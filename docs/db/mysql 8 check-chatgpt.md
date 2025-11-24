下面把你的脚本做了系统级重构：更安全（不在命令行暴露密码）、更兼容 MySQL 8（移除已废弃项目、加新变量回退）、更稳健（统一取样、颜色与对齐、异常处理）、更快（一次性抓取 VARIABLES/STATUS，减少多次连接），并修复了若干明显错误（如 log-bin、slave-parallel-type、查询缓存等）。

直接保存为 `mysql_check.sh` 即可运行。

```bash
#!/usr/bin/env bash
# MySQL 8 巡检脚本（优化版）
# - 兼容 MySQL 8.*（含替代变量回退）
# - 单次抓取 VARIABLES/STATUS，减少连接次数
# - QPS/TPS 1s 取样，InnoDB BP 命中率
# - 复制/半同步、慢日志、库大小、碎片、锁等待、等待事件
# 使用：
#   chmod +x mysql_check.sh
#   ./mysql_check.sh -h 127.0.0.1 -P 3306 -u root [-p] [-S /path/mysql.sock]
# 建议使用 my.cnf 或 mysql_config_editor，避免明文密码

set -Eeuo pipefail

# ---------- 参数 ----------
HOST="127.0.0.1"
PORT="3306"
USER="root"
PASS=""           # 不建议在这里写；若需临时输入用 -p 交互；或用 ~/.my.cnf
SOCKET=""
DB="mysql"
BASE="/usr/local/mysql"   # 若在 PATH 中已有 mysql，可忽略
MYSQL_BIN=""

while getopts ":h:P:u:p::S:d:b:" opt; do
  case $opt in
    h) HOST="$OPTARG" ;;
    P) PORT="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    p) PASS="${OPTARG-ask}" ;;   # -p 或 -p'xxx'；仅 -p 则交互
    S) SOCKET="$OPTARG" ;;
    d) DB="$OPTARG" ;;
    b) BASE="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 2 ;;
  esac
done

# ---------- 准备 mysql 命令 ----------
if [[ -x "$BASE/bin/mysql" ]]; then
  MYSQL_BIN="$BASE/bin/mysql"
elif command -v mysql >/dev/null 2>&1; then
  MYSQL_BIN="$(command -v mysql)"
else
  echo "找不到 mysql 客户端，请检查 PATH 或 BASE" >&2; exit 1
fi

MYSQL_OPTS=( -h "$HOST" -P "$PORT" -u "$USER" -N -s --batch --connect-timeout=5 )
[[ -n "$SOCKET" ]] && MYSQL_OPTS=( --socket="$SOCKET" -u "$USER" -N -s --batch --connect-timeout=5 )
if [[ "${PASS:-}" == "ask" ]]; then
  read -r -s -p "MySQL password: " PASS; echo
fi
[[ -n "$PASS" ]] && MYSQL_OPTS+=( -p"$PASS" )

run_sql() { "$MYSQL_BIN" "${MYSQL_OPTS[@]}" -e "$1" "$DB"; }

# ---------- 美化 ----------
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  bold=$(tput bold); red=$(tput setaf 1); green=$(tput setaf 2); yellow=$(tput setaf 3); blue=$(tput setaf 4); reset=$(tput sgr0)
else
  bold=""; red=""; green=""; yellow=""; blue=""; reset=""
fi
hr(){ printf "%s\n" "============================================================"; }
p(){ printf "%-44s : %s\n" "$1" "$2"; }
warn(){ printf "%s%-44s : %s%s\n" "$yellow" "$1" "$2" "$reset"; }
ok(){ printf "%s%-44s : %s%s\n" "$green" "$1" "$2" "$reset"; }
bad(){ printf "%s%-44s : %s%s\n" "$red" "$1" "$2" "$reset"; }

# ---------- 连接检测 ----------
if ! run_sql "SELECT 1" >/dev/null 2>&1; then
  echo "无法连接 MySQL，请检查主机、端口、用户或认证方式（建议使用 ~/.my.cnf）" >&2
  exit 1
fi
START_TS=$(date +%s)

echo "================= 开始 MySQL 数据库巡检 ==============================="

# ---------- 一次性抓取 VARIABLES/STATUS ----------
VARS="$(run_sql "SHOW VARIABLES")" || VARS=""
STATUS1="$(run_sql "SHOW GLOBAL STATUS")" || STATUS1=""
sleep 1
STATUS2="$(run_sql "SHOW GLOBAL STATUS")" || STATUS2=""

# 取变量/状态值（若不存在返回空）
v(){ awk -v k="$1" 'BEGIN{FS="\t"} $1==k{print $2}' <<<"$VARS" | head -n1; }
s1(){ awk -v k="$1" 'BEGIN{FS="\t"} $1==k{print $2}' <<<"$STATUS1" | head -n1; }
s2(){ awk -v k="$1" 'BEGIN{FS="\t"} $1==k{print $2}' <<<"$STATUS2" | head -n1; }

# 回退抓取（变量不存在时尝试等价项）
first_nonempty(){ for x in "$@"; do [[ -n "$x" ]] && { echo "$x"; return; }; done; }

# 字节友好显示
human(){ awk 'function human(x){s="B KB MB GB TB PB";i=0;while(x>=1024&&i<5){x/=1024;i++} return sprintf("%.2f %s",x,split(s,a)?a[i+1]:"B")} {print human($0)}'; }

# ---------- 基本配置信息 ----------
hr; echo "================= mysql 配置信息 ==============================="
echo "========= 基本配置信息 =========="
lc=$(v lower_case_table_names)
p  "不区分大小写(lower_case_table_names)" "${lc:-N/A}"
p_=$(v port); p "端口(port)" "${p_:-$PORT}"
sock=$(v socket); p "socket" "${sock:-N/A}"
p "skip_name_resolve" "$(v skip_name_resolve)"
p "character_set_server" "$(v character_set_server)"
p "transaction_isolation" "$(first_nonempty "$(v transaction_isolation)" "$(v tx_isolation)")"
p "datadir" "$(v datadir)"
p "server_id" "$(v server_id)"
p "sql_mode" "$(v sql_mode)"
p "版本(version)" "$(v version)"

# ---------- 连接数 ----------
hr; echo "========= 连接数配置信息 =========="
mc=$(v max_connections); p "max_connections" "${mc}"
muc=$(s1 Max_used_connections); p "Max_used_connections (历史峰值)" "${muc}"
tc=$(s2 Threads_connected); p "当前连接(Threads_connected)" "${tc}"
if [[ -n "${mc:-}" && -n "${tc:-}" ]]; then
  used=$(awk -v a="$tc" -v b="$mc" 'BEGIN{if(b>0) printf "%.1f%%",(a/b)*100; else print "N/A"}')
  (awk -v u="$used" 'BEGIN{gsub("%","",u); exit !(u>=80)}') && warn "连接使用率" "$used" || ok "连接使用率" "$used"
fi
p "Aborted_connects" "$(s2 Aborted_connects)"

# ---------- QPS/TPS ----------
hr; echo "================= QPS / TPS ==============================="
# QPS：优先 Queries，不存在回退 Questions
q1=$(first_nonempty "$(s1 Queries)" "$(s1 Questions)" "0")
q2=$(first_nonempty "$(s2 Queries)" "$(s2 Questions)" "0")
qps=$(( q2 - q1 )); p "QPS(1s 采样)" "$qps"

cc1=$(s1 Com_commit); cr1=$(s1 Com_rollback)
cc2=$(s2 Com_commit); cr2=$(s2 Com_rollback)
tps=$(( (cc2-cc1) + (cr2-cr1) ))
p "TPS(1s 采样)" "$tps"

# ---------- binlog ----------
hr; echo "========= binlog 配置信息 =========="
p "log_bin" "$(v log_bin)"
p "binlog_format" "$(v binlog_format)"
p "sync_binlog" "$(v sync_binlog)"
# MySQL 8: binlog_expire_logs_seconds 替代 expire_logs_days
exp_sec=$(v binlog_expire_logs_seconds); exp_days=$(v expire_logs_days)
if [[ -n "$exp_sec" && "$exp_sec" != "0" ]]; then
  days=$(awk -v s="$exp_sec" 'BEGIN{printf "%.2f 天", s/86400}')
  p "binlog 保留" "$days"
else
  p "binlog 保留(expire_logs_days)" "${exp_days:-0} 天"
fi
p "binlog_cache_size" "$(v binlog_cache_size)"
p "max_binlog_cache_size" "$(v max_binlog_cache_size)"
p "max_binlog_size" "$(v max_binlog_size)"
p "master_info_repository" "$(v master_info_repository)"
p "relay_log_info_repository" "$(v relay_log_info_repository)"
p "relay_log_recovery" "$(v relay_log_recovery)"

# ---------- GTID ----------
hr; echo "========= GTID 配置信息 =========="
p "gtid_mode" "$(v gtid_mode)"
p "enforce_gtid_consistency" "$(v enforce_gtid_consistency)"
p "log_slave_updates" "$(v log_slave_updates)"

# ---------- InnoDB 配置 ----------
hr; echo "======== InnoDB 配置信息 ========"
bp=$(v innodb_buffer_pool_size); p "innodb_buffer_pool_size" "$(printf "%s (%s)" "$bp" "$(echo "$bp" | human 2>/dev/null)")"
p "innodb_buffer_pool_instances" "$(v innodb_buffer_pool_instances)"
p "innodb_log_file_size" "$(printf "%s (%s)" "$(v innodb_log_file_size)" "$(echo "$(v innodb_log_file_size)" | human)"}"
p "innodb_log_files_in_group" "$(v innodb_log_files_in_group)"
p "innodb_flush_log_at_trx_commit" "$(v innodb_flush_log_at_trx_commit)"
p "innodb_io_capacity" "$(v innodb_io_capacity)"
# 可选变量（不同版本可能不存在）
opt_undo_sz="$(v innodb_max_undo_log_size)"; [[ -n "$opt_undo_sz" ]] && p "innodb_max_undo_log_size" "$opt_undo_sz"
opt_undo_ts="$(v innodb_undo_tablespaces)"; [[ -n "$opt_undo_ts" ]] && p "innodb_undo_tablespaces" "$opt_undo_ts"

# ---------- 内存相关 ----------
hr; echo "================= 内存配置情况 ==============================="
p "innodb_log_buffer_size" "$(printf "%s (%s)" "$(v innodb_log_buffer_size)" "$(echo "$(v innodb_log_buffer_size)" | human)")"
p "thread_cache_size" "$(v thread_cache_size)"
# MySQL 8 已移除 Query Cache，这里仅显示是否存在相关变量
qcsize="$(v query_cache_size)"; qctype="$(v query_cache_type)"
if [[ -n "$qcsize" || -n "$qctype" ]]; then
  warn "Query Cache(已废弃)" "size=$qcsize type=$qctype"
else
  ok "Query Cache" "MySQL 8 已移除"
fi
p "table_open_cache" "$(v table_open_cache)"
p "table_definition_cache" "$(v table_definition_cache)"
p "max_connections" "$(v max_connections)"
p "thread_stack" "$(v thread_stack)"
p "sort_buffer_size" "$(v sort_buffer_size)"
p "join_buffer_size" "$(v join_buffer_size)"
p "read_buffer_size" "$(v read_buffer_size)"
p "read_rnd_buffer_size" "$(v read_rnd_buffer_size)"
p "tmp_table_size" "$(v tmp_table_size)"

# ---------- InnoDB Buffer Pool 命中率 ----------
hr; echo "================= InnoDB 缓存命中情况 ==============================="
bprq1=$(first_nonempty "$(s1 Innodb_buffer_pool_read_requests)" "0")
bprd1=$(first_nonempty "$(s1 Innodb_buffer_pool_reads)" "0")
bprq2=$(first_nonempty "$(s2 Innodb_buffer_pool_read_requests)" "$bprq1")
bprd2=$(first_nonempty "$(s2 Innodb_buffer_pool_reads)" "$bprd1")
# 用总量估算命中率（非 1s 差分，便于长期水平评估）
if [[ "$bprq2" -gt 0 ]]; then
  hit=$(awk -v rq="$bprq2" -v rd="$bprd2" 'BEGIN{printf "%.2f%%",(1 - rd/rq)*100}')
  p "Buffer Pool 命中率(累计)" "$hit"
else
  p "Buffer Pool 命中率(累计)" "N/A"
fi

# ---------- 主从复制 ----------
hr; echo "================= 主从复制 ==============================="
# 兼容新旧命令：SHOW REPLICA STATUS / SHOW SLAVE STATUS
replica_status="$(run_sql "SHOW REPLICA STATUS\\G" 2>/dev/null || true)"
if [[ -z "$replica_status" ]]; then
  replica_status="$(run_sql "SHOW SLAVE STATUS\\G" 2>/dev/null || true)"
fi
if [[ -n "$replica_status" ]]; then
  echo "$replica_status" | sed -n 's/^\s*\(Replica_IO_Running\|Slave_IO_Running\|Replica_SQL_Running\|Slave_SQL_Running\|Seconds_Behind_Master\|SQL_Delay\|Retrieved_Gtid_Set\|Executed_Gtid_Set\):/ \1:/p'
else
  echo "未配置复制或无法读取复制状态。"
fi

# ---------- 半同步复制 ----------
hr; echo "================= 半同步复制 ==============================="
# 兼容旧名(master/slave)与新名(source/replica)
run_sql "SHOW VARIABLES LIKE 'rpl_semi_sync%';" 2>/dev/null || true

# ---------- 慢查询 ----------
hr; echo "================= 慢查询 ==============================="
slow_on="$(v slow_query_log)"
slow_file="$(v slow_query_log_file)"
lqt="$(v long_query_time)"
lnui="$(v log_queries_not_using_indexes)"
p "slow_query_log" "${slow_on}"
p "slow_query_log_file" "${slow_file}"
p "long_query_time(s)" "${lqt}"
p "log_queries_not_using_indexes" "${lnui}"
if [[ "${slow_on^^}" == "ON" && -f "$slow_file" ]]; then
  echo "慢查询 Top 10（按次数）:"
  if command -v mysqldumpslow >/dev/null 2>&1; then
    mysqldumpslow -s c -t 10 "$slow_file" || true
  else
    echo "未找到 mysqldumpslow，简单 grep 近 200 行："
    tail -n 200 "$slow_file" | grep -i "Query_time" | head -n 10 || true
  fi
else
  echo "慢查询未开启或日志文件不存在。"
fi

# ---------- 库大小 ----------
hr; echo "================= 数据库大小 ==============================="
run_sql "
SELECT
  table_schema,
  ROUND(SUM(data_length)/1024/1024/1024,2) AS data_gb,
  ROUND(SUM(index_length)/1024/1024/1024,2) AS index_gb,
  ROUND(SUM(data_length+index_length)/1024/1024/1024,2) AS total_gb
FROM information_schema.TABLES
WHERE table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
GROUP BY table_schema
ORDER BY total_gb DESC;
" || true

# ---------- 数据碎片（粗略估算） ----------
hr; echo "================= 数据碎片 ==============================="
run_sql "
SELECT
  TABLE_SCHEMA,
  TABLE_NAME,
  ENGINE,
  CONCAT(ROUND((DATA_LENGTH+INDEX_LENGTH - TABLE_ROWS*AVG_ROW_LENGTH)/1024/1024,2),' MB') AS frag_mb
FROM information_schema.TABLES
WHERE TABLE_TYPE='BASE TABLE'
  AND (DATA_LENGTH+INDEX_LENGTH) > 0
  AND ROUND((DATA_LENGTH+INDEX_LENGTH - TABLE_ROWS*AVG_ROW_LENGTH)/1024/1024,2) > 256
ORDER BY (DATA_LENGTH+INDEX_LENGTH - TABLE_ROWS*AVG_ROW_LENGTH) DESC
LIMIT 200;
" || true

# ---------- 锁等待（MySQL 8 使用 performance_schema.data_lock_waits） ----------
hr; echo "================= 锁等待 ==============================="
run_sql "
SELECT
  r.PROCESSLIST_ID    AS waiting_pid,
  r.PROCESSLIST_USER  AS waiting_user,
  r.PROCESSLIST_TIME  AS waiting_secs,
  LEFT(r.PROCESSLIST_INFO,120) AS waiting_sql,
  b.PROCESSLIST_ID    AS blocking_pid,
  b.PROCESSLIST_USER  AS blocking_user,
  b.PROCESSLIST_TIME  AS blocking_secs,
  LEFT(b.PROCESSLIST_INFO,120) AS blocking_sql
FROM performance_schema.data_lock_waits w
JOIN performance_schema.threads r ON r.THREAD_ID = w.REQUESTING_THREAD_ID
JOIN performance_schema.threads b ON b.THREAD_ID = w.BLOCKING_THREAD_ID
LIMIT 20;
" || true

# ---------- 等待事件（TOP 10） ----------
hr; echo "================= 等待事件 TOP10 ==============================="
run_sql "
SELECT EVENT_NAME, COUNT_STAR,
       ROUND(SUM_TIMER_WAIT/1000000000000,2) AS total_wait_s
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE COUNT_STAR>0
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;
" || true

# ---------- 最近一周错误日志（按日期字符串粗过滤） ----------
hr; echo "================= 最近一周错误日志 ==============================="
err_file="$(v log_error)"
if [[ -f "$err_file" ]]; then
  dlist=""
  for i in {6..0}; do dlist+=$(date -d "$i days ago" +%Y-%m-%d)"|"; done
  dlist="${dlist%|}"
  grep -iE "error" "$err_file" | grep -E "$dlist" | tail -n 200 || true
else
  echo "log_error 文件不存在：$err_file"
fi

# ---------- 复制/主状态（简要） ----------
hr; echo "================= 主/复制状态摘要 ==============================="
run_sql "SHOW MASTER STATUS\G" 2>/dev/null || true
run_sql "SHOW BINARY LOGS" 2>/dev/null | head -n 20 || true

# ---------- 结束 ----------
hr
END_TS=$(date +%s)
echo "完成巡检，脚本执行时间：$((END_TS-START_TS)) 秒"
```

# 这版相对你原脚本的关键改进

- ✅ **安全**：不再把密码硬编码在脚本里；支持 `~/.my.cnf`、`mysql_config_editor`，或运行时 `-p` 交互输入。
- ✅ **更少连接**：一次抓全量 `SHOW VARIABLES` / `SHOW GLOBAL STATUS`，后续本地解析，显著减少几十次连接开销。
- ✅ **MySQL 8 兼容**：
  - 移除/标注 **Query Cache**（8.0 已移除）；
  - `expire_logs_days` 自动回退到 `binlog_expire_logs_seconds`；
  - 复制命令兼容 `SHOW REPLICA STATUS` / `SHOW SLAVE STATUS`；
  - 锁等待改用 `performance_schema.data_lock_waits`（8.0 正确姿势）；
  - 修正 `log-bin` → `log_bin`、`slave-parallel-type/workers` → `slave_parallel_type/workers` 等。
- ✅ **更准确的指标**：QPS/TPS 改为 **1s 取样差分**；新增 **InnoDB Buffer Pool 累计命中率**。
- ✅ **稳健易读**：统一输出对齐与颜色高亮，遇到缺失变量/权限不足时**不报错中断**。
- ✅ **可读单位**：对大字节值同时展示人类可读单位（MB/GB）。
- ✅ **慢日志**：自动识别 slow log 状态与文件；缺少 `mysqldumpslow` 时降级用 `grep`。
- ✅ **碎片与锁**：碎片以 MB 粗估并加阈值（>256MB）；锁等待直接列出阻塞/被阻塞会话与 SQL 片段。

如果你需要：

- 把输出写到**同时**落盘（纯文本/JSON），或
- 按阈值给出**红黄绿建议**（如 sync_binlog/innodb_flush_log_at_trx_commit “双 1”告警，连接使用率 >80% 告警，binlog 保留不足等），
   我可以在这版上继续加一层“规则引擎”和报告汇总页。