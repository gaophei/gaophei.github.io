###安装mysql8

1、卸载mariadb

```bash
rpm -qa |grep -i mariadb
yum remove -y mariadb-libs.x86_64
```

2、安装mysql

```bash
mkdir -p /data/mysql
wget https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm

yum localinstall -y mysql80-community-release-el7-3.noarch.rpm
yum search mysql-community-server
yum install -y mysql-community-server
```

###/etc/my.cnf

```mysql
[mysqld]
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
port=3306
character-set-server=utf8mb4
default-time_zone='+8:00'
lower_case_table_names=1

binlog_format=ROW
log-bin=mysql-bin
binlog_expire_logs_seconds=604800
max_binlog_size = 100M

max_connections=2000
max_connect_errors=100000

##bufer大小根据实际内存调整，此例为32G总内存
innodb_buffer_pool_chunk_size=1073741824
innodb_buffer_pool_instances=4
innodb_buffer_pool_size=8589934592

default_authentication_plugin=mysql_native_password
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock

log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid


skip_name_resolve = 1


long_query_time=15
slow_query_log = 1
slow_query_log_file=/var/lib/mysql/slow.log



[client]
port=3306
default-character-set=utf8mb4
socket=/var/lib/mysql/mysql.sock

[mysql]
no-auto-rehash
default-character-set=utf8mb4

```



##启动mysql

```bash
systemctl start mysqld
systemctl status mysqld
systemctl enable mysqld
```



3、修改密码

```bash
cat /var/log/mysqld.log | grep password
2020-10-21T09:31:37.753737Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: sRj4lo!!d.pM

mysql -u root -p
==> sRj4lo!!d.pM

set global validate_password.policy=0;
set global validate_password.length=1;
ALTER USER "root"@"localhost" IDENTIFIED  BY "Abc123!@#";
exit;
mysql -u root -p
==>Abc123!@#

```



4、设置远程访问

```mysql
show databases;
use mysql;

select host,user from user \G;
update user set host= '%' where user = 'root';
flush privileges;
```



5、重置密码

vim /etc/my.cnf     

\##在【mysqld】模块下面添加：skip-grant-tables 保存退出。

 

```bash
systemctl restart mysqld

mysql -u root -p  

###不输入密码直接敲回车键
use mysql   

\#把密码置空(因为免密登陆时不能直接修改密码) 

update user set authentication_string='' where user='root';

flush privileges;

ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'Bac321!@#';


```







