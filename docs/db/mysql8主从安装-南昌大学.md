此文档提供安装mysql8(最新版8.0.39)主从高可用模式的安装

****

#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小，mysql安装到最大分区里
#20240821补充OS优化部分，安装版本为8.0.39

## 服务器资源

#建议

```
vm: 32核/64G 

OS: Anolis OS 7.9(3.10.0-1160.an7.x86_64)

磁盘LVM管理，500G，/data为最大分区
```

## 部署过程

### 一、系统优化

#### 0、将/home分区空间回收，加入/分区

#当前/home分区最大

```bash
[root@localhost ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sr0          11:0    1   1.2G  0 rom
vda         252:0    0   500G  0 disk
├─vda1      252:1    0     1G  0 part /boot
└─vda2      252:2    0   499G  0 part
  ├─ao-root 253:0    0    50G  0 lvm  /
  ├─ao-swap 253:1    0  15.7G  0 lvm  [SWAP]
  └─ao-home 253:2    0 433.3G  0 lvm  /home
[root@localhost ~]# df -h
文件系统             容量  已用  可用 已用% 挂载点
devtmpfs              32G     0   32G    0% /dev
tmpfs                 32G     0   32G    0% /dev/shm
tmpfs                 32G  8.8M   32G    1% /run
tmpfs                 32G     0   32G    0% /sys/fs/cgroup
/dev/mapper/ao-root   50G  2.9G   48G    6% /
/dev/mapper/ao-home  434G   33M  434G    1% /home
/dev/vda1           1014M  175M  840M   18% /boot
tmpfs                6.3G     0  6.3G    0% /run/user/0
tmpfs                 60M     0   60M    0% /var/log/rtlog
```



#回收/home分区，添加到/分区

```bash
df -h

umount /home

lvs
pvs
vgs

lvremove /dev/mapper/ao-home

vgs

lvextend -l +100%FREE /dev/mapper/ao-root

vgs
lvs

#xfs_growfs /dev/mapper/ao-root
#报错：xfs_growfs: /dev/mapper/ao-root is not a mounted XFS filesystem

xfs_growfs /

lvs

vi /etc/fstab
cat /etc/fstab

df -h

mkdir /data
```



#logs

```bash
[root@localhost ~]# umount /home
[root@localhost ~]# pvs
  PV         VG Fmt  Attr PSize    PFree
  /dev/vda2  ao lvm2 a--  <499.00g 4.00m
[root@localhost ~]# lvs
  LV   VG Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  home ao -wi-a----- 433.30g
  root ao -wi-ao----  50.00g
  swap ao -wi-ao---- <15.69g
[root@localhost ~]# vgs
  VG #PV #LV #SN Attr   VSize    VFree
  ao   1   3   0 wz--n- <499.00g 4.00m
[root@localhost ~]# lvremove /dev/mapper/ao-home
Do you really want to remove active logical volume ao/home? [y/n]: y
  Logical volume "home" successfully removed
[root@localhost ~]# vgs
  VG #PV #LV #SN Attr   VSize    VFree
  ao   1   2   0 wz--n- <499.00g <433.31g
[root@localhost ~]# lvextend -l +100%FREE /dev/mapper/ao-root
  Size of logical volume ao/root changed from 50.00 GiB (12800 extents) to <483.31 GiB (123727 extents).
  Logical volume ao/root successfully resized.
[root@localhost ~]# vgs
  VG #PV #LV #SN Attr   VSize    VFree
  ao   1   2   0 wz--n- <499.00g    0
[root@localhost ~]# lvs
  LV   VG Attr       LSize    Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  root ao -wi-ao---- <483.31g
  swap ao -wi-ao----  <15.69g
[root@localhost ~]# xfs_growfs /dev/mapper/ao-root
xfs_growfs: /dev/mapper/ao-root is not a mounted XFS filesystem
[root@localhost ~]# cat /etc/fstab

#
# /etc/fstab
# Created by anaconda on Wed Aug 21 02:32:12 2024
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/ao-root     /                       xfs     defaults        0 0
UUID=6349a9fd-b175-4645-8182-7b483fca9e09 /boot                   xfs     defaults        0 0
/dev/mapper/ao-home     /home                   xfs     defaults        0 0
/dev/mapper/ao-swap     swap                    swap    defaults        0 0


[root@localhost ~]# xfs_growfs -h
xfs_growfs：无效选项 -- h
Usage: xfs_growfs [options] mountpoint

Options:
        -d          grow data/metadata section
        -l          grow log section
        -r          grow realtime section
        -n          don't change anything, just show geometry
        -i          convert log from external to internal format
        -t          alternate location for mount table (/etc/mtab)
        -x          convert log from internal to external format
        -D size     grow data/metadata section to size blks
        -L size     grow/shrink log section to size blks
        -R size     grow realtime section to size blks
        -e size     set realtime extent size to size blks
        -m imaxpct  set inode max percent to imaxpct
        -V          print version information
        
        
[root@localhost ~]# xfs_growfs /
meta-data=/dev/mapper/ao-root    isize=512    agcount=4, agsize=3276800 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=0
data     =                       bsize=4096   blocks=13107200, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=6400, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 13107200 to 126696448

[root@localhost ~]# df -h
文件系统             容量  已用  可用 已用% 挂载点
devtmpfs              32G     0   32G    0% /dev
tmpfs                 32G     0   32G    0% /dev/shm
tmpfs                 32G  8.8M   32G    1% /run
tmpfs                 32G     0   32G    0% /sys/fs/cgroup
/dev/mapper/ao-root  484G  2.9G  481G    1% /
/dev/vda1           1014M  175M  840M   18% /boot
tmpfs                6.3G     0  6.3G    0% /run/user/0
tmpfs                 60M     0   60M    0% /var/log/rtlog
[root@localhost ~]# vi /etc/fstab
[root@localhost ~]# cat /etc/fstab

#
# /etc/fstab
# Created by anaconda on Wed Aug 21 02:32:12 2024
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/ao-root     /                       xfs     defaults        0 0
UUID=6349a9fd-b175-4645-8182-7b483fca9e09 /boot                   xfs     defaults        0 0
#/dev/mapper/ao-home     /home                   xfs     defaults        0 0
/dev/mapper/ao-swap     swap                    swap    defaults        0 0

[root@mysql01 ~]# mkdir /data
```



#### 1、Hostname修改

#hostname命名建议规范，以实际IP为准

```bash
cat >> /etc/hosts <<EOF
222.204.70.110 mysql01
222.204.70.111 mysql02
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
        Machine ID: 4297f39ad4274e4daac0d4ad8b649309
           Boot ID: 26507a91dc6c4ccd86b0b3102a2de3fd
    Virtualization: kvm
  Operating System: Anolis OS 7.9
            Kernel: Linux 3.10.0-1160.an7.x86_64
      Architecture: x86-64
[root@mysql01 ~]#

[root@mysql01 ~]# cat >> /etc/hosts <<EOF
222.204.70.110 mysql01
222.204.70.111 mysql02
EOF

[root@mysql01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
222.204.70.110 mysql01
222.204.70.111 mysql02

[root@mysql01 ~]# ping mysql01 -c 1
PING mysql01 (222.204.70.110) 56(84) bytes of data.
64 bytes from mysql01 (222.204.70.110): icmp_seq=1 ttl=64 time=0.065 ms

--- mysql01 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.065/0.065/0.065/0.000 ms
[root@mysql01 ~]# ping mysql02 -c 1
PING mysql02 (222.204.70.111) 56(84) bytes of data.
64 bytes from mysql02 (222.204.70.111): icmp_seq=1 ttl=64 time=0.619 ms

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

systemctl status firewalld

setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

getenforce
cat /etc/selinux/config

```

#### 3、修改源文件

```bash
#oracle linux server直接使用自己的yum源，此处不做修改
#Anolis OS 直接使用自己的yum源，此处不做修改

[root@mysql01 ~]# cat /etc/anolis-release
Anolis OS release 7.9

[root@mysql01 ~]# ls /etc/yum.repos.d/
AnolisOS-Debuginfo.repo  AnolisOS-os.repo    AnolisOS-Source.repo
AnolisOS-extras.repo     AnolisOS-Plus.repo  AnolisOS-updates.repo
[root@mysql01 ~]# cat /etc/yum.repos.d/AnolisOS-os.repo
[os]
name=AnolisOS-7.9 - os
baseurl=http://mirrors.openanolis.cn/anolis/7.9/os/$basearch/os
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ANOLIS
gpgcheck=1
[root@mysql01 ~]#


#centos7.9
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
systemctl enable ntpd

#ubuntu启动
systemctl start ntp
system enable ntp

vi /etc/ntp.conf
#注释下面4行
#server 0.centos.pool.ntp.org iburst
#server 1.centos.pool.ntp.org iburst
#server 2.centos.pool.ntp.org iburst
#server 3.centos.pool.ntp.org iburst

#学校如果有ntp服务器
#centos7.9配置
server times.neuq.edu.cn iburst
#ubuntu22.04
pool times.neuq.edu.cn iburst

#学校如果没有ntp服务器替换成中国时间服务器
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
cp /etc/sysctl.conf /etc/sysctl.conf.old

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
net.core.rmem_default=16777216
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
" > /etc/sysctl.conf

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
*            soft    stack           90000
*            hard    stack           90000
*            soft    memlock         unlimited
*            hard    memlock         unlimited

EOF


cat /etc/security/limits.d/20-nproc.conf

cat /etc/security/limits.conf

#重新登陆后
ulimit -a

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
root            soft    stack           90000
root            hard    stack           90000
root            soft    memlock         unlimited
root            hard    memlock         unlimited

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

#centos7.9
#mysql 8.4.x
wget https://dev.mysql.com/get/mysql84-community-release-el7-1.noarch.rpm

#8.0.39
wget https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm

yum localinstall -y mysql80-community-release-el7-11.noarch.rpm

yum search mysql-community-server
yum list mysql-community-server.x86_64  --showduplicates | sort -r
yum list mysql-community-client-plugins.x86_64  --showduplicates | sort -r

yum install -y mysql-community-server

#指定某版本
yum install -y mysql-community-{server,client,client-plugins,icu-data-files,common,libs,libs-compat}-8.0.20-1.el7
```

#如果在线安装时报错

```bash
[root@NFS mysql]# yum list mysql-community-client-plugins.x86_64  --showduplicates | sort -r|grep 8.0.37
mysql-community-client-plugins.x86_64       8.0.37-1.el7       mysql80-community
[root@NFS mysql]# yum install -y mysql-community-server
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: mirrors.jlu.edu.cn
 * extras: mirrors.jlu.edu.cn
 * updates: mirrors.jlu.edu.cn
Resolving Dependencies
--> Running transaction check
---> Package mysql-community-server.x86_64 0:8.0.37-1.el7 will be installed
--> Processing Dependency: mysql-community-common(x86-64) = 8.0.37-1.el7 for package: mysql-community-server-8.0.37-1.el7.x86_64
--> Processing Dependency: mysql-community-icu-data-files = 8.0.37-1.el7 for package: mysql-community-server-8.0.37-1.el7.x86_64
--> Processing Dependency: mysql-community-client(x86-64) >= 8.0.11 for package: mysql-community-server-8.0.37-1.el7.x86_64
--> Processing Dependency: net-tools for package: mysql-community-server-8.0.37-1.el7.x86_64
--> Running transaction check
---> Package mysql-community-client.x86_64 0:8.0.37-1.el7 will be installed
--> Processing Dependency: mysql-community-client-plugins = 8.0.37-1.el7 for package: mysql-community-client-8.0.37-1.el7.x86_64
--> Processing Dependency: mysql-community-libs(x86-64) >= 8.0.11 for package: mysql-community-client-8.0.37-1.el7.x86_64
---> Package mysql-community-common.x86_64 0:8.0.37-1.el7 will be installed
---> Package mysql-community-icu-data-files.x86_64 0:8.0.37-1.el7 will be installed
---> Package net-tools.x86_64 0:2.0-0.25.20131004git.el7 will be installed
--> Running transaction check
---> Package mysql-community-client-plugins.x86_64 0:8.0.37-1.el7 will be installed
---> Package mysql-community-libs.x86_64 0:8.0.37-1.el7 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

===============================================================================================================================
 Package                                 Arch            Version                              Repository                  Size
===============================================================================================================================
Installing:
 mysql-community-server                  x86_64          8.0.37-1.el7                         mysql80-community           65 M
Installing for dependencies:
 mysql-community-client                  x86_64          8.0.37-1.el7                         mysql80-community           16 M
 mysql-community-client-plugins          x86_64          8.0.37-1.el7                         mysql80-community          3.5 M
 mysql-community-common                  x86_64          8.0.37-1.el7                         mysql80-community          666 k
 mysql-community-icu-data-files          x86_64          8.0.37-1.el7                         mysql80-community          2.2 M
 mysql-community-libs                    x86_64          8.0.37-1.el7                         mysql80-community          1.5 M
 net-tools                               x86_64          2.0-0.25.20131004git.el7             base                       306 k

Transaction Summary
===============================================================================================================================
Install  1 Package (+6 Dependent packages)

Total size: 89 M
Total download size: 3.5 M
Installed size: 417 M
Downloading packages:
Delta RPMs disabled because /usr/bin/applydeltarpm not installed.
mysql-community-client-plugins FAILED
http://repo.mysql.com/yum/mysql-8.0-community/el/7/x86_64/mysql-community-client-plugins-8.0.37-1.el7.x86_64.rpm: [Errno 14] curl#56 - "Recv failure: Connection reset by peer"
Trying other mirror.


Error downloading packages:
  mysql-community-client-plugins-8.0.37-1.el7.x86_64: [Errno 256] No more mirrors to try.


[root@NFS mysql]# yum list mysql-community-client-plugins.x86_64  --showduplicates | sort -r|grep 8.0.37
mysql-community-client-plugins.x86_64       8.0.37-1.el7       mysql80-community
```

#解决办法

```bash
wget http://repo.mysql.com/yum/mysql-8.0-community/el/7/x86_64/mysql-community-client-plugins-8.0.37-1.el7.x86_64.rpm

yum localinstall -y mysql-community-client-plugins-8.0.37-1.el7.x86_64.rpm

yum install -y mysql-community-server
```





#### 3、优化mysql---mysql01和mysql02有细微差别

#检查my.cnf

```bash
mysqld --defaults-file=/etc/my.cnf  --validate-config --log-error-verbosity=2
```

#logs

```bash
#启动前

[root@mysql01 ~]# mysqld --defaults-file=/etc/my.cnf  --validate-config --log-error-verbosity=2
2024-08-21T12:11:55.450283+08:00 0 [Warning] [MY-011070] [Server] 'binlog_format' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450361+08:00 0 [Warning] [MY-011069] [Server] The syntax '--master-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450366+08:00 0 [Warning] [MY-011069] [Server] The syntax '--relay-log-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450375+08:00 0 [Warning] [MY-011070] [Server] '--sync-relay-log-info' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450384+08:00 0 [Warning] [MY-011069] [Server] The syntax '--replica-parallel-type' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450471+08:00 0 [Warning] [MY-010091] [Server] Can't create test file /data/mysql/mysqld_tmp_file_case_insensitive_test.lower-test
[root@mysql01 ~]#

#启动后
[root@mysql01 data]# mysqld --defaults-file=/etc/my.cnf  --validate-config --log-error-verbosity=2
2024-08-21T12:16:21.793327+08:00 0 [Warning] [MY-011070] [Server] 'binlog_format' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793404+08:00 0 [Warning] [MY-011069] [Server] The syntax '--master-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793410+08:00 0 [Warning] [MY-011069] [Server] The syntax '--relay-log-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793419+08:00 0 [Warning] [MY-011070] [Server] '--sync-relay-log-info' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793428+08:00 0 [Warning] [MY-011069] [Server] The syntax '--replica-parallel-type' is deprecated and will be removed in a future release.
[root@mysql01 data]#


```



##### 1) mysql01---/etc/my.cnf

```bash
#cp /etc/my.cnf /etc/my.cnf.bak

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
server_id = 110
#server_id = 111
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


#内部临时表
#internal_tmp_mem_storage_engine = MEMORY
#internal_tmp_mem_storage_engine = TempTable

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
#binlog_expire_logs_seconds = 604800
#expire_logs_days = 180
binlog_expire_logs_seconds = 15552000
#binlog_ignore_db = testdb01
#binlog_ignore_db = testdb02
#binlog_do_db = testdb03
#binlog_do_db = testdb04

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
log_queries_not_using_indexes = 0
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
#replica_skip_errors = 1032
replica_skip_errors = 1032,1062,1053,1146
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
#32G
#innodb_buffer_pool_size = 16384M
#64G
innodb_buffer_pool_size = 32768M
#2个G一个instance,一般小于32G配置为4,大于32G配置为8
innodb_buffer_pool_instances = 8
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
server_id = 110
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
binlog_expire_logs_seconds = 15552000
binlog_transaction_compression = on
binlog_transaction_compression_level_zstd = 3
slow_query_log = 1
long_query_time = 15
slow_query_log_file = slow.log
log_queries_not_using_indexes = 0
log_throttle_queries_not_using_indexes = 60
log_timestamps = SYSTEM
log_error = error.log
log_error_verbosity = 3
replica_skip_errors = 1032,1062,1053,1146
log_error_suppression_list = 'MY-010914,MY-013360,MY-013730,MY-010584,MY-010559'
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
innodb_buffer_pool_size = 32768M
innodb_buffer_pool_instances = 8
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
#server_id = 110
server_id = 111
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

#内部临时表
#internal_tmp_mem_storage_engine = MEMORY
#internal_tmp_mem_storage_engine = TempTable

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
#binlog_expire_logs_seconds = 604800
#expire_logs_days = 180
binlog_expire_logs_seconds = 15552000
#binlog_ignore_db = testdb01
#binlog_ignore_db = testdb02
#binlog_do_db = testdb03
#binlog_do_db = testdb04

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
log_queries_not_using_indexes = 0
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
#replica_skip_errors = 1032
replica_skip_errors = 1032,1062,1053,1146
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
innodb_buffer_pool_size = 32768M
#2个G一个instance,一般小于32G配置为4,大于32G配置为8
innodb_buffer_pool_instances = 8
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
server_id = 111
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
binlog_expire_logs_seconds = 15552000
binlog_transaction_compression = on
binlog_transaction_compression_level_zstd = 3
slow_query_log = 1
long_query_time = 15
slow_query_log_file = slow.log
log_queries_not_using_indexes = 0
log_throttle_queries_not_using_indexes = 60
log_timestamps = SYSTEM
log_error = error.log
log_error_verbosity = 3
replica_skip_errors = 1032,1062,1053,1146
log_error_suppression_list = 'MY-010914,MY-013360,MY-013730,MY-010584,MY-010559'
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
innodb_buffer_pool_size = 32768M
innodb_buffer_pool_instances = 8
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
create user 'repl'@'222.204.70.%' identified with mysql_native_password by 'Repl123!@#2024';
grant replication slave on *.* to 'repl'@'222.204.70.%';

show grants for 'repl'@'222.204.70.%';

SET @@GLOBAL.read_only = ON;
flush tables with read lock; 
```

#### 2、同步现有数据

#如果主节点已经有大量数据，需要mysqldump出来后，scp到从节点，导入后，再配置主从模式

#备份数据库，压缩后拷贝到从库

#主库执行

```bash
#/usr/bin/mysqldump -uroot -pMysql2023\!\@\#Root --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > 20231102.sql

/usr/bin/mysqldump -uroot -pMysql2023\!\@\#Root --quick --events --all-databases --source-data=2 --single-transaction --set-gtid-purged=OFF > 20231102.sql

/usr/bin/tar -zcvf 20231102.sql.tar.gz 20231102.sql

 scp 20231102.sql.tar.gz 222.204.70.110:/root/
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
#SET @@GLOBAL.read_only = ON;

CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.204.70.110',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2024',SOURCE_AUTO_POSITION = 1;

show warnings;

SHOW REPLICA STATUS \G;

start replica;

SHOW REPLICA STATUS \G;

#SET @@GLOBAL.read_only = OFF;
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
#主库

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
2023-11-02T10:43:19.953661+08:00 47 [System] [MY-014002] [Repl] Replica receiver thread for channel '': connected to source 'repl@222.204.70.110:3306' with server_uuid=6cfaa641-7926-11ee-bb23-fefcfe25467b, server_id=114. Starting GTID-based replication.

```



#主库

```bash
tail -f /data/mysql/error.log

2023-11-02T10:43:19.897307+08:00 12 [Warning] [MY-013360] [Server] Plugin mysql_native_password reported: ''mysql_native_password' is deprecated and will be removed in a future release. Please use caching_sha2_password instead'
2023-11-02T10:43:19.956046+08:00 12 [Note] [MY-010462] [Repl] Start binlog_dump to source_thread_id(12) replica_server(115), pos(, 4)

```

#主库logs

```bash

[root@mysql01 mysql]# tail -f error.log
2024-08-21T12:16:03.112680+08:00 0 [Note] [MY-011243] [Server] Plugin mysqlx reported: 'Using OpenSSL for TLS connections'
2024-08-21T12:16:03.112851+08:00 0 [System] [MY-010931] [Server] /usr/sbin/mysqld: ready for connections. Version: '8.0.39'  socket: '/data/mysql/mysql.sock'  port: 3306  MySQL Community Server - GPL.
2024-08-21T12:16:03.112865+08:00 0 [System] [MY-013292] [Server] Admin interface ready for connections, address: '127.0.0.1'  port: 33062
2024-08-21T12:16:03.112859+08:00 0 [System] [MY-011323] [Server] X Plugin ready for connections. Bind-address: '::' port: 33060, socket: /var/run/mysqld/mysqlx.sock
2024-08-21T12:24:33.377077+08:00 9 [Warning] [MY-011234] [Server] Effective value of validate_password_length is changed. New value is 4
2024-08-21T14:53:06.704459+08:00 10 [Note] [MY-010462] [Repl] Start binlog_dump to source_thread_id(10) replica_server(111), pos(, 4)
2024-08-21T15:04:09.102529+08:00 11 [Note] [MY-010014] [Repl] While initializing dump thread for replica with UUID <0f76fa28-5f74-11ef-be67-fefcfe4ed56d>, found a zombie dump thread with the same UUID. Source is killing the zombie dump thread(10).
2024-08-21T15:04:09.102682+08:00 11 [Note] [MY-010462] [Repl] Start binlog_dump to source_thread_id(11) replica_server(111), pos(, 4)
2024-08-21T15:06:08.870261+08:00 12 [Note] [MY-010014] [Repl] While initializing dump thread for replica with UUID <0f76fa28-5f74-11ef-be67-fefcfe4ed56d>, found a zombie dump thread with the same UUID. Source is killing the zombie dump thread(11).
2024-08-21T15:06:08.870411+08:00 12 [Note] [MY-010462] [Repl] Start binlog_dump to source_thread_id(12) replica_server(111), pos(, 4)

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

root@localhost:mysql.sock [testdb]>  SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000002
          Read_Source_Log_Pos: 3238
               Relay_Log_File: relay-bin.000004
                Relay_Log_Pos: 2012
        Relay_Source_Log_File: mysql-bin.000002
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
          Exec_Source_Log_Pos: 3238
              Relay_Log_Space: 2519
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
             Source_Server_Id: 110
                  Source_UUID: 0cb2951d-5f74-11ef-ae17-fefcfe1fc29a
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
           Retrieved_Gtid_Set: 0cb2951d-5f74-11ef-ae17-fefcfe1fc29a:1-11
            Executed_Gtid_Set: 0cb2951d-5f74-11ef-ae17-fefcfe1fc29a:1-11,
0f76fa28-5f74-11ef-be67-fefcfe4ed56d:1-5
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

root@localhost:mysql.sock [testdb]> select * from performance_schema.replication_applier_status_by_worker;
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



##### 5) 主库误操作: reset master，没有数据写入 --- 可立即还原成双主模式

#同事在主库上新建了个备份库formflowcs，导出原库formflow数据库，导入到formflowcs，但是报错：ERROR 3546 (HY000) at line 24: @@GLOBAL.GTID_PURGED cannot be changed: the added gtid set must not overlap with @@GLOBAL.GTID_EXECUTED

#同事经过百度后，在主库执行了reset master，导致主库的binlog全部清空了

#此时主从同步中断，从库报错

#但是此时数据库进行了read only操作，可以立即恢复为双主模式

#主库状态

```sql
#reset master前
mysql> show master status;
+------------------+----------+--------------+------------------+---------------------------------------------------------------------------------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set                                                                           |
+------------------+----------+--------------+------------------+---------------------------------------------------------------------------------------------+
| mysql-bin.000009 |   822250 |              |                  | 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1-57525,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-257840 |
+------------------+----------+--------------+------------------+---------------------------------------------------------------------------------------------+
1 row in set (0.00 sec)

#reset master操作
mysql> reset master;
Query OK, 0 rows affected (0.15 sec)


mysql> show master status;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000001 |      157 |              |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
1 row in set (0.00 sec)

mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.111
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000007
          Read_Source_Log_Pos: 391
               Relay_Log_File: relay-bin.000021
                Relay_Log_Pos: 567
        Relay_Source_Log_File: mysql-bin.000007
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
          Exec_Source_Log_Pos: 391
              Relay_Log_Space: 446208
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
             Source_Server_Id: 115
                  Source_UUID: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a
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
           Retrieved_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:55119-57525
            Executed_Gtid_Set: 
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



#从库状态

```sql
#主库reset master前
> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000009
          Read_Source_Log_Pos: 822250
               Relay_Log_File: relay-bin.000021
                Relay_Log_Pos: 420
        Relay_Source_Log_File: mysql-bin.000009
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
          Exec_Source_Log_Pos: 822250
              Relay_Log_Space: 624
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
             Source_Server_Id: 114
                  Source_UUID: 6cfaa641-7926-11ee-bb23-fefcfe25467b
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
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1-57525,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-257840
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


#主库reset master后，暂时未有变化
> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000009
          Read_Source_Log_Pos: 822250
               Relay_Log_File: relay-bin.000021
                Relay_Log_Pos: 420
        Relay_Source_Log_File: mysql-bin.000009
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
          Exec_Source_Log_Pos: 822250
              Relay_Log_Space: 624
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
             Source_Server_Id: 114
                  Source_UUID: 6cfaa641-7926-11ee-bb23-fefcfe25467b
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
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1-57525,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-257840
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



#双主重置操作

```bash
1、从库操作

-- 清空从库gtid
reset master;

-- 停止slave
stop slave;
-- 重置slave
reset slave all;

-- 重新指定主
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.204.70.110',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;

-- 启动slave
#start slave
start replica;

show replica status\G;

2、主库操作

-- 停止slave
stop slave;
-- 重置slave
reset slave all;

-- 重新建立关系  子厚两个参数查看master状态即可 和主库保持一致
#change master to master_host = '192.168.22.22', master_user = 'user', master_port=3306, master_password='pwd', master_log_file = 'mysqld-bin.000001', master_log_pos=1234; 
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.204.70.111',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;


-- 启动slave
#start slave
start replica;

show replica status\G;

3、查看从库状态

-- 查看slave状态
#show slave status
SHOW REPLICA STATUS \G;

4、验证主从的同步，查看Slave_IO_Running、Slave_SQL_Running的值，都为YES就说明没问题，主库写入数据测试即可。
1) 主库A操作
mysql> CREATE DATABASE testdb01 DEFAULT CHARSET utf8mb4; 
mysql> CREATE USER 'testuser01'@'%' IDENTIFIED BY 'Qwert123..';
mysql> GRANT ALL PRIVILEGES ON testdb01.* TO 'testuser01'@'%'; 
mysql> FLUSH PRIVILEGES;

mysql> USE testdb01;
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

mysql> select * from t_user01;
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



2) 主库B操作
mysql> use testdb01;
Database changed

mysql> select * from testdb01.t_user01;
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

mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000001
          Read_Source_Log_Pos: 1609
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 1825
        Relay_Source_Log_File: mysql-bin.000001
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
          Exec_Source_Log_Pos: 1609
              Relay_Log_Space: 2029
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
             Source_Server_Id: 114
                  Source_UUID: 6cfaa641-7926-11ee-bb23-fefcfe25467b
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
           Retrieved_Gtid_Set: 6cfaa641-7926-11ee-bb23-fefcfe25467b:1-2
            Executed_Gtid_Set: 6cfaa641-7926-11ee-bb23-fefcfe25467b:1-2
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


mysql> BEGIN;
INSERT INTO t_user01 VALUES (10,'user01');
INSERT INTO t_user01 VALUES (20,'user02');
INSERT INTO t_user01 VALUES (30,'user03');
INSERT INTO t_user01 VALUES (40,'user04');
INSERT INTO t_user01 VALUES (50,'user05');
commit;

mysql> select * from testdb01.t_user01;
+----+--------+
| id | name   |
+----+--------+
|  1 | user01 |
|  2 | user02 |
|  3 | user03 |
|  4 | user04 |
|  5 | user05 |
| 10 | user01 |
| 20 | user02 |
| 30 | user03 |
| 40 | user04 |
| 50 | user05 |
+----+--------+
10 rows in set (0.00 sec)


mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000001
          Read_Source_Log_Pos: 2678
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 1825
        Relay_Source_Log_File: mysql-bin.000001
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
          Exec_Source_Log_Pos: 2678
              Relay_Log_Space: 2029
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
             Source_Server_Id: 114
                  Source_UUID: 6cfaa641-7926-11ee-bb23-fefcfe25467b
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
           Retrieved_Gtid_Set: 6cfaa641-7926-11ee-bb23-fefcfe25467b:1-2
            Executed_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-2
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



3)主库A操作

mysql> select * from t_user01;
+----+--------+
| id | name   |
+----+--------+
|  1 | user01 |
|  2 | user02 |
|  3 | user03 |
|  4 | user04 |
|  5 | user05 |
| 10 | user01 |
| 20 | user02 |
| 30 | user03 |
| 40 | user04 |
| 50 | user05 |
+----+--------+
10 rows in set (0.00 sec)

mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.111
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000001
          Read_Source_Log_Pos: 2680
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 1440
        Relay_Source_Log_File: mysql-bin.000001
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
          Exec_Source_Log_Pos: 2680
              Relay_Log_Space: 1644
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
             Source_Server_Id: 115
                  Source_UUID: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a
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
           Retrieved_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1
            Executed_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-2
                Auto_Position: 1
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Source_TLS_Version: 
       Source_public_key_path: 
        Get_Source_public_key: 0
            Network_Namespace: 
1 row in set (0.01 sec)

ERROR: 
No query specified

```





##### 6) 主库误操作: reset master，又执行了DML后 --- 还原成主从模式

#同事在主库上新建了个备份库formflowcs，导出原库formflow数据库，导入到formflowcs，但是报错：ERROR 3546 (HY000) at line 24: @@GLOBAL.GTID_PURGED cannot be changed: the added gtid set must not overlap with @@GLOBAL.GTID_EXECUTED

#同事经过百度后，在主库执行了reset master，导致主库的binlog全部清空了

#此时主从同步中断，从库报错

#但是后面又有数据插入进来或者删除

#主库状态

```sql
root@localhost:mysql.sock [(none)]> SHOW MASTER STATUS;
+------------------+-----------+--------------+------------------+-----------------------------------------------+
| File             | Position  | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set                             |
+------------------+-----------+--------------+------------------+-----------------------------------------------+
| mysql-bin.000003 | 444986131 |              |                  | af179f66-7990-11ee-97cc-fa163e1255d2:1-366018 |
+------------------+-----------+--------------+------------------+-----------------------------------------------+
1 row in set (0.00 sec)
```



#从库状态

```sql
root@localhost:mysql.sock [(none)]>  SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State:
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000153
          Read_Source_Log_Pos: 1171668
               Relay_Log_File: relay-bin.000458
                Relay_Log_Pos: 1171844
        Relay_Source_Log_File: mysql-bin.000153
           Replica_IO_Running: No
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
          Exec_Source_Log_Pos: 1171668
              Relay_Log_Space: 1172135
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
                Last_IO_Errno: 13114
                Last_IO_Error: Got fatal error 1236 from source when reading data from binary log: 'could not find next log; the first event '' at 4, the last event read from './mysql-bin.000153' at 1171668, the last byte read from './mysql-bin.000153' at 1171668.'
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 136
                  Source_UUID: af179f66-7990-11ee-97cc-fa163e1255d2
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp: 240301 09:39:41
     Last_SQL_Error_Timestamp:
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:3440-10308609
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-10308609,

b00ea401-7990-11ee-a316-fa163e3f7e56:1-1235
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



#主从重置操作

```bash
1、从库操作

-- 清空从库gtid
reset master;

-- 停止slave
stop slave;
-- 重置slave
reset slave all;
--删除同步的数据
show databases;
drop database db*

2、主库操作

-- 查看状态
show master status;

查看position的数值，如果多次查询有变化，就说明对数据有操作。

-- 重置master
reset master;
show master status;

-- 全局锁定
SET @@GLOBAL.read_only = ON;
-- 锁表只读
flush tables with read lock;

-- 此时进行备份

/usr/bin/mysqldump -uroot -pMysql2023\!\@\#Root --quick --events --all-databases --source-data=2 --single-transaction --set-gtid-purged=OFF > 20240305.sql

/usr/bin/tar -zcvf 20240305.sql.tar.gz 20240305.sql

-- 传输到从库

 scp 20240305.sql.tar.gz 222.204.70.110:/root/

3、从库操作

-- 还原从库
tar -zxvf 20240305.sql.tar.gz

mysql -u root -p

source /root/20240305.sql


-- 重新建立关系  子厚两个参数查看master状态即可 和主库保持一致
#change master to master_host = '192.168.22.22', master_user = 'user', master_port=3306, master_password='pwd', master_log_file = 'mysqld-bin.000001', master_log_pos=1234; 
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.204.70.110',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;


-- 启动slave
#start slave
start replica;

4、主库解锁

unlock tables;
SET @@GLOBAL.read_only = OFF;


5、查看从库状态

-- 查看slave状态
#show slave status
SHOW REPLICA STATUS \G;

6、验证主从的同步，查看Slave_IO_Running、Slave_SQL_Running的值，都为YES就说明没问题，主库写入数据测试即可。
1) 主库操作
mysql> CREATE DATABASE testdb01 DEFAULT CHARSET utf8mb4; 
mysql> CREATE USER 'testuser01'@'%' IDENTIFIED BY 'Qwert123..';
mysql> GRANT ALL PRIVILEGES ON testdb01.* TO 'testuser01'@'%'; 
mysql> FLUSH PRIVILEGES;

mysql> USE testdb01;
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

mysql> select * from t_user01;
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

mysql> show master status;
+------------------+----------+--------------+------------------+------------------------------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set                        |
+------------------+----------+--------------+------------------+------------------------------------------+
| mysql-bin.000001 |     1718 |              |                  | b526a489-7796-11ee-b698-fefcfec91d86:1-6 |
+------------------+----------+--------------+------------------+------------------------------------------+
1 row in set (0.00 sec)


2) 从库查询
mysql> use testdb01;
Database changed

mysql> select * from testdb01.t_user01;
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

mysql> SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 172.18.13.112
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000001
          Read_Source_Log_Pos: 1718
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 1934
        Relay_Source_Log_File: mysql-bin.000001
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
          Exec_Source_Log_Pos: 1718
              Relay_Log_Space: 2138
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
           Retrieved_Gtid_Set: b526a489-7796-11ee-b698-fefcfec91d86:1-6
            Executed_Gtid_Set: b526a489-7796-11ee-b698-fefcfec91d86:1-6
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



##### 7) 主库误操作: reset master，又执行了DML后 --- 还原成双主模式

#同事在主库上新建了个备份库formflowcs，导出原库formflow数据库，导入到formflowcs，但是报错：ERROR 3546 (HY000) at line 24: @@GLOBAL.GTID_PURGED cannot be changed: the added gtid set must not overlap with @@GLOBAL.GTID_EXECUTED

#同事经过百度后，在主库执行了reset master，导致主库的binlog全部清空了

#此时主从同步中断，从库报错

#但是后面又有数据插入进来或者删除

#主库状态

```sql
root@localhost:mysql.sock [(none)]> SHOW MASTER STATUS;
+------------------+-----------+--------------+------------------+-----------------------------------------------+
| File             | Position  | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set                             |
+------------------+-----------+--------------+------------------+-----------------------------------------------+
| mysql-bin.000003 | 444986131 |              |                  | af179f66-7990-11ee-97cc-fa163e1255d2:1-366018 |
+------------------+-----------+--------------+------------------+-----------------------------------------------+
1 row in set (0.00 sec)
```



#从库状态

```sql
root@localhost:mysql.sock [(none)]>  SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State:
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000153
          Read_Source_Log_Pos: 1171668
               Relay_Log_File: relay-bin.000458
                Relay_Log_Pos: 1171844
        Relay_Source_Log_File: mysql-bin.000153
           Replica_IO_Running: No
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
          Exec_Source_Log_Pos: 1171668
              Relay_Log_Space: 1172135
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
                Last_IO_Errno: 13114
                Last_IO_Error: Got fatal error 1236 from source when reading data from binary log: 'could not find next log; the first event '' at 4, the last event read from './mysql-bin.000153' at 1171668, the last byte read from './mysql-bin.000153' at 1171668.'
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 136
                  Source_UUID: af179f66-7990-11ee-97cc-fa163e1255d2
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp: 240301 09:39:41
     Last_SQL_Error_Timestamp:
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:3440-10308609
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-10308609,

b00ea401-7990-11ee-a316-fa163e3f7e56:1-1235
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



#双主重置操作

```bash
1、从库操作

-- 清空从库gtid
reset master;

-- 停止slave
stop slave;
-- 重置slave
reset slave all;
--删除同步的数据
show databases;
drop database db*

2、主库操作

-- 查看状态
show master status;

查看position的数值，如果多次查询有变化，就说明对数据有操作。

-- 重置master
reset master;
show master status;

-- 全局锁定
SET @@GLOBAL.read_only = ON;
-- 锁表只读
flush tables with read lock;

-- 此时进行备份

/usr/bin/mysqldump -uroot -pMysql2023\!\@\#Root --quick --events --all-databases --source-data=2 --single-transaction --set-gtid-purged=OFF > 20240305.sql

/usr/bin/tar -zcvf 20240305.sql.tar.gz 20240305.sql

-- 传输到从库

 scp 20240305.sql.tar.gz 222.204.70.110:/root/

3、从库操作

-- 还原从库
tar -zxvf 20240305.sql.tar.gz

mysql -u root -p

source /root/20240305.sql

-- 如果是双主，此时从库也要reset master下，重置下binlog
reset master;

-- 重新建立关系  子厚两个参数查看master状态即可 和主库保持一致
#change master to master_host = '192.168.22.22', master_user = 'user', master_port=3306, master_password='pwd', master_log_file = 'mysqld-bin.000001', master_log_pos=1234; 
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.204.70.110',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;


-- 启动slave
#start slave
start replica;

4、主库解锁

unlock tables;
SET @@GLOBAL.read_only = OFF;

5、配置双主模式

stop slave;
reset slave all;

CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.204.70.111',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;

start replica;


6、查看从库状态

-- 查看slave状态
#show slave status
SHOW REPLICA STATUS \G;

7、验证主从的同步，查看Slave_IO_Running、Slave_SQL_Running的值，都为YES就说明没问题，主库写入数据测试即可。
1) 主库A操作
mysql> CREATE DATABASE testdb01 DEFAULT CHARSET utf8mb4; 
mysql> CREATE USER 'testuser01'@'%' IDENTIFIED BY 'Qwert123..';
mysql> GRANT ALL PRIVILEGES ON testdb01.* TO 'testuser01'@'%'; 
mysql> FLUSH PRIVILEGES;

mysql> USE testdb01;
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

mysql> select * from t_user01;
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



2) 主库B操作
mysql> use testdb01;
Database changed

mysql> select * from testdb01.t_user01;
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

mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000001
          Read_Source_Log_Pos: 7896
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 8112
        Relay_Source_Log_File: mysql-bin.000001
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
          Exec_Source_Log_Pos: 7896
              Relay_Log_Space: 8316
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
             Source_Server_Id: 136
                  Source_UUID: af179f66-7990-11ee-97cc-fa163e1255d2
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
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-11
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-11
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


mysql> BEGIN;
INSERT INTO t_user01 VALUES (10,'user01');
INSERT INTO t_user01 VALUES (20,'user02');
INSERT INTO t_user01 VALUES (30,'user03');
INSERT INTO t_user01 VALUES (40,'user04');
INSERT INTO t_user01 VALUES (50,'user05');
commit;

mysql> select * from testdb01.t_user01;
+----+--------+
| id | name   |
+----+--------+
|  1 | user01 |
|  2 | user02 |
|  3 | user03 |
|  4 | user04 |
|  5 | user05 |
| 10 | user01 |
| 20 | user02 |
| 30 | user03 |
| 40 | user04 |
| 50 | user05 |
+----+--------+
10 rows in set (0.00 sec)


mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000001
          Read_Source_Log_Pos: 296748
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 295895
        Relay_Source_Log_File: mysql-bin.000001
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
          Exec_Source_Log_Pos: 296748
              Relay_Log_Space: 296099
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
             Source_Server_Id: 136
                  Source_UUID: af179f66-7990-11ee-97cc-fa163e1255d2
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
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-312
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-312,
b00ea401-7990-11ee-a316-fa163e3f7e56:1
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



3)主库A操作

mysql> select * from t_user01;
+----+--------+
| id | name   |
+----+--------+
|  1 | user01 |
|  2 | user02 |
|  3 | user03 |
|  4 | user04 |
|  5 | user05 |
| 10 | user01 |
| 20 | user02 |
| 30 | user03 |
| 40 | user04 |
| 50 | user05 |
+----+--------+
10 rows in set (0.00 sec)

mysql>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.111
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000001
          Read_Source_Log_Pos: 264878
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 1487
        Relay_Source_Log_File: mysql-bin.000001
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
          Exec_Source_Log_Pos: 264878
              Relay_Log_Space: 1691
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
             Source_Server_Id: 137
                  Source_UUID: b00ea401-7990-11ee-a316-fa163e3f7e56
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
           Retrieved_Gtid_Set: b00ea401-7990-11ee-a316-fa163e3f7e56:1
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-291,
b00ea401-7990-11ee-a316-fa163e3f7e56:1
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



##### 8) 主库误操作: reset master，又执行了DML后 --- 重新导入备份文件后，还原成双主模式---repl密码发生了变动

#执行7)错误恢复时，因为从生产库导入的最新sql，导致repl发生了密码变动

#所以主从间报错

```log
2024-03-11T15:52:24.709143+08:00 5 [ERROR] [MY-010584] [Repl] Replica I/O for channel '': Error connecting to source 'repl@222.204.70.111:3306'. This was attempt 1/86400, with a delay of 60 seconds between attempts. Message: Authentication plugin 'caching_sha2_password' reported error: Authentication requires secure connection. Error_code: MY-002061
2024-03-11T15:52:42.080809+08:00 52 [Warning] [MY-013360] [Server] Plugin mysql_native_password reported: ''mysql_native_password' is deprecated and will be removed in a future release. Please use caching_sha2_password instead'
```

```mysql
mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Connecting to source
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000009
          Read_Source_Log_Pos: 532135560
               Relay_Log_File: relay-bin.000027
                Relay_Log_Pos: 4
        Relay_Source_Log_File: mysql-bin.000009
           Replica_IO_Running: Connecting
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
          Exec_Source_Log_Pos: 532135560
              Relay_Log_Space: 532136207
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
                Last_IO_Errno: 1045
                Last_IO_Error: Error connecting to source 'repl@222.204.70.110:3306'. This was attempt 12/86400, with a delay of 60 seconds between attempts. Message: Access denied for user 'repl'@'222.204.70.111' (using password: YES)
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Source_Server_Id: 0
                  Source_UUID: 6cfaa641-7926-11ee-bb23-fefcfe25467b
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Source_Retry_Count: 86400
                  Source_Bind: 
      Last_IO_Error_Timestamp: 240311 15:50:42
     Last_SQL_Error_Timestamp: 
               Source_SSL_Crl: 
           Source_SSL_Crlpath: 
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1-12,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-136385
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



#生产环境repl密码跟原测试库密码比对，或者在mysql库中的表slave_master_info中查看原密码

#发现不一致

```sql
select * from mysql.slave_master_info;
```



#并且原本授权repl账户带IP段的信息

```sql
grant replication slave on *.* to 'repl'@'10.20.12.%';
```



#解决办法

#首先主库修改或者IP限制

```sql
update mysql.user set host='172.18.13.%' where user='repl';

#update mysql.user set host='%' where user='repl';

commit;
```



#此时从库先进行repl连接主库测试，使用生产环境密码

```bash
mysql -u repl -p -h 222.204.70.110
```



#此时修改从库连接主库的repl账户密码

```sql
stop replica;

change replication source to SOURCE_PASSWORD='Repl123!@#2023';

start replica;

show replica status\G;
```



#因为前面搭建的是双主，我在主从库上都进行了update mysql.user set host='172.18.13.%' where user='repl';操作，所以从库此处有报错

```mysql
mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000010
          Read_Source_Log_Pos: 1245
               Relay_Log_File: relay-bin.000002
                Relay_Log_Pos: 373
        Relay_Source_Log_File: mysql-bin.000010
           Replica_IO_Running: Yes
          Replica_SQL_Running: No
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 1410
                   Last_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 1 failed executing transaction '6cfaa641-7926-11ee-bb23-fefcfe25467b:136387' at source log mysql-bin.000010, end_log_pos 1245. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 237
              Relay_Log_Space: 1585
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
               Last_SQL_Errno: 1410
               Last_SQL_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 1 failed executing transaction '6cfaa641-7926-11ee-bb23-fefcfe25467b:136387' at source log mysql-bin.000010, end_log_pos 1245. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
  Replicate_Ignore_Server_Ids: 
             Source_Server_Id: 114
                  Source_UUID: 6cfaa641-7926-11ee-bb23-fefcfe25467b
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: 
           Source_Retry_Count: 86400
                  Source_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 240311 15:55:23
               Source_SSL_Crl: 
           Source_SSL_Crlpath: 
           Retrieved_Gtid_Set: 6cfaa641-7926-11ee-bb23-fefcfe25467b:136386-136387
            Executed_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1-12,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-136386
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



#根据三.4中的报错处理，从库恢复正常

```sql
mysql> stop replica;
Query OK, 0 rows affected (0.00 sec)

mysql> set @@session.gtid_next='6cfaa641-7926-11ee-bb23-fefcfe25467b:136387';
Query OK, 0 rows affected (0.00 sec)

mysql> begin commit;
ERROR 1064 (42000): You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'commit' at line 1
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> commit;
Query OK, 0 rows affected (0.00 sec)

mysql> set @@session.gtid_next=automatic;  
Query OK, 0 rows affected (0.00 sec)

mysql> start replica;
Query OK, 0 rows affected (0.05 sec)


mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.204.70.110
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000010
          Read_Source_Log_Pos: 1245
               Relay_Log_File: relay-bin.000003
                Relay_Log_Pos: 460
        Relay_Source_Log_File: mysql-bin.000010
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
          Exec_Source_Log_Pos: 1245
              Relay_Log_Space: 1888
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
             Source_Server_Id: 114
                  Source_UUID: 6cfaa641-7926-11ee-bb23-fefcfe25467b
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
           Retrieved_Gtid_Set: 6cfaa641-7926-11ee-bb23-fefcfe25467b:136386-136387
            Executed_Gtid_Set: 6cf9ffd3-7926-11ee-84ca-fefcfe0f647a:1-12,
6cfaa641-7926-11ee-bb23-fefcfe25467b:1-136387
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



#同样步骤在现在的主库中执行

#双主恢复

#然后恢复keepalived



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
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.204.70.111',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2024',SOURCE_AUTO_POSITION = 1;

start replica;
show replica status\G;

mysql> select * from performance_schema.replication_applier_status_by_worker where LAST_ERROR_NUMBER=1396;

 stop replica;
 set @@session.gtid_next='0f76fa28-5f74-11ef-be67-fefcfe4ed56d:1'; 
 begin; 
 commit; 
 
 set @@session.gtid_next=automatic;  
 
 start replica; 
 
 SHOW REPLICA STATUS \G;
 
 stop replica;
 set @@session.gtid_next='0f76fa28-5f74-11ef-be67-fefcfe4ed56d:4'; 
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
yum install -y pcre-devel openssl-devel popt-devel libnl libnl-devel psmisc gcc
```



#### 2、安装keepalived

#在线安装

```bash
yum install -y keepalived

keepalived -v
```



#logs

```bash
[root@mysql01 network-scripts]# keepalived -v
Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2

#如果版本过低，低于2.2.8，那么可以离线部署
```





#离线部署

#官网https://www.keepalived.org/download.html

```bash
wget --no-check-certificate https://www.keepalived.org/software/keepalived-2.2.8.tar.gz
tar -zxvf keepalived-2.2.8.tar.gz
cd keepalived-2.2.8
#yum install -y gcc
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
   router_id MYSQL-110                   #主机标识符，唯一即可
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
    virtual_router_id 112            #虚拟路由标识，取值0-255，master-1和master-2保持一致
    priority 100                     #优先级，用来选举master，取值范围1-255
    advert_int 1                     #发VRRP包时间间隔，即多久进行一次master选举
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              #虚拟出来的地址
        222.204.70.112
    }
}

#虚拟服务器定义
virtual_server 222.204.70.112 3306 { #虚拟出来的地址加端口
    delay_loop 2                     #设置运行情况检查时间，单位为秒
    lb_algo rr                       #设置后端调度器算法，rr为轮询算法
    lb_kind DR                       #设置LVS实现负载均衡的机制，有DR、NAT、TUN三种模式可选
    persistence_timeout 50           #会话保持时间，单位为秒
    protocol TCP                     #指定转发协议，有 TCP和UDP可选

        real_server 222.204.70.110 3306 {          #实际本地ip+3306端口
       weight=5                      #表示服务器的权重值。权重值越高，服务器在负载均衡中被选中的概率就越大
        #当该ip 端口连接异常时，执行该脚本
        notify_down /etc/keepalived/shutdown.sh   #检查mysql服务down掉后执行的脚本
        TCP_CHECK {
            #实际物理机ip地址
            connect_ip 222.204.70.110
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
   router_id MYSQL-110                   
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
    virtual_router_id 112            
    priority 100                     
    advert_int 1                    
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {             
        222.204.70.112
    }
}


virtual_server 222.204.70.112 3306 { 
    delay_loop 2                   
    lb_algo rr                      
    lb_kind DR                     
    persistence_timeout 50           
    protocol TCP                  

        real_server 222.204.70.110 3306 {      
       weight=5                    
        notify_down /etc/keepalived/shutdown.sh  
        TCP_CHECK {
            connect_ip 222.204.70.110
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
   router_id MYSQL-111                   #主机标识符，唯一即可
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
    virtual_router_id 112            #虚拟路由标识，取值0-255，master-1和master-2保持一致
    priority 40                      #优先级，用来选举master，取值范围1-255
    advert_int 1                     #发VRRP包时间间隔，即多久进行一次master选举
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              #虚拟出来的地址
        222.204.70.112
    }
}

#虚拟服务器定义
virtual_server 222.204.70.112 3306 { #虚拟出来的地址加端口
    delay_loop 2                     #设置运行情况检查时间，单位为秒
    lb_algo rr                       #设置后端调度器算法，rr为轮询算法
    lb_kind DR                       #设置LVS实现负载均衡的机制，有DR、NAT、TUN三种模式可选
    persistence_timeout 50           #会话保持时间，单位为秒
    protocol TCP                     #指定转发协议，有 TCP和UDP可选

        real_server 222.204.70.111 3306 {          #实际本地ip+3306端口
       weight=5                      #表示服务器的权重值。权重值越高，服务器在负载均衡中被选中的概率就越大
        #当该ip 端口连接异常时，执行该脚本
        notify_down /etc/keepalived/shutdown.sh   #检查mysql服务down掉后执行的脚本
        TCP_CHECK {
            #实际物理机ip地址
            connect_ip 222.204.70.111
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
   router_id MYSQL-111
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
    virtual_router_id 112            
    priority 40                     
    advert_int 1                     
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              
        222.204.70.112
    }
}


virtual_server 222.204.70.112 3306 { 
    delay_loop 2                     
    lb_algo rr                       
    lb_kind DR                       
    persistence_timeout 50           
    protocol TCP                   

        real_server 222.204.70.111 3306 {          
       weight=5                      
        notify_down /etc/keepalived/shutdown.sh   
        TCP_CHECK {
            connect_ip 222.204.70.111
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

ping xxx.xxx.xx.xx

#如果此时ping不通第二个IP，那么可以关闭keepalived后，手动添加第二个IP，再ping测试
ip addr add 192.168.1.100/24 dev eth0
ping 192.168.1.100

```

发现vip在主库上：
```
[root@mysql01 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:1f:c2:9a brd ff:ff:ff:ff:ff:ff
    inet 222.204.70.110/25 brd 222.204.70.127 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet 222.204.70.112/32 scope global eth0
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
222.204.70.110 mysql01
222.204.70.111 mysql02

vip: 222.204.70.112
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
| NULL | 2024-08-21 17:30:14 |
+------+---------------------+
1 row in set (0.00 sec)

```

#执行脚本

```bash
while true; do date;mysql -u testuser -pQwert123.. -h 222.204.70.112 -e 'use testdb;insert into nowdate values (null, now());'; sleep 1;done
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
#用mysql连接工具连接keepalived虚拟出来的222.204.70.112服务器

##### 3) 建立测试数据 
#在222.204.70.112数据库mydb测试库新建一张表，表中插入一些数据

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
#使用ip addr命令查看实际使用的物理机为222.204.70.110，所以master-1(222.204.70.110)服务器mysql为主数据库。

##### 6) 停止物理机mysql服务
#此时手动将master-1服务器mysql停止，keepalived检测到222.204.70.110服务3306端口连接失败，会执行/etc/keepalived/shutdown.sh脚本，将222.204.70.110服务器keepalived应用结束

```bash
service mysql stop
Shutting down MySQL............. SUCCESS! 
```


##### 7) 查看漂移ip执行情况
#此时再连接222.204.70.111服务下，ip addr查看，发现已经实际将物理机由master-1(222.204.70.110)到master-2(222.204.70.111)服务器上

##### 8) 在新的主服务器插入数据
#再使用mysql连接工具连接222.204.70.111的mysql，插入一条数据，测试是否将数据存入master-2(222.204.70.111)服务器mysql中

```mysql
insert into ceshi1 values(6,'李四','英语',94);
```



##### 9) 查看新主服务器数据
#查看master-2服务器mysql数据，数据已同步，说明keepalived搭建高可用成功，当master-1服务器mysql出现问题后keepalived自动漂移IP到实体机master-2服务器上，从而使master-2服务器mysql作为主数据库。

##### 10) 重启master-1服务，查看数据同步情况
#此时再启动master-1(222.204.70.110)服务器mysql、keepalived应用

```bash
systemctl start mysql
systemctl status mysql

systemctl start keepalived
systemctl status keepalived
```

 #查看master-1数据库ceshi1表数据，数据已同步成功。 

```sql
#主从库可以都commit下
commit;

select count(1) from ceshi1;
```



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
#gzDumpFile="mysql136_${nowDate}.sql.tgz"
gzDumpFile="mysql136_${nowDate}.zip"
ZIP_PASSWORD="7bXNvTCgnQ3sdTvgaR5e"

cd $bakDir
# 全量备份
/usr/bin/mysqldump -u${username} -p${mypasswd} --quick --events  --all-databases  --source-data=2 --single-transaction --set-gtid-purged=OFF > $dumpFile
# 打包
#/usr/bin/tar -zvcf $gzDumpFile $dumpFile
zip -j -P $ZIP_PASSWORD $gzDumpFile $dumpFile
/usr/bin/rm $dumpFile

endTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo 开始:$beginTime 结束:$endTime $gzDumpFile succ >> $logFile

##删除过期备份
find $bakDir -name 'mysql*.sql.tgz' -mtime +7 -exec rm {} \;

#scp到备份服务器
scp $gzDumpFile 10.20.12.129:/data/mysql117bak/

scpendTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo scp结束:$scpendTime succ >> $logFile

sync
echo 1 > /proc/sys/vm/drop_caches

backupendTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo backup结束:$backupendTime succ >> $logFile

EOF

```



#

```bash
watch -n 1 "iostat -dx 1 2; mysqladmin ext | grep -E 'Innodb_buffer_pool_reads|Innodb_pages_read'"
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

scpendTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo scp结束:$scpendTime succ >> $logFile

sync
echo 1 > /proc/sys/vm/drop_caches

backupendTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo backup结束:$backupendTime succ >> $logFile

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
#wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.34-1.el7.x86_64.rpm-bundle.tar
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.37-1.el7.x86_64.rpm-bundle.tar
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



#### 8.20 my.cnf

```bash
[root@k8s-mysql-ole-test etc]# cat /etc/my.cnf
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
server_id = 120
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


#内部临时表
#internal_tmp_mem_storage_engine = MEMORY
#internal_tmp_mem_storage_engine = TempTable

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
#log_replica_updates = on
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
#expire_logs_days = 180
binlog_expire_logs_seconds = 15552000

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
log_queries_not_using_indexes = 0
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
slave-skip-errors=1032
#replica_skip_errors = 1032
#log_error_suppression_list = 'MY-010914,MY-013360,MY-013730,MY-010584,MY-010559'
#log_error_suppression_list='MY-010956,MY-010957'

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
#replica_net_timeout = 30
#rpl_stop_replica_timeout = 300
slave_net_timeout = 30
rpl_stop_slave_timeout = 180
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
#replica_preserve_commit_order = OFF

#replica_parallel
#replica_parallel_type = LOGICAL_CLOCK

#replica_parallel_workers = 16
#deprecated
slave_preserve_commit_order = OFF
#并行复制模式:DATABASE默认值,基于库的并行复制方式;LOGICAL_CLOCK,基于组提交的并行复制方式
slave_parallel_type = LOGICAL_CLOCK
#主从复制时,设置并行复制的工作线程数
slave_parallel_workers=16

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
#innodb_redo_log_capacity=1073741824

#8.0.30以前
innodb_log_file_size = 1024M
#redo日志组数,默认为2
innodb_log_files_in_group = 3

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
```

#### .my.cnf
```bash
cat >> /root/.my.cnf <<EOF
[mysqldump]
user="root"
password ="xxxxxx"
[mysqladmin]
user="root"
password ="xxxxxx"
[mysql]
user="root"
password ="xxxxxx"
[client]
user="root"
password ="xxxxxx"
EOF

chmod 600 /root/.my.cnf

mysql
exit

mysqlcheck -Aa
```


### 七、开启防火墙

#
```bash
systemctl start firewalld

systemctl enable firewalld

systemctl status firewalld


sudo firewall-cmd --permanent --add-port=3306/tcp

firewall-cmd --add-rich-rule='rule protocol value="vrrp" accept' --permanent

firewall-cmd --reload

firewall-cmd --list-all
```