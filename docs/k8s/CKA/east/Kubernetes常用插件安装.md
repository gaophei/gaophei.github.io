这里统一使用helm安装相关插件，所以需要先安装好helm： 

```Bash
#wget https://breezey-public.oss-cn-zhangjiakou.aliyuncs.com/softwares/linux/kubernetes/helm-v3.6.3-linux-amd64.tar.gz
#tar xf helm-v3.6.3-linux-amd64.tar.gz
#cd helm-v3.6.3-linux-amd64
wget https://rancher-mirror.rancher.cn/helm/v3.11.3/helm-v3.11.3-linux-amd64.tar.gz
tar -zxvf helm-v3.11.3-linux-amd64.tar.gz
cd linux-adm64
cp helm /usr/bin/

```



常用add-ons：

- ingress
- metrics-server
- keda
- node-problem-detector
- openkruise
- metricbeat
- dashboard
- prometheus-operator



## ingress

ingress的github地址： [github.com/kubernetes/ingress-nginx](http://github.com/kubernetes/ingress-nginx)

官方文档地址： [https://kubernetes.github.io/ingress-nginx/](https://kubernetes.github.io/ingress-nginx/)



部署：

```
# 添加helm源
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
# 获取安装包
helm fetch ingress-nginx/ingress-nginx
# Error: Get "https://github.com/kubernetes/ingress-nginx/releases/download/helm-chart-4.6.0/ingress-nginx-4.6.0.tgz": unexpected EOF

tar xf ingress-nginx-4.0.6.tgz
cd ingress-nginx
```

修改values.yaml内容如下： 

```YAML
controller:
  name: controller
  image:
    registry: registry.cn-zhangjiakou.aliyuncs.com
    image: breezey/ingress-nginx
    #digest: sha256:545cff00370f28363dad31e3b59a94ba377854d3a11f18988f5f9e56841ef9ef
    tag: "v1.0.4"
  ...
  config:
    allow-backend-server-header: "true"
    enable-underscores-in-headers: "true"
    generate-request-id: "true"
    ignore-invalid-headers: "true"
    keep-alive: "30"
    keep-alive-requests: "50000"
    log-format-upstream: $remote_addr - [$remote_addr] - $remote_user [$time_local]
      "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length
      $request_time [$proxy_upstream_name] $upstream_addr $upstream_response_length
      $upstream_response_time $upstream_status $req_id $host
    max-worker-connections: "65536"
    proxy-body-size: 100m
    proxy-connect-timeout: "5"
    proxy-next-upstream: "off"
    proxy-read-timeout: "5"
    proxy-send-timeout: "5"
    #proxy-set-headers: ingress-nginx/custom-headers
    reuse-port: "true"
    server-tokens: "false"
    ssl-redirect: "false"
    upstream-keepalive-connections: "200"
    upstream-keepalive-timeout: "900"
    use-forwarded-headers: "true"
    worker-cpu-affinity: auto
    worker-processes: auto
  ...
  replicaCount: 2
  ingressClassResource:
    name: nginx
    enabled: true
    default: true
    controllerValue: "k8s.io/ingress-nginx"
  ...
  tolerations:
  - key: ingressClass
    operator: Equal
    value: nginx
    effect: NoSchedule
  ...
  nodeSelector:
    kubernetes.io/os: linux
    ingressClass: nginx
  ...
  admissionWebhooks:
    ...
    patch:
      enabled: true
      image:
        registry: dyhub.douyucdn.cn
        image: library/kube-webhook-certgen
        tag: v1.1.1
        #digest: sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660
        pullPolicy: IfNotPresent
...
defaultBackend:
  ##
  enabled: true
  name: defaultbackend
  image:
    registry: registry.cn-zhangjiakou.aliyuncs.com
    image: breezey/defaultbackend-amd64

```

执行安装： 

```Bash
kubectl create ns ingress-nginx
helm install -n ingress-nginx ingress-nginx ./
```



## metrics-server

metrics-server用于在集群内部向kube-apiserver暴露集群指标。

代码托管地址： [https://github.com/kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server)



部署

```Bash
# 配置helm源
helm repo add bitnami https://charts.bitnami.com/bitnami

helm search repo metrics-server 

# 获取配置文件
helm  show values bitnami/metrics-server > metrics-server.yaml

```

修改metrics-server.yaml配置文件

```YAML
extraArgs:
  cert-dir: tmp
  kubelet-insecure-tls: true
  kubelet-preferred-address-types: InternalIP,ExternalIP,Hostname
  kubelet-use-node-status-port: true
```

执行安装： 

```
helm upgrade  -n kube-system metrics-server bitnami/metrics-server  -f metrics-server.yaml 
```

验证： 

```
[root@cka-master metrics-server]# kubectl top nodes
NAME           CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
192.168.0.93   169m         8%     1467Mi          39%
cka-node1      138m         6%     899Mi           24%
```



# metricbeat

metricbeat是ELastic的beats家族成员，可用于采集相关监控指标及事件。这里主要用作收集kubernetes相关事件。另一个类似的组件为阿里云开源的kube-eventer，是一个用于采集pod相关事件的收集器，它可以将相关的事件发送至kafka,mysql，es等sink

metricbeat的部署文档参考： [https://www.elastic.co/guide/en/beats/metricbeat/current/running-on-kubernetes.html](https://www.elastic.co/guide/en/beats/metricbeat/current/running-on-kubernetes.html)

kube-eventer的代码仓库地址：  [https://github.com/AliyunContainerService/kube-eventer](https://github.com/AliyunContainerService/kube-eventer)

## 1.  部署kube-state-metrics

需要说明的是，metricbeat采集kubernetes相关事件，需要依赖kube-state-metrics，所以，需要先安装这个组件。

```
helm repo add azure-marketplace https://marketplace.azurecr.io/helm/v1/repo

helm show values azure-marketplace/kube-state-metrics > kube-state-metrics.yaml


```

修改kube-state-metrics.yaml内容如下：

```
global:
  imageRegistry: registry.cn-zhangjiakou.aliyuncs.com
image:
  registry: registry.cn-zhangjiakou.aliyuncs.com
  repository: breezey/kube-state-metrics
  tag: 1.9.7-debian-10-r143
```

执行部署： 

```
helm install -n kube-system kube-state-metrics azure-marketplace/kube-state-metrics  -f kube-state-metrics.yaml
```

## 2. 部署metricbeat

```
curl -L -O https://raw.githubusercontent.com/elastic/beats/7.10/deploy/kubernetes/metricbeat-kubernetes.yaml

```

删除掉daemonset相关配置，因为那些配置用于采集系统及kubernetes的监控指标，而我们这里只采集事件。

然后修改ConfigMap内容如下

```
...
    fields:
      cluster: k8s-test-hwcloud
    metricbeat.config.modules:
      # Mounted `metricbeat-daemonset-modules` configmap:
      path: ${path.config}/modules.d/*.yml
      # Reload module configs as they change:
      reload.enabled: true
...
    output.kafka:
      hosts: ["10.32.99.62:9092","10.32.99.142:9092","10.32.99.143:9092","10.32.99.145:9092","10.32.99.146:9092","10.32.99.147:9092","10.32.99.148:9092"]
      topic: 'ops_k8s_event_log'
      partition.round_robin:
        reachable_only: false
      required_acks: 1
      compression: gzip
      max_message_bytes: 1000000
...
  kubernetes.yml: |-
    - module: kubernetes
      metricsets:
        # Uncomment this to get k8s events:
        - event
      period: 10s
      host: ${NODE_NAME}
      hosts: ["kube-state-metrics:8080"]
...
```

执行部署： 

```
kubectl apply -f metricbeat-kubernetes.yaml
```

# dashboard

为kubernetes提供web-ui

dashboard的github仓库地址：[https://github.com/kubernetes/dashboard](https://github.com/kubernetes/dashboard)

安装： 

```Bash
# 添加helm源
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
```

此时，即可通过浏览器访问web端，端口为32443： 

![kubernetes-dashboard](https://code.aliyun.com/yanruogu/mypics/raw/master/kubernetes/kubernetes-dashboard.png)

可以看到出现如上图画面，需要我们输入一个kubeconfig文件或者一个token。事实上在安装dashboard时，也为我们默认创建好了一个serviceaccount，为kubernetes-dashboard，并为其生成好了token，我们可以通过如下指令获取该sa的token：

```
kubectl describe secret -n kubernetes-dashboard $(kubectl get secret -n kubernetes-dashboard |grep  kubernetes-dashboard-token | awk '{print $1}') |grep token | awk '{print $2}'


eyJhbGciOiJSUzI1NiIsImtpZCI6IkUtYTBrbU44TlhMUjhYWXU0VDZFV1JlX2NQZ0QxV0dPRjBNUHhCbUNGRzAifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291eeeeeeLWRhc2hib2FyZC10b2tlbi1rbXBuMiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFxxxxxxxxxxxxxxxxxxxxxxxGZmZmYxLWJhOTAtNDU5Ni1hMzgxLTRhNDk5NzMzYWI0YiIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlcm5ldGVzLWRhc2hib2FyZDprdWJlcm5ldGVzLWRhc2hib2FyZCJ9.UwAsemOra-EGl2OzKc3lur8Wtg5adqadulxH7djFpmpWmDj1b8n1YFiX-AwZKSbv_jMZd-mvyyyyyyyyyyyyyyyMYLyVub98kurq0eSWbJdzvzCvBTXwYHl4m0RdQKzx9IwZznzWyk2E5kLYd4QHaydCw7vH26by4cZmsqbRkTsU6_0oJIs0YF0YbCqZKbVhrSVPp2Fw5IyVP-ue27MjaXNCSSNxLX7GNfK1W1E68CrdbX5qqz0-Ma72EclidSxgs17T34p9mnRq1-aQ3ji8bZwvhxuTtCw2DkeU7DbKfzXvJw9ENBB-A0fN4bewP6Og07Q
```

通过该token登入集群以后，发现很多namespace包括一些其他的资源都没有足够的权限查看。这是因为默认我们使用的这个帐户只有有限的权限。我们可以通过对该sa授予cluster-admin权限来解决这个问题：

修改ClusterRoleBinding资源内容如下：

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard
```

重新创建clusterrolebinding：

```
kubectl delete clusterrolebinding  kubernetes-dashboard -n kubernetes-dashboard
kubectl apply -f ./recommended.yaml
```

此时，kubernetes-dashboard相关配置即完成。

# KEDA

keda全称为kubernetes event driven autoscaler，为kubernetes提供基于事件驱动的自动伸缩

github仓库地址： [https://github.com/kedacore/keda](https://github.com/kedacore/keda)

官方文档地址： https://keda.sh

安装： 

```Bash
# 添加helm源
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
# 获取配置文件
helm show values kedacore/keda > keda.yaml

```

修改 keda.yaml

```
image:
  keda:
    repository: registry.cn-zhangjiakou.aliyuncs.com/breezey/keda
    tag: 2.4.0
  metricsApiServer:
    repository: registry.cn-zhangjiakou.aliyuncs.com/breezey/keda-metrics-apiserver
    tag: 2.4.0
  pullPolicy: Always
```

执行安装： 

```Bash
kubectl create ns keda
helm install keda -n keda ./
```



# openkruise

openKruise的官方代码库地址： [https://github.com/openkruise/kruise](https://github.com/openkruise/kruise)

官方文档地址： [https://openkruise.io/](https://openkruise.io/)

安装： 

```Bash
helm repo add openkruise https://openkruise.github.io/charts/
helm repo update
helm install kruise openkruise/kruise -n kube-system --version 0.10.0
```



> 这里也可以直接使用阿里云官方的chart仓库： helm repo add incubator [https://aliacs-k8s-cn-beijing.oss-cn-beijing.aliyuncs.com/app/charts-incubator](http://aliacs-k8s-cn-beijing.oss-cn-beijing.aliyuncs.com/app/charts-incubator)

# node-problem-detect

安装： 

```Bash
helm repo add deliveryhero https://charts.deliveryhero.io/
helm repo update

helm show values  deliveryhero/node-problem-detector --version 2.0.9 > node-problem-detector.yaml

```

修改node-problem-detector.yaml内容如下： 

```Bash
image:
  repository: registry.cn-zhangjiakou.aliyuncs.com/breezey/node-problem-detector
  tag: v0.8.10
  pullPolicy: IfNotPresent
```

安装： 

```Bash
helm install -n kube-system node-problem-detect deliveryhero/node-problem-detector  --version 2.0.9 -f ./node-problem-detector.yaml 
```