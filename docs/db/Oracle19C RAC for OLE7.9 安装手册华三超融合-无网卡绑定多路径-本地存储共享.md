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
### 1.0. 三台服务器

#本地深信服超融合环境，存储全部挂载给了虚拟化环境，没有多余的共享lun可以划出来，所以采用一台虚拟机搭建iscsi共享存储

```
k8s-rac01: 172.18.13.97
k8s-rac02: 172.18.13.98
k8s-oracle-store: 172.18.13.97
```

### 1.1. 系统版本

```
[root@k8s-rac01 ~]# cat /etc/os-release |grep PRETTY
PRETTY_NAME="Oracle Linux Server 7.9"

[root@k8s-rac01 ~]# uname -r
5.4.17-2102.201.3.el7uek.x86_64
```
### 1.2. ASM 磁盘组规划

```
ASM 磁盘组 用途 大小 冗余
ocr、voting file   50G+50G+50G NORMAL        ocr01/ocr02/ocr03
DATA 数据文件       100G+100G+100G EXTERNAL   data01/data02/data03
FRA  归档日志       200G EXTERNAL             fra01
```




### 1.3. 主机网络规划

#password

```
root/AZlm92c2YeVc!
root1/Jile2dx49OmUne
grid/FG2jc62xwucD
oracle/L2jc4l2MAucl

sys/
system/
```

#分区---120G

```
/boot   1G
swap    32G
/       其余容量  
```

#IP规划

```
网络配置               节点 1                               节点 2              iscsi虚拟机
主机名称               k8s-rac01                           k8s-rac02           k8s-oracle-store
public ip            172.18.13.97                       172.18.13.98         172.18.13.104
private ip           10.100.100.97                      10.100.100.98
vip                  172.18.13.99                       172.18.13.100
scan ip              172.18.13.101
```
###最后实际参数

```
[root@k8s-rac01 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdf           8:80   0  100G  0 disk 
sdd           8:48   0  100G  0 disk 
sdb           8:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
sdg           8:96   0  200G  0 disk 
sde           8:64   0  100G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot

[root@k8s-rac02 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdf           8:80   0  100G  0 disk 
sdd           8:48   0  100G  0 disk 
sdb           8:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
sdg           8:96   0  200G  0 disk 
sde           8:64   0  100G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot


#部分学校因为使用的是深信服CAS虚拟化平台，无法支持scsi分区磁盘，故无法使用udev，只能采用oracleasm管理磁盘
[root@rac01 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

[root@rac02 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

----------------------
#本次共享存储正常：
[root@k8s-rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007



[root@k8s-rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007

---------------------------------
[root@k8s-rac01 network-scripts]# cat ifcfg-eth0
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
NAME=eth0
UUID=5cb29430-beb7-48b8-ba7a-2e49415d02eb
DEVICE=eth0
ONBOOT=yes
IPADDR=172.18.13.97
PREFIX=16
GATEWAY=172.18.209.40
DNS1=223.5.5.5
DNS2=223.6.6.6

[root@k8s-rac01 network-scripts]# cat ifcfg-eth1
TYPE=Ethernet
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
NAME=eth1
HWADDR=FE:FC:FE:DB:83:4D
PEERDNS=no
IPADDR=10.100.100.97
NETMASK=255.255.255.0
GATEWAY=10.100.100.1
METRIC=105

[root@k8s-rac01 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.18.209.40   0.0.0.0         UG    100    0        0 eth0
0.0.0.0         10.100.100.1    0.0.0.0         UG    101    0        0 eth1
10.100.100.0    0.0.0.0         255.255.255.0   U     101    0        0 eth1
172.18.0.0      0.0.0.0         255.255.0.0     U     100    0        0 eth0

[root@k8s-rac01 ~]# ip route list
default via 172.18.209.40 dev eth0 proto static metric 100 
default via 10.100.100.1 dev eth1 proto static metric 101 
10.100.100.0/24 dev eth1 proto kernel scope link src 10.100.100.97 metric 101 
172.18.0.0/16 dev eth0 proto kernel scope link src 172.18.13.97 metric 100 

[root@k8s-rac01 network-scripts]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  a51bd73a-44bc-44be-adf0-aa26c1506eb6  ethernet  eth0   
eth1  897abf73-23a4-4585-af73-b32a3c228f03  ethernet  eth1   



[root@k8s-rac02 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth0
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
NAME=eth0
#UUID=5cb29430-beb7-48b8-ba7a-2e49415d02eb
UUID=01c42c1f-4e75-40d5-b250-10810b428bca
DEVICE=eth0
ONBOOT=yes
IPADDR=172.18.13.98
PREFIX=16
GATEWAY=172.18.209.40
DNS1=223.5.5.5
DNS2=223.6.6.6

[root@k8s-rac02 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth1
TYPE=Ethernet
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
NAME=eth1
UUID=9d03cbb7-affc-4f0e-9605-511a35f60d83
HWADDR=FE:FC:FE:43:24:AF
PEERDNS=no
IPADDR=10.100.100.98
NETMASK=255.255.255.0
GATEWAY=10.100.100.1
METRIC=103
[root@k8s-rac02 ~]# ip route list
default via 172.18.209.40 dev eth0 proto static metric 100 
default via 10.100.100.1 dev eth1 proto static metric 101 
10.100.100.0/24 dev eth1 proto kernel scope link src 10.100.100.98 metric 101 
172.18.0.0/16 dev eth0 proto kernel scope link src 172.18.13.98 metric 100 
[root@k8s-rac02 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  01c42c1f-4e75-40d5-b250-10810b428bca  ethernet  eth0   
eth1  9d03cbb7-affc-4f0e-9605-511a35f60d83  ethernet  eth1   
```
#网卡配置及多路径配置
```bash
ifconfig
nmcli conn show

#默认是NetworkManager管理网络
[root@k8s-rac01 ~]# systemctl status network
● network.service - LSB: Bring up/down networking
   Loaded: loaded (/etc/rc.d/init.d/network; bad; vendor preset: disabled)
   Active: active (exited) since Fri 2023-11-17 18:21:11 CST; 3min 11s ago
     Docs: man:systemd-sysv-generator(8)
  Process: 30913 ExecStop=/etc/rc.d/init.d/network stop (code=exited, status=0/SUCCESS)
  Process: 31455 ExecStart=/etc/rc.d/init.d/network start (code=exited, status=0/SUCCESS)

Nov 17 18:21:10 k8s-rac01 systemd[1]: Starting LSB: Bring up/down networking...
Nov 17 18:21:10 k8s-rac01 network[31455]: Bringing up loopback interface:  [  OK  ]
Nov 17 18:21:10 k8s-rac01 network[31455]: Bringing up interface eth0:  Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/7)
Nov 17 18:21:10 k8s-rac01 network[31455]: [  OK  ]
Nov 17 18:21:11 k8s-rac01 network[31455]: Bringing up interface eth1:  Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/8)
Nov 17 18:21:11 k8s-rac01 network[31455]: [  OK  ]
Nov 17 18:21:11 k8s-rac01 systemd[1]: Started LSB: Bring up/down networking.
[root@k8s-rac01 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2023-11-17 11:30:08 CST; 6h ago
     Docs: man:NetworkManager(8)
 Main PID: 7190 (NetworkManager)
   CGroup: /system.slice/NetworkManager.service
           └─7190 /usr/sbin/NetworkManager --no-daemon

Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0810] agent-manager: req[0x562c38d1e330, :1.117/nmcli-connect/0]: agent registered
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0853] device (eth1): Activation: starting connection 'eth1' (897abf73-23a4-4585-af73-b32a3c228f03)
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0857] audit: op="connection-activate" uuid="897abf73-23a4-4585-af73-b32a3c228f03" name="eth1" pid=31655 uid=0 result="success"
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0858] device (eth1): state change: disconnected -> prepare (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0866] device (eth1): state change: prepare -> config (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0884] device (eth1): state change: config -> ip-config (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0904] device (eth1): state change: ip-config -> ip-check (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0926] device (eth1): state change: ip-check -> secondaries (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.0930] device (eth1): state change: secondaries -> activated (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-rac01 NetworkManager[7190]: <info>  [1700216471.1051] device (eth1): Activation: successful, device activated.
[root@k8s-rac01 ~]# nmcli dev
DEVICE  TYPE      STATE      CONNECTION 
eth0    ethernet  connected  eth0       
eth1    ethernet  connected  eth1       
lo      loopback  unmanaged  --         
[root@k8s-rac01 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  a51bd73a-44bc-44be-adf0-aa26c1506eb6  ethernet  eth0   
eth1  897abf73-23a4-4585-af73-b32a3c228f03  ethernet  eth1  

--------------------------------------------------------------------
[root@k8s-rac02 ~]# systemctl status network
● network.service - LSB: Bring up/down networking
   Loaded: loaded (/etc/rc.d/init.d/network; bad; vendor preset: disabled)
   Active: active (exited) since Fri 2023-11-17 18:22:21 CST; 2min 1s ago
     Docs: man:systemd-sysv-generator(8)
  Process: 30257 ExecStop=/etc/rc.d/init.d/network stop (code=exited, status=0/SUCCESS)
  Process: 30542 ExecStart=/etc/rc.d/init.d/network start (code=exited, status=0/SUCCESS)

Nov 17 18:22:20 k8s-rac02 systemd[1]: Starting LSB: Bring up/down networking...
Nov 17 18:22:21 k8s-rac02 network[30542]: Bringing up loopback interface:  [  OK  ]
Nov 17 18:22:21 k8s-rac02 network[30542]: Bringing up interface eth0:  Connection successfully a...n/7)
Nov 17 18:22:21 k8s-rac02 network[30542]: [  OK  ]
Nov 17 18:22:21 k8s-rac02 network[30542]: Bringing up interface eth1:  Connection successfully a...n/8)
Nov 17 18:22:21 k8s-rac02 network[30542]: [  OK  ]
Nov 17 18:22:21 k8s-rac02 systemd[1]: Started LSB: Bring up/down networking.
Hint: Some lines were ellipsized, use -l to show in full.
[root@k8s-rac02 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2023-11-17 11:33:48 CST; 6h ago
     Docs: man:NetworkManager(8)
 Main PID: 893 (NetworkManager)
   CGroup: /system.slice/NetworkManager.service
           └─893 /usr/sbin/NetworkManager --no-daemon

Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2144] agent-manager: req[0x558...red
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2160] device (eth1): Activatio...83)
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2161] audit: op="connection-ac...ss"
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2162] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2167] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2172] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2183] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2197] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2199] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-rac02 NetworkManager[893]: <info>  [1700216541.2227] device (eth1): Activatio...ed.
Hint: Some lines were ellipsized, use -l to show in full.
[root@k8s-rac02 ~]# nmcli dev
DEVICE  TYPE      STATE      CONNECTION 
eth0    ethernet  connected  eth0       
eth1    ethernet  connected  eth1       
lo      loopback  unmanaged  --         
[root@k8s-rac02 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  01c42c1f-4e75-40d5-b250-10810b428bca  ethernet  eth0   
eth1  9d03cbb7-affc-4f0e-9605-511a35f60d83  ethernet  eth1   
```

#网卡绑定---无

```
假如网卡绑定，本次没有网卡绑定：
#eno8为私有网卡
#ens3f0和ens3f1d1绑定为team0为业务网卡
```
#节点一rac01
```bash
nmcli con mod eno8 ipv4.addresses 10.100.100.97/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '172.18.13.97/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#节点二rac02
```bash
nmcli con mod eno8 ipv4.addresses 10.100.100.98/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '172.18.13.97/24' ipv4.gateway '192.168.203.254'
 
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

#其他学校mysql情况
[root@DTMysql1 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 3600508b1001c2f58146de5792c5af902
/dev/sdb 360002ac0000000000000000300021f88
/dev/sdc 360002ac0000000000000000300021f88
/dev/sdd 360002ac0000000000000000300021f88
/dev/sde 360002ac0000000000000000300021f88
[root@DTMysql1 ~]# lsblk
NAME               MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sda                  8:0    0  1.6T  0 disk  
├─sda1               8:1    0  600M  0 part  /boot/efi
├─sda2               8:2    0    1G  0 part  /boot
└─sda3               8:3    0  1.6T  0 part  
  ├─openeuler-root 253:0    0  1.6T  0 lvm   /
  └─openeuler-swap 253:1    0   16G  0 lvm   [SWAP]
sdb                  8:16   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
sdc                  8:32   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
sdd                  8:48   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
sde                  8:64   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
  
[root@DTMysql1 ~]# cat /etc/multipath.conf 
# device-mapper-multipath configuration file

# For a complete list of the default configuration values, run either:
# # multipath -t
# or
# # multipathd show config

# For a list of configuration options with descriptions, see the
# multipath.conf man page.

defaults {
	user_friendly_names yes
	find_multipaths yes
}

blacklist_exceptions {
        property "(SCSI_IDENT_|ID_WWN)"
}

blacklist {
}


[root@DTMysql1 ~]# cat /etc/multipath
multipath/      multipath.conf  
[root@DTMysql1 ~]# cat /etc/multipath.conf 
# device-mapper-multipath configuration file

# For a complete list of the default configuration values, run either:
# # multipath -t
# or
# # multipathd show config

# For a list of configuration options with descriptions, see the
# multipath.conf man page.

defaults {
	user_friendly_names yes
	find_multipaths yes
}

blacklist_exceptions {
        property "(SCSI_IDENT_|ID_WWN)"
}

blacklist {
}
[root@DTMysql1 ~]# cat /etc/multipath
multipath/      multipath.conf  
[root@DTMysql1 ~]# cat /etc/multipath/
bindings  wwids     
[root@DTMysql1 ~]# cat /etc/multipath/bindings 
# Multipath bindings, Version : 1.0
# NOTE: this file is automatically maintained by the multipath program.
# You should not need to edit this file in normal circumstances.
#
# Format:
# alias wwid
#
mpatha 360002ac0000000000000000300021f88
[root@DTMysql1 ~]# cat /etc/multipath/wwids 
# Multipath wwids, Version : 1.0
# NOTE: This file is automatically maintained by multipath and multipathd.
# You should not need to edit this file in normal circumstances.
#
# Valid WWIDs:
/360002ac0000000000000000300021f88/
[root@DTMysql1 ~]# multipathd show maps
name   sysfs uuid                             
mpatha dm-2  360002ac0000000000000000300021f88

```

### 1.6.第三台虚拟机(k8s-oracle-store)搭建iscsi共享存储
#### 1.6.1.添加共享磁盘

#添加硬盘，创建方式：新磁盘，分配方式：预分配(类似于vsphere的厚置备，置零)

![image-20231117111420348](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle-store\image-20231117111420348.png)

![image-20231117112712657](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle-store\image-20231117112712657.png)





#### 1.6.2.配置iscsi

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

#安装iscsi管理工具

```bash
yum install -y targetcli
```

#启动iscsi服务

```bash
systemctl start target.service
systemctl enable target.service

systemctl status target.service
```

#查看磁盘信息

```bash
# lsblk
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
```

#安装 scsi-target-utils

```bash
#yum install -y epel-release
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -ivh epel-release-latest-7.noarch.rpm

yum  -y install scsi-target-utils libxslt
#yum --enablerepo=epel -y install scsi-target-utils libxslt
```

#配置 targets.conf ，在文件末尾添加如下内容

```bash
cat >> /etc/tgt/targets.conf << EOF
<target iqn.2023-11.com.oracle:rac>
    backing-store /dev/vdb
    backing-store /dev/vdc
    backing-store /dev/vdd
    backing-store /dev/vde
    backing-store /dev/vdf
    backing-store /dev/vdg
    backing-store /dev/vdh
    initiator-address 172.18.13.0/24
    write-cache off
</target>
EOF
```

#注意

```
#iqn 名字可任意

#initiator-address 限定允许访问的客户端地址段或具体IP

#write-cache off 是否开启或关闭快取
```

```bash
# cat /etc/tgt/targets.conf |grep -v ^#|grep -v ^$
default-driver iscsi
<target iqn.2023-11.com.oracle:rac>
    backing-store /dev/vdb
    backing-store /dev/vdc
    backing-store /dev/vdd
    backing-store /dev/vde
    backing-store /dev/vdf
    backing-store /dev/vdg
    backing-store /dev/vdh
    initiator-address 172.18.13.0/24
    write-cache off
</target>
```

#启动 tgtd

```bash
systemctl restart tgtd.service

systemctl restart target.service

systemctl enable tgtd

tgt-admin -dump

tgtadm --lld iscsi --mode target --op show

netstat -anp|grep tgt
```

#日志

```bash
[root@k8s-oracle-store ~]# tgt-admin -dump
default-driver iscsi

<target iqn.2023-11.com.oracle:rac>
	backing-store /dev/vdb
	backing-store /dev/vdc
	backing-store /dev/vdd
	backing-store /dev/vde
	backing-store /dev/vdf
	backing-store /dev/vdg
	backing-store /dev/vdh
	initiator-address 172.18.13.0/24
</target>


[root@k8s-oracle-store ~]# tgtadm --lld iscsi --mode target --op show
Target 1: iqn.2023-11.com.oracle:rac
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags: 
        LUN: 1
            Type: disk
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdb
            Backing store flags: 
        LUN: 2
            Type: disk
            SCSI ID: IET     00010002
            SCSI SN: beaf12
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdc
            Backing store flags: 
        LUN: 3
            Type: disk
            SCSI ID: IET     00010003
            SCSI SN: beaf13
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdd
            Backing store flags: 
        LUN: 4
            Type: disk
            SCSI ID: IET     00010004
            SCSI SN: beaf14
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vde
            Backing store flags: 
        LUN: 5
            Type: disk
            SCSI ID: IET     00010005
            SCSI SN: beaf15
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdf
            Backing store flags: 
        LUN: 6
            Type: disk
            SCSI ID: IET     00010006
            SCSI SN: beaf16
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdg
            Backing store flags: 
        LUN: 7
            Type: disk
            SCSI ID: IET     00010007
            SCSI SN: beaf17
            Size: 214748 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdh
            Backing store flags: 
    Account information:
    ACL information:
        172.18.13.0/24
     
     
#oracle rac 连接后

[root@k8s-oracle-store ~]# tgtadm -L iscsi -o show -m target
Target 1: iqn.2023-11.com.oracle:rac
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
        I_T nexus: 2
            Initiator: iqn.2023-11.com.oracle:rac alias: k8s-rac01
            Connection: 0
                IP Address: 172.18.13.97
        I_T nexus: 15
            Initiator: iqn.2023-11.com.oracle:rac alias: k8s-rac02
            Connection: 0
                IP Address: 172.18.13.98
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags: 
        LUN: 1
            Type: disk
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdb
            Backing store flags: 
        LUN: 2
            Type: disk
            SCSI ID: IET     00010002
            SCSI SN: beaf12
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdc
            Backing store flags: 
        LUN: 3
            Type: disk
            SCSI ID: IET     00010003
            SCSI SN: beaf13
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdd
            Backing store flags: 
        LUN: 4
            Type: disk
            SCSI ID: IET     00010004
            SCSI SN: beaf14
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vde
            Backing store flags: 
        LUN: 5
            Type: disk
            SCSI ID: IET     00010005
            SCSI SN: beaf15
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdf
            Backing store flags: 
        LUN: 6
            Type: disk
            SCSI ID: IET     00010006
            SCSI SN: beaf16
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdg
            Backing store flags: 
        LUN: 7
            Type: disk
            SCSI ID: IET     00010007
            SCSI SN: beaf17
            Size: 214748 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdh
            Backing store flags: 
    Account information:
    ACL information:
        172.18.13.0/24
        
[root@k8s-oracle-store ~]# netstat -anp|grep tgt
netstat: showing only processes with your user ID
tcp        0      0 0.0.0.0:3260            0.0.0.0:*               LISTEN      25468/tgtd
tcp        0      0 172.18.13.104:3260      172.18.13.98:64708      ESTABLISHED 25468/tgtd
tcp        0      0 172.18.13.104:3260      172.18.13.97:33274      ESTABLISHED 25468/tgtd
tcp        0      0 :::3260                 :::*                    LISTEN      25468/tgtd
        
```


### 1.7. 配置 iscsi 客户端（所有rac节点）

#### 1.7.1.配置共享磁盘

#安装 iscsi-initiator-utils,安裝 iSCSI Client 软件

```bash
yum install -y iscsi-initiator-utils libiscsi
```

#配置 initiatorname.iscsi

```bash
vi /etc/iscsi/initiatorname.iscsi
#将上面的内容复制到这里
InitiatorName=iqn.2023-11.com.oracle:rac
```

#重启iscsi

```bash
systemctl restart iscsi.service
systemctl enable iscsi.service
```

#通过3260端口查看开放了哪些共享存储

```bash
iscsiadm -m discovery -tsendtargets -p 172.18.13.104:3260
```

#日志

```bash
# iscsiadm -m discovery -tsendtargets -p 172.18.13.104:3260
172.18.13.104:3260,1 iqn.2023-11.com.oracle:rac
```

#登录共享存储

```bash
iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 172.18.13.104:3260 -l
```

#日志

```bash
# iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 172.18.13.104:3260 -l
Logging in to [iface: default, target: iqn.2023-11.com.oracle:rac, portal: 172.18.13.104,3260] (multiple)
Login to [iface: default, target: iqn.2023-11.com.oracle:rac, portal: 172.18.13.104,3260] successful.
```

#探测下共享存储的目录

```bash
partprobe

lsblk

iscsiadm -m session -R

lsscsi

ll  /dev/disk/by-path

yum install -y tree
tree /var/lib/iscsi/
cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
```

#日志

```bash
[root@k8s-rac01 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdf           8:80   0  100G  0 disk 
sdd           8:48   0  100G  0 disk 
sdb           8:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
sdg           8:96   0  200G  0 disk 
sde           8:64   0  100G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot

[root@k8s-rac02 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdf           8:80   0  100G  0 disk 
sdd           8:48   0  100G  0 disk 
sdb           8:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
sdg           8:96   0  200G  0 disk 
sde           8:64   0  100G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot


[root@k8s-rac02 iscsi]#  iscsiadm -m session -R
Rescanning session [sid: 2, target: iqn.2023-11.com.oracle:rac, portal: 172.18.13.104,3260]
[root@k8s-rac02 iscsi]# lsscsi 
[1:0:0:0]    cd/dvd  SANGFOR  DVD-ROM          2.5+  /dev/sr0 
[2:0:0:0]    storage IET      Controller       0001  -        
[2:0:0:1]    disk    IET      VIRTUAL-DISK     0001  /dev/sda 
[2:0:0:2]    disk    IET      VIRTUAL-DISK     0001  /dev/sdb 
[2:0:0:3]    disk    IET      VIRTUAL-DISK     0001  /dev/sdc 
[2:0:0:4]    disk    IET      VIRTUAL-DISK     0001  /dev/sdd 
[2:0:0:5]    disk    IET      VIRTUAL-DISK     0001  /dev/sde 
[2:0:0:6]    disk    IET      VIRTUAL-DISK     0001  /dev/sdf 
[2:0:0:7]    disk    IET      VIRTUAL-DISK     0001  /dev/sdg 


[root@k8s-rac02 iscsi]# ll  /dev/disk/by-path
total 0
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-1 -> ../../sda
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-2 -> ../../sdb
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-3 -> ../../sdc
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-4 -> ../../sdd
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-5 -> ../../sde
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-6 -> ../../sdf
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-7 -> ../../sdg
lrwxrwxrwx 1 root root  9 Nov 21 19:00 pci-0000:00:01.1-ata-2.0 -> ../../sr0

[root@k8s-rac02 iscsi]# tree /var/lib/iscsi/
/var/lib/iscsi/
├── ifaces
├── isns
├── nodes
│   └── iqn.2023-11.com.oracle:rac
│       └── 172.18.13.104,3260,1
│           └── default
├── send_targets
│   └── 172.18.13.104,3260
│       ├── iqn.2023-11.com.oracle:rac,172.18.13.104,3260,1,default -> /var/lib/iscsi/nodes/iqn.2023-11.com.oracle:rac/172.18.13.104,3260,1
│       └── st_config
├── slp
└── static

10 directories, 2 files
[root@k8s-rac02 iscsi]# 

[root@k8s-rac02 iscsi]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
iscsid.startup = /bin/systemctl start iscsid.socket iscsiuio.socket
iscsid.safe_logout = Yes
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 120
node.conn[0].timeo.login_timeout = 15
node.conn[0].timeo.logout_timeout = 15
node.conn[0].timeo.noop_out_interval = 5
node.conn[0].timeo.noop_out_timeout = 5
node.session.err_timeo.abort_timeout = 15
node.session.err_timeo.lu_reset_timeout = 30
node.session.err_timeo.tgt_reset_timeout = 30
node.session.initial_login_retry_max = 8
node.session.cmds_max = 128
node.session.queue_depth = 32
node.session.xmit_thread_priority = -20
node.session.iscsi.InitialR2T = No
node.session.iscsi.ImmediateData = Yes
node.session.iscsi.FirstBurstLength = 262144
node.session.iscsi.MaxBurstLength = 16776192
node.conn[0].iscsi.MaxRecvDataSegmentLength = 262144
node.conn[0].iscsi.MaxXmitDataSegmentLength = 0
discovery.sendtargets.iscsi.MaxRecvDataSegmentLength = 32768
node.conn[0].iscsi.HeaderDigest = None
node.session.nr_sessions = 1
node.session.iscsi.FastAbort = Yes
node.session.scan = auto

#优化后参数
[root@k8s-rac02 iscsi]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
iscsid.startup = /bin/systemctl start iscsid.socket iscsiuio.socket
iscsid.safe_logout = Yes
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 3
node.conn[0].timeo.login_timeout = 15
node.conn[0].timeo.logout_timeout = 15
node.conn[0].timeo.noop_out_interval = 1
node.conn[0].timeo.noop_out_timeout = 1
node.session.err_timeo.abort_timeout = 15
node.session.err_timeo.lu_reset_timeout = 30
node.session.err_timeo.tgt_reset_timeout = 30
node.session.initial_login_retry_max = 2
node.session.cmds_max = 128
node.session.queue_depth = 32
node.session.xmit_thread_priority = -20
node.session.iscsi.InitialR2T = No
node.session.iscsi.ImmediateData = Yes
node.session.iscsi.FirstBurstLength = 262144
node.session.iscsi.MaxBurstLength = 16776192
node.conn[0].iscsi.MaxRecvDataSegmentLength = 262144
node.conn[0].iscsi.MaxXmitDataSegmentLength = 0
discovery.sendtargets.iscsi.MaxRecvDataSegmentLength = 32768
node.conn[0].iscsi.HeaderDigest = None
node.session.nr_sessions = 1
node.session.iscsi.FastAbort = Yes
node.session.scan = auto

```

#iscsi.service的状态变化

```bash
#yum install -y iscsi-initiator-utils libiscsi后 
[root@k8s-rac01 ~]# systemctl status iscsi
● iscsi.service - Login and scanning of iSCSI devices
   Loaded: loaded (/usr/lib/systemd/system/iscsi.service; enabled; vendor preset: disabled)
   Active: inactive (dead)
     Docs: man:iscsiadm(8)
           man:iscsid(8)
#重启后
[root@k8s-rac01 ~]# systemctl restart iscsi
[root@k8s-rac01 ~]# systemctl status iscsi
● iscsi.service - Login and scanning of iSCSI devices
   Loaded: loaded (/usr/lib/systemd/system/iscsi.service; enabled; vendor preset: disabled)
   Active: inactive (dead)
Condition: start condition failed at Wed 2023-11-22 10:12:27 CST; 1s ago
           ConditionDirectoryNotEmpty=/var/lib/iscsi/nodes was not met
     Docs: man:iscsiadm(8)
           man:iscsid(8)

#配置完跟
```



#### 1.7.2.后续如果出现共享磁盘的uuid乱了时，可以退出并重新扫描、登录

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

id grid
id oracle

#root/
#oracle/k8s123#@!
#grid/k8s123#@!
```
```bash
# id oracle
uid=11011(oracle) gid=11001(oinstall) groups=11001(oinstall),11002(dba),11003(oper),11004(backupdba),11005(dgdba),11006(kmdba),11007(asmdba),11010(racdba)
# id grid
uid=11012(grid) gid=11001(oinstall) groups=11001(oinstall),11002(dba),11007(asmdba),11008(asmoper),11009(asmadmin)
```



### 2.4. 配置 host 表

#hosts 文件配置
#hostname
```bash
#rac01
hostnamectl set-hostname k8s-rac01
#rac02
hostnamectl set-hostname k8s-rac02

cat >> /etc/hosts <<EOF
#public ip 
172.18.13.97 k8s-rac01
172.18.13.98 k8s-rac02
#vip
172.18.13.99  k8s-rac01-vip
172.18.13.100 k8s-rac02-vip
#private ip
10.100.100.97 k8s-rac01-prv
10.100.100.98 k8s-rac02-prv
#scan ip
172.18.13.101 rac-scan
EOF
```
#检查下网络是否顺畅

```bash
ping k8s-rac01 -c 1

ping k8s-rac02 -c 1

ping k8s-rac01-vip -c 1

ping k8s-rac02-vip -c 1

ping k8s-rac01-prv -c 1

ping k8s-rac02-prv -c 1

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
clockdiff k8s-rac01
clockdiff k8s-rac02

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

ulimit -a
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
##如果由于H3C CAS虚拟化平台磁盘类型中没有scsi类型，导致不支持scsi_id命令识别磁盘，只能使用udevadm查看，而学校暂不支持改为裸块加入iscsi高速硬盘
##可以采用oracle asmlib管理磁盘
#/usr/lib/udev/scsi_id -g -u -d devicename
ls -1cv /dev/vs* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; udevadm info --query=all --name=$disk|grep ID_SERIAL ; done
```
#本次正常使用udev管理磁盘

```
[root@k8s-rac01 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sde: 104857600
/dev/sdf: 104857600
/dev/sdg: 209715200
total: 932179968 blocks
[root@k8s-rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007

[root@k8s-rac02 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdf: 104857600
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sdg: 209715200
/dev/sde: 104857600
total: 932179968 blocks
[root@k8s-rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
```
#oracleasm管理磁盘---本次不使用

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





#其他正常学校的配置步骤---本次使用

```bash
[root@k8s-rac01 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sde: 104857600
/dev/sdf: 104857600
/dev/sdg: 209715200
total: 932179968 blocks
[root@k8s-rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
[root@k8s-rac01 ~]#


[root@k8s-rac02 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdf: 104857600
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sdg: 209715200
/dev/sde: 104857600
total: 932179968 blocks
[root@k8s-rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
[root@k8s-rac02 ~]#

```

#99-oracle-asmdevices.rules

```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sda", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010001", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdb", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010002", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdc", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010003", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdd", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010004", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sde", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010005", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdf", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010006", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdg", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010007", OWNER="grid",GROUP="asmadmin", MODE="0660"
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
[root@k8s-rac01 ~]# ll /dev|grep asm
brw-rw----  1 grid asmadmin   8,   0 Nov 17 19:04 sda
brw-rw----  1 grid asmadmin   8,  16 Nov 17 19:04 sdb
brw-rw----  1 grid asmadmin   8,  32 Nov 17 19:04 sdc
brw-rw----  1 grid asmadmin   8,  48 Nov 17 19:04 sdd
brw-rw----  1 grid asmadmin   8,  64 Nov 17 19:04 sde
brw-rw----  1 grid asmadmin   8,  80 Nov 17 19:04 sdf
brw-rw----  1 grid asmadmin   8,  96 Nov 17 19:04 sdg
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

```bash
#oracle/k8s123#@!
#grid/k8s123#@!

#可以用/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh
#仅在节点一root用户下执行

/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh -user grid  -hosts "k8s-rac01 k8s-rac02" -advanced exverify -confirm

/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh -user grid  -hosts "k8s-rac01 k8s-rac02" -advanced exverify -confirm

#也可以用下面的步骤挨个执行
```

#grid用户

```bash
su - grid

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在k8s-rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh k8s-rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh k8s-rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-rac02:~/.ssh/authorized_keys

ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh  k8s-rac01 date -Ins;ssh  k8s-rac02 date -Ins;ssh  k8s-rac01-prv date -Ins;ssh  k8s-rac02-prv date -Ins

#在k8s-rac02执行
ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh  k8s-rac01 date -Ins;ssh  k8s-rac02 date -Ins;ssh  k8s-rac01-prv date -Ins;ssh  k8s-rac02-prv date -Ins
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在k8s-rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh k8s-rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh k8s-rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-rac02:~/.ssh/authorized_keys

ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh  k8s-rac01 date -Ins;ssh  k8s-rac02 date -Ins;ssh  k8s-rac01-prv date -Ins;ssh  k8s-rac02-prv date -Ins

#在k8s-rac02上执行
ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh k8s-rac01 date;ssh k8s-rac02 date;ssh k8s-rac01-prv date;ssh k8s-rac02-prv date

ssh  k8s-rac01 date -Ins;ssh  k8s-rac02 date -Ins;ssh  k8s-rac01-prv date -Ins;ssh  k8s-rac02-prv date -Ins
```



#后面升级openssh后，原来配置的互信失效，重新配置，此时可以再次使用rsa和dsa，也可以使用ecdsa和ed25519，但是必须scp -O

#vi .bashrc

#alias scp="scp -O"

#grid用户

#k8s123#@!

```bash
su - grid

cd /home/grid
mv .ssh .ssh.bak
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ecdsa

ssh-keygen -t ed25519

#以下只在oracle01执行，逐条执行
cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

scp -O ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
#在oracle02执行
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
```
#oracle用户

#k8s123#@!

```bash
su - oracle

cd /home/oracle
mv .ssh .ssh.bak
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ecdsa

ssh-keygen -t ed25519

#以下只在oracle01执行，逐条执行
cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

scp -O ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

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
scp cvuqdisk-1.0.10-1.rpm k8s-rac02:/u01

#两台服务器都安装
su - root
cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm

#节点一安装前检查：
[grid@rac01 ~]$ cd /u01/app/19.0.0/grid/
[grid@rac01 grid]$ ./runcluvfy.sh stage -pre crsinst -n k8s-rac01,k8s-rac02 -fixup -verbose|tee -a pre.log

#./runcluvfy.sh stage -pre crsinst -allnodes -fixup -verbose -method root|tee -a pre.log
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
4. 添加节点2并测试节点互信(Add k8s-rac02/k8s-rac02-vip, SSH connectivity--->Test)
5. 公网、私网网段选择(eth1-10.100.100.0-ASM&private/eth0-172.18.0.0-public)
6. 选择 asm 存储(use oracle flex ASM for storage)
7. 选择不单独为GIMR配置磁盘组
8. 选择 asm 磁盘组(ORC/normal/50G三块磁盘/扫描的磁盘路径: /dev/sd*)
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

    先在k8s-rac01上执行完毕,再去k8s-rac02执行
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
### 3.5.错误处理---oracle linux server不存在这些错误

#### 3.5.1.错误处理执行root.sh时报错缺少libcap.so.1

```
Installing Trace File Analyzer
Failed to create keys in the OLR, rc = 127, Message:
  /u01/app/11.2.0/grid/bin/clscfg.bin: error while loading shared libraries: libcap.so.1: cannot open shared object file: No such file or directory

Failed to create keys in the OLR at /u01/app/11.2.0/grid/crs/install/crsconfig_lib.pm line 7660.
/u01/app/11.2.0/grid/perl/bin/perl -I/u01/app/11.2.0/grid/perl/lib -I/u01/app/11.2.0/grid/crs/install /u01/app/11.2.0/grid/crs/install/rootcrs.pl execution failed

```

#解决办法，oracle01/oracle02都执行

```bash
cd /lib64
ll|grep libcap
ln -s libcap.so.2.22 libcap.so.1
ll|grep libcap
```

#然后oracle01重新执行root.sh

```bash
/u01/app/11.2.0/grid/root.sh
```

#### 3.5.2.执行root.sh报错ohasd failed to start

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

[root@oracle01 init.d]# systemctl status ohas.service
● ohas.service - Oracle High Availability Services
   Loaded: loaded (/usr/lib/systemd/system/ohas.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2022-01-04 11:45:14 CST; 8s ago
 Main PID: 42231 (init.ohasd)
   CGroup: /system.slice/ohas.service
           └─42231 /bin/sh /etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple

Jan 04 11:45:14 oracle01 systemd[1]: Started Oracle High Availability Services.


#此时oracle01的root.sh会继续安装下去，无需重新执行root.sh脚本

#注意： 为了避免其余节点遇到这种报错，可以在root.sh执行过程中，待/etc/init.d/目录下生成了init.ohasd 文件后，执行systemctl start ohas.service 启动ohas服务即可。若没有/etc/init.d/init.ohasd文件 systemctl start ohas.service 则会启动失败。
```

#### 3.5.3.asm及crsd报错CRS-4535: Cannot communicate with Cluster Ready Services

#如果是光纤直连服务器和SAN存储，因OCR检查时间是15s，但是服务器与存储间检查时间是30s，导致asm报错，从而crs整体报错

```bash
[root@oracle01 ~]# cat /sys/block/sdb/device/timeout 
30
[root@oracle01 ~]# sqlplus / as sysasm
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
#oracle01/oracle02都要修改

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

#oracle01/oracle02都要重启crs生效

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

#/u01/app/11.2.0/grid/log/oracle02/crsd/crsd.log
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

#### 3.5.4.添加listener---grid用户

#上面错误解决后，发现集群缺少listener

```
[grid@oracle01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle02                                     
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle02                             
      
[root@oracle02 ~]# lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 04-JAN-2022 16:54:49

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 111: Connection refused
[root@oracle02 ~]# su - grid
Last login: Tue Jan  4 14:06:57 CST 2022 on pts/0
[grid@oracle02 ~]$ srvctl config listener
PRCN-2044 : No listener exists
```

#尝试添加

```bash
[grid@oracle02 ~]$ srvctl add listener -l listener -p 1521 
PRCN-2061 : Failed to add listener ora.LISTENER.lsnr
PRCN-2065 : Port(s) 1521 are not available on the nodes given
PRCN-2067 : Port 1521 is not available across node(s) "oracle01-vip"

#先停止oracle01-vip和oracle02-vip
crsctl stop resource ora.oracle01.vip
crsctl stop resource ora.oracle01.vip
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
[grid@oracle02 admin]$ srvctl stop scan_listener

[grid@oracle02 admin]$ srvctl add listener -l listener
PRCN-2061 : Failed to add listener ora.LISTENER.lsnr
PRCN-2065 : Port(s) 1521 are not available on the nodes given
PRCN-2067 : Port 1521 is not available across node(s) "oracle01-vip"

[grid@oracle02 admin]$ crsctl stop resource ora.oracle01.vip
CRS-2673: Attempting to stop 'ora.oracle01.vip' on 'oracle01'
CRS-2677: Stop of 'ora.oracle01.vip' on 'oracle01' succeeded

[grid@oracle02 admin]$ crsctl stop resource ora.oracle02.vip
CRS-2673: Attempting to stop 'ora.oracle02.vip' on 'oracle02'
CRS-2677: Stop of 'ora.oracle02.vip' on 'oracle02' succeeded

[grid@oracle02 admin]$ srvctl add listener -l listener

[grid@oracle02 admin]$ srvctl config listener
Name: LISTENER
Network: 1, Owner: grid
Home: <CRS home>
End points: TCP:1521

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------                              
ora.LISTENER.lsnr
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        OFFLINE OFFLINE                                                   
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        OFFLINE OFFLINE                                                   
ora.oracle02.vip
      1        OFFLINE OFFLINE                                                   
ora.scan1.vip
      1        ONLINE  ONLINE       oracle02                                     
[grid@oracle02 admin]$ srvctl start listener -l listener

[grid@oracle02 admin]$ crsctl start resource ora.oracle02.vip
CRS-5702: Resource 'ora.oracle02.vip' is already running on 'oracle02'
CRS-4000: Command Start failed, or completed with errors.

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE oracle01                 Not All Endpoints Registered           
               ONLINE  ONLINE       oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        OFFLINE OFFLINE                                                   
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle02                                     
[grid@oracle02 admin]$ crsctl status resource ora.LISTENER_SCAN1.lsnr
NAME=ora.LISTENER_SCAN1.lsnr
TYPE=ora.scan_listener.type
TARGET=OFFLINE
STATE=OFFLINE

[grid@oracle02 admin]$ srvctl start scan_listener

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE oracle01                 Not All Endpoints Registered           
               ONLINE  ONLINE       oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  INTERMEDIATE oracle01                 Not All Endpoints R 
                                                             egistered           
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01                                     
[grid@oracle02 admin]$ srvctl start scan_listener
PRCC-1014 : LISTENER_SCAN1 was already running
PRCR-1004 : Resource ora.LISTENER_SCAN1.lsnr is already running
PRCR-1079 : Failed to start resource ora.LISTENER_SCAN1.lsnr
CRS-5702: Resource 'ora.LISTENER_SCAN1.lsnr' is already running on 'oracle01'

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE oracle01                 Not All Endpoints R 
                                                             egistered           
               ONLINE  ONLINE       oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  INTERMEDIATE oracle01                 Not All Endpoints R 
                                                             egistered           
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01                                     

[root@oracle02 ~]# . oraenv
ORACLE_SID = [+ASM2] ? 
The Oracle base remains unchanged with value /u01/app/grid
[root@oracle02 ~]# crsctl stop cluster -all
CRS-2673: Attempting to stop 'ora.crsd' on 'oracle02'
CRS-2673: Attempting to stop 'ora.crsd' on 'oracle01'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'oracle01'
CRS-2673: Attempting to stop 'ora.oc4j' on 'oracle01'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'oracle01'
CRS-2673: Attempting to stop 'ora.LISTENER_SCAN1.lsnr' on 'oracle01'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'oracle01'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'oracle01'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'oracle01'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'oracle02'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'oracle02'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'oracle02'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'oracle02'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'oracle02'
CRS-2673: Attempting to stop 'ora.cvu' on 'oracle02'
CRS-2677: Stop of 'ora.cvu' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.oracle01.vip' on 'oracle01'
CRS-2677: Stop of 'ora.LISTENER_SCAN1.lsnr' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.scan1.vip' on 'oracle01'
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.oracle02.vip' on 'oracle02'
CRS-2677: Stop of 'ora.DATA.dg' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.DATA.dg' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.FRA.dg' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.FRA.dg' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.oracle02.vip' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.oracle01.vip' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.scan1.vip' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.oc4j' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.OCR.dg' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'oracle01'
CRS-2677: Stop of 'ora.OCR.dg' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'oracle02'
CRS-2677: Stop of 'ora.asm' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.asm' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.ons' on 'oracle02'
CRS-2677: Stop of 'ora.ons' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'oracle02'
CRS-2677: Stop of 'ora.net1.network' on 'oracle02' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'oracle02' has completed
CRS-2673: Attempting to stop 'ora.ons' on 'oracle01'
CRS-2677: Stop of 'ora.ons' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'oracle01'
CRS-2677: Stop of 'ora.net1.network' on 'oracle01' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'oracle01' has completed
CRS-2677: Stop of 'ora.crsd' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'oracle02'
CRS-2673: Attempting to stop 'ora.evmd' on 'oracle02'
CRS-2673: Attempting to stop 'ora.asm' on 'oracle02'
CRS-2677: Stop of 'ora.crsd' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'oracle01'
CRS-2673: Attempting to stop 'ora.evmd' on 'oracle01'
CRS-2673: Attempting to stop 'ora.asm' on 'oracle01'
CRS-2677: Stop of 'ora.evmd' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.evmd' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.asm' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'oracle02'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'oracle02'
CRS-2677: Stop of 'ora.cssd' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.asm' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'oracle01'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'oracle01'
CRS-2677: Stop of 'ora.cssd' on 'oracle01' succeeded
[root@oracle02 ~]# 

```


## 4.创建 ASM 数据磁盘

### 4.1. grid 账户登录图形化界面，执行 asmca
#创建asm磁盘组步骤
```
1. DiskGroups界面点击Create
2. #asmlib管理的话
DATA/External/(/dev/oracleasm/disks/DATA01、/dev/oracleasm/disks/DATA02、/dev/oracleasm/disks/DATA03)，点击OK

#本次共享磁盘
DATA/External/(/dev/sdd、/dev/sde、/dev/sdf)，点击OK
3. 继续点击Create
4.  #asmlib管理的话FRA/External/(/dev/oracleasm/disks/FRA01、/dev/oracleasm/disks/FRA02、/dev/oracleasm/disks/FRA03)，点击OK

#本次共享磁盘
FRA/External/(/dev/sdg)，点击OK
5. Exit
```
![image-20231118184625244](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle-store\image-20231118184625244.png)

### 4.2 查看状态

```
[grid@k8s-rac01 ~]$ crsctl status resource -t
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
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
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
[grid@rac01 grid]$ ./runcluvfy.sh stage -pre dbinst -n k8s-rac01,k8s-rac02 -fixup -verbose|tee -a pre-db.log
```

#关于rac-scan的解析失败，可以忽略

```
Verifying DNS/NIS name service 'rac-scan' ...FAILED
  PRVG-11826 : DNS resolved IP addresses "" for SCAN name "rac-scan" not found
  in the name service returned IP addresses "172.18.13.101"
  PRVG-11827 : Name service returned IP addresses "172.18.13.101" for SCAN name
  "rac-scan" not found in the DNS returned IP addresses ""

  k8s-rac02: PRVF-4664 : Found inconsistent name resolution entries for SCAN
             name "rac-scan"

  k8s-rac01: PRVF-4664 : Found inconsistent name resolution entries for SCAN
             name "rac-scan"
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
3. SSH互信测试(SSH connectivity--->Test)
4. Enterprise Edition
5. $ORACLE_BASE(/u01/app/oracle)
6. 用户组，保持默认
7. 不执行配置脚本，保持默认
8. 忽略全部--->Yes
9. Install
10. root账户先在k8s-rac01执行完毕后再在k8s-rac02上执行脚本(/u01/app/oracle/product/19.0.0/db_1/root.sh)，然后点击OK
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
       #pga=memory*65%*25%=64G*65%*25%=10.4G(向下十位取整为10G)
       #sga=30G
       #pag=10G
       #此处为总32G，所以sga=15G,pga=5G
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
[grid@k8s-rac01 ~]$ crsctl status resource -t
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
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
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
--------------------------------------------------------------------------------

[grid@k8s-rac01 ~]$  srvctl config database -d xydb
Database unique name: xydb
Database name: xydb
Oracle home: /u01/app/oracle/product/19.0.0/db_1
Oracle user: oracle
Spfile: +DATA/XYDB/PARAMETERFILE/spfile.272.1153251931
Password file: +DATA/XYDB/PASSWORD/pwdxydb.256.1153250601
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
Configured nodes: k8s-rac01,k8s-rac02
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
	  1 k8s-rac01:xydb1
	  2 k8s-rac02:xydb2

SQL> SELECT instance_name, host_name FROM gv$instance;

INSTANCE_NAME	 HOST_NAME
---------------- --------------------------------
xydb1		 k8s-rac01
xydb2		 k8s-rac02

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
	 3 STUWORK			  READ WRITE NO

SQL>  alter session set container=STUWORK;

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
#user password life修改，一个节点(k8s-rac01或者k8s-rac02)修改即可(CDB/PDB)

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
#数据库自启动---两个节点都要修改

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

srvctl stop database -d xydb
srvctl start database -d xydb

sqlplus / as sysdba
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

 alter system set "_disable_file_resize_logging"=TRUE scope=both sid='*';
```





##创建service

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



#### 7.1.1.检查集群状态

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



#### 7.1.2.更新grid opatch 两个节点 root执行

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

 

#### 7.1.4.解压patch包 两个节点 root执行

```bash
#这一个包 包含了全部的patch
unzip /opt/19.20patch/p35319490_190000_Linux-x86-64.zip -d /opt/19.20patch/

chown -R grid:oinstall /opt/19.20patch/35319490

chmod -R 755 /opt/19.20patch/35319490

#此时可以查看35319490文件夹下的 README.html，里面有详细的RU步骤
```



#### 7.1.5.兼容性检查

```bash
#OPatch兼容性检查 两个节点 grid用户

 su - grid

/u01/app/19.0.0/grid/OPatch/opatch lsinventory -detail -oh /u01/app/19.0.0/grid/

#OPatch兼容性检查 两个节点 oracle用户

 su - oracle

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatch lsinventory -detail -oh /u01/app/oracle/product/19.0.0/db_1/
```



#### 7.1.6.补丁冲突检查 k8s-rac01/k8s-rac02两个节点都执行

```bash
#子目录的五个patch在grid用户下分别执行检查

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



#### 7.1.7.空间检查 k8s-rac01/k8s-rac02两个节点都执行

```bash
#grid用户执行

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
/opt/19.20patch/35319490/35320081
/opt/19.20patch/35319490/35320149
EOF

$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_list_dbhome.txt
```



#### 7.1.8.补丁分析检查  root用户两个节点都要分别执行 

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



#### 7.1.9.grid 升级 root两个节点都要分别执行 --grid upgrade

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



#### 7.1.10.oracle 升级 root两个节点都要分别执行 --oracle upgrade

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





#### 7.1.11.升级后动作 after patch

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

### 7.2.接着打19.21RU---执行过程同7.1

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

