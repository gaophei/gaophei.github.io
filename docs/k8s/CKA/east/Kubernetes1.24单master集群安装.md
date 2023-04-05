从kubernetes 1.22开始，kubernetes正式不再支持docker作为其容器运行时，本篇文档，我们使用containerd作为其运行时，用kubeadm部署一个单master的kubernetes集群



整个安装过程分为如下几个步骤： 

- 环境说明
- 集群部署
- 安装add-ons
- 集群维护
- 附录



# 环境说明



各组件部署示意图： 

![](https://secure2.wostatic.cn/static/4WpFBgvHWGMpcxAWhb4t1S/image.png?auth_key=1680618586-2NB61rhuifUTwh47ctTP8D-0-ba6e910e691ae388bf494c4102ee6cdb)

相关部署环境及部署组件： 

| 主机名 | ip地址        | 节点类型     | 系统版本 |
| ------ | ------------- | ------------ | -------- |
| k8s01  | 172.26.159.93 | master、etcd | centos7  |
| k8s02  | 172.26.159.94 | worker       | centos7  |
| k8s03  | 172.26.159.95 | worker       | centos7  |


| 组件       | 版本 | 说明       |
| ---------- | ---- | ---------- |
| kubernetes | 1.24 | 主程序     |
| containerd | 1.6  | 容器运行时 |
| calico     | 3.23 | 网络插件   |
| etcd       | 3.5  | 数据库     |
| coredns    | 1.8  | dns组件    |


# 集群部署

集群部署分为如下四个部分： 

- 环境准备
- 部署master
- 安装网络插件
- 添加worker节点



## 环境准备

准备工作需要在所有节点上操作，包含的过程如下： 

- 配置主机名
- 添加/etc/hosts
- 清空防火墙
- 设置yum源
- 配置时间同步
- 关闭swap
- 配置内核参数
- 加载ip_vs内核模块
- 安装Containerd
- 安装kubelet、kubectl、kubeadm



修改主机名：

```
# 以一个节点为例
# k8s01
hostnamectl set-hostname k8s01 --static
# k8s02
hostnamectl set-hostname k8s02 --static
# k8s03
hostnamectl set-hostname k8s03 --static
```



添加hosts:

```Bash
# /etc/hosts
172.26.159.93 k8s01
172.26.159.94 k8s01
172.26.159.95 k8s01

```





清空防火墙规则和selinux：

```
iptables -F
setenforce 0 
sed -i 's/SELINUX=/SELINUX=disabled/g' /etc/selinux/config
```

设置yum源：

```
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

wget -O /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo

```



配置时间同步： 

```Bash
yum install -y chrony -y 
systemctl enable --now chronyd 
chronyc sources 
```



关闭swap： 

默认情况下，kubernetes不允许其安装节点开启swap，如果已经开始了swap的节点，建议关闭掉swap

```Bash
# 临时禁用swap
swapoff -a 

# 修改/etc/fstab，将swap挂载注释掉，可确保节点重启后swap仍然禁用

# 可通过如下指令验证swap是否禁用： 
free -m  # 可以看到swap的值为0
              total        used        free      shared  buff/cache   available
Mem:           7822         514         184         431        7123        6461
Swap:             0           0           0

```



加载内核模块：

```
cat > /etc/modprobe.d/k8s.conf <<EOF
#!/bin/bash
modprobe -- br_netfilter
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF

chmod 755 /etc/modprobe.d/k8s.conf && \
bash /etc/modprobe.d/k8s.conf && \
lsmod | grep -E "ip_vs|nf_conntrack_ipv4"

```

> 这些内核模块主要用于后续将kube-proxy的代理模式从iptables切换至ipvs

> 在linux kernel 4.19版本已经将nf_conntrack_ipv4 更新为 nf_conntrack，如果在加载内核时出现如下报错：`modprobe: FATAL: Module nf_conntrack_ipv4 not found.`，则将nf_conntrack_ipv4 改为nf_conntrack即可



修改内核参数：

```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
vm.swappiness = 0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
fs.may_detach_mounts = 1
EOF

sysctl -p /etc/sysctl.d/k8s.conf

```

> 如果出现sysctl: cannot stat /proc/sys/net/bridge/bridge-nf-call-ip6tables: No Such file or directory这样的错误，可以忽略



bridge-nf 使 netfilter 可以对 Linux 网桥上的 IPv4/ARP/IPv6 包过滤。比如，设置`net.bridge.bridge-nf-call-iptables=1`后，二层的网桥在转发包时也会被 iptables的 FORWARD 规则所过滤。常用的选项包括： 

- net.bridge.bridge-nf-call-arptables：是否在 arptables 的 FORWARD 中过滤网桥的 ARP 包
- net.bridge.bridge-nf-call-ip6tables：是否在 ip6tables 链中过滤 IPv6 包
- net.bridge.bridge-nf-call-iptables：是否在 iptables 链中过滤 IPv4 包
- net.bridge.bridge-nf-filter-vlan-tagged：是否在 iptables/arptables 中过滤打了 vlan 标签的包。
- fs.may_detach_mounts：centos7.4引入的新内核参数，用于在容器场景防止挂载点泄露





安装containerd：

```
yum install -y yum-utils device-mapper-persistent-data lvm2

yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo

yum install -y containerd.io

# 生成containerd的配置文件

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 修改/etc/containerd.config.toml配置文件以下内容： 
......
[plugins]
  ......
  [plugins."io.containerd.grpc.v1.cri"]
    ...
    #sandbox_image = "k8s.gcr.io/pause:3.2"
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.7"
    ...
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      ...
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            ...
            SystemdCgroup = true #对于使用 systemd 作为 init system 的 Linux 的发行版，使用 systemd 作为容器的 cgroup driver 可以确保节点在资源紧张的情况更加稳定
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://pqbap4ya.mirror.aliyuncs.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]  
        ......
        
systemctl enable containerd --now

# 验证
ctr version 


```

安装kubeadm、kubelet、kubectl：

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum list kubeadm --showduplicates

yum install -y kubelet-1.24.3 kubeadm-1.24.3 kubectl-1.24.3
systemctl enable kubelet  # 注意: 在这里kubelet是无法正常启动的，只是确保其可以开机自启

```

## 部署master

部署master，只需要在master节点上配置，包含的过程如下：

- 生成kubeadm.yaml文件
- 编辑kubeadm.yaml文件
- 根据配置的kubeadm.yaml文件部署master



通过如下指令创建默认的kubeadm.yaml文件：

```
kubeadm config print init-defaults   > kubeadm.yaml
```

修改kubeadm.yaml文件如下：

```YAML
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 172.26.159.93 # 设置master节点的ip地址
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock # 设置containerd的连接套接字
  imagePullPolicy: IfNotPresent
  name: 172.26.159.93 # 指定master的主机名
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers  # 指定下载master组件镜像的镜像仓库地址
kind: ClusterConfiguration
kubernetesVersion: 1.24.3
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16  # 指定pod ip的网段
scheduler: {}
```

拉取镜像： 

```Bash
kubeadm config images pull --config kubeadm.yaml
```



安装master节点：

```
kubeadm init --config kubeadm.yaml
```

此时如下看到类似如下输出即代表master安装完成： 

```Bash
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.0.180:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:cad3fa778559b724dff47bb1ad427bd39d97dd76e934b9467507a2eb990a50c7
```



配置访问集群：

```
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -u) $HOME/.kube/config
```

## 配置网络

在master完成部署之后，发现两个问题：

1. master节点一直notready
2. coredns pod一直pending

其实这两个问题都是因为还没有安装网络插件导致的，kubernetes支持众多的网络插件，详情可参考这里： https://kubernetes.io/docs/concepts/cluster-administration/addons/

我们这里使用calico网络插件，安装如下： 

```
curl https://raw.githubusercontent.com/projectcalico/calico/v3.24.0/manifests/calico.yaml -O

kubectl apply -f calico.yaml

```

> 参考：[https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less](https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less)

> 安装网络插件，也只需要在master节点上操作即可



部署完成后，可以通过如下指令验证组件是否正常： 

检查master组件是否正常：

```Bash
# kubectl get pods -n kube-system
NAME                                               READY   STATUS    RESTARTS   AGE
calico-kube-controllers-58497c65d5-f48xk           1/1     Running   0          94s
calico-node-nh4xb                                  1/1     Running   0          94s
coredns-7f6cbbb7b8-7r558                           1/1     Running   0          4m45s
coredns-7f6cbbb7b8-vr58g                           1/1     Running   0          4m45s2
etcd-192.168.0.180                                 1/1     Running   0          4m54s
kube-apiserver-192.168.0.180                       1/1     Running   0          4m54s
kube-controller-manager-192.168.0.180              1/1     Running   0          5m
kube-proxy-wx49q                                   1/1     Running   0          4m45s
kube-scheduler-192.168.0.180                       1/1     Running   0          4m54s
```

查看节点状态： 

```Bash
# kubectl get nodes
NAME    STATUS   ROLES                  AGE     VERSION
k8s01   Ready    control-plane,master   4m59s   v1.23.0
```

## 添加worker节点



在master节点上，当master部署成功时，会返回类似如下信息：

```
kubeadm join 192.168.0.180:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:cad3fa778559b724dff47bb1ad427bd39d97dd76e934b9467507a2eb990a50c7 --node-name 192.168.0.41
```

即可完成节点的添加

> 需要说明的是，以上指令中的token有效期只有24小时，当token失效以后，可以使用`kubeadm token create --print-join-command`生成新的添加节点指令

> `—node-name`用于指定要添加的节点的名称



# 集群维护

这里主要包含两部分内容： 

- 集群重置  
- 集群升级

## 集群重置

在安装过程中，我们会遇到一些问题，这个时候可以把集群重置，推倒重来。

```
# 重置集群
kubeadm reset
# 停止kubelet
systemctl stop kubelet
# 删除已经部署的容器
crictl  --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -aq |xargs crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock rm 
# 清理所有目录
rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /var/lib/cni/
```



## 集群升级

## 注意事项

1. 使用kubeadm升级集群，不支持跨版本升级
2. swap必须关闭
3. 注意数据备份。虽然kubeadm upgrade操作不会触碰你的工作负载，只会更新kubernetes的组件，但任何时候，备份都是最佳实践。
4. 节点更新完成后，其上的所有容器都会被重启

## 操作升级

### 1. 升级master节点

检查可用的kubeadm版本

```
# ubuntu

apt update 
apt-cache madison kubeadm

# centos
yum list --showduplicates kubeadm --disableexcludes=kubernetes

```

更新kubeadm软件包

```
# ubuntu

apt update
apt upgrade -y  kubeadm=1.24.3-00

# centos

yum update -y kubeadm-1.24.3-0

```

排干要更新的节点： 

```
# 这里以master节点为例
kubectl drain 172.26.159.93 --ignore-daemonsets
```

创建升级计划： 

```
kubeadm upgrade plan
```

按照提示执行升级： 

```
kubeadm upgrade apply v1.24.3
```

看到如下提示，即说明升级完成： 

```Bash
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.22.1". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```



将节点重新设置为可调度： 

```
kubectl uncordon k8s01
```

如果有多个master节点，升级其他Master节点， 直接执行如下操作即可: 

```
kubeadm upgrade node
```

升级kubelet和kubectl 

```
# ubuntu
apt update
apt upgrade -y kubelet=1.24.3-00 kubectl=1.24.3-00

# centos
yum update -y kubelet-1.24.3-0 kubectl-1.24.3-0
```

重启kubelet

```
systemctl daemon-reload
systemctl restart kubelet 
```



### 2. 升级worker



```
# 在woker节点上升级kubeadm
yum upgrade kubeadm-1.24.3-0 -y

# 在master节点上排干要升级的worker节点
kubectl drain k8s02

# 在worker节点上执行升级操作
kubectl upgrade node 

# 在worker节点上更新kubelet和kubectl
yum upgrade kubelet-1.24.3-0 kubectl-1.24.3-0

# 重启worker节点上的kubelet
systemctl daemon_reload
systemctl restart kubelet

# 在master节点上取消worker节点的不可调度设置
kubectl uncordon 172.26.159.94

```

>  参考： [https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)



# 附录

用于记录在操作过程中所出现的一些问题。

## 1. calico-node在master上无法启动问题

pod状态： 

```
calico-node-hhl5j                          0/1     Running   0          3h54m
```

报错如下： 

```
Events:
  Type     Reason     Age                       From     Message
  ----     ------     ----                      ----     -------
  Warning  Unhealthy  4m38s (x1371 over 3h52m)  kubelet  (combined from similar events): Readiness probe failed: 2021-08-07 09:43:25.755 [INFO][1038] confd/health.go 180: Number of node(s) with BGP peering established = 0
calico/node is not ready: BIRD is not ready: BGP not established with 192.168.0.41,192.168.0.241
```

解决方法： 

调整calicao的网络插件的网卡发现机制，修改IP_AUTODETECTION_METHOD对应的value值。

默认情况下，官方提供的yaml文件中，ip识别策略（IPDETECTMETHOD）没有配置，即默认为first-found，这会导致一个网络异常的ip作为nodeIP被注册，从而影响node之间的网络连接。可以修改成can-reach或者interface的策略，尝试连接某一个Ready的node的IP，以此选择出正确的IP。

打开calico.yaml，找到`CLUSTER_TYPE`，配置项，在其下添加一个变量配置，示例如下： 

```
# Cluster type to identify the deployment type
- name: CLUSTER_TYPE
  value: "k8s,bgp"
# 要添加的配置项
- name: IP_AUTODETECTION_METHOD
  value: "interface=eth0"
```

然后重新apply calico.yaml即可： 

```
kubectl apply -f calico.yaml
```



## 2. podip网段问题

在kubernetes安装完成之后，我们检查coredns的ip地址，操作如下： 

```Bash
kubectl get pods -o wide -n kube-system |grep coredns
```

可能会看到coredns pod的地址为10.88.xx.xx网段， 但我们配置的podSubnet为10.244.0.0/16。这是因为containerd自带了一个cni配置： 10-containerd-net.conflist；同时可以看到宿主机上还有一个cni0的网桥。使用了这个网络配置的pod是无法跨主机通信的。所以我们需要执行如下操作删除该网络配置并删除该网桥： 

```Bash
mv /etc/cni/net.d/10-containerd-net.conflist /etc/cni/net.d/10-containerd-net.conflist.bak
ifconfig cni0 down && ip link delete cni0
systemctl daemon-reload
systemctl restart containerd kubelet
```

然后重建coredns即可： 

```Bash
kubectl get pods -n kube-system |grep coredns | awk '{print $1}'|xargs kubectl delete po -n kube-system 
```



## 3. 拉取镜像异常

在执行`kubeadmin config images pull —config kubeadm.yaml`时出现如下异常： 

```Bash
failed to pull image "registry.aliyuncs.com/google_containers/kube-apiserver:v1.24.3": output: E0820 23:04:41.007978    7450 remote_image.go:218] "PullImage from image service failed" err="rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.ImageService" image="registry.aliyuncs.com/google_containers/kube-apiserver:v1.24.3"
time="2022-08-20T23:04:41+08:00" level=fatal msg="pulling image: rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.ImageService"
, error: exit status 1
To see the stack trace of this error execute with --v=5 or higher
```

需要修改`/etc/containerd/config.toml`如下： 

```Bash
 [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
   SystemdCgroup = true # 添加该配置
      ...
      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        ...
        runtime_type = "io.containerd.runtime.v1.linux"
```

然后重启containerd: 

```YAML
systemctl restart containerd
```

## 4. 部署时提示内核模块加载异常

在执行`kubeadm init —config kubeadm.yaml`时出现如下错误： 

```YAML
root@k8s01:~# kubeadm init --config kubeadm.yaml 
[init] Using Kubernetes version: v1.24.6
[preflight] Running pre-flight checks
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables does not exist
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
To see the stack trace of this error execute with --v=5 or higher
```

解决方法： 

```YAML
modprobe br_netfilter
```