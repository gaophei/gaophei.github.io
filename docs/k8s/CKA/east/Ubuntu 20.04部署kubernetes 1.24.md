## 环境准备

准备工作需要在所有节点上操作，包含的过程如下： 

- 配置主机名
- 添加/etc/hosts
- 清空防火墙
- 设置apt源
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

添加/etc/hosts:

```
# k8s01
echo "172.26.159.93 k8s01" >> /etc/hosts
# k8s02
echo "172.26.159.94 k8s02" >> /etc/hosts
# k8s03
echo "172.26.159.95 k8s03" >> /etc/hosts

```

清空防火墙规则

```
iptables -F

iptables -t nat -F
```

设置apt源：

```
cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse

# deb https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

apt update -y 


```



配置时间同步： 

```Bash
apt install -y chrony 
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
cat > /etc/modules-load.d/modules.conf<<EOF
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

for i in br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack;do modprobe $i;done

```

> 这些内核模块主要用于后续将kube-proxy的代理模式从iptables切换至ipvs



修改内核参数：

```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
vm.swappiness = 0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl -p /etc/sysctl.d/k8s.conf

```

> 如果出现sysctl: cannot stat /proc/sys/net/bridge/bridge-nf-call-ip6tables: No Such file or directory这样的错误，说明没有先加载内核模块br_netfilter。

bridge-nf 使 netfilter 可以对 Linux 网桥上的 IPv4/ARP/IPv6 包过滤。比如，设置`net.bridge.bridge-nf-call-iptables=1`后，二层的网桥在转发包时也会被 iptables的 FORWARD 规则所过滤。常用的选项包括： 

- net.bridge.bridge-nf-call-arptables：是否在 arptables 的 FORWARD 中过滤网桥的 ARP 包
- net.bridge.bridge-nf-call-ip6tables：是否在 ip6tables 链中过滤 IPv6 包
- net.bridge.bridge-nf-call-iptables：是否在 iptables 链中过滤 IPv4 包
- net.bridge.bridge-nf-filter-vlan-tagged：是否在 iptables/arptables 中过滤打了 vlan 标签的包。





安装containerd：

```

apt-get update -y && \
apt-get -y install apt-transport-https ca-certificates curl software-properties-common && \
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add - && \
add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" && \
apt-get -y update && \
apt-get -y install containerd.io


# 生成containerd的配置文件

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 修改/etc/containerd.config.toml配置文件以下内容： 
......
[plugins]
  ......
  [plugins."io.containerd.grpc.v1.cri"]
    ...
    #sandbox_image = "k8s.gcr.io/pause:3.6"
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.7"
    ...
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      ...
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
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
apt-get update && apt-get install -y apt-transport-https && \
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - && \
cat > /etc/apt/sources.list.d/kubernetes.list<<EOF 
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt update -y && \
apt-cache madison kubeadm && \
apt install -y kubelet=1.24.6-00  kubeadm=1.24.6-00  kubectl=1.24.6-00  && \
systemctl enable kubelet

```

## 部署master

部署master，只需要在master节点上配置，包含的过程如下：

- 生成kubeadm-config.yaml文件
- 编辑kubeadm-config.yaml文件
- 根据配置的kubeadm-config.yaml文件部署master



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
  advertiseAddress:  172.26.159.93 # 设置master节点的ip地址
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock # 设置containerd的连接套接字
  imagePullPolicy: IfNotPresent
  name: k8s01 # 指定master的主机名
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
kubernetesVersion: 1.24.6
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
curl https://docs.projectcalico.org/manifests/calico.yaml -O

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
coredns-7f6cbbb7b8-vr58g                           1/1     Running   0          4m45s
etcd-192.168.0.180                                 1/1     Running   0          4m54s
kube-apiserver-192.168.0.180                       1/1     Running   0          4m54s
kube-controller-manager-192.168.0.180              1/1     Running   0          5m
kube-proxy-wx49q                                   1/1     Running   0          4m45s
kube-scheduler-192.168.0.180                       1/1     Running   0          4m54s
```

查看节点状态： 

```Bash
# kubectl get nodes
NAME            STATUS   ROLES                  AGE     VERSION
192.168.0.180   Ready    control-plane,master   4m59s   v1.22.0
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



# 配置ingress





# 安装nfs-csi



安装nfs： 

```Bash
apt install -y nfs-kernel-server

mkdir -p /data
chmod 777 /data -R

echo "/data *(rw,sync,no_root_squash)" >> /etc/exports

systemctl enable nfs-server
systemctl restart nfs-server

# 验证
showmount -e 172.26.159.93
```



安装nfs-csi：

```Bash
wget https://breezey-public.oss-cn-zhangjiakou.aliyuncs.com/tmp/nfs-csi.tar.gz
tar xf nfs-csi.tar.gz
kubectl apply -f v3.1.0
```



配置storage：

```YAML
# nfs-csi.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: csi-hostpath-sc
mountOptions:
- hard
- nfsvers=4.0
parameters:
  server: 172.26.159.93
  share: /data
provisioner: nfs.csi.k8s.io
reclaimPolicy: Delete
volumeBindingMode: Immediate

# 部署
kubectl apply -f nfs-csi.yaml
```

测试创建pvc： 

```YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 8Gi
  storageClassName: csi-hostpath-sc
```

使用pvc：

```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: busybox
  name: busybox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: busybox
  strategy: {}
  template:
    metadata:
      labels:
        app: busybox
    spec:
      volumes:
      - name: test
        persistentVolumeClaim:
          claimName: myclaim
      containers:
      - image: busybox:1.28
        name: busybox
        volumeMounts:
        - name: test
          mountPath: /data
        command: 
        - /bin/sh
        - -c
        - "sleep 3600"
        resources: {}
```



# 附录

在执行`kubeadm config images pull —config kubeadm.yaml`时出现如下异常： 

```Bash
failed to pull image "registry.aliyuncs.com/google_containers/kube-apiserver:v1.24.3": output: E0820 23:04:41.007978    7450 remote_image.go:218] "PullImage from image service failed" err="rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.ImageService" image="registry.aliyuncs.com/google_containers/kube-apiserver:v1.24.3"
time="2022-08-20T23:04:41+08:00" level=fatal msg="pulling image: rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.ImageService"
, error: exit status 1
To see the stack trace of this error execute with --v=5 or higher
```

需要修改`/etc/containerd/config.toml`如下： 

```Bash
      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        ...
        runtime_type = "io.containerd.runtime.v1.linux"
```

然后重启containerd: 

```YAML
systemctl restart containerd
```



在执行kubeadm init —config yaml时出错，kubelet 抛出如下异常： 

```YAML
root@k8s01:~# journalctl -xe -u kubelet 
1365   12377 kubelet_node_status.go:70] "Attempting to register node" node="k8s01"
1630   12377 kubelet_node_status.go:92] "Unable to register node with API server" err="Post \"https://172.26.>3821   12377 kubelet.go:2424] "Error getting node" err="node \"k8s01\" not found"
5521   12377 reflector.go:324] vendor/k8s.io/client-go/informers/factory.go:134: failed to list *v1.Service: >5569   12377 reflector.go:138] vendor/k8s.io/client-go/informers/factory.go:134: Failed to watch *v1.Service:>4782   12377 kubelet.go:2424] "Error getting node" err="node \"k8s01\" not found"
```



进一步检查 containerd的日志，有如下异常： 

```YAML
box for &PodSandboxMetadata{Name:kube-controller-manager-k8s01,Uid:442564a9a3387a3cfb3eff3a22c04e1f,Namespace>box for &PodSandboxMetadata{Name:kube-scheduler-k8s01,Uid:233150635540b26cd6ef074fe008014c,Namespace:kube-sys>t host" error="failed to do request: Head \"https://k8s.gcr.io/v2/pause/manifests/3.7\": dial tcp 142.250.157>dbox for &PodSandboxMetadata{Name:etcd-k8s01,Uid:7015b34aae829f2c642db4efe16bdb75,Namespace:kube-system,Attem>t host" error="failed to do request: Head \"https://k8s.gcr.io/v2/pause/manifests/3.7\": dial tcp 142.250.157>dbox for &PodSandboxMetadata{Name:kube-apiserver-k8s01,Uid:11ebe35165cc34f039475769cced894b,Namespace:kube-sy>t host" error="failed to do request: Head \"https://k8s.gcr.io/v2/pause/manifests/3.7\": dial tcp 142.250.157>dbox for &PodSandboxMetadata{Name:kube-controller-manager-k8s01,Uid:442564a9a3387a3cfb3eff3a22c04e1f,Namespac>t host" error="failed to do request: Head \"https://k8s.gcr.io/v2/pause/manifests/3.7\": dial tcp 142.250.157>dbox for &PodSandboxMetadata{Name:kube-scheduler-k8s01,Uid:233150635540b26cd6ef074fe008014c,Namespace:kube-sy
```