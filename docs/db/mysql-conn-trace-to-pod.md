# MySQL 连接反查 Kubernetes Pod 排查手册

> **适用场景**：MySQL（或任意数据库）部署在 K8s 集群外，集群内多个微服务共用同一个数据库账号连接。
> `processlist` 里只能看到被 SNAT 后的**节点 IP**，需要反查到具体是哪个 Pod 建立的连接。
>
> **适用环境**：Rancher RKE1 / Canal（Flannel+Calico）、docker 运行时。
> containerd 运行时把 `docker` 换成 `crictl` 即可（文中已给出对照命令）。

---

## 0. 本次案例的环境信息（模板，现场替换）

| 项 | 值 |
|---|---|
| MySQL 版本 | 8.0.26 |
| MySQL 地址端口 | `172.18.10.20:13306` ← **注意不是默认 3306** |
| 目标库 | `ds_wiki` |
| 共用账号 | `dataassets` |
| Pod 网段 | `10.42.0.0/16`（Canal 默认） |
| 涉及节点 | `172.18.10.14` = k8sworker03-new，`172.18.10.15` = k8sworker04-new |
| 现象 | 每个节点各 50 条 `Sleep` 连接 |

**开工前先确认三件事**，否则后面所有过滤条件都会写错：

```bash
# 1) MySQL 真实监听端口（不要想当然是 3306）
mysql -h <mysql_ip> -P <port> -u<user> -p -e "SELECT @@port, @@hostname, @@version;"

# 2) Pod 网段（用来区分"这是 Pod IP"还是"这是节点 IP"）
kubectl -n kube-system get cm rke-network-plugin -o yaml 2>/dev/null | grep -i cluster_cidr
# 或直接看一眼现有 Pod
kubectl get pods -A -o wide | head

# 3) 节点 IP 与节点名的对照表（后面反复要用，先存下来）
kubectl get nodes -o wide
```

---

## 1. MySQL 侧：先看连接从哪些 IP 来

### 1.1 按来源 IP 聚合

```sql
SELECT SUBSTRING_INDEX(host, ':', 1) AS src_ip,
       COUNT(*)                      AS conns,
       SUM(command = 'Sleep')        AS sleeping,
       MAX(time)                     AS max_idle
FROM information_schema.processlist
WHERE user = 'dataassets'
GROUP BY src_ip
ORDER BY conns DESC;
```

**本次实测输出：**

```
src_ip          conns   sleeping   max_idle
172.18.10.15      50        50        1780
172.18.10.14      50        50        1790
172.18.10.61      30        30        1560
172.18.10.63      10        10         368
172.18.10.26      10        10        1717
172.18.10.62      10        10         370
172.18.10.60      10        10        1481
```

### 1.2 明细（含源端口，第 3 步反查要用）

```sql
SELECT id, host, db, command, time, state
FROM information_schema.processlist
WHERE user = 'dataassets'
  AND command = 'Sleep'
  AND db = 'ds_wiki'
ORDER BY time DESC;
```

**本次实测输出（节选）：**

```
5089   172.18.10.15:55538   ds_wiki   Sleep   146
5093   172.18.10.14:17056   ds_wiki   Sleep   138
5099   172.18.10.14:62607   ds_wiki   Sleep   131
5102   172.18.10.14:1736    ds_wiki   Sleep   129
...
```

### 1.3 备用查询

```sql
-- 只看长时间空闲的（超过 10 分钟）
SELECT SUBSTRING_INDEX(host,':',1) AS ip, COUNT(*) AS idle_over_600
FROM information_schema.processlist
WHERE command='Sleep' AND time > 600
GROUP BY ip ORDER BY 2 DESC;

-- 全库全用户的连接分布（不限 dataassets），用来和 conntrack 结果对账
SELECT user, SUBSTRING_INDEX(host,':',1) AS ip, db, COUNT(*)
FROM information_schema.processlist
GROUP BY user, ip, db ORDER BY 4 DESC;

user	ip	db	COUNT(*)
portal_service_v6	172.18.10.14	portal_service_v6	65
dataassets	172.18.10.14	ds_wiki	50
cas_server_dev	172.18.10.14	cas_server_dev	15
api_arrange	172.18.10.14	api_arrange	10
formflow	172.18.10.14	formflow	9
user	172.18.10.14	user	9
user_authz_1_5_0	172.18.10.14	user_authz_1_5_0	6
developer_center	172.18.10.14	developer_center	5
message	172.18.10.14	data_view_tpl_data	5
personal_service_dev	172.18.10.14	personal_service_dev	2
authx_kri_dev2	172.18.10.14	authx_kri_dev2	2
platform_openapi	172.18.10.14	platform_openapi	1
portal_service_v6	172.18.10.15	portal_service_v6	20
portal_service_v6	172.18.10.15	datavines	12
portal_service_v6	172.18.10.15	wisdombrain-standard-local	12
portal_service_v6	172.18.10.15	wisdombrain-model	12
portal_service_v6	172.18.10.15	wisdombrain-code	12
platform_openapi	172.18.10.15	platform_openapi	10
admin_center	172.18.10.15	admin_center	5


-- 连接总量水位
SHOW VARIABLES LIKE 'wait_timeout';
SHOW VARIABLES LIKE 'interactive_timeout';
SELECT @@max_connections,
       (SELECT VARIABLE_VALUE FROM performance_schema.global_status
        WHERE VARIABLE_NAME='Threads_connected')     AS now_conns,
       (SELECT VARIABLE_VALUE FROM performance_schema.global_status
        WHERE VARIABLE_NAME='Max_used_connections')  AS peak;
        
Variable_name	Value
wait_timeout	28800

-- 客户端驱动信息（区分不出 Pod，但能区分驱动/语言）
SELECT t.processlist_id, t.processlist_host, c.attr_name, c.attr_value
FROM performance_schema.session_connect_attrs c
JOIN performance_schema.threads t ON t.processlist_id = c.processlist_id
ORDER BY t.processlist_id;
```

### 1.4 判断：是 Pod IP 还是节点 IP？

- 落在 **Pod 网段**（如 `10.42.x.x`）→ **跳到第 4 步**，可直接映射。
- 落在**节点 IP 段**（本次 `172.18.10.x`）→ 被 SNAT 了，继续第 2、3 步。

> **旁证**：本次源端口极其分散（1736、2020、7144 … 64467），是 kube-proxy masquerade 规则带 `--random-fully` 的典型特征，进一步确认经过了节点 NAT。

---

## 2. 节点侧：确认 conntrack 表可读

登录第 1 步里连接数最多的节点。

```bash
head -1 /proc/net/nf_conntrack
```

**本次实测输出：**

```
ipv4 2 tcp 6 83292 ESTABLISHED src=10.42.4.43 dst=10.42.6.225 sport=56828 dport=9200 \
 src=10.42.6.225 dst=10.42.4.43 sport=9200 dport=56828 [ASSURED] mark=0 zone=0 use=2
```

### 读法（关键）

一行有**两组** src/dst，分别是原始方向和回包方向：

```
src=<Pod IP>  dst=<DB IP>    sport=<Pod 源端口>  dport=<DB 端口>      ← 原始方向
src=<DB IP>   dst=<节点 IP>  sport=<DB 端口>     dport=<SNAT 后端口>  ← 回包方向
                                                 ^^^^^^^^^^^^^^^^^^
                                        这个值 = MySQL processlist 里看到的端口
```

### 如果 `/proc/net/nf_conntrack` 不存在

```bash
# 老内核路径
cat /proc/net/ip_conntrack

# 内核没编 NF_CONNTRACK_PROCFS，只能装工具包
yum install -y conntrack-tools     # RHEL/CentOS
apt install -y conntrack           # Debian/Ubuntu
```

---

## 3. 反查：SNAT 端口 → Pod IP

### 3.1 单条精确反查（主方案）

```bash
grep -w "dport=17056" /proc/net/nf_conntrack
```

**本次实测输出（k8sworker03-new）：**

```
ipv4 2 tcp 6 86366 ESTABLISHED src=10.42.6.209 dst=172.18.10.24 sport=55468 dport=5432 \
 src=172.18.10.24 dst=172.18.10.14 sport=5432 dport=17056 [ASSURED] mark=0 zone=0 use=2
ipv4 2 tcp 6 85824 ESTABLISHED src=10.42.6.47  dst=172.18.10.20 sport=53474 dport=13306 \
 src=172.18.10.20 dst=172.18.10.14 sport=13306 dport=17056 [ASSURED] mark=0 zone=0 use=2
```

> ⚠️ **坑点 1：源端口会撞车。**
> 上面返回了两行，第一行是到 `172.18.10.24:5432` 的 PostgreSQL 连接，只是恰好 SNAT 到了同一个端口号。
> **必须叠加目标 IP + 目标端口过滤：**

```bash
DB_IP=172.18.10.20
DB_PORT=13306
PORT=17056

grep -w "dport=${PORT}" /proc/net/nf_conntrack | grep "dst=${DB_IP} .*dport=${DB_PORT}"
```

**其余实测：**

```bash
[k8sworker03-new] grep -w "dport=62607" → src=10.42.6.47  dst=172.18.10.20 dport=13306
[k8sworker03-new] grep -w "dport=1736"  → src=10.42.6.47  dst=172.18.10.20 dport=13306
[k8sworker04-new] grep -w "dport=55538" → src=10.42.2.70  dst=172.18.10.20 dport=13306
```

### 3.2 批量统计该节点上各 Pod 的连接数（推荐，一步到位）

```bash
awk '/dst=172\.18\.10\.20 / && /dport=13306/ {
  for(i=1;i<=NF;i++) if($i ~ /^src=10\.42\./) {print substr($i,5); break}
}' /proc/net/nf_conntrack | sort | uniq -c | sort -rn
```

**本次实测输出：**

```
--- k8sworker03-new (172.18.10.14) ---
     65 10.42.6.206
     50 10.42.6.47      ← dataassets 的 50 条就是它
     10 10.42.6.247
      6 10.42.6.122
      4 10.42.6.6
      4 10.42.6.245
      1 10.42.6.236

--- k8sworker04-new (172.18.10.15) ---
     50 10.42.2.70      ← dataassets 的 50 条就是它
     49 10.42.2.44
     24 10.42.2.181
     10 10.42.2.180
      2 10.42.2.4
      2 10.42.2.183
```

> ⚠️ **坑点 2：conntrack 总数会大于 processlist 的数。**
> conntrack 统计的是**到该 MySQL 实例的全部连接**（所有账号、所有库）；
> `processlist` 那 50 条只是 `user='dataassets'` 的部分。
> 对账时用 1.3 节的"全库全用户分布"查询来核对。

### 3.3 备用方案 A：conntrack 命令（装了工具包时）

```bash
# 全量
conntrack -L -p tcp --dst 172.18.10.20 --dport 13306

# 按 SNAT 后端口精确反查（比 grep 干净）
conntrack -L -p tcp --reply-port-dst 17056

# 统计
conntrack -L -p tcp --dst 172.18.10.20 --dport 13306 2>/dev/null \
 | awk '{print $5}' | sed 's/src=//' | sort | uniq -c | sort -rn
```

### 3.4 备用方案 B：不依赖 conntrack，直接进 netns 数连接

**适用于**：conntrack 表被清空 / 表项过期 / 内核不支持 / 想避开端口撞车问题。

原理：每个 Pod 有独立 netns，进去读 `/proc/net/tcp` 即可。
`/proc/net/tcp` 第 3 列 `rem_address` 是 `<IP十六进制>:<端口十六进制>`，第 4 列 `01` 表示 ESTABLISHED。

**端口十六进制换算表：**

| 端口 | 十六进制 |
|---|---|
| 3306 | `0CEA` |
| 13306 | `33FA` |
| 5432 | `1538` |
| 6379 | `18EB` |
| 9200 | `23F0` |

```bash
# 自己换算：
printf '%04X\n' 13306      # → 33FA
```

**docker 运行时（RKE1）：**

```bash
#!/bin/bash
PORT_HEX=33FA    # 13306
for c in $(docker ps -q --filter "label=io.kubernetes.docker.type=podsandbox"); do
  pid=$(docker inspect -f '{{.State.Pid}}' "$c"); [ "$pid" = 0 ] && continue
  cnt=$(nsenter -t "$pid" -n cat /proc/net/tcp 2>/dev/null \
        | awk -v p=":$PORT_HEX" '$3 ~ p"$" && $4=="01"' | wc -l)
  [ "$cnt" -eq 0 ] && continue
  ns=$(docker  inspect -f '{{index .Config.Labels "io.kubernetes.pod.namespace"}}' "$c")
  pod=$(docker inspect -f '{{index .Config.Labels "io.kubernetes.pod.name"}}'      "$c")
  printf "%4d  %s/%s\n" "$cnt" "$ns" "$pod"
done | sort -rn
```

> 只遍历 pause 容器（`podsandbox`）是为了每个 Pod 的 netns 只统计一次，避免多容器 Pod 重复计数。

**containerd 运行时（RKE2 / K3s）：**

```bash
#!/bin/bash
PORT_HEX=33FA
for c in $(crictl pods -q); do
  pid=$(crictl inspectp --output go-template --template '{{.info.pid}}' "$c" 2>/dev/null)
  [ -z "$pid" ] || [ "$pid" = 0 ] && continue
  cnt=$(nsenter -t "$pid" -n cat /proc/net/tcp 2>/dev/null \
        | awk -v p=":$PORT_HEX" '$3 ~ p"$" && $4=="01"' | wc -l)
  [ "$cnt" -eq 0 ] && continue
  name=$(crictl inspectp --output go-template \
         --template '{{.status.metadata.namespace}}/{{.status.metadata.name}}' "$c")
  printf "%4d  %s\n" "$cnt" "$name"
done | sort -rn
```

### 3.5 备用方案 C：纯 kubectl（无节点 shell 权限时）

镜像里有 `sh` 就够了，不需要 `ss` / `netstat`：

```bash
NS=dataassets
for p in $(kubectl get pods -n $NS -o name); do
  n=$(kubectl exec -n $NS "${p#pod/}" -- sh -c "grep -c ':33FA' /proc/net/tcp" 2>/dev/null)
  [ -n "$n" ] && [ "$n" != 0 ] && echo "$n ${p#pod/}"
done | sort -rn
```

> 注意：`ss -tnp` / `netstat` 在**节点宿主机**上看不到 Pod 的连接（netns 隔离），必须 `nsenter` 或 `kubectl exec`。

---

## 4. Pod IP → Pod Name

### 4.1 单个查

```bash
kubectl get pod -A -o wide | grep 10.42.6.47
kubectl get pod -A -o wide | grep 10.42.2.70
```

**本次实测输出：**

```
dataassets  dataassets-new-api-use-6cd5c9c4fb-dqssw  1/1 Running 171 65d 10.42.6.47 k8sworker03-new
dataassets  dataassets-data-assets-6db469d7b6-dhnpq  1/1 Running  32 90d 10.42.2.70 k8sworker04-new
```

### 4.2 批量映射

```bash
# 生成 IP → ns/pod 对照表
kubectl get pod -A -o wide --no-headers | awk '{print $7"\t"$1"/"$2}' | sort > /tmp/podip.map

# 把第 3.2 步的统计结果存成 /tmp/conn.txt（格式：<count> <podip>），然后
awk 'NR==FNR{m[$1]=$2; next} {printf "%6s  %-16s  %s\n", $1, $2, (m[$2]?m[$2]:"<不在本集群/已重建>")}' \
    /tmp/podip.map /tmp/conn.txt
```

### 4.3 从 Pod 追到工作负载

```bash
kubectl -n dataassets get pod dataassets-new-api-use-6cd5c9c4fb-dqssw \
  -o jsonpath='{.metadata.ownerReferences[0].name}{"\n"}'
kubectl -n dataassets get deploy | grep new-api-use
kubectl -n dataassets get deploy dataassets-new-api-use -o yaml | grep -iA3 -E 'replicas|image:'
```

### 4.4 查不到对应 Pod 的情况

- Pod 已重建，IP 被回收 → 改用 3.4 的实时 netns 统计。
- IP 不在 Pod 网段 → 是集群外的虚机 / 老服务在连，查节点或防火墙记录。
- 本次第 1 步里的 `172.18.10.26 / .60 / .62 / .63` 需单独确认是否为集群节点：

```bash
kubectl get nodes -o wide | grep -E '172\.18\.10\.(26|60|61|62|63)'
```

---

## 5. 本次结论

| 节点 | 节点 IP | dataassets 连接数 | Pod IP | Pod 名 |
|---|---|---|---|---|
| k8sworker03-new | 172.18.10.14 | 50 | 10.42.6.47 | `dataassets-new-api-use-6cd5c9c4fb-dqssw` |
| k8sworker04-new | 172.18.10.15 | 50 | 10.42.2.70 | `dataassets-data-assets-6db469d7b6-dhnpq` |

**关键判断：50 条连接来自单个 Pod 的一个大连接池，不是 5 个 Pod 各 10 条。**
（早期曾按"整十分布"误判为多 Pod 均摊，被 3.1 的实测推翻——三个不同源端口指回同一个 Pod IP。
**教训：不要用连接数的数字规律去猜拓扑，必须逐条反查验证。**）

---

## 6. 后续处置

### 6.1 优先级最高：Pod 重启异常

```
dataassets-new-api-use-...-dqssw   Running   RESTARTS=171   AGE=65d   ← 日均 2.6 次
dataassets-data-assets-...-dhnpq   Running   RESTARTS=32    AGE=90d
```

```bash
kubectl -n dataassets describe pod dataassets-new-api-use-6cd5c9c4fb-dqssw | grep -A8 "Last State"
kubectl -n dataassets logs  dataassets-new-api-use-6cd5c9c4fb-dqssw --previous --tail=300
kubectl -n dataassets get events --field-selector involvedObject.name=dataassets-new-api-use-6cd5c9c4fb-dqssw \
  --sort-by=.lastTimestamp
kubectl -n dataassets get pod dataassets-new-api-use-6cd5c9c4fb-dqssw \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

判断方向：

- `Reason: OOMKilled` → 50 条连接的 JDBC buffer + 结果集缓存在小 limit 下容易打爆，**降池 + 提 limit**。
- `Reason: Error` + 探针失败 → 结合 `max_idle=1780s`（约 30 分钟无活动），应用可能已经僵住。

### 6.2 连接池配置

50 条全 `Sleep` 且不回落，最典型原因是 **HikariCP 的 `minimumIdle` 没显式配**——此时它默认等于
`maximumPoolSize`，`idleTimeout` **完全不生效**，池会永久停在最大值。

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20       # 从 50 降下来
      minimum-idle: 5             # 必须显式配且 < max，idleTimeout 才起作用
      idle-timeout: 300000        # 5 min
      keepalive-time: 120000      # 空闲探活，防中间设备静默断链
      max-lifetime: 1500000       # 建议 < MySQL wait_timeout
      connection-test-query: SELECT 1
```

Druid 对应项：

```yaml
      max-active: 20
      min-idle: 5
      time-between-eviction-runs-millis: 60000
      min-evictable-idle-time-millis: 300000
      test-while-idle: true
      validation-query: SELECT 1
```

> **不建议在数据库侧 kill 连接**——池会立刻重建，治标不治本。
> 只要 `Max_used_connections` 离 `max_connections` 还远，170 条对 MySQL 8.0.26 毫无压力。

### 6.3 长效改进（下次不用再走这套流程）

**方案一：JDBC 连接属性打标（改动最小）**

```
jdbc:mysql://172.18.10.20:13306/ds_wiki?connectionAttributes=podName:${POD_NAME},svc:new-api-use
```

`POD_NAME` 用 Downward API 注入：

```yaml
env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
```

之后一条 SQL 直接出结果：

```sql
SELECT t.processlist_id,
       MAX(CASE WHEN c.attr_name='podName' THEN c.attr_value END) AS pod,
       MAX(CASE WHEN c.attr_name='svc'     THEN c.attr_value END) AS svc,
       MAX(t.processlist_command) AS cmd,
       MAX(t.processlist_time)    AS idle_sec
FROM performance_schema.session_connect_attrs c
JOIN performance_schema.threads t ON t.processlist_id = c.processlist_id
GROUP BY t.processlist_id
ORDER BY idle_sec DESC;
```

**方案二：每个微服务独立数据库账号**（`da_new_api`、`da_data_assets` …）
排查成本直接归零，且能按服务做权限收敛和资源限制：

```sql
CREATE USER 'da_new_api'@'%' IDENTIFIED BY '...';
GRANT SELECT,INSERT,UPDATE,DELETE ON ds_wiki.* TO 'da_new_api'@'%';
ALTER USER 'da_new_api'@'%' WITH MAX_USER_CONNECTIONS 25;
```

---

## 附录：一键脚本

保存为 `trace-db-conn.sh`，在节点上执行。

```bash
#!/bin/bash
# 用法: ./trace-db-conn.sh <DB_IP> <DB_PORT>
# 例:   ./trace-db-conn.sh 172.18.10.20 13306
set -u
DB_IP=${1:?need db ip}
DB_PORT=${2:?need db port}
DB_PORT_HEX=$(printf '%04X' "$DB_PORT")

echo "=== $(hostname) → ${DB_IP}:${DB_PORT} (hex ${DB_PORT_HEX}) ==="
echo

if [ -r /proc/net/nf_conntrack ]; then
  echo "--- [1] conntrack 统计 (Pod IP / 连接数) ---"
  awk -v ip="dst=${DB_IP}" -v pt="dport=${DB_PORT}" '
    index($0,ip) && index($0,pt) {
      for(i=1;i<=NF;i++) if($i ~ /^src=10\./) {print substr($i,5); break}
    }' /proc/net/nf_conntrack | sort | uniq -c | sort -rn
  echo
else
  echo "!! /proc/net/nf_conntrack 不可读，跳过，改用 netns 统计"
  echo
fi

echo "--- [2] netns 实时统计 (连接数 / ns/pod) ---"
if command -v docker >/dev/null 2>&1; then
  LIST=$(docker ps -q --filter "label=io.kubernetes.docker.type=podsandbox")
  for c in $LIST; do
    pid=$(docker inspect -f '{{.State.Pid}}' "$c" 2>/dev/null)
    [ -z "$pid" ] || [ "$pid" = 0 ] && continue
    cnt=$(nsenter -t "$pid" -n cat /proc/net/tcp 2>/dev/null \
          | awk -v p=":${DB_PORT_HEX}\$" '$3 ~ p && $4=="01"' | wc -l)
    [ "$cnt" -eq 0 ] && continue
    ns=$(docker  inspect -f '{{index .Config.Labels "io.kubernetes.pod.namespace"}}' "$c")
    pod=$(docker inspect -f '{{index .Config.Labels "io.kubernetes.pod.name"}}'      "$c")
    printf "%6d  %s/%s\n" "$cnt" "$ns" "$pod"
  done | sort -rn
elif command -v crictl >/dev/null 2>&1; then
  for c in $(crictl pods -q); do
    pid=$(crictl inspectp --output go-template --template '{{.info.pid}}' "$c" 2>/dev/null)
    [ -z "$pid" ] || [ "$pid" = 0 ] && continue
    cnt=$(nsenter -t "$pid" -n cat /proc/net/tcp 2>/dev/null \
          | awk -v p=":${DB_PORT_HEX}\$" '$3 ~ p && $4=="01"' | wc -l)
    [ "$cnt" -eq 0 ] && continue
    name=$(crictl inspectp --output go-template \
           --template '{{.status.metadata.namespace}}/{{.status.metadata.name}}' "$c")
    printf "%6d  %s\n" "$cnt" "$name"
  done | sort -rn
else
  echo "未找到 docker / crictl"
fi
```

**排查顺序速查：**

```
processlist 聚合 → 判断是否 Pod 网段
  ├─ 是 → kubectl get pod -o wide | grep <ip>            [完]
  └─ 否 → 登节点
           ├─ /proc/net/nf_conntrack 可读 → awk 批量统计 → Pod IP → kubectl 映射
           ├─ 有 conntrack 命令         → conntrack -L --reply-port-dst <port>
           └─ 都没有                     → nsenter 进 netns 读 /proc/net/tcp
```

**必须记住的两个坑：**

1. SNAT 源端口会在不同目标库之间撞车 → **过滤条件必须带目标 IP + 目标端口**。
2. conntrack 统计的是该实例全部连接，**大于** `processlist` 中单个账号的数量 → 对账时注意口径。
