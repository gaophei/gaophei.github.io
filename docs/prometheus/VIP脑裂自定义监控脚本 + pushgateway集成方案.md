一套**VIP脑裂自定义监控脚本 + pushgateway集成方案**，适配你的MySQL双主+Keepalived环境，并结合Prometheus告警。
 【目标】是**只要VIP在两个节点都出现就立刻告警**，防止脑裂影响数据一致性。

------

## 一、方案思路

1. **在两台MySQL节点（192.168.100.101 和 192.168.100.102）分别定时执行VIP检测脚本**；
2. 脚本把“本机是否持有VIP”这一状态通过 HTTP POST 上报给 Prometheus 的 pushgateway；
3. Prometheus 服务器定时从 pushgateway 拉取数据，配合 alert.rules 判断“同一时间有多个节点VIP持有”为脑裂并告警。

------

## 二、安装 pushgateway（监控主机 192.168.100.110 上操作）

```bash
cd /opt
wget https://github.com/prometheus/pushgateway/releases/download/v1.7.0/pushgateway-1.7.0.linux-amd64.tar.gz
tar -zxvf pushgateway-1.7.0.linux-amd64.tar.gz
mv pushgateway-1.7.0.linux-amd64 pushgateway

# systemd 服务
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

systemctl daemon-reload
systemctl enable pushgateway
systemctl start pushgateway
```

- 默认监听9091端口

------

## 三、VIP检测上报脚本（MySQL两节点各部署一份）

**文件名示例** `/usr/local/bin/push_vip_status.sh`
 `VIP=192.168.100.100`
 假设本机HOSTNAME设置正确（如`mysql01`、`mysql02`），否则建议用`ip`代替

```bash
#!/bin/bash

VIP=192.168.100.100
PUSHGW="192.168.100.110:9091"
JOB="vip_status"
INSTANCE="$(hostname)"    # 或自行设定唯一标识

# 检查本机是否拥有VIP（返回1=有，0=无）
if ip a | grep -q "$VIP"; then
  VALUE=1
else
  VALUE=0
fi

cat <<EOF | curl --data-binary @- http://$PUSHGW/metrics/job/$JOB/instance/$INSTANCE
# TYPE vip_own gauge
vip_own{instance="$INSTANCE"} $VALUE
EOF
```

**说明：**

- 脚本会以`vip_own{instance="mysql01"} 1`（有VIP）或`vip_own{instance="mysql01"} 0`（无VIP）上报
- 你也可以用`INSTANCE=$(hostname -I | awk '{print $1}')`改成IP

------

## 四、定时执行脚本

**加入crontab（MySQL节点上）：**

```bash
* * * * * /usr/local/bin/push_vip_status.sh
```

建议每分钟执行一次，脑裂可以很快检测出来。

------

## 五、Prometheus配置采集pushgateway

在`prometheus.yml`中加一段：

```yaml
- job_name: 'vip-push'
  static_configs:
    - targets: ['192.168.100.110:9091']
```

------

## 六、脑裂告警规则（alert.rules.yml）

**核心思想：同一时间有多于1台机器的`vip_own=1`就告警**

```yaml
groups:
- name: vip-splitbrain
  rules:
  - alert: MySQLSplitBrain
    expr: sum(vip_own) by (job) > 1
    for: 10s
    labels:
      severity: critical
    annotations:
      summary: "MySQL 脑裂风险"
      description: "有多台主机同时持有VIP，疑似脑裂！"
```

- `sum(vip_own)` 结果大于1即多节点持有VIP
- `for: 10s` 表示持续10秒仍有脑裂才报警（可自行调整）

**记得把此规则文件include到`prometheus.yml`的`rule_files`**

------

## 七、验证脑裂监控

1. **正常情况**，只有一台节点检测到有VIP，sum=1，不告警；
2. **脑裂时**（两台都持有VIP），sum=2，Prometheus触发告警。

------

## 八、补充说明

- pushgateway适合这种“非服务端直接pull指标”的主动上报场景
- VIP检测方式(ip a/ifconfig/ip addr show)根据系统而定，主流Linux都支持`ip a`
- 如果你用systemd或keepalived健康脚本，也可以直接集成检测和上报

------

## 九、整理目录和权限建议

- `/usr/local/bin/push_vip_status.sh` 需 `chmod +x`
- crontab建议用`root`或能运行ip命令的用户
- pushgateway服务运行用户需有文件读写权限（默认root即可）

------

## 十、推送效果举例

假设mysql01和mysql02都同时持有VIP，则Prometheus将采集到：

```
vip_own{instance="mysql01"} 1
vip_own{instance="mysql02"} 1
```

> 此时sum(vip_own) by (job) = 2，马上产生脑裂告警。

------

如需“完整部署脚本一键包”，或者有其他脑裂检测细节需求（如VIP接口指定、检测ARP表等复杂场景），可进一步定制。

如有任何实际操作疑问，可随时发你的执行日志、出错信息，我帮你查原因！