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
mkdir -p /opt/minio/bin
# 存放minio日志文件夹
mkdir -p /opt/minio/log
# 挂载盘路径
mkdir -p /opt/minio/mnt
# 挂载盘数据存放路径
mkdir -p /opt/minio/mnt/data1
mkdir -p /opt/minio/mnt/data2
mkdir -p /opt/minio/mnt/data3
mkdir -p /opt/minio/mnt/data4

```

### 3.2、上传可执行文件

#minio server可执行文件

```bash
cd /opt/minio/bin/

wget https://dl.min.io/server/minio/release/linux-arm64/archive/minio.RELEASE.2021-08-25T00-41-18Z
mv minio.RELEASE.2021-08-25T00-41-18Z minio
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
mount /dev/sdb /opt/minio/mnt/data1
mount /dev/sdc /opt/minio/mnt/data2
mount /dev/sdd /opt/minio/mnt/data3
mount /dev/sde /opt/minio/mnt/data4

#写入/etc/fstab
cat >> /etc/fstab <<EOF
/dev/sdb /opt/minio/mnt/data1 defaults 0 0
/dev/sdc /opt/minio/mnt/data2 defaults 0 0
/dev/sdd /opt/minio/mnt/data3 defaults 0 0
/dev/sde /opt/minio/mnt/data4 defaults 0 0
EOF
```

#最新版minio，非独占分区时的errer log

```log
Unable to use the drive http://192.168.106.55:9000/opt/minio/mnt/data1: drive is part of root drive, will not be used
Unable to use the drive http://192.168.106.55:9000/opt/minio/mnt/data2: drive is part of root drive, will not be used
Unable to use the drive http://192.168.106.55:9000/opt/minio/mnt/data3: drive is part of root drive, will not be used
Unable to use the drive http://192.168.106.55:9000/opt/minio/mnt/data4: drive is part of root drive, will not be used

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
Error: Drive http://192.168.106.55:9000/opt/minio/mnt/data2 returned an unexpected error: m
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

nohup MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=Supwisdom@321 /opt/minio /bin/minio server   --console-address=":9001" http://192.168.106.{52...55}/opt/minio/mnt/data{1...4} > /opt/minio/log/minio.log 2>&1 &
```



#启动脚本startup_minio_cluster.sh

```shell
cat > /opt/minio/startup_minio_cluster.sh <<'EOF'
#!/bin/bash
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=Supwisdom@321
MINIO_HOME=/opt/minio

${MINIO_HOME}/bin/minio server   --console-address=":9001" \
http://192.168.106.{52...55}/opt/minio/mnt/data{1...4} \
>${MINIO_HOME}/log/minio.log

EOF

chmod a+x /opt/minio/startup_minio_cluster.sh
```

**说明：**

**1、MINIO_ROOT_USER  minio部署后的访问用户名**

**2、MINIO_ROOT_PASSWORD minio部署后的访问密码**

**3、脚本中的IP地址要换成 minio集群服务器的地址**

修改后的启动脚本上传至服务器(所有集群服务器)目录/opt/minio

### 3.4、执行启动脚本

```shell
cd /opt/minio
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
WorkingDirectory=/opt/minio
ExecStart=/opt/minio/startup_minio_cluster.sh

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



















