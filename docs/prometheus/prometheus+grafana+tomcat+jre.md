****此文档提供安装prometheus(基于v2.45.0)+grafana+的安装****

****

#安装开始前，请注意OS系统的优化、服务器内存大小、磁盘分区大小及最大分区里

## 服务器资源

#建议

```
vm: 16核/32G 

OS:Anolis OS 7.9(3.10.0-1160)

磁盘LVM管理，／为最大分区
```

## 部署过程

### 一、系统优化

#### 1、Hostname修改

#hostname命名建议规范

```bash
hostnamectl set-hostname monitor

ifconfig

echo "10.96.4.97 monitor" >> /etc/hosts

hostnamectl status

# hostnamectl status
   Static hostname: monitor
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 887b84ea483444a99e710fbceca51559
           Boot ID: 713ce2b4b50040df9e93424f8685917e
    Virtualization: vmware
  Operating System: Anolis OS 7.9
            Kernel: Linux 3.10.0-1160.an7.x86_64
      Architecture: x86-64

```

#### 2、关闭防火墙和selinux

```bash
systemctl stop firewalld
systemctl disable firewalld

setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

#### 3、修改centos源文件---龙蜥暂不修改

```bash
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

yum clean all && yum makecache all
```

#### 4、开始时间同步及修改东8区

```bash
yum install -y ntp
systemctl start ntpd
system enable ntpd

vi /etc/ntp.conf
#注释下面4行
#server 0.centos.pool.ntp.org iburst
#server 1.centos.pool.ntp.org iburst
#server 2.centos.pool.ntp.org iburst
#server 3.centos.pool.ntp.org iburst

#替换成中国时间服务器
#http://www.pool.ntp.org/zone/cn
server 0.cn.pool.ntp.org
server 1.cn.pool.ntp.org
server 2.cn.pool.ntp.org
server 3.cn.pool.ntp.org

date -R
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
```

#### 5、语言修改为utf8

```bash
sudo echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```

#### 6、内核模块调优

##### 1)内核模块

```bash
echo "
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_interval=60
net.ipv4.neigh.default.gc_stale_time=120

# 参考 https://github.com/prometheus/node_exporter#disabled-by-default
kernel.perf_event_paranoid=-1

#sysctls for k8s node config
net.ipv4.tcp_slow_start_after_idle=0
net.core.rmem_max=16777216
fs.inotify.max_user_watches=524288
kernel.softlockup_all_cpu_backtrace=1

kernel.softlockup_panic=0

kernel.watchdog_thresh=30
fs.file-max=2097152
fs.inotify.max_user_instances=8192
fs.inotify.max_queued_events=16384
vm.max_map_count=262144
fs.may_detach_mounts=1
net.core.netdev_max_backlog=16384
net.ipv4.tcp_wmem=4096 12582912 16777216
net.core.wmem_max=16777216
net.core.somaxconn=32768
net.ipv4.ip_forward=1
net.ipv4.tcp_max_syn_backlog=8096
net.ipv4.tcp_rmem=4096 12582912 16777216

###如果学校开启IPv6，则必须为0
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

kernel.yama.ptrace_scope=0
vm.swappiness=0

# 可以控制core文件的文件名中是否添加pid作为扩展。
kernel.core_uses_pid=1

# Do not accept source routing
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0

# Promote secondary addresses when the primary address is removed
net.ipv4.conf.default.promote_secondaries=1
net.ipv4.conf.all.promote_secondaries=1

# Enable hard and soft link protection
fs.protected_hardlinks=1
fs.protected_symlinks=1
# 源路由验证
# see details in https://help.aliyun.com/knowledge_detail/39428.html
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2
# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_synack_retries=2
kernel.sysrq=1
" >> /etc/sysctl.conf

sysctl -p
```

##### 2)open-files

```bash
sudo sed -i 's/4096/90000/g' /etc/security/limits.d/20-nproc.conf

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

### 二、在线安装prometheus

#### 1、创建 Prometheus 用户

```bash
useradd -m -s /bin/false prometheus
```

#### 2、创建配置目录

```bash
mkdir /etc/prometheus

mkdir /var/lib/prometheus

chown prometheus:prometheus /var/lib/prometheus/
```

#### 3、下载最新版的 prometheus

```
#下载地址：https://prometheus.io/download/
cd /root
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
```

#### 4、解压文件

```
tar -zxvf prometheus-2.45.0.linux-amd64.tar.gz

#复制 prometheus 和 promtool 到 /usr/local/bin 路径
cd prometheus-2.45.0.linux-amd64
cp prometheus  /usr/local/bin
cp promtool  /usr/local/bin

# 将 prometheus.yml 复制到 /etc/prometheus/ 路径
cp prometheus.yml /etc/prometheus/
```


#### 5、开放 Prometheus 端口

```bash
firewall-cmd --add-port=9090/tcp --permanent

firewall-cmd --reload
```

#### 6、创建 Prometheus 服务

```
# 创建服务文件，以便以服务方式运行 Prometheus

cat >> /etc/systemd/system/prometheus.service  <<EOF
[Unit]

Description=Prometheus Time Series Collection and Processing Server

Wants=network-online.target

After=network-online.target

 
[Service]

User=prometheus

Group=prometheus

Type=simple

ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    #--storage.tsdb.retention=15d --web.enable-lifecycle \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries


[Install]

WantedBy=multi-user.target
EOF
```

#### 7、启动服务

```bash
# 重新加载
systemctl daemon-reload

# 启动 Prometheus 服务
systemctl start prometheus

# 设置 Prometheus 开机启动
systemctl enable prometheus

# 验证 Prometheu s正在运行
systemctl status prometheus

# 查看端口 9090
netstat -tunlp |grep 9090
```

#### 8、浏览页面

#在浏览器打开 http://server-ip:9090，将server-ip 改为自己服务器的IP地址即可。本例为http://10.96.4.97:9090 

![image-20230927113207897](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230927113207897.png)

### 三、安装 Node Exporter

#ode exoorter 用于收集 linux 系统的 CPU、内存、网络等信息

#### 1、创建用户

```bash
useradd -m -s /bin/false node_exporter
```

#### 2、下载修新版的程序

```mysql
#官网地址：https://github.com/prometheus/node_exporter/releases
yum install -y wget
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
```

#### 3、解压文件

```bash
tar -zxvf node_exporter-1.6.1.linux-amd64.tar.gz

cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

#### 4、以服务方式运行

```bash
#创建sevice配置文件

cat >> /etc/systemd/system/node_exporter.service <<EOF
[Unit]

Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target
 

[Service]

User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

 
[Install]

WantedBy=multi-user.target
EOF

```

#### 5、启动服务

```bash
# 重新加载
systemctl daemon-reload

# 启动 node_exporter 服务
systemctl start node_exporter

# 设置 node_exporter 开机启动
systemctl enable node_exporter

# 验证 node_exporter正在运行
systemctl status node_exporter

# 查看端口 9100
netstat -tunlp |grep 9100
```



#### 6、开放9100端口

```bash
#如果防火墙为关闭状态，怎不用设置
firewall-cmd --add-port=9100/tcp  --permanent
firewall-cmd --reload
```

#### 7、将node_exporter加入prometheus配置

```bash
#编辑配置文件，添加以下内容，注意与上面内容的对齐
cat >> /etc/prometheus/prometheus.yml <<EOF

  - job_name: 'node_exporter'

    static_configs:

      - targets: ['localhost:9100']
EOF

```

#完整的prometheus.yml文件

```yaml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus"

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ["localhost:9090"]

  - job_name: 'node_exporter'

    static_configs:

      - targets: ['localhost:9100']

```

#后续添加了其他服务器节点：

```bash
202.119.114.61
202.119.114.62
202.119.114.63
202.119.114.64
202.119.114.65
202.119.114.137
202.119.114.136
202.119.115.14
```

#promethues服务器修改配置文件

```bash
cat >> /etc/prometheus/prometheus.yml <<EOF

  - job_name: 'node_exporter_61'

    static_configs:

      - targets: ['202.119.114.61:9100']
	  
  - job_name: 'node_exporter_62'

    static_configs:

      - targets: ['202.119.114.62:9100']	
	  
  - job_name: 'node_exporter_63'

    static_configs:

      - targets: ['202.119.114.63:9100']
	  
  - job_name: 'node_exporter_64'

    static_configs:

      - targets: ['202.119.114.64:9100']	

  - job_name: 'node_exporter_65'

    static_configs:

      - targets: ['202.119.114.65:9100']
	  
  - job_name: 'node_exporter_136'

    static_configs:

      - targets: ['202.119.114.136:9100']	  

  - job_name: 'node_exporter_137'

    static_configs:

      - targets: ['202.119.114.137:9100']
	  
  - job_name: 'node_exporter_115_14'

    static_configs:

      - targets: ['202.119.115.14:9100']		  
EOF

systemctl restart prometheus
```



#### 8、重启prometheus服务

```bash
systemctl restart prometheus
```

#### 9、浏览页面

#在浏览器打开 http://server-ip:9100/metrics，将server-ip 改为自己服务器的IP地址即可。本例为http://10.96.4.97:9100/metrics 

![image-20230927115805881](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230927115805881.png)



### 四、安装 Grafana

#### 1、下新版的程序

```
#下载地址：https://grafana.com/grafana/download?pg=get&plcmt=selfmanaged-box1-cta1

# 这里选择centos
wget https://dl.grafana.com/enterprise/release/grafana-enterprise-10.1.2-1.x86_64.rpm
yum install -y ./grafana-enterprise-10.1.2-1.x86_64.rpm
```

#### 2、启动grafana服务

```bash
systemctl start grafana-server
systemctl enable grafana-server

systemctl status grafana-server
```

#### 3、开放3000端口

```bash
firewall-cmd --add-port=3000/tcp  --permanent
firewall-cmd --reload
```

#### 4、浏览页面

#在浏览器打开 http://server-ip:3000，将server-ip 改为自己服务器的IP地址即可。本例为http://10.96.4.97:3000

#默认的账户密码是：admin/admin，可以再次更改为admin密码

### 五、配置 Prometheus

#### 1、进入grafana后，添加数据源

![image-20230927184910363](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230927184910363.png)



#点击promethues

![image-20230927185032523](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230927185032523.png)



#填入prometheus地址

![image-20230927185402279](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230927185402279.png)



#在这个页面，拖到最下面，有个：Save & test

![image-20230927185319284](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230927185319284.png)



#### 2、配置显示模板

```
#总的官网Dashboard：

https://grafana.com/grafana/dashboards/
```

#本次配置基于Linux监控模板的

![image-20230928091803765](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230928091803765.png)



![image-20230928091844181](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230928091844181.png)



![image-20230928092205795](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230928092205795.png)



#配置后的显示：

![image-20230928092441888](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20230928092441888.png)



### 六、对tomcat的监控---部署jmx_prometheus_javaagent

#### 1、下载新版程序

```bash
#官网https://prometheus.io/download/  --->点击：Exporters and integrations ---> 点击：JMX exporter (official)
#官网https://github.com/prometheus/jmx_exporter

#这里有两种方式：Running the Java Agent 和 Running the Standalone HTTP Server
#本次采用Running the Java Agent

#查找最新版https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/

#下载到tomcat的bin目录下
#服务器IP202.119.114.62
cd /opt/platform-portal/tomcat-platform-portal/bin
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar
```

#### 2、添加config.yaml

```bash
#添加到tomcat的bin目录下
cd /opt/platform-portal/tomcat-platform-portal/bin
vi config.yaml
#可以采用最小配置文件：
---
rules:
- pattern: ".*"
---

#也可以去下载实例文件https://github.com/prometheus/jmx_exporter/blob/main/example_configs/tomcat.yml
```

```yaml
# https://grafana.com/grafana/dashboards/8704-tomcat-dashboard/
---   
lowercaseOutputLabelNames: true
lowercaseOutputName: true
whitelistObjectNames: ["java.lang:type=OperatingSystem", "Catalina:*"]
blacklistObjectNames: []
rules:
  - pattern: 'Catalina<type=Server><>serverInfo: (.+)'
    name: tomcat_serverinfo
    value: 1
    labels:
      serverInfo: "$1"
    type: COUNTER
  - pattern: 'Catalina<type=GlobalRequestProcessor, name=\"(\w+-\w+)-(\d+)\"><>(\w+):'
    name: tomcat_$3_total
    labels:
      port: "$2"
      protocol: "$1"
    help: Tomcat global $3
    type: COUNTER
  - pattern: 'Catalina<j2eeType=Servlet, WebModule=//([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), name=([-a-zA-Z0-9+/$%~_-|!.]*), J2EEApplication=none, J2EEServer=none><>(requestCount|processingTime|errorCount):'
    name: tomcat_servlet_$3_total
    labels:
      module: "$1"
      servlet: "$2"
    help: Tomcat servlet $3 total
    type: COUNTER
  - pattern: 'Catalina<type=ThreadPool, name="(\w+-\w+)-(\d+)"><>(currentThreadCount|currentThreadsBusy|keepAliveCount|connectionCount|acceptCount|acceptorThreadCount|pollerThreadCount|maxThreads|minSpareThreads):'
    name: tomcat_threadpool_$3
    labels:
      port: "$2"
      protocol: "$1"
    help: Tomcat threadpool $3
    type: GAUGE
  - pattern: 'Catalina<type=Manager, host=([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), context=([-a-zA-Z0-9+/$%~_-|!.]*)><>(processingTime|sessionCounter|rejectedSessions|expiredSessions):'
    name: tomcat_session_$3_total
    labels:
      context: "$2"
      host: "$1"
    help: Tomcat session $3 total
    type: COUNTER   
```

#### 4、修改tomcat的配置文件

```bash
cd /opt/platform-portal/tomcat-platform-portal/bin
vi catalina.sh

修改JAVA_OPTS="$JAVA_OPTS -Djava.protocol.handler.pkgs=org.apache.catalina.webresources" --->
JAVA_OPTS="$JAVA_OPTS -Djava.protocol.handler.pkgs=org.apache.catalina.webresources -javaagent:/opt/platform-portal/tomcat-platform-portal/bin/jmx_prometheus_javaagent-0.20.0.jar=30018:/opt/platform-portal/tomcat-platform-portal/bin/config.yaml"

```

#### 5、重启tomcat

```bash
 ps -ef|grep tomcat
 kill -9 PIDxxx
 
 cd /opt/platform-portal/tomcat-platform-portal/bin
 ./startup.sh
 
 tail -f ../logs/catalina.out
```

#### 6、开放30018端口

```bash
firewall-cmd --add-port=30018/tcp  --permanent
firewall-cmd --reload

#firewall-cmd --remove-port=30018/tcp  --permanent
```



#### 7、查看jmx exporter采集的数据

#在浏览器打开 http://server-ip:30018/metrics，将server-ip 改为自己tomcat服务器的IP地址即可。本例为http://202.119.114.62:30018/metrics

#### 8、配置prometheus采集jmx exporter数据

```bash
cd /etc/prometheus/
vi  prometheus.yml
#在scrape_configs:的下面添加以下内容：
  - job_name: 'tomcat_62_web1'
    static_configs:
      - targets: ['202.119.114.62:30018']  
```

#### 9、重启prometheus服务

```bash
systemctl restart prometheus
```

#### 10、查看prometheus的监控数据

#查看prometheus与jmx exporter的连接是否正常

```
http://10.96.4.97:9090/targets?search=
查找下tomcat_62_web1

http://10.96.4.97:9090/targets?search=&scrapePool=tomcat_62_web1
```

![image-20231007112242568](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007112242568.png)

#在prometheus里查询jmx exporter监控的数据

```
http://10.96.4.97:9090/
查看graph

http://10.96.4.97:9090/graph?g0.expr=&g0.tab=1&g0.stacked=0&g0.show_exemplars=0&g0.range_input=1h

搜索jmx_exporter_build_info
```

![image-20231007112718719](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007112718719.png)

#### 11、配置grafana的tomcat显示模板

```
#总的官网Dashboard：
https://grafana.com/grafana/dashboards/

#本次基于tomcat的模板
https://grafana.com/grafana/dashboards/8704-tomcat-dashboard/
```

#打开grafana的dashboard网页，点击New下面的Import

![image-20231007110632965](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007110632965.png)



#输入tomcat的模板数字：8704后，点击：Load

![image-20231007111124459](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007111124459.png)



#修改Name和Job，Job中的内容必须跟上一步中的prometheus的job_name相同，然后点击Import

![image-20231007111508055](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007111508055.png)



#点击tomcat_62_web1

![image-20231007111825470](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007111825470.png)



#查看页面展示

![image-20231007111919876](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007111919876.png)



#### 12、针对部分显示NaN内容，调整展示页面

#编辑NaN显示项的内容

![image-20231007151333972](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007151333972.png)



![image-20231007151450877](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007151450877.png)



#首先可以将查询指标tomcat_serverinfo在prometheus网页查询是否存在

![image-20231007151549095](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007151549095.png)

#更进一步，去服务器的指标页面去查询

![image-20231007151727617](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007151727617.png)



![image-20231007152045977](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007152045977.png)



#有些可能是缺少指标或者计算错误，需要改正查询公式，根据现场具体情况进行调整



### 七、对jar的监控---类似于tomcat---部署jmx_prometheus_javaagent
#### 1、下载新版程序

```bash
#官网https://prometheus.io/download/  --->点击：Exporters and integrations ---> 点击：JMX exporter (official)
#官网https://github.com/prometheus/jmx_exporter

#这里有两种方式：Running the Java Agent 和 Running the Standalone HTTP Server
#本次采用Running the Java Agent

#查找最新版https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/

#服务器IP202.119.114.136

#首先找到需要监控的jar的位置
ps -ef|grep java
ls -l /proc/pidXXX

#或者是看下开机启动的程序
cat /etc/rc.local
/opt/supwisdom/microservice/autoStartAll.sh

#进入该目录
cd /opt/supwisdom/microservice

ls

#拉取最新程序
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar

```

#### 2、添加config.yaml

```bash
#添加到微服务的目录下
cd /opt/supwisdom/microservice

cat >> config.yaml <<EOF
rules:
- pattern: ".*"
EOF
```

#### 4、修改jar的启动文件

```bash
cd /opt/supwisdom/microservice

cat autoStartAll.sh
......省略部分输出...
java -jar appportal-auth.jar

java -jar appportal-pc.jar
......省略部分输出...

#因为由多个jar同时运行，所以配置不同端口进行监控30020、30021：
java -javaagent:/opt/supwisdom/microservice/jmx_prometheus_javaagent-0.20.0.jar=30020:/opt/supwisdom/microservice/config.yaml -jar appportal-auth.jar

java -javaagent:/opt/supwisdom/microservice/jmx_prometheus_javaagent-0.20.0.jar=30021:/opt/supwisdom/microservice/config.yaml -jar appportal-pc.jar
```

#### 5、重启jar

```bash
 ps -ef|grep java
 kill -9 PIDxxx
 
 cd /opt/supwisdom/microservice
 ./autoStartAll.sh
```

#### 6、开放30018/30020/30021端口

```bash
firewall-cmd --add-port=30018/tcp  --permanent
firewall-cmd --add-port=30020/tcp  --permanent
firewall-cmd --add-port=30021/tcp  --permanent
firewall-cmd --reload

#
firewall-cmd --remove-port=30018/tcp  --permanent
firewall-cmd --remove-port=30020/tcp  --permanent
firewall-cmd --remove-port=30021/tcp  --permanent

firewall-cmd --remove-port=9100/tcp  --permanent

firewall-cmd --reload

firewall-cmd --list-all
```

#### 7、查看jmx exporter采集的数据

#在浏览器打开 http://server-ip:30018/metrics，将server-ip 改为自己tomcat服务器的IP地址即可。本例为http://202.119.114.136:30020/metrics

#和http://202.119.114.136:30021/metrics

#### 8、配置prometheus采集jmx exporter数据

```bash
cd /etc/prometheus/
vi  prometheus.yml
#因为在202.119.114.136上部署了tomcat(30018端口)、两个jar包(30020和30021端口)
#所以在scrape_configs:的下面添加以下内容：
#mob2

  - job_name: 'tomcat_136_mob2'
    static_configs:
      - targets: ['202.119.114.136:30018']  
  - job_name: 'jar_136_appportal_auth'
    static_configs:
      - targets: ['202.119.114.136:30020']  
  - job_name: 'jar_136_appportal_pc'
    static_configs:
      - targets: ['202.119.114.136:30021']  
```

#### 9、重启prometheus服务

```bash
systemctl restart prometheus
```

#### 10、查看prometheus的监控数据

#查看prometheus与jmx exporter的连接是否正常

```
http://10.96.4.97:9090/targets?search=
查找下tomcat_136_mob2、jar_136_appportal_auth、jar_136_appportal_pc
```

![image-20231007154249967](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007154249967.png)

#在prometheus里查询jmx exporter监控的数据

```
http://10.96.4.97:9090/
查看graph

http://10.96.4.97:9090/graph?g0.expr=&g0.tab=1&g0.stacked=0&g0.show_exemplars=0&g0.range_input=1h

搜索jmx_exporter_build_info
```

![image-20231007154421593](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007154421593.png)

#### 11、配置grafana的jvm显示模板

```
#总的官网Dashboard：
https://grafana.com/grafana/dashboards/

#本次基于jvm的模板
https://grafana.com/grafana/dashboards/8563-jvm-dashboard/
```

#打开grafana的dashboard网页，点击New下面的Import

![image-20231007110632965](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007110632965.png)



#输入jvm的模板数字：8563后，点击：Load

![image-20231007154719622](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007154719622.png)



#修改Name、uid和Job，可以三个内容都跟job_name相同，然后点击Import

#最终生成的114.163的三个展示页面：一个tomcat，两个jar

![image-20231007154852891](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007154852891.png)



#分别查看页面展示

![image-20231007155443551](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007155443551.png)



### 八、钉钉告警

#### 1、二进制部署 Alertmanager

```bash
#官网https://prometheus.io/download/
#https://github.com/prometheus/alertmanager/releases

wget https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz

tar -zxvf alertmanager-0.26.0.linux-amd64.tar.gz

mv alertmanager-0.26.0.linux-amd64 /usr/local/alertmanager
chown prometheus.prometheus /usr/local/alertmanager
```

#### 2、以服务方式运行alertmanager

```bash
#创建sevice配置文件

cat >> /etc/systemd/system/alertmanager.service <<EOF
[Unit]
Description=https://prometheus.io

[Service]
Type=simple
User=prometheus
Restart=on-failure
ExecStart=/usr/local/alertmanager/alertmanager --config.file=/usr/local/alertmanager/alertmanager.yml --storage.path=/usr/local/alertmanager/data/

[Install]
WantedBy=multi-user.target
EOF

```

#### 3、启动服务alertmanager

```bash
# 重新加载
systemctl daemon-reload

# 启动 alertmanager 服务
systemctl start alertmanager

# 设置 alertmanager 开机启动
systemctl enable alertmanager

# 验证 alertmanager正在运行
systemctl status alertmanager

# 查看端口 9093
netstat -tnulp|grep 9093
tcp6       0      0 :::9093                 :::*                    LISTEN      25773/alertmanager  

# 查看端口
netstat -tnulp|grep 909
tcp6       0      0 :::9093                 :::*                    LISTEN      25773/alertmanager  
tcp6       0      0 :::9094                 :::*                    LISTEN      25773/alertmanager  
tcp6       0      0 :::9090                 :::*                    LISTEN      8175/prometheus     
udp6       0      0 :::9094                 :::*                                25773/alertmanager 
```

#### 4、开放alertmanager端口

```bash
firewall-cmd --add-port=9093/tcp  --permanent
firewall-cmd --reload
```



#### 5、浏览页面

#在浏览器打开 http://server-ip:9093，将server-ip 改为自己服务器的IP地址即可。本例为http://10.96.4.97:9093

![image-20231007164013534](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007164013534.png)

#### 6、配置钉钉机器人

#打开钉钉的智能群助手，点击添加机器人

![image-20231007164255472](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007164255472.png)



#选择自定义机器人

![image-20231007164339978](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007164339978.png)



![image-20231007164402474](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007164402474.png)

#注意保存Webhook和加签的内容

![image-20231007164533747](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007164533747.png)



#### 7、安装钉钉服务

```bash
#https://github.com/timonwong/prometheus-webhook-dingtalk/releases

wget https://github.com/timonwong/prometheus-webhook-dingtalk/releases/download/v2.1.0/prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz

tar -zxvf prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz

mv prometheus-webhook-dingtalk-2.1.0.linux-amd64 /usr/local/prometheus_webhook_dingtalk
chown prometheus.prometheus /usr/local/prometheus_webhook_dingtalk
```



#### 8、编写dingtalk配置文件

```bash
cd /usr/local/prometheus_webhook_dingtalk

#根据config.example.yml和上面生成的机器人信息编写
cp config.example.yml config.yml
```

```yaml
#config.yml
## Request timeout
timeout: 5s

## Uncomment following line in order to write template from scratch (be careful!)
#no_builtin_template: true

## Customizable templates path
templates:
  - contrib/templates/legacy/dingtalk.tmpl

## You can also override default template using `default_message`
## The following example to use the 'legacy' template from v0.3.0
#default_message:
#  title: '{{ template "legacy.title" . }}'
#  text: '{{ template "legacy.content" . }}'

## Targets, previously was known as "profiles"
targets:
  webhook1:
    url: https://oapi.dingtalk.com/robot/send?access_token=0a32a2b4c053ac9b27ab5e050e7bb819a0674c543b3c738e6f6575be30d12507
    # secret for signature
    secret: SECc20ec234f114d58d7ef55b833b50eb8001ae3ddcfbc34779e0760cac28ba060f
  webhook_mention_all:
    url: https://oapi.dingtalk.com/robot/send?access_token=0a32a2b4c053ac9b27ab5e050e7bb819a0674c543b3c738e6f6575be30d12507
    secret: SECc20ec234f114d58d7ef55b833b50eb8001ae3ddcfbc34779e0760cac28ba060f
    mention:
      all: true
  webhook_mention_users:
    url: https://oapi.dingtalk.com/robot/send?access_token=0a32a2b4c053ac9b27ab5e050e7bb819a0674c543b3c738e6f6575be30d12507
    secret: SECc20ec234f114d58d7ef55b833b50eb8001ae3ddcfbc34779e0760cac28ba060f
    mention:
      mobiles: ['13xxxxxx17']


```

#模板文件contrib/templates/legacy/dingtalk.tmpl

```yaml
{{ define "__subject" }}
[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}]
{{ end }}
 
 
{{ define "__alert_list" }}{{ range . }}
---
{{ if .Labels.owner }}@{{ .Labels.owner }}{{ end }}
 
**告警主题**: {{ .Annotations.summary }}

**告警类型**: {{ .Labels.alertname }}
 
**告警级别**: {{ .Labels.severity }} 
 
**告警主机**: {{ .Labels.instance }} 
 
**告警信息**: {{ index .Annotations "description" }}
 
**告警时间**: {{ dateInZone "2006.01.02 15:04:05" (.StartsAt) "Asia/Shanghai" }}
{{ end }}{{ end }}
 
{{ define "__resolved_list" }}{{ range . }}
---
{{ if .Labels.owner }}@{{ .Labels.owner }}{{ end }}

**告警主题**: {{ .Annotations.summary }}

**告警类型**: {{ .Labels.alertname }} 
 
**告警级别**: {{ .Labels.severity }}
 
**告警主机**: {{ .Labels.instance }}
 
**告警信息**: {{ index .Annotations "description" }}
 
**告警时间**: {{ dateInZone "2006.01.02 15:04:05" (.StartsAt) "Asia/Shanghai" }}
 
**恢复时间**: {{ dateInZone "2006.01.02 15:04:05" (.EndsAt) "Asia/Shanghai" }}
{{ end }}{{ end }}
 
 
{{ define "default.title" }}
{{ template "__subject" . }}
{{ end }}
 
{{ define "default.content" }}
{{ if gt (len .Alerts.Firing) 0 }}
**====侦测到{{ .Alerts.Firing | len  }}个故障====**
{{ template "__alert_list" .Alerts.Firing }}
---
{{ end }}
 
{{ if gt (len .Alerts.Resolved) 0 }}
**====恢复{{ .Alerts.Resolved | len  }}个故障====**
{{ template "__resolved_list" .Alerts.Resolved }}
{{ end }}
{{ end }}
 
 
{{ define "ding.link.title" }}{{ template "default.title" . }}{{ end }}
{{ define "ding.link.content" }}{{ template "default.content" . }}{{ end }}
{{ template "default.title" . }}
{{ template "default.content" . }}
```



#### 9、以服务方式运行

```bash
#创建sevice配置文件

cat >> /etc/systemd/system/webhook_dingtalk.service <<EOF
[Unit]
Description=https://prometheus.io

[Service]
Type=simple
User=prometheus
Restart=on-failure
ExecStart=/usr/local/prometheus_webhook_dingtalk/prometheus-webhook-dingtalk --config.file=/usr/local/prometheus_webhook_dingtalk/config.yml --web.listen-address=:8060

[Install]
WantedBy=multi-user.target
EOF

```

#### 10、启动webhook_dingtalk服务

```bash
# 重新加载
systemctl daemon-reload

# 启动 webhook_dingtalk 服务
systemctl start webhook_dingtalk

# 设置 webhook_dingtalk 开机启动
systemctl enable webhook_dingtalk

# 验证 webhook_dingtalk 正在运行
systemctl status webhook_dingtalk

# 查看端口 8060
netstat -tunlp |grep 8060
tcp6       0      0 :::8060                 :::*                    LISTEN      26821/prometheus-webhook-dingtalk 

#查看服务运行情况
systemctl status webhook_dingtalk.service -l
● webhook_dingtalk.service - https://prometheus.io
   Loaded: loaded (/etc/systemd/system/webhook_dingtalk.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2023-10-07 17:14:33 CST; 1min 28s ago
 Main PID: 27896 (prometheus-webh)
    Tasks: 9
   CGroup: /system.slice/webhook_dingtalk.service
           └─27896 /usr/local/prometheus_webhook_dingtalk/prometheus-webhook-dingtalk --config.file=/usr/local/prometheus_webhook_dingtalk/config.yml --web.listen-address=:8060

Oct 07 17:14:33 monitor systemd[1]: Started https://prometheus.io.
Oct 07 17:14:33 monitor prometheus-webhook-dingtalk[27896]: ts=2023-10-07T09:14:33.593Z caller=main.go:59 level=info msg="Starting prometheus-webhook-dingtalk" version="(version=2.1.0, branch=HEAD, revision=8580d1395f59490682fb2798136266bdb3005ab4)"
Oct 07 17:14:33 monitor prometheus-webhook-dingtalk[27896]: ts=2023-10-07T09:14:33.593Z caller=main.go:60 level=info msg="Build context" (gogo1.18.1,userroot@177bd003ba4d,date20220421-08:19:05)=(MISSING)
Oct 07 17:14:33 monitor prometheus-webhook-dingtalk[27896]: ts=2023-10-07T09:14:33.594Z caller=coordinator.go:83 level=info component=configuration file=/usr/local/prometheus_webhook_dingtalk/config.yml msg="Loading configuration file"
Oct 07 17:14:33 monitor prometheus-webhook-dingtalk[27896]: ts=2023-10-07T09:14:33.594Z caller=coordinator.go:91 level=info component=configuration file=/usr/local/prometheus_webhook_dingtalk/config.yml msg="Completed loading of configuration file"
Oct 07 17:14:33 monitor prometheus-webhook-dingtalk[27896]: ts=2023-10-07T09:14:33.594Z caller=main.go:97 level=info component=configuration msg="Loading templates" templates=contrib/templates/legacy/template.tmpl
Oct 07 17:14:33 monitor prometheus-webhook-dingtalk[27896]: ts=2023-10-07T09:14:33.596Z caller=main.go:113 `component=configuration msg="Webhook urls for prometheus alertmanager" urls="http://localhost:8060/dingtalk/webhook1/send http://localhost:8060/dingtalk/webhook_mention_all/send http://localhost:8060/dingtalk/webhook_mention_users/send"`
Oct 07 17:14:33 monitor prometheus-webhook-dingtalk[27896]: ts=2023-10-07T09:14:33.596Z caller=web.go:208 level=info component=web msg="Start listening for connections" address=:8060

```

#### 11、开放webhook_dingtalk端口

```bash
firewall-cmd --add-port=8060/tcp  --permanent
firewall-cmd --reload
```

#### 12、编辑alertmanager.yml

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 30s
  repeat_interval: 5m
  receiver: 'webhook_dingtalk.webhook1'
  routes:
  - receiver: 'webhook_dingtalk.webhook1'
    match_re:
      alertname: ".*"
    group_wait: 10s
    group_interval: 15s
    repeat_interval: 3h
  - receiver: 'webhook_dingtalk.webhook_mention_all'
    match_re:
      #team: all
      alertname: ".*"
    group_wait: 10s
    group_interval: 15s
    repeat_interval: 3h
receivers:
  - name: 'webhook_dingtalk.webhook1'
    webhook_configs:
      - url: 'http://10.96.4.97:8060/dingtalk/webhook1/send'
        send_resolved: true
  - name: 'webhook_dingtalk.webhook_mention_all'
    webhook_configs:
      - url: 'http://10.96.4.97:8060/dingtalk/webhook_mention_all/send'
        send_resolved: true
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
```

#### 13、重启Alertmanager服务

```bash
./amtool check-config ./alertmanager.yml 
Checking './alertmanager.yml'  SUCCESS
Found:
 - global config
 - route
 - 1 inhibit rules
 - 2 receivers
 - 0 templates


systemctl restart alertmanager
systemctl status alertmanager
```

#### 14、配置prometheus

#修改/etc/prometheus/prometheus.yml 

#主要是alterting中的地址：10.96.4.97:9093

#和rule_files:

```yaml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
           - 10.96.4.97:9093
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"
  - "/usr/local/prometheus/prometheus/rule/node_exporter.yml"
```

#/usr/local/prometheus/prometheus/rule/node_exporter.yml

```yaml
#/usr/local/prometheus/prometheus/rule/node_exporter.yml
groups:
- name: 服务器资源监控
  rules:
  - alert: 内存使用率过高
    expr: 100 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 80
    for: 3m 
    labels:
      severity: 严重告警
    annotations:
      summary: "{{ $labels.instance }} 内存使用率过高, 请尽快处理！"
      description: "{{ $labels.instance }}内存使用率超过80%,当前使用率{{ $value }}%."
          
  - alert: 服务器宕机
    expr: up == 0
    for: 1s
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.instance}} 服务器宕机, 请尽快处理!"
      description: "{{$labels.instance}} 服务器延时超过3分钟,当前状态{{ $value }}. "
 
  - alert: CPU高负荷
    expr: 100 - (avg by (instance,job)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
    for: 5m
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.instance}} CPU使用率过高,请尽快处理！"
      description: "{{$labels.instance}} CPU使用大于90%,当前使用率{{ $value }}%. "
      
  - alert: 磁盘IO性能
    expr: avg(irate(node_disk_io_time_seconds_total[1m])) by(instance,job)* 100 > 90
    for: 5m
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.instance}} 流入磁盘IO使用率过高,请尽快处理！"
      description: "{{$labels.instance}} 流入磁盘IO大于90%,当前使用率{{ $value }}%."
 
 
  - alert: 网络流入
    expr: ((sum(rate (node_network_receive_bytes_total{device!~'tap.*|veth.*|br.*|docker.*|virbr*|lo*'}[5m])) by (instance,job)) / 100) > 102400
    for: 5m
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.instance}} 流入网络带宽过高，请尽快处理！"
      description: "{{$labels.instance}} 流入网络带宽持续5分钟高于100M. RX带宽使用量{{$value}}."
 
  - alert: 网络流出
    expr: ((sum(rate (node_network_transmit_bytes_total{device!~'tap.*|veth.*|br.*|docker.*|virbr*|lo*'}[5m])) by (instance,job)) / 100) > 102400
    for: 5m
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.instance}} 流出网络带宽过高,请尽快处理！"
      description: "{{$labels.instance}} 流出网络带宽持续5分钟高于100M. RX带宽使用量{$value}}."
  
  - alert: TCP连接数
    expr: node_netstat_Tcp_CurrEstab > 10000
    for: 2m
    labels:
      severity: 严重告警
    annotations:
      summary: " TCP_ESTABLISHED过高！"
      description: "{{$labels.instance}} TCP_ESTABLISHED大于100%,当前使用率{{ $value }}%."
 
  - alert: 磁盘容量
    expr: 100-(node_filesystem_free_bytes{fstype=~"ext4|xfs"}/node_filesystem_size_bytes {fstype=~"ext4|xfs"}*100) > 90
    for: 1m
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.mountpoint}} 磁盘分区使用率过高，请尽快处理！"
      description: "{{$labels.instance}} 磁盘分区使用大于90%，当前使用率{{ $value }}%."

```



#在prometheus安装文件夹根目录增加alert_rules.yml配置文件，内容如下

```yaml
groups:
  - name: alert_rules
    rules:
      - alert: CpuUsageAlertWarning
        expr: sum(avg(irate(node_cpu_seconds_total{mode!='idle'}[5m])) without (cpu)) by (instance) > 0.60
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} CPU usage high"
          description: "{{ $labels.instance }} CPU usage above 60% (current value: {{ $value }})"
      - alert: CpuUsageAlertSerious
        #expr: sum(avg(irate(node_cpu_seconds_total{mode!='idle'}[5m])) without (cpu)) by (instance) > 0.85
        expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{job=~".*",mode="idle"}[5m])) * 100)) > 85
        for: 3m
        labels:
          level: serious
        annotations:
          summary: "Instance {{ $labels.instance }} CPU usage high"
          description: "{{ $labels.instance }} CPU usage above 85% (current value: {{ $value }})"
      - alert: MemUsageAlertWarning
        expr: avg by(instance) ((1 - (node_memory_MemFree_bytes + node_memory_Buffers_bytes + node_memory_Cached_bytes) / node_memory_MemTotal_bytes) * 100) > 70
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} MEM usage high"
          description: "{{$labels.instance}}: MEM usage is above 70% (current value is: {{ $value }})"
      - alert: MemUsageAlertSerious
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)/node_memory_MemTotal_bytes > 0.90
        for: 3m
        labels:
          level: serious
        annotations:
          summary: "Instance {{ $labels.instance }} MEM usage high"
          description: "{{ $labels.instance }} MEM usage above 90% (current value: {{ $value }})"
      - alert: DiskUsageAlertWarning
        expr: (1 - node_filesystem_free_bytes{fstype!="rootfs",mountpoint!="",mountpoint!~"/(run|var|sys|dev).*"} / node_filesystem_size_bytes) * 100 > 80
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} Disk usage high"
          description: "{{$labels.instance}}: Disk usage is above 80% (current value is: {{ $value }})"
      - alert: DiskUsageAlertSerious
        expr: (1 - node_filesystem_free_bytes{fstype!="rootfs",mountpoint!="",mountpoint!~"/(run|var|sys|dev).*"} / node_filesystem_size_bytes) * 100 > 90
        for: 3m
        labels:
          level: serious
        annotations:
          summary: "Instance {{ $labels.instance }} Disk usage high"
          description: "{{$labels.instance}}: Disk usage is above 90% (current value is: {{ $value }})"
      - alert: NodeFileDescriptorUsage
        expr: avg by (instance) (node_filefd_allocated{} / node_filefd_maximum{}) * 100 > 60
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} File Descriptor usage high"
          description: "{{$labels.instance}}: File Descriptor usage is above 60% (current value is: {{ $value }})"
      - alert: NodeLoad15
        expr: avg by (instance) (node_load15{}) > 80
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} Load15 usage high"
          description: "{{$labels.instance}}: Load15 is above 80 (current value is: {{ $value }})"
      - alert: NodeAgentStatus
        expr: avg by (instance) (up{}) == 0
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "{{$labels.instance}}: has been down"
          description: "{{$labels.instance}}: Node_Exporter Agent is down (current value is: {{ $value }})"
      - alert: NodeProcsBlocked
        expr: avg by (instance) (node_procs_blocked{}) > 10
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }}  Process Blocked usage high"
          description: "{{$labels.instance}}: Node Blocked Procs detected! above 10 (current value is: {{ $value }})"
      - alert: NetworkTransmitRate
        #expr:  avg by (instance) (floor(irate(node_network_transmit_bytes_total{device="ens192"}[2m]) / 1024 / 1024)) > 50
        expr:  avg by (instance) (floor(irate(node_network_transmit_bytes_total{}[2m]) / 1024 / 1024 * 8 )) > 40
        for: 1m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} Network Transmit Rate usage high"
          description: "{{$labels.instance}}: Node Transmit Rate (Upload) is above 40Mbps/s (current value is: {{ $value }}Mbps/s)"
      - alert: NetworkReceiveRate
        #expr:  avg by (instance) (floor(irate(node_network_receive_bytes_total{device="ens192"}[2m]) / 1024 / 1024)) > 50
        expr:  avg by (instance) (floor(irate(node_network_receive_bytes_total{}[2m]) / 1024 / 1024 * 8 )) > 40
        for: 1m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} Network Receive Rate usage high"
          description: "{{$labels.instance}}: Node Receive Rate (Download) is above 40Mbps/s (current value is: {{ $value }}Mbps/s)"
      - alert: DiskReadRate
        expr: avg by (instance) (floor(irate(node_disk_read_bytes_total{}[2m]) / 1024 )) > 200
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} Disk Read Rate usage high"
          description: "{{$labels.instance}}: Node Disk Read Rate is above 200KB/s (current value is: {{ $value }}KB/s)"
      - alert: DiskWriteRate
        expr: avg by (instance) (floor(irate(node_disk_written_bytes_total{}[2m]) / 1024 / 1024 )) > 20
        for: 2m
        labels:
          level: warning
        annotations:
          summary: "Instance {{ $labels.instance }} Disk Write Rate usage high"
          description: "{{$labels.instance}}: Node Disk Write Rate is above 20MB/s (current value is: {{ $value }}MB/s)"
```

#### 15、重启prometheus

```bash
systemctl restart prometheus
```

#### 16、查看prometheus

#http://10.96.4.97:9090/alerts?search=

![image-20231007185012158](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007185012158.png)

#如果故意关闭几个测试的微服务

![image-20231007185141076](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007185141076.png)



#解除告警

![image-20231007185216618](E:\workpc\git\gitio\gaophei.github.io\docs\prometheus\monitor-pics\image-20231007185216618.png)

