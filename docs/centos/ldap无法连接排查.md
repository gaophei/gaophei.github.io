从你贴的两张图可以看到两个现象：

1. **应用日志**：
    `连接失败：10.40.8.73:389`，随后 `java.lang.NullPointerException`。——说明 Java 程序没连上 LDAP 389 端口，后续又没有对失败做空指针保护。
2. **Apache Directory Studio（或 LDAP Browser）**：
    `Error while opening connection - Missing schema location in RootDSE, using default schema.`
    ——这通常表示客户端无法从 RootDSE 读到 `namingContexts / subschemaSubentry` 等属性（常见原因是服务器未允许匿名读 RootDSE，或没有绑定 DN 就去读取，或者服务器只监听本地/未对外开放）。

下面给出**定位与修复步骤**，按顺序执行即可快速找出根因。

------

## 一、服务器侧检查（端口/监听/防火墙）

```bash
# 1) slapd 服务状态与监听
systemctl status slapd
ss -lntp | egrep ':389|:636'

# 2) 检查 slapd 监听地址配置
# CentOS/RHEL:
grep -E '^SLAPD_URLS=' /etc/sysconfig/slapd
# Debian/Ubuntu:
grep -E '^SLAPD_SERVICES=' /etc/default/slapd
```

> **期望**：看到包含 `ldap:///`（全部接口监听）或明确监听服务器对外 IP。
>  如果只看到 `ldap://127.0.0.1:389/`，那外部主机无法连入，需要改为：
>  `SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"`（按你的环境选择是否开启 `ldaps:///`），然后 `systemctl restart slapd`。

**防火墙/安全组：**

```bash
# firewalld
firewall-cmd --list-ports
firewall-cmd --add-service=ldap --permanent
firewall-cmd --add-service=ldaps --permanent
firewall-cmd --reload

# 或 iptables/安全组放行 389（以及 636，如启用 LDAPS）
```

------

## 二、网络连通性自检（从客户端或应用主机）

```bash
# 纯连通性
nc -vz 10.40.8.73 389
nc -vz 10.40.8.73 636   # 若启用了 LDAPS
```

> 不通就先排网络（路由/ACL/防火墙/监听）。

------

## 三、LDAP 功能性测试（RootDSE / 命名上下文）

从客户端执行（未启用 TLS 时）：

```bash
# 读取 RootDSE（匿名）
ldapsearch -x -H ldap://10.40.8.73:389 -b "" -s base "+"
```

如果服务器 **要求 StartTLS**，改用：

```bash
ldapsearch -x -ZZ -H ldap://10.40.8.73:389 -b "" -s base "+"
```

或 **走 LDAPS**：

```bash
ldapsearch -x -H ldaps://10.40.8.73:636 -b "" -s base "+"
```

> **期望输出**至少包含：`namingContexts`、`supportedLDAPVersion`、`subschemaSubentry`。
>  若命令成功但这些属性缺失或被拒读，Directory Studio 就会弹出你看到的那个警告。

------

## 四、（常见）权限/ACL 修复：允许读取 RootDSE 与 Subschema

很多环境默认不允许匿名读取 RootDSE 或 `cn=Subschema`，导致客户端报 *Missing schema location*。
 可在 **cn=config** 下给前端数据库加一条通用读取 ACL：

**allow-rootdse.ldif**

```ldif
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcAccess
olcAccess: to dn.base="" by * read
-
add: olcAccess
olcAccess: to dn.base="cn=Subschema" by * read
-
add: olcAccess
olcAccess: to attrs=namingContexts,subschemaSubentry by * read
```

应用变更（在服务器上，以本地域套接字绑定）：

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// -f allow-rootdse.ldif
```

> 之后再用 Directory Studio 连接，警告应消失；即使保留警告，一般也不影响绑定和浏览，但建议按上面方式放行只读 RootDSE 以提高兼容性。

------

## 五、若服务器强制加密（常见策略）

如果配置了：

- `olcSecurity: tls=...` 或 `olcTLS...`（只允许 TLS/要求 StartTLS）
- `olcRequire: authc` / `olcSecurity: simple_bind=128`（禁止明文 simple bind）

那就必须在客户端：

- **389 端口**勾选 **Use StartTLS**（Directory Studio 连接设置里）
- 或者直接用 **636/LDAPS**，并导入 CA 证书到客户端信任库。

------

## 六、Directory Studio 连接建议

- **Network Parameter**：Host `10.40.8.73`，Port `389`；若强制加密则勾选 **StartTLS**，或改用 636 + **LDAPS**。
- **Authentication**：提供可绑定的 DN/密码，例如 `cn=admin,dc=example,dc=com`。
- **Browser Options**：如果 “获取 Base DNs” 失败，**手工填写 Base DN**（如 `dc=example,dc=com`）。

------

## 七、应用（Java）侧健壮性

连接失败时你这边出现了 `NullPointerException`。无论网络/认证是否通过，代码都应做失败保护：

```java
DirContext ctx = null;
try {
    ctx = getContext(); // 内部完成环境、绑定、超时等
} catch (NamingException e) {
    log.error("LDAP connect failed: {}", e.getMessage(), e);
    return; // 直接返回或走降级逻辑
}

// 使用 ctx 前先判空，并在 finally 中安全关闭
```

另外为 JNDI 设置合理的超时与 TLS 选项（示例）：

```java
env.put("com.sun.jndi.ldap.connect.timeout", "5000");
env.put("com.sun.jndi.ldap.read.timeout", "5000");
// 若 StartTLS:
env.put(Context.SECURITY_PROTOCOL, "ssl"); // 或使用 StartTLS 控制
```

------

## 快速排错清单（10 分钟内能确认方向）

1. `ss -lntp`：389 是否对外监听？
2. 客户端 `nc -vz 10.40.8.73 389`：端口是否可达？
3. `ldapsearch -x -H ldap://... -b "" -s base "+"`：能否读到 RootDSE？
4. 如果提示需 TLS：改 `-ZZ` 或走 `ldaps://...:636` 并导入 CA。
5. 若 RootDSE 无 `namingContexts/subschemaSubentry`：按 **第四步** 加 ACL。
6. Directory Studio 里手工填写 **Base DN**，并勾选 **StartTLS**（如需要）。
7. 应用侧补充失败保护，避免 NPE。

------

如果你方便，把下面三条输出贴出来，我可以据此给出更精确的修改建议（包括完整的 `olcAccess` 顺序）：

- `ss -lntp | egrep ':389|:636'`
- `ldapsearch -x -H ldap://10.40.8.73:389 -b "" -s base "+"` 的完整输出/报错
- 你的 Base DN 与绑定 DN（可以打码敏感部分）



=============================================

```
[root@localhost bin]# ./ldapsearch -x -H ldap://10.40.8.73:389 -b "" -s base "+"
# extended LDIF
#
# LDAPv3
# base <> with scope baseObject
# filter: (objectclass=*)
# requesting: +
#

# search result
search: 2
result: 0 Success

# numResponses: 1
[root@localhost bin]#

```



谢谢，`ldapsearch` 的这条输出很关键：

```
./ldapsearch -x -H ldap://10.40.8.73:389 -b "" -s base "+"
# ...
# search result
search: 2
result: 0 Success
# numResponses: 1
```

**解读**：查询 RootDSE（`-b "" -s base`）成功，但**服务器没有返回任何 RootDSE 条目**（连 `dn:`、`namingContexts`、`supportedLDAPVersion` 等一个属性都没有）。
 这正是 Apache Directory Studio/LDAP Browser 报 “**Missing schema location in RootDSE**” 的直接原因；应用侧因此也容易出错（你日志里出现了 NPE）。

按正常情况，RootDSE 至少会返回一些**操作属性**（`namingContexts、subschemaSubentry、supported*` 等）。出现你这种“成功但空结果”的常见原因有两类：

1. **服务器的 RootDSE 读权限被 ACL 拦住**（匿名或未绑定用户对 `dn=""`、`cn=Subschema` 没有 `read/search` 权限）
2. **目录后端/前端配置异常**（极少见：前端数据库 ACL 配置不当、没有任何 suffix、或被代理层非标准转换）

下面给出一个从易到难的**最小化复现与修复流程**。请照着执行并把结果贴出来，我可以据此精确给出最终配置。

------

## A. 再做两条“验证性”查询

1. **显式点名属性**（避免服务器对“+”的兼容性差异）：

```bash
ldapsearch -x -H ldap://10.40.8.73:389 -b "" -s base -LLL \
  "objectClass=*" namingContexts subschemaSubentry supportedLDAPVersion supportedSASLMechanisms vendorName vendorVersion
```

1. **用可用帐号绑定再查 RootDSE**（如果你有管理 DN）：

```bash
ldapsearch -H ldap://10.40.8.73:389 -D "cn=admin,dc=example,dc=com" -W \
  -b "" -s base -LLL "objectClass=*" namingContexts subschemaSubentry supportedLDAPVersion
```

- 若**绑定后能返回**属性，而匿名不能返回 ⇒ 说明是**ACL 权限**问题；
- 若**绑定后仍然空** ⇒ 需要检查前端数据库与监听/代理设置（见 D、E）。

------

## B.（OpenLDAP）最小权限修复：允许只读 RootDSE 与 Subschema

> 这条配置**只放行读取 RootDSE 与 `cn=Subschema`**，不会放开你业务条目的匿名访问，是安全的默认实践。

1. 准备 LDIF：

```ldif
# allow-rootdse.ldif
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcAccess
olcAccess: to dn.base="" by * read
-
add: olcAccess
olcAccess: to dn.base="cn=Subschema" by * read
-
add: olcAccess
olcAccess: to attrs=namingContexts,subschemaSubentry by * read
```

1. 以本地套接字应用（无需密码）：

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// -f allow-rootdse.ldif
```

1. 再次验证：

```bash
ldapsearch -x -H ldap://10.40.8.73:389 -b "" -s base -LLL "objectClass=*"
```

> 期望能看到 `dn:`（空 DN）、`namingContexts`、`subschemaSubentry`、`supportedLDAPVersion` 等。

------

## C. Apache Directory Studio 连接建议（临时绕过）

在 **Connection → Browser Options** 里：

- 若“获取 Base DNs”失败，**手工填写 Base DN**（如 `dc=example,dc=com`）；
- 根据服务器策略勾选 **Use StartTLS** 或直接用 **LDAPS/636**；
- 提供可绑定的 DN/密码，避免匿名访问限制的影响。

------

## D. 若你用的是 **389-Directory Server**（而非 OpenLDAP）

默认也应返回 RootDSE。若被关闭匿名访问且策略较严，可开启仅 RootDSE 的匿名读：

```bash
# 以实例名替换 instance
dsconf instance config replace nsslapd-allow-anonymous-access=on
# 或者仅 RootDSE（不同版本参数名略有差异）
# dsconf instance config replace rootdse_anon_access=on
dsctl instance restart
```

然后重测 A 步。

------

## E. 进一步排查（若 B/D 后仍为空）

1. **确认 slapd 监听与类型**

```bash
ss -lntp | egrep ':389|:636'
slapcat -n 0 | egrep -n 'olcDatabase|olcAccess|olcSuffix'
```

- 看是否有 `olcDatabase={-1}frontend,cn=config`；
- 看业务数据库（mdb/hdb）是否配置了 `olcSuffix: dc=...`（没有 suffix，`namingContexts` 也不会出现）。

1. **排除代理/四层转发问题**
    如果前面挂了反向代理/负载均衡，请直连后端 LDAP 实例测试；极端情况下，非标准代理会把“空条目”当作成功返回。

------

## F. 应用（Java）侧建议（避免 NPE）

即便连接失败，也不应抛出 `NullPointerException`。请在获取 `DirContext` 后做判空与异常处理，并设置合理超时：

```java
Hashtable<String,String> env = new Hashtable<>();
env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
env.put(Context.PROVIDER_URL, "ldap://10.40.8.73:389");
env.put("com.sun.jndi.ldap.connect.timeout", "5000");
env.put("com.sun.jndi.ldap.read.timeout", "5000");
// 如需 StartTLS 或 LDAPS，按需增加设置

DirContext ctx = null;
try {
    ctx = new InitialDirContext(env);
} catch (NamingException e) {
    log.error("LDAP connect failed", e);
    return; // 做好降级
}
```

------

### 接下来请提供

- A 步两条 `ldapsearch` 的输出（尤其是绑定后的结果）
- `slapcat -n 0 | egrep -n 'olcDatabase|olcAccess|olcSuffix'` 的片段（可打码 DN）

我据此给你**准确的 LDIF** 与**ACL 顺序**（OpenLDAP 的 ACL 顺序很关键），确保 Directory Studio 不再报错，应用也能稳定连接。



======================



```
ldap服务器开启了Iptables，需要对以下服务器列表开启389端口的白名单
222.24.203.11
222.24.203.12
222.24.203.13
222.24.203.14
222.24.203.15
222.24.203.16
222.24.203.17
222.24.203.18
222.24.203.19
222.24.203.20
222.24.203.21
222.24.203.22
222.24.203.23
222.24.203.24
222.24.203.25
222.24.203.51
222.24.203.52
222.24.203.53
222.24.203.54
222.24.203.55
222.24.203.56
222.24.203.57
222.24.203.58
222.24.203.59
222.24.203.60

```

好的。既然服务端启用了 **iptables**，而你只想让下面这批来源 IP 能访问 **389/TCP（LDAP）**，推荐两种做法：

- **方案 A（推荐）：`ipset` + 一条 iptables 规则** —— 高效、规则简洁，便于后续批量增删。
- **方案 B：逐条 iptables 规则** —— 无需安装 `ipset`，但规则会很多。

下面给出**可直接运行的命令/脚本**，默认 **CentOS/RHEL 7/8**（`iptables-services`），Debian/Ubuntu 的保存方式在文末。

------

## 白名单列表（放到脚本里即可）

```
222.24.203.11
222.24.203.12
222.24.203.13
222.24.203.14
222.24.203.15
222.24.203.16
222.24.203.17
222.24.203.18
222.24.203.19
222.24.203.20
222.24.203.21
222.24.203.22
222.24.203.23
222.24.203.24
222.24.203.25
222.24.203.51
222.24.203.52
222.24.203.53
222.24.203.54
222.24.203.55
222.24.203.56
222.24.203.57
222.24.203.58
222.24.203.59
222.24.203.60
```

------

## 方案 A：`ipset` + iptables（推荐）

**优点**：一条规则搞定；后续增删只改 `ipset`，无需动 iptables。

```bash
# 0) 先备份现有规则（强烈建议）
iptables-save > /root/iptables.backup.$(date +%F-%H%M%S)

# 1) 安装 ipset（若未安装）
yum -y install ipset || true    # CentOS/RHEL
# Debian/Ubuntu: apt-get update && apt-get install -y ipset

# 2) 创建或清空白名单集合
ipset list -n | grep -qw LDAP_WHITELIST || ipset create LDAP_WHITELIST hash:ip
ipset flush LDAP_WHITELIST

# 3) 批量加入白名单 IP（可把这些命令粘贴执行）
ipset add LDAP_WHITELIST 222.24.203.11
ipset add LDAP_WHITELIST 222.24.203.12
ipset add LDAP_WHITELIST 222.24.203.13
ipset add LDAP_WHITELIST 222.24.203.14
ipset add LDAP_WHITELIST 222.24.203.15
ipset add LDAP_WHITELIST 222.24.203.16
ipset add LDAP_WHITELIST 222.24.203.17
ipset add LDAP_WHITELIST 222.24.203.18
ipset add LDAP_WHITELIST 222.24.203.19
ipset add LDAP_WHITELIST 222.24.203.20
ipset add LDAP_WHITELIST 222.24.203.21
ipset add LDAP_WHITELIST 222.24.203.22
ipset add LDAP_WHITELIST 222.24.203.23
ipset add LDAP_WHITELIST 222.24.203.24
ipset add LDAP_WHITELIST 222.24.203.25
ipset add LDAP_WHITELIST 222.24.203.51
ipset add LDAP_WHITELIST 222.24.203.52
ipset add LDAP_WHITELIST 222.24.203.53
ipset add LDAP_WHITELIST 222.24.203.54
ipset add LDAP_WHITELIST 222.24.203.55
ipset add LDAP_WHITELIST 222.24.203.56
ipset add LDAP_WHITELIST 222.24.203.57
ipset add LDAP_WHITELIST 222.24.203.58
ipset add LDAP_WHITELIST 222.24.203.59
ipset add LDAP_WHITELIST 222.24.203.60

# 4) 关键防火墙规则（插入在较前位置）
# 允许已建立连接
iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -I INPUT 1 -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许本地回环
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || \
iptables -I INPUT 2 -i lo -j ACCEPT

# 允许白名单访问 LDAP 389/TCP
iptables -C INPUT -p tcp --dport 389 -m set --match-set LDAP_WHITELIST src -j ACCEPT 2>/dev/null || \
iptables -I INPUT 3 -p tcp --dport 389 -m set --match-set LDAP_WHITELIST src -j ACCEPT

# （可选）如果你也用到了 CLDAP，放开 389/UDP
# iptables -C INPUT -p udp --dport 389 -m set --match-set LDAP_WHITELIST src -j ACCEPT 2>/dev/null || \
# iptables -I INPUT 4 -p udp --dport 389 -m set --match-set LDAP_WHITELIST src -j ACCEPT

# 5) 严格限制：拒绝其他来源访问 389（放在接受规则之后）
iptables -C INPUT -p tcp --dport 389 -j DROP 2>/dev/null || iptables -A INPUT -p tcp --dport 389 -j DROP
# iptables -C INPUT -p udp --dport 389 -j DROP 2>/dev/null || iptables -A INPUT -p udp --dport 389 -j DROP

# 6) 持久化保存
iptables-save > /etc/sysconfig/iptables          # CentOS/RHEL（需安装 iptables-services）
ipset save    > /etc/sysconfig/ipset
systemctl enable iptables 2>/dev/null || true
# Debian/Ubuntu:
# apt-get install -y iptables-persistent
# netfilter-persistent save
```

> **后续维护**
>
> - 增加 IP：`ipset add LDAP_WHITELIST 1.2.3.4 && ipset save > /etc/sysconfig/ipset`
> - 删除 IP：`ipset del LDAP_WHITELIST 1.2.3.4 && ipset save > /etc/sysconfig/ipset`
> - 查看：`ipset list LDAP_WHITELIST`

------

## 方案 B：不用 ipset，逐条 iptables（直观但规则多）

```bash
iptables-save > /root/iptables.backup.$(date +%F-%H%M%S)

# 允许已建立连接、回环（如未配置）
iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT -i lo -j ACCEPT

# 白名单逐条放行 389/TCP
for ip in 222.24.203.{11..25} 222.24.203.{51..60}; do
  iptables -I INPUT -p tcp -s $ip --dport 389 -j ACCEPT
  # 如需 UDP：
  # iptables -I INPUT -p udp -s $ip --dport 389 -j ACCEPT
done

# 最后拒绝其他来源访问 389（确保位于放行规则之后）
iptables -A INPUT -p tcp --dport 389 -j DROP
# iptables -A INPUT -p udp --dport 389 -j DROP

iptables-save > /etc/sysconfig/iptables
```

------

## 验证

从任一白名单主机：

```bash
nc -vz <LDAP服务器IP> 389
# 或
ldapsearch -x -H ldap://<LDAP服务器IP>:389 -b "" -s base -LLL namingContexts
```

从非白名单主机应连接失败。

------

## 注意事项

1. **规则顺序**很重要：白名单 `ACCEPT` 要在最终的 `DROP` 之前。
2. 如启用了 **LDAPS (636/TCP)** 或 **StartTLS**，相应端口也要按同样方式放行。
3. 如果服务器还使用 **firewalld**，请确认它未接管规则（只用其中一种：iptables *或* firewalld）。
4. Debian/Ubuntu 持久化：`apt-get install -y iptables-persistent && netfilter-persistent save`。
5. 有 IPv6 需求时，记得用 `ip6tables` 做同样的白名单。

------

如果你愿意，我可以把上述内容打包成**一键脚本**（支持增删 IP、回滚规则），直接给你下载并执行。需要的话告诉我系统版本（例如 CentOS 7/8 或 Ubuntu 20.04），我就生成对应脚本。



```
对以下废弃节点的iptables去除掉：
-A INPUT -s 10.40.8.109/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.150/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.128/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.129/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.113/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.114/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.115/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.116/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.117/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.136/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.137/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.138/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.139/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.140/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.141/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.142/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.143/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 10.40.8.144/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 222.24.211.160/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 222.24.211.161/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
-A INPUT -s 222.24.211.162/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT

```





没问题。下面给你一段**可直接执行的一键脚本**，把列出的这些“废弃节点”对应的 389/TCP 放行规则从 `iptables` 里删除，并在最后持久化保存（CentOS/RHEL 的 `/etc/sysconfig/iptables`），同时打印当前 INPUT 链供核对。

> 脚本按你给出的**完整匹配条件**删除：`-s <IP>/32 -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT`
>  如果规则不存在，会跳过并提示。

```bash
# --------------- rm_ldap_old_rules.sh ---------------
cat > /root/rm_ldap_old_rules.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 0) 备份现有规则
BACKUP="/root/iptables.backup.$(date +%F-%H%M%S).rules"
iptables-save > "$BACKUP"
echo "Saved current rules to $BACKUP"

# 1) 待移除的来源 IP 清单
IPS=(
10.40.8.109
10.40.8.150
10.40.8.128
10.40.8.129
10.40.8.113
10.40.8.114
10.40.8.115
10.40.8.116
10.40.8.117
10.40.8.136
10.40.8.137
10.40.8.138
10.40.8.139
10.40.8.140
10.40.8.141
10.40.8.142
10.40.8.143
10.40.8.144
222.24.211.160
222.24.211.161
222.24.211.162
)

# 2) 按给定匹配条件删除 TCP/389 放行规则
for ip in "${IPS[@]}"; do
  if iptables -C INPUT -s "${ip}/32" -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT 2>/dev/null; then
    iptables -D INPUT -s "${ip}/32" -p tcp -m state --state NEW -m tcp --dport 389 -j ACCEPT
    echo "Removed rule: ${ip} -> tcp/389"
  else
    echo "No matching rule found for ${ip} (tcp/389)"
  fi

  # 如果你曾经也放行过 udp/389（很少见），取消下面三行注释一并删除：
  # if iptables -C INPUT -s "${ip}/32" -p udp -m state --state NEW --dport 389 -j ACCEPT 2>/dev/null; then
  #   iptables -D INPUT -s "${ip}/32" -p udp -m state --state NEW --dport 389 -j ACCEPT
  #   echo "Removed rule: ${ip} -> udp/389"
  # fi
done

# 3) 持久化（CentOS/RHEL；Debian/Ubuntu 见下方说明）
iptables-save > /etc/sysconfig/iptables || true

echo
echo "Current INPUT chain (first 80 lines):"
iptables -L INPUT -n --line-numbers | sed -n '1,80p'
EOF

chmod +x /root/rm_ldap_old_rules.sh
/root/rm_ldap_old_rules.sh
# --------------- end ---------------
```

### 验证与注意

1. **验证**：

   ```bash
   iptables -S INPUT | grep -- "-p tcp" | grep -- "--dport 389"
   iptables -L INPUT -n --line-numbers
   ```

   确认这些来源 IP 的 `ACCEPT` 规则已不在，且（若你有）最终的 `DROP`/`REJECT` 规则仍位于合适位置。

2. **Debian/Ubuntu 持久化**：
    安装并保存：`apt-get install -y iptables-persistent && netfilter-persistent save`

3. **与 firewalld 的关系**：
    若服务器启用了 `firewalld`，建议只用**其中一种**防火墙工具。可检查：`systemctl is-active firewalld`。若在用 firewalld，请改用 `firewall-cmd` 管理规则或停用 firewalld 仅用 iptables。

4. **回滚**：
    如需回滚：`iptables-restore < /root/iptables.backup.YYYY-MM-DD-HHMMSS.rules`

如果你想最终把 389 的放行统一迁移到 **ipset 白名单**（后续维护更省事），我可以在这些删除完成后，按你的“保留节点清单”给出一条 `ipset` 规则和持久化步骤。需要的话把需要保留的 IP 发我即可。

