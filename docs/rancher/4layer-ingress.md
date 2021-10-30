## 简要说明

按照本文档配置后，每个应用的Ingress就不需要配置配置证书，证书的更新也只需要在一处进行了。

## 步骤

* 确认环境：外部4层代理到集群

* 确认证书：有泛域名证书

* 到集群的System项目 `ingress-nginx` 命名空间下新建证书Secret，名字叫做 `ingress-default-cert`

* 修改 `nginx-ingress-controller`的yaml，添加启动参数：

  ```yaml
  - --default-ssl-certificate=ingress-nginx/ingress-default-cert
  ```

下面是一个例子：

```yaml
...
      containers:
      - args:
        - /nginx-ingress-controller
        - --configmap=$(POD_NAMESPACE)/nginx-configuration
        - --election-id=ingress-controller-leader
        - --ingress-class=nginx
        - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
        - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
        - --annotations-prefix=nginx.ingress.kubernetes.io
        - --default-ssl-certificate=ingress-nginx/ingress-default-cert
...
```

## 参考文档

* [配置 NGINX 默认证书][1]

[1]: https://docs.rancher.cn/docs/rke/config-options/add-ons/ingress-controllers/_index/#%E9%85%8D%E7%BD%AE-nginx-%E9%BB%98%E8%AE%A4%E8%AF%81%E4%B9%A6

