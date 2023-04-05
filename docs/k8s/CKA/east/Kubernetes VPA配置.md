VPA的全称为vertical-pod-autoscaler，即pod的垂直的自动伸缩， 相对于HPA的横向伸缩（增加或减少pod数量）， VPA通过调整现有POD的resources来达到资源扩缩的目的。

项目地址： [https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)



## 架构

![](https://secure2.wostatic.cn/static/cUnhXQEtQy5Lh79q5pUiP5/image.png?auth_key=1680618741-9spJGcBdLyaKSoZHbxLDww-0-e5b7e73220c53a7533ddad8760884aef)

Kubernetes VPA 包含以下组件：

- Recommender：用于根据监控指标结合内置机制给出资源建议值。其在启动时从History Storage获取历史数据，根据内置机制修改VPA API object资源建议值。
- Updater：用于实时更新 pod resource requests。其监听VPA API object，依据建议值动态修改 pod resource requests。
- VPA Admission Controller：用于 pod 创建时修改 pod resource requests。
- History Storage：通过Kubernetes Metrics API采集和存储监控数据。

## 流程

![](https://secure2.wostatic.cn/static/dQYp3n8zuTVhGaZQtEw1QU/image.png?auth_key=1680618742-osbu1fnN4PpRu6r9LRRMH4-0-88a398e69a1227c676ab0cf2c5e4e003)

流程说明：

1. vpa连续检查pod在运行过程所占用的资源，默认间隔为10s一次
2. 当发现pod资源占用到达设定的阈值时，vpa会尝试更改分配的内存或CPU
3. vpa尝试更新部署组中的pod的资源定义
4. pod重启，新资源将应用于创建出来的新实例

## 运行模式

vpa支持如下四种更新策略：

- Initial：仅在 Pod 创建时修改资源请求，以后都不再修改。
- Auto：默认策略，在 Pod 创建时修改资源请求，并且在 Pod 更新时也会修改。
- Recreate：类似 Auto，在 Pod 的创建和更新时都会修改资源请求，不同的是，只要Pod 中的请求值与新的推荐值不同，VPA 都会驱逐该 Pod，然后使用新的推荐值重新启一个。因此，一般不使用该策略，而是使用 Auto，除非你真的需要保证请求值是最新的推荐值。
- Off：不改变 Pod 的资源请求，不过仍然会在 VPA 中设置资源的推荐值。

## 使用注意事项

- 针对同一个部署组，不能同时启用hpa和vpa，除非hpa只监控定制化的或者外部的资源度量
- vpa更新pod的resouces时，会导致pod的重建和重启，甚至是重调度
- VPA使用admission webhook作为其准入控制器。如果集群中有其他的admission webhook，需要确保它们不会与VPA发生冲突
- VPA会处理绝大多数OOM（Out Of Memory）的事件，但不保证所有的场景下都有效。
- VPA的性能还没有在大型集群中测试过。
- VPA对Pod资源requests的修改值可能超过实际的资源上限，例如节点资源上限、空闲资源或资源配额，从而造成Pod处于Pending状态无法被调度。同时使用集群自动伸缩（ClusterAutoscaler）可以一定程度上解决这个问题。
- 多个VPA同时匹配同一个Pod会造成未定义的行为。
- **vpa目前只支持kubernetes的默认控制器，并不支持扩展控制器**

# 使用

## 部署

这里使用helm的方式部署vpa。

helm仓库配置说明： [https://artifacthub.io/packages/helm/cowboysysop/vertical-pod-autoscaler](https://artifacthub.io/packages/helm/cowboysysop/vertical-pod-autoscaler)

简单部署示例如下：

```
helm repo add vpa https://cowboysysop.github.io/charts/
helm install vpa vpa/vertical-pod-autoscaler -n kube-system 
```

> 鉴于国内的环境，建议修改chart包中默认使用的镜像仓库地址

部署完成之后的运行示例如下： 

```Bash
# kubectl get pods -n kube-system |grep vpa
vpa-vertical-pod-autoscaler-admission-controller-5bc4c7bf8s5mlt   1/1     Running            0          8d
vpa-vertical-pod-autoscaler-recommender-6fbb49cc-2rtdh            1/1     Running            0          8d
vpa-vertical-pod-autoscaler-recommender-6fbb49cc-54zd2            1/1     Running            0          6d17h
vpa-vertical-pod-autoscaler-updater-75b6df49bd-5dkmc              1/1     Running            0          41h
vpa-vertical-pod-autoscaler-updater-75b6df49bd-6j6tw              1/1     Running            0          8d
```

## 示例

1. 创建一个deployment如下：

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-basic
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```
2. 为该deployment绑定一个vpa资源如下：

```
apiVersion: "autoscaling.k8s.io/v1"
kind: VerticalPodAutoscaler
metadata:
  name: nginx-basic-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: nginx-basic
  updatePolicy:
    updateMode: "Auto"
```
3. 查看创建的vpa对象：

```
# kubectl  get vpa nginx-basic-vpa
NAME              AGE
nginx-basic-vpa   61s
```
4. 查看vpa对象的详情： 

```
# kubectl  describe vpa nginx-basic-vpa
Name:         nginx-basic-vpa
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"autoscaling.k8s.io/v1","kind":"VerticalPodAutoscaler","metadata":{"annotations":{},"name":"nginx-basic-vpa","namespace":"de...
API Version:  autoscaling.k8s.io/v1
Kind:         VerticalPodAutoscaler
Metadata:
  Creation Timestamp:  2021-06-11T07:58:57Z
  Generation:          2
  Resource Version:    402268277
  Self Link:           /apis/autoscaling.k8s.io/v1/namespaces/default/verticalpodautoscalers/nginx-basic-vpa
  UID:                 fd5fd2a3-f373-4c1d-961d-88227c00cb7d
Spec:
  Target Ref:
    API Version:  apps/v1
    Kind:         Deployment
    Name:         nginx-basic
  Update Policy:
    Update Mode:  Auto
Status:
  Conditions:
    Last Transition Time:  2021-06-11T07:59:18Z
    Status:                True
    Type:                  RecommendationProvided
  Recommendation:
    Container Recommendations:
      Container Name:  nginx
      Lower Bound:
        Cpu:     25m
        Memory:  262144k
      Target:
        Cpu:     25m
        Memory:  262144k
      Uncapped Target:
        Cpu:     25m
        Memory:  262144k
      Upper Bound:
        Cpu:     5291m
        Memory:  11339574038
Events:          <none>
```

此时，pod也会被重启并应用推荐值：

```
# kubectl get pods -w
NAME                           READY   STATUS    RESTARTS   AGE
nginx-basic-85ff79dd56-7s6ww   1/1     Running   0          5m46s
nginx-basic-85ff79dd56-99r5g   1/1     Running   0          15s
nginx-basic-85ff79dd56-7s6ww   1/1     Terminating   0          5m57s
nginx-basic-85ff79dd56-zt48j   0/1     Pending       0          0s
nginx-basic-85ff79dd56-zt48j   0/1     Pending       0          0s
nginx-basic-85ff79dd56-zt48j   0/1     ContainerCreating   0          0s
nginx-basic-85ff79dd56-7s6ww   0/1     Terminating         0          5m59s
nginx-basic-85ff79dd56-7s6ww   0/1     Terminating         0          6m
nginx-basic-85ff79dd56-7s6ww   0/1     Terminating         0          6m
nginx-basic-85ff79dd56-zt48j   1/1     Running             0          4s
```

推荐值示例如下：

```
Recommendation:
  Container Recommendations:
    Container Name:  nginx
    Lower Bound:
      Cpu:     25m
      Memory:  262144k
    Target:
      Cpu:     25m
      Memory:  262144k
    Uncapped Target:
      Cpu:     25m
      Memory:  262144k
    Upper Bound:
      Cpu:     5291m
      Memory:  11339574038
```

说明：

- Lower Bound: 推荐的最小资源
- Uncapped Target: 如果minAllowed和maxAllowed都未设置的情况下建议的目标值
- Upper Bound: 推荐的最大资源

# 为VPA配置指标采集

vpa的推荐值可以使用kube-state-metrics指标系统将其暴露出来。不过默认情况下该指标没有暴露，需要开启。关于kube-state-metrics的安装可参考： [https://github.com/kubernetes/kube-state-metrics#kubernetes-deployment](https://github.com/kubernetes/kube-state-metrics#kubernetes-deployment)

安装完成之后，需要做如下变更： 

1. 修改clusterrole kube-state-metrics，添加如下权限： 

```
- apiGroups:
  - autoscaling.k8s.io
  resources:
  - verticalpodautoscalercheckpoints
  - verticalpodautoscalers
  verbs:
  - list
  - watch
```

2. 修改kube-state-metrics的pod，在args当中添加如下参数： 

```
- --collectors=verticalpodautoscalers
```

此时，访问kube-state-metrics地址，可看如下指标： 

```
# HELP kube_verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound Minimum resources the container can use before the VerticalPodAutoscaler updater evicts it.
# TYPE kube_verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound gauge
kube_verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound{namespace="wsd",verticalpodautoscaler="wsd-dy-projects-zeus-front-2049",target_api_version="apps/v1",target_kind="Deployment",target_name="wsd-dy-projects-zeus-front-2049",container="wsd-dy-projects-zeus-front-2049-nginx",resource="cpu",unit="core"} 0.012
```

详细配置可参考这里： [https://github.com/kubernetes/kube-state-metrics/blob/master/docs/verticalpodautoscaler-metrics.md#Configuration](https://github.com/kubernetes/kube-state-metrics/blob/master/docs/verticalpodautoscaler-metrics.md#Configuration)

# 为应用自动添加vpa对象

当在集群当中大规模使用vpa时，我们需要为每一个部署组绑定一个vpa资源对象。需要在部署组被创建时自动绑定，还需要提供一个portal能通过可视化的方式发现所有pod的资源推荐，并确认是否去应用资源推荐。

> 注： 一般在生产环境中主流的伸缩方式还是hpa， vpa更多时被配置为Off的更新策略用于获取集群中资源设置不合理的部署组并报告给管理员，以辅助决策。

goldilocks就是这样一个可自动为特定命名空间的所有部署组（Deployment）绑定vpa并提供可视化portal的一个开源工具。不过其可视化页面是真的丑！

项目地址： [https://github.com/FairwindsOps/goldilocks](https://github.com/FairwindsOps/goldilocks)

helm部署： [https://artifacthub.io/packages/helm/fairwinds-stable/goldilocks](https://artifacthub.io/packages/helm/fairwinds-stable/goldilocks)

下面是简单的部署示例

```
helm repo add fairwinds-stable https://charts.fairwinds.com/stable

helm fetch fairwinds-stable/goldilocks

tar xf goldilocks-3.2.1.tgz

cd goldilocks

# 修改values.yaml如下
image:
  # image.repository -- Repository for the goldilocks image
  repository: dyhub.douyucdn.cn/library/goldilocks
  # image.tag -- The goldilocks image tag to use
  tag: v4.1.0
...
dashboard:
  ...
  service:
    # 修改dashboard的service类型，用于直接暴露访问
    type: NodePort

# 执行安装
helm install -n vpa goldilocks ./
```

为指定的命名空间下所有的deploy统一开启vpa配置： 

```Bash
kubectl label namespace dyvideo goldilocks.fairwinds.com/enabled=true
```

# 参考

- [《K8S之纵向扩缩容VPA》](https://www.lishuai.fun/2020/09/02/k8s-vpa/)
- [《Setting the right requests and limits in Kubernetes》](https://learnk8s.io/setting-cpu-memory-limits-requests)