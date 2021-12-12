## 服务器资源
vm: 4核/8G 

OS: centos7.9(3.10.0-1127)

docker: 19.03.15

ks8: 1.21.7

## 部署过程
### 一、系统优化
#### 0、各个节点的mac地址和product_uuid不能相同
```bash
ip link
cat /sys/class/dmi/id/product_uuid
```
#### 1、Hostname修改
#hostname特殊符号只能含有-和.
```bash
echo "192.168.1.225 master01" >> /etc/hosts
hostnamectl set-hostname master01

hostnamectl status
```
#### 2、关闭防火墙和selinux
```bash
systemctl stop firewalld
systemctl disable firewalld

setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```
#### 3、修改centos源文件
```bash
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

yum clean all && yum makecache all

yum install net-tools  vim git  wget netstat -y 
```
#### 4、开始时间同步及修改东8区
```bash
yum install -y ntpd
systemctl start ntpd
system enable ntpd

date -R
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
```
#### 5、语言修改为utf8
```bash
sudo echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```
#### 6、内核模块调优
##### 1）内核模块
```bash
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
net.ipv4.tcp_rmem=4096 12582912 16777216

###如果学校开启IPv6，则必须为0
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
```
##### 2)open-files
```bash
sudo sed -i 's/4096/90000/g' /etc/security/limits.d/20-nproc.conf

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
```
##### 3)加载模块
```bash
modprobe br_netfilter && modprobe ip6_udp_tunnel && modprobe ip_set;
modprobe ip_set_hash_ip && modprobe ip_set_hash_net;
modprobe iptable_filter && modprobe iptable_nat;
modprobe iptable_mangle && modprobe iptable_raw;
modprobe nf_conntrack_netlink && modprobe nf_conntrack;
modprobe nf_conntrack_ipv4 && modprobe nf_defrag_ipv4;
modprobe nf_nat && modprobe nf_nat_ipv4;
modprobe nf_nat_masquerade_ipv4 && modprobe nfnetlink;
modprobe udp_tunnel && modprobe veth;
modprobe vxlan && modprobe x_tables;
modprobe xt_addrtype && modprobe xt_conntrack;
modprobe xt_comment && modprobe xt_mark;
modprobe xt_multiport && modprobe xt_nat;
modprobe xt_recent && modprobe xt_set;
modprobe xt_statistic && modprobe xt_tcpudp;

sysctl -p

#检查
for module in br_netfilter ip6_udp_tunnel ip_set ip_set_hash_ip ip_set_hash_net iptable_filter iptable_nat iptable_mangle iptable_raw nf_conntrack_netlink nf_conntrack nf_conntrack_ipv4   nf_defrag_ipv4 nf_nat nf_nat_ipv4 nf_nat_masquerade_ipv4 nfnetlink udp_tunnel veth vxlan x_tables xt_addrtype xt_conntrack xt_comment xt_mark xt_multiport xt_nat xt_recent xt_set  xt_statistic xt_tcpudp;
    do
      if ! lsmod | grep -q $module; then
        echo "module $module is not present";
      fi;
    done

```
#### 7、关闭swap分区
```bash
swapoff -a

sed -i 's/\/dev\/mapper\/centos-swap/\#\/dev\/mapper\/centos-swap/g' /etc/fstab
```
### 二、安装docker
#### 1、安装依赖
```bash
sudo yum install -y yum-utils device-mapper-persistent-data lvm2 bash-completion;
```
#### 2、配置源
```bash
sudo yum-config-manager --add-repo \
    https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo;
    
sudo yum makecache all;
```
#### 3、安装docker
```bash
yum list docker-ce.x86_64 --showduplicates

yum -y install docker-ce-19.03.15-3.el7
```
#### 4、优化docker
##### 1)daemon.json
```bash
mkdir /etc/docker
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

systemctl start docker && systemctl enable docker
systemctl status docker
docker info
```
##### 2)docker.service，添加内容
```bash
vi /usr/lib/systemd/system/docker.service
[Service]
OOMScoreAdjust=-1000
ExecStartPost=/sbin/iptables -P FORWARD ACCEPT
```
###重启docker
```bash
systemctl daemon-reload && systemctl restart docker
```
### 三、安装kubeadm/kubectl/kubelet
#### 1、配置源文件
```bash
#设置国内K8S源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
 
#更新缓存
yum clean && yum makecache -y
```
#### 2、安装kubeadm/kubelet/kubectl
```bash
#查看当前版本号
yum list kubeadm.x86_64 --showduplicates
yum list kubelet.x86_64 --showduplicates
yum list kubectl.x86_64 --showduplicates
#安装
yum install -y socat conntrack-tools
yum install -y kubelet-1.21.7-0 kubeadm-1.21.7-0 kubectl-1.21.7-0
 
#设置开机启动Kubelet，但是不要启动kubelet,不然加入集群时会导致kubelet丢失config.yaml文件，导致起不来，就报10248端口连接拒绝
systemctl enable kubelet 
 
#设置Kubelet命令补全
echo "source <(kubectl completion bash)" >> ~/.bash_profile
```
### 四、master节点配置和初始化集群
#### 1、导出默认文件并修改
```bash
mkdir -p /usr/local/docker/kubernetes
cd /usr/local/docker/kubernetes

kubeadm config print init-defaults --component-configs KubeletConfiguration > kubeadm.yaml

vi kubeadm.yaml
```
#根据服务器网络、名称、镜像仓库地址等进行修改
```yaml
apiVersion: kubeadm.k8s.io/v1beta2
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
  advertiseAddress: 192.168.1.225       #master01节点所在IP
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: master01                        #master01节点的hostname
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers      #国内镜像拉取地址
kind: ClusterConfiguration
kubernetesVersion: 1.21.7              #k8s版本
networking:
  dnsDomain: cluster.local
  podSubnet: 10.0.0.0/16               #新增pod子网
  serviceSubnet: 10.96.0.0/12          #svc子网
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
cgroupDriver: cgroupfs
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
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
rotateCertificates: true
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s

```
#### 2、 查看并拉取镜像
```bash
kubeadm config images list
kubeadm config images list --config kubeadm.yaml
```
#如下：
```
[root@master01 kubernetes]# kubeadm config images list
I1209 18:07:50.769452    1335 version.go:254] remote version is much newer: v1.23.0; falling back to: stable-1.21
k8s.gcr.io/kube-apiserver:v1.21.7
k8s.gcr.io/kube-controller-manager:v1.21.7
k8s.gcr.io/kube-scheduler:v1.21.7
k8s.gcr.io/kube-proxy:v1.21.7
k8s.gcr.io/pause:3.4.1
k8s.gcr.io/etcd:3.4.13-0
k8s.gcr.io/coredns/coredns:v1.8.0
[root@master01 kubernetes]# kubeadm config images list --config kubeadm.yaml 
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v1.21.7
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v1.21.7
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.21.7
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v1.21.7
registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.4.1
registry.cn-hangzhou.aliyuncs.com/google_containers/etcd:3.4.13-0
registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:v1.8.0
[root@master01 kubernetes]# 
```
#拉取镜像
```bash
kubeadm config images pull --config kubeadm.yaml
```
#如下：
```
[root@master01 kubernetes]# docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
[root@master01 kubernetes]# kubeadm config images pull --config kubeadm.yaml 
[config/images] Pulled registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v1.21.7
[config/images] Pulled registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v1.21.7
[config/images] Pulled registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.21.7
[config/images] Pulled registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v1.21.7
[config/images] Pulled registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.4.1
[config/images] Pulled registry.cn-hangzhou.aliyuncs.com/google_containers/etcd:3.4.13-0
[config/images] Pulled registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:v1.8.0
[root@master01 kubernetes]# docker images
REPOSITORY                                                                    TAG                 IMAGE ID            CREATED             SIZE
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver            v1.21.7             0f5bfd20d26e        3 weeks ago         126MB
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy                v1.21.7             7e58936d778d        3 weeks ago         104MB
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager   v1.21.7             7a37590177f7        3 weeks ago         120MB
registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler            v1.21.7             c67c2461177d        3 weeks ago         50.9MB
registry.cn-hangzhou.aliyuncs.com/google_containers/pause                     3.4.1               0f8457a4c2ec        11 months ago       683kB
registry.cn-hangzhou.aliyuncs.com/google_containers/coredns                   v1.8.0              296a6d5035e2        13 months ago       42.5MB
registry.cn-hangzhou.aliyuncs.com/google_containers/etcd                      3.4.13-0            0369cf4303ff        15 months ago       253MB
[root@master01 kubernetes]# 
```
#### 3、根据修改好的配置开始初始化
```bash
kubeadm init --config=kubeadm.yaml --upload-certs|tee kubeadm-init.log
```
#看到下面输出：
```
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

kubeadm join 192.168.1.225:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:fd3e962a3a3f1642d7dd540947e6296c0b05478262f4a615ca280fba45a57f3a 
```
#### 4、设置kubeconfig
```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
#### 五、安装calico
#未部署网络插件前，节点状态为NotReady
```
[root@master01 network]# kubectl get nodes
NAME       STATUS   ROLES                  AGE    VERSION
master01   NotReady    control-plane,master   2d5h   v1.21.7
```
#master01节点下载calico
```bash
cd /usr/local/docker/kubernetes/
#50个nodes以内：
curl https://docs.projectcalico.org/manifests/calico.yaml -O
kubectl apply -f calico.yaml
#50个nodes以上
curl https://docs.projectcalico.org/manifests/calico-typha.yaml -o calico.yaml
kubectl apply -f calico.yaml
```
#此时节点为就绪状态
```
[root@master01 network]# kubectl get nodes
NAME       STATUS   ROLES                  AGE    VERSION
master01   Ready    control-plane,master   2d5h   v1.21.7
```
### 六、工作节点加入集群
#工作节点执行上面第一至第三的步骤，然后执行下面语句加入集群
```bash
kubeadm join 192.168.1.225:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:fd3e962a3a3f1642d7dd540947e6296c0b05478262f4a615ca280fba45a57f3a
```
### 七、集群检查
#master节点
```bash
kubectl get nodes
kubectl get pod -A -owide
```
#node节点
```bash
docker ps
docker images
```

### 八、错误处理

#### 1、安装kubeadm时，报缺少依赖：
```
[root@master01 ~]# yum install -y kubelet-1.21.7-0 kubeadm-1.21.7-0 kubectl-1.21.7-0
Loaded plugins: fastestmirror, langpacks
Loading mirror speeds from cached hostfile
docker-ce-stable                                                                                                                                             | 3.5 kB  00:00:00     
kubernetes/signature                                                                                                                                         |  844 B  00:00:00     
kubernetes/signature                                                                                                                                         | 1.4 kB  00:00:00 !!! 
Resolving Dependencies
--> Running transaction check
---> Package kubeadm.x86_64 0:1.21.7-0 will be installed
--> Processing Dependency: kubernetes-cni >= 0.8.6 for package: kubeadm-1.21.7-0.x86_64
--> Processing Dependency: cri-tools >= 1.19.0 for package: kubeadm-1.21.7-0.x86_64
---> Package kubectl.x86_64 0:1.21.7-0 will be installed
---> Package kubelet.x86_64 0:1.21.7-0 will be installed
--> Processing Dependency: socat for package: kubelet-1.21.7-0.x86_64
--> Processing Dependency: conntrack for package: kubelet-1.21.7-0.x86_64
--> Running transaction check
---> Package cri-tools.x86_64 0:1.19.0-0 will be installed
---> Package kubelet.x86_64 0:1.21.7-0 will be installed
--> Processing Dependency: socat for package: kubelet-1.21.7-0.x86_64
--> Processing Dependency: conntrack for package: kubelet-1.21.7-0.x86_64
---> Package kubernetes-cni.x86_64 0:0.8.7-0 will be installed
--> Finished Dependency Resolution
Error: Package: kubelet-1.21.7-0.x86_64 (kubernetes)
           Requires: socat
Error: Package: kubelet-1.21.7-0.x86_64 (kubernetes)
           Requires: conntrack
 You could try using --skip-broken to work around the problem
 You could try running: rpm -Va --nofiles --nodigest
[root@master01 ~]# 
```
#查询socat和conntrack，并安装
```bash
yum search socat
yum search conntrack

yum install -y socat conntrack-tools
```
#### 2、kubeadm config image pull时报错无法拉取相关镜像
#可以查看仓库中镜像的版本号，与需要的版本号对比
#如仓库中镜像版本为coredns:1.8.0，而需要拉取的版本为coredns:v1.8.0
#那么可以先拉取仓库版本，然后修改tag。
```bash
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.8.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.8.0 registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:v1.8.0
```
#### 3、kubeadm init 发生error，中断安装时，可以通过kubeadm reset，然后解决相关错误后重新初始化
```bash
kubeadm reset
rm -rf $HOME/.kube
```
#### 4、网络插件选择
#可以为calico，也可以是flannel(overlay network)，或者canal(calico+flannel)

#### 5、工作节点在集群初始化后超过24小时未加入集群
#默认生成的token，需要在24小时内工作节点加入集群，如果超过24小时，用集群初始化时生成的join命令会无法加入集群，错误如下：
```
[root@harbor ~]# kubeadm join 192.168.1.225:6443 --token abcdef.0123456789abcdef --discovery-token-ca-cert-hash sha256:fd3e962a3a3f1642d7dd540947e6296c0b05478262f4a615ca280fba45a57f3a

[preflight] Running pre-flight checks
error execution phase preflight: couldn't validate the identity of the API Server: could not find a JWS signature in the cluster-info ConfigMap for token ID "abcdef"
To see the stack trace of this error execute with --v=5 or higher
```
#可以重新生成永不过期的token
```bash
[root@master01 kubernetes]# kubeadm token create --print-join-command --ttl=0
kubeadm join 192.168.1.225:6443 --token j3olqw.ndkgddtsyhv0n0j3 --discovery-token-ca-cert-hash sha256:fd3e962a3a3f1642d7dd540947e6296c0b05478262f4a615ca280fba45a57f3a 
```
#### 6、工作节点加入集群时，node节点报错：
```bash
kubectl describe node node01
```
```
  Warning  ImageGCFailed            16m                 kubelet     wanted to free 12912347545 bytes, but freed 0 bytes space with errors in image deletion: [rpc error: code = Unknown desc = Error response from daemon: conflict: unable to remove repository reference "goharbor/harbor-db:v2.1.1" (must force) - container f629ea86b5fa is using its referenced image 1989b7290300, rpc error: code = Unknown desc = Error response from daemon: conflict: unable to remove repository reference "goharbor/nginx-photon:v2.1.1" (must force) - container db8d0bf6264a is using its referenced image 88bf58494701, rpc error: code = Unknown desc = Error response from daemon: confl
```
  #在node节点查看kubelet日志
```bash
  journalctl -f -u kubelet.service
```
  #进行慎用
```docker
  docker system prune
```
  #重启kubelet和docker
```bash
  systemctl stop kubelet
  systemctl stop docker
  systemctl start docker
  systemctl start kubelet
```
  #此时检查node节点状态，正常
```bash
  kubectl describe node node01
```
  #日志如下
```
  Events:
  Type     Reason                   Age                From        Message
  ----     ------                   ----               ----        -------
  Normal   Starting                 55m                kubelet     Starting kubelet.
  Normal   NodeHasSufficientMemory  55m (x2 over 55m)  kubelet     Node node01 status is now: NodeHasSufficientMemory
  Normal   NodeHasNoDiskPressure    55m (x2 over 55m)  kubelet     Node node01 status is now: NodeHasNoDiskPressure
  Normal   NodeHasSufficientPID     55m (x2 over 55m)  kubelet     Node node01 status is now: NodeHasSufficientPID
  Warning  Rebooted                 55m                kubelet     Node node01 has been rebooted, boot id: c3a6e1b4-1f68-4d48-8a74-627bea4bc923
  Normal   NodeNotReady             55m                kubelet     Node node01 status is now: NodeNotReady
  Normal   NodeAllocatableEnforced  55m                kubelet     Updated Node Allocatable limit across pods
  Normal   Starting                 55m                kube-proxy  Starting kube-proxy.
  Normal   NodeReady                54m                kubelet     Node node01 status is now: NodeReady
```
#### 7、k8s集群可以导入rancher进行管理，但是不能再添加节点。导入rancher后报controller-manager和scheduler组件不健康
#加入rancher脚本命令
```bash
#Rancher:
      kubectl apply -f https://rancher.xxx.edu.cn/v3/import/2blmlz589jtpxrh9cg4q7cc8g4mq5w9dz95c9xh8q2zxxzgsl8fjvl_c-66lj7.yaml    
#Rancher-自签名证书:
      curl --insecure -sfL https://rancher.xxx.edu.cn/v3/import/2blmlz589jtpxrh9cg4q7cc8g4mq5w9dz95c9xh8q2zxxzgsl8fjvl_c-66lj7.yaml | kubectl apply -f -    
```
#加入rancher后组件报错：

![err1.png](k8serr\err1.png)

#master节点上查询cs

```
[root@master01 manifests]# kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS      MESSAGE                                                                                       ERROR
controller-manager   Unhealthy   Get "http://127.0.0.1:10252/healthz": dial tcp 127.0.0.1:10252: connect: connection refused   
scheduler            Unhealthy   Get "http://127.0.0.1:10251/healthz": dial tcp 127.0.0.1:10251: connect: connection refused   
etcd-0               Healthy     {"health":"true"}                                        
```

#解决办法：

#找到master节点上的两个文件，去掉中间的- --port=0，并重启kubelet

```
/etc/kubernetes/manifests/kube-controller-manager.yaml
/etc/kubernetes/manifests/kube-scheduler.yaml
```
```bash
systemctl restart kubelet
```
#此时组件恢复正常

![normal.png](k8serr\normal.png)

```
[root@master01 manifests]# kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok                  
scheduler            Healthy   ok                  
etcd-0               Healthy   {"health":"true"}  
```

#### 8、cgroup驱动，默认为cgroupfs，可以修改为systemd
#kubeadm init前操作，否则kubeadm init时提示：
```
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
```
#在/etc/docker/daemon.json中添加一项
```
exec-opts": ["native.cgroupdriver=cgroupfs"]
```
#重启docker
```bash
systemctl daemon-reload&&systemctl restart docker
```
#在kubeadm-init.yaml，修改kubeleteConfiguration内容
#默认
```
cgroupDriver: cgroupfs
```
#修改为
```
cgroupDriver: systemd
```
#如果已经初始化后修改，那么配置文件是/var/lib/kubelet/config.yaml
```
cgroupDriver: systemd
```
#并重启docker和kubelet
```bash
systemctl restart docker
systemctl restart kubelet
```
#### 9、如果开启防火墙，下面端口必须开放
#master节点
```
协议	方向	端口范围	        作用	             使用者
TCP	入站	6443	    Kubernetes API 服务器	    所有组件
TCP	入站	2379-2380	etcd服务器客户端API	      kube-apiserver, etcd
TCP	入站	10250	    Kubelet API	              kubelet 自身、控制平面组件
TCP	入站	10251	    kube-scheduler	          kube-scheduler 自身
TCP	入站	10252	   kube-controller-manager	 kube-controller-manager自身
TCP	入站	8080	    kubelet	                  kubelet自身
```
#官方
```
Control plane
Protocol	Direction	Port Range	            Purpose	Used By
TCP	Inbound	6443	Kubernetes API server	      All
TCP	Inbound	2379-2380	etcd server client API	  kube-apiserver, etcd
TCP	Inbound	10250	Kubelet API	                  Self, Control plane
TCP	Inbound	10259	kube-scheduler	              Self
TCP	Inbound	10257	kube-controller-manager	      Self
```

#node节点
```
协议	   方向	端口范围	   作用	                   使用者
TCP	    入站	 10250	      Kubelet API	       kubelet 自身、控制平面组件
TCP/UDP	入站	 30000-32767	  NodePort 服务 	      所有组件
```
#官方
```
Worker node(s)
Protocol	Direction	Port Range	            Purpose	Used By
TCP	Inbound	10250	    Kubelet API	            Self, Control plane
TCP	Inbound	30000-32767	NodePort Services†	    All
```

#rancher防火墙端口规则参考
##全部角色
```
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=2376/tcp
firewall-cmd --permanent --add-port=2379/tcp
firewall-cmd --permanent --add-port=2380/tcp
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --permanent --add-port=9099/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10254/tcp
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --permanent --add-port=30000-32767/udp
```
###部分角色
```
## 对于etcd节点，运行以下命令：
firewall-cmd --permanent --add-port=2376/tcp
firewall-cmd --permanent --add-port=2379/tcp
firewall-cmd --permanent --add-port=2380/tcp
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --permanent --add-port=9099/tcp
firewall-cmd --permanent --add-port=10250/tcp

## 对于control plane节点，运行以下命令：
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=2376/tcp
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --permanent --add-port=9099/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10254/tcp
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --permanent --add-port=30000-32767/udp

## 对于worker nodes节点，运行以下命令：
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=2376/tcp
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --permanent --add-port=9099/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10254/tcp
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --permanent --add-port=30000-32767/udp
```
