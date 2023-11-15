**Oracle11C RAC for Centos7.9 安装手册**

## 目录
1 环境..............................................................................................................................................2
1.1. 系统版本： ..............................................................................................................................2
1.2. ASM 磁盘组规划 ....................................................................................................................2
1.3. 主机网络规划..........................................................................................................................2
1.4. 操作系统配置部分.................................................................................................................2
2 准备工作（oracle1 与 oracle2 同时配置） ............................................................................................3
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
[root@rac01 Packages]# cat /etc/redhat-release
Red Hat Enterprise Linux Server release 7.9 (Maipo)
```
### 1.2. ASM 磁盘组规划
```
ASM 磁盘组 用途 大小 冗余
ocr、 voting file   100G+100G+100G NORMAL   oracleRAC-ocr01/oracleRAC-ocr02/oracleRAC-ocr03
DATA 数据文件 2T+2T+2T EXTERNAL              oracleRAC-data01/oracleRAC-data02/oracleRAC-data03
FRA    归档日志 1.5T+1.5T+1.5T EXTERNAL      oracleRAC-fra01/oracleRAC-fra02/oracleRAC-fra03
```
![image-20230920160818300](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920160818300.png)



![image-20230920160954978](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920160954978.png)

![image-20230920161151483](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920161151483.png)



![image-20230920161951526](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920161951526.png)



![image-20230920162102664](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920162102664.png)



![image-20230920163447782](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920163447782.png)



![image-20230920163551458](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920163551458.png)



![image-20230920163710931](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920163710931.png)

![image-20230920163809166](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920163809166.png)



### 1.3. 主机网络规划

#password

```
root/AZlm92c2YeVc!
root1/Jile2dx49OmUne
grid/
oracle

sys/
system/
```

#分区---1T

```
/boot   1G
swap    32G
/       其余容量  
```

![image-20230920181110626](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230920181110626.png)

#IP规划

```
网络配置               节点 1                               节点 2
主机名称               rac01                               rac02
public ip            10.20.12.118                       10.20.12.119
private ip           10.20.24.250                       10.20.24.251
vip                  10.20.12.132                       10.20.12.133
scan ip              10.20.12.134
```
#网卡配置

```bash
ifconfig
nmcli conn show
#如果发现虚拟机为克隆模式，两台服务器ens32的uuid相同，可以重新生成新的UUID
#uuidgen ens32
#然后修改/etc/sysconfig/network-scripts/ifcfg-ens32中的UUID
#创建ens160
#cp /etc/sysconfig/network-scripts/ifcfg-ens32  /etc/sysconfig/network-scripts/ifcfg-ens160
```
#修改私有网卡的相关配置
#rac01
```
[root@rac01 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth0
UUID=bdc16ef2-d1d0-4c97-889c-961adfa53039
DEVICE=eth0
ONBOOT=yes
IPADDR=10.20.12.118
PREFIX=24
GATEWAY=10.20.12.1
DNS1=202.206.16.2
DNS2=233.5.5.5
[root@rac01 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth1
UUID=d5d1bda3-c00f-484f-b818-e68b5023dbc7
DEVICE=eth1
ONBOOT=yes
IPADDR=10.20.24.250
PREFIX=24
GATEWAY=10.20.24.1
```
#oracle2
```
[root@rac02 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=10.20.12.119
PREFIX=24
GATEWAY=10.20.12.1
DNS1=202.206.16.2
DNS2=223.5.5.5
[root@rac02 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
NAME=eth1
DEVICE=eth1
ONBOOT=yes
IPADDR=10.20.24.251
PREFIX=24
GATEWAY=10.20.24.1
```
### 1.4. 操作系统配置部分

#关闭防火墙
```bash
systemctl stop firewalld
systemctl disable firewalld
```
#关闭 selinux
```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0

getenforce
```

## 2.准备工作（oracle1 与 oracle2 同时配置）

### 2.1. 配置本地 yum 源--可选

#挂载光驱
```bash
mount -t auto /dev/cdrom /mnt
```
#配置本地源
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
### 2.2. 安装 rpm 依赖包

#官网为准
```bash
yum install -y binutils
yum install -y compat-libcap1
yum install -y compat-libstdc++-33
yum install -y compat-libstdc++-33.i686
yum install -y gcc
yum install -y gcc-c++
yum install -y glibc
yum install -y glibc.i686
yum install -y glibc-devel
yum install -y glibc-devel.i686
yum install -y ksh
yum install -y libgcc
yum install -y libgcc.i686
yum install -y libstdc++
yum install -y libstdc++.i686
yum install -y libstdc++-devel
yum install -y libstdc++-devel.i686
yum install -y libaio
yum install -y libaio.i686
yum install -y libaio-devel
yum install -y libaio-devel.i686
yum install -y libXext
yum install -y libXext.i686
yum install -y libXtst
yum install -y libXtst.i686
yum install -y libX11
yum install -y libX11.i686
yum install -y libXau
yum install -y libXau.i686
yum install -y libxcb
yum install -y libxcb.i686
yum install -y libXi
yum install -y libXi.i686
yum install -y make
yum install -y sysstat
yum install -y unixODBCyum install -y unixODBC-devel
yum install -y readline
yum install -y libtermcap-devel
yum install -y bc
yum install -y compat-libstdc++
yum install -y elfutils-libelf
yum install -y elfutils-libelf-devel
yum install -y fontconfig-devel
yum install -y libXi
yum install -y libXtst
yum install -y libXrender
yum install -y libXrender-devel
yum install -y libgcc
yum install -y librdmacm-devel
yum install -y libstdc++
yum install -y libstdc++-devel
yum install -y net-tools
yum install -y nfs-utils
yum install -y python
yum install -y python-configshell
yum install -y python-rtslib
yum install -y python-six
yum install -y targetcli
yum install -y smartmontools


```
#检查是否完全安装

```bash
rpm -qa    binutils  compat-libcap1  compat-libstdc++-33  compat-libstdc++-33.i686  gcc  gcc-c++  glibc  glibc.i686  glibc-devel  glibc-devel.i686  ksh  libgcc  libgcc.i686  libstdc++  libstdc++.i686  libstdc++-devel  libstdc++-devel.i686  libaio  libaio.i686  libaio-devel  libaio-devel.i686  libXext  libXext.i686  libXtst  libXtst.i686  libX11  libX11.i686  libXau  libXau.i686  libxcb  libxcb.i686  libXi  libXi.i686  make  sysstat  unixODBC unixODBC-devel  readline  libtermcap-devel  bc  compat-libstdc++  elfutils-libelf  elfutils-libelf-devel  fontconfig-devel  libXi  libXtst  libXrender  libXrender-devel  libgcc  librdmacm-devel  libstdc++  libstdc++-devel  net-tools  nfs-utils  python  python-configshell  python-rtslib  python-six  targetcli  smartmontools
```



### 2.3. 创建用户

```bash
groupadd -g 11001 oinstall
groupadd -g 11002 dba
groupadd -g 11003 oper
groupadd -g 11004 backupdba
groupadd -g 11005 dgdba
groupadd -g 11006 kmdba
groupadd -g 11007 asmdba
groupadd -g 11008 asmoper
groupadd -g 11009 asmadmin
groupadd -g 11010 racdba

useradd -u 11011 -g oinstall -G dba,asmdba,backupdba,dgdba,kmdba,racdba,oper oracle

useradd -u 11012 -g oinstall -G asmadmin,asmdba,asmoper,dba grid

#root/AZlm92c2YeVc!
#root1/Jile2dx49OmUne
passwd oracle
#L2jc4l2MAucl
passwd grid
#FG2jc62xwucD
```
### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#oracle1
hostnamectl set-hostname rac01
#oracle2
hostnamectl set-hostname rac02

cat >> /etc/hosts <<EOF
#public ip eth0
10.20.12.118 rac01
10.20.12.119 rac02
#vip
10.20.12.132 rac01-vip
10.20.12.133 rac02-vip
#private ip eth1
10.20.24.250 rac01-prv
10.20.24.251 rac02-prv
#scan ip
10.20.12.134 rac-scan

EOF
```
#连通性测试

```bash
ping rac01
ping rac02
ping rac01-prv
ping rac02-prv

#以下临时ping不通，证明IP未占用
ping rac01-vip
ping rac02-vip
ping rac-scan
```



### 2.5. 禁用 NTP

#检查两节点时间，时区是否相同，并禁止 ntp
```bash
systemctl disable ntpd.service
systemctl stop ntpd.service
mv /etc/ntp.conf /etc/ntp.conf.orig

systemctl status ntpd

systemctl disable chronyd
systemctl stop chronyd

systemctl status chronyd
```
#时区设置
```bash
#查看是否中国时区，时间是否正确
date -R 

yum install -y rdate
rdate -s time.nist.gov


#设置中国时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#方法二
timedatectl list-timezones |grep Shanghai #查找中国时区的完整名称
--->Asia/Shanghai
timedatectl set-timezone Asia/Shanghai
```
### 2.6. 创建所需要目录

```bash
mkdir -p /u01/app/19.0.0/grid
mkdir -p /u01/app/grid
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oracle/product/19.0.0/db_1

chown -R grid:oinstall /u01
chown -R oracle:oinstall /u01/app/oracle
chmod -R 775 /u01
```
### 2.7. 其它优化配置：

#修改/etc/security/limits.d/20-nproc.con

```bash
sudo sed -i 's/4096/90000/g' /etc/security/limits.d/20-nproc.conf
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

##修改方法一，必须知道引导是BIOS还是EFI，可以通过df -h来判断是否有/boot/efi等字样
则修改/etc/default/grub，在RUB_CMDLINE_LINUX中添加transparent_hugepage=never

#内容如下
```
#GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet transparent_hugepage=never numa=off"

GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=ol/root rd.lvm.lv=ol/swap rhgb quiet transparent_hugepage=never numa=off"
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
```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 14062500
#memory*90%,此处为64G
kernel.shmmax = 57600000000
kernel.shmmni = 4096
kernel.sem = 6144 50331648 4096 8192
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 4194304
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.ipfrag_high_thresh = 16777216
net.ipv4.ipfrag_low_thresh = 15728640

EOF

```
#关闭avahi-daemon
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

#grid用户，注意oracle1/oracle2两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意oracle2修改
#export ORACLE_SID=+ASM2
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/11.2.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
#oracle用户，注意oracle1/oracle2的区别
```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1
export ORACLE_SID=xydb1
#注意oracle2修改
#export ORACLE_SID=xydb2
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
### 2.9. 配置共享磁盘权限

#### 2.9.1.无多路径模式

#适用于vsphere平台直接共享存储磁盘

#检查磁盘UUID
```bash
sfdisk -s
/usr/lib/udev/scsi_id -g -u -d devicename
```
#显示如下
```
[root@rac01 ~]# sfdisk -s
/dev/sdc:  20971520
/dev/sde: 524288000
/dev/sda: 524288000
/dev/sdf: 314572800
/dev/sdb:  20971520
/dev/sdd:  20971520
/dev/mapper/centos-root: 456126464
/dev/mapper/centos-swap:  67108864
total: 1949298688 blocks

[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
36000c29cab9f05183d3af0fc44e8022f
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
36000c29aa1f89b4a2054f787a381ec5f
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
36000c293eb6bd488a57530ba68d59381
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
36000c29e32ff47627698b21515cc5682
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
36000c29b4a664efab3f02294bb39f75c
```
#99-oracle-asmdevices.rules
```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sdb", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36000c29cab9f05183d3af0fc44e8022f", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdc", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36000c29aa1f89b4a2054f787a381ec5f", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdd", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36000c293eb6bd488a57530ba68d59381", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sde", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36000c29e32ff47627698b21515cc5682", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdf", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36000c29b4a664efab3f02294bb39f75c", OWNER="grid",GROUP="asmadmin", MODE="0660"
EOF

```
#启动udev
```bash
/usr/sbin/partprobe
systemctl restart systemd-udev-trigger.service
systemctl enale systemd-udev-trigger.service
```
#检查asm磁盘
```bash
ll /dev|grep asm
```
#显示如下
```
[root@rac01 ~]# ll /dev|grep asm
brw-rw----  1 grid asmadmin   8,  16 Dec 21 16:25 sdb
brw-rw----  1 grid asmadmin   8,  32 Dec 21 16:25 sdc
brw-rw----  1 grid asmadmin   8,  48 Dec 21 16:25 sdd
brw-rw----  1 grid asmadmin   8,  64 Dec 21 16:25 sde
brw-rw----  1 grid asmadmin   8,  80 Dec 21 16:25 sdf
```

#### 2.9.2.多路径模式

#适用于物理服务器、广交、存储多路跳线连接

#存储uuid
```
以下是oracle 卷的序列号，请按照这个顺序使用，跟存储上的名称才能对应。
data1(2TB): e25b665dc06369916c9ce900b6fab6bc
/dev/sdd  /dev/sdp  /dev/sdt  /dev/sdx
data2(2TB): cdc2ff0f5bc698456c9ce900b6fab6bc
/dev/sdaa  /dev/sdae  /dev/sdg  /dev/sdk
FRA(2TB): fc7ffd18baba312e6c9ce900b6fab6bc
/dev/sdab  /dev/sdaf  /dev/sdh  /dev/sdl
LOG1(150GB): 6f1134c7f5aeac0d6c9ce900b6fab6bc
/dev/sde  /dev/sdq  /dev/sdu  /dev/sdy
LGO2(150GB): f8505ff366f3732a6c9ce900b6fab6bc
/dev/sdac  /dev/sdag  /dev/sdi  /dev/sdm
OCR1(100GB): 11e8f142da86728d6c9ce900b6fab6bc
/dev/sdb   /dev/sdn  /dev/sdr  /dev/sdv
OCR2(100GB): c95d9e2bbe0ff5906c9ce900b6fab6bc
/dev/sdc  /dev/sdo  /dev/sds  /dev/sdw
OCR3(100GB): b38e62246b6fc4fb6c9ce900b6fab6bc
/dev/sdad  /dev/sdf  /dev/sdj  /dev/sdz
```
#通过scsi_id检查
```
[root@rac01 ~]# sfdisk -s
/dev/sda: 585531392
/dev/mapper/centos-root: 516321280
/dev/mapper/centos-swap:  67108864
/dev/sdb: 104857600
/dev/sdc: 2147483648
/dev/sdd: 2147483648
/dev/sde: 157286400
/dev/sdf: 104857600
/dev/sdg: 2147483648
/dev/sdh: 2147483648
/dev/sdi: 157286400
/dev/sdj: 104857600
/dev/sdk: 104857600
/dev/sdl: 2147483648
/dev/sdm: 157286400
/dev/sdn: 104857600
/dev/sdo: 104857600
/dev/sdp: 2147483648
/dev/sdq: 157286400
/dev/sdr: 104857600
/dev/sds: 104857600
/dev/sdt: 2147483648
/dev/sdu: 157286400
/dev/sdv: 104857600
/dev/sdw: 2147483648
/dev/sdx: 2147483648
/dev/sdy: 157286400
/dev/sdz: 104857600
/dev/sdaa: 2147483648
/dev/sdab: 2147483648
/dev/sdac: 157286400
/dev/sdad: 104857600
/dev/sdae: 104857600
/dev/sdaf: 2147483648
/dev/sdag: 157286400
total: 29455347712 blocks

[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
211e8f142da86728d6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2e25b665dc06369916c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
211e8f142da86728d6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2e25b665dc06369916c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
211e8f142da86728d6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2e25b665dc06369916c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
211e8f142da86728d6c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdae
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaf
2e25b665dc06369916c9ce900b6fab6bc
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdag
26f1134c7f5aeac0d6c9ce900b6fab6bc

#通过循环来获取
for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4
```

#配置多路径配置
```bash
rpm -qa|grep device-mapper-multipath
yum install device-mapper-multipath
systemctl enable multipathd

cat >> /etc/multipath.conf  <<EOF
multipaths {
           multipath {
                      wwid 211e8f142da86728d6c9ce900b6fab6bc
                      alias ocr1
           }
           multipath {
                      wwid 2c95d9e2bbe0ff5906c9ce900b6fab6bc
                      alias ocr2
           }
		   multipath {
                      wwid 2b38e62246b6fc4fb6c9ce900b6fab6bc
                      alias ocr3
           }
           multipath {
                      wwid 26f1134c7f5aeac0d6c9ce900b6fab6bc
                      alias log1
           }
		   multipath {
                      wwid 2f8505ff366f3732a6c9ce900b6fab6bc
                      alias log2
           }
           multipath {
                      wwid 2e25b665dc06369916c9ce900b6fab6bc
                      alias data1
           }
		   multipath {
                      wwid 2cdc2ff0f5bc698456c9ce900b6fab6bc
                      alias data2
           }
           multipath {
                      wwid 2fc7ffd18baba312e6c9ce900b6fab6bc
                      alias fra
           }
}
EOF


cat >> /etc/udev/rules.d/12-dm-permissions.rules <<'EOF'
ENV{DM_NAME}=="ocr1",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="ocr2",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="ocr3",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="log1",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="log2",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data1",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data2",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
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

#以下只在oracle1执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh oracle2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh oracle2 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys oracle2:~/.ssh/authorized_keys

ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date

ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date

#在oracle2执行
ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date

ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在oracle1执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh oracle2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh oracle2 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys oracle2:~/.ssh/authorized_keys

ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date

ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date

#在oracle2上执行
ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date

ssh oracle1 date;ssh oracle2 date;ssh oracle1-prv date;ssh oracle2-prv date
```
### 2.11. 在 grid 安装文件中安装 cvuqdisk

```bash
[root@rac01 rpm]# pwd
/u01/app/11.2.0/grid/cv/rpm
[root@rac01 rpm]# ls
cvuqdisk-1.0.10-1.rpm
[root@rac01 rpm]# rpm -ivh cvuqdisk-1.0.10-1.rpm
```
## 3 开始安装 grid

### 3.1. 上传集群软件包

[root@rac01 grid]# ll
-rwxr-xr-x 1 grid oinstall 5.1G Jan 28 15:58 LINUX.X64_180000_grid_home.zip
3.2. 解压 grid 安装包
在 19C 中需要把 grid 包解压放到 grid 用户下 ORACLE_HOME 目录内
解压文件到/u01/app/11.2.0/grid
[grid@oracle2 grid]$ cd /u01/app/11.2.0/grid
[grid@oracle2 grid]$ unzip LINUX.X64_193000_grid_home.zip
cd /u01/app/11.2.0/grid/cv/rpm
cp cvuqdisk-1.0.10-1.rpm /u01
scp cvuqdisk-1.0.10-1.rpm oracle2:/u01
su - root
cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm
su - grid
安装前检查：
 [grid@oracle1 ~]$ cd /u01/app/12.2.0/grid/
[grid@oracle1 grid]$ ./runcluvfy.sh stage -pre crsinst -n oracle1,oracle2 -verbose
3.3. 进入 grid 集群软件目录执行安装
cd /u01/app/12.2.0/grid/
[grid@oracle1 grid]$ ./gridSetup.sh
3.4. GUI 安装步骤
1. 创建新的集群
2. 配置集群名称以及 scan 名称3. 节点互信
4. 公网、私网网段选择5. 选择 asm 存储
6. 选择配置 GIMR7. 这里选择 ocr、 voting file 与 gimr 放在一起
8. 选择 asm 磁盘组
9. 输入密码10. 保持默认
11. 保持默认12. 确认 base 目录13. 这里可以选择自动 root 执行脚本14. 预安装检查
15. 解决相关依赖后，忽略如下报错16. 如下警告可以忽略-警告是由于没有使用 DNS 解析造成可忽略
17. 执行 root 脚本[root@rac01 oraInventory]# sh /u01/app/oraInventory/orainstRoot.sh Changing
permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.
[root@oracle2 ~]# sh /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.
Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@rac01 oraInventory]# sh /u01/app/11.2.0/grid/root.sh
Performing root user operation.
The following environment variables are set as:
ORACLE_OWNER= grid
ORACLE_HOME= /u01/app/11.2.0/grid
Enter the full pathname of the local bin directory: [/usr/local/bin]:Copying dbhome to /usr/local/bin ...
Copying oraenv to /usr/local/bin ...
Copying coraenv to /usr/local/bin ...
Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/app/11.2.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
/u01/app/grid/crsdata/oracle1/crsconfig/rootcrs_oracle1_2020-03-26_09-37-
30PM.log
2020/03/26 21:37:41 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2020/03/26 21:37:41 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2020/03/26 21:37:41 CLSRSC-363: User ignored prerequisites during installation
2020/03/26 21:37:41 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2020/03/26 21:37:44 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2020/03/26 21:37:44 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2020/03/26 21:37:45 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2020/03/26 21:37:45 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2020/03/26 21:38:15 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA)
Collector.
2020/03/26 21:38:15 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2020/03/26 21:38:18 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2020/03/26 21:38:25 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2020/03/26 21:38:25 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2020/03/26 21:38:29 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2020/03/26 21:38:29 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2020/03/26 21:38:50 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2020/03/26 21:38:54 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2020/03/26 21:38:58 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2020/03/26 21:39:02 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
ASM has been created and started successfully.
[DBT-30001] Disk groups created successfully. Check
/u01/app/grid/cfgtoollogs/asmca/asmca-200326PM093934.log for details.
2020/03/26 21:40:24 CLSRSC-482: Running command:
'/u01/app/11.2.0/grid/bin/ocrconfig -upgrade grid oinstall'
CRS-4256: Updating the profileSuccessful addition of voting disk 737d53ea5a884f5abfd465a0e1f0e6f4.
Successfully replaced voting disk group with +CRS.
CRS-4256: Updating the profile
CRS-4266: Voting file(s) successfully replaced
## STATE File Universal Id File Name Disk group
-- ----- ----------------- --------- ---------
1. ONLINE 737d53ea5a884f5abfd465a0e1f0e6f4 (/dev/sdc) [CRS]
Located 1 voting disk(s).
2020/03/26 21:41:28 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2020/03/26 21:42:53 CLSRSC-343: Successfully started Oracle Clusterware stack
2020/03/26 21:42:53 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2020/03/26 21:44:01 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2020/03/26 21:44:22 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ...
succeeded
[root@rac01 oraInventory]#
[root@oracle2 ~]# sh /u01/app/11.2.0/grid/root.sh
Performing root user operation.
The following environment variables are set as:
ORACLE_OWNER= grid
ORACLE_HOME= /u01/app/11.2.0/grid
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
Using configuration parameter file: /u01/app/11.2.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
/u01/app/grid/crsdata/oracle2/crsconfig/rootcrs_oracle2_2020-03-26_09-45-
21PM.log
2020/03/26 21:45:26 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2020/03/26 21:45:26 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2020/03/26 21:45:26 CLSRSC-363: User ignored prerequisites during installation2020/03/26 21:45:26 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2020/03/26 21:45:27 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2020/03/26 21:45:27 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2020/03/26 21:45:27 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2020/03/26 21:45:27 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2020/03/26 21:45:29 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2020/03/26 21:45:29 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2020/03/26 21:45:31 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2020/03/26 21:45:31 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2020/03/26 21:45:33 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2020/03/26 21:45:33 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2020/03/26 21:45:51 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA)
Collector.
2020/03/26 21:45:54 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2020/03/26 21:45:55 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2020/03/26 21:45:57 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2020/03/26 21:45:58 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2020/03/26 21:46:06 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2020/03/26 21:46:50 CLSRSC-343: Successfully started Oracle Clusterware stack
2020/03/26 21:46:50 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2020/03/26 21:47:02 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2020/03/26 21:47:10 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ...
succeeded
[root@oracle2 ~]#
3.5. 查看状态
[grid@oracle2 ~]$ crsctl stat res -t
----------------------------------------------------------------------------
----
Name Target State Server State details
----------------------------------------------------------------------------
----
Local Resources
----------------------------------------------------------------------------
----
ora.LISTENER.lsnr
ONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
ora.chad
ONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
ora.net1.networkONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
ora.ons
ONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
----------------------------------------------------------------------------
----
Cluster Resources
----------------------------------------------------------------------------
----
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
1 ONLINE ONLINE oracle1 STABLE
2 ONLINE ONLINE oracle2 STABLE
3 OFFLINE OFFLINE STABLE
ora.CRS.dg(ora.asmgroup)
1 ONLINE ONLINE oracle1 STABLE
2 ONLINE ONLINE oracle2 STABLE
3 OFFLINE OFFLINE STABLE
ora.LISTENER_SCAN1.lsnr
1 ONLINE ONLINE oracle1 STABLE
ora.asm(ora.asmgroup)
1 ONLINE ONLINE oracle1 Started,STABLE
2 ONLINE ONLINE oracle2 Started,STABLE
3 OFFLINE OFFLINE STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
1 ONLINE ONLINE oracle1 STABLE
2 ONLINE ONLINE oracle2 STABLE
3 OFFLINE OFFLINE STABLE
ora.cvu
1 ONLINE ONLINE oracle1 STABLE
ora.qosmserver
1 ONLINE ONLINE oracle1 STABLE
ora.oracle1.vip
1 ONLINE ONLINE oracle1 STABLE
ora.oracle2.vip
1 ONLINE ONLINE oracle2 STABLE
ora.scan1.vip
1 ONLINE ONLINE oracle1 STABLE
4 以 Oracle 用户登录图形化界面将数据库软件解压至$ORACLE_HOME 安装 Oracle 数据库软件
[oracle@oracle1 db_1]$ pwd
/u01/app/oracle/product/11.2.0/db_1
[oracle@oracle1 db_1]$ unzip /opt/LINUX.X64_193000_db_home.zip
[oracle@oracle1 db_1]$ ./runInstaller
4.1. 执行安装预安装前检查忽略如下警告4.2. 执行 root 脚本
[root@rac01 db_1]# sh /u01/app/oracle/product/11.2.0/db_1/root.sh
Performing root user operation.
The following environment variables are set as:
ORACLE_OWNER= oracle
ORACLE_HOME= /u01/app/oracle/product/11.2.0/db_1
Enter the full pathname of the local bin directory: [/usr/local/bin]:
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
[root@oracle2 ~]# sh /u01/app/oracle/product/11.2.0/db_1/root.sh
Performing root user operation.
The following environment variables are set as:
ORACLE_OWNER= oracle
ORACLE_HOME= /u01/app/oracle/product/11.2.0/db_1
Enter the full pathname of the local bin directory: [/usr/local/bin]:
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
5 创建 ASM 数据磁盘5.1. grid 账户登录图形化界面，执行 asmca6 建立数据库
以 oracle 账户登录。6.1. 执行建库 dbca6.2. 查看集群状态
[root@rac01 ~]# crsctl stat res -t
----------------------------------------------------------------------------
----
Name Target State Server State details
----------------------------------------------------------------------------
----
Local Resources
----------------------------------------------------------------------------
----
ora.CRS_GIMR.GHCHKPT.advm
OFFLINE OFFLINE oracle1 STABLE
OFFLINE OFFLINE oracle2 STABLE
ora.LISTENER.lsnr
ONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
ora.chad
ONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
ora.crs_gimr.ghchkpt.acfs
OFFLINE OFFLINE oracle1 STABLE
OFFLINE OFFLINE oracle2 STABLE
ora.helper
OFFLINE OFFLINE oracle1 IDLE,STABLE
OFFLINE OFFLINE oracle2 IDLE,STABLE
ora.net1.network
ONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
ora.ons
ONLINE ONLINE oracle1 STABLE
ONLINE ONLINE oracle2 STABLE
ora.proxy_advm
OFFLINE OFFLINE oracle1 STABLE
OFFLINE OFFLINE oracle2 STABLE
----------------------------------------------------------------------------
----
Cluster Resources
----------------------------------------------------------------------------
----
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
1 ONLINE ONLINE oracle1 STABLE
2 ONLINE ONLINE oracle2 STABLE3 ONLINE OFFLINE STABLE
ora.CRS_GIMR.dg(ora.asmgroup)
1 ONLINE ONLINE oracle1 STABLE
2 ONLINE ONLINE oracle2 STABLE
3 OFFLINE OFFLINE STABLE
ora.DATA.dg(ora.asmgroup)
1 ONLINE ONLINE oracle1 STABLE
2 ONLINE ONLINE oracle2 STABLE
3 OFFLINE OFFLINE STABLE
ora.LISTENER_SCAN1.lsnr
1 ONLINE ONLINE oracle1 STABLE
ora.MGMTLSNR
1 ONLINE ONLINE oracle1 169.254.11.15
10.10.
10.211,STABLE
ora.asm(ora.asmgroup)
1 ONLINE ONLINE oracle1 Started,STABLE
2 ONLINE ONLINE oracle2 Started,STABLE
3 OFFLINE OFFLINE STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
1 ONLINE ONLINE oracle1 STABLE
2 ONLINE ONLINE oracle2 STABLE
3 OFFLINE OFFLINE STABLE
ora.cvu
1 ONLINE ONLINE oracle1 STABLE
ora.mgmtdb
1 ONLINE ONLINE oracle1 Open,STABLE
ora.orcl.db
1 ONLINE ONLINE oracle1
Open,HOME=/u01/app/o
racle/product/19.0.0
/db_1,STABLE
2 ONLINE ONLINE oracle2
Open,HOME=/u01/app/o
racle/product/19.0.0
/db_1,STABLE
ora.qosmserver
1 ONLINE ONLINE oracle1 STABLE
ora.oracle1.vip
1 ONLINE ONLINE oracle1 STABLE
ora.oracle2.vip
1 ONLINE ONLINE oracle2 STABLEora.rhpserver
1 OFFLINE OFFLINE STABLE
ora.scan1.vip
1 ONLINE ONLINE oracle1 STABLE
6.3. 查看数据库版本
[oracle@oracle1 db_1]$ sqlplus / as sysdba
SQL> col banner_full for a120
SQL> select BANNER_FULL from v$version;
BANNER_FULL
----------------------------------------------------------------------------
----
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
cdb:
SQL> select file_name ,tablespace_name from dba_temp_files;
FILE_NAME									 TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/TEMPFILE/temp.265.1061760325 					 TEMP


FILE_NAME										   TABLESPACE_NAME		      CON_ID
------------------------------------------------------------------------------------------ ------------------------------ ----------
+DATA/XYDB/TEMPFILE/dataassets_tmp.305.1061836669					   DATAASSETS_TMP			   1
+DATA/XYDB/TEMPFILE/dataassets_tmp.306.1061836699					   DATAASSETS_TMP			   1
+DATA/XYDB/TEMPFILE/temp.265.1061760325 						   TEMP 				   1
+DATA/XYDB/TEMPFILE/temp.304.1061836561 						   TEMP 				   1
+DATA/XYDB/B8D87A7C092DF3ECE0530B0E080AA526/TEMPFILE/temp.277.1061826499		   TEMP 				   3
+DATA/XYDB/B8DA7D139F9E58F8E0530B0E080A13FD/TEMPFILE/temp.288.1061835131		   TEMP 				   4
+DATA/XYDB/B8DA7D139F9E58F8E0530B0E080A13FD/TEMPFILE/temp.307.1061836917		   TEMP 				   4

7 rows selected.

SQL> 

SQL> 
alter tablespace temp add tempfile '+DATA' size 1G autoextend on next 1G maxsize 31G;
create temporary tablespace dataassets_tmp tempfile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local ;
alter tablespace dataassets_tmp add tempfile '+DATA' size 1G autoextend on next 1G maxsize 31G;

==========================
  852   sqlplus IDC_DATA_SWOP/H2DHiH9yRSx24wK@10.8.13.201:1521/dataassets
  853  sqlplus IDC_DATA_SWOP/H2DHiH9yRSx24wK@10.8.14.15:1521/s_dataassets
  854  expdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu directory=home/oracle/zd_dump dumpfile=eams_jmu_210610.dmp logfile=eams_jmu_210610.log cluster=n compression=data_only version=12.2.0.1.0
  855  expdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu directory=zd_dump dumpfile=eams_jmu_210610.dmp logfile=eams_jmu_210610.log cluster=n compression=data_only version=12.2.0.1.0
  856  expdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu directory=zd_dump dumpfile=eams_jmu_210610.dmp  cluster=n compression=data_only version=12.2.0.1.0
  857  expdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu directory=zd_dump dumpfile=eams_jmu_2106101.dmp  cluster=n compression=data_only version=12.2.0.1.0
  858  expdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu directory=zd_dump dumpfile=eams0610.dmp  cluster=n compression=data_only version=12.2.0.1.0
  859  ll
  860  cd zd_dump/
  861  ll
  862  expdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu directory=zd_dump dumpfile=eams_jmu_210610.dmp logfile=eams_jmu_210610.log cluster=n compression=data_only version=12.2.0.1.0
  863  expdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu directory=home/oracle/zd_dump dumpfile=eams_jmu_210610.dmp logfile=eams_jmu_210610.log cluster=n compression=data_only version=12.2.0.1.0

  693  impdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu_b2 directory=data_pump_dir dumpfile=eams_jmu_210330.dmp logfile=eams_jmu_210330.log remap_schema=eams_jmu_b2:eams remap_tablespace=users:eams cluster=n transform=oid:n
  695  impdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu_b2 directory=zd_dump dumpfile=eams_jmu_210330.dmp logfile=eams_jmu_210330.log remap_schema=eams_jmu_b2:eams remap_tablespace=users:eams cluster=n transform=oid:n
  700  impdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu_b2 directory=data_pump_dir dumpfile=eams_jmu_210330.dmp logfile=eams_jmu_210330.log remap_schema=eams_jmu_b2:eams remap_tablespace=users:eams cluster=n transform=oid:n
  701  impdp eamsadm/eaEr56uLms@s_eamspdb schemas=eams_jmu_b2 directory=data_pump_dir dumpfile=eams_jmu_210330.dmp logfile=eams_jmu_210330.log remap_schema=eams_jmu_b2:eams_jmu remap_tablespace=users:eams cluster=n transform=oid:n
  753  history|grep impdp
  775  impdp eamsadm/eaEr56uLms@s_eamspdb tabless=EAMS_JMU_XC210427.YJS_COURSE,EAMS_JMU_XC210427.STANDERD_CODE,EAMS_JMU_XC210427.PY_XS,EAMS_JMU_XC210427.ZD_YJS_MAJOR directory=data_pump_dir dumpfile=eams_jmu_yjs_210505.dmp logfile=eams_jmu_yjs_210505.log remap_schema=EAMS_JMU_XC210427:eams_jmu remap_tablespace=users:eams cluster=n
  776  impdp eamsadm/eaEr56uLms@s_eamspdb tables=EAMS_JMU_XC210427.YJS_COURSE,EAMS_JMU_XC210427.STANDERD_CODE,EAMS_JMU_XC210427.PY_XS,EAMS_JMU_XC210427.ZD_YJS_MAJOR directory=data_pump_dir dumpfile=eams_jmu_yjs_210505.dmp logfile=eams_jmu_yjs_210505.log remap_schema=EAMS_JMU_XC210427:eams_jmu remap_tablespace=users:eams cluster=n
  778  impdp eamsadm/eaEr56uLms@s_eamspdb tables=EAMS_JMU_XC210427.YJS_COURSE,EAMS_JMU_XC210427.STANDERD_CODE,EAMS_JMU_XC210427.PY_XS,EAMS_JMU_XC210427.ZD_YJS_MAJOR directory=data_pump_dir dumpfile=eams_jmu_yjs_210505.dmp logfile=eams_jmu_yjs_210505.log remap_schema=EAMS_JMU_XC210427:eams_jmu remap_tablespace=users:eams cluster=n
  781  impdp eamsadm/eaEr56uLms@s_eamspdb tables=EAMS_JMU_XC210427.YJS_COURSE,EAMS_JMU_XC210427.STANDERD_CODE,EAMS_JMU_XC210427.PY_XS,EAMS_JMU_XC210427.ZD_YJS_MAJOR directory=data_pump_dir dumpfile=eams_jmu_yjs_210505.dmp logfile=eams_jmu_yjs_210505.log remap_schema=EAMS_JMU_XC210427:eams_jmu remap_tablespace=users:eams cluster=n
  801  impdp eamsadm/eaEr56uLms@s_eamspdb tables=EAMS_JMU_XC210427.PY_XS,EAMS_JMU_XC210427.xj,EAMS_JMU_XC210427.zd_yjs_major,EAMS_JMU_XC210427.PY_TABTERM,EAMS_JMU_XC210427.STANDERD_CODE,EAMS_JMU_XC210427.yjs_course,EAMS_JMU_XC210427.PY_PYFA_M,EAMS_JMU_XC210427.PY_PYFA,EAMS_JMU_XC210427.PY_PYJH directory=data_pump_dir dumpfile=eams_jmu_yjs_210518.dmp logfile=eams_jmu_yjs_210518.log remap_schema=EAMS_JMU_XC210427:eams_jmu remap_tablespace=users:eams TABLE_EXISTS_ACTION=REPLACE cluster=n

====================================
  /u01/app/oracle/oradata/ORCL/CAE7CB8D19BB039FE053C90D080A6738/datafile/EOTQ03.db


scp -P 20622 101.231.81.202:/root/eotq0610.zip ./

create pluggable database eotqpdb admin user eotq identified by H2DHiH9yRSx24wK roles=(dba);
create tablespace EOTQ datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace EOTQ add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace EOTQ add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace EOTQ add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace EOTQ add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create pluggable database cwpdb admin user cwpdb identified by dGl6cHdkMTIzIUAj roles=(dba);
alter pluggable database cwpdb open;
alter session set container=cwpdb;

create tablespace cwpdb datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace cwpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace cwpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace cwpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace cwpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user cwuser identified by dGl6cHdkMTIzIUAj default tablespace cwpdb account unlock;

grant dba to cwuser;
grant select any table to cwuser;

sqlplus cwuser/dGl6cHdkMTIzIUAj@10.8.14.15:1521/s_cwpdb

[oracle@oracle1 ~]$ srvctl add service -d xydb -s s_cwpdb -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb cwpdb
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_cwpdb
Service s_cwpdb is not running.
[oracle@oracle1 ~]$ srvctl start service -d xydb -s s_cwpdb
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_cwpdb
Service s_cwpdb is running on instance(s) xydb1,xydb2
[oracle@oracle1 ~]$ lsnrctl status 

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 22-JUL-2021 17:04:23

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                14-JAN-2021 11:47:38
Uptime                    189 days 5 hr. 16 min. 45 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/11.2.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/oracle1/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=10.20.12.118)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=10.8.14.12)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_LOG" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "b8d87a7c092df3ece0530b0e080aa526" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "b8da7d139f9e58f8e0530b0e080a13fd" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "bcc591d8d5bb080ae0530d0e080ac943" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "c474f1e25d5e9735e0530b0e080ac7b9" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "c7b37f1e6557092fe0530b0e080a2ef1" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "cwpdb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "dataassets" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "eamspdb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "eotqpdb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "jmupdb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_cwpdb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_dataassets" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_eamspdb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_eotq" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_jmupdb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[oracle@oracle1 ~]$ 


create tablespace users datafile '/u01/app/oracle/oradata/ORCL/CAE7CB8D19BB039FE053C90D080A6738/datafile/users01.dbf' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace users add datafile '/u01/app/oracle/oradata/ORCL/CAE7CB8D19BB039FE053C90D080A6738/datafile/users02.dbf' size 1G autoextend on next 1G maxsize 31G;


create tablespace users datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace users add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create user eotqv2_jm identified by H2DHiH9yRSx24wK default tablespace EOTQ account unlock;

grant dba to eotqv2_jm;
grant select any table to eotqv2_jm;

impdp eotqv2_jm/H2DHiH9yRSx24wK@s_eotq  schemas=eotqv2_jm directory=eotq_exp dumpfile=eotq0610.dmp 
imp eotqv2_jm/H2DHiH9yRSx24wK@s_eotq  file=eotq0610.dmp  log=eotq0611.log fromuser=eotqv2_jm
imp system/manager file=seapark log=seapark fromuser=seapark

srvctl add service -d xydb  -s s_eotq -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb eotqpdb
[oracle@oracle1 ~]$ srvctl status service -d xydb  -s s_eotq
Service s_eotq is not running.
[oracle@oracle1 ~]$ srvctl start service -d xydb  -s s_eotq
[oracle@oracle1 ~]$ srvctl status service -d xydb  -s s_eotq
Service s_eotq is running on instance(s) xydb1,xydb2
[oracle@oracle1 ~]$ 

expdp eotqv2_jm/H2DHiH9yRSx24wK@10.20.12.118:1521/s_eotq schemas=eotqv2_jm directory=expdir dumpfile=eotqv2_jm_20210901.dmp logfile=eotqv2_jm_20210901.log cluster=n compression=data_only version=12.2.0.1.0
sqlplus eotqv2_jm/H2DHiH9yRSx24wK@10.8.14.15:1521/s_eotq
sqlplus eotqv2_jm/\"jmzlxt@2021\"@10.8.14.15:1521/s_eotq

impdp eotqv2_jm/H2DHiH9yRSx24wK@10.8.13.201:1521/eotqpdb schemas=eotqv2_jm directory=expdir dumpfile=eotqv2_jm_20210901.dmp logfile=eotqv2_jm_20210901.log cluster=n

sqlplus eotqv2_jm/H2DHiH9yRSx24wK@10.8.13.201:1521/eotqpdb
sqlplus idc_u_stu/\"idcustu@sufe1917\"@ecard

sqlplus eotq/H2DHiH9yRSx24wK@10.8.14.15:1521/s_eotq

================================
 srvctl add service -d xydb  -s s_jmupdb -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb jmupdb


create pluggable database jmupdb admin user jmu identified by H2DHiH9yRSx24wK roles=(dba);




CREATE OR REPLACE TRIGGER open_pdbs
  AFTER STARTUP ON DATABASE
BEGIN
   EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
END open_pdbs;
/

pdb

sqlplus jmu/H2DHiH9yRSx24wK@10.8.14.15:1521/s_jmupdb
SQL> select file_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------
+DATA/XYDB/B8D87A7C092DF3ECE0530B0E080AA526/DATAFILE/system.275.1061826497
+DATA/XYDB/B8D87A7C092DF3ECE0530B0E080AA526/DATAFILE/sysaux.276.1061826497
+DATA/XYDB/B8D87A7C092DF3ECE0530B0E080AA526/DATAFILE/undotbs1.274.1061826497
+DATA/XYDB/B8D87A7C092DF3ECE0530B0E080AA526/DATAFILE/undo_2.278.1061832441

cdb  
SQL> select file_name from dba_data_files;
+DATA/XYDB/DATAFILE/system.258.1061760187
+DATA/XYDB/DATAFILE/sysaux.259.1061760223
+DATA/XYDB/DATAFILE/undotbs1.260.1061760237
+DATA/XYDB/DATAFILE/users.261.1061760239
+DATA/XYDB/DATAFILE/undotbs2.270.1061760773


create tablespace portal_service datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace portal_service add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace portal_service add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace portal_service add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace portal_service add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user portal_service identified by H2DHiH9yRSx24wK default tablespace portal_service account unlock;

grant dba to portal_service;
grant select any table to portal_service;


 =========================

create pluggable database hrpdb admin user hrpdb identified by H2D3JHiH9Sx24wK roles=(dba);
alter pluggable database hrpdb open;
alter session set container=hrpdb;

create tablespace hrpdb datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace hrpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace hrpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace hrpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace hrpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create user hruser identified by H2D3JHiH9Sx24wK default tablespace hrpdb account unlock;

grant dba to hruser;
grant select any table to hruser;

sqlplus hruser/H2D3JHiH9Sx24wK@10.8.14.15:1521/s_hrpdb
IP:  10.8.14.15
sqlplus hruser/H2D3JHiH9Sx24wK@10.8.14.15:1521/s_hrpdb
create user hruser1 identified by H2D3JHiH9Sx24wK default tablespace hrpdb account unlock;
grant dba to hruser1;


[oracle@oracle1 ~]$ srvctl add service -d xydb -s s_hrpdb -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb hrpdb
srvctl start service -d xydb -s s_hrpdb

impdp  hruser/H2D3JHiH9Sx24wK@10.20.12.118:1521/s_hrpdb schemas=hruser directory=data_pump_dir dumpfile=eamscce210816.dpdmp logfile=hruser.log remap_tablespace=users:hruser cluster=n  transform=oid:n TABLE_EXISTS_ACTION=replace


impdp directory=expdir dumpfile=GXYS_ORACLE11201_20200921.DMP   schemas=hruser logfile=hruser.log cluster=n  transform=oid:n TABLE_EXISTS_ACTION=replace

 impdp  hruser/H2D3JHiH9Sx24wK@10.20.12.118:1521/s_hrpdb  directory=expdir dumpfile=GXYS_ORACLE11201_20200921.DMP   remap_schema=gxys:hruser remap_tablespace=ykspace:hrpdb  logfile=hruser0823001.log cluster=n  TABLE_EXISTS_ACTION=replace
 impdp  hruser/H2D3JHiH9Sx24wK@10.20.12.118:1521/s_hrpdb  directory=expdir dumpfile=GXYS_ORACLE11201_20200921.DMP   remap_schema=gxys:hruser remap_tablespace=ykspace:hrpdb  logfile=hruser0823001.log cluster=n  TABLE_EXISTS_ACTION=replace

 GXYS
 CREATE USER "GXYS" IDENTIFIED BY VALUES 'S:E2506CB6369F3CF1D4EE2E1B08AABD2C6426472D3550AA809C860277156E;B7971FDB00AC4053'
      DEFAULT TABLESPACE "YKSPACE"
      TEMPORARY TABLESPACE "TEMP";

 ORA-02374: conversion error loading table "HRUSER"."TPARAM"
ORA-12899: value too large for column PARAMNAME (actual: 37, maximum: 30)

ORA-02372: data for row: PARAMNAME : 0X'B5A5CEBBB5D8D6B75FB5D8A3A8CAD0A1A2D6DDA1A2C3CBA3A9'


ORA-02374: conversion error loading table "HRUSER"."TPARAM"
ORA-12899: value too large for column PARAMNAME (actual: 37, maximum: 30)

ORA-02372: data for row: PARAMNAME : 0X'B5A5CEBBB5D8D6B75FCFD8A3A8CAD0A1A2C7F8A1A2C6ECA3A9'


ORA-02374: conversion error loading table "HRUSER"."TPARAM"
ORA-12899: value too large for column PARAMNAME (actual: 43, maximum: 30)

ORA-02372: data for row: PARAMNAME : 0X'B5A5CEBBB5D8D6B75FCAA1A3A8D7D4D6CEC7F8A1A2D6B1CFBD'


ORA-02374: conversion error loading table "HRUSER"."TPARAM"
ORA-12899: value too large for column PARAMNAME (actual: 36, maximum: 30)

ORA-02372: data for row: PARAMNAME : 0X'C1AACFB5B5E7BBB0A3A8B0FCC0A8B5D8C7F8BAC5C2EBA3A9'



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
SQL> 

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

 create pluggable database jwpdb1 admin user jwpdb identified by supwisdom210831 roles=(dba);
alter alter pluggable database jwpdb1 open;
alter session set container=jwpdb1;



create tablespace users datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace users add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace users add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace users add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace users add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create tablespace eams datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace eams add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace eams add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace eams add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace eams add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter user system identified by supwisdom210831 account unlock;



 

 create pluggable database rptpdb admin user rptpdb identified by J3dx0J3HH29LmH9S roles=(dba);
alter pluggable database rptpdb open;
alter session set container=rptpdb;

create tablespace rptpdb datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace rptpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace rptpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace rptpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace rptpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create user rpt identified by J3dx0J3HH29LmH9S default tablespace rptpdb account unlock;

grant dba to rpt;
grant select any table to rpt;

sqlplus rpt/J3dx0J3HH29LmH9S@10.8.14.15:1521/s_rpt

[oracle@oracle1 ~]$ srvctl add service -d xydb -s s_rpt -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb rptpdb
srvctl start service -d xydb -s s_rptpdb



cdb
create pluggable database dataassets admin user jmu identified by H2DHiH9yRSx24wK roles=(dba);

oracle
srvctl add service -d xydb  -s s_dataassets -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets
srvctl status service -d xydb  -s s_dataassets
srvctl start service -d xydb  -s s_dataassets
grid
crsctl status resource -t

pdb
sqlplus jmu/H2DHiH9yRSx24wK@10.8.14.15:1521/s_dataassets
--查询表空间
select file_name,tablespace_name from dba_data_files order by tablespace_name;
+DATA/XYDB/B8DA7D139F9E58F8E0530B0E080A13FD/DATAFILE/undotbs1.285.1061835129	 UNDOTBS1

SELECT T.FILE_NAME FROM DBA_DATA_FILES T  --查询表空间创建物理位置，查询结果替换创建表空间‘/home/u01/app/oracle/oradata/xydb/’部分

--创建表空间

create tablespace IDC_DATA_ASSETS datafile '+DATA' size 1G autoextend on next 1G maxsize unlimited extent management local segment space management auto; 


create tablespace IDC_DATA_SHAREDB datafile '+DATA' size 1G autoextend on next 1G maxsize unlimited extent management local segment space management auto; 

create tablespace IDC_DATA_STANDCODE datafile '+DATA' size 1G autoextend on next 1G maxsize unlimited extent management local segment space management auto; 

create tablespace IDC_DATA_SWOP datafile '+DATA' size 1G autoextend on next 1G maxsize unlimited extent management local segment space management auto; 

alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_SHAREDB add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_SHAREDB add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_STANDCODE add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_SWOP add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace IDC_DATA_ASSETS add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

sqlplus IDC_DATA_ASSETS/H2DHiH9yRSx24wK@10.8.14.15:1521/s_dataassets
sqlplus IDC_DATA_STANDCODE/H2DHiH9yRSx24wK@10.8.14.15:1521/s_dataassets
sqlplus IDC_DATA_SHAREDB/H2DHiH9yRSx24wK@10.8.14.15:1521/s_dataassets
 idc_data_standcode
--创建 IDC_DATA_ASSETS 用户

create user IDC_DATA_ASSETS identified by H2DHiH9yRSx24wK
default tablespace IDC_DATA_ASSETS
temporary tablespace TEMP
profile DEFAULT;
grant dba to IDC_DATA_ASSETS;
grant connect to IDC_DATA_ASSETS;
grant select any table to IDC_DATA_ASSETS;

create user IDC_DATA_API identified by H2DHiH9yRSx24wK
default tablespace IDC_DATA_ASSETS
temporary tablespace TEMP
profile DEFAULT;
grant dba to IDC_DATA_API;
grant connect to IDC_DATA_API;
grant select any table to IDC_DATA_API; 





alter user IDC_DATA_ASSETS default tablespace IDC_DATA_ASSETS temporary tablespace TEMP;

--创建 IDC_DATA_SHAREDB 用户

create user IDC_DATA_SHAREDB identified by H2DHiH9yRSx24wK
default tablespace IDC_DATA_SHAREDB
temporary tablespace TEMP
profile DEFAULT;
grant dba to IDC_DATA_SHAREDB;
grant connect to IDC_DATA_SHAREDB;
grant select any table to IDC_DATA_SHAREDB;

--创建 IDC_DATA_STANDCODE 用户

create user IDC_DATA_STANDCODE identified by H2DHiH9yRSx24wK
default tablespace IDC_DATA_STANDCODE
temporary tablespace TEMP
profile DEFAULT;
grant dba to IDC_DATA_STANDCODE;
grant connect to IDC_DATA_STANDCODE;
grant select any table to IDC_DATA_STANDCODE;

--创建 IDC_DATA_SWOP 用户

create user IDC_DATA_SWOP identified by H2DHiH9yRSx24wK
default tablespace IDC_DATA_SWOP
temporary tablespace TEMP
profile DEFAULT;
grant dba to IDC_DATA_SWOP;
grant connect to IDC_DATA_SWOP;
grant select any table to IDC_DATA_SWOP;

select username,account_status from dba_users order by account_status;
SYSKM			       LOCKED
JMU			          OPEN

USERNAME		       ACCOUNT_STATUS
------------------------------ --------------------------------
IDC_DATA_SHAREDB	       OPEN
SYS			       OPEN
IDC_DATA_STANDCODE	       OPEN
SYSTEM			       OPEN
IDC_DATA_SWOP		       OPEN
IDC_DATA_ASSETS 	       OPEN
DBSNMP			       OPEN

40 rows selected.


--mysql创建用户、数据库的语句

   set global validate_password.policy=0;
   set global validate_password.length=1;

create user 'dataassets_api'@'%' identified with mysql_native_password  by '2PxmfuqBZnf6%@#';

create database `dataassets_api` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;

grant all privileges on `dataassets_api`.* to 'dataassets_api'@'%' with grant option;

grant SUPER on *.* to 'dataassets_api'@'%';

==========================
mysqldump --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF -u root -p -P 3306 > dbdump.db

#!/bin/bash
# mysql 数据库全量备份

# 用户名、密码、数据库名
username="root"
password="Sup123!@#"
dbName="goodthing"

beginTime=`date +"%Y年%m月%d日 %H:%M:%S"`
# 备份目录
bakDir=/home/mysql/backup
# 日志文件
logFile=/home/mysql/backup/bak.log
# 备份文件
nowDate=`date +%Y%m%d`
dumpFile="${dbName}_${nowDate}.sql"
gzDumpFile="${dbName}_${nowDate}.sql.tgz"

cd $bakDir
# 全量备份（对所有数据库备份，除了数据库goodthing里的village表）
/usr/local/mysql/bin/mysqldump -u${username} -p${password} --quick --events --databases ${dbName} --ignore-table=goodthing.village --ignore-table=goodthing.area --flush-logs --delete-master-logs --single-transaction > $dumpFile
# 打包
/bin/tar -zvcf $gzDumpFile $dumpFile
/bin/rm $dumpFile

endTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo 开始:$beginTime 结束:$endTime $gzDumpFile succ >> $logFile

# 删除所有增量备份
cd $bakDir/daily
/bin/rm -f *

##删除过期备份
find $bakDir -name 'mysql_*.sql.tgz' -mtime +30 -exec rm {} \;
==========================

/home/oracle/eotqv2_jm_20210915.dmp
SveQg977EHrD
expdp eotqv2_jm/H2DHiH9yRSx24wK@10.20.12.118:1521/s_eotq schemas=eotqv2_jm directory=expdir dumpfile=eotqv2_jm_20210915.dmp logfile=eotqv2_jm_20210915.log cluster=n

impdp eotqv2_jm/H2DHiH9yRSx24wK@10.8.13.201:1521/eotqpdb schemas=eotqv2_jm directory=expdir dumpfile=eotqv2_jm_20210915.dmp logfile=eotqv2_jm_20210915.log cluster=n TABLE_EXISTS_ACTION=replace

SQL>  select saddr,sid,serial#,paddr,username,status from v$session where username = 'EOTQV2_JM';

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E07D3C10	  7	 59647 00000000E45198A8 EOTQV2_JM		       INACTIVE
00000000E87E91C8	127	 58287 00000000E05388E8 EOTQV2_JM		       INACTIVE
00000000E8824F88	151	  4844 00000000E052DDE8 EOTQV2_JM		       INACTIVE
00000000E08F7918	245	 44135 00000000DC637B40 EOTQV2_JM		       INACTIVE
00000000E0924768	263	 29375 00000000DC64D140 EOTQV2_JM		       INACTIVE
00000000E092BF20	266	 64259 00000000DC642640 EOTQV2_JM		       INACTIVE
00000000E8920E10	373	 38263 00000000E853A900 EOTQV2_JM		       INACTIVE
00000000E892ADB0	377	 61344 00000000E8545400 EOTQV2_JM		       INACTIVE
00000000E0A2F560	491	 46002 00000000E451AE08 EOTQV2_JM		       INACTIVE
00000000E0A54BF8	506	 20509 00000000E4505808 EOTQV2_JM		       INACTIVE
00000000E0A573E0	507	 48545 00000000E4510308 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E8A651E0	624	 42203 00000000E0539E48 EOTQV2_JM		       INACTIVE
00000000E8B7EF48	858	 10240 00000000E853BE60 EOTQV2_JM		       INACTIVE
00000000E8B81730	859	  5939 00000000E8531360 EOTQV2_JM		       INACTIVE
00000000E0CB7D00	993	 14393 00000000E4511868 EOTQV2_JM		       INACTIVE
00000000E0DB13A0       1214	  5915 00000000DC645100 EOTQV2_JM		       INACTIVE
00000000E0DEF948       1239	 58464 00000000DC63A600 EOTQV2_JM		       INACTIVE
00000000E8DDA898       1342	 12234 00000000E85127C0 EOTQV2_JM		       INACTIVE
00000000E8DF5F90       1353	   349 00000000E853D3C0 EOTQV2_JM		       INACTIVE
00000000E0F27590       1485	 41417 00000000E4512DC8 EOTQV2_JM		       INACTIVE
00000000E8F28C08       1597	 23236 00000000E053C908 EOTQV2_JM		       INACTIVE
00000000E10144A8       1701	 65319 00000000DC631060 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E1032388       1713	  7772 00000000DC626560 EOTQV2_JM		       INACTIVE
00000000E1037358       1715	 51254 00000000DC646660 EOTQV2_JM		       INACTIVE
00000000E103EB10       1718	 27981 00000000DC63BB60 EOTQV2_JM		       INACTIVE
00000000E903B1B8       1828	 13833 00000000E8533E20 EOTQV2_JM		       INACTIVE
00000000E113F968       1942	 23131 00000000E4509828 EOTQV2_JM		       INACTIVE
00000000E9195CB0       2088	 16616 00000000E053DE68 EOTQV2_JM		       INACTIVE
00000000E127C580       2190	 63392 00000000DC63D0C0 EOTQV2_JM		       INACTIVE
00000000E129A460       2202	  8839 00000000DC647BC0 EOTQV2_JM		       INACTIVE
00000000E92AD230       2321	 23031 00000000E853FE80 EOTQV2_JM		       INACTIVE
00000000E92AFA18       2322	 47005 00000000E8535380 EOTQV2_JM		       INACTIVE
00000000E1391318       2422	  6095 00000000E4515888 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E13BB980       2439	 34987 00000000E450AD88 EOTQV2_JM		       INACTIVE
00000000E93B5840       2548	 21532 00000000E05348C8 EOTQV2_JM		       INACTIVE
00000000E93CBF68       2557	 61341 00000000E053F3C8 EOTQV2_JM		       INACTIVE
00000000E14C17A8       2665	 20836 00000000DC63E620 EOTQV2_JM		       INACTIVE
00000000E14DCEA0       2676	  7136 00000000DC649120 EOTQV2_JM		       INACTIVE
00000000E94E5CD0       2791	 13790 00000000E85413E0 EOTQV2_JM		       INACTIVE
00000000E15FBBD8       2912	 21392 00000000E450C2E8 EOTQV2_JM		       INACTIVE
00000000E160D330       2919	 46789 00000000E4516DE8 EOTQV2_JM		       INACTIVE
00000000E962A0A0       3042	 44110 00000000E0540928 EOTQV2_JM		       INACTIVE
00000000E9631858       3045	 13439 00000000E04B5A28 EOTQV2_JM		       INACTIVE
00000000E173AFD8       3161	 24378 00000000DC63FB80 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E18485B8       3390	 59486 00000000E4518348 EOTQV2_JM		       INACTIVE
00000000E1859D10       3397	 55713 00000000E4502D48 EOTQV2_JM		       INACTIVE
00000000E18932E8       3420	 27203 00000000E450D848 EOTQV2_JM		       INACTIVE
00000000E98A10E8       3537	 25910 00000000E0541E88 EOTQV2_JM		       INACTIVE
00000000E19829E8       3637	 62793 00000000DC64BBE0 EOTQV2_JM		       INACTIVE
00000000E999F758       3760	 30976 00000000E8543EA0 EOTQV2_JM		       INACTIVE

50 rows selected.

SQL> 

SQL> /

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E07D3C10	  7	 59647 00000000E45198A8 EOTQV2_JM		       INACTIVE
00000000E87E91C8	127	 58287 00000000E05388E8 EOTQV2_JM		       INACTIVE
00000000E8824F88	151	  4844 00000000E052DDE8 EOTQV2_JM		       INACTIVE
00000000E08F7918	245	 44135 00000000DC637B40 EOTQV2_JM		       INACTIVE
00000000E0924768	263	 29375 00000000DC64D140 EOTQV2_JM		       INACTIVE
00000000E092BF20	266	 64259 00000000DC642640 EOTQV2_JM		       INACTIVE
00000000E8920E10	373	 38263 00000000E853A900 EOTQV2_JM		       INACTIVE
00000000E892ADB0	377	 61344 00000000E8545400 EOTQV2_JM		       INACTIVE
00000000E0A2F560	491	 46002 00000000E451AE08 EOTQV2_JM		       INACTIVE
00000000E0A54BF8	506	 20509 00000000E4505808 EOTQV2_JM		       INACTIVE
00000000E0A573E0	507	 48545 00000000E4510308 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E8A651E0	624	 42203 00000000E0539E48 EOTQV2_JM		       INACTIVE
00000000E8B7EF48	858	 10240 00000000E853BE60 EOTQV2_JM		       INACTIVE
00000000E8B81730	859	  5939 00000000E8531360 EOTQV2_JM		       INACTIVE
00000000E0CB7D00	993	 14393 00000000E4511868 EOTQV2_JM		       INACTIVE
00000000E0DB13A0       1214	  5915 00000000DC645100 EOTQV2_JM		       INACTIVE
00000000E0DEF948       1239	 58464 00000000DC63A600 EOTQV2_JM		       INACTIVE
00000000E8DDA898       1342	 12234 00000000E85127C0 EOTQV2_JM		       INACTIVE
00000000E8DF5F90       1353	   349 00000000E853D3C0 EOTQV2_JM		       INACTIVE
00000000E0F27590       1485	 41417 00000000E4512DC8 EOTQV2_JM		       INACTIVE
00000000E8F28C08       1597	 23236 00000000E053C908 EOTQV2_JM		       INACTIVE
00000000E10144A8       1701	 65319 00000000DC631060 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E1032388       1713	  7772 00000000DC626560 EOTQV2_JM		       INACTIVE
00000000E1037358       1715	 51254 00000000DC646660 EOTQV2_JM		       INACTIVE
00000000E103EB10       1718	 27981 00000000DC63BB60 EOTQV2_JM		       INACTIVE
00000000E903B1B8       1828	 13833 00000000E8533E20 EOTQV2_JM		       INACTIVE
00000000E113F968       1942	 23131 00000000E4509828 EOTQV2_JM		       INACTIVE
00000000E9195CB0       2088	 16616 00000000E053DE68 EOTQV2_JM		       INACTIVE
00000000E127C580       2190	 63392 00000000DC63D0C0 EOTQV2_JM		       INACTIVE
00000000E129A460       2202	  8839 00000000DC647BC0 EOTQV2_JM		       INACTIVE
00000000E92AD230       2321	 23031 00000000E853FE80 EOTQV2_JM		       INACTIVE
00000000E92AFA18       2322	 47005 00000000E8535380 EOTQV2_JM		       INACTIVE
00000000E1391318       2422	  6095 00000000E4515888 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E13BB980       2439	 34987 00000000E450AD88 EOTQV2_JM		       INACTIVE
00000000E93B5840       2548	 21532 00000000E05348C8 EOTQV2_JM		       INACTIVE
00000000E93CBF68       2557	 61341 00000000E053F3C8 EOTQV2_JM		       INACTIVE
00000000E14C17A8       2665	 20836 00000000DC63E620 EOTQV2_JM		       INACTIVE
00000000E14DCEA0       2676	  7136 00000000DC649120 EOTQV2_JM		       INACTIVE
00000000E94E5CD0       2791	 13790 00000000E85413E0 EOTQV2_JM		       INACTIVE
00000000E15FBBD8       2912	 21392 00000000E450C2E8 EOTQV2_JM		       INACTIVE
00000000E160D330       2919	 46789 00000000E4516DE8 EOTQV2_JM		       INACTIVE
00000000E962A0A0       3042	 44110 00000000E0540928 EOTQV2_JM		       INACTIVE
00000000E9631858       3045	 13439 00000000E04B5A28 EOTQV2_JM		       INACTIVE
00000000E173AFD8       3161	 24378 00000000DC63FB80 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E18485B8       3390	 59486 00000000E4518348 EOTQV2_JM		       INACTIVE
00000000E1859D10       3397	 55713 00000000E4502D48 EOTQV2_JM		       INACTIVE
00000000E18932E8       3420	 27203 00000000E450D848 EOTQV2_JM		       INACTIVE
00000000E98A10E8       3537	 25910 00000000E0541E88 EOTQV2_JM		       INACTIVE
00000000E19829E8       3637	 62793 00000000DC64BBE0 EOTQV2_JM		       INACTIVE
00000000E999F758       3760	 30976 00000000E8543EA0 EOTQV2_JM		       INACTIVE

50 rows selected.

SQL> 
/home/oracle/eotqv2_jm_20210915.dmp
SveQg977EHrD
expdp eotqv2_jm/H2DHiH9yRSx24wK@10.20.12.118:1521/s_eotq schemas=eotqv2_jm directory=expdir dumpfile=eotqv2_jm_20210915.dmp logfile=eotqv2_jm_20210915.log cluster=n

impdp eotqv2_jm/H2DHiH9yRSx24wK@10.8.13.201:1521/eotqpdb schemas=eotqv2_jm directory=expdir dumpfile=eotqv2_jm_20210915.dmp logfile=eotqv2_jm_20210915.log cluster=n TABLE_EXISTS_ACTION=replace

SQL>  select saddr,sid,serial#,paddr,username,status from v$session where username = 'EOTQV2_JM';

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E07D3C10	  7	 59647 00000000E45198A8 EOTQV2_JM		       INACTIVE
00000000E87E91C8	127	 58287 00000000E05388E8 EOTQV2_JM		       INACTIVE
00000000E8824F88	151	  4844 00000000E052DDE8 EOTQV2_JM		       INACTIVE
00000000E08F7918	245	 44135 00000000DC637B40 EOTQV2_JM		       INACTIVE
00000000E0924768	263	 29375 00000000DC64D140 EOTQV2_JM		       INACTIVE
00000000E092BF20	266	 64259 00000000DC642640 EOTQV2_JM		       INACTIVE
00000000E8920E10	373	 38263 00000000E853A900 EOTQV2_JM		       INACTIVE
00000000E892ADB0	377	 61344 00000000E8545400 EOTQV2_JM		       INACTIVE
00000000E0A2F560	491	 46002 00000000E451AE08 EOTQV2_JM		       INACTIVE
00000000E0A54BF8	506	 20509 00000000E4505808 EOTQV2_JM		       INACTIVE
00000000E0A573E0	507	 48545 00000000E4510308 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E8A651E0	624	 42203 00000000E0539E48 EOTQV2_JM		       INACTIVE
00000000E8B7EF48	858	 10240 00000000E853BE60 EOTQV2_JM		       INACTIVE
00000000E8B81730	859	  5939 00000000E8531360 EOTQV2_JM		       INACTIVE
00000000E0CB7D00	993	 14393 00000000E4511868 EOTQV2_JM		       INACTIVE
00000000E0DB13A0       1214	  5915 00000000DC645100 EOTQV2_JM		       INACTIVE
00000000E0DEF948       1239	 58464 00000000DC63A600 EOTQV2_JM		       INACTIVE
00000000E8DDA898       1342	 12234 00000000E85127C0 EOTQV2_JM		       INACTIVE
00000000E8DF5F90       1353	   349 00000000E853D3C0 EOTQV2_JM		       INACTIVE
00000000E0F27590       1485	 41417 00000000E4512DC8 EOTQV2_JM		       INACTIVE
00000000E8F28C08       1597	 23236 00000000E053C908 EOTQV2_JM		       INACTIVE
00000000E10144A8       1701	 65319 00000000DC631060 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E1032388       1713	  7772 00000000DC626560 EOTQV2_JM		       INACTIVE
00000000E1037358       1715	 51254 00000000DC646660 EOTQV2_JM		       INACTIVE
00000000E103EB10       1718	 27981 00000000DC63BB60 EOTQV2_JM		       INACTIVE
00000000E903B1B8       1828	 13833 00000000E8533E20 EOTQV2_JM		       INACTIVE
00000000E113F968       1942	 23131 00000000E4509828 EOTQV2_JM		       INACTIVE
00000000E9195CB0       2088	 16616 00000000E053DE68 EOTQV2_JM		       INACTIVE
00000000E127C580       2190	 63392 00000000DC63D0C0 EOTQV2_JM		       INACTIVE
00000000E129A460       2202	  8839 00000000DC647BC0 EOTQV2_JM		       INACTIVE
00000000E92AD230       2321	 23031 00000000E853FE80 EOTQV2_JM		       INACTIVE
00000000E92AFA18       2322	 47005 00000000E8535380 EOTQV2_JM		       INACTIVE
00000000E1391318       2422	  6095 00000000E4515888 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E13BB980       2439	 34987 00000000E450AD88 EOTQV2_JM		       INACTIVE
00000000E93B5840       2548	 21532 00000000E05348C8 EOTQV2_JM		       INACTIVE
00000000E93CBF68       2557	 61341 00000000E053F3C8 EOTQV2_JM		       INACTIVE
00000000E14C17A8       2665	 20836 00000000DC63E620 EOTQV2_JM		       INACTIVE
00000000E14DCEA0       2676	  7136 00000000DC649120 EOTQV2_JM		       INACTIVE
00000000E94E5CD0       2791	 13790 00000000E85413E0 EOTQV2_JM		       INACTIVE
00000000E15FBBD8       2912	 21392 00000000E450C2E8 EOTQV2_JM		       INACTIVE
00000000E160D330       2919	 46789 00000000E4516DE8 EOTQV2_JM		       INACTIVE
00000000E962A0A0       3042	 44110 00000000E0540928 EOTQV2_JM		       INACTIVE
00000000E9631858       3045	 13439 00000000E04B5A28 EOTQV2_JM		       INACTIVE
00000000E173AFD8       3161	 24378 00000000DC63FB80 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E18485B8       3390	 59486 00000000E4518348 EOTQV2_JM		       INACTIVE
00000000E1859D10       3397	 55713 00000000E4502D48 EOTQV2_JM		       INACTIVE
00000000E18932E8       3420	 27203 00000000E450D848 EOTQV2_JM		       INACTIVE
00000000E98A10E8       3537	 25910 00000000E0541E88 EOTQV2_JM		       INACTIVE
00000000E19829E8       3637	 62793 00000000DC64BBE0 EOTQV2_JM		       INACTIVE
00000000E999F758       3760	 30976 00000000E8543EA0 EOTQV2_JM		       INACTIVE

50 rows selected.

SQL> 

SQL> /

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E07D3C10	  7	 59647 00000000E45198A8 EOTQV2_JM		       INACTIVE
00000000E87E91C8	127	 58287 00000000E05388E8 EOTQV2_JM		       INACTIVE
00000000E8824F88	151	  4844 00000000E052DDE8 EOTQV2_JM		       INACTIVE
00000000E08F7918	245	 44135 00000000DC637B40 EOTQV2_JM		       INACTIVE
00000000E0924768	263	 29375 00000000DC64D140 EOTQV2_JM		       INACTIVE
00000000E092BF20	266	 64259 00000000DC642640 EOTQV2_JM		       INACTIVE
00000000E8920E10	373	 38263 00000000E853A900 EOTQV2_JM		       INACTIVE
00000000E892ADB0	377	 61344 00000000E8545400 EOTQV2_JM		       INACTIVE
00000000E0A2F560	491	 46002 00000000E451AE08 EOTQV2_JM		       INACTIVE
00000000E0A54BF8	506	 20509 00000000E4505808 EOTQV2_JM		       INACTIVE
00000000E0A573E0	507	 48545 00000000E4510308 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E8A651E0	624	 42203 00000000E0539E48 EOTQV2_JM		       INACTIVE
00000000E8B7EF48	858	 10240 00000000E853BE60 EOTQV2_JM		       INACTIVE
00000000E8B81730	859	  5939 00000000E8531360 EOTQV2_JM		       INACTIVE
00000000E0CB7D00	993	 14393 00000000E4511868 EOTQV2_JM		       INACTIVE
00000000E0DB13A0       1214	  5915 00000000DC645100 EOTQV2_JM		       INACTIVE
00000000E0DEF948       1239	 58464 00000000DC63A600 EOTQV2_JM		       INACTIVE
00000000E8DDA898       1342	 12234 00000000E85127C0 EOTQV2_JM		       INACTIVE
00000000E8DF5F90       1353	   349 00000000E853D3C0 EOTQV2_JM		       INACTIVE
00000000E0F27590       1485	 41417 00000000E4512DC8 EOTQV2_JM		       INACTIVE
00000000E8F28C08       1597	 23236 00000000E053C908 EOTQV2_JM		       INACTIVE
00000000E10144A8       1701	 65319 00000000DC631060 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E1032388       1713	  7772 00000000DC626560 EOTQV2_JM		       INACTIVE
00000000E1037358       1715	 51254 00000000DC646660 EOTQV2_JM		       INACTIVE
00000000E103EB10       1718	 27981 00000000DC63BB60 EOTQV2_JM		       INACTIVE
00000000E903B1B8       1828	 13833 00000000E8533E20 EOTQV2_JM		       INACTIVE
00000000E113F968       1942	 23131 00000000E4509828 EOTQV2_JM		       INACTIVE
00000000E9195CB0       2088	 16616 00000000E053DE68 EOTQV2_JM		       INACTIVE
00000000E127C580       2190	 63392 00000000DC63D0C0 EOTQV2_JM		       INACTIVE
00000000E129A460       2202	  8839 00000000DC647BC0 EOTQV2_JM		       INACTIVE
00000000E92AD230       2321	 23031 00000000E853FE80 EOTQV2_JM		       INACTIVE
00000000E92AFA18       2322	 47005 00000000E8535380 EOTQV2_JM		       INACTIVE
00000000E1391318       2422	  6095 00000000E4515888 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E13BB980       2439	 34987 00000000E450AD88 EOTQV2_JM		       INACTIVE
00000000E93B5840       2548	 21532 00000000E05348C8 EOTQV2_JM		       INACTIVE
00000000E93CBF68       2557	 61341 00000000E053F3C8 EOTQV2_JM		       INACTIVE
00000000E14C17A8       2665	 20836 00000000DC63E620 EOTQV2_JM		       INACTIVE
00000000E14DCEA0       2676	  7136 00000000DC649120 EOTQV2_JM		       INACTIVE
00000000E94E5CD0       2791	 13790 00000000E85413E0 EOTQV2_JM		       INACTIVE
00000000E15FBBD8       2912	 21392 00000000E450C2E8 EOTQV2_JM		       INACTIVE
00000000E160D330       2919	 46789 00000000E4516DE8 EOTQV2_JM		       INACTIVE
00000000E962A0A0       3042	 44110 00000000E0540928 EOTQV2_JM		       INACTIVE
00000000E9631858       3045	 13439 00000000E04B5A28 EOTQV2_JM		       INACTIVE
00000000E173AFD8       3161	 24378 00000000DC63FB80 EOTQV2_JM		       INACTIVE

SADDR			SID    SERIAL# PADDR		USERNAME		       STATUS
---------------- ---------- ---------- ---------------- ------------------------------ --------
00000000E18485B8       3390	 59486 00000000E4518348 EOTQV2_JM		       INACTIVE
00000000E1859D10       3397	 55713 00000000E4502D48 EOTQV2_JM		       INACTIVE
00000000E18932E8       3420	 27203 00000000E450D848 EOTQV2_JM		       INACTIVE
00000000E98A10E8       3537	 25910 00000000E0541E88 EOTQV2_JM		       INACTIVE
00000000E19829E8       3637	 62793 00000000DC64BBE0 EOTQV2_JM		       INACTIVE
00000000E999F758       3760	 30976 00000000E8543EA0 EOTQV2_JM		       INACTIVE

50 rows selected.

SQL> 

SELECT owner, object_name, object_type,status 
FROM dba_objects 
WHERE status = 'INVALID';

alter user EOTQV2_JM account lock;
select saddr,sid,serial#,paddr,username,status from v$session where username = 'EOTQV2_JM';
alter system kill session '124,12343';













alter user EOTQV2_JM account lock;
select saddr,sid,serial#,paddr,username,status from v$session where username = 'EOTQV2_JM';
alter system kill session '124,12343';





=====================
1、外事系统 数据库名：s_flow   用户urpuser               (  新建租户 ) 
2、旧平台：                  s_flow    用户 urpuser             (  新建租户 ) 
3、流程填报数据库：    s_flow       用户 sharedb_flow   (  跟 sharedb  是同一个实例 ) 
4、财务科研对接：  数据库名   s_cwkyuser       用户   cwkyuser 

sqlplus wsuser/L2dcjjxx111UAj@10.8.14.15:1521/s_wspdb
sqlplus urpuser/J3nmmAAb6EYn@10.8.14.15:1521/s_urpdb
sqlplus sharedb_flow/Yab004Jmaleu@10.8.14.15:1521/s_flow



create pluggable database wspdb admin user wspdb identified by dGl6cLgemxq12ed roles=(dba);
alter pluggable database wspdb open;
alter session set container=wspdb;

create tablespace wspdb datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace wspdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace wspdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace wspdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace wspdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user wsuser identified by L2dcjjxx111UAj default tablespace wspdb account unlock;

grant dba to wsuser;
grant select any table to wsuser;

sqlplus wsuser/L2dcjjxx111UAj@10.8.14.15:1521/s_wspdb

[oracle@oracle1 ~]$ srvctl add service -d xydb -s s_wspdb -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb wspdb
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_wspdb
Service s_wspdb is not running.
[oracle@oracle1 ~]$ srvctl start service -d xydb -s s_wspdb
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_wspdb
Service s_wspdb is running on instance(s) xydb1,xydb2
[oracle@oracle1 ~]$ lsnrctl status 

-------------------

create pluggable database urpdb admin user urpdb identified by J38xmmAqbc12ed roles=(dba);
alter pluggable database urpdb open;
alter session set container=urpdb;

create tablespace urpdb datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user urpuser identified by J3nmmAAb6EYn default tablespace urpdb account unlock;

grant dba to urpuser;
grant select any table to urpuser;

sqlplus urpuser/J3nmmAAb6EYn@10.8.14.15:1521/s_urpdb

[oracle@oracle1 ~]$ srvctl add service -d xydb -s s_urpdb -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb urpdb
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_urpdb
Service s_urpdb is not running.
[oracle@oracle1 ~]$ srvctl start service -d xydb -s s_urpdb
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_urpdb
Service s_urpdb is running on instance(s) xydb1,xydb2
[oracle@oracle1 ~]$ lsnrctl status 

---------------
create tablespace flow datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace flow add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace flow add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace flow add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace flow add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user sharedb_flow identified by Yab004Jmaleu default tablespace flow account unlock;

grant dba to sharedb_flow;
grant select any table to urpuser;

sqlplus sharedb_flow/Yab004Jmaleu@10.8.14.15:1521/s_flow

[oracle@oracle1 ~]$ srvctl add service -d xydb -s s_flow -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets 
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_flow
Service s_flow is not running.
[oracle@oracle1 ~]$ srvctl start service -d xydb -s s_flow
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_flow
Service s_flow is running on instance(s) xydb1,xydb2
[oracle@oracle1 ~]$ lsnrctl status 

-------------------

create pluggable database cwkyuser admin user cwkyuseradmin identified by L36Jbew1Blo roles=(dba);
alter pluggable database cwkyuser open;
alter session set container=cwkyuser;

create tablespace cwkyuser datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;
alter tablespace cwkyuser add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace cwkyuser add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace cwkyuser add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace cwkyuser add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user cwkyuser identified by Y3nGwjZbeljy2 default tablespace cwkyuser account unlock;

grant dba to cwkyuser;
grant select any table to cwkyuser;

sqlplus cwkyuser/Y3nGwjZbeljy2@10.8.14.15:1521/s_cwkyuser

[oracle@oracle1 ~]$ srvctl add service -d xydb -s s_cwkyuser -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb cwkyuser
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_cwkyuser
Service s_cwkyuser is not running.
[oracle@oracle1 ~]$ srvctl start service -d xydb -s s_cwkyuser
[oracle@oracle1 ~]$ srvctl status service -d xydb -s s_cwkyuser
Service s_cwkyuser is running on instance(s) xydb1,xydb2
[oracle@oracle1 ~]$ lsnrctl status 

---------------
-----------------

-----------------
-----------------
01-NOV-2021 17:19:26 * (CONNECT_DATA=(SERVICE_NAME=s_hrpdb)(CID=(PROGRAM=C:\Program?Files\PremiumSoft\Navicat?Premium?12\navicat.exe)(HOST=JCPT-JUMPBOX)(USER=Administrator))(SERVER=dedicated)(INSTANCE_NAME=xydb2)) * (ADDRESS=(PROTOCOL=tcp)(HOST=10.8.13.2)(PORT=59391)) * establish * s_hrpdb * 0
01-NOV-2021 17:31:35 * (CONNECT_DATA=(SERVICE_NAME=s_hrpdb)(CID=(PROGRAM=C:\Program?Files\PremiumSoft\Navicat?Premium?12\navicat.exe)(HOST=JCPT-JUMPBOX)(USER=Administrator))(SERVER=dedicated)(INSTANCE_NAME=xydb2)) * (ADDRESS=(PROTOCOL=tcp)(HOST=10.8.13.2)(PORT=59443)) * establish * s_hrpdb * 0




01-NOV-2021 17:32:16 * (CONNECT_DATA=(SERVICE_NAME=s_hrpdb)(CID=(PROGRAM=sqlplus)(HOST=jcpt-oracletest)(USER=oracle))) * (ADDRESS=(PROTOCOL=tcp)(HOST=10.8.13.201)(PORT=38004)) * establish * s_hrpdb * 0

[oracle@oracle2 trace]$ tail -f listener.log |grep s_data


01-NOV-2021 17:34:07 * (CONNECT_DATA=(SERVICE_NAME=s_dataassets)(CID=(PROGRAM=C:\Program?Files\PremiumSoft\Navicat?Premium?12\navicat.exe)(HOST=JCPT-JUMPBOX)(USER=Administrator))) * (ADDRESS=(PROTOCOL=tcp)(HOST=10.8.13.2)(PORT=59446)) * establish * s_dataassets * 0



^C
[oracle@oracle2 trace]$ tail -f listener.log |grep s_hrpdb
01-NOV-2021 17:34:29 * (CONNECT_DATA=(SERVICE_NAME=s_hrpdb)(CID=(PROGRAM=C:\Program?Files\PremiumSoft\Navicat?Premium?12\navicat.exe)(HOST=JCPT-JUMPBOX)(USER=Administrator))(SERVER=dedicated)(INSTANCE_NAME=xydb2)) * (ADDRESS=(PROTOCOL=tcp)(HOST=10.8.13.2)(PORT=59451)) * establish * s_hrpdb * 0


01-NOV-2021 17:39:19 * (CONNECT_DATA=(SERVICE_NAME=s_hrpdb)(CID=(PROGRAM=C:\Program?Files\PremiumSoft\Navicat?Premium?12\navicat.exe)(HOST=JCPT-JUMPBOX)(USER=Administrator))(SERVER=dedicated)(INSTANCE_NAME=xydb2)) * (ADDRESS=(PROTOCOL=tcp)(HOST=10.8.13.2)(PORT=59463)) * establish * s_hrpdb * 0