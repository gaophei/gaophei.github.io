**19C RAC for OLE7.9 安装手册深信服超融合**

## 目录
1 环境..............................................................................................................................................2
1.1. 系统版本： ..............................................................................................................................2
1.2. ASM 磁盘组规划 ....................................................................................................................2
1.3. 主机网络规划..........................................................................................................................2
1.4. 操作系统配置部分.................................................................................................................2
2 准备工作（rac01 与 rac02 同时配置） ............................................................................................3
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
### 1.0. 一台服务器

#本地深信服超融合环境，存储全部挂载给了虚拟化环境，没有多余的共享lun可以划出来，所以采用一台虚拟机搭建iscsi共享存储

#k8s-oracle-store作为19c RAC ADG的备库

```
k8s-oracle-store: 172.18.13.104
```

### 1.1. 系统版本

```
[root@k8s-rac01 ~]# cat /etc/os-release |grep PRETTY
PRETTY_NAME="Oracle Linux Server 7.9"

[root@k8s-rac01 ~]# uname -r
5.4.17-2102.201.3.el7uek.x86_64
```



### 1.2. 主机网络规划

#分区---120G

```
/boot   1G
swap    32G
/       其余容量  
```



###最后实际参数

```
[root@k8s-oracle-store ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vdh         251:112  0  200G  0 disk 
vdf         251:80   0  100G  0 disk 
vdd         251:48   0   50G  0 disk 
vdb         251:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
vdg         251:96   0  100G  0 disk 
vde         251:64   0  100G  0 disk 
vdc         251:32   0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
[root@k8s-oracle-store ~]# df -h
Filesystem           Size  Used Avail Use% Mounted on
devtmpfs              16G     0   16G   0% /dev
tmpfs                 16G     0   16G   0% /dev/shm
tmpfs                 16G   65M   16G   1% /run
tmpfs                 16G     0   16G   0% /sys/fs/cgroup
/dev/mapper/ol-root   87G  5.6G   82G   7% /
/dev/vda1           1014M  204M  811M  21% /boot
tmpfs                3.2G     0  3.2G   0% /run/user/0
[root@k8s-oracle-store ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:3a:a2:29 brd ff:ff:ff:ff:ff:ff
    inet 172.18.13.104/16 brd 172.18.255.255 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::e578:9631:36c9:efb6/64 scope link tentative noprefixroute dadfailed 
       valid_lft forever preferred_lft forever
    inet6 fe80::73c0:bbb4:3c87:976d/64 scope link tentative noprefixroute dadfailed 
       valid_lft forever preferred_lft forever
    inet6 fe80::2069:ca1d:ff3:e67/64 scope link tentative noprefixroute dadfailed 
       valid_lft forever preferred_lft forever
       
[root@k8s-oracle-store ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  5cb29430-beb7-48b8-ba7a-2e49415d02eb  ethernet  eth0
```



### 1.3. 操作系统配置部分

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


### 1.4.后续如果出现共享磁盘的uuid乱了时，可以退出并重新扫描、登录

```bash
ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

/usr/sbin/iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 172.18.13.104:3260 --logout

#iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 172.18.13.104:3260 -o delete
#systemctl restart iscsi.service

/usr/sbin/iscsiadm -m discovery -tsendtargets -p 172.18.13.104:3260

iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 172.18.13.104:3260 -l

lsblk

ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

/usr/sbin/partprobe

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service

ll /dev|grep asm

ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

#root用户下
/u01/app/19.0.0/grid/bin/crsctl start cluster
/u01/app/19.0.0/grid/bin/crsctl status resource -t
```

#ocrcheck -local报错处理

```bash
#如果ocrcheck -local报错，那么可以restore
[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
Status of Oracle Cluster Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      84464
	 Available space (kbytes) :     407220
	 ID                       : 1399819439
	 Device/File Name         :       +OCR
                                    Device/File integrity check succeeded

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

	 Cluster registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83408
	 Available space (kbytes) :     408276
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed



[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-rac02     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr     724960844

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     

[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded



[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 ~]# 
```



## 2.准备工作

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
yum install -y unixODBC
yum install -y unixODBC-devel
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

rpm -qa   binutils  compat-libcap1  compat-libstdc++-33    gcc  gcc-c++  glibc    glibc-devel    ksh  libgcc   libstdc++    libstdc++-devel   libaio   libaio-devel    libXext   libXtst  libX11    libXau   libxcb    libXi   make  sysstat  unixODBC   unixODBC-devel  readline  libtermcap-devel  bc  compat-libstdc++  elfutils-libelf  elfutils-libelf-devel  fontconfig-devel  libXi  libXtst  libXrender  libXrender-devel  libgcc  librdmacm-devel  libstdc++  libstdc++-devel  net-tools  nfs-utils  python  python-configshell  python-rtslib  python-six  targetcli  smartmontools
```
### 2.3. 创建用户

#创建用户组及用户前，检查下gid和uid是否已经占用

```bash
cat /etc/group

cd /home

id xxx
```



```bash
groupadd -g 11001 oinstall
groupadd -g 11002 dba
groupadd -g 11003 oper

useradd -u 11011 -g oinstall -G dba,oper oracle

passwd oracle

id oracle

#root/
#oracle/k8s123#@!
```
```bash
# id oracle
uid=11011(oracle) gid=11001(oinstall) groups=11001(oinstall),11002(dba),11003(oper)
```



### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#hostname
hostnamectl set-hostname k8s-oracle-store


cat >> /etc/hosts <<EOF
172.18.13.104 k8s-oracle-store
EOF
```
#检查下网络是否顺畅

```bash
ping  k8s-oracle-store
```



### 2.5. 起用 NTP



```bash
yum install ntp -y
systemctl start ntp; systemctl enable ntp
systemctl status ntp

vim /etc/ntp.conf

#注释下面4行

server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst

#替换成中国时间服务器：
#http://www.pool.ntp.org/zone/cn

server 0.cn.pool.ntp.org
server 1.cn.pool.ntp.org
server 2.cn.pool.ntp.org
server 3.cn.pool.ntp.org

#重启
systemctl restart ntpd
systemctl status ntpd

```
#时区设置
```bash
#查看是否中国时区
date -R 
timedatectl

#同步时间
rdate -s time.nist.gov
(clock -w)

#设置中国时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#方法二
timedatectl list-timezones |grep Shanghai #查找中国时区的完整名称
--->Asia/Shanghai
timedatectl set-timezone Asia/Shanghai
```

#修改系统语言环境
```
env|grep LANG

sudo echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```

### 2.6. 创建所需要目录

```bash
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/oracle/product/19.0.0/db_1

chown -R oracle:oinstall /u01
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
*            soft    stack           90000
*            hard    stack           90000
*            soft    memlock         unlimited
*            hard    memlock         unlimited

EOF

ulimit -a
```
#关闭THP，检查是否开启---单实例暂不处理

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
[root@k8s-rac01 ~]# grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
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

#memory=64G

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

sysctl -p
```
#memory=32G

```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 7031250
#memory*90%,此处为32G
kernel.shmmax = 28800000000
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
#禁用virbr0网卡

```bash
brctl show

ifconfig virbr0 down
brctl delbr virbr0

systemctl disable libvirtd.service
systemctl mask libvirtd.service
```

#日志

```bash
[root@rac01 storage]# systemctl status libvirtd.service
● libvirtd.service - Virtualization daemon
   Loaded: loaded (/usr/lib/systemd/system/libvirtd.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2023-09-25 14:49:28 CST; 29min ago
     Docs: man:libvirtd(8)
           https://libvirt.org
 Main PID: 2542 (libvirtd)
    Tasks: 19 (limit: 32768)
   CGroup: /system.slice/libvirtd.service
           ├─2542 /usr/sbin/libvirtd
           ├─2793 /usr/sbin/dnsmasq --conf-file=/var/lib/libvirt/dnsmasq...
           └─2794 /usr/sbin/dnsmasq --conf-file=/var/lib/libvirt/dnsmasq...

Sep 25 14:49:28 rac01 dnsmasq[2793]: started, version 2.76 cachesize 150
Sep 25 14:49:28 rac01 dnsmasq[2793]: compile time options: IPv6 GNU-get...y
Sep 25 14:49:28 rac01 dnsmasq-dhcp[2793]: DHCP, IP range 192.168.122.2 ...h
Sep 25 14:49:28 rac01 dnsmasq-dhcp[2793]: DHCP, sockets bound exclusive...0
Sep 25 14:49:28 rac01 dnsmasq[2793]: reading /etc/resolv.conf
Sep 25 14:49:28 rac01 dnsmasq[2793]: using nameserver 202.206.16.2#53
Sep 25 14:49:28 rac01 dnsmasq[2793]: using nameserver 233.5.5.5#53
Sep 25 14:49:28 rac01 dnsmasq[2793]: read /etc/hosts - 9 addresses
Sep 25 14:49:28 rac01 dnsmasq[2793]: read /var/lib/libvirt/dnsmasq/defa...s
Sep 25 14:49:28 rac01 dnsmasq-dhcp[2793]: read /var/lib/libvirt/dnsmasq...e
Hint: Some lines were ellipsized, use -l to show in full.
[root@rac01 storage]# brctl show
bridge name     bridge id               STP enabled     interfaces
virbr0          8000.525400292db9       yes             virbr0-nic
[root@rac01 storage]# nmcli con show
NAME    UUID                                  TYPE      DEVICE
eth0    bdc16ef2-d1d0-4c97-889c-961adfa53039  ethernet  eth0
eth1    d5d1bda3-c00f-484f-b818-e68b5023dbc7  ethernet  eth1
virbr0  2c4afa19-bb2b-4fa3-a5a0-6ea5cb84cf96  bridge    virbr0


[root@rac01 storage]# ifconfig virbr0 down
[root@rac01 storage]# brctl delbr virbr0
[root@rac01 storage]# systemctl disable libvirtd.service
Removed symlink /etc/systemd/system/multi-user.target.wants/libvirtd.service.
Removed symlink /etc/systemd/system/sockets.target.wants/virtlogd.socket.
Removed symlink /etc/systemd/system/sockets.target.wants/virtlockd.socket.
[root@rac01 storage]# systemctl mask libvirtd.service
Created symlink from /etc/systemd/system/libvirtd.service to /dev/null.
[root@rac01 storage]#
```



### 2.8. 配置环境变量



#oracle用户

```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/db_1
export ORACLE_SID=xydbdg
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
EOF

```


## 3 安装 Oracle 数据库软件
#以 Oracle 用户登录图形化界面，将数据库软件解压至$ORACLE_HOME 

```bash
[oracle@rac01 db_1]$ pwd
/u01/app/oracle/product/19.0.0/db_1
[oracle@rac01 db_1]$ unzip -oq /u01/storage/LINUX.X64_193000_db_home.zip
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



#通过xstart图形化连接服务器

#也可以通过Mo



```bash
[oracle@rac01 db_1]$ ./runInstaller
```
### 5.1. oracle software安装步骤
#安装过程如下
```
1. 仅设置software
2. Single instance database installation
3. Enterprise Edition
4. $ORACLE_BASE(/u01/app/oracle)
5. /u01/app/oraInventory
6. 用户组，保持默认
7. 不执行配置脚本，保持默认
8. 全部Succeeded
9. Install
10. root账户执行脚本(/u01/app/oraInventory/orainstRoot.sh 和 /u01/app/oracle/product/19.0.0/db_1/root.sh)，然后点击OK
11. Close
```
#执行脚本记录

```
[root@k8s-oracle-store ~]# cd /u01/app/oracle/product/19.0.0/db_1
[root@k8s-oracle-store db_1]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@k8s-oracle-store db_1]#  /u01/app/oracle/product/19.0.0/db_1/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/19.0.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Oracle Trace File Analyzer (TFA - Standalone Mode) is available at :
    /u01/app/oracle/product/19.0.0/db_1/bin/tfactl

Note :
1. tfactl will use TFA Service if that service is running and user has been granted access
2. tfactl will configure TFA Standalone Mode only if user has no access to TFA Service or TFA is not installed

```



## 6 建立数据库

以 oracle 账户登录。

### 6.1.执行netca
#创建listener的步骤
```
1. Listener configuration
2. Add
3. LISTENER
4. TCP
5. Use the standard port number of 1521
6. No
7. Next
8. Finish
```
#查看监听是否正常

```bash
[oracle@k8s-oracle-store db_1]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 04-JAN-2024 17:04:28

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                04-JAN-2024 17:03:58
Uptime                    0 days 0 hr. 0 min. 31 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
The listener supports no services
The command completed successfully

```



### 6.2. 执行建库 dbca

#创建数据库步骤

#为了创建ADG，作为备库，db_name必须跟主库一致(xydb)，但是db_unique_name不能一致(xydbdg)，但是默认db_unique_name=db_name，所以部署完单实例后，要通过修改系统参数db_unique_name

```
1. Create a database
2. Advanced Configuration
3. Oracle Single Instance database/Admin Managed/General Purpose
4. xydb/xydbdg/Create as Container database/Use Local Undo tbs for PDBs/pdb:1/pdbname:testpdb
5. Use following for the database storage attributes: File System/{ORACLE_BASE}/oradata/{DB_UNIQUE_NAME}
6. Specify Fast Recovery Area: File System/ {ORACLE_BASE}/fast_recovery_area/{DB_UNIQUE_NAME} /Size: 20Giving
7. LISTENER/1521/ /u01/app/oracle/product/19.0.0/db_1 /Up
8. 数据库组件(Oracle Data Vault)，保持默认不选
9. ASMM自动共享内存管理
       #sga=memory*65%*75%=64G*65%*75%=31.2G(向下十位取整为30G)
       #pga=memory*65%*25%=64G*65%*25%=10.4G(向下十位取整为10G)
       #sga=30G
       #pag=10G
       #此处为总32G，所以sga=15G,pga=5G
   Sizing: block size: 8192/processes: 3000
   Character Sets: AL32UTF8
   Connection mode: Dadicated server mode--->Next
10. 关闭EM
11. 使用相同密码Oracle2023#Sys
12. 勾选：create database
13. Finish
14. Close
```
### 6.3. 查看数据库版本
```
[oracle@k8s-oracle-store ~]$  sqlplus / as sysdba
SQL> col banner_full for a120
SQL> select BANNER_FULL from v$version;

BANNER_FULL
--------------------------------------------------------------------------------
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select INST_NUMBER,INST_NAME FROM v$active_instances;
no rows selected

SQL> select instance_name from v$instance;

INSTANCE_NAME
----------------
xydbdg


SQL> col file_name format a80

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------------------------------------------- -----------------------
/u01/app/oracle/oradata/XYDB/temp01.dbf					 TEMP

SQL> 


SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
/u01/app/oracle/oradata/XYDB/system01.dbf					 SYSTEM
/u01/app/oracle/oradata/XYDB/sysaux01.dbf					 SYSAUX
/u01/app/oracle/oradata/XYDB/undotbs01.dbf				 UNDOTBS1
/u01/app/oracle/oradata/XYDB/users01.dbf					 USERS

SQL> 

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 TESTPDB			  READ WRITE NO


SQL>   alter session set container=testpdb;

Session altered.

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------------------------------------------- -----------------------
/u01/app/oracle/oradata/XYDB/testpdb/temp01.dbf				 TEMP

SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------------------------------------------- -----------------------
/u01/app/oracle/oradata/XYDB/testpdb/system01.dbf				 SYSTEM
/u01/app/oracle/oradata/XYDB/testpdb/sysaux01.dbf				 SYSAUX
/u01/app/oracle/oradata/XYDB/testpdb/undotbs01.dbf			 UNDOTBS1
/u01/app/oracle/oradata/XYDB/testpdb/users01.dbf				 USERS

SQL> 

```
### 6.4. Oracle RAC数据库优化
#user password life修改，CDB/PDB都要修改

```oracle
select resource_name,limit from dba_profiles where profile='DEFAULT';
alter profile default limit password_life_time unlimited;
alter profile  ORA_STIG_PROFILE limit  PASSWORD_LIFE_TIME   UNLIMITED;
ALTER PROFILE DEFAULT limit FAILED_LOGIN_ATTEMPTS unlimited;

select resource_name,limit from dba_profiles where profile='DEFAULT';
```
#允许oracle低版本连接

```
su - oracle
cd $ORACLE_HOME/network/admin
vi sqlnet.ora

SQLNET.ALLOWED_LOGON_VERSION_SERVER=8
SQLNET.ALLOWED_LOGON_VERSION_CLIENT=8
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

#DB_FILES修改，默认200

```oracle
alter system set DB_FILES=4096 scope=spfile;

shutdown immediate;
startup;

show parameter db_files
```

#开启hugepages

```bash
#!/bin/bash
#
# hugepages_settings.sh

# Welcome text
echo "
This script is provided by Doc ID 401749.1 from My Oracle Support
(http://support.oracle.com) where it is intended to compute values for
the recommended HugePages/HugeTLB configuration for the current shared
memory segments on Oracle Linux. Before proceeding with the execution please note following:
 * For ASM instance, it needs to configure ASMM instead of AMM.
 * The 'pga_aggregate_target' is outside the SGA and
   you should accommodate this while calculating the overall size.
 * In case you changes the DB SGA size,
   as the new SGA will not fit in the previous HugePages configuration,
   it had better disable the whole HugePages,
   start the DB with new SGA size and run the script again.
And make sure that:
 * Oracle Database instance(s) are up and running
 * Oracle Database 11g Automatic Memory Management (AMM) is not setup
   (See Doc ID 749851.1)
 * The shared memory segments can be listed by command:
     # ipcs -m

Press Enter to proceed..."

read

# Check for the kernel version
KERN=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`

# Find out the HugePage size
HPG_SZ=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
if [ -z "$HPG_SZ" ];then
    echo "The hugepages may not be supported in the system where the script is being executed."
    exit 1
fi

# Initialize the counter
NUM_PG=0

# Cumulative number of pages required to handle the running shared memory segments
for SEG_BYTES in `ipcs -m | cut -c44-300 | awk '{print $1}' | grep "[0-9][0-9]*"`
do
    MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
    if [ $MIN_PG -gt 0 ]; then
        NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
    fi
done

RES_BYTES=`echo "$NUM_PG * $HPG_SZ * 1024" | bc -q`

# An SGA less than 100MB does not make sense
# Bail out if that is the case
if [ $RES_BYTES -lt 100000000 ]; then
    echo "***********"
    echo "** ERROR **"
    echo "***********"
    echo "Sorry! There are not enough total of shared memory segments allocated for
HugePages configuration. HugePages can only be used for shared memory segments
that you can list by command:

    # ipcs -m

of a size that can match an Oracle Database SGA. Please make sure that:
 * Oracle Database instance is up and running
 * Oracle Database 11g Automatic Memory Management (AMM) is not configured"
    exit 1
fi

# Finish with results
case $KERN in
    '2.4') HUGETLB_POOL=`echo "$NUM_PG*$HPG_SZ/1024" | bc -q`;
           echo "Recommended setting: vm.hugetlb_pool = $HUGETLB_POOL" ;;
    '2.6') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '3.8') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '3.10') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '4.1') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '4.14') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '4.18') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '5.4') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    *) echo "Kernel version $KERN is not supported by this script (yet). Exiting." ;;
esac

# End
```



```bash
vi /etc/sysctl.conf
#添加
vm.nr_hugepages = 15362

sysctl -p
reboot

grep "HugePages" /proc/meminfo
```



#VKTM报错处理

```oracle
Warning: VKTM detected a forward time drift.
Please see the VKTM trace file for more details:
/u01/app/oracle/diag/rdbms/xydb/xydb2/trace/xydb2_vktm_9790.trc
```

#解决：

```oracle
alter system set event="10795 trace name context forever, level 2" scope=spfile sid='*';

srvctl stop database -d xydb 
srvctl start database -d xydb 
```



#resize operation completed for file# old size new size报错处理

```bash
2023-10-30T01:13:27.378988+08:00
DATAASSETS(3):Resize operation completed for file# 11, fname +DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/sysaux.275.1148736011, old size 563200K, new size 573440K
```

#解决

#cdb设置，全体pdb也生效

```sql
col name for a52
col value for a24
col description for a50

Set linesize 300
Select a.ksppinm name, B.ksppstvl value, a.ksppdesc description
From x$ksppi a, x$ksppcv B
Where a.inst_id = USERENV ('instance')
And B.inst_id = USERENV ('instance')
And a.indx = B.indx
and upper (a.ksppinm) LIKE upper ('%&param%')
order by name
/

---->_disable_file_resize_logging

 alter system set "_disable_file_resize_logging"=TRUE scope=both;
```





##创建service----单实例没有

```oracle
su - oracle

srvctl add service -d xydb -s s_stuwork -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb stuwork

srvctl start service -d xydb -s s_stuwork

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

SQL> alter user pdbadmin identified by Oracle2023#Sys account unlock;

User altered.

SQL> grant dba to pdbadmin;

Grant succeeded.

SQL> exit
#sqlplus pdbadmin/DSApdb2023#ADb@172.18.13.101:1521/s_dataassets
#sqlplus portaluser/Oracle2023#Portal@172.18.13.101:1521/s_portal
#sqlplus onecodeuser/ConeDe2839#CoeN@172.18.13.101:1521/s_onecode

#sqlplus system/Oracle2023#Sys@172.18.13.101:1521/s_dataassets

[oracle@rac02 ~]$ sqlplus pdbadmin/DSApdb2023#ADb@172.18.13.101:1521/s_dataassets

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

#快速进入某pdb

```bash
export ORACLE_PDB_SID=portal
sqlplus / as sysdba
show con_name;

[oracle@rac01 ~]$ export ORACLE_PDB_SID=portal;
[oracle@rac01 ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Thu Oct 19 15:51:21 2023
Version 19.20.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.20.0.0.0

SQL> show con_name;

CON_NAME
------------------------------
PORTAL

SQL> alter session set container=cdb$root;  

Session altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 PORTAL			  READ WRITE NO
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
expdp test1/test1@172.18.13.101:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n
#导出全库
expdp pdbadmin/pdbadmin@172.18.13.101:1521/s_dataassets full=y directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp
impdp est1/test1@172.18.13.101:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp--remap
impdp  est1/test1@172.18.13.101:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n   remap_schema=test2:test1 remap_tablespace=test2:test1  logfile=test01.log cluster=n

#expdp-12.2.0.1.0
expdp test1/test1@172.18.13.101:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n compression=data_only version=12.2.0.1.0

#脚本

#!/bin/bash
source /etc/profile
source /home/oracle/.bash_profile

now=`date +%y%m%d`
dmpfile=dataassets_db$now.dmp
logfile=dataassets_db$now.log

echo start exp $dmpfile ...


expdp pdbadmin/pdbadmin@172.18.13.101:1521/s_dataassets full=y directory=expdir dumpfile=$dmpfile logfile=$logfile cluster=n 



echo delete local file ...
find /home/oracle/expdir -name "*.dmp" -mtime +5 -exec rm {} \;
find /home/oracle/expdir -name "*.log" -mtime +5 -exec rm {} \;

echo finish bak job

```
### 6.5. Oracle RAC其他操作
#创建pdb

```oracle
create pluggable database portal admin user portaluser identified by Oracle2023#Portal roles=(dba);

alter pluggable database portal open;
alter session set container=portal;
grant dba to portaluser;
#如果不赋权，那么没有system表空间的权限
SQL> create table test as select * from dba_users;
create table test as select * from dba_users
                                   *
ERROR at line 1:
ORA-01950: no privileges on tablespace 'SYSTEM'


create tablespace PORTAL_SERVICE datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

alter tablespace PORTAL_SERVICE add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user PORTAL_SERVICE_V6 identified by Oracle2023#Portal default tablespace PORTAL_SERVICE account unlock;

grant dba to PORTAL_SERVICE_V6;

grant select any table to PORTAL_SERVICE_V6;

------------------------------------------------


------------------------------------
create pluggable database onecode admin user onecodeuser identified by ConeDe2839#CoeN roles=(dba);

alter pluggable database onecode open;
alter session set container=onecode;
grant dba to onecodeuser；

create pluggable database dataassets admin user pdbadmin identified by ConeDe2839#CoeN roles=(dba);

alter pluggable database onecode open;
alter session set container=onecode;
grant dba to onecodeuser；
```
#连接方式

```bash
srvctl add service -d xydb -s s_portal -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb portal

srvctl start service -d xydb -s s_portal
srvctl status service -d xydb -s s_portal

sqlplus portaluser/Oracle2023#Portal@172.18.13.101:1521/s_portal

--------------------------------
srvctl add service -d xydb -s s_onecode -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb onecode

srvctl start service -d xydb -s s_onecode
srvctl status service -d xydb -s s_onecode

sqlplus onecodeuser/ConeDe2839#CoeN@172.18.13.101:1521/s_onecode

sqlplus pdbadmin/DSApdb2023#ADb@172.18.13.101:1521/s_dataassets

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



## 7 打补丁

#注意事项

```
本次升级顺序是19.3.0--->19.20.0--->19.21.0
打补丁顺序:
k8s-rac01 GI---> k8s-rac02 GI ---> k8s-rac01 DB ---> k8s-rac02 DB

#单实例的话，只需要19.3.0--->19.20.0 DB--->19.21.0 DB 即可
#If this is not a RAC environment, shut down all instances and listeners associated with the Oracle home that you are updating.

打补丁前可以先备份grid/oracle目录---k8s-rac01/k8s-rac02 用户root执行
cd  /u01/app/19.0.0/
tar -zcvf grid.tar.gz grid

cd  /u01/app/oracle/product/19.0.0
tar -zcvf db_1.tar.gz db_1

磁盘空间检查
df -h
```



### 7.1.首先打19.20RU

#补丁列表

|                             Name                             |  Download Link   |
| :----------------------------------------------------------: | :--------------: |
|           Database Release Update 19.20.0.0.230718           | <Patch 35320081> |
|     Grid Infrastructure Release Update 19.20.0.0.230718      | <Patch 35319490> |
|             OJVM Release Update 19.20.0.0.230718             | <Patch 35354406> |
|  (there were no OJVM Release Update Revisions for Jul 2023)  |                  |
| Microsoft Windows 32-Bit & x86-64 Bundle Patch 19.20.0.0.230718 | <Patch 35348034> |



```
#补丁位置：---k8s-rac01/k8s-rac02都一样
[root@k8s-rac02 ~]# cd /opt/19.20patch/
[root@k8s-rac02 19.20patch]# ls -lrth
total 4.7G
-rw-r--r-- 1 root root 120M Oct 10 14:14 p6880880_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 2.8G Oct 10 14:14 p35319490_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 1.7G Oct 10 14:14 p35320081_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 122M Oct 10 14:14 p35354406_190000_Linux-x86-64.zip
```



#### 7.1.1.检查集群状态---单实例不执行

```bash
crsctl status resource -t
```

#集群正常

```bash
[grid@k8s-rac02 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                Started,STABLE
      2        ONLINE  ONLINE       k8s-rac02                Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.k8s-rac01.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac02.vip
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-rac02                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------

[grid@k8s-rac01 ~]$ crsctl status res -t -init
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.asm
      1        ONLINE  ONLINE       k8s-rac01                Started,STABLE
ora.cluster_interconnect.haip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.crf
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.crsd
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.cssd
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.cssdmonitor
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.ctssd
      1        ONLINE  ONLINE       k8s-rac01                ACTIVE:0,STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.drivers.acfs
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.evmd
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.gipcd
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.gpnpd
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.mdnsd
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.storage
      1        ONLINE  ONLINE       k8s-rac01                STABLE
--------------------------------------------------------------------------------

```

##### 7.1.1.1.单实例打补丁，必须关闭待升级ORACLE HOME关联的所有实例和监听，并且包括退出所有的sqlplus窗口

```bash
su - oracle

$ lsnrctl stop

$ sqlplus / as sysdba

shutdown immediate;
```

#logs

```bash
[root@k8s-oracle-store 35320081]# su - oracle
Last login: Fri Jan  5 11:05:38 CST 2024 on pts/4
[oracle@k8s-oracle-store ~]$ lsnrctl stop

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 05-JAN-2024 11:22:52

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
The command completed successfully
[oracle@k8s-oracle-store ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 05-JAN-2024 11:22:55

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 111: Connection refused
Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=EXTPROC1521)))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 2: No such file or directory
[oracle@k8s-oracle-store ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Jan 5 11:23:14 2024
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> shutdown immediate;
Database closed.
Database dismounted.
ORACLE instance shut down.
SQL> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0
[oracle@k8s-oracle-store ~]$ ps -x
  PID TTY      STAT   TIME COMMAND
15343 pts/4    R+     0:00 ps -x
25310 pts/3    S      0:00 -bash
27628 pts/3    S+     0:00 tail -f alert_xydbdg.log
32188 pts/4    S      0:00 -bash
[oracle@k8s-oracle-store ~]$ 

```



#### 7.1.2.更新grid opatch 两个节点 root执行---单实例不执行

```bash
#备份opatch
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch_bak    

#更新opatch
unzip -q /opt/19.20patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/  

chmod -R 755 /u01/app/19.0.0/grid/OPatch

chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

#更新后检查opatch的版本至少12.2.0.1.37
su - grid

[grid@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-rac01 OPatch]$ ./opatch version   

OPatch Version: 12.2.0.1.39
OPatch succeeded.
```



#### 7.1.3.更新oracle opatch 两个节点 root执行

```bash
#备份opatch
mv /u01/app/oracle/product/19.0.0/db_1/OPatch /u01/app/oracle/product/19.0.0/db_1/OPatch.bak     

unzip -q /opt/19.20patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/db_1/ 

chmod -R 755 /u01/app/oracle/product/19.0.0/db_1/OPatch

chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/db_1/OPatch
```

 

#### 7.1.4.解压patch包 两个节点 root执行---单实例不执行

```bash
#这一个包 包含了全部的patch
unzip /opt/19.20patch/p35319490_190000_Linux-x86-64.zip -d /opt/19.20patch/

chown -R grid:oinstall /opt/19.20patch/35319490

chmod -R 755 /opt/19.20patch/35319490

#此时可以查看35319490文件夹下的 README.html，里面有详细的RU步骤
```

##### 7.1.4.1.单实例打补丁只解压db补丁即可---root执行

```bash
su - root
unzip /opt/19.20patch/p35320081_190000_Linux-x86-64.zip -d /opt/19.20patch/

chown -R oracle:oinstall /opt/19.20patch/35320081
chmod -R 755 /opt/19.20patch/35320081
```



#### 7.1.5.兼容性检查

```bash
#OPatch兼容性检查 两个节点 grid用户---单实例不执行

 su - grid

/u01/app/19.0.0/grid/OPatch/opatch lsinventory -detail -oh /u01/app/19.0.0/grid/

#OPatch兼容性检查 两个节点 oracle用户

 su - oracle

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatch lsinventory -detail -oh /u01/app/oracle/product/19.0.0/db_1/
```



#### 7.1.6.补丁冲突检查 k8s-rac01/k8s-rac02两个节点都执行---单实例不执行

```bash
#子目录的五个patch在grid用户下分别执行检查---单实例不执行

su - grid

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320081

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320149

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35332537

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35553096

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/33575402


#子目录的一个patch在oracle用户下执行检查


su - oracle


$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320081

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320149
```



##### 7.1.6.1.单实例打补丁只检查DB补丁即可

```bash
su - oracle

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35320081
```



#logs

```bash
[root@k8s-oracle-store 19.20patch]# ll -rth
total 1.8G
drwxr-xr-x 5 root root   81 Jul 16 03:54 35320081
-rw-rw-r-- 1 root root 1.7M Jul 18 21:03 PatchSearch.xml
-rw-r--r-- 1 root root 1.7G Jan  4 17:17 p35320081_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 120M Jan  5 10:54 p6880880_190000_Linux-x86-64.zip
[root@k8s-oracle-store 19.20patch]# chown -R oracle:oinstall /opt/19.20patch/35320081
[root@k8s-oracle-store 19.20patch]# chmod -R 755 /opt/19.20patch/35320081
[root@k8s-oracle-store 19.20patch]# ll
total 1851584
drwxr-xr-x 5 oracle oinstall         81 Jul 16 03:54 35320081
-rw-r--r-- 1 root   root     1769419773 Jan  4 17:17 p35320081_190000_Linux-x86-64.zip
-rw-r--r-- 1 root   root      124843817 Jan  5 10:54 p6880880_190000_Linux-x86-64.zip
-rw-rw-r-- 1 root   root        1749054 Jul 18 21:03 PatchSearch.xml

[root@k8s-oracle-store 19.20patch]# su - oracle

[oracle@k8s-oracle-store ~]$ $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35320081
Oracle Interim Patch Installer version 12.2.0.1.37
Copyright (c) 2024, Oracle Corporation.  All rights reserved.

PREREQ session

Oracle Home       : /u01/app/oracle/product/19.0.0/db_1
Central Inventory : /u01/app/oraInventory
   from           : /u01/app/oracle/product/19.0.0/db_1/oraInst.loc
OPatch version    : 12.2.0.1.37
OUI version       : 12.2.0.7.0
Log file location : /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/opatch2024-01-05_11-05-45AM_1.log

Invoking prereq "checkconflictagainstohwithdetail"

Prereq "checkConflictAgainstOHWithDetail" passed.

OPatch succeeded.

```



#### 7.1.7.空间检查 k8s-rac01/k8s-rac02两个节点都执行

```bash
#grid用户执行---单实例不执行

su - grid

touch /tmp/patch_list_gihome.txt

cat >>  /tmp/patch_list_gihome.txt <<EOF
/opt/19.20patch/35319490/35320081
/opt/19.20patch/35319490/35320149
/opt/19.20patch/35319490/35332537
/opt/19.20patch/35319490/35553096
/opt/19.20patch/35319490/33575402
EOF


$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_list_gihome.txt


#oracle用户执行

su - oracle

touch /tmp/patch_list_dbhome.txt

cat > /tmp/patch_list_dbhome.txt <<EOF
/opt/19.20patch/35320081
EOF

$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_list_dbhome.txt
```



#### 7.1.8.补丁分析检查  root用户两个节点都要分别执行 ---单实例不执行

```bash
su - root

#k8s-rac01:
#k8s-rac01大约2分钟40秒，全部成功(最长有过4分17秒)

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -analyze

#k8s-rac02:
#k8s-rac02大约2分钟40秒，全部成功(最长有过3分48秒)
#可能会有部分失败

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -analyze

-----------------------------
Reason: Failed during Analysis: CheckSystemCommandsAvailable Failed, [ Prerequisite Status: FAILED, Prerequisite output:
The details are:

Missing command :fuser]
---------------------------


#解决办法：
yum install -y psmisc

#k8s-rac02再次检查：
#k8s-rac02大约2分钟40秒，全部成功
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -analyze       
```





#### 7.1.9.grid 升级 root两个节点都要分别执行 --grid upgrade ---单实例不执行

```bash
su - root

#k8s-rac01约15分钟(最长有过80分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   

#k8s-rac02约20分钟(最长有过60分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   
#报错后可以再次执行


#升级后的状态
su - grid
cd $ORACLE_HOME/OPatch

[grid@k8s-rac01 OPatch]$./opatch lspatches   
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
35332537;ACFS RELEASE UPDATE 19.20.0.0.0 (35332537)
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.

[grid@k8s-rac02 OPatch]$ ./opatch lspatches   
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
35332537;ACFS RELEASE UPDATE 19.20.0.0.0 (35332537)
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.
```

#错误处理

```bash
#(0)
#不能在/root或/目录下执行，否则报错：
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   

Invalid current directory.  Please run opatchauto from other than '/root' or '/' directory.
And check if the home owner user has write permission set for the current directory.
opatchauto returns with error code = 2
------------------------------------------------------------------------
#(1)
#GI因为共享磁盘的UUID变化，没起来

CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-1705: Found 1 configured voting files but 2 voting files are required, terminating to ensure data integrity; details at (:CSSNM00021:) in /u01/app/grid/diag/crs/k8s-rac02/crs/trace/ocssd.trc
CRS-2883: Resource 'ora.cssd' failed during Clusterware stack start.
CRS-4406: Oracle High Availability Services synchronous start failed.
CRS-41053: checking Oracle Grid Infrastructure for file permission issues
PRVH-0116 : Path "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" with permissions "rw-r--r--" does not have execute permissions for the owner, file's group, and others on node "k8s-rac02".
PRVG-2031 : Owner of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-rac02". [Expected = "grid(11012)" ; Found = "root(0)"]
PRVG-2032 : Group of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-rac02". [Expected = "oinstall(11001)" ; Found = "root(0)"]
CRS-4000: Command Start failed, or completed with errors.
2023/11/19 07:42:47 CLSRSC-117: Failed to start Oracle Clusterware stack 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 07:42:50 2023
Time taken to complete the session 2 minutes, 35 seconds

 opatchauto failed with error code 42
------------------------------------------------------------------------

#(2)
#共享磁盘重新扫描、挂载修复后，发现因为olr无法手动备份，导致报错；

Performing postpatch operations on CRS - starting CRS service on home /u01/app/19.0.0/grid
Postpatch operation log file location: /u01/app/grid/crsdata/k8s-rac02/crsconfig/crs_postpatch_apply_inplace_k8s-rac02_2023-11-19_09-07-00AM.log
Failed to start CRS service on home /u01/app/19.0.0/grid

Execution of [GIStartupAction] patch action failed, check log for more details. Failures:
Patch Target : k8s-rac02->/u01/app/19.0.0/grid Type[crs]
Details: [
---------------------------Patching Failed---------------------------------
Command execution failed during patching in home: /u01/app/19.0.0/grid, host: k8s-rac02.
Command failed:  /u01/app/19.0.0/grid/perl/bin/perl -I/u01/app/19.0.0/grid/perl/lib -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/xag /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install/rootcrs.pl -postpatch
Command failure output: 
Using configuration parameter file: /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crs_postpatch_apply_inplace_k8s-rac02_2023-11-19_09-07-00AM.log
2023/11/19 09:07:16 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
Oracle Clusterware active version on the cluster is [19.0.0.0.0]. The cluster upgrade state is [NORMAL]. The cluster active patch level is [3976270074].
CRS-2672: Attempting to start 'ora.drivers.acfs' on 'k8s-rac02'
CRS-2676: Start of 'ora.drivers.acfs' on 'k8s-rac02' succeeded
2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 09:10:12 2023
Time taken to complete the session 25 minutes, 5 seconds

 opatchauto failed with error code 42
[root@k8s-rac02 35319490]# 

#发现错误是2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 
#手动执行，发现确实报错
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup manual

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 ~]# ll /u01/app/grid/crsdata/k8s-rac02/olr
total 495048
-rw-r--r-- 1 root root       1101824 Nov 18 18:49 autobackup_20231118_184948.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:35 backup_20231118_183548.olr
-rw------- 1 root oinstall 503484416 Nov 19 11:54 k8s-rac02_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 08:46 k8s-rac02_19.olr.bkp.patch
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup
PROTL-23: failed to back up Oracle Local Registry
PROCL-60: The Oracle Local Registry backup file '/u01/app/grid/crsdata/k8s-rac02/olr/backup_20231119_121545.olr' is corrupt.

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83168
	 Available space (kbytes) :     408516
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed


#但在k8s-rac01上手动备份没问题
[root@k8s-rac01 ContentsXML]# ocrconfig -local -manualbackup

k8s-rac01     2023/11/19 12:12:49     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231119_121249.olr     3976270074     

k8s-rac01     2023/11/19 01:25:37     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231119_012537.olr     3976270074     

k8s-rac01     2023/11/18 18:27:53     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231118_182753.olr     724960844     
[root@k8s-rac01 ContentsXML]# ll /u01/app/grid/crsdata/k8s-rac01/olr/
total 498160
-rw-r--r-- 1 root root       1114112 Nov 18 18:39 autobackup_20231118_183942.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:27 backup_20231118_182753.olr
-rw------- 1 root root       1150976 Nov 19 01:25 backup_20231119_012537.olr
-rw------- 1 root root       1593344 Nov 19 12:12 backup_20231119_121249.olr
-rw------- 1 root oinstall 503484416 Nov 19 12:12 k8s-rac01_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 00:11 k8s-rac01_19.olr.bkp.patch
[root@k8s-rac01 ~]#  /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83444
	 Available space (kbytes) :     408240
	 ID                       : 1567972045
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac01/olr/k8s-rac01_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#k8s-rac02，如果此时关闭cluster，将无法启动，特别是ora.asm/ora.OCR.dg(ora.asmgroup)/ora.DATA.dg(ora.asmgroup)/ora.FRA.dg(ora.asmgroup)等无法启动，但是vip/LISTENER等其他组件正常

[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
===== Summary of resource auto-start failures follows =====
CRS-2807: Resource 'ora.asmgroup' failed to start automatically.
CRS-2807: Resource 'ora.xydb.db' failed to start automatically.
CRS-2807: Resource 'ora.xydb.s_stuwork.svc' failed to start automatically.
CRS-6016: Resource auto-start has completed for server k8s-rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                Started,STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac01.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac02.vip
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  OFFLINE                               STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
--------------------------------------------------------------------------------

[root@k8s-rac02 trace]# tail -f /u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsctl_8402.trc

2023-11-20 03:21:08.163 :  OCROSD:2832813824: utopen: Failed to open OCR disk/file [/u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr], errno:[13], OS error string:[Permission denied]
2023-11-20 03:21:08.163 :  OCROSD:2832813824: utopen:7: failed to open any OCR file/disk, errno=13, os err string=Permission denied
 default:2832813824: u_set_gbl_comp_error: comptype '101' : error '13'
2023-11-20 03:21:08.163 :  OCRRAW:2832813824: proprinit: Could not open raw device
2023-11-20 03:21:08.163 : default:2832813824: a_init:7!: Backend init unsuccessful : [26]
2023-11-20 03:21:08.163 :  OCRAPI:2832813824: clsugcnr:5.1: procr_init_ext failed [26] with bootlevel [131072]. Error data [PROCL-26: Error while accessing the physical storage Operating System error [Permission denied] [13]]. Return [5]


#此时对olr进行restore处理
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-rac02     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr     724960844

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     

#再次检查ocrcheck -local，发现为succeeded
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck 
PROT-602: Failed to retrieve data from the cluster registry
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 trace]# 

------------------------------------------------------------------------
#(3)
#但是此时再次启动cluster报错，因为还原了Olr后与已经打的补丁不一致
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start cluster
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl check crs
CRS-4639: Could not contact Oracle High Availability Services

[root@k8s-rac02 dispatcher.d]# ps -ef|grep grid|grep app|awk '{print $2}'|xargs kill -9

[root@k8s-rac02 dispatcher.d]# ps -ef|grep grid
root     14717 11600  0 11:51 pts/4    00:00:00 grep --color=auto grid
root     26985 11598  0 Nov21 pts/2    00:00:00 su - grid
grid     26987 26985  0 Nov21 pts/2    00:00:00 -bash
grid     29819 26987  0 Nov21 pts/2    00:00:00 tail -100f alert_+ASM2.log


[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.

#解决办法：

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -unlock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crsunlock_k8s-rac02_2023-11-22_11-54-32AM.log
2023/11/22 11:54:33 CLSRSC-4012: Shutting down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:56 CLSRSC-4013: Successfully shut down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:58 CLSRSC-347: Successfully unlock /u01/app/19.0.0/grid

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/clscfg -localpatch
clscfg: EXISTING configuration version 0 detected.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -lock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crslock_k8s-rac02_2023-11-22_11-58-45AM.log
2023/11/22 11:58:52 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-33676: Start of resource group 'ora.asmgroup' on server 'k8s-rac02' succeeded.
CRS-2672: Attempting to start 'ora.FRA.dg' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.DATA.dg' on 'k8s-rac02'
CRS-2676: Start of 'ora.FRA.dg' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.DATA.dg' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-2676: Start of 'ora.xydb.db' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.s_stuwork.svc' on 'k8s-rac02'
CRS-2676: Start of 'ora.xydb.s_stuwork.svc' on 'k8s-rac02' succeeded
CRS-6016: Resource auto-start has completed for server k8s-rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-rac02 ~]# 

[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
Status of Oracle Cluster Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      84460
	 Available space (kbytes) :     407224
	 ID                       : 1399819439
	 Device/File Name         :       +OCR
                                    Device/File integrity check succeeded

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

	 Cluster registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83152
	 Available space (kbytes) :     408532
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#再次手动备份也正常了
[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup

k8s-rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844    

#再次打补丁

```



#### 7.1.10.oracle 升级 root两个节点都要分别执行 --oracle upgrade ---单实例不执行

```bash
su - root

#k8s-rac01
#在非/和/root目录下执行

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/oracle/product/19.0.0/db_1

#k8s-rac01约25分钟 
-------------------------------------------------------

#第一次执行报错：

Patch: /opt/opa/35319490/35320081
Log: /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatchauto/core/opatch/opatch2023-10-10_17-11-02PM_1.log
Reason: Failed during Patching: oracle.opatch.opatchsdk.OPatchException: Prerequisite check "CheckActiveFilesAndExecutables" failed.
After fixing the cause of failure Run opatchauto resume
#查看日志：

Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1 PID( 110745 )
Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so PID( 110745 )
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so
[Oct 10, 2023 5:11:47 PM] [SEVERE]  OUI-67073:UtilSession failed: Prerequisite check "CheckActiveFilesAndExecutables" failed.

#手动检查进程110745
ps -ef|grep 110745

fuser /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
fuser /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so

#都没有发现

#此时在第一个报错的窗口执行opatchauto resume恢复正常执行完毕
cd /u01/app/oracle/product/19.0.0/db_1/OPatch/

./opatchauto resume

--------------------------------------------------------

#k8s-rac02

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/oracle/product/19.0.0/db_1 

#k8s-rac02约33分钟(最长85 minutes, 13 seconds)

 
#检查补丁情况
su - oracle
cd $ORACLE_HOME/OPatch
./opatch lspatches  


[oracle@k8s-rac01 OPatch]$ ./opatch lspatches
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)

OPatch succeeded.


[oracle@k8s-rac02 OPatch]$ ./opatch lspatches
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)

OPatch succeeded.
```

#单实例执行

```bash
su - root

#在非/和/root目录下执行

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.20patch/35320081 -oh /u01/app/oracle/product/19.0.0/db_1

#k8s-rac01约25分钟 
-------------------------------------------------------

#第一次执行报错：

Patch: /opt/opa/35319490/35320081
Log: /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatchauto/core/opatch/opatch2023-10-10_17-11-02PM_1.log
Reason: Failed during Patching: oracle.opatch.opatchsdk.OPatchException: Prerequisite check "CheckActiveFilesAndExecutables" failed.
After fixing the cause of failure Run opatchauto resume
#查看日志：

Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1 PID( 110745 )
Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so PID( 110745 )
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so
[Oct 10, 2023 5:11:47 PM] [SEVERE]  OUI-67073:UtilSession failed: Prerequisite check "CheckActiveFilesAndExecutables" failed.

#手动检查进程110745
ps -ef|grep 110745

fuser /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
fuser /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so

#都没有发现

#此时在第一个报错的窗口执行opatchauto resume恢复正常执行完毕
cd /u01/app/oracle/product/19.0.0/db_1/OPatch/

./opatchauto resume

--------------------------------------------------------

#k8s-rac02

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/oracle/product/19.0.0/db_1 

#k8s-rac02约33分钟(最长85 minutes, 13 seconds)

 
#检查补丁情况
su - oracle
cd $ORACLE_HOME/OPatch
./opatch lspatches  


[oracle@k8s-rac01 OPatch]$ ./opatch lspatches
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)

OPatch succeeded.


[oracle@k8s-rac02 OPatch]$ ./opatch lspatches
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)

OPatch succeeded.
```

##### 7.1.10.1.单实例直接升级补丁----oracle用户下执行

```bash
# su - oracle
# cd <PATCH_TOP_DIR> 35320081
# opatch apply
```

#logs

```bash
[oracle@k8s-oracle-store ~]$ cd /opt/19.20patch/35320081/
[oracle@k8s-oracle-store 35320081]$ $ORACLE_HOME/OPatch/opatch apply
Oracle Interim Patch Installer version 12.2.0.1.37
Copyright (c) 2024, Oracle Corporation.  All rights reserved.


Oracle Home       : /u01/app/oracle/product/19.0.0/db_1
Central Inventory : /u01/app/oraInventory
   from           : /u01/app/oracle/product/19.0.0/db_1/oraInst.loc
OPatch version    : 12.2.0.1.37
OUI version       : 12.2.0.7.0
Log file location : /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/opatch2024-01-05_11-29-58AM_1.log

Verifying environment and performing prerequisite checks...
OPatch continues with these patches:   35320081  

Do you want to proceed? [y|n]
y
User Responded with: Y
All checks passed.

Please shutdown Oracle instances running out of this ORACLE_HOME on the local system.
(Oracle Home = '/u01/app/oracle/product/19.0.0/db_1')


Is the local system ready for patching? [y|n]
y
User Responded with: Y
Backing up files...
Applying interim patch '35320081' to OH '/u01/app/oracle/product/19.0.0/db_1'
ApplySession: Optional component(s) [ oracle.network.gsm, 19.0.0.0.0 ] , [ oracle.rdbms.ic, 19.0.0.0.0 ] , [ oracle.rdbms.tg4db2, 19.0.0.0.0 ] , [ oracle.tfa, 19.0.0.0.0 ] , [ oracle.rdbms.tg4msql, 19.0.0.0.0 ] , [ oracle.options.olap, 19.0.0.0.0 ] , [ oracle.ons.cclient, 19.0.0.0.0 ] , [ oracle.network.cman, 19.0.0.0.0 ] , [ oracle.rdbms.tg4ifmx, 19.0.0.0.0 ] , [ oracle.rdbms.tg4sybs, 19.0.0.0.0 ] , [ oracle.net.cman, 19.0.0.0.0 ] , [ oracle.rdbms.tg4tera, 19.0.0.0.0 ] , [ oracle.sdo.companion, 19.0.0.0.0 ] , [ oracle.oid.client, 19.0.0.0.0 ] , [ oracle.xdk.companion, 19.0.0.0.0 ] , [ oracle.ons.eons.bwcompat, 19.0.0.0.0 ] , [ oracle.options.olap.api, 19.0.0.0.0 ] , [ oracle.jdk, 1.8.0.191.0 ]  not present in the Oracle Home or a higher version is found.

Patching component oracle.rdbms, 19.0.0.0.0...

Patching component oracle.rdbms.util, 19.0.0.0.0...

Patching component oracle.rdbms.rsf, 19.0.0.0.0...

Patching component oracle.assistants.acf, 19.0.0.0.0...

Patching component oracle.assistants.deconfig, 19.0.0.0.0...

Patching component oracle.assistants.server, 19.0.0.0.0...

Patching component oracle.blaslapack, 19.0.0.0.0...

Patching component oracle.buildtools.rsf, 19.0.0.0.0...

Patching component oracle.ctx, 19.0.0.0.0...

Patching component oracle.dbdev, 19.0.0.0.0...

Patching component oracle.dbjava.ic, 19.0.0.0.0...

Patching component oracle.dbjava.jdbc, 19.0.0.0.0...

Patching component oracle.dbjava.ucp, 19.0.0.0.0...

Patching component oracle.duma, 19.0.0.0.0...

Patching component oracle.javavm.client, 19.0.0.0.0...

Patching component oracle.ldap.owm, 19.0.0.0.0...

Patching component oracle.ldap.rsf, 19.0.0.0.0...

Patching component oracle.ldap.security.osdt, 19.0.0.0.0...

Patching component oracle.marvel, 19.0.0.0.0...

Patching component oracle.network.rsf, 19.0.0.0.0...

Patching component oracle.odbc.ic, 19.0.0.0.0...

Patching component oracle.ons, 19.0.0.0.0...

Patching component oracle.ons.ic, 19.0.0.0.0...

Patching component oracle.oracore.rsf, 19.0.0.0.0...

Patching component oracle.perlint, 5.28.1.0.0...

Patching component oracle.precomp.common.core, 19.0.0.0.0...

Patching component oracle.precomp.rsf, 19.0.0.0.0...

Patching component oracle.rdbms.crs, 19.0.0.0.0...

Patching component oracle.rdbms.dbscripts, 19.0.0.0.0...

Patching component oracle.rdbms.deconfig, 19.0.0.0.0...

Patching component oracle.rdbms.oci, 19.0.0.0.0...

Patching component oracle.rdbms.rsf.ic, 19.0.0.0.0...

Patching component oracle.rdbms.scheduler, 19.0.0.0.0...

Patching component oracle.rhp.db, 19.0.0.0.0...

Patching component oracle.sdo, 19.0.0.0.0...

Patching component oracle.sdo.locator.jrf, 19.0.0.0.0...

Patching component oracle.sqlplus, 19.0.0.0.0...

Patching component oracle.sqlplus.ic, 19.0.0.0.0...

Patching component oracle.wwg.plsql, 19.0.0.0.0...

Patching component oracle.xdk.parser.java, 19.0.0.0.0...

Patching component oracle.ldap.ssl, 19.0.0.0.0...

Patching component oracle.ctx.rsf, 19.0.0.0.0...

Patching component oracle.rdbms.dv, 19.0.0.0.0...

Patching component oracle.rdbms.drdaas, 19.0.0.0.0...

Patching component oracle.network.client, 19.0.0.0.0...

Patching component oracle.rdbms.hsodbc, 19.0.0.0.0...

Patching component oracle.network.listener, 19.0.0.0.0...

Patching component oracle.ldap.rsf.ic, 19.0.0.0.0...

Patching component oracle.dbtoolslistener, 19.0.0.0.0...

Patching component oracle.nlsrtl.rsf, 19.0.0.0.0...

Patching component oracle.xdk.xquery, 19.0.0.0.0...

Patching component oracle.rdbms.install.common, 19.0.0.0.0...

Patching component oracle.ovm, 19.0.0.0.0...

Patching component oracle.oraolap, 19.0.0.0.0...

Patching component oracle.rdbms.rman, 19.0.0.0.0...

Patching component oracle.install.deinstalltool, 19.0.0.0.0...

Patching component oracle.rdbms.install.plugins, 19.0.0.0.0...

Patching component oracle.rdbms.lbac, 19.0.0.0.0...

Patching component oracle.sdo.locator, 19.0.0.0.0...

Patching component oracle.oraolap.dbscripts, 19.0.0.0.0...

Patching component oracle.oraolap.api, 19.0.0.0.0...

Patching component oracle.ctx.atg, 19.0.0.0.0...

Patching component oracle.javavm.server, 19.0.0.0.0...

Patching component oracle.rdbms.hs_common, 19.0.0.0.0...

Patching component oracle.xdk, 19.0.0.0.0...

Patching component oracle.xdk.rsf, 19.0.0.0.0...

Patching component oracle.ldap.client, 19.0.0.0.0...

Patching component oracle.mgw.common, 19.0.0.0.0...

Patching component oracle.odbc, 19.0.0.0.0...

Patching component oracle.precomp.lang, 19.0.0.0.0...

Patching component oracle.precomp.common, 19.0.0.0.0...

Patching component oracle.jdk, 1.8.0.201.0...
Patch 35320081 successfully applied.
Sub-set patch [29517242] has become inactive due to the application of a super-set patch [35320081].
Please refer to Doc ID 2161861.1 for any possible further required actions.
Log file location: /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/opatch2024-01-05_11-29-58AM_1.log

OPatch succeeded.



```

##### 7.1.10.2.Load Modified SQL Files into the Database

```bash
lsnrctl start

sqlplus / as sysdba
startup
show pdbs;

alter pluggable database all open;
show pdbs;

quit

cd $ORACLE_HOME/OPatch
./datapatch -verbose
```

#logs

```bash
[oracle@k8s-oracle-store 35320081]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Jan 5 11:50:24 2024
Version 19.20.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

Connected to an idle instance.

SQL> startup;
ORACLE instance started.

Total System Global Area 1.6106E+10 bytes
Fixed Size		   18625040 bytes
Variable Size		 2181038080 bytes
Database Buffers	 1.3892E+10 bytes
Redo Buffers		   14925824 bytes
Database mounted.
Database opened.
SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 TESTPDB			  READ WRITE NO
SQL> exit   
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.20.0.0.0
[oracle@k8s-oracle-store 35320081]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-oracle-store OPatch]$ cd -
/opt/19.20patch/35320081
[oracle@k8s-oracle-store 35320081]$ $ORACLE_HOME/OPatch/datapatch -verbose
SQL Patching tool version 19.20.0.0.0 Production on Fri Jan  5 11:51:58 2024
Copyright (c) 2012, 2023, Oracle.  All rights reserved.

Log file for this invocation: /u01/app/oracle/cfgtoollogs/sqlpatch/sqlpatch_31544_2024_01_05_11_51_58/sqlpatch_invocation.log

Connecting to database...OK
Gathering database info...done

Note:  Datapatch will only apply or rollback SQL fixes for PDBs
       that are in an open state, no patches will be applied to closed PDBs.
       Please refer to Note: Datapatch: Database 12c Post Patch SQL Automation
       (Doc ID 1585822.1)

Bootstrapping registry and package to current versions...done
Determining current state...done

Current state of interim SQL patches:
  No interim patches found

Current state of release update SQL patches:
  Binary registry:
    19.20.0.0.0 Release_Update 230715022800: Installed
  PDB CDB$ROOT:
    Applied 19.3.0.0.0 Release_Update 190410122720 successfully on 04-JAN-24 05.24.45.204786 PM
  PDB PDB$SEED:
    Applied 19.3.0.0.0 Release_Update 190410122720 successfully on 04-JAN-24 05.33.24.224149 PM
  PDB TESTPDB:
    Applied 19.3.0.0.0 Release_Update 190410122720 successfully on 04-JAN-24 05.33.24.224149 PM

Adding patches to installation queue and performing prereq checks...done
Installation queue:
  For the following PDBs: CDB$ROOT PDB$SEED TESTPDB
    No interim patches need to be rolled back
    Patch 35320081 (Database Release Update : 19.20.0.0.230718 (35320081)):
      Apply from 19.3.0.0.0 Release_Update 190410122720 to 19.20.0.0.0 Release_Update 230715022800
    No interim patches need to be applied

Installing patches...
Patch installation complete.  Total patches installed: 3

Validating logfiles...done
Patch 35320081 apply (pdb CDB$ROOT): SUCCESS
  logfile: /u01/app/oracle/cfgtoollogs/sqlpatch/35320081/25314491/35320081_apply_XYDBDG_CDBROOT_2024Jan05_11_54_06.log (no errors)
Patch 35320081 apply (pdb PDB$SEED): SUCCESS
  logfile: /u01/app/oracle/cfgtoollogs/sqlpatch/35320081/25314491/35320081_apply_XYDBDG_PDBSEED_2024Jan05_12_07_48.log (no errors)
Patch 35320081 apply (pdb TESTPDB): SUCCESS
  logfile: /u01/app/oracle/cfgtoollogs/sqlpatch/35320081/25314491/35320081_apply_XYDBDG_TESTPDB_2024Jan05_12_07_50.log (no errors)

Automatic recompilation incomplete; run utlrp.sql to revalidate.
  PDBs: CDB$ROOT PDB$SEED TESTPDB

SQL Patching tool complete on Fri Jan  5 12:18:31 2024

```

##### 

##### 7.1.10.3.升级后，查看版本变化及处理无效对象

```bash
#完成后检查patch情况

set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;


col status for a10
col action for a10
col action_time for a30
col description for a60

select patch_id,patch_type,action,status,action_time,description from dba_registry_sqlpatch;

col version for a25
col comments for a80

select ACTION_TIME,VERSION,COMMENTS from dba_registry_history;



#编译无效对象---cdb/pdb全部执行

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73500
INVALID        286


SQL> @$ORACLE_HOME/rdbms/admin/utlrp.sql

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73786

```



#logs

```
SQL> select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION	      STATUS	      TARGET_VERSION
---------- ---------- --------------- --------------- ---------------
  29517242 RU	      APPLY	      SUCCESS	      19.3.0.0.0
  35320081 RU	      APPLY	      SUCCESS	      19.20.0.0.0

SQL> 

SQL> select patch_id,patch_type,action,status,action_time,description from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION	 STATUS     ACTION_TIME 		   DESCRIPTION
---------- ---------- ---------- ---------- ------------------------------ ------------------------------------------------------------
  29517242 RU	      APPLY	 SUCCESS    04-JAN-24 05.24.45.204786 PM   Database Release Update : 19.3.0.0.190416 (29517242)
  35320081 RU	      APPLY	 SUCCESS    05-JAN-24 12.17.58.133923 PM   Database Release Update : 19.20.0.0.230718 (35320081)

SQL> 

SQL> select ACTION_TIME,VERSION,COMMENTS from dba_registry_history;

ACTION_TIME		       VERSION			 COMMENTS
------------------------------ ------------------------- --------------------------------------------------------------------------------
			       19			 RDBMS_19.20.0.0.0DBRU_LINUX.X64_230621
04-JAN-24 05.24.36.473920 PM   19.0.0.0.0		 Patch applied on 19.3.0.0.0: Release_Update - 190410122720
05-JAN-24 12.07.30.610435 PM   19.0.0.0.0		 Patch applied from 19.3.0.0.0 to 19.20.0.0.0: Release_Update - 230715022800

SQL> 

SQL> select status,count(*) from dba_objects group by status;

STATUS	     COUNT(*)
---------- ----------
VALID		72819
INVALID 	  285

SQL>  @$ORACLE_HOME/rdbms/admin/utlrp.sql

Session altered.
..................................
Function created.


PL/SQL procedure successfully completed.


Function dropped.


PL/SQL procedure successfully completed.

SQL>  select status,count(*) from dba_objects group by status;

STATUS	     COUNT(*)
---------- ----------
VALID		73104

SQL> 



```





#### 7.1.11.升级后动作 after patch---单实例不再执行

```bash
#(1)
#仅节点1---直接启动全部pdb后，用oracle用户执行datapatch -verbose

su - oracle
sqlplus / as sysdba
show pdbs;
exit

#确认全部pdb已经启动后
cd $ORACLE_HOME/OPatch
./datapatch -verbose


[oracle@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-rac01 OPatch]$ ./datapatch -verbose 

#执行前确认两个节点pdb都打开，如果pdb没有打开 可能会出现cdb和pdb RU不一致，
#导致pdb受限。如果pdb没有更新 可以使用这个命令强制更新ru

 datapatch -verbose -apply  ru_id -force -pdbs PDB1

#(2)
#编译无效对象---cdb/pdb全部执行

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73500
INVALID        286


SQL> @$ORACLE_HOME/rdbms/admin/utlrp.sql

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73786



 

#完成后检查patch情况

set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

 
SQL> select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION	      STATUS	      TARGET_VERSION
---------- ---------- --------------- --------------- ---------------
  29517242 RU	      APPLY	      SUCCESS	      19.3.0.0.0
  35320081 RU	      APPLY	      SUCCESS	      19.20.0.0.0


SQL>  select  PATCH_UID,PATCH_ID,ACTION,STATUS,ACTION_TIME ,DESCRIPTION,TARGET_VERSION from dba_registry_sqlpatch;

PATCH_UID   PATCH_ID ACTION          STATUS                    ACTION_TIME                    DESCRIPTION                                             TARGET_VERSION

---------- ---------- --------------- ------------------------- ------------------------------ ------------------------------------------------------- ---------------

  22862832   29517242 APPLY           SUCCESS                   28-SEP-23 01.07.44.077637 PM   Database Release Update : 19.3.0.0.190416 (29517242)    19.3.0.0.0
  25314491   35320081 APPLY           SUCCESS                   10-OCT-23 06.30.55.798713 PM   Database Release Update : 19.20.0.0.230718 (35320081)   19.20.0.0.0
  
  
--------------------------------------------------
#根据升级文档，datapatch操作可以在全部pdb开启后执行，不再按以下步骤执行

opatch lspatches

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP

SQL> alter system set cluster_database=false scope=spfile;  --设置接非集群

 

srvctl stop db -d dbname  

 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP UPGRADE

如果使用了pdb  请确认pdb 全部open

alter pluggable database  all open;


[oracle@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-rac01 OPatch]$ ./datapatch -verbose 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> alter system set cluster_database=true scope=spfile sid='*';

SQL> SHUTDOWN

srvctl start database -d dbname

--------------------------------------------------
```

### 7.2.接着打19.21 RAC RU---执行过程同7.1---单实例DB不执行

#补丁列表

|                             Name                             |  Download Link   |
| :----------------------------------------------------------: | :--------------: |
|           Database Release Update 19.21.0.0.231017           | <Patch 35643107> |
|     Grid Infrastructure Release Update 19.21.0.0.231017      | <Patch 35642822> |
|             OJVM Release Update 19.21.0.0.231017             | <Patch 35648110> |
|  (there were no OJVM Release Update Revisions for Oct 2023)  |                  |
| Microsoft Windows 32-Bit & x86-64 Bundle Patch 19.21.0.0.231017 | <Patch 35681552> |



```
#补丁位置：---k8s-rac01/k8s-rac02都一样
[oracle@k8s-rac01 opt]$ ls
19.20patch  19.21patch  opa  oracle  oracle.ahf  ORCLfmap
[oracle@k8s-rac01 opt]$ cd 19.21patch/
[oracle@k8s-rac01 19.21patch]$ ll
total 5031608
-rw-r--r-- 1 root root 3084439097 Nov 18 23:00 p35642822_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 1815725977 Nov 18 23:00 p35643107_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root  127350205 Nov 18 23:00 p35648110_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root  124843817 Nov 18 23:00 p6880880_190000_Linux-x86-64.zip

```



#### 7.2.1.检查集群状态

```bash
crsctl status resource -t
```

#集群正常

```bash
[grid@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-rac01 OPatch]$ ./opatch lspatches   
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
35332537;ACFS RELEASE UPDATE 19.20.0.0.0 (35332537)
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.

[grid@k8s-rac01 OPatch]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                Started,STABLE
      2        ONLINE  ONLINE       k8s-rac02                Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac01.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac02.vip
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-rac02                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------

```



#### 7.2.2.更新grid opatch 两个节点 root执行

```bash
#备份opatch
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch_20bak    

#更新opatch
unzip -q /opt/19.21patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/  

chmod -R 755 /u01/app/19.0.0/grid/OPatch

chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

#更新后检查opatch的版本至少12.2.0.1.37
su - grid

[grid@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-rac01 OPatch]$ ./opatch version   

OPatch Version: 12.2.0.1.37
OPatch succeeded.
```



#### 7.2.3.更新oracle opatch 两个节点 root执行

```bash
#备份opatch
mv /u01/app/oracle/product/19.0.0/db_1/OPatch /u01/app/oracle/product/19.0.0/db_1/OPatch.20bak     

unzip -q /opt/19.21patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/db_1/ 

chmod -R 755 /u01/app/oracle/product/19.0.0/db_1/OPatch

chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/db_1/OPatch
```

 

#### 7.2.4.解压patch包 两个节点 root执行

```bash
#这一个包 包含了全部的patch
unzip /opt/19.21patch/p35642822_190000_Linux-x86-64.zip -d /opt/19.21patch/

chown -R grid:oinstall /opt/19.21patch/35642822

chmod -R 755 /opt/19.21patch/35642822

#此时可以查看35642822文件夹下的 README.html，里面有详细的RU步骤
```



#### 7.2.5.兼容性检查

```bash
#OPatch兼容性检查 两个节点 grid用户

 su - grid

/u01/app/19.0.0/grid/OPatch/opatch lsinventory -detail -oh /u01/app/19.0.0/grid/

#OPatch兼容性检查 两个节点 oracle用户

 su - oracle

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatch lsinventory -detail -oh /u01/app/oracle/product/19.0.0/db_1/
```



#### 7.2.6.补丁冲突检查 k8s-rac01/k8s-rac02两个节点都执行

```bash
#子目录的五个patch在grid用户下分别执行检查

su - grid

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35643107

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35655527

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35652062

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35553096

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/33575402


#子目录的一个patch在oracle用户下执行检查

su - oracle


$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35643107

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35655527
```



#### 7.2.7.空间检查 k8s-rac01/k8s-rac02两个节点都执行

```bash
#grid用户执行

su - grid

touch /tmp/1921patch_list_gihome.txt

cat >>  /tmp/1921patch_list_gihome.txt <<EOF
/opt/19.21patch/35642822/35643107
/opt/19.21patch/35642822/35655527
/opt/19.21patch/35642822/35652062
/opt/19.21patch/35642822/35553096
/opt/19.21patch/35642822/33575402
EOF


$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/1921patch_list_gihome.txt


#oracle用户执行

su - oracle

touch /tmp/1921patch_list_dbhome.txt

cat > /tmp/1921patch_list_dbhome.txt <<EOF
/opt/19.21patch/35642822/35643107
/opt/19.21patch/35642822/35655527
EOF

$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/1921patch_list_dbhome.txt
```



#### 7.2.8.补丁分析检查  root用户两个节点都要分别执行 

```bash
su - root

#k8s-rac01:
#k8s-rac01大约2分钟40秒，全部成功(最长有过4分17秒)

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze

#k8s-rac02:
#k8s-rac02大约2分钟40秒，全部成功(最长有过3分48秒)
#可能会有部分失败

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze

-----------------------------
Reason: Failed during Analysis: CheckSystemCommandsAvailable Failed, [ Prerequisite Status: FAILED, Prerequisite output:
The details are:

Missing command :fuser]
---------------------------


#解决办法：
yum install -y psmisc

#k8s-rac02再次检查：
#k8s-rac02大约2分钟40秒，全部成功
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze       
```

#报错分析解决

```bash
[root@k8s-rac01 OPatch]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze 
OPatchauto session is initiated at Wed Nov 22 18:02:38 2023

System initialization log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchautodb/systemconfig2023-11-22_06-02-46PM.log.

Session log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-20PM.log
The id for this session is BY6I

Wrong OPatch software installed in following homes:
Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1

Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1

OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
OPatchAuto failed.

OPatchauto session completed at Wed Nov 22 18:03:51 2023
Time taken to complete the session 1 minute, 6 seconds

 opatchauto failed with error code 42

[root@k8s-rac02 OPatch]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze 
OPatchauto session is initiated at Wed Nov 22 18:02:38 2023

System initialization log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchautodb/systemconfig2023-11-22_06-02-44PM.log.

Session log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-14PM.log
The id for this session is YA4Q

Wrong OPatch software installed in following homes:
Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1

Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1

OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
OPatchAuto failed.

OPatchauto session completed at Wed Nov 22 18:03:38 2023
Time taken to complete the session 0 minute, 54 seconds

 opatchauto failed with error code 42


[root@k8s-rac01 OPatch]# tail -100f /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-20PM.log
2023-11-22 18:03:50,374 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator -  OH  hostname  OH.getPath() /u01/app/oracle/product/19.0.0/db_1
2023-11-22 18:03:51,025 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac01
2023-11-22 18:03:51,025 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac02
2023-11-22 18:03:51,025 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='
Wrong OPatch software installed in following homes:'}
2023-11-22 18:03:51,025 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:51,026 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:51,027 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.DBValidationController - Validation failed due to :OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
2023-11-22 18:03:51,028 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OOPPatchTargetValidator - OOP patch target validation skipped
2023-11-22 18:03:51,190 INFO  [1] com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport - Space available after session: 236574 MB
2023-11-22 18:03:51,267 INFO  [1] com.oracle.glcm.patch.auto.db.framework.core.oplan.IOUtils - Change the permission of the file /u01/app/19.0.0/grid/opatchautocfg/db/sessioninfo/patchingsummary.xmlto 775
2023-11-22 18:03:51,343 SEVERE [1] com.oracle.glcm.patch.auto.OPatchAuto - OPatchAuto failed.
com.oracle.glcm.patch.auto.OPatchAutoException: OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport.loadTopology(DBBaseProductSupport.java:236)
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBProductSupport.loadTopology(DBProductSupport.java:69)
        at com.oracle.glcm.patch.auto.OPatchAuto.loadTopology(OPatchAuto.java:1732)
        at com.oracle.glcm.patch.auto.OPatchAuto.prepareOrchestration(OPatchAuto.java:730)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:397)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:344)
        at com.oracle.glcm.patch.auto.OPatchAuto.main(OPatchAuto.java:212)
2023-11-22 18:03:51,344 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.'}
2023-11-22 18:03:51,344 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPatchAuto failed.'}

[root@k8s-rac02 OPatch]# tail -100f /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-14PM.log
2023-11-22 18:03:38,228 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator -  OH  hostname  OH.getPath() /u01/app/oracle/product/19.0.0/db_1
2023-11-22 18:03:38,731 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac01
2023-11-22 18:03:38,732 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac02
2023-11-22 18:03:38,732 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='
Wrong OPatch software installed in following homes:'}
2023-11-22 18:03:38,732 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:38,733 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:38,735 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.DBValidationController - Validation failed due to :OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
2023-11-22 18:03:38,735 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OOPPatchTargetValidator - OOP patch target validation skipped
2023-11-22 18:03:38,777 INFO  [1] com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport - Space available after session: 242439 MB
2023-11-22 18:03:38,793 INFO  [1] com.oracle.glcm.patch.auto.db.framework.core.oplan.IOUtils - Change the permission of the file /u01/app/19.0.0/grid/opatchautocfg/db/sessioninfo/patchingsummary.xmlto 775
2023-11-22 18:03:38,810 SEVERE [1] com.oracle.glcm.patch.auto.OPatchAuto - OPatchAuto failed.
com.oracle.glcm.patch.auto.OPatchAutoException: OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport.loadTopology(DBBaseProductSupport.java:236)
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBProductSupport.loadTopology(DBProductSupport.java:69)
        at com.oracle.glcm.patch.auto.OPatchAuto.loadTopology(OPatchAuto.java:1732)
        at com.oracle.glcm.patch.auto.OPatchAuto.prepareOrchestration(OPatchAuto.java:730)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:397)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:344)
        at com.oracle.glcm.patch.auto.OPatchAuto.main(OPatchAuto.java:212)
2023-11-22 18:03:38,811 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.'}
2023-11-22 18:03:38,811 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPatchAuto failed.'}


#调查分析：grid用户和oracle用户用的opatch不是一个版本
#原来grid用户用的是19.20的opatch，版本是；12.2.0.1.39；而oracle用户用的是19.20的opatch，版本是；12.2.0.1.37
#全部改为19.21的opatch后，通过！
```



#### 7.2.9.grid 升级 root两个节点都要分别执行 --grid upgrade

```bash
su - root

#k8s-rac01约15分钟(最长有过80分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/19.0.0/grid   

#k8s-rac02约20分钟(最长有过60分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/19.0.0/grid   
#报错后可以再次执行


#升级后的状态
su - grid
cd $ORACLE_HOME/OPatch

[grid@k8s-rac01 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35652062;ACFS RELEASE UPDATE 19.21.0.0.0 (35652062)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.


[grid@k8s-rac02 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35652062;ACFS RELEASE UPDATE 19.21.0.0.0 (35652062)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.

```

#错误处理

```bash
#(0)
#不能在/root或/目录下执行，否则报错：
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   

Invalid current directory.  Please run opatchauto from other than '/root' or '/' directory.
And check if the home owner user has write permission set for the current directory.
opatchauto returns with error code = 2
------------------------------------------------------------------------
#(1)
#GI因为共享磁盘的UUID变化，没起来

CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-1705: Found 1 configured voting files but 2 voting files are required, terminating to ensure data integrity; details at (:CSSNM00021:) in /u01/app/grid/diag/crs/k8s-rac02/crs/trace/ocssd.trc
CRS-2883: Resource 'ora.cssd' failed during Clusterware stack start.
CRS-4406: Oracle High Availability Services synchronous start failed.
CRS-41053: checking Oracle Grid Infrastructure for file permission issues
PRVH-0116 : Path "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" with permissions "rw-r--r--" does not have execute permissions for the owner, file's group, and others on node "k8s-rac02".
PRVG-2031 : Owner of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-rac02". [Expected = "grid(11012)" ; Found = "root(0)"]
PRVG-2032 : Group of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-rac02". [Expected = "oinstall(11001)" ; Found = "root(0)"]
CRS-4000: Command Start failed, or completed with errors.
2023/11/19 07:42:47 CLSRSC-117: Failed to start Oracle Clusterware stack 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 07:42:50 2023
Time taken to complete the session 2 minutes, 35 seconds

 opatchauto failed with error code 42
------------------------------------------------------------------------

#(2)
#修复后，发现因为olr无法手动备份，导致报错；估计还是上面共享磁盘的问题

Performing postpatch operations on CRS - starting CRS service on home /u01/app/19.0.0/grid
Postpatch operation log file location: /u01/app/grid/crsdata/k8s-rac02/crsconfig/crs_postpatch_apply_inplace_k8s-rac02_2023-11-19_09-07-00AM.log
Failed to start CRS service on home /u01/app/19.0.0/grid

Execution of [GIStartupAction] patch action failed, check log for more details. Failures:
Patch Target : k8s-rac02->/u01/app/19.0.0/grid Type[crs]
Details: [
---------------------------Patching Failed---------------------------------
Command execution failed during patching in home: /u01/app/19.0.0/grid, host: k8s-rac02.
Command failed:  /u01/app/19.0.0/grid/perl/bin/perl -I/u01/app/19.0.0/grid/perl/lib -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/xag /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install/rootcrs.pl -postpatch
Command failure output: 
Using configuration parameter file: /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crs_postpatch_apply_inplace_k8s-rac02_2023-11-19_09-07-00AM.log
2023/11/19 09:07:16 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
Oracle Clusterware active version on the cluster is [19.0.0.0.0]. The cluster upgrade state is [NORMAL]. The cluster active patch level is [3976270074].
CRS-2672: Attempting to start 'ora.drivers.acfs' on 'k8s-rac02'
CRS-2676: Start of 'ora.drivers.acfs' on 'k8s-rac02' succeeded
2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 09:10:12 2023
Time taken to complete the session 25 minutes, 5 seconds

 opatchauto failed with error code 42
[root@k8s-rac02 35319490]# 

#发现错误是2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 
#手动执行，发现确实报错
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup manual

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 ~]# ll /u01/app/grid/crsdata/k8s-rac02/olr
total 495048
-rw-r--r-- 1 root root       1101824 Nov 18 18:49 autobackup_20231118_184948.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:35 backup_20231118_183548.olr
-rw------- 1 root oinstall 503484416 Nov 19 11:54 k8s-rac02_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 08:46 k8s-rac02_19.olr.bkp.patch
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup
PROTL-23: failed to back up Oracle Local Registry
PROCL-60: The Oracle Local Registry backup file '/u01/app/grid/crsdata/k8s-rac02/olr/backup_20231119_121545.olr' is corrupt.

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83168
	 Available space (kbytes) :     408516
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed


#但在k8s-rac01上手动备份没问题
[root@k8s-rac01 ContentsXML]# ocrconfig -local -manualbackup

k8s-rac01     2023/11/19 12:12:49     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231119_121249.olr     3976270074     

k8s-rac01     2023/11/19 01:25:37     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231119_012537.olr     3976270074     

k8s-rac01     2023/11/18 18:27:53     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231118_182753.olr     724960844     
[root@k8s-rac01 ContentsXML]# ll /u01/app/grid/crsdata/k8s-rac01/olr/
total 498160
-rw-r--r-- 1 root root       1114112 Nov 18 18:39 autobackup_20231118_183942.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:27 backup_20231118_182753.olr
-rw------- 1 root root       1150976 Nov 19 01:25 backup_20231119_012537.olr
-rw------- 1 root root       1593344 Nov 19 12:12 backup_20231119_121249.olr
-rw------- 1 root oinstall 503484416 Nov 19 12:12 k8s-rac01_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 00:11 k8s-rac01_19.olr.bkp.patch
[root@k8s-rac01 ~]#  /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83444
	 Available space (kbytes) :     408240
	 ID                       : 1567972045
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac01/olr/k8s-rac01_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#k8s-rac02，如果此时关闭cluster，将无法启动，特别是ora.asm/ora.OCR.dg(ora.asmgroup)/ora.DATA.dg(ora.asmgroup)/ora.FRA.dg(ora.asmgroup)等无法启动，但是vip/LISTENER等其他组件正常

[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
===== Summary of resource auto-start failures follows =====
CRS-2807: Resource 'ora.asmgroup' failed to start automatically.
CRS-2807: Resource 'ora.xydb.db' failed to start automatically.
CRS-2807: Resource 'ora.xydb.s_stuwork.svc' failed to start automatically.
CRS-6016: Resource auto-start has completed for server k8s-rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                Started,STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac01.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac02.vip
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  OFFLINE                               STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
--------------------------------------------------------------------------------


#此时对olr进行restore处理
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-rac02     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr     724960844

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     

#再次检查ocrcheck -local，发现为succeeded
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck 
PROT-602: Failed to retrieve data from the cluster registry
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 trace]# 

------------------------------------------------------------------------
#(3)
#但是此时再次启动cluster报错，因为还原了Olr后与已经打的补丁不一致
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start cluster
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl check crs
CRS-4639: Could not contact Oracle High Availability Services

[root@k8s-rac02 dispatcher.d]# ps -ef|grep grid|grep app|awk '{print $2}'|xargs kill -9

[root@k8s-rac02 dispatcher.d]# ps -ef|grep grid
root     14717 11600  0 11:51 pts/4    00:00:00 grep --color=auto grid
root     26985 11598  0 Nov21 pts/2    00:00:00 su - grid
grid     26987 26985  0 Nov21 pts/2    00:00:00 -bash
grid     29819 26987  0 Nov21 pts/2    00:00:00 tail -100f alert_+ASM2.log


[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.

#解决办法：

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -unlock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crsunlock_k8s-rac02_2023-11-22_11-54-32AM.log
2023/11/22 11:54:33 CLSRSC-4012: Shutting down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:56 CLSRSC-4013: Successfully shut down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:58 CLSRSC-347: Successfully unlock /u01/app/19.0.0/grid

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/clscfg -localpatch
clscfg: EXISTING configuration version 0 detected.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -lock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crslock_k8s-rac02_2023-11-22_11-58-45AM.log
2023/11/22 11:58:52 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-33676: Start of resource group 'ora.asmgroup' on server 'k8s-rac02' succeeded.
CRS-2672: Attempting to start 'ora.FRA.dg' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.DATA.dg' on 'k8s-rac02'
CRS-2676: Start of 'ora.FRA.dg' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.DATA.dg' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-2676: Start of 'ora.xydb.db' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.s_stuwork.svc' on 'k8s-rac02'
CRS-2676: Start of 'ora.xydb.s_stuwork.svc' on 'k8s-rac02' succeeded
CRS-6016: Resource auto-start has completed for server k8s-rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-rac02 ~]# 

[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
Status of Oracle Cluster Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      84460
	 Available space (kbytes) :     407224
	 ID                       : 1399819439
	 Device/File Name         :       +OCR
                                    Device/File integrity check succeeded

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

	 Cluster registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83152
	 Available space (kbytes) :     408532
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#再次手动备份也正常了
[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup

k8s-rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844    

#再次打补丁

```



#### 7.2.10.oracle 升级 root两个节点都要分别执行 --oracle upgrade

```bash
su - root

#k8s-rac01
#在非/和/root目录下执行

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/oracle/product/19.0.0/db_1

#k8s-rac01约25分钟 
-------------------------------------------------------

#第一次执行报错：

Patch: /opt/opa/35319490/35320081
Log: /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatchauto/core/opatch/opatch2023-10-10_17-11-02PM_1.log
Reason: Failed during Patching: oracle.opatch.opatchsdk.OPatchException: Prerequisite check "CheckActiveFilesAndExecutables" failed.
After fixing the cause of failure Run opatchauto resume
#查看日志：

Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1 PID( 110745 )
Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so PID( 110745 )
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so
[Oct 10, 2023 5:11:47 PM] [SEVERE]  OUI-67073:UtilSession failed: Prerequisite check "CheckActiveFilesAndExecutables" failed.

#手动检查进程110745
ps -ef|grep 110745

fuser /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
fuser /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so

#都没有发现

#此时在第一个报错的窗口执行opatchauto resume恢复正常执行完毕
cd /u01/app/oracle/product/19.0.0/db_1/OPatch/

./opatchauto resume

--------------------------------------------------------

#k8s-rac02

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/oracle/product/19.0.0/db_1 

#k8s-rac02约33分钟(最长85 minutes, 13 seconds)

 
#检查补丁情况
su - oracle
cd $ORACLE_HOME/OPatch
./opatch lspatches  


[oracle@k8s-rac01 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)

OPatch succeeded.


[oracle@k8s-rac02 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)

OPatch succeeded.
```





#### 7.2.11.升级后动作 after patch

```bash
#(1)
#仅节点1---直接启动全部pdb后，用oracle用户执行datapatch -verbose

su - oracle
sqlplus / as sysdba
show pdbs;
exit

#确认全部pdb已经启动后
cd $ORACLE_HOME/OPatch

#可选
./datapatch -sanity_checks

#执行
./datapatch -verbose


[oracle@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-rac01 OPatch]$ ./datapatch -sanity_checks 
[oracle@k8s-rac01 OPatch]$ ./datapatch -verbose 

#执行前确认两个节点pdb都打开，如果pdb没有打开 可能会出现cdb和pdb RU不一致，
#导致pdb受限。如果pdb没有更新 可以使用这个命令强制更新ru

 datapatch -verbose -apply  ru_id -force -pdbs PDB1

#(2)
#编译无效对象---cdb/pdb全部执行

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73500
INVALID        286


SQL> @$ORACLE_HOME/rdbms/admin/utlrp.sql

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73786



 

#完成后检查patch情况

set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

 
SQL> select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION          STATUS          TARGET_VERSION
---------- ---------- --------------- --------------- ---------------
  29517242 RU         APPLY           SUCCESS         19.3.0.0.0
  35320081 RU         APPLY           SUCCESS         19.20.0.0.0
  35643107 RU         APPLY           SUCCESS         19.21.0.0.0



SQL>  select  PATCH_UID,PATCH_ID,ACTION,STATUS,ACTION_TIME ,DESCRIPTION,TARGET_VERSION from dba_registry_sqlpatch;
  
 PATCH_UID   PATCH_ID ACTION          STATUS          ACTION_TIME
---------- ---------- --------------- --------------- ---------------------------------------------------------------------------
DESCRIPTION                                                                                          TARGET_VERSION
---------------------------------------------------------------------------------------------------- ---------------
  22862832   29517242 APPLY           SUCCESS         18-NOV-23 07.31.46.746877 PM
Database Release Update : 19.3.0.0.190416 (29517242)                                                 19.3.0.0.0

  25314491   35320081 APPLY           SUCCESS         22-NOV-23 02.53.28.041848 PM
Database Release Update : 19.20.0.0.230718 (35320081)                                                19.20.0.0.0

  25405995   35643107 APPLY           SUCCESS         22-NOV-23 11.53.49.603359 PM
Database Release Update : 19.21.0.0.231017 (35643107)                                                19.21.0.0.0


[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl query crs releasepatch
Oracle Clusterware release patch level is [2204791795] and the complete list of patches [33575402 35553096 35643107 35652062 35655527 ] have been applied on the local node. The release patch string is [19.21.0.0.0].

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl query css votedisk
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   dd0f67278ca64f02bf1be1f5476c5897 (/dev/sda) [OCR]
 2. ONLINE   0c98d89348b64f12bf7a4d996fdaff4f (/dev/sdb) [OCR]
 3. ONLINE   a4df36e0ad924f5abff76c6389c32ea8 (/dev/sdc) [OCR]

#常用集群检查命令
#grid用户
cluvfy  stage -post crsinst -n k8s-rac01,k8s-rac02 -verbose 
cluvfy comp software  
cluvfy comp sys -allnodes -p crs -verbose
cluvfy comp healthcheck -collect cluster -html
#u01/app/19.0.0/grid/cv/report/html/

asmcmd lsdsk -k
kfed read /dev/sda | grep name


  
--------------------------------------------------
#根据升级文档，datapatch操作可以在全部pdb开启后执行，不再按以下步骤执行

opatch lspatches

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP

SQL> alter system set cluster_database=false scope=spfile;  --设置接非集群

 

srvctl stop db -d dbname  

 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP UPGRADE

如果使用了pdb  请确认pdb 全部open

alter pluggable database  all open;


[oracle@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-rac01 OPatch]$ ./datapatch -verbose 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> alter system set cluster_database=true scope=spfile sid='*';

SQL> SHUTDOWN

srvctl start database -d dbname

--------------------------------------------------
```



### 7.3 19.21 DB单实例RU---执行过程同7.1

#补丁列表

|                   Name                   |  Download Link   |
| :--------------------------------------: | :--------------: |
| Database Release Update 19.21.0.0.231017 | <Patch 35643107> |

#单实例的话，只需要19.20.0 DB--->19.21.0 DB 即可
#If this is not a RAC environment, shut down all instances and listeners associated with the Oracle home that you are updating.

#单实例打补丁，必须关闭待升级ORACLE HOME关联的所有实例和监听，并且包括退出所有的sqlplus窗口

```bash
su - oracle

$ lsnrctl stop

$ sqlplus / as sysdba

shutdown immediate;
exit
```



#更新oracle opatch --- root执行

```bash
mv /u01/app/oracle/product/19.0.0/db_1/OPatch /u01/app/oracle/product/19.0.0/db_1/OPatch.old     

unzip -q /opt/19.21patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/db_1/ 

chmod -R 755 /u01/app/oracle/product/19.0.0/db_1/OPatch

chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/db_1/OPatch

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatch lsinventory -detail -oh /u01/app/oracle/product/19.0.0/db_1/
```



#解压patch包 --- root执行

```bash
unzip -q /opt/19.21patch/p35643107_190000_Linux-x86-64.zip -d /opt/19.21patch/
chown -R oracle:oinstall /opt/19.21patch/35643107
chmod -R 755 /opt/19.21patch/35643107
```



#补丁冲突检查 --- oracle用户执行

```bash
#cd /opt/19.21patch/35643107

#$ORACLE_HOME/OPatch/opatch prereq 

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35643107
```



#补丁升级

```bash
# su - oracle
# cd <PATCH_TOP_DIR> 35643107
# opatch apply
$ORACLE_HOME/OPatch/opatch apply
```



#Load Modified SQL Files into the Database

```bash
lsnrctl start

sqlplus / as sysdba
startup
show pdbs;

alter pluggable database all open;
show pdbs;

quit


cd $ORACLE_HOME/OPatch
./datapatch -verbose
```





#升级后，查看版本变化及处理无效对象

```bash
#完成后检查patch情况

set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;


col status for a10
col action for a10
col action_time for a30
col description for a60

select patch_id,patch_type,action,status,action_time,description from dba_registry_sqlpatch;

col version for a25
col comments for a80

select ACTION_TIME,VERSION,COMMENTS from dba_registry_history;



#编译无效对象---cdb/pdb全部执行

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73500
INVALID        286


SQL> @$ORACLE_HOME/rdbms/admin/utlrp.sql

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73786

```







#执行过程logs

```bash
[oracle@k8s-oracle-store ~]$ lsnrctl stop

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 06-JAN-2024 13:50:34

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
The command completed successfully

[oracle@k8s-oracle-store ~]$ sqlplus / as sysdba

SQL> shutdown immediate;
Database closed.
Database dismounted.
ORACLE instance shut down.
SQL> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.20.0.0.0


[oracle@k8s-oracle-store OPatch]$ /u01/app/oracle/product/19.0.0/db_1/OPatch/opatch lsinventory -detail -oh /u01/app/oracle/product/19.0.0/db_1/
Oracle Interim Patch Installer version 12.2.0.1.37
Copyright (c) 2024, Oracle Corporation.  All rights reserved.

Oracle Home       : /u01/app/oracle/product/19.0.0/db_1
Central Inventory : /u01/app/oraInventory
   from           : /u01/app/oracle/product/19.0.0/db_1//oraInst.loc
OPatch version    : 12.2.0.1.37
OUI version       : 12.2.0.7.0
Log file location : /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/opatch2024-01-06_13-51-22PM_1.log

Lsinventory Output file location : /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/lsinv/lsinventory2024-01-06_13-51-22PM.txt
--------------------------------------------------------------------------------
Local Machine Information::
Hostname: k8s-oracle-store
ARU platform id: 226
ARU platform description:: Linux x86-64

Installed Top-level Products (1):

Oracle Database 19c                                                  19.0.0.0.0
There are 1 products installed in this Oracle Home.


Installed Products (128):

Assistant Common Files                                               19.0.0.0.0
BLASLAPACK Component                                                 19.0.0.0.0
Buildtools Common Files                                              19.0.0.0.0
Cluster Verification Utility Common Files                            19.0.0.0.0
Cluster Verification Utility DB Files                                19.0.0.0.0
Database Configuration and Upgrade Assistants                        19.0.0.0.0
Database Migration Assistant for Unicode                             19.0.0.0.0
Database SQL Scripts                                                 19.0.0.0.0
Database Workspace Manager                                           19.0.0.0.0
DB TOOLS Listener                                                    19.0.0.0.0
Deinstallation Tool                                                  19.0.0.0.0
Enterprise Edition Options                                           19.0.0.0.0
Expat libraries                                                       2.0.1.0.4
Generic Connectivity Common Files                                    19.0.0.0.0
Hadoopcore Component                                                 19.0.0.0.0
HAS Common Files                                                     19.0.0.0.0
HAS Files for DB                                                     19.0.0.0.0
Installation Common Files                                            19.0.0.0.0
Installation Plugin Files                                            19.0.0.0.0
Installer SDK Component                                              12.2.0.7.0
JAccelerator (COMPANION)                                             19.0.0.0.0
Java Development Kit                                                1.8.0.201.0
LDAP Required Support Files                                          19.0.0.0.0
OLAP SQL Scripts                                                     19.0.0.0.0
Oracle Advanced Analytics                                            19.0.0.0.0
Oracle Advanced Security                                             19.0.0.0.0
Oracle Application Express                                           19.0.0.0.0
Oracle Bali Share                                                    11.1.1.6.0
Oracle Call Interface (OCI)                                          19.0.0.0.0
Oracle Clusterware RDBMS Files                                       19.0.0.0.0
Oracle Context Companion                                             19.0.0.0.0
Oracle Core Required Support Files                                   19.0.0.0.0
Oracle Core Required Support Files for Core DB                       19.0.0.0.0
Oracle Database 19c                                                  19.0.0.0.0
Oracle Database 19c                                                  19.0.0.0.0
Oracle Database 19c Multimedia Files                                 19.0.0.0.0
Oracle Database Deconfiguration                                      19.0.0.0.0
Oracle Database Gateway for ODBC                                     19.0.0.0.0
Oracle Database Provider for DRDA                                    19.0.0.0.0
Oracle Database Utilities                                            19.0.0.0.0
Oracle Database Vault option                                         19.0.0.0.0
Oracle DBCA Deconfiguration                                          19.0.0.0.0
Oracle Extended Windowing Toolkit                                    11.1.1.6.0
Oracle Globalization Support                                         19.0.0.0.0
Oracle Globalization Support                                         19.0.0.0.0
Oracle Globalization Support For Core                                19.0.0.0.0
Oracle Help for Java                                                 11.1.1.7.0
Oracle Help Share Library                                            11.1.1.7.0
Oracle Ice Browser                                                   11.1.1.7.0
Oracle Internet Directory Client                                     19.0.0.0.0
Oracle Java Client                                                   19.0.0.0.0
Oracle JDBC Server Support Package                                   19.0.0.0.0
Oracle JDBC/OCI Instant Client                                       19.0.0.0.0
Oracle JDBC/THIN Interfaces                                          19.0.0.0.0
Oracle JFC Extended Windowing Toolkit                                11.1.1.6.0
Oracle JVM                                                           19.0.0.0.0
Oracle JVM For Core                                                  19.0.0.0.0
Oracle Label Security                                                19.0.0.0.0
Oracle LDAP administration                                           19.0.0.0.0
Oracle Locale Builder                                                19.0.0.0.0
Oracle Message Gateway Common Files                                  19.0.0.0.0
Oracle Multimedia                                                    19.0.0.0.0
Oracle Multimedia Client Option                                      19.0.0.0.0
Oracle Multimedia Java Advanced Imaging                              19.0.0.0.0
Oracle Multimedia Locator                                            19.0.0.0.0
Oracle Multimedia Locator Java Required Support Files                19.0.0.0.0
Oracle Multimedia Locator RDBMS Files                                19.0.0.0.0
Oracle Net                                                           19.0.0.0.0
Oracle Net Listener                                                  19.0.0.0.0
Oracle Net Required Support Files                                    19.0.0.0.0
Oracle Net Services                                                  19.0.0.0.0
Oracle Netca Client                                                  19.0.0.0.0
Oracle Notification Service                                          19.0.0.0.0
Oracle Notification Service for Instant Client                       19.0.0.0.0
Oracle ODBC Driver                                                   19.0.0.0.0
Oracle ODBC Driverfor Instant Client                                 19.0.0.0.0
Oracle OLAP                                                          19.0.0.0.0
Oracle OLAP API                                                      19.0.0.0.0
Oracle OLAP RDBMS Files                                              19.0.0.0.0
Oracle One-Off Patch Installer                                      12.2.0.1.15
Oracle Partitioning                                                  19.0.0.0.0
Oracle Programmer                                                    19.0.0.0.0
Oracle R Enterprise Server Files                                     19.0.0.0.0
Oracle RAC Required Support Files-HAS                                19.0.0.0.0
Oracle Real Application Testing                                      19.0.0.0.0
Oracle Recovery Manager                                              19.0.0.0.0
Oracle Scheduler Agent                                               19.0.0.0.0
Oracle Security Developer Tools                                      19.0.0.0.0
Oracle Spatial and Graph                                             19.0.0.0.0
Oracle SQL Developer                                                 19.0.0.0.0
Oracle Starter Database                                              19.0.0.0.0
Oracle Text                                                          19.0.0.0.0
Oracle Text ATG Language Support Files                               19.0.0.0.0
Oracle Text Required Support Files                                   19.0.0.0.0
Oracle Universal Connection Pool                                     19.0.0.0.0
Oracle Universal Installer                                           12.2.0.7.0
Oracle USM Deconfiguration                                           19.0.0.0.0
Oracle Wallet Manager                                                19.0.0.0.0
Oracle XML Development Kit                                           19.0.0.0.0
Oracle XML Query                                                     19.0.0.0.0
oracle.swd.commonlogging                                             13.3.0.0.0
oracle.swd.opatchautodb                                              12.2.0.1.5
oracle.swd.oui.core.min                                              12.2.0.7.0
Parser Generator Required Support Files                              19.0.0.0.0
Perl Interpreter                                                     5.28.1.0.0
Perl Modules                                                         5.28.1.0.0
PL/SQL                                                               19.0.0.0.0
PL/SQL Embedded Gateway                                              19.0.0.0.0
Platform Required Support Files                                      19.0.0.0.0
Precompiler Common Files                                             19.0.0.0.0
Precompiler Common Files for Core                                    19.0.0.0.0
Precompiler Required Support Files                                   19.0.0.0.0
Precompilers                                                         19.0.0.0.0
RDBMS Required Support Files                                         19.0.0.0.0
RDBMS Required Support Files for Instant Client                      19.0.0.0.0
Required Support Files                                               19.0.0.0.0
RHP Files for Common                                                 19.0.0.0.0
RHP Files for DB                                                     19.0.0.0.0
Secure Socket Layer                                                  19.0.0.0.0
SQL*Plus                                                             19.0.0.0.0
SQL*Plus Files for Instant Client                                    19.0.0.0.0
SQL*Plus Required Support Files                                      19.0.0.0.0
SQLJ Runtime                                                         19.0.0.0.0
SSL Required Support Files for InstantClient                         19.0.0.0.0
Trace File Analyzer for DB                                           19.0.0.0.0
XDK Required Support Files                                           19.0.0.0.0
XML Parser for Java                                                  19.0.0.0.0
XML Parser for Oracle JVM                                            19.0.0.0.0
There are 128 products installed in this Oracle Home.


Interim patches (2) :
Patch  35320081     : applied on Fri Jan 05 22:44:17 CST 2024
Unique Patch ID:  25314491
Patch description:  "Database Release Update : 19.20.0.0.230718 (35320081)"
   Created on 15 Jul 2023, 12:54:11 hrs UTC
   Bugs fixed:
......................................

Patch  29585399     : applied on Thu Apr 18 15:21:33 CST 2019
Unique Patch ID:  22840393
Patch description:  "OCW RELEASE UPDATE 19.3.0.0.0 (29585399)"
   Created on 9 Apr 2019, 19:12:47 hrs PST8PDT
   Bugs fixed:
..............................

OPatch succeeded.







[oracle@k8s-oracle-store 19.21patch]$ $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35643107/
Oracle Interim Patch Installer version 12.2.0.1.37
Copyright (c) 2024, Oracle Corporation.  All rights reserved.

PREREQ session

Oracle Home       : /u01/app/oracle/product/19.0.0/db_1
Central Inventory : /u01/app/oraInventory
   from           : /u01/app/oracle/product/19.0.0/db_1/oraInst.loc
OPatch version    : 12.2.0.1.37
OUI version       : 12.2.0.7.0
Log file location : /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/opatch2024-01-05_13-46-32PM_1.log

Invoking prereq "checkconflictagainstohwithdetail"

Prereq "checkConflictAgainstOHWithDetail" passed.

OPatch succeeded.


[oracle@k8s-oracle-store 19.21patch]$ ls
35643107  p35643107_190000_Linux-x86-64.zip  PatchSearch.xml
[oracle@k8s-oracle-store 19.21patch]$ cd 35643107/
[oracle@k8s-oracle-store 35643107]$ ls
custom  etc  files  README.html  README.txt


[oracle@k8s-oracle-store 35643107]$ $ORACLE_HOME/OPatch/opatch apply
Oracle Interim Patch Installer version 12.2.0.1.37
Copyright (c) 2024, Oracle Corporation.  All rights reserved.


Oracle Home       : /u01/app/oracle/product/19.0.0/db_1
Central Inventory : /u01/app/oraInventory
   from           : /u01/app/oracle/product/19.0.0/db_1/oraInst.loc
OPatch version    : 12.2.0.1.37
OUI version       : 12.2.0.7.0
Log file location : /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/opatch2024-01-05_13-49-06PM_1.log

Verifying environment and performing prerequisite checks...
OPatch continues with these patches:   35643107  

Do you want to proceed? [y|n]
y
User Responded with: Y
All checks passed.

Please shutdown Oracle instances running out of this ORACLE_HOME on the local system.
(Oracle Home = '/u01/app/oracle/product/19.0.0/db_1')


Is the local system ready for patching? [y|n]
y
User Responded with: Y
Backing up files...
Applying interim patch '35643107' to OH '/u01/app/oracle/product/19.0.0/db_1'
ApplySession: Optional component(s) [ oracle.network.gsm, 19.0.0.0.0 ] , [ oracle.pg4mq, 19.0.0.0.0 ] , [ oracle.rdbms.ic, 19.0.0.0.0 ] , [ oracle.rdbms.tg4db2, 19.0.0.0.0 ] , [ oracle.tfa, 19.0.0.0.0 ] , [ oracle.rdbms.tg4msql, 19.0.0.0.0 ] , [ oracle.ons.cclient, 19.0.0.0.0 ] , [ oracle.rdbms.tg4sybs, 19.0.0.0.0 ] , [ oracle.options.olap.api, 19.0.0.0.0 ] , [ oracle.network.cman, 19.0.0.0.0 ] , [ oracle.sdo.companion, 19.0.0.0.0 ] , [ oracle.xdk.companion, 19.0.0.0.0 ] , [ oracle.rdbms.tg4tera, 19.0.0.0.0 ] , [ oracle.net.cman, 19.0.0.0.0 ] , [ oracle.ons.eons.bwcompat, 19.0.0.0.0 ] , [ oracle.oid.client, 19.0.0.0.0 ] , [ oracle.rdbms.tg4ifmx, 19.0.0.0.0 ] , [ oracle.options.olap, 19.0.0.0.0 ] , [ oracle.jdk, 1.8.0.191.0 ]  not present in the Oracle Home or a higher version is found.


Patching component oracle.rdbms.util, 19.0.0.0.0...

Patching component oracle.rdbms.rsf, 19.0.0.0.0...

Patching component oracle.rdbms, 19.0.0.0.0...

Patching component oracle.assistants.acf, 19.0.0.0.0...

Patching component oracle.assistants.deconfig, 19.0.0.0.0...

Patching component oracle.assistants.server, 19.0.0.0.0...

Patching component oracle.blaslapack, 19.0.0.0.0...

Patching component oracle.buildtools.rsf, 19.0.0.0.0...

Patching component oracle.ctx, 19.0.0.0.0...

Patching component oracle.dbdev, 19.0.0.0.0...

Patching component oracle.dbjava.ic, 19.0.0.0.0...

Patching component oracle.dbjava.jdbc, 19.0.0.0.0...

Patching component oracle.dbjava.ucp, 19.0.0.0.0...

Patching component oracle.duma, 19.0.0.0.0...

Patching component oracle.javavm.client, 19.0.0.0.0...

Patching component oracle.ldap.owm, 19.0.0.0.0...

Patching component oracle.ldap.rsf, 19.0.0.0.0...

Patching component oracle.ldap.security.osdt, 19.0.0.0.0...

Patching component oracle.marvel, 19.0.0.0.0...

Patching component oracle.network.rsf, 19.0.0.0.0...

Patching component oracle.odbc.ic, 19.0.0.0.0...

Patching component oracle.ons, 19.0.0.0.0...

Patching component oracle.ons.ic, 19.0.0.0.0...

Patching component oracle.oracore.rsf, 19.0.0.0.0...

Patching component oracle.perlint, 5.28.1.0.0...

Patching component oracle.precomp.common.core, 19.0.0.0.0...

Patching component oracle.precomp.rsf, 19.0.0.0.0...

Patching component oracle.rdbms.crs, 19.0.0.0.0...

Patching component oracle.rdbms.dbscripts, 19.0.0.0.0...

Patching component oracle.rdbms.deconfig, 19.0.0.0.0...

Patching component oracle.rdbms.oci, 19.0.0.0.0...

Patching component oracle.rdbms.rsf.ic, 19.0.0.0.0...

Patching component oracle.rdbms.scheduler, 19.0.0.0.0...

Patching component oracle.rhp.db, 19.0.0.0.0...

Patching component oracle.sdo, 19.0.0.0.0...

Patching component oracle.sdo.locator.jrf, 19.0.0.0.0...

Patching component oracle.sqlplus, 19.0.0.0.0...

Patching component oracle.sqlplus.ic, 19.0.0.0.0...

Patching component oracle.wwg.plsql, 19.0.0.0.0...

Patching component oracle.ldap.rsf.ic, 19.0.0.0.0...

Patching component oracle.ldap.client, 19.0.0.0.0...

Patching component oracle.rdbms.dv, 19.0.0.0.0...

Patching component oracle.rdbms.install.common, 19.0.0.0.0...

Patching component oracle.rdbms.hsodbc, 19.0.0.0.0...

Patching component oracle.nlsrtl.rsf, 19.0.0.0.0...

Patching component oracle.xdk.rsf, 19.0.0.0.0...

Patching component oracle.odbc, 19.0.0.0.0...

Patching component oracle.xdk.parser.java, 19.0.0.0.0...

Patching component oracle.ctx.atg, 19.0.0.0.0...

Patching component oracle.network.listener, 19.0.0.0.0...

Patching component oracle.ctx.rsf, 19.0.0.0.0...

Patching component oracle.rdbms.hs_common, 19.0.0.0.0...

Patching component oracle.dbtoolslistener, 19.0.0.0.0...

Patching component oracle.xdk, 19.0.0.0.0...

Patching component oracle.rdbms.rman, 19.0.0.0.0...

Patching component oracle.rdbms.drdaas, 19.0.0.0.0...

Patching component oracle.install.deinstalltool, 19.0.0.0.0...

Patching component oracle.ovm, 19.0.0.0.0...

Patching component oracle.rdbms.install.plugins, 19.0.0.0.0...

Patching component oracle.mgw.common, 19.0.0.0.0...

Patching component oracle.xdk.xquery, 19.0.0.0.0...

Patching component oracle.network.client, 19.0.0.0.0...

Patching component oracle.ldap.ssl, 19.0.0.0.0...

Patching component oracle.oraolap.api, 19.0.0.0.0...

Patching component oracle.javavm.server, 19.0.0.0.0...

Patching component oracle.sdo.locator, 19.0.0.0.0...

Patching component oracle.oraolap, 19.0.0.0.0...

Patching component oracle.oraolap.dbscripts, 19.0.0.0.0...

Patching component oracle.rdbms.lbac, 19.0.0.0.0...

Patching component oracle.precomp.common, 19.0.0.0.0...

Patching component oracle.precomp.lang, 19.0.0.0.0...

Patching component oracle.jdk, 1.8.0.201.0...
Patch 35643107 successfully applied.
Sub-set patch [35320081] has become inactive due to the application of a super-set patch [35643107].
Please refer to Doc ID 2161861.1 for any possible further required actions.
Log file location: /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatch/opatch2024-01-05_13-49-06PM_1.log

OPatch succeeded.



[oracle@k8s-oracle-store ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Jan 5 14:16:24 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

Connected to an idle instance.

SQL> startup;
ORACLE instance started.

Total System Global Area 1.6106E+10 bytes
Fixed Size		   18625040 bytes
Variable Size		 2415919104 bytes
Database Buffers	 1.3657E+10 bytes
Redo Buffers		   14925824 bytes
Database mounted.
Database opened.
SQL> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0


[oracle@k8s-oracle-store ~]$ lsnrctl start

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 05-JAN-2024 14:17:09

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Starting /u01/app/oracle/product/19.0.0/db_1/bin/tnslsnr: please wait...

TNSLSNR for Linux: Version 19.0.0.0.0 - Production
System parameter file is /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Log messages written to /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-JAN-2024 14:17:09
Uptime                    0 days 0 hr. 0 min. 0 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
The listener supports no services
The command completed successfully


[oracle@k8s-oracle-store ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 05-JAN-2024 14:17:27

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-JAN-2024 14:17:09
Uptime                    0 days 0 hr. 0 min. 18 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
The listener supports no services
The command completed successfully


[oracle@k8s-oracle-store ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Jan 5 14:18:02 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 TESTPDB			  READ WRITE NO
SQL> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0


[oracle@k8s-oracle-store ~]$ cd $ORACLE_HOME/OPatch


[oracle@k8s-oracle-store OPatch]$ ./datapatch -verbose
SQL Patching tool version 19.21.0.0.0 Production on Fri Jan  5 14:18:51 2024
Copyright (c) 2012, 2023, Oracle.  All rights reserved.

Log file for this invocation: /u01/app/oracle/cfgtoollogs/sqlpatch/sqlpatch_28378_2024_01_05_14_18_51/sqlpatch_invocation.log

Connecting to database...OK
Gathering database info...done

Note:  Datapatch will only apply or rollback SQL fixes for PDBs
       that are in an open state, no patches will be applied to closed PDBs.
       Please refer to Note: Datapatch: Database 12c Post Patch SQL Automation
       (Doc ID 1585822.1)

Bootstrapping registry and package to current versions...done
Determining current state...done

Current state of interim SQL patches:
  No interim patches found

Current state of release update SQL patches:
  Binary registry:
    19.21.0.0.0 Release_Update 230930151951: Installed
  PDB CDB$ROOT:
    Applied 19.20.0.0.0 Release_Update 230715022800 successfully on 05-JAN-24 12.17.58.133923 PM
  PDB PDB$SEED:
    Applied 19.20.0.0.0 Release_Update 230715022800 successfully on 05-JAN-24 12.18.08.482360 PM
  PDB TESTPDB:
    Applied 19.20.0.0.0 Release_Update 230715022800 successfully on 05-JAN-24 12.18.18.544439 PM

Adding patches to installation queue and performing prereq checks...done
Installation queue:
  For the following PDBs: CDB$ROOT PDB$SEED TESTPDB
    No interim patches need to be rolled back
    Patch 35643107 (Database Release Update : 19.21.0.0.231017 (35643107)):
      Apply from 19.20.0.0.0 Release_Update 230715022800 to 19.21.0.0.0 Release_Update 230930151951
    No interim patches need to be applied

Installing patches...
Patch installation complete.  Total patches installed: 3

Validating logfiles...done
Patch 35643107 apply (pdb CDB$ROOT): SUCCESS
  logfile: /u01/app/oracle/cfgtoollogs/sqlpatch/35643107/25405995/35643107_apply_XYDBDG_CDBROOT_2024Jan05_14_20_25.log (no errors)
Patch 35643107 apply (pdb PDB$SEED): SUCCESS
  logfile: /u01/app/oracle/cfgtoollogs/sqlpatch/35643107/25405995/35643107_apply_XYDBDG_PDBSEED_2024Jan05_14_22_15.log (no errors)
Patch 35643107 apply (pdb TESTPDB): SUCCESS
  logfile: /u01/app/oracle/cfgtoollogs/sqlpatch/35643107/25405995/35643107_apply_XYDBDG_TESTPDB_2024Jan05_14_22_15.log (no errors)
SQL Patching tool complete on Fri Jan  5 14:24:33 2024



[oracle@k8s-oracle-store OPatch]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Jan 5 14:25:35 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

SQL> set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION	      STATUS	      TARGET_VERSION
---------- ---------- --------------- --------------- ---------------
  29517242 RU	      APPLY	      SUCCESS	      19.3.0.0.0
  35320081 RU	      APPLY	      SUCCESS	      19.20.0.0.0
  35643107 RU	      APPLY	      SUCCESS	      19.21.0.0.0

SQL> 
SQL> col status for a10
col action for a10
col action_time for a30
col description for a60
SQL> select patch_id,patch_type,action,status,action_time,description from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION	 STATUS     ACTION_TIME 		   DESCRIPTION
---------- ---------- ---------- ---------- ------------------------------ ------------------------------------------------------------
  29517242 RU	      APPLY	 SUCCESS    04-JAN-24 05.24.45.204786 PM   Database Release Update : 19.3.0.0.190416 (29517242)
  35320081 RU	      APPLY	 SUCCESS    05-JAN-24 12.17.58.133923 PM   Database Release Update : 19.20.0.0.230718 (35320081)
  35643107 RU	      APPLY	 SUCCESS    05-JAN-24 02.24.24.534709 PM   Database Release Update : 19.21.0.0.231017 (35643107)

SQL> col version for a25
col comments for a80SQL> 
SQL> 
SQL> select ACTION_TIME,VERSION,COMMENTS from dba_registry_history;

ACTION_TIME		       VERSION			 COMMENTS
------------------------------ ------------------------- --------------------------------------------------------------------------------
			       19			 RDBMS_19.21.0.0.0DBRU_LINUX.X64_230923
04-JAN-24 05.24.36.473920 PM   19.0.0.0.0		 Patch applied on 19.3.0.0.0: Release_Update - 190410122720
05-JAN-24 12.07.30.610435 PM   19.0.0.0.0		 Patch applied from 19.3.0.0.0 to 19.20.0.0.0: Release_Update - 230715022800
05-JAN-24 02.21.37.826001 PM   19.0.0.0.0		 Patch applied from 19.20.0.0.0 to 19.21.0.0.0: Release_Update - 230930151951

SQL> select status,count(*) from dba_objects group by status;

STATUS	     COUNT(*)
---------- ----------
VALID		73104

SQL> 

```





## 8.其他优化
### 8.1.hugepages_settings.sh
```bash
#!/bin/bash
#
# hugepages_settings.sh

# Welcome text
echo "
This script is provided by Doc ID 401749.1 from My Oracle Support
(http://support.oracle.com) where it is intended to compute values for
the recommended HugePages/HugeTLB configuration for the current shared
memory segments on Oracle Linux. Before proceeding with the execution please note following:
 * For ASM instance, it needs to configure ASMM instead of AMM.
 * The 'pga_aggregate_target' is outside the SGA and
   you should accommodate this while calculating the overall size.
 * In case you changes the DB SGA size,
   as the new SGA will not fit in the previous HugePages configuration,
   it had better disable the whole HugePages,
   start the DB with new SGA size and run the script again.
And make sure that:
 * Oracle Database instance(s) are up and running
 * Oracle Database 11g Automatic Memory Management (AMM) is not setup
   (See Doc ID 749851.1)
 * The shared memory segments can be listed by command:
     # ipcs -m

Press Enter to proceed..."

read

# Check for the kernel version
KERN=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`

# Find out the HugePage size
HPG_SZ=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
if [ -z "$HPG_SZ" ];then
    echo "The hugepages may not be supported in the system where the script is being executed."
    exit 1
fi

# Initialize the counter
NUM_PG=0

# Cumulative number of pages required to handle the running shared memory segments
for SEG_BYTES in `ipcs -m | cut -c44-300 | awk '{print $1}' | grep "[0-9][0-9]*"`
do
    MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
    if [ $MIN_PG -gt 0 ]; then
        NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
    fi
done

RES_BYTES=`echo "$NUM_PG * $HPG_SZ * 1024" | bc -q`

# An SGA less than 100MB does not make sense
# Bail out if that is the case
if [ $RES_BYTES -lt 100000000 ]; then
    echo "***********"
    echo "** ERROR **"
    echo "***********"
    echo "Sorry! There are not enough total of shared memory segments allocated for
HugePages configuration. HugePages can only be used for shared memory segments
that you can list by command:

    # ipcs -m

of a size that can match an Oracle Database SGA. Please make sure that:
 * Oracle Database instance is up and running
 * Oracle Database 11g Automatic Memory Management (AMM) is not configured"
    exit 1
fi

# Finish with results
case $KERN in
    '2.4') HUGETLB_POOL=`echo "$NUM_PG*$HPG_SZ/1024" | bc -q`;
           echo "Recommended setting: vm.hugetlb_pool = $HUGETLB_POOL" ;;
    '2.6') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '3.8') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '3.10') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '4.1') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '4.14') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '4.18') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '5.4') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    *) echo "Kernel version $KERN is not supported by this script (yet). Exiting." ;;
esac

# End

```



 #root用户执行

```bash
chmod a+x hugepages_settings.sh
./hugepages_settings.sh
```

#根据上面脚本运行的结果，修改/etc/sysctl.conf

```bash
cat >> /etc/sysctl.conf <<EOF
vm.nr_hugepages = 7682
EOF

sysctl -p

cat /proc/meminfo|grep -i huge
```

