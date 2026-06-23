# Oracle 19C RAC 安装手册 v3.0 历史日志归档

> 本文件由 v2.7.3 定稿候选版纯搬运生成。归档内容仅供追溯、审计和故障复盘,禁止作为主流程直接照抄执行。执行口径以 v3.0 主手册正文为准。

| 归档编号 | 来源章节 | 说明 |
| -------- | -------- | ---- |
| LOG-03-06 | ### 3.6. root脚本执行日志 | 3.6 root脚本执行日志 |
| LOG-03-07 | ### 3.7. 集群状态检查 | 3.7 集群状态检查长回显 |
| LOG-05-02 | ### 5.2. 执行root.sh脚本记录 | 5.2 DB root.sh脚本记录 |
| LOG-05-03 | ### 5.3. 查看集群状态 | 5.3 DB软件安装后集群状态长回显 |
| LOG-06-02 | ### 6.2. 查看集群状态 | 6.2 建库后集群状态长回显 |
| LOG-07-RU | ### 7.0.6.历史执行记录说明 | 7.1/7.2 19.20与19.21 RU历史执行记录 |
| LOG-11-01-08 | #### 11.1.8.操作日志logs | 11.1.8 Swingbench操作日志 |
| LOG-14-01 | ### 14.1.CTSS/chrony历史错误处理记录(禁止照做) | 14.1 CTSS/chrony历史错误处理记录 |
| LOG-14-02 | ### 14.2.iSCSI参数调优历史对比记录(含错误配置,禁止照抄) | 14.2 iSCSI参数调优历史对比记录 |


---

## LOG-03-06 3.6 root脚本执行日志

来源章节: `### 3.6. root脚本执行日志`

### 3.6. root脚本执行日志

#k8s-19rac01

```bash
[root@k8s-19rac01 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.

[root@k8s-19rac01 ~]# /u01/app/19.0.0/grid/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/app/19.0.0/grid

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac01/crsconfig/rootcrs_k8s-19rac01_2025-04-01_04-36-12PM.log
2025/04/01 16:36:20 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2025/04/01 16:36:20 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2025/04/01 16:36:20 CLSRSC-363: User ignored prerequisites during installation
2025/04/01 16:36:20 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2025/04/01 16:36:22 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2025/04/01 16:36:22 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2025/04/01 16:36:23 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2025/04/01 16:36:23 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2025/04/01 16:36:35 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2025/04/01 16:36:38 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2025/04/01 16:36:43 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2025/04/01 16:36:50 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2025/04/01 16:36:51 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2025/04/01 16:36:55 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2025/04/01 16:36:55 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2025/04/01 16:37:16 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2025/04/01 16:37:20 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2025/04/01 16:37:25 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2025/04/01 16:37:29 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.

ASM has been created and started successfully.

[DBT-30001] Disk groups created successfully. Check /u01/app/grid/cfgtoollogs/asmca/asmca-250401PM043758.log for details.

2025/04/01 16:38:55 CLSRSC-482: Running command: '/u01/app/19.0.0/grid/bin/ocrconfig -upgrade grid oinstall'
CRS-4256: Updating the profile
Successful addition of voting disk 5efd0c23970d4fe5bf96e0a2feaa0b31.
Successful addition of voting disk 8b999d4dd2934fffbf7957496e5138bd.
Successful addition of voting disk 425e1aae93974fcdbf5e2f5f3c4bc925.
Successfully replaced voting disk group with +OCR.
CRS-4256: Updating the profile
CRS-4266: Voting file(s) successfully replaced
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   5efd0c23970d4fe5bf96e0a2feaa0b31 (/dev/oracleasm/disks/OCR01) [OCR]
 2. ONLINE   8b999d4dd2934fffbf7957496e5138bd (/dev/oracleasm/disks/OCR02) [OCR]
 3. ONLINE   425e1aae93974fcdbf5e2f5f3c4bc925 (/dev/oracleasm/disks/OCR03) [OCR]
Located 3 voting disk(s).
2025/04/01 16:40:20 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2025/04/01 16:41:26 CLSRSC-343: Successfully started Oracle Clusterware stack
2025/04/01 16:41:26 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2025/04/01 16:42:33 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2025/04/01 16:42:55 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```



#k8s-19rac02

```bash
[root@k8s-19rac02 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/app/19.0.0/grid

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac02/crsconfig/rootcrs_k8s-19rac02_2025-04-01_04-44-44PM.log
2025/04/01 16:44:49 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2025/04/01 16:44:49 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2025/04/01 16:44:49 CLSRSC-363: User ignored prerequisites during installation
2025/04/01 16:44:49 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2025/04/01 16:44:51 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2025/04/01 16:44:51 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2025/04/01 16:44:51 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2025/04/01 16:44:51 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2025/04/01 16:44:53 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2025/04/01 16:44:53 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2025/04/01 16:45:01 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2025/04/01 16:45:01 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2025/04/01 16:45:03 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2025/04/01 16:45:03 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2025/04/01 16:45:14 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2025/04/01 16:45:23 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2025/04/01 16:45:25 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2025/04/01 16:45:26 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2025/04/01 16:45:28 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2025/04/01 16:45:38 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2025/04/01 16:46:09 CLSRSC-343: Successfully started Oracle Clusterware stack
2025/04/01 16:46:09 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2025/04/01 16:46:20 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2025/04/01 16:46:25 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```


---

## LOG-03-07 3.7 集群状态检查长回显

来源章节: `### 3.7. 集群状态检查`

### 3.7. 集群状态检查

```bash
[root@k8s-19rac01 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
--------------------------------------------------------------------------------
[root@k8s-19rac01 ~]# 


[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
--------------------------------------------------------------------------------
[root@k8s-19rac02 ~]# 

```


---

## LOG-05-02 5.2 DB root.sh脚本记录

来源章节: `### 5.2. 执行root.sh脚本记录`

### 5.2. 执行root.sh脚本记录
```bash
[root@k8s-19rac01 ~]#   /u01/app/oracle/product/19.0.0/db_1/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/19.0.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.


[root@k8s-19rac02 ~]# /u01/app/oracle/product/19.0.0/db_1/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/19.0.0/db_1

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.

```


---

## LOG-05-03 5.3 DB软件安装后集群状态长回显

来源章节: `### 5.3. 查看集群状态`

### 5.3. 查看集群状态

```bash
[root@k8s-19rac01 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
--------------------------------------------------------------------------------
[root@k8s-19rac01 ~]# 


[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
--------------------------------------------------------------------------------
[root@k8s-19rac02 ~]# 
```


---

## LOG-06-02 6.2 建库后集群状态长回显

来源章节: `### 6.2. 查看集群状态`

### 6.2. 查看集群状态
```
[root@k8s-19rac01 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t|wc -l
64
[root@k8s-19rac01 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
--------------------------------------------------------------------------------
[root@k8s-19rac01 ~]# 


[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t|wc -l
64
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
--------------------------------------------------------------------------------
[root@k8s-19rac02 ~]# 



[root@k8s-19rac01 ~]# su - grid
Last login: Tue Apr  1 18:28:15 CST 2025
[grid@k8s-19rac01 ~]$ srvctl config database -d xydb
Database unique name: xydb
Database name: xydb
Oracle home: /u01/app/oracle/product/19.0.0/db_1
Oracle user: oracle
Spfile: +DATA/XYDB/PARAMETERFILE/spfile.274.1197310365
Password file: +DATA/XYDB/PASSWORD/pwdxydb.256.1197309455
Domain: 
Start options: open
Stop options: immediate
Database role: PRIMARY
Management policy: AUTOMATIC
Server pools: 
Disk Groups: FRA,DATA
Mount point paths: 
Services: 
Type: RAC
Start concurrency: 
Stop concurrency: 
OSDBA group: dba
OSOPER group: oper
Database instances: xydb1,xydb2
Configured nodes: k8s-19rac01,k8s-19rac02
CSS critical: no
CPU count: 0
Memory target: 0
Maximum memory: 0
Default network number for database services: 
Database is administrator managed
[grid@k8s-19rac01 ~]$ 
```


---

## LOG-07-RU 7.1/7.2 19.20与19.21 RU历史执行记录

来源章节: `### 7.0.6.历史执行记录说明`

### 7.0.6.历史执行记录说明

#以下7.1/7.2为本环境当时从19.3升级到19.20/19.21的历史记录。
#后续打补丁只复用流程和检查点,不要照抄补丁号、版本号和输出日志。

### 7.1.首先打19.20RU

#补丁列表

|                             Name                             |  Download Link   |
| :----------------------------------------------------------: | :--------------: |
|           Database Release Update 19.20.0.0.230718           | <Patch 35320081> |
|     Grid Infrastructure Release Update 19.20.0.0.230718      | <Patch 35319490> |
|             OJVM Release Update 19.20.0.0.230718             | <Patch 35354406> |
|  (there were no OJVM Release Update Revisions for Jul 2023)  |                  |
| Microsoft Windows 32-Bit & x86-64 Bundle Patch 19.20.0.0.230718 | <Patch 35348034> |

#You must use the OPatch utility version 12.2.0.1.37 or later to apply this patch.



```
#补丁位置：---k8s-19rac01/k8s-19rac02都一样
[root@k8s-19rac02 ~]# cd /opt/19.20patch/
[root@k8s-19rac02 19.20patch]# ls -lrth
total 4.7G
-rw-r--r-- 1 root root 120M Oct 10 14:14 p6880880_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 2.8G Oct 10 14:14 p35319490_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 1.7G Oct 10 14:14 p35320081_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 122M Oct 10 14:14 p35354406_190000_Linux-x86-64.zip
```



#### 7.1.1.检查集群状态

```bash
# crsctl status resource -t
```

#集群正常

```bash
[grid@k8s-19rac02 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
--------------------------------------------------------------------------------

[grid@k8s-19rac01 ~]$ crsctl status res -t -init
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.asm
      1        ONLINE  ONLINE       k8s-19rac01                Started,STABLE
ora.cluster_interconnect.haip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.crf
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.crsd
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.cssd
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.cssdmonitor
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.ctssd
      1        ONLINE  ONLINE       k8s-19rac01                ACTIVE:0,STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.drivers.acfs
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.evmd
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.gipcd
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.gpnpd
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.mdnsd
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.storage
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
--------------------------------------------------------------------------------

```



#### 7.1.2.更新grid opatch 两个节点 root执行

```bash
#备份opatch
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch_bak    

#更新opatch
unzip -q /opt/19.20patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/  

chmod -R 755 /u01/app/19.0.0/grid/OPatch

chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

#更新后检查opatch的版本至少12.2.0.1.37
su - grid

[grid@k8s-19rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-19rac01 OPatch]$ ./opatch version   

OPatch Version: 12.2.0.1.39
OPatch succeeded.
```



#### 7.1.3.更新oracle opatch 两个节点 root执行

```bash
#备份opatch
mv /u01/app/oracle/product/19.0.0/db_1/OPatch /u01/app/oracle/product/19.0.0/db_1/OPatch.bak     

unzip -q /opt/19.20patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/db_1/ 

chmod -R 755 /u01/app/oracle/product/19.0.0/db_1/OPatch

chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/db_1/OPatch
```

 

#### 7.1.4.解压patch包 两个节点 root执行

```bash
#这一个包 包含了全部的patch
unzip /opt/19.20patch/p35319490_190000_Linux-x86-64.zip -d /opt/19.20patch/

chown -R grid:oinstall /opt/19.20patch/35319490

chmod -R 755 /opt/19.20patch/35319490

#此时可以查看35319490文件夹下的 README.html，里面有详细的RU步骤
```



#### 7.1.5.兼容性检查 两个节点 grid/oracle用户

```bash
#OPatch兼容性检查 两个节点 grid用户

 su - grid

/u01/app/19.0.0/grid/OPatch/opatch lsinventory -detail -oh /u01/app/19.0.0/grid/

#OPatch兼容性检查 两个节点 oracle用户

 su - oracle

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatch lsinventory -detail -oh /u01/app/oracle/product/19.0.0/db_1/
```



#### 7.1.6.补丁冲突检查 k8s-19rac01/k8s-19rac02两个节点都执行

```bash
#子目录的五个patch在grid用户下分别执行检查

su - grid

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320081

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320149

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35332537

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35553096

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/33575402


#子目录的一个patch在oracle用户下执行检查

su - oracle


$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320081

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.20patch/35319490/35320149
```



#### 7.1.7.空间检查 k8s-19rac01/k8s-19rac02两个节点都执行

```bash
#grid用户执行

su - grid

touch /tmp/patch_list_gihome.txt

cat >>  /tmp/patch_list_gihome.txt <<EOF
/opt/19.20patch/35319490/35320081
/opt/19.20patch/35319490/35320149
/opt/19.20patch/35319490/35332537
/opt/19.20patch/35319490/35553096
/opt/19.20patch/35319490/33575402
EOF


$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_list_gihome.txt


#oracle用户执行

su - oracle

touch /tmp/patch_list_dbhome.txt

cat > /tmp/patch_list_dbhome.txt <<EOF
/opt/19.20patch/35319490/35320081
/opt/19.20patch/35319490/35320149
EOF

$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_list_dbhome.txt
```



#### 7.1.8.补丁分析检查  root用户两个节点都要分别执行 

```bash
su - root

#k8s-19rac01:
#k8s-19rac01大约2分钟40秒，全部成功(最长有过4分17秒)

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -analyze

#k8s-19rac02:
#k8s-19rac02大约2分钟40秒，全部成功(最长有过3分48秒)
#可能会有部分失败

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -analyze

-----------------------------
Reason: Failed during Analysis: CheckSystemCommandsAvailable Failed, [ Prerequisite Status: FAILED, Prerequisite output:
The details are:

Missing command :fuser]
---------------------------


#解决办法：
yum install -y psmisc

#k8s-19rac02再次检查：
#k8s-19rac02大约2分钟40秒，全部成功
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -analyze       
```



#### 7.1.9.grid 升级 root两个节点都要分别执行 --grid upgrade

```bash
su - root

#k8s-19rac01约15分钟(最长有过80分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   

#k8s-19rac02约20分钟(最长有过60分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   
#报错后可以再次执行


#升级后的状态
su - grid
cd $ORACLE_HOME/OPatch

[grid@k8s-19rac01 OPatch]$./opatch lspatches   
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
35332537;ACFS RELEASE UPDATE 19.20.0.0.0 (35332537)
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.

[grid@k8s-19rac02 OPatch]$ ./opatch lspatches   
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
35332537;ACFS RELEASE UPDATE 19.20.0.0.0 (35332537)
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.
```

#错误处理

```bash
#(0)
#不能在/root或/目录下执行，否则报错：
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   

Invalid current directory.  Please run opatchauto from other than '/root' or '/' directory.
And check if the home owner user has write permission set for the current directory.
opatchauto returns with error code = 2
------------------------------------------------------------------------
#(1)
#GI因为共享磁盘的UUID变化，没起来

CRS-2676: Start of 'ora.crf' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-19rac02'
CRS-1705: Found 1 configured voting files but 2 voting files are required, terminating to ensure data integrity; details at (:CSSNM00021:) in /u01/app/grid/diag/crs/k8s-19rac02/crs/trace/ocssd.trc
CRS-2883: Resource 'ora.cssd' failed during Clusterware stack start.
CRS-4406: Oracle High Availability Services synchronous start failed.
CRS-41053: checking Oracle Grid Infrastructure for file permission issues
PRVH-0116 : Path "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" with permissions "rw-r--r--" does not have execute permissions for the owner, file's group, and others on node "k8s-19rac02".
PRVG-2031 : Owner of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-19rac02". [Expected = "grid(11012)" ; Found = "root(0)"]
PRVG-2032 : Group of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-19rac02". [Expected = "oinstall(11001)" ; Found = "root(0)"]
CRS-4000: Command Start failed, or completed with errors.
2023/11/19 07:42:47 CLSRSC-117: Failed to start Oracle Clusterware stack 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 07:42:50 2023
Time taken to complete the session 2 minutes, 35 seconds

 opatchauto failed with error code 42
------------------------------------------------------------------------

#(2)
#共享磁盘重新扫描、挂载修复后，发现因为olr无法手动备份，导致报错；

Performing postpatch operations on CRS - starting CRS service on home /u01/app/19.0.0/grid
Postpatch operation log file location: /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crs_postpatch_apply_inplace_k8s-19rac02_2023-11-19_09-07-00AM.log
Failed to start CRS service on home /u01/app/19.0.0/grid

Execution of [GIStartupAction] patch action failed, check log for more details. Failures:
Patch Target : k8s-19rac02->/u01/app/19.0.0/grid Type[crs]
Details: [
---------------------------Patching Failed---------------------------------
Command execution failed during patching in home: /u01/app/19.0.0/grid, host: k8s-19rac02.
Command failed:  /u01/app/19.0.0/grid/perl/bin/perl -I/u01/app/19.0.0/grid/perl/lib -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/crs/install -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/xag /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/crs/install/rootcrs.pl -postpatch
Command failure output: 
Using configuration parameter file: /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crs_postpatch_apply_inplace_k8s-19rac02_2023-11-19_09-07-00AM.log
2023/11/19 09:07:16 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
Oracle Clusterware active version on the cluster is [19.0.0.0.0]. The cluster upgrade state is [NORMAL]. The cluster active patch level is [3976270074].
CRS-2672: Attempting to start 'ora.drivers.acfs' on 'k8s-19rac02'
CRS-2676: Start of 'ora.drivers.acfs' on 'k8s-19rac02' succeeded
2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 09:10:12 2023
Time taken to complete the session 25 minutes, 5 seconds

 opatchauto failed with error code 42
[root@k8s-19rac02 35319490]# 

#发现错误是2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 
#手动执行，发现确实报错
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup manual

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-19rac02 ~]# ll /u01/app/grid/crsdata/k8s-19rac02/olr
total 495048
-rw-r--r-- 1 root root       1101824 Nov 18 18:49 autobackup_20231118_184948.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:35 backup_20231118_183548.olr
-rw------- 1 root oinstall 503484416 Nov 19 11:54 k8s-19rac02_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 08:46 k8s-19rac02_19.olr.bkp.patch
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup
PROTL-23: failed to back up Oracle Local Registry
PROCL-60: The Oracle Local Registry backup file '/u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231119_121545.olr' is corrupt.

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83168
	 Available space (kbytes) :     408516
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed


#但在k8s-19rac01上手动备份没问题
[root@k8s-19rac01 ContentsXML]# ocrconfig -local -manualbackup

k8s-19rac01     2023/11/19 12:12:49     /u01/app/grid/crsdata/k8s-19rac01/olr/backup_20231119_121249.olr     3976270074     

k8s-19rac01     2023/11/19 01:25:37     /u01/app/grid/crsdata/k8s-19rac01/olr/backup_20231119_012537.olr     3976270074     

k8s-19rac01     2023/11/18 18:27:53     /u01/app/grid/crsdata/k8s-19rac01/olr/backup_20231118_182753.olr     724960844     
[root@k8s-19rac01 ContentsXML]# ll /u01/app/grid/crsdata/k8s-19rac01/olr/
total 498160
-rw-r--r-- 1 root root       1114112 Nov 18 18:39 autobackup_20231118_183942.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:27 backup_20231118_182753.olr
-rw------- 1 root root       1150976 Nov 19 01:25 backup_20231119_012537.olr
-rw------- 1 root root       1593344 Nov 19 12:12 backup_20231119_121249.olr
-rw------- 1 root oinstall 503484416 Nov 19 12:12 k8s-19rac01_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 00:11 k8s-19rac01_19.olr.bkp.patch
[root@k8s-19rac01 ~]#  /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83444
	 Available space (kbytes) :     408240
	 ID                       : 1567972045
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac01/olr/k8s-19rac01_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#k8s-19rac02，如果此时关闭cluster，将无法启动，特别是ora.asm/ora.OCR.dg(ora.asmgroup)/ora.DATA.dg(ora.asmgroup)/ora.FRA.dg(ora.asmgroup)等无法启动，但是vip/LISTENER等其他组件正常

[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-19rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-19rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-19rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-19rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-19rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-19rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-19rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-19rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-19rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-19rac02' failed
===== Summary of resource auto-start failures follows =====
CRS-2807: Resource 'ora.asmgroup' failed to start automatically.
CRS-2807: Resource 'ora.xydb.db' failed to start automatically.
CRS-2807: Resource 'ora.xydb.s_stuwork.svc' failed to start automatically.
CRS-6016: Resource auto-start has completed for server k8s-19rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                Started,STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  OFFLINE                               STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
--------------------------------------------------------------------------------

[root@k8s-19rac02 trace]# tail -f /u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsctl_8402.trc

2023-11-20 03:21:08.163 :  OCROSD:2832813824: utopen: Failed to open OCR disk/file [/u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr], errno:[13], OS error string:[Permission denied]
2023-11-20 03:21:08.163 :  OCROSD:2832813824: utopen:7: failed to open any OCR file/disk, errno=13, os err string=Permission denied
 default:2832813824: u_set_gbl_comp_error: comptype '101' : error '13'
2023-11-20 03:21:08.163 :  OCRRAW:2832813824: proprinit: Could not open raw device
2023-11-20 03:21:08.163 : default:2832813824: a_init:7!: Backend init unsuccessful : [26]
2023-11-20 03:21:08.163 :  OCRAPI:2832813824: clsugcnr:5.1: procr_init_ext failed [26] with bootlevel [131072]. Error data [PROCL-26: Error while accessing the physical storage Operating System error [Permission denied] [13]]. Return [5]


#此时对olr进行restore处理
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-19rac02     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-19rac02/olr/autobackup_20231118_184948.olr     724960844

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-19rac02/olr/autobackup_20231118_184948.olr
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     

#再次检查ocrcheck -local，发现为succeeded
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck 
PROT-602: Failed to retrieve data from the cluster registry
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 trace]# 

------------------------------------------------------------------------
#(3)
#但是此时再次启动cluster报错，因为还原了Olr后与已经打的补丁不一致
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start cluster
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl check crs
CRS-4639: Could not contact Oracle High Availability Services

[root@k8s-19rac02 dispatcher.d]# ps -ef|grep grid|grep app|awk '{print $2}'|xargs kill -9

[root@k8s-19rac02 dispatcher.d]# ps -ef|grep grid
root     14717 11600  0 11:51 pts/4    00:00:00 grep --color=auto grid
root     26985 11598  0 Nov21 pts/2    00:00:00 su - grid
grid     26987 26985  0 Nov21 pts/2    00:00:00 -bash
grid     29819 26987  0 Nov21 pts/2    00:00:00 tail -100f alert_+ASM2.log


[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.

#解决办法：

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -unlock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crsunlock_k8s-19rac02_2023-11-22_11-54-32AM.log
2023/11/22 11:54:33 CLSRSC-4012: Shutting down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:56 CLSRSC-4013: Successfully shut down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:58 CLSRSC-347: Successfully unlock /u01/app/19.0.0/grid

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/clscfg -localpatch
clscfg: EXISTING configuration version 0 detected.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -lock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crslock_k8s-19rac02_2023-11-22_11-58-45AM.log
2023/11/22 11:58:52 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-19rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-19rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-19rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-19rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-19rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-19rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-19rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-33676: Start of resource group 'ora.asmgroup' on server 'k8s-19rac02' succeeded.
CRS-2672: Attempting to start 'ora.FRA.dg' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.DATA.dg' on 'k8s-19rac02'
CRS-2676: Start of 'ora.FRA.dg' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.DATA.dg' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-2676: Start of 'ora.xydb.db' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.s_stuwork.svc' on 'k8s-19rac02'
CRS-2676: Start of 'ora.xydb.s_stuwork.svc' on 'k8s-19rac02' succeeded
CRS-6016: Resource auto-start has completed for server k8s-19rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-19rac02 ~]# 

[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
Status of Oracle Cluster Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      84460
	 Available space (kbytes) :     407224
	 ID                       : 1399819439
	 Device/File Name         :       +OCR
                                    Device/File integrity check succeeded

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

	 Cluster registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83152
	 Available space (kbytes) :     408532
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#再次手动备份也正常了
[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup

k8s-19rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-19rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844    

#再次打补丁

```



#### 7.1.10.oracle 升级 root两个节点都要分别执行 --oracle upgrade

```bash
su - root

#k8s-19rac01
#在非/和/root目录下执行

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/oracle/product/19.0.0/db_1

#k8s-19rac01约25分钟 
-------------------------------------------------------

#第一次执行报错：

Patch: /opt/opa/35319490/35320081
Log: /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatchauto/core/opatch/opatch2023-10-10_17-11-02PM_1.log
Reason: Failed during Patching: oracle.opatch.opatchsdk.OPatchException: Prerequisite check "CheckActiveFilesAndExecutables" failed.
After fixing the cause of failure Run opatchauto resume
#查看日志：

Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1 PID( 110745 )
Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so PID( 110745 )
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so
[Oct 10, 2023 5:11:47 PM] [SEVERE]  OUI-67073:UtilSession failed: Prerequisite check "CheckActiveFilesAndExecutables" failed.

#手动检查进程110745
ps -ef|grep 110745

fuser /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
fuser /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so

#都没有发现

#此时在第一个报错的窗口执行opatchauto resume恢复正常执行完毕
cd /u01/app/oracle/product/19.0.0/db_1/OPatch/

./opatchauto resume

--------------------------------------------------------

#k8s-19rac02

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/oracle/product/19.0.0/db_1 

#k8s-19rac02约33分钟(最长85 minutes, 13 seconds)

 
#检查补丁情况
su - oracle
cd $ORACLE_HOME/OPatch
./opatch lspatches  


[oracle@k8s-19rac01 OPatch]$ ./opatch lspatches
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)

OPatch succeeded.


[oracle@k8s-19rac02 OPatch]$ ./opatch lspatches
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)

OPatch succeeded.
```





#### 7.1.11.升级后动作 after patch

```bash
#(1)
#仅节点1---直接启动全部pdb后，用oracle用户执行datapatch -verbose

su - oracle
sqlplus / as sysdba
show pdbs;
exit

#确认全部pdb已经启动后
cd $ORACLE_HOME/OPatch
./datapatch -verbose


[oracle@k8s-19rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-19rac01 OPatch]$ ./datapatch -verbose 

#执行前确认两个节点pdb都打开，如果pdb没有打开 可能会出现cdb和pdb RU不一致，
#导致pdb受限。如果pdb没有更新 可以使用这个命令强制更新ru

 datapatch -verbose -apply  ru_id -force -pdbs PDB1

#(2)
#编译无效对象---cdb/pdb全部执行

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73500
INVALID        286


SQL> @$ORACLE_HOME/rdbms/admin/utlrp.sql

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73786



 

#完成后检查patch情况

set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

 
SQL> select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION	      STATUS	      TARGET_VERSION
---------- ---------- --------------- --------------- ---------------
  29517242 RU	      APPLY	      SUCCESS	      19.3.0.0.0
  35320081 RU	      APPLY	      SUCCESS	      19.20.0.0.0


SQL>  select  PATCH_UID,PATCH_ID,ACTION,STATUS,ACTION_TIME ,DESCRIPTION,TARGET_VERSION from dba_registry_sqlpatch;

PATCH_UID   PATCH_ID ACTION          STATUS                    ACTION_TIME                    DESCRIPTION                                             TARGET_VERSION

---------- ---------- --------------- ------------------------- ------------------------------ ------------------------------------------------------- ---------------

  22862832   29517242 APPLY           SUCCESS                   28-SEP-23 01.07.44.077637 PM   Database Release Update : 19.3.0.0.190416 (29517242)    19.3.0.0.0
  25314491   35320081 APPLY           SUCCESS                   10-OCT-23 06.30.55.798713 PM   Database Release Update : 19.20.0.0.230718 (35320081)   19.20.0.0.0
  
  
--------------------------------------------------
#根据升级文档，datapatch操作可以在全部pdb开启后执行，不再按以下步骤执行
#升级后操作 (only node1)
sqlplus / as sysdba
STARTUP
alter system set cluster_database=false scope=spfile;
srvctl stop db -d <dbname>
STARTUP UPGRADE;
SHUTDOWN;
STARTUP;
alter system set cluster_database=true scope=spfile sid='*';
SHUTDOWN;
srvctl start database -d <dbname>
alter pluggable database all open;

-- 确认 PDB 全部打开
-- 执行 datapatch
$ORACLE_HOME/OPatch/datapatch -verbose  # 约35min

-----------------------------------------------

opatch lspatches

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP

SQL> alter system set cluster_database=false scope=spfile;  --设置接非集群

 

srvctl stop db -d dbname  

 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP UPGRADE

如果使用了pdb  请确认pdb 全部open

alter pluggable database  all open;


[oracle@k8s-19rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-19rac01 OPatch]$ ./datapatch -verbose 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> alter system set cluster_database=true scope=spfile sid='*';

SQL> SHUTDOWN

srvctl start database -d dbname

--------------------------------------------------
```

### 7.2.接着打19.21RU---执行过程同7.1

#补丁列表

|                             Name                             |  Download Link   |
| :----------------------------------------------------------: | :--------------: |
|           Database Release Update 19.21.0.0.231017           | <Patch 35643107> |
|     Grid Infrastructure Release Update 19.21.0.0.231017      | <Patch 35642822> |
|             OJVM Release Update 19.21.0.0.231017             | <Patch 35648110> |
|  (there were no OJVM Release Update Revisions for Oct 2023)  |                  |
| Microsoft Windows 32-Bit & x86-64 Bundle Patch 19.21.0.0.231017 | <Patch 35681552> |

#You must use the OPatch utility version 12.2.0.1.37 or later to apply this patch.



```
#补丁位置：---k8s-19rac01/k8s-19rac02都一样
[oracle@k8s-19rac01 opt]$ ls
19.20patch  19.21patch  opa  oracle  oracle.ahf  ORCLfmap
[oracle@k8s-19rac01 opt]$ cd 19.21patch/
[oracle@k8s-19rac01 19.21patch]$ ll
total 5031608
-rw-r--r-- 1 root root 3084439097 Nov 18 23:00 p35642822_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root 1815725977 Nov 18 23:00 p35643107_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root  127350205 Nov 18 23:00 p35648110_190000_Linux-x86-64.zip
-rw-r--r-- 1 root root  124843817 Nov 18 23:00 p6880880_190000_Linux-x86-64.zip

```



#### 7.2.1.检查集群状态

```bash
crsctl status resource -t
```

#集群正常

```bash
[grid@k8s-19rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-19rac01 OPatch]$ ./opatch lspatches   
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
35332537;ACFS RELEASE UPDATE 19.20.0.0.0 (35332537)
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.

[grid@k8s-19rac01 OPatch]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
--------------------------------------------------------------------------------

```



#### 7.2.2.更新grid opatch 两个节点 root执行

```bash
#备份opatch
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch_20bak    

#更新opatch
unzip -q /opt/19.21patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/  

chmod -R 755 /u01/app/19.0.0/grid/OPatch

chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

#更新后检查opatch的版本至少12.2.0.1.37
su - grid

[grid@k8s-19rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-19rac01 OPatch]$ ./opatch version   

OPatch Version: 12.2.0.1.37
OPatch succeeded.
```



#### 7.2.3.更新oracle opatch 两个节点 root执行

```bash
#备份opatch
mv /u01/app/oracle/product/19.0.0/db_1/OPatch /u01/app/oracle/product/19.0.0/db_1/OPatch.20bak     

unzip -q /opt/19.21patch/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/db_1/ 

chmod -R 755 /u01/app/oracle/product/19.0.0/db_1/OPatch

chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/db_1/OPatch
```

 

#### 7.2.4.解压patch包 两个节点 root执行

```bash
#这一个包 包含了全部的patch
unzip /opt/19.21patch/p35642822_190000_Linux-x86-64.zip -d /opt/19.21patch/

chown -R grid:oinstall /opt/19.21patch/35642822

chmod -R 755 /opt/19.21patch/35642822

#此时可以查看35642822文件夹下的 README.html，里面有详细的RU步骤
```



#### 7.2.5.兼容性检查

```bash
#OPatch兼容性检查 两个节点 grid用户

 su - grid

/u01/app/19.0.0/grid/OPatch/opatch lsinventory -detail -oh /u01/app/19.0.0/grid/

#OPatch兼容性检查 两个节点 oracle用户

 su - oracle

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatch lsinventory -detail -oh /u01/app/oracle/product/19.0.0/db_1/
```



#### 7.2.6.补丁冲突检查 k8s-19rac01/k8s-19rac02两个节点都执行

```bash
#子目录的五个patch在grid用户下分别执行检查

su - grid

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35643107

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35655527

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35652062

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35553096

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/33575402


#子目录的一个patch在oracle用户下执行检查

su - oracle


$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35643107

$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /opt/19.21patch/35642822/35655527
```



#### 7.2.7.空间检查 k8s-19rac01/k8s-19rac02两个节点都执行

```bash
#grid用户执行

su - grid

touch /tmp/1921patch_list_gihome.txt

cat >>  /tmp/1921patch_list_gihome.txt <<EOF
/opt/19.21patch/35642822/35643107
/opt/19.21patch/35642822/35655527
/opt/19.21patch/35642822/35652062
/opt/19.21patch/35642822/35553096
/opt/19.21patch/35642822/33575402
EOF


$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/1921patch_list_gihome.txt


#oracle用户执行

su - oracle

touch /tmp/1921patch_list_dbhome.txt

cat > /tmp/1921patch_list_dbhome.txt <<EOF
/opt/19.21patch/35642822/35643107
/opt/19.21patch/35642822/35655527
EOF

$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/1921patch_list_dbhome.txt
```



#### 7.2.8.补丁分析检查  root用户两个节点都要分别执行 

```bash
su - root

#k8s-19rac01:
#k8s-19rac01大约2分钟40秒，全部成功(最长有过4分17秒)

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze

#k8s-19rac02:
#k8s-19rac02大约2分钟40秒，全部成功(最长有过3分48秒)
#可能会有部分失败

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze

-----------------------------
Reason: Failed during Analysis: CheckSystemCommandsAvailable Failed, [ Prerequisite Status: FAILED, Prerequisite output:
The details are:

Missing command :fuser]
---------------------------


#解决办法：
yum install -y psmisc

#k8s-19rac02再次检查：
#k8s-19rac02大约2分钟40秒，全部成功
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze       
```

#报错分析解决

```bash
[root@k8s-19rac01 OPatch]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze 
OPatchauto session is initiated at Wed Nov 22 18:02:38 2023

System initialization log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchautodb/systemconfig2023-11-22_06-02-46PM.log.

Session log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-20PM.log
The id for this session is BY6I

Wrong OPatch software installed in following homes:
Host:k8s-19rac01, Home:/u01/app/oracle/product/19.0.0/db_1

Host:k8s-19rac02, Home:/u01/app/oracle/product/19.0.0/db_1

OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
OPatchAuto failed.

OPatchauto session completed at Wed Nov 22 18:03:51 2023
Time taken to complete the session 1 minute, 6 seconds

 opatchauto failed with error code 42

[root@k8s-19rac02 OPatch]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze 
OPatchauto session is initiated at Wed Nov 22 18:02:38 2023

System initialization log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchautodb/systemconfig2023-11-22_06-02-44PM.log.

Session log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-14PM.log
The id for this session is YA4Q

Wrong OPatch software installed in following homes:
Host:k8s-19rac01, Home:/u01/app/oracle/product/19.0.0/db_1

Host:k8s-19rac02, Home:/u01/app/oracle/product/19.0.0/db_1

OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
OPatchAuto failed.

OPatchauto session completed at Wed Nov 22 18:03:38 2023
Time taken to complete the session 0 minute, 54 seconds

 opatchauto failed with error code 42


[root@k8s-19rac01 OPatch]# tail -100f /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-20PM.log
2023-11-22 18:03:50,374 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator -  OH  hostname  OH.getPath() /u01/app/oracle/product/19.0.0/db_1
2023-11-22 18:03:51,025 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-19rac01
2023-11-22 18:03:51,025 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-19rac02
2023-11-22 18:03:51,025 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='
Wrong OPatch software installed in following homes:'}
2023-11-22 18:03:51,025 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-19rac01, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:51,026 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-19rac02, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:51,027 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.DBValidationController - Validation failed due to :OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
2023-11-22 18:03:51,028 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OOPPatchTargetValidator - OOP patch target validation skipped
2023-11-22 18:03:51,190 INFO  [1] com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport - Space available after session: 236574 MB
2023-11-22 18:03:51,267 INFO  [1] com.oracle.glcm.patch.auto.db.framework.core.oplan.IOUtils - Change the permission of the file /u01/app/19.0.0/grid/opatchautocfg/db/sessioninfo/patchingsummary.xmlto 775
2023-11-22 18:03:51,343 SEVERE [1] com.oracle.glcm.patch.auto.OPatchAuto - OPatchAuto failed.
com.oracle.glcm.patch.auto.OPatchAutoException: OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport.loadTopology(DBBaseProductSupport.java:236)
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBProductSupport.loadTopology(DBProductSupport.java:69)
        at com.oracle.glcm.patch.auto.OPatchAuto.loadTopology(OPatchAuto.java:1732)
        at com.oracle.glcm.patch.auto.OPatchAuto.prepareOrchestration(OPatchAuto.java:730)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:397)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:344)
        at com.oracle.glcm.patch.auto.OPatchAuto.main(OPatchAuto.java:212)
2023-11-22 18:03:51,344 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.'}
2023-11-22 18:03:51,344 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPatchAuto failed.'}

[root@k8s-19rac02 OPatch]# tail -100f /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-14PM.log
2023-11-22 18:03:38,228 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator -  OH  hostname  OH.getPath() /u01/app/oracle/product/19.0.0/db_1
2023-11-22 18:03:38,731 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-19rac01
2023-11-22 18:03:38,732 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-19rac02
2023-11-22 18:03:38,732 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='
Wrong OPatch software installed in following homes:'}
2023-11-22 18:03:38,732 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-19rac01, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:38,733 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-19rac02, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:38,735 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.DBValidationController - Validation failed due to :OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
2023-11-22 18:03:38,735 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OOPPatchTargetValidator - OOP patch target validation skipped
2023-11-22 18:03:38,777 INFO  [1] com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport - Space available after session: 242439 MB
2023-11-22 18:03:38,793 INFO  [1] com.oracle.glcm.patch.auto.db.framework.core.oplan.IOUtils - Change the permission of the file /u01/app/19.0.0/grid/opatchautocfg/db/sessioninfo/patchingsummary.xmlto 775
2023-11-22 18:03:38,810 SEVERE [1] com.oracle.glcm.patch.auto.OPatchAuto - OPatchAuto failed.
com.oracle.glcm.patch.auto.OPatchAutoException: OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBBaseProductSupport.loadTopology(DBBaseProductSupport.java:236)
        at com.oracle.glcm.patch.auto.db.integration.model.productsupport.DBProductSupport.loadTopology(DBProductSupport.java:69)
        at com.oracle.glcm.patch.auto.OPatchAuto.loadTopology(OPatchAuto.java:1732)
        at com.oracle.glcm.patch.auto.OPatchAuto.prepareOrchestration(OPatchAuto.java:730)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:397)
        at com.oracle.glcm.patch.auto.OPatchAuto.orchestrate(OPatchAuto.java:344)
        at com.oracle.glcm.patch.auto.OPatchAuto.main(OPatchAuto.java:212)
2023-11-22 18:03:38,811 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.'}
2023-11-22 18:03:38,811 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='OPatchAuto failed.'}


#调查分析：grid用户和oracle用户用的opatch不是一个版本
#原来grid用户用的是19.20的opatch，版本是；12.2.0.1.39；而oracle用户用的是19.20的opatch，版本是；12.2.0.1.37
#全部改为19.21的opatch后，通过！
```



#### 7.2.9.grid 升级 root两个节点都要分别执行 --grid upgrade

```bash
su - root

#k8s-19rac01约15分钟(最长有过80分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/19.0.0/grid   

#k8s-19rac02约20分钟(最长有过60分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/19.0.0/grid   
#报错后可以再次执行


#升级后的状态
su - grid
cd $ORACLE_HOME/OPatch

[grid@k8s-19rac01 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35652062;ACFS RELEASE UPDATE 19.21.0.0.0 (35652062)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.


[grid@k8s-19rac02 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35652062;ACFS RELEASE UPDATE 19.21.0.0.0 (35652062)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.

```

#错误处理

```bash
#(0)
#不能在/root或/目录下执行，否则报错：
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   

Invalid current directory.  Please run opatchauto from other than '/root' or '/' directory.
And check if the home owner user has write permission set for the current directory.
opatchauto returns with error code = 2
------------------------------------------------------------------------
#(1)
#GI因为共享磁盘的UUID变化，没起来

CRS-2676: Start of 'ora.crf' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-19rac02'
CRS-1705: Found 1 configured voting files but 2 voting files are required, terminating to ensure data integrity; details at (:CSSNM00021:) in /u01/app/grid/diag/crs/k8s-19rac02/crs/trace/ocssd.trc
CRS-2883: Resource 'ora.cssd' failed during Clusterware stack start.
CRS-4406: Oracle High Availability Services synchronous start failed.
CRS-41053: checking Oracle Grid Infrastructure for file permission issues
PRVH-0116 : Path "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" with permissions "rw-r--r--" does not have execute permissions for the owner, file's group, and others on node "k8s-19rac02".
PRVG-2031 : Owner of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-19rac02". [Expected = "grid(11012)" ; Found = "root(0)"]
PRVG-2032 : Group of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-19rac02". [Expected = "oinstall(11001)" ; Found = "root(0)"]
CRS-4000: Command Start failed, or completed with errors.
2023/11/19 07:42:47 CLSRSC-117: Failed to start Oracle Clusterware stack 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 07:42:50 2023
Time taken to complete the session 2 minutes, 35 seconds

 opatchauto failed with error code 42
------------------------------------------------------------------------

#(2)
#修复后，发现因为olr无法手动备份，导致报错；估计还是上面共享磁盘的问题

Performing postpatch operations on CRS - starting CRS service on home /u01/app/19.0.0/grid
Postpatch operation log file location: /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crs_postpatch_apply_inplace_k8s-19rac02_2023-11-19_09-07-00AM.log
Failed to start CRS service on home /u01/app/19.0.0/grid

Execution of [GIStartupAction] patch action failed, check log for more details. Failures:
Patch Target : k8s-19rac02->/u01/app/19.0.0/grid Type[crs]
Details: [
---------------------------Patching Failed---------------------------------
Command execution failed during patching in home: /u01/app/19.0.0/grid, host: k8s-19rac02.
Command failed:  /u01/app/19.0.0/grid/perl/bin/perl -I/u01/app/19.0.0/grid/perl/lib -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/crs/install -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/xag /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/crs/install/rootcrs.pl -postpatch
Command failure output: 
Using configuration parameter file: /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-19rac02/patchwork/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crs_postpatch_apply_inplace_k8s-19rac02_2023-11-19_09-07-00AM.log
2023/11/19 09:07:16 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
Oracle Clusterware active version on the cluster is [19.0.0.0.0]. The cluster upgrade state is [NORMAL]. The cluster active patch level is [3976270074].
CRS-2672: Attempting to start 'ora.drivers.acfs' on 'k8s-19rac02'
CRS-2676: Start of 'ora.drivers.acfs' on 'k8s-19rac02' succeeded
2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 

After fixing the cause of failure Run opatchauto resume

]
OPATCHAUTO-68061: The orchestration engine failed.
OPATCHAUTO-68061: The orchestration engine failed with return code 1
OPATCHAUTO-68061: Check the log for more details.
OPatchAuto failed.

OPatchauto session completed at Sun Nov 19 09:10:12 2023
Time taken to complete the session 25 minutes, 5 seconds

 opatchauto failed with error code 42
[root@k8s-19rac02 35319490]# 

#发现错误是2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 
#手动执行，发现确实报错
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup manual

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-19rac02 ~]# ll /u01/app/grid/crsdata/k8s-19rac02/olr
total 495048
-rw-r--r-- 1 root root       1101824 Nov 18 18:49 autobackup_20231118_184948.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:35 backup_20231118_183548.olr
-rw------- 1 root oinstall 503484416 Nov 19 11:54 k8s-19rac02_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 08:46 k8s-19rac02_19.olr.bkp.patch
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup
PROTL-23: failed to back up Oracle Local Registry
PROCL-60: The Oracle Local Registry backup file '/u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231119_121545.olr' is corrupt.

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83168
	 Available space (kbytes) :     408516
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed


#但在k8s-19rac01上手动备份没问题
[root@k8s-19rac01 ContentsXML]# ocrconfig -local -manualbackup

k8s-19rac01     2023/11/19 12:12:49     /u01/app/grid/crsdata/k8s-19rac01/olr/backup_20231119_121249.olr     3976270074     

k8s-19rac01     2023/11/19 01:25:37     /u01/app/grid/crsdata/k8s-19rac01/olr/backup_20231119_012537.olr     3976270074     

k8s-19rac01     2023/11/18 18:27:53     /u01/app/grid/crsdata/k8s-19rac01/olr/backup_20231118_182753.olr     724960844     
[root@k8s-19rac01 ContentsXML]# ll /u01/app/grid/crsdata/k8s-19rac01/olr/
total 498160
-rw-r--r-- 1 root root       1114112 Nov 18 18:39 autobackup_20231118_183942.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:27 backup_20231118_182753.olr
-rw------- 1 root root       1150976 Nov 19 01:25 backup_20231119_012537.olr
-rw------- 1 root root       1593344 Nov 19 12:12 backup_20231119_121249.olr
-rw------- 1 root oinstall 503484416 Nov 19 12:12 k8s-19rac01_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 00:11 k8s-19rac01_19.olr.bkp.patch
[root@k8s-19rac01 ~]#  /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83444
	 Available space (kbytes) :     408240
	 ID                       : 1567972045
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac01/olr/k8s-19rac01_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#k8s-19rac02，如果此时关闭cluster，将无法启动，特别是ora.asm/ora.OCR.dg(ora.asmgroup)/ora.DATA.dg(ora.asmgroup)/ora.FRA.dg(ora.asmgroup)等无法启动，但是vip/LISTENER等其他组件正常

[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-19rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-19rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-19rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-19rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-19rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-19rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-19rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-19rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-19rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-19rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-19rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-19rac02' failed
===== Summary of resource auto-start failures follows =====
CRS-2807: Resource 'ora.asmgroup' failed to start automatically.
CRS-2807: Resource 'ora.xydb.db' failed to start automatically.
CRS-2807: Resource 'ora.xydb.s_stuwork.svc' failed to start automatically.
CRS-6016: Resource auto-start has completed for server k8s-19rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01                STABLE
               ONLINE  ONLINE       k8s-19rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                Started,STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  ONLINE       k8s-19rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  OFFLINE                               STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-19rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
--------------------------------------------------------------------------------


#此时对olr进行restore处理
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-19rac02     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-19rac02/olr/autobackup_20231118_184948.olr     724960844

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-19rac02/olr/autobackup_20231118_184948.olr
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     

#再次检查ocrcheck -local，发现为succeeded
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck 
PROT-602: Failed to retrieve data from the cluster registry
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 trace]# 

------------------------------------------------------------------------
#(3)
#但是此时再次启动cluster报错，因为还原了Olr后与已经打的补丁不一致
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start cluster
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-19rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl check crs
CRS-4639: Could not contact Oracle High Availability Services

[root@k8s-19rac02 dispatcher.d]# ps -ef|grep grid|grep app|awk '{print $2}'|xargs kill -9

[root@k8s-19rac02 dispatcher.d]# ps -ef|grep grid
root     14717 11600  0 11:51 pts/4    00:00:00 grep --color=auto grid
root     26985 11598  0 Nov21 pts/2    00:00:00 su - grid
grid     26987 26985  0 Nov21 pts/2    00:00:00 -bash
grid     29819 26987  0 Nov21 pts/2    00:00:00 tail -100f alert_+ASM2.log


[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.

#解决办法：

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -unlock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crsunlock_k8s-19rac02_2023-11-22_11-54-32AM.log
2023/11/22 11:54:33 CLSRSC-4012: Shutting down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:56 CLSRSC-4013: Successfully shut down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:58 CLSRSC-347: Successfully unlock /u01/app/19.0.0/grid

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/clscfg -localpatch
clscfg: EXISTING configuration version 0 detected.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -lock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-19rac02/crsconfig/crslock_k8s-19rac02_2023-11-22_11-58-45AM.log
2023/11/22 11:58:52 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-19rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-19rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-19rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-19rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-19rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-19rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-19rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-19rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-19rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-19rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-19rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-19rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-19rac02' succeeded
CRS-33676: Start of resource group 'ora.asmgroup' on server 'k8s-19rac02' succeeded.
CRS-2672: Attempting to start 'ora.FRA.dg' on 'k8s-19rac02'
CRS-2672: Attempting to start 'ora.DATA.dg' on 'k8s-19rac02'
CRS-2676: Start of 'ora.FRA.dg' on 'k8s-19rac02' succeeded
CRS-2676: Start of 'ora.DATA.dg' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-19rac02'
CRS-2676: Start of 'ora.xydb.db' on 'k8s-19rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.s_stuwork.svc' on 'k8s-19rac02'
CRS-2676: Start of 'ora.xydb.s_stuwork.svc' on 'k8s-19rac02' succeeded
CRS-6016: Resource auto-start has completed for server k8s-19rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-19rac02 ~]# 

[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
Status of Oracle Cluster Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      84460
	 Available space (kbytes) :     407224
	 ID                       : 1399819439
	 Device/File Name         :       +OCR
                                    Device/File integrity check succeeded

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

                                    Device/File not configured

	 Cluster registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83152
	 Available space (kbytes) :     408532
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#再次手动备份也正常了
[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup

k8s-19rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-19rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844    

#再次打补丁

```



#### 7.2.10.oracle 升级 root两个节点都要分别执行 --oracle upgrade

```bash
su - root

#k8s-19rac01
#在非/和/root目录下执行

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/oracle/product/19.0.0/db_1

#k8s-19rac01约25分钟 
-------------------------------------------------------

#第一次执行报错：

Patch: /opt/opa/35319490/35320081
Log: /u01/app/oracle/product/19.0.0/db_1/cfgtoollogs/opatchauto/core/opatch/opatch2023-10-10_17-11-02PM_1.log
Reason: Failed during Patching: oracle.opatch.opatchsdk.OPatchException: Prerequisite check "CheckActiveFilesAndExecutables" failed.
After fixing the cause of failure Run opatchauto resume
#查看日志：

Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1 PID( 110745 )
Files in use by a process: /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so PID( 110745 )
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
                                    /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so
[Oct 10, 2023 5:11:47 PM] [SEVERE]  OUI-67073:UtilSession failed: Prerequisite check "CheckActiveFilesAndExecutables" failed.

#手动检查进程110745
ps -ef|grep 110745

fuser /u01/app/oracle/product/19.0.0/db_1/lib/libclntsh.so.19.1
fuser /u01/app/oracle/product/19.0.0/db_1/lib/libsqlplus.so

#都没有发现

#此时在第一个报错的窗口执行opatchauto resume恢复正常执行完毕
cd /u01/app/oracle/product/19.0.0/db_1/OPatch/

./opatchauto resume

--------------------------------------------------------

#k8s-19rac02

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/oracle/product/19.0.0/db_1 

#k8s-19rac02约33分钟(最长85 minutes, 13 seconds)

 
#检查补丁情况
su - oracle
cd $ORACLE_HOME/OPatch
./opatch lspatches  


[oracle@k8s-19rac01 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)

OPatch succeeded.


[oracle@k8s-19rac02 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)

OPatch succeeded.
```





#### 7.2.11.升级后动作 after patch

```bash
#(1)
#仅节点1---直接启动全部pdb后，用oracle用户执行datapatch -verbose

su - oracle
sqlplus / as sysdba
show pdbs;
exit

#确认全部pdb已经启动后
cd $ORACLE_HOME/OPatch

#可选
./datapatch -sanity_checks

#执行
./datapatch -verbose


[oracle@k8s-19rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-19rac01 OPatch]$ ./datapatch -sanity_checks 
[oracle@k8s-19rac01 OPatch]$ ./datapatch -verbose 

#执行前确认两个节点pdb都打开，如果pdb没有打开 可能会出现cdb和pdb RU不一致，
#导致pdb受限。如果pdb没有更新 可以使用这个命令强制更新ru

 datapatch -verbose -apply  ru_id -force -pdbs PDB1

#(2)
#编译无效对象---cdb/pdb全部执行

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73500
INVALID        286


SQL> @$ORACLE_HOME/rdbms/admin/utlrp.sql

SQL> select status,count(*) from dba_objects group by status;

STATUS    COUNT(*)
------- ----------
VALID        73786



 

#完成后检查patch情况

set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

 
SQL> select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;

  PATCH_ID PATCH_TYPE ACTION          STATUS          TARGET_VERSION
---------- ---------- --------------- --------------- ---------------
  29517242 RU         APPLY           SUCCESS         19.3.0.0.0
  35320081 RU         APPLY           SUCCESS         19.20.0.0.0
  35643107 RU         APPLY           SUCCESS         19.21.0.0.0



SQL>  select  PATCH_UID,PATCH_ID,ACTION,STATUS,ACTION_TIME ,DESCRIPTION,TARGET_VERSION from dba_registry_sqlpatch;
  
 PATCH_UID   PATCH_ID ACTION          STATUS          ACTION_TIME
---------- ---------- --------------- --------------- ---------------------------------------------------------------------------
DESCRIPTION                                                                                          TARGET_VERSION
---------------------------------------------------------------------------------------------------- ---------------
  22862832   29517242 APPLY           SUCCESS         18-NOV-23 07.31.46.746877 PM
Database Release Update : 19.3.0.0.190416 (29517242)                                                 19.3.0.0.0

  25314491   35320081 APPLY           SUCCESS         22-NOV-23 02.53.28.041848 PM
Database Release Update : 19.20.0.0.230718 (35320081)                                                19.20.0.0.0

  25405995   35643107 APPLY           SUCCESS         22-NOV-23 11.53.49.603359 PM
Database Release Update : 19.21.0.0.231017 (35643107)                                                19.21.0.0.0


[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl query crs releasepatch
Oracle Clusterware release patch level is [2204791795] and the complete list of patches [33575402 35553096 35643107 35652062 35655527 ] have been applied on the local node. The release patch string is [19.21.0.0.0].

[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl query css votedisk
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   dd0f67278ca64f02bf1be1f5476c5897 (/dev/sda) [OCR]
 2. ONLINE   0c98d89348b64f12bf7a4d996fdaff4f (/dev/sdb) [OCR]
 3. ONLINE   a4df36e0ad924f5abff76c6389c32ea8 (/dev/sdc) [OCR]

#常用集群检查命令
#grid用户
cluvfy  stage -post crsinst -n k8s-19rac01,k8s-19rac02 -verbose 
cluvfy comp software  
cluvfy comp sys -allnodes -p crs -verbose
cluvfy comp healthcheck -collect cluster -html
#u01/app/19.0.0/grid/cv/report/html/

asmcmd lsdsk -k
kfed read /dev/sda | grep name


  
--------------------------------------------------
#根据升级文档，datapatch操作可以在全部pdb开启后执行，不再按以下步骤执行

opatch lspatches

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP

SQL> alter system set cluster_database=false scope=spfile;  --设置接非集群

 

srvctl stop db -d dbname  

 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> STARTUP UPGRADE

如果使用了pdb  请确认pdb 全部open

alter pluggable database  all open;


[oracle@k8s-19rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-19rac01 OPatch]$ ./datapatch -verbose 

sqlplus /nolog

SQL> CONNECT / AS SYSDBA

SQL> alter system set cluster_database=true scope=spfile sid='*';

SQL> SHUTDOWN

srvctl start database -d dbname

--------------------------------------------------



#完成后检查patch情况

set linesize 180

col action for a15

col status for a15

select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;


col status for a10
col action for a10
col action_time for a30
col description for a60

select patch_id,patch_type,action,status,action_time,description from dba_registry_sqlpatch;

col version for a25
col comments for a80

select ACTION_TIME,VERSION,COMMENTS from dba_registry_history;



```


---

## LOG-11-01-08 11.1.8 Swingbench操作日志

来源章节: `#### 11.1.8.操作日志logs`

#### 11.1.8.操作日志logs

```bash
[oracle@k8s-rac01 ~]$ sqlplus system/<SYS_PWD>@172.18.13.176:1521/s_stuwork

SQL*Plus: Release 19.0.0.0.0 - Production on Tue Apr 8 10:21:42 2025
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

Last Successful login time: Fri Apr 04 2025 23:17:01 +08:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SYSTEM@172.18.13.176:1521/s_stuwork> select instance_name from v$instance;

INSTANCE_NAME
----------------
xydb3

SYSTEM@172.18.13.176:1521/s_stuwork> 

SYSTEM@172.18.13.176:1521/s_stuwork> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0
[oracle@k8s-rac01 ~]$ 

[oracle@k8s-rac01 ~]$ cd /home/oracle/swingbench/swingbench
[oracle@k8s-rac01 swingbench]$ ls
bin  configs  launcher  lib  log  README.md  source  sql  utils  winbin  wizardconfigs
[oracle@k8s-rac01 swingbench]$ ls bin
charbench    data              jsonwizard  moviewizard  results2pdf  shwizard    swingbench   tpchwizard
coordinator  jsonsocialwizard  minibench   oewizard     sbutil       sqlbuilder  tpcdswizard
[oracle@k8s-rac01 swingbench]$ ./bin/oewizard -h
usage: parameters:
 -allindexes             build all indexes for schema
 -async_off              run without async transactions
 -async_on               run with async transactions (default)
 -bigfile                use big file tablespaces
 -bs <size>              the batch size of rows inserted into the database
 -c <filename>           wizard config file
 -cf <file>              the location of a credentials file for Oracle
                         Autonomous Database
 -cl                     run in character mode
 -compositepart          use a composite paritioning model if it exisits
 -compress               use default compression model if it exists
 -constraints            only create primary/foreign keys for schema
 -create                 create benchmarks schema
 -cs <connectString>     connectring for database
 -dba <username>         dba username for schema creation
 -dbap <password>        password for schema creation
 -debug                  turn on debugging output
 -debugf <debugfile>     turn on debugging. Write output to <debugfile>
                         defaults to debug.log
 -df <datafile>          datafile name used to create schema in
 -drop                   drop benchmarks schema
 -dt <driverType>        driver type (oci|thin)
 -g                      run in graphical mode (default)
 -generate               generate data for benchmark if available
 -h,--help               print this message
 -hashpart               use hash paritioning model if it exists
 -hcccompress            use HCC compression if it exisits
 -idf <datafile>         index datafile used to create indexes in
 -its <datafile>         index tablespace used to create indexes in
 -nc                     Don't use color output
 -nocompress             don't use any database compression
 -noindexes              don't build any indexes for schema
 -nopart                 don't use any database partitioning
 -normalfile             use normal file tablespaces
 -oltpcompress           use OLTP compression if it exisits
 -ot <output type>       output type (json or std), defaults to std
 -p <password>           password for benchmark schema
 -part                   use default paritioning model if it exists
 -rangepart              use a range paritioning model if it exisits
 -ro                     reverse the order in which data is generated
                         (smallest first)
 -s                      run in silent mode
 -scale <scale>          mulitiplier for default config
 -sp <soft partitions>   the number of softparitions used. Defaults to cpu
                         count
 -tc <thread count>      the number of threads(parallelism) used to
                         generate data. Defaults to cpus*2
 -ts <tablespace>        tablespace to create schema in
 -u <username>           username for benchmark schema
 -v                      run in verbose mode when running from command
                         line
 -version <version>      version of the benchmark to run
 
[oracle@k8s-rac01 swingbench]$ ./bin/oewizard -cl \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe \
  -p soe \
  -ts swingbench_data \
  -its swingbench_index \
  -scale 1 \
  -create \
  -v \
  -c /home/oracle/swingbench/configs/SOE_Server_Side_V2.xml \
  -df +DATA \
  -nopart
  
SwingBench Wizard
Author  :	Dominic Giles
Version :	2.7.0.1511

Running in Lights Out Mode using config file : ../wizardconfigs/oewizard.xml
ERROR : Cannot connect to the database using the details provided.                       
ERROR :  ORA-01017: invalid username/password; logon denied

https://docs.oracle.com/error-help/db/ora-01017/ 



[oracle@k8s-rac01 swingbench]$ ./bin/oewizard -cl \
  -cs //172.18.13.176:1521/s_stuwork \
  -dba "sys as sysdba" \
  -dbap "abc123" \
  -u soe \
  -p soe \
  -ts swingbench_data \
  -its swingbench_index \
  -scale 1 \
  -create \
  -v \
  -c /home/oracle/swingbench/configs/SOE_Server_Side_V2.xml \
  -df +DATA \
  -nopart


SwingBench Wizard
Author  :	Dominic Giles
Version :	2.7.0.1511

Running in Lights Out Mode using config file : ../wizardconfigs/oewizard.xml
Starting run                                                                            
Starting script ../sql/orderentry/soedgdrop2.sql                                        
Script completed in 0 hour(s) 0 minute(s) 0 second(s) 136 millisecond(s)                
Starting script ../sql/orderentry/soedgcreatetables2.sql                                
Script completed in 0 hour(s) 0 minute(s) 0 second(s) 350 millisecond(s)                
Starting script ../sql/orderentry/soedgviews.sql                                        
Script completed in 0 hour(s) 0 minute(s) 0 second(s) 66 millisecond(s)                 
Starting script ../sql/orderentry/soedgsqlset.sql                                       
Script completed in 0 hour(s) 0 minute(s) 0 second(s) 235 millisecond(s)                
Inserting data into table PRODUCT_INFORMATION                                           
Inserting data into table INVENTORIES                                                   
Inserting data into table ADDRESSES_16 
Inserting data into table ADDRESSES_14                                                  
Inserting data into table ADDRESSES_4                                                   
Inserting data into table ADDRESSES_15                                                  
Inserting data into table ADDRESSES_5                                                   
Inserting data into table ADDRESSES_6                                                   
Inserting data into table ADDRESSES_3 
Inserting data into table ADDRESSES_1                                                   
Inserting data into table ADDRESSES_2                                                   
Inserting data into table ADDRESSES_10                                                  
Inserting data into table ADDRESSES_13                                                  
Inserting data into table ADDRESSES_9                                                   
Inserting data into table ADDRESSES_8                                                   
Inserting data into table ADDRESSES_11                                                  
Inserting data into table ADDRESSES_7                                                   
Inserting data into table ADDRESSES_12                                                  
Inserting data into table CUSTOMERS_16                                                  
Inserting data into table CUSTOMERS_1                                                   
Inserting data into table CUSTOMERS_6                                                   
Inserting data into table CUSTOMERS_10                                                  
Inserting data into table CUSTOMERS_11                                                  
Inserting data into table CUSTOMERS_12                                                  
Inserting data into table CUSTOMERS_13                                                  
Inserting data into table CUSTOMERS_14                                                  
Inserting data into table CUSTOMERS_15 
Inserting data into table CUSTOMERS_5                                                   
Inserting data into table CUSTOMERS_4                                                   
Inserting data into table CUSTOMERS_3                                                   
Inserting data into table CUSTOMERS_2                                                   
Inserting data into table CUSTOMERS_9                                                   
Completed processing table PRODUCT_INFORMATION in 0:00:01                               
Inserting data into table CUSTOMERS_8                                                   
Completed processing table CUSTOMERS_9 in 0:00:05 a generation completed : 12.49%       
Inserting data into table CUSTOMERS_7                                                   
Completed processing table CUSTOMERS_16 in 0:00:05                                      
Inserting data into table ORDERS_16                                                     
Inserting data into table ORDER_ITEMS_1340415                                           
Completed processing table CUSTOMERS_13 in 0:00:05                                      
Inserting data into table ORDER_ITEMS_268083                                            
Completed processing table ADDRESSES_16 in 0:00:05 
Inserting data into table ORDERS_4                                                      
Completed processing table CUSTOMERS_1 in 0:00:05                                       
Completed processing table ADDRESSES_13 in 0:00:05                                      
Inserting data into table ORDER_ITEMS_536166                                            
Inserting data into table ORDERS_7                                                      
Completed processing table CUSTOMERS_15 in 0:00:06                                      
Completed processing table CUSTOMERS_14 in 0:00:06                                      
Inserting data into table ORDER_ITEMS_714888                                            
Inserting data into table ORDERS_9                                                      
Completed processing table ADDRESSES_5 in 0:00:06                                       
Completed processing table ADDRESSES_12 in 0:00:06                                      
Inserting data into table ORDERS_13                                                     
Inserting data into table ORDER_ITEMS_1072332                                           
Completed processing table ADDRESSES_8 in 0:00:06                                       
Completed processing table ADDRESSES_7 in 0:00:06                                       
Inserting data into table ORDERS_14                                                     
Inserting data into table ORDER_ITEMS_1161693 
Completed processing table ADDRESSES_10 in 0:00:06                                      
Completed processing table ADDRESSES_14 in 0:00:06                                      
Inserting data into table ORDER_ITEMS_446805                                            
Inserting data into table ORDERS_6                                                      
Completed processing table CUSTOMERS_5 in 0:00:06                                       
Inserting data into table ORDER_ITEMS_0                                                 
Completed processing table CUSTOMERS_8 in 0:00:05 
Inserting data into table ORDERS_1                                                      
Completed processing table CUSTOMERS_11 in 0:00:07                                      
Inserting data into table ORDER_ITEMS_178722                                            
Completed processing table CUSTOMERS_3 in 0:00:07 
Inserting data into table ORDERS_3                                                      
Completed processing table CUSTOMERS_2 in 0:00:07                                       
Completed processing table ADDRESSES_9 in 0:00:07                                       
Inserting data into table ORDERS_10                                                     
Inserting data into table ORDER_ITEMS_804249                                            
Completed processing table CUSTOMERS_4 in 0:00:07                                       
Inserting data into table ORDERS_12                                                     
Completed processing table CUSTOMERS_6 in 0:00:07 
Inserting data into table ORDER_ITEMS_982971 
Completed processing table CUSTOMERS_10 in 0:00:07                                      
Inserting data into table ORDER_ITEMS_357444                                            
Completed processing table CUSTOMERS_12 in 0:00:07 
Inserting data into table ORDERS_5                                                      
Completed processing table ADDRESSES_4 in 0:00:07                                       
Inserting data into table ORDER_ITEMS_625527                                            
Inserting data into table ORDERS_8                                                      
Completed processing table ADDRESSES_15 in 0:00:08 
Completed processing table ADDRESSES_11 in 0:00:08                                      
Inserting data into table ORDER_ITEMS_893610                                            
Inserting data into table ORDERS_11                                                     
Completed processing table CUSTOMERS_7 in 0:00:03 
Completed processing table ADDRESSES_2 in 0:00:08                                       
Inserting data into table ORDER_ITEMS_1251054                                           
Inserting data into table ORDERS_15                                                     
Completed processing table ADDRESSES_3 in 0:00:08 
Completed processing table ADDRESSES_6 in 0:00:08                                       
Completed processing table ADDRESSES_1 in 0:00:08                                       
Inserting data into table ORDER_ITEMS_89361                                             
Inserting data into table ORDERS_2 
Completed processing table INVENTORIES in 0:00:11                                       
Completed processing table ORDERS_3 in 0:00:22                                          
Inserting data into table CARD_DETAILS_16 
Completed processing table ORDERS_6 in 0:00:23                                          
Inserting data into table CARD_DETAILS_15                                               
Completed processing table ORDERS_1 in 0:00:23                                          
Inserting data into table CARD_DETAILS_13                                               
Completed processing table ORDERS_2 in 0:00:21                                          
Inserting data into table CARD_DETAILS_12                                               
Completed processing table ORDERS_9 in 0:00:24                                          
Inserting data into table CARD_DETAILS_7                                                
Completed processing table ORDERS_10 in 0:00:23                                         
Inserting data into table CARD_DETAILS_14                                               
Completed processing table ORDERS_5 in 0:00:23                                          
Inserting data into table CARD_DETAILS_10                                               
Completed processing table ORDERS_15 in 0:00:22                                         
Inserting data into table CARD_DETAILS_8                                                
Completed processing table ORDERS_8 in 0:00:23                                          
Inserting data into table CARD_DETAILS_2                                                
Completed processing table ORDERS_12 in 0:00:24                                         
Inserting data into table CARD_DETAILS_4                                                
Completed processing table ORDER_ITEMS_446805 in 0:00:25                                
Inserting data into table CARD_DETAILS_9                                                
Completed processing table ORDER_ITEMS_714888 in 0:00:25                                
Inserting data into table CARD_DETAILS_6                                                
Completed processing table ORDERS_11 in 0:00:24                                         
Inserting data into table CARD_DETAILS_3                                                
Completed processing table ORDER_ITEMS_89361 in 0:00:23                                 
Inserting data into table CARD_DETAILS_1                                                
Completed processing table ORDER_ITEMS_804249 in 0:00:25                                
Inserting data into table CARD_DETAILS_5                                                
Completed processing table ORDER_ITEMS_357444 in 0:00:25                                
Inserting data into table CARD_DETAILS_11                                               
Completed processing table CARD_DETAILS_9 in 0:00:01                                    
Inserting data into table LOGON_16                                                      
Completed processing table CARD_DETAILS_15 in 0:00:03                                   
Inserting data into table LOGON_15                                                      
Completed processing table CARD_DETAILS_13 in 0:00:02                                   
Inserting data into table LOGON_10                                                      
Completed processing table CARD_DETAILS_10 in 0:00:02                                   
Inserting data into table LOGON_9                                                       
Completed processing table CARD_DETAILS_7 in 0:00:02                                    
Inserting data into table LOGON_8 ds (32/32) : Data generation completed : 74.61%       
Completed processing table CARD_DETAILS_14 in 0:00:02                                   
Inserting data into table LOGON_1                                                       
Completed processing table CARD_DETAILS_16 in 0:00:04                                   
Inserting data into table LOGON_12                                                      
Completed processing table ORDER_ITEMS_178722 in 0:00:27                                
Inserting data into table LOGON_6                                                       
Completed processing table ORDER_ITEMS_0 in 0:00:27                                     
Inserting data into table LOGON_2                                                       
Completed processing table ORDER_ITEMS_1251054 in 0:00:25                               
Inserting data into table LOGON_7                                                       
Completed processing table CARD_DETAILS_4 in 0:00:02                                    
Inserting data into table LOGON_4                                                       
Completed processing table CARD_DETAILS_6 in 0:00:02                                    
Inserting data into table LOGON_5                                                       
Completed processing table ORDER_ITEMS_982971 in 0:00:27                                
Inserting data into table LOGON_11                                                      
Completed processing table CARD_DETAILS_5 in 0:00:02                                    
Inserting data into table LOGON_14                                                      
Completed processing table ORDER_ITEMS_893610 in 0:00:26                                
Inserting data into table LOGON_3                                                       
Completed processing table ORDER_ITEMS_625527 in 0:00:26                                
Inserting data into table LOGON_13                                                      
Completed processing table CARD_DETAILS_11 in 0:00:02                                   
Inserting data into table PRODUCT_DESCRIPTIONS                                          
Completed processing table PRODUCT_DESCRIPTIONS in 0:00:00                              
Inserting data into table WAREHOUSES                                                    
Completed processing table WAREHOUSES in 0:00:00                                        
Completed processing table CARD_DETAILS_1 in 0:00:03                                    
Completed processing table CARD_DETAILS_8 in 0:00:04                                    
Completed processing table CARD_DETAILS_12 in 0:00:05                                   
Completed processing table CARD_DETAILS_2 in 0:00:04                                    
Completed processing table CARD_DETAILS_3 in 0:00:03                                    
Completed processing table LOGON_1 in 0:00:04                                           
Completed processing table LOGON_4 in 0:00:03                                           
Completed processing table LOGON_14 in 0:00:03 Data generation completed : 95.89%       
Completed processing table LOGON_16 in 0:00:04                                          
Completed processing table LOGON_11 in 0:00:03                                          
Completed processing table LOGON_10 in 0:00:04                                          
Completed processing table LOGON_15 in 0:00:04                                          
Completed processing table LOGON_13 in 0:00:03                                          
Completed processing table LOGON_9 in 0:00:04                                           
Completed processing table LOGON_7 in 0:00:03                                           
Completed processing table LOGON_12 in 0:00:04                                          
Completed processing table LOGON_5 in 0:00:03                                           
Completed processing table ORDERS_7 in 0:00:32                                          
Completed processing table LOGON_8 in 0:00:04                                           
Completed processing table LOGON_2 in 0:00:04                                           
Completed processing table LOGON_3 in 0:00:03                                           
Completed processing table LOGON_6 in 0:00:04                                           
Completed processing table ORDERS_4 in 0:00:33                                          
Completed processing table ORDERS_13 in 0:00:32                                         
Completed processing table ORDERS_16 in 0:00:34                                         
Completed processing table ORDERS_14 in 0:00:33                                         
Completed processing table ORDER_ITEMS_536166 in 0:00:34                                
Completed processing table ORDER_ITEMS_268083 in 0:00:35                                
Completed processing table ORDER_ITEMS_1072332 in 0:00:34                               
Completed processing table ORDER_ITEMS_1340415 in 0:00:35                               
Starting script ../sql/orderentry/soedganalyzeschema2.sql                               
ERROR : The following statement failed : BEGIN                                           
    DBMS_STATS.set_global_prefs ( 
        pname   => 'CONCURRENT', 
        pvalue  => 'AUTOMATIC' 
    ); 
END; 
 : Due to : ORA-20000: Insufficient privileges
ORA-06512: at "SYS.DBMS_STATS", line 10348
ORA-06512: at "SYS.DBMS_STATS", line 52374
ORA-06512: at "SYS.DBMS_STATS", line 52737
ORA-06512: at line 2

https://docs.oracle.com/error-help/db/ora-20000/

Script completed in 0 hour(s) 0 minute(s) 28 second(s) 304 millisecond(s)               
Starting script ../sql/orderentry/soedgconstraints2.sql                                 
Script completed in 0 hour(s) 0 minute(s) 40 second(s) 886 millisecond(s)               
Starting script ../sql/orderentry/soedgindexes2.sql                                     
Script completed in 0 hour(s) 1 minute(s) 10 second(s) 599 millisecond(s)               
Starting script ../sql/orderentry/soedgsequences2.sql                                   
Script completed in 0 hour(s) 0 minute(s) 24 second(s) 456 millisecond(s)               
Starting script ../sql/orderentry/soedgpackage2_header.sql                              
Script completed in 0 hour(s) 0 minute(s) 0 second(s) 279 millisecond(s)                
Starting script ../sql/orderentry/soedgpackage2_body.sql                                
Script completed in 0 hour(s) 0 minute(s) 0 second(s) 214 millisecond(s)                
Starting script ../sql/orderentry/soedgsetupmetadata.sql                                
Script completed in 0 hour(s) 0 minute(s) 2 second(s) 445 millisecond(s)                

Data Generation Runtime Metrics
+-------------------------+-------------+
| Description             | Value       |
+-------------------------+-------------+
| Connection Time         | 0:00:00.002 |
| Data Generation Time    | 0:00:41.792 |
| DDL Creation Time       | 0:02:48.034 |
| Total Run Time          | 0:03:29.832 |
| Rows Inserted per sec   | 379,612     |
| Actual Rows Generated   | 15,857,704  |
| Commits Completed       | 928         |
| Batch Updates Completed | 79,406      |
+-------------------------+-------------+

Validation Report                                                                       
The schema appears to have been created successfully.

Valid Objects
Valid Tables : 'ORDERS','ORDER_ITEMS','CUSTOMERS','WAREHOUSES','ORDERENTRY_METADATA','INVENTORIES','PRODUCT_INFORMATION','PRODUCT_DESCRIPTIONS','ADDRESSES','CARD_DETAILS'
Valid Indexes : 'PRD_DESC_PK','PROD_NAME_IX','PRODUCT_INFORMATION_PK','PROD_SUPPLIER_IX','PROD_CATEGORY_IX','INVENTORY_PK','INV_PRODUCT_IX','INV_WAREHOUSE_IX','ORDER_PK','ORD_SALES_REP_IX','ORD_CUSTOMER_IX','ORD_ORDER_DATE_IX','ORD_WAREHOUSE_IX','ORDER_ITEMS_PK','ITEM_ORDER_IX','ITEM_PRODUCT_IX','WAREHOUSES_PK','WHS_LOCATION_IX','CUSTOMERS_PK','CUST_EMAIL_IX','CUST_ACCOUNT_MANAGER_IX','CUST_FUNC_LOWER_NAME_IX','ADDRESS_PK','ADDRESS_CUST_IX','CARD_DETAILS_PK','CARDDETAILS_CUST_IX'
Valid Views : 'PRODUCTS','PRODUCT_PRICES'
Valid Sequences : 'CUSTOMER_SEQ','ORDERS_SEQ','ADDRESS_SEQ','LOGON_SEQ','CARD_DETAILS_SEQ'
Valid Code : 'ORDERENTRY'
Schema Created


[oracle@k8s-rac01 orderentry]$ cat soedganalyzeschema2.sql
BEGIN
    DBMS_STATS.set_global_prefs (
        pname   => 'CONCURRENT',
        pvalue  => 'AUTOMATIC'
    );
END;
/

begin
    dbms_stats.gather_schema_stats(
        ownname => '&username',
        estimate_percent => dbms_stats.auto_sample_size,
        block_sample => true,
        method_opt =>'FOR ALL COLUMNS SIZE SKEWONLY',
        degree => &parallelism,
        granularity => 'ALL',
        cascade => true
    );
end;
/

--End
[oracle@k8s-rac01 orderentry]$

#解决办法
#方案一
#以具有足够权限的用户（如 SYS）执行操作
BEGIN
    DBMS_STATS.set_global_prefs (
        pname   => 'CONCURRENT',
        pvalue  => 'AUTOMATIC'
    );
END;
/

#方案二
#以SYSDBA权限授予必要的权限给当前用户
GRANT ANALYZE ANY TO soe;
GRANT ANALYZE ANY DICTIONARY TO soe;



[oracle@k8s-rac01 swingbench]$ cp configs/SOE_Server_Side_V2.xml configs/19RAC_Test.xml
[oracle@k8s-rac01 swingbench]$ vi configs/19RAC_Test.xml


[oracle@k8s-rac01 swingbench]$ ./bin/charbench \
  -c ./configs/19RAC_Test.xml \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe \
  -p soe \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 100 \
  -rt 00:30 \
  -a
  


11:59:04  [100/100]   120090   3617    
Saved results to results.xml 
11:59:05  [0/100]     120016   3119    
Completed Run. 
[oracle@k8s-rac01 swingbench]$ ls
bin  configs  launcher  lib  log  README.md  source  sql  utils  winbin  wizardconfigs
[oracle@k8s-rac01 swingbench]$ find ./ -name results.xml
./bin/results.xml
[oracle@k8s-rac01 swingbench]$ ./bin/swingbench -h
Error : You're trying to start swingbench on a server without a graphical frontend. Try using charbench instead.
[oracle@k8s-rac01 swingbench]$ ./bin/swingbench --help
Error : You're trying to start swingbench on a server without a graphical frontend. Try using charbench instead.
[oracle@k8s-rac01 swingbench]$ ./bin/swingbench -ls ./bin/results.xml 
Error : You're trying to start swingbench on a server without a graphical frontend. Try using charbench instead.
[oracle@k8s-rac01 swingbench]$ ls bin
charbench    data              jsonwizard  moviewizard  results2pdf  sbutil    sqlbuilder  tpcdswizard
coordinator  jsonsocialwizard  minibench   oewizard     results.xml  shwizard  swingbench  tpchwizard
[oracle@k8s-rac01 swingbench]$ ./bin/results2pdf -h
Results2Pdf 
Author  :  	 Dominic Giles 
Version :  	 2.7.0.1511 
usage: parameters:
 -c <filename>   the config file to convert from xml to pdf
 -debug          send debug information to stdout
 -h,--help       print this message
 -o <arg>        output filename
[oracle@k8s-rac01 swingbench]$ ./bin/results2pdf -c ./bin/results.xml -o 100results.pdf
Results2Pdf 
Author  :  	 Dominic Giles 
Version :  	 2.7.0.1511 
The results file  ./bin/results.xml  does not exist. Exiting, please try again.
[oracle@k8s-rac01 swingbench]$ ./bin/results2pdf -c results.xml -o 100results.pdf
Results2Pdf 
Author  :  	 Dominic Giles 
Version :  	 2.7.0.1511 
Success : Pdf file 100results.pdf was created from results.xml results file.
[oracle@k8s-rac01 swingbench]$ ls bin
100results.pdf  coordinator  jsonsocialwizard  minibench    oewizard     results.xml  shwizard    swingbench   tpchwizard
charbench       data         jsonwizard        moviewizard  results2pdf  sbutil       sqlbuilder  tpcdswizard
[oracle@k8s-rac01 swingbench]$ 



#100并发时
[oracle@k8s-19rac03 ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Tue Apr 8 11:31:10 2025
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> alter session set container=stuwork;

Session altered.

SQL> SELECT event, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE' AND wait_class != 'Idle' 
GROUP BY event 
ORDER BY COUNT(*) DESC;  2    3    4    5  

EVENT								   COUNT(*)
---------------------------------------------------------------- ----------
log file sync								 46
gc buffer busy release							 18
gc current request							 13
gc cr request								  7
gc buffer busy acquire							  6
db file sequential read 						  5
gc cr block 3-way							  3
gc current grant 2-way							  1

8 rows selected.

SQL> /

EVENT								   COUNT(*)
---------------------------------------------------------------- ----------
gc current request							 34
gc cr request								 25
log file sync								 19
db file sequential read 						  6
gc buffer busy acquire							  5
gc cr multi block request						  3
read by other session							  1
gc current block 2-way							  1
gc cr block 3-way							  1
gc cr block 2-way							  1

10 rows selected.

SQL> SELECT inst_id, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE' 
GROUP BY inst_id;  2    3    4  

   INST_ID   COUNT(*)
---------- ----------
	 1	   35
	 2	   34
	 3	   32

SQL> SELECT inst_id, value 
FROM gv$sysmetric 
WHERE metric_name = 'CPU Usage Per Sec' 
AND group_id = 2;  2    3    4  

no rows selected

SQL> SELECT inst_id, resource_name, current_utilization, max_utilization 
FROM gv$resource_limit 
WHERE resource_name IN ('processes', 'sessions', 'transactions') 
ORDER BY inst_id, resource_name;  2    3    4  

no rows selected

SQL> SELECT event, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE' AND wait_class != 'Idle' 
GROUP BY event 
ORDER BY COUNT(*) DESC;  2    3    4    5  

EVENT								   COUNT(*)
---------------------------------------------------------------- ----------
log file sync								 38
gc current request							 21
gc cr request								 15
gc cr block 2-way							  6
gc current block busy							  4
gc current block 2-way							  3
library cache: mutex X							  3
gc cr block 3-way							  1
kfk: async disk IO							  1
gc current grant busy							  1
enq: HW - contention							  1

EVENT								   COUNT(*)
---------------------------------------------------------------- ----------
gc current block 3-way							  1
db file sequential read 						  1

13 rows selected.

SQL> SELECT inst_id, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE' 
GROUP BY inst_id;  2    3    4  

   INST_ID   COUNT(*)
---------- ----------
	 1	   35
	 2	   34
	 3	   32

SQL> SELECT inst_id, resource_name, current_utilization, max_utilization 
FROM gv$resource_limit 
WHERE resource_name IN ('processes', 'sessions', 'transactions') 
ORDER BY inst_id, resource_name;  2    3    4  

no rows selected

SQL> 


```


---

## LOG-14-01 14.1 CTSS/chrony历史错误处理记录

来源章节: `### 14.1.CTSS/chrony历史错误处理记录(禁止照做)`

### 14.1.CTSS/chrony历史错误处理记录(禁止照做)

#背景:当时误以为CTSS需要进入Active模式,采用了"移走/etc/chrony.conf"的错误做法。
#现行标准(2.5节):保留chronyd统一对接校园NTP源,CTSS处于Observer模式即为正确状态。

```text
#!!!以下为历史错误处理记录(当时误以为CTSS需要进入Active模式),仅保留用于说明现象,禁止照做!!!
#现行标准见2.5节:保留chronyd并统一对接校园NTP源,CTSS处于Observer模式即为正确状态
#禁止通过删除/移走/etc/chrony.conf或停用chronyd的方式让CTSS进入Active模式
#----------------------------------历史记录开始----------------------------------
#如果存在/etc/ntp.conf或者/etc/chrony.conf会导致octssd处于Observer模式
#日志目录/u01/app/grid/diag/crs/rac02/crs/trace/octssd.trc
# ctsselect_msm: CTSS mode is [0xc6]


[grid@rac02 ~]$  cluvfy comp clocksync -n all -verbose

Performing following verification checks ...

  Clock Synchronization ...
  Node Name                             Status
  ------------------------------------  ------------------------
  rac02                                 passed
  rac01                                 passed

  Node Name                             State
  ------------------------------------  ------------------------
  rac02                                 Observer
  rac01                                 Observer

CTSS is in Observer state. Switching over to clock synchronization checks using NTP

    Network Time Protocol (NTP) ...
      '/etc/chrony.conf' ...
    Node Name                             File exists?
    ------------------------------------  ------------------------
    rac02                                 no
    rac01                                 yes

      '/etc/chrony.conf' ...FAILED (PRVG-1019)
      '/var/run/ntpd.pid' ...
    Node Name                             File exists?
    ------------------------------------  ------------------------
    rac02                                 no
    rac01                                 no


#此时将rac1中chrony.conf移除掉，就会ctss进入active模式(历史错误做法,现已禁止,见2.5节)
# ctsselect_msm: CTSS mode is [0xc4]
[root@rac01 ~]$ mv /etc/chrony.conf  /etc/chrony.conf.bak
[root@rac01 ~]$ su - grid

[grid@rac01 ~]$ cluvfy comp clocksync -n all -verbose

Performing following verification checks ...

  Clock Synchronization ...
  Node Name                             Status
  ------------------------------------  ------------------------
  rac01                                 passed
  rac02                                 passed

  Node Name                             State
  ------------------------------------  ------------------------
  rac02                                 Active
  rac01                                 Active

  Node Name     Time Offset               Status
  ------------  ------------------------  ------------------------
  rac02         0.0                       passed
  rac01         0.0                       passed
  Clock Synchronization ...PASSED

Verification of Clock Synchronization across the cluster nodes was successful.

CVU operation performed:      Clock Synchronization across the cluster nodes
Date:                         Oct 25, 2023 10:55:34 AM
CVU version:                  19.20.0.0.0 (062923x8664)
Clusterware version:          19.0.0.0.0
CVU home:                     /u01/app/19.0.0/grid
Grid home:                    /u01/app/19.0.0/grid
User:                         grid
Operating system:             Linux5.4.17-2011.6.2.el7uek.x86_64


[grid@rac02 ~]$  cluvfy comp clocksync -n all -verbose
```


---

## LOG-14-02 14.2 iSCSI参数调优历史对比记录

来源章节: `### 14.2.iSCSI参数调优历史对比记录(含错误配置,禁止照抄)`

### 14.2.iSCSI参数调优历史对比记录(含错误配置,禁止照抄)

#背景:当时good侧记录的nr_sessions=4/replacement_timeout=60为旧标准;
#现行标准为nr_sessions=1、replacement_timeout=30,理由与验收见1.7节。

```text
#!!!说明:以下good/bad两段为当时调参的历史对比记录,仅保留用于追溯,不作为执行依据
#(good侧记录的nr_sessions=4/replacement_timeout=60为旧标准;现行标准为1/30,理由见下文"修改以下参数")
#优化后参数
#good
[root@k8s-19rac01 ~]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
iscsid.startup = /bin/systemctl start iscsid.socket iscsiuio.socket
iscsid.safe_logout = Yes
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 60
node.conn[0].timeo.login_timeout = 15
node.conn[0].timeo.logout_timeout = 15
node.conn[0].timeo.noop_out_interval = 2
node.conn[0].timeo.noop_out_timeout = 3
node.session.err_timeo.abort_timeout = 15
node.session.err_timeo.lu_reset_timeout = 30
node.session.err_timeo.tgt_reset_timeout = 30
node.session.initial_login_retry_max = 8
node.session.cmds_max = 256
node.session.queue_depth = 128
node.session.xmit_thread_priority = -20
node.session.iscsi.InitialR2T = No
node.session.iscsi.ImmediateData = Yes
node.session.iscsi.FirstBurstLength = 262144
node.session.iscsi.MaxBurstLength = 16776192
node.conn[0].iscsi.MaxRecvDataSegmentLength = 262144
node.conn[0].iscsi.MaxXmitDataSegmentLength = 262144
discovery.sendtargets.iscsi.MaxRecvDataSegmentLength = 32768
node.conn[0].iscsi.HeaderDigest = CRC32C
node.session.nr_sessions = 4
node.session.iscsi.RedirectSupport = Yes
node.session.iscsi.FastAbort = Yes
node.session.scan = auto

#bad
[root@k8s-19rac02 iscsi]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
iscsid.startup = /bin/systemctl start iscsid.socket iscsiuio.socket
iscsid.safe_logout = Yes
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 3
node.conn[0].timeo.login_timeout = 15
node.conn[0].timeo.logout_timeout = 15
node.conn[0].timeo.noop_out_interval = 1
node.conn[0].timeo.noop_out_timeout = 1
node.session.err_timeo.abort_timeout = 15
node.session.err_timeo.lu_reset_timeout = 30
node.session.err_timeo.tgt_reset_timeout = 30
node.session.initial_login_retry_max = 2
node.session.cmds_max = 128
node.session.queue_depth = 32
node.session.xmit_thread_priority = -20
node.session.iscsi.InitialR2T = No
node.session.iscsi.ImmediateData = Yes
node.session.iscsi.FirstBurstLength = 262144
node.session.iscsi.MaxBurstLength = 16776192
node.conn[0].iscsi.MaxRecvDataSegmentLength = 262144
node.conn[0].iscsi.MaxXmitDataSegmentLength = 0
discovery.sendtargets.iscsi.MaxRecvDataSegmentLength = 32768
node.conn[0].iscsi.HeaderDigest = None
node.session.nr_sessions = 1
node.session.iscsi.FastAbort = Yes
node.session.scan = auto
```

