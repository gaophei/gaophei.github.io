好的，我将为你整理在 Oracle Linux 7.9 系统中，只修改 Oracle 19c RAC 两个节点 Public IP（从 172.29.84.8 和 172.29.84.9 改为 172.29.85.10 和 172.29.85.11）且主机名不变的具体操作步骤。稍等片刻，我整理好后会通知你查看。

# Oracle RAC 两节点 Public IP 修改步骤（Oracle Linux 7.9 & GI 19c）

在Oracle Linux 7.9操作系统下，将Oracle 19c RAC两节点的Public IP从`172.29.84.8/172.29.84.9`修改为`172.29.85.10/172.29.85.11`，主机名不变（VIP和SCAN地址不变）。以下是详细的操作指南。**注意：**确保新Public IP与VIP/SCAN位于同一网段，否则还需额外修改VIP/SCAN（本指南不涉及） 。

## 1. 修改前的准备和检查

- **确认集群状态：**在变更前，验证RAC集群当前运行正常。使用Grid用户运行集群检查命令，例如：

  ```bash
  $ crsctl check cluster -all    # 检查各节点集群状态
  $ crsctl stat res -t           # 查看集群资源状态表
  ```

  确认没有错误，并记录当前Public网络配置：

  ```bash
  $ oifcfg getif
  ```

  该命令会列出网卡接口及其对应的网络段和角色（public或private） ([〖Oracle〗Oracle 19c RAC修改网络 - 课程体系 - 云贝教育](https://www.yunbee.net/Home/News/detail/article_id/550.html#:~:text=[grid@racdb01 ,0  global  cluster_interconnect%2Casm))。

- **备份重要配置：**为防止意外，备份以下配置文件：

  ```bash
  # 备份GPnP配置文件（在每个节点执行）
  $ cp $GRID_HOME/gpnp/profiles/peer/profile.xml $GRID_HOME/gpnp/profiles/peer/profile.xml.bak
  
  # 备份hosts文件（在每个节点执行）
  $ cp /etc/hosts /etc/hosts.bak                      ([Oracle 11g RAC 修改各类IP地址-腾讯云开发者社区-腾讯云](https://cloud.tencent.com/developer/article/1431627#:~:text=%E6%A0%B9%E6%8D%AE%E9%9C%80%E6%B1%82%EF%BC%8C%E5%85%88%E5%A4%87%E4%BB%BD%E5%8E%9F%E6%9D%A5%E7%9A%84%2Fetc%2Fhosts%E6%96%87%E4%BB%B6%E4%B8%BA%2Fetc%2Fhosts))
  ```

  *说明：* `$GRID_HOME`为Grid Infrastructure安装路径，例如`/u01/app/19.3.0/grid`。`/etc/hosts`备份后方便出错时还原 ([Oracle 11g RAC 修改各类IP地址-腾讯云开发者社区-腾讯云](https://cloud.tencent.com/developer/article/1431627#:~:text=根据需求，先备份原来的%2Fetc%2Fhosts文件为%2Fetc%2Fhosts))。

- **规划网络变更：**确保新IP地址未被占用，并有适当的网络掩码和网关。确定Public网卡接口名称（可通过`ip addr`或`ifconfig`查看当前`172.29.84.x`所属接口）。另外，如果计划在修改后重启操作系统，为避免RAC开机自动启动，可在变更前以root用户执行：

  ```bash
  # （可选）禁用集群自动启动
  # 在所有节点执行：
  # crsctl disable crs
  ```

  这将暂时禁止OS引导时启动GI。变更完成后可用`crsctl enable crs`恢复。

## 2. 正确停止数据库和集群服务

1. **停止数据库实例和监听：**以Oracle用户登录节点（任一节点即可控制集群数据库），执行以下命令关闭所有数据库实例和相关监听：

   ```bash
   $ srvctl stop database -d <数据库名> -o immediate   # 立即关闭RAC上的数据库实例
   $ srvctl stop listener -node <节点名>               # 可选：分别停止各节点监听
   ```

   确认数据库和监听已停止。

2. **停止集群服务：**以root用户在每个节点停止Grid Infrastructure集群服务：

   ```bash
   # 在节点1:
   # crsctl stop crs
   # 在节点2:
   # crsctl stop crs
   ```

   也可在任一节点执行`crsctl stop cluster -all`一次性停止整个集群。上述命令将依次停止该节点上的所有集群资源和CRS守护进程 ([Oracle 19C RAC 修改IP地址 -- cnDBA.cn_中国DBA社区](https://www.cndba.cn/hbhe0316/article/5044#:~:text=[oracle@rac01 ,managed resources on))。等待命令完成后，用状态检查命令验证集群已完全停止：

   ```bash
   # 期望返回无法通信的错误，表示CRS已停止
   $ crsctl stat res -t
   CRS-4535: Cannot communicate with Cluster Ready Services ([Oracle 19C RAC 修改IP地址 -- cnDBA.cn_中国DBA社区](https://www.cndba.cn/hbhe0316/article/5044#:~:text=%5Broot%40rac01%20~%5D,failed%2C%20or%20completed%20with%20errors))
   ```

## 3. 修改系统网络配置和 `/etc/hosts` 文件

以下操作需要在**两个节点**分别执行：

- **修改`/etc/hosts`：**编辑每个节点的`/etc/hosts`文件，将其中Public主机名对应的IP更改为新地址：

  ```bash
  # 编辑/etc/hosts，在节点1将172.29.84.8改为172.29.85.10，在节点2将172.29.84.9改为172.29.85.11
  ```

  确保更改后的主机名解析正确，无重复冲突。*示例：*如果原文件包含：

  ```
  172.29.84.8   db-node1.example.com   db-node1
  172.29.84.9   db-node2.example.com   db-node2
  172.29.84.10  db-node1-vip
  172.29.84.11  db-node2-vip
  ```

  修改后应为：

  ```
  172.29.85.10  db-node1.example.com   db-node1
  172.29.85.11  db-node2.example.com   db-node2
  172.29.84.10  db-node1-vip           # VIP保持不变
  172.29.84.11  db-node2-vip           # SCAN条目若有则保持不变
  ```

  *注意：*不要修改VIP和SCAN相关的行（本次未变更）。

- **修改网络接口IP：**编辑Public网络接口的配置文件（通常位于`/etc/sysconfig/network-scripts/ifcfg-<接口名>`）。将其中的IP地址更新为新Public IP，并相应调整网络掩码和网关（如有需要）：

  ```
  DEVICE=<接口名>
  BOOTPROTO=static
  ONBOOT=yes
  IPADDR=172.29.85.10        # 节点1新IP（节点2填172.29.85.11）
  NETMASK=255.255.255.0      # 若网段变化，调整子网掩码
  GATEWAY=172.29.85.1        # 根据新网络设置网关
  DNS1=<DNS服务器IP>         # 如果使用DNS解析
  ```

  将文件保存退出。建议同时确认私有网络接口配置未发生变化。

- **使新配置生效：**重启网络服务或网卡接口以应用新IP。**注：该操作会中断当前连接，建议通过控制台执行。** 在每个节点执行：

  ```bash
  # 重启网络服务（适用于使用network服务管理网络的系统）
  # systemctl restart network
  
  # 或仅重启具体接口：
  # ifdown <接口名>; ifup <接口名>
  ```

  执行后，用 `ip addr` 或 `ifconfig` 核实Public接口已绑定新IP地址。

## 4. 使用 OIFCFG 更新 Oracle 网络接口绑定

Public IP网段变更后，需要更新Oracle集群的网络接口配置，以使Clusterware识别新Public网络。操作步骤如下：

1. **启动集群到维护模式：\**由于先前已停止集群，可选择在\**单个节点**以维护模式启动GI，以更新配置而不自动加入集群。在节点1以root用户执行：

   ```bash
   # 不启动CRS守护进程的独占模式启动（11.2.0.2+版本需要 -nocrs 参数）
   # crsctl start crs -excl -nocrs
   ```

   以上命令启动Oracle High Availability Services但不启动集群资源，以便进行配置更改 ([Oracle RAC Interview Questions | orasolution](https://orasolution.wordpress.com/2019/02/25/oracle-rac-interview-questions/#:~:text=crsctl start crs ))。

2. **更新Public网络定义：**以Grid用户（或root用户）在节点1执行以下命令：

   ```bash
   $ oifcfg getif
   # 确认当前Public网卡名称和旧网络段，例如输出包含：
   # <iface>  172.29.84.0  global  public
   
   $ oifcfg delif -global <iface>/172.29.84.0        # 删除旧的Public网络绑定 ([〖Oracle〗Oracle 19c RAC修改网络 - 课程体系 - 云贝教育](https://www.yunbee.net/Home/News/detail/article_id/550.html#:~:text=oifcfg%20delif%20))
   
   $ oifcfg setif -global <iface>/172.29.85.0:public  # 添加新的Public网络绑定 ([〖Oracle〗Oracle 19c RAC修改网络 - 课程体系 - 云贝教育](https://www.yunbee.net/Home/News/detail/article_id/550.html#:~:text=oifcfg%20delif%20))
   
   $ oifcfg getif
   # 核实输出已更新为新网段，例如：
   # <iface>  172.29.85.0  global  public
   ```

   上述命令将Oracle集群的Public网络接口从原`172.29.84.0`网段更新为`172.29.85.0`网段。 ([〖Oracle〗Oracle 19c RAC修改网络 - 课程体系 - 云贝教育](https://www.yunbee.net/Home/News/detail/article_id/550.html#:~:text=oifcfg delif ))

3. **关闭维护模式：**配置更新后，停止节点1的GI以退出独占模式：

   ```bash
   # crsctl stop crs
   ```

   此时所有节点的集群服务仍是停止状态，新网络配置已写入集群的OCR配置。

## 5. 启动服务并验证集群状态

1. **启动集群服务：**在两个节点依次启动Grid Infrastructure集群服务（以root用户执行）：

   ```bash
   # 在节点1和节点2分别执行
   # crsctl start crs             ([Oracle 19C RAC 修改IP地址 -- cnDBA.cn_中国DBA社区](https://www.cndba.cn/hbhe0316/article/5044#:~:text=5))
   ```

   如果之前禁用了开机自动启动（执行过`disable crs`），建议现在恢复：

   ```bash
   # 在每个节点启用集群自启动
   # crsctl enable crs            ([Oracle 19C RAC 修改IP地址 -- cnDBA.cn_中国DBA社区](https://www.cndba.cn/hbhe0316/article/5044#:~:text=8%EF%BC%89%E4%BD%BF%E7%94%A8root%E7%94%A8%E6%88%B7%E6%BF%80%E6%B4%BB%E9%9B%86%E7%BE%A4%E5%B9%B6%E9%87%8D%E6%96%B0%E5%90%AF%E5%8A%A8%E9%9B%86%E7%BE%A4%E4%B8%AD%E6%89%80%E6%9C%89%E8%8A%82%E7%82%B9%EF%BC%88%E6%AF%8F%E4%B8%AA%E8%8A%82%E7%82%B9%EF%BC%89))
   ```

   （如不重启节点，该命令主要确保下次引导时自动启动。）

2. **验证集群资源：**当两个节点的CRS服务均启动后，检查各资源状态：

   ```bash
   $ crsctl stat res -t    # 查看所有资源应为ONLINE状态
   $ olsnodes -n -i        # 验证集群节点名和节点IP信息
   $ srvctl status nodeapps -node <节点名>   # 检查VIP、监听状态
   ```

   确认Public网络相关的资源（例如各节点VIP、SCAN VIP、监听器等）均在正常运行状态。如有资源未启动，可用`srvctl start <资源>`启动相应资源 ([Oracle 19C RAC 修改IP地址 -- cnDBA.cn_中国DBA社区](https://www.cndba.cn/hbhe0316/article/5044#:~:text=5))。若VIP或SCAN未上线，需检查其IP是否在Public网段内以及前述配置是否正确。

3. **启动数据库服务：**最后，以Oracle用户启动数据库实例及相关服务：

   ```bash
   $ srvctl start database -d <数据库名>
   $ srvctl start listener             # 如监听未随集群自动启动
   ```

   然后使用`srvctl status database -d <数据库名>`确认所有实例状态为`ONLINE`。

4. **功能验证：**尝试通过新Public IP或主机名在各节点之间互相ping，确保网络联通。同时通过VIP/SCAN连接数据库，验证RAC对外服务正常。至此，Public IP修改操作完成。

**参考资料：**以上步骤和命令基于Oracle官方建议及实践经验 ([Oracle 19C RAC 修改IP地址 -- cnDBA.cn_中国DBA社区](https://www.cndba.cn/hbhe0316/article/5044#:~:text=[oracle@rac01 ,managed resources on)) ([Oracle RAC Interview Questions | orasolution](https://orasolution.wordpress.com/2019/02/25/oracle-rac-interview-questions/#:~:text=crsctl start crs )) ([〖Oracle〗Oracle 19c RAC修改网络 - 课程体系 - 云贝教育](https://www.yunbee.net/Home/News/detail/article_id/550.html#:~:text=oifcfg delif ))，适用于Oracle Linux 7.9环境下的Oracle 19c RAC集群配置。