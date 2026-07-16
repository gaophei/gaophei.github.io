# Rancher / Nginx / WAF 场景下 Java 微服务 SSL 证书链错误排查文档

## 1. 文档目的

本文档用于指导现场排查以下类型问题：

```text
Nginx / Rancher / Ingress 中 SSL 证书已经更换；
Kubernetes 微服务仍然报 SSL 证书错误；
Java 应用日志中出现 PKIX path building failed；
浏览器或部分入口访问看起来正常，但 Pod 内 Java 客户端访问 HTTPS 地址失败。
```

本文结合本次现场实际问题整理，包含：

```text
1. 问题现象；
2. 现场链路；
3. 关键日志；
4. 证书链排查命令；
5. Rancher / Kubernetes TLS Secret 检查；
6. 后端入口直连验证；
7. 最终根因判断；
8. 学校侧安全设备 / WAF 修复说明；
9. CoreDNS 内部解析覆盖的临时绕过方案；
10. 回滚方法；
11. 现场快速命令汇总。
```

------

## 2. 问题现象

业务系统部署在 Rancher / Kubernetes 中。
Nginx 和 Rancher 负载均衡中的 SSL 证书已经更换，但 Rancher 中的 Java 微服务仍然报证书错误。

应用日志中出现类似错误：

```log
javax.net.ssl.SSLHandshakeException: PKIX path building failed:
sun.security.provider.certpath.SunCertPathBuilderException:
unable to find valid certification path to requested target
```

也可能出现如下业务异常：

```log
javax.imageio.IIOException: Can't get input stream from URL!

https://newcas.sjzc.edu.cn/cas/file/png/iconImageUrl

Caused by: javax.net.ssl.SSLHandshakeException:
PKIX path building failed:
sun.security.provider.certpath.SunCertPathBuilderException:
unable to find valid certification path to requested target
```

本次现场中，CAS 服务访问如下地址时报错：

```text
https://newcas.sjzc.edu.cn/cas/file/png/iconImageUrl
```

日志中还出现 CAS / OAuth / pac4j 相关调用链：

```log
org.jasig.cas.client.validation.AbstractUrlBasedTicketValidator.validate
org.pac4j.cas.credentials.authenticator.CasAuthenticator.validate
org.apereo.cas.support.oauth.web.endpoints.OAuth20CallbackAuthorizeEndpointController.handleRequest
```

这说明问题发生在：

```text
Java 应用作为 HTTPS 客户端主动访问 newcas.sjzc.edu.cn 时。
```

不是单纯的浏览器访问入口问题。

------

## 3. 关键错误解释

### 3.1 PKIX path building failed 是什么

Java 报错：

```text
PKIX path building failed
unable to find valid certification path to requested target
```

通常表示：

```text
Java 客户端收到了服务端证书，
但无法根据当前信任库构建一条完整可信的证书链。
```

常见原因：

```text
1. 服务端只返回站点证书，未返回中间证书；
2. 服务端证书链顺序错误；
3. Java truststore 中缺少根证书或中间证书；
4. 链路中的 WAF / 安全设备 / SSL 代理替换了证书；
5. Pod 内访问的入口和预期入口不是同一个；
6. DNS 解析到了另一层反代或安全设备。
```

------

## 4. 本次现场链路

本次现场域名：

```text
newcas.sjzc.edu.cn
```

Pod 内解析结果：

```bash
java-app@cas-server-webapp-9df49c947-fdhx6:/home/java-app$ getent hosts newcas.sjzc.edu.cn
192.168.41.95   newcas.sjzc.edu.cn
```

现场链路表现为：

```text
cas-server-webapp Pod
  ↓
访问 newcas.sjzc.edu.cn
  ↓ DNS 解析
192.168.41.95  学校侧入口地址
  ↓
学校侧安全设备 / WAF / SSL 检测设备
  ↓
192.168.51.20  我方 Rancher / Nginx / Ingress 入口
  ↓
cas-server 服务
```

后续学校侧最终确认：

```text
问题并不是 192.168.41.95 普通反代本身；
而是学校侧链路中的安全设备 / WAF / SSL 代理设备上的证书配置问题。
```

该设备对 `newcas.sjzc.edu.cn` 做了 HTTPS 终止、SSL 检测或证书代理，但设备上配置的证书链不完整。

------

## 5. 最终根因

最终根因：

```text
学校侧安全设备 / WAF / SSL 检测设备对 newcas.sjzc.edu.cn 做了 HTTPS 终止或证书代理，
但该设备上配置的服务端证书链不完整，只返回站点证书，未返回中间证书链，
导致 Java 客户端无法构建可信证书链，从而触发 PKIX path building failed。
```

不是以下问题：

```text
1. 不是我方 Rancher TLS Secret 配置错误；
2. 不是我方 192.168.51.20 入口证书链配置错误；
3. 不是证书域名不匹配；
4. 不是 key 和证书不匹配；
5. 不是业务代码本身优先导致。
```

本次现场验证结果：

| 检查对象                            | 结果                               | 判断     |
| ----------------------------------- | ---------------------------------- | -------- |
| `cas-server` 命名空间 TLS Secret    | 3 段证书                           | 正常     |
| 直连我方入口 `192.168.51.20:443`    | 3 段证书，`Verify return code: 0`  | 正常     |
| Pod 内访问 `newcas.sjzc.edu.cn:443` | 1 段证书，`Verify return code: 20` | 异常     |
| 学校侧最终确认                      | 安全设备 / WAF 证书链问题          | 根因确认 |

------

## 6. 排查过程

### 6.1 查看应用日志是否存在 PKIX 报错

执行：

```bash
kubectl -n cas-server logs deploy/cas-server-webapp --tail=500 | egrep -i "SSLHandshakeException|PKIX|valid certification path|unable to find"
```

典型异常：

```log
javax.net.ssl.SSLHandshakeException: PKIX path building failed
sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
```

如果存在该异常，说明 Java 客户端 SSL 证书链校验失败。

------

### 6.2 进入报错 Pod

查询 Pod：

```bash
kubectl -n cas-server get pod -o wide
```

进入 Pod：

```bash
kubectl -n cas-server exec -it cas-server-webapp-9df49c947-fdhx6 -- sh
```

本次现场 Pod：

```text
cas-server-webapp-9df49c947-fdhx6
```

------

### 6.3 查看 Pod 内域名解析结果

在 Pod 内执行：

```bash
getent hosts newcas.sjzc.edu.cn
```

本次现场输出：

```bash
java-app@cas-server-webapp-9df49c947-fdhx6:/home/java-app$ getent hosts newcas.sjzc.edu.cn
192.168.41.95   newcas.sjzc.edu.cn
```

判断：

```text
Pod 内访问 newcas.sjzc.edu.cn 时，实际访问的是 192.168.41.95。
因此不能只检查 Rancher / Ingress Secret，还要检查 192.168.41.95 及其链路上的安全设备实际返回的证书。
```

------

### 6.4 检查 Pod 内访问域名时返回几段证书

在 Pod 内执行：

```bash
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
```

本次现场输出：

```bash
java-app@cas-server-webapp-9df49c947-fdhx6:/home/java-app$ echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
1
```

判断：

```text
服务端只返回 1 段证书，即只返回站点证书；
没有返回完整的中间证书链。
```

正常建议至少返回：

```text
2
```

更完整时可能返回：

```text
3
```

常见证书链顺序：

```text
第 1 段：站点证书
第 2 段：中间证书
第 3 段：根证书，可选
```

------

### 6.5 检查 Pod 内访问域名时证书校验结果

在 Pod 内执行：

```bash
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts -verify_return_error 2>&1 | egrep 'subject=|issuer=|Verify return code'
```

本次现场输出：

```bash
Verify return code: 20 (unable to get local issuer certificate)
```

判断：

```text
Verify return code: 20 表示客户端无法找到本地可信的上级签发证书。
在本场景中，核心原因是服务端链路只返回站点证书，缺少中间证书链。
```

正常应为：

```text
Verify return code: 0 (ok)
```

------

### 6.6 使用 curl 验证 HTTPS 访问现象

在 Pod 内执行：

```bash
curl -vkI https://newcas.sjzc.edu.cn/cas/file/png/iconImageUrl
```

本次现场输出关键信息：

```log
*   Trying 192.168.41.95:443...
* Connected to newcas.sjzc.edu.cn (192.168.41.95) port 443 (#0)

* Server certificate:
*  subject: C=CN; ST=\U6CB3\U5317\U7701; L=\U77F3\U5BB6\U5E84\U5E02; O=\U77F3\U5BB6\U5E84\U5B66\U9662; CN=*.sjzc.edu.cn
*  start date: Jul 15 01:35:32 2026 GMT
*  expire date: Jan 30 01:35:31 2027 GMT
*  issuer: C=CN; O=Beijing Xinchacha Credit Management Co., Ltd.; CN=Xcc Trust OV SSL CA
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.

HTTP/1.1 200
```

说明：

```text
1. 网络访问是通的；
2. HTTP 响应可以返回 200；
3. 但证书链校验失败；
4. curl 使用 -k 参数会忽略证书错误继续访问；
5. Java 默认不会忽略证书错误，所以 Java 报 PKIX。
```

------

## 7. 检查 Kubernetes TLS Secret

### 7.1 导出 Secret 中的证书

在 Kubernetes 管理节点执行：

```bash
kubectl -n cas-server get secret 2026-2027 \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/tls1.crt
```

检查证书段数：

```bash
grep -c 'BEGIN CERTIFICATE' /tmp/tls1.crt
```

本次现场输出：

```bash
[root@docker01 ~]# kubectl -n cas-server get secret 2026-2027 \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/tls1.crt

[root@docker01 ~]# grep -c 'BEGIN CERTIFICATE' /tmp/tls1.crt
3
```

判断：

```text
cas-server 命名空间下的 TLS Secret 中包含 3 段证书；
Rancher / Kubernetes Secret 配置正常。
```

------

### 7.2 查看 Secret 证书内容

可执行：

```bash
openssl crl2pkcs7 -nocrl -certfile /tmp/tls1.crt | \
  openssl pkcs7 -print_certs -noout | egrep "subject=|issuer="
```

也可以逐段拆分：

```bash
awk 'BEGIN{c=0}/BEGIN CERTIFICATE/{c++; fn=sprintf("/tmp/secret-cert%d.pem",c)}{print > fn}' /tmp/tls1.crt
```

查看每段证书：

```bash
for f in /tmp/secret-cert*.pem; do
  echo "===== $f ====="
  openssl x509 -in "$f" -noout -subject -issuer -dates
done
```

------

## 8. 直连我方入口 192.168.51.20 验证

因为我方入口为：

```text
192.168.51.20
```

需要从 Pod 内绕过学校侧入口，直接访问我方入口验证证书链。

### 8.1 检查证书段数

在 Pod 内执行：

```bash
echo | openssl s_client \
  -connect 192.168.51.20:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
```

本次现场输出：

```bash
java-app@cas-server-webapp-9df49c947-fdhx6:/home/java-app$ echo | openssl s_client \
  -connect 192.168.51.20:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
3
```

判断：

```text
我方入口 192.168.51.20 返回 3 段证书，证书链完整。
```

------

### 8.2 检查证书校验结果

在 Pod 内执行：

```bash
echo | openssl s_client \
  -connect 192.168.51.20:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts -verify_return_error 2>&1 | egrep 'subject=|issuer=|Verify return code'
```

本次现场输出：

```bash
java-app@cas-server-webapp-9df49c947-fdhx6:/home/java-app$ echo | openssl s_client \
  -connect 192.168.51.20:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts -verify_return_error 2>&1 | egrep 'subject=|issuer=|Verify return code'

subject=C = CN, ST = \E6\B2\B3\E5\8C\97\E7\9C\81, L = \E7\9F\B3\E5\AE\B6\E5\BA\84\E5\B8\82, O = \E7\9F\B3\E5\AE\B6\E5\BA\84\E5\AD\A6\E9\99\A2, CN = *.sjzc.edu.cn
issuer=C = CN, O = "Beijing Xinchacha Credit Management Co., Ltd.", CN = Xcc Trust OV SSL CA
Verify return code: 0 (ok)
```

判断：

```text
我方入口 192.168.51.20 的 SSL 证书链正常；
不是我方 Rancher / Nginx / Ingress 证书配置问题。
```

------

## 9. 关键对比结论

| 访问方式                                       | 证书段数 | 校验结果                 | 说明 |
| ---------------------------------------------- | -------- | ------------------------ | ---- |
| `newcas.sjzc.edu.cn:443`                       | 1        | `Verify return code: 20` | 异常 |
| `192.168.51.20:443` + SNI `newcas.sjzc.edu.cn` | 3        | `Verify return code: 0`  | 正常 |
| K8s Secret `2026-2027`                         | 3        | 配置完整                 | 正常 |

因此可判断：

```text
Pod 访问域名时，实际链路中有学校侧安全设备 / WAF / SSL 代理层参与；
该设备返回的证书链不完整。
```

------

## 10. 正式修复方案

### 10.1 学校侧安全设备 / WAF 修复证书链

学校侧需要在安全设备 / WAF / SSL 检测设备上，重新配置 `newcas.sjzc.edu.cn` 的完整证书链。

完整证书链应包含：

```text
第 1 段：*.sjzc.edu.cn 站点证书
第 2 段：Xcc Trust OV SSL CA 中间证书
第 3 段：Certum Trusted Network CA 根证书
```

证书文件顺序应为：

```text
站点证书 -> 中间证书 -> 根证书
```

如果安全设备只要求上传站点证书和中间证书，则至少应上传：

```text
站点证书 -> 中间证书
```

根证书是否需要上传，取决于设备要求。

------

### 10.2 修复后验证

学校侧修复后，在业务 Pod 内重新执行：

```bash
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
```

期望输出：

```text
2
```

或：

```text
3
```

继续执行：

```bash
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts -verify_return_error 2>&1 | egrep 'subject=|issuer=|Verify return code'
```

期望输出：

```text
Verify return code: 0 (ok)
```

检查应用日志：

```bash
kubectl -n cas-server logs deploy/cas-server-webapp --tail=500 | egrep -i "SSLHandshakeException|PKIX|valid certification path|unable to find"
```

如果没有新的相关输出，说明 SSL 证书链问题已解决。

------

## 11. 临时绕过方案一：CoreDNS 内部解析覆盖

### 11.1 方案说明

如果学校侧安全设备 / WAF 暂时不能立即修复，可以临时通过 CoreDNS 让 Kubernetes 集群内部 Pod 访问：

```text
newcas.sjzc.edu.cn
```

时直接解析到我方证书链正常的入口：

```text
192.168.51.20
```

即：

```text
newcas.sjzc.edu.cn -> 192.168.51.20
```

这样可以让集群内部 Java 应用绕过学校侧证书链异常的安全设备。

注意：

```text
1. 该方案只影响 Kubernetes 集群内部 Pod；
2. 不影响外部用户、浏览器、学校办公网 DNS 解析；
3. 所有使用集群 CoreDNS 的 Pod 访问 newcas.sjzc.edu.cn 都会解析到 192.168.51.20；
4. 这是临时绕过方案，不替代学校侧安全设备正式修复；
5. 需要确认 Pod 网段可以直接访问 192.168.51.20:443。
```

------

### 11.2 查看 CoreDNS ConfigMap

先确认 CoreDNS ConfigMap 所在位置：

```bash
kubectl get cm -A | grep -i coredns
```

常见输出：

```text
kube-system   coredns
```

查看当前 CoreDNS 配置：

```bash
kubectl -n kube-system get configmap coredns -o yaml
```

只查看 Corefile：

```bash
kubectl -n kube-system get configmap coredns \
  -o jsonpath='{.data.Corefile}'
```

------

### 11.3 修改前备份 CoreDNS

修改前必须备份：

```bash
kubectl -n kube-system get configmap coredns -o yaml > coredns-cm-backup-$(date +%F-%H%M%S).yaml
```

确认备份文件：

```bash
ls -lh coredns-cm-backup-*.yaml
```

------

### 11.4 编辑 CoreDNS ConfigMap

执行：

```bash
kubectl -n kube-system edit configmap coredns
```

找到类似配置：

```yaml
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

在 `forward . /etc/resolv.conf` 前增加 `hosts` 插件配置：

```yaml
data:
  Corefile: |
    .:53 {
        errors
        health
        ready

        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
        }

        prometheus :9153

        hosts {
            192.168.51.20 newcas.sjzc.edu.cn
            fallthrough
        }

        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

核心配置：

```coredns
hosts {
    192.168.51.20 newcas.sjzc.edu.cn
    fallthrough
}
```

含义：

```text
192.168.51.20 newcas.sjzc.edu.cn
```

表示集群内访问 `newcas.sjzc.edu.cn` 时，CoreDNS 直接返回 `192.168.51.20`。

```text
fallthrough
```

表示未在 hosts 中命中的其他域名继续走后面的正常 DNS 解析流程。

建议放置位置：

```text
kubernetes 插件之后；
forward 插件之前。
```

------

### 11.5 完整 CoreDNS 示例

如果现场 CoreDNS 为常见配置，可以参考如下完整示例。

注意：不要盲目整体替换，应结合现场原 Corefile，只增加 `hosts` 部分。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors

        health {
            lameduck 5s
        }

        ready

        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }

        prometheus :9153

        hosts {
            192.168.51.20 newcas.sjzc.edu.cn
            fallthrough
        }

        forward . /etc/resolv.conf {
            max_concurrent 1000
        }

        cache 30
        loop
        reload
        loadbalance
    }
```

------

### 11.6 重启 CoreDNS

修改后，CoreDNS 通常支持自动 reload，但现场建议主动重启：

```bash
kubectl -n kube-system rollout restart deployment coredns
```

查看 rollout 状态：

```bash
kubectl -n kube-system rollout status deployment coredns
```

查看 CoreDNS Pod：

```bash
kubectl -n kube-system get pod | grep -i coredns
```

如果环境中 CoreDNS 标签为 `k8s-app=kube-dns`，也可以执行：

```bash
kubectl -n kube-system get pod -l k8s-app=kube-dns -o wide
```

------

### 11.7 验证 CoreDNS 解析是否生效

进入业务 Pod：

```bash
kubectl -n cas-server exec -it cas-server-webapp-9df49c947-fdhx6 -- sh
```

执行：

```bash
getent hosts newcas.sjzc.edu.cn
```

期望输出：

```text
192.168.51.20   newcas.sjzc.edu.cn
```

也可以执行：

```bash
nslookup newcas.sjzc.edu.cn
```

期望输出类似：

```text
Name:      newcas.sjzc.edu.cn
Address:   192.168.51.20
```

如果 Pod 内没有 `nslookup`，使用 `getent hosts` 即可。

------

### 11.8 用临时 Pod 验证 DNS

可以临时启动 busybox 验证：

```bash
kubectl run dns-test \
  --image=busybox:1.36 \
  --restart=Never \
  --rm -it \
  -- nslookup newcas.sjzc.edu.cn
```

期望输出：

```text
Name:      newcas.sjzc.edu.cn
Address 1: 192.168.51.20
```

如果现场无法拉取镜像，可直接在已有业务 Pod 内执行 `getent hosts`。

------

### 11.9 验证 SSL 证书链

CoreDNS 解析覆盖生效后，在业务 Pod 内执行：

```bash
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
```

期望输出：

```text
3
```

继续验证：

```bash
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts -verify_return_error 2>&1 | egrep 'subject=|issuer=|Verify return code'
```

期望输出：

```text
Verify return code: 0 (ok)
```

------

### 11.10 重启业务服务

如果业务应用中存在 DNS 缓存，建议重启业务 Deployment：

```bash
kubectl -n cas-server rollout restart deploy cas-server-webapp
```

查看状态：

```bash
kubectl -n cas-server rollout status deploy cas-server-webapp
```

查看日志是否仍有 SSL 错误：

```bash
kubectl -n cas-server logs deploy/cas-server-webapp --tail=500 | egrep -i "SSLHandshakeException|PKIX|valid certification path|unable to find"
```

如果无输出，说明临时绕过已生效。

------

### 11.11 CoreDNS 方案回滚

如果 CoreDNS 修改后出现异常，使用备份文件回滚。

查看备份文件：

```bash
ls -lh coredns-cm-backup-*.yaml
```

回滚：

```bash
kubectl apply -f coredns-cm-backup-2026-07-16-103000.yaml
```

重启 CoreDNS：

```bash
kubectl -n kube-system rollout restart deployment coredns
```

验证 CoreDNS Pod：

```bash
kubectl -n kube-system get pod | grep -i coredns
```

验证域名解析是否恢复：

```bash
kubectl -n cas-server exec -it cas-server-webapp-9df49c947-fdhx6 -- getent hosts newcas.sjzc.edu.cn
```

------

## 12. 临时绕过方案二：Deployment hostAliases

如果只想影响某一个业务服务，不想改全局 CoreDNS，可以给对应 Deployment 添加 `hostAliases`。

### 12.1 配置示例

在 `cas-server-webapp` Deployment 的 Pod template 中增加：

```yaml
spec:
  template:
    spec:
      hostAliases:
      - ip: "192.168.51.20"
        hostnames:
        - "newcas.sjzc.edu.cn"
```

完整片段示例：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cas-server-webapp
  namespace: cas-server
spec:
  template:
    spec:
      hostAliases:
      - ip: "192.168.51.20"
        hostnames:
        - "newcas.sjzc.edu.cn"
      containers:
      - name: cas-server-webapp
        image: <your-image>
```

------

### 12.2 使用 kubectl edit 修改

执行：

```bash
kubectl -n cas-server edit deploy cas-server-webapp
```

在：

```yaml
spec:
  template:
    spec:
```

下面增加：

```yaml
      hostAliases:
      - ip: "192.168.51.20"
        hostnames:
        - "newcas.sjzc.edu.cn"
```

保存后，Deployment 会自动滚动更新。

查看状态：

```bash
kubectl -n cas-server rollout status deploy cas-server-webapp
```

验证：

```bash
kubectl -n cas-server exec -it <new-pod-name> -- getent hosts newcas.sjzc.edu.cn
```

期望输出：

```text
192.168.51.20   newcas.sjzc.edu.cn
```

------

### 12.3 hostAliases 与 CoreDNS 对比

| 方案            | 影响范围              | 优点       | 缺点               |
| --------------- | --------------------- | ---------- | ------------------ |
| CoreDNS 覆盖    | 集群内所有 Pod        | 统一生效   | 影响范围大         |
| hostAliases     | 单个 Deployment / Pod | 影响范围小 | 多服务需要分别配置 |
| 修复 WAF 证书链 | 全链路                | 根本解决   | 需要学校侧配合     |

建议：

```text
1. 单个服务急救：优先 hostAliases；
2. 多个服务都需要访问该域名：可临时使用 CoreDNS；
3. 最终必须修复学校侧安全设备 / WAF 证书链。
```

------

## 13. 不推荐长期使用的方案：导入 Java cacerts

也可以把中间证书和根证书导入 Java truststore：

```bash
keytool -importcert -noprompt \
  -trustcacerts \
  -alias xcc-trust-ov-ssl-ca \
  -file cert2.pem \
  -keystore $JAVA_HOME/jre/lib/security/cacerts \
  -storepass changeit
```

但不推荐作为长期方案，原因：

```text
1. 只解决当前 Java 容器，不解决服务端证书链不完整的问题；
2. Pod 重建后如果镜像未固化，手工修改会丢失；
3. 其他服务、其他客户端仍可能报证书链错误；
4. 本次根因在学校侧安全设备 / WAF，不应通过修改所有客户端来规避。
```

------

## 14. 给学校侧安全设备 / WAF 管理员的沟通模板

```text
目前 newcas.sjzc.edu.cn 在业务 Pod 内解析到 192.168.41.95。我们从 Pod 内使用 openssl 检查发现，访问 newcas.sjzc.edu.cn:443 时，服务端只返回 1 段站点证书，未返回中间证书链，导致 Java 客户端报 PKIX path building failed / unable to find valid certification path to requested target。

我们这边后端入口 192.168.51.20 已经验证正常：同样使用 SNI newcas.sjzc.edu.cn 访问 192.168.51.20:443，服务端返回 3 段证书，Verify return code 为 0。

学校侧最终排查确认链路中存在安全设备 / WAF / SSL 检测设备。请在该安全设备上检查 newcas.sjzc.edu.cn 对应的 HTTPS 证书配置，确认证书链为完整链，即站点证书 + 中间证书 + 根证书，不能只配置站点证书。

修复后验证标准：
1. openssl s_client -showcerts 能看到 2 或 3 段证书；
2. Verify return code 为 0；
3. Java 应用不再出现 PKIX path building failed。
```

------

## 15. 现场快速命令汇总

### 15.1 查看应用 SSL 报错

```bash
kubectl -n cas-server logs deploy/cas-server-webapp --tail=500 | egrep -i "SSLHandshakeException|PKIX|valid certification path|unable to find"
```

------

### 15.2 查看 Pod 内域名解析

```bash
kubectl -n cas-server exec -it <pod-name> -- getent hosts newcas.sjzc.edu.cn
```

------

### 15.3 查看域名返回几段证书

```bash
kubectl -n cas-server exec -it <pod-name> -- sh -c '
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
'
```

------

### 15.4 查看域名证书校验结果

```bash
kubectl -n cas-server exec -it <pod-name> -- sh -c '
echo | openssl s_client \
  -connect newcas.sjzc.edu.cn:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts -verify_return_error 2>&1 | egrep "subject=|issuer=|Verify return code"
'
```

------

### 15.5 查看 Kubernetes TLS Secret 证书段数

```bash
kubectl -n cas-server get secret 2026-2027 \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | grep -c "BEGIN CERTIFICATE"
```

------

### 15.6 直连我方入口验证证书段数

```bash
kubectl -n cas-server exec -it <pod-name> -- sh -c '
echo | openssl s_client \
  -connect 192.168.51.20:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
'
```

------

### 15.7 直连我方入口验证证书校验结果

```bash
kubectl -n cas-server exec -it <pod-name> -- sh -c '
echo | openssl s_client \
  -connect 192.168.51.20:443 \
  -servername newcas.sjzc.edu.cn \
  -showcerts -verify_return_error 2>&1 | egrep "subject=|issuer=|Verify return code"
'
```

------

### 15.8 查看 CoreDNS 配置

```bash
kubectl -n kube-system get configmap coredns -o yaml
```

------

### 15.9 备份 CoreDNS

```bash
kubectl -n kube-system get configmap coredns -o yaml > coredns-cm-backup-$(date +%F-%H%M%S).yaml
```

------

### 15.10 修改 CoreDNS

```bash
kubectl -n kube-system edit configmap coredns
```

增加：

```coredns
hosts {
    192.168.51.20 newcas.sjzc.edu.cn
    fallthrough
}
```

------

### 15.11 重启 CoreDNS

```bash
kubectl -n kube-system rollout restart deployment coredns
```

------

### 15.12 验证 CoreDNS 覆盖

```bash
kubectl -n cas-server exec -it <pod-name> -- getent hosts newcas.sjzc.edu.cn
```

期望：

```text
192.168.51.20   newcas.sjzc.edu.cn
```

------

### 15.13 重启业务 Deployment

```bash
kubectl -n cas-server rollout restart deploy cas-server-webapp
```

------

## 16. 最终判定标准

问题修复后，应满足：

```text
1. Pod 内访问 newcas.sjzc.edu.cn 时，证书链返回 2 或 3 段；
2. openssl s_client 校验结果为 Verify return code: 0；
3. Java 应用日志中不再出现 SSLHandshakeException / PKIX path building failed；
4. 业务接口访问恢复正常；
5. 如果使用 CoreDNS 或 hostAliases 临时绕过，应在学校侧 WAF 修复后评估是否回滚。
```

------

## 17. 本次现场最终结论

```text
本次 Rancher 中 Java 微服务 SSL 报错的最终原因是学校侧安全设备 / WAF / SSL 代理设备上的证书链配置不完整。

我方 Rancher TLS Secret 中证书链为 3 段，配置正常；
我方 192.168.51.20 入口返回 3 段证书，Verify return code 为 0，配置正常；
但 Pod 访问 newcas.sjzc.edu.cn 时，链路中的学校侧安全设备只返回 1 段站点证书，导致 Java 8 客户端无法完成 PKIX 证书链校验。

学校侧修复安全设备 / WAF 上的完整证书链后，问题解决。
```