# MySQL 8.0 error log 撑爆磁盘 —— 疑难排查文档

> 现场参考 / 复盘文档
> 涉及 MySQL 版本:8.0.26 Community(容器化,`docker run` 部署)
> 现象一句话:`mysql_error.log` 疯狂增长(一度 58G),威胁磁盘写满 —— 但**前后是两个完全不同的根因**,表现却一样。

---

## 0. TL;DR(结论速览)

本次事故日志暴涨其实是**两个独立问题**,因为都通过"stderr 重定向进 error log + 无限增长"表现成同一个"日志撑爆盘",极易被误判为一个问题。

| # | 根因 | 关键特征 | 解决手段 | 是否需重启 |
|---|------|----------|----------|------------|
| 一 | InnoDB 缓冲池过小(默认 128M)→ 严重抖动 → 触发 8.0 早期版本 flush 计数器**下溢** bug | `buffer pool: 18446744073709551614`(= 2⁶⁴−2);mysqld CPU 506%、`wa 0.0`;`SHOW VARIABLES` 卡死 | 调大 `innodb_buffer_pool_size` 写进配置 + **重启**清掉内存坏计数 | 是 |
| 二 | 容器缺 `CAP_SYS_NICE`,libnuma 的 `mbind(2)` 被 Docker seccomp 拒(EPERM)→ 裸消息刷进 error log。TempTable 走 mmap 是高负载下的**主力放大器** | error log 持续刷 `mbind: Operation not permitted`(无时间戳、无 `[MY-xxxx]` 前缀) | 动态 `SET GLOBAL temptable_use_mmap=OFF` 压掉主力(量降 99%);**残余只能靠重建容器加 `--cap-add=SYS_NICE` 根治**;当下用 logrotate 消除撑盘风险 | 压制不需要;根治需重建 |

**通用止血动作**:error log 被 mysqld 打开着,**不要 `rm`**(不会立即释放空间),原地截断即可:`: > /var/log/mysql/mysql_error.log`。
**顺序铁律**:**先关/压源头,再截断**。源头没停就截断,日志会立刻被重新填满。

---

## 1. 环境信息

- 宿主:Ubuntu,内存 16G(`16037 MB`),Swap 4G,已运行 93 天。
- 容器:`demo-mysql`,镜像 `9da615fced53`(镜像已 4 年),`MySQL 8.0.26 Community Server - GPL`。
- 端口映射:`0.0.0.0:13306->3306`。
- 数据:`/var/lib/mysql` 约 **285G**,约 **130 个库**(单实例承载大量业务库)。
- 存储:overlay → `/dev/mapper/ubuntu--vg-ubuntu--lv`,590G。
- 容器内配置:`/etc/mysql/conf.d/config-file.cnf` 只设了时区和 `log_error` 路径,**没有任何缓冲池调优** → 缓冲池取默认值(128M)。

```bash
# 关键配置(容器内)
$ cat /etc/mysql/conf.d/config-file.cnf
[mysqld]
default-time_zone='+8:00'
log_error=/var/log/mysql/mysql_error.log
[mysqld_safe]
log_error=/var/log/mysql/mysql_error.log
```

> 提示:`log_error` 指定后,mysqld 启动时会把进程 **stderr 重定向到该文件**。这意味着不仅 MySQL 自己的日志,连底层库(如 libnuma)直接往 stderr 打的裸消息也会落进这个文件 —— 这是问题二能进 error log 的直接原因,后面详述。

---

## 2. 问题一:InnoDB 缓冲池空闲块风暴 + 计数器下溢

### 2.1 现象

`mysql_error.log` 增长到 **58G**,和数据在同一个 lv 上,面临磁盘写满风险。`tail` 内容是同一条 warning 每秒刷成千上万次:

```bash
$ ls -lrth /var/log/mysql/
-rw-r--r-- 1 mysql mysql 58G Jul 21 06:29 mysql_error.log

$ tail -f mysql_error.log
... [Warning] [MY-011959] [InnoDB] Difficult to find free blocks in the buffer pool
(3085 search iterations)! 3085 failed attempts to flush a page! Consider increasing
the buffer pool size. ... Pending flushes (fsync) log: 0; buffer pool: 18446744073709551614.
9570761 OS file reads, 1775526 OS file writes, 1062936 OS fsyncs. ...
```

### 2.2 排查思路与关键判据

**判据 1 —— `buffer pool: 18446744073709551614`**
这个数正好是 `2⁶⁴ − 2`,是无符号计数器**下溢到 −2** 后回绕的典型特征。InnoDB 内部"待 flush 页数"一旦下溢,代码会永远认为有海量待刷页 → 疯狂自旋找空闲块 → 疯狂打这条 warning。**改配置不会让它自动恢复,必须重启清掉内存里的坏计数器。** 这是 8.0 早期版本(含 8.0.26)一个已知的 InnoDB flush 计数器竞态 bug。

**判据 2 —— 是 CPU 活锁,不是 I/O 问题**

```bash
$ top
top - 06:41:43 up 93 days, load average: 21.91, 22.50, 21.77
%Cpu(s): 36.6 us, 5.7 sy, 57.2 id, 0.0 wa, ...        # 注意 wa = 0.0
  PID USER   ...  %CPU %MEM   COMMAND
30109 999    ...  506.3 14.2  mysqld                   # 单进程 506% CPU

$ free -m
              total   used   free   shared  buff/cache  available
Mem:          16037   3281   1201        0       11554       12369
```

`wa`(iowait)是 0、`buff/cache` 高达 11.5G(数据基本都在页缓存里),说明线程**不是在等磁盘**,而是卡在"找不到空闲块"的循环里空转 —— 与判据 1 的下溢死循环吻合。

**判据 3 —— `SHOW VARIABLES` 卡死**

```sql
mysql> SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
（无限卡住,无返回）
```

空转线程已经把缓冲池相关的 mutex 占死,任何碰缓冲池状态的操作都排在风暴后面出不来。**推论:此时在线 `SET GLOBAL innodb_buffer_pool_size` 也会同样卡死,不能走在线调整这条路。**

**判据 4 —— 缓冲池确实没调 & 容器无内存限制**

```bash
$ docker inspect demo-mysql | grep -i memory
            "Memory": 0,          # 0 = 无限制,可放心把缓冲池调大
            "MemorySwap": 0,
            ...
```

配置里没设 `innodb_buffer_pool_size` → 默认 128M。130 库 / 285G 数据配 128M 缓冲池,必然疯狂换页抖动,而这正是触发下溢竞态的土壤(并发 flush 越猛越容易踩)。`9570761 reads` ≫ `1775526 writes`(读远多于写)也印证命中率极低、一直在换页。

### 2.3 处理步骤(含具体命令)

**① 登录 MySQL(注意:`localhost` 走 socket 可能被拒,用 `127.0.0.1` 走 TCP)**
```bash
$ mysql -u root -p                 # 报 ERROR 1045 Access denied（localhost/socket）
$ mysql -u root -p -h 127.0.0.1    # OK
mysql> SELECT VERSION();           # 确认 8.0.26
```

**② 立即回收 58G(安全、无需重启)**
```bash
: > /var/log/mysql/mysql_error.log
# 空间立刻回来,mysqld 继续往同一句柄追加,无风险
```
效果:`df -h` 使用率从 73% 掉回 63%(释放约 58G)。

**③ 写入缓冲池配置(重启前)**
```bash
cat > /etc/mysql/conf.d/tuning.cnf <<'EOF'
[mysqld]
innodb_buffer_pool_size      = 8G
innodb_buffer_pool_instances = 8
EOF
```
16G 内存给 8G:留够 OS、同宿主的 logstash(1G 堆)、连接与临时表开销。

**④ 重启,清掉下溢计数器**
```bash
docker restart demo-mysql
docker logs -f demo-mysql
```
**预期**:mysqld 正在 506% 空转,优雅关闭会被占锁线程卡住,docker 超时后发 SIGKILL → **基本会走一次 crash recovery**。这没关系:2⁶⁴ 是**内存**计数器,磁盘数据页没坏,InnoDB 崩溃恢复是 ACID 安全的,不丢已提交数据。启动时盯日志里 `Starting crash recovery` → `Apply batch completed` → `ready for connections`,看到在跑 recovery 就等它,别当成卡住又去 kill。

### 2.4 验证(重启后 `SHOW ENGINE INNODB STATUS`)

```sql
mysql> SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
+-------------------------+------------+
| innodb_buffer_pool_size | 8589934592 |     -- 8G 生效
+-------------------------+------------+

mysql> SHOW ENGINE INNODB STATUS\G
...
Pending flushes (fsync) log: 0; buffer pool: 0          -- ← 下溢计数已清零,死循环消失
Total large memory allocated 8770551808
Buffer pool hit rate 991 / 1000                         -- ← 命中率 99%
Free buffers 482831 / Buffer pool size 524241 (pages)   -- ← 大量空闲页
0 queries inside InnoDB, 0 queries in queue             -- ← 无排队
RW-shared/excl spins 0 ... OS waits 0                   -- ← 无锁等待
```

`top` 里 mysqld CPU 掉回正常。缓冲池刚启动只载入约 4 万页,会随业务访问逐步预热填满,属正常现象。

---

## 3. 问题二:`mbind: Operation not permitted` 刷屏

### 3.1 现象

重启解决问题一后,error log **再次持续暴涨**,6 分钟涨到 467M,内容全是同一行:

```bash
$ tail -f /var/log/mysql/mysql_error.log
mbind: Operation not permitted
mbind: Operation not permitted
mbind: Operation not permitted
...
```

注意这行**没有时间戳、没有 `[MY-xxxx]` 前缀** —— 不是 MySQL 自己格式的日志。

### 3.2 根因(经排查修正后的结论)

**这行是谁打的**:`mbind: Operation not permitted` 是 glibc/libnuma 在 `mbind(2)` 系统调用被拒时**直接往 stderr 打的裸消息**。因为配了 `log_error`,mysqld 的 stderr 被重定向到该文件,所以它落进了 `mysql_error.log`,不只出现在 `docker logs`。

**为什么被拒(EPERM)**:`mbind` 用于 NUMA 内存策略绑定。Docker 默认 seccomp / capability 策略在容器缺少 `CAP_SYS_NICE` 时会拦掉 `mbind` / `set_mempolicy` → 返回 EPERM。这是 MySQL 8 官方镜像的一个长期已知现象(docker-library/mysql 有对应 issue),**业界公认的根治方式是给容器补 `CAP_SYS_NICE`**。

**`temptable_use_mmap` 扮演什么角色(重要修正)**:
最初一版判断"关掉 `temptable_use_mmap` 就能彻底停",**这个结论不准确**,现场验证已证伪(见 3.3)。准确的关系是:
- MySQL 8.0 默认 `internal_tmp_mem_storage_engine=TempTable` 且 `temptable_use_mmap=ON`,内部临时表内存超过 `temptable_max_ram`(默认 1G)时走 mmap,并对该内存做 NUMA 绑定 → 每次触发一次 `mbind` EPERM。业务繁忙(大量 GROUP BY / ORDER BY / 派生表)时,这条路径是**高负载下的主力放大器**,把日志刷成每秒几千行。
- 关掉 `temptable_use_mmap` 只是**掐掉了这个主力放大器**(量随即掉到每分钟几十行),但 **mysqld 还有其他 NUMA interleave 路径**在零星触发 mbind,**没有任何运行时变量能把它们全部关掉**。
- 因此:`SET GLOBAL temptable_use_mmap=OFF` 是"降噪 99%"的**缓解**,不是**根治**;根治只有 `CAP_SYS_NICE`。

### 3.3 处理步骤(含具体命令与验证)

**① 缓解:动态关掉主力放大器(立即生效,无需重启)**
```sql
mysql> SET GLOBAL temptable_use_mmap = OFF;
-- 8.0.26 里该变量已 deprecated,可能回一句 deprecation 警告,不影响生效
```

**② 验证变量已生效**
```sql
mysql> SHOW VARIABLES LIKE 'temptable_use_mmap';
+--------------------+-------+
| temptable_use_mmap | OFF   |
+--------------------+-------+
```

**③ 持久化到 `conf.d/tuning.cnf`(重启后仍生效)**
```bash
echo "temptable_use_mmap = OFF" >> /etc/mysql/conf.d/tuning.cnf
cat /etc/mysql/conf.d/tuning.cnf
# [mysqld]
# innodb_buffer_pool_size      = 8G
# innodb_buffer_pool_instances = 8
# temptable_use_mmap = OFF
```

> ⚠️ **坑(现场真实踩到)**:`.cnf` 里加这行**只在下次重启才生效**;要立刻止住必须先跑动态 `SET GLOBAL`。两者配合:动态命令负责当下,`.cnf` 负责重启后。

**④ 验证:量级大幅下降,但残余仍在(证伪"彻底停"的关键观察)**
```bash
$ tail -f /var/log/mysql/mysql_error.log
mbind: Operation not permitted                          # ← 仍偶发,但从每秒几千行 → 每分钟几十行
2026-07-21T07:24:20 ... [Note] [MY-010914] Aborted connection ... db: 'dns' ...
mbind: Operation not permitted
...
```
残余量对磁盘已无威胁,**撑盘风险靠 logrotate 彻底消除**(见 §5),那行日志本身留待 `CAP_SYS_NICE` 根治。

**⑤ 根治(维护窗口重建/重部署容器)**
运行中的容器**加不了 capability**,必须重建:
```bash
# docker run 方式
docker run ... --cap-add=SYS_NICE ...

# 或 docker-compose.yml
services:
  db:
    image: <your-mysql-image>
    cap_add:
      - SYS_NICE
```
重建后重启,并验证:
```bash
docker exec demo-mysql capsh --print | grep cap_sys_nice
# 输出中出现 cap_sys_nice 即为生效;此后 mbind 不再出现
```
> 可选诊断:`SHOW VARIABLES LIKE '%numa%';` 看 `innodb_numa_interleave` 是否 ON。注意它是**启动时**做一次缓冲池 interleave,不是本次这种持续刷的来源;是否 ON 都不改变"根治靠 `CAP_SYS_NICE`"的结论。

---

## 4. 关键经验与踩坑点(重点)

1. **同一个"日志撑爆盘"可能是多个不同根因**。本次先后两次暴涨,一个是缓冲池计数器下溢的 `[MY-011959]` 风暴,一个是 libnuma 的 `mbind` 裸消息,处理手段完全不同。看到 error log 涨,先看**刷的是哪条**,别急着归为一类。

2. **`log_error` = stderr 重定向**:底层库(libnuma 等)直接写 stderr 的消息也会进 error log,所以里面可能混有非 MySQL 格式的行(无时间戳、无 `[MY-xxxx]`)。见到这种行,往"底层库 / 系统调用 / 容器权限"方向查,而不是 SQL 层。

3. **顺序铁律:先关/压源头,再截断日志**。源头没停就截断,日志会立刻被重新填满,白干。

4. **回收被打开的日志文件用截断,不用 `rm`**:`: > file` / `truncate -s 0 file` 立即释放且句柄不失效;`rm` 在进程持有句柄时空间不会立即释放。

5. **`config 文件 ≠ 立即生效`(本次真实踩到)**:把 `temptable_use_mmap = OFF` 写进 `.cnf` **只在下次重启才生效**;要立刻止住必须跑动态 `SET GLOBAL`。

6. **"量降下来" ≠ "根治"(本次真实踩到)**:`temptable_use_mmap=OFF` 把 mbind 从每秒几千行压到每分钟几十行,容易误以为解决了。实际它只掐了主力放大器,残余来自其他 NUMA 路径,**唯一彻底解法是容器加 `CAP_SYS_NICE`**。定位这类问题时,别把"显著缓解"当成"消除",要用 `tail` 观察是否归零来确认。

7. **`2^N ± 小数` 的巨值 = 计数器溢出/下溢信号**:`18446744073709551614 = 2⁶⁴−2`,一眼认出是无符号计数器下溢;这类内存计数器坏了**只能重启清**,调参无效。

8. **`top` 高 CPU + `wa 0.0` = 活锁/空转,不是 I/O 瓶颈**;配合 `SHOW ENGINE INNODB STATUS` 的 SEMAPHORES / Pending flushes 段定位。

9. **风暴期间在线改参数会被同一把锁挡住**:`SHOW VARIABLES` 都卡死时,`SET GLOBAL` 同样卡死,别指望在线调整,直接走"改配置 + 重启"。

10. **容器内连不上 `root@localhost`**:`mysql -u root -p` 走 socket 报 `ERROR 1045`,改用 `-h 127.0.0.1` 走 TCP 即可(账号按 host 授权不同)。

---

## 5. 遗留事项 / 维护窗口 Checklist

以下多数不是急救步骤,需在**能干净停库的维护窗口**内做:

- [ ] **error log 轮转(建议尽快做)**:配 logrotate,是当前压制 mbind 残余、杜绝再次撑盘的直接手段。示例(宿主上,针对容器内路径对应的宿主路径或用 `docker exec`):
  ```
  /var/log/mysql/mysql_error.log {
      size 200M
      rotate 5
      missingok
      notifempty
      compress
      delaycompress
      copytruncate
  }
  ```
  > 用 `copytruncate` 可免去让 mysqld 重开文件句柄的复杂度;若走 `FLUSH ERROR LOGS`/信号方式则用 `postrotate` 触发。
- [ ] **重建容器加 `--cap-add=SYS_NICE`**:从根上消除 `mbind` 报错(唯一彻底解法)。重建前先备份数据卷/确认挂载。
- [ ] **全量备份**(mysqldump 或物理备份),作为下面升级类变更的前置。
- [ ] **升级掉 8.0.26**:缓冲池 flush 下溢是这代 InnoDB 的已知 bug,根治需升到较新的 8.0 小版本。镜像已 4 年,一并更新。
- [ ] **redo log 调大**:当前是旧式 `ib_logfile0/ib_logfile1`(< 8.0.30),默认偏小,大写入时频繁 checkpoint。**必须在一次干净关闭后**再改。8.0.30+ 用 `innodb_redo_log_capacity`,更早用 `innodb_log_file_size`。
- [ ] **容量评估**:130 库 / 285G 挤在一个 16G 容器里本就吃紧。长期考虑加内存、按业务拆实例,或并入主从 / keepalived 架构分担。
- [ ] **配置持久化确认**:`tuning.cnf` 位于容器可写层。若本实例由 compose / 脚本重建产生,务必把它落到挂载卷或 compose 定义里,否则一旦 `docker rm` 重建就丢失。

---

## 6. 附 A:全程命令时间线(可直接照抄参考)

```bash
# ---------- 侦察 ----------
docker ps
docker exec -it demo-mysql /bin/bash
df -h                                   # 看磁盘水位
du -h --max-depth=1 /var/lib/mysql      # 看各库占用(定位大库)
cat /etc/mysql/my.cnf
cat /etc/mysql/conf.d/config-file.cnf   # 发现没设缓冲池
ls -lrth /var/log/mysql/                # 发现 error log 58G
tail -f /var/log/mysql/mysql_error.log  # 看刷的是哪条 → MY-011959 + 2^64 下溢

# ---------- 问题一:止血 + 定性 ----------
: > /var/log/mysql/mysql_error.log      # 截断回收 58G（不要用 rm）
mysql -u root -p                        # localhost 被拒
mysql -u root -p -h 127.0.0.1           # 用 TCP 登录
#   SELECT VERSION();                             -> 8.0.26
#   SHOW VARIABLES LIKE 'innodb_buffer_pool_size';-> 卡死（锁被占）
free -m                                 # 16G 内存,buff/cache 高
docker inspect demo-mysql | grep -i memory   # Memory:0 无限制
top                                     # mysqld 506% CPU, wa 0.0 → 活锁

# ---------- 问题一:处理 ----------
cat > /etc/mysql/conf.d/tuning.cnf <<'EOF'
[mysqld]
innodb_buffer_pool_size      = 8G
innodb_buffer_pool_instances = 8
EOF
docker restart demo-mysql               # 会强杀 + crash recovery,ACID 安全
docker logs -f demo-mysql               # 盯 recovery 跑完 → ready for connections

# ---------- 问题一:验证 ----------
mysql -h127.0.0.1 -uroot -p -e \
  "SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; SHOW ENGINE INNODB STATUS\G"
#   -> buffer pool: 0（下溢清零）、8G 生效、hit rate 991/1000

# ---------- 问题二:mbind 刷屏 ----------
tail -f /var/log/mysql/mysql_error.log        # 满屏 mbind: Operation not permitted
mysql -h127.0.0.1 -uroot -p -e "SET GLOBAL temptable_use_mmap = OFF;"   # 缓解:压主力
mysql -h127.0.0.1 -uroot -p -e "SHOW VARIABLES LIKE 'temptable_use_mmap';"  # 验证 OFF
echo "temptable_use_mmap = OFF" >> /etc/mysql/conf.d/tuning.cnf         # 持久化
: > /var/log/mysql/mysql_error.log            # 确认量级下降后再截断
tail -f /var/log/mysql/mysql_error.log        # 观察:仍有零星残余 → 需 CAP_SYS_NICE 根治

# ---------- 问题二:根治(维护窗口重建容器）----------
# docker run ... --cap-add=SYS_NICE ...   或  compose: cap_add: [SYS_NICE]
docker exec demo-mysql capsh --print | grep cap_sys_nice   # 验证 cap 生效
```

## 7. 附 B:本次最终生效的 `conf.d/tuning.cnf`

```ini
[mysqld]
innodb_buffer_pool_size      = 8G
innodb_buffer_pool_instances = 8
temptable_use_mmap           = OFF
```

> 说明:
> - `innodb_buffer_pool_size` / `instances` —— 需重启生效,已随本次重启生效。
> - `temptable_use_mmap` —— `.cnf` 项重启生效;当下用 `SET GLOBAL temptable_use_mmap=OFF` 动态止血。它只是**缓解**手段;维护窗口给容器补 `--cap-add=SYS_NICE` 后,mbind 根治,可视情况回收这条。

---

*文档结束。适配版本 MySQL 8.0.26 容器化部署;其他版本参数名与默认值请以实际 `SHOW VARIABLES` 为准。*
