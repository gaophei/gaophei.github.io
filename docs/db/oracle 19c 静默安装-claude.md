I'll guide you through a detailed silent installation of Oracle Database 19c on Oracle Linux Server 7.9. Your system has adequate resources (31GB RAM, 32GB swap).

## 1. **Prerequisites and System Preparation**

### Set hostname and update /etc/hosts

```bash
hostnamectl set-hostname oracletest.localdomain
echo "$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -1) oracletest.localdomain oracletest" >> /etc/hosts
```

### Disable firewall and SELinux (for test environments)

```bash
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
setenforce 0
```

## 2. **Install Required Packages**

### Install Oracle Preinstall RPM

```bash
yum install -y oracle-database-preinstall-19c
yum install -y bc binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libxcb libX11 libXau libXi libXtst libXrender libXrender-devel make net-tools nfs-utils smartmontools sysstat unixODBC unixODBC-devel unzip
```

## 3. **Create Oracle User and Groups** (if not created by preinstall)

```bash
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
echo "I26[Y,)SSQ11" | passwd --stdin oracle
```

## 4. **Set Kernel Parameters**

### Create /etc/sysctl.d/97-oracle-database-sysctl.conf

```bash
cat > /etc/sysctl.d/97-oracle-database-sysctl.conf << EOF
# Async I/O - Increased for better I/O performance
fs.aio-max-nr = 3145728

# File handles - Adequate for 32GB system
fs.file-max = 6815744

# Shared Memory Settings - Optimized for 32GB RAM
# shmmax: 80% of physical RAM (25.6GB) for optimal Oracle SGA allocation
kernel.shmmax = 27487790694

# shmall: Total shared memory pages (shmmax/pagesize)
kernel.shmall = 6710886

# shmmni: Number of shared memory segments
kernel.shmmni = 4096

# Semaphores: SEMMSL SEMMNS SEMOPM SEMMNI
# Increased for better concurrency
kernel.sem = 250 64000 100 256

# Network Port Range - Increased range for more connections
net.ipv4.ip_local_port_range = 9000 65500

# Network Buffer Settings - Increased for better network performance
# Receive buffer default and max (1MB and 16MB)
net.core.rmem_default = 1048576
net.core.rmem_max = 16777216

# Send buffer default and max (1MB and 16MB)
net.core.wmem_default = 1048576
net.core.wmem_max = 16777216

# Optional: Additional network optimizations
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 1048576 16777216
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10

# Dirty page settings for better write performance
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100

# Swappiness - Reduce swapping for database server
vm.swappiness = 10

# Huge Pages Settings (Optional - for large SGA)
# vm.nr_hugepages = 12288
EOF

# Apply the settings
sysctl --system



```

```bash
cat > /etc/sysctl.d/97-oracle-database-sysctl.conf << EOF
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
vm.swappiness = 10
EOF


sysctl --system
```



### Set shell limits for oracle user

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

## 5. **Create Oracle Directories**

```bash
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
mkdir -p /u01/app/oraInventory
chown -R oracle:oinstall /u01
chmod -R 775 /u01
```

## 6. **Set Oracle User Environment**

```bash
su - oracle
cat >> ~/.bash_profile << 'EOF'
export TMP=/tmp
export TMPDIR=$TMP

export ORACLE_HOSTNAME=oracletest
export ORACLE_UNQNAME=ORCL
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL

export PATH=/usr/sbin:/usr/local/bin:$PATH
export PATH=$ORACLE_HOME/bin:$PATH

export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

source ~/.bash_profile
exit
```

## 7. **Download and Extract Oracle Software**

```bash
# As root, download Oracle 19c (you need to download from Oracle website with your account)
# Place the file LINUX.X64_193000_db_home.zip in /tmp/

# Change ownership
chown oracle:oinstall /tmp/LINUX.X64_193000_db_home.zip

# As oracle user
su - oracle
cd $ORACLE_HOME
unzip -q /tmp/LINUX.X64_193000_db_home.zip
```

## 8. **Create Response Files for Silent Installation**

### Database Software Installation Response File

### 8.1. non-CDB模式

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



### 8.2. CDB/PDB模式

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

## 9. **Run Silent Installation**

```bash
# As oracle user
su - oracle
cd $ORACLE_HOME

# 仅先决条件检查
./runInstaller -silent -responseFile /tmp/db_install.rsp -executePrereqs -waitforcompletion

# 开始静默安装
./runInstaller -silent -responseFile /tmp/db_install.rsp -ignorePrereqFailure
```

Wait for installation to complete (monitor the log file shown in output).

## 10. **Execute Root Scripts**

When installation prompts or completes, run as root:

```bash
su - root

/u01/app/oraInventory/orainstRoot.sh
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

## 11. **Create Listener**

### 11.1. Method 1: Create Listener Using Response File (Recommended)

```bash
# As oracle user
cd $ORACLE_HOME

# Create response file for listener
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
NAMING_METHODS={"TNSNAMES","EZCONNECT"}
EOF

# Run netca with response file
netca -silent -responseFile /tmp/netca_listener.rsp
```



### 11.2. Method 2: Quick Manual Configuration(Most Reliable)

````bash
# As oracle user
mkdir -p $ORACLE_HOME/network/admin
cd $ORACLE_HOME/network/admin

# Create listener.ora file
cat > listener.ora << 'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
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
````

### 11.3. Method 3: Start Default Listener  (Simplest)

```bash
# As oracle user
# This will create and start a default listener on port 1521
lsnrctl start

# Check if it's running
lsnrctl status

# If you get an error, first stop any existing listener
lsnrctl stop
lsnrctl start
```



## 12. **Create Database Using DBCA Silent Mode**

### 12.1. ***non-CDB***

```bash
# As oracle user
su - oracle

# Create response file for database creation
cat > /tmp/dbca.rsp << 'EOF'
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
dbca -silent -createDatabase -responseFile /tmp/dbca.rsp
```

### 12.2. ***CDB/PDB***

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

## 13. **Post-Creation: Create Additional PDBs**
After creating the CDB, you can add more PDBs:

### 13.1. Method 1: Using SQL*Plus
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
### 13.2. Method 2: Using DBCA Silent Mode for Additional PDBs
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
## 14. **Configure Automatic Startup** for CDB and All PDBs

### 设置/etc/oratab

```bash
# As root, change the oratab file
vi /etc/oratab

ORCL:/u01/app/oracle/product/19.0.0/dbhome_1:Y

# Or use sed to fix it
sed -i 's/^ORCL:.*:N$/ORCL:\/u01\/app\/oracle\/product\/19.0.0\/dbhome_1:Y/' /etc/oratab

# Verify the change
grep "^ORCL" /etc/oratab
```



### 14.1. non-CDB

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

### 14.2. CDB/PDB mode
```bash
# Create startup trigger for PDBs (as oracle user)
sqlplus / as sysdba << EOF
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

## 15.  **Create TNS Entries for PDBs**

```bash
# As oracle user
cat >> $ORACLE_HOME/network/admin/tnsnames.ora << 'EOF'

# CDB Connection
ORCL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL)
    )
  )

# PDB Connections
AUTHX =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
  
PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )

PDB2 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB2)
    )
  )

PDB3 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB3)
    )
  )

PDBDEV =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDBDEV)
    )
  )

PDBTEST =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracletest)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDBTEST)
    )
  )
EOF
```



## 16. **Verify Installation**

### 16.1. Verify non-CDB Installation

```bash
# As oracle user
su - oracle
sqlplus / as sysdba

SQL> SELECT instance_name, status FROM v$instance;
SQL> SELECT name, open_mode FROM v$database;
SQL> exit
```

### 16.2. Verify CDB/PDB Installation

```bash
# As oracle user
su - oracle

# Check CDB
sqlplus / as sysdba << EOF
-- Show container info
SHOW CON_NAME;
SHOW CON_ID;

-- List all PDBs
COL name FORMAT A20
SELECT con_id, name, open_mode FROM v\$pdbs ORDER BY con_id;

-- Show PDB details
COL pdb_name FORMAT A15
COL status FORMAT A10
SELECT pdb_name, status FROM dba_pdbs;

-- Check services
COL name FORMAT A30
SELECT name, pdb FROM v\$services ORDER BY pdb, name;
EXIT;
EOF

# Connect to specific PDB
sqlplus sys/Mj925qas6JD@localhost:1521/AUTHX as sysdba << EOF
SHOW CON_NAME;
SELECT tablespace_name FROM dba_tablespaces;
EXIT;
EOF

# Using Easy Connect to PDBs
sqlplus pdbadmin/Mj925qas6JD@localhost:1521/AUTHX
```

### 16.3. Key CDB/PDB Management Commands

```bash
-- Switch between containers
ALTER SESSION SET CONTAINER = PDB1;

-- Start/Stop specific PDB
ALTER PLUGGABLE DATABASE PDB1 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDB1 OPEN;

-- Start/Stop all PDBs
ALTER PLUGGABLE DATABASE ALL CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE ALL OPEN;

-- Save PDB state
ALTER PLUGGABLE DATABASE PDB1 SAVE STATE;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;

-- Create common user (in CDB$ROOT)
CREATE USER c##admin IDENTIFIED BY Oracle123 CONTAINER=ALL;
GRANT DBA TO c##admin CONTAINER=ALL;

-- Create local user (in PDB)
ALTER SESSION SET CONTAINER = PDB1;
CREATE USER appuser IDENTIFIED BY Oracle123;
GRANT CONNECT, RESOURCE TO appuser;
```



## 17. **The database is not starting automatically after reboot.**

The database is not starting automatically after reboot. The service shows as running but only the listener started, not the database itself.

### Step 1: Check and Fix /etc/oratab

```bash
# As root, check the oratab file
cat /etc/oratab

# It should have an entry like:
# ORCL:/u01/app/oracle/product/19.0.0/dbhome_1:Y

# If it shows :N at the end, change it to :Y
vi /etc/oratab
# Or use sed to fix it
sed -i 's/^ORCL:.*:N$/ORCL:\/u01\/app\/oracle\/product\/19.0.0\/dbhome_1:Y/' /etc/oratab

# Verify the change
grep "^ORCL" /etc/oratab
```

### Step 2: Test dbstart Script Manually

```bash
# Switch to oracle user
su - oracle

# Set environment
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

# Test dbstart manually
$ORACLE_HOME/bin/dbstart $ORACLE_HOME

# Check if database started
ps -ef | grep pmon
sqlplus / as sysdba << EOF
SELECT instance_name, status FROM v\$instance;
EXIT;
EOF
```

### Step 3: Fix the Systemd Service File

```bash
# As root, create an improved service file
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
Environment="PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/u01/app/oracle/product/19.0.0/dbhome_1/bin"

# Start listener first
ExecStartPre=/u01/app/oracle/product/19.0.0/dbhome_1/bin/lsnrctl start

# Start database
ExecStart=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbstart /u01/app/oracle/product/19.0.0/dbhome_1

# Wait and open PDBs
ExecStartPost=/bin/bash -c 'sleep 30; echo "ALTER PLUGGABLE DATABASE ALL OPEN;" | /u01/app/oracle/product/19.0.0/dbhome_1/bin/sqlplus -S / as sysdba'

# Stop database
ExecStop=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbshut /u01/app/oracle/product/19.0.0/dbhome_1

# Stop listener
ExecStopPost=/u01/app/oracle/product/19.0.0/dbhome_1/bin/lsnrctl stop

Restart=no
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload
```

### Step 4: Alternative - Create Custom Startup Script

```bash
# Create a custom startup script
cat > /u01/app/oracle/scripts/start_oracle.sh << 'EOF'
#!/bin/bash

# Set Oracle environment
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> /u01/app/oracle/scripts/startup.log
}

log_message "Starting Oracle Database startup process..."

# Start Listener
log_message "Starting Listener..."
$ORACLE_HOME/bin/lsnrctl start >> /u01/app/oracle/scripts/startup.log 2>&1

# Start Database
log_message "Starting Database..."
$ORACLE_HOME/bin/sqlplus -S / as sysdba << EOSQL >> /u01/app/oracle/scripts/startup.log 2>&1
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;
EXIT;
EOSQL

# Verify startup
sleep 10
if pgrep -x "ora_pmon_ORCL" > /dev/null
then
    log_message "Database started successfully"
else
    log_message "ERROR: Database failed to start"
    exit 1
fi

log_message "Oracle Database startup completed"
EOF

# Create stop script
cat > /u01/app/oracle/scripts/stop_oracle.sh << 'EOF'
#!/bin/bash

# Set Oracle environment
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

# Stop Database
$ORACLE_HOME/bin/sqlplus -S / as sysdba << EOSQL
SHUTDOWN IMMEDIATE;
EXIT;
EOSQL

# Stop Listener
$ORACLE_HOME/bin/lsnrctl stop
EOF

# Create scripts directory and set permissions
mkdir -p /u01/app/oracle/scripts
chown -R oracle:oinstall /u01/app/oracle/scripts
chmod 755 /u01/app/oracle/scripts/*.sh
```

### Step 5: Update Service to Use Custom Script

```bash
# Update systemd service to use custom script
cat > /etc/systemd/system/oracle-database.service << 'EOF'
[Unit]
Description=Oracle Database CDB Service
After=network.target

[Service]
Type=forking
User=oracle
Group=oinstall
ExecStart=/u01/app/oracle/scripts/start_oracle.sh
ExecStop=/u01/app/oracle/scripts/stop_oracle.sh
Restart=no
RemainAfterExit=yes
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
```

### Step 6: Test the Service

```bash
su - root

# Stop everything first
systemctl stop oracle-database.service
su - oracle -c "lsnrctl stop"
su - oracle -c "sqlplus / as sysdba << EOF
SHUTDOWN IMMEDIATE;
EXIT;
EOF"

# Start using systemd
systemctl start oracle-database.service

# Check status
systemctl status oracle-database.service

# Verify database is running
su - oracle -c "sqlplus / as sysdba << EOF
SELECT instance_name, status FROM v\$instance;
SELECT name, open_mode FROM v\$pdbs;
EXIT;
EOF"

# Check processes
ps -ef | grep pmon
ps -ef | grep listener
```

### Step 7: Enable Automatic PDB Opening (Database Level)

```bash
# As oracle user, create startup trigger
su - oracle
sqlplus / as sysdba << EOF
-- Create trigger to open PDBs automatically
CREATE OR REPLACE TRIGGER open_pdbs_after_startup
AFTER STARTUP ON DATABASE
BEGIN
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
END open_pdbs_after_startup;
/

-- Save PDB state
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;

-- Verify
COL name FORMAT A20
SELECT name, state FROM dba_pdb_saved_states;
EXIT;
EOF
```

### Step 8: Final Test - Reboot

```bash
# Ensure service is enabled
systemctl enable oracle-database.service

# Reboot the system
reboot

# After reboot, verify everything started
systemctl status oracle-database.service
ps -ef | grep pmon
ps -ef | grep listener

# Check database and PDBs
su - oracle
sqlplus / as sysdba << EOF
SELECT instance_name, status FROM v\$instance;
SHOW pdbs;
EXIT;
EOF
```

### Troubleshooting

If it still doesn't work, check:

```bash
# Check the startup log
cat /u01/app/oracle/scripts/startup.log

# Check system logs
journalctl -u oracle-database.service -n 50

# Check Oracle alert log
su - oracle
tail -100 $ORACLE_BASE/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log

# Manually test as oracle user
su - oracle
export ORAENV_ASK=NO
export ORACLE_SID=ORCL
. oraenv
sqlplus / as sysdba
STARTUP;
EXIT;
```

The custom script method (Steps 4-5) is usually the most reliable for automatic startup as it provides better control and logging.

## Post-Installation Tasks

1. **Set strong passwords** for SYS and SYSTEM users
2. **Configure backup strategy**
3. **Enable archivelog mode** if required
4. **Configure Enterprise Manager** if needed
5. **Apply latest patches** from Oracle Support

The installation is now complete! Your Oracle 19c database should be running on instance ORCL. Connect using:

```bash
sqlplus sys/Oracle123@localhost:1521/ORCL as sysdba
```

Remember to change default passwords and implement security best practices for production environments.