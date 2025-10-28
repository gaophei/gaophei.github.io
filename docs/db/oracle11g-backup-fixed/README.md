
# Oracle 11g 备份脚本（修订版）

本包包含 **RAC** 与 **单实例** 的 RMAN 与 Data Pump（expdp）备份脚本与参数模板。已按以下要求调整：

- RAC 的 expdp **默认 `CLUSTER=N`**；目录使用**本地磁盘**，**不依赖共享存储**。
- **不需要 Wallet**：所有脚本默认走本机 OS 认证 `'/ as sysdba'`（需在 DB 主机本地执行）。
- 遵循许可合规：RMAN 压缩算法为 **BASIC**（免费），expdp 使用 **COMPRESSION=METADATA_ONLY**；如需进一步压缩，请使用脚本内的 `gzip` 步骤。
- 归档日志备份策略：`NOT BACKED UP 1 TIMES DELETE INPUT`（避免误删全部副本）。
- 加固：`set -euo pipefail`、`umask 077`、日志与清理规范。

> **注意**：RAC 的 RMAN/expdp 脚本在本地节点执行即可；RAC expdp 因 `CLUSTER=N`，只使用当前节点的 Data Pump worker 与本地目录。若未来你改为共享目录并希望并行到多个实例，可改 `CLUSTER=Y` 并将目录指向共享存储。

## 目录结构

```
oracle11g-backup-fixed/
├─ scripts/
│  ├─ rman/
│  │  ├─ rman_rac_full.sh
│  │  ├─ rman_rac_incr.sh
│  │  ├─ rman_si_full.sh
│  │  └─ rman_si_incr.sh
│  └─ expdp/
│     ├─ expdp_rac_full.par
│     ├─ expdp_rac_schemas.par
│     ├─ expdp_rac_full.sh
│     ├─ expdp_rac_schemas.sh
│     ├─ expdp_si_full.par
│     ├─ expdp_si_schemas.par
│     ├─ expdp_si_full.sh
│     └─ expdp_si_schemas.sh
├─ sql/
│  ├─ create_directory.sql
│  └─ enable_bct.sql
└─ logs/   （运行时产生日志）
```

## 使用前必改项（所有脚本头部均有同名变量）

- `ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1`
- `ORACLE_SID=`
  - **RAC**：设为本机实例名（如 `orcl1`）。
  - **单实例**：设为数据库实例名（如 `orcl`）。
- `DB_UNIQUE_NAME=orcl`
- `BACKUP_BASE=/backup/${DB_UNIQUE_NAME}`  （备份根目录，本机磁盘路径）

## 首次初始化（必做）

1. 以 `oracle` 用户登录数据库主机，创建 Data Pump 目录对象（路径需与脚本中的 `EXPDP_DIR` 一致）：
   ```bash
   sqlplus / as sysdba @sql/create_directory.sql
   ```

2. （可选）启用 **块变化跟踪**（建议放数据盘）：
   ```bash
   sqlplus / as sysdba @sql/enable_bct.sql
   ```

## 运行示例

- 周日全备（RMAN Level 0）：
  ```bash
  bash scripts/rman/rman_rac_full.sh
  ```

- 工作日日增（RMAN Level 1）：
  ```bash
  bash scripts/rman/rman_rac_incr.sh
  ```

- Data Pump 全库（RAC，本地单节点）：
  ```bash
  bash scripts/expdp/expdp_rac_full.sh
  ```

- Data Pump 多 Schema（单实例）：
  ```bash
  bash scripts/expdp/expdp_si_schemas.sh
  ```

## 建议的 crontab（示例）

```
# RMAN：周日 02:00 全备；周一~周六 01:30 增量
0 2 * * 0 /bin/bash /path/to/scripts/rman/rman_rac_full.sh   >/dev/null 2>&1
30 1 * * 1-6 /bin/bash /path/to/scripts/rman/rman_rac_incr.sh >/dev/null 2>&1

# Data Pump：周日 04:00 全库；每日 03:30 多 schema
0 4 * * 0 /bin/bash /path/to/scripts/expdp/expdp_rac_full.sh     >/dev/null 2>&1
30 3 * * * /bin/bash /path/to/scripts/expdp/expdp_rac_schemas.sh  >/dev/null 2>&1
```

## 还原演练（建议定期）

- RMAN（只做校验，不真正还原）：
  ```bash
  rman target / <<'EOF'
  LIST BACKUP SUMMARY;
  RESTORE VALIDATE DATABASE;
  EOF
  ```

- Data Pump：使用 `impdp` 的 `SQLFILE` 或导入到测试 schema，核对对象计数与错误。
