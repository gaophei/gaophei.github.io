**19C RAC for Centos7.9 安装手册**

## 目录
1 环境..............................................................................................................................................2
1.1. 系统版本： ..............................................................................................................................2
1.2. ASM 磁盘组规划 ....................................................................................................................2
1.3. 主机网络规划..........................................................................................................................2
1.4. 操作系统配置部分.................................................................................................................2
2 准备工作（oracle01 与 oracle02 同时配置） ............................................................................................3
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
[root@oracle01 Packages]# cat /etc/redhat-release
CentOS Linux release 7.9.2009 (Core)
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
网络配置               节点 1                               节点 2
主机名称               oracle01                          oracle02
public ip            10.4.0.41                         10.4.0.42
private ip           3.3.3.41                          3.3.3.42
vip                  10.4.0.43                        10.4.0.44
scan ip              10.4.0.45 
```
###学校实际参数
```
10.0.1.68  密码Jshl@iop*()mh
Jscn2022!


[root@stuora1 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 36000c290895fb077d085d625b053999c
/dev/sdb 36000c29c7593c00dd6020d68c379af8b
/dev/sdc 36000c29191410ca350a65dd4d2ab87f9
/dev/sdd 36000c29c8ff162cd8141ad12e89e4f67
/dev/sde 36000c2901faead7b7f181d282cf639ac
/dev/sdf 36000c293747331cfc85e8d668f728f4d
/dev/sdg 36000c2979ccf579f7c2c288b3d645e50
/dev/sdh 36000c290d12b15a3bdece97e79c7a665
[root@stuora1 ~]# lsblk
NAME            MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
fd0               2:0    1     4K  0 disk
sda               8:0    0   533G  0 disk
├─sda1            8:1    0     1G  0 part /boot
└─sda2            8:2    0   532G  0 part
  ├─centos-root 253:0    0    50G  0 lvm  /
  ├─centos-swap 253:1    0  31.5G  0 lvm  [SWAP]
  └─centos-home 253:2    0 450.5G  0 lvm  /home
sdb               8:16   0   100G  0 disk
sdc               8:32   0   100G  0 disk
sdd               8:48   0   100G  0 disk
sde               8:64   0     2T  0 disk
sdf               8:80   0     2T  0 disk
sdg               8:96   0     2T  0 disk
sdh               8:112  0     2T  0 disk
sr0              11:0    1   4.4G  0 rom
[root@stuora1 ~]#


[root@stuora2 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
36000c29191410ca350a65dd4d2ab87f9
[root@stuora2 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 36000c29a15618293a78d56ceb841c184
/dev/sdb 36000c29c7593c00dd6020d68c379af8b
/dev/sdc 36000c29191410ca350a65dd4d2ab87f9
/dev/sdd 36000c29c8ff162cd8141ad12e89e4f67
/dev/sde 36000c2901faead7b7f181d282cf639ac
/dev/sdf 36000c293747331cfc85e8d668f728f4d
/dev/sdg 36000c2979ccf579f7c2c288b3d645e50
/dev/sdh 36000c290d12b15a3bdece97e79c7a665
[root@stuora2 ~]# lsblk
NAME            MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
fd0               2:0    1     4K  0 disk
sda               8:0    0   533G  0 disk
├─sda1            8:1    0     1G  0 part /boot
└─sda2            8:2    0   532G  0 part
  ├─centos-root 253:0    0    50G  0 lvm  /
  ├─centos-swap 253:1    0  31.5G  0 lvm  [SWAP]
  └─centos-home 253:2    0 450.5G  0 lvm  /home
sdb               8:16   0   100G  0 disk
sdc               8:32   0   100G  0 disk
sdd               8:48   0   100G  0 disk
sde               8:64   0     2T  0 disk
sdf               8:80   0     2T  0 disk
sdg               8:96   0     2T  0 disk
sdh               8:112  0     2T  0 disk
sr0              11:0    1   4.4G  0 rom
[root@stuora2 ~]#

[root@stuora1 network-scripts]# ls
ifcfg-ens192  ifdown-eth   ifdown-post    ifdown-TeamPort  ifup-eth   ifup-plip    ifup-sit       init.ipv6-global
ifcfg-ens32   ifdown-ib    ifdown-ppp     ifdown-tunnel    ifup-ib    ifup-plusb   ifup-Team      network-functions
ifcfg-lo      ifdown-ippp  ifdown-routes  ifup             ifup-ippp  ifup-post    ifup-TeamPort  network-functions-ipv6
ifdown        ifdown-ipv6  ifdown-sit     ifup-aliases     ifup-ipv6  ifup-ppp     ifup-tunnel
ifdown-bnep   ifdown-isdn  ifdown-Team    ifup-bnep        ifup-isdn  ifup-routes  ifup-wireless
[root@stuora1 network-scripts]# cat ifcfg-ens192
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="yes"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="ens192"
UUID="8c825358-4ea8-3f1d-bfef-c327c6575d74"
DEVICE="ens192"
ONBOOT="yes"
IPADDR="1.1.1.1"
PREFIX="24"
GATEWAY="1.1.1.254"
IPV6_PRIVACY="no"
[root@stuora1 network-scripts]# cat ifcfg-ens32
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="yes"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="ens32"
UUID="f3d887d9-e9e6-43cb-81a2-1eeb09311abd"
DEVICE="ens32"
ONBOOT="yes"
IPADDR="10.0.1.68"
PREFIX="24"
GATEWAY="10.0.1.254"
DNS1="10.0.1.135"
IPV6_PRIVACY="no"
[root@stuora1 network-scripts]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.1.254      0.0.0.0         UG    100    0        0 ens32
0.0.0.0         1.1.1.254       0.0.0.0         UG    101    0        0 ens192
1.1.1.0         0.0.0.0         255.255.255.0   U     101    0        0 ens192
10.0.1.0        0.0.0.0         255.255.255.0   U     100    0        0 ens32
169.254.0.0     0.0.0.0         255.255.0.0     U     0      0        0 ens192
[root@stuora1 network-scripts]# ip route list
default via 10.0.1.254 dev ens32 proto static metric 100
default via 1.1.1.254 dev ens192 proto static metric 101
1.1.1.0/24 dev ens192 proto kernel scope link src 1.1.1.1 metric 101
10.0.1.0/24 dev ens32 proto kernel scope link src 10.0.1.68 metric 100
169.254.0.0/16 dev ens192 proto kernel scope link src 169.254.69.234
[root@stuora1 network-scripts]# nmcli con show
NAME    UUID                                  TYPE      DEVICE
ens32   f3d887d9-e9e6-43cb-81a2-1eeb09311abd  ethernet  ens32
ens192  8c825358-4ea8-3f1d-bfef-c327c6575d74  ethernet  ens192
[root@stuora1 network-scripts]#




[root@stuora2 ~]# cd /etc/sysconfig/network-scripts/
[root@stuora2 network-scripts]# ls
ifcfg-ens192  ifdown-eth   ifdown-post    ifdown-TeamPort  ifup-eth   ifup-plip    ifup-sit       init.ipv6-global
ifcfg-ens32   ifdown-ib    ifdown-ppp     ifdown-tunnel    ifup-ib    ifup-plusb   ifup-Team      network-functions
ifcfg-lo      ifdown-ippp  ifdown-routes  ifup             ifup-ippp  ifup-post    ifup-TeamPort  network-functions-ipv6
ifdown        ifdown-ipv6  ifdown-sit     ifup-aliases     ifup-ipv6  ifup-ppp     ifup-tunnel
ifdown-bnep   ifdown-isdn  ifdown-Team    ifup-bnep        ifup-isdn  ifup-routes  ifup-wireless
[root@stuora2 network-scripts]# cat ifcfg-ens192
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="yes"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="ens192"
UUID="8905a107-5be6-38c2-b94f-9c924d988574"
DEVICE="ens192"
ONBOOT="yes"
IPADDR="1.1.1.2"
PREFIX="24"
GATEWAY="1.1.1.254"
IPV6_PRIVACY="no"
[root@stuora2 network-scripts]# cat ifcfg-ens32
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="yes"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="ens32"
UUID="6ec7e9d3-01ef-4025-a839-9a4e7b687bbc"
DEVICE="ens32"
ONBOOT="yes"
IPADDR="10.0.1.69"
PREFIX="24"
GATEWAY="10.0.1.254"
DNS1="10.0.1.135"
IPV6_PRIVACY="no"
[root@stuora2 network-scripts]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.1.254      0.0.0.0         UG    100    0        0 ens32
0.0.0.0         1.1.1.254       0.0.0.0         UG    101    0        0 ens192
1.1.1.0         0.0.0.0         255.255.255.0   U     101    0        0 ens192
10.0.1.0        0.0.0.0         255.255.255.0   U     100    0        0 ens32
169.254.0.0     0.0.0.0         255.255.0.0     U     0      0        0 ens192
[root@stuora2 network-scripts]# ip route list
default via 10.0.1.254 dev ens32 proto static metric 100
default via 1.1.1.254 dev ens192 proto static metric 101
1.1.1.0/24 dev ens192 proto kernel scope link src 1.1.1.2 metric 101
10.0.1.0/24 dev ens32 proto kernel scope link src 10.0.1.69 metric 100
169.254.0.0/16 dev ens192 proto kernel scope link src 169.254.35.75
[root@stuora2 network-scripts]# nmcli con show
NAME    UUID                                  TYPE      DEVICE
ens32   6ec7e9d3-01ef-4025-a839-9a4e7b687bbc  ethernet  ens32
ens192  8905a107-5be6-38c2-b94f-9c924d988574  ethernet  ens192
[root@stuora2 network-scripts]#


[grid@stuora1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       stuora1
               ONLINE  ONLINE       stuora2
ora.FRA.dg
               ONLINE  ONLINE       stuora1
               ONLINE  ONLINE       stuora2
ora.LISTENER.lsnr
               ONLINE  ONLINE       stuora1
               ONLINE  ONLINE       stuora2
ora.OCR.dg
               ONLINE  ONLINE       stuora1
               ONLINE  ONLINE       stuora2
ora.asm
               ONLINE  ONLINE       stuora1                  Started
               ONLINE  ONLINE       stuora2                  Started
ora.gsd
               OFFLINE OFFLINE      stuora1
               OFFLINE OFFLINE      stuora2
ora.net1.network
               ONLINE  ONLINE       stuora1
               ONLINE  ONLINE       stuora2
ora.ons
               ONLINE  ONLINE       stuora1
               ONLINE  ONLINE       stuora2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       stuora1
ora.cvu
      1        ONLINE  ONLINE       stuora1
ora.oc4j
      1        ONLINE  ONLINE       stuora1
ora.scan1.vip
      1        ONLINE  ONLINE       stuora1
ora.stuora1.vip
      1        ONLINE  ONLINE       stuora1
ora.stuora2.vip
      1        ONLINE  ONLINE       stuora2
ora.xydb.db
      1        ONLINE  ONLINE       stuora1                  Open
      2        ONLINE  ONLINE       stuora2                  Open
[grid@stuora1 ~]$


```
#网卡配置及多路径配置
```bash
ifconfig
nmcli conn show
#只运行了network
#NetworkManager未运行
#关闭NetworkManager
#systemctl stop NetworkManager
[root@localhost ~]# nmcli conn show
Error: NetworkManager is not running.
```

```
假如网卡绑定：
#eno8为私有网卡
#ens3f0和ens3f1d1绑定为team0为业务网卡
```
#节点一oracle01
```bash
nmcli con mod eno8 ipv4.addresses 3.3.3.41/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '10.4.0.41/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#节点二oracle02
```bash
nmcli con mod eno8 ipv4.addresses 3.3.3.42/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '10.4.0.41/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#实际网卡的相关配置
#oracle01

```
[root@oracle01 ~]# nmcli dev
[root@oracle01 ~]# nmcli conn show
Error: NetworkManager is not running.

[root@oracle01 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
     Docs: man:NetworkManager(8)
[root@oracle01 ~]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.4.0.41  netmask 255.255.254.0  broadcast 10.4.1.255
        inet6 fe80::fcfc:feff:fe52:7f24  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:52:7f:24  txqueuelen 1000  (Ethernet)
        RX packets 1237  bytes 134249 (131.1 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 178  bytes 23444 (22.8 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 3.3.3.41  netmask 255.255.255.0  broadcast 3.3.3.255
        inet6 fe80::fcfc:feff:fecd:5c79  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:cd:5c:79  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 4  bytes 376 (376.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4  bytes 376 (376.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@oracle01 ~]# nmcli con show
错误：网络管理器（NetworkManager）未运行。
[root@oracle01 ~]# cd /etc/sysconfig/network-scripts/
[root@oracle01 network-scripts]# ls
ifcfg-eth0  ifdown-bnep  ifdown-isdn    ifdown-sit       ifup          ifup-ippp  ifup-plusb   ifup-sit       ifup-wireless
ifcfg-eth1  ifdown-eth   ifdown-post    ifdown-Team      ifup-aliases  ifup-ipv6  ifup-post    ifup-Team      init.ipv6-global
ifcfg-lo    ifdown-ippp  ifdown-ppp     ifdown-TeamPort  ifup-bnep     ifup-isdn  ifup-ppp     ifup-TeamPort  network-functions
ifdown      ifdown-ipv6  ifdown-routes  ifdown-tunnel    ifup-eth      ifup-plip  ifup-routes  ifup-tunnel    network-functions-ipv6
[root@oracle01 network-scripts]# cat ifcfg-eth0
DEFROUTE=yes
PROXY_METHOD=none
BROWSER_ONLY=no
IPV6INIT=no
TYPE=Ethernet
DEVICE=eth0
BOOTPROTO=static
ONBOOT=yes
NAME=eth0
HWADDR=FE:FC:FE:52:7F:24
PEERDNS=no
NM_CONTROLLED=no
IPADDR=10.4.0.41
NETMASK=255.255.254.0
GATEWAY=10.4.0.1
METRIC=100
[root@oracle01 network-scripts]# cat ifcfg-eth1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth1
UUID=0d8a61a2-cb0e-4f39-a3d7-f330cbd0e22c
DEVICE=eth1
ONBOOT=yes
IPADDR=3.3.3.41
PREFIX=24
[root@oracle01 network-scripts]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:52:7f:24 brd ff:ff:ff:ff:ff:ff
    inet 10.4.0.41/23 brd 10.4.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::fcfc:feff:fe52:7f24/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:cd:5c:79 brd ff:ff:ff:ff:ff:ff
    inet 3.3.3.41/24 brd 3.3.3.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::fcfc:feff:fecd:5c79/64 scope link
       valid_lft forever preferred_lft forever
[root@oracle01 network-scripts]# ip route list
default via 10.4.0.1 dev eth0 metric 100
3.3.3.0/24 dev eth1 proto kernel scope link src 3.3.3.41
10.4.0.0/23 dev eth0 proto kernel scope link src 10.4.0.41
169.254.0.0/16 dev eth0 scope link metric 1002
169.254.0.0/16 dev eth1 scope link metric 1003
[root@oracle01 network-scripts]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.4.0.1        0.0.0.0         UG    100    0        0 eth0
3.3.3.0         0.0.0.0         255.255.255.0   U     0      0        0 eth1
10.4.0.0        0.0.0.0         255.255.254.0   U     0      0        0 eth0
169.254.0.0     0.0.0.0         255.255.0.0     U     1002   0        0 eth0
169.254.0.0     0.0.0.0         255.255.0.0     U     1003   0        0 eth1
[root@oracle01 network-scripts]#
```
#oracle02
```
[root@oracle02 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
     Docs: man:NetworkManager(8)
[root@oracle02 ~]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.4.0.42  netmask 255.255.254.0  broadcast 10.4.1.255
        inet6 fe80::fcfc:feff:fee0:d1c0  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:e0:d1:c0  txqueuelen 1000  (Ethernet)
        RX packets 1351  bytes 144831 (141.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 182  bytes 23674 (23.1 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 3.3.3.42  netmask 255.255.255.0  broadcast 3.3.3.255
        inet6 fe80::fcfc:feff:fe07:abee  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:07:ab:ee  txqueuelen 1000  (Ethernet)
        RX packets 14  bytes 908 (908.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 4  bytes 376 (376.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4  bytes 376 (376.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@oracle02 ~]# nmcli con show
错误：网络管理器（NetworkManager）未运行。
[root@oracle02 ~]# cd /etc/sysconfig/network-scripts/
[root@oracle02 network-scripts]# ls
ifcfg-eth0  ifdown-bnep  ifdown-isdn    ifdown-sit       ifup          ifup-ippp  ifup-plusb   ifup-sit       ifup-wireless
ifcfg-eth1  ifdown-eth   ifdown-post    ifdown-Team      ifup-aliases  ifup-ipv6  ifup-post    ifup-Team      init.ipv6-global
ifcfg-lo    ifdown-ippp  ifdown-ppp     ifdown-TeamPort  ifup-bnep     ifup-isdn  ifup-ppp     ifup-TeamPort  network-functions
ifdown      ifdown-ipv6  ifdown-routes  ifdown-tunnel    ifup-eth      ifup-plip  ifup-routes  ifup-tunnel    network-functions-ipv6
[root@oracle02 network-scripts]# cat ifcfg-eth0
DEFROUTE=yes
PROXY_METHOD=none
BROWSER_ONLY=no
IPV6INIT=no
TYPE=Ethernet
DEVICE=eth0
BOOTPROTO=static
ONBOOT=yes
NAME=eth0
HWADDR=FE:FC:FE:E0:D1:C0
PEERDNS=no
NM_CONTROLLED=no
IPADDR=10.4.0.42
NETMASK=255.255.254.0
GATEWAY=10.4.0.1
METRIC=100
[root@oracle02 network-scripts]# cat ifcfg-eth1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth1
UUID=0d8a61a2-cb0e-4f39-a3d7-f330cbd0e22c
DEVICE=eth1
ONBOOT=yes
IPADDR=3.3.3.42
PREFIX=24
[root@oracle02 network-scripts]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:e0:d1:c0 brd ff:ff:ff:ff:ff:ff
    inet 10.4.0.42/23 brd 10.4.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::fcfc:feff:fee0:d1c0/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:07:ab:ee brd ff:ff:ff:ff:ff:ff
    inet 3.3.3.42/24 brd 3.3.3.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::fcfc:feff:fe07:abee/64 scope link
       valid_lft forever preferred_lft forever
[root@oracle02 network-scripts]# ip route list
default via 10.4.0.1 dev eth0 metric 100
3.3.3.0/24 dev eth1 proto kernel scope link src 3.3.3.42
10.4.0.0/23 dev eth0 proto kernel scope link src 10.4.0.42
169.254.0.0/16 dev eth0 scope link metric 1002
169.254.0.0/16 dev eth1 scope link metric 1003
[root@oracle02 network-scripts]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.4.0.1        0.0.0.0         UG    100    0        0 eth0
3.3.3.0         0.0.0.0         255.255.255.0   U     0      0        0 eth1
10.4.0.0        0.0.0.0         255.255.254.0   U     0      0        0 eth0
169.254.0.0     0.0.0.0         255.255.0.0     U     1002   0        0 eth0
169.254.0.0     0.0.0.0         255.255.0.0     U     1003   0        0 eth1
[root@oracle02 network-scripts]#
```
### 1.4. 操作系统配置部分

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
[root@oracle02 ~]# cat /etc/multipath/
bindings  wwids     
[root@oracle02 ~]# cat /etc/multipath/bindings 
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
[root@oracle02 ~]# cat /etc/multipath/wwids 
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

[root@oracle02 ~]# sfdisk -s|grep mpath
/dev/mapper/mpatha: 104857600
/dev/mapper/mpathb: 104857600
/dev/mapper/mpathc: 104857600
/dev/mapper/mpathd: 2147483648
/dev/mapper/mpathe: 2147483648
/dev/mapper/mpathf: 2147483648
/dev/mapper/mpathg: 2147483648

[root@oracle01 ~]# multipathd show maps
name   sysfs uuid
mpatha dm-2  24c740a67e89393fa6c9ce90079a4df08
mpathb dm-3  2bf57071b2488dae06c9ce90079a4df08
mpathc dm-4  2ee6c414e797cb16f6c9ce90079a4df08
mpathd dm-5  2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe dm-6  2086fa4c938d839c66c9ce90079a4df08
mpathf dm-7  27b44daa76accbc526c9ce90079a4df08
mpathg dm-8  2aa67dbb0c9c0573b6c9ce90079a4df08
```

## 2.准备工作（oracle01 与 oracle02 同时配置）

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
#Ycit2022!
```
### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#oracle01
hostnamectl set-hostname oracle01
#oracle02
hostnamectl set-hostname oracle02

cat >> /etc/hosts <<EOF
#public ip 
10.4.0.41 oracle01
10.4.0.42 oracle02
#vip
10.4.0.43 oracle01-vip
10.4.0.44 oracle02-vip
#private ip
3.3.3.41 oracle01-prv
3.3.3.42 oracle02-prv
#scan ip
10.4.0.45 rac-scan
EOF

```
### 2.5. 禁用 NTP

#检查两节点时间，时区是否相同，并禁止 ntp
```bash
systemctl disable ntpd.service
systemctl stop ntpd.service
mv /etc/ntp.conf /etc/ntp.conf.orig
[root@oracle01 ~]# systemctl disable ntpd.service
Failed to execute operation: No such file or directory
[root@oracle01 ~]# systemctl stop ntpd.service
Failed to stop ntpd.service: Unit ntpd.service not loaded.

systemctl status ntpd

systemctl disable chronyd
systemctl stop chronyd

systemctl status chronyd

ntpdate pool.ntp.org
```
#时区设置
```bash
#查看是否中国时区
date -R 
timedatectl
clockdiff oracle01
clockdiff oracle02

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
[root@oracle01 ~]# grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
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

#memory=128G

```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 28125000
#memory*90%
kernel.shmmax = 115200000000
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

#grid用户，注意oracle01/oracle02两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意oracle02修改
#export ORACLE_SID=+ASM2
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
#oracle用户，注意oracle01/oracle02的区别
```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/db_1
export ORACLE_SID=xydb1
#注意oracle02修改
#export ORACLE_SID=xydb2
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
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
[root@oracle01 network-scripts]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 368ee0625304a85085600b88ed5fa3e0e
/dev/sdb 367850ad2f04bb70a9fc09714a06e7684
/dev/sdc 36c3a0087e0411209e380f43b597b12e9
/dev/sdd 3615b0d62c043850b6190eb2e183a3b61
/dev/sde 36b90096e304857085320c4edc10bee88
/dev/sdf 36cb30cf25045830a1af0687c7a2b6ff6
/dev/sdg 36d420575a040810bbbc0d8c0ddd708b3
[root@oracle01 network-scripts]# lsblk
NAME            MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda               8:0    0   100G  0 disk
sdb               8:16   0   100G  0 disk
sdc               8:32   0   100G  0 disk
sdd               8:48   0     2T  0 disk
sde               8:64   0     2T  0 disk
sdf               8:80   0     2T  0 disk
sdg               8:96   0     2T  0 disk
sr0              11:0    1   4.4G  0 rom
vda             252:0    0   500G  0 disk
├─vda1          252:1    0     1G  0 part /boot
└─vda2          252:2    0   499G  0 part
  ├─centos-root 253:0    0    50G  0 lvm  /
  ├─centos-swap 253:1    0  31.5G  0 lvm  [SWAP]
  └─centos-home 253:2    0 417.5G  0 lvm  /home
[root@oracle01 network-scripts]#

[root@oracle02 network-scripts]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 368ee0625304a85085600b88ed5fa3e0e
/dev/sdb 367850ad2f04bb70a9fc09714a06e7684
/dev/sdc 36c3a0087e0411209e380f43b597b12e9
/dev/sdd 3615b0d62c043850b6190eb2e183a3b61
/dev/sde 36b90096e304857085320c4edc10bee88
/dev/sdf 36cb30cf25045830a1af0687c7a2b6ff6
/dev/sdg 36d420575a040810bbbc0d8c0ddd708b3
[root@oracle02 network-scripts]# lsblk
NAME            MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda               8:0    0   100G  0 disk
sdb               8:16   0   100G  0 disk
sdc               8:32   0   100G  0 disk
sdd               8:48   0     2T  0 disk
sde               8:64   0     2T  0 disk
sdf               8:80   0     2T  0 disk
sdg               8:96   0     2T  0 disk
sr0              11:0    1   4.4G  0 rom
vda             252:0    0   500G  0 disk
├─vda1          252:1    0     1G  0 part /boot
└─vda2          252:2    0   499G  0 part
  ├─centos-root 253:0    0    50G  0 lvm  /
  ├─centos-swap 253:1    0  31.5G  0 lvm  [SWAP]
  └─centos-home 253:2    0 417.5G  0 lvm  /home
[root@oracle02 network-scripts]#
```
#99-oracle-asmdevices.rules
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
#启动udev
```bash
/usr/sbin/partprobe

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service
```
#检查asm磁盘
```bash
ll /dev|grep asm
```
#显示如下
```
[root@oracle01 ~]# ll /dev|grep asm
brw-rw----  1 grid asmadmin   8,   0 Dec 30 17:09 sda
brw-rw----  1 grid asmadmin   8,  16 Dec 30 17:09 sdb
brw-rw----  1 grid asmadmin   8,  32 Dec 30 17:09 sdc
brw-rw----  1 grid asmadmin   8,  48 Dec 30 17:09 sdd
brw-rw----  1 grid asmadmin   8,  64 Dec 30 17:09 sde
brw-rw----  1 grid asmadmin   8,  80 Dec 30 17:09 sdf
brw-rw----  1 grid asmadmin   8,  96 Dec 30 17:09 sdg
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
[root@oracle01 ~]# sfdisk -s
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

[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
24c740a67e89393fa6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2bf57071b2488dae06c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2ee6c414e797cb16f6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2086fa4c938d839c66c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
27b44daa76accbc526c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
24c740a67e89393fa6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2bf57071b2488dae06c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2ee6c414e797cb16f6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
2086fa4c938d839c66c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
27b44daa76accbc526c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
24c740a67e89393fa6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
2bf57071b2488dae06c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2ee6c414e797cb16f6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
2086fa4c938d839c66c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
27b44daa76accbc526c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
24c740a67e89393fa6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2bf57071b2488dae06c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2ee6c414e797cb16f6c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2086fa4c938d839c66c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
27b44daa76accbc526c9ce90079a4df08
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@oracle01 ~]#

#通过循环来获取
for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4

[root@oracle01 ~]# for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4
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

[root@oracle01 ~]# lsscsi -i
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
[root@oracle01 ~]#
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

#以下只在oracle01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
#在oracle02执行
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在oracle01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins

#在oracle02上执行
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
```

## 3 开始安装 grid

### 3.1. 上传集群软件包
```bash
#注意不同的用户
[root@oracle01 storage]# ll -rth
-rwxr-xr-x 1 grid oinstall 2.7G Jan 28 15:58 LINUX.X64_193000_grid_home.zip
-rwxr-xr-x 1 oracle oinstall 2.9G Jan 28 16:38 LINUX.X64_193000_db_home.zip
```
### 3.2. 解压 grid 安装包

```bash
#在 19C 中需要把 grid 包解压放到 grid 用户下 ORACLE_HOME 目录内(/u01/app/19.0.0/grid)
#只在节点一上做解压缩
#如果节点二上也做了解压缩，必须全部删除，ls -a , rm -rfv ./* , rm -rfv ./opatch*, rm -rfv ./patch*
[grid@oracle01 ~]$ cd /u01/app/19.0.0/grid
[grid@oracle01 grid]$ unzip -oq /u01/Storage/LINUX.X64_193000_grid_home.zip

#安装cvuqdisk包
cd /u01/app/19.0.0/grid/cv/rpm
cp cvuqdisk-1.0.10-1.rpm /u01
scp cvuqdisk-1.0.10-1.rpm oracle02:/u01

#两台服务器都安装
su - root
cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm

#节点一安装前检查：
[grid@oracle01 ~]$ cd /u01/app/19.0.0/grid/
[grid@oracle01 grid]$ ./runcluvfy.sh stage -pre crsinst -n oracle01,oracle02 -verbose
```

#error检查
```
#可以忽略的
ERROR:
PRVG-10467 : The default Oracle Inventory group could not be determined.

Verifying Network Time Protocol (NTP) ...FAILED (PRVG-1017)
Verifying resolv.conf Integrity ...FAILED (PRVG-10048)

#centos7可以忽略：
Verifying /dev/shm mounted as temporary file system ...FAILED (PRVE-0421)
Verifying /dev/shm mounted as temporary file system ...FAILED
oracle02: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm

oracle01: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm
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
[grid@oracle01 grid]$ ./gridSetup.sh
```
### 3.4. GI 安装步骤
#安装过程如下
```
1. 为新的集群配置GI(configure oracle grid infrastructure for a New Cluster)
2. 配置独立的集群(configure an oracle standalone cluster)
3. 配置集群名称以及 scan 名称(rac-cluster/rac-scan/1521)
4. 添加节点2并测试节点互信(Add oracle02/oracle02-vip, test for SSH connectivity)
5. 公网、私网网段选择(eth1-3.3.3.0-ASM&private/eth0-10.4.0.0-public)
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
    先在oracle01上执行完毕,再去oracle02执行
    执行完毕后,点击OK
    INS-20802 oracle cluster verification utility failed---OK
    Next
    INS-43080----YES
19. Close     
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

[root@oracle02 grid]# cd lib/
[root@oracle02 lib]# ll|grep ^l
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


[root@oracle02 lib]# ls -l libcln*
lrwxrwxrwx 1 root root       21 Oct 20 16:00 libclntshcore.so -> libclntshcore.so.19.1
-rwxr-xr-x 1 root root  8040416 Apr 18  2019 libclntshcore.so.19.1
lrwxrwxrwx 1 root root       17 Oct 20 16:00 libclntsh.so -> libclntsh.so.19.1
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.10.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.11.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.12.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.18.1 -> libclntsh.so
-rwxr-xr-x 1 root root 79927312 Apr 18  2019 libclntsh.so.19.1

[root@oracle02 lib]# ll|grep libodm
-rw-r--r-- 1 root root     10594 Apr 17  2019 libodm19.a
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libodm19.so -> libodmd19.so
-rw-r--r-- 1 root root     17848 Apr 17  2019 libodmd19.so
[root@oracle02 lib]#

-------------------------------------------
#检查grid账户下正常解压缩文件，发现软连接文件成了正常文件，但是大小还是12
cd /u01/app/19.0.0.0/grid/lib
[grid@oracle02 lib]$ ll|grep ^l
lrwxrwxrwx  1 grid oinstall        15 Oct 20 16:10 libagtsh.so -> libagtsh.so.1.0
lrwxrwxrwx  1 grid oinstall        10 Oct 20 16:10 libocci.so.18.1 -> libocci.so

[grid@oracle02 lib]$ ls -l  libcln*
-rwxr-xr-x. 1 grid oinstall       21 Oct 20 15:16 libclntshcore.so
-rwxr-xr-x. 1 grid oinstall  8040416 Oct 20 15:16 libclntshcore.so.19.1
-rwxr-xr-x. 1 grid oinstall       17 Oct 20 15:16 libclntsh.so
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.10.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.11.1
-rwxr-x---. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.12.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.18.1
-rwxr-xr-x. 1 grid oinstall 79927312 Oct 20 15:16 libclntsh.so.19.1

[grid@oracle02 lib]$ ls -l|grep libjavavm19
-rwxr-xr-x. 1 grid oinstall        36 Oct 20 15:16 libjavavm19.a
[grid@oracle02 lib]$ ls -l|grep libodm
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
[root@oracle01 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@oracle01 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/oracle01/crsconfig/rootcrs_oracle01_2022-08-12_11-09-12PM.log
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

[root@oracle02 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
You have new mail in /var/spool/mail/root
[root@oracle02 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/oracle02/crsconfig/rootcrs_oracle02_2022-03-09_06-18-12PM.log
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
[grid@oracle01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
ora.chad
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
ora.net1.network
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
ora.ons
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              Started,STABLE
      2        ONLINE  ONLINE       oracle02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       oracle01              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       oracle01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01              STABLE
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01              STABLE
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02              STABLE
--------------------------------------------------------------------------------

```
## 5 安装 Oracle 数据库软件
#以 Oracle 用户登录图形化界面，将数据库软件解压至$ORACLE_HOME 
```bash
[oracle@oracle01 db_1]$ pwd
/u01/app/oracle/product/19.0.0/db_1
[oracle@oracle01 db_1]$ unzip -oq /u01/Storage/LINUX.X64_193000_db_home.zip
```
#通过xstart图形化连接服务器，同Grid连接方式

```bash
[oracle@oracle01 db_1]$ ./runInstaller
```
### 5.1. oracle software安装步骤
#安装过程如下
```
1. 仅设置software
2. oracle RAC
3. SSH互信测试
4. Enterprise Edition
5. $ORACLE_BASE(/u01/app/oracle)
6. 用户组，保持默认
7. 不执行配置脚本，保持默认
8. 忽略全部--->Yes
9. Install
10. root账户先在oracle01执行完毕后再在oracle02上执行脚本(/u01/app/oracle/product/19.0.0/db_1/root.sh)，然后点击OK
11. Close
```
#执行root.sh脚本记录
```
[root@oracle01 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
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

[root@oracle02 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
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
5. xydb/xydb/Create as Container database/Use Local Undo tbs for PDBs/pdb:1/pdbname:stuwork
6. AMS:+DATA/{DB_UNIQUE_NAME}/Use OMF
7. ASM/+FRA/+FRA free space(点击Browse查看：2097012)/Enable archiving
8. 数据库组件，保持默认不选
9. ASMM自动共享内存管理
       #sga=memory*65%*75%=512G*65%*75%=249.6G(向下十位取整为240G)
       #pga=memory*65%*25%=512G*65%*25%=83.2G(向下十位取整为80G)
       sga=66G
       pag=22G
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
[grid@oracle01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
ora.chad
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
ora.net1.network
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
ora.ons
               ONLINE  ONLINE       oracle01              STABLE
               ONLINE  ONLINE       oracle02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              Started,STABLE
      2        ONLINE  ONLINE       oracle02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       oracle01              STABLE
      2        ONLINE  ONLINE       oracle02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       oracle01              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       oracle01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01              STABLE
ora.xydb.db
      1        ONLINE  ONLINE       oracle01              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       oracle02              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01              STABLE
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02              STABLE
--------------------------------------------------------------------------------


[grid@oracle01 ~]$ srvctl config database -d xydb
Database unique name: xydb
Database name: xydb
Oracle home: /u01/app/oracle/product/19.0.0/db_1
Oracle user: oracle
Spfile: +DATA/XYDB/PARAMETERFILE/spfile.272.1098977945
Password file: +DATA/XYDB/PASSWORD/pwdxydb.256.1098977053
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
Configured nodes: oracle01,oracle02
CSS critical: no
CPU count: 0
Memory target: 0
Maximum memory: 0
Default network number for database services:
Database is administrator managed

```
### 6.3. 查看数据库版本
```
[oracle@oracle01 db_1]$ sqlplus / as sysdba
SQL> col banner_full for a120
SQL> select BANNER_FULL from v$version;

BANNER_FULL
--------------------------------------------------------------------------------
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select INST_NUMBER,INST_NAME FROM v$active_instances;

INST_NUMBER INST_NAME
----------- ----------------------------------------------
	  1 oracle01:xydb1
	  2 oracle02:xydb2

SQL> SELECT instance_name, host_name FROM gv$instance;

INSTANCE_NAME	 HOST_NAME
---------------- --------------------------------
xydb1		 oracle01
xydb2		 oracle02

SQL> 

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
------------------------------------------- ------------------------------
+DATA/XYDB/TEMPFILE/temp.264.1098977211 					 TEMP

SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------- ------------------------------
+DATA/XYDB/DATAFILE/system.257.1098977073					 SYSTEM
+DATA/XYDB/DATAFILE/sysaux.258.1098977107					 SYSAUX
+DATA/XYDB/DATAFILE/undotbs1.259.1098977123					 UNDOTBS1
+DATA/XYDB/DATAFILE/users.260.1098977123					 USERS
+DATA/XYDB/DATAFILE/undotbs2.269.1098977625					 UNDOTBS2

SQL> 

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 DATAASSETS			  READ WRITE NO
SQL> alter session set container=dataassets;

Session altered.

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------- ------------------------------
+DATA/XYDB/D9D95AD26C416301E0536ACBA8C0985D/TEMPFILE/temp.276.1098978145	 TEMP

SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME									 TABLESPACE_NAME
-------------------------------------------  ------------------------------
+DATA/XYDB/D9D95AD26C416301E0536ACBA8C0985D/DATAFILE/system.274.1098978145	 SYSTEM
+DATA/XYDB/D9D95AD26C416301E0536ACBA8C0985D/DATAFILE/sysaux.275.1098978145	 SYSAUX
+DATA/XYDB/D9D95AD26C416301E0536ACBA8C0985D/DATAFILE/undotbs1.273.1098978145	 UNDOTBS1
+DATA/XYDB/D9D95AD26C416301E0536ACBA8C0985D/DATAFILE/undo_2.277.1098978155	 UNDO_2
+DATA/XYDB/D9D95AD26C416301E0536ACBA8C0985D/DATAFILE/users.278.1098978155	 USERS

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

srvctl add service -d xydb -s s_dataassets -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets

srvctl start service -d xydb -s s_dataassets

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
#sqlplus pdbadmin/pdbadmin@10.4.0.45:1521/s_dataassets
[oracle@oracle02 ~]$ sqlplus pdbadmin/pdbadmin@10.4.0.45:1521/s_dataassets

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
expdp test1/test1@10.4.0.45:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n
#导出全库
expdp pdbadmin/pdbadmin@10.4.0.45:1521/s_dataassets full=y directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp
impdp est1/test1@10.4.0.45:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp--remap
impdp  est1/test1@10.4.0.45:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n   remap_schema=test2:test1 remap_tablespace=test2:test1  logfile=test01.log cluster=n

#expdp-12.2.0.1.0
expdp test1/test1@10.4.0.45:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n compression=data_only version=12.2.0.1.0

#脚本

#!/bin/bash
source /etc/profile
source /home/oracle/.bash_profile

now=`date +%y%m%d`
dmpfile=dataassets_db$now.dmp
logfile=dataassets_db$now.log

echo start exp $dmpfile ...


expdp pdbadmin/pdbadmin@10.4.0.45:1521/s_dataassets full=y directory=expdir dumpfile=$dmpfile logfile=$logfile cluster=n 



echo delete local file ...
find /home/oracle/expdir -name "*.dmp" -mtime +5 -exec rm {} \;
find /home/oracle/expdir -name "*.log" -mtime +5 -exec rm {} \;

echo finish bak job

```
### 6.5. Oracle RAC其他操作
#创建pdb
```oracle
create pluggable database pdb1 admin user pdb1user identified by pdb1user roles=(dba);

alter pluggable database pdb1 open;
alter session set container=pdb1;

create tablespace pdb1user datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

alter tablespace pdb1user add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create user user1 identified by user1 default tablespace pdb1user account unlock;

grant dba to user1;
grant select any table to user1;
```
#连接方式
```bash
srvctl add service -d xydb -s s_pdb1 -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb pdb1

srvctl start service -d xydb -s s_pdb1
srvctl status service -d xydb -s s_pdb1

sqlplus user1/user1@10.4.0.45:1521/s_pdb1
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
