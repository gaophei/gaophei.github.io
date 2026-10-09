# Rancher local 集群 etcd 成员故障恢复及 RKE 配置文件找回记录

| 项目 | 内容 |
|---|---|
| 发生日期 | 2026-10-08 |
| 涉及集群 | Rancher 2.5.7 管理集群（local，RKE1 部署） |
| 故障节点 | rancher1（10.11.133.88） |
| 故障现象 | etcd 容器循环重启，日志报 `etcdmain: walpb: crc mismatch` |
| 处理结果 | 已恢复，三个 etcd 成员健康、数据一致；已从集群内找回 `cluster.rkestate`，重建 `cluster.yml`，并生成直连 apiserver 的 kubeconfig |
| 文档更新 | 2026-10-09：补充备份、磁盘检查、停止旧成员、导出 rkestate 的实际执行记录及 etcd-old 状态；据此修订根因分析 |

---

## 1. 摘要

2026-10-08 14:24 前后，local 集群节点 rancher1（10.11.133.88）和 rancher3（10.11.133.90）发生重启，其中 rancher1 是系统正常关机后立即重启，发起原因待查。重启后，rancher1 上的 etcd 因 WAL 文件损坏（`walpb: crc mismatch`）无法启动，容器约每 60 秒重启一次，`kubectl get cs` 显示 etcd-1 Unhealthy。另外两个 etcd 成员正常，集群保持 2/3 quorum，kube-apiserver 可正常读写，业务未中断，但集群已失去容错能力。

处理方式：将损坏的成员从 etcd 集群中移除，清空其数据目录，重新以新成员身份加入，并以 `--initial-cluster-state=existing` 参数重建 etcd 容器，由 leader 全量同步数据。恢复后三个成员的 RAFT INDEX 完全一致，`kubectl get cs` 全部 Healthy。

处理过程中还确认了一个问题：当初执行 RKE 安装的 nginx02 虚拟机已损坏重建，原 `cluster.yml` 和 `cluster.rkestate` 丢失，只剩一份走 Rancher 代理的 kubeconfig。本次从集群的 ConfigMap `kube-system/full-cluster-state` 中导出了 `cluster.rkestate`，从中取出 kube-admin 证书生成了直连 apiserver 的 `kube_config_cluster.yml`，并根据状态文件中的 `rkeConfig` 重建了 `cluster.yml`。

### 时间线

以下均为本地时间（UTC+8）。各节点系统时间为 UTC+8，而 etcd 容器日志和 etcdctl 输出中的时间为 UTC，两者相差 8 小时，例如 etcd 日志中的 06:38 即本地 14:38。

| 时间 | 事件 | 依据 |
|---|---|---|
| 2026-10-08 14:24 | rancher1 系统正常关机，随即重新启动 | rancher1 `last -x`（4.2 节） |
| 约 14:20～14:25 | rancher3 重启 | 排查时 rancher3 系统容器已运行约 19 分钟，具体时间待核实 |
| 14:24 之后 | rancher1 etcd 反复启动，每次都因 `walpb: crc mismatch` 退出 | rancher1 etcd 日志（3.2 节） |
| 约 14:40 | 发现 `kubectl get cs` 中 etcd-1 Unhealthy，开始排查 | 3.1 节 |
| 14:49 | 在 rancher2 上打手动快照 `manual-202610081449.db`（58 MB） | 4.1 节 |
| 16:13 | 检查 rancher1 磁盘、内核日志与重启记录 | 4.2 节 |
| 约 17 时前后 | 停止 rancher1 旧 etcd，移除并重新加入成员，重建 etcd 容器，验证三成员健康 | 根据次日 `docker ps -a` 中的容器运行时长推算（4.7 节） |
| 之后 | 导出 `cluster.rkestate`，生成直连 kubeconfig，重建 `cluster.yml` | 第 5 节 |
| 2026-10-09 | 新 etcd 已稳定运行 16 小时；`etcd-old` 容器尚未删除 | 4.7 节 |

---

## 2. 环境信息

### 2.1 节点

| 主机名 | IP | RKE 角色 | 说明 |
|---|---|---|---|
| rancher1 | 10.11.133.88 | controlplane, etcd, worker | 故障节点，etcd 成员名 `etcd-10.11.133.88` |
| rancher2 | 10.11.133.89 | controlplane, etcd, worker | 恢复时为 etcd leader |
| rancher3 | 10.11.133.90 | controlplane, etcd, worker | 与 rancher1 同期发生重启 |
| nginx02（主机名 glfzjh） | — | 4 层负载均衡、运维机 | 原 RKE 安装机，VM 损坏后已重建 |

### 2.2 软件版本

| 组件 | 版本 |
|---|---|
| Rancher | 2.5.7 |
| Kubernetes | v1.20.4（RKE 版本串 `v1.20.4-rancher1-1`） |
| etcd | 3.4.14（`rancher/coreos-etcd:v3.4.14-rancher1`） |
| rke-tools | v0.1.72 |
| 网络插件 | canal（calico v3.17.2 + flannel v0.13.0） |
| Ingress | `rancher/nginx-ingress-controller:nginx-0.43.0-rancher1` |
| Rancher 访问域名 | rancher.shufe-zj.edu.cn |

### 2.3 nginx02 负载均衡配置

nginx02 以 stream 模块做 4 层转发，将 80/443 分发到三个节点的 ingress-nginx：

```nginx
worker_processes 4;
worker_rlimit_nofile 40000;

events {
    worker_connections 8192;
}

stream {
    upstream rancher_servers_http {
        least_conn;
        server 10.11.133.88:80 max_fails=3 fail_timeout=5s;
        server 10.11.133.89:80 max_fails=3 fail_timeout=5s;
        server 10.11.133.90:80 max_fails=3 fail_timeout=5s;
    }
    server {
        listen     80;
        proxy_pass rancher_servers_http;
    }

    upstream rancher_servers_https {
        least_conn;
        server 10.11.133.88:443 max_fails=3 fail_timeout=5s;
        server 10.11.133.89:443 max_fails=3 fail_timeout=5s;
        server 10.11.133.90:443 max_fails=3 fail_timeout=5s;
    }
    server {
        listen     443;
        proxy_pass rancher_servers_https;
    }
}
```

### 2.4 RKE 下 etcd 的关键路径

| 用途 | 宿主机路径 | 容器内路径 |
|---|---|---|
| etcd 数据目录 | `/var/lib/etcd` | `/var/lib/rancher/etcd` |
| 证书 | `/etc/kubernetes/ssl` | `/etc/kubernetes/ssl` |
| RKE 滚动快照 | `/opt/rke/etcd-snapshots` | — |

以上为 RKE 默认值，本环境已通过 `docker inspect etcd` 确认一致（见 4.1 节）。RKE 滚动快照每 6 小时一次（UTC 02:53、08:53、14:53、20:53，即本地 10:53、16:53、22:53、04:53），保留 60 份。RKE 的 etcd 容器内已预置 etcdctl 所需的证书环境变量（API v3），可以直接用 `docker exec etcd etcdctl ...` 执行命令。

---

## 3. 故障现象与排查

### 3.1 集群整体状态（nginx02 执行）

```text
[root@glfzjh ~]# kubectl get pod -A -owide
NAMESPACE                 NAME                                       READY   STATUS             RESTARTS   AGE      IP             NODE           NOMINATED NODE   READINESS GATES
cattle-system             rancher-f86cb5d54-dxzh2                    1/1     Running            1          17m      10.42.1.67     10.11.133.88   <none>           <none>
cattle-system             rancher-f86cb5d54-qdgk5                    1/1     Running            448        562d     10.42.0.41     10.11.133.89   <none>           <none>
cattle-system             rancher-f86cb5d54-r5nq8                    1/1     Running            543        582d     10.42.0.40     10.11.133.89   <none>           <none>
cattle-system             rancher-webhook-7ddb797ddb-kgp6s           1/1     Running            4          559d     10.42.2.60     10.11.133.90   <none>           <none>
fleet-system              fleet-agent-7d68bcc7b5-4f8ph               1/1     Running            11         562d     10.42.0.45     10.11.133.89   <none>           <none>
fleet-system              fleet-controller-6899bdd4d8-ngr64          1/1     Running            32         582d     10.42.0.46     10.11.133.89   <none>           <none>
fleet-system              gitjob-86d96977d7-cmz9l                    1/1     Running            18         582d     10.42.0.43     10.11.133.89   <none>           <none>
ingress-nginx             default-http-backend-65dd5949d9-gc5sc      1/1     Running            12         5y198d   10.42.2.59     10.11.133.90   <none>           <none>
ingress-nginx             nginx-ingress-controller-4fgcl             1/1     Running            8          5y198d   10.11.133.89   10.11.133.89   <none>           <none>
ingress-nginx             nginx-ingress-controller-k5n5x             1/1     Running            9          5y198d   10.11.133.90   10.11.133.90   <none>           <none>
ingress-nginx             nginx-ingress-controller-ndms4             1/1     Running            14         5y198d   10.11.133.88   10.11.133.88   <none>           <none>
kube-system               calico-kube-controllers-6c8ddcb6cd-sg7sz   1/1     Running            12         5y198d   10.42.2.57     10.11.133.90   <none>           <none>
kube-system               canal-2nrf4                                2/2     Running            17         5y198d   10.11.133.89   10.11.133.89   <none>           <none>
kube-system               canal-86558                                2/2     Running            19         5y198d   10.11.133.90   10.11.133.90   <none>           <none>
kube-system               canal-w59ks                                2/2     Running            24         5y198d   10.11.133.88   10.11.133.88   <none>           <none>
kube-system               coredns-7c49b8c54c-qdmzd                   1/1     Running            11         5y198d   10.42.2.61     10.11.133.90   <none>           <none>
kube-system               coredns-7c49b8c54c-w6jmr                   1/1     Running            12         5y198d   10.42.1.70     10.11.133.88   <none>           <none>
kube-system               coredns-autoscaler-79599b9dc6-cb5l8        1/1     Running            12         5y198d   10.42.1.68     10.11.133.88   <none>           <none>
kube-system               metrics-server-6cc9c79d8c-b4sff            1/1     Running            16         5y198d   10.42.1.69     10.11.133.88   <none>           <none>
kube-system               rke-coredns-addon-deploy-job-jg4fj         0/1     Completed          0          5y198d   10.11.133.88   10.11.133.88   <none>           <none>
kube-system               rke-ingress-controller-deploy-job-xj5kf    0/1     Completed          0          5y198d   10.11.133.88   10.11.133.88   <none>           <none>
kube-system               rke-metrics-addon-deploy-job-v9rkd         0/1     Completed          0          5y198d   10.11.133.88   10.11.133.88   <none>           <none>
kube-system               rke-network-plugin-deploy-job-cdcnf        0/1     Completed          0          5y198d   10.11.133.88   10.11.133.88   <none>           <none>
rancher-operator-system   rancher-operator-5c795bd886-wxqms          0/1     ImagePullBackOff   0          562d     10.42.0.48     10.11.133.89   <none>           <none>

[root@glfzjh ~]# kubectl get nodes
NAME           STATUS   ROLES                      AGE      VERSION
10.11.133.88   Ready    controlplane,etcd,worker   5y198d   v1.20.4
10.11.133.89   Ready    controlplane,etcd,worker   5y198d   v1.20.4
10.11.133.90   Ready    controlplane,etcd,worker   5y198d   v1.20.4

[root@glfzjh ~]# kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS      MESSAGE                                                                                           ERROR
etcd-1               Unhealthy   Get "https://10.11.133.88:2379/health": dial tcp 10.11.133.88:2379: connect: connection refused
scheduler            Healthy     ok
controller-manager   Healthy     ok
etcd-2               Healthy     {"health":"true"}
etcd-0               Healthy     {"health":"true"}
```

从这组输出可以看出：

- 三个节点都是 Ready，说明各节点的 kubelet 正常。
- `kubectl get cs` 中 etcd-1（10.11.133.88）Unhealthy，2379 端口拒绝连接，etcd 进程没有在监听。
- rancher1 上的 rancher Pod（`rancher-f86cb5d54-dxzh2`）AGE 只有 17 分钟，说明该节点刚重启过。
- `rancher-operator` 的 ImagePullBackOff 已持续 562 天，两个 rancher Pod 的重启次数为 448 和 543 次。这两项都是历史遗留问题，与本次故障无关，列入第 7 节遗留事项。

### 3.2 rancher1：etcd 容器循环重启

```text
[root@rancher1 ~]# docker ps
CONTAINER ID   IMAGE                                  COMMAND                  CREATED          STATUS                          PORTS     NAMES
79e32a469595   0bfefe9f649b                           "/opt/bin/flanneld -…"   15 minutes ago   Up 15 minutes                             k8s_kube-flannel_canal-w59ks_kube-system_51e0cffb-1a27-4495-a486-55b8bb0a9372_12
908a174447db   5a3c598c81d5                           "start_runit"            15 minutes ago   Up 15 minutes                             k8s_calico-node_canal-w59ks_kube-system_51e0cffb-1a27-4495-a486-55b8bb0a9372_12
c41eeef072df   296a6d5035e2                           "/coredns -conf /etc…"   15 minutes ago   Up 15 minutes                             k8s_coredns_coredns-7c49b8c54c-w6jmr_kube-system_f50e07bf-00af-4146-b28d-9aa49ab2d59c_12
eb5247aabbf8   9759a41ccdf0                           "/metrics-server --c…"   15 minutes ago   Up 15 minutes                             k8s_metrics-server_metrics-server-6cc9c79d8c-b4sff_kube-system_dd71757a-1db4-4911-90dc-c9a821a8872d_16
50b605da13c0   acd7606e832d                           "/usr/bin/dumb-init …"   15 minutes ago   Up 15 minutes                             k8s_nginx-ingress-controller_nginx-ingress-controller-ndms4_ingress-nginx_28c45dab-97e3-4fa9-b6d6-a3af1963e82b_14
a6f38ec1c174   rancher/pause:3.2                      "/pause"                 15 minutes ago   Up 15 minutes                             k8s_POD_coredns-7c49b8c54c-w6jmr_kube-system_f50e07bf-00af-4146-b28d-9aa49ab2d59c_14
d8f5d037b44b   rancher/pause:3.2                      "/pause"                 15 minutes ago   Up 15 minutes                             k8s_POD_metrics-server-6cc9c79d8c-b4sff_kube-system_dd71757a-1db4-4911-90dc-c9a821a8872d_104
526159f5354e   rancher/pause:3.2                      "/pause"                 15 minutes ago   Up 15 minutes                             k8s_POD_canal-w59ks_kube-system_51e0cffb-1a27-4495-a486-55b8bb0a9372_12
fc4eab736712   rancher/pause:3.2                      "/pause"                 15 minutes ago   Up 15 minutes                             k8s_POD_nginx-ingress-controller-ndms4_ingress-nginx_28c45dab-97e3-4fa9-b6d6-a3af1963e82b_12
8fe3f4bbf7be   4f1064cf7caf                           "/cluster-proportion…"   15 minutes ago   Up 15 minutes                             k8s_autoscaler_coredns-autoscaler-79599b9dc6-cb5l8_kube-system_a1668260-5e7b-499e-bd61-e1631ba7492b_12
63f5d3295c27   rancher/pause:3.2                      "/pause"                 15 minutes ago   Up 15 minutes                             k8s_POD_coredns-autoscaler-79599b9dc6-cb5l8_kube-system_a1668260-5e7b-499e-bd61-e1631ba7492b_101
99f31a73f55a   3ea53a0e3b90                           "entrypoint.sh --htt…"   15 minutes ago   Up 15 minutes                             k8s_rancher_rancher-f86cb5d54-dxzh2_cattle-system_837f7d13-f748-4c9b-a3d8-21eb95ad067c_1
9d5a974ec3e3   rancher/pause:3.2                      "/pause"                 15 minutes ago   Up 15 minutes                             k8s_POD_rancher-f86cb5d54-dxzh2_cattle-system_837f7d13-f748-4c9b-a3d8-21eb95ad067c_1
ad9a9d69743c   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 16 minutes                             kube-proxy
e17bf487ff10   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 16 minutes                             kubelet
25bb0ed50731   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 16 minutes                             kube-scheduler
e7322801e729   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 16 minutes                             kube-controller-manager
d7a560a3fcff   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 16 minutes                             kube-apiserver
04972378c00e   rancher/rke-tools:v0.1.72              "/docker-entrypoint.…"   5 years ago      Up 16 minutes                             etcd-rolling-snapshots
458a10fab611   rancher/coreos-etcd:v3.4.14-rancher1   "/usr/local/bin/etcd…"   5 years ago      Restarting (1) 40 seconds ago             etcd
```

```text
[root@rancher1 ~]# docker logs etcd --tail 50
2026-10-08 06:38:15.826416 I | embed: name = etcd-10.11.133.88
2026-10-08 06:38:15.826430 I | embed: data dir = /var/lib/rancher/etcd/
2026-10-08 06:38:15.826436 I | embed: member dir = /var/lib/rancher/etcd/member
2026-10-08 06:38:15.826441 I | embed: heartbeat = 500ms
2026-10-08 06:38:15.826446 I | embed: election = 5000ms
2026-10-08 06:38:15.826451 I | embed: snapshot count = 100000
2026-10-08 06:38:15.826490 I | embed: advertise client URLs = https://10.11.133.88:2379
2026-10-08 06:38:15.826498 I | embed: initial advertise peer URLs = https://10.11.133.88:2380
2026-10-08 06:38:15.826505 I | embed: initial cluster =
2026-10-08 06:38:16.967162 C | etcdmain: walpb: crc mismatch
2026-10-08 06:39:17.234865 W | pkg/flags: unrecognized environment variable ETCD_UNSUPPORTED_ARCH=x86_64
[WARNING] Deprecated '--logger=capnslog' flag is set; use '--logger=zap' flag instead
2026-10-08 06:39:17.234975 I | etcdmain: etcd Version: 3.4.14
2026-10-08 06:39:17.234989 I | etcdmain: Git SHA: 8a03d2e96
2026-10-08 06:39:17.234996 I | etcdmain: Go Version: go1.12.17
2026-10-08 06:39:17.235001 I | etcdmain: Go OS/Arch: linux/amd64
2026-10-08 06:39:17.235006 I | etcdmain: setting maximum number of CPUs to 4, total number of available CPUs is 4
2026-10-08 06:39:17.235099 N | etcdmain: the server is already initialized as member before, starting as etcd member...
[WARNING] Deprecated '--logger=capnslog' flag is set; use '--logger=zap' flag instead
2026-10-08 06:39:17.235146 I | embed: peerTLS: cert = /etc/kubernetes/ssl/kube-etcd-10-11-133-88.pem, key = /etc/kubernetes/ssl/kube-etcd-10-11-133-88-key.pem, trusted-ca = /etc/kubernetes/ssl/kube-ca.pem, client-cert-auth = true, crl-file =
2026-10-08 06:39:17.236084 I | embed: name = etcd-10.11.133.88
2026-10-08 06:39:17.236101 I | embed: data dir = /var/lib/rancher/etcd/
2026-10-08 06:39:17.236108 I | embed: member dir = /var/lib/rancher/etcd/member
2026-10-08 06:39:17.236113 I | embed: heartbeat = 500ms
2026-10-08 06:39:17.236118 I | embed: election = 5000ms
2026-10-08 06:39:17.236122 I | embed: snapshot count = 100000
2026-10-08 06:39:17.236134 I | embed: advertise client URLs = https://10.11.133.88:2379
2026-10-08 06:39:17.236140 I | embed: initial advertise peer URLs = https://10.11.133.88:2380
2026-10-08 06:39:17.236148 I | embed: initial cluster =
2026-10-08 06:39:18.351280 C | etcdmain: walpb: crc mismatch
2026-10-08 06:40:18.619028 W | pkg/flags: unrecognized environment variable ETCD_UNSUPPORTED_ARCH=x86_64
[WARNING] Deprecated '--logger=capnslog' flag is set; use '--logger=zap' flag instead
2026-10-08 06:40:18.619160 I | etcdmain: etcd Version: 3.4.14
2026-10-08 06:40:18.619173 I | etcdmain: Git SHA: 8a03d2e96
2026-10-08 06:40:18.619184 I | etcdmain: Go Version: go1.12.17
2026-10-08 06:40:18.619190 I | etcdmain: Go OS/Arch: linux/amd64
2026-10-08 06:40:18.619207 I | etcdmain: setting maximum number of CPUs to 4, total number of available CPUs is 4
2026-10-08 06:40:18.619316 N | etcdmain: the server is already initialized as member before, starting as etcd member...
[WARNING] Deprecated '--logger=capnslog' flag is set; use '--logger=zap' flag instead
2026-10-08 06:40:18.619374 I | embed: peerTLS: cert = /etc/kubernetes/ssl/kube-etcd-10-11-133-88.pem, key = /etc/kubernetes/ssl/kube-etcd-10-11-133-88-key.pem, trusted-ca = /etc/kubernetes/ssl/kube-ca.pem, client-cert-auth = true, crl-file =
2026-10-08 06:40:18.620379 I | embed: name = etcd-10.11.133.88
2026-10-08 06:40:18.620403 I | embed: data dir = /var/lib/rancher/etcd/
2026-10-08 06:40:18.620410 I | embed: member dir = /var/lib/rancher/etcd/member
2026-10-08 06:40:18.620415 I | embed: heartbeat = 500ms
2026-10-08 06:40:18.620420 I | embed: election = 5000ms
2026-10-08 06:40:18.620425 I | embed: snapshot count = 100000
2026-10-08 06:40:18.620445 I | embed: advertise client URLs = https://10.11.133.88:2379
2026-10-08 06:40:18.620460 I | embed: initial advertise peer URLs = https://10.11.133.88:2380
2026-10-08 06:40:18.620467 I | embed: initial cluster =
2026-10-08 06:40:19.783112 C | etcdmain: walpb: crc mismatch
```

从容器状态和日志可以看出：

- etcd 容器状态为 `Restarting (1)`，而同节点的 kubelet、kube-apiserver 等系统容器已运行约 16 分钟，节点本身是正常的。
- etcd 日志约每 60 秒重复一次启动流程，每次都在读取 WAL 时报 `walpb: crc mismatch` 后退出。该行日志级别为 `C`（Critical），etcd 遇到这类错误会直接终止进程。
- `the server is already initialized as member before` 表示数据目录里已有成员数据，etcd 按已有数据启动；这种情况下 `initial cluster =` 显示为空是正常的，不是配置问题。

### 3.3 rancher2 / rancher3：其余成员状态

```bash
[root@rancher2 ~]# docker ps
CONTAINER ID   IMAGE                                  COMMAND                  CREATED          STATUS          PORTS     NAMES
ce8fcaa1271e   e6516ceecc32                           "fleetcontroller"        18 minutes ago   Up 18 minutes             k8s_fleet-controller_fleet-controller-6899bdd4d8-ngr64_fleet-system_06b343be-0506-409f-a694-3d1be7bea52f_32
245be3253b57   3ea53a0e3b90                           "entrypoint.sh --htt…"   18 minutes ago   Up 18 minutes             k8s_rancher_rancher-f86cb5d54-qdgk5_cattle-system_5d4a714b-9543-4509-9c54-a049373d2e08_448
9fcf63242bc4   2c18f4f68eef                           "gitjob --tekton-ima…"   19 minutes ago   Up 19 minutes             k8s_gitjob_gitjob-86d96977d7-cmz9l_fleet-system_02741f3e-eda7-4896-8b50-37b8ba4b26b2_18
726f83ebd943   4c6ca93b4785                           "fleetagent"             19 minutes ago   Up 19 minutes             k8s_fleet-agent_fleet-agent-7d68bcc7b5-4f8ph_fleet-system_127f58bc-b67b-4329-bfe2-9030e23368dd_11
f0305c448965   3ea53a0e3b90                           "entrypoint.sh --htt…"   5 weeks ago      Up 5 weeks                k8s_rancher_rancher-f86cb5d54-r5nq8_cattle-system_a34ec0d3-2b55-4a1f-b6c3-e9c6ccd71592_543
d15bf4701fbc   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_rancher-operator-5c795bd886-wxqms_rancher-operator-system_097c63f3-a38c-478d-839d-e850dde32df4_5
83f367940eca   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_fleet-controller-6899bdd4d8-ngr64_fleet-system_06b343be-0506-409f-a694-3d1be7bea52f_3
f7fc8e006e81   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_fleet-agent-7d68bcc7b5-4f8ph_fleet-system_127f58bc-b67b-4329-bfe2-9030e23368dd_3
f8bb97c00bc8   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_gitjob-86d96977d7-cmz9l_fleet-system_02741f3e-eda7-4896-8b50-37b8ba4b26b2_3
67864c83493b   0bfefe9f649b                           "/opt/bin/flanneld -…"   5 weeks ago      Up 5 weeks                k8s_kube-flannel_canal-2nrf4_kube-system_be837c8a-b8d5-483f-af77-353dd957a9f5_8
8e126e2871b9   5a3c598c81d5                           "start_runit"            5 weeks ago      Up 5 weeks                k8s_calico-node_canal-2nrf4_kube-system_be837c8a-b8d5-483f-af77-353dd957a9f5_9
d7b71b099dc2   acd7606e832d                           "/usr/bin/dumb-init …"   5 weeks ago      Up 5 weeks                k8s_nginx-ingress-controller_nginx-ingress-controller-4fgcl_ingress-nginx_765f4040-0ac6-4b1b-a3c1-6be0085596d6_8
0ff0d1f5fee7   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_rancher-f86cb5d54-qdgk5_cattle-system_5d4a714b-9543-4509-9c54-a049373d2e08_4
9736909b0ae2   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_rancher-f86cb5d54-r5nq8_cattle-system_a34ec0d3-2b55-4a1f-b6c3-e9c6ccd71592_3
bf37749ffb98   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_nginx-ingress-controller-4fgcl_ingress-nginx_765f4040-0ac6-4b1b-a3c1-6be0085596d6_8
7b593ad84e78   rancher/pause:3.2                      "/pause"                 5 weeks ago      Up 5 weeks                k8s_POD_canal-2nrf4_kube-system_be837c8a-b8d5-483f-af77-353dd957a9f5_8
c18e57e97c3c   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 5 weeks                kube-proxy
26ead089c687   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 5 weeks                kubelet
83a117a54495   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 5 weeks                kube-scheduler
287163591e4e   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 5 weeks                kube-controller-manager
a2c0c2d61476   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 5 weeks                kube-apiserver
7bfaebeebdd3   rancher/rke-tools:v0.1.72              "/docker-entrypoint.…"   5 years ago      Up 5 weeks                etcd-rolling-snapshots
e1d437da8886   rancher/coreos-etcd:v3.4.14-rancher1   "/usr/local/bin/etcd…"   5 years ago      Up 5 weeks                etcd
```

```bash
[root@rancher2 ~]# docker logs -f etcd --tail 50
2026-10-08 06:40:43.307922 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:46.386687 W | etcdserver: failed to reach the peerURL(https://10.11.133.88:2380) of member 1b77b20a79efe7b (Get https://10.11.133.88:2380/version: dial tcp 10.11.133.88:2380: connect: connection refused)
2026-10-08 06:40:46.386728 W | etcdserver: cannot get the version of member 1b77b20a79efe7b (Get https://10.11.133.88:2380/version: dial tcp 10.11.133.88:2380: connect: connection refused)
2026-10-08 06:40:48.308073 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:48.308131 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:50.388102 W | etcdserver: failed to reach the peerURL(https://10.11.133.88:2380) of member 1b77b20a79efe7b (Get https://10.11.133.88:2380/version: dial tcp 10.11.133.88:2380: connect: connection refused)
2026-10-08 06:40:50.388136 W | etcdserver: cannot get the version of member 1b77b20a79efe7b (Get https://10.11.133.88:2380/version: dial tcp 10.11.133.88:2380: connect: connection refused)
2026-10-08 06:40:53.308431 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:53.308535 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:54.389418 W | etcdserver: failed to reach the peerURL(https://10.11.133.88:2380) of member 1b77b20a79efe7b (Get https://10.11.133.88:2380/version: dial tcp 10.11.133.88:2380: connect: connection refused)
2026-10-08 06:40:54.389452 W | etcdserver: cannot get the version of member 1b77b20a79efe7b (Get https://10.11.133.88:2380/version: dial tcp 10.11.133.88:2380: connect: connection refused)
2026-10-08 06:40:58.236129 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2026-10-08 06:40:58.308643 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
……（以下内容相同，每 4~5 秒重复一次，略）
2026-10-08 06:41:28.232652 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2026-10-08 06:41:38.404819 W | etcdserver: cannot get the version of member 1b77b20a79efe7b (Get https://10.11.133.88:2380/version: dial tcp 10.11.133.88:2380: connect: connection refused)
```

```bash
[root@rancher3 ~]# docker ps
CONTAINER ID   IMAGE                                  COMMAND                  CREATED          STATUS          PORTS     NAMES
a1b5e3515ff7   296a6d5035e2                           "/coredns -conf /etc…"   16 minutes ago   Up 16 minutes             k8s_coredns_coredns-7c49b8c54c-qdmzd_kube-system_2b1e47e7-3aeb-413f-84d1-9b1b9d7b8784_11
72dd918a1e4a   rancher/pause:3.2                      "/pause"                 16 minutes ago   Up 16 minutes             k8s_POD_coredns-7c49b8c54c-qdmzd_kube-system_2b1e47e7-3aeb-413f-84d1-9b1b9d7b8784_10
ceb75fc3241f   0bfefe9f649b                           "/opt/bin/flanneld -…"   18 minutes ago   Up 18 minutes             k8s_kube-flannel_canal-86558_kube-system_29cfc6c3-c11f-4806-9ec5-63c63c901f24_10
b79ca2d4177b   5a3c598c81d5                           "start_runit"            18 minutes ago   Up 18 minutes             k8s_calico-node_canal-86558_kube-system_29cfc6c3-c11f-4806-9ec5-63c63c901f24_9
ac9c3f7ecd2d   6fbb8bab37af                           "webhook"                18 minutes ago   Up 18 minutes             k8s_rancher-webhook_rancher-webhook-7ddb797ddb-kgp6s_cattle-system_7e59844b-eed1-446a-8fc1-82af3a1b840d_4
dae8bfbc17fa   b5af743e5984                           "/server"                18 minutes ago   Up 18 minutes             k8s_default-http-backend_default-http-backend-65dd5949d9-gc5sc_ingress-nginx_82ea54f0-bb03-4299-864e-824db610303d_12
0e138bcb2235   acd7606e832d                           "/usr/bin/dumb-init …"   18 minutes ago   Up 18 minutes             k8s_nginx-ingress-controller_nginx-ingress-controller-k5n5x_ingress-nginx_3378a5b5-4c1e-4413-9930-4057566d29e4_9
6d95b8412073   rancher/pause:3.2                      "/pause"                 18 minutes ago   Up 18 minutes             k8s_POD_rancher-webhook-7ddb797ddb-kgp6s_cattle-system_7e59844b-eed1-446a-8fc1-82af3a1b840d_5
ac0b7016d332   rancher/pause:3.2                      "/pause"                 18 minutes ago   Up 18 minutes             k8s_POD_default-http-backend-65dd5949d9-gc5sc_ingress-nginx_82ea54f0-bb03-4299-864e-824db610303d_15
2354407e69dd   59b927df412f                           "/usr/bin/kube-contr…"   18 minutes ago   Up 18 minutes             k8s_calico-kube-controllers_calico-kube-controllers-6c8ddcb6cd-sg7sz_kube-system_dcaf9d11-340d-4695-86be-c4f127182b18_12
9a0642636f37   rancher/pause:3.2                      "/pause"                 18 minutes ago   Up 18 minutes             k8s_POD_calico-kube-controllers-6c8ddcb6cd-sg7sz_kube-system_dcaf9d11-340d-4695-86be-c4f127182b18_21
4cf18592e1c0   rancher/pause:3.2                      "/pause"                 18 minutes ago   Up 18 minutes             k8s_POD_canal-86558_kube-system_29cfc6c3-c11f-4806-9ec5-63c63c901f24_9
5cadcd2b85eb   rancher/pause:3.2                      "/pause"                 18 minutes ago   Up 18 minutes             k8s_POD_nginx-ingress-controller-k5n5x_ingress-nginx_3378a5b5-4c1e-4413-9930-4057566d29e4_9
2d7207e5906f   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 19 minutes             kube-proxy
afba70860699   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 19 minutes             kubelet
d880d7f79680   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 19 minutes             kube-scheduler
bc4ffccdec5f   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 19 minutes             kube-controller-manager
04da540c3bc3   rancher/hyperkube:v1.20.4-rancher1     "/opt/rke-tools/entr…"   5 years ago      Up 19 minutes             kube-apiserver
1405d22b0768   rancher/rke-tools:v0.1.72              "/docker-entrypoint.…"   5 years ago      Up 19 minutes             etcd-rolling-snapshots
49063aaef5ae   rancher/coreos-etcd:v3.4.14-rancher1   "/usr/local/bin/etcd…"   5 years ago      Up 19 minutes             etcd
```

```bash
[root@rancher3 ~]# docker logs etcd --tail 50
2026-10-08 06:40:17.956650 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:22.951661 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:22.956816 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:27.951907 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:27.957026 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:28.232961 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2026-10-08 06:40:32.952172 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
2026-10-08 06:40:32.957226 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
……（以下内容相同，每 5 秒重复一次，略）
2026-10-08 06:41:58.229553 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2026-10-08 06:42:02.960683 W | rafthttp: health check for peer 1b77b20a79efe7b could not connect: dial tcp 10.11.133.88:2380: connect: connection refused
```

从这两台的输出可以看出：

- 两个成员自身 `/health OK`，只是持续报告连不上 peer `1b77b20a79efe7b`（即 10.11.133.88:2380）。说明它们本身正常，缺的只是 rancher1 这个成员。
- rancher2 的系统容器已运行 5 周；rancher3 的系统容器只运行了约 19 分钟，说明 rancher3 和 rancher1 几乎同时发生过重启。

### 3.4 诊断结论

1. **故障点**：rancher1 上 etcd 成员（member ID `1b77b20a79efe7b`）的 WAL 文件损坏，etcd 重放 WAL 时 CRC 校验失败，进程无法启动。
2. **集群状态**：剩余两个成员健康，2/3 满足 quorum，集群可正常读写。但已没有容错能力，再失去任何一个成员，etcd 就会失去 quorum，apiserver 无法写入。
3. **修复方式**：WAL 的 CRC 损坏无法原地修复（etcd 自带的 WAL 修复只能处理末尾记录被截断的情况）。标准做法是把该成员从集群移除，清空其数据目录，再作为新成员重新加入，由 leader 全量同步数据。

---

## 4. etcd 成员恢复过程

### 4.1 备份（rancher2 执行）

集群当前只剩两个健康成员，操作前必须先备份。

先确认成员列表和数据目录挂载关系：

```bash
[root@rancher2 ~]# docker exec etcd etcdctl member list -w table
+------------------+---------+-------------------+---------------------------+---------------------------+------------+
|        ID        | STATUS  |       NAME        |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER |
+------------------+---------+-------------------+---------------------------+---------------------------+------------+
|  1b77b20a79efe7b | started | etcd-10.11.133.88 | https://10.11.133.88:2380 | https://10.11.133.88:2379 |      false |
| 43ef60f42e51a4ad | started | etcd-10.11.133.90 | https://10.11.133.90:2380 | https://10.11.133.90:2379 |      false |
| 8c85a8c032918317 | started | etcd-10.11.133.89 | https://10.11.133.89:2380 | https://10.11.133.89:2379 |      false |
+------------------+---------+-------------------+---------------------------+---------------------------+------------+

[root@rancher2 ~]# docker inspect etcd --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'
/etc/kubernetes -> /etc/kubernetes
/var/lib/etcd -> /var/lib/rancher/etcd
```

故障成员 `1b77b20a79efe7b` 在列表中仍显示为 `started`。`member list` 里的 STATUS 只表示该成员曾经启动并加入过集群，不代表当前在线；成员是否健康要看 `endpoint health`。挂载关系与 RKE 默认值一致：宿主机 `/var/lib/etcd` 对应容器内 `/var/lib/rancher/etcd`。

手动打快照，并移出 etcd 数据目录：

```bash
[root@rancher2 ~]# docker exec etcd etcdctl snapshot save /var/lib/rancher/etcd/manual-$(date +%Y%m%d%H%M).db
{"level":"info","ts":1791442198.0195735,"caller":"snapshot/v3_snapshot.go:119","msg":"created temporary db file","path":"/var/lib/rancher/etcd/manual-202610081449.db.part"}
{"level":"info","ts":"2026-10-08T06:49:58.029Z","caller":"clientv3/maintenance.go:200","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":1791442198.0294216,"caller":"snapshot/v3_snapshot.go:127","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2026-10-08T06:49:58.813Z","caller":"clientv3/maintenance.go:208","msg":"completed snapshot read; closing"}
{"level":"info","ts":1791442199.159312,"caller":"snapshot/v3_snapshot.go:142","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"58 MB","took":1.139551408}
{"level":"info","ts":1791442199.159457,"caller":"snapshot/v3_snapshot.go:152","msg":"saved","path":"/var/lib/rancher/etcd/manual-202610081449.db"}
Snapshot saved at /var/lib/rancher/etcd/manual-202610081449.db

[root@rancher2 ~]# mkdir -p /root/etcd-backup && mv /var/lib/etcd/manual-*.db /root/etcd-backup/
[root@rancher2 ~]# ls
anaconda-ks.cfg  cloud-guest-tool  converter  etcd-backup
[root@rancher2 ~]# cd etcd-backup/
[root@rancher2 etcd-backup]# ls
manual-202610081449.db
```

确认 RKE 滚动快照是正常的：

```bash
[root@rancher2 etcd-backup]# ls -lht /opt/rke/etcd-snapshots/ | head
total 451M
-rw------- 1 root root 7.6M Oct  8 10:53 2026-10-08T02:53:37Z_etcd.zip
-rw------- 1 root root 7.5M Oct  8 04:53 2026-10-07T20:53:37Z_etcd.zip
-rw------- 1 root root 7.5M Oct  7 22:53 2026-10-07T14:53:37Z_etcd.zip
-rw------- 1 root root 7.6M Oct  7 16:53 2026-10-07T08:53:37Z_etcd.zip
-rw------- 1 root root 7.6M Oct  7 10:53 2026-10-07T02:53:37Z_etcd.zip
-rw------- 1 root root 7.6M Oct  7 04:53 2026-10-06T20:53:37Z_etcd.zip
-rw------- 1 root root 7.6M Oct  6 22:53 2026-10-06T14:53:37Z_etcd.zip
-rw------- 1 root root 7.6M Oct  6 16:53 2026-10-06T08:53:37Z_etcd.zip
-rw------- 1 root root 7.6M Oct  6 10:53 2026-10-06T02:53:37Z_etcd.zip
```

备份结果：

- 手动快照：rancher2 `/root/etcd-backup/manual-202610081449.db`，大小 58 MB，与 4.6 节中的 DB SIZE 一致。
- RKE 滚动快照每 6 小时一次，运行正常（文件名为 UTC 时间，文件修改时间为本地时间）。故障前最近一次自动快照为 10-08 10:53（本地时间），即重启前约 3.5 小时。

### 4.2 检查故障节点磁盘（rancher1 执行）

如果磁盘本身有问题，在坏盘上重建 etcd 没有意义，所以重建前先检查。

```bash
[root@rancher1 ~]# df -h /var/lib/etcd
Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/centos-root   50G  5.0G   46G  10% /

[root@rancher1 ~]# dmesg -T | grep -iE 'i/o error|xfs|ext4|blk_update|corrupt' | tail -20
[Thu Oct  8 14:24:48 2026] SGI XFS with ACLs, security attributes, no debug enabled
[Thu Oct  8 14:24:48 2026] XFS (dm-0): Mounting V5 Filesystem
[Thu Oct  8 14:24:49 2026] XFS (dm-0): Ending clean mount
[Thu Oct  8 14:24:51 2026] XFS (vda1): Mounting V5 Filesystem
[Thu Oct  8 14:24:51 2026] XFS (vda1): Ending clean mount
[Thu Oct  8 14:24:52 2026] XFS (dm-2): Mounting V5 Filesystem
[Thu Oct  8 14:24:52 2026] XFS (dm-2): Ending clean mount

[root@rancher1 ~]# last -x | grep -E 'reboot|shutdown' | head
reboot   system boot  3.10.0-1160.21.1 Thu Oct  8 14:24 - 16:13  (01:49)
shutdown system down  3.10.0-1160.21.1 Thu Oct  8 14:24 - 14:24  (00:00)
reboot   system boot  3.10.0-1160.21.1 Fri Aug 28 22:53 - 14:24 (40+15:31)
reboot   system boot  3.10.0-1160.21.1 Sun Jul  5 21:39 - 14:24 (94+16:45)
reboot   system boot  3.10.0-1160.21.1 Wed Mar  4 16:34 - 14:24 (217+21:49)
reboot   system boot  3.10.0-1160.21.1 Fri Mar 28 23:01 - 14:24 (558+15:22)
reboot   system boot  3.10.0-1160.21.1 Thu Mar 27 16:06 - 14:24 (559+22:17)
reboot   system boot  3.10.0-1160.21.1 Tue Mar  4 16:33 - 14:24 (582+21:51)
reboot   system boot  3.10.0-1160.21.1 Wed Apr 17 19:39 - 14:24 (903+18:45)
reboot   system boot  3.10.0-1160.21.1 Wed Jun 14 10:43 - 14:24 (1212+03:41)
```

检查结论：

- **磁盘空间**：etcd 数据目录所在的根分区（`/dev/mapper/centos-root`）使用率 10%，空间充足，排除磁盘写满的可能。
- **文件系统**：本次启动后各 XFS 分区挂载时都是 `Ending clean mount`，说明上次关机时文件系统是正常卸载的，不需要日志回放；本次启动以来没有 I/O 错误。需要注意，dmesg 只覆盖当前启动周期，关机前是否出现过 I/O 报错，要查 `/var/log/messages`（见 6.2 节）。
- **本次重启**：10-08 14:24 有一条 `shutdown` 记录，紧接着 14:24 开机，说明这次是**系统正常关机后立即重启**（`reboot` 命令或虚拟化平台通过 guest 工具发起的正常关机），不是掉电或强制断电。停机时间不到 1 分钟。
- **历史重启**：`last` 输出中没有年份，按持续天数倒推，此前的重启时间为 2026-08-28、2026-07-05、2026-03-04、2025-03-28、2025-03-27、2025-03-04、2024-04-17、2023-06-14。这些重启之前都没有对应的 `shutdown` 记录，通常意味着是非正常重启（掉电、强制断电或系统崩溃）。
- 磁盘与文件系统没有发现异常，可以在原磁盘上重建 etcd 成员。

### 4.3 停止故障成员并移走旧数据（rancher1 执行）

```bash
[rancher@rancher1 ~]$ docker update --restart=no etcd
etcd
[rancher@rancher1 ~]$ docker stop etcd
etcd
```

`docker update --restart=no` 用于关闭自动重启，防止停掉后又被 docker 拉起。随后以 root 移走旧数据（`mv` 命令无输出）：

```bash
mv /var/lib/etcd/member /root/etcd-member-bak-$(date +%Y%m%d)
```

这里只移走 `member` 子目录，`/var/lib/etcd` 目录本身保留，这样属主和权限不会变。损坏的旧数据保留在 rancher1 的 `/root/etcd-member-bak-20261008`。后续新成员能正常加入并同步，也间接证明旧的 member 数据已经移走（否则新容器仍会读到损坏的 WAL 并报同样的错误）。

### 4.4 移除旧成员并重新加入（rancher2 执行）

```bash
[root@rancher2 etcd-backup]# docker exec etcd etcdctl member remove 1b77b20a79efe7b
Member  1b77b20a79efe7b removed from cluster 3536cf50d6a7a7ad

[root@rancher2 etcd-backup]# docker exec etcd etcdctl member add etcd-10.11.133.88 --peer-urls=https://10.11.133.88:2380
Member 6211bcec6bffb393 added to cluster 3536cf50d6a7a7ad

ETCD_NAME="etcd-10.11.133.88"
ETCD_INITIAL_CLUSTER="etcd-10.11.133.90=https://10.11.133.90:2380,etcd-10.11.133.88=https://10.11.133.88:2380,etcd-10.11.133.89=https://10.11.133.89:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.11.133.88:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

注意事项：

- 成员名必须与 etcd 容器启动参数里的 `--name` 一致，即 `etcd-10.11.133.88`，可以从 3.2 节的日志 `embed: name = etcd-10.11.133.88` 确认。
- member add 之后集群有 3 个成员、2 个在线，quorum（2）仍然满足。但新成员要尽快启动，不要在这个状态停留太久。
- 新成员的 member ID 为 `6211bcec6bffb393`。

### 4.5 以 existing 模式重建 etcd 容器（rancher1 执行）

**为什么不能直接启动原容器**：RKE 首次创建集群时，etcd 容器的启动参数是 `--initial-cluster-state=new`。数据目录清空后，如果仍以 `new` 启动，etcd 会按引导新集群的逻辑计算 member ID，算出来的 ID 与 member add 分配的 ID（`6211bcec6bffb393`）对不上，无法加入现有集群。而 docker 容器创建后启动参数不能修改，所以把原容器改名为 `etcd-old` 保留，按它的镜像、环境变量、挂载和参数重建一个新容器，只把这一个参数改为 `existing`。

```bash
docker rename etcd etcd-old

IMG=$(docker inspect etcd-old --format '{{.Config.Image}}')
ENTRY=$(docker inspect etcd-old --format '{{.Path}}')
ENVS=$(docker inspect etcd-old --format '{{range .Config.Env}}-e {{.}} {{end}}')
BINDS=$(docker inspect etcd-old --format '{{range .HostConfig.Binds}}-v {{.}} {{end}}')
ARGS=$(docker inspect etcd-old --format '{{range .Args}}{{.}} {{end}}' \
       | sed 's/--initial-cluster-state=new/--initial-cluster-state=existing/')
```

启动前检查关键参数：

```bash
[root@rancher1 ~]# echo "$ARGS" | tr ' ' '\n' | grep -E 'initial-cluster|--name'
--initial-cluster-state=existing
--name=etcd-10.11.133.88
--initial-cluster-token=etcd-cluster-1
--initial-cluster=etcd-10.11.133.88=https://10.11.133.88:2380,etcd-10.11.133.89=https://10.11.133.89:2380,etcd-10.11.133.90=https://10.11.133.90:2380
```

检查要点：`--initial-cluster-state=existing` 已生效（如果原参数里没有这一项，需要手动追加到 `$ARGS` 末尾）；`--initial-cluster` 包含三个节点；`--name` 正确。

启动新容器：

```bash
[root@rancher1 ~]# docker run -d --name etcd --net=host --restart=always \
>   $ENVS $BINDS --entrypoint "$ENTRY" "$IMG" $ARGS
ef2feedd1b8f20bec52285ff29871757cd954848823ddb8a0b3582bffb506e3e
```

启动后用 `docker logs -f etcd` 观察：正常情况下不再出现 crc 报错，能看到 `added member`、`published ... to cluster` 以及成为 follower 的 raft 日志。

> 备注：新容器不是由 RKE 创建的。以后执行 `rke up` 时，RKE 可能会按自己的模板重建这个容器；那时数据目录里已经有成员数据，`--initial-cluster-state` 参数会被忽略，不影响运行。

### 4.6 恢复验证

rancher2 上检查成员状态：

```bash
[root@rancher2 etcd-backup]# docker exec etcd etcdctl member list -w table
+------------------+---------+-------------------+---------------------------+---------------------------+------------+
|        ID        | STATUS  |       NAME        |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER |
+------------------+---------+-------------------+---------------------------+---------------------------+------------+
| 43ef60f42e51a4ad | started | etcd-10.11.133.90 | https://10.11.133.90:2380 | https://10.11.133.90:2379 |      false |
| 6211bcec6bffb393 | started | etcd-10.11.133.88 | https://10.11.133.88:2380 | https://10.11.133.88:2379 |      false |
| 8c85a8c032918317 | started | etcd-10.11.133.89 | https://10.11.133.89:2380 | https://10.11.133.89:2379 |      false |
+------------------+---------+-------------------+---------------------------+---------------------------+------------+

[root@rancher2 etcd-backup]# docker exec etcd etcdctl endpoint health --cluster
https://10.11.133.89:2379 is healthy: successfully committed proposal: took = 13.262273ms
https://10.11.133.88:2379 is healthy: successfully committed proposal: took = 15.742079ms
https://10.11.133.90:2379 is healthy: successfully committed proposal: took = 17.099341ms

[root@rancher2 etcd-backup]# docker exec etcd etcdctl endpoint status --cluster -w table
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.11.133.90:2379 | 43ef60f42e51a4ad |  3.4.14 |   58 MB |     false |      false |     17459 |  851614964 |          851614964 |        |
| https://10.11.133.88:2379 | 6211bcec6bffb393 |  3.4.14 |   58 MB |     false |      false |     17459 |  851614964 |          851614964 |        |
| https://10.11.133.89:2379 | 8c85a8c032918317 |  3.4.14 |   58 MB |      true |      false |     17459 |  851614964 |          851614964 |        |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

nginx02 上检查组件状态：

```bash
[root@glfzjh ~]# kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```

验证结论：

- 三个成员均为 `started`，`endpoint health` 全部 healthy。
- 三个成员的 RAFT TERM（17459）、RAFT INDEX 和 RAFT APPLIED INDEX（851614964）完全一致，DB SIZE 都是 58 MB，说明新成员已从 leader（10.11.133.89）完成全量同步。
- `kubectl get cs` 全部 Healthy，集群恢复了一个节点的容错能力。

### 4.7 收尾

次日（2026-10-09）检查 rancher1 上的 etcd 相关容器：

```bash
[root@rancher1 ~]# docker ps -a|grep etcd
ef2feedd1b8f   rancher/coreos-etcd:v3.4.14-rancher1   "/usr/local/bin/etcd…"   16 hours ago   Up 16 hours                           etcd
04972378c00e   rancher/rke-tools:v0.1.72              "/docker-entrypoint.…"   5 years ago    Up 19 hours                           etcd-rolling-snapshots
458a10fab611   rancher/coreos-etcd:v3.4.14-rancher1   "/usr/local/bin/etcd…"   5 years ago    Exited (1) 16 hours ago               etcd-old
```

- 新建的 etcd 容器（`ef2feedd1b8f`，即 4.5 节 `docker run` 返回的容器 ID）已稳定运行 16 小时。
- 旧容器 `etcd-old`（`458a10fab611`）处于 `Exited (1)` 状态，尚未删除。
- `etcd-rolling-snapshots` 自 14:24 开机后一直运行（19 小时），与新 etcd 的运行时长相差约 3 小时，由此推算容器重建发生在 10-08 约 17 时前后。

新 etcd 已稳定运行，可以删除旧容器：

```bash
# rancher1：再确认新 etcd 的日志没有持续的报错
docker logs --tail 30 etcd

# 删除旧容器
docker rm etcd-old
```

备份的保留安排：

| 备份 | 位置 | 处理建议 |
|---|---|---|
| 损坏的旧成员数据 | rancher1 `/root/etcd-member-bak-20261008` | 确认运行稳定几天后删除 |
| 故障期间的手动快照 | rancher2 `/root/etcd-backup/manual-202610081449.db` | 拷贝一份到集群外保存 |

---

## 5. 找回 cluster.yml 与 cluster.rkestate

### 5.1 背景

local 集群当初是在 nginx02 上用 rke 安装的。nginx02 原虚拟机损坏后换成了新虚拟机，原来的 `cluster.yml`、`cluster.rkestate` 和 `kube_config_cluster.yml` 都已丢失，nginx02 上只剩一份由 Rancher 生成的 kubeconfig（token 已脱敏）：

```yaml
apiVersion: v1
kind: Config
clusters:
- name: "local"
  cluster:
    server: "https://rancher.shufe-zj.edu.cn/k8s/clusters/local"
    certificate-authority-data: "<略>"
users:
- name: "local"
  user:
    token: "kubeconfig-user-w2hfd:<已脱敏>"
contexts:
- name: "local"
  context:
    user: "local"
    cluster: "local"
current-context: "local"
```

这种状态有两个风险：

- 这份 kubeconfig 经由 Rancher 代理访问 local 集群。Rancher 服务本身不可用时（local 集群出问题时恰恰最可能如此），就无法访问集群。
- 没有 `cluster.yml` 和 `cluster.rkestate`，就无法执行 `rke up`，证书轮换、节点替换、版本升级等操作都做不了。

### 5.2 原理

RKE（v0.2.0 起）除了在本地生成 `cluster.rkestate` 文件，还会在集群里保存一份完整状态：`kube-system` 命名空间下名为 `full-cluster-state` 的对象。较早的 RKE 版本把它存为 ConfigMap（内容是明文 JSON），较新的版本改为 Secret（需要 base64 解码）。**本环境（2021 年用 RKE v1.2.x 安装）实际存放在 ConfigMap 中。**

状态文件的主要结构：

| 字段 | 内容 |
|---|---|
| `currentState.rkeConfig` | 当前生效的完整集群配置，即 `cluster.yml` 的内容，并已补全默认值 |
| `currentState.certificatesBundle` | 集群全部证书和私钥（包括 kube-ca、kube-admin 等），其中 `kube-admin` 条目附带一份现成的 kubeconfig |
| `desiredState` | 结构与 currentState 相同 |

`cluster.yml` 本身没有原样保存在集群里，需要根据 `rkeConfig` 反推重写。

### 5.3 导出 cluster.rkestate（nginx02 执行）

本环境实际执行的命令（从 ConfigMap 导出）：

```text
[root@glfzjh ~]# mkdir -p /root/rke-local && cd /root/rke-local && umask 077
[root@glfzjh rke-local]# kubectl -n kube-system get configmap full-cluster-state \
>    -o jsonpath='{.data.full-cluster-state}' > cluster.rkestate
[root@glfzjh rke-local]# ls
cluster.rkestate
[root@glfzjh rke-local]# cat cluster.rkestate
{"desiredState":{"rkeConfig":{"nodes":[{"address":"10.11.133.88","port":"22","internalAddress":"10.11.133.88","role":["controlplane","worker","etcd"],"hostnameOverride":"10.11.133.88","user":"rancher","sshKeyPath":"~/.ssh/id_rsa"},{"address":"10.11.133.89","port":"22","internalAdd......
```

（`cat` 输出过长，此处截断；文件中包含全部证书私钥，不应完整打印或外传。）

如果是较新 RKE 版本安装的集群，状态存放在 Secret 中，导出命令为：

```bash
kubectl -n kube-system get secret full-cluster-state \
  -o jsonpath='{.data.full-cluster-state}' | base64 -d > cluster.rkestate
```

可选的校验命令（打印 k8s 版本和节点列表）：

```bash
python -c "import json;s=json.load(open('cluster.rkestate'))['currentState']['rkeConfig'];print(s.get('kubernetesVersion'));print([n['address'] for n in s['nodes']])"
```

### 5.4 生成直连 apiserver 的 kubeconfig（nginx02 执行）

从状态文件中取出 kube-admin 的 kubeconfig，直接连接 apiserver 的 6443 端口，不依赖 Rancher：

```text
[root@glfzjh rke-local]# python -c "import json;print(json.load(open('cluster.rkestate'))['currentState']['certificatesBundle']['kube-admin']['config'])" > kube_config_cluster.yml
[root@glfzjh rke-local]#
[root@glfzjh rke-local]# kubectl --kubeconfig kube_config_cluster.yml get nodes
NAME           STATUS   ROLES                      AGE      VERSION
10.11.133.88   Ready    controlplane,etcd,worker   5y199d   v1.20.4
10.11.133.89   Ready    controlplane,etcd,worker   5y199d   v1.20.4
10.11.133.90   Ready    controlplane,etcd,worker   5y199d   v1.20.4
```

直连成功，说明导出的状态文件完整，其中的证书有效。kubeconfig 里的 server 地址可以用 `grep server kube_config_cluster.yml` 查看；nginx02 需要能访问节点的 6443 端口。

### 5.5 导出 rkeConfig（nginx02 执行）

```text
[root@glfzjh rke-local]# python -c "import json;print(json.dumps(json.load(open('cluster.rkestate'))['currentState']['rkeConfig'],indent=2,sort_keys=True))" > rkeconfig.json
[root@glfzjh rke-local]# ls
cluster.rkestate  kube_config_cluster.yml  rkeconfig.json
```

`rkeconfig.json` 的完整内容见附录 A。从中提取的关键配置：

| 配置项 | 值 |
|---|---|
| cluster_name | local |
| kubernetes_version | v1.20.4-rancher1-1 |
| 节点 SSH 用户 / 端口 / 私钥 | rancher / 22 / `~/.ssh/id_rsa` |
| 网络插件 | canal（vxlan，端口 8472） |
| Service 网段 / Pod 网段 / 集群 DNS | 10.43.0.0/16 / 10.42.0.0/16 / 10.43.0.10 |
| etcd 自定义参数 | auto-compaction-retention=240，quota-backend-bytes=6442450944（6 GB），heartbeat 500ms，election 5000ms |
| etcd 自动备份 | 开启，每 6 小时一次，保留 60 份 |
| kube-apiserver 审计日志 | 开启（默认参数） |
| ingress | nginx，无自定义 options |

### 5.6 重建 cluster.yml

**转换规则**

rkeConfig 不能直接从 JSON 转成 YAML 使用，需要手工转换：

1. **字段名格式不同。** rkestate 中是驼峰命名，cluster.yml 要求下划线命名。主要对照如下：

   | rkestate（JSON） | cluster.yml（YAML） |
   |---|---|
   | `kubernetesVersion` | `kubernetes_version` |
   | `sshKeyPath` | `ssh_key_path` |
   | `hostnameOverride` / `internalAddress` | `hostname_override` / `internal_address` |
   | `services.kubeApi` / `services.kubeController` | `services.kube-api` / `services.kube-controller` |
   | `extraArgs` | `extra_args` |
   | `backupConfig.intervalHours` | `backup_config.interval_hours` |
   | `serviceClusterIpRange` / `clusterCidr` | `service_cluster_ip_range` / `cluster_cidr` |
   | `systemImages` | `system_images` |

   RKE 解析 cluster.yml 时，对拼错的字段名一般不会报错，而是按默认值处理，所以转换后要仔细核对，并用 5.7 节的方式验证。

2. **省略默认值。** RKE 自动补全的默认项都没有写入，例如 dns 的 autoscaler 参数、ingress 的端口与网络模式、审计日志的具体参数、kubelet 的 infra 镜像、`prefix_path` 等。不写的话，RKE 会按同样的值补回来。

3. **不复制 `RKE_AUDITLOG_CONFIG_CHECKSUM`。** `services.kubeApi.extraEnv` 中的这个变量是 RKE 根据审计配置自动生成的，状态里重复了 6 次，是历次执行 `rke up` 累积下来的，手工写进去没有意义。

4. **写死 `kubernetes_version`。** 防止以后用别的 rke 版本执行 `rke up` 时把 k8s 升级到其默认版本。

5. **钉死 `system_images`。** 写的是集群当前实际在用的镜像，只保留 canal、coredns、nginx ingress、metrics-server 及核心组件用到的项，其余由 RKE 按版本补全。不同版本的 rke 对同一个 k8s 版本内置的配套镜像可能不同，钉死之后 rke 不会去拉新镜像。节点不一定能访问 Docker Hub，拉镜像失败会让 `rke up` 卡在半路。

6. **ingress 没有自定义 options。** 如果线上 `ingress-nginx` 命名空间里的 ConfigMap 有自定义内容，那就是后来手工改的，执行 `rke up` 前要先补进 `ingress.options`，否则会被覆盖。

**cluster.yml 完整内容**（保存为 nginx02 的 `/root/rke-local/cluster.yml`）：

```yaml
# local 集群 (Rancher 2.5.7) —— 由 cluster.rkestate 的 currentState.rkeConfig 反推
# 必须与 cluster.rkestate 放在同一目录,且文件名前缀一致(cluster.yml <-> cluster.rkestate)
# 使用 RKE v1.2.x,不要用更新的 rke 跑 rke up

cluster_name: local
kubernetes_version: v1.20.4-rancher1-1   # 必须写死,否则 rke up 会升级 k8s
ssh_key_path: ~/.ssh/id_rsa
addon_job_timeout: 45

nodes:
  - address: 10.11.133.88
    internal_address: 10.11.133.88
    hostname_override: 10.11.133.88
    port: "22"
    user: rancher
    role: [controlplane, worker, etcd]
  - address: 10.11.133.89
    internal_address: 10.11.133.89
    hostname_override: 10.11.133.89
    port: "22"
    user: rancher
    role: [controlplane, worker, etcd]
  - address: 10.11.133.90
    internal_address: 10.11.133.90
    hostname_override: 10.11.133.90
    port: "22"
    user: rancher
    role: [controlplane, worker, etcd]

services:
  etcd:
    snapshot: true
    backup_config:
      enabled: true
      interval_hours: 6
      retention: 60
    extra_args:
      auto-compaction-retention: "240"
      election-timeout: "5000"
      heartbeat-interval: "500"
      quota-backend-bytes: "6442450944"
  kube-api:
    service_cluster_ip_range: 10.43.0.0/16
    service_node_port_range: 30000-32767
    audit_log:
      enabled: true          # 其余审计参数与 RKE 默认值一致,不必写出
  kube-controller:
    cluster_cidr: 10.42.0.0/16
    service_cluster_ip_range: 10.43.0.0/16
  kubelet:
    cluster_domain: cluster.local
    cluster_dns_server: 10.43.0.10

network:
  plugin: canal

dns:
  provider: coredns

ingress:
  provider: nginx

monitoring:
  provider: metrics-server

authentication:
  strategy: x509

authorization:
  mode: rbac

# 钉死为集群当前实际在用的镜像,避免 rke 元数据不同导致去拉新镜像
system_images:
  kubernetes: rancher/hyperkube:v1.20.4-rancher1
  etcd: rancher/coreos-etcd:v3.4.14-rancher1
  alpine: rancher/rke-tools:v0.1.72
  nginx_proxy: rancher/rke-tools:v0.1.72
  cert_downloader: rancher/rke-tools:v0.1.72
  kubernetes_services_sidecar: rancher/rke-tools:v0.1.72
  pod_infra_container: rancher/pause:3.2
  coredns: rancher/coredns-coredns:1.8.0
  coredns_autoscaler: rancher/cluster-proportional-autoscaler:1.8.1
  canal_node: rancher/calico-node:v3.17.2
  canal_cni: rancher/calico-cni:v3.17.2
  canal_controllers: rancher/calico-kube-controllers:v3.17.2
  canal_flannel: rancher/coreos-flannel:v0.13.0-rancher1
  canal_flexvol: rancher/calico-pod2daemon-flexvol:v3.17.2
  ingress: rancher/nginx-ingress-controller:nginx-0.43.0-rancher1
  ingress_backend: rancher/nginx-ingress-controller-defaultbackend:1.5-rancher1
  metrics_server: rancher/metrics-server:v0.4.1
```

### 5.7 可用性验证（待执行）

以下步骤用一个不改动集群的操作，把整条链路（配置文件、状态文件、SSH、镜像）验证一遍。

**第 1 步：准备 rke 二进制。** 集群是 2021 年 3 月用 RKE v1.2.x 安装的，建议先试 v1.2.6 或 v1.2.7，从 GitHub 的 rancher/rke Releases 页面下载 `rke_linux-amd64`。

```bash
./rke --version
./rke config --list-version --all | grep v1.20.4-rancher1-1      # 必须能列出这个版本
./rke config --system-images --version v1.20.4-rancher1-1        # 与附录 A 中的 systemImages 对比
```

**第 2 步：配置 SSH 免密登录。** 原私钥随旧 VM 一起丢失，需要在新 nginx02 上重新生成，并把公钥加到三台节点 `rancher` 用户的 `authorized_keys` 中：

```bash
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
for ip in 88 89 90; do ssh-copy-id rancher@10.11.133.$ip; done
for ip in 88 89 90; do ssh rancher@10.11.133.$ip 'docker version --format {{.Server.Version}}'; done
```

前提条件：`rancher` 用户在节点的 docker 组中；节点 sshd 配置为 `AllowTcpForwarding yes`（RKE 通过 SSH 转发访问节点的 docker.sock，如果安全加固时关闭了转发，会报 tunnel 相关错误）。

**第 3 步：用 etcd 快照做端到端验证。** 这个操作不改动集群：

```bash
cd /root/rke-local
./rke etcd snapshot-save --config cluster.yml --name verify-$(date +%Y%m%d)
```

该命令会读取 `cluster.yml` 和 `cluster.rkestate`，通过 SSH 连接三台节点，用 rke-tools 镜像打一个快照，快照保存在各节点的 `/opt/rke/etcd-snapshots/`。执行成功即说明配置文件、状态文件、SSH 和镜像全部可用。

### 5.8 执行 rke up 前的注意事项

平时不需要执行 `rke up`，这几个文件主要是留作备用，用于证书轮换、节点替换等场景。真正需要执行时，注意以下几点：

1. **rke 版本**：使用 RKE v1.2.x，并确认 `kubernetes_version` 已写死。如果用新版 rke 又没写死版本，`rke up` 会把 k8s 升级到其默认版本，而 Rancher 2.5.7 不支持更高版本的 k8s。
2. **文件位置**：`cluster.yml` 与 `cluster.rkestate` 必须同名、放在同一目录。
3. **手工改动会被覆盖**：rkestate 记录的是最后一次执行 `rke up` 时的配置。如果之后手工修改过 RKE 管理的资源（如 ingress-nginx 的 ConfigMap 或 DaemonSet 参数、kube-system 下的 addon），`rke up` 会按 cluster.yml 覆盖回去，必须先把改动写进 cluster.yml。
4. **先备份**：执行前先打一个 etcd 快照。

### 5.9 文件清单与保管

| 文件 | 位置 | 说明 |
|---|---|---|
| `cluster.rkestate` | nginx02 `/root/rke-local/` | 含 kube-ca 在内全部证书的私钥，等同于集群最高权限 |
| `cluster.yml` | nginx02 `/root/rke-local/` | 根据 rkeConfig 重建 |
| `kube_config_cluster.yml` | nginx02 `/root/rke-local/` | kube-admin 直连 kubeconfig，集群管理员权限 |
| `rkeconfig.json` | nginx02 `/root/rke-local/` | rkeConfig 导出，仅供参考 |

以上文件权限应为 600（导出时已设置 `umask 077`）。

还要注意：集群里的 ConfigMap `kube-system/full-cluster-state` 本身就以明文保存着全部证书私钥，任何能读取 `kube-system` 命名空间 ConfigMap 的账号，都能借此拿到集群管理员权限。需要确认只有管理员账号具备这项权限。

整个 `/root/rke-local` 目录（建议连同 rke 二进制一起）需要打包保存到 nginx02 以外的地方。这次文件丢失，就是因为只放在了一台机器上。

---

## 6. 根因分析与影响评估

### 6.1 直接原因

rancher1 上 etcd 的 WAL 文件中存在 CRC 校验不通过的记录，etcd 启动重放 WAL 时报 `walpb: crc mismatch` 并退出。etcd 自带的 WAL 修复只能处理末尾记录被截断的情况，CRC 不一致无法自动修复，只能重建该成员。

### 6.2 触发因素分析

**已确认的事实**

- rancher1 于 10-08 14:24 系统正常关机并立即重启（`last -x` 有 shutdown 记录），停机不到 1 分钟。
- 开机时各 XFS 分区都是 clean mount，说明关机时文件系统正常卸载；开机后的内核日志里没有 I/O 错误；磁盘使用率 10%（4.2 节）。
- rancher3 在相近时间也发生了重启（排查时其系统容器已运行约 19 分钟）；rancher2 没有重启（系统容器已运行 5 周）。

**分析**

正常关机时，systemd 会停止 docker 服务，docker 再向各容器发送 SIGTERM，etcd 收到后会正常退出；文件系统也能正常卸载，这一点已经由 clean mount 证实。因此，这次 WAL 损坏不太像是关机过程中写入被打断造成的。

etcd 每写一条 WAL 记录都会 fsync，启动时从最近一次快照开始重放 WAL，并逐条校验 CRC。也就是说，损坏的记录可能早在关机前、etcd 正常运行期间就已经写坏了，只是运行中不会再读取这些记录，直到这次重启重放时才被发现。在操作系统层面一切正常、fsync 也正常返回的情况下出现这种数据错误，更可能来自底层存储，例如虚拟化平台的磁盘缓存策略、存储设备或存储链路的问题。这是根据现有证据做出的推断，需要在平台侧核实。

**背景：这批虚拟机曾多次非正常重启**

rancher1 此前在 2026-08-28、2026-07-05、2026-03-04、2025-03-28、2025-03-27、2025-03-04、2024-04-17、2023-06-14 的重启都没有对应的 shutdown 记录，属于非正常重启（掉电、强制断电或系统崩溃）。其中 2025-03-04 16:33 和 2026-03-04 16:34 两次重启时间几乎相同，可能与机房或平台的例行维护有关。rancher2 的系统容器运行时长（5 周）与 08-28 那次重启吻合，说明 rancher2 很可能也在那次一起重启过。频繁的非正常断电，会增加 etcd 这类对落盘要求很高的组件出现数据损坏的风险。

**待核实事项及命令**

1. rancher1：查看关机前后的系统日志，确认关机由谁发起，以及关机前是否出现过 I/O 报错。

   ```bash
   grep -E '^Oct  8 1[34]:' /var/log/messages | grep -iE 'shutdown|reboot|power|stopping|guest|i/o error|xfs|blk_update'
   ```

2. rancher3：检查重启记录和内核日志，确认重启时间，以及与 rancher1 的停机时间是否有重叠。

   ```bash
   last -x | grep -E 'reboot|shutdown' | head
   dmesg -T | grep -iE 'i/o error|xfs|blk_update|corrupt' | tail -20
   grep -E '^Oct  8 1[34]:' /var/log/messages | grep -iE 'shutdown|reboot|power|stopping|guest|i/o error|xfs|blk_update'
   ```

3. 虚拟化/云平台侧：查看 rancher1、rancher3 在 10-08 14:20 前后的虚拟机事件（关机或重启由谁发起、是否有宿主机迁移或故障），并确认虚拟机磁盘的缓存模式和存储健康状况。rancher2 的 `/root` 下有 `cloud-guest-tool` 目录，说明这些虚拟机装有云平台的 guest 工具，平台可以通过它向虚拟机发起正常关机。

### 6.3 影响评估

| 时间段 | etcd 状态 | 影响 |
|---|---|---|
| rancher1 停机期间（14:24，不到 1 分钟） | 如果与 rancher3 的停机时间重叠，只剩 1/3 成员，失去 quorum | apiserver 无法写入，已运行的业务 Pod 一般不受影响。是否发生需根据 rancher3 的重启时间核实 |
| rancher1 开机后至修复完成（14:24～约 17 时，约 2.5 小时） | 2/3 成员，quorum 正常 | 集群读写正常，业务不受影响，但没有容错能力 |
| 修复后 | 3/3 成员 | 恢复正常 |

数据未丢失：故障成员的数据由 leader 全量同步，恢复后三个成员的 RAFT INDEX 一致（851614964）。

---

## 7. 遗留事项

| 序号 | 事项 | 状态 |
|---|---|---|
| 1 | 查明 10-08 14:24 rancher1 正常关机由谁发起（系统日志、平台事件，见 6.2 节） | 待处理 |
| 2 | 检查 rancher3 的重启记录与日志，确认重启时间、与 rancher1 是否有停机重叠 | 待处理 |
| 3 | 在虚拟化平台侧检查虚拟机磁盘缓存模式与存储健康状况 | 待处理 |
| 4 | 查明历史多次非正常重启的原因（包括 2025、2026 年 3 月 4 日的两次） | 待评估 |
| 5 | rancher1 磁盘与文件系统检查 | 已完成，无异常（4.2 节） |
| 6 | 删除 rancher1 上的 `etcd-old` 容器 | 待处理（10-09 检查时仍为 Exited 状态） |
| 7 | 运行稳定几天后，删除 rancher1 的 `/root/etcd-member-bak-20261008` | 待处理 |
| 8 | 将 rancher2 `/root/etcd-backup/manual-202610081449.db` 拷贝到集群外保存 | 待处理 |
| 9 | 准备 RKE v1.2.x 二进制并核对镜像（5.7 节第 1 步） | 待处理 |
| 10 | 配置 nginx02 到三台节点的 SSH 免密登录（5.7 节第 2 步） | 待处理 |
| 11 | 执行 `rke etcd snapshot-save` 端到端验证（5.7 节第 3 步） | 待处理 |
| 12 | 将 `/root/rke-local` 打包保存到 nginx02 以外的地方 | 待处理 |
| 13 | 检查 `ingress-nginx` ConfigMap 是否有手工改动，如有则补进 cluster.yml | 待处理 |
| 14 | 确认只有管理员账号能读取 `kube-system` 的 ConfigMap（`full-cluster-state` 含全部私钥） | 待处理 |
| 15 | 删除并重新生成 Rancher API token `kubeconfig-user-w2hfd`（排查过程中曾外传） | 待处理 |
| 16 | `rancher-operator` ImagePullBackOff，已持续约 562 天 | 待评估 |
| 17 | 两个 rancher Pod 重启次数偏高（448 / 543 次） | 待评估 |

---

## 附录 A：rkeconfig.json 完整内容

```json
{
  "addonJobTimeout": 45,
  "authentication": {
    "strategy": "x509"
  },
  "authorization": {
    "mode": "rbac"
  },
  "bastionHost": {},
  "cloudProvider": {},
  "clusterName": "local",
  "dns": {
    "linearAutoscalerParams": {
      "coresPerReplica": 128,
      "min": 1,
      "nodesPerReplica": 4,
      "preventSinglePointFailure": true
    },
    "provider": "coredns",
    "updateStrategy": {
      "rollingUpdate": {
        "maxSurge": 0,
        "maxUnavailable": 1
      },
      "strategy": "RollingUpdate"
    }
  },
  "ignoreDockerVersion": false,
  "ingress": {
    "defaultBackend": true,
    "httpPort": 80,
    "httpsPort": 443,
    "networkMode": "hostNetwork",
    "provider": "nginx",
    "updateStrategy": {
      "rollingUpdate": {
        "maxUnavailable": 1
      },
      "strategy": "RollingUpdate"
    }
  },
  "kubernetesVersion": "v1.20.4-rancher1-1",
  "monitoring": {
    "provider": "metrics-server",
    "replicas": 1,
    "updateStrategy": {
      "rollingUpdate": {
        "maxSurge": "25%",
        "maxUnavailable": "25%"
      },
      "strategy": "RollingUpdate"
    }
  },
  "network": {
    "options": {
      "canal_flannel_backend_port": "8472",
      "canal_flannel_backend_type": "vxlan",
      "canal_flannel_backend_vni": "1",
      "canal_flex_volume_plugin_dir": "/usr/libexec/kubernetes/kubelet-plugins/volume/exec/nodeagent~uds"
    },
    "plugin": "canal",
    "updateStrategy": {
      "rollingUpdate": {
        "maxUnavailable": 1
      },
      "strategy": "RollingUpdate"
    }
  },
  "nodes": [
    {
      "address": "10.11.133.88",
      "hostnameOverride": "10.11.133.88",
      "internalAddress": "10.11.133.88",
      "port": "22",
      "role": [
        "controlplane",
        "worker",
        "etcd"
      ],
      "sshKeyPath": "~/.ssh/id_rsa",
      "user": "rancher"
    },
    {
      "address": "10.11.133.89",
      "hostnameOverride": "10.11.133.89",
      "internalAddress": "10.11.133.89",
      "port": "22",
      "role": [
        "controlplane",
        "worker",
        "etcd"
      ],
      "sshKeyPath": "~/.ssh/id_rsa",
      "user": "rancher"
    },
    {
      "address": "10.11.133.90",
      "hostnameOverride": "10.11.133.90",
      "internalAddress": "10.11.133.90",
      "port": "22",
      "role": [
        "controlplane",
        "worker",
        "etcd"
      ],
      "sshKeyPath": "~/.ssh/id_rsa",
      "user": "rancher"
    }
  ],
  "prefixPath": "/",
  "restore": {},
  "rotateEncryptionKey": false,
  "services": {
    "etcd": {
      "backupConfig": {
        "enabled": true,
        "intervalHours": 6,
        "retention": 60,
        "s3BackupConfig": null,
        "timeout": 300
      },
      "creation": "12h",
      "extraArgs": {
        "auto-compaction-retention": "240",
        "election-timeout": "5000",
        "heartbeat-interval": "500",
        "quota-backend-bytes": "6442450944"
      },
      "image": "rancher/coreos-etcd:v3.4.14-rancher1",
      "retention": "72h",
      "snapshot": true
    },
    "kubeApi": {
      "auditLog": {
        "configuration": {
          "format": "json",
          "maxAge": 30,
          "maxBackup": 10,
          "maxSize": 100,
          "path": "/var/log/kube-audit/audit-log.json",
          "policy": {
            "apiVersion": "audit.k8s.io/v1",
            "kind": "Policy",
            "metadata": {
              "creationTimestamp": null
            },
            "rules": [
              {
                "level": "Metadata"
              }
            ]
          }
        },
        "enabled": true
      },
      "extraEnv": [
        "RKE_AUDITLOG_CONFIG_CHECKSUM=856f426399fb14a50b78e721d15c168c",
        "RKE_AUDITLOG_CONFIG_CHECKSUM=856f426399fb14a50b78e721d15c168c",
        "RKE_AUDITLOG_CONFIG_CHECKSUM=856f426399fb14a50b78e721d15c168c",
        "RKE_AUDITLOG_CONFIG_CHECKSUM=856f426399fb14a50b78e721d15c168c",
        "RKE_AUDITLOG_CONFIG_CHECKSUM=856f426399fb14a50b78e721d15c168c",
        "RKE_AUDITLOG_CONFIG_CHECKSUM=856f426399fb14a50b78e721d15c168c"
      ],
      "image": "rancher/hyperkube:v1.20.4-rancher1",
      "serviceClusterIpRange": "10.43.0.0/16",
      "serviceNodePortRange": "30000-32767"
    },
    "kubeController": {
      "clusterCidr": "10.42.0.0/16",
      "image": "rancher/hyperkube:v1.20.4-rancher1",
      "serviceClusterIpRange": "10.43.0.0/16"
    },
    "kubelet": {
      "clusterDnsServer": "10.43.0.10",
      "clusterDomain": "cluster.local",
      "image": "rancher/hyperkube:v1.20.4-rancher1",
      "infraContainerImage": "rancher/pause:3.2"
    },
    "kubeproxy": {
      "image": "rancher/hyperkube:v1.20.4-rancher1"
    },
    "scheduler": {
      "image": "rancher/hyperkube:v1.20.4-rancher1"
    }
  },
  "sshAgentAuth": false,
  "sshKeyPath": "~/.ssh/id_rsa",
  "systemImages": {
    "aciCniDeployContainer": "noiro/cnideploy:5.1.1.0.1ae238a",
    "aciControllerContainer": "noiro/aci-containers-controller:5.1.1.0.1ae238a",
    "aciGbpServerContainer": "noiro/gbp-server:5.1.1.0.1ae238a",
    "aciHostContainer": "noiro/aci-containers-host:5.1.1.0.1ae238a",
    "aciMcastContainer": "noiro/opflex:5.1.1.0.1ae238a",
    "aciOpflexContainer": "noiro/opflex:5.1.1.0.1ae238a",
    "aciOpflexServerContainer": "noiro/opflex-server:5.1.1.0.1ae238a",
    "aciOvsContainer": "noiro/openvswitch:5.1.1.0.1ae238a",
    "alpine": "rancher/rke-tools:v0.1.72",
    "calicoCni": "rancher/calico-cni:v3.17.2",
    "calicoControllers": "rancher/calico-kube-controllers:v3.17.2",
    "calicoCtl": "rancher/calico-ctl:v3.17.2",
    "calicoFlexVol": "rancher/calico-pod2daemon-flexvol:v3.17.2",
    "calicoNode": "rancher/calico-node:v3.17.2",
    "canalCni": "rancher/calico-cni:v3.17.2",
    "canalControllers": "rancher/calico-kube-controllers:v3.17.2",
    "canalFlannel": "rancher/coreos-flannel:v0.13.0-rancher1",
    "canalFlexVol": "rancher/calico-pod2daemon-flexvol:v3.17.2",
    "canalNode": "rancher/calico-node:v3.17.2",
    "certDownloader": "rancher/rke-tools:v0.1.72",
    "coredns": "rancher/coredns-coredns:1.8.0",
    "corednsAutoscaler": "rancher/cluster-proportional-autoscaler:1.8.1",
    "dnsmasq": "rancher/k8s-dns-dnsmasq-nanny:1.15.10",
    "etcd": "rancher/coreos-etcd:v3.4.14-rancher1",
    "flannel": "rancher/coreos-flannel:v0.13.0-rancher1",
    "flannelCni": "rancher/flannel-cni:v0.3.0-rancher6",
    "ingress": "rancher/nginx-ingress-controller:nginx-0.43.0-rancher1",
    "ingressBackend": "rancher/nginx-ingress-controller-defaultbackend:1.5-rancher1",
    "kubedns": "rancher/k8s-dns-kube-dns:1.15.10",
    "kubednsAutoscaler": "rancher/cluster-proportional-autoscaler:1.8.1",
    "kubednsSidecar": "rancher/k8s-dns-sidecar:1.15.10",
    "kubernetes": "rancher/hyperkube:v1.20.4-rancher1",
    "kubernetesServicesSidecar": "rancher/rke-tools:v0.1.72",
    "metricsServer": "rancher/metrics-server:v0.4.1",
    "nginxProxy": "rancher/rke-tools:v0.1.72",
    "nodelocal": "rancher/k8s-dns-node-cache:1.15.13",
    "podInfraContainer": "rancher/pause:3.2",
    "weaveCni": "weaveworks/weave-npc:2.8.1",
    "weaveNode": "weaveworks/weave-kube:2.8.1",
    "windowsPodInfraContainer": "rancher/kubelet-pause:v0.1.6"
  },
  "upgradeStrategy": {
    "maxUnavailableControlplane": "1",
    "maxUnavailableWorker": "10%",
    "nodeDrainInput": {
      "gracePeriod": -1,
      "ignoreDaemonSets": true,
      "timeout": 120
    }
  }
}
```

## 附录 B：etcd 成员 ID 对照

etcd 集群 ID：`3536cf50d6a7a7ad`

| 节点 | 成员名 | 恢复前 member ID | 恢复后 member ID |
|---|---|---|---|
| 10.11.133.88（rancher1） | etcd-10.11.133.88 | `1b77b20a79efe7b`（已移除） | `6211bcec6bffb393` |
| 10.11.133.89（rancher2） | etcd-10.11.133.89 | `8c85a8c032918317` | 不变（恢复时为 leader） |
| 10.11.133.90（rancher3） | etcd-10.11.133.90 | `43ef60f42e51a4ad` | 不变 |

## 附录 C：常用 etcd 检查命令（RKE 环境，任一 etcd 节点执行）

```bash
docker exec etcd etcdctl member list -w table              # 成员列表
docker exec etcd etcdctl endpoint health --cluster         # 各成员健康状态
docker exec etcd etcdctl endpoint status --cluster -w table  # leader、RAFT INDEX、DB 大小
docker exec etcd etcdctl alarm list                        # 告警（如 NOSPACE）
docker logs --tail 100 etcd                                # etcd 日志
ls -lht /opt/rke/etcd-snapshots/ | head                    # RKE 滚动快照
```
