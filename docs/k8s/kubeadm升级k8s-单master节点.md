## 服务器资源
vm: 4核/8G 

OS: centos7.9(3.10.0-1127)

docker: 19.03.15

master01: 192.168.1.225
node01: 192.168.1.226

## 升级需求
现有k8s版本:

ks8: 1.21.7

升级到

k8s: 1.23.3

## 升级注意事项
不能直接跨版本升级，不然会报错。只能是逐步升级:1.21.7-0--->1.22.7-0--->1.23.4
```
[root@master01 kubernetes]# yum list kubeadm --showduplicates
kubeadm.x86_64                                      1.20.15-0                                   kubernetes 
kubeadm.x86_64                                      1.21.0-0                                    kubernetes 
kubeadm.x86_64                                      1.21.1-0                                    kubernetes 
kubeadm.x86_64                                      1.21.2-0                                    kubernetes 
kubeadm.x86_64                                      1.21.3-0                                    kubernetes 
kubeadm.x86_64                                      1.21.4-0                                    kubernetes 
kubeadm.x86_64                                      1.21.5-0                                    kubernetes 
kubeadm.x86_64                                      1.21.6-0                                    kubernetes 
kubeadm.x86_64                                      1.21.7-0                                    kubernetes 
kubeadm.x86_64                                      1.21.8-0                                    kubernetes 
kubeadm.x86_64                                      1.21.9-0                                    kubernetes 
kubeadm.x86_64                                      1.21.10-0                                   kubernetes 
kubeadm.x86_64                                      1.22.0-0                                    kubernetes 
kubeadm.x86_64                                      1.22.1-0                                    kubernetes 
kubeadm.x86_64                                      1.22.2-0                                    kubernetes 
kubeadm.x86_64                                      1.22.3-0                                    kubernetes 
kubeadm.x86_64                                      1.22.4-0                                    kubernetes 
kubeadm.x86_64                                      1.22.5-0                                    kubernetes 
kubeadm.x86_64                                      1.22.6-0                                    kubernetes 
kubeadm.x86_64                                      1.22.7-0                                    kubernetes 
kubeadm.x86_64                                      1.23.0-0                                    kubernetes 
kubeadm.x86_64                                      1.23.1-0                                    kubernetes 
kubeadm.x86_64                                      1.23.2-0                                    kubernetes 
kubeadm.x86_64                                      1.23.3-0                                    kubernetes 
kubeadm.x86_64                                      1.23.4-0                                    kubernetes

[root@master01 kubernetes]# yum install -y kubeadm-1.23.4-0

[root@master01 kubernetes]# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade/config] FATAL: this version of kubeadm only supports deploying clusters with the control plane version >= 1.22.0. Current version: v1.21.7
To see the stack trace of this error execute with --v=5 or higher
```

## 升级过程
### 升级kubeadm
```bash
yum list kubeadm --showduplicates
yum install -y kubeadm-1.22.7-0
```
### 查看升级计划
```bash
kubeadm upgrade plan
```
日志如下：
```
[root@master01 ~]# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.21.7
[upgrade/versions] kubeadm version: v1.22.7
I0225 17:12:35.380448   20779 version.go:255] remote version is much newer: v1.23.4; falling back to: stable-1.22
[upgrade/versions] Target version: v1.22.7
[upgrade/versions] Latest version in the v1.21 series: v1.21.10

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       TARGET
kubelet     2 x v1.21.7   v1.21.10

Upgrade to the latest version in the v1.21 series:

COMPONENT                 CURRENT    TARGET
kube-apiserver            v1.21.7    v1.21.10
kube-controller-manager   v1.21.7    v1.21.10
kube-scheduler            v1.21.7    v1.21.10
kube-proxy                v1.21.7    v1.21.10
CoreDNS                   v1.8.0     v1.8.4
etcd                      3.4.13-0   3.4.13-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.21.10

_____________________________________________________________________

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       TARGET
kubelet     2 x v1.21.7   v1.22.7

Upgrade to the latest stable version:

COMPONENT                 CURRENT    TARGET
kube-apiserver            v1.21.7    v1.22.7
kube-controller-manager   v1.21.7    v1.22.7
kube-scheduler            v1.21.7    v1.22.7
kube-proxy                v1.21.7    v1.22.7
CoreDNS                   v1.8.0     v1.8.4
etcd                      3.4.13-0   3.5.0-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.22.7

_____________________________________________________________________


The table below shows the current state of component configs as understood by this version of kubeadm.
Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
upgrade to is denoted in the "PREFERRED VERSION" column.

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________

[root@master01 ~]# 
```
### 升级集群
```bash
kubeadm upgrade apply v1.22.7
#过程中需要输入y继续
```
日志如下：
```
[root@master01 ~]# kubeadm upgrade apply v1.22.7
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.22.7"
[upgrade/versions] Cluster version: v1.21.7
[upgrade/versions] kubeadm version: v1.22.7
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.22.7"...
Static pod: kube-apiserver-master01 hash: b620a7935d42ca8a77cf595a527790b7
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
[upgrade/etcd] Upgrading to TLS for etcd
Static pod: etcd-master01 hash: 225c30c294fa64e0e3f1fe167aa6aba7
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Renewing etcd-server certificate
[upgrade/staticpods] Renewing etcd-peer certificate
[upgrade/staticpods] Renewing etcd-healthcheck-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/etcd.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2022-02-25-17-27-08/etcd.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
Static pod: etcd-master01 hash: 225c30c294fa64e0e3f1fe167aa6aba7
Static pod: etcd-master01 hash: 225c30c294fa64e0e3f1fe167aa6aba7
Static pod: etcd-master01 hash: b980eef69feef7f592a90e69d66c08d1
[apiclient] Found 1 Pods for label selector component=etcd
[upgrade/staticpods] Component "etcd" upgraded successfully!
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests786365706"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Renewing apiserver-etcd-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2022-02-25-17-27-08/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
Static pod: kube-apiserver-master01 hash: b620a7935d42ca8a77cf595a527790b7
Static pod: kube-apiserver-master01 hash: 53e3743b31a30b440897db36557502a8
[apiclient] Found 1 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2022-02-25-17-27-08/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: d957cfc9db897cd9da44c07cb11f2d16
Static pod: kube-controller-manager-master01 hash: 0edd56c8b3633f55ad482cd4338769b4
[apiclient] Found 1 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2022-02-25-17-27-08/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: b3920dea111b4ed333b4a80ad3372201
Static pod: kube-scheduler-master01 hash: c97a5ea2e162bef7a1cf01bb923c8dd2
[apiclient] Found 1 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upgrade/postupgrade] Applying label node-role.kubernetes.io/control-plane='' to Nodes with label node-role.kubernetes.io/master='' (deprecated)
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.22" in namespace kube-system with the configuration for the kubelets in the cluster
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.22.7". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
[root@master01 ~]# 
```
### 查看版本
```bash
kubectl get  nodes
kubectl version
kubelet --version
```
日志如下：
```
[root@master01 ~]# kubectl get nodes
NAME       STATUS   ROLES                  AGE   VERSION
master01   Ready    control-plane,master   77d   v1.21.7
mysql3     Ready    <none>                 74m   v1.21.7
[root@master01 ~]# kubectl version
Client Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.7", GitCommit:"1f86634ff08f37e54e8bfcd86bc90b61c98f84d4", GitTreeState:"clean", BuildDate:"2021-11-17T14:41:19Z", GoVersion:"go1.16.10", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"22", GitVersion:"v1.22.7", GitCommit:"b56e432f2191419647a6a13b9f5867801850f969", GitTreeState:"clean", BuildDate:"2022-02-16T11:43:55Z", GoVersion:"go1.16.14", Compiler:"gc", Platform:"linux/amd64"}

[root@master01 ~]# kubelet --version
Kubernetes v1.21.7

```
### 升级kubelet和kubectl
```bash
yum install -y kubelet-1.22.7-0 kubectl-1.22.7-0
```
日志如下：
```
[root@master01 ~]# yum install -y kubelet-1.22.7-0 kubectl-1.22.7-0
Loaded plugins: fastestmirror, langpacks
Loading mirror speeds from cached hostfile
 * base: mirrors.aliyun.com
 * extras: mirrors.aliyun.com
 * updates: mirrors.aliyun.com
Resolving Dependencies
--> Running transaction check
---> Package kubectl.x86_64 0:1.21.7-0 will be updated
---> Package kubectl.x86_64 0:1.22.7-0 will be an update
---> Package kubelet.x86_64 0:1.21.7-0 will be updated
---> Package kubelet.x86_64 0:1.22.7-0 will be an update
--> Finished Dependency Resolution

Dependencies Resolved

====================================================================================================================================================================================
 Package                                   Arch                                     Version                                      Repository                                    Size
====================================================================================================================================================================================
Updating:
 kubectl                                   x86_64                                   1.22.7-0                                     kubernetes                                   9.7 M
 kubelet                                   x86_64                                   1.22.7-0                                     kubernetes                                    20 M

Transaction Summary
====================================================================================================================================================================================
Upgrade  2 Packages

Total download size: 30 M
Downloading packages:
No Presto metadata available for kubernetes
(1/2): b3d0081504a6f7831e9dbd90390fe56f7c46ebe90860c07d300bdecf7c829d64-kubectl-1.22.7-0.x86_64.rpm                                                          | 9.7 MB  00:00:33     
(2/2): 04ea9a2adcf134b7f6771a631e8d68a7a4c478de213b88ae004a90a5c6788e31-kubelet-1.22.7-0.x86_64.rpm                                                          |  20 MB  00:01:01     
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                               500 kB/s |  30 MB  00:01:01     
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Updating   : kubectl-1.22.7-0.x86_64                                                                                                                                          1/4 
  Updating   : kubelet-1.22.7-0.x86_64                                                                                                                                          2/4 
  Cleanup    : kubectl-1.21.7-0.x86_64                                                                                                                                          3/4 
  Cleanup    : kubelet-1.21.7-0.x86_64                                                                                                                                          4/4 
  Verifying  : kubelet-1.22.7-0.x86_64                                                                                                                                          1/4 
  Verifying  : kubectl-1.22.7-0.x86_64                                                                                                                                          2/4 
  Verifying  : kubelet-1.21.7-0.x86_64                                                                                                                                          3/4 
  Verifying  : kubectl-1.21.7-0.x86_64                                                                                                                                          4/4 

Updated:
  kubectl.x86_64 0:1.22.7-0                                                                kubelet.x86_64 0:1.22.7-0                                                               

Complete!

```
### 升级kubelet
```bash
systemctl daemon-reload
systemctl restart kubelet
```
日志如下：
```
[root@master01 ~]# systemctl restart kubelet
[root@master01 ~]# systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Fri 2022-02-25 18:06:42 CST; 9s ago
     Docs: https://kubernetes.io/docs/
 Main PID: 4417 (kubelet)
    Tasks: 17
   Memory: 38.7M
   CGroup: /system.slice/kubelet.service
           └─4417 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml ...

Feb 25 18:06:44 master01 kubelet[4417]: E0225 18:06:44.793870    4417 kubelet.go:1701] "Failed creating a mirror pod for" err="pods \"etcd-master01\" already exists" ...d-master01"
Feb 25 18:06:44 master01 kubelet[4417]: I0225 18:06:44.988109    4417 request.go:665] Waited for 1.008951664s due to client-side throttling, not priority and fairness...system/pods
Feb 25 18:06:44 master01 kubelet[4417]: E0225 18:06:44.993582    4417 kubelet.go:1701] "Failed creating a mirror pod for" err="pods \"kube-controller-manager-master01...r-master01"
Feb 25 18:06:45 master01 kubelet[4417]: E0225 18:06:45.123421    4417 configmap.go:200] Couldn't get configMap kube-system/coredns: failed to sync configmap cache: ti...e condition
Feb 25 18:06:45 master01 kubelet[4417]: E0225 18:06:45.123422    4417 secret.go:195] Couldn't get secret cattle-system/cattle-credentials-26cd792: failed to sync secr...e condition
Feb 25 18:06:45 master01 kubelet[4417]: E0225 18:06:45.123538    4417 nestedpendingoperations.go:335] Operation for "{volumeName:kubernetes.io/configmap/b2923976-843d...015 +0800 C
Feb 25 18:06:45 master01 kubelet[4417]: E0225 18:06:45.123433    4417 configmap.go:200] Couldn't get configMap kube-system/kube-proxy: failed to sync configmap cache:...e condition
Feb 25 18:06:45 master01 kubelet[4417]: E0225 18:06:45.123583    4417 nestedpendingoperations.go:335] Operation for "{volumeName:kubernetes.io/secret/0287a2b4-f8c8-4d...63933 +0800
Feb 25 18:06:45 master01 kubelet[4417]: E0225 18:06:45.123654    4417 nestedpendingoperations.go:335] Operation for "{volumeName:kubernetes.io/configmap/ee66d6ee-65af...+0800 CST m
Feb 25 18:06:49 master01 kubelet[4417]: I0225 18:06:49.920872    4417 prober_manager.go:255] "Failed to trigger a manual run" probe="Readiness"
Hint: Some lines were ellipsized, use -l to show in full.
[root@master01 ~]# kubectl get nodes
NAME       STATUS   ROLES                  AGE   VERSION
master01   Ready    control-plane,master   77d   v1.22.7
mysql3     Ready    <none>                 93m   v1.21.7
[root@master01 ~]# 
```

### 工作节点升级
```bash
yum install -y kubeadm-1.22.7-0 --disableexcludes=kubernetes
kubeadm upgrade node
```
日志如下：
```
[root@mysql3 ~]# kubeadm upgrade node
[upgrade] Reading configuration from the cluster...
[upgrade] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks
[preflight] Skipping prepull. Not a control plane node.
[upgrade] Skipping phase. Not a control plane node.
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade] The configuration for this node was successfully updated!
[upgrade] Now you should go ahead and upgrade the kubelet package using your package manager.
```

### 驱逐节点
```bash
kubectl drain node node1 --ignore-daemonsets
```

### 升级并重启kubelet
```bash
yum install -y kubelet-1.22.7-0
systemctl daemon-reload
systemctl restart kubelet
```
### 此时查看节点版本，已全部升级
```bash
kubectl get nodes
```
日志如下：
```
[root@master01 ~]# kubectl get nodes
NAME       STATUS   ROLES                  AGE    VERSION
master01   Ready    control-plane,master   77d    v1.22.7
mysql3     Ready    <none>                 100m   v1.22.7
```