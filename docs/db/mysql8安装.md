****此文档提供安装mysql8最新版8.0.2x****

****
#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘最大分区在哪！

## 在线安装mysql

### 卸载mariadb

```bash
rpm -qa |grep -i mariadb
yum remove -y mariadb-libs.x86_64
```

### 安装mysql

```bash
mkdir -p /data/mysql
yum install -y wget net-tools

wget https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm

yum localinstall -y mysql80-community-release-el7-3.noarch.rpm

yum search mysql-community-server
yum install -y mysql-community-server
```
### 优化mysql

```bash
cp /etc/my.cnf /etc/my.cnf.bak

cat > /etc/my.cnf <<EOF
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

#总内存16G时，设置成如下参数
#innodb_buffer_pool_chunk_size=536870912
#innodb_buffer_pool_instances=4
#innodb_buffer_pool_size=4294967296

sort_buffer_size=1048576

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
EOF
```
### 启动mysql

```bash
sed -i 's/LimitNOFILE = 10000/LimitNOFILE = 65500/g' /usr/lib/systemd/system/mysqld.service

systemctl daemon-reload

systemctl start mysqld
systemctl status mysqld
systemctl enable mysqld
```
### 修改密码

```bash
cat /var/log/mysqld.log | grep password
2021-12-14T14:31:37.753737Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: sRj4lo!!d.pM

mysql -u root -p
==> sRj4lo!!d.pM

ALTER USER "root"@"localhost" IDENTIFIED  BY "Abc123!@#";
exit;

mysql -u root -p
==>Abc123!@#
```
### 设置远程访问

```mysql
show databases;
use mysql;

select host,user from user \G;
update user set host= '%' where user = 'root';
flush privileges;
```
### 创建智慧校园平台所需的数据库和用户等

#略

## 离线安装mysql

#仅安装mysql部分不同，其他步骤相同
### 安装mysql
#找台外网开通的服务器
```bash
wget https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar
```
#将mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar拷贝至mysql服务器
```bash
tar -xvf mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar

rpm -ivh mysql-community-common-8.0.26-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-plugins-8.0.26-1.el7.x86_64.rpm

rpm -ivh mysql-community-libs-8.0.26-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-8.0.26-1.el7.x86_64.rpm

rpm -ivh mysql-community-server-8.0.26-1.el7.x86_64.rpm

```
#注意离线部署可能会缺少依赖包，比如perl，那么需要光盘制作个本地yum源进行安装
```bash
yum install -y perl
```

## mysql双主配置

#假如两台服务器IP为192.168.1.11/192.168.1.12，vip为192.168.1.13

### 配置my.cnf

#1.11添加
```
server_id=11
```
#1.12添加
```
server_id=12
```