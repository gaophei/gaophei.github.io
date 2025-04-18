好的，除了 Swingbench，您可以使用其他多种工具或方法来测试 Oracle 19c RAC 三节点集群的故障转移功能。以下是一些替代方案及其详细步骤和参数，您可以根据您的测试环境进行调整后使用。

**核心概念：**

故障转移测试的目标是验证当 RAC 集群中的一个节点（及其上的实例）发生故障时：

1. **连接保持 (Connection Retention):** 现有连接是否能够（根据配置）自动或在短暂中断后重新连接到幸存的节点上。这通常依赖于透明应用程序故障转移 (TAF) 或应用程序连续性 (AC) 的配置。
2. **新连接 (New Connections):** 新的连接请求是否能够成功路由到幸存节点上的实例。这依赖于 SCAN Listener 和服务 (Services) 的正确配置。
3. **负载分发 (Load Distribution):** 负载是否在幸存的节点之间重新分配。
4. **服务重定位 (Service Relocation):** 如果服务配置为只在特定节点运行（非 `UNIFORM`），故障转移后服务是否会迁移到其配置的备用节点。

**测试前的关键准备工作 (Prerequisites):**

1. RAC 集群健康:

    确保您的三节点 RAC 集群状态正常，所有节点、实例、监听器（尤其是 SCAN Listener）都在运行。

   Bash

   ```
   crsctl stat res -t
   lsnrctl status LISTENER_SCAN1 # (以及 SCAN2, SCAN3)
   lsnrctl status LISTENER       # (每个节点上的本地监听器)
   srvctl status database -d <your_db_name>
   srvctl status service -d <your_db_name>
   ```

2. 创建测试服务 (Test Service):

    创建一个专门用于测试的数据库服务。配置该服务以支持故障转移（TAF 或 AC）。建议使用 

   ```
   UNIFORM
   ```

    策略以便服务在所有可用实例上运行，或者明确指定首选和可用实例。

   - 示例（TAF - BASIC 方法）:

     Bash

     ```
     srvctl add service -db <your_db_name> -service test_failover_svc \
            -preferred <instance1_name>,<instance2_name>,<instance3_name> \
            -available <instance1_name>,<instance2_name>,<instance3_name> \
            -role PRIMARY \
            -policy AUTOMATIC \
            -failovertype SESSION \
            -failovermethod BASIC \
            -failoverretry 30 \
            -failoverdelay 5 \
            -clbgoal LONG \
            -rlbgoal SERVICE_TIME
     srvctl start service -db <your_db_name> -service test_failover_svc
     ```

   - **检查服务状态:** `srvctl config service -d <your_db_name> -s test_failover_svc`

3. 客户端配置 (Client Configuration):

    确保用于连接的客户端（无论是脚本、工具还是 SQL*Plus）使用了支持故障转移的连接字符串或 TNSNAMES.ORA 条目。

   - **使用 SCAN 地址和 Service Name:** 这是推荐的方式。

   - TNSNAMES.ORA 示例 (支持 TAF):

     Code snippet

     ```
     TEST_FAILOVER =
       (DESCRIPTION =
         (CONNECT_TIMEOUT=10)(RETRY_COUNT=3)
         (ADDRESS_LIST =
           (LOAD_BALANCE=on)
           (FAILOVER=on)
           (ADDRESS = (PROTOCOL = TCP)(HOST = <your_scan_address>)(PORT = <your_scan_port>))
         )
         (CONNECT_DATA =
           (SERVICE_NAME = test_failover_svc)
           (FAILOVER_MODE =
              (TYPE = SESSION)  # 或 TRANSACTION
              (METHOD = BASIC)
              (RETRIES = 30)
              (DELAY = 5)
           )
         )
       )
     ```

4. 测试用户和表 (Test User and Table):

    创建一个测试用户，并创建一个简单的表用于 DML 操作。

   SQL

   ```
   CREATE USER testuser IDENTIFIED BY <password>;
   GRANT CONNECT, RESOURCE TO testuser;
   ALTER USER testuser QUOTA UNLIMITED ON <your_tablespace>;
   CREATE TABLE testuser.failover_test (id NUMBER PRIMARY KEY, data VARCHAR2(100), inst_id NUMBER, ts TIMESTAMP);
   ```

**替代工具和测试步骤：**

------

### 方法一：使用自定义脚本 (例如 Shell + SQL*Plus)

这种方法最直接，不需要额外安装复杂的工具，但模拟的负载可能不如专用工具真实。

**步骤：**

1. 创建 SQL 脚本 (`workload.sql`):

    这个脚本将执行一些简单的 DML 和查询，并记录当前的实例 ID。

   SQL

   ```
   -- workload.sql
   SET ECHO OFF
   SET FEEDBACK OFF
   SET VERIFY OFF
   WHENEVER SQLERROR EXIT SQL.SQLCODE;
   
   DECLARE
     v_inst_id NUMBER;
     v_count NUMBER;
   BEGIN
     SELECT instance_number INTO v_inst_id FROM v$instance;
   
     -- 简单的插入操作
     INSERT INTO testuser.failover_test (id, data, inst_id, ts)
     VALUES (ROUND(DBMS_RANDOM.VALUE(1,1000000)), 'Test Data - Instance ' || v_inst_id, v_inst_id, SYSTIMESTAMP);
     COMMIT;
   
     -- 简单的查询操作 (模拟读)
     SELECT COUNT(*) INTO v_count FROM testuser.failover_test WHERE ROWNUM <= 100;
     DBMS_OUTPUT.PUT_LINE('Instance: ' || v_inst_id || ', Timestamp: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF') || ', Query Count: ' || v_count);
   
     -- 稍微等待一下模拟思考时间
     DBMS_LOCK.SLEEP(1); -- 等待 1 秒
   
   EXCEPTION
     WHEN OTHERS THEN
       -- 记录错误但不退出，以便脚本可以尝试重连（如果 TAF 配置）
       DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
       -- 可能需要回滚未提交的事务
       ROLLBACK;
       -- 强制稍等，避免快速连续失败
        DBMS_LOCK.SLEEP(5);
   END;
   /
   
   EXIT;
   ```

2. 创建 Shell 脚本 (`run_test.sh`):

    这个脚本会循环调用 SQL*Plus 来执行 

   ```
   workload.sql
   ```

   。

   Bash

   ```
   #!/bin/bash
   
   # -- 参数 --
   TNS_ALIAS="TEST_FAILOVER" # TNSNAMES.ORA 中的条目，指向 SCAN 和测试服务
   USERNAME="testuser"
   PASSWORD="<password>"
   DURATION_MINUTES=10 # 测试运行总时长（分钟）
   # ----------
   
   END_TIME=$((SECONDS + DURATION_MINUTES * 60))
   LOG_FILE="failover_test_$(date +%Y%m%d_%H%M%S).log"
   
   echo "Starting test at $(date)" | tee -a $LOG_FILE
   echo "Connecting using TNS Alias: $TNS_ALIAS" | tee -a $LOG_FILE
   echo "Test duration: $DURATION_MINUTES minutes" | tee -a $LOG_FILE
   
   while [ $SECONDS -lt $END_TIME ]; do
     echo "Executing workload at $(date)..." >> $LOG_FILE
     # 使用 TAF 配置的 TNS Alias
     sqlplus -S -L ${USERNAME}/${PASSWORD}@${TNS_ALIAS} @workload.sql >> $LOG_FILE 2>&1
     SQL_EXIT_CODE=$?
   
     if [ $SQL_EXIT_CODE -ne 0 ]; then
         echo "$(date): SQL*Plus exited with error code $SQL_EXIT_CODE. Possible connection issue or SQL error." | tee -a $LOG_FILE
         # 在出现连接错误时稍作等待，让 TAF 有机会工作或重试
         sleep 5
     fi
   
     # 可以根据需要调整这里的 sleep 时间，控制执行频率
     # sleep 0.1 # 短暂间隔
   done
   
   echo "Test finished at $(date)" | tee -a $LOG_FILE
   ```

3. 运行测试:

   - 确保 `tnsnames.ora` 在运行脚本的机器上配置正确，或者直接在脚本中使用完整的 Easy Connect 字符串 (如果支持 TAF)。

   - 赋予 Shell 脚本执行权限: `chmod +x run_test.sh`

   - 后台运行多个脚本实例来模拟并发用户:

     Bash

     ```
     nohup ./run_test.sh &> run1.out &
     nohup ./run_test.sh &> run2.out &
     nohup ./run_test.sh &> run3.out &
     # ... 可以启动更多实例
     ```

4. 模拟节点故障:

    在测试运行期间（例如，运行几分钟后），选择一个节点（假设是 node3，实例名为 

   ```
   <your_db_name>3
   ```

   ）并强制停止其实例。

   - 推荐方式 (模拟实例崩溃):

     Bash

     ```
     srvctl stop instance -d <your_db_name> -i <instance_name_on_node_to_fail> -o immediate -f
     # 例如: srvctl stop instance -d orclcdb -i orclcdb3 -o immediate -f
     ```

   - **或者 (模拟节点宕机 - 需要访问操作系统):** 在目标节点上执行 `shutdown -h now` 或 `reboot -f` (这更剧烈，测试网络层面的故障转移)。

   - **或者 (模拟进程崩溃 - 不推荐用于常规测试，但可模拟特定场景):** `kill -9 <pmon_pid>`

5. 观察:

   - **脚本日志 (`runX.out`, `failover_test_\*.log`):** 观察是否有连接错误、ORA-错误（如 ORA-3113, ORA-125xx），以及脚本是否在短暂中断后继续执行。查看 `workload.sql` 输出的 `Instance: X` 是否在故障后不再显示失败节点的实例 ID。

   - **数据库 Alert Log:** 在幸存节点上检查 Alert Log，看是否有关于实例故障、服务重定位、TAF/FAN 事件的记录。

   - **监听器日志 (SCAN & Local):** 检查是否有连接重定向的记录。

   - 活动会话:

      在幸存节点上查询 

     ```
     GV$SESSION
     ```

     ，看连接是否已迁移过来。

     SQL

     ```
     SELECT inst_id, sid, serial#, username, status, sql_id, event, service_name
     FROM gv$session
     WHERE username = 'TESTUSER' AND service_name = 'test_failover_svc';
     ```

6. 恢复节点:

    测试完成后，重新启动之前停止的实例或节点。

   Bash

   ```
   srvctl start instance -d <your_db_name> -i <instance_name_on_failed_node>
   # 或者如果关闭了节点，则启动节点并等待 CRS 自动启动实例
   ```

7. **清理:** 删除测试表和用户（如果需要）。

------

### 方法二：使用 Apache JMeter

JMeter 是一个流行的开源负载测试工具，可以通过 JDBC 连接数据库。

**步骤：**

1. **安装 JMeter:** 从 Apache JMeter 官网下载并安装。需要 Java 环境。

2. **获取 Oracle JDBC Driver:** 下载适合您数据库版本的 `ojdbcX.jar` 文件（例如 `ojdbc8.jar` 或 `ojdbc11.jar`）。将其放入 JMeter 的 `lib` 目录下。

3. 创建 JMeter 测试计划:

   - 启动 JMeter GUI (`jmeter.bat` 或 `jmeter.sh`)。

   - 右键点击 "Test Plan" -> "Add" -> "Threads (Users)" -> "Thread Group"。

     - **Number of Threads (users):** 设置并发用户数（例如 10）。
     - **Ramp-up period (seconds):** 用户启动所需时间（例如 5 秒）。
     - **Loop Count:** 设置为 "Forever" 或一个很大的数字，或者选中 "Scheduler" 并设置持续时间。

   - 右键点击 "Thread Group" -> "Add" -> "Config Element" -> "JDBC Connection Configuration"。

     - **Variable Name for created pool:** `oraclePool` (任意名称)
     - **Database URL:** `jdbc:oracle:thin:@//<your_scan_address>:<your_scan_port>/test_failover_svc` (确保使用 SCAN 地址和配置了 TAF/AC 的服务名)
     - **JDBC Driver class:** `oracle.jdbc.driver.OracleDriver`
     - **Username:** `testuser`
     - **Password:** `<password>`
     - **Validation Query:** `select 1 from dual`
     - 根据需要调整其他连接池设置（Max Number of Connections 等）。

   - 右键点击 "Thread Group" -> "Add" -> "Sampler" -> "JDBC Request"。

     - **Variable Name of Pool declared in JDBC Connection Configuration:** `oraclePool` (与上面配置的名称一致)

     - **Query Type:** `Select Statement` 或 `Update Statement` 等。

     - SQL Query:

       SQL

       ```
       -- 可以放类似 workload.sql 中的逻辑，但 JMeter 通常放单条语句
       -- 示例查询:
       SELECT instance_number FROM v$instance;
       -- 示例 DML (确保有提交逻辑或自动提交):
       -- INSERT INTO testuser.failover_test (id, data, inst_id, ts) VALUES (ROUND(DBMS_RANDOM.VALUE(1,1000000)), 'JMeter Test', (SELECT instance_number FROM v$instance), SYSTIMESTAMP)
       ```

       注意: 如果执行 DML，确保 JDBC 连接配置或 JDBC Request 中处理了事务提交（默认可能是 AutoCommit，或者使用多条语句并包含 COMMIT）。

   - 右键点击 "Thread Group" -> "Add" -> "Timer" -> "Constant Timer" (或其他 Timer)。

     - **Thread Delay (milliseconds):** 添加思考时间，例如 `1000` (1 秒)。

   - 右键点击 "Test Plan" or "Thread Group" -> "Add" -> "Listener" -> "View Results Tree" 和 "Summary Report"。

4. **运行测试:** 点击 JMeter 工具栏上的绿色启动按钮。

5. **模拟节点故障:** 同方法一的步骤 4。

6. 观察:

   - JMeter Listeners:
     - **View Results Tree:** 查看每个请求的成功/失败状态。在故障期间和之后，可能会看到一些失败的请求（取决于 TAF 生效速度和 JMeter 超时设置），但之后应该会恢复正常，并且可能连接到不同的实例。
     - **Summary Report:** 观察吞吐量 (Throughput) 和错误率 (% Error)。故障期间吞吐量会下降，错误率可能上升，之后应恢复。
   - **数据库端:** 同方法一的步骤 5（Alert Log, `GV$SESSION` 等）。

7. **恢复节点:** 同方法一的步骤 6。

8. **停止 JMeter 测试:** 点击工具栏上的停止按钮。

9. **清理:** 同方法一的步骤 7。

------

### 方法三：使用 HammerDB

HammerDB 是一个流行的开源数据库负载测试和基准测试工具，支持 Oracle。

**步骤:**

1. **安装 HammerDB:** 从 HammerDB 官网下载并安装。
2. 配置 Oracle 连接:
   - 启动 HammerDB。
   - 在左侧选择 "Oracle"。
   - 双击 "Schema Build" -> "Options"。
     - **Oracle Service Name:** 输入您的 SCAN 地址、端口和测试服务名，格式如：`//<your_scan_address>:<your_scan_port>/test_failover_svc`。
     - **Oracle User:** `SYSTEM` 或其他有权限创建用户的用户。
     - **Oracle Password:** 对应用户的密码。
     - **User for Schema Build:** `tpcc_user` (或自定义)。
     - **Password for User:** `<password>`。
     - **Number of Warehouses:** 设置一个较小的值用于测试，例如 5 或 10。
     - **Build Options:** 选择 "Use Oracle Defaults for Tablespaces"。
   - 双击 "Driver Script" -> "Options"。
     - 确认 "Oracle Service Name" 与上面一致。
     - **Oracle User:** `tpcc_user` (或您创建的 Schema 用户)。
     - **Password for User:** 对应的密码。
     - **Timed Driver Script:** 选中此项。
     - **Minutes to run test:** 设置测试时长，例如 10 分钟。
     - **Rampup Time in minutes:** 设置预热时间，例如 1 分钟。
3. 构建测试 Schema (如果首次使用):
   - 在 "Schema Build" 下，双击 "Build" 脚本。点击工具栏上的红色 "X" (Destroy Schema) 清理旧的（如果存在），然后点击绿色箭头 (Create Schema)。观察输出窗口直到完成。
4. 加载并运行 Driver Script:
   - 在 "Driver Script" 下，双击 "Load" 脚本。
   - 在 "Virtual Users" 下，双击 "Options"。
     - **Virtual Users to Create:** 设置并发用户数，例如 10 或 20。
   - 双击 "Create" 来创建虚拟用户。
   - 双击 "Run" (或者点击工具栏上的绿色箭头) 来开始测试。
5. **模拟节点故障:** 同方法一的步骤 4。
6. 观察:
   - **HammerDB 主窗口:** 观察 "Transactions Per Minute (TPM)" 图表。在故障期间，TPM 应该会显著下降，然后可能会恢复到一个较低的水平（因为少了一个节点处理负载）。错误计数器可能会增加。
   - **HammerDB Transaction Counter 窗口:** 查看每个虚拟用户的状态和错误。
   - **数据库端:** 同方法一的步骤 5（Alert Log, `GV$SESSION`, AWR/ASH 报告）。
7. **恢复节点:** 同方法一的步骤 6。
8. **停止 HammerDB 测试:** 当达到设定的测试时间或手动点击工具栏上的红色方块停止按钮。
9. **清理:** 可以使用 HammerDB 的 "Destroy Schema" 功能清理 TPC-C 表和用户。

------

**重要注意事项:**

- **TAF vs AC:** TAF (Transparent Application Failover) 主要用于恢复会话和进行中的 `SELECT` 语句。应用程序连续性 (Application Continuity) 是更高级的功能，能更好地屏蔽故障，甚至能重放进行中的事务（需额外配置）。确保您的服务和连接字符串与您想测试的功能匹配。
- **故障模拟方式:** `srvctl stop instance -f` 是最标准的模拟实例失败的方式。模拟网络故障（拔网线、防火墙规则）或存储故障（断开共享存储连接）可以测试更复杂的场景。模拟整个节点宕机（OS Shutdown/Crash）则测试整个节点的恢复和实例的自动启动。
- **监控:** 在测试期间，使用 Enterprise Manager (如果可用)、`GV$` 视图 (如 `GV$SESSION`, `GV$SESSION_WAIT`, `GV$SERVICE_EVENT`)、AWR/ASH 报告以及 Alert Log 和监听器日志来全面了解系统行为。
- **应用程序影响:** 最真实的测试是使用您的实际应用程序或其负载模拟器。如果上述通用工具的测试结果良好，最终还需验证您的应用程序在故障转移场景下的实际表现，因为应用程序自身的连接池、错误处理和重试逻辑也非常关键。

选择哪种方法取决于您的熟悉程度、环境限制以及您希望模拟的负载复杂度。对于基本的故障转移验证，自定义脚本或 JMeter 通常足够。HammerDB 则更侧重于标准的基准负载。