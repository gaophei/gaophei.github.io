一套**基于 Prometheus + Grafana 的 MySQL 双主+Keepalived VIP高可用架构监控部署方案**，包括**组件选择、部署流程、核心配置、监控目标与告警**，并附上**典型配置文件和告警规则**。
 整体思路是：

- 用 `mysqld_exporter` 采集 MySQL 各项指标
- 用 `node_exporter` 采集系统资源
- 用自定义脚本或 `blackbox_exporter` 监控 VIP、端口可用性、脑裂风险
- Prometheus 统一采集
- Grafana 展示+告警

------

## 一、架构简图

```
  [MySQL-1]---+                        +---[mysqld_exporter]---+
               |                        |                      |
  [MySQL-2]---+---[node_exporter]-------+                      +--> [Prometheus] --> [Grafana]
               |                        |                      |
           [Keepalived]              [blackbox_exporter]-------+
```

- **MySQL-1/MySQL-2**：双主部署，并装 exporter
- **Keepalived**：负责VIP，健康检查用自定义脚本配合 exporter
- **Prometheus**：集中采集所有 exporter 数据
- **Grafana**：数据展示和报警

------

## 二、组件准备

1. Prometheus（可单独服务器或和Grafana同机）
2. Grafana（建议单独服务器）
3. mysqld_exporter（部署在每个MySQL主机上）
4. node_exporter（部署在每个MySQL主机上）
5. blackbox_exporter（可部署在Prometheus同主机）
6. 可选：自定义bash/python脚本定时检测脑裂/VIP归属，push到Prometheus

------

## 三、部署流程和配置

### 1. mysqld_exporter 安装与配置

> 适用于MySQL 5.7/8.0

#### 1）在MySQL主机上创建监控用户

```sql
CREATE USER 'mysqld_exporter'@'localhost' IDENTIFIED BY 'YourPassword';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost';
FLUSH PRIVILEGES;
```

#### 2）下载和运行 mysqld_exporter

```bash
# 以 0.15.0 版本为例，其他版本同理
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar -zxvf mysqld_exporter-0.15.0.linux-amd64.tar.gz
cd mysqld_exporter-0.15.0.linux-amd64

# 配置 MySQL 连接信息
echo 'DATA_SOURCE_NAME="mysqld_exporter:YourPassword@(localhost:3306)/"' > .env

# 启动
./mysqld_exporter --config.my-cnf=~/.my.cnf &
# 建议用systemd或supervisor托管
```

### 2. node_exporter 安装与配置

```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar -zxvf node_exporter-1.8.1.linux-amd64.tar.gz
cd node_exporter-1.8.1.linux-amd64
./node_exporter &
# 建议用systemd托管
```

### 3. blackbox_exporter 安装与配置

用于**端口存活（如VIP:3306）、HTTP(s)健康检测**等，推荐部署在Prometheus同服务器上。

```bash
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.25.0/blackbox_exporter-0.25.0.linux-amd64.tar.gz
tar -zxvf blackbox_exporter-0.25.0.linux-amd64.tar.gz
cd blackbox_exporter-0.25.0.linux-amd64
./blackbox_exporter &
```

#### 示例配置（prometheus.yml里用）

```yaml
  - job_name: 'vip-tcp-check'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
        - 10.0.0.100:3306    # 你的VIP和端口
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9115   # blackbox_exporter监听地址
```

### 4. Prometheus 安装与配置

```bash
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar -zxvf prometheus-2.52.0.linux-amd64.tar.gz
cd prometheus-2.52.0.linux-amd64
```

#### 典型prometheus.yml配置

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'mysql1-node'
    static_configs:
      - targets: ['mysql1_ip:9100']    # node_exporter 端口

  - job_name: 'mysql2-node'
    static_configs:
      - targets: ['mysql2_ip:9100']

  - job_name: 'mysql1'
    static_configs:
      - targets: ['mysql1_ip:9104']    # mysqld_exporter 默认端口

  - job_name: 'mysql2'
    static_configs:
      - targets: ['mysql2_ip:9104']

  - job_name: 'vip-tcp'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets: ['10.0.0.100:3306']    # VIP端口
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9115    # blackbox_exporter监听地址
```

### 5. 脑裂检测（VIP被多个节点抢占）

#### 方式1：自定义脚本 + pushgateway

可以写个定时脚本检测VIP归属情况，将结果通过pushgateway送到Prometheus。

```bash
# check_vip.sh
VIP=10.0.0.100
if ip a | grep $VIP; then
  echo "vip_status{host=\"$(hostname)\"} 1" | curl --data-binary @- http://pushgateway_ip:9091/metrics/job/vip_check
else
  echo "vip_status{host=\"$(hostname)\"} 0" | curl --data-binary @- http://pushgateway_ip:9091/metrics/job/vip_check
fi
```

- 两台MySQL节点上都跑
- Prometheus定时抓取pushgateway

#### 方式2：blackbox_exporter检测VIP的ARP

写脚本定期ssh到另一台机器检测VIP归属（更复杂）

------

### 6. Grafana 安装与配置

1. 下载并安装 Grafana（https://grafana.com/download/）
2. 登录后添加 Prometheus 数据源
3. 导入相关 Dashboard（比如 [Percona MySQL Dashboard](https://grafana.com/grafana/dashboards/7362-mysql-overview/) 或自定义仪表盘）
4. 配置告警规则（详见下文）

------

## 四、关键监控项建议

- MySQL主从复制状态（Seconds_Behind_Master、Slave_IO_Running、Slave_SQL_Running、Last_Error等）
- MySQL进程存活/端口可用性
- VIP:3306 可达性
- 主机资源（CPU、内存、磁盘）
- 连接数、慢查询、QPS/TPS
- 脑裂（VIP归属，两个主都持有VIP即报警）

------

## 五、Prometheus Alertmanager 告警规则（示例）

```yaml
groups:
- name: mysql-double-master-alerts
  rules:
  - alert: MySQLInstanceDown
    expr: up{job="mysql1"} == 0 or up{job="mysql2"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "MySQL 实例宕机"
      description: "MySQL 实例 {{ $labels.instance }} 宕机无法访问。"

  - alert: MySQLReplicationError
    expr: mysql_slave_status_slave_io_running != 1 or mysql_slave_status_slave_sql_running != 1
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "MySQL 主从复制中断"
      description: "MySQL 复制异常，检查 slave_io_running/slave_sql_running 状态。"

  - alert: VIPUnreachable
    expr: probe_success{job="vip-tcp"} == 0
    for: 30s
    labels:
      severity: critical
    annotations:
      summary: "MySQL VIP端口不可达"
      description: "VIP 3306 不可访问，可能服务已失效或漂移。"

  - alert: MySQLSplitBrain
    expr: count(vip_status{job="vip_check"} == 1) > 1
    for: 10s
    labels:
      severity: critical
    annotations:
      summary: "MySQL 脑裂风险"
      description: "检测到同一时间有多个节点持有VIP，疑似脑裂！"
```

------

## 六、最佳实践和建议

- 建议**所有MySQL相关监控都通过VIP端口做“黑盒”监控**，能真实反映业务连通性
- 业务层也可以加健康监测（如周期性执行`select 1`）
- 关键监控项务必加钉钉、邮件等高优先级通知
- 各项Exporter建议用systemd托管，配置自动重启
- Grafana仪表盘可以用官方模板快速搭建，如Percona系列
- 配置落地时注意网络、端口防火墙放行

------

## 七、参考资源和Dashboard模板

- [mysqld_exporter官方文档](https://github.com/prometheus/mysqld_exporter)
- [blackbox_exporter官方文档](https://github.com/prometheus/blackbox_exporter)
- [Grafana Dashboard: Percona MySQL Overview 7362](https://grafana.com/grafana/dashboards/7362-mysql-overview/)
- [Grafana Dashboard: Node Exporter Full 1860](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)
- [Alertmanager官方文档](https://prometheus.io/docs/alerting/latest/alertmanager/)

------

如需**完整prometheus.yml、grafana dashboard json、告警配置、部署脚本实例**，请告知你的服务器IP和环境细节，可以直接发你“即用型”配置！
 如果有其他组件（如推送钉钉、企业微信告警），也可补充给你对接教程。