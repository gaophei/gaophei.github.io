下面给出三个不同“强度”的**持续连接池测试**范式，你可按需要取用或改造。示例基于 **python-oracledb 3.x Thick 模式**，但思路同样适用于 Java HikariCP、Go database/sql 等——核心就是：**循环取连接 → 执行轻量 SQL → 记录耗时/错误 → 归还连接**。

------

## 1. “心跳”级：轻量健康监测

> 目标：验证池一直可用、延迟和错误率。
>  负载：很低；适合守护进程或运维探活脚本。

```python
#!/usr/bin/env python3
import oracledb, time, csv, datetime

oracledb.init_oracle_client(lib_dir="/root/db/instantclient_11_2")

pool = oracledb.SessionPool(user="system", password="oracle",
                            dsn="127.0.0.1:1521/XE",
                            min=1, max=5, increment=1,
                            timeout=60, # 闲置多久回收
                            getmode=oracledb.SPOOL_ATTRVAL_WAIT)

LOG = "ping_log.csv"
with open(LOG, "a", newline="") as f:
    writer = csv.writer(f)
    while True:
        t0 = time.perf_counter()
        ok, err = 1, ""
        try:
            with pool.acquire() as conn, conn.cursor() as cur:
                cur.execute("SELECT 1 FROM dual")
                cur.fetchone()
        except Exception as e:
            ok, err = 0, repr(e)
        dt = (time.perf_counter() - t0) * 1000  # ms
        writer.writerow([datetime.datetime.now(), ok, f"{dt:.2f}", err])
        f.flush()
        time.sleep(5)          # 每 5 s 心跳一次
```

- **输出**：CSV 行形如 `2025-07-08 07:40:01.123456,1,4.58,`（1=成功；延迟 4.58 ms）。
- 配合 `tail -f ping_log.csv` 或可视化工具（Grafana → Promtail/Loki）即可长期观测。

------

## 2. “并发”级：小规模压力/回归测试

> 目标：验证池在并发 & 反复建立/释放下无泄漏、无偶发异常。

```python
import oracledb, concurrent.futures as fut, time, statistics

N_WORKERS = 20        # 并发线程数 ≈ 最大活跃连接数
LOOP_PER_WORKER = 500 # 每线程循环执行次数

oracledb.init_oracle_client(lib_dir="/root/db/instantclient_11_2")
pool = oracledb.SessionPool(user="system", password="oracle",
                            dsn="127.0.0.1:1521/XE",
                            min=5, max=N_WORKERS, increment=2)

latencies, errors = [], 0
def task(_):
    global errors
    for _ in range(LOOP_PER_WORKER):
        t0 = time.perf_counter()
        try:
            with pool.acquire() as conn, conn.cursor() as cur:
                cur.execute("SELECT /*+ RESULT_CACHE */ SYSDATE FROM dual")
                cur.fetchone()
        except Exception:
            errors += 1
        else:
            latencies.append((time.perf_counter()-t0)*1000)

with fut.ThreadPoolExecutor(max_workers=N_WORKERS) as ex:
    ex.map(task, range(N_WORKERS))

print(f"Total requests: {N_WORKERS*LOOP_PER_WORKER}")
print(f"Errors: {errors}")
print(f"p50={statistics.quantiles(latencies, n=100)[49]:.2f} ms, "
      f"p95={statistics.quantiles(latencies, n=100)[94]:.2f} ms, "
      f"max={max(latencies):.2f} ms")
```

- **重点**：线程数 ≤ `max`，否则池会排队等待。
- 可在循环里改成业务核心 SQL，观测更贴近真实负载。

------

## 3. “高压”级：长时间 soak / 漏检

> 目标：24 h 持续随机负载，找连接泄漏、句柄耗尽、ORA-04031 等边缘问题。
>  建议用 **Locust、k6** 或 **pytest-benchmark** 之类专业压测框架，下面给出最小裸脚本雏形：

```python
import oracledb, random, time, threading

oracledb.init_oracle_client(lib_dir="/root/db/instantclient_21_13")
pool = oracledb.SessionPool(user="bench", password="bench",
                            dsn="host:1521/XE", min=5, max=50,
                            increment=5, timeout=120)

SQLS = [
  "SELECT COUNT(*) FROM big_table",
  "SELECT /*+ FIRST_ROWS(10) */ * FROM big_table WHERE ROWNUM <= 10",
  "SELECT SUM(col) FROM big_table WHERE id BETWEEN :1 AND :2"
]

def worker():
    while True:
        try:
            with pool.acquire() as conn, conn.cursor() as cur:
                sql = random.choice(SQLS)
                cur.execute(sql, (random.randint(1,1e6), random.randint(1,1e6)))
                cur.fetchone()
        except Exception as e:
            print("ERR:", e)

threads=[threading.Thread(target=worker, daemon=True) for _ in range(40)]
[t.start() for t in threads]
# 主线程定期打印池状态
while True:
    print("Pool stats:", pool.get_stats())
    time.sleep(30)
```

- **监控**
  - `pool.get_stats()` 会给出 `openCount / busyCount / timeoutCount` 等指标。
  - Oracle 端可查看 `V$SESSION`, `V$PROCESS`, `V$RESOURCE_LIMIT`。
  - 宿主机侧监测 CPU / MEM / 网络 / fd 使用率。
- **停止**：Ctrl-C；或设定 `time.sleep(duration)` 后 `sys.exit()`。

------

### 贴士

| 场景               | 建议                                                         |
| ------------------ | ------------------------------------------------------------ |
| **连接偶发超时**   | 增大 `connection_timeout` (Hikari / JDBC) or `timeout` (python-oracledb)。 |
| **想测试自动重连** | 先 `docker pause oracle11g` 5 s 模拟网络中断，再继续跑脚本。 |
| **想在 k8s 内测**  | 用 `service.cluster.local:1521/XE` 代替 `127.0.0.1` 并确保 `Service` + `Headless`/`ClusterIP` 配置正确。 |
| **限制**           | Oracle XE 11g 最多 1 GB 内存 & 1 CPU，压力测试别太猛；否则 `ORA-12516`。 |

------

> **总结一句**：持续连接池测试 = 持续「取连-跑 SQL-归还」，外加**采集延迟/错误/池状态**。
>  心跳脚本保活，线程/协程脚本压测，结合 Oracle + 系统监控即可对连通性与稳定性做到长期“看得见”。