****此文档提供安装mysql8(最新版8.0.34)双主高可用模式的安装****

****

#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小，mysql安装到最大分区里
#20211228补充OS优化部分，安装版本为8.0.34

## 服务器资源

#建议

```
vm: 16核/32G 

OS: ubuntu 22.04

磁盘LVM管理，／为最大分区

本次服务器：
minio03 --- ubuntu22.04
minio04 --- ubuntu22.04
```

## 部署过程

### 一、系统优化

#### 1、Hostname修改

#hostname命名建议规范，以实际IP为准

```bash
cat >> /etc/hosts <<EOF
10.20.12.126 minio03
10.20.12.127 minio04
EOF

#minio03
hostnamectl set-hostname minio03
#minio04
hostnamectl set-hostname minio04

hostnamectl status

#ubuntu安装Ping命令
apt install -y iputils-ping

ping minio03
ping minio04

```

#### 2、关闭防火墙和selinux

```bash
#ubuntu关闭防火墙
ufw status
ufw disable
```

#### 3、修改源文件

```bash
#ubuntu 22.04
cat >> /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/ubuntu jammy main restricted
deb http://mirrors.aliyun.com/ubuntu jammy-updates main restricted
deb http://mirrors.aliyun.com/ubuntu jammy universe
deb http://mirrors.aliyun.com/ubuntu jammy-updates universe
deb http://mirrors.aliyun.com/ubuntu jammy multiverse
deb http://mirrors.aliyun.com/ubuntu jammy-updates multiverse
deb http://mirrors.aliyun.com/ubuntu jammy-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu jammy-security main restricted
deb http://mirrors.aliyun.com/ubuntu jammy-security universe
deb http://mirrors.aliyun.com/ubuntu jammy-security multiverse
EOF

apt update

#ubuntu 20.04
cat >> /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted
deb http://mirrors.aliyun.com/ubuntu/ focal universe
deb http://mirrors.aliyun.com/ubuntu/ focal-updates universe
deb http://mirrors.aliyun.com/ubuntu/ focal multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted
deb http://mirrors.aliyun.com/ubuntu/ focal-security universe
deb http://mirrors.aliyun.com/ubuntu/ focal-security multiverse
EOF

apt update
```

#### 4、开始时间同步及修改东8区

```bash
#安装
#centos7.9
yum install -y ntp
#ubuntu 22.04
apt install -y ntp

#centos启动
systemctl start ntpd
system enable ntpd

#ubuntu启动
systemctl start ntp
system enable ntp

vi /etc/ntp.conf
#注释下面4行
#server 0.centos.pool.ntp.org iburst
#server 1.centos.pool.ntp.org iburst
#server 2.centos.pool.ntp.org iburst
#server 3.centos.pool.ntp.org iburst

#学校ntp服务器
#centos7.9配置
server times.neuq.edu.cn iburst
#ubuntu22.04
pool times.neuq.edu.cn iburst

#替换成中国时间服务器
#http://www.pool.ntp.org/zone/cn
server 0.cn.pool.ntp.org
server 1.cn.pool.ntp.org
server 2.cn.pool.ntp.org
server 3.cn.pool.ntp.org

#centos重启ntpd
systemctl restart ntpd

#ubuntu重启ntp
systemctl restart ntp

date -R
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
```

#### 5、语言修改为utf8---centos7.9

```bash
sudo echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```

#### 6、内核模块调优

##### 1）内核模块

```bash
echo "
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_interval=60
net.ipv4.neigh.default.gc_stale_time=120

# 参考 https://github.com/prometheus/node_exporter#disabled-by-default
kernel.perf_event_paranoid=-1

#sysctls for k8s node config
net.ipv4.tcp_slow_start_after_idle=0
net.core.rmem_max=16777216
fs.inotify.max_user_watches=524288
kernel.softlockup_all_cpu_backtrace=1

kernel.softlockup_panic=0

kernel.watchdog_thresh=30
fs.file-max=2097152
fs.inotify.max_user_instances=8192
fs.inotify.max_queued_events=16384
vm.max_map_count=262144
fs.may_detach_mounts=1
net.core.netdev_max_backlog=16384
net.ipv4.tcp_wmem=4096 12582912 16777216
net.core.wmem_max=16777216
net.core.somaxconn=32768
net.ipv4.ip_forward=1
net.ipv4.tcp_max_syn_backlog=8096
net.ipv4.tcp_rmem=4096 12582912 16777216

###如果学校开启IPv6，则必须为0
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

kernel.yama.ptrace_scope=0
vm.swappiness=0

# 可以控制core文件的文件名中是否添加pid作为扩展。
kernel.core_uses_pid=1

# Do not accept source routing
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0

# Promote secondary addresses when the primary address is removed
net.ipv4.conf.default.promote_secondaries=1
net.ipv4.conf.all.promote_secondaries=1

# Enable hard and soft link protection
fs.protected_hardlinks=1
fs.protected_symlinks=1
# 源路由验证
# see details in https://help.aliyun.com/knowledge_detail/39428.html
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2
# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_synack_retries=2
kernel.sysrq=1
" >> /etc/sysctl.conf

sysctl -p
```

##### 2)open-files

```bash
#centos7.9
sudo sed -i 's/4096/90000/g' /etc/security/limits.d/20-nproc.conf

cat >> /etc/security/limits.conf <<EOF

*            soft    nofile          65536
*            hard    nofile          65536
*            soft    core            unlimited
*            hard    core            unlimited
*            soft    sigpending      90000
*            hard    sigpending      90000
*            soft    nproc           90000
*            hard    nproc           90000

EOF

#ubuntu 22.04
cat >> /etc/security/limits.conf <<EOF

root            soft    nofile          65536
root            hard    nofile          65536
root            soft    core            unlimited
root            hard    core            unlimited
root            soft    sigpending      90000
root            hard    sigpending      90000
root            soft    nproc           90000
root            hard    nproc           90000

EOF
```

### 二、在线安装mysql---centos7.9

#### 1、卸载mariadb

```bash
rpm -qa |grep -i mariadb
yum remove -y mariadb-libs.x86_64
```

#### 2、安装mysql

```bash
yum install -y wget net-tools

#8.0.34
wget https://dev.mysql.com/get/mysql80-community-release-el7-10.noarch.rpm

yum localinstall -y mysql80-community-release-el7-10.noarch.rpm

yum search mysql-community-server
yum install -y mysql-community-server
```

#### 3、优化mysql

##### 1) /etc/my.cnf

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

##### 2) mysqld.server

```bash
sed -i 's/LimitNOFILE = 10000/LimitNOFILE = 65500/g' /usr/lib/systemd/system/mysqld.service
```

#### 4、启动mysql

```bash
systemctl daemon-reload

systemctl start mysqld
systemctl status mysqld
systemctl enable mysqld
```

#### 5、修改密码

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

#### 6、设置远程访问

```mysql
show databases;
use mysql;

select host,user from user \G;
update user set host= '%' where user = 'root';
flush privileges;
```

### 三、离线安装mysql---可选---centos7.9

#仅与在线安装mysql中的安装部分不同，其他步骤相同

#### 离线安装mysql

#找台外网开通的服务器

```bash
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.34-1.el7.x86_64.rpm-bundle.tar
```

#将mysql-8.0.34-1.el7.x86_64.rpm-bundle.tar拷贝至mysql服务器

```bash
tar -xvf mysql-8.0.34-1.el7.x86_64.rpm-bundle.tar

rpm -ivh mysql-community-common-8.0.34-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-plugins-8.0.34-1.el7.x86_64.rpm

rpm -ivh mysql-community-libs-8.0.34-1.el7.x86_64.rpm

rpm -ivh mysql-community-libs-compat-8.0.34-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-8.0.34-1.el7.x86_64.rpm

rpm -ivh mysql-community-server-8.0.34-1.el7.x86_64.rpm

```

#注意离线部署可能会缺少依赖包，比如perl，那么需要光盘制作个本地yum源进行安装

```bash
yum install -y perl
```

### 四、在线安装mysql---ubuntu22.04---需要在root用户下(或者sudo安装)

#### 1、卸载mariadb

```bash
sudo su - 
dpkg -l |grep -i mariadb
apt remove -y mariadb-libs.x86_64
#卸载旧版本
apt autoremove -y mysql-server-8.0
```

#### 2、安装mysql

```bash
apt update

apt-cache search mysql-server
apt info -a mysql-server-8.0

apt install -y mysql-server-8.0
```

#### 3、优化mysql

##### 1) /etc/my.cnf

```bash
cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.old

cat > /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
#
# The MySQL database server configuration file.
#
# One can use all long options that the program supports.
# Run program with --help to get a list of available options and with
# --print-defaults to see which it would actually understand and use.
#
# For explanations see
# http://dev.mysql.com/doc/mysql/en/server-system-variables.html

# Here is entries for some specific programs
# The following values assume you have at least 32M ram

[mysqld]
#
# * Basic Settings
#
user		= mysql
pid-file	= /var/run/mysqld/mysqld.pid
socket	= /var/run/mysqld/mysqld.sock
port		= 3306
datadir	= /var/lib/mysql

#初始化参数，无法后面修改
#lower_case_table_names = 1

default-time-zone = "+8:00"
#character_set_server  =  utf8mb4


# If MySQL is running as a replication slave, this should be
# changed. Ref https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_tmpdir
# tmpdir		= /tmp
#
# Instead of skip-networking the default is now to listen only on
# localhost which is more compatible and is not less secure.
#bind-address		= 127.0.0.1
bind-address		= 0.0.0.0
mysqlx-bind-address	= 127.0.0.1
#
# * Fine Tuning
#
key_buffer_size		= 16M
# max_allowed_packet	= 64M
# thread_stack		= 256K
#
sort_buffer_size = 2M
join_buffer_size = 2M
thread_cache_size = 1500
thread_stack = 192K
tmp_table_size = 96M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
bulk_insert_buffer_size = 32M

innodb_print_all_deadlocks = 1

innodb_buffer_pool_chunk_size=1073741824
innodb_buffer_pool_instances=4
innodb_buffer_pool_size=8589934592

#初始化参数，无法后面修改
#innodb_data_file_path = ibdata1:12M:autoextend
#编译安装可以修改为：
#innodb_data_file_path = ibdata1:1024M:autoextend

admin_port = 33062
admin_address = '127.0.0.1'
create_admin_listener_thread = 1

# thread_cache_size       = -1

# This replaces the startup script and checks MyISAM tables if needed
# the first time they are touched
myisam-recover-options  = BACKUP

max_connections        = 2000
max_connect_errors     = 100000
table_open_cache       = 4000

# table_open_cache       = 4000

#
# * Logging and Replication
#
# Both location gets rotated by the cronjob.
#
# Log all queries
# Be aware that this log type is a performance killer.
# general_log_file        = /var/log/mysql/query.log
# general_log             = 1
#
# Error log - should be very few entries.
#
log_error = /var/log/mysql/error.log
#
# Here you can see queries with especially long duration
slow_query_log		= 1
slow_query_log_file	= /var/log/mysql/mysql-slow.log
long_query_time = 15
min_examined_row_limit=3
log_queries_not_using_indexes = 1
log_throttle_queries_not_using_indexes = 60

skip_name_resolve = 1
log_timestamps = SYSTEM
#
# The following can be used as easy to replay backup logs or for replication.
# note: if you are setting up a replication slave, see README.Debian about
#       other settings you may need to change.
#server-id		= 1
log_bin			= /var/log/mysql/mysql-bin.log
binlog_expire_logs_seconds	= 604800

max_binlog_size   = 100M
binlog_transaction_dependency_tracking = 'writeset'
# binlog_do_db		= include_database_name
# binlog_ignore_db	= include_database_name




[client]
port=3306
default-character-set=utf8mb4
socket=/var/lib/mysql/mysql.sock

[mysql]
no-auto-rehash
default-character-set=utf8mb4
EOF
```

```bash
#配置文件检查
mysqld --defaults-file=/etc/mysql/mysql.conf.d/mysqld.cnf  --validate-config --log-error-verbosity=2
```



##### 2) mysqld.server

```bash
sed -i 's/LimitNOFILE=10000/LimitNOFILE=65500/g' /lib/systemd/system/mysql.service
```

#### 4、启动mysql

```bash
systemctl daemon-reload

systemctl start mysql
systemctl status mysql
systemctl enable mysql
```

#### 5、修改密码

```bash
#cat /etc/mysql/debian.cnf
#mysql服务器本地登录，刚安装完毕时，可以用root不需要输入密码，直接回车进入

mysql -u root -p
==> 回车

#本地root账户修改密码
ALTER USER "root"@"localhost" IDENTIFIED WITH mysql_native_password  BY "Mysql2023!@#Root";
```

#### 6、设置远程访问

```bash
#远程root账户
CREATE USER 'root'@'%' IDENTIFIED BY 'Mysql2023!@#Root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
flush privileges;
SELECT `user`, `host`, `authentication_string`, `plugin` FROM mysql.user;
exit;

#在apt安装的MySQL的配置文件里，设置了绑定127.0.0.1地址，需要在配置文件/etc/mysql/mysql.conf.d/mysqld.cnf中注释掉该行，在操作之前，需要停止mysql服务：
systemctl stop mysql


#开放3306端口
ufw allow 3306
```

### 三、离线安装mysql---可选---ubuntu22.04

#仅与在线安装mysql中的安装部分不同，其他步骤相同

#### 离线安装mysql

#找台外网开通的服务器

```bash
wget https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.27-1.el7.x86_64.rpm-bundle.tar
```

#将mysql-8.0.27-1.el7.x86_64.rpm-bundle.tar拷贝至mysql服务器

```bash
tar -xvf mysql-8.0.27-1.el7.x86_64.rpm-bundle.tar

rpm -ivh mysql-community-common-8.0.27-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-plugins-8.0.27-1.el7.x86_64.rpm

rpm -ivh mysql-community-libs-8.0.27-1.el7.x86_64.rpm

rpm -ivh mysql-community-libs-compat-8.0.27-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-8.0.27-1.el7.x86_64.rpm

rpm -ivh mysql-community-server-8.0.27-1.el7.x86_64.rpm

```

#注意离线部署可能会缺少依赖包，比如perl，那么需要光盘制作个本地yum源进行安装

```bash
yum install -y perl
```

