**19C RAC for Centos7.9 安装手册**

## 目录
1 环境..............................................................................................................................................2
1.1. 系统版本： ..............................................................................................................................2
1.2. ASM 磁盘组规划 ....................................................................................................................2
1.3. 主机网络规划..........................................................................................................................2
1.4. 操作系统配置部分.................................................................................................................2
2 准备工作（db-rac01 与 db-rac02 同时配置） ............................................................................................3
2.1. 配置本地 yum 源： ................................................................................................................3
2.2. 安装 rpm 依赖包 ....................................................................................................................4
2.3. 创建用户...................................................................................................................................5
2.4. 配置 host 表.............................................................................................................................6
2.5. 禁用 NTP ..................................................................................................................................6
2.6. 创建所需要目录 .....................................................................................................................6
2.7. 其它配置： ..............................................................................................................................6
2.8. 配置环境变量..........................................................................................................................8
2.9. 配置共享磁盘权限.................................................................................................................9
2.10. 配置互信........................................................................................................................... 11
2.11. 在 grid 安装文件中安装 cvuqdisk.............................................................................. 12
3 开始安装 grid ................................................................................................................................... 12
3.1. 上传集群软件包 .................................................................................................................. 12
3.2. 解压 grid 安装包.................................................................................................................. 12
3.3. 进入 grid 集群软件目录执行安装................................................................................... 12
3.4. GUI 安装步骤........................................................................................................................ 13
3.5. 查看状态................................................................................................................................ 25
4 以 Oracle 用户登录图形化界面................................................................................................... 26
4.1. 执行安装................................................................................................................................ 27
4.2. 执行 root 脚本...................................................................................................................... 32
5 创建 ASM 数据磁盘........................................................................................................................ 32
5.1. grid 账户登录图形化界面，执行 asmca....................................................................... 33
6 建立数据库 ........................................................................................................................................ 35
6.1. 执行建库 dbca ..................................................................................................................... 36
6.2. 查看集群状态....................................................................................................................... 45
6.3. 查看数据库版本 .................................................................................................................. 471 

## 1.系统环境
### 1.1. 系统版本：
```
[root@db-rac01 Packages]# cat /etc/oracle-release
Oracle Linux release 8.7
```
### 1.2. ASM 磁盘组规划
```
ASM 磁盘组 用途 大小 冗余
ocr    voting file   100G+100G+100G NORMAL
DATA 数据文件 2T+2T+2T EXTERNAL
FRA    归档日志 2T EXTERNAL
```
### 1.3. 主机网络规划

#IP规划

```
网络配置               节点 1                                  节点 2
主机名称               db-rac01                              db-rac02
public ip            172.16.134.1                          172.16.134.3
private ip           10.251.252.1                          10.251.252.3
vip                  172.16.134.2                          172.16.134.4
scan ip              172.16.134.8/172.16.134.9/172.16.134.10 
```
###学校实际参数

```
root/Ora123#@!
grid/Fjbu2022!
oracle/Fjbu2022!

[root@db-rac01 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0    2T  0 disk 
sdb           8:16   0    2T  0 disk 
sdc           8:32   0    2T  0 disk 
sdd           8:48   0    2T  0 disk 
sde           8:64   0  100G  0 disk 
sdf           8:80   0  100G  0 disk 
sdg           8:96   0  100G  0 disk 
sr0          11:0    1 11.2G  0 rom  
vda         251:0    0 1000G  0 disk 
├─vda1      251:1    0    1G  0 part /boot
└─vda2      251:2    0  999G  0 part 
  ├─ol-root 252:0    0  967G  0 lvm  /
  └─ol-swap 252:1    0   32G  0 lvm  [SWAP]
[root@db-rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | sk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -uone
/dev/sda 36ff204468043c909acc0afa4094745b6
/dev/sdb 368350b4ed049f10a9b108e152738bc3d
/dev/sdc 366960e55904821091c9025e2c7255c7f
/dev/sdd 36b0708eaa043b10a29d06927e688b365
/dev/sde 3643a008cc04b8e0b8e109a319a118822
/dev/sdf 36e450b2170407e0911006b92fd32de0e
/dev/sdg 366a2083ed04ba40b0470989b6a3a6a77
[root@db-rac01 ~]# 

[root@db-rac02 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0    2T  0 disk 
sdb           8:16   0    2T  0 disk 
sdc           8:32   0    2T  0 disk 
sdd           8:48   0    2T  0 disk 
sde           8:64   0  100G  0 disk 
sdf           8:80   0  100G  0 disk 
sdg           8:96   0  100G  0 disk 
sr0          11:0    1 11.2G  0 rom  
vda         251:0    0 1000G  0 disk 
├─vda1      251:1    0    1G  0 part /boot
└─vda2      251:2    0  999G  0 part 
  ├─ol-root 252:0    0  967G  0 lvm  /
  └─ol-swap 252:1    0   32G  0 lvm  [SWAP]
[root@db-rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | sk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -uone
/dev/sda 36ff204468043c909acc0afa4094745b6
/dev/sdb 36b0708eaa043b10a29d06927e688b365
/dev/sdc 366960e55904821091c9025e2c7255c7f
/dev/sdd 368350b4ed049f10a9b108e152738bc3d
/dev/sde 36e450b2170407e0911006b92fd32de0e
/dev/sdf 366a2083ed04ba40b0470989b6a3a6a77
/dev/sdg 3643a008cc04b8e0b8e109a319a118822
[root@db-rac02 ~]# 

[root@db-rac01 ~]# cd /etc/sysconfig/network-scripts/[root@db-rac01 network-scripts]# ls
ifcfg-ens18  ifcfg-ens19
[root@db-rac01 network-scripts]# cat ifcfg-ens18
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=eui64
NAME=ens18
UUID=34c50ef1-948a-4100-8665-69adf4d83f1a
DEVICE=ens18
ONBOOT=yes
IPADDR=172.16.134.1
PREFIX=24
GATEWAY=172.16.134.254
DNS1=114.114.114.114
[root@db-rac01 network-scripts]# cat ifcfg-ens19
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=eui64
NAME=ens19
UUID=e061389c-e34e-4317-b79f-0bf5fbaa5dc2
DEVICE=ens19
ONBOOT=yes
IPADDR=10.251.252.1
PREFIX=24
GATEWAY=10.251.252.254
[root@db-rac01 network-scripts]# ip route list
default via 172.16.134.254 dev ens18 proto static metric 100 
default via 10.251.252.254 dev ens19 proto static metric 101 
10.251.252.0/24 dev ens19 proto kernel scope link src 10.251.252.1 metric 101 
172.16.134.0/24 dev ens18 proto kernel scope link src 172.16.134.1 metric 100 
[root@db-rac01 network-scripts]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.16.134.254  0.0.0.0         UG    100    0        0 ens18
0.0.0.0         10.251.252.254  0.0.0.0         UG    101    0        0 ens19
10.251.252.0    0.0.0.0         255.255.255.0   U     101    0        0 ens19
172.16.134.0    0.0.0.0         255.255.255.0   U     100    0        0 ens18
[root@db-rac01 network-scripts]# 

[root@db-rac02 ~]# cd /etc/sysconfig/network-scripts/[root@db-rac02 network-scripts]# ls
ifcfg-ens18  ifcfg-ens19
[root@db-rac02 network-scripts]# cat ifcfg-ens18
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=eui64
NAME=ens18
#UUID=34c50ef1-948a-4100-8665-69adf4d83f1a
UUID=4332671f-e9c5-49e2-ab47-4bea8927e261
DEVICE=ens18
ONBOOT=yes
IPADDR=172.16.134.3
PREFIX=24
GATEWAY=172.16.134.254
DNS1=114.114.114.114
[root@db-rac02 network-scripts]# cat ifcfg-ens19
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=eui64
NAME=ens19
#UUID=e061389c-e34e-4317-b79f-0bf5fbaa5dc2
UUID=fed391c5-2025-4e8d-82a2-3029e436f450
DEVICE=ens19
ONBOOT=yes
IPADDR=10.251.252.3
PREFIX=24
GATEWAY=10.251.252.254
[root@db-rac02 network-scripts]# ip route list
default via 172.16.134.254 dev ens18 proto static metric 100 
default via 10.251.252.254 dev ens19 proto static metric 101 
10.251.252.0/24 dev ens19 proto kernel scope link src 10.251.252.3 metric 101 
172.16.134.0/24 dev ens18 proto kernel scope link src 172.16.134.3 metric 100 
[root@db-rac02 network-scripts]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.16.134.254  0.0.0.0         UG    100    0        0 ens18
0.0.0.0         10.251.252.254  0.0.0.0         UG    101    0        0 ens19
10.251.252.0    0.0.0.0         255.255.255.0   U     101    0        0 ens19
172.16.134.0    0.0.0.0         255.255.255.0   U     100    0        0 ens18
[root@db-rac02 network-scripts]# 

[root@db-rac01 ~]# nmcli dev
DEVICE  TYPE      STATE      CONNECTION 
ens18   ethernet  connected  ens18      
ens19   ethernet  connected  ens19      
lo      loopback  unmanaged  --         
[root@db-rac01 ~]# nmcli con show
NAME   UUID                                  TYPE   >
ens18  34c50ef1-948a-4100-8665-69adf4d83f1a  etherne>
ens19  e061389c-e34e-4317-b79f-0bf5fbaa5dc2  etherne>
[root@db-rac01 ~]# 


[root@db-rac02 ~]# nmcli dev
DEVICE  TYPE      STATE      CONNECTION 
ens18   ethernet  connected  ens18      
ens19   ethernet  connected  ens19      
lo      loopback  unmanaged  --         
[root@db-rac02 ~]# nmcli con show
NAME   UUID                                  TYPE   >
ens18  4332671f-e9c5-49e2-ab47-4bea8927e261  etherne>
ens19  fed391c5-2025-4e8d-82a2-3029e436f450  etherne>
[root@db-rac02 ~]#

[root@db-rac01 ~]# systemctl status network
Unit network.service could not be found.

[root@db-rac01 ~]# cat /etc/resolv.conf 
# Generated by NetworkManager
nameserver 114.114.114.114
[root@db-rac01 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkMa>
   Active: active (running) since Thu 2022-12-01 17:>
     Docs: man:NetworkManager(8)
 Main PID: 2189 (NetworkManager)
    Tasks: 3 (limit: 1647071)
   Memory: 10.7M
   CGroup: /system.slice/NetworkManager.service
           └─2189 /usr/sbin/NetworkManager --no-daem>

Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
Dec 01 17:50:21 db-rac01 NetworkManager[2189]: <info>
[root@db-rac01 ~]# 

```
#网卡配置及多路径配置
```bash
ifconfig
nmcli conn show
#只运行了NetworkManager
#network未运行
```

```
假如网卡绑定：
#eno8为私有网卡
#ens3f0和ens3f1d1绑定为team0为业务网卡
```
#节点一db-rac01
```bash
nmcli con mod eno8 ipv4.addresses 10.251.252.1/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '172.16.134.1/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#节点二db-rac02
```bash
nmcli con mod eno8 ipv4.addresses 10.251.252.3/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '172.16.134.1/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```

### 1.4. 操作系统配置部分

#修改hostname
```bash
hostnamectl set-hostname db-rac01
hostnamectl set-hostname db-rac02
hostnamectl set-hostname db-rac03
```
#关闭防火墙
```bash
systemctl stop firewalld
systemctl disable firewalld

systemctl status firewalld
```
#关闭 selinux
```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0
```
### 1.5.多路径配置情况---无
```  
[root@db-rac02 ~]# cat /etc/multipath/
bindings  wwids     
[root@db-rac02 ~]# cat /etc/multipath/bindings 
# Multipath bindings, Version : 1.0
# NOTE: this file is automatically maintained by the multipath program.
# You should not need to edit this file in normal circumstances.
#
# Format:
# alias wwid
#
mpatha 24c740a67e89393fa6c9ce90079a4df08
mpathb 2bf57071b2488dae06c9ce90079a4df08
mpathc 2ee6c414e797cb16f6c9ce90079a4df08
mpathd 2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe 2086fa4c938d839c66c9ce90079a4df08
mpathf 27b44daa76accbc526c9ce90079a4df08
mpathg 2aa67dbb0c9c0573b6c9ce90079a4df08
[root@db-rac02 ~]# cat /etc/multipath/wwids 
# Multipath wwids, Version : 1.0
# NOTE: This file is automatically maintained by multipath and multipathd.
# You should not need to edit this file in normal circumstances.
#
# Valid WWIDs:
mpatha 24c740a67e89393fa6c9ce90079a4df08
mpathb 2bf57071b2488dae06c9ce90079a4df08
mpathc 2ee6c414e797cb16f6c9ce90079a4df08
mpathd 2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe 2086fa4c938d839c66c9ce90079a4df08
mpathf 27b44daa76accbc526c9ce90079a4df08
mpathg 2aa67dbb0c9c0573b6c9ce90079a4df08

[root@db-rac02 ~]# sfdisk -s|grep mpath
/dev/mapper/mpatha: 104857600
/dev/mapper/mpathb: 104857600
/dev/mapper/mpathc: 104857600
/dev/mapper/mpathd: 2147483648
/dev/mapper/mpathe: 2147483648
/dev/mapper/mpathf: 2147483648
/dev/mapper/mpathg: 2147483648

[root@db-rac01 ~]# multipathd show maps
name   sysfs uuid
mpatha dm-2  24c740a67e89393fa6c9ce90079a4df08
mpathb dm-3  2bf57071b2488dae06c9ce90079a4df08
mpathc dm-4  2ee6c414e797cb16f6c9ce90079a4df08
mpathd dm-5  2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe dm-6  2086fa4c938d839c66c9ce90079a4df08
mpathf dm-7  27b44daa76accbc526c9ce90079a4df08
mpathg dm-8  2aa67dbb0c9c0573b6c9ce90079a4df08
```

## 2.准备工作（db-rac01 与 db-rac02 同时配置）

### 2.1. 配置本地 yum 源--可选

#挂载光驱
```bash
mount -t auto /dev/cdrom /mnt
```
#配置本地源---centos7.9
```bash
cat >> CentOS-Media.repo <<EOF
# CentOS-Media.repo
#
# This repo can be used with mounted DVD media, verify the mount point for
# CentOS-7. You can use this repo and yum to install items directly off the
# DVD ISO that we release.
#
# To use this repo, put in your DVD and use it with the other repos too:
# yum --enablerepo=c7-media [command]
#
# or for ONLY the media repo, do this:
#
# yum --disablerepo=\* --enablerepo=c7-media [command]
[c7-media]
name=CentOS-$releasever - Media
baseurl=file:///mnt/
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF


yum clean all

yum makecache
```

#配置本地源---oracleLinux8.7
```bash
cd /etc/yum.repo.d
mv oracle-linux-ol8.repo oracle-linux-ol8.repo.bak

cat >> oracle-linux-ol8.repo <<EOF
# CentOS-Media.repo
#
# This repo can be used with mounted DVD media, verify the mount point for
# CentOS-7. You can use this repo and yum to install items directly off the
# DVD ISO that we release.
#
# To use this repo, put in your DVD and use it with the other repos too:
# yum --enablerepo=c7-media [command]
#
# or for ONLY the media repo, do this:
#
# yum --disablerepo=\* --enablerepo=c7-media [command]
[local_iso_baseos]
name=ol8_baseos
baseurl=file:///mnt/BaseOS/
enabled=1
gpgcheck=0
[local_iso_appstream]
name=ol8_appstream
baseurl=file:///mnt/AppStream/
enabled=1
gpgcheck=0

EOF


yum clean all

yum makecache
```
### 2.2. 安装 rpm 依赖包

#官网为准
```
https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/supported-oracle-linux-8-distributions-for-x86-64.html#GUID-F4902762-325B-4C89-B85B-F52BA482190F
```
```bash
dnf install -y  bc
dnf install -y  binutils
dnf install -y  elfutils-libelf
dnf install -y  elfutils-libelf-devel
dnf install -y  fontconfig-devel
dnf install -y  glibc
dnf install -y  glibc-devel
dnf install -y  ksh
dnf install -y  libaio
dnf install -y  libaio-devel
dnf install -y  libXrender
dnf install -y  libX11
dnf install -y  libXau
dnf install -y  libXi
dnf install -y  libXtst
dnf install -y  libgcc
dnf install -y  libnsl
dnf install -y  librdmacm
dnf install -y  libstdc++
dnf install -y  libstdc++-devel
dnf install -y  libxcb
dnf install -y  libibverbs
dnf install -y  make
dnf install -y  policycoreutils
dnf install -y  policycoreutils-python-utils
dnf install -y  smartmontools
dnf install -y  sysstat

dnf install -y compat-libstdc++-33
dnf install -y libXrender-devel
dnf install -y libnsl2
dnf install -y libnsl2-devel
dnf install -y net-tools
dnf install -y nfs-utils
dnf install -y unixODBC
```

```
rpm -qa|grep   bc
rpm -qa|grep   binutils
rpm -qa|grep   elfutils-libelf
rpm -qa|grep   elfutils-libelf-devel
rpm -qa|grep   fontconfig-devel
rpm -qa|grep   glibc
rpm -qa|grep   glibc-devel
rpm -qa|grep   ksh
rpm -qa|grep   libaio
rpm -qa|grep   libaio-devel
rpm -qa|grep   libXrender
rpm -qa|grep   libX11
rpm -qa|grep   libXau
rpm -qa|grep   libXi
rpm -qa|grep   libXtst
rpm -qa|grep   libgcc
rpm -qa|grep   libnsl
rpm -qa|grep   librdmacm
rpm -qa|grep   libstdc++
rpm -qa|grep   libstdc++-devel
rpm -qa|grep   libxcb
rpm -qa|grep   libibverbs
rpm -qa|grep   make
rpm -qa|grep   policycoreutils
rpm -qa|grep   policycoreutils-python-utils
rpm -qa|grep   smartmontools
rpm -qa|grep   sysstat

rpm -qa|grep  compat-libstdc++-33
rpm -qa|grep  libXrender-devel
rpm -qa|grep  libnsl2
rpm -qa|grep  libnsl2-devel
rpm -qa|grep  net-tools
rpm -qa|grep  nfs-utils
rpm -qa|grep  unixODBC
```

### 2.3. 创建用户

```bash
/usr/sbin/groupadd -g 54321 oinstall
/usr/sbin/groupadd -g 54322 dba
/usr/sbin/groupadd -g 54323 oper
/usr/sbin/groupadd -g 54324 backupdba
/usr/sbin/groupadd -g 54325 dgdba
/usr/sbin/groupadd -g 54326 kmdba
/usr/sbin/groupadd -g 54327 asmdba
/usr/sbin/groupadd -g 54328 asmoper
/usr/sbin/groupadd -g 54329 asmadmin
/usr/sbin/groupadd -g 54330 racdba
/usr/sbin/useradd -u 54321 -g oinstall -G dba,oper,backupdba,dgdba,kmdba,racdba,asmdba,asmoper oracle
/usr/sbin/useradd -u 54322 -g oinstall -G dba,oper,asmadmin,asmdba,asmoper,racdba grid
# pass Word
echo "oracle" | passwd --stdin oracle
echo "oracle" | passwd --stdin grid

passwd oracle
passwd grid
#Fjbu2022!
```
### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#db-rac01
hostnamectl set-hostname db-rac01
#db-rac02
hostnamectl set-hostname db-rac02

cat >> /etc/hosts <<EOF
#public ip 
172.16.134.1 db-rac01
172.16.134.3 db-rac02
172.16.134.6 db-rac03
#vip
172.16.134.2 db-rac01-vip
172.16.134.4 db-rac02-vip
172.16.134.7 db-rac03-vip
#private ip
10.251.252.1 db-rac01-prv
10.251.252.3 db-rac02-prv
10.251.252.6 db-rac03-prv
#scan ip
172.16.134.8 rac-scan
172.16.134.9 rac-scan
172.16.134.10 rac-scan
EOF

```
### 2.5. 禁用 NTP

#检查两节点时间，时区是否相同，并禁止 ntp
```bash
#yum remove ntpd
systemctl disable ntpd.service
systemctl stop ntpd.service
mv /etc/ntp.conf /etc/ntp.conf.orig
[root@db-rac01 ~]# systemctl disable ntpd.service
Failed to execute operation: No such file or directory
[root@db-rac01 ~]# systemctl stop ntpd.service
Failed to stop ntpd.service: Unit ntpd.service not loaded.

systemctl status ntpd

#yum remove chronyd
systemctl disable chronyd
systemctl stop chronyd

systemctl status chronyd

#ntpdate pool.ntp.org
```
#时区设置
```bash
#查看是否中国时区
date -R 
timedatectl
clockdiff db-rac01
clockdiff db-rac02

#设置中国时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#方法二
timedatectl list-timezones |grep Shanghai #查找中国时区的完整名称
--->Asia/Shanghai
timedatectl set-timezone Asia/Shanghai
```

#修改系统语言环境
```
sudo echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```

### 2.6. 创建所需要目录

```bash
mkdir -p /u01/app/19.0.0/grid
mkdir -p /u01/app/grid
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/oracle/product/19.0.0/db_1

chown -R grid:oinstall /u01
chown -R oracle:oinstall /u01/app/oracle
chmod -R 775 /u01
```
### 2.7. 其它优化配置：

#oracleLinux8 没有/etc/security/limits.d/20-nproc.con

```bash
#sudo sed -i 's/4096/90000/g' /etc/security/limits.d/20-nproc.conf
```
#修改/etc/security/limits.conf
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
#关闭THP，检查是否开启
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```
--->[always] madvise never
#若以上命令执行结果显示为“always”，则表示开启了THP

##修改方法一，必须知道引导是BIOS还是EFI
#可以通过df -h或者cat /etc/fstab查看是否有/boot/efi分区
#则修改/etc/default/grub，在RUB_CMDLINE_LINUX中添加transparent_hugepage=never

#内容如下
```
GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet transparent_hugepage=never numa=off"
```
#执行如下命令，重新生成grub.cfg配置文件

#On BIOS-based machines
```bash
grub2-mkconfig -o /boot/grub2/grub.cfg

reboot
```
#On UEFI-based machines
```bash
grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg

reboot
```
#日志
```
[root@db-rac01 ~]# grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1160.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1160.el7.x86_64.img
Found linux image: /boot/vmlinuz-0-rescue-ec5c058bc1d14a888efba10ef3d6c18f
Found initrd image: /boot/initramfs-0-rescue-ec5c058bc1d14a888efba10ef3d6c18f.img
done
```
重启节点后，检查配置是否正常：
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```
```
--->always madvise [never]
```
检查是否使用HugePages

```bash
# cat /proc/meminfo |grep -i hug
AnonHugePages:         0 kB
HugePages_Total:   128819
HugePages_Free:     5980
HugePages_Rsvd:       42
HugePages_Surp:        0
Hugepagesize:       2048 kB
# cat /sys/kernel/mm/transparent_hugepage/enabled
always madvise [never]
# cat /etc/fstab 

#
# /etc/fstab
# Created by anaconda on Fri Jan  8 23:19:04 2021
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=0483cd82-0c25-4c7f-b281-ab607253bfb4 /boot                   xfs     defaults        0 0
UUID=7E75-FE2E          /boot/efi               vfat    umask=0077,shortname=winnt 0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
```



##方法二
#修改/etc/rc.local，并重启OS

```bash
cat >> /etc/rc.local <<EOF
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

EOF

```
#修改pam.d/login
```bash
cat >> /etc/pam.d/login <<EOF
#ORACLE SETTING
session required pam_limits.so

EOF

```
#修改/etc/sysctl.conf

#memory=256G

```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 56250000
#memory*90%
kernel.shmmax = 230400000000
kernel.shmmni = 4096
kernel.sem = 6144 50331648 4096 8192
kernel.panic_on_oops = 1
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 4194304
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

EOF

sysctl -p
```
#关闭avahi-daemon---无

```bash
systemctl disable avahi-daemon.socket
systemctl disable avahi-daemon.service

ps -ef|grep avahi-daemon|grep -v grep

#avahi 2674 1 0 18:28 ? 00:00:00 avahi-daemon: running [linux.local]
#avahi 2704 2674 0 18:28 ? 00:00:00 avahi-daemon: chroot helper

#kill -9 2674 2704

ps -ef|grep avahi-daemon

```
#nozeroconf
```bash
cat  >> /etc/sysconfig/network <<EOF
NOZEROCONF=yes
EOF
```
### 2.8. 配置环境变量

#grid用户，注意db-rac01/db-rac02两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意db-rac02修改
#export ORACLE_SID=+ASM2
#注意db-rac03修改
#export ORACLE_SID=+ASM3
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
#oracle用户，注意db-rac01/db-rac02的区别
```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/db_1
export ORACLE_SID=xydb1
#注意db-rac02修改
#export ORACLE_SID=xydb2
#注意db-rac03修改
#export ORACLE_SID=xydb3
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
### 2.9. 配置共享磁盘权限

#### 2.9.1.无多路径模式---本次为多路径模式--无

#适用于vsphere平台直接共享存储磁盘

#检查磁盘UUID
```bash
sfdisk -s
##由于华三超融合平台不支持scsi_id命令，只能使用udevadm，改为裸块加入iscsi高速硬盘后，支持
#/usr/lib/udev/scsi_id -g -u -d devicename
ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; udevadm info --query=all --name=$disk|grep ID_SERIAL ; done
```
#显示如下
```
#ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

[root@db-rac01 ~]# lsblk -d
NAME MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda    8:0    0    2T  0 disk 
sdb    8:16   0    2T  0 disk 
sdc    8:32   0    2T  0 disk 
sdd    8:48   0    2T  0 disk 
sde    8:64   0  100G  0 disk 
sdf    8:80   0  1.5T  0 disk 
sdg    8:96   0  100G  0 disk 
sdh    8:112  0  100G  0 disk 
sr0   11:0    1 11.2G  0 rom  
vda  251:0    0 1000G  0 disk 

[root@db-rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 36ff204468043c909acc0afa4094745b6
/dev/sdb 366960e55904821091c9025e2c7255c7f
/dev/sdc 36b0708eaa043b10a29d06927e688b365
/dev/sdd 368350b4ed049f10a9b108e152738bc3d
/dev/sde 3643a008cc04b8e0b8e109a319a118822
/dev/sdf 360b10783704bff0af2707731d9fb3cf0
/dev/sdg 36e450b2170407e0911006b92fd32de0e
/dev/sdh 366a2083ed04ba40b0470989b6a3a6a77
[root@db-rac01 ~]# 


[root@db-rac02 ~]# lsblk -d
NAME MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda    8:0    0    2T  0 disk 
sdb    8:16   0    2T  0 disk 
sdc    8:32   0    2T  0 disk 
sdd    8:48   0    2T  0 disk 
sde    8:64   0  100G  0 disk 
sdf    8:80   0  1.5T  0 disk 
sdg    8:96   0  100G  0 disk 
sdh    8:112  0  100G  0 disk 
sr0   11:0    1 11.2G  0 rom  
vda  251:0    0 1000G  0 disk 

[root@db-rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 366960e55904821091c9025e2c7255c7f
/dev/sdb 36ff204468043c909acc0afa4094745b6
/dev/sdc 368350b4ed049f10a9b108e152738bc3d
/dev/sdd 36b0708eaa043b10a29d06927e688b365
/dev/sde 36e450b2170407e0911006b92fd32de0e
/dev/sdf 360b10783704bff0af2707731d9fb3cf0
/dev/sdg 366a2083ed04ba40b0470989b6a3a6a77
/dev/sdh 3643a008cc04b8e0b8e109a319a118822
[root@db-rac02 ~]# 

```
#无法通过/usr/lib/udev/scsi_id -g -u -d  /dev/sda等创建99-oracle-asmdevices.rules
```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sda", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="368ee0625304a85085600b88ed5fa3e0e", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdb", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="367850ad2f04bb70a9fc09714a06e7684", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdc", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36c3a0087e0411209e380f43b597b12e9", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdd", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="3615b0d62c043850b6190eb2e183a3b61", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sde", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36b90096e304857085320c4edc10bee88", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdf", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36cb30cf25045830a1af0687c7a2b6ff6", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdg", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36d420575a040810bbbc0d8c0ddd708b3", OWNER="grid",GROUP="asmadmin", MODE="0660"
EOF

```

#通过第一台虚拟机生成文件，然后scp到另一台
#dev根据规则文件命名，只需要在一个节点执行，再将生成的规则文件复制到另外一个节点，这样保证两个节点产生的磁盘名一致。
#节点1：

```bash
#Unpart $name
#!/bin/bash
disk=$(lsblk -d | grep -E "sd|vd" | grep -v $(df -h | grep boot | cut -c 6-8 | head -n 1) | awk {'print $1'})
for i in $disk
do
echo "KERNEL==\"sd*\",SUBSYSTEM==\"block\", PROGRAM==\"/usr/lib/udev/scsi_id -g -u -d /dev/\$name\", RESULT==\"`/usr/lib/udev/scsi_id -g -u -d /dev/$i`\", SYMLINK+=\"asm-disk$i\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"", ATTR{queue/scheduler}=\"deadline\"   >> /etc/udev/rules.d/99-oracle-asmdevices.rules
done
start_udev > /dev/null 2>&1

```

#为了保持节点间，对同一磁盘有一样的名称，需要使用一样的规则文件。需要在一个节点生成后，传输到其他节点。
#节点1:
```bash
scp /etc/udev/rules.d/99-oracle-asmdevices.rules db-rac02:/etc/udev/rules.d/99-oracle-asmdevices.rules
```

#启动udev

```bash
/usr/sbin/partprobe

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service
```
#检查asm磁盘
```bash
ll /dev|grep asm*
```
#显示如下

```
[root@db-rac01 ~]# ll /dev/asm*
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksda -> sdb
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdb -> sda
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdc -> sdc
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdd -> sdd
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksde -> sde
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdf -> sdg
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdg -> sdh
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdh -> sdf


[root@db-rac02 ~]# ll /dev/asm*
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksda -> sda
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdb -> sdb
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdc -> sdd
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdd -> sdc
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksde -> sdh
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdf -> sde
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdg -> sdg
lrwxrwxrwx 1 root root 3 Dec  2 16:19 /dev/asm-disksdh -> sdf
```

#如果没有启动udev，可以执行以下命令
```bash
/usr/sbin/partprobe
/usr/sbin/udevadm control --reload-rules
/sbin/udevadm trigger --type=devices --action=change

ll /dev/asm*

```

#### 2.9.2.多路径模式--无

#适用于物理服务器、广交、存储多路跳线连接

#存储uuid
```
以下是oracle 卷的序列号，请按照这个顺序使用，跟存储上的名称才能对应。
data1(2TB): 2d96d1c2c86f4f6d26c9ce90079a4df08
/dev/sdf  /dev/sdm  /dev/sdt  /dev/sdaa
data2(2TB): 2086fa4c938d839c66c9ce90079a4df08
/dev/sdg  /dev/sdn  /dev/sdu  /dev/sdab
data3(2TB): 27b44daa76accbc526c9ce90079a4df08
/dev/sdh  /dev/sdao  /dev/sdv  /dev/sdac
FRA(2TB): 2f8505ff366f3732a6c9ce900b6fab6bc
/dev/sdi  /dev/sdp  /dev/sdw  /dev/sdad
OCR1(100GB): 24c740a67e89393fa6c9ce90079a4df08
/dev/sdc   /dev/sdj  /dev/sdq  /dev/sdx
OCR2(100GB): 2bf57071b2488dae06c9ce90079a4df08
/dev/sdd  /dev/sdk  /dev/sdr  /dev/sdy
OCR3(100GB): 2ee6c414e797cb16f6c9ce90079a4df08
/dev/sde  /dev/sdl  /dev/sds  /dev/sdz
```
#通过scsi_id检查
```
[root@db-rac01 ~]# sfdisk -s
/dev/sda: 468818776
/dev/sdc: 104857600
/dev/sdd: 104857600
/dev/sde: 104857600
/dev/sdf: 2147483648
/dev/sdg: 2147483648
/dev/sdh: 2147483648
/dev/sdi: 2147483648
/dev/mapper/centos-root: 419430400
/dev/sdj: 104857600
/dev/mapper/centos-swap:  33554432
/dev/sdk: 104857600
/dev/sdl: 104857600
/dev/sdm: 2147483648
/dev/sdn: 2147483648
/dev/sdo: 2147483648
/dev/sdp: 2147483648
/dev/mapper/mpatha: 104857600
/dev/mapper/mpathb: 104857600
/dev/mapper/mpathc: 104857600
/dev/mapper/mpathd: 2147483648
/dev/mapper/mpathe: 2147483648
/dev/mapper/mpathf: 2147483648
/dev/mapper/mpathg: 2147483648
/dev/sdq: 104857600
/dev/sdr: 104857600
/dev/sds: 104857600
/dev/sdt: 2147483648
/dev/sdu: 2147483648
/dev/sdv: 2147483648
/dev/sdw: 2147483648
/dev/sdx: 104857600
/dev/sdy: 104857600
/dev/sdz: 104857600
/dev/sdaa: 2147483648
/dev/sdab: 2147483648
/dev/sdac: 2147483648
/dev/sdad: 2147483648
/dev/loop0:   4601856
total: 45448942424 blocks

[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
24c740a67e89393fa6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2bf57071b2488dae06c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2ee6c414e797cb16f6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2086fa4c938d839c66c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
27b44daa76accbc526c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
24c740a67e89393fa6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2bf57071b2488dae06c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2ee6c414e797cb16f6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
2086fa4c938d839c66c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
27b44daa76accbc526c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
24c740a67e89393fa6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
2bf57071b2488dae06c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2ee6c414e797cb16f6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
2086fa4c938d839c66c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
27b44daa76accbc526c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
24c740a67e89393fa6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2bf57071b2488dae06c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2ee6c414e797cb16f6c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2086fa4c938d839c66c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
27b44daa76accbc526c9ce90079a4df08
[root@db-rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@db-rac01 ~]#

#通过循环来获取
for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4

[root@db-rac01 ~]# for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4
Device: sdab WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdg WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdn WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdu WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdc WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdj WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdq WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdx WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdac WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdh WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdo WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdv WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdad WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdi WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdp WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdw WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdd WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdk WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdr WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdy WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdaa WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sdf WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sdm WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sdt WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sde WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sdl WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sds WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sdz WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sda1 WWID: 3600508b1001c18a54136918e59858bef
Device: sda2 WWID: 3600508b1001c18a54136918e59858bef
Device: sda3 WWID: 3600508b1001c18a54136918e59858bef
Device: sda WWID: 3600508b1001c18a54136918e59858bef

[root@db-rac01 ~]# lsscsi -i
[0:0:0:0]    disk    Generic- SD/MMC CRW       1.00  /dev/sdb   Generic-_SD_MMC_CRW_29203008282014000-0:0
[1:0:0:0]    disk    Nimble   Server           1.0   /dev/sdc   24c740a67e89393fa6c9ce90079a4df08
[1:0:0:1]    disk    Nimble   Server           1.0   /dev/sdd   2bf57071b2488dae06c9ce90079a4df08
[1:0:0:2]    disk    Nimble   Server           1.0   /dev/sde   2ee6c414e797cb16f6c9ce90079a4df08
[1:0:0:3]    disk    Nimble   Server           1.0   /dev/sdf   2d96d1c2c86f4f6d26c9ce90079a4df08
[1:0:0:4]    disk    Nimble   Server           1.0   /dev/sdg   2086fa4c938d839c66c9ce90079a4df08
[1:0:0:5]    disk    Nimble   Server           1.0   /dev/sdh   27b44daa76accbc526c9ce90079a4df08
[1:0:0:6]    disk    Nimble   Server           1.0   /dev/sdi   2aa67dbb0c9c0573b6c9ce90079a4df08
[1:0:1:0]    disk    Nimble   Server           1.0   /dev/sdj   24c740a67e89393fa6c9ce90079a4df08
[1:0:1:1]    disk    Nimble   Server           1.0   /dev/sdk   2bf57071b2488dae06c9ce90079a4df08
[1:0:1:2]    disk    Nimble   Server           1.0   /dev/sdl   2ee6c414e797cb16f6c9ce90079a4df08
[1:0:1:3]    disk    Nimble   Server           1.0   /dev/sdm   2d96d1c2c86f4f6d26c9ce90079a4df08
[1:0:1:4]    disk    Nimble   Server           1.0   /dev/sdn   2086fa4c938d839c66c9ce90079a4df08
[1:0:1:5]    disk    Nimble   Server           1.0   /dev/sdo   27b44daa76accbc526c9ce90079a4df08
[1:0:1:6]    disk    Nimble   Server           1.0   /dev/sdp   2aa67dbb0c9c0573b6c9ce90079a4df08
[2:0:0:0]    enclosu HPE      Smart Adapter    3.53  -          -
[2:1:0:0]    disk    HPE      LOGICAL VOLUME   3.53  /dev/sda   3600508b1001c18a54136918e59858bef
[2:2:0:0]    storage HPE      P408i-a SR Gen10 3.53  -          -
[3:0:0:0]    disk    Nimble   Server           1.0   /dev/sdq   24c740a67e89393fa6c9ce90079a4df08
[3:0:0:1]    disk    Nimble   Server           1.0   /dev/sdr   2bf57071b2488dae06c9ce90079a4df08
[3:0:0:2]    disk    Nimble   Server           1.0   /dev/sds   2ee6c414e797cb16f6c9ce90079a4df08
[3:0:0:3]    disk    Nimble   Server           1.0   /dev/sdt   2d96d1c2c86f4f6d26c9ce90079a4df08
[3:0:0:4]    disk    Nimble   Server           1.0   /dev/sdu   2086fa4c938d839c66c9ce90079a4df08
[3:0:0:5]    disk    Nimble   Server           1.0   /dev/sdv   27b44daa76accbc526c9ce90079a4df08
[3:0:0:6]    disk    Nimble   Server           1.0   /dev/sdw   2aa67dbb0c9c0573b6c9ce90079a4df08
[3:0:1:0]    disk    Nimble   Server           1.0   /dev/sdx   24c740a67e89393fa6c9ce90079a4df08
[3:0:1:1]    disk    Nimble   Server           1.0   /dev/sdy   2bf57071b2488dae06c9ce90079a4df08
[3:0:1:2]    disk    Nimble   Server           1.0   /dev/sdz   2ee6c414e797cb16f6c9ce90079a4df08
[3:0:1:3]    disk    Nimble   Server           1.0   /dev/sdaa  2d96d1c2c86f4f6d26c9ce90079a4df08
[3:0:1:4]    disk    Nimble   Server           1.0   /dev/sdab  2086fa4c938d839c66c9ce90079a4df08
[3:0:1:5]    disk    Nimble   Server           1.0   /dev/sdac  27b44daa76accbc526c9ce90079a4df08
[3:0:1:6]    disk    Nimble   Server           1.0   /dev/sdad  2aa67dbb0c9c0573b6c9ce90079a4df08
[root@db-rac01 ~]#
```

#配置多路径配置
```bash
rpm -qa|grep device-mapper-multipath
yum install device-mapper-multipath
systemctl enable multipathd

cat >> /etc/multipath.conf  <<EOF
blacklist {
}
multipaths {
    multipath {
            wwid                    24c740a67e89393fa6c9ce90079a4df08
            alias                   mpatha
    }
    multipath {
            wwid                    2bf57071b2488dae06c9ce90079a4df08
            alias                   mpathb
    }
    multipath {
            wwid                    2ee6c414e797cb16f6c9ce90079a4df08
            alias                   mpathc
    }
    multipath {
            wwid                    2d96d1c2c86f4f6d26c9ce90079a4df08
            alias                   mpathd
    }
    multipath {
            wwid                    2086fa4c938d839c66c9ce90079a4df08
            alias                   mpathe
    }
    multipath {
            wwid                    27b44daa76accbc526c9ce90079a4df08
            alias                   mpathf
    }
    multipath {
            wwid                    2aa67dbb0c9c0573b6c9ce90079a4df08
            alias                   mpathg
    }
}
EOF


cat >> /etc/udev/rules.d/12-dm-permissions.rules <<'EOF'
ENV{DM_NAME}=="ocr1",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="ocr2",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="ocr3",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data1",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data2",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data3",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data4",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="fra",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
EOF


systemctl restart multipathd

systemctl status multipathd

multipath -ll

/sbin/udevadm trigger --type=devices --action=change

ll /dev|grep asm
```
### 2.10. 配置互信

#grid用户
```bash
su - grid

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在db-rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh db-rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh db-rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys db-rac02:~/.ssh/authorized_keys

ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date -Ins;ssh db-rac02 date -Ins;ssh db-rac01-prv date -Ins;ssh db-rac02-prv date -Ins
#在db-rac02执行
ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date -Ins;ssh db-rac02 date -Ins;ssh db-rac01-prv date -Ins;ssh db-rac02-prv date -Ins
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在db-rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh db-rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh db-rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys db-rac02:~/.ssh/authorized_keys

ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date -Ins;ssh db-rac02 date -Ins;ssh db-rac01-prv date -Ins;ssh db-rac02-prv date -Ins

#在db-rac02上执行
ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date;ssh db-rac02 date;ssh db-rac01-prv date;ssh db-rac02-prv date

ssh db-rac01 date -Ins;ssh db-rac02 date -Ins;ssh db-rac01-prv date -Ins;ssh db-rac02-prv date -Ins
```

## 3 开始安装 grid

### 3.1. 上传集群软件包
```bash
#注意不同的用户
[root@db-rac01 storage]# ll -rth
-rwxr-xr-x 1 grid oinstall 2.7G Jan 28 15:58 LINUX.X64_193000_grid_home.zip
-rwxr-xr-x 1 oracle oinstall 2.9G Jan 28 16:38 LINUX.X64_193000_db_home.zip
```
### 3.2. 解压 grid 安装包

```bash
#在 19C 中需要把 grid 包解压放到 grid 用户下 ORACLE_HOME 目录内(/u01/app/19.0.0/grid)
#只在节点一上做解压缩
#如果节点二上也做了解压缩，必须全部删除，ls -a , rm -rfv ./* , rm -rfv ./opatch*, rm -rfv ./patch*
[grid@db-rac01 ~]$ cd /u01/app/19.0.0/grid
[grid@db-rac01 grid]$ unzip -oq /u01/Storage/LINUX.X64_193000_grid_home.zip

#安装cvuqdisk包
cd /u01/app/19.0.0/grid/cv/rpm
cp cvuqdisk-1.0.10-1.rpm /u01
scp cvuqdisk-1.0.10-1.rpm db-rac02:/u01

#两台服务器都安装
su - root
cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm

#节点一安装前检查：
[grid@db-rac01 ~]$ cd /u01/app/19.0.0/grid/
[grid@db-rac01 grid]$ ./runcluvfy.sh stage -pre crsinst -n db-rac01,db-rac02 -verbose | tee -a pre1.log
```

#error检查
```
#如果执行该命令时卡住，半天没反应，可能是scp报错了，解决办法见下面

#可以忽略的
ERROR:
PRVG-10467 : The default Oracle Inventory group could not be determined.

Verifying Network Time Protocol (NTP) ...FAILED (PRVG-1017)
Verifying resolv.conf Integrity ...FAILED (PRVG-10048)

#centos7可以忽略：
Verifying /dev/shm mounted as temporary file system ...FAILED (PRVE-0421)
Verifying /dev/shm mounted as temporary file system ...FAILED
db-rac02: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm

db-rac01: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm
```

#安装xterm
```bash
yum install -y xterm*
#如果提示：已拒绝X11转移申请，那么安装xorg-x11-xauth
yum install -y xorg-x11-xauth
#或者本地镜像需挨着安装包
yum install -y xorg-x11-xkb-utils
rpm -ivh xorg-x11-xkb-utils-7.7-14.el7.x86_64.rpm
rpm -ivh xorg-x11-xauth-1.0.9-1.el7.x86_64.rpm
rpm -ivh xterm-295-3.el7.x86_64.rpm

#本地打开xstart
#用grid账户通过ssh登录
#命令为/usr/bin/xterm -ls -display $DISPLAY
```
### 3.3. 进入 grid 集群软件目录执行安装
```bash
cd /u01/app/19.0.0/grid/
[grid@db-rac01 grid]$ ./gridSetup.sh
```
#报错处理
```
[INS-08101] Unexpected error while executing the action at state: 'supportedOSCheck'
```
```
办法一：临时解决
export CV_ASSUME_DISTID=OEL8.1
办法二：永久解决
vi $ORACLE_HOME/cv/admin/cvu_config
在#CV_ASSUME_DISTID=OEL5该行下添加一行：
CV_ASSUME_DISTID=OEL8.1
```

### 3.4. GI 安装步骤
#安装过程如下
```
1. 为新的集群配置GI(configure oracle grid infrastructure for a New Cluster)
2. 配置独立的集群(configure an oracle standalone cluster)
3. 配置集群名称以及 scan 名称(rac-cluster/rac-scan/1521)
4. 添加节点2并测试节点互信(Add db-rac02/db-rac02-vip, test for SSH connectivity)
5. 公网、私网网段选择(eth1-172.16.134.0-ASM&private/eth0-10.251.252.0-public)
6. 选择 asm 存储(use oracle flex ASM for storage)
7. 选择不单独为GIMR配置磁盘组
8. 选择 asm 磁盘组(ORC/normal/100G三块磁盘)
9. 输入密码Ora543Cle
10. 保持默认No IPMI
11. 保持默认No EM
12. 默认用户组asmadmin/asmdba/asmoper
13. 确认 base 目录$ORACLE_BASE(/u01/app/grid)
14. Inventory Directory: /u01/app/orainventory
15. 这里可以选择自动 root 执行脚本,不自动执行,不选
16. 预安装检查
    解决相关依赖后，忽略如下报错
    如下警告可以忽略-警告是由于没有使用 DNS 解析造成可忽略
17. installer
18. 执行 root 脚本.
    先在db-rac01上执行完毕,再去db-rac02执行
    执行完毕后,点击OK
    INS-20802 oracle cluster verification utility failed---OK
    Next
    INS-43080----YES
19. Close     
```
#报错处理，如果在ssh互信时报错
```
[INS-06006] Passwordless SSH connectivity not set up between the following nodes(s)
```
#可以通过root账户用以下命令临时解决
```bash
# Rename the original scp
mv /usr/bin/scp /usr/bin/scp.orig

# Create a new file scp
echo "/usr/bin/scp.orig -T \$*" > /usr/bin/scp

# Make the file executable
chmod a+rx /usr/bin/scp

# 查看scp的内容
cat /usr/bin/scp
/usr/bin/scp.orig -T $*
```

#全部装好数据库后，可以恢复scp
```
# Delete interim scp
rm /usr/bin/scp

# Restore the original scp.
mv /usr/bin/scp.orig /usr/bin/scp
```


#报错处理，安装进度到了5%的时候出现
###以下两个报错均是lib中文件的软链接出现了问题导致的
```
###第一个报错：libclntsh.so报错
INFO:
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libclntsh.so: file format not recognized; treating as linker script
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libclntsh.so:1: syntax error

INFO:
make[2]: *** [dlopenlib] Error 1

INFO:
make[2]: Leaving directory `/u01/app/19.0.0/grid/rdbms/lib'

INFO:
make[1]: Leaving directory `/u01/app/19.0.0/grid/rdbms/lib'

INFO:
make[1]: *** [/u01/app/19.0.0/grid/lib/libasmperl19.so] Error 2

INFO:
make: *** [libasmperl19.ohso] Error 2

INFO: End output from spawned process.
INFO: ----------------------------------
INFO: Exception thrown from action: make
Exception Name: MakefileException
Exception String: Error in invoking target 'libasmclntsh19.ohso libasmperl19.ohso client_sharedlib' of makefile '/u01/app/19.0.0/grid/rdbms/lib/ins_rdbms.mk'. See '/tmp/GridSetupActions2022-10-20_03-47-30PM/gridSetupActions2022-10-20_03-47-30PM.log' for details.
Exception Severity: 1

###第二个报错：libodm19.so
INFO:
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libodm19.so: file format not recognized; treating as linker script
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libodm19.so:1: syntax error

INFO:
make: *** [/u01/app/19.0.0/grid/rdbms/lib/oracle] Error 1

INFO: End output from spawned process.
INFO: ----------------------------------
INFO: Exception thrown from action: make
Exception Name: MakefileException
Exception String: Error in invoking target 'irman ioracle' of makefile '/u01/app/19.0.0/grid/rdbms/lib/ins_rdbms.mk'. See '/tmp/GridSetupActions2022-10-20_03-47-30PM/gridSetupActions2022-10-20_03-47-30PM.log' for details.
Exception Severity: 1
```

#解决办法
```
#通过root账户，将grid文件重新解压缩，可以看到相关的正确软链接文件
cd /u01/app/tmp/
unzip -oq /u01/Storage/LINUX.X64_193000_grid_home.zip
cd lib

[root@db-rac02 grid]# cd lib/
[root@db-rac02 lib]# ll|grep ^l
lrwxrwxrwx 1 root root        15 Oct 20 16:00 libagtsh.so -> libagtsh.so.1.0
lrwxrwxrwx 1 root root        21 Oct 20 16:00 libclntshcore.so -> libclntshcore.so.19.1
lrwxrwxrwx 1 root root        17 Oct 20 16:00 libclntsh.so -> libclntsh.so.19.1
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.10.1 -> libclntsh.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.11.1 -> libclntsh.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.12.1 -> libclntsh.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.18.1 -> libclntsh.so
lrwxrwxrwx 1 root root        36 Oct 20 16:00 libjavavm19.a -> ../javavm/jdk/jdk8/lib/libjavavm19.a
lrwxrwxrwx 1 root root        15 Oct 20 16:00 libocci.so -> libocci.so.19.1
lrwxrwxrwx 1 root root        10 Oct 20 16:00 libocci.so.18.1 -> libocci.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libodm19.so -> libodmd19.so


[root@db-rac02 lib]# ls -l libcln*
lrwxrwxrwx 1 root root       21 Oct 20 16:00 libclntshcore.so -> libclntshcore.so.19.1
-rwxr-xr-x 1 root root  8040416 Apr 18  2019 libclntshcore.so.19.1
lrwxrwxrwx 1 root root       17 Oct 20 16:00 libclntsh.so -> libclntsh.so.19.1
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.10.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.11.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.12.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.18.1 -> libclntsh.so
-rwxr-xr-x 1 root root 79927312 Apr 18  2019 libclntsh.so.19.1

[root@db-rac02 lib]# ll|grep libodm
-rw-r--r-- 1 root root     10594 Apr 17  2019 libodm19.a
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libodm19.so -> libodmd19.so
-rw-r--r-- 1 root root     17848 Apr 17  2019 libodmd19.so
[root@db-rac02 lib]#

-------------------------------------------
#检查grid账户下正常解压缩文件，发现软连接文件成了正常文件，但是大小还是12
cd /u01/app/19.0.0.0/grid/lib
[grid@db-rac02 lib]$ ll|grep ^l
lrwxrwxrwx  1 grid oinstall        15 Oct 20 16:10 libagtsh.so -> libagtsh.so.1.0
lrwxrwxrwx  1 grid oinstall        10 Oct 20 16:10 libocci.so.18.1 -> libocci.so

[grid@db-rac02 lib]$ ls -l  libcln*
-rwxr-xr-x. 1 grid oinstall       21 Oct 20 15:16 libclntshcore.so
-rwxr-xr-x. 1 grid oinstall  8040416 Oct 20 15:16 libclntshcore.so.19.1
-rwxr-xr-x. 1 grid oinstall       17 Oct 20 15:16 libclntsh.so
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.10.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.11.1
-rwxr-x---. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.12.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.18.1
-rwxr-xr-x. 1 grid oinstall 79927312 Oct 20 15:16 libclntsh.so.19.1

[grid@db-rac02 lib]$ ls -l|grep libjavavm19
-rwxr-xr-x. 1 grid oinstall        36 Oct 20 15:16 libjavavm19.a
[grid@db-rac02 lib]$ ls -l|grep libodm
-rw-r--r--. 1 grid oinstall     10594 Oct 20 15:16 libodm19.a
-rwxr-xr-x. 1 grid oinstall        12 Oct 20 15:16 libodm19.so
-rw-r--r--. 1 grid oinstall     17848 Oct 20 15:16 libodmd19.so

#解决办法：
#删除相关报错文件，重新建立软链接，然后在安装图形界面，点击重试即可

rm -rfv libclntshcore.so libclntsh.so libclntsh.so.10.1 libclntsh.so.11.1 libclntsh.so.12.1 libclntsh.so.18.1
ln -s libclntshcore.so.19.1 libclntshcore.so
ln -s libclntsh.so.19.1 libclntsh.so
ln -s libclntsh.so libclntsh.so.10.1
ln -s libclntsh.so libclntsh.so.11.1
ln -s libclntsh.so libclntsh.so.12.1
ln -s libclntsh.so libclntsh.so.18.1

rm -rfv libjavavm19.a libodm19.so
ln -s libodmd19.so libodm19.so
ln -s ../javavm/jdk/jdk8/lib/libjavavm19.a libjavavm19.a
```


#执行root脚本日志如下
```
[root@db-rac01 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@db-rac01 ~]# /u01/app/19.0.0/grid/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/app/19.0.0/grid

Enter the full pathname of the local bin directory: [/usr/local/bin]:
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/db-rac01/crsconfig/rootcrs_db-rac01_2022-08-12_11-09-12PM.log
2022/03/09 18:11:12 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2022/03/09 18:11:12 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2022/03/09 18:11:12 CLSRSC-363: User ignored prerequisites during installation
2022/03/09 18:11:12 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2022/03/09 18:11:14 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2022/03/09 18:11:14 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2022/03/09 18:11:15 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2022/03/09 18:11:15 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2022/03/09 18:11:25 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2022/03/09 18:11:28 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2022/03/09 18:11:34 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2022/03/09 18:11:40 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2022/03/09 18:11:40 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2022/03/09 18:11:44 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2022/03/09 18:11:44 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2022/03/09 18:12:05 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2022/03/09 18:12:09 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2022/03/09 18:12:13 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2022/03/09 18:12:17 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.

ASM has been created and started successfully.

[DBT-30001] Disk groups created successfully. Check /u01/app/grid/cfgtoollogs/asmca/asmca-220309PM061249.log for details.

2022/03/09 18:13:35 CLSRSC-482: Running command: '/u01/app/19.0.0/grid/bin/ocrconfig -upgrade grid oinstall'
CRS-4256: Updating the profile
Successful addition of voting disk 963be5e020964f73bfc4e8810d4d2d72.
Successful addition of voting disk 0cad1112ce4a4f21bf7fb68c81659713.
Successful addition of voting disk 37518f8cb4ed4fd5bf79d54a331cec28.
Successfully replaced voting disk group with +OCR.
CRS-4256: Updating the profile
CRS-4266: Voting file(s) successfully replaced
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   963be5e020964f73bfc4e8810d4d2d72 (/dev/dm-2) [OCR]
 2. ONLINE   0cad1112ce4a4f21bf7fb68c81659713 (/dev/dm-3) [OCR]
 3. ONLINE   37518f8cb4ed4fd5bf79d54a331cec28 (/dev/dm-4) [OCR]
Located 3 voting disk(s).
2022/03/09 18:14:58 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2022/03/09 18:16:04 CLSRSC-343: Successfully started Oracle Clusterware stack
2022/03/09 18:16:04 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2022/03/09 18:17:06 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2022/03/09 18:17:27 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded

[root@db-rac02 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
You have new mail in /var/spool/mail/root
[root@db-rac02 ~]# /u01/app/19.0.0/grid/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/app/19.0.0/grid

Enter the full pathname of the local bin directory: [/usr/local/bin]:
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/db-rac02/crsconfig/rootcrs_db-rac02_2022-03-09_06-18-12PM.log
2022/03/09 18:18:15 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2022/03/09 18:18:15 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2022/03/09 18:18:15 CLSRSC-363: User ignored prerequisites during installation
2022/03/09 18:18:15 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2022/03/09 18:18:16 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2022/03/09 18:18:16 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2022/03/09 18:18:16 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2022/03/09 18:18:16 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2022/03/09 18:18:17 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2022/03/09 18:18:17 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2022/03/09 18:18:25 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2022/03/09 18:18:25 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2022/03/09 18:18:26 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2022/03/09 18:18:26 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2022/03/09 18:18:37 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2022/03/09 18:18:44 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2022/03/09 18:18:45 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2022/03/09 18:18:46 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2022/03/09 18:18:47 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2022/03/09 18:18:55 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2022/03/09 18:19:41 CLSRSC-343: Successfully started Oracle Clusterware stack
2022/03/09 18:19:41 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2022/03/09 18:19:50 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2022/03/09 18:19:55 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```
## 创建 ASM 数据磁盘
### 4.1. grid 账户登录图形化界面，执行 asmca
#创建asm磁盘组步骤
```
1. DiskGroups界面点击Create
2. DATA/External/(/dev/sdd、/dev/sde、/dev/sdf)，点击OK
3. 继续点击Create
4. FRA/External/(/dev/sdg)，点击OK
5. Exit
```
### 4.2 查看状态
```
[grid@db-rac01 grid]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
ora.chad
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
ora.net1.network
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
ora.ons
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 Started,STABLE
      2        ONLINE  ONLINE       db-rac02                 Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac01.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac02.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.qosmserver
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
--------------------------------------------------------------------------------


sqlplus / as sysasm

db-rac02:
SQL> select name,path from v$asm_disk;

NAME			       PATH
------------------------------ 
DATA_0002		       /dev/sdc
DATA_0003		       /dev/sdg
FRA_0000		       /dev/sdf
DATA_0000		       /dev/sda
DATA_0001		       /dev/sdb
OCR_0001		       /dev/sdd
OCR_0000		       /dev/sdh
OCR_0002		       /dev/sde

8 rows selected.

SQL> 

db-rac01:
SQL> set linesize 300
SQL> select name,path from v$asm_disk;

NAME			       PATH
------------------------------ 
OCR_0002		       /dev/sdg
DATA_0000		       /dev/sda
DATA_0002		       /dev/sdc
OCR_0001		       /dev/sdf
DATA_0003		       /dev/sdd
OCR_0000		       /dev/sde
DATA_0001		       /dev/sdb
FRA_0000		       /dev/sdh

8 rows selected.

SQL> 

```
## 5 安装 Oracle 数据库软件
#以 Oracle 用户登录图形化界面，将数据库软件解压至$ORACLE_HOME 
```bash
[oracle@db-rac01 db_1]$ pwd
/u01/app/oracle/product/19.0.0/db_1
[oracle@db-rac01 db_1]$ unzip -oq /u01/storage/LINUX.X64_193000_db_home.zip
```
#通过xstart图形化连接服务器，同Grid连接方式

```bash
[oracle@db-rac01 db_1]$ ./runInstaller
```
#报错处理
```
[INS-08101] Unexpected error while executing the action at state: 'supportedOSCheck'
```
```
办法一：临时解决
export CV_ASSUME_DISTID=OEL8.1
办法二：永久解决
vi $ORACLE_HOME/cv/admin/cvu_config
在#CV_ASSUME_DISTID=OEL5该行下添加一行：
CV_ASSUME_DISTID=OEL8.1
```

### 5.1. oracle software安装步骤
#安装过程如下

```
1. 仅设置software(set up software only)
2. oracle RAC
3. SSH互信测试
4. Enterprise Edition
5. $ORACLE_BASE(/u01/app/oracle)
6. 用户组，保持默认(dba/oper/backupdba/dgdba/kmdba/racdba)
7. 不执行配置脚本，保持默认
8. 忽略全部(scan/rac-scan)--->Yes
9. Install
10. root账户先在db-rac01执行完毕后再在db-rac02上执行脚本(/u01/app/oracle/product/19.0.0/db_1/root.sh)，然后点击OK
11. Close
```
#执行root.sh脚本记录
```
[root@db-rac01 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/19.0.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]:
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.

[root@db-rac02 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/19.0.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]:
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
```

## 6 建立数据库
以 oracle 账户登录。
### 6.1. 执行建库 dbca
#创建RAC数据库步骤
```
1. Create a database
2. Advanced Configuration
3. RAC/Admin Managed/General Purpose
4. Select All
5. xydb/xydb/Create as Container database/Use Local Undo tbs for PDBs/pdb:1/pdbname:portal
6. AMS:+DATA/{DB_UNIQUE_NAME}/Use OMF
7. ASM/+FRA/+FRA free space(点击Browse查看：1535868)/Enable archiving
8. 数据库组件，保持默认不选(Vault/Label Security)
9. ASMM自动共享内存管理
       #sga=memory*65%*75%=256G*65%*75%=129.1875G(向下十位取整为129G)
       #pga=memory*65%*25%=512G*65%*25%=43.0625G(向下十位取整为43G)
       
   Sizing: block size: 8192/processes: 3000
   Character Sets: AL32UTF8
   Connection mode: Dadicated server mode--->Next
10. 运行CVU和关闭EM
11. 使用相同密码Ora543Cle
12. 勾选：create database
13. Ignore all--->Yes
14. Finish
15. Close

```
### 6.2. 查看集群状态
```
[root@db-rac01 db_1]# cd
[root@db-rac01 ~]# . oraenv
ORACLE_SID = [root] ? +ASM1
ORACLE_HOME = [/home/oracle] ? /u01/app/19.0.0/grid
The Oracle base has been set to /u01/app/grid
[root@db-rac01 ~]# crsctl enable crs
CRS-4622: Oracle High Availability Services autostart is enabled.
[root@db-rac01 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
ora.chad
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
ora.net1.network
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
ora.ons
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 Started,STABLE
      2        ONLINE  ONLINE       db-rac02                 Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac01.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac02.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.qosmserver
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.xydb.db
      1        ONLINE  ONLINE       db-rac01                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       db-rac02                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
--------------------------------------------------------------------------------
[root@db-rac01 ~]# 



[root@db-rac01 ~]#  srvctl config database -d xydb
Database unique name: xydb
Database name: xydb
Oracle home: /u01/app/oracle/product/19.0.0/db_1
Oracle user: oracle
Spfile: +DATA/XYDB/PARAMETERFILE/spfile.272.1122668865
Password file: +DATA/XYDB/PASSWORD/pwdxydb.256.1122667929
Domain: 
Start options: open
Stop options: immediate
Database role: PRIMARY
Management policy: AUTOMATIC
Server pools: 
Disk Groups: FRA,DATA
Mount point paths: 
Services: 
Type: RAC
Start concurrency: 
Stop concurrency: 
OSDBA group: dba
OSOPER group: oper
Database instances: xydb1,xydb2
Configured nodes: db-rac01,db-rac02
CSS critical: no
CPU count: 0
Memory target: 0
Maximum memory: 0
Default network number for database services: 
Database is administrator managed
[root@db-rac01 ~]# 
```
### 6.3. 查看数据库版本
```
[oracle@db-rac01 db_1]$ sqlplus / as sysdba
SQL> col banner_full for a120
SQL> select BANNER_FULL from v$version;

BANNER_FULL
--------------------------------------------------------------------------------
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select INST_NUMBER,INST_NAME FROM v$active_instances;

INST_NUMBER INST_NAME
----------- ----------------------------------------------
	  1 db-rac01:xydb1
	  2 db-rac02:xydb2

SQL> SELECT instance_name, host_name FROM gv$instance;

INSTANCE_NAME	 HOST_NAME
---------------- --------------------------------
xydb1		 db-rac01
xydb2		 db-rac02

SQL> 

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
------------------------------------------- ------------------------------
+DATA/XYDB/TEMPFILE/temp.264.1122668107 					 TEMP

SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME											     TABLESPACE_NAME
---------------------------------                     ------------------------------
+DATA/XYDB/DATAFILE/system.257.1122667951							     SYSTEM
+DATA/XYDB/DATAFILE/sysaux.258.1122667985							     SYSAUX
+DATA/XYDB/DATAFILE/undotbs1.259.1122668011							     UNDOTBS1
+DATA/XYDB/DATAFILE/users.260.1122668011							     USERS
+DATA/XYDB/DATAFILE/undotbs2.269.1122668541							     UNDOTBS2

SQL> 

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 PORTAL			  READ WRITE NO
SQL> 
SQL> alter session set container=PORTAL;

Session altered.

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------- ------------------------------
+DATA/XYDB/EF14DB5CE59D2D91E053018610AC1806/TEMPFILE/temp.276.1122669049	 TEMP

SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME											     TABLESPACE_NAME
---------------------------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/EF14DB5CE59D2D91E053018610AC1806/DATAFILE/system.274.1122669049			     SYSTEM
+DATA/XYDB/EF14DB5CE59D2D91E053018610AC1806/DATAFILE/sysaux.275.1122669049			     SYSAUX
+DATA/XYDB/EF14DB5CE59D2D91E053018610AC1806/DATAFILE/undotbs1.273.1122669049			     UNDOTBS1
+DATA/XYDB/EF14DB5CE59D2D91E053018610AC1806/DATAFILE/undo_2.277.1122669059			     UNDO_2
+DATA/XYDB/EF14DB5CE59D2D91E053018610AC1806/DATAFILE/users.278.1122669061			     USERS

SQL> 


```
### 6.4. Oracle RAC数据库优化
#user password life修改，一个节点修改即可(CDB/PDB)
```oracle
select resource_name,limit from dba_profiles where profile='DEFAULT';
alter profile default limit password_life_time unlimited;
ALTER PROFILE DEFAULT limit FAILED_LOGIN_ATTEMPTS unlimited;

select resource_name,limit from dba_profiles where profile='DEFAULT';
```
#允许oracle低版本连接，两个节点都要修改
```
su - oracle
cd $ORACLE_HOME/network/admin
vi sqlnet.ora

SQLNET.ALLOWED_LOGON_VERSION_SERVER=8
SQLNET.ALLOWED_LOGON_VERSION_CLIENT=8
```
#数据库自启动
```
su - root
cd /u01/app/19.0.0/grid/bin
./crsctl enable crs
```
#PDB自启动
#方法一
```oracle
CREATE OR REPLACE TRIGGER open_pdbs
  AFTER STARTUP ON DATABASE
BEGIN
   EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
END open_pdbs;
/
```
#方法二
```oracle
alter pluggable database all open instances=all;
alter pluggable database all save state instances=all;
```
##创建service
```oracle
su - oracle

srvctl add service -d xydb -s s_portal -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb portal

srvctl start service -d xydb -s s_portal

lsnrctl status 
```

##连接方式
```oracle
SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 DATAASSETS			  READ WRITE NO
SQL> alter session set container=DATAASSETS;

Session altered.

SQL> grant dba to pdbadmin;

Grant succeeded.

SQL> exit
#sqlplus pdbadmin/pdbadmin@172.16.134.8:1521/s_dataassets
[oracle@db-rac02 ~]$ sqlplus pdbadmin/pdbadmin@172.16.134.8:1521/s_dataassets

SQL*Plus: Release 19.0.0.0.0 - Production on Mon Mar 14 15:54:42 2022
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Last Successful login time: Mon Mar 14 2022 15:54:30 +08:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select count(*) from dba_objects;

  COUNT(*)
----------
     72490

SQL> exit

```

#rman备份
#创建脚本目录
```bash
su - oracle
mkdir /home/oracle/rmanbak
```
#/home/oracle/rmanbak/rmanbak.sh
```bash
#!/bin/bash

time=$(date +"%Y%m%d")
rman_dir=/home/oracle/rmanbak

if [ -f $HOME/.bash_profile ]; then
    . $HOME/.bash_profile
elif [ -f $HOME/.profile ]; then
        . $HOME/.profile
fi

echo `date` > $rman_dir/rmanrun.log
  
rman target / log=$rman_dir/rmanfullbak_$time.log append <<EOF
run{
   CONFIGURE CONTROLFILE AUTOBACKUP ON;
   CONFIGURE BACKUP OPTIMIZATION ON;
   allocate channel c1 type disk;
   allocate channel c2 type disk;
   allocate channel c3 type disk;
   allocate channel c4 type disk;
   alter system archive log current;
   backup as compressed backupset database plus archivelog delete all input; 
   alter system archive log current;
   backup archivelog all;
   crosscheck backup;
   delete noprompt obsolete;
   delete noprompt expired backup;
   release channel c1;
   release channel c2;
   release channel c3;
   release channel c4;
}
exit;
EOF
 >> $rman_dir/rmanrun.log
#delete 7days before log 
find $rman_dir -name 'rmanfullbak_*.log' -mtime +7 -exec rm {} \;
echo `date ` >> $rman_dir/rmanrun.log
```
#定时脚本crontab -l
```bash
30 0 * * * /home/oracle/rmanbak/rmanbak.sh
```
#数据泵导出、导入
```bash
#创建目录，两个节点都必须创建该目录
mkdir /home/oracle/expdir
```
```oracle
#创建directory
create directory expdir as '/home/oracle/expdir';
grant read,write on directory expdir to public;

##expdp
#导出某个用户,IP地址用scanIP时，注意导出文件在哪一个节点
expdp test1/test1@172.16.134.8:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n
#导出全库
expdp pdbadmin/pdbadmin@172.16.134.8:1521/s_dataassets full=y directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp
impdp est1/test1@172.16.134.8:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp--remap
impdp  est1/test1@172.16.134.8:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n   remap_schema=test2:test1 remap_tablespace=test2:test1  logfile=test01.log cluster=n

#expdp-12.2.0.1.0
expdp test1/test1@172.16.134.8:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n compression=data_only version=12.2.0.1.0

#脚本

#!/bin/bash
source /etc/profile
source /home/oracle/.bash_profile

now=`date +%y%m%d`
dmpfile=dataassets_db$now.dmp
logfile=dataassets_db$now.log

echo start exp $dmpfile ...


expdp pdbadmin/pdbadmin@172.16.134.8:1521/s_dataassets full=y directory=expdir dumpfile=$dmpfile logfile=$logfile cluster=n 



echo delete local file ...
find /home/oracle/expdir -name "*.dmp" -mtime +5 -exec rm {} \;
find /home/oracle/expdir -name "*.log" -mtime +5 -exec rm {} \;

echo finish bak job

```
### 6.5. Oracle RAC其他操作
#创建pdb
```oracle
create pluggable database dataassets admin user pdbadmin identified by J3my3xl4c12ed roles=(dba);
alter pluggable database dataassets open;
alter pluggable database all save state instances=all;



alter session set container=dataassets;

create tablespace pdb1user datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

alter tablespace pdb1user add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create user user1 identified by user1 default tablespace pdb1user account unlock;

grant dba to user1;
grant select any table to user1;
```
#连接方式
```bash
srvctl add service -d xydb -s s_dataassets -r xydb1,xydb2,xydb3 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets

srvctl start service -d xydb -s s_dataassets
srvctl status service -d xydb -s s_dataassets

sqlplus pdbadmin/J3my3xl4c12ed@172.16.134.9:1521/s_dataassets
```

### 6.8. Oracle RAC更改PDB的字符集
```
 SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 JMUPDB			  READ WRITE NO
	 4 DATAASSETS			  READ WRITE NO
	 5 EOTQPDB			  READ WRITE NO
	 6 EAMSPDB			  READ WRITE NO
	 7 CWPDB			  READ WRITE NO
	 8 RPTPDB			  READ WRITE NO
	 9 HRPDB			  READ WRITE NO

SQL> alter pluggable database hrpdb close immediate instances=all;

Pluggable database altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 JMUPDB			  READ WRITE NO
	 4 DATAASSETS			  READ WRITE NO
	 5 EOTQPDB			  READ WRITE NO
	 6 EAMSPDB			  READ WRITE NO
	 7 CWPDB			  READ WRITE NO
	 8 RPTPDB			  READ WRITE NO
	 9 HRPDB			  MOUNTED
SQL> alter pluggable database hrpdb  open read write restricted;

Pluggable database altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 JMUPDB			  READ WRITE NO
	 4 DATAASSETS			  READ WRITE NO
	 5 EOTQPDB			  READ WRITE NO
	 6 EAMSPDB			  READ WRITE NO
	 7 CWPDB			  READ WRITE NO
	 8 RPTPDB			  READ WRITE NO
	 9 HRPDB			  READ WRITE YES
SQL> alter session set container=hrpdb;

Session altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
----------------------------------------------------
AMERICAN_AMERICA.AL32UTF8

SQL> alter database character set internal_use ZHS16GBK;

Database altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
--------------------------------------------------------------------------------
AMERICAN_AMERICA.ZHS16GBK

SQL> alter pluggable database hrpdb close immediate;

Pluggable database altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 9 HRPDB			  MOUNTED
SQL> alter pluggable database hrpdb open instances=all;

Pluggable database altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
--------------------------------------------------------------------------------
AMERICAN_AMERICA.ZHS16GBK

SQL> alter session set container=jmupdb;

Session altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
----------------------------------------------------
AMERICAN_AMERICA.AL32UTF8

SQL> 

```

## 7 部署第三个节点

### 7.1. 根据前面内容做好节点三的优化、grid/oracle配置、ssh互信等
#节点三root下修改scp
```
# Rename the original scp
mv /usr/bin/scp /usr/bin/scp.orig

# Create a new file scp
echo "/usr/bin/scp.orig -T \$*" > /usr/bin/scp

# Make the file executable
chmod a+rx /usr/bin/scp

# 查看scp的内容
cat /usr/bin/scp
/usr/bin/scp.orig -T $*
```

#配置共享磁盘

#为了保持节点间，对同一磁盘有一样的名称，需要使用一样的规则文件。需要在一个节点生成后，传输到其他节点。
#节点1:

```bash
scp /etc/udev/rules.d/99-oracle-asmdevices.rules db-rac03:/etc/udev/rules.d/99-oracle-asmdevices.rules
```

#启动udev

```bash
/usr/sbin/partprobe

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service
```
#检查asm磁盘
```bash
ll /dev|grep asm*
```

#配置互信
#db-rac03:

```bash
su - grid

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

su - oracle

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa
```
#db-rac01:
#grid/oracle
```bash
ssh db-rac03 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys db-rac02:~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys db-rac03:~/.ssh/authorized_keys
```
#db-rac01/db-rac02/db-rac03:
#grid/oracle
```bash
ssh db-rac01 date;ssh db-rac02 date;ssh db-rac03 date;ssh db-rac01-prv date;ssh db-rac02-prv date;ssh db-rac03-prv date
```

### 7.2. 安装前检查
```bash
su - grid
cd $ORACLE_HOME/
./runcluvfy.sh comp peer -refnode db-rac01 -n db-rac03 -verbose
```
#看到结果
```
Verifying Peer Compatibility ...PASSED

Verification of peer compatibility was successful. 
```


```bash
su - grid
cd $ORACLE_HOME/
 ./runcluvfy.sh  stage -pre nodeadd -n db-rac03 -fixup -verbose
```

#看到以下有关共享磁盘的报错，可以忽略，继续安装
```
Verifying Device Checks for ASM ...
  Verifying Package: cvuqdisk-1.0.10-1 ...PASSED
  Verifying ASM device sharedness check ...
    Verifying Shared Storage Accessibility:/dev/sda,/dev/sdb,/dev/sdc,/dev/sde,/dev/sdh,/dev/sdd,/dev/sdf,/dev/sdg ...FAILED (PRVG-0806)

  Device                                Device Type             
  ------------------------------------  ------------------------
  /dev/sdh                              Disk                    
  /dev/sdg                              Disk                    
  /dev/sdf                              Disk                    
  /dev/sdc                              Disk                    
PRVG-10487 : Storage "/dev/sda" is not shared on all nodes.
PRVG-10487 : Storage "/dev/sde" is not shared on all nodes.
PRVG-10487 : Storage "/dev/sdd" is not shared on all nodes.
PRVG-10487 : Storage "/dev/sdb" is not shared on all nodes.
  Verifying ASM device sharedness check ...FAILED (PRVG-0806)


Failures were encountered during execution of CVU verification request "stage -pre nodeadd".

Verifying Device Checks for ASM ...FAILED
  Verifying ASM device sharedness check ...FAILED
    Verifying Shared Storage
    Accessibility:/dev/sda,/dev/sdb,/dev/sdc,/dev/sde,/dev/sdh,/dev/sdd,/dev/sdf
    ,/dev/sdg ...FAILED
    PRVG-0806 : Signature for storage path "/dev/sda" is inconsistent across
    the nodes.
    Signature was found as "36ff204468043c909acc0afa4094745b6|" on nodes:
    "db-rac03".
    Signature was found as "366960e55904821091c9025e2c7255c7f|" on nodes:
    "db-rac01".
    PRVG-0806 : Signature for storage path "/dev/sdb" is inconsistent across
    the nodes.
    Signature was found as "36ff204468043c909acc0afa4094745b6|" on nodes:
    "db-rac01".
    Signature was found as "366960e55904821091c9025e2c7255c7f|" on nodes:
    "db-rac03".
    PRVG-0806 : Signature for storage path "/dev/sde" is inconsistent across
    the nodes.
    Signature was found as "3643a008cc04b8e0b8e109a319a118822|" on nodes:
    "db-rac03".
    Signature was found as "368350b4ed049f10a9b108e152738bc3d|" on nodes:
    "db-rac01".
    PRVG-0806 : Signature for storage path "/dev/sdd" is inconsistent across
    the nodes.
    Signature was found as "3643a008cc04b8e0b8e109a319a118822|" on nodes:
    "db-rac01".
    Signature was found as "368350b4ed049f10a9b108e152738bc3d|" on nodes:
    "db-rac03".
```

### 7.3. 在节点一上开始添加节点三的GI

#节点一db-rac01上执行，xterm连接grid用户

```bash
cd $ORACLE_HOME
./gridSetup.sh
```
#安装过程
```
Add more nodes to the cluster--->Add：db-rac03/db-rac03-vip--->SSH connectivity、Test--->Ignore all--->submit--->db-rac03root执行脚本：/u01/app/oraInventory/orainstRoot.sh /u01/app/19.0.0/grid/root.sh-->Close
```

#脚本结果
```
[root@db-rac03 u01]# cd /u01/app/oraInventory/
[root@db-rac03 oraInventory]# ls
backup  ContentsXML  logs  oraInst.loc  orainstRoot.sh
[root@db-rac03 oraInventory]# ./orainstRoot.sh 
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.

[root@db-rac03 oraInventory]# cd /u01/app/19.0.0/grid/
[root@db-rac03 grid]# ./root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/app/19.0.0/grid

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/db-rac03/crsconfig/rootcrs_db-rac03_2022-12-06_06-34-48PM.log
2022/12/06 18:34:52 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2022/12/06 18:34:52 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2022/12/06 18:34:53 CLSRSC-363: User ignored prerequisites during installation
2022/12/06 18:34:53 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2022/12/06 18:34:53 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2022/12/06 18:34:59 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2022/12/06 18:34:59 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2022/12/06 18:35:00 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2022/12/06 18:35:01 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2022/12/06 18:35:02 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2022/12/06 18:35:10 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2022/12/06 18:35:10 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2022/12/06 18:35:12 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2022/12/06 18:35:12 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2022/12/06 18:35:16 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2022/12/06 18:35:31 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2022/12/06 18:35:32 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2022/12/06 18:35:34 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2022/12/06 18:35:35 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2022/12/06 18:35:42 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2022/12/06 18:37:48 CLSRSC-343: Successfully started Oracle Clusterware stack
2022/12/06 18:37:48 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
clscfg: EXISTING configuration version 19 detected.
Successfully accumulated necessary OCR keys.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
2022/12/06 18:38:08 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2022/12/06 18:38:12 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```

### 7.4. 在节点一上开始添加节点三的数据库
#节点一db-rac01上执行，xterm连接oracle用户
```bash
cd $ORACLE_HOME/addnode
./addnode.sh "CLUSTER_NEW_NODES={db-rac03}"
```
#安装过程
```
SH connectivity---Test--->submit--->db-rac03root执行脚本：/u01/app/oracle/product/19.0.0/db_1/root.sh-->OK-->Close
```

#脚本结果
```
[root@db-rac03 ~]# cd /u01/app/oracle/product/19.0.0/db_1/
[root@db-rac03 db_1]# ./root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/19.0.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
[root@db-rac03 db_1]#
```

#此时检查集群状态

```bash
[grid@db-rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.chad
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.net1.network
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.ons
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 Started,STABLE
      2        ONLINE  ONLINE       db-rac02                 Started,STABLE
      3        ONLINE  ONLINE       db-rac03                 Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.cvu
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac01.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac02.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.db-rac03.vip
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.qosmserver
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.xydb.db
      1        ONLINE  ONLINE       db-rac01                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       db-rac02                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_portal.svc
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
--------------------------------------------------------------------------------
```



###  7.5. 在节点一上开始安装节点三的instance

#xterm连接db-rac01的oracle账户
```bash
dbca
```
#安装过程
```
Oracle RAC databas instnce management--->Add an instance--->勾选xydb/xydb1/ADMIN_MANAGED，下面填写sys/Ora543Cle--->Instance name：xydb3；Node name：db-rac03；下面是xydb1/xydb2/active--->Finish--->开始安装--->Close
```
#此时集群检查
```
[grid@db-rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.chad
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.net1.network
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.ons
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 Started,STABLE
      2        ONLINE  ONLINE       db-rac02                 Started,STABLE
      3        ONLINE  ONLINE       db-rac03                 Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.cvu
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac01.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac02.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.db-rac03.vip
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.qosmserver
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.xydb.db
      1        ONLINE  ONLINE       db-rac01                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       db-rac02                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      3        ONLINE  ONLINE       db-rac03                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_portal.svc
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
--------------------------------------------------------------------------------
[grid@db-rac01 ~]$ 

[grid@db-rac01 ~]$ ifconfig
ens18: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.1  netmask 255.255.255.0  broadcast 172.16.134.255
        inet6 fe80::fcfc:feff:feaa:d9d6  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:aa:d9:d6  txqueuelen 1000  (Ethernet)
        RX packets 663622  bytes 80047357 (76.3 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 615625  bytes 14447513558 (13.4 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens18:1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.10  netmask 255.255.255.0  broadcast 172.16.134.255
        ether fe:fc:fe:aa:d9:d6  txqueuelen 1000  (Ethernet)

ens18:4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.2  netmask 255.255.255.0  broadcast 172.16.134.255
        ether fe:fc:fe:aa:d9:d6  txqueuelen 1000  (Ethernet)

ens19: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.251.252.1  netmask 255.255.255.0  broadcast 10.251.252.255
        inet6 fe80::fcfc:feff:fef3:9f21  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:f3:9f:21  txqueuelen 1000  (Ethernet)
        RX packets 21212444  bytes 26580525643 (24.7 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 21779803  bytes 27480176546 (25.5 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens19:1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 169.254.1.167  netmask 255.255.224.0  broadcast 169.254.31.255
        ether fe:fc:fe:f3:9f:21  txqueuelen 1000  (Ethernet)

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 1899949  bytes 3740600055 (3.4 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 1899949  bytes 3740600055 (3.4 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[grid@db-rac01 ~]$ 


[root@db-rac02 ~]# ifconfig
ens18: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.3  netmask 255.255.255.0  broadcast 172.16.134.255
        inet6 fe80::fcfc:feff:fe91:b277  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:91:b2:77  txqueuelen 1000  (Ethernet)
        RX packets 183979  bytes 159190115 (151.8 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 90450  bytes 18687149 (17.8 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens18:1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.4  netmask 255.255.255.0  broadcast 172.16.134.255
        ether fe:fc:fe:91:b2:77  txqueuelen 1000  (Ethernet)

ens18:2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.8  netmask 255.255.255.0  broadcast 172.16.134.255
        ether fe:fc:fe:91:b2:77  txqueuelen 1000  (Ethernet)

ens19: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.251.252.3  netmask 255.255.255.0  broadcast 10.251.252.255
        inet6 fe80::fcfc:feff:fe49:1cec  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:49:1c:ec  txqueuelen 1000  (Ethernet)
        RX packets 21315577  bytes 26910727608 (25.0 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 18651149  bytes 25728630369 (23.9 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens19:1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 169.254.13.190  netmask 255.255.224.0  broadcast 169.254.31.255
        ether fe:fc:fe:49:1c:ec  txqueuelen 1000  (Ethernet)

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 1158296  bytes 339405030 (323.6 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 1158296  bytes 339405030 (323.6 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@db-rac02 ~]# 


[root@db-rac03 ~]# ifconfig
ens18: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.6  netmask 255.255.255.0  broadcast 172.16.134.255
        inet6 fe80::fcfc:feff:fede:6b05  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:de:6b:05  txqueuelen 1000  (Ethernet)
        RX packets 10026107  bytes 14883537972 (13.8 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 513671  bytes 45281175 (43.1 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens18:1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.9  netmask 255.255.255.0  broadcast 172.16.134.255
        ether fe:fc:fe:de:6b:05  txqueuelen 1000  (Ethernet)

ens18:2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.134.7  netmask 255.255.255.0  broadcast 172.16.134.255
        ether fe:fc:fe:de:6b:05  txqueuelen 1000  (Ethernet)

ens19: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.251.252.6  netmask 255.255.255.0  broadcast 10.251.252.255
        inet6 fe80::fcfc:feff:fe19:23d3  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:19:23:d3  txqueuelen 1000  (Ethernet)
        RX packets 870633  bytes 789535439 (752.9 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 704293  bytes 895592146 (854.1 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens19:1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 169.254.14.16  netmask 255.255.224.0  broadcast 169.254.31.255
        ether fe:fc:fe:19:23:d3  txqueuelen 1000  (Ethernet)

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 86625  bytes 27356489 (26.0 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 86625  bytes 27356489 (26.0 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@db-rac03 ~]# 
```

#修改原来的service
```
[oracle@db-rac01 ~]$ srvctl modify service -d xydb -s s_portal -oldinst xydb1,xydb2 -newinst xydb3
PRKO-2101 : Failed to find database instances xydb1,xydb2
[oracle@db-rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 06-DEC-2022 21:37:08

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-DEC-2022 20:58:22
Uptime                    1 days 0 hr. 38 min. 46 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/db-rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.1)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.2)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "ef14db5ce59d2d91e053018610ac1806" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[oracle@db-rac01 ~]$ srvctl remove service -d xydb -s s_portal
PRCR-1025 : Resource ora.xydb.s_portal.svc is still running
[oracle@db-rac01 ~]$ srvctl stop service -d xydb -s s_portal
[oracle@db-rac01 ~]$ srvctl remove service -d xydb -s s_portal
[oracle@db-rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 06-DEC-2022 21:37:51

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-DEC-2022 20:58:22
Uptime                    1 days 0 hr. 39 min. 28 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/db-rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.1)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.2)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "ef14db5ce59d2d91e053018610ac1806" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[oracle@db-rac01 ~]$ srvctl add service -help

Adds a service configuration to the Oracle Clusterware.

Usage: srvctl add service -db <db_unique_name> -service "<service_name_list>" 
       {-preferred "<preferred_list>" [-available "<available_list>"] [-tafpolicy {BASIC | NONE | PRECONNECT}] | -serverpool <pool_name> [-cardinality {UNIFORM | SINGLETON}] } 
       [-netnum <network_number>] [-role "[PRIMARY][,PHYSICAL_STANDBY][,LOGICAL_STANDBY][,SNAPSHOT_STANDBY]"] [-policy {AUTOMATIC | MANUAL}] 
       [-notification {TRUE | FALSE}] [-dtp {TRUE | FALSE}] [-clbgoal {SHORT | LONG}] [-rlbgoal {NONE | SERVICE_TIME | THROUGHPUT}] 
       [-failovertype {NONE | SESSION | SELECT | TRANSACTION | AUTO}] [-failovermethod {NONE | BASIC}] [-failoverretry <failover_retries>] [-failoverdelay <failover_delay>] [-failover_restore {NONE | LEVEL1}] [-failback {YES | NO}] 
       [-edition <edition>] [-pdb <pluggable_database>] [-global {TRUE | FALSE}] [-maxlag <max_lag_time>] [-sql_translation_profile <sql_translation_profile>] 
       [-commit_outcome {TRUE | FALSE}] [-retention <retention>] [-replay_init_time <replay_initiation_time>] [-session_state {STATIC | DYNAMIC}] 
       [-pqservice <pq_service>] [-pqpool "<pq_pool_list>"] [-gsmflags <gsm_flags>] [-tablefamilyid <table_family_id>] [-drain_timeout <drain_timeout>] [-stopoption <stop_option>] [-css_critical {YES | NO}] [-rfpool <pool_name> -hubsvc <hub_service>]
       [-force] [-eval] [-verbose]
    -db <db_unique_name>           Unique name for the database
    -service "<serv,...>"          Comma separated service names
    -preferred "<preferred_list>"  Comma separated list of preferred instances
    -available "<available_list>"  Comma separated list of available instances
    -serverpool <pool_name>        Server pool name
    -cardinality                   (UNIFORM | SINGLETON) Service runs on every active server in the server pool hosting this service (UNIFORM) or just one server (SINGLETON)
    -netnum  <network_number>      Network number (default number is 1)
    -tafpolicy                     (NONE | BASIC | PRECONNECT)        TAF policy specification
    -role <role>                   Role of the service (primary, physical_standby, logical_standby, snapshot_standby)
    -policy <policy>               Management policy for the service (AUTOMATIC or MANUAL)
    -failovertype                  (NONE | SESSION | SELECT | TRANSACTION | AUTO)      Failover type
    -failovermethod                (NONE | BASIC)     Failover method
    -failoverdelay <failover_delay> Failover delay (in seconds)
    -failoverretry <failover_retries> Number of attempts to retry connection
    -failover_restore <failover_restore>  Option to restore initial environment for Application Continuity and TAF (NONE or LEVEL1)
    -failback                      (YES|NO) Failback to a preferred instance for a administrator-managed database 
    -edition <edition>             Edition (or "" for empty edition value)
    -pdb <pluggable_database>      Pluggable database name
    -maxlag <max_lag_time>         Maximum replication lag time in seconds (Non-negative integer, default value is 'ANY')
    -clbgoal                       (SHORT | LONG)                   Connection Load Balancing Goal. Default is LONG.
    -rlbgoal                       (SERVICE_TIME | THROUGHPUT | NONE)     Runtime Load Balancing Goal
    -dtp                           (TRUE | FALSE)  Distributed Transaction Processing
    -notification                  (TRUE | FALSE)  Enable Fast Application Notification (FAN) for OCI connections
    -global <global>               Global attribute (TRUE or FALSE)
    -sql_translation_profile <sql_translation_profile> Specify a database object for SQL translation profile
    -commit_outcome                (TRUE | FALSE)          Commit outcome
    -retention <retention>         Specifies the number of seconds the commit outcome is retained
    -replay_init_time <replay_initiation_time> Seconds after which replay will not be initiated
    -session_state <session_state> Session state consistency (STATIC or DYNAMIC)
    -pqservice <pq_service>        Parallel query service name
    -pqpool "<pq_pool_list>"       Comma separated list of parallel query server pool names
    -gsmflags <gsm_flags>          Set locality and region failover values
    -tablefamilyid <table_family_id> Set table family ID for a given service
    -drain_timeout <drain_timeout> Service drain timeout specified in seconds
    -stopoption <stop_options>     Options to stop service (e.g. TRANSACTIONAL or IMMEDIATE)
    -css_critical {YES | NO}          Define whether the database or service is CSS critical
    -rfpool <pool_name>            Reader farm server pool name
    -hubsvc <hub_service>            Hub service used by Reader Farm service
    -eval                          Evaluates the effects of event without making any changes to the system
Usage: srvctl add service -db <db_unique_name> -service "<service_name_list>" -update {-preferred "<new_pref_inst>" | -available "<new_avail_inst>"} [-force] [-verbose]
    -db <db_unique_name>           Unique name for the database
    -service "<serv,...>"          Comma separated service names
    -update                        Add a new instance to service configuration
    -preferred <new_pref_inst>     Name of new preferred instance
    -available <new_avail_inst>    Name of new available instance
    -force                         Force the add operation even though a listener is not configured for a network
    -verbose                       Verbose output
    -help                          Print usage
    
#oracle11gRAC

[root@stuora1 ~]# su - oracle
Last login: Sun Oct  9 14:41:38 CST 2022 on pts/0
[oracle@stuora1 ~]$ srvctl add service -help

Adds a service configuration to the Oracle Clusterware.

Usage: srvctl add service -d <db_unique_name> -s <service_name> {-r "<preferred_list>" [-a "<available_list>"] [-P {BASIC | NONE | PRECONNECT}] | -g <pool_name> [-c {UNIFORM | SINGLETON}] } [-k   <net_num>] [-l [PRIMARY][,PHYSICAL_STANDBY][,LOGICAL_STANDBY][,SNAPSHOT_STANDBY]] [-y {AUTOMATIC | MANUAL}] [-q {TRUE|FALSE}] [-x {TRUE|FALSE}] [-j {SHORT|LONG}] [-B {NONE|SERVICE_TIME|THROUGHPUT}] [-e {NONE|SESSION|SELECT}] [-m {NONE|BASIC}] [-z <failover_retries>] [-w <failover_delay>] [-t <edition>] [-f]
    -d <db_unique_name>      Unique name for the database
    -s <service>             Service name
    -r "<preferred_list>"    Comma separated list of preferred instances
    -a "<available_list>"    Comma separated list of available instances
    -g <pool_name>           Server pool name
    -c {UNIFORM | SINGLETON} Service runs on every active server in the server pool hosting this service (UNIFORM) or just one server (SINGLETON)
    -k <net_num>             network number (default number is 1)
    -P {NONE | BASIC | PRECONNECT}        TAF policy specification
    -l <role>                Role of the service (primary, physical_standby, logical_standby, snapshot_standby)
    -y <policy>              Management policy for the service (AUTOMATIC or MANUAL)
    -e <Failover type>       Failover type (NONE, SESSION, or SELECT)
    -m <Failover method>     Failover method (NONE or BASIC)
    -w <integer>             Failover delay
    -z <integer>             Failover retries
    -t <edition>             Edition (or "" for empty edition value)
    -j <clb_goal>  Connection Load Balancing Goal (SHORT or LONG). Default is LONG.
    -B <Runtime Load Balancing Goal>     Runtime Load Balancing Goal (SERVICE_TIME, THROUGHPUT, or NONE)
    -x <Distributed Transaction Processing>  Distributed Transaction Processing (TRUE or FALSE)
    -q <AQ HA notifications> AQ HA notifications (TRUE or FALSE)
Usage: srvctl add service -d <db_unique_name> -s <service_name> -u {-r "<new_pref_inst>" | -a "<new_avail_inst>"} [-f]
    -d <db_unique_name>      Unique name for the database
    -s <service>             Service name
    -u                       Add a new instance to service configuration
    -r <new_pref_inst>       Name of new preferred instance
    -a <new_avail_inst>      Name of new available instance
    -f                       Force the add operation even though a listener is not configured for a network
    -h                       Print usage
[oracle@stuora1 ~]$

[oracle@db-rac01 ~]$ srvctl add service -d xydb -s s_portal -r xydb1,xydb2,xydb3 -P basic -e select -m basic -z 180 -w 5 -pdb portal
[oracle@db-rac01 ~]$ srvctl start service -d xydb -s s_portal
[oracle@db-rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 06-DEC-2022 21:49:02

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-DEC-2022 20:58:22
Uptime                    1 days 0 hr. 50 min. 40 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/db-rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.1)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.2)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "ef14db5ce59d2d91e053018610ac1806" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[oracle@db-rac01 ~]$ 

sqlplus pdbadmin/J3my3xl4c12ed@172.16.134.9:1521/s_dataassets

sqlplus pdbadmin/J3my3xl4c12ed@172.16.134.8:1521/s_portal
```