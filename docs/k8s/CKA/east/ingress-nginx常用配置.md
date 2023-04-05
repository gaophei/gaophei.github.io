# ingress基本配置项

```
data:
  allow-backend-server-header: "true"
  compute-full-forwarded-for: "true"
  enable-underscores-in-headers: "true"
  generate-request-id: "true"
  ignore-invalid-headers: "true"
  keep-alive: "30"
  keep-alive-requests: "50000"
  log-format-upstream: $the_real_ip - [$the_real_ip] - $remote_user [$time_local]
    "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length
    $request_time [$proxy_upstream_name] $upstream_addr $upstream_response_length
    $upstream_response_time $upstream_status $req_id $host [$proxy_alternative_upstream_name]
  max-worker-connections: "65536"
  proxy-body-size: 100m
  proxy-connect-timeout: "5"
  proxy-next-upstream: "off"
  proxy-read-timeout: "5"
  proxy-send-timeout: "5"
  proxy_set_headers: kube-system/custom-headers
  reuse-port: "true"
  server-tokens: "false"
  ssl-redirect: "false"
  upstream-keepalive-connections: "200"
  upstream-keepalive-timeout: "900"
  use-forwarded-headers: "true"
  worker-cpu-affinity: auto
  worker-processes: auto
```

## 1. header头

### 1.1 自定义单个应用header头配置

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-dt
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header CDN-SRC-IP $http_cdn_src_ip;
```

### 1.2 通过自定义header头的方式配置websocket

```Bash
...
annotations:
  nginx.ingress.kubernetes.io/server-snippet: |
    proxy_http_version 1.1;
    proxy_seconfiguration-snippett_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
```

### 1.3 全局配置header头

创建一个configmap示例如下：

```
# cat custom-headers.yaml
apiVersion: v1
data:
   CDN-SRC-IP: "$http_cdn_src_ip"
kind: ConfigMap
metadata:
  name: custom-headers
  namespace: kube-system
```

```
kubectl apply -f custom-headers.yaml
```

在全局configmap中引入配置：

```
proxy_set_headers: kube-system/custom-headers
```

配置参考：[https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/customization/custom-headers](https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/customization/custom-headers)



## 2. 传递用户真实ip

```
compute-full-forwarded-for: "true"
forwarded-for-header: "X-Forwarded-For"
use-forwarded-headers: "true"
```

- use-forwarded-headers：将其设置为true时，nginx将X-Forwarded-*的头信息传递给后端服务
- forwarded-for-header：用来设置识别客户端来源真实ip的字段，默认是X-Forwarded-For。如果想修改为自定义的字段名，则可以在configmap的data配置块下添加：forwarded-for-header: "THE_NAME_YOU_WANT"。通常情况下，我们使用默认的字段名就满足需求，所以不用对这个字段进行额外配置。
- compute-full-forwarded-for：如果只是开启了use-forwarded-headers: "true"的话，有时还是不能获取到客户端来源的真实ip，原因是当前X-Forwarded-For变量是从remote_addr获取的值，每次取到的都是最近一层代理的ip。为了解决这个问题，就要配置compute-full-forwarded-for字段了，即在configmap的data配置块添加：compute-full-forwarded-for: "true"。其作用就是，将客户端用户访问所经过的代理ip按逗号连接的列表形式记录下来。

设置以上参数后，location配置如下： 

```YAML
...
proxy_set_header Host                   $best_http_host;

# Pass the extracted client certificate to the backend

# Allow websocket connections
proxy_set_header                        Upgrade           $http_upgrade;

proxy_set_header                        Connection        $connection_upgrade;

proxy_set_header X-Request-ID           $req_id;
proxy_set_header X-Real-IP              $remote_addr;

proxy_set_header X-Forwarded-For        $remote_addr;

proxy_set_header X-Forwarded-Host       $best_http_host;
proxy_set_header X-Forwarded-Port       $pass_port;
proxy_set_header X-Forwarded-Proto      $pass_access_scheme;
proxy_set_header X-Forwarded-Scheme     $pass_access_scheme;

proxy_set_header X-Scheme               $pass_access_scheme;

# Pass the original X-Forwarded-For
proxy_set_header X-Original-Forwarded-For $http_x_forwarded_for;

# mitigate HTTPoxy Vulnerability
# https://www.nginx.com/blog/mitigating-the-httpoxy-vulnerability-with-nginx/
proxy_set_header Proxy                  "";
...
```

参考： [https://blog.csdn.net/felix_yujing/article/details/106616962](https://blog.csdn.net/felix_yujing/article/details/106616962)



另外，需要说明的是，如果ingress启用了四层转发，可通过如下配置项实现透传： 

```YAML
use-proxy-protocol: "true"
```

## 3. 跨域配置

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-dt
  annotations:
    nginx.ingress.kubernetes.io/cors-allow-methods: "PUT, GET, POST, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers："DNT,X-CustomHeader,Keep-Alive,User- 
Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
```

## 4. 七层负载均衡算法

### 4.1 通过会话cookie进行一致性hash算法

```
ingress.kubernetes.io/affinity: "cookie"
ingress.kubernetes.io/session-cookie-name: "route"
ingress.kubernetes.io/session-cookie-hash: "sha1"
```

### 4.2 通过客户端ip进行一致性hash

```
nginx.ingress.kubernetes.io/upstream-hash-by: "${remote_addr}"
```

### 4.3 通过请求uri进行一致性hash

```
nginx.ingress.kubernetes.io/upstream-hash-by: "${request_uri}"
```

## 5. 配置超时时间

### 5.1 全局配置

```
data:
  proxy-connect-timeout: "5"
  proxy-read-timeout: "5"
  proxy-send-timeout: "5"
```

### 5.2 为单个应用配置

```
kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: ingress-example
  annotations:
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "900"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "900"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "900"
```



## 6. Rewrite



参考： [https://www.qikqiak.com/post/url-rewrite-on-ingress-nginx/](https://www.qikqiak.com/post/url-rewrite-on-ingress-nginx/)

# 附录

更多配置参考：

- [《Kubernetes Ingress Nginx常用配置参数设置》](https://blog.csdn.net/weixin_43855694/article/details/106942537)
- [《NGINX Ingress Controller官方文档》](https://kubernetes.github.io/ingress-nginx/)