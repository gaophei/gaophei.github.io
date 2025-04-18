# 使用Swingbench对Oracle RAC进行压测的详细步骤

以下是在Oracle RAC环境中使用Swingbench进行压测的完整步骤指南，按照这些步骤可以直接在RAC环境中执行测试。

## 1. 准备测试环境

### 1.1 安装Swingbench

在一台可以连接到RAC集群的服务器上安装Swingbench：

```bash
# 创建安装目录
mkdir -p /home/oracle/swingbench
cd /home/oracle/swingbench

# 下载Swingbench
wget https://github.com/domgiles/swingbench/releases/download/2.6.0.1135/swingbench-2.6.0.1135.zip

# 解压文件
unzip swingbench-2.6.0.1135.zip

# 确保文件有执行权限
chmod +x /home/oracle/swingbench/bin/*.sh
```

### 1.2 配置Oracle客户端

确保测试服务器上安装了Oracle客户端并正确配置了tnsnames.ora：

```bash
# 检查Oracle客户端环境变量
echo $ORACLE_HOME
echo $TNS_ADMIN

# 测试连接到RAC数据库
sqlplus system/password@rac-scan
```

## 2. 创建测试用户和表空间

登录到RAC数据库，创建专用的测试用户和表空间：

```sql
-- 创建表空间
CREATE TABLESPACE swingbench_data 
DATAFILE '+DATA' SIZE 10G 
AUTOEXTEND ON NEXT 1G MAXSIZE 50G;

CREATE TABLESPACE swingbench_index 
DATAFILE '+DATA' SIZE 5G 
AUTOEXTEND ON NEXT 1G MAXSIZE 25G;

-- 创建测试用户
CREATE USER soe IDENTIFIED BY soe_password 
DEFAULT TABLESPACE swingbench_data 
TEMPORARY TABLESPACE temp;

-- 授予必要权限
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE JOB, CREATE EXTERNAL JOB TO soe;
GRANT UNLIMITED TABLESPACE TO soe;
GRANT EXECUTE ON DBMS_LOCK TO soe;
```

## 3. 创建测试数据模型

Swingbench提供了多种测试模型，这里使用Order Entry (SOE)模型：

```bash
cd /home/oracle/swingbench

# 设置环境变量
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export TNS_ADMIN=$ORACLE_HOME/network/admin

# 创建SOE架构和数据
./bin/oewizard -cl \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -ts swingbench_data \
  -is swingbench_index \
  -scale 1 \
  -create \
  -v \
  -c /home/oracle/swingbench/configs/SOE_Server_Side_V2.xml \
  -df +DATA \
  -nopart
```

参数说明：
- `-cl`: 使用命令行模式
- `-cs`: 连接字符串
- `-u`: 用户名
- `-p`: 密码
- `-ts`: 数据表空间
- `-is`: 索引表空间
- `-scale`: 数据规模（GB）
- `-create`: 创建架构
- `-v`: 详细输出
- `-nopart`: 不分区表

## 4. 配置并执行压测

### 4.1 基本压测配置

创建一个自定义配置文件：

```bash
cp /home/oracle/swingbench/configs/SOE_Server_Side_V2.xml /home/oracle/swingbench/configs/RAC_Test.xml
```

编辑配置文件，调整以下参数：
```bash
vi /home/oracle/swingbench/configs/RAC_Test.xml
```

修改以下关键参数：
- `<Connection>`: 确保使用RAC的SCAN地址
- `<UserCount>`: 设置并发用户数
- `<MinThinkTime>`: 最小思考时间（毫秒）
- `<MaxThinkTime>`: 最大思考时间（毫秒）
- `<LogonGroupCount>`: 登录组数量

### 4.2 执行基础压测

```bash
cd /home/oracle/swingbench

# 执行30分钟的压测，100个并发用户
./bin/charbench \
  -c ./configs/RAC_Test.xml \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 100 \
  -rt 00:30 \
  -a
```

参数说明：
- `-c`: 配置文件路径
- `-cs`: 连接字符串
- `-u`: 用户名
- `-p`: 密码
- `-v`: 要显示的统计信息
- `-intermin/-intermax`: 交互最小/最大思考时间
- `-min/-max`: 最小/最大思考时间
- `-uc`: 用户数量
- `-rt`: 运行时间（HH:MM格式）
- `-a`: 自动启动

### 4.3 逐步增加负载

```bash
# 执行200个并发用户的测试
./bin/charbench \
  -c ./configs/RAC_Test.xml \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 200 \
  -rt 00:30 \
  -a

# 执行500个并发用户的测试
./bin/charbench \
  -c ./configs/RAC_Test.xml \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 500 \
  -rt 00:30 \
  -a

# 执行1000个并发用户的测试
./bin/charbench \
  -c ./configs/RAC_Test.xml \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 1000 \
  -rt 00:30 \
  -a
```

## 5. 高级测试场景

### 5.1 节点故障转移测试

在执行压测的同时，模拟节点故障：

```bash
# 在一个终端启动压测
./bin/charbench \
  -c ./configs/RAC_Test.xml \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -v users,tpm,tps \
  -uc 500 \
  -rt 01:00 \
  -a

# 在另一个终端，以root用户身份关闭一个RAC节点（例如node2）
ssh root@rac-node2 "crsctl stop crs -f"
```

观察Swingbench输出，记录故障发生时的性能下降和恢复情况。

### 5.2 RAC负载均衡测试

使用以下命令查看RAC各节点的负载分布：

```bash
# 在压测过程中，登录到数据库并执行以下SQL
sqlplus / as sysdba

-- 查看各节点的会话分布
SELECT inst_id, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE' 
GROUP BY inst_id;

-- 查看各节点的负载情况
SELECT inst_id, value 
FROM gv$sysmetric 
WHERE metric_name = 'CPU Usage Per Sec' 
AND group_id = 2;
```

### 5.3 长时间稳定性测试

执行一个长时间（如24小时）的压测，验证系统的稳定性：

```bash
./bin/charbench \
  -c ./configs/RAC_Test.xml \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -v users,tpm,tps \
  -uc 300 \
  -rt 24:00 \
  -a \
  -o /home/oracle/swingbench/results/24hour_test.xml
```

## 6. 监控与分析

### 6.1 实时监控

在压测过程中，使用以下命令监控数据库性能：

```sql
-- 查看等待事件
SELECT event, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE' AND wait_class != 'Idle' 
GROUP BY event 
ORDER BY COUNT(*) DESC;

-- 查看资源使用情况
SELECT inst_id, resource_name, current_utilization, max_utilization 
FROM gv$resource_limit 
WHERE resource_name IN ('processes', 'sessions', 'transactions') 
ORDER BY inst_id, resource_name;
```

### 6.2 生成AWR报告

在测试前后生成AWR报告，分析性能数据：

```sql
-- 创建基准AWR快照
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();

-- 记下快照ID
SELECT snap_id, instance_number, begin_interval_time 
FROM dba_hist_snapshot 
ORDER BY begin_interval_time DESC;

-- 测试结束后，再创建一个快照
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();

-- 生成AWR报告（替换快照ID）
@?/rdbms/admin/awrgrpt.sql
```

#**创建PDB级别的AWR快照**

#在测试前后手动创建PDB级别的AWR快照

```sql
-- 在CDB$ROOT容器中执行，自动在所有实例的指定PDB中创建快照
sqlplus / as sysdba

DECLARE
  v_con_name VARCHAR2(30) := 'your_pdb';
BEGIN
  FOR rec IN (SELECT inst_id FROM gv$instance) LOOP
    dbms_workload_repository.create_snapshot(
      con_id => (SELECT con_id FROM cdb_pdbs WHERE pdb_name = v_con_name),
      inst_id => rec.inst_id
    );
  END LOOP;
END;
/
```

#**生成PDB级别的AWR报告**

#测试完成后，生成AWR报告

```sql
alter session set container=your_pdb;
@?/rdbms/admin/awrrpt.sql
```



### 6.3 分析Swingbench结果

Swingbench生成的结果文件可以用来分析性能：

```bash
# 使用Swingbench的图形界面查看结果
./bin/swingbench -ls /home/oracle/swingbench/results/24hour_test.xml
```

## 7. 清理测试环境

测试完成后，可以清理测试数据：

```bash
# 删除SOE架构
./bin/oewizard \
  -cl \
  -cs //rac-scan:1521/racdb \
  -u soe \
  -p soe_password \
  -drop
```

```sql
-- 或者通过SQL删除用户和表空间
DROP USER soe CASCADE;
DROP TABLESPACE swingbench_data INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE swingbench_index INCLUDING CONTENTS AND DATAFILES;
```

## 8. 常见问题解决

### 8.1 连接问题

如果遇到连接问题，检查：
- tnsnames.ora配置是否正确
- 监听器是否正常运行
- 防火墙设置是否允许连接

### 8.2 性能问题

如果性能不如预期：
- 检查表空间是否有足够空间
- 确认数据库参数设置是否合理
- 检查网络延迟是否过高

### 8.3 资源限制

如果遇到资源限制：
- 增加processes参数值
- 调整sessions参数
- 检查操作系统资源限制

---

通过以上步骤，你可以在Oracle RAC环境中全面地执行Swingbench压力测试，评估系统的性能、可靠性和扩展能力。这些测试结果将帮助你优化RAC配置，提高系统性能。