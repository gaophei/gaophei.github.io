此文档提供安装mysql8(最新版8.0.34)主从高可用模式的安装

****

#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小，mysql安装到最大分区里
#20211228补充OS优化部分，安装版本为8.0.34

## 服务器资源

#建议

```
vm: 16核/32G 

OS: oracle Linux 7.9(5.4.17-2011.6.2.el7uek.x86_64)

磁盘LVM管理，挂载第二块磁盘1T，/data为最大分区
```

## 部署过程

### 一、系统优化

#### 1、Hostname修改

#hostname命名建议规范，以实际IP为准

```bash
cat >> /etc/hosts <<EOF
10.20.12.136 mysql01
10.20.12.137 mysql02
EOF

#mysql01
hostnamectl set-hostname mysql01
#mysql02
hostnamectl set-hostname mysql02

hostnamectl status

ping mysql01 
ping mysql02

```

```
[root@localhost ~]# hostnamectl set-hostname mysql01
[root@localhost ~]# exit

[root@mysql01 ~]# hostnamectl status
   Static hostname: mysql01
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 4e99db48ca56469d86d4043965953a54
           Boot ID: d7b0f5da94ba4c43b9f3432a6c1258c1
    Virtualization: kvm
  Operating System: Oracle Linux Server 7.9
       CPE OS Name: cpe:/o:oracle:linux:7:9:server
            Kernel: Linux 5.4.17-2011.6.2.el7uek.x86_64
      Architecture: x86-64

[root@mysql01 ~]# cat >> /etc/hosts <<EOF
> 10.20.12.136 mysql01
> 10.20.12.137 mysql02
> EOF
[root@mysql01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.20.12.136 mysql01
10.20.12.137 mysql02

[root@mysql01 ~]# ping mysql01 -c 1
PING mysql01 (10.20.12.136) 56(84) bytes of data.
64 bytes from mysql01 (10.20.12.136): icmp_seq=1 ttl=64 time=0.065 ms

--- mysql01 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.065/0.065/0.065/0.000 ms
[root@mysql01 ~]# ping mysql02 -c 1
PING mysql02 (10.20.12.137) 56(84) bytes of data.
64 bytes from mysql02 (10.20.12.137): icmp_seq=1 ttl=64 time=0.619 ms

--- mysql02 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.619/0.619/0.619/0.000 ms
[root@mysql01 ~]#

```



#### 2、关闭防火墙和selinux

```bash
#centos关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

getenforce
cat /etc/selinux/config

```

#### 3、修改源文件

```bash
#oracle linux server直接使用自己的yum源，此处不做修改

#centos
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

yum clean all && yum makecache all

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
systemctl status ntpd

#ubuntu重启ntp
systemctl restart ntp
systemctl status ntp

date -R
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
```

#### 5、语言修改为utf8---centos7.9

```bash
env|grep LANG
echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
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

cat /etc/security/limits.d/20-nproc.conf
cat /etc/security/limits.conf

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

#8.0.35
wget https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm

yum localinstall -y mysql80-community-release-el7-11.noarch.rpm

yum search mysql-community-server
yum list mysql-community-server.x86_64  --showduplicates | sort -r

yum install -y mysql-community-server

#指定某版本
yum install -y mysql-community-{server,client,client-plugins,icu-data-files,common,libs,libs-compat}-8.0.20-1.el7
```

#### 3、优化mysql---mysql01和mysql02有细微差别

#检查my.cnf

```bash
mysqld --defaults-file=/etc/my.cnf  --validate-config --log-error-verbosity=2
```



##### 1) mysql01---/etc/my.cnf

```bash
cp /etc/my.cnf /etc/my.cnf.bak

cat > /etc/my.cnf <<EOF
[client]
port = 3306
#socket连接文件；该配置不用修改
socket = /data/mysql/mysql.sock
#default-character-set = utf8mb4

[mysql]
#mysql终端提醒配置
prompt = "\u@\h:\p [\d]> "
#关闭自动补全功能
no-auto-rehash
#default-character-set = utf8mb4

[mysqld]
####################general####################
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
user = mysql
port = 3306
#basedir = /data/mysql
datadir = /data/mysql
#tmpdir = /tmp
socket = /data/mysql/mysql.sock
#服务器唯一id，默认为1，值范围为1～2^32−1. ；主数据库和从数据库的server-id不能重复
server_id = 136
#server_id = 137
#mysqlx_port = 33060
#管理员用来连接的端口号,注意如果admin_address没有设置的话,这个端口号是无效的
admin_port = 33062
#用于指定管理员发起tcp连接的主机地址
admin_address = '127.0.0.1'
#是否创建一个单独的listener线程来监听admin的链接请求,默认值是关闭的
create_admin_listener_thread = on

#禁用dns解析
skip_name_resolve = 1
#设置默认时区
default_time_zone = "+8:00"
#设置默认的字符集
character-set-server = utf8mb4
#collation_connection = utf8mb4_0900_ai_ci
#character-set-client-handshake = FALSE
#init_connect = 'SET NAMES utf8mb4'

#设置表名不区分大小写,默认值为0,表名是严格区分大小写的
lower_case_table_names = 1
#是否信任存储函数创建者
log_bin_trust_function_creators = 1

####################max connection################
#对整个服务器的用户限制，设置允许的最大连接数
max_connections = 3000
#限制每个用户的session连接个数
max_user_connections = 2000
#客户端连接失败以下次数，MySQL不再响应客户端连接
max_connect_errors = 100000
mysqlx_max_connections = 300

back_log = 2000

####################binlog#######################
#设置binlog日志(主从同步和数据恢复需要)
#log-bin = /data/mysql/logs/mysql-bin
log-bin = mysql-bin
#设置主从复制的模式：STATEMENT模式（SBR）、ROW模式（RBR）、MIXED模式（MBR）
binlog_format = row
#开启该参数,从库从主库同步的数据也会更新到从库的binlog文件,默认为ON状态
log_replica_updates = on
#开启全局事务标识模式,gtid用于在binlog中唯一标识一个事务
gtid_mode = on
#当启用enforce_gtid_consistency功能的时候,MySQL只允许能够保障事务安全,并且能够被日志记录的SQL语句被执行
#像create table … select 和 create temporary table语句,以及同时更新事务表和非事务表的SQL语句或事务都不允许执行
enforce_gtid_consistency = on
#为每个session分配的内存,在事务过程中用来存储二进制日志的缓存
binlog_cache_size = 2M
#max_binlog_cache_size=8M
#binlog文件的大小,超过该大小会自动创建新的binlog文件
max_binlog_size = 512M
#在row模式下开启该参数,将把sql语句打印到binlog日志里面,默认值为0(off)
binlog_rows_query_log_events = on
#设置每次事务提交都将数据同步到磁盘
sync_binlog = 1
#表示binlog提交后等待延迟多少时间再同步到磁盘,默认值为0,不延迟
#设置延迟可以让多个事务在某一时刻提交,提高binlog组提交的并发数和效率,提高slave的吞吐量
binlog_group_commit_sync_delay = 0
#表示等待延迟提交的最大事务数,如果binlog_group_commit_sync_dela没到,但事务数到了,则直接同步到磁盘
#若binlog_group_commit_sync_delay没有开启,则该参数也不会开启,默认值为0
binlog_group_commit_sync_no_delay_count = 0
#提交的事务是否按照写入二进制日志binlog的顺序提交,在一些情况下关闭这个参数,可以获得性能上的一点提升,默认值为on
binlog_order_commits = off
#设置binlog日志的保存天数,超过天数的日志会被自动删除,默认值为0,不自动清理
#expire_logs_days = 7
binlog_expire_logs_seconds = 604800

#binlog事务压缩传输
binlog_transaction_compression = on
binlog_transaction_compression_level_zstd = 3

##################Parallel replication---is deprecated##########
#控制检测事务依赖关系时采用的HASH算法,有三个取值OFF|XXHASH64|MURMUR32
#transaction_write_set_extraction = 'XXHASH64'
#5.7.29+版本有下面2个参数,低于该版本的请关闭下面配置
#控制事务依赖模式,让从库根据主库写入binlog中的commit timestamps或者write sets并行回放事务
#有三个取值COMMIT_ORDERE|WRITESET|WRITESET_SESSION
#binlog_transaction_dependency_tracking = 'writeset'
#取值范围为1-1000000,初始默认值为25000
#binlog_transaction_dependency_history_size = 25000

####################slow log####################
#开启慢查询
slow_query_log = 1
#SQL语句运行时间阈值,执行时间大于参数值的语句才会被记录下来
long_query_time = 15
#设置慢查询日志文件的路径和名称
slow_query_log_file = slow.log
#将没有使用索引的语句记录到慢查询日志
log_queries_not_using_indexes = 1
#设定每分钟记录到日志的未使用索引的语句数目,超过这个数目后只记录语句数量和花费的总时间
log_throttle_queries_not_using_indexes = 60

#Don't write queries to slow log that examine fewer rows than that
# min_examined_row_limit = 3

####################error log####################
#控制错误日志、慢查询日志等日志中的显示时间,在5.7.2 之后该参数为默认UTC,会导致日志中记录的时间比中国这边的慢,导致查看日志不方便
log_timestamps = SYSTEM
#设置错误日志的路径和名称
log_error = error.log
#1-错误信息;2-错误信息和告警信息;3-错误信息、告警信息和通知信息
log_error_verbosity = 3

#跳过临时表缺少binlog错误
#slave-skip-errors=1032
replica_skip_errors = 1032
log_error_suppression_list = 'MY-010914,MY-013360,MY-013730,MY-010584,MY-010559'

####################session######################
sort_buffer_size = 2M
join_buffer_size = 2M
key_buffer_size = 16M
thread_cache_size = 1500
thread_stack = 256K
tmp_table_size = 96M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
bulk_insert_buffer_size = 32M
max_allowed_packet = 32M

####################timeout######################
interactive_timeout = 600
wait_timeout = 600
innodb_rollback_on_timeout = on
replica_net_timeout = 30
rpl_stop_replica_timeout = 300
#slave_net_timeout = 30
#rpl_stop_slave_timeout = 180
lock_wait_timeout = 300

####################relay_log####################
relay_log = relay-bin
relay_log_index = relay-bin.index

#is deprecated and will be removed
master_info_repository = table
relay_log_info_repository = table

relay_log_purge = on

#默认值10000
sync_relay_log = 10000

#默认值10000
#is deprecated and will be removed
sync_relay_log_info = 10000

####################sql_thread####################
#从库在异常宕机时,会自动放弃所有未执行的relay log,重新从主库获取日志,保证relay-log的完整性,默认该功能是关闭的
relay_log_recovery = ON
replica_preserve_commit_order = OFF

#replica_parallel
replica_parallel_type = LOGICAL_CLOCK

replica_parallel_workers = 16
#deprecated
#slave_preserve_commit_order = OFF
#并行复制模式:DATABASE默认值,基于库的并行复制方式;LOGICAL_CLOCK,基于组提交的并行复制方式
#slave_parallel_type = LOGICAL_CLOCK
#主从复制时,设置并行复制的工作线程数
#slave_parallel_workers=16

####################innodb#######################
#内存的50%-70%
innodb_buffer_pool_size = 16384M
#2个G一个instance,一般小于32G配置为4,大于32G配置为8
innodb_buffer_pool_instances = 4
#默认启用,指定在MySQL服务器启动时,InnoDB缓冲池通过加载之前保存的相同页面自动预热,通常与innodb_buffer_pool_dump_at_shutdown结合使用.
innodb_buffer_pool_load_at_startup = 1
#默认启用,指定在MySQL服务器关闭时是否记录在InnoDB缓冲池中缓存的页面,以便在下次重新启动时缩短预热过程.
innodb_buffer_pool_dump_at_shutdown = 1
#指定innodb tablespace表空间的大小,默认: ibdata1:12M:autoextend
innodb_data_file_path = ibdata1:1024M:autoextend
#默认值为1,在每个事务提交时，InnoDB立即将缓存中的redo日志回写到日志文件,并调用操作系统fsync刷新IO缓存,保证完整的ACID.
innodb_flush_log_at_trx_commit = 1
#日志缓冲区大小
innodb_log_buffer_size = 64M
#redo日志大小
innodb_redo_log_capacity=1073741824

#8.0.30以前
#innodb_log_file_size = 1024M
#redo日志组数,默认为2
#innodb_log_files_in_group = 3

#用来控制buffer pool中脏页的百分比,当脏页数量占比超过这个参数设置的值时,InnoDB会启动刷脏页的操作.
innodb_max_dirty_pages_pct = 90
#开启独立表空间,默认为开启
innodb_file_per_table = 1
#开始事务超时回滚整个事务。默认不开启,超时回滚最后一次提交记录
innodb_rollback_on_timeout = on
#根据您的服务器IOPS能力适当调整,一般配普通SSD盘的话,可以调整到10000-20000
#配置高端PCIe SSD卡的话,则可以调整的更高,比如50000-80000
innodb_io_capacity = 10000
#设置事务的隔离级别为读已提交
transaction_isolation = READ-COMMITTED
innodb_flush_method = O_DIRECT
#开启保存死锁日志,死锁日志存放到log_error配置的文件里
innodb_print_all_deadlocks = 1
#禁用线程并发检查,使InnoDB按照请求的需求,创造尽可能多的线程
innodb_thread_concurrency = 0
#设置IO读写的线程数(默认：4),一般CPU多少核就设置多少
innodb_read_io_threads = 4
innodb_write_io_threads = 4
#开启死锁检测,默认开启 
innodb_deadlock_detect = on
#设置锁等待超时时间,默认为50s
innodb_lock_wait_timeout = 20

####################undo########################
#设置undo log的最大值,默认值为1G.当超过设置的阈值,会触发truncate回收(收缩)动作.
innodb_max_undo_log_size = 4G
#undo文件存放的位置
innodb_undo_directory = /data/mysql/mysql3306/data/undolog
#从 8.0.14开始废弃该参数,默认表空间数量为2
#innodb_undo_tablespaces = 4
#开启自动清理undo log的功能
innodb_undo_log_truncate = 1

####################performance_schema####################
#MySQL的performance schema用于监控MySQL server在一个较低级别的运行过程中的资源消耗、资源等待等情况
performance_schema                                                      = on
performance_schema_consumer_global_instrumentation                      = on
performance_schema_consumer_thread_instrumentation                      = on
performance_schema_consumer_events_stages_current                       = on
performance_schema_consumer_events_stages_history                       = on
performance_schema_consumer_events_stages_history_long                  = off
performance_schema_consumer_statements_digest                           = on
performance_schema_consumer_events_statements_current                   = on
performance_schema_consumer_events_statements_history                   = on
performance_schema_consumer_events_statements_history_long              = off
performance_schema_consumer_events_waits_current                        = on
performance_schema_consumer_events_waits_history                        = on
performance_schema_consumer_events_waits_history_long                   = off
#key-value格式,支持使用通配符,匹配memory/开头的
performance_schema_instrument                                           = 'memory/%=COUNTED'

#####################MGR################################
#binlog_checksum=none
#transaction_write_set_extraction=XXHASH64
#binlog_transaction_dependency_tracking=WRITESET
#loose-group_replication_group_name="e7d07963-de9b-4506-9ede-8297903c257c" 
#loose-group_replication_start_on_boot=off 
#loose-group_replication_local_address= "192.168.113.243:33061" 
#loose-group_replication_group_seeds= "192.168.113.243:33061,192.168.113.244:33061,192.168.113.245:33061" 
#loose-group_replication_bootstrap_group= off

####################MGR multi master####################
#loose-group_replication_single_primary_mode=off
#loose-group_replication_enforce_update_everywhere_checks=on

[mysqldump]
quick
max_allowed_packet = 32M

EOF
```

```mysql
[client]
port = 3306
socket = /data/mysql/mysql.sock
[mysql]
prompt = "\u@\h:\p [\d]> "
no-auto-rehash
[mysqld]
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
user = mysql
port = 3306
datadir = /data/mysql
socket = /data/mysql/mysql.sock
server_id = 136
admin_port = 33062
admin_address = '127.0.0.1'
create_admin_listener_thread = on
skip_name_resolve = 1
default_time_zone = "+8:00"
character-set-server = utf8mb4
lower_case_table_names = 1
log_bin_trust_function_creators = 1
max_connections = 3000
max_user_connections = 2000
max_connect_errors = 100000
mysqlx_max_connections = 300
back_log = 2000
log-bin = mysql-bin
binlog_format = row
log_replica_updates = on
gtid_mode = on
enforce_gtid_consistency = on
binlog_cache_size = 2M
max_binlog_size = 512M
binlog_rows_query_log_events = on
sync_binlog = 1
binlog_group_commit_sync_delay = 0
binlog_group_commit_sync_no_delay_count = 0
binlog_order_commits = off
binlog_expire_logs_seconds = 604800
slow_query_log = 1
long_query_time = 15
slow_query_log_file = slow.log
log_queries_not_using_indexes = 1
log_throttle_queries_not_using_indexes = 60
log_timestamps = SYSTEM
log_error = error.log
log_error_verbosity = 3
replica_skip_errors = 1032
sort_buffer_size = 2M
join_buffer_size = 2M
key_buffer_size = 16M
thread_cache_size = 1500
thread_stack = 256K
tmp_table_size = 96M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
bulk_insert_buffer_size = 32M
max_allowed_packet = 32M
interactive_timeout = 600
wait_timeout = 600
innodb_rollback_on_timeout = on
replica_net_timeout = 30
rpl_stop_replica_timeout = 300
lock_wait_timeout = 300
relay_log = relay-bin
relay_log_index = relay-bin.index
master_info_repository = table
relay_log_info_repository = table
relay_log_purge = on
sync_relay_log = 10000
sync_relay_log_info = 10000
relay_log_recovery = ON
replica_preserve_commit_order = OFF
replica_parallel_type = LOGICAL_CLOCK
replica_parallel_workers = 16
innodb_buffer_pool_size = 16384M
innodb_buffer_pool_instances = 4
innodb_buffer_pool_load_at_startup = 1
innodb_buffer_pool_dump_at_shutdown = 1
innodb_data_file_path = ibdata1:1024M:autoextend
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 64M
innodb_redo_log_capacity=1073741824
innodb_max_dirty_pages_pct = 90
innodb_file_per_table = 1
innodb_rollback_on_timeout = on
innodb_io_capacity = 10000
transaction_isolation = READ-COMMITTED
innodb_flush_method = O_DIRECT
innodb_print_all_deadlocks = 1
innodb_thread_concurrency = 0
innodb_read_io_threads = 4
innodb_write_io_threads = 4
innodb_deadlock_detect = on
innodb_lock_wait_timeout = 20
innodb_max_undo_log_size = 4G
innodb_undo_directory = /data/mysql/mysql3306/data/undolog
innodb_undo_log_truncate = 1
performance_schema                                                      = on
performance_schema_consumer_global_instrumentation                      = on
performance_schema_consumer_thread_instrumentation                      = on
performance_schema_consumer_events_stages_current                       = on
performance_schema_consumer_events_stages_history                       = on
performance_schema_consumer_events_stages_history_long                  = off
performance_schema_consumer_statements_digest                           = on
performance_schema_consumer_events_statements_current                   = on
performance_schema_consumer_events_statements_history                   = on
performance_schema_consumer_events_statements_history_long              = off
performance_schema_consumer_events_waits_current                        = on
performance_schema_consumer_events_waits_history                        = on
performance_schema_consumer_events_waits_history_long                   = off
performance_schema_instrument                                           = 'memory/%=COUNTED'
[mysqldump]
quick
max_allowed_packet = 32M

```



##### 2) mysql02---/etc/my.cnf

```bash
cp /etc/my.cnf /etc/my.cnf.bak

cat > /etc/my.cnf <<EOF
[client]
port = 3306
#socket连接文件；该配置不用修改
socket = /data/mysql/mysql.sock
#default-character-set = utf8mb4

[mysql]
#mysql终端提醒配置
prompt = "\u@\h:\p [\d]> "
#关闭自动补全功能
no-auto-rehash
#default-character-set = utf8mb4

[mysqld]
####################general####################
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
user = mysql
port = 3306
#basedir = /data/mysql
datadir = /data/mysql
#tmpdir = /tmp
socket = /data/mysql/mysql.sock
#服务器唯一id，默认为1，值范围为1～2^32−1. ；主数据库和从数据库的server-id不能重复
#server_id = 136
server_id = 137
#mysqlx_port = 33060
#管理员用来连接的端口号,注意如果admin_address没有设置的话,这个端口号是无效的
admin_port = 33062
#用于指定管理员发起tcp连接的主机地址
admin_address = '127.0.0.1'
#是否创建一个单独的listener线程来监听admin的链接请求,默认值是关闭的
create_admin_listener_thread = on

#禁用dns解析
skip_name_resolve = 1
#设置默认时区
default_time_zone = "+8:00"
#设置默认的字符集
character-set-server = utf8mb4
#collation_connection = utf8mb4_0900_ai_ci
#character-set-client-handshake = FALSE
#init_connect = 'SET NAMES utf8mb4'

#设置表名不区分大小写,默认值为0,表名是严格区分大小写的
lower_case_table_names = 1
#是否信任存储函数创建者
log_bin_trust_function_creators = 1

####################max connection################
#对整个服务器的用户限制，设置允许的最大连接数
max_connections = 3000
#限制每个用户的session连接个数
max_user_connections = 2000
#客户端连接失败以下次数，MySQL不再响应客户端连接
max_connect_errors = 100000
mysqlx_max_connections = 300

back_log = 2000

####################binlog#######################
#设置binlog日志(主从同步和数据恢复需要)
#log-bin = /data/mysql/logs/mysql-bin
log-bin = mysql-bin
#设置主从复制的模式：STATEMENT模式（SBR）、ROW模式（RBR）、MIXED模式（MBR）
binlog_format = row
#开启该参数,从库从主库同步的数据也会更新到从库的binlog文件,默认为ON状态
log_replica_updates = on
#开启全局事务标识模式,gtid用于在binlog中唯一标识一个事务
gtid_mode = on
#当启用enforce_gtid_consistency功能的时候,MySQL只允许能够保障事务安全,并且能够被日志记录的SQL语句被执行
#像create table … select 和 create temporary table语句,以及同时更新事务表和非事务表的SQL语句或事务都不允许执行
enforce_gtid_consistency = on
#为每个session分配的内存,在事务过程中用来存储二进制日志的缓存
binlog_cache_size = 2M
#max_binlog_cache_size=8M
#binlog文件的大小,超过该大小会自动创建新的binlog文件
max_binlog_size = 512M
#在row模式下开启该参数,将把sql语句打印到binlog日志里面,默认值为0(off)
binlog_rows_query_log_events = on
#设置每次事务提交都将数据同步到磁盘
sync_binlog = 1
#表示binlog提交后等待延迟多少时间再同步到磁盘,默认值为0,不延迟
#设置延迟可以让多个事务在某一时刻提交,提高binlog组提交的并发数和效率,提高slave的吞吐量
binlog_group_commit_sync_delay = 0
#表示等待延迟提交的最大事务数,如果binlog_group_commit_sync_dela没到,但事务数到了,则直接同步到磁盘
#若binlog_group_commit_sync_delay没有开启,则该参数也不会开启,默认值为0
binlog_group_commit_sync_no_delay_count = 0
#提交的事务是否按照写入二进制日志binlog的顺序提交,在一些情况下关闭这个参数,可以获得性能上的一点提升,默认值为on
binlog_order_commits = off
#设置binlog日志的保存天数,超过天数的日志会被自动删除,默认值为0,不自动清理
#expire_logs_days = 7
binlog_expire_logs_seconds = 604800

#binlog事务压缩传输
binlog_transaction_compression = on
binlog_transaction_compression_level_zstd = 3

##################Parallel replication---is deprecated##########
#控制检测事务依赖关系时采用的HASH算法,有三个取值OFF|XXHASH64|MURMUR32
#transaction_write_set_extraction = 'XXHASH64'
#5.7.29+版本有下面2个参数,低于该版本的请关闭下面配置
#控制事务依赖模式,让从库根据主库写入binlog中的commit timestamps或者write sets并行回放事务
#有三个取值COMMIT_ORDERE|WRITESET|WRITESET_SESSION
#binlog_transaction_dependency_tracking = 'writeset'
#取值范围为1-1000000,初始默认值为25000
#binlog_transaction_dependency_history_size = 25000

####################slow log####################
#开启慢查询
slow_query_log = 1
#SQL语句运行时间阈值,执行时间大于参数值的语句才会被记录下来
long_query_time = 15
#设置慢查询日志文件的路径和名称
slow_query_log_file = slow.log
#将没有使用索引的语句记录到慢查询日志
log_queries_not_using_indexes = 1
#设定每分钟记录到日志的未使用索引的语句数目,超过这个数目后只记录语句数量和花费的总时间
log_throttle_queries_not_using_indexes = 60

#Don't write queries to slow log that examine fewer rows than that
# min_examined_row_limit = 3

####################error log####################
#控制错误日志、慢查询日志等日志中的显示时间,在5.7.2 之后该参数为默认UTC,会导致日志中记录的时间比中国这边的慢,导致查看日志不方便
log_timestamps = SYSTEM
#设置错误日志的路径和名称
log_error = error.log
#1-错误信息;2-错误信息和告警信息;3-错误信息、告警信息和通知信息
log_error_verbosity = 3

#跳过临时表缺少binlog错误
#slave-skip-errors=1032
replica_skip_errors = 1032
log_error_suppression_list = 'MY-010914,MY-013360,MY-013730,MY-010584,MY-010559'

####################session######################
sort_buffer_size = 2M
join_buffer_size = 2M
key_buffer_size = 16M
thread_cache_size = 1500
thread_stack = 256K
tmp_table_size = 96M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
bulk_insert_buffer_size = 32M
max_allowed_packet = 32M

####################timeout######################
interactive_timeout = 600
wait_timeout = 600
innodb_rollback_on_timeout = on
replica_net_timeout = 30
rpl_stop_replica_timeout = 300
#slave_net_timeout = 30
#rpl_stop_slave_timeout = 180
lock_wait_timeout = 300

####################relay_log####################
relay_log = relay-bin
relay_log_index = relay-bin.index

#is deprecated and will be removed
master_info_repository = table
relay_log_info_repository = table

relay_log_purge = on

#默认值10000
sync_relay_log = 10000

#默认值10000
#is deprecated and will be removed
sync_relay_log_info = 10000

####################sql_thread####################
#从库在异常宕机时,会自动放弃所有未执行的relay log,重新从主库获取日志,保证relay-log的完整性,默认该功能是关闭的
relay_log_recovery = ON
replica_preserve_commit_order = OFF

#replica_parallel
replica_parallel_type = LOGICAL_CLOCK

replica_parallel_workers = 16
#deprecated
#slave_preserve_commit_order = OFF
#并行复制模式:DATABASE默认值,基于库的并行复制方式;LOGICAL_CLOCK,基于组提交的并行复制方式
#slave_parallel_type = LOGICAL_CLOCK
#主从复制时,设置并行复制的工作线程数
#slave_parallel_workers=16

####################innodb#######################
#内存的50%-70%
innodb_buffer_pool_size = 16384M
#2个G一个instance,一般小于32G配置为4,大于32G配置为8
innodb_buffer_pool_instances = 4
#默认启用,指定在MySQL服务器启动时,InnoDB缓冲池通过加载之前保存的相同页面自动预热,通常与innodb_buffer_pool_dump_at_shutdown结合使用.
innodb_buffer_pool_load_at_startup = 1
#默认启用,指定在MySQL服务器关闭时是否记录在InnoDB缓冲池中缓存的页面,以便在下次重新启动时缩短预热过程.
innodb_buffer_pool_dump_at_shutdown = 1
#指定innodb tablespace表空间的大小,默认: ibdata1:12M:autoextend
innodb_data_file_path = ibdata1:1024M:autoextend
#默认值为1,在每个事务提交时，InnoDB立即将缓存中的redo日志回写到日志文件,并调用操作系统fsync刷新IO缓存,保证完整的ACID.
innodb_flush_log_at_trx_commit = 1
#日志缓冲区大小
innodb_log_buffer_size = 64M
#redo日志大小
innodb_redo_log_capacity=1073741824

#8.0.30以前
#innodb_log_file_size = 1024M
#redo日志组数,默认为2
#innodb_log_files_in_group = 3

#用来控制buffer pool中脏页的百分比,当脏页数量占比超过这个参数设置的值时,InnoDB会启动刷脏页的操作.
innodb_max_dirty_pages_pct = 90
#开启独立表空间,默认为开启
innodb_file_per_table = 1
#开始事务超时回滚整个事务。默认不开启,超时回滚最后一次提交记录
innodb_rollback_on_timeout = on
#根据您的服务器IOPS能力适当调整,一般配普通SSD盘的话,可以调整到10000-20000
#配置高端PCIe SSD卡的话,则可以调整的更高,比如50000-80000
innodb_io_capacity = 10000
#设置事务的隔离级别为读已提交
transaction_isolation = READ-COMMITTED
innodb_flush_method = O_DIRECT
#开启保存死锁日志,死锁日志存放到log_error配置的文件里
innodb_print_all_deadlocks = 1
#禁用线程并发检查,使InnoDB按照请求的需求,创造尽可能多的线程
innodb_thread_concurrency = 0
#设置IO读写的线程数(默认：4),一般CPU多少核就设置多少
innodb_read_io_threads = 4
innodb_write_io_threads = 4
#开启死锁检测,默认开启 
innodb_deadlock_detect = on
#设置锁等待超时时间,默认为50s
innodb_lock_wait_timeout = 20

####################undo########################
#设置undo log的最大值,默认值为1G.当超过设置的阈值,会触发truncate回收(收缩)动作.
innodb_max_undo_log_size = 4G
#undo文件存放的位置
innodb_undo_directory = /data/mysql/mysql3306/data/undolog
#从 8.0.14开始废弃该参数,默认表空间数量为2
#innodb_undo_tablespaces = 4
#开启自动清理undo log的功能
innodb_undo_log_truncate = 1

####################performance_schema####################
#MySQL的performance schema用于监控MySQL server在一个较低级别的运行过程中的资源消耗、资源等待等情况
performance_schema                                                      = on
performance_schema_consumer_global_instrumentation                      = on
performance_schema_consumer_thread_instrumentation                      = on
performance_schema_consumer_events_stages_current                       = on
performance_schema_consumer_events_stages_history                       = on
performance_schema_consumer_events_stages_history_long                  = off
performance_schema_consumer_statements_digest                           = on
performance_schema_consumer_events_statements_current                   = on
performance_schema_consumer_events_statements_history                   = on
performance_schema_consumer_events_statements_history_long              = off
performance_schema_consumer_events_waits_current                        = on
performance_schema_consumer_events_waits_history                        = on
performance_schema_consumer_events_waits_history_long                   = off
#key-value格式,支持使用通配符,匹配memory/开头的
performance_schema_instrument                                           = 'memory/%=COUNTED'

#####################MGR################################
#binlog_checksum=none
#transaction_write_set_extraction=XXHASH64
#binlog_transaction_dependency_tracking=WRITESET
#loose-group_replication_group_name="e7d07963-de9b-4506-9ede-8297903c257c" 
#loose-group_replication_start_on_boot=off 
#loose-group_replication_local_address= "192.168.113.243:33061" 
#loose-group_replication_group_seeds= "192.168.113.243:33061,192.168.113.244:33061,192.168.113.245:33061" 
#loose-group_replication_bootstrap_group= off

####################MGR multi master####################
#loose-group_replication_single_primary_mode=off
#loose-group_replication_enforce_update_everywhere_checks=on

[mysqldump]
quick
max_allowed_packet = 32M

EOF
```

```mysql
[client]
port = 3306
socket = /data/mysql/mysql.sock
[mysql]
prompt = "\u@\h:\p [\d]> "
no-auto-rehash
[mysqld]
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
user = mysql
port = 3306
datadir = /data/mysql
socket = /data/mysql/mysql.sock
server_id = 137
admin_port = 33062
admin_address = '127.0.0.1'
create_admin_listener_thread = on
skip_name_resolve = 1
default_time_zone = "+8:00"
character-set-server = utf8mb4
lower_case_table_names = 1
log_bin_trust_function_creators = 1
max_connections = 3000
max_user_connections = 2000
max_connect_errors = 100000
mysqlx_max_connections = 300
back_log = 2000
log-bin = mysql-bin
binlog_format = row
log_replica_updates = on
gtid_mode = on
enforce_gtid_consistency = on
binlog_cache_size = 2M
max_binlog_size = 512M
binlog_rows_query_log_events = on
sync_binlog = 1
binlog_group_commit_sync_delay = 0
binlog_group_commit_sync_no_delay_count = 0
binlog_order_commits = off
binlog_expire_logs_seconds = 604800
slow_query_log = 1
long_query_time = 15
slow_query_log_file = slow.log
log_queries_not_using_indexes = 1
log_throttle_queries_not_using_indexes = 60
log_timestamps = SYSTEM
log_error = error.log
log_error_verbosity = 3
replica_skip_errors = 1032
sort_buffer_size = 2M
join_buffer_size = 2M
key_buffer_size = 16M
thread_cache_size = 1500
thread_stack = 256K
tmp_table_size = 96M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
bulk_insert_buffer_size = 32M
max_allowed_packet = 32M
interactive_timeout = 600
wait_timeout = 600
innodb_rollback_on_timeout = on
replica_net_timeout = 30
rpl_stop_replica_timeout = 300
lock_wait_timeout = 300
relay_log = relay-bin
relay_log_index = relay-bin.index
master_info_repository = table
relay_log_info_repository = table
relay_log_purge = on
sync_relay_log = 10000
sync_relay_log_info = 10000
relay_log_recovery = ON
replica_preserve_commit_order = OFF
replica_parallel_type = LOGICAL_CLOCK
replica_parallel_workers = 16
innodb_buffer_pool_size = 16384M
innodb_buffer_pool_instances = 4
innodb_buffer_pool_load_at_startup = 1
innodb_buffer_pool_dump_at_shutdown = 1
innodb_data_file_path = ibdata1:1024M:autoextend
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 64M
innodb_redo_log_capacity=1073741824
innodb_max_dirty_pages_pct = 90
innodb_file_per_table = 1
innodb_rollback_on_timeout = on
innodb_io_capacity = 10000
transaction_isolation = READ-COMMITTED
innodb_flush_method = O_DIRECT
innodb_print_all_deadlocks = 1
innodb_thread_concurrency = 0
innodb_read_io_threads = 4
innodb_write_io_threads = 4
innodb_deadlock_detect = on
innodb_lock_wait_timeout = 20
innodb_max_undo_log_size = 4G
innodb_undo_directory = /data/mysql/mysql3306/data/undolog
innodb_undo_log_truncate = 1
performance_schema                                                      = on
performance_schema_consumer_global_instrumentation                      = on
performance_schema_consumer_thread_instrumentation                      = on
performance_schema_consumer_events_stages_current                       = on
performance_schema_consumer_events_stages_history                       = on
performance_schema_consumer_events_stages_history_long                  = off
performance_schema_consumer_statements_digest                           = on
performance_schema_consumer_events_statements_current                   = on
performance_schema_consumer_events_statements_history                   = on
performance_schema_consumer_events_statements_history_long              = off
performance_schema_consumer_events_waits_current                        = on
performance_schema_consumer_events_waits_history                        = on
performance_schema_consumer_events_waits_history_long                   = off
performance_schema_instrument                                           = 'memory/%=COUNTED'
[mysqldump]
quick
max_allowed_packet = 32M
```



##### 3) mysqld.server---mysql01/mysql02

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
cat /data/mysql/error.log | grep "temporary password"
2023-10-31T10:39:37.827971+08:00 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: Z*n.jrlJ2uL<

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



### 三、配置基于gtid的高可用

#### 1、创建数据库同步账户

#如果主节点已经含有大量数据，需要导出，那么仅在主节点上创建同步数据库账户

#如果是全新部署的主从集群，那么主、从库都要创建该账户

#如果配置好主从后，要全库导入旧库，那么应该提前在旧库也创建好该账户

```sql
   set global validate_password.policy=0;
   set global validate_password.length=1;
create user 'repl'@'10.20.12.%' identified with mysql_native_password by 'Repl123!@#2023';
grant replication slave on *.* to 'repl'@'10.20.12.%';

show grants for 'repl'@'10.20.12.%';

SET @@GLOBAL.read_only = ON;
flush tables with read lock; 
```

#### 2、同步现有数据

#如果主节点已经有大量数据，需要mysqldump出来后，scp到从节点，导入后，再配置主从模式

#备份数据库，压缩后拷贝到从库

#主库执行

```bash
/usr/bin/mysqldump -uroot -pMysql2023\!\@\#Root --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > 20231102.sql

/usr/bin/mysqldump -uroot -pMysql2023\!\@\#Root --quick --events --all-databases --source-data=2 --single-transaction --set-gtid-purged=OFF > 20231102.sql

/usr/bin/tar -zcvf 20231102.sql.tar.gz 20231102.sql

 scp 20231102.sql.tar.gz 10.20.12.136:/root/
```



#从库执行

```bash
tar -zxvf 20231102.sql.tar.gz

mysql -u root -p
```

#导入sql文件

```mysql
source /root/20231102.sql
```

#### 3、配置主从同步

#仅在从库配置

```bash
SET @@GLOBAL.read_only = ON;

CHANGE REPLICATION SOURCE TO SOURCE_HOST='10.20.12.136',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;

show warnings;

SHOW REPLICA STATUS \G;

start replica;

SHOW REPLICA STATUS \G;

SET @@GLOBAL.read_only = OFF;
```



#主库查询

```mysql
show replicas;

unlock tables;
SET @@GLOBAL.read_only = OFF;
```



#### 4、错误处理

#从库开启主从后报错:

#可能会有修改root账户及创建repl账户的相关错误

```mysql
mysql> SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 172.18.13.112
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000006
          Read_Source_Log_Pos: 712
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 373
        Relay_Source_Log_File: mysql-bin.000002
           Replica_IO_Running: Yes
          Replica_SQL_Running: No
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 1396
                   Last_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 1 failed executing transaction 'b526a489-7796-11ee-b698-fefcfec91d86:1' at source log mysql-bin.000002, end_log_pos 476. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 157
              Relay_Log_Space: 685555993
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File: 
           Source_SSL_CA_Path: 
              Source_SSL_Cert: 
            Source_SSL_Cipher: 
               Source_SSL_Key: 
        Seconds_Behind_Source: NULL
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 1396
               Last_SQL_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 1 failed executing transaction 'b526a489-7796-11ee-b698-fefcfec91d86:1' at source log mysql-bin.000002, end_log_pos 476. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
  Replicate_Ignore_Server_Ids: 
             Source_Server_Id: 112
                  Source_UUID: b526a489-7796-11ee-b698-fefcfec91d86
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: 
           Source_Retry_Count: 86400
                  Source_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 231031 17:37:37
               Source_SSL_Crl: 
           Source_SSL_Crlpath: 
           Retrieved_Gtid_Set: b526a489-7796-11ee-b698-fefcfec91d86:1-4122
            Executed_Gtid_Set: 0f6d9c97-77c1-11ee-92e4-fefcfebb93d1:1-2981
                Auto_Position: 1
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Source_TLS_Version: 
       Source_public_key_path: 
        Get_Source_public_key: 0
            Network_Namespace: 
1 row in set (0.00 sec)

ERROR: 
No query specified

mysql> select * from performance_schema.replication_applier_status_by_worker where LAST_ERROR_NUMBER=1396;
```

```bash
cd /data/mysql/

mysqlbinlog --base64-output=decode-rows -vvv mysql-bin.000002 > 2_binlog

vi 2_binlog

```

```vim
#找到at 157
/at 157

# at 157
#231031 10:43:14 server id 112  end_log_pos 236 CRC32 0xf6ef69b4        GTID    last_committed=0        sequence_number=1       rbr_only=no     original_committed_timestamp=1698720194806196   immediate_commit_timestamp=1698720194806196     transaction_length=319
# original_commit_timestamp=1698720194806196 (2023-10-31 10:43:14.806196 CST)
# immediate_commit_timestamp=1698720194806196 (2023-10-31 10:43:14.806196 CST)
/*!80001 SET @@session.original_commit_timestamp=1698720194806196*//*!*/;
/*!80014 SET @@session.original_server_version=80035*//*!*/;
/*!80014 SET @@session.immediate_server_version=80035*//*!*/;
SET @@SESSION.GTID_NEXT= 'b526a489-7796-11ee-b698-fefcfec91d86:1'/*!*/;


#找到at 236
/at 236

# at 236
#231031 10:43:14 server id 112  end_log_pos 476 CRC32 0xb2223c20        Query   thread_id=8     exec_time=0     error_code=0    Xid = 4
SET TIMESTAMP=1698720194.799259/*!*/;
SET @@session.pseudo_thread_id=8/*!*/;
SET @@session.foreign_key_checks=1, @@session.sql_auto_is_null=0, @@session.unique_checks=1, @@session.autocommit=1/*!*/;
SET @@session.sql_mode=1168113664/*!*/;
SET @@session.auto_increment_increment=1, @@session.auto_increment_offset=1/*!*/;
/*!\C utf8mb4 *//*!*/;
SET @@session.character_set_client=255,@@session.collation_connection=255,@@session.collation_server=255/*!*/;
SET @@session.time_zone='+08:00'/*!*/;
SET @@session.lc_time_names=0/*!*/;
SET @@session.collation_database=DEFAULT/*!*/;
/*!80011 SET @@session.default_collation_for_utf8mb4=255*//*!*/;
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$7+YaT@:iiaot>EJR]O{m14oa3A6OY4t4Mjv.V5T6.iJoJj2DGL1Fs2g0JX04eZ/'
/*!*/;



```



#跳过部分

```
stop replica;
 
 set @@session.gtid_next='b526a489-7796-11ee-b698-fefcfec91d86:109'; 
 begin; 
 commit; 

 set @@session.gtid_next='b526a489-7796-11ee-b698-fefcfec91d86:110'; 
 begin; 
 commit; 

 set @@session.gtid_next='b526a489-7796-11ee-b698-fefcfec91d86:111'; 
 begin; 
 commit;  

 set @@session.gtid_next='b526a489-7796-11ee-b698-fefcfec91d86:112'; 
 begin; 
 commit;  

 set @@session.gtid_next='b526a489-7796-11ee-b698-fefcfec91d86:113'; 
 begin; 
 commit; 
 
 set @@session.gtid_next=automatic;  
 
 start replica; 
 
 SHOW REPLICA STATUS \G;
```

#全部报错解决后：

#从库

```mysql
mysql>   SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 172.18.13.112
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000006
          Read_Source_Log_Pos: 712
               Relay_Log_File: relay-bin.000017
                Relay_Log_Pos: 460
        Relay_Source_Log_File: mysql-bin.000006
           Replica_IO_Running: Yes
          Replica_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 712
              Relay_Log_Space: 967
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File: 
           Source_SSL_CA_Path: 
              Source_SSL_Cert: 
            Source_SSL_Cipher: 
               Source_SSL_Key: 
        Seconds_Behind_Source: 0
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Source_Server_Id: 112
                  Source_UUID: b526a489-7796-11ee-b698-fefcfec91d86
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Source_Retry_Count: 86400
                  Source_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Source_SSL_Crl: 
           Source_SSL_Crlpath: 
           Retrieved_Gtid_Set: b526a489-7796-11ee-b698-fefcfec91d86:1-4122
            Executed_Gtid_Set: 0f6d9c97-77c1-11ee-92e4-fefcfebb93d1:1-2981,
b526a489-7796-11ee-b698-fefcfec91d86:1-4122
                Auto_Position: 1
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Source_TLS_Version: 
       Source_public_key_path: 
        Get_Source_public_key: 0
            Network_Namespace: 
1 row in set (0.00 sec)

ERROR: 
No query specified


```

```bash
tail -f /data/mysql/error.log

2023-11-02T10:43:19.894271+08:00 47 [Warning] [MY-010897] [Repl] Storing MySQL user name or password information in the connection metadata repository is not secure and is therefore not recommended. Please consider using the USER and PASSWORD connection options for START REPLICA; see the 'START REPLICA Syntax' in the MySQL Manual for more information.
2023-11-02T10:43:19.951855+08:00 48 [Note] [MY-010581] [Repl] Replica SQL thread for channel '' initialized, starting replication in log 'mysql-bin.000002' at position 157, relay log './relay-bin.000002' position: 373
2023-11-02T10:43:19.953661+08:00 47 [System] [MY-014002] [Repl] Replica receiver thread for channel '': connected to source 'repl@172.18.13.114:3306' with server_uuid=6cfaa641-7926-11ee-bb23-fefcfe25467b, server_id=114. Starting GTID-based replication.

```



#主库

```bash
tail -f /data/mysql/error.log

2023-11-02T10:43:19.897307+08:00 12 [Warning] [MY-013360] [Server] Plugin mysql_native_password reported: ''mysql_native_password' is deprecated and will be removed in a future release. Please use caching_sha2_password instead'
2023-11-02T10:43:19.956046+08:00 12 [Note] [MY-010462] [Repl] Start binlog_dump to source_thread_id(12) replica_server(115), pos(, 4)

```



#### 5、验证主从的同步

#主库

```mysql
mysql> CREATE DATABASE testdb DEFAULT CHARSET utf8mb4; 
mysql> CREATE USER 'testuser'@'%' IDENTIFIED BY 'Qwert123..';
mysql> GRANT ALL PRIVILEGES ON testdb.* TO 'testuser'@'%'; 
mysql> FLUSH PRIVILEGES;

mysql> USE testdb;
mysql> CREATE TABLE t_user01(
 id int auto_increment primary key,
 name varchar(40)
) ENGINE = InnoDB;

BEGIN;
INSERT INTO t_user01 VALUES (1,'user01');
INSERT INTO t_user01 VALUES (2,'user02');
INSERT INTO t_user01 VALUES (3,'user03');
INSERT INTO t_user01 VALUES (4,'user04');
INSERT INTO t_user01 VALUES (5,'user05');
commit;
```

#从库

```mysql
# 查看数据库，可以看到testdb同步过来了
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| testdb             |
+--------------------+
5 rows in set (0.03 sec)


# 数据也同步过来了
mysql> use testdb;
Database changed

mysql> select * from testdb.t_user01;
+----+--------+
| id | name   |
+----+--------+
|  1 | user01 |
|  2 | user02 |
|  3 | user03 |
|  4 | user04 |
|  5 | user05 |
+----+--------+
5 rows in set (0.00 sec)

mysql>  SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 172.18.13.112
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000006
          Read_Source_Log_Pos: 3580
               Relay_Log_File: relay-bin.000017
                Relay_Log_Pos: 3328
        Relay_Source_Log_File: mysql-bin.000006
           Replica_IO_Running: Yes
          Replica_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 3580
              Relay_Log_Space: 3835
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File: 
           Source_SSL_CA_Path: 
              Source_SSL_Cert: 
            Source_SSL_Cipher: 
               Source_SSL_Key: 
        Seconds_Behind_Source: 0
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Source_Server_Id: 112
                  Source_UUID: b526a489-7796-11ee-b698-fefcfec91d86
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Source_Retry_Count: 86400
                  Source_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Source_SSL_Crl: 
           Source_SSL_Crlpath: 
           Retrieved_Gtid_Set: b526a489-7796-11ee-b698-fefcfec91d86:1-4129
            Executed_Gtid_Set: 0f6d9c97-77c1-11ee-92e4-fefcfebb93d1:1-2981,
7661d18c-8e10-11e7-8e9c-6c0b84d5a868:298637-298639,
b526a489-7796-11ee-b698-fefcfec91d86:1-4129
                Auto_Position: 1
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Source_TLS_Version: 
       Source_public_key_path: 
        Get_Source_public_key: 0
            Network_Namespace: 
1 row in set (0.00 sec)

ERROR: 
No query specified

mysql > select * from performance_schema.replication_applier_status_by_worker;

```

#### 6、配置主从或者双主后mysql部分报错处理

##### 1)错误一：MY-010914

```bash
2023-11-02T17:45:57.710621+08:00 921 [Note] [MY-010914] [Server] Got an error reading communication packets
2023-11-02T17:45:59.711067+08:00 922 [Note] [MY-010914] [Server] Got an error reading communication packets
2023-11-02T17:46:01.711612+08:00 923 [Note] [MY-010914] [Server] Got an error reading communication packets
```



```mysql
mysql> show global status like '%abort%';

+------------------------+-------+
| Variable_name          | Value |
+------------------------+-------+
| Aborted_clients        | 3     |
| Aborted_connects       | 734   |
| Mysqlx_aborted_clients | 0     |
+------------------------+-------+
3 rows in set (0.00 sec)

```

#或者通过mysqladmin

```bash
#  mysqladmin -u root -p ext | grep Abort
Enter password: 
| Aborted_clients                                       | 8           |
| Aborted_connects                                      | 585         |
```

#临时解决办法

```mysql
set global log_error_suppression_list='MY-010914';
```

```mysql
mysql> show variables like '%log%err%';
+----------------------------+----------------------------------------+
| Variable_name              | Value                                  |
+----------------------------+----------------------------------------+
| binlog_error_action        | ABORT_SERVER                           |
| log_error                  | ./error.log                            |
| log_error_services         | log_filter_internal; log_sink_internal |
| log_error_suppression_list |                                        |
| log_error_verbosity        | 3                                      |
+----------------------------+----------------------------------------+
5 rows in set (0.00 sec)

mysql> set global log_error_suppression_list='MY-010914';
Query OK, 0 rows affected (0.00 sec)

mysql> show variables like '%log%err%';
+----------------------------+----------------------------------------+
| Variable_name              | Value                                  |
+----------------------------+----------------------------------------+
| binlog_error_action        | ABORT_SERVER                           |
| log_error                  | ./error.log                            |
| log_error_services         | log_filter_internal; log_sink_internal |
| log_error_suppression_list | MY-010914                              |
| log_error_verbosity        | 3                                      |
+----------------------------+----------------------------------------+
5 rows in set (0.00 sec)

```



#或者my.cnf添加

```mysql
log_error_suppression_list = 'MY-010914'
```



##### 2)错误二：MY-013360和MY-013730

```
2023-11-03T00:03:17.835888+08:00 18871 [Warning] [MY-013360] [Server] Plugin mysql_native_password reported: ''mysql_native_password' is deprecated and will be removed in a future release. Please use caching_sha2_password instead'
2023-11-03T09:09:11.288422+08:00 18510 [Note] [MY-013730] [Server] 'wait_timeout' period of 600 seconds was exceeded for `authx_service_single`@`%`. The idle time since last command was too long.

```

```mysql
#因为老库创建账户时使用了mysql_native_password，而没有使用caching_sha2_password，所以一直在告警MY-013360
mysql> select user,host,plugin from mysql.user;
+----------------------+------------+-----------------------+
| user                 | host       | plugin                |
+----------------------+------------+-----------------------+
| admin_center         | %          | mysql_native_password |
| authx_service_single | %          | mysql_native_password |
| cas_server           | %          | mysql_native_password |
| formflow             | %          | mysql_native_password |
| jobs_server          | %          | mysql_native_password |
| meeting_reservation  | %          | mysql_native_password |
| message              | %          | mysql_native_password |
| platform_openapi     | %          | mysql_native_password |
| root                 | %          | mysql_native_password |
| seat_reservation     | %          | mysql_native_password |
| temporary_management | %          | mysql_native_password |
| transaction          | %          | mysql_native_password |
| repl                 | 10.20.12.% | mysql_native_password |
| mysql.infoschema     | localhost  | caching_sha2_password |
| mysql.session        | localhost  | caching_sha2_password |
| mysql.sys            | localhost  | caching_sha2_password |
+----------------------+------------+-----------------------+
16 rows in set (0.00 sec)

#而timeout参数的设置是600s超时断开连接，note级别，可以忽略
mysql> show variables like 'wait_timeout';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| wait_timeout  | 600   |
+---------------+-------+
1 row in set (0.00 sec)

mysql> show variables like 'interactive_timeout';
+---------------------+-------+
| Variable_name       | Value |
+---------------------+-------+
| interactive_timeout | 600   |
+---------------------+-------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]>


#继续排除告警
mysql> set global log_error_suppression_list='MY-010914,MY-013360,MY-013730';
Query OK, 0 rows affected (0.00 sec)

```





##### 3)错误三：MY-010584

````
2023-11-03T00:30:09.677942+08:00 7 [Note] [MY-010584] [Repl] Replica SQL for channel '': Worker 1 failed executing transaction 'af179f66-7990-11ee-97cc-fa163e1255d2:15294' at source log mysql-bin.000005, end_log_pos 86433551; Could not execute Delete_rows event on table authx_service_single.tmp_ua_account_origin; Can't find record in 'tmp_ua_account_origin', Error_code: 1032; handler error HA_ERR_KEY_NOT_FOUND; the event's source log mysql-bin.000005, end_log_pos 86433551, Error_code: MY-001032

2023-11-03T08:30:36.470746+08:00 7 [Note] [MY-010584] [Repl] Replica SQL for channel '': Worker 1 failed executing transaction 'af179f66-7990-11ee-97cc-fa163e1255d2:15320' at source log mysql-bin.000005, end_log_pos 129182677; Could not execute Delete_rows event on table authx_service_single.tmp_ua_account_group_origin; Can't find record in 'tmp_ua_account_group_origin', Error_code: 1032; handler error HA_ERR_KEY_NOT_FOUND; the event's source log mysql-bin.000005, end_log_pos 129182677, Error_code: MY-001032

````

#因为部分临时表缺少binlog，导致从库没有添加，就进行了update和delete操作，可以忽略

#my.cnf已经设置replica_skip_errors = 1032，此处再次添加

```mysql
set global log_error_suppression_list='MY-010914,MY-013360,MY-013730,MY-010584';
```



##### 4) 错误四：MY-010559

```log
2023-11-03T16:37:04.467006+08:00 6 [Note] [MY-010559] [Repl] Multi-threaded replica statistics for channel '': seconds elapsed = 601; events assigned = 728065; worker queues filled over overrun level = 0; waited due a Worker queue full = 0; waited due the total size = 0; waited at clock conflicts = 1448054900 waited (count) when Workers occupied = 178054 waited when Workers occupied = 0
```

#只是返回部分同步信息，可以忽略

```mysql
set global log_error_suppression_list='MY-010914,MY-013360,MY-013730,MY-010584,MY-010559';
```



#最后修改下my.cnf，永久保持

```
log_error_suppression_list = 'MY-010914,MY-013360,MY-013730,MY-010584,MY-010559'
```

#### 7、压测

```
由于我的系统主机资源有限，因此就简单的 10 张表、每张表 1千条数据进行 5 分钟压测

参考：https://help.aliyun.com/document_detail/146103.html
```

##### 1）安装sysbench

```bash
#https://github.com/akopytov/sysbench

curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.rpm.sh | sudo bash

#如果是oracle linux server7.9，那么可能需要修改/etc/yum.repo.d/akopytov_sysbench.repo中的ol--->el
yum -y install sysbench

sysbench --version
sysbench --help
```



##### 2）读性能

###### 2.1 准备数据

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300  oltp_read_only prepare
  
# 说明：
# --table_size：表记录数
# --tables：表数量
```



###### 2.2 运行

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300 \
  --threads=5 \
  --percentile=95 \
  --range_selects=0 \
  --skip-trx=1 \
  --report-interval=1 oltp_read_only run
    
# 说明：
# --threads：并发线程数，可以理解为模拟的客户端并发连接数
# --skip-trx：省略begin/commit语句。默认是off
```

#结果

```
#sysbench结果

SQL statistics:
    queries performed:
        read:                            5938200
        write:                           0
        other:                           0
        total:                           5938200
    transactions:                        593820 (1979.29 per sec.)
    queries:                             5938200 (19792.89 per sec.)
    ignored errors:                      0      (0.00 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.0146s
    total number of events:              593820

Latency (ms):
         min:                                    0.76
         avg:                                    2.52
         max:                                   71.74
         95th percentile:                        6.32
         sum:                              1496142.56

Threads fairness:
    events (avg/stddev):           118764.0000/2556.79
    execution time (avg/stddev):   299.2285/0.01

#mysql服务器
# 压测前
# uptime 
 14:35:14 up 1 day, 21:36,  4 users,  load average: 0.47, 0.56, 0.11

# 压测中
# uptime 
 14:41:41 up 1 day, 21:42,  4 users,  load average: 3.56, 2.17, 1.12
```



###### 2.3 清理

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300   \
  --threads=5 \
  --percentile=95 \
  --range_selects=0 oltp_read_only cleanup
```



##### 3）写性能

###### 3.1 准备数据

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300  oltp_write_only prepare
```



###### 3.2 运行

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300 \
  --threads=5 \
  --percentile=95 \
  --report-interval=1 oltp_write_only run
```

#结果

```bash
SQL statistics:
    queries performed:
        read:                            0
        write:                           278412
        other:                           139211
        total:                           417623
    transactions:                        69597  (231.97 per sec.)
    queries:                             417623 (1391.98 per sec.)
    ignored errors:                      17     (0.06 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.0186s
    total number of events:              69597

Latency (ms):
         min:                                    4.05
         avg:                                   21.54
         max:                                  310.03
         95th percentile:                       47.47
         sum:                              1499244.94

Threads fairness:
    events (avg/stddev):           13919.4000/55.93
    execution time (avg/stddev):   299.8490/0.01

```

###### 3.3 清理

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300   \
  --threads=5 \
  --percentile=95 oltp_write_only cleanup
```



##### 4）读写性能

###### 4.1 准备数据

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300  oltp_read_write prepare
```



###### 4.2 运行

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300 \
  --threads=5 \
  --percentile=95 \
  --report-interval=1 oltp_read_write run
```



```
SQL statistics:
    queries performed:
        read:                            752458
        write:                           214973
        other:                           107489
        total:                           1074920
    transactions:                        53742  (179.10 per sec.)
    queries:                             1074920 (3582.27 per sec.)
    ignored errors:                      5      (0.02 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.0650s
    total number of events:              53742

Latency (ms):
         min:                                    6.58
         avg:                                   27.90
         max:                                  452.12
         95th percentile:                       56.84
         sum:                              1499622.53

Threads fairness:
    events (avg/stddev):           10748.4000/45.80
    execution time (avg/stddev):   299.9245/0.01
```



```bash
# uptime 
 15:24:16 up 1 day, 22:15,  4 users,  load average: 0.33, 0.58, 0.84

# uptime 
 15:26:41 up 1 day, 22:27,  4 users,  load average: 3.64, 1.92, 1.16
 # uptime 
 15:28:50 up 1 day, 22:29,  4 users,  load average: 3.87, 2.57, 1.50
```





###### 4.3 清理

```bash
sysbench \
  --db-driver=mysql \
  --mysql-host=172.18.13.112 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=Mysql2023\!\@\#Root \
  --mysql-db=testdb \
  --table_size=1000 \
  --tables=10 \
  --events=0 \
  --time=300   \
  --threads=5 \
  --percentile=95 oltp_read_write cleanup
```



##### 5）主从复制延迟

#以 10 张表，每张表 1000 条记录，读写压测 5 分钟的数据来看，主从复制的延迟在为 1s，不超过 2s（本次测试结果）

```
Seconds_Behind_Source: 1
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Source_Server_Id: 112
                  Source_UUID: b526a489-7796-11ee-b698-fefcfec91d86
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Waiting for dependent transaction to commit
           Source_Retry_Count: 86400
                  Source_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Source_SSL_Crl: 
           Source_SSL_Crlpath: 
           Retrieved_Gtid_Set: b526a489-7796-11ee-b698-fefcfec91d86:1-90185
            Executed_Gtid_Set: 0f6d9c97-77c1-11ee-92e4-fefcfebb93d1:1-2981,
7661d18c-8e10-11e7-8e9c-6c0b84d5a868:298637-298639,
b526a489-7796-11ee-b698-fefcfec91d86:1-90169
                Auto_Position: 1
```



##### 6)重新check下全库

#因为大量数据变化，特别是压测完，或者重新导入以前的旧库

#可以多执行几遍

```bash
mysqlcheck -Aa -uroot -p
```



#### 8、MySQL配置了主从，重启步骤，如果是双主，那么不需要这么操作

```
停应用 -> 停keepalived（先备后主）-> 停数据库（先备后主）-> 启数据库（先主后备）-> 启keepalived（先主后备） -> 启应用
```
```
 停keepalived从库，在从库操作
 systemctl stop keepalived
 
 停keepalived主库，在主库操作
 systemctl stop keepalived

关闭MySQL从库，在从库操作
a.先查看当前的主从同步状态 show replica status\G; 看是否双yes
b.执行stop replica;
c.停止从库服务 systemctl stop mysqld
d.查看是否还有mysql的进程ps -ef | grep mysql
d.如果部署了多个实例，那每个实例都要按照以上步骤来操作

关闭MySQL主库，在主库操作
a.停止主库服务 systemctl stop mysqld
b.查看是否还有mysql的进程ps -ef | grep mysql

启动MySQL主库，在主库操作
a.启动主库服务 systemctl start mysqld
b.查看mysql的进程ps -ef | grep mysql

启动MySQL从库，在从库操作
a.启动从库服务systemctl start mysqld
b.启动复制start replica;
c.检查同步状态  show replica status\G; 是否双yes
d.查看mysql的进程ps -ef | grep mysql

 启keepalived主库，在主库操作
 systemctl start keepalived
 
 启keepalived从库，在从库操作
 systemctl start keepalived

```



#### 9、新旧指令

```mysql
SET @@GLOBAL.read_only = OFF;

systemctl stop mysqld

/etc/my.cnf
gtid_mode=ON
enforce-gtid-consistency=ON

systemctl start mysqld

mysql> CHANGE MASTER TO
     >     MASTER_HOST = host,
     >     MASTER_PORT = port,
     >     MASTER_USER = user,
     >     MASTER_PASSWORD = password,
     >     MASTER_AUTO_POSITION = 1;

Or from MySQL 8.0.23:

mysql> CHANGE REPLICATION SOURCE TO
     >     SOURCE_HOST = host,
     >     SOURCE_PORT = port,
     >     SOURCE_USER = user,
     >     SOURCE_PASSWORD = password,
     >     SOURCE_AUTO_POSITION = 1;
     
     
mysql> START SLAVE;
Or from MySQL 8.0.22:
mysql> START REPLICA;


SET @@GLOBAL.read_only = ON;
```

#### 10、主从变双主
#在主节点上执行
```mysql
CHANGE REPLICATION SOURCE TO SOURCE_HOST='10.20.12.137',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;

start replica;
show replica status\G;

mysql> select * from performance_schema.replication_applier_status_by_worker where LAST_ERROR_NUMBER=1396;

 stop replica;
 set @@session.gtid_next='b00ea401-7990-11ee-a316-fa163e3f7e56:1'; 
 begin; 
 commit; 
 
 set @@session.gtid_next=automatic;  
 
 start replica; 
 
 SHOW REPLICA STATUS \G;
```
#此时如果主库全库导入旧库，那么导入后，双主库都需要重启mysql，不然mysql.user中的账户密码不生效

```bash
systemctl retart mysqld
```

```mysql
show replica status\G;
```



### 四、配置keepalived

#可以在线安装，也可以下载程序安装

#### 1、安装依赖包

```bash
yum install -y pcre-devel openssl-devel popt-devel libnl libnl-devel psmisc
```



#### 2、安装keepalived

#在线安装

```bash
yum install -y keepalived

keepalived -v
```

#离线部署

#官网https://www.keepalived.org/download.html

```bash
wget --no-check-certificate https://www.keepalived.org/software/keepalived-2.2.8.tar.gz
tar -zxvf keepalived-2.2.8.tar.gz
cd keepalived-2.2.8
./configure --prefix=/usr/local/keepalived-2.2.8
make && make install

mkdir /etc/keepalived
cp keepalived/etc/keepalived/keepalived.conf.sample /etc/keepalived/keepalived.conf
cp keepalived/etc/init.d/keepalived /etc/init.d/
cp keepalived/etc/sysconfig/keepalived /etc/sysconfig/
cp bin/keepalived /usr/sbin/

cat >> /etc/keepalived/shutdown.sh <<EOF
#!/bin/bash
killall keepalived
EOF

chmod +x /etc/keepalived/shutdown.sh
```



#### 3、修改/etc/keepalived/keepalived.conf

###主库

```bash
 mv /etc/keepalived/keepalived.conf  /etc/keepalived/keepalived.conf.bak

cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

#主要配置故障发生时的通知对象及机器标识
global_defs {
   router_id MYSQL-136                   #主机标识符，唯一即可
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security
}

#用来定义对外提供服务的VIP区域及相关属性
vrrp_instance VI_1 {
    state BACKUP                     #表示keepalived角色，都是设成BACKUP则以优先级为主要参考
    interface eth0                 #指定HA监听的网络接口，刚才ifconfig查看的接口名称
    virtual_router_id 117            #虚拟路由标识，取值0-255，master-1和master-2保持一致
    priority 100                     #优先级，用来选举master，取值范围1-255
    advert_int 1                     #发VRRP包时间间隔，即多久进行一次master选举
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              #虚拟出来的地址
        10.20.12.117
    }
}

#虚拟服务器定义
virtual_server 10.20.12.117 3306 { #虚拟出来的地址加端口
    delay_loop 2                     #设置运行情况检查时间，单位为秒
    lb_algo rr                       #设置后端调度器算法，rr为轮询算法
    lb_kind DR                       #设置LVS实现负载均衡的机制，有DR、NAT、TUN三种模式可选
    persistence_timeout 50           #会话保持时间，单位为秒
    protocol TCP                     #指定转发协议，有 TCP和UDP可选

        real_server 10.20.12.136 3306 {          #实际本地ip+3306端口
       weight=5                      #表示服务器的权重值。权重值越高，服务器在负载均衡中被选中的概率就越大
        #当该ip 端口连接异常时，执行该脚本
        notify_down /etc/keepalived/shutdown.sh   #检查mysql服务down掉后执行的脚本
        TCP_CHECK {
            #实际物理机ip地址
            connect_ip 10.20.12.136
            #实际物理机port端口
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}
EOF

```

```config
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   router_id MYSQL-136                   
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security
}


vrrp_instance VI_1 {
    state BACKUP                    
    interface eth0                
    virtual_router_id 117            
    priority 100                     
    advert_int 1                    
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {             
        10.20.12.117
    }
}


virtual_server 10.20.12.117 3306 { 
    delay_loop 2                   
    lb_algo rr                      
    lb_kind DR                     
    persistence_timeout 50           
    protocol TCP                  

        real_server 10.20.12.136 3306 {      
       weight=5                    
        notify_down /etc/keepalived/shutdown.sh  
        TCP_CHECK {
            connect_ip 10.20.12.136
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}
EOF
```



###从库
```
 mv /etc/keepalived/keepalived.conf  /etc/keepalived/keepalived.conf.bak


cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

#主要配置故障发生时的通知对象及机器标识
global_defs {
   router_id MYSQL-115                   #主机标识符，唯一即可
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security   
}

#用来定义对外提供服务的VIP区域及相关属性
vrrp_instance VI_1 {
    state BACKUP                     #表示keepalived角色，都是设成BACKUP则以优先级为主要参考
    interface eth0                 #指定HA监听的网络接口，刚才ifconfig查看的接口名称
    virtual_router_id 113            #虚拟路由标识，取值0-255，master-1和master-2保持一致
    priority 40                      #优先级，用来选举master，取值范围1-255
    advert_int 1                     #发VRRP包时间间隔，即多久进行一次master选举
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              #虚拟出来的地址
        172.18.13.113
    }
}

#虚拟服务器定义
virtual_server 172.18.13.113 3306 { #虚拟出来的地址加端口
    delay_loop 2                     #设置运行情况检查时间，单位为秒
    lb_algo rr                       #设置后端调度器算法，rr为轮询算法
    lb_kind DR                       #设置LVS实现负载均衡的机制，有DR、NAT、TUN三种模式可选
    persistence_timeout 50           #会话保持时间，单位为秒
    protocol TCP                     #指定转发协议，有 TCP和UDP可选

        real_server 172.18.13.115 3306 {          #实际本地ip+3306端口
       weight=5                      #表示服务器的权重值。权重值越高，服务器在负载均衡中被选中的概率就越大
        #当该ip 端口连接异常时，执行该脚本
        notify_down /etc/keepalived/shutdown.sh   #检查mysql服务down掉后执行的脚本
        TCP_CHECK {
            #实际物理机ip地址
            connect_ip 172.18.13.115
            #实际物理机port端口
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```

```config
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived


global_defs {
   router_id MYSQL-137
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security   
}


vrrp_instance VI_1 {
    state BACKUP                     
    interface eth0                 
    virtual_router_id 117            
    priority 40                     
    advert_int 1                     
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              
        10.20.12.117
    }
}


virtual_server 10.20.12.117 3306 { 
    delay_loop 2                     
    lb_algo rr                       
    lb_kind DR                       
    persistence_timeout 50           
    protocol TCP                   

        real_server 10.20.12.137 3306 {          
       weight=5                      
        notify_down /etc/keepalived/shutdown.sh   
        TCP_CHECK {
            connect_ip 10.20.12.137
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```



#### 4、启动keepalived

```bash
systemctl start keepalived

systemctl status keepalived

systemctl enable keepalived
```

#### 5、查看vip是否启动

```bash
ip a
```

发现vip在主库上：
```
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:25:46:7b brd ff:ff:ff:ff:ff:ff
    inet 172.18.13.114/16 brd 172.18.255.255 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet 172.18.13.113/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::bc1a:7ab1:f794:2418/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever

```

#### 6、主库关闭mysqld/keepalived测试

```bash
systemctl stop mysqld
systemctl status mysqld

systemctl status keepalived

ip a
```

#发现vip漂移到了从库

#测试完毕，主库记得启动mysqld和keepalived，因为主库优先级高，所以vip又漂移到了主库上面

```bash
systemctl start mysqld
systemctl status mysqld

systemctl start keepalived
systemctl status keepalived
```

#### 7、失效转移测试

#测试条件

```
172.18.13.114 mysql01
172.18.13.115 mysql02

vip: 172.18.13.113
```



#创建测试库、用户及表

```mysql
mysql> create database testdb DEFAULT CHARSET utf8mb4;
mysql> CREATE USER 'testuser'@'%' IDENTIFIED BY 'Qwert123..';
mysql> GRANT ALL PRIVILEGES ON testdb.* TO 'testuser'@'%'; 
mysql> FLUSH PRIVILEGES;
mysql> 
mysql> USE testdb;
mysql> create table nowdate(id int,ctime timestamp);
Query OK, 0 rows affected (0.02 sec)

mysql> insert into nowdate values (null,now());
Query OK, 1 row affected (0.01 sec)

mysql> select * from nowdate;
+------+---------------------+
| id   | ctime               |
+------+---------------------+
| NULL | 2023-11-03 21:27:05 |
+------+---------------------+
1 row in set (0.00 sec)

```

#执行脚本

```bash
while true; do date;mysql -u testuser -pQwert123.. -h 172.18.13.113 -e 'use testdb;insert into nowdate values (null, now());'; sleep 1;done
```

#此时主库关闭mysqld

```bash
systemctl stop mysqld
systemctl status mysqld

systemctl status keepalived
ip addr
```

#vip漂移到了从库

```bash
systemctl status keepalived
ip addr
```

#此时再次启动主库上的mysqld和keepalived，VIP再次漂移了过来

```bash
systemctl start mysqld
systemctl status mysqld

systemctl start keepalived
systemctl status keepalived

ip addr
```

#因为是双主，中间无缝切换


#### 8、Mysql双主双活+keepalived高可用整体测试

##### 1) 启动服务（启动过不需要再启动）
#首先将master-1、master-2两台服务器mysql、keepalived应用全部启动，然后新建一个用户，配置权限可以外网访问

```mysql
mysql> CREATE DATABASE IF NOT EXISTS mydb DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_general_ci;
Query OK, 1 row affected (0.10 sec)

mysql> create user 'user01'@'%' identified by 'Mysql12#$';
Query OK, 0 rows affected (0.19 sec)

mysql> grant all privileges on `mydb`.* to 'user01'@'%' ;
Query OK, 0 rows affected (0.02 sec)

mysql> flush privileges; 
Query OK, 0 rows affected (0.02 sec)

mysql> select user,host from mysql.user;
+------------------+--------------+
| user             | host         |
+------------------+--------------+
| user01           | %            |
| test             | 192.168.15.% |
| mysql.infoschema | localhost    |
| mysql.session    | localhost    |
| mysql.sys        | localhost    |
| root             | localhost    |
+------------------+--------------+
6 rows in set (0.00 sec)
```


##### 2) 连接keepalived虚拟服务器
#用mysql连接工具连接keepalived虚拟出来的172.18.13.113服务器

##### 3) 建立测试数据 
#在172.18.13.113数据库mydb测试库新建一张表，表中插入一些数据

```mysql
drop table ceshi1;

CREATE TABLE ceshi1(
    ID int,
    NAME VARCHAR(255),
    subject VARCHAR(18),
    score int);
insert into ceshi1  values(1,'张三','数学',90);
insert into ceshi1  values(2,'张三','语文',70);

select * from ceshi1;
```



##### 4) 查看master-1、master-2同步情况
#此时可以查看master-1、master-2数据库，数据已同步

##### 5) 查看100服务器实际物理机ip
#使用ip addr命令查看实际使用的物理机为172.18.13.114，所以master-1(172.18.13.114)服务器mysql为主数据库。

##### 6) 停止物理机mysql服务
#此时手动将master-1服务器mysql停止，keepalived检测到172.18.13.114服务3306端口连接失败，会执行/etc/keepalived/shutdown.sh脚本，将172.18.13.114服务器keepalived应用结束

```bash
service mysql stop
Shutting down MySQL............. SUCCESS! 
```


##### 7) 查看漂移ip执行情况
#此时再连接172.18.13.115服务下，ip addr查看，发现已经实际将物理机由master-1(172.18.13.114)到master-2(172.18.13.115)服务器上

##### 8) 在新的主服务器插入数据
#再使用mysql连接工具连接172.18.13.115的mysql，插入一条数据，测试是否将数据存入master-2(172.18.13.115)服务器mysql中

```mysql
insert into ceshi1 values(6,'李四','英语',94);
```



##### 9) 查看新主服务器数据
#查看master-2服务器mysql数据，数据已同步，说明keepalived搭建高可用成功，当master-1服务器mysql出现问题后keepalived自动漂移IP到实体机master-2服务器上，从而使master-2服务器mysql作为主数据库。

##### 10) 重启master-1服务，查看数据同步情况
#此时再启动master-1(172.18.13.114)服务器mysql、keepalived应用

```bash
systemctl start mysql
systemctl status mysql

systemctl start keepalived
systemctl status keepalived
```


 #查看master-1数据库ceshi1表数据，数据已同步成功。 

#至此，mysql双主双活+keepalived高可用部署并测试完成。

##### 11) 总结

```
1、 采用keepalived作为高可用方案时，两个节点最好都设置成BACKUP模式，避免因为意外情况下相互抢占导致两个节点内写入相同的数据而引发冲突；

2、把两个节点的auto_increment_increment（自增步长）和auto_increment_offset（字增起始值）设置成不同值，其目的是为了避免master节点意外宕机时，可能会有部分binlog未能及时复制到slave上被应用，从而会导致slave新写入数据的自增值和原master上冲突，因此一开始就错开；-----基于gtid的主从，该点不考虑

3、Slave节点服务器配置不要太差，否则更容易导致复制延迟，作为热备节点的slave服务器，硬件配置不能低于master节点；
如果对延迟很敏感的话，可考虑使用MariaDB分支版本，利用多线程复制的方式可以很大降低复制延迟。
```




### 五、mysql数据库备份

#主从库均做backup服务器的免ssh登录

```bash
ssh-keygen

ssh-copy-id root@10.20.12.129

ssh root@10.20.12.129
```

#主库配置备份脚本

```bash
mkdir -p /data/backup
touch /data/backup/mysqlbackup.sh
chmod a+x /data/backup/mysqlbackup.sh

cat > /data/backup/mysqlbackup.sh <<'EOF'
#!/bin/bash
# mysql 数据库全量备份

# 用户名和密码，注意实际情况！也可以在/etc/my.cnf中配置
username="root"
mypasswd="ABC123!@#"

beginTime=`date +"%Y年%m月%d日 %H:%M:%S"`

# 备份目录,注意实际环境目录
bakDir=/data/backup
# 日志文件
logFile=/data/backup/bak.log
# 备份文件
nowDate=`date +%Y%m%d`
dumpFile="mysql_${nowDate}.sql"
gzDumpFile="mysql136_${nowDate}.sql.tgz"

cd $bakDir
# 全量备份
/usr/bin/mysqldump -u${username} -p${mypasswd} --quick --events  --all-databases  --source-data=2 --single-transaction --set-gtid-purged=OFF > $dumpFile
# 打包
/usr/bin/tar -zvcf $gzDumpFile $dumpFile
/usr/bin/rm $dumpFile

endTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo 开始:$beginTime 结束:$endTime $gzDumpFile succ >> $logFile

##删除过期备份
find $bakDir -name 'mysql*.sql.tgz' -mtime +7 -exec rm {} \;

#scp到备份服务器
scp $gzDumpFile 10.20.12.129:/data/mysql117bak/

EOF

```



#从库备份脚本

```bash
mkdir -p /data/backup
touch /data/backup/mysqlbackup.sh
chmod a+x /data/backup/mysqlbackup.sh

cat > /data/backup/mysqlbackup.sh <<'EOF'
#!/bin/bash
# mysql 数据库全量备份

# 用户名和密码，注意实际情况！也可以在/etc/my.cnf中配置
username="root"
mypasswd="ABC123!@#"

beginTime=`date +"%Y年%m月%d日 %H:%M:%S"`

# 备份目录,注意实际环境目录
bakDir=/data/backup
# 日志文件
logFile=/data/backup/bak.log
# 备份文件
nowDate=`date +%Y%m%d`
dumpFile="mysql_${nowDate}.sql"
gzDumpFile="mysql137_${nowDate}.sql.tgz"

cd $bakDir
# 全量备份
/usr/bin/mysqldump -u${username} -p${mypasswd} --quick --events  --all-databases  --source-data=2 --single-transaction --set-gtid-purged=OFF > $dumpFile
# 打包
/usr/bin/tar -zvcf $gzDumpFile $dumpFile
/usr/bin/rm $dumpFile

endTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo 开始:$beginTime 结束:$endTime $gzDumpFile succ >> $logFile

##删除过期备份
find $bakDir -name 'mysql*.sql.tgz' -mtime +7 -exec rm {} \;

#scp到备份服务器
scp $gzDumpFile 10.20.12.129:/data/mysql117bak/

EOF

```



#每天的调度脚本

```bash
crontab -e

10 1 * * * /usr/bin/bash -x /data/backup/mysqlbackup.sh >/dev/null 2>&1
```





### 六、离线安装mysql---可选---centos7.9

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

