```bash
bash-5.1# ./pod_jvm.sh jstat -h
Usage: 
jps
  pod_jvm.sh <POD_NAME> jps [-help]
  pod_jvm.sh <POD_NAME> jps [-q] [-mlvV] [<pid>]
jstat
  pod_jvm.sh <POD_NAME> jstat -help|-options
  pod_jvm.sh <POD_NAME> jstat -<option> [-t] [-h<lines>] <vmid> [<interval> [<count>]]
jstack
  JPID=<JVM PID> pod_jvm.sh <POD_NAME> jstack [-help]
  JPID=<JVM PID> pod_jvm.sh <POD_NAME> jstack [-l] <JVM PID>
jmap
  JPID=<JVM PID> pod_jvm.sh <POD_NAME> jmap -h
  JPID=<JVM PID> pod_jvm.sh <POD_NAME> jmap -histo <JVM PID>
  JPID=<JVM PID> pod_jvm.sh <POD_NAME> jmap -dump:live,format=b,file=</path/in/container/heap.bin> <JVM PID>
get
  pod_jvm.sh <POD_NAME> get </path/in/container>
container-pid
  pod_jvm.sh container-pid <PID>
container-name-by-pid
  pod_jvm.sh container-name-by-pid <PID>
create-jvm-socket
  pod_jvm.sh <POD_NAME> create-jvm-socket <PID>
delete-jvm-socket
  pod_jvm.sh delete-jvm-socket <PID>
mock-usr-grp
  pod_jvm.sh <POD_NAME> mock-usr-grp
purge-usr-grp
  pod_jvm.sh purge-usr-grp
bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-7886b4d765-2mj7p jps
2812446 app.jar
2973200 Jps
bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-7886b4d765-2mj7p jstat -gcutil 2812446 1000 5
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT   
  0.00 100.00  59.24  15.76  93.23  90.17     58    3.482     0    0.000    3.482
  0.00 100.00  59.34  15.76  93.23  90.17     58    3.482     0    0.000    3.482
  0.00 100.00  59.60  15.76  93.23  90.17     58    3.482     0    0.000    3.482
Exception in thread "main" java.lang.InternalError: a fault occurred in a recent unsafe memory access operation in compiled Java code
        at java.util.HashMap.resize(HashMap.java:705)
        at java.util.HashMap.putVal(HashMap.java:630)
        at java.util.HashMap.put(HashMap.java:613)
        at sun.tools.jstat.ExpressionExecuter.evaluate(ExpressionExecuter.java:73)
        at sun.tools.jstat.ExpressionExecuter.evaluate(ExpressionExecuter.java:86)
        at sun.tools.jstat.ExpressionExecuter.evaluate(ExpressionExecuter.java:86)
        at sun.tools.jstat.ExpressionExecuter.evaluate(ExpressionExecuter.java:87)
        at sun.tools.jstat.ExpressionExecuter.evaluate(ExpressionExecuter.java:86)
        at sun.tools.jstat.RowClosure.visit(RowClosure.java:57)
        at sun.tools.jstat.OptionFormat.apply(OptionFormat.java:82)
        at sun.tools.jstat.OptionOutputFormatter.getRow(OptionOutputFormatter.java:66)
        at sun.tools.jstat.JStatLogger.logSamples(JStatLogger.java:149)
        at sun.tools.jstat.Jstat.logSamples(Jstat.java:189)
        at sun.tools.jstat.Jstat.main(Jstat.java:70)
bash-5.1# 
      
bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-7886b4d765-2mj7p jstat -gcutil 2812446 1000 5
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT   
  0.00 100.00  88.38  15.76  93.23  90.17     58    3.482     0    0.000    3.482
  0.00 100.00  88.64  15.76  93.23  90.17     58    3.482     0    0.000    3.482
  0.00 100.00  89.01  15.76  93.23  90.17     58    3.482     0    0.000    3.482
  0.00 100.00  89.01  15.76  93.23  90.17     58    3.482     0    0.000    3.482
  0.00 100.00  89.32  15.76  93.23  90.17     58    3.482     0    0.000    3.482
bash-5.1# 
```





------------------



下面给你一份「在 K8s 里排查 Java 进程」的实用手册，重点放在 jstat / jstack（也顺带补齐 jcmd/jmap），并结合你贴出来的输出做一次现场解读与下一步建议。

# 一、常用 JVM Tools 一览（生产可用）

- **jps**：列出 Java 进程与 PID。
- **jstat**：采样查看类加载、编译器、GC 各分代/区域的使用率与次数/耗时。轻量、适合在线观察趋势。
- **jstack**：线程栈快照。看“卡死/死锁/高 CPU/频繁 GC 造成停顿”的第一选择。
- **jcmd**：更现代、更通用的“瑞士军刀”：线程、GC、堆信息、类直方图、触发 heap dump 等都能做（JDK 8u/11+ 推荐优先用它）。
- **jmap**：堆直方图 / 堆转储（会停顿，慎用在线业务）。
- **jfr（Java Flight Recorder）**：低开销性能剖析（JDK 11+；生产场景很香）。
- **jhsdb**：离线分析崩溃 / core dump。

> K8s 实操：你的 `pod_jvm.sh` 已经把 exec 进 Pod + 指定 PID 封装了，继续沿用即可。

------

# 二、jstat 速查（参数与列解释）

常用子命令：

- `-gcutil`：**百分比视图**（最常用）。
- `-gccause`：最近一次 / 当前 GC 的原因（定位“为何在 GC”很关键）。
- 其他：`-gc`（容量+已用）、`-gccapacity`、`-gcnew*`、`-gcold*`、`-class`、`-compiler`、`-printcompilation`。

`-gcutil` 典型列解释（G1/Parallel 都通用，G1 只是实现不同）：

- **S0/S1**：两个 Survivor 区使用率（%）。一次 Minor GC 后通常一满一空是正常的。
- **E**：Eden 使用率（%）。分配速率高时会快速上涨，触发 Minor GC 后会回落。
- **O**：Old/Tenured 使用率（%）。如果持续上升且难以下降，留意“晋升过多/长期对象累积”。
- **M**：Metaspace 使用率（%）。接近 100% 风险较大（可能 Meta OOM）。
- **CCS**：Compressed Class Space 使用率（%）。
- **YGC / YGCT**：Minor GC 次数 / 总耗时（秒）。
- **FGC / FGCT**：Full GC 次数 / 总耗时（秒）。
- **GCT**：所有 GC 总耗时（秒）= YGCT + FGCT。

`-gccause` 里常见 Cause：

- **G1 Evacuation Pause (young/mixed)**：年轻代/混合收集停顿。
- **Allocation Failure**：分配失败触发 Young GC。
- **Metadata GC Threshold** / **Metaspace**：元空间压力触发并发周期/FGC。
- **To-space exhausted**：G1 复制失败，可能退化为 Full GC（要警惕）。

------

# 三、jstack 速查（怎么「看」）

命令：`jstack [-l] [-m] [-F] <pid>`

- `-l`：附加锁/等待对象信息（**默认加上**，定位锁阻塞很有用）。
- `-m`：混合 native 帧（排查 JNI 相关/阻塞在本地方法时用）。
- `-F`：无法正常 attach 时强制（不得已再用）。

**怎么看：**

1. **线程状态总览**
   - `RUNNABLE`：真忙（或阻塞在 syscalls）。结合 top 看高 CPU 线程。
   - `BLOCKED`：在 `synchronized` 互斥锁上互斥等待（典型热点锁/死锁线索）。
   - `WAITING/TIMED_WAITING`：正常等待（队列/锁/定时器/网络）。大量此状态通常不是问题核心。
2. **热点线程定位**
   - `top -H -p <pid>` 拿到 LWP/TID（十进制），转十六进制对齐 jstack 的 `nid=0x...`：
      `printf "0x%x\n" <tid>`
   - 在 dump 里搜索该 nid，看其栈顶在忙什么方法。
3. **锁与队列**
   - 关注 `parking to wait for`、`BLOCKED on`、`waiting on condition`、`at java.util.concurrent` 等。
   - 末尾如出现 `Found one Java-level deadlock`，当场按提示查看涉及的线程与锁。
4. **GC 是否在“吃掉”停顿时间**
   - 看到大量 `VM Thread`、`GC Thread`、`Concurrent Mark`、`Safepoint` 相关栈，结合 jstat 的 YGC/FGC 以及 GC 日志判断是否 GC 抢占了时间。
5. **重复抓多次**
   - 连续抓 3–5 份（间隔 3–5 秒），找**稳定重复**的热点（偶发噪声不要被误导）。

> 生产技巧：**优先 `jcmd Thread.print -l`**，信息更全、兼容性好；`jmap -histo:live` 会触发 Full GC，慎用。

------

# 四、把你的 jstat 输出当场解读

你给的三段 `-gcutil`（pid 3997751）要点如下：

```
Eden(E)：65% → 70% 持续上涨
Old(O)：~9.95% 低位稳定
YGC：18（采样期间未增长，说明没发生新一次 Minor GC）
FGC：0
M：94.70%（元空间使用率很高）
CCS：92.58%（压缩类空间也很高）
S0=0 / S1=100（单侧 Survivor 满，属于常见形态）
总 GC 时间(GCT)：0.989s（仅为 Young 累计）
```

结论：

- **当前没有 GC 风暴**（采样窗口内 YGC 没变、FGC=0）。
- **Eden 在涨** → 说明**分配速率**存在，但尚未触发新一轮 Young GC。
- **Old 低位** → 没有明显“晋升积压”。
- **Meta/CCS 极高（>90%）** → **要重点关注**：如果继续增长，可能碰到 `Metaspace OOM`。
  - 在 G1 下，类卸载发生在并发周期 Remark 阶段；若长时间没有并发周期或类卸载被抑制，Meta 就只增不减。
  - 强烈建议尽快确认 **`-XX:MaxMetaspaceSize`** 是否有限制，以及是否存在**频繁动态类生成/热代理**（例如大量 `$$EnhancerByCGLIB`、`$$Lambda$`、JSP 动态编译、字节码框架等）。

------

# 五、现场排障“动作清单”（不改代码先拿证据）

**轻量、安全优先的顺序：**

1. **看 GC 原因**

   ```bash
   jstat -gccause <pid> 1000 5
   ```

   关注 `Cause` / `LastCause` 是否出现 `Metadata GC Threshold` / `To-space exhausted` 等信号。

2. **堆与区域快照（无停顿）**

   ```bash
   jcmd <pid> GC.heap_info
   jcmd <pid> GC.heap_region_detail    # JDK11+ G1 可用
   ```

3. **类直方图（尽量不用 live 版）**

   ```bash
   jcmd <pid> GC.class_histogram
   # 观察是否有大量动态类/代理类/Loader 累积
   ```

4. **线程快照（连续 3~5 次）**

   ```bash
   jcmd <pid> Thread.print -l > /tmp/th1.txt
   sleep 3; jcmd <pid> Thread.print -l > /tmp/th2.txt
   sleep 3; jcmd <pid> Thread.print -l > /tmp/th3.txt
   ```

   对比是否同一批线程持续 RUNNABLE/阻塞在相同点。

5. **必要时开 GC 日志（重启生效）**

   - JDK 8：`-XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/path/gc.log`
   - JDK 9+：`-Xlog:gc*,safepoint:file=/path/gc.log:utctime,tid,level,tags`
      用以确认停顿分布、类卸载情况、触发原因与时间线。

6. **只在窗口期触发一次直方图/堆转储（会停顿，避开高峰）**

   ```bash
   # 直方图（live 版会 Full GC，谨慎）
   jmap -histo:live <pid> | head -n 50
   
   # 堆转储（推荐用 jcmd，JDK11+）
   jcmd <pid> GC.heap_dump /tmp/heap-$(date +%s).hprof
   ```

   之后用 MAT/YourKit/IDEA Profiler 离线分析“顶层实例”、“支配树”。

------

# 六、如何解读“常见异味模式”

- **Young GC 很频繁，Eden 一直很高**
  - 说明**对象分配速率很高**。优先用 **JFR** 或 **async-profiler（alloc）** 找高分配热点；
  - 短期可调大 `-XX:MaxGCPauseMillis`（G1 会倾向更大 Eden，降低 YGC 频率），或适度增大堆。
- **Old 持续上升、FGC 偶发且耗时长**
  - 典型“长期对象积累/内存泄漏”。用 `class_histogram` + 堆转储找出**保留链**和可疑缓存/Map。
- **Meta/CCS 持续上升**
  - 排查**类加载器泄漏**、热代理；确保有并发标记周期能触发类卸载；必要时设置
     `-XX:MaxMetaspaceSize=` 限制上限并**提早暴露问题**；或升级/修正产生动态类的库用法。
- **To-space exhausted / Promotion failure**
  - G1 复制失败 → 往往会退化 Full GC。考虑增大 `G1ReservePercent`（默认 10）与 `-XX:InitiatingHeapOccupancyPercent`，或者降低晋升压力（减少大对象短生存）。
- **高 CPU / 假死**
  - 用 `top -H` 找热点 TID → 映射到 jstack 的 `nid` → 看在忙什么。
  - 若大量 `BLOCKED` 于同一把锁，定位这把锁持有者的栈；考虑优化锁粒度/使用无锁结构/读写锁。

------

# 七、你遇到的 jstat InternalError（偶发）

报错：

```
java.lang.InternalError: a fault occurred in a recent unsafe memory access operation in compiled Java code
 at ... sun.tools.jstat.ExpressionExecuter...
```

这属于 **jstat 工具本身**在表达式/采样过程中偶发崩溃的已知类型（在某些 JDK 版本、容器/Alpine 环境下更容易出现）。通常对目标 JVM **无害**，重跑就能继续（你后面也成功了）。建议：

- **优先用 jcmd 等价命令** 做关键采样（更稳）：
   `jcmd <pid> GC.heap_info`、`jcmd <pid> VM.uptime`、`jcmd <pid> GC.class_histogram`。
- 确认生产镜像使用**稳定发行版 JDK**（如 Temurin/Oracle/OpenJDK LTS 的较新 update 版），尽量避开过老 build 或某些 musl 变体的已知坑。
- 如果频繁出现，考虑把 **jstat 的采样间隔拉大**、降低并发采样频率，或直接转用 jcmd。

------

# 八、立即可执行的诊断脚本（基于你的 `pod_jvm.sh`）

```bash
# 1) 看 GC 原因
./pod_jvm.sh <pod> jstat -gccause <pid> 1000 5

# 2) 看堆/区域概要
./pod_jvm.sh <pod> jcmd <pid> GC.heap_info

# 3) 看类直方图（无 live，先观测趋势）
./pod_jvm.sh <pod> jcmd <pid> GC.class_histogram | head -n 50

# 4) 连续线程快照 3 份
./pod_jvm.sh <pod> jcmd <pid> Thread.print -l > /tmp/th1.txt
sleep 3
./pod_jvm.sh <pod> jcmd <pid> Thread.print -l > /tmp/th2.txt
sleep 3
./pod_jvm.sh <pod> jcmd <pid> Thread.print -l > /tmp/th3.txt
```

------

# 九、结合你这台实例的“下一步建议”

1. **优先确认 Meta/CCS**：
   - `jcmd <pid> VM.flags` / `VM.system_properties` 看是否限制了 `MaxMetaspaceSize`；
   - `jcmd <pid> GC.class_histogram` 检查是否存在大量代理类/动态生成类；
   - 观察一段时间的 `-gccause`，看是否出现 `Metadata GC Threshold`，以及并发周期是否正常触发；
   - 若确实接近上限/持续上升：
     - 临时提高 `MaxMetaspaceSize`（并评估容器内存上限），
     - 或找出动态类来源并修复（如过度生成代理、热加载未卸载等）。
2. **监控 Eden 的回落节奏**：
   - 让 `-gcutil` 连续跑长一点，确认是否出现 Young GC 并回落；若 YGC 过于频繁，再看分配热点。
3. **保留一轮线程快照**：
   - 以便排除由锁/IO/外部依赖引发的响应性问题，避免一切都怪在 GC 上。

------

需要的话，我也可以把这些命令封成一份“值班排障清单”（含预期现象/阈值/处置建议）供你们团队直接跟着走。

-------------------------

```bash
#jstack日志分析
#pod authx-service-user-data-service-goa-74b9d59666-4rvr6
bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-4rvr6 jps
550857 Jps
3730591 app.jar
bash-5.1# 

bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-4rvr6 jstat -gcutil 3730591 1000 5
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT   
  0.00 100.00  85.23  66.57  76.57  59.25  15637  837.738  4418 53871.503 54709.241
  0.00 100.00  85.23  66.57  76.57  59.25  15637  837.738  4418 53871.503 54709.241
  0.00 100.00  85.23  66.57  76.57  59.25  15637  837.738  4418 53871.503 54709.241
  0.00 100.00  85.23  66.57  76.57  59.25  15637  837.738  4418 53871.503 54709.241
  0.00 100.00  85.23  66.57  76.57  59.25  15637  837.738  4418 53871.503 54709.241

bash-5.1# JPID=3730591 ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-4rvr6 jstack 3730591 > /tmp/jstack-docker08.log

# pod authx-service-user-data-service-goa-74b9d59666-2v2kg
bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-2v2kg jps
2574394 Jps
372938 app.jar
bash-5.1# 

bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-2v2kg jstat -gcutil 372938 1000 5
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT   
  0.00 100.00  27.65  51.84  88.58  82.47   2939  135.203     0    0.000  135.203
  0.00 100.00  36.15  51.84  88.58  82.47   2939  135.203     0    0.000  135.203
  0.00 100.00  45.12  51.84  88.58  82.47   2939  135.203     0    0.000  135.203
  0.00 100.00  45.12  51.84  88.58  82.47   2939  135.203     0    0.000  135.203
  0.00 100.00  53.67  51.84  88.58  82.47   2939  135.203     0    0.000  135.203
bash-5.1# JPID=372938 ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-2v2kg jstack 372938 > /tmp/jstack-docker07.log

#pod authx-service-user-data-service-goa-74b9d59666-x4thh

bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-x4thh jps
657379 Jps
454652 app.jar
bash-5.1# ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-x4thh jstat -gcutil 454652 1000 5
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT   
  0.00 100.00  62.72  25.96  92.23  88.41    237    8.580     0    0.000    8.580
  0.00 100.00  62.80  25.96  92.23  88.41    237    8.580     0    0.000    8.580
  0.00 100.00  63.19  25.96  92.23  88.41    237    8.580     0    0.000    8.580
  0.00 100.00  63.74  25.96  92.23  88.41    237    8.580     0    0.000    8.580
  0.00 100.00  63.74  25.96  92.23  88.41    237    8.580     0    0.000    8.580
bash-5.1# JPID=454652 ./pod_jvm.sh authx-service-user-data-service-goa-74b9d59666-x4thh jstack 454652 > /tmp/jstack-docker09.log
bash-5.1#  
```



下面把 3 个 Pod 的 jstack / jstat 结果梳理成结论 + 处置建议（重点看异常的 docker08 那个 Pod）。

# 结论（TL;DR）

- **docker08（Unavailable 的那个 Pod）并非线程死锁**，Tomcat 的 Acceptor/Poller 在跑，业务工作线程大多在队列里等待；同时 **GC 线程非常活跃**。结合你贴的 `jstat`：`FGC=4418，FGCT≈53871s，GCT≈54709s`，这是典型 **Full GC 频繁 & 停顿超长（GC Thrashing）** 导致存活探针/就绪探针失败，Pod 被标为 Unavailable。jstack 里能看到 G1 的并发标记/Refinement 线程活跃，以及大量 http-nio 工作线程在 `TaskQueue.take()` 等待任务，这符合“进程在 GC，几乎没有能力处理请求”的场景。  
- **docker07 / docker09（Running 的两个 Pod）状态基本健康**：
  - Tomcat `Acceptor`/`Poller` 线程 RUNNABLE；
  - 大量 `http-nio-*-exec-*` 线程处于 WAITING（在任务队列里正常待命）；
  - RabbitMQ/Netty 相关线程 RUNNABLE；
  - GC 线程正常。以上都是典型“服务空闲或轻载”的健康形态。   

# 现场画像（关键证据）

- **docker08（异常）**
  - G1 相关线程（Concurrent Mark / Refinement）在跑；同时 `http-nio-8888-exec-*` 绝大多数在 `LinkedBlockingQueue.take()` 等待，说明线程没被锁住，而是整体处理能力被 GC 拖住。 
  - 结合 `jstat -gcutil` 的 **超高 FGC 次数与时间**，可判定为 **Full GC 频繁**（常见诱因：老年代/大对象分配失败、G1 To-space exhausted、Metaspace/类加载膨胀、内存泄漏等）。
- **docker07 / docker09（正常）**
  - `http-nio-*-Acceptor/Poller` RUNNABLE，`http-nio-*-exec-*` WAITING（队列取任务），RabbitMQ 线程 RUNNABLE，均为健康特征；GC 线程存在但无异常信号。 

# 可能原因（按概率从高到低）

1. **G1 频繁 Full GC**：如 Humongous 对象分配失败 / To-space exhausted / 老年代回收效果差，导致进入 Full GC 且停顿时间极长。你给的 `FGCT≈53871s`（近 15 小时累计停顿）基本坐实。
2. **堆/元空间配置与实际负载不匹配**：当前进程是 G1 + `-XX:+UseContainerSupport` + 百分比参数（`-XX:InitialRAMPercentage=50.0` 等），实际分配的 `Xmx/Metaspace` 可能偏紧，在该节点（docker08）上更容易触发 Full GC。
3. **内存泄漏或缓存失控**：例如大 Map/本地缓存/未关闭的 ByteBuf/反序列化大对象等，导致老年代不断膨胀，Full GC 也回收不动。
4. **节点维度的资源挤兑**：docker08 上 CPU 抢占严重时（或 cgroup 限速），会让 GC 更“吃力”，表现为 FGCT 飙升（建议同时核对该节点的 CPU/内存压力与 cgroup 限额）。

# 立即处置建议（先恢复可用性）

1. **先把 Unavailable 的 Pod 滚动重建/迁移到其他节点**（规避当前 GC 风暴，尽快恢复流量承载）。
2. **临时调大该部署的内存 & Java 堆**（例如把 `Xmx` 明确设到更合理的值，而不是百分比随容器波动），并确保 **Metaspace 上限** 也足够（`-XX:MaxMetaspaceSize=`）。
3. **降低单 Pod 压力**：临时把副本数 +1～2，或给 docker08 节点打 `NoSchedule` 先疏散负载，确认吞吐回稳后再复原。

# 根因排查与长期修复（强烈建议立刻打开 GC 日志）

1. **开启 GC 日志**（JDK8）并收集至少 10～30 分钟：

   ```
   -Xloggc:/tmp/gc.log
   -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime
   -XX:+PrintTenuringDistribution -XX:+PrintAdaptiveSizePolicy
   -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=10M
   ```

   有了 GC 日志，才能确认是否是 **Humongous Allocation / To-space exhausted / Metaspace** 等触发点。

2. **抓一次 Heap Dump（仅在问题复现且业务允许时）**：

   ```
   jmap -dump:format=b,file=/tmp/heap.hprof <PID>
   ```

   用 MAT/Eclipse Memory Analyzer 看 Top Dominator，定位大对象/泄漏路径。

3. **G1 参数微调（在确认瓶颈后再做）**：

   - 若是 Humongous 对象频发：减少巨型对象（例如避免超大 JSON/数组），或调小 `-XX:G1HeapRegionSize`（需谨慎，通常 1–8MB），优化对象分配策略。
   - 若是并发周期触发过晚：试试降低 `-XX:InitiatingHeapOccupancyPercent=30~45` 以更早开始并发标记。
   - 根据延迟目标设置 `-XX:MaxGCPauseMillis=200~500`（提示 G1 目标停顿）。

4. **应用侧优化**：

   - 自查是否有大 Map/缓存无限长/无淘汰；
   - 是否有批量反序列化巨型集合或图片/字节数组；
   - 第三方客户端（如 Redis/Rabbit）的缓冲是否可能囤积大量数据等。

5. **资源与容器配额**：确保 `requests/limits` 与 `Xmx/Metaspace` 一致（避免 JVM 以为有内存、容器却把 cgroup 限死的情况）。

# 证据摘取（供同事交叉验证）

- **docker08**：G1/GC 线程活跃；大量 `http-nio-8888-exec-*` 在队列里 WAITING；这是“吞吐被 GC 拖死”的典型形态。 
- **docker09**（健康）：`Acceptor`/`Poller` RUNNABLE，`exec-*` WAITING，AMQP 线程 RUNNABLE。 
- **docker07**（健康）：与上同，另见 RabbitListener 线程在阻塞队列正常取消息。 

------

需要的话，我可以基于你这三份 jstack 再做个**线程状态统计表**（RUNNABLE/WAITING/BLOCKED 分布）和 **GC 线索清单**，以及给出一份 **可直接复制进 Deployment 的 JVM 诊断参数**清单，方便快速回滚/验证。



---------------------------

下面把两份 jstack（docker07、docker08）做一个“结论先行 + 证据摘录 + 排查方法”的梳理。文中所有“证据”都来自你上传的两份 dump。

# 结论（先看这个）

1. **没有死锁/卡锁迹象。** 两份 dump 都未见 `BLOCKED` 或 “Found one Java-level deadlock” 之类特征；大量业务/容器线程处于 `WAITING/TIMED_WAITING`，在队列上“取任务”或“等定时任务”，这通常不是锁竞争导致的停顿。证据见后文。
2. **Tomcat 线程池“很多、但在等活儿”。** 出现**上百个** `http-nio-8888-exec-*` 线程，统一栈顶为 `TaskQueue.take(...)`，说明线程池里线程空闲等待任务，而不是被某个业务调用卡住；此类栈在 docker08 中随处可见，例如 `exec-790/788/785/...`（均在 `LinkedBlockingQueue.take -> TaskQueue.take` 上 WAITING）。
3. **RabbitMQ & Redis 线程表现正常。**
   - RabbitMQ：`AMQP Connection ...` 线程在 `socketRead0` 上 `RUNNABLE`/I/O 等待，属于**正常拉取/收包**姿态。两份日志都有此形态。
   - Redis（lettuce）：`lettuce-nioEventLoop...` 线程 `RUNNABLE`，栈顶为 `EPollArrayWrapper.epollWait`，即**事件循环空转等待**，也属正常。
4. **健康检查请求活跃，但非瓶颈。** 多条线程正处在 Spring Boot Actuator `/actuator/health` 的调用栈（`HealthEndpoint -> DispatcherServlet -> ...`），说明抓 dump 当时存在探针访问，不是“系统卡死”。
5. **疑似“定时线程池被反复创建”的风险。** 注意到线程名如 `passwordStrategy-scheduled-thread-pool-24011/24012/...`，**编号非常大**（2.4万量级的后缀），常见于**重复 newScheduledThreadPool 未复用/未 shutdown** 的代码路径；这些线程都在 `ThreadPoolExecutor.getTask` 上等待任务，看似“无害”，但会**长期占用线程/栈内存**并增加上下文切换成本，建议重点自查相关 Bean/单例。

------

# 关键证据（各类线程形态 ➜ 你系统当下在忙/在等什么）

- **Tomcat 工作线程空闲等待任务**
   典型栈：`LinkedBlockingQueue.take -> TaskQueue.take -> ThreadPoolExecutor.getTask`，状态 `WAITING (parking)`，如 `http-nio-8888-exec-790/788/785/...` 等大量线程均如此——说明线程池**并未被任务“打满”**。
- **RabbitMQ**
   典型栈：`SocketInputStream.socketRead0 -> ... -> AMQConnection$MainLoop.run`，状态 `RUNNABLE`（I/O 等待/收包），属**健康连接**。两份日志均有：docker08、docker07。
   另有消费者线程在 `BlockingQueueConsumer.nextMessage` 上等消息，表示**当时队列不忙**。
- **Redis（lettuce）**
   典型栈：`EPollArrayWrapper.epollWait -> NioEventLoop.run`，**事件循环正常**。
- **Actuator 健康检查**
   典型栈：`HealthEndpoint -> DispatcherServlet.doDispatch -> ...`，说明**频繁健康探针**在访问，但这类线程并未卡在下游。

> 小结：这两份 dump 展示的是“**整体空闲**”的瞬时画面：容器线程、业务线程都在等待队列/事件；并无“谁把大家都卡住”的直接证据。

------

# 这两份 jstack 能告诉我们的 & 不能告诉我们的

- ✅ 能确认：**无死锁/无明显锁膨胀**、**线程池配置很大**、**Rabbit/Redis 连接正常**、**健康检查在跑**、**可能存在定时线程池重复创建**。
- ❌ 不能确认：**是否发生过长时间 STW GC**、**个别请求为何在某时段变慢**、**数据库/三方调用是否偶发超时**。这些要结合 GC/jstat、访问日志与下游端到端时序才能锚定。

------

# 接下来如何“定位问题”（实操清单）

> 目标：当“变慢/超时”再现时，第一时间把“忙的线程在忙什么”与“卡的线程卡在哪里”定格下来，用证据说话。

1. **连拍 3 份线程栈（间隔 5s）**

   ```
   jstack -l <pid> > jstack_$(date +%F_%T).log
   # 重复三次
   ```

   - 连续三份里**同一批 RUNNABLE** 若始终停在同一栈顶（如 `JDBC 执行/HTTP 调用`），多半是**下游慢**；若大量 `BLOCKED`，再看**持锁线程**是谁（需 `-l` / 或用 `jcmd <pid> Thread.print -l`）。

2. **把“高 CPU 的线程”对上 jstack 的 nid**

   ```
   top -H -p <pid>        # 找到占 CPU 的线程，记十进制 TID
   printf "0x%x\n" <tid>  # 转 16 进制，对上 jstack 里的 nid=0x...
   ```

   - 若 CPU 忙而 jstack 显示 Java 空闲，可能是**JNI/加解密/压缩**等 native hotspot。

3. **同时抓 GC 侧证据**

   - 开 GC 日志：`-Xlog:gc*:file=/path/gc.log:time,uptime,level,tags`（JDK8: `-XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/path/gc.log`）。
   - 观察是否存在**长时间 Full GC / 元空间膨胀**；配合你前面 `jstat` 结果联动判断。

4. **快速“量化”线程状态分布**（离线）

   ```
   grep -c "java.lang.Thread.State: RUNNABLE" jstack.log
   grep -c "java.lang.Thread.State: WAITING"   jstack.log
   grep -c "java.lang.Thread.State: TIMED_WAITING" jstack.log
   grep -n "BLOCKED" jstack.log
   ```

5. **排查“定时线程池泄漏”**（重点）

   - 用 `grep -n "passwordStrategy-scheduled-thread-pool"` 看数量是否很多、编号是否持续增大；此命名在 dump 中后缀已达 **2401x**（示例条目），高度可疑。请检查是否在业务流程中**反复 newScheduledThreadPool / new Timer** 而非复用单例，并确保在 Bean 销毁时 `shutdown()`。

6. **收敛 Tomcat 线程池规模**

   - 目前可见 **上百条** `http-nio-8888-exec-*` 空闲线程（示例：`exec-790/788/785/...`），过大的 `maxThreads` 带来**线程调度开销与内存占用**，建议按 QPS/RT 调整到合理区间（常见 200–400），配合连接池、异步/响应式等手段扩容。

7. **把“健康检查”降成本**

   - 频繁 `/actuator/health` 出现在栈里，建议健康探针改为**轻量级**（只做本地检查，必要时用 `management.endpoint.health.probes.enabled=true` 并关闭昂贵的外部依赖指示器），或降低探针频率。

------

# 针对两份 dump 的“逐条点评”

- **docker08**
  - `http-nio-8888-exec-*` 大量 `WAITING` on `TaskQueue.take`（线程池空闲）。
  - `lettuce-nioEventLoop` 在 `epollWait`（Redis 客户端正常）。
  - 多个 `passwordStrategy-scheduled-thread-pool-24xxx` 等待任务，**编号异常大**，需排查创建/销毁。
  - Actuator 健康检查正在执行。
  - RabbitMQ 连接线程 I/O 等待正常。
- **docker07**
  - RabbitMQ 消费端：连接线程收包正常、消费者线程在 `BlockingQueueConsumer.nextMessage` 等消息（队列当时不忙）。
  - 同样未见 `BLOCKED`/死锁痕迹；整体偏“空闲等待”。

------

如果你的**线上症状是“偶发卡顿/RT 抖动”**，而我们抓到的这两份 jstack 都是“空闲态”，那更需要按上面“连拍 3 份 + GC 日志 + top -H 对齐”的流程，在**问题发生当时**再取证；结合访问日志/调用链，基本就能把问题锚定在**GC、下游 I/O、线程泄漏/过量**或**个别热点方法**之一。

------------------

--------------------

收到。这次我把你提供的三台 Pod 的 jstat 截图做了“横向对比”，并**重点**对两份已上传的 jstack（docker08、docker07）做**逐条证据+定位建议**。如果你也想看第三份（docker09），把 `/tmp/jstack-docker09.log` 一并上传即可。

------

# 先看 jstat：三台实例的“内存/G C 体感”

- **docker08（pid 3730591）**
   `FGC=4418，FGCT≈53871s，GCT≈54709s`，历史上**Full GC 非常多且耗时巨大**；当前采样 5 次各列**不变**（说明这 5 秒里没有新的 GC 发生），但**Old≈66.6%**、**Eden≈85%**、**Metaspace≈76.6%**。→ **这台历史上一定有过严重的停顿风险**（FGC 这么高几乎铁证）。
- **docker07（pid 372938）**
   `FGC=0，YGC=2939、YGCT≈135s`，Old≈51.8%，**Metaspace≈88.6%（很高）**，Eden 27%→53% 缓慢上涨。→ **没看到 Full GC，但元空间逼近红线**。
- **docker09（pid 454652）**
   `FGC=0，YGC=237、YGCT≈8.6s`，Old≈26%，**Metaspace≈92.2%（更高）**。→ **元空间最紧**，但暂未触发 FGC。

> 粗判：**docker08** 的主要“慢/抖”嫌疑来自**历史 Full GC**；**docker07、docker09** 的风险主要在**Metaspace 高水位**（可能后续触发 Meta 驱动的并发周期或 Full GC）。

------

# 两份 jstack “看图说话”（docker08 & docker07）

## A. docker08：线程总体**空闲**，存在“疑似定时线程池反复创建”的强信号

1. **健康检查在跑**
    多条栈从 `HealthEndpoint` → SpringMVC → 过滤器链 → Tomcat，说明采样当时有 `/actuator/health` 请求；可作为“服务仍在处理请求”的旁证。
2. **Tomcat 工作线程大多在等活（线程池空闲）**
    典型：`http-nio-8888-exec-790` 等许多线程停在 `LinkedBlockingQueue.take -> TaskQueue.take -> ThreadPoolExecutor.getTask`，状态 `WAITING`。这意味着**此刻不是“线程都被任务打满”**。
3. **Redis（lettuce）I/O 事件循环健康**
    线程在 `EPollArrayWrapper.epollWait -> NioEventLoop.run`，属正常事件轮询。
4. **RabbitMQ 连接线程健康**
    `AMQConnection$MainLoop` 在 `SocketInputStream.socketRead0` 上 `RUNNABLE`（I/O 等待/收包）。
5. **强可疑：定时线程池“编号巨大”**
    看到多条名为 `passwordStrategy-scheduled-thread-pool-2401x` 的线程（后缀**2.4 万级**），都停在 `ScheduledThreadPoolExecutor$DelayedWorkQueue.take / getTask`，这很像**重复 newScheduledThreadPool 而未复用/未 shutdown** 导致**线程泄漏**（逻辑上“无害等待”，但会吃线程/栈、增加上下文切换，极端时影响可用性）。

> 小结（docker08）：**当下**并不是业务线程“被卡死”，而是**历史 Full GC 非常多**；另有**定时线程池疑似反复创建**的问题值得优先修。

------

## B. docker07：也呈“空闲态”，Rabbit/Redis 正常，能见到数据源后台线程

1. **RabbitMQ**
    和 docker08 一样，连接线程在 `socketRead0`，消费者线程在 `BlockingQueueConsumer.nextMessage` 等待下一条消息——**队列当时不忙**。
2. **Redis（lettuce）事件循环健康**
    线程在 `epollWait`/`NioEventLoop.run` 或事件执行器队列上等待，属正常。
3. **Druid 数据源维护线程**
    可见 `Druid-ConnectionPool-Create/Destroy` 后台线程在 `sleep/await`；说明数据源层面没有“建连风暴”。
4. **自建线程池线程在等任务**
    多个 `pool-4-thread-*` 停在 `LinkedBlockingQueue.take -> getTask`，同样是**空闲**姿态。

> 小结（docker07）：线程侧没有拥塞/死锁信号；配合 jstat，这台应关注**Metaspace 高水位**引发的**后续 GC 风险**。

------

# 怎么从“现象”定位到“根因”（一套落地打法）

> 你的两份 jstack 都是“系统很闲”的瞬时快照，所以**不是**用它们去解释“已发生的卡顿”，而是用它们**排除**“卡在锁/卡在线程池”的可能性，并把注意力转向 **GC/元空间/线程泄漏/下游 I/O** 等更可能的方向。

### 1) 对 docker08：先把“为什么 Full GC 如此之多”查清

- **马上取 GC 原因**（轻量）：
   `jstat -gccause <pid> 1000 5` —— 看 `Cause/LastCause` 是否出现 `Metadata GC Threshold`、`To-space exhausted`、`Allocation Failure` 等。
- **取堆&区域快照（在线轻量）**：
   `jcmd <pid> GC.heap_info`，确认 GC 算法（G1/Parallel）、各区水位、IHOP（如果是 G1）。
- **开 GC 日志（若还没开）**：
  - JDK 8：`-XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/path/gc.log`
  - JDK 9+：`-Xlog:gc*,safepoint:file=/path/gc.log:utctime,tid,level`
     用它去核对**Full GC 的触发原因/暂停时长/发生时间**与业务抖动是否一致。
- **如果是 Metaspace 触发**：
  - 结合 `jcmd <pid> VM.flags` 看 `MaxMetaspaceSize` 是否太小；
  - 抓 `jcmd <pid> GC.class_histogram` 看是否有**动态代理类/热生成类**堆积（Spring CGLIB、Lambda、JSP、字节码框架等）。
- **如果是 G1 复制失败/晋升失败**（`To-space exhausted`/`promotion failure`）：
  - 考虑增大 `G1ReservePercent`（默认10）与 `-XX:InitiatingHeapOccupancyPercent` 的配比；
  - 同时排查大对象/短命巨对象的分配热点（JFR/async-profiler alloc 模式）。

### 2) 修“定时线程池疑似泄漏”（docker08 的强信号）

- 你有一堆 `passwordStrategy-scheduled-thread-pool-2401x` 线程常驻在 `getTask`，编号极大 → **几乎可以判**是**反复 newScheduledThreadPool** 或重复 `new Timer`。
- 处置：
  - 保证只在**单例 Bean**中创建 `ScheduledExecutorService`，全局复用；
  - 组件销毁时 `shutdown()`；
  - Spring 环境优先使用 `@EnableScheduling + TaskScheduler`（由容器托管生命周期）。

### 3) 对 docker07 / docker09：盯紧 Metaspace

- 两台的 `M` 都在 **88–92%** 高位（docker09 更危险）。
- 建议：
  - `jcmd <pid> VM.flags`/`VM.system_properties` 确认 `MaxMetaspaceSize`；
  - `jcmd <pid> GC.class_histogram` 看是否出现**大量代理类/动态生成类**；
  - 必要时**临时调高 MaxMetaspaceSize**（同时评估容器内存限制），并**定位类加载器泄漏**（WebAppClassLoader、热加载、反复注册的代理/拦截器等）。

### 4) 当“卡顿再现”时，三件事同时做（证据闭环）

1. **连拍 3 份线程栈（间隔 3–5s）**：`jcmd <pid> Thread.print -l`
   - 如果同一批 `RUNNABLE` 一直停在 JDBC/HTTP 调用栈顶 → **下游慢**；
   - 如果大量 `BLOCKED` → 看持锁线程的栈定位热点锁。
2. **top -H 对齐 nid**：找到高 CPU 的 TID，转 16 进制对上 jstack 的 `nid=0x...`，看它在忙什么。
3. **看 GC 日志**：是否此刻恰好 Full GC/STW？

------

# 具体“改/查”的优先级（给排期）

1. **docker08：甩锅点=历史 FGC 很多**
   - 立刻打开/收集 GC 日志，凭“时间戳”比对业务告警；
   - `jstat -gccause` + `jcmd GC.heap_info` 定因；
   - 修复**定时线程池**创建问题（这条通常简单+收益大）。
2. **docker09 / docker07：压住 Metaspace 风险**
   - 先把 `MaxMetaspaceSize` 调到不至于“误伤”的水平（同时观察容器 RSS）；
   - 走 `class_histogram` 找“谁在生成类”；必要时代码治理。
3. **Tomcat 线程池收敛**（三台都有很多空闲 `http-nio-8888-exec-*`）
   - 按 QPS/RT 调到合理的 `maxThreads`（过大只会增加线程/栈内存和调度成本）。
4. **健康检查降成本**
   - `/actuator/health` 明显出现于多条栈；建议启用轻量探针或减少频率，避免把外部依赖也纳入每次检测。

------

如果你把 **docker09** 的 jstack 也上传，我会把三台的线程形态对齐成表格，再结合你们的 RT/错误峰值时间轴，给一版“现网排障 Runbook（含阈值 & 处置动作）”。