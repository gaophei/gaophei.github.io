下面是一个实现 MySQL 8.0 数据库每日全量备份并实时同步增量日志（二进制日志）至异地存储的脚本示例。该脚本使用 `mysqldump` 进行全量备份，结合 `mysqlbinlog` 和 `rsync` 工具实现增量日志的实时同步。脚本适用于 Linux 环境，并假设异地存储可以通过 SSH 访问。

### 脚本内容

```bash
#!/bin/bash

# 数据库配置
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="backup_user"
DB_PASS="your_password"
DB_NAME="your_database"

# 备份路径配置
LOCAL_BACKUP_DIR="/backup/mysql/full"  # 本地全量备份目录
LOCAL_BINLOG_DIR="/backup/mysql/binlog" # 本地二进制日志临时目录
REMOTE_BACKUP_DIR="/remote/backup/mysql" # 异地存储目录
REMOTE_HOST="remote_user@remote_host"    # 异地存储服务器SSH信息
REMOTE_PORT="22"                         # 异地存储服务器SSH端口

# 备份文件名配置
DATE=$(date +%Y%m%d)
FULL_BACKUP_FILE="full_backup_${DB_NAME}_${DATE}.sql.gz"

# 日志文件
LOG_FILE="/var/log/mysql_backup.log"

# 确保备份目录存在
mkdir -p ${LOCAL_BACKUP_DIR}
mkdir -p ${LOCAL_BINLOG_DIR}

# 函数：记录日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> ${LOG_FILE}
}

# 函数：检查命令执行是否成功
check_status() {
    if [ $? -ne 0 ]; then
        log "ERROR: $1 failed."
        exit 1
    fi
}

# 1. 每日全量备份
log "Starting full backup for ${DB_NAME}..."
mysqldump -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} -p${DB_PASS} --single-transaction --routines --triggers --events ${DB_NAME} | gzip > ${LOCAL_BACKUP_DIR}/${FULL_BACKUP_FILE}
check_status "Full backup of ${DB_NAME}"

log "Full backup completed: ${FULL_BACKUP_FILE}"

# 2. 同步全量备份到异地存储
log "Starting to sync full backup to remote storage..."
rsync -avz -e "ssh -p ${REMOTE_PORT}" ${LOCAL_BACKUP_DIR}/${FULL_BACKUP_FILE} ${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/full/
check_status "Sync full backup to remote storage"

log "Full backup synced to remote storage."

# 3. 获取当前的二进制日志文件信息
log "Fetching current binary log information..."
CURRENT_BINLOG=$(mysql -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} -p${DB_PASS} -e "SHOW MASTER STATUS;" | grep -v "File" | awk '{print $1}')
check_status "Fetch current binary log information"

log "Current binary log: ${CURRENT_BINLOG}"

# 4. 实时同步二进制日志到异地存储
log "Starting real-time binary log sync..."
mysqlbinlog --read-from-remote-server --host=${DB_HOST} --port=${DB_PORT} --user=${DB_USER} --password=${DB_PASS} --raw --stop-never ${CURRENT_BINLOG} &
BINLOG_PID=$!
log "Binary log sync process started with PID: ${BINLOG_PID}"

# 5. 将二进制日志文件同步到本地临时目录后，再同步到异地存储
while true; do
    for binlog_file in $(ls /var/log/mysql/mysql-bin.* 2>/dev/null); do
        if [[ ! -f ${LOCAL_BINLOG_DIR}/$(basename ${binlog_file}) ]]; then
            cp ${binlog_file} ${LOCAL_BINLOG_DIR}/
            check_status "Copy binary log ${binlog_file} to local temp directory"
            log "Copied binary log: ${binlog_file}"
        fi
    done

    rsync -avz --delete -e "ssh -p ${REMOTE_PORT}" ${LOCAL_BINLOG_DIR}/ ${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/binlog/
    check_status "Sync binary logs to remote storage"
    log "Binary logs synced to remote storage."

    sleep 60  # 每分钟检查一次
done &

# 记录脚本启动完成
log "MySQL backup and sync script started successfully."
```

### 脚本说明

1. **全量备份**：
   - 使用 `mysqldump` 工具进行每日全量备份，支持 `--single-transaction` 以确保数据一致性（适用于 InnoDB 存储引擎）。
   - 备份文件以日期命名并压缩为 `.gz` 格式，存储在本地目录。
   - 使用 `rsync` 将全量备份文件同步到异地存储。

2. **增量日志同步**：
   - 通过 `mysqlbinlog --read-from-remote-server --stop-never` 实时读取 MySQL 的二进制日志。
   - 将二进制日志文件从 MySQL 日志目录复制到本地临时目录，然后通过 `rsync` 同步到异地存储。
   - 使用 `while true` 循环每分钟检查并同步新的二进制日志文件。

3. **异地存储**：
   - 使用 `rsync` 结合 SSH 进行文件传输，确保数据安全。
   - 需要在本地和异地服务器之间配置 SSH 免密登录（建议使用 SSH 密钥认证）。

4. **日志记录**：
   - 脚本执行过程会记录到指定的日志文件中，便于排查问题。

### 使用步骤

1. **环境准备**：
   - 确保 MySQL 8.0 已启用二进制日志（在 `my.cnf` 中设置 `log_bin = /var/log/mysql/mysql-bin`）。
   - 安装必要的工具：`mysqldump`、`mysqlbinlog`、`rsync`。
   - 配置 SSH 免密登录到异地存储服务器。

2. **脚本配置**：
   - 修改脚本中的数据库连接信息（`DB_HOST`、`DB_USER`、`DB_PASS` 等）。
   - 修改本地和异地备份目录路径（`LOCAL_BACKUP_DIR`、`REMOTE_BACKUP_DIR` 等）。
   - 修改异地存储服务器信息（`REMOTE_HOST`、`REMOTE_PORT`）。

3. **权限设置**：
   - 将脚本保存为 `/usr/local/bin/mysql_backup.sh`。
   - 设置执行权限：`chmod +x /usr/local/bin/mysql_backup.sh`。

4. **定时任务**：
   - 使用 `crontab` 设置每日全量备份时间，例如：
     ```
     0 2 * * * /usr/local/bin/mysql_backup.sh
     ```
     表示每天凌晨 2 点执行脚本。

5. **监控与维护**：
   - 定期检查日志文件（`/var/log/mysql_backup.log`）以确保备份和同步正常运行。
   - 清理旧的备份文件，避免磁盘空间不足（可添加清理逻辑到脚本中）。

### 注意事项

- **安全性**：确保备份用户权限最小化，仅赋予必要的权限（如 `SELECT`、`LOCK TABLES` 等）。
- **性能影响**：全量备份和二进制日志同步可能会对数据库性能产生影响，建议在低峰期执行。
- **存储空间**：定期清理旧备份和日志文件，避免本地和异地存储空间不足。
- **数据恢复测试**：定期测试备份文件的可用性，确保可以在需要时恢复数据。
- **网络稳定性**：异地同步依赖网络，建议监控网络状态并设置重试机制。

如果您有特定的环境或需求（如不同的异地存储方式、备份策略等），请告诉我，我可以进一步优化脚本。