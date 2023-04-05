生成一个configmap示例如下： 

```YAML
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    product: k8s-demo
  name: demo
data:
  settings.json: |
    {
      "store": {
        "type": "InMemory",
    }
```

将该configmap中的指定文件挂载至指定目录： 

```YAML
containers:
  ...
  volumeMounts:
    - name: demo-config
      mountPath: /app
volumes:
  - name: demo-config
    configMap:
      name: demo
      items:
        - key: settings.json
          path: keys
```

此时，会将settings.json文件挂载至容器的/app/keys目录下，路径为/app/keys/settings.json， 同时/app目录下的其他文件会被全覆盖。



如果想要将settings.json挂载至/app目录下，且不覆盖/app目录下的其他文件，可使用如下配置： 

```YAML
containers:
  ...
  volumeMounts:
    - name: demo-config
      mountPath: /app/settings.json
      subPath: settings.json   # 指定demo这个configmap中的settings.json这个key挂载到/app目录下，名为settings.json
volumes:
  - name: demo-config
    configMap:
      name: demo

```



参考： [https://github.com/kubernetes/kubernetes/issues/44815](https://github.com/kubernetes/kubernetes/issues/44815)