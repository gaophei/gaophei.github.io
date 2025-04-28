KES RAC，这里就不多介绍了，本期就来一个保姆级安装教程。今天正好也是金仓社区换新上线一周年的纪念日，也当做生日礼物送给金仓社区。

## 1 环境说明

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQ5aVrZgucvI8enUYYauBkpDFJkjYNS6tmQ6Tlv1ZrAlgKDjYw1DoPEg/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

## 2 操作系统标准配置

操作系统分为两部分，用于数据库安装的两台使用银河麒麟V10 SP2（Kylin-Server-10-SP2-Release-Build09-20210524-x86_64），用于存储的使用RHEL 8.10。

### 2.1 关闭防火墙

```
systemctl stop firewalld.service 
systemctl disable firewalld.service
```

### 2.2 关闭SELinux

```
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
setenforce 0
[reboot]
```

### 2.3 配置hosts文件

```
cat >>/etc/hosts<<EOF
10.10.10.151 kesrac01
10.10.10.152 kesrac02
20.20.20.151 kesrac01-priv
20.20.20.152 kesrac02-priv
30.30.30.151 kesrac01-st
30.30.30.152 kexrac02-st
30.30.30.150 kesrac-storage
EOF
```

### 2.4 时间同步配置

在生产环境中可以使用NTP或chrony实现时间同步。
本次由于使用公网时间同步，相关配置省略。

## 3存储配置

本次不使用openfiler而是在操作系统直接配置iscsi实现。

### 3.1 配置本地yum源

```
mkdir /iso
mount -r /dev/sr0 /iso
rm -rf /etc/yum.repo.d/*

cat > /etc/yum.repos.d/iso.repo <<EOF
[AppStream]
name=AppStream
baseurl=file:///iso/AppStream
gpgcheck=0
enabled=1
 
[BaseOS]
name=BaseOS
baseurl=file:///iso/BaseOS
gpgcheck=0
enabled=1
EOF
```

### 3.2 安装targetcli

```
dnf -y install targetcli
```

### 3.3 配置磁盘

本机挂载了4块30GB的磁盘做软raid5作为数据盘，4块1G的磁盘做raid5做投票盘。
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQGIcDZzwyVibFmHyMoibTtTgZqlQUwbLpCNonHGv308fbibeW2ZKcBWVag/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

```
mdadm --create /dev/md1 --level=5 --raid-devices=3 --spare-device=1 /dev/nvme0n2 /dev/nvme0n3 /dev/nvme0n4 /dev/nvme0n5
mdadm --create /dev/md2 --level=5 --raid-devices=3 --spare-device=1 /dev/nvme0n6 /dev/nvme0n7 /dev/nvme0n8 /dev/nvme0n9
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQqd82ibrwKFhst7eWwIFDF6zfqkApPOyyu8Kz5icQVt9GJRmtaNIXIMiaA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQBzibvo9WAj1mRgj4zMuYcUGOibKbiaYpIfuHPTeU2NRGI35XssQFu85eA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 3.5 配置iscsi

```
targetcli #进入iscsi配置命令行

# 创建映射磁盘
cd /backstores/block

create data /dev/md1
create vote /dev/md2
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQQiaxQEDe8dEpjPtRHHHQYoYzjKvJNIzfks4icZzxTozbN0uKicgjSj8iag/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

```
# 创建iqn标签
cd /iscsi
create iqn.2025-03.com.iscsi.www:server
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQSzUPtJfQd5yRqRQ7Pycxp50Z1NP6cSbLUmEo65ibzIaVG0icDMJ6Z86w/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

```
# 创建acl
cd iqn.2025-03.com.iscsi.www:server/tpg1/acls
create iqn.2025-03.com.iscsi.www:client
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQYvV5mVia02tNlTKIg13BpkMVRqohIBvm6tYiaHc7ricCFRhMZEa3tVibew/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

```
# 创建lun
cd /iscsi/iqn.2025-03.com.iscsi.www:server/tpg1/luns
create /backstores/block/data
create /backstores/block/vote
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQjjQMBNmv71Gv62yPWtcaOnxFAPjJ3oy2l1DtqXiapBibfSjamVD0U5GA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

```
# 退出保存配置
exit
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQ6RwNKlXzEJiaD9PUt9VGsZaVFd4awNyZibw4EQOBGpbLktEAMJeVNpzw/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

```
# 修改启动iqn
cat > /etc/iscsi/initiatorname.iscsi <<EOF
InitiatorName=iqn.2025-03.com.iscsi.www:client
EOF

# 启动iscsi并配置开机启动
systemctl restart iscsi
systemctl restart iscsid
systemctl start target.service 
systemctl enable target.service
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQz4EJjv68jRfeOMozL4BYiap6ia8Ln63bcmmXcqD1fibLibRd4CFcVCF3rA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

## 4 数据库节点配置

### 4.1 配置sysctl.conf

```
cat >>/etc/sysctl.conf <<EOF
fs.aio-max-nr= 1048576
fs.file-max= 6815744
kernel.shmall= 2097152
kernel.shmmax= 4294967296
kernel.shmmni= 4096
kernel.sem= 250 32000 100 128
net.ipv4.ip_local_port_range= 9000 65500
net.core.rmem_default= 262144
net.core.rmem_max= 4194304
net.core.wmem_default= 262144
net.core.wmem_max= 1048576
EOF

sysctl -p
```

### 4.2 配置limits.conf

```
cat >>/etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65535
* soft nproc 65536
* hard nproc 65535
* soft core unlimited
* hard core unlimited
EOF
```

### 4.3 创建用户

```
useradd -u 2000 kingbase
echo "KESV9#123" | passwd --stdin kingbase
```

### 4.4 创建软件目录

```
mkdir -p /Kingbase/ES/V9/server
chown -R kingbase:kingbase /Kingbase
```

### 4.5 配置环境变量

```
su - kingbase
cat >>.bash_profile<<EOF
export PATH=/Kingbase/ES/V9/server/Server/bin:\$PATH
EOF
```

### 4.6 挂载磁盘

```
yum -y install open-iscsi
cat > /etc/iscsi/initiatorname.iscsi <<EOF
InitiatorName=iqn.2025-03.com.iscsi.www:client
EOF
systemctl start iscsid

iscsiadm -m discovery -t st -p 30.30.30.150
iscsiadm -m node -T iqn.2025-03.com.iscsi.www:server --login
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQEnZl4Z1iaP4IcMricYTpP3RiaxlM3skmbOasXoDEjC1asZeWOFYibOgT6w/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQczowIeP7ibkq9mAdFKibpyWBh1jXriaZUaNibicQLzw954wGLiaFAKNpDIXA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

> 这里需要说明一点，关于挂载磁盘的软件Kylin V10 SP2还用的是open-iscsi-2.1.1-11这个版本很老，因此在挂载后，对应磁盘的大小会有不同。而RHEL 8.10使用的是iscsi-initiator-utils-6.2.1.4-8，经过实测不会出现相同的问题。

### 4.7 安装KES

可以按照《[KingBaseES V9 on RHEL8](https://mp.weixin.qq.com/s?__biz=Mzg3MTk4MzYyMQ==&mid=2247485442&idx=1&sn=269dfb304eb2977e3522620fbb74d4f7&scene=21#wechat_redirect)》的方式先安装数据库软件。
这里需要说明一点，每个节点的license存放在kingbase用户家目录中，安装过程中指定。

> 本次安装使用的版本为非官网版本，具体版本号为V009R001B04071841。

安装过程中比官网版本会多出以下一个选项页面：
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQqGNymqM3F7xRMK0OjVyWtqibDa72tic231C87eYU8Lv5mjia8E8kuHWJw/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 4.8 生产KES RAC安装文件

使用root用户执行：

```
cd /Kingbase/ES/V9/server/install/script/
./rootDeployClusterware.sh
```

这一操作会在/opt目录下生成对应的文件：
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQdsDXBen4ibehwnCdwnKVBAicakxzSMvVP9GpccrcbIj08GRUEgTJPjjw/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 4.9 配置KES RAC

```
cd /opt/KingbaseHA
vim cluster_manager.conf
```

主要配置内容如下：

```
cluster_name=kcluster
node_name=(kesrac01 kesrac02) #需要与主机名一致
node_ip=(10.10.10.151 10.10.10.152)
enable_qdisk=1
votingdisk=/dev/sdb
sharedata_dir=/sharedata/data_gfs2
sharedata_disk=/dev/sda
install_dir=/opt/KingbaseHA
kingbaseowner=kingbase
kingbasegroup=kingbase
kingbase_install_dir=/kingbase/ES/V9/server/Server
database="test"
username="system"
password="123456"
enable_fence=1
enable_qdisk_fence=1
qdisk_watchdog_dev=/dev/watchdog
qdisk_watchdog_timeout=8
install_rac=1
db_port=54321
rac_lms_port=53444
rac_lms_count=7
heuristics_ping_gateway="10.10.10.2" #需要输入网关
```

> 参数信息详见：https://bbs.kingbase.com.cn/docHtml?recId=d16e9a1be637c8fe4644c2c82fe16444&url=aHR0cHM6Ly9iYnMua2luZ2Jhc2UuY29tLmNuL2tpbmdiYXNlLWRvYy92OS9oaWdobHkvUkFDL2luZGV4Lmh0bWw

```
scp cluster_manager.conf kesrac02:`pwd`
```

### 4.10 磁盘初始化

任一节点执行即可：

```
# 初始化投票盘
./cluster_manager.sh --qdisk_init
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQHJLaV5SDYn0jlQBbiaBDSn8YLSVSpanecmIXliastL1GDp86NE1tYnnA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

```
# 初始化数据盘
./cluster_manager.sh --cluster_disk_init
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQ2aumSiaVUQYGPJKPjlpIIGfZBOiaZGuL29OQ7Olxxyibyr00BSywmcM7g/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 4.11 基础组件初始化

所有节点执行：

```
./cluster_manager.sh --init_gfs2
./cluster_manager.sh --base_configure_init
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQMqUXiaqUumbTxT5yaP7PrqRz6icxjpydcRiaCVICHyau6NPS9Kl70F39A/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQ9tq4yHhoibQPW1nnJVlxicfictG1Wrcy8X6VNwhcYyhJGMWRUJicO56HsA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 4.12 gfs2相关资源初始化

任一节点执行即可：

```
source /root/.bashrc
./cluster_manager.sh --config_gfs2_resource
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQpz8TMvyAlRS4b7NuFkfhia8A9LO48cjLO9vP4Ld9ibO8tMOAM6Hiafoiaw/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 4.13 初始化数据库

任一节点执行即可：

```
./cluster_manager.sh --init_rac
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQEUHMnofPEr5Gkvysj39oAoHvic7Z69FBZ4O1nRc8eRm8ufYnL6Xsc4A/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 4.14 配置数据库资源

```
./cluster_manager.sh --config_rac_resource
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQ0l1SyHxegJtt3iadfMJV9z4zvgAmoc9G9N5cu3umIOy46hqLRukf6cQ/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

### 4.15 检查数据库运行状态

```
su - kingbase
sys_ctl -D /sharedata/kingbase/data status
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQEq56eOoWWG89joelPTsuOzrPFL5bLZWJcGhdbUOlsicibdXYHRFFny7Q/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQSqyJF0ibfREw1NFETg8LYVqc4vNVbbrKHYSib4s2ibye0HZ3kseTX9vyQ/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)

## 5 访问数据库

在之前的文章中也提到了以高可用方式连接KES RAC需要在驱动侧配置所有节点IP，这里就仅访问各节点并简单测试RAC特性：
节点1访问实例：

```
ksql -p 54321 -U system test
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQX5IiczLPCFYpGcBTicMoqziavR5XWEUiaKEM3te15twTD5NFy0GJDbne3A/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
节点2访问实例：

```
ksql -p 54321 -U system test
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQwrrFk9hp2t5IQyHdsTVr5eG3xvGK54sEFPicVXmXPg9mHCicORqEDicVw/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
接下来在节点1创建database、建表、插入语句后再节点2进行查看：

```
create database kesrac;
\c kesrac
create table test (id number,name varchar(20));
insert into test values (1,'kesrac');
commit;
```

![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQrlVBZ43JuzeH66uQmv4FV2jJvsOCSJiaEQHvbOvUOGibxWMBaM3vHmLg/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
节点2查询相关内容：
![image.png](https://mmbiz.qpic.cn/sz_mmbiz_png/Y15LZ0NXz9iaAEgx0SADSkrTnZW3FZWIQribicAo5SLZteO86JW81jOWDOSSGRmstcRDNf2hCibXMAZOAReqEj32mw/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1)
这里可以看到各节点的数据是同步的，达到RAC集群的预期。