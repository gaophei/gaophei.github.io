#kingbase

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
• 默认字符集编码为：UTF8（可选 GBK、GB18030） 
• 默认数据库兼容模式为：ORACLE（可选 PG、MySQL） 
• 默认大小写敏感为：是（可选否）--->选 否
• 默认数据块大小为：8k（可选 16k、32k） 
• 默认加密方法为 sm4（可选 rc4） 
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



#优化kingbase数据库参数

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

work_mem = 20MB
maintenance_work_mem = 64MB

dynamic_shared_memory_type = posix


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






#创建生产库

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

```





#备份



