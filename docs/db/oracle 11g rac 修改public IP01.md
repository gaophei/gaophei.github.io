要在 Oracle 11g R2 RAC 两个节点上将 Public IP 从 172.29.84.8 和 172.29.84.9 修改为 172.29.85.10 和 172.29.85.11，请按照以下步骤进行：

**注意**：在进行任何更改之前，强烈建议备份 OCR（Oracle Cluster Registry）和 GPNP（Grid Plug and Play）配置文件，以防止意外情况导致的数据丢失。

1. **备份 OCR 和 GPNP 配置文件**：

   在任一节点上，以 `root` 用户执行以下命令手动备份 OCR：

   ```bash
   /u01/app/11.2.0/grid/bin/ocrconfig -manualbackup
   ```

   查看 OCR 的手动备份：

   ```bash
   /u01/app/11.2.0/grid/bin/ocrconfig -showbackup
   ```

   以 `grid` 用户在两个节点上备份 GPNP 配置文件：

   ```bash
   cd $ORACLE_HOME/gpnp/`hostname`/profiles/peer/
   cp -p profile.xml profile.xml.bak
   ```

2. **停止 Oracle 集群管理软件**：

   在所有节点上，以 `root` 用户依次执行以下命令：

   - 关闭监听器：

     ```bash
     su - grid
     lsnrctl stop
     ```

   - 关闭数据库实例：

     ```bash
     srvctl stop database -d <数据库名>
     ```

   - 关闭集群服务：

     ```bash
     /u01/app/11.2.0/grid/bin/crsctl stop has
     ```

3. **修改操作系统网络配置**：

   在两个节点上，执行以下操作：

   - 修改 `/etc/hosts` 文件，更新 Public IP 地址。例如，将以下内容：

     ```
     172.29.84.8   rac1
     172.29.84.9   rac2
     ```

     修改为：

     ```
     172.29.85.10  rac1
     172.29.85.11  rac2
     ```

   - 修改网络接口配置文件（例如 `/etc/sysconfig/network-scripts/ifcfg-eth0`），更新 `IPADDR` 为新的 IP 地址：

     ```bash
     vi /etc/sysconfig/network-scripts/ifcfg-eth0
     ```

     将 `IPADDR` 修改为新的 IP 地址，例如：

     ```
     IPADDR=172.29.85.10
     ```

   - 重启网络服务使更改生效：

     ```bash
     service network restart
     ```

4. **更新 Oracle 集群配置**：

   如果仅修改了 Public IP 地址，而未更改网络接口名称、子网或网络掩码信息，则无需在 Oracle 集群中进行额外的配置更改。否则，需要使用 `oifcfg` 工具更新网络接口配置。

   - 查看当前的网络接口配置：

     ```bash
     /u01/app/11.2.0/grid/bin/oifcfg getif
     ```

   - 如果需要修改网络接口，先删除旧的接口配置：

     ```bash
     /u01/app/11.2.0/grid/bin/oifcfg delif -global eth0/172.29.84.0
     ```

   - 添加新的接口配置：

     ```bash
     /u01/app/11.2.0/grid/bin/oifcfg setif -global eth0/172.29.85.0:public
     ```

5. **启动 Oracle 集群管理软件**：

   在所有节点上，以 `root` 用户执行以下命令启动集群服务：

   ```bash
   /u01/app/11.2.0/grid/bin/crsctl start has
   ```

6. **验证配置**：

   - 检查网络接口的 IP 地址是否已正确更新：

     ```bash
     ifconfig eth0
     ```

   - 使用 `crsctl` 和 `srvctl` 命令检查集群资源的状态，确保所有资源都正常运行：

     ```bash
     /u01/app/11.2.0/grid/bin/crsctl status resource -t
     ```

     ```bash
     srvctl status database -d <数据库名>
     ```

   - 确认 VIP 和 SCAN IP 地址是否在正确的子网范围内，并且能够正常解析和访问。

**注意事项**：

- 确保所有节点上的 `/etc/hosts` 文件和 DNS 配置已同步更新，以避免解析问题。
- 如果 VIP（虚拟 IP）和 SCAN IP 地址也需要更改，请参考相关文档，按照类似步骤进行修改。
- 在生产环境中进行上述操作前，建议在测试环境中验证所有步骤，以确保不会影响业务运行。

参考资料：

- [Oracle 11g RAC R2 for Linux 修改 Public、VIP IP、主机名](https://www.cnblogs.com/hmwh/p/8855956.html)
- [Oracle 11gR2 RAC 网络配置，更改 Public IP、VIP 和 SCAN IP](https://blog.csdn.net/cf7923/article/details/83515862)
- [Oracle RAC 11g R2 修改 Public IP、VIP、SCAN IP 全过程记录](https://www.modb.pro/db/41688)

请根据实际情况调整上述步骤，并在操作前确保已充分备份和测试。