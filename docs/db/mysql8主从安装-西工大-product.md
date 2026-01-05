此文档提供安装mysql8(最新版8.0.39)主从高可用模式的安装

****

#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小，mysql安装到最大分区里
#20240821补充OS优化部分，安装版本为8.0.39

## 服务器资源

#建议

```
vm: 16核/32G 

OS: 
Kylin Linux Advanced Server
release V10 (SP2) /(Sword)-x86_64-Build09.01/20210524


磁盘LVM管理，1T，/为最大分区
```

## 部署过程

### 一、系统优化

#### 0、将/home分区空间回收，加入/分区

#当前/home分区最大

```bash
[root@MHsql-db01 ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                  31G     0   31G    0% /dev
tmpfs                     31G   88K   31G    1% /dev/shm
tmpfs                     31G  282M   31G    1% /run
tmpfs                     31G     0   31G    0% /sys/fs/cgroup
/dev/mapper/rootvg-root  253G   17G  237G    7% /
tmpfs                     31G   32K   31G    1% /tmp
/dev/mapper/rootvg-home   30G  248M   30G    1% /home
/dev/vda1               1014M  212M  803M   21% /boot
tmpfs                    6.2G   44K  6.2G    1% /run/user/0
tmpfs                    6.2G     0  6.2G    0% /run/user/1000
[root@MHsql-db01 ~]# cat /etc/os-release
NAME="Kylin Linux Advanced Server"
VERSION="V10 (Sword)"
ID="kylin"
VERSION_ID="V10"
PRETTY_NAME="Kylin Linux Advanced Server V10 (Sword)"
ANSI_COLOR="0;31"

[root@MHsql-db01 ~]# cat /etc/.productinfo
Kylin Linux Advanced Server
release V10 (SP2) /(Sword)-x86_64-Build09/20210524

[root@MHsql-db01 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk
sr0              11:0    1 1024M  0 rom
vda             252:0    0  100G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   99G  0 part
  ├─rootvg-root 253:0    0  253G  0 lvm  /
  ├─rootvg-swap 253:1    0   16G  0 lvm  [SWAP]
  └─rootvg-home 253:2    0   30G  0 lvm  /home
vdb             252:16   0  200G  0 disk
└─rootvg-root   253:0    0  253G  0 lvm  /
vdc             252:32   0  1.5T  0 disk
└─datavg-datalv 253:3    0  1.5T  0 lvm

[root@MHsql-db01 ~]# vgs
  VG     #PV #LV #SN Attr   VSize   VFree
  datavg   1   1   0 wz--n-   1.46t    0
  rootvg   2   3   0 wz--n- 298.99g    0
[root@MHsql-db01 ~]# lvs
  LV     VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  datalv datavg -wi-a-----   1.46t                                        
  home   rootvg -wi-ao----  30.00g                                        
  root   rootvg -wi-ao---- 252.99g                                        
  swap   rootvg -wi-ao----  16.00g                                        
[root@MHsql-db01 ~]#

[root@MHsql-db01B ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                  31G     0   31G    0% /dev
tmpfs                     31G   56K   31G    1% /dev/shm
tmpfs                     31G  114M   31G    1% /run
tmpfs                     31G     0   31G    0% /sys/fs/cgroup
/dev/mapper/rootvg-root  253G   16G  238G    7% /
tmpfs                     31G     0   31G    0% /tmp
/dev/mapper/rootvg-home   30G  248M   30G    1% /home
/dev/vda1               1014M  212M  803M   21% /boot
tmpfs                    6.2G     0  6.2G    0% /run/user/993
tmpfs                    6.2G     0  6.2G    0% /run/user/1000
[root@MHsql-db01B ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk
sr0              11:0    1 1024M  0 rom
vda             252:0    0  100G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   99G  0 part
  ├─rootvg-root 253:0    0  253G  0 lvm  /
  ├─rootvg-swap 253:1    0   16G  0 lvm  [SWAP]
  └─rootvg-home 253:3    0   30G  0 lvm  /home
vdb             252:16   0  200G  0 disk
└─rootvg-root   253:0    0  253G  0 lvm  /
vdc             252:32   0  1.5T  0 disk
└─datavg-datalv 253:2    0  1.5T  0 lvm
[root@MHsql-db01B ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                  31G     0   31G    0% /dev
tmpfs                     31G   56K   31G    1% /dev/shm
tmpfs                     31G  114M   31G    1% /run
tmpfs                     31G     0   31G    0% /sys/fs/cgroup
/dev/mapper/rootvg-root  253G   16G  238G    7% /
tmpfs                     31G     0   31G    0% /tmp
/dev/mapper/rootvg-home   30G  248M   30G    1% /home
/dev/vda1               1014M  212M  803M   21% /boot
tmpfs                    6.2G     0  6.2G    0% /run/user/993
tmpfs                    6.2G     0  6.2G    0% /run/user/1000
[root@MHsql-db01B ~]# cat /etc/os-release
NAME="Kylin Linux Advanced Server"
VERSION="V10 (Sword)"
ID="kylin"
VERSION_ID="V10"
PRETTY_NAME="Kylin Linux Advanced Server V10 (Sword)"
ANSI_COLOR="0;31"

[root@MHsql-db01B ~]# cat /etc/.productinfo
Kylin Linux Advanced Server
release V10 (SP2) /(Sword)-x86_64-Build09/20210524
[root@MHsql-db01B ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk
sr0              11:0    1 1024M  0 rom
vda             252:0    0  100G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   99G  0 part
  ├─rootvg-root 253:0    0  253G  0 lvm  /
  ├─rootvg-swap 253:1    0   16G  0 lvm  [SWAP]
  └─rootvg-home 253:3    0   30G  0 lvm  /home
vdb             252:16   0  200G  0 disk
└─rootvg-root   253:0    0  253G  0 lvm  /
vdc             252:32   0  1.5T  0 disk
└─datavg-datalv 253:2    0  1.5T  0 lvm
[root@MHsql-db01B ~]# vgs
  VG     #PV #LV #SN Attr   VSize   VFree
  datavg   1   1   0 wz--n-   1.46t    0
  rootvg   2   3   0 wz--n- 298.99g    0
[root@MHsql-db01B ~]# lvs
  LV     VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  datalv datavg -wi-a-----   1.46t                                        
  home   rootvg -wi-ao----  30.00g                                        
  root   rootvg -wi-ao---- 252.99g                                        
  swap   rootvg -wi-ao----  16.00g                                        
[root@MHsql-db01B ~]#


[root@HMsql-db02 ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                  16G     0   16G    0% /dev
tmpfs                     16G   84K   16G    1% /dev/shm
tmpfs                     16G  274M   15G    2% /run
tmpfs                     16G     0   16G    0% /sys/fs/cgroup
/dev/mapper/rootvg-root  253G   17G  237G    7% /
tmpfs                     16G     0   16G    0% /tmp
/dev/mapper/rootvg-home   30G  248M   30G    1% /home
/dev/vda1               1014M  212M  803M   21% /boot
tmpfs                    3.1G   40K  3.1G    1% /run/user/0
tmpfs                    3.1G     0  3.1G    0% /run/user/1000
[root@HMsql-db02 ~]# cat /etc/os-release
NAME="Kylin Linux Advanced Server"
VERSION="V10 (Sword)"
ID="kylin"
VERSION_ID="V10"
PRETTY_NAME="Kylin Linux Advanced Server V10 (Sword)"
ANSI_COLOR="0;31"

[root@HMsql-db02 ~]# cat /etc/.productinfo
Kylin Linux Advanced Server
release V10 (SP2) /(Sword)-x86_64-Build09/20210524
[root@HMsql-db02 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk
sr0              11:0    1 1024M  0 rom
vda             252:0    0  100G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   99G  0 part
  ├─rootvg-root 253:0    0  253G  0 lvm  /
  ├─rootvg-swap 253:1    0   16G  0 lvm  [SWAP]
  └─rootvg-home 253:2    0   30G  0 lvm  /home
vdb             252:16   0  200G  0 disk
└─rootvg-root   253:0    0  253G  0 lvm  /
vdc             252:32   0  500G  0 disk
└─datavg-datalv 253:3    0  500G  0 lvm
[root@HMsql-db02 ~]# vgs
  VG     #PV #LV #SN Attr   VSize    VFree
  datavg   1   1   0 wz--n- <500.00g    0
  rootvg   2   3   0 wz--n-  298.99g    0
[root@HMsql-db02 ~]# lvs
  LV     VG     Attr       LSize    Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  datalv datavg -wi-a----- <500.00g                                       
  home   rootvg -wi-ao----   30.00g                                       
  root   rootvg -wi-ao----  252.99g                                       
  swap   rootvg -wi-ao----   16.00g                                       
[root@HMsql-db02 ~]#

[root@HMsql-db02B ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                  16G     0   16G    0% /dev
tmpfs                     16G   56K   16G    1% /dev/shm
tmpfs                     16G  114M   15G    1% /run
tmpfs                     16G     0   16G    0% /sys/fs/cgroup
/dev/mapper/rootvg-root  253G   16G  238G    7% /
tmpfs                     16G     0   16G    0% /tmp
/dev/vda1               1014M  212M  803M   21% /boot
/dev/mapper/rootvg-home   30G  248M   30G    1% /home
tmpfs                    3.1G     0  3.1G    0% /run/user/993
tmpfs                    3.1G     0  3.1G    0% /run/user/1000
[root@HMsql-db02B ~]# cat /etc/os-release
NAME="Kylin Linux Advanced Server"
VERSION="V10 (Sword)"
ID="kylin"
VERSION_ID="V10"
PRETTY_NAME="Kylin Linux Advanced Server V10 (Sword)"
ANSI_COLOR="0;31"

[root@HMsql-db02B ~]# cat /etc/.productinfo
Kylin Linux Advanced Server
release V10 (SP2) /(Sword)-x86_64-Build09/20210524
[root@HMsql-db02B ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk
sr0              11:0    1 1024M  0 rom
vda             252:0    0  100G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   99G  0 part
  ├─rootvg-root 253:0    0  253G  0 lvm  /
  ├─rootvg-swap 253:1    0   16G  0 lvm  [SWAP]
  └─rootvg-home 253:2    0   30G  0 lvm  /home
vdb             252:16   0  200G  0 disk
└─rootvg-root   253:0    0  253G  0 lvm  /
vdc             252:32   0  500G  0 disk
└─datavg-datalv 253:3    0  500G  0 lvm
[root@HMsql-db02B ~]# vgs
  VG     #PV #LV #SN Attr   VSize    VFree
  datavg   1   1   0 wz--n- <500.00g    0
  rootvg   2   3   0 wz--n-  298.99g    0
[root@HMsql-db02B ~]# lvs
  LV     VG     Attr       LSize    Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  datalv datavg -wi-a----- <500.00g                                       
  home   rootvg -wi-ao----   30.00g                                       
  root   rootvg -wi-ao----  252.99g                                       
  swap   rootvg -wi-ao----   16.00g                                       
[root@HMsql-db02B ~]#

```



#data分区，单独挂载

```bash
vi /etc/fstab

/dev/mapper/datavg-datalv /data xfs defaults 0 0
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

[root@MHsql-db01 ~]# mkdir /data
```



#### 1、Hostname修改

#hostname命名建议规范，以实际IP为准

```bash
cat >> /etc/hosts <<EOF
 222.24.203.31 MHsql-db01
 222.24.203.35 MHsql-db01B
EOF

#MHsql-db01
hostnamectl set-hostname MHsql-db01
#MHsql-db01B
hostnamectl set-hostname MHsql-db01B

hostnamectl status

ping MHsql-db01 
ping MHsql-db01B

```

```
[root@localhost ~]# hostnamectl set-hostname MHsql-db01B
[root@localhost ~]# exit

[root@MHsql-db01B ~]# $ hostnamectl status
   Static hostname: MHsql-db01B
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 96673b7b63a1448eab69bc486cb9f432
           Boot ID: c9cda86512674cb4a7c04e1e8630bd35
    Virtualization: kvm
  Operating System: Kylin Linux Advanced Server V10 (Sword)
            Kernel: Linux 4.19.90-24.4.v2101.ky10.x86_64
      Architecture: x86-64



[root@MHsql-db01 ~]# cat >> /etc/hosts <<EOF
10.40.10.132       MHmysql-db01       
10.40.10.133       MHmysql-db02       
10.40.10.134       MHmysql-db03       
10.40.10.135       MHmysql-db04       
10.40.10.136       MHmysql-db01B       
10.40.10.137       MHmysql-db02B       
10.40.10.138       MHmysql-db03B       
10.40.10.139       MHmysql-db04B       


222.24.203.31       MHmysql-db01       
222.24.203.32       MHmysql-db02       
222.24.203.33       MHmysql-db03       
222.24.203.34       MHmysql-db04       
222.24.203.35       MHmysql-db01B       
222.24.203.36       MHmysql-db02B       
222.24.203.37       MHmysql-db03B       
222.24.203.38       MHmysql-db04B
EOF

[root@MHsql-db01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.40.10.132       MHmysql-db01       
10.40.10.133       MHmysql-db02       
10.40.10.134       MHmysql-db03       
10.40.10.135       MHmysql-db04       
10.40.10.136       MHmysql-db01B       
10.40.10.137       MHmysql-db02B       
10.40.10.138       MHmysql-db03B       
10.40.10.139       MHmysql-db04B       


222.24.203.31       MHmysql-db01       
222.24.203.32       MHmysql-db02       
222.24.203.33       MHmysql-db03       
222.24.203.34       MHmysql-db04       
222.24.203.35       MHmysql-db01B       
222.24.203.36       MHmysql-db02B       
222.24.203.37       MHmysql-db03B       
222.24.203.38       MHmysql-db04B

[root@MHsql-db01 ~]# ping MHsql-db01 -c 1
PING MHsql-db01 ( 222.24.203.31) 56(84) bytes of data.
64 bytes from MHsql-db01 ( 222.24.203.31): icmp_seq=1 ttl=64 time=0.065 ms

--- MHsql-db01 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.065/0.065/0.065/0.000 ms
[root@MHsql-db01 ~]# ping MHsql-db01B -c 1
PING MHsql-db01B ( 222.24.203.35) 56(84) bytes of data.
64 bytes from MHsql-db01B ( 222.24.203.35): icmp_seq=1 ttl=64 time=0.619 ms

--- MHsql-db01B ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.619/0.619/0.619/0.000 ms
[root@MHsql-db01 ~]#

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

[root@MHsql-db01 ~]# cat /etc/anolis-release
Anolis OS release 7.9

[root@MHsql-db01 ~]# ls /etc/yum.repos.d/
AnolisOS-Debuginfo.repo  AnolisOS-os.repo    AnolisOS-Source.repo
AnolisOS-extras.repo     AnolisOS-Plus.repo  AnolisOS-updates.repo
[root@MHsql-db01 ~]# cat /etc/yum.repos.d/AnolisOS-os.repo
[os]
name=AnolisOS-7.9 - os
baseurl=http://mirrors.openanolis.cn/anolis/7.9/os/$basearch/os
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ANOLIS
gpgcheck=1
[root@MHsql-db01 ~]#


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


#Kylin Linux Advanced Server 10
[root@MHsql-db01 ~]# cd /etc/yum.repos.d/
[root@MHsql-db01 yum.repos.d]# ls
kylin_x86_64.repo  kylin_x86_64.repo.bak  yum_kylin_local.repo
[root@MHsql-db01 yum.repos.d]# cat kylin_x86_64.repo
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
[docker-ce-stable]
name=Docker CE Stable
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/8/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[centos-extras]
name=centos-extras Stable
baseurl=https://mirrors.aliyun.com/centos/8/extras/$basearch/os
enabled=1
gpgcheck=0

------------
[docker-ce-stable]
name=Docker CE Stable
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7.9/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[centos-extras]
name=centos-extras Stable
baseurl=https://mirrors.aliyun.com/centos/7/extras/$basearch
enabled=1
gpgcheck=0
[devel@docker01-test yum.repos.d]$

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
#server times.neuq.edu.cn iburst
server 222.24.211.121
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
yum remove mariadb* -y

[root@DB03-test ~]# rpm -qa |grep -i mariadb
mariadb-errmessage-10.3.39-1.p01.ky10.x86_64
mariadb-server-10.3.39-1.p01.ky10.x86_64
mariadb-connector-c-3.0.6-8.p01.ky10.x86_64
mariadb-common-10.3.39-1.p01.ky10.x86_64
mariadb-10.3.39-1.p01.ky10.x86_64
[root@DB03-test ~]#yum remove mariadb* -y
```

#### 2、安装mysql

```bash
yum install -y wget net-tools

#centos7.9
#mysql 8.4.x
wget https://dev.mysql.com/get/mysql84-community-release-el7-1.noarch.rpm

#20250923
#8.0.43
wget https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm
yum localinstall -y mysql80-community-release-el7-11.noarch.rpm

#Kylin Linux Advanced Server 10
[root@MHsql-db01 ~]# uname -a
Linux MHsql-db01 4.19.90-25.44.v2101.ky10.x86_64 #1 SMP Thu Nov 7 17:33:30 CST 2024 x86_64 x86_64 x86_64 GNU/Linux

wget https://dev.mysql.com/get/mysql80-community-release-el8-3.noarch.rpm

yum localinstall -y mysql80-community-release-el8-3.noarch.rpm


yum search mysql-community-server
yum list mysql-community-server.x86_64  --showduplicates | sort -r
yum list mysql-community-client-plugins.x86_64  --showduplicates | sort -r

#yum install -y mysql-community-server
yum install -y mysql-community-server --nogpgcheck

[root@MHsql-db01 ~]# mysql -V
mysql  Ver 8.0.43 for Linux on x86_64 (MySQL Community Server - GPL)



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





#### 3、优化mysql---MHsql-db01和MHsql-db01B有细微差别

#检查my.cnf

```bash
mysqld --defaults-file=/etc/my.cnf  --validate-config --log-error-verbosity=2
```

#logs

```bash
#启动前

[root@MHsql-db01 ~]# mysqld --defaults-file=/etc/my.cnf  --validate-config --log-error-verbosity=2
2024-08-21T12:11:55.450283+08:00 0 [Warning] [MY-011070] [Server] 'binlog_format' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450361+08:00 0 [Warning] [MY-011069] [Server] The syntax '--master-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450366+08:00 0 [Warning] [MY-011069] [Server] The syntax '--relay-log-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450375+08:00 0 [Warning] [MY-011070] [Server] '--sync-relay-log-info' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450384+08:00 0 [Warning] [MY-011069] [Server] The syntax '--replica-parallel-type' is deprecated and will be removed in a future release.
2024-08-21T12:11:55.450471+08:00 0 [Warning] [MY-010091] [Server] Can't create test file /data/mysql/mysqld_tmp_file_case_insensitive_test.lower-test
[root@MHsql-db01 ~]#

#启动后
[root@MHsql-db01 data]# mysqld --defaults-file=/etc/my.cnf  --validate-config --log-error-verbosity=2
2024-08-21T12:16:21.793327+08:00 0 [Warning] [MY-011070] [Server] 'binlog_format' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793404+08:00 0 [Warning] [MY-011069] [Server] The syntax '--master-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793410+08:00 0 [Warning] [MY-011069] [Server] The syntax '--relay-log-info-repository' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793419+08:00 0 [Warning] [MY-011070] [Server] '--sync-relay-log-info' is deprecated and will be removed in a future release.
2024-08-21T12:16:21.793428+08:00 0 [Warning] [MY-011069] [Server] The syntax '--replica-parallel-type' is deprecated and will be removed in a future release.
[root@MHsql-db01 data]#


```



##### 1) MHsql-db01---/etc/my.cnf

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
server_id = 80
#server_id = 81
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
innodb_buffer_pool_size = 16384M
#64G
#innodb_buffer_pool_size = 32768M
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
server_id = 80
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
innodb_buffer_pool_size = 16384M
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



##### 2) MHsql-db01B---/etc/my.cnf

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
#server_id = 80
server_id = 81
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
innodb_buffer_pool_size = 16384M
#64G
#innodb_buffer_pool_size = 32768M
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
server_id = 81
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
innodb_buffer_pool_size = 16384M
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



##### 3) mysqld.server---MHsql-db01/MHsql-db01B

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
create user 'repl'@'10.40.10.%' identified with mysql_native_password by 'Repl123!@#2024';
grant replication slave on *.* to 'repl'@'10.40.10.%';

show grants for 'repl'@'10.40.10.%';

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

 scp 20231102.sql.tar.gz  222.24.203.31:/root/
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

CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.31',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2024',SOURCE_AUTO_POSITION = 1;

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



#此时如果主库全库导入旧库，那么导入后，双主库都需要重启mysql，不然mysql.user中的账户密码不生效

#### 4、错误处理

##### 4.1.root/repl账户重复的报错

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

```bash
tail -f /data/mysql/error.log


2025-04-18T18:07:35.195437+08:00 30 [ERROR] [MY-010584] [Repl] Replica SQL for channel '': Worker 1 failed executing transaction '6a48c612-1c39-11f0-b37f-286ed489ab99:1' at source log mysql-bin.000002, end_log_pos 477; Error 'Operation ALTER USER failed for 'root'@'localhost'' on query. Default database: ''. Query: 'ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$fBjJG*L(q1Lyr\\C   EVWPQ/V2e4bFKNoXRTypFYRwkuoM4mZMU8Btryguz5D'', Error_code: MY-001396
2025-04-18T18:07:35.195929+08:00 29 [ERROR] [MY-010586] [Repl] Error running query, replica SQL thread aborted. Fix the problem, and restart the replica SQL thread with "START REPLICA". We stopped at log 'mysql-bin.000002' position 157


```



#跳过部分

```
stop replica;
 
 set @@session.gtid_next='b526a489-7796-11ee-b698-fefcfec91d86:1'; 
 begin; 
 commit; 

 set @@session.gtid_next='b526a489-7796-11ee-b698-fefcfec91d86:4'; 
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
2023-11-02T10:43:19.953661+08:00 47 [System] [MY-014002] [Repl] Replica receiver thread for channel '': connected to source 'repl@ 222.24.203.31:3306' with server_uuid=6cfaa641-7926-11ee-bb23-fefcfe25467b, server_id=114. Starting GTID-based replication.

```



#主库

```bash
tail -f /data/mysql/error.log

2023-11-02T10:43:19.897307+08:00 12 [Warning] [MY-013360] [Server] Plugin mysql_native_password reported: ''mysql_native_password' is deprecated and will be removed in a future release. Please use caching_sha2_password instead'
2023-11-02T10:43:19.956046+08:00 12 [Note] [MY-010462] [Repl] Start binlog_dump to source_thread_id(12) replica_server(115), pos(, 4)

```

#主库logs

```bash

[root@MHsql-db01 mysql]# tail -f error.log
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



##### 4.2.配置主从时，在IP地址前多了个空格，导致报错

#在配置主从时，`CHANGE MASTER TO` 命令中的 `MASTER_HOST` 参数误写为 **`' 222.24.203.31'`**（含空格），导致MySQL无法解析该主机名

```sql
root@localhost:mysql.sock [mysql]> CHANGE REPLICATION SOURCE TO SOURCE_HOST=' 222.24.203.31',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='ReplNwpu123!@#2025',SOURCE_AUTO_POSITION = 1;
Query OK, 0 rows affected, 2 warnings (0.02 sec)

root@localhost:mysql.sock [mysql]> SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State:
                  Source_Host:  222.24.203.31
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File:
          Read_Source_Log_Pos: 4
               Relay_Log_File: relay-bin.000001
                Relay_Log_Pos: 4
        Relay_Source_Log_File:
           Replica_IO_Running: No
          Replica_SQL_Running: No
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 0
              Relay_Log_Space: 157
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
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 0
                  Source_UUID:
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State:
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set:
            Executed_Gtid_Set: 69fc8d5a-1c39-11f0-88c3-286ed489b835:1-5
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

root@localhost:mysql.sock [mysql]> start replica;
Query OK, 0 rows affected (0.13 sec)

root@localhost:mysql.sock [mysql]> SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Connecting to source
                  Source_Host:  222.24.203.31
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File:
          Read_Source_Log_Pos: 4
               Relay_Log_File: relay-bin.000001
                Relay_Log_Pos: 4
        Relay_Source_Log_File:
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
          Exec_Source_Log_Pos: 0
              Relay_Log_Space: 157
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
                Last_IO_Errno: 2005
                Last_IO_Error: Error connecting to source 'repl@ 222.24.203.31:3306'. This was attempt 1/86400, with a delay of 60 seconds between attempts. Message: Unknown MySQL server host '222.24.203.31' (-2)
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 0
                  Source_UUID:
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp: 250418 17:59:46
     Last_SQL_Error_Timestamp:
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set:
            Executed_Gtid_Set: 69fc8d5a-1c39-11f0-88c3-286ed489b835:1-5
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

2025-04-18T18:00:46.217515+08:00 10 [ERROR] [MY-010584] [Repl] Replica I/O for channel '': Error connecting to source 'repl@ 222.24.203.31:3306'. This was attempt 2/86400, with a delay of 60 seconds between attempts. Message: Unknown MySQL server host ' 222.24.203.31' (-2), Error_code: MY-002005
```



#解决办法

```sql
STOP REPLICA;
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.31' FOR CHANNEL ''; -- If you're using default channel
-- OR
-- CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.31' FOR CHANNEL 'your_channel_name'; -- If you've named the channel
START REPLICA;
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
                  Source_Host:  222.24.203.31
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
                  Source_Host:  222.24.203.35
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
                  Source_Host:  222.24.203.31
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
                  Source_Host:  222.24.203.31
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
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.31',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;

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
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.35',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;


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
                  Source_Host:  222.24.203.31
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
                  Source_Host:  222.24.203.31
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
                  Source_Host:  222.24.203.35
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
                  Source_Host:  222.24.203.31
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

 scp 20240305.sql.tar.gz  222.24.203.31:/root/

3、从库操作

-- 还原从库
tar -zxvf 20240305.sql.tar.gz

mysql -u root -p

source /root/20240305.sql


-- 重新建立关系  子厚两个参数查看master状态即可 和主库保持一致
#change master to master_host = '192.168.22.22', master_user = 'user', master_port=3306, master_password='pwd', master_log_file = 'mysqld-bin.000001', master_log_pos=1234; 
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.31',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;


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
                  Source_Host:  222.24.203.31
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

 scp 20240305.sql.tar.gz  222.24.203.31:/root/

3、从库操作

-- 还原从库
tar -zxvf 20240305.sql.tar.gz

mysql -u root -p

source /root/20240305.sql

-- 如果是双主，此时从库也要reset master下，重置下binlog
reset master;

-- 重新建立关系  子厚两个参数查看master状态即可 和主库保持一致
#change master to master_host = '192.168.22.22', master_user = 'user', master_port=3306, master_password='pwd', master_log_file = 'mysqld-bin.000001', master_log_pos=1234; 
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.31',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;


-- 启动slave
#start slave
start replica;

4、主库解锁

unlock tables;
SET @@GLOBAL.read_only = OFF;

5、配置双主模式

stop slave;
reset slave all;

CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.35',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2023',SOURCE_AUTO_POSITION = 1;

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
                  Source_Host:  222.24.203.31
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
                  Source_Host:  222.24.203.31
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
                  Source_Host:  222.24.203.35
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
2024-03-11T15:52:24.709143+08:00 5 [ERROR] [MY-010584] [Repl] Replica I/O for channel '': Error connecting to source 'repl@ 222.24.203.35:3306'. This was attempt 1/86400, with a delay of 60 seconds between attempts. Message: Authentication plugin 'caching_sha2_password' reported error: Authentication requires secure connection. Error_code: MY-002061
2024-03-11T15:52:42.080809+08:00 52 [Warning] [MY-013360] [Server] Plugin mysql_native_password reported: ''mysql_native_password' is deprecated and will be removed in a future release. Please use caching_sha2_password instead'
```

```mysql
mysql> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Connecting to source
                  Source_Host:  222.24.203.31
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
                Last_IO_Error: Error connecting to source 'repl@ 222.24.203.31:3306'. This was attempt 12/86400, with a delay of 60 seconds between attempts. Message: Access denied for user 'repl'@'222.24.203.35' (using password: YES)
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
mysql -u repl -p -h  222.24.203.31
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
                  Source_Host:  222.24.203.31
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
                  Source_Host:  222.24.203.31
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





##### 9) 主库有记录，从库没有记录，只在从库补充单条记录

#故障原因

```logs
在从库用 SET GTID_NEXT=...; BEGIN; COMMIT; 注入了空事务来“消化”冲突 GTID，所以该事务在从库被标记为已执行，但实际业务数据没有落地——因此现在复制继续跑、而从库缺这条账号记录，这是预期结果（但造成主从轻微不一致）
```

#从库操作logs

```bash
[root@mysql02 fw]# tail  -20f /data/mysql/error.log
2025-11-19T02:07:41.646879+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4113ms to flush 10000 and evict 0 pages
2025-11-19T02:07:48.002490+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4355ms to flush 10000 and evict 0 pages
2025-11-19T02:07:54.348300+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4345ms to flush 10000 and evict 0 pages
2025-11-19T02:08:02.503364+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4154ms to flush 10000 and evict 0 pages
2025-11-19T05:08:37.446149+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4028ms to flush 10000 and evict 0 pages
2025-11-19T05:08:46.730706+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4284ms to flush 10000 and evict 0 pages
2025-11-19T05:08:52.988072+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4257ms to flush 10000 and evict 0 pages
2025-11-19T05:08:58.207135+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4218ms to flush 10000 and evict 0 pages
2025-11-20T02:07:34.494949+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4194ms to flush 10000 and evict 0 pages
2025-11-20T02:07:40.753262+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4258ms to flush 10000 and evict 0 pages
2025-11-20T02:07:47.162612+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4409ms to flush 10000 and evict 0 pages
2025-11-20T02:07:54.619455+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4456ms to flush 10000 and evict 0 pages
2025-11-20T05:05:56.579547+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4008ms to flush 10000 and evict 0 pages
2025-11-20T05:06:03.142946+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4563ms to flush 10000 and evict 0 pages
2025-11-20T05:06:10.155403+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 5012ms to flush 10000 and evict 0 pages
2025-11-20T05:06:18.044275+08:00 0 [Note] [MY-011953] [InnoDB] Page cleaner took 4888ms to flush 10000 and evict 0 pages
2025-11-20T14:55:50.143398+08:00 5388168 [ERROR] [MY-010584] [Repl] Replica SQL for channel '': Worker 2 failed executing transaction 'af179f66-7990-11ee-97cc-fa163e1255d2:77621204' at source log mysql-bin.000904, end_log_pos 19717894; Could not execute Write_rows event on table cas_server.tb_account; Duplicate entry '2510001' for key 'tb_account.UQ_USERNAME', Error_code: 1062; handler error HA_ERR_FOUND_DUPP_KEY; the event's source log mysql-bin.000904, end_log_pos 19717894, Error_code: MY-001062
2025-11-20T14:55:50.151123+08:00 5388166 [ERROR] [MY-010586] [Repl] Error running query, replica SQL thread aborted. Fix the problem, and restart the replica SQL thread with "START REPLICA". We stopped at log 'mysql-bin.000904' position 19708198
2025-11-24T18:07:30.160395+08:00 5388165 [Warning] [MY-010897] [Repl] Storing MySQL user name or password information in the connection metadata repository is not secure and is therefore not recommended. Please consider using the USER and PASSWORD connection options for START REPLICA; see the 'START REPLICA Syntax' in the MySQL Manual for more information.
2025-11-24T18:07:30.193541+08:00 5388165 [System] [MY-014002] [Repl] Replica receiver thread for channel '': connected to source 'repl@10.20.12.136:3306' with server_uuid=af179f66-7990-11ee-97cc-fa163e1255d2, server_id=136. Starting GTID-based replication.
^C
[root@mysql02 fw]# mysql
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 32518348
Server version: 8.0.35 MySQL Community Server - GPL

Copyright (c) 2000, 2023, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

root@localhost:mysql.sock [(none)]> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.20.12.136
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000911
          Read_Source_Log_Pos: 334924396
               Relay_Log_File: relay-bin.002711
                Relay_Log_Pos: 19708374
        Relay_Source_Log_File: mysql-bin.000904
           Replica_IO_Running: Yes
          Replica_SQL_Running: No
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 1062
                   Last_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 2 failed executing transaction 'af179f66-7990-11ee-97cc-fa163e1255d2:77621204' at source log mysql-bin.000904, end_log_pos 19717894. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 19708198
              Relay_Log_Space: 4122132606
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
               Last_SQL_Errno: 1062
               Last_SQL_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 2 failed executing transaction 'af179f66-7990-11ee-97cc-fa163e1255d2:77621204' at source log mysql-bin.000904, end_log_pos 19717894. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 136
                  Source_UUID: af179f66-7990-11ee-97cc-fa163e1255d2
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State:
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp: 251120 14:55:50
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-78375385
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-77621203,
b00ea401-7990-11ee-a316-fa163e3f7e56:1-21
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

root@localhost:mysql.sock [(none)]> STOP REPLICA;
Query OK, 0 rows affected (0.01 sec)


root@localhost:mysql.sock [(none)]> SELECT * FROM cas_server.tb_account WHERE username='2510001'
    -> ;
+----------------------------------+------------+---------+-------------+---------------------+--------------+---------------------+----------------+-------------+----------+----------------------------------+-------------+---------+---------------------+--------------------+-------------------------+--------------+---------+--------+----------------------------------+--------+---------------+---------------+-------------+----------------------------------+
| ID                               | COMPANY_ID | DELETED | ADD_ACCOUNT | ADD_TIME            | EDIT_ACCOUNT | EDIT_TIME           | DELETE_ACCOUNT | DELETE_TIME | USERNAME | PASSWORD                         | DESCRIPTION | ENABLED | ACCOUNT_NON_EXPIRED | ACCOUNT_NON_LOCKED | CREDENTIALS_NON_EXPIRED | IDENTITY_    | USER_ID | NAME   | USER_NO                          | MOBILE | EMAIL_ADDRESS | IDENTITY_TYPE | IDENTITY_NO | EXTERNAL_ID                      |
+----------------------------------+------------+---------+-------------+---------------------+--------------+---------------------+----------------+-------------+----------+----------------------------------+-------------+---------+---------------------+--------------------+-------------------------+--------------+---------+--------+----------------------------------+--------+---------------+---------------+-------------+----------------------------------+
| 78cacdc0ad9311f0c7e50130648a5cc0 | 1          |       0 | anonymous   | 2025-10-20 17:02:11 | anonymous    | 2025-10-20 17:03:32 | NULL           | NULL        | 2510001  | 767c22d0ad9311f0498bc9f52b2637bd | NULL        |       1 |                   1 |                  1 |                       1 | 临时人员     | NULL    | 王帅   | 78c68801ad9311f0c7e50130648a5cc0 | NULL   | NULL          | NULL          | NULL        | 78cacdc0ad9311f0c7e50130648a5cc0 |
+----------------------------------+------------+---------+-------------+---------------------+--------------+---------------------+----------------+-------------+----------+----------------------------------+-------------+---------+---------------------+--------------------+-------------------------+--------------+---------+--------+----------------------------------+--------+---------------+---------------+-------------+----------------------------------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SELECT * FROM cas_server.tb_account WHERE username='2510001'\G
*************************** 1. row ***************************
                     ID: 78cacdc0ad9311f0c7e50130648a5cc0
             COMPANY_ID: 1
                DELETED: 0
            ADD_ACCOUNT: anonymous
               ADD_TIME: 2025-10-20 17:02:11
           EDIT_ACCOUNT: anonymous
              EDIT_TIME: 2025-10-20 17:03:32
         DELETE_ACCOUNT: NULL
            DELETE_TIME: NULL
               USERNAME: 2510001
               PASSWORD: 767c22d0ad9311f0498bc9f52b2637bd
            DESCRIPTION: NULL
                ENABLED: 1
    ACCOUNT_NON_EXPIRED: 1
     ACCOUNT_NON_LOCKED: 1
CREDENTIALS_NON_EXPIRED: 1
              IDENTITY_: 临时人员
                USER_ID: NULL
                   NAME: 王帅
                USER_NO: 78c68801ad9311f0c7e50130648a5cc0
                 MOBILE: NULL
          EMAIL_ADDRESS: NULL
          IDENTITY_TYPE: NULL
            IDENTITY_NO: NULL
            EXTERNAL_ID: 78cacdc0ad9311f0c7e50130648a5cc0
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State:
                  Source_Host: 10.20.12.136
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000911
          Read_Source_Log_Pos: 334980904
               Relay_Log_File: relay-bin.002711
                Relay_Log_Pos: 19708374
        Relay_Source_Log_File: mysql-bin.000904
           Replica_IO_Running: No
          Replica_SQL_Running: No
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 1062
                   Last_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 2 failed executing transaction 'af179f66-7990-11ee-97cc-fa163e1255d2:77621204' at source log mysql-bin.000904, end_log_pos 19717894. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 19708198
              Relay_Log_Space: 4122189114
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
               Last_SQL_Errno: 1062
               Last_SQL_Error: Coordinator stopped because there were error(s) in the worker(s). The most recent failure being: Worker 2 failed executing transaction 'af179f66-7990-11ee-97cc-fa163e1255d2:77621204' at source log mysql-bin.000904, end_log_pos 19717894. See error log and/or performance_schema.replication_applier_status_by_worker table for more details about this failure or others, if any.
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 136
                  Source_UUID: af179f66-7990-11ee-97cc-fa163e1255d2
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State:
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp: 251120 14:55:50
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-78375431
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-77621203,
b00ea401-7990-11ee-a316-fa163e3f7e56:1-21
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

root@localhost:mysql.sock [(none)]> stop replica;
Query OK, 0 rows affected, 1 warning (0.00 sec)

root@localhost:mysql.sock [(none)]>
root@localhost:mysql.sock [(none)]>  set @@session.gtid_next='af179f66-7990-11ee-97cc-fa163e1255d2:77621204';
Query OK, 0 rows affected (0.00 sec)

root@localhost:mysql.sock [(none)]>  begin;
Query OK, 0 rows affected (0.00 sec)

root@localhost:mysql.sock [(none)]>  commit;
Query OK, 0 rows affected (0.00 sec)

root@localhost:mysql.sock [(none)]>
root@localhost:mysql.sock [(none)]>
root@localhost:mysql.sock [(none)]>  set @@session.gtid_next=automatic;
Query OK, 0 rows affected (0.00 sec)

root@localhost:mysql.sock [(none)]>
root@localhost:mysql.sock [(none)]>  start replica;
Query OK, 0 rows affected (0.04 sec)

root@localhost:mysql.sock [(none)]>
root@localhost:mysql.sock [(none)]>  SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.20.12.136
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000911
          Read_Source_Log_Pos: 335141472
               Relay_Log_File: relay-bin.002711
                Relay_Log_Pos: 19985339
        Relay_Source_Log_File: mysql-bin.000904
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
          Exec_Source_Log_Pos: 19985163
              Relay_Log_Space: 4122350189
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 358033
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
    Replica_SQL_Running_State: Waiting for dependent transaction to commit
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-78375574
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-77621427,
b00ea401-7990-11ee-a316-fa163e3f7e56:1-21
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

root@localhost:mysql.sock [(none)]> SELECT * FROM cas_server.tb_account WHERE username='2510001'\G
Empty set (0.00 sec)

```

#手工补齐从库缺失的那条记录

```sql
-- 仅暂停 SQL 线程即可（IO 线程保持拉取）
STOP REPLICA SQL_THREAD;

-- 避免写本地 binlog
SET SQL_LOG_BIN=0;

INSERT INTO cas_server.tb_account
( ID, COMPANY_ID, DELETED, ADD_ACCOUNT, ADD_TIME, EDIT_ACCOUNT, EDIT_TIME,
  DELETE_ACCOUNT, DELETE_TIME, USERNAME, PASSWORD, DESCRIPTION,
  ENABLED, ACCOUNT_NON_EXPIRED, ACCOUNT_NON_LOCKED, CREDENTIALS_NON_EXPIRED,
  IDENTITY_, USER_ID, NAME, USER_NO, MOBILE, EMAIL_ADDRESS,
  IDENTITY_TYPE, IDENTITY_NO, EXTERNAL_ID )
VALUES
('f5352330c5dd11f023929d6fbb10da2f', 1, 0, 'anonymous', '2025-11-20 14:55:50',
 'anonymous', '2025-11-20 14:56:13', NULL, NULL, '2510001',
 '{bcrypt}$2a$04$STYMV/fXvAbA0ybtLaSuDubChWK6s3G5EbzQOmLccdt4T4lmaV8.q', '',
 1, 1, 1, 1,
 '劳务派遣', 'f5301a20c5dd11f023929d6fbb10da2f', '刘彤', 'f5301a21c5dd11f023929d6fbb10da2f',
 NULL, NULL, '居民身份证', '230622199502074064', 'f5352330c5dd11f023929d6fbb10da2f');

-- 恢复本地 binlog
SET SQL_LOG_BIN=1;

START REPLICA SQL_THREAD;
```

#从库确认

```sql
SELECT * FROM cas_server.tb_account WHERE username='2510001'\G
SHOW REPLICA STATUS\G   -- 期望 IO/SQL 都是 Yes
```



#从库确认logs

```sql
root@localhost:mysql.sock [(none)]>  SHOW REPLICA STATUS \G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.20.12.136
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000911
          Read_Source_Log_Pos: 335622633
               Relay_Log_File: relay-bin.002717
                Relay_Log_Pos: 321576381
        Relay_Source_Log_File: mysql-bin.000906
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
          Exec_Source_Log_Pos: 321576205
              Relay_Log_Space: 3048697450
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 232693
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
    Replica_SQL_Running_State: Waiting for dependent transaction to commit
           Source_Retry_Count: 86400
                  Source_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Source_SSL_Crl:
           Source_SSL_Crlpath:
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-78376026
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-77846294,
b00ea401-7990-11ee-a316-fa163e3f7e56:1-21
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

root@localhost:mysql.sock [(none)]> SELECT * FROM cas_server.tb_account WHERE username='2510001'\G
*************************** 1. row ***************************
                     ID: f5352330c5dd11f023929d6fbb10da2f
             COMPANY_ID: 1
                DELETED: 0
            ADD_ACCOUNT: anonymous
               ADD_TIME: 2025-11-20 14:55:50
           EDIT_ACCOUNT: anonymous
              EDIT_TIME: 2025-11-20 14:56:13
         DELETE_ACCOUNT: NULL
            DELETE_TIME: NULL
               USERNAME: 2510001
               PASSWORD: {bcrypt}$2a$04$STYMV/fXvAbA0ybtLaSuDubChWK6s3G5EbzQOmLccdt4T4lmaV8.q
            DESCRIPTION:
                ENABLED: 1
    ACCOUNT_NON_EXPIRED: 1
     ACCOUNT_NON_LOCKED: 1
CREDENTIALS_NON_EXPIRED: 1
              IDENTITY_: 劳务派遣
                USER_ID: f5301a20c5dd11f023929d6fbb10da2f
                   NAME: 刘彤
                USER_NO: f5301a21c5dd11f023929d6fbb10da2f
                 MOBILE: NULL
          EMAIL_ADDRESS: NULL
          IDENTITY_TYPE: 居民身份证
            IDENTITY_NO: 230622199502074064
            EXTERNAL_ID: f5352330c5dd11f023929d6fbb10da2f
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SELECT USERNAME, COUNT(*) c FROM cas_server.tb_account GROUP BY USERNAME HAVING c>1;
Empty set (0.02 sec)

root@localhost:mysql.sock [(none)]> SELECT COUNT(*) FROM cas_server.tb_account;
+----------+
| COUNT(*) |
+----------+
|    52504 |
+----------+
1 row in set (0.33 sec)

root@localhost:mysql.sock [(none)]>

```

#主库确认Logs

```sql
root@localhost:mysql.sock [(none)]> SHOW REPLICA STATUS\G
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.20.12.137
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000758
          Read_Source_Log_Pos: 250078915
               Relay_Log_File: relay-bin.001516
                Relay_Log_Pos: 453
        Relay_Source_Log_File: mysql-bin.000758
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
          Exec_Source_Log_Pos: 250078915
              Relay_Log_Space: 784
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
           Retrieved_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:77621204,
b00ea401-7990-11ee-a316-fa163e3f7e56:1-21
            Executed_Gtid_Set: af179f66-7990-11ee-97cc-fa163e1255d2:1-78376384,
b00ea401-7990-11ee-a316-fa163e3f7e56:1-21
                Auto_Position: 1
         Replicate_Rewrite_DB:
                 Channel_Name:
           Source_TLS_Version:
       Source_public_key_path:
        Get_Source_public_key: 0
            Network_Namespace:
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SELECT * FROM cas_server.tb_account WHERE username='2510001'\G
*************************** 1. row ***************************
                     ID: f5352330c5dd11f023929d6fbb10da2f
             COMPANY_ID: 1
                DELETED: 0
            ADD_ACCOUNT: anonymous
               ADD_TIME: 2025-11-20 14:55:50
           EDIT_ACCOUNT: anonymous
              EDIT_TIME: 2025-11-20 14:56:13
         DELETE_ACCOUNT: NULL
            DELETE_TIME: NULL
               USERNAME: 2510001
               PASSWORD: {bcrypt}$2a$04$STYMV/fXvAbA0ybtLaSuDubChWK6s3G5EbzQOmLccdt4T4lmaV8.q
            DESCRIPTION:
                ENABLED: 1
    ACCOUNT_NON_EXPIRED: 1
     ACCOUNT_NON_LOCKED: 1
CREDENTIALS_NON_EXPIRED: 1
              IDENTITY_: 劳务派遣
                USER_ID: f5301a20c5dd11f023929d6fbb10da2f
                   NAME: 刘彤
                USER_NO: f5301a21c5dd11f023929d6fbb10da2f
                 MOBILE: NULL
          EMAIL_ADDRESS: NULL
          IDENTITY_TYPE: 居民身份证
            IDENTITY_NO: 230622199502074064
            EXTERNAL_ID: f5352330c5dd11f023929d6fbb10da2f
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]>


root@localhost:mysql.sock [(none)]> SELECT COUNT(*) FROM cas_server.tb_account;
+----------+
| COUNT(*) |
+----------+
|    52504 |
+----------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]>


```



##### 10) 主库有数据库账户A，从库缺少该数据库账户，只在从库添加该账户

```mysql
#从库报错
2025-11-21T20:05:50.759488+08:00 3093 [ERROR] [MY-010584] [Repl] Replica SQL for channel '': Worker 1 failed executing transaction 'a36b6a91-5adc-11f0-864f-286ed48a126e:197692526' at source log mysql-bin.000414, end_log_pos 244248430; Error 'Operation ALTER USER failed for 'authx_log_sjh'@'%'' on query. Default database: 'mysql'. Query: 'ALTER USER 'authx_log_sjh'@'%' IDENTIFIED WITH 'mysql_native_password' AS '*C8AD5D8DE8FEAA56857958402DF5E5DF14B671F8' PASSWORD EXPIRE NEVER', Error_code: MY-001396
2025-11-21T20:05:50.760816+08:00 3092 [ERROR] [MY-010586] [Repl] Error running query, replica SQL thread aborted. Fix the problem, and restart the replica SQL thread with "START REPLICA". We stopped at log 'mysql-bin.000414' position 244235477



#主库

root@localhost:mysql.sock [mysql]> SHOW CREATE USER 'authx_log_sjh'@'%'\G
*************************** 1. row ***************************
CREATE USER for authx_log_sjh@%: CREATE USER `authx_log_sjh`@`%` IDENTIFIED WITH 'mysql_native_password' AS '*C8AD5D8DE8FEAA56857958402DF5E5DF14B671F8' REQUIRE NONE PASSWORD EXPIRE NEVER ACCOUNT UNLOCK PASSWORD HISTORY DEFAULT PASSWORD REUSE INTERVAL DEFAULT PASSWORD REQUIRE CURRENT DEFAULT
1 row in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SHOW GRANTS FOR 'authx_log_sjh'@'%'\G
*************************** 1. row ***************************
Grants for authx_log_sjh@%: GRANT USAGE ON *.* TO `authx_log_sjh`@`%`
*************************** 2. row ***************************
Grants for authx_log_sjh@%: GRANT SELECT ON `authx_log`.`tb_l_authentication_log` TO `authx_log_sjh`@`%`
*************************** 3. row ***************************
Grants for authx_log_sjh@%: GRANT SELECT ON `authx_log`.`tb_l_online_log` TO `authx_log_sjh`@`%`
*************************** 4. row ***************************
Grants for authx_log_sjh@%: GRANT SELECT ON `authx_log`.`tb_l_service_access_log` TO `authx_log_sjh`@`%`
4 rows in set (0.00 sec)

root@localhost:mysql.sock [mysql]>

#从库缺少该账户


#从库添加该账户

-- 仅暂停 SQL 线程即可（IO 线程保持拉取）
STOP REPLICA SQL_THREAD;

-- 避免写本地 binlog
SET SQL_LOG_BIN=0;


-- 2）创建和主库完全一致的账号（照你贴的 SHOW CREATE USER 原样抄）
CREATE USER `authx_log_sjh`@`%`
  IDENTIFIED WITH 'mysql_native_password'
  AS '*C8AD5D8DE8FEAA56857958402DF5E5DF14B671F8'
  REQUIRE NONE
  PASSWORD EXPIRE NEVER
  ACCOUNT UNLOCK
  PASSWORD HISTORY DEFAULT
  PASSWORD REUSE INTERVAL DEFAULT
  PASSWORD REQUIRE CURRENT DEFAULT;

-- 3）按主库的授权，一条条补上（照你贴的 SHOW GRANTS）
GRANT USAGE ON *.* TO `authx_log_sjh`@`%`;
GRANT SELECT ON `authx_log`.`tb_l_authentication_log` TO `authx_log_sjh`@`%`;
GRANT SELECT ON `authx_log`.`tb_l_online_log`          TO `authx_log_sjh`@`%`;
GRANT SELECT ON `authx_log`.`tb_l_service_access_log`  TO `authx_log_sjh`@`%`;

-- 4）恢复本会话的 binlog 记录
SET sql_log_bin = 1;



START REPLICA SQL_THREAD;



-- 跳过报错的GTID
STOP REPLICA;

SET GTID_NEXT='0f76fa28-5f74-11ef-be67-fefcfe4ed56d:468373884';
BEGIN; COMMIT;
SET GTID_NEXT='AUTOMATIC';

START REPLICA;

```



##### 11) 从库落后主库太多，追赶慢

#临时参数调整

```sql
#追数据阶段：临时降低从库“落盘/刷盘”开销（吞吐提升通常很明显）

#这招对“回放慢”特别有效，因为回放本质是不断 COMMIT。

#在从库执行（追赶期间临时调，追平后再改回去）：

SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';
SHOW VARIABLES LIKE 'sync_binlog';

SET GLOBAL innodb_flush_log_at_trx_commit = 2;
SET GLOBAL sync_binlog = 0;


#innodb_flush_log_at_trx_commit=2：每秒刷一次日志（崩溃可能丢 1 秒内事务，但这是从库回放，通常可接受）

#sync_binlog=0：binlog 不强制每次刷盘（如果你的从库还开着 binlog / log_replica_updates，这个很关键）

#追平后建议恢复更稳的值（按你们的可靠性要求）：

SET GLOBAL innodb_flush_log_at_trx_commit = 1;
SET GLOBAL sync_binlog = 1;
```



#分析过程

```
mysql双主模式，但是只有一路主数据库进行写入操作，另一路作为从库，进行读操作。当前从库在同步报错后，进行了人工修复后恢复双主模式，但是一直落后于当前的主数据库。有没有提高同步效率的办法？
root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000796
          Read_Source_Log_Pos: 515555540
               Relay_Log_File: relay-bin.003666
                Relay_Log_Pos: 216654590
        Relay_Source_Log_File: mysql-bin.000454
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
          Exec_Source_Log_Pos: 216654398
              Relay_Log_Space: 183558180613
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5729924
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406747334
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219274744,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000796
          Read_Source_Log_Pos: 515608426
               Relay_Log_File: relay-bin.003666
                Relay_Log_Pos: 216967740
        Relay_Source_Log_File: mysql-bin.000454
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
          Exec_Source_Log_Pos: 216967548
              Relay_Log_Space: 183558233499
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5729925
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406747382
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219275054,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000796
          Read_Source_Log_Pos: 515657500
               Relay_Log_File: relay-bin.003666
                Relay_Log_Pos: 217361116
        Relay_Source_Log_File: mysql-bin.000454
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
          Exec_Source_Log_Pos: 217360924
              Relay_Log_Space: 183558282573
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5729926
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406747427
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219275405,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>

```

#从库同步初步分析

```
从你贴的 SHOW REPLICA STATUS\G 看，IO 线程是正常拉取的（Read_Source_Log_Pos 一直涨），但 SQL 线程应用很慢，而且 Relay_Log_Space 已经堆到 183GB；Replica_SQL_Running_State: Waiting for dependent transaction to commit 也很典型：回放端受“提交顺序/依赖”限制，吞吐上不去。这种情况下，提速主要就两条路：“并行回放 + 降低落盘开销”；如果落后太久，**“直接重建从库”**通常更快。
```



#从库查询状态

```sql
root@localhost:mysql.sock [(none)]> show processlist;
+---------+-----------------+--------------------+-----------+------------------+---------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------------------+
| Id      | User            | Host               | db        | Command          | Time    | State                                                           | Info                                                                                                 |
+---------+-----------------+--------------------+-----------+------------------+---------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------------------+
|       7 | event_scheduler | localhost          | NULL      | Daemon           | 3457397 | Waiting on empty queue                                          | NULL                                                                                                 |
|   87921 | repl            | 10.40.10.132:45110 | NULL      | Binlog Dump GTID | 2650235 | Source has sent all binlog to replica; waiting for more updates | NULL                                                                                                 |
| 1349811 | system user     | connecting host    | NULL      | Connect          |  172410 | Waiting for source to send event                                | NULL                                                                                                 |
| 1358108 | system user     |                    | NULL      | Query            |       0 | Waiting for dependent transaction to commit                     | NULL                                                                                                 |
| 1358109 | system user     |                    | authx_log | Query            | 5730507 | Applying batch of row changes (write)                           | insert into TB_L_APPLY_CALL_LOG (ADD_ACCOUNT, ADD_TIME, COMPANY_ID, DELETE_ACCOUNT, DELETE_TIME, DEL |
| 1358110 | system user     |                    | authx_log | Query            | 5730507 | Applying batch of row changes (write)                           | insert into TB_L_APPLY_CALL_LOG (ADD_ACCOUNT, ADD_TIME, COMPANY_ID, DELETE_ACCOUNT, DELETE_TIME, DEL |
| 1358111 | system user     |                    | authx_log | Query            | 5730507 | Applying batch of row changes (write)                           | insert into TB_L_APPLY_CALL_LOG (ADD_ACCOUNT, ADD_TIME, COMPANY_ID, DELETE_ACCOUNT, DELETE_TIME, DEL |
| 1358112 | system user     |                    | authx_log | Query            | 5730507 | Applying batch of row changes (write)                           | insert into TB_L_APPLY_CALL_LOG (ADD_ACCOUNT, ADD_TIME, COMPANY_ID, DELETE_ACCOUNT, DELETE_TIME, DEL |
| 1358113 | system user     |                    | NULL      | Query            | 5730507 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358114 | system user     |                    | NULL      | Query            | 5730508 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358115 | system user     |                    | NULL      | Query            | 5730508 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358116 | system user     |                    | NULL      | Query            | 5730508 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358117 | system user     |                    | NULL      | Query            | 5730508 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358118 | system user     |                    | NULL      | Query            | 5730508 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358119 | system user     |                    | NULL      | Query            | 5730521 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358120 | system user     |                    | NULL      | Query            | 5730521 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358121 | system user     |                    | NULL      | Query            | 5730521 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358122 | system user     |                    | NULL      | Query            | 5730521 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358123 | system user     |                    | NULL      | Query            | 5730521 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358124 | system user     |                    | NULL      | Query            | 5730521 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1436164 | root            | localhost          | NULL      | Query            |       0 | init                                                            | show processlist                                                                                     |
+---------+-----------------+--------------------+-----------+------------------+---------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------------------+
21 rows in set, 1 warning (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'replica_parallel%';
+--------------------------+---------------+
| Variable_name            | Value         |
+--------------------------+---------------+
| replica_parallel_type    | LOGICAL_CLOCK |
| replica_parallel_workers | 16            |
+--------------------------+---------------+
2 rows in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'transaction_write_set_extraction';
+----------------------------------+----------+
| Variable_name                    | Value    |
+----------------------------------+----------+
| transaction_write_set_extraction | XXHASH64 |
+----------------------------------+----------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'binlog_transaction_dependency_tracking';
+----------------------------------------+--------------+
| Variable_name                          | Value        |
+----------------------------------------+--------------+
| binlog_transaction_dependency_tracking | COMMIT_ORDER |
+----------------------------------------+--------------+
1 row in set (0.01 sec)

root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'replica_preserve_commit_order';
+-------------------------------+-------+
| Variable_name                 | Value |
+-------------------------------+-------+
| replica_preserve_commit_order | OFF   |
+-------------------------------+-------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';
+--------------------------------+-------+
| Variable_name                  | Value |
+--------------------------------+-------+
| innodb_flush_log_at_trx_commit | 1     |
+--------------------------------+-------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]>
root@localhost:mysql.sock [(none)]> SELECT * FROM performance_schema.replication_applier_status_by_worker\G
*************************** 1. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 1
                                              THREAD_ID: 1358153
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479592
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.843178
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.843178
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:55.024100
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:55.032866
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 2. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 2
                                              THREAD_ID: 1358154
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479590
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.836248
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.836248
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:55.015401
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:55.021981
                                   APPLYING_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479593
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.843212
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.843212
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:55.024115
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 3. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 3
                                              THREAD_ID: 1358155
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479559
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.712290
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.712290
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:54.753865
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:54.760610
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 4. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 4
                                              THREAD_ID: 1358156
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479556
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.693681
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.693681
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:54.746359
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:54.753790
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 5. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 5
                                              THREAD_ID: 1358157
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479532
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.603581
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.603581
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:54.569421
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:54.575780
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 6. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 6
                                              THREAD_ID: 1358158
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479426
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.239433
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:35.239433
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:53.675908
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:53.679387
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 7. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 7
                                              THREAD_ID: 1358159
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219479134
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:34.185192
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:34.185192
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:51.410411
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:51.413617
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 8. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 8
                                              THREAD_ID: 1358160
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219478952
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:33.491548
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:33.491548
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:50.196109
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:50.230919
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 9. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 9
                                              THREAD_ID: 1358161
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219478905
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:33.321266
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:33.321266
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:49.717092
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:49.724764
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 10. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 10
                                              THREAD_ID: 1358162
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219478906
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:33.321268
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:33.321268
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:49.717112
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:49.719879
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 11. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 11
                                              THREAD_ID: 1358163
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219478179
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:30.628222
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:30.628222
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:44.112358
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:44.118143
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 12. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 12
                                              THREAD_ID: 1358164
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219478180
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:30.628226
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:30.628226
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:44.112384
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:44.118897
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 13. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 13
                                              THREAD_ID: 1358165
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219474211
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:26:16.002072
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:26:16.002072
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:18:13.410898
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:18:13.415269
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 14. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 14
                                              THREAD_ID: 1358166
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219467921
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:25:52.779292
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:25:52.779292
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:17:21.497691
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:17:21.519021
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 15. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 15
                                              THREAD_ID: 1358167
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219467922
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:25:52.779295
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:25:52.779295
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:17:21.497726
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:17:21.501034
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
*************************** 16. row ***************************
                                           CHANNEL_NAME:
                                              WORKER_ID: 16
                                              THREAD_ID: 1358168
                                          SERVICE_STATE: ON
                                      LAST_ERROR_NUMBER: 0
                                     LAST_ERROR_MESSAGE:
                                   LAST_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                               LAST_APPLIED_TRANSACTION: a36b6a91-5adc-11f0-864f-286ed48a126e:219467923
     LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 2025-10-19 02:25:52.779297
    LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 2025-10-19 02:25:52.779297
         LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP: 2025-12-24 10:17:21.497730
           LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP: 2025-12-24 10:17:21.505583
                                   APPLYING_TRANSACTION:
         APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
        APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP: 0000-00-00 00:00:00.000000
             APPLYING_TRANSACTION_START_APPLY_TIMESTAMP: 0000-00-00 00:00:00.000000
                 LAST_APPLIED_TRANSACTION_RETRIES_COUNT: 0
   LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
  LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
                     APPLYING_TRANSACTION_RETRIES_COUNT: 0
       APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER: 0
      APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE:
    APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP: 0000-00-00 00:00:00.000000
16 rows in set (0.09 sec)

root@localhost:mysql.sock [(none)]>


```

#继续分析

```
IO 线程已经追到源库头部（源库上 Binlog Dump GTID 显示 Source has sent all binlog… waiting for more updates）

SQL 回放线程在追历史（LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP 还是 2025-10-19，而现在是 2025-12-24）

虽然你开了 16 个 worker + LOGICAL_CLOCK，但 processlist 里只有少数 worker 在忙，其它都在等 Coordinator——典型原因就是：源库的依赖跟踪仍是 COMMIT_ORDER，并行度被依赖判定“锁死”了。
```

#临时从库调整参数

```sql
#追数据阶段：临时降低从库“落盘/刷盘”开销（吞吐提升通常很明显）

#这招对“回放慢”特别有效，因为回放本质是不断 COMMIT。

#在从库执行（追赶期间临时调，追平后再改回去）：

SET GLOBAL innodb_flush_log_at_trx_commit = 2;
SET GLOBAL sync_binlog = 0;


#innodb_flush_log_at_trx_commit=2：每秒刷一次日志（崩溃可能丢 1 秒内事务，但这是从库回放，通常可接受）

#sync_binlog=0：binlog 不强制每次刷盘（如果你的从库还开着 binlog / log_replica_updates，这个很关键）

#追平后建议恢复更稳的值（按你们的可靠性要求）：

SET GLOBAL innodb_flush_log_at_trx_commit = 1;
SET GLOBAL sync_binlog = 1;
```



#修改参数后的效果

```sql
root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'sync_binlog';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| sync_binlog   | 0     |
+---------------+-------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';
+--------------------------------+-------+
| Variable_name                  | Value |
+--------------------------------+-------+
| innodb_flush_log_at_trx_commit | 2     |
+--------------------------------+-------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW PROCESSLIST;
+---------+-----------------+--------------------+-----------+------------------+---------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------------------+
| Id      | User            | Host               | db        | Command          | Time    | State                                                           | Info                                                                                                 |
+---------+-----------------+--------------------+-----------+------------------+---------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------------------+
|       7 | event_scheduler | localhost          | NULL      | Daemon           | 3458922 | Waiting on empty queue                                          | NULL                                                                                                 |
|   87921 | repl            | 10.40.10.132:45110 | NULL      | Binlog Dump GTID | 2651760 | Source has sent all binlog to replica; waiting for more updates | NULL                                                                                                 |
| 1349811 | system user     | connecting host    | NULL      | Connect          |  173935 | Waiting for source to send event                                | NULL                                                                                                 |
| 1358108 | system user     |                    | NULL      | Query            |       0 | Waiting for dependent transaction to commit                     | NULL                                                                                                 |
| 1358109 | system user     |                    | authx_log | Query            | 5731293 | Applying batch of row changes (write)                           | insert into TB_L_APPLY_CALL_LOG (ADD_ACCOUNT, ADD_TIME, COMPANY_ID, DELETE_ACCOUNT, DELETE_TIME, DEL |
| 1358110 | system user     |                    | NULL      | Query            | 5731293 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358111 | system user     |                    | NULL      | Query            | 5731293 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358112 | system user     |                    | NULL      | Query            | 5731293 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358113 | system user     |                    | NULL      | Query            | 5731293 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358114 | system user     |                    | NULL      | Query            | 5731293 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358115 | system user     |                    | NULL      | Query            | 5731293 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358116 | system user     |                    | NULL      | Query            | 5731294 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358117 | system user     |                    | NULL      | Query            | 5731294 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358118 | system user     |                    | NULL      | Query            | 5731294 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358119 | system user     |                    | NULL      | Query            | 5731294 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358120 | system user     |                    | NULL      | Query            | 5731335 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358121 | system user     |                    | NULL      | Query            | 5731335 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358122 | system user     |                    | NULL      | Query            | 5731335 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358123 | system user     |                    | NULL      | Query            | 5731350 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1358124 | system user     |                    | NULL      | Query            | 5731423 | Waiting for an event from Coordinator                           | NULL                                                                                                 |
| 1436786 | root            | localhost          | NULL      | Query            |       0 | init                                                            | SHOW PROCESSLIST                                                                                     |
+---------+-----------------+--------------------+-----------+------------------+---------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------------------+
21 rows in set, 1 warning (0.00 sec)

root@localhost:mysql.sock [(none)]> SELECT * FROM performance_schema.replication_applier_status_by_worker;
+--------------+-----------+-----------+---------------+-------------------+--------------------+----------------------------+------------------------------------------------+----------------------------------------------------+-----------------------------------------------------+------------------------------------------------+----------------------------------------------+------------------------------------------------+------------------------------------------------+-------------------------------------------------+--------------------------------------------+----------------------------------------+------------------------------------------------------+-------------------------------------------------------+---------------------------------------------------------+------------------------------------+--------------------------------------------------+---------------------------------------------------+-----------------------------------------------------+
| CHANNEL_NAME | WORKER_ID | THREAD_ID | SERVICE_STATE | LAST_ERROR_NUMBER | LAST_ERROR_MESSAGE | LAST_ERROR_TIMESTAMP       | LAST_APPLIED_TRANSACTION                       | LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP | LAST_APPLIED_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP | LAST_APPLIED_TRANSACTION_START_APPLY_TIMESTAMP | LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP | APPLYING_TRANSACTION                           | APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP | APPLYING_TRANSACTION_IMMEDIATE_COMMIT_TIMESTAMP | APPLYING_TRANSACTION_START_APPLY_TIMESTAMP | LAST_APPLIED_TRANSACTION_RETRIES_COUNT | LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER | LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE | LAST_APPLIED_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP | APPLYING_TRANSACTION_RETRIES_COUNT | APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_NUMBER | APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_MESSAGE | APPLYING_TRANSACTION_LAST_TRANSIENT_ERROR_TIMESTAMP |
+--------------+-----------+-----------+---------------+-------------------+--------------------+----------------------------+------------------------------------------------+----------------------------------------------------+-----------------------------------------------------+------------------------------------------------+----------------------------------------------+------------------------------------------------+------------------------------------------------+-------------------------------------------------+--------------------------------------------+----------------------------------------+------------------------------------------------------+-------------------------------------------------------+---------------------------------------------------------+------------------------------------+--------------------------------------------------+---------------------------------------------------+-----------------------------------------------------+
|              |         1 |   1358153 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622575 | 2025-10-19 02:35:35.224111                         | 2025-10-19 02:35:35.224111                          | 2025-12-24 10:37:08.780908                     | 2025-12-24 10:37:08.781915                   | a36b6a91-5adc-11f0-864f-286ed48a126e:219622578 | 2025-10-19 02:35:35.228213                     | 2025-10-19 02:35:35.228213                      | 2025-12-24 10:37:08.790247                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         2 |   1358154 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622576 | 2025-10-19 02:35:35.224369                         | 2025-10-19 02:35:35.224369                          | 2025-12-24 10:37:08.780939                     | 2025-12-24 10:37:08.790183                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         3 |   1358155 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622577 | 2025-10-19 02:35:35.226024                         | 2025-10-19 02:35:35.226024                          | 2025-12-24 10:37:08.780959                     | 2025-12-24 10:37:08.788361                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         4 |   1358156 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622569 | 2025-10-19 02:35:35.202299                         | 2025-10-19 02:35:35.202299                          | 2025-12-24 10:37:08.708642                     | 2025-12-24 10:37:08.709028                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         5 |   1358157 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622570 | 2025-10-19 02:35:35.204364                         | 2025-10-19 02:35:35.204364                          | 2025-12-24 10:37:08.708674                     | 2025-12-24 10:37:08.721487                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         6 |   1358158 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622529 | 2025-10-19 02:35:35.057101                         | 2025-10-19 02:35:35.057101                          | 2025-12-24 10:37:08.237879                     | 2025-12-24 10:37:08.238301                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         7 |   1358159 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622530 | 2025-10-19 02:35:35.057104                         | 2025-10-19 02:35:35.057104                          | 2025-12-24 10:37:08.237883                     | 2025-12-24 10:37:08.265305                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         8 |   1358160 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622480 | 2025-10-19 02:35:34.875366                         | 2025-10-19 02:35:34.875366                          | 2025-12-24 10:37:08.003714                     | 2025-12-24 10:37:08.004062                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |         9 |   1358161 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622481 | 2025-10-19 02:35:34.875369                         | 2025-10-19 02:35:34.875369                          | 2025-12-24 10:37:08.003729                     | 2025-12-24 10:37:08.013201                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |        10 |   1358162 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622482 | 2025-10-19 02:35:34.876346                         | 2025-10-19 02:35:34.876346                          | 2025-12-24 10:37:08.003741                     | 2025-12-24 10:37:08.027612                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |        11 |   1358163 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219622484 | 2025-10-19 02:35:34.876356                         | 2025-10-19 02:35:34.876356                          | 2025-12-24 10:37:08.004017                     | 2025-12-24 10:37:08.027543                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |        12 |   1358164 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219611417 | 2025-10-19 02:34:53.349077                         | 2025-10-19 02:34:53.349077                          | 2025-12-24 10:35:51.966328                     | 2025-12-24 10:35:51.992292                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |        13 |   1358165 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219611418 | 2025-10-19 02:34:53.349080                         | 2025-10-19 02:34:53.349080                          | 2025-12-24 10:35:51.966314                     | 2025-12-24 10:35:51.992032                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |        14 |   1358166 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219611419 | 2025-10-19 02:34:53.349083                         | 2025-10-19 02:34:53.349083                          | 2025-12-24 10:35:51.966343                     | 2025-12-24 10:35:51.977772                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |        15 |   1358167 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219607370 | 2025-10-19 02:34:38.560754                         | 2025-10-19 02:34:38.560754                          | 2025-12-24 10:35:23.469929                     | 2025-12-24 10:35:23.485376                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
|              |        16 |   1358168 | ON            |                 0 |                    | 0000-00-00 00:00:00.000000 | a36b6a91-5adc-11f0-864f-286ed48a126e:219587986 | 2025-10-19 02:33:25.558321                         | 2025-10-19 02:33:25.558321                          | 2025-12-24 10:33:13.432173                     | 2025-12-24 10:33:13.439635                   |                                                | 0000-00-00 00:00:00.000000                     | 0000-00-00 00:00:00.000000                      | 0000-00-00 00:00:00.000000                 |                                      0 |                                                    0 |                                                       | 0000-00-00 00:00:00.000000                              |                                  0 |                                                0 |                                                   | 0000-00-00 00:00:00.000000                          |
+--------------+-----------+-----------+---------------+-------------------+--------------------+----------------------------+------------------------------------------------+----------------------------------------------------+-----------------------------------------------------+------------------------------------------------+----------------------------------------------+------------------------------------------------+------------------------------------------------+-------------------------------------------------+--------------------------------------------+----------------------------------------+------------------------------------------------------+-------------------------------------------------------+---------------------------------------------------------+------------------------------------+--------------------------------------------------+---------------------------------------------------+-----------------------------------------------------+
16 rows in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW REPLICA STATUS\G
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 72490009
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 52621368
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 52621176
              Relay_Log_Space: 183115115424
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731298
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406845506
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219623949,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
                Auto_Position: 1
         Replicate_Rewrite_DB:
                 Channel_Name:
           Source_TLS_Version:
       Source_public_key_path:
        Get_Source_public_key: 0
            Network_Namespace:
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW REPLICA STATUS\G
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 72581174
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 52859877
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 52859685
              Relay_Log_Space: 183115206589
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731299
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406845615
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219624163,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
                Auto_Position: 1
         Replicate_Rewrite_DB:
                 Channel_Name:
           Source_TLS_Version:
       Source_public_key_path:
        Get_Source_public_key: 0
            Network_Namespace:
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> SHOW REPLICA STATUS\G
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 72813555
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 53345141
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 53344949
              Relay_Log_Space: 183115438970
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731301
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406845924
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219624597,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
                Auto_Position: 1
         Replicate_Rewrite_DB:
                 Channel_Name:
           Source_TLS_Version:
       Source_public_key_path:
        Get_Source_public_key: 0
            Network_Namespace:
1 row in set (0.01 sec)

root@localhost:mysql.sock [(none)]>

```



#效果并不明显，分析磁盘IO

```bash
从库：
root@localhost:mysql.sock [(none)]> SHOW VARIABLES LIKE 'replica_pending_jobs_size_max';
+-------------------------------+-----------+
| Variable_name                 | Value     |
+-------------------------------+-----------+
| replica_pending_jobs_size_max | 134217728 |
+-------------------------------+-----------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [(none)]> exit
Bye
[root@MHsql-db01B mysql]# iostat -x 1
Linux 4.19.90-24.4.v2101.ky10.x86_64 (MHsql-db01B)      12/24/2025      _x86_64_        (32 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.09    0.00    0.07    0.16    0.00   99.69

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             0.06      2.26     0.00   0.00    4.28    39.97    0.63      5.30     0.00   0.00    0.22     8.40    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.02
dm-1             0.01      0.02     0.00   0.00    5.29     4.09    0.04      0.18     0.00   0.00    5.21     4.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-2             5.70    330.13     0.00   0.00    9.31    57.94   69.65    728.85     0.00   0.00    0.56    10.46    0.00      0.00     0.00   0.00    0.00     0.00    0.09   4.78
dm-3             0.00      0.00     0.00   0.00    0.66     3.52    0.00      0.00     0.00   0.00    0.21    11.32    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vda              0.06      2.18     0.00   5.24    4.25    37.68    0.58      4.75     0.10  14.34    0.61     8.17    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.02
vdb              0.00      0.10     0.00   0.66    6.15    69.46    0.07      0.23     0.01  12.15    0.83     3.47    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdc              5.70    330.13     0.00   0.02    9.30    57.95   69.61    712.57     0.03   0.05    0.55    10.24    0.00      0.00     0.00   0.00    0.00     0.00    0.06   4.78


avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.31    0.00    0.22    3.78    0.00   95.69

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             0.00      0.00     0.00   0.00    0.00     0.00    2.00     24.00     0.00   0.00    2.00    12.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.40
dm-1             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-2           104.00   1664.00     0.00   0.00   11.65    16.00  631.00  13158.00     0.00   0.00    0.36    20.85    0.00      0.00     0.00   0.00    0.00     0.00    1.44  94.40
dm-3             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vda              0.00      0.00     0.00   0.00    0.00     0.00    2.00     24.00     0.00   0.00    0.50    12.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.40
vdb              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdc            104.00   1664.00     0.00   0.00   11.74    16.00  631.00  13137.00     0.00   0.00    0.39    20.82    0.00      0.00     0.00   0.00    0.00     0.00    1.03  94.40


avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.16    0.00    0.16    3.35    0.00   96.34

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-1             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-2            93.00   1488.00     0.00   0.00   13.29    16.00  104.00   2317.00     0.00   0.00    0.35    22.28    0.00      0.00     0.00   0.00    0.00     0.00    1.27  99.20
dm-3             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vda              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdb              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdc             93.00   1488.00     0.00   0.00   13.15    16.00  104.00   2310.50     0.00   0.00    0.46    22.22    0.00      0.00     0.00   0.00    0.00     0.00    1.06  99.20


avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.25    0.00    0.19    3.38    0.00   96.19

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-1             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-2           108.00   1728.00     0.00   0.00   11.81    16.00  129.00   2533.00     0.00   0.00    0.16    19.64    0.00      0.00     0.00   0.00    0.00     0.00    1.30  96.80
dm-3             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vda              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdb              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdc            107.00   1712.00     0.00   0.00   11.88    16.00  126.00   2523.00     3.00   2.33    0.43    20.02    0.00      0.00     0.00   0.00    0.00     0.00    1.06  96.80


avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.19    0.00    0.16    3.91    0.00   95.75

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-1             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-2           101.00   1616.00     0.00   0.00   13.43    16.00  105.00   2313.00     0.00   0.00    0.57    22.03    0.00      0.00     0.00   0.00    0.00     0.00    1.42  96.80
dm-3             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vda              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdb              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdc            102.00   1632.00     0.00   0.00   12.77    16.00  105.00   2304.50     0.00   0.00    0.54    21.95    0.00      0.00     0.00   0.00    0.00     0.00    1.14  96.40

^C
[root@MHsql-db01B mysql]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk
sr0              11:0    1 1024M  0 rom
vda             252:0    0  100G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   99G  0 part
  ├─rootvg-root 253:0    0  253G  0 lvm  /
  ├─rootvg-swap 253:1    0   16G  0 lvm  [SWAP]
  └─rootvg-home 253:3    0   30G  0 lvm  /home
vdb             252:16   0  200G  0 disk
└─rootvg-root   253:0    0  253G  0 lvm  /
vdc             252:32   0  1.5T  0 disk
└─datavg-datalv 253:2    0  1.5T  0 lvm  /data
[root@MHsql-db01B mysql]# pwd
/data/mysql
[root@MHsql-db01B mysql]# cat /etc/my.cnf|grep data
socket = /data/mysql/mysql.sock
datadir = /data/mysql
socket = /data/mysql/mysql.sock
innodb_data_file_path = ibdata1:1024M:autoextend
innodb_undo_directory = /data/mysql/mysql3306/data/undolog
[root@MHsql-db01B mysql]#

```



#分析

```
结论基本明确了：现在主要瓶颈在从库的 /data 盘（vdc/dm-2）I/O 已经接近打满，而不是 CPU。

iostat 里 dm-2 / vdc %util 94%~99%，r_await 11~13ms，CPU 95%+ idle → 存储 IOPS/延迟在限制回放速度

SHOW PROCESSLIST 里绝大多数 worker 在等 Coordinator，只有 1 个在持续 “Applying batch … insert TB_L_APPLY_CALL_LOG …” → 事务依赖/单表热点导致并行度很低（你主库还是 COMMIT_ORDER，这会进一步限制并行）

已经把最有效的“降刷盘”做了（innodb_flush_log_at_trx_commit=2、sync_binlog=0），下一步建议按下面做。
```



#建议

```sql
#从库调整参数
SET GLOBAL replica_pending_jobs_size_max = 1024*1024*1024;
```



```
1）把从库 replica_pending_jobs_size_max 提高（128MB 太小）

这个参数太小会导致 Coordinator 队列很快满，worker 喂不饱（尤其 row event 多的时候）。

从库执行即可（动态生效）：

SET GLOBAL replica_pending_jobs_size_max = 1024*1024*1024;  -- 1G


这是“低风险增益项”：主要吃内存，不改数据一致性。

2）主库把依赖跟踪从 COMMIT_ORDER 改成 WRITESET（对“后续事务”很关键）

你主库现在：

binlog_transaction_dependency_tracking = COMMIT_ORDER

transaction_write_set_extraction = XXHASH64（这个已 OK）

建议在主库改成：

SET PERSIST binlog_transaction_dependency_tracking = 'WRITESET';
SET PERSIST transaction_write_set_extraction = 'XXHASH64';
SET PERSIST binlog_transaction_dependency_history_size = 100000;

FLUSH BINARY LOGS;


这一步不会让历史两个月的 binlog 立刻变并行（历史部分仍然是 COMMIT_ORDER），但能避免“你一边追、一边新增写入又把你越拉越远”，并且对后续追赶会有帮助。

3）你现在是典型“单表日志写入拖慢回放”：TB_L_APPLY_CALL_LOG

TB_L_APPLY_CALL_LOG 这种日志表如果有很多二级索引/大批量 insert，回放会产生大量随机读写，I/O 就会像你看到的那样把盘打满。

如果这张表在读库不关键（只是审计/流水），有一个最快的提速方案：复制过滤掉它，让其它业务表先追平。

MySQL 8 支持在线改复制过滤（谨慎评估一致性需求）：

STOP REPLICA;
CHANGE REPLICATION FILTER REPLICATE_IGNORE_TABLE = (authx_log.TB_L_APPLY_CALL_LOG);
START REPLICA;


代价：读库这张表数据将不完整/不再更新。
如果业务可以接受，这是“立刻见效”的方案。

4）I/O 已经 99% util：再加 workers 未必更快（甚至更慢）

你现在瓶颈是盘，不是 CPU。replica_parallel_workers 继续加到 32/64 可能只会让随机 I/O 更碎、更抖。

更稳的做法是：

先做 第 1、2 步

然后观察 %util、r_await 是否下降、Executed_Gtid_Set 增长是否明显变快

如果盘仍然 95%+ util 且延迟不降，说明硬件/云盘 IOPS 就到顶了，想要数量级提升只有：

换更高 IOPS 的盘 / 把 datadir 放到更快存储

或直接 重建从库（Clone/物理备份）跳过两个月回放

5）关于你问的“从库改 2/0 会不会影响主库”

不会影响主库，只影响这台从库实例本地的持久性策略。你现在读库追赶阶段这么设是合理的；追平、准备随时切主时再改回 1/1 即可。

建议你现在立刻做的顺序

从库：SET GLOBAL replica_pending_jobs_size_max = 1G;

主库：改 binlog_transaction_dependency_tracking=WRITESET + FLUSH BINARY LOGS;

观察 10 分钟：SHOW PROCESSLIST 里是否出现多个 worker 同时在 Applying（不再只有一个忙）

如果还是被 TB_L_APPLY_CALL_LOG 拖死：评估是否可复制过滤，或者直接重建从库
```



#再次查看效果

```sql
root@localhost:mysql.sock [mysql]> SHOW VARIABLES LIKE 'replica_pending_jobs_size_max';
+-------------------------------+------------+
| Variable_name                 | Value      |
+-------------------------------+------------+
| replica_pending_jobs_size_max | 1073741824 |
+-------------------------------+------------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 131577555
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 215442886
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 215442694
              Relay_Log_Space: 183174202970
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731742
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406917071
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219776383,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 131958183
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 216464585
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 216464393
              Relay_Log_Space: 183174583598
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731745
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406917579
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219777348:219777350,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 132121604
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 216783842
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 216783650
              Relay_Log_Space: 183174747019
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731747
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406917786
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219777657,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 132268399
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 217099612
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 217099420
              Relay_Log_Space: 183174893814
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731747
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406917983
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219777972,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 132448679
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 217372867
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 217372675
              Relay_Log_Space: 183175074094
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5731748
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406918209
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-219778224,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]>

```



#分析

```
现在这个现象大概率不是“卡住不动”，而是：从库在回放非常旧的事务（你 replication_applier_status_by_worker 里看到的 ...ORIGINAL_COMMIT_TIMESTAMP 是 2025-10-19），所以 Seconds_Behind_Source ≈ 5,7xx,xxx（约 66 天）会长期维持在一个很大的数，甚至还会缓慢变化——直到回放追到接近当前时间它才会明显下降。判断是否在追赶，更可靠看这几个量是否持续增长：

Relay_Source_Log_File / Exec_Source_Log_Pos（你在从 mysql-bin.000455 往前推进）

Executed_Gtid_Set 的尾号是否持续变大（你从 219776xxx -> 219778xxx 在涨）
```

```sql


root@localhost:mysql.sock [mysql]>  show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 10.40.10.132
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000797
          Read_Source_Log_Pos: 199184438
               Relay_Log_File: relay-bin.003669
                Relay_Log_Pos: 527599258
        Relay_Source_Log_File: mysql-bin.000455
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
          Exec_Source_Log_Pos: 527599066
              Relay_Log_Space: 183241809853
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 5719406
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 132
                  Source_UUID: a36b6a91-5adc-11f0-864f-286ed48a126e
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
           Retrieved_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:52053:197337666-406992805
            Executed_Gtid_Set: a36b6a91-5adc-11f0-864f-286ed48a126e:1-52052:52054-220109391,
a52be673-5adc-11f0-85e5-286ed4894d31:1-3332
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

root@localhost:mysql.sock [mysql]> 
```



#继续分析

````bash
你这组最新数据里，其实已经能看到**追赶在变快、并且确实在追**了——只是 `Seconds_Behind_Source` 这种指标在“落后两个月”时看起来还是很吓人而已。

### 现在的追赶效果（用你贴的几次 `SHOW REPLICA STATUS` 直接算）

* `Executed_Gtid_Set` 从 **219,978,996** 增到 **220,109,391**，净增加 **130,395 个事务**（而 `Retrieved_Gtid_Set` 只增加了几千），说明 **SQL 回放速度 > 新增写入速度**，在“缩小欠账”。
* `Seconds_Behind_Source` 从 **5,725,400** 降到 **5,719,406**，下降 **5,994 秒 ≈ 1小时40分**。这说明你在“时间维度”也在往前推进（只是离当前还差 66 天左右）。

所以：你把 `replica_pending_jobs_size_max` 提到 1G + 从库 `flush=2/sync_binlog=0` 这些操作是有效的。

---

## 但为什么还是“一堆 worker 在等 Coordinator，只看到 1 个在 Applying”？

从你的 `processlist` 看，确实大部分时间只有一个 worker 在执行某张表的批量变更（TB_L_APPLY_CALL_LOG / TB_JOB_TASK_RECORD_DETAIL / TMP_* 等），其他都在等：

* 这通常意味着：**当前这段 binlog 的事务依赖很强（或单表热点/大事务），天然并行不起来**；
* 而你主库现在还是 `binlog_transaction_dependency_tracking=COMMIT_ORDER`，会让依赖判定更保守，更容易出现 `Waiting for dependent transaction to commit`。

---

## 接下来最推荐做的 3 件事（按收益排序）

### 1）主库改成 WRITESET（让“后续 binlog”更容易并行回放）

你主库已开启 `transaction_write_set_extraction=XXHASH64`，条件满足。建议在主库执行：

```sql
SET PERSIST binlog_transaction_dependency_tracking = 'WRITESET';
SET PERSIST binlog_transaction_dependency_history_size = 100000;  -- 可选，冲突多就加大
FLUSH BINARY LOGS;
```

> 说明：这主要提升“之后产生”的 binlog 的并行度；你现在积压的是很久以前的历史 binlog，它当时是 COMMIT_ORDER 生成的，所以并行提升不会立刻翻倍，但至少能避免“越追越被新增写入拉开”。

---

### 2）追赶期间继续保持“低刷盘”（你现在的值没问题）

你已经是：

* `innodb_flush_log_at_trx_commit=2`
* `sync_binlog=0`

追赶期间建议继续保持（追平、准备切主时再改回 1/1）。

如果你还没调过这 3 个，也可以追赶期间临时降一下（同样是“追赶专用”）：

```sql
SET GLOBAL sync_relay_log = 0;
SET GLOBAL sync_relay_log_info = 0;
SET GLOBAL sync_master_info = 0;
```

---

### 3）如果读库不需要某些“日志/流水表”，可以考虑复制过滤（立竿见影，但要评估业务）

你之前明显被 `TB_L_APPLY_CALL_LOG` 这类表拖慢过。若确认读业务不依赖这些表，过滤掉会让整体追赶快很多：

```sql
STOP REPLICA;
CHANGE REPLICATION FILTER REPLICATE_IGNORE_TABLE = (authx_log.TB_L_APPLY_CALL_LOG);
START REPLICA;
```

> 风险：该表在从库会不完整/不更新。适合“只为读库服务、日志表不看”的场景。

---

## 快速自检：你到底能并行到什么程度？

在从库跑这个，看看同时有多少个 worker 真正在 APPLY（非空）：

```sql
SELECT
  SUM(APPLYING_TRANSACTION <> '') AS applying_workers,
  COUNT(*) AS total_workers
FROM performance_schema.replication_applier_status_by_worker;
```

* 如果 `applying_workers` 长期接近 1：说明这段历史 binlog 依赖太强/大事务/单表热点，**硬并行也没用**；
* 如果能到 4/8/16：说明并行开始跑起来了，继续追就行。

---

## 最现实的提醒

你现在欠账（`Retrieved` 406,xxx,xxx vs `Executed` 220,xxx,xxx）还是**1.8 亿级事务**，靠回放能追，但时间可能仍然很长；如果业务要求“尽快恢复一个接近当前的读库”，通常更快的是**物理重建/Clone**，直接跳过两个月 binlog 回放。

---

如果你把下面两项从库参数贴一下（各 1 行即可），我就能判断“你现在是否还在承受写 binlog 的额外 IO（双主反向通道）”，从而决定是否建议你临时关掉某条通道/调整架构来加速：

```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'log_replica_updates';
```

````

#可以跳过部分表

```sql
STOP REPLICA;
-- 忽略掉这些只写不读、或者不影响核心业务的大表
CHANGE REPLICATION FILTER REPLICATE_IGNORE_TABLE = ('jobs_server.TB_JOB_TASK_RECORD_DETAIL', 'authx_log.TB_L_APPLY_CALL_LOG');
START REPLICA;
```



#提高mysql的innodb_buffer_pool_size

```sql
 [root@MHsql-db01B mysql]# free -m

total used free shared buff/cache available

Mem: 63082 38479 11337 60 13265 23762

Swap: 16383 528 15855

[root@MHsql-db01B mysql]#

root@localhost:mysql.sock [mysql]> SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

+-------------------------+-------------+

| Variable_name | Value |

+-------------------------+-------------+

| innodb_buffer_pool_size | 34359738368 |

+-------------------------+-------------+

1 row in set (0.00 sec) 

root@localhost:mysql.sock [mysql]>  SELECT  WORKER_ID,  LAST_APPLIED_TRANSACTION,  LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP  FROM performance_schema.replication_applier_status_by_worker  WHERE SERVICE_STATE = 'ON';
+-----------+------------------------------------------------+----------------------------------------------+
| WORKER_ID | LAST_APPLIED_TRANSACTION                       | LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP |
+-----------+------------------------------------------------+----------------------------------------------+
|         1 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980366 | 2025-12-24 14:05:13.462772                   |
|         2 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980365 | 2025-12-24 14:05:13.453092                   |
|         3 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980353 | 2025-12-24 14:05:13.347996                   |
|         4 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980323 | 2025-12-24 14:05:13.177100                   |
|         5 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980324 | 2025-12-24 14:05:13.225087                   |
|         6 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980325 | 2025-12-24 14:05:13.174103                   |
|         7 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980283 | 2025-12-24 14:05:13.041427                   |
|         8 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980284 | 2025-12-24 14:05:13.027725                   |
|         9 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980285 | 2025-12-24 14:05:13.027258                   |
|        10 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980286 | 2025-12-24 14:05:13.055100                   |
|        11 | a36b6a91-5adc-11f0-864f-286ed48a126e:221979628 | 2025-12-24 14:05:09.082295                   |
|        12 | a36b6a91-5adc-11f0-864f-286ed48a126e:221979629 | 2025-12-24 14:05:09.089515                   |
|        13 | a36b6a91-5adc-11f0-864f-286ed48a126e:221979630 | 2025-12-24 14:05:09.082300                   |
|        14 | a36b6a91-5adc-11f0-864f-286ed48a126e:221979631 | 2025-12-24 14:05:09.082298                   |
|        15 | a36b6a91-5adc-11f0-864f-286ed48a126e:221975949 | 2025-12-24 14:04:46.138647                   |
|        16 | a36b6a91-5adc-11f0-864f-286ed48a126e:221975950 | 2025-12-24 14:04:46.136394                   |
+-----------+------------------------------------------------+----------------------------------------------+
16 rows in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SELECT      WORKER_ID,      LAST_APPLIED_TRANSACTION,      LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP  FROM performance_schema.replication_applier_status_by_worker  WHERE SERVICE_STATE = 'ON';
+-----------+------------------------------------------------+----------------------------------------------+
| WORKER_ID | LAST_APPLIED_TRANSACTION                       | LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP |
+-----------+------------------------------------------------+----------------------------------------------+
|         1 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982199 | 2025-12-24 14:05:24.635907                   |
|         2 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982197 | 2025-12-24 14:05:24.612519                   |
|         3 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982190 | 2025-12-24 14:05:24.562252                   |
|         4 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982176 | 2025-12-24 14:05:24.446097                   |
|         5 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982177 | 2025-12-24 14:05:24.437175                   |
|         6 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982102 | 2025-12-24 14:05:23.924501                   |
|         7 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982035 | 2025-12-24 14:05:23.498023                   |
|         8 | a36b6a91-5adc-11f0-864f-286ed48a126e:221982009 | 2025-12-24 14:05:23.365666                   |
|         9 | a36b6a91-5adc-11f0-864f-286ed48a126e:221981833 | 2025-12-24 14:05:22.220518                   |
|        10 | a36b6a91-5adc-11f0-864f-286ed48a126e:221981766 | 2025-12-24 14:05:21.698550                   |
|        11 | a36b6a91-5adc-11f0-864f-286ed48a126e:221981767 | 2025-12-24 14:05:21.698593                   |
|        12 | a36b6a91-5adc-11f0-864f-286ed48a126e:221981768 | 2025-12-24 14:05:21.720239                   |
|        13 | a36b6a91-5adc-11f0-864f-286ed48a126e:221981769 | 2025-12-24 14:05:21.701362                   |
|        14 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980804 | 2025-12-24 14:05:15.888659                   |
|        15 | a36b6a91-5adc-11f0-864f-286ed48a126e:221975949 | 2025-12-24 14:04:46.138647                   |
|        16 | a36b6a91-5adc-11f0-864f-286ed48a126e:221975950 | 2025-12-24 14:04:46.136394                   |
+-----------+------------------------------------------------+----------------------------------------------+
16 rows in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SELECT      WORKER_ID,      LAST_APPLIED_TRANSACTION,      LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP  FROM performance_schema.replication_applier_status_by_worker  WHERE SERVICE_STATE = 'ON';
+-----------+------------------------------------------------+----------------------------------------------+
| WORKER_ID | LAST_APPLIED_TRANSACTION                       | LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP |
+-----------+------------------------------------------------+----------------------------------------------+
|         1 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983838 | 2025-12-24 14:05:34.684745                   |
|         2 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983837 | 2025-12-24 14:05:34.682963                   |
|         3 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983835 | 2025-12-24 14:05:34.646444                   |
|         4 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983829 | 2025-12-24 14:05:34.492438                   |
|         5 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983798 | 2025-12-24 14:05:34.222884                   |
|         6 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983787 | 2025-12-24 14:05:34.153855                   |
|         7 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983759 | 2025-12-24 14:05:34.028270                   |
|         8 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983760 | 2025-12-24 14:05:34.015510                   |
|         9 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983761 | 2025-12-24 14:05:34.009188                   |
|        10 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983762 | 2025-12-24 14:05:34.003001                   |
|        11 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983764 | 2025-12-24 14:05:34.014489                   |
|        12 | a36b6a91-5adc-11f0-864f-286ed48a126e:221983765 | 2025-12-24 14:05:34.004499                   |
|        13 | a36b6a91-5adc-11f0-864f-286ed48a126e:221981769 | 2025-12-24 14:05:21.701362                   |
|        14 | a36b6a91-5adc-11f0-864f-286ed48a126e:221980804 | 2025-12-24 14:05:15.888659                   |
|        15 | a36b6a91-5adc-11f0-864f-286ed48a126e:221975949 | 2025-12-24 14:04:46.138647                   |
|        16 | a36b6a91-5adc-11f0-864f-286ed48a126e:221975950 | 2025-12-24 14:04:46.136394                   |
+-----------+------------------------------------------------+----------------------------------------------+
16 rows in set (0.00 sec)

root@localhost:mysql.sock [mysql]>
```



```logs
用 buffer pool 余量换 I/O（你机器还有内存空间）

你机器 63G 内存、buffer pool 32G，free -m 里 available 还有 23G 左右。追数据这种大量索引页读写场景，适当加大 buffer pool 往往能减少随机读，缓解 /data 的读压力。

可以先加到 48G 试试（别一步拉太满，避免 OS 缓存/其它进程不够）：

SET GLOBAL innodb_buffer_pool_size = 51539607552;  -- 48G


加完盯一下：

swap 是否继续增长（你现在 swap 已经在用 528M 了）

iostat 的 r/s、r_await 是否下降

B. 别用 “Seconds_Behind_Source” 当唯一指标

你现在 Seconds_Behind_Source 大约 5,6xx,xxx 秒（≈65 天），这个值在大事务/提交依赖场景下会很“钝”。更建议你用下面这种方式看“真实推进速度”：

每隔 10 秒看一次 SHOW REPLICA STATUS\G：

Executed_Gtid_Set 尾号是否持续增长

Exec_Source_Log_Pos 是否持续增长

Relay_Log_Space 是否在下降
```



```sql
root@localhost:mysql.sock [mysql]>  SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
+-------------------------+-------------+
| Variable_name           | Value       |
+-------------------------+-------------+
| innodb_buffer_pool_size | 51539607552 |
+-------------------------+-------------+
1 row in set (0.01 sec)

root@localhost:mysql.sock [mysql]> SELECT
    ->     WORKER_ID,
    ->     LAST_APPLIED_TRANSACTION,
    ->     LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP
    -> FROM performance_schema.replication_applier_status_by_worker
    -> WHERE SERVICE_STATE = 'ON';
+-----------+------------------------------------------------+----------------------------------------------+
| WORKER_ID | LAST_APPLIED_TRANSACTION                       | LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP |
+-----------+------------------------------------------------+----------------------------------------------+
|         1 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131750 | 2025-12-24 14:20:40.281114                   |
|         2 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131751 | 2025-12-24 14:20:40.300595                   |
|         3 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131753 | 2025-12-24 14:20:40.307726                   |
|         4 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131733 | 2025-12-24 14:20:40.172425                   |
|         5 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131706 | 2025-12-24 14:20:39.931858                   |
|         6 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131629 | 2025-12-24 14:20:39.157816                   |
|         7 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131544 | 2025-12-24 14:20:38.600492                   |
|         8 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131347 | 2025-12-24 14:20:37.161863                   |
|         9 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131348 | 2025-12-24 14:20:37.161476                   |
|        10 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131349 | 2025-12-24 14:20:37.157331                   |
|        11 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131350 | 2025-12-24 14:20:37.173273                   |
|        12 | a36b6a91-5adc-11f0-864f-286ed48a126e:222131351 | 2025-12-24 14:20:37.173333                   |
|        13 | a36b6a91-5adc-11f0-864f-286ed48a126e:222130291 | 2025-12-24 14:20:30.160315                   |
|        14 | a36b6a91-5adc-11f0-864f-286ed48a126e:222130297 | 2025-12-24 14:20:30.169004                   |
|        15 | a36b6a91-5adc-11f0-864f-286ed48a126e:222130293 | 2025-12-24 14:20:30.160640                   |
|        16 | a36b6a91-5adc-11f0-864f-286ed48a126e:222130114 | 2025-12-24 14:20:29.322598                   |
+-----------+------------------------------------------------+----------------------------------------------+
16 rows in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SELECT      WORKER_ID,      LAST_APPLIED_TRANSACTION,      LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP  FROM performance_schema.replication_applier_status_by_worker  WHERE SERVICE_STATE = 'ON';
+-----------+------------------------------------------------+----------------------------------------------+
| WORKER_ID | LAST_APPLIED_TRANSACTION                       | LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP |
+-----------+------------------------------------------------+----------------------------------------------+
|         1 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133451 | 2025-12-24 14:20:49.945897                   |
|         2 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133452 | 2025-12-24 14:20:49.951879                   |
|         3 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133453 | 2025-12-24 14:20:49.960011                   |
|         4 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133426 | 2025-12-24 14:20:49.829213                   |
|         5 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133427 | 2025-12-24 14:20:49.829772                   |
|         6 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133225 | 2025-12-24 14:20:48.540283                   |
|         7 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133209 | 2025-12-24 14:20:48.507921                   |
|         8 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133210 | 2025-12-24 14:20:48.507934                   |
|         9 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133211 | 2025-12-24 14:20:48.501597                   |
|        10 | a36b6a91-5adc-11f0-864f-286ed48a126e:222132380 | 2025-12-24 14:20:43.183043                   |
|        11 | a36b6a91-5adc-11f0-864f-286ed48a126e:222132372 | 2025-12-24 14:20:43.187443                   |
|        12 | a36b6a91-5adc-11f0-864f-286ed48a126e:222132373 | 2025-12-24 14:20:43.183353                   |
|        13 | a36b6a91-5adc-11f0-864f-286ed48a126e:222132374 | 2025-12-24 14:20:43.175915                   |
|        14 | a36b6a91-5adc-11f0-864f-286ed48a126e:222132375 | 2025-12-24 14:20:43.175817                   |
|        15 | a36b6a91-5adc-11f0-864f-286ed48a126e:222132376 | 2025-12-24 14:20:43.184955                   |
|        16 | a36b6a91-5adc-11f0-864f-286ed48a126e:222132377 | 2025-12-24 14:20:43.180540                   |
+-----------+------------------------------------------------+----------------------------------------------+
16 rows in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SELECT      WORKER_ID,      LAST_APPLIED_TRANSACTION,      LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP  FROM performance_schema.replication_applier_status_by_worker  WHERE SERVICE_STATE = 'ON';
+-----------+------------------------------------------------+----------------------------------------------+
| WORKER_ID | LAST_APPLIED_TRANSACTION                       | LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP |
+-----------+------------------------------------------------+----------------------------------------------+
|         1 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135315 | 2025-12-24 14:21:00.237409                   |
|         2 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135318 | 2025-12-24 14:21:00.238452                   |
|         3 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135319 | 2025-12-24 14:21:00.238362                   |
|         4 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135320 | 2025-12-24 14:21:00.238439                   |
|         5 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135302 | 2025-12-24 14:21:00.175021                   |
|         6 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135246 | 2025-12-24 14:20:59.854063                   |
|         7 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135247 | 2025-12-24 14:20:59.837903                   |
|         8 | a36b6a91-5adc-11f0-864f-286ed48a126e:222135204 | 2025-12-24 14:20:59.648933                   |
|         9 | a36b6a91-5adc-11f0-864f-286ed48a126e:222134858 | 2025-12-24 14:20:57.822037                   |
|        10 | a36b6a91-5adc-11f0-864f-286ed48a126e:222134859 | 2025-12-24 14:20:57.824399                   |
|        11 | a36b6a91-5adc-11f0-864f-286ed48a126e:222134860 | 2025-12-24 14:20:57.820954                   |
|        12 | a36b6a91-5adc-11f0-864f-286ed48a126e:222134861 | 2025-12-24 14:20:57.817649                   |
|        13 | a36b6a91-5adc-11f0-864f-286ed48a126e:222134862 | 2025-12-24 14:20:57.841690                   |
|        14 | a36b6a91-5adc-11f0-864f-286ed48a126e:222134865 | 2025-12-24 14:20:57.817655                   |
|        15 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133528 | 2025-12-24 14:20:50.166323                   |
|        16 | a36b6a91-5adc-11f0-864f-286ed48a126e:222133529 | 2025-12-24 14:20:50.164050                   |
+-----------+------------------------------------------------+----------------------------------------------+
16 rows in set (0.00 sec)

root@localhost:mysql.sock [mysql]>

```



```sql
给你一套更好用的“测速 SQL”（建议直接用这个）
3.1 看 10 秒内推进了多少 GTID（推荐）
SELECT
  NOW(6) AS ts,
  MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid
FROM performance_schema.replication_applier_status_by_worker
WHERE SERVICE_STATE='ON';
-- 等 10 秒再执行一次，max_gtid 的差值 / 10 就是 tps


如果你想“一条 SQL 自动算 10 秒速率”，用这个：

SELECT
  a.max_gtid AS gtid_0,
  SLEEP(10) AS t,
  (SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))
   FROM performance_schema.replication_applier_status_by_worker
   WHERE SERVICE_STATE='ON') AS gtid_10,
  ((SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))
    FROM performance_schema.replication_applier_status_by_worker
    WHERE SERVICE_STATE='ON') - a.max_gtid) / 10 AS tps
FROM (
  SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid
  FROM performance_schema.replication_applier_status_by_worker
  WHERE SERVICE_STATE='ON'
) a;

3.2 同时看 “relay 是否在变少”（能否追平的关键）

每隔一段时间看一次：

SHOW REPLICA STATUS\G


重点盯：

Relay_Log_Space：持续下降 = 在消化积压（非常关键）

Executed_Gtid_Set 尾号：持续上升

Seconds_Behind_Source：只当参考（大延迟时很钝）
```

```logs

root@localhost:mysql.sock [mysql]> SELECT
    ->   NOW(6) AS ts,
    ->   MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid
    -> FROM performance_schema.replication_applier_status_by_worker
    -> WHERE SERVICE_STATE='ON';
+----------------------------+-----------+
| ts                         | max_gtid  |
+----------------------------+-----------+
| 2025-12-24 14:22:40.812751 | 222152636 |
+----------------------------+-----------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SELECT   NOW(6) AS ts,   MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid FROM performance_schema.replication_applier_status_by_worker WHERE SERVICE_STATE='ON';
+----------------------------+-----------+
| ts                         | max_gtid  |
+----------------------------+-----------+
| 2025-12-24 14:22:52.136475 | 222154369 |
+----------------------------+-----------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SELECT   NOW(6) AS ts,   MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid FROM performance_schema.replication_applier_status_by_worker WHERE SERVICE_STATE='ON';
+----------------------------+-----------+
| ts                         | max_gtid  |
+----------------------------+-----------+
| 2025-12-24 14:23:01.041782 | 222155889 |
+----------------------------+-----------+
1 row in set (0.00 sec)

root@localhost:mysql.sock [mysql]> SELECT
   WHERE SERVICE_STATE='ON') AS gtid_10,
    ->   a.max_gtid AS gtid_0,
    ->   SLEEP(10) AS t,
    ->   (SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))
    ->    FROM performance_schema.replication_applier_status_by_worker
    ->    WHERE SERVICE_STATE='ON') AS gtid_10,
    ->   ((SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))
    ->     FROM performance_schema.replication_applier_status_by_worker
    WHERE SERVICE_STATE='O    -> N') - a.max_gtid) / 10 AS tps
FROM (
  SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid
    WHERE SERVICE_STATE='ON') - a.max_gtid) / 10 AS tps
    -> FROM (
    ->   SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid
    ->   FROM performance_schema.replication_applier_status_by_worker
    ->   WHERE SERVICE_STATE='ON'
    -> ) a;
+-----------+---+-----------+----------+
| gtid_0    | t | gtid_10   | tps      |
+-----------+---+-----------+----------+
| 222158872 | 0 | 222160605 | 173.5000 |
+-----------+---+-----------+----------+
1 row in set (10.00 sec)

root@localhost:mysql.sock [mysql]> SELECT   a.max_gtid AS gtid_0,   SLEEP(10) AS t,   (SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))    FROM performance_schema.replication_applier_status_by_worker    WHERE SERVICE_STATE='ON') AS gtid_10,   ((SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))     FROM performance_schema.replication_applier_status_by_worker     WHERE SERVICE_STATE='ON') - a.max_gtid) / 10 AS tps FROM (   SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid   FROM performance_schema.replication_applier_status_by_worker   WHERE SERVICE_STATE='ON' ) a;
+-----------+---+-----------+----------+
| gtid_0    | t | gtid_10   | tps      |
+-----------+---+-----------+----------+
| 222169582 | 0 | 222171218 | 163.6000 |
+-----------+---+-----------+----------+
1 row in set (10.00 sec)

root@localhost:mysql.sock [mysql]> SELECT   a.max_gtid AS gtid_0,   SLEEP(10) AS t,   (SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))    FROM performance_schema.replication_applier_status_by_worker    WHERE SERVICE_STATE='ON') AS gtid_10,   ((SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED))     FROM performance_schema.replication_applier_status_by_worker     WHERE SERVICE_STATE='ON') - a.max_gtid) / 10 AS tps FROM (   SELECT MAX(CAST(SUBSTRING_INDEX(LAST_APPLIED_TRANSACTION, ':', -1) AS UNSIGNED)) AS max_gtid   FROM performance_schema.replication_applier_status_by_worker   WHERE SERVICE_STATE='ON' ) a;
+-----------+---+-----------+----------+
| gtid_0    | t | gtid_10   | tps      |
+-----------+---+-----------+----------+
| 222172731 | 0 | 222174498 | 176.7000 |
+-----------+---+-----------+----------+
1 row in set (10.00 sec)

root@localhost:mysql.sock [mysql]>

```



```bash

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.16    0.00    0.09    3.95    0.00   95.80

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-1             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-2           102.00   1632.00     0.00   0.00   13.06    16.00  147.00   6352.00     0.00   0.00    0.79    43.21    0.00      0.00     0.00   0.00    0.00     0.00    1.45  95.60
dm-3             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vda              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdb              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdc            104.00   1664.00     0.00   0.00   12.66    16.00  147.00   6340.00     0.00   0.00    0.75    43.13    0.00      0.00     0.00   0.00    0.00     0.00    1.15  95.60


avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.47    0.00    0.22    4.25    0.00   95.07

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-1             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
dm-2           131.00   2096.00     0.00   0.00   11.08    16.00  636.00  13232.00     0.00   0.00    0.39    20.81    0.00      0.00     0.00   0.00    0.00     0.00    1.70  95.60
dm-3             0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vda              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdb              0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
vdc            131.00   2096.00     0.00   0.00   10.94    16.00  636.00  13204.00     0.00   0.00    0.36    20.76    0.00      0.00     0.00   0.00    0.00     0.00    1.21  95.60

^C
[root@MHsql-db01B mysql]# free -m
              total        used        free      shared  buff/cache   available
Mem:          63082       40637        8596          60       13848       21604
Swap:         16383         528       15855
[root@MHsql-db01B mysql]#

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
CHANGE REPLICATION SOURCE TO SOURCE_HOST='222.24.203.35',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='Repl123!@#2024',SOURCE_AUTO_POSITION = 1;

start replica;
show replica status\G;

mysql> select * from performance_schema.replication_applier_status_by_worker where LAST_ERROR_NUMBER=1396;

 stop replica;
 set @@session.gtid_next='69fc8d5a-1c39-11f0-88c3-286ed489b835:1'; 
 begin; 
 commit; 
 
 set @@session.gtid_next=automatic;  
 
 start replica; 
 
 SHOW REPLICA STATUS \G;
 
 stop replica;
 set @@session.gtid_next='69fc8d5a-1c39-11f0-88c3-286ed489b835:4'; 
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
#yum install -y pcre-devel openssl-devel popt-devel libnl libnl-devel psmisc gcc

yum install -y pcre-devel openssl-devel popt-devel psmisc gcc
```



#### 2、安装keepalived

#推荐离线安装

##### 2.1、在线安装
#在线安装---版本较低

```bash
yum install -y keepalived

keepalived -v
```



#logs

```bash
#centos 7.9
[root@MHsql-db01 network-scripts]# keepalived -v
Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2

#如果版本过低，低于2.2.8，那么可以离线部署

#kylin
[root@MHsql-db01 ~]# yum install -y pcre-devel openssl-devel popt-devel libnl libnl-devel psmisc gcc
Last metadata expiration check: 2:09:42 ago on Mon 21 Apr 2025 07:28:07 AM CST.
Package pcre-devel-8.44-2.ky10.x86_64 is already installed.
Package openssl-devel-1:1.1.1f-4.p22.ky10.x86_64 is already installed.
No match for argument: libnl
No match for argument: libnl-devel
Package psmisc-23.3-2.ky10.x86_64 is already installed.
Package gcc-7.3.0-20190804.35.p07.ky10.x86_64 is already installed.
Error: Unable to find a match: libnl libnl-devel
[root@MHsql-db01 ~]# yum install -y keepalived
Last metadata expiration check: 2:10:16 ago on Mon 21 Apr 2025 07:28:07 AM CST.
Dependencies resolved.
=========================================================================================================================================================
 Package                                 Architecture               Version                                   Repository                            Size
=========================================================================================================================================================
Installing:
 keepalived                              x86_64                     2.0.20-19.p01.ky10                        ks10-adv-updates                     294 k
Installing dependencies:
 mariadb-connector-c                     x86_64                     3.0.6-8.p01.ky10                          ks10-adv-updates                     127 k
 net-snmp                                x86_64                     1:5.9-3.p05.ky10                          ks10-adv-updates                     1.1 M

Transaction Summary
=========================================================================================================================================================
Install  3 Packages

Total download size: 1.5 M
Installed size: 6.2 M
Downloading Packages:
(1/3): mariadb-connector-c-3.0.6-8.p01.ky10.x86_64.rpm                                                                   402 kB/s | 127 kB     00:00
(2/3): net-snmp-5.9-3.p05.ky10.x86_64.rpm                                                                                2.7 MB/s | 1.1 MB     00:00
(3/3): keepalived-2.0.20-19.p01.ky10.x86_64.rpm                                                                          443 kB/s | 294 kB     00:00
---------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                    2.2 MB/s | 1.5 MB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Running scriptlet: mariadb-connector-c-3.0.6-8.p01.ky10.x86_64                                                                                     1/1
  Preparing        :                                                                                                                                 1/1
  Installing       : mariadb-connector-c-3.0.6-8.p01.ky10.x86_64                                                                                     1/3
  Installing       : net-snmp-1:5.9-3.p05.ky10.x86_64                                                                                                2/3
  Running scriptlet: net-snmp-1:5.9-3.p05.ky10.x86_64                                                                                                2/3
  Installing       : keepalived-2.0.20-19.p01.ky10.x86_64                                                                                            3/3
  Running scriptlet: keepalived-2.0.20-19.p01.ky10.x86_64                                                                                            3/3
/sbin/ldconfig: /usr/lib64/libLLVM-7.so is not a symbolic link


  Verifying        : keepalived-2.0.20-19.p01.ky10.x86_64                                                                                            1/3
  Verifying        : mariadb-connector-c-3.0.6-8.p01.ky10.x86_64                                                                                     2/3
  Verifying        : net-snmp-1:5.9-3.p05.ky10.x86_64                                                                                                3/3

Installed:
  keepalived-2.0.20-19.p01.ky10.x86_64             mariadb-connector-c-3.0.6-8.p01.ky10.x86_64             net-snmp-1:5.9-3.p05.ky10.x86_64

Complete!
[root@MHsql-db01 ~]# keepalived -v
Keepalived v2.0.20 (01/22,2020)

Copyright(C) 2001-2020 Alexandre Cassen, <acassen@gmail.com>

Built with kernel headers for Linux 4.19.90
Running on Linux 4.19.90-25.44.v2101.ky10.x86_64 #1 SMP Thu Nov 7 17:33:30 CST 2024

configure options: --build=x86_64-koji-linux-gnu --host=x86_64-koji-linux-gnu --program-prefix= --disable-dependency-tracking --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include --libdir=/usr/lib64 --libexecdir=/usr/libexec --localstatedir=/var --sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info --enable-sha1 --with-init=systemd --enable-nftables --disable-iptables --disable-ipset --enable-snmp --enable-snmp-rfc build_alias=x86_64-koji-linux-gnu host_alias=x86_64-koji-linux-gnu PKG_CONFIG_PATH=:/usr/lib64/pkgconfig:/usr/share/pkgconfig CFLAGS=-O2 -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fexceptions -fstack-protector-strong -grecord-gcc-switches -specs=/usr/lib/rpm/kylin/kylin-hardened-cc1 -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection  LDFLAGS=-Wl,-z,relro -Wl,-z,now -specs=/usr/lib/rpm/kylin/kylin-hardened-ld

Config options:  NFTABLES LVS VRRP VRRP_AUTH OLD_CHKSUM_COMPAT FIB_ROUTING SNMP_V3_FOR_V2 SNMP_VRRP SNMP_CHECKER SNMP_RFCV2 SNMP_RFCV3

System options:  PIPE2 SIGNALFD INOTIFY_INIT1 VSYSLOG EPOLL_CREATE1 IPV4_DEVCONF IPV6_ADVANCED_API LIBNL3 RTA_ENCAP RTA_EXPIRES RTA_NEWDST RTA_PREF FRA_SUPPRESS_PREFIXLEN FRA_SUPPRESS_IFGROUP FRA_TUN_ID RTAX_CC_ALGO RTAX_QUICKACK RTEXT_FILTER_SKIP_STATS FRA_L3MDEV FRA_UID_RANGE RTAX_FASTOPEN_NO_COOKIE RTA_VIA FRA_OIFNAME FRA_PROTOCOL FRA_IP_PROTO FRA_SPORT_RANGE FRA_DPORT_RANGE RTA_TTL_PROPAGATE IFA_FLAGS IP_MULTICAST_ALL LWTUNNEL_ENCAP_MPLS LWTUNNEL_ENCAP_ILA NET_LINUX_IF_H_COLLISION LIBIPVS_NETLINK IPVS_DEST_ATTR_ADDR_FAMILY IPVS_SYNCD_ATTRIBUTES IPVS_64BIT_STATS VRRP_VMAC VRRP_IPVLAN IFLA_LINK_NETNSID CN_PROC SOCK_NONBLOCK SOCK_CLOEXEC O_PATH GLOB_BRACE INET6_ADDR_GEN_MODE VRF SO_MARK SCHED_RESET_ON_FORK
[root@MHsql-db01 ~]#


```



##### 2.2、离线安装

#离线部署

#官网https://www.keepalived.org/download.html

```bash
#2024
wget --no-check-certificate https://www.keepalived.org/software/keepalived-2.2.8.tar.gz
tar -zxvf keepalived-2.2.8.tar.gz
cd keepalived-2.2.8
#yum install -y gcc
./configure --prefix=/usr/local/keepalived-2.2.8
make && make install

#20250422
yum remove keepalived -y
wget --no-check-certificate https://www.keepalived.org/software/keepalived-2.3.3.tar.gz
tar -zxvf keepalived-2.3.3.tar.gz
cd keepalived-2.3.3
#yum install -y gcc
./configure --prefix=/usr/local/keepalived-2.3.3
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

mv /etc/keepalived/keepalived.conf  /etc/keepalived/keepalived.conf.bak
```



#logs

```bash
./configure --prefix=/usr/local/keepalived-2.3.3

.............
Keepalived configuration
------------------------
Keepalived version       : 2.3.3
Compiler                 : gcc gcc (GCC) 7.3.0
Preprocessor flags       : -D_GNU_SOURCE
Compiler flags           : -g -g -O2 -Wall -Wextra -Wunused -Wstrict-prototypes -Wabi -Walloca -Walloc-zero -Warray-bounds=2 -Wbad-function-cast -Wcast-align -Wcast-qual -Wchkp -Wdate-time -Wdisabled-optimization -Wdouble-promotion -Wduplicated-branches -Wduplicated-cond -Wfloat-conversion -Wfloat-equal -Wformat-overflow -Wformat-signedness -Wformat-truncation -Wframe-larger-than=5120 -Wimplicit-fallthrough=3 -Winit-self -Winline -Winvalid-pch -Wjump-misses-init -Wlogical-op -Wmissing-declarations -Wmissing-field-initializers -Wmissing-include-dirs -Wmissing-prototypes -Wnested-externs -Wnormalized -Wnull-dereference -Wold-style-definition -Woverlength-strings -Wpointer-arith -Wredundant-decls -Wshadow -Wshift-overflow=2 -Wstack-protector -Wstrict-overflow=4 -Wstringop-overflow=2 -Wsuggest-attribute=format -Wsuggest-attribute=noreturn -Wsuggest-attribute=pure -Wsync-nand -Wtrampolines -Wundef -Wuninitialized -Wunknown-pragmas -Wunsafe-loop-optimizations -Wunsuffixed-float-constants -Wunused-const-variable=2 -Wvariadic-macros -Wwrite-strings -fno-strict-aliasing -fPIE -Wformat -Werror=format-security -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -D_FORTIFY_SOURCE=3 -O2
Linker flags             : -pie -Wl,-z,relro -Wl,-z,now
Extra Lib                : -lm -lssl -lcrypto -lsystemd
Use IPVS Framework       : Yes
IPVS use libnl           : No
IPVS syncd attributes    : Yes
IPVS 64 bit stats        : Yes
HTTP_GET regex support   : No
fwmark socket support    : Yes
Use VRRP Framework       : Yes
Use VRRP VMAC            : Yes
Use VRRP authentication  : Yes
With track_process       : Yes
With linkbeat            : Yes
Use NetworkManager       : No
Use BFD Framework        : No
SNMP vrrp support        : No
SNMP checker support     : No
SNMP RFCv2 support       : No
SNMP RFCv3 support       : No
DBUS support             : No
Use JSON output          : No
libnl version            : None
Use IPv4 devconf         : Yes
Use iptables             : No
Use nftables             : No
init type                : systemd
systemd notify           : Yes
Strict config checks     : No
Build documentation      : No
iproute usr directory    : /etc/iproute2
iproute etc directory    : /etc/iproute2
Default runtime options  : -D

*** WARNING - this build will not support IPVS with IPv6. Please install libnl/libnl-3 dev libraries to support IPv6 with IPVS.

```





#### 3、修改/etc/keepalived/keepalived.conf

###主库

```bash
#mv /etc/keepalived/keepalived.conf  /etc/keepalived/keepalived.conf.bak

cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

#主要配置故障发生时的通知对象及机器标识
global_defs {
   router_id MYSQL-80                   #主机标识符，唯一即可
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
    interface enp4s1                 #指定HA监听的网络接口，刚才ifconfig查看的接口名称
    virtual_router_id 83            #虚拟路由标识，取值0-255，master-1和master-2保持一致
    priority 100                     #优先级，用来选举master，取值范围1-255
    advert_int 1                     #发VRRP包时间间隔，即多久进行一次master选举
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              #虚拟出来的地址
        222.24.203.83
    }
}

#虚拟服务器定义
virtual_server 222.24.203.83 3306 { #虚拟出来的地址加端口
    delay_loop 2                     #设置运行情况检查时间，单位为秒
    lb_algo rr                       #设置后端调度器算法，rr为轮询算法
    lb_kind DR                       #设置LVS实现负载均衡的机制，有DR、NAT、TUN三种模式可选
    persistence_timeout 50           #会话保持时间，单位为秒
    protocol TCP                     #指定转发协议，有 TCP和UDP可选

        real_server  222.24.203.31 3306 {          #实际本地ip+3306端口
       weight=5                      #表示服务器的权重值。权重值越高，服务器在负载均衡中被选中的概率就越大
        #当该ip 端口连接异常时，执行该脚本
        notify_down /etc/keepalived/shutdown.sh   #检查mysql服务down掉后执行的脚本
        TCP_CHECK {
            #实际物理机ip地址
            connect_ip  222.24.203.31
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
#52
```config
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   router_id MYSQL-132
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security
}


vrrp_instance VI_1 {
    state BACKUP
    interface  enp4s2
    virtual_router_id 52
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.40.10.141
    }
}


virtual_server 10.40.10.141 3306 {
    delay_loop 2
    lb_algo rr
    lb_kind DR
    persistence_timeout 50
    protocol TCP

        real_server  10.40.10.132 3306 {
       weight=5
        notify_down /etc/keepalived/shutdown.sh
        TCP_CHECK {
            connect_ip  10.40.10.132
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```
#123
```bash
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   router_id MYSQL-135
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security
}


vrrp_instance VI_1 {
    state BACKUP
    interface  enp4s2
    virtual_router_id 123
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.40.10.142
    }
}


virtual_server 10.40.10.142 3306 {
    delay_loop 2
    lb_algo rr
    lb_kind DR
    persistence_timeout 50
    protocol TCP

        real_server  10.40.10.135 3306 {
       weight=5
        notify_down /etc/keepalived/shutdown.sh
        TCP_CHECK {
            connect_ip  10.40.10.135
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```
#121
```bash
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   router_id MYSQL-133
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security
}


vrrp_instance VI_1 {
    state BACKUP
    interface  enp4s2
    virtual_router_id 121
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.40.10.143
    }
}


virtual_server 10.40.10.143 3306 {
    delay_loop 2
    lb_algo rr
    lb_kind DR
    persistence_timeout 50
    protocol TCP

        real_server  10.40.10.133 3306 {
       weight=5
        notify_down /etc/keepalived/shutdown.sh
        TCP_CHECK {
            connect_ip  10.40.10.133
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```

#122
```bash
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   router_id MYSQL-134
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security
}


vrrp_instance VI_1 {
    state BACKUP
    interface  enp4s2
    virtual_router_id 122
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.40.10.144
    }
}


virtual_server 10.40.10.144 3306 {
    delay_loop 2
    lb_algo rr
    lb_kind DR
    persistence_timeout 50
    protocol TCP

        real_server  10.40.10.134 3306 {
       weight=5
        notify_down /etc/keepalived/shutdown.sh
        TCP_CHECK {
            connect_ip  10.40.10.134
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
   router_id MYSQL-81                   #主机标识符，唯一即可
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
    interface enp4s1                 #指定HA监听的网络接口，刚才ifconfig查看的接口名称
    virtual_router_id 83            #虚拟路由标识，取值0-255，master-1和master-2保持一致
    priority 40                      #优先级，用来选举master，取值范围1-255
    advert_int 1                     #发VRRP包时间间隔，即多久进行一次master选举
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              #虚拟出来的地址
        222.24.203.83
    }
}

#虚拟服务器定义
virtual_server 222.24.203.83 3306 { #虚拟出来的地址加端口
    delay_loop 2                     #设置运行情况检查时间，单位为秒
    lb_algo rr                       #设置后端调度器算法，rr为轮询算法
    lb_kind DR                       #设置LVS实现负载均衡的机制，有DR、NAT、TUN三种模式可选
    persistence_timeout 50           #会话保持时间，单位为秒
    protocol TCP                     #指定转发协议，有 TCP和UDP可选

        real_server  222.24.203.35 3306 {          #实际本地ip+3306端口
       weight=5                      #表示服务器的权重值。权重值越高，服务器在负载均衡中被选中的概率就越大
        #当该ip 端口连接异常时，执行该脚本
        notify_down /etc/keepalived/shutdown.sh   #检查mysql服务down掉后执行的脚本
        TCP_CHECK {
            #实际物理机ip地址
            connect_ip  222.24.203.35
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
    interface enp4s2                 
    virtual_router_id 52            
    priority 40                     
    advert_int 1                     
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              
        10.40.10.141
    }
}


virtual_server 10.40.10.141 3306 { 
    delay_loop 2                     
    lb_algo rr                       
    lb_kind DR                       
    persistence_timeout 50           
    protocol TCP                   

        real_server  10.40.10.136 3306 {          
       weight=5                      
        notify_down /etc/keepalived/shutdown.sh   
        TCP_CHECK {
            connect_ip  10.40.10.136
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```

#123

```bash
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived


global_defs {
   router_id MYSQL-139
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security   
}


vrrp_instance VI_1 {
    state BACKUP                     
    interface enp4s2                 
    virtual_router_id 123            
    priority 40                     
    advert_int 1                     
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              
        10.40.10.142
    }
}


virtual_server 10.40.10.142 3306 { 
    delay_loop 2                     
    lb_algo rr                       
    lb_kind DR                       
    persistence_timeout 50           
    protocol TCP                   

        real_server  10.40.10.139 3306 {          
       weight=5                      
        notify_down /etc/keepalived/shutdown.sh   
        TCP_CHECK {
            connect_ip  10.40.10.139
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```



#121

```bash
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
    interface enp4s2                 
    virtual_router_id 121            
    priority 40                     
    advert_int 1                     
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              
        10.40.10.143
    }
}


virtual_server 10.40.10.143 3306 { 
    delay_loop 2                     
    lb_algo rr                       
    lb_kind DR                       
    persistence_timeout 50           
    protocol TCP                   

        real_server  10.40.10.137 3306 {          
       weight=5                      
        notify_down /etc/keepalived/shutdown.sh   
        TCP_CHECK {
            connect_ip  10.40.10.137
            connect_port 3306
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3

        }
    }
}

EOF
```



#122

```bash
cat >> /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived


global_defs {
   router_id MYSQL-138
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
   script_user root
   enable_script_security   
}


vrrp_instance VI_1 {
    state BACKUP                     
    interface enp4s2                 
    virtual_router_id 122            
    priority 40                     
    advert_int 1                     
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {              
        10.40.10.144
    }
}


virtual_server 10.40.10.144 3306 { 
    delay_loop 2                     
    lb_algo rr                       
    lb_kind DR                       
    persistence_timeout 50           
    protocol TCP                   

        real_server  10.40.10.138 3306 {          
       weight=5                      
        notify_down /etc/keepalived/shutdown.sh   
        TCP_CHECK {
            connect_ip  10.40.10.138
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
systemctl start keepalived && systemctl enable keepalived

systemctl status keepalived

```



#logs

```bash
[root@MHsql-db01 keepalived-2.3.3]# systemctl start keepalived
[root@MHsql-db01 keepalived-2.3.3]# systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2025-04-22 09:34:23 CST; 1s ago
     Docs: man:keepalived(8)
           man:keepalived.conf(5)
           man:genhash(1)
           https://keepalived.org
 Main PID: 2628369 (keepalived)
    Tasks: 3
   Memory: 1.0M
   CGroup: /system.slice/keepalived.service
           ├─2628369 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           ├─2628370 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           └─2628371 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D

Apr 22 09:34:23 MHsql-db01 Keepalived_healthcheckers[2628370]: Activating healthchecker for service [222.24.203.31]:tcp:3306 for VS [222.24.203.83]:tcp:3>
Apr 22 09:34:23 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) Strict mode does not support authentication. Ignoring.
Apr 22 09:34:23 MHsql-db01 Keepalived_vrrp[2628371]: Assigned address 222.24.203.31 for interface enp4s1
Apr 22 09:34:23 MHsql-db01 Keepalived_vrrp[2628371]: Registering gratuitous ARP shared channel
Apr 22 09:34:23 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) removing VIPs.
Apr 22 09:34:23 MHsql-db01 Keepalived[2628369]: Startup complete
Apr 22 09:34:23 MHsql-db01 systemd[1]: Started LVS and VRRP High Availability Monitor.
Apr 22 09:34:23 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) removing VIPs.
Apr 22 09:34:23 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) Entering BACKUP STATE (init)
Apr 22 09:34:23 MHsql-db01 Keepalived_vrrp[2628371]: VRRP sockpool: [ifindex(  2), family(IPv4), proto(112), fd(15,16) multicast, address(224.0.0.18)]
[root@MHsql-db01 keepalived-2.3.3]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: enp4s1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 28:6e:d4:89:ab:99 brd ff:ff:ff:ff:ff:ff
    inet 222.24.203.31/24 brd 222.24.203.255 scope global noprefixroute enp4s1
       valid_lft forever preferred_lft forever
    inet 222.24.203.83/32 scope global enp4s1
       valid_lft forever preferred_lft forever
[root@MHsql-db01 keepalived-2.3.3]# systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2025-04-22 09:34:23 CST; 8s ago
     Docs: man:keepalived(8)
           man:keepalived.conf(5)
           man:genhash(1)
           https://keepalived.org
 Main PID: 2628369 (keepalived)
    Tasks: 3
   Memory: 936.0K
   CGroup: /system.slice/keepalived.service
           ├─2628369 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           ├─2628370 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           └─2628371 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D

Apr 22 09:34:26 MHsql-db01 Keepalived_healthcheckers[2628370]: TCP connection to [222.24.203.31]:tcp:3306 success.
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) Receive advertisement timeout
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) Entering MASTER STATE
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) setting VIPs.
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: (VI_1) Sending/queueing gratuitous ARPs on enp4s1 for 222.24.203.83
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 22 09:34:26 MHsql-db01 Keepalived_vrrp[2628371]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
[root@MHsql-db01 keepalived-2.3.3]#


[root@MHsql-db01B keepalived-2.3.3]#  systemctl start keepalived
[root@MHsql-db01B keepalived-2.3.3]#  systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2025-04-22 09:36:53 CST; 2s ago
     Docs: man:keepalived(8)
           man:keepalived.conf(5)
           man:genhash(1)
           https://keepalived.org
 Main PID: 1211770 (keepalived)
    Tasks: 3
   Memory: 972.0K
   CGroup: /system.slice/keepalived.service
           ├─1211770 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           ├─1211771 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           └─1211772 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D

Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: Assigned address 222.24.203.35 for interface enp4s1
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: Registering gratuitous ARP shared channel
Apr 22 09:36:53 MHsql-db01B Keepalived[1211770]: Startup complete
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) removing VIPs.
Apr 22 09:36:53 MHsql-db01B systemd[1]: Started LVS and VRRP High Availability Monitor.
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) removing VIPs.
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) Entering BACKUP STATE (init)
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: VRRP sockpool: [ifindex(  2), family(IPv4), proto(112), fd(15,16) multicast, address(224.0.0.18)]
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) master set to 222.24.203.31
Apr 22 09:36:55 MHsql-db01B Keepalived_healthcheckers[1211771]: TCP connection to [222.24.203.35]:tcp:3306 success.
[root@MHsql-db01B keepalived-2.3.3]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet 222.24.203.84/32 scope global lo
       valid_lft forever preferred_lft forever
2: enp4s1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 28:6e:d4:89:b8:35 brd ff:ff:ff:ff:ff:ff
    inet 222.24.203.35/24 brd 222.24.203.255 scope global noprefixroute enp4s1
       valid_lft forever preferred_lft forever
[root@MHsql-db01B keepalived-2.3.3]#  systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2025-04-22 09:36:53 CST; 10s ago
     Docs: man:keepalived(8)
           man:keepalived.conf(5)
           man:genhash(1)
           https://keepalived.org
 Main PID: 1211770 (keepalived)
    Tasks: 3
   Memory: 940.0K
   CGroup: /system.slice/keepalived.service
           ├─1211770 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           ├─1211771 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D
           └─1211772 /usr/local/keepalived-2.3.3/sbin/keepalived --dont-fork -D

Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: Assigned address 222.24.203.35 for interface enp4s1
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: Registering gratuitous ARP shared channel
Apr 22 09:36:53 MHsql-db01B Keepalived[1211770]: Startup complete
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) removing VIPs.
Apr 22 09:36:53 MHsql-db01B systemd[1]: Started LVS and VRRP High Availability Monitor.
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) removing VIPs.
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) Entering BACKUP STATE (init)
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: VRRP sockpool: [ifindex(  2), family(IPv4), proto(112), fd(15,16) multicast, address(224.0.0.18)]
Apr 22 09:36:53 MHsql-db01B Keepalived_vrrp[1211772]: (VI_1) master set to 222.24.203.31
Apr 22 09:36:55 MHsql-db01B Keepalived_healthcheckers[1211771]: TCP connection to [222.24.203.35]:tcp:3306 success.

```





#### 5、查看vip是否启动

```bash
ip a

ping xxx.xxx.xx.xx

#如果此时ping不通第二个IP，那么可以关闭keepalived后，手动添加第二个IP，再ping测试
ip addr add 222.24.203.84/32 dev eth0
ping 192.168.1.100

#ip addr del 222.24.203.84/32 dev enp4s1
```

发现vip在主库上：
```
[root@MHsql-db01 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:1f:c2:9a brd ff:ff:ff:ff:ff:ff
    inet  222.24.203.31/25 brd 222.204.70.127 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet 222.204.70.112/32 scope global eth0
       valid_lft forever preferred_lft forever
```

#报错处理

#现象

```bash
ping vip时：
ping: sendmsg: Operation not permitted
```

#原因

```bash
#这不是网络不通，而是操作系统内核拒绝发送 ICMP 包，因为该 VIP (222.24.203.83/32) 是通过 LVS DR 模式绑定的，而不是标准的接口绑定方式

#在 Keepalived 中：

#如果启用了 vrrp_strict：

#非 MASTER 节点即使绑了 VIP，也不能发 ARP，也不能响应 ping 请求（会触发 kernel 层级 drop）。

#本机也不能对自己绑定的 VIP 发起访问或 ping 请求。
```

#接近办法

```bash
#方法一：
注释掉参数vrrp_strict，生产环境不建议

#方法二：
安装keepalive最新版
```



#logs

```bash

[root@MHsql-db01 ~]# systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2025-04-21 10:40:00 CST; 52s ago
  Process: 2320497 ExecStart=/usr/sbin/keepalived $KEEPALIVED_OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 2320499 (keepalived)
    Tasks: 3
   Memory: 1004.0K
   CGroup: /system.slice/keepalived.service
           ├─2320499 /usr/sbin/keepalived -D
           ├─2320500 /usr/sbin/keepalived -D
           └─2320501 /usr/sbin/keepalived -D

Apr 21 10:40:04 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:04 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:04 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:04 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:09 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:09 MHsql-db01 Keepalived_vrrp[2320501]: (VI_1) Sending/queueing gratuitous ARPs on enp4s1 for 222.24.203.83
Apr 21 10:40:09 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:09 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:09 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
Apr 21 10:40:09 MHsql-db01 Keepalived_vrrp[2320501]: Sending gratuitous ARP on enp4s1 for 222.24.203.83
[root@MHsql-db01 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: enp4s1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 28:6e:d4:89:ab:99 brd ff:ff:ff:ff:ff:ff
    inet 222.24.203.31/24 brd 222.24.203.255 scope global noprefixroute enp4s1
       valid_lft forever preferred_lft forever
    inet 222.24.203.83/32 scope global enp4s1
       valid_lft forever preferred_lft forever
[root@MHsql-db01 ~]# ping 222.24.203.83
PING 222.24.203.83 (222.24.203.83) 56(84) bytes of data.
ping: sendmsg: Operation not permitted
ping: sendmsg: Operation not permitted
^C
--- 222.24.203.83 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1003ms


[root@MHsql-db01B ~]# systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2025-04-21 10:40:18 CST; 14s ago
  Process: 904047 ExecStart=/usr/sbin/keepalived $KEEPALIVED_OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 904048 (keepalived)
    Tasks: 3
   Memory: 1.0M
   CGroup: /system.slice/keepalived.service
           ├─904048 /usr/sbin/keepalived -D
           ├─904049 /usr/sbin/keepalived -D
           └─904050 /usr/sbin/keepalived -D

Apr 21 10:40:18 MHsql-db01B Keepalived_healthcheckers[904049]: Activating healthchecker for service [222.24.203.35]:tcp:3306 for VS [222.24.203.83]:tcp:33>
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: Opening file '/etc/keepalived/keepalived.conf'.
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) Strict mode does not support authentication. Ignoring.
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: Assigned address 222.24.203.35 for interface enp4s1
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: Registering gratuitous ARP shared channel
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) removing VIPs.
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) removing firewall drop rule
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) Entering BACKUP STATE (init)
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: VRRP sockpool: [ifindex(2), family(IPv4), proto(112), unicast(0), fd(13,14)]
Apr 21 10:40:21 MHsql-db01B Keepalived_healthcheckers[904049]: TCP connection to [222.24.203.35]:tcp:3306 success.
[root@MHsql-db01B ~]# ping 222.24.203.83
PING 222.24.203.83 (222.24.203.83) 56(84) bytes of data.
^C
--- 222.24.203.83 ping statistics ---
6 packets transmitted, 0 received, 100% packet loss, time 5108ms

[root@MHsql-db01B ~]# ping 222.24.203.31
PING 222.24.203.31 (222.24.203.31) 56(84) bytes of data.
64 bytes from 222.24.203.31: icmp_seq=1 ttl=64 time=0.822 ms
64 bytes from 222.24.203.31: icmp_seq=2 ttl=64 time=0.793 ms
^C
--- 222.24.203.31 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1027ms
rtt min/avg/max/mdev = 0.793/0.807/0.822/0.014 ms
[root@MHsql-db01B ~]# systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2025-04-21 10:40:18 CST; 3min 20s ago
  Process: 904047 ExecStart=/usr/sbin/keepalived $KEEPALIVED_OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 904048 (keepalived)
    Tasks: 3
   Memory: 1004.0K
   CGroup: /system.slice/keepalived.service
           ├─904048 /usr/sbin/keepalived -D
           ├─904049 /usr/sbin/keepalived -D
           └─904050 /usr/sbin/keepalived -D

Apr 21 10:40:18 MHsql-db01B Keepalived_healthcheckers[904049]: Activating healthchecker for service [222.24.203.35]:tcp:3306 for VS [222.24.203.83]:tcp:33>
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: Opening file '/etc/keepalived/keepalived.conf'.
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) Strict mode does not support authentication. Ignoring.
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: Assigned address 222.24.203.35 for interface enp4s1
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: Registering gratuitous ARP shared channel
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) removing VIPs.
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) removing firewall drop rule
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: (VI_1) Entering BACKUP STATE (init)
Apr 21 10:40:18 MHsql-db01B Keepalived_vrrp[904050]: VRRP sockpool: [ifindex(2), family(IPv4), proto(112), unicast(0), fd(13,14)]
Apr 21 10:40:21 MHsql-db01B Keepalived_healthcheckers[904049]: TCP connection to [222.24.203.35]:tcp:3306 success.
[root@MHsql-db01B ~]#

```





#### 6、主库关闭mysqld/keepalived测试

```bash
systemctl stop mysqld
systemctl status mysqld

systemctl status keepalived

ip a
```

```sql
SELECT @@hostname;
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
 222.24.203.31 MHsql-db01
 222.24.203.35 MHsql-db01B

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
while true; do date;mysql -u testuser -pQwert123.. -h 10.40.10.141 -e 'use testdb;insert into nowdate values (null, now());'; sleep 1;done

while true; do date;mysql -u testuser -pQwert123.. -h 10.40.10.141 -e 'SELECT @@hostname;'; sleep 1;done
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

```bash
#如果执行systemctl stop mysqld，那么关闭数据库会有时间消耗
#如果执行reboot服务器，那么间隔很短暂
```






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
#使用ip addr命令查看实际使用的物理机为 222.24.203.31，所以master-1( 222.24.203.31)服务器mysql为主数据库。

##### 6) 停止物理机mysql服务
#此时手动将master-1服务器mysql停止，keepalived检测到 222.24.203.31服务3306端口连接失败，会执行/etc/keepalived/shutdown.sh脚本，将 222.24.203.31服务器keepalived应用结束

```bash
service mysql stop
Shutting down MySQL............. SUCCESS! 
```


##### 7) 查看漂移ip执行情况
#此时再连接 222.24.203.35服务下，ip addr查看，发现已经实际将物理机由master-1( 222.24.203.31)到master-2( 222.24.203.35)服务器上

##### 8) 在新的主服务器插入数据
#再使用mysql连接工具连接 222.24.203.35的mysql，插入一条数据，测试是否将数据存入master-2( 222.24.203.35)服务器mysql中

```mysql
insert into ceshi1 values(6,'李四','英语',94);
```



##### 9) 查看新主服务器数据
#查看master-2服务器mysql数据，数据已同步，说明keepalived搭建高可用成功，当master-1服务器mysql出现问题后keepalived自动漂移IP到实体机master-2服务器上，从而使master-2服务器mysql作为主数据库。

##### 10) 重启master-1服务，查看数据同步情况
#此时再启动master-1( 222.24.203.31)服务器mysql、keepalived应用

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
#主库重启后，追从库数据logs

```bash
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.24.203.35
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000049
          Read_Source_Log_Pos: 490306513
               Relay_Log_File: relay-bin.000101
                Relay_Log_Pos: 60777814
        Relay_Source_Log_File: mysql-bin.000049
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
          Exec_Source_Log_Pos: 356401275
              Relay_Log_Space: 193642728
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File:
           Source_SSL_CA_Path:
              Source_SSL_Cert:
            Source_SSL_Cipher:
               Source_SSL_Key:
        Seconds_Behind_Source: 343
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Source_Server_Id: 81
                  Source_UUID: 69fc8d5a-1c39-11f0-88c3-286ed489b835
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
           Retrieved_Gtid_Set: 69fc8d5a-1c39-11f0-88c3-286ed489b835:5329-199273
            Executed_Gtid_Set: 69fc8d5a-1c39-11f0-88c3-286ed489b835:1-64138,
6a48c612-1c39-11f0-b37f-286ed489ab99:1-427600
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

root@localhost:mysql.sock [(none)]>

root@localhost:mysql.sock [(none)]> show replica status\G;
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 222.24.203.35
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000049
          Read_Source_Log_Pos: 490342017
               Relay_Log_File: relay-bin.000101
                Relay_Log_Pos: 193642524
        Relay_Source_Log_File: mysql-bin.000049
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
          Exec_Source_Log_Pos: 490342017
              Relay_Log_Space: 193642728
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
             Source_Server_Id: 81
                  Source_UUID: 69fc8d5a-1c39-11f0-88c3-286ed489b835
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
           Retrieved_Gtid_Set: 69fc8d5a-1c39-11f0-88c3-286ed489b835:5329-199273
            Executed_Gtid_Set: 69fc8d5a-1c39-11f0-88c3-286ed489b835:1-199273,
6a48c612-1c39-11f0-b37f-286ed489ab99:1-427652
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

root@localhost:mysql.sock [(none)]>


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



#每个库一个文件的备份

```bash
#!/bin/bash
# mysql 数据库差异化备份
# 用户名和密码，注意实际情况！也可以在/etc/my.cnf中配置
username="root"
mypasswd="ABC123!@#"

beginTime=`date +"%Y年%m月%d日 %H:%M:%S"`

# 备份目录,注意实际环境目录
bakDir=/data/backup
# 日志文件
logFile=/data/backup/bak.log
# 备份文件开始

nowDate=`date +%Y%m%d`
#定义不需要备份的表
ignore_table="--ignore-table=cas_server.TB_SSO_LOG_copy1 --ignore-table=cas_server.TB_SERVICE_ACCESS_LOG --ignore-table=cas_server.TB_SERVICE_ACCESS_LOG_08 --ignore-table=cas_server.TB_SSO_LOG --ignore-table=cas_server.TB_SSO_LOG_08 --ignore-table=cas_server.TB_AUTHENTICATION_LOG --ignore-table=cas_server.TB_AUTHENTICATION_LOG_08 --ignore-table=authx_log.TB_L_APPLY_CALL_LOG --ignore-table=authx_log.TB_L_APPLY_CALL_LOG_08 --ignore-table=authx_log.TB_L_SERVICE_ACCESS_LOG --ignore-table=authx_log.TB_L_SERVICE_ACCESS_LOG_08 --ignore-table=authx_log.TB_L_ONLINE_LOG --ignore-table=authx_log.TB_L_AUTHENTICATION_LOG --ignore-table=authx_log.TB_L_AUTHENTICATION_LOG_08 --ignore-table=authx_log.TB_L_ONLINE_LOG0819 --ignore-table=jobs_server.TB_JOB_TASK_RECORD_DETAIL"
cd $bakDir
for dbname in $(mysql -u ${username} -p${mypasswd} -e "show databases;" --skip-column-names| grep -v information_schema | grep -v performance_schema| grep -v sys)
do
dumpFile=$dbname-$nowDate".sql"
echo 备份开始:$beginTime >> $logFile
echo "Backing up database $dbname at $(date +%F_%H-%M) ...">> $logFile
# 全量备份
/usr/bin/mysqldump -u${username} -p${mypasswd} --quick --events --databases $dbname ${ignore_table} --source-data=2 --single-transaction --set-gtid-purged=OFF >${bakDir}/$dumpFile

echo "Backed down database $dbname at $(date +%F_%H-%M) ...">> $logFile
done

gzDumpFile="databak_${nowDate}.sql.tgz"


# 打包
/usr/bin/tar -zvcf $gzDumpFile ${bakDir}/*.sql
/usr/bin/rm ${bakDir}/*.sql

endTime=`date +"%Y年%m月%d日 %H:%M:%S"`
echo 打包结束:$endTime $gzDumpFile succ！ >> $logFile

##删除过期备份
find ${bakDir} -name 'databak_*.sql.tgz' -mtime +7 -exec rm {} \;

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

#开放3306和vrrp

```bash
systemctl start firewalld

systemctl enable firewalld

systemctl status firewalld


sudo firewall-cmd --permanent --add-port=3306/tcp

firewall-cmd --add-rich-rule='rule protocol value="vrrp" accept' --permanent

firewall-cmd --reload

firewall-cmd --list-all
```



#ip白名单设置

#精简版

```bash
#!/usr/bin/env bash
set -euo pipefail

ZONE=public
IFACE=eth0

# Auto-detect local IP
LOCAL_IP=$(ip -4 addr show dev "$IFACE" | awk '/inet /{print $2}' | cut -d/ -f1 | grep -E '^10\.20\.12\.(136|137)$' || true)

if [[ "$LOCAL_IP" == "10.20.12.136" ]]; then
  PEER_IP=10.20.12.137
elif [[ "$LOCAL_IP" == "10.20.12.137" ]]; then
  PEER_IP=10.20.12.136
else
  echo "Unable to recognize local machine as 10.20.12.136 or 10.20.12.137 on $IFACE" >&2
  exit 1
fi

echo "Configuring firewall on $LOCAL_IP (peer: $PEER_IP)"

# Enable firewalld
systemctl enable firewalld --now >/dev/null
firewall-cmd --state

# Basic services
firewall-cmd --permanent --zone="$ZONE" --add-service=ssh

# Clean up old MySQL configurations
firewall-cmd --permanent --zone="$ZONE" --remove-service=mysql 2>/dev/null || true
firewall-cmd --permanent --zone="$ZONE" --remove-port=3306/tcp 2>/dev/null || true

# Create/verify ipset
if ! firewall-cmd --permanent --get-ipsets | grep -qw mysql_allowed; then
  firewall-cmd --permanent --new-ipset=mysql_allowed --type=hash:ip
fi

# Add allowed IPs
ALLOW_IPS=(
  # Application servers
  10.20.12.103 10.20.12.104 10.20.12.105 10.20.12.106 10.20.12.107
  10.20.12.108 10.20.12.109 10.20.12.110 10.20.12.111 10.20.12.112
  10.20.12.113 10.20.12.114 10.20.12.118 10.20.12.119
  # Other servers
  10.20.12.128 10.20.12.129 10.20.12.130 10.20.12.132 10.20.12.133 10.20.12.134
  # MySQL replication peers
  10.20.12.136 10.20.12.137
)

for ip in "${ALLOW_IPS[@]}"; do
  firewall-cmd --permanent --ipset=mysql_allowed --add-entry="$ip" 2>/dev/null || true
done

# MySQL access rules
firewall-cmd --permanent --zone="$ZONE" \
  --add-rich-rule='rule family="ipv4" source ipset="mysql_allowed" port port="3306" protocol="tcp" accept'

# Clean up old VRRP rules
firewall-cmd --permanent --zone="$ZONE" -mysql
-remove-rich-rule='rule protocol value="vrrp" accept' 2>/dev/null || true
firewall-cmd --permanent --zone="$ZONE" --remove-rich-rule='rule family="ipv4" destination address="224.0.0.18" accept' 2>/dev/null || true
firewall-cmd --permanent --zone="$ZONE" --remove-rich-rule='rule family="ipv4" source address="10.20.12.136" protocol value="vrrp" accept' 2>/dev/null || true
firewall-cmd --permanent --zone="$ZONE" --remove-rich-rule='rule family="ipv4" source address="10.20.12.137" protocol value="vrrp" accept' 2>/dev/null || true

# Add VRRP rule for keepalived (without interface specification for OL7 compatibility)
firewall-cmd --permanent --zone="$ZONE" \
  --add-rich-rule='rule family="ipv4" source address="10.20.12.0/24" destination address="224.0.0.18" protocol value="vrrp" accept'

# Reload
firewall-cmd --reload

# Verification
echo "================================"
echo "Configuration: $LOCAL_IP -> $PEER_IP"
echo "================================"
echo "Rich Rules ($ZONE):"
firewall-cmd --zone="$ZONE" --list-rich-rules
echo "================================"
echo "MySQL Allowed IPs:"
firewall-cmd --info-ipset=mysql_allowed
echo "================================"
```

