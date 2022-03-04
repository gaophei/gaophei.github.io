**oracle011g RAC for Centos7.9 安装手册**

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
2.准备工作（oracle01 与 oracle02 同时配置）
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
[root@oracle01 Packages]# cat /etc/redhat-release
CentOS Linux release 7.9.2009 (Core)
[root@oracle01 ~]# uname -a
Linux oracle01 3.10.0-1160.49.1.el7.x86_64 #1 SMP Tue Nov 30 15:51:32 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux
```
### 1.2. ASM 磁盘组规划
```
ASM 磁盘组 用途 大小 冗余
ocr、 voting file   100G+100G+100G NORMAL
DATA 数据文件 1T+1T+1T EXTERNAL
FRA    归档日志 500G EXTERNAL
```
### 1.3. 主机网络规划

#### 1.3.1.IP规划
```
网络配置               节点 1                               节点 2
主机名称               oracle01                             oracle02
public ip            10.119.5.60                       10.119.5.61
private ip           192.168.5.60                      192.168.5.61
vip                  10.119.5.62                       10.119.5.63
scan ip              10.119.5.64
```
#### 1.3.2.网卡配置

##### 1.3.2.1.网卡eno1/eno2做网卡绑定(IP10.119.5.65)，连接存储
```bash
#开启bonding
lsmod | grep bonding
cd /etc/sysconfig/modules/

cat >> bonding.modules <<EOF
modprobe bonding
EOF

chmod 755 bonding.modules 

reboot

lsmod | grep bonding

#关闭NetworkManager
systemctl list-units | grep NetworkManager

systemctl stop NetworkManager.service
systemctl disable NetworkManager.service

#bonding
cd /etc/sysconfig/network-scripts/

cp ifcfg-eno1 ifcfg-eno1.bak
cp ifcfg-eno2 ifcfg-eno2.bak
cp ifcfg-eno3 ifcfg-eno3.bak
cp ifcfg-eno4 ifcfg-eno4.bak

cat > ifcfg-bond0 <<EOF
DEVICE=bond0
TYPE=Bond
IPADDR=10.119.5.65
NETMASK=255.255.255.0
DNS1=210.31.0.9
DNS2=210.31.0.10
DEFROUTE=no
USERCTL=no
BOOTPROTO=none
ONBOOT=yes
BONDING_MASTER=yes
BONDING_OPTS="mode=6 miimon=100"
EOF

cat > ifcfg-eno1 <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=no
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno1
UUID=a6807a27-1879-4e07-89eb-c1b6246bb4d6
DEVICE=eno1
ONBOOT=yes
USERCTL=no
MASTER=bond0
SLAVE=yes
EOF

cat > ifcfg-eno2 <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=no
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno2
UUID=4490141e-f33b-46a7-8e6c-6240289dbbf9
DEVICE=eno2
ONBOOT=yes
USERCTL=no
MASTER=bond0
SLAVE=yes
EOF

systemctl restart network.service

ifconfig

route -n
#设置默认路由
route del -net 0.0.0.0 gw 10.119.5.60 dev bond0
route del -net 0.0.0.0 gw 10.119.5.60 dev eno3
route add default gw 10.119.5.254 dev eno3

#配置iscsi连接
yum install -y iscsi-initiator-utils
systemctl list-units iscsi

systemctl restart iscsid.service
systemctl enable iscsid

#存储划分卷
ocr-100G/100G/100G
data-1T/1T/1T
fra-500G
#存储建立主机
#oracle01
cat /etc/iscsi/initiatorname.iscsi 
InitiatorName=iqn.1994-05.com.redhat:2b34b39bd76
#oracle02
cat /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.1994-05.com.redhat:19cf36dd2c63
#映射主机跟卷
#oracle01查找iscsi目标及挂载磁盘
iscsiadm --help
iscsiadm -m discovery -t sendtargets -p 10.119.8.3
iscsiadm -m discovery -t sendtargets -p 10.119.8.4
iscsiadm -m discovery -t sendtargets -p 10.119.8.5
iscsiadm -m discovery -t sendtargets -p 10.119.8.6
#出现提示类似如下
#10.119.8.3:3260,1 iqn.1986-03.com.ibm:2145.fleetystore.node2
#登入节点
iscsiadm -m node -T iqn.2006-08.com.huawei:oceanstor:2100244c07e97626::20100:10.119.8.3 -p 10.119.8.3:3260 -l
#提示如下表示正常
#Logging in to [iface: default, target: iqn.2006-08.com.huawei:oceanstor:2100244c07e97626::20100:10.119.8.3, portal: 10.119.8.3,3260] (multiple)
#Login to [iface: default, target: iqn.2006-08.com.huawei:oceanstor:2100244c07e97626::20100:10.119.8.3, portal: 10.119.8.3,3260] successful.
#配置在系统启动时自动登入
iscsiadm -m node -o update -n node.startup -v automatic
#iscsiadm -m node [ -hV ] [ -d debug_level ] [ -P printlevel ] [ -L all,manual,automatic ] [ -U all,manual,automatic ] [ -S ] [ [ -T targetname -p ip:port -I ifaceN ] [ -l | -u | -R | -s] ] [ [ -o  operation  ] [ -n name ] [ -v value ] 
#iscsiadm -m node -T iqn.2006-08.com.huawei:oceanstor:2100244c07e97626::20100:10.119.8.3 -p 10.119.8.3:3260 --op update -n node.startup -v automatic

#安装多路径软件
unzip OceanStor_UltraPath_31.0.2_CentOS.zip
chmod 777 install.sh
./install.sh
#查看磁盘
fdisk -l

sfdisk -s
```
##### 1.3.2.2.网卡eno3走业务网
```bash
cat >> ifcfg-eno3 <<EOF
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
NAME="eno3"
UUID="4bb212fa-1bd1-487c-b13a-232cd336c389"
DEVICE="eno3"
ONBOOT="yes"
IPADDR="10.119.5.60"
PREFIX="24"
DNS1="210.31.0.9"
IPV6_PRIVACY="no"
DNS2="210.31.0.10"
EOF
```

##### 1.3.2.3.网卡eno4两台服务器直连，做私有网络
```bash
cat > ifcfg-eno4 <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
#DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno4
UUID=0948e888-9973-4a35-b5ea-ecb76f296422
DEVICE=eno4
ONBOOT=yes
IPADDR=192.168.5.60
NETMASK=255.255.255.0
EOF

systemctl restart network
ifconfig
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
[root@oracle01 ~]# ip route list
default via 10.119.5.254 dev eno3 
#10.119.5.0/24 dev bond0 proto kernel scope link src 10.119.5.65 
10.119.5.0/24 dev eno3 proto kernel scope link src 10.119.5.60 
10.119.8.3 via 10.119.5.254 dev bond0 src 10.119.5.65 
10.119.8.4 via 10.119.5.254 dev bond0 src 10.119.5.65 
10.119.8.5 via 10.119.5.254 dev bond0 src 10.119.5.65 
10.119.8.6 via 10.119.5.254 dev bond0 src 10.119.5.65 
169.254.0.0/16 dev eno3 scope link metric 1004 
169.254.0.0/16 dev eno4 scope link metric 1005 
169.254.0.0/16 dev bond0 scope link metric 1006 
192.168.5.0/24 dev eno4 proto kernel scope link src 192.168.5.60 

[root@oracle01 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.119.5.254    0.0.0.0         UG    0      0        0 eno3
10.119.5.0      0.0.0.0         255.255.255.0   U     0      0        0 bond0
10.119.5.0      0.0.0.0         255.255.255.0   U     0      0        0 eno3
10.119.8.3      10.119.5.254    255.255.255.255 UGH   0      0        0 bond0
10.119.8.4      10.119.5.254    255.255.255.255 UGH   0      0        0 bond0
10.119.8.5      10.119.5.254    255.255.255.255 UGH   0      0        0 bond0
10.119.8.6      10.119.5.254    255.255.255.255 UGH   0      0        0 bond0
169.254.0.0     0.0.0.0         255.255.0.0     U     1004   0        0 eno3
169.254.0.0     0.0.0.0         255.255.0.0     U     1005   0        0 eno4
169.254.0.0     0.0.0.0         255.255.0.0     U     1006   0        0 bond0
192.168.5.0     0.0.0.0         255.255.255.0   U     0      0        0 eno4

[root@oracle01 network-scripts]# ls
ifcfg-bond0  ifcfg-eno3      ifcfg-lo     ifdown-eth   ifdown-isdn  ifdown-routes  ifdown-TeamPort  ifup-aliases  ifup-ippp  ifup-plip   ifup-ppp     ifup-Team      ifup-wireless      network-functions-ipv6
ifcfg-eno1   ifcfg-eno4      ifdown       ifdown-ippp  ifdown-post  ifdown-sit     ifdown-tunnel    ifup-bnep     ifup-ipv6  ifup-plusb  ifup-routes  ifup-TeamPort  init.ipv6-global   route-bond0
ifcfg-eno2   ifcfg-eno4.bak  ifdown-bnep  ifdown-ipv6  ifdown-ppp   ifdown-Team    ifup             ifup-eth      ifup-isdn  ifup-post   ifup-sit     ifup-tunnel    network-functions  route-eno3

[root@oracle01 network-scripts]# ifconfig
bond0: flags=5187<UP,BROADCAST,RUNNING,MASTER,MULTICAST>  mtu 1500
        inet 10.119.5.65  netmask 255.255.255.0  broadcast 10.119.5.255
        ether 28:de:e5:c0:b5:ac  txqueuelen 1000  (Ethernet)
        RX packets 1582188  bytes 2112928920 (1.9 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 96698  bytes 8754462 (8.3 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eno1: flags=6211<UP,BROADCAST,RUNNING,SLAVE,MULTICAST>  mtu 1500
        ether 28:de:e5:c0:b5:ac  txqueuelen 1000  (Ethernet)
        RX packets 57398  bytes 32064048 (30.5 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 52174  bytes 4776228 (4.5 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eno2: flags=6211<UP,BROADCAST,RUNNING,SLAVE,MULTICAST>  mtu 1500
        ether 28:de:e5:c0:b5:ad  txqueuelen 1000  (Ethernet)
        RX packets 1524790  bytes 2080864872 (1.9 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 44524  bytes 3978234 (3.7 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eno3: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.119.5.60  netmask 255.255.255.0  broadcast 10.119.5.255
        ether 28:de:e5:c0:b5:ae  txqueuelen 1000  (Ethernet)
        RX packets 1336415  bytes 1871639057 (1.7 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 1193831  bytes 92620781 (88.3 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eno4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.5.60  netmask 255.255.255.0  broadcast 192.168.5.255
        ether 28:de:e5:c0:b5:af  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 6  bytes 252 (252.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0


[root@oracle01 network-scripts]# cat ifcfg-bond0 
DEVICE=bond0
TYPE=Bond
IPADDR=10.119.5.65
NETMASK=255.255.255.0
DNS1=210.31.0.9
DNS2=210.31.0.10
DEFROUTE=no
USERCTL=no
BOOTPROTO=none
ONBOOT=yes
BONDING_MASTER=yes
BONDING_OPTS="mode=6 miimon=100"
[root@oracle01 network-scripts]# cat ifcfg-eno1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=no
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno1
UUID=a6807a27-1879-4e07-89eb-c1b6246bb4d6
DEVICE=eno1
ONBOOT=yes
USERCTL=no
MASTER=bond0
SLAVE=yes
[root@oracle01 network-scripts]# cat ifcfg-eno2
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=no
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno2
UUID=4490141e-f33b-46a7-8e6c-6240289dbbf9
DEVICE=eno2
ONBOOT=yes
USERCTL=no
MASTER=bond0
SLAVE=yes
[root@oracle01 network-scripts]# cat ifcfg-eno3
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
NAME="eno3"
UUID="4bb212fa-1bd1-487c-b13a-232cd336c389"
DEVICE="eno3"
ONBOOT="yes"
IPADDR="10.119.5.60"
PREFIX="24"
DNS1="210.31.0.9"
IPV6_PRIVACY="no"
DNS2="210.31.0.10"
[root@oracle01 network-scripts]# cat ifcfg-eno4
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
#DEFROUTE=yes
DEFROUTE=no
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno4
UUID=0948e888-9973-4a35-b5ea-ecb76f296422
DEVICE=eno4
ONBOOT=yes
IPADDR=192.168.5.60
NETMASK=255.255.255.0

[root@oracle01 ~]# sfdisk -s
/dev/sda: 2343665664
/dev/mapper/centos-root: 2308853760
/dev/mapper/centos-swap:  33554432
/dev/sdb: 104857600
/dev/sdc: 104857600
/dev/sdd: 104857600
/dev/sde: 1073741824
/dev/sdf: 1073741824
/dev/sdg: 1073741824
/dev/sdh: 524288000
total: 8746160128 blocks

[root@oracle01 ~]# arp -a
oracle01 (10.119.5.60) at 28:de:e5:c0:b5:ae [ether] on bond0
gateway (10.119.5.254) at 00:00:5e:00:01:02 [ether] on bond0
gateway (10.119.5.254) at 00:00:5e:00:01:02 [ether] on eno3
? (192.168.5.61) at 28:de:e5:c0:b3:b4 [ether] on eno4
[root@oracle02 ~]# arp -a
? (192.168.5.60) at 28:de:e5:c0:b5:af [ether] on eno4
oracle02 (10.119.5.61) at 28:de:e5:c0:b3:b3 [ether] on bond0
gateway (10.119.5.254) at 00:00:5e:00:01:02 [ether] on eno3
gateway (10.119.5.254) at 00:00:5e:00:01:02 [ether] on bond0
[root@oracle02 network-scripts]# 

#oracle02内容类似
```
##### 1.3.2.5.网卡绑定方法二
#需绑定网卡信息
```
RAC1: 00:26:28:9B:4B:60  00:26:28:9B:4B:61 两个网卡 bond 一下
RAC2: 00:26:28:9B:49:90   00:26:28:9B:49:91 两个网卡 bond 一下
```
#若安装的OS为RHEL7则按照如下方式配置bond，以bond_pub为例。
#分别登录服务器节点：
#a. 创建bond_priv。
```bash
nmcli con add type bond ifname bond_pub mode balance-xor
```
#b. 配置bond_priv的IP地址。
```
nmcli connection modify bond-bond_pub ipv4.addresses 10.8.14.11/24 ipv4.gateway 10.8.14.1 ipv4.dns 210.34.128.33

nmcli connection modify bond-bond_pub ipv4.method manual
```
#c. 增加slave网口。本例中为“ens4f0”和“ens6f0”，请根据实际情况修改。
```bash
nmcli con add type bond-slave ifname ens1f0 master bond-bond_pub
nmcli con add type bond-slave ifname ens1f1d1 master bond-bond_pub
nmcli conn up bond-slave-ens1f0
nmcli conn up bond-slave-ens1f1d1
```
#d. 查看配置信息。
```
cat /proc/net/bonding/bond_pub
nmcli connection show
```
#如果输出信息如下则说明配置成功。
```
bond-slave-ens4f0 1c88d785-b280-4999-96d5-237d4e761e43 802-3-ethernet ens4f0
bond-slave-ens6f0 e6845549-b897-4cb8-9487-9004c71e3741 802-3-ethernet ens6f0
bond-bond_sr 5a3cb631-be4c-44d5-ae9a-95b01d6a6c03 bond bond_pub
```

##### 1.3.2.6.华为存储光纤跳线直连配置
#linux查看fc hba卡
```bash
cat  /sys/class/fc_host/host1/port_name
cat  /sys/class/fc_host/host2/port_name
```
#存储中添加san主机
#配置多路径ultrapath:
#安装:
```bash
unzip OceanStor_UltraPath_31.0.2_CentOS.zip 
   ./install.sh
   --->选1：boot from local
   --->y:reboot
```
#添加配置存储：
#hot_add扫描设备：
```bash
   hot_add
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
getenforce
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

#使用阿里云的源
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

yum clean all && yum makecache all
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
#oracle01
hostnamectl set-hostname oracle01
#oracle02
hostnamectl set-hostname oracle02

cat >> /etc/hosts <<EOF
#public ip ens32
10.119.5.60 oracle01
10.119.5.61 oracle02
#vip
10.119.5.62 oracle01-vip
10.119.5.63 oracle02-vip
#private ip ens160
192.168.5.60 oracle01-prv
192.168.5.61 oracle02-prv
#scan ip
10.119.5.64 rac-scan

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
#memory192G
```bash
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 42187500
#memory*90%
kernel.shmmax = 172800000000
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

#grid用户，注意oracle01/oracle02两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意oracle02修改
#export ORACLE_SID=+ASM2
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/11.2.0/grid
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
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1
export ORACLE_SID=xydb1
#注意oracle02修改
#export ORACLE_SID=xydb2
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
/usr/lib/udev/scsi_id -g -u -d devicename
```
#显示如下
```
[root@oracle01 ~]# sfdisk -s
/dev/sda: 2343665664
/dev/mapper/centos-root: 2308853760
/dev/mapper/centos-swap:  33554432
/dev/sdb: 104857600
/dev/sdc: 104857600
/dev/sdd: 104857600
/dev/sde: 1073741824
/dev/sdf: 1073741824
/dev/sdg: 1073741824
/dev/sdh: 524288000
total: 8746160128 blocks

[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
36903fea1003f8b2fab27363200000010
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
36903fea1003f8b2fab27364600000011
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
36903fea1003f8b2fab27367400000012
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
36903fea1003f8b2fab27be9300000013
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
36903fea1003f8b2fab27beac00000014
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
36903fea1003f8b2fab27bed800000015
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
36903fea1003f8b2fab28923c00000016
```
#99-oracle-asmdevices.rules
```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sdb", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36903fea1003f8b2fab27363200000010", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdc", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36903fea1003f8b2fab27364600000011", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdd", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36903fea1003f8b2fab27367400000012", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sde", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36903fea1003f8b2fab27be9300000013", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdf", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36903fea1003f8b2fab27beac00000014", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdg", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36903fea1003f8b2fab27bed800000015", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdh", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="36903fea1003f8b2fab28923c00000016", OWNER="grid",GROUP="asmadmin", MODE="0660"
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
brw-rw----  1 grid asmadmin   8,  16 Dec 30 17:09 sdb
brw-rw----  1 grid asmadmin   8,  32 Dec 30 17:09 sdc
brw-rw----  1 grid asmadmin   8,  48 Dec 30 17:09 sdd
brw-rw----  1 grid asmadmin   8,  64 Dec 30 17:09 sde
brw-rw----  1 grid asmadmin   8,  80 Dec 30 17:09 sdf
brw-rw----  1 grid asmadmin   8,  96 Dec 30 17:09 sdg
brw-rw----  1 grid asmadmin   8, 112 Dec 30 17:09 sdh

```
#知识补充：/usr/lib/systemd/system/systemd-udev-trigger.service
```
[root@oracle01 ~]# cat /usr/lib/systemd/system/systemd-udev-trigger.service
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

[root@oracle01 ~]# cat /usr/lib/systemd/system/systemd-udevd.service
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
[root@oracle01 ~]# sfdisk -s
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

[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdb
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
26f1134c7f5aeac0d6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2b38e62246b6fc4fb6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2cdc2ff0f5bc698456c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2fc7ffd18baba312e6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
2f8505ff366f3732a6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
211e8f142da86728d6c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdae
2c95d9e2bbe0ff5906c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaf
2e25b665dc06369916c9ce900b6fab6bc
[root@oracle01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdag
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

#以下只在oracle01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

#第一遍输入时需要输入yes
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

#在oracle02执行
#第一遍输入时需要输入yes
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date
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

#注意过程中第一次时可能需要输入yes
ssh oracle02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

#注意过程中第一次时可能需要输入yes
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

#在oracle02上执行
#注意过程中第一次需要输入yes
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date
```

### 2.11. 安装vnc

#服务器远程操作，安装vnc，便于图形安装

#### 2.11.1.安装图形化组件并重启
```bash
yum grouplist
yum groupinstall -y "Server with GUI"

reboot
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
  oracle02[192.168.122.1]         oracle01[192.168.122.1]         yes             
Result: Node connectivity passed for subnet "192.168.122.0" with node(s) oracle02,oracle01


Check: TCP connectivity of subnet "192.168.122.0"
  Source                          Destination                     Connected?      
  ------------------------------  ------------------------------  ----------------
  oracle01:192.168.122.1          oracle02:192.168.122.1          failed          

ERROR: 
PRVF-7617 : Node connectivity between "oracle01 : 192.168.122.1" and "oracle02 : 192.168.122.1" failed
Result: TCP connectivity check failed for subnet "192.168.122.0"
```
#关闭并
```bash
brctl show

ifconfig virbr0 down
brctl delbr virbr0

systemctl disable libvirtd.service 
```
#### 2.11.2.安装vnc
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
[root@oracle01 ~]# yum grouplist
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
[root@oracle01 ~]#yum groupinstall -y "Server with GUI"

[root@oracle01 ~]# ps -ef|grep vnc
grid      2998     1  0 14:23 pts/0    00:00:00 /bin/Xvnc :1 -auth /home/grid/.Xauthority -desktop oracle01:1 (grid) -fp catalogue:/etc/X11/fontpath.d -geometry 1024x768 -httpd /usr/share/vnc/classes -pn -rfbauth /home/grid/.vnc/passwd -rfbport 5901 -rfbwait 30000
grid      3017     1  0 14:23 pts/0    00:00:00 /bin/sh /home/grid/.vnc/xstartup
root      4508  2099  0 14:26 pts/0    00:00:00 grep --color=auto vnc

[grid@oracle01 ~]$ vncserver -list

TigerVNC server sessions:

X DISPLAY #	PROCESS ID
:1		14370
```

## 3 开始安装 GI

### 3.1. 上传oracle rac软件安装包并解压缩

#将软件包上传至oracle01的/u01/Storage目录下
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
#oracle01下执行
su - grid

cd /u01/Storage/grid/rpm
cp cvuqdisk-1.0.9-1.rpm /u01

scp cvuqdisk-1.0.9-1.rpm oracle02:/u01

#oracle01/oracle02都要执行
su - root

cd /u01
rpm -ivh cvuqdisk-1.0.9-1.rpm
```
#安装前检查，只在oracle01上执行
```bash
su - grid

cd /u01/Storage/grid/
./runcluvfy.sh stage -pre crsinst -n oracle01,oracle02 -fixup -verbose|tee -a pre.log
```
#会生成fixup脚本，需在oracle01/oracle02上执行
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
--->add:oracle02/oracle02-vip,SSHconnectivity,test
--->en03:10.119.5.0:Public,eno4:192.168.5.0:Private,bond0:10.119.5.0:Do Not Use
--->oracle ASM
DiskGroupName:OCR,normal,AUSize:1M,Candidate Disks:sdb/sdc/sdd--->
--->use same passwords for these accounts:Ora543Cle---Do Not Use IPMI
--->asmadmin/asmdba/asmoper
--->Oracle Base:/u01/app/grid,Oracle Home:/u01/app/11.2.0/grid
--->Inventory Directory:/u01/app/oraInventory
--->缺少pdksh,可以忽略
--->install
--->/u01/app/oraInventory/orainstRoot.sh,/u01/app/11.2.0/grid/root.sh，必须先在oracle01上执行完毕这两个脚本，再在oracle02上执行，出现错误时见下面的错误处理步骤，如果弹框看不到内容，可以用鼠标拖动
---->INS-20802，忽略，如果弹框看不到内容，也无法用鼠标拖动，可以按4次Tab键后回车即可
---->INS-32091，忽略，如果弹框看不到内容，也无法用鼠标拖动，可以按4次Tab键后回车即可
---->close
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
##### 3.4.2.执行root.sh报错ohasd failed to start
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
##### 3.4.3.asm及crsd报错CRS-4535: Cannot communicate with Cluster Ready Services
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
##### 3.4.4.添加listener
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
### 3.5. 查看状态

```bash
crsctl status resource -t

```

```
[grid@oracle01 ~]$  crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       oracle01                                     
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
      1        ONLINE  ONLINE       oracle01                                     
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle02                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01                                     

[grid@oracle01 grid]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
```
## 4 创建ASM磁盘组：DATA/FRA

#grid用户图形界面下
```bash
asmca
```
```
 --->create
 --->DATA,external,sde/sdf/sdg,OK，如果弹框看不到磁盘选择项，可以用鼠标拖动
 --->creat
 --->FRA,external,sdh,OK，如果弹框看不到磁盘选择项，可以用鼠标拖动
 --->exit
```
#验证
```
[grid@oracle01 ~]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   3145728  3145602                0         3145602              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576    512000   511901                0          511901              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
ASMCMD> lsdsk
Path
/dev/sdb
/dev/sdc
/dev/sdd
/dev/sde
/dev/sdf
/dev/sdg
/dev/sdh
ASMCMD> 
[grid@oracle01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02    
ora.DATA.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.FRA.dg
               ONLINE  ONLINE       oracle01                                     
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
  ./runcluvfy.sh stage -pre dbinst -n oracle01,oracle02 -fixup -verbose
```
#如果下面报错内容，可以忽略
```
Check: Package existence for "pdksh"
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  oracle02       missing                   pdksh-5.2.14              failed
  oracle01       missing                   pdksh-5.2.14              failed
Result: Package existence check failed for "pdksh"


ERROR:
PRVG-1101 : SCAN name "rac-scan" failed to resolve
  SCAN Name     IP Address                Status                    Comment
  ------------  ------------------------  ------------------------  ----------
  rac-scan      10.119.5.64              failed                    NIS Entry

ERROR:
PRVF-4657 : Name resolution setup check for "rac-scan" (IP address: 10.119.5.64) failed

ERROR:
PRVF-4664 : Found inconsistent name resolution entries for SCAN name "rac-scan"

Verification of SCAN VIP and Listener setup failed

```
#通过vnc以 Oracle 用户登录图形化界面安装 Oracle 数据库软件
```
#根据前面vnc的配置，连接地址
oracle01IP:2
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
--->/u01/app/oracle/product/11.2.0/db_1/root.sh，分别在oracle01/oracle02上用root账户运行，如果弹框看不到内容，可以用鼠标拖动
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
[root@oracle01 ~]# /u01/app/oracle/product/11.2.0/db_1/root.sh
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

[root@oracle02 ohasd]# /u01/app/oracle/product/11.2.0/db_1/root.sh
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
--->Specify FRA: +FRA/500000M(大小根据实际情况填写)/Enable Arechiving
--->Sample Schemas，可以去掉打勾
--->Memory: Custom---SGA:115000M/PGA:38000M(大小根据实际设置memory*60%左右)
    --->Sizing: Processes---1500(根据服务器资源调整)
    --->CharacterSets: Use Unicode(AL32UTF8)
    --->Connection Mode: Dedicated Server Mode
--->可以修改Redo Log Groups，再添加两组，并调整大小为200M
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
	 1 ONLINE  +FRA/xydb/onlinelog/group_1.257.1093116751
	 1 ONLINE  +DATA/xydb/onlinelog/group_1.261.1093116751
	 2 ONLINE  +DATA/xydb/onlinelog/group_2.262.1093116751
	 2 ONLINE  +FRA/xydb/onlinelog/group_2.258.1093116751
	 3 ONLINE  +DATA/xydb/onlinelog/group_3.266.1093116853
	 3 ONLINE  +FRA/xydb/onlinelog/group_3.260.1093116853
	 4 ONLINE  +DATA/xydb/onlinelog/group_4.267.1093116853
	 4 ONLINE  +FRA/xydb/onlinelog/group_4.261.1093116853
	 5 ONLINE  +DATA/xydb/onlinelog/group_5.263.1093116753
	 5 ONLINE  +FRA/xydb/onlinelog/group_5.259.1093116753
	 6 ONLINE  +FRA/xydb/onlinelog/group_6.262.1093116853
	 6 ONLINE  +DATA/xydb/onlinelog/group_6.268.1093116853

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
SYSAUX			       +DATA/xydb/datafile/sysaux.257.1093116677		 540
SYSTEM			       +DATA/xydb/datafile/system.256.1093116677		 740
UNDOTBS1		       +DATA/xydb/datafile/undotbs1.258.1093116677		  95
UNDOTBS2		       +DATA/xydb/datafile/undotbs2.265.1093116795		  25
USERS			       +DATA/xydb/datafile/users.259.1093116677 		   5
```
### 7.3.查看集群状态

#oracle01服务器执行
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
sqlplus test/test@10.119.5.64:1521/xydb
```
#日志
```
[root@oracle01 ~]# su - grid
Last login: Wed Dec 22 18:49:00 CST 2021 on pts/1
[grid@oracle01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.FRA.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.LISTENER.lsnr
               ONLINE  ONLINE       oracle01                                     
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
      1        ONLINE  ONLINE       oracle01                                     
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle02                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.xydb.db
      1        ONLINE  ONLINE       oracle01                 Open                
      2        ONLINE  ONLINE       oracle02                 Open    
[grid@oracle01 ~]$ srvctl status asm
ASM is running on oracle01,oracle02
[grid@oracle01 ~]$ asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576   3145728  3142816                0         3142816              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576    512000   510286                0          510286              0             N  FRA/
MOUNTED  NORMAL  N         512   4096  1048576    307200   306274           102400          101937              0             Y  OCR/
ASMCMD> 

[grid@oracle01 ~]$ srvctl status database -d xydb
Instance xydb1 is running on node oracle01
Instance xydb2 is running on node oracle02

[grid@oracle01 ~]$ lsnrctl status

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
Listener Log File         /u01/app/11.2.0/grid/log/diag/tnslsnr/oracle01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=10.119.5.60)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=10.119.5.62)(PORT=1521)))
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

dmpfilename=full_db$time.dmp
logfilename=full_db$time.log

echo start expdp $dmpfilename ... >> $expdp_dir/expdprun.log

expdp system/Z8jAmy3Tec92 directory=expdir dumpfile=$dmpfilename logfile=$logfilename full=y  parallel=4 cluster=N

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