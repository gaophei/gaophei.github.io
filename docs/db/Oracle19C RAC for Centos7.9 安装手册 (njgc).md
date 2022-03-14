**19C RAC for Centos7.9 安装手册**

## 目录
1 环境..............................................................................................................................................2
1.1. 系统版本： ..............................................................................................................................2
1.2. ASM 磁盘组规划 ....................................................................................................................2
1.3. 主机网络规划..........................................................................................................................2
1.4. 操作系统配置部分.................................................................................................................2
2 准备工作（zhongtaidb1 与 zhongtaidb2 同时配置） ............................................................................................3
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
[root@zhongtaidb1 Packages]# cat /etc/redhat-release
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
主机名称               zhongtaidb1                        zhongtaidb2
public ip            192.168.203.106                    192.168.203.107
private ip           10.10.10.11                      10.10.10.12
vip                  192.168.203.108                    192.168.203.109
scan ip              192.168.203.111 
```
#网卡配置及多路径配置
```bash
ifconfig
nmcli conn show

#eno8为私有网卡
#ens3f0和ens3f1d1绑定为team0为业务网卡
```

#节点一zhongtaidb1
```bash
nmcli con mod eno8 ipv4.addresses 10.10.10.11/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '192.168.203.106/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#节点二zhongtaidb2
```bash
nmcli con mod eno8 ipv4.addresses 10.10.10.12/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '192.168.203.106/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#修改私有网卡的相关配置
#zhongtaidb1
```
[root@zhongtaidb1 ~]# nmcli dev
DEVICE    TYPE      STATE        CONNECTION
team0     team      connected    team0
eno8      ethernet  connected    eno8
ens3f0    ethernet  connected    team0-ens3f0
ens3f1d1  ethernet  connected    team0-ens3f1d1
eno5      ethernet  unavailable  --
eno6      ethernet  unavailable  --
eno7      ethernet  unavailable  --
lo        loopback  unmanaged    --
[root@zhongtaidb1 ~]#

[root@zhongtaidb1 ~]# nmcli conn show
NAME            UUID                                  TYPE      DEVICE
team0           2720d30c-88dd-41df-aee0-57c7b2341387  team      team0
eno8            46fbcecc-e3d9-4e9e-99d9-984746affe06  ethernet  eno8
team0-ens3f0    8c55f51d-ed1b-4938-8da2-210f570c27a0  ethernet  ens3f0
team0-ens3f1d1  518a337e-8567-4644-b143-eef226ce60fe  ethernet  ens3f1d1
eno5            de9c06af-1c86-4f50-86ee-3bdc6d9b4b6e  ethernet  --
eno6            32839215-743d-4a52-8ccc-81b332d1107e  ethernet  --
eno7            ad7312f3-2809-4675-9d0a-e88d23796dd9  ethernet  --
ens3f0          2c40ee1c-f649-4648-af65-cabe2543db98  ethernet  --
ens3f1d1        09833b6a-29bb-4e6a-99b5-6b9a75ebfb47  ethernet  --
[root@zhongtaidb1 ~]# ifconfig
eno5: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether d4:f5:ef:60:3f:f0  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6f00000-e6ffffff

eno6: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether d4:f5:ef:60:3f:f1  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6e00000-e6efffff

eno7: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether d4:f5:ef:60:3f:f2  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6d00000-e6dfffff

eno8: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.10.10.11  netmask 255.255.255.0  broadcast 10.10.10.255
        inet6 fe80::d7df:a509:d372:4544  prefixlen 64  scopeid 0x20<link>
        ether d4:f5:ef:60:3f:f3  txqueuelen 1000  (Ethernet)
        RX packets 1309  bytes 103335 (100.9 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 1354  bytes 147658 (144.1 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6c00000-e6cfffff

ens3f0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether f4:03:43:f1:01:20  txqueuelen 1000  (Ethernet)
        RX packets 7881303  bytes 5218373455 (4.8 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4175830  bytes 4999490153 (4.6 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens3f1d1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether f4:03:43:f1:01:20  txqueuelen 1000  (Ethernet)
        RX packets 4271950  bytes 256318216 (244.4 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 807  bytes 70113 (68.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 807  bytes 70113 (68.4 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

team0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.203.106  netmask 255.255.255.0  broadcast 192.168.203.255
        inet6 fe80::7a3c:dbb6:cda0:17e1  prefixlen 64  scopeid 0x20<link>
        ether f4:03:43:f1:01:20  txqueuelen 1000  (Ethernet)
        RX packets 5597102  bytes 4989256929 (4.6 GiB)
        RX errors 0  dropped 333  overruns 0  frame 0
        TX packets 1015371  bytes 4790889811 (4.4 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        
[root@zhongtaidb1 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens3f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master team0 state UP group default qlen 1000
    link/ether f4:03:43:f1:01:20 brd ff:ff:ff:ff:ff:ff
3: ens3f1d1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master team0 state UP group default qlen 1000
    link/ether f4:03:43:f1:01:20 brd ff:ff:ff:ff:ff:ff
4: eno5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether d4:f5:ef:60:3f:f0 brd ff:ff:ff:ff:ff:ff
5: eno6: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether d4:f5:ef:60:3f:f1 brd ff:ff:ff:ff:ff:ff
6: eno7: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether d4:f5:ef:60:3f:f2 brd ff:ff:ff:ff:ff:ff
7: eno8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether d4:f5:ef:60:3f:f3 brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.11/24 brd 10.10.10.255 scope global noprefixroute eno8
       valid_lft forever preferred_lft forever
    inet6 fe80::d7df:a509:d372:4544/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
8: team0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether f4:03:43:f1:01:20 brd ff:ff:ff:ff:ff:ff
    inet 192.168.203.106/24 brd 192.168.203.255 scope global noprefixroute team0
       valid_lft forever preferred_lft forever
    inet6 fe80::7a3c:dbb6:cda0:17e1/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
[root@zhongtaidb1 ~]# ip route
default via 192.168.203.1 dev team0 proto static metric 350
10.10.10.0/24 dev eno8 proto kernel scope link src 10.10.10.11 metric 102
192.168.203.0/24 dev team0 proto kernel scope link src 192.168.203.106 metric 350
[root@zhongtaidb1 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.203.1   0.0.0.0         UG    350    0        0 team0
10.10.10.0      0.0.0.0         255.255.255.0   U     102    0        0 eno8
192.168.203.0   0.0.0.0         255.255.255.0   U     350    0        0 team0

[root@zhongtaidb1 ~]# cd /etc/sysconfig/network-scripts/
[root@zhongtaidb1 network-scripts]# ls
ifcfg-eno5            ifdown-bnep      ifdown-tunnel  ifup-ppp
ifcfg-eno6            ifdown-eth       ifup           ifup-routes
ifcfg-eno7            ifdown-ippp      ifup-aliases   ifup-sit
ifcfg-eno8            ifdown-ipv6      ifup-bnep      ifup-Team
ifcfg-ens3f0          ifdown-isdn      ifup-eth       ifup-TeamPort
ifcfg-ens3f1d1        ifdown-post      ifup-ippp      ifup-tunnel
ifcfg-lo              ifdown-ppp       ifup-ipv6      ifup-wireless
ifcfg-team0           ifdown-routes    ifup-isdn      init.ipv6-global
ifcfg-team0-ens3f0    ifdown-sit       ifup-plip      network-functions
ifcfg-team0-ens3f1d1  ifdown-Team      ifup-plusb     network-functions-ipv6
ifdown                ifdown-TeamPort  ifup-post
[root@zhongtaidb1 network-scripts]# cat ifcfg-team0
TEAM_CONFIG="{\"runner\":{\"name\":\"activebackup\"}}"
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
IPADDR=192.168.203.106
PREFIX=24
GATEWAY=192.168.203.1
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=team0
UUID=2720d30c-88dd-41df-aee0-57c7b2341387
DEVICE=team0
ONBOOT=yes
DEVICETYPE=Team
MACADDR=f4:03:43:f1:01:20
[root@zhongtaidb1 network-scripts]# cat ifcfg-team0-ens3f0
NAME=team0-ens3f0
UUID=8c55f51d-ed1b-4938-8da2-210f570c27a0
DEVICE=ens3f0
ONBOOT=yes
TEAM_MASTER=team0
DEVICETYPE=TeamPort
[root@zhongtaidb1 network-scripts]# cat ifcfg-team0-ens3f1d1
NAME=team0-ens3f1d1
UUID=518a337e-8567-4644-b143-eef226ce60fe
DEVICE=ens3f1d1
ONBOOT=yes
TEAM_MASTER=team0
DEVICETYPE=TeamPort
[root@zhongtaidb1 network-scripts]# cat ifcfg-eno8
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno8
UUID=46fbcecc-e3d9-4e9e-99d9-984746affe06
DEVICE=eno8
ONBOOT=yes
IPADDR=10.10.10.11
PREFIX=24

[root@zhongtaidb1 ~]# teamdctl team0 st
setup:
  runner: activebackup
ports:
  ens3f0
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
  ens3f1d1
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
runner:
  active port: ens3f0
```
#zhongtaidb2
```
[root@zhongtaidb2 ~]# nmcli dev
DEVICE    TYPE      STATE        CONNECTION
team0     team      connected    team0
eno8      ethernet  connected    eno8
ens3f0    ethernet  connected    team0-ens3f0
ens3f1d1  ethernet  connected    team0-ens3f1d1
eno5      ethernet  unavailable  --
eno6      ethernet  unavailable  --
eno7      ethernet  unavailable  --
lo        loopback  unmanaged    --

[root@zhongtaidb2 ~]# nmcli conn show
NAME            UUID                                  TYPE      DEVICE
team0           6df09d29-7cd6-4681-a678-6ab9aaa026a6  team      team0
eno8            4d0be2df-c5da-41c9-bfd5-8f8cc6ad6e74  ethernet  eno8
team0-ens3f0    2c54fa8b-e63a-46c5-9fd3-9047784bb9cc  ethernet  ens3f0
team0-ens3f1d1  97341b21-6def-4288-b380-ac3a3b964076  ethernet  ens3f1d1
eno5            6f1356e3-4cf8-4d04-8569-8f27a61a0f46  ethernet  --
eno6            54b39264-6645-4337-9c45-d81bf4a9e8d4  ethernet  --
eno7            f5d5497c-3d67-4eb8-a1a2-12d9adcaca74  ethernet  --
ens3f0          0be449f6-5011-4770-a5ac-a6bad4498449  ethernet  --
ens3f1d1        2d0b2436-9148-4eb4-ac4b-ba00c1494c58  ethernet  --
[root@zhongtaidb2 ~]# ifconfig
eno5: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether d4:f5:ef:38:96:1c  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6f00000-e6ffffff

eno6: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether d4:f5:ef:38:96:1d  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6e00000-e6efffff

eno7: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether d4:f5:ef:38:96:1e  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6d00000-e6dfffff

eno8: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.10.10.12  netmask 255.255.255.0  broadcast 10.10.10.255
        inet6 fe80::1504:5d2:edc0:c974  prefixlen 64  scopeid 0x20<link>
        ether d4:f5:ef:38:96:1f  txqueuelen 1000  (Ethernet)
        RX packets 124  bytes 10842 (10.5 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 115  bytes 19599 (19.1 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device memory 0xe6c00000-e6cfffff

ens3f0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether f4:03:43:f0:db:60  txqueuelen 1000  (Ethernet)
        RX packets 7620522  bytes 5195158075 (4.8 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 224820  bytes 16536892 (15.7 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens3f1d1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether f4:03:43:f0:db:60  txqueuelen 1000  (Ethernet)
        RX packets 4271914  bytes 256315926 (244.4 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 753  bytes 65613 (64.0 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 753  bytes 65613 (64.0 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

team0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.203.107  netmask 255.255.255.0  broadcast 192.168.203.255
        inet6 fe80::9089:3568:982e:f299  prefixlen 64  scopeid 0x20<link>
        ether f4:03:43:f0:db:60  txqueuelen 1000  (Ethernet)
        RX packets 4609193  bytes 4931881827 (4.5 GiB)
        RX errors 0  dropped 333  overruns 0  frame 0
        TX packets 224792  bytes 16525002 (15.7 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@zhongtaidb2 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens3f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master team0 state UP group default qlen 1000
    link/ether f4:03:43:f0:db:60 brd ff:ff:ff:ff:ff:ff
3: ens3f1d1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master team0 state UP group default qlen 1000
    link/ether f4:03:43:f0:db:60 brd ff:ff:ff:ff:ff:ff
4: eno5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether d4:f5:ef:38:96:1c brd ff:ff:ff:ff:ff:ff
5: eno6: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether d4:f5:ef:38:96:1d brd ff:ff:ff:ff:ff:ff
6: eno7: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether d4:f5:ef:38:96:1e brd ff:ff:ff:ff:ff:ff
7: eno8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether d4:f5:ef:38:96:1f brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.12/24 brd 10.10.10.255 scope global noprefixroute eno8
       valid_lft forever preferred_lft forever
    inet6 fe80::1504:5d2:edc0:c974/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
8: team0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether f4:03:43:f0:db:60 brd ff:ff:ff:ff:ff:ff
    inet 192.168.203.107/24 brd 192.168.203.255 scope global noprefixroute team0
       valid_lft forever preferred_lft forever
    inet6 fe80::9089:3568:982e:f299/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
[root@zhongtaidb2 ~]# ip route
default via 192.168.203.1 dev team0 proto static metric 350
10.10.10.0/24 dev eno8 proto kernel scope link src 10.10.10.12 metric 102
192.168.203.0/24 dev team0 proto kernel scope link src 192.168.203.107 metric 350
[root@zhongtaidb2 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.203.1   0.0.0.0         UG    350    0        0 team0
10.10.10.0      0.0.0.0         255.255.255.0   U     102    0        0 eno8
192.168.203.0   0.0.0.0         255.255.255.0   U     350    0        0 team0

[root@zhongtaidb2 ~]# cd /etc/sysconfig/network-scripts/
[root@zhongtaidb2 network-scripts]# ls
ifcfg-eno5            ifdown-bnep      ifdown-tunnel  ifup-ppp
ifcfg-eno6            ifdown-eth       ifup           ifup-routes
ifcfg-eno7            ifdown-ippp      ifup-aliases   ifup-sit
ifcfg-eno8            ifdown-ipv6      ifup-bnep      ifup-Team
ifcfg-ens3f0          ifdown-isdn      ifup-eth       ifup-TeamPort
ifcfg-ens3f1d1        ifdown-post      ifup-ippp      ifup-tunnel
ifcfg-lo              ifdown-ppp       ifup-ipv6      ifup-wireless
ifcfg-team0           ifdown-routes    ifup-isdn      init.ipv6-global
ifcfg-team0-ens3f0    ifdown-sit       ifup-plip      network-functions
ifcfg-team0-ens3f1d1  ifdown-Team      ifup-plusb     network-functions-ipv6
ifdown                ifdown-TeamPort  ifup-post
[root@zhongtaidb2 network-scripts]# cat ifcfg-team0
TEAM_CONFIG="{\"runner\":{\"name\":\"activebackup\"}}"
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
IPADDR=192.168.203.107
PREFIX=24
GATEWAY=192.168.203.1
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=team0
UUID=6df09d29-7cd6-4681-a678-6ab9aaa026a6
DEVICE=team0
ONBOOT=yes
DEVICETYPE=Team
MACADDR=f4:03:43:f0:db:60
[root@zhongtaidb2 network-scripts]# cat ifcfg-team0-ens3f0
NAME=team0-ens3f0
UUID=2c54fa8b-e63a-46c5-9fd3-9047784bb9cc
DEVICE=ens3f0
ONBOOT=yes
TEAM_MASTER=team0
DEVICETYPE=TeamPort
[root@zhongtaidb2 network-scripts]# cat ifcfg-team0-ens3f1d1
NAME=team0-ens3f1d1
UUID=97341b21-6def-4288-b380-ac3a3b964076
DEVICE=ens3f1d1
ONBOOT=yes
TEAM_MASTER=team0
DEVICETYPE=TeamPort
[root@zhongtaidb2 network-scripts]# cat ifcfg-eno8
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno8
UUID=4d0be2df-c5da-41c9-bfd5-8f8cc6ad6e74
DEVICE=eno8
ONBOOT=yes
IPADDR=10.10.10.12
PREFIX=24

[root@zhongtaidb2 ~]# teamdctl team0 state
setup:
  runner: activebackup
ports:
  ens3f0
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
  ens3f1d1
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
runner:
  active port: ens3f0
```
### 1.4. 操作系统配置部分

#关闭防火墙
```bash
systemctl stop firewalld
systemctl disabled firewalld

systemctl status firewalld
```
#关闭 selinux
```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0
```
### 1.5.多路径配置情况
```  
[root@zhongtaidb2 ~]# cat /etc/multipath/
bindings  wwids     
[root@zhongtaidb2 ~]# cat /etc/multipath/bindings 
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
[root@zhongtaidb2 ~]# cat /etc/multipath/wwids 
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

[root@zhongtaidb2 ~]# sfdisk -s|grep mpath
/dev/mapper/mpatha: 104857600
/dev/mapper/mpathb: 104857600
/dev/mapper/mpathc: 104857600
/dev/mapper/mpathd: 2147483648
/dev/mapper/mpathe: 2147483648
/dev/mapper/mpathf: 2147483648
/dev/mapper/mpathg: 2147483648

[root@zhongtaidb1 ~]# multipathd show maps
name   sysfs uuid
mpatha dm-2  24c740a67e89393fa6c9ce90079a4df08
mpathb dm-3  2bf57071b2488dae06c9ce90079a4df08
mpathc dm-4  2ee6c414e797cb16f6c9ce90079a4df08
mpathd dm-5  2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe dm-6  2086fa4c938d839c66c9ce90079a4df08
mpathf dm-7  27b44daa76accbc526c9ce90079a4df08
mpathg dm-8  2aa67dbb0c9c0573b6c9ce90079a4df08
```

## 2.准备工作（zhongtaidb1 与 zhongtaidb2 同时配置）

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
```
### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#zhongtaidb1
hostnamectl set-hostname zhongtaidb1
#zhongtaidb2
hostnamectl set-hostname zhongtaidb2

cat >> /etc/hosts <<EOF
#public ip team0
192.168.203.106 zhongtaidb1
192.168.203.107 zhongtaidb2
#vip
192.168.203.108 zhongtaidb1-vip
192.168.203.109 zhongtaidb2-vip
#private ip eno8
10.10.10.11 zhongtaidb1-prv
10.10.10.12 zhongtaidb2-prv
#scan ip
192.168.203.111 rac-scan
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

ntpdate pool.ntp.org
```
#时区设置
```bash
#查看是否中国时区
date -R 
timedatectl
clockdiff zhongtaidb1
clockdiff zhongtaidb2

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
[root@zhongtaidb1 ~]# grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
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
```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 107 374182
#memory*80%(512*1024*1024*1024*80%)
kernel.shmmax = 439804651111
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

#grid用户，注意zhongtaidb1/zhongtaidb2两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意zhongtaidb2修改
#export ORACLE_SID=+ASM2
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
#oracle用户，注意zhongtaidb1/zhongtaidb2的区别
```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/db_1
export ORACLE_SID=xydb1
#注意zhongtaidb2修改
#export ORACLE_SID=xydb2
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
### 2.9. 配置共享磁盘权限

#### 2.9.1.无多路径模式---本次为多路径模式

#适用于vsphere平台直接共享存储磁盘

#检查磁盘UUID
```bash
sfdisk -s
/usr/lib/udev/scsi_id -g -u -d devicename
```
#显示如下
```
[root@zhongtaidb1 ~]# sfdisk -s
/dev/sdc:  20971520
/dev/sde: 524288000
/dev/sda: 524288000
/dev/sdf: 314572800
/dev/sdb:  20971520
/dev/sdd:  20971520
/dev/mapper/centos-root: 456126464
/dev/mapper/centos-swap:  67108864
total: 1949298688 blocks

[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
36000c29cab9f05183d3af0fc44e8022f
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
36000c29aa1f89b4a2054f787a381ec5f
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
36000c293eb6bd488a57530ba68d59381
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
36000c29e32ff47627698b21515cc5682
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
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
[root@zhongtaidb1 ~]# ll /dev|grep asm
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
[root@zhongtaidb1 ~]# sfdisk -s
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

[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
24c740a67e89393fa6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2bf57071b2488dae06c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2ee6c414e797cb16f6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2086fa4c938d839c66c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
27b44daa76accbc526c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
24c740a67e89393fa6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2bf57071b2488dae06c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2ee6c414e797cb16f6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
2086fa4c938d839c66c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
27b44daa76accbc526c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
24c740a67e89393fa6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
2bf57071b2488dae06c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2ee6c414e797cb16f6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
2086fa4c938d839c66c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
27b44daa76accbc526c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
24c740a67e89393fa6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2bf57071b2488dae06c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2ee6c414e797cb16f6c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2086fa4c938d839c66c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
27b44daa76accbc526c9ce90079a4df08
[root@zhongtaidb1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@zhongtaidb1 ~]#

#通过循环来获取
for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4

[root@zhongtaidb1 ~]# for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4
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

[root@zhongtaidb1 ~]# lsscsi -i
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
[root@zhongtaidb1 ~]#
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

#以下只在zhongtaidb1执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh zhongtaidb2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh zhongtaidb2 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys zhongtaidb2:~/.ssh/authorized_keys

ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date -Ins;ssh zhongtaidb2 date -Ins;ssh zhongtaidb1-prv date -Ins;ssh zhongtaidb2-prv date -Ins

#在zhongtaidb2执行
ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date -Ins;ssh zhongtaidb2 date -Ins;ssh zhongtaidb1-prv date -Ins;ssh zhongtaidb2-prv date -Ins
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在zhongtaidb1执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh zhongtaidb2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh zhongtaidb2 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys zhongtaidb2:~/.ssh/authorized_keys

ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date -Ins;ssh zhongtaidb2 date -Ins;ssh zhongtaidb1-prv date -Ins;ssh zhongtaidb2-prv date -Ins

#在zhongtaidb2上执行
ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date;ssh zhongtaidb2 date;ssh zhongtaidb1-prv date;ssh zhongtaidb2-prv date

ssh zhongtaidb1 date -Ins;ssh zhongtaidb2 date -Ins;ssh zhongtaidb1-prv date -Ins;ssh zhongtaidb2-prv date -Ins
```
### 2.11. 在 grid 安装文件中安装 cvuqdisk

```bash
[root@zhongtaidb1 rpm]# pwd
/u01/app/19.0.0/grid/cv/rpm
[root@zhongtaidb1 rpm]# ls
cvuqdisk-1.0.10-1.rpm
[root@zhongtaidb1 rpm]# rpm -ivh cvuqdisk-1.0.10-1.rpm
```
## 3 开始安装 grid

### 3.1. 上传集群软件包
```bash
[root@zhongtaidb1 storage]# ll
-rwxr-xr-x 1 grid oinstall 5.1G Jan 28 15:58 LINUX.X64_193000_grid_home.zip
```
### 3.2. 解压 grid 安装包

```bash
#在 19C 中需要把 grid 包解压放到 grid 用户下 ORACLE_HOME 目录内(/u01/app/19.0.0/grid)
[grid@zhongtaidb2 ~]$ cd /u01/app/19.0.0/grid
[grid@zhongtaidb2 grid]$ unzip -oq /u01/storage/LINUX.X64_193000_grid_home.zip

#安装cvuqdisk包
cd /u01/app/19.0.0/grid/cv/rpm
cp cvuqdisk-1.0.10-1.rpm /u01
scp cvuqdisk-1.0.10-1.rpm zhongtaidb2:/u01

#两台服务器都安装
su - root
cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm

#节点一安装前检查：
[grid@zhongtaidb1 ~]$ cd /u01/app/19.0.0/grid/
[grid@zhongtaidb1 grid]$ ./runcluvfy.sh stage -pre crsinst -n zhongtaidb1,zhongtaidb2 -verbose
```

#安装xterm
```bash
yum install -y xterm*
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
[grid@zhongtaidb1 grid]$ ./gridSetup.sh
```
### 3.4. GI 安装步骤
#安装过程如下
```
1. 为新的集群配置GI
2. 配置集群名称以及 scan 名称(rac-cluster/rac-scan/1521)
3. 节点互信
4. 公网、私网网段选择(eno8-10.10.10.0-ASM&private/team0-192.168.203.0-public)
5. 选择 asm 存储
6. 选择不单独为GIMR配置磁盘组
7. 选择 asm 磁盘组(ORC/normal/100G三块磁盘)
9. 输入密码
10. 保持默认
11. 保持默认
12. 确认 base 目录
13. 这里可以选择自动 root 执行脚本
14. 预安装检查
15. 解决相关依赖后，忽略如下报错
16. 如下警告可以忽略-警告是由于没有使用 DNS 解析造成可忽略
17. 执行 root 脚本
```
#日志如下
```
[root@zhongtaidb1 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@zhongtaidb1 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/zhongtaidb1/crsconfig/rootcrs_zhongtaidb1_2022-03-09_06-11-06PM.log
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

[root@zhongtaidb2 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
You have new mail in /var/spool/mail/root
[root@zhongtaidb2 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/zhongtaidb2/crsconfig/rootcrs_zhongtaidb2_2022-03-09_06-18-12PM.log
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
2. DATA/External/(/dev/dm-5、/dev/dm-6、/dev/dm-7)，点击OK
3. 继续点击Create
4. FRA/External/(/dev/dm-8)，点击OK
5. Exit
```
### 4.2 查看状态
```
[grid@zhongtaidb1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.chad
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.net1.network
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.ons
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              Started,STABLE
      2        ONLINE  ONLINE       zhongtaidb2              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.zhongtaidb1.vip
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.zhongtaidb2.vip
      1        ONLINE  ONLINE       zhongtaidb2              STABLE
--------------------------------------------------------------------------------

```
## 5 安装 Oracle 数据库软件
#以 Oracle 用户登录图形化界面，将数据库软件解压至$ORACLE_HOME 
```bash
[oracle@zhongtaidb1 db_1]$ pwd
/u01/app/oracle/product/19.0.0/db_1
[oracle@zhongtaidb1 db_1]$ unzip -oq /u01/storage/LINUX.X64_193000_db_home.zip
```
#通过xstart图形化连接服务器，通Grid连接方式
```bash
[oracle@zhongtaidb1 db_1]$ ./runInstaller
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
10. root账户先在zhongtaidb1执行完毕后再在zhongtaidb2上执行脚本(/u01/app/oracle/product/19.0.0/db_1/root.sh)，然后点击OK
11. Close
```
#执行root.sh脚本记录
```
[root@zhongtaidb1 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
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

[root@zhongtaidb2 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
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
5. xydb/xydb/Create as Container database/Use Local Undo tbs for PDBs/pdb:1/pdbname:dataassets
6. AMS:+DATA/{DB_UNIQUE_NAME}/Use OMF
7. ASM/+FRA/+FRA free space(点击Browse查看：2097012)/Enable archiving
8. 数据库组件，保持默认不选
9. ASMM自动共享内存管理
       sga=memory*65%*75%=512G*65%*75%=249.6G(向下十位取整为240G)
       pga=memory*65%*25%=512G*65%*25%=83.2G(向下十位取整为80G)
10. Sizing: block size: 8192/processes: 3840
11. Character Sets: AL32UTF8
12. Connection mode: Dadicated server mode--->Next
13. 运行CVU和开启EM
14. 使用相同密码
15. 勾选：create database
16. Ignore all--->Yes
17. Finish
18. Close

```
### 6.2. 查看集群状态
```
[grid@zhongtaidb1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.chad
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.net1.network
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.ons
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              Started,STABLE
      2        ONLINE  ONLINE       zhongtaidb2              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.xydb.db
      1        ONLINE  ONLINE       zhongtaidb1              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       zhongtaidb2              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.zhongtaidb1.vip
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.zhongtaidb2.vip
      1        ONLINE  ONLINE       zhongtaidb2              STABLE
--------------------------------------------------------------------------------


[grid@zhongtaidb1 ~]$ srvctl config database -d xydb
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
Configured nodes: zhongtaidb1,zhongtaidb2
CSS critical: no
CPU count: 0
Memory target: 0
Maximum memory: 0
Default network number for database services:
Database is administrator managed

```
### 6.3. 查看数据库版本
```
[oracle@zhongtaidb1 db_1]$ sqlplus / as sysdba
SQL> col banner_full for a120
SQL> select BANNER_FULL from v$version;

BANNER_FULL
--------------------------------------------------------------------------------
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select INST_NUMBER,INST_NAME FROM v$active_instances;

INST_NUMBER INST_NAME
----------- ----------------------------------------------
	  1 zhongtaidb1:xydb1
	  2 zhongtaidb2:xydb2

SQL> SELECT instance_name, host_name FROM gv$instance;

INSTANCE_NAME	 HOST_NAME
---------------- --------------------------------
xydb1		 zhongtaidb1
xydb2		 zhongtaidb2

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
#sqlplus pdbadmin/pdbadmin@192.168.203.111:1521/s_dataassets
[oracle@zhongtaidb2 ~]$ sqlplus pdbadmin/pdbadmin@192.168.203.111:1521/s_dataassets

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
expdp test1/test1@192.168.203.111:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n
#导出全库
expdp pdbadmin/pdbadmin@192.168.203.111:1521/s_dataassets full=y directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp
impdp est1/test1@192.168.203.111:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp--remap
impdp  est1/test1@192.168.203.111:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n   remap_schema=test2:test1 remap_tablespace=test2:test1  logfile=test01.log cluster=n

#expdp-12.2.0.1.0
expdp test1/test1@192.168.203.111:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n compression=data_only version=12.2.0.1.0
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

sqlplus user1/user1@192.168.203.111:1521/s_pdb1
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
