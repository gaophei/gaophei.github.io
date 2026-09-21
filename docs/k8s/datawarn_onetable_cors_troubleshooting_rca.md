# `onetable.fyut.edu.cn` 调用 `datawarn.fyut.edu.cn` 跨域失败问题排查与解决记录

> 文档类型：故障排查 / RCA / 解决方案记录  
> 日期：2026-09-21  
> 影响链路：`https://onetable.fyut.edu.cn` → `https://datawarn.fyut.edu.cn` → Kubernetes Ingress → `gateway-server` → `data-portrait-server`  
> 最终结论：**Spring Cloud Gateway 未配置全局 CORS，导致浏览器预检 OPTIONS 请求在 Gateway 层被 403 拒绝。通过为 Gateway 增加 `spring.cloud.gateway.globalcors` 配置后恢复。**

---

## 1. 问题背景

系统中存在两个域名：

- 前端页面：`https://onetable.fyut.edu.cn`
- 后端 API 网关：`https://datawarn.fyut.edu.cn`

前端页面通过 Axios 调用后端接口，例如：

```text
https://datawarn.fyut.edu.cn/portrait/v1/card/list
```

由于前端页面与 API 域名不同：

```text
onetable.fyut.edu.cn
datawarn.fyut.edu.cn
```

因此该请求属于浏览器意义上的**跨域请求（Cross-Origin Request）**。

同时前端实际请求中携带了 `Authorization` 请求头，因此浏览器不会直接发送 GET，而是先发起 CORS 预检请求：

```http
OPTIONS /portrait/v1/card/list
Origin: https://onetable.fyut.edu.cn
Access-Control-Request-Method: GET
Access-Control-Request-Headers: authorization
```

只有 OPTIONS 预检通过后，浏览器才会发送真正的 GET 请求。

---

# 2. 初始故障现象

浏览器开发者工具中出现典型 CORS 错误：

```text
blocked by CORS policy:
Response to preflight request doesn't pass access control check:
No 'Access-Control-Allow-Origin' header is present
```

同时 Axios 报错：

```text
AxiosError: Network Error
```

以及浏览器网络层：

```text
net::ERR_FAILED
```

初始判断：

```text
浏览器
  |
  | OPTIONS 预检
  v
datawarn.fyut.edu.cn
  |
  X 预检失败
```

这里需要特别说明：

**微服务之间的服务端调用本身通常不存在浏览器 CORS 问题。CORS 是浏览器安全机制。**

因此最初看到的错误虽然发生在“两个微服务相关链路”中，但真正失败的是：

```text
浏览器 → API 域名
```

这一段。

---

# 3. 第一次验证：直接模拟浏览器 OPTIONS 预检

在服务器上执行：

```bash
curl -i -X OPTIONS \
  'https://datawarn.fyut.edu.cn/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET'
```

返回：

```http
HTTP/1.1 403
Server: nginx
Date: Mon, 21 Sep 2026 06:18:48 GMT
Content-Length: 0
Connection: keep-alive
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
```

之后根据浏览器实际请求补充：

```http
Access-Control-Request-Headers: authorization
```

更准确的模拟命令为：

```bash
curl -i -X OPTIONS \
  'https://datawarn.fyut.edu.cn/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

核心现象仍然是：

```text
HTTP 403
```

并且响应里没有：

```http
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
```

这说明浏览器报错并不是前端 Axios 自身问题，而是服务端预检请求被拒绝。

---

# 4. 检查最外层 Nginx

最外层 Nginx 配置中：

```nginx
location / {
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_pass http://rancherworkserver;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    if ($request_uri ~* "swagger-ui.html$") {
        return 403;
    }
}
```

可以看到 Nginx 并没有针对 OPTIONS 做限制。

唯一显式的 403 是：

```nginx
if ($request_uri ~* "swagger-ui.html$") {
    return 403;
}
```

而当前请求路径：

```text
/portrait/v1/card/list
```

显然不匹配。

因此不能直接认为 403 是最外层 Nginx 返回的。

---

# 5. 绕过最外层 Nginx，直接访问 Kubernetes Worker / Ingress

最外层 Nginx 的 upstream 为多个 Kubernetes Worker：

```text
192.168.99.23
192.168.99.24
192.168.99.25
192.168.99.26
192.168.99.27
192.168.99.28
192.168.99.29
192.168.99.30
192.168.99.31
```

直接请求 Worker：

```bash
curl -i -X OPTIONS \
  'http://192.168.99.25/portrait/v1/card/list' \
  -H 'Host: datawarn.fyut.edu.cn' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 403
Date: Mon, 21 Sep 2026 06:23:00 GMT
Content-Length: 0
Connection: keep-alive
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
```

随后遍历全部 Worker：

```bash
for ip in \
192.168.99.25 \
192.168.99.23 \
192.168.99.26 \
192.168.99.29 \
192.168.99.30 \
192.168.99.31 \
192.168.99.24 \
192.168.99.27 \
192.168.99.28
do
    echo "====== $ip ======"
    curl -s -o /dev/null -D - -X OPTIONS \
      "http://${ip}/portrait/v1/card/list" \
      -H 'Host: datawarn.fyut.edu.cn' \
      -H 'Origin: https://onetable.fyut.edu.cn' \
      -H 'Access-Control-Request-Method: GET' \
      -H 'Access-Control-Request-Headers: authorization'
done
```

所有节点全部返回：

```http
HTTP/1.1 403
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
```

### 阶段性结论

可以排除：

- `nginx01` 单机配置异常
- 某一个 Kubernetes Worker 节点异常
- 某一个节点上 Ingress 实例异常

故障是**统一配置行为**。

---

# 6. 定位 Kubernetes Ingress 与 Gateway

Ingress 信息表明：

```text
Host:
datawarn.fyut.edu.cn

Path:
/

Service:
gateway-server-svc
```

也就是说，请求链路实际是：

```text
https://datawarn.fyut.edu.cn
        |
        v
Kubernetes Ingress
        |
        v
gateway-server-svc
        |
        v
gateway-server
```

而不是直接进入 `data-portrait-server`。

---

# 7. 绕过 Ingress，直接访问 gateway-server Service

查询 Service：

```bash
kubectl -n lightapp get svc gateway-server-svc -o wide
```

结果：

```text
NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
gateway-server-svc   ClusterIP   10.43.71.184   <none>        9999/TCP
```

查询 Endpoint：

```bash
kubectl -n lightapp get endpoints gateway-server-svc -o wide
```

结果：

```text
gateway-server-svc   10.42.180.230:9999
```

直接访问 ClusterIP：

```bash
curl -i -X OPTIONS \
  'http://10.43.71.184:9999/portrait/v1/card/list' \
  -H 'Host: datawarn.fyut.edu.cn' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 403
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
Content-Length: 0
```

---

# 8. 直接访问 gateway-server Pod

Gateway Pod：

```text
10.42.180.230:9999
```

直接请求：

```bash
curl -i -X OPTIONS \
  'http://10.42.180.230:9999/portrait/v1/card/list' \
  -H 'Host: datawarn.fyut.edu.cn' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

仍返回：

```http
HTTP/1.1 403
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
Content-Length: 0
```

### 重要结论

此时已经可以排除：

- 外层 Nginx
- Kubernetes Worker
- Ingress
- `gateway-server-svc`

问题范围进一步缩小到：

```text
gateway-server 应用自身
```

---

# 9. 对 gateway-server 进行对比测试

## 9.1 不带 Origin

执行：

```bash
curl -i -X OPTIONS \
  'http://10.42.180.230:9999/portrait/v1/card/list'
```

返回：

```http
HTTP/1.1 200
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: *
Access-Control-Allow-Headers: Origin, No-Cache, X-Requested-With, If-Modified-Since, Pragma, Last-Modified, Cache-Control, Expires, Content-Type, X-E4M-With, X-FORWARD-ID-TOKEN,X-id-token, Authorization, X-FORWARD-GATEWAY,formflowUserName,timeStr,uuid,visitor,Req-Visitmode-Id
Allow: GET,HEAD
Content-Length: 0
```

## 9.2 带 Gateway 自己的 Origin

```bash
curl -i -X OPTIONS \
  'http://10.42.180.230:9999/portrait/v1/card/list' \
  -H 'Origin: https://datawarn.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 403
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
```

## 9.3 带真实前端 Origin

```bash
curl -i -X OPTIONS \
  'http://10.42.180.230:9999/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 403
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
```

### 关键现象

```text
不带 Origin → 200
带任何 Origin → 403
```

这说明：

**普通 OPTIONS 可以走通，但是“真正的浏览器 CORS 预检”被 Spring Cloud Gateway 在进入下游之前拒绝。**

---

# 10. 检查 Gateway Deployment 配置

查看 Deployment：

```bash
kubectl -n lightapp get deploy gateway-server -o yaml
```

发现：

```yaml
envFrom:
  - configMapRef:
      name: gateway-server-params-config
  - configMapRef:
      name: lightapp-poa-config
```

重要环境变量包括：

```text
AUTH_ENABLED=false
MY_DOMAIN_NAME=https://datawarn.fyut.edu.cn
DATA_PORTRAIT_HOST=http://data-portrait-server-svc.lightapp.svc.cluster.local:10084
SERVER_PORT=9999
```

这里 `AUTH_ENABLED=false` 很重要。

因为它说明当前 Gateway 的业务鉴权功能并未启用，所以：

```text
OPTIONS → 403
```

不像是 token 认证失败，更像是 CORS 拒绝。

> 注意：排障过程中曾输出过敏感凭据（如 `POA_CLIENT_SECRET`）。本文档不记录实际值，建议将该凭据视为已暴露并安排轮换。

---

# 11. 解包 gateway-server 的 app.jar

容器内：

```text
/home/java-app/lib/app.jar
```

复制出来：

```bash
kubectl -n lightapp cp \
  gateway-server-7bff8f9d88-hbgwt:/home/java-app/lib/app.jar \
  ./app.jar
```

解包：

```bash
mkdir app-unpack
cd app-unpack
unzip ../app.jar >/dev/null
```

目录：

```text
BOOT-INF
META-INF
org
```

---

# 12. 检查 Gateway 路由配置

查看：

```bash
cat BOOT-INF/classes/routes.yml
```

关键配置：

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: data-portrait
          uri: ${custom.server-host.data-portrait}
          predicates:
            - ${DATA_PORTRAIT_PREDICATES:Path=/portrait/**}
          filters:
            - ${DATA_PORTRAIT_FILTERS:StripPrefix=0}
```

其中：

```yaml
StripPrefix=0
```

说明 Gateway 转发到 `data-portrait-server` 时不会去掉 `/portrait`。

因此：

```text
Gateway 收到：
/portrait/v1/card/list

下游收到：
/portrait/v1/card/list
```

这为后续直接访问 portrait 服务提供了正确路径。

---

# 13. 直接访问 data-portrait-server，验证下游 CORS

查询 Service：

```text
data-portrait-server-svc
ClusterIP: 10.43.65.208
Port: 10084
```

查询 Pod：

```text
data-portrait-server-744695748c-8bhzc
Pod IP: 10.42.38.107
Port: 10084
```

---

## 13.1 portrait Service：不带 Origin

```bash
curl -i -X OPTIONS \
  'http://10.43.65.208:10084/portrait/v1/card/list'
```

返回：

```http
HTTP/1.1 200
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: *
Access-Control-Allow-Headers: ...
```

---

## 13.2 portrait Service：带 onetable Origin

```bash
curl -i -X OPTIONS \
  'http://10.43.65.208:10084/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 200
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: *
Access-Control-Allow-Headers: ...
Allow: GET, HEAD, POST, PUT, DELETE, TRACE, OPTIONS, PATCH
```

---

## 13.3 portrait Service：带 datawarn Origin

```bash
curl -i -X OPTIONS \
  'http://10.43.65.208:10084/portrait/v1/card/list' \
  -H 'Origin: https://datawarn.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 200
Access-Control-Allow-Origin: https://datawarn.fyut.edu.cn
```

---

## 13.4 直接访问 portrait Pod

```bash
curl -i -X OPTIONS \
  'http://10.42.38.107:10084/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

同样返回：

```http
HTTP/1.1 200
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
```

---

# 14. 至此完成故障责任边界定位

对比：

```text
gateway-server:
Origin=https://onetable.fyut.edu.cn
→ 403

data-portrait-server:
Origin=https://onetable.fyut.edu.cn
→ 200
```

因此可以明确：

```text
data-portrait-server CORS 正常
gateway-server CORS 异常
```

问题不是：

- portrait 服务
- Service
- Ingress
- Nginx
- Kubernetes 节点

而是：

```text
Spring Cloud Gateway 层
```

---

# 15. 为什么 Gateway 不带 Origin 时会出现下游 CORS Header

这一点排查过程中容易造成误判。

不带 Origin 的请求：

```http
OPTIONS /portrait/v1/card/list
```

并不是真正的 CORS preflight。

因此 Gateway 不会进行跨域校验，而是把 OPTIONS 当普通请求继续转发：

```text
Gateway
  |
  v
data-portrait-server
```

portrait 服务会返回：

```http
Access-Control-Allow-Methods: *
Access-Control-Allow-Headers: ...
```

所以最初在 Gateway 返回中看到这些 Header 时，容易误以为：

```text
“Gateway 自己已经配置了 CORS”
```

实际上这些 Header 是由下游 portrait 返回后透传出来的。

而真正的浏览器预检包含：

```http
Origin: ...
Access-Control-Request-Method: ...
```

此时 Spring Cloud Gateway 会先进行 CORS 校验，在没有匹配 CorsConfiguration 的情况下直接：

```text
403
```

请求根本到不了下游。

---

# 16. 检查 Gateway Spring 配置

查看：

```bash
cat BOOT-INF/classes/application.yml
```

内容中：

```yaml
spring:
  cloud:
    gateway:
      enabled: true
```

但是没有：

```yaml
spring:
  cloud:
    gateway:
      globalcors:
```

查看：

```bash
cat BOOT-INF/classes/custom.yml
```

同样没有 CORS 配置。

---

# 17. 检查外部配置

容器目录：

```text
/home/java-app/etc
```

为空。

搜索：

```bash
grep -RniE \
'cors|origin|globalcors|allowedOrigins|allowed-origins' \
/home/java-app/etc 2>/dev/null
```

无结果。

Java 启动命令：

```bash
tr '\0' ' ' < /proc/1/cmdline
```

结果核心部分：

```text
java ... -jar /home/java-app/lib/app.jar
```

没有：

```text
--spring.config.location=
--spring.config.additional-location=
-Dspring.config.location=
```

因此当前 Gateway 没有额外外部 Spring 配置覆盖。

---

# 18. 最终根因

## 根因描述

`gateway-server` 使用：

```text
Spring Cloud Gateway 3.1.9
```

但应用配置中仅启用了：

```yaml
spring:
  cloud:
    gateway:
      enabled: true
```

没有配置：

```yaml
spring.cloud.gateway.globalcors
```

因此真实浏览器 CORS 预检：

```http
OPTIONS /portrait/v1/card/list
Origin: https://onetable.fyut.edu.cn
Access-Control-Request-Method: GET
Access-Control-Request-Headers: authorization
```

在 Gateway 的 CORS/HandlerMapping 阶段被拒绝。

请求链路为：

```text
onetable.fyut.edu.cn
        |
        | OPTIONS + Origin
        v
nginx
        |
        v
Ingress
        |
        v
gateway-server
        |
        X 403
        |
        v
data-portrait-server
```

实际上 `data-portrait-server` 根本没有收到这次预检。

---

# 19. 临时修复方案：SPRING_APPLICATION_JSON

为了不重新构建镜像，使用 Spring Boot 原生支持的：

```text
SPRING_APPLICATION_JSON
```

动态注入完整 Gateway CORS 配置。

执行：

```bash
CORS_JSON='{
  "spring": {
    "cloud": {
      "gateway": {
        "globalcors": {
          "add-to-simple-url-handler-mapping": true,
          "cors-configurations": {
            "[/**]": {
              "allowedOrigins": [
                "https://onetable.fyut.edu.cn"
              ],
              "allowedMethods": [
                "GET",
                "POST",
                "PUT",
                "DELETE",
                "PATCH",
                "OPTIONS"
              ],
              "allowedHeaders": [
                "*"
              ],
              "allowCredentials": true,
              "maxAge": 3600
            }
          }
        },
        "default-filters": [
          "DedupeResponseHeader=Access-Control-Allow-Credentials Access-Control-Allow-Origin"
        ]
      }
    }
  }
}'
```

注入 Deployment：

```bash
kubectl -n lightapp set env deployment/gateway-server \
  SPRING_APPLICATION_JSON="$CORS_JSON"
```

等待滚动更新：

```bash
kubectl -n lightapp rollout status deployment/gateway-server
```

确认新 Pod：

```bash
kubectl -n lightapp get pods -l app=gateway-server -o wide
```

新 Pod：

```text
gateway-server-66cb5ddc77-z4ql6
IP: 10.42.180.236
```

确认变量：

```bash
kubectl -n lightapp exec deploy/gateway-server -- \
  printenv SPRING_APPLICATION_JSON
```

---

# 20. 为什么增加 `DedupeResponseHeader`

下游 `data-portrait-server` 本身已经会返回：

```http
Access-Control-Allow-Origin
Access-Control-Allow-Credentials
```

Gateway 增加 CORS 后，也可能产生同名响应头。

如果最终响应中出现：

```http
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
```

浏览器可能认为该 Header 有多个值并继续报跨域错误。

因此在 Gateway 增加：

```text
DedupeResponseHeader=Access-Control-Allow-Credentials Access-Control-Allow-Origin
```

用于去重。

---

# 21. 修复后的验证

## 21.1 Gateway Service 正向验证

```bash
curl -i -X OPTIONS \
  'http://10.43.71.184:9999/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

修复后：

```http
HTTP/1.1 200
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
Access-Control-Allow-Methods: GET,POST,PUT,DELETE,PATCH,OPTIONS
Access-Control-Allow-Headers: authorization
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 3600
Content-Length: 0
```

说明 Gateway CORS 已生效。

---

## 21.2 最终公网域名验证

```bash
curl -i -X OPTIONS \
  'https://datawarn.fyut.edu.cn/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 200
Server: nginx
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
Access-Control-Allow-Methods: GET,POST,PUT,DELETE,PATCH,OPTIONS
Access-Control-Allow-Headers: authorization
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 3600
```

说明完整链路：

```text
Browser → Nginx → Ingress → Gateway
```

已经可以正确处理预检。

---

## 21.3 非法 Origin 负向验证

执行：

```bash
curl -i -X OPTIONS \
  'http://10.43.71.184:9999/portrait/v1/card/list' \
  -H 'Origin: https://example.com' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

返回：

```http
HTTP/1.1 403
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
```

说明白名单规则正常：

```text
https://onetable.fyut.edu.cn → 允许
https://example.com          → 拒绝
```

不是简单粗暴地允许所有来源。

---

# 22. 修复后的真实 GET 验证

执行：

```bash
curl -i \
  'https://datawarn.fyut.edu.cn/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn'
```

返回：

```http
HTTP/1.1 200
Content-Type: application/json;charset=UTF-8
Access-Control-Allow-Origin: https://onetable.fyut.edu.cn
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: *
Access-Control-Allow-Headers: ...
```

业务响应：

```json
{
  "flag": false,
  "msg": "token过期,请重新登陆",
  "status": 10005
}
```

这个结果非常重要。

它说明：

```text
CORS 已经通过
Gateway 已经正常转发
portrait 服务已经收到 GET
当前剩余问题是业务 token 过期
```

因此：

```text
“token过期”
```

和之前的 CORS 403 是两个不同层次的问题。

---

# 23. 浏览器侧预期变化

故障前：

```text
OPTIONS 403
  ↓
浏览器阻止真正 GET
  ↓
Axios Network Error
  ↓
net::ERR_FAILED
```

修复后：

```text
OPTIONS 200
  ↓
浏览器允许请求
  ↓
GET 发出
  ↓
Gateway 转发
  ↓
portrait 返回业务数据/业务错误
```

如果登录 token 已过期，则前端应该表现为：

```text
接口正常返回 token 过期业务码
```

而不是：

```text
Network Error / CORS Error
```

---

# 24. 推荐的正式持久化方案

当前使用：

```text
kubectl set env deployment/gateway-server SPRING_APPLICATION_JSON=...
```

属于快速修复方式。

该 Deployment 存在 Rancher / Helm 管理痕迹，因此未来：

- Helm upgrade
- Rancher 修改工作负载
- 重新部署 Deployment
- 应用重新发布

都有可能覆盖手工注入的环境变量。

因此建议将配置正式持久化。

---

## 24.1 方案一：直接写入 application.yml

推荐：

```yaml
spring:
  cloud:
    gateway:
      enabled: true

      globalcors:
        add-to-simple-url-handler-mapping: true
        cors-configurations:
          '[/**]':
            allowedOrigins:
              - "https://onetable.fyut.edu.cn"
            allowedMethods:
              - GET
              - POST
              - PUT
              - DELETE
              - PATCH
              - OPTIONS
            allowedHeaders:
              - "*"
            allowCredentials: true
            maxAge: 3600

      default-filters:
        - DedupeResponseHeader=Access-Control-Allow-Credentials Access-Control-Allow-Origin
```

重新构建并发布 Gateway 镜像。

---

# 25. 推荐：通过环境变量维护域名白名单

为了避免以后每增加一个前端域名都重新改 YAML，可以把白名单抽象成环境变量。

## 25.1 application.yml 修改为

```yaml
spring:
  cloud:
    gateway:
      globalcors:
        add-to-simple-url-handler-mapping: true
        cors-configurations:
          '[/**]':
            allowedOrigins: ${CORS_ALLOWED_ORIGINS:https://onetable.fyut.edu.cn}
            allowedMethods:
              - GET
              - POST
              - PUT
              - DELETE
              - PATCH
              - OPTIONS
            allowedHeaders:
              - "*"
            allowCredentials: true
            maxAge: 3600

      default-filters:
        - DedupeResponseHeader=Access-Control-Allow-Credentials Access-Control-Allow-Origin
```

环境变量：

```text
CORS_ALLOWED_ORIGINS=https://onetable.fyut.edu.cn,https://portal.fyut.edu.cn
```

然后 Kubernetes 中可以配置：

```yaml
env:
  - name: CORS_ALLOWED_ORIGINS
    value: "https://onetable.fyut.edu.cn,https://portal.fyut.edu.cn"
```

也可以：

```bash
kubectl -n lightapp set env deployment/gateway-server \
  CORS_ALLOWED_ORIGINS='https://onetable.fyut.edu.cn,https://portal.fyut.edu.cn'
```

> 建议在当前 Spring Boot / Spring Cloud Gateway 版本上先验证逗号分隔列表绑定是否符合预期，再正式上线。

---

# 26. 更适合运维的 ConfigMap 方式

当前 Gateway 本身已经通过：

```yaml
envFrom:
  - configMapRef:
      name: gateway-server-params-config
```

加载环境变量。

因此可以在：

```text
gateway-server-params-config
```

中增加：

```yaml
data:
  CORS_ALLOWED_ORIGINS: "https://onetable.fyut.edu.cn,https://portal.fyut.edu.cn"
```

优点：

- 运维只修改 ConfigMap
- 不需要修改 Deployment YAML
- 不需要维护复杂 JSON
- 域名白名单更直观
- 更适合 Helm / Rancher 管理

修改 ConfigMap 后，需要确保 Pod 重建或滚动重启：

```bash
kubectl -n lightapp rollout restart deployment/gateway-server
kubectl -n lightapp rollout status deployment/gateway-server
```

---

# 27. 为什么不建议配置 `allowedOrigins: "*"`

当前配置：

```yaml
allowCredentials: true
```

如果使用：

```yaml
allowedOrigins:
  - "*"
```

容易与带凭据请求产生安全或框架兼容问题。

生产环境建议明确列出允许来源：

```yaml
allowedOrigins:
  - "https://onetable.fyut.edu.cn"
```

如果有多个：

```yaml
allowedOrigins:
  - "https://onetable.fyut.edu.cn"
  - "https://portal.fyut.edu.cn"
```

这样既可控，也更符合最小权限原则。

---

# 28. 为什么 `Authorization` 会触发预检

浏览器的简单跨域请求必须满足一组限制。

而：

```http
Authorization: ...
```

并不是 CORS safelisted request header。

因此一旦请求携带：

```http
Authorization
```

浏览器通常会先发：

```http
OPTIONS
```

其中：

```http
Access-Control-Request-Headers: authorization
```

Gateway 必须在预检响应中允许：

```http
Access-Control-Allow-Headers: authorization
```

否则浏览器不会继续发送真实 GET。

---

# 29. 为什么 `add-to-simple-url-handler-mapping: true` 很重要

Spring Cloud Gateway 中，预检 OPTIONS 有时无法像普通业务 GET 一样匹配正常 Route。

配置：

```yaml
add-to-simple-url-handler-mapping: true
```

可以让全局 CORS 配置也应用到 SimpleUrlHandlerMapping。

对于：

```text
OPTIONS + Origin + Access-Control-Request-Method
```

这种预检请求尤其重要。

---

# 30. 故障链路图

## 故障前

```text
┌──────────────────────────────┐
│ https://onetable.fyut.edu.cn │
└──────────────┬───────────────┘
               │
               │ OPTIONS
               │ Origin: https://onetable.fyut.edu.cn
               │ Access-Control-Request-Method: GET
               │ Access-Control-Request-Headers: authorization
               ▼
┌──────────────────────────────┐
│ datawarn.fyut.edu.cn / Nginx │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Kubernetes Ingress           │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ gateway-server               │
│ Spring Cloud Gateway 3.1.9   │
│                              │
│ 未配置 globalcors            │
└──────────────┬───────────────┘
               │
               X 403
               │
               ▼
       data-portrait-server
       （预检未到达）
```

---

## 修复后

```text
┌──────────────────────────────┐
│ https://onetable.fyut.edu.cn │
└──────────────┬───────────────┘
               │
               │ OPTIONS
               ▼
┌──────────────────────────────┐
│ Gateway globalcors           │
│                              │
│ allowedOrigins:              │
│ onetable.fyut.edu.cn         │
└──────────────┬───────────────┘
               │
               │ 200
               │ Access-Control-Allow-Origin
               ▼
       浏览器预检成功
               │
               │ GET + Authorization
               ▼
┌──────────────────────────────┐
│ gateway-server               │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ data-portrait-server         │
└──────────────┬───────────────┘
               │
               ▼
           业务响应
```

---

# 31. 排障过程中各层结论汇总

| 层级 | 验证方式 | 结果 | 结论 |
|---|---|---|---|
| 浏览器 | DevTools Network | OPTIONS 失败，CORS 报错 | 确认是预检失败 |
| 外层 Nginx | 查看 nginx.conf | 未限制 OPTIONS | 非主要嫌疑 |
| Worker / Ingress | 直接访问 `192.168.99.x` | 全部 403 | 排除 nginx01 |
| Gateway Service | `10.43.71.184:9999` | 带 Origin 403 | 问题进入 Gateway |
| Gateway Pod | `10.42.180.230:9999` | 带 Origin 403 | 锁定 Gateway 应用 |
| Gateway 无 Origin | OPTIONS | 200 | 普通 OPTIONS 可透传 |
| portrait Service | `10.43.65.208:10084` | 带 Origin 200 | 下游 CORS 正常 |
| portrait Pod | `10.42.38.107:10084` | 带 Origin 200 | 服务自身正常 |
| Gateway application.yml | 静态配置 | 无 globalcors | 找到配置缺失 |
| Gateway 外部配置 | `/home/java-app/etc` | 空 | 无外部补充 |
| 修复后 Gateway | OPTIONS | 200 | 修复成功 |
| 非法 Origin | `example.com` | 403 | 白名单生效 |
| 修复后真实 GET | GET | HTTP 200 + token 过期业务码 | CORS 已恢复 |

---

# 32. 一套可复用的 CORS 排障方法

以后遇到类似问题，可以按照以下顺序排查。

## 第一步：确认是不是预检

浏览器 Network 中查：

```text
OPTIONS
```

观察：

- Status Code
- Origin
- Access-Control-Request-Method
- Access-Control-Request-Headers
- Access-Control-Allow-Origin
- Access-Control-Allow-Headers

---

## 第二步：用 curl 精确复现浏览器

```bash
curl -i -X OPTIONS \
  'https://API域名/接口路径' \
  -H 'Origin: https://前端域名' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

常见状态码：

```text
200 / 204 → 继续检查 CORS Header
401 / 403 → 鉴权或 CORS 拒绝
404       → 路由不匹配
301 / 302 → 重定向问题
5xx       → 网关或后端异常
```

---

## 第三步：逐层绕过

推荐顺序：

```text
公网域名
↓
外层 Nginx
↓
Ingress Node
↓
Service ClusterIP
↓
Pod IP
↓
下游 Service
↓
下游 Pod
```

每绕过一层，都用完全相同的：

```http
Origin
Access-Control-Request-Method
Access-Control-Request-Headers
```

保证测试可比。

---

## 第四步：找到“第一次从正常变异常”的位置

例如本次：

```text
portrait Pod      = 200
gateway Pod       = 403
```

故障边界就非常明确：

```text
Gateway
```

---

# 33. 本次排障中值得保留的经验

## 33.1 不能看到 `Server: nginx` 就认定是 Nginx 拒绝

上游服务的 403 完全可以被 Nginx 透传。

因此必须通过：

```text
绕过 Nginx
```

验证。

---

## 33.2 不能只测普通 OPTIONS

普通：

```bash
curl -X OPTIONS URL
```

并不等于浏览器预检。

必须至少带：

```http
Origin
Access-Control-Request-Method
```

如果浏览器还要求自定义 Header，则再带：

```http
Access-Control-Request-Headers
```

本次就是：

```http
Access-Control-Request-Headers: authorization
```

---

## 33.3 看到 Access-Control-Allow-* Header 不代表当前层配置了 CORS

因为响应可能来自下游服务。

本次 Gateway 不带 Origin 时的 CORS Header，实际上来自 portrait 服务透传。

所以需要：

```text
Service/Pod 分层验证
```

才能知道 Header 是谁加的。

---

## 33.4 微服务自身 CORS 正常，不代表 Gateway CORS 正常

本次 portrait：

```text
200
```

Gateway：

```text
403
```

统一 API Gateway 在浏览器跨域链路中属于独立的 CORS 边界。

---

## 33.5 CORS 问题与业务认证问题要分开

修复前：

```text
CORS 403
浏览器连 GET 都没有发送
```

修复后：

```text
GET 已到业务服务
返回 token 过期
```

第二个问题不能再归因于跨域。

---

# 34. 回滚临时环境变量的方法

如果需要撤销本次临时配置：

```bash
kubectl -n lightapp set env deployment/gateway-server \
  SPRING_APPLICATION_JSON-
```

然后：

```bash
kubectl -n lightapp rollout status deployment/gateway-server
```

注意：

**回滚后原 CORS 403 问题会重新出现。**

因此只有在正式配置已经通过 Helm / application.yml / ConfigMap 落地后，才应该删除临时配置。

---

# 35. 上线后的建议验证清单

正式持久化后建议执行：

```bash
curl -i -X OPTIONS \
  'https://datawarn.fyut.edu.cn/portrait/v1/card/list' \
  -H 'Origin: https://onetable.fyut.edu.cn' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

必须满足：

```text
HTTP 200/204
Access-Control-Allow-Origin 正确
Access-Control-Allow-Headers 包含 authorization
Access-Control-Allow-Credentials 正确
```

再测试非法来源：

```bash
curl -i -X OPTIONS \
  'https://datawarn.fyut.edu.cn/portrait/v1/card/list' \
  -H 'Origin: https://example.com' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```

应继续被拒绝。

最后测试真实 GET。

---

# 36. 安全注意事项

排障过程中曾通过：

```bash
kubectl exec ... printenv
```

输出完整容器环境变量。

其中包含：

- Client Secret
- Client ID
- 内部服务地址
- CAS/JWT 配置信息

后续在工单、聊天、Wiki、Git 仓库中保存日志时应进行脱敏。

尤其：

```text
POA_CLIENT_SECRET
```

建议按已暴露凭据处理：

1. 在对应平台重新生成 Secret。
2. 更新 Kubernetes Secret / ConfigMap。
3. 滚动重启 Gateway。
4. 验证旧 Secret 已失效。
5. 避免以后使用 `printenv` 后整段直接复制到公共记录。

---

# 37. 最终 RCA 摘要

## 故障现象

`onetable.fyut.edu.cn` 调用 `datawarn.fyut.edu.cn` 时浏览器报：

```text
CORS policy
AxiosError: Network Error
net::ERR_FAILED
```

## 直接原因

浏览器 OPTIONS 预检返回：

```text
HTTP 403
```

## 根因

`gateway-server` 使用 Spring Cloud Gateway，但未配置：

```yaml
spring.cloud.gateway.globalcors
```

导致真正的 CORS preflight 在 Gateway 层被拒绝。

## 为什么后端服务自身看起来正常

`data-portrait-server` 已正确支持：

```text
https://onetable.fyut.edu.cn
```

但浏览器请求先经过 Gateway，因此 Gateway 必须先允许预检。

## 修复方式

通过：

```text
SPRING_APPLICATION_JSON
```

为 Gateway 注入：

```yaml
spring.cloud.gateway.globalcors
```

并配置合法 Origin：

```text
https://onetable.fyut.edu.cn
```

同时通过：

```text
DedupeResponseHeader
```

避免上下游产生重复 CORS Header。

## 修复验证

合法来源：

```text
OPTIONS → HTTP 200
```

非法来源：

```text
OPTIONS → HTTP 403
```

真实 GET：

```text
HTTP 200
```

接口进入业务逻辑，当前仅剩 token 过期业务问题。

---

# 38. 最终推荐配置

推荐正式落地为：

```yaml
spring:
  cloud:
    gateway:
      enabled: true

      globalcors:
        add-to-simple-url-handler-mapping: true
        cors-configurations:
          '[/**]':
            allowedOrigins:
              - "https://onetable.fyut.edu.cn"
            allowedMethods:
              - GET
              - POST
              - PUT
              - DELETE
              - PATCH
              - OPTIONS
            allowedHeaders:
              - "*"
            allowCredentials: true
            maxAge: 3600

      default-filters:
        - DedupeResponseHeader=Access-Control-Allow-Credentials Access-Control-Allow-Origin
```

如果后续希望通过环境变量维护白名单，建议改为：

```yaml
allowedOrigins: ${CORS_ALLOWED_ORIGINS:https://onetable.fyut.edu.cn}
```

然后通过 Kubernetes ConfigMap 管理：

```yaml
data:
  CORS_ALLOWED_ORIGINS: "https://onetable.fyut.edu.cn,https://portal.fyut.edu.cn"
```

---

# 39. 结论

本次故障并不是：

```text
Nginx 转发失败
Kubernetes Ingress 异常
portrait 微服务异常
网络不可达
Axios 本身异常
```

真正的问题是：

```text
Spring Cloud Gateway 缺少全局 CORS 配置
```

导致浏览器预检：

```text
OPTIONS
```

在 Gateway 层直接返回：

```text
403
```

经过逐层绕过 Nginx、Ingress、Service、Pod，以及直接对比 Gateway 与 portrait 服务，最终定位到 Gateway。

增加：

```text
spring.cloud.gateway.globalcors
```

后：

```text
合法 Origin → 200
非法 Origin → 403
真实 GET → 正常进入业务服务
```

至此 CORS 故障处理完成。

