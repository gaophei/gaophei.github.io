[TOC]

## kingbase

### 1. 系统优化

su - root

#关闭防火墙

```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0
getenforce


systemctl stop firewalld.service && systemctl disable firewalld.service

```



#OS优化

```bash
echo "
#net.bridge.bridge-nf-call-ip6tables=1
#net.bridge.bridge-nf-call-iptables=1
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

```



#ulimit

```bash
cat >> /etc/security/limits.conf <<EOF

*            soft    nofile          65536
*            hard    nofile          65536
*            soft    core            unlimited
*            hard    core            unlimited
*            soft    sigpending      90000
*            hard    sigpending      90000
*            soft    nproc           90000
*            hard    nproc           90000
*            soft    stack           90000
*            hard    stack           90000
*            soft    memlock         unlimited
*            hard    memlock         unlimited


EOF
```



#系统语言

```bash
echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```



#DB方面优化

```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr= 1048576
fs.file-max= 6815744
kernel.shmall= 3125000
#memory*80%,此处为16G
#kernel.shmmax= 12800000000
#memory*80%,此处为32G
kernel.shmmax= 25600000000
#memory*80%,此处为64G
#kernel.shmmax= 51200000000
kernel.shmmni= 4096
kernel.sem= 6144 50331648 4096 8192
net.ipv4.ip_local_port_range= 9000 65500
net.core.rmem_default= 262144
net.core.rmem_max= 4194304
net.core.wmem_default= 262144
net.core.wmem_max= 1048576
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.ipfrag_high_thresh = 16777216
net.ipv4.ipfrag_low_thresh = 15728640
EOF

sysctl -p
```



#更新升级系统

```bash
yum update -y

reboot
```

#如果龙蜥7.9报错：

```log
Transaction check error:
  file /usr/lib64/libnss3.so conflicts between attempted installs of firefox-115.12.0-1.0.1.an7.x86_64 and nss-3.90.0-2.an7.x86_64
```



#解决办法

```bash
yum remove firefox -y
```



### 2.kingbase安装



#安装

```bash

useradd -m kingbase

passwd kingbase

#pw
KingDBBase2025!1
```





```bash
mkdir -p /opt/Kingbase/ES/V8

mkdir -p /opt/Kingbase/storage/KingbaseESV8

#放入ISO和补丁包、license文件等，具体版本以现场为准
#数据库下载地址
https://download.kingbase.com.cn/xzzx/index.htm


cd /opt/Kingbase/storage

wget https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Lin64_install.iso
#https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Kunpeng64_install.iso

#wget https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Kunpeng64_install.iso

#飞腾
#wget https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Aarch64_install.iso

#海光
#wget https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Lin64_install.iso

#龙芯
#wget https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Loongarch64_install.iso

#申威
#wget https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Sw64_install.iso

#兆芯
#wget https://kingbase.oss-cn-beijing.aliyuncs.com/KESV8R3/V008R006C009B0014/KingbaseES_V008R006C009B0014_Lin64_install.iso

chmod o+rwx /opt/Kingbase/ES/V8

chown -R kingbase:kingbase /opt/Kingbase


cd /opt/Kingbase/storage

mount KingbaseES_V008R006C009B0014_Lin64_install.iso ./KingbaseESV8
```





#切换到kingbase账户

su - kingbase

```bash
cd /opt/Kingbase/storage/KingbaseESV8


sh setup.sh

---->回车
一直到：

DO YOU ACCEPT THE TERMS OF THIS LICENSE AGREEMENT? (Y/N): 

输入Y

#默认选择1-Full,此处回车即可
--->Full

#输入授权文件位置，现场以正版key为准
/opt/Kingbase/storage/license_30646_0.dat

#安装目录，默认为/opt/Kingbase/ES/V8,直接回车即可

#数据库参数配置如下，其他步骤见下面的截图

• 默认端口为:54321（可自定义）
• 默认账户为:system（可自定义）
• 密码（自定义）
• 默认server字符集编码为：UTF8（可选 GBK、GB18030） 
• 默认Locale字符集编码为：en_US.UTF-8
• 默认数据库兼容模式为：ORACLE（可选 PG、MySQL） 
• 默认大小写敏感为：是（可选否）--->选 否
• 默认数据块大小为：8k（可选 16k、32k） 
#• 默认加密方法为 sm4（可选 rc4） 
• 默认身份认证方法为 scram-sha-256（可选 scram-sm3，sm4，sm3）


执行 root.sh
如果想注册数据库服务为系统服务，您可以在安装并初始化数据库成功后，执行 root.sh 脚本来注册并启动数据
库服务，具体步骤如下：

1. 打开新终端；
2. 切换到 root 用户；
3. 运行 ${安装目录}/install/script/root.sh 。
   如果想启动或停止数据库服务，进入 ${安装目录}/Server/bin 目录，使用 kingbase 用户执行如下命令：

# 启动服务

sys_ctl -w start -D ${Data 文件目录} -l "${Data 文件目录}/sys_log/startup.log"

# 停止服务

sys_ctl stop -m fast -w -D ${Data 文件目录}

---------------------

sys_ctl stop -m fast -w -D /opt/Kingbase/ES/V8/data
sys_ctl -w start -D /opt/Kingbase/ES/V8/data -l "/opt/Kingbase/ES/V8/data/sys_log/startup.log"

sys_ctl stop -m fast -w -D /opt/Kingbase/ES/V8/data
```



#安装过程截图

![image-20241218175946716](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218175946716.png)



![image-20241218180044601](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180044601.png)





#授权文件/opt/Kingbase/storage/license_41249_0.dat

![image-20241218180325358](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180325358.png)



#数据目录/opt/Kingbase/ES/V8

![image-20241218180434129](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180434129.png)



#检查磁盘空间

![image-20241218180550103](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180550103.png)





![image-20241218180655672](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180655672.png)





![image-20241218180809166](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180809166.png)





![image-20241218180837919](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180837919.png)





![image-20241218180915431](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218180915431.png)



#system的密码

![image-20241218181623816](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218181623816.png)







![image-20241218181705274](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218181705274.png)





![image-20241218181806746](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218181806746.png)



![image-20241218181837634](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218181837634.png)





#大小写不敏感

![image-20241218181949209](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218181949209.png)





![image-20241218182018172](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218182018172.png)



![image-20241218182052195](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218182052195.png)





![image-20241218182117230](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218182117230.png)





![image-20241218182140200](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218182140200.png)



![image-20241218182223237](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218182223237.png)



#安装结束

![image-20241218182414439](E:\workpc\git\gitio\gaophei.github.io\docs\db\kingbase-install\image-20241218182414439.png)

#

su  - root

```bash
/opt/Kingbase/ES/V8/install/script/root.sh
```

#配置PATH

```bash
cat >> /etc/profile <<EOF
export PATH=$PATH:/opt/Kingbase/ES/V8/Server/bin
EOF

source /etc/profile
```



### 3.优化kingbase数据库参数

```bash
su - kingbase
cd /opt/Kingbase/ES/V8/data
cp kingbase.conf kingbase.conf.old

> kingbase.conf
```



```conf
#32G为例，如果服务器内存未64G，下列数值可以翻倍
max_connections = 2000
shared_buffers = 16000MB
effective_cache_size = 28GB
```

#优化参数

```bash
echo "
listen_addresses = '*'
port = 54321

max_connections = 3000
superuser_reserved_connections = 5

password_encryption = scram-sha-256

#memory=32GB
shared_buffers = 16GB
max_stack_depth = 3MB

#temp_buffers = 8 MB

work_mem = 64MB
maintenance_work_mem = 1GB

dynamic_shared_memory_type = posix

idle_in_transaction_session_timeout = '2h'
statement_timeout = 60min


max_wal_size = 1GB
min_wal_size = 80MB

archive_mode = always
archive_command = 'exit 0'
wal_receiver_status_interval = 2s

wal_level = replica

fsync = on

full_page_writes = on

commit_delay = 0
commit_siblings = 5

bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0

#memory=32GB
effective_cache_size = 28GB


log_destination = 'stderr'
logging_collector = on
log_directory = 'sys_log'


log_min_duration_statement = 15000
log_line_prefix = '%t [%p]:  user=%u,db=%d,app=%a,client=%h '

log_timezone = 'Asia/Shanghai'
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_error_verbosity = default


track_sql = on
track_instance = on
track_wait_timing = on
track_counts = on
track_io_timing = on
track_functions = 'all'
sys_stat_statements.track = 'top'


datestyle = 'iso, mdy'
intervalstyle = 'sql_standard'
timezone = 'Asia/Shanghai'


lc_messages = 'en_US.UTF-8'

lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'

default_text_search_config = 'pg_catalog.english'



shared_preload_libraries = 'synonym, plsql, force_view, kdb_flashback,plugin_debugger, plsql_plugin_debugger, plsql_plprofiler, kdb_ora_expr, sepapower, dblink, sys_kwr, sys_spacequota, sys_stat_statements, backtrace, kdb_utils_function, auto_bmr, sys_squeeze, src_restrict, kdb_raw'

ora_input_emptystr_isnull = on
ora_integer_div_returnfloat = on

" >> kingbase.conf

```





#重启kingbase库

```bash
sys_ctl stop -m fast -w -D /opt/Kingbase/ES/V8/data

sys_ctl -w start -D /opt/Kingbase/ES/V8/data -l "/opt/Kingbase/ES/V8/data/sys_log/startup.log"
```





### 4.创建生产库

su - root

```bash
mkdir -p /data/tbs

chown -R kingbase:kingbase /data
```







su - kingbase

```bash
mkdir /data/tbs/authx_service

mkdir /data/tbs/cas_server

mkdir /data/tbs/jobs_server


mkdir /data/tbs/admin_center

mkdir /data/tbs/message

mkdir /data/tbs/transaction

mkdir /data/tbs/data_view


mkdir /data/tbs/formflow

mkdir /data/tbs/fileupload

mkdir /data/tbs/powerjob

mkdir /data/tbs/platform_openapi

mkdir /data/tbs/portal

mkdir /data/tbs/eams

mkdir /data/tbs/dataassets

mkdir /data/tbs/datacenter


mkdir -p /data/tbs/dataassets_kingbase/idc_data_assets
mkdir -p /data/tbs/dataassets_kingbase/idc_data_sharedb
mkdir -p /data/tbs/dataassets_kingbase/idc_data_standcode
mkdir -p /data/tbs/dataassets_kingbase/idc_data_dataquality
mkdir -p /data/tbs/dataassets_kingbase/idc_data_swop
mkdir -p /data/tbs/dataassets_kingbase/idc_data_api
mkdir -p /data/tbs/dataassets_kingbase/idc_data_dashboard
mkdir -p /data/tbs/dataassets_kingbase/idc_data_swopwork
mkdir -p /data/tbs/dataassets_kingbase/idc_data_ods
mkdir -p /data/tbs/dataassets_kingbase/idc_data_job
mkdir -p /data/tbs/dataassets_kingbase/idc_data_collect
```



```bash
ksql -U system -d test
```

```sql
create user platform_openapi connection limit -1 password 'Authxuser123';

create tablespace platform_openapi owner platform_openapi location '/data/tbs/platform_openapi';

create database platform_openapi with owner platform_openapi tablespace platform_openapi encoding utf8;


create user authx_service connection limit -1 password 'Authxuser123';

create tablespace authx_service owner authx_service location '/data/tbs/authx_service';

create database authx_service with owner authx_service tablespace authx_service encoding utf8;


create user cas_server connection limit -1 password 'Authxuser123';

create tablespace cas_server owner cas_server location '/data/tbs/cas_server';

create database cas_server with owner cas_server tablespace cas_server encoding utf8;


create user jobs_server connection limit -1 password 'Authxuser123';

create tablespace jobs_server owner jobs_server location '/data/tbs/jobs_server';

create database jobs_server with owner jobs_server tablespace jobs_server encoding utf8;


alter user authx_service superuser;

alter user cas_server superuser;

alter user jobs_server superuser;


create user admin_center connection limit -1 password 'Authxuser123';

create tablespace admin_center owner admin_center location '/data/tbs/admin_center';

create database admin_center with owner admin_center tablespace admin_center encoding utf8;




create user message connection limit -1 password 'Authxuser123';

create tablespace message owner message location '/data/tbs/message';

create database message with owner message tablespace message encoding utf8;


create user transaction connection limit -1 password 'Authxuser123';

create tablespace transaction owner transaction location '/data/tbs/transaction';

create database transaction with owner transaction tablespace transaction encoding utf8;



create user data_view connection limit -1 password 'Authxuser123';

create tablespace data_view owner data_view location '/data/tbs/data_view';

create database data_view with owner data_view tablespace data_view encoding utf8;


alter user message superuser;

alter user transaction superuser;

alter user data_view superuser;



create user formflow connection limit -1 password 'Authxuser123';

create tablespace formflow owner formflow location '/data/tbs/formflow';

create database formflow with owner formflow tablespace formflow encoding utf8;


create user fileupload connection limit -1 password 'Authxuser123';

create tablespace fileupload owner fileupload location '/data/tbs/fileupload';

create database fileupload with owner fileupload tablespace fileupload encoding utf8;


create user powerjob connection limit -1 password 'Authxuser123';

create tablespace powerjob owner powerjob location '/data/tbs/powerjob';

create database powerjob with owner powerjob tablespace powerjob encoding utf8;


alter user formflow superuser;

alter user fileupload superuser;

alter user powerjob superuser;

create schema powerjob_product authorization powerjob;


create user portal connection limit -1 password 'Authxuser123';

create tablespace portal owner portal location '/data/tbs/portal';

create database portal with owner portal tablespace portal encoding utf8;

alter user portal superuser;

create user datacenter connection limit -1 password 'DataCenter961';

create tablespace datacenter owner datacenter location '/data/tbs/datacenter';

create database datacenter with owner datacenter tablespace datacenter encoding utf8;


create user dataassets connection limit -1 password 'Authxuser123';

create tablespace dataassets owner dataassets location '/data/tbs/dataassets';

create database dataassets with owner dataassets tablespace dataassets encoding utf8;

alter user dataassets superuser;


CREATE TABLESPACE idc_data_assets OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_assets';
CREATE TABLESPACE idc_data_sharedb OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_sharedb';
CREATE TABLESPACE idc_data_standcode OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_standcode';
CREATE TABLESPACE idc_data_dataquality OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_dataquality';
CREATE TABLESPACE idc_data_swop OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_swop';
CREATE TABLESPACE idc_data_api OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_api';
CREATE TABLESPACE idc_data_dashboard OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_dashboard';
CREATE TABLESPACE idc_data_swopwork OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_swopwork';
CREATE TABLESPACE idc_data_ods OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_ods';
CREATE TABLESPACE idc_data_job OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_job';
CREATE TABLESPACE idc_data_collect OWNER dataassets LOCATION '/data/tbs/dataassets_kingbase/idc_data_collect';




create user dataassetszusi connection limit -1 password 'Authxuser123';

create tablespace dataassetszusi owner dataassetszusi location '/data/tbs/dataassets-zusi';

create database dataassetszusi with owner dataassetszusi tablespace dataassetszusi encoding utf8;

alter user dataassetszusi superuser;


```



#切换到dataassets用户

```bash
ksql -U dataassets -d dataassets
```



```sql
create schema idc_data_assets authorization dataassets;

alter user dataassets set search_path to idc_data_assets;


create schema idc_data_sharedb authorization dataassets;

create schema idc_data_standcode authorization dataassets;

create schema idc_data_dataquality authorization dataassets;

create schema idc_data_swop authorization dataassets;

create schema idc_data_api authorization dataassets;

create schema idc_data_dashboard authorization dataassets;

create schema idc_data_swopwork authorization dataassets;

create schema idc_data_ods authorization dataassets;

create schema idc_data_job authorization dataassets;

create schema idc_data_collect authorization dataassets;

```



#快速重建schema

```sql
drop schema idc_data_assets CASCADE;

drop schema idc_data_sharedb CASCADE;

drop schema idc_data_standcode CASCADE;

drop schema idc_data_dataquality CASCADE;

drop schema idc_data_swop CASCADE;

drop schema idc_data_api CASCADE;

drop schema idc_data_dashboard CASCADE;

drop schema idc_data_swopwork CASCADE;

drop schema idc_data_ods CASCADE;

drop schema idc_data_job CASCADE;

drop schema idc_data_collect CASCADE;


create schema idc_data_assets authorization dataassets;

alter user dataassets set search_path to idc_data_assets;


create schema idc_data_sharedb authorization dataassets;

create schema idc_data_standcode authorization dataassets;

create schema idc_data_dataquality authorization dataassets;

create schema idc_data_swop authorization dataassets;

create schema idc_data_api authorization dataassets;

create schema idc_data_dashboard authorization dataassets;

create schema idc_data_swopwork authorization dataassets;

create schema idc_data_ods authorization dataassets;

create schema idc_data_job authorization dataassets;

create schema idc_data_collect authorization dataassets;
```



```
人大金仓数据库信息: 

xxxx.xxxx.xxxx.xxxx  system/xxxxxx


其它账户密码均为Authxuser123

数据库名称与用户名相同


platform_openapi

 authx_service

 cas_server

 jobs_server

 admin_center

 message

 transaction

 data_view

 formflow

 fileupload

 portal

 dataassets
```





### 5.备份与还原

#备份

```bash
su - root

vi /home/kingbase/.kbpass
#hostname:port:database:username:password
192.168.106.57:54321:*:system:system


chmod 0600 /home/kingbase/.kbpass
chown kingbase:kingbase /home/kingbase/.kbpass

su - kingbase

ssh-keygen

ssh-copy-id root@172.16.50.231

#如果编译安装了openssh，那么采用以下命令
#cat ~/.ssh/id_rsa.pub | ssh root@172.16.50.231 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
#cat ~/.ssh/id_ed25519.pub | ssh root@172.16.50.231 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

[kingbase@DBServer backup]$ ls
kingbase_backup.sh  kingbase_cron.log
[kingbase@DBServer backup]$ cat kingbase_backup.sh
#!/bin/bash

HOST="10.50.50.79"
PORT="54321"
USER="system"
DATENOW="$(date +"%Y-%m-%d")"
OUTPUT_BASE_DIR=/data/backup
OUTPUT_DIR="${OUTPUT_BASE_DIR}/$DATENOW/"

mkdir -p ${OUTPUT_DIR}

echo "---------------${DATENOW}开始备份----------------"| tee -a ${OUTPUT_BASE_DIR}/backup.log

# 获取要导出的数据库列表
DATABASES=$(/opt/Kingbase/ES/V8/Server/bin/ksql -h $HOST -p $PORT -U $USER -d test -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1');")

# 导出每个数据库
for DB in $DATABASES; do
    echo "Dumping database: $DB"
    /opt/Kingbase/ES/V8/Server/bin/sys_dump -h $HOST -p $PORT -U $USER -d $DB -f "$OUTPUT_DIR/$DB.sql"
done

echo "---------------压缩备份文件$(date +"%Y-%m-%d %H:%M:%S")----------------"
cd ${OUTPUT_BASE_DIR}
tar -czvf ${DATENOW}.tar.gz ${DATENOW} --remove-files

echo "---------------传输到备份服务器$(date +"%Y-%m-%d %H:%M:%S")----------------"
#rsync
#which rsync
/bin/rsync -azv --progress -e "ssh -p 22 " ${OUTPUT_BASE_DIR}/ root@172.16.50.231:${OUTPUT_BASE_DIR}/

echo "---------------删除五天前备份的文件$(date +"%Y-%m-%d %H:%M:%S")----------------"
cd /data/backup && find . -type f -name "*.tar.gz" -mtime +5 | tee -a delete_list.log | xargs rm -f
echo "---------------备份结束$(date +"%Y-%m-%d %H:%M:%S")----------------"
echo "---------------${DATENOW}结束备份----------------"| tee -a ${OUTPUT_BASE_DIR}/backup.log
[kingbase@DBServer backup]$ crontab -l
42 15 * * * /home/kingbase/backup/kingbase_backup.sh >> /home/kingbase/backup/kingbase_cron.log
[kingbase@DBServer backup]$
```

#单次备份

```bash
DATABASES=$(/opt/Kingbase/ES/V8/Server/bin/ksql -h 192.168.106.84 -p 54321 -U system -d test -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1');")
 
for DB in $DATABASES; do
    /opt/Kingbase/ES/V8/Server/bin/sys_dump -h 192.168.106.84 -p 54321 -U system -d $DB -f "/home/kingbase/$DB.sql"
done
```



#还原

```bash
/opt/Kingbase/ES/V8/Server/bin/sys_restore -h 127.0.0.1 -p 54321 -d db_demo -U system /opt/backup/db_demo.sql >> /opt/backup/restore.log  2>&1


/opt/Kingbase/ES/V8/Server/bin/ksql -h 127.0.0.1 -p 54321 -d db_demo -U system -f /opt/backup/db_demo.sql >> /opt/backup/restore.log  2>&1

for DB in `ls |awk -F '.' '{print $1}'`;  do
   /opt/Kingbase/ES/V8/Server/bin/ksql -h 127.0.0.1 -p 54321 -d $DB -U system /opt/backup/$DB.sql >> /opt/backup/restore.log  2>&1
done

--------------------------------------

DATABASES=$(ls /home/kingbase/back-exp/2025-08-21/*.sql | xargs -n1 basename | sed 's/\.sql$//')

# 创建数据库
for DB in $DATABASES; do
  /opt/Kingbase/ES/V8/Server/bin/ksql -h 新服务器IP -p 54321 -U system -d test -c "CREATE DATABASE $DB;"
done

# 导入数据
for DB in $DATABASES; do
  /opt/Kingbase/ES/V8/Server/bin/ksql -h 172.18.13.147 -p 54321 -U system -d $DB -f "/home/kingbase/back-exp/2025-06-04/$DB.sql" >> import.log 2>&1
done

```



### 6.常用sql

#### 6.0.常用查询

```sql
#Connection
  \c[onnect] {[DBNAME|- USER|- HOST|- PORT|-] | conninfo}
                         connect to new database (currently "dataassetszusi")
  \conninfo              display information about current connection

#Informational
  (options: S = show system objects, + = additional detail)
  \d[S+]                 list tables, views, and sequences
  \d[S+]  NAME           describe table, view, sequence, or index
  \da[S]  [PATTERN]      list aggregates
  \dA[+]  [PATTERN]      list access methods
  \db[+]  [PATTERN]      list tablespaces
  \dc[S+] [PATTERN]      list conversions
  \dC[+]  [PATTERN]      list casts
  \dd[S]  [PATTERN]      show object descriptions not displayed elsewhere
  \dD[S+] [PATTERN]      list domains
  \ddp    [PATTERN]      list default privileges
  \dE[S+] [PATTERN]      list foreign tables
  \det[+] [PATTERN]      list foreign tables
  \des[+] [PATTERN]      list foreign servers
  \deu[+] [PATTERN]      list user mappings
  \dew[+] [PATTERN]      list foreign-data wrappers
  \df[anptw][S+] [PATRN] list [only agg/normal/procedures/trigger/window] functions
  \dF[+]  [PATTERN]      list text search configurations
  \dFd[+] [PATTERN]      list text search dictionaries
  \dFp[+] [PATTERN]      list text search parsers
  \dFt[+] [PATTERN]      list text search templates
  \dg[S+] [PATTERN]      list roles
  \di[S+] [PATTERN]      list indexes
  \dl                    list large objects, same as \lo_list
  \dL[S+] [PATTERN]      list procedural languages
  \dm[S+] [PATTERN]      list materialized views
  \dn[S+] [PATTERN]      list schemas
  \do[S]  [PATTERN]      list operators
  \dO[S+] [PATTERN]      list collations
  \dp     [PATTERN]      list table, view, and sequence access privileges
  \dpkg[S+] [PATTERN]    list packages
  \dP[itn+] [PATTERN]    list [only index/table] partitioned relations [n=nested]
  \drds [PATRN1 [PATRN2]] list per-database role settings
  \dRp[+] [PATTERN]      list replication publications
  \dRs[+] [PATTERN]      list replication subscriptions
  \ds[S+] [PATTERN]      list sequences
  \dt[S+] [PATTERN]      list tables
  \dT[S+] [PATTERN]      list data types
  \du[S+] [PATTERN]      list roles
  \dv[S+] [PATTERN]      list views
  \dx[+]  [PATTERN]      list extensions
  \dy     [PATTERN]      list event triggers
  \l[+]   [PATTERN]      list databases
  \sf[+]  FUNCNAME       show a function's definition
  \sv[+]  VIEWNAME       show a view's definition
  \z      [PATTERN]      same as \dp

```



#### 6.1.死元组

```sql
#慢sql
EXPLAIN ANALYZE SELECT MT.TABLE_NAME,MC.COL_NAME 
FROM METADATA_COLUMN MC 
JOIN METADATA_TABLE MT ON MT.ID=MC.TABLE_ID 
WHERE MT.DS_ID='-1' AND MC.ENCRYPT_TYPE=1;


#单库查询死元组排名前十的表
SELECT
    schemaname,
    relname,
    n_dead_tup,
    n_live_tup,
    round(n_dead_tup * 100.0 / nullif(n_live_tup, 0), 2) AS dead_percentage
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 10;

#单个表的膨胀清空
SELECT
  schemaname,
  relname,
  n_dead_tup,
  n_live_tup,
  round(n_dead_tup * 100.0 / nullif(n_live_tup, 0), 2) AS dead_percentage
FROM pg_stat_user_tables
WHERE relname = 'METADATA_COLUMN';

#在数据库log中也有记录
#automatic vacuum
#57131970 remain, 57080282 are dead but not yet removable
#system usage: CPU: user: 8.35 s, system: 1.74 s, elapsed: 37.68

/opt/Kingbase/ES/V8/data/sys_log/kingbase-2025-03-20_150538.log

2025-03-20 15:07:29 CST [31269]:  user=,db=,app=,client= LOG:  automatic vacuum of table "dataassets.idc_data_assets.METADATA_COLUMN": index scans: 0
	pages: 0 removed, 1336325 remain, 0 skipped due to pins, 0 skipped frozen
	tuples: 0 removed, 57131970 remain, 57080282 are dead but not yet removable, oldest xmin: 142139
	tuples: 0 removed by snapshotcsn, Number Snapcsn Segments: 0
	buffer usage: 2672020 hits, 1184 misses, 0 dirtied
	avg read rate: 0.245 MB/s, avg write rate: 0.000 MB/s
	system usage: CPU: user: 8.35 s, system: 1.74 s, elapsed: 37.68 sWAL usage: 0 records, 0 full page images, 0 bytes
	ref LSN: start: 2A/76E510B8 end: 2A/76E5F6A8
	
	

#定期分析表以更新统计信息
ANALYZE METADATA_COLUMN;


#设置较长的语句超时时间，因为操作可能需要很长时间
SET statement_timeout = 0;
#手动清理死元组
vacuum full verbose METADATA_COLUMN;

#REINDEX TABLE dataassets.idc_data_assets.METADATA_COLUMN;

#分析表
ANALYZE METADATA_TABLE;
ANALYZE METADATA_COLUMN;

#再次执行sql
EXPLAIN ANALYZE SELECT MT.TABLE_NAME,MC.COL_NAME 
FROM METADATA_COLUMN MC 
JOIN METADATA_TABLE MT ON MT.ID=MC.TABLE_ID 
WHERE MT.DS_ID='-1' AND MC.ENCRYPT_TYPE=1;


#死元组未被清理的主要原因可能是存在 长事务 或 未提交的事务
#检查当前活动的事务
SELECT
    pid,
    usename,
    state,
    query,
    age(clock_timestamp(), xact_start) AS transaction_duration
FROM pg_stat_activity
WHERE state IN ('idle in transaction', 'active')
ORDER BY transaction_duration DESC;

#查找长时间运行的事务
SELECT pid, datname, usename, state, backend_xmin, 
       now() - xact_start AS xact_runtime,
       now() - state_change AS state_runtime
FROM pg_stat_activity 
WHERE state != 'idle' AND backend_xmin IS NOT NULL
ORDER BY xact_runtime DESC;


#如果发现存在运行时间过长的事务，尝试终止它们
#终止超过 1 天的事务
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - xact_start > interval '1 day'; 
  
#如果需要终止特定事务（例如 PID 为 26664 的事务）
SELECT pg_terminate_backend(26664);

#长时间的 idle in transaction 通常是由于应用程序未正确关闭事务或连接造成的

#手动冻结表
#冻结表中的事务 ID，减少死元组引用
VACUUM FREEZE METADATA_COLUMN;



#批量查询所有库的前十名死元组
$ cat check.sh
#!/bin/bash
DBUSER=system
DBHOST=172.16.50.230
# 查询所有库名
databases=$(ksql -U $DBUSER -h $DBHOST -d test -Atc "SELECT datname FROM pg_database WHERE datistemplate = false;")

for db in $databases; do
    echo "==== $db ===="
    ksql -U $DBUSER -h $DBHOST -d $db -c \
    "SELECT schemaname, relname, n_dead_tup FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 10;"
done


```



#logs

```sql
#现在有个库，执行一条sql比较慢：
dataassets=# ANALYZE METADATA_TABLE;
ANALYZE
dataassets=# ANALYZE METADATA_COLUMN;
ANALYZE

dataassets=# explain analyze SELECT MT.TABLE_NAME,MC.COL_NAME
dataassets-# FROM METADATA_COLUMN MC
dataassets-# JOIN METADATA_TABLE MT ON MT.ID=MC.TABLE_ID
dataassets-# WHERE MT.DS_ID='-1' AND MC.ENCRYPT_TYPE=1;
QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------
----------------
Nested Loop (cost=2108.73..679505.32 rows=1 width=22) (actual time=4023.673..4023.675 rows=0 loops=1)
-> Seq Scan on METADATA_TABLE MT (cost=0.00..346.98 rows=273 width=48) (actual time=2.196..2.613 rows=273 loops=1)
Filter: ((ds_id)::text = '-1'::text)
Rows Removed by Filter: 3325
-> Bitmap Heap Scan on METADATA_COLUMN MC (cost=2108.73..2487.75 rows=1 width=40) (actual time=14.727..14.727 rows=0 loops=27
3)
Recheck Cond: ((table_id)::text = (MT.id)::text)
Filter: (ENCRYPT_TYPE = '1'::numeric)
Rows Removed by Filter: 19
Heap Blocks: exact=689
-> Bitmap Index Scan on ind_metadata_column_tid (cost=0.00..2108.73 rows=95 width=0) (actual time=10.448..10.448 rows=2
3359 loops=273)
Index Cond: ((table_id)::text = (MT.id)::text)
Planning Time: 4.101 ms
Execution Time: 4023.712 ms
(13 rows)

dataassets=#

#死元组强制清理
dataassets=# vacuum full verbose METADATA_COLUMN;
INFO:  vacuuming "idc_data_assets.METADATA_COLUMN"
INFO:  "METADATA_COLUMN": found 0 removable, 57236244 nonremovable row versions in 1338779 pages
DETAIL:  57184549 dead row versions cannot be removed yet.
CPU: user: 129.42 s, system: 17.01 s, elapsed: 158.22 s.

#这些死元组未被清理，可能是因为存在未提交的长事务或快照引用，导致 PostgreSQL 无法回收这些行

dataassets=# vacuum full verbose METADATA_COLUMN;
INFO:  vacuuming "idc_data_assets.METADATA_COLUMN"
INFO:  "METADATA_COLUMN": found 46119343 removable, 3572147 nonremovable row versions in 1337917 pages
DETAIL:  3520452 dead row versions cannot be removed yet.
CPU: user: 28.10 s, system: 2.09 s, elapsed: 30.89 s.
VACUUM


dataassets=# vacuum full verbose METADATA_COLUMN;
INFO:  vacuuming "idc_data_assets.METADATA_COLUMN"
INFO:  "METADATA_COLUMN": found 0 removable, 3572147 nonremovable row versions in 83733 pages
DETAIL:  3520452 dead row versions cannot be removed yet.
CPU: user: 3.62 s, system: 0.64 s, elapsed: 4.83 s.
VACUUM
dataassets=#


dataassets=# ANALYZE METADATA_TABLE;
ANALYZE
dataassets=# ANALYZE METADATA_COLUMN;
ANALYZE

dataassets=# EXPLAIN ANALYZE SELECT MT.TABLE_NAME,MC.COL_NAME
dataassets-# FROM METADATA_COLUMN MC
dataassets-# JOIN METADATA_TABLE MT ON MT.ID=MC.TABLE_ID
dataassets-# WHERE MT.DS_ID='-1' AND MC.ENCRYPT_TYPE=1;
                                                       QUERY PLAN
------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.28..1869.55 rows=1 width=22) (actual time=12.738..12.739 rows=0 loops=1)
   ->  Seq Scan on METADATA_COLUMN MC  (cost=0.00..1861.19 rows=1 width=40) (actual time=12.737..12.737 rows=0 loops=1)
         Filter: (ENCRYPT_TYPE = '1'::numeric)
         Rows Removed by Filter: 51695
   ->  Index Scan using METADATA_TABLE_pkey on METADATA_TABLE MT  (cost=0.28..8.30 rows=1 width=48) (never executed)
         Index Cond: ((id)::text = (MC.table_id)::text)
         Filter: ((ds_id)::text = '-1'::text)
 Planning Time: 1.406 ms
 Execution Time: 12.773 ms
(9 rows)

```





#### 6.2.索引膨胀

```sql
#检查索引膨胀
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;


#重建膨胀索引
REINDEX INDEX index_name;

#创建覆盖索引
#如果查询频繁过滤某些字段，可以创建覆盖索引提高性能
CREATE INDEX idx_metadata_column_tableid_encrypt
ON METADATA_COLUMN (TABLE_ID, ENCRYPT_TYPE);

```



#### 6.3.慢sql处理

```sql
#postgresql
#安装并启用 pg_stat_statements 扩展
CREATE EXTENSION pg_stat_statements;

#分析慢查询
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;

#使用 pg_stat_statements 分析慢查询
SELECT query, calls, total_time, rows
FROM pg_stat_statements
WHERE query LIKE '%METADATA_COLUMN%'
ORDER BY total_time DESC LIMIT 10;

#人大金仓
#安装并启用 sys_stat_statements 扩展
CREATE EXTENSION sys_stat_statements;

#分析慢查询
SELECT * FROM sys_stat_statements ORDER BY total_time DESC LIMIT 10;

#使用 pg_stat_statements 分析慢查询
SELECT query, calls, total_time, rows
FROM sys_stat_statements
WHERE query LIKE '%METADATA_COLUMN%'
ORDER BY total_time DESC LIMIT 10;

```



#### 6.4.**确保事务 ID 不溢出**

#PostgreSQL 使用事务 ID（`XID`）来管理表中的行版本。如果事务 ID 接近溢出（`autovacuum_freeze_max_age`），可能会导致死元组无法清理

```sql
#查看值
show autovacuum_freeze_max_age;

#检查数据库事务 ID 的使用情况
SELECT datname, age(datfrozenxid) AS xid_age FROM pg_database;

#如果事务 ID 接近溢出，执行全库冻结
VACUUM FREEZE;


```



#logs

```sql
dataassets=# show autovacuum_freeze_max_age;
 autovacuum_freeze_max_age
---------------------------
 200000000
(1 row)

dataassets=# SELECT datname, age(datfrozenxid) AS xid_age FROM pg_database;
  datname   | xid_age
------------+---------
 test       | 8190006
 kingbase   | 8190006
 template1  | 8190006
 template0  | 8190006
 security   | 8190006
 dataassets | 8190006
(6 rows)

dataassets=#

```





#### 6.5.长事务处理

```sql
#死元组未被清理的主要原因可能是存在 长事务 或 未提交的事务

#检查当前活动的事务
#带sql
SELECT
    pid,
    usename,
    application_name,
    state,
    query,
    age(clock_timestamp(), xact_start) AS transaction_duration
FROM pg_stat_activity
WHERE state IN ('idle in transaction', 'active')
ORDER BY transaction_duration DESC;

#查找长时间运行的事务
SELECT pid, datname, usename, application_name, state, backend_xmin, 
       now() - xact_start AS xact_runtime,
       now() - state_change AS state_runtime
FROM pg_stat_activity 
WHERE state != 'idle' AND backend_xmin IS NOT NULL
ORDER BY xact_runtime DESC;

#查找长时间运行的事务,带相关sql语句
SELECT pid, datname, usename, application_name, state, query, backend_xmin, 
       now() - xact_start AS xact_runtime,
       now() - state_change AS state_runtime
FROM pg_stat_activity 
WHERE state != 'idle' AND backend_xmin IS NOT NULL
ORDER BY xact_runtime DESC;


#如果发现存在运行时间过长的事务，尝试终止它们
#终止超过 1 天的事务
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - xact_start > interval '1 day'; 
  
#终止阻碍清理的事务（如运行时间超过 1 小时的事务）
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - xact_start > interval '1 hour';
  
#设置系统参数
ALTER SYSTEM SET idle_in_transaction_session_timeout = '2h';

ALTER SYSTEM SET statement_timeout = '1h';

SELECT pg_reload_conf();

  
#如果需要终止特定事务（例如 PID 为 26664 的事务）
SELECT pg_terminate_backend(26664);

#长时间的 idle in transaction 通常是由于应用程序未正确关闭事务或连接造成的

#手动执行 VACUUM FULL
#在确保没有阻碍的事务后，尝试执行 VACUUM FULL 强制清理死元组
VACUUM FULL VERBOSE METADATA_COLUMN;

#VACUUM FULL 会强制回收死元组并重建表，但需要注意：
#它会锁定整个表，期间无法进行读写操作
#表可能会暂时占用额外的磁盘空间

#设置事务超时时间
#在 PostgreSQL 配置文件（postgresql.conf）中，设置 idle_in_transaction_session_timeout 参数
idle_in_transaction_session_timeout = '10min'  # 超过 10 分钟的空闲事务将被自动终止
#也可以针对当前会话设置
SET idle_in_transaction_session_timeout = '10min';


#配置监控系统，实时监控长时间运行的事务，并设置报警机制
#超过 1 小时的事务
SELECT pid, datname, usename, state, backend_xmin,
       now() - xact_start AS xact_runtime
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - xact_start > interval '1 hour'; 


#防止查询运行时间过长
ALTER SYSTEM SET statement_timeout = '30min'; 
```

#logs

```sql
dataassets=#    -- 查找长时间运行的事务
dataassets=# SELECT pid, datname, usename, state, backend_xmin,
dataassets-#        now() - xact_start AS xact_runtime,
dataassets-#        now() - state_change AS state_runtime
dataassets-# FROM pg_stat_activity
dataassets-# WHERE state != 'idle' AND backend_xmin IS NOT NULL
dataassets-# ORDER BY xact_runtime DESC;
  pid  |  datname   |  usename   |        state        | backend_xmin |         xact_runtime          |         state_runtime
-------+------------+------------+---------------------+--------------+-------------------------------+-------------------------------
 26664 | dataassets | dataassets | idle in transaction |       142139 | +000000030 07:20:29.596678000 | +000000030 07:20:29.587738000
 26772 | dataassets | dataassets | idle in transaction |       142139 | +000000030 07:20:01.277137000 | +000000030 07:20:01.268629000
 26775 | dataassets | dataassets | idle in transaction |       142139 | +000000030 07:19:58.919943000 | +000000030 07:19:58.910549000
 21621 | dataassets | dataassets | idle in transaction |      5519844 | +000000009 04:39:41.630038000 | +000000009 04:39:41.621582000
 26872 | dataassets | dataassets | idle in transaction |      7559279 | +000000002 01:04:10.628936000 | +000000002 01:04:10.620923000
 27241 | dataassets | dataassets | idle in transaction |      7572576 | +000000002 00:44:26.895387000 | +000000002 00:06:30.855989000
 25506 | dataassets | dataassets | idle in transaction |      7566922 | +000000002 00:33:42.496160000 | +000000002 00:27:30.273175000
 27519 | dataassets | dataassets | idle in transaction |      7566560 | +000000002 00:30:18.472414000 | +000000002 00:30:18.463454000
 27520 | dataassets | dataassets | idle in transaction |      7566560 | +000000002 00:30:13.350303000 | +000000002 00:30:13.341882000
 30121 | dataassets | dataassets | idle in transaction |      7596145 | +000000001 22:15:18.776720000 | +000000001 21:36:45.295175000
  6531 | dataassets | dataassets | idle in transaction |      7680999 | +000000001 16:53:07.226865000 | +000000001 16:53:07.029764000
 19919 | dataassets | dataassets | idle in transaction |      7794808 | +000000001 06:55:45.156024000 | +000000001 06:55:36.591725000
 25286 | dataassets | dataassets | idle in transaction |      7846074 | +000000001 02:59:48.307466000 | +000000001 02:56:43.950883000
 29687 | dataassets | dataassets | idle in transaction |      7881155 | +000000001 00:12:46.842577000 | +000000001 00:12:41.750036000
 29841 | dataassets | dataassets | idle in transaction |      7889609 | +000000000 23:58:53.849443000 | +000000000 23:41:02.010867000
  4355 | dataassets | dataassets | idle in transaction |      7928090 | +000000000 20:03:18.691553000 | +000000000 20:02:23.095052000
  5514 | dataassets | dataassets | idle in transaction |      7993401 | +000000000 16:55:06.966126000 | +000000000 16:55:06.778411000
 31503 | dataassets | dataassets | idle in transaction |      8139053 | +000000000 01:58:13.319848000 | +000000000 01:58:13.070423000
 31515 | dataassets | dataassets | idle in transaction |      8154617 | +000000000 01:17:11.831062000 | +000000000 01:12:28.993400000
  2186 | dataassets | dataassets | idle in transaction |      8174755 | +000000000 00:46:49.444542000 | +000000000 00:46:49.191591000
  1715 | dataassets | dataassets | active              |      8176940 | +000000000 00:28:37.905016000 | +000000000 00:28:37.905014000
  4113 | dataassets | dataassets | active              |      8176940 | +000000000 00:28:37.905016000 | +000000000 00:11:48.629471000
 31936 | dataassets | dataassets | active              |      8176941 | +000000000 00:15:43.044923000 | +000000000 00:15:43.044872000
 31935 | dataassets | dataassets | active              |      8176941 | +000000000 00:15:43.021288000 | +000000000 00:15:43.021194000
 32554 | dataassets | dataassets | active              |      8176941 | +000000000 00:15:42.869546000 | +000000000 00:15:42.869488000
 31937 | dataassets | dataassets | active              |      8176941 | +000000000 00:14:42.959485000 | +000000000 00:14:42.959383000
 31938 | dataassets | dataassets | active              |      8176941 | +000000000 00:13:43.129444000 | +000000000 00:13:43.125687000
 31939 | dataassets | dataassets | active              |      8176941 | +000000000 00:13:42.950825000 | +000000000 00:13:42.950724000
  3955 | dataassets | dataassets | active              |      8176941 | +000000000 00:12:44.974388000 | +000000000 00:12:44.974317000
  4114 | dataassets | dataassets | active              |      8176941 | +000000000 00:11:39.498623000 | +000000000 00:11:39.498546000
 17991 | dataassets | dataassets | active              |      8176941 | +000000000 00:10:59.649776000 | +000000000 00:10:59.649772000
 17989 | dataassets | dataassets | active              |      8176941 | +000000000 00:09:59.649542000 | +000000000 00:09:59.649536000
 32640 | dataassets | dataassets | active              |      8176941 | +000000000 00:09:39.645307000 | +000000000 00:09:39.645305000
 17993 | dataassets | dataassets | active              |      8176941 | +000000000 00:08:39.638817000 | +000000000 00:08:39.638814000
 30410 | dataassets | dataassets | active              |      8176941 | +000000000 00:08:29.804668000 | +000000000 00:08:29.804536000
  4126 | dataassets | dataassets | active              |      8176941 | +000000000 00:08:29.796979000 | +000000000 00:08:29.796884000
  4215 | dataassets | dataassets | active              |      8176941 | +000000000 00:08:25.745648000 | +000000000 00:08:25.745595000
  4216 | dataassets | dataassets | active              |      8176941 | +000000000 00:08:25.704434000 | +000000000 00:08:25.704344000
  4219 | dataassets | dataassets | active              |      8176941 | +000000000 00:08:14.243242000 | +000000000 00:08:14.243239000
  4217 | dataassets | dataassets | active              |      8176941 | +000000000 00:07:25.747215000 | +000000000 00:07:25.747082000
  4220 | dataassets | dataassets | active              |      8176941 | +000000000 00:07:25.746392000 | +000000000 00:07:25.746279000
  4221 | dataassets | dataassets | active              |      8176941 | +000000000 00:07:14.236567000 | +000000000 00:07:14.236564000
 32555 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.415726000 | +000000000 00:05:02.415668000
  4284 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.385263000 | +000000000 00:05:02.385167000
  4286 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.356889000 | +000000000 00:05:02.356774000
  4287 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.356361000 | +000000000 00:05:02.356282000
  4285 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.353723000 | +000000000 00:05:02.353677000
  4288 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.330997000 | +000000000 00:05:02.330908000
  4289 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.323003000 | +000000000 00:05:02.322936000
  4290 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.264578000 | +000000000 00:05:02.264472000
  4291 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:02.165782000 | +000000000 00:05:02.165632000
  4292 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:00.278588000 | +000000000 00:05:00.278488000
  4293 | dataassets | dataassets | active              |      8176941 | +000000000 00:05:00.253448000 | +000000000 00:05:00.253353000
  4297 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:45.783605000 | +000000000 00:04:45.783593000
  4298 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:37.550862000 | +000000000 00:04:37.550859000
  4296 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:32.331673000 | +000000000 00:04:32.331671000
 32556 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.454729000 | +000000000 00:04:02.454647000
  4308 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.454217000 | +000000000 00:04:02.454112000
  4294 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.447682000 | +000000000 00:04:02.447633000
  4312 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.427154000 | +000000000 00:04:02.427045000
  4313 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.417442000 | +000000000 00:04:02.417324000
  4314 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.402802000 | +000000000 00:04:02.402726000
  4315 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.390856000 | +000000000 00:04:02.390777000
  4316 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.261082000 | +000000000 00:04:02.261018000
  4317 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:02.232575000 | +000000000 00:04:02.232480000
  4318 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:00.251063000 | +000000000 00:04:00.250996000
  4319 | dataassets | dataassets | active              |      8176941 | +000000000 00:04:00.249787000 | +000000000 00:04:00.249697000
  4322 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:45.755152000 | +000000000 00:03:45.755150000
  4325 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:37.526375000 | +000000000 00:03:37.526373000
  4334 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:32.306059000 | +000000000 00:03:32.306057000
  4335 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:13.735063000 | +000000000 00:03:13.735060000
  4336 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.456917000 | +000000000 00:03:02.456792000
  4337 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.454125000 | +000000000 00:03:02.454045000
 32553 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.448360000 | +000000000 00:03:02.448282000
  4340 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.447022000 | +000000000 00:03:02.446882000
  4341 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.422912000 | +000000000 00:03:02.422859000
  4342 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.403562000 | +000000000 00:03:02.403481000
  4343 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.379386000 | +000000000 00:03:02.379325000
  4344 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.261472000 | +000000000 00:03:02.261391000
  4345 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.235790000 | +000000000 00:03:02.235717000
  4346 | dataassets | dataassets | active              |      8176941 | +000000000 00:03:02.034610000 | +000000000 00:03:02.034607000
  4347 | dataassets | dataassets | active              |      8176941 | +000000000 00:02:48.415670000 | +000000000 00:02:48.415667000
  4350 | dataassets | dataassets | active              |      8176941 | +000000000 00:01:48.410383000 | +000000000 00:01:48.410380000
  4382 | dataassets | dataassets | active              |      8176941 | +000000000 00:00:48.385916000 | +000000000 00:00:48.385914000
  3662 | dataassets | dataassets | active              |      8176941 | +000000000 00:00:00.000000000 | -000000000 00:00:00.000003000
(85 rows)

dataassets=#
```



#### 6.6.关于某个表相关的sql

```sql
#查看某张表的表结构（列信息）
-- psql命令
\d 表名

-- SQL查询
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = '表名'
ORDER BY ordinal_position;


#查询当前正在执行的与METADATA_COLUMN相关的SQL
SELECT pid, usename, application_name, client_addr, 
       state, query_start, now() - query_start AS duration, 
       wait_event_type, wait_event, query
FROM pg_stat_activity 
WHERE query ILIKE '%METADATA_COLUMN%' 
  AND state != 'idle'
ORDER BY query_start;

SELECT pid,
       usename AS username,
       datname AS database_name,
       state,
       query,
       query_start,
       now() - query_start AS duration,
       application_name
FROM pg_stat_activity
WHERE query LIKE '%METADATA_COLUMN%'
  AND state <> 'idle';


#查询表上的锁情况
SELECT l.pid, a.usename, a.application_name, l.locktype, l.mode, 
       l.granted, a.query_start, now() - a.query_start AS duration, a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation = 'METADATA_COLUMN'::regclass
ORDER BY l.granted, a.query_start;


SELECT pg_locks.pid,
       pg_stat_activity.usename AS username,
       pg_stat_activity.query AS active_query,
       pg_locks.locktype,
       pg_locks.mode,
       pg_locks.granted,
       pg_class.relname AS locked_table
FROM pg_locks
JOIN pg_stat_activity ON pg_locks.pid = pg_stat_activity.pid
JOIN pg_class ON pg_locks.relation = pg_class.oid
WHERE pg_class.relname = 'METADATA_COLUMN';



#查询阻塞其他会话的锁
SELECT blocked.pid AS blocked_pid, 
       blocked.usename AS blocked_user,
       blocking.pid AS blocking_pid,
       blocking.usename AS blocking_user,
       blocked.query AS blocked_query,
       blocking.query AS blocking_query,
       now() - blocked.query_start AS blocked_duration
FROM pg_stat_activity blocked
JOIN pg_locks blockedl ON blocked.pid = blockedl.pid
JOIN pg_locks blockingl ON blockedl.relation = blockingl.relation 
  AND blockedl.pid != blockingl.pid
JOIN pg_stat_activity blocking ON blocking.pid = blockingl.pid
WHERE NOT blockedl.granted
  AND blockingl.granted
  AND blockedl.relation = 'METADATA_COLUMN'::regclass;


SELECT waiting_activity.pid AS waiting_pid,
       waiting_activity.usename AS waiting_user,
       waiting_activity.query AS waiting_query,
       blocking_activity.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocking_activity.query AS blocking_query
FROM pg_stat_activity waiting_activity
JOIN pg_locks waiting_locks ON waiting_activity.pid = waiting_locks.pid
JOIN pg_locks blocking_locks ON waiting_locks.locktype = blocking_locks.locktype
                              AND waiting_locks.database = blocking_locks.database
                              AND waiting_locks.relation = blocking_locks.relation
                              AND waiting_locks.pid <> blocking_locks.pid
JOIN pg_stat_activity blocking_activity ON blocking_locks.pid = blocking_activity.pid
WHERE NOT waiting_locks.granted
  AND waiting_activity.query LIKE '%METADATA_COLUMN%';


#查询长时间运行的事务
SELECT pid, usename, application_name, 
       xact_start, now() - xact_start AS xact_age,
       query_start, now() - query_start AS query_age,
       backend_xid, backend_xmin, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND (query ILIKE '%METADATA_COLUMN%' OR backend_xmin = 8190358)
ORDER BY xact_start;

#
SELECT
  blocked_locks.pid AS blocked_pid,
  blocked_activity.usename AS blocked_user,
  blocking_locks.pid AS blocking_pid,
  blocking_activity.usename AS blocking_user,
  blocked_activity.query AS blocked_query,
  blocking_activity.query AS blocking_query,
  now() - blocked_activity.query_start AS blocked_duration
FROM pg_locks blocked_locks
JOIN pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.pid != blocked_locks.pid
JOIN pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

```



#### 6.7.数据库大小

```sql
#数据库列表
SELECT datname FROM pg_database WHERE datistemplate = false;

#查看当前数据库大小
SELECT pg_size_pretty(pg_database_size(current_database()));

#查看指定数据库大小
SELECT pg_size_pretty(pg_database_size('数据库名'));

#查看所有数据库的大小列表
SELECT
  datname,
  pg_size_pretty(pg_database_size(datname)) AS size
FROM
  pg_database
ORDER BY
  pg_database_size(datname) DESC;
  
#查看某个表的大小
SELECT
  relname AS table_name,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM
  pg_catalog.pg_statio_user_tables
ORDER BY
  pg_total_relation_size(relid) DESC;

# 查看当前数据库中所有表的大小
SELECT
  relname AS table_name,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM
  pg_catalog.pg_statio_user_tables
ORDER BY
  pg_total_relation_size(relid) DESC;

#当前库表大小的前十名
SELECT
  relname AS table_name,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM
  pg_catalog.pg_statio_user_tables
ORDER BY
  pg_total_relation_size(relid) DESC limit 10;

#当前库索引大小的前十名
SELECT
  schemaname,
  relname,
  indexrelname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM
  pg_stat_user_indexes
ORDER BY
  pg_relation_size(indexrelid) DESC limit 10;


```




### 7.更新license

```bash
su - kingbase

vi /opt/Kingbase/ES/V8/license.dat

#重启kingbase
sys_ctl stop -D /opt/Kingbase/ES/V8/data/

sys_ctl -w start -D /opt/Kingbase/ES/V8/data/ -l "/opt/Kingbase/ES/V8/data/sys_log/startup.log"
```



### 8.开启防火墙

#Make absolutely sure your current SSH connection IP is in the allowlist before setting the default zone to drop, or you'll lose access!

#确保当前ssh客户端的IP在防火墙的白名单列表中

```bash
echo $SSH_CLIENT | awk '{print $1}'
```



#方式一

```bash
# Add rich rules for each IP address
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.213" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.214" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.215" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.216" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.217" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.218" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.219" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.221" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.222" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.223" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.224" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.225" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.226" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.227" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.228" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.229" port protocol="tcp" port="54321" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.50.232" port protocol="tcp" port="54321" accept'

# Reload firewall
firewall-cmd --reload
```

#方式一改进

```bash
for ip in 172.16.50.213 172.16.50.214 172.16.50.215 172.16.50.216 172.16.50.217 172.16.50.218 172.16.50.219 172.16.50.221 172.16.50.222 172.16.50.223 172.16.50.224 172.16.50.225 172.16.50.226 172.16.50.227 172.16.50.228 172.16.50.229 172.16.50.232; do
  firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address=\"${ip}\" accept"
done
```



#方式二

```bash
# First, ensure firewalld is running
systemctl start firewalld
systemctl enable firewalld

# Create a new zone for Kingbase (optional but recommended for better organization)
firewall-cmd --permanent --new-zone=kingbase

# Add the allowed IP addresses as sources to the zone
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.213
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.214
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.215
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.216
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.217
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.218
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.219
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.221
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.222
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.223
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.224
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.225
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.226
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.227
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.228
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.229
firewall-cmd --permanent --zone=kingbase --add-source=172.16.50.232

# Add the Kingbase port (default is 54321, adjust if different)
#firewall-cmd --permanent --zone=kingbase --add-port=54321/tcp
#firewall-cmd --permanent --zone=kingbase --add-port=22/tcp

# Or if you want to allow all ports from these IPs (as mentioned "unrestricted access port")
firewall-cmd --permanent --zone=kingbase --set-target=ACCEPT

# Remove the Kingbase port from other zones if it was previously added
firewall-cmd --permanent --zone=public --remove-port=54321/tcp

# Reload the firewall to apply changes
firewall-cmd --reload

# Verify the configuration
firewall-cmd --zone=kingbase --list-all
```



#方式二改进，不限制端口

```bash
systemctl start firewalld
systemctl enable firewalld

firewall-cmd --permanent --new-zone=allowlist
firewall-cmd --permanent --zone=allowlist --set-target=ACCEPT

for ip in 172.16.50.213 172.16.50.214 172.16.50.215 172.16.50.216 172.16.50.217 172.16.50.218 172.16.50.219 172.16.50.221 172.16.50.222 172.16.50.223 172.16.50.224 172.16.50.225 172.16.50.226 172.16.50.227 172.16.50.228 172.16.50.229 172.16.50.232; do
  firewall-cmd --permanent --zone=allowlist --add-source=${ip}/32
done

firewall-cmd --permanent --zone=allowlist --add-source=127.0.0.1/32

firewall-cmd --reload

firewall-cmd --set-default-zone=drop

firewall-cmd --get-default-zone
firewall-cmd --zone=allowlist --list-all
firewall-cmd --zone=drop --list-all
firewall-cmd --list-all
```



#命令分层

```bash
# First, ensure firewalld is running
systemctl start firewalld
systemctl enable firewalld

# Create the allowlist zone
firewall-cmd --permanent --new-zone=allowlist

# Set the zone to ACCEPT traffic from its sources
firewall-cmd --permanent --zone=allowlist --set-target=ACCEPT

# Add all allowed IPs to the allowlist zone
for ip in 172.16.50.213 172.16.50.214 172.16.50.215 172.16.50.216 172.16.50.217 172.16.50.218 172.16.50.219 172.16.50.221 172.16.50.222 172.16.50.223 172.16.50.224 172.16.50.225 172.16.50.226 172.16.50.227 172.16.50.228 172.16.50.229 172.16.50.232; do
  firewall-cmd --permanent --zone=allowlist --add-source=${ip}/32
done

firewall-cmd --permanent --zone=allowlist --add-source=127.0.0.1/32

# Reload to apply changes
firewall-cmd --reload

# Set default zone to drop (blocks everything not explicitly allowed)
# --set-default-zone changes both runtime and permanent configuration automatically, so it doesn't need (and can't use) the --permanent flag
# This command will immediately change the default zone and the change will persist across reboots
firewall-cmd --set-default-zone=drop

# Verify the configuration
firewall-cmd --get-default-zone
firewall-cmd --zone=allowlist --list-all
firewall-cmd --zone=drop --list-all
firewall-cmd --list-all
```



### 9.死元组的autovacuum 的触发阈值

```bash
kingbase V8版本，目前部分表可以自动处理死元组，但是部分表为什么没有自动处理？
[kingbase@DBServer sys_log]$ tail -1000f kingbase-2025-11-03_000000.log |grep METADATA_COLUMN
2025-11-03 14:02:18 CST [7101]:  user=,db=,app=,client= LOG:  automatic vacuum of table "dataassets.idc_data_assets.METADATA_COLUMN_RULE_GROUPS": index scans: 1
2025-11-03 14:02:18 CST [7101]:  user=,db=,app=,client= LOG:  automatic analyze of table "dataassets.idc_data_assets.METADATA_COLUMN_RULE_GROUPS" system usage: CPU: user: 0.02 s, system: 0.00 s, elapsed: 0.02 s
2025-11-03 14:02:18 CST [7101]:  user=,db=,app=,client= LOG:  automatic vacuum of table "dataassets.idc_data_assets.METADATA_COLUMN": index scans: 1
2025-11-03 14:02:20 CST [7101]:  user=,db=,app=,client= LOG:  automatic analyze of table "dataassets.idc_data_assets.METADATA_COLUMN" system usage: CPU: user: 2.16 s, system: 0.00 s, elapsed: 2.21 s
^C
[kingbase@DBServer sys_log]$ tail -1000f kingbase-2025-11-03_000000.log |grep ODS_ITEMS_IN_API
^C
[kingbase@DBServer sys_log]$ tail -1000f kingbase-2025-11-02_000000.log |grep ODS_ITEMS_IN_API
^C
[kingbase@DBServer sys_log]$ tail -1000f kingbase-2025-11-02_000000.log |grep ODS_ITEMS_IN_API
^C
[kingbase@DBServer sys_log]$ tail -1000f kingbase-2025-11-01_000000.log |grep ODS_ITEMS_IN_API
^C
[kingbase@DBServer sys_log]$ tail -1000f kingbase-2025-11-01_000000.log |grep METADATA_COLUMN
2025-11-01 23:02:45 CST [13657]:  user=,db=,app=,client= LOG:  automatic vacuum of table "dataassets.idc_data_assets.METADATA_COLUMN_RULE_GROUPS": index scans: 1
2025-11-01 23:02:45 CST [13657]:  user=,db=,app=,client= LOG:  automatic analyze of table "dataassets.idc_data_assets.METADATA_COLUMN_RULE_GROUPS" system usage: CPU: user: 0.02 s, system: 0.00 s, elapsed: 0.02 s
2025-11-01 23:02:45 CST [13657]:  user=,db=,app=,client= LOG:  automatic vacuum of table "dataassets.idc_data_assets.METADATA_COLUMN": index scans: 1
2025-11-01 23:02:47 CST [13657]:  user=,db=,app=,client= LOG:  automatic analyze of table "dataassets.idc_data_assets.METADATA_COLUMN" system usage: CPU: user: 2.20 s, system: 0.00 s, elapsed: 2.25 s
^C
[kingbase@DBServer sys_log]$
```

```sql
SELECT schemaname, relname, n_dead_tup, n_live_tup,
       round(n_dead_tup*100.0/nullif(n_live_tup,0),2) AS dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

```logs
schemaname	relname	n_dead_tup	n_live_tup	dead_pct
idc_data_dashboard	ODS_ITEMS_IN_API	33902	200585	16.90
idc_data_assets	JOB_TASK_LOG	19737	248948	7.93
idc_data_sharedb	ZCXTSJZD001	8538	92072	9.27
idc_data_dashboard	ods_table_data_stat	7594	82047	9.26
idc_data_dashboard	ODS_AS_METADATA_COLUMN	6913	72161	9.58
idc_data_dashboard	ods_as_code_execute_code	6130	96308	6.36
idc_data_swopwork	R_STEP_ATTRIBUTE	5962	39760	14.99
idc_data_assets	DATA_TOTAL_RESULT_TABLE	5408	83645	6.47
idc_data_sharedb	JX_XSPYKC	4927	226292	2.18
idc_data_dashboard	ods_job_task	4076	39025	10.44
idc_data_dashboard	ods_as_model_execute_item	3618	20756	17.43
idc_data_dashboard	ods_swop_trans	3286	28077	11.70
idc_data_sharedb	JX_JSKCB	3276	16750	19.56
idc_data_swop	R_STEP_ATTRIBUTE	2835	94494	3.00
idc_data_sharedb	xyk_yktryxx	2317	48261	4.80
idc_data_assets	METADATA_COLLECT_RESULT	2261	109625	2.06
idc_data_assets	METADATA_COLLECT_LOG_DETAIL	2261	109844	2.06
idc_data_swopwork	R_TRANS_ATTRIBUTE	2220	24642	9.01
idc_data_dashboard	ods_swop_trans_data_count	2157	17209	12.53
idc_data_assets	METADATA_COLUMN_CHANGE	2151	105393	2.04
```

-------------------



看图里的统计+日志，其实是**阈值没到**的典型现象：
Autovacuum 是否对某个表做 VACUUM，主要看这个触发公式（KingbaseV8≃PostgreSQL）：

> vacuum_threshold = autovacuum_vacuum_threshold
>  + autovacuum_vacuum_scale_factor × reltuples(≈表中“活”行数)

默认一般是：`autovacuum_vacuum_threshold=50`、`autovacuum_vacuum_scale_factor=0.2`。

用截图里的两个表粗算一下（用 n_live_tup 近似 reltuples 就够用了）：

* **ODS_ITEMS_IN_API**：
  n_live_tup≈200,585 ⇒ 阈值 ≈ 50 + 0.2×200,585 = **40,167**
  n_dead_tup=33,902 　**< 40,167** → 没达到触发条件，所以这几天日志里看不到它的自动 VACUUM，很正常。
* **METADATA_COLUMN**：
  n_live_tup≈72,161 ⇒ 阈值 ≈ 50 + 0.2×72,161 = **14,482**
  这个表近期的 autovacuum 日志能看到，可能是**达到了阈值**，或者该表**设置了更激进的 per-table 参数**，又或者是**冻结/插入阈值**触发（某些版本带 `autovacuum_vacuum_insert_threshold/_scale_factor` 时，最近插入很多也会触发）。

> 补充：如果存在**长事务/闲置但未提交的事务**、逻辑复制槽卡住、热备长查询等，也会阻止清理；你上次手动 kill 掉 “idle in transaction” 后自动清理恢复，正说明这类阻塞也在影响效果。

---

#### 9.1.一键自查 SQL（直接执行就能看出“谁该被扫”）

```sql
-- 计算每张表当前的 VACUUM 触发阈值和是否已超过
WITH p AS (
  SELECT
    current_setting('autovacuum_vacuum_threshold')::int  AS thr,
    current_setting('autovacuum_vacuum_scale_factor')::numeric AS sf
)
SELECT s.schemaname, s.relname, s.n_live_tup, s.n_dead_tup,
       (p.thr + p.sf * GREATEST(s.n_live_tup,0))::bigint AS vacuum_threshold,
       (s.n_dead_tup - (p.thr + p.sf * GREATEST(s.n_live_tup,0)))::bigint AS over_by
FROM pg_stat_user_tables s, p
ORDER BY over_by DESC
LIMIT 50;
```

查看是否对单表做过特殊配置（可能解释为什么同库里有的表会自动扫、有的不会）：

```sql
SELECT n.nspname, c.relname, c.reloptions
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE c.reloptions IS NOT NULL
  AND c.relname IN ('ODS_ITEMS_IN_API','METADATA_COLUMN');
```

排查会阻止回收的长事务/复制槽：

```sql
-- 长事务 / idle in transaction（会抬高全库 xmin）
SELECT pid, usename, state, xact_start, now()-xact_start AS age, query
FROM pg_stat_activity
WHERE backend_xid IS NOT NULL OR state='idle in transaction'
ORDER BY xact_start;

-- 复制槽是否卡住
SELECT slot_name, active, pg_size_pretty(pg_xlog_location_diff(pg_current_xlog_location(), restart_lsn)) AS lag
FROM pg_replication_slots;
```

---

#### 9.2.该怎么做

**短期（立刻见效）**

* 手动处理个别表：

  ```sql
  VACUUM (VERBOSE, ANALYZE) idc_data_dashboard."ODS_ITEMS_IN_API";
  ```

  若明确空间已严重膨胀并可接受锁表维护，再考虑 `VACUUM (FULL)`。

**中期（让它以后“自动扫”起来）**

* 只对“更新/删除频繁”的大表下调阈值，避免全库成本上升：

  ```sql
  ALTER TABLE idc_data_dashboard."ODS_ITEMS_IN_API"
    SET (autovacuum_vacuum_scale_factor = 0.05,
         autovacuum_vacuum_threshold     = 2000,
         autovacuum_analyze_scale_factor = 0.05,
         autovacuum_analyze_threshold    = 500);
  ```

  这样 ODS_ITEMS_IN_API 的触发线从 ~4 万降到 ~1 万以内，能更勤快地扫。

* 保持你之前的“超时”设置（能防止 idle in transaction 卡住清理），但建议**先按会话/角色设置**，避免误杀 ETL/批处理长 SQL：

  ```sql
  -- 对特定角色
  ALTER ROLE etl_user SET idle_in_transaction_session_timeout = '1h';
  ALTER ROLE etl_user SET statement_timeout = '30min';
  ```

**长期（全局策略 & 监控）**

* 如果这是个数仓/ETL 型系统，普遍更新量大，可以考虑全局把 scale_factor 降到 0.05～0.1：

  ```sql
  ALTER SYSTEM SET autovacuum_vacuum_scale_factor = '0.05';
  ALTER SYSTEM SET autovacuum_analyze_scale_factor = '0.05';
  SELECT pg_reload_conf();
  ```
* 确认并适当提高并发与速度：

  ```sql
  SHOW autovacuum_max_workers;          -- 视实例规模设为 5~10
  SHOW autovacuum_vacuum_cost_limit;    -- 提高能加快清理
  SHOW maintenance_work_mem;            -- 适当增大便于索引清理
  ```
* 打开详细日志方便日常观察：

  ```sql
  ALTER SYSTEM SET log_autovacuum_min_duration = 0;
  SELECT pg_reload_conf();
  ```

**结论**：
看到“有的表扫、有的表不扫”，主要是**没有达到 autovacuum 的触发阈值**；个别能扫的表，要么达标了，要么被设置了更激进的参数，或被“冻结/插入阈值”触发。按上面的自查 SQL 验证一下，再对热点表**单表下调阈值**，基本就能让它们也自动清理起来。

