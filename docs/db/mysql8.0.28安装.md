****此文档提供安装mysql8(最新版8.0.2x)的单机版安装****

****
#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小，mysql安装到最大分区里

#20211228补充OS优化部分

#20220319安装版本为8.0.28

## 服务器资源

#建议(等于或高于以下配置)
```
vm: 16核/32G 

OS: centos7.9(3.10.0-1127)

磁盘LVM管理，／为最大分区
```

## 部署过程

### 一、系统优化

#### 1、Hostname修改
#hostname命名建议规范
```bash
echo "192.168.1.225 mysql01" >> /etc/hosts
hostnamectl set-hostname mysql01

hostnamectl status
```
#### 2、关闭防火墙和selinux
```bash
systemctl stop firewalld
systemctl disable firewalld

setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```
#### 3、修改centos源文件
```bash
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

yum clean all && yum makecache all
```
#### 4、开始时间同步及修改东8区
```bash
yum install -y ntp
systemctl start ntpd
system enable ntpd

vi /etc/ntp.conf
#注释下面4行
#server 0.centos.pool.ntp.org iburst
#server 1.centos.pool.ntp.org iburst
#server 2.centos.pool.ntp.org iburst
#server 3.centos.pool.ntp.org iburst

#替换成中国时间服务器
#http://www.pool.ntp.org/zone/cn
server 0.cn.pool.ntp.org
server 1.cn.pool.ntp.org
server 2.cn.pool.ntp.org
server 3.cn.pool.ntp.org

date -R
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
```
#### 5、语言修改为utf8
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
```

### 二、在线安装mysql

#### 1、卸载mariadb
```bash
rpm -qa |grep -i mariadb
yum remove -y mariadb-libs.x86_64
```
#### 2、安装mysql
```bash
yum install -y wget net-tools

wget https://dev.mysql.com/get/mysql80-community-release-el7-5.noarch.rpm

yum localinstall -y mysql80-community-release-el7-5.noarch.rpm

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

### 三、离线安装mysql---可选

#仅与在线安装mysql中的安装部分不同，其他步骤相同

#### 离线安装mysql
#找台外网开通的服务器
```bash
wget https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.28-1.el7.x86_64.rpm-bundle.tar
```
#将mysql-8.0.28-1.el7.x86_64.rpm-bundle.tar拷贝至mysql服务器

```bash
tar -xvf mysql-8.0.28-1.el7.x86_64.rpm-bundle.tar

rpm -ivh mysql-community-common-8.0.28-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-plugins-8.0.28-1.el7.x86_64.rpm

rpm -ivh mysql-community-libs-8.0.28-1.el7.x86_64.rpm

rpm -ivh mysql-community-libs-compat-8.0.28-1.el7.x86_64.rpm

rpm -ivh mysql-community-client-8.0.28-1.el7.x86_64.rpm

rpm -ivh mysql-community-server-8.0.28-1.el7.x86_64.rpm

```
#注意离线部署可能会缺少依赖包，比如perl，那么需要光盘制作个本地yum源进行安装
```bash
yum install -y perl
```

