下面给你一套可以直接落地的 Oracle 19c 备份脚本模板，覆盖：

- RAC（含 CDB/PDB）的 RMAN 物理备份与 Data Pump（expdp）逻辑备份
- 单实例（含 CDB/PDB）的 RMAN 与 expdp

脚本均为“模板化 + 可选项清楚标注”，拿去按你的环境变量改下即可用。

------

# 准备与约定

- OS 账号：`oracle`；备份目录（文件系统示例）`/backup`（RAC 用共享存储/NFS/ACFS）。
- 目录对象：`CREATE OR REPLACE DIRECTORY DPDIR AS '/backup/dpump'; GRANT READ, WRITE ON DIRECTORY DPDIR TO SYSTEM;`
- 建议启用：`ARCHIVELOG`、`FRA`、`CONTROLFILE AUTOBACKUP`。
- 并发与压缩：RMAN 使用压缩备份集；expdp 默认 `COMPRESSION=METADATA_ONLY`（若有 AC 授权，可改 `ALL`）。
- 备份加密（**可选**）：RMAN `SET ENCRYPTION ON IDENTIFIED BY 'yourStrongPwd' ONLY;`；expdp 用 `ENCRYPTION=PASSWORD ENCRYPTION_PASSWORD=yourStrongPwd`。

> **RAC 注意**
>
> - expdp 目录路径必须是**各节点可见**的共享路径。
> - 想用 Data Pump 跨节点跑并行，保留 `CLUSTER=YES`（默认 YES）。
> - RMAN 备份到 ASM 时把 `FORMAT` 换成 `+FRA/%d/backupset/%T/%U` 一类路径即可。

------

# 一、RAC：RMAN 备份脚本（含 CDB / PDB）

## 1）一次性配置（可执行一次）

**rman_config_rac.rcv**

```rman
-- 连接方式任选其一（建议安全凭据/钱包）
-- connect target "sys/Password@MYCDB as sysdba";
connect target /

CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/rman/%d/%T/%U.bkp';
-- 可选：只在归档备份≥1次后允许删除
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO DISK;
```

执行：

```bash
rman cmdfile=rman_config_rac.rcv log=/backup/logs/rman_config_$(date +%F).log
```

## 2）每周全备（包含整个 CDB 与所有 PDB + 控制文件 + 归档）

**backup_full_cdb_rac.sh**

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=MYCDB1         # 任一实例SID
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
LOG=/backup/logs/rman_full_$(date +%F_%H%M).log

rman target / <<'RMAN' | tee "$LOG"
RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  # 可选：备份加密
  # SET ENCRYPTION ON IDENTIFIED BY 'yourStrongPwd' ONLY;

  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    INCLUDE CURRENT CONTROLFILE
    TAG 'FULL_CDB';

  BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    DELETE INPUT
    TAG 'ARC_CDB';

  BACKUP CURRENT CONTROLFILE TAG 'CTRLFILE_AUTON';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
RMAN
```

## 3）每日增量（Level 1 累积）

**backup_inc1_cdb_rac.sh**

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=MYCDB1
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
LOG=/backup/logs/rman_inc1_$(date +%F_%H%M).log

rman target / <<'RMAN' | tee "$LOG"
RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 CUMULATIVE
    DATABASE
    TAG 'INC1_CDB';

  BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    DELETE INPUT
    TAG 'ARC_CDB';

  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
RMAN
```

## 4）仅备份指定 PDB（可选）

**backup_pdbs_rac.rcv**

```rman
connect target /

RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP AS COMPRESSED BACKUPSET
    PLUGGABLE DATABASE pdbtest, pdbhr
    TAG 'PDB_ONLY';
  BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    DELETE INPUT
    TAG 'ARC_PDB';
  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
```

> 说明：
>
> - RMAN 物理备份在 CDB 级别即可覆盖全部 PDB；只有**想缩小备份范围**时，才用 `BACKUP PLUGGABLE DATABASE`。
> - 恢复/克隆单个 PDB 时，PDB 级备份更灵活。

------

# 二、RAC：expdp 备份脚本（逻辑，建议按 PDB 维度）

## 1）导出某 PDB 全库（数据+元数据）

**expdp_pdb1.par**

```
USERID=system/Password@pdb1
DIRECTORY=DPDIR
DUMPFILE=pdb1_full_%U.dmp
LOGFILE=pdb1_full.log
FULL=Y
PARALLEL=8
CLUSTER=YES
COMPRESSION=METADATA_ONLY
FLASHBACK_TIME=SYSTIMESTAMP
-- 若需压缩数据并有 AC 授权：COMPRESSION=ALL
-- 若需加密：
-- ENCRYPTION=PASSWORD
-- ENCRYPTION_PASSWORD=yourStrongPwd
```

执行：

```bash
expdp parfile=/backup/pars/expdp_pdb1.par
```

## 2）批量导出多个 PDB（示例）

**expdp_all_pdbs.sh**

```bash
#!/bin/bash
set -euo pipefail
PDBS=("pdb1" "pdb2" "pdbtest")
for p in "${PDBS[@]}"; do
  expdp "system/Password@${p}" \
    directory=DPDIR dumpfile="${p}_full_%U.dmp" logfile="${p}_full.log" \
    full=y parallel=8 cluster=yes compression=metadata_only flashback_time=systimestamp
done
```

## 3）导出 CDB 根（仅公共对象/元数据，**不含各 PDB 用户数据**）

**expdp_cdb_root_meta.par**

```
USERID=system/Password@cdbroot
DIRECTORY=DPDIR
DUMPFILE=cdbroot_meta_%U.dmp
LOGFILE=cdbroot_meta.log
FULL=Y
PARALLEL=4
CLUSTER=YES
COMPRESSION=METADATA_ONLY
```

> 建议做法：**RMAN 负责物理整库（CDB+PDB）可恢复性；expdp 负责按 PDB 的逻辑迁移/回档。**

------

# 三、单实例：RMAN 备份脚本（含 CDB/PDB）

## 1）一次性配置

**rman_config_si.rcv**

```rman
connect target /

CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/rman/%d/%T/%U.bkp';
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO DISK;
```

执行：

```bash
rman cmdfile=rman_config_si.rcv log=/backup/logs/rman_config_si_$(date +%F).log
```

## 2）每周全备

**backup_full_cdb_si.sh**

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=MYCDB
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
LOG=/backup/logs/si_full_$(date +%F_%H%M).log

rman target / <<'RMAN' | tee "$LOG"
RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    INCLUDE CURRENT CONTROLFILE
    TAG 'FULL_CDB_SI';
  BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    DELETE INPUT
    TAG 'ARC_CDB_SI';
  BACKUP CURRENT CONTROLFILE TAG 'CTRLFILE_AUTON';
  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
RMAN
```

## 3）每日增量

**backup_inc1_cdb_si.sh**

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=MYCDB
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
LOG=/backup/logs/si_inc1_$(date +%F_%H%M).log

rman target / <<'RMAN' | tee "$LOG"
RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 CUMULATIVE
    DATABASE
    TAG 'INC1_CDB_SI';
  BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    DELETE INPUT
    TAG 'ARC_CDB_SI';
  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
RMAN
```

## 4）单实例仅备份指定 PDB（可选）

**backup_pdbs_si.rcv**

```rman
connect target /

RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP AS COMPRESSED BACKUPSET
    PLUGGABLE DATABASE pdbtest
    TAG 'PDB_ONLY_SI';
  BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    DELETE INPUT
    TAG 'ARC_PDB_SI';
  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;
}
```

------

# 四、单实例：expdp 备份脚本

## 1）导出某 PDB 全库

**expdp_pdb_si.par**

```
USERID=system/Password@pdbtest
DIRECTORY=DPDIR
DUMPFILE=pdbtest_full_%U.dmp
LOGFILE=pdbtest_full.log
FULL=Y
PARALLEL=4
COMPRESSION=METADATA_ONLY
FLASHBACK_TIME=SYSTIMESTAMP
-- 可选加密：
-- ENCRYPTION=PASSWORD
-- ENCRYPTION_PASSWORD=yourStrongPwd
```

## 2）导出 CDB 根元数据（可选）

同 RAC 的 `expdp_cdb_root_meta.par`，把连到 root 的服务名改成单实例对应的 root 服务即可。

------

# 五、校验与演练（强烈建议纳入周任务）

**RMAN 备份可恢复性校验**

```bash
rman target / <<'RMAN'
-- 仅做读校验，不真正还原
RESTORE DATABASE VALIDATE;
VALIDATE BACKUPSET;
RMAN
```

**Data Pump 快速校验**

```bash
impdp system/Password@pdbtest DIRECTORY=DPDIR DUMPFILE=pdbtest_full_01.dmp \
  SQLFILE=check_ddl.sql LOGFILE=check_imp.log
```

> `SQLFILE` 只生成 DDL，不实际导入，便于检查对象/权限是否齐全。

------

# 六、Crontab 调度示例

```cron
# 每周日 01:00 全备（RAC）
0 1 * * 0 /backup/scripts/backup_full_cdb_rac.sh >/backup/logs/cron_full_rac.out 2>&1
# 周一到周六 01:00 增量（RAC）
0 1 * * 1-6 /backup/scripts/backup_inc1_cdb_rac.sh >/backup/logs/cron_inc1_rac.out 2>&1

# 单实例同理：
0 2 * * 0 /backup/scripts/backup_full_cdb_si.sh >/backup/logs/cron_full_si.out 2>&1
0 2 * * 1-6 /backup/scripts/backup_inc1_cdb_si.sh >/backup/logs/cron_inc1_si.out 2>&1
```

------

## 常见坑与小贴士

- **RAC 的 expdp**：`DIRECTORY` 指向**共享**路径，否则多节点并行/回写会失败；保留 `CLUSTER=YES`。
- **一致性快照**：多 PDB 并行导出时加 `FLASHBACK_TIME=SYSTIMESTAMP`，拿到同一时刻的一致数据。
- **归档清理策略**：`CONFIGURE ARCHIVELOG DELETION POLICY` 配合跨库复制/备份策略谨慎设置。
- **备份加密**：跨机房/上云强烈建议启用。
- **恢复演练**：定期做 `RESTORE VALIDATE` 与沙箱 impdp 测试，避免“只备不演”。

------

需要我帮你把以上脚本按你现有的 DB 名称、服务名、目录与并发数**定制成一套可直接部署的文件结构**吗？我可以一次性给出完整目录树与可执行权限设置。