要定期备份 Kingbase 数据库，可以编写一个 Shell 脚本，并结合 cron 作业来实现。以下是一个示例脚本及其设置方法：

### 步骤 1：编写备份脚本

首先，创建一个名为 `backup_kingbase.sh` 的脚本文件，并将以下内容复制到该文件中：

```sh
#!/bin/bash

# 配置备份路径
BACKUP_DIR="/path/to/backup/directory"
LOG_FILE="$BACKUP_DIR/backup.log"

# 配置Kingbase数据库信息
DB_NAME="your_database_name"
DB_USER="your_username"
DB_HOST="your_host"
DB_PORT="your_port"
DB_PASSWORD="your_password"

# 设置日期格式
DATE=$(date +'%Y%m%d_%H%M%S')

# 备份文件名
BACKUP_FILE="$BACKUP_DIR/$DB_NAME-$DATE.bak"

# 确保备份目录存在
mkdir -p $BACKUP_DIR

# 导出数据库
export PGPASSWORD=$DB_PASSWORD
kingbase_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -F c -b -v -f $BACKUP_FILE $DB_NAME

# 检查备份是否成功
if [ $? -eq 0 ]; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Backup successful: $BACKUP_FILE" >> $LOG_FILE
else
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Backup failed" >> $LOG_FILE
fi

# 删除超过30天的备份文件
find $BACKUP_DIR -type f -name "*.bak" -mtime +30 -exec rm {} \;
```

请根据实际情况替换脚本中的占位符：
- `/path/to/backup/directory`：备份文件的存储路径
- `your_database_name`：Kingbase 数据库的名称
- `your_username`：连接数据库的用户名
- `your_host`：数据库服务器的主机名
- `your_port`：数据库服务器的端口号
- `your_password`：连接数据库的密码

### 步骤 2：赋予脚本执行权限

在终端中运行以下命令，为脚本赋予执行权限：

```sh
chmod +x /path/to/backup_kingbase.sh
```

### 步骤 3：设置 cron 作业

要定期运行此脚本，可以使用 `cron`。编辑 crontab 文件：

```sh
crontab -e
```

添加以下行以每天凌晨 2 点执行备份脚本：

```sh
0 2 * * * /path/to/backup_kingbase.sh
```

保存并退出编辑器。

### 说明

- 脚本使用 `kingbase_dump` 工具进行备份，备份格式为压缩格式（`-F c`）。
- 每次备份都会生成一个带有时间戳的文件。
- 脚本会记录备份成功或失败的日志信息到 `$LOG_FILE`。
- 脚本会删除超过 30 天的旧备份文件，保持备份目录清洁。

按照上述步骤操作后，你的 Kingbase 数据库将定期备份，并且旧备份文件会自动清理。

===========

#全库备份

要定期备份 Kingbase 数据库的全库（即备份所有数据库），可以编写一个 Shell 脚本并结合 cron 作业来实现。以下是一个示例脚本及其设置方法：

### 步骤 1：编写全库备份脚本

首先，创建一个名为 `backup_all_kingbase.sh` 的脚本文件，并将以下内容复制到该文件中：

```sh
#!/bin/bash

# 配置备份路径
BACKUP_DIR="/path/to/backup/directory"
LOG_FILE="$BACKUP_DIR/backup.log"

# 配置Kingbase数据库信息
DB_USER="your_username"
DB_HOST="your_host"
DB_PORT="your_port"
DB_PASSWORD="your_password"

# 设置日期格式
DATE=$(date +'%Y%m%d_%H%M%S')

# 备份文件名
BACKUP_FILE="$BACKUP_DIR/all_databases-$DATE.bak"

# 确保备份目录存在
mkdir -p $BACKUP_DIR

# 导出全库数据库
export PGPASSWORD=$DB_PASSWORD
kingbase_dumpall -h $DB_HOST -p $DB_PORT -U $DB_USER -f $BACKUP_FILE

# 检查备份是否成功
if [ $? -eq 0 ]; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Full backup successful: $BACKUP_FILE" >> $LOG_FILE
else
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Full backup failed" >> $LOG_FILE
fi

# 删除超过30天的备份文件
find $BACKUP_DIR -type f -name "*.bak" -mtime +30 -exec rm {} \;
```

请根据实际情况替换脚本中的占位符：
- `/path/to/backup/directory`：备份文件的存储路径
- `your_username`：连接数据库的用户名
- `your_host`：数据库服务器的主机名
- `your_port`：数据库服务器的端口号
- `your_password`：连接数据库的密码

### 步骤 2：赋予脚本执行权限

在终端中运行以下命令，为脚本赋予执行权限：

```sh
chmod +x /path/to/backup_all_kingbase.sh
```

### 步骤 3：设置 cron 作业

要定期运行此脚本，可以使用 `cron`。编辑 crontab 文件：

```sh
crontab -e
```

添加以下行以每天凌晨 2 点执行备份脚本：

```sh
0 2 * * * /path/to/backup_all_kingbase.sh
```

保存并退出编辑器。

### 说明

- 脚本使用 `kingbase_dumpall` 工具进行全库备份。
- 每次备份都会生成一个带有时间戳的文件。
- 脚本会记录备份成功或失败的日志信息到 `$LOG_FILE`。
- 脚本会删除超过 30 天的旧备份文件，保持备份目录清洁。

按照上述步骤操作后，你的 Kingbase 数据库全库将定期备份，并且旧备份文件会自动清理。