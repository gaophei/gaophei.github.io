**19C RAC for Centos7.9 安装手册华三超融合-无网卡绑定多路径-东大秦皇岛**

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
grid/FG2jc62xwucD
oracle/L2jc4l2MAucl

sys/
system/Oracle2023#Sys
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
###学校实际参数
```
[root@rac01 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
vdf         251:80   0     2T  0 disk
vdd         251:48   0   100G  0 disk
└─vdd1      251:49   0   100G  0 part
vdb         251:16   0   100G  0 disk
└─vdb1      251:17   0   100G  0 part
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
vde         251:64   0     2T  0 disk
vdc         251:32   0   100G  0 disk
└─vdc1      251:33   0   100G  0 part
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk

[root@rac02 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
vdf         251:80   0     2T  0 disk
vdd         251:48   0   100G  0 disk
└─vdd1      251:49   0   100G  0 part
vdb         251:16   0   100G  0 disk
└─vdb1      251:17   0   100G  0 part
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
vde         251:64   0     2T  0 disk
vdc         251:32   0   100G  0 disk
└─vdc1      251:33   0   100G  0 part
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk

#因为使用的是深信服CAS虚拟化平台，无法支持scsi分区磁盘，故无法使用udev，只能采用oracleasm管理磁盘
[root@rac01 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

[root@rac02 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

----------------------
#其他正常学校应该是这样：
[root@rac01 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 36000c290895fb077d085d625b053999c
/dev/sdb 36000c29c7593c00dd6020d68c379af8b
/dev/sdc 36000c29191410ca350a65dd4d2ab87f9
/dev/sdd 36000c29c8ff162cd8141ad12e89e4f67
/dev/sde 36000c2901faead7b7f181d282cf639ac
/dev/sdf 36000c293747331cfc85e8d668f728f4d
/dev/sdg 36000c2979ccf579f7c2c288b3d645e50
/dev/sdh 36000c290d12b15a3bdece97e79c7a665
[root@rac01 ~]# lsblk
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
[root@rac01 ~]#


[root@rac02 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
36000c29191410ca350a65dd4d2ab87f9
[root@rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 36000c29a15618293a78d56ceb841c184
/dev/sdb 36000c29c7593c00dd6020d68c379af8b
/dev/sdc 36000c29191410ca350a65dd4d2ab87f9
/dev/sdd 36000c29c8ff162cd8141ad12e89e4f67
/dev/sde 36000c2901faead7b7f181d282cf639ac
/dev/sdf 36000c293747331cfc85e8d668f728f4d
/dev/sdg 36000c2979ccf579f7c2c288b3d645e50
/dev/sdh 36000c290d12b15a3bdece97e79c7a665
[root@rac02 ~]# lsblk
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
[root@rac02 ~]#
---------------------------------
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
[root@rac01 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.20.12.1      0.0.0.0         UG    100    0        0 eth0
0.0.0.0         10.20.24.1      0.0.0.0         UG    101    0        0 eth1
10.20.12.0      0.0.0.0         255.255.255.0   U     100    0        0 eth0
10.20.24.0      0.0.0.0         255.255.255.0   U     101    0        0 eth1
192.168.122.0   0.0.0.0         255.255.255.0   U     0      0        0 virbr0
[root@rac01 ~]# ip route list
default via 10.20.12.1 dev eth0 proto static metric 100
default via 10.20.24.1 dev eth1 proto static metric 101
10.20.12.0/24 dev eth0 proto kernel scope link src 10.20.12.118 metric 100
10.20.24.0/24 dev eth1 proto kernel scope link src 10.20.24.250 metric 101
192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1 linkdown
[root@rac01 ~]# nmcli con show
NAME    UUID                                  TYPE      DEVICE
eth0    bdc16ef2-d1d0-4c97-889c-961adfa53039  ethernet  eth0
eth1    d5d1bda3-c00f-484f-b818-e68b5023dbc7  ethernet  eth1
virbr0  095e850f-a527-4866-85ca-b6ecbcaac7de  bridge    virbr0


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
[root@rac02 ~]# ip route list
default via 10.20.12.1 dev eth0 proto static metric 100
default via 10.20.24.1 dev eth1 proto static metric 101
10.20.12.0/24 dev eth0 proto kernel scope link src 10.20.12.119 metric 100
10.20.24.0/24 dev eth1 proto kernel scope link src 10.20.24.251 metric 101
[root@rac02 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE
eth0  5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03  ethernet  eth0
eth1  9c92fad9-6ecb-3e6c-eb4d-8a47c6f50c04  ethernet  eth1




[grid@rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       rac01
               ONLINE  ONLINE       rac02
ora.FRA.dg
               ONLINE  ONLINE       rac01
               ONLINE  ONLINE       rac02
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac01
               ONLINE  ONLINE       rac02
ora.OCR.dg
               ONLINE  ONLINE       rac01
               ONLINE  ONLINE       rac02
ora.asm
               ONLINE  ONLINE       rac01                  Started
               ONLINE  ONLINE       rac02                  Started
ora.gsd
               OFFLINE OFFLINE      rac01
               OFFLINE OFFLINE      rac02
ora.net1.network
               ONLINE  ONLINE       rac01
               ONLINE  ONLINE       rac02
ora.ons
               ONLINE  ONLINE       rac01
               ONLINE  ONLINE       rac02
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac01
ora.cvu
      1        ONLINE  ONLINE       rac01
ora.oc4j
      1        ONLINE  ONLINE       rac01
ora.scan1.vip
      1        ONLINE  ONLINE       rac01
ora.rac01.vip
      1        ONLINE  ONLINE       rac01
ora.rac02.vip
      1        ONLINE  ONLINE       rac02
ora.xydb.db
      1        ONLINE  ONLINE       rac01                  Open
      2        ONLINE  ONLINE       rac02                  Open
[grid@rac01 ~]$


```
#网卡配置及多路径配置
```bash
ifconfig
nmcli conn show

#默认是NetworkManager管理网络
[root@rac01 ~]# systemctl status network
● network.service - LSB: Bring up/down networking
   Loaded: loaded (/etc/rc.d/init.d/network; bad; vendor preset: disabled)
   Active: active (exited) since Mon 2023-09-25 10:00:21 CST; 52min ago
     Docs: man:systemd-sysv-generator(8)

Sep 25 10:00:21 rac01 systemd[1]: Starting LSB: Bring up/down networking...
Sep 25 10:00:21 rac01 network[1378]: Bringing up loopback interface:  [  OK  ]
Sep 25 10:00:21 rac01 network[1378]: Bringing up interface eth0:  [  OK  ]
Sep 25 10:00:21 rac01 network[1378]: Bringing up interface eth1:  [  OK  ]
Sep 25 10:00:21 rac01 systemd[1]: Started LSB: Bring up/down networking.
[root@rac01 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2023-09-25 10:00:21 CST; 52min ago
     Docs: man:NetworkManager(8)
 Main PID: 1282 (NetworkManager)
   CGroup: /system.slice/NetworkManager.service
           └─1282 /usr/sbin/NetworkManager --no-daemon

Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3098] device (virbr0-nic): Activation: connection 'virbr0-nic' enslaved, contin...tivation
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3100] device (virbr0-nic): state change: ip-config -> ip-check (reason 'none', ...ternal')
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3104] device (virbr0): state change: secondaries -> activated (reason 'none', s...ternal')
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3135] device (virbr0): Activation: successful, device activated.
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3139] device (virbr0-nic): state change: ip-check -> secondaries (reason 'none'...ternal')
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3141] device (virbr0-nic): state change: secondaries -> activated (reason 'none...ternal')
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3161] device (virbr0-nic): Activation: successful, device activated.
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3382] device (virbr0-nic): state change: activated -> unmanaged (reason 'connec...ternal')
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3387] device (virbr0): bridge port virbr0-nic was detached
Sep 25 10:00:23 rac01 NetworkManager[1282]: <info>  [1695607223.3387] device (virbr0-nic): released from master device virbr0
Hint: Some lines were ellipsized, use -l to show in full.
[root@rac01 ~]#

[root@rac01 ~]#  nmcli dev
DEVICE      TYPE      STATE      CONNECTION
eth0        ethernet  connected  eth0
eth1        ethernet  connected  eth1
virbr0      bridge    connected  virbr0
lo          loopback  unmanaged  --
virbr0-nic  tun       unmanaged  --


[root@rac02 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE
eth0  5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03  ethernet  eth0
eth1  9c92fad9-6ecb-3e6c-eb4d-8a47c6f50c04  ethernet  eth1

---------------
[root@rac02 ~]# systemctl status network
● network.service - LSB: Bring up/down networking
   Loaded: loaded (/etc/rc.d/init.d/network; bad; vendor preset: disabled)
   Active: active (exited) since Mon 2023-09-25 10:00:19 CST; 55min ago
     Docs: man:systemd-sysv-generator(8)
  Process: 1262 ExecStart=/etc/rc.d/init.d/network start (code=exited, status=0/SUCCESS)

Sep 25 10:00:19 rac02 systemd[1]: Starting LSB: Bring up/down networking...
Sep 25 10:00:19 rac02 network[1262]: Bringing up loopback interface:  [  OK  ]
Sep 25 10:00:19 rac02 network[1262]: Bringing up interface eth0:  [  OK  ]
Sep 25 10:00:19 rac02 network[1262]: Bringing up interface eth1:  [  OK  ]
Sep 25 10:00:19 rac02 systemd[1]: Started LSB: Bring up/down networking.
[root@rac02 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2023-09-25 10:00:19 CST; 55min ago
     Docs: man:NetworkManager(8)
 Main PID: 1209 (NetworkManager)
   CGroup: /system.slice/NetworkManager.service
           └─1209 /usr/sbin/NetworkManager --no-daemon

Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6568] device (eth0): state change: ip-check -> secondaries (reason 'none', sys-...anaged')
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6569] device (eth1): state change: ip-check -> secondaries (reason 'none', sys-...anaged')
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6571] device (eth0): state change: secondaries -> activated (reason 'none', sys...anaged')
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6609] manager: NetworkManager state is now CONNECTED_SITE
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6610] policy: set 'eth0' (eth0) as default for IPv4 routing and DNS
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6629] device (eth0): Activation: successful, device activated.
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6633] manager: NetworkManager state is now CONNECTED_GLOBAL
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6637] device (eth1): state change: secondaries -> activated (reason 'none', sys...anaged')
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6657] device (eth1): Activation: successful, device activated.
Sep 25 10:00:19 rac02 NetworkManager[1209]: <info>  [1695607219.6663] manager: startup complete
Hint: Some lines were ellipsized, use -l to show in full.
[root@rac02 ~]# nmcli dev
DEVICE  TYPE      STATE      CONNECTION
eth0    ethernet  connected  eth0
eth1    ethernet  connected  eth1
lo      loopback  unmanaged  --
[root@rac02 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE
eth0  5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03  ethernet  eth0
eth1  9c92fad9-6ecb-3e6c-eb4d-8a47c6f50c04  ethernet  eth1
```

#网卡绑定---无

```
假如网卡绑定，本次没有网卡绑定：
#eno8为私有网卡
#ens3f0和ens3f1d1绑定为team0为业务网卡
```
#节点一rac01
```bash
nmcli con mod eno8 ipv4.addresses 10.20.24.250/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '10.20.12.118/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#节点二rac02
```bash
nmcli con mod eno8 ipv4.addresses 10.20.24.251/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '10.20.12.118/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
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
[root@rac02 ~]# cat /etc/multipath/
bindings  wwids     
[root@rac02 ~]# cat /etc/multipath/bindings 
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
[root@rac02 ~]# cat /etc/multipath/wwids 
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

[root@rac02 ~]# sfdisk -s|grep mpath
/dev/mapper/mpatha: 104857600
/dev/mapper/mpathb: 104857600
/dev/mapper/mpathc: 104857600
/dev/mapper/mpathd: 2147483648
/dev/mapper/mpathe: 2147483648
/dev/mapper/mpathf: 2147483648
/dev/mapper/mpathg: 2147483648

[root@rac01 ~]# multipathd show maps
name   sysfs uuid
mpatha dm-2  24c740a67e89393fa6c9ce90079a4df08
mpathb dm-3  2bf57071b2488dae06c9ce90079a4df08
mpathc dm-4  2ee6c414e797cb16f6c9ce90079a4df08
mpathd dm-5  2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe dm-6  2086fa4c938d839c66c9ce90079a4df08
mpathf dm-7  27b44daa76accbc526c9ce90079a4df08
mpathg dm-8  2aa67dbb0c9c0573b6c9ce90079a4df08
```

## 2.准备工作（rac01 与 rac02 同时配置）

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

#root/AZlm92c2YeVc!
#root1/Jile2dx49OmUne
#oracle/L2jc4l2MAucl
#grid/FG2jc62xwucD
```
### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#rac01
hostnamectl set-hostname rac01
#rac02
hostnamectl set-hostname rac02

cat >> /etc/hosts <<EOF
#public ip 
10.20.12.118 rac01
10.20.12.119 rac02
#vip
10.20.12.132 rac01-vip
10.20.12.133 rac02-vip
#private ip
10.20.24.250 rac01-prv
10.20.24.251 rac02-prv
#scan ip
10.20.12.134 rac-scan
EOF

```
### 2.5. 禁用 NTP

#检查两节点时间，时区是否相同，并禁止 ntp
```bash
systemctl disable ntpd.service
systemctl stop ntpd.service
mv /etc/ntp.conf /etc/ntp.conf.orig
[root@rac01 ~]# systemctl disable ntpd.service
Failed to execute operation: No such file or directory
[root@rac01 ~]# systemctl stop ntpd.service
Failed to stop ntpd.service: Unit ntpd.service not loaded.

systemctl status ntpd

systemctl disable chronyd
systemctl stop chronyd
mv /etc/chrony.conf /etc/chrony.conf.bak

systemctl status chronyd

ntpdate pool.ntp.org
```
#时区设置
```bash
#查看是否中国时区
date -R 
timedatectl
clockdiff rac01
clockdiff rac02

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
[root@rac01 ~]# grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
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

#grid用户，注意rac01/rac02两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意rac02修改
#export ORACLE_SID=+ASM2
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
#oracle用户，注意rac01/rac02的区别
```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/db_1
export ORACLE_SID=xydb1
#注意rac02修改
#export ORACLE_SID=xydb2
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
EOF

```
### 2.9. 配置共享磁盘权限

#### 2.9.1.无多路径模式

#适用于vsphere平台直接共享存储磁盘

#检查磁盘UUID
```bash
sfdisk -s
##由于H3C CAS虚拟化平台磁盘类型中没有scsi类型，导致不支持scsi_id命令识别磁盘，只能使用udevadm查看，而学校暂不支持改为裸块加入iscsi高速硬盘
##所以本次采用oracle asmlib管理磁盘
#/usr/lib/udev/scsi_id -g -u -d devicename
ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; udevadm info --query=all --name=$disk|grep ID_SERIAL ; done
```
#显示如下
```
[root@rac01 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

[root@rac02 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

[root@rac01 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while reao -n "$disk " ; udevadm info --query=all --name=$disk|grep ID_SERIAL ; done
/dev/vda E: ID_SERIAL=eb92085afa8ebc23bcc3
/dev/vdb E: ID_SERIAL=3593a94f-a31f-4d7b-b
/dev/vdc E: ID_SERIAL=eb1c103a-5f28-45ce-b
/dev/vdd E: ID_SERIAL=5bcd6fdf-4392-44b9-b
/dev/vde E: ID_SERIAL=30b3ad90-22be-4c64-b
/dev/vdf E: ID_SERIAL=e1e86d49-3af4-4fca-9
/dev/vdg E: ID_SERIAL=5cdf69bc-f360-48ff-a
/dev/vdh E: ID_SERIAL=e1cc3e2f-3e84-40ed-9
/dev/vdi E: ID_SERIAL=56d34c45-fc52-447d-b
/dev/vdj E: ID_SERIAL=0f74d06e-baaf-42cd-a

[root@rac02 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while reao -n "$disk " ; udevadm info --query=all --name=$disk|grep ID_SERIAL ; done
/dev/vda E: ID_SERIAL=0cc5a0c66b566e7a9f60
/dev/vdb E: ID_SERIAL=3593a94f-a31f-4d7b-b
/dev/vdc E: ID_SERIAL=eb1c103a-5f28-45ce-b
/dev/vdd E: ID_SERIAL=5bcd6fdf-4392-44b9-b
/dev/vde E: ID_SERIAL=30b3ad90-22be-4c64-b
/dev/vdf E: ID_SERIAL=e1e86d49-3af4-4fca-9
/dev/vdg E: ID_SERIAL=5cdf69bc-f360-48ff-a
/dev/vdh E: ID_SERIAL=e1cc3e2f-3e84-40ed-9
/dev/vdi E: ID_SERIAL=56d34c45-fc52-447d-b
/dev/vdj E: ID_SERIAL=0f74d06e-baaf-42cd-a


[root@rac01 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
vdf         251:80   0     2T  0 disk
vdd         251:48   0   100G  0 disk
vdb         251:16   0   100G  0 disk
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
vde         251:64   0     2T  0 disk
vdc         251:32   0   100G  0 disk
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk

[root@rac02 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
vdf         251:80   0     2T  0 disk
vdd         251:48   0   100G  0 disk
vdb         251:16   0   100G  0 disk
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
vde         251:64   0     2T  0 disk
vdc         251:32   0   100G  0 disk
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk

```
#oracleasm管理磁盘

```bash
#格式化存储分区：仅rac01执行！
       ##2T以上磁盘分区用parted，2T以下分区用fdisk，ASM管理磁盘只支持最大2T的分区加入卷
       fdisk -l
       
       fdisk /dev/vdb
       fdisk /dev/vdc
       fdisk /dev/vdd
       
       fdisk /dev/vde
       fdisk /dev/vdf
       fdisk /dev/vdg
       
       fdisk /dev/vdh
       fdisk /dev/vdi
       fdisk /dev/vdj       
       fdisk  -l
---------------------------------------------------
m--->n--->p--->1--->默认值回车--->默认值回车--->w
----------------------------------------------------


#如果不格式化磁盘，那么会报错：
oracleasm createdisk DATA1 /dev/vde
Device "/dev/vde" is not a partition


[root@rac01 ~]# mount /dev/sr0 /mnt
[root@rac01 ~]# cd /mnt/Packages

[root@rac01 Packages]# ls -lrth|grep oracleasm
-rw-rw-r-- 1 1039 1039   85K Feb  4  2018 oracleasm-support-2.1.11-2.el7.x86_64.rpm
-rw-rw-r-- 1 1039 1039  298K May 29  2020 kmod-oracleasm-2.0.8-28.0.1.el7.x86_64.rpm

#安装并配置asm:----root账户下
#安装kmod-oracleasm/oracleasmlib/oracleasm-support，注意安装顺序：
     yum -y install kmod-oracleasm
     rpm -ivh oracleasmlib-
     rpm -ivh oracleasm-support-

yum install kmod-oracleasm-2.0.8-28.0.1.el7.x86_64.rpm oracleasmlib-2.0.12-1.el7.x86_64.rpm oracleasm-support-2.1.11-2.el7.x86_64.rpm

# rpm -qa|grep oracleasm
oracleasmlib-2.0.12-1.el7.x86_64
oracleasm-support-2.1.11-2.el7.x86_64
kmod-oracleasm-2.0.8-28.0.1.el7.x86_64

#安装完成后配置asmlib使用如下命令：
     oracleasm --help
     #设置asmlib
     oracleasm configure -i
     grid-->asmadmin-->y-->y---->done
     #载入asm模块
     oracleasm init
     #创建ASM磁盘----仅rac01执行！
     oracleasm createdisk OCR1 /dev/vdb1
     oracleasm createdisk OCR2 /dev/vdc1
     oracleasm createdisk OCR3 /dev/vdd1
     
     oracleasm createdisk data01 /dev/vde1
     oracleasm createdisk data02 /dev/vdf1
     oracleasm createdisk data03 /dev/vdg1
     
     oracleasm createdisk fra01 /dev/vdh1
     oracleasm createdisk fra02 /dev/vdi1
     oracleasm createdisk fra03 /dev/vdj1
     
     oracleasm listdisks
     cd /dev/oracleasm/disks/
     ls -lrth
     oracleasm querydisk -p OCR1
     ......
     oracleasm querydisk -p FRA03
     
    #扫描ASM磁盘---rac02执行
     oracleasm scandisks
    #查看ASM磁盘
     oracleasm listdisks
     cd /dev/oracleasm/disks/
     ls -lrth
     oracleasm querydisk -p OCR1
     ......
     oracleasm querydisk -p FRA03
     
#重启，测试
reboot
oracleasm status
```

#asmlib配置日志

```bash
#rac01:
[root@rac01 Packages]# oracleasm configure -i
Configuring the Oracle ASM library driver.

This will configure the on-boot properties of the Oracle ASM library
driver.  The following questions will determine whether the driver is
loaded on boot and what permissions it will have.  The current values
will be shown in brackets ('[]').  Hitting <ENTER> without typing an
answer will keep that current value.  Ctrl-C will abort.

Default user to own the driver interface []: grid
Default group to own the driver interface []: asmadmin
Start Oracle ASM library driver on boot (y/n) [n]: y
Scan for Oracle ASM disks on boot (y/n) [y]: y
Writing Oracle ASM library driver configuration: done

[root@rac01 ~]# reboot

[root@rac01 ~]# oracleasm status
Checking if ASM is loaded: yes
Checking if /dev/oracleasm is mounted: yes

#rac02:
[root@rac02 ~]# oracleasm configure -i
Configuring the Oracle ASM library driver.

This will configure the on-boot properties of the Oracle ASM
driver.  The following questions will determine whether the d
loaded on boot and what permissions it will have.  The curren
will be shown in brackets ('[]').  Hitting <ENTER> without ty
answer will keep that current value.  Ctrl-C will abort.

Default user to own the driver interface []: grid
Default group to own the driver interface []: asmadmin
Start Oracle ASM library driver on boot (y/n) [n]: y
Scan for Oracle ASM disks on boot (y/n) [y]: y
Writing Oracle ASM library driver configuration: done

[root@rac02 ~]# reboot


[root@rac01 ~]# reboot

[root@rac02 ~]# oracleasm status
Checking if ASM is loaded: yes
Checking if /dev/oracleasm is mounted: yes

[root@rac01 ~]# fdisk -l

Disk /dev/vda: 1099.5 GB, 1099511627776 bytes, 2147483648 sec                                                                  tors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000031f0

   Device Boot      Start         End      Blocks   Id  Syste                                                                  m
/dev/vda1   *        2048     2099199     1048576   83  Linux
/dev/vda2         2099200  2147483647  1072692224   8e  Linux                                                                   LVM

Disk /dev/vdb: 107.4 GB, 107374182400 bytes, 209715200 sectors                                         
Disk /dev/vdc: 107.4 GB, 107374182400 bytes, 209715200 sectors                                         
Disk /dev/vdd: 107.4 GB, 107374182400 bytes, 209715200 sectors                                         

Disk /dev/vde: 2147.5 GB, 2147483648000 bytes, 4194304000 sectors
Disk /dev/vdf: 2147.5 GB, 2147483648000 bytes, 4194304000 sectors
Disk /dev/vdg: 2147.5 GB, 2147483648000 bytes, 4194304000 sectors

Disk /dev/vdh: 1610.6 GB, 1610612736000 bytes, 3145728000 sectors
Disk /dev/vdi: 1610.6 GB, 1610612736000 bytes, 3145728000 sectors
Disk /dev/vdj: 1610.6 GB, 1610612736000 bytes, 3145728000 sectors

Disk /dev/mapper/ol-root: 1064.1 GB, 1064073953280 bytes, 2078269440 sectors
Disk /dev/mapper/ol-swap: 34.4 GB, 34359738368 bytes, 67108864 sectors

[root@rac01 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
vdf         251:80   0     2T  0 disk
vdd         251:48   0   100G  0 disk
vdb         251:16   0   100G  0 disk
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
vde         251:64   0     2T  0 disk
vdc         251:32   0   100G  0 disk
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk

[root@rac01 ~]# oracleasm createdisk DATA01 /dev/vdb
Device "/dev/vdb" is not a partition


[root@rac01 ~]# fdisk /dev/vdb
[root@rac01 ~]# fdisk /dev/vdc
[root@rac01 ~]# fdisk /dev/vdd

[root@rac01 ~]# fdisk /dev/vde
Welcome to fdisk (util-linux 2.23.2).

Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table
Building a new DOS disklabel with disk identifier 0xb59a7a8a.

Command (m for help): m
Command action
   a   toggle a bootable flag
   b   edit bsd disklabel
   c   toggle the dos compatibility flag
   d   delete a partition
   g   create a new empty GPT partition table
   G   create an IRIX (SGI) partition table
   l   list known partition types
   m   print this menu
   n   add a new partition
   o   create a new empty DOS partition table
   p   print the partition table
   q   quit without saving changes
   s   create a new empty Sun disklabel
   t   change a partition's system id
   u   change display/entry units
   v   verify the partition table
   w   write table to disk and exit
   x   extra functionality (experts only)

Command (m for help): n
Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p): p
Partition number (1-4, default 1): 1
First sector (2048-4194303999, default 2048):
Using default value 2048
Last sector, +sectors or +size{K,M,G} (2048-4194303999, default 4194303999):
Using default value 4194303999
Partition 1 of type Linux and of size 2 TiB is set

Command (m for help): w
The partition table has been altered!

Calling ioctl() to re-read partition table.
Syncing disks.


[root@rac01 ~]# fdisk /dev/vdf
[root@rac01 ~]# fdisk /dev/vdg

[root@rac01 ~]# fdisk /dev/vdh
[root@rac01 ~]# fdisk /dev/vdi
[root@rac01 ~]# fdisk /dev/vdj

[root@rac01 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
└─vdh1      251:113  0   1.5T  0 part
vdf         251:80   0     2T  0 disk
└─vdf1      251:81   0     2T  0 part
vdd         251:48   0   100G  0 disk
└─vdd1      251:49   0   100G  0 part
vdb         251:16   0   100G  0 disk
└─vdb1      251:17   0   100G  0 part
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
└─vdi1      251:129  0   1.5T  0 part
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
└─vdg1      251:97   0     2T  0 part
vde         251:64   0     2T  0 disk
└─vde1      251:65   0     2T  0 part
vdc         251:32   0   100G  0 disk
└─vdc1      251:33   0   100G  0 part
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk
└─vdj1      251:145  0   1.5T  0 part

[root@rac01 dev]# oracleasm createdisk data01 /dev/vde1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk data02 /dev/vdf1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk data03 /dev/vdg1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]#
[root@rac01 dev]# oracleasm createdisk fra01 /dev/vdh1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk fra02 /dev/vdi1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk fra03 /dev/vdj1
Writing disk header: done
Instantiating disk: done

[root@rac01 dev]# oracleasm listdisks
DATA01
DATA02
DATA03
FRA01
FRA02
FRA03
OCR1
OCR2
OCR3


[root@rac01 ~]# cd /dev/oracleasm/disks/
[root@rac01 disks]# ls -lrth
total 0
brw-rw---- 1 grid asmadmin 251,  49 Sep 25 12:06 OCR3
brw-rw---- 1 grid asmadmin 251,  33 Sep 25 12:06 OCR2
brw-rw---- 1 grid asmadmin 251,  17 Sep 25 12:06 OCR1
brw-rw---- 1 grid asmadmin 251,  97 Sep 25 13:53 DATA03
brw-rw---- 1 grid asmadmin 251,  81 Sep 25 13:53 DATA02
brw-rw---- 1 grid asmadmin 251,  65 Sep 25 13:53 DATA01
brw-rw---- 1 grid asmadmin 251, 113 Sep 25 13:54 FRA01
brw-rw---- 1 grid asmadmin 251, 129 Sep 25 13:54 FRA02
brw-rw---- 1 grid asmadmin 251, 145 Sep 25 13:54 FRA03

[root@rac01 ~]#  oracleasm querydisk -p OCR1
Disk "OCR1" is a valid ASM disk
/dev/vdb1: LABEL="OCR1" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p OCR2
Disk "OCR2" is a valid ASM disk
/dev/vdc1: LABEL="OCR2" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p OCR3
Disk "OCR3" is a valid ASM disk
/dev/vdd1: LABEL="OCR3" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p DATA01
Disk "DATA01" is a valid ASM disk
/dev/vde1: LABEL="DATA01" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p DATA02
Disk "DATA02" is a valid ASM disk
/dev/vdf1: LABEL="DATA02" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p DATA03
Disk "DATA03" is a valid ASM disk
/dev/vdg1: LABEL="DATA03" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p FRA01
Disk "FRA01" is a valid ASM disk
/dev/vdh1: LABEL="FRA01" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p FRA02
Disk "FRA02" is a valid ASM disk
/dev/vdi1: LABEL="FRA02" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p FRA03
Disk "FRA03" is a valid ASM disk
/dev/vdj1: LABEL="FRA03" TYPE="oracleasm"

[root@rac01 ~]# tail -f /var/log/message
Sep 25 14:13:32 rac01 kernel: blk_update_request: I/O error, dev fd0, sector 0 op 0x0:(READ) flags 0x0 phys_seg 1 prio class 0
Sep 25 14:13:32 rac01 kernel: floppy: error 10 while reading block 0
Sep 25 14:20:01 rac01 systemd: Started Session 18 of user root.


[root@rac01 ~]# lsmod | grep -i floppy
floppy                 81920  0

[root@rac01 log]# modprobe -r floppy

[root@rac01 log]# vi /etc/modprobe.d/fd-blacklist.conf
blacklist floppy

[root@rac01 log]# reboot -n

--------------

[root@rac02 ~]# oracleasm scandisks
Reloading disk partitions: done
Cleaning any stale ASM disks...
Scanning system for ASM disks...

Instantiating disk "OCR1"
Instantiating disk "OCR2"
Instantiating disk "OCR3"
Instantiating disk "DATA01"
Instantiating disk "DATA02"
Instantiating disk "DATA03"
Instantiating disk "FRA01"
Instantiating disk "FRA02"
Instantiating disk "FRA03"

[root@rac02 ~]# oracleasm listdisks
DATA01
DATA02
DATA03
FRA01
FRA02
FRA03
OCR1
OCR2
OCR3

[root@rac02 ~]# cd /dev/oracleasm/disks/
[root@rac02 disks]# ls -lrth
total 0
brw-rw---- 1 grid asmadmin 251,  49 Sep 25 12:06 OCR3
brw-rw---- 1 grid asmadmin 251,  33 Sep 25 12:06 OCR2
brw-rw---- 1 grid asmadmin 251,  17 Sep 25 12:06 OCR1
brw-rw---- 1 grid asmadmin 251, 145 Sep 25 14:06 FRA03
brw-rw---- 1 grid asmadmin 251, 129 Sep 25 14:06 FRA02
brw-rw---- 1 grid asmadmin 251, 113 Sep 25 14:06 FRA01
brw-rw---- 1 grid asmadmin 251,  97 Sep 25 14:06 DATA03
brw-rw---- 1 grid asmadmin 251,  81 Sep 25 14:06 DATA02
brw-rw---- 1 grid asmadmin 251,  65 Sep 25 14:06 DATA01

[root@rac02 ~]#  oracleasm querydisk -p OCR1
Disk "OCR1" is a valid ASM disk
/dev/vdb1: LABEL="OCR1" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p OCR2
Disk "OCR2" is a valid ASM disk
/dev/vdc1: LABEL="OCR2" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p OCR3
Disk "OCR3" is a valid ASM disk
/dev/vdd1: LABEL="OCR3" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p DATA01
Disk "DATA01" is a valid ASM disk
/dev/vde1: LABEL="DATA01" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p DATA02
Disk "DATA02" is a valid ASM disk
/dev/vdf1: LABEL="DATA02" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p DATA03
Disk "DATA03" is a valid ASM disk
/dev/vdg1: LABEL="DATA03" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p FRA01
Disk "FRA01" is a valid ASM disk
/dev/vdh1: LABEL="FRA01" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p FRA02
Disk "FRA02" is a valid ASM disk
/dev/vdi1: LABEL="FRA02" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p FRA03
Disk "FRA03" is a valid ASM disk
/dev/vdj1: LABEL="FRA03" TYPE="oracleasm"


```





#其他正常学校的配置步骤---本次无

```bash
[root@rac01 network-scripts]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 368ee0625304a85085600b88ed5fa3e0e
/dev/sdb 367850ad2f04bb70a9fc09714a06e7684
/dev/sdc 36c3a0087e0411209e380f43b597b12e9
/dev/sdd 3615b0d62c043850b6190eb2e183a3b61
/dev/sde 36b90096e304857085320c4edc10bee88
/dev/sdf 36cb30cf25045830a1af0687c7a2b6ff6
/dev/sdg 36d420575a040810bbbc0d8c0ddd708b3
[root@rac01 network-scripts]# lsblk
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
[root@rac01 network-scripts]#

[root@rac02 network-scripts]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 368ee0625304a85085600b88ed5fa3e0e
/dev/sdb 367850ad2f04bb70a9fc09714a06e7684
/dev/sdc 36c3a0087e0411209e380f43b597b12e9
/dev/sdd 3615b0d62c043850b6190eb2e183a3b61
/dev/sde 36b90096e304857085320c4edc10bee88
/dev/sdf 36cb30cf25045830a1af0687c7a2b6ff6
/dev/sdg 36d420575a040810bbbc0d8c0ddd708b3
[root@rac02 network-scripts]# lsblk
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
[root@rac02 network-scripts]#
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
[root@rac01 ~]# ll /dev|grep asm
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
[root@rac01 ~]# sfdisk -s
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

[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]#

#通过循环来获取
for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4

[root@rac01 ~]# for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4
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

[root@rac01 ~]# lsscsi -i
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
[root@rac01 ~]#
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

```
#oracle/L2jc4l2MAucl
#grid/FG2jc62xwucD
```

#grid用户

```bash
su - grid

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys rac02:~/.ssh/authorized_keys

ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date -Ins;ssh rac02 date -Ins;ssh rac01-prv date -Ins;ssh rac02-prv date -Ins

#在rac02执行
ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date -Ins;ssh rac02 date -Ins;ssh rac01-prv date -Ins;ssh rac02-prv date -Ins
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys rac02:~/.ssh/authorized_keys

ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date -Ins;ssh rac02 date -Ins;ssh rac01-prv date -Ins;ssh rac02-prv date -Ins

#在rac02上执行
ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date;ssh rac02 date;ssh rac01-prv date;ssh rac02-prv date

ssh rac01 date -Ins;ssh rac02 date -Ins;ssh rac01-prv date -Ins;ssh rac02-prv date -Ins
```

## 3 开始安装 grid

### 3.1. 上传集群软件包
```bash
#注意不同的用户
[root@rac01 storage]# cd /u01/storage
[root@rac01 storage]# ll -rth
-rwxr-xr-x 1 grid oinstall 2.7G Jan 28 15:58 LINUX.X64_193000_grid_home.zip
-rwxr-xr-x 1 oracle oinstall 2.9G Jan 28 16:38 LINUX.X64_193000_db_home.zip
```
### 3.2. 解压 grid 安装包

```bash
#在 19C 中需要把 grid 包解压放到 grid 用户下 ORACLE_HOME 目录内(/u01/app/19.0.0/grid)
#只在节点一上做解压缩
#如果节点二上也做了解压缩，必须全部删除，ls -a , rm -rfv ./* , rm -rfv ./opatch*, rm -rfv ./patch*
[grid@rac01 ~]$ cd /u01/app/19.0.0/grid
[grid@rac01 grid]$ unzip -oq /u01/storage/LINUX.X64_193000_grid_home.zip

#安装cvuqdisk包
cd /u01/app/19.0.0/grid/cv/rpm
cp cvuqdisk-1.0.10-1.rpm /u01
scp cvuqdisk-1.0.10-1.rpm rac02:/u01

#两台服务器都安装
su - root
cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm

#节点一安装前检查：
[grid@rac01 ~]$ cd /u01/app/19.0.0/grid/
[grid@rac01 grid]$ ./runcluvfy.sh stage -pre crsinst -n rac01,rac02 -fixup -verbose|tee -a pre.log
```

#error检查

#会生成fixup脚本，需在oracle01/oracle02上执行

```
#可以忽略的
ERROR:
PRVG-10467 : The default Oracle Inventory group could not be determined.

Verifying Network Time Protocol (NTP) ...FAILED (PRVG-1017)
Verifying resolv.conf Integrity ...FAILED (PRVG-10048)

#centos7可以忽略：
Verifying /dev/shm mounted as temporary file system ...FAILED (PRVE-0421)
Verifying /dev/shm mounted as temporary file system ...FAILED
rac02: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm

rac01: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm
```


#如果报错以下，可以忽略

```
Check: Package existence for "pdksh" 
  Node Name     Available                 Required                  Status    
  ------------  ------------------------  ------------------------  ----------
  oracle02       missing                   pdksh-5.2.14              failed    
  oracle01       missing                   pdksh-5.2.14              failed    
Result: Package existence check failed for "pdksh"
```
#如果报错以下内容必须处理
```
Checking Core file name pattern consistency...

ERROR:
PRVF-6402 : Core file name pattern is not same on all the nodes.
Found core filename pattern "|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h" on nodes "oracle01".
Found core filename pattern "core.%p" on nodes "oracle02".
Core file name pattern consistency check failed.
```
#解决办法，可以将node1的abrt-hook-ccpp关闭
#查看core_pattern
```bash
[root@oracle01 ~]# more /proc/sys/kernel/core_pattern
|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h
[root@oracle01 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; enabled; vendor preset: enabled)
   Active: active (exited) since Wed 2021-11-03 10:58:38 CST; 1 months 18 days ago
  Process: 806 ExecStart=/usr/sbin/abrt-install-ccpp-hook install (code=exited, status=0/SUCCESS)
 Main PID: 806 (code=exited, status=0/SUCCESS)
    Tasks: 0
   CGroup: /system.slice/abrt-ccpp.service
Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.


[root@oracle02 ~]# more /proc/sys/kernel/core_pattern
core
[root@oracle02 ~]# systemctl status abrt-ccpp.service
Unit abrt-ccpp.service could not be found.
```
#oracle01关闭abrt-ccpp
```bash
systemctl stop abrt-ccpp.service
systemctl disable abrt-ccpp.service
systemctl status abrt-ccpp.service
```
#此时再次runcluvfy即可通过
```
[root@oracle01 ~]# systemctl stop abrt-ccpp.service
[root@oracle01 ~]# systemctl disable abrt-ccpp.service
Removed symlink /etc/systemd/system/multi-user.target.wants/abrt-ccpp.service.
[root@oracle01 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; disabled; vendor preset: enabled)
   Active: inactive (dead)

Dec 22 14:06:03 oracle01 systemd[1]: Starting Install ABRT coredump hook...
Dec 22 14:06:03 oracle01 systemd[1]: Started Install ABRT coredump hook.
Dec 22 14:47:32 oracle01 systemd[1]: Stopping Install ABRT coredump hook...
Dec 22 14:47:32 oracle01 systemd[1]: Stopped Install ABRT coredump hook.
[root@oracle01 ~]# more /proc/sys/kernel/core_pattern
core

runcluvfy.sh:
Checking Core file name pattern consistency...
Core file name pattern consistency check passed.
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
[grid@rac01 grid]$ ./gridSetup.sh
```
### 3.4. GI 安装步骤
#安装过程如下
```
1. 为新的集群配置GI(configure oracle grid infrastructure for a New Cluster)
2. 配置独立的集群(configure an oracle standalone cluster)
3. 配置集群名称以及 scan 名称(rac-cluster/rac-scan/1521)
4. 添加节点2并测试节点互信(Add rac02/rac02-vip, test for SSH connectivity)
5. 公网、私网网段选择(eth1-10.20.24.0-ASM&private/eth0-10.20.12.0-public)
6. 选择 asm 存储(use oracle flex ASM for storage)
7. 选择不单独为GIMR配置磁盘组
8. 选择 asm 磁盘组(ORC/normal/100G三块磁盘/扫描的磁盘路径: /dev/oracleasm/disks/*)
9. 输入密码Oracle2023#Sys
10. 保持默认No IPMI
11. 保持默认No EM
12. 默认用户组asmadmin/asmdba/asmoper
13. 确认 base 目录$ORACLE_BASE(/u01/app/grid)
14. Inventory Directory: /u01/app/orainventory
15. 这里可以选择自动 root 执行脚本,不自动执行,不选
16. 预安装检查
    解决相关依赖后，忽略如下报错:
       DNS/NIS name service
    如下警告可以忽略-警告是由于没有使用 DNS 解析造成可忽略
       SCAN
       RPM Package Manager database
       
     [INS-13016]--->yes
17. install
18. 执行 root 脚本.

    先在rac01上执行完毕,再去rac02执行
    /u01/app/oraInventory/orainstRoot.sh
    /u01/app/19.0.0/grid/root.sh
    
    执行完毕后,点击OK
    INS-20802 oracle cluster verification utility failed--->OK
    Next
    INS-43080--->YES
19. Close     
```
#基于asmlib的磁盘选择

#/dev/oracleasm/disks/*

![image-20230925160246882](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230925160246882.png)



![image-20230925160428599](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230925160428599.png)



#安装前的忽略

![image-20230925160959650](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230925160959650.png)



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

[root@rac02 grid]# cd lib/
[root@rac02 lib]# ll|grep ^l
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


[root@rac02 lib]# ls -l libcln*
lrwxrwxrwx 1 root root       21 Oct 20 16:00 libclntshcore.so -> libclntshcore.so.19.1
-rwxr-xr-x 1 root root  8040416 Apr 18  2019 libclntshcore.so.19.1
lrwxrwxrwx 1 root root       17 Oct 20 16:00 libclntsh.so -> libclntsh.so.19.1
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.10.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.11.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.12.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.18.1 -> libclntsh.so
-rwxr-xr-x 1 root root 79927312 Apr 18  2019 libclntsh.so.19.1

[root@rac02 lib]# ll|grep libodm
-rw-r--r-- 1 root root     10594 Apr 17  2019 libodm19.a
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libodm19.so -> libodmd19.so
-rw-r--r-- 1 root root     17848 Apr 17  2019 libodmd19.so
[root@rac02 lib]#

-------------------------------------------
#检查grid账户下正常解压缩文件，发现软连接文件成了正常文件，但是大小还是12
cd /u01/app/19.0.0.0/grid/lib
[grid@rac02 lib]$ ll|grep ^l
lrwxrwxrwx  1 grid oinstall        15 Oct 20 16:10 libagtsh.so -> libagtsh.so.1.0
lrwxrwxrwx  1 grid oinstall        10 Oct 20 16:10 libocci.so.18.1 -> libocci.so

[grid@rac02 lib]$ ls -l  libcln*
-rwxr-xr-x. 1 grid oinstall       21 Oct 20 15:16 libclntshcore.so
-rwxr-xr-x. 1 grid oinstall  8040416 Oct 20 15:16 libclntshcore.so.19.1
-rwxr-xr-x. 1 grid oinstall       17 Oct 20 15:16 libclntsh.so
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.10.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.11.1
-rwxr-x---. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.12.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.18.1
-rwxr-xr-x. 1 grid oinstall 79927312 Oct 20 15:16 libclntsh.so.19.1

[grid@rac02 lib]$ ls -l|grep libjavavm19
-rwxr-xr-x. 1 grid oinstall        36 Oct 20 15:16 libjavavm19.a
[grid@rac02 lib]$ ls -l|grep libodm
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
[root@rac01 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.


[root@rac01 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/rac01/crsconfig/rootcrs_rac01_2022-08-12_11-09-12PM.log
2023/09/25 16:11:12 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2023/09/25 16:11:12 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2023/09/25 16:11:12 CLSRSC-363: User ignored prerequisites during installation
2023/09/25 16:11:12 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2023/09/25 16:11:14 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2023/09/25 16:11:14 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2023/09/25 16:11:15 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2023/09/25 16:11:15 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2023/09/25 16:11:25 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2023/09/25 16:11:28 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2023/09/25 16:11:34 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2023/09/25 16:11:40 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2023/09/25 16:11:40 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2023/09/25 16:11:44 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2023/09/25 16:11:44 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2023/09/25 16:12:05 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2023/09/25 16:12:09 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2023/09/25 16:12:13 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2023/09/25 16:12:17 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.

ASM has been created and started successfully.

[DBT-30001] Disk groups created successfully. Check /u01/app/grid/cfgtoollogs/asmca/asmca-220309PM061249.log for details.

2023/09/25 16:13:35 CLSRSC-482: Running command: '/u01/app/19.0.0/grid/bin/ocrconfig -upgrade grid oinstall'
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
2023/09/25 16:14:58 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2023/09/25 16:16:04 CLSRSC-343: Successfully started Oracle Clusterware stack
2023/09/25 16:16:04 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2023/09/25 16:17:06 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2023/09/25 16:17:27 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded


[root@rac02 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.


[root@rac02 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/rac02/crsconfig/rootcrs_rac02_2022-03-09_06-18-12PM.log
2023/09/25 16:18:15 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2023/09/25 16:18:15 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2023/09/25 16:18:15 CLSRSC-363: User ignored prerequisites during installation
2023/09/25 16:18:15 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2023/09/25 16:18:17 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2023/09/25 16:18:17 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2023/09/25 16:18:25 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2023/09/25 16:18:25 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2023/09/25 16:18:26 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2023/09/25 16:18:26 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2023/09/25 16:18:37 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2023/09/25 16:18:44 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2023/09/25 16:18:45 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2023/09/25 16:18:46 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2023/09/25 16:18:47 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2023/09/25 16:18:55 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2023/09/25 16:19:41 CLSRSC-343: Successfully started Oracle Clusterware stack
2023/09/25 16:19:41 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2023/09/25 16:19:50 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2023/09/25 16:19:55 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```
## 创建 ASM 数据磁盘
### 4.1. grid 账户登录图形化界面，执行 asmca
#创建asm磁盘组步骤
```
1. DiskGroups界面点击Create
2. DATA/External/(/dev/oracleasm/disks/DATA01、/dev/oracleasm/disks/DATA02、/dev/oracleasm/disks/DATA03)，点击OK
3. 继续点击Create
4. FRA/External/(/dev/oracleasm/disks/FRA01、/dev/oracleasm/disks/FRA02、/dev/oracleasm/disks/FRA03)，点击OK
5. Exit
```
![image-20230925164844572](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230925164844572.png)

### 4.2 查看状态

```
[grid@rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac01              STABLE
               ONLINE  ONLINE       rac02              STABLE
ora.chad
               ONLINE  ONLINE       rac01              STABLE
               ONLINE  ONLINE       rac02              STABLE
ora.net1.network
               ONLINE  ONLINE       rac01              STABLE
               ONLINE  ONLINE       rac02              STABLE
ora.ons
               ONLINE  ONLINE       rac01              STABLE
               ONLINE  ONLINE       rac02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       rac01              STABLE
      2        ONLINE  ONLINE       rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       rac01              STABLE
      2        ONLINE  ONLINE       rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       rac01              STABLE
      2        ONLINE  ONLINE       rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       rac01              STABLE
      2        ONLINE  ONLINE       rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       rac01              Started,STABLE
      2        ONLINE  ONLINE       rac02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       rac01              STABLE
      2        ONLINE  ONLINE       rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       rac01              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       rac01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       rac01              STABLE
ora.rac01.vip
      1        ONLINE  ONLINE       rac01              STABLE
ora.rac02.vip
      1        ONLINE  ONLINE       rac02              STABLE
--------------------------------------------------------------------------------


#如果存在/etc/ntp.conf或者/etc/chrony.conf会导致octssd处于Observer模式
#日志目录/u01/app/grid/diag/crs/rac02/crs/trace/octssd.trc
# ctsselect_msm: CTSS mode is [0xc6]


[grid@rac02 ~]$  cluvfy comp clocksync -n all -verbose

Performing following verification checks ...

  Clock Synchronization ...
  Node Name                             Status
  ------------------------------------  ------------------------
  rac02                                 passed
  rac01                                 passed

  Node Name                             State
  ------------------------------------  ------------------------
  rac02                                 Observer
  rac01                                 Observer

CTSS is in Observer state. Switching over to clock synchronization checks using NTP

    Network Time Protocol (NTP) ...
      '/etc/chrony.conf' ...
    Node Name                             File exists?
    ------------------------------------  ------------------------
    rac02                                 no
    rac01                                 yes

      '/etc/chrony.conf' ...FAILED (PRVG-1019)
      '/var/run/ntpd.pid' ...
    Node Name                             File exists?
    ------------------------------------  ------------------------
    rac02                                 no
    rac01                                 no


#此时将rac1中chrony.conf移除掉，就会ctss进入active模式
# ctsselect_msm: CTSS mode is [0xc4]
[root@rac01 ~]$ mv /etc/chrony.conf  /etc/chrony.conf.bak
[root@rac01 ~]$ su - grid

[grid@rac01 ~]$ cluvfy comp clocksync -n all -verbose

Performing following verification checks ...

  Clock Synchronization ...
  Node Name                             Status
  ------------------------------------  ------------------------
  rac01                                 passed
  rac02                                 passed

  Node Name                             State
  ------------------------------------  ------------------------
  rac02                                 Active
  rac01                                 Active

  Node Name     Time Offset               Status
  ------------  ------------------------  ------------------------
  rac02         0.0                       passed
  rac01         0.0                       passed
  Clock Synchronization ...PASSED

Verification of Clock Synchronization across the cluster nodes was successful.

CVU operation performed:      Clock Synchronization across the cluster nodes
Date:                         Oct 25, 2023 10:55:34 AM
CVU version:                  19.20.0.0.0 (062923x8664)
Clusterware version:          19.0.0.0.0
CVU home:                     /u01/app/19.0.0/grid
Grid home:                    /u01/app/19.0.0/grid
User:                         grid
Operating system:             Linux5.4.17-2011.6.2.el7uek.x86_64


[grid@rac02 ~]$  cluvfy comp clocksync -n all -verbose
```
## 5 安装 Oracle 数据库软件
#以 Oracle 用户登录图形化界面，将数据库软件解压至$ORACLE_HOME 

```bash
[oracle@rac01 db_1]$ pwd
/u01/app/oracle/product/19.0.0/db_1
[oracle@rac01 db_1]$ unzip -oq /u01/storage/LINUX.X64_193000_db_home.zip
```
#节点一安装前检查--也可以不进行该项检查

```bash
[grid@rac01 ~]$ cd /u01/app/19.0.0/grid/
[grid@rac01 grid]$ ./runcluvfy.sh stage -pre dbinst -n rac01,rac02 -fixup -verbose|tee -a pre-db.log
```



#通过xstart图形化连接服务器，同Grid连接方式

```bash
[oracle@rac01 db_1]$ ./runInstaller
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
10. root账户先在rac01执行完毕后再在rac02上执行脚本(/u01/app/oracle/product/19.0.0/db_1/root.sh)，然后点击OK
11. Close
```
#执行root.sh脚本记录
```
[root@rac01 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
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

[root@rac02 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
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

![image-20230928121556137](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle19cRAC-neuq\image-20230928121556137.png)



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
       #sga=memory*65%*75%=64G*65%*75%=31.2G(向下十位取整为30G)
       #pga=memory*65%*25%=512G*65%*25%=83.210.4G(向下十位取整为10G)
       sga=30G
       pag=10G
   Sizing: block size: 8192/processes: 3000
   Character Sets: AL32UTF8
   Connection mode: Dadicated server mode--->Next
10. 运行CVU和关闭EM
11. 使用相同密码Oracle2023#Sys
12. 勾选：create database
13. Ignore all--->Yes
14. Finish
15. Close

```
### 6.2. 查看集群状态
```
[grid@rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac01                    STABLE
               ONLINE  ONLINE       rac02                    STABLE
ora.chad
               ONLINE  ONLINE       rac01                    STABLE
               ONLINE  ONLINE       rac02                    STABLE
ora.net1.network
               ONLINE  ONLINE       rac01                    STABLE
               ONLINE  ONLINE       rac02                    STABLE
ora.ons
               ONLINE  ONLINE       rac01                    STABLE
               ONLINE  ONLINE       rac02                    STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       rac01                    STABLE
      2        ONLINE  ONLINE       rac02                    STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       rac01                    STABLE
      2        ONLINE  ONLINE       rac02                    STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       rac01                    STABLE
      2        ONLINE  ONLINE       rac02                    STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac01                    STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       rac01                    STABLE
      2        ONLINE  ONLINE       rac02                    STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       rac01                    Started,STABLE
      2        ONLINE  ONLINE       rac02                    Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       rac01                    STABLE
      2        ONLINE  ONLINE       rac02                    STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       rac01                    STABLE
ora.qosmserver
      1        ONLINE  ONLINE       rac01                    STABLE
ora.rac01.vip
      1        ONLINE  ONLINE       rac01                    STABLE
ora.rac02.vip
      1        ONLINE  ONLINE       rac02                    STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       rac01                    STABLE
ora.xydb.db
      1        ONLINE  ONLINE       rac01                    Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       rac02                    Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
--------------------------------------------------------------------------------

[grid@rac01 ~]$  srvctl config database -d xydb
Database unique name: xydb
Database name: xydb
Oracle home: /u01/app/oracle/product/19.0.0/db_1
Oracle user: oracle
Spfile: +DATA/XYDB/PARAMETERFILE/spfile.272.1148735835
Password file: +DATA/XYDB/PASSWORD/pwdxydb.256.1148734945
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
Configured nodes: rac01,rac02
CSS critical: no
CPU count: 0
Memory target: 0
Maximum memory: 0
Default network number for database services:
Database is administrator managed
```
### 6.3. 查看数据库版本
```
[oracle@rac01 db_1]$ sqlplus / as sysdba
SQL> col banner_full for a120
SQL> select BANNER_FULL from v$version;

BANNER_FULL
--------------------------------------------------------------------------------
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select INST_NUMBER,INST_NAME FROM v$active_instances;

INST_NUMBER INST_NAME
----------- ----------------------------------------------
	  1 rac01:xydb1
	  2 rac02:xydb2

SQL> SELECT instance_name, host_name FROM gv$instance;

INSTANCE_NAME	 HOST_NAME
---------------- --------------------------------
xydb1		 rac01
xydb2		 rac02

SQL> col file_name format a80

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
------------------------------------------- ------------------------------
+DATA/XYDB/TEMPFILE/temp.264.1098977211 					 TEMP

SQL> select file_name,tablespace_name from dba_data_files;


FILE_NAME                                                                        TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/DATAFILE/system.257.1148734967                                        SYSTEM
+DATA/XYDB/DATAFILE/sysaux.258.1148735013                                        SYSAUX
+DATA/XYDB/DATAFILE/undotbs1.259.1148735037                                      UNDOTBS1
+DATA/XYDB/DATAFILE/users.260.1148735039                                         USERS
+DATA/XYDB/DATAFILE/undotbs2.269.1148735517                                      UNDOTBS2



SQL> 

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 DATAASSETS			  READ WRITE NO

SQL>  alter session set container=dataassets;

Session altered.

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME                                                                        TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/TEMPFILE/temp.276.1148736023         TEMP

SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME                                                                        TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/system.274.1148736011       SYSTEM
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/sysaux.275.1148736011       SYSAUX
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/undotbs1.273.1148736011     UNDOTBS1
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/undo_2.277.1148736039       UNDO_2
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/users.278.1148736041        USERS

SQL> 
```
### 6.4. Oracle RAC数据库优化
#user password life修改，一个节点修改即可(CDB/PDB)

```oracle
select resource_name,limit from dba_profiles where profile='DEFAULT';
alter profile default limit password_life_time unlimited;
alter profile  ORA_STIG_PROFILE limit  PASSWORD_LIFE_TIME   UNLIMITED;
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


#DB_FILES修改，默认1024

```oracle
alter system set DB_FILES=4096 scope=spfile sid='*';
```

#开启huagepages

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

 alter system set "_disable_file_resize_logging"=TRUE scope=both sid='*';
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

SQL> alter user pdbadmin identified by Oracle2023#Sys account unlock;

User altered.

SQL> grant dba to pdbadmin;

Grant succeeded.

SQL> exit
#sqlplus pdbadmin/DSApdb2023#ADb@10.20.12.134:1521/s_dataassets
#sqlplus portaluser/Oracle2023#Portal@10.20.12.134:1521/s_portal
#sqlplus onecodeuser/ConeDe2839#CoeN@10.20.12.134:1521/s_onecode

#sqlplus system/Oracle2023#Sys@10.20.12.134:1521/s_dataassets

[oracle@rac02 ~]$ sqlplus pdbadmin/DSApdb2023#ADb@10.20.12.134:1521/s_dataassets

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
expdp test1/test1@10.20.12.134:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n
#导出全库
expdp pdbadmin/pdbadmin@10.20.12.134:1521/s_dataassets full=y directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp
impdp est1/test1@10.20.12.134:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n

##impdp--remap
impdp  est1/test1@10.20.12.134:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n   remap_schema=test2:test1 remap_tablespace=test2:test1  logfile=test01.log cluster=n

#expdp-12.2.0.1.0
expdp test1/test1@10.20.12.134:1521/s_dataassets schemas=test1 directory=expdir dumpfile=test1_20220314.dmp logfile=test1_20220314.log cluster=n compression=data_only version=12.2.0.1.0

#脚本

#!/bin/bash
source /etc/profile
source /home/oracle/.bash_profile

now=`date +%y%m%d`
dmpfile=dataassets_db$now.dmp
logfile=dataassets_db$now.log

echo start exp $dmpfile ...


expdp pdbadmin/pdbadmin@10.20.12.134:1521/s_dataassets full=y directory=expdir dumpfile=$dmpfile logfile=$logfile cluster=n 



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

sqlplus portaluser/Oracle2023#Portal@10.20.12.134:1521/s_portal

--------------------------------
srvctl add service -d xydb -s s_onecode -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb onecode

srvctl start service -d xydb -s s_onecode
srvctl status service -d xydb -s s_onecode

sqlplus onecodeuser/ConeDe2839#CoeN@10.20.12.134:1521/s_onecode

sqlplus pdbadmin/DSApdb2023#ADb@10.20.12.134:1521/s_dataassets

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
