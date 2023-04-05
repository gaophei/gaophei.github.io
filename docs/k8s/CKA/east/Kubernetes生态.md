# 日志相关

## kube-eventer

收集kubernetes事件至kafka、mysql、elasticsearch等sink

项目地址： [https://github.com/AliyunContainerService/kube-eventer](https://github.com/AliyunContainerService/kube-eventer)

参考文章： [https://yq.aliyun.com/articles/708855?spm=a2c4e.11153940.0.0.5b9448b9CjRbhw](https://yq.aliyun.com/articles/708855?spm=a2c4e.11153940.0.0.5b9448b9CjRbhw)

## log-pilot

通过在deployment中申明变量的方式定义deploy的日志路径，自动采集，可发送至kafka、elasticseach等多种后端

项目地址： [https://github.com/AliyunContainerService/log-pilot](https://github.com/AliyunContainerService/log-pilot)

# 监控

## node-problem-detector

用于监控系统内核以及docker层面的一些异常，并生成相关事件

项目地址： [https://github.com/kubernetes/node-problem-detector](https://github.com/kubernetes/node-problem-detector)

## prometheus-operator



## pixie

## kubeprober

## kubehealthy

# kubeeye

## popeye

# 弹性伸缩相关

## kubernetes-cronhpa-controller

实现kubernetes中的deploy的周期性定时伸缩

项目地址： [https://github.com/AliyunContainerService/kubernetes-cronhpa-controller](https://github.com/AliyunContainerService/kubernetes-cronhpa-controller)

参考文章： [https://yq.aliyun.com/articles/716544](https://yq.aliyun.com/articles/716544)

## prometheus-adapter

用于为kubernetes的hpa提供自定义指标，其从promtheus中获取自定义指标，经过聚合处理后返回给metrics-server

项目地址： [https://github.com/DirectXMan12/k8s-prometheus-adapter](https://github.com/DirectXMan12/k8s-prometheus-adapter)

参考部署文章： [https://www.ibm.com/support/knowledgecenter/en/SSBS6K_3.1.2/manage_cluster/hpa.htm](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_3.1.2/manage_cluster/hpa.htm)

[https://itnext.io/horizontal-pod-autoscale-with-custom-metrics-8cb13e9d475](https://itnext.io/horizontal-pod-autoscale-with-custom-metrics-8cb13e9d475)

## keda

项目地址： 

参考文档： 

# 资源相关

## openKruise

项目地址： [https://github.com/openkruise/kruise](https://github.com/openkruise/kruise)

# 网络相关

## galaxy

腾讯开源的一款支持固定Ip需求的基于cni的网络插件。

项目地址： [https://github.com/tkestack/galaxy](https://github.com/tkestack/galaxy)

## flannel

## calico

## cni-plugins

开源的cni插件库

项目地址： [https://github.com/containernetworking/plugins](https://github.com/containernetworking/plugins)

# 管理系统

## kuboard

github地址： [https://github.com/eip-work/kuboard-press](https://github.com/eip-work/kuboard-press)
官方文档地址： [https://kuboard.cn/overview/](https://kuboard.cn/overview/)

kubernetes的web端，推荐

## rainbond

## rancher 

官方文档： [https://docs.rancher.cn/rancher2x/quick-start.html#_1-入门须知](https://docs.rancher.cn/rancher2x/quick-start.html#_1-入门须知)

## openshift

## wayne

## kubeSphere

## tke

## portainer-k8s

## kubeoperator

代码地址： [https://github.com/portainer/portainer-k8s](https://github.com/portainer/portainer-k8s)

# 边缘计算

## kubeEdge

## k3s

# 深度学习

## volcano

华为开源的一款针对机器学习和离线计算相关的调度器，支持众多调度算法。

项目地址：[https://github.com/volcano-sh/volcano](https://github.com/volcano-sh/volcano)

参考文档： [https://www.cnblogs.com/huaweicloud/p/12018269.html](https://www.cnblogs.com/huaweicloud/p/12018269.html)

[https://blog.csdn.net/devcloud/article/details/98747622](https://blog.csdn.net/devcloud/article/details/98747622)

## gpu-manager

gpu-manager是腾讯tke团队开源的gpu虚拟化技术，可以将一块gpu虚拟化成100份，我们可以申请其中指定的份数。

项目地址： [https://github.com/tkestack/gpu-manager](https://github.com/tkestack/gpu-manager)

# 负载均衡

## metallb

## porterlb

# 镜像管理

## harbor

## kubeapps

kubeapps是一个kubernetes的应用商店。

项目官网： [https://kubeapps.com/](https://kubeapps.com/)

项目地址： [https://github.com/kubeapps/kubeapps](https://github.com/kubeapps/kubeapps)

# 重调度

## descheduler

# 任务

## airflow

## saturn

项目地址： [https://github.com/vipshop/saturn](https://github.com/vipshop/saturn)

# 混沌工程

## chaosblade

# 管理api

## crossplane

项目地址：

## kubevela

项目地址：

官方文档： [https://kubevela.io/zh/docs/](https://kubevela.io/zh/docs/)

相关参考文档：

- [https://www.kubernetes.org.cn/9130.html](https://www.kubernetes.org.cn/9130.html)
- [https://xie.infoq.cn/article/4c7b59a7a96ac7af67501f9db](https://xie.infoq.cn/article/4c7b59a7a96ac7af67501f9db)

## teraform

# 集群状态巡检

## popeye

项目地址： [https://github.com/derailed/popeye](https://github.com/derailed/popeye)

## pixie

官方文档： [https://docs.pixielabs.ai](https://docs.pixielabs.ai)

## kubeEye

项目地址： [https://github.com/kubesphere/kubeeye](https://github.com/kubesphere/kubeeye)

相关参考文章： [https://www.kubernetes.org.cn/8955.html](https://www.kubernetes.org.cn/8955.html)

[https://itnext.io/kubeeye-an-automatic-diagnostic-tool-that-provides-a-holistic-view-of-your-kubernetes-cluster-badcb1a3ba59](https://itnext.io/kubeeye-an-automatic-diagnostic-tool-that-provides-a-holistic-view-of-your-kubernetes-cluster-badcb1a3ba59)

# 多云管理

## karmada

项目地址：[https://github.com/karmada-io/karmada](https://github.com/karmada-io/karmada)

## liqo

项目地址： [https://github.com/liqotech/liqo](https://github.com/liqotech/liqo)

官方文档： [https://doc.liqo.io/](https://doc.liqo.io/)

# 域名解析

## External DNS

可以将kubernetes集群内部的ingress的域名以及type=loadbalancer类型的service的域名同步至外部的dns。

项目地址： [https://github.com/kubernetes-sigs/external-dns](https://github.com/kubernetes-sigs/external-dns)

# 其他

## sloop 

查询kubernetes资源历史的视图

项目地址： [https://github.com/salesforce/sloop](https://github.com/salesforce/sloop)