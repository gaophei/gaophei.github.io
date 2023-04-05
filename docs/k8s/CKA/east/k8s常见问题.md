# 1. 删除pod时，卡在Terminating状态

在删除pod时出现如下异常： 

```Bash
# kubectl get pods -n wsd -o wide  |grep Terminating
wsd-live-app-mpapi-go-1100834-68759f5946-9kqvn   0/1     Terminating   3          51d     10.209.0.64    10.208.64.9    <none>           1/1
wsd-live-app-mpapi-go-1100834-68759f5946-chpj2   0/1     Terminating   6          51d     10.209.0.57    10.208.64.36   <none>           1/1
wsd-live-app-mpapi-go-1100834-68759f5946-llt95   0/1     Terminating   4          51d     10.209.0.137   10.208.64.12   <none>           1/1
wsd-live-app-mpapi-go-1100834-68759f5946-ncwqg   0/1     Terminating   3          51d     10.209.0.135   10.208.64.11   <none>           1/1
wsd-live-app-mpapi-go-1100834-68759f5946-t9b8x   0/1     Terminating   6          51d     10.209.0.91    10.208.64.41   <none>           1/1
wsd-live-app-mpapi-go-1100834-68759f5946-tgd8q   0/1     Terminating   4          51d     10.209.1.69    10.208.64.14   <none>           1/1
wsd-live-app-mpapp-go-1100901-686768f967-4qg85   0/1     Terminating   0          39d     10.209.1.7     10.208.64.36   <none>           1/1
wsd-live-app-mpapp-go-1100901-686768f967-xg7t6   0/1     Terminating   1          39d     10.209.0.145   10.208.64.9    <none>           1/1
wsd-live-app-mpapp-go-1100901-686768f967-zs4q5   0/1     Terminating   0          39d     10.209.1.72    10.208.64.12   <none>           1/1
```

查看pod所在的节点的kubelet，日志报错如下： 

```Bash
Sep 26 21:12:34 ctnr.a208-64-9.prod.tct-ap-beijing-7 kubelet[19854]: E0926 21:12:34.986721   19854 kuberuntime_manager.go:965] PodSandboxStatus of sandbox "58bea2fd6d4e275ad590182d72bc5e3de1a072f5b1adfa9fa175e39f534d2030" for pod "wsd-live-app-mpapi-go-1100834-68759f5946-9kqvn_wsd(8b70c462-841a-4c37-a282-f2b62c2665cd)" error: rpc error: code = Unknown desc = failed to get sandbox ip: check network namespace closed: remove netns: unlinkat /var/run/netns/cni-eebe28ae-943b-298f-9829-a67515c8a4a0: device or resource busy
```

这是因为卸载/run/netns目录失败。原因是因为在容器场景出现了挂载泄露。可通过调整如下参数解决该问题： 

```Bash
fs.may_detach_mounts=1
```

详解可参考这里： [https://blog.51cto.com/nosmoking/1958730](https://blog.51cto.com/nosmoking/1958730)



# 2. helm安装timeout

在使用helm安装chart包时，有时会hang住只至超时： 

```Bash
Error: failed pre-install: timed out waiting for the condition
```

这个错误提示非常不明显，需要通过如下指令查看根因： 

```Bash
kubectl get events -n namespace  # 查看chart包安装所在namespace的事件信息
```

比如，如下错误中提示image无法正常拉取： 

```Bash
LAST SEEN   TYPE      REASON              OBJECT                                                   MESSAGE
30m         Normal    Scheduled           pod/nickfury-ingress-nginx-admission-create-2r8qn        Successfully assigned ingress-nginx/nickfury-ingress-nginx-admission-create-2r8qn to 10.238.82.7
29m         Normal    Pulling             pod/nickfury-ingress-nginx-admission-create-2r8qn        Pulling image "dyhub.douyucdn.cn/library/kube-webhook-certgen:v1.1.1@sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660"
29m         Warning   Failed              pod/nickfury-ingress-nginx-admission-create-2r8qn        Failed to pull image "dyhub.douyucdn.cn/library/kube-webhook-certgen:v1.1.1@sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660": rpc error: code = NotFound desc = failed to pull and unpack image "dyhub.douyucdn.cn/library/kube-webhook-certgen@sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660": failed to resolve reference "dyhub.douyucdn.cn/library/kube-webhook-certgen@sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660": dyhub.douyucdn.cn/library/kube-webhook-certgen@sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660: not found
29m         Warning   Failed              pod/nickfury-ingress-nginx-admission-create-2r8qn        Error: ErrImagePull
15m         Normal    BackOff             pod/nickfury-ingress-nginx-admission-create-2r8qn        Back-off pulling image "dyhub.douyucdn.cn/library/kube-webhook-certgen:v1.1.1@sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660"
10m         Warning   Failed              pod/nickfury-ingress-nginx-admission-create-2r8qn        Error: ImagePullBackOff
```



# 3. 在开启了networkpolicy的网络插件中无法使用postStart



如果在开启了networkPolicy的网络中，pod启动后网络会延迟一会儿才能通信，如果此时，pod中有postStart钩子，且该钩子需要依赖网络才能执行任务的话，则该钩子无法正常执行。

具体问题可参考： [https://github.com/kubernetes/kubernetes/issues/85966](https://github.com/kubernetes/kubernetes/issues/85966)



如果使用的是阿里云terway，可通过如下方法关闭networkpolicy：

```YAML
kubectl edit cm -n kube-system cni-config  # 修改（如果有这个key）或者新增disable_network_policy: "true"
```



# 4. kubernetes service响应1s延时问题



kube-proxy使用ipvs模式负载均衡时，出现请求1s延时现象。



具体问题分析：

[ipvs 连接复用引发的系列问题 - Kubernetes 实践指南 (imroc.cc)](https://imroc.cc/kubernetes/networking/faq/ipvs-conn-reuse-mode.html)



解决办法： 

将转发模式修改为iptables



# 5. 网络故障排查

参考： [《99%的人都不知道的kubernetes网络疑难杂症排查方法》](https://juejin.cn/post/6844903912894382088#heading-6)



# 6. 删除 namespace卡在terminating状态

在删除kubernetes namespace的时候，需要先删除该ns下的所有资源后，才能正常删除ns。我们可以通过如下方式检测命名空间下的所有资源： 

```Bash
 kubectl api-resources -o name --verbs=list --namespaced | xargs -n 1 kubectl get --show-kind --ignore-not-found -n istio-system
```

找到所有未删除 的资源，将其删除后，再尝试删除namespace，如果此时namespace仍然无法删除，可以尝试强制删除： 

```Bash
kubectl delete ns test --force --grace-period=0
```

如果到此时，仍然无法删除，可以尝试使用原生接口删除： 

1. 获取命名空间的json描述

```Bash
kubectl get ns istio-system  -o json > istio-system.json

```

    istio-system.json内容如下： 

```JSON
{
    "apiVersion": "v1",
    "kind": "Namespace",
    "metadata": {
        "creationTimestamp": "2019-07-16T12:49:27Z",
        "deletionTimestamp": "2021-08-19T02:32:45Z",
        "labels": {
            "kubesphere.io/namespace": "istio-system"
        },
        "name": "istio-system",
        "resourceVersion": "1185239956",
        "selfLink": "/api/v1/namespaces/istio-system",
        "uid": "25748f37-a7c8-11e9-84c7-fa163ecb7031"
    },
    "spec": {
        "finalizers": [
            "kubernetes"
        ]
    },
    "status": {
        "conditions": [
            {
                "lastTransitionTime": "2021-08-19T02:32:50Z",
                "message": "Discovery failed for some groups, 1 failing: unable to retrieve the complete list of server APIs: tap.linkerd.io/v1alpha1: the server is currently unable to handle the request",
                "reason": "DiscoveryFailed",
                "status": "True",
                "type": "NamespaceDeletionDiscoveryFailure"
            },
            {
                "lastTransitionTime": "2021-08-19T02:32:57Z",
                "message": "All legacy kube types successfully parsed",
                "reason": "ParsedGroupVersions",
                "status": "False",
                "type": "NamespaceDeletionGroupVersionParsingFailure"
            },
            {
                "lastTransitionTime": "2021-08-19T02:32:57Z",
                "message": "All content successfully deleted",
                "reason": "ContentDeleted",
                "status": "False",
                "type": "NamespaceDeletionContentFailure"
            }
        ],
        "phase": "Terminating"
    }
}
```
2. 删除掉json中的spec字段

```JSON
    "spec": {
        "finalizers": [
            "kubernetes"
        ]
    },
```
3. 调用原生接口执行删除

    在本地通过`kubectl proxy`启动一个本地代理，然后执行如下操作删除ns: 

```Bash
 curl -k -H "Content-Type: application/json" -X PUT --data-binary @istio-system.json http://127.0.0.1:8001/api/v1/namespaces/istio-system/finalize

```

    也可以直接执行如下操作： 

```Bash
kubectl replace --raw "/api/v1/namespaces/istio-system/finalize" -f ./istio-system.json

```

一般情况下，到此时，namespace应该可以删除了。如果仍然删除不掉，则需要再次编辑命名空间的yaml：

```Bash
kubectl edit ns istio-system
```

将metadata下的finalizers字段删除： 

```YAML
metadata:
  ...
  finalizers:
  - controller.cattle.io/namespace-auth
```