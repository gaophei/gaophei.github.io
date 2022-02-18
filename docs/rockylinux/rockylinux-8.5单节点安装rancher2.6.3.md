#### rocky linux 8.5单节点安装rancher2.6.3过程

##### 关闭防火墙/selinux/swap分区等
```bash
systemctl stop firewalld && systemctl disable firewalld
systemctl status firewalld

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0
getenforce

swapoff -a
sed -i 's/\/dev\/mapper\/cl-swap/\#\/dev\/mapper\/cl-swap/g' /etc/fstab
```

##### 内核优化等
```bash
#内核优化
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
#最大连接数
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

reboot
```
##### 安装docker源及依赖
```bash
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

dnf makecache fast

dnf list docker-ce --showduplicates |sort -r
```

##### 安装docker
```bash
dnf install -y docker-ce-20.10.12-3.el8

#如果有依赖包版本冲突，可以执行以下命令
dnf install -y docker-ce-20.10.12-3.el8 --allowrasing
```

##### 优化docker配置
```bash
systemctl start docker
systemctl status docker
systemctl enable docker

mkdir -p /etc/docker
touch /etc/docker/daemon.json

cat > /etc/docker/daemon.json <<EOF
{
    "oom-score-adjust": -1000,
    "log-driver": "json-file",
    "log-opts": {
    "max-size": "100m",
    "max-file": "3"
    },
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 10,
    "bip": "138.138.123.1/24",
    "registry-mirrors": ["https://7bezldxe.mirror.aliyuncs.com"],
    "insecure-registries":["https://harbor.supwisdom.com"],
    "storage-driver": "overlay2",
    "storage-opts": [
    "overlay2.override_kernel_check=true"
    ]
}
EOF

#编辑/usr/lib/systemd/system/docker.service，添加
OOMScoreAdjust=-1000
ExecStartPost=/sbin/iptables -P FORWARD ACCEPT

systemctl daemon-reload
systemctl restart docker
```

##### 单节点安装rancher2.6.3
```bash
docker run -d --restart=unless-stopped --name=rancher --privileged  -p 80:80 -p 443:443  rancher/rancher:v2.6.3
```

##### 页面配置
#查看bootstap password
```bash
docker ps
docker logs container-id 2>&1 | grep "Bootstrap Password:"
```
![image-20220215145045963](单节点rancher2.6.3\image-20220215145045963.png)



![image-20220215145520291](单节点rancher2.6.3\image-20220215145520291.png)



![image-20220215145619694](单节点rancher2.6.3\image-20220215145619694.png)
