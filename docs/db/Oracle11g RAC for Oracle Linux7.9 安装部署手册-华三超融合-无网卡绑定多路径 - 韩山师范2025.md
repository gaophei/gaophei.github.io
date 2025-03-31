**rac11g RAC for Centos7.9 安装手册**

## 目录
#内容目录
```
1.系统环境
1.1. 系统版本
1.2. ASM 磁盘组规划
1.3. 主机网络规划
1.3.1.IP规划
1.3.2.网卡配置
1.3.2.1.网卡eno1/eno2做网卡绑定(IP10.119.5.65)，连接存储
1.3.2.2.网卡eno3走业务网
1.3.2.3.网卡eno4两台服务器直连，做私有网络
1.3.2.4.最后网络配置信息
1.3.2.5.网卡绑定方法二
1.3.2.6.华为存储光纤跳线直连配置
1.4. 操作系统配置部分
2.准备工作（rac1 与 rac2 同时配置）
2.1. 配置本地 yum 源--可选
2.2. 安装 rpm 依赖包
2.3. 创建用户
2.4. 配置 host 表
2.5. 禁用 NTP
2.6. 创建所需要目录
2.7. 其它优化配置：
2.8. 配置环境变量
2.9. 配置共享磁盘权限
2.9.1.无多路径模式
2.9.2.多路径模式
2.10. 配置互信
2.11. 安装vnc
2.11.1.安装图形化组件并重启
2.11.2.安装vnc
3 开始安装 GI
3.1. 上传oracle rac软件安装包并解压缩
3.2. 安装 cvuqdisk并做安装前检查
3.3. 开始安装GI
3.4.错误处理
3.4.1.错误处理执行root.sh时报错缺少libcap.so.1
3.4.2.执行root.sh报错ohasd failed to start
3.4.3.asm及crsd报错CRS-4535: Cannot communicate with Cluster Ready Services
3.4.4.添加listener
3.5. 查看状态
4 创建ASM磁盘组：DATA/FRA
5 安装oracle软件
6 建立数据库实例
7 检查修改部分数据库配置参数
7.1.密码过期时间
7.2.归档、redo、undo、datafile等检查
7.3.查看集群状态
7.4.创建表空间、用户、表等测试
8 备份
8.1.rman备份
8.2.expdp备份.
```

## 1.系统环境
### 1.1. 系统版本
```
[root@rac1 Packages]# cat /etc/redhat-release
CentOS Linux release 7.9.2009 (Core)
[root@rac1 ~]# uname -a
Linux rac1 3.10.0-1160.71.1.el7.x86_64 #1 SMP Tue Jun 28 15:37:28 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
Linux rac1 3.10.0-1160.119.1.el7.x86_64 #1 SMP Tue Jun 4 14:43:51 UTC 2024 x86_64 x86_64 x86_64 GNU/Linux
```
### 1.2. ASM 磁盘组规划

```
ASM 磁盘组 用途 大小 冗余
ocr、 voting file   100G+100G+100G NORMAL
DATA 数据文件 2T EXTERNAL
FRA 归档日志 2T EXTERNAL
```
#本次是oracle rac重装，使用原来的共享磁盘

#需要清空之前其他Oracle RAC项目使用过的共享磁盘，主要是删除磁盘上的ASM头信息、OCR数据和投票磁盘数据等Oracle特有标记

````bash
#清空共享磁盘的操作步骤

### 1. 确认磁盘信息
首先确认要清空的共享磁盘设备路径：
```bash
# 查看系统识别的磁盘设备
ls -l /dev/sd*

# 如果使用多路径设备
multipath -ll
```

### 2. 清除ASM磁盘头信息
```bash
# 清除磁盘开头部分(假设设备为/dev/sdX)
dd if=/dev/zero of=/dev/sdX bs=1M count=100
```

### 3. 对磁盘完全清零(更彻底但耗时)
```bash
# 完全清零整个磁盘
dd if=/dev/zero of=/dev/sdX bs=8M
```

### 4. 使用ASM命令清除标签(如果安装了ASMLib)
```bash
# 删除ASM磁盘标签
oracleasm deletedisk DISKNAME
```

### 5. 验证清除结果
```bash
# 检查磁盘头是否已被清除
dd if=/dev/sdX bs=1M count=1 | hexdump -C
```
````



#查看

```bash
dd if=/dev/sda bs=1M count=1 | hexdump -C|more

dd if=/dev/sdb bs=1M count=1 | hexdump -C|more

dd if=/dev/sdc bs=1M count=1 | hexdump -C|more

dd if=/dev/sdd bs=1M count=1 | hexdump -C|more

dd if=/dev/sde bs=1M count=1 | hexdump -C|more
```



#清除磁盘开头部分

```bash
dd if=/dev/zero of=/dev/sda bs=1M count=100

dd if=/dev/zero of=/dev/sdb bs=1M count=100

dd if=/dev/zero of=/dev/sdc bs=1M count=100

dd if=/dev/zero of=/dev/sdd bs=1M count=100

dd if=/dev/zero of=/dev/sde bs=1M count=100
```



#logs

```bash
[root@rac2 ~]# dd if=/dev/sda bs=1M count=1| hexdump -C|more
00000000  01 82 01 01 00 00 00 00  00 00 00 80 cc ea 76 c7  |..............v.|
00000010  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000020  4f 52 43 4c 44 49 53 4b  00 00 00 00 00 00 00 00  |ORCLDISK........|
00000030  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000040  00 00 20 0b 00 00 02 03  4f 43 52 5f 30 30 30 30  |.. .....OCR_0000|
00000050  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000060  00 00 00 00 00 00 00 00  4f 43 52 00 00 00 00 00  |........OCR.....|
00000070  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000080  00 00 00 00 00 00 00 00  4f 43 52 5f 30 30 30 30  |........OCR_0000|
00000090  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
000000c0  00 00 00 00 00 00 00 00  c9 4d fa 01 00 e4 93 e2  |.........M......|
000000d0  2a 4e fa 01 00 88 ec 52  00 02 00 10 00 00 10 00  |*N.....R........|
000000e0  80 bc 01 00 00 90 01 00  02 00 00 00 01 00 00 00  |................|
000000f0  02 00 00 00 02 00 00 00  00 00 00 00 00 00 00 00  |................|
00000100  00 00 10 0a c9 4d fa 01  00 3c 92 e2 00 01 00 00  |.....M...<......|
00000110  20 01 00 00 00 00 00 00  00 00 00 00 00 00 00 00  | ...............|
00000120  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00001000  01 82 02 02 01 00 00 00  00 00 00 80 99 92 f6 92  |................|
00001010  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00001020  00 00 00 00 fe 00 e5 00  00 00 01 00 00 00 00 00  |................|
00001030  00 00 00 00 00 00 00 00  77 10 10 10 10 10 10 10  |........w.......|
00001040  10 10 10 10 10 10 10 10  10 10 10 10 10 10 10 10  |................|
*
00001110  10 10 10 10 10 10 10 10  10 10 10 10 10 00 00 00  |................|
00001120  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00002000  01 82 03 02 02 00 00 00  00 00 00 80 6d 87 07 84  |............m...|
00002010  17 02 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00002020  00 00 00 00 c0 01 00 00  08 00 08 00 0c 00 0c 00  |................|
00002030  c8 09 c8 09 e8 09 e8 09  18 00 18 00 1c 00 1c 00  |................|


[root@rac2 ~]# dd if=/dev/zero of=/dev/sda bs=1M count=100
100+0 records in
100+0 records out
104857600 bytes (105 MB) copied, 0.323818 s, 324 MB/s
[root@rac2 ~]# dd if=/dev/zero of=/dev/sdb bs=1M count=100
100+0 records in
100+0 records out
104857600 bytes (105 MB) copied, 0.32408 s, 324 MB/s
[root@rac2 ~]# dd if=/dev/zero of=/dev/sdc bs=1M count=100
100+0 records in
100+0 records out
104857600 bytes (105 MB) copied, 0.32547 s, 322 MB/s
[root@rac2 ~]# dd if=/dev/sda bs=1M count=1| hexdump -C
00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00100000
1+0 records in
1+0 records out
1048576 bytes (1.0 MB) copied, 0.00886925 s, 118 MB/s
[root@rac2 ~]#

```



### 1.3. 主机网络规划

#### 1.3.1.IP规划
```
网络配置               节点 1                               节点 2
主机名称               rac1                                 rac2
public ip            192.168.10.52                         192.168.10.53
private ip           10.10.20.2                            10.10.20.3
vip                  192.168.10.54                         192.168.10.55
scan ip              192.168.10.56
```
#### 1.3.2.网卡配置


##### 1.3.2.1.网卡eth0走业务网
```
[root@rac1 network-scripts]# cat ifcfg-eth0
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="eth0"
UUID=2706ecb5-8d68-49aa-ae6b-3ca89383a6b9
DEVICE="eth0"
ONBOOT="yes"
IPADDR="192.168.10.52"
PREFIX="25"
GATEWAY="192.168.10.1"
DNS1="210.38.208.50"
DNS2="210.38.208.55"
IPV6_PRIVACY="no"
[root@rac1 network-scripts]# cat ifcfg-eth1
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="eth1"
UUID=c9d607fd-66c8-45e8-be7f-9c6cf0b981b0
DEVICE="eth1"
ONBOOT="yes"
IPADDR="10.10.20.2"
PREFIX="24"
DNS1="210.38.208.50"
DNS2="210.38.208.55"
IPV6_PRIVACY="no"
[root@rac1 network-scripts]#

[root@rac1 network-scripts]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:f8:9e:08 brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.52/25 brd 192.168.10.127 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::e6f7:bc52:60e7:4a09/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:c8:70:06 brd ff:ff:ff:ff:ff:ff
    inet 10.10.20.2/24 brd 10.10.20.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::e6d6:3e4a:d0f4:587b/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
[root@rac1 network-scripts]#

[root@rac2 network-scripts]# cat ifcfg-eth0
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="eth0"
UUID=6c9e468f-4791-4f91-a158-713a1cbfcb8e
DEVICE="eth0"
ONBOOT="yes"
IPADDR="192.168.10.53"
PREFIX="25"
GATEWAY="192.168.10.1"
DNS1="210.38.208.50"
DNS2="210.38.208.55"
IPV6_PRIVACY="no"
[root@rac2 network-scripts]# cat ifcfg-eth1
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="eth1"
UUID=3b7f833c-3209-4416-a9a8-ce1f040aa3aa
DEVICE="eth1"
ONBOOT="yes"
IPADDR="10.10.20.3"
PREFIX="24"
DNS1="210.38.208.50"
DNS2="210.38.208.55"
IPV6_PRIVACY="no"
[root@rac2 network-scripts]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:b6:f0:89 brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.53/25 brd 192.168.10.127 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::cdc6:fde5:63d4:b010/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:1a:a2:4d brd ff:ff:ff:ff:ff:ff
    inet 10.10.20.3/24 brd 10.10.20.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::3955:ca28:2a99:75ad/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
[root@rac2 network-scripts]#

```

##### 1.3.2.2.网卡eth1两台服务器直连，做私有网络

```
#添加第二块网卡后，网卡配置没有
[root@rac1 network-scripts]# 
[root@rac1 network-scripts]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.10.52  netmask 255.255.255.0  broadcast 172.30.104.255
        inet6 fe80::89d9:33b1:fa46:2bb6  prefixlen 64  scopeid 0x20<link>
        inet6 fe80::9497:a9e8:ccc5:c68c  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:67:21:05  txqueuelen 1000  (Ethernet)
        RX packets 4157785  bytes 5461407091 (5.0 GiB)
        RX errors 0  dropped 34  overruns 0  frame 0
        TX packets 787700  bytes 56611997 (53.9 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether fe:fc:fe:d7:e1:0e  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 2971  bytes 303339 (296.2 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2971  bytes 303339 (296.2 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

virbr0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 192.168.122.1  netmask 255.255.255.0  broadcast 192.168.122.255
        ether 52:54:00:c7:da:73  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@rac1 network-scripts]# ls
ifcfg-ens18  ifcfg-lo     ifdown-ib    ifdown-post    ifdown-Team      ifup-aliases  ifup-ippp  ifup-plusb   ifup-sit       ifup-wireless
ifcfg-ens19  ifdown       ifdown-ippp  ifdown-ppp     ifdown-TeamPort  ifup-bnep     ifup-ipv6  ifup-post    ifup-Team      init.ipv6-global
ifcfg-eth0   ifdown-bnep  ifdown-ipv6  ifdown-routes  ifdown-tunnel    ifup-eth      ifup-isdn  ifup-ppp     ifup-TeamPort  network-functions
ifcfg-eth1   ifdown-eth   ifdown-isdn  ifdown-sit     ifup             ifup-ib       ifup-plip  ifup-routes  ifup-tunnel    network-functions-ipv6
[root@rac1 network-scripts]# nmcli con show
NAME    UUID                                  TYPE      DEVICE
eth0    5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03  ethernet  eth0
virbr0  1f6d6af8-28fd-48c0-b871-3a3e9b05c528  bridge    virbr0
ens18   26578edb-2bdf-46d6-a4bf-aeb810865581  ethernet  --
ens19   647edc57-ba11-4d1e-89c0-aac69558b937  ethernet  --
eth1    9c92fad9-6ecb-3e6c-eb4d-8a47c6f50c04  ethernet  --
[root@rac1 network-scripts]#

[root@rac1 network-scripts]#
[root@rac1 network-scripts]# cat ifcfg-eth1
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
UUID=5cbe8fbc-1ec4-4524-ac97-1fd8497fc8b4
DEVICE=eth1
ONBOOT=yes
IPADDR=10.10.20.2
PREFIX=25
GATEWAY=3.3.3.1

[root@rac1 network-scripts]# systemctl restart network
[root@rac1 network-scripts]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.10.52  netmask 255.255.255.0  broadcast 211.70.1.255
        inet6 fe80::bbf4:fae8:61c9:1371  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:98:d4:28  txqueuelen 1000  (Ethernet)
        RX packets 12149  bytes 2297660 (2.1 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 735  bytes 130150 (127.0 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.10.20.2  netmask 255.255.255.0  broadcast 10.10.20.355
        inet6 fe80::fcfc:feff:fe8b:59ac  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:8b:59:ac  txqueuelen 1000  (Ethernet)
        RX packets 292  bytes 48144 (47.0 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 244  bytes 42100 (41.1 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0


--------------------------------------------------------
[root@studata2 network-scripts]# ls
ifcfg-ens18  ifdown-bnep  ifdown-ipv6  ifdown-ppp     ifdown-Team      ifup          ifup-eth   ifup-isdn   ifup-post    ifup-sit       ifup-tunnel       network-functions
ifcfg-lo     ifdown-eth   ifdown-isdn  ifdown-routes  ifdown-TeamPort  ifup-aliases  ifup-ippp  ifup-plip   ifup-ppp     ifup-Team      ifup-wireless     network-functions-ipv6
ifdown       ifdown-ippp  ifdown-post  ifdown-sit     ifdown-tunnel    ifup-bnep     ifup-ipv6  ifup-plusb  ifup-routes  ifup-TeamPort  init.ipv6-global

[root@studata2 network-scripts]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.10.53  netmask 255.255.255.0  broadcast 211.70.1.255
        inet6 fe80::f6ec:764f:b48f:d714  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:1b:c2:4b  txqueuelen 1000  (Ethernet)
        RX packets 2108  bytes 389851 (380.7 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 484  bytes 70524 (68.8 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether fe:fc:fe:9c:90:bc  txqueuelen 1000  (Ethernet)
        RX packets 50  bytes 8996 (8.7 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 57  bytes 10102 (9.8 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@studata2 network-scripts]# nmcli con show
NAME                UUID                                  TYPE      DEVICE
ens18               cd783228-c948-4466-ad13-56aac0b6a4ff  ethernet  eth0
Wired connection 1  8958f2a3-1be5-3790-b869-a68d60ba80b4  ethernet  --
[root@studata2 network-scripts]# nmcli con add con-name eth1  type ethernet ifname  eth1
Connection 'eth1' (0c5cd75c-f8fa-4855-a2b0-fbd7d8c2fb7e) successfully added.
[root@studata2 network-scripts]# nmcli con show
NAME                UUID                                  TYPE      DEVICE
eth1                0c5cd75c-f8fa-4855-a2b0-fbd7d8c2fb7e  ethernet  eth1
ens18               cd783228-c948-4466-ad13-56aac0b6a4ff  ethernet  eth0
Wired connection 1  8958f2a3-1be5-3790-b869-a68d60ba80b4  ethernet  --
[root@studata2 network-scripts]# ls
ifcfg-ens18  ifdown       ifdown-ippp  ifdown-post    ifdown-sit       ifdown-tunnel  ifup-bnep  ifup-ipv6  ifup-plusb  ifup-routes  ifup-TeamPort  init.ipv6-global
ifcfg-eth1   ifdown-bnep  ifdown-ipv6  ifdown-ppp     ifdown-Team      ifup           ifup-eth   ifup-isdn  ifup-post   ifup-sit     ifup-tunnel    network-functions
ifcfg-lo     ifdown-eth   ifdown-isdn  ifdown-routes  ifdown-TeamPort  ifup-aliases   ifup-ippp  ifup-plip  ifup-ppp    ifup-Team    ifup-wireless  network-functions-ipv6
[root@studata2 network-scripts]# cat ifcfg-eth1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth1
UUID=0c5cd75c-f8fa-4855-a2b0-fbd7d8c2fb7e
DEVICE=eth1
ONBOOT=yes
[root@studata2 network-scripts]# nmcli con show
NAME                UUID                                  TYPE      DEVICE
eth1                0c5cd75c-f8fa-4855-a2b0-fbd7d8c2fb7e  ethernet  eth1
ens18               cd783228-c948-4466-ad13-56aac0b6a4ff  ethernet  eth0
Wired connection 1  8958f2a3-1be5-3790-b869-a68d60ba80b4  ethernet  --

[root@studata2 network-scripts]# cat ifcfg-eth1
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
NAME=eth1
UUID=0c5cd75c-f8fa-4855-a2b0-fbd7d8c2fb7e
DEVICE=eth1
ONBOOT=yes
IPADDR=10.10.20.2
PREFIX=25
GATEWAY=3.3.3.1

[root@studata2 network-scripts]# systemctl restart network
[root@studata2 network-scripts]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.10.53  netmask 255.255.255.0  broadcast 211.70.1.255
        inet6 fe80::f6ec:764f:b48f:d714  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:1b:c2:4b  txqueuelen 1000  (Ethernet)
        RX packets 13207  bytes 2493978 (2.3 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 1072  bytes 170551 (166.5 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.10.20.2  netmask 255.255.255.0  broadcast 10.10.20.355
        inet6 fe80::c721:b3a1:4554:7cec  prefixlen 64  scopeid 0x20<link>
        ether fe:fc:fe:9c:90:bc  txqueuelen 1000  (Ethernet)
        RX packets 247  bytes 41662 (40.6 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 300  bytes 48424 (47.2 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

```


##### 1.3.2.4.最后网络配置信息
```bash
ip route list
route -n
ifconfig
sfdisk -s
```
#内容如下
```
[root@rac1 ~]# ip route list
default via 192.168.10.1 dev eth0 proto static metric 100
10.10.20.0/24 dev eth1 proto kernel scope link src 10.10.20.2 metric 101
192.168.10.0/25 dev eth0 proto kernel scope link src 192.168.10.52 metric 100

[root@rac1 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.10.1    0.0.0.0         UG    100    0        0 eth0
10.10.20.0      0.0.0.0         255.255.255.0   U     101    0        0 eth1
192.168.10.0    0.0.0.0         255.255.255.128 U     100    0        0 eth0

[root@rac1 ~]# sfdisk -s
/dev/vda: 524288000
/dev/vdb: 2147483648
/dev/sda: 104857600
/dev/sdb: 104857600
/dev/sdc: 104857600
/dev/sdd: 2147483648
/dev/sde: 2147483648
/dev/mapper/centos-root: 2549084160
/dev/mapper/centos-swap:  16773120
/dev/mapper/centos-home: 104857600
total: 9952026624 blocks

[root@rac1 ~]# free -m
              total        used        free      shared  buff/cache   available
Mem:         128764        1623      126719           8         421      126419
Swap:         16379           0       16379

#注意网卡UUID不要相同
#uuidgen

[root@rac1 network-scripts]# nmcli con show
NAME  UUID                                  TYPE      DEVICE
eth0  2706ecb5-8d68-49aa-ae6b-3ca89383a6b9  ethernet  eth0
eth1  c9d607fd-66c8-45e8-be7f-9c6cf0b981b0  ethernet  eth1
[root@rac1 network-scripts]#

[root@rac2 network-scripts]# nmcli con show
NAME  UUID                                  TYPE      DEVICE
eth0  6c9e468f-4791-4f91-a158-713a1cbfcb8e  ethernet  eth0
eth1  3b7f833c-3209-4416-a9a8-ce1f040aa3aa  ethernet  eth1
[root@rac2 network-scripts]#



[root@rac1 ~]# arp -a
rac2-vip (192.168.10.55) at <incomplete> on eth0
rac2-prv (10.10.20.3) at 00:16:3e:1a:a2:4d [ether] on eth1
rac1-vip (192.168.10.54) at <incomplete> on eth0
gateway (192.168.10.1) at 58:48:49:25:82:4c [ether] on eth0
rac2 (192.168.10.53) at 00:16:3e:b6:f0:89 [ether] on eth0
[root@rac1 ~]#

[root@rac2 ~]# arp -a
rac2-vip (192.168.10.55) at <incomplete> on eth0
rac1-vip (192.168.10.54) at <incomplete> on eth0
rac1 (192.168.10.52) at 00:16:3e:f8:9e:08 [ether] on eth0
rac1-prv (10.10.20.2) at 00:16:3e:c8:70:06 [ether] on eth1
gateway (192.168.10.1) at 58:48:49:25:82:4c [ether] on eth0
[root@rac2 ~]#

#rac2内容类似
```

### 1.4. 操作系统关闭防火墙和selinux

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
getenforce
```

### 1.5.回收/home分区

#由于老师在安装OS时，单独建了/home分区，防止磁盘满，将/home分区回收

```bash
[root@rac1 ~]# df -h
Filesystem               Size  Used Avail Use% Mounted on
devtmpfs                  63G     0   63G   0% /dev
tmpfs                     63G   52K   63G   1% /dev/shm
tmpfs                     63G  8.9M   63G   1% /run
tmpfs                     63G     0   63G   0% /sys/fs/cgroup
/dev/mapper/centos-root  2.4T  2.0G  2.4T   1% /
/dev/mapper/centos-home  100G   33M  100G   1% /home
/dev/vda1               1014M  152M  863M  15% /boot
tmpfs                     13G     0   13G   0% /run/user/0
[root@rac1 ~]#

[root@rac1 ~]# cd /
[root@rac1 /]# ls
bin   dev  home  lib64  mnt  proc  run   srv  tmp  var boot  etc  lib   media  opt  root  sbin  sys  usr
[root@rac1 /]# tar -zcvf home.tar.gz home
home/
home/hsroot/
home/hsroot/.bash_logout
home/hsroot/.bash_profile
home/hsroot/.bashrc
home/hsroot/.bash_history
[root@rac1 /]# ls
bin   etc          lib    mnt   root  srv  usr boot  home         lib64  opt   run   sys  var
dev   home.tar.gz  media  proc  sbin  tmp
[root@rac1 /]#
[root@rac1 /]# lvs
  LV   VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  home centos -wi-ao---- 100.00g                           
  root centos -wi-ao----   2.37t                           
  swap centos -wi-ao---- <16.00g                           
[root@rac1 /]# lvremove /dev/mapper/centos-home
  Logical volume centos/home contains a filesystem in use.
[root@rac1 /]#

[root@rac1 /]# ls /home/
hsroot
[root@rac1 /]#

#先将/etc/fstab中的home分区注释掉挂载，然后reboot
[root@rac1 /]# cat /etc/fstab

#
# /etc/fstab
# Created by anaconda on Thu Feb 27 08:59:25 2025
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=4869fbbb-b7e9-42c1-850b-5c06a44b369a /boot                   xfs     defaults        0 0
#/dev/mapper/centos-home /home                   xfs     defaults        0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
[root@rac1 /]# reboot


[root@rac1 ~]# df -h
Filesystem               Size  Used Avail Use% Mounted on
devtmpfs                  63G     0   63G   0% /dev
tmpfs                     63G   52K   63G   1% /dev/shm
tmpfs                     63G  8.9M   63G   1% /run
tmpfs                     63G     0   63G   0% /sys/fs/cgroup
/dev/mapper/centos-root  2.4T  2.0G  2.4T   1% /
/dev/vda1               1014M  152M  863M  15% /boot
tmpfs                     13G     0   13G   0% /run/user/0
[root@rac1 ~]#

[root@rac1 ~]# lvs
  LV   VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  home centos -wi-a----- 100.00g                           
  root centos -wi-ao----   2.37t                           
  swap centos -wi-ao---- <16.00g      
  
[root@rac1 ~]# lvremove /dev/mapper/centos-home
Do you really want to remove active logical volume centos/home? [y/n]: y
  Logical volume "home" successfully removed
  
[root@rac1 ~]# lvs
  LV   VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  root centos -wi-ao----   2.37t                           
  swap centos -wi-ao---- <16.00g          
  
[root@rac1 ~]# vgs
  VG     #PV #LV #SN Attr   VSize  VFree
  centos   2   2   0 wz--n- <2.49t 100.00g
  
[root@rac1 ~]# df -h
Filesystem               Size  Used Avail Use% Mounted on
devtmpfs                  63G     0   63G   0% /dev
tmpfs                     63G   52K   63G   1% /dev/shm
tmpfs                     63G  8.9M   63G   1% /run
tmpfs                     63G     0   63G   0% /sys/fs/cgroup
/dev/mapper/centos-root  2.4T  2.0G  2.4T   1% /
/dev/vda1               1014M  152M  863M  15% /boot
tmpfs                     13G     0   13G   0% /run/user/0
[root@rac1 ~]#

```

## 2.准备工作（rac1 与 rac2 同时配置）

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

#使用阿里云的源
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

yum clean all && yum makecache all

#可以先更新下内核
yum update -y
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
#检查是否安装全
```bash
rpm -qa|grep  binutils
rpm -qa|grep  compat-libcap1
rpm -qa|grep  compat-libstdc++-33
rpm -qa|grep  gcc
rpm -qa|grep  gcc-c++
rpm -qa|grep  glibc
rpm -qa|grep  glibc-devel
rpm -qa|grep  ksh
rpm -qa|grep  libgcc
rpm -qa|grep  libstdc++
rpm -qa|grep  libstdc++-devel
rpm -qa|grep  libaio
rpm -qa|grep  libaio-devel
rpm -qa|grep  libXext
rpm -qa|grep  libXtst
rpm -qa|grep  libX11
rpm -qa|grep  libXau
rpm -qa|grep  libxcb
rpm -qa|grep  libXi
rpm -qa|grep  make
rpm -qa|grep  sysstat
rpm -qa|grep  unixODBC
rpm -qa|grep  unixODBC-devel
rpm -qa|grep  readline
rpm -qa|grep  libtermcap-devel
rpm -qa|grep  bc
rpm -qa|grep  compat-libstdc++
rpm -qa|grep  elfutils-libelf
rpm -qa|grep  elfutils-libelf-devel
rpm -qa|grep  fontconfig-devel
rpm -qa|grep  libXi
rpm -qa|grep  libXtst
rpm -qa|grep  libXrender
rpm -qa|grep  libXrender-devel
rpm -qa|grep  libgcc
rpm -qa|grep  librdmacm-devel
rpm -qa|grep  libstdc++
rpm -qa|grep  libstdc++-devel
rpm -qa|grep  net-tools
rpm -qa|grep  nfs-utils
rpm -qa|grep  python
rpm -qa|grep  python-configshell
rpm -qa|grep  python-rtslib
rpm -qa|grep  python-six
rpm -qa|grep  targetcli
rpm -qa|grep  smartmontools
```

```bash
 rpm -qa   binutils    compat-libcap1    compat-libstdc++-33    gcc    gcc-c++    glibc    glibc-devel    ksh    libgcc    libstdc++    libstdc++-devel    libaio    libaio-devel    libXext    libXtst    libX11    libXau    libxcb    libXi    make    sysstat    unixODBC    unixODBC-devel    readline    libtermcap-devel    bc    compat-libstdc++    elfutils-libelf    elfutils-libelf-devel    fontconfig-devel    libXi    libXtst    libXrender    libXrender-devel    libgcc    librdmacm-devel    libstdc++    libstdc++-devel    net-tools    nfs-utils    python    python-configshell    python-rtslib    python-six    targetcli    smartmontools
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
#rac1
hostnamectl set-hostname rac1
#rac2
hostnamectl set-hostname rac2

cat >> /etc/hosts <<EOF
#public ip eth0
192.168.10.52 rac1
192.168.10.53 rac2
#vip
192.168.10.54 rac1-vip
192.168.10.55 rac2-vip
#private ip eth1
10.10.20.2 rac1-prv
10.10.20.3 rac2-prv
#scan ip
192.168.10.56 rac-scan

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

#语言
sudo echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
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
### 2.7. 其它优化配置

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


#关闭THP，检查是否开启---64G，暂时不用设置

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```
--->[always] madvise never
#若以上命令执行结果显示为“always”，则表示开启了THP

##方法一
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

##修改方法二，必须知道引导是BIOS还是EFI
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

#修改pam.d/login
```bash
cat >> /etc/pam.d/login <<EOF
#ORACLE SETTING
session required pam_limits.so

EOF

```
#修改/etc/sysctl.conf
#memory64G

```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 14062500
#memory*90%
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

EOF

sysctl -p
```
#memory128G

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

#grid用户，注意rac1/rac2两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意rac2修改
#export ORACLE_SID=+ASM2
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/11.2.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
#oracle用户，注意rac1/rac2的区别
```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1
export ORACLE_SID=szhxy1
#注意rac2修改
#export ORACLE_SID=szhxy2
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
### 2.9. 配置共享磁盘权限

#### 2.9.1.无多路径模式
#前面通过华为的软件已经设置好多路径，此处无需设置

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
[root@rac1 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 30cbf7872248422ed
/dev/sdb 32097c31cf9db6fcb
/dev/sdc 30442c10d43a466e4
/dev/sdd 31e2def1ead66aedd
/dev/sde 30ff5cc36a19ba2ab
/dev/sdsock /dev/sd_cloudhelper_update /dev/sd_sdcc_signin /dev/sd_sdec_signin /dev/sd_sdexam_signin /dev/sd_sdmonitor_command /dev/sd_sdsvrd_signin /dev/sd_udcenter_signin /dev/sd_update_config [root@rac1 ~]# 
[root@rac1 ~]# 
[root@rac1 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk 
sda               8:0    0  100G  0 disk 
sdb               8:16   0  100G  0 disk 
sdc               8:32   0  100G  0 disk 
sdd               8:48   0    2T  0 disk 
sde               8:64   0    2T  0 disk 
sr0              11:0    1 1024M  0 rom  
vda             252:0    0  500G  0 disk 
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0  499G  0 part 
  ├─centos-root 253:0    0  2.4T  0 lvm  /
  ├─centos-swap 253:1    0   16G  0 lvm  [SWAP]
  └─centos-home 253:2    0  100G  0 lvm  /home
vdb             252:16   0    2T  0 disk 
└─vdb1          252:17   0    2T  0 part 
  └─centos-root 253:0    0  2.4T  0 lvm  /
[root@rac1 ~]# 

[root@rac2 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 30cbf7872248422ed
/dev/sdb 32097c31cf9db6fcb
/dev/sdc 30442c10d43a466e4
/dev/sdd 31e2def1ead66aedd
/dev/sde 30ff5cc36a19ba2ab
/dev/sdsock /dev/sd_cloudhelper_update /dev/sd_sdcc_signin /dev/sd_sdec_signin /dev/sd_sdexam_signin /dev/sd_sdmonitor_command /dev/sd_sdsvrd_signin /dev/sd_udcenter_signin /dev/sd_update_config [root@rac2 ~]# 
[root@rac2 ~]# 
[root@rac2 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0               2:0    1    4K  0 disk 
sda               8:0    0  100G  0 disk 
sdb               8:16   0  100G  0 disk 
sdc               8:32   0  100G  0 disk 
sdd               8:48   0    2T  0 disk 
sde               8:64   0    2T  0 disk 
sr0              11:0    1 1024M  0 rom  
vda             252:0    0  500G  0 disk 
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0  499G  0 part 
  ├─centos-root 253:0    0  2.4T  0 lvm  /
  ├─centos-swap 253:1    0   16G  0 lvm  [SWAP]
  └─centos-home 253:2    0  100G  0 lvm  /home
vdb             252:16   0    2T  0 disk 
└─vdb1          252:17   0    2T  0 part 
  └─centos-root 253:0    0  2.4T  0 lvm  /

#reboot服务器后，uuid不会变化
```
#uuid不变，可以采用方法一

#99-oracle-asmdevices.rules

```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sda", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="30cbf7872248422ed", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdb", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="32097c31cf9db6fcb", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdc", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="30442c10d43a466e4", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdd", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="31e2def1ead66aedd", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sde", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="30ff5cc36a19ba2ab", OWNER="grid",GROUP="asmadmin", MODE="0660"
EOF

```

#如果暂时没法绑定uuid到具体盘符

#采用方法二

```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="36e650279d04e1f0a98903c89538f75f4", SYMLINK+="oracleasm/disks/DATA01", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="36fd00ef6f043f30a76a012015decdae2", SYMLINK+="oracleasm/disks/DATA02", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="3610e09574042d30bfed0a5fe8baba933", SYMLINK+="oracleasm/disks/OCR01", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="36b5b0f99a047b8082cd0af75c05c45a0", SYMLINK+="oracleasm/disks/OCR02", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="36d390d047041ff086f202095fdf7cee4", SYMLINK+="oracleasm/disks/OCR03", OWNER="grid", GROUP="asmadmin", MODE="0660"
EOF

```





#启动udev

```bash
/usr/sbin/partprobe

#[root@rac1 network-scripts]# /usr/sbin/partprobe
Warning: Unable to open /dev/sr0 read-write (Read-only file system).  /dev/sr0 has been opened read-only.

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service
```
#检查asm磁盘
```bash
ll /dev|grep asm
```
#方法一显示如下

```bash
[root@rac1 ~]# ll /dev|grep asm
brw-rw----  1 grid asmadmin   8,   0 Mar 13 16:22 sda
brw-rw----  1 grid asmadmin   8,  16 Mar 13 16:22 sdb
brw-rw----  1 grid asmadmin   8,  32 Mar 13 16:22 sdc
brw-rw----  1 grid asmadmin   8,  48 Mar 13 16:22 sdd
brw-rw----  1 grid asmadmin   8,  64 Mar 13 16:22 sde
[root@rac1 ~]# 

[root@rac2 ~]# ll /dev|grep asm
brw-rw----  1 grid asmadmin   8,   0 Mar 13 16:22 sda
brw-rw----  1 grid asmadmin   8,  16 Mar 13 16:22 sdb
brw-rw----  1 grid asmadmin   8,  32 Mar 13 16:22 sdc
brw-rw----  1 grid asmadmin   8,  48 Mar 13 16:22 sdd
brw-rw----  1 grid asmadmin   8,  64 Mar 13 16:22 sde
[root@rac2 ~]# 
```



#方法二显示如下

```
[root@rac1 ~]# ll /dev/|grep asm
drwxr-xr-x   3 root root           60 Mar  6 11:18 oracleasm
brw-rw----   1 grid asmadmin   8,   0 Mar  6 11:18 sda
brw-rw----   1 grid asmadmin   8,  16 Mar  6 11:18 sdb
brw-rw----   1 grid asmadmin   8,  80 Mar  6 11:18 sdf
brw-rw----   1 grid asmadmin   8,  96 Mar  6 11:18 sdg
brw-rw----   1 grid asmadmin   8, 112 Mar  6 11:18 sdh
[root@rac1 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sdf           8:80   0   100G  0 disk
sdd           8:48   0    50G  0 disk
sdb           8:16   0     2T  0 disk
sr0          11:0    1   4.5G  0 rom
sdg           8:96   0   100G  0 disk
sde           8:64   0    50G  0 disk
sdc           8:32   0    50G  0 disk
sda           8:0    0     2T  0 disk
vda         251:0    0   600G  0 disk
├─vda2      251:2    0 531.5G  0 part
│ ├─ol-swap 252:1    0  31.5G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   500G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sdh           8:112  0   100G  0 disk
[root@rac1 ~]# ll /dev/oracleasm/disks/
total 0
lrwxrwxrwx 1 root root 9 Mar  6 11:18 DATA01 -> ../../sda
lrwxrwxrwx 1 root root 9 Mar  6 11:18 DATA02 -> ../../sdb
lrwxrwxrwx 1 root root 9 Mar  6 11:18 OCR01 -> ../../sdg
lrwxrwxrwx 1 root root 9 Mar  6 11:18 OCR02 -> ../../sdf
lrwxrwxrwx 1 root root 9 Mar  6 11:18 OCR03 -> ../../sdh
[root@rac1 ~]#


[root@rac2 ~]# ll /dev/|grep asm
drwxr-xr-x   3 root root           60 Mar  6 11:18 oracleasm
brw-rw----   1 grid asmadmin   8,   0 Mar  6 11:18 sda
brw-rw----   1 grid asmadmin   8,  32 Mar  6 11:18 sdc
brw-rw----   1 grid asmadmin   8,  80 Mar  6 11:18 sdf
brw-rw----   1 grid asmadmin   8,  96 Mar  6 11:18 sdg
brw-rw----   1 grid asmadmin   8, 112 Mar  6 11:18 sdh
[root@rac2 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sdf           8:80   0   100G  0 disk
sdd           8:48   0    50G  0 disk
sdb           8:16   0    50G  0 disk
sr0          11:0    1   4.5G  0 rom
sdg           8:96   0   100G  0 disk
sde           8:64   0    50G  0 disk
sdc           8:32   0     2T  0 disk
sda           8:0    0     2T  0 disk
vda         251:0    0   600G  0 disk
├─vda2      251:2    0 531.5G  0 part
│ ├─ol-swap 252:1    0  31.5G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   500G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sdh           8:112  0   100G  0 disk
[root@rac2 ~]# ll /dev/oracleasm/disks/
total 0
lrwxrwxrwx 1 root root 9 Mar  6 11:18 DATA01 -> ../../sdc
lrwxrwxrwx 1 root root 9 Mar  6 11:18 DATA02 -> ../../sda
lrwxrwxrwx 1 root root 9 Mar  6 11:18 OCR01 -> ../../sdg
lrwxrwxrwx 1 root root 9 Mar  6 11:18 OCR02 -> ../../sdf
lrwxrwxrwx 1 root root 9 Mar  6 11:18 OCR03 -> ../../sdh
[root@rac2 ~]#


```
#知识补充：/usr/lib/systemd/system/systemd-udev-trigger.service
```
[root@rac1 ~]# cat /usr/lib/systemd/system/systemd-udev-trigger.service
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

[root@rac1 ~]# cat /usr/lib/systemd/system/systemd-udevd.service
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
[root@rac1 ~]# sfdisk -s
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

[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
211e8f142da86728d6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2e25b665dc06369916c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
211e8f142da86728d6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2e25b665dc06369916c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
211e8f142da86728d6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2e25b665dc06369916c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
2f8505ff366f3732a6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
211e8f142da86728d6c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdae
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaf
2e25b665dc06369916c9ce900b6fab6bc
[root@rac1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdag
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

#以下只在rac1执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh rac2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh rac2 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys rac2:~/.ssh/authorized_keys

#第一遍输入时需要输入yes
ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date

ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date

#在rac2执行
#第一遍输入时需要输入yes
ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date

ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在rac1执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

#注意过程中第一次时可能需要输入yes
ssh rac2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh rac2 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys rac2:~/.ssh/authorized_keys

#注意过程中第一次时可能需要输入yes
ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date

ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date

#在rac2上执行
#注意过程中第一次需要输入yes
ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date

ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date
```

```
#如果服务器之间修改了默认的22ssh端口，需要修改/etc/services中的ssh端口为响应的端口
[grid@rac1 ~]$ ssh rac2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
ssh: connect to host rac2 port 22: Connection refused
[grid@rac1 ~]$ cat /etc/ssh/sshd_config
cat: /etc/ssh/sshd_config: Permission denied
[grid@rac1 ~]$ exit
logout
[root@rac1 ~]# ping rac2
PING rac2 (192.168.10.53) 56(84) bytes of data.
64 bytes from rac2 (192.168.10.53): icmp_seq=1 ttl=64 time=0.128 ms
^C
--- rac2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.128/0.128/0.128/0.000 ms
[root@rac1 ~]# ssh rac2
ssh: connect to host rac2 port 22: Connection refused
[root@rac1 ~]# cat /etc/ssh/sshd_config
#       $OpenBSD: sshd_config,v 1.100 2016/08/15 12:32:04 naddy Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/bin:/usr/bin

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

# If you want to change the port on a SELinux system, you have to tell
# SELinux about this change.
# semanage port -a -t ssh_port_t -p tcp #PORTNUMBER
#
Port 23231
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

------------
vi /etc/services
ssh             22/tcp                          # The Secure Shell (SSH) Protocol
------>
ssh             23231/tcp                          # The Secure Shell (SSH) Protocol

--------------
[root@rac1 ~]# su - grid
Last login: Mon Oct  3 17:32:03 CST 2022 on pts/0
[grid@rac1 ~]$ ssh rac2 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
The authenticity of host '[rac2]:23231 ([192.168.10.53]:23231)' can't be established.
ECDSA key fingerprint is SHA256:iZflP699bZkC0yjy6bExcDMZ1g1giBpRK+FmBDlx0kA.
ECDSA key fingerprint is MD5:d4:a7:41:b2:71:9b:e6:68:6e:74:7f:84:d6:78:66:6e.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[rac2]:23231,[192.168.10.53]:23231' (ECDSA) to the list of known hosts.
grid@rac2's password:
[grid@rac1 ~]$

```



```bash
#如果两台服务器时间不一致，需要rdate时间同步下
su - root
yum install -y rdate 
rdate -s time.nist.gov

su - grid
ssh rac1 date;ssh rac2 date;ssh rac1-prv date;ssh rac2-prv date
```



### 2.11. 安装vnc

#服务器远程操作，安装vnc，便于图形安装

#### 2.11.1.安装图形化组件并重启
```bash
yum grouplist
yum groupinstall -y "Server with GUI"

reboot

修改参数，启用X11 Forwarding    
vi /etc/ssh/sshd_config
    X11Forwarding yes
    X11UseLocalhost no
 
    重启sshd服务
systemctl restart sshd.service
```
#装完这个重启后，可能会引起NetworkManager的启动，需重新关闭下

```bash
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service
```
#装完这个重启后，可能会生成virbr0，需关闭，如果不关闭，那么安装前预检查会报错
```
#ifconfig
virbr0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 192.168.122.1  netmask 255.255.255.0  broadcast 192.168.122.255
        ether 52:54:00:0d:80:29  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        
#precheck-error
Check: Node connectivity of subnet "192.168.122.0"
  Source                          Destination                     Connected?      
  ------------------------------  ------------------------------  ----------------
  rac2[192.168.122.1]         rac1[192.168.122.1]         yes             
Result: Node connectivity passed for subnet "192.168.122.0" with node(s) rac2,rac1


Check: TCP connectivity of subnet "192.168.122.0"
  Source                          Destination                     Connected?      
  ------------------------------  ------------------------------  ----------------
  rac1:192.168.122.1          rac2:192.168.122.1          failed          

ERROR: 
PRVF-7617 : Node connectivity between "rac1 : 192.168.122.1" and "rac2 : 192.168.122.1" failed
Result: TCP connectivity check failed for subnet "192.168.122.0"
```
#关闭并
```bash
brctl show

ifconfig virbr0 down
brctl delbr virbr0

systemctl disable libvirtd.service 
```
```
#日志
[root@rac1 ~]# brctl show
bridge name     bridge id               STP enabled     interfaces
virbr0          8000.5254002d8cd5       yes             virbr0-nic
[root@rac1 ~]# ifconfig virbr0 down
[root@rac1 ~]# brctl delbr virbr0
[root@rac1 ~]# systemctl disable libvirtd.service
Removed symlink /etc/systemd/system/multi-user.target.wants/libvirtd.service.
Removed symlink /etc/systemd/system/sockets.target.wants/virtlogd.socket.
Removed symlink /etc/systemd/system/sockets.target.wants/virtlockd.socket.
[root@rac1 ~]#
```

#### 2.11.2.安装xterm
```bash
yum install -y xterm*
#如果提示：已拒绝X11转移申请，那么安装xorg-x11-xauth
yum install -y xorg-x11-xauth
#或者本地镜像需挨着安装包
yum install -y xorg-x11-xkb-utils
yum install -y xorg-x11-xauth

rpm -ivh xorg-x11-xkb-utils-7.7-14.el7.x86_64.rpm
rpm -ivh xorg-x11-xauth-1.0.9-1.el7.x86_64.rpm
rpm -ivh xterm-295-3.el7.x86_64.rpm

#本地打开xstart
#用grid账户通过ssh登录
#命令为/usr/bin/xterm -ls -display $DISPLAY
```
#### 2.11.3.安装vnc---选做
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
--->password: vncserver
--->a view-only password: no
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
[root@rac1 ~]# yum grouplist
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
[root@rac1 ~]#yum groupinstall -y "Server with GUI"

[root@rac1 ~]# ps -ef|grep vnc
grid      2998     1  0 14:23 pts/0    00:00:00 /bin/Xvnc :1 -auth /home/grid/.Xauthority -desktop rac1:1 (grid) -fp catalogue:/etc/X11/fontpath.d -geometry 1024x768 -httpd /usr/share/vnc/classes -pn -rfbauth /home/grid/.vnc/passwd -rfbport 5901 -rfbwait 30000
grid      3017     1  0 14:23 pts/0    00:00:00 /bin/sh /home/grid/.vnc/xstartup
root      4508  2099  0 14:26 pts/0    00:00:00 grep --color=auto vnc

[grid@rac1 ~]$ vncserver -list

TigerVNC server sessions:

X DISPLAY #	PROCESS ID
:1		14370
```

## 3 开始安装 GI

### 3.1. 上传oracle rac软件安装包并解压缩

#将软件包上传至rac1的/u01/Storage目录下
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
#rac1下执行
su - grid

cd /u01/Storage/grid/rpm
cp cvuqdisk-1.0.9-1.rpm /u01

scp cvuqdisk-1.0.9-1.rpm rac2:/u01

#rac1/rac2都要执行
su - root

cd /u01
rpm -ivh cvuqdisk-1.0.9-1.rpm
```
#安装前检查，只在rac1上执行
```bash
su - grid

cd /u01/Storage/grid/
./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -fixup -verbose|tee -a pre.log
```
#会生成fixup脚本，需在rac1/rac2上执行
#如果报错以下，可以忽略
```
Check: Package existence for "pdksh" 
  Node Name     Available                 Required                  Status    
  ------------  ------------------------  ------------------------  ----------
  rac2       missing                   pdksh-5.2.14              failed    
  rac1       missing                   pdksh-5.2.14              failed    
Result: Package existence check failed for "pdksh"

Interfaces found on subnet "211.70.1.0" that are likely candidates for VIP are:
rac2 eth0:192.168.10.53
rac1 eth0:192.168.10.52

Interfaces found on subnet "3.3.3.0" that are likely candidates for VIP are:
rac2 eth1:10.10.20.3
rac1 eth1:10.10.20.2

WARNING:
Could not find a suitable set of interfaces for the private interconnect
Checking subnet mask consistency...
Subnet mask consistency check passed for subnet "211.70.1.0".
Subnet mask consistency check passed for subnet "3.3.3.0".
Subnet mask consistency check passed.

Result: Node connectivity check passed
```
#如果报错以下内容必须处理
```
Checking Core file name pattern consistency...

ERROR:
PRVF-6402 : Core file name pattern is not same on all the nodes.
Found core filename pattern "|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h" on nodes "rac1".
Found core filename pattern "core.%p" on nodes "rac2".
Core file name pattern consistency check failed.
```
#解决办法，可以将node1的abrt-hook-ccpp关闭
#查看core_pattern
```bash
[root@rac1 ~]# more /proc/sys/kernel/core_pattern
|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h
[root@rac1 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; enabled; vendor preset: enabled)
   Active: active (exited) since Wed 2021-11-03 10:58:38 CST; 1 months 18 days ago
  Process: 806 ExecStart=/usr/sbin/abrt-install-ccpp-hook install (code=exited, status=0/SUCCESS)
 Main PID: 806 (code=exited, status=0/SUCCESS)
    Tasks: 0
   CGroup: /system.slice/abrt-ccpp.service
Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.


[root@rac2 ~]# more /proc/sys/kernel/core_pattern
core
[root@rac2 ~]# systemctl status abrt-ccpp.service
Unit abrt-ccpp.service could not be found.
```
#rac1关闭abrt-ccpp
```bash
systemctl stop abrt-ccpp.service
systemctl disable abrt-ccpp.service
systemctl status abrt-ccpp.service
```
#此时再次runcluvfy即可通过

```
[root@rac1 ~]# systemctl stop abrt-ccpp.service
[root@rac1 ~]# systemctl disable abrt-ccpp.service
Removed symlink /etc/systemd/system/multi-user.target.wants/abrt-ccpp.service.
[root@rac1 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; disabled; vendor preset: enabled)
   Active: inactive (dead)

Dec 22 14:06:03 rac1 systemd[1]: Starting Install ABRT coredump hook...
Dec 22 14:06:03 rac1 systemd[1]: Started Install ABRT coredump hook.
Dec 22 14:47:32 rac1 systemd[1]: Stopping Install ABRT coredump hook...
Dec 22 14:47:32 rac1 systemd[1]: Stopped Install ABRT coredump hook.
[root@rac1 ~]# more /proc/sys/kernel/core_pattern
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
--->cluster name:rac-scan/scan name:rac-scan/scan port:1521,去掉configure GNS前面的勾
--->add:rac2/rac2-vip,SSHconnectivity,test
--->eth0:192.168.10.0:Public,eth1:10.10.20.0:Private
--->oracle ASM
DiskGroupName:OCR,normal,AUSize:1M,Candidate Disks----Chang Discovery Path: /dev/*---/dev/sda|/dev/sdb|/dev/sdc---102400Mi--->
--->use same passwords for these accounts:Ora543Cle---Do Not Use IPMI
--->asmadmin/asmdba/asmoper
--->Oracle Base:/u01/app/grid,Oracle Home:/u01/app/11.2.0/grid
--->Inventory Directory:/u01/app/oraInventory
--->缺少pdksh/Device Checks for ASM,可以忽略
--->install
--->/u01/app/oraInventory/orainstRoot.sh,/u01/app/11.2.0/grid/root.sh，必须先在rac1上执行完毕这两个脚本，再在rac2上执行，出现错误时见下面的错误处理步骤，如果弹框看不到内容，可以用鼠标拖动
---->INS-20802，忽略，如果弹框看不到内容，也无法用鼠标拖动，可以按4次Tab键后回车即可
---->INS-32091，忽略，如果弹框看不到内容，也无法用鼠标拖动，可以按4次Tab键后回车即可
---->close


#如果共享磁盘采用方式二，那么Chang Discovery Path: /dev/oracleasm/disks---OCR01/OCR02/OCR03
```
#### 3.4.错误处理

##### 3.4.1.错误处理执行root.sh时报错缺少libcap.so.1
```
Installing Trace File Analyzer
Failed to create keys in the OLR, rc = 127, Message:
  /u01/app/11.2.0/grid/bin/clscfg.bin: error while loading shared libraries: libcap.so.1: cannot open shared object file: No such file or directory

Failed to create keys in the OLR at /u01/app/11.2.0/grid/crs/install/crsconfig_lib.pm line 7660.
/u01/app/11.2.0/grid/perl/bin/perl -I/u01/app/11.2.0/grid/perl/lib -I/u01/app/11.2.0/grid/crs/install /u01/app/11.2.0/grid/crs/install/rootcrs.pl execution failed

```
#解决办法，rac1/rac2都执行
```bash
cd /lib64
ll|grep libcap
ln -s libcap.so.2.22 libcap.so.1
ll|grep libcap
```
#然后rac1重新执行root.sh
```bash
/u01/app/11.2.0/grid/root.sh
```
##### 3.4.2.执行root.sh报错ohasd failed to start
```
Adding Clusterware entries to inittab
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

[root@rac1 init.d]# systemctl status ohas.service
● ohas.service - Oracle High Availability Services
   Loaded: loaded (/usr/lib/systemd/system/ohas.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2022-01-04 11:45:14 CST; 8s ago
 Main PID: 42231 (init.ohasd)
   CGroup: /system.slice/ohas.service
           └─42231 /bin/sh /etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple

Jan 04 11:45:14 rac1 systemd[1]: Started Oracle High Availability Services.


#此时rac1的root.sh会继续安装下去，无需重新执行root.sh脚本

#注意： 为了避免其余节点遇到这种报错，可以在root.sh执行过程中，待/etc/init.d/目录下生成了init.ohasd 文件后，执行systemctl start ohas.service 启动ohas服务即可。若没有/etc/init.d/init.ohasd文件 systemctl start ohas.service 则会启动失败。
```
##### 3.4.3.asm及crsd报错CRS-4535: Cannot communicate with Cluster Ready Services
#如果是光纤直连服务器和SAN存储，因OCR检查时间是15s，但是服务器与存储间检查时间是30s，导致asm报错，从而crs整体报错

```bash
[root@rac1 ~]# cat /sys/block/sdb/device/timeout 
30
[root@rac1 ~]# sqlplus / as sysasm
```
```oracle
SQL> select name, state from v$asm_diskgroup;

NAME			       STATE
------------------------------ -----------
OCR			       DISMOUNTED

SQL> SELECT   ksppinm, ksppstvl, ksppdesc
   FROM   x$ksppi x, x$ksppcv y
  WHERE   x.indx = y.indx AND  ksppinm = '_asm_hbeatiowait' ;

KSPPINM
--------------------------------------------------------------------------------
KSPPSTVL
--------------------------------------------------------------------------------
KSPPDESC
--------------------------------------------------------------------------------
_asm_hbeatiowait
15
number of secs to wait for PST Async Hbeat IO return
```
#解决办法
#rac1/rac2都要修改

```oracle
SQL> select name, state from v$asm_diskgroup;

NAME			       STATE
------------------------------ -----------
OCR			       DISMOUNTED

SQL> alter diskgroup ocr mount;

Diskgroup altered.

SQL> alter system set "_asm_hbeatiowait"=120 scope=spfile sid='*';

System altered.
```
#rac1/rac2都要重启crs生效
```bash
crsctl stop crs -f 
crsctl start crs
crsctl enable crs
```
#重启集群后，查看下参数
```oracle
SQL> SELECT   ksppinm, ksppstvl, ksppdesc
   FROM   x$ksppi x, x$ksppcv y
  WHERE   x.indx = y.indx AND  ksppinm = '_asm_hbeatiowait' ;  2    3  

KSPPINM
--------------------------------------------------------------------------------
KSPPSTVL
--------------------------------------------------------------------------------
KSPPDESC
--------------------------------------------------------------------------------
_asm_hbeatiowait
120
number of secs to wait for PST Async Hbeat IO return
```
#报错日志
```
#/u01/app/grid/diag/asm/+asm/+ASM2/trace/alert_+ASM2.log
ue Jan 04 12:57:51 2022
ASM Health Checker found 1 new failures
Tue Jan 04 12:58:03 2022
SUCCESS: diskgroup OCR was dismounted
SUCCESS: alter diskgroup OCR dismount force /* ASM SERVER:238559154 */
SUCCESS: ASM-initiated MANDATORY DISMOUNT of group OCR
Tue Jan 04 12:58:03 2022
NOTE: diskgroup resource ora.OCR.dg is offline
Tue Jan 04 12:58:03 2022
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING: requested mirror side 1 of virtual extent 5 logical extent 0 offset 704512 is not allocated; I/O request failed
WARNING: requested mirror side 2 of virtual extent 5 logical extent 1 offset 704512 is not allocated; I/O request failed
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
ORA-15078: ASM diskgroup was forcibly dismounted
Tue Jan 04 12:58:03 2022
SQL> alter diskgroup OCR check /* proxy */ 
ORA-15032: not all alterations performed
ORA-15001: diskgroup "OCR" does not exist or is not mounted
ERROR: alter diskgroup OCR check /* proxy */

#/u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc
*** 2022-01-04 14:09:06.969
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
ksfdrfms:Mirror Read file=+OCR.255.4294967295 fob=0x90c03648 bufp=0x7f5878cb2a00 blkno=1125 nbytes=4096
WARNING:failed xlate 1 
WARNING: requested mirror side 1 of virtual extent 4 logical extent 0 offset 413696 is not allocated; I/O request failed
ksfdrfms:Read failed from mirror side=1 logical extent number=0 dskno=65535
WARNING:failed xlate 1 
WARNING: requested mirror side 2 of virtual extent 4 logical extent 1 offset 413696 is not allocated; I/O request failed
ksfdrfms:Read failed from mirror side=2 logical extent number=1 dskno=65535
ORA-15078: ASM diskgroup was forcibly dismounted
ORA-15078: ASM diskgroup was forcibly dismounted

#/u01/app/11.2.0/grid/log/rac2/crsd/crsd.log
2022-01-04 12:58:15.154: [ CRSMAIN][859629376] Initializing OCR
[   CLWAL][859629376]clsw_Initialize: OLR initlevel [70000]
2022-01-04 12:58:15.480: [  OCRASM][859629376]proprasmo: Error in open/create file in dg [OCR]
[  OCRASM][859629376]SLOS : SLOS: cat=8, opn=kgfoOpen01, dep=15056, loc=kgfokge

2022-01-04 12:58:15.480: [  OCRASM][859629376]ASM Error Stack :
2022-01-04 12:58:15.512: [  OCRASM][859629376]proprasmo: kgfoCheckMount returned [6]
2022-01-04 12:58:15.512: [  OCRASM][859629376]proprasmo: The ASM disk group OCR is not found or not mounted
2022-01-04 12:58:15.513: [  OCRRAW][859629376]proprioo: Failed to open [+OCR]. Returned proprasmo() with [26]. Marking location as UNAVAILABLE.
2022-01-04 12:58:15.513: [  OCRRAW][859629376]proprioo: No OCR/OLR devices are usable
2022-01-04 12:58:15.513: [  OCRASM][859629376]proprasmcl: asmhandle is NULL
2022-01-04 12:58:15.513: [    GIPC][859629376] gipcCheckInitialization: possible incompatible non-threaded init from [prom.c : 690], original from [clsss.c : 5343]
2022-01-04 12:58:15.514: [ default][859629376]clsvactversion:4: Retrieving Active Version from local storage.
2022-01-04 12:58:15.516: [ CSSCLNT][859629376]clssgsgrppubdata: group (ocr_rac-scan) not found

2022-01-04 12:58:15.516: [  OCRRAW][859629376]proprio_repairconf: Failed to retrieve the group public data. CSS ret code [20]
2022-01-04 12:58:15.517: [  OCRRAW][859629376]proprioo: Failed to auto repair the OCR configuration.
2022-01-04 12:58:15.517: [  OCRRAW][859629376]proprinit: Could not open raw device
2022-01-04 12:58:15.517: [  OCRASM][859629376]proprasmcl: asmhandle is NULL
2022-01-04 12:58:15.519: [  OCRAPI][859629376]a_init:16!: Backend init unsuccessful : [26]
2022-01-04 12:58:15.519: [  CRSOCR][859629376] OCR context init failure.  Error: PROC-26: Error while accessing the physical storage

2022-01-04 12:58:15.519: [    CRSD][859629376] Created alert : (:CRSD00111:) :  Could not init OCR, error: PROC-26: Error while accessing the physical storage

2022-01-04 12:58:15.519: [    CRSD][859629376][PANIC] CRSD exiting: Could not init OCR, code: 26
2022-01-04 12:58:15.519: [    CRSD][859629376] Done.
```
##### 3.4.4.添加listener---grid用户
#上面错误解决后，发现集群缺少listener

```
[grid@rac1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.asm
               ONLINE  ONLINE       rac1                 Started             
               ONLINE  ONLINE       rac2                 Started             
ora.gsd
               OFFLINE OFFLINE      rac1                                     
               OFFLINE OFFLINE      rac2                                     
ora.net1.network
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.ons
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac2                                     
ora.cvu
      1        ONLINE  ONLINE       rac2                                     
ora.oc4j
      1        ONLINE  ONLINE       rac1                                     
ora.rac1.vip
      1        ONLINE  ONLINE       rac1                                     
ora.rac2.vip
      1        ONLINE  ONLINE       rac2                                     
ora.scan1.vip
      1        ONLINE  ONLINE       rac2                             
      
[root@rac2 ~]# lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 04-JAN-2022 16:54:49

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 111: Connection refused
[root@rac2 ~]# su - grid
Last login: Tue Jan  4 14:06:57 CST 2022 on pts/0
[grid@rac2 ~]$ srvctl config listener
PRCN-2044 : No listener exists

[root@rac1 grid]# ls -la /u01/app/11.2.0/grid/network/admin/
total 8
drwxr-xr-x  3 grid oinstall  59 Mar 18 09:53 .
drwxr-xr-x 11 grid oinstall 157 Mar 18 09:41 ..
-rw-r--r--  1 grid oinstall 184 Mar 18 09:53 listener.ora
drwxr-xr-x  2 grid oinstall  64 Mar 18 09:40 samples
-rw-r--r--  1 grid oinstall 381 Dec 17  2012 shrept.lst
[root@rac1 grid]# cat /u01/app/11.2.0/grid/network/admin/listener.ora
LISTENER_SCAN1=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER_SCAN1))))                # line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER_SCAN1=ON                # line added by Agent
[root@rac1 grid]#


[root@rac2 ~]# ls -la /u01/app/11.2.0/grid/network/admin/
total 4
drwxr-xr-x  3 grid oinstall  51 Mar 18 09:42 .
drwxr-xr-x 11 grid oinstall 157 Mar 18 09:42 ..
drwxr-xr-x  2 grid oinstall  80 Mar 18 09:42 samples
-rw-r--r--  1 grid oinstall 381 Mar 18 09:42 shrept.lst

[root@rac2 ~]# srvctl config listener
PRCN-2044 : No listener exists

```
#尝试添加
```bash
[grid@rac2 ~]$ srvctl add listener -l listener -p 1521 
PRCN-2061 : Failed to add listener ora.LISTENER.lsnr
PRCN-2065 : Port(s) 1521 are not available on the nodes given
PRCN-2067 : Port 1521 is not available across node(s) "rac1-vip"

#先停止rac1-vip和rac2-vip
crsctl stop resource ora.rac1.vip
crsctl stop resource ora.rac1.vip
#检查是否有listener的残留进程
ps -ef|grep tns
#如果有以下类似进程，需kill掉，不然会存在Not All Endpoints Registered的问题
grid     17769     1  0 18:53 ?        00:00:00 /u01/app/11.2.0/grid/bin/tnslsnr LISTENER -inherit

kill -9 17769

#开始添加监听
srvctl add listener -l listener
srvctl config listener
srvctl start listener -l listener

crsctl status resource -t
```
#如果还存在问题，可以尝试重启集群解决
```bash
crsctl stop cluster -all

crsctl start cluster -all
```
#日志
```
[grid@rac2 admin]$ srvctl stop scan_listener

[grid@rac2 admin]$ srvctl add listener -l listener
PRCN-2061 : Failed to add listener ora.LISTENER.lsnr
PRCN-2065 : Port(s) 1521 are not available on the nodes given
PRCN-2067 : Port 1521 is not available across node(s) "rac1-vip"

[grid@rac2 admin]$ crsctl stop resource ora.rac1.vip
CRS-2673: Attempting to stop 'ora.rac1.vip' on 'rac1'
CRS-2677: Stop of 'ora.rac1.vip' on 'rac1' succeeded

[grid@rac2 admin]$ crsctl stop resource ora.rac2.vip
CRS-2673: Attempting to stop 'ora.rac2.vip' on 'rac2'
CRS-2677: Stop of 'ora.rac2.vip' on 'rac2' succeeded

[grid@rac2 admin]$ srvctl add listener -l listener

[grid@rac2 admin]$ srvctl config listener
Name: LISTENER
Network: 1, Owner: grid
Home: <CRS home>
End points: TCP:1521

[grid@rac2 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------                              
ora.LISTENER.lsnr
               OFFLINE OFFLINE      rac1                                     
               OFFLINE OFFLINE      rac2                                     
ora.OCR.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.asm
               ONLINE  ONLINE       rac1                 Started             
               ONLINE  ONLINE       rac2                 Started             
ora.gsd
               OFFLINE OFFLINE      rac1                                     
               OFFLINE OFFLINE      rac2                                     
ora.net1.network
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.ons
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        OFFLINE OFFLINE                                                   
ora.cvu
      1        ONLINE  ONLINE       rac2                                     
ora.oc4j
      1        ONLINE  ONLINE       rac1                                     
ora.rac1.vip
      1        OFFLINE OFFLINE                                                   
ora.rac2.vip
      1        OFFLINE OFFLINE                                                   
ora.scan1.vip
      1        ONLINE  ONLINE       rac2                                     
[grid@rac2 admin]$ srvctl start listener -l listener

[grid@rac2 admin]$ crsctl start resource ora.rac2.vip
CRS-5702: Resource 'ora.rac2.vip' is already running on 'rac2'
CRS-4000: Command Start failed, or completed with errors.

[grid@rac2 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE rac1                 Not All Endpoints Registered           
               ONLINE  ONLINE       rac2                                     
ora.OCR.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.asm
               ONLINE  ONLINE       rac1                 Started             
               ONLINE  ONLINE       rac2                 Started             
ora.gsd
               OFFLINE OFFLINE      rac1                                     
               OFFLINE OFFLINE      rac2                                     
ora.net1.network
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.ons
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        OFFLINE OFFLINE                                                   
ora.cvu
      1        ONLINE  ONLINE       rac2                                     
ora.oc4j
      1        ONLINE  ONLINE       rac1                                     
ora.rac1.vip
      1        ONLINE  ONLINE       rac1                                     
ora.rac2.vip
      1        ONLINE  ONLINE       rac2                                     
ora.scan1.vip
      1        ONLINE  ONLINE       rac2                                     
[grid@rac2 admin]$ crsctl status resource ora.LISTENER_SCAN1.lsnr
NAME=ora.LISTENER_SCAN1.lsnr
TYPE=ora.scan_listener.type
TARGET=OFFLINE
STATE=OFFLINE

[grid@rac2 admin]$ srvctl start scan_listener

[grid@rac2 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE rac1                 Not All Endpoints Registered           
               ONLINE  ONLINE       rac2                                     
ora.OCR.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.asm
               ONLINE  ONLINE       rac1                 Started             
               ONLINE  ONLINE       rac2                 Started             
ora.gsd
               OFFLINE OFFLINE      rac1                                     
               OFFLINE OFFLINE      rac2                                     
ora.net1.network
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.ons
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  INTERMEDIATE rac1                 Not All Endpoints R 
                                                             egistered           
ora.cvu
      1        ONLINE  ONLINE       rac2                                     
ora.oc4j
      1        ONLINE  ONLINE       rac1                                     
ora.rac1.vip
      1        ONLINE  ONLINE       rac1                                     
ora.rac2.vip
      1        ONLINE  ONLINE       rac2                                     
ora.scan1.vip
      1        ONLINE  ONLINE       rac1                                     
[grid@rac2 admin]$ srvctl start scan_listener
PRCC-1014 : LISTENER_SCAN1 was already running
PRCR-1004 : Resource ora.LISTENER_SCAN1.lsnr is already running
PRCR-1079 : Failed to start resource ora.LISTENER_SCAN1.lsnr
CRS-5702: Resource 'ora.LISTENER_SCAN1.lsnr' is already running on 'rac1'

[grid@rac2 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE rac1                 Not All Endpoints R 
                                                             egistered           
               ONLINE  ONLINE       rac2                                     
ora.OCR.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.asm
               ONLINE  ONLINE       rac1                 Started             
               ONLINE  ONLINE       rac2                 Started             
ora.gsd
               OFFLINE OFFLINE      rac1                                     
               OFFLINE OFFLINE      rac2                                     
ora.net1.network
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.ons
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  INTERMEDIATE rac1                 Not All Endpoints R 
                                                             egistered           
ora.cvu
      1        ONLINE  ONLINE       rac2                                     
ora.oc4j
      1        ONLINE  ONLINE       rac1                                     
ora.rac1.vip
      1        ONLINE  ONLINE       rac1                                     
ora.rac2.vip
      1        ONLINE  ONLINE       rac2                                     
ora.scan1.vip
      1        ONLINE  ONLINE       rac1                                     

[root@rac2 ~]# . oraenv
ORACLE_SID = [+ASM2] ? 
The Oracle base remains unchanged with value /u01/app/grid
[root@rac2 ~]# crsctl stop cluster -all
CRS-2673: Attempting to stop 'ora.crsd' on 'rac2'
CRS-2673: Attempting to stop 'ora.crsd' on 'rac1'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'rac1'
CRS-2673: Attempting to stop 'ora.oc4j' on 'rac1'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'rac1'
CRS-2673: Attempting to stop 'ora.LISTENER_SCAN1.lsnr' on 'rac1'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'rac1'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'rac1'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'rac1'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'rac2'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'rac2'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'rac2'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'rac2'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'rac2'
CRS-2673: Attempting to stop 'ora.cvu' on 'rac2'
CRS-2677: Stop of 'ora.cvu' on 'rac2' succeeded
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.rac1.vip' on 'rac1'
CRS-2677: Stop of 'ora.LISTENER_SCAN1.lsnr' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.scan1.vip' on 'rac1'
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.rac2.vip' on 'rac2'
CRS-2677: Stop of 'ora.DATA.dg' on 'rac2' succeeded
CRS-2677: Stop of 'ora.DATA.dg' on 'rac1' succeeded
CRS-2677: Stop of 'ora.FRA.dg' on 'rac1' succeeded
CRS-2677: Stop of 'ora.FRA.dg' on 'rac2' succeeded
CRS-2677: Stop of 'ora.rac2.vip' on 'rac2' succeeded
CRS-2677: Stop of 'ora.rac1.vip' on 'rac1' succeeded
CRS-2677: Stop of 'ora.scan1.vip' on 'rac1' succeeded
CRS-2677: Stop of 'ora.oc4j' on 'rac1' succeeded
CRS-2677: Stop of 'ora.OCR.dg' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'rac1'
CRS-2677: Stop of 'ora.OCR.dg' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'rac2'
CRS-2677: Stop of 'ora.asm' on 'rac1' succeeded
CRS-2677: Stop of 'ora.asm' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.ons' on 'rac2'
CRS-2677: Stop of 'ora.ons' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'rac2'
CRS-2677: Stop of 'ora.net1.network' on 'rac2' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'rac2' has completed
CRS-2673: Attempting to stop 'ora.ons' on 'rac1'
CRS-2677: Stop of 'ora.ons' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'rac1'
CRS-2677: Stop of 'ora.net1.network' on 'rac1' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'rac1' has completed
CRS-2677: Stop of 'ora.crsd' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'rac2'
CRS-2673: Attempting to stop 'ora.evmd' on 'rac2'
CRS-2673: Attempting to stop 'ora.asm' on 'rac2'
CRS-2677: Stop of 'ora.crsd' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'rac1'
CRS-2673: Attempting to stop 'ora.evmd' on 'rac1'
CRS-2673: Attempting to stop 'ora.asm' on 'rac1'
CRS-2677: Stop of 'ora.evmd' on 'rac2' succeeded
CRS-2677: Stop of 'ora.evmd' on 'rac1' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'rac2' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'rac1' succeeded
CRS-2677: Stop of 'ora.asm' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'rac2'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'rac2'
CRS-2677: Stop of 'ora.cssd' on 'rac2' succeeded
CRS-2677: Stop of 'ora.asm' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'rac1'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'rac1'
CRS-2677: Stop of 'ora.cssd' on 'rac1' succeeded
[root@rac2 ~]# 

```

##### 3.4.5.节点二执行root.sh时网络中断，需要重新执行root.sh

```bash
[root@rac2 ~]# /u01/app/11.2.0/grid/crs/install/rootcrs.pl -deconfig -force -verbose
Can't locate Env.pm in @INC (@INC contains: /usr/local/lib64/perl5 /usr/local/share/perl5 /usr/lib64/perl5/vendor_perl /usr/share/perl5/vendor_perl /usr/lib64/perl5 /usr/share/perl5 . /u01/app/11.2.0/grid/crs/install) at /u01/app/11.2.0/grid/crs/install/crsconfig_lib.pm line 703.
BEGIN failed--compilation aborted at /u01/app/11.2.0/grid/crs/install/crsconfig_lib.pm line 703.
Compilation failed in require at /u01/app/11.2.0/grid/crs/install/rootcrs.pl line 305.
BEGIN failed--compilation aborted at /u01/app/11.2.0/grid/crs/install/rootcrs.pl line 305.
[root@rac2 ~]# . oraenv
ORACLE_SID = [+ASM2] ?
The Oracle base remains unchanged with value /u01/app/grid
[root@rac2 ~]# cd /u01/app/11.2.0/grid/perl/bin/
[root@rac2 bin]# ls
a2p          cpanp           enc2xs     ora_explain  piconv     pod2usage   ptar
c2ph         cpanp-run-perl  find2perl  perl         pl2pm      podchecker  ptardiff
config_data  dbilogstrip     h2ph       perl5.10.0   pod2html   podselect   s2p
corelist     dbiprof         h2xs       perlbug      pod2latex  prove       shasum
cpan         dbiproxy        instmodsh  perldoc      pod2man    psed        splain
cpan2dist    dprofpp         libnetcfg  perlivp      pod2text   pstruct     xsubpp
[root@rac2 bin]# ./perl /u01/app/11.2.0/grid/crs/install/rootcrs.pl -deconfig -force -verbose
Using configuration parameter file: /u01/app/11.2.0/grid/crs/install/crsconfig_params
PRCR-1119 : Failed to look up CRS resources of ora.cluster_vip_net1.type type
PRCR-1068 : Failed to query resources
Cannot communicate with crsd
PRCR-1070 : Failed to check if resource ora.gsd is registered
Cannot communicate with crsd
PRCR-1070 : Failed to check if resource ora.ons is registered
Cannot communicate with crsd


CRS-4544: Unable to connect to OHAS
CRS-4000: Command Stop failed, or completed with errors.
Successfully deconfigured Oracle clusterware stack on this node
[root@rac2 bin]# /u01/app/11.2.0/grid/root.sh
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
Adding Clusterware entries to inittab
CRS-4402: The CSS daemon was started in exclusive mode but found an active CSS daemon on node rac1, number 1, and is terminating
An active cluster was found during exclusive startup, restarting to join the cluster


```



##### 3.4.6.节点二缺少vip---root账户添加vip

```bash
#执行到这里卡住了，然后检查rac2没有vip资源

#检查rootcrs_rac2.log
[root@rac2 ~]# cd /u01/app/11.2.0/grid/cfgtoollogs/crsconfig
[root@rac2 crsconfig]# ll
total 80
-rwxrwxr-x 1 grid oinstall 79845 Mar 18 10:00 rootcrs_rac2.log
[root@rac2 crsconfig]# tail -f rootcrs_rac2.log
2025-03-18 10:00:23: Sync the checkpoint file '/u01/app/grid/Clusterware/ckptGridHA_rac2.xml'
2025-03-18 10:00:23: Sync '/u01/app/grid/Clusterware/ckptGridHA_rac2.xml' to the physical disk
2025-03-18 10:00:23: Configuring node
2025-03-18 10:00:23: adding nodeapps...
2025-03-18 10:00:23: upgrade_opt=
2025-03-18 10:00:23: nodevip=rac2-vip/255.255.255.128/eth0
2025-03-18 10:00:23: DHCP_flag=0
2025-03-18 10:00:23: nodes_to_add=rac2
2025-03-18 10:00:23: add nodeapps for static IP
2025-03-18 10:00:23: Running srvctl config nodeapps to detect if VIP exists
#卡在此处


#此时查看altertrac2.log

[root@rac2 ~]# cd /u01/app/11.2.0/grid/log/rac2
[root@rac2 rac2]# tail -f alertrac2.log
2025-03-18 09:59:29.545:
[ctssd(18051)]CRS-2408:The clock on host rac2 has been updated by the Cluster Time Synchronization Service to be synchronous with the mean cluster time.
2025-03-18 09:59:55.571:
[crsd(18264)]CRS-1012:The OCR service started on node rac2.
2025-03-18 09:59:55.579:
[evmd(18284)]CRS-1401:EVMD started on node rac2.
2025-03-18 09:59:56.551:
[crsd(18264)]CRS-1201:CRSD started on node rac2.
2025-03-18 10:01:28.185:
[/u01/app/11.2.0/grid/bin/oraagent.bin(18416)]CRS-5818:Aborted command 'check' for resource 'ora.asm'. Details at (:CRSAGF00113:) {2:15798:2} in /u01/app/11.2.0/grid/log/rac2/agent/crsd/oraagent_grid/oraagent_grid.log.

#查看oraagent_grid.log
[root@rac2 rac2]# tail -f /u01/app/11.2.0/grid/log/rac2/agent/crsd/oraagent_grid/oraagent_grid.log
2025-03-18 10:18:28.094: [    AGFW][491316992]{2:15798:2} Agent received the message: AGENT_HB[Engine] ID 12293:525
2025-03-18 10:18:58.104: [    AGFW][491316992]{2:15798:2} Agent received the message: AGENT_HB[Engine] ID 12293:532
2025-03-18 10:18:58.184: [ora.asm][495519488]{2:15798:2} [check] CrsCmd::ClscrsCmdData::stat entity 1 statflag 33 useFilter 0
2025-03-18 10:18:58.200: [ora.asm][495519488]{2:15798:2} [check] AsmProxy StartDependeeRes = ora.LISTENER.lsnr
2025-03-18 10:18:58.200: [ora.asm][495519488]{2:15798:2} [check] AsmProxyAgent::check clsagfw_res_status 0
2025-03-18 10:19:00.621: [ora.ons][495519488]{2:15798:2} [check] getOracleHomeAttrib: oracle_home = /u01/app/11.2.0/grid
2025-03-18 10:19:00.621: [ora.ons][495519488]{2:15798:2} [check] Utils:execCmd action = 3 flags = 6 ohome = /u01/app/11.2.0/grid/opmn/ cmdname = onsctli. 
2025-03-18 10:19:00.722: [ora.ons][495519488]{2:15798:2} [check] (:CLSN00010:)ons is running ...
2025-03-18 10:19:00.722: [ora.ons][495519488]{2:15798:2} [check] (:CLSN00010:)
2025-03-18 10:19:00.722: [ora.ons][495519488]{2:15798:2} [check] execCmd ret = 0
2025-03-18 10:19:05.356: [ USRTHRD][3749689088]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 1 useFilter 0
2025-03-18 10:19:05.378: [ USRTHRD][3749689088]{2:15798:2} checkCrsStat 2 CLSCRS_STAT ret: 200
2025-03-18 10:19:05.378: [ USRTHRD][3749689088]{2:15798:2} checkCrsStat 2 clscrs_res_get_op_status CLSCRS_STAT status 210 err_msg CRS-0210: Could not find resource 'ora.rac2.vip'.
2025-03-18 10:19:05.378: [ USRTHRD][3749689088]{2:15798:2} Warning, could not get the node VIP address
2025-03-18 10:19:05.378: [ USRTHRD][3749689088]{2:15798:2} AsmCommonAgent: Getting local vip failed.



[grid@rac1 rac1]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[grid@rac1 rac1]$

[grid@rac1 rac1]$ crsctl status resource ora.rac2.vip
CRS-2613: Could not find resource 'ora.rac2.vip'.
[grid@rac1 rac1]$

[root@rac2 rac2]# crsctl stat res ora.rac1.vip -v
NAME=ora.rac1.vip
TYPE=ora.cluster_vip_net1.type
LAST_SERVER=rac1
STATE=ONLINE on rac1
TARGET=ONLINE
CARDINALITY_ID=1
CREATION_SEED=2
RESTART_COUNT=0
FAILURE_COUNT=0
FAILURE_HISTORY=
ID=ora.rac1.vip 1 1
INCARNATION=1
LAST_RESTART=03/18/2025 09:53:32
LAST_STATE_CHANGE=03/18/2025 09:53:32
STATE_DETAILS=
INTERNAL_STATE=STABLE

[root@rac1 conf]# srvctl config nodeapps -n rac1
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[root@rac1 conf]# srvctl config nodeapps -n rac2
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[root@rac1 conf]#

#rac1的root账户下添加rac2的vip资源

#查看rac1的vip资源
[grid@rac1 rac1]$ srvctl config vip  -n rac1
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
[grid@rac1 rac1]$ srvctl config vip  -n rac2
PRKO-2310 : VIP does not exist on node rac2.

[root@rac1 conf]# srvctl config nodeapps -n rac1
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[root@rac1 conf]# srvctl config nodeapps -n rac2
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016

[root@rac1 conf]# srvctl status nodeapps -n rac1
VIP rac1-vip is enabled
VIP rac1-vip is running on node: rac1
Network is enabled
Network is running on node: rac1
GSD is disabled
GSD is not running on node: rac1
ONS is enabled
ONS daemon is running on node: rac1
[root@rac1 conf]# srvctl status nodeapps -n rac2
Network is enabled
Network is running on node: rac2
GSD is disabled
GSD is not running on node: rac2
ONS is enabled
ONS daemon is running on node: rac2
PRKO-2165 : VIP does not exist on node(s) : rac2

[root@rac1 conf]#


#如果使用grid账户，会报权限不足
[grid@rac1 ~]$ srvctl add vip -n rac2 -k 1 -A rac2-vip/255.255.255.128/eth0
PRCN-2018 : Current user grid is not a privileged user


#/u01/app/11.2.0/grid/bin/srvctl add nodeapps -n rac2 -A "rac2-vip/255.255.255.128/eth0

[root@rac1 ~]# srvctl add vip -n rac2 -k 1 -A rac2-vip/255.255.255.128/eth0
[root@rac1 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        OFFLINE OFFLINE
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[root@rac1 ~]# srvctl start vip -n rac2
[root@rac1 ~]# srvctl status vip -n rac2
VIP rac2-vip is enabled
VIP rac2-vip is running on node: rac2
[root@rac1 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1

[root@rac1 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:2a:d3:93 brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.52/25 brd 192.168.10.127 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet 192.168.10.54/25 brd 192.168.10.127 scope global secondary eth0:1
       valid_lft forever preferred_lft forever
    inet 192.168.10.56/25 brd 192.168.10.127 scope global secondary eth0:2
       valid_lft forever preferred_lft forever
    inet6 fe80::ee9e:23bf:9ba8:efe9/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:cf:22:29 brd ff:ff:ff:ff:ff:ff
    inet 10.10.20.2/24 brd 10.10.20.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet 169.254.228.87/16 brd 169.254.255.255 scope global eth1:1
       valid_lft forever preferred_lft forever
    inet6 fe80::647c:fdb7:c014:2f74/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
5: virbr0-nic: <BROADCAST,MULTICAST> mtu 1500 qdisc pfifo_fast state DOWN group default qlen 1000
    link/ether 52:54:00:82:0f:eb brd ff:ff:ff:ff:ff:ff
[root@rac1 ~]# su - grid
Last login: Fri Mar 14 10:51:42 CST 2025 from 192.168.10.221 on pts/2
[grid@rac1 ~]$ ssh rac2
Last login: Fri Mar 14 14:27:20 2025
[grid@rac2 ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:a8:03:b9 brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.53/25 brd 192.168.10.127 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet 192.168.10.55/25 brd 192.168.10.127 scope global secondary eth0:1
       valid_lft forever preferred_lft forever
    inet6 fe80::ee9e:23bf:9ba8:efe9/64 scope link tentative noprefixroute dadfailed
       valid_lft forever preferred_lft forever
    inet6 fe80::cd0b:276a:7f5b:bbe3/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:6e:1c:3a brd ff:ff:ff:ff:ff:ff
    inet 10.10.20.3/24 brd 10.10.20.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet 169.254.174.106/16 brd 169.254.255.255 scope global eth1:1
       valid_lft forever preferred_lft forever
    inet6 fe80::647c:fdb7:c014:2f74/64 scope link tentative noprefixroute dadfailed
       valid_lft forever preferred_lft forever
    inet6 fe80::4f2:af7f:38b2:8b3f/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
[grid@rac2 ~]$ exit
logout
Connection to rac2 closed.
[grid@rac1 ~]$ crsctl check cluster -all
**************************************************************
rac1:
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
**************************************************************
rac2:
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
**************************************************************
[grid@rac1 ~]$ srvctl config nodeapps -n rac2
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac2-vip/192.168.10.55/192.168.10.0/255.255.255.128/eth0, hosting node rac2
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[grid@rac1 ~]$ srvctl config nodeapps -n rac1
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016

[grid@rac1 ~]$ srvctl config nodeapps
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
VIP exists: /rac2-vip/192.168.10.55/192.168.10.0/255.255.255.128/eth0, hosting node rac2
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[grid@rac1 ~]$


[grid@rac1 ~]$ srvctl config vip -n rac2
VIP exists: /rac2-vip/192.168.10.55/192.168.10.0/255.255.255.128/eth0, hosting node rac2
[grid@rac1 ~]$ cat /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="eth0"
UUID=
DEVICE="eth0"
ONBOOT="yes"
IPADDR="192.168.10.52"
PREFIX="25"
GATEWAY="192.168.10.1"
DNS1=""210.38.208.50""
DNS2="210.38.208.55"
IPV6_PRIVACY="no"
[grid@rac1 ~]$


#此时报错缺少ora.LISTENER.lsnr
#处理参考3.4.4
#查看oraagent_grid.log
[root@rac2 rac2]# tail -f /u01/app/11.2.0/grid/log/rac2/agent/crsd/oraagent_grid/oraagent_grid.log
2025-03-18 12:24:58.116: [    AGFW][491316992]{2:15798:2} Agent received the message: AGENT_HB[Engine] ID 12293:2286
2025-03-18 12:24:58.197: [ora.OCR.dg][486020864]{2:15798:2} [check] CrsCmd::ClscrsCmdData::stat entity 1 statflag 33 useFilter 0
2025-03-18 12:24:58.212: [ora.OCR.dg][486020864]{2:15798:2} [check] DgpAgent::runCheck: asm stat asmRet 0
2025-03-18 12:24:58.213: [ora.OCR.dg][486020864]{2:15798:2} [check] DgpAgent::getConnxn connected
2025-03-18 12:24:58.213: [ora.OCR.dg][486020864]{2:15798:2} [check] DgpAgent::queryDgStatus dgName OCR ret 0
2025-03-18 12:24:58.214: [ora.asm][486020864]{2:15798:2} [check] CrsCmd::ClscrsCmdData::stat entity 1 statflag 33 useFilter 0
2025-03-18 12:24:58.233: [ora.asm][486020864]{2:15798:2} [check] AsmProxy StartDependeeRes = ora.LISTENER.lsnr
2025-03-18 12:24:58.233: [ USRTHRD][486020864]{2:15798:2} Thread:ASM DedicatedThreadstart {
2025-03-18 12:24:58.233: [ USRTHRD][486020864]{2:15798:2} Thread:ASM DedicatedThreadstart }
2025-03-18 12:24:58.233: [ora.asm][486020864]{2:15798:2} [check] AsmProxyAgent::check clsagfw_res_status 0
2025-03-18 12:24:58.234: [ USRTHRD][3697157888]{2:15798:2} ASM Dedicated Thread {
2025-03-18 12:24:58.234: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 1 useFilter 0
2025-03-18 12:24:58.256: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 1 useFilter 0
2025-03-18 12:24:58.277: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 1 useFilter 0
2025-03-18 12:24:58.299: [ USRTHRD][3697157888]{2:15798:2} Local VIP address is rac2-vip
2025-03-18 12:24:58.299: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 32 useFilter 0
2025-03-18 12:24:58.321: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 CLSCRS_STAT ret: 200
2025-03-18 12:24:58.321: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 clscrs_res_get_op_status CLSCRS_STAT status 210 err_msg CRS-0210: Could not find resource 'ora.LISTENER.lsnr'.
2025-03-18 12:24:58.321: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 33 useFilter 0
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 CLSCRS_STAT ret: 200
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 clscrs_res_get_op_status CLSCRS_STAT status 210 err_msg CRS-0210: Could not find resource 'ora.LISTENER.lsnr'.
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} AsmCommonAgent::setLocalListener cls::Exception CRS-0210: Could not find resource 'ora.LISTENER.lsnr'.
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} ASM Dedicated Thread }
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} Thread:ASM DedicatedThreadisRunning is reset to false here
2025-03-18 12:25:00.624: [ora.ons][493418240]{2:15798:2} [check] getOracleHomeAttrib: oracle_home = /u01/app/11.2.0/grid
2025-03-18 12:25:00.625: [ora.ons][493418240]{2:15798:2} [check] Utils:execCmd action = 3 flags = 6 ohome = /u01/app/11.2.0/grid/opmn/ cmdname = onsctli.
2025-03-18 12:25:00.726: [ora.ons][493418240]{2:15798:2} [check] (:CLSN00010:)ons is running ...
2025-03-18 12:25:00.726: [ora.ons][493418240]{2:15798:2} [check] (:CLSN00010:)
2025-03-18 12:25:00.726: [ora.ons][493418240]{2:15798:2} [check] execCmd ret = 0




[root@rac1 grid]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[root@rac1 grid]# lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 18-MAR-2025 12:26:14

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 111: Connection refused
[root@rac1 grid]#

[root@rac1 grid]# srvctl config listener
PRCN-2044 : No listener exists

```



##### 3.4.7.节点二添加vip后，继续报错缺少listener，需要grid账户添加listener并启动

```bash
#此时报错缺少ora.LISTENER.lsnr
#处理参考3.4.4
#查看oraagent_grid.log
[root@rac2 rac2]# tail -f /u01/app/11.2.0/grid/log/rac2/agent/crsd/oraagent_grid/oraagent_grid.log
2025-03-18 12:24:58.116: [    AGFW][491316992]{2:15798:2} Agent received the message: AGENT_HB[Engine] ID 12293:2286
2025-03-18 12:24:58.197: [ora.OCR.dg][486020864]{2:15798:2} [check] CrsCmd::ClscrsCmdData::stat entity 1 statflag 33 useFilter 0
2025-03-18 12:24:58.212: [ora.OCR.dg][486020864]{2:15798:2} [check] DgpAgent::runCheck: asm stat asmRet 0
2025-03-18 12:24:58.213: [ora.OCR.dg][486020864]{2:15798:2} [check] DgpAgent::getConnxn connected
2025-03-18 12:24:58.213: [ora.OCR.dg][486020864]{2:15798:2} [check] DgpAgent::queryDgStatus dgName OCR ret 0
2025-03-18 12:24:58.214: [ora.asm][486020864]{2:15798:2} [check] CrsCmd::ClscrsCmdData::stat entity 1 statflag 33 useFilter 0
2025-03-18 12:24:58.233: [ora.asm][486020864]{2:15798:2} [check] AsmProxy StartDependeeRes = ora.LISTENER.lsnr
2025-03-18 12:24:58.233: [ USRTHRD][486020864]{2:15798:2} Thread:ASM DedicatedThreadstart {
2025-03-18 12:24:58.233: [ USRTHRD][486020864]{2:15798:2} Thread:ASM DedicatedThreadstart }
2025-03-18 12:24:58.233: [ora.asm][486020864]{2:15798:2} [check] AsmProxyAgent::check clsagfw_res_status 0
2025-03-18 12:24:58.234: [ USRTHRD][3697157888]{2:15798:2} ASM Dedicated Thread {
2025-03-18 12:24:58.234: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 1 useFilter 0
2025-03-18 12:24:58.256: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 1 useFilter 0
2025-03-18 12:24:58.277: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 1 useFilter 0
2025-03-18 12:24:58.299: [ USRTHRD][3697157888]{2:15798:2} Local VIP address is rac2-vip
2025-03-18 12:24:58.299: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 32 useFilter 0
2025-03-18 12:24:58.321: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 CLSCRS_STAT ret: 200
2025-03-18 12:24:58.321: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 clscrs_res_get_op_status CLSCRS_STAT status 210 err_msg CRS-0210: Could not find resource 'ora.LISTENER.lsnr'.
2025-03-18 12:24:58.321: [ USRTHRD][3697157888]{2:15798:2} CrsCmd::ClscrsCmdData::stat entity 1 statflag 33 useFilter 0
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 CLSCRS_STAT ret: 200
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} checkCrsStat 2 clscrs_res_get_op_status CLSCRS_STAT status 210 err_msg CRS-0210: Could not find resource 'ora.LISTENER.lsnr'.
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} AsmCommonAgent::setLocalListener cls::Exception CRS-0210: Could not find resource 'ora.LISTENER.lsnr'.
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} ASM Dedicated Thread }
2025-03-18 12:24:58.342: [ USRTHRD][3697157888]{2:15798:2} Thread:ASM DedicatedThreadisRunning is reset to false here
2025-03-18 12:25:00.624: [ora.ons][493418240]{2:15798:2} [check] getOracleHomeAttrib: oracle_home = /u01/app/11.2.0/grid
2025-03-18 12:25:00.625: [ora.ons][493418240]{2:15798:2} [check] Utils:execCmd action = 3 flags = 6 ohome = /u01/app/11.2.0/grid/opmn/ cmdname = onsctli.
2025-03-18 12:25:00.726: [ora.ons][493418240]{2:15798:2} [check] (:CLSN00010:)ons is running ...
2025-03-18 12:25:00.726: [ora.ons][493418240]{2:15798:2} [check] (:CLSN00010:)
2025-03-18 12:25:00.726: [ora.ons][493418240]{2:15798:2} [check] execCmd ret = 0




[root@rac1 grid]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[root@rac1 grid]# lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 18-MAR-2025 12:26:14

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 111: Connection refused
[root@rac1 grid]#

[root@rac1 grid]# srvctl config listener
PRCN-2044 : No listener exists

```



#grid账户添加listener

#如果root账户添加listener，会造成后面dbca时没有权限访问Listener

```bash
#一台机器上添加一遍即可
#根据后面的经验，需要grid账户添加
#如果root账户添加后，后面dbca会报错：oracle用户没有访问listener的权限
# srvctl add listener -l listener -p 1521 

[root@rac1 grid]# srvctl add listener -n rac1
Warning:-n option has been deprecated and will be ignored.
[root@rac1 grid]# srvctl add listener -n rac2
Warning:-n option has been deprecated and will be ignored.
PRCN-3004 : Listener LISTENER already exists

[root@rac1 grid]# srvctl config listener
Name: LISTENER
Network: 1, Owner: root
Home: <CRS home>
End points: TCP:1521
[root@rac1 grid]# srvctl config listener -n rac1
Warning:-n option has been deprecated and will be ignored.
Name: LISTENER
Network: 1, Owner: root
Home: <CRS home>
End points: TCP:1521
[root@rac1 grid]# srvctl config listener -n rac2
Warning:-n option has been deprecated and will be ignored.
Name: LISTENER
Network: 1, Owner: root
Home: <CRS home>
End points: TCP:1521
[root@rac1 grid]# srvctl status listener
Listener LISTENER is enabled
Listener LISTENER is not running

[root@rac2 ~]# srvctl config listener
Name: LISTENER
Network: 1, Owner: root
Home: <CRS home>
End points: TCP:1521
[root@rac2 ~]#
[root@rac2 ~]# srvctl status listener
Listener LISTENER is enabled
Listener LISTENER is not running
[root@rac2 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[root@rac2 ~]#


[root@rac2 ~]# srvctl start listener
[root@rac2 ~]# srvctl status listener
Listener LISTENER is enabled
Listener LISTENER is running on node(s): rac2,rac1
[root@rac2 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[root@rac2 ~]#


[root@rac1 grid]# cat /u01/app/11.2.0/grid/network/admin/listener.ora
LISTENER=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER))))            # line added by Agent
LISTENER_SCAN1=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER_SCAN1))))                # line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER_SCAN1=ON                # line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER=ON              # line added by Agent
[root@rac1 grid]#

[root@rac2 rac2]# cat /u01/app/11.2.0/grid/network/admin/listener.ora
LISTENER=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER))))            # line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER=ON              # line added by Agent
[root@rac2 rac2]#


[root@rac1 grid]# lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 18-MAR-2025 13:09:03

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 11.2.0.4.0 - Production
Start Date                18-MAR-2025 12:58:27
Uptime                    0 days 0 hr. 10 min. 36 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/11.2.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/11.2.0/grid/log/diag/tnslsnr/rac1/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.10.52)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.10.54)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
The command completed successfully
[root@rac1 grid]#


[root@rac2 rac2]# lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 18-MAR-2025 13:08:40

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 11.2.0.4.0 - Production
Start Date                18-MAR-2025 12:58:27
Uptime                    0 days 0 hr. 10 min. 13 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/11.2.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/11.2.0/grid/log/diag/tnslsnr/rac2/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.10.53)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.10.55)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM2", status READY, has 1 handler(s) for this service...
The command completed successfully
[root@rac2 rac2]#

```

#添加vip前和添加vip/listener之后资源对比

```bash
[root@rac2 conf]# crs_stat -t
Name           Type           Target    State     Host
------------------------------------------------------------
ora....N1.lsnr ora....er.type ONLINE    ONLINE    rac1
ora.OCR.dg     ora....up.type ONLINE    ONLINE    rac1
ora.asm        ora.asm.type   ONLINE    ONLINE    rac1
ora.cvu        ora.cvu.type   ONLINE    ONLINE    rac1
ora.gsd        ora.gsd.type   OFFLINE   OFFLINE
ora....network ora....rk.type ONLINE    ONLINE    rac1
ora.oc4j       ora.oc4j.type  ONLINE    ONLINE    rac1
ora.ons        ora.ons.type   ONLINE    ONLINE    rac1
ora....SM1.asm application    ONLINE    ONLINE    rac1
ora.rac1.gsd   application    OFFLINE   OFFLINE
ora.rac1.ons   application    ONLINE    ONLINE    rac1
ora.rac1.vip   ora....t1.type ONLINE    ONLINE    rac1
ora....SM2.asm application    ONLINE    ONLINE    rac2
ora.rac2.gsd   application    OFFLINE   OFFLINE
ora.rac2.ons   application    ONLINE    ONLINE    rac2
ora.scan1.vip  ora....ip.type ONLINE    ONLINE    rac1
[root@rac2 conf]#

[root@rac2 rac2]# crs_stat -t
Name           Type           Target    State     Host
------------------------------------------------------------
ora....ER.lsnr ora....er.type ONLINE    ONLINE    rac1
ora....N1.lsnr ora....er.type ONLINE    ONLINE    rac1
ora.OCR.dg     ora....up.type ONLINE    ONLINE    rac1
ora.asm        ora.asm.type   ONLINE    ONLINE    rac1
ora.cvu        ora.cvu.type   ONLINE    ONLINE    rac1
ora.gsd        ora.gsd.type   OFFLINE   OFFLINE
ora....network ora....rk.type ONLINE    ONLINE    rac1
ora.oc4j       ora.oc4j.type  ONLINE    ONLINE    rac1
ora.ons        ora.ons.type   ONLINE    ONLINE    rac1
ora....SM1.asm application    ONLINE    ONLINE    rac1
ora....C1.lsnr application    ONLINE    ONLINE    rac1
ora.rac1.gsd   application    OFFLINE   OFFLINE
ora.rac1.ons   application    ONLINE    ONLINE    rac1
ora.rac1.vip   ora....t1.type ONLINE    ONLINE    rac1
ora....SM2.asm application    ONLINE    ONLINE    rac2
ora....C2.lsnr application    ONLINE    ONLINE    rac2
ora.rac2.gsd   application    OFFLINE   OFFLINE
ora.rac2.ons   application    ONLINE    ONLINE    rac2
ora.rac2.vip   ora....t1.type ONLINE    ONLINE    rac2
ora.scan1.vip  ora....ip.type ONLINE    ONLINE    rac1
[root@rac2 rac2]#
```

##### 3.4.8.节点二再次执行root.sh卡住排查，重启rac2后恢复

```bash
#此时再次执行root.sh，会卡在Installing Trace File Analyzer
#检查安装日志发现卡在srvctl config nodeapps

[root@rac2 ~]# cd /u01/app/11.2.0/grid/cfgtoollogs/crsconfig
[root@rac2 crsconfig]# tail -f rootcrs_rac2.log
2025-03-18 14:03:20: Sync the checkpoint file '/u01/app/grid/Clusterware/ckptGridHA_rac2.xml'
2025-03-18 14:03:20: Sync '/u01/app/grid/Clusterware/ckptGridHA_rac2.xml' to the physical disk
2025-03-18 14:03:20: Configuring node
2025-03-18 14:03:20: adding nodeapps...
2025-03-18 14:03:20: upgrade_opt=
2025-03-18 14:03:20: nodevip=rac2-vip/255.255.255.128/eth0
2025-03-18 14:03:20: DHCP_flag=0
2025-03-18 14:03:20: nodes_to_add=rac2
2025-03-18 14:03:20: add nodeapps for static IP
2025-03-18 14:03:20: Running srvctl config nodeapps to detect if VIP exists

#rac1节点上执行srvctl config nodeapps 正常：
[grid@rac1 Clusterware]$ srvctl config nodeapps
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
VIP exists: /rac2-vip/192.168.10.55/192.168.10.0/255.255.255.128/eth0, hosting node rac2
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[grid@rac1 Clusterware]$


#但是在rac2上执行srvctl config nodeapps 会卡住，必须加参数-n rac1或者-n rac2才行：

[grid@rac2 Clusterware]$ srvctl config nodeapps -n rac1
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[grid@rac2 Clusterware]$ srvctl config nodeapps -n rac2
-n <node_name> option has been deprecated.
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac2-vip/192.168.10.55/192.168.10.0/255.255.255.128/eth0, hosting node rac2
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[grid@rac2 Clusterware]$ srvctl config nodeapps


#将rac2重启
[root@rac2 ~]# reboot

#将rac1的集群重启下

[root@rac1 ~]# crsctl stop crs

[root@rac1 ~]# crsctl start crs


#此时再次在rac2上检查nodeapps正常
[root@rac2 ~]# srvctl config nodeapps
Network exists: 1/192.168.10.0/255.255.255.128/eth0, type static
VIP exists: /rac1-vip/192.168.10.54/192.168.10.0/255.255.255.128/eth0, hosting node rac1
VIP exists: /rac2-vip/192.168.10.55/192.168.10.0/255.255.255.128/eth0, hosting node rac2
GSD exists
ONS exists: Local port 6100, remote port 6200, EM port 2016
[root@rac2 ~]#

#在rac2上再次执行root.sh 成功

[root@rac2 ~]# /u01/app/11.2.0/grid/root.sh
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
PRKO-2190 : VIP exists for node rac2, VIP name rac2-vip
Configure Oracle Grid Infrastructure for a Cluster ... succeeded
[root@rac2 ~]#

[root@rac2 crsconfig]# pwd
/u01/app/11.2.0/grid/cfgtoollogs/crsconfig
[root@rac2 crsconfig]# tail -f rootcrs_rac2.log
2025-03-18 14:57:07: Running as user grid: /u01/app/11.2.0/grid/bin/cluutil -ckpt -oraclebase /u01/app/grid -writeckpt -name ROOTCRS_STACK -state SUCCESS
2025-03-18 14:57:07: s_run_as_user2: Running /bin/su grid -c ' /u01/app/11.2.0/grid/bin/cluutil -ckpt -oraclebase /u01/app/grid -writeckpt -name ROOTCRS_STACK -state SUCCESS '
2025-03-18 14:57:07: Removing file /tmp/file98vGxZ
2025-03-18 14:57:07: Successfully removed file: /tmp/file98vGxZ
2025-03-18 14:57:07: /bin/su successfully executed

2025-03-18 14:57:07: Succeeded in writing the checkpoint:'ROOTCRS_STACK' with status:SUCCESS
2025-03-18 14:57:07: CkptFile: /u01/app/grid/Clusterware/ckptGridHA_rac2.xml
2025-03-18 14:57:07: Sync the checkpoint file '/u01/app/grid/Clusterware/ckptGridHA_rac2.xml'
2025-03-18 14:57:07: Sync '/u01/app/grid/Clusterware/ckptGridHA_rac2.xml' to the physical disk


[root@rac2 crsconfig]# more /u01/app/grid/Clusterware/ckptGridHA_rac2.xml
<?xml version="1.0" standalone="yes" ?>
<!-- Copyright (c) 1999, 2013, Oracle and/or its affiliates.
All rights reserved. -->
<!-- Do not modify the contents of this file by hand. -->
<CHECKPOINTS>
   <CHECKPOINT LEVEL="MAJOR" NAME="ROOTCRS_STACK" DESC="ROOTCRS_STACK" STATE="SUCCESS">
      <PROPERTY_LIST>
         <PROPERTY NAME="VERSION" TYPE="STRING" VAL="11.2.0.4.0"/>
      </PROPERTY_LIST>
   </CHECKPOINT>
   <CHECKPOINT LEVEL="MAJOR" NAME="ROOTCRS_PARAM" DESC="ROOTCRS_PARAM" STATE="SUCCESS">
      <PROPERTY_LIST>
         <PROPERTY NAME="NODE_NAME_LIST" TYPE="STRING" VAL="rac1,rac2"/>
         <PROPERTY NAME="REUSEDG" TYPE="STRING
```



##### 3.4.9.图形化点击完成root.sh脚本后继续执行，在86%显示启动netca配置时卡住

```bash
#此时在rac1上执行srvctl config listener卡住，在rac2上执行srvctl config listener正常，所以将rac2的crs重启下，在rac1上执行srvctl config listener正常后，安装会继续，直至完成

#图形化安装GI结束后，两台虚拟机都重启下，此时在两台机器上执行srvctl config listener均正常
```



### 3.5.root用户执行脚本日志

#### 3.5.1 rac1日志
```bash
[root@rac1 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@rac1 ~]# /u01/app/11.2.0/grid/root.sh
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
2025-03-06 17:17:41.412:
[client(224068)]CRS-2101:The OLR was formatted using version 3.

CRS-2672: Attempting to start 'ora.mdnsd' on 'rac1'
CRS-2676: Start of 'ora.mdnsd' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'rac1'
CRS-2676: Start of 'ora.gpnpd' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'rac1'
CRS-2672: Attempting to start 'ora.gipcd' on 'rac1'
CRS-2676: Start of 'ora.cssdmonitor' on 'rac1' succeeded
CRS-2676: Start of 'ora.gipcd' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'rac1'
CRS-2672: Attempting to start 'ora.diskmon' on 'rac1'
CRS-2676: Start of 'ora.diskmon' on 'rac1' succeeded
CRS-2676: Start of 'ora.cssd' on 'rac1' succeeded

ASM created and started successfully.

Disk Group OCR created successfully.

clscfg: -install mode specified
Successfully accumulated necessary OCR keys.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
CRS-4256: Updating the profile
Successful addition of voting disk 4bdc8755d4d84f90bfc431822a91f3f8.
Successful addition of voting disk 013fac474ee14fd7bff5f023ba08babd.
Successful addition of voting disk 1b4645c4dc964fe4bfb0ebe9cc29a1ef.
Successfully replaced voting disk group with +OCR.
CRS-4256: Updating the profile
CRS-4266: Voting file(s) successfully replaced
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   4bdc8755d4d84f90bfc431822a91f3f8 (/dev/oracleasm/disks/OCR01) [OCR]
 2. ONLINE   013fac474ee14fd7bff5f023ba08babd (/dev/oracleasm/disks/OCR02) [OCR]
 3. ONLINE   1b4645c4dc964fe4bfb0ebe9cc29a1ef (/dev/oracleasm/disks/OCR03) [OCR]
Located 3 voting disk(s).
CRS-2672: Attempting to start 'ora.asm' on 'rac1'
CRS-2676: Start of 'ora.asm' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.OCR.dg' on 'rac1'
CRS-2676: Start of 'ora.OCR.dg' on 'rac1' succeeded
Configure Oracle Grid Infrastructure for a Cluster ... succeeded
[root@rac1 u01]#
```
#### 3.5.2 rac2日志
```bash
[root@rac2 u01]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@rac2 u01]# /u01/app/11.2.0/grid/root.sh
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
CRS-4402: The CSS daemon was started in exclusive mode but found an active CSS daemon on node rac1, number 1, and is terminating
An active cluster was found during exclusive startup, restarting to join the cluster
Configure Oracle Grid Infrastructure for a Cluster ... succeeded
[root@rac2 u01]#

```

### 3.6. 查看状态

```bash
crsctl status resource -t

```

```
[grid@rac1 grid]$ cat  /u01/app/oraInventory/logs/installActions2025-03-06_03-10-52PM.log|grep udev
[grid@rac1 grid]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
      
[grid@rac1 ~]$ ll /dev/oracleasm/disks/
total 0
lrwxrwxrwx 1 root root 9 Mar  6 18:00 DATA01 -> ../../sda
lrwxrwxrwx 1 root root 9 Mar  6 18:00 DATA02 -> ../../sdc
lrwxrwxrwx 1 root root 9 Mar  6 18:00 OCR01 -> ../../sde
lrwxrwxrwx 1 root root 9 Mar  6 18:00 OCR02 -> ../../sdg
lrwxrwxrwx 1 root root 9 Mar  6 18:00 OCR03 -> ../../sdh

[grid@rac1 grid]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:89:b7:df brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.52/23 brd 172.29.85.255 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet 192.168.10.54/23 brd 172.29.85.255 scope global secondary eth0:1
       valid_lft forever preferred_lft forever
    inet 192.168.10.56/23 brd 172.29.85.255 scope global secondary eth0:2
       valid_lft forever preferred_lft forever
    inet6 fe80::fcfc:feff:fe89:b7df/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:0a:fe:73 brd ff:ff:ff:ff:ff:ff
    inet 10.10.20.2/24 brd 3.3.3.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet 169.254.52.12/16 brd 169.254.255.255 scope global eth1:1
       valid_lft forever preferred_lft forever
    inet6 fe80::b2ee:742c:4fd4:f720/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
5: virbr0-nic: <BROADCAST,MULTICAST> mtu 1500 qdisc pfifo_fast state DOWN group default qlen 1000
    link/ether 52:54:00:c6:e5:ee brd ff:ff:ff:ff:ff:ff
    
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
ASMCMD> lsdsk
Path
/dev/oracleasm/disks/OCR01
/dev/oracleasm/disks/OCR02
/dev/oracleasm/disks/OCR03
ASMCMD>
```
## 4 创建ASM磁盘组：DATA/FRA

#grid用户图形界面下

```bash
asmca
```
```
 --->create
 --->DATA,external,选中/dev/sdd,OK，如果弹框看不到磁盘选择项，可以用鼠标拖动
 --->FRA,external,选中/dev/sde,OK，如果弹框看不到磁盘选择项，可以用鼠标拖动
 
 
 #如果用方式二
 --->DATA,external,选中/dev/oracleasm/disks/DATA01和/dev/oracleasm/disks/DATA02,OK，如果弹框看不到磁盘选择项，可以用鼠标拖动
```
#验证
```
[grid@rac1 grid]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   4194304  4194171                0         4194171              0             N  DATA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
ASMCMD> lsdsk
Path
/dev/oracleasm/disks/DATA01
/dev/oracleasm/disks/DATA02
/dev/oracleasm/disks/OCR01
/dev/oracleasm/disks/OCR02
/dev/oracleasm/disks/OCR03
ASMCMD> exit

[grid@rac1 ~]$ ll /dev/oracleasm/disks/
total 0
lrwxrwxrwx 1 root root 9 Mar  6 18:00 DATA01 -> ../../sda
lrwxrwxrwx 1 root root 9 Mar  6 18:00 DATA02 -> ../../sdc
lrwxrwxrwx 1 root root 9 Mar  6 18:00 OCR01 -> ../../sde
lrwxrwxrwx 1 root root 9 Mar  6 18:00 OCR02 -> ../../sdg
lrwxrwxrwx 1 root root 9 Mar  6 18:00 OCR03 -> ../../sdh

[grid@rac1 grid]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[grid@rac1 grid]$

[grid@rac2 ~]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   4194304  4194171                0         4194171              0             N  DATA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
ASMCMD> lsdsk
Path
/dev/oracleasm/disks/DATA01
/dev/oracleasm/disks/DATA02
/dev/oracleasm/disks/OCR01
/dev/oracleasm/disks/OCR02
/dev/oracleasm/disks/OCR03
ASMCMD> exit


[grid@rac2 ~]$ ll /dev/oracleasm/disks/
total 0
lrwxrwxrwx 1 root root 9 Mar  6 18:08 DATA01 -> ../../sda
lrwxrwxrwx 1 root root 9 Mar  6 18:00 DATA02 -> ../../sdb
lrwxrwxrwx 1 root root 9 Mar  6 18:08 OCR01 -> ../../sdf
lrwxrwxrwx 1 root root 9 Mar  6 18:08 OCR02 -> ../../sdh
lrwxrwxrwx 1 root root 9 Mar  6 18:00 OCR03 -> ../../sdg


[grid@rac2 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[grid@rac2 ~]$

```


#### 4.1.通过asmca，DATA/FRA创建成功，但是crsctl status resource -t不显示

##### 4.1.1.现象

```bash
#在rac1上通过asmca创建共享磁盘DATA和FRA后，在rac2上看不到

[grid@rac1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac2
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac2
[grid@rac1 ~]$ asmcmd lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usa                           ble_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   2097152  2097082                0                                    2097082              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576   2097152  2097082                0                                    2097082              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400                                     101937              0             Y  OCR/


[grid@rac2 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac2
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac2
[grid@rac2 ~]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
ASMCMD> exit
[grid@rac2 ~]$

[grid@rac1 trace]$ tail -f alert_+ASM1.log
SUCCESS: CREATE DISKGROUP FRA EXTERNAL REDUNDANCY DISK '/dev/sde' SIZE 2097152M ATTRIBUTE 'compatible.asm'='11.2.0.0.0','au_size'='1M' /* ASMCA */
Tue Mar 18 16:02:34 2025
NOTE: diskgroup resource ora.FRA.dg is online
ERROR: failed to update diskgroup resource ora.FRA.dg

[root@rac1 rac1]# srvctl status diskgroup -g FRA
PRCA-1000 : ASM Disk Group FRA does not exist
PRCR-1001 : Resource ora.FRA.dg does not exist
[root@rac1 rac1]# srvctl status diskgroup -g DATA
PRCA-1000 : ASM Disk Group DATA does not exist
PRCR-1001 : Resource ora.DATA.dg does not exist
[root@rac1 rac1]#

[root@rac1 rac1]# crsctl status resource ora.DATA.dg -t
CRS-2613: Could not find resource 'ora.DATA.dg'.
[root@rac1 rac1]# crsctl status resource ora.FRA.dg -t
CRS-2613: Could not find resource 'ora.FRA.dg'.
[root@rac1 rac1]# crsctl status resource ora.OCR.dg -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
[root@rac1 rac1]#

```

##### 4.1.2.尝试解决，失败

#手动添加失败

```bash
#手动添加失败
[root@rac1 rac1]# srvctl add diskgroup -g DATA
Usage: srvctl <command> <object> [<options>]
    commands: enable|disable|start|stop|relocate|status|add|remove|modify|getenv|setenv|unsetenv|config|convert|upgrade
    objects: database|instance|service|nodeapps|vip|network|asm|diskgroup|listener|srvpool|server|scan|scan_listener|oc4j|home|filesystem|gns|cvu
For detailed help on each command and object and its options use:
  srvctl <command> -h or
  srvctl <command> <object> -h
PRKO-2011 : Invalid object specified on command line: diskgroup

```



#两台虚拟机重启cluster无效

```bash
#两台虚拟机重启cluster无效
[root@rac2 app]# crsctl stop cluster -all
CRS-2673: Attempting to stop 'ora.crsd' on 'rac2'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'rac2'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'rac2'
CRS-2673: Attempting to stop 'ora.LISTENER_SCAN1.lsnr' on 'rac2'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'rac2'
CRS-2677: Stop of 'ora.LISTENER_SCAN1.lsnr' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.scan1.vip' on 'rac2'
CRS-2677: Stop of 'ora.scan1.vip' on 'rac2' succeeded
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.rac2.vip' on 'rac2'
CRS-2677: Stop of 'ora.rac2.vip' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.crsd' on 'rac1'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'rac1'
CRS-2673: Attempting to stop 'ora.oc4j' on 'rac1'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'rac1'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'rac1'
CRS-2673: Attempting to stop 'ora.cvu' on 'rac1'
CRS-2677: Stop of 'ora.cvu' on 'rac1' succeeded
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.rac1.vip' on 'rac1'
CRS-2677: Stop of 'ora.rac1.vip' on 'rac1' succeeded
CRS-2677: Stop of 'ora.oc4j' on 'rac1' succeeded
CRS-2677: Stop of 'ora.OCR.dg' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'rac2'
CRS-2677: Stop of 'ora.asm' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.ons' on 'rac2'
CRS-2677: Stop of 'ora.ons' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'rac2'
CRS-2677: Stop of 'ora.net1.network' on 'rac2' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'rac2' has completed
CRS-2677: Stop of 'ora.crsd' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'rac2'
CRS-2673: Attempting to stop 'ora.evmd' on 'rac2'
CRS-2673: Attempting to stop 'ora.asm' on 'rac2'
CRS-2677: Stop of 'ora.evmd' on 'rac2' succeeded
CRS-2677: Stop of 'ora.OCR.dg' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'rac1'
CRS-2677: Stop of 'ora.asm' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.ons' on 'rac1'
CRS-2677: Stop of 'ora.ons' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'rac1'
CRS-2677: Stop of 'ora.net1.network' on 'rac1' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'rac1' has completed
CRS-2677: Stop of 'ora.crsd' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'rac1'
CRS-2673: Attempting to stop 'ora.evmd' on 'rac1'
CRS-2673: Attempting to stop 'ora.asm' on 'rac1'
CRS-2677: Stop of 'ora.evmd' on 'rac1' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'rac2' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'rac1' succeeded
CRS-2677: Stop of 'ora.asm' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'rac2'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'rac2'
CRS-2677: Stop of 'ora.cssd' on 'rac2' succeeded
CRS-2677: Stop of 'ora.asm' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'rac1'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'rac1'
CRS-2677: Stop of 'ora.cssd' on 'rac1' succeeded
[root@rac2 app]# crsctl status resource -t
CRS-4535: Cannot communicate with Cluster Ready Services
CRS-4000: Command Status failed, or completed with errors.
[root@rac2 app]# crsctl start cluster -all
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'rac2'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'rac1'
CRS-2676: Start of 'ora.cssdmonitor' on 'rac1' succeeded
CRS-2676: Start of 'ora.cssdmonitor' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'rac2'
CRS-2672: Attempting to start 'ora.cssd' on 'rac1'
CRS-2672: Attempting to start 'ora.diskmon' on 'rac1'
CRS-2672: Attempting to start 'ora.diskmon' on 'rac2'
CRS-2676: Start of 'ora.diskmon' on 'rac1' succeeded
CRS-2676: Start of 'ora.diskmon' on 'rac2' succeeded
CRS-2676: Start of 'ora.cssd' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.ctssd' on 'rac2'
CRS-2676: Start of 'ora.cssd' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'rac2'
CRS-2672: Attempting to start 'ora.ctssd' on 'rac1'
CRS-2676: Start of 'ora.ctssd' on 'rac2' succeeded
CRS-2676: Start of 'ora.ctssd' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.evmd' on 'rac2'
CRS-2672: Attempting to start 'ora.evmd' on 'rac1'
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'rac1'
CRS-2676: Start of 'ora.evmd' on 'rac2' succeeded
CRS-2676: Start of 'ora.evmd' on 'rac1' succeeded
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'rac2'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'rac1'
CRS-2676: Start of 'ora.asm' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'rac2'
CRS-2676: Start of 'ora.crsd' on 'rac2' succeeded
CRS-2676: Start of 'ora.asm' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'rac1'
CRS-2676: Start of 'ora.crsd' on 'rac1' succeeded
[root@rac2 app]# asmcmd lsdg
Connected to an idle instance.
ASMCMD-8102: no connection to Oracle ASM; command requires Oracle ASM to run
[root@rac2 app]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac2
ora.oc4j
      1        ONLINE  ONLINE       rac2
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[root@rac2 app]#

```



#两台虚拟机重启无效

#使用SQL挂载操作触发自动注册，失败

```bash
#先卸载磁盘组
SQL> ALTER DISKGROUP DATA DISMOUNT;
SQL> ALTER DISKGROUP FRA DISMOUNT;

#然后重新挂载它们
SQL> ALTER DISKGROUP DATA MOUNT;
SQL> ALTER DISKGROUP FRA MOUNT;
```



#使用crsctl命令直接添加共享磁盘组，失败

```bash
crsctl add resource ora.DATA.dg -type ora.diskgroup.type -attr="ACL=owner:oracle:rwx,START_DEPENDENCIES=pullup:always(ora.asm) hard(ora.asm),VERSION=11.2.0.4.0"

crsctl add resource ora.FRA.dg -type ora.diskgroup.type -attr="ACL=owner:oracle:rwx,START_DEPENDENCIES=pullup:always(ora.asm) hard(ora.asm),VERSION=11.2.0.4.0"

```





##### 4.1.3.解决办法



```bash
#使用crsctl命令手动注册

#虽然DATA和FRA磁盘组在ASM中已经挂载（asmcmd lsdg可以看到），但它们没有在Oracle集群注册表(OCR)中注册为集群资源，因此在crsctl status resource -t的输出中看不到
#由于Oracle 11gR2中没有直接的`srvctl add diskgroup`命令，需要使用以下方法来注册磁盘组

```

```bash
#首先，从现有的OCR.dg资源获取配置文件
crsctl stat resource ora.OCR.dg -p > ocr_profile.txt

#编辑该文件，将所有OCR相关的内容替换为DATA
cp ocr_profile.txt data_profile.txt
   vi data_profile.txt
   # 将所有"OCR"替换为"DATA"
   
#使用修改后的配置文件添加DATA磁盘组资源：
crsctl add resource ora.DATA.dg -type ora.diskgroup.type -file data_profile.txt

#对FRA磁盘组重复相同的步骤：
   cp ocr_profile.txt fra_profile.txt
   vi fra_profile.txt
   # 将所有"OCR"替换为"FRA"
   crsctl add resource ora.FRA.dg -type ora.diskgroup.type -file fra_profile.txt
   
   
#查看共享磁盘组是否添加成功
crsctl status resource -t

#如果资源已添加但状态不是ONLINE，启动它们
crsctl start resource ora.DATA.dg
crsctl start resource ora.FRA.dg

#尝试重启集群看看能否自动挂载
crsctl stop cluster -all
crsctl start cluster -all

#服务器重启测试
reboot
```



#logs

```bash
[root@rac1 ~]# crsctl status resource ora.OCR.dg -p > ocr_profile.txt

[root@rac1 ~]# cat ocr_profile.txt
NAME=ora.OCR.dg
TYPE=ora.diskgroup.type
ACL=owner:grid:rwx,pgrp:oinstall:rwx,other::r--
ACTION_FAILURE_TEMPLATE=
ACTION_SCRIPT=
AGENT_FILENAME=%CRS_HOME%/bin/oraagent%CRS_EXE_SUFFIX%
ALIAS_NAME=
AUTO_START=never
CHECK_INTERVAL=300
CHECK_TIMEOUT=30
DEFAULT_TEMPLATE=
DEGREE=1
DESCRIPTION=CRS resource type definition for ASM disk group resource
ENABLED=1
LOAD=1
LOGGING_LEVEL=1
NLS_LANG=
NOT_RESTARTING_TEMPLATE=
OFFLINE_CHECK_INTERVAL=0
PROFILE_CHANGE_TEMPLATE=
RESTART_ATTEMPTS=5
SCRIPT_TIMEOUT=60
START_DEPENDENCIES=hard(ora.asm) pullup(ora.asm)
START_TIMEOUT=900
STATE_CHANGE_TEMPLATE=
STOP_DEPENDENCIES=hard(intermediate:ora.asm)
STOP_TIMEOUT=180
TYPE_VERSION=1.2
UPTIME_THRESHOLD=1d
USR_ORA_ENV=
USR_ORA_OPI=false
USR_ORA_STOP_MODE=
VERSION=11.2.0.4.0

[root@rac1 ~]# cp ocr_profile.txt data_profile.txt
[root@rac1 ~]# vi data_profile.txt
[root@rac1 ~]# crsctl add resource ora.DATA.dg -type ora.diskgroup.type -file data_profile.txt

[root@rac1 ~]# cp ocr_profile.txt fra_profile.txt
[root@rac1 ~]# vi fra_profile.txt
[root@rac1 ~]# crsctl add resource ora.FRA.dg -type ora.diskgroup.type -file fra_profile.txt

[root@rac1 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.FRA.dg
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[root@rac1 ~]#


#如果资源已添加但状态不是ONLINE，启动它们
[root@rac1 ~]# crsctl start resource ora.DATA.dg
CRS-2672: Attempting to start 'ora.DATA.dg' on 'rac1'
CRS-2672: Attempting to start 'ora.DATA.dg' on 'rac2'
CRS-2676: Start of 'ora.DATA.dg' on 'rac1' succeeded
CRS-2676: Start of 'ora.DATA.dg' on 'rac2' succeeded
[root@rac1 ~]# crsctl start resource ora.FRA.dg
CRS-2672: Attempting to start 'ora.FRA.dg' on 'rac2'
CRS-2672: Attempting to start 'ora.FRA.dg' on 'rac1'
CRS-2676: Start of 'ora.FRA.dg' on 'rac1' succeeded
CRS-2676: Start of 'ora.FRA.dg' on 'rac2' succeeded
[root@rac1 ~]#


[root@rac2 ~]# crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.FRA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1


[root@rac1 ~]# crsctl stop cluster -all
CRS-2673: Attempting to stop 'ora.crsd' on 'rac1'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'rac1'
CRS-2673: Attempting to stop 'ora.LISTENER_SCAN1.lsnr' on 'rac1'
CRS-2673: Attempting to stop 'ora.cvu' on 'rac1'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'rac1'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'rac1'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'rac1'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'rac1'
CRS-2673: Attempting to stop 'ora.oc4j' on 'rac1'
CRS-2677: Stop of 'ora.cvu' on 'rac1' succeeded
CRS-2677: Stop of 'ora.LISTENER_SCAN1.lsnr' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.scan1.vip' on 'rac1'
CRS-2677: Stop of 'ora.DATA.dg' on 'rac1' succeeded
CRS-2677: Stop of 'ora.FRA.dg' on 'rac1' succeeded
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.rac1.vip' on 'rac1'
CRS-2677: Stop of 'ora.scan1.vip' on 'rac1' succeeded
CRS-2677: Stop of 'ora.rac1.vip' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.crsd' on 'rac2'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'rac2'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'rac2'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'rac2'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'rac2'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'rac2'
CRS-2677: Stop of 'ora.oc4j' on 'rac1' succeeded
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.rac2.vip' on 'rac2'
CRS-2677: Stop of 'ora.rac2.vip' on 'rac2' succeeded
CRS-2677: Stop of 'ora.OCR.dg' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'rac1'
CRS-2677: Stop of 'ora.asm' on 'rac1' succeeded
CRS-2677: Stop of 'ora.OCR.dg' on 'rac2' succeeded
CRS-2675: Stop of 'ora.DATA.dg' on 'rac2' failed
CRS-2679: Attempting to clean 'ora.DATA.dg' on 'rac2'
CRS-2675: Stop of 'ora.FRA.dg' on 'rac2' failed
CRS-2679: Attempting to clean 'ora.FRA.dg' on 'rac2'
CRS-2681: Clean of 'ora.DATA.dg' on 'rac2' succeeded
CRS-2681: Clean of 'ora.FRA.dg' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'rac2'
CRS-2677: Stop of 'ora.asm' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.ons' on 'rac2'
CRS-2677: Stop of 'ora.ons' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'rac2'
CRS-2677: Stop of 'ora.net1.network' on 'rac2' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'rac2' has completed
CRS-2673: Attempting to stop 'ora.ons' on 'rac1'
CRS-2677: Stop of 'ora.ons' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'rac1'
CRS-2677: Stop of 'ora.net1.network' on 'rac1' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'rac1' has completed
CRS-2677: Stop of 'ora.crsd' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'rac2'
CRS-2673: Attempting to stop 'ora.evmd' on 'rac2'
CRS-2673: Attempting to stop 'ora.asm' on 'rac2'
CRS-2677: Stop of 'ora.crsd' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'rac1'
CRS-2673: Attempting to stop 'ora.evmd' on 'rac1'
CRS-2673: Attempting to stop 'ora.asm' on 'rac1'
CRS-2677: Stop of 'ora.evmd' on 'rac2' succeeded
CRS-2677: Stop of 'ora.evmd' on 'rac1' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'rac1' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'rac2' succeeded
CRS-5017: The resource action "ora.asm stop" encountered the following error:
ORA-03113: end-of-file on communication channel
Process ID: 3453
Session ID: 2807 Serial number: 3
. For details refer to "(:CLSN00108:)" in "/u01/app/11.2.0/grid/log/rac1/agent/ohasd/oraagent_grid/oraagent_grid.log".
CRS-2675: Stop of 'ora.asm' on 'rac1' failed
CRS-2679: Attempting to clean 'ora.asm' on 'rac1'
CRS-2681: Clean of 'ora.asm' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'rac1'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'rac1' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'rac1'
CRS-2677: Stop of 'ora.cssd' on 'rac1' succeeded
CRS-2677: Stop of 'ora.asm' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'rac2'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'rac2' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'rac2'
CRS-2677: Stop of 'ora.cssd' on 'rac2' succeeded
[root@rac1 ~]#



[root@rac1 ~]# crsctl start cluster -all
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'rac1'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'rac2'
CRS-2676: Start of 'ora.cssdmonitor' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'rac1'
CRS-2676: Start of 'ora.cssdmonitor' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.diskmon' on 'rac1'
CRS-2672: Attempting to start 'ora.cssd' on 'rac2'
CRS-2672: Attempting to start 'ora.diskmon' on 'rac2'
CRS-2676: Start of 'ora.diskmon' on 'rac1' succeeded
CRS-2676: Start of 'ora.diskmon' on 'rac2' succeeded
CRS-2676: Start of 'ora.cssd' on 'rac2' succeeded
CRS-2676: Start of 'ora.cssd' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.ctssd' on 'rac1'
CRS-2672: Attempting to start 'ora.ctssd' on 'rac2'
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'rac1'
CRS-2676: Start of 'ora.ctssd' on 'rac1' succeeded
CRS-2676: Start of 'ora.ctssd' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.evmd' on 'rac2'
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'rac2'
CRS-2672: Attempting to start 'ora.evmd' on 'rac1'
CRS-2676: Start of 'ora.evmd' on 'rac2' succeeded
CRS-2676: Start of 'ora.evmd' on 'rac1' succeeded
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'rac1'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'rac2'
CRS-2676: Start of 'ora.asm' on 'rac1' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'rac1'
CRS-2676: Start of 'ora.crsd' on 'rac1' succeeded
CRS-2676: Start of 'ora.asm' on 'rac2' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'rac2'
CRS-2676: Start of 'ora.crsd' on 'rac2' succeeded
[root@rac1 ~]#

[grid@rac1 trace]$ asmcmd lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   2097152  2097039                0         2097039              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576   2097152  2097039                0         2097039              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
[grid@rac1 trace]$

[grid@rac2 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.FRA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
[grid@rac2 ~]$ asmcmd lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   2097152  2097039                0         2097039              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576   2097152  2097039                0         2097039              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/


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
  ./runcluvfy.sh stage -pre dbinst -n rac1,rac2 -fixup -verbose|tee -a preora.log
```
#如果下面报错内容，可以忽略
```
Check: Package existence for "pdksh"
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  rac2       missing                   pdksh-5.2.14              failed
  rac1       missing                   pdksh-5.2.14              failed
Result: Package existence check failed for "pdksh"


ERROR:
PRVG-1101 : SCAN name "rac-scan" failed to resolve
  SCAN Name     IP Address                Status                    Comment
  ------------  ------------------------  ------------------------  ----------
  rac-scan      192.168.10.56              failed                    NIS Entry

ERROR:
PRVF-4657 : Name resolution setup check for "rac-scan" (IP address: 192.168.10.56) failed

ERROR:
PRVF-4664 : Found inconsistent name resolution entries for SCAN name "rac-scan"

Verification of SCAN VIP and Listener setup failed

```
#通过vnc以 Oracle 用户登录图形化界面安装 Oracle 数据库软件
```
#根据前面vnc的配置，连接地址
rac1IP:2
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
--->pdksh/scan: Ignore All(如果无法点击弹框，可以按4次Tab后点击回车键即可)
--->Install
--->'agent nmhs' error处理,见下面错误处理步骤
    --->Retry
--->/u01/app/oracle/product/11.2.0/db_1/root.sh，分别在rac1/rac2上用root账户运行，如果弹框看不到内容，可以用鼠标拖动
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
[root@rac1 ~]# /u01/app/oracle/product/11.2.0/db_1/root.sh
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

[root@rac2 ohasd]# /u01/app/oracle/product/11.2.0/db_1/root.sh
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

### 6.1.dbca安装数据库实例
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
--->Admin-Managed/szhxy/szhxy/Select All
--->Configure Enterprise Manager
--->SYS/SYSTEM/DBSNMP/SYSMAN使用一个密码: Ora543Cle
--->ASM/+DATA
    --->弹框中输入ASMSNMP的密码(此弹框可能需要鼠标拖开，密码为GI时设置的密码)
--->Specify FRA: +FRA/2000000M(大小根据实际情况填写)/Enable Arechiving
--->Sample Schemas，可以去掉打勾
--->Memory: Custom---SGA:60000M/PGA:20000M(大小根据实际设置memory*60%左右)
    --->Sizing: Processes---3000(根据服务器资源调整)
    --->CharacterSets: Use AL32UTF8(有些库是ZHS16GBK)
    --->Connection Mode: Dedicated Server Mode
--->可以修改Redo Log Groups，再添加两组，并调整大小为200M
ALTER DATABASE ADD LOGFILE THREAD 1 GROUP 5  SIZE 200M;
ALTER DATABASE ADD LOGFILE THREAD 2 GROUP 6  SIZE 200M;
--->Finish
--->OK，此处弹框可能需要鼠标拖开
--->等待执行完毕，点击Exit
```

### 6.2.报错处理
##### 6.2.1报错1 oracle用户没有权限访问资源ora.LISTENER.lsnr

```bash
[oracle@rac1 ~]$ cd /u01/app/oracle/cfgtoollogs/dbca/szhxy

[oracle@rac1 szhxy]$ ll -rth
total 364K
-rw-r----- 1 oracle oinstall 364K Mar 18 18:08 trace.log
[oracle@rac1 szhxy]$ tail -100f trace.log

[Thread-157] [ 2025-03-18 18:07:40.698 CST ] [InstanceStepOPS.executeImpl:1014]  PRCR-1006 : Failed to add resource ora.szhxy.db for szhxy
PRCR-1071 : Failed to register or update resource ora.szhxy.db
CRS-2566: User 'oracle' does not have sufficient permissions to operate on resource 'ora.LISTENER.lsnr', which is part of the dependency specification.
[Thread-157] [ 2025-03-18 18:07:40.698 CST ] [BasicStep.configureSettings:304]  messageHandler being set=oracle.sysman.assistants.util.UIMessageHandler@2ef9748f
[Thread-157] [ 2025-03-18 18:07:40.698 CST ] [BasicStep.configureSettings:304]  messageHandler being set=oracle.sysman.assistants.util.UIMessageHandler@2ef9748f
oracle.sysman.assistants.util.step.StepExecutionException: PRCR-1006 : Failed to add resource ora.szhxy.db for szhxy
PRCR-1071 : Failed to register or update resource ora.szhxy.db
CRS-2566: User 'oracle' does not have sufficient permissions to operate on resource 'ora.LISTENER.lsnr', which is part of the dependency specification.
        at oracle.sysman.assistants.dbca.backend.InstanceStepOPS.executeImpl(InstanceStepOPS.java:1015)
        at oracle.sysman.assistants.util.step.BasicStep.execute(BasicStep.java:210)
        at oracle.sysman.assistants.util.step.BasicStep.callStep(BasicStep.java:251)
        at oracle.sysman.assistants.dbca.backend.CloneRmanRestoreStep.executeImpl(CloneRmanRestoreStep.java:222)
        at oracle.sysman.assistants.util.step.BasicStep.execute(BasicStep.java:210)
        at oracle.sysman.assistants.util.step.Step.execute(Step.java:140)
        at oracle.sysman.assistants.util.step.StepContext$ModeRunner.run(StepContext.java:2711)
        at java.lang.Thread.run(Thread.java:637)
[Finalizer] [ 2025-03-18 18:08:09.663 CST ] [ClusterUtil.finalize:102]  ClusterUtil: finalized called for oracle.ops.mgmt.has.ClusterUtil@1efc3d2
[Finalizer] [ 2025-03-18 18:08:09.663 CST ] [ClusterUtil.finalize:102]  ClusterUtil: finalized called for oracle.ops.mgmt.has.ClusterUtil@16e15a69
[Finalizer] [ 2025-03-18 18:08:09.663 CST ] [ClusterUtil.finalize:102]  ClusterUtil: finalized called for oracle.ops.mgmt.has.ClusterUtil@24f6af3b
[Finalizer] [ 2025-03-18 18:08:09.663 CST ] [ClusterUtil.finalize:102]  ClusterUtil: finalized called for oracle.ops.mgmt.has.ClusterUtil@3f6a5d72
[Finalizer] [ 2025-03-18 18:08:09.664 CST ] [Util.finalize:126]  Util: finalized called for oracle.ops.mgmt.has.Util@601d07e4
[Finalizer] [ 2025-03-18 18:08:09.664 CST ] [Util.finalize:126]  Util: finalized called for oracle.ops.mgmt.has.Util@11f13b08
[Finalizer] [ 2025-03-18 18:08:09.664 CST ] [Util.finalize:126]  Util: finalized called for oracle.ops.mgmt.has.Util@745a936b
[Finalizer] [ 2025-03-18 18:08:09.664 CST ] [Util.finalize:126]  Util: finalized called for oracle.ops.mgmt.has.Util@6684917a

#ACL错误
#ACL=owner:root:rwx,pgrp:root:r-x,other::r--
[grid@rac2 ~]$ crsctl status resource ora.LISTENER.lsnr -p
NAME=ora.LISTENER.lsnr
TYPE=ora.listener.type
ACL=owner:root:rwx,pgrp:root:r-x,other::r--
ACTION_FAILURE_TEMPLATE=
ACTION_SCRIPT=%CRS_HOME%/bin/racgwrap%CRS_SCRIPT_SUFFIX%
AGENT_FILENAME=%CRS_HOME%/bin/oraagent%CRS_EXE_SUFFIX%
ALIAS_NAME=ora.%CRS_CSS_NODENAME_LOWER_CASE%.LISTENER_%CRS_CSS_NODENAME_UPPER_CASE%.lsnr
AUTO_START=restore
CHECK_INTERVAL=60
CHECK_TIMEOUT=120
DEFAULT_TEMPLATE=PROPERTY(RESOURCE_CLASS=listener) PROPERTY(LISTENER_NAME=PARSE(%NAME%, ., 2))
DEGREE=1
DESCRIPTION=Oracle Listener resource
ENABLED=1
ENDPOINTS=TCP:1521
LOAD=1
LOGGING_LEVEL=1
NLS_LANG=
NOT_RESTARTING_TEMPLATE=
OFFLINE_CHECK_INTERVAL=0
ORACLE_HOME=%CRS_HOME%
PORT=1521
PROFILE_CHANGE_TEMPLATE=
RESTART_ATTEMPTS=5
SCRIPT_TIMEOUT=60
START_DEPENDENCIES=hard(type:ora.cluster_vip_net1.type) pullup(type:ora.cluster_vip_net1.type)
START_TIMEOUT=180
STATE_CHANGE_TEMPLATE=
STOP_DEPENDENCIES=hard(intermediate:type:ora.cluster_vip_net1.type)
STOP_TIMEOUT=0

#正确的ACL
#ACL=owner:grid:rwx,pgrp:oinstall:rwx,other::r--
[grid@rac2 ~]$ crsctl status resource ora.LISTENER.lsnr -p
NAME=ora.LISTENER.lsnr
TYPE=ora.listener.type
ACL=owner:grid:rwx,pgrp:root:r-x,other::r--
ACTION_FAILURE_TEMPLATE=
ACTION_SCRIPT=%CRS_HOME%/bin/racgwrap%CRS_SCRIPT_SUFFIX%
AGENT_FILENAME=%CRS_HOME%/bin/oraagent%CRS_EXE_SUFFIX%
ALIAS_NAME=ora.%CRS_CSS_NODENAME_LOWER_CASE%.LISTENER_%CRS_CSS_NODENAME_UPPER_CASE%.lsnr
AUTO_START=restore
CHECK_INTERVAL=60
CHECK_TIMEOUT=120
DEFAULT_TEMPLATE=PROPERTY(RESOURCE_CLASS=listener) PROPERTY(LISTENER_NAME=PARSE(%NAME%, ., 2))
DEGREE=1
DESCRIPTION=Oracle Listener resource
ENABLED=1
ENDPOINTS=TCP:1521
LOAD=1
LOGGING_LEVEL=1
NLS_LANG=
NOT_RESTARTING_TEMPLATE=
OFFLINE_CHECK_INTERVAL=0
ORACLE_HOME=%CRS_HOME%
PORT=1521
PROFILE_CHANGE_TEMPLATE=
RESTART_ATTEMPTS=5
SCRIPT_TIMEOUT=60
START_DEPENDENCIES=hard(type:ora.cluster_vip_net1.type) pullup(type:ora.cluster_vip_net1.type)
START_TIMEOUT=180
STATE_CHANGE_TEMPLATE=
STOP_DEPENDENCIES=hard(intermediate:type:ora.cluster_vip_net1.type)
STOP_TIMEOUT=0
TYPE_VERSION=1.2
UPTIME_THRESHOLD=1d
USR_ORA_ENV=
USR_ORA_OPI=false
VERSION=11.2.0.4.0



===============
[root@rac2 ~]# crsctl status resource ora.LISTENER.lsnr -p
NAME=ora.LISTENER.lsnr
TYPE=ora.listener.type
ACL=owner:grid:rwx,pgrp:oinstall:rwx,other::r--
ACTION_FAILURE_TEMPLATE=
ACTION_SCRIPT=%CRS_HOME%/bin/racgwrap%CRS_SCRIPT_SUFFIX%
AGENT_FILENAME=%CRS_HOME%/bin/oraagent%CRS_EXE_SUFFIX%
ALIAS_NAME=ora.%CRS_CSS_NODENAME_LOWER_CASE%.LISTENER_%CRS_CSS_NODENAME_UPPER_CASE%.lsnr
AUTO_START=restore
CHECK_INTERVAL=60
CHECK_TIMEOUT=120
DEFAULT_TEMPLATE=PROPERTY(RESOURCE_CLASS=listener) PROPERTY(LISTENER_NAME=PARSE(%NAME%, ., 2))
DEGREE=1
DESCRIPTION=Oracle Listener resource
ENABLED=1
ENDPOINTS=TCP:1521
LOAD=1
LOGGING_LEVEL=1
NLS_LANG=
NOT_RESTARTING_TEMPLATE=
OFFLINE_CHECK_INTERVAL=0
ORACLE_HOME=%CRS_HOME%
PORT=1521
PROFILE_CHANGE_TEMPLATE=
RESTART_ATTEMPTS=5
SCRIPT_TIMEOUT=60
START_DEPENDENCIES=hard(type:ora.cluster_vip_net1.type) pullup(type:ora.cluster_vip_net1.type)
START_TIMEOUT=180
STATE_CHANGE_TEMPLATE=
STOP_DEPENDENCIES=hard(intermediate:type:ora.cluster_vip_net1.type)
STOP_TIMEOUT=0
TYPE_VERSION=1.2
UPTIME_THRESHOLD=1d
USR_ORA_ENV=ORACLE_BASE=/u01/app/grid
USR_ORA_OPI=false
VERSION=11.2.0.4.0


```



```bash
#测试
[root@rac1 ~]# srvctl config listener
Name: LISTENER
Network: 1, Owner: root
Home: <CRS home>
End points: TCP:1521
[root@rac1 ~]# srvctl modify listener -u grid
[root@rac1 ~]# srvctl config listener
Name: LISTENER
Network: 1, Owner: grid
Home: <CRS home>
End points: TCP:1521
[root@rac1 ~]#

```

#解决办法

```bash
[grid@rac1 ~]$ srvctl stop listener
[grid@rac1 ~]$ srvctl remove listener
[grid@rac1 ~]$ srvctl add listener -l LISTENER -p 1521
[grid@rac1 ~]$ srvctl config listener
[grid@rac1 ~]$ srvctl start listener
[grid@rac1 ~]$ srvctl status listener
[grid@rac1 ~]$ crsctl status resource ora.LISTENER.lsnr -p
```



#logs

```bash
[grid@rac1 ~]$ srvctl stop listener
[grid@rac1 ~]$ srvctl remove listener
[grid@rac1 ~]$ srvctl add listener -l LISTENER -p 1521
[grid@rac1 ~]$ srvctl config listener
Name: LISTENER
Network: 1, Owner: grid
Home: <CRS home>
End points: TCP:1521
[grid@rac1 ~]$ srvctl start listener
[grid@rac1 ~]$ srvctl status listener
Listener LISTENER is enabled
Listener LISTENER is running on node(s): rac2,rac1
[grid@rac1 ~]$ crsctl status resource ora.LISTENER.lsnr -p
NAME=ora.LISTENER.lsnr
TYPE=ora.listener.type
ACL=owner:grid:rwx,pgrp:oinstall:rwx,other::r--
ACTION_FAILURE_TEMPLATE=
ACTION_SCRIPT=%CRS_HOME%/bin/racgwrap%CRS_SCRIPT_SUFFIX%
AGENT_FILENAME=%CRS_HOME%/bin/oraagent%CRS_EXE_SUFFIX%
ALIAS_NAME=ora.%CRS_CSS_NODENAME_LOWER_CASE%.LISTENER_%CRS_CSS_NODENAME_UPPER_CASE%.lsnr
AUTO_START=restore
CHECK_INTERVAL=60
CHECK_TIMEOUT=120
DEFAULT_TEMPLATE=PROPERTY(RESOURCE_CLASS=listener) PROPERTY(LISTENER_NAME=PARSE(%NAME%, ., 2))
DEGREE=1
DESCRIPTION=Oracle Listener resource
ENABLED=1
ENDPOINTS=TCP:1521
LOAD=1
LOGGING_LEVEL=1

```



##### 6.2.2.报错2 CRS-2674/CRS-2632 其中一台数据库实例没有启动

#手动启动rac1上的oracle实例后，点击OK，继续安装

```bash
#oracle 11gR2 rac 安装，dbca时，在85%时报错
#IPC Send timeout detected.

[oracle@rac1 ~]$ tail -f /u01/app/oracle/cfgtoollogs/dbca/szhxy/trace.log

[Thread-175] [ 2025-03-14 16:31:13.413 CST ] [PostDBCreationStep.executeImpl:885]  Starting Database HA Resource
[Thread-175] [ 2025-03-14 16:38:05.256 CST ] [CRSNative.internalStartResource:389]  Failed to start resource: Name: ora.szhxy.db, node: null, filter: null, msg CRS-5017: The resource action "ora.szhxy.db start" encountered the following error:
ORA-03113: end-of-file on communication channel
Process ID: 25908
Session ID: 2983 Serial number: 1
. For details refer to "(:CLSN00107:)" in "/u01/app/11.2.0/grid/log/rac1/agent/crsd/oraagent_oracle/oraagent_oracle.log".

CRS-2674: Start of 'ora.szhxy.db' on 'rac1' failed
CRS-2632: There are no more servers to try to place resource 'ora.szhxy.db' on that would satisfy its placement policy
[Thread-175] [ 2025-03-14 16:38:05.257 CST ] [PostDBCreationStep.executeImpl:893]  Exception while Starting with HA Database Resource PRCR-1079 : Failed to start resource ora.szhxy.db
CRS-5017: The resource action "ora.szhxy.db start" encountered the following error:
ORA-03113: end-of-file on communication channel
Process ID: 25908
Session ID: 2983 Serial number: 1
. For details refer to "(:CLSN00107:)" in "/u01/app/11.2.0/grid/log/rac1/agent/crsd/oraagent_oracle/oraagent_oracle.log".

CRS-2674: Start of 'ora.szhxy.db' on 'rac1' failed
CRS-2632: There are no more servers to try to place resource 'ora.szhxy.db' on that would satisfy its placement policy


[oracle@rac1 trace]$ tail -f /u01/app/oracle/diag/rdbms/szhxy/szhxy1/trace/alert_szhxy1.log
Starting background process GTX0
Wed Mar 19 09:43:01 2025
GTX0 started with pid=49, OS id=21029
Starting background process RCBG
Wed Mar 19 09:43:01 2025
RCBG started with pid=50, OS id=21031
replication_dependency_tracking turned off (no async multimaster replication found)
Starting background process QMNC
Wed Mar 19 09:43:02 2025
QMNC started with pid=51, OS id=21035


Wed Mar 19 09:48:17 2025
IPC Send timeout detected. Receiver ospid 20899 [
Wed Mar 19 09:48:17 2025
Errors in file /u01/app/oracle/diag/rdbms/szhxy/szhxy1/trace/szhxy1_lms3_20899.trc:
Wed Mar 19 09:49:07 2025
Detected an inconsistent instance membership by instance 2
Wed Mar 19 09:49:08 2025
Received an instance abort message from instance 2
Please check instance 2 alert and LMON trace files for detail.
LMD0 (ospid: 20885): terminating the instance due to error 481
Wed Mar 19 09:49:08 2025
System state dump requested by (instance=1, osid=20885 (LMD0)), summary=[abnormal instance termination].
System State dumped to trace file /u01/app/oracle/diag/rdbms/szhxy/szhxy1/trace/szhxy1_diag_20873_20250319094908.trc
Dumping diagnostic data in directory=[cdmp_20250319094908], requested by (instance=1, osid=20885 (LMD0)), summary=[abnormal instance termination].
Instance terminated by LMD0, pid = 20885

[oracle@rac2 ~]$ tail -100f /u01/app/oracle/diag/rdbms/szhxy/szhxy2/trace/alert_szhxy2.log
minact-scn: Inst 2 is a slave inc#:4 mmon proc-id:60124 status:0x2
minact-scn status: grec-scn:0x0000.00000000 gmin-scn:0x0000.00000000 gcalc-scn:0x0000.00000000
Wed Mar 19 09:48:17 2025
IPC Send timeout detected. Sender: ospid 60086 [oracle@rac2 (LMS3)]
Receiver: inst 1 binc 435183027 ospid 20899
IPC Send timeout to 1.4 inc 4 for msg type 65521 from opid 16
Wed Mar 19 09:48:19 2025
Communications reconfiguration: instance_number 1
Wed Mar 19 09:49:08 2025
Detected an inconsistent instance membership by instance 2
Evicting instance 1 from cluster
Waiting for instances to leave: 1
Wed Mar 19 09:49:08 2025
Dumping diagnostic data in directory=[cdmp_20250319094908], requested by (instance=1, osid=20885 (LMD0)), summary=[abnormal instance termination].
Reconfiguration started (old inc 4, new inc 8)
List of instances:
 2 (myinst: 2)
 Global Resource Directory frozen
 * dead instance detected - domain 0 invalid = TRUE
 Communication channels reestablished
 Master broadcasted resource hash value bitmaps
 Non-local Process blocks cleaned out
Wed Mar 19 09:49:08 2025
Wed Mar 19 09:49:08 2025
 LMS 1: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
 LMS 3: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
Wed Mar 19 09:49:08 2025
 LMS 2: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
Wed Mar 19 09:49:08 2025
 LMS 0: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
 Set master node info
 Submitted all remote-enqueue requests
 Dwn-cvts replayed, VALBLKs dubious
 All grantable enqueues granted
 Post SMON to start 1st pass IR
Wed Mar 19 09:49:08 2025
minact-scn: Inst 2 is now the master inc#:8 mmon proc-id:60124 status:0x7

[grid@rac2 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.FRA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
ora.szhxy.db
      1        ONLINE  OFFLINE
      2        ONLINE  ONLINE       rac2                     Open
[grid@rac2 ~]$

```


#解决办法

```bash
#尝试手动启动rac1上的实例

#方法一
#通过srvctl启动实例
[oracle@rac1 ~]$ srvctl start instance -d szhxy -i szhxy1 -o open
[oracle@rac1 ~]$ srvctl status database -d szhxy
Instance szhxy1 is running on node rac1
Instance szhxy2 is running on node rac2
[oracle@rac1 ~]$


#方法二
# 以sysdba身份登录到rac1
sqlplus / as sysdba

# 在SQL提示符下执行
STARTUP;




#方法三
#重建实例
# 停止数据库
[grid@rac1 ~]$ srvctl stop database -d szhxy -f

# 删除数据库配置
[grid@rac1 ~]$ srvctl remove database -d szhxy

# 重新添加数据库配置
[grid@rac1 ~]$ srvctl add database -d szhxy -o /u01/app/oracle/product/11.2.0/db_1 -p +DATA/szhxy/spfileszhxy.ora
[grid@rac1 ~]$ srvctl add instance -d szhxy -i szhxy1 -n rac1
[grid@rac1 ~]$ srvctl add instance -d szhxy -i szhxy2 -n rac2

# 启动数据库
[grid@rac1 ~]$ srvctl start database -d szhxy


```

```sql
#部分oracle内部参数优化
alter system set "_gc_latency_wait_time"=1000 scope=spfile;
alter system set "_lm_rcvr_hang_allow_time"=300 scope=spfile;

```





#详细日志

```bash
[grid@rac1 trace]$ tail -100f alert_+ASM1.log

Wed Mar 19 09:42:46 2025
NOTE: client szhxy1:szhxy registered, osid 20940, mbr 0x1
Wed Mar 19 09:49:12 2025
NOTE: ASM client szhxy1:szhxy disconnected unexpectedly.
NOTE: check client alert log.
NOTE: Trace records dumped in trace file /u01/app/grid/diag/asm/+asm/+ASM1/trace/+ASM1_ora_20940.trc



[oracle@rac1 ~]$ tail -f /u01/app/oracle/cfgtoollogs/dbca/szhxy/trace.log


[Thread-175] [ 2025-03-19 09:42:36.367 CST ] [PostDBCreationStep.executeImpl:885]  Starting Database HA Resource
[Thread-175] [ 2025-03-19 09:49:28.460 CST ] [CRSNative.internalStartResource:389]  Failed to start resource: Name: ora.szhxy.db, node: null, filter: null, msg CRS-5017: The resource action "ora.szhxy.db start" encountered the following error:
ORA-03113: end-of-file on communication channel
Process ID: 20968
Session ID: 2983 Serial number: 1
. For details refer to "(:CLSN00107:)" in "/u01/app/11.2.0/grid/log/rac1/agent/crsd/oraagent_oracle/oraagent_oracle.log".

CRS-2674: Start of 'ora.szhxy.db' on 'rac1' failed
CRS-2632: There are no more servers to try to place resource 'ora.szhxy.db' on that would satisfy its placement policy
[Thread-175] [ 2025-03-19 09:49:28.460 CST ] [PostDBCreationStep.executeImpl:893]  Exception while Starting with HA Database Resource PRCR-1079 : Failed to start resource ora.szhxy.db
CRS-5017: The resource action "ora.szhxy.db start" encountered the following error:
ORA-03113: end-of-file on communication channel
Process ID: 20968
Session ID: 2983 Serial number: 1
. For details refer to "(:CLSN00107:)" in "/u01/app/11.2.0/grid/log/rac1/agent/crsd/oraagent_oracle/oraagent_oracle.log".

CRS-2674: Start of 'ora.szhxy.db' on 'rac1' failed
CRS-2632: There are no more servers to try to place resource 'ora.szhxy.db' on that would satisfy its placement policy
^C
[oracle@rac1 szhxy]$ tail -f trace.log
CRS-2632: There are no more servers to try to place resource 'ora.szhxy.db' on that would satisfy its placement policy
[Thread-175] [ 2025-03-19 09:49:28.460 CST ] [PostDBCreationStep.executeImpl:893]  Exception while Starting with HA Database Resource PRCR-1079 : Failed to start resource ora.szhxy.db
CRS-5017: The resource action "ora.szhxy.db start" encountered the following error:
ORA-03113: end-of-file on communication channel
Process ID: 20968
Session ID: 2983 Serial number: 1
. For details refer to "(:CLSN00107:)" in "/u01/app/11.2.0/grid/log/rac1/agent/crsd/oraagent_oracle/oraagent_oracle.log".

CRS-2674: Start of 'ora.szhxy.db' on 'rac1' failed
CRS-2632: There are no more servers to try to place resource 'ora.szhxy.db' on that would satisfy its placement policy






[root@rac1 ~]# tail -f /u01/app/11.2.0/grid/log/rac1/agent/crsd/oraagent_oracle/oraagent_oracle.log 


2025-03-19 09:49:33.779: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstConnection::connectInt: server not attached
2025-03-19 09:49:33.792: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ORA-01034: ORACLE not available
ORA-27101: shared memory realm does not exist
Linux-x86_64 Error: 2: No such file or directory
Process ID: 0
Session ID: 0 Serial number: 0

2025-03-19 09:49:33.793: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstConnection::connectInt (2) Exception OCIException
2025-03-19 09:49:33.793: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstConnection:connect:excp OCIException OCI error 1034
2025-03-19 09:49:33.793: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstAgent::stop: connect1 errcode 1034
2025-03-19 09:49:33.793: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstAgent::stop: connect2 oracleHome /u01/app/oracle/product/11.2.0/db_1 oracleSid szhxy1
2025-03-19 09:49:33.793: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstConnection::connectInt: server not attached
2025-03-19 09:49:33.806: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstConnection:connectInt connected
2025-03-19 09:49:33.806: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstConnection::shutdown mode 4
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection connection count 1
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection sid  szhxy1, InstConnection 80009220
2025-03-19 09:49:33.807: [ USRTHRD][2654983936]{1:42527:1887} InstConnection::breakCall pConnxn:80009220  DetachLock:00ae3228 m_pSvcH:80089170
2025-03-19 09:49:33.807: [ USRTHRD][2654983936]{1:42527:1887} InstConnection:~InstConnection: this 80009220
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection delete InstConnection 80009220
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection freed 1
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::stopConnection
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection connection count 0
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection freed 0
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::stopConnection sid szhxy1 status  1
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] InstAgent::stop db/asm
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::stopConnection
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection connection count 0
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::removeConnection freed 0
2025-03-19 09:49:33.807: [ora.szhxy.db][2654983936]{1:42527:1887} [clean] ConnectionPool::stopConnection sid szhxy1 status  1
2025-03-19 09:49:33.808: [ora.szhxy.db][2654983936]{1:42527:1887} [check] InstAgent::check 1 prev clsagfw_res_status 2 current clsagfw_res_status 1
2025-03-19 09:49:38.808: [ora.szhxy.db][2654983936]{1:42527:1887} [check] InstAgent::check prev clsagfw_res_status 1 current clsagfw_res_status 1
2025-03-19 09:49:38.808: [    AGFW][2652882688]{1:42527:1887} ora.szhxy.db 1 1 state changed from: CLEANING to: OFFLINE
2025-03-19 09:49:38.808: [    AGFW][2652882688]{1:42527:1887} Agent sending last reply for: RESOURCE_CLEAN[ora.szhxy.db 1 1] ID 4100:26430
2025-03-19 09:49:38.809: [    AGFW][2652882688]{1:42527:1887} Agent has no resources to be monitored, Shutting down ..
2025-03-19 09:49:38.809: [    AGFW][2652882688]{1:42527:1887} Agent sending message to PE: AGENT_SHUTDOWN_REQUEST[Proxy] ID 20486:28
2025-03-19 09:49:38.810: [    AGFW][2652882688]{1:42527:1887} Agent is shutting down.
2025-03-19 09:49:38.810: [    AGFW][2652882688]{1:42527:1887} Agent is exiting with exit code: 1





[oracle@rac1 trace]$ tail -f /u01/app/oracle/diag/rdbms/szhxy/szhxy1/trace/alert_szhxy1.log
Starting background process GTX0
Wed Mar 19 09:43:01 2025
GTX0 started with pid=49, OS id=21029
Starting background process RCBG
Wed Mar 19 09:43:01 2025
RCBG started with pid=50, OS id=21031
replication_dependency_tracking turned off (no async multimaster replication found)
Starting background process QMNC
Wed Mar 19 09:43:02 2025
QMNC started with pid=51, OS id=21035


Wed Mar 19 09:48:17 2025
IPC Send timeout detected. Receiver ospid 20899 [
Wed Mar 19 09:48:17 2025
Errors in file /u01/app/oracle/diag/rdbms/szhxy/szhxy1/trace/szhxy1_lms3_20899.trc:
Wed Mar 19 09:49:07 2025
Detected an inconsistent instance membership by instance 2
Wed Mar 19 09:49:08 2025
Received an instance abort message from instance 2
Please check instance 2 alert and LMON trace files for detail.
LMD0 (ospid: 20885): terminating the instance due to error 481
Wed Mar 19 09:49:08 2025
System state dump requested by (instance=1, osid=20885 (LMD0)), summary=[abnormal instance termination].
System State dumped to trace file /u01/app/oracle/diag/rdbms/szhxy/szhxy1/trace/szhxy1_diag_20873_20250319094908.trc
Dumping diagnostic data in directory=[cdmp_20250319094908], requested by (instance=1, osid=20885 (LMD0)), summary=[abnormal instance termination].
Instance terminated by LMD0, pid = 20885

[oracle@rac2 ~]$ tail -100f /u01/app/oracle/diag/rdbms/szhxy/szhxy2/trace/alert_szhxy2.log
minact-scn: Inst 2 is a slave inc#:4 mmon proc-id:60124 status:0x2
minact-scn status: grec-scn:0x0000.00000000 gmin-scn:0x0000.00000000 gcalc-scn:0x0000.00000000
Wed Mar 19 09:48:17 2025
IPC Send timeout detected. Sender: ospid 60086 [oracle@rac2 (LMS3)]
Receiver: inst 1 binc 435183027 ospid 20899
IPC Send timeout to 1.4 inc 4 for msg type 65521 from opid 16
Wed Mar 19 09:48:19 2025
Communications reconfiguration: instance_number 1
Wed Mar 19 09:49:08 2025
Detected an inconsistent instance membership by instance 2
Evicting instance 1 from cluster
Waiting for instances to leave: 1
Wed Mar 19 09:49:08 2025
Dumping diagnostic data in directory=[cdmp_20250319094908], requested by (instance=1, osid=20885 (LMD0)), summary=[abnormal instance termination].
Reconfiguration started (old inc 4, new inc 8)
List of instances:
 2 (myinst: 2)
 Global Resource Directory frozen
 * dead instance detected - domain 0 invalid = TRUE
 Communication channels reestablished
 Master broadcasted resource hash value bitmaps
 Non-local Process blocks cleaned out
Wed Mar 19 09:49:08 2025
Wed Mar 19 09:49:08 2025
 LMS 1: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
 LMS 3: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
Wed Mar 19 09:49:08 2025
 LMS 2: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
Wed Mar 19 09:49:08 2025
 LMS 0: 0 GCS shadows cancelled, 0 closed, 0 Xw survived
 Set master node info
 Submitted all remote-enqueue requests
 Dwn-cvts replayed, VALBLKs dubious
 All grantable enqueues granted
 Post SMON to start 1st pass IR
Wed Mar 19 09:49:08 2025
minact-scn: Inst 2 is now the master inc#:8 mmon proc-id:60124 status:0x7
minact-scn status: grec-scn:0x0000.00000000 gmin-scn:0x0000.00000000 gcalc-scn:0x0000.00000000
minact-scn: master found reconf/inst-rec before recscn scan old-inc#:8 new-inc#:8
Wed Mar 19 09:49:08 2025
Instance recovery: looking for dead threads
Beginning instance recovery of 1 threads
 Submitted all GCS remote-cache requests
 Post SMON to start 1st pass IR
 Fix write in gcs resources
Reconfiguration complete
 parallel recovery started with 32 processes
Started redo scan
Completed redo scan
 read 33 KB redo, 5 data blocks need recovery
Started redo application at
 Thread 1: logseq 3, block 33827
Recovery of Online Redo Log: Thread 1 Group 5 Seq 3 Reading mem 0
  Mem# 0: +DATA/szhxy/onlinelog/group_5.263.1196156449
  Mem# 1: +FRA/szhxy/onlinelog/group_5.259.1196156451
Completed redo application of 0.01MB
Completed instance recovery at
 Thread 1: logseq 3, block 33893, scn 986547
 4 data blocks read, 4 data blocks written, 33 redo k-bytes read

[oracle@rac1 trace]$ cat ~/.bash_profile
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1
export ORACLE_SID=szhxy1
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
[oracle@rac1 trace]$ pwd
/u01/app/oracle/diag/rdbms/szhxy/szhxy1/trace
[oracle@rac1 trace]$


[oracle@rac2 ~]$ cat .bash_profile
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1
export ORACLE_SID=szhxy2
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
[oracle@rac2 ~]$

[grid@rac1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.FRA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1
ora.cvu
      1        ONLINE  ONLINE       rac1
ora.oc4j
      1        ONLINE  ONLINE       rac1
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac1
ora.szhxy.db
      1        ONLINE  OFFLINE
      2        ONLINE  ONLINE       rac2                     Open
[grid@rac1 ~]$

[grid@rac1 ~]$ srvctl status database -d szhxy
Instance szhxy1 is not running on node rac1
Instance szhxy2 is running on node rac2
[grid@rac1 ~]$

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
db_recovery_file_dest_size           big integer 500000M
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
---------- ------- ----------------------------------------------------------------------------------------------------
	 1 ONLINE  +FRA/szhxy/onlinelog/group_1.257.1093116751
	 1 ONLINE  +DATA/szhxy/onlinelog/group_1.261.1093116751
	 2 ONLINE  +DATA/szhxy/onlinelog/group_2.262.1093116751
	 2 ONLINE  +FRA/szhxy/onlinelog/group_2.258.1093116751
	 3 ONLINE  +DATA/szhxy/onlinelog/group_3.266.1093116853
	 3 ONLINE  +FRA/szhxy/onlinelog/group_3.260.1093116853
	 4 ONLINE  +DATA/szhxy/onlinelog/group_4.267.1093116853
	 4 ONLINE  +FRA/szhxy/onlinelog/group_4.261.1093116853
	 5 ONLINE  +DATA/szhxy/onlinelog/group_5.263.1093116753
	 5 ONLINE  +FRA/szhxy/onlinelog/group_5.259.1093116753
	 6 ONLINE  +FRA/szhxy/onlinelog/group_6.262.1093116853
	 6 ONLINE  +DATA/szhxy/onlinelog/group_6.268.1093116853

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

TABLESPACE_NAME 	       FILE_NAME						  MB
------------------------------ -------------------------------------------------- ----------
SYSAUX			       +DATA/szhxy/datafile/sysaux.257.1093116677		 540
SYSTEM			       +DATA/szhxy/datafile/system.256.1093116677		 740
UNDOTBS1		       +DATA/szhxy/datafile/undotbs1.258.1093116677		  95
UNDOTBS2		       +DATA/szhxy/datafile/undotbs2.265.1093116795		  25
USERS			       +DATA/szhxy/datafile/users.259.1093116677 		   5
```
### 7.3.查看集群状态

#rac1服务器执行
```bash
#设置集群自动启动
su - root
. oraenv
--->+ASM1/+ASM2

crsctl enable crs

#集群状态
su - grid
crsctl status resource -t

#asm
srvctl status asm

asmcmd
lsdg
#数据库
srvctl status database -d szhxy
#监听
lsnrctl status
#外部连接数据库
sqlplus test/test@scanIP:1521/szhxy
#比如
sqlplus test/test@192.168.10.56:1521/szhxy
```
#日志
```
[root@rac1 ~]# su - grid
Last login: Wed Dec 22 18:49:00 CST 2021 on pts/1
[grid@rac1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.FRA.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.OCR.dg
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.asm
               ONLINE  ONLINE       rac1                 Started             
               ONLINE  ONLINE       rac2                 Started             
ora.gsd
               OFFLINE OFFLINE      rac1                                     
               OFFLINE OFFLINE      rac2                                     
ora.net1.network
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
ora.ons
               ONLINE  ONLINE       rac1                                     
               ONLINE  ONLINE       rac2                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac1                                     
ora.cvu
      1        ONLINE  ONLINE       rac2                                     
ora.oc4j
      1        ONLINE  ONLINE       rac2                                     
ora.rac1.vip
      1        ONLINE  ONLINE       rac1                                     
ora.rac2.vip
      1        ONLINE  ONLINE       rac2                                     
ora.scan1.vip
      1        ONLINE  ONLINE       rac1                                     
ora.szhxy.db
      1        ONLINE  ONLINE       rac1                 Open                
      2        ONLINE  ONLINE       rac2                 Open    
[grid@rac1 ~]$ srvctl status asm
ASM is running on rac1,rac2
[grid@rac1 ~]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   3145728  3142816                0         3142816              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576    512000   510286                0          510286              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
ASMCMD> 

[grid@rac1 ~]$ srvctl status database -d szhxy
Instance szhxy1 is running on node rac1
Instance szhxy2 is running on node rac2

[grid@rac1 ~]$ lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 05-JAN-2022 11:22:04

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 11.2.0.4.0 - Production
Start Date                04-JAN-2022 18:53:14
Uptime                    0 days 16 hr. 28 min. 49 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/11.2.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/11.2.0/grid/log/diag/tnslsnr/rac1/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.10.52)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.10.54)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "szhxy" has 1 instance(s).
  Instance "szhxy1", status READY, has 1 handler(s) for this service...
Service "szhxyXDB" has 1 instance(s).
  Instance "szhxy1", status READY, has 1 handler(s) for this service...
The command completed successfully
```

### 7.4.创建表空间、用户、表等测试

```oracle
create tablespace ntjw datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
alter tablespace ntjw add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user ntjw identified by ntjw default tablespace ntjw;
grant connect,resource to ntjw;

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
chmod a+x /home/oracle/backup/rmanbak.sh
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
expdp system/xxxx directory=expdir dumpfile=20241028.dmp logfile=20241028.log full=y parallel=4 cluster=N
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

dmpfilename=full_db_$time.dmp
logfilename=full_db_$time.log

echo start expdp $dmpfilename ... >> $expdp_dir/expdprun.log

expdp system/abc123 directory=expdir dumpfile=$dmpfilename logfile=$logfilename full=y  parallel=4 cluster=N

echo done expdp $dmpfilename ...  >> $expdp_dir/expdprun.log

#delete 30days before log 
echo start delete $logfilename ... >> $expdp_dir/expdprun.log
find $expdp_dir -name 'full_db_*.log' -mtime +30 -exec rm {} \;

#delete 30days before dmpfile 
echo start delete $dmpfilename ... >> $expdp_dir/expdprun.log
find $expdp_dir -name 'full_db_*.dmp' -mtime +30 -exec rm {} \;

echo done delete ...  >> $expdp_dir/expdprun.log
```
#设置调度任务
```bash
crontab -e

#每周日1:30开始执行
30 1 * * 0 /home/oracle/expdir/expdir.sh
```


## 9 日志位置
### 9.1.GI日志

```bash
/u01/app/11.2.0/grid/log/$hostname
```

### 9.2.oracle日志

```bash
/u01/app/oracle/product/11.2.0/db_1/log
```

