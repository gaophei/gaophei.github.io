# 校园统一反代场景下集群外 Nginx 入口改造方案

> **文档定位**：学校收回自建服务的 SSL 证书、要求统一走校级反代设备后，Rancher 集群外 Nginx 入口的改造标准做法。含选型判断、实施步骤、完整配置样例、踩坑记录与排障命令。
>
> **适用范围**：域名 → 学校外网 → 学校统一反代 → 集群外 Nginx → Rancher 工作节点 ingress 这一类链路。
>
> **首次落地现场**：shufe-zj（浙江，CentOS 7.9 + Nginx + Rancher/RKE1）

| 项目 | 内容 |
|---|---|
| 文档版本 | v1.0 |
| 编写日期 | 2026-07-24 |
| 操作系统 | CentOS 7.9 |
| 涉及组件 | Nginx（集群外入口）、ingress-nginx（集群内）、学校反代设备 |
| 变更风险等级 | 中（入口层变更，影响全部业务域名，需窗口期） |

---

## 目录

1. [背景与触发条件](#1-背景与触发条件)
2. [现网架构](#2-现网架构)
3. [前置信息采集（必做）](#3-前置信息采集必做)
4. [方案选型决策](#4-方案选型决策)
5. [实施步骤](#5-实施步骤)
6. [完整配置样例](#6-完整配置样例)
7. [关键技术点与踩坑记录](#7-关键技术点与踩坑记录)
8. [排障命令速查](#8-排障命令速查)
9. [上线验证清单](#9-上线验证清单)
10. [回退方案](#10-回退方案)
11. [遗留与待核实事项](#11-遗留与待核实事项)
12. [附录 A：本次现场实施记录](#附录-a本次现场实施记录)
13. [附录 B：配置变更 diff](#附录-b配置变更-diff)

---

## 1. 背景与触发条件

### 1.1 触发场景

学校信息中心通知：**不再为各业务系统单独签发/续期 SSL 证书，所有对外服务统一强制经过校级反代设备**，由反代设备持有权威证书并终结客户端 TLS。

对我们的直接影响：集群外 Nginx 上原本配置的 `ssl_certificate` 到期后无法续期。

### 1.2 需要先厘清的一个误区

> **能不能借用其他学校的 SSL 证书？**
>
> **不能，而且没必要。**
>
> - 证书是公私钥对。别人的 `.pem` 可以拿到，`.key` 拿不到——真拿到了属于严重安全事故。没有私钥 Nginx 起不来。
> - 即使有，域名不匹配，任何做证书校验的客户端都会报错。
> - **最关键的**：TLS 已经由学校反代终结，集群外 Nginx 到反代设备之间是**内网的一跳**。这一跳用什么证书完全由你和反代设备约定，不需要任何 CA 签发。自签证书即可。

### 1.3 改造目标

| 目标 | 说明 |
|---|---|
| 去除对权威证书的依赖 | 内网一跳改用自签证书，或直接不加密 |
| 保持业务无感 | 全部业务域名访问正常，无重定向循环、无混合内容告警 |
| 保持 WebSocket 可用 | Rancher UI、业务系统的长连接功能不受影响 |
| 保留真实客户端 IP | 日志可溯源，满足等保要求 |
| 合规基线不降级 | TLS 协议版本、加密套件符合等保扫描要求 |

---

## 2. 现网架构

```
                    客户端浏览器
                         │
                         │  https://portal.xxx.edu.cn  （权威证书在此校验）
                         ▼
                 学校外网出口 / 防火墙
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  学校统一反代设备  10.11.170.12     │  ← 持有权威证书
        │  在此终结客户端 TLS                 │  ← 改造后唯一的对外 TLS 终结点
        └────────────────────────────────────┘
                         │
                         │  https 回源，目的端口 443（本次现场实测）
                         ▼
        ┌────────────────────────────────────┐
        │  集群外 Nginx     10.11.170.3       │  ★ 本次改造对象
        │  自签证书，least_conn 负载          │
        └────────────────────────────────────┘
                         │
                         │  https，proxy_pass 到工作节点 443
                         ▼
        ┌────────────────────────────────────┐
        │  Rancher 工作节点 ingress-nginx     │
        │  10.11.133.94/95/96/98/99          │
        │  10.11.133.117~121/133             │
        └────────────────────────────────────┘
                         │
                         ▼
                     业务 Pod
```

### 关键认知

改造后链路上存在 **两次 TLS 终结**：

1. 客户端 ↔ 学校反代：权威证书，学校负责
2. 学校反代 ↔ 集群外 Nginx：自签证书，我们负责
3. 集群外 Nginx ↔ ingress：ingress 自持证书，Nginx 侧默认不校验

**协议信息（scheme / port）在第 2 跳会丢失**，必须通过 `X-Forwarded-*` 头人工补回去。这是本次改造 90% 故障的根源，详见 [7.2](#72-x-forwarded-proto-必须写死不能用-scheme)。

---

## 3. 前置信息采集（必做）

**不要跳过这一节。** 本次现场因为一开始没有确认回源端口就动手，走了弯路。

### 3.1 采集清单

| # | 需确认项 | 为什么重要 | 采集方法 |
|---|---|---|---|
| 1 | 本机 Nginx 当前工作在 4 层还是 7 层 | 决定是否需要改造 | 见 3.2 |
| 2 | 学校反代回源的协议和端口 | 决定选方案 A 还是 B | 见 3.3 |
| 3 | 学校反代是否校验源站证书 | 决定自签证书是否可行 | 见 3.4 |
| 4 | 学校反代是否透传原始 Host | 影响 `proxy_set_header Host` 写法 | 见 3.5 |
| 5 | 学校反代是否透传 X-Forwarded-For | 影响真实 IP 与日志溯源 | 见 3.5 |
| 6 | 后端 ingress 是否启用 `use-proxy-protocol` | **7 层方案的硬约束**，见 7.5 | 见 3.6 |
| 7 | 后端 ingress 是否启用 `use-forwarded-headers` | 决定 XFP 是否被后端采信 | 见 3.6 |
| 8 | 该入口承载几个业务域名 | 单域名 vs 多域名，影响选型 | 见 3.7 |

### 3.2 判断本机 Nginx 工作在几层

```bash
# 方法一：看实际加载的配置里有没有 stream 块
nginx -T 2>/dev/null | grep -E "^\s*(stream|http)\s*\{"

# 方法二：看有没有 http 层特有的 server 块（比如健康检查端口）
curl -I http://127.0.0.1:8080/health
# 200      → 7 层配置已加载
# 拒绝连接 → 大概率还是 4 层 stream，或配置未 reload
```

> **重要**：如果本机是 **4 层 stream 配置**，它根本不终结 TLS、配置里压根没有 `ssl_certificate` 这一项——**学校收回证书对该现场影响为零，一行都不用改**。直接回复信息中心"无需配合改造"即可。
>
> 本次现场在这里绕过弯：4 层配置本可以不动，但因为要与其他现场配置对齐、且需要在入口层做 swagger 拦截，才决定改 7 层。**如果没有这类额外诉求，维持 4 层是最优解。**

### 3.3 确认学校反代的回源端口和协议

**不要问，直接抓。** 学校信息中心的回复往往不准确。

```bash
# 方法一：看已建立的连接落在哪个本地端口
ss -tn state established | grep <学校反代IP>

# 方法二：抓包（最可靠）
tcpdump -i any -nn "host <学校反代IP> and (port 80 or port 443)" -c 20
```

**判读要点**（以本次现场为例）：

```
17:40:41.437449 IP 10.11.170.12.33190 > 10.11.170.3.443: Flags [S], ...
                    ↑ 学校反代                ↑ 本机:443  ← 回源端口确认为 443
17:40:41.438602 IP 10.11.170.12.33190 > 10.11.170.3.443: Flags [P.], length 194
                                                                     ↑ ClientHello
17:40:41.443028 IP 10.11.170.3.443 > 10.11.170.12.33190: Flags [P.], length 1310
                                                                     ↑ 证书链下发
17:40:41.444063 IP 10.11.170.12.33190 > 10.11.170.3.443: length 93   ← 密钥交换
17:40:41.445054 IP 10.11.170.3.443 > 10.11.170.12.33190: length 51   ← CCS/Finished
17:40:41.446050 IP 10.11.170.12.33190 > 10.11.170.3.443: length 792  ← 加密后的 HTTP 请求
17:40:41.475962 IP 10.11.170.3.443 > 10.11.170.12.33190: length 4109 ┐
17:40:41.475981 ...                                       length 4125 │ 约 25KB
17:40:41.477009 ...                                       length 5544 │ 正常响应
17:40:41.477029 ...                                       length 8271 │
17:40:41.477175 ...                                       length 2727 ┘
```

看到完整的握手四步 + 后续大块数据交换，说明：

- 回源端口 **443**
- TLS 握手 **成功**
- **学校反代不校验源站证书**（否则在收到自签证书那一步就会 RST）
- 后端有正常内容返回

一次抓包同时确认了清单里的 #2 和 #3，非常划算。

### 3.4 确认反代是否校验源站证书

如上，抓包看握手能否走完即可。若握手在证书下发后立即 RST/FIN，说明对方在校验，需要联系信息中心关闭"源站证书校验"选项（不同厂商叫法不一：`ssl_verify off`、"不验证后端证书"、"忽略证书错误"）。

### 3.5 确认 Host 与 XFF 透传情况

临时在 `log_format` 里加变量，reload 后看一次真实请求：

```nginx
log_format  probe  '$remote_addr | host=$host | xff=[$http_x_forwarded_for] '
                   'xfp=[$http_x_forwarded_proto] | "$request" $status';
```

- `host=` 显示的是真实域名 → 透传正常，`proxy_set_header Host $host` 可用
- `host=` 显示的是 IP → 需要写死域名：`proxy_set_header Host portal.xxx.edu.cn;`
- `xff=[]` 为空 → 反代不透传，`set_real_ip_from` 是空转，真实客户端 IP 拿不到，需要找信息中心开启

### 3.6 确认后端 ingress 配置

```bash
# RKE1 环境
kubectl -n ingress-nginx get cm nginx-configuration -o yaml \
  | grep -iE "proxy-protocol|forwarded|real-ip"
```

也可从 Rancher UI 查看：**集群 → 存储/更多资源 → 配置映射 → `ingress-nginx` 命名空间 → `ingress-nginx-controller`**。

四个关键项：

| 配置项 | 值 | 对本次改造的含义 |
|---|---|---|
| `use-proxy-protocol` | `true` | **7 层方案不可用**，必须先改 ingress，见 7.5 |
| `use-proxy-protocol` | `false`/缺省 | 7 层方案可行 |
| `use-forwarded-headers` | `true` | 后端采信入口传的 `X-Forwarded-Proto`，因此 XFP **务必写死 https** |
| `use-forwarded-headers` | `false`/缺省 | 后端用自身 `$scheme`，XFP 只影响应用层 |
| `compute-full-forwarded-for` | `true` | ingress 追加完整 XFF 链，保留客户端 IP |
| `proxy-real-ip-cidr` | 默认 `0.0.0.0/0` | **存在伪造风险**，建议限定为集群外 Nginx 的 IP，见 7.9 |

具体如何配套调整见 [4.4](#44-集群内-ingress-侧配套改造必做)。

> **注意**：RKE1 环境下直接 `kubectl edit cm` 或在 Rancher UI 改配置映射，可能被 RKE reconciliation 覆盖。必须同步落到 `cluster.yml` 的 `rke_config.ingress.options` 段。

### 3.7 确认承载的域名数量

```bash
# 从访问日志统计
awk '{print $NF}' /var/log/nginx/access.log | sort -u | head -50
# 或者直接问业务方 / 看 ingress
kubectl get ingress -A -o custom-columns=NS:.metadata.namespace,HOST:.spec.rules[*].host
```

**单域名或少量同类域名** → 7 层没问题。
**大量异构业务域名** → 慎重，见 [4.3](#43-多业务域名场景的特别提醒)。

---

## 4. 方案选型决策

### 4.1 决策树

```
本机 Nginx 是 4 层 stream 吗？
├─ 是 → 【方案 0】不改动。stream 不终结 TLS，与证书无关。收工。
└─ 否（7 层 http）
   │
   └─ 后端 ingress 启用了 use-proxy-protocol 吗？
      ├─ 是 → 必须先关掉（改 cluster.yml + rke up），否则 7 层无法工作
      └─ 否
         │
         └─ 学校反代回源用什么协议？
            ├─ HTTP:80  → 【方案 A】本机只监听 80，纯 HTTP 回源
            ├─ HTTPS:443 → 【方案 B】保留 443，换自签证书  ★本次采用
            └─ 不确定/可能变动 → 【方案 B+】80/443 同 server 双监听，两种都兼容
```

> **推荐直接上【方案 B+】**：一个 server 块同时 `listen 80` 和 `listen 443 ssl`，行为完全一致。无论学校反代从哪个端口回源都能通，且以后学校单方面调整回源端口时不用改配置。本次现场最终采用的就是这个形态。

### 4.2 三种方案对比

| 维度 | 方案 0（维持 4 层） | 方案 A（7 层纯 HTTP） | 方案 B+（7 层双监听 + 自签）★ |
|---|---|---|---|
| 改动量 | 无 | 中 | 中 |
| 需要证书 | 否 | 否 | 自签 |
| 内网一跳加密 | 透传（端到端加密） | 明文 | 加密 |
| SNI | 原样透传 | 丢失 | 丢失 |
| 各业务独立跳转策略 | 保留 | 被抹平 | 被抹平 |
| 入口层做 URL 拦截/改写 | 不支持 | 支持 | 支持 |
| 入口层访问日志 | 仅连接级 | 完整 HTTP 日志 | 完整 HTTP 日志 |
| 真实客户端 IP | 需 proxy_protocol | XFF + real_ip | XFF + real_ip |
| 回源端口变动的适应性 | 好 | 差 | 好 |
| 踩坑概率 | 低 | 中 | 中 |

### 4.3 多业务域名场景的特别提醒

这是本次现场最值得记录的一条经验。

4 层和 7 层在多域名场景下的差异是**本质性**的：

| | 4 层 stream | 7 层 http |
|---|---|---|
| TLS 终结点 | 每个业务的 ingress 自己 | 集群外 Nginx 统一终结 |
| 证书 | 各业务 ingress 各自持有 | 一张自签证书顶所有域名 |
| SNI | 原样透传，ingress 按 SNI 选证书 | 被吃掉 |
| 跳转策略 | 各业务 ingress/应用自己决定 | 被入口配置统一抹平 |

7 层等于把所有业务的差异强行归一化。只要其中**任何一个**业务的 ingress 带了 `force-ssl-redirect` 之类注解，或应用层自己有一套 http/https 判断逻辑，跟入口统一下发的 `X-Forwarded-Proto` 对不上，那个域名就会出现重定向循环。

**故障特征**：不是某一个域名出问题，而是"业务网址打开**都是**重定向太多"。这说明不是某个配置项写错，是整层抽象不匹配，需要回到 [7.2](#72-x-forwarded-proto-必须写死不能用-scheme) 逐项对齐 `X-Forwarded-*`。

### 4.4 集群内 ingress 侧配套改造（必做）

**这是最容易被漏掉、也最容易致命的一步。** 4 层和 7 层对 ingress-nginx 配置映射的要求是**互斥**的，切换时必须同步调整。

| ConfigMap 键 | 4 层 stream | 7 层 http | 说明 |
|---|---|---|---|
| `use-proxy-protocol` | `true` | **必须移除 / false** | http 模块无法发送 PROXY 头，见 7.5 |
| `use-forwarded-headers` | 不需要 | `true` | 让 ingress 采信入口传来的 `X-Forwarded-*` |
| `compute-full-forwarded-for` | 不需要 | `true` | 让 ingress 追加完整 XFF 链，保留客户端 IP |
| `proxy-real-ip-cidr` | 建议限定 | **强烈建议限定** | 默认 `0.0.0.0/0`，存在伪造风险，见 7.9 |

**本次现场实际采用的配置**（Rancher → 配置映射 → `ingress-nginx` 命名空间 → `ingress-nginx-controller`）：

```yaml
# 4 层 stream 时期
use-proxy-protocol: "true"

# 7 层 http 时期（改造后）
use-forwarded-headers: "true"
compute-full-forwarded-for: "true"
```

#### 切换顺序很重要

```
1. 先改 ingress ConfigMap        （controller 自动 reload，秒级生效）
2. 再改集群外 Nginx 并 reload
```

反过来做，中间会有一段两侧协议不匹配的窗口，期间入口完全不可用。**变更单里要把这个顺序写清楚。**

#### 持久化风险（重要）

RKE1 下这个 ConfigMap 由 RKE 托管。只在 Rancher UI / kubectl 层面修改，下次 `rke up`、集群编辑、节点增删时**可能被 reconcile 回去**。必须同步写入 `cluster.yml`：

```yaml
ingress:
  provider: nginx
  options:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    proxy-real-ip-cidr: "<集群外Nginx IP>/32"
```

**特别注意**：如果 `use-proxy-protocol: "true"` 还留在 `cluster.yml` 里、只是从运行中的 ConfigMap 删掉了，那么下一次集群编辑就会被写回——届时 7 层入口会**瞬间全挂**，且故障点极难联想到"我上周改过一个 YAML"。改造完成后务必回 `cluster.yml` 确认这一项已被移除。

---

## 5. 实施步骤

以【方案 B+】为例。**建议安排在业务低峰窗口，全程预留回退。**

### Step 1：备份

```bash
cd /usr/local/nginx/conf     # 按现场实际路径调整
cp -a nginx.conf nginx.conf.bak.$(date +%Y%m%d%H%M)
cp -a ssl ssl.bak.$(date +%Y%m%d%H%M)

# 记录当前监听状态，回退时比对
ss -lntp | grep nginx > /tmp/nginx_listen_before.txt
nginx -T > /tmp/nginx_full_conf_before.txt 2>&1
```

### Step 2：生成自签证书

> **CentOS 7.9 注意**：系统自带 OpenSSL 1.0.2k，**不支持 `-addext` 参数**。必须用配置文件方式添加 SAN。直接照抄网上带 `-addext` 的命令会报 `unknown option`。

```bash
cd /usr/local/nginx/conf
mkdir -p ssl && cd ssl

cat > /tmp/san.cnf <<'EOF'
[req]
distinguished_name = dn
x509_extensions    = v3_req
prompt             = no

[dn]
C  = CN
ST = Zhejiang
O  = Campus
OU = IT
CN = portal.xxx.edu.cn

[v3_req]
basicConstraints = CA:FALSE
keyUsage         = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt

[alt]
DNS.1 = portal.xxx.edu.cn
DNS.2 = *.xxx.edu.cn
EOF

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout internal.key -out internal.pem \
  -config /tmp/san.cnf

chmod 600 internal.key
chmod 644 internal.pem
chown nginx:nginx internal.key internal.pem
rm -f /tmp/san.cnf
```

```bash
# 泛域名证书
cd /etc/nginx    # 按你实际的 nginx 前缀
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout ssl/internal.key -out ssl/internal.pem \
  -subj "/C=CN/O=Internal/CN=shufe-zj.edu.cn"
chmod 600 ssl/internal.key
```



**校验生成结果**：

```bash
openssl x509 -in internal.pem -noout -subject -dates -ext subjectAltName
```

**说明**：

- `-days 3650`：内网自签，给足十年，避免以后再被过期问题打扰
- CN/SAN 填真实域名：万一学校反代做 SNI 或域名匹配校验，能兜住
- 通配符 SAN：该入口承载多个同后缀域名时省事

### Step 3：修改 nginx.conf

> **前置动作**：若原配置为 4 层且带 `proxy_protocol on`，**必须先完成 [4.4](#44-集群内-ingress-侧配套改造必做) 的 ingress ConfigMap 调整**，再回到本步骤。顺序反了会有不可用窗口。

核心动作四条，缺一不可：

| # | 动作 | 原因 |
|---|---|---|
| 1 | **删除**独立的 `listen 80` + `rewrite ... https permanent` server 块 | 循环根源，见 7.1 |
| 2 | 把 `listen 80` 并入原 443 的 server 块 | 兼容两种回源端口 |
| 3 | `X-Forwarded-Proto` / `X-Forwarded-Port` **写死** `https` / `443` | 循环根源，见 7.2 |
| 4 | `Connection` 头改用 `$connection_upgrade` | 见 7.4 |

附带的合规收紧：

| # | 动作 | 原因 |
|---|---|---|
| 5 | `ssl_protocols` 去掉 `TLSv1 TLSv1.1` | 等保扫描必点名 |
| 6 | `ssl_ciphers` 去掉 `3DES`/`RC4`/`DES` | 同上 |
| 7 | `server_name localhost` 改 `_` | 语义更准确（接收任意域名） |

完整配置见 [第 6 节](#6-完整配置样例)。

### Step 4：语法校验

```bash
nginx -t
# 必须看到：
# nginx: configuration file ... test is successful
```

**校验通过不代表逻辑正确**，务必继续 Step 5、6。

### Step 5：本机自测（reload 之前先看清后端状态）

```bash
# 先确认后端 ingress 本身正常，排除后端因素
curl -Ik -H "Host: portal.xxx.edu.cn" https://10.11.133.94/
# 期望 200 或 302 到登录页
# 若 400 / 连接重置 → 后端 ingress 可能开着 use-proxy-protocol，见 7.5，此时不要继续
```

### Step 6：reload

```bash
nginx -s reload
# 或 systemctl reload nginx

# 确认监听端口
ss -lntp | grep nginx
# 期望同时看到 :80、:443、:8080
```

### Step 7：验证

见 [第 9 节验证清单](#9-上线验证清单)。

### Step 8：观察

```bash
# 盯 error log 5~10 分钟
tail -f /var/log/nginx/error.log

# 统计跳转状态码占比，正常业务不应大量出现 301/302
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
```

---

## 6. 完整配置样例

已在 shufe-zj 现场验证生效。**替换 `<>` 内的现场值后使用。**

```nginx
user  nginx;
worker_processes  auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 1024000;

events {
    use epoll;
    multi_accept on;
    worker_connections 65535;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    charset utf-8;
    server_tokens off;
    server_names_hash_bucket_size 64;

    client_header_buffer_size 4k;
    client_header_timeout 15;
    client_body_timeout 15;
    reset_timedout_connection on;
    send_timeout 15;
    client_max_body_size 500m;

    sendfile     on;
    tcp_nopush   on;
    tcp_nodelay  on;

    # ---- 日志 ----
    # 建议在改造期临时加上 $upstream_status 和 $sent_http_location，
    # 便于定位 301/302 是本机发的还是后端返回的（见 8.4）
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" $request_time';

    access_log  /var/log/nginx/access.log  main;
    error_log   /var/log/nginx/error.log   warn;

    # ---- gzip ----
    gzip on;
    gzip_min_length 2k;
    gzip_buffers   4 32k;
    gzip_http_version 1.1;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/javascript text/xml text/x-component
               application/xml+rss application/json application/javascript
               application/x-javascript application/xml image/svg+xml
               application/vnd.ms-fontobject font/truetype font/opentype;
    gzip_vary on;
    gzip_proxied any;
    gzip_disable "MSIE [1-6]\.";

    keepalive_timeout  120;
    keepalive_requests 20000;

    open_file_cache_errors on;
    open_file_cache max=102400 inactive=60s;
    open_file_cache_valid 90s;
    open_file_cache_min_uses 1;

    proxy_buffer_size          1024k;
    proxy_buffers           16 1024k;
    proxy_busy_buffers_size    2048k;
    proxy_temp_file_write_size 2048k;

    proxy_connect_timeout    600;
    proxy_read_timeout       600;
    proxy_send_timeout       600;

    proxy_next_upstream error timeout non_idempotent;
    proxy_next_upstream_timeout 0;
    proxy_next_upstream_tries 3;

    # ---- WebSocket 必需的 map ----
    # 有 Upgrade 头时传 upgrade，没有时传空，避免污染普通请求
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      '';
    }

    # ---- 后端 Rancher 工作节点 ----
    upstream rancher_servers_http {
        least_conn;
        server <10.11.133.94>:80  max_fails=3 fail_timeout=5s;
        server <10.11.133.95>:80  max_fails=3 fail_timeout=5s;
        # ... 按现场补齐
    }

    upstream rancher_servers_https {
        least_conn;
        server <10.11.133.94>:443 max_fails=3 fail_timeout=5s;
        server <10.11.133.95>:443 max_fails=3 fail_timeout=5s;
        # ... 按现场补齐
    }

    # ---- 本机监控/探活端口，仅本地可访问 ----
    server {
        listen 8080;
        allow 127.0.0.1;
        deny all;

        location /nginx_status {
            stub_status on;
            access_log off;
        }

        location /health {
            add_header Content-Type text/plain;
            return 200 "OK\n";
            access_log off;
        }
    }

    # ================================================================
    #  主入口：80 与 443 行为完全一致，不做任何跳转
    #  —— 这是避免重定向循环的核心设计
    # ================================================================
    server {
        listen 80;
        listen 443 ssl default_server;
        server_name _;

        # 学校反代地址，用于还原真实客户端 IP
        # 仅当反代确实透传 XFF 时才生效，否则是空转
        set_real_ip_from <10.11.170.12>;
        real_ip_header   X-Forwarded-For;
        real_ip_recursive on;

        # 内网一跳的自签证书
        ssl_certificate      ssl/internal.pem;
        ssl_certificate_key  ssl/internal.key;
        ssl_session_timeout  5m;
        ssl_protocols        TLSv1.2 TLSv1.3;
        ssl_ciphers          HIGH:!aNULL:!MD5:!3DES:!RC4;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;

            # ★★★ 必须写死，不能用 $scheme / $server_port ★★★
            # 走 80 进来时 $scheme=http，后端会误判协议并发起跳转，
            # 叠加 HSTS 后形成无限循环。详见 7.2 / 7.3
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-Port  443;

            proxy_pass https://rancher_servers_https;
            proxy_http_version 1.1;

            # WebSocket 支持
            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;

            # 入口层安全拦截（可选，按现场需求保留）
            if ($request_uri ~* "swagger-ui.html$") {
                return 403;
            }
        }
    }
}
```

### 若 Host 未被透传

学校反代把 Host 改写成 IP 时，第 3.5 节的探针日志会暴露这一点。此时把 `Host` 写死：

```nginx
proxy_set_header Host portal.xxx.edu.cn;
```

否则后端 ingress 匹配不到对应的 Ingress 规则，会返回默认后端的 404。

---

## 7. 关键技术点与踩坑记录

### 7.1 独立的 80→443 rewrite 块导致死循环

**现象**：浏览器提示"重定向次数过多 / ERR_TOO_MANY_REDIRECTS"。

**问题配置**：

```nginx
server {
    listen 80;
    server_name localhost;
    rewrite ^(.*)$ https://$host$1 permanent;   # ← 罪魁
}
```

**成因**：客户端到学校反代已经是 HTTPS，反代若用 HTTP 回源，请求落到这个 server：

```
浏览器 --https--> 学校反代 --http:80--> 本机 --301 https://域名/--> 浏览器
   ↑                                                                    │
   └────────────────────────────────────────────────────────────────────┘
                          无限循环
```

**为什么改 7 层才暴露**：4 层 stream 配置里 80 是直接 TCP 转发到后端的，没有这条 rewrite。这是"改成 7 层"新引入的问题，不是原有缺陷。

**修复**：删掉该 server 块，让 80 和 443 走同一个 server、行为一致、都不跳转。跳转的事交给学校反代去做（客户端到反代那一跳）。

### 7.2 X-Forwarded-Proto 必须写死，不能用 $scheme

**这是本次改造最核心的一条。**

**问题配置**：

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Port  $server_port;
```

**成因**：`$scheme` 反映的是**学校反代到本机这一跳**的协议，不是客户端实际使用的协议。

| 客户端实际 | 学校反代回源 | `$scheme` 的值 | 后端认为的协议 | 结果 |
|---|---|---|---|---|
| https | https:443 | `https` | https | 正常 |
| https | http:80 | `http` ❌ | http | **后端发起 http→https 跳转，循环** |

后端 ingress-nginx 若开启 `use-forwarded-headers: true`，会直接采信这个头；应用层（Spring Security、CAS 客户端等）也普遍依赖它构造回调地址。传错了，后端就会不断把用户往"正确"的协议上引，而每次请求过来又都是 http，永远引不到位。

**修复**：既然客户端到学校反代恒定是 HTTPS，就写死：

```nginx
proxy_set_header X-Forwarded-Proto https;
proxy_set_header X-Forwarded-Port  443;
```

**排查提示**：如果只在登录环节循环、首页正常，八成是这条。首页往往是静态页不做协议判断，登录/回调链路才做。

### 7.3 HSTS 把隐性循环放大成显性故障

本次现场响应头里带着：

```
Strict-Transport-Security: max-age=15724800; includeSubDomains
```

这会让 7.2 的问题变得**更难排查**：

1. 后端认为是 http，返回 `302 Location: http://portal.xxx.edu.cn/...`
2. 浏览器因为 HSTS，把这个 http 链接**强制升级成 https** 再发一次
3. 请求原样回到后端，后端再次返回 http 跳转
4. → 回到第 1 步，无限循环

**关键干扰点**：整个过程中浏览器地址栏**全程显示 https**，开发者工具里看到的也是 https 请求。那个作为循环起点的 `http://` Location 很容易被忽略。

**排查方法**：必须用 curl 把完整跳转链打出来，看 Location 的**协议头**：

```bash
curl -ksIL https://portal.xxx.edu.cn/ | grep -iE '^HTTP/|^location:'
```

Location 里出现 `http://` → 实锤是 7.2 的问题。

### 7.4 Connection 头写死 "upgrade" 的隐患

**问题配置**：

```nginx
proxy_set_header Connection "upgrade";
```

配置文件上方明明定义了 `map $http_upgrade $connection_upgrade`，却没有使用——这是很常见的复制粘贴遗留。

**影响**：所有**非 WebSocket 的普通 HTTP 请求**也会带上 `Connection: upgrade`。后端可能因此拒绝 keepalive 复用，或在某些代理链路上出现协议协商异常。表现为偶发 502、连接数异常升高。

**修复**：

```nginx
proxy_set_header Connection $connection_upgrade;
```

有 Upgrade 头时传 `upgrade`，没有时传空串，行为正确。

### 7.5 http 模块无法向 upstream 发送 PROXY 协议

**硬约束，无解，只能绕。**

4 层 stream 配置里常见：

```nginx
stream {
    server {
        listen 443;
        proxy_pass rancher_servers_https;
        proxy_protocol on;          # ← 向后端发送 PROXY 协议头
    }
}
```

`proxy_protocol on` 说明后端 ingress-nginx 配置了 `use-proxy-protocol: true`，在等着收 PROXY 头。

**而 Nginx 的 http 模块（7 层）没有任何办法向 upstream 发送 PROXY 协议头**——该指令只存在于 stream 模块。改 7 层后，你发过去的第一行 HTTP 请求会被 ingress 当成 PROXY 头解析，直接失败。

**表现**：400 Bad Request、连接被重置，或 TLS 握手直接失败。**不是重定向循环**——如果你的故障现象是循环，说明问题不在这里。

**处理**：

1. 先确认后端实际状态：`kubectl -n ingress-nginx get cm nginx-configuration -o yaml | grep proxy-protocol`
2. 若为 `true`，且坚持要上 7 层：改 `cluster.yml` 的 `ingress: options:` 段关掉，然后 `rke up`。**注意直接 `kubectl edit cm` 会被 RKE reconciliation 覆盖。**
3. 权衡：为了一个非必需的改造去动生产集群的入口层，风险与收益不成比例。此时应认真考虑维持 4 层。

### 7.6 real_ip 与 XFF 的重复叠加

```nginx
set_real_ip_from 10.11.170.12;
real_ip_header   X-Forwarded-For;
real_ip_recursive on;

proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

`real_ip_header X-Forwarded-For` 会把 `$remote_addr` 替换为 XFF 中解析出的客户端 IP。随后 `$proxy_add_x_forwarded_for`（= 原 XFF + `, ` + `$remote_addr`）会把这个 IP **再追加一次**，后端看到的 XFF 形如：

```
X-Forwarded-For: 1.2.3.4, 1.2.3.4
```

不影响功能（后端取第一个），但日志会有点脏。介意的话可以改成：

```nginx
proxy_set_header X-Forwarded-For $http_x_forwarded_for;
```

即原样透传学校反代给的 XFF，不再追加。

另外：**若学校反代根本不透传 XFF，这三行是完全空转的**，`$remote_addr` 永远是反代设备的 IP，日志失去溯源价值。这种情况需要找信息中心开启 XFF 透传，或提前索要反代设备侧的访问日志对应关系。

### 7.7 TLS 合规基线

原配置：

```nginx
ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
ssl_ciphers   HIGH:!DES:!3DES:!RC4:!MD5:!aNULL:!eNULL:!NULL:!DH:!EDH:!EXP:+MEDIUM;
```

`TLSv1` / `TLSv1.1` 已被主流浏览器弃用，等保测评和漏扫必然点名。`+MEDIUM` 也会把一些弱套件放进来。

**改造时顺手收紧**：

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers   HIGH:!aNULL:!MD5:!3DES:!RC4;
```

反正这一跳只面向学校反代设备，兼容性压力为零，没有理由保留旧协议。

### 7.8 改配置后一定要确认 reload 生效

本次现场排查中一度出现困惑：配置文件里明明有 `rewrite`，`curl` 却返回 200。

**成因**：`nginx -t` 通过 ≠ 新配置已加载。执行了 `nginx -t` 但忘记 `nginx -s reload`，跑的还是内存里的旧配置。

**判定方法**：找一个新旧配置的**差异特征点**去探测。本次用的是 8080 健康检查端口（只存在于 7 层配置里）：

```bash
curl -I http://127.0.0.1:8080/health
# 200 → 7 层配置已加载
# 拒绝 → 还是旧的
```

或者直接看实际加载的配置：

```bash
nginx -T 2>/dev/null | grep -E "^\s*(stream|http)\s*\{"
```

### 7.9 use-forwarded-headers: true 引入的伪造风险

**改 7 层必然要开这个开关，但它是有代价的，不能开完就不管。**

开启后 ingress-nginx 会**无条件采信**请求里的 `X-Forwarded-For` / `X-Forwarded-Proto`，而 `proxy-real-ip-cidr` 默认是 `0.0.0.0/0`——意味着**任何能直连工作节点 443 的来源都可以伪造这两个头**。

后果：

| 伪造项 | 危害 |
|---|---|
| `X-Forwarded-For` | 绕过应用层基于 IP 的访问控制；污染审计日志，事后溯源拿到的是攻击者想让你看到的 IP |
| `X-Forwarded-Proto: https` | 让应用误判为安全连接，可能把 Secure Cookie 下发到明文通道 |

**加固措施**：把可信来源限定为集群外 Nginx。

```yaml
proxy-real-ip-cidr: "<集群外Nginx IP>/32"
```

同时要在网络层确认一件事：**工作节点的 80/443 是否只允许集群外 Nginx 访问**。如果校园网内任意主机都能直连 `10.11.133.x:443`，那么上面这条 CIDR 限制才是真正起作用的那道门；反之如果节点本来就只对 Nginx 开放，风险相对可控，但仍建议显式配置，避免网络策略后续变更时留下敞口。

> 4 层时代不存在这个问题：`proxy_protocol` 头由 TCP 层传递，客户端伪造不了。这是 7 层方案隐含的安全成本，值得在变更评审时说明。

### 7.10 XFF 链的重复叠加

入口 Nginx 传 `$proxy_add_x_forwarded_for`，ingress 又开了 `compute-full-forwarded-for`，再叠加入口侧的 `real_ip_header X-Forwarded-For`，最终应用看到的可能是：

```
X-Forwarded-For: 1.2.3.4, 1.2.3.4, 10.11.170.3
                 ↑客户端  ↑重复    ↑入口Nginx
```

多数框架取链首第一个，无影响。但如果应用按**跳数**解析，或取"最后一个可信 IP"，会拿到错误结果。

排查真实 IP 相关问题时，先把这条链原样打出来看一眼：

```nginx
log_format probe '$remote_addr | xff=[$http_x_forwarded_for]';
```

若确认重复，可把入口侧改为原样透传、不再追加：

```nginx
proxy_set_header X-Forwarded-For $http_x_forwarded_for;
```

---

## 8. 排障命令速查

### 8.1 确认回源端口与协议

```bash
ss -tn state established | grep <学校反代IP>
tcpdump -i any -nn "host <学校反代IP> and (port 80 or port 443)" -c 20
```

### 8.2 本机是否发出跳转

```bash
curl -I  -H "Host: portal.xxx.edu.cn" http://127.0.0.1/
curl -Ik -H "Host: portal.xxx.edu.cn" https://127.0.0.1/
```

两条都应为 200 或后端正常状态码。任一条出现 `301`/`302` + `Location: https://...` → 本机在跳转，回到 7.1。

### 8.3 抓完整跳转链（定位循环源头）

从**能访问域名的机器**执行：

```bash
curl -ksIL https://portal.xxx.edu.cn/ | grep -iE '^HTTP/|^location:'
```

判读：

| Location 特征 | 结论 |
|---|---|
| `http://` 开头 | X-Forwarded-Proto 问题，见 7.2 |
| 域名变了（跳到 CAS 等） | SSO 回跳问题，与 Nginx 无关 |
| 同域名同路径反复 | 后端应用层协议判断错误，仍指向 7.2 |
| 无 Location，直接 200 | 本链路正常，问题在更深的路径 |

### 8.4 定位 301/302 是本机还是后端发的

临时给 `log_format main` 末尾追加：

```nginx
'$status $upstream_status "$sent_http_location"'
```

reload 后复现，然后：

```bash
grep -E ' 30[0-9] ' /var/log/nginx/access.log | tail -50
```

- `$upstream_status` 为空、`$status` 是 30x → **本机 Nginx** 发的
- `$upstream_status` 也是 30x → **后端** 发的，看 `$sent_http_location` 的目标

### 8.5 绕过 Nginx 直测后端

```bash
curl -Ik -H "Host: portal.xxx.edu.cn" https://<工作节点IP>/
```

| 结果 | 含义 |
|---|---|
| 200 / 302 到登录页 | 后端正常，问题在 Nginx 这一层 |
| 400 Bad Request | 大概率 ingress 开着 `use-proxy-protocol`，见 7.5 |
| 连接重置 / 握手失败 | 同上，或 ingress 未监听 443 |
| 404 | Host 没匹配上 Ingress 规则，检查 Host 透传 |

### 8.6 验证自签证书

```bash
# 看证书内容
openssl x509 -in ssl/internal.pem -noout -subject -issuer -dates -ext subjectAltName

# 从外部握手验证（-k 跳过校验，模拟学校反代行为）
openssl s_client -connect 127.0.0.1:443 -servername portal.xxx.edu.cn </dev/null 2>&1 | head -30
```

### 8.7 确认配置已生效

```bash
nginx -T 2>/dev/null | grep -E "^\s*(stream|http)\s*\{"
ss -lntp | grep nginx
curl -I http://127.0.0.1:8080/health
```

### 8.8 后端节点健康状态

```bash
# 后端摘除时 error log 会有 upstream 相关记录
grep -i "upstream" /var/log/nginx/error.log | tail -30

# 逐个探测后端节点
for ip in 10.11.133.{94,95,96,98,99}; do
  echo -n "$ip: "
  curl -sk -o /dev/null -w "%{http_code} %{time_total}s\n" \
       -H "Host: portal.xxx.edu.cn" --max-time 5 https://$ip/
done
```

---

## 9. 上线验证清单

按顺序执行，全部通过才算完成。

### 9.1 服务层

- [ ] `nginx -t` 语法校验通过
- [ ] `ss -lntp | grep nginx` 显示 80、443、8080 均在监听
- [ ] `curl -I http://127.0.0.1:8080/health` 返回 200
- [ ] `nginx -T` 确认加载的是新配置（有 http 块，无遗留 rewrite server）

### 9.2 本机代理层

- [ ] `curl -I -H "Host: <域名>" http://127.0.0.1/` 返回 200，**无 Location 头**
- [ ] `curl -Ik -H "Host: <域名>" https://127.0.0.1/` 返回 200，**无 Location 头**
- [ ] `openssl s_client` 握手成功，证书 CN/SAN 与域名一致

### 9.3 端到端

- [ ] `curl -ksIL https://<域名>/` 跳转链中**无 `http://` 开头的 Location**
- [ ] 浏览器打开首页正常，无"重定向次数过多"
- [ ] **完整走一遍登录流程**（首页正常≠登录正常，见 7.2 排查提示）
- [ ] 登录后页面刷新、跳转正常，无反复回到登录页
- [ ] 浏览器控制台无 Mixed Content 告警

### 9.4 功能层

- [ ] Rancher UI 集群列表状态**正常刷新**（WebSocket 是否通的最直接信号）
- [ ] 业务系统中的实时刷新/推送功能正常
- [ ] 大文件上传正常（验证 `client_max_body_size 500m`）
- [ ] 每一个承载的业务域名逐个访问确认（多域名场景必做，不能只测一个）

### 9.5 日志与合规

- [ ] `access.log` 中 `$remote_addr` 是真实客户端 IP，不是反代设备 IP
- [ ] 30x 状态码占比在正常范围，无异常堆积
- [ ] `error.log` 无持续报错
- [ ] 漏扫/等保工具复扫，TLS 协议版本项通过

### 9.6 观察期

- [ ] 变更后持续观察 30 分钟，`error.log` 无新增异常
- [ ] 次日复查前一日日志，确认无夜间批处理类业务受影响

---

## 10. 回退方案

### 10.1 回退触发条件

出现以下任一情况，**立即回退，不要在生产上继续调试**：

- 业务域名大面积无法访问
- 重定向循环在 15 分钟内未定位到根因
- 后端 ingress 出现大量 400/502

### 10.2 回退操作

```bash
cd /usr/local/nginx/conf
cp -a nginx.conf.bak.<时间戳> nginx.conf
nginx -t && nginx -s reload

# 确认恢复
ss -lntp | grep nginx
diff <(ss -lntp | grep nginx) /tmp/nginx_listen_before.txt
curl -ksIL https://<域名>/ | grep -iE '^HTTP/|^location:'
```

回退耗时通常 < 1 分钟。

### 10.3 回退后的再决策

回退成功后，重新走 [第 3 节](#3-前置信息采集必做) 采集缺失信息，特别是：

- 后端 ingress 的 `use-proxy-protocol` 真实状态
- 该入口承载的域名清单及各自的跳转策略

**如果原配置是 4 层且工作正常，认真评估"是否真的需要改 7 层"**。学校收回证书对 4 层没有任何影响，改造的驱动力应该来自其他明确需求（入口层拦截、统一日志等），而不是"证书没了"。

### 10.4 4 层需求的替代实现

若最终决定维持 4 层，原计划在 7 层做的事可以这样落地：

| 需求 | 4 层下的替代方案 |
|---|---|
| swagger-ui 等 URL 拦截 | 下沉到 ingress，用 `nginx.ingress.kubernetes.io/server-snippet` 注解；或让开发在生产 profile 关闭 swagger |
| 真实客户端 IP | `proxy_protocol on` + ingress 的 `use-proxy-protocol: true` |
| 访问日志 | 看 ingress-controller 的 Pod 日志 |
| 连接级可观测性 | stream 块支持 `access_log`，可记录 `$remote_addr $upstream_addr $status $bytes_sent $session_time` |

---

## 11. 遗留与待核实事项

以下问题在本次现场未完全闭环，**其他现场实施前建议明确**：

### 11.1 proxy_protocol 疑问 —— 已闭环 ✅

**原疑问**：原 4 层配置带 `proxy_protocol on`，理论上要求后端 `use-proxy-protocol: true`；但改成 7 层后（7 层发不出 PROXY 头）业务同样正常，逻辑上不应同时成立。

**结论**：切换 7 层时**同步调整了 ingress-nginx 配置映射**——移除 `use-proxy-protocol: true`，改为 `use-forwarded-headers: true` + `compute-full-forwarded-for: true`。两侧是配套变更，不存在矛盾。详见 [4.4](#44-集群内-ingress-侧配套改造必做)。

**给其他现场的提示**：这条经验不能只抄一半。看到原配置带 `proxy_protocol on`，就一定要连带改 ingress ConfigMap，否则 7 层入口根本连不通——**表现为 400 / 握手失败，不是重定向循环**。

### 11.2 cluster.yml 是否已同步（待确认）

ConfigMap 的改动是否已落到 `cluster.yml` 的 `rke_config.ingress.options`，本次未确认。

**风险**：若 `use-proxy-protocol: "true"` 仍留在 `cluster.yml`，下次集群编辑 / `rke up` 会把它写回运行配置，7 层入口瞬间全挂。而且距离本次变更时间越久，越不会有人往这个方向联想。

**建议动作**（优先级最高）：

```bash
# 确认运行态
kubectl -n ingress-nginx get cm nginx-configuration -o yaml | grep -iE "proxy-protocol|forwarded"
```

然后去 Rancher UI：集群 → 编辑配置 → Edit as YAML，检查 `rke_config.ingress.options` 段，确保：

- `use-proxy-protocol` **已移除**
- `use-forwarded-headers` / `compute-full-forwarded-for` **已写入**

### 11.3 proxy-real-ip-cidr 未限定（待加固）

当前保持默认 `0.0.0.0/0`，配合 `use-forwarded-headers: true` 存在 XFF/XFP 伪造风险，详见 [7.9](#79-use-forwarded-headers-true-引入的伪造风险)。

**建议动作**：限定为集群外 Nginx 的 `/32`，并同步写入 `cluster.yml`。同时核查工作节点 80/443 的网络访问范围。

### 11.4 XFF 透传情况未确认

`set_real_ip_from 10.11.170.12` 已配置，但未验证学校反代是否真的透传 XFF。若未透传，该配置为空转、日志中拿不到真实客户端 IP。

**建议动作**：查一次访问日志，确认 `$remote_addr` 是否为真实客户端 IP 而非 `10.11.170.12`。

### 11.5 自签证书的到期管理

`-days 3650` 到期时间较远，容易被遗忘。建议登记到证书台账，或加一条监控：

```bash
openssl x509 -in /usr/local/nginx/conf/ssl/internal.pem -noout -checkend $((86400*30)) \
  || echo "internal cert expires within 30 days"
```

### 11.6 单点问题

集群外 Nginx 目前是单节点。入口层单点故障会导致全部业务不可用。建议后续评估 keepalived + VIP 双机，或由学校反代侧配置多个源站地址做健康检查。

---

## 附录 A：本次现场实施记录

### A.1 现场信息

| 项 | 值 |
|---|---|
| 现场 | shufe-zj |
| 域名 | `portal.shufe-zj.edu.cn` |
| 学校反代 | `10.11.170.12` |
| 集群外 Nginx | `10.11.170.3`（CentOS 7.9） |
| 回源协议/端口 | HTTPS / 443（抓包实测确认） |
| 反代是否校验源站证书 | 否（自签证书握手成功） |
| 后端工作节点 | `10.11.133.94/95/96/98/99/117/118/119/120/121/133`（`.97` 已注释停用） |
| 改造前形态 | 4 层 stream，80/443 均 `proxy_pass` + `proxy_protocol on` |
| 改造后形态 | 7 层 http，80/443 同 server 双监听 + 自签证书 |
| ingress ConfigMap（4 层时） | `use-proxy-protocol: "true"` |
| ingress ConfigMap（7 层时） | `use-forwarded-headers: "true"`、`compute-full-forwarded-for: "true"` |

### A.2 时间线与关键节点

| 阶段 | 动作 | 结果 |
|---|---|---|
| 1 | 收到学校通知，确认不再提供证书 | — |
| 2 | 4 层 stream 改为 7 层 http + 自签证书 | ❌ 全部业务域名"重定向次数过多" |
| 3 | 抓包确认回源端口 | ✅ 确认为 443，且反代不校验证书 |
| 4 | 本机 curl 自测 80/443 | 均返回 200，确认循环不由本机 301 引起 |
| 5 | 一度回退至 4 层保业务 | ✅ 业务恢复 |
| 6 | 修正 7 层配置（四条核心动作）后再次上线 | ✅ **访问正常，改造完成** |

### A.3 最终生效的核心修改点

```diff
- server {
-       listen 80 ;
-       server_name localhost;
-       rewrite ^(.*)$ https://$host$1 permanent;
- }
-
  server {
-     listen 443 default_server ssl;
-     server_name localhost;
+     listen 80;
+     listen 443 ssl default_server;
+     server_name _;

-     ssl_protocols  TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
-     ssl_ciphers  HIGH:!DES:!3DES:!RC4:!MD5:!aNULL:!eNULL:!NULL:!DH:!EDH:!EXP:+MEDIUM;
+     ssl_protocols  TLSv1.2 TLSv1.3;
+     ssl_ciphers    HIGH:!aNULL:!MD5:!3DES:!RC4;

      location / {
-         proxy_set_header X-Forwarded-Proto $scheme;
-         proxy_set_header X-Forwarded-Port  $server_port;
+         proxy_set_header X-Forwarded-Proto https;
+         proxy_set_header X-Forwarded-Port  443;

-         proxy_set_header Connection "upgrade";
+         proxy_set_header Connection $connection_upgrade;
      }
  }
```

### A.4 经验总结

1. **先采集，再动手。** 回源端口一次 tcpdump 就能确认，比反复问信息中心快得多，而且准确。同一次抓包还顺带验证了"反代不校验源站证书"。
2. **"重定向太多"要看 Location 的协议头。** HSTS 会把 `http://` 的 Location 悄悄升级成 https，导致地址栏全程显示 https，极具迷惑性。必须 `curl -ksIL` 打出完整链路。
3. **`$scheme` 在多级代理下不可信。** 它只反映相邻一跳的协议。客户端协议恒定时，直接写死最稳妥。
4. **首页正常 ≠ 改造成功。** 静态首页往往不做协议判断，登录/回调链路才会暴露 XFP 问题。验证必须走完整登录流程。
5. **`nginx -t` 通过 ≠ 配置已加载。** 用新旧配置的差异特征点（如 8080 端口）去探测实际生效状态。
6. **4 层现场先别急着改。** 它不终结 TLS，学校收回证书对它零影响。改造应由明确的功能需求驱动。

---

## 附录 B：配置变更 diff

完整的改造前后对照，可直接用于变更单附件。

### B.1 删除的内容

```nginx
# 删除：独立的 80→443 跳转 server（重定向循环根源）
server {
      listen 80 ;
      #listen [::]:80 ipv6only=on;
      server_name localhost;
      rewrite ^(.*)$ https://$host$1 permanent;
}
```

### B.2 修改的内容

| 配置项 | 改造前 | 改造后 | 依据 |
|---|---|---|---|
| `listen` | `443 default_server ssl` | `80` + `443 ssl default_server` | 7.1 |
| `server_name` | `localhost` | `_` | 语义 |
| `ssl_certificate` | `ssl/zjcm.edu.cn.pem` | `ssl/internal.pem` | 1.2 |
| `ssl_certificate_key` | `ssl/zjcm.edu.cn.key` | `ssl/internal.key` | 1.2 |
| `ssl_protocols` | 含 `TLSv1 TLSv1.1` | `TLSv1.2 TLSv1.3` | 7.7 |
| `ssl_ciphers` | 含 `+MEDIUM` | `HIGH:!aNULL:!MD5:!3DES:!RC4` | 7.7 |
| `X-Forwarded-Proto` | `$scheme` | `https`（写死） | 7.2 |
| `X-Forwarded-Port` | `$server_port` | `443`（写死） | 7.2 |
| `Connection` | `"upgrade"` | `$connection_upgrade` | 7.4 |

### B.3 新增的内容

```nginx
# 新增：还原真实客户端 IP（需确认学校反代确实透传 XFF）
set_real_ip_from <学校反代IP>;
real_ip_header   X-Forwarded-For;
real_ip_recursive on;
```

### B.4 保持不变的内容

- `worker_*`、`events` 段全部性能参数
- `gzip` 相关配置
- `proxy_buffer*` / `proxy_*_timeout` / `proxy_next_upstream` 相关配置
- `upstream rancher_servers_http` / `rancher_servers_https` 后端列表
- `listen 8080` 的监控/健康检查 server 块
- `swagger-ui.html` 的 403 拦截规则

---

**文档结束**

> 实施过程中遇到本文未覆盖的情况，建议补充到第 7 节和附录 A，保持文档随现场演进。
