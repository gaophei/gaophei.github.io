此文档提供安装elasticsearch7.7.1(最新版8.19/9.1.0)三节点集群模式的安装

****

#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小，es安装到最大分区里
#20240715安装版本为7.7.1

## 服务器资源

#建议

```
vm: 16核/32G 

OS: Kylin Linux Advanced Server V10 (SP2 / Sword)(4.19.90-25.48.v2101.ky10.x86_64)

磁盘LVM管理，挂载第二块磁盘500G，/data为最大分区

/opt/elasticsearch为程序目录
/data/data为数据目录
/data/log为日志目录
```



#最少三台

| 序号 |    IP地址     | 主机名 |    角色     | 备注 |
| :--: | :-----------: | :----: | :---------: | :--: |
|  1   | 222.24.203.42 |  es01  | master,data |      |
|  2   | 222.24.203.43 |  es02  | master,data |      |
|  3   | 222.24.203.44 |  es03  | master,data |      |
|  4   |               |        |   ingest    |      |
|  5   |               |        |   ingest    |      |



#官网

```addr
#elk
https://www.elastic.co/

#es download
https://www.elastic.co/downloads/elasticsearch
https://www.elastic.co/downloads/past-releases#elasticsearch

#kibana download
https://www.elastic.co/downloads/kibana
https://www.elastic.co/downloads/past-releases#kibana

#es deployment docs
https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-from-archive-on-linux-macos

https://www.elastic.co/guide/en/elasticsearch/reference/8.19/targz.html

https://www.elastic.co/guide/en/elasticsearch/reference/7.7/targz.html
```





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
#Kylin v10 SP2
cat >> /etc/yum.repos.d/kylin_x86_64.repo <<EOF
###Kylin Linux Advanced Server 10 - os repo###

[ks10-adv-os]
name = Kylin Linux Advanced Server 10 - Os
baseurl = http://update.cs2c.com.cn:8080/NS/V10/V10SP2/os/adv/lic/base/$basearch/
gpgcheck = 1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-kylin
enabled = 1

[ks10-adv-updates]
name = Kylin Linux Advanced Server 10 - Updates
baseurl = http://update.cs2c.com.cn:8080/NS/V10/V10SP2/os/adv/lic/updates/$basearch/
gpgcheck = 1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-kylin
enabled = 1

[ks10-adv-addons]
name = Kylin Linux Advanced Server 10 - Addons
baseurl = http://update.cs2c.com.cn:8080/NS/V10/V10SP2/os/adv/lic/addons/$basearch/
gpgcheck = 1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-kylin
enabled = 0

[centos-extras]
name=centos-extras Stable
baseurl=https://mirrors.aliyun.com/centos/7/extras/$basearch
enabled=1
gpgcheck=0
EOF


yum clean all && yum makecache all


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
222.24.203.42 es01
222.24.203.43 es02
222.24.203.44 es03
EOF

#es01
hostnamectl set-hostname es01
#es02
hostnamectl set-hostname es02
#es03
hostnamectl set-hostname es03

hostnamectl status

ping es01  -c 3
ping es02  -c 3
ping es03  -c 3

```

```
[root@localhost ~]# hostnamectl set-hostname es01
[root@localhost ~]# exit

[root@es01 ~]# hostnamectl status
   Static hostname: es01
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 96673b7b63a1448eab69bc486cb9f432
           Boot ID: eb508de5a690492da65a07ba229c639a
    Virtualization: kvm
  Operating System: Kylin Linux Advanced Server V10 (Sword)
            Kernel: Linux 4.19.90-25.48.v2101.ky10.x86_64
      Architecture: x86-64
[root@es01 ~]#

[root@es02 ~]# hostnamectl status
   Static hostname: es02
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 96673b7b63a1448eab69bc486cb9f432
           Boot ID: 12ce614b79414f0388094ccefbd0a36f
    Virtualization: kvm
  Operating System: Kylin Linux Advanced Server V10 (Sword)
            Kernel: Linux 4.19.90-25.48.v2101.ky10.x86_64
      Architecture: x86-64
[root@es02 ~]#

[root@es03 ~]# hostnamectl status
   Static hostname: es03
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 96673b7b63a1448eab69bc486cb9f432
           Boot ID: 69ab9179f1ff46d6ae2e939ade889b6a
    Virtualization: kvm
  Operating System: Kylin Linux Advanced Server V10 (Sword)
            Kernel: Linux 4.19.90-25.48.v2101.ky10.x86_64
      Architecture: x86-64
[root@es03 ~]#



[root@es01 ~]# cat >> /etc/hosts <<EOF
222.24.203.42 es01
222.24.203.43 es02
222.24.203.44 es03
EOF

[root@es01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
222.24.203.42 es01
222.24.203.43 es02
222.24.203.44 es03

[root@es01 ~]# ping es01 -c 1
PING es01 (222.24.203.42) 56(84) bytes of data.
64 bytes from es01 (222.24.203.42): icmp_seq=1 ttl=64 time=0.065 ms

--- es01 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.065/0.065/0.065/0.000 ms

[root@es01 ~]# ping es02 -c 1
PING es02 (222.24.203.43) 56(84) bytes of data.
64 bytes from es02 (222.24.203.43): icmp_seq=1 ttl=64 time=0.619 ms

--- es02 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.619/0.619/0.619/0.000 ms

[root@es01 ~]# ping es03 -c 1
PING es03 (222.24.203.44) 56(84) bytes of data.
64 bytes from es02 (222.24.203.44): icmp_seq=1 ttl=64 time=0.619 ms

--- es02 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.619/0.619/0.619/0.000 ms

```



#### 2、关闭防火墙和selinux

```bash
#centos关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

systemctl status firewalld

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
useradd elasticsearch && echo Mysql\@20220317 |passwd --stdin elasticsearch
```

#添加到sudo组中

```bash
visudo

#添加一行
elasticsearch ALL=(ALL) NOPASSWD:ALL
```



#logs

```bash
[root@es02 ~]# useradd elasticsearch && echo Mysql\@20220317 |passwd --stdin elasticsearch
Changing password for user elasticsearch.
passwd: all authentication tokens updated successfully.
```



#### 5、开始时间同步及修改东8区

```bash
#安装
#Kylin v10 SP2
[root@es01 ~]# crontab -l
0 */1 * * * /usr/sbin/ntpdate 222.24.211.121

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
#kylin

echo "
net.ipv4.tcp_retries2=5
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
#vm.max_map_count=262144
vm.max_map_count=655360
#fs.may_detach_mounts=1
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

#kernel.yama.ptrace_scope=0
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




#centos7
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
[root@es01 ~]# sysctl net.ipv4.tcp_retries2
net.ipv4.tcp_retries2 = 5

[root@es01 ~]# sysctl vm.max_map_count
vm.max_map_count = 65530

[root@es01 ~]# sysctl vm.swappiness
vm.swappiness = 0
```





##### 2）open-files

```bash
#kylin
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



### 二、安装es---centos7.7

#### 1、规划

#建议

```
vm: 16核/32G 

OS: OS: Kylin Linux Advanced Server V10 (SP2 / Sword)(4.19.90-25.48.v2101.ky10.x86_64)

磁盘LVM管理，挂载第二块磁盘500G，/为最大分区

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

| 序号 |    IP地址     | 主机名 |    角色     | 备注 |
| :--: | :-----------: | :----: | :---------: | :--: |
|  1   | 222.24.203.42 |  es01  | master,data |      |
|  2   | 222.24.203.43 |  es02  | master,data |      |
|  3   | 222.24.203.44 |  es03  | master,data |      |
|  4   |               |        |   ingest    |      |
|  5   |               |        |   ingest    |      |





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

#7.7.1
su - elasticsearch

cd /opt/soft

wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.7.1-linux-x86_64.tar.gz

tar -zxvf elasticsearch-7.7.1-linux-x86_64.tar.gz -C /opt/elasticsearch --strip-components=1
```

#### 3、配置环境变量

#卸载系统自带的openjdk

```bash
rpm -qa|grep java
yum remove java*

rpm -qa|grep java
```

#logs

```bash
[root@es02 ~]# rpm -qa|grep java
javapackages-filesystem-5.3.0-2.ky10.noarch
tzdata-java-2020a-8.p03.ky10.noarch
java-1.8.0-openjdk-1.8.0.452.b09-1.p01.ky10.x86_64
java-11-openjdk-11.0.27.6-1.p01.ky10.x86_64
java-1.8.0-openjdk-headless-1.8.0.452.b09-1.p01.ky10.x86_64
javapackages-tools-5.3.0-2.ky10.noarch
java-11-openjdk-headless-11.0.27.6-1.p01.ky10.x86_64
[root@es02 ~]# yum remove java*

[root@es02 ~]# rpm -qa|grep java

```



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


[root@es02 ~]# which java
/opt/elasticsearch/jdk/bin/java
[root@es02 ~]# java -version
openjdk version "14.0.1" 2020-04-14
OpenJDK Runtime Environment AdoptOpenJDK (build 14.0.1+7)
OpenJDK 64-Bit Server VM AdoptOpenJDK (build 14.0.1+7, mixed mode, sharing)
[root@es02 ~]#
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
cluster.name: nwpu-newes
#根据每台节点进行修改
node.name: node-1
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
#根据每台节点进行修改
#network.host: 0.0.0.0
#network.host: "_en0:ipv4_"
#network.host: "_en0:ipv6_"
network.host: 222.24.203.42
http.port: 9200
discovery.seed_hosts: ["es01", "es02", "es03"]
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
#thread_pool.search.queue_size: 8000
```



#shard

```
The cluster shard limit defaults to 1000 shards per non-frozen data node for normal (non-frozen) indices and 3000 shards per frozen data node for frozen indices. Both primary and replica shards of all open indices count toward the limit, including unassigned shards. For example, an open index with 5 primary shards and 2 replicas counts as 15 shards. Closed indices do not contribute to the shard count.
```



#JVM参数

----------------------

#13.3版本需要单独建文件

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



--------------------------

#7.7.1

#直接修改jvm.options

```bash
[elasticsearch@es01 config]$ cat jvm.options|grep -v ^#|grep -v ^$
-Xms15g
-Xmx15g
8-13:-XX:+UseConcMarkSweepGC
8-13:-XX:CMSInitiatingOccupancyFraction=75
8-13:-XX:+UseCMSInitiatingOccupancyOnly
14-:-XX:+UseG1GC
14-:-XX:G1ReservePercent=25
14-:-XX:InitiatingHeapOccupancyPercent=30
-Djava.io.tmpdir=${ES_TMPDIR}
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/data/data/
-XX:ErrorFile=logs/hs_err_pid%p.log
8:-XX:+PrintGCDetails
8:-XX:+PrintGCDateStamps
8:-XX:+PrintTenuringDistribution
8:-XX:+PrintGCApplicationStoppedTime
8:-Xloggc:logs/gc.log
8:-XX:+UseGCLogFileRotation
8:-XX:NumberOfGCLogFiles=32
8:-XX:GCLogFileSize=64m
9-:-Xlog:gc*,gc+age=trace,safepoint:file=logs/gc.log:utctime,pid,tags:filecount=32,filesize=64m
```





##### 1) es01

#elasticsearch.yml

```yaml
cluster.name: nwpu-newes
node.name: node-1
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 222.24.203.42
http.port: 9200
discovery.seed_hosts: ["es01", "es02", "es03"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
http.max_content_length: 2000mb
script.max_size_in_bytes: 10000000
script.max_compilations_rate: 60000/1m
indices.memory.index_buffer_size: 15%
indices.memory.min_index_buffer_size: 96mb
thread_pool.get.queue_size: 5000
thread_pool.write.queue_size: 20000
```

#最终配置文件

#初始化后，需注释掉`cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]`

```yaml
[root@es01 config]# cat elasticsearch.yml |grep -v ^#|grep -v ^$
cluster.name: nwpu-newes
node.name: node-1
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 222.24.203.42
http.port: 9200
discovery.seed_hosts: ["es01", "es02", "es03"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
http.max_content_length: 2000mb
script.max_size_in_bytes: 10000000
script.max_compilations_rate: 60000/1m
indices.memory.index_buffer_size: 15%
indices.memory.min_index_buffer_size: 96mb
thread_pool.get.queue_size: 5000
thread_pool.write.queue_size: 20000
path.repo: ["/snp"]
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.client_authentication: required
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12
xpack.security.http.ssl:
  enabled: true
  keystore.path: http.p12
```



##### 2) es02

#elasticsearch.yml
```yaml
cluster.name: nwpu-newes
node.name: node-2
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 222.24.203.43
http.port: 9200
discovery.seed_hosts: ["es01", "es02", "es03"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
http.max_content_length: 2000mb
script.max_size_in_bytes: 10000000
script.max_compilations_rate: 60000/1m
indices.memory.index_buffer_size: 15%
indices.memory.min_index_buffer_size: 96mb
thread_pool.get.queue_size: 5000
thread_pool.write.queue_size: 20000
```

#最终配置文件

#初始化后，需注释掉`cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]`

```yaml
[root@es02 config]# cat elasticsearch.yml |grep -v ^#|grep -v ^$
cluster.name: nwpu-newes
node.name: node-2
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 222.24.203.43
http.port: 9200
discovery.seed_hosts: ["es01", "es02", "es03"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
http.max_content_length: 2000mb
script.max_size_in_bytes: 10000000
script.max_compilations_rate: 60000/1m
indices.memory.index_buffer_size: 15%
indices.memory.min_index_buffer_size: 96mb
thread_pool.get.queue_size: 5000
thread_pool.write.queue_size: 20000
path.repo: ["/snp"]
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.client_authentication: required
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12
xpack.security.http.ssl:
  enabled: true
  keystore.path: http.p12
```



##### 3) es03

#elasticsearch.yml
```yaml
cluster.name: nwpu-newes
node.name: node-3
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 222.24.203.44
http.port: 9200
discovery.seed_hosts: ["es01", "es02", "es03"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
http.max_content_length: 2000mb
script.max_size_in_bytes: 10000000
script.max_compilations_rate: 60000/1m
indices.memory.index_buffer_size: 15%
indices.memory.min_index_buffer_size: 96mb
thread_pool.get.queue_size: 5000
thread_pool.write.queue_size: 20000
```

#最终配置文件

#初始化后，需注释掉`cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]`

```yaml
[root@es03 config]# cat elasticsearch.yml |grep -v ^#|grep -v ^$
cluster.name: nwpu-newes
node.name: node-3
path.data: /data/data
path.logs: /data/log
bootstrap.memory_lock: true
network.host: 222.24.203.44
http.port: 9200
discovery.seed_hosts: ["es01", "es02", "es03"]
action.destructive_requires_name: true
thread_pool.search.queue_size: 8000
http.max_content_length: 2000mb
script.max_size_in_bytes: 10000000
script.max_compilations_rate: 60000/1m
indices.memory.index_buffer_size: 15%
indices.memory.min_index_buffer_size: 96mb
thread_pool.get.queue_size: 5000
thread_pool.write.queue_size: 20000
path.repo: ["/snp"]
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.client_authentication: required
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12
xpack.security.http.ssl:
  enabled: true
  keystore.path: http.p12
```



#### 5、启动与关闭elasticsearch

```bash
#启动
su - elasticsearch
elasticsearch -d

#关闭
ps -ef | grep elasticsearch|grep -vE "grep|controller" |awk '{print $2}'|xargs kill -9

#开机自启
su - root
systemctl start elasticsearch
systemctl status elasticsearch
```



#如果修改es的配置，需要重启节点的es

```bash
#重启前
#curl -H "Content-Type: application/json" -XPUT 222.24.203.42:9200/_cluster/settings -d '{"transient":{"cluster.routing.allocation.disable_allocation":true}}'


#重启后
#curl -H "Content-Type: application/json" -XPUT localhost:9200/_cluster/settings -d '{"transient":{"cluster.routing.allocation.disable_allocation":false}}'
```



#### 6、访问

```bash
http://222.24.203.42:9200/_nodes/stats

http://222.24.203.43:9200/_nodes/stats

http://222.24.203.44:9200/_nodes/stats
```

#### 7、安全配置，开启xpack并配置

#官网地址https://www.elastic.co/guide/en/elasticsearch/reference/7.7/ssl-tls.html

##### 7.1、创建 SSL Elastic 证书---10年证书

#默认生成证书位置在/opt/elasticsearch中

```bash
[elasticsearch@es01 ~]$ elasticsearch-certutil --help

[elasticsearch@es01 ~]$ elasticsearch-certutil ca --help

[elasticsearch@es01 ~]$ elasticsearch-certutil ca --day 3650
warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK
This tool assists you in the generation of X.509 certificates and certificate
signing requests for use with SSL/TLS in the Elastic stack.

The 'ca' mode generates a new 'certificate authority'
This will create a new X.509 certificate and private key that can be used
to sign certificate when running in 'cert' mode.

Use the 'ca-dn' option if you wish to configure the 'distinguished name'
of the certificate authority

By default the 'ca' mode produces a single PKCS#12 output file which holds:
    * The CA certificate
    * The CA's private key

If you elect to generate PEM format certificates (the -pem option), then the output will
be a zip file containing individual files for the CA certificate and private key

Please enter the desired output file [elastic-stack-ca.p12]: 
Enter password for elastic-stack-ca.p12 : 

[elasticsearch@es01 ~]$ cd /opt/elasticsearch/
[elasticsearch@es01 elasticsearch]$ ls
bin  config  elastic-stack-ca.p12  jdk  lib  LICENSE.txt  logs  modules  NOTICE.txt  plugins  README.asciidoc


[elasticsearch@es01 elasticsearch]$ elasticsearch-certutil cert --ca elastic-stack-ca.p12 --days 3650

warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK
This tool assists you in the generation of X.509 certificates and certificate
signing requests for use with SSL/TLS in the Elastic stack.

The 'cert' mode generates X.509 certificate and private keys.
    * By default, this generates a single certificate and key for use
       on a single instance.
    * The '-multiple' option will prompt you to enter details for multiple
       instances and will generate a certificate and key for each one
    * The '-in' option allows for the certificate generation to be automated by describing
       the details of each instance in a YAML file

    * An instance is any piece of the Elastic Stack that requires an SSL certificate.
      Depending on your configuration, Elasticsearch, Logstash, Kibana, and Beats
      may all require a certificate and private key.
    * The minimum required value for each instance is a name. This can simply be the
      hostname, which will be used as the Common Name of the certificate. A full
      distinguished name may also be used.
    * A filename value may be required for each instance. This is necessary when the
      name would result in an invalid file or directory name. The name provided here
      is used as the directory name (within the zip) and the prefix for the key and
      certificate files. The filename is required if you are prompted and the name
      is not displayed in the prompt.
    * IP addresses and DNS names are optional. Multiple values can be specified as a
      comma separated string. If no IP addresses or DNS names are provided, you may
      disable hostname verification in your SSL configuration.


    * All certificates generated by this tool will be signed by a certificate authority (CA)
      unless the --self-signed command line option is specified.
      The tool can automatically generate a new CA for you, or you can provide your own with
      the --ca or --ca-cert command line options.


By default the 'cert' mode produces a single PKCS#12 output file which holds:
    * The instance certificate
    * The private key for the instance certificate
    * The CA certificate

If you specify any of the following options:
    * -pem (PEM formatted output)
    * -multiple (generate multiple certificates)
    * -in (generate certificates from an input file)
then the output will be be a zip file containing individual certificate/key files

Enter password for CA (elastic-stack-ca.p12) : 
Please enter the desired output file [elastic-certificates.p12]:
Enter password for elastic-certificates.p12 : 

Certificates written to /opt/elasticsearch/elastic-certificates.p12

This file should be properly secured as it contains the private key for 
your instance.
This file is a self contained file and can be copied and used 'as is'
For each Elastic product that you wish to configure, you should copy
this '.p12' file to the relevant configuration directory
and then follow the SSL configuration instructions in the product guide.

For client applications, you may only need to copy the CA certificate and
configure the client to trust this certificate.


[elasticsearch@es01 elasticsearch]$ ls
bin  config  elastic-certificates.p12  elastic-stack-ca.p12  jdk  lib  LICENSE.txt  ll -rth  logs  modules  NOTICE.txt  plugins  README.asciidoc

```

##### 7.2、将 SSL 证书复制到所有节点

```bash
 cd /opt/elasticsearch
 #本机
 cp elastic-certificates.p12 config/

 #其它机器
 scp elastic-certificates.p12 es02:/opt/elasticsearch/config/
 
 scp elastic-certificates.p12 es03:/opt/elasticsearch/config/
 
 #每台节点都确认下证书的时间
 ll -rth /opt/elasticsearch/config/
```



##### 7.3、更新 elasticsearch.yml

#elasticsearch.yml添加以下参数

```yml
#注释掉原来的xpack.security.enabled: false

xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.client_authentication: required
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12
```





##### 7.4、重启所有 Elasticsearch 节点

```bash
su - root
systemctl restart elasticsearch

systemctl status elasticsearch
```



##### 7.5、创建/重置内置用户密码

#自动/手动两种模式

#其中一台节点执行即可

```bash
[elasticsearch@es01 log]$ elasticsearch-setup-passwords auto
warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK
******************************************************************************
Note: The 'elasticsearch-setup-passwords' tool has been deprecated. This       command will be removed in a future release.
******************************************************************************

Initiating the setup of passwords for reserved users elastic,apm_system,kibana,kibana_system,logstash_system,beats_system,remote_monitoring_user.
The passwords will be randomly generated and printed to the console.
Please confirm that you would like to continue [y/N]y


Changed password for user apm_system
PASSWORD apm_system = 5Whmw8qyR0eWZTl5BG5L

Changed password for user kibana
PASSWORD kibana = YNNy1i1y03a4TRqlH32w

Changed password for user logstash_system
PASSWORD logstash_system = OfZ4emGDQj2tZjbuQbRl

Changed password for user beats_system
PASSWORD beats_system = kUlAdVNIgztrK78JdbzP

Changed password for user remote_monitoring_user
PASSWORD remote_monitoring_user = h1tZbCdYyucV8Cy25QCB

Changed password for user elastic
PASSWORD elastic = XIlreSzGM51dH44yuxo1
```



##### 7.6、验证账户密码及查看证书情况

#证书默认三年有效期

###### 7.6.1、网页访问

```
http://222.24.203.42:9200/_ssl/certificates
```

```yaml
// http://222.24.203.42:9200/_ssl/certificates

[
   {
      "alias": "instance",
      "expiry": "2035-08-04T03:34:58.000Z",
      "format": "PKCS12",
      "has_private_key": true,
      "path": "elastic-certificates.p12",
      "serial_number": "38c3a219bf66fed6f4420f1b6a826585d6ee75e8",
      "subject_dn": "CN=instance"
   },
   {
      "alias": "instance",
      "expiry": "2035-08-04T03:27:12.000Z",
      "format": "PKCS12",
      "has_private_key": false,
      "path": "elastic-certificates.p12",
      "serial_number": "43f433b5bb3258c4bcce2f45b31de8b28164808e",
      "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA"
   },
   {
      "alias": "ca",
      "expiry": "2035-08-04T03:27:12.000Z",
      "format": "PKCS12",
      "has_private_key": false,
      "path": "elastic-certificates.p12",
      "serial_number": "43f433b5bb3258c4bcce2f45b31de8b28164808e",
      "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA"
   }
]
```



###### 7.6.2、命令行访问

```bash
#curl -u elastic:XIlreSzGM51dH44yuxo1  http://222.24.203.42:9200/_ssl/certificates
#yum install -y jq

[root@es01-test home]# curl -s -u elastic:PLq3dAEaTXI4pnQ27hWL  http://222.24.203.42:9200/_ssl/certificates | jq '.'
[
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "instance",
    "subject_dn": "CN=instance",
    "serial_number": "38c3a219bf66fed6f4420f1b6a826585d6ee75e8",
    "has_private_key": true,
    "expiry": "2035-08-04T03:34:58.000Z"
  },
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "instance",
    "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA",
    "serial_number": "43f433b5bb3258c4bcce2f45b31de8b28164808e",
    "has_private_key": false,
    "expiry": "2035-08-04T03:27:12.000Z"
  },
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "ca",
    "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA",
    "serial_number": "43f433b5bb3258c4bcce2f45b31de8b28164808e",
    "has_private_key": false,
    "expiry": "2035-08-04T03:27:12.000Z"
  }
]
```



###### 7.6.3、kibana访问

#kibana.conf使用kibana账户(elasticsearch 8.x使用kibana_system账户)，kibana网页系统登录需要elastic用户

#修改kibana.conf

```bash
su - elasticsearch
vi /opt/kibana/config/kibana.yml

#添加
#7.x 
elasticsearch.username: "kibana"
#8.x
#elasticsearch.username: "kibana_system"
elasticsearch.password: "A4uzNbulbspWXUdR2Sdd"
```

#重启kibana

```bash
su - root
systemctl restart kibana
```



#使用elastic账户访问网页版的kibana，不能使用kibana或者kibana_system账户访问



##### 7.7、证书过期后，再次更换为10年证书

#先mv下以前生成的证书

```bash
su - elasticsearch
cd /opt/elasticsearch

[elasticsearch@es01 elasticsearch]$ ls
bin  config  elastic-certificates.p12  elastic-stack-ca.p12  jdk  lib  LICENSE.txt  ll -rth  logs  modules  NOTICE.txt  plugins  README.asciidoc
[elasticsearch@es01 elasticsearch]$ mv elastic-certificates.p12 elastic-certificates.p12.old
[elasticsearch@es01 elasticsearch]$ mv elastic-stack-ca.p12 elastic-stack-ca.p12.old
[elasticsearch@es01 elasticsearch]$ 
```

#生成新的证书

```bash
[elasticsearch@es01 elasticsearch]$ elasticsearch-certutil ca --day 3650
warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK
This tool assists you in the generation of X.509 certificates and certificate
signing requests for use with SSL/TLS in the Elastic stack.

The 'ca' mode generates a new 'certificate authority'
This will create a new X.509 certificate and private key that can be used
to sign certificate when running in 'cert' mode.

Use the 'ca-dn' option if you wish to configure the 'distinguished name'
of the certificate authority

By default the 'ca' mode produces a single PKCS#12 output file which holds:
    * The CA certificate
    * The CA's private key

If you elect to generate PEM format certificates (the -pem option), then the output will
be a zip file containing individual files for the CA certificate and private key

Please enter the desired output file [elastic-stack-ca.p12]: 
Enter password for elastic-stack-ca.p12 : 
[elasticsearch@es01 elasticsearch]$ ls
bin     elastic-certificates.p12.old  elastic-stack-ca.p12.old  lib          ll -rth  modules     plugins
config  elastic-stack-ca.p12          jdk                       LICENSE.txt  logs     NOTICE.txt  README.asciidoc
[elasticsearch@es01 elasticsearch]$ 


[elasticsearch@es01 elasticsearch]$ elasticsearch-certutil cert --ca elastic-stack-ca.p12 --days 3650
warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK
This tool assists you in the generation of X.509 certificates and certificate
signing requests for use with SSL/TLS in the Elastic stack.

The 'cert' mode generates X.509 certificate and private keys.
    * By default, this generates a single certificate and key for use
       on a single instance.
    * The '-multiple' option will prompt you to enter details for multiple
       instances and will generate a certificate and key for each one
    * The '-in' option allows for the certificate generation to be automated by describing
       the details of each instance in a YAML file

    * An instance is any piece of the Elastic Stack that requires an SSL certificate.
      Depending on your configuration, Elasticsearch, Logstash, Kibana, and Beats
      may all require a certificate and private key.
    * The minimum required value for each instance is a name. This can simply be the
      hostname, which will be used as the Common Name of the certificate. A full
      distinguished name may also be used.
    * A filename value may be required for each instance. This is necessary when the
      name would result in an invalid file or directory name. The name provided here
      is used as the directory name (within the zip) and the prefix for the key and
      certificate files. The filename is required if you are prompted and the name
      is not displayed in the prompt.
    * IP addresses and DNS names are optional. Multiple values can be specified as a
      comma separated string. If no IP addresses or DNS names are provided, you may
      disable hostname verification in your SSL configuration.


    * All certificates generated by this tool will be signed by a certificate authority (CA)
      unless the --self-signed command line option is specified.
      The tool can automatically generate a new CA for you, or you can provide your own with
      the --ca or --ca-cert command line options.


By default the 'cert' mode produces a single PKCS#12 output file which holds:
    * The instance certificate
    * The private key for the instance certificate
    * The CA certificate

If you specify any of the following options:
    * -pem (PEM formatted output)
    * -multiple (generate multiple certificates)
    * -in (generate certificates from an input file)
then the output will be be a zip file containing individual certificate/key files

Enter password for CA (elastic-stack-ca.p12) : 
Please enter the desired output file [elastic-certificates.p12]: 
Enter password for elastic-certificates.p12 : 

Certificates written to /opt/elasticsearch/elastic-certificates.p12

This file should be properly secured as it contains the private key for 
your instance.
This file is a self contained file and can be copied and used 'as is'
For each Elastic product that you wish to configure, you should copy
this '.p12' file to the relevant configuration directory
and then follow the SSL configuration instructions in the product guide.

For client applications, you may only need to copy the CA certificate and
configure the client to trust this certificate.
[elasticsearch@es01 elasticsearch]$ ls
bin     elastic-certificates.p12      elastic-stack-ca.p12      jdk  LICENSE.txt  logs     NOTICE.txt  README.asciidoc
config  elastic-certificates.p12.old  elastic-stack-ca.p12.old  lib  ll -rth      modules  plugins

```

#复制替换

```bash
cp elastic-certificates.p12 /opt/elasticsearch/config/

scp elastic-certificates.p12 es02:/opt/elasticsearch/config/
 
scp elastic-certificates.p12 es03:/opt/elasticsearch/config/
 
#每台节点都确认下证书的时间
ll -rth /opt/elasticsearch/config/
```

#不需要重启es，新证书立即生效

```bash
# curl -s -u elastic:PLq3dAEaTXI4pnQ27hWL  http://222.24.203.42:9200/_ssl/certificates | jq '.'
[
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "ca",
    "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA",
    "serial_number": "9c43f6920f4739032c758d3bb2a3c9ab848edb7c",
    "has_private_key": false,
    "expiry": "2034-07-17T04:41:42.000Z",
    "issuer": "CN=Elastic Certificate Tool Autogenerated CA"
  },
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "instance",
    "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA",
    "serial_number": "9c43f6920f4739032c758d3bb2a3c9ab848edb7c",
    "has_private_key": false,
    "expiry": "2034-07-17T04:41:42.000Z",
    "issuer": "CN=Elastic Certificate Tool Autogenerated CA"
  },
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "instance",
    "subject_dn": "CN=instance",
    "serial_number": "9f66544d2c4adf5125a3c351dca471273b026cee",
    "has_private_key": true,
    "expiry": "2034-07-17T04:42:38.000Z",
    "issuer": "CN=Elastic Certificate Tool Autogenerated CA"
  }
]

```

##### 7.8、开启http ssl

#可以直接elastic-certificates.p12证书，但是这样kibana无法连接es

#所以要生成http证书
###### 7.8.1、生成https支持所需文件
```bash
#elasticsearch-certutil http

Generate a CSR? [y/N]n：是否生成 CSR，输入 n
Use an existing CA? [y/N]y：用已经存在的根证书，输入 y
CA Path: /opt/elasticsearch/elastic-stack-ca.p12：输入根证书的绝对路径
Password for elastic-stack-ca.p12：输入根证书的密码
For how long should your certificate be valid? [5y] ：证书有效期，默认为 5y（5年）
Generate a certificate per node? [y/N]：是否为每一个节点都生成证书
Enter all the hostnames that you need, one per line.：输入集群中节点的主机名，回车两次跳过即可
Enter all the IP addresses that you need, one per line.：输入集群中节点的IP地址，回车两次跳过即可
Do you wish to change any of these options? [y/N]n：是否要改变选项，输入 n
Provide a password for the “http.p12” file: [ for none]：输入私钥 http.p12 的密码，回车不设置密码
What filename should be used for the output zip file? ：输出的压缩文件的文件名
```

#logs

```bash
[elasticsearch@es01 ~]$ cd /opt/elasticsearch/
[elasticsearch@es01 elasticsearch]$ ls
bin     elastic-certificates.p12      elastic-stack-ca.p12      jdk  LICENSE.txt  logs     NOTICE.txt  README.asciidoc
config  elastic-certificates.p12.old  elastic-stack-ca.p12.old  lib  ll -rth      modules  plugins


[elasticsearch@es01 elasticsearch]$ elasticsearch-certutil --help
warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK
Simplifies certificate creation for use with the Elastic Stack

Commands
--------
csr - generate certificate signing requests
cert - generate X.509 certificates and keys
ca - generate a new local certificate authority
http - generate a new certificate (or certificate request) for the Elasticsearch HTTP interface

Non-option arguments:
command              

Option             Description        
------             -----------        
-E <KeyValuePair>  Configure a setting
-h, --help         Show help          
-s, --silent       Show minimal output
-v, --verbose      Show verbose output


[elasticsearch@es01 elasticsearch]$ elasticsearch-certutil http
warning: ignoring JAVA_HOME=/opt/elasticsearch/jdk; using bundled JDK

## Elasticsearch HTTP Certificate Utility

The 'http' command guides you through the process of generating certificates
for use on the HTTP (Rest) interface for Elasticsearch.

This tool will ask you a number of questions in order to generate the right
set of files for your needs.

## Do you wish to generate a Certificate Signing Request (CSR)?

A CSR is used when you want your certificate to be created by an existing
Certificate Authority (CA) that you do not control (that is, you don't have
access to the keys for that CA). 

If you are in a corporate environment with a central security team, then you
may have an existing Corporate CA that can generate your certificate for you.
Infrastructure within your organisation may already be configured to trust this
CA, so it may be easier for clients to connect to Elasticsearch if you use a
CSR and send that request to the team that controls your CA.

If you choose not to generate a CSR, this tool will generate a new certificate
for you. That certificate will be signed by a CA under your control. This is a
quick and easy way to secure your cluster with TLS, but you will need to
configure all your clients to trust that custom CA.

Generate a CSR? [y/N]n  

## Do you have an existing Certificate Authority (CA) key-pair that you wish to use to sign your certificate?

If you have an existing CA certificate and key, then you can use that CA to
sign your new http certificate. This allows you to use the same CA across
multiple Elasticsearch clusters which can make it easier to configure clients,
and may be easier for you to manage.

If you do not have an existing CA, one will be generated for you.

Use an existing CA? [y/N]y 

## What is the path to your CA?

Please enter the full pathname to the Certificate Authority that you wish to
use for signing your new http certificate. This can be in PKCS#12 (.p12), JKS
(.jks) or PEM (.crt, .key, .pem) format.
CA Path: /opt/elasticsearch/elastic-stack-ca.p12
Reading a PKCS12 keystore requires a password.
It is possible for the keystore's password to be blank,
in which case you can simply press <ENTER> at the prompt
Password for elastic-stack-ca.p12:

## How long should your certificates be valid?

Every certificate has an expiry date. When the expiry date is reached clients
will stop trusting your certificate and TLS connections will fail.

Best practice suggests that you should either:
(a) set this to a short duration (90 - 120 days) and have automatic processes
to generate a new certificate before the old one expires, or
(b) set it to a longer duration (3 - 5 years) and then perform a manual update
a few months before it expires.

You may enter the validity period in years (e.g. 3Y), months (e.g. 18M), or days (e.g. 90D)

For how long should your certificate be valid? [5y] 

## Do you wish to generate one certificate per node?

If you have multiple nodes in your cluster, then you may choose to generate a
separate certificate for each of these nodes. Each certificate will have its
own private key, and will be issued for a specific hostname or IP address.

Alternatively, you may wish to generate a single certificate that is valid
across all the hostnames or addresses in your cluster.

If all of your nodes will be accessed through a single domain
(e.g. node01.es.example.com, node02.es.example.com, etc) then you may find it
simpler to generate one certificate with a wildcard hostname (*.es.example.com)
and use that across all of your nodes.

However, if you do not have a common domain name, and you expect to add
additional nodes to your cluster in the future, then you should generate a
certificate per node so that you can more easily generate new certificates when
you provision new nodes.

Generate a certificate per node? [y/N]

## Which hostnames will be used to connect to your nodes?

These hostnames will be added as "DNS" names in the "Subject Alternative Name"
(SAN) field in your certificate.

You should list every hostname and variant that people will use to connect to
your cluster over http.
Do not list IP addresses here, you will be asked to enter them later.

If you wish to use a wildcard certificate (for example *.es.example.com) you
can enter that here.

Enter all the hostnames that you need, one per line.
When you are done, press <ENTER> once more to move on to the next step.


You did not enter any hostnames.
Clients are likely to encounter TLS hostname verification errors if they
connect to your cluster using a DNS name.

Is this correct [Y/n]

## Which IP addresses will be used to connect to your nodes?

If your clients will ever connect to your nodes by numeric IP address, then you
can list these as valid IP "Subject Alternative Name" (SAN) fields in your
certificate.

If you do not have fixed IP addresses, or not wish to support direct IP access
to your cluster then you can just press <ENTER> to skip this step.

Enter all the IP addresses that you need, one per line.
When you are done, press <ENTER> once more to move on to the next step.


You did not enter any IP addresses.

Is this correct [Y/n]

## Other certificate options

The generated certificate will have the following additional configuration
values. These values have been selected based on a combination of the
information you have provided above and secure defaults. You should not need to
change these values unless you have specific requirements.

Key Name: elasticsearch
Subject DN: CN=elasticsearch
Key Size: 2048

Do you wish to change any of these options? [y/N]n

## What password do you want for your private key(s)?

Your private key(s) will be stored in a PKCS#12 keystore file named "http.p12".
This type of keystore is always password protected, but it is possible to use a
blank password.

If you wish to use a blank password, simply press <enter> at the prompt below.
Provide a password for the "http.p12" file:  [<ENTER> for none]

## Where should we save the generated files?

A number of files will be generated including your private key(s),
public certificate(s), and sample configuration options for Elastic Stack products.

These files will be included in a single zip archive.

What filename should be used for the output zip file? [/opt/elasticsearch/elasticsearch-ssl-http.zip] 

Zip file written to /opt/elasticsearch/elasticsearch-ssl-http.zip


[elasticsearch@es01 elasticsearch]$ ls -lrth
total 576K
-rw-r--r--  1 elasticsearch elasticsearch 8.0K May 29  2020 README.asciidoc
-rw-r--r--  1 elasticsearch elasticsearch  14K May 29  2020 LICENSE.txt
drwxr-xr-x  2 elasticsearch elasticsearch    6 May 29  2020 plugins
-rw-r--r--  1 elasticsearch elasticsearch 523K May 29  2020 NOTICE.txt
drwxr-xr-x  3 elasticsearch elasticsearch 4.0K May 29  2020 lib
drwxr-xr-x  2 elasticsearch elasticsearch 4.0K May 29  2020 bin
drwxr-xr-x  9 elasticsearch elasticsearch  107 May 29  2020 jdk
drwxr-xr-x 45 elasticsearch elasticsearch 4.0K May 29  2020 modules
-rw-------  1 elasticsearch elasticsearch 2.5K Aug  6 11:28 elastic-stack-ca.p12
-rw-------  1 elasticsearch elasticsearch 3.4K Aug  6 11:35 elastic-certificates.p12
drwxr-xr-x  3 elasticsearch elasticsearch  231 Aug  6 14:35 config
drwxr-xr-x  2 elasticsearch elasticsearch  105 Aug  6 14:43 logs
-rw-------  1 elasticsearch elasticsearch 7.2K Aug  6 15:14 elasticsearch-ssl-http.zip
[elasticsearch@es01 elasticsearch]$


[elasticsearch@es01 elasticsearch]$ unzip elasticsearch-ssl-http.zip 
Archive:  elasticsearch-ssl-http.zip
   creating: elasticsearch/
  inflating: elasticsearch/README.txt  
  inflating: elasticsearch/http.p12  
  inflating: elasticsearch/sample-elasticsearch.yml  
   creating: kibana/
  inflating: kibana/README.txt       
  inflating: kibana/elasticsearch-ca.pem  
  inflating: kibana/sample-kibana.yml  


[elasticsearch@es01 elasticsearch]$ ll elasticsearch
total 12
-rw-r--r-- 1 elasticsearch elasticsearch 3435 Aug  6 15:14 http.p12
-rw-r--r-- 1 elasticsearch elasticsearch 1098 Aug  6 15:14 README.txt
-rw-r--r-- 1 elasticsearch elasticsearch  664 Aug  6 15:14 sample-elasticsearch.yml
[elasticsearch@es01 elasticsearch]$ ll kibana/
total 12
-rw-r--r-- 1 elasticsearch elasticsearch 1200 Aug  6 15:14 elasticsearch-ca.pem
-rw-r--r-- 1 elasticsearch elasticsearch 1306 Aug  6 15:14 README.txt
-rw-r--r-- 1 elasticsearch elasticsearch 1056 Aug  6 15:14 sample-kibana.yml
[elasticsearch@es01 elasticsearch]$


[elasticsearch@es01 elasticsearch]$ cp elasticsearch/http.p12 /opt/elasticsearch/config/

[elasticsearch@es01 elasticsearch]$ scp elasticsearch/http.p12 es02:/opt/elasticsearch/config/
elasticsearch@es02's password: 
http.p12                                                                                                                   100% 3604     1.4MB/s   00:00  

[elasticsearch@es01 elasticsearch]$ scp elasticsearch/http.p12 es03:/opt/elasticsearch/config/
elasticsearch@es03's password: 
http.p12                                                                                                                   100% 3604   948.2KB/s   00:00    
[elasticsearch@es01 elasticsearch]$ 


```



###### 7.8.2、更新 elasticsearch.yml

#elasticsearch.yml添加以下参数

```yml
xpack.security.http.ssl:
  enabled: true
  keystore.path: http.p12
```





###### 7.8.3、重启所有 Elasticsearch 节点

```bash
su - root
systemctl restart elasticsearch

systemctl status elasticsearch
```

###### 7.8.4、访问

#通过命令行

```bash
[root@es01 ~]# curl -s -k -u elastic:XIlreSzGM51dH44yuxo1  https://222.24.203.42:9200/_ssl/certificates|jq '.'
[
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "instance",
    "subject_dn": "CN=instance",
    "serial_number": "38c3a219bf66fed6f4420f1b6a826585d6ee75e8",
    "has_private_key": true,
    "expiry": "2035-08-04T03:34:58.000Z"
  },
  {
    "path": "http.p12",
    "format": "PKCS12",
    "alias": "http",
    "subject_dn": "CN=elasticsearch",
    "serial_number": "7326c6fbafb53dade40e489a2e0d3263534d3ae2",
    "has_private_key": true,
    "expiry": "2030-08-06T07:14:43.000Z"
  },
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "instance",
    "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA",
    "serial_number": "43f433b5bb3258c4bcce2f45b31de8b28164808e",
    "has_private_key": false,
    "expiry": "2035-08-04T03:27:12.000Z"
  },
  {
    "path": "elastic-certificates.p12",
    "format": "PKCS12",
    "alias": "ca",
    "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA",
    "serial_number": "43f433b5bb3258c4bcce2f45b31de8b28164808e",
    "has_private_key": false,
    "expiry": "2035-08-04T03:27:12.000Z"
  },
  {
    "path": "http.p12",
    "format": "PKCS12",
    "alias": "http",
    "subject_dn": "CN=Elastic Certificate Tool Autogenerated CA",
    "serial_number": "43f433b5bb3258c4bcce2f45b31de8b28164808e",
    "has_private_key": false,
    "expiry": "2035-08-04T03:27:12.000Z"
  }
]
```



#证书解释

```bash
#elastic-certificates.p12 - alias: instance
用途：通常用于节点间（Transport Layer）通信加密和身份认证

#http.p12 - alias: http
用途：用于 HTTP 层（即对外 HTTPS 访问），加密客户端与集群之间的通信

#elastic-certificates.p12 - alias: instance（CA证书）
用途：这是 CA（证书颁发机构）证书，用于签发上述节点证书

#elastic-certificates.p12 - alias: ca
用途：同上，也是 CA 证书，只是别名不同

#http.p12 - alias: http（CA证书）
用途：同样是 CA 证书，存储在 http.p12 文件中，供 HTTP 层使用
```



###### 7.8.5、配置kibana

#将上面生成的kibana/elasticsearch-ca.pem证书拷贝到kibana的配置目录下

```bash
[elasticsearch@es01 elasticsearch]$ ll kibana
total 12
-rw-rw-r-- 1 elasticsearch elasticsearch 1200 Jul 19 19:03 elasticsearch-ca.pem
-rw-rw-r-- 1 elasticsearch elasticsearch 1306 Jul 19 19:03 README.txt
-rw-rw-r-- 1 elasticsearch elasticsearch 1057 Jul 19 19:03 sample-kibana.yml
[elasticsearch@es01 elasticsearch]$ cp kibana/elasticsearch-ca.pem /opt/kibana/config/
```



#修改kibana配置文件

```bash
[elasticsearch@es01 elasticsearch]$ vi /opt/kibana/config/kibana.yml
#增加
elasticsearch.ssl.certificateAuthorities: /opt/kibana/config/elasticsearch-ca.pem
elasticsearch.ssl.verificationMode: certificate
#elasticsearch.ssl.verificationMode: none

```



#重启kibana

```bash
su - root
systemctl restart kibana
```

#logs

```bash
[root@es01 log]# systemctl restart kibana
[root@es01 log]# systemctl status kibana
● kibana.service - kibana
   Loaded: loaded (/usr/lib/systemd/system/kibana.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2024-07-19 19:19:21 CST; 6s ago
 Main PID: 27586 (node)
   CGroup: /system.slice/kibana.service
           └─27586 /opt/kibana/bin/../node/bin/node /opt/kibana/bin/../src/cli/dist

Jul 19 19:19:21 es01 systemd[1]: Started kibana.
Jul 19 19:19:22 es01 kibana[27586]: Kibana is currently running with legacy OpenSSL providers enabled! For details and instructions on h...-provider
Jul 19 19:19:23 es01 kibana[27586]: {"log.level":"info","@timestamp":"2024-07-19T11:19:23.123Z","log.logger":"elastic-apm-node","ecs.ver...,"timezon
Jul 19 19:19:23 es01 kibana[27586]: Native global console methods have been overridden in production environment.
Hint: Some lines were ellipsized, use -l to show in full.

```



#访问Kibana



### 三、安装kibana

#官网

```
#https://www.elastic.co/guide/en/kibana/8.13/get-started.html
https://www.elastic.co/guide/en/kibana/7.17/get-started.html
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

```bash
su - elasticsearch
cd /opt/soft

#wget https://artifacts.elastic.co/downloads/kibana/kibana-8.13.3-linux-x86_64.tar.gz
wget https://artifacts.elastic.co/downloads/kibana/kibana-7.7.1-linux-x86_64.tar.gz

tar -zxvf kibana-7.7.1-linux-x86_64.tar.gz -C  /opt/kibana --strip-components=1

#将es http ssl证书拷贝过来
cp /opt/elasticsearch/kibana/elasticsearch-ca.pem /opt/kibana/config/
```



#### 3、修改配置

#/opt/kibana/config/kibana.yml

```yaml
#kibana绑定的IP地址
server.host: "222.24.203.42"

#访问URL
#8.13版本参数，7.7.1没有该项参数
#server.publicBaseUrl: "http://222.24.203.42:5601"

#添加一个elasticsearch节点的IP即可
#elasticsearch.hosts: ["http://222.24.203.42:9200"]
elasticsearch.hosts: ["http://222.24.203.42:9200","http://222.24.203.43:9200","http://222.24.203.44:9200"]

#es超时设置Client request timeout
elasticsearch.requestTimeout: 3000000

#中文语言界面
#默认英文
#i18n.locale: "en"
i18n.locale: "zh-CN"

#log
-----------
#8.13
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
-----------------

#7.7.1
#logging.dest: stdout
logging.dest: /data/log/kibana.log

-----------
logging:
  appenders:
    file:
      type: file
      fileName: /data/log/kibana.log
      layout:
        type: pattern
  root:
    appenders: [default, file]

---------
logging:
  appenders:
    console:
      type: console
      layout:
        type: pattern
        highlight: true
    file:
      type: file
      fileName: /data/log/kibana.log
    custom:
      type: console
      layout:
        type: pattern
        pattern: "[%date][%level] %message"
    json-file-appender:
      type: file
      fileName: /data/log/kibana-json.log
      layout:
        type: json

  root:
    appenders: [default, console, file]
    level: error

  loggers:
    - name: plugins
      appenders: [custom]
      level: warn
    - name: plugins.myPlugin
      level: info
    - name: server
      level: fatal
    - name: optimize
      appenders: [console]
    - name: telemetry
      appenders: [json-file-appender]
      level: all
    - name: metrics.ops
      appenders: [console]
      level: debug
```



#最终配置

#es 已经开启 xpack和http ssl

```bash
[elasticsearch@es01 ~]$ /opt/kibana/config/kibana.yml |grep -v ^#|grep -v ^$
server.host: "222.24.203.42"
elasticsearch.hosts: ["https://222.24.203.42:9200","https://222.24.203.43:9200","https://222.24.203.44:9200"]
elasticsearch.ssl.certificateAuthorities: /opt/kibana/config/elasticsearch-ca.pem
elasticsearch.ssl.verificationMode: certificate
elasticsearch.requestTimeout: 3000000
logging.dest: /data/log/kibana.log
i18n.locale: "zh-CN"
elasticsearch.username: "kibana"
elasticsearch.password: "YNNy1i1y03a4TRqlH32w"
```





#### 4、启动与关闭

```bash
su - elasticsearch

#启动
#nohup /opt/kibana/bin/kibana &
nohup /opt/kibana/bin/kibana > /data/log/kibana.log 2>&1 &

#关闭
ps -ef | grep kibana|grep -v grep |awk '{print $2}'|xargs kill -9

#自动启动
su - root

systemctl restart kibana
systemctl status kibana
```



#### 5、访问

```html
http://222.24.203.42:5601/
```

#使用elastic:XIlreSzGM51dH44yuxo1登录访问

#不能使用kibana用户登录访问，否则403forbiden



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
su - elasticsearch

cd /opt/elasticsearch/plugins
mkdir ik

cd ik

#8.13.3
#wget https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.13.3.zip
#unzip elasticsearch-analysis-ik-8.13.3.zip
#vi plugin-descriptor.properties
#仅修改java版本
#java.version=21.0.2

#7.7.1
wget https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-7.7.1.zip

unzip elasticsearch-analysis-ik-7.7.1.zip

which java
java -version

vi plugin-descriptor.properties
#仅修改java版本
#7.7.1版本仅指定java主版本，不能指定为14.0.1，否则es无法正常启动
#java.lang.IllegalStateException: analysis-ik requires Java 14.0.1:, your system: 14
java.version=14
```

#logs

```bash
[elasticsearch@es02 ik]$ which java
/opt/elasticsearch/jdk/bin/java

[elasticsearch@es02 ik]$ java -version
openjdk version "14.0.1" 2020-04-14
OpenJDK Runtime Environment AdoptOpenJDK (build 14.0.1+7)
OpenJDK 64-Bit Server VM AdoptOpenJDK (build 14.0.1+7, mixed mode, sharing)
```



#### 2、重启es

```bash
su - root

systemctl restart elasticsearch

systemctl status elasticsearch
```

#如果指定错java版本，会导致es无法正常启动

```logs
[2025-08-06T15:55:59,063][ERROR][o.e.b.Bootstrap          ] [node-1] Exception
java.lang.IllegalStateException: analysis-ik requires Java 14.0.1:, your system: 14
        at org.elasticsearch.bootstrap.JarHell.checkJavaVersion(JarHell.java:256) ~[elasticsearch-core-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.verifyCompatibility(PluginsService.java:348) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.loadBundle(PluginsService.java:531) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.loadBundles(PluginsService.java:471) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.<init>(PluginsService.java:163) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.node.Node.<init>(Node.java:321) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.node.Node.<init>(Node.java:264) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Bootstrap$5.<init>(Bootstrap.java:227) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Bootstrap.setup(Bootstrap.java:227) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:393) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:170) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.execute(Elasticsearch.java:161) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.cli.EnvironmentAwareCommand.execute(EnvironmentAwareCommand.java:86) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:127) [elasticsearch-cli-7.7.1.jar:7.7.1]
        at org.elasticsearch.cli.Command.main(Command.java:90) [elasticsearch-cli-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:126) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:92) [elasticsearch-7.7.1.jar:7.7.1]
[2025-08-06T15:55:59,068][ERROR][o.e.b.ElasticsearchUncaughtExceptionHandler] [node-1] uncaught exception in thread [main]
org.elasticsearch.bootstrap.StartupException: java.lang.IllegalStateException: analysis-ik requires Java 14.0.1:, your system: 14
        at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:174) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.execute(Elasticsearch.java:161) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.cli.EnvironmentAwareCommand.execute(EnvironmentAwareCommand.java:86) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:127) ~[elasticsearch-cli-7.7.1.jar:7.7.1]
        at org.elasticsearch.cli.Command.main(Command.java:90) ~[elasticsearch-cli-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:126) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:92) ~[elasticsearch-7.7.1.jar:7.7.1]
Caused by: java.lang.IllegalStateException: analysis-ik requires Java 14.0.1:, your system: 14
        at org.elasticsearch.bootstrap.JarHell.checkJavaVersion(JarHell.java:256) ~[elasticsearch-core-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.verifyCompatibility(PluginsService.java:348) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.loadBundle(PluginsService.java:531) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.loadBundles(PluginsService.java:471) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.plugins.PluginsService.<init>(PluginsService.java:163) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.node.Node.<init>(Node.java:321) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.node.Node.<init>(Node.java:264) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Bootstrap$5.<init>(Bootstrap.java:227) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Bootstrap.setup(Bootstrap.java:227) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:393) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:170) ~[elasticsearch-7.7.1.jar:7.7.1]
        ... 6 more

```



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
curl -XPUT http://222.24.203.42:9200/index
```

###### 3.1.2.create a mapping

```bash
curl -XPOST http://222.24.203.42:9200/index/_mapping -H 'Content-Type:application/json' -d'
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
curl -XPOST http://222.24.203.42:9200/index/_create/1 -H 'Content-Type:application/json' -d'
{"content":"美国留给伊拉克的是个烂摊子吗"}
'
```

```bash
curl -XPOST http://222.24.203.42:9200/index/_create/2 -H 'Content-Type:application/json' -d'
{"content":"公安部：各地校车将享最高路权"}
'
```

```bash
curl -XPOST http://222.24.203.42:9200/index/_create/3 -H 'Content-Type:application/json' -d'
{"content":"中韩渔警冲突调查：韩警平均每天扣1艘中国渔船"}
'
```

```bash
curl -XPOST http://222.24.203.42:9200/index/_create/4 -H 'Content-Type:application/json' -d'
{"content":"中国驻洛杉矶领事馆遭亚裔男子枪击 嫌犯已自首"}
'
```

###### 3.1.4.query with highlighting

```bash
curl -XPOST http://222.24.203.42:9200/index/_search  -H 'Content-Type:application/json' -d'
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

#uid/gid不同时，快照存储库验证失败

```bash
[elasticsearch@es01 log]$ id elasticsearch
uid=1001(elasticsearch) gid=1001(elasticsearch) groups=1001(elasticsearch)

[elasticsearch@es02 log]$ id elasticsearch
uid=1001(elasticsearch) gid=1001(elasticsearch) groups=1001(elasticsearch)

#es03 uid/gid被oracle用户占用
[elasticsearch@es03 log]$ id elasticsearch
uid=1002(elasticsearch) gid=1003(elasticsearch) groups=1003(elasticsearch)
[elasticsearch@es03 log]$ id 1001
uid=1001(oracle) gid=1002(oinstall) groups=1002(oinstall),1001(dba)

#此时快照存储库验证报错
{
  "error": {
    "root_cause": [
      {
        "type": "repository_verification_exception",
        "reason": "[es-snp] [[a1DK8XclQean8VwNoXzK3w, 'RemoteTransportException[[node-3][222.24.203.44:9300][internal:admin/repository/verify]]; nested: RepositoryVerificationException[[es-snp] store location [/snp] is not accessible on the node [{node-3}{a1DK8XclQean8VwNoXzK3w}{Eb4f6ayoQmKiR_KZmNwMLw}{222.24.203.44}{222.24.203.44:9300}{dilmrt}{ml.machine_memory=33697431552, xpack.installed=true, transform.node=true, ml.max_open_jobs=20}]]; nested: AccessDeniedException[/snp/tests-rdy0HhrJSxKNL23xkkeSYQ/data-a1DK8XclQean8VwNoXzK3w.dat];']]"
      }
    ],
    "type": "repository_verification_exception",
    "reason": "[es-snp] [[a1DK8XclQean8VwNoXzK3w, 'RemoteTransportException[[node-3][222.24.203.44:9300][internal:admin/repository/verify]]; nested: RepositoryVerificationException[[es-snp] store location [/snp] is not accessible on the node [{node-3}{a1DK8XclQean8VwNoXzK3w}{Eb4f6ayoQmKiR_KZmNwMLw}{222.24.203.44}{222.24.203.44:9300}{dilmrt}{ml.machine_memory=33697431552, xpack.installed=true, transform.node=true, ml.max_open_jobs=20}]]; nested: AccessDeniedException[/snp/tests-rdy0HhrJSxKNL23xkkeSYQ/data-a1DK8XclQean8VwNoXzK3w.dat];']]"
  },
  "status": 500
}


#es报错日志

[2024-07-17T15:24:34,857][WARN ][r.suppressed             ] [node-2] path: /_snapshot/es-snp/_verify, params: {repository=es-snp}
org.elasticsearch.repositories.RepositoryVerificationException: [es-snp] [[a1DK8XclQean8VwNoXzK3w, 'RemoteTransportException[[node-3][222.24.203.44:9300][internal:admin/repository/verify]]; nested: RepositoryVerificationException[[es-snp] store location [/snp] is not accessible on the node [{node-3}{a1DK8XclQean8VwNoXzK3w}{Eb4f6ayoQmKiR_KZmNwMLw}{222.24.203.44}{222.24.203.44:9300}{dilmrt}{ml.machine_memory=33697431552, xpack.installed=true, transform.node=true, ml.max_open_jobs=20}]]; nested: AccessDeniedException[/snp/tests-rdy0HhrJSxKNL23xkkeSYQ/data-a1DK8XclQean8VwNoXzK3w.dat];']]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction.finishVerification(VerifyNodeRepositoryAction.java:118) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction.access$000(VerifyNodeRepositoryAction.java:49) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction$1.handleResponse(VerifyNodeRepositoryAction.java:99) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction$1.handleResponse(VerifyNodeRepositoryAction.java:95) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.TransportService$ContextRestoreResponseHandler.handleResponse(TransportService.java:1129) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.InboundHandler$1.doRun(InboundHandler.java:222) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.common.util.concurrent.AbstractRunnable.run(AbstractRunnable.java:37) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.common.util.concurrent.EsExecutors$DirectExecutorService.execute(EsExecutors.java:225) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.InboundHandler.handleResponse(InboundHandler.java:214) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.InboundHandler.messageReceived(InboundHandler.java:139) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.InboundHandler.inboundMessage(InboundHandler.java:103) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.TcpTransport.inboundMessage(TcpTransport.java:676) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.netty4.Netty4MessageChannelHandler.channelRead(Netty4MessageChannelHandler.java:62) [transport-netty4-client-7.7.1.jar:7.7.1]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:377) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:363) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:355) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.handler.codec.ByteToMessageDecoder.fireChannelRead(ByteToMessageDecoder.java:321) [netty-codec-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.handler.codec.ByteToMessageDecoder.channelRead(ByteToMessageDecoder.java:295) [netty-codec-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:377) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:363) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:355) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.handler.logging.LoggingHandler.channelRead(LoggingHandler.java:227) [netty-handler-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:377) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:363) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:355) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.DefaultChannelPipeline$HeadContext.channelRead(DefaultChannelPipeline.java:1410) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:377) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:363) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.DefaultChannelPipeline.fireChannelRead(DefaultChannelPipeline.java:919) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.nio.AbstractNioByteChannel$NioByteUnsafe.read(AbstractNioByteChannel.java:163) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.nio.NioEventLoop.processSelectedKey(NioEventLoop.java:714) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.nio.NioEventLoop.processSelectedKeysPlain(NioEventLoop.java:615) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.nio.NioEventLoop.processSelectedKeys(NioEventLoop.java:578) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.channel.nio.NioEventLoop.run(NioEventLoop.java:493) [netty-transport-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.util.concurrent.SingleThreadEventExecutor$4.run(SingleThreadEventExecutor.java:989) [netty-common-4.1.45.Final.jar:4.1.45.Final]
        at io.netty.util.internal.ThreadExecutorMap$2.run(ThreadExecutorMap.java:74) [netty-common-4.1.45.Final.jar:4.1.45.Final]
        at java.lang.Thread.run(Thread.java:832) [?:?]


[2024-07-17T15:24:31,119][WARN ][o.e.r.VerifyNodeRepositoryAction] [node-3] [es-snp] failed to verify repository
org.elasticsearch.repositories.RepositoryVerificationException: [es-snp] store location [/snp] is not accessible on the node [{node-3}{a1DK8XclQean8VwNoXzK3w}{Eb4f6ayoQmKiR_KZmNwMLw}{222.24.203.44}{222.24.203.44:9300}{dilmrt}{ml.machine_memory=33697431552, xpack.installed=true, transform.node=true, ml.max_open_jobs=20}]
        at org.elasticsearch.repositories.blobstore.BlobStoreRepository.verify(BlobStoreRepository.java:1893) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction.doVerify(VerifyNodeRepositoryAction.java:126) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction.access$400(VerifyNodeRepositoryAction.java:49) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction$VerifyNodeRepositoryRequestHandler.messageReceived(VerifyNodeRepositoryAction.java:158) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.VerifyNodeRepositoryAction$VerifyNodeRepositoryRequestHandler.messageReceived(VerifyNodeRepositoryAction.java:153) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.RequestHandlerRegistry.processMessageReceived(RequestHandlerRegistry.java:63) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.transport.InboundHandler$RequestHandler.doRun(InboundHandler.java:264) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.common.util.concurrent.ThreadContext$ContextPreservingAbstractRunnable.doRun(ThreadContext.java:692) [elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.common.util.concurrent.AbstractRunnable.run(AbstractRunnable.java:37) [elasticsearch-7.7.1.jar:7.7.1]
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1130) [?:?]
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:630) [?:?]
        at java.lang.Thread.run(Thread.java:832) [?:?]
Caused by: java.nio.file.AccessDeniedException: /snp/tests-rdy0HhrJSxKNL23xkkeSYQ/data-a1DK8XclQean8VwNoXzK3w.dat
        at sun.nio.fs.UnixException.translateToIOException(UnixException.java:90) ~[?:?]
        at sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:111) ~[?:?]
        at sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:116) ~[?:?]
        at sun.nio.fs.UnixFileSystemProvider.newByteChannel(UnixFileSystemProvider.java:219) ~[?:?]
        at java.nio.file.spi.FileSystemProvider.newOutputStream(FileSystemProvider.java:478) ~[?:?]
        at java.nio.file.Files.newOutputStream(Files.java:224) ~[?:?]
        at org.elasticsearch.common.blobstore.fs.FsBlobContainer.writeBlob(FsBlobContainer.java:161) ~[elasticsearch-7.7.1.jar:7.7.1]
        at org.elasticsearch.repositories.blobstore.BlobStoreRepository.verify(BlobStoreRepository.java:1890) ~[elasticsearch-7.7.1.jar:7.7.1]
        ... 11 more
```



#如果存储可以改为all_squash，那么服务器这边不用动

![image-20240717163751146](es\image-20240717163751146.png)



#但是如果存储为共享目录，已经有其它业务在跑，存储这边参数不建议修改，防止影响其它业务。

#第二个解决办法，就是修改服务器这边的uid/gid

#修改过程

```bash
#es03 uid/gid被oracle用户占用
[elasticsearch@es03 log]$ id elasticsearch
uid=1002(elasticsearch) gid=1003(elasticsearch) groups=1003(elasticsearch)
[elasticsearch@es03 log]$ id 1001
uid=1001(oracle) gid=1002(oinstall) groups=1002(oinstall),1001(dba)

[elasticsearch@es03 log]$ su - root

[root@es03 ~]# userdel -rf oracle
[root@es03 ~]# groupdel dba
[root@es03 ~]# groupdel oinstall


[root@es03 ~]# getent passwd | awk -F: '{print $3}' | sort -n | grep 1001
[root@es03 ~]# getent group | awk -F: '{print $3}' | sort -n | grep 1001

[root@es03 ~]# getent group | awk -F: '{print $3}' | sort -n | grep 1003
1003
[root@es03 ~]# getent passwd | awk -F: '{print $3}' | sort -n | grep 1002
1002
[root@es03 ~]# systemctl stop elasticsearch.service

[root@es03 home]# userdel -rf elasticsearch

[root@es03 home]# getent group | awk -F: '{print $3}' | sort -n | grep 1003
[root@es03 ~]# getent passwd | awk -F: '{print $3}' | sort -n | grep 1002

[root@es03 home]#  groupadd -g 1001 elasticsearch
[root@es03 home]#  useradd -u 1001 -g 1001 elasticsearch


[root@es03 home]# passwd elasticsearch
Changing password for user elasticsearch.
New password:
Retype new password:
passwd: all authentication tokens updated successfully.


#然后重新对elasticsearch用户的目录赋权下

chown -R elasticsearch:elasticsearch /opt/soft

chown -R elasticsearch:elasticsearch /opt/elasticsearch

chown -R elasticsearch:elasticsearch /data/data

chown -R elasticsearch:elasticsearch /data/log

#chown -R elasticsearch:elasticsearch /opt/kibana

#启动es服务
[root@es03 opt]# systemctl start elasticsearch
[root@es03 opt]# systemctl status elasticsearch
● elasticsearch.service - elasticsearch
   Loaded: loaded (/usr/lib/systemd/system/elasticsearch.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2024-07-17 16:24:10 CST; 3s ago
 Main PID: 39879 (java)
    Tasks: 37
   CGroup: /system.slice/elasticsearch.service
           └─39879 /opt/elasticsearch/jdk/bin/java -Xshare:auto -Des.networkaddress.cache.ttl=60 -Des.networkaddress.cache.negative.ttl=10 -XX:+AlwaysPreTouch -Xss1m -Djava.awt.headless=true -Dfil...

Jul 17 16:24:10 es03 systemd[1]: Started elasticsearch.
[root@es03 opt]# systemctl status elasticsearch
● elasticsearch.service - elasticsearch
   Loaded: loaded (/usr/lib/systemd/system/elasticsearch.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2024-07-17 16:24:10 CST; 4s ago
 Main PID: 39879 (java)
    Tasks: 44
   CGroup: /system.slice/elasticsearch.service
           ├─39879 /opt/elasticsearch/jdk/bin/java -Xshare:auto -Des.networkaddress.cache.ttl=60 -Des.networkaddress.cache.negative.ttl=10 -XX:+AlwaysPreTouch -Xss1m -Djava.awt.headless=true -Dfil...
           └─40143 /opt/elasticsearch/modules/x-pack-ml/platform/linux-x86_64/bin/controller

Jul 17 16:24:10 es03 systemd[1]: Started elasticsearch.
Jul 17 16:24:13 es03 elasticsearch[39879]: [2024-07-17T16:24:13,865][INFO ][o.e.e.NodeEnvironment    ] [node-3] using [1] data paths, mounts [[/ (rootfs)]], net usable_space [42...pes [rootfs]
Jul 17 16:24:13 es03 elasticsearch[39879]: [2024-07-17T16:24:13,868][INFO ][o.e.e.NodeEnvironment    ] [node-3] heap size [15gb], compressed ordinary object pointers [true]
Jul 17 16:24:13 es03 elasticsearch[39879]: [2024-07-17T16:24:13,995][INFO ][o.e.n.Node               ] [node-3] node name [node-3], node ID [a1DK8XclQean8VwNoXzK3w], cluster name [nwpu-newes]
Jul 17 16:24:13 es03 elasticsearch[39879]: [2024-07-17T16:24:13,998][INFO ][o.e.n.Node               ] [node-3] version[7.7.1], pid[39879], build[default/tar/ad56dce891c901a492b....1/14.0.1+7]
Jul 17 16:24:13 es03 elasticsearch[39879]: [2024-07-17T16:24:13,998][INFO ][o.e.n.Node               ] [node-3] JVM home [/opt/elasticsearch/jdk]
Jul 17 16:24:13 es03 elasticsearch[39879]: [2024-07-17T16:24:13,999][INFO ][o.e.n.Node               ] [node-3] JVM arguments [-Xshare:auto, -Des.networkaddress.cache.ttl=60, -D...tackTraceInF
Hint: Some lines were ellipsized, use -l to show in full.
```





#### 2、每台es节点创建备份目录，并mount共享目录

```bash
su - root

mkdir /snp

yum install -y nfs-utils

mount -t nfs 10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp /snp

chmod -R 777 /snp

cat >> /etc/fstab <<EOF
10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp      /snp      nfs  defaults,_netdev  0 0
EOF

#mount -t nfs 10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS_share/Ecampus_tmp /newessnp
```



#### 3、修改es节点的elasticsearch.yml

```bash
su - elasticsearch

cat >> /opt/elasticsearch/config/elasticsearch.yml <<EOF
path.repo: ["/snp"]
#path.repo: ["/snp","/newessnp"]
EOF

su - root
systemctl restart elasticsearch
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

curl -XPUT 222.24.203.42:9200/_snapshot/my_backup -d 
'{
  "type": "fs",
  "settings": {
    "location": "/data/es_snapshot"
  }
}'


#查看存储库
#GET /_snapshot/my_backup

curl -XGET 222.24.203.42:9200/_snapshot/my_backup

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



curl -XGET http://222.24.203.42:9200/_cat/snapshots?v

#
id                                           repository  status start_epoch start_time end_epoch  end_time duration indices successful_shards failed_shards total_shards
daily-snap-2024.05.11-pfsf0g5er7ophfuigczrqw es-nfs     SUCCESS 1715411551  07:12:31   1715411552 07:12:32       1s      34                34             0           34


curl -XGET http://222.24.203.44:9200/_snapshot/es-nfs/daily-snap-2024.05.11-pfsf0g5er7ophfuigczrqw/_status

#curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/es_snp?verify=false" -X PUT -H "Content-Type: application/json" -d '{"type":"fs","settings":{"location":"/snp","compress":true,"readonly":true}}'

#curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/es_snp" -X PUT -H "Content-Type: application/json" -d '{"type":"fs","settings":{"location":"/snp","compress":true}}'
```



#### 5、快照

##### 5.1、通过kibana打快照

#配置完策略后，可以点击立即执行，会立即生成一份快照

```
Management ---> Stack Management ---> Snapshot and Restore ---> 策略

策略名称: daily-snap
快照名称: <daily-snap-{now/d}>
存储库: es_snp
计划: 0 30 1 * * ?

快照保留: 5days

---> 所有数据流和索引
---> 单个索引等
```

```bash
创建与 Kibana 相同的 SLM 策略

- 策略名：daily-snap
- 调度：0 30 1 * * ?（每天 01:30）
- 快照名模板：<daily-snap-{now/d}>
- 仓库：newes_snp
- 索引：所有索引
- 忽略不可用索引：是
- 允许部分快照：是
- 包含全局状态：是
- 保留期限：5d
```



##### 5.2、通过命令打快照

```bash
# 创建单次快照
PUT /_snapshot/newes_snp/daily-snap-2024.05.11-16-43?wait_for_completion=true 
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
GET /_snapshot/newes_snp/daily-snap-2024.05.11-16-43

#创建每日快照
curl -u elastic:$ESPASSWD -H 'Content-Type: application/json' -X PUT -k  "https://222.24.203.42:9200/_slm/policy/daily-snap" -d '{
  "schedule": "0 30 17 * * ?",
  "name": "<daily-snap-{now/d}>",
  "repository": "newes_snp",
  "config": {
    "indices": ["*"],
    "ignore_unavailable": true,
    "include_global_state": true,
    "partial": true
  },
  "retention": {
    "expire_after": "5d"
  }
}'


#立即执行一次此策略 
curl -X POST -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap/_execute"
#查看策略 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"
#查看 SLM 状态 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/status?pretty"
#立刻执行一次保留清理（删除超过 5d 的快照） 
curl -X POST -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/_execute_retention"

#查看进行中的快照进度
#查所有正在进行的快照 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/_status?pretty"
#只看指定仓库 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/newes_snp/_status?pretty"
#已知快照名时（进度最详细） 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/newes_snp/<SNAPSHOT_NAME>/_status?pretty"

#以上返回中的关键字段：
snapshots[0].state: IN_PROGRESS / SUCCESS / FAILED
snapshots[0].shards_stats: initializing/started/finalizing/done/failed/total
snapshots[0].stats.time_in_millis、size_in_bytes


#快速看状态列表
#列出仓库里快照及状态（IN_PROGRESS/SUCCESS/FAILED） 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_cat/snapshots/newes_snp?v&s=start_epoch:desc"

#通过任务查看（可选，看到创建快照的任务） 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_tasks?detailed=true&actions=cluster:admin/snapshot/*&pretty"

#查看策略的最近一次成功/失败时间 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"

#查询 SLM 历史（最近10条） 
#查询字段
curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_mapping?pretty&filter_path=**.properties"

#根据上面查询出的字段名称，来查询最近的十条---@timestamp
curl -H 'Content-Type: application/json' -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_search?pretty" -d '{"size":10,"sort":[{"@timestamp":"desc"}]}'

#（按快照名显示完成分片数/总数） SN=<执行策略后返回的snapshot_name> 
#daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw
export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
watch -n 5 "curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw/_status' | jq -r '.snapshots[0] | \"state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)\"'"

export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
while true; do
  curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/'"$SN"'/_status' \
  | jq -r '.snapshots[0] | "state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)"'
  sleep 5
done

#（按快照名显示完成分片数/总数） SN=<执行策略后返回的snapshot_name> 
#daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw
export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
watch -n 5 "curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw/_status' | jq -r '.snapshots[0] | \"state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)\"'"

export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
while true; do
  curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/'"$SN"'/_status' \
  | jq -r '.snapshots[0] | "state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)"'
  sleep 5
done
```



```bash
[elasticsearch@es03 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_cat/snapshots/newes_snp?v&s=start_epoch:desc"
id                                                status start_epoch start_time end_epoch  end_time duration indices successful_shards failed_shards total_shards
daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw IN_PROGRESS 1755222710  01:51:50   0          00:00:00    11.6m      75                 0             0            0
snapshot_20240814                                SUCCESS 1755155369  07:09:29   1755155369 07:09:29    200ms       1                 1             0            1


[elasticsearch@es03 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_tasks?detailed=true&actions=cluster:admin/snapshot/*&pretty"
{
  "nodes" : {
    "s3cH7VN6RkqEkCNlo9C4bQ" : {
      "name" : "node-3",
      "transport_address" : "222.24.203.44:9300",
      "host" : "222.24.203.44",
      "ip" : "222.24.203.44:9300",
      "roles" : [
        "ingest",
        "master",
        "transform",
        "data",
        "remote_cluster_client",
        "ml"
      ],
      "attributes" : {
        "ml.machine_memory" : "32322408448",
        "ml.max_open_jobs" : "20",
        "xpack.installed" : "true",
        "transform.node" : "true"
      },
      "tasks" : {
        "s3cH7VN6RkqEkCNlo9C4bQ:567925" : {
          "node" : "s3cH7VN6RkqEkCNlo9C4bQ",
          "id" : 567925,
          "type" : "transport",
          "action" : "cluster:admin/snapshot/create",
          "description" : "snapshot [newes_snp:daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw]",
          "start_time_in_millis" : 1755222710484,
          "running_time_in_nanos" : 833072763081,
          "cancellable" : false,
          "headers" : { }
        }
      }
    }
  }
}

#打快照中
[devel@docker-01 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"
{
  "daily-snap" : {
    "version" : 2,
    "modified_date_millis" : 1755222630730,
    "policy" : {
      "name" : "<daily-snap-{now/d}>",
      "schedule" : "0 30 17 * * ?",
      "repository" : "newes_snp",
      "config" : {
        "ignore_unavailable" : true,
        "partial" : true
      },
      "retention" : {
        "expire_after" : "5d"
      }
    },
    "next_execution_millis" : 1755279000000,
    "in_progress" : {
      "name" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
      "uuid" : "ZrS8LwCSQsG8dexSBWgQ9w",
      "state" : "STARTED",
      "start_time_millis" : 1755222710474
    },
    "stats" : {
      "policy" : "daily-snap",
      "snapshots_taken" : 0,
      "snapshots_failed" : 0,
      "snapshots_deleted" : 0,
      "snapshot_deletion_failures" : 0
    }
  }
}

#快照完毕
[elasticsearch@es03 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"
{
  "daily-snap" : {
    "version" : 2,
    "modified_date_millis" : 1755222630730,
    "policy" : {
      "name" : "<daily-snap-{now/d}>",
      "schedule" : "0 30 17 * * ?",
      "repository" : "newes_snp",
      "config" : {
        "ignore_unavailable" : true,
        "partial" : true
      },
      "retention" : {
        "expire_after" : "5d"
      }
    },
    "last_success" : {
      "snapshot_name" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
      "time" : 1755224920313
    },
    "next_execution_millis" : 1755279000000,
    "stats" : {
      "policy" : "daily-snap",
      "snapshots_taken" : 1,
      "snapshots_failed" : 0,
      "snapshots_deleted" : 0,
      "snapshot_deletion_failures" : 0
    }
  }
}



[elasticsearch@es03 indices]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/_status?pretty"
{
  "snapshots" : [
    {
      "snapshot" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
      "repository" : "newes_snp",
      "uuid" : "ZrS8LwCSQsG8dexSBWgQ9w",
      "state" : "STARTED",
      "include_global_state" : true,
      "shards_stats" : {
        "initializing" : 0,
        "started" : 61,
        "finalizing" : 0,
        "done" : 14,
        "failed" : 0,
        "total" : 75
      },
      "stats" : {
        "incremental" : {
          "file_count" : 8108,
          "size_in_bytes" : 145754282608
        },
        "processed" : {
          "file_count" : 1087,
          "size_in_bytes" : 24843215555
        },
        "total" : {
          "file_count" : 8108,
          "size_in_bytes" : 145754282608
        },
        "start_time_in_millis" : 1755222710474,
        "time_in_millis" : 299524
      },
      "indices" : {
        "authx_log__service_access_log_index-2024.01" : {
          "shards_stats" : {
            "initializing" : 0,
            "started" : 0,
            "finalizing" : 0,
            "done" : 1,
            "failed" : 0,
            "total" : 1
          },
          "stats" : {
            "incremental" : {
              "file_count" : 61,
              "size_in_bytes" : 4264903144
            },
            "processed" : {
              "file_count" : 44,
              "size_in_bytes" : 4264895242
            },
            "total" : {
              "file_count" : 61,
              "size_in_bytes" : 4264903144
            },
            "start_time_in_millis" : 1755222710474,
            "time_in_millis" : 238699
          },
          "shards" : {
            "0" : {
              "stage" : "DONE",
              "stats" : {
                "incremental" : {
                  "file_count" : 61,
                  "size_in_bytes" : 4264903144
                },
                "processed" : {
                  "file_count" : 44,
                  "size_in_bytes" : 4264895242
                },
                "total" : {
                  "file_count" : 61,
                  "size_in_bytes" : 4264903144
                },
                "start_time_in_millis" : 1755222710474,
                "time_in_millis" : 238699
              }
            }
          }
        },
        "authx_log__service_access_log_index-2024.03" : {
          "shards_stats" : {
            "initializing" : 0,
            "started" : 1,
            "finalizing" : 0,
            "done" : 0,
            "failed" : 0,
            "total" : 1
          },
          "stats" : {
            "incremental" : {
              "file_count" : 79,
              "size_in_bytes" : 4449175058
            },
            "processed" : {
              "file_count" : 0,
              "size_in_bytes" : 0
            },
            "total" : {
              "file_count" : 79,
              "size_in_bytes" : 4449175058
            },
            "start_time_in_millis" : 1755222710674,
            "time_in_millis" : 0
          },
          "shards" : {
            "0" : {
              "stage" : "STARTED",
              "stats" : {
                "incremental" : {
                  "file_count" : 79,
                  "size_in_bytes" : 4449175058
                },
                "processed" : {
                  "file_count" : 0,
                  "size_in_bytes" : 0
                },
                "total" : {
                  "file_count" : 79,
                  "size_in_bytes" : 4449175058
                },
                "start_time_in_millis" : 1755222710674,
                "time_in_millis" : 0
              },
              "node" : "s3cH7VN6RkqEkCNlo9C4bQ"
            }
          }
        },
  
#快照进度
export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
watch -n 5 "curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw/_status' | jq -r '.snapshots[0] | \"state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)\"'"

Every 5.0s: curl -s -k -u elastic:XIlreSzGM51dH44yuxo1 'https://222.24.203.42:9200/_snapshot/newes_snp/daily-snap...  docker-01: Fri Aug 15 10:27:37 2025

state=STARTED done=72/75
......
state=SUCCESS done=75/75


#快照历史记录
#查询字段
[elasticsearch@es03 ~]$  curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_mapping?pretty&filter_path=**.properties"
{
  ".slm-history-2-000001" : {
    "mappings" : {
      "properties" : {
        "@timestamp" : {
          "type" : "date",
          "format" : "epoch_millis"
        },
        "configuration" : {
          "dynamic" : "false",
          "properties" : {
            "include_global_state" : {
              "type" : "boolean"
            },
            "indices" : {
              "type" : "keyword"
            },
            "partial" : {
              "type" : "boolean"
            }
          }
        },
        "error_details" : {
          "type" : "text",
          "index" : false
        },
        "operation" : {
          "type" : "keyword"
        },
        "policy" : {
          "type" : "keyword"
        },
        "repository" : {
          "type" : "keyword"
        },
        "snapshot_name" : {
          "type" : "keyword"
        },
        "success" : {
          "type" : "boolean"
        }
      }
    }
  }
}

[elasticsearch@es03 ~]$ curl -H 'Content-Type: application/json' -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_search?pretty" -d '{"size":10,"sort":[{"@timestamp":"desc"}]}'
{
  "took" : 1,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 1,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [
      {
        "_index" : ".slm-history-2-000001",
        "_type" : "_doc",
        "_id" : "UvCOq5gBbVBmE7QY0cWV",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755224920313,
          "policy" : "daily-snap",
          "repository" : "newes_snp",
          "snapshot_name" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755224920313
        ]
      }
    ]
  }
}


#其它多条记录的
GET /.slm-history-*/_search?pretty
{"size":6,"sort":[{"@timestamp":"desc"}]}

{
  "took" : 51,
  "timed_out" : false,
  "_shards" : {
    "total" : 4,
    "successful" : 4,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 188,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "y5pZq5gBhgCqahXjJMgo",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755221402664,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.09-vr1mvm1itcqafltjyivlna",
          "operation" : "DELETE",
          "success" : true,
          "configuration" : null,
          "error_details" : null
        },
        "sort" : [
          1755221402664
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "1ZahqZgBhgCqahXj5kd2",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755192616566,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.14-qwh4_zdxracjojhi2f2ymq",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755192616566
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "wo0yppgBhgCqahXjxj40",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755135002163,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.08-ahqjsvhatagf7cgczakvhq",
          "operation" : "DELETE",
          "success" : true,
          "configuration" : null,
          "error_details" : null
        },
        "sort" : [
          1755135002163
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "uYh7pJgBhgCqahXjjLbC",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755106217154,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.13-hqqw5k6usrifnkflhhp0ig",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755106217154
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "3H8MoZgBhgCqahXjj6qO",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755048611725,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.07-v8mf6pb6ragvxy5kgcpg-q",
          "operation" : "DELETE",
          "success" : true,
          "configuration" : null,
          "error_details" : null
        },
        "sort" : [
          1755048611725
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "kntVn5gBhgCqahXjHRt9",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755019812221,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.12-voemyurrtdwtdiwvltg7kg",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755019812221
        ]
      }
    ]
  }
}

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
[root@es02 ~]# elasticsearch -d
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



#### 3、es集群第一遍初始化成功后，需要修改配置文件

#/opt/elasticsearch/config/elasticsearch.yml

#注释掉cluster.initial_master_nodes一行

```yaml
#cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
```





#否则报错

```log
[2024-05-09T15:43:00,388][WARN ][o.e.c.c.ClusterBootstrapService] [node-1] this node is locked into cluster UUID [cpLLf87gS2uEEAVlPEFYaA] but [cluster.initial_master_nodes] is set to [node-1, node-2, node-3]; remove this setting to avoid possible data loss caused by subsequent cluster bootstrap attempts; for further information see https://www.elastic.co/guide/en/elasticsearch/reference/8.13/important-settings.html#initial_master_nodes
[2024-05-09T15:43:10,404][WARN ][o.e.c.c.ClusterFormationFailureHelper] [node-1] master not discovered or elected yet, an election requires at least 2 nodes with ids from [178aaQJ1RTut1WclHoKkOw, tAGwLBqPR6KS0E-tzhRFgw, 4mfikY7-RpyVPJ2EQ6RKJw], have only discovered non-quorum [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{222.24.203.42}{222.24.203.42:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}]; discovery will continue using [222.24.203.43:9300, 222.24.203.44:9300] from hosts providers and [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{222.24.203.42}{222.24.203.42:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}] from last-known cluster state; node term 2, last-accepted version 148 in term 2; for troubleshooting guidance, see https://www.elastic.co/guide/en/elasticsearch/reference/8.13/discovery-troubleshooting.html
[2024-05-09T15:43:20,409][WARN ][o.e.c.c.ClusterFormationFailureHelper] [node-1] master not discovered or elected yet, an election requires at least 2 nodes with ids from [178aaQJ1RTut1WclHoKkOw, tAGwLBqPR6KS0E-tzhRFgw, 4mfikY7-RpyVPJ2EQ6RKJw], have only discovered non-quorum [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{222.24.203.42}{222.24.203.42:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}]; discovery will continue using [222.24.203.43:9300, 222.24.203.44:9300] from hosts providers and [{node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{222.24.203.42}{222.24.203.42:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}] from last-known cluster state; node term 2, last-accepted version 148 in term 2; for troubleshooting guidance, see https://www.elastic.co/guide/en/elasticsearch/reference/8.13/discovery-troubleshooting.html
[2024-05-09T15:43:23,349][INFO ][o.e.c.s.ClusterApplierService] [node-1] master node changed {previous [], current [{node-2}{4mfikY7-RpyVPJ2EQ6RKJw}{sQaBo1vGTUK-8B-9xWBYIQ}{node-2}{222.24.203.43}{222.24.203.43:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}]}, added {{node-2}{4mfikY7-RpyVPJ2EQ6RKJw}{sQaBo1vGTUK-8B-9xWBYIQ}{node-2}{222.24.203.43}{222.24.203.43:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}}, term: 3, version: 185, reason: ApplyCommitRequest{term=3, version=185, sourceNode={node-2}{4mfikY7-RpyVPJ2EQ6RKJw}{sQaBo1vGTUK-8B-9xWBYIQ}{node-2}{222.24.203.43}{222.24.203.43:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}{ml.allocated_processors=16, ml.machine_memory=33371656192, transform.config_version=10.0.0, xpack.installed=true, ml.config_version=12.0.0, ml.max_jvm_size=16684941312, ml.allocated_processors_double=16.0}}
[2024-05-09T15:43:23,376][INFO ][o.e.h.AbstractHttpServerTransport] [node-1] publish_address {222.24.203.42:9200}, bound_addresses {222.24.203.42:9200}
[2024-05-09T15:43:23,395][INFO ][o.e.n.Node               ] [node-1] started {node-1}{178aaQJ1RTut1WclHoKkOw}{i6BZQOmtSw2ntcfq7T6wnQ}{node-1}{222.24.203.42}{222.24.203.42:9300}{cdfhilmrstw}{8.13.3}{7000099-8503000}{ml.allocated_processors=16, ml.machine_memory=33371656192, transform.config_version=10.0.0, xpack.installed=true, ml.config_version=12.0.0, ml.max_jvm_size=16684941312, ml.allocated_processors_double=16.0}
[elasticsearch@es01 config]$ 
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

#使用Rally进行压测

#官网

```yaml
https://esrally.readthedocs.io/en/latest/
```



#### 1、先决条件

```json
Python 3.8+ including pip3
git 1.9+
jdk 1.8.0+
```



#ES支持jdk版本

```
https://www.elastic.co/cn/support/matrix#matrix_jvm
```



##### 1.1.Python 3.8





##### 1.2.git 





##### 1.3.jdk

#oracle

```json
https://www.oracle.com/java/technologies/downloads/
```



#下载

```
wget https://download.oracle.com/otn/java/jdk/8u411-b09/43d62d619be4e416215729597d70b8ac/jdk-8u411-linux-x64.tar.gz
```







### 九、es的监控


### 十、es的测试

#### 1、导入数据
#官网数据
```bash
mkdir /root/es/
cd /root/es/

#7
#https://github.com/elastic/elasticsearch/blob/v7.7.1/docs/src/test/resources/accounts.json
wget https://raw.githubusercontent.com/elastic/elasticsearch/v7.7.1/docs/src/test/resources/accounts.json


#8
#https://github.com/elastic/elasticsearch/blob/v8.13.3/docs/src/yamlRestTest/resources/normalized-T1117-AtomicRed-regsvr32.json
wget https://raw.githubusercontent.com/elastic/elasticsearch/v8.13.3/docs/src/yamlRestTest/resources/normalized-T1117-AtomicRed-regsvr32.json
```



#导入es数据

```bash
curl -H "Content-Type: application/json" -XPOST "222.24.203.42:9200/bank/_bulk?pretty&refresh" --data-binary "@/root/es/accounts.json"
```



#查看状态

```bash
# curl -XGET "222.24.203.42:9200/_cat/indices?v" | grep bank
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  4025    0  4025    0     0   194k      0 --:--:-- --:--:-- --:--:--  196k
green  open   bank                                                               LEZthvWDTd-YIHrQJkkVdw   1   1       1000            0    762.7kb        389.7kb      389.7kb
```



#### 2、查询

##### 2.1.查询所有

#查询所有，并按照account_number升序排序

```bash
GET /bank/_search
{
  "query":
  {
    "match_all": {}
  },
  "sort": [
    {"account_number": "asc"}
    ]
}
```

#logs

```json
{
  "took": 4,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1000,
      "relation": "eq"
    },
    "max_score": null,
    "hits": [
      {
        "_index": "bank",
        "_id": "0",
        "_score": null,
        "_source": {
          "account_number": 0,
          "balance": 16623,
          "firstname": "Bradshaw",
          "lastname": "Mckenzie",
          "age": 29,
          "gender": "F",
          "address": "244 Columbus Place",
          "employer": "Euron",
          "email": "bradshawmckenzie@euron.com",
          "city": "Hobucken",
          "state": "CO"
        },
        "sort": [
          0
        ]
      },
      {
        "_index": "bank",
        "_id": "1",
        "_score": null,
        "_source": {
          "account_number": 1,
          "balance": 39225,
          "firstname": "Amber",
          "lastname": "Duke",
          "age": 32,
          "gender": "M",
          "address": "880 Holmes Lane",
          "employer": "Pyrami",
          "email": "amberduke@pyrami.com",
          "city": "Brogan",
          "state": "IL"
        },
        "sort": [
          1
        ]
      },
      ....
    ]
  }
}
     
```



#相关字段解释

```json
took – Elasticsearch运行查询所花费的时间（以毫秒为单位）
timed_out – 搜索请求是否超时
_shards - 搜索了多少个碎片，以及成功，失败或跳过了多少个碎片的细目分类
max_score – 找到的最相关文档的分数
hits.total.value - 找到了多少个匹配的文档
hits.sort - 文档的排序位置（不按相关性得分排序时）
hits._score - 文档的相关性得分（使用match_all时不适用）
```






##### 2.2.分页查询

#from

#size

```bash
GET /bank/_search
{
  "query": {
    "match_all": {}
  },
  "sort": [
    {
        "account_number": "desc"
    }
  ],
  "from": 10,
  "size": 20
}
```



#logs

```json
{
  "took": 5,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1000,
      "relation": "eq"
    },
    "max_score": null,
    "hits": [
      {
        "_index": "bank",
        "_id": "10",
        "_score": null,
        "_source": {
          "account_number": 10,
          "balance": 46170,
          "firstname": "Dominique",
          "lastname": "Park",
          "age": 37,
          "gender": "F",
          "address": "100 Gatling Place",
          "employer": "Conjurica",
          "email": "dominiquepark@conjurica.com",
          "city": "Omar",
          "state": "NJ"
        },
        "sort": [
          10
        ]
      },
      {
        "_index": "bank",
        "_id": "11",
        "_score": null,
        "_source": {
          "account_number": 11,
          "balance": 20203,
          "firstname": "Jenkins",
          "lastname": "Haney",
          "age": 20,
          "gender": "M",
          "address": "740 Ferry Place",
          "employer": "Qimonk",
          "email": "jenkinshaney@qimonk.com",
          "city": "Steinhatchee",
          "state": "GA"
        },
        "sort": [
          11
        ]
      },
      .......
      {
        "_index": "bank",
        "_id": "29",
        "_score": null,
        "_source": {
          "account_number": 29,
          "balance": 27323,
          "firstname": "Leah",
          "lastname": "Santiago",
          "age": 33,
          "gender": "M",
          "address": "193 Schenck Avenue",
          "employer": "Isologix",
          "email": "leahsantiago@isologix.com",
          "city": "Gerton",
          "state": "ND"
        },
        "sort": [
          29
        ]
      }
    ]
  }
}
```



##### 2.3.指定字段查询

#match

#如果要在字段中搜索特定字词，可以使用`match`

#如下语句将查询address 字段中包含 mill 或者 lane的数据

#由于ES底层是按照分词索引的，所以上述查询结果是address 字段中包含 mill 或者 lane的数据

```bash
GET /bank/_search
{
  "query":
  {
    "match": {
      "address": "mill lane"
    }
  }
}

```



#logs

```json
{
  "took": 4,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 19,
      "relation": "eq"
    },
    "max_score": 9.507477,
    "hits": [
      {
        "_index": "bank",
        "_id": "136",
        "_score": 9.507477,
        "_source": {
          "account_number": 136,
          "balance": 45801,
          "firstname": "Winnie",
          "lastname": "Holland",
          "age": 38,
          "gender": "M",
          "address": "198 Mill Lane",
          "employer": "Neteria",
          "email": "winnieholland@neteria.com",
          "city": "Urie",
          "state": "IL"
        }
      },
      {
        "_index": "bank",
        "_id": "970",
        "_score": 5.4032025,
        "_source": {
          "account_number": 970,
          "balance": 19648,
          "firstname": "Forbes",
          "lastname": "Wallace",
          "age": 28,
          "gender": "M",
          "address": "990 Mill Road",
          "employer": "Pheast",
          "email": "forbeswallace@pheast.com",
          "city": "Lopezo",
          "state": "AK"
        }
      },
.........
      {
        "_index": "bank",
        "_id": "449",
        "_score": 4.1042743,
        "_source": {
          "account_number": 449,
          "balance": 41950,
          "firstname": "Barnett",
          "lastname": "Cantrell",
          "age": 39,
          "gender": "F",
          "address": "945 Bedell Lane",
          "employer": "Zentility",
          "email": "barnettcantrell@zentility.com",
          "city": "Swartzville",
          "state": "ND"
        }
      }
    ]
  }
}
```



##### 2.4.查询段落匹配

#如果我们希望查询的条件是 address字段中包含 "mill lane"，则可以使用`match_phrase`

```bash
GET /bank/_search
{
  "query": {
    "match_phrase": {"address": "mill lane"}
  }
}
```



#logs

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
      "value": 1,
      "relation": "eq"
    },
    "max_score": 9.507477,
    "hits": [
      {
        "_index": "bank",
        "_id": "136",
        "_score": 9.507477,
        "_source": {
          "account_number": 136,
          "balance": 45801,
          "firstname": "Winnie",
          "lastname": "Holland",
          "age": 38,
          "gender": "M",
          "address": "198 Mill Lane",
          "employer": "Neteria",
          "email": "winnieholland@neteria.com",
          "city": "Urie",
          "state": "IL"
        }
      }
    ]
  }
}
```





##### 2.5.多条件查询

#bool

#如果要构造更复杂的查询，可以使用`bool`查询来组合多个查询条件。

#例如，以下请求在bank索引中搜索40岁客户的帐户，但不包括居住在爱达荷州（ID）的任何人

```bash
GET /bank/_search
{
  "query": {
    "bool": {
      "must": [
        {"match": {"age": 40}}
        ],
      "must_not": [
        {"match": {"state": "ID"}}
        ]
    }
  }
}
```



#logs

```json
{
  "took": 3,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 43,
      "relation": "eq"
    },
    "max_score": 1,
    "hits": [
      {
        "_index": "bank",
        "_id": "474",
        "_score": 1,
        "_source": {
          "account_number": 474,
          "balance": 35896,
          "firstname": "Obrien",
          "lastname": "Walton",
          "age": 40,
          "gender": "F",
          "address": "192 Ide Court",
          "employer": "Suremax",
          "email": "obrienwalton@suremax.com",
          "city": "Crucible",
          "state": "UT"
        }
      },
      ............................
      {
        "_index": "bank",
        "_id": "177",
        "_score": 1,
        "_source": {
          "account_number": 177,
          "balance": 48972,
          "firstname": "Harris",
          "lastname": "Gross",
          "age": 40,
          "gender": "F",
          "address": "468 Suydam Street",
          "employer": "Kidstock",
          "email": "harrisgross@kidstock.com",
          "city": "Yettem",
          "state": "KY"
        }
      }
    ]
  }
}
```



###### 2.5.1.must与filter的区别

#`must`, `should`, `must_not` 和 `filter` 都是`bool`查询的子句

#`must`：文档 必须 匹配这些条件才能被包含进来，相当于sql中的 and

#`must_not`：文档 必须不 匹配这些条件才能被包含进来，相当于sql中的 not

#`should`：如果满足这些语句中的任意语句，将增加 _score ，否则，无任何影响。它们主要用于修正每个文档的相关性得分。相当于sql中的or

#`filter`：必须 匹配，但它以不评分、过滤模式来进行。这些语句对评分没有贡献，只是根据过滤标准来排除或包含文档。

#must和filter的区别

```
must：返回的文档必须满足must子句的条件，并且参与计算分值

filter：返回的文档必须满足filter子句的条件。但是跟Must不一样的是，不会计算分值， 并且可以使用缓存

must和filter是一样的。区别是场景不一样。如果结果需要算分就使用must，否则可以考虑使用filter，使查询更高效
```



```bash
GET /bank/_search 
{
  "query": {
    "bool": {
      "must": [
        {"match": {"state": "ND"}}  
      ],
      "filter": [
        {"term": {"age": "40"}},
        {"range": 
          {"balance": 
            {"gte": 20000,
             "lte": 30000
            }
          }
        }
      ]
    }
  }
}
```



#logs

```json
{
  "took": 3,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1,
      "relation": "eq"
    },
    "max_score": 3.7100816,
    "hits": [
      {
        "_index": "bank",
        "_id": "432",
        "_score": 3.7100816,
        "_source": {
          "account_number": 432,
          "balance": 28969,
          "firstname": "Preston",
          "lastname": "Ferguson",
          "age": 40,
          "gender": "F",
          "address": "239 Greenwood Avenue",
          "employer": "Bitendrex",
          "email": "prestonferguson@bitendrex.com",
          "city": "Idledale",
          "state": "ND"
        }
      }
    ]
  }
}
```



###### 2.5.2.term与match的区别

#term：代表完全匹配，也就是精确查询，搜索前不会再对搜索词进行分词解析，直接对搜索词进行查找

#match：代表模糊匹配，搜索前会对搜索词进行分词解析，然后按搜索词匹配查找

###### 2.5.3.text和keyword的区别

#text：查询时会进行分词解析

#keyword：keyword类型的词不会被分词器进行解析，直接作为整体进行查询



##### 2.6.聚合查询

#我们知道SQL中有group by，在ES中它叫Aggregation，即聚合运算

###### 2.6.1.简单聚合

#比如我们希望计算出account每个州的统计数量， 使用`aggs`关键字对`state`字段聚合，被聚合的字段无需对分词统计，所以使用`state.keyword`对整个字段统计



```bash
GET /bank/_search
{
  "size": 0,
  "aggs": {
    "group_by_state": {
      "terms": {
        "field": "state.keyword"
      }
    }
  }
}
```



#logs

```json
{
  "took": 9,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1000,
      "relation": "eq"
    },
    "max_score": null,
    "hits": []
  },
  "aggregations": {
    "group_by_state": {
      "doc_count_error_upper_bound": 0,
      "sum_other_doc_count": 743,
      "buckets": [
        {
          "key": "TX",
          "doc_count": 30
        },
        {
          "key": "MD",
          "doc_count": 28
        },
        {
          "key": "ID",
          "doc_count": 27
        },
        {
        .................
        {
          "key": "ND",
          "doc_count": 24
        }
      ]
    }
  }
}
```



#因为无需返回条件的具体数据, 所以设置size=0，返回hits为空

#`doc_count`表示bucket中每个州的数据条数

###### 2.6.2.嵌套聚合

#比如承接上个例子， 计算每个州的平均结余。涉及到的就是在对state分组的基础上，嵌套计算avg(balance)

```bash
GET /bank/_search
{
  "size": 0,
  "aggs": {
    "group_by_state": {
      "terms": {
        "field": "state.keyword"
      },
      "aggs": {
        "average_balance": {
          "avg": {
            "field": "balance"
          }
        }
      }
    }
  }
}
```



#logs

```json
{
  "took": 13,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1000,
      "relation": "eq"
    },
    "max_score": null,
    "hits": []
  },
  "aggregations": {
    "group_by_state": {
      "doc_count_error_upper_bound": 0,
      "sum_other_doc_count": 743,
      "buckets": [
        {
          "key": "TX",
          "doc_count": 30,
          "average_balance": {
            "value": 26073.3
          }
        },
        {
          "key": "MD",
          "doc_count": 28,
          "average_balance": {
            "value": 26161.535714285714
          }
        },
        ...............................
        {
          "key": "ND",
          "doc_count": 24,
          "average_balance": {
            "value": 26577.333333333332
          }
        }
      ]
    }
  }
}
```




###### 2.6.3.对聚合结果排序

#比如承接上个例子， 对嵌套计算出的avg(balance)，这里是average_balance，进行排序

```bash
GET /bank/_search
{
  "size": 0,
  "aggs": {
    "group_by_state": {
      "terms": {
        "field": "state.keyword",
        "order": {
          "average_balance": "desc"
        }
      },
      "aggs": {
        "average_balance": {
          "avg": {
            "field": "balance"
          }
        }
      }
    }
  }
}
```



#logs

```json
{
  "took": 24,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1000,
      "relation": "eq"
    },
    "max_score": null,
    "hits": []
  },
  "aggregations": {
    "group_by_state": {
      "doc_count_error_upper_bound": -1,
      "sum_other_doc_count": 827,
      "buckets": [
        {
          "key": "CO",
          "doc_count": 14,
          "average_balance": {
            "value": 32460.35714285714
          }
        },
        {
          "key": "NE",
          "doc_count": 16,
          "average_balance": {
            "value": 32041.5625
          }
        },
        {
          "key": "AZ",
          "doc_count": 14,
          "average_balance": {
            "value": 31634.785714285714
          }
        },
        {
          "key": "MT",
          "doc_count": 17,
          "average_balance": {
            "value": 31147.41176470588
          }
        },
        {
          "key": "VA",
          "doc_count": 16,
          "average_balance": {
            "value": 30600.0625
          }
        },
        {
          "key": "GA",
          "doc_count": 19,
          "average_balance": {
            "value": 30089
          }
        },
        {
          "key": "MA",
          "doc_count": 24,
          "average_balance": {
            "value": 29600.333333333332
          }
        },
        {
          "key": "IL",
          "doc_count": 22,
          "average_balance": {
            "value": 29489.727272727272
          }
        },
        {
          "key": "NM",
          "doc_count": 14,
          "average_balance": {
            "value": 28792.64285714286
          }
        },
        {
          "key": "LA",
          "doc_count": 17,
          "average_balance": {
            "value": 28791.823529411766
          }
        }
      ]
    }
  }
}
```




### 十一、es的web管理工具

#chrome插件 es-client
#chrome插件 elasticsearch-head

#本地web客户端ElasticView

```bash

# 拉取项目源代码
git clone https://github.com/1340691923/ElasticView.git
 
# 同步前端项目依赖
cd resources/vue && npm install
 
# 构建前端包
npm run build:prod
 
# 构建项目二进制程序
#CGO_ENABLED=0 GOOS=linux go build -ldflags '-w -s' -o ev cmd/ev/main.go

#windows cmder下

go build  -o ev.exe cmd/ev/main.go

#生成linux版本

set GOOS=linux

go build  -o ev-linux cmd/ev/main.go


#生成mac版本
 
set GOOS=darwin
 
go build  -o ev-mac cmd/ev/main.go
 
```

#本地执行程序后，默认端口8090，账户密码admin/admin

```url
http://127.0.0.1:8090
```

### 十二、500G大小json的导入
#### 1、通过split将文件分割成100M/份，然后循环导入

```bash
#!/bin/bash

# 定义变量
ES_HOST="es03:9200"
INDEX_NAME="cat"
BULK_SIZE=100M   # 每个小文件的大小，可以根据实际情况调整
SOURCE_FILE="/newdata/cat.json"
SPLIT_DIR="/newdata/split_files"
CONTENT_TYPE="application/json"

# 创建保存分割文件的目录
mkdir -p $SPLIT_DIR

# 1. 分割大文件为多个小文件
echo "Splitting large file into smaller chunks..."
split -b $BULK_SIZE $SOURCE_FILE $SPLIT_DIR/cat_split_

# 2. 批量导入到 Elasticsearch
echo "Starting bulk import into Elasticsearch..."

for file in $SPLIT_DIR/cat_split_*; do
  echo "Importing file: $file"
  curl -H "Content-Type: $CONTENT_TYPE" -XPOST "$ES_HOST/$INDEX_NAME/_bulk?pretty&refresh" --data-binary "@$file"
  
  # 检查导入结果，如果导入失败则退出循环
  if [ $? -ne 0 ]; then
    echo "Error occurred during import of file $file. Exiting..."
    exit 1
  fi
done

echo "Bulk import completed."

# 3. 删除临时文件
echo "Cleaning up temporary files..."
rm -rf $SPLIT_DIR

echo "All done!"

```

```
#脚本说明
#定义变量：

ES_HOST: Elasticsearch 集群的地址。
INDEX_NAME: 要导入数据的索引名称。
BULK_SIZE: 每次分割后的文件大小（可调整）。
SOURCE_FILE: 原始大文件的路径。
SPLIT_DIR: 用于存储分割文件的临时目录。
CONTENT_TYPE: HTTP 请求的内容类型。
分割文件：使用 split 命令将大文件分割为多个小文件。每个小文件的大小由 BULK_SIZE 控制。

批量导入：使用 curl 命令循环遍历每个分割后的文件，并将其批量导入到 Elasticsearch 集群中。通过 --data-binary 选项读取每个小文件并发送到 Elasticsearch。

检查导入结果：每次导入后检查 curl 的退出状态码。如果发生错误，脚本会立即退出并打印错误信息。

清理临时文件：导入完成后，删除所有分割的临时文件。
```



#### 2、通过调用API接口

#基于go

##### 2.1.linux-go

```
使用Golang语言结合Elasticsearch官方的Go客户端库，可以更高效地处理批量数据导入任务。下面是一个完整的Golang程序示例，它将大文件分割成小批次，并通过批量API将数据导入到Elasticsearch中。
根据提供的Elasticsearch集群地址和认证信息，以下是完整的Golang代码。这个程序将连接到指定的Elasticsearch集群，使用提供的账户和密码进行认证，并将大文件中的JSON数据批量导入到集群中。
```

```go
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/elastic/go-elasticsearch/v8"
	"github.com/elastic/go-elasticsearch/v8/esapi"
)

// Document represents a single JSON document structure
type Document map[string]interface{}

func main() {
	// Elasticsearch configuration
	es, err := elasticsearch.NewDefaultClient()
	if err != nil {
		log.Fatalf("Error creating the client: %s", err)
	}

	// File paths and settings
	sourceFile := "/newdata/cat.json"
	bulkSize := 10000 // Number of documents per batch
	indexName := "cat"

	// Open the source file
	file, err := os.Open(sourceFile)
	if err != nil {
		log.Fatalf("Error opening file: %s", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	batch := make([]string, 0, bulkSize)
	count := 0

	fmt.Println("Starting bulk import...")

	for scanner.Scan() {
		line := scanner.Text()
		batch = append(batch, line)

		// When the batch size is reached, process the batch
		if len(batch) >= bulkSize {
			err := processBatch(es, batch, indexName)
			if err != nil {
				log.Fatalf("Error importing batch: %s", err)
			}
			batch = batch[:0] // Clear the batch
			count++
			fmt.Printf("Processed batch %d\n", count)
		}
	}

	// Process any remaining documents
	if len(batch) > 0 {
		err := processBatch(es, batch, indexName)
		if err != nil {
			log.Fatalf("Error importing final batch: %s", err)
		}
		fmt.Printf("Processed final batch\n")
	}

	if err := scanner.Err(); err != nil {
		log.Fatalf("Error reading file: %s", err)
	}

	fmt.Println("Bulk import completed.")
}

// processBatch processes a batch of documents and sends them to Elasticsearch
func processBatch(es *elasticsearch.Client, batch []string, indexName string) error {
	var b strings.Builder

	for _, line := range batch {
		// Convert line to a map
		var doc Document
		if err := json.Unmarshal([]byte(line), &doc); err != nil {
			return fmt.Errorf("error unmarshalling line: %v", err)
		}

		// Convert map back to JSON
		data, err := json.Marshal(doc)
		if err != nil {
			return fmt.Errorf("error marshalling document: %v", err)
		}

		// Prepare bulk request
		meta := []byte(fmt.Sprintf(`{ "index" : { "_index" : "%s" } }%s`, indexName, "\n"))
		b.Write(meta)
		b.Write(data)
		b.WriteString("\n")
	}

	req := esapi.BulkRequest{
		Body: strings.NewReader(b.String()),
	}

	res, err := req.Do(context.Background(), es)
	if err != nil {
		return fmt.Errorf("bulk request failed: %v", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("bulk request error: %s", res.String())
	}

	return nil
}

```



```
#代码说明
#Elasticsearch配置：

使用 elasticsearch.NewDefaultClient() 创建一个Elasticsearch客户端。可以根据需要自定义Elasticsearch配置，例如认证信息或集群地址。
文件处理：

使用 bufio.Scanner 逐行读取大文件 cat.json。
批次大小设为 bulkSize（例如 10000 条文档），每当达到批次大小时，将文档批量发送到Elasticsearch。
批量处理函数 processBatch：

这个函数接收Elasticsearch客户端、文档批次和索引名称，将文档转换为Elasticsearch Bulk API 的格式，并发送到集群。
文档以 meta 和 data 组合的形式发送，meta 部分指明索引的相关信息，data 部分是文档内容。
错误处理：

如果批次处理过程中出现错误，程序会立即终止并报告错误信息。每次批次成功导入后会输出处理进度。
```



#升级

```go
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/elastic/go-elasticsearch/v8"
	"github.com/elastic/go-elasticsearch/v8/esapi"
)

// Document represents a single JSON document structure
type Document map[string]interface{}

func main() {
	// Elasticsearch configuration with basic authentication
	es, err := elasticsearch.NewClient(elasticsearch.Config{
		Addresses: []string{
			"https://222.24.203.42:9200",
		},
		Username: "elastic",
		Password: "elastic123",
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true, // Ignore SSL certificate errors (not recommended for production)
			},
		},
	})
	if err != nil {
		log.Fatalf("Error creating the client: %s", err)
	}

	// File paths and settings
	sourceFile := "/newdata/cat.json"
	bulkSize := 10000 // Number of documents per batch
	indexName := "cat"

	// Open the source file
	file, err := os.Open(sourceFile)
	if err != nil {
		log.Fatalf("Error opening file: %s", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	batch := make([]string, 0, bulkSize)
	count := 0

	fmt.Println("Starting bulk import...")

	for scanner.Scan() {
		line := scanner.Text()
		batch = append(batch, line)

		// When the batch size is reached, process the batch
		if len(batch) >= bulkSize {
			err := processBatch(es, batch, indexName)
			if err != nil {
				log.Fatalf("Error importing batch: %s", err)
			}
			batch = batch[:0] // Clear the batch
			count++
			fmt.Printf("Processed batch %d\n", count)
		}
	}

	// Process any remaining documents
	if len(batch) > 0 {
		err := processBatch(es, batch, indexName)
		if err != nil {
			log.Fatalf("Error importing final batch: %s", err)
		}
		fmt.Printf("Processed final batch\n")
	}

	if err := scanner.Err(); err != nil {
		log.Fatalf("Error reading file: %s", err)
	}

	fmt.Println("Bulk import completed.")
}

// processBatch processes a batch of documents and sends them to Elasticsearch
func processBatch(es *elasticsearch.Client, batch []string, indexName string) error {
	var b strings.Builder

	for _, line := range batch {
		// Convert line to a map
		var doc Document
		if err := json.Unmarshal([]byte(line), &doc); err != nil {
			return fmt.Errorf("error unmarshalling line: %v", err)
		}

		// Convert map back to JSON
		data, err := json.Marshal(doc)
		if err != nil {
			return fmt.Errorf("error marshalling document: %v", err)
		}

		// Prepare bulk request
		meta := []byte(fmt.Sprintf(`{ "index" : { "_index" : "%s" } }%s`, indexName, "\n"))
		b.Write(meta)
		b.Write(data)
		b.WriteString("\n")
	}

	req := esapi.BulkRequest{
		Body: strings.NewReader(b.String()),
	}

	res, err := req.Do(context.Background(), es)
	if err != nil {
		return fmt.Errorf("bulk request failed: %v", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("bulk request error: %s", res.String())
	}

	return nil
}

```





```
#代码说明
Elasticsearch配置：

使用 elasticsearch.NewClient() 创建了一个Elasticsearch客户端。
设置了 Addresses 来指定Elasticsearch集群的URL。
使用 Username 和 Password 来进行基本认证。
InsecureSkipVerify: true 使得客户端忽略SSL证书错误。这仅适用于测试环境或自签名证书场景，不建议在生产环境中使用。
文件处理：

通过 bufio.Scanner 逐行读取大文件 cat.json。
每批处理 bulkSize（设置为10000条文档），将文档批量发送到Elasticsearch。
批量处理函数 processBatch：

该函数将文档转换为Elasticsearch Bulk API 的格式，并发送到Elasticsearch集群。
批量导入是通过 esapi.BulkRequest 实现的，并通过 Do 方法发送请求。
错误处理：

如果在批次处理过程中出现错误，程序会立即终止并打印错误信息。每个批次成功导入后会输出处理进度。
```



```go
#运行程序
#确保已安装Go语言并配置环境。
#初始化项目并安装Elasticsearch Go客户端：
go mod init es_bulk_import
go get github.com/elastic/go-elasticsearch/v8

#将代码保存为 main.go。
#通过以下命令编译并运行程序：

go run main.go
#此程序将大文件中的数据逐行读取并分批次导入到指定的Elasticsearch集群，确保有效利用Elasticsearch的批量导入功能。
```



##### 2.2.windows-go

```
要在Windows环境中执行上述Golang代码，并处理位于 c:\work\cat.json 的文件，你只需要对文件路径做一些小调整。Windows使用反斜杠（\）作为路径分隔符，但在Go代码中，需要将反斜杠转义为双反斜杠（\\）。此外，其他部分的代码逻辑保持不变。
```



```go
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"crypto/tls"
	"net/http"

	"github.com/elastic/go-elasticsearch/v8"
	"github.com/elastic/go-elasticsearch/v8/esapi"
)

// Document represents a single JSON document structure
type Document map[string]interface{}

func main() {
	// Elasticsearch configuration with basic authentication
	es, err := elasticsearch.NewClient(elasticsearch.Config{
		Addresses: []string{
			"https://222.24.203.42:9200",
			"https://es02:9200",
			"https://es03:9200",
		},
		Username: "elastic",
		Password: "elastic123",
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true, // Ignore SSL certificate errors (not recommended for production)
			},
		},
	})
	if err != nil {
		log.Fatalf("Error creating the client: %s", err)
	}

	// File paths and settings
	sourceFile := `c:\work\cat.json` // Windows file path
	bulkSize := 10000                // Number of documents per batch
	indexName := "cat"

	// Open the source file
	file, err := os.Open(sourceFile)
	if err != nil {
		log.Fatalf("Error opening file: %s", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	batch := make([]string, 0, bulkSize)
	count := 0

	fmt.Println("Starting bulk import...")

	for scanner.Scan() {
		line := scanner.Text()
		batch = append(batch, line)

		// When the batch size is reached, process the batch
		if len(batch) >= bulkSize {
			err := processBatch(es, batch, indexName)
			if err != nil {
				log.Fatalf("Error importing batch: %s", err)
			}
			batch = batch[:0] // Clear the batch
			count++
			fmt.Printf("Processed batch %d\n", count)
		}
	}

	// Process any remaining documents
	if len(batch) > 0 {
		err := processBatch(es, batch, indexName)
		if err != nil {
			log.Fatalf("Error importing final batch: %s", err)
		}
		fmt.Printf("Processed final batch\n")
	}

	if err := scanner.Err(); err != nil {
		log.Fatalf("Error reading file: %s", err)
	}

	fmt.Println("Bulk import completed.")
}

// processBatch processes a batch of documents and sends them to Elasticsearch
func processBatch(es *elasticsearch.Client, batch []string, indexName string) error {
	var b strings.Builder

	for _, line := range batch {
		// Convert line to a map
		var doc Document
		if err := json.Unmarshal([]byte(line), &doc); err != nil {
			return fmt.Errorf("error unmarshalling line: %v", err)
		}

		// Convert map back to JSON
		data, err := json.Marshal(doc)
		if err != nil {
			return fmt.Errorf("error marshalling document: %v", err)
		}

		// Prepare bulk request
		meta := []byte(fmt.Sprintf(`{ "index" : { "_index" : "%s" } }%s`, indexName, "\n"))
		b.Write(meta)
		b.Write(data)
		b.WriteString("\n")
	}

	req := esapi.BulkRequest{
		Body: strings.NewReader(b.String()),
	}

	res, err := req.Do(context.Background(), es)
	if err != nil {
		return fmt.Errorf("bulk request failed: %v", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("bulk request error: %s", res.String())
	}

	return nil
}

```





```
关键调整
文件路径：

在Windows中，文件路径通常使用反斜杠（\），但在Golang中，反斜杠需要转义成双反斜杠（\\）。
在代码中，sourceFile := c:\work\cat.json 使用了反引号（ ` ``）来定义原始字符串，以避免反斜杠转义问题。这种方式更方便处理Windows路径。
TLS配置：

InsecureSkipVerify: true 是为了忽略SSL证书验证错误，这在自签名证书或测试环境中是常见的做法。如果在生产环境中使用，请确保SSL证书是正确配置的，并移除这个配置。
其他代码保持不变：

除了路径格式的修改，其余部分的代码与Linux版本相同，逻辑也完全一致。

```



```bash
#运行程序
#确保在Windows系统中已安装Go语言并配置好环境变量。
#打开命令提示符或PowerShell，导航到包含代码文件的目录。
#初始化项目并安装Elasticsearch Go客户端：
#go env -w GOPROXY=https://goproxy.cn,direct

go mod init es_bulk_import
go get github.com/elastic/go-elasticsearch/v8

#将代码保存为 main.go。
#在命令行中运行以下命令：

go run main.go

#这个程序将在Windows环境中读取指定位置的文件，并通过Elasticsearch Bulk API 将数据批量导入到指定的Elasticsearch集群中。
```



##### 2.3.windows-go 基于证书校验

```
要完善上述Golang代码以支持多个Elasticsearch节点以及SSL证书认证，您需要以下几个步骤：

配置多个Elasticsearch节点的连接：指定多个节点地址。
加载SSL证书：使用自定义的证书加载方式来处理客户端认证。
CA证书加载：

使用 ioutil.ReadFile 读取CA证书文件 elastic-stack-ca.p12。不过 .p12 格式文件一般需要密码解锁并处理，因此通常建议使用 .pem 格式的证书。你需要首先将 .p12 转换为 .pem。转换命令如下：

openssl pkcs12 -in elastic-stack-ca.p12 -out elastic-stack-ca.pem -clcerts -nokeys
使用 x509.NewCertPool 创建一个新的证书池并将CA证书加入其中。

根据openssl pkcs12 -in elastic-stack-ca.p12 -out elastic-stack-ca.pem -clcerts -nokeys
这条命令生成了elastic-stack-ca.pem
同时将elastic-stack-ca.pem、elastic-stack-ca.p12、elastic-certificates.p12、http.p12四个证书放到了c:\work\certs

#elastic-stack-ca.pem和Kibana的es证书elasticsearch-ca.pem内容一致

配置认证：基于提供的用户名和密码进行认证。
下面是基于您提供的 elasticsearch.yml 配置文件信息的完整Golang代码示例：
```



```go
package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/elastic/go-elasticsearch/v8"
	"github.com/elastic/go-elasticsearch/v8/esapi"
)

// Document represents a single JSON document structure
type Document map[string]interface{}

func main() {
	// Load CA certificate
	caCertPath := `c:\work\certs\elastic-stack-ca.pem`

	// Read the CA certificate
	caCert, err := ioutil.ReadFile(caCertPath)
	if err != nil {
		log.Fatalf("Failed to read CA certificate: %v", err)
	}

	// Create a CA certificate pool and add the CA certificate
	caCertPool := x509.NewCertPool()
	if ok := caCertPool.AppendCertsFromPEM(caCert); !ok {
		log.Fatalf("Failed to add CA certificate to pool")
	}

	// Configure TLS settings
	tlsConfig := &tls.Config{
		RootCAs: caCertPool,
	}

	// Elasticsearch configuration with multiple nodes and TLS settings
	es, err := elasticsearch.NewClient(elasticsearch.Config{
		Addresses: []string{
			"https://222.24.203.42:9200",
			"https://es02:9200",
			"https://es03:9200",
		},
		Username: "elastic",
		Password: "elastic123",
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	})
	if err != nil {
		log.Fatalf("Error creating the Elasticsearch client: %s", err)
	}

	// File paths and settings
	sourceFile := `c:\work\cat.json` // Windows file path
	bulkSize := 10000                // Number of documents per batch
	indexName := "cat"

	// Open the source file
	file, err := os.Open(sourceFile)
	if err != nil {
		log.Fatalf("Error opening file: %s", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	batch := make([]string, 0, bulkSize)
	count := 0

	fmt.Println("Starting bulk import...")

	for scanner.Scan() {
		line := scanner.Text()
		batch = append(batch, line)

		// When the batch size is reached, process the batch
		if len(batch) >= bulkSize {
			err := processBatch(es, batch, indexName)
			if err != nil {
				log.Fatalf("Error importing batch: %s", err)
			}
			batch = batch[:0] // Clear the batch
			count++
			fmt.Printf("Processed batch %d\n", count)
		}
	}

	// Process any remaining documents
	if len(batch) > 0 {
		err := processBatch(es, batch, indexName)
		if err != nil {
			log.Fatalf("Error importing final batch: %s", err)
		}
		fmt.Printf("Processed final batch\n")
	}

	if err := scanner.Err(); err != nil {
		log.Fatalf("Error reading file: %s", err)
	}

	fmt.Println("Bulk import completed.")
}

// processBatch processes a batch of documents and sends them to Elasticsearch
func processBatch(es *elasticsearch.Client, batch []string, indexName string) error {
	var b strings.Builder

	for _, line := range batch {
		// Convert line to a map
		var doc Document
		if err := json.Unmarshal([]byte(line), &doc); err != nil {
			return fmt.Errorf("error unmarshalling line: %v", err)
		}

		// Convert map back to JSON
		data, err := json.Marshal(doc)
		if err != nil {
			return fmt.Errorf("error marshalling document: %v", err)
		}

		// Prepare bulk request
		meta := []byte(fmt.Sprintf(`{ "index" : { "_index" : "%s" } }%s`, indexName, "\n"))
		b.Write(meta)
		b.Write(data)
		b.WriteString("\n")
	}

	req := esapi.BulkRequest{
		Body: strings.NewReader(b.String()),
	}

	res, err := req.Do(context.Background(), es)
	if err != nil {
		return fmt.Errorf("bulk request failed: %v", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("bulk request error: %s", res.String())
	}

	return nil
}

```





```
关键点总结
CA证书加载：

使用 ioutil.ReadFile 读取CA证书文件 elastic-stack-ca.pem。
使用 x509.NewCertPool() 创建一个新的证书池，并通过 AppendCertsFromPEM() 方法将证书添加到池中。
TLS配置：

使用 RootCAs 配置客户端信任的CA证书，这样可以确保与Elasticsearch的SSL连接是安全的。
多节点配置：

代码中配置了多个Elasticsearch节点地址，客户端会自动选择可用的节点并进行负载均衡。
运行程序
确保所有证书文件（特别是 .pem 文件）已正确生成并放置在 c:\work\certs 目录下。
打开命令提示符或PowerShell，导航到包含代码文件的目录。
运行Go程序：
go run main.go

此代码将从本地读取 cat.json 文件，并使用指定的SSL证书连接到Elasticsearch集群，将数据批量导入到指定的索引中。
```







### 十三、ES的优化

#### 1、配置参数

1.1.系统配置参数查询

```bash
GET _cluster/settings?include_defaults&flat_settings
```



1.2.系统配置参数的优化

1.2.1."http.max_content_length": "100mb"

默认此值时，如果批量导入json数据时，超过100mb，会报错：

```log
Starting bulk import...
2024/08/17 14:35:52 Error importing batch: bulk request error: [413 Request Entity Too Large]
exit status 1
```



修改到200mb后，重启es，重新导入



### 十四、ES集群的迁移
