kubernetes的证书主要分为三类： 

- 集群CA证书，包括kubernetes的CA，etcd的CA以及聚合层CA
- 控制面组件证书，包括kube-apiserver，etcd，kube-controller-manager，kube-scheduler，聚合层的证书
- kubelet证书

可以通过如下指令查看到相关证书的过期时间： 

```Bash
[root@k8s01 ~]# kubeadm  certs check-expiration
[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Dec 11, 2022 01:37 UTC   362d                                    no      
apiserver                  Dec 11, 2022 01:37 UTC   362d            ca                      no      
apiserver-etcd-client      Dec 11, 2022 01:37 UTC   362d            etcd-ca                 no      
apiserver-kubelet-client   Dec 11, 2022 01:37 UTC   362d            ca                      no      
controller-manager.conf    Dec 11, 2022 01:37 UTC   362d                                    no      
etcd-healthcheck-client    Dec 11, 2022 01:37 UTC   362d            etcd-ca                 no      
etcd-peer                  Dec 11, 2022 01:37 UTC   362d            etcd-ca                 no      
etcd-server                Dec 11, 2022 01:37 UTC   362d            etcd-ca                 no      
front-proxy-client         Dec 11, 2022 01:37 UTC   362d            front-proxy-ca          no      
scheduler.conf             Dec 11, 2022 01:37 UTC   362d                                    no      

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Dec 09, 2031 01:37 UTC   9y              no      
etcd-ca                 Dec 09, 2031 01:37 UTC   9y              no      
front-proxy-ca          Dec 09, 2031 01:37 UTC   9y              no 
```



可以看到，通过kubeadm安装的kubernetes集群CA证书的有效期是10年，而其他证书的有效期只有一年，在证书过期时，需要更新证书。我们有两种方式可以规避这个问题： 

1. 提供更长的证书有效期
2. 配置证书续期



# CA证书更新

CA证书默认是10年期，默认情况下，kubernetes支持的证书最长时间就是10年，如果需要手动轮换CA证书，可以参考这里： [https://kubernetes.io/zh/docs/tasks/tls/manual-rotation-of-ca-certificates/](https://kubernetes.io/zh/docs/tasks/tls/manual-rotation-of-ca-certificates/)



# 控制面证书更新



kubeadm提供指令可以使我们手动更新控制面证书： 

```Bash
[root@k8s01 ~]# kubeadm certs renew --help 
This command is not meant to be run on its own. See list of available subcommands.

Usage:
  kubeadm certs renew [flags]
  kubeadm certs renew [command]

Available Commands:
  admin.conf               Renew the certificate embedded in the kubeconfig file for the admin to use and for kubeadm itself
  all                      Renew all available certificates
  apiserver                Renew the certificate for serving the Kubernetes API
  apiserver-etcd-client    Renew the certificate the apiserver uses to access etcd
  apiserver-kubelet-client Renew the certificate for the API server to connect to kubelet
  controller-manager.conf  Renew the certificate embedded in the kubeconfig file for the controller manager to use
  etcd-healthcheck-client  Renew the certificate for liveness probes to healthcheck etcd
  etcd-peer                Renew the certificate for etcd nodes to communicate with each other
  etcd-server              Renew the certificate for serving etcd
  front-proxy-client       Renew the certificate for the front proxy client
  scheduler.conf           Renew the certificate embedded in the kubeconfig file for the scheduler manager to use
```



除此之外，我们也可以在使用kubeadm安装集群时，指定生成的证书的有效期长度： 

```Bash
controllerManager:
  extraArgs:
    v: "4"
    node-cidr-mask-size: "19"
    deployment-controller-sync-period: "10s"
    # 在 kubeadm 配置文件中设置证书有效期为 10 年
    experimental-cluster-signing-duration: "86700h"
    node-monitor-grace-period: "20s"
    pod-eviction-timeout: "2m"
    terminated-pod-gc-threshold: "30"
```



# 配置kubelet证书自动续期



如果是kubeadm安装的集群，可以在安装时，开启如下配置项以实现kubelet证书的自动续期： 

```Bash
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true   # 配置 kubelet 以使用被正确签名的服务证书
rotateCertificates: true   # 证书自动更新

```



如果是已经安装的集群中配置，可修改kube-system命名空间下的`kubelet-config-${version}`的configmap添加上述配置，并在所有worker节点的`/var/lib/kubelet/config.yaml`文件中添加上述配置，并重启kubelet。



如果是非kubeadm的集群，需要通过如下配置项去实现kubelet证书的自动更新： 



1. 修改kubelet启动文件

```Bash
# vim /lib/systemd/system/kubelet.service

--feature-gates=RotateKubeletServerCertificate=true,RotateKubeletClientCertificate=true
--rotate-certificates
```

2. 修改kube-controller-manager启动文件

```
# vim /lib/systemd/system/kube-controller-manager.service

# 自动续期的证书有效期为10年
# 需要说明的是这里虽然配置的是10年，但kubelet签发证书的最长有效期只有5年，所以这里也只会是5年
--experimental-cluster-signing-duration=87600h0m0s
--feature-gates=RotateKubeletServerCertificate=true
```

3. 创建自动批准相关CSR请求的ClusterRole

```yaml
# vim tls-instructs-csr.yaml

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: system:certificates.k8s.io:certificatesigningrequests:selfnodeserver
rules:
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/selfnodeserver"]
  verbs: ["create"]
  
  
# kubectl apply -f tls-instructs-csr.yaml
```

```
#自动批准 kubelet-bootstrap 用户 TLS bootstrapping 首次申请证书的 CSR 请求
kubectl create clusterrolebinding node-client-auto-approve-csr --clusterrole=system:certificates.k8s.io:certificatesigningrequests:nodeclient --user=kubelet-bootstrap
 
#自动批准 system:nodes 组用户更新 kubelet 自身与 apiserver 通讯证书的 CSR 请求
kubectl create clusterrolebinding node-client-auto-renew-crt --clusterrole=system:certificates.k8s.io:certificatesigningrequests:selfnodeclient --group=system:nodes

#自动批准 system:nodes 组用户更新 kubelet 10250 api 端口证书的 CSR 请求
kubectl create clusterrolebinding node-server-auto-renew-crt --clusterrole=system:certificates.k8s.io:certificatesigningrequests:selfnodeserver --group=system:nodes
```

4. 重启kube-controller-manager

```
systemctl daemon-reload
systemctl restart kube-controller-manager
```

5. 验证

    删除kubelet证书，查看是否正常签发：

```Bash
# 删除kubelet证书
rm -f kubelet-client-current.pem kubelet-client-*.pem kubelet.key kubelet.crt

# 重启kubelet 
systemctl restart kubelet 

# 查看新生成的证书
openssl x509 -in kubelet-client-current.pem -noout -text | grep "Not"
```

# 附录

- [《使用kubeadm进行证书管理》](https://kubernetes.io/zh/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- [《Kubelet证书如何自动续期》](https://www.cnblogs.com/lvcisco/p/11912637.html)