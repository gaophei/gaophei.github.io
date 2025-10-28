好的！下面给你一套可直接落地的 **Oracle 11g** 备份方案，分别覆盖：

- **RAC**：RMAN（周全备 + 日增量）与 Data Pump（全库/多 schema）
- **单实例**：RMAN（周全备 + 日增量）与 Data Pump（全库/多 schema）

脚本均假设在 **Linux** 上运行，采用 **磁盘备份**；压缩用 RMAN 的 **BASIC**（无需额外许可），Data Pump 默认 **COMPRESSION=METADATA_ONLY**（免费）。你可以按需调整并放进 cron。

------

# 一、通用准备（两类库都适用）

**1）设置环境与目录（首次）**

```bash
# 按需修改
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export ORACLE_BASE=/u01/app/oracle
export PATH=$ORACLE_HOME/bin:$PATH

# 库名与备份根目录
DB_NAME=orcl              # 数据库名
DB_UNIQUE_NAME=orcl       # 唯一名（用作目录层级）
BACKUP_BASE=/backup/${DB_UNIQUE_NAME}

# 目录
sudo mkdir -p $BACKUP_BASE/{rman,expdp,logs}
sudo chown -R oracle:oinstall $BACKUP_BASE
```

**2）建议一次性开启 BCT（增量更快）**

```bash
sqlplus / as sysdba <<'SQL'
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING
USING FILE '/u02/oradata/orcl/bct_orcl.chg';
SQL
```

------

# 二、RAC：RMAN 备份脚本

> 说明：在**任一节点**执行即可；脚本里用 `ORACLE_SID=${DB_NAME}1`（请按你实例名调整，如 orcl1）。备份写到本机/共享目录，**归档日志会切换并备份**；保留策略 7 天，可自行改。

## 1）周日全备（Level 0）

```
rman_rac_full.sh
#!/bin/bash
set -euo pipefail

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
DB_NAME=orcl
DB_UNIQUE_NAME=orcl
export ORACLE_SID=${DB_NAME}1        # <- 按需改为你的实例1名
BACKUP_BASE=/backup/${DB_UNIQUE_NAME}
DATE=$(date +%F_%H%M)

rman target / log="$BACKUP_BASE/logs/rman_full_${DATE}.log" <<EOF
RUN {
  CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
  CONFIGURE CONTROLFILE AUTOBACKUP ON;
  CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE
    TAG 'WEEKLY_LEVEL0_${DATE}'
    FORMAT '$BACKUP_BASE/rman/%d_%T_L0_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT
    FORMAT '$BACKUP_BASE/rman/%d_%T_ARCH_%U.bkp';

  BACKUP CURRENT CONTROLFILE FORMAT '$BACKUP_BASE/rman/%d_%T_CTL_%U.bkp';
  BACKUP SPFILE FORMAT '$BACKUP_BASE/rman/%d_%T_SPFILE_%U.bkp';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF
```

## 2）周一~周六日增量（Level 1）

```
rman_rac_incr.sh
#!/bin/bash
set -euo pipefail

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
DB_NAME=orcl
DB_UNIQUE_NAME=orcl
export ORACLE_SID=${DB_NAME}1
BACKUP_BASE=/backup/${DB_UNIQUE_NAME}
DATE=$(date +%F_%H%M)

rman target / log="$BACKUP_BASE/logs/rman_incr_${DATE}.log" <<EOF
RUN {
  CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
  CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE
    TAG 'DAILY_LEVEL1_${DATE}'
    FORMAT '$BACKUP_BASE/rman/%d_%T_L1_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT
    FORMAT '$BACKUP_BASE/rman/%d_%T_ARCH_%U.bkp';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF
```

------

# 三、单实例：RMAN 备份脚本

> 说明：并行度略小些（2）。其余逻辑与 RAC 类似。

## 1）周日全备（Level 0）

```
rman_si_full.sh
#!/bin/bash
set -euo pipefail

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=orcl              # <- 单实例 SID
DB_UNIQUE_NAME=orcl
BACKUP_BASE=/backup/${DB_UNIQUE_NAME}
DATE=$(date +%F_%H%M)

rman target / log="$BACKUP_BASE/logs/rman_full_${DATE}.log" <<EOF
RUN {
  CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
  CONFIGURE CONTROLFILE AUTOBACKUP ON;
  CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE
    TAG 'WEEKLY_LEVEL0_${DATE}'
    FORMAT '$BACKUP_BASE/rman/%d_%T_L0_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT
    FORMAT '$BACKUP_BASE/rman/%d_%T_ARCH_%U.bkp';

  BACKUP CURRENT CONTROLFILE FORMAT '$BACKUP_BASE/rman/%d_%T_CTL_%U.bkp';
  BACKUP SPFILE FORMAT '$BACKUP_BASE/rman/%d_%T_SPFILE_%U.bkp';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF
```

## 2）周一~周六日增量（Level 1）

```
rman_si_incr.sh
#!/bin/bash
set -euo pipefail

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=orcl
DB_UNIQUE_NAME=orcl
BACKUP_BASE=/backup/${DB_UNIQUE_NAME}
DATE=$(date +%F_%H%M)

rman target / log="$BACKUP_BASE/logs/rman_incr_${DATE}.log" <<EOF
RUN {
  CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
  CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE
    TAG 'DAILY_LEVEL1_${DATE}'
    FORMAT '$BACKUP_BASE/rman/%d_%T_L1_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT
    FORMAT '$BACKUP_BASE/rman/%d_%T_ARCH_%U.bkp';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF
```

------

# 四、RAC：Data Pump（expdp）脚本

> **重要**：`DIRECTORY` 指向的文件系统应为 **共享存储（ACFS/NFS）**，以便 `PARALLEL>1` 且 `CLUSTER=Y` 时各实例都能写入。
>  **用户**：请使用 `SYSTEM` 或具备 `DATAPUMP_EXP_FULL_DATABASE` 角色的专用账号，**不要**用 SYS。

**1）创建目录对象（首次）**

```bash
sqlplus / as sysdba <<'SQL'
CREATE OR REPLACE DIRECTORY DP_DIR AS '/backup/orcl/expdp';
GRANT READ, WRITE ON DIRECTORY DP_DIR TO SYSTEM;
SQL
```

**2）全库导出（周）**
 `expdp_rac_full.par`

```
FULL=Y
DIRECTORY=DP_DIR
DUMPFILE=full_%U_%DATE%.dmp
LOGFILE=full_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=Y
PARALLEL=4
# 可选：指定泵服务，需提前用 srvctl 建服务
# SERVICE_NAME=orcl_pump
expdp_rac_full.sh
#!/bin/bash
set -euo pipefail

DATE=$(date +%F_%H%M)
PAR=/backup/orcl/expdp/expdp_rac_full.par

# 生成带日期的临时 parfile
sed "s/%DATE%/${DATE}/g" $PAR > /tmp/expdp_full_${DATE}.par

# 建议使用专用备份用户，示例用 SYSTEM
expdp system/<PASSWORD> PARFILE=/tmp/expdp_full_${DATE}.par

# 清理 14 天前的 dmp/log
find /backup/orcl/expdp -type f \( -name "*.dmp" -o -name "*.log" \) -mtime +14 -delete
```

**3）多 Schema 导出（可日更）**
 （结合你之前库里的 schema：`SHAREDB,PORTAL_SERVICE,IDC_U_STUWORK,SHAREDB_WISDOM_BRAIN,DATAQUALITY_WISDOM_BRAIN,STANDCODE_WISDOM_BRAIN,SWOP_WISDOM_BRAIN`）
 `expdp_rac_schemas.par`

```
SCHEMAS=SHAREDB,PORTAL_SERVICE,IDC_U_STUWORK,SHAREDB_WISDOM_BRAIN,DATAQUALITY_WISDOM_BRAIN,STANDCODE_WISDOM_BRAIN,SWOP_WISDOM_BRAIN
DIRECTORY=DP_DIR
DUMPFILE=schemas_%U_%DATE%.dmp
LOGFILE=schemas_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=Y
PARALLEL=4
# SERVICE_NAME=orcl_pump
expdp_rac_schemas.sh
#!/bin/bash
set -euo pipefail
DATE=$(date +%F_%H%M)
PAR=/backup/orcl/expdp/expdp_rac_schemas.par
sed "s/%DATE%/${DATE}/g" $PAR > /tmp/expdp_schemas_${DATE}.par
expdp system/<PASSWORD> PARFILE=/tmp/expdp_schemas_${DATE}.par
find /backup/orcl/expdp -type f \( -name "*.dmp" -o -name "*.log" \) -mtime +14 -delete
```

------

# 五、单实例：Data Pump（expdp）脚本

**1）目录对象（首次）**

```bash
sqlplus / as sysdba <<'SQL'
CREATE OR REPLACE DIRECTORY DP_DIR AS '/backup/orcl/expdp';
GRANT READ, WRITE ON DIRECTORY DP_DIR TO SYSTEM;
SQL
```

**2）全库导出**
 `expdp_si_full.par`

```
FULL=Y
DIRECTORY=DP_DIR
DUMPFILE=full_%U_%DATE%.dmp
LOGFILE=full_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=N
PARALLEL=2
```

**3）多 Schema 导出**
 `expdp_si_schemas.par`

```
SCHEMAS=SHAREDB,PORTAL_SERVICE,IDC_U_STUWORK,SHAREDB_WISDOM_BRAIN,DATAQUALITY_WISDOM_BRAIN,STANDCODE_WISDOM_BRAIN,SWOP_WISDOM_BRAIN
DIRECTORY=DP_DIR
DUMPFILE=schemas_%U_%DATE%.dmp
LOGFILE=schemas_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=N
PARALLEL=2
```

与 RAC 相同的 `*.sh` 方式运行即可（把 `CLUSTER=Y` 的 parfile 换为单实例的）。

------

# 六、建议的 crontab（例）

```cron
# 周日 02:00 RMAN Level 0，全备
0 2 * * 0 /bin/bash /backup/orcl/scripts/rman_rac_full.sh   >/dev/null 2>&1
# 周一~周六 01:30 RMAN Level 1，增量
30 1 * * 1-6 /bin/bash /backup/orcl/scripts/rman_rac_incr.sh >/dev/null 2>&1

# 周日 04:00 Data Pump 全库
0 4 * * 0 /bin/bash /backup/orcl/scripts/expdp_rac_full.sh   >/dev/null 2>&1
# 每天 03:30 Data Pump 多 Schema
30 3 * * * /bin/bash /backup/orcl/scripts/expdp_rac_schemas.sh >/dev/null 2>&1
```

> 单实例就把脚本名换成 `*_si_*` 版本。

------

# 七、验证与恢复演练（强烈推荐定期做）

**1）RMAN 有效性检查（每周一次）：**

```bash
rman target / <<'EOF'
REPORT SCHEMA;
LIST BACKUP SUMMARY;
RESTORE VALIDATE DATABASE;
EOF
```

**2）Data Pump 快速校验：**建一个临时空库/同名测试库，做一次 `impdp` 的 `SQLFILE` 或导入到新 schema 验证对象数量与错误日志。

------

# 备注与小贴士

- **RMAN 压缩**未指定算法时 11g 使用 **BASIC**，无需额外许可；如果你改为 `LOW/MEDIUM/HIGH` 则涉及高级压缩授权。
- Data Pump 的 **COMPRESSION=METADATA_ONLY** 免费；若要压缩数据段（`ALL`），涉及高级压缩授权。
- RAC 下 `PARALLEL>1` 且 `CLUSTER=Y` 时，**目录对象必须可被所有实例访问**（ACFS/NFS 等）。
- 如果用 **FRA**，`DELETE INPUT` 会让 RMAN 合规回收归档；也可将归档备份独立出来（比如每小时一次）。

------

需要我把这些脚本打包成一份可下载的目录结构（含 parfile 和可执行权限）吗？我可以直接给你成套文件名与内容。

-----------------------------

# 全部脚本与参数文件（v3）

## README.md

```
# Oracle 11g 备份脚本（修订版 v3）

本版将 **RMAN TAG** 统一为：
- Level 0：`TAG 'WEEKLY_LEVEL0_${DATE}'`
- Level 1：`TAG 'DAILY_LEVEL1_${DATE}'`
- 归档：   `TAG 'ARCH_${DATE}'`
- 控制文件/参数文件：`TAG 'CONTROL_${DATE}'` / `TAG 'SPFILE_${DATE}'`

> 注意：RMAN 主备份 RUN 块使用 `<<EOF`（未加引号）以便 **shell 展开 `${DATE}`**。不要改成 `<<'EOF'`。

其他特性：RAC expdp `CLUSTER=N`、本地目录、无需 Wallet；RMAN 压缩 BASIC；expdp `COMPRESSION=METADATA_ONLY`；归档 `NOT BACKED UP 1 TIMES DELETE INPUT`；`set -euo pipefail` + `umask 077`。

```

## sql/create_directory.sql

```
-- 创建与授权 Data Pump 目录对象（本地路径，非共享存储）
CREATE OR REPLACE DIRECTORY DP_DIR AS '/backup/orcl/expdp';
GRANT READ, WRITE ON DIRECTORY DP_DIR TO SYSTEM;

```

## sql/enable_bct.sql

```
-- 启用块变化跟踪（建议放数据库数据盘）
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING
USING FILE '/u02/oradata/orcl/bct_orcl.chg';

```

## scripts/rman/rman_rac_full.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"        # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"
BACKUP_BASE="/backup/${DB_UNIQUE_NAME}"
LOG_DIR="${BACKUP_BASE}/logs"
mkdir -p "${LOG_DIR}"
DATE="$(date +%F_%H%M)"

RMAN_TAG="rman_rac_full"

# RMAN 持久化配置（首次会生效，之后保持该配置）
rman target / log="${LOG_DIR}/${RMAN_TAG}_${DATE}.log" <<'EOF'
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
EOF

BACKUP_DIR="${BACKUP_BASE}/rman"
mkdir -p "${BACKUP_DIR}"

# 使用 <<EOF（未加引号），以便 ${DATE} 在 shell 侧展开
rman target / log="${LOG_DIR}/WEEKLY_LEVEL0_${DATE}.rman.log" <<EOF
RUN {
  CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE
    TAG 'WEEKLY_LEVEL0_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_L0_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
    NOT BACKED UP 1 TIMES
    TAG 'ARCH_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_ARCH_%U.bkp'
    DELETE INPUT;

  BACKUP CURRENT CONTROLFILE FORMAT '${BACKUP_DIR}/%d_%T_CTL_%U.bkp' TAG 'CONTROL_${DATE}';
  BACKUP SPFILE            FORMAT '${BACKUP_DIR}/%d_%T_SPFILE_%U.bkp' TAG 'SPFILE_${DATE}';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF

```

## scripts/rman/rman_rac_incr.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"        # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"
BACKUP_BASE="/backup/${DB_UNIQUE_NAME}"
LOG_DIR="${BACKUP_BASE}/logs"
mkdir -p "${LOG_DIR}"
DATE="$(date +%F_%H%M)"

RMAN_TAG="rman_rac_incr"

# RMAN 持久化配置（首次会生效，之后保持该配置）
rman target / log="${LOG_DIR}/${RMAN_TAG}_${DATE}.log" <<'EOF'
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
EOF

BACKUP_DIR="${BACKUP_BASE}/rman"
mkdir -p "${BACKUP_DIR}"

# 使用 <<EOF（未加引号），以便 ${DATE} 在 shell 侧展开
rman target / log="${LOG_DIR}/DAILY_LEVEL1_${DATE}.rman.log" <<EOF
RUN {
  CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE
    TAG 'DAILY_LEVEL1_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_L1_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
    NOT BACKED UP 1 TIMES
    TAG 'ARCH_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_ARCH_%U.bkp'
    DELETE INPUT;

  BACKUP CURRENT CONTROLFILE FORMAT '${BACKUP_DIR}/%d_%T_CTL_%U.bkp' TAG 'CONTROL_${DATE}';
  BACKUP SPFILE            FORMAT '${BACKUP_DIR}/%d_%T_SPFILE_%U.bkp' TAG 'SPFILE_${DATE}';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF

```

## scripts/rman/rman_si_full.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"  # 单实例 SID        # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"
BACKUP_BASE="/backup/${DB_UNIQUE_NAME}"
LOG_DIR="${BACKUP_BASE}/logs"
mkdir -p "${LOG_DIR}"
DATE="$(date +%F_%H%M)"

RMAN_TAG="rman_si_full"

# RMAN 持久化配置（首次会生效，之后保持该配置）
rman target / log="${LOG_DIR}/${RMAN_TAG}_${DATE}.log" <<'EOF'
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
EOF

BACKUP_DIR="${BACKUP_BASE}/rman"
mkdir -p "${BACKUP_DIR}"

# 使用 <<EOF（未加引号），以便 ${DATE} 在 shell 侧展开
rman target / log="${LOG_DIR}/WEEKLY_LEVEL0_${DATE}.rman.log" <<EOF
RUN {
  CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE
    TAG 'WEEKLY_LEVEL0_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_L0_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
    NOT BACKED UP 1 TIMES
    TAG 'ARCH_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_ARCH_%U.bkp'
    DELETE INPUT;

  BACKUP CURRENT CONTROLFILE FORMAT '${BACKUP_DIR}/%d_%T_CTL_%U.bkp' TAG 'CONTROL_${DATE}';
  BACKUP SPFILE            FORMAT '${BACKUP_DIR}/%d_%T_SPFILE_%U.bkp' TAG 'SPFILE_${DATE}';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF

```

## scripts/rman/rman_si_incr.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"  # 单实例 SID        # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"
BACKUP_BASE="/backup/${DB_UNIQUE_NAME}"
LOG_DIR="${BACKUP_BASE}/logs"
mkdir -p "${LOG_DIR}"
DATE="$(date +%F_%H%M)"

RMAN_TAG="rman_si_incr"

# RMAN 持久化配置（首次会生效，之后保持该配置）
rman target / log="${LOG_DIR}/${RMAN_TAG}_${DATE}.log" <<'EOF'
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
EOF

BACKUP_DIR="${BACKUP_BASE}/rman"
mkdir -p "${BACKUP_DIR}"

# 使用 <<EOF（未加引号），以便 ${DATE} 在 shell 侧展开
rman target / log="${LOG_DIR}/DAILY_LEVEL1_${DATE}.rman.log" <<EOF
RUN {
  CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;

  SQL 'alter system archive log current';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE
    TAG 'DAILY_LEVEL1_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_L1_%U.bkp';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
    NOT BACKED UP 1 TIMES
    TAG 'ARCH_${DATE}'
    FORMAT '${BACKUP_DIR}/%d_%T_ARCH_%U.bkp'
    DELETE INPUT;

  BACKUP CURRENT CONTROLFILE FORMAT '${BACKUP_DIR}/%d_%T_CTL_%U.bkp' TAG 'CONTROL_${DATE}';
  BACKUP SPFILE            FORMAT '${BACKUP_DIR}/%d_%T_SPFILE_%U.bkp' TAG 'SPFILE_${DATE}';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
EOF

```

## scripts/expdp/expdp_rac_full.par

```
FULL=Y
DIRECTORY=DP_DIR
DUMPFILE=full_%U_%DATE%.dmp
LOGFILE=full_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=N
PARALLEL=2
METRICS=Y
FILESIZE=8G

```

## scripts/expdp/expdp_rac_schemas.par

```
SCHEMAS=SHAREDB,PORTAL_SERVICE,IDC_U_STUWORK,SHAREDB_WISDOM_BRAIN,DATAQUALITY_WISDOM_BRAIN,STANDCODE_WISDOM_BRAIN,SWOP_WISDOM_BRAIN
DIRECTORY=DP_DIR
DUMPFILE=schemas_%U_%DATE%.dmp
LOGFILE=schemas_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=N
PARALLEL=2
METRICS=Y
FILESIZE=8G

```

## scripts/expdp/expdp_rac_full.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"   # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"

# Data Pump 目录对象所指向的本地路径（需与 sql/create_directory.sql 一致）
EXPDP_DIR="/backup/${DB_UNIQUE_NAME}/expdp"
LOG_DIR="/backup/${DB_UNIQUE_NAME}/logs"
mkdir -p "${EXPDP_DIR}" "${LOG_DIR}"

DATE="$(date +%F_%H%M)"
PAR_TEMPLATE="${EXPDP_DIR}/expdp_rac_full.par"
PAR_WORK="/tmp/$(basename "${PAR_TEMPLATE%.par}")_${DATE}.par"

# 生成带日期的 parfile（把 %DATE% 替换为 ${DATE} 值）
sed "s/%DATE%/${DATE}/g" "${PAR_TEMPLATE}" > "${PAR_WORK}"

# 本地 OS 认证（需在 DB 主机执行）
expdp '/ as sysdba' PARFILE="${PAR_WORK}"

# 压缩本次生成的 dmp（按日期匹配）
find "${EXPDP_DIR}" -maxdepth 1 -type f -name "*_${DATE}*.dmp" -print0 | xargs -0 -I{} gzip -f "{}" || true

# 清理历史（默认 14 天；按需调整）
RETENTION_DAYS="${RETENTION_DAYS:-14}"
find "${EXPDP_DIR}" -type f \( -name "*.dmp" -o -name "*.dmp.gz" -o -name "*.log" \) -mtime +${RETENTION_DAYS} -delete || true

echo "expdp done: $(date)"

```

## scripts/expdp/expdp_rac_schemas.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"   # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"

# Data Pump 目录对象所指向的本地路径（需与 sql/create_directory.sql 一致）
EXPDP_DIR="/backup/${DB_UNIQUE_NAME}/expdp"
LOG_DIR="/backup/${DB_UNIQUE_NAME}/logs"
mkdir -p "${EXPDP_DIR}" "${LOG_DIR}"

DATE="$(date +%F_%H%M)"
PAR_TEMPLATE="${EXPDP_DIR}/expdp_rac_schemas.par"
PAR_WORK="/tmp/$(basename "${PAR_TEMPLATE%.par}")_${DATE}.par"

# 生成带日期的 parfile（把 %DATE% 替换为 ${DATE} 值）
sed "s/%DATE%/${DATE}/g" "${PAR_TEMPLATE}" > "${PAR_WORK}"

# 本地 OS 认证（需在 DB 主机执行）
expdp '/ as sysdba' PARFILE="${PAR_WORK}"

# 压缩本次生成的 dmp（按日期匹配）
find "${EXPDP_DIR}" -maxdepth 1 -type f -name "*_${DATE}*.dmp" -print0 | xargs -0 -I{} gzip -f "{}" || true

# 清理历史（默认 14 天；按需调整）
RETENTION_DAYS="${RETENTION_DAYS:-14}"
find "${EXPDP_DIR}" -type f \( -name "*.dmp" -o -name "*.dmp.gz" -o -name "*.log" \) -mtime +${RETENTION_DAYS} -delete || true

echo "expdp done: $(date)"

```

## scripts/expdp/expdp_si_full.par

```
FULL=Y
DIRECTORY=DP_DIR
DUMPFILE=full_%U_%DATE%.dmp
LOGFILE=full_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=N
PARALLEL=2
METRICS=Y
FILESIZE=8G

```

## scripts/expdp/expdp_si_schemas.par

```
SCHEMAS=SHAREDB,PORTAL_SERVICE,IDC_U_STUWORK,SHAREDB_WISDOM_BRAIN,DATAQUALITY_WISDOM_BRAIN,STANDCODE_WISDOM_BRAIN,SWOP_WISDOM_BRAIN
DIRECTORY=DP_DIR
DUMPFILE=schemas_%U_%DATE%.dmp
LOGFILE=schemas_%DATE%.log
FLASHBACK_TIME=SYSTIMESTAMP
COMPRESSION=METADATA_ONLY
EXCLUDE=STATISTICS
CLUSTER=N
PARALLEL=2
METRICS=Y
FILESIZE=8G

```

## scripts/expdp/expdp_si_full.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"   # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"

# Data Pump 目录对象所指向的本地路径（需与 sql/create_directory.sql 一致）
EXPDP_DIR="/backup/${DB_UNIQUE_NAME}/expdp"
LOG_DIR="/backup/${DB_UNIQUE_NAME}/logs"
mkdir -p "${EXPDP_DIR}" "${LOG_DIR}"

DATE="$(date +%F_%H%M)"
PAR_TEMPLATE="${EXPDP_DIR}/expdp_si_full.par"
PAR_WORK="/tmp/$(basename "${PAR_TEMPLATE%.par}")_${DATE}.par"

# 生成带日期的 parfile（把 %DATE% 替换为 ${DATE} 值）
sed "s/%DATE%/${DATE}/g" "${PAR_TEMPLATE}" > "${PAR_WORK}"

# 本地 OS 认证（需在 DB 主机执行）
expdp '/ as sysdba' PARFILE="${PAR_WORK}"

# 压缩本次生成的 dmp（按日期匹配）
find "${EXPDP_DIR}" -maxdepth 1 -type f -name "*_${DATE}*.dmp" -print0 | xargs -0 -I{} gzip -f "{}" || true

# 清理历史（默认 14 天；按需调整）
RETENTION_DAYS="${RETENTION_DAYS:-14}"
find "${EXPDP_DIR}" -type f \( -name "*.dmp" -o -name "*.dmp.gz" -o -name "*.log" \) -mtime +${RETENTION_DAYS} -delete || true

echo "expdp done: $(date)"

```

## scripts/expdp/expdp_si_schemas.sh

```
#!/bin/bash
set -euo pipefail
umask 077

# ====== 必改：环境与目录 ======
export ORACLE_HOME="/u01/app/oracle/product/11.2.0/dbhome_1"
export PATH="$ORACLE_HOME/bin:$PATH"
export ORACLE_SID="orcl"   # 单实例：orcl；RAC：如 orcl1（本机实例）
DB_UNIQUE_NAME="orcl"

# Data Pump 目录对象所指向的本地路径（需与 sql/create_directory.sql 一致）
EXPDP_DIR="/backup/${DB_UNIQUE_NAME}/expdp"
LOG_DIR="/backup/${DB_UNIQUE_NAME}/logs"
mkdir -p "${EXPDP_DIR}" "${LOG_DIR}"

DATE="$(date +%F_%H%M)"
PAR_TEMPLATE="${EXPDP_DIR}/expdp_si_schemas.par"
PAR_WORK="/tmp/$(basename "${PAR_TEMPLATE%.par}")_${DATE}.par"

# 生成带日期的 parfile（把 %DATE% 替换为 ${DATE} 值）
sed "s/%DATE%/${DATE}/g" "${PAR_TEMPLATE}" > "${PAR_WORK}"

# 本地 OS 认证（需在 DB 主机执行）
expdp '/ as sysdba' PARFILE="${PAR_WORK}"

# 压缩本次生成的 dmp（按日期匹配）
find "${EXPDP_DIR}" -maxdepth 1 -type f -name "*_${DATE}*.dmp" -print0 | xargs -0 -I{} gzip -f "{}" || true

# 清理历史（默认 14 天；按需调整）
RETENTION_DAYS="${RETENTION_DAYS:-14}"
find "${EXPDP_DIR}" -type f \( -name "*.dmp" -o -name "*.dmp.gz" -o -name "*.log" \) -mtime +${RETENTION_DAYS} -delete || true

echo "expdp done: $(date)"

```

