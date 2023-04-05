configmap/secret更新后大约10s后会更新到pod中, 但是pod无法感应到configmap/secret的更新， 这其实是由于configmap/secret机制的, 因为获取configmap是否更新的操作是由kubelet定时（以一定的时间间隔）同步Pod和缓存中的configmap内容的，且缓存中的configmap内容更新可能会有延迟，所以当更改了configmap的内容后，真正反映到Pod中可能要经过syncFrequency + delay这么长的时间, 因此无法做到立即重启pod, 所以把重启的操作交给操作人员来决定。



要实现cm/secret更新后自动让Pod重载配置, 一般分为以下几种方法:

- 发送信号：这个一般都需要应用程序本身支持接收信号量机制, 比如nginx就支持使用`HUP`来做热重启。因为涉及到需要修改业务代码, 一般很少会考虑使用。
- inotifywatch：可以使用脚本来watch配置文件是否存在更新，有一个基于inotifywatch的开源实现：[ configmap-auto-reload](https://github.com/William-Yeh/configmap-auto-reload)
- Sidecar：通过往pod中植入一个sidecar，挂载配置文件目录，监听配置文件的变更，触发通知；prometheus与alertmanager就是使用这种基于；开源实现： [configmap-reload](https://github.com/jimmidyson/configmap-reload)
- reloader：使用kubernetes的list/watch机制来监听指定configmap的变化来执行滚动升级操作，这种方案会重启pod。开源实现： [reloader](https://github.com/stakater/Reloader)



### reloader的使用

reloader的详细用法可以参考官方文档，这里简单作下基本的用法说明。

reloader的关键配置项就是在deploy或者sts中添加特定的annotations；annotations中填写监听的configmap的名称，如果这些configmap发生变化，则reloader控制器会通知apiserver重启这组deploy/sts所管理的pod。



一个简单的示例： 

```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-deployment
  namespace: stage
  annotations:
    configmap.reloader.stakater.com/reload: "nginx-config, demo-config"
  labels:
    app: config-demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-demo-app
  template:
    metadata:
      labels:
        app: config-demo-app
    spec:
      volumes:
        - name: configmap-volume
          configMap:
            name: nginx-config
            items:
              - key: nginx.conf
                path: nginx.conf
              - key: mime.types
                path: mime.types
              - key: conf.d__default.conf
                path: conf.d/default.conf
      containers:
      - name: config-demo-app
        image: nginx:latest 
        ports:
          - containerPort: 80
        volumeMounts:
          - mountPath: /etc/nginx/
            name: configmap-volume
            readOnly: true
        envFrom:
          - configMapRef:
              name: demo-config
```



# 附录

参考：[Kubernetes学习(configmap及secret更新后自动重启POD) | Z.S.K.'s Records (izsk.me)](https://izsk.me/2020/05/10/Kubernetes-deploy-hot-reload-when-configmap-update/)