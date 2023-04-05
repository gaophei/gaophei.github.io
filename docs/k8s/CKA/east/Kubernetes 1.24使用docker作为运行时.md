从kubernetes 1.24开始，dockershim已经从kubelet中移除，但因为历史问题docker却不支持kubernetes主推的CRI（容器运行时接口）标准，所以docker不能再作为kubernetes的容器运行时了，即从kubernetesv1.24开始不再使用docker了。

但是如果想继续使用docker的话，可以在kubelet和docker之间加上一个中间层cri-docker。cri-docker是一个支持CRI标准的shim（垫片）。一头通过CRI跟kubelet交互，另一头跟docker api交互，从而间接的实现了kubernetes以docker作为容器运行时。但是这种架构缺点也很明显，调用链更长，效率更低。

![](https://secure2.wostatic.cn/static/tymfdxUUuE47vHJeBQVYMd/image.png?auth_key=1680618536-j5guKC82GhTWB8MFSEH4mD-0-1170b92beed8183b8d2e4b4643c4f389)

# 安装docker

> 在所有节点安装

```Bash
# 安装docker
yum install -y docker-ce 

# 生成docker配置文件
{
  "registry-mirrors": ["https://o0o4czij.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}

# 启动docker
systemctl enable docker --now
```



# 安装cri-docker

> 在所有节点安装

cri-docker的代码托管地址： [Mirantis/cri-dockerd (github.com)](https://github.com/Mirantis/cri-dockerd)

```Bash
wget https://breezey-public.oss-cn-zhangjiakou.aliyuncs.com/softwares/linux/docker/cri-dockerd-0.2.6.amd64.tgz

tar xf cri-dockerd-0.2.6.amd64.tgz

cp cri-dockerd/cri-dockerd /usr/bin/

```



cri-docker的启动文件有两个： 

- cri-docker.service
- cri-docker.socket

这两个文件可以在cir-docker的源代码目录packaging/systemd中找到，但是cri-docker.service的启动项还要做如下修改： 

```Go
ExecStart=/usr/bin/cri-dockerd --network-plugin=cni --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.7
```

说明：

- 在kubernetes中使用，必须要指定—network-plugin=cni
- 通过指定—pod-infra-container-image指定pause镜像地址



启动cri-docker并设置开机自启： 

```Bash
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket
systemctl start cri-docker
```



# 安装kubernetes

> 在master上执行

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
  criSocket: unix:///var/run/cri-dockerd.sock # 设置cri-docker的连接套接字
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

执行部署： 

```Bash
kubeadm init --config=kubeadm.yaml
```

添加节点配置如下： 

```Bash
kubeadm join 192.168.0.180:6443 --token cjb89t.io9c7dev0huiyuwk --discovery-token-ca-cert-hash sha256:e5280f1d03a526e2cbf803931aa0601a46b76f53fb9f8beb1255deb59dbd17e5 --node-name 10.64.132.5 --cri-socket unix:///var/run/cri-dockerd.sock
```

# 附录

## 指定`—pod-infra-container-image`配置项

如果不通过—pod-infra-container-image指定pause镜像地址，则会抛出如下异常：

```Bash
Events:
  Type     Reason                  Age   From               Message
  ----     ------                  ----  ----               -------
  Normal   Scheduled               12s   default-scheduler  Successfully assigned kube-system/calico-node-4vssv to 10.64.132.5
  Warning  FailedCreatePodSandBox  8s    kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed pulling image "k8s.gcr.io/pause:3.1": Error response from daemon: Get "https://k8s.gcr.io/v2/": dial tcp 108.177.97.82:443: connect: connection timed out
```



## 参考

- [配置cri-docker使kubernetes1.24以docker作为运行时](https://blog.csdn.net/lduan_001/article/details/125198823)
- [cri-docker安装 - OrcHome](https://www.orchome.com/16593)