结论：**不能**把 `maxmemory 6gb` 这类键值当作“环境变量”分别加进去。
 对你用的 **bitnami/redis:4.0.14**，有两种正确做法：

------

## ✅ 做法 1（推荐，最少改动）：用 `REDIS_EXTRA_FLAGS`

Bitnami 镜像会把 `REDIS_EXTRA_FLAGS` 里的参数原样传给 `redis-server`。在 Pod 里加**一个**环境变量即可：

```yaml
env:
  - name: REDIS_EXTRA_FLAGS
    value: "--maxmemory 6gb --maxmemory-policy allkeys-lru --maxmemory-samples 10 --activedefrag yes --appendonly no"
    # 如必须保留 AOF：把最后的 --appendonly no 去掉，改成
    # --appendfsync everysec --auto-aof-rewrite-percentage 200 --no-appendfsync-on-rewrite yes
```

> 你现在无 PVC，却看到 `aof_enabled:1`，这会造成 fork/COW 峰值与无意义的临时写入。**能接受“丢 token 需重新登录”就先关 AOF（如上）**；如果不能，务必给容器挂 PVC 到 `/data` 再保留 AOF。

------

## ✅ 做法 2：直接用 `args` 传参（与镜像无关，100%生效）

```yaml
containers:
- name: redis
  image: bitnami/redis:4.0.14
  args:
    - "--maxmemory"            # 等价于 redis.conf 里的同名项
    - "6gb"
    - "--maxmemory-policy"
    - "allkeys-lru"            # 现阶段无 TTL 键较多，用 allkeys-* 才会生效
    - "--maxmemory-samples"
    - "10"
    - "--activedefrag"
    - "yes"
    - "--appendonly"
    - "no"                     # 同上，按需保留/关闭 AOF
```

> 别把这些当成四个独立的 env；Redis 并不会读取你自定义的环境变量名（除非镜像的入口脚本专门支持）。

------

## 重启后验证（务必检查）

```bash
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy
redis-cli CONFIG GET maxmemory-samples
redis-cli CONFIG GET activedefrag
redis-cli INFO memory | egrep 'used_memory_human|maxmemory_human'
redis-cli INFO persistence | egrep 'aof_enabled|appendfsync'
```

期望看到：`maxmemory_human:6.00G`、`maxmemory-policy:allkeys-lru`、`aof_enabled:0`（若你选择关闭）。

------

## 策略与后续小建议

- 现在 TTL 覆盖率仍低（`expires/keys` 很小），先用 **`allkeys-lru`** 或 **`allkeys-lfu`** 才能兜底；
   等你把大部分缓存键**写入时带 TTL**（目标 ≥90%）后，再切回：

  ```bash
  --maxmemory-policy volatile-lfu   # 热点更稳
  ```

- 继续观察：`evicted_keys`（触顶才会增）、命中率 `hits/(hits+misses)`、`mem_fragmentation_ratio`。

- 版本已是 **4.0.14（EOL）**；条件允许的话，后续考虑升到 6/7，AOF 重写与碎片整理更好。

需要的话把你当前的 Deployment/StatefulSet 片段贴一下，我给你直接改成可用的 YAML。

------------------------



下面给你一套**redis-cli 监控速查表**（都能在生产上安全执行），分“参数是否生效”和“运行健康度”两部分，并附判断阈值。你当前是 Redis 4.0.x，下面的命令都兼容。

------

# 一、参数是否生效（重启后马上跑）

```bash
# 内存与淘汰策略
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy
redis-cli CONFIG GET maxmemory-samples
redis-cli CONFIG GET activedefrag

# 持久化状态（是否启用 AOF、同步策略）
redis-cli INFO persistence | egrep 'aof_enabled|appendfsync|aof_current_size|aof_base_size'

# 当前上限与实时占用
redis-cli INFO memory | egrep 'used_memory_human|maxmemory_human|mem_fragmentation_ratio'
```

**期望**：`maxmemory_human:6.00G`、`maxmemory-policy:allkeys-lru`（或改完后的策略）、如果你选择关 AOF 则 `aof_enabled:0`。

------

# 二、实时看板（轻量、持续观察）

```bash
# 一行看主要指标（QPS/内存/命中率/连接数等），每秒刷新
redis-cli --stat
```

这是最省心的“迷你仪表盘”，可以挂着看一段时间。

------

# 三、内存健康

```bash
# 关键内存指标
redis-cli INFO memory | egrep 'used_memory_human|used_memory_rss_human|maxmemory_human|mem_fragmentation_ratio'

# Redis 的内存建议（内置医生）
redis-cli MEMORY DOCTOR
```

**看法：**

- `used_memory` 接近 `maxmemory` 时要观察是否开始淘汰（见下一节）。
- `mem_fragmentation_ratio` 一直 > **1.5**：考虑 `activedefrag yes`、滚动重启、检查大对象模式。
- RSS 长期远高于 used_memory：多半是碎片/THP/COW。

------

# 四、缓存行为与容量（命中率/过期/淘汰）

```bash
# 命中率、过期、淘汰
redis-cli INFO stats | egrep 'keyspace_hits|keyspace_misses|expired_keys|evicted_keys'

# TTL 覆盖率（多少键带过期）
redis-cli INFO keyspace
```

**解读：**

- 命中率 ≈ `hits / (hits + misses)`，一般希望 **>90%**（看场景）。
- `expired_keys` 稳步增长 ⇒ TTL 在工作。
- **只有**在 `used_memory` 触顶时，`evicted_keys` 才会增长；频繁淘汰+命中率下降 ⇒ 容量不足或 TTL 太短。
- `INFO keyspace` 里 `expires/keys` 比例 **≥90%** 时，适合切换到 `volatile-*` 策略。

------

# 五、延迟与 fork/COW（重要）

```bash
# 延迟自检（汇总分析）
redis-cli LATENCY DOCTOR

# 最近的延迟事件
redis-cli LATENCY LATEST

# fork 开销（bgsave/重写时关注）
redis-cli INFO stats | egrep 'latest_fork_usec'
```

**阈值参考：**

- `latest_fork_usec` 持续高（>200,000 µs）会带来抖动；减少数据集、降低重写频率，或关 AOF/关 RDB。
- `LATENCY DOCTOR` 提醒 if any：按建议处理（慢命令、磁盘、网络等）。

------

# 六、客户端健康与输出缓冲

```bash
# 客户端数量/阻塞数
redis-cli INFO clients

# 找“膨胀的输出缓冲”（pubsub/慢消费者常见）
redis-cli CLIENT LIST | egrep 'omem=|obl='
```

**关注点**：`blocked_clients > 0` 持续存在要排查；某些连接 `omem=` 很大 ⇒ 下游消费慢，限制 `client-output-buffer-limit` 或排查订阅/复制通道。

------

# 七、慢命令与大键排查（离峰跑）

```bash
# 最近慢命令
redis-cli SLOWLOG LEN
redis-cli SLOWLOG GET 64

# 发现最大的大键（抽样 SCAN，不锁表）
redis-cli --bigkeys
```

**处理**：用 `SCAN`/分页代替全量 `KEYS`/`SORT`，拆批；大键尽量拆分为小值或压缩结构。

------

# 八、TTL 覆盖率与无 TTL 键（辅助脚本）

```bash
# 粗看 TTL 覆盖率（需要 awk）
redis-cli INFO keyspace | awk -F'[=,]' '/db0/ {printf "keys=%s, expires=%s (%.1f%%), avg_ttl(ms)=%s\n",$2,$4,100*$4/$2,$6}'

# 统计无 TTL 键数量（采样 20k）
redis-cli --scan | head -n 20000 | \
xargs -n1 -I{} sh -c 't=$(redis-cli ttl "{}"); [ "$t" -eq -1 ] && echo 1' | wc -l
```

**目标**：让无 TTL 的缓存键尽量接近 0；确需长期保存的键与缓存键分前缀管理。

------

# 九、复核“参数已经生效”的一键检查（可收藏）

```bash
(
  echo '=== config ==='
  redis-cli CONFIG GET maxmemory maxmemory-policy maxmemory-samples activedefrag | xargs -n2 echo
  echo '=== memory ==='
  redis-cli INFO memory | egrep 'used_memory_human|maxmemory_human|mem_fragmentation_ratio'
  echo '=== stats ==='
  redis-cli INFO stats  | egrep 'evicted_keys|expired_keys|keyspace_hits|keyspace_misses|latest_fork_usec'
  echo '=== keyspace ==='
  redis-cli INFO keyspace
  echo '=== persistence ==='
  redis-cli INFO persistence | egrep 'aof_enabled|appendfsync|aof_current_size|aof_base_size'
)
```

------

## 判定“运行基本最优”的简单清单

- `maxmemory`、淘汰策略与你的目标一致，**重启后仍然生效**（用上面 CONFIG/INFO 验证）。
- `used_memory` 常态 < `maxmemory` 的 **85–95%**；撞线只在高峰且 `evicted_keys` 温和增加。
- 命中率稳定在**可接受阈值**（例如 >90%）；`misses` 爆增要排查键淘汰/TTL 太短。
- `mem_fragmentation_ratio` 常态 **≤1.4**；偶发高峰可由 fork/COW/活跃碎片整理解释。
- `latest_fork_usec` 不高；无长时间大延迟事件（看 `LATENCY DOCTOR`）。
- `blocked_clients` 常态 0；无长期巨大 `omem=` 的客户端。
- （开启 AOF 时）`aof_current_size` 与 `aof_base_size` 的增长可被 rewrite 周期平衡；无频繁重写。

> 生产上**不要**长期开 `MONITOR`（极重），`--bigkeys`、全库 `SCAN` 建议在低谷跑。

如果你愿意，我可以把这些命令整理成一段可执行的 `kubectl exec` 脚本，直接在 Pod 里跑一遍输出完整健康报告。

--------------------------------



太好了。我把前面那套检查项做成了一键脚本，**本地执行**，它会用 `kubectl exec` 进 Pod，在容器里跑一段 `sh` 脚本，最后打印一份“Redis 健康报告”。

把下面内容保存为 `redis-health.sh`，给可执行权限即可。

```bash
#!/usr/bin/env bash
# Redis health report via kubectl exec
# Usage:
#   ./redis-health.sh -n <namespace> -p <pod> [-c <container>] [-a <password>] [-d <db_index>] [--bigkeys]
# Example:
#   ./redis-health.sh -n default -p portal-v6-chart-redis-6694c4d96c-njfcr --bigkeys

set -euo pipefail

NS="" POD="" CTN="" PASS="" DB="0" RUN_BIGKEYS="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2;;
    -p|--pod)       POD="$2"; shift 2;;
    -c|--container) CTN="$2"; shift 2;;
    -a|--password)  PASS="$2"; shift 2;;
    -d|--db)        DB="$2"; shift 2;;
    --bigkeys)      RUN_BIGKEYS="1"; shift 1;;
    -h|--help)
      echo "Usage: $0 -n <namespace> -p <pod> [-c <container>] [-a <password>] [-d <db>] [--bigkeys]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

[[ -z "$NS" || -z "$POD" ]] && { echo "ERROR: -n <namespace> and -p <pod> are required."; exit 1; }

KCMD=(kubectl exec -n "$NS" "$POD")
[[ -n "$CTN" ]] && KCMD+=( -c "$CTN" )

# Pass args into the container script: $1=password, $2=db, $3=run_bigkeys
"${KCMD[@]}" -- sh -s -- "$PASS" "$DB" "$RUN_BIGKEYS" <<'INSIDE'
PASS="$1"; DB="${2:-0}"; RUN_BIGKEYS="${3:-0}"

# Find redis-cli; prefer PATH, fallback to bitnami location
REDIS_CLI="$(command -v redis-cli 2>/dev/null || true)"
[ -z "$REDIS_CLI" ] && REDIS_CLI="/opt/bitnami/redis/bin/redis-cli"

AUTH_OPT=""
[ -n "$PASS" ] && AUTH_OPT="-a $PASS"

rcli() { # $@ = redis subcommand
  # shellcheck disable=SC2086
  $REDIS_CLI $AUTH_OPT -n "$DB" "$@"
}

sep(){ printf '\n==== %s ====\n' "$*"; }

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
HOSTN="$(hostname)"

sep "REDIS HEALTH REPORT @ $NOW (host: $HOSTN)"
echo "# Basic"
rcli INFO server | awk -F: '/^redis_version|^redis_mode|^os|^tcp_port|^config_file/ {gsub(/\r/,""); printf "  %-16s %s\n",$1,$2}'

sep "CONFIG (expect to persist across restarts via args/ConfigMap)"
# shellcheck disable=SC2046
rcli CONFIG GET maxmemory maxmemory-policy maxmemory-samples activedefrag \
  | sed 'N;s/\n/ /' | awk '{printf "  %-20s %s\n",$1,$2}'

sep "PERSISTENCE"
rcli INFO persistence | awk -F: '/^aof_enabled|^appendfsync|^aof_current_size|^aof_base_size/ {gsub(/\r/,""); printf "  %-20s %s\n",$1,$2}'

sep "MEMORY"
rcli INFO memory | awk -F: '
/^used_memory_human|^used_memory_rss_human|^maxmemory_human|^mem_fragmentation_ratio/{
  gsub(/\r/,""); printf "  %-24s %s\n",$1,$2
}'

sep "STATS"
H=$(rcli INFO stats | awk -F: "/^keyspace_hits/ {gsub(/\r/,\"\"); print \$2}")
M=$(rcli INFO stats | awk -F: "/^keyspace_misses/ {gsub(/\r/,\"\"); print \$2}")
E=$(rcli INFO stats | awk -F: "/^evicted_keys/ {gsub(/\r/,\"\"); print \$2}")
X=$(rcli INFO stats | awk -F: "/^expired_keys/ {gsub(/\r/,\"\"); print \$2}")
TOTAL=$(( (${H:-0}) + (${M:-0}) ))
if [ "$TOTAL" -gt 0 ]; then
  HITRATE=$(awk -v h="${H:-0}" -v m="${M:-0}" 'BEGIN{printf "%.2f%%", 100*h/(h+m)}')
else
  HITRATE="n/a"
fi
printf "  %-20s %s\n" "keyspace_hits"     "${H:-0}"
printf "  %-20s %s\n" "keyspace_misses"   "${M:-0}"
printf "  %-20s %s\n" "hit_rate"          "$HITRATE"
printf "  %-20s %s\n" "expired_keys"      "${X:-0}"
printf "  %-20s %s\n" "evicted_keys"      "${E:-0}"
rcli INFO stats | awk -F: '/^latest_fork_usec/ {gsub(/\r/,""); printf "  %-20s %s\n",$1,$2}'

sep "KEYSPACE"
DBSIZE=$(rcli DBSIZE | tr -d '\r')
LINE=$(rcli INFO keyspace | tr -d '\r' | awk '/^db0:/{print}')
if [ -n "$LINE" ]; then
  # db0:keys=...,expires=...,avg_ttl=...
  KEYS=$(echo "$LINE" | awk -F'[=,]' '{print $2}')
  EXP=$(echo "$LINE"  | awk -F'[=,]' '{print $4}')
  AVGTTL=$(echo "$LINE"| awk -F'[=,]' '{print $6}')
  COV="n/a"
  [ "$KEYS" -gt 0 ] && COV=$(awk -v e="$EXP" -v k="$KEYS" 'BEGIN{printf "%.1f%%", 100*e/k}')
  printf "  %-20s %s\n" "dbsize"          "$DBSIZE"
  printf "  %-20s %s (expires=%s, avg_ttl(ms)=%s)\n" "keys" "$KEYS" "$EXP" "$AVGTTL"
  printf "  %-20s %s\n" "ttl_coverage"    "$COV"
else
  printf "  %-20s %s\n" "dbsize" "$DBSIZE"
fi

sep "CLIENTS"
rcli INFO clients | awk -F: '/^connected_clients|^blocked_clients/ {gsub(/\r/,""); printf "  %-20s %s\n",$1,$2}'
echo "  suspect output buffers (top):"
rcli CLIENT LIST | awk '
  {
    omem=0; obl=0;
    for(i=1;i<=NF;i++){
      if($i~/^omem=/){split($i,a,"="); omem=a[2]}
      if($i~/^obl=/){split($i,a,"="); obl=a[2]}
      if($i~/^cmd=/){cmd=$i}
    }
    if(omem>0 || obl>0){print "    omem="omem, "obl="obl, cmd}
  }' | sort -k2nr | head -n 10

sep "LATENCY (summary)"
rcli LATENCY DOCTOR 2>/dev/null || echo "  N/A (no latency samples)"

if [ "$RUN_BIGKEYS" = "1" ]; then
  sep "BIGKEYS (sampled scan)  —— 建议在业务低峰使用"
  rcli --bigkeys
fi

sep "MEMORY DOCTOR (hints)"
rcli MEMORY DOCTOR 2>/dev/null || echo "  N/A"

sep "QUICK SUMMARY"
MM=$(rcli INFO memory | awk -F: '/^maxmemory_human/ {gsub(/\r/,""); print $2}')
POL=$(rcli CONFIG GET maxmemory-policy | tr -d '\r' | awk 'NR==2{print}')
FRAG=$(rcli INFO memory | awk -F: '/^mem_fragmentation_ratio/ {gsub(/\r/,""); print $2}')
printf "  %-22s %s\n" "maxmemory" "${MM:-0}"
printf "  %-22s %s\n" "policy"    "${POL:-unknown}"
printf "  %-22s %s\n" "frag_ratio" "${FRAG:-unknown}"
echo "  Notes:"
echo "   - evicted_keys 为 0 且 used_memory 未触顶属正常；触顶后才会淘汰。"
echo "   - frag_ratio>1.5 持续偏高可考虑 activedefrag/滚动重启/排查大对象。"
echo "   - 建议 TTL 覆盖率 >=90% 后使用 volatile-*(如 volatile-lfu) 仅淘汰可过期键。"
INSIDE
```

### 怎么用

```bash
chmod +x redis-health.sh

# 基础用法
./redis-health.sh -n <命名空间> -p <Pod名>

# 如果容器里开启了 requirepass：
./redis-health.sh -n <ns> -p <pod> -a '<你的密码>'

# 指定容器名（Pod 里有多个容器时）
./redis-health.sh -n <ns> -p <pod> -c <container-name>

# 需要附带大键扫描（离峰跑）
./redis-health.sh -n <ns> -p <pod> --bigkeys
```

脚本会输出各个分区的指标、自动算命中率与 TTL 覆盖率、标出可能的问题点（延迟、fork、碎片、输出缓冲等）。如果你想把结果落盘到文件，直接重定向即可：

```bash
./redis-health.sh -n <ns> -p <pod> > redis-health-$(date +%F-%H%M).log
```

需要我给你把命名空间/Pod 名替换成你环境里的实际值，或把报告里再加上“是否已触顶”的判定和建议阈值，也可以直接贴出来，我帮你定制。





-------------

#20250929 new

#redis4.0



```bash
#!/usr/bin/env bash
# Redis health report via kubectl exec (with headroom & limit judgement)
# Usage:
#   ./redis-health.sh -n <namespace> -p <pod> [-c <container>] [-a <password>] [-d <db_index>] [--bigkeys] [--sample-secs 3]

set -euo pipefail

NS="" POD="" CTN="" PASS="" DB="0" RUN_BIGKEYS="0" SAMPLE_SECS=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2;;
    -p|--pod)       POD="$2"; shift 2;;
    -c|--container) CTN="$2"; shift 2;;
    -a|--password)  PASS="$2"; shift 2;;
    -d|--db)        DB="$2"; shift 2;;
    --bigkeys)      RUN_BIGKEYS="1"; shift 1;;
    --sample-secs)  SAMPLE_SECS="${2:-3}"; shift 2;;
    -h|--help) echo "Usage: $0 -n <ns> -p <pod> [-c <ctn>] [-a <pass>] [-d <db>] [--bigkeys] [--sample-secs N]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

[[ -z "$NS" || -z "$POD" ]] && { echo "ERROR: -n <namespace> and -p <pod> are required."; exit 1; }

# >>> 关键修复点：加 -i 把 heredoc 通过 stdin 传进容器
KCMD=(kubectl exec -i -n "$NS" "$POD")
[[ -n "$CTN" ]] && KCMD+=( -c "$CTN" )

"${KCMD[@]}" -- sh -s -- "$PASS" "$DB" "$RUN_BIGKEYS" "$SAMPLE_SECS" <<'INSIDE'
# （容器内脚本内容保持与上个版本一致）
PASS="$1"; DB="${2:-0}"; RUN_BIGKEYS="${3:-0}"; SAMPLE_SECS="${4:-3}"

REDIS_CLI="$(command -v redis-cli 2>/dev/null || true)"
[ -z "$REDIS_CLI" ] && REDIS_CLI="/opt/bitnami/redis/bin/redis-cli"
AUTH_OPT=""
[ -n "$PASS" ] && AUTH_OPT="-a $PASS"
rcli() { $REDIS_CLI $AUTH_OPT -n "$DB" "$@"; }

sep(){ printf '\n==== %s ====\n' "$*"; }
kv(){ printf "  %-24s %s\n" "$1" "$2"; }

read_cg_val(){ f="$1"; [ -f "$f" ] && cat "$f" 2>/dev/null || echo ""; }

# 先读 v1，再尝试 v2；current 优先 v1 的 usage_in_bytes
CG_LIMIT="$(read_cg_val /sys/fs/cgroup/memory/memory.limit_in_bytes)"
CG_CURRENT="$(read_cg_val /sys/fs/cgroup/memory/memory.usage_in_bytes)"
if [ -z "$CG_LIMIT" ]; then
  CG_LIMIT="$(read_cg_val /sys/fs/cgroup/memory.max)"
fi
if [ -z "$CG_CURRENT" ]; then
  CG_CURRENT="$(read_cg_val /sys/fs/cgroup/memory.current)"
fi

case "$CG_LIMIT" in ""|"max") CG_LIMIT="-1";; esac
# 一致性校验：若 current≈limit 且 RSS<<limit，判定 current 失真
BAD_CUR="0"
if [ "$CG_LIMIT" != "-1" ] && [ -n "$CG_LIMIT" ] && [ -n "$CG_CURRENT" ]; then
  DIFF_OK=$(awk -v cur="$CG_CURRENT" -v lim="$CG_LIMIT" -v rss="$USED_RSS" \
    'BEGIN{print (cur>=0.98*lim && rss<0.8*lim) ? 1 : 0}')
  [ "$DIFF_OK" -eq 1 ] && BAD_CUR="1"
fi
[ "$BAD_CUR" = "1" ] && CG_CURRENT=""

INFO_MEM="$(rcli INFO memory | tr -d '\r')"
INFO_STA="$(rcli INFO stats  | tr -d '\r')"
USED_MEM=$(echo "$INFO_MEM" | awk -F: '/^used_memory:/ {print $2}')
USED_RSS=$(echo "$INFO_MEM" | awk -F: '/^used_memory_rss:/ {print $2}')
MAXMEM=$(echo "$INFO_MEM" | awk -F: '/^maxmemory:/ {print $2}')
FRAG=$(echo "$INFO_MEM" | awk -F: '/^mem_fragmentation_ratio:/ {print $2}')
AOF_ENABLED=$(rcli INFO persistence | awk -F: '/^aof_enabled:/ {print $2}' | tr -d '\r')
RDB_SAVE=$(rcli CONFIG GET save | awk 'NR==2{print}')
EVICT_T0=$(echo "$INFO_STA" | awk -F: '/^evicted_keys:/ {print $2}')
HITS_T0=$(echo "$INFO_STA"  | awk -F: '/^keyspace_hits:/ {print $2}')
MISS_T0=$(echo "$INFO_STA"  | awk -F: '/^keyspace_misses:/ {print $2}')

sleep "${SAMPLE_SECS}" 2>/dev/null

INFO_MEM2="$(rcli INFO memory | tr -d '\r')"
INFO_STA2="$(rcli INFO stats  | tr -d '\r')"
EVICT_T1=$(echo "$INFO_STA2" | awk -F: '/^evicted_keys:/ {print $2}')
HITS_T1=$(echo "$INFO_STA2"  | awk -F: '/^keyspace_hits:/ {print $2}')
MISS_T1$(echo "$INFO_STA2"  | awk -F: '/^keyspace_misses:/ {print $2}') >/dev/null 2>&1 || true
# ↑ 某些老版本 awk 在无字段时会报错，上行忽略

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; HOSTN="$(hostname)"
sep "REDIS HEALTH REPORT @ $NOW (host: $HOSTN)"

echo "# Basic"
rcli INFO server | awk -F: '/^redis_version|^redis_mode|^os|^tcp_port|^config_file/ {gsub(/\r/,""); printf "  %-16s %s\n",$1,$2}'

sep "CONFIG (should persist across restarts via args/ConfigMap)"
for k in maxmemory maxmemory-policy maxmemory-samples activedefrag; do
  rcli CONFIG GET "$k" | sed 'N;s/\n/ /' | awk '{printf "  %-20s %s\n",$1,$2}'
done

sep "PERSISTENCE"
rcli INFO persistence | awk -F: '/^aof_enabled|^appendfsync|^aof_current_size|^aof_base_size/ {gsub(/\r/,""); printf "  %-20s %s\n",$1,$2}'
kv "rdb_save_config" "${RDB_SAVE:-""}"

sep "MEMORY"
echo "$INFO_MEM" | awk -F: '/^used_memory_human|^used_memory_rss_human|^maxmemory_human|^mem_fragmentation_ratio/ {gsub(/\r/,""); printf "  %-24s %s\n",$1,$2}'

sep "STATS"
H=$(echo "$INFO_STA2" | awk -F: "/^keyspace_hits:/ {print \$2}")
M=$(echo "$INFO_STA2" | awk -F: "/^keyspace_misses:/ {print \$2}")
TOTAL=$(( (${H:-0}) + (${M:-0}) ))
[ "$TOTAL" -gt 0 ] && HITRATE=$(awk -v h="${H:-0}" -v m="${M:-0}" 'BEGIN{printf "%.2f%%", 100*h/(h+m)}') || HITRATE="n/a"
kv "keyspace_hits"     "${H:-0}"
kv "keyspace_misses"   "${M:-0}"
kv "hit_rate"          "$HITRATE"
echo "$INFO_STA2" | awk -F: '/^expired_keys|^evicted_keys|^latest_fork_usec/ {gsub(/\r/,""); printf "  %-20s %s\n",$1,$2}'

sep "KEYSPACE"
DBSIZE=$(rcli DBSIZE | tr -d '\r')
LINE=$(rcli INFO keyspace | tr -d '\r' | awk '/^db0:/{print}')
if [ -n "$LINE" ]; then
  KEYS=$(echo "$LINE" | awk -F'[=,]' '{print $2}')
  EXP=$(echo "$LINE"  | awk -F'[=,]' '{print $4}')
  AVGTTL=$(echo "$LINE"| awk -F'[=,]' '{print $6}')
  COV="n/a"; [ "$KEYS" -gt 0 ] && COV=$(awk -v e="$EXP" -v k="$KEYS" 'BEGIN{printf "%.1f%%", 100*e/k}')
  kv "dbsize" "$DBSIZE"
  kv "keys"   "$KEYS (expires=$EXP, avg_ttl(ms)=$AVGTTL)"
  kv "ttl_coverage" "$COV"
else
  kv "dbsize" "$DBSIZE"
fi

sep "CLIENTS"
rcli INFO clients | awk -F: '/^connected_clients|^blocked_clients/ {gsub(/\r/,""); printf "  %-20s %s\n",$1,$2}'
echo "  suspect output buffers (top):"
rcli CLIENT LIST | awk '
  { omem=0; obl=0;
    for(i=1;i<=NF;i++){
      if($i~/^omem=/){split($i,a,"="); omem=a[2]}
      if($i~/^obl=/){split($i,a,"="); obl=a[2]}
      if($i~/^cmd=/){cmd=$i}
    }
    if(omem>0 || obl>0){print "    omem="omem, "obl="obl, cmd}
  }' | sort -k2nr | head -n 10

sep "LATENCY (summary)"
rcli LATENCY DOCTOR 2>/dev/null || echo "  N/A (no latency samples)"

sep "MEMORY DOCTOR (hints)"
rcli MEMORY DOCTOR 2>/dev/null || echo "  N/A"

sep "LIMIT & HEADROOM JUDGEMENT"
fmtb(){ v="$1"; awk -v b="$v" 'BEGIN{split("B KB MB GB TB",u); s=1; while(b>=1024&&s<5){b/=1024;s++} printf "%.2f %s", b,u[s] }'; }

if [ "$CG_LIMIT" = "-1" ] || [ -z "$CG_LIMIT" ]; then
  kv "cgroup_limit" "unknown (no container memory limit detected)"
else
  kv "cgroup_limit" "$(fmtb "$CG_LIMIT")"
  [ -n "$CG_CURRENT" ] && { PCT=$(awk -v c="$CG_CURRENT" -v l="$CG_LIMIT" 'BEGIN{printf "%.2f%%", (100*c/l)}'); kv "cgroup_current" "$(fmtb "$CG_CURRENT") ($PCT)"; }
fi

if [ "$MAXMEM" -gt 0 ] 2>/dev/null; then
  USED_PCT=$(awk -v u="$USED_MEM" -v m="$MAXMEM" 'BEGIN{printf "%.2f%%", (100*u/m)}')
  kv "redis_used/maxmemory" "$(fmtb "$USED_MEM") / $(fmtb "$MAXMEM") ($USED_PCT)"
else
  kv "redis_maxmemory" "0 (UNLIMITED) —— 建议尽快设置 maxmemory"
fi
kv "rss" "$(fmtb "$USED_RSS")"
kv "frag_ratio" "$FRAG"
kv "aof_enabled" "${AOF_ENABLED:-0}"
kv "rdb_save_config" "${RDB_SAVE:-""}"

ERATE=$(( (${EVICT_T1:-0} - ${EVICT_T0:-0}) / (${SAMPLE_SECS:-1}) ))
kv "evict_rate(keys/s)" "$ERATE"

REDIS_STATE="OK"
if [ "$MAXMEM" -gt 0 ] 2>/dev/null; then
  CMP=$(awk -v u="$USED_MEM" -v m="$MAXMEM" 'BEGIN{print (u>=0.98*m)?"HIT":(u>=0.90*m)?"NEAR":"OK"}')
  REDIS_STATE="$CMP"
else REDIS_STATE="NO_MAXMEM"; fi

CG_STATE="UNKNOWN"
if [ "$CG_LIMIT" != "-1" ] && [ -n "$CG_LIMIT" ]; then
  CGCMP=$(awk -v r="$USED_RSS" -v l="$CG_LIMIT" 'BEGIN{print (r>=0.95*l)?"OOM_RISK":(r>=0.85*l)?"NEAR":"OK"}')
  CG_STATE="$CGCMP"
fi

kv "redis_limit_state" "$REDIS_STATE  (OK|NEAR|HIT|NO_MAXMEM)"
kv "cgroup_limit_state" "$CG_STATE    (OK|NEAR|OOM_RISK|UNKNOWN)"

if [ "$CG_LIMIT" != "-1" ] && [ -n "$CG_LIMIT" ]; then
  PERSIST="0"
  [ "${AOF_ENABLED:-0}" = "1" ] && PERSIST="1"
  [ -n "$RDB_SAVE" ] && [ "$RDB_SAVE" != "" ] && [ "$RDB_SAVE" != "\"\"" ] && PERSIST="1"
  if [ "$PERSIST" = "1" ]; then
    REC=$(awk -v L="$CG_LIMIT" 'BEGIN{printf "%.0f", 0.55*L}')
    kv "recommended_maxmemory" "$(fmtb "$REC")  (持久化开启：建议 50–60% 容器上限，预留 COW+碎片)"
  else
    REC=$(awk -v L="$CG_LIMIT" 'BEGIN{printf "%.0f", 0.75*L}')
    kv "recommended_maxmemory" "$(fmtb "$REC")  (无持久化：建议 70–80% 容器上限，预留碎片+波动)"
  fi
fi

echo "  判定说明："
echo "   - redis_limit_state: USED>=98% 为 HIT，>=90% 为 NEAR；其余 OK。"
echo "   - cgroup_limit_state: RSS>=95% 为 OOM_RISK，>=85% 为 NEAR；其余 OK。"
echo "   - 若 evict_rate>0 且 redis_limit_state 为 NEAR/HIT，说明正在因容量触发淘汰。"
echo "   - frag_ratio 持续 >1.5 可考虑 activedefrag/滚动重启/优化对象粒度。"
echo "   - 当 TTL 覆盖率 >=90% 后，建议使用 volatile-*(如 volatile-lfu) 只淘汰可过期键。"

[ "$RUN_BIGKEYS" = "1" ] && { sep "BIGKEYS (sampled scan)  —— 建议在业务低峰使用"; rcli --bigkeys; }

sep "END OF REPORT"
INSIDE

```

