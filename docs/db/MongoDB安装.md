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



## mongo tools
#官网
#https://www.mongodb.com/try/download/database-tools/releases/archive

#查找rhel82-aarch64

```bash
wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-rhel82-aarch64-100.9.4.tgz
```

#解压缩

```bash
tar -zxvf mongodb-database-tools-rhel82-aarch64-100.9.4.tgz

cp mongodb-database-tools-rhel82-aarch64-100.9.4/bin/* /usr/mongodb/bin/
```

### 备份

#备份报错

```bash
# mongodump -h 192.168.106.53 -u admin -p 'Supwisdom!@#' --authenticationDatabase admin --gzip -d "swopErrorData" -o /data/mongo/$(date +%Y%m%d)
2024-05-27T20:36:43.166+0800    Failed: error creating intents to dump: error getting collections for database `swopErrorData`: (Unauthorized) not authorized on swopErrorData to execute command { listCollections: 1, filter: {}, cursor: {}, lsid: { id: UUID("3db0ac0f-6cc8-45fe-99a7-e61e9ea168bf") }, $db: "swopErrorData" }


#官网关于role的介绍
#https://www.mongodb.com/docs/v4.4/reference/built-in-roles/#mongodb-authrole-backup

#此处可以赋予admin用户backup权限，或者readWriteAnyDatabase权限

# mongo -u admin -p 'Supwisdom!@#' --authenticationDatabase admin
MongoDB shell version v4.4.29
connecting to: mongodb://127.0.0.1:27017/?authSource=admin&compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("2d343ad6-97a6-4cce-8ee1-8393d38a4ad2") }
MongoDB server version: 4.4.29
> use admin;
switched to db admin

> db.grantRolesToUser("admin",[{role: "backup", db: "admin"}]);
> db.getUser("admin");
{
        "_id" : "admin.admin",
        "userId" : UUID("17f407eb-4586-4c84-9cdd-df1d65bee783"),
        "user" : "admin",
        "db" : "admin",
        "roles" : [
                {
                        "role" : "backup",
                        "db" : "admin"
                },
                {
                        "role" : "userAdminAnyDatabase",
                        "db" : "admin"
                }
        ],
        "mechanisms" : [
                "SCRAM-SHA-1",
                "SCRAM-SHA-256"
        ]
}
> exit
bye

#再次备份测试
# mongodump -h 192.168.106.53 -u admin -p 'Supwisdom!@#' --authenticationDatabase admin --gzip -d "swopErrorData" -o /data/mongo/$(date +%Y%m%d)
2024-05-27T21:57:39.637+0800    writing swopErrorData.swopWorkErrorLog to /data/mongo/20240527/swopErrorData/swopWorkErrorLog.bson.gz
2024-05-27T21:57:39.638+0800    writing swopErrorData.SWOP_TRANS_LOG to /data/mongo/20240527/swopErrorData/SWOP_TRANS_LOG.bson.gz
2024-05-27T21:57:39.638+0800    writing swopErrorData.SWOP_JOB_LOG to /data/mongo/20240527/swopErrorData/SWOP_JOB_LOG.bson.gz
2024-05-27T21:57:39.641+0800    done dumping swopErrorData.SWOP_JOB_LOG (0 documents)
2024-05-27T21:57:39.642+0800    writing swopErrorData.swopErrorData to /data/mongo/20240527/swopErrorData/swopErrorData.bson.gz
2024-05-27T21:57:39.643+0800    done dumping swopErrorData.SWOP_TRANS_LOG (4 documents)
2024-05-27T21:57:39.643+0800    writing swopErrorData.swopWorkLog to /data/mongo/20240527/swopErrorData/swopWorkLog.bson.gz
2024-05-27T21:57:39.645+0800    done dumping swopErrorData.swopWorkErrorLog (5 documents)
2024-05-27T21:57:39.645+0800    done dumping swopErrorData.swopErrorData (0 documents)
2024-05-27T21:57:39.662+0800    done dumping swopErrorData.swopWorkLog (556 documents)

# cd /data/mongo/
# ll
total 4
drwxr-xr-x 3 root root 4096 May 27 21:57 20240527

# cd 20240527/
# ls
swopErrorData

# cd swopErrorData/
# ls
swopErrorData.bson.gz           SWOP_TRANS_LOG.bson.gz             swopWorkLog.bson.gz
swopErrorData.metadata.json.gz  SWOP_TRANS_LOG.metadata.json.gz    swopWorkLog.metadata.json.gz
SWOP_JOB_LOG.bson.gz            swopWorkErrorLog.bson.gz
SWOP_JOB_LOG.metadata.json.gz   swopWorkErrorLog.metadata.json.gz


#测试正常，后面可以使用如下命令
mongodump -h 192.168.106.53 -u admin -p 'Supwisdom!@#' --authenticationDatabase admin --gzip -d "swopErrorData" -o /data/mongo/$(date +%Y%m%d) >/dev/null 2>&1


```



### 还原

#还原到一个新库报错，因为没有创建库等权限

```bash
# mongorestore -h 192.168.106.53 -u admin -p 'Supwisdom!@#' --authenticationDatabase admin --gzip -d "swop01" /data/mongo/$(date +%Y%m%d)/swopErrorData/ --gzip
2024-05-27T22:07:26.016+0800    The --db and --collection flags are deprecated for this use-case; please use --nsInclude instead, i.e. with --nsInclude=${DATABASE}.${COLLECTION}
2024-05-27T22:07:26.017+0800    building a list of collections to restore from /data/mongo/20240527/swopErrorData dir
2024-05-27T22:07:26.017+0800    reading metadata for swop01.SWOP_JOB_LOG from /data/mongo/20240527/swopErrorData/SWOP_JOB_LOG.metadata.json.gz
2024-05-27T22:07:26.017+0800    reading metadata for swop01.SWOP_TRANS_LOG from /data/mongo/20240527/swopErrorData/SWOP_TRANS_LOG.metadata.json.gz
2024-05-27T22:07:26.017+0800    reading metadata for swop01.swopErrorData from /data/mongo/20240527/swopErrorData/swopErrorData.metadata.json.gz
2024-05-27T22:07:26.017+0800    reading metadata for swop01.swopWorkErrorLog from /data/mongo/20240527/swopErrorData/swopWorkErrorLog.metadata.json.gz
2024-05-27T22:07:26.018+0800    reading metadata for swop01.swopWorkLog from /data/mongo/20240527/swopErrorData/swopWorkLog.metadata.json.gz
2024-05-27T22:07:26.019+0800    finished restoring swop01.swopWorkLog (0 documents, 0 failures)
2024-05-27T22:07:26.019+0800    Failed: swop01.swopWorkLog: error creating collection swop01.swopWorkLog: error running create command: (Unauthorized) not authorized on swop01 to execute command { create: "swopWorkLog", idIndex: { key: { _id: 1 }, ns: "swop01.swopWorkLog", name: "_id_" }, lsid: { id: UUID("6fd065e8-a56a-433a-943a-840a124138a9") }, $db: "swop01" }
2024-05-27T22:07:26.019+0800    0 document(s) restored successfully. 0 document(s) failed to restore.
```



#赋予readWriteAnyDatabase权限后再次还原正常

```bash
# mongo -u admin -p 'Supwisdom!@#' --authenticationDatabase admin
MongoDB shell version v4.4.29
connecting to: mongodb://127.0.0.1:27017/?authSource=admin&compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("470445bb-d7de-4aeb-bd5b-1583b16b5e5f") }
MongoDB server version: 4.4.29
> use admin;
switched to db admin
> db.getUser("admin");
{
        "_id" : "admin.admin",
        "userId" : UUID("17f407eb-4586-4c84-9cdd-df1d65bee783"),
        "user" : "admin",
        "db" : "admin",
        "roles" : [
                {
                        "role" : "backup",
                        "db" : "admin"
                },
                {
                        "role" : "userAdminAnyDatabase",
                        "db" : "admin"
                }
        ],
        "mechanisms" : [
                "SCRAM-SHA-1",
                "SCRAM-SHA-256"
        ]
}

> db.grantRolesToUser("admin",[{role: "readWriteAnyDatabase", db: "admin"}]);
> db.getUser("admin");
{
        "_id" : "admin.admin",
        "userId" : UUID("17f407eb-4586-4c84-9cdd-df1d65bee783"),
        "user" : "admin",
        "db" : "admin",
        "roles" : [
                {
                        "role" : "readWriteAnyDatabase",
                        "db" : "admin"
                },
                {
                        "role" : "userAdminAnyDatabase",
                        "db" : "admin"
                },
                {
                        "role" : "backup",
                        "db" : "admin"
                }
        ],
        "mechanisms" : [
                "SCRAM-SHA-1",
                "SCRAM-SHA-256"
        ]
}
> exit
bye

# mongorestore -h 192.168.106.53 -u admin -p 'Supwisdom!@#' --authenticationDatabase admin --gzip -d "swop01" /data/mongo/$(date +%Y%m%d)/swopErrorData/ --gzip
2024-05-27T22:11:33.964+0800    The --db and --collection flags are deprecated for this use-case; please use --nsInclude instead, i.e. with --nsInclude=${DATABASE}.${COLLECTION}
2024-05-27T22:11:33.965+0800    building a list of collections to restore from /data/mongo/20240527/swopErrorData dir
2024-05-27T22:11:33.965+0800    reading metadata for swop01.SWOP_JOB_LOG from /data/mongo/20240527/swopErrorData/SWOP_JOB_LOG.metadata.json.gz
2024-05-27T22:11:33.965+0800    reading metadata for swop01.SWOP_TRANS_LOG from /data/mongo/20240527/swopErrorData/SWOP_TRANS_LOG.metadata.json.gz
2024-05-27T22:11:33.965+0800    reading metadata for swop01.swopErrorData from /data/mongo/20240527/swopErrorData/swopErrorData.metadata.json.gz
2024-05-27T22:11:33.965+0800    reading metadata for swop01.swopWorkErrorLog from /data/mongo/20240527/swopErrorData/swopWorkErrorLog.metadata.json.gz
2024-05-27T22:11:33.965+0800    reading metadata for swop01.swopWorkLog from /data/mongo/20240527/swopErrorData/swopWorkLog.metadata.json.gz
2024-05-27T22:11:34.145+0800    restoring swop01.swopWorkErrorLog from /data/mongo/20240527/swopErrorData/swopWorkErrorLog.bson.gz
2024-05-27T22:11:34.145+0800    restoring swop01.swopWorkLog from /data/mongo/20240527/swopErrorData/swopWorkLog.bson.gz
2024-05-27T22:11:34.157+0800    finished restoring swop01.swopWorkErrorLog (5 documents, 0 failures)
2024-05-27T22:11:34.162+0800    restoring swop01.SWOP_TRANS_LOG from /data/mongo/20240527/swopErrorData/SWOP_TRANS_LOG.bson.gz
2024-05-27T22:11:34.174+0800    finished restoring swop01.SWOP_TRANS_LOG (4 documents, 0 failures)
2024-05-27T22:11:34.175+0800    finished restoring swop01.swopWorkLog (556 documents, 0 failures)
2024-05-27T22:11:34.198+0800    restoring swop01.SWOP_JOB_LOG from /data/mongo/20240527/swopErrorData/SWOP_JOB_LOG.bson.gz
2024-05-27T22:11:34.208+0800    finished restoring swop01.SWOP_JOB_LOG (0 documents, 0 failures)
2024-05-27T22:11:34.224+0800    restoring swop01.swopErrorData from /data/mongo/20240527/swopErrorData/swopErrorData.bson.gz
2024-05-27T22:11:34.250+0800    finished restoring swop01.swopErrorData (0 documents, 0 failures)
2024-05-27T22:11:34.250+0800    restoring indexes for collection swop01.SWOP_JOB_LOG from metadata
2024-05-27T22:11:34.250+0800    index: &idx.IndexDocument{Options:primitive.M{"name":"JOB_LOG_ID_1", "v":2}, Key:primitive.D{primitive.E{Key:"JOB_LOG_ID", Value:1}}, PartialFilterExpression:primitive.D(nil)}
2024-05-27T22:11:34.250+0800    restoring indexes for collection swop01.SWOP_TRANS_LOG from metadata
2024-05-27T22:11:34.251+0800    index: &idx.IndexDocument{Options:primitive.M{"name":"TRANS_LOG_ID_1", "v":2}, Key:primitive.D{primitive.E{Key:"TRANS_LOG_ID", Value:1}}, PartialFilterExpression:primitive.D(nil)}
2024-05-27T22:11:34.251+0800    restoring indexes for collection swop01.swopErrorData from metadata
2024-05-27T22:11:34.251+0800    index: &idx.IndexDocument{Options:primitive.M{"name":"_swopLogId_1", "v":2}, Key:primitive.D{primitive.E{Key:"_swopLogId", Value:1}}, PartialFilterExpression:primitive.D(nil)}
2024-05-27T22:11:34.251+0800    index: &idx.IndexDocument{Options:primitive.M{"name":"_createtime_-1", "v":2}, Key:primitive.D{primitive.E{Key:"_createtime", Value:-1}}, PartialFilterExpression:primitive.D(nil)}
2024-05-27T22:11:34.252+0800    restoring indexes for collection swop01.swopWorkErrorLog from metadata
2024-05-27T22:11:34.252+0800    index: &idx.IndexDocument{Options:primitive.M{"name":"logId_-1", "v":2}, Key:primitive.D{primitive.E{Key:"logId", Value:-1}}, PartialFilterExpression:primitive.D(nil)}
2024-05-27T22:11:34.266+0800    restoring indexes for collection swop01.swopWorkLog from metadata
2024-05-27T22:11:34.266+0800    index: &idx.IndexDocument{Options:primitive.M{"name":"logId_-1", "v":2}, Key:primitive.D{primitive.E{Key:"logId", Value:-1}}, PartialFilterExpression:primitive.D(nil)}
2024-05-27T22:11:34.475+0800    565 document(s) restored successfully. 0 document(s) failed to restore.

#查看新库数据
# mongo -u admin -p 'Supwisdom!@#' --authenticationDatabase admin
MongoDB shell version v4.4.29
connecting to: mongodb://127.0.0.1:27017/?authSource=admin&compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("d20eaa2d-ff2c-43d8-a52e-1f66f2e9ce56") }
MongoDB server version: 4.4.29
> show dbs;
admin          0.000GB
config         0.000GB
dataassets     0.000GB
local          0.000GB
swop01         0.000GB
swopErrorData  0.001GB
> use swop01;
switched to db swop01
> show collections;
SWOP_JOB_LOG
SWOP_TRANS_LOG
swopErrorData
swopWorkErrorLog
swopWorkLog
```



#增量

#https://tencentcloud.csdn.net/65bc87986901917cd68b7355.html?dp_token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6MTE0MjY2LCJleHAiOjE3MTc0MTMxMjMsImlhdCI6MTcxNjgwODMyMywidXNlcm5hbWUiOiJnYW9mbHlkb2cifQ.LVdQSlgkOxz5g3lXOKCRXcNXHFhDhI3c4ZS2csHfQQc

