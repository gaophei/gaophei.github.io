下面详细给出 Oracle 11g R2 RAC 两节点 Public IP 从 **172.29.84.8 和 172.29.84.9** 修改为 **172.29.85.10 和 172.29.85.11** 的具体步骤：

---

## 一、前期准备

1. **备份 RAC 环境**
   - 对数据库进行完整备份。
   - 对 OCR 和 Voting Disk 进行备份：
     ```bash
     # root用户执行备份OCR
     ocrconfig -manualbackup
     ```

2. **确认新 IP 可用性**
   确认新IP地址（172.29.85.10、172.29.85.11）在网络中可用，并且未被占用。

3. **记录当前配置**
   检查并记录当前 RAC 配置：
   ```bash
   crsctl stat res -t
   srvctl config vip -n <节点1名>
   srvctl config vip -n <节点2名>
   oifcfg getif
   ```

---

## 二、具体修改步骤

### **步骤1：停止 RAC 集群服务**

在两个节点上分别以 root 用户执行：

```bash
crsctl stop crs
```

确认集群服务已停止：

```bash
crsctl check crs
```

---

### **步骤2：修改操作系统网络配置**

分别在两个节点上执行：

- 节点1（原IP：172.29.84.8 改为 172.29.85.10）
- 节点2（原IP：172.29.84.9 改为 172.29.85.11）

以 Linux 为例，修改网络配置文件：

```bash
vi /etc/sysconfig/network-scripts/ifcfg-ethX
```

修改内容：

```bash
IPADDR=172.29.85.10   # 节点1配置
NETMASK=255.255.255.0
GATEWAY=<你的网关地址>
```

```bash
IPADDR=172.29.85.11   # 节点2配置
NETMASK=255.255.255.0
GATEWAY=<你的网关地址>
```

重启网络服务：

```bash
systemctl restart network
```

验证修改：

```bash
ip addr show
ping <对端节点新IP>  # 确认两节点网络通信正常
```

---

### **步骤3：修改 Oracle Clusterware 网络配置**

在任意节点上，以 grid 用户执行：

（1）先删除旧的 public 网络配置：

```bash
oifcfg delif -global ethX/172.29.84.0
```

（2）添加新的 public 网络配置：

```bash
oifcfg setif -global ethX/172.29.85.0:public
```

（3）验证配置：

```bash
oifcfg getif
```

输出应类似：

```
ethX  172.29.85.0  global  public
ethY  192.168.X.X  global  cluster_interconnect
```

---

### **步骤4：修改 VIP 地址**

以 grid 用户执行：

```bash
# 修改节点1的VIP
srvctl modify vip -n <节点1名> -A 172.29.85.10/255.255.255.0/<网卡名>

# 修改节点2的VIP
srvctl modify vip -n <节点2名> -A 172.29.85.11/255.255.255.0/<网卡名>
```

**注意：**
- `-A` 参数格式为：IP地址/子网掩码/网卡名，如：`172.29.85.10/255.255.255.0/ethX`

验证修改结果：

```bash
srvctl config vip -n <节点1名>
srvctl config vip -n <节点2名>
```

---

### **步骤5：启动 RAC 集群服务**

在两个节点上分别以 root 用户启动集群服务：

```bash
crsctl start crs
```

检查集群状态：

```bash
crsctl stat res -t
```

确认 VIP 和其他资源均正常运行。

---

### **步骤6：后续检查与确认**

- 检查监听状态：
```bash
srvctl status listener
```

- 检查 VIP 状态：
```bash
srvctl status vip -n <节点1名>
srvctl status vip -n <节点2名>
```

- 检查数据库服务状态：
```bash
srvctl status database -d <数据库名>
```

- 从客户端进行连接测试，确保连接正常：
```bash
sqlplus system@<数据库服务名>
```

---

## 三、注意事项

- 本操作涉及集群关键配置，建议在计划维护窗口内进行。
- 操作期间务必确保所有节点网络连通性。
- 操作前后务必检查日志（如：`$GRID_HOME/log`、`$ORACLE_BASE/diag`）以确保无异常。
- 如果出现问题，请及时回退网络配置和集群配置，或联系 Oracle 技术支持。

以上步骤详细描述了 Oracle 11g R2 RAC 环境下两个节点 Public IP 的修改过程，按照顺序谨慎执行即可顺利完成 IP 地址变更。