我们在kubernetes 1.23单mster集群部署一文中详细说明了使用kubeadm与containerd部署一个单master的集群。事实上在生产环境中基本都是多master部署以确保控制面的可用性。这篇文档的重点是使用kube-vip配置kubernetes master节点的高可用性。

控制面组件包括： 

- etcd
- kube-apiserver
- kube-controller-manager
- kube-scheduler

其中kube-controller-manager和kube-scheduler是 Kubernetes 集群自己去实现高可用，当有多个节点部署的时候，会自动选择一个作为 Leader 提供服务，不需要我们做额外处理。而etcd和kube-apiserver需要我们去保证高可用。etcd有官方的集群配置，而kube-apiserver属于无状态服务，可以通过为其配置haproxy+keepalived这种常规的负载均衡与vip的方式实现其可用性，示意图如下： 

![](https://secure2.wostatic.cn/static/cGpkQiEtXFK9bXQTRZZrif/image.png?auth_key=1680618461-4N6ko5ucHiweDYUZnzXUg-0-b086389b0b3e7f8d50eb5ed2c4c18486)

也可以使用较新颖的工具，比如kube-vip。

kube-vip的官方地址： [https://kube-vip.io/](https://kube-vip.io/)
kube-vip的代码托管地址： [https://github.com/kube-vip/kube-vip](https://github.com/kube-vip/kube-vip)

kube-vip与传统的haproxy+ keepalived这种负载均衡方式最大的不同就是其可以在控制平面节点上提供一个 Kubernetes 原生的 HA 负载均衡，这样就不需要额外的节点来部署haproxy+keepalived提供负载均衡服务了。示意图如下： 

![](https://secure2.wostatic.cn/static/fTqdrnedJjasDdME7v8Hzh/image.png?auth_key=1680618461-6rc4tgr3QGG3KPnaGkUNzp-0-510bdb64f2f251a59767aab34600faa3)

kube-vip 可以以静态 pod的方式 运行在控制面节点上，这些 pod 通过 ARP 会话来识别其他节点，其支持设置模式： 

- BGP：在这种模式下，所有节点都会绑定一个vip，然后通过bgp协议与物理网络上的三层交换建立邻居实现流量的均衡转发
- ARP：在这种模式下，会先出一个leader，leader节点会继承vip并成为集群内负载均衡的leader

这里使用arp模式，在这种模式下，leader将分配vip，并将其绑定到配置中声明的选定接口上。当 Leader 改变时，它将首先撤销 vip，或者在失败的情况下，vip 将直接由下一个当选的 Leader 分配。当 vip 从一个主机移动到另一个主机时，任何使用 vip 的主机将保留以前的 `vip <-> MAC` 地址映射，直到 ARP 过期（通常是30秒）并检索到一个新的 `vip <-> MAC` 映射，这可以通过使用无偿的 ARP 广播来优化。

kube-vip 可以被配置为广播一个无偿的 arp（可选），通常会立即通知所有本地主机 `vip <-> MAC` 地址映射已经改变： 

![](https://secure2.wostatic.cn/static/vfAFxdvrKby1ZRBLWt62KZ/image.png?auth_key=1680618461-vn37UmnwA4wLMGcaucgwE2-0-fed7b221b14a4629bbe52acafacbe1fd)



> kube-vip除了可以用作kubernetes 控制面的负载均衡，还可以以daemonset的方式部署用以替代kube-proxy



# 环境说明

| 主机名 | ip地址        | 节点类型             | 系统版本 |
| ------ | ------------- | -------------------- | -------- |
| k8s01  | 192.168.0.180 | master、etcd、worker | centos7  |
| k8s02  | 192.168.0.41  | master、etcd、worker | centos7  |
| k8s03  | 192.168.0.241 | master、etcd、worker | centos7  |


# 配置kube-vip 

kube-vip的配置文件需要在安装kubernetes的控制面节点之前准备好，然后在安装控制面时一起安装。

关于安装kubernetes时的环境准备工作已经在kubernetes 1.23单mster集群部署一文中有过详细说明，这里不再赘述。准备好环境之后，可以开始为kube-vip生成相应的部署文件。在这里kube-vip以静态pod的方式部署，所以先在其中一个master节点上生成kube-vip，这里就使用k8s01：

```Bash
# 创建静态pod目录
mkdir -p /etc/kubernetes/manifests/
# 拉取镜像
ctr image pull docker.io/plndr/kube-vip:v0.3.8
# 使用下面的容器输出静态Pod资源清单
ctr run --rm --net-host docker.io/plndr/kube-vip:v0.3.8 vip \
/kube-vip manifest pod \
--interface eth0 \
--vip 192.168.0.100 \
--controlplane \
--services \
--arp \
--leaderElection | tee  /etc/kubernetes/manifests/kube-vip.yaml
```

选项说明： 

- `manifest`： 指定生成的配置文件类型，指定为pod则 用于生成静态pod的配置；指定为daemonset用于生成daemonset的配置
- `—interface`：指定vip绑定的网卡名称，需要指定master节点内网网卡
- `—vip`:  指定要绑定的vip的地址
- `—controlplane`：为控制面开启ha
- `—services`：开启kubernetes服务
- `—arp`：将kube-api启动为arp模式
- `—leaderElection`：为集群启用领导者选举机制

生成的kube-vip.yaml内容如下： 

```YAML
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-vip
  namespace: kube-system
spec:
  containers:
  - args:
    - manager
    env:
    - name: vip_arp
      value: "true"
    - name: vip_interface
      value: eth0
    - name: port
      value: "6443"
    - name: vip_cidr
      value: "32"
    - name: cp_enable
      value: "true"
    - name: cp_namespace
      value: kube-system
    - name: vip_ddns
      value: "false"
    - name: svc_enable
      value: "true"
    - name: vip_leaderelection
      value: "true"
    - name: vip_leaseduration
      value: "5"
    - name: vip_renewdeadline
      value: "3"
    - name: vip_retryperiod
      value: "1"
    - name: vip_address
      value: 192.168.0.100
    image: ghcr.io/kube-vip/kube-vip:v0.3.8
    imagePullPolicy: Always
    name: kube-vip
    resources: {}
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_RAW
        - SYS_TIME
    volumeMounts:
    - mountPath: /etc/kubernetes/admin.conf
      name: kubeconfig
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/admin.conf
    name: kubeconfig
status: {}
```



# 部署控制面

使用如下指令生成部署配置文件： 

```Bash
kubeadm config print init-defaults --component-configs KubeletConfiguration --component-configs KubeProxyConfiguration  > kubeadm.yaml
```

修改kubeadm.yaml内容如下： 

```YAML
# cat kubeadm.yaml
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
  advertiseAddress: 192.168.0.180    # 当前master节点的ip
  bindPort: 6443
nodeRegistration:
  criSocket: /run/containerd/containerd.sock # 使用 containerd的Unix socket 地址
  imagePullPolicy: IfNotPresent 
  name: k8s01   # master节点的主机名
  taints: null 
---
apiServer:
  timeoutForControlPlane: 4m0s
  extraArgs:
    authorization-mode: Node,RBAC
  certSANs:  # 添加其他master节点的相关信息
  - k8s01
  - k8s02
  - k8s03
  - 127.0.0.1
  - localhost
  - kubernetes
  - kubernetes.default
  - kubernetes.default.svc
  - kubernetes.default.svc.cluster.local
  - 192.168.0.180
  - 192.168.0.41
  - 192.168.0.241
  - 192.168.0.100
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers   # 镜像仓库地址，k8s.gcr.io在国内无法获取镜像
kind: ClusterConfiguration
kubernetesVersion: 1.22.0  # 指定kubernetes的安装版本
controlPlaneEndpoint: 192.168.0.100:6443 # 指定kube-apiserver的vip地址，也可以指定一个外部域名，该域名需要解析至该vip上
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12  # service的网段
  podSubnet: 10.244.0.0/16   # pod的网段
scheduler: {}
---
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
cgroupDriver: systemd  # 配置cgroup driver为systemd
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
kind: KubeletConfiguration
logging: {}
memorySwap: {}
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
rotateCertificates: true   # 证书自动更新
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 0.0.0.0
bindAddressHardFail: false
clientConnection:
  acceptContentTypes: ""
  burst: 0
  contentType: ""
  kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
  qps: 0
clusterCIDR: ""
configSyncPeriod: 0s
conntrack:
  maxPerCore: null
  min: null
  tcpCloseWaitTimeout: null
  tcpEstablishedTimeout: null
detectLocalMode: ""
enableProfiling: false
healthzBindAddress: ""
hostnameOverride: ""
iptables:
  masqueradeAll: false
  masqueradeBit: null
  minSyncPeriod: 0s
  syncPeriod: 0s
ipvs:
  excludeCIDRs: null
  minSyncPeriod: 0s
  scheduler: ""
  strictARP: false
  syncPeriod: 0s
  tcpFinTimeout: 0s
  tcpTimeout: 0s
  udpTimeout: 0s
kind: KubeProxyConfiguration
metricsBindAddress: ""
mode: "ipvs"  # kube-proxy的转发模式设置为ipvs
nodePortAddresses: null
oomScoreAdj: null
portRange: ""
showHiddenMetricsForVersion: ""
udpIdleTimeout: 0s
winkernel:
  enableDSR: false
  networkName: ""
  sourceVip: ""

```



重点关注如下变更： 

```YAML
controlPlaneEndpoint: 192.168.0.100:6443 # 指定kube-apiserver的vip地址，也可以指定一个外部域名，该域名需要解析至该vip上
apiServer:
  timeoutForControlPlane: 4m0s
  extraArgs:
    authorization-mode: Node,RBAC
  certSANs:  # 添加其他master节点的相关信息
  - k8s01
  - k8s02
  - k8s03
  - 127.0.0.1
  - localhost
  - kubernetes
  - kubernetes.default
  - kubernetes.default.svc
  - kubernetes.default.svc.cluster.local
  - 192.168.0.180
  - 192.168.0.41
  - 192.168.0.241
  - 192.168.0.100 
```



kubeadm.yaml文件配置完成后，可执行如下指令拉取kubernetes部署所要用到的镜像 ： 

```Bash
kubeadm config images pull --config kubeadm.yaml
```

如果出现报错，可以参考kubernetes 1.23单mster集群部署相关操作进行修复。



执行安装： 

```Bash
kubeadm init --upload-certs --config kubeadm.yaml
```

部署成功后会返回类似如下信息： 

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

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 192.168.0.100:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1f10cff6e4038f91b1569805e740a0cdfb10ae3001e5ba5343d7eebe9148e2c5 \
        --control-plane --certificate-key 281e7bcf740f838aff526f5a6fd2ff8851defec9c152f214c3b847207e557cbe

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.0.100:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1f10cff6e4038f91b1569805e740a0cdfb10ae3001e5ba5343d7eebe9148e2c5
```



配置访问权限： 

```Bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```



配置网络，这里以calico为例：

```Bash
curl https://docs.projectcalico.org/manifests/calico.yaml -O

kubectl apply -f calico.yaml
```

# 添加其他控制面

注意，由于coredns:v1.8.4镜像无法正常拉取的问题，建议在其他控制节点上优先把该镜像准备好： 

```Bash
ctr -n k8s.io i pull  registry.aliyuncs.com/google_containers/coredns:1.8.4
ctr -n k8s.io i tag registry.aliyuncs.com/google_containers/coredns:1.8.4  registry.aliyuncs.com/google_containers/coredns:v1.8.4
```



使用如下命令添加其他的控制面： 

```Bash
  kubeadm join 192.168.0.100:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1f10cff6e4038f91b1569805e740a0cdfb10ae3001e5ba5343d7eebe9148e2c5 \
        --control-plane --certificate-key 281e7bcf740f838aff526f5a6fd2ff8851defec9c152f214c3b847207e557cbe \
        --cri-socket /run/containerd/containerd.sock
```

该命令在上面第一个master部署成功后打印，然后我们添加了一个`—cri-socket`参数以指定使用containerd作为运行时。需要说明的是，该命令中的`—certificate-key`  的有效期只有2小时，如果超期之后需要执行如下指令重新生成： 

```Bash
# kubeadm init phase upload-certs --upload-certs
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
b3b65d7e6b11803e00f3a141c4e54cb2d9c2c47c8ab3e936088923b92e3dde08
```

此时，我们可以通过如下方式打印完整的添加master的指令： 

```Bash
# kubeadm  token create --certificate-key b3b65d7e6b11803e00f3a141c4e54cb2d9c2c47c8ab3e936088923b92e3dde08 --print-join-command
kubeadm join 192.168.0.100:6443 --token iezp4s.jrv9xommiz42slqf --discovery-token-ca-cert-hash sha256:1f10cff6e4038f91b1569805e740a0cdfb10ae3001e5ba5343d7eebe9148e2c5 --control-plane --certificate-key b3b65d7e6b11803e00f3a141c4e54cb2d9c2c47c8ab3e936088923b92e3dde08
```

同样，在真正执行时，不要忘记添加`—cri-socket`参数。



在添加完控制面节点之后，也需要在这些控制面节点上部署kube-vip，示例如下： 

```Bash
# 创建静态pod目录
mkdir -p /etc/kubernetes/manifests/
# 拉取镜像
ctr image pull docker.io/plndr/kube-vip:v0.3.8
# 使用下面的容器输出静态Pod资源清单
ctr run --rm --net-host docker.io/plndr/kube-vip:v0.3.8 vip \
/kube-vip manifest pod \
--interface eth0 \
--vip 192.168.0.100 \
--controlplane \
--services \
--arp \
--leaderElection | tee  /etc/kubernetes/manifests/kube-vip.yaml
```

此时，kubernetes会自动将kube-vip的pod拉起。至此，控制面添加完成。



数据面的添加和kubernetes 1.23单mster集群部署中的操作完全一致，这里不再赘述。





参考： [https://mp.weixin.qq.com/s/ypIObV4ARzo-DOY81EDc_Q](https://mp.weixin.qq.com/s/ypIObV4ARzo-DOY81EDc_Q)