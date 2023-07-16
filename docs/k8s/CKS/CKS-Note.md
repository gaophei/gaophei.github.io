[CKS](https://training.linuxfoundation.cn/certificates/16)
===

[TOC]

<hr>

# <strong style='color: #00B9E4'>1. 集群安装-10%</strong>

> 1.1 使用==网络安全策略==来限制集群级别的访问
>
> 1.2 使用 ==CIS== 基准检查 Kubernetes 组件(etcd, kubelet, kubedns, kubeapi)的安全配置
>
> 1.3 正确设置带有安全控制的 ==Ingress== 对象
>
> 1.4 保护节点元数据和端点 
>
> 1.5 最小化 ==GUI== 元素的使用和访问
>
> 1.6 在部署之前验证平台二进制文件

## 1.1 netoworkPolicy

### <strong style='color: #92D400'>Lab1.</strong>  默认拒绝所有入站流量  

<img height=78 align=left src="https://i0.hdslb.com/bfs/album/7ad55e0ffe365cc012673f1177fcbb013f4087ea.png">

```bash
$ kubectl run web --image=nginx --image-pull-policy=IfNotPresent --restart=Always
pod/web created

$ kubectl get pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP             NODE          NOMINATED NODE   READINESS GATES
web    1/1     Running   0          25s  `172.16.126.3`  k8s-worker2   <none>           <none>

$ curl -s 172.16.126.3 | grep -i welcome
`<title>Welcome to nginx!</title>`
`<h1>Welcome to nginx!</h1>`
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

```

Try it out

```bash
$ curl -sm 1 172.16.126.3
$ echo $?
28
```

Cleanup

```bash
$ kubectl delete -f network-policy-default-deny-ingress.yaml
networkpolicy.networking.k8s.io "default-deny-ingress" deleted
```



### <strong style='color: #92D400'>Lab2.</strong> 默认允许所有入站流量

<img height=78 align=left src="https://i0.hdslb.com/bfs/album/7fe5de5cc90acf3088a4e43e0efd7844ee1a7683.png">

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-ingress
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
EOF
  
```

Try it out

```bash
$ curl -s 172.16.126.3 | grep -i welcome
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```

Cleanup

```bash
$ kubectl delete -f network-policy-allow-all-ingress.yaml
networkpolicy.networking.k8s.io "allow-all-ingress" deleted
```



### <strong style='color: #92D400'>Lab3.</strong> [拒绝发往应用程序的所有流量](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/01-deny-all-traffic-to-an-application.md)

![3](https://i0.hdslb.com/bfs/album/4ae493af0690108be049c30b20098f0d7038d172.png)

```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port=80
```

```bash
$ kubectl run --rm -i -t --image=alpine test-$RANDOM -- sh
/ # wget -qO- http://web
<!DOCTYPE html>
<html>
<head>
...
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-deny-all
spec:
  podSelector:
    matchLabels:
      app: web
  ingress: []
EOF

```

Try it out

```bash
$ kubectl run --rm -i -t --image=alpine test-$RANDOM -- sh
/ # wget -qO- --timeout=2 http://web
wget: download timed out
```

Cleanup

```bash
kubectl delete pod web
kubectl delete service web
kubectl delete networkpolicy web-deny-all
```



### <strong style='color: #92D400'>Lab4.</strong> [限制到应用程序的流量](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/02-limit-traffic-to-an-application.md)

![image-20220730164528045](https://i0.hdslb.com/bfs/album/252491c8e4a226faed0a2d72fb5146a9563d278e.png)

```bash
$ kubectl run apiserver --image=nginx --labels="app=bookstore,role=api" --expose --port=80
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: api-allow
spec:
  podSelector:
    matchLabels:
      app: bookstore
      role: api
  ingress:
  - from:
      - podSelector:
          matchLabels:
            app: bookstore
EOF

```

Try it out

```bash
无法访问
$ kubectl run test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://apiserver
wget: download timed out

可以访问
$ kubectl run test-$RANDOM --rm -i -t --image=alpine --labels="app=bookstore,role=frontend" -- sh
/ # wget -qO- --timeout=2 http://apiserver
<!DOCTYPE html>
<html><head>
```

Cleanup

```bash
kubectl delete pod apiserver
kubectl delete service apiserver
kubectl delete networkpolicy api-allow
```



### <strong style='color: #92D400'>Lab5.</strong> [拒绝来自其他命名空间的所有流量](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/04-deny-traffic-from-other-namespaces.md)

![image-20220730164554648](https://i0.hdslb.com/bfs/album/b91eb76ccdc1682e2476f2fe40bdfae3b0b77edb.png)

```bash
$ kubectl run web --namespace=default --image=nginx --labels="app=web" --expose --port=80
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: default
  name: deny-from-other-namespaces
spec:
  podSelector:
    matchLabels:
  ingress:
  - from:
    - podSelector: {}
EOF

```

Try it out

```bash
$ kubectl create namespace foo
$ kubectl run test-$RANDOM --namespace=foo --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://web.default
wget: download timed out

$ kubectl run test-$RANDOM --namespace=default --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://web.default
<!DOCTYPE html>
<html>
```

Cleanup

```bash
kubectl delete pod web -n default
kubectl delete service web -n default
kubectl delete networkpolicy deny-from-other-namespaces -n default
kubectl delete namespace foo
```



### <strong style='color: #92D400'>Lab6.</strong> [允许从所有命名空间流向应用程序的流量](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/05-allow-traffic-from-all-namespaces.md)

![image-20220730164611322](https://i0.hdslb.com/bfs/album/adba88c156dfcf6e3c370b1f552821a0b6a1bb75.png)

```bash
kubectl run web --namespace=default --image=nginx --labels="app=web" --expose --port=80
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: default
  name: web-allow-all-namespaces
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - from:
    - namespaceSelector: {}
EOF

```

Try it out

```bash
$ kubectl create namespace secondary

$ kubectl run test-$RANDOM --namespace=secondary --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://web.default
<!DOCTYPE html>
<html>
<head>
```

Cleanup

```bash
kubectl delete pod web -n default
kubectl delete service web -n default
kubectl delete networkpolicy web-allow-all-namespaces -n default
kubectl delete namespace secondary
```



### <strong style='color: #92D400'>Lab7.</strong> [允许来自命名空间的所有流量](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/06-allow-traffic-from-a-namespace.md)

![image-20220730164630137](https://i0.hdslb.com/bfs/album/28416597e4bef1603a7fc083b05665707c44f616.png)

```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port=80
```

```bash
kubectl create namespace dev
kubectl label namespace/dev purpose=testing

kubectl create namespace prod
kubectl label namespace/prod purpose=production
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-allow-prod
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: production
EOF

```

Try it out

```bash
$ kubectl run test-$RANDOM --namespace=dev --rm -i -t --image=alpine -- sh
If you don't see a command prompt, try pressing enter.
/ # wget -qO- --timeout=2 http://web.default
wget: download timed out

(traffic blocked)

$ kubectl run test-$RANDOM --namespace=prod --rm -i -t --image=alpine -- sh
If you don't see a command prompt, try pressing enter.
/ # wget -qO- --timeout=2 http://web.default
<!DOCTYPE html>
<html>
<head>
...
(traffic allowed)
```

Cleanup

```bash
kubectl delete networkpolicy web-allow-prod
kubectl delete pod web
kubectl delete service web
kubectl delete namespace {prod,dev}
```



### <strong style='color: #92D400'>Lab8.</strong> [拒绝所有未列入白名单的流向命名空间的流量](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/03-deny-all-non-whitelisted-traffic-in-the-namespace.md)

![image-20220730164652762](https://i0.hdslb.com/bfs/album/73d434e9902cef3b2882aa76a337fafde79da9f1.png)

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  ingress: []
EOF

```

> - `namespace: default`将此策略部署到`default`命名空间
> - `podSelector:`为空，这意味着它将匹配所有 pod
>   因此，该策略将强制执行到`default`namespace 中的所有 pod
> - 没有 `ingress`指定规则。这会导致传入流量被丢弃到选定的（=all）pod
>   - 在这种情况下，可以省略该`ingress`字段，或将其留空

Cleanup

```bash
kubectl delete networkpolicy default-deny-all
```



### <strong style='color: #92D400'>Lab9.</strong> [允许来自外部客户端的流量](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/08-allow-external-traffic.md)

![image-20220730164713001](https://i0.hdslb.com/bfs/album/9f96cf54bc6337e60f90dbf61949da8b3b9b3f10.png)

```bash
kubectl run web --image=nginx --labels="app=web" --port=80

kubectl expose pod/web --type=LoadBalancer
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-allow-external
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - {}
EOF

```

Remarks

> 此清单为`app=web`pod 指定一个入口规则。由于它没有指定特定的`podSelector`或 `namespaceSelector`，因此它允许来自所有资源的流量，包括外部资源
>
> 要将外部访问仅限于端口 80，您可以部署一个入口规则

```yaml
  ingress:
  - ports:
    - port: 80
```

Cleanup

```bash
kubectl delete pod web
kubectl delete service web
kubectl delete networkpolicy web-allow-external
```



### <strong style='color: #92D400'>Lab10.</strong> [仅允许流量流向应用程序的端口](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/09-allow-traffic-only-to-a-port.md)

![image-20220730164733489](/Users/alex/Library/Application Support/typora-user-images/image-20220730164733489.png)

```bash
kubectl run apiserver --image=ahmet/app-on-two-ports --labels="app=apiserver"

kubectl create service clusterip apiserver \
    --tcp 8001:8000 \
    --tcp 5001:5000
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: api-allow-5000
spec:
  podSelector:
    matchLabels:
      app: apiserver
  ingress:
  - ports:
    - port: 5000
    from:
    - podSelector:
        matchLabels:
          role: monitoring
EOF

```

Try it out

```bash
$ kubectl run test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://apiserver:8001
wget: download timed out

/ # wget -qO- --timeout=2 http://apiserver:5001/metrics
wget: download timed out
```

```bash
$ kubectl run test-$RANDOM --labels="role=monitoring" --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://apiserver:8001
wget: download timed out

/ # wget -qO- --timeout=2 http://apiserver:5001/metrics
http.requests=3
go.goroutines=5
go.cpus=1
```

Cleanup

```bash
kubectl delete pod apiserver
kubectl delete service apiserver
kubectl delete networkpolicy api-allow-5000
```



## 1.3 ingress

### <strong style='color: #92D400'>Lab11.</strong> [ResourceQuota](https://kubernetes.io/zh/docs/concepts/policy/resource-quotas/)

```bash
$ kubectl create quota best-effort --hard=pods=2
resourcequota/best-effort created

$ kubectl get resourcequotas
NAME          AGE   REQUEST     LIMIT
best-effort   55s   pods: 2/2

$ vim deployment.yml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

```bash
$ kubectl apply -f deployment.yml
```

```bash
$ kubectl get deployments.apps nginx-deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   2/3     2            2           7m16s

$ kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
nginx-deployment-9456bbbf9-8gplx   1/1     Running   0          5m16s
nginx-deployment-9456bbbf9-hzb2k   1/1     Running   0          5m16s
```



### Task1. [kube-image-bouncer](https://hub.docker.com/r/flavio/kube-image-bouncer) <img height=38 src="https://d36jcksde1wxzq.cloudfront.net/075f9ab7fd796264d788.png">

> - 一个简单的 webhook 端点服务器，可用于验证在 Kubernetes 集群内创建的图像
>
> - 此准入控制器拒绝所有使用带有`latest`标签的镜像的 pod



## 1.4 保护节点元数据和端点

```bash
$ kubectl auth can-i -h

$ kubectl auth can-i create pods --all-namespaces

$ kubectl auth can-i '*' '*'
```



## 1.5 dashboard

### <strong style='color: #92D400'>Lab12.</strong> Dashboard 避免 nodePort

<div style="background: #dbfaf4; padding: 12px; line-height: 24px; margin-bottom: 24px;">
<dt style="background: #1abc9c; padding: 6px 12px; font-weight: bold; display: block; color: #fff; margin: -12px; margin-bottom: -12px; margin-bottom: 12px;" >Hint - 提示</dt>
  <li> 国内默认无法访问 https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
  <li> https://k8s.ruitong.cn:8080/K8s/dashboard/v2.7.0/aio/deploy/recommended.yaml
</div>



```bash
$ kubectl apply -f https://k8s.ruitong.cn:8080/K8s/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

```bash
$ kubectl -n kubernetes-dashboard get pods -owide
NAME                                         READY   STATUS    RESTARTS   AGE    IP              NODE          NOMINATED NODE   READINESS GATES
dashboard-metrics-scraper-799d786dbf-r7dp9   1/1     Running   0          115s   172.16.194.65   k8s-worker1   <none>           <none>
kubernetes-dashboard-546cbc58cd-2lvxt        1/1     Running   0          115s   172.16.126.1   `k8s-worker1`  <none>           <none>
```

```bash
$ kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard -p '{"spec":{"type":"NodePort"}}' 

$ kubectl -n kubernetes-dashboard get svc
NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP   10.103.222.187   <none>        8000/TCP        6m2s
kubernetes-dashboard       `NodePort`   10.97.233.31     <none>        443:`32433`/TCP   6m3s
```

> Chrome https://k8s-worker1:32443
>
> ​		==thisisunsafe==

![image-20220730165547778](https://i0.hdslb.com/bfs/album/13b60991fb18f5207ae4c25104a22332ac2f1af9.png)

```bash
*$ kubectl -n kubernetes-dashboard create token kubernetes-dashboard
`eyJhbGciOiJSUzI1NiIsImtpZCI6IkN6Zlo5dElKSFAyOXBkM2x0MWxxWU5yZkl1M2JzN1drZ2R1c1F3ZGVfdncifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNjY3NjIwNzY1LCJpYXQiOjE2Njc2MTcxNjUsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsInVpZCI6IjE1MGRiODQyLTE3N2EtNGU0Ny04ZDQyLWVlZmIyNDU0ZTk0ZSJ9fSwibmJmIjoxNjY3NjE3MTY1LCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQifQ.JpoEQqH2vDa-mMbvdhzTUfZ1BGfmQ4gY2TaJSb16EiQbqrh7KNGcH74cx8xLOgTppFCns_R-pdcg5yWKBsXYcksUotoTx1b4qRko6xEUV63bPz4eo5Z7bnMRWn_5WPqRY91z37xrbnW6DzYnhROJLGzBfNcIWi9f2gryda0P8q94kkunrb96YhXB3l_tUVUfrC8jGd0MsJMFv0ncQH_8a--w3EHKimaA5XNARlFw5iXtpcXkwL5Q7jJ-Jjml4Az-XS0pwECYrTBN23_PY6sqc62RrWRqL7NXWVcwFkWmlhw2AJk3mxZG6IiCiUnNRSg98D0l7M2jE2fOV9y_x1sV0w`

*$ kubectl -n kubernetes-dashboard create secret generic kubernetes-dashboard-token --from-literal=token=eyJhbGciOiJSUzI1NiIsImtpZCI6IkN6Zlo5dElKSFAyOXBkM2x0MWxxWU5yZkl1M2JzN1drZ2R1c1F3ZGVfdncifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNjY3NjIwNzY1LCJpYXQiOjE2Njc2MTcxNjUsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsInVpZCI6IjE1MGRiODQyLTE3N2EtNGU0Ny04ZDQyLWVlZmIyNDU0ZTk0ZSJ9fSwibmJmIjoxNjY3NjE3MTY1LCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQifQ.JpoEQqH2vDa-mMbvdhzTUfZ1BGfmQ4gY2TaJSb16EiQbqrh7KNGcH74cx8xLOgTppFCns_R-pdcg5yWKBsXYcksUotoTx1b4qRko6xEUV63bPz4eo5Z7bnMRWn_5WPqRY91z37xrbnW6DzYnhROJLGzBfNcIWi9f2gryda0P8q94kkunrb96YhXB3l_tUVUfrC8jGd0MsJMFv0ncQH_8a--w3EHKimaA5XNARlFw5iXtpcXkwL5Q7jJ-Jjml4Az-XS0pwECYrTBN23_PY6sqc62RrWRqL7NXWVcwFkWmlhw2AJk3mxZG6IiCiUnNRSg98D0l7M2jE2fOV9y_x1sV0w
```

> Chrome
>
> ​	使用以上token登陆，10个提示（权限）


```bash
$ kubectl -n kubernetes-dashboard describe clusterrole cluster-admin
...输出省略...
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  *.*        []                 []              [*]
             [*]                []              [*]

$ kubectl -n kubernetes-dashboard \
describe clusterrole kubernetes-dashboard
...输出省略...
PolicyRule:
  Resources             Non-Resource URLs  Resource Names  Verbs
  ---------             -----------------  --------------  -----
  nodes.metrics.k8s.io  []                 []              [get list watch]
  pods.metrics.k8s.io   []                 []              [get list watch]

*$ kubectl create clusterrolebinding kubernetes-dashboard-cluster-admin \
--clusterrole=cluster-admin \
--serviceaccount=kubernetes-dashboard:kubernetes-dashboard

$ kubectl get clusterrolebindings.rbac.authorization.k8s.io -owide | grep dash
kubernetes-dashboard-cluster-admin  ClusterRole/cluster-admin  6m34s  kubernetes-dashboard/kubernetes-dashboard
kubernetes-dashboard  ClusterRole/kubernetes-dashboard  88m  kubernetes-dashboard/kubernetes-dashboard
```



### <strong style='color: #92D400'>Lab13.</strong> Dashboard 避免使用的 args

> - ==- --enable-skip-login=true==
>   生产中不要使用这个选项

```bash
$ kubectl -n kubernetes-dashboard get pod
...输出省略...
kubernetes-dashboard`-6f8c86dcbc-2b4cq`        0/1     ContainerCreating   0          5m59s

$ kubectl -n kubernetes-dashboard edit deployments.apps kubernetes-dashboard
```

```yaml
...输出省略...
    spec:
      containers:
      - args:
        # 增加 1 行
        - --enable-skip-login=true
...输出省略...
```

```bash
$ kubectl -n kubernetes-dashboard get pod
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-799d786dbf-jvdc4   1/1     Running   0          11m
kubernetes-dashboard-546cbc58cd-6gcq5        1/1     Running   0          11m
kubernetes-dashboard-674467d558-5xkl2        1/1    `Running`   0          47s
```

![image-20220730165721416](https://i0.hdslb.com/bfs/album/c1e6f7d63d45966919663921163f9e6e73fe9f07.png)

> - ==- --enable-insecure-login=true==
>   生产中不要使用这个选项

```bash
$ kubectl -n kubernetes-dashboard edit deployments.apps kubernetes-dashboard
```

```yaml
...输出省略...
    spec:
      containers:
      - args:
# 增加 1 行
        - --enable-insecure-login=true
...输出省略...
```

```bash
$ kubectl -n kubernetes-dashboard get pod
NAME                                         READY   STATUS              RESTARTS   AGE
dashboard-metrics-scraper-799d786dbf-jvdc4   1/1     Running             0          14m
kubernetes-dashboard-674467d558-5xkl2        1/1     Running             0          3m59s
kubernetes-dashboard-8444446cf-8hcjv         1/1    `Running`   0          48s
```

> 现象：无登陆界面



## 1.6 检验文件

> - 二进制安装
>   - apt-key add
> - 源码安装
>   - hash
>     - md5
>     - sha1sum

```bash
$ wget https://dl.k8s.io/v1.24.1/kubernetes.tar.gz

$ sha512sum kubernetes.tar.gz
`51a10087465c18b067657b452b6d1302b7203cf66b1011d6603281d5f59bdcdf6f3eb43c9220a5f43492560360bc1c297c0618873409e5b221bcba10242f0c21`  kubernetes.tar.gz

$ curl -s https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.24.md#v1241 | grep -A 3 1.24.1.*kubernetes.tar.gz
```



# <strong style='color: #00B9E4'>2. 集群强化-15%</strong>

> 2.1 限制访问 Kubernetes API
>
> 2.2 使用基于角色的访问控制来最小化暴露
>
> 2.3 谨慎使用服务帐户，例如禁用默认设置，减少新创建帐户的权限
>
> 2.4 经常更新 Kubernetes

## 2.1 验证方式

```bash
$ kubectl config -h
Modify kubeconfig files using subcommands like "kubectl config set current-context my-context"

 The loading order follows these rules:

  1.  If the --kubeconfig flag is set, then only that file is loaded. The flag may only be set once and no merging ta/es place.
  2.  If $KUBECONFIG environment variable is set, then it is used as a list of paths (normal path delimiting rules for your system). These paths are merged. When a value is modified, it is modified in the file that defines the stanza. When a value is created, it is created in the first file that exists. If no files in the chain exist, then it creates the last file in the list.
  3.  Otherwise, ${HOME}/.kube/config is used and no merging takes place.
...输出省略...

$ ll /etc/kubernetes/admin.conf
cluser
name
context

$ kubectl --kubeconfig=/path/config
$ export KUBECONFIG=/path/config
$ mkdir ${HOME}/.kube \
&& cp /etc/kubernetes/admin.conf ${HOME}/.kube
```



### <strong style='color: #92D400'>Lab14.</strong> token-create

> 1. token对应服务帐号（sa/service account），服务帐号属于名字空间
> 2. kube-system 名字空间
> 3. token以机密（secrets）的形式保存

```bash
$ kubectl -n kube-system create sa dashboard-admin

$ SN=$(kubectl -n kube-system get secret | awk '/dashboard-admin/ {print $1}')
$ kubectl -n kube-system describe secrets ${SN}

$ kubectl create clusterrolebinding dashboard-admin \
--clusterrole=cluster-admin \
--serviceaccount=kube-system:dashboard-admin
```



### <strong style='color: #92D400'>Lab15.</strong> Kubeconfig-token-create

> \-d decrypt

```bash
DN: Dashboard Namespace
SN: Secret Name
$ DN=kubernetes-dashboard; SN=kubernetes-dashboard-token

$ DASH_TOKEN=$(kubectl -n ${DN} get secret ${SN} -o jsonpath={.data.token} | base64 -d)
```

set-cluster

```bash
$ ls dashboard-admin.kubeconfig || echo no exists

$ kubectl config set-cluster ck8s \
--certificate-authority=/etc/kubernetes/pki/ca.crt \
--embed-certs=true \
--server=https://192.168.147.141:6443 \
--kubeconfig=dashboard-admin.kubeconfig

$ cat dashboard-admin.kubeconfig
```

set-context

```bash
$ kubectl config set-context dashboard-admin@ck8s \
--cluster=ck8s \
--user=dashboard-admin \
--kubeconfig=dashboard-admin.kubeconfig

$ cat dashboard-admin.kubeconfig
```

set-credentials

```bash
$ kubectl config set-credentials dashboard-admin \
--token=${DASH_TOKEN} \
--kubeconfig=dashboard-admin.kubeconfig
```

use-context

```bash
$ kubectl config use-context dashboard-admin@ck8s \
--kubeconfig=dashboard-admin.kubeconfig

$ kubectl config current-context
kubernetes-admin@ck8s
```



### <strong style='color: #92D400'>Lab16.</strong> kubeconfig-cert

```bash
# 生成种子文件
openssl rand -writerand /home/kiosk/.rnd

cd /etc/kubernetes/pki

# 生成用户私钥/tom.key - 1/2
sudo openssl genrsa -out tom.key
sudo chmod +r tom.key

# 生成证书请求文件
sudo openssl req -new -key tom.key \
  -out tom.csr -subj "/CN=tom"
  
# 生成用户公钥/tom.crt - 2/2
sudo openssl x509 -req -in tom.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out tom.crt -days 365

cd
```

set-credentials

```bash
$ kubectl config set-credentials tom \
--client-certificate=/etc/kubernetes/pki/tom.crt \
--client-key=/etc/kubernetes/pki/tom.key \
--kubeconfig=tom.kubeconfig
```

set-cluster

```bash
kubectl config set-cluster ck8s \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --server=https://192.168.147.141:6443 \
  --kubeconfig=tom.kubeconfig
```

set-context

```bash
kubectl config set-context tom@ck8s \
  --cluster=ck8s \
  --user=tom \
  --kubeconfig=tom.kubeconfig
```

```bash
# 角色绑定
kubectl create clusterrolebinding crb-tom \
  --clusterrole=cluster-admin \
  --user=tom
```

```bash
# 切换集群
kubectl config use-context tom@ck8s \
  --kubeconfig=tom.kubeconfig

# 确认上一条命令的配置
kubectl config current-context \
  --kubeconfig=tom.kubeconfig

# 使用 tom 身份访问集群
kubectl get nodes --kubeconfig=tom.kubeconfig
kubectl --kubeconfig=tom.kubeconfig get nodes
```

```bash
# 方法1. 就一个集群
cp tom.kubeconfig ~/.kube/config

# 使用
k get nodes
```

```bash
# 方法2. 多个集群

编辑 ~/.kube/config, 合并tom.kubeconfig
```



## <strong style='color: #92D400'>Lab-.</strong> kubeconfig

```bash
$ kubectl -n kubernetes-dashboard edit deployments kubernetes-dashboard
删除之前增加的两个参数
```

```bash
安装桌面
$ sudo apt -y install ubuntu-desktop
```

物理机

```bash
$ scp kiosk@k8s-master:dashboard-admin.kubeconfig .
$ scp kiosk@k8s-master:tom.kubeconfig .
```

> - dashboard-admin.kubeconfig	文件中使用 token，dashboard 可以使用
> - tom.kubeconfig     文件中使用证书，命令行可以使用

## 2.2 RBAC



## 2.3 serviceAccount

> 没用的sa，怎么样能筛选出来呢？
>
> --A, -all-namespaces=false:

```bash
$ kubectl \
  -n prod \
  get pod \
  --output=custom-columns="Namespace:.metadata.namespace,Name:.metadata.name,Volumes:.volumes.*"
Namespace   Name          Volumes
prod        frontend-sa   <none>

$ k -n prod get sa
NAME          SECRETS   AGE
default       1         7d3h
frontend-sa   1         105m

```



## 2.4 更新 k8s





# <strong style='color: #00B9E4'>3. 系统强化-15%</strong>

> 3.1 最小化主机操作系统的大小(减少攻击面)
>
> 3.2 最小化 IAM 角色
>
> 3.3 最小化对网络的外部访问
>
> 3.4 适当使用内核强化工具，如 ==AppArmor==, seccomp

## 3.1 减少服务器的安全隐患

### <strong style='color: #92D400'>Lab17.</strong> 去除多余的系统模块

```bash
kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: pod1
  name: pod1
spec:
  containers:
  - image: centos
    command: ["sh","-c","sleep 10000"]
    imagePullPolicy: IfNotPresent
    name: pod1
EOF

```

```bash
$ kubectl get pod pod1 -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP             NODE          NOMINATED NODE   READINESS GATES
pod1   1/1     Running   0          9s    172.16.126.4  `k8s-worker2`   <none>           <none>
```

```bash
$ ssh root@k8s-worker2 lsmod | wc -l
`138`
$ kubectl exec pod1 -- lsmod | wc -l
`138`
```

```bash
$ ssh root@k8s-worker2 ls /etc/modprobe.d/*blacklist.conf
/etc/modprobe.d/amd64-microcode-blacklist.conf
/etc/modprobe.d/blacklist.conf
/etc/modprobe.d/intel-microcode-blacklist.conf

$ ssh root@k8s-worker2 cat /etc/modprobe.d/*blacklist.conf \
 | grep -v ^$ | grep -v ^#
blacklist microcode
blacklist evbug
blacklist usbmouse
blacklist usbkbd
blacklist eepro100
blacklist de4x5
blacklist eth1394
blacklist snd_intel8x0m
blacklist snd_aw2
blacklist prism54
blacklist bcm43xx
blacklist garmin_gps
blacklist asus_acpi
blacklist snd_pcsp
blacklist `pcspkr`
blacklist amd76x_edac
blacklist microcode

$ modinfo pcspkr
filename:       /lib/modules/5.4.0-107-generic/kernel/drivers/input/misc/pcspkr.ko
alias:          platform:pcspkr
license:        GPL
description:    PC Speaker beeper driver
...输出省略...
```

```bash
$ ssh root@k8s-worker2 modprobe pcspkr

$ ssh root@k8s-worker2 lsmod | grep pcspkr
`pcspkr`                 16384  0
```

```bash
$ ssh root@k8s-worker2 lsmod | wc -l
`138`
$ kubectl exec pod1 -- lsmod | wc -l
`138`
```



## 3.2 POLP - Principle Of Least Privilege

```bash
$ k -n kube-system \
  get clusterrolebindings -owide\
  | grep admin
cluster-admin  ClusterRole/cluster-admin  109d  system:masters
crb-tom  ClusterRole/cluster-admin  3h48m  tom
kubernetes-dashboard-cluster-admin ClusterRole/cluster-admin                                                          6d21h kubernetes-dashboard/kubernetes-dashboard
```



## 3.3 最小化对网络的外部访问



## 3.4 apparmor

### <strong style='color: #92D400'>Lab18.</strong> Apparmor-nginx

> **生产当中，一个应用如何创建规则文件**
>
> **nginx**
>
> ​	root	/www
>
> ​				 /www/{safe,unsafe}
>

1. 准备环境

```bash
# 安装
sudo apt -y install nginx

# 建立主目录
sudo mkdir -p /www/{safe,unsafe}

# 创建索引页
echo An Quan | sudo tee /www/safe/index.html
echo Bu An Quan | sudo tee /www/unsafe/index.html

# 更改root=/www, listen=81
sudo sed \
-i.bk "/^http/aserver {\n\t\tlisten 81;\n\t\tlocation / {\n\t\t\troot /www;\n\t\t}\n\t}" \
/etc/nginx/nginx.conf

# 生效
sudo systemctl restart nginx

# 测试，皆可正常访问
curl http://k8s-master:81/safe/
curl http://k8s-master:81/unsafe/
```

```bash
# 安装管理工具
sudo apt -y install apparmor-profiles apparmor-utils

# 切换到配置目录
cd /etc/apparmor.d/

# 手动生成 nginx 配置文件
sudo aa-autodep nginx
ls usr.sbin.nginx

# 重启服务
sudo systemctl restart nginx
```

2. 生成配置文件

```bash
# 安装记录需要的服务
sudo apt -y install rsyslog

# 开始记录
sudo aa-logprof
:<<EOF
Reading log entries from /var/log/syslog.
Updating AppArmor profiles in /etc/apparmor.d.
Complain-mode changes:

Profile:    /usr/sbin/nginx
Capability: dac_override
Severity:   9

 [1 - capability dac_override,]
(A)llow / [(D)eny] / (I)gnore / Audi(t) / Abo(r)t / (F)inish
`a`
Adding capability dac_override, to profile.

Profile:    /usr/sbin/nginx
Capability: setgid
Severity:   9

 [1 - #include <abstractions/dovecot-common>]
  2 - #include <abstractions/postfix-common>
  3 - capability setgid,
(A)llow / [(D)eny] / (I)gnore / Audi(t) / Abo(r)t / (F)inish
`a`
Adding #include <abstractions/dovecot-common> to profile.

Profile:  /usr/sbin/nginx
Path:     /var/log/nginx/error.log
New Mode: w
Severity: 8

 [1 - /var/log/nginx/error.log w,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / Abo(r)t / (F)inish 
`a`
Adding /var/log/nginx/error.log w, to profile.

Profile:  /usr/sbin/nginx
Path:     /etc/ssl/openssl.cnf
New Mode: owner r
Severity: 2

 [1 - #include <abstractions/openssl>]
  2 - #include <abstractions/ssl_keys>
  3 - owner /etc/ssl/openssl.cnf r,
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
 `a`
Adding #include <abstractions/openssl> to profile.

Profile:  /usr/sbin/nginx
Path:     /etc/nginx/nginx.conf
New Mode: owner r
Severity: unknown

 [1 - owner /etc/nginx/nginx.conf r,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
`a`
Adding owner /etc/nginx/nginx.conf r, to profile.

Profile:  /usr/sbin/nginx
Path:     /etc/nsswitch.conf
New Mode: owner r
Severity: unknown

 [1 - #include <abstractions/nameservice>]
  2 - owner /etc/nsswitch.conf r,
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
`a`
Adding #include <abstractions/nameservice> to profile.

Profile:  /usr/sbin/nginx
Path:     /etc/nginx/modules-enabled/
New Mode: owner r
Severity: unknown

 [1 - #include <abstractions/totem>]
  2 - owner /etc/nginx/modules-enabled/ r,
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
`a`
Adding #include <abstractions/totem> to profile.

Profile:  /usr/sbin/nginx
Path:     /var/www/html/index.nginx-debian.html
New Mode: r
Severity: unknown

 [1 - #include <abstractions/web-data>]
  2 - /var/www/html/index.nginx-debian.html r,
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / Abo(r)t / (F)inish
`a`
Adding #include <abstractions/web-data> to profile.

Profile:  /usr/sbin/nginx
Path:     /var/log/nginx/access.log
New Mode: owner w
Severity: 8

 [1 - owner /var/log/nginx/access.log w,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
`a`
Adding owner /var/log/nginx/access.log w, to profile.

Profile:  /usr/sbin/nginx
Path:     /run/nginx.pid
New Mode: owner w
Severity: unknown

 [1 - owner /run/nginx.pid w,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
`a`
Adding owner /run/nginx.pid w, to profile.

Profile:  /usr/sbin/nginx
Path:     /www/index.html
New Mode: r
Severity: unknown

 [1 - /www/index.html r,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / Abo(r)t / (F)inish
`a`
Adding /www/index.html r, to profile.

Profile:  /usr/sbin/nginx
Path:     /www/unsafe/index.html
New Mode: r
Severity: unknown

 [1 - /www/unsafe/index.html r,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / Abo(r)t / (F)inish
`d`
Adding /www/unsafe/index.html r, to profile.

Profile:  /usr/sbin/nginx
Path:     /etc/nginx/mime.types
New Mode: owner r
Severity: unknown

 [1 - owner /etc/nginx/mime.types r,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
Adding owner /etc/nginx/mime.types r, to profile.

Profile:  /usr/sbin/nginx
Path:     /etc/nginx/sites-available/default
New Mode: owner r
Severity: unknown

 [1 - owner /etc/nginx/sites-available/default r,]
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
Adding owner /etc/nginx/sites-available/default r, to profile.

= Changed Local Profiles =

The following local profiles were changed. Would you like to save them?

 [1 - /usr/sbin/nginx]
(S)ave Changes / Save Selec(t)ed Profile / [(V)iew Changes] / View Changes b/w (C)lean profiles / Abo(r)t
`s`
Writing updated profile for /usr/sbin/nginx.
:EOF
```

```bash
新版本Apparmor需要多次重启，生成配置
直到服务可以正常启动
$ sudo systemctl restart nginx
$ sudo aa-logprof
```

```bash
$ sudo vim usr.sbin.nginx
```

```ini
  ...此处省略...
  capability dac_override,
  # 增加 2 行，查看 /var/log/nginx/error.log
  capability setgid,
  capability setuid,
  # 增加 1 行
  /www/safe/index.html r,
  ...此处省略...
```

```bash
sudo systemctl restart apparmor
sudo systemctl restart nginx
```

3. 测试

```bash
$ curl localhost:81/safe/
An Quan

$ curl localhost:81/unsafe/
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.18.0 (Ubuntu)</center>
</body>
</html>
```



## 3.4 seccomp

```bash
$ strace -fqc cat /etc/hosts
127.0.0.1 localhost

192.168.147.128 k8s-master
192.168.147.129 k8s-worker1
192.168.147.130 k8s-worker2
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
  0.00    0.000000           0         3           read
  0.00    0.000000           0         1           write
  0.00    0.000000           0         6           close
  0.00    0.000000           0         5           fstat
  0.00    0.000000           0         9           mmap
  0.00    0.000000           0         3           mprotect
  0.00    0.000000           0         2           munmap
  0.00    0.000000           0         3           brk
  0.00    0.000000           0         6           pread64
  0.00    0.000000           0         1         1 access
  0.00    0.000000           0         1           execve
  0.00    0.000000           0         2         1 arch_prctl
  0.00    0.000000           0         1           fadvise64
  0.00    0.000000           0         4           openat
------ ----------- ----------- --------- --------- ----------------
100.00    0.000000                    47         2 total
```

### <strong style='color: #92D400'>Lab19.</strong> seccomp

- Docker

```bash
运行默认的 seccomp 配置文件
# docker container run --rm -it alpine sh

运行时不使用 seccomp 配置文件
# docker run --rm -it --security-opt seccomp=unconfined alpine sh
```

- K8s

```bash
$ ssh root@k8s-worker1
# vim /var/lib/kubelet/config.yaml
```

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
# 增加 3 行
featureGates:
  SeccompDefault: true
seccomp-default: true
...输出省略...
```

```bash
# systemctl restart kubelet
```

<kbd>Ctrl</kbd>-<kbd>D</kbd>

```yaml
$ kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: default-seccomp
spec:
# 增加 3 行
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  nodeSelector:
    kubernetes.io/hostname: k8s-worker1
  containers:
  - name: test-container
    image: registry.cn-hangzhou.aliyuncs.com/k-cks/amicontained
    imagePullPolicy: IfNotPresent
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "amicontained" ]
    securityContext:
      allowPrivilegeEscalation: false
EOF
```

```bash
$ kubectl logs default-seccomp
Container Runtime: docker
Has Namespaces:
	pid: true
	user: false
AppArmor Profile: docker-default (enforce)
Capabilities:
	BOUNDING -> chown dac_override fowner fsetid kill setgid setuid setpcap net_bind_service net_raw sys_chroot mknod audit_write setfcap
Seccomp: filtering
Blocked Syscalls (`60`):
	SYSLOG SETPGID SETSID USELIB USTAT SYSFS VHANGUP PIVOT_ROOT _SYSCTL ACCT SETTIMEOFDAY MOUNT UMOUNT2 SWAPON SWAPOFF REBOOT SETHOSTNAME SETDOMAINNAME IOPL IOPERM CREATE_MODULE INIT_MODULE DELETE_MODULE GET_KERNEL_SYMS QUERY_MODULE QUOTACTL NFSSERVCTL GETPMSG PUTPMSG AFS_SYSCALL TUXCALL SECURITY LOOKUP_DCOOKIE CLOCK_SETTIME VSERVER MBIND SET_MEMPOLICY GET_MEMPOLICY KEXEC_LOAD ADD_KEY REQUEST_KEY KEYCTL MIGRATE_PAGES UNSHARE MOVE_PAGES PERF_EVENT_OPEN FANOTIFY_INIT NAME_TO_HANDLE_AT OPEN_BY_HANDLE_AT SETNS PROCESS_VM_READV PROCESS_VM_WRITEV KCMP FINIT_MODULE KEXEC_FILE_LOAD BPF USERFAULTFD PKEY_MPROTECT PKEY_ALLOC PKEY_FREE
Looking for Docker.sock
```



# <strong style='color: #00B9E4'>4. 微服务漏洞最小化：20%</strong>

> 4.1 设置适当的 OS 级安全域，例如使用 ==PSP==, OPA，安全上下文
>
> 4.2 管理 Kubernetes ==机密==
>
> 4.3 在多租户环境中使用容器运行时 (例如 ==gvisor==, kata 容器)
>
> 4.4 使用 mTLS 实现 Pod 对 Pod 加密

## 4.1 PSP-Pod Security Policy

```bash
$ kubectl label \
  --dry-run=server --overwrite ns --all \
  pod-security.kubernetes.io/enforce=privileged

namespace/default labeled
namespace/kube-node-lease labeled
namespace/kube-public labeled
namespace/kube-system labeled
```

```bash
$ kubectl label \
  --dry-run=server --overwrite ns --all \
  pod-security.kubernetes.io/enforce=baseline

namespace/default labeled
namespace/kube-node-lease labeled
namespace/kube-public labeled
Warning: existing pods in namespace "kube-system" violate the new PodSecurity enforce level "baseline:latest"
Warning: calico-node-75k64 (and 5 other pods): host namespaces, hostPath volumes, privileged
Warning: etcd-k8s-master (and 3 other pods): host namespaces, hostPath volumes
namespace/kube-system labeled
```

```bash
$ kubectl label \
  --dry-run=server --overwrite ns --all \
  pod-security.kubernetes.io/enforce=restricted

Warning: existing pods in namespace "default" violate the new PodSecurity enforce level "restricted:latest"
Warning: default-seccomp: unrestricted capabilities, runAsNonRoot != true
namespace/default labeled
namespace/kube-node-lease labeled
namespace/kube-public labeled
Warning: existing pods in namespace "kube-system" violate the new PodSecurity enforce level "restricted:latest"
Warning: calico-kube-controllers-7c845d499-qzgrz: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
Warning: calico-node-75k64 (and 5 other pods): host namespaces, hostPath volumes, privileged, allowPrivilegeEscalation != false, unrestricted capabilities, restricted volume types, runAsNonRoot != true, seccompProfile
Warning: coredns-6d8c4cb4d-28tj5 (and 1 other pod): unrestricted capabilities, runAsNonRoot != true, seccompProfile
Warning: etcd-k8s-master (and 3 other pods): host namespaces, hostPath volumes, allowPrivilegeEscalation != false, unrestricted capabilities, restricted volume types, runAsNonRoot != true
namespace/kube-system labeled
```



## Task 5. PSP（<1.25 考点）

<div style="background: #F9DBD8; padding: 12px; margin-bottom: 24px;">
  您<b>必须</b>在以下 cluster /节点上完成此考考题：<br>
  <dl style="margin-bottom: 74px;">
    <dt style="float: left; width: 33%;"><b>Cluster</b></dt>
    <dt style="float: left; width: 33%;"><b>Master 节点</b></dt>
    <dt style="float: left; width: 33%;"><b>工作节点</b></dt>
<dt style="float: left; width: 33%;"><a>ck8s</a>
<dt style="float: left; width: 33%;"><a>ck8s-master</a></dt>
<dt style="float: left; width: 33%;"><a>ck8s-worker1</a></dt>
  </dl>
您可以使用以下命令来切换 cluster / <b>配置环境</b>：
<dt style="background: #EFEFEF; padding: 12px; line-height: 24px; margin-bottom: 6px; margin-top: 6px;" >
  [kiosk@cli]$ <a>kubectl config use-context ck8s</a>
  </dt>
</div>


**Context**

PodSecurityPolicy 应防止在特定 namespace 中特权 Pod 的创建。

**Task**

创建一个名为 <a>prevent-psp-policy</a> 的新 PodSecurityPolicy，以防止特权Pod 的创建。

创建一个名为 <a>restrict-access-role</a> 并使用新创建的 PodSecurityPolicy <a>prevent-psp-policy</a> 的 ClusterRole。

在现有 namespace <a>development</a> 中创建一个名为 <a>psp-denial-sa</a> 的新 ServiceAccount。

最后，新建一个名为 <a>dany-access-bind</a> 的 ClusterRoleBinding，将新创建的 ClusterRole <a>restrict-access-role</a> 绑定到新创建的ServiceAccount <a>psp-denial-sa</a>。

<div style="background: #CFE2F0; padding: 12px; line-height: 24px; margin-bottom: 24px; ">
  您可以在以下位置找到模板清单文件：
  <li> <a>/home/kiosk/KSMV00102/pod-security-policy.yaml</a>
  <li> <a>/home/kiosk/KSMV00102/cluster-role.yaml</a>
  <li> <a>/home/kiosk/KSMV00102/service-account.yaml</a> 
	<li> <a>/home/kiosk/KSMV00102/cluster-role-binding.yaml</div>


<div style="background: #dbfaf4; padding: 12px; line-height: 24px; margin-bottom: 24px;">
<dt style="background: #1abc9c; padding: 6px 12px; font-weight: bold; display: block; color: #fff; margin: -12px; margin-bottom: -12px; margin-bottom: 12px;" >Hint - 提示</dt>
  <li> kiosk@k8s-master:~$ <b>cks-setup 5</b>
</div>
<hr>
<div style='background: #113362; padding: 12px; margin-bottom: 24px; display: table; width: 100%'>
 <dt style="background: #4198C7; padding: 6px; line-height: 20px; color: #FFFFFF; weight: 40px; float: left;">Readme</dt>
 <dt style="background: #307195; padding: 6px; line-height: 20px; color: #FFFFFF; float: left;">>_Web Terminal</dt>
  <dt style="padding: 6px; line-height: 20px; color: #FFFFFF; float: right;"><b>参考答案</b></dt>
</div>
<hr>


![][cli]**[kiosk@cli]**

1. 切换 kubernetes

```bash
*$ kubectl config use-context ck8s
```

2. 确认已启用 PSP

```bash
$ ssh root@k8s-master

# vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```ini
...此处省略...
   #- --enable-admission-plugins=NodeRestriction
    - --enable-admission-plugins=NodeRestriction,PodSecurity
...
```



3. 参考官方手册，创建并编辑 yaml
   	`kind: PodSecurityPolicy`
   		[Pod Security Policy | Kubernetes](https://kubernetes.io/id/docs/concepts/policy/pod-security-policy/)		

```bash
*$ vim 5-psp.yml
```

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
# name: example
  name: prevent-psp-policy
spec:
  # 题意要求，值匹配
  privileged: false
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
  - '*'
```

4. 创建 PSP

```bash
*$ kubectl apply -f 5-psp.yml
```

5. 创建 clusterrole

```bash
*$ kubectl create clusterrole restrict-access-role \
  --resource=psp \
  --verb=use \
  --resource-name=prevent-psp-policy
  
```

6. 创建 serviceaccount

```bash
*$ kubectl -n development create sa psp-denial-sa
```

7. 创建 clusterrolebinding

```bash
*$ kubectl create clusterrolebinding dany-access-bind \
     --clusterrole=restrict-access-role \
     --serviceaccount=development:psp-denial-sa
```

8. 验证

```bash
$ kubectl get podsecuritypolicies.policy prevent-psp-policy
NAME                 PRIV     ...
prevent-psp-policy  `false`   ...

$ kubectl get clusterrole restrict-access-role -o yaml
...输出省略...
rules:
- apiGroups:
  - policy
  resourceNames:
  - `prevent-psp-policy`
  resources:
  - `podsecuritypolicies`
  verbs:
  - `use`
  
$ kubectl -n development get sa
NAME            SECRETS   AGE
default         1         17m
`psp-denial-sa` 1         80m

$ kubectl get clusterrolebindings dany-access-bind -o wide
NAME               ROLE                               AGE   USERS   GROUPS   SERVICEACCOUNTS
dany-access-bind   ClusterRole/restrict-access-role   79m                    development/psp-denial-sa
```

9. 实验现象

```bash
$ kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: t2
spec:
  containers:
  - name: pod1
    image: nginx
    securityContext:
      privileged: true
EOF
Error from server (Forbidden): error when creating "STDIN": pods "t3" is forbidden: `PodSecurityPolicy`: unable to admit pod: [spec.containers[0].securityContext.privileged: Invalid value: true: Privileged containers are not allowed]

$ kubectl -n development \
  run t1 --image=nginx --image-pull-policy=IfNotPresent
pod/t1 created
```



## 4.1 OPA-Open Policy Agent

### <strong style='color: #92D400'>Lab20.</strong> [gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/install/)

> https://github.com/open-policy-agent/gatekeeper
>
> https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
>
> https://k8s.ruitong.cn:8080/K8s/open-policy-agent/gatekeeper.yaml

```bash
kubectl apply -f https://k8s.ruitong.cn:8080/K8s/open-policy-agent/gatekeeper.yaml

$ kubectl -n gatekeeper-system get pods
NAME                                          READY   STATUS    RESTARTS   AGE
gatekeeper-audit-57c46f85bf-sxnf6             1/1     `Running   0          4m28s
gatekeeper-controller-manager-9fff5d5-5nnwv   1/1     `Running   0          4m28s
gatekeeper-controller-manager-9fff5d5-kdbt7   1/1     `Running   0          4m28s
gatekeeper-controller-manager-9fff5d5-zs4lw   1/1     `Running   0          4m28s
```

```yaml
# ConstraintTemplate
kubectl apply -f- <<EOF
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: blacklistimages
spec:
  crd:
    spec:
      names:
        kind: BlacklistImages
  targets:
  - rego: |
      package k8strustedimages
      
      images {
        image := input.review.object.spec.containers[_].image
        not startswith(image, "tom.163.com/")
        not startswith(image, "jerry.163.com/")
      }
      violation[{"msg": msg}] {
        not images
        msg := "not trusted image!"
      }
    target: admission.k8s.gatekeeper.sh
EOF
```

```yaml
# BlacklistImages
kubectl apply -f- <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: BlacklistImages
metadata:
  generation: 1
  managedFields:
  name: pod-trusted-images
  resourceVersion: "14449"
spec:
  match:
    kinds:
    - apiGroups:
      - ""
      kinds:
      - Pod
EOF
```

```bash
$ kubectl get BlacklistImages
NAME                 AGE
pod-trusted-images   8s
```

```bash
# bash completion
source <(crictl completion bash)

# 拉取镜像
sudo crictl pull nginx

for i in tom jerry spike; do
  sudo ctr -n k8s.io i tag docker.io/library/nginx:latest $i.163.com/nginx:latest
done

sudo crictl images | grep nginx
```

```bash
$ kubectl run w1 --image=tom.163.com/nginx --image-pull-policy=IfNotPresent
Error from server ([pod-trusted-images] not trusted image!): admission webhook "validation.gatekeeper.sh" `denied` the request: [pod-trusted-images] not trusted image!

$ kubectl run w2 --image=jerry.163.com/nginx --image-pull-policy=IfNotPresent
Error from server ([pod-trusted-images] not trusted image!): admission webhook "validation.gatekeeper.sh" `denied` the request: [pod-trusted-images] not trusted image!

$ kubectl run w3 --image=spike.163.com/nginx --image-pull-policy=IfNotPresent
`pod/w3 created`

$ kubectl run w4 --image=nginx --image-pull-policy=IfNotPresent
`pod/w4 created`
```



## 4.1 安全上下文



## 4.2 secret

### <strong style='color: #92D400'>Lab21.</strong> [Env](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-secrets-as-environment-variables)

```bash
# mysql
kubectl create secret generic db1-pass \
  --from-literal=password='P@33w0rd'
```

```yaml
# pod
kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mysql
spec:
  containers:
  - name: db1
    image: mysql
    env:
      - name: MYSQL_ROOT_PASSWORD
        valueFrom:
          secretKeyRef:
            name: db1-pass
            key: password
            optional: false
EOF
```

```bash
$ kubectl get pods -owide
NAME    READY   STATUS    RESTARTS   AGE     IP             NODE          NOMINATED NODE   READINESS GATES
mysql   1/1     Running   0          101s    `172.16.126.8`  k8s-worker2   <none>           <none>
```

```bash
$ sudo apt update \
  && sudo apt -y install mysql-client \
  && mysql -h 172.16.126.8 -u root -pP@33w0rd -e 'show databases;'
  
mysql: [Warning] Using a password on the command line interface can be insecure.
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
```



### <strong style='color: #92D400'>Lab22.</strong> [docker-registry](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-imagepullsecrets)

> https://hub.docker.com/signup
>
> 注册一个帐号

```bash
DUSER=adder99
DPASS=jiubugaosuni

sudo docker pull busybox
sudo docker tag busybox:latest $DUSER/busybox:latest

sudo docker login -u $DUSER -p $DPASS

sudo docker push $DUSER/busybox:latest

sudo docker logout
```

```bash
$ sudo docker pull $DUSER/busybox
Using default tag: latest
Error response from daemon: pull access denied for $DUSER/busybox, repository does not exist or may require 'docker login': denied: requested access to the resource is denied
```



```bash
kubectl create secret docker-registry user-pass \
  --docker-server=docker.io \
  --docker-username=$DUSER \
  --docker-password=$DPASS
```

#### [官网手册](https://kubernetes.io/zh-cn/docs/concepts/configuration/secret/#docker-config-secrets) / [在 Pod 上指定 ImagePullSecrets](https://kubernetes.io/zh-cn/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod)

```yaml
kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
spec:
# 增加 2 行
  imagePullSecrets:
  - name: user-pass
  containers:
    - name: test-container
      image: docker.io/$DUSER/busybox
      command: ['sh', '-c', 'echo "Hello, Kubernetes!" && sleep 3600']
EOF

```

```bash
$ kubectl describe pod secret-test-pod
...输出省略...
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  56s   default-scheduler  Successfully assigned default/secret-test-pod to k8s-worker2
  Normal  Pulling    55s   kubelet            Pulling image "docker.io/$DUSER/busybox"
  Normal  Pulled     1s    kubelet            Successfully pulled image "docker.io/$DUSER/busybox" in 54.075580447s
  Normal  Created    1s    kubelet            Created container test-container
  Normal  Started    1s    kubelet            Started container test-container
  
$ k get pods -owide
NAME              READY   STATUS             RESTARTS      AGE     IP              NODE          NOMINATED NODE   READINESS GATES
secret-test-pod   1/1     Running   0          78s    172.16.126.15  `k8s-worker2`   <none>           <none>

$ ssh root@k8s-worker2 crictl images | grep busybox
```



## 4.3 runtimeClass-kata

### <strong style='color: #92D400'>Lab23.</strong> kata

> 1. VMware - CPU启用虚拟化
>
>    复选`在此虚拟机中启用 Hypervisor`
>
> 2. VMware - 选择固件类型（==嵌套虚拟化==）
>
>    物理机是 macOS 系统，Ubuntu 安装时应选择 `UEFI`

**[kiosk@k8s-worker1]**

```bash
$ sudo snap download core
$ sudo snap download kata-containers

$ sudo snap ack core_*.assert;
  sudo snap install core_*.snap

$ sudo snap ack kata-containers_*.assert;
  sudo snap install kata-containers_*.snap --classic
  
$ sudo cp /snap/kata-containers/2167/usr/bin/* /usr/bin/
```

> AMD CPU 需执行下面两步

```bash
$ echo "options kvm ignore_msrs=1" | sudo tee /etc/modprobe.d/kvm-ignore-msrs.conf
$ echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs
```

```bash
$ sudo /snap/bin/kata-containers.runtime kata-check
...输出省略...
ERRO[0000] kernel property vhost_vsock not found         arch=amd64 description="Host Support for Linux VM Sockets" name=vhost_vsock pid=14141 source=runtime type=module
System is capable of running Kata Containers
System can currently create Kata Containers

$ sudo tee /etc/modprobe.d/blacklist-vmware.conf <<EOF
blacklist vmw_vsock_virtio_transport_common
blacklist vmw_vsock_vmci_transport
EOF

$ sudo reboot

$ sudo /snap/bin/kata-containers.runtime kata-check
WARN[0000] Not running network checks as super user      arch=amd64 name=kata-runtime pid=1698 source=runtime
System is capable of running Kata Containers
System can currently create Kata Containers
```

> 默认已经安装 containerd

```bash
$ sudo mkdir /etc/containerd
$ containerd config default | sudo tee /etc/containerd/config.toml
```

```bash
$ sudo vim /etc/containerd/config.toml
```

> SEE ALSO: 
>
> - https://k8s.ruitong.cn:8080/K8s/kata/config.toml

```bash
$ sudo systemctl restart containerd

$ sudo tee /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

> k8s 支持 containerd

```bash
$ sudo tee /etc/systemd/system/kubelet.service.d/0-cri-containerd.conf <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock --cgroup-driver=systemd"
EOF

$ sudo systemctl daemon-reload
$ sudo systemctl restart kubelet
```

**[kiosk@k8s-master] $**

```yaml
kubectl apply -f- <<EOF
kind: RuntimeClass
apiVersion: node.k8s.io/v1beta1
metadata:
  name: kata-containers
handler: kata
EOF

```

```bash
$ kubectl get runtimeclass
NAME              HANDLER   AGE
kata-containers   kata      8s
```

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kata-nginx
spec:
  runtimeClassName: kata-containers
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
EOF
```

```bash
$ kubectl get pods -owide
```



## 4.3 runtimeClass-gVisor





## 4.4 TLS

> - 通配符
>   - *.example.com / cert-manager
>   - www.example.com / certbot
> - ACME
>   - HTTP01 -=> 80
>   - DNS01 / 通配符
> - [certbot](https://certbot.eff.org/) -=> single
> - [cert-manager](https://cert-manager.io/) -=> K8s

<a name="Lab24"></a>

### <strong style='color: #92D400'>Lab24.</strong> [nginx-ingress](https://kubernetes.io/zh/docs/concepts/services-networking/ingress-controllers/)

1. 创建 ingress-nginx

[kiosk@k8s-master]$

```bash
# 创建 Pod
kubectl run pod1 --image=nginx --image-pull-policy=IfNotPresent
# 创建 服务
kubectl expose pod pod1 --port=80

# Ingress-NGINX version		k8s supported version
# 大于等于 v1.3.0          `1.24`, 1.23, 1.22, 1.21, 1.20
wget https://k8s.ruitong.cn:8080/K8s/ingress-nginx/controller-v1.5.1/deploy.yml -O ingress-nginx.yml
## pull images,通过yml文件判断版本
URL=registry.aliyuncs.com/google_containers
URL1=$URL/nginx-ingress-controller:v1.5.1
URL2=$URL/kube-webhook-certgen:v20220916-gd32f8c343

sudo ctr ns ls

for n in k8s-worker1 k8s-worker2; do
  for i in $URL1 $URL2; do
    sudo ctr -n k8s.io i pull $i
  done
done
## 创建 ingress-nginx
sed -i -e '/dnsPolicy/i\      hostNetwork: true' \
     -e "/image.*controller/s+:.*+: $URL1+" \
     -e "/image.*kube-webhook-certgen/s+:.*+: $URL2+" ingress-nginx.yml

kubectl apply -f ingress-nginx.yml

```

```bash
$ kubectl -n ingress-nginx get pod
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-5n98z        0/1    `Completed`  0          18s
ingress-nginx-admission-patch-rb6qv         0/1    `Completed`  0          18s
ingress-nginx-controller-8679f5b494-xw4gd   1/1    `Running`    0          18s
```

4. 创建 ingress

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
# 添加1行
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pod1
            port:
              number: 80
EOF

```

5. 验证

```bash
$ kubectl get pods -A -o wide |grep ingress.*control
ingress-nginx   ingress-nginx-controller-8679f5b494-c7gt4   1/1     Running     0              61m   `192.168.147.129`  k8s-worker1   <none>           <none>

$ curl -s http://192.168.147.129 | grep -i welcome
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```



### <strong style='color: #92D400'>Lab25.</strong> [CFSSL](https://kubernetes.io/zh/docs/tasks/administer-cluster/certificates/#cfssl)-自签名证书

> - 服务器www.opensu.ink
>- 使用==/etc/hosts==解析
> - 前题：已完成 <strong style='color: #92D400'>Lab24.</strong> [nginx-ingress](#Lab24)

1. 下载、解压并准备如下所示的命令行工具

```bash
CURL=https://k8s.ruitong.cn:8080/K8s/CloudFlare/cfssl
curl -# $CURL/cfssl_1.6.1_linux_amd64 -o cfssl
curl -# $CURL/cfssljson_1.6.1_linux_amd64 -o cfssljson
curl -# $CURL/cfssl-certinfo_1.6.1_linux_amd64 -o cfssl-certinfo
chmod +x cfssl*; PATH=$PATH:~

```

2. 创建一个目录，用它保存所生成的构件和初始化 cfssl

```bash
$ cfssl print-defaults config > ca-config.json

$ cfssl print-defaults csr > ca-csr.json
```

3. 创建一个 JSON 配置文件来生成 CA 文件

```bash
$ vim ca-config.json
```

```json
{
    "signing": {
        "default": {
            "expiry": "168h"
        },
        "profiles": {
            "www": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
//          },
//          "client": {
//              "expiry": "8760h",
//              "usages": [
//                  "signing",
//                  "key encipherment",
//                  "client auth"
//              ]
            }
        }
    }
}
```

4. 创建一个 JSON 配置文件，用于 CA 证书签名请求（CSR）

> 可以定义多个 profiles，为不同的机构颁发证书，分别指定不同的过期时间、使用场景等参数；
>
> 后续在签名证书时使用某个 profile

|    ITEM     |         COMMON         | DESCRIPTION                                                  |
| :---------: | :--------------------: | ------------------------------------------------------------ |
|   signing   |                        | 表示该证书可用于签名其它证书；生成的 ca.pem 证书中 CA=TRUE   |
| server auth |                        | 表示client可以用该 CA 对server提供的证书进行验证             |
| client auth |                        | 表示server可以用该CA对client提供的证书进行验证；<br>当client和server互相需要认证时，被称为mTLS |
|   ==CN==    |      Common Name       | 浏览器使用该字段验证网站是否合法，一般写的是域名             |
|      C      |        Country         | 国家                                                         |
|      L      |        Locality        | 地区，城市                                                   |
|      O      |   Organization Name    | 组织名称，公司名称                                           |
|     OU      | Organization Unit Name | 组织单位名称，公司部门                                       |
|     ST      |         State          | 州，省                                                       |

```bash
$ vim ca-csr.json
```

> //开头的都删除

```json
{
//"CN": "example.net",
  "CN": "opensu.ink",
//"hosts": [
//      "example.net",
//      "www.example.net"
//  ],
  "key": {
        "algo": "ecdsa",
        "size": 256
    },
  "names": [
        {
//  "C": "US",
    "C": "CN",
//  "ST": "CA",
    "ST": "BEIJING",
//  "L": "San Francisco"
    "L": "Bei Jing"
        }
    ]
}
```

5. 生成 CA 秘钥文件（`ca-key.pem`）和证书文件（`ca.pem`）

```bash
$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca

$ ls ca*
ca-config.json  ca-csr.json  `ca.pem`  ca.csr  `ca-key.pem`
```

6. 创建一个 JSON 配置文件，用来为 API 服务器生成秘钥和证书

```bash
$ cfssl print-defaults csr > server-csr.json

$ vim server-csr.json
```

```bash
{
//  "CN": "example.net",
    "CN": "www.opensu.ink",
    "hosts": [
//      "example.net",
//      "www.example.net"
        "www.opensu.ink"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "CN",
            "ST": "BEIJING",
            "L": "Bei Jing"
        }
    ]
}
```

7. 为 API 服务器生成秘钥和证书，默认会分别存储为`server-key.pem` 和 `server.pem` 两个文件

```bash
$ cfssl gencert -ca=ca.pem -ca-key=ca-key.pem \
--config=ca-config.json -profile=www \
server-csr.json | cfssljson -bare server

$ ls server*
server.csr  `server-key.pem`  server-csr.json  `server.pem`
```

8. 创建机密

```bash
$ kubectl create secret \
    tls www-com-tls \
    --cert=server.pem \
    --key=server-key.pem
```

9. 创建 一个 [Ingress 资源](https://kubernetes.io/zh/docs/concepts/services-networking/ingress/#the-ingress-resource)

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: www-com
spec:
# 添加 5 行
  ingressClassName: nginx
  tls:
  - hosts:
    - www.opensu.ink
    secretName: www-com-tls
  rules:
# 添加 1 行
  - host: www.opensu.ink
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pod1
            port:
              number: 80
EOF

```

10. 测试

> \-k	忽略证书https，自签名证书
>
> \-v	verbose详细模式

```bash
IP地址无法匹配证书
$ curl -kv https://192.168.147.129
...输出省略...
* Server certificate:
*  subject: `O=Acme Co; CN=Kubernetes Ingress Controller Fake Certificate`
...输出省略...
*  issuer: `O=Acme Co; CN=Kubernetes Ingress Controller Fake Certificate`
...输出省略...

DNS名称可以匹配证书，需要解析
$ sudo tee -a /etc/hosts <<EOF
192.168.147.129 www.opensu.ink
EOF
$ curl -kv https://www.opensu.ink
...输出省略...
* Server certificate:
*  subject: `C=CN; ST=BEIJING; L=Bei Jing; CN=www.opensu.ink`
...输出省略...
*  issuer: `C=CN; ST=BEIJING; L=Bei Jing; CN=opensu.ink`
...输出省略...
```

<a name="Lab26"></a>

### <strong style='color: #92D400'>Lab26.</strong> [cert-manager](https://cert-manager.io/docs/installation/)<img height=30 src="https://cert-manager.io/images/cert-manager-logo-icon.svg"> - 自动签发证书

> 已完成 <strong style='color: #92D400'>Lab24.</strong> [nginx-ingress](#Lab22)
>
> ==opensu.ink== 指的是花钱买的域名
>
> coen.ns.cloudflare.com， etta.ns.cloudflare.com
> 	http://dash.cloudflare.com/

1. [安装 cert-manager](https://cert-manager.io/docs/installation/kubectl/)（方法一：yaml）

```bash
$ kubectl apply -f https://k8s.ruitong.cn:8080/K8s/CloudFlare/cert-manager/v1.8.0/cert-manager.yaml
```

1. 安装 cert-manager（方法二：helm，针对Lab29/Lab30）**建议使用**

```bash
$ sudo apt -y install apt-file
$ sudo apt-file update
$ sudo apt-file search nslookup | grep bin/nslookup
$ sudo apt -y install bind9-dnsutils
```

```bash
$ nslookup opensu.ink coen.ns.cloudflare.com
Server:		coen.ns.cloudflare.com
Address:	`108.162.195.151`#53

Name:	opensu.ink
Address: 211.103.158.66

$ nslookup opensu.ink etta.ns.cloudflare.com
Server:		etta.ns.cloudflare.com
Address:	`172.64.32.156`#53

Name:	opensu.ink
Address: 211.103.158.66
```

[kiosk@k8s-master] $

```bash
# install helm
# https://helm.sh/zh/docs/intro/install/
FHELM=helm-v3.10.2-linux-amd64.tar.gz
curl -# https://k8s.ruitong.cn:8080/K8s/helm/$FHELM -o $FHELM
tar -xf $FHELM
sudo cp linux-amd64/helm /usr/local/bin

# install cert-manager
helm repo add jetstack https://charts.jetstack.io \
&& helm repo update \
&& helm install cert-manager jetstack/cert-manager \
  --create-namespace \
  --namespace cert-manager \
  --set installCRDs=true \
  --version v1.8.0 \
  --set 'extraArgs={--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=108.162.195.151:53\,172.64.32.156:53}'

```

2. 验证安装成功

```bash
$ kubectl -n cert-manager get pods
NAME                                      READY   STATUS    RESTARTS  AGE
cert-manager-64d9bc8b74-hnf76             1/1    `Running`   0        36s
cert-manager-cainjector-6db6b64d5f-8zmgk  1/1    `Running`   0        36s
cert-manager-webhook-6c9dd55dc8-mvfkl     1/1    `Running`   0        36s

$ kubectl get crd | grep cert
certificates.cert-manager.io					...
certificaterequests.cert-manager.io		...
clusterissuers.cert-manager.io				...
issuers.cert-manager.io								...
orders.acme.cert-manager.io						...
challenges.acme.cert-manager.io				...
```



### <strong style='color: #92D400'>Lab27.</strong> CFSSL :heavy_plus_sign: cert-manager<img height=30 src="https://cert-manager.io/images/cert-manager-logo-icon.svg"> - 自动签发自签名证书

> `www1`.opensu.ink
>
> <strong style='color: #92D400'>Lab26.</strong> [Cert-manager](#Lab26)

1. 创建机密

```bash
$ kubectl -n cert-manager create \
    secret tls ca-key-pair \
    --cert=ca.pem \
    --key=ca-key.pem

$ kubectl -n cert-manager get secrets
NAME         TYPE               DATA   AGE
ca-key-pair  kubernetes.io/tls  2      2m10s
...输出省略...
```

2. 创建发行者

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF

```

```bash
$ kubectl get clusterissuers
NAME                READY   AGE
`ca-issuer`        `True`   6s
```

3. 创建证书

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www1-com-tls
spec:
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  dnsNames:
    - www1.opensu.ink
# 默认不存在，成功后生成
  secretName: www1-com-tls
EOF

```

```bash
$ kubectl get certificate
NAME           READY   SECRET         AGE
...输出省略...
www1-com-tls  `True`   www1-com-tls   7s

$ kubectl get secrets
NAME          TYPE               DATA   AGE
...输出省略...
www1-com-tls  kubernetes.io/tls  3      2m22s
```

5. 创建 ingress

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: www1-com
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - www1.opensu.ink
    secretName: www1-com-tls
  rules:
  - host: www1.opensu.ink
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pod1
            port:
              number: 80
EOF

```

6. 测试

```bash
$ sudo tee -a /etc/hosts >/dev/null <<EOF
192.168.147.129 www1.opensu.ink
EOF

$ curl -kv https://www1.opensu.ink
...输出省略...
* Server certificate:
*  subject: [NONE]
...输出省略...
*  issuer: C=CN; ST=BEIJING; L=Bei Jing; CN=opensu.ink
...输出省略...
```



### <strong style='color: #92D400'>Lab28.</strong> Cloudflare :heavy_plus_sign: secret = 生成token

> 花点儿钱（最少1元），申请一个域名
>
> https://www.aliyun.com/

1. Cloudflare [<kbd>注册</kbd>](https://dash.cloudflare.com/login)

2. 保护您的 Internet 资产 <kbd>开始使用</kbd>

3. 输入您的站点 (example.com): ==opensu.ink== <kbd>添加站点</kbd>

4. 选择计划-选择您的计划 / ==Free 0 美元== / <kbd>继续</kbd>

7. 选择计划-查看DNS记录 / <kbd>继续</kbd>

8. 选择计划-更改您的名称服务器
8. [阿里云](https://www.aliyun.com/) / 控制台 / 域名 / 域名列表 / 鼠标单击<a>opensu.ink</a>

10. 按上图要求<a>修改DNS</a>

11. <a>修改DNS服务</a>
12. 参照步骤8的值修改

13. 返回Cloudflare, <kbd>完成，检查名称服务器</kbd>

14. 检查邮箱

15. 返回Cloudflare网站，单击域名<a>opensu.ink</a>

16. <a>获取您的 API 令牌</a>

17. <kbd>创建令牌</kbd>

18. <kbd>开始使用</kbd>

19. [创建自定义令牌](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)

    > 令牌名称 ==cks==
    >
    > 权限
    >
    > - ==区域== ==DNS== ==编辑==
    >
    >   添加更多
    >
    > - ==区域== ==区域== ==读取==
    >
    > <kbd>继续以显示摘要</kbd>

20.  <kbd>创建令牌</kbd>

21. 按提示，==测试此令牌==
22. 返回结果 ，=="success":true==,=="errors":[]==

```bash
$ curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer zous9eZwjlE97xK1e9Q8r-z02WDB3VAMEkfMnWoP" \
     -H "Content-Type:application/json"
{"result":{"id":"fe694804fd6bb7791c415f49ed7a789d","status":"active"},"success":true,"errors":[],"messages":[{"code":10000,"message":"This API Token is valid and active","type":null}]}

$ sudo apt -y install jq
$ curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer zous9eZwjlE97xK1e9Q8r-z02WDB3VAMEkfMnWoP" \
     -H "Content-Type:application/json" | jq
{
  "result": {
    "id": "98cc69714156c39e374acaf350139087",
    "status": "active"
  },
  "success": `true`,
  "errors": [],
  "messages": [
    {
      "code": 10000,
      "message": "This API Token is valid and active",
      "type": null
    }
  ]
}
```

23. [生成机密](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/#api-tokens)

```bash
$ kubectl -n cert-manager \
    create secret generic cloudflare-api-token-secret \
  --from-literal=api-token=zous9eZwjlE97xK1e9Q8r-z02WDB3VAMEkfMnWoP

```



### <strong style='color: #92D400'>Lab29.</strong> cert-manager :one: Manual

> `www2.opensu.ink`

1. 创建 ClusterIssuer

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
#kind: Issuer
kind: ClusterIssuer
metadata:
# name: example-issuer
  name: letsencrypt-dns01
spec:
  acme:
#   ...
# 增加 3 行
    privateKeySecretRef:
      name: letsencrypt-dns01
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - dns01:
        cloudflare:
#         email: my-cloudflare-acc@example.com
          email: adder99@163.com
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
EOF

```

```bash
$ kubectl get clusterissuers
NAME                  READY   AGE
`letsencrypt-dns01`  `True`   7s
```

2. [Creating Certificate Resources](https://cert-manager.io/docs/usage/certificate/#creating-certificate-resources)

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www2-xyz-tls
spec:
# CA 发行者
  issuerRef:
    name: letsencrypt-dns01
    kind: ClusterIssuer
# 申请证书的域名
  dnsNames:
    - www2.opensu.ink
# 成功后，会生成机密文件
  secretName: www2-xyz-tls
EOF

```

```bash
$ kubectl get certificate
NAME          READY   SECRET             AGE
www2-xyz-tls  `False`  www2-xyz-tls       3s
```

```bash
$ kubectl get certificaterequests
NAME                APPROVED   DENIED   READY   ISSUER              REQUESTOR                                         AGE
www2-xyz-tls-fjv54  `True`               False   letsencrypt-dns01   system:serviceaccount:cert-manager:cert-manager   26s
```

```bash
$ kubectl get orders
NAME                            STATE     AGE
www2-xyz-tls-fjv54-2574072105  `pending`  55s
```

```bash
$ kubectl get challenges
NAME                                       STATE     DOMAIN          AGE
www2-xyz-tls-fjv54-2574072105-1778439215  `pending`  www2.opensu.ink   70s
```

```bash
$ kubectl describe challenges www2-xyz-tls-fjv54-2574072105-1778439215
```

```bash
$ kubectl get certificate
NAME          READY   SECRET             AGE
www2-xyz-tls  `True`  www2-xyz-tls       80s
```

```bash
$ kubectl get secret
NAME                     TYPE    						DATA   AGE
...输出省略...
www2-xyz-tls       kubernetes.io/tls  1      82s
```

3. 创建 ingress

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: www2-xyz
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - www2.opensu.ink
    secretName: www2-xyz-tls
  rules:
  - host: www2.opensu.ink
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pod1
            port:
              number: 80
EOF

```

```bash
$ kubectl get ingress
NAME      CLASS   HOSTS           ADDRESS   PORTS     AGE
...输出省略...
www2-xyz  nginx   www2.opensu.ink             80, 443   13m
```

4. 确认

```bash
$ sudo tee -a /etc/hosts <<EOF
192.168.147.129 www2.opensu.ink
EOF

$ curl -v https://www2.opensu.ink
...输出省略...
* Server certificate:
*  subject: CN=www2.opensu.ink
...输出省略...
*  issuer: C=US; O=Let's Encrypt; CN=R3
*  SSL certificate verify ok.
...输出省略...

公共证书，不需要k选项
$ curl -s https://www2.opensu.ink | grep Welcome
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```



### <strong style='color: #92D400'>Lab30.</strong> cert-manager :two: Auto

> `www3.opensu.ink`

[kiosk@k8s-master] $

```yaml
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: www3-xyz
# 增加 2 行
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-dns01"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - www3.opensu.ink
    secretName: www3-xyz-tls
  rules:
  - host: www3.opensu.ink
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pod1
            port:
              number: 80
EOF

```

```bash
$ kubectl get ingress
NAME          CLASS    HOSTS           ADDRESS   PORTS     AGE
...输出省略...
www3-xyz      <none>   www3.opensu.ink             80, 443   7s

$ kubectl get certificate
NAME           READY   SECRET         AGE
...输出省略...
www3-xyz-tls  `True`   www3-xyz-tls   119s

$ kubectl get secret
NAME                  TYPE                                  DATA   AGE
...输出省略...
www3-xyz-tls          kubernetes.io/tls                     2      73s
```

```bash
$ sudo tee -a /etc/hosts <<EOF
192.168.147.129 www3.opensu.ink
EOF

$ curl -v https://www3.opensu.ink
...输出省略...
* Server certificate:
*  subject: CN=www3.opensu.ink
*  start date: Aug 14 02:34:07 2022 GMT
*  expire date: Nov 12 02:34:06 2022 GMT
*  subjectAltName: host "www3.opensu.ink" matched cert's "www3.opensu.ink"
*  issuer: C=US; O=Let's Encrypt; CN=R3
*  SSL certificate verify ok.
...输出省略...
```




# <strong style='color: #00B9E4'>5. 供应链安全：20%</strong>

> 5.1 最小化基本镜像大小
>
> 5.2 保护您的供应链：将允许的注册表列入白名单，对镜像进行签名和验证
>
> 5.3 使用用户工作负载的静态分析(例如 kubernetes 资源，Docker 文件)
>
> 5.4 扫描镜像，找出已知的漏洞

## 5.1 最小化基本镜像大小

> Linux 发行版本，主要差异 包管理器
>
> Slackware, redhat/centos, Debian/ubuntu

```bash
# os - apk，推荐
sudo docker pull alpine
# os - apt
sudo docker pull ubuntu
# os - yum
sudo docker pull centos
# os - yum
sudo docker pull redhat/ubi8
# client 没有包管理器
sudo docker pull busybox

$ for i in ubuntu centos redhat/ubi8 busybox alpine; do
    sudo docker images $i
  done
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
busybox      latest    beae173ccac6   7 months ago  `1.24MB`
alpine       latest    c059bfaa849c   8 months ago  `5.59MB`
ubuntu       latest    ba6acccedd29   10 months ago `72.8MB`
redhat/ubi8  latest    f754849582f5   2 weeks ago   `207MB`
centos       latest    5d0da3dc9764   11 months ago `231MB`
```

```bash
$ sudo docker pull nginx
$ sudo docker pull httpd

$ for i in nginx httpd; do
    sudo docker images $i
  done
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
nginx        latest    605c77e624dd   7 months ago  `141MB`
httpd        latest    dabbfbe0c57b   7 months ago  `144MB`
```



## 5.2 保护您的供应链

> **公共镜像仓库**
>
> - https://hub.docker.com
> - https://quay.io/search
> - https://catalog.redhat.com/
>   - 必须有帐号和密码
>
> **私有镜像仓库**
>
> - registry/测试
> - Harbor/生产中建议

> - **QA/T16**
>   	只能使用带具体标签的image，不允许使用 latest
> - **Note/Lab20**
>       只能使用指定的镜像仓库

## 5.3 Dockerfile

> - dockerfile
>   - docker build
> - cmd
>   - docker run ...
>   - docker exec ...
>   - docker commit ...

### <strong style='color: #92D400'>Lab31.</strong> [选择基础镜像](https://docs.docker.com/develop/develop-images/baseimages/)

> 建议：选择小的，建议 alpine；busybox 测试客户端

|                    NAME                     |  Size   |                        | 适合场景                 | 角色   |
| :-----------------------------------------: | :-----: | ---------------------- | ------------------------ | ------ |
| [scratch](https://hub.docker.com/_/scratch) |    0    | 空镜像                 | 不依赖任何第三方库的程序 | 程序员 |
|  [alpine](https://hub.docker.com/_/alpine)  | 5.59 MB | 空镜像 + BusyBox + apk | 安装软件                 | 运维   |
| [busybox](https://hub.docker.com/_/busybox) | 1.24MB  | 空镜像 + BusyBox       | 一些快速的实验场景       |        |

```bash
$ sudo  docker images busybox
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
busybox      latest    beae173ccac6   3 months ago  `1.24MB`

$ sudo docker images alpine
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
alpine       latest    c059bfaa849c   5 months ago  `5.59MB`

$ sudo  docker images centos
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
centos       latest    5d0da3dc9764   7 months ago  `231MB`
```

```dockerfile
cat > Dockerfile <<EOF
FROM alpine
RUN apk update
RUN apk add curl
RUN apk add net-tools
EOF
```

> image 分层， 下面的实例分了4层

```bash
$ sudo docker build -t alpine:v1 .
Step 1/4 : FROM alpine
...输出省略...
Step 2/4 : RUN apk update
...输出省略...
Step 3/4 : RUN apk add curl
...输出省略...
Step 4/4 : RUN apk add net-tools
...输出省略...
Successfully tagged alpine:v1
```

```bash
$ sudo docker images alpine
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
alpine       v1        960a632d6333   2 minutes ago  `10.5MB`
alpine       latest    c059bfaa849c   5 months ago    5.59MB

$ sudo docker history alpine:v1
IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
a988c35bf6cd   57 seconds ago       /bin/sh -c apk add net-tools                    463kB
cb89f3a191e8   About a minute ago   /bin/sh -c apk add curl                         2.12MB
d16666de6bb0   About a minute ago   /bin/sh -c apk update                           2.29MB
c059bfaa849c   8 months ago         /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      8 months ago         /bin/sh -c #(nop) ADD file:9233f6f2237d79659…   5.59MB
```



### <strong style='color: #92D400'>Lab32.</strong>  减少层数  

> 在定义 Dockerfile 的时候，每一条指令都会对应一个新的镜像层
> 通过 `docker history` 命令就可以查询出具体 Docker 镜像构建的层以及每层使用的指令
> 为了减少镜像的层数，在实际构建镜像时，通过使用 ==&&== 连接命令的执行过程，将多个命令定义到一个构建指令中执行
>
> - ==&&== 条件为真，执行。（if）
> - ==||==	条件为假，执行
> - ==;==	回车，前面的命令无论成功失败，执行
> - ==\\== 反斜杠在命令行结尾，手动换行

```dockerfile
$ cat > Dockerfile <<EOF
FROM alpine
RUN apk update && \
    apk add curl && \
    apk add net-tools
EOF

```

```bash
$ sudo docker build -t alpine:v2 .
Step 1/2 : FROM alpine
...输出省略...
Step 2/2 : RUN apk update &&     apk add curl &&     apk add net-tools
...输出省略...
Successfully tagged alpine:v2
```

```bash
$ sudo docker history alpine:v1
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
960a632d6333   7 minutes ago   /bin/sh -c apk add net-tools                    463kB
ba03037ec529   7 minutes ago   /bin/sh -c apk add curl                         2.1MB
05dbc88bd768   7 minutes ago   /bin/sh -c apk update                           2.29MB
c059bfaa849c   5 months ago    /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      5 months ago    /bin/sh -c #(nop) ADD file:9233f6f2237d79659…   5.59MB

$ sudo docker history alpine:v2
IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
4350f468d5dc   About a minute ago   /bin/sh -c apk update &&     apk add curl &&…   4.82MB
c059bfaa849c   5 months ago         /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      5 months ago         /bin/sh -c #(nop) ADD file:9233f6f2237d79659…   5.59MB

$ sudo docker images alpine
REPOSITORY   TAG       IMAGE ID       CREATED              SIZE
alpine       v2        fbeb6dcd69f2   About a minute ago   `10.4MB`
alpine       v1        a988c35bf6cd   10 minutes ago       `10.5MB`
alpine       latest    c059bfaa849c   8 months ago         `5.59MB`
```



### <strong style='color: #92D400'>Lab33.</strong>  清理无用数据  

|  ID  |     RELEASE      | COMMAND                                         |
| :--: | :--------------: | ----------------------------------------------- |
|  1   |      alpine      | apk --no-cache update<br>apk --no-cache add PKG |
|  2   | centos \| redhat | yum clean all && rm -rf /var/cache/yum/*        |
|  3   |      ubuntu      | apt clean && rm -rf /var/lib/apt/lists*         |

```dockerfile
$ cat > Dockerfile <<EOF
FROM alpine
RUN apk --no-cache update && \
    apk --no-cache add curl && \
    apk --no-cache add net-tools
EOF

```

```bash
$ sudo docker build -t alpine:v3 .
Step 1/2 : FROM alpine
...输出省略...
Step 2/2 : RUN apk --no-cache update &&     apk --no-cache add curl &&     apk --no-cache add net-tools
...输出省略...
Successfully tagged alpine:v3
```

```bash
$ sudo docker images alpine
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
alpine       v3        f91ab1d32980   9 seconds ago  `8.13MB`
alpine       v2        4350f468d5dc   21 minutes ago  10.4MB
alpine       v1        960a632d6333   28 minutes ago  10.4MB
alpine       latest    c059bfaa849c   5 months ago    5.59MB
```



### <strong style='color: #92D400'>Lab34.</strong>  [多阶段构建镜像](https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds)   

> Docker `17.05` 版本的新特性
>
> 通过将原先仅一个阶段构建的镜像，拆分成多个阶段 == FROM*n
>
> 1. 一阶段：gcc 编译安装 
> 2. 二阶段：只要生成的文件
> 3. 删除一阶段

```dockerfile
cat > Dockerfile <<EOF
FROM alpine
RUN apk --no-cache add nginx && \
    cp /etc/nginx/nginx.conf /opt && \
    apk del nginx
EOF
```

```bash
$ sudo docker build -t nginx:v1 .
```

```bash
$ sudo docker images nginx
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
nginx        v1        fdadb26ba083   24 seconds ago  `5.62MB`

$ sudo docker images alpine
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
alpine       latest    c059bfaa849c   5 months ago    `5.59MB`
```

```dockerfile
cat > Dockerfile <<EOF
FROM alpine
RUN apk --no-cache add nginx

FROM alpine
COPY --from=0 /etc/nginx/nginx.conf /opt
EOF
```

```bash
$ sudo docker build -t nginx:v2 .
```

```bash
$ sudo docker images nginx
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
nginx        v2        ed7f1088569e   11 seconds ago  `5.59MB`
nginx        v1        fdadb26ba083   5 minutes ago   `5.62MB`
```



### <strong style='color: #92D400'>Lab35.</strong> 尽量避免使用 root 登录

> root 在 pod 中，默认用户
>
> 指令 ==USER== 指定用户

```dockerfile
cat > Dockerfile <<EOF
FROM alpine
EOF
```

```bash
$ sudo docker build -t user:v1 .
```

```bash
$ sudo docker run -it --rm user:v1 id -un
`root`
```

```docker
cat > Dockerfile <<EOF
FROM alpine
USER nobody
EOF
```

```bash
$ sudo docker build -t user:v2 .
```

```bash
$ sudo docker run -it --rm user:v2 id -un
`nobody`
```



## 5.3 yaml

### <strong style='color: #92D400'>Lab36.</strong>  kubesec

> [https://kubesec.io](https://kubesec.io/)

[kiosk@k8s-master] $

```bash
KF=kubesec_linux_amd64.tar.gz
curl -# https://k8s.ruitong.cn:8080/K8s/$KF -o $KF \
&& sudo tar -xf $KF -C /usr/local/bin

```

```bash
$ kubesec -h

$ kubectl run podk --image=nginx \
  --dry-run=client \
  -o yaml > podk.yml
```

```bash
$ kubesec scan podk.yml
[
  {
    "object": "Pod/podk.default",
    "valid": true,
    "fileName": "podk.yml",
    "message": "Passed with a score of 0 points",
    "score": 0,
    "scoring": {
      `"advise"`: [
        {
          "id": "ApparmorAny",
          "selector": ".metadata .annotations .\"container.apparmor.security.beta.kubernetes.io/nginx\"",
          "reason": "Well defined AppArmor policies may provide greater protection from unknown threats. WARNING: NOT PRODUCTION READY",
          "points": 3
        },
        {
          "id": "ServiceAccountName",
          "selector": ".spec .serviceAccountName",
          "reason": "Service accounts restrict Kubernetes API access and should be configured with least privilege",
          "points": 3
        },
        {
          "id": "SeccompAny",
          "selector": ".metadata .annotations .\"container.seccomp.security.alpha.kubernetes.io/pod\"",
          "reason": "Seccomp profiles set minimum privilege and secure against unknown threats",
          "points": 1
        },
        {
          "id": "LimitsCPU",
          "selector": "containers[] .resources .limits .cpu",
          "reason": "Enforcing CPU limits prevents DOS via resource exhaustion",
          "points": 1
        },
        {
          "id": "LimitsMemory",
          "selector": "containers[] .resources .limits .memory",
          "reason": "Enforcing memory limits prevents DOS via resource exhaustion",
          "points": 1
        },
        {
          "id": "RequestsCPU",
          "selector": "containers[] .resources .requests .cpu",
          "reason": "Enforcing CPU requests aids a fair balancing of resources across the cluster",
          "points": 1
        },
        {
          "id": "RequestsMemory",
          "selector": "containers[] .resources .requests .memory",
          "reason": "Enforcing memory requests aids a fair balancing of resources across the cluster",
          "points": 1
        },
        {
          "id": "CapDropAny",
          "selector": "containers[] .securityContext .capabilities .drop",
          "reason": "Reducing kernel capabilities available to a container limits its attack surface",
          "points": 1
        },
        {
          "id": "CapDropAll",
          "selector": "containers[] .securityContext .capabilities .drop | index(\"ALL\")",
          "reason": "Drop all capabilities and add only those required to reduce syscall attack surface",
          "points": 1
        },
        {
          "id": "ReadOnlyRootFilesystem",
          "selector": "containers[] .securityContext .readOnlyRootFilesystem == true",
          "reason": "An immutable root filesystem can prevent malicious binaries being added to PATH and increase attack cost",
          "points": 1
        },
        {
          "id": "RunAsNonRoot",
          "selector": "containers[] .securityContext .runAsNonRoot == true",
          "reason": "Force the running image to run as a non-root user to ensure least privilege",
          "points": 1
        },
        {
          "id": "RunAsUser",
          "selector": "containers[] .securityContext .runAsUser -gt 10000",
          "reason": "Run as a high-UID user to avoid conflicts with the host's user table",
          "points": 1
        }
      ]
    }
  }
]
```

```bash
$ vim podk.yml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: podk
  name: podk
# "id": "ApparmorAny"
# "id": "SeccompAny"
  annotations:
    container.apparmor.security.beta.kubernetes.io/podk: localhost/K8s-apparmor-example-deny-write
    container.seccomp.security.alpha.kubernetes.io/pod: runtime/default
spec:
# "id": "ServiceAccountName"
  serviceAccountName: default
  containers:
  - image: nginx
    name: podk
# "id": "LimitsCPU"
# "id": "LimitsMemory"
# "id": "RequestsCPU"
# "id": "RequestsMemory"
    resources:
      limits:
        memory: 200Mi
        cpu: "250m"
      requests:
        memory: 100Mi
        cpu: "500m"
# "id": "CapDropAny"
# "id": "CapDropAll"
# "id": "ReadOnlyRootFilesystem"
# "id": "RunAsNonRoot"
# "id": "RunAsUser"
    securityContext:
      capabilities:
        drop:
          - all
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 65534
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

```bash
$ kubesec scan podk.yml
[
  {
    "object": "Pod/podk.default",
    "valid": true,
    "fileName": "podk.yml",
    "message": "Passed with a score of 16 points",
    "score": 16,
    "scoring": {
      `"passed"`: [
...输出省略...
```



## 5.4 trivy

> **一个**简单而全面的[漏洞](https://aquasecurity.github.io/trivy/v0.29.0/docs/vulnerability/scanning/)/[错误配置](https://aquasecurity.github.io/trivy/v0.29.0/docs/misconfiguration/scanning/)/[秘密](https://aquasecurity.github.io/trivy/v0.29.0/docs/secret/scanning/)扫描器，用于容器和其他工件。
>
> - Installation
>
>   https://aquasecurity.github.io/trivy/v0.29.0/getting-started/installation/
>
>   - 程序					https://aquasecurity.github.io/trivy/v0.29.0/
>
>
>   - 离线数据库	https://github.com/aquasecurity/trivy-db/releases/download/v1-2023020812/trivy-offline.db.tgz

```bash
# 方法A，快
TP=trivy_0.29.0_Linux-64bit.deb
curl -# https://k8s.ruitong.cn:8080/K8s/trivy/$TP -o $TP
sudo dpkg -i $TP

DP=trivy-offline.db.tgz
curl -# https://k8s.ruitong.cn:8080/K8s/trivy/$DP -o $DP
:<<EOF
trivy -h | grep cache
   --cache-dir value  cache directory (default: "/root/.cache/trivy") [$TRIVY_CACHE_DIR]
EOF
mkdir -p /root/.cache/trivy
mv trivy-offline.db.tgz /root/.cache/trivy
```

```bash
# trivy -h
USAGE:
   trivy [global options] command [command options] target
...
COMMANDS:
   `image`, i          scan an image
...
   `help`, h           Shows a list of commands or help for one command

# trivy help image
   --severity value, -s value       severities of vulnerabilities to be displayed (comma separated) (default: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL") [$TRIVY_SEVERITY]
   ...

# trivy image -s HIGH,CRITICAL alpine
...
alpine (alpine 3.15.0)
Total: 6 (HIGH: 4, CRITICAL: 2)
```

```bash
$ sudo docker pull alpine:3.16.0
# trivy image -s HIGH,CRITICAL alpine:3.16.0
...
alpine:3.16.0 (alpine 3.16.0)

Total: 0 (HIGH: `0`, CRITICAL: `0`)
```



# <strong style='color: #00B9E4'>6. 监控、日志记录和运行时安全：20%</strong>

> 6.1 在主机和容器级别执行系统调用进程和文件活动的行为分析，以检测恶意活动
>
> 6.2 检测物理基础架构，应用程序，网络，数据，用户和工作负载中的威胁
>
> 6.3 检测攻击的所有阶段，无论它发生在哪里，如何扩散
>
> 6.4 对环境中的不良行为者进行深入的分析调查和识别
>
> 6.5 确保容器在运行时不变
>
> 6.6 使用审计日志来监视访问

## 6.1 执行系统调用进程和文件活动的行为分析

## 6.1 sysdig

> Linux system exploration and troubleshooting tool with first class support for containers
>
> Linux 系统探索和故障排除工具，为容器提供一流的支持

## 6.1 falco



## 6.2 检测威胁



## 6.3 检测攻击的所有阶段



## 6.4 深入的分析调查和识别



## 6.5 确保容器在运行时不变

## Task. stateless

<div style="background: #F9DBD8; padding: 12px; margin-bottom: 24px;">
  您<b>必须</b>在以下 cluster /节点上完成此考考题：<br>
  <dl style="margin-bottom: 74px;">
    <dt style="float: left; width: 33%;"><b>Cluster</b></dt>
    <dt style="float: left; width: 33%;"><b>Master 节点</b></dt>
    <dt style="float: left; width: 33%;"><b>工作节点</b></dt>
<dt style="float: left; width: 33%;"><a>ck8s</a>
<dt style="float: left; width: 33%;"><a>ck8s-master</a></dt>
<dt style="float: left; width: 33%;"><a>ck8s-worker1</a></dt>
  </dl>
您可以使用以下命令来切换 cluster / <b>配置环境</b>：
<dt style="background: #EFEFEF; padding: 12px; line-height: 24px; margin-bottom: 6px; margin-top: 6px;" >
  [kiosk@cli]$ <a>kubectl config use-context ck8s</a>
  </dt>
</div>


**Context**

最佳实践是将容器设计为无状态和不可变的。

**Task**

检查在 namespace <a>development</a> 中运行的 Pod，并删除任何**非无状态**或**非不可变**的 Pod。

使用以下对无状态和不可变的严格解释：

- 能够在容器内存储数据的Pod必须被视为非无状态的。

  <div style="background: #CFE2F0; padding: 12px; line-height: 24px; margin-bottom: 24px; ">
  您不必担心数据是否实际上已经存储在容器中。
  </div>

- **被配置**为任何形式的特权的 Pod 必须被视为可能是**非无状态**和**无不可变的**。

<hr>
<div style='background: #113362; padding: 12px; margin-bottom: 24px; display: table; width: 100%'>
 <dt style="background: #4198C7; padding: 6px; line-height: 20px; color: #FFFFFF; weight: 40px; float: left;">Readme</dt>
 <dt style="background: #307195; padding: 6px; line-height: 20px; color: #FFFFFF; float: left;">>_Web Terminal</dt>
  <dt style="padding: 6px; line-height: 20px; color: #FFFFFF; float: right;"><b>参考答案</b></dt>
</div>
<hr>


![][cli]**[kiosk@cli]**

1. 切换 kubernetes 集群

```bash
*$ kubectl config use-context ck8s
```

2. 列出 development 命名空间中的 pod

```bash
$ kubectl -n development get pods
NAME		READY	STATUS	RESTARTS	AGE
`frontent`	1/1	Running	2 (7d15h ago)	78d
`pod1`			1/1	Running	2 (7d15h ago)	78d
`sso`				1/1	Running	2 (7d15h ago)	78d
```

3. 备份当前 pod（建议）

```bash
$ kubectl -n development get pod -o yaml > 8-bk.yml
```

4. 查找挂载了存储的容器

```bash
$ kubectl -n development \
  get pods frontent -o jsonpath={.spec.volumes} | jq
$ kubectl -n development \
  get pods pod1 -o jsonpath={.spec.volumes} | jq
$ kubectl -n development \
  get pods sso -o jsonpath={.spec.volumes} | jq
```

5. 查找以特权方式运行的容器

```bash
$ kubectl -n development get pods frontent -o yaml | grep "privi.*true"
      privileged: true
      
$ kubectl -n development get pods pod1 -o yaml | grep "privi.*: true"

$ kubectl -n development get pods sso -o yaml | grep "privi.*: true"
```

6. 删除

```bash
*$ kubectl -n development delete pod frontent
```



## 6.6 使用审计日志来监视访问





# <strong style='color: #00B9E4'>A. 附录</strong>

## A1. 认证一览

|  ID  |   TITLE    | COMMENT                                      |
| :--: | :--------: | -------------------------------------------- |
|  1   |  考试模式  | `线上考试`                                   |
|  2   |  考试时间  | `2小时`                                      |
|  3   | 认证有效期 | ==2年==                                      |
|  4   |  软件版本  | Kubernetes ==v1.23==                         |
|  5   |   有效期   | 考试资格自考试码注册之日起 ==12 个月==内有效 |
|  6   |  重考政策  | 可接受 ==1== 次重考                          |
|  7   |  经验水平  | 中级                                         |

## A2. 领域和能力

> CKS 认证考试包括这些一般领域及其在考试中的权重：

| COURSE |            UNIT            | PERCENT |
| :----: | :------------------------: | :-----: |
|   1    |          集群安装          |   10%   |
|   2    |          集群强化          |   15%   |
|   3    |          系统强化          |   15%   |
|   4    |      微服务漏洞最小化      |   20%   |
|   5    |         供应链安全         |   20%   |
|   6    | 监控、日志记录和运行时安全 |   20%   |

## A3. vim

<kbd>w</kbd>

<kbd>b</kbd>

<kbd>Ctrl</kbd>-<kbd>D</kbd>

## A4. Chrome

- 显示==您的连接不是私密连接==时，
  直接输入`thisisunsafe`

- 插件名：[SetupVPN](https://setupvpn.com/) <img height=38 src="https://theme.zdassets.com/theme_assets/1862305/3f8e93fed69807d29e3e87c7eb8025249313c276.png">

  ![SetupVPN](https://gitee.com/suzhen99/K8s/raw/master/images/SetupVPN.jpeg)

## A5. certbot

- 手动 - 管理域名的帐号不在自己手里

```bash
# ---------------------------------
# Manual
# certbot
# ---------------------------------

# macOS
brew install certbot

SDN=k8s.ruitong.cn

sudo certbot certonly \
    -d "$SDN" \
    --manual \
    --preferred-challenges dns \
    --server https://acme-v02.api.letsencrypt.org/directory
# 回车后，查看如下输出信息
:<<EOF
Please deploy a DNS TXT record under the name:

_acme-challenge.k8s.ruitong.cn.

with the following value:

70WKdpwIzaOuVsEgHSJRzeHtsAFWizkoLLL7Xdcr6Lw
EOF
# 将上面信息给管理DNS域名的同事，帮忙添加TXT记录
# 对方填完后，我们新开个终端测试下,确认可解析
dig -t txt _acme-challenge.k8s.ruitong.cn

# 回到第一个终端回车
```

- 自动 - 管理域名的帐号不在自己手里

```bash
# ---------------------------------
# Automatic
# python + certbot-dns-cloudflare
# ---------------------------------

brew install certbot

SDN=aws.opensu.ink
EA=cloudflare_YOUR_ACCOUNT
CK=cloudflare_YOUR_TOCKEN

# 安装 pip
python3 -m pip install --upgrade pip

pip install certbot-dns-cloudflare

# ~/.secrets/certbot/cloudflare.ini
mkdir -p ~/.secrets/certbot
chmod 700 ~/.secrets
tee ~/.secrets/certbot/cloudflare.ini >/dev/null <<EOC
dns_cloudflare_email = $EA
dns_cloudflare_api_key = $CK
EOC
chmod 400 ~/.secrets/certbot/cloudflare.ini
    
sudo certbot certonly -d "$SDN" \
    --agree-tos \
    --email $EA \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --dns-cloudflare \
    --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 30
```

