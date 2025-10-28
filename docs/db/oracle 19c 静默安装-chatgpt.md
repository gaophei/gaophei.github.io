下面给你一套在 **Oracle Linux Server 7.9（OL7.9）** 上**静默安装 Oracle Database 19c（单机、文件系统版）**的完整步骤，从系统准备、软件静默装、监听配置到 DBCA 静默建库与自启动配置，直接照抄即可。若你们用 ASM 或 RAC，流程会不同，这里只讲单机文件系统。

> 参考依据：Oracle 官方 19c 安装文档（含静默/响应文件说明）、Oracle Linux 的预安装 RPM 说明，以及 DBCA/NETCA 静默参数范例。文中关键点均附出处，便于你核对或深挖。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/using-response-files.html?utm_source=chatgpt.com))

------

# 0. 前置假设与命名

- 安装用户与组：`oracle:oinstall`（OSDBA 组：`dba`，其他可选组：`oper/backupdba/dgdba/kmdba/racdba`）
- 目录：
  - `ORACLE_BASE=/u01/app/oracle`
  - `ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1`
  - 软库目录（数据文件）：`/u01/app/oracle/oradata`
- CDB/SID：`orclcdb`，PDB：`orclpdb`
- 监听端口：`1521`，DB Express 端口：`5500`
- 介质：`LINUX.X64_193000_db_home.zip`（需登录 Oracle 官网下载）([Oracle](https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html?utm_source=chatgpt.com))

------

# 1. 系统准备（root）

1. 基本检查与网络名解析

```bash
cat /etc/os-release
hostnamectl set-hostname db19c.localdomain
echo "192.168.1.100 db19c.localdomain db19c" >> /etc/hosts   # 按你的IP调整
```

1. 关闭/宽松 SELinux 与开放端口（推荐 permissive）

```bash
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
# 开放监听与 DB Express
firewall-cmd --permanent --add-port=1521/tcp
firewall-cmd --permanent --add-port=5500/tcp
firewall-cmd --reload
```

1. 一键完成内核参数、资源限制、组与用户、依赖包（强烈建议）
    OL7 上安装 Oracle 的**预安装 RPM**：

```bash
yum install -y oracle-database-preinstall-19c
```

该 RPM 会（若不存在则）创建 `oracle` 用户与 `oinstall/dba` 等组，配置 `/etc/sysctl.d/*oracle*` 与 `/etc/security/limits.d/*oracle*` 的资源限制，并安装所需依赖，极大简化准备工作。若你有多个软件所有者账号，其他账号需手工配置内核参数与 limits。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/about-the-oracle-preinstallation-rpm.html?utm_source=chatgpt.com))

> 如果你不想用预安装 RPM，需要**手工**设置内核参数与 limits，并安装依赖包。Oracle 官方也推荐在 OL 上使用该 RPM。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/checking-resource-limits-for-oracle-software-installation-users.html?utm_source=chatgpt.com))

1. 创建目录并授权（若 preinstall 未自动创建或你要自定义路径）

```bash
mkdir -p /u01/app/oracle/product/19.3.0/dbhome_1
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/oracle/oradata
chown -R oracle:oinstall /u01
chmod -R 775 /u01
```

1. 常用工具

```bash
yum install -y unzip tar ksh libaio
```

------

# 2. 准备介质（oracle）

1. 将 `LINUX.X64_193000_db_home.zip` 上传到服务器（建议放到 `/u01`）。
2. 解压到 `ORACLE_HOME`：

```bash
su - oracle
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
cd /u01
unzip LINUX.X64_193000_db_home.zip -d $ORACLE_HOME
```

> 19c 的 zip 介质是**解压即为 ORACLE_HOME** 的结构。([Oracle](https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html?utm_source=chatgpt.com))

------

# 3. 静默安装数据库软件（不建库）

1. 准备响应文件（基于官方模板）
    模板路径：`$ORACLE_HOME/install/response/db_install.rsp`。核心项如下（可直接写入新文件 `$HOME/db_install.rsp`）：

```properties
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
SELECTED_LANGUAGES=en,zh_CN
ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=false
```

> 静默/响应文件安装的字段说明，见官方“Using Response Files”。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/using-response-files.html?utm_source=chatgpt.com))

1. 先跑**仅先决条件检查**（可选、推荐）

```bash
cd $ORACLE_HOME
./runInstaller -silent -responseFile /home/oracle/db_install.rsp -executePrereqs -waitforcompletion
```

1. 开始安装

```bash
./runInstaller -silent -responseFile /home/oracle/db_install.rsp -ignorePrereqFailure -waitforcompletion
```

安装完成后，终端会提示以 **root** 执行两个脚本：

```bash
# root 执行
/u01/app/oraInventory/orainstRoot.sh
/u01/app/oracle/product/19.3.0/dbhome_1/root.sh
```

------

# 4. 配置监听（NETCA 静默）

你可以用响应文件或直接用参数创建一个标准监听。最简单方式：

```bash
su - oracle
netca -silent -createListener -listenerName LISTENER -port 1521
lsnrctl status
```

> NETCA 支持采用响应文件或命令行参数在静默模式下创建并启动监听。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/riwin/running-oracle-net-configuration-assistant-using-response-files.html?utm_source=chatgpt.com))

------

# 5. 静默建库（DBCA）

## 5.1 创建 CDB + 1 个 PDB（推荐，19c 缺省形态）

```bash
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbname orclcdb -sid orclcdb \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName orclpdb \
  -sysPassword 'SysPassw0rd!' \
  -systemPassword 'SystemPassw0rd!' \
  -pdbAdminPassword 'PdbAdminPassw0rd!' \
  -datafileDestination '/u01/app/oracle/oradata' \
  -storageType FS \
  -characterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -totalMemory 4096 \
  -redoLogFileSize 200 \
  -emConfiguration DBEXPRESS -dbExpressPort 5500
```

完成后日志在：`$ORACLE_BASE/cfgtoollogs/dbca/<DB_NAME>/`。

> DBCA 的静默参数与示例见官方与业界说明。([oracle-base.com](https://oracle-base.com/articles/misc/database-configuration-assistant-dbca-silent-mode?utm_source=chatgpt.com))

## 5.2 如需**非 CDB**（不推荐，19c 起已不鼓励）

在上面的命令里把 `-createAsContainerDatabase true` 改成 `false` 即可（仅在仍需兼容旧应用时考虑）。([oracle-base.com](https://oracle-base.com/articles/misc/database-configuration-assistant-dbca-silent-mode?utm_source=chatgpt.com))

------

# 6. 环境变量与本地连接（oracle）

把这些加进 `~/.bash_profile`：

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1
export ORACLE_SID=orclcdb
export PATH=$PATH:$ORACLE_HOME/bin
```

使之生效并验证：

```bash
. ~/.bash_profile
sqlplus / as sysdba
-- CDB 模式查看 PDB
show pdbs
```

------

# 7. 设置开机自启动（Oracle Linux 7 / systemd）

1. 确保 `/etc/oratab` 把该实例的末尾标记设为 `Y`：

```
orclcdb:/u01/app/oracle/product/19.3.0/dbhome_1:Y
```

1. 新建 systemd 单元（以 oracle 用户运行）：
    `/etc/systemd/system/oracle-rdbms.service`

```ini
[Unit]
Description=Oracle Database and Listener
After=network.target

[Service]
Type=forking
User=oracle
ExecStart=/bin/bash -lc "$ORACLE_HOME/bin/lsnrctl start; $ORACLE_HOME/bin/dbstart $ORACLE_HOME"
ExecStop=/bin/bash -lc "$ORACLE_HOME/bin/dbshut $ORACLE_HOME; $ORACLE_HOME/bin/lsnrctl stop"
Restart=on-failure
TimeoutSec=300
Environment=ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1
Environment=ORACLE_BASE=/u01/app/oracle

[Install]
WantedBy=multi-user.target
```

启用并测试：

```bash
systemctl daemon-reload
systemctl enable --now oracle-rdbms
systemctl status oracle-rdbms
```

------

# 8. 常见问题速排

- **先决条件告警/依赖包缺失**：优先用 `oracle-database-preinstall-19c`，它会装依赖、设 limits 与内核参数，并（若需）创建 oracle 用户与组。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/about-the-oracle-preinstallation-rpm.html?utm_source=chatgpt.com))
- **监听起不来**：确认 1521 端口已放行、`listener.ora` 主机名能解析、`lsnrctl status` 查看报错；必要时用 `netca -silent -deletelistener LISTENER && netca -silent -createListener ...` 重建。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/riwin/running-oracle-net-configuration-assistant-using-response-files.html?utm_source=chatgpt.com))
- **DBCA 失败**：看 `$ORACLE_BASE/cfgtoollogs/dbca/*/`；磁盘空间/权限/字符集/内存参数是常见原因。DBCA 静默参数可用 `dbca -silent -help` 查看。([oracle-base.com](https://oracle-base.com/articles/misc/database-configuration-assistant-dbca-silent-mode?utm_source=chatgpt.com))
- **THP/NUMA**：预安装 RPM 会按推荐关闭 NUMA 并设置相关内核项；若你手工配，记得处理透明大页与 NUMA。([Oracle 文档](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/about-the-oracle-preinstallation-rpm.html?utm_source=chatgpt.com))

------

# 9. 之后你可能还要做

- 打 RU / RUR 补丁（opatchauto / opatch）
- 配置归档/备份目录、FRA、AWR/ADRC 清理
- 设监听 TCPS / VALID_NODE_CHECKING 注册白名单
- 监控接入（比如用 DB Express：`https://<host>:5500/`）

------

如果你告诉我你们机器的 **内存/CPU/磁盘布局** 和 **期望的 SGA/PGA/字符集/PDB 数量**，我可以把第 5 步的 DBCA 命令替你**精确到位**（比如总内存与数据文件放置策略等），并给一个**一键安装脚本**。