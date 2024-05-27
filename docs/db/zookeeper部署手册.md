#  前置条件
## 服务器配置
| 节点       | 操作系统               | cpu核数 | 内存GB | 系统磁盘GB | 磁盘分区                                   |
| ---------- | ---------------------- | ------- | ------ | ---------- | ------------------------------------------ |
| zookeeper1 | KylinSec 3.5.2/arm64位 | 4       | 8      | 256        | /boot 1G<br/>swap 2048M<br/>/ 剩余所有空间 |
| zookeeper2 | KylinSec 3.5.2/arm64位 | 4       | 8      | 256        | /boot 1G<br/>swap 2048M<br/>/ 剩余所有空间 |
| zookeeper3 | KylinSec 3.5.2/arm64位 | 4       | 8      | 256        | /boot 1G<br/>swap 2048M<br/>/ 剩余所有空间 |

## 系统设置

### centos

1. 开放端口

   - 方案一：关闭防火墙

     ~~~sh
     systemctl stop firewalld && systemctl disable firewalld
     ~~~

   - 方案二：添加开放端口

     ~~~sh
     firewall-cmd --zone=public --add-port=2181/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=2888/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=3888/tcp --permanent &&\
     firewall-cmd --reload &&\
     firewall-cmd --list-ports
     ~~~

2. 关闭selinux

   ~~~sh
 #永久
   sed -i 's/enforcing/disabled/' /etc/selinux/config
#临时
   setenforce 0
   ~~~

3. 关闭swap

   ~~~sh
#临时
   swapoff -a
#永久，注释掉“/dev/mapper/centos-swap swap”
   sed -i '/swap/s/^/#/' /etc/fstab
   ~~~

4. 时间同步

   ~~~sh
   yum install ntpdate -y && ntpdate time.windows.com
   ~~~

5. 设置主机名**（特别注意：每个节点按需执行对应语句，不要三个都执行）**

   ~~~sh
   #zookeeper节点1
   hostnamectl set-hostname zk1
   #zookeeper节点2
   hostnamectl set-hostname zk2
   #zookeeper节点3
   hostnamectl set-hostname zk3
   ~~~

6. 修改host文件，所有服务器都执行以下命令

   ~~~sh
   echo "[zookeeper1节点内部IP] zk1" >> /etc/hosts &&\
   echo "[zookeeper2节点内部IP] zk2" >> /etc/hosts &&\
   echo "[zookeeper3节点内部IP] zk3" >> /etc/hosts
   ~~~

7. 新建/opt/software和/opt/module目录

   **当前安装用户需要有/opt目录下的读写权限，最好用root用户安装**

   ~~~sh
   mkdir -p /opt/software && mkdir -p /opt/module
   ~~~

8. 安装jdk

   ~~~sh
   #wget -O - http://p.supwisdom.com:8400/home/middleware/jdk/install-jdk1.8.0_111.sh | bash
   
   # 删除系统自带的jdk
   rpm -qa | grep jdk | xargs rpm -e --nodeps
   
   # 下载压缩文件并安装
   #mkdir -p /opt/module && wget -O - https://artifacts-supwisdom.oss-cn-shanghai.aliyuncs.com/dataassets/jdk/jdk-8u333-linux-x64.tar.gz | tar -xz -C /opt/module && ln -s /opt/module/jdk1.8.0_333  /opt/module/java
   
   #oracle jdk 1.8下载地址，需要登陆
   https://download.oracle.com/otn/java/jdk/8u411-b09/43d62d619be4e416215729597d70b8ac/jdk-8u411-linux-aarch64.tar.gz 
   
   tar -zxvf jdk-8u411-linux-aarch64.tar.gz -C /opt/module && ln -s /opt/module/jdk1.8.0_411  /opt/module/java
   
   #更新环境变量
   echo "export JAVA_HOME=/opt/module/java" >>  /etc/profile
   echo "export PATH=\$PATH:\$JAVA_HOME/bin" >>  /etc/profile
   
   # 刷新环境变量
   source /etc/profile
   
   java -version
   ~~~

### ubuntu

1. 开放端口

   - 方案一：关闭防火墙

     ~~~sh
     ufw disable && ufw status
     ~~~

   - 添加开放端口

     ~~~sh
     ufw allow 2181/tcp &&\
     ufw allow 2888/tcp &&\
     ufw allow 3888/tcp &&\
     ufw status
     ~~~

2. 关闭selinux：参考centos配置

3. 关闭swap：参考centos配置

4. 时间同步

   ~~~sh
   #查看当前时区：
   timedatectl
   #选择中国时区：
   timedatectl set-timezone Asia/Shanghai
   #验证时区设置：
   timedatectl
   #更新硬件时钟
   hwclock --systohc
   #设置24小时制
   echo "LC_TIME=en_DK.UTF-8" >> /etc/default/locale
   ~~~

5. 设置主机名**（特别注意：每个节点按需执行对应语句，不要三个都执行）**：参考centos配置

6. 修改host文件，所有服务器都执行以下命令：参考centos配置

7. 新建/opt/software和/opt/module目录：参考centos配置

8. 安装jdk：参考centos配置


# 安装zookeeper

**每台机器都要执行**

## 部署

1. 下载并解压

   ~~~bash
   #mkdir -p /opt/module && wget -O - https://artifacts-supwisdom.oss-cn-shanghai.aliyuncs.com/dataassets/zookeeper/apache-zookeeper-3.5.8-bin.tar.gz | tar -xz -C /opt/module
   
   #官网
   #https://zookeeper.apache.org/releases.html#download
   #老版本
   #https://archive.apache.org/dist/zookeeper/
   #wget https://archive.apache.org/dist/zookeeper/zookeeper-3.5.10/apache-zookeeper-3.5.10-bin.tar.gz
   
   mkdir -p /opt/module
   wget https://dlcdn.apache.org/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz
   tar -zxvf apache-zookeeper-3.8.4-bin.tar.gz -C /opt/module
   
   
   
   ~~~

2. 创建zookeeper软连接（兼容以后版本升级时不用修改配置文件）
    `新建zookeeper软连接,方便后面操作，之所以不重新命名为zookeeper，是为了后续能更方便的知道安装的版本`
   ~~~bash
   #ln -s /opt/module/apache-zookeeper-3.5.8-bin/ /opt/module/zookeeper
   
    ln -s /opt/module/apache-zookeeper-3.8.4-bin/ /opt/module/zookeeper
    ~~~
    
3. 配置环境变量

   ~~~bash
   echo 'export ZK_HOME=/opt/module/zookeeper' >> /etc/profile &&\
   echo 'export PATH=$PATH:$ZK_HOME/bin' >> /etc/profile &&\
   source /etc/profile
   ~~~

   

## 修改配置

**以下没有特殊说明，每台机器都要执行**

1. 复制zookeeper官方模板配置

   ~~~sh
   cp /opt/module/zookeeper/conf/zoo_sample.cfg	/opt/module/zookeeper/conf/zoo.cfg
   ~~~

2. 创建zookeeper数据存储目录

   ~~~sh
   mkdir -p /data/zookeeper
   ~~~

3. 修改配置文件

   ~~~bash
   #修改内容存储路径dataDir
   sed -i 's/\/tmp\/zookeeper/\/data\/zookeeper/' /opt/module/zookeeper/conf/zoo.cfg
   #配置集群信息
   echo 'server.1=zk1:2888:3888' >> /opt/module/zookeeper/conf/zoo.cfg
   echo 'server.2=zk2:2888:3888' >> /opt/module/zookeeper/conf/zoo.cfg
   echo 'server.3=zk3:2888:3888' >> /opt/module/zookeeper/conf/zoo.cfg
   ~~~

4. 创建myid文件**（特别注意：每个节点按需执行对应语句，不要三个都执行）**

   在上面第三步修改的配置文件中`dataDir `指定的目录下创建`myid`文件，这里的文件路径为`/data/zookeeper`

   **每个节点单独执行**

   ~~~bash
   #zookeeper节点1
   echo "1" > /data/zookeeper/myid
   #zookeeper节点2
   echo "2" > /data/zookeeper/myid
   #zookeeper节点3
   echo "3" > /data/zookeeper/myid
   ~~~

5. 启动

   **每个节点单独执行**

   ~~~sh
   zkServer.sh start
   ~~~

6. 验证是否启动成功

   - 方式一：**每个节点单独执行**

     ~~~bash
     zkServer.sh status
     ~~~
     _正确配置应该有2台follower，1台leader_ 

   - 方式二：**3台zookeeper机器中找一台机器验证**

     ```sh
     (echo) | telnet zk1 2181 ; \
     (echo) | telnet zk2 2181 ; \
     (echo) | telnet zk3 2181 ;
     ```

   - 方式三：**每个节点单独执行**

     ~~~sh
     jps
     ~~~
      _此方法只能证明zookeeper执行了启动命令，不代表执行成功，所以多执行几次，有可能会是假启动_ 
      _查看是否有QuorumPeerMain进程，存在则成功，不存在则失败_  


7. 停用

   **每个节点单独执行**

   ~~~sh
   zkServer.sh stop
   ~~~

## 设置开机自启动
**前提条件：必须先停掉zookeeper服务**

**每个节点单独执行**

```sh
zkServer.sh stop
```



- 添加守护进程

  vim /etc/systemd/system/zookeeper.service

方式一
  ~~~properties
[Unit]
Description=zookeeper server
Requires=network.target remote-fs.target
After=network.target remote-fs.target
  
[Service]
Type=forking
ExecStart=/bin/sh -c 'source /etc/profile && zkServer.sh start'
ExecStop=zkServer.sh stop
Restart=on-failure
RestartSec=2s
[Install]
WantedBy=multi-user.target
  ~~~

方式二

~~~properties
[Unit]
Description=zookeeper server
Requires=network.target remote-fs.target
After=network.target remote-fs.target
    
[Service]
Type=forking
Environment="JAVA_HOME=/opt/module/java"
ExecStart=/opt/module/zookeeper/bin/zkServer.sh start
ExecStop=/opt/module/zookeeper/bin/zkServer.sh stop
Restart=on-failure
RestartSec=2s
[Install]
WantedBy=multi-user.target
~~~


- 重新加载配置

  ~~~sh
  systemctl daemon-reload
  ~~~

- 设置zookeeper开启启动

  ```sh
  systemctl enable zookeeper
  ```

- 启动zookeeper

  ~~~sh
  systemctl start zookeeper
  ~~~

- 查看zookeeper启动状态

  ~~~sh
  systemctl status zookeeper
  ~~~

- 停止zookeeper

  ```sh
  systemctl stop zookeeper
  ```

**注意：**
通过此方法设置开机启动后，不能再通过`zkServer.sh stop`停止zookeeper，只能通过systemctl stop zookeeper
除非注释或删除`/etc/systemd/system/zookeeper.service`中的`Restart=on-failure`参数