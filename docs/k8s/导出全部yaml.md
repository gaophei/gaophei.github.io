下面给你几种**一次性把各种 K8s 资源 YAML 快速落盘**的做法（适用于通过 Rancher 连接到下游生产集群；直接在 Rancher 的 *Kubectl shell* 里跑也行）。按“最快 → 更优雅可版本化”的顺序来：

------

# 1) 最快：一次性导出到一个文件---需k8s高版本

> 适合“先备一份，慢慢整理”。

```bash
# 导出常见资源（含：Deployment/StatefulSet/Job/CronJob/ConfigMap/Secret）
kubectl get deploy,sts,job,cronjob,cm,secret -A \
  -o yaml --show-managed-fields=false > cluster-backup-$(date +%F).yaml
```

- `-A` 导出所有命名空间。
- `--show-managed-fields=false` 去掉 `managedFields`，文件更干净。
- 后续可再用 `yq`/`jq` 清理 `status`、`resourceVersion` 等易变字段（见第 2、3 节）。

------

# 2) 实用：按「命名空间/类型/名称」分文件（更适合进 Git）

> 输出目录结构：`./export/<namespace>/<kind>/<name>.yaml`，默认清理易变字段并跳过 SA 自动生成的 Token Secret。

**依赖：** `kubectl`、[`jq`](https://stedolan.github.io/jq/)、[`yq v4`](https://github.com/mikefarah/yq)（mikefarah 版）

```bash
#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=${1:-k8s-yaml-export-$(date +%F)}
# 你要的类型清单（可自行增减）
KINDS=(deployments statefulsets jobs cronjobs configmaps secrets)

# 若只想导出某个 Rancher 项目下的命名空间，设置 PROJECT_ID，例如：c-abcde:p-12345
PROJECT_ID="${PROJECT_ID:-}"

mkdir -p "$OUT_DIR"

# 选定命名空间：全集群 或 Rancher 项目内
if [[ -n "$PROJECT_ID" ]]; then
  mapfile -t NAMESPACES < <(
    kubectl get ns -o json \
    | jq -r --arg p "$PROJECT_ID" '.items[]
        | select(.metadata.annotations["field.cattle.io/projectId"] == $p)
        | .metadata.name'
  )
else
  mapfile -t NAMESPACES < <(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
fi

for ns in "${NAMESPACES[@]}"; do
  for kind in "${KINDS[@]}"; do
    echo "[*] $ns / $kind ..."
    mkdir -p "$OUT_DIR/$ns/$kind"

    # 拉取该命名空间该类型的对象
    kubectl -n "$ns" get "$kind" -o json --ignore-not-found \
    | jq -c '.items[]' \
    | while read -r obj; do
        name=$(jq -r '.metadata.name' <<<"$obj")

        # 跳过 ServiceAccount 自动生成的 Token Secret
        # （其他类型没有 .type 字段，不受影响）
        obj=$(jq 'if .kind=="Secret" then
                    select(.type != "kubernetes.io/service-account-token")
                  else . end' <<<"$obj") || true
        [[ -z "$obj" ]] && continue

        # 清理易变/噪音字段（便于进 Git 做差异）
        cleaned=$(jq '
          del(.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]) |
          del(.metadata.annotations["field.cattle.io/creatorId"]) |
          del(.metadata.annotations["field.cattle.io/publicEndpoints"]) |
          del(.metadata.creationTimestamp, .metadata.generation, .metadata.resourceVersion,
              .metadata.uid, .metadata.selfLink, .metadata.managedFields) |
          del(.status)
        ' <<<"$obj")

        # 写入 YAML
        yq -P <<<"$cleaned" > "$OUT_DIR/$ns/$kind/$name.yaml"
      done
  done
done

echo "✅ 导出完成：$OUT_DIR"
```

**用法示例：**

```bash
# 全集群导出
bash export-k8s.sh

# 只导出某个 Rancher 项目（先查项目 ID，再导出）
export PROJECT_ID="c-abcde:p-12345"
bash export-k8s.sh rancher-project-a-$(date +%F)
```

> 💡 提示
>
> - 如果你还想导出更多类型，把 `KINDS` 里再加，比如 `svc,hpa,ingress,rbac` 等；或见第 4 节用“全自动发现所有类型”。
> - 如果没有 `yq`，可以先输出 JSON 保存（把最后一行改成 `echo "$cleaned" > ...json`），后续再转换。

------

# 3) Helm 发行版（Release）另存：还原“声明式”清单

你的部分工作负载若是通过 Helm 部署，保存 Helm 渲染结果更贴近“声明式”来源：

```bash
# 列 release
helm -n <ns> ls

# 导出单个 release 的 manifest
helm -n <ns> get manifest <release-name> > helm-<release-name>.yaml
```

------

# 4) 进阶：自动发现所有**命名空间级**资源并分文件导出

> 免维护资源清单（包括 CRD 自定义资源）。同样会清理易变字段，并跳过 SA token Secret。

```bash
#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=${1:-k8s-yaml-export-$(date +%F)}
mkdir -p "$OUT_DIR"

# 忽略一些不适合备份/会频繁变化的资源
EXCLUDE_RE='^events(\.events\.k8s\.io)?$|^leases$|^endpoints$|^endpointslices$'

# 仅命名空间级资源
mapfile -t KINDS < <(
  kubectl api-resources --verbs=list --namespaced -o name \
  | grep -Ev "$EXCLUDE_RE" | sort -u
)

for kind in "${KINDS[@]}"; do
  echo "[*] Export $kind ..."
  kubectl get "$kind" -A -o json --ignore-not-found \
  | jq -c '.items[]' \
  | while read -r obj; do
      ns=$(jq -r '.metadata.namespace' <<<"$obj")
      name=$(jq -r '.metadata.name' <<<"$obj")
      [[ "$ns" == "null" || -z "$ns" ]] && ns="_cluster_"
      mkdir -p "$OUT_DIR/$ns/$kind"

      obj=$(jq 'if .kind=="Secret" then
                  select(.type != "kubernetes.io/service-account-token")
                else . end' <<<"$obj") || true
      [[ -z "$obj" ]] && continue

      cleaned=$(jq '
        del(.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]) |
        del(.metadata.creationTimestamp, .metadata.generation, .metadata.resourceVersion,
            .metadata.uid, .metadata.selfLink, .metadata.managedFields) |
        del(.status)
      ' <<<"$obj")

      yq -P <<<"$cleaned" > "$OUT_DIR/$ns/$kind/$name.yaml"
    done
done

echo "✅ Done: $OUT_DIR"
```

> 还想导出**集群级**资源（如 `ClusterRole`, `ClusterRoleBinding`, `StorageClass`, `CRD`, `MutatingWebhookConfiguration`, `ValidatingWebhookConfiguration` 等）时，把 `--namespaced=false` 再跑一遍，然后去掉 `-n` 参数、把输出存到 `./_cluster_/<kind>/<name>.yaml` 即可。

------

## 注意事项（很重要）

- **Secret** 真数据是 Base64 编码（不是加密）。提交 Git 时请使用 SOPS（age/GPG）或 Sealed Secrets 加密敏感字段。
- 删除了 `status/resourceVersion/managedFields/uid/creationTimestamp` 等 **易变字段**，便于版本管理与重复应用（`kubectl apply`/`kustomize`）。
- 某些控制器会为你自动创建对象（如 SA token Secret、Endpoints 等），**不建议备份/还原**。脚本里已默认跳过常见的。
- 在 Rancher 里跑的话，用集群页面右上角的 **Kubectl** 打开终端，直接粘贴脚本即可；或本地先 `rancher login`/设置好 kubeconfig context 再运行。

------

如果你告诉我：

- 需要导出的**具体项目名/命名空间**，
- 是否需要包含**集群级**资源，
- 想不想把 **Secret 自动转换为 SOPS/SealedSecrets**，

我可以把脚本按你的场景直接定制好👌。





----------------------

```bash
[系统未激活][root@k8s01-nfs 0922]# kubectl get deploy,sts,job,cronjob,cm,secret -A -o yaml --show-managed-fields=false > cluster-backup-$(date +%F).yaml
Error: unknown flag: --show-managed-fields
See 'kubectl get --help' for usage.
[系统未激活][root@k8s01-nfs 0922]# kubectl version
Client Version: version.Info{Major:"1", Minor:"20", GitVersion:"v1.20.15", GitCommit:"8f1e5bf0b9729a899b8df86249b56e2c74aebc55", GitTreeState:"clean", BuildDate:"2022-01-19T17:27:39Z", GoVersion:"go1.15.15", Compiler:"gc", Platform:"linux/arm64"}
Server Version: version.Info{Major:"1", Minor:"20", GitVersion:"v1.20.15", GitCommit:"8f1e5bf0b9729a899b8df86249b56e2c74aebc55", GitTreeState:"clean", BuildDate:"2022-01-19T17:23:01Z", GoVersion:"go1.15.15", Compiler:"gc", Platform:"linux/arm64"}
[系统未激活][root@k8s01-nfs 0922]# kubectl --help
kubectl controls the Kubernetes cluster manager.

 Find more information at: https://kubernetes.io/docs/reference/kubectl/overview/

Basic Commands (Beginner):
  create        Create a resource from a file or from stdin.
  expose        Take a replication controller, service, deployment or pod and expose it as a new Kubernetes Service
  run           Run a particular image on the cluster
  set           Set specific features on objects

Basic Commands (Intermediate):
  explain       Documentation of resources
  get           Display one or many resources
  edit          Edit a resource on the server
  delete        Delete resources by filenames, stdin, resources and names, or by resources and label selector

Deploy Commands:
  rollout       Manage the rollout of a resource
  scale         Set a new size for a Deployment, ReplicaSet or Replication Controller
  autoscale     Auto-scale a Deployment, ReplicaSet, or ReplicationController

Cluster Management Commands:
  certificate   Modify certificate resources.
  cluster-info  Display cluster info
  top           Display Resource (CPU/Memory/Storage) usage.
  cordon        Mark node as unschedulable
  uncordon      Mark node as schedulable
  drain         Drain node in preparation for maintenance
  taint         Update the taints on one or more nodes

Troubleshooting and Debugging Commands:
  describe      Show details of a specific resource or group of resources
  logs          Print the logs for a container in a pod
  attach        Attach to a running container
  exec          Execute a command in a container
  port-forward  Forward one or more local ports to a pod
  proxy         Run a proxy to the Kubernetes API server
  cp            Copy files and directories to and from containers.
  auth          Inspect authorization
  debug         Create debugging sessions for troubleshooting workloads and nodes

Advanced Commands:
  diff          Diff live version against would-be applied version
  apply         Apply a configuration to a resource by filename or stdin
  patch         Update field(s) of a resource
  replace       Replace a resource by filename or stdin
  wait          Experimental: Wait for a specific condition on one or many resources.
  kustomize     Build a kustomization target from a directory or a remote url.

Settings Commands:
  label         Update the labels on a resource
  annotate      Update the annotations on a resource
  completion    Output shell completion code for the specified shell (bash or zsh)

Other Commands:
  api-resources Print the supported API resources on the server
  api-versions  Print the supported API versions on the server, in the form of "group/version"
  config        Modify kubeconfig files
  plugin        Provides utilities for interacting with plugins.
  version       Print the client and server version information

Usage:
  kubectl [flags] [options]

Use "kubectl <command> --help" for more information about a given command.
Use "kubectl options" for a list of global command-line options (applies to all commands).
[系统未激活][root@k8s01-nfs 0922]# 

```

--------------------

你这台 `kubectl v1.20` 没有 `--show-managed-fields` 这个参数，所以报错。用法改两种思路：

------

### A. 直接导出（最省事，可能带噪音字段）

```bash
kubectl get deploy,sts,job,cronjob,cm,secret -A -o yaml > cluster-backup-$(date +%F).yaml
```

------

### B. 导出同时“清理易变字段”（推荐；需 `jq` 与 `yq v4`）

```bash
# 导出为 JSON → 用 jq 删除 managedFields / status / 版本类字段 → 转回 YAML
kubectl get deploy,sts,job,cronjob,cm,secret -A -o json \
| jq '
  .items |= map(
    # 跳过由 ServiceAccount 自动生成的 token Secret
    select((.kind == "Secret" and ((.type // "") == "kubernetes.io/service-account-token")) | not)
    # 清掉易变/噪音字段，方便入库做 diff 与复用
    | del(.metadata.managedFields,
          .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"],
          .metadata.annotations["field.cattle.io/creatorId"],
          .metadata.annotations["field.cattle.io/publicEndpoints"],
          .metadata.uid, .metadata.resourceVersion, .metadata.generation,
          .metadata.creationTimestamp, .metadata.selfLink,
          .status)
  )' \
| yq -P > cluster-backup-$(date +%F).yaml
```

> 没有 `yq` 也行：把最后一段去掉改成输出 JSON
>  `... | jq '...清理...' > cluster-backup-$(date +%F).json`

------

#### 可选：按命名空间/类型分文件（兼容 1.20）

如果你想更适合进 Git 的目录结构（`<ns>/<kind>/<name>.yaml`），用这个短脚本（同样只依赖 `kubectl + jq + yq`）：

```bash
#!/usr/bin/env bash
set -euo pipefail
OUT_DIR=${1:-k8s-yaml-export-$(date +%F)}
KINDS=(deployments statefulsets jobs cronjobs configmaps secrets)
mkdir -p "$OUT_DIR"

# 若只导出某个 Rancher 项目，先设置 PROJECT_ID="c-xxxxx:p-yyyyy"
PROJECT_ID="${PROJECT_ID:-}"

if [[ -n "$PROJECT_ID" ]]; then
  mapfile -t NSES < <(kubectl get ns -o json \
    | jq -r --arg p "$PROJECT_ID" '.items[]
        | select(.metadata.annotations["field.cattle.io/projectId"]==$p)
        | .metadata.name')
else
  mapfile -t NSES < <(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
fi

for ns in "${NSES[@]}"; do
  for k in "${KINDS[@]}"; do
    kubectl -n "$ns" get "$k" -o json --ignore-not-found \
    | jq -c '.items[]' | while read -r obj; do
        name=$(jq -r '.metadata.name' <<<"$obj")
        # 跳过 SA token Secret
        is_sa_token=$(jq -r 'select(.kind=="Secret") | (.type // "")=="kubernetes.io/service-account-token"' <<<"$obj" || true)
        [[ "$is_sa_token" == "true" ]] && continue
        cleaned=$(jq 'del(.metadata.managedFields,
                          .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"],
                          .metadata.uid, .metadata.resourceVersion,
                          .metadata.generation, .metadata.creationTimestamp,
                          .metadata.selfLink, .status)' <<<"$obj")
        mkdir -p "$OUT_DIR/$ns/$k"
        yq -P <<<"$cleaned" > "$OUT_DIR/$ns/$k/$name.yaml"
      done
  done
done
echo "✅ 导出完成：$OUT_DIR"
```

------

##### 小贴士

- 你现在这版 `kubectl` 不支持 `--show-managed-fields`；用上面的 jq/yq 方式即可达到同样效果。
- `Secret.data` 是 Base64 编码（非加密），建议入库前用 SOPS/Sealed Secrets 处理。
- 如果还想包含更多资源（如 svc/ingress/hpa/rbac 等），把它们加进 `KINDS` 即可，或用 `kubectl api-resources --verbs=list --namespaced -o name` 自动发现再导出。