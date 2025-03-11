**ES cluster 8.x for Centos7.9 安装手册**

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

#本地深信服超融合环境，三台oracle linux部署ES集群

```
k8s-mysql-ole: 172.18.13.112
k8s-mysql-ole-117: 172.18.13.117
k8s-mysql-ole-test: 172.18.13.120
```

#分区---120G

```
/boot   1G
swap    32G
/       其余容量  
```

### 1.1. 系统版本

```
[root@k8s-mysql-ole ~]# cat /etc/os-release |grep PRETTY
PRETTY_NAME="Oracle Linux Server 7.9"

[root@k8s-mysql-ole ~]# uname -r
5.4.17-2102.201.3.el7uek.x86_64
```



### 1.2. 操作系统配置部分


### 1.3.多路径配置情况---无
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

### 1.4.第三台虚拟机(k8s-mysql-ole-test)搭建iscsi共享存储
#### 1.4.1.添加共享磁盘

#添加硬盘，创建方式：新磁盘，分配方式：预分配(类似于vsphere的厚置备，置零)

![image-20231117111420348](oracle-store\image-20231117111420348.png)

![image-20231117112712657](oracle-store\image-20231117112712657.png)





#### 1.4.2.配置iscsi

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
[root@k8s-mysql-ole-test ~]# tgt-admin -dump
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


[root@k8s-mysql-ole-test ~]# tgtadm --lld iscsi --mode target --op show
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

[root@k8s-mysql-ole-test ~]# tgtadm -L iscsi -o show -m target
Target 1: iqn.2023-11.com.oracle:rac
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
        I_T nexus: 2
            Initiator: iqn.2023-11.com.oracle:rac alias: k8s-mysql-ole
            Connection: 0
                IP Address: 172.18.13.112
        I_T nexus: 15
            Initiator: iqn.2023-11.com.oracle:rac alias: k8s-mysql-ole-117
            Connection: 0
                IP Address: 172.18.13.117
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
        
[root@k8s-mysql-ole-test ~]# netstat -anp|grep tgt
netstat: showing only processes with your user ID
tcp        0      0 0.0.0.0:3260            0.0.0.0:*               LISTEN      25468/tgtd
tcp        0      0 172.18.13.104:3260      172.18.13.117:64708      ESTABLISHED 25468/tgtd
tcp        0      0 172.18.13.104:3260      172.18.13.112:33274      ESTABLISHED 25468/tgtd
tcp        0      0 :::3260                 :::*                    LISTEN      25468/tgtd
        
```


### 1.5. 配置 iscsi 客户端（所有rac节点）

#### 1.5.1.配置共享磁盘

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
[root@k8s-mysql-ole ~]# lsblk
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

[root@k8s-mysql-ole-117 ~]# lsblk
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


[root@k8s-mysql-ole-117 iscsi]#  iscsiadm -m session -R
Rescanning session [sid: 2, target: iqn.2023-11.com.oracle:rac, portal: 172.18.13.104,3260]
[root@k8s-mysql-ole-117 iscsi]# lsscsi 
[1:0:0:0]    cd/dvd  SANGFOR  DVD-ROM          2.5+  /dev/sr0 
[2:0:0:0]    storage IET      Controller       0001  -        
[2:0:0:1]    disk    IET      VIRTUAL-DISK     0001  /dev/sda 
[2:0:0:2]    disk    IET      VIRTUAL-DISK     0001  /dev/sdb 
[2:0:0:3]    disk    IET      VIRTUAL-DISK     0001  /dev/sdc 
[2:0:0:4]    disk    IET      VIRTUAL-DISK     0001  /dev/sdd 
[2:0:0:5]    disk    IET      VIRTUAL-DISK     0001  /dev/sde 
[2:0:0:6]    disk    IET      VIRTUAL-DISK     0001  /dev/sdf 
[2:0:0:7]    disk    IET      VIRTUAL-DISK     0001  /dev/sdg 


[root@k8s-mysql-ole-117 iscsi]# ll  /dev/disk/by-path
total 0
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-1 -> ../../sda
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-2 -> ../../sdb
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-3 -> ../../sdc
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-4 -> ../../sdd
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-5 -> ../../sde
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-6 -> ../../sdf
lrwxrwxrwx 1 root root  9 Nov 22 10:19 ip-172.18.13.104:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-7 -> ../../sdg
lrwxrwxrwx 1 root root  9 Nov 21 19:00 pci-0000:00:01.1-ata-2.0 -> ../../sr0

[root@k8s-mysql-ole-117 iscsi]# tree /var/lib/iscsi/
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
[root@k8s-mysql-ole-117 iscsi]# 

[root@k8s-mysql-ole-117 iscsi]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
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
[root@k8s-mysql-ole-117 iscsi]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
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
[root@k8s-mysql-ole ~]# systemctl status iscsi
● iscsi.service - Login and scanning of iSCSI devices
   Loaded: loaded (/usr/lib/systemd/system/iscsi.service; enabled; vendor preset: disabled)
   Active: inactive (dead)
     Docs: man:iscsiadm(8)
           man:iscsid(8)
#重启后
[root@k8s-mysql-ole ~]# systemctl restart iscsi
[root@k8s-mysql-ole ~]# systemctl status iscsi
● iscsi.service - Login and scanning of iSCSI devices
   Loaded: loaded (/usr/lib/systemd/system/iscsi.service; enabled; vendor preset: disabled)
   Active: inactive (dead)
Condition: start condition failed at Wed 2023-11-22 10:12:27 CST; 1s ago
           ConditionDirectoryNotEmpty=/var/lib/iscsi/nodes was not met
     Docs: man:iscsiadm(8)
           man:iscsid(8)

#配置完跟
```



#### 1.5.2.后续如果出现共享磁盘的uuid乱了时，可以退出并重新扫描、登录

```bash
ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

# /u01/app/19.0.0/grid/bin/crsctl stop cluster -f

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



#有时候oracle-store会报错tgtd.service，需要iscsi服务器端先重启tgtd和target，然后rac01/rac02做上面的配置

```
Apr 18 21:00:32 k8s-mysql-ole-test tgtd: tgtd: conn_close(140) Forcing release of tx task 0x20aeea0 10000054 1
Apr 18 21:00:37 k8s-mysql-ole-test kernel: tgtd[25468]: segfault at 0 ip 000000000040b25a sp 00007ffca4e858f0 error 6 in tgtd[400000+4b000]
Apr 18 21:00:37 k8s-mysql-ole-test kernel: Code: 48 83 ec 08 48 8b 42 98 83 38 0a 74 43 48 8b 88 28 02 00 00 48 8d 72 b0 48 05 20 02 00 00 48 89 70 08 48 89 42 b0 48 89 4a b8 <48> 89 31 be 05 00 00 00 48 8b 7a 98 48 8b 87 68 02 00 00 ff 90 90
Apr 18 21:00:41 k8s-mysql-ole-test systemd: tgtd.service: main process exited, code=killed, status=11/SEGV
Apr 18 21:00:41 k8s-mysql-ole-test systemd: Unit tgtd.service entered failed state.
Apr 18 21:00:41 k8s-mysql-ole-test systemd: tgtd.service failed.
```

```bash
systemctl restart tgtd.service

systemctl restart target.service

systemctl enable tgtd

tgt-admin -dump

tgtadm --lld iscsi --mode target --op show

netstat -anp|grep tgt
```





#ocrcheck -local报错处理

```bash
#如果ocrcheck -local报错，那么可以restore
[root@k8s-mysql-ole-117 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
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

[root@k8s-mysql-ole-117 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83408
	 Available space (kbytes) :     408276
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-mysql-ole-117/olr/k8s-mysql-ole-117_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed



[root@k8s-mysql-ole-117 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-mysql-ole-117     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-mysql-ole-117/olr/autobackup_20231118_184948.olr     724960844

k8s-mysql-ole-117     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-mysql-ole-117/olr/backup_20231118_183548.olr     724960844     
[root@k8s-mysql-ole-117 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-mysql-ole-117/olr/autobackup_20231118_184948.olr
[root@k8s-mysql-ole-117 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-mysql-ole-117     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-mysql-ole-117/olr/backup_20231118_183548.olr     724960844     

[root@k8s-mysql-ole-117 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-mysql-ole-117/olr/k8s-mysql-ole-117_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded



[root@k8s-mysql-ole-117 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-mysql-ole-117 ~]# 
```



## 2.准备工作（ES节点同时配置）

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
### 2.2. 关闭防火墙和selinux

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

### 2.3. 创建用户

#创建用户组及用户前，检查下gid和uid是否已经占用

```bash
cat /etc/group

cd /home

id elasticsearch
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
hostnamectl set-hostname k8s-mysql-ole
#rac02
hostnamectl set-hostname k8s-mysql-ole-117

cat >> /etc/hosts <<EOF
#public ip 
172.18.13.112 k8s-mysql-ole
172.18.13.117 k8s-mysql-ole-117
#vip
172.18.13.99  k8s-mysql-ole-vip
172.18.13.100 k8s-mysql-ole-117-vip
#private ip
10.100.100.97 k8s-mysql-ole-prv
10.100.100.98 k8s-mysql-ole-117-prv
#scan ip
172.18.13.101 rac-scan
EOF
```
#检查下网络是否顺畅

```bash
ping k8s-mysql-ole -c 1

ping k8s-mysql-ole-117 -c 1

ping k8s-mysql-ole-vip -c 1

ping k8s-mysql-ole-117-vip -c 1

ping k8s-mysql-ole-prv -c 1

ping k8s-mysql-ole-117-prv -c 1

```



### 2.5. 禁用swap分区

#临时关闭

```bash
swapoff -a
```
#永久关闭

```bash
sed -i '/swap/s/^/#/' /etc/fstab
```

#确认

```bash
free -m

cat /etc/fstab
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
#[ -d /sys/firmware/efi ] && echo "UEFI" || echo "BIOS"

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
[root@k8s-mysql-ole ~]# grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
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
[root@k8s-mysql-ole ~]# sfdisk -s
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
[root@k8s-mysql-ole ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007

[root@k8s-mysql-ole-117 ~]# sfdisk -s
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
[root@k8s-mysql-ole-117 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
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
[root@k8s-mysql-ole ~]# sfdisk -s
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
[root@k8s-mysql-ole ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
[root@k8s-mysql-ole ~]#


[root@k8s-mysql-ole-117 ~]# sfdisk -s
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
[root@k8s-mysql-ole-117 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
[root@k8s-mysql-ole-117 ~]#

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
[root@k8s-mysql-ole ~]# ll /dev|grep asm
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

/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh -user grid  -hosts "k8s-mysql-ole k8s-mysql-ole-117" -advanced exverify -confirm

/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh -user grid  -hosts "k8s-mysql-ole k8s-mysql-ole-117" -advanced exverify -confirm

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

#以下只在k8s-mysql-ole执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh k8s-mysql-ole-117 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh k8s-mysql-ole-117 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-mysql-ole-117:~/.ssh/authorized_keys

ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh  k8s-mysql-ole date -Ins;ssh  k8s-mysql-ole-117 date -Ins;ssh  k8s-mysql-ole-prv date -Ins;ssh  k8s-mysql-ole-117-prv date -Ins

#在k8s-mysql-ole-117执行
ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh  k8s-mysql-ole date -Ins;ssh  k8s-mysql-ole-117 date -Ins;ssh  k8s-mysql-ole-prv date -Ins;ssh  k8s-mysql-ole-117-prv date -Ins
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在k8s-mysql-ole执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh k8s-mysql-ole-117 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh k8s-mysql-ole-117 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-mysql-ole-117:~/.ssh/authorized_keys

ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh  k8s-mysql-ole date -Ins;ssh  k8s-mysql-ole-117 date -Ins;ssh  k8s-mysql-ole-prv date -Ins;ssh  k8s-mysql-ole-117-prv date -Ins

#在k8s-mysql-ole-117上执行
ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh k8s-mysql-ole date;ssh k8s-mysql-ole-117 date;ssh k8s-mysql-ole-prv date;ssh k8s-mysql-ole-117-prv date

ssh  k8s-mysql-ole date -Ins;ssh  k8s-mysql-ole-117 date -Ins;ssh  k8s-mysql-ole-prv date -Ins;ssh  k8s-mysql-ole-117-prv date -Ins
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

## 3 开始安装 ES

### 3.1. 下载软件包
```bash
#官网

#根据服务器OS不同，下载相关压缩包，此处为linux X86_64
mkdir /root/es
cd /root/es

wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.13.3-linux-x86_64.tar.gz
```
### 3.2. 解压 grid 安装包

