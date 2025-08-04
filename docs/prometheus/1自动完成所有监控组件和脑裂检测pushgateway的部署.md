好的！你要的“一键部署包”，会**自动完成所有监控组件和脑裂检测pushgateway的部署（含systemd、配置、脚本）**，适合**新监控服务器192.168.100.110**。MySQL节点部分只需简单部署exporter和VIP脚本即可。
 下面内容你只需**按顺序粘贴运行即可**，如需打成tar包下载也可以告知。

------

## 1. 在192.168.100.110（监控服务器）一键部署

**注：脚本假定/opt为空或用于监控组件目录。root/sudo运行。**

```bash
#!/bin/bash
set -e

# 基础包
yum install -y wget tar curl

cd /opt

# Prometheus
wget -q https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar -xf prometheus-2.52.0.linux-amd64.tar.gz
mv prometheus-2.52.0.linux-amd64 prometheus

# Alertmanager
wget -q https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xf alertmanager-0.27.0.linux-amd64.tar.gz
mv alertmanager-0.27.0.linux-amd64 alertmanager

# blackbox_exporter
wget -q https://github.com/prometheus/blackbox_exporter/releases/download/v0.25.0/blackbox_exporter-0.25.0.linux-amd64.tar.gz
tar -xf blackbox_exporter-0.25.0.linux-amd64.tar.gz
mv blackbox_exporter-0.25.0.linux-amd64 blackbox_exporter

# pushgateway
wget -q https://github.com/prometheus/pushgateway/releases/download/v1.7.0/pushgateway-1.7.0.linux-amd64.tar.gz
tar -xf pushgateway-1.7.0.linux-amd64.tar.gz
mv pushgateway-1.7.0.linux-amd64 pushgateway

# Grafana
wget -q https://dl.grafana.com/enterprise/release/grafana-enterprise-11.0.0.linux-amd64.tar.gz
tar -xf grafana-enterprise-11.0.0.linux-amd64.tar.gz
mv grafana-11.0.0 grafana

# 配置文件
cat > /opt/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
      - targets: ['127.0.0.1:9093']

rule_files:
  - "alert.rules.yml"

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

  - job_name: 'vip-push'
    static_configs:
      - targets: ['127.0.0.1:9091']
EOF

cat > /opt/prometheus/alert.rules.yml <<EOF
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
      description: "MySQL 实例 {{ \$labels.instance }} 宕机无法访问。"

  - alert: VIPUnreachable
    expr: probe_success{job="vip-tcp"} == 0
    for: 30s
    labels:
      severity: critical
    annotations:
      summary: "MySQL VIP端口不可达"
      description: "VIP 3306 不可访问，可能服务已失效或漂移。"

  - alert: MySQLSplitBrain
    expr: sum(vip_own) > 1
    for: 10s
    labels:
      severity: critical
    annotations:
      summary: "MySQL 脑裂风险"
      description: "检测到多台节点同时持有VIP，疑似脑裂！"
EOF

cat > /opt/alertmanager/alertmanager.yml <<EOF
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
  - url: 'http://127.0.0.1:8060/dingtalk/send/vip'

- name: 'wechat_db'
  webhook_configs:
  - url: 'http://127.0.0.1:8061/wechat/send/db'
EOF

cat > /opt/blackbox_exporter/blackbox.yml <<EOF
modules:
  tcp_connect:
    prober: tcp
    timeout: 5s
EOF

# Systemd服务文件
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/prometheus/prometheus \\
  --config.file=/opt/prometheus/prometheus.yml \\
  --storage.tsdb.path=/opt/prometheus/data \\
  --web.console.templates=/opt/prometheus/consoles \\
  --web.console.libraries=/opt/prometheus/console_libraries
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/alertmanager.service <<EOF
[Unit]
Description=Prometheus Alertmanager
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/alertmanager/alertmanager \\
  --config.file=/opt/alertmanager/alertmanager.yml \\
  --storage.path=/opt/alertmanager/data
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/blackbox_exporter.service <<EOF
[Unit]
Description=Prometheus Blackbox Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/blackbox_exporter/blackbox_exporter \\
  --config.file=/opt/blackbox_exporter/blackbox.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/pushgateway.service <<EOF
[Unit]
Description=Prometheus Pushgateway
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/pushgateway/pushgateway
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/grafana.service <<EOF
[Unit]
Description=Grafana
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/grafana
ExecStart=/opt/grafana/bin/grafana-server \\
  --homepath=/opt/grafana
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动并设为开机自启
systemctl daemon-reload
systemctl enable prometheus alertmanager blackbox_exporter pushgateway grafana
systemctl start prometheus alertmanager blackbox_exporter pushgateway grafana

echo "一键部署完成！"
echo "Prometheus:    http://192.168.100.110:9090"
echo "Alertmanager:  http://192.168.100.110:9093"
echo "Grafana:       http://192.168.100.110:3000 (初始账号: admin/admin)"
```

------

## 2. MySQL两节点部署exporter及VIP脑裂监控脚本

### 2.1 安装 node_exporter & mysqld_exporter（以101节点为例）

```bash
# node_exporter
cd /opt
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar -xf node_exporter-1.8.1.linux-amd64.tar.gz
mv node_exporter-1.8.1.linux-amd64 node_exporter

cat > /etc/systemd/system/node_exporter.service <<EOF
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
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# mysqld_exporter
wget -q https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar -xf mysqld_exporter-0.15.0.linux-amd64.tar.gz
mv mysqld_exporter-0.15.0.linux-amd64 mysqld_exporter

cat > /opt/mysqld_exporter/.my.cnf <<EOF
[client]
user=mysqld_exporter
password=exporter_pwd
host=localhost
EOF

chmod 600 /opt/mysqld_exporter/.my.cnf

cat > /etc/systemd/system/mysqld_exporter.service <<EOF
[Unit]
Description=Prometheus MySQLd Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/mysqld_exporter/mysqld_exporter --config.my-cnf=/opt/mysqld_exporter/.my.cnf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mysqld_exporter
systemctl start mysqld_exporter
```

> 请先在MySQL内执行账号授权SQL（见上面回复）。

------

### 2.2 脑裂检测push脚本

**/usr/local/bin/push_vip_status.sh**

```bash
#!/bin/bash

VIP=192.168.100.100
PUSHGW="192.168.100.110:9091"
JOB="vip_status"
INSTANCE="$(hostname)"    # 或用本机IP

if ip a | grep -q "$VIP"; then
  VALUE=1
else
  VALUE=0
fi

cat <<EOF | curl --data-binary @- http://$PUSHGW/metrics/job/$JOB/instance/$INSTANCE
# TYPE vip_own gauge
vip_own{instance="$INSTANCE"} $VALUE
EOF
chmod +x /usr/local/bin/push_vip_status.sh
(crontab -l; echo "* * * * * /usr/local/bin/push_vip_status.sh") | crontab -
```

------

## 3. 可选：邮件/钉钉/企业微信报警转发

> 请参见上面详细文档配置

- 邮件：alertmanager配置alertmanager.yml中的SMTP部分
- 钉钉/企业微信：prometheus-webhook-dingtalk、prometheus-webhook-wechat单独下载配置（可提供一键安装脚本）

------

## 4. Grafana仪表盘

- 浏览器访问：[http://192.168.100.110:3000](http://192.168.100.110:3000/)
- 初始用户 admin/admin
- 数据源添加Prometheus，URL为 [http://localhost:9090](http://localhost:9090/)
- 可在线导入仪表盘 [7362](https://grafana.com/grafana/dashboards/7362-mysql-overview/)、[1860](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)

------

## 完整包导出

如你需要所有内容打包成tar.gz（含脚本、配置和模板），请回复“打包下载”，我会生成结构说明和压缩包脚本，供你一键下载和分发。

------

如有任何部署细节卡壳，欢迎随时反馈，直接粘贴报错/执行日志，我会帮你定位优化！