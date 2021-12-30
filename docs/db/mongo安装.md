##先关闭防火墙，优化OS，再安装mongo

#### 关闭防火墙：

```bash
systemctl stop firewalld
systemctl disable firewalld

 sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
 setenforce 0
 
 systemctl status firewalld
 getenforce
```

#### 优化操作系统

[root@jcpt-mongodbtest ~]# cat /etc/security/limits.conf 

```bash
*            soft    nofile          65536
*            hard    nofile          200000
*            soft    core            unlimited
*            hard    core            unlimited
*            soft    sigpending      90000
*            hard    sigpending      90000
*            soft    nproc           90000
*            hard    nproc           90000
```

[root@jcpt-mongodbtest ~]# cat /etc/security/limits.d/20-nproc.conf 

```bash
*          soft    nproc     90000
root       soft    nproc     unlimited
```

#### 下载安装mongodb
(1)下载并解压

```bash
cd /data
wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-4.4.6.tgz
tar -zxvf mongodb-linux-x86_64-rhel70-4.4.6.tgz
mv mongodb-linux-x86_64-rhel70-4.4.6 mongodb
```

(2)创建所需文件夹和文件

```bash
cd /data/mongodb
mkdir db
mkdir log

#配置文件
touch /data/mongodb/mongodb.conf

echo "
port=27017
dbpath= /data/mongodb/db
logpath= /data/mongodb/log/mongodb.log
logappend=true
fork=true
maxConns=2000
#noauth=true
journal=true
storageEngine=wiredTiger
bind_ip = 0.0.0.0" >> mongodb.conf

cd log
touch mongodb.log

chmod -R 777 db
chmod -R 777 log

echo "
export PATH=/data/mongodb/bin:$PATH" >> /etc/profile

source /etc/profile
```

(3)启动mongo

```bash
cd ~
mongod -f /data/mongodb/mongodb.conf
```

(4)进入mongo进行操作

```bash
mongo
```

创建库和用户

```mongo
use dataassets;
db.createUser({user:"dataassets",pwd:"Xyz123",roles:["dbOwner"]});
```

(5)访问方式

```bash
mongo mongodb://dataassets:Xyz123@192.168.0.10:27017/dataassets
```

