内核配置项： 

```Bash
# node瓶颈是conntrack
# 下面2项令TCP窗口和状态追踪更加宽松
net.netfilter.nf_conntrack_tcp_be_liberal=1
net.netfilter.nf_conntrack_tcp_loose=1 
# 下面3项调大了conntrack表，保证操作效率
net.netfilter.nf_conntrack_max=3200000
net.netfilter.nf_conntrack_buckets=1600512
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
 
 
# pod瓶颈是TCP协议栈
net.ipv4.tcp_timestamps=1 # 与tw_reuse一起用
net.ipv4.tcp_tw_reuse=1 # 仅作用于客户端，允许复用TIME_WAIT端口（与tcp_rw_recycle不同，该选项不受NAT场景下时间戳不一致问题影响）
net.ipv4.ip_local_port_range="5120 65000" # 端口范围
net.ipv4.tcp_fin_timeout=30 # 缩短TIME_WAIT时间,加速端口回收
# 下面3个均为加强握手队列能力
net.ipv4.tcp_max_syn_backlog=10240
net.core.somaxconn=10240
net.ipv4.tcp_syncookies=1
# 放开信号量限制
kernel.sem="1034 32000 100 1000"

```



node开机后，需要关闭透明大页，否则影响程序性能： 

```Bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```



配置网卡多队列： 

```Bash
# 查看网卡支持多队列的情况
# ethtool -l eth0
Channel parameters for eth0:
Pre-set maximums:
RX:             0
TX:             0
Other:          1
Combined:       63  # 表示最多支持设置63个队列
Current hardware settings:
RX:             0
TX:             0
Other:          1
Combined:       32 # 当前生效的是32个队列

# 修改多队列支持
ethtool -L eth0 combined 64

# 再次查看
# ethtool -l eth0
Channel parameters for eth0:
Pre-set maximums:
RX:             0
TX:             0
Other:          1
Combined:       63
Current hardware settings:
RX:             0
TX:             0
Other:          1
Combined:       63

```



配置网卡的软中断负载均衡，具体配置可参考： [https://www.codeleading.com/article/76001481980/](https://www.codeleading.com/article/76001481980/) 