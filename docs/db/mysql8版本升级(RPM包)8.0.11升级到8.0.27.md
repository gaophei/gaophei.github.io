# mysql8版本升级(RPM包)8.0.11升级到8.0.25

#### 1、备份数据库

```
[root@node42 ~]# mysqldump -uroot -p --all-databases >backupall.sql
```

#### 2、关闭mysql

```
[root@node42 ~]# systemctl stop mysqld
```

#### 3、上传RPM包

```
-rw-r--r--  1 root root  46M Sep  6 13:28 mysql-community-client-8.0.25-1.el7.x86_64.rpm
-rw-r--r--  1 root root 4.1M Sep  6 13:28 mysql-community-libs-8.0.25-1.el7.x86_64.rpm
-rw-r--r--  1 root root 428M Sep  6 13:28 mysql-community-server-8.0.25-1.el7.x86_64.rpm
-rw-r--r--  1 root root 615K Sep  6 13:28 mysql-community-common-8.0.25-1.el7.x86_64.rpm
```

#### 4、强制进行数据字典升级和服务升级安装

```
[root@node42 ~]# rpm -ivh mysql-community-common-8.0.25-1.el7.x86_64.rpm --nodeps --force
warning: mysql-community-common-8.0.25-1.el7.x86_64.rpm: Header V3 DSA/SHA1 Signature, key ID 5072e1f5: NOKEY
Preparing...                          ################################# [100%]
Updating / installing...
   1:mysql-community-common-8.0.25-1.e################################# [100%]
[root@node42 ~]# rpm -ivh mysql-community-libs-8.0.25-1.el7.x86_64.rpm --nodeps --force
warning: mysql-community-libs-8.0.25-1.el7.x86_64.rpm: Header V3 DSA/SHA1 Signature, key ID 5072e1f5: NOKEY
Preparing...                          ################################# [100%]
Updating / installing...
   1:mysql-community-libs-8.0.25-1.el7################################# [100%]
[root@node42 ~]# rpm -ivh mysql-community-client-8.0.25-1.el7.x86_64.rpm --nodeps --force
warning: mysql-community-client-8.0.25-1.el7.x86_64.rpm: Header V3 DSA/SHA1 Signature, key ID 5072e1f5: NOKEY
Preparing...                          ################################# [100%]
Updating / installing...
   1:mysql-community-client-8.0.25-1.e################################# [100%]
[root@node42 ~]# rpm -ivh mysql-community-server-8.0.25-1.el7.x86_64.rpm --nodeps --force
warning: mysql-community-server-8.0.25-1.el7.x86_64.rpm: Header V3 DSA/SHA1 Signature, key ID 5072e1f5: NOKEY
Preparing...                          ################################# [100%]
Updating / installing...
   1:mysql-community-server-8.0.25-1.e################################# [100%]
```

#### 5、查找已安装的mysql

```
[root@node42 ~]# rpm -qa |grep mysql
mysql-community-common-8.0.11-1.el7.x86_64
mysql-community-libs-8.0.25-1.el7.x86_64
mysql-community-client-8.0.11-1.el7.x86_64
mysql-community-client-8.0.25-1.el7.x86_64
mysql-community-server-8.0.11-1.el7.x86_64
mysql-community-server-8.0.25-1.el7.x86_64
mysql-community-common-8.0.25-1.el7.x86_64
mysql-community-libs-8.0.11-1.el7.x86_64
```

#### 6、删除查找到的上个版本的安装包

```
[root@node42 ~]# rpm -e mysql-community-common-8.0.11-1.el7.x86_64^C
[root@node42 ~]# rpm -e mysql-community-server-8.0.11-1.el7.x86_64
[root@node42 ~]# rpm -e mysql-community-client-8.0.11-1.el7.x86_64
[root@node42 ~]# rpm -e mysql-community-libs-8.0.11-1.el7.x86_64
[root@node42 ~]# rpm -e mysql-community-common-8.0.11-1.el7.x86_64
[root@node42 ~]# rpm -qa |grep mysql
mysql-community-libs-8.0.25-1.el7.x86_64
mysql-community-client-8.0.25-1.el7.x86_64
mysql-community-server-8.0.25-1.el7.x86_64
mysql-community-common-8.0.25-1.el7.x86_64
```

#### 7、启动mysql

```
[root@node42 ~]# systemctl start mysqld
```

#### 8、查看是否启动

```
[root@node42 ~]# ps -ef|grep mysql
mysql     5061     1  4 13:40 ?        00:00:28 /usr/sbin/mysqld
root      5425  4663  0 13:51 pts/0    00:00:00 grep --color=auto mysql
```

#### 9、登录数据库查看版本



```
[root@node42 ~]# mysql -uroot -p
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 120
Server version: 8.0.25 MySQL Community Server - GPL

Copyright (c) 2000, 2021, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> \s
--------------
mysql  Ver 8.0.25 for Linux on x86_64 (MySQL Community Server - GPL)

Connection id:          120
Current database:
Current user:           root@localhost
SSL:                    Not in use
Current pager:          stdout
Using outfile:          ''
Using delimiter:        ;
Server version:         8.0.25 MySQL Community Server - GPL
Protocol version:       10
Connection:             Localhost via UNIX socket
Server characterset:    utf8mb4
Db     characterset:    utf8mb4
Client characterset:    utf8mb4
Conn.  characterset:    utf8mb4
UNIX socket:            /var/lib/mysql/mysql.sock
Binary data as:         Hexadecimal
Uptime:                 11 min 5 sec

Threads: 2  Questions: 2009  Slow queries: 0  Opens: 908  Flush tables: 6  Open tables: 296  Queries per second avg: 3.021
--------------
```
