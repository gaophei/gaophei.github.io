在 Kubernetes 集群中，数据库一般会在应用容器集群外部单独部署，这就需要集群内服务有访问集群外部服务的需求。如果使用云服务，也可能会有连接RDS的需求，`ExternalName`类型的Service和EndPoint都可以解决这个问题。

## Endpoint 类型的服务

在Kubernetes集群中，同一个微服务的不同副本会对集群内或集群外（取决于服务对外暴露类型）暴露统一的服务名称，一个服务背后是多个 EndPoint，EndPoint解决映射到某个pod的问题，在 EndPoint 中不仅可以指定集群内pod的IP，还可以指定集群外的IP，可以利用这个特性使用集群外部的服务。

### endpoint 介绍

服务和pod不是直接连接，而是通过Endpoint资源进行连通。endpoint资源是暴露一个服务的ip地址和port的列表。

标签选择器用于构建ip和port列表，然后存储在endpoint资源中。当客户端连接到服务时，服务代理选择这些列表中的ip和port对中的一个，并将传入连接重定向到在该位置监听的服务器。

endpoint是一个单独的资源并不是服务的属性，endpoint的名称必须和服务的名称相匹配。

### endpoint 使用

![](https://secure2.wostatic.cn/static/5gGoK6vxRCqL3C2LKmFjyi/image.png?auth_key=1680663902-nZVUMsfP9QknRPkYzscUzx-0-dfdb0ad0ce454f009dc6f703e4b5a49a)

```YAML
kind: Endpoints
apiVersion: v1
metadata:
  # 此处 metadata.name 的值要和 service 中的 metadata.name 的值保持一致
  # endpoint 的名称必须和服务的名称相匹配
  name: mysql
  # 外部服务服务统一在固定的名称空间中
  namespace: external-apps
subsets:
  - addresses:
      # 外部服务 IP 地址
      # 服务将连接重定向到 endpoint 的 IP 地址
      - ip: 192.168.1.25 
    ports:
      # 外部服务端口
      # endpoint 的目标端口
      - port: 3306
---
apiVersion: v1
kind: Service
metadata:
  # 此处 metadata.name 的值要和 endpoints 中的 metadata.name 的值保持一致
  name: mysql
  # 外部服务服务统一在固定的名称空间中
  namespace: external-apps
spec:
  ports:
    - port: 3306
```



## ExternalName类型的服务

EndPoint 方式的缺点是只能指定IP，不能使用域名，比如RDS的地址，此时只能使用ExternalName来解决。



在Docker环境中，由于Docker Engine自带 DNS Server，我们使用容器名来访问其它容器，因为容器是不稳定的，当容器宕掉，再重新启动相同镜像的容器，IP地址会改变，所以我们不使用IP访问其它容器；同样的，在Kubernetes集群中，由于使用 CoreDNS，可以通过 Service 名称来访问某个服务，Service 资源对象能保证其背后的容器副本始终是最新的IP。

因此，利用这个特性，对Service名称和外部服务地址做一个映射，使之访问Service名称既是访问外部服务：

```YAML
kind: Service
apiVersion: v1
metadata:
  name: svc1-ecternal
  namespace: external-apps
spec:
  type: ExternalName
  externalName: somedomain.org # 提供方的服务完全限定域名,如 rds 域名等。
```

## 总结

本文介绍了集群内部访问外部服务的两种方法，ExternalName 类型的服务适用于外部服务使用域名的方式，缺点是不能指定端口；而EndPoint的方式适合于外部服务是IP的情况，但是可以指定端口。