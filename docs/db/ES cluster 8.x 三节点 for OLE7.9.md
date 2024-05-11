此文档提供安装elasticsearch8.13(最新版8.13.3)三节点集群模式的安装

****

#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小，es安装到最大分区里
#20240507安装版本为8.13.3

## 服务器资源

#建议

```
vm: 16核/32G 

OS: oracle Linux 7.9(5.4.17-2011.6.2.el7uek.x86_64)

磁盘LVM管理，挂载第二块磁盘1T，/data为最大分区

/opt/elasticsearch为程序目录
/data/data为数据目录
/data/log为日志目录
```



#最少三台

| 序号 |    IP地址     |       主机名       |    角色     | 备注 |
| :--: | :-----------: | :----------------: | :---------: | :--: |
|  1   | 172.18.13.112 |   k8s-mysql-ole    | master,data |      |
|  2   | 172.18.13.117 | k8s-mysql-ole-117  | master,data |      |
|  3   | 172.18.13.120 | k8s-mysql-ole-test | master,data |      |
|  4   |               |                    |   ingest    |      |
|  5   |               |                    |   ingest    |      |







## 部署过程

### 一、系统优化

#官网必须优化项目

```
https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html
```

```
The following settings must be considered before going to production:

Configure system settings
Disable swapping
Increase file descriptors
Ensure sufficient virtual memory
Ensure sufficient threads
JVM DNS cache settings
Temporary directory not mounted with noexec
TCP retransmission timeout
```

#### 0、修改源文件

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

#### 1、Hostname修改

#hostname命名建议规范，以实际IP为准

```bash
cat >> /etc/hosts <<EOF
172.18.13.112 k8s-mysql-ole
172.18.13.117 k8s-mysql-ole-117
172.18.13.120 k8s-mysql-ole-test
EOF

#k8s-mysql-ole
hostnamectl set-hostname k8s-mysql-ole
#k8s-mysql-ole-117
hostnamectl set-hostname k8s-mysql-ole-117
#k8s-mysql-ole-test
hostnamectl set-hostname k8s-mysql-ole-test

hostnamectl status

ping k8s-mysql-ole  -c 3
ping k8s-mysql-ole-117  -c 3
ping k8s-mysql-ole-test -c 3

```

```
[root@localhost ~]# hostnamectl set-hostname k8s-mysql-ole
[root@localhost ~]# exit

[root@k8s-mysql-ole ~]# hostnamectl status
   Static hostname: k8s-mysql-ole
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 4e99db48ca56469d86d4043965953a54
           Boot ID: d7b0f5da94ba4c43b9f3432a6c1258c1
    Virtualization: kvm
  Operating System: Oracle Linux Server 7.9
       CPE OS Name: cpe:/o:oracle:linux:7:9:server
            Kernel: Linux 5.4.17-2011.6.2.el7uek.x86_64
      Architecture: x86-64

[root@k8s-mysql-ole ~]# cat >> /etc/hosts <<EOF
172.18.13.112 k8s-mysql-ole
172.18.13.117 k8s-mysql-ole-117
172.18.13.120 k8s-mysql-ole-test
EOF

[root@k8s-mysql-ole ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.18.13.112 k8s-mysql-ole
172.18.13.117 k8s-mysql-ole-117
172.18.13.120 k8s-mysql-ole-test

[root@k8s-mysql-ole ~]# ping k8s-mysql-ole -c 1
PING k8s-mysql-ole (172.18.13.112) 56(84) bytes of data.
64 bytes from k8s-mysql-ole (172.18.13.112): icmp_seq=1 ttl=64 time=0.065 ms

--- k8s-mysql-ole ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.065/0.065/0.065/0.000 ms

[root@k8s-mysql-ole ~]# ping k8s-mysql-ole-117 -c 1
PING k8s-mysql-ole-117 (172.18.13.117) 56(84) bytes of data.
64 bytes from k8s-mysql-ole-117 (172.18.13.117): icmp_seq=1 ttl=64 time=0.619 ms

--- k8s-mysql-ole-117 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.619/0.619/0.619/0.000 ms

[root@k8s-mysql-ole ~]# ping k8s-mysql-ole-test -c 1
PING k8s-mysql-ole-test (172.18.13.120) 56(84) bytes of data.
64 bytes from k8s-mysql-ole-117 (172.18.13.120): icmp_seq=1 ttl=64 time=0.619 ms

--- k8s-mysql-ole-117 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.619/0.619/0.619/0.000 ms

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

#### 3. 禁用swap分区

#临时关闭

```bash
swapoff -a
```
#永久关闭

```bash
sed -i '/swap/s/^/#/' /etc/fstab
```

#确认

```bash
free -m

cat /etc/fstab
```



#### 4、创建用户

#es不能用root用户进行部署，得在每个机器上新建一个用户，部署的步骤都在这个新用户上进行

```bash
useradd elasticsearch && echo es123\!\@\# |passwd --stdin elasticsearch
```

#添加到sudo组中

```bash
visudo

#添加一行
elasticsearch ALL=(ALL) NOPASSWD:ALL
```



#logs

```bash
[root@k8s-mysql-ole-117 ~]# useradd elasticsearch && echo es123\!\@\# |passwd --stdin elasticsearch
Changing password for user elasticsearch.
passwd: all authentication tokens updated successfully.
```



#### 5、开始时间同步及修改东8区

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

#### 6、语言修改为utf8---centos7.9

```bash
env|grep LANG
echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```

#### 7、内核模块调优

##### 1）内核模块

#备份

```bash
cp /etc/sysctl.conf /etc/sysctl.conf.bak
```



#优化

```bash
echo "
net.ipv4.tcp_retries2=5

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
#vm.max_map_count=262144
vm.max_map_count=655360
fs.may_detach_mounts=1
net.core.netdev_max_backlog=16384
net.ipv4.tcp_wmem=4096 12582912 16777216
net.core.wmem_max=16777216
net.core.somaxconn=32768
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



#检查

```bash
sysctl net.ipv4.tcp_retries2

sysctl vm.max_map_count

sysctl vm.swappiness
```



#logs

```bash
[root@k8s-mysql-ole ~]# sysctl net.ipv4.tcp_retries2
net.ipv4.tcp_retries2 = 5

[root@k8s-mysql-ole ~]# sysctl vm.max_map_count
vm.max_map_count = 65530

[root@k8s-mysql-ole ~]# sysctl vm.swappiness
vm.swappiness = 0
```





##### 2）open-files

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
*            soft    stack           90000
*            hard    stack           90000
*            soft    memlock         unlimited
*            hard    memlock         unlimited

EOF


cat /etc/security/limits.d/20-nproc.conf
cat /etc/security/limits.conf

#ubuntu 22.04
cat >> /etc/security/limits.conf <<EOF

elasticsearch            soft    nofile          65536
elasticsearch            hard    nofile          65536
elasticsearch            soft    core            unlimited
elasticsearch            hard    core            unlimited
elasticsearch            soft    sigpending      90000
elasticsearch            hard    sigpending      90000
elasticsearch            soft    nproc           90000
elasticsearch            hard    nproc           90000
elasticsearch            soft    stack           90000
elasticsearch            hard    stack           90000
elasticsearch            soft    memlock         unlimited
elasticsearch            hard    memlock         unlimited

EOF
```



#es查询

```bash
GET _nodes/stats/process?filter_path=**.max_file_descriptors
```



### 二、安装es---centos7.9

#### 1、规划

#建议

```
vm: 16核/32G 

OS: oracle Linux 7.9(5.4.17-2011.6.2.el7uek.x86_64)

磁盘LVM管理，挂载第二块磁盘1T，/data为最大分区

/opt/elasticsearch为程序目录
/data/data为数据目录
/data/log为日志目录
```
#目录规划

| 序号 |        目录        |   内容   | 备注 |
| :--: | :----------------: | :------: | :--: |
|  1   | /opt/elasticsearch | 程序目录 |      |
|  2   |     /data/data     | 数据目录 |      |
|  3   |     /data/log      | 日志目录 |      |
|  4   |                    |          |      |
|  5   |                    |          |      |

#最少三台，只允许一台掉线

| 序号 |    IP地址     |       主机名       |    角色     | 备注 |
| :--: | :-----------: | :----------------: | :---------: | :--: |
|  1   | 172.18.13.112 |   k8s-mysql-ole    | master,data |      |
|  2   | 172.18.13.117 | k8s-mysql-ole-117  | master,data |      |
|  3   | 172.18.13.120 | k8s-mysql-ole-test | master,data |      |
|  4   |               |                    |   ingest    |      |
|  5   |               |                    |   ingest    |      |





#### 2、下载elasticsearch---三个节点同样操作

```bash
su - root

yum install -y wget net-tools


mkdir /opt/soft
mkdir /opt/elasticsearch

mkdir -p /data/data
mkdir -p /data/log

chown -R elasticsearch:elasticsearch /opt/soft

chown -R elasticsearch:elasticsearch /opt/elasticsearch

chown -R elasticsearch:elasticsearch /data/data

chown -R elasticsearch:elasticsearch /data/log

#官网
https://www.elastic.co/downloads/elasticsearch

#根据服务器OS不同，下载相关压缩包，此处为linux X86_64

#8.13.3
su - elasticsearch

cd /opt/soft

wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.13.3-linux-x86_64.tar.gz

tar -zxvf elasticsearch-8.13.3-linux-x86_64.tar.gz -C /opt/elasticsearch --strip-components=1
```

#### 3、配置环境变量

#采用es内置的jdk

```bash
su - root

cat >> /etc/profile <<'EOF'
export JAVA_HOME=/opt/elasticsearch/jdk
export ES_HOME=/opt/elasticsearch
export PATH=$PATH:$ES_HOME/bin:$JAVA_HOME/bin
EOF


source /etc/profile

java -version
```



#### 4、优化es配置---三个节点有细微差别

#官网文档

```bash
https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html
```

#三个重要的配置文件(/opt/elasticsearch/config)

| 序号 |       名称        |            作用             | 备注 |
| :--: | :---------------: | :-------------------------: | :--: |
|  1   | elasticsearch.yml |     配置 Elasticsearch      |      |
|  2   |    jvm.options    | 配置 Elasticsearch JVM 设置 |      |
|  3   | log4j2.properties | 配置 Elasticsearch 日志记录 |      |

##### 0)基本配置

#elasticsearch.yml
```yaml
cluster.name: supwisdom
#根据每台节点进行修改
node.name: node-1
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
#根据每台节点进行修改
#network.host: 0.0.0.0
#network.host: "_en0:ipv4_"
#network.host: "_en0:ipv6_"
network.host: 172.18.13.112
http.port: 9200
discovery.seed_hosts: ["k8s-mysql-ole", "k8s-mysql-ole-117", "k8s-mysql-ole-test"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000

#可以关闭xpack功能
xpack.security.enabled: false
```

#待验证

```yaml
#解决数据迁移时的报错：org.elasticsearch.client.ResponseException: method [POST], host [http://192.168.6.171:9200], URI [/demo/_bulk], status line [HTTP/1.1 413 Request Entity Too Large
#也不能太大，否则会导致报错：java.lang.IllegalArgumentException: failed to parse value [20000mb] for setting [http.max_content_length], must be <= [2147483647b]
http.max_content_length: 2000mb

#解决java通过DSL的script操作时的报错："[es/put_script] failed: [illegal_argument_exception] exceeded max allowed stored script size in bytes [65535] with size [502007] for script [dsl1]"
script.max_size_in_bytes: 10000000

#解决java通过DSL的script操作时的报错：[script] Too many dynamic script compilations within, max: [150/5m]; please use indexed, or scripts with parameters instead; this limit can be changed by the [script.max_compilations_rate] setting
script.max_compilations_rate: 60000/1m


#其他：

# index_buffer
indices.memory.index_buffer_size: 15%
indices.memory.min_index_buffer_size: 96mb

# 用于 Get 请求的线程池（queue_size默认为1000）
thread_pool.get.queue_size: 5000

# 用于 index/delete/update/bulk 请求的写线程池（queue_size默认为10000）
thread_pool.write.queue_size: 20000

# 用于 count/search/suggest 等操作的搜索线程池（queue_size默认为1000）
thread_pool.search.queue_size: 5000
```



#shard

```
The cluster shard limit defaults to 1000 shards per non-frozen data node for normal (non-frozen) indices and 3000 shards per frozen data node for frozen indices. Both primary and replica shards of all open indices count toward the limit, including unassigned shards. For example, an open index with 5 primary shards and 2 replicas counts as 15 shards. Closed indices do not contribute to the shard count.
```



#JVM参数

#默认不修改

#如果需要手动设置JVM 堆大小

```yaml
cat >> /opt/elasticsearch/config/jvm.options.d/java01.conf <<EOF
-Xms16g
-Xmx16g
EOF
```

#如果需要修改JVM堆转储路径

#jvm.options

```bash
#-XX:HeapDumpPath=data
-XX:HeapDumpPath=/data/data/
```



#log4j2.properties

```yaml


```





##### 1) k8s-mysql-ole

#elasticsearch.yml

```yaml
cluster.name: supwisdom
node.name: node-1
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 172.18.13.112
http.port: 9200
discovery.seed_hosts: ["k8s-mysql-ole", "k8s-mysql-ole-117", "k8s-mysql-ole-test"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
```



##### 2) k8s-mysql-ole-117

#elasticsearch.yml
```yaml
cluster.name: supwisdom
node.name: node-2
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 172.18.13.117
http.port: 9200
discovery.seed_hosts: ["k8s-mysql-ole", "k8s-mysql-ole-117", "k8s-mysql-ole-test"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
```



##### 3) k8s-mysql-ole-test

#elasticsearch.yml
```yaml
cluster.name: supwisdom
node.name: node-3
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 172.18.13.120
http.port: 9200
discovery.seed_hosts: ["k8s-mysql-ole", "k8s-mysql-ole-117", "k8s-mysql-ole-test"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000

```



#### 5、启动与关闭elasticsearch

```bash
#启动
elasticsearch -d

#开机自启
systemctl start elasticsearch

#关闭
ps -ef | grep elasticsearch|grep -vE "grep|controller" |awk '{print $2}'|xargs kill -9
```



#如果修改es的配置，需要重启节点的es

```bash
#重启前
#curl -H "Content-Type: application/json" -XPUT 172.18.13.112:9200/_cluster/settings -d'{"transient":{"cluster.routing.allocation.disable_allocation":true}}'


#重启后
#curl -H "Content-Type: application/json" -XPUT localhost:9200/_cluster/settings -d '{"transient":{"cluster.routing.allocation.disable_allocation":false}}'
```



#### 6、访问

```bash
http://172.18.13.112:9200/_nodes/stats

http://172.18.13.117:9200/_nodes/stats

http://172.18.13.120:9200/_nodes/stats
```

#### 7、安全配置，开启xpack并配置

##### 7.1、开启xpack

```mysql

```



### 三、安装kibana

#官网

```
https://www.elastic.co/guide/en/kibana/8.13/get-started.html
```



#### 1、创建目录

```bash
su - root
mkdir /opt/kibana
chown -R elasticsearch:elasticsearch /opt/kibana
```



#### 2、下载kibana

#下载与es同版本的

#仅node-1节点安装即可

```bas
su - elasticsearch
cd /opt/soft

wget https://artifacts.elastic.co/downloads/kibana/kibana-8.13.3-linux-x86_64.tar.gz

tar -zxvf kibana-8.13.3-linux-x86_64.tar.gz -C  /opt/kibana --strip-components=1
```



#### 3、修改配置

#/opt/kibana/config/kibana.yml

```yaml
#kibana绑定的IP地址
server.host: "172.18.13.112"

#访问URL
server.publicBaseUrl: "http://172.18.13.112:5601"

#添加一个elasticsearch节点的IP即可
elasticsearch.hosts: ["http://172.18.13.112:9200"]

#es超时设置Client request timeout
elasticsearch.requestTimeout: 3000000

#中文语言界面
#默认英文
#i18n.locale: "en"
i18n.locale: "zh-CN"

#log
logging.appenders.default:
  type: rolling-file
  fileName: /data/log/kibana.log
  policy:
    type: size-limit
    size: 256mb
  strategy:
    type: numeric
    max: 10
  layout:
    type: json
```



#### 4、启动与关闭

```bash
su - elasticsearch

#启动
#nohup /opt/kibana/bin/kibana &
nohup /opt/kibana/bin/kibana > /data/log/kibana.log 2>&1 &

#关闭
ps -ef | grep kibana|grep -v grep |awk '{print $2}'|xargs kill -9
```



#### 5、访问

```html
http://172.18.13.112:5601/
```





### 四、安装IK

#官网

```yaml
#github
https://github.com/infinilabs/analysis-ik/

#download network
https://release.infinilabs.com/
```



#### 1、下载及解压缩

#每台es节点都要安装

```bash
cd /opt/elasticsearch/plugins
mkdir ik

cd ik

wget https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.13.3.zip

unzip elasticsearch-analysis-ik-8.13.3.zip

vi plugin-descriptor.properties
#仅修改java版本
java.version=21.0.2
```



#### 2、重启es

#### 3、测试

#`_analyze` 语法验证两种analyzer

```bash
#ik_smart最粗粒度的拆分
GET /_analyze
{
  "text": "中华人民共和国国歌",
  "analyzer": "ik_smart"
}

#ik_max_word最细粒度的拆分
GET /_analyze
{
  "text": "中华人民共和国国歌",
  "analyzer": "ik_max_word"
}

```



#新建索引测试

##### 3.1.测试1

###### 3.1.1.create a index

```bash
curl -XPUT http://172.18.13.112:9200/index
```

###### 3.1.2.create a mapping

```bash
curl -XPOST http://172.18.13.112:9200/index/_mapping -H 'Content-Type:application/json' -d'
{
        "properties": {
            "content": {
                "type": "text",
                "analyzer": "ik_max_word",
                "search_analyzer": "ik_smart"
            }
        }

}'
```

###### 3.1.3.index some docs

```bash
curl -XPOST http://172.18.13.112:9200/index/_create/1 -H 'Content-Type:application/json' -d'
{"content":"美国留给伊拉克的是个烂摊子吗"}
'
```

```bash
curl -XPOST http://172.18.13.112:9200/index/_create/2 -H 'Content-Type:application/json' -d'
{"content":"公安部：各地校车将享最高路权"}
'
```

```bash
curl -XPOST http://172.18.13.112:9200/index/_create/3 -H 'Content-Type:application/json' -d'
{"content":"中韩渔警冲突调查：韩警平均每天扣1艘中国渔船"}
'
```

```bash
curl -XPOST http://172.18.13.112:9200/index/_create/4 -H 'Content-Type:application/json' -d'
{"content":"中国驻洛杉矶领事馆遭亚裔男子枪击 嫌犯已自首"}
'
```

###### 3.1.4.query with highlighting

```bash
curl -XPOST http://172.18.13.112:9200/index/_search  -H 'Content-Type:application/json' -d'
{
    "query" : { "match" : { "content" : "中国" }},
    "highlight" : {
        "pre_tags" : ["<tag1>", "<tag2>"],
        "post_tags" : ["</tag1>", "</tag2>"],
        "fields" : {
            "content" : {}
        }
    }
}
'
```

Result

```json
{
    "took": 14,
    "timed_out": false,
    "_shards": {
        "total": 1,
        "successful": 1,
        "failed": 0
    },
    "hits": {
        "total": 2,
        "max_score": 2,
        "hits": [
            {
                "_index": "index",
                "_id": "4",
                "_score": 2,
                "_source": {
                    "content": "中国驻洛杉矶领事馆遭亚裔男子枪击 嫌犯已自首"
                },
                "highlight": {
                    "content": [
                        "<tag1>中国</tag1>驻洛杉矶领事馆遭亚裔男子枪击 嫌犯已自首 "
                    ]
                }
            },
            {
                "_index": "index",
                "_id": "3",
                "_score": 2,
                "_source": {
                    "content": "中韩渔警冲突调查：韩警平均每天扣1艘中国渔船"
                },
                "highlight": {
                    "content": [
                        "均每天扣1艘<tag1>中国</tag1>渔船 "
                    ]
                }
            }
        ]
    }
}
```



```json
GET /index/_search
{
  "query": {
    "match": {
      "content": "中国"
    }
  }
}
```



```json
{
  "took": 6,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 2,
      "relation": "eq"
    },
    "max_score": 0.642793,
    "hits": [
      {
        "_index": "index",
        "_id": "3",
        "_score": 0.642793,
        "_source": {
          "content": "中韩渔警冲突调查：韩警平均每天扣1艘中国渔船"
        }
      },
      {
        "_index": "index",
        "_id": "4",
        "_score": 0.642793,
        "_source": {
          "content": "中国驻洛杉矶领事馆遭亚裔男子枪击 嫌犯已自首"
        }
      }
    ]
  }
}
```



##### 3.2.测试2

###### 3.2.1.插入实验数据

```JSON
PUT /my_index
{
  "mappings": {
      "properties": {
        "text": {
          "type": "text",
          "analyzer": "ik_max_word"
        }
      }
  }
}

```



```JSON
POST /my_index/_bulk
{ "index": { "_id": "1"} }
{ "text": "男子偷上万元发红包求交女友 被抓获时仍然单身" }
{ "index": { "_id": "2"} }
{ "text": "16岁少女为结婚“变”22岁 7年后想离婚被法院拒绝" }
{ "index": { "_id": "3"} }
{ "text": "深圳女孩骑车逆行撞奔驰 遭索赔被吓哭(图)" }
{ "index": { "_id": "4"} }
{ "text": "女人对护肤品比对男票好？网友神怼" }
{ "index": { "_id": "5"} }
{ "text": "为什么国内的街道招牌用的都是红黄配？" }

```



###### 3.2.2.查询

```json
GET /my_index/_search
{
  "query": {
    "match": {
      "text": "16岁少女结婚好还是单身好？"
    }
  }
}

```



#响应结果

```json
{
  "took": 12,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 3,
      "relation": "eq"
    },
    "max_score": 5.587998,
    "hits": [
      {
        "_index": "my_index",
        "_id": "2",
        "_score": 5.587998,
        "_source": {
          "text": "16岁少女为结婚“变”22岁 7年后想离婚被法院拒绝"
        }
      },
      {
        "_index": "my_index",
        "_id": "4",
        "_score": 2.9288726,
        "_source": {
          "text": "女人对护肤品比对男票好？网友神怼"
        }
      },
      {
        "_index": "my_index",
        "_id": "1",
        "_score": 1.2661822,
        "_source": {
          "text": "男子偷上万元发红包求交女友 被抓获时仍然单身"
        }
      }
    ]
  }
}
```



###### 3.2.3._validate和explain

```json
GET /my_index/_validate/query?explain
{
  "query": {
    "match": {
      "text": "16岁少女结婚好还是单身好？"
    }
  }
}
```



#返回

```json
{
  "_shards": {
    "total": 1,
    "successful": 1,
    "failed": 0
  },
  "valid": true,
  "explanations": [
    {
      "index": "my_index",
      "valid": true,
      "explanation": "text:16 text:岁 text:少女 text:结婚 text:好 text:还是 text:单身 text:好"
    }
  ]
}
```



### 五、es快照备份与还原

#### 1、搭建nfs服务器----es节点之外的节点

#IP 192.168.1.227

```bash
yum install -y nfs*

mkdir /es

chmod -R 777 /es

cat >> /etc/exports <<EOF
/es 172.18.13.0/24(rw,sync,insecure,no_subtree_check,no_root_squash)

EOF


systemctl restart nfs

systemctl enable nfs

showmount -e
```



#all_squash 表示客户机写入nfs的数据全部映射为nobody用户 这里设置 all_squash并把目录设置为777 是为防止elasticsearch 集群的每个节点启动的uid和gid 不一致导致在创建快照仓库时无法创建成功

#在这里说明下，并不是要求elasticsearch集群中中每个节点启动的用户id和group id 必须是一致的 只要写入的文件是同一个用户即可，所以这里设置all_squash

#### 2、每台es节点创建备份目录，并mount共享目录

```bash
su - root

mkdir /snp
chmod -R 777 /snp

yum install -y nfs-utils

mount -t nfs 192.168.1.227:/es /snp

cat >> /etc/fstab <<EOF
192.168.1.227:/es      /snp      nfs  defaults,_netdev  0 0
EOF

```



#### 3、修改es节点的elasticsearch.yml

```bash
su - elasticsearch

cat >> /opt/elasticsearch/config/elasticsearch.yml <<EOF
path.repo: ["/snp"]
EOF
```



#### 4、注册存储库

##### 4.1、通过kibana注册存储库

```yaml
Management ---> Stack Management ---> Snapshot and Restore
```



##### 4.2、通过命令注册存储库

```bash
#
PUT /_snapshot/my_backup
{
  "type": "fs",
  "settings": {
    "location": "/data/es_snapshot"
  }
}

#或者

curl -XPUT 172.18.13.112:9200/_snapshot/my_backup -d 
'{
  "type": "fs",
  "settings": {
    "location": "/data/es_snapshot"
  }
}'


#查看存储库
#GET /_snapshot/my_backup

curl -XGET 172.18.13.112:9200/_snapshot/my_backup

/*
{
  "es-nfs": {
    "type": "fs",
    "settings": {
      "location": "/snp"
    }
  }
}
*/



curl -XGET http://172.18.13.112:9200/_cat/snapshots?v

#
id                                           repository  status start_epoch start_time end_epoch  end_time duration indices successful_shards failed_shards total_shards
daily-snap-2024.05.11-pfsf0g5er7ophfuigczrqw es-nfs     SUCCESS 1715411551  07:12:31   1715411552 07:12:32       1s      34                34             0           34


curl -XGET http://172.18.13.120:9200/_snapshot/es-nfs/daily-snap-2024.05.11-pfsf0g5er7ophfuigczrqw/_status

```



#### 5、快照

##### 5.1、通过kibana打快照

```
Management ---> Stack Management ---> Snapshot and Restore ---> 策略

---> 所有数据流和索引
---> 单个索引等
```



##### 5.2、通过命令打快照

```bash
# 创建快照
PUT /_snapshot/es-nfs/daily-snap-2024.05.11-16-43?wait_for_completion=true 
{
  "indices": "kibana_sample_data_ecommerce,kibana_sample_data_flights",
  "ignore_unavailable": true,
  "include_global_state": false,
  "metadata": {
    "taken_by": "supwisdom",
    "taken_because": "backup before upgrading"
  }
}
# 查看快照
GET /_snapshot/es-nfs/daily-snap-2024.05.11-16-43

```





#### 6、还原

##### 6.1、通过kibana还原快照

```
Management ---> Stack Management ---> Snapshot and Restore ---> Snapshot

---> 所有数据流和索引
---> 单个索引等
```



##### 6.2、通过命令恢复快照

```bash
POST /_snapshot/es-nfs/daily-snap-2024.05.11-pfsf0g5er7ophfuigczrqw/_restore
{
  "indices": "kibana_sample_data_ecommerce,kibana_sample_data_flights",
  "ignore_unavailable": true,
  "include_global_state": true,
  "rename_pattern": "index_(.+)",
  "rename_replacement": "restored_index_$1"
}

```





### 六、错误处理

#### 1、es初始化启动报错

```
[2024-05-08T17:25:49,722][ERROR][o.e.b.Elasticsearch      ] [node-1] node validation exception
[1] bootstrap checks failed. You must address the points described in the following [1] lines before starting Elasticsearch. For more inform
ation see [https://www.elastic.co/guide/en/elasticsearch/reference/8.13/bootstrap-checks.html]
bootstrap check failure [1] of [1]: Transport SSL must be enabled if security is enabled. Please set [xpack.security.transport.ssl.enabled] 
to [true] or disable security by setting [xpack.security.enabled] to [false];
```



#因为In Elasticsearch 8.0 and later, security is enabled automatically when you start Elasticsearch for the first time.

#解决办法：

#elasticsearch.yaml添加参数

```yaml
xpack.security.enabled: false
```



#或者是配置相关安全选项



#### 2、不能使用root用户启动es

#报错内容

```bash
[root@k8s-mysql-ole-117 ~]# elasticsearch -d
warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK
May 09, 2024 3:42:41 PM sun.util.locale.provider.LocaleProviderAdapter <clinit>
WARNING: COMPAT locale provider will be removed in a future release
[2024-05-09T15:42:42,113][INFO ][o.e.n.NativeAccess       ] [node-2] Using [jdk] native provider and native methods for [Linux]
[2024-05-09T15:42:42,154][ERROR][o.e.b.Elasticsearch      ] [node-2] fatal exception while booting Elasticsearchjava.lang.RuntimeException: can not run elasticsearch as root
        at org.elasticsearch.server@8.13.3/org.elasticsearch.bootstrap.Elasticsearch.initializeNatives(Elasticsearch.java:283)
        at org.elasticsearch.server@8.13.3/org.elasticsearch.bootstrap.Elasticsearch.initPhase2(Elasticsearch.java:168)
        at org.elasticsearch.server@8.13.3/org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:73)

See logs for more details.

ERROR: Elasticsearch did not exit normally - check the logs at /data/log/supwisdom.log

ERROR: Elasticsearch died while starting up, with exit code 1
```



#### 3、es集群第一边初始化成功后，需要修改配置文件

#/opt/elasticsearch/config/elasticsearch.yml

#注释掉cluster.initial_master_nodes一行

```yaml
#cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
```





#否则报错

```log
[2024-05-09T15:43:00,388][WARN ][o.e.c.c.ClusterBootstrapService] [node-1] this node is locked into cluster UUID [cpLLf87gS2uEEAVlPEFYaA] but [cluster.initial_master_nodes] is set to [node-1, node-2, node-3]; remove this setting to avoid possible data loss caused by subsequent cluster bootstrap attempts; for further information see https://www.elastic.co/guide/en/elasticsearch/reference/8.13/important-settings.html#initial_master_nodes
[2024-05-09T15:43:10,404][WARN ][o.e.c.c.ClusterFormationFailureHelper] [node-1] master not discovered or elected yet, an election requires at least 2 nodes with ids from [178aaQJ1RTut1WclHoKkOw, tAGwLBqPR6KS0E-tzhRFgw, 4mfikY7-RpyVPJ2EQ6RKJw], have only discovered non-quorum [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{172.18.13.112}{172.18.13.112:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}]; discovery will continue using [172.18.13.117:9300, 172.18.13.120:9300] from hosts providers and [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{172.18.13.112}{172.18.13.112:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}] from last-known cluster state; node term 2, last-accepted version 148 in term 2; for troubleshooting guidance, see https://www.elastic.co/guide/en/elasticsearch/reference/8.13/discovery-troubleshooting.html
[2024-05-09T15:43:20,409][WARN ][o.e.c.c.ClusterFormationFailureHelper] [node-1] master not discovered or elected yet, an election requires at least 2 nodes with ids from [178aaQJ1RTut1WclHoKkOw, tAGwLBqPR6KS0E-tzhRFgw, 4mfikY7-RpyVPJ2EQ6RKJw], have only discovered non-quorum [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{172.18.13.112}{172.18.13.112:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}]; discovery will continue using [172.18.13.117:9300, 172.18.13.120:9300] from hosts providers and [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{172.18.13.112}{172.18.13.112:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}] from last-known cluster state; node term 2, last-accepted version 148 in term 2; for troubleshooting guidance, see https://www.elastic.co/guide/en/elasticsearch/reference/8.13/discovery-troubleshooting.html
[2024-05-09T15:43:23,349][INFO ][o.e.c.s.ClusterApplierService] [node-1] master node changed {previous [], current [{node-2}{4mfikY7-RpyVPJ2EQ6RKJw}{sQaBo1vGTUK-8B-9xWBYIQ}{node-2}{172.18.13.117}{172.18.13.117:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}]}, added {{node-2}{4mfikY7-RpyVPJ2EQ6RKJw}{sQaBo1vGTUK-8B-9xWBYIQ}{node-2}{172.18.13.117}{172.18.13.117:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}}, term: 3, version: 185, reason: ApplyCommitRequest{term=3, version=185, sourceNode={node-2}{4mfikY7-RpyVPJ2EQ6RKJw}{sQaBo1vGTUK-8B-9xWBYIQ}{node-2}{172.18.13.117}{172.18.13.117:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}{ml.allocated_processors=16, ml.machine_memory=33371656192, transform.config_version=10.0.0, xpack.installed=true, ml.config_version=12.0.0, ml.max_jvm_size=16684941312, ml.allocated_processors_double=16.0}}
[2024-05-09T15:43:23,376][INFO ][o.e.h.AbstractHttpServerTransport] [node-1] publish_address {172.18.13.112:9200}, bound_addresses {172.18.13.112:9200}
[2024-05-09T15:43:23,395][INFO ][o.e.n.Node               ] [node-1] started {node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{172.18.13.112}{172.18.13.112:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}{ml.allocated_processors=16, ml.machine_memory=33371656192, transform.config_version=10.0.0, xpack.installed=true, ml.config_version=12.0.0, ml.max_jvm_size=16684941312, ml.allocated_processors_double=16.0}
[elasticsearch@k8s-mysql-ole config]$ 
```







### 七、es与kibana的自启动

#创建ES系统服务（root用户执行）：

```bash
su - root

cat >> /usr/lib/systemd/system/elasticsearch.service <<EOF
[Unit]
Description=elasticsearch
After=network.target
Wants=network.target

[Service]
User=elasticsearch
Group=elasticsearch
LimitNOFILE=165536
LimitNPROC=165536
LimitMEMLOCK=infinity
ExecStart=/opt/elasticsearch/bin/elasticsearch

[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload
systemctl enable elasticsearch --now

ps -ef | grep elasticsearch|grep -vE "grep|controller" |awk '{print $2}'|xargs kill -9

systemctl start elasticsearch

systemctl status elasticsearch
```



#创建kibana系统服务：

#【es1上操作（root用户执行）】

```bash
su - root

cat >> /usr/lib/systemd/system/kibana.service <<EOF
[Unit]
Description=kibana
After=network.target
Wants=elasticsearch

[Service]
User=elasticsearch
Group=elasticsearch
ExecStart=/opt/kibana/bin/kibana

[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload
systemctl enable kibana --now

ps -ef | grep kibana|grep -v grep |awk '{print $2}'|xargs kill -9

systemctl start kibana

systemctl status kibana
```





### 八、 es的压测







### 九、es的监控

