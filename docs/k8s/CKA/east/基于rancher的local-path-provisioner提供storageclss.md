local-path-provisioner的代码托管地址： [https://github.com/rancher/local-path-provisioner](https://github.com/rancher/local-path-provisioner)

如果使用k3s作为容器编排系统，则默认已经部署local-path-provisioner，并将其生成的storageclass设置为默认的sc。



如果想在kubernetes中使用local-path-provisoner，可使用helm charts的方式来完成相关的部署： [https://artifacthub.io/packages/helm/containeroo/local-path-provisioner](https://artifacthub.io/packages/helm/containeroo/local-path-provisioner)



local-path-provisoner会自动在宿主机创建hostPath类型的卷用作持久存储，其关键点在于，我们需要在部署local-path-provisioner时指定本地宿主机目录的path路径，参数如下： 

```Bash
nodePathMap: [{node: DEFAULT_PATH_FOR_NON_LISTED_NODES, paths: [/opt/local-path-provisioner]}]
```