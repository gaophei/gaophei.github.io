在使用`kubectl apply`或者`kubectl create`创建pod时，并不需要等待pod创建完成；如果在在一些特定的场景中需要等待pod创建结果的返回，则需要额外的操作。

`kubectl rollout status`可以获取正在创建的pod的当前状态，并阻塞，直至其创建完成： 

```Bash
#!/bin/bash
ATTEMPTS=0
ROLLOUT_STATUS_CMD="kubectl rollout status deployment/myapp -n namespace"
until $ROLLOUT_STATUS_CMD || [ $ATTEMPTS -eq 60 ]; do
  $ROLLOUT_STATUS_CMD
  ATTEMPTS=$((attempts + 1))
  sleep 10
done
```



需要说明的是，在kubernetes中，还有一个用于等待pod创建的命令`kubectl wait`：

```Bash
kubectl wait --for=condition=available --timeout=600s deployment/myapp -n namespace
```

然而该命令只能判断deployment是否available，不能用来判断rollout，即available状态的deployment，很可能老的pod还在terminating，新的pod还没创建好。