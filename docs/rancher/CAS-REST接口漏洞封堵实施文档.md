# CAS REST 接口（/cas/v1/tickets）漏洞封堵实施文档

| 项目 | 内容 |
|---|---|
| 文档版本 | v1.0 |
| 编写日期 | 2026-08-10 |
| 适用对象 | 校园 CAS/SSO 单点登录平台运维人员 |
| 验证现场 | cascs.zjhzcc.edu.cn（Rancher + RKE1 集群，方案三-C 实测通过） |

---

## 目录

1. [背景与风险说明](#1-背景与风险说明)
2. [参数替换表](#2-参数替换表)
3. [第一步：判断现场是否受影响](#3-第一步判断现场是否受影响)
4. [第二步：判断现场链路结构，选择方案](#4-第二步判断现场链路结构选择方案)
5. [方案一：WAF 防火墙拦截](#5-方案一waf-防火墙拦截)
6. [方案二：nginx01（七层）配置拦截](#6-方案二nginx01七层配置拦截)
7. [方案三：Rancher 负载均衡（Ingress）拦截](#7-方案三rancher-负载均衡ingress拦截)
8. [验证清单](#8-验证清单)
9. [常见故障对照表](#9-常见故障对照表)
10. [回滚方法](#10-回滚方法)
11. [根治建议](#11-根治建议)
12. [附录：实测记录](#12-附录实测记录)

---

## 1. 背景与风险说明

### 1.1 漏洞接口

```
https://<HOST>/cas/v1/tickets
https://<HOST>/cas/v1/users
```

### 1.2 成因

该接口由 CAS 的 **`cas-server-support-rest`** 模块提供，属于 CAS REST Protocol。只要构建 CAS 时引入了该依赖，接口即默认对外开放，**无需任何认证即可访问**。

### 1.3 风险

- 接口直接接收 `username` / `password` 参数，可被用于**账号密码爆破**。
- 返回体中的异常类型（如 `AccountExpiredException`、`AccountNotFoundException`）会**泄露账号是否存在、账号状态**，可用于用户名枚举。
- 未做频率限制时，攻击成本极低。

### 1.4 处置原则

本文档提供的是**边界封堵**（止血），根治方式见 [第 11 节](#11-根治建议)。建议采用纵深防御：WAF + Nginx/Ingress + 应用侧模块下线，至少落实其中两层。

---

## 2. 参数替换表

文档中所有配置模板均使用占位符，实施前请按现场实际值替换。

| 占位符 | 说明 | 获取方式 | 本次实测值 |
|---|---|---|---|
| `<HOST>` | CAS 对外域名 | 现场提供 | `cascs.zjhzcc.edu.cn` |
| `<NS>` | CAS 所在命名空间 | `kubectl get ns` | `cas-server` |
| `<SVC>` | CAS webapp 的 Service 名 | 见 [7.1](#71-前置检查必做) | `cas-server-webapp` |
| `<PORT>` | Service 的 http 端口 | 见 [7.1](#71-前置检查必做) | `8080` |
| `<DNS_IP>` | CoreDNS 的 ClusterIP | 见 [7.1](#71-前置检查必做) | `10.43.0.10` |
| `<ALLOW_IP>` | 需放行的三方厂商调用方 IP | 现场提供 | `172.16.14.245` |

---

## 3. 第一步：判断现场是否受影响

在**任意一台能访问 CAS 的服务器**上执行：

```bash
curl -i -X POST -d "username=test&password=test" https://<HOST>/cas/v1/tickets
```

### 判断标准

**受影响**（接口存在且开放），返回 `401` 且响应体是 **Java 的 JSON 结构**：

```
HTTP/1.1 401
Date: Mon, 10 Aug 2026 07:01:07 GMT
Content-Type: text/plain;charset=UTF-8
Content-Length: 143
Connection: keep-alive
Cache-Control: no-cache, no-store, max-age=0, must-revalidate
Pragma: no-cache
Expires: 0
Strict-Transport-Security: max-age=15724800; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
{
  "@class" : "java.util.HashMap",
  "authentication_exceptions" : [ "java.util.ArrayList", [ "AccountExpiredException: ACCOUNT_EXPIRED" ] ]
}
```

> ⚠️ **本文档全程使用的核心判断标准**
>
> | 返回体特征 | 含义 |
> |---|---|
> | **Java JSON 体**（`"@class" : "java.util.HashMap"`） | 请求**到达了 CAS 应用** |
> | **nginx HTML 页**（`<hr><center>nginx</center>`） | 请求**被 nginx 拦在门外**，未到 CAS |
>
> 后续所有验证都靠这一条区分「拦住了」和「转发失败了」，请务必看响应体，不要只看状态码。

**不受影响**：返回 404 且是 nginx HTML 页（模块未打包），或已被前置设备拦截。

---

## 4. 第二步：判断现场链路结构，选择方案

### 4.1 摸清链路

典型链路：

```
三方厂商/客户端 → 学校外网WAF → 学校反向代理 → 集群外nginx01 → ingress-nginx → CAS Pod
                                                （四层或七层）    （固定为七层）
```

**关键认知：Rancher 里的「负载均衡」背后就是 ingress-nginx，它本身是完整的七层 nginx。**
即使 nginx01 是四层（stream 透传），也**不需要**把它改造成七层——在 Ingress 上配置即可生效。

### 4.2 方案对比与选型

| 方案 | 适用场景 | 优点 | 缺点 |
|---|---|---|---|
| **一：WAF** | 任何场景；**唯一能看到真实客户端 IP 的位置** | 不动业务配置；集中管理 | 需学校配合；变更周期长 |
| **二：nginx01** | nginx01 是**七层**代理 | 直观；不依赖 K8s 权限 | 四层不可用；带白名单时需复制 proxy 块 |
| **三：Ingress** | nginx01 是**四层**，或不想改造 nginx01 | 无需改造前端；秒级生效；不重启 Pod | 需集群操作权限 |

**选型建议**：

- 只需**纯拦截**（现场没有 restful 对接）→ 方案三-A（最简单）
- 需**保留白名单**且能改 nginx01 → 方案二-C
- 需**保留白名单**且 nginx01 是四层 → 方案三-B 或 方案三-C
- **白名单必须按厂商真实公网 IP 判断** → 只能用方案一（见下方警告）

### 4.3 ⚠️ 白名单方案的关键前提：真实源 IP

每经过一次七层反向代理，`$remote_addr` 就变成上一跳的地址。如果链路中间有学校反代，Ingress 看到的**不是**厂商真实 IP，此时白名单会：

- 全部 403 → 业务中断，或
- 写成反代 IP → **等于对全网放行，比不配更危险**

**上线白名单前必须实测确认**，方法见 [7.1.4](#714-确认-ingress-看到的真实源-ip)。

---

## 5. 方案一：WAF 防火墙拦截

### 5.1 操作

将以下地址告知学校信息中心，由学校在 WAF / 边界防火墙上拦截：

```
https://<HOST>/cas/v1/tickets
https://<HOST>/cas/v1/users
```

后续如有三方厂商需要调用，由学校在 WAF 上开放 **源 IP 白名单**。

### 5.2 说明

- 这是**唯一能看到真实客户端公网 IP** 的位置，白名单需求优先走此方案。
- 建议一并拦截：`/cas/actuator/*`、`/cas/status`、`/cas/statistics`（同属信息泄露点）。

---

## 6. 方案二：nginx01（七层）配置拦截

> **前提：nginx01 必须是七层代理。如果是四层（stream），请使用方案三。**

### 6.1 备份（必做）

```bash
cd /opt/nginx/conf
cp nginx.conf nginx.conf.bak$(date +%Y%m%d)
ls -l nginx.conf.bak*
```

### 6.2 方案二-A：纯拦截（无白名单需求）

在 `server` 段中增加：

```nginx
location ~* ^/cas/v1/(tickets|users) {
    deny all;
}
```

**为什么用正则 location 而不是 `if ($request_uri ...)`：**
nginx 在 location 匹配前会先对 URI 解码（`%76%31` → `v1`）、合并多余斜杠（`//` → `/`）、消解 `/./` 与 `/../`。正则 location 匹配的是**归一化后的路径**，天然能挡住绕过；而 `$request_uri` 是**原始未解码**串，极易被绕过。

### 6.3 方案二-B：带白名单（厂商写法）

> ⚠️ **必须把现场 `location /` 里的 proxy 指令整段复制进来。**
> nginx 的 location 是**排他**的：请求一旦命中新 location，就完全不走 `location /` 了。新 location 里若没有 `proxy_pass`，白名单内的请求会掉到静态文件处理，**返回 404**。

```nginx
location ~* ^/cas/v1/(tickets|users) {
    allow <ALLOW_IP>;
    deny all;               # 其余全部拦截

    # ↓↓↓ 以下内容需替换为现场 location / 下面的实际配置 ↓↓↓
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port  $server_port;
    proxy_pass http://rancherworkserver;
    proxy_http_version 1.1;
    proxy_set_header Upgrade    $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

**多个 IP 写多行 `allow`，且必须全部排在 `deny all` 之前**（nginx 访问控制自上而下匹配，命中即停）：

```nginx
    allow 172.16.14.245;
    allow 172.16.14.241;
    allow 192.168.100.0/24;   # 整段网段
    deny all;
```

**缺点**：`location /` 以后改 proxy 参数时，这里容易漏改，形成两套逻辑。

### 6.4 方案二-C：带白名单（推荐，免复制 proxy 块）

不新建 location，用 `geo` 变量在 `location /` 内部判断，proxy 指令一份不用动。

**http 段**（与 `upstream` 同级）增加：

```nginx
geo $cas_rest_allowed {
    default        0;
    127.0.0.1      1;
    <ALLOW_IP>     1;
    192.168.100.0/24  1;
}
```

**`location /` 内部**，在 `proxy_pass` 之前增加：

```nginx
set $cas_rest_block "";
if ($uri ~* "^/cas/v1/(tickets|users)") { set $cas_rest_block "R"; }
if ($cas_rest_allowed = 0)              { set $cas_rest_block "${cas_rest_block}D"; }
if ($cas_rest_block = "RD")             { return 403; }
```

> `if` 内只使用 `return` 和 `set`，属 nginx 官方认可的安全用法，不会踩 "if is evil" 的坑。

**注意**：`geo` 默认取 `$remote_addr`。若 nginx01 前面还有学校反代，需先配置真实 IP 还原：

```nginx
set_real_ip_from 10.0.0.0/8;      # 换成上游反代的地址段
real_ip_header   X-Forwarded-For;
real_ip_recursive on;
```

### 6.5 生效

```bash
/opt/nginx/sbin/nginx -t
/opt/nginx/sbin/nginx -s reload
```

`nginx -t` 必须先通过再 reload。

---

## 7. 方案三：Rancher 负载均衡（Ingress）拦截

### 7.1 前置检查（必做）

#### 7.1.1 确认 Service 名与端口

```bash
kubectl -n <NS> get svc
```

实测输出示例：

```
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
cas-server-webapp   ClusterIP   10.43.x.x       <none>        8080/TCP,6060/TCP   120d
```

更直接的方式——查现有 Ingress 实际指向哪个 Service：

```bash
kubectl -n <NS> get ing -o custom-columns='ING:.metadata.name,SVC:.spec.rules[*].http.paths[*].backend.service.name,PORT:.spec.rules[*].http.paths[*].backend.service.port.number'
```

> **注意**：Rancher 界面上显示的名称是「目标工作负载/Service 的显示名」，**不一定等于实际 Service 资源名**，务必以 `kubectl` 查询结果为准。本次实测现场为 `cas-server-webapp`，端口 `http=8080`、`http-metrics=6060`，取 **8080**。

#### 7.1.2 确认 CoreDNS 的 ClusterIP

```bash
kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}'; echo
```

实测输出：`10.43.0.10`

#### 7.1.3 验证 Service 域名可解析

```bash
kubectl -n <NS> run dnstest --rm -it --image=busybox:1.28 --restart=Never -- \
  nslookup <SVC>.<NS>.svc.cluster.local
```

预期输出包含：

```
Name:      cas-server-webapp.cas-server.svc.cluster.local
Address 1: 10.43.x.x cas-server-webapp.cas-server.svc.cluster.local
```

#### 7.1.4 确认 Ingress 看到的真实源 IP

**只有需要配白名单时才必做。** 从计划放行的机器发一次请求，然后查 ingress 访问日志：

```bash
POD=$(kubectl -n ingress-nginx get pod -l app=ingress-nginx -o name | head -1)
kubectl -n ingress-nginx logs $POD --tail=100 | grep '/cas/v1'
```

| 日志里的源 IP | 处理方式 |
|---|---|
| **就是厂商真实 IP** | 直接配白名单，正常实施 |
| **是集群外 nginx01 的 IP** | 四层未传真实 IP。nginx01 加 `proxy_protocol on;`，controller ConfigMap 设 `use-proxy-protocol: "true"`。<br>⚠️ **RKE 现场必须同步写入 `cluster.yml` 的 `ingress.options`，否则下次 reconcile 会被刷掉** |
| **是学校反代的 IP** | 真实 IP 已在反代那一跳丢失。**不要在 Ingress 做白名单**，退回[方案一](#5-方案一waf-防火墙拦截) |

> 若走 XFF 路线（ConfigMap 设 `use-forwarded-headers: "true"` + `compute-full-forwarded-for: "true"`）：XFF 头**可伪造**，**仅当最外层 WAF 会强制覆写 XFF 时才安全**，否则攻击者随手伪造即可绕过白名单。上线前务必与学校确认。

#### 7.1.5 备份现有 Ingress

```bash
kubectl -n <NS> get ing cas-server-webapp -o yaml > cas-webapp-bak-$(date +%Y%m%d).yaml
ls -l cas-webapp-bak-*.yaml
```

---

### 7.2 方案三-A：纯拦截（无白名单需求，最简单）

**Rancher 界面路径**：`项目` → `负载均衡` → 找到 `cas-server-webapp` → `编辑` → 展开底部 **「标签和注释 / Labels & Annotations」** → 添加注释。

**注释键：**
```
nginx.ingress.kubernetes.io/server-snippet
```

**注释值：**
```nginx
location ~* ^/cas/v1/(tickets|users) {
    deny all;
}
```

或直接「编辑 YAML」：

```yaml
metadata:
  name: cas-server-webapp
  namespace: <NS>
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      location ~* ^/cas/v1/(tickets|users) {
          deny all;
      }
```

保存后 ingress-nginx 自动 reload，**秒级生效，无需重启任何 Pod**。

> **建议扩大封堵范围**（同属常见信息泄露点）：
> ```nginx
> location ~* ^/cas/(v1/(tickets|users)|actuator|status|statistics) {
>     deny all;
> }
> ```
>
> **可选**：把 `deny all;` 换成 `return 404;`。403 等于告诉扫描器「这里有东西但被拦了」，404 让接口看起来根本不存在。

#### YAML 缩进注意

`|` 块标量的缩进基准由**第一行**决定，块内所有行必须 **≥ 基准缩进**。下面这种写法会导致 YAML 解析失败（`could not find expected ':'`），注解根本提交不上去：

```yaml
    nginx.ingress.kubernetes.io/server-snippet: |
      location ~* ^/cas/v1/(tickets|users) {
allow 127.0.0.1;          # ❌ 顶格，YAML 认为块已结束
deny all;                 # ❌
      }
```

正确写法：

```yaml
    nginx.ingress.kubernetes.io/server-snippet: |
      location ~* ^/cas/v1/(tickets|users) {
          allow 127.0.0.1;
          deny all;
      }
```

> nginx 对空白不敏感，在 Rancher 界面单行输入框中提交时，也可以写成一整行：
> `location ~* ^/cas/v1/(tickets|users) { deny all; }`

---

### 7.3 方案三-B：带白名单 · configuration-snippet（推荐）

**原理**：`configuration-snippet` 注入到 ingress-nginx **已生成的 location 内部**，复用 controller 自己管理的 Lua upstream，**不需要写 `proxy_pass`**，因此不存在 404 和 DNS 解析问题。

删除 `server-snippet` 注解，在**同一条 Ingress** 上添加：

**注释键：**
```
nginx.ingress.kubernetes.io/configuration-snippet
```

**注释值：**
```nginx
set $cas_rest_block "";
if ($uri ~* "^/cas/v1/(tickets|users)") {
    set $cas_rest_block "R";
}
if ($remote_addr !~ "^(172\.16\.14\.245|172\.16\.14\.241)$") {
    set $cas_rest_block "${cas_rest_block}D";
}
if ($cas_rest_block = "RD") {
    return 403;
}
```

**逻辑**：路径命中记 `R`，源 IP 不在白名单再补 `D`，两个条件同时成立（`RD`）才拦截。白名单 IP 一路走到底，继承原 location 的 `proxy_pass`，正常到达 CAS。

**白名单写法变体**：

```nginx
# 多个单 IP（点号需转义）
if ($remote_addr !~ "^(172\.16\.14\.245|10\.11\.170\.50)$") { ... }

# 整段网段（前缀匹配）
if ($remote_addr !~ "^192\.168\.100\.") { ... }
```

> 使用 `$uri` 而非 `$request_uri`：前者是 nginx 归一化解码后的路径，能挡住 `/cas//v1/tickets`、`/cas/./v1/tickets`、`%76%31` 等绕过。

---

### 7.4 方案三-C：带白名单 · server-snippet + resolver（**本次现场实测通过**）

保留 `allow/deny` 的直观写法，但必须自行补全转发。

```nginx
location ~* ^/cas/v1/(tickets|users) {
    allow <ALLOW_IP>;
    deny all;

    resolver <DNS_IP> valid=30s ipv6=off;
    set $cas_upstream "<SVC>.<NS>.svc.cluster.local";

    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_pass http://$cas_upstream:8080$request_uri;
}
```

**本次实测使用的实际配置：**

```nginx
location ~* ^/cas/v1/(tickets|users) {
    allow 172.16.14.245;
    deny all;
    resolver 10.43.0.10 valid=30s ipv6=off;
    set $cas_upstream "cas-server-webapp.cas-server.svc.cluster.local";
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_pass http://$cas_upstream:8080$request_uri;
}
```

#### 三个必须遵守的要点

1. **必须用变量 + `resolver`，不能直接写死域名。**
   nginx 对 `proxy_pass` 中写死的域名要求**配置解析期**就能解析出 IP。admission webhook 在校验容器里执行 `nginx -t`，此时会因查不到域名而拒绝整个提交（报错见 [第 9 节](#9-常见故障对照表)）。引入变量后解析被推迟到运行时。

2. **`proxy_pass` 一旦使用变量，必须显式带上 `$request_uri`。**
   否则原始路径不会传给后端，CAS 会收到空路径。这是最容易漏的一处。

3. **多个 IP 写多行 `allow`，全部排在 `deny all` 之前。**

```nginx
    allow 172.16.14.245;
    allow 172.16.14.241;
    allow 172.16.14.0/24;    # 也可用网段合并
    deny all;
```

#### 本方案的两处维护隐患（建议写入交接文档）

| 隐患 | 后果 | 表现 |
|---|---|---|
| `resolver <DNS_IP>` 写死 | CoreDNS 的 ClusterIP 变更（重建 kube-dns Service、改 Service CIDR）后解析失败 | **只有 REST 接口 502，`/cas/` 主路径正常**，容易查偏方向 |
| 该 location 不继承主路径注解 | 后续在 Ingress 上加的限流、超时、自定义 header 不会作用于 `/cas/v1/*` | 两套独立逻辑，配置漂移 |

此外，本方案绕过了 ingress-nginx 的 Lua 负载均衡器，改走 kube-proxy 的 ClusterIP 转发，`session affinity`、`upstream-hash-by` 等注解对该 location 不生效。

---

### 7.5 方案三-D：独立 Ingress + whitelist-source-range（最规范）

不使用任何 snippet，适用于 `allow-snippet-annotations` 被关闭的集群。

> **前提：必须先删除主 Ingress 上的 `server-snippet` 注解。**
> nginx 中正则 location 优先级高于普通前缀 location，若 snippet 残留，本方案生成的 `location /cas/v1` 会被它整个盖住，不生效。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cas-v1-restrict
  namespace: <NS>
  annotations:
    # 多个 IP 用逗号分隔；当前无放行方时填 127.0.0.1/32 作为占位（等价于全部拦截）
    nginx.ingress.kubernetes.io/whitelist-source-range: "172.16.14.245/32,172.16.14.241/32"
spec:
  rules:
  - host: <HOST>
    http:
      paths:
      - path: /cas/v1
        pathType: Prefix
        backend:
          service:
            name: <SVC>
            port:
              number: <PORT>
```

应用：

```bash
kubectl apply -f cas-v1-restrict.yaml
kubectl -n <NS> get ing cas-v1-restrict
```

`/cas/v1` 比 `/cas/` 前缀更长，nginx 优先命中；`proxy_pass`、upstream、keepalive 全部由 controller 自动生成，**无需复制任何内容**。后续换 IP 只改一行注解。

---

## 8. 验证清单

### 8.1 检查生成的 nginx 配置

```bash
POD=$(kubectl -n ingress-nginx get pod -l app=ingress-nginx -o name | head -1)
kubectl -n ingress-nginx exec $POD -- cat /etc/nginx/nginx.conf | grep -A25 'location.*cas/v1'
```

**带白名单方案必须确认 `allow` / `deny all` 与 `proxy_pass` 同时存在。** 只有 allow/deny 没有 proxy_pass，白名单 IP 会 404。

### 8.2 检查是否有配置错误

```bash
kubectl -n ingress-nginx logs $POD --tail=50 | grep -iE 'emerg|invalid|error'
```

> 以下三条 **warn 属于基础配置固有噪音，与本次变更无关，无需处理**：
> ```
> [warn] the "http2_max_field_size" directive is obsolete, use the "large_client_header_buffers" directive instead
> [warn] the "http2_max_header_size" directive is obsolete, use the "large_client_header_buffers" directive instead
> [warn] the "http2_max_requests" directive is obsolete, use the "keepalive_requests" directive instead
> ```
> 只需关注 `[emerg]` 行。

### 8.3 功能验证

| # | 执行位置 | 命令 | 预期结果 |
|---|---|---|---|
| 1 | **白名单机器** | `curl -i -X POST -d "username=test&password=test" https://<HOST>/cas/v1/tickets` | `401` + **Java JSON 体** |
| 2 | **非白名单机器** | 同上 | `403` + **nginx HTML 页** |
| 3 | 任意 | `curl -i "https://<HOST>/cas//v1/tickets"` | `403`（绕过测试） |
| 4 | 任意 | `curl -i "https://<HOST>/cas/./v1/tickets"` | `403`（绕过测试） |
| 5 | 任意 | `curl -i "https://<HOST>/CAS/V1/TICKETS"` | `403`（大小写绕过测试） |
| 6 | 任意 | `curl -i https://<HOST>/cas/login` | `200`（确认登录页未被误伤） |
| 7 | 任意 | `curl -i https://<HOST>/cas/v1/users` | `403` |

**纯拦截方案**（三-A / 二-A）无第 1 条，所有位置均应返回 403。

### 8.4 业务回归

- [ ] 浏览器打开 `https://<HOST>/cas/login`，完成一次正常登录
- [ ] 至少验证 2 个已接入的业务系统单点登录正常
- [ ] 确认三方厂商 restful 对接调用正常（如有）

---

## 9. 常见故障对照表

| 现象 | 根本原因 | 处理方法 |
|---|---|---|
| **白名单 IP 返回 404 + nginx HTML 页** | `server-snippet` 新建的 location 缺 `proxy_pass`，nginx 退回静态文件处理器找不到文件 | 按 [方案三-C](#74-方案三-c带白名单--server-snippet--resolver本次现场实测通过) 补 `resolver` + `proxy_pass`，或改用 [方案三-B](#73-方案三-b带白名单--configuration-snippet推荐) |
| **提交时被 admission webhook 拒绝**：<br>`[emerg] host not found in upstream "xxx.svc.cluster.local"` | `proxy_pass` 写死域名，nginx 在**配置解析期**就要解析，webhook 校验容器内查不到 | ① 用 `kubectl -n <NS> get svc` 核对 Service 名与命名空间；② 改用变量 + `resolver` 写法（[7.4](#74-方案三-c带白名单--server-snippet--resolver本次现场实测通过)） |
| **所有 IP（含白名单）都返回 403** | Ingress 看到的不是真实客户端 IP（链路中有反代/四层未传 IP） | 按 [7.1.4](#714-确认-ingress-看到的真实源-ip) 排查；确认丢失后改用[方案一](#5-方案一waf-防火墙拦截) |
| **白名单 IP 返回 502** | `resolver` 地址错误，或 CoreDNS 异常 | 核对 `kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}'` |
| **白名单 IP 到达 CAS 但报路径错误** | `proxy_pass` 用了变量却未带 `$request_uri` | 补上 `$request_uri` |
| **注解提交报 `could not find expected ':'`** | YAML 块标量缩进错误（内容行顶格） | 块内所有行缩进 ≥ 第一行 |
| **配置提交成功但完全不生效** | ① `allow-snippet-annotations` 被关闭；② 同 host 下多条 Ingress 的 `server-snippet` 冲突 | ① ConfigMap 设 `allow-snippet-annotations: "true"`（**RKE 需同步写入 cluster.yml 的 `ingress.options`**）；② snippet 只在其中一条 Ingress 上配置 |
| **新建的独立 Ingress 不生效** | 主 Ingress 上的 `server-snippet` 正则 location 优先级更高，把它盖住了 | 先删除 `server-snippet` 注解 |
| **重启/升级后配置消失** | RKE reconcile 覆盖了 ingress-nginx ConfigMap | 把 ConfigMap 改动写入 `cluster.yml` 的 `ingress.options` |

---

## 10. 回滚方法

### 10.1 Ingress 方案回滚

**界面操作**：编辑对应负载均衡 → 删除新增的注释 → 保存。

**命令行**：

```bash
# 删除注解
kubectl -n <NS> annotate ing cas-server-webapp nginx.ingress.kubernetes.io/server-snippet-
kubectl -n <NS> annotate ing cas-server-webapp nginx.ingress.kubernetes.io/configuration-snippet-

# 或从备份整体还原
kubectl apply -f cas-webapp-bak-<日期>.yaml

# 删除独立 Ingress（方案三-D）
kubectl -n <NS> delete ing cas-v1-restrict
```

回滚验证：

```bash
curl -i -X POST -d "username=test&password=test" https://<HOST>/cas/v1/tickets
# 应恢复为 401 + Java JSON 体
```

### 10.2 nginx01 方案回滚

```bash
cd /opt/nginx/conf
cp nginx.conf.bak<日期> nginx.conf
/opt/nginx/sbin/nginx -t
/opt/nginx/sbin/nginx -s reload
```

---

## 11. 根治建议

以上全部为**边界封堵**，接口本身依然存在。彻底修复方式：

1. **下线 REST 模块**：从 CAS 构建中移除 `cas-server-support-rest` 依赖，重新打包镜像 → 推送 Harbor → 滚动更新。这是治本方案。
2. **白名单的局限**：IP 白名单只把攻击面从「全网」缩小到「厂商机器 + 中间链路」。厂商那台机器一旦失陷，接口依然可达。
3. **若接口必须保留**：推动厂商侧改为带密钥/证书的调用方式，并在 CAS 侧启用登录失败频率限制（throttling）。
4. **一并排查同类接口**：`/cas/actuator/*`、`/cas/status`、`/cas/statistics`、`swagger-ui.html`。

建议**边界封堵 + 模块下线两条腿走**，前者止血，后者治愈。

---

## 12. 附录：实测记录

**现场**：cascs.zjhzcc.edu.cn ｜ **集群**：Rancher + RKE1 ｜ **日期**：2026-08-10

### 12.1 环境参数

```
命名空间:      cas-server
Service:       cas-server-webapp (ClusterIP)
端口:          http=8080 / http-metrics=6060
CoreDNS:       10.43.0.10
白名单机器:    cs-mysql   172.16.14.245
对照机器:      harbor     （非白名单）
```

### 12.2 阶段一：未配置任何注解（漏洞存在）

```
[root@cs-mysql ~]# curl -i -X POST -d "username=test&password=test" https://cascs.zjhzcc.edu.cn/cas/v1/tickets
HTTP/1.1 401
Content-Type: text/plain;charset=UTF-8
Content-Length: 143
...
{
  "@class" : "java.util.HashMap",
  "authentication_exceptions" : [ "java.util.ArrayList", [ "AccountExpiredException: ACCOUNT_EXPIRED" ] ]
}
```

→ **Java JSON 体，请求到达 CAS，接口开放。**

### 12.3 阶段二：仅 `deny all`（纯拦截生效）

```
[root@cs-mysql ~]# curl -i -X POST -d "username=test&password=test" https://cascs.zjhzcc.edu.cn/cas/v1/tickets
HTTP/1.1 403 Forbidden
Content-Type: text/html
Content-Length: 146
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

→ **nginx HTML 页，被拦在门外。**

### 12.4 阶段三：`allow` + `deny all`，但无 proxy_pass（**踩坑**）

配置：`location ~* ^/cas/v1/(tickets|users) { allow 172.16.14.245; deny all; }`

```
[root@cs-mysql ~]# curl -i -X POST -d "username=test&password=test" https://cascs.zjhzcc.edu.cn/cas/v1/tickets
HTTP/1.1 404 Not Found
Content-Type: text/html
<html>
<head><title>404 Not Found</title></head>
...
<hr><center>nginx</center>
</body>
</html>
```

→ **403 变 404，说明 `allow` 已命中**（顺带证明该现场 Ingress 能看到真实源 IP），但新 location 无 `proxy_pass`，nginx 退回静态文件处理器返回 404，请求未到 CAS。

### 12.5 阶段四：写死 FQDN 的 proxy_pass（**踩坑**）

配置：`proxy_pass http://cas-server-webapp.cas-server.svc.cluster.local:8080;`

```
admission webhook "validate.nginx.ingress.kubernetes.io" denied the request:
...
2026/08/10 08:07:22 [emerg] 4297#4297: host not found in upstream
"cas-server-webapp.cas-server.svc.cluster.local" in /tmp/nginx/nginx-cfg111914859:2051
nginx: configuration file /tmp/nginx/nginx-cfg111914859 test failed
```

→ webhook 拒绝，**配置未提交，线上保持上一版，业务未受影响**。同批出现的 `http2_max_field_size` 等 warn 为固有噪音。

### 12.6 阶段五：变量 + resolver（**最终方案，通过**）

配置见 [7.4](#74-方案三-c带白名单--server-snippet--resolver本次现场实测通过)。

**白名单机器 172.16.14.245：**

```
[root@cs-mysql ~]# curl -i -X POST -d "username=test&password=test" https://cascs.zjhzcc.edu.cn/cas/v1/tickets
HTTP/1.1 401
Date: Mon, 10 Aug 2026 10:21:41 GMT
Content-Type: text/plain;charset=UTF-8
Content-Length: 143
Connection: keep-alive
Cache-Control: no-cache, no-store, max-age=0, must-revalidate
Pragma: no-cache
Expires: 0
Strict-Transport-Security: max-age=15768000 ; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
{
  "@class" : "java.util.HashMap",
  "authentication_exceptions" : [ "java.util.ArrayList", [ "AccountExpiredException: ACCOUNT_EXPIRED" ] ]
}
```

→ ✅ **Java JSON 体，白名单放行成功，请求到达 CAS。**

**非白名单机器 harbor：**

```
[root@harbor ~]# curl -i -X POST -d "username=test&password=test" https://cascs.zjhzcc.edu.cn/cas/v1/tickets
HTTP/1.1 403 Forbidden
Date: Mon, 10 Aug 2026 10:22:14 GMT
Content-Type: text/html
Content-Length: 146
Connection: keep-alive
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

→ ✅ **nginx HTML 页，非白名单拦截成功。**

**结论：方案三-C 验证通过，白名单与拦截双向符合预期。**

---

## 实施速查卡

```
① 判断是否受影响    curl -i -X POST -d "username=test&password=test" https://<HOST>/cas/v1/tickets
                    → 401 + Java JSON = 受影响

② 摸链路            nginx01 是四层还是七层？前面有没有学校反代？

③ 选方案            纯拦截 ────────────────→ 方案三-A（Ingress，deny all）
                    要白名单 + nginx01 七层 → 方案二-C（geo 写法）
                    要白名单 + nginx01 四层 → 方案三-B 或 三-C
                    要按厂商公网 IP 白名单 ─→ 方案一（WAF）

④ 前置检查          kubectl -n <NS> get svc                                    # Service 名+端口
                    kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}'
                    kubectl -n <NS> get ing <ING> -o yaml > 备份.yaml
                    查 ingress 日志确认真实源 IP（配白名单时必做）

⑤ 实施              加注解 → 自动 reload，秒级生效

⑥ 验证              白名单机 → 401 + Java JSON
                    非白名单 → 403 + nginx HTML
                    /cas/login → 200
```
