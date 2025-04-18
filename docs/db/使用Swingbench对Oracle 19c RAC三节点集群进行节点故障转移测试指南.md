# 使用Swingbench对Oracle 19c RAC三节点集群进行节点故障转移测试指南

## 目录

1. [概述](#1-概述)
2. [环境准备](#2-环境准备)
   - [2.1 硬件和软件要求](#21-硬件和软件要求)
   - [2.2 网络配置](#22-网络配置)
   - [2.3 Oracle RAC环境配置](#23-oracle-rac环境配置)
3. [Swingbench安装与配置](#3-swingbench安装与配置)
   - [3.1 下载与安装](#31-下载与安装)
   - [3.2 创建测试用户和表空间](#32-创建测试用户和表空间)
   - [3.3 生成测试数据](#33-生成测试数据)
4. [Swingbench配置参数](#4-swingbench配置参数)
   - [4.1 连接配置](#41-连接配置)
   - [4.2 测试参数配置](#42-测试参数配置)
   - [4.3 故障转移测试参数](#43-故障转移测试参数)
5. [测试场景设计](#5-测试场景设计)
   - [5.1 单节点计划内停机测试](#51-单节点计划内停机测试)
   - [5.2 单节点非计划停机测试](#52-单节点非计划停机测试)
   - [5.3 网络故障测试](#53-网络故障测试)
   - [5.4 高负载下的节点故障测试](#54-高负载下的节点故障测试)
   - [5.5 多节点故障测试](#55-多节点故障测试)
6. [测试步骤详解](#6-测试步骤详解)
   - [6.1 测试准备工作](#61-测试准备工作)
   - [6.2 单节点计划内停机测试步骤](#62-单节点计划内停机测试步骤)
   - [6.3 单节点非计划停机测试步骤](#63-单节点非计划停机测试步骤)
   - [6.4 网络故障测试步骤](#64-网络故障测试步骤)
   - [6.5 高负载下的节点故障测试步骤](#65-高负载下的节点故障测试步骤)
   - [6.6 多节点故障测试步骤](#66-多节点故障测试步骤)
7. [监控与验证方法](#7-监控与验证方法)
   - [7.1 系统级监控](#71-系统级监控)
   - [7.2 数据库级监控](#72-数据库级监控)
   - [7.3 Swingbench监控](#73-swingbench监控)
   - [7.4 自动化监控脚本](#74-自动化监控脚本)
   - [7.5 验证方法](#75-验证方法)
8. [结果分析与报告](#8-结果分析与报告)
   - [8.1 性能指标分析](#81-性能指标分析)
   - [8.2 故障转移时间分析](#82-故障转移时间分析)
   - [8.3 测试报告模板](#83-测试报告模板)
9. [最佳实践与注意事项](#9-最佳实践与注意事项)
   - [9.1 测试环境准备最佳实践](#91-测试环境准备最佳实践)
   - [9.2 测试执行最佳实践](#92-测试执行最佳实践)
   - [9.3 常见问题与解决方案](#93-常见问题与解决方案)
10. [参考资源](#10-参考资源)

## 1. 概述

本指南详细介绍了如何使用Swingbench工具对Oracle 19c RAC三节点集群进行节点故障转移测试。通过模拟各种故障场景，可以全面评估RAC集群的高可用性和故障恢复能力，验证在节点故障情况下系统的行为和性能表现。

Oracle Real Application Clusters (RAC)是Oracle提供的集群数据库解决方案，允许多个实例同时访问一个共享的数据库，提供高可用性、可扩展性和负载均衡能力。节点故障转移是RAC的核心功能之一，确保在一个节点发生故障时，其上运行的服务能够自动迁移到集群中的其他节点，从而保证业务连续性。

Swingbench是一个开源的基准测试工具，专为测试Oracle数据库的性能和可扩展性而设计。它可以模拟多种负载类型，包括事务处理、数据仓库、OLTP和大容量负载，是评估Oracle RAC故障转移能力的理想工具。

本指南适用于数据库管理员、系统管理员和性能测试工程师，帮助他们设计和执行全面的RAC节点故障转移测试，确保Oracle RAC环境能够满足业务的高可用性需求。

## 2. 环境准备

### 2.1 硬件和软件要求

#### 2.1.1 硬件要求

- **节点数量**：3个物理或虚拟节点
- **每个节点配置**：
  - CPU：至少4核心
  - 内存：至少16GB
  - 磁盘空间：系统盘至少100GB，共享存储至少500GB
  - 网络：至少两张网卡（公共网络和私有互联网络）

#### 2.1.2 软件要求

- **操作系统**：Oracle Linux 7/8或Red Hat Enterprise Linux 7/8
- **数据库版本**：Oracle Database 19c (19.3.0或更高版本)
- **集群软件**：Oracle Grid Infrastructure 19c
- **测试工具**：Swingbench 2.6或更高版本
- **Java环境**：JDK 8或更高版本
- **监控工具**：Oracle Enterprise Manager、AWR报告、OS Watcher

### 2.2 网络配置

#### 2.2.1 网络要求

- **公共网络**：用于客户端访问，每个节点一个公共IP地址
- **私有互联网络**：用于节点间通信，建议使用至少10Gbps的网络
- **SCAN IP**：单一客户端访问名称，通常配置3个IP地址
- **VIP**：每个节点的虚拟IP地址，用于故障转移

#### 2.2.2 网络配置示例

| 节点 | 主机名 | 公共IP | VIP | 私有IP |
|------|--------|--------|-----|--------|
| 节点1 | rac-node1 | 192.168.1.101 | 192.168.1.111 | 10.0.0.101 |
| 节点2 | rac-node2 | 192.168.1.102 | 192.168.1.112 | 10.0.0.102 |
| 节点3 | rac-node3 | 192.168.1.103 | 192.168.1.113 | 10.0.0.103 |
| SCAN | rac-scan | 192.168.1.121-123 | - | - |

### 2.3 Oracle RAC环境配置

#### 2.3.1 验证RAC环境

在开始测试前，确保Oracle RAC环境正常运行：

```bash
# 检查集群状态
crsctl status resource -t

# 检查数据库实例状态
srvctl status database -d <db_name>

# 检查服务状态
srvctl status service -d <db_name>

# 检查监听器状态
lsnrctl status

# 检查ASM实例状态
srvctl status asm
```

#### 2.3.2 配置数据库服务

为测试创建专用的数据库服务：

```bash
# 创建用于测试的服务
srvctl add service -d <db_name> -s swingbench_svc -r <instance1>,<instance2>,<instance3> -P BASIC -y AUTOMATIC -e SELECT -m BASIC -w 3 -z 10

# 启动服务
srvctl start service -d <db_name> -s swingbench_svc

# 验证服务状态
srvctl status service -d <db_name> -s swingbench_svc
```

## 3. Swingbench安装与配置

### 3.1 下载与安装

#### 3.1.1 准备安装环境

1. 确保已安装Java运行环境：

```bash
java -version
```

如果未安装，请使用以下命令安装：

```bash
sudo apt-get update
sudo apt-get install -y openjdk-8-jdk
```

或者在Oracle Linux/RHEL上：

```bash
sudo yum install -y java-1.8.0-openjdk
```

2. 确保已安装Oracle客户端或Oracle实例：

```bash
sqlplus -version
```

#### 3.1.2 下载和安装Swingbench

1. 创建安装目录：

```bash
mkdir -p /home/oracle/swingbench
cd /home/oracle/swingbench
```

2. 下载并解压Swingbench：

```bash
wget http://www.dominicgiles.com/swingbench/swingbench26.zip
unzip swingbench26.zip
```

3. 设置环境变量：

```bash
echo "export SWINGBENCH_HOME=/home/oracle/swingbench" >> ~/.bash_profile
echo "export PATH=\$PATH:\$SWINGBENCH_HOME/bin" >> ~/.bash_profile
source ~/.bash_profile
```

4. 验证安装：

```bash
cd $SWINGBENCH_HOME/bin
./swingbench -v
```

### 3.2 创建测试用户和表空间

1. 连接到Oracle数据库：

```bash
sqlplus / as sysdba
```

2. 创建测试表空间：

```sql
-- 创建数据表空间
CREATE TABLESPACE swingbench_data DATAFILE '+DATA' SIZE 10G AUTOEXTEND ON NEXT 1G MAXSIZE 50G;

-- 创建临时表空间
CREATE TEMPORARY TABLESPACE swingbench_temp TEMPFILE '+DATA' SIZE 5G AUTOEXTEND ON NEXT 1G MAXSIZE 20G;
```

3. 创建测试用户：

```sql
-- 创建用户
CREATE USER swingbench IDENTIFIED BY swingbench123 
DEFAULT TABLESPACE swingbench_data 
TEMPORARY TABLESPACE swingbench_temp;

-- 授予权限
GRANT connect, resource, dba TO swingbench;
GRANT execute ON dbms_lock TO swingbench;
GRANT select ON SYS.V_$PARAMETER TO swingbench;
GRANT select ON SYS.V_$INSTANCE TO swingbench;
GRANT select ON SYS.GV_$INSTANCE TO swingbench;
```

### 3.3 生成测试数据

使用Swingbench的oewizard工具创建Order Entry Schema测试数据：

```bash
cd $SWINGBENCH_HOME/bin

# 创建Order Entry Schema
./oewizard -cl -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 -ts swingbench_data -tc 16 -scale 1 -create
```

参数说明：
- `-cl`: 使用命令行模式
- `-cs`: 连接字符串，格式为//scan-ip:1521/service_name
- `-u`: 用户名
- `-p`: 密码
- `-ts`: 表空间名称
- `-tc`: 使用的线程数
- `-scale`: 数据规模（GB）
- `-create`: 创建新的测试数据

验证测试数据是否正确创建：

```bash
./sbutil -soe -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 -val
```

如果显示"The Order Entry Schema appears to be valid"，则表示测试数据创建成功。

## 4. Swingbench配置参数

### 4.1 连接配置

#### 4.1.1 使用SCAN IP和服务名

在Swingbench配置文件中设置连接字符串：

```xml
<ConnectionString>//rac-scan:1521/swingbench_svc</ConnectionString>
```

#### 4.1.2 使用TNS别名

在`tnsnames.ora`文件中定义TNS别名：

```
SWINGBENCH_RAC =
  (DESCRIPTION =
    (FAILOVER = on)
    (LOAD_BALANCE = on)
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = swingbench_svc)
      (FAILOVER_MODE =
        (TYPE = select)
        (METHOD = basic)
        (RETRIES = 180)
        (DELAY = 5)
      )
    )
  )
```

然后在Swingbench配置中引用：

```xml
<ConnectionString>SWINGBENCH_RAC</ConnectionString>
```

### 4.2 测试参数配置

#### 4.2.1 基本参数

以下是Swingbench配置文件中的关键参数：

```xml
<!-- 用户连接信息 -->
<Username>swingbench</Username>
<Password>swingbench123</Password>

<!-- 测试持续时间（分钟） -->
<RunTime>30</RunTime>

<!-- 用户数量（并发连接数） -->
<NumberOfUsers>50</NumberOfUsers>

<!-- 用户启动间隔（毫秒） -->
<UserStartupInterval>10</UserStartupInterval>

<!-- 事务超时时间（秒） -->
<TransactionTimeout>30</TransactionTimeout>

<!-- 启用统计信息收集 -->
<StatsCollectionStart>true</StatsCollectionStart>
<StatsCollectionEnd>true</StatsCollectionEnd>
<StatsDumpInterval>10</StatsDumpInterval>
```

#### 4.2.2 命令行参数

使用`charbench`命令行工具运行测试时，可以覆盖配置文件中的参数：

```bash
./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 -v users,tpm,tps,resp -rt 30 -uc 50 -c ../configs/SOE_Server_Side_V2.xml
```

参数说明：
- `-cs`: 连接字符串
- `-u`: 用户名
- `-p`: 密码
- `-v`: 显示的统计信息（users=用户数, tpm=每分钟事务数, tps=每秒事务数, resp=响应时间）
- `-rt`: 运行时间（分钟）
- `-uc`: 用户数量
- `-c`: 配置文件路径

### 4.3 故障转移测试参数

针对节点故障转移测试，需要特别关注以下参数：

```xml
<!-- 启用连接池 -->
<UseConnectionPool>true</UseConnectionPool>
<InitialPoolSize>10</InitialPoolSize>
<MinPoolSize>5</MinPoolSize>
<MaxPoolSize>50</MaxPoolSize>

<!-- 连接重试设置 -->
<ConnectionRetries>30</ConnectionRetries>
<ConnectionRetryInterval>3</ConnectionRetryInterval>

<!-- 事务重试设置 -->
<TransactionRetries>5</TransactionRetries>
<TransactionRetryInterval>1</TransactionRetryInterval>
```

## 5. 测试场景设计

### 5.1 单节点计划内停机测试

**目标**：验证在计划内停机情况下，RAC集群能否平滑地将工作负载转移到其他节点。

**测试步骤概述**：
1. 使用Swingbench启动中等负载（约50个并发用户）
2. 确认负载均匀分布在三个节点上
3. 使用`srvctl stop instance`命令优雅地停止一个节点的实例
4. 监控故障转移过程和应用程序响应时间
5. 记录故障转移完成时间和任何错误或警告
6. 使用`srvctl start instance`命令重新启动停止的实例
7. 监控工作负载重新平衡的过程

**预期结果**：
- 实例停止后，连接到该实例的会话应自动转移到其他节点
- 应用程序应继续运行，可能会有短暂的性能下降
- 实例重新启动后，工作负载应重新平衡

### 5.2 单节点非计划停机测试

**目标**：验证在非计划停机情况下，RAC集群能否快速恢复服务。

**测试步骤概述**：
1. 使用Swingbench启动中等负载（约50个并发用户）
2. 确认负载均匀分布在三个节点上
3. 使用`shutdown -h now`命令模拟节点崩溃
4. 监控故障检测和故障转移过程
5. 记录故障转移完成时间和任何错误或警告
6. 重新启动故障节点
7. 监控节点重新加入集群的过程

**预期结果**：
- 集群应检测到节点故障并启动故障转移
- VIP应迁移到存活的节点
- 连接到故障节点的会话应在配置的超时时间后重新连接到其他节点
- 应用程序应继续运行，可能会有短暂的服务中断
- 节点重新启动后，应自动重新加入集群

### 5.3 网络故障测试

#### 5.3.1 公共网络故障测试

**目标**：验证在公共网络故障情况下，RAC集群的行为和恢复能力。

**测试步骤概述**：
1. 使用Swingbench启动中等负载（约50个并发用户）
2. 确认负载均匀分布在三个节点上
3. 在一个节点上禁用公共网络接口
4. 监控VIP迁移和客户端连接行为
5. 记录故障转移完成时间和任何错误或警告
6. 重新启用公共网络接口
7. 监控VIP和服务的恢复过程

**预期结果**：
- VIP应迁移到存活的节点
- 客户端应能通过SCAN IP继续访问数据库
- 公共网络恢复后，VIP应返回原始节点

#### 5.3.2 私有互联网络故障测试

**目标**：验证在私有互联网络故障情况下，RAC集群的行为和恢复能力。

**测试步骤概述**：
1. 使用Swingbench启动中等负载（约50个并发用户）
2. 确认负载均匀分布在三个节点上
3. 在一个节点上禁用私有互联网络接口
4. 监控节点状态和集群完整性
5. 记录任何错误或警告
6. 重新启用私有互联网络接口
7. 监控节点通信的恢复过程

**预期结果**：
- 根据集群配置，节点可能会被驱逐出集群或进入隔离状态
- 集群应保持数据一致性
- 私有互联网络恢复后，节点应恢复正常通信

### 5.4 高负载下的节点故障测试

**目标**：验证在高负载情况下，RAC集群的故障转移性能。

**测试步骤概述**：
1. 使用Swingbench启动高负载（约200个并发用户）
2. 确认负载均匀分布在三个节点上
3. 使用`shutdown -h now`命令模拟一个节点的突然崩溃
4. 监控故障检测和故障转移过程
5. 记录故障转移完成时间、事务响应时间和任何错误或警告
6. 重新启动故障节点
7. 监控节点重新加入集群和工作负载重新平衡的过程

**预期结果**：
- 集群应检测到节点故障并启动故障转移
- 连接到故障节点的会话应在配置的超时时间后重新连接到其他节点
- 应用程序应继续运行，可能会有性能下降
- 节点重新启动后，应自动重新加入集群

### 5.5 多节点故障测试

**目标**：验证在多个节点同时故障的情况下，RAC集群的行为。

**测试步骤概述**：
1. 使用Swingbench启动中等负载（约50个并发用户）
2. 确认负载均匀分布在三个节点上
3. 几乎同时停止两个节点（在三节点集群中留下一个节点）
4. 监控剩余节点的行为和客户端连接
5. 记录任何错误或警告
6. 重新启动故障节点
7. 监控节点重新加入集群的过程

**预期结果**：
- 如果剩余节点构成仲裁（在三节点集群中，一个节点不构成仲裁），集群应继续运行
- 如果不构成仲裁，集群可能会停止
- 节点重新启动后，应自动重新加入集群

## 6. 测试步骤详解

### 6.1 测试准备工作

#### 6.1.1 环境准备

1. **确认RAC集群状态**
   ```bash
   # 以oracle用户登录到任一节点
   ssh oracle@rac-node1
   
   # 检查集群状态
   crsctl status resource -t
   
   # 确认所有节点和服务正常运行
   srvctl status database -d <db_name>
   srvctl status service -d <db_name>
   ```

2. **确认网络配置**
   ```bash
   # 检查SCAN配置
   nslookup <scan-name>
   
   # 检查VIP配置
   srvctl status vip
   
   # 测试节点间连通性
   ping <rac-node1-priv>
   ping <rac-node2-priv>
   ping <rac-node3-priv>
   ```

3. **准备监控脚本**
   ```bash
   # 创建监控目录
   mkdir -p /home/oracle/rac_test/logs
   
   # 创建监控脚本
   cat > /home/oracle/rac_test/monitor_rac.sh << 'EOF'
   #!/bin/bash
   LOG_DIR="/home/oracle/rac_test/logs"
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   LOG_FILE="${LOG_DIR}/rac_status_${TIMESTAMP}.log"
   
   echo "=== RAC Status Check - $(date) ===" > $LOG_FILE
   echo "" >> $LOG_FILE
   
   echo "=== Cluster Resources ===" >> $LOG_FILE
   crsctl status resource -t >> $LOG_FILE
   
   echo "" >> $LOG_FILE
   echo "=== Database Status ===" >> $LOG_FILE
   srvctl status database -d <db_name> -v >> $LOG_FILE
   
   echo "" >> $LOG_FILE
   echo "=== Service Status ===" >> $LOG_FILE
   srvctl status service -d <db_name> -v >> $LOG_FILE
   
   echo "" >> $LOG_FILE
   echo "=== Instance Status ===" >> $LOG_FILE
   sqlplus -s / as sysdba << EOSQL >> $LOG_FILE
   set linesize 200
   set pagesize 1000
   select inst_id, instance_name, status, host_name from gv\$instance;
   exit;
   EOSQL
   
   echo "" >> $LOG_FILE
   echo "=== Active Sessions ===" >> $LOG_FILE
   sqlplus -s / as sysdba << EOSQL >> $LOG_FILE
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOSQL
   
   echo "Log saved to $LOG_FILE"
   EOF
   
   chmod +x /home/oracle/rac_test/monitor_rac.sh
   ```

4. **备份数据库**
   ```bash
   # 以oracle用户身份连接到数据库
   sqlplus / as sysdba
   
   # 创建备份
   RMAN> BACKUP DATABASE PLUS ARCHIVELOG;
   ```

#### 6.1.2 测试前检查清单

- [ ] 所有节点状态正常
- [ ] 所有数据库实例状态正常
- [ ] 所有服务状态正常
- [ ] 网络连接正常
- [ ] Swingbench安装和配置完成
- [ ] 测试数据已创建
- [ ] 监控脚本已准备
- [ ] 数据库已备份

### 6.2 单节点计划内停机测试步骤

#### 6.2.1 测试准备

1. **启动监控脚本**
   ```bash
   # 在一个单独的终端窗口中运行
   /home/oracle/rac_test/monitor_rac.sh
   ```

2. **记录初始状态**
   ```bash
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/initial_status.log
   
   # 记录数据库服务分布
   srvctl status service -d <db_name> -v >> /home/oracle/rac_test/logs/initial_status.log
   
   # 记录活动会话分布
   sqlplus -s / as sysdba << EOF >> /home/oracle/rac_test/logs/initial_status.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

#### 6.2.2 执行测试

1. **启动Swingbench负载**
   ```bash
   cd $SWINGBENCH_HOME/bin
   
   # 启动Swingbench测试，50个并发用户，运行30分钟
   ./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
     -v users,tpm,tps,resp,errors \
     -rt 30 \
     -uc 50 \
     -min 0 \
     -max 0 \
     -stats all \
     -statsinterval 5 \
     -statsdir /home/oracle/rac_test/logs \
     -c ../configs/SOE_Server_Side_V2.xml > /home/oracle/rac_test/logs/swingbench_run1.log &
     
     
   ./bin/charbench \
     -c ./configs/19RAC_Test.xml \
     -cs //172.18.13.176:1521/s_stuwork_swingbench \
     -u soe01 \
     -p soe01 \
     -v users,tpm,tps,errs \
     -intermin 50 \
     -intermax 100 \
     -min 0 \
     -max 30 \
     -uc 300 \
     -rt 00:30 \
     -a \
     -r /home/oracle/swingbench/rac_transaction_swingbench.log
   ```
   
2. **等待负载稳定**
   ```bash
   # 等待约5分钟，让负载稳定
   sleep 300
   ```

3. **记录负载分布**
   ```bash
   # 记录测试开始时的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/pre_shutdown_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

4. **计划内停止一个节点的实例**
   ```bash
   # 记录停止时间
   echo "Instance shutdown started at $(date)" > /home/oracle/rac_test/logs/shutdown_time.log
   
   # 停止节点2的实例
   #srvctl stop instance -d <db_name> -i <instance_name_3> -o immediate
   srvctl stop instance -d xydb -i xydb2 -force
   
   # 记录停止完成时间
   echo "Instance shutdown completed at $(date)" >> /home/oracle/rac_test/logs/shutdown_time.log
   ```
   
5. **监控故障转移过程**
   ```bash
   # 运行监控脚本
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录故障转移后的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/post_shutdown_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

6. **等待测试继续运行**
   ```bash
   # 等待约10分钟
   sleep 600
   ```

7. **重新启动停止的实例**
   ```bash
   # 记录启动时间
   echo "Instance startup started at $(date)" > /home/oracle/rac_test/logs/startup_time.log
   
   # 启动节点3的实例
   srvctl start instance -d <db_name> -i <instance_name_3>
   
   # 记录启动完成时间
   echo "Instance startup completed at $(date)" >> /home/oracle/rac_test/logs/startup_time.log
   ```

8. **监控工作负载重新平衡**
   ```bash
   # 运行监控脚本
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录实例重启后的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/post_startup_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

9. **等待Swingbench测试完成**
   ```bash
   # 等待Swingbench测试完成
   wait
   ```

#### 6.2.3 收集和分析结果

1. **收集Swingbench结果**
   ```bash
   # 复制Swingbench结果文件
   cp /home/oracle/rac_test/logs/swingbench_run1.log /home/oracle/rac_test/results/
   cp /home/oracle/rac_test/logs/*.xml /home/oracle/rac_test/results/
   ```

2. **生成AWR报告**
   ```bash
   # 连接到数据库
   sqlplus / as sysdba
   
   # 生成AWR报告
   @?/rdbms/admin/awrrpt.sql
   ```

3. **分析结果**
   - 计算故障检测时间
   - 计算故障转移时间
   - 计算服务中断时间
   - 分析事务响应时间变化
   - 分析事务吞吐量变化
   - 检查是否有任何错误或警告

### 6.3 单节点非计划停机测试步骤

#### 6.3.1 测试准备

1. **启动监控脚本**
   ```bash
   # 在一个单独的终端窗口中运行
   /home/oracle/rac_test/monitor_rac.sh
   ```

2. **记录初始状态**
   ```bash
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/initial_status_scenario2.log
   
   # 记录数据库服务分布
   srvctl status service -d <db_name> -v >> /home/oracle/rac_test/logs/initial_status_scenario2.log
   ```

#### 6.3.2 执行测试

1. **启动Swingbench负载**
   ```bash
   cd $SWINGBENCH_HOME/bin
   
   # 启动Swingbench测试，50个并发用户，运行30分钟
   ./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
     -v users,tpm,tps,resp,errors \
     -rt 30 \
     -uc 50 \
     -min 0 \
     -max 0 \
     -stats all \
     -statsinterval 5 \
     -statsdir /home/oracle/rac_test/logs \
     -c ../configs/SOE_Server_Side_V2.xml > /home/oracle/rac_test/logs/swingbench_run2.log &
   ```

2. **等待负载稳定**
   ```bash
   # 等待约5分钟，让负载稳定
   sleep 300
   ```

3. **记录负载分布**
   ```bash
   # 记录测试开始时的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/pre_crash_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

4. **模拟节点崩溃**
   ```bash
   # 登录到节点2
   ssh oracle@rac-node2
   
   # 记录崩溃时间
   echo "Node crash started at $(date)" > /tmp/crash_time.log
   
   # 模拟节点崩溃（需要root权限）
   sudo su -
   shutdown -h now
   ```

5. **监控故障检测和故障转移过程**
   ```bash
   # 在节点1上运行监控脚本
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录故障转移后的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/post_crash_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

6. **等待测试继续运行**
   ```bash
   # 等待约10分钟
   sleep 600
   ```

7. **重新启动崩溃的节点**
   ```bash
   # 手动重新启动节点2
   # 这通常需要物理访问服务器或通过远程管理接口（如iLO、DRAC等）
   
   # 记录节点重新启动时间
   echo "Node restart started at $(date)" > /home/oracle/rac_test/logs/node_restart_time.log
   ```

8. **监控节点重新加入集群**
   ```bash
   # 运行监控脚本
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录节点重新加入后的状态
   crsctl status resource -t > /home/oracle/rac_test/logs/post_restart_status.log
   
   # 记录节点重新加入后的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/post_restart_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

9. **等待Swingbench测试完成**
   ```bash
   # 等待Swingbench测试完成
   wait
   ```

#### 6.3.3 收集和分析结果

1. **收集Swingbench结果**
   ```bash
   # 复制Swingbench结果文件
   cp /home/oracle/rac_test/logs/swingbench_run2.log /home/oracle/rac_test/results/
   cp /home/oracle/rac_test/logs/*.xml /home/oracle/rac_test/results/
   ```

2. **生成AWR报告**
   ```bash
   # 连接到数据库
   sqlplus / as sysdba
   
   # 生成AWR报告
   @?/rdbms/admin/awrrpt.sql
   ```

3. **分析结果**
   - 计算故障检测时间
   - 计算故障转移时间
   - 计算服务中断时间
   - 分析事务响应时间变化
   - 分析事务吞吐量变化
   - 检查是否有任何错误或警告

### 6.4 网络故障测试步骤

#### 6.4.1 公共网络故障测试

1. **启动监控脚本**
   ```bash
   # 在一个单独的终端窗口中运行
   /home/oracle/rac_test/monitor_rac.sh
   ```

2. **记录初始状态**
   ```bash
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/initial_status_scenario3_1.log
   
   # 记录VIP状态
   srvctl status vip >> /home/oracle/rac_test/logs/initial_status_scenario3_1.log
   ```

3. **启动Swingbench负载**
   ```bash
   cd $SWINGBENCH_HOME/bin
   
   # 启动Swingbench测试，50个并发用户，运行30分钟
   ./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
     -v users,tpm,tps,resp,errors \
     -rt 30 \
     -uc 50 \
     -min 0 \
     -max 0 \
     -stats all \
     -statsinterval 5 \
     -statsdir /home/oracle/rac_test/logs \
     -c ../configs/SOE_Server_Side_V2.xml > /home/oracle/rac_test/logs/swingbench_run3_1.log &
   ```

4. **等待负载稳定**
   ```bash
   # 等待约5分钟，让负载稳定
   sleep 300
   ```

5. **禁用公共网络接口**
   ```bash
   # 登录到节点1
   ssh oracle@rac-node1
   
   # 记录网络禁用时间
   echo "Public network disabled at $(date)" > /tmp/network_disable_time.log
   
   # 禁用公共网络接口（需要root权限）
   sudo su -
   ifdown eth0  # 或适用于您环境的网络接口名称
   ```

6. **监控VIP迁移和客户端连接行为**
   ```bash
   # 在节点2上运行监控脚本
   ssh oracle@rac-node2
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录VIP状态
   srvctl status vip > /home/oracle/rac_test/logs/post_network_disable_vip.log
   ```

7. **等待测试继续运行**
   ```bash
   # 等待约10分钟
   sleep 600
   ```

8. **重新启用公共网络接口**
   ```bash
   # 登录到节点1
   ssh oracle@rac-node1
   
   # 记录网络启用时间
   echo "Public network enabled at $(date)" > /tmp/network_enable_time.log
   
   # 启用公共网络接口（需要root权限）
   sudo su -
   ifup eth0  # 或适用于您环境的网络接口名称
   ```

9. **监控VIP和服务的恢复过程**
   ```bash
   # 运行监控脚本
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录VIP状态
   srvctl status vip > /home/oracle/rac_test/logs/post_network_enable_vip.log
   ```

10. **等待Swingbench测试完成**
    ```bash
    # 等待Swingbench测试完成
    wait
    ```

#### 6.4.2 私有互联网络故障测试

1. **启动监控脚本**
   ```bash
   # 在一个单独的终端窗口中运行
   /home/oracle/rac_test/monitor_rac.sh
   ```

2. **记录初始状态**
   ```bash
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/initial_status_scenario3_2.log
   
   # 记录节点状态
   olsnodes -n -s -t >> /home/oracle/rac_test/logs/initial_status_scenario3_2.log
   ```

3. **启动Swingbench负载**
   ```bash
   cd $SWINGBENCH_HOME/bin
   
   # 启动Swingbench测试，50个并发用户，运行30分钟
   ./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
     -v users,tpm,tps,resp,errors \
     -rt 30 \
     -uc 50 \
     -min 0 \
     -max 0 \
     -stats all \
     -statsinterval 5 \
     -statsdir /home/oracle/rac_test/logs \
     -c ../configs/SOE_Server_Side_V2.xml > /home/oracle/rac_test/logs/swingbench_run3_2.log &
   ```

4. **等待负载稳定**
   ```bash
   # 等待约5分钟，让负载稳定
   sleep 300
   ```

5. **禁用私有互联网络接口**
   ```bash
   # 登录到节点3
   ssh oracle@rac-node3
   
   # 记录网络禁用时间
   echo "Private network disabled at $(date)" > /tmp/private_network_disable_time.log
   
   # 禁用私有互联网络接口（需要root权限）
   sudo su -
   ifdown eth1  # 或适用于您环境的网络接口名称
   ```

6. **监控节点状态和集群完整性**
   ```bash
   # 在节点1上运行监控脚本
   ssh oracle@rac-node1
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录节点状态
   olsnodes -n -s -t > /home/oracle/rac_test/logs/post_private_network_disable_nodes.log
   
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/post_private_network_disable_cluster.log
   ```

7. **等待测试继续运行**
   ```bash
   # 等待约10分钟
   sleep 600
   ```

8. **重新启用私有互联网络接口**
   ```bash
   # 登录到节点3
   ssh oracle@rac-node3
   
   # 记录网络启用时间
   echo "Private network enabled at $(date)" > /tmp/private_network_enable_time.log
   
   # 启用私有互联网络接口（需要root权限）
   sudo su -
   ifup eth1  # 或适用于您环境的网络接口名称
   ```

9. **监控节点通信的恢复过程**
   ```bash
   # 运行监控脚本
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录节点状态
   olsnodes -n -s -t > /home/oracle/rac_test/logs/post_private_network_enable_nodes.log
   
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/post_private_network_enable_cluster.log
   ```

10. **等待Swingbench测试完成**
    ```bash
    # 等待Swingbench测试完成
    wait
    ```

### 6.5 高负载下的节点故障测试步骤

1. **启动监控脚本**
   ```bash
   # 在一个单独的终端窗口中运行
   /home/oracle/rac_test/monitor_rac.sh
   ```

2. **记录初始状态**
   ```bash
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/initial_status_scenario4.log
   
   # 记录数据库服务分布
   srvctl status service -d <db_name> -v >> /home/oracle/rac_test/logs/initial_status_scenario4.log
   ```

3. **启动高负载Swingbench测试**
   ```bash
   cd $SWINGBENCH_HOME/bin
   
   # 启动Swingbench测试，200个并发用户，运行30分钟
   ./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
     -v users,tpm,tps,resp,errors \
     -rt 30 \
     -uc 200 \
     -min 0 \
     -max 0 \
     -stats all \
     -statsinterval 5 \
     -statsdir /home/oracle/rac_test/logs \
     -c ../configs/SOE_Server_Side_V2.xml > /home/oracle/rac_test/logs/swingbench_run4.log &
   ```

4. **等待负载稳定**
   ```bash
   # 等待约5分钟，让负载稳定
   sleep 300
   ```

5. **记录负载分布**
   ```bash
   # 记录测试开始时的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/pre_high_load_crash_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

6. **模拟节点崩溃**
   ```bash
   # 登录到节点1
   ssh oracle@rac-node1
   
   # 记录崩溃时间
   echo "Node crash started at $(date)" > /tmp/high_load_crash_time.log
   
   # 模拟节点崩溃（需要root权限）
   sudo su -
   shutdown -h now
   ```

7. **监控故障检测和故障转移过程**
   ```bash
   # 在节点2上运行监控脚本
   ssh oracle@rac-node2
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录故障转移后的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/post_high_load_crash_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

8. **等待测试继续运行**
   ```bash
   # 等待约10分钟
   sleep 600
   ```

9. **重新启动崩溃的节点**
   ```bash
   # 手动重新启动节点1
   # 这通常需要物理访问服务器或通过远程管理接口（如iLO、DRAC等）
   
   # 记录节点重新启动时间
   echo "Node restart started at $(date)" > /home/oracle/rac_test/logs/high_load_node_restart_time.log
   ```

10. **监控节点重新加入集群和工作负载重新平衡**
    ```bash
    # 运行监控脚本
    /home/oracle/rac_test/monitor_rac.sh
    
    # 记录节点重新加入后的状态
    crsctl status resource -t > /home/oracle/rac_test/logs/post_high_load_restart_status.log
    
    # 记录节点重新加入后的活动会话分布
    sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/post_high_load_restart_sessions.log
    set linesize 200
    set pagesize 1000
    select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
    exit;
    EOF
    ```

11. **等待Swingbench测试完成**
    ```bash
    # 等待Swingbench测试完成
    wait
    ```

### 6.6 多节点故障测试步骤

1. **启动监控脚本**
   ```bash
   # 在一个单独的终端窗口中运行
   /home/oracle/rac_test/monitor_rac.sh
   ```

2. **记录初始状态**
   ```bash
   # 记录集群状态
   crsctl status resource -t > /home/oracle/rac_test/logs/initial_status_scenario5.log
   
   # 记录数据库服务分布
   srvctl status service -d <db_name> -v >> /home/oracle/rac_test/logs/initial_status_scenario5.log
   ```

3. **启动Swingbench负载**
   ```bash
   cd $SWINGBENCH_HOME/bin
   
   # 启动Swingbench测试，50个并发用户，运行30分钟
   ./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
     -v users,tpm,tps,resp,errors \
     -rt 30 \
     -uc 50 \
     -min 0 \
     -max 0 \
     -stats all \
     -statsinterval 5 \
     -statsdir /home/oracle/rac_test/logs \
     -c ../configs/SOE_Server_Side_V2.xml > /home/oracle/rac_test/logs/swingbench_run5.log &
   ```

4. **等待负载稳定**
   ```bash
   # 等待约5分钟，让负载稳定
   sleep 300
   ```

5. **记录负载分布**
   ```bash
   # 记录测试开始时的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/pre_multi_node_crash_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

6. **几乎同时停止两个节点**
   ```bash
   # 准备在两个节点上执行关闭命令
   # 在节点1上
   ssh oracle@rac-node1
   
   # 记录崩溃时间
   echo "Node 1 crash started at $(date)" > /tmp/multi_node_crash_time_1.log
   
   # 在节点2上
   ssh oracle@rac-node2
   
   # 记录崩溃时间
   echo "Node 2 crash started at $(date)" > /tmp/multi_node_crash_time_2.log
   
   # 几乎同时在两个节点上执行关闭命令（需要root权限）
   # 在节点1上
   sudo su -
   shutdown -h now
   
   # 在节点2上
   sudo su -
   shutdown -h now
   ```

7. **监控剩余节点的行为和客户端连接**
   ```bash
   # 在节点3上运行监控脚本
   ssh oracle@rac-node3
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录多节点故障后的状态
   crsctl status resource -t > /home/oracle/rac_test/logs/post_multi_node_crash_status.log
   
   # 尝试连接到数据库并记录结果
   sqlplus -s swingbench/swingbench123@//rac-scan:1521/swingbench_svc << EOF > /home/oracle/rac_test/logs/post_multi_node_crash_connection.log
   select sysdate from dual;
   exit;
   EOF
   ```

8. **重新启动故障节点**
   ```bash
   # 手动重新启动节点1和节点2
   # 这通常需要物理访问服务器或通过远程管理接口（如iLO、DRAC等）
   
   # 记录节点重新启动时间
   echo "Nodes restart started at $(date)" > /home/oracle/rac_test/logs/multi_node_restart_time.log
   ```

9. **监控节点重新加入集群的过程**
   ```bash
   # 运行监控脚本
   /home/oracle/rac_test/monitor_rac.sh
   
   # 记录节点重新加入后的状态
   crsctl status resource -t > /home/oracle/rac_test/logs/post_multi_node_restart_status.log
   
   # 记录节点重新加入后的活动会话分布
   sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/post_multi_node_restart_sessions.log
   set linesize 200
   set pagesize 1000
   select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
   exit;
   EOF
   ```

10. **等待Swingbench测试完成**
    ```bash
    # 等待Swingbench测试完成
    wait
    ```

## 7. 监控与验证方法

### 7.1 系统级监控

#### 7.1.1 操作系统监控

```bash
# 实时监控CPU使用率
top -c

# 每5秒收集一次CPU使用率数据，共收集100次
vmstat 5 100 > /home/oracle/rac_test/logs/vmstat_$(date +%Y%m%d_%H%M%S).log

# 使用sar收集CPU使用率数据
sar -u 5 100 > /home/oracle/rac_test/logs/sar_cpu_$(date +%Y%m%d_%H%M%S).log

# 实时监控内存使用率
free -m

# 每5秒收集一次内存使用率数据，共收集100次
sar -r 5 100 > /home/oracle/rac_test/logs/sar_mem_$(date +%Y%m%d_%H%M%S).log

# 实时监控磁盘I/O
iostat -xm 5

# 收集磁盘I/O数据
iostat -xm 5 100 > /home/oracle/rac_test/logs/iostat_$(date +%Y%m%d_%H%M%S).log

# 实时监控网络流量
sar -n DEV 5

# 收集网络流量数据
sar -n DEV 5 100 > /home/oracle/rac_test/logs/sar_net_$(date +%Y%m%d_%H%M%S).log
```

#### 7.1.2 集群监控

```bash
# 监控集群资源状态
crsctl status resource -t > /home/oracle/rac_test/logs/crs_status_$(date +%Y%m%d_%H%M%S).log

# 监控集群节点状态
olsnodes -n -s -t > /home/oracle/rac_test/logs/olsnodes_$(date +%Y%m%d_%H%M%S).log

# 监控集群完整性
cluvfy comp healthcheck -n all > /home/oracle/rac_test/logs/cluvfy_$(date +%Y%m%d_%H%M%S).log

# 监控VIP状态
srvctl status vip > /home/oracle/rac_test/logs/vip_status_$(date +%Y%m%d_%H%M%S).log

# 监控SCAN状态
srvctl status scan > /home/oracle/rac_test/logs/scan_status_$(date +%Y%m%d_%H%M%S).log
srvctl status scan_listener > /home/oracle/rac_test/logs/scan_listener_status_$(date +%Y%m%d_%H%M%S).log

# 监控ASM实例状态
srvctl status asm > /home/oracle/rac_test/logs/asm_status_$(date +%Y%m%d_%H%M%S).log

# 监控ASM磁盘组状态
asmcmd lsdg > /home/oracle/rac_test/logs/asm_diskgroup_$(date +%Y%m%d_%H%M%S).log
```

### 7.2 数据库级监控

#### 7.2.1 实例监控

```bash
# 监控数据库实例状态
srvctl status database -d <db_name> > /home/oracle/rac_test/logs/db_status_$(date +%Y%m%d_%H%M%S).log

# 监控实例状态
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/instance_status_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, instance_name, status, host_name from gv\$instance;
exit;
EOF

# 监控数据库服务状态
srvctl status service -d <db_name> > /home/oracle/rac_test/logs/service_status_$(date +%Y%m%d_%H%M%S).log

# 监控服务分布
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/service_distribution_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, name, count(*) from gv\$session where type = 'USER' group by inst_id, name;
exit;
EOF
```

#### 7.2.2 会话监控

```bash
# 监控活动会话分布
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/active_sessions_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
exit;
EOF

# 监控长时间运行的会话
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/long_running_sessions_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, sid, serial#, username, program, machine, last_call_et/60 as "Minutes_Since_Last_Call"
from gv\$session
where status = 'ACTIVE' and type = 'USER' and last_call_et > 300
order by last_call_et desc;
exit;
EOF

# 监控会话等待事件
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/session_waits_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, event, count(*) 
from gv\$session_wait 
where wait_class != 'Idle' 
group by inst_id, event 
order by count(*) desc;
exit;
EOF
```

#### 7.2.3 性能监控

```bash
# 监控系统统计信息
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/system_stats_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, statistic#, name, value 
from gv\$sysstat 
where name in ('physical reads', 'physical writes', 'redo writes', 'user commits', 'user rollbacks', 'execute count')
order by inst_id, name;
exit;
EOF

# 监控全局缓存统计信息
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/gc_stats_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, name, value 
from gv\$sysstat 
where name like 'gc%' 
order by inst_id, name;
exit;
EOF

# 监控等待事件统计信息
sqlplus -s / as sysdba << EOF > /home/oracle/rac_test/logs/wait_events_$(date +%Y%m%d_%H%M%S).log
set linesize 200
set pagesize 1000
select inst_id, event, total_waits, time_waited_micro/1000000 as time_waited_seconds
from gv\$system_event
where wait_class != 'Idle'
order by time_waited_micro desc;
exit;
EOF
```

#### 7.2.4 警报日志监控

```bash
# 监控警报日志
for i in $(seq 1 3); do
  inst_name="<instance_name_$i>"
  tail -100 $ORACLE_BASE/diag/rdbms/<db_name>/$inst_name/trace/alert_$inst_name.log > /home/oracle/rac_test/logs/alert_${inst_name}_$(date +%Y%m%d_%H%M%S).log
done
```

### 7.3 Swingbench监控

#### 7.3.1 实时性能监控

在Swingbench运行过程中，可以通过以下方式监控性能：

```bash
# 使用charbench的-v参数显示实时统计信息
./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
  -v users,tpm,tps,resp,errors \
  -rt 30 \
  -uc 50 \
  -stats all \
  -statsinterval 5 \
  -statsdir /home/oracle/rac_test/logs \
  -c ../configs/SOE_Server_Side_V2.xml
```

#### 7.3.2 统计信息收集

```bash
# 收集Swingbench统计信息
./charbench -cs //rac-scan:1521/swingbench_svc -u swingbench -p swingbench123 \
  -v users,tpm,tps,resp,errors \
  -rt 30 \
  -uc 50 \
  -stats all \
  -statsinterval 5 \
  -statsdir /home/oracle/rac_test/logs \
  -c ../configs/SOE_Server_Side_V2.xml > /home/oracle/rac_test/logs/swingbench_stats_$(date +%Y%m%d_%H%M%S).log
```

### 7.4 自动化监控脚本

#### 7.4.1 周期性监控脚本

```bash
#!/bin/bash
# 文件名: periodic_monitor.sh
# 描述: 周期性监控RAC集群状态

LOG_DIR="/home/oracle/rac_test/logs"
INTERVAL=60  # 监控间隔（秒）
DURATION=3600  # 监控持续时间（秒）
DB_NAME="<db_name>"

# 创建日志目录
mkdir -p $LOG_DIR

# 开始监控
echo "Starting periodic monitoring at $(date)" > $LOG_DIR/monitor_start.log
start_time=$(date +%s)
current_time=$start_time

while [ $((current_time - start_time)) -lt $DURATION ]; do
  timestamp=$(date +%Y%m%d_%H%M%S)
  
  # 监控集群状态
  crsctl status resource -t > $LOG_DIR/crs_status_$timestamp.log
  
  # 监控数据库状态
  srvctl status database -d $DB_NAME > $LOG_DIR/db_status_$timestamp.log
  srvctl status service -d $DB_NAME > $LOG_DIR/service_status_$timestamp.log
  
  # 监控实例状态
  sqlplus -s / as sysdba << EOF > $LOG_DIR/instance_status_$timestamp.log
set linesize 200
set pagesize 1000
select inst_id, instance_name, status, host_name from gv\$instance;
select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
exit;
EOF
  
  # 监控系统资源
  vmstat 1 5 > $LOG_DIR/vmstat_$timestamp.log
  iostat -xm 1 5 > $LOG_DIR/iostat_$timestamp.log
  
  # 等待下一个监控周期
  sleep $INTERVAL
  current_time=$(date +%s)
done

echo "Periodic monitoring completed at $(date)" >> $LOG_DIR/monitor_start.log
```

#### 7.4.2 故障转移监控脚本

```bash
#!/bin/bash
# 文件名: failover_monitor.sh
# 描述: 监控RAC故障转移过程

LOG_DIR="/home/oracle/rac_test/logs"
INTERVAL=5  # 监控间隔（秒）
DURATION=600  # 监控持续时间（秒）
DB_NAME="<db_name>"

# 创建日志目录
mkdir -p $LOG_DIR

# 开始监控
echo "Starting failover monitoring at $(date)" > $LOG_DIR/failover_monitor_start.log
start_time=$(date +%s)
current_time=$start_time

while [ $((current_time - start_time)) -lt $DURATION ]; do
  timestamp=$(date +%Y%m%d_%H%M%S)
  
  # 监控集群状态
  crsctl status resource -t > $LOG_DIR/failover_crs_status_$timestamp.log
  
  # 监控数据库状态
  srvctl status database -d $DB_NAME > $LOG_DIR/failover_db_status_$timestamp.log
  srvctl status service -d $DB_NAME > $LOG_DIR/failover_service_status_$timestamp.log
  
  # 监控VIP状态
  srvctl status vip > $LOG_DIR/failover_vip_status_$timestamp.log
  
  # 监控实例状态
  sqlplus -s / as sysdba << EOF > $LOG_DIR/failover_instance_status_$timestamp.log
set linesize 200
set pagesize 1000
select inst_id, instance_name, status, host_name from gv\$instance;
select inst_id, count(*) from gv\$session where status = 'ACTIVE' and type = 'USER' group by inst_id;
exit;
EOF
  
  # 监控等待事件
  sqlplus -s / as sysdba << EOF > $LOG_DIR/failover_wait_events_$timestamp.log
set linesize 200
set pagesize 1000
select inst_id, event, count(*) 
from gv\$session_wait 
where wait_class != 'Idle' 
group by inst_id, event 
order by count(*) desc;
exit;
EOF
  
  # 等待下一个监控周期
  sleep $INTERVAL
  current_time=$(date +%s)
done

echo "Failover monitoring completed at $(date)" >> $LOG_DIR/failover_monitor_start.log
```

### 7.5 验证方法

#### 7.5.1 故障检测验证

故障检测时间是从节点故障发生到集群检测到故障的时间。可以通过以下方法计算：

1. 记录节点故障发生的时间（例如，执行`shutdown -h now`命令的时间）
2. 从警报日志中找到集群检测到节点故障的时间
3. 计算两个时间点之间的差值

```bash
# 查找节点故障检测记录
grep -i "node.*down" $ORACLE_BASE/diag/rdbms/<db_name>/<instance_name>/trace/alert_<instance_name>.log
```

故障检测验证标准：
- 故障检测时间应在配置的CSS misscount参数值范围内（通常为30秒）
- 集群应正确识别故障节点
- 集群日志应包含适当的故障检测消息

#### 7.5.2 故障转移验证

故障转移时间是从检测到故障到服务在其他节点上可用的时间。可以通过以下方法计算：

1. 从警报日志中找到集群检测到节点故障的时间
2. 从警报日志中找到服务在其他节点上启动的时间
3. 计算两个时间点之间的差值

```bash
# 查找服务重新启动记录
grep -i "service.*started" $ORACLE_BASE/diag/rdbms/<db_name>/<instance_name>/trace/alert_<instance_name>.log
```

故障转移验证标准：
- VIP应成功迁移到存活的节点
- 数据库服务应在配置的时间内在其他节点上可用
- 客户端应能够重新连接到数据库
- 不应有数据损坏或一致性问题

#### 7.5.3 服务连续性验证

连接恢复率是成功重新连接到其他节点的会话百分比：

```
连接恢复率 = (故障后成功连接的会话数 / 故障前的会话总数) * 100%
```

可以通过以下查询获取会话数：

```sql
-- 故障前的会话总数
select count(*) from gv$session where type = 'USER';

-- 故障后成功连接的会话数
select count(*) from gv$session where type = 'USER';
```

服务连续性验证标准：
- 连接恢复率应接近100%（取决于配置的TAF策略）
- 服务中断时间应在可接受的范围内（通常小于60秒）
- 未提交的事务可能会回滚，但不应导致数据不一致

#### 7.5.4 性能影响验证

比较故障前、故障期间和故障后的性能指标：

```bash
# 分析Swingbench结果
grep "Transactions per Minute" /home/oracle/rac_test/logs/swingbench_*.log

# 分析响应时间
grep "Average Response Time" /home/oracle/rac_test/logs/swingbench_*.log
```

性能影响验证标准：
- 故障转移后的事务吞吐量应恢复到接近故障前的水平
- 响应时间可能在故障转移期间暂时增加，但应在故障转移完成后恢复
- 系统资源使用率（CPU、内存、I/O）应在可接受的范围内

#### 7.5.5 数据一致性验证

```sql
-- 检查数据库一致性
sqlplus / as sysdba
SQL> select * from v$database_block_corruption;
SQL> select * from v$nonlogged_block;
SQL> select * from dba_outstanding_alerts where reason like '%corrupt%';
```

数据一致性验证标准：
- 不应有数据块损坏
- 不应有未记录的数据块
- 不应有与数据损坏相关的警报

## 8. 结果分析与报告

### 8.1 性能指标分析

#### 8.1.1 AWR报告分析

AWR报告提供了数据库性能的详细信息，可以通过以下步骤分析：

1. 生成AWR报告：

```sql
sqlplus / as sysdba
SQL> @?/rdbms/admin/awrrpt.sql
```

2. 分析AWR报告中的关键部分：
   - 负载概况
   - 等待事件
   - 全局缓存统计信息
   - SQL语句性能
   - 系统统计信息

#### 8.1.2 Swingbench结果分析

Swingbench结果文件包含了测试期间的性能指标，可以通过以下方法分析：

1. 分析事务吞吐量：

```bash
grep "Transactions per Minute" /home/oracle/rac_test/logs/swingbench_*.log
```

2. 分析响应时间：

```bash
grep "Average Response Time" /home/oracle/rac_test/logs/swingbench_*.log
```

3. 分析错误率：

```bash
grep "Errors:" /home/oracle/rac_test/logs/swingbench_*.log
```

### 8.2 故障转移时间分析

#### 8.2.1 时间线分析

创建测试过程的时间线，标记关键事件：

1. 测试开始时间
2. 负载稳定时间
3. 节点故障时间
4. 故障检测时间
5. 故障转移完成时间
6. 服务恢复时间
7. 节点重新启动时间
8. 节点重新加入集群时间
9. 测试结束时间

#### 8.2.2 比较分析

比较不同测试场景的结果，分析以下方面的差异：

1. 故障检测时间
2. 故障转移时间
3. 服务中断时间
4. 连接恢复率
5. 性能影响
6. 错误率

### 8.3 测试报告模板

以下是测试结果报告的建议模板：

```
# Oracle 19c RAC三节点集群节点故障转移测试报告

## 测试概述
- 测试日期：[日期]
- 测试环境：[环境描述]
- 测试场景：[场景描述]
- 测试目标：[测试目标]

## 测试配置
- 节点数量：3
- 数据库版本：Oracle 19c
- 集群软件版本：Grid Infrastructure 19c
- Swingbench版本：[版本]
- 测试负载：[负载描述]

## 测试步骤
1. [步骤1]
2. [步骤2]
...

## 测试结果

### 故障检测和转移时间
- 故障发生时间：[时间]
- 故障检测时间：[时间]（延迟：[秒]）
- 故障转移完成时间：[时间]（总转移时间：[秒]）
- 服务恢复时间：[时间]（服务中断时间：[秒]）

### 连接恢复情况
- 故障前会话数：[数量]
- 故障后成功连接的会话数：[数量]
- 连接恢复率：[百分比]

### 性能影响
- 故障前平均TPS：[数值]
- 故障期间平均TPS：[数值]（下降：[百分比]）
- 故障后平均TPS：[数值]（恢复：[百分比]）
- 故障前平均响应时间：[毫秒]
- 故障期间平均响应时间：[毫秒]（增加：[百分比]）
- 故障后平均响应时间：[毫秒]（恢复：[百分比]）

### 错误统计
- 总错误数：[数量]
- 错误类型分布：
  - [错误类型1]：[数量]
  - [错误类型2]：[数量]
  ...

## 观察结果
- [观察1]
- [观察2]
...

## 结论和建议
- [结论1]
- [建议1]
...

## 附件
- AWR报告
- Swingbench结果文件
- 监控日志
```

## 9. 最佳实践与注意事项

### 9.1 测试环境准备最佳实践

1. **使用专用测试环境**：始终在非生产环境中执行测试，避免影响生产系统。

2. **环境一致性**：确保测试环境与生产环境尽可能相似，包括硬件配置、软件版本和网络拓扑。

3. **数据备份**：在执行测试前创建完整备份，以便在测试出现问题时能够恢复。

4. **资源规划**：确保有足够的磁盘空间存储日志和结果文件，避免因空间不足导致测试中断。

5. **权限检查**：确保测试账户具有足够的权限执行所有测试操作，包括停止和启动实例。

### 9.2 测试执行最佳实践

1. **渐进式测试**：从简单的测试场景开始，逐步增加复杂性，确保基本功能正常后再测试更复杂的场景。

2. **监控全面性**：同时监控操作系统、集群、数据库和应用程序层面，获取全面的性能和行为数据。

3. **时间同步**：确保所有节点的时钟同步，以便准确计算故障检测和故障转移时间。

4. **详细记录**：记录所有观察到的行为，包括预期和非预期的，以便后续分析。

5. **测试间隔**：在每个测试场景之间确保系统恢复到正常状态，避免前一个测试影响后续测试。

6. **参数一致性**：使用一致的测试参数以便比较结果，只改变要测试的变量。

7. **重复测试**：考虑在不同时间重复测试以验证结果的一致性。

### 9.3 常见问题与解决方案

#### 9.3.1 节点无法重新加入集群

**问题**：节点重启后无法重新加入集群。

**解决方案**：
- 检查集群互联网络连接
- 验证节点时钟同步
- 检查OCR和投票磁盘的访问权限
- 查看CRS日志中的错误信息
- 尝试手动启动CRS：`crsctl start crs`

#### 9.3.2 服务未自动故障转移

**问题**：节点故障后，服务未自动迁移到其他节点。

**解决方案**：
- 检查服务配置：`srvctl config service -d <db_name> -s <service_name>`
- 确认服务配置了自动故障转移：`-y AUTOMATIC`
- 检查服务的首选实例和可用实例配置
- 手动启动服务：`srvctl start service -d <db_name> -s <service_name>`

#### 9.3.3 性能下降严重

**问题**：故障转移后，性能下降严重且未恢复。

**解决方案**：
- 检查剩余节点的资源使用情况（CPU、内存、I/O）
- 验证实例参数配置是否适合处理增加的负载
- 检查是否有长时间运行的事务或会话
- 分析AWR报告中的等待事件和瓶颈
- 考虑调整服务器负载平衡策略

#### 9.3.4 连接恢复率低

**问题**：节点故障后，许多会话未能重新连接。

**解决方案**：
- 检查TAF配置
- 验证连接字符串中的故障转移参数
- 检查客户端错误日志
- 增加连接重试次数和间隔
- 考虑使用应用程序连接池

#### 9.3.5 测试工具问题

**问题**：Swingbench工具崩溃或报错。

**解决方案**：
- 检查Java版本兼容性
- 增加Java堆内存：`export JVM_ARGS="-Xms512m -Xmx2048m"`
- 验证Swingbench配置文件的语法
- 检查数据库连接和权限
- 尝试使用较低的并发用户数

## 10. 参考资源

- Oracle RAC文档：https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/index.html
- Oracle高可用性最佳实践：https://www.oracle.com/database/technologies/high-availability/ha-best-practices.html
- Swingbench文档：http://www.dominicgiles.com/swingbench.html
- Oracle性能诊断指南：https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/index.html
- Oracle RAC故障转移白皮书：https://www.oracle.com/technetwork/database/options/clustering/overview/maa-wp-rac-failover-11gr2-1-132337.pdf
