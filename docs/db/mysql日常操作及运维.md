****mysql日常操作及运维****

<strong style="color:red;">生产环境注意操作安全！！！</strong>

### 日常操作
#登录mysql

```bash
mysql -u root -p
```

#库相关操作

```mysql
show databases;

create database test1 character set utf8mb4 collate utf8mb4_unicode_ci;

drop database test1;
```

##表相关操作

```mysql
use test1;

show tables;

create table table1 (id varchar(20),age char(1));

desc table1;

analyze table table1;

show index from table1;

drop table table1;

```

#用户相关操作

```mysql
set global validate_password.policy=0;

set global validate_password.length=1;

create user 'admin_center'@'%' identified with mysql_native_password  by 'Abc123!@#';

grant all privileges on  admin_center.* to 'admin_center'@'%' with grant option;

flush privileges;

drop user  'admin_center'@'%' ;
```

#性能查询相关
##可以通过mysql-adminer管理，更直观点

```mysql
show processlist;

select * from information_schema.innodb_trx;

select * from performance_schema.data_lock_waits;

select * from performance_schema.data_locks;

kill sql_pid;
```

#查看执行计划

```mysql
explain select xxxx from xxx left join xxxxxx where xxx=xxxx;
```

### 备份
#表的备份

```mysql
create table test1 as select * from TB_ACCOUNT;
```

#库的备份
##单个库的备份

```bash
/usr/bin/mysqldump -u root -p --quick --events --databases cas_server --master-data=2 --single-transaction --set-gtid-purged=OFF > 20211216cas_server.sql
```

##全库备份

```bash
/usr/bin/mysqldump -u root -p --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > 20211216full.sql
```
#定期备份

#创建备份目录及脚本，注意分区容量

```bash
mkdir -p /data/backup
touch /data/backup/mysqlbackup.sh
chmod a+x /data/backup/mysqlbackup.sh

cat > /data/backup/mysqlbackup.sh <<'EOF'
#!/bin/bash
# mysql 数据库全量备份

# 用户名和密码，注意实际情况！也可以在/etc/my.cnf中配置
username="root"
mypasswd="Abc123!@#"

beginTime=`date +"%Y年%m月%d日 %H:%M:%S"`

# 备份目录,注意实际环境目录
bakDir=/data/backup
# 日志文件
logFile=/data/backup/bak.log
# 备份文件
nowDate=`date +%Y%m%d`
dumpFile="mysql_${nowDate}.sql"
gzDumpFile="mysql_${nowDate}.sql.tgz"

cd $bakDir
# 全量备份
/usr/bin/mysqldump -u${username} -p${mypasswd} --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > $dumpFile
# 打包
/usr/bin/tar -zvcf $gzDumpFile $dumpFile
/usr/bin/rm $dumpFile

endTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo 开始:$beginTime 结束:$endTime $gzDumpFile succ >> $logFile

##删除过期备份
find $bakDir -name 'mysql_*.sql.tgz' -mtime +7 -exec rm {} \;

EOF

```

#调度任务，每天1点10分做全库备份

```bash
crontab -e
```
#添加内容

```
10 1 * * * /usr/bin/bash -x /data/backup/mysqlbackup.sh >/dev/null 2>&1
```







