#  前置条件
## 服务器配置

建议5台，也可以3台

| 节点   | 操作系统               | cpu核数 | 内存GB | 系统磁盘GB | 磁盘分区                                   |
| ------ | ---------------------- | ------- | ------ | ---------- | ------------------------------------------ |
| kafka1 | KylinSec 3.5.2/arm64位 | 16      | 32     | 512        | /boot 1G<br/>swap 8192M<br/>/ 剩余所有空间 |
| kafka2 | KylinSec 3.5.2/arm64位 | 16      | 32     | 512        | /boot 1G<br/>swap 8192M<br/>/ 剩余所有空间 |
| kafka3 | KylinSec 3.5.2/arm64位 | 16      | 32     | 512        | /boot 1G<br/>swap 8192M<br/>/ 剩余所有空间 |
| kafka4 | KylinSec 3.5.2/arm64位 | 16      | 32     | 512        | /boot 1G<br/>swap 8192M<br/>/ 剩余所有空间 |
| kafka5 | KylinSec 3.5.2/arm64位 | 16      | 32     | 512        | /boot 1G<br/>swap 8192M<br/>/ 剩余所有空间 |

## 系统设置

### KylinSec 3.5.2/arm64位

1. 开放端口

   - 方案一：关闭防火墙

     ~~~sh
     systemctl stop firewalld && systemctl disable firewalld
     ~~~

   - 方案二：添加开放端口

     ~~~sh
     firewall-cmd --zone=public --add-port=9090/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=9092/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=9093/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=9094/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=9095/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=9096/tcp --permanent &&\
     firewall-cmd --zone=public --add-port=9999/tcp --permanent &&\
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
   #kafka节点1
   hostnamectl set-hostname kafka1
   #kafka节点2
   hostnamectl set-hostname kafka2
   #kafka节点3
   hostnamectl set-hostname kafka3
   #kafka节点4
   hostnamectl set-hostname kafka4
   #kafka节点5
   hostnamectl set-hostname kafka5
   ~~~

6. 修改host文件，所有服务器都执行以下命令

   ~~~sh
   echo "[kafka1节点内部IP] kafka1" >> /etc/hosts &&\
   echo "[kafka2节点内部IP] kafka2" >> /etc/hosts &&\
   echo "[kafka3节点内部IP] kafka3" >> /etc/hosts &&\
   echo "[kafka4节点内部IP] kafka4" >> /etc/hosts &&\
   echo "[kafka5节点内部IP] kafka5" >> /etc/hosts
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
     ufw allow 9090/tcp &&\
     ufw allow 9092/tcp &&\
     ufw allow 9093/tcp &&\
     ufw allow 9094/tcp &&\
     ufw allow 9095/tcp &&\
     ufw allow 9096/tcp &&\
     ufw allow 9999/tcp &&\
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

8. 安装jdk：参考KylinSec 3.5.2/arm64位配置

   

# 安装kafka

**每台机器都要执行**

## 部署

1. 下载并解压

   ~~~sh
   #mkdir -p /opt/module && wget -O - https://artifacts-supwisdom.oss-cn-shanghai.aliyuncs.com/dataassets/kafka/kafka_2.13-3.2.0.tgz | tar -xz -C /opt/module
   
   mkdir -p /opt/module && wget -O - https://archive.apache.org/dist/kafka/3.2.0/kafka_2.13-3.2.0.tgz | tar -xz -C /opt/module
   
   #tar -zxvf kafka_2.13-3.2.0.tgz -C /opt/module
   ~~~

2. 创建kafka软连接（兼容以后版本升级时不用修改配置文件）

   `新建kafka软连接,方便后面操作，之所以不重新命名kafka_2.13-3.2.0为kafka，是为了后续能更方便的知道安装的版本`

   ~~~sh
   ln -s /opt/module/kafka_2.13-3.2.0/ /opt/module/kafka
   ~~~

3. 配置环境变量

   ~~~sh
   echo 'export KAFKA_HOME=/opt/module/kafka' >> /etc/profile &&\
   echo 'export PATH=$PATH:$KAFKA_HOME/bin' >> /etc/profile &&\
   source /etc/profile
   ~~~

   

## kraft 模式配置

**以下没有特殊说明，每台机器都要执行**

1. 创建kafka数据存储目录

   ~~~sh
   #kafka1节点1
   mkdir -p /data/kafka-kraft-logs
   #kafka2节点2
   mkdir -p /data/kafka-kraft-logs
   #kafka3节点3
   mkdir -p /data/kafka-kraft-logs
   #kafka4节点4
   mkdir -p /data/kafka-kraft-logs
   #kafka5节点5
   mkdir -p /data/kafka-kraft-logs
   ~~~

2. 修改配置文件

   vim /opt/module/kafka/config/kraft/server.properties

   修改以下需要修改配置项	**注意：**有对应指就直接修改，没有对应指就打开注释或者直接新增一行

   以下以16核32G配置为例

   ~~~sh
   #kafka1节点序号写1，kafka2节点序号写2，以此类推
   node.id=[序号]
   controller.quorum.voters=1@kafka1:9093,2@kafka2:9093,3@kafka3:9093,4@kafka4:9093,5@kafka5:9093
   
    #将localhost修改为能访问本机的内外或外网IP，内网一般就是本机的IP
   #advertised.listeners=PLAINTEXT://localhost:9092
   advertised.listeners=PLAINTEXT://10.1.1.7:9092
   
   #参考：cpu个数或者[CPU核数]/2
   num.network.threads=8
   
   #参考：[CPU核数]
   num.io.threads=16
   #数据存储路径
   log.dirs=/data/kafka-kraft-logs
   
   #参考：默认每个主题的分区数，建议填写实际kafka服务器数量，3台写3,5台写5，以此类推
   num.partitions=5
   
   num.recovery.threads.per.data.dir=1
   
   # 默认每个主题的副本数,新增属性
   default.replication.factor=3   
   
   offsets.topic.replication.factor=3
   transaction.state.log.replication.factor=3
   transaction.state.log.min.isr=3
   
   
   #数据保留7天，单位小时
   log.retention.hours=168
   #允许删除主题，新增属性
   delete.topic.enable=true 
   ~~~

   #kafka1

   ```yaml
   # cat server.properties |grep -v ^#|grep -v ^$
   process.roles=broker,controller
   node.id=1
   controller.quorum.voters=1@k8s01-nfs:9093,2@harbor-mongo-minio:9093,3@db:9093
   listeners=PLAINTEXT://:9092,CONTROLLER://:9093
   inter.broker.listener.name=PLAINTEXT
   advertised.listeners=PLAINTEXT://192.168.106.52:9092
   controller.listener.names=CONTROLLER
   listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
   num.network.threads=2
   num.io.threads=4
   socket.send.buffer.bytes=102400
   socket.receive.buffer.bytes=102400
   socket.request.max.bytes=104857600
   log.dirs=/data/kafka-kraft-logs
   num.partitions=3
   num.recovery.threads.per.data.dir=1
   default.replication.factor=3
   offsets.topic.replication.factor=3
   transaction.state.log.replication.factor=3
   transaction.state.log.min.isr=3
   log.retention.hours=168
   log.segment.bytes=1073741824
   log.retention.check.interval.ms=300000
   delete.topic.enable=true
   ```

   #kafka2

   ```yaml
   # cat server.properties |grep -v ^#|grep -v ^$
   process.roles=broker,controller
   node.id=2
   controller.quorum.voters=1@k8s01-nfs:9093,2@harbor-mongo-minio:9093,3@db:9093
   listeners=PLAINTEXT://:9092,CONTROLLER://:9093
   inter.broker.listener.name=PLAINTEXT
   advertised.listeners=PLAINTEXT://192.168.106.53:9092
   controller.listener.names=CONTROLLER
   listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
   num.network.threads=2
   num.io.threads=4
   socket.send.buffer.bytes=102400
   socket.receive.buffer.bytes=102400
   socket.request.max.bytes=104857600
   log.dirs=/data/kafka-kraft-logs
   num.partitions=3
   num.recovery.threads.per.data.dir=1
   default.replication.factor=3 
   offsets.topic.replication.factor=3
   transaction.state.log.replication.factor=3
   transaction.state.log.min.isr=3
   log.retention.hours=168
   log.segment.bytes=1073741824
   log.retention.check.interval.ms=300000
   delete.topic.enable=true
   ```

   #kafka3

   ```yaml
   # cat server.properties |grep -v ^#|grep -v ^$
   process.roles=broker,controller
   node.id=3
   controller.quorum.voters=1@k8s01-nfs:9093,2@harbor-mongo-minio:9093,3@db:9093
   listeners=PLAINTEXT://:9092,CONTROLLER://:9093
   inter.broker.listener.name=PLAINTEXT
   advertised.listeners=PLAINTEXT://192.168.106.57:9092
   controller.listener.names=CONTROLLER
   listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
   num.network.threads=8
   num.io.threads=16
   socket.send.buffer.bytes=102400
   socket.receive.buffer.bytes=102400
   socket.request.max.bytes=104857600
   log.dirs=/data/kafka-kraft-logs
   num.partitions=3
   num.recovery.threads.per.data.dir=1
   default.replication.factor=3 
   offsets.topic.replication.factor=3
   transaction.state.log.replication.factor=3
   transaction.state.log.min.isr=3
   log.retention.hours=168
   log.segment.bytes=1073741824
   log.retention.check.interval.ms=300000
   delete.topic.enable=true
   ```

   

3. 初始化kafka

   选取其中一台服务器执行以下命令：

   ~~~bash
   # 生成存储目录唯一 ID
   kafka-storage.sh random-uuid
   ~~~

   #如果报错

   ```bash
   # kafka-storage.sh random-uuid
   Error: VM option 'UseG1GC' is experimental and must be enabled via -XX:+UnlockExperimentalVMOptions.
   Error: Could not create the Java Virtual Machine.
   Error: A fatal exception has occurred. Program will exit.
   ```

   #查看kafka-storage.sh，发现内容

   ```log
   exec $(dirname $0)/kafka-run-class.sh kafka.tools.StorageTool "$@"
   ```

   

   #编辑/opt/module/kafka/bin/kafka-run-class.sh，找到`KAFKA_JVM_PERFORMANCE_OPTS`一行，在`-XX:+UseG1GC`的前面添加`-XX:+UnlockExperimentalVMOptions`

   #原来的内容

   ```bash
   if [ -z "$KAFKA_JVM_PERFORMANCE_OPTS" ]; then
     KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:MaxInlineLevel=15 -Djava.awt.headless=true"
   fi
   ```

   #修改为以下内容---每个节点都要修改

   ```bash
   if [ -z "$KAFKA_JVM_PERFORMANCE_OPTS" ]; then
     KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:MaxInlineLevel=15 -Djava.awt.headless=true"
   fi
   ```

   

   #再次执行---在某一个节点上执行

   ```bash
   kafka-storage.sh random-uuid
   ```

   ```log
   # kafka-storage.sh random-uuid
   RdfGEdR6RpStcG7vdlJF2Q
   ```

   根据上面命令生成的uuid值，对所有机子初始化

   **每个节点单独执行**，[uuid]替换为上面命令生成的uuid的值

   ~~~sh
   #kafka-storage.sh format -t [uuid] -c $KAFKA_HOME/config/kraft/server.properties
   
   kafka-storage.sh format -t RdfGEdR6RpStcG7vdlJF2Q -c $KAFKA_HOME/config/kraft/server.properties
   ~~~

4. 启动

   **每个节点单独执行**

   ~~~sh
   kafka-server-start.sh -daemon $KAFKA_HOME/config/kraft/server.properties
   ~~~

5. 验证是否启动成功

   启动

   - 方式一：**随便找一台机器验证**

     ~~~sh
     kafka-topics.sh --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092,kafka4:9092,kafka5:9092 --list
     
     #kafka-topics.sh --bootstrap-server k8s01-nfs:9092,harbor-mongo-minio:9092,db:9092 --list
     #kafka-topics.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --list
     ~~~

   - 方式二：**随便找一台机器验证**

     ```sh
     (echo) | telnet kafka1 9092 ; \
     (echo) | telnet kafka2 9092 ; \
     (echo) | telnet kafka3 9092 ; \
     (echo) | telnet kafka4 9092 ; \
     (echo) | telnet kafka5 9092
     ```

   - 方式三：**每个节点单独执行**

     ~~~sh
     jps
     ~~~
     
     *此方法只能证明kafka执行了启动命令，不代表执行成功，所以多执行几次，有可能会是假启动*
     *查看是否有kafka进程，存在则成功，不存在则失败*
     
   - 方式四：**使用工具**
   #官网
   ```yaml
   https://www.kafkatool.com/download.html
   
   Cluster name: arm-kafka
   Bootstrap Server:192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092
   Kafka Cluster version: 3.2
   ```

   - 方式五：**生产、消费测试**
```bash
kafka-topics.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --list

kafka-topics.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --create --topic test --partitions 3 --replication-factor 3

kafka-topics.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --create --topic my_topic --partitions 3 --replication-factor 2

kafka-topics.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --topic my_topic --describe

# kafka-topics.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --topic test --describe
Topic: test     TopicId: tTZZPbDASbiHbf3iuHoOqA PartitionCount: 3       ReplicationFactor: 3       Configs: segment.bytes=1073741824
        Topic: test     Partition: 0    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3
        Topic: test     Partition: 1    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1
        Topic: test     Partition: 2    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2

# kafka-topics.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --topic my_topic --describe
Topic: my_topic TopicId: xUZTnDU2Rk2NfXbQBWcUkA PartitionCount: 3       ReplicationFactor: 2       Configs: segment.bytes=1073741824
        Topic: my_topic Partition: 0    Leader: 3       Replicas: 3,1   Isr: 3,1
        Topic: my_topic Partition: 1    Leader: 1       Replicas: 1,2   Isr: 1,2
        Topic: my_topic Partition: 2    Leader: 2       Replicas: 2,3   Isr: 2,3

#kafka-console-producer.sh --broker-list 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --topic test

kafka-console-producer.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --topic test

kafka-console-consumer.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --topic test --from-beginning

kafka-consumer-groups.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --list

kafka-consumer-groups.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --group console-consumer-9093 --describe

# kafka-consumer-groups.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --list
console-consumer-9093

# kafka-consumer-groups.sh --bootstrap-server 192.168.106.52:9092,192.168.106.53:9092,192.168.106.57:9092 --group console-consumer-9093 --describe

GROUP                 TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID                                           HOST            CLIENT-ID
console-consumer-9093 test            0          -               3               -               console-consumer-caa2504e-9d0b-424a-a640-ef77d8e97f8e /192.168.106.57 console-consumer
console-consumer-9093 test            1          -               4               -               console-consumer-caa2504e-9d0b-424a-a640-ef77d8e97f8e /192.168.106.57 console-consumer
console-consumer-9093 test            2          -               1               -               console-consumer-caa2504e-9d0b-424a-a640-ef77d8e97f8e /192.168.106.57 console-consumer
```
6. 停用

   **每个节点单独执行**

   ~~~sh
   kafka-server-stop.sh
   ~~~

## 设置开机自启动
**前提条件：必须先停掉kafka服务**

**每个节点单独执行**

```sh
kafka-server-stop.sh
```



- 添加守护进程

  vim /etc/systemd/system/kafka.service

方式一 
  ~~~properties
  [Unit]
  Description=kafka server
  Requires=network.target remote-fs.target
  After=network.target remote-fs.target
  
  [Service]
  Type=forking
  ExecStart=/bin/sh -c 'source /etc/profile && kafka-server-start.sh -daemon $KAFKA_HOME/config/kraft/server.properties'
  ExecStop=kafka-server-stop.sh
  Restart=on-failure
  RestartSec=2s
  [Install]
  WantedBy=multi-user.target
  ~~~

方式二
  ~~~properties
[Unit]
Description=kafka server
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=forking
Environment="JAVA_HOME=/opt/module/java"
Environment="KAFKA_HOME=/opt/module/kafka"
ExecStart=/opt/module/kafka/bin/kafka-server-start.sh -daemon /opt/module/kafka/config/kraft/server.properties
ExecStop=/opt/module/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=2s
[Install]
WantedBy=multi-user.target

  ~~~

- 重新加载配置

  ~~~sh
  systemctl daemon-reload
  ~~~

- 设置kafka开启启动

  ```sh
  systemctl enable kafka
  ```

- 启动kafka

  ~~~sh
  systemctl start kafka
  ~~~

- 查看kafka启动状态

  ~~~sh
  systemctl status kafka
  ~~~

- 停止kafka

  ```sh
  systemctl stop kafka
  ```

**注意：**
通过此方法设置开机启动后，不能再通过`kafka-server-stop.sh`停止kafka，只能通过systemctl stop kafka
除非注释或删除`/etc/systemd/system/kafka.service`中的`Restart=on-failure`参数