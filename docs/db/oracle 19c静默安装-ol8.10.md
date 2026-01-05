# Oracle 19c Silent Installation on Oracle Linux 8.10

Here's a comprehensive guide for silently installing Oracle 19c with CDB and PDB on your Oracle Linux 8.10 system.

------

## Phase 1: System Preparation

### 1.1 Configure Hostname and Hosts File

```bash
# Set hostname
hostnamectl set-hostname oracledb

# Update /etc/hosts
cat >> /etc/hosts <<EOF
$(hostname -I | awk '{print $1}')  oracledb oracledb.localdomain
EOF
```

### 1.2 Disable SELinux and Firewall (for lab environment)

```bash
# Disable SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0

# Disable firewall (or open ports 1521, 5500)
systemctl stop firewalld
systemctl disable firewalld

systemctl status firewalld
```

### 1.3 Install Oracle Preinstall Package

This package automatically configures kernel parameters, creates the oracle user, and installs dependencies:

```bash
# Install Oracle 19c preinstall package
# 会自动安装依赖包、创建99-oracle-database-preinstall-19c-sysctl.conf、创建Oracle用户
dnf install -y oracle-database-preinstall-19c

#dnf install -y bc binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libxcb libX11 libXau libXi libXtst libXrender libXrender-devel make net-tools nfs-utils smartmontools sysstat unixODBC unixODBC-devel unzip
```

### 1.4 Set Oracle User Password

```bash
echo "I26[Y,)SSQ11" | passwd --stdin oracle
```

#默认不执行，如果preinstall没有创建oracle用户时，手动创建

```bash
id oracle

groupadd -g 54321 oinstall
groupadd -g 54322 dba
groupadd -g 54323 oper
groupadd -g 54324 backupdba
groupadd -g 54325 dgdba
groupadd -g 54326 kmdba
groupadd -g 54327 asmdba
groupadd -g 54328 asmoper
groupadd -g 54329 asmadmin
groupadd -g 54330 racdba

useradd -u 54321 -g oinstall -G dba,oper,backupdba,dgdba,kmdba,racdba oracle
```

### 1.5 Set Kernel Parameters

#可以手动创建或者修改以下文件

#### Create /etc/sysctl.d/97-oracle-database-sysctl.conf

```bash
cat > /etc/sysctl.d/97-oracle-database-sysctl.conf << EOF
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_interval=60
net.ipv4.neigh.default.gc_stale_time=120

# 参考 https://github.com/prometheus/node_exporter#disabled-by-default
kernel.perf_event_paranoid=-1

#sysctls for k8s node config
net.ipv4.tcp_slow_start_after_idle=0
fs.inotify.max_user_watches=524288
kernel.softlockup_all_cpu_backtrace=1

kernel.softlockup_panic=0

kernel.watchdog_thresh=30
fs.inotify.max_user_instances=8192
fs.inotify.max_queued_events=16384
vm.max_map_count=262144
net.core.netdev_max_backlog=16384
net.ipv4.tcp_wmem=4096 12582912 16777216
net.core.somaxconn=32768
net.ipv4.ip_forward=1
net.ipv4.tcp_max_syn_backlog=8096
net.ipv4.tcp_rmem=4096 12582912 16777216

###如果学校开启IPv6，则必须为0
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

kernel.yama.ptrace_scope=0
vm.swappiness=10

# 可以控制core文件的文件名中是否添加pid作为扩展。
kernel.core_uses_pid=1

# Do not accept source routing
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0

# Promote secondary addresses when the primary address is removed
net.ipv4.conf.default.promote_secondaries=1
net.ipv4.conf.all.promote_secondaries=1

# Enable hard and soft link protection
fs.protected_hardlinks=1
fs.protected_symlinks=1
# 源路由验证
# see details in https://help.aliyun.com/knowledge_detail/39428.html
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2
# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_synack_retries=2
kernel.sysrq=1


fs.aio-max-nr = 3145728
fs.file-max = 6815744
kernel.shmall = 7031250
kernel.shmmax = 28800000000
kernel.shmmni = 4096
kernel.sem = 6144 50331648 4096 8192
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 4194304
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

# Huge Pages Settings (Optional - for large SGA)
# vm.nr_hugepages = 12288
EOF

# Apply the settings
sysctl --system
```



#### Set shell limits for oracle user

```bash
cat > /etc/security/limits.d/oracle-database-server-19c-preinstall.conf << EOF
oracle   soft   nofile   65536
oracle   hard   nofile   65536
oracle   soft   nproc    16384
oracle   hard   nproc    16384
oracle   soft   stack    10240
oracle   hard   stack    32768
oracle   soft   memlock  134217728
oracle   hard   memlock  134217728
EOF
```







### 1.6 Create Directory Structure

```bash
# Create Oracle directories
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
mkdir -p /u01/app/oraInventory
#mkdir -p /u01/oradata
#mkdir -p /u01/recovery

# Set ownership
chown -R oracle:oinstall /u01
chmod -R 775 /u01
```

------

## Phase 2: Configure Oracle Environment

### 2.1 Set Environment Variables for Oracle User

```bash
#su - oracle
cat >> /home/oracle/.bash_profile << 'EOF'
export TMP=/tmp
export TMPDIR=$TMP

export CV_ASSUME_DISTID=OEL8.1

export ORACLE_HOSTNAME=backup
export ORACLE_UNQNAME=ORCL
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL

export PATH=/usr/sbin:/usr/local/bin:$PATH
export PATH=$ORACLE_HOME/bin:$PATH

export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

source /home/oracle/.bash_profile
exit
```



```bash
cat >> /home/oracle/.bash_profile <<'EOF'

# Oracle Environment Variables
export CV_ASSUME_DISTID=OEL8.1

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.3.0/dbhome_1
export ORACLE_SID=orcl
export ORACLE_UNQNAME=orcl
export PDB_NAME=orclpdb

export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

# Aliases
alias sqlplus='rlwrap sqlplus'
alias rman='rlwrap rman'
EOF

source /home/oracle/.bash_profile
```

------

## Phase 3: Download and Extract Oracle Software

### 3.1 Download Oracle 19c

```bash
# As root, download Oracle 19c (you need to download from Oracle website with your account)
# Download `LINUX.X64_193000_db_home.zip` from [Oracle Technology Network](https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html) and upload to the server.

# Place the file LINUX.X64_193000_db_home.zip in /tmp/

# Change ownership
chown oracle:oinstall /tmp/LINUX.X64_193000_db_home.zip
```

### 3.2 Extract to ORACLE_HOME

```bash
# Switch to oracle user
su - oracle

# Extract directly to ORACLE_HOME (Oracle 19c requirement)
cd $ORACLE_HOME
unzip -oq /tmp/LINUX.X64_193000_db_home.zip
```

------

## Phase 4: Silent Installation of Oracle Software

### 4.1 Create Response File for Software Installation

#### 4.1.1 non-CDB模式

```bash
cat > /tmp/db_install.rsp << 'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=false
oracle.install.db.ConfigureAsContainerDB=false
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
oracle.install.db.config.starterdb.globalDBName=ORCL
oracle.install.db.config.starterdb.SID=ORCL
oracle.install.db.config.starterdb.characterSet=AL32UTF8
oracle.install.db.config.starterdb.memoryOption=false
oracle.install.db.config.starterdb.installExampleSchemas=false
oracle.install.db.config.starterdb.managementOption=DEFAULT
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
EOF

chown oracle:oinstall /tmp/db_install.rsp
```



#### 4.1.2 CDB/PDB模式

```bash
cat > /tmp/db_install.rsp << 'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=false
oracle.install.db.ConfigureAsContainerDB=true
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
oracle.install.db.config.starterdb.globalDBName=ORCL
oracle.install.db.config.starterdb.SID=ORCL
oracle.install.db.config.starterdb.characterSet=AL32UTF8
oracle.install.db.config.starterdb.memoryOption=false
oracle.install.db.config.starterdb.installExampleSchemas=false
oracle.install.db.config.starterdb.managementOption=DEFAULT
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
EOF

chown oracle:oinstall /tmp/db_install.rsp
```

### 4.2 Run Silent Installation

```bash
# As oracle user
su - oracle

cd $ORACLE_HOME

# Set the environment variable
export CV_ASSUME_DISTID=OEL8.1

# 仅先决条件检查
./runInstaller -silent -responseFile /tmp/db_install.rsp -executePrereqs -waitforcompletion

# 开始静默安装
./runInstaller -silent -responseFile /tmp/db_install.rsp -ignorePrereqFailure -waitForCompletion
```



#logs

```bash
#由于Oracle 19c (19.3) 发布的年份（2019年）早于 Oracle Linux 8.10，如果不设置 export CV_ASSUME_DISTID=OEL8.1，会报错
[oracle@backup dbhome_1]$ ./runInstaller -silent -responseFile /tmp/db_install.rsp -executePrereqs -waitforcompletion
Launching Oracle Database Setup Wizard...
[oracle@backup dbhome_1]$ ./runInstaller -silent -responseFile /tmp/db_install.rsp -ignorePrereqFailure -waitForCompletion
Launching Oracle Database Setup Wizard...
[WARNING] [INS-08101] Unexpected error while executing the action at state: 'supportedOSCheck'
   CAUSE: No additional information available.
   ACTION: Contact Oracle Support Services or refer to the software manual.
   SUMMARY:
       - java.lang.NullPointerException
Moved the install session logs to:
 /u01/app/oraInventory/logs/InstallActions2025-12-29_11-12-41AM
[oracle@backup dbhome_1]$ cat /u01/app/oraInventory/logs/InstallActions2025-12-29_11-12-41AM/installActions2025-12-29_11-12-41AM.log
...........
INFO:  [Dec 29, 2025 11:12:42 AM] Completed background operations
WARNING:  [Dec 29, 2025 11:12:42 AM] [WARNING] [INS-08101] Unexpected error while executing the action at state: 'supportedOSCheck'
   CAUSE: No additional information available.
   ACTION: Contact Oracle Support Services or refer to the software manual.
   SUMMARY:
       - java.lang.NullPointerException.
Refer associated stacktrace #oracle.install.commons.util.exception.AbstractErrorAdvisor:479
INFO:  [Dec 29, 2025 11:12:42 AM] Advice is CONTINUE
INFO:  [Dec 29, 2025 11:12:42 AM] Adding ExitStatus FAILURE to the exit status set
INFO:  [Dec 29, 2025 11:12:42 AM] Finding the most appropriate exit status for the current application
INFO:  [Dec 29, 2025 11:12:42 AM] The inventory does not exist, but the location of the inventory is known: /u01/app/oraInventory
INFO:  [Dec 29, 2025 11:12:42 AM] Finding the most appropriate exit status for the current application
INFO:  [Dec 29, 2025 11:12:42 AM] Exit Status is -1
INFO:  [Dec 29, 2025 11:12:42 AM] Shutdown Oracle Database 19c Installer
INFO:  [Dec 29, 2025 11:12:42 AM] Unloading Setup Driver
[oracle@backup InstallActions2025-12-29_11-12-41AM]$ cat /etc/os-release
NAME="Oracle Linux Server"
VERSION="8.10"
ID="ol"
ID_LIKE="fedora"
VARIANT="Server"
VARIANT_ID="server"
VERSION_ID="8.10"
PLATFORM_ID="platform:el8"
PRETTY_NAME="Oracle Linux Server 8.10"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:oracle:linux:8:10:server"
HOME_URL="https://linux.oracle.com/"
BUG_REPORT_URL="https://github.com/oracle/oracle-linux"
ORACLE_BUGZILLA_PRODUCT="Oracle Linux 8"
ORACLE_BUGZILLA_PRODUCT_VERSION=8.10
ORACLE_SUPPORT_PRODUCT="Oracle Linux"
ORACLE_SUPPORT_PRODUCT_VERSION=8.10
```

#正确执行过程Logs

```bash
[oracle@backup dbhome_1]$ export CV_ASSUME_DISTID=OEL8.1
[oracle@backup dbhome_1]$ ./runInstaller -silent -responseFile /tmp/db_install.rsp -executePrereqs -waitforcompletion
Launching Oracle Database Setup Wizard...

Prerequisite checks executed successfully.
Moved the install session logs to:
 /u01/app/oraInventory/logs/InstallActions2025-12-29_11-17-30AM

[oracle@backup dbhome_1]$ ./runInstaller -silent -responseFile /tmp/db_install.rsp -ignorePrereqFailure
Launching Oracle Database Setup Wizard...

[WARNING] [INS-32047] The location (/u01/app/oraInventory) specified for the central inventory is not empty.
   ACTION: It is recommended to provide an empty location for the inventory.
The response file for this session can be found at:
 /u01/app/oracle/product/19.0.0/dbhome_1/install/response/db_2025-12-29_03-45-44PM.rsp

You can find the log of this install session at:
 /tmp/InstallActions2025-12-29_03-45-44PM/installActions2025-12-29_03-45-44PM.log

As a root user, execute the following script(s):
        1. /u01/app/oraInventory/orainstRoot.sh
        2. /u01/app/oracle/product/19.0.0/dbhome_1/root.sh

Execute /u01/app/oraInventory/orainstRoot.sh on the following nodes:
[backup]
Execute /u01/app/oracle/product/19.0.0/dbhome_1/root.sh on the following nodes:
[backup]


Successfully Setup Software.
Moved the install session logs to:
 /u01/app/oraInventory/logs/InstallActions2025-12-29_03-45-44PM
[oracle@backup dbhome_1]$

```





#设置swap分区

```bash
# 1. Create a 32GB swap file
#sudo fallocate -l 32G /swapfile 
sudo dd if=/dev/zero of=/swapfile bs=1G count=32 status=progress

# 2. Set proper permissions
sudo chmod 600 /swapfile

# 3. Format as swap
sudo mkswap /swapfile

# 4. Enable the swap
sudo swapon /swapfile

# 5. Verify it's active
free -m


# 6. Add to /etc/fstab
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# 7. Verify Final Configuration
free -m
swapon --show
```

```bash
sudo chmod 600 /swapfile          && \
sudo mkswap /swapfile             && \
sudo swapon /swapfile             && \
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```



### 4.3 Run Root Scripts (as root)

```bash
# Switch to root and run:
/u01/app/oraInventory/orainstRoot.sh
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

------

#logs

```bash
[root@backup ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@backup ~]#  /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
Check /u01/app/oracle/product/19.0.0/dbhome_1/install/root_backup_2025-12-29_15-48-10-775968449.log for the output of root script
[root@backup ~]#

[root@backup ~]# cat /u01/app/oracle/product/19.0.0/dbhome_1/install/root_backup_2025-12-29_15-48-10-775968449.log
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Oracle Trace File Analyzer (TFA) is available at : /u01/app/oracle/product/19.0.0/dbhome_1/bin/tfactl
```





## Phase 5: Silent Database Creation 

### 5.1 ***non-CDB***

### Create DBCA Response File

```bash
# As oracle user
su - oracle

# Create response file for database creation
cat > /tmp/dbca_noncdb.rsp << 'EOF'
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_19.0.0
gdbName=ORCL
sid=ORCL
databaseConfigType=SI
createAsContainerDatabase=false
templateName=General_Purpose.dbc
sysPassword=Oracle123
systemPassword=Oracle123
emConfiguration=NONE
datafileDestination=/u01/app/oracle/oradata
storageType=FS
characterSet=AL32UTF8
nationalCharacterSet=AL16UTF16
automaticMemoryManagement=false
totalMemory=24576
EOF

# Run DBCA silent mode
dbca -silent -createDatabase -responseFile /tmp/dbca_noncdb.rsp
```

### 5.2 CDB + PDB

```bash
# As oracle user
su - oracle

# Create response file for CDB with multiple PDBs
cat > /tmp/dbca_cdb.rsp << 'EOF'
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_19.0.0
gdbName=ORCL
sid=ORCL
databaseConfigType=SI
# Enable Container Database
createAsContainerDatabase=true
# Number of PDBs to create initially
numberOfPDBs=1
# PDB Name Prefix (will create AUTHX1, AUTHX2, AUTHX3)
pdbName=AUTHX
# Use PDB file name conversion (OMF style)
useLocalUndoForPDBs=true
# Admin user for all PDBs
pdbAdminPassword=Mj925qas6JD
templateName=General_Purpose.dbc
sysPassword=Mj925qas6JD
systemPassword=Mj925qas6JD
emConfiguration=NONE
datafileDestination=/u01/app/oracle/oradata
recoveryAreaDestination=/u01/app/oracle/fast_recovery_area
storageType=FS
characterSet=AL32UTF8
nationalCharacterSet=AL16UTF16
automaticMemoryManagement=false
# Memory optimized for 32GB system with CDB
totalMemory=24576
initParams=sga_target=18G,pga_aggregate_target=6G,processes=2000,open_cursors=1000,db_block_size=8192,log_buffer=256M,enable_pluggable_database=true,max_pdbs=252
listeners=LISTENER
sampleSchema=false
EOF

# Run DBCA silent mode to create CDB with PDBs
dbca -silent -createDatabase -responseFile /tmp/dbca_cdb.rsp
```

**Expected Output:**

```
Prepare for db operation
10% complete
Copying database files
40% complete
Creating and starting Oracle instance
42% complete
...
100% complete
Database creation complete. For details check the logfiles at:
 /u01/app/oracle/cfgtoollogs/dbca/orcl
Database Information:
Global Database Name:orcl
System Identifier(SID):orcl
Look at the log file "/u01/app/oracle/cfgtoollogs/dbca/orcl/orcl.log" for further details.
```

------

#logs

```bash
[oracle@backup dbhome_1]$ dbca -silent -createDatabase -responseFile /tmp/dbca_cdb.rsp
Prepare for db operation
8% complete
Copying database files
31% complete
Creating and starting Oracle instance
32% complete
36% complete
40% complete
43% complete
46% complete
Completing Database Creation
51% complete
53% complete
54% complete
Creating Pluggable Databases
58% complete
77% complete
Executing Post Configuration Actions
100% complete
Database creation complete. For details check the logfiles at:
 /u01/app/oracle/cfgtoollogs/dbca/ORCL.
Database Information:
Global Database Name:ORCL
System Identifier(SID):ORCL
Look at the log file "/u01/app/oracle/cfgtoollogs/dbca/ORCL/ORCL.log" for further details.
[oracle@backup dbhome_1]$
```



## Phase 6: Configure Listener

### 6.1 Create Listener Using netca (Silent)

```bash
cat > /tmp/netca_listener.rsp << 'EOF'
[GENERAL]
RESPONSEFILE_VERSION="19.0"
CREATE_TYPE="CUSTOM"

[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"LISTENER"}
LISTENER_PROTOCOLS={"TCP;1521"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;1521"}
EOF

netca -silent -responseFile /tmp/netca_listener.rsp
```

#logs

```bash
[oracle@backup dbhome_1]$ cat /tmp/netca_listener.rsp
RESPONSEFILE_VERSION="19.0"
CREATE_TYPE="CUSTOM"

[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"LISTENER"}
LISTENER_PROTOCOLS={"TCP;1521"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;1521"}
[oracle@backup dbhome_1]$ netca -silent -responseFile /tmp/netca_listener.rsp

Parsing command line arguments:
    Parameter "silent" = true
    Parameter "responsefile" = /tmp/netca_listener.rsp
Done parsing command line arguments.
Oracle Net Services Configuration:
Profile configuration complete.
Oracle Net Listener Startup:
    Running Listener Control:
      /u01/app/oracle/product/19.0.0/dbhome_1/bin/lsnrctl start LISTENER
    Listener Control complete.
    Listener started successfully.
Listener configuration complete.
Oracle Net Services configuration successful. The exit code is 0

[oracle@backup dbhome_1]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 29-DEC-2025 16:14:34

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=backup)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                29-DEC-2025 16:14:03
Uptime                    0 days 0 hr. 0 min. 31 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/dbhome_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/backup/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=backup)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
The listener supports no services
The command completed successfully
[oracle@backup dbhome_1]$

```



### 6.2 Or Create Listener Manually

```bash
# As oracle user
mkdir -p $ORACLE_HOME/network/admin
cd $ORACLE_HOME/network/admin

# Create listener.ora file
cat > listener.ora << 'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = backup)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

ADR_BASE_LISTENER = /u01/app/oracle
EOF

# Create sqlnet.ora file
cat > sqlnet.ora << 'EOF'
NAMES.DIRECTORY_PATH= (TNSNAMES, EZCONNECT)
EOF

# Start the listener
lsnrctl start

# Check listener status
lsnrctl status
```

### 6.3 Create tnsnames.ora

```bash
cat > $ORACLE_HOME/network/admin/tnsnames.ora << EOF

LISTENER_ORCL =
  (ADDRESS = (PROTOCOL = TCP)(HOST = $(hostname))(PORT = 1521))
  
# CDB Connection
ORCL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = $(hostname))(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL)
    )
  )

# PDB Connections
AUTHX =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = $(hostname))(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = AUTHX)
    )
  )
EOF
```

### 6.4 Start Listener

```bash
lsnrctl start
lsnrctl status
```

------

## Phase 7: Post-Installation Configuration

### 7.1 Verify Database Status

```bash
sqlplus / as sysdba <<EOF
SELECT name, open_mode, cdb FROM v\$database;
SELECT con_id, name, open_mode FROM v\$pdbs;
SHOW pdbs;
EOF
```

**Expected Output:**

```
NAME      OPEN_MODE            CDB
--------- -------------------- ---
ORCL      READ WRITE           YES

    CON_ID NAME                 OPEN_MODE
---------- -------------------- ----------
         2 PDB$SEED             READ ONLY
         3 ORCLPDB              READ WRITE
```

### 7.2 Set PDB to Auto-Open on Startup

#### 7.2.1 设置/etc/oratab

```bash
# As root, change the oratab file
vi /etc/oratab

ORCL:/u01/app/oracle/product/19.0.0/dbhome_1:Y

# Or use sed to fix it
sed -i 's/^ORCL:.*:N$/ORCL:\/u01\/app\/oracle\/product\/19.0.0\/dbhome_1:Y/' /etc/oratab

# Verify the change
grep "^ORCL" /etc/oratab
```



#### 7.2.2 non-CDB

```bash
# As root
cat > /etc/systemd/system/oracle-database.service << 'EOF'
[Unit]
Description=Oracle Database Service
After=network.target

[Service]
Type=forking
User=oracle
Group=oinstall
ExecStart=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbstart /u01/app/oracle/product/19.0.0/dbhome_1
ExecStop=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbshut /u01/app/oracle/product/19.0.0/dbhome_1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Edit /etc/oratab to enable auto-start
sed -i 's/:N$/:Y/' /etc/oratab

# Enable service
systemctl daemon-reload
systemctl enable oracle-database.service
```

#### 7.2.3 CDB/PDB mode
```bash
# Create startup trigger for PDBs (as oracle user)
sqlplus / as sysdba << ‘EOF’
CREATE OR REPLACE TRIGGER open_all_pdbs
  AFTER STARTUP 
  ON DATABASE
BEGIN
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
END open_all_pdbs;
/
EXIT;
EOF

# Update the systemd service (as root)
cat > /etc/systemd/system/oracle-database.service << 'EOF'
[Unit]
Description=Oracle Database CDB Service
After=network.target

[Service]
Type=forking
User=oracle
Group=oinstall
Environment="ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1"
Environment="ORACLE_SID=ORCL"
ExecStart=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbstart /u01/app/oracle/product/19.0.0/dbhome_1
ExecStartPost=/bin/bash -c 'sleep 10; echo "ALTER PLUGGABLE DATABASE ALL OPEN;" | /u01/app/oracle/product/19.0.0/dbhome_1/bin/sqlplus -S / as sysdba'
ExecStop=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbshut /u01/app/oracle/product/19.0.0/dbhome_1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable oracle-database.service
```

```bash
sqlplus / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;
EOF
```







### 7.3 Create Oracle Systemd Service

```bash
# As root
cat > /etc/systemd/system/oracle-database.service <<EOF
[Unit]
Description=Oracle Database Service
After=network.target

[Service]
Type=forking
User=oracle
Group=oinstall
Environment="ORACLE_BASE=/u01/app/oracle"
Environment="ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1"
Environment="ORACLE_SID=orcl"
ExecStart=/u01/app/oracle/product/19.3.0/dbhome_1/bin/dbstart /u01/app/oracle/product/19.3.0/dbhome_1
ExecStop=/u01/app/oracle/product/19.3.0/dbhome_1/bin/dbshut /u01/app/oracle/product/19.3.0/dbhome_1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Configure oratab for auto-start
sed -i 's/:N$/:Y/' /etc/oratab

# Enable and start service
systemctl daemon-reload
systemctl enable oracle-database
systemctl start oracle-database
```

------

## Phase 8: Verification

### 8.1 Complete Verification Script

```bash
su - oracle

sqlplus / as sysdba <<EOF
-- Database info
SELECT name, created, log_mode, open_mode FROM v\$database;

-- Instance info
SELECT instance_name, status, version_full FROM v\$instance;

-- PDB info
SELECT con_id, name, open_mode, total_size/1024/1024 AS size_mb FROM v\$pdbs;

-- Tablespace info
SELECT tablespace_name, 
       ROUND(SUM(bytes)/1024/1024) AS size_mb 
FROM dba_data_files 
GROUP BY tablespace_name;

-- Connect to PDB
ALTER SESSION SET container=orclpdb;
SELECT sys_context('USERENV','CON_NAME') AS current_container FROM dual;
EOF
```

### 8.2 Test Listener Connection

```bash
# Test CDB connection
sqlplus system/Oracle2024@orcl

# Test PDB connection  
sqlplus system/Oracle2024@orclpdb
```

------



## Phase 9: Post-Creation: Create Additional PDBs
After creating the CDB, you can add more PDBs:

### 9.1. Method 1: Using SQL*Plus

```bash
# As oracle user
sqlplus / as sysdba

-- Create additional PDBs from seed
CREATE PLUGGABLE DATABASE PDBDEV 
  ADMIN USER pdbadmin IDENTIFIED BY Oracle123
  CREATE_FILE_DEST='/u01/app/oracle/oradata';

CREATE PLUGGABLE DATABASE PDBTEST 
  ADMIN USER pdbadmin IDENTIFIED BY Oracle123
  CREATE_FILE_DEST='/u01/app/oracle/oradata';

CREATE PLUGGABLE DATABASE PDBUAT
  ADMIN USER pdbadmin IDENTIFIED BY Oracle123
  CREATE_FILE_DEST='/u01/app/oracle/oradata';

-- Open all PDBs
ALTER PLUGGABLE DATABASE ALL OPEN;

-- Save state so PDBs open automatically
ALTER PLUGGABLE DATABASE ALL SAVE STATE;

-- Verify PDBs
SELECT name, open_mode FROM v$pdbs;
SHOW pdbs;

EXIT;
```



### 9.2. Method 2: Using DBCA Silent Mode for Additional PDBs

```bash
# Create a new PDB in existing CDB
dbca -silent -createPluggableDatabase \
  -sourceDB ORCL \
  -pdbName PDBAPP \
  -pdbAdminUserName pdbadmin \
  -pdbAdminPassword Oracle123 \
  -createUserTableSpace true

# Clone an existing PDB
dbca -silent -createPluggableDatabase \
  -sourceDB ORCL \
  -pdbName PDBDEV2 \
  -createFromRemotePDB \
  -remotePDBName PDBDEV \
  -remoteDBConnString ORCL \
  -sysDBAUserName sys \
  -sysDBAPassword Oracle123 \
  -pdbAdminUserName pdbadmin \
  -pdbAdminPassword Oracle123
```





## Quick Reference Commands

| Task            | Command                                                  |
| --------------- | -------------------------------------------------------- |
| Start DB        | `sqlplus / as sysdba` → `startup`                        |
| Stop DB         | `sqlplus / as sysdba` → `shutdown immediate`             |
| Start Listener  | `lsnrctl start`                                          |
| Stop Listener   | `lsnrctl stop`                                           |
| Check DB Status | `sqlplus / as sysdba` → `SELECT status FROM v$instance;` |
| List PDBs       | `sqlplus / as sysdba` → `SHOW pdbs;`                     |
| Open PDB        | `ALTER PLUGGABLE DATABASE orclpdb OPEN;`                 |
| Connect to PDB  | `ALTER SESSION SET container=orclpdb;`                   |

------

## Summary

| Component           | Value                                   |
| ------------------- | --------------------------------------- |
| ORACLE_BASE         | /u01/app/oracle                         |
| ORACLE_HOME         | /u01/app/oracle/product/19.3.0/dbhome_1 |
| CDB Name (SID)      | orcl                                    |
| PDB Name            | orclpdb                                 |
| Listener Port       | 1521                                    |
| SYS/SYSTEM Password | Oracle2024                              |
| Character Set       | AL32UTF8                                |

This installation uses approximately 8GB RAM for the SGA/PGA, which is appropriate for your 32GB system. Let me know if you need help with any specific step or encounter any issues!