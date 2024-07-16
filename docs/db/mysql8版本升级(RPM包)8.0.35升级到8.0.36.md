本文档介绍RPM包的升级方法。

如果条件允许，请使用操作系统发行版的包管理器来升级，比如`yum`和`apt-get`。

## 0、mysql当前版本

```bash
mysql -V

rpm -qa|grep mysql
```

#log

```bash

[root@mysql ~]# mysql -V
mysql  Ver 8.0.31 for Linux on x86_64 (MySQL Community Server - GPL)


[root@mysql ~]# rpm -qa|grep mysql
mysql80-community-release-el7-3.noarch
mysql-community-client-8.0.31-1.el7.x86_64
mysql-community-icu-data-files-8.0.31-1.el7.x86_64
mysql-community-client-plugins-8.0.31-1.el7.x86_64
mysql-community-libs-8.0.31-1.el7.x86_64
mysql-community-server-8.0.31-1.el7.x86_64
mysql-community-common-8.0.31-1.el7.x86_64
[root@mysql ~]#
```



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
/usr/bin/mysqldump -u root -p --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > 20231212001.sql
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
set global log_error_suppression_list = 'MY-013360';
#修改my.cnf
log_error_suppression_list = 'MY-013360'

mysqld --upgrade=NONE
```

## 6、查看版本

```bash
mysql -V

mysql -u root -p
```

#log

```bash
[root@mysql mysql]# mysql -V
mysql  Ver 8.0.35 for Linux on x86_64 (MySQL Community Server - GPL)
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
source /root/20231212001.sql
```

**冷备恢复方法：**

```bash
systemctl stop mysqld
rm -rf /var/lib/mysql
cp -rf /var/lib/mysql_bak /var/lib/mysql
```

**虚拟机备份恢复方法：**

服务器关机，然后执行虚拟机备份恢复。

## 整个过程日志
```bash
[root@mysql ~]# wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar
--2023-12-12 17:02:17--  https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar
Resolving dev.mysql.com (dev.mysql.com)... 23.66.135.36, 2600:1406:5600:2a9::2e31, 2600:1406:5600:291::2e31
Connecting to dev.mysql.com (dev.mysql.com)|23.66.135.36|:443... connected.
HTTP request sent, awaiting response... 302 Moved Temporarily
Location: https://cdn.mysql.com//Downloads/MySQL-8.0/mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar [following]
--2023-12-12 17:02:18--  https://cdn.mysql.com//Downloads/MySQL-8.0/mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar
Resolving cdn.mysql.com (cdn.mysql.com)... 23.2.142.104, 2600:140b:2:58f::1d68, 2600:140b:2:593::1d68
Connecting to cdn.mysql.com (cdn.mysql.com)|23.2.142.104|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1028679680 (981M) [application/x-tar]
Saving to: ‘mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar’

100%[============================================================================================================================================================================

2023-12-12 17:03:53 (10.4 MB/s) - ‘mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar’ saved [1028679680/1028679680]

[root@mysql ~]# tar -xvf mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar
mysql-community-client-8.0.35-1.el7.x86_64.rpm
mysql-community-client-plugins-8.0.35-1.el7.x86_64.rpm
mysql-community-common-8.0.35-1.el7.x86_64.rpm
mysql-community-debuginfo-8.0.35-1.el7.x86_64.rpm
mysql-community-devel-8.0.35-1.el7.x86_64.rpm
mysql-community-embedded-compat-8.0.35-1.el7.x86_64.rpm
mysql-community-icu-data-files-8.0.35-1.el7.x86_64.rpm
mysql-community-libs-8.0.35-1.el7.x86_64.rpm
mysql-community-libs-compat-8.0.35-1.el7.x86_64.rpm
mysql-community-server-8.0.35-1.el7.x86_64.rpm
mysql-community-server-debug-8.0.35-1.el7.x86_64.rpm
mysql-community-test-8.0.35-1.el7.x86_64.rpm


[root@mysql ~]# mkdir mysql
[root@mysql ~]# mv mysql-* mysql
[root@mysql ~]# ls
anaconda-ks.cfg  daclient  daclient.tar.gz  deploy.log  ics_agent.py  mysql  openssh-9.5p1  openssh-9.5p1.tar.gz  openssl-1.1.1w  openssl-1.1.1w.tar.gz  package_list
[root@mysql ~]# cd mysql/
[root@mysql mysql]# ls
mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar                mysql-community-common-8.0.35-1.el7.x86_64.rpm     mysql-community-embedded-compat-8.0.35-1.el7.x86_64.rpm  mysql-communi
mysql-community-client-8.0.35-1.el7.x86_64.rpm          mysql-community-debuginfo-8.0.35-1.el7.x86_64.rpm  mysql-community-icu-data-files-8.0.35-1.el7.x86_64.rpm   mysql-communi
mysql-community-client-plugins-8.0.35-1.el7.x86_64.rpm  mysql-community-devel-8.0.35-1.el7.x86_64.rpm      mysql-community-libs-8.0.35-1.el7.x86_64.rpm             mysql-communi
[root@mysql mysql]# 



[root@mysql mysql]# cd /data/
[root@mysql data]# ls
backup
[root@mysql data]# cd backup/
[root@mysql backup]# ll -rth
total 2.6G
-rwxr-xr-x 1 root root  862 Nov 18  2022 mysqlbackup.sh
-rw-r--r-- 1 root root 316M Dec  5 01:31 mysql_20231205.sql.tgz
-rw-r--r-- 1 root root 319M Dec  6 01:31 mysql_20231206.sql.tgz
-rw-r--r-- 1 root root 321M Dec  7 01:31 mysql_20231207.sql.tgz
-rw-r--r-- 1 root root 323M Dec  8 01:31 mysql_20231208.sql.tgz
-rw-r--r-- 1 root root 325M Dec  9 01:31 mysql_20231209.sql.tgz
-rw-r--r-- 1 root root 326M Dec 10 01:31 mysql_20231210.sql.tgz
-rw-r--r-- 1 root root 328M Dec 11 01:31 mysql_20231211.sql.tgz
-rw-r--r-- 1 root root 330M Dec 12 01:31 mysql_20231212.sql.tgz
-rw-r--r-- 1 root root  37K Dec 12 01:31 bak.log

[root@mysql backup]# mysqldump -u root -p --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > 20231212001.sql
WARNING: --master-data is deprecated and will be removed in a future version. Use --source-data instead.
Enter password:
[root@mysql backup]#
[root@mysql backup]# mysql -u root -p --execute="SET GLOBAL innodb_fast_shutdown=0"
Enter password:
[root@mysql backup]# systemctl stop mysqld
[root@mysql backup]# cd
[root@mysql ~]# ls
anaconda-ks.cfg  daclient  daclient.tar.gz  deploy.log  ics_agent.py  mysql  openssh-9.5p1  openssh-9.5p1.tar.gz  openssl-1.1.1w  openssl-1.1.1w.tar.gz  package_list
[root@mysql ~]# cd mysql/
[root@mysql mysql]# ls
mysql-8.0.35-1.el7.x86_64.rpm-bundle.tar                mysql-community-devel-8.0.35-1.el7.x86_64.rpm            mysql-community-server-8.0.35-1.el7.x86_64.rpm
mysql-community-client-8.0.35-1.el7.x86_64.rpm          mysql-community-embedded-compat-8.0.35-1.el7.x86_64.rpm  mysql-community-server-debug-8.0.35-1.el7.x86_64.rpm
mysql-community-client-plugins-8.0.35-1.el7.x86_64.rpm  mysql-community-icu-data-files-8.0.35-1.el7.x86_64.rpm   mysql-community-test-8.0.35-1.el7.x86_64.rpm
mysql-community-common-8.0.35-1.el7.x86_64.rpm          mysql-community-libs-8.0.35-1.el7.x86_64.rpm
mysql-community-debuginfo-8.0.35-1.el7.x86_64.rpm       mysql-community-libs-compat-8.0.35-1.el7.x86_64.rpm
[root@mysql mysql]# rpm -Uvh  *.rpm  --nodeps --force
warning: mysql-community-client-8.0.35-1.el7.x86_64.rpm: Header V4 RSA/SHA256 Signature, key ID 3a79bd29: NOKEY
Preparing...                          ################################# [100%]
Updating / installing...
   1:mysql-community-common-8.0.35-1.e################################# [  6%]
   2:mysql-community-client-plugins-8.################################# [ 11%]
   3:mysql-community-libs-8.0.35-1.el7################################# [ 17%]
   4:mysql-community-client-8.0.35-1.e################################# [ 22%]
   5:mysql-community-icu-data-files-8.################################# [ 28%]
   6:mysql-community-server-8.0.35-1.e################################# [ 33%]
   7:mysql-community-server-debug-8.0.################################# [ 39%]
   8:mysql-community-test-8.0.35-1.el7################################# [ 44%]
   9:mysql-community-devel-8.0.35-1.el################################# [ 50%]
  10:mysql-community-libs-compat-8.0.3################################# [ 56%]
  11:mysql-community-embedded-compat-8################################# [ 61%]
  12:mysql-community-debuginfo-8.0.35-################################# [ 67%]
Cleaning up / removing...
  13:mysql-community-server-8.0.31-1.e################################# [ 72%]
  14:mysql-community-icu-data-files-8.################################# [ 78%]
  15:mysql-community-client-8.0.31-1.e################################# [ 83%]
  16:mysql-community-libs-8.0.31-1.el7################################# [ 89%]
  17:mysql-community-common-8.0.31-1.e################################# [ 94%]
  18:mysql-community-client-plugins-8.################################# [100%]
[root@mysql mysql]# systemctl start mysqld
[root@mysql mysql]# systemctl status mysqld
● mysqld.service - MySQL Server
   Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2023-12-12 22:44:26 CST; 10s ago
     Docs: man:mysqld(8)
           http://dev.mysql.com/doc/refman/en/using-systemd.html
  Process: 13725 ExecStartPre=/usr/bin/mysqld_pre_systemd (code=exited, status=0/SUCCESS)
 Main PID: 13756 (mysqld)
   Status: "Server is operational"
   CGroup: /system.slice/mysqld.service
           └─13756 /usr/sbin/mysqld

Dec 12 22:44:17 mysql systemd[1]: Starting MySQL Server...
Dec 12 22:44:26 mysql systemd[1]: Started MySQL Server.
[root@mysql mysql]# vi /etc/my.cnf
[root@mysql mysql]# mysql -u root -p
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 84
Server version: 8.0.35 MySQL Community Server - GPL

Copyright (c) 2000, 2023, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> set global log_error_suppression_list = 'MY-013360';
Query OK, 0 rows affected (0.00 sec)

mysql> exit
Bye
[root@mysql mysql]# mysqld --upgrade=NONE
2023-12-12T14:45:44.392369Z 0 [Warning] [MY-011070] [Server] 'binlog_format' is deprecated and will be removed in a future release.
2023-12-12T14:45:44.394661Z 0 [Warning] [MY-010918] [Server] 'default_authentication_plugin' is deprecated and will be removed in a future release. Please use authentication_policy instead.
2023-12-12T14:45:44.394690Z 0 [System] [MY-010116] [Server] /usr/sbin/mysqld (mysqld 8.0.35) starting as process 31494
2023-12-12T14:45:44.396827Z 0 [ERROR] [MY-010123] [Server] Fatal error: Please read "Security" section of the manual to find out how to run mysqld as root!
2023-12-12T14:45:44.396890Z 0 [ERROR] [MY-010119] [Server] Aborting
2023-12-12T14:45:44.397395Z 0 [System] [MY-010910] [Server] /usr/sbin/mysqld: Shutdown complete (mysqld 8.0.35)  MySQL Community Server - GPL.
[root@mysql mysql]# mysql -V
mysql  Ver 8.0.35 for Linux on x86_64 (MySQL Community Server - GPL)
[root@mysql mysql]#

```