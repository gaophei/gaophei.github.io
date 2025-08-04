**MySQL双主+Keepalived VIP架构 Prometheus+Grafana 监控的全流程详细脚本与配置**，**涵盖安装、systemd服务、prometheus配置、主流告警方式（邮件、钉钉、企业微信）**。
 **监控部署节点为192.168.100.110，所有端口默认。**

------

# 一、架构与前置环境

- 监控服务器：`192.168.100.110`（Prometheus、Grafana、Alertmanager、blackbox_exporter）
- MySQL节点：`192.168.100.101`、`192.168.100.102`
- VIP地址：`192.168.100.100`
- 所有机器为 x86_64 Linux，假定为 CentOS 7/8 或类似环境

------

# 二、监控端二进制包下载安装

```bash
# （建议root或sudo下执行）
cd /opt

# 1. Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar -zxvf prometheus-2.52.0.linux-amd64.tar.gz
mv prometheus-2.52.0.linux-amd64 prometheus

# 2. Alertmanager
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -zxvf alertmanager-0.27.0.linux-amd64.tar.gz
mv alertmanager-0.27.0.linux-amd64 alertmanager

# 3. blackbox_exporter
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.25.0/blackbox_exporter-0.25.0.linux-amd64.tar.gz
tar -zxvf blackbox_exporter-0.25.0.linux-amd64.tar.gz
mv blackbox_exporter-0.25.0.linux-amd64 blackbox_exporter

# 4. Grafana
wget https://dl.grafana.com/enterprise/release/grafana-enterprise-11.0.0.linux-amd64.tar.gz
tar -zxvf grafana-enterprise-11.0.0.linux-amd64.tar.gz
mv grafana-11.0.0 grafana
```

------

# 三、MySQL 节点 exporter 安装

在 `192.168.100.101` 和 `192.168.100.102` 两台 MySQL 主机执行：

## 1. 安装 node_exporter

```bash
cd /opt
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar -zxvf node_exporter-1.8.1.linux-amd64.tar.gz
mv node_exporter-1.8.1.linux-amd64 node_exporter
```

## 2. 安装 mysqld_exporter

```bash
cd /opt
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar -zxvf mysqld_exporter-0.15.0.linux-amd64.tar.gz
mv mysqld_exporter-0.15.0.linux-amd64 mysqld_exporter
```

### 3. 创建 MySQL 监控账号

登录MySQL，执行如下SQL（密码可改）：

```sql
CREATE USER 'mysqld_exporter'@'localhost' IDENTIFIED BY 'exporter_pwd';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost';
FLUSH PRIVILEGES;
```

### 4. 创建配置文件

**编辑 /opt/mysqld_exporter/.my.cnf：**

```ini
[client]
user=mysqld_exporter
password=exporter_pwd
host=localhost
```

**权限设置：**

```bash
chmod 600 /opt/mysqld_exporter/.my.cnf
```

------

# 四、Systemd Service 文件

**1. Prometheus 服务**

```
/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.console.templates=/opt/prometheus/consoles \
  --web.console.libraries=/opt/prometheus/console_libraries
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

------

**2. Alertmanager 服务**

```
/etc/systemd/system/alertmanager.service
[Unit]
Description=Prometheus Alertmanager
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/alertmanager/alertmanager \
  --config.file=/opt/alertmanager/alertmanager.yml \
  --storage.path=/opt/alertmanager/data
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

------

**3. Blackbox Exporter 服务**

```
/etc/systemd/system/blackbox_exporter.service
[Unit]
Description=Prometheus Blackbox Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/blackbox_exporter/blackbox_exporter \
  --config.file=/opt/blackbox_exporter/blackbox.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

------

**4. Grafana 服务**

```
/etc/systemd/system/grafana.service
[Unit]
Description=Grafana
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/grafana
ExecStart=/opt/grafana/bin/grafana-server \
  --homepath=/opt/grafana
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

------

**5. node_exporter 服务（MySQL节点）**

```
/etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/node_exporter/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

------

**6. mysqld_exporter 服务（MySQL节点）**

```
/etc/systemd/system/mysqld_exporter.service
[Unit]
Description=Prometheus MySQLd Exporter
After=network.target

[Service]
Type=simple
User=root
Environment="DATA_SOURCE_NAME=mysqld_exporter:exporter_pwd@(localhost:3306)/"
ExecStart=/opt/mysqld_exporter/mysqld_exporter --config.my-cnf=/opt/mysqld_exporter/.my.cnf
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

------

**启动并设为自启动：**

```bash
systemctl daemon-reload
systemctl enable prometheus alertmanager blackbox_exporter grafana
systemctl start prometheus alertmanager blackbox_exporter grafana

# 在各MySQL节点：
systemctl enable node_exporter mysqld_exporter
systemctl start node_exporter mysqld_exporter
```

------

# 五、配置文件内容

## 1. blackbox_exporter 配置 `/opt/blackbox_exporter/blackbox.yml`

```yaml
modules:
  tcp_connect:
    prober: tcp
    timeout: 5s
```

## 2. Prometheus 配置 `/opt/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
      - targets:
        - 127.0.0.1:9093

scrape_configs:
  - job_name: 'mysql01-node'
    static_configs:
      - targets: ['192.168.100.101:9100']

  - job_name: 'mysql02-node'
    static_configs:
      - targets: ['192.168.100.102:9100']

  - job_name: 'mysql01-mysql'
    static_configs:
      - targets: ['192.168.100.101:9104']

  - job_name: 'mysql02-mysql'
    static_configs:
      - targets: ['192.168.100.102:9104']

  - job_name: 'vip-tcp'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets: ['192.168.100.100:3306']
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9115
```

------

## 3. Alertmanager 配置 `/opt/alertmanager/alertmanager.yml`

**（多渠道模板）**

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'email_default'
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h
  routes:
    - match:
        alertname: 'VIPUnreachable'
      receiver: 'dingding_vip'
    - match:
        alertname: 'MySQLSplitBrain'
      receiver: 'wechat_db'
    # 可以再细分更多路由

receivers:
- name: 'email_default'
  email_configs:
  - to: 'alert@example.com'
    from: 'alert@example.com'
    smarthost: 'smtp.example.com:465'
    auth_username: 'alert@example.com'
    auth_password: 'SMTP_PASSWORD'
    require_tls: true
    send_resolved: true

- name: 'dingding_vip'
  webhook_configs:
  - url: 'http://127.0.0.1:8060/dingtalk/send/vip'  # 见下节说明

- name: 'wechat_db'
  webhook_configs:
  - url: 'http://127.0.0.1:8061/wechat/send/db'
```

------

## 4. Prometheus 告警规则 `/opt/prometheus/alert.rules.yml`

```yaml
groups:
- name: mysql-double-master-alerts
  rules:
  - alert: MySQLInstanceDown
    expr: up{job="mysql01-mysql"} == 0 or up{job="mysql02-mysql"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "MySQL 实例宕机"
      description: "MySQL 实例 {{ $labels.instance }} 宕机无法访问。"

  - alert: VIPUnreachable
    expr: probe_success{job="vip-tcp"} == 0
    for: 30s
    labels:
      severity: critical
    annotations:
      summary: "MySQL VIP端口不可达"
      description: "VIP 3306 不可访问，可能服务已失效或漂移。"

  - alert: MySQLSplitBrain
    expr: count(up{job=~"vip-tcp"} == 1) > 1
    for: 10s
    labels:
      severity: critical
    annotations:
      summary: "MySQL 脑裂风险"
      description: "检测到同一时间有多个节点持有VIP，疑似脑裂！"
```

**在`prometheus.yml`加入：**

```yaml
rule_files:
  - "alert.rules.yml"
```

------

# 六、钉钉与企业微信 Webhook 告警方案

Prometheus/Alertmanager 不支持直接钉钉和微信，需本地开小webhook转发服务（常用 [prometheus-webhook-dingtalk](https://github.com/timonwong/prometheus-webhook-dingtalk)、[prometheus-webhook-wechat](https://github.com/timonwong/prometheus-webhook-wechat)）

## 1. prometheus-webhook-dingtalk 安装

```bash
# 假设在192.168.100.110运行
wget https://github.com/timonwong/prometheus-webhook-dingtalk/releases/download/v2.1.0/prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz
tar -zxvf prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz
cd prometheus-webhook-dingtalk-2.1.0.linux-amd64

cat > config.yml <<EOF
targets:
  vip:
    url: https://oapi.dingtalk.com/robot/send?access_token=你的钉钉机器人token
EOF
```

运行：

```bash
./prometheus-webhook-dingtalk --config.file=config.yml --web.listen-address=0.0.0.0:8060 &
```

systemd可自行加（同理）

## 2. prometheus-webhook-wechat 安装

```bash
wget https://github.com/timonwong/prometheus-webhook-wechat/releases/download/v2.1.0/prometheus-webhook-wechat-2.1.0.linux-amd64.tar.gz
tar -zxvf prometheus-webhook-wechat-2.1.0.linux-amd64.tar.gz
cd prometheus-webhook-wechat-2.1.0.linux-amd64

cat > config.yml <<EOF
targets:
  db:
    corp_id: "你的企业微信CorpID"
    agent_id: "1000002"
    secret: "你的Secret"
    to_user: "@all"
    to_party: ""
    to_tag: ""
EOF
```

运行：

```bash
./prometheus-webhook-wechat --config.file=config.yml --web.listen-address=0.0.0.0:8061 &
```

systemd可自行加（同理）

------

# 七、Grafana 配置与仪表盘

1. 启动 Grafana（见 systemd 文件）
2. 浏览器访问 `http://192.168.100.110:3000`（默认端口）
   - 默认账号 admin/admin
   - 添加 Prometheus 数据源，URL 填 `http://localhost:9090`
   - 导入仪表盘，可推荐：[Percona MySQL Dashboard 7362](https://grafana.com/grafana/dashboards/7362-mysql-overview/)、[Node Exporter Full 1860](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)
3. 告警规则可通过 Grafana 也进行配置（高级场景）

------

# 八、常见目录结构建议

```
/opt/
  prometheus/
    prometheus
    prometheus.yml
    alert.rules.yml
  alertmanager/
    alertmanager
    alertmanager.yml
  blackbox_exporter/
    blackbox_exporter
    blackbox.yml
  grafana/
    bin/grafana-server
  prometheus-webhook-dingtalk/
    prometheus-webhook-dingtalk
    config.yml
  prometheus-webhook-wechat/
    prometheus-webhook-wechat
    config.yml
```

------

# 九、常用操作命令

```bash
# 配置修改后重启服务
systemctl restart prometheus alertmanager blackbox_exporter grafana

# 查看prometheus/alertmanager/grafana日志
journalctl -u prometheus -f
journalctl -u alertmanager -f
journalctl -u grafana -f
```

------

# 十、你要做的就是：

1. 按上面安装二进制、拷贝配置和 systemd 文件，调整文件路径和密码等（尤其MySQL exporter相关账号密码）
2. 启动所有服务并检查端口可达（3306/9100/9104/9115/9090/3000/9093/8060/8061等）
3. 按需注册钉钉/微信/邮箱，替换好 webhook/账号等
4. Grafana导入dashboard即可
5. 邮箱建议开启SMTP SSL（端口465/587）
6. exporter建议与MySQL部署在同一台

------

**如有某一步卡住或配置细节需调整，可随时补充你的实际需求，我可以帮你生成个性化的完整配置和一键启动脚本。**

如需要“全打包文件（tar.gz或脚本）”，可告知。
 如需VIP脑裂自定义监控脚本及pushgateway方案，也可加配！