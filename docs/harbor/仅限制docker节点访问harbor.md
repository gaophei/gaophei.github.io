要配置防火墙，使得仅允许指定的三台服务器（`192.168.100.101`, `192.168.100.102`, `192.168.100.103`）访问位于 `192.168.100.100` 上的 NFS 和 Harbor 服务，你可以使用 `firewalld` 来实现这一目标。具体步骤如下：

### 1. **开放 NFS 端口**
NFS 使用的端口主要包括：
- `2049` (NFS)
- `111` (rpcbind)
  

你需要确保只允许这三台服务器访问 NFS 所需的端口。

### 2. **开放 Harbor 端口**
Harbor 的 HTTP 服务默认使用 `80` 端口，你需要为这三台服务器开放该端口。

### 3. **防火墙配置步骤**
确保 `firewalld` 已经启动并且配置生效。然后你可以使用以下命令进行配置。

#### 1) 启动并启用 `firewalld`
如果 `firewalld` 没有启动，可以用以下命令启用并启动：
```bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
```

#### 2) 配置 NFS 服务防火墙规则

为 NFS 服务的 `2049` 和 `111` 端口添加规则，允许来自 `192.168.100.101`, `192.168.100.102`, `192.168.100.103` 这三台服务器的访问：
```bash
# 允许 192.168.100.101 访问 NFS 的端口 2049 和 rpcbind 端口 111
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.101" port protocol="tcp" port="2049" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.101" port protocol="tcp" port="111" accept'

# 允许 192.168.100.102 访问 NFS 的端口 2049 和 rpcbind 端口 111
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.102" port protocol="tcp" port="2049" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.102" port protocol="tcp" port="111" accept'

# 允许 192.168.100.103 访问 NFS 的端口 2049 和 rpcbind 端口 111
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.103" port protocol="tcp" port="2049" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.103" port protocol="tcp" port="111" accept'
```

#### 3) 配置 Harbor 服务防火墙规则

为 Harbor 的 `80` 端口添加规则，允许来自这三台服务器的访问：
```bash
# 允许 192.168.100.101 访问 Harbor 的 80 端口
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.101" port protocol="tcp" port="80" accept'

# 允许 192.168.100.102 访问 Harbor 的 80 端口
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.102" port protocol="tcp" port="80" accept'

# 允许 192.168.100.103 访问 Harbor 的 80 端口
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.100.103" port protocol="tcp" port="80" accept'
```

#### 4) 拒绝其他所有访问

为了确保只允许这三台服务器访问 `192.168.100.100` 上的 NFS 和 Harbor 服务，拒绝其他所有主机的访问，你可以使用以下命令：
```bash
# 拒绝其他所有 IP 访问 NFS 端口 2049 和 rpcbind 端口 111
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port protocol="tcp" port="2049" reject'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port protocol="tcp" port="111" reject'

# 拒绝其他所有 IP 访问 Harbor 的 80 端口
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port protocol="tcp" port="80" reject'
```

#### 5) 重新加载防火墙规则
执行完上述命令后，重新加载防火墙配置使其生效：
```bash
sudo firewall-cmd --reload
```

### 4. **验证防火墙配置**
你可以使用以下命令查看配置是否已经成功应用：
```bash
sudo firewall-cmd --list-all
```

检查 NFS 端口（`2049` 和 `111`）以及 Harbor 端口（`80`）是否已经按照预期配置。

### 总结
通过上述步骤，你已经配置了 `firewalld`，确保仅允许 `192.168.100.101`, `192.168.100.102`, `192.168.100.103` 三台服务器访问 `192.168.100.100` 上的 NFS 和 Harbor 服务。同时，你也拒绝了其他 IP 地址对这些服务的访问。这将有效防止未经授权的主机连接到你的 NFS 和 Harbor 服务。