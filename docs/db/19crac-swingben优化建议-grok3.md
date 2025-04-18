分析 Oracle 19c RAC 三节点集群的 Swingbench 压测结果，结合提供的 AWR 报告（集群报告和节点 3 的单实例报告），可以识别出性能瓶颈并提出具体的优化建议。以下是详细分析和建议：

---

### **1. 总体性能瓶颈分析**

#### **1.1 主要问题：高延迟的 "Commit" 和 "Cluster" 等待**
- **问题描述**：
  - AWR 集群报告显示，`Commits and Rollbacks` 占用了 47.11% 的总活动会话时间（396.83 个活跃会话），`Cluster` 等待占用了 47.27%（398.13 个活跃会话）。
  - 节点 3 的单实例报告显示，`Commit` 等待占用了 47.94%（135.9 个活跃会话），`Cluster` 等待占用了 48.23%（137.0 个活跃会话）。
  - 具体事件：
    - **`log file sync`** 是 `Commit` 等待的主要事件，集群范围内总等待时间为 7.8M 秒（节点 3），平均等待时间为 1343.98ms，占用了 47.9% 的 DB time。
    - **`gc cr block busy`** 和 **`gc buffer busy acquire`** 是 `Cluster` 等待的主要事件，分别占用了 21.5% 和 12.4% 的 DB time（节点 3）。
  - 这些高延迟表明：
    1. 提交操作（`log file sync`）耗时严重，可能与日志文件 I/O 或日志切换相关。
    2. 集群间通信（`Global Cache`）存在瓶颈，导致跨节点块传输和一致性读的延迟。

#### **1.2 问题：Buffer Busy - Hot Objects**
- **问题描述**：
  - 集群报告中，`Buffer Busy - Hot Objects` 占用了 46.79% 的活动会话（394.16 个活跃会话）。
  - 节点 3 报告显示，`Buffer Busy - Hot Objects` 占用了 49.15%（139.32 个活跃会话）。
  - ADDM 报告指出，主要受影响的表包括：
    - `SOE01.ORDERS`（对象 ID 73335）
    - `SOE01.LOGON`（对象 ID 73338）
    - `SOE01.CUSTOMERS`（对象 ID 73330）
  - 这些表上的并发 DML 操作导致了块争用，特别是在 `INVENTORIES` 和 `ORDERS` 表上。

#### **1.3 问题：Top SQL Statements 性能问题**
- **问题描述**：
  - 集群报告显示，`Top SQL Statements` 占用了 39.38% 的活动会话（331.74 个活跃会话）。
  - 节点 3 报告显示，`Top SQL Statements` 占用了 37.72%（106.93 个活跃会话）。
  - 主要的 SQL 包括：
    - **SQL ID: c13sma6rkr27c**（SELECT 从 `PRODUCTS` 和 `INVENTORIES` 表）
      - 执行了 115,546,476 次，平均耗时 0.075 秒，占用了大量的 CPU、I/O 和 Cluster 等待。
    - **SQL ID: 3fw75k1snsddx**（INSERT 插入 `ORDERS` 表）
      - 执行了 8,428,803 次，平均耗时 0.37 秒，主要消耗在 CPU、I/O 和 Cluster 等待。
    - **SQL ID: 0y1prvxqc2ra9**（SELECT 从 `PRODUCTS` 和 `INVENTORIES` 表）
      - 执行了 144,378,772 次，平均耗时 0.022 秒，同样消耗在 CPU、I/O 和 Cluster 等待。

#### **1.4 问题：Global Cache Messaging 和 Global Cache Busy**
- **问题描述**：
  - 集群报告中，`Global Cache Messaging` 占用了 43.89%（369.73 个活跃会话），`Global Cache Busy` 占用了 35.63%（300.15 个活跃会话）。
  - 节点 3 报告显示，`Global Cache Messaging` 占用了 45.42%（128.76 个活跃会话），`Global Cache Busy` 占用了 38.85%（110.13 个活跃会话）。
  - 这些问题表明 RAC 集群中的跨节点通信存在瓶颈，尤其是在块传输和一致性读方面。

#### **1.5 问题：I/O 性能问题**
- **问题描述**：
  - 集群报告和节点 3 报告显示，`User I/O` 等待占用了 2.32% 的总 DB time（集群）和 0.83%（节点 3）。
  - 具体事件 `db file sequential read` 在节点 3 上占用了 0.8% 的 DB time，总等待时间为 131.2K 秒，平均等待时间为 310.23ms。
  - 虽然 I/O 问题不是主要瓶颈，但仍对性能有一定影响。

---

### **2. 具体优化建议**

#### **2.1 优化 "Commits and Rollbacks" 和 "log file sync" 问题**
1. **检查日志文件 I/O 性能**：
   - `log file sync` 的高延迟（平均 1343.98ms）表明日志文件写入可能存在瓶颈。
   - **建议**：
     - 确保 redo log 文件存储在高性能存储（如 SSD 或 NVMe）上。
     - 检查是否存在 I/O 争用，确保 redo log 文件和数据文件分离存储。
     - 增加 redo log 文件的大小，减少日志切换频率（当前未见频繁的 `log file switch` 事件，但仍需验证）。
     - 调整参数 `log_buffer`，增大日志缓冲区（当前为 33.85MB，可能不足以应对高并发写入）。
       - 建议：将 `log_buffer` 调整至 64MB 或更高，观察效果。

2. **减少不必要的提交操作**：
   - Swingbench 压测中，`Commits and Rollbacks` 占用了大量时间，可能是因为应用程序频繁提交。
   - **建议**：
     - 优化应用程序逻辑，减少不必要的 COMMIT 操作。例如，可以将多个小事务合并为一个大事务，减少 `log file sync` 的频率。
     - 检查是否存在不必要的 ROLLBACK 操作（AWR 显示每秒 7.5 次回滚），可能是应用程序设计问题。

3. **启用异步提交**：
   - 如果业务允许，可以启用异步提交（`commit_write=IMMEDIATE,NOFORCE`），减少 `log file sync` 等待。
   - **建议**：
     - 评估业务对数据一致性的要求，如果可以接受异步提交，设置 `commit_write` 参数。

#### **2.2 优化 "Cluster" 等待和 "Global Cache" 问题**
1. **优化 Global Cache 性能**：
   - `gc cr block busy` 和 `gc buffer busy acquire` 表明跨节点块传输存在争用。
   - **建议**：
     - 检查网络延迟：AWR 报告显示集群互联网络延迟在 1ms 以内，符合要求。但仍需验证是否存在网络抖动或丢包。
     - 优化表分区：ADDM 建议对 `SOE01.ORDERS` 和 `SOE01.LOGON` 表进行分区，减少跨节点争用。
       - 例如，对 `ORDERS` 表按 `WAREHOUSE_ID` 或 `CUSTOMER_ID` 进行范围分区，确保并发 DML 操作分布到不同节点。
     - 增加 `db_cache_size`：当前 DBCache 平均为 26,432MB，可能不足以缓存热点数据。建议增加至 30GB 或更高。
     - 检查 `gc`-相关参数：
       - 增大 `_gc_policy_time`（默认值为 10），减少不必要的缓存刷新。
       - 调整 `_gc_undo_retention`（默认值为 900 秒），减少全局缓存一致性检查的开销。

2. **减少热点块争用**：
   - `Global Cache Busy` 表明多个节点同时访问相同的块。
   - **建议**：
     - 使用逆向索引（Reverse Key Index）或全局哈希分区索引，减少索引块争用（例如 `CUSTOMERS_PK` 和 `ORDER_PK` 索引）。
     - 调整 `INCREMENT BY` 值：对于序列（如 `ORDERS_SEQ`），增大 `CACHE` 和 `INCREMENT BY` 值，减少跨节点序列争用。
       - 建议：设置 `ALTER SEQUENCE ORDERS_SEQ CACHE 1000 INCREMENT BY 10;`。

#### **2.3 优化 "Buffer Busy - Hot Objects" 问题**
1. **表分区**：
   - ADDM 报告明确建议对 `SOE01.ORDERS`、`SOE01.LOGON` 和 `SOE01.CUSTOMERS` 表进行分区。
   - **建议**：
     - 对 `ORDERS` 表按 `WAREHOUSE_ID` 或 `ORDER_DATE` 进行范围分区。
     - 对 `LOGON` 表按 `LOGON_DATE` 或 `CUSTOMER_ID` 进行分区。
     - 对 `CUSTOMERS` 表按 `CUSTOMER_ID` 进行范围或哈希分区。
     - 分区后，启用分区索引（Local Partitioned Index），减少全局索引争用。

2. **调整块大小**：
   - 当前数据库块大小为 8192 字节，可能导致热点块争用。
   - **建议**：
     - 考虑将热点表（如 `INVENTORIES` 和 `ORDERS`）迁移到更大的块大小表空间（如 16KB 或 32KB）。
       - 创建新表空间：`CREATE TABLESPACE swingbench_data_16k DATAFILE '+DATA' SIZE 10G BLOCKSIZE 16384;`
       - 迁移表：`ALTER TABLE SOE01.ORDERS MOVE TABLESPACE swingbench_data_16k;`

3. **优化应用程序逻辑**：
   - 热点块争用可能与应用程序的高并发 DML 操作有关。
   - **建议**：
     - 检查是否存在不必要的频繁更新或插入操作，优化业务逻辑以减少对热点表的并发访问。
     - 使用批量操作（Bulk Insert/Update），减少单条记录的 DML 频率。

#### **2.4 优化 "Top SQL Statements"**
1. **SQL ID: c13sma6rkr27c (SELECT FROM PRODUCTS, INVENTORIES)**：
   - **问题**：执行次数高达 115,546,476 次，平均耗时 0.075 秒，占用了大量的 Cluster 和 I/O 等待。
   - **建议**：
     - 运行 SQL Tuning Advisor（如 ADDM 建议）：
       ```sql
       EXEC DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => 'c13sma6rkr27c');
       EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => 'SYS_AUTO_SQL_TUNING_TASK');
       ```
     - 检查索引：确保 `PRODUCTS.CATEGORY_ID` 和 `INVENTORIES.PRODUCT_ID` 有高效索引。
       - 如果不存在，创建索引：
         ```sql
         CREATE INDEX products_category_id_idx ON PRODUCTS(CATEGORY_ID);
         CREATE INDEX inventories_product_id_idx ON INVENTORIES(PRODUCT_ID, WAREHOUSE_ID);
         ```
     - 优化查询：考虑使用分区表或物化视图，减少对 `INVENTORIES` 表的扫描。

2. **SQL ID: 3fw75k1snsddx (INSERT INTO ORDERS)**：
   - **问题**：执行 8,428,803 次，平均耗时 0.37 秒，Cluster 和 I/O 等待较高。
   - **建议**：
     - 运行 SQL Tuning Advisor。
     - 优化序列：`ORDERS_SEQ.NEXTVAL` 可能导致序列争用，增大 `CACHE` 值：
       ```sql
       ALTER SEQUENCE ORDERS_SEQ CACHE 1000;
       ```
     - 批量插入：将多次插入合并为批量操作，减少提交频率。
     - 检查索引：确保 `ORDERS` 表上的主键和外键索引高效。

3. **SQL ID: 0y1prvxqc2ra9 (SELECT FROM PRODUCTS, INVENTORIES)**：
   - **问题**：执行 144,378,772 次，平均耗时 0.022 秒，Cluster 和 I/O 等待较高。
   - **建议**：
     - 运行 SQL Tuning Advisor。
     - 优化查询：考虑使用 `INDEX` 提示或物化视图，减少扫描。
     - 确保 `PRODUCTS.PRODUCT_ID` 和 `INVENTORIES.PRODUCT_ID` 有索引。

#### **2.5 优化 I/O 性能**
1. **优化存储性能**：
   - `db file sequential read` 的平均等待时间为 310.23ms，表明单块读取性能较差。
   - **建议**：
     - 确保数据文件存储在高性能磁盘上（如 SSD）。
     - 检查是否存在 I/O 争用，确保数据文件、索引文件和 redo log 文件分布在不同的磁盘组。
     - 启用异步 I/O（`filesystemio_options=SETALL`），提高 I/O 效率。

2. **调整参数**：
   - 增大 `db_file_multiblock_read_count`，提高多块读取效率（当前未见具体值，建议设置为 128）。
   - 增大 `db_writer_processes`，提高 DBWR 进程的写入效率（建议设置为 CPU 核心数的 1/4，例如 8）。

---

### **3. 其他优化建议**

#### **3.1 调整 Swingbench 压测参数**
- 当前压测参数：
  - 用户数：1,000
  - 最小事务间隔：200ms
  - 最大事务间隔：300ms
  - 负载比例：Customer Registration (15), Update Customer Details (10), Browse Products (50), Process Orders (5), Browse Orders (5), Sales Rep Query (2)
- **建议**：
  - 降低用户数（如 500），观察是否能减少并发压力。
  - 增加事务间隔（如最小 300ms，最大 500ms），降低系统负载。
  - 调整负载比例，减少对 `ORDERS` 和 `INVENTORIES` 表的压力，例如降低 `Process Orders` 和 `Customer Registration` 的比例。

#### **3.2 监控和持续优化**
- **建议**：
  - 定期生成 AWR 报告，监控优化效果。
  - 使用 ASH（Active Session History）报告，深入分析特定时间段的等待事件。
  - 启用 SQL 跟踪，分析热点 SQL 的执行计划，查找潜在优化点。

---

### **4. 总结**

#### **主要问题**：
1. 高延迟的 `Commits and Rollbacks`（`log file sync`）。
2. 集群间通信瓶颈（`Global Cache Messaging` 和 `Global Cache Busy`）。
3. 热点块争用（`Buffer Busy - Hot Objects`）。
4. 高频低效 SQL（`Top SQL Statements`）。
5. I/O 性能瓶颈（`db file sequential read`）。

#### **优化优先级**：
1. 优化 `log file sync` 等待（调整日志文件 I/O、减少提交频率）。
2. 减少 `Cluster` 等待（分区表、优化 Global Cache）。
3. 解决热点块争用（分区表、调整块大小）。
4. 优化 Top SQL（运行 SQL Tuning Advisor、创建索引）。
5. 提高 I/O 性能（优化存储、调整参数）。

通过以上优化措施，可以显著提升 Oracle 19c RAC 集群的性能，减少等待时间，提高吞吐量。如果需要进一步分析特定问题，可以提供更详细的 AWR 报告片段或 ASH 数据。