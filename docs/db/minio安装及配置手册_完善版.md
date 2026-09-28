# minio安装及配置手册-arm64

说明：minio主要做解决数据资产非结构化文件存储问题，在数据资产1.2.x版本之后支持。

非必要（如果不需要非结构化文件存储，可以不安装minio）

如果不安装minio，那么数据资产安装部署后微服务：dataassets-minio和dataassets-file-collect这个两个微服务不需要启动。

## 1、服务器申请

服务器要求（建议）：5台服务器，1台做nginx负载，4台做minio集群

nginx服务器：KylinSec OS arm64位，cpu4 ，内存 8G

minio集群服务器：KylinSec OS arm64位，cpu8 ，内存 16G，存储4TB

**注意：服务器的IP地址要为连续的**

这个只是建议的配置，看这个现场的实际需求，minio集群服务器数量和配置都可以减少的（最少2台服务），nginx服务器是必须要有的

部署文档是按照4台minio集群服务器写的，如果不一样需要修改响应的脚本

## 2、服务器优化





## 3、安装部署

**注意：步骤1至5 minio集群所有服务器都需要执行**

### 3.1、服务器创建目录

```shell
# 创建minio使用目录
# 存放minio可执行文件
mkdir -p /data/minio/bin
# 存放minio日志文件夹
mkdir -p /data/minio/log
# 挂载盘路径
mkdir -p /data/minio/mnt
# 挂载盘数据存放路径
mkdir -p /data/minio/mnt/data{1..4}
```

### 3.2、上传可执行文件

#minio server可执行文件

```bash
cd /data/minio/bin/
#从公司钉钉下载
#https://github.com/minio
#wget https://dl.min.io/server/minio/release/linux-arm64/archive/minio.RELEASE.2021-08-25T00-41-18Z
#mv minio.RELEASE.2021-08-25T00-41-18Z minio
chmod a+x minio
```

#如果采用最新版minio，必须要配置单独的硬盘

```bash

#最新版的minio，data1---data4目录必须是独占的磁盘分区，不能是文件目录
#否则报错drive is part of root drive
#每台新加四块磁盘
wget https://dl.min.io/server/minio/release/linux-arm64/minio

#不重启，直接刷新磁盘数据总线，获取新加的磁盘
for host in $(ls /sys/class/scsi_host) ; do echo "- - -" > /sys/class/scsi_host/$host/scan; done

lsblk

# 格式化
mkfs.xfs /dev/sdb
mkfs.xfs /dev/sdc
mkfs.xfs /dev/sdd
mkfs.xfs /dev/sde

# 挂载
mount /dev/sdb /data/minio/mnt/data1
mount /dev/sdc /data/minio/mnt/data2
mount /dev/sdd /data/minio/mnt/data3
mount /dev/sde /data/minio/mnt/data4

#写入/etc/fstab
cat >> /etc/fstab <<EOF
/dev/sdb /data/minio/mnt/data1 defaults 0 0
/dev/sdc /data/minio/mnt/data2 defaults 0 0
/dev/sdd /data/minio/mnt/data3 defaults 0 0
/dev/sde /data/minio/mnt/data4 defaults 0 0
EOF
```

#最新版minio，非独占分区时的errer log

```log
Unable to use the drive http://192.168.106.55:9000/data/minio/mnt/data1: drive is part of root drive, will not be used
Unable to use the drive http://192.168.106.55:9000/data/minio/mnt/data2: drive is part of root drive, will not be used
Unable to use the drive http://192.168.106.55:9000/data/minio/mnt/data3: drive is part of root drive, will not be used
Unable to use the drive http://192.168.106.55:9000/data/minio/mnt/data4: drive is part of root drive, will not be used

API: SYSTEM.internal
Time: 02:45:40 UTC 05/20/2024
Error: Read failed. Insufficient number of drives online (*errors.errorString)
      11: internal/logger/logger.go:268:logger.LogIf()
      10: cmd/logging.go:94:cmd.internalLogIf()
       9: cmd/prepare-storage.go:243:cmd.connectLoadInitFormats()
       8: cmd/prepare-storage.go:292:cmd.waitForFormatErasure()
       7: cmd/erasure-server-pool.go:130:cmd.newErasureServerPools.func1()
       6: cmd/server-main.go:586:cmd.bootstrapTrace()
       5: cmd/erasure-server-pool.go:129:cmd.newErasureServerPools()
       4: cmd/server-main.go:1185:cmd.newObjectLayer()
       3: cmd/server-main.go:934:cmd.serverMain.func10()
       2: cmd/server-main.go:586:cmd.bootstrapTrace()
       1: cmd/server-main.go:932:cmd.serverMain()
Waiting for a minimum of 8 drives to come online (elapsed 20s)


API: SYSTEM.storage
Time: 02:45:41 UTC 05/20/2024
Error: Drive http://192.168.106.55:9000/data/minio/mnt/data2 returned an unexpected error: m
ajor: 253: minor: 0: drive is part of root drive, will not be used, please investigate - dr
ive will be offline (*fmt.wrapError)
       6: internal/logger/logonce.go:118:logger.(*logOnceType).logOnceIf()
       5: internal/logger/logonce.go:149:logger.LogOnceIf()
       4: cmd/logging.go:146:cmd.storageLogOnceIf()
       3: cmd/storage-rest-server.go:1236:cmd.logFatalErrs()
       2: cmd/storage-rest-server.go:1378:cmd.registerStorageRESTHandlers.func2()
       1: cmd/storage-rest-server.go:1402:cmd.registerStorageRESTHandlers.func3()

```



#minio client

```bash
#wget https://dl.min.io/client/mc/release/linux-arm64/mc
wget https://dl.min.io/client/mc/release/linux-arm64/archive/mc.RELEASE.2021-09-02T09-21-27Z
mv mc.RELEASE.2021-09-02T09-21-27Z mc
chmod +x mc
mc alias set myminio/ http://MINIO-SERVER MYUSER MYPASSWORD
#mc config host add <ALIAS> <YOUR-MINIO-ENDPOINT> [YOUR-ACCESS-KEY] [YOUR-SECRET-KEY]
```



### 3.3、上传启动脚本

#单次启动脚本

```bash
#MINIO_ROOT_USER=admin MINIO_ROOT_PASSWORD=password ./minio server /mnt/data --console-address ":9001"

nohup MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=Supwisdom@321 /data/minio /bin/minio server   --console-address=":9001" http://192.168.106.{52...55}/data/minio/mnt/data{1...4} > /data/minio/log/minio.log 2>&1 &
```



#启动脚本startup_minio_cluster.sh

```shell
cat > /data/minio/startup_minio_cluster.sh <<'EOF'
#!/bin/bash
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=Supwisdom@321
MINIO_HOME=/data/minio

${MINIO_HOME}/bin/minio server   --console-address=":9001" \
http://192.168.106.{52...55}/data/minio/mnt/data{1...4} \
>${MINIO_HOME}/log/minio.log

EOF

chmod a+x /data/minio/startup_minio_cluster.sh
```

**说明：**

**1、MINIO_ROOT_USER  minio部署后的访问用户名**

**2、MINIO_ROOT_PASSWORD minio部署后的访问密码**

**3、脚本中的IP地址要换成 minio集群服务器的地址**

修改后的启动脚本上传至服务器(所有集群服务器)目录/data/minio

### 3.4、执行启动脚本---4台虚拟机都执行

```shell
cd /data/minio
# 启动minio
sh startup_minio_cluster.sh
# 查看运行日志
tail -f log/minio.log
```

#自启动脚本

```bash
# 如果使用rpm安装，minio.service就会自动生成，只要修改就行
cat > /usr/lib/systemd/system/minio.service <<EOF
[Unit]
Description=Minio service
Documentation=https://docs.minio.io/

[Service]
WorkingDirectory=/data/minio
ExecStart=/data/minio/startup_minio_cluster.sh

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


chmod a+x /usr/lib/systemd/system/minio.service

systemctl daemon-reload

systemctl restart minio && systemctl enable minio

systemctl status minio
```




### 3.5、minio启动后测试

在浏览器访问任意一台集群服务器都能访问，访问方式：http://ip:9001  用启动脚本中的用户、密码

#端口9000/9001

```bash
# netstat -tnulp|grep 9000
tcp6       0      0 :::9000                 :::*                    LISTEN      615461/minio        
# netstat -tnulp|grep 9001
tcp6       0      0 :::9001                 :::*                    LISTEN      615461/minio        
```

```bash
# netstat -tnulp|grep minio
tcp6       0      0 :::9001                 :::*                    LISTEN      1196/minio          
tcp6       0      0 :::9000                 :::*                    LISTEN      1196/minio          
```



### 3.6、配置nginx

> 0、安装nginx

#minio-nginx
```bash
#minio-nginx

yum install -y gcc-c++
yum install -y pcre pcre-devel
yum install -y zlib zlib-devel
yum install -y openssl openssl-devel


yum install -y nginx

systemctl enable nginx
```



> 1、修改minio.conf

修改upstream minio_cluster和upstream minio_console_cluster中的minio集群服务器IP

**注意：如果需要证书的，按照各个现场自行修改server中参数**

修改后上传到nginx中的nginx.conf同目录下的conf.d目录

```shell

 upstream minio_cluster {
    server 192.168.106.52:9000;
    server 192.168.106.53:9000;
    server 192.168.106.54:9000;
    server 192.168.106.55:9000;
 }
 
 upstream minio_console_cluster {
    server 192.168.106.52:9001;
    server 192.168.106.53:9001;
    server 192.168.106.54:9001;
    server 192.168.106.55:9001;
 }

server {
 listen 80;
 listen [::]:80;
 server_name ds-file.test.edu.cn;
 #listen 443 ssl;
 #ssl_certificate     /etc/nginx/conf.d/test.edu.cn.pem;
 #ssl_certificate_key /etc/nginx/conf.d/test.edu.cn.key;

 # To allow special characters in headers
 ignore_invalid_headers off;
 # Allow any size file to be uploaded.
 # Set to a value such as 1000m; to restrict file size to a specific value
 client_max_body_size 0;
 # To disable buffering
 proxy_buffering off;

	location / {

	   proxy_set_header X-Real-IP $remote_addr;
	   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	   proxy_set_header X-Forwarded-Proto $scheme;
	   proxy_set_header Host $http_host;

	   proxy_connect_timeout 300;
	   # Default is HTTP/1, keepalive is only enabled in HTTP/1.1
	   proxy_http_version 1.1;
	   proxy_set_header Connection "";
	   chunked_transfer_encoding off;

	   proxy_pass http://minio_cluster;
	}
}

server { 
	listen 80; 
	listen [::]:80; 
	server_name ds-file-web.test.edu.cn; 
	#listen 443 ssl;
  #ssl_certificate     /etc/nginx/conf.d/test.edu.cn.pem;
  #ssl_certificate_key /etc/nginx/conf.d/test.edu.cn.key;
  
	# To allow special characters in headers 
	ignore_invalid_headers off; 
	# Allow any size file to be uploaded. 
	# Set to a value such as 1000m; to restrict file size to a specific value 
	client_max_body_size 0; 
	# To disable buffering 
	proxy_buffering off; 
	
	location / { 
		proxy_set_header Host $http_host; 
		proxy_set_header X-Real-IP $remote_addr; 
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; 
		proxy_set_header X-Forwarded-Proto $scheme; 
		proxy_set_header X-NginX-Proxy true; 
		
		proxy_connect_timeout 300; 
		# Default is HTTP/1, keepalive is only enabled in HTTP/1.1 
		proxy_http_version 1.1; 
		proxy_set_header Connection ""; 
		chunked_transfer_encoding off; 
		proxy_pass http://minio_console_cluster; 
	} 
}
```

> 2、修改nginx.conf配置

在http标签最后添加include conf.d/minio.conf;

```shell

#user  nobody;
worker_processes  auto;

events {
    worker_connections  10240;
}


http {
    ## 忽略的内容，在http标签最后添加
	include conf.d/minio.conf;
}

```

> 3、验证访问

做完以上操作，重启nginx

#在浏览器访问http://nginx服务器ip  用启动脚本中的用户、密码

> 4、配置域名（必须的）

| 域名（xxx换成学校实际域名）     | 映射说明                  |
| ------------------------------- | ------------------------- |
| https://ds-file.xxx.edu.cn     | 映射到nginx服务器端口443 |
| https://ds-file-web.xxx.edu.cn | 映射到nginx服务器端口443 |

nginx自启动可以参考连接：https://www.cnblogs.com/downey-blog/p/10473939.html

## 4、数据资产配置

在数据资产配置映射中需要修改两个参数

| 配置映射参数(Rancher) | 参数值                                            | 说明 |
| --------------------- | ------------------------------------------------- | ---- |
| MINIO_ENDPOINT        | https://ds-file.xxx.edu.cn                       |      |
| VUE_MINIO_BASE_URL    | https://ds-file.xxx.edu.cn/dataassetsbucket/ |      |
| MINIO_USERNAME   | minioadmin |      |
| MINIO_PASSWORD   | Supwisdom@321 |      |

修改完成以后要重启微服务：dataassets-minio、dataassets-file-collect







## 5. 服务器IP地址不连续时，走hostname

```bash
#!/bin/bash

export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD='Supwisdom@321'

MINIO_HOME=/data/minio

nohup ${MINIO_HOME}/bin/minio server \
  --console-address=":9001" \
  http://192.168.99.54/data/minio/mnt/data{1...4} \
  http://192.168.99.43/data/minio/mnt/data{1...4} \
  http://192.168.99.41/data/minio/mnt/data{1...4} \
  http://192.168.99.42/data/minio/mnt/data{1...4} \
  >${MINIO_HOME}/log/minio.log 2>&1 &
```





这组主机名正好适合直接用 MinIO 的 `{1...4}` 展开语法，比直接写 4 个 IP 更方便。MinIO 官方文档也支持用连续 hostname 定义分布式集群，并要求每个节点使用**完全相同的 server 命令**。[MinIO AIStor Documentation](https://docs.min.io/aistor/reference/aistor-server/?utm_source=chatgpt.com)

建议先在 **4 台机器的 `/etc/hosts` 都配置相同内容**：

```
192.168.99.54 ecs-minio-0001
192.168.99.43 ecs-minio-0002
192.168.99.41 ecs-minio-0003
192.168.99.42 ecs-minio-0004
```

然后确认互相能解析：

```
ping -c 2 ecs-minio-0001
ping -c 2 ecs-minio-0002
ping -c 2 ecs-minio-0003
ping -c 2 ecs-minio-0004
```

启动脚本就可以写成：

```
cat > /data/minio/startup_minio_cluster.sh <<'EOF'
#!/bin/bash

export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD='tfb0LtEO8aD0cIqW'

MINIO_HOME=/data/minio

nohup ${MINIO_HOME}/bin/minio server \
  --console-address=":9001" \
  http://ecs-minio-000{1...4}/data/minio/mnt/data{1...4} \
  >${MINIO_HOME}/log/minio.log 2>&1 &
EOF

chmod a+x /data/minio/startup_minio_cluster.sh
```

这个表达式会展开成：

```
ecs-minio-0001:
  /data/minio/mnt/data1
  /data/minio/mnt/data2
  /data/minio/mnt/data3
  /data/minio/mnt/data4

ecs-minio-0002:
  /data/minio/mnt/data1
  /data/minio/mnt/data2
  /data/minio/mnt/data3
  /data/minio/mnt/data4

ecs-minio-0003:
  /data/minio/mnt/data1
  /data/minio/mnt/data2
  /data/minio/mnt/data3
  /data/minio/mnt/data4

ecs-minio-0004:
  /data/minio/mnt/data1
  /data/minio/mnt/data2
  /data/minio/mnt/data3
  /data/minio/mnt/data4
```

即 **4 个节点 × 每节点 4 个数据目录 = 16 个 endpoint**。MinIO 的 hostname 和目录都支持 `{x...y}` 展开。[MinIO AIStor Documentation](https://docs.min.io/aistor/reference/aistor-server/?utm_source=chatgpt.com)

四台机器：

```
192.168.99.54 ecs-minio-0001
192.168.99.43 ecs-minio-0002
192.168.99.41 ecs-minio-0003
192.168.99.42 ecs-minio-0004
```

**全部运行同一份脚本**，不要根据本机 hostname 修改 endpoint。

启动之前，我建议每台执行：

```
mkdir -p /data/minio/log
mkdir -p /data/minio/mnt/data{1..4}
```

注意这里有个容易混淆的地方：

```
# Bash 创建目录
/data/minio/mnt/data{1..4}

# MinIO endpoint 展开
/data/minio/mnt/data{1...4}
```

另外检查 9000 端口互通，例如在任意节点：

```
for host in ecs-minio-000{1..4}; do
    echo "===== $host ====="
    ping -c 1 $host
done
```

如果 MinIO 还没启动，`9000` 暂时当然不会通；启动后可以检查：

```
for host in ecs-minio-000{1..4}; do
    nc -zv $host 9000
done
```

然后查看本机日志：

```
tail -100f /data/minio/log/minio.log
```

最终你的部署关系就是：

```
                    MinIO Cluster
                         │
        ┌────────────────┼────────────────┐
        │                │                │
ecs-minio-0001    ecs-minio-0002   ecs-minio-0003   ecs-minio-0004
192.168.99.54     192.168.99.43    192.168.99.41    192.168.99.42
        │                │                │                │
    data1~4          data1~4          data1~4          data1~4
```

所以，你目前这套环境，我建议最终直接使用这一条核心命令：

```
${MINIO_HOME}/bin/minio server \
  --console-address=":9001" \
  http://ecs-minio-000{1...4}/data/minio/mnt/data{1...4}
```

而不是继续使用 IP 地址。以后即使 IP 发生变化，只需要维护 DNS 或 `/etc/hosts`，MinIO 启动脚本无需修改。



## 6.自动启动



在 `ecs-minio-0004`：

```
systemctl stop minio

rm -f /usr/lib/systemd/system/minio.service

mkdir -p /etc/minio
```

创建环境变量：

```
cat > /etc/minio/minio.conf <<'EOF'
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=你的密码
EOF

chmod 600 /etc/minio/minio.conf
```

service：

```
cat > /etc/systemd/system/minio.service <<'EOF'
[Unit]
Description=MinIO Object Storage
Documentation=https://min.io/docs/
Wants=network-online.target
After=network-online.target local-fs.target

[Service]
Type=simple
EnvironmentFile=/etc/minio/minio.conf
WorkingDirectory=/data/minio

ExecStart=/data/minio/bin/minio server --console-address=:9001 http://ecs-minio-000{1...4}/data/minio/mnt/data{1...4}

Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

然后：

```
systemctl daemon-reload
systemctl enable --now minio
```

检查：

```
systemctl status minio -l
```

然后：

```
journalctl -u minio -n 100 --no-pager
```

以及：

```
ps -ef | grep '[m]inio'
```

如果正常，你应该看到：

```
Active: active (running)
```

最后再从 Windows 确认：

```
mc.exe admin info minio
```

恢复：

```
ecs-minio-0001  Drives: 4/4 OK
ecs-minio-0002  Drives: 4/4 OK
ecs-minio-0003  Drives: 4/4 OK
ecs-minio-0004  Drives: 4/4 OK

16 drives online, 0 drives offline
```

之后把同样的 systemd 配置部署到其余三台即可。











## 7. data2/data3/data4 迁移到独立 LVM 数据盘

### 7.1 迁移目标和最终磁盘布局

当前每台 MinIO 虚拟机只有一块数据盘 `/dev/vdb`，通过 LVM 挂载到 `/data`：

```text
/dev/vdb
  └─vg_bigdata-lv_data
       └─/data
          └─/data/minio/mnt/
             ├─data1
             ├─data2
             ├─data3
             └─data4
```

当前 `data1`、`data2`、`data3`、`data4` 实际上只是同一个 `/data` 文件系统中的 4 个目录。为了使 MinIO 的 4 个 drive 对应 4 个独立虚拟磁盘，同时保留以后扩容虚拟磁盘后使用 LVM 扩容的能力，建议最终调整为：

```text
/dev/vdb
  └─vg_bigdata-lv_data
       └─/data
          └─/data/minio/mnt/data1

/dev/vdc
  └─vg_minio_data2-lv_data2
       └─/data/minio/mnt/data2

/dev/vdd
  └─vg_minio_data3-lv_data3
       └─/data/minio/mnt/data3

/dev/vde
  └─vg_minio_data4-lv_data4
       └─/data/minio/mnt/data4
```

说明：

1. `/dev/vdb` 保持现状，不重新格式化，`data1` 继续保留在 `/data` 文件系统中。
2. 每台 MinIO 虚拟机新增 3 块独立虚拟磁盘：`/dev/vdc`、`/dev/vdd`、`/dev/vde`。
3. 新增磁盘采用“一块磁盘 -> 一个 PV -> 一个 VG -> 一个 LV -> 一个 MinIO data 挂载点”的方式，不要把多块 MinIO 数据盘加入同一个 VG。
4. `data2`、`data3`、`data4` 分别迁移到新 LV，MinIO endpoint 路径保持不变，因此原启动参数无需修改。
5. 不要使用 `cp`、`scp`、`rsync` 直接复制 MinIO 底层数据目录。迁移时将新的空文件系统挂载到原 endpoint 路径，由 MinIO 自动进行 healing/rebuild。
6. 每次只迁移一个 endpoint，确认集群恢复到 `16 drives online, 0 drives offline` 后，再迁移下一个 endpoint。不要并行迁移多个节点或多个 drive。

> 注意：以下示例以 `/dev/vdc -> data2`、`/dev/vdd -> data3`、`/dev/vde -> data4` 为例。实际设备名必须以 `lsblk` 输出为准。`pvcreate`、`mkfs.xfs` 都会改变磁盘内容，执行前必须确认是新分配的空磁盘。


### 7.2 迁移前检查

四台 MinIO 节点均确认集群正常后再开始操作。

Windows 或安装有新版 `mc` 的管理机执行：

```bash
mc admin info minio
```

开始迁移前应确认类似：

```text
ecs-minio-0001  Drives: 4/4 OK
ecs-minio-0002  Drives: 4/4 OK
ecs-minio-0003  Drives: 4/4 OK
ecs-minio-0004  Drives: 4/4 OK

16 drives online, 0 drives offline
```

如果老版本 `mc` 出现：

```text
Drives: 0/0 OK
0 drives online, 0 drives offline
```

先升级 `mc` 后再检查，避免因为客户端版本过旧导致状态显示不完整。

在准备迁移的 MinIO 节点执行：

```bash
hostname
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
pvs
vgs
lvs
df -h /data
```

确认当前 `/dev/vdb` 和 `/data` 关系正确，并确认新增磁盘尚未承载业务数据。


### 7.3 扫描并确认新分配磁盘

虚拟化平台给每台 MinIO 虚拟机新增 3 块磁盘后，如果操作系统没有立即识别，可以扫描 SCSI 总线：

```bash
for host in $(ls /sys/class/scsi_host); do
    echo "- - -" > /sys/class/scsi_host/${host}/scan
done
```

然后查看磁盘：

```bash
lsblk
```

示例：

```text
NAME                   SIZE TYPE MOUNTPOINT
vda                    128G disk
└─vda1                 128G part /
vdb                    384G disk
└─vg_bigdata-lv_data   384G lvm  /data
vdc                    384G disk
vdd                    384G disk
vde                    384G disk
```

再次确认 `/dev/vdc`、`/dev/vdd`、`/dev/vde` 为新分配空盘后再继续。


### 7.4 为 data2 创建 LVM 和 XFS 文件系统

以下操作先只处理 `/dev/vdc`，不要同时处理 data3、data4 的迁移。

创建 PV：

```bash
pvcreate /dev/vdc
```

创建独立 VG：

```bash
vgcreate vg_minio_data2 /dev/vdc
```

创建 LV，使用该 VG 的全部空间：

```bash
lvcreate -n lv_data2 -l 100%FREE vg_minio_data2
```

查看：

```bash
pvs
vgs
lvs
lsblk
```

格式化为 XFS：

```bash
mkfs.xfs /dev/vg_minio_data2/lv_data2
```

获取文件系统 UUID：

```bash
blkid /dev/vg_minio_data2/lv_data2
```

建议使用 UUID 写入 `/etc/fstab`，避免设备名变化导致挂载错误。


### 7.5 迁移 data2 到新 LV

#### 7.5.1 再次确认集群健康

```bash
mc admin info minio
```

必须先确认当前为：

```text
16 drives online, 0 drives offline
```

#### 7.5.2 停止当前节点 MinIO

假设当前操作节点为 `ecs-minio-0001`：

```bash
systemctl stop minio
```

确认 MinIO 主进程已经停止：

```bash
ps -ef | grep '[m]inio'
```

维护期间只操作这一台节点，不要同时停止其他 MinIO 节点。

#### 7.5.3 保留原 data2 目录

不要删除原目录，先重命名作为临时回退数据：

```bash
cd /data/minio/mnt
mv data2 data2.old
mkdir -p data2
```

此时目录结构类似：

```text
/data/minio/mnt/
├─data1
├─data2          # 新的空挂载点
├─data2.old      # 原 data2 底层数据，暂时保留
├─data3
└─data4
```

#### 7.5.4 配置永久挂载

先获取 UUID：

```bash
blkid /dev/vg_minio_data2/lv_data2
```

编辑 `/etc/fstab`，增加：

```text
UUID=<data2文件系统UUID> /data/minio/mnt/data2 xfs defaults,noatime 0 2
```

然后执行：

```bash
mount /data/minio/mnt/data2
```

验证：

```bash
findmnt /data/minio/mnt/data2
df -h /data/minio/mnt/data2
ls -la /data/minio/mnt/data2
```

此时 `/data/minio/mnt/data2` 应当对应新 LV，并且开始时基本为空。

#### 7.5.5 启动 MinIO

```bash
systemctl start minio
systemctl status minio -l
```

实时查看日志：

```bash
journalctl -u minio -f
```

也可以查看最近日志：

```bash
journalctl -u minio -n 200 --no-pager
```

MinIO endpoint 路径没有变化，仍然是：

```text
http://ecs-minio-0001/data/minio/mnt/data2
```

因此不需要修改 MinIO server 的 endpoint 配置。MinIO 会将新挂载的空 data2 识别为需要恢复的 drive，并自动进行 healing/rebuild。

#### 7.5.6 检查 healing 和集群状态

在管理机持续检查：

```bash
mc admin info minio
```

必要时可以查看 healing：

```bash
mc admin heal minio/ --verbose
```

最终必须恢复到：

```text
16 drives online, 0 drives offline
```

同时在节点确认新 data2 已经产生 MinIO 数据：

```bash
findmnt /data/minio/mnt/data2
du -sh /data/minio/mnt/data2
ls -la /data/minio/mnt/data2
```

并从客户端抽查已有 bucket/object：

```bash
mc ls minio
```

如果有测试对象，可以执行：

```bash
mc stat minio/<bucket>/<object>
```

并实际下载文件验证。

#### 7.5.7 删除旧 data2 目录

只有在以下条件全部满足后，才允许删除 `data2.old`：

- `mc admin info minio` 显示 `16 drives online, 0 drives offline`；
- 新 `/data/minio/mnt/data2` 确认为新 LV；
- healing 已完成；
- bucket/object 读取验证正常；
- 已保留必要的外部备份或确认可以删除回退目录。

检查旧目录：

```bash
du -sh /data/minio/mnt/data2.old
```

确认无误后：

```bash
rm -rf /data/minio/mnt/data2.old
```

删除后，原 `/dev/vdb` 上对应空间被释放。


### 7.6 迁移 data3 到 /dev/vdd

只有在 data2 完成迁移并恢复 `16 drives online, 0 drives offline` 后，才开始 data3。

创建 LVM：

```bash
pvcreate /dev/vdd
vgcreate vg_minio_data3 /dev/vdd
lvcreate -n lv_data3 -l 100%FREE vg_minio_data3
mkfs.xfs /dev/vg_minio_data3/lv_data3
blkid /dev/vg_minio_data3/lv_data3
```

停止当前节点 MinIO：

```bash
systemctl stop minio
```

保留原目录并创建挂载点：

```bash
cd /data/minio/mnt
mv data3 data3.old
mkdir -p data3
```

在 `/etc/fstab` 增加：

```text
UUID=<data3文件系统UUID> /data/minio/mnt/data3 xfs defaults,noatime 0 2
```

挂载并验证：

```bash
mount /data/minio/mnt/data3
findmnt /data/minio/mnt/data3
df -h /data/minio/mnt/data3
```

启动 MinIO：

```bash
systemctl start minio
systemctl status minio -l
journalctl -u minio -f
```

检查：

```bash
mc admin info minio
```

待恢复到：

```text
16 drives online, 0 drives offline
```

确认 healing、文件读取均正常后再删除：

```bash
rm -rf /data/minio/mnt/data3.old
```


### 7.7 迁移 data4 到 /dev/vde

只有在 data3 完成迁移并恢复 `16 drives online, 0 drives offline` 后，才开始 data4。

创建 LVM：

```bash
pvcreate /dev/vde
vgcreate vg_minio_data4 /dev/vde
lvcreate -n lv_data4 -l 100%FREE vg_minio_data4
mkfs.xfs /dev/vg_minio_data4/lv_data4
blkid /dev/vg_minio_data4/lv_data4
```

停止当前节点 MinIO：

```bash
systemctl stop minio
```

保留原目录并创建挂载点：

```bash
cd /data/minio/mnt
mv data4 data4.old
mkdir -p data4
```

在 `/etc/fstab` 增加：

```text
UUID=<data4文件系统UUID> /data/minio/mnt/data4 xfs defaults,noatime 0 2
```

挂载并验证：

```bash
mount /data/minio/mnt/data4
findmnt /data/minio/mnt/data4
df -h /data/minio/mnt/data4
```

启动 MinIO：

```bash
systemctl start minio
systemctl status minio -l
journalctl -u minio -f
```

检查：

```bash
mc admin info minio
```

待恢复到：

```text
16 drives online, 0 drives offline
```

确认 healing、文件读取均正常后再删除：

```bash
rm -rf /data/minio/mnt/data4.old
```


### 7.8 单台服务器迁移完成后的检查

完成 data2、data3、data4 迁移后，检查：

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
pvs
vgs
lvs
findmnt /data
findmnt /data/minio/mnt/data2
findmnt /data/minio/mnt/data3
findmnt /data/minio/mnt/data4
```

期望结构类似：

```text
vda
└─vda1                                      /

vdb
└─vg_bigdata-lv_data                        /data
                                              └─data1

vdc
└─vg_minio_data2-lv_data2                   /data/minio/mnt/data2

vdd
└─vg_minio_data3-lv_data3                   /data/minio/mnt/data3

vde
└─vg_minio_data4-lv_data4                   /data/minio/mnt/data4
```

其中：

```text
data1 -> /dev/vdb 对应的 vg_bigdata/lv_data
data2 -> /dev/vdc 对应的 vg_minio_data2/lv_data2
data3 -> /dev/vdd 对应的 vg_minio_data3/lv_data3
data4 -> /dev/vde 对应的 vg_minio_data4/lv_data4
```

确认该节点完成后，再按相同方法迁移下一台 MinIO 节点。推荐顺序：

```text
ecs-minio-0001: data2 -> data3 -> data4
        ↓ 每一步都恢复 16/16 后再继续
ecs-minio-0002: data2 -> data3 -> data4
        ↓
ecs-minio-0003: data2 -> data3 -> data4
        ↓
ecs-minio-0004: data2 -> data3 -> data4
```

严禁同时迁移两台 MinIO 节点。


### 7.9 迁移后的 /etc/fstab 示例

每台服务器 UUID 不同，必须使用本机 `blkid` 的实际值。

示例：

```text
# 原有 /data
/dev/mapper/vg_bigdata-lv_data /data xfs defaults,noatime 0 2

# MinIO 独立数据盘
UUID=<data2-uuid> /data/minio/mnt/data2 xfs defaults,noatime 0 2
UUID=<data3-uuid> /data/minio/mnt/data3 xfs defaults,noatime 0 2
UUID=<data4-uuid> /data/minio/mnt/data4 xfs defaults,noatime 0 2
```

修改后检查语法和挂载：

```bash
mount -a
findmnt /data/minio/mnt/data2
findmnt /data/minio/mnt/data3
findmnt /data/minio/mnt/data4
```

`mount -a` 无报错后再继续。


### 7.10 迁移后完善 systemd 自启动

迁移完成后，MinIO 不应再使用 `nohup ... &` 方式由 systemd 间接启动。systemd 应直接管理 MinIO 主进程。

环境变量文件：

```bash
mkdir -p /etc/minio

cat > /etc/minio/minio.conf <<'EOF'
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=请替换为实际密码
EOF

chmod 600 /etc/minio/minio.conf
```

确认 `mountpoint` 命令路径：

```bash
command -v mountpoint
```

一般为：

```text
/usr/bin/mountpoint
```

创建或覆盖 `/etc/systemd/system/minio.service`：

```bash
cat > /etc/systemd/system/minio.service <<'EOF'
[Unit]
Description=MinIO Object Storage
Documentation=https://min.io/docs/
Wants=network-online.target
After=network-online.target local-fs.target
RequiresMountsFor=/data /data/minio/mnt/data2 /data/minio/mnt/data3 /data/minio/mnt/data4

[Service]
Type=simple
EnvironmentFile=/etc/minio/minio.conf
WorkingDirectory=/data/minio

# data1 仍位于 /data 中，data2/data3/data4 必须是真实挂载点。
ExecStartPre=/usr/bin/test -d /data/minio/mnt/data1
ExecStartPre=/usr/bin/mountpoint -q /data/minio/mnt/data2
ExecStartPre=/usr/bin/mountpoint -q /data/minio/mnt/data3
ExecStartPre=/usr/bin/mountpoint -q /data/minio/mnt/data4

ExecStart=/data/minio/bin/minio server --console-address=:9001 http://ecs-minio-000{1...4}/data/minio/mnt/data{1...4}

Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

说明：

1. `RequiresMountsFor=` 确保 systemd 在启动 MinIO 前先处理相关文件系统挂载。
2. `ExecStartPre=/usr/bin/mountpoint -q ...` 用于防止 data2/data3/data4 因磁盘未挂载而退化成 `/data` 下的普通目录。
3. 如果本机 `mountpoint` 路径不是 `/usr/bin/mountpoint`，请按 `command -v mountpoint` 的实际结果修改 service 文件。
4. systemd 直接执行 MinIO 主进程，不要在 `ExecStart` 对应脚本中使用 `nohup` 和 `&`。
5. MinIO endpoint 仍然保持：

```text
http://ecs-minio-000{1...4}/data/minio/mnt/data{1...4}
```

因此迁移磁盘后不需要修改集群 endpoint。

重新加载并启用：

```bash
systemctl daemon-reload
systemctl enable minio
systemctl restart minio
```

检查：

```bash
systemctl status minio -l
ps -ef | grep '[m]inio'
journalctl -u minio -n 100 --no-pager
```

正常应显示：

```text
Active: active (running)
```

最后确认集群：

```bash
mc admin info minio
```

必须确认：

```text
16 drives online, 0 drives offline
```


### 7.11 重启验证

全部迁移完成后，建议选择维护窗口逐台重启 MinIO 虚拟机验证自动挂载和 MinIO 自启动。一次只重启一台，不要四台同时重启。

重启前：

```bash
mc admin info minio
```

重启单台节点：

```bash
reboot
```

节点恢复后检查：

```bash
systemctl status minio -l
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
findmnt /data/minio/mnt/data2
findmnt /data/minio/mnt/data3
findmnt /data/minio/mnt/data4
journalctl -u minio -n 100 --no-pager
```

管理机再次检查：

```bash
mc admin info minio
```

确认恢复 `16 drives online, 0 drives offline` 后，再重启下一台节点。


### 7.12 后续单盘扩容方式

采用“一块虚拟磁盘 -> 一个 PV -> 一个 VG -> 一个 LV”的结构后，如果云平台直接将原虚拟磁盘扩容，例如 `/dev/vdc` 从 384G 扩容到 768G，可以使用 LVM 和 XFS 在线扩容。

先确认系统已经识别新磁盘容量：

```bash
lsblk
```

扩展 PV：

```bash
pvresize /dev/vdc
```

查看 VG 空闲空间：

```bash
pvs
vgs
```

扩展 LV：

```bash
lvextend -l +100%FREE /dev/vg_minio_data2/lv_data2
```

扩展 XFS 文件系统：

```bash
xfs_growfs /data/minio/mnt/data2
```

也可以使用：

```bash
lvextend -r -l +100%FREE /dev/vg_minio_data2/lv_data2
```

注意：

1. 不建议通过 `vgextend vg_minio_data2 /dev/vdf` 的方式把另一块独立磁盘拼接到现有 MinIO drive。
2. 如果需要扩大同一个 MinIO Pool 的容量，应统一规划各 drive 的容量，避免长期存在 drive 大小明显不一致的情况。
3. 集群级大规模扩容应单独规划新的 MinIO Server Pool，而不是把多块物理/虚拟磁盘拼成一个 LV。


### 7.13 迁移操作检查表

每迁移一个 endpoint，都按以下顺序检查：

```text
1. mc admin info -> 16 drives online, 0 drives offline
2. 确认新磁盘设备名
3. pvcreate / vgcreate / lvcreate
4. mkfs.xfs
5. blkid 获取 UUID
6. systemctl stop minio
7. dataX -> dataX.old
8. 创建新的 dataX 挂载点
9. 修改 /etc/fstab
10. mount 并用 findmnt 验证
11. systemctl start minio
12. journalctl 查看 healing/启动状态
13. mc admin info 再次恢复 16/16
14. 抽查 bucket/object
15. 最后删除 dataX.old
16. 再开始下一个 endpoint
```

如果任一步骤出现异常，停止后续迁移，不要同时继续操作其他节点或其他 drive。



## 8.minio buckets桶策略

#mc alias set my-minio http://192.168.1.100:9000 minioadmin minioadmin

mc alias set my-minio https://ds-file.fyut.edu.cn minioadmin xxxxxxx

#mc.exe alias set my-minio https://ds-file.fyut.edu.cn minioadmin xxxxxxx

#配置 minio 的登录信息，在 `~/.mc/config.json`文件

这里有两个配置：

- 第一个 my-minio ，需要填写完整的 minio url、accessKey、secreKey。
- 第二个 my-minio-anno，指需要填写 minio url，accessKey、secretKey 不要填。这个配置用于后续的匿名用户访问测试。

```json
{
	"version": "10",
	"aliases": {
		"gcs": {
			"url": "https://storage.googleapis.com",
			"accessKey": "YOUR-ACCESS-KEY-HERE",
			"secretKey": "YOUR-SECRET-KEY-HERE",
			"api": "S3v2",
			"path": "off"
		},
		"local": {
			"url": "http://localhost:9000",
			"accessKey": "",
			"secretKey": "",
			"api": "S3v4",
			"path": "auto"
		},
		"minio": {
			"url": "http://192.168.99.54:9000",
			"accessKey": "minioadmin",
			"secretKey": "tfb0LtEO8aD0cIqW",
			"api": "s3v4",
			"path": "auto"
		},
		"my-minio": {
			"url": "https://ds-file.fyut.edu.cn",
			"accessKey": "minioadmin",
			"secretKey": "xxxxxxx",
			"api": "s3v4",
			"path": "auto"
		},
		"my-minio-anno": {
			"url": "https://ds-file.fyut.edu.cn",
			"accessKey": "",
			"secretKey": "",
			"api": "s3v4",
			"path": "auto"
		},		
		"play": {
			"url": "https://play.min.io",
			"accessKey": "Q3AM3UQ867SPQQA43P2F",
			"secretKey": "zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG",
			"api": "S3v4",
			"path": "auto"
		},
		"s3": {
			"url": "https://s3.amazonaws.com",
			"accessKey": "YOUR-ACCESS-KEY-HERE",
			"secretKey": "YOUR-SECRET-KEY-HERE",
			"api": "S3v4",
			"path": "off"
		}
	}
}
```



查看 MinIO policy 的版本

```bash
# mc anonymous get-json my-minio/dataassetsbucket
{
 "Statement": [

 ],
 "Version": "2012-10-17"
}
```



创建dataassetsbucket.policy.json




```conf
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "*"
                ]
            },
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::dataassetsbucket/*"
            ]
        }
    ]
}
```

执行命令

```bash
mc anonymous set-json dataassetsbucket.policy.json my-minio/dataassetsbucket
```

上传、下载图片测试

验证漏洞是否修复

```bash
# mc ls my-minio-anno/dataassetsbucket
mc: <ERROR> Unable to list folder . Access Denied.

# mc ls my-minio/dataassetsbucket
[2026-09-28 17:26:10 CST]  13KiB STANDARD 9a252870b32e11f1d84a3cda74719c38.jpg

# mc admin info minio
●  ecs-minio-0001:9000
   Uptime: 1 hour
   Version: 2023-05-04T21:44:30Z
   Network: 4/4 OK
   Drives: 4/4 OK
   Pool: 1

●  ecs-minio-0002:9000
   Uptime: 1 hour
   Version: 2023-05-04T21:44:30Z
   Network: 4/4 OK
   Drives: 4/4 OK
   Pool: 1

●  ecs-minio-0003:9000
   Uptime: 1 hour
   Version: 2023-05-04T21:44:30Z
   Network: 4/4 OK
   Drives: 4/4 OK
   Pool: 1

●  ecs-minio-0004:9000
   Uptime: 1 hour
   Version: 2023-05-04T21:44:30Z
   Network: 4/4 OK
   Drives: 4/4 OK
   Pool: 1

┌──────┬───────────────────────┬─────────────────────┬──────────────┐
│ Pool │ Drives Usage          │ Erasure stripe size │ Erasure sets │
│ 1st  │ 0.7% (total: 4.5 TiB) │ 16                  │ 1            │
└──────┴───────────────────────┴─────────────────────┴──────────────┘

13 KiB Used, 1 Bucket, 1 Object
16 drives online, 0 drives offline, EC:4

```

