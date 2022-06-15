**Oracle11g RAC for Centos7.9 安装手册**

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
[root@oracle1 Packages]# cat /etc/redhat-release
CentOS Linux release 7.9.2009 (Core)
```
### 1.2. ASM 磁盘组规划
```
ASM 磁盘组 用途 大小 冗余
ocr、 voting file   20G+20G+20G NORMAL
DATA 数据文件 500G EXTERNAL
FRA    归档日志 300G EXTERNAL
```
### 1.3. 主机网络规划

#IP规划
```
网络配置               节点 1                               节点 2
主机名称               oracle1                             oracle2
public ip            210.46.97.93                       210.46.97.94
private ip           192.168.97.93                      192.168.97.94
vip                  210.46.97.96                       210.46.97.97
scan ip              210.46.97.98
```
#网卡配置
```bash
ifconfig
nmcli conn show
#发现虚拟机为克隆模式，两台服务器ens32的uuid相同，重新生成新的UUID
uuidgen ens32
#然后修改/etc/sysconfig/network-scripts/ifcfg-ens32中的UUID
#创建ens160，并修改相关内容
cp /etc/sysconfig/network-scripts/ifcfg-ens32  /etc/sysconfig/network-scripts/ifcfg-ens160

#重启网卡，没有报错的时候可以reboot下
systemctl restart network
```
#修改私有网卡的相关配置
#oracle1
```
[root@oracle1 network-scripts]# cat ifcfg-ens32
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens32
#UUID=c0a520bb-1a60-4e88-bda7-03781a44c22b
UUID=d27052e5-c774-4c86-a6df-5c21a7424c0c
DEVICE=ens32
ONBOOT=yes
IPADDR=210.46.97.93
NETMASK=255.255.255.0
GATEWAY=210.46.97.3
DNS1=210.46.97.1

[root@oracle1 network-scripts]# cat ifcfg-ens160
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
#注意私有IP的defroute为no
DEFROUTE=no
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens160
UUID=4dd5b952-2a74-34db-b642-7ea138d0a101
DEVICE=ens160
ONBOOT=yes
IPADDR=192.168.97.93
NETMASK=255.255.255.0
GATEWAY=192.168.97.3

[root@oracle1 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         210.46.97.3     0.0.0.0         UG    100    0        0 ens32
192.168.97.0    0.0.0.0         255.255.255.0   U     101    0        0 ens160
210.46.97.0     0.0.0.0         255.255.255.0   U     100    0        0 ens32

[root@oracle1 ~]# ip route
default via 210.46.97.3 dev ens32 proto static metric 100
192.168.97.0/24 dev ens160 proto kernel scope link src 192.168.97.93 metric 101
210.46.97.0/24 dev ens32 proto kernel scope link src 210.46.97.93 metric 100
[root@oracle1 ~]#

[root@oracle1 ~]# ifconfig
ens32: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 210.46.97.93  netmask 255.255.255.0  broadcast 210.46.97.255
        ether 00:50:56:98:0e:d1  txqueuelen 1000  (Ethernet)
        RX packets 332959  bytes 29632801 (28.2 MiB)
        RX errors 0  dropped 20  overruns 0  frame 0
        TX packets 7660  bytes 4715138 (4.4 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens160: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.97.93  netmask 255.255.255.0  broadcast 192.168.97.255
        ether 00:50:56:98:38:e9  txqueuelen 1000  (Ethernet)
        RX packets 327157  bytes 28741266 (27.4 MiB)
        RX errors 0  dropped 10  overruns 0  frame 0
        TX packets 422  bytes 80208 (78.3 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 770  bytes 143362 (140.0 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 770  bytes 143362 (140.0 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@oracle1 ~]# cat /etc/resolv.conf
# Generated by NetworkManager
nameserver 210.46.97.1
```

#oracle2
```
[root@oracle2 ~]# cd /etc/sysconfig/network-scripts/
[root@oracle2 network-scripts]# cat ifcfg-ens32
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens32
#UUID=c0a520bb-1a60-4e88-bda7-03781a44c22b
UUID=c5b7477d-1162-443a-8b99-579ac8c27d29
DEVICE=ens32
ONBOOT=yes
IPADDR=210.46.97.94
NETMASK=255.255.255.0
GATEWAY=210.46.97.3
DNS1=210.46.97.1
[root@oracle2 network-scripts]# cat ifcfg-ens160
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
#注意私有IP的defroute为no
DEFROUTE=no
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens160
UUID=72a36720-cde5-3b0a-86bd-bc6080988a3c
DEVICE=ens160
ONBOOT=yes
IPADDR=192.168.97.94
NETMASK=255.255.255.0
GATEWAY=192.168.97.3

[root@oracle2 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         210.46.97.3     0.0.0.0         UG    100    0        0 ens32
192.168.97.0    0.0.0.0         255.255.255.0   U     101    0        0 ens160
210.46.97.0     0.0.0.0         255.255.255.0   U     100    0        0 ens32

[root@oracle2 ~]# ip route
default via 210.46.97.3 dev ens32 proto static metric 100
192.168.97.0/24 dev ens160 proto kernel scope link src 192.168.97.94 metric 101
210.46.97.0/24 dev ens32 proto kernel scope link src 210.46.97.94 metric 100

[root@oracle2 ~]# ifconfig
ens32: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 210.46.97.94  netmask 255.255.255.0  broadcast 210.46.97.255
        ether 00:50:56:98:15:1f  txqueuelen 1000  (Ethernet)
        RX packets 325711  bytes 31433578 (29.9 MiB)
        RX errors 0  dropped 10  overruns 0  frame 0
        TX packets 5078  bytes 912560 (891.1 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens160: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.97.94  netmask 255.255.255.0  broadcast 192.168.97.255
        ether 00:50:56:98:33:d8  txqueuelen 1000  (Ethernet)
        RX packets 319302  bytes 28055943 (26.7 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 421  bytes 80132 (78.2 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 635  bytes 118268 (115.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 635  bytes 118268 (115.4 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        
[root@oracle1 ~]# cat /etc/resolv.conf
# Generated by NetworkManager
nameserver 210.46.97.1
```

### 1.4. 操作系统配置部分

#关闭防火墙
```bash
systemctl stop firewalld
systemctl disabled firewalld
```
#关闭 selinux
```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0
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

passwd oracle
passwd grid
```
### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#oracle1
hostnamectl set-hostname oracle1
#oracle2
hostnamectl set-hostname oracle2

cat >> /etc/hosts <<EOF
#public ip ens32
210.46.97.93 oracle1
210.46.97.94 oracle2
#vip
210.46.97.96 oracle1-vip
210.46.97.97 oracle2-vip
#private ip ens160
192.168.97.93 oracle1-prv
192.168.97.94 oracle2-prv
#scan ip
210.46.97.98 rac-scan

EOF
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
#查看是否中国时区
date -R 

#设置中国时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#方法二
timedatectl list-timezones |grep Shanghai #查找中国时区的完整名称
--->Asia/Shanghai
timedatectl set-timezone Asia/Shanghai
```
### 2.6. 创建所需要目录

```bash
mkdir -p /u01/app/11.2.0/grid
mkdir -p /u01/app/grid
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oracle/product/11.2.0/db_1
mkdir -p /u01/Storage

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

EOF

```
#关闭THP，检查是否开启
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```
--->[always] madvise never
#若以上命令执行结果显示为“always”，则表示开启了THP

##修改方法一，必须知道引导是BIOS还是EFI
则修改/etc/default/grub，在RUB_CMDLINE_LINUX中添加transparent_hugepage=never

#内容如下
```
GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet transparent_hugepage=never numa=off"
```
#执行如下命令，重新生成grub.cfg配置文件

#On BIOS-based machines
```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
```
#On UEFI-based machines
```bash
grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
```
重启节点后，检查配置是否正常：
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```
```
--->always madvise [never]
```
##方法二
#修改/etc/rc.local，并重启OS
```bash
cat >> /etc/d/rc.local <<EOF
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

EOF

chmod +x /etc/rc.d/rc.local 

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
kernel.shmall = 3774873
#memory*90%
kernel.shmmax = 15461882265
kernel.shmmni = 4096
kernel.sem = 6144 50331648 4096 8192
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 4194304
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

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
[root@oracle1 ~]# sfdisk -s
/dev/sdc:  20971520
/dev/sde: 524288000
/dev/sda: 524288000
/dev/sdf: 314572800
/dev/sdb:  20971520
/dev/sdd:  20971520
/dev/mapper/centos-root: 456126464
/dev/mapper/centos-swap:  67108864
total: 1949298688 blocks

[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
36000c29cab9f05183d3af0fc44e8022f
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
36000c29aa1f89b4a2054f787a381ec5f
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
36000c293eb6bd488a57530ba68d59381
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
36000c29e32ff47627698b21515cc5682
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
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
systemctl status systemd-udev-trigger.service
```
#检查asm磁盘
```bash
ll /dev|grep asm
```
#显示如下
```
[root@oracle1 ~]# ll /dev|grep asm
brw-rw----  1 grid asmadmin   8,  16 Dec 21 16:25 sdb
brw-rw----  1 grid asmadmin   8,  32 Dec 21 16:25 sdc
brw-rw----  1 grid asmadmin   8,  48 Dec 21 16:25 sdd
brw-rw----  1 grid asmadmin   8,  64 Dec 21 16:25 sde
brw-rw----  1 grid asmadmin   8,  80 Dec 21 16:25 sdf
```
#知识补充：/usr/lib/systemd/system/systemd-udev-trigger.service
```
[root@oracle1 ~]# cat /usr/lib/systemd/system/systemd-udev-trigger.service
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

[Unit]
Description=udev Coldplug all Devices
Documentation=man:udev(7) man:systemd-udevd.service(8)
DefaultDependencies=no
Wants=systemd-udevd.service
After=systemd-udevd-kernel.socket systemd-udevd-control.socket systemd-hwdb-update.service
Before=sysinit.target
ConditionPathIsReadWrite=/sys

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/udevadm trigger --type=subsystems --action=add ; /usr/bin/udevadm trigger --type=devices --action=add
[root@oracle1 ~]# cat /usr/lib/systemd/system/systemd-udevd.service
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

[Unit]
Description=udev Kernel Device Manager
Documentation=man:systemd-udevd.service(8) man:udev(7)
DefaultDependencies=no
Wants=systemd-udevd-control.socket systemd-udevd-kernel.socket
After=systemd-udevd-control.socket systemd-udevd-kernel.socket systemd-sysusers.service
Before=sysinit.target
ConditionPathIsReadWrite=/sys

[Service]
Type=notify
OOMScoreAdjust=-1000
Sockets=systemd-udevd-control.socket systemd-udevd-kernel.socket
Restart=always
RestartSec=0
ExecStart=/usr/lib/systemd/systemd-udevd
KillMode=mixed
[root@oracle1 ~]#
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
[root@oracle1 ~]# sfdisk -s
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

[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdae
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaf
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdag
26f1134c7f5aeac0d6c9ce900b6fab6bc
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

### 2.11. 安装vnc

#服务器远程操作，安装vnc，便于图形安装

#安装图形化组件并重启
```bash
yum grouplist
yum groupinstall -y "Server with GUI"

reboot
```
#安装vnc并编辑设置
```bash
yum -y install vnc *vnc-server*

cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@.service

vi /etc/sysconfig/vncservers
#填入以下内容
VNCSERVERS="1:grid"
VNCSERVERS="2:oracle"
VNCSERVERARGS[1]="-geometry 800x600 -nolisten tcp -localhost -alwaysshared -depth 24"
```
#进入grid测试
```bash
su - grid
vncserver
--->password:vncserver
```
#此时windows打开vnc客户端连接grid用户界面：
```
oracleserverIP:1
```
#进入oracle测试
```bash
su - oracle
vncserver
--->password:vncserver
```
#此时windows打开vnc客户端连接oracle用户界面：
```
oracleserverIP:2
```
#显示如下
```
[root@oracle1 ~]# yum grouplist
Loaded plugins: fastestmirror
There is no installed groups file.
Maybe run: yum groups mark convert (see man yum)
Loading mirror speeds from cached hostfile
 * base: mirrors.neusoft.edu.cn
 * extras: mirrors.neusoft.edu.cn
 * updates: mirrors.neusoft.edu.cn
Available Environment Groups:
   Minimal Install
   Compute Node
   Infrastructure Server
   File and Print Server
   Basic Web Server
   Virtualization Host
   Server with GUI
   GNOME Desktop
   KDE Plasma Workspaces
   Development and Creative Workstation
Available Groups:
   Compatibility Libraries
   Console Internet Tools
   Development Tools
   Graphical Administration Tools
   Legacy UNIX Compatibility
   Scientific Support
   Security Tools
   Smart Card Support
   System Administration Tools
   System Management
Done
[root@oracle1 ~]#

[root@oracle1 ~]# ps -ef|grep vnc
grid      2998     1  0 14:23 pts/0    00:00:00 /bin/Xvnc :1 -auth /home/grid/.Xauthority -desktop oracle1:1 (grid) -fp catalogue:/etc/X11/fontpath.d -geometry 1024x768 -httpd /usr/share/vnc/classes -pn -rfbauth /home/grid/.vnc/passwd -rfbport 5901 -rfbwait 30000
grid      3017     1  0 14:23 pts/0    00:00:00 /bin/sh /home/grid/.vnc/xstartup
root      4508  2099  0 14:26 pts/0    00:00:00 grep --color=auto vnc

```

## 3 开始安装 GI

### 3.1. 上传oracle rac软件安装包并解压缩

#将软件包上传至oracle1的/u01/Storage目录下
```bash
#解压缩
su - root
cd /u01/Storage
#按顺序解压缩
unzip p13390677_112040_Linux-x86-64_1of7.zip

unzip p13390677_112040_Linux-x86-64_2of7.zip

unzip p13390677_112040_Linux-x86-64_3of7.zip

#设置权限
chown -R grid:oinstall /u01/Storage
```
#### 3.2. 安装 cvuqdisk并做安装前检查

#安装cvuqdisk
```bash
#oracle1下执行
su - grid

cd /u01/Storage/grid/rpm
cp cvuqdisk-1.0.9-1.rpm /u01

scp cvuqdisk-1.0.9-1.rpm oracle2:/u01

#oracle1/oracle2都要执行
su - root

cd /u01
rpm -ivh cvuqdisk-1.0.9-1.rpm
```
#安装前检查，只在oracle1上执行
```bash
su - grid

cd /u01/Storage/grid/
./runcluvfy.sh stage -pre crsinst -n oracle1,oracle2 -fixup -verbose|tee -a pre.log
```
#会生成fixup脚本，需在oracle1/oracle2上执行
#如果报错以下，可以忽略
```
Check: Package existence for "pdksh" 
  Node Name     Available                 Required                  Status    
  ------------  ------------------------  ------------------------  ----------
  oracle2       missing                   pdksh-5.2.14              failed    
  oracle1       missing                   pdksh-5.2.14              failed    
Result: Package existence check failed for "pdksh"
```
#如果报错以下内容必须处理
```
Checking Core file name pattern consistency...

ERROR:
PRVF-6402 : Core file name pattern is not same on all the nodes.
Found core filename pattern "|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h" on nodes "oracle1".
Found core filename pattern "core.%p" on nodes "oracle2".
Core file name pattern consistency check failed.
```
#解决办法，可以将node1的abrt-hook-ccpp关闭
#查看core_pattern
```bash
[root@oracle1 ~]# more /proc/sys/kernel/core_pattern
|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h
[root@oracle1 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; enabled; vendor preset: enabled)
   Active: active (exited) since Wed 2021-11-03 10:58:38 CST; 1 months 18 days ago
  Process: 806 ExecStart=/usr/sbin/abrt-install-ccpp-hook install (code=exited, status=0/SUCCESS)
 Main PID: 806 (code=exited, status=0/SUCCESS)
    Tasks: 0
   CGroup: /system.slice/abrt-ccpp.service
Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.


[root@oracle2 ~]# more /proc/sys/kernel/core_pattern
core
[root@oracle2 ~]# systemctl status abrt-ccpp.service
Unit abrt-ccpp.service could not be found.
```
#oracle1关闭abrt-ccpp
```bash
systemctl stop abrt-ccpp.service
systemctl disable abrt-ccpp.service
systemctl status abrt-ccpp.service
```
#此时再次runcluvfy即可通过
```
[root@oracle1 ~]# systemctl stop abrt-ccpp.service
[root@oracle1 ~]# systemctl disable abrt-ccpp.service
Removed symlink /etc/systemd/system/multi-user.target.wants/abrt-ccpp.service.
[root@oracle1 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; disabled; vendor preset: enabled)
   Active: inactive (dead)

Dec 22 14:06:03 oracle1 systemd[1]: Starting Install ABRT coredump hook...
Dec 22 14:06:03 oracle1 systemd[1]: Started Install ABRT coredump hook.
Dec 22 14:47:32 oracle1 systemd[1]: Stopping Install ABRT coredump hook...
Dec 22 14:47:32 oracle1 systemd[1]: Stopped Install ABRT coredump hook.
[root@oracle1 ~]# more /proc/sys/kernel/core_pattern
core

runcluvfy.sh:
Checking Core file name pattern consistency...
Core file name pattern consistency check passed.
```
#### 3.3. 开始安装GI

#VNC连接grid账户，开始安装

```bash
cd /u01/Storage/grid/
./runInstaller
```
#安装步骤，截图见安装过程截图文档

```
--->skip software updates
--->Install and Configure Oracle Grid Infrastructure for a Cluster
--->Advanced installation
--->English/Simplified Chinese
--->cluster name:rac-scan/scan name:rac-cluster/scan port:1521,去掉configure GNS前面的勾
--->add:oracle2/oracle2-vip,SSHconnectivity,test
--->ens160:192.168.97.0:private,ens32:210.46.97.0:public,virbr0:192.168.122.0:Do Not Use
--->oracle ASM
DiskGroupName:OCR,normal,AUSize:1M,Candidate Disks:sdb/sdc/sdd--->
--->use same passwords for these accounts:Ora543Cle---Do Not Use IPMI
--->asmadmin/asmdba/asmoper
--->Oracle Base:/u01/app/grid,Oracle_Home:/u01/app/11.2.0/grid
--->Inventory Directory:/u01/app/oraInventory
--->缺少pdksh,可以忽略
--->install
--->/u01/app/oraInventory/orainstRoot.sh,/u01/app/11.2.0/grid/root.sh，必须先在oracle1上执行完毕这两个脚本，再在oracle2上执行，出现错误时见下面的错误处理步骤，如果弹框看不到内容，可以用鼠标拖动
---->INS-20802，忽略，如果弹框看不到内容，也无法用鼠标拖动，可以按4次Tab键后回车即可
---->INS-32091，忽略，如果弹框看不到内容，也无法用鼠标拖动，可以按4次Tab键后回车即可
---->close
```
#错误处理
##执行root.sh时报错缺少libcap.so.1
```
Installing Trace File Analyzer
Failed to create keys in the OLR, rc = 127, Message:
  /u01/app/11.2.0/grid/bin/clscfg.bin: error while loading shared libraries: libcap.so.1: cannot open shared object file: No such file or directory

Failed to create keys in the OLR at /u01/app/11.2.0/grid/crs/install/crsconfig_lib.pm line 7660.
/u01/app/11.2.0/grid/perl/bin/perl -I/u01/app/11.2.0/grid/perl/lib -I/u01/app/11.2.0/grid/crs/install /u01/app/11.2.0/grid/crs/install/rootcrs.pl execution failed

```
#解决办法，oracle1/oracle2都执行
```bash
cd /lib64
ll|grep libcap
ln -s libcap.so.2.22 libcap.so.1
ll|grep libcap
```
#然后oracle1重新执行root.sh
```bash
/u01/app/11.2.0/grid/root.sh
```
##执行root.sh报错ohasd failed to start
```
ohasd failed to start
Failed to start the Clusterware. Last 20 lines of the alert log follow:
2021-12-22 16:16:16.536:
[client(23029)]CRS-2101:The OLR was formatted using version 3.
2021-12-22 16:26:16.232:
[client(24751)]CRS-2101:The OLR was formatted using version 3.
```
#因为Centos7使用systemd而不是initd来启动/重新启动进程，并将它们作为服务运行，所以当前的11.2.0.4和12.1.0.1的软件安装不会成功，因为ohasd进程没有正常启动

#解决办法
```
#手动在systemd中添加ohasd服务

touch /usr/lib/systemd/system/ohas.service

#编辑文件ohasd.service添加如下内容

vi   /usr/lib/systemd/system/ohas.service

[Unit]
Description=Oracle High Availability Services
After=syslog.target

[Service]
ExecStart=/etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple
Restart=always

[Install]
WantedBy=multi-user.target

 
#添加和启动服务

systemctl daemon-reload
systemctl enable ohas.service
systemctl start ohas.service

#查看运行状态：

[root@rac1 system]# systemctl status ohas.service
● ohas.service - Oracle High Availability Services
Loaded: loaded (/usr/lib/systemd/system/ohas.service; enabled; vendor preset: disabled)
Active: active (running) since Thu 2018-04-19 14:10:19 CST; 1h 16min ago
Main PID: 1210 (init.ohasd)
CGroup: /system.slice/ohasd.service
└─1210 /bin/sh /etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple

Apr 19 14:10:19 bms-75c8 systemd[1]: Started Oracle High Availability Services.
Apr 19 14:10:19 bms-75c8 systemd[1]: Starting Oracle High Availability Services...

#此时oracle1的root.sh会继续安装下去，无需重新执行root.sh脚本

#注意： 为了避免其余节点遇到这种报错，可以在root.sh执行过程中，待/etc/init.d/目录下生成了init.ohasd 文件后，执行systemctl start ohas.service 启动ohas服务即可。若没有/etc/init.d/init.ohasd文件 systemctl start ohas.service 则会启动失败。
```

#部署过程日志
```
[root@oracle1 ~]# cd /lib64
[root@oracle1 lib64]# ll|grep libcap
lrwxrwxrwx.  1 root root       18 Dec 10 14:11 libcap-ng.so.0 -> libcap-ng.so.0.0.0
-rwxr-xr-x.  1 root root    23968 Nov 20  2015 libcap-ng.so.0.0.0
lrwxrwxrwx.  1 root root       14 Dec 10 14:11 libcap.so.2 -> libcap.so.2.22
-rwxr-xr-x.  1 root root    20048 Apr  1  2020 libcap.so.2.22
[root@oracle1 lib64]# ln -s libcap.so.2.22 libcap.so.1
[root@oracle1 lib64]# ll|grep libcap
lrwxrwxrwx.  1 root root       18 Dec 10 14:11 libcap-ng.so.0 -> libcap-ng.so.0.0.0
-rwxr-xr-x.  1 root root    23968 Nov 20  2015 libcap-ng.so.0.0.0
lrwxrwxrwx   1 root root       14 Dec 22 16:20 libcap.so.1 -> libcap.so.2.22
lrwxrwxrwx.  1 root root       14 Dec 10 14:11 libcap.so.2 -> libcap.so.2.22
-rwxr-xr-x.  1 root root    20048 Apr  1  2020 libcap.so.2.22


[root@oracle2 ~]# cd /lib64
[root@oracle2 lib64]# ll|grep libcap
lrwxrwxrwx.  1 root root      18 Dec 10 14:11 libcap-ng.so.0 -> libcap-ng.so.0.0.0
-rwxr-xr-x.  1 root root   23968 Nov 20  2015 libcap-ng.so.0.0.0
lrwxrwxrwx.  1 root root      14 Dec 10 14:11 libcap.so.2 -> libcap.so.2.22
-rwxr-xr-x.  1 root root   20048 Apr  1  2020 libcap.so.2.22
[root@oracle2 lib64]# ln -s libcap.so.2.22 libcap.so.1
[root@oracle2 lib64]# ll|grep libcap
lrwxrwxrwx.  1 root root      18 Dec 10 14:11 libcap-ng.so.0 -> libcap-ng.so.0.0.0
-rwxr-xr-x.  1 root root   23968 Nov 20  2015 libcap-ng.so.0.0.0
lrwxrwxrwx   1 root root      14 Dec 22 16:22 libcap.so.1 -> libcap.so.2.22
lrwxrwxrwx.  1 root root      14 Dec 10 14:11 libcap.so.2 -> libcap.so.2.22
-rwxr-xr-x.  1 root root   20048 Apr  1  2020 libcap.so.2.22

[root@oracle1 ~]# /u01/app/11.2.0/grid/root.sh
Performing root user operation for Oracle 11g

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/app/11.2.0/grid

Enter the full pathname of the local bin directory: [/usr/local/bin]:
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Using configuration parameter file: /u01/app/11.2.0/grid/crs/install/crsconfig_params
User ignored Prerequisites during installation
Installing Trace File Analyzer
OLR initialization - successful
  root wallet
  root wallet cert
  root cert export
  peer wallet
  profile reader wallet
  pa wallet
  peer wallet keys
  pa wallet keys
  peer cert request
  pa cert request
  peer cert
  pa cert
  peer root cert TP
  profile reader root cert TP
  pa root cert TP
  peer pa cert TP
  pa peer cert TP
  profile reader pa cert TP
  profile reader peer cert TP
  peer user cert
  pa user cert
Adding Clusterware entries to inittab

ohasd failed to start
Failed to start the Clusterware. Last 20 lines of the alert log follow:
2021-12-22 16:16:16.536:
[client(23029)]CRS-2101:The OLR was formatted using version 3.
2021-12-22 16:26:16.232:
[client(24751)]CRS-2101:The OLR was formatted using version 3.

CRS-2672: Attempting to start 'ora.mdnsd' on 'oracle1'
CRS-2676: Start of 'ora.mdnsd' on 'oracle1' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'oracle1'
CRS-2676: Start of 'ora.gpnpd' on 'oracle1' succeeded
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'oracle1'
CRS-2672: Attempting to start 'ora.gipcd' on 'oracle1'
CRS-2676: Start of 'ora.cssdmonitor' on 'oracle1' succeeded
CRS-2676: Start of 'ora.gipcd' on 'oracle1' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'oracle1'
CRS-2672: Attempting to start 'ora.diskmon' on 'oracle1'
CRS-2676: Start of 'ora.diskmon' on 'oracle1' succeeded
CRS-2676: Start of 'ora.cssd' on 'oracle1' succeeded

ASM created and started successfully.

Disk Group ORC created successfully.

clscfg: -install mode specified
Successfully accumulated necessary OCR keys.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
CRS-4256: Updating the profile
Successful addition of voting disk ab7ca7ea5aa34f62bfc562f2ad83cda1.
Successful addition of voting disk 6a09805cd4c94f87bf712ba5181b9941.
Successful addition of voting disk 90fb8bac64a84f19bf4599e793a7de08.
Successfully replaced voting disk group with +ORC.
CRS-4256: Updating the profile
CRS-4266: Voting file(s) successfully replaced
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   ab7ca7ea5aa34f62bfc562f2ad83cda1 (/dev/sdb) [ORC]
 2. ONLINE   6a09805cd4c94f87bf712ba5181b9941 (/dev/sdc) [ORC]
 3. ONLINE   90fb8bac64a84f19bf4599e793a7de08 (/dev/sdd) [ORC]
Located 3 voting disk(s).
CRS-2672: Attempting to start 'ora.asm' on 'oracle1'
CRS-2676: Start of 'ora.asm' on 'oracle1' succeeded
CRS-2672: Attempting to start 'ora.ORC.dg' on 'oracle1'
CRS-2676: Start of 'ora.ORC.dg' on 'oracle1' succeeded
Configure Oracle Grid Infrastructure for a Cluster ... succeeded

[root@oracle1 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.ORC.dg
               ONLINE  ONLINE       oracle1
ora.asm
               ONLINE  ONLINE       oracle1                  Started
ora.gsd
               OFFLINE OFFLINE      oracle1
ora.net1.network
               ONLINE  ONLINE       oracle1
ora.ons
               ONLINE  ONLINE       oracle1
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle1
ora.cvu
      1        ONLINE  ONLINE       oracle1
ora.oc4j
      1        ONLINE  ONLINE       oracle1
ora.oracle1.vip
      1        ONLINE  ONLINE       oracle1
ora.scan1.vip
      1        ONLINE  ONLINE       oracle1

[root@oracle2 ~]# /u01/app/oraInventory/orainstRoot.sh

[root@oracle2 ~]# /u01/app/11.2.0/grid/root.sh

[root@oracle2 ~]# cd /etc/init.d
[root@oracle2 init.d]# ls
functions  netconsole  network  README

[root@oracle2 init.d]# ls
functions  init.ohasd  netconsole  network  ohasd  README

[root@oracle2 init.d]# systemctl start ohas

[root@oracle2 init.d]# /u01/app/11.2.0/grid/root.sh
Performing root user operation for Oracle 11g

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/app/11.2.0/grid

Enter the full pathname of the local bin directory: [/usr/local/bin]:
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Using configuration parameter file: /u01/app/11.2.0/grid/crs/install/crsconfig_params
Creating trace directory
User ignored Prerequisites during installation
Installing Trace File Analyzer
OLR initialization - successful
Adding Clusterware entries to inittab
CRS-4402: The CSS daemon was started in exclusive mode but found an active CSS daemon on node oracle1, number 1, and is terminating
An active cluster was found during exclusive startup, restarting to join the cluster
Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```

### 3.5. 查看状态

```bash
crsctl status resource -t
```
```
[root@oracle2 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.ORC.dg
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.asm
               ONLINE  ONLINE       oracle1                  Started
               ONLINE  ONLINE       oracle2                  Started
ora.gsd
               OFFLINE OFFLINE      oracle1
               OFFLINE OFFLINE      oracle2
ora.net1.network
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.ons
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle1
ora.cvu
      1        ONLINE  ONLINE       oracle1
ora.oc4j
      1        ONLINE  ONLINE       oracle1
ora.oracle1.vip
      1        ONLINE  ONLINE       oracle1
ora.oracle2.vip
      1        ONLINE  ONLINE       oracle2
ora.scan1.vip
      1        ONLINE  ONLINE       oracle1

```
## 4 创建ASM磁盘组：DATA/FRA

#grid用户图形界面下
```bash
asmca
```
```
 --->create
 --->DATA,external,sde,OK，如果弹框看不到磁盘选择项，可以用鼠标拖动
 --->creat
 --->FRA,external,sdf,OK，如果弹框看不到磁盘选择项，可以用鼠标拖动
 --->exit
```
#验证
```
[grid@oracle1 ~]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576    512000   511901                0          511901              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576    307200   307103                0          307103              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576     61440    60514            20480           20017              0             Y  ORC/
ASMCMD> lsdsk
Path
/dev/sdb
/dev/sdc
/dev/sdd
/dev/sde
/dev/sdf
ASMCMD>
[grid@oracle1 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.FRA.dg
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.LISTENER.lsnr
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.ORC.dg
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.asm
               ONLINE  ONLINE       oracle1                  Started
               ONLINE  ONLINE       oracle2                  Started
ora.gsd
               OFFLINE OFFLINE      oracle1
               OFFLINE OFFLINE      oracle2
ora.net1.network
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.ons
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle1
ora.cvu
      1        ONLINE  ONLINE       oracle1
ora.oc4j
      1        ONLINE  ONLINE       oracle1
ora.oracle1.vip
      1        ONLINE  ONLINE       oracle1
ora.oracle2.vip
      1        ONLINE  ONLINE       oracle2
ora.scan1.vip
      1        ONLINE  ONLINE       oracle1
[root@oracle1 ~]#

```
## 5 安装oracle软件

#将目录/u01/Storage/database赋权给oracle
```bash
su - root

chown -R oracle:oinstall /u01/Storage/database
```
#安装前检查
```bash
su - grid

cd /u01/Storage/grid
  ./runcluvfy.sh stage -pre dbinst -n oracle1,oracle2 -fixup -verbose |tee -a pre1.log
```
#如果下面报错内容，可以忽略
```
Check: Package existence for "pdksh"
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  oracle2       missing                   pdksh-5.2.14              failed
  oracle1       missing                   pdksh-5.2.14              failed
Result: Package existence check failed for "pdksh"


ERROR:
PRVG-1101 : SCAN name "rac-scan" failed to resolve
  SCAN Name     IP Address                Status                    Comment
  ------------  ------------------------  ------------------------  ----------
  rac-scan      210.46.97.98              failed                    NIS Entry

ERROR:
PRVF-4657 : Name resolution setup check for "rac-scan" (IP address: 210.46.97.98) failed

ERROR:
PRVF-4664 : Found inconsistent name resolution entries for SCAN name "rac-scan"

Verification of SCAN VIP and Listener setup failed

```
#通过vnc以 Oracle 用户登录图形化界面安装 Oracle 数据库软件
```
#根据前面vnc的配置，连接地址
oracle1IP:2
```
#开始安装
```bash
cd /u01/Storage/database
./runInstaller
```
#安装过程
```
--->去掉I wish前面的打勾
    --->弹框：Yes
--->Skip software updates
--->Install database software only
--->Orace Real Application Clusters database installation
    --->Select All
    --->SSH Connectivity
    --->Test
--->English/Simplified Chinese
--->Enterprise Edition
--->Oracle Base: /u01/app/oracle
    --->Software Location: /u01/app/oracle/product/11.2.0/db_1
--->dba/oper
--->pdksh/scan: Ignore All
--->Install
--->'agent nmhs' error处理,见下面错误处理步骤
    --->Retry
--->/u01/app/oracle/product/11.2.0/db_1/root.sh，分别在oracle1/oracle2上用root账户运行，如果弹框看不到内容，可以用鼠标拖动
--->Close
```
#安装过程中错误处理
```
Exception String: Error in invoking target 'agent nmhs' of makefile '/u01/app/oracle/product/11.2.0/db_1/sysman/lib/ins_emagent.mk'. See '/u01/app/oraInventory/logs/installActions2021-12-22_06-58-16PM.log' for details.
```
#解决办法
```
vi /u01/app/oracle/product/11.2.0/db_1/sysman/lib/ins_emagent.mk
 
找到 $(MK_EMAGENT_NMECTL) 这一行，在后面添加 -lnnz11 如下：
 
$(MK_EMAGENT_NMECTL) -lnnz11
然后点击retry 即可
#如果弹框看不到内容，也无法用鼠标拖动，可以在处理完错误后按4次Tab键后回车即可
```
#执行 root 脚本日志
```
[root@oracle1 ~]# /u01/app/oracle/product/11.2.0/db_1/root.sh
Performing root user operation for Oracle 11g

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/11.2.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]:
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Finished product-specific root actions.

[root@oracle2 ohasd]# /u01/app/oracle/product/11.2.0/db_1/root.sh
Performing root user operation for Oracle 11g

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/11.2.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]:
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Finished product-specific root actions.
```
## 6 建立数据库实例

#通过vnc以 Oracle 用户登录图形化界面安装 

#执行建库 dbca
```bash
dbca
```
#安装过程，截图见另一份截图文档
```
--->Oracle RAC database
--->Create a Database
--->General Purpose
--->Admin-Managed/xydb/xydb/Select All
--->Configure Enterprise Manager
--->SYS/SYSTEM/DBSNMP/SYSMAN使用一个密码: XXXXXX
--->ASM/+DATA
    --->弹框中输入ASMSNMP的密码(此弹框可能需要鼠标拖开，密码为GI时设置的密码)
--->Specify FRA: +FRA/300000M(大小根据实际情况填写)/Enable Arechiving
--->Sample Schemas，可以去掉打勾
--->Memory: Custom---SGA:6000M/PGA:2000M(大小根据实际设置memory*60%左右)
    --->Sizing: Processes---1500(根据服务器资源调整)
    --->CharacterSets: Use Unicode(AL32UTF8)
    --->Connection Mode: Dedicated Server Mode
    --->All Initialization Parameters: 可以修改Redo Log Groups，再添加两组，并调整大小为200M
--->Finish
--->OK，此处弹框可能需要鼠标拖开
--->等待执行完毕，点击Exit
```

## 7 检查修改部分数据库配置参数

### 7.1.密码过期时间

```bash
su - oracle
sqlplus / as sysdba
```
```oracle
select resource_name,limit from dba_profiles where profile='DEFAULT';

alter profile default limit password_life_time unlimited;
```
#日志
```
SQL> select resource_name,limit from dba_profiles where profile='DEFAULT';

RESOURCE_NAME                    LIMIT
-------------------------------- ----------------------------------------
COMPOSITE_LIMIT                  UNLIMITED
SESSIONS_PER_USER                UNLIMITED
CPU_PER_SESSION                  UNLIMITED
CPU_PER_CALL                     UNLIMITED
LOGICAL_READS_PER_SESSION        UNLIMITED
LOGICAL_READS_PER_CALL           UNLIMITED
IDLE_TIME                        UNLIMITED
CONNECT_TIME                     UNLIMITED
PRIVATE_SGA                      UNLIMITED
FAILED_LOGIN_ATTEMPTS            10
PASSWORD_LIFE_TIME               180
PASSWORD_REUSE_TIME              UNLIMITED
PASSWORD_REUSE_MAX               UNLIMITED
PASSWORD_VERIFY_FUNCTION         NULL
PASSWORD_LOCK_TIME               1
PASSWORD_GRACE_TIME              7

16 rows selected.

SQL>

SQL> alter profile default limit password_life_time unlimited;

Profile altered.

SQL> select resource_name,limit from dba_profiles where profile='DEFAULT';

RESOURCE_NAME                    LIMIT
-------------------------------- ----------------------------------------
COMPOSITE_LIMIT                  UNLIMITED
SESSIONS_PER_USER                UNLIMITED
CPU_PER_SESSION                  UNLIMITED
CPU_PER_CALL                     UNLIMITED
LOGICAL_READS_PER_SESSION        UNLIMITED
LOGICAL_READS_PER_CALL           UNLIMITED
IDLE_TIME                        UNLIMITED
CONNECT_TIME                     UNLIMITED
PRIVATE_SGA                      UNLIMITED
FAILED_LOGIN_ATTEMPTS            10
PASSWORD_LIFE_TIME               UNLIMITED

RESOURCE_NAME                    LIMIT
-------------------------------- ----------------------------------------
PASSWORD_REUSE_TIME              UNLIMITED
PASSWORD_REUSE_MAX               UNLIMITED
PASSWORD_VERIFY_FUNCTION         NULL
PASSWORD_LOCK_TIME               1
PASSWORD_GRACE_TIME              7

16 rows selected.

```
### 7.2.归档、redo、undo、datafile等检查

```oracle
archive log list;
show parameter recovery;
select * from v$recovery_area_usage;

select group#,thread#,sequence#,bytes/1024/1024 MB,members,archived,status from v$log;

select group#,type,member from v$logfile order by 1;

show parameter undo;

select tablespace_name, file_name,bytes/1024/1024 MB from dba_data_files order by 1;
```
#日志
```
SQL> archive log list;
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     1
Next log sequence to archive   2
Current log sequence           2
SQL>
SQL> show parameter recovery;

NAME                                 TYPE        VALUE
------------------------------------ ----------- -----------------------
db_recovery_file_dest                string      +FRA
db_recovery_file_dest_size           big integer 300000M
recovery_parallelism                 integer     0
SQL>  select * from v$recovery_area_usage;

FILE_TYPE            PERCENT_SPACE_USED PERCENT_SPACE_RECLAIMABLE NUMBER_OF_FILES
-------------------- ------------------ ------------------------- ------    ------
CONTROL FILE                        .01                         0               1
REDO LOG                             .4                         0               6
ARCHIVED LOG                          0                         0               1
BACKUP PIECE                          0                         0               0
IMAGE COPY                            0                         0               0
FLASHBACK LOG                         0                         0               0
FOREIGN ARCHIVED LOG                  0                         0               0

7 rows selected.

SQL>
SQL>  select group#,thread#,sequence#,bytes/1024/1024 MB,members,archived,status from v$log;

    GROUP#    THREAD#  SEQUENCE#         MB    MEMBERS ARC STATUS
---------- ---------- ---------- ---------- ---------- --- -------------
         1          1          1        200          2 YES INACTIVE
         2          1          2        200          2 NO  CURRENT
         3          2          1        200          2 YES INACTIVE
         4          2          2        200          2 NO  CURRENT
         5          1          0        200          2 YES UNUSED
         6          2          0        200          2 YES UNUSED

6 rows selected.

SQL>
SQL> select group#,type,member from v$logfile order by 1;

    GROUP# TYPE    MEMBER
---------- ------- --------------------------------------------------
         1 ONLINE  +FRA/xydb/onlinelog/group_1.257.1092061839
         1 ONLINE  +DATA/xydb/onlinelog/group_1.261.1092061839
         2 ONLINE  +DATA/xydb/onlinelog/group_2.262.1092061841
         2 ONLINE  +FRA/xydb/onlinelog/group_2.258.1092061841
         3 ONLINE  +DATA/xydb/onlinelog/group_3.267.1092062193
         3 ONLINE  +FRA/xydb/onlinelog/group_3.260.1092062195
         4 ONLINE  +DATA/xydb/onlinelog/group_4.268.1092062195
         4 ONLINE  +FRA/xydb/onlinelog/group_4.261.1092062195
         5 ONLINE  +DATA/xydb/onlinelog/group_5.263.1092061841
         5 ONLINE  +FRA/xydb/onlinelog/group_5.259.1092061841
         6 ONLINE  +FRA/xydb/onlinelog/group_6.262.1092062195
         6 ONLINE  +DATA/xydb/onlinelog/group_6.269.1092062195

12 rows selected.

SQL>
SQL> show parameter undo;

NAME                                 TYPE        VALUE
------------------------------------ ----------- -----------------------
undo_management                      string      AUTO
undo_retention                       integer     900
undo_tablespace                      string      UNDOTBS2
SQL>

SQL> select tablespace_name, file_name,bytes/1024/1024 MB from dba_data_files order by 1;

TABLESPACE_NAME                FILE_NAME                                                  MB
------------------------------ -------------------------------------------------- ----------
EXAMPLE                        +DATA/xydb/datafile/example.265.1092061851            313.125
SYSAUX                         +DATA/xydb/datafile/sysaux.257.1092061679                 550
SYSTEM                         +DATA/xydb/datafile/system.256.1092061679                 750
UNDOTBS1                       +DATA/xydb/datafile/undotbs1.258.1092061681               115
UNDOTBS2                       +DATA/xydb/datafile/undotbs2.266.1092062083                25
USERS                          +DATA/xydb/datafile/users.259.1092061681                    5

6 rows selected.

```
### 7.3.查看集群状态

#oracle1服务器执行
```bash
su - grid
#集群状态
crsctl status resource -t
#设置集群自动启动
crsctl enable crs
#asm
srvctl status asm

asmcmd
lsdg
#数据库
srvctl status database -d xydb
#监听
lsnrctl status
#外部连接数据库
sqlplus test/test@scanIP:1521/xydb
#比如
sqlplus test/test@210.46.97.98:1521/xydb
```
#日志
```
[root@oracle1 ~]# su - grid
Last login: Wed Dec 22 18:49:00 CST 2021 on pts/1
[grid@oracle1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.FRA.dg
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.LISTENER.lsnr
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.ORC.dg
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.asm
               ONLINE  ONLINE       oracle1                  Started
               ONLINE  ONLINE       oracle2                  Started
ora.gsd
               OFFLINE OFFLINE      oracle1
               OFFLINE OFFLINE      oracle2
ora.net1.network
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
ora.ons
               ONLINE  ONLINE       oracle1
               ONLINE  ONLINE       oracle2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle1
ora.cvu
      1        ONLINE  ONLINE       oracle1
ora.oc4j
      1        ONLINE  ONLINE       oracle1
ora.oracle1.vip
      1        ONLINE  ONLINE       oracle1
ora.oracle2.vip
      1        ONLINE  ONLINE       oracle2
ora.scan1.vip
      1        ONLINE  ONLINE       oracle1
ora.xydb.db
      1        ONLINE  ONLINE       oracle1                  Open
      2        ONLINE  ONLINE       oracle2                  Open
[grid@oracle1 ~]$ srvctl status asm
ASM is running on oracle1,oracle2
[grid@oracle1 ~]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576    512000   507820                0          507820              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576    307200   305730                0          305730              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576     61440    60514            20480           20017              0             Y  ORC/
ASMCMD>

[grid@oracle1 ~]$ srvctl status database -d xydb
Instance xydb1 is running on node oracle1
Instance xydb2 is running on node oracle2
[grid@oracle1 ~]$ lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 23-DEC-2021 16:17:15

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 11.2.0.4.0 - Production
Start Date                22-DEC-2021 17:14:46
Uptime                    0 days 23 hr. 2 min. 28 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/11.2.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/oracle1/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=210.46.97.93)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=210.46.97.96)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully

```

### 7.4.创建表空间、用户、表等测试

```oracle
create tablespace test datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace test add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user test identified by test default tablespace test;
grant connect,resource to test;

conn test/test

create table test1(id number,name varchar2(20));
insert into test1 values(1,'JACKY');
commit;
select * from test1;

```
#日志
```
SQL> create tablespace test datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

Tablespace created.

SQL> create user test identified by test default tablespace test;

User created.
SQL> grant connect,resource to test;

Grant succeeded.

SQL> conn test/test;
Connected.
SQL> create table test1(id number,name varchar2(20));

Table created.

SQL> insert into test1 values(1,'JACKY');

1 row created.

SQL> commit;

Commit complete.

SQL> select * from test1;

        ID NAME
---------- --------------------
         1 JACKY

SQL>

```
## 8 备份

### 8.1.rman备份

#根据磁盘的实际大小，建立备份目录
```bash
su - oracle

mkdir /home/oracle/backup
touch /home/oracle/backup/rmanrun.log
touch /home/oracle/backup/rmanbak.sh
chmod a+x /home/oracle/backup/rman
```

#rman全库备份脚本
```bash
vi /home/oracle/backup/rmanbak.sh
```
#填入以下内容
```
#!/bin/bash

time=$(date +"%Y%m%d")
rman_dir=/home/oracle/backup

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
   sql 'alter system archive log current';
   backup as compressed backupset database plus archivelog delete all input;
   sql 'alter system archive log current';
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

#设置调度任务
```bash
crontab -e

#每天0:30开始执行
30 0 * * * /home/oracle/backup/rmanbak.sh
```

### 8.2.expdp备份

#设置备份目录
```bash
su - oracle

mkdir /home/oracle/expdir
touch /home/oracle/expdir/expdir.sh
chmod a+x /home/oracle/expdir/expdir.sh
```
#oracle配置
```bash
sqlplus  / as sysdba
```
#创建目录
```
create directory expdir as '/home/oracle/expdir';
grant read,write on directory expdir to public;
```
#expdp脚本

#全库导出
```bash
expdp system/xxxx directory=expdir dumpfile=20211224.dmp logfile=20211224.log full=y parallel=4 cluster=N
```
#导出部分用户
```bash
expdp system/xxxx directory=expdir dumpfile=20211224.dmp logfile=20211224.log schemas=test,test1,test2 parallel=4 cluster=N
```

#定时备份脚本
#设置导出目录
```bash
su - oracle
mkdir -p /home/oracle/expdir
touch /home/oracle/expdir/expdir.sh
chmod a+x /home/oracle/expdir/expdir.sh
```

#脚本
```
#!/bin/bash

time=$(date +"%Y%m%d")
expdp_dir=/home/oracle/expdir

if [ -f $HOME/.bash_profile ]; then
    . $HOME/.bash_profile
elif [ -f $HOME/.profile ]; then
        . $HOME/.profile
fi

dmpfile=full_db$time.dmp
logfile=full_db$time.log

echo start expdp $dmpfile ... >> $expdp_dir/expdprun.log

expdp system/Z4wKxUTEb77 directory=expdir dumpfile=20211224.dmp logfile=$logfile full=y  parallel=4 cluster=N

echo done expdp $dmpfile ...  >> $expdp_dir/expdprun.log

#delete 3days before log 

echo start delete $logfile ... >> $expdp_dir/expdprun.log
find $expdp_dir -name 'full_db_*.log' -mtime +3 -exec rm {} \;

echo start delete $dmpfile ... >> $expdp_dir/expdprun.log
find $expdp_dir -name 'full_db_*.dmp' -mtime +3 -exec rm {} \;

echo done delete ...  >> $expdp_dir/expdprun.log
```
#设置调度任务
```bash
crontab -e

#每天0:30开始执行
30 1 * * * /home/oracle/expdir/expdir.sh
```