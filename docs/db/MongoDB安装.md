# 	MongoDB安装

## Linux下安装

>1、获取MongoDB安装包
>
>​      可以通过两种方式自己下载、网络下载方式、公司安装包下载（建议使用公司这个）
>
>​     公司安装包地址：https://supwisdom.coding.net/s/2293ce33-6268-43b0-bf2e-1c12d03a8de4，查看密码：ryfu

```shell
# 直接下载安装包 官方下载地址：https://www.mongodb.com/download-center/community

# linux 下载
  #x86
  #wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-4.4.1
  
  #arm64
  #wget https://fastdl.mongodb.org/linux/mongodb-linux-aarch64-rhel82-4.4.29.tgz
  
  wget https://fastdl.mongodb.org/linux/mongodb-linux-aarch64-rhel82-4.4.29.tgz
```

> 2、解压安装包

```shell
# 上传或下载都放在/usr 文件夹下
cd /usr
tar -zxvf mongodb-linux-aarch64-rhel82-4.4.29.tgz
# 修改文件夹名称
mv mongodb-linux-aarch64-rhel82-4.4.29 mongodb

```

>3、配置环境变量

```shell
cat >> /etc/profile <<'EOF'
export PATH=/usr/mongodb/bin:$PATH
EOF

source /etc/profile
```

> 4、创建数据库目录

```shell
cd /usr/mongodb
touch mongodb.conf

mkdir db
mkdir log

cd log
touch mongodb.log
```

> 5、修改mongodb配置文件

```shell
cat >> /usr/mongodb/mongodb.conf <<EOF
port=27017 #端口
dbpath= /usr/mongodb/db #数据库存文件存放目录
logpath= /usr/mongodb/log/mongodb.log #日志文件存放路径
logappend=true #使用追加的方式写日志
fork=true #以守护进程的方式运行，创建服务器进程
maxConns=800 #最大同时连接数
noauth=true #不启用验证
journal=true #每次写入会记录一条操作日志（通过journal可以重新构造出写入的数据）。
#即使宕机，启动时wiredtiger会先将数据恢复到最近一次的checkpoint点，然后重放后续的journal日志来恢复。
storageEngine=wiredTiger  #存储引擎有mmapv1、wiretiger、mongorocks
bind_ip = 0.0.0.0  #这样就可外部访问了，例如从win10中去连虚拟机中的MongoDB
EOF
```

> 6、设置文件夹权限

```shell
chmod -R 777 db
chmod -R 777 log
```

> 7、启动mongodb

```shell
# 启动MongoDB
./bin/mongod --config mongodb.conf
cd bin
# 进入MongoDB
./mongo
```



```shell
# 数据资产在进入MongoDB后的操作
# 查询所有数据库列表
show dbs;
# 切换数据库
use dataassets;
# 查询数据库下所有用户
show users;

db.createUser(
 {
  user : "dataassets",
  pwd : "dataassets",
  roles: [ { role : "readWrite", db : "dataassets" } ]
 }
)

 
 # 切换数据库
use swop;
# 查询数据库下所有用户
show users;

db.createUser(
 {
  user : "swop",
  pwd : "swop",
  roles: [ { role : "readWrite", db : "swop" } ]
 }
 )
 
 # 切换数据库
use dataquality;
# 查询数据库下所有用户
show users;

db.createUser(
 {
  user : "dataquality",
  pwd : "dataquality",
  roles: [ { role : "readWrite", db : "dataquality" } ]
 }
 )
```
## linux下配置auth

> 1、创建管理员账号

```shell
#登录mongodb服务器进入mongodb
#切换进入admin库
use admin;
#创建超级管理员权限
db.createUser({user: "admin",pwd: "Supwisdom!@#",roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]})
```

> 2、关闭mongodb数据库

```shell
#安全关闭mongodb数据库
#切换到admin库 
use admin
#关闭服务 
db.shutdownServer()
```

> 3、修改配置文件

```shell
#修改配置文件/usr/mongodb/mongodb.conf
把noauth=true改成auth=true
```

> 4、启动mongodb数据库

```shell
#启动mongodb数据库
mongod --config /usr/mongodb/mongodb.conf

#验证
mongo
#切换到admin
use admin
#登录 返回1  说明登录成功
db.auth('admin','Supwisdom!@#');

#查看所有用户
db.system.users.find().pretty();
```

## linux（centos7）下配置开机启动

> 1、创建并编辑mongodb.service文件

```shell
cat >> /lib/systemd/system/mongodb.service <<'EOF'
[Unit]
 
Description=mongodb
 
After=network.target remote-fs.target nss-lookup.target
 
[Service]
 
Type=forking
 
ExecStart=/usr/mongodb/bin/mongod --config /usr/mongodb/mongodb.conf
 
ExecReload=/bin/kill -s HUP $MAINPID
 
ExecStop=/usr/mongodb/bin/mongod --shutdown --config /usr/mongodb/mongodb.conf
 
PrivateTmp=true

[Install]
 
WantedBy=multi-user.target
EOF
```

> 2、操作命令

```shell
#先关闭mongo
ps -ef|grep mongod|awk '{print $2}' |xargs kill -9

systemctl daemon-reload
#启动服务
systemctl start mongodb.service
#开机启动
systemctl enable mongodb.service
#关闭服务
systemctl stop mongodb.service
#查看状态
systemctl status mongodb.service
```



