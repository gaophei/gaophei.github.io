# Harbor 服务器（192.168.23.12）漏洞处理记录

| 项目 | 内容 |
|---|---|
| 主机 | 192.168.23.12（hostname: harbor） |
| 用途 | Harbor 私有镜像仓库，域名 `harbor.sti.edu.cn` |
| 操作系统 | Anolis OS 7.9/64（CentOS 7 兼容分支） |
| 配置 | 4C / 8G / 512G SAS |
| 应用版本 | Harbor **v2.14.4**，docker compose 部署，11 个容器 |
| 扫描来源 | 绿盟 RSAS V6.0R04F04SP11，任务 2735 |
| 扫描时间 | 2026-08-17 11:09:54 – 11:36:53 |
| 主机评分 | **8.6（高危）** |
| 漏洞统计 | 高危 8 · 中危 6 · 低危 17 |
| 处理日期 | 2026-08-21 |

---

# 一、漏洞详情

## 1.1 按端口分布

### ICMP / UDP

| 等级 | 漏洞名称 | CVE |
|---|---|---|
| 低 | ICMP timestamp 请求响应漏洞 | CVE-1999-0524 |
| 低 | 允许 Traceroute 探测 | — |

### 22/tcp — SSH

| 等级 | 漏洞名称 | CVE |
|---|---|---|
| 低 | SSH 版本信息可被获取 | CVE-1999-0634 |
| 低 | 探测到 SSH 服务器支持的算法【原理扫描】 | — |

> 本机为 OpenSSH 10.3（已手工升级过），未命中弱加密算法与 CBC 模式问题。

### 23/tcp — Telnet

| 等级 | 漏洞名称 | CVE |
|---|---|---|
| 低 | 检测到远端运行着 Telnet 服务 | CVE-1999-0619 |

> **评分虽低，但实际风险最高**：明文传输账号口令，等保必查项。本次处置列为 P0。

### 80/tcp — HTTP（nginx）

| 等级 | 漏洞名称 | CVE |
|---|---|---|
| **高** | NGINX ngx_http_rewrite_module 堆缓冲区溢出漏洞 | **CVE-2026-42945** |
| **高** | F5 NGINX 缓冲区错误漏洞 | CVE-2026-32647 |
| **高** | F5 NGINX 安全漏洞 | CVE-2026-27654 |
| **高** | F5 NGINX 代码问题漏洞 | CVE-2026-27651 |
| **高** | F5 NGINX 安全漏洞 | CVE-2026-9256 |
| **高** | F5 NGINX 安全漏洞 | CVE-2026-42946 |
| 中 | F5 NGINX 安全漏洞 | CVE-2026-1642 |
| 中 | F5 NGINX 输入验证错误漏洞 | CVE-2026-27784 |
| 中 | F5 NGINX 安全漏洞 | CVE-2026-40460 |
| 中 | F5 NGINX 缓冲区错误漏洞 | CVE-2026-42934 |
| 中 | F5 NGINX 资源管理错误漏洞 | CVE-2026-40701 |
| 中 | F5 Nginx Plus 缓冲区错误漏洞 | CVE-2026-48142 |
| 低 | F5 NGINX 缓冲区错误漏洞 | CVE-2025-53859 |
| 低 | F5 NGINX 注入漏洞 | CVE-2026-28753 |
| 低 | 可通过 HTTP(S) 获取远端 WWW 服务信息 | — |

### 111/tcp + 111/udp — rpcbind

| 等级 | 漏洞名称 | CVE |
|---|---|---|
| **高** | 检测到远端 RPCBIND/PORTMAP 正在运行中（tcp） | CVE-1999-0632 |
| **高** | 检测到远端 RPCBIND/PORTMAP 正在运行中（udp） | CVE-1999-0632 |
| 低 | 目标主机 rpcinfo -p 信息泄露 | — |

> 注意：所谓「2 条高危」是同一个问题，tcp 和 udp 各计一条。

### 443/tcp — HTTPS

8 条低危，全部为信息采集型：可通过 HTTP(S)/HTTPS 获取 WWW 服务信息、SSL 证书过期时间、证书 hostname、TLS 1.2 / TLS 1.3 协议检测、支持的 SSL 加密算法、远端 HSTS 服务运行中。

> 其中「HSTS 服务运行中」实为安全加固已生效的标志，非缺陷。

## 1.2 关键判断

> **8 条高危实际只对应 2 个根因**：nginx 版本落后（6 条）+ rpcbind 对外开放（2 条）。
> 而 nginx 那 6 条**并不在宿主机上**——详见第二章排查过程。

---

# 二、排查过程（含完整命令与输出）

## 2.1 端口与进程基线

```bash
netstat -tnulp
```

```
Proto Recv-Q Send-Q Local Address           Foreign Address     State   PID/Program name
tcp        0      0 127.0.0.1:1514          0.0.0.0:*           LISTEN  226662/docker-proxy
tcp        0      0 127.0.0.1:10573         0.0.0.0:*           LISTEN  941/agent_service
tcp        0      0 0.0.0.0:111             0.0.0.0:*           LISTEN  712/rpcbind
tcp        0      0 0.0.0.0:80              0.0.0.0:*           LISTEN  227397/docker-proxy
tcp        0      0 192.168.122.1:53        0.0.0.0:*           LISTEN  1466/dnsmasq
tcp        0      0 0.0.0.0:22              0.0.0.0:*           LISTEN  32797/sshd
tcp        0      0 0.0.0.0:23              0.0.0.0:*           LISTEN  1/systemd
tcp        0      0 127.0.0.1:631           0.0.0.0:*           LISTEN  833/cupsd
tcp        0      0 0.0.0.0:443             0.0.0.0:*           LISTEN  227378/docker-proxy
udp        0      0 0.0.0.0:111             0.0.0.0:*                   712/rpcbind
udp        0      0 0.0.0.0:886             0.0.0.0:*                   712/rpcbind
udp        0      0 0.0.0.0:5353            0.0.0.0:*                   795/avahi-daemon
udp        0      0 0.0.0.0:57160           0.0.0.0:*                   795/avahi-daemon
```

**三条线索立刻浮现：**

1. `23/tcp` 的持有者是 **PID 1 / systemd** → 说明 telnet 是 socket 激活的（`telnet.socket`），只 `stop` 服务无效，必须处理 socket 单元。
2. `80` 和 `443` 的持有者是 **docker-proxy**，不是 nginx → 宿主机上根本没有 nginx 进程。
3. 存在 `cups`、`avahi`、`dnsmasq(libvirt)` → 这台机是**桌面/工作站包集**安装，不是最小化服务器安装。

## 2.2 确认 nginx 归属：在容器里，不在宿主机

```bash
docker compose ps
```

```
NAME                IMAGE                                    STATUS                  PORTS
harbor-core         goharbor/harbor-core:v2.14.4             Up 2 months (healthy)
harbor-db           goharbor/harbor-db:v2.14.4               Up 2 months (healthy)
harbor-jobservice   goharbor/harbor-jobservice:v2.14.4       Up 2 months (healthy)
harbor-log          goharbor/harbor-log:v2.14.4              Up 2 months (healthy)   127.0.0.1:1514->10514/tcp
harbor-portal       sha256:6ea93fde8496...                   Up 2 months (healthy)
nginx               goharbor/nginx-photon:v2.14.4            Up 2 months (healthy)   0.0.0.0:80->8080/tcp, 0.0.0.0:443->8443/tcp
redis               goharbor/redis-photon:v2.14.4            Up 2 months (healthy)
registry            goharbor/registry-photon:v2.14.4         Up 2 months (healthy)
registryctl         goharbor/harbor-registryctl:v2.14.4      Up 2 months (healthy)
trivy-adapter       goharbor/trivy-adapter-photon:v2.14.4    Up 2 months (healthy)
```

```bash
docker exec -it nginx cat /etc/os-release
docker exec -it nginx nginx -V
```

```
NAME="VMware Photon OS"
VERSION="5.0"

nginx version: nginx/1.26.3
built with OpenSSL 3.0.18 30 Sep 2025
configure arguments: --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx
  --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid
  --add-dynamic-module=njs-0.8.4/nginx
  --add-dynamic-module=./headers-more-nginx-module-0.37
  --with-pcre --with-compat --with-http_ssl_module --modules-path=/etc/nginx/modules
  --with-http_auth_request_module --with-http_sub_module --with-http_stub_status_module
  --with-http_v2_module --with-http_realip_module
  --with-http_dav_module=dynamic --with-stream=dynamic
  --with-stream_ssl_preread_module=dynamic --with-stream_ssl_module
```

**结论一：`yum update nginx` 在这台机上无从下手。** 漏洞载体是 `goharbor/nginx-photon:v2.14.4` 这个容器镜像（基于 VMware Photon OS 5.0），修复途径只能是**更换镜像**。

**结论二：编译参数决定了大量 CVE 根本不适用。** 见 2.3 的可达性矩阵。

## 2.3 nginx CVE 实际可达性核查

### 2.3.1 配置层核查

```bash
docker exec nginx cat /etc/nginx/nginx.conf
docker exec nginx sh -c 'grep -rnE "rewrite|^[[:space:]]*if[[:space:]]*\(|set \\\$" /etc/nginx/'
```

grep **返回空**。完整配置核对结果：

- 全文只有 `location` + `proxy_pass` 结构，外加 `return 404`（`/v1/`、`/service/notifications`）和 `return 308`（8080 跳 https）
- **没有任何 `rewrite`、`if`、`set` 指令**
- 存在 `map $http_x_forwarded_proto $x_forwarded_proto`，但匹配键只有 `default` 和空串 `""`，**不含正则**
- 没有 `load_module` 指令 → 所有 dynamic 模块（dav、stream、njs、headers-more 之外）均未加载
- 未使用 `charset`、`ssi`、`slice`、`alias`、`mp4` 任何一个指令
- `proxy_http_version 1.1`（不是到后端的 HTTP/2）

### 2.3.2 模块可达性矩阵

| CVE | 扫描等级 | 涉及模块 | 该模块是否编入 | 配置是否启用 | 可达性 |
|---|---|---|---|---|---|
| CVE-2026-42945（Rift） | 高 | rewrite | 是（内置） | **否**（无 rewrite/if/set） | **不可达** |
| CVE-2026-27654 | 高 | dav（COPY/MOVE + alias） | dynamic | **否**（未 load_module，无 alias） | **不可达** |
| CVE-2026-32647 | 高 | mp4 | **未编入** | 否 | **不可达** |
| CVE-2026-27784 | 中 | mp4（32 位） | **未编入** | 否 | **不可达** |
| CVE-2026-48142 | 中 | charset | 是（默认） | **否**（无 charset 指令） | **不可达** |
| CVE-2026-42533 | （复扫可能出现） | map + 正则 | 是 | **否**（map 无正则） | **不可达** |
| CVE-2026-60005 | （复扫可能出现） | slice | **未编入** | 否 | **不可达** |
| CVE-2026-56434 | （复扫可能出现） | ssi | 是（默认） | **否**（未启用） | **不可达** |
| CVE-2026-42055 | （复扫可能出现） | proxy_v2 + grpc | — | **否**（`proxy_http_version 1.1`） | **不可达** |
| CVE-2026-27651 / 9256 / 42946 / 1642 / 40460 / 42934 / 40701 | 高/中 | 未在公开信息中确认具体模块 | — | — | 需以升级后复扫为准 |

> **核心结论**：本次报出的 nginx 高危中，可明确定位模块的几条**在 Harbor 的配置下代码路径全部不可达**，不存在实际可利用面。整改可按计划窗口进行，不需要紧急抢修。

### 2.3.3 验证命令（可用于佐证材料）

```bash
# 确认 mp4 / slice 模块未编入
docker exec nginx nginx -V 2>&1 | tr ' ' '\n' | grep -E 'mp4|slice'   # 应为空

# 确认无动态模块被加载
docker exec nginx sh -c 'grep -rn load_module /etc/nginx/'            # 应为空

# 确认无 charset / ssi / alias 指令
docker exec nginx sh -c 'grep -rnE "charset|ssi_|alias " /etc/nginx/' # 应为空
```

## 2.4 rpcbind 消费者核查

```bash
systemctl status nfs
```

```
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
```

```bash
rpcinfo -p localhost
```

```
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper
    100000    2   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100000    3   udp    111  portmapper
    100000    2   udp    111  portmapper
```

**只有 `100000`（portmapper 自己），没有 `100003`(nfs)、`100005`(mountd)、`100024`(statd)。** 若本机是 NFSv3 客户端，`rpc.statd` 必然注册 `100024`。

```bash
# nfs服务器
# rpcinfo -p localhost
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper
    100000    2   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100000    3   udp    111  portmapper
    100000    2   udp    111  portmapper
    100024    1   udp  49710  status
    100024    1   tcp  43989  status
    100005    1   udp  20048  mountd
    100005    1   tcp  20048  mountd
    100005    2   udp  20048  mountd
    100005    2   tcp  20048  mountd
    100005    3   udp  20048  mountd
    100005    3   tcp  20048  mountd
    100003    3   tcp   2049  nfs
    100003    4   tcp   2049  nfs
    100227    3   tcp   2049  nfs_acl
    100003    3   udp   2049  nfs
    100003    4   udp   2049  nfs
    100227    3   udp   2049  nfs_acl
    100021    1   udp  46717  nlockmgr
    100021    3   udp  46717  nlockmgr
    100021    4   udp  46717  nlockmgr
    100021    1   tcp  42542  nlockmgr
    100021    3   tcp  42542  nlockmgr
    100021    4   tcp  42542  nlockmgr
```



进一步确认无 NFS 挂载：

```bash
mount | grep -E ' nfs | nfs4 '        # 空
grep -i nfs /etc/fstab                # 空
df -hT | grep -i nfs                  # 空
grep -A2 '^data_volume' ./harbor.yml
```

```
data_volume: /opt/harbordata/data
# Harbor Storage settings by default is using /data dir on local filesystem
```

**结论：Harbor 数据存放在本地盘，rpcbind 零消费者，可直接停用**（无需保留并做来源限制）。

> ⚠️ **踩坑记录**：在 192.168.23.11 上曾执行 `yum remove nfs-utils -y`，结果 111 端口**纹丝不动**——因为 111 属于 `rpcbind` 包而非 `nfs-utils`。而且该命令级联删除了 12 个包（gnome-boxes、libvirt-daemon-kvm、libvirt-daemon-driver-qemu 及 8 个 storage 子驱动）。
> **本机 rpm 依赖链因手工替换过 OpenSSL 本就不健康，后续所有 `yum remove` 一律不加 `-y`，先看完级联清单再确认。**

## 2.5 访问来源核查（为白名单收敛做准备）

### 2.5.1 全量来源统计

Harbor 的 nginx 日志格式为：

```
$remote_addr - "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time $upstream_response_time $pipe
```

注意 `$request` 带引号且含空格，因此 **awk 中路径是第 4 个字段**，不是第 3 个。

```bash
docker logs nginx 2>&1 | awk '
  {p=$4; t = (p ~ /^\/v2\//) ? "registry" : (p ~ /^\/(api|c)\//) ? "ui" : "other";
   print $1, t}' | sort | uniq -c | sort -rn
```

```
 226226 127.0.0.1 other
   5278 192.168.23.16 registry
   3079 192.168.247.224 other
   2578 192.168.23.16 other
    584 192.168.23.21 other
    372 192.168.23.21 ui
     27 192.168.247.224 ui
      2 192.168.247.224 registry
      2 192.168.23.15 registry
      1 192.168.23.15 other
```

**读数解析：**

- `127.0.0.1` 22.6 万条（约 95%）→ Harbor 容器自身的 healthcheck 噪音
- `192.168.23.16`（docker02）→ 真正的镜像拉取大户
- `192.168.23.21` → 运维终端，Web UI 访问（连续多次采样时只有它在增长，据此定位）
- `192.168.23.15`（docker01）→ 少量拉取
- **`192.168.247.224` → 不在 23 段，需单独查证**

> 排查技巧：连续执行同一条统计命令 3–4 次，观察哪个 IP 的计数在增长，即可定位当前正在访问的来源。
> 另注：最初只 grep `/v2/` 时看不到 Web UI 访问，因为 UI 走的是 `/`、`/api/`、`/c/`。

### 2.5.2 192.168.247.224 身份查证

```bash
docker logs nginx 2>&1 | grep '192.168.247.224' | tail -20
```

```
192.168.247.224 - "GET /cgi-bin/nx/common/cds/menu.inc.php?c_path=http://xxxxxxxx/ HTTP/1.1" 400 248 "-" "Mozilla/4.75 [en] (X11, U;)"
192.168.247.224 - "GET //sql.php?LIB_INC=1&btnDrop=No&goto=/etc/passwd HTTP/1.0" 308 171 "-" "-"
192.168.247.224 - "GET /phpPgAdmin/sql.php3?LIB_INC=1&btnDrop=No&goto=/etc/passwd HTTP/1.1" 400 248 "-" "Mozilla/4.75 [en] (X11, U;)"
...
```

典型 Web 漏扫特征：批量探测 phpPgAdmin / sql.php / cgi-bin，`goto=/etc/passwd` 目录穿越试探，`c_path=http://` SSRF 试探；UA `Mozilla/4.75 [en] (X11, U;)` 是扫描器固定指纹。

```bash
docker logs -t nginx 2>&1 | grep '192.168.247.224' | head -3
docker logs -t nginx 2>&1 | grep '192.168.247.224' | tail -3
```

```
2026-08-17T11:12:56+08:00 192.168.247.224 - "GET / HTTP/1.0" 308 171
...
2026-08-17T11:36:00+08:00 192.168.247.224 - "GET /scripts/sql.php3?...&goto=/etc/passwd HTTP/1.1" 400 248
```

**时间窗 11:12:56 – 11:36:00，完全落在扫描任务 2735 的 11:09:54 – 11:36:53 之内。**

> **结论：192.168.247.224 = 绿盟 RSAS 扫描器本机。** 属授权行为，非安全事件。但**不应列入日常白名单**，复扫时临时放行即可。

### 2.5.3 200 响应的真假甄别

```bash
docker logs nginx 2>&1 | grep '192.168.247.224' | grep -E '" (200|30[12]|401) '
```

```
192.168.247.224 - "GET /wnm/check.j HTTP/1.1"                    200 785
192.168.247.224 - "GET / HTTP/1.1"                               200 785
192.168.247.224 - "GET /metrics HTTP/1.1"                        200 785
192.168.247.224 - "GET /console/login/LoginForm.jsp HTTP/1.1"    200 785
192.168.247.224 - "GET /phpinfo.php HTTP/1.1"                    200 785
192.168.247.224 - "GET /index HTTP/1.1"                          200 785
192.168.247.224 - "GET /api/v2.0/systeminfo HTTP/1.1"            200 120
```

**响应体大小是甄别关键：**

- `785` 字节的全部是 **Harbor 前端 SPA 的 index.html**。`location /` 把所有未匹配路径都转给 portal，portal 对任意路径返回同一入口页——这是单页应用的兜底行为。`/phpinfo.php` 返回 200 **不代表存在 phpinfo**，`/metrics` 也未暴露 Prometheus 指标，`/console/login/LoginForm.jsp`（WebLogic 探测）同理。
- `120` 字节的 `GET /api/v2.0/systeminfo` 是**唯一真实端点**，未授权可访问，返回 JSON 中包含 `harbor_version`。

验证命令：

```bash
curl -sk -o /dev/null -w '%{http_code} %{size_download}\n' \
  https://127.0.0.1/ https://127.0.0.1/phpinfo.php https://127.0.0.1/metrics
# 三个均为 200 785

curl -sk https://127.0.0.1/api/v2.0/systeminfo
```

> **经验沉淀**：扫描器报「某路径可访问」时，先比对响应体大小。SPA 兜底页会制造大量假阳性。

## 2.6 防火墙路径核查（关键踩坑）

### 2.6.1 firewalld 为何无效

```bash
systemctl is-active firewalld
```

```
inactive
```

```bash
docker info 2>/dev/null | grep -i iptables      # 无输出，即默认 iptables=true
cat /etc/docker/daemon.json
```

```json
{
    "bip": "138.138.123.1/24",
    "registry-mirrors": ["https://7bezldxe.mirror.aliyuncs.com"],
    "insecure-registries":["http://harbor.sti.edu.cn"],
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": { "max-size": "100m", "max-file": "3" }
}
```

```bash
iptables -t nat -L DOCKER -n --line-numbers
```

```
Chain DOCKER (2 references)
num  target     prot opt source        destination
3    DNAT       tcp  --  0.0.0.0/0     127.0.0.1     tcp dpt:1514 to:172.20.0.2:10514
4    DNAT       tcp  --  0.0.0.0/0     0.0.0.0/0     tcp dpt:443  to:172.20.0.10:8443
5    DNAT       tcp  --  0.0.0.0/0     0.0.0.0/0     tcp dpt:80   to:172.20.0.10:8080
```

数据包路径：

```
外部请求 → nat/PREROUTING → DOCKER 链（DNAT 到 172.20.0.10:8443）
         → filter/FORWARD → DOCKER / DOCKER-USER → 容器
```

**firewalld 的 `--add-port` / zone 规则全部作用在 `filter/INPUT` 上，而这条路径根本不经过 INPUT。** 因此对 Docker 发布的端口完全无效，必须改用 `DOCKER-USER` 链（`FORWARD` 的第一跳，Docker 自身永不修改其内容，重启 docker 也不清空）。

### 2.6.2 第一版规则失效及根因

初版规则（**错误示范**）：

```bash
iptables -I DOCKER-USER 1 -i eth0 -p tcp -m multiport --dports 80,443 \
         -m set --match-set harbor_allow src -j RETURN
iptables -I DOCKER-USER 2 -i eth0 -p tcp -m multiport --dports 80,443 -j DROP
```

计数器读数：

```
num   pkts bytes target     prot opt in     out   ...
1        0     0 RETURN     tcp  --  eth0   *     multiport dports 80,443 match-set harbor_allow src
2        0     0 DROP       tcp  --  eth0   *     multiport dports 80,443
3     6307  2797K RETURN    all  --  *      *
```

**规则 1、2 恒为 0 包，而末尾 Docker 自带的 `RETURN all` 正常累计** → 说明链是通的，但匹配条件不成立。

根因由 conntrack 直接证实：

```bash
yum install -y conntrack-tools

conntrack -D -p tcp --dport 443
```

```
tcp 6 431996 ESTABLISHED src=192.168.23.21 dst=192.168.23.12 sport=54122 dport=443
                          src=172.20.0.10  dst=192.168.23.21 sport=8443 dport=54122 [ASSURED]
```

回复方向的源端口是 **8443**，说明 DNAT 已在 `nat/PREROUTING` 完成。**包到达 `filter/FORWARD` 时目的端口早已被改写成容器端口 8080/8443，`--dports 80,443` 永不匹配。**

旁证——Docker 自己在 filter 表的规则也是按容器端口写的：

```bash
iptables -L DOCKER -n -v | head
```

```
 pkts bytes target  prot opt in                out              source     destination   
10662  640K ACCEPT  tcp  --  !br-b94a3d4c072d  br-b94a3d4c072d  0.0.0.0/0  172.20.0.10  tcp dpt:8443
 1500 90000 ACCEPT  tcp  --  !br-b94a3d4c072d  br-b94a3d4c072d  0.0.0.0/0  172.20.0.10  tcp dpt:8080
```

### 2.6.3 另一个测试陷阱

```bash
# 在 192.168.23.12 本机执行——这个测试无效
curl -sk -o /dev/null -w '%{http_code}\n' https://192.168.23.12/
```

本机访问自己发布的端口走 `OUTPUT → nat/OUTPUT → DNAT`，**不经过 `FORWARD`**，因此 DOCKER-USER 规则永远碰不到它，无论白名单是否为空都返回 200。

> **验证必须从外部机器（如 192.168.23.21）发起。**

### 2.6.4 网桥名获取

```bash
ip -o link show | grep -E 'docker0|br-'
docker network inspect harbor_harbor -f '{{.Id}}' | cut -c1-12
```

```
5:  docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> state DOWN     ← 未使用
71: br-b94a3d4c072d: <BROADCAST,MULTICAST,UP,LOWER_UP> state UP ← Harbor 网络
b94a3d4c072d
```

> ⚠️ **`docker compose down` 会删除 `harbor_harbor` 网络，`up` 后网络 ID 变化，`br-*` 接口名随之改变。持久化脚本必须动态查询，不可硬编码。** 后续 Harbor 升级正好会走这个流程。

### 2.6.5 域名与源 IP 可信性

```bash
getent hosts harbor.sti.edu.cn
```

```
192.168.23.12   harbor.sti.edu.cn
```

解析到本机内网地址，无外部 NAT 发夹回环，日志中的源 IP 即真实客户端 IP，可直接用于白名单。

---

# 三、解决方案与执行记录

## 3.1 处置优先级

| 序号 | 项目 | 优先级 | 停机影响 | 状态 |
|---|---|---|---|---|
| A | 关闭 telnet | **P0** | 无 | 待执行 |
| B | 停用 rpcbind | **P0** | 无 | ✅ 已完成 |
| C | DOCKER-USER 访问白名单 | **P0** | 无 | ✅ 已完成 |
| D | 持久化配置 | P1 | 无 | 待执行 |
| E | Harbor 升级 v2.15.2 | P1 | 需窗口 | 待执行 |
| F | 系统瘦身（cups/avahi/libvirt） | P2 | 无 | 待执行 |
| G | ICMP timestamp / traceroute | P2 | 无 | 报备 |

## 3.2 A — 关闭 Telnet【P0】

telnet 由 systemd socket 激活（持有者为 PID 1），仅 `stop` 服务无效，必须处理 socket 单元并 `mask` 防止被依赖唤醒。

```bash
systemctl stop    telnet.socket
systemctl disable telnet.socket
systemctl mask    telnet.socket

# 验证
ss -lntp | grep ':23'                    # 应为空
systemctl is-enabled telnet.socket       # 应为 masked
```

卸载服务端包（**不加 `-y`**，先看级联清单）：

```bash
rpm -qa | grep -i telnet
yum remove telnet-server                 # 看清依赖清单再确认
```

> `telnet`（客户端）与 `telnet-server`（服务端）是两个包，只需卸服务端，客户端可保留作排障工具。

**消除漏洞**：CVE-1999-0619（低）。

## 3.3 B — 停用 rpcbind【P0，已完成】

rpcbind 是 socket 激活的，三步缺一不可：

```bash
systemctl stop    rpcbind.socket rpcbind.service
systemctl disable rpcbind.socket rpcbind.service
systemctl mask    rpcbind.socket rpcbind.service
```

执行输出：

```
Removed symlink /etc/systemd/system/multi-user.target.wants/rpcbind.service.
Removed symlink /etc/systemd/system/sockets.target.wants/rpcbind.socket.
Created symlink from /etc/systemd/system/rpcbind.socket to /dev/null.
Created symlink from /etc/systemd/system/rpcbind.service to /dev/null.
```

清理 rpc_pipefs：

```bash
# 如果是docker01工作节点，不能做此操作
umount /var/lib/nfs/rpc_pipefs 2>/dev/null
systemctl mask var-lib-nfs-rpc_pipefs.mount
```

```
Created symlink from /etc/systemd/system/var-lib-nfs-rpc_pipefs.mount to /dev/null.
```

**验证：**

```bash
ss -lntup | grep -E ':111|:886'
```

```
（无输出 — 111/tcp、111/udp、886/udp 全部消失）
```

**消除漏洞**：CVE-1999-0632 × 2（高）、rpcinfo -p 信息泄露（低）。

> **说明**：本项选择 `mask` 而非 `yum remove rpcbind`。mask 已能使端口彻底消失、满足复扫要求，且完全可逆；remove 则要再冒一次级联删包风险，收益为零。

## 3.4 C — DOCKER-USER 访问白名单【P0，已完成】

### 3.4.1 安装与集合创建

```bash
yum install -y ipset ipset-service

ipset create harbor_allow hash:net timeout 0
ipset add harbor_allow 192.168.23.0/24
```

> `ipset` 命令行工具与 systemd 服务单元分属两个包，**必须同时安装 `ipset-service`**，否则 `systemctl enable ipset` 会报 `Failed to execute operation: No such file or directory`。

启用自动保存，避免以后加了临时 IP 忘记落盘：

```bash
systemctl enable ipset
sed -i 's/^IPSET_SAVE_ON_STOP=.*/IPSET_SAVE_ON_STOP="yes"/' /etc/sysconfig/ipset-config
grep IPSET_SAVE_ON_STOP /etc/sysconfig/ipset-config
```

```
Created symlink from /etc/systemd/system/basic.target.wants/ipset.service to /usr/lib/systemd/system/ipset.service.
IPSET_SAVE_ON_STOP="yes"
```

### 3.4.2 定稿规则

**关键：端口必须写容器侧的 8080/8443，不是宿主机发布的 80/443。**

```bash
BR=$(docker network inspect harbor_harbor -f 'br-{{printf "%.12s" .Id}}')
echo "$BR"          # br-b94a3d4c072d

# 有的网卡是eth0，有的是ens18，通过ip a查看
# eth0
iptables -I DOCKER-USER 1 -i eth0 -o "$BR" -p tcp -m multiport --dports 8080,8443 \
         -m set --match-set harbor_allow src -j RETURN
iptables -I DOCKER-USER 2 -i eth0 -o "$BR" -p tcp -m multiport --dports 8080,8443 -j DROP

# ens18
ipset list harbor_allow -t
iptables -D DOCKER-USER 1
iptables -D DOCKER-USER 1

iptables -I DOCKER-USER 1 -i ens18 -o "$BR" -p tcp -m multiport --dports 8080,8443 \
         -m set --match-set harbor_allow src -j RETURN
iptables -I DOCKER-USER 2 -i ens18 -o "$BR" -p tcp -m multiport --dports 8080,8443 -j DROP
```

规则确认：

```bash
iptables -L DOCKER-USER -n -v --line-numbers
```

```
Chain DOCKER-USER (1 references)
num   pkts bytes target  prot opt in    out              source     destination
1        0     0 RETURN  tcp  --  eth0  br-b94a3d4c072d  0.0.0.0/0  0.0.0.0/0  multiport dports 8080,8443 match-set harbor_allow src
2        0     0 DROP    tcp  --  eth0  br-b94a3d4c072d  0.0.0.0/0  0.0.0.0/0  multiport dports 8080,8443
3      218  106K RETURN  all  --  *     *                0.0.0.0/0  0.0.0.0/0
```

> 三个限定条件缺一不可：
> - `-i eth0`：只作用于外部进入的流量
> - `-o $BR`：只作用于流向 Harbor 网桥的方向
> - `--dports 8080,8443`：DNAT 后的真实目的端口
>
> **若省略 `-i eth0` 或写成裸 `-j DROP`，容器出网会被整个切断**（replication、proxy cache、Trivy 漏洞库更新全部失效）。



```bash
[root@harbor ~]# iptables -L DOCKER-USER -n -v --line-numbers
Chain DOCKER-USER (1 references)
num   pkts bytes target     prot opt in     out     source               destination         
1        0     0 RETURN     tcp  --  ens18  br-7533db52f8da  0.0.0.0/0            0.0.0.0/0            multiport dports 8080,8443 match-set harbor_allow src
2        0     0 DROP       tcp  --  ens18  br-7533db52f8da  0.0.0.0/0            0.0.0.0/0            multiport dports 8080,8443
3     530M  210G RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0           
[root@harbor ~]# ipset list harbor_allow -t
Name: harbor_allow
Type: hash:net
Revision: 6
Header: family inet hashsize 1024 maxelem 65536 timeout 0
Size in memory: 640
References: 1
Number of entries: 1
[root@harbor harbor]# iptables -L DOCKER-USER -n -v --line-numbers
Chain DOCKER-USER (1 references)
num   pkts bytes target     prot opt in     out     source               destination         
1      637  157K RETURN     tcp  --  ens18  br-7533db52f8da  0.0.0.0/0            0.0.0.0/0            multiport dports 8080,8443 match-set harbor_allow src
2       24  1440 DROP       tcp  --  ens18  br-7533db52f8da  0.0.0.0/0            0.0.0.0/0            multiport dports 8080,8443
3     530M  210G RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0           
[root@harbor harbor]# 
[root@harbor harbor]# iptables -Z DOCKER-USER
[root@harbor harbor]# iptables -L DOCKER-USER -n -v --line-numbers
Chain DOCKER-USER (1 references)
num   pkts bytes target     prot opt in     out     source               destination         
1        0     0 RETURN     tcp  --  ens18  br-7533db52f8da  0.0.0.0/0            0.0.0.0/0            multiport dports 8080,8443 match-set harbor_allow src
2        0     0 DROP       tcp  --  ens18  br-7533db52f8da  0.0.0.0/0            0.0.0.0/0            multiport dports 8080,8443
3      141 73567 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0           
[root@harbor harbor]# 

```





### 3.4.3 验证记录

**① 白名单命中验证**（从 192.168.23.21 访问 Harbor 网页后）：

```bash
iptables -L DOCKER-USER -n -v --line-numbers
```

```
num   pkts bytes target  ...
1       41 19046 RETURN  tcp  --  eth0  br-b94a3d4c072d  ... match-set harbor_allow src
2        0     0 DROP    tcp  --  eth0  br-b94a3d4c072d  ...
3     2091  935K RETURN  all  --  *     *
```

规则 1 命中 41 包，规则 2（DROP）保持 0 —— 白名单在前拦下，行为正确。

**② 拦截验证**：

```bash
# 192.168.23.12 上移除白名单
ipset del harbor_allow 192.168.23.0/24
conntrack -D -p tcp --dport 8443 2>/dev/null
```

```bash
# 192.168.23.21（Windows）上测试 —— 注意 cmd 不认单引号，须用双引号
curl -sk -o NUL -w "blocked: %{http_code}\n" -m 5 https://192.168.23.12/
```

```
blocked: 000                    ← 超时，拦截生效
```

```bash
# 192.168.23.15（docker01）上测试
docker pull harbor.sti.edu.cn/admin-platform/admin-platform:1.4.3-RELEASE.2
```

```
Error response from daemon: Get http://harbor.sti.edu.cn/v2/: net/http: request canceled
while waiting for connection (Client.Timeout exceeded while awaiting headers)
```

> 注意报错中是 **`http://`** —— docker01 通过 `insecure-registries` 走 80 端口（容器侧 8080），规则已覆盖。

**③ 恢复验证**：

```bash
# 192.168.23.12 上恢复
ipset add harbor_allow 192.168.23.0/24
```

```bash
# docker01
docker pull harbor.sti.edu.cn/admin-platform/admin-platform:1.4.3-RELEASE.2
```

```
1.4.3-RELEASE.2: Pulling from admin-platform/admin-platform
Digest: sha256:1b2e79be000ede1958b930a0c842bf3b960dffb31ad97d6f134085afec6b9473
Status: Image is up to date for harbor.sti.edu.cn/admin-platform/admin-platform:1.4.3-RELEASE.2
```

```bash
# 192.168.23.21
curl -sk -o NUL -w "%{http_code}\n" -m 5 https://192.168.23.12/
```

```
200
```

**三个方向全部验证通过。**

### 3.4.4 白名单范围

| 网段/IP | 说明 | 是否放行 |
|---|---|---|
| `192.168.23.0/24` | 覆盖 .11–.18 全部服务器 + .21 运维终端 | ✅ 常驻 |
| `192.168.247.224` | 绿盟 RSAS 扫描器 | ❌ 日常封禁，复扫时临时放行 |

复扫前临时放行（2 小时自动失效）：

```bash
ipset add harbor_allow 192.168.247.224 timeout 7200
ipset list harbor_allow          # 可查看剩余时间
```

> **流程约定**：若复扫时不放行扫描器，报告会显示该主机无 Web 服务——那不是「整改完成」而是「扫不到」，反而掩盖了真实版本状态。建议复扫时临时放行，让报告如实反映升级后效果。

### 3.4.5 观察期日志规则（建议，一周后移除）

DROP 是静默的，加一条限速日志以捕获遗漏的合法来源（日志轮转可能已丢失部分历史记录，`.13`/`.14` 从未在日志中出现过，需确认是真不拉还是记录已滚掉）：

```bash
BR=br-b94a3d4c072d
iptables -I DOCKER-USER 2 -i eth0 -o "$BR" -p tcp -m multiport --dports 8080,8443 \
         -m limit --limit 10/min --limit-burst 20 \
         -j LOG --log-prefix "HARBOR-BLOCKED: " --log-level 4

iptables -L DOCKER-USER -n -v --line-numbers    # 确认顺序：RETURN / LOG / DROP
```

一周后统计：

```bash
grep 'HARBOR-BLOCKED' /var/log/messages | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn
```

确认无意外来源后移除：

```bash
iptables -D DOCKER-USER 2
```

> 限速是必须的——扫描器一次就是几千条，不限速会撑爆 `/var/log/messages`。

## 3.5 D — 持久化配置【P1】

### 3.5.1 ipset 落盘

> ⚠️ 若曾在白名单为空时执行过 `ipset save`，**必须重新保存一次**，否则重启后集合为空导致全网阻断。

```bash
ipset save > /etc/sysconfig/ipset
grep harbor_allow /etc/sysconfig/ipset
```

### 3.5.2 iptables 规则单元

不使用 `iptables-services`（它会在开机时恢复整套规则集，极易与 Docker 自建链冲突），改用只管自己两条规则的 systemd 单元：

注意网卡有的是eth0，有的是ens18等，与现场保持一致

```bash
cat > /usr/local/sbin/harbor-fw.sh <<'EOF'
#!/bin/bash
CHAIN=DOCKER-USER; IF=eth0; PORTS=8080,8443; SET=harbor_allow; NET=harbor_harbor

# 等 Docker 建好 DOCKER-USER 链和网络
for i in $(seq 1 60); do
  iptables -n -L $CHAIN >/dev/null 2>&1 && \
  docker network inspect $NET >/dev/null 2>&1 && break
  sleep 2
done

# 动态解析网桥名（compose down/up 后网络 ID 会变）
BR=$(docker network inspect $NET -f 'br-{{printf "%.12s" .Id}}' 2>/dev/null)
[ -z "$BR" ] && { echo "cannot resolve bridge for $NET"; exit 1; }

ipset list -n 2>/dev/null | grep -qx "$SET" || ipset create $SET hash:net timeout 0

# 幂等：先删再加，重复执行不会堆积规则
iptables -D $CHAIN -i $IF -o "$BR" -p tcp -m multiport --dports $PORTS \
         -m set --match-set $SET src -j RETURN 2>/dev/null
iptables -D $CHAIN -i $IF -o "$BR" -p tcp -m multiport --dports $PORTS -j DROP 2>/dev/null

iptables -I $CHAIN 1 -i $IF -o "$BR" -p tcp -m multiport --dports $PORTS \
         -m set --match-set $SET src -j RETURN
iptables -I $CHAIN 2 -i $IF -o "$BR" -p tcp -m multiport --dports $PORTS -j DROP
EOF
chmod +x /usr/local/sbin/harbor-fw.sh

cat > /etc/systemd/system/harbor-fw.service <<'EOF'
[Unit]
Description=Harbor DOCKER-USER access whitelist
After=docker.service ipset.service
Requires=ipset.service
PartOf=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/harbor-fw.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now harbor-fw
systemctl status harbor-fw
```

> `PartOf=docker.service` 使其在 docker 重启时跟随重跑。脚本幂等，手工调试可随意重复执行。

### 3.5.3 重启验证（随升级窗口一并完成）

```bash
iptables -L DOCKER-USER -n -v --line-numbers
ipset list harbor_allow
docker compose ps
systemctl is-enabled rpcbind.socket telnet.socket    # 均应为 masked
```

## 3.6 E — Harbor 升级至 v2.15.2【P1】

### 3.6.1 版本核实

```bash
docker run --rm goharbor/nginx-photon:v2.15.2 nginx -V
```

```
nginx version: nginx/1.30.2
built by gcc 12.2.0 (GCC)
built with OpenSSL 3.5.7 9 Jun 2026
configure arguments: ... --add-dynamic-module=njs-0.9.9/nginx
  --add-dynamic-module=./headers-more-nginx-module-0.39 --with-compat
  --with-http_ssl_module --modules-path=/etc/nginx/modules
  --with-http_auth_request_module --with-http_sub_module
  --with-http_stub_status_module --with-http_v2_modu...
```

| | v2.14.4（当前） | v2.15.2（目标） |
|---|---|---|
| nginx | 1.26.3 | **1.30.2** |
| OpenSSL | 3.0.18 | **3.5.7** |
| njs | 0.8.4 | 0.9.9 |
| headers-more | 0.37 | 0.39 |

> **背景说明**：Photon OS 5.0 曾长期将 nginx 钉在 1.28.3，而 CVE-2026-42945 的上游补丁只在 1.30.1 / 1.31.0 发布、1.28.x 线无 backport。2026 年 5 月的社区反馈显示当时 Harbor 各版本镜像均为 1.26.3 或 1.28.3。**Photon 后续已将 stable 分支从 1.28 升到 1.30**，因此升级 Harbor 现在确实可解决该问题。
> **实测优先于文档** —— 任何版本判断都应以 `docker run --rm goharbor/nginx-photon:<tag> nginx -V` 的实际输出为准。

### 3.6.2 升级步骤

2.14 → 2.15 为跨 minor 版本升级，必须走官方流程，不可只换 tag。

```bash
cd /root/harbor

# 1. 停服务（切勿用 down -v，会删数据卷）
docker compose down

# 2. 备份
cp harbor.yml /root/harbor.yml.bak-$(date +%F)
tar czf /root/harbor-cfg-$(date +%F).tar.gz /root/harbor/common/config
tar czf /root/harbor-compose-$(date +%F).tar.gz /root/harbor/docker-compose.yml
ls -lh /opt/harbordata/data          # 数据目录按既定备份策略处理

# 3. 迁移配置文件
docker run -it --rm -v /:/hostfs goharbor/harbor-migrator:v2.15.2 \
  --cfg up /root/harbor/harbor.yml

# 4. 下载 v2.15.2 offline installer，解压后执行
./install.sh --with-trivy

# 5. 验证
docker compose ps
docker exec nginx nginx -v
curl -sk https://127.0.0.1/api/v2.0/systeminfo
```

**升级后必做**：网络重建会导致 `br-*` 接口名变化，需重跑防火墙脚本并验证。

```bash
docker network inspect harbor_harbor -f 'br-{{printf "%.12s" .Id}}'
systemctl restart harbor-fw
iptables -L DOCKER-USER -n -v --line-numbers
```

### 3.6.3 升级后仍可能报出的 CVE

1.30.2 落后于当前最新的 1.30.4，以下已知漏洞在 1.30.3 / 1.30.4 才修复，版本比对型扫描器可能改报：

| CVE | 修复版本 | 涉及模块 | Harbor 配置可达性 |
|---|---|---|---|
| CVE-2026-42055 | 1.30.3 | proxy_v2 + grpc | 不可达（`proxy_http_version 1.1`） |
| CVE-2026-48142 | 1.30.3 | charset | 不可达（无 charset 指令） |
| CVE-2026-42533 | 1.30.4 | map + 正则 | 不可达（map 无正则） |
| CVE-2026-60005 | 1.30.4 | slice | 不可达（模块未编入） |
| CVE-2026-56434 | 1.30.4 | ssi | 不可达（未启用） |

> 建议在整改报告中预先写入本表，避免复扫后重复解释。若安全部门只认版本号不认可达性论证，则需持续跟踪 Harbor 后续 tag，用 `docker run` 逐个核实 nginx 版本。

## 3.7 F — 系统瘦身【P2】

本机为桌面/工作站包集安装，存在大量与制品库无关的服务：

| 端口 | 进程 | 处置 |
|---|---|---|
| `0.0.0.0:5353` + `57160` | avahi-daemon | 关闭（mDNS 服务发现，服务器上多余且全网可达） |
| `0.0.0.0:67` + `192.168.122.1:53` | dnsmasq（libvirt 默认网络） | 确认无虚机后关闭 |
| `127.0.0.1:631` | cupsd | 关闭（打印服务无意义） |
| `127.0.0.1:1514` | docker-proxy → harbor-log | **保留**（仅监听本地） |
| `127.0.0.1:10573` | agent_service | **保留**（监控/安全 agent，仅监听本地） |

```bash
# 确认无 KVM 虚机在跑
virsh list --all 2>/dev/null
ps -ef | grep -c '[q]emu-kvm'

# 关闭
systemctl disable --now avahi-daemon.socket avahi-daemon.service
systemctl disable --now cups.socket cups.service

# libvirt 默认网络（确认无虚机后）
virsh net-destroy default
virsh net-autostart default --disable
```

> 这几项扫描报告未单独报出（无对应 CVE），但等保「最小化安装」检查项会被点名。

## 3.8 G — 报备项【P2】

以下条目建议在整改报告中统一列为「信息型条目 / 已知悉 / 无需整改」：

- ICMP timestamp 请求响应漏洞（CVE-1999-0524）、允许 Traceroute 探测 —— 内网环境风险极低，若边界防火墙已统一处理则整体豁免
- SSH 版本信息可被获取（CVE-1999-0634）、探测到 SSH 服务器支持的算法
- 可通过 HTTP(S)/HTTPS 获取远端 WWW 服务信息
- 获取目标 SSL 证书过期时间 / 证书 hostname
- TLS 1.2 / TLS 1.3 版协议检测、检测到目标主机加密通信支持的 SSL 加密算法
- **远端 HSTS 服务运行中** —— 此项实为安全加固已生效的标志，非缺陷

若需消除 ICMP 类：

```bash
iptables -A INPUT  -p icmp --icmp-type timestamp-request -j DROP
iptables -A OUTPUT -p icmp --icmp-type timestamp-reply   -j DROP
```

---

# 四、遗留问题

| # | 问题 | 说明 | 建议 |
|---|---|---|---|
| 1 | `/api/v2.0/systeminfo` 未授权可访问 | 返回 JSON 含 `harbor_version`，是版本指纹的直接来源。Harbor 前端登录前渲染页面所必需，官方无关闭开关 | 无法修复。通过访问白名单限制「谁能问」，已由 3.4 覆盖 |
| 2 | `bip: 138.138.123.1/24` 使用公网地址段 | 138.138.0.0/16 是已分配的真实公网空间，非 RFC1918。后果是本机容器永远无法访问该真实网段的主机 | 现暂无影响，建议在升级窗口顺手改为 `172.31.x.x` 等私有段 |
| 3 | rpm 依赖链不健康 | 本机 OpenSSL/OpenSSH 曾被手工编译替换，`rpm -qf /usr/lib64/libssl.so.10` 显示 not owned by any package | **切勿删除 `libssl.so.1.0.2k` / `libcrypto.so.1.0.2k` 兼容垫片**；所有 `yum remove` 不加 `-y` |
| 4 | Anolis OS 7.9 已属 EOL 生态 | 全部 9 台机器均为 7.9，nginx 官方 el7 源已于 2024-06 冻结、MySQL 8.0 已 EOL | 系统性问题，建议单独立项评估升级到 Anolis 8 |
| 5 | Harbor 日志中 healthcheck 占比 95% | 22.6 万条 / 23.8 万条，真实客户端记录易被稀释、轮转丢失 | 观察期日志规则（3.4.5）可兜底；必要时调整 healthcheck 频率或分离日志 |
| 6 | `.13` / `.14` 从未出现在访问日志 | 可能真不拉镜像，也可能记录已轮转 | 二者均在 `192.168.23.0/24` 内，不影响本次配置；由 3.4.5 观察期确认 |

---

# 五、验收标准

- [ ] `ss -lntp | grep ':23'` 无输出
- [x] `ss -lntup | grep -E ':111|:886'` 无输出
- [x] `iptables -L DOCKER-USER` 规则 1 有命中计数
- [x] 白名单移除后外部访问超时、恢复后正常（三向验证通过）
- [ ] `docker exec nginx nginx -v` 显示 1.30.2 或更高
- [ ] 重启后规则与集合自动恢复
- [ ] 复扫：高危归零，中危仅保留有明确报备理由的条目

---

# 六、命令速查

```bash
# ── 日常运维 ────────────────────────────────
ipset list harbor_allow                        # 查看白名单及剩余时间
ipset add harbor_allow <IP> timeout 7200       # 临时放行 2 小时
ipset del harbor_allow <IP>                    # 立即撤销
ipset save > /etc/sysconfig/ipset              # 落盘

# ── 排障 ────────────────────────────────────
iptables -L DOCKER-USER -n -v --line-numbers   # 规则与命中计数
iptables -Z DOCKER-USER                        # 计数器归零
iptables -F DOCKER-USER                        # 紧急回滚（清空自定义规则）
yum install -y conntrack-tools
conntrack -D -p tcp --dport 8443               # 清连接跟踪，强制重新匹配
docker network inspect harbor_harbor -f 'br-{{printf "%.12s" .Id}}'

# ── 访问来源分析 ─────────────────────────────
docker logs nginx 2>&1 | awk '
  {p=$4; t=(p ~ /^\/v2\//)?"registry":(p ~ /^\/(api|c)\//)?"ui":"other"; print $1,t}' \
  | sort | uniq -c | sort -rn

# ── 验证（必须从外部机器执行）────────────────
curl -sk -o /dev/null -w "%{http_code}\n" -m 5 https://192.168.23.12/
docker pull harbor.sti.edu.cn/<project>/<image>:<tag>
```

---

*编制日期：2026-08-21 · 依据：绿盟 RSAS 任务 2735 报告（2026-08-17 11:09:54–11:36:53）*
