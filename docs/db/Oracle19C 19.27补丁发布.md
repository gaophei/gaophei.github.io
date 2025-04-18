# A.Oracle19C 19.27补丁发布

北京时间4/16日Oracle 19C 19.27季度补丁发布，

The Database patch bundles that were released on April 15, 2025 for Release 19c were:

|                             Name                             | Download Link  |
| :----------------------------------------------------------: | :------------: |
|           Database Release Update 19.27.0.0.250415           | Patch 37642901 |
|     Grid Infrastructure Release Update 19.27.0.0.250415      | Patch 37641958 |
|             OJVM Release Update 19.27.0.0.250415             | Patch 37499406 |
| Microsoft Windows 32-Bit & x86-64 Bundle Patch 19.27.0.0.250415 | Patch 37532350 |

This is the Known Issues note for the patches listed above. These known issues are in addition to the issues listed:

- in the README file for each individual Release Update (RU),, or Bundle Patch (BP).
- in Note 555.1, "Oracle Database 19c Important Recommended One-off Patches"

Beginning with the October 2022 patching cycle, 19c Release Update Revisions (RURs) will no longer be provided for 19.17.0 and above. No additional RURs will be delivered on any platform after the delivery of Oracle Database 19c RUR 19.16.2 in January, 2023. Refer to Sunsetting of 19c RURs and FAQ (Note 2898381.1) for further details.

To provide customers more frequent access to recommended and well-tested collections of patches, Oracle is pleased to introduce Monthly Recommended Patches (MRPs) starting

**Oracle Database 19c RU, and BP Apr 2025 Known Issues**



My Oracle Support Document ID: 19202504.9

Released: April 15, 2025

This document lists the known issues for Oracle Database / Grid Infrastructure / OJVM Release 19c Apr 2025. These known issues are in addition to the issues listed in the README file for each individual RU, or BP.

Oracle recommends that you subscribe to this Known Issues NOTE in order to stay informed of any emergent problems.

This document includes the following sections:

- Section 1, "Known Issues"
- Section 2, "Modification History"
- Section 3, "Documentation Accessibility"



**1 Known Issues**

*This issue applies to DB RU 19.27.*

![图片](https://mmbiz.qpic.cn/mmbiz_png/UVPsfafg9IeUe8lBGmwRBibScwVlrr5ZSevznbPrumiarMUU3w8ImeoIBxFyGnNiaXCeOraMlQxrSOJLWLaKT1IBA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1&wx_co=1)

![图片](https://mmbiz.qpic.cn/mmbiz_png/UVPsfafg9IeUe8lBGmwRBibScwVlrr5ZSOkZReg3qKMIbCpic6shgibnCGGCpF8ib79Z4e5EQVJAXtrS84S7aVZ4UA/640?wx_fmt=png&from=appmsg&tp=wxpic&wxfrom=5&wx_lazy=1&wx_co=1)



# **B.Oracle 19c RAC 打补丁升级到 19.27**

本文仅供简明指令和大概用时，方便直接 copy 使用，并了解指令的预期执行时间，减少等待焦虑。

## 一、补丁包列表

- p6880880_190000_Linux-x86-64.zip (更新 OPatch .45)
- p37499406_190000_Linux-x86-64.zip (OJVM 19.27)
- p37642901_190000_Linux-x86-64.zip (DB 19.27)
- p37641958_190000_Linux-x86-64.zip (GI 19.27)

## 二、更新 OPatch (grid/oracle)

【root】

```
mv OPatch OPatch.bak
unzip -q p6880880_190000_Linux-x86-64.zip -d $ORACLE_HOME
chmod -R 755 OPatch
chown -R grid:oinstall / oracle:oinstall
opatch version # 检查新版本
```

## 三、解压 patch 包

【root】

```
unzip p37641958_190000_Linux-x86-64.zip -d /u01/app/
unzip p37499406_190000_Linux-x86-64.zip -d /u01/app/
chown -R grid:oinstall /u01/app/37641958 /u01/app/37499406
chmod -R 755
```

## 四、OPatch 兼容性检查

【grid】

```
$GRID_HOME/OPatch/opatch lsinventory -detail
```

## 五、补丁冲突检查

【grid/oracle】

```
opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /u01/app/37641958/[subdir]
opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /u01/app/37499406
```

## 六、空间检查

```
vi /tmp/patch_list_gihome.txt
/u01/app/37641958/[patch1]
/u01/app/37641958/[patch2]
/u01/app/37499406
opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_list_gihome.txt
```

## 七、补丁分析 (Analyze)

```
opatchauto apply /u01/app/37499406 -analyze   # 约7分钟
opatchauto apply /u01/app/37641958 -analyze   # 约13分钟
```

## 八、GRID 升级

```
opatchauto apply /u01/app/37499406 -oh $GRID_HOME  # OJVM, 7min
opatchauto apply /u01/app/37641958 -oh $GRID_HOME  # GI, 13min
opatch lspatches  # 确认 patch 状态
```

## 九、DB 升级 (Oracle home)

```
srvctl stop database -d <dbname>
opatchauto apply /u01/app/37641958/37642901 -oh $ORACLE_HOME  # 约6.5分钟
```

## 十、升级后操作 (only node1)

```
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
$ORACLE_HOME/OPatch/datapatch -verbose  # 约35min

-- 如有未更新 PDB
$ORACLE_HOME/OPatch/datapatch -verbose -apply 37642901 -force -pdbs <pdbname>

-- 编译无效对象
@$ORACLE_HOME/rdbms/admin/utlrp.sql
```

## 十一、查看补丁实际状态

```
set linesize 180
col action for a15
col status for a15
select PATCH_ID,PATCH_TYPE,ACTION,STATUS,TARGET_VERSION from dba_registry_sqlpatch;
```

至此，19c RAC 升级至19.27 完成。