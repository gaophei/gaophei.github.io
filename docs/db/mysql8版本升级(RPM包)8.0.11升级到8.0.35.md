本文档介绍RPM包的升级方法。

如果条件允许，请使用操作系统发行版的包管理器来升级，比如`yum`和`apt-get`。

## 1、下载最新安装包

```bash
#wget https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.28-1.el7.x86_64.rpm-bundle.tar
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar

tar -xvf mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar
```

## 2、备份数据库

有三种备份方式，根据实际情况选择一种或多种。

**热备（MySQL关闭前执行）：**

占用磁盘空间最小，比较可靠。

```bash
/usr/bin/mysqldump -u root -p --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > 20220117001.sql
```

**冷备（MySQL关闭后，升级前执行）：**

占用磁盘空间最大，最可靠，因此执行前需注意服务器磁盘大小。

```bash
systemctl stop mysqld
cp -rf /var/lib/mysql /var/lib/mysql_bak
```

**虚拟机备份（MySQL关闭后，升级前执行）：**

通过虚拟机磁盘快照/备份的方式，对MySQL服务器进行备份。

```
#此步需联系学校执行
#首先关闭数据库
systemctl stop mysqld
#关闭虚拟机
poweoff
#虚拟机打快照
```

## 3、清理缓存并关闭mysql

```bash
mysql -u root -p --execute="SET GLOBAL innodb_fast_shutdown=0"
#mysql -u root -p --execute="SET GLOBAL innodb_fast_shutdown=0" --socket=/home/mysql/data/mysql.sock

systemctl stop mysqld
```

## 4、mysql数据库升级

```bash
rpm -Uvh  *.rpm  --nodeps --force
```

## 5、启动、升级

```bash
systemctl start mysqld
systemctl status mysqld
tail -f /var/log/mysqld.log

#如果mysqld.log报错：
2023-11-09T10:57:00.810720Z 400 [Warning] [MY-013360] [Server] Plugin mysql_native_password reported: ''mysql_native_password' is deprecated and will be removed in a future release. Please use caching_sha2_password instead'

#mysql里修改
set global log_error_suppression_list = 'MY-013360'
#修改my.cnf
log_error_suppression_list = 'MY-013360'

mysqld --upgrade=NONE
```

## 6、查看版本

```bash
mysql -V

mysql -u root -p
```

## 7、检查rancher里的pod运行情况

```
#比如认证中的POD：cas-server-sa-api，看看是否有连接数据库报错
```

## 数据恢复

如果数据库出现数据问题，进行数据库还原，如果正常，本步忽略。

**热备恢复方法：**

```bash
mysql -u root -p
```

```mysql
source /root/20220117001.sql
```

**冷备恢复方法：**

```bash
systemctl stop mysqld
rm -rf /var/lib/mysql
cp -rf /var/lib/mysql_bak /var/lib/mysql
```

**虚拟机备份恢复方法：**

服务器关机，然后执行虚拟机备份恢复。