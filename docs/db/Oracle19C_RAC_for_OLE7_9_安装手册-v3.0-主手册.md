**19C RAC for Centos7.9 安装手册华三超融合-无网卡绑定多路径-本地存储共享**



[TOC]



## 0.变量表与脱敏说明

#v2.5.2变更说明:本版在v2.5.1基础上补齐postcheck HugePages断言,并将expdp逻辑备份改造为按PDB分文件、同步到192.168.100.100:/data的异地备份方案。
#v2.6变更说明:本版进入P2文档优化,补充OS+DB+ASM参数基线、MTU 9000端到端方案、监听VNCR安全、FAN/ONS/TAC说明和监控平台化接入。
#v2.6.1变更说明:修复P2审核发现的sysctl多源覆盖问题,并收口MTU条件断言、SQLNET.EXPIRE_TIME重复写入、VNCR SCAN监听、监控状态文件与备份静默失败告警。
#v2.7变更说明:进入P3文档优化,补充tgtd到LIO(targetcli)演进方案、生产SCAN/DNS标准、容量规划方法和静默安装路径;本轮暂不拆册、不迁移历史日志。
#v2.7.1变更说明:修复2.7.3历史sysctl模板sed误伤注释;静默安装框架统一为三节点口径;补充13.3脚本实跑检查单。
#v2.7.2变更说明:补齐13.1/13.2脚本落盘与语法预检闭环;监控状态目录从node_exporter目录剥离;新增正式修订历史表;收口10949/10503默认禁用口径;补充PGA limit校验SQL与ASM compatible单向门提示。
#v2.7.3变更说明:按高级DBA终审意见补齐pga_aggregate_limit官方2GB绝对下限项;为bash -n语法预检增加显式OK/FAIL判定;补充早期版本追溯占位和Zabbix路径口径说明。
#v3.0变更说明:执行纯搬运式拆册/日志归档;正文保留主流程、关键命令和验收索引,将root.sh、opatchauto、crsctl等长回显迁入独立历史日志归档文件。


#本文档为可流转的部署运维手册,所有真实口令已替换为<尖括号占位符>:
#1)真实口令保存在独立保密渠道(密码管理器/保密文档),随文档分发时单独传递,不写入本文档
#2)执行命令前将占位符替换为真实值;严禁把替换后的真实口令回填进本文档或粘贴执行日志时带出
#3)历史日志中出现的口令同样已脱敏,日志仅供过程追溯

#口令类变量(敏感,正文与日志中只出现占位符)

| 占位符 | 含义 | 复杂度格式示例(非真实值) |
| ------ | ---- | ------------------------ |
| `<SYS_PWD>` | SYS/SYSTEM及dbca建库统一口令 | Abc2026#Xyz |
| `<DSA_PWD>` | dataassets PDB管理用户pdbadmin口令 | Dsa2026#Pdb |
| `<PORTAL_PWD>` | portal PDB用户portaluser/PORTAL_SERVICE_V6口令 | Ptl2026#Svc |
| `<ONECODE_PWD>` | onecode PDB用户onecodeuser口令 | Ocd2026#Usr |
| `<NFS_SERVER>` | RMAN备份独立NFS服务器地址(6.5.1.1节) | 172.18.x.x |
| `<EXPDP_REMOTE_HOST>` | expdp异地备份服务器地址(6.5.1.2节) | 192.168.100.100 |
| `<EXPDP_REMOTE_DIR>` | expdp异地备份服务器目录(6.5.1.2节) | /data |
| `<EXPDP_REMOTE_USER>` | expdp异地备份服务器SSH用户(按实际创建) | backup |
| `<MONITOR_TEXTFILE_DIR>` | node_exporter textfile collector目录(P2监控接入) | /var/lib/node_exporter/textfile_collector |
| `<MONITOR_STATUS_DIR>` | Oracle巡检/备份状态文件目录(P2监控接入,不由node_exporter直接扫描) | /var/lib/oracle_mon |
| `<PRIVATE_MTU>` | RAC私网MTU目标值(P2,端到端确认后启用) | 9000 |
| `<ISCSI_MTU>` | iSCSI存储网MTU目标值(P2,端到端确认后启用) | 9000 |
| `<DNS_DOMAIN>` | 生产DNS域名后缀(P3 SCAN/DNS标准化) | example.edu.cn |
| `<SCAN_NAME>` | 生产SCAN名称(P3,建议DNS轮询3个A记录) | rac-scan.example.edu.cn |
| `<SCAN_IP1>` | 生产SCAN第1个IP | 172.18.13.176 |
| `<SCAN_IP2>` | 生产SCAN第2个IP | 172.18.13.181 |
| `<SCAN_IP3>` | 生产SCAN第3个IP | 172.18.13.182 |
| `<LIO_TARGET_IQN>` | LIO/targetcli iSCSI target名称(P3替代tgtd时使用) | iqn.2026-01.edu.example:xydb-rac |
| `<RAC01_INITIATOR_IQN>` | RAC节点1 iSCSI initiator名称(LIO新部署建议唯一) | iqn.2026-01.edu.example:k8s-19rac01 |
| `<RAC02_INITIATOR_IQN>` | RAC节点2 iSCSI initiator名称(LIO新部署建议唯一) | iqn.2026-01.edu.example:k8s-19rac02 |
| `<RAC03_INITIATOR_IQN>` | RAC节点3 iSCSI initiator名称(LIO新部署建议唯一) | iqn.2026-01.edu.example:k8s-19rac03 |
| `<SILENT_RSP_DIR>` | 静默安装响应文件目录(P3) | /u01/install/rsp |

#说明:test1/test1、soe/soe、swingbench等为演示/压测专用账号,非生产凭据,未做替换;
#压测完成后务必按11.1.6节清理SOE等压测账号

#环境基线(非敏感;跨学校移植时按此清单整体替换正文中的字面值)

| 项目 | 本环境值 |
| ---- | -------- |
| 集群节点 | k8s-19rac01/02/03 (172.18.13.172/173/177) |
| SCAN | rac-scan 172.18.13.176 (hosts方式,单SCAN IP) |
| 数据库/实例 | xydb / xydb1,xydb2,xydb3 |
| PDB | stuwork, portal, onecode, dataassets |
| ADG备库 | k8s-19rac-adg 172.18.13.180, db_unique_name=xydbadg |
| iSCSI存储节点 | k8s-19rac-store 172.18.13.179 (iSCSI网段3.3.3.0/24) |
| GRID_HOME | /u01/app/19.0.0/grid |
| ORACLE_HOME | /u01/app/oracle/product/19.0.0/db_1 |
| ASM磁盘组 | OCR(NORMAL,3x50G) / DATA(EXTERNAL,200G) / FRA(EXTERNAL,200G) |
| RMAN备份目的地 | /backup/rmanbak (独立NFS,见6.5.1.1节) |


## 0.0.修订历史

#本表用于正式交付版本追踪。历史版本如缺少精确修订日期/作者,交付前由项目文档负责人按变更单补齐;本文不反向补造个人信息。

| 版本 | 日期 | 修订人 | 主要变更 | 审核/确认 |
| ---- | ---- | ------ | -------- | --------- |
| v2.5.1及更早 | 历史版本 | 项目文档维护人 | 早期安装主流程、ADG章节、OCR/OLR恢复、口令变量化、RMAN/expdp脚本等演进;详细以早期变更说明和项目变更单为准 | 项目DBA |
| v2.5.2 | 历史版本 | 项目文档维护人 | 补齐postcheck HugePages断言;expdp改造为按PDB分文件并异地同步 | 项目DBA |
| v2.6 | 历史版本 | 项目文档维护人 | 进入P2:OS/DB/ASM参数基线、MTU 9000、VNCR、FAN/ONS/TAC、监控接入 | 项目DBA |
| v2.6.1 | 历史版本 | 项目文档维护人 | 修复sysctl多源覆盖;收口MTU断言、SQLNET.EXPIRE_TIME、VNCR SCAN、监控状态文件 | 高级DBA复核 |
| v2.7 | 历史版本 | 项目文档维护人 | 进入P3:tgtd到LIO、SCAN/DNS、容量规划、静默安装路径 | 高级DBA复核 |
| v2.7.1 | 2026-06-13 | 项目文档维护人 | 修复2.7.3 sed误伤;静默安装统一三节点;补充13.3.4实跑检查单 | 高级DBA复核 |
| v2.7.2 | 2026-06-13 | 项目文档维护人 | 补齐precheck/postcheck落盘闭环;拆分监控状态目录;补修订历史;收口隐藏event依据;补PGA/compatible验收提示 | 高级DBA复核 |
| v2.7.3 | 2026-06-13 | 项目文档维护人 | 补pga_aggregate_limit 2GB绝对下限;bash -n增加显式判定;补Zabbix路径口径说明 | 高级DBA终审 |
| v3.0 | 2026-06-13 | 项目文档维护人 | 纯搬运拆册:正文瘦身,历史root.sh/opatchauto/crsctl/Swingbench长回显迁入独立日志归档 | 高级DBA复核待定 |



## 0.1.P0级架构风险与适用边界声明

#!!!本章是执行本文档前必须先阅读的风险边界。本文档记录的是一套基于华三/深信服等超融合虚拟化环境、单台虚拟机提供iSCSI共享存储的Oracle 19c RAC+ADG部署方案。
#它可以用于实验、培训、验证、迁移演练或受控的非核心生产场景;若用于正式生产,必须由项目DBA、系统负责人和业务负责人完成风险接受或架构加固。

| 风险点 | 当前文档环境 | 风险说明 | 生产建议/补偿措施 |
| ------ | ------------ | -------- | ---------------- |
| 共享存储单点 | k8s-19rac-store单虚拟机提供iSCSI LUN | store宕机、tgtd异常、宿主机故障会影响整个RAC共享磁盘访问 | 生产使用企业级共享存储/双控存储/多路径;至少对store配置监控、配置备份和应急重建预案 |
| iSCSI实现 | 文档保留tgtd/scsi-target-utils历史部署 | tgtd为用户态实现,稳定性与维护性弱于LIO/targetcli | 新建生产环境优先采用LIO(targetcli)或企业存储;tgtd仅作为历史/实验方案 |
| DATA/FRA冗余 | DATA/FRA为EXTERNAL冗余 | ASM层无冗余,完全依赖底层存储可靠性 | 生产明确底层存储冗余能力;关键系统考虑NORMAL/HIGH冗余或企业存储保护 |
| SCAN解析 | hosts方式,单SCAN IP | 失去3个SCAN IP的DNS轮询与高可用能力 | 生产标准为DNS轮询3个SCAN IP;hosts单SCAN只作为无DNS降级方案 |
| 备份故障域 | RMAN/OCR要求复制到<NFS_SERVER> | 只保存在RAC节点、+FRA或store不算离线备份 | 独立NFS/备份服务器必须与RAC/store不同故障域;定期做恢复验证 |
| ADG切换 | 依赖双地址连接串/应用改造 | 未改造老应用需要人工切换,会增加RTO | 关键业务必须提前验证TNS/JDBC双地址、service角色、Broker切换和回切演练 |

#执行原则:
#1)任何历史日志、历史错误处理、附录14中的命令都不得作为主流程直接照抄执行;
#2)执行前必须先跑第13章precheck_assert.sh;部署/变更后必须跑postcheck.sh;
#3)脚本首次进入cron或生产流程前,必须在实验集群实跑并把修正记录写入14.3;
#4)涉及口令、安全降级、隐藏参数/event、存储重建、ADG failover的动作必须形成变更记录。




## 0.2.P1本轮优化范围说明

#本轮只做P1运维能力补强,不做日志大搬迁、不拆册、不调整历史大段回显。
#已覆盖:
#1)HugePages/limits/memlock/SGA/PGA/processes强制规划;
#2)故障处置手册与TFA/AHF采集;
#3)日常/每周/季度巡检脚本与清单;
#4)RMAN恢复演练:单数据文件、控制文件、PITR、异机全库恢复;
#5)expdp/impdp生产化脚本、状态文件、失败检查和保留策略;
#6)季度RU补丁策略、补丁前后检查、datapatch、回退和验收。


## 0.3.P2本轮优化范围说明

#本轮进入P2生产化/安全化/平台化补强,仍不做P3拆册与历史日志搬迁。
#已覆盖:
#1)OS参数终版决策:kernel.sem、rp_filter、min_free_kbytes、limits与HugePages联动;
#2)DB参数基线:control_file_record_keep_time、db_create_file_dest、fast_start_mttr_target、open_cursors/session_cached_cursors、parallel上限、Resource Manager维护窗口策略;
#3)ASM/FRA基线:compatible.asm/rdbms、DATA au_size、asm_power_limit、FRA容量告警阈值与清理预案;
#4)MTU 9000端到端方案:OS网卡、虚拟交换机、物理交换机/存储侧一致后才启用,并写入precheck断言;
#5)监听安全:VNCR注册白名单、SQLNET.EXPIRE_TIME、主备互列白名单防止ADG注册/redo传输被拦;
#6)FAN/ONS/TAC:应用连接高可用能力说明、适用前提、服务属性样例和演练要求;
#7)监控平台化:将RMAN、expdp、每日巡检、FRA、ADG状态文件接入Zabbix或node_exporter textfile collector。

## 0.4.P3/P3收尾与v3.0拆册范围说明

#v2.7.x完成P3架构演进与批量部署能力补强;v3.0只做纯搬运式拆册/历史日志归档,不改变技术主流程和执行命令口径。
#已覆盖:
#1)tgtd到LIO(targetcli)演进:给出新部署推荐方案、存量迁移边界、配置备份和scsi_id稳定性验收;
#2)SCAN/DNS标准化:生产推荐3个SCAN IP的DNS轮询,hosts单SCAN仅作为无DNS降级方案;
#3)容量规划方法:把Swingbench/AWR/OS/备份增长量转化为CPU、内存、Redo、FRA、DATA、UNDO/TEMP、连接数和备份容量结论;
#4)静默安装路径:补充Grid、DB软件、DBCA静默安装响应文件与命令框架,用于无GUI和批量部署场景;
#5)v3.0已将部分长回显迁入独立历史日志归档文件;正文保留主流程、关键命令、验收点和归档索引。

## 0.5.交付物收尾边界与v3.0拆册说明

#v3.0的目标是对v2.7.3定稿候选执行纯搬运式拆册:不改技术内容、不新增现场结论、不删除历史证据,只把正文中影响阅读的长回显迁入独立历史日志归档文件。
#拆册后交付物至少包含:
#1)主手册:保留架构风险、主流程命令、脚本、验收标准、Runbook和归档索引;
#2)历史日志归档:保存root.sh、opatchauto、crsctl状态、Swingbench操作日志、CTSS/iSCSI历史错误等长回显;
#3)第13章脚本仍必须完成13.3.4实跑,并把结果写入14.3/14.6;拆册不等于实跑验收。

### 0.5.1.v3.0历史日志归档索引

| 归档编号 | 原章节 | 已搬迁内容 |
| -------- | ------ | ---------- |
| LOG-03-06 | 3.6 | GI root.sh执行长回显 |
| LOG-03-07 | 3.7 | GI安装后crsctl资源状态长回显 |
| LOG-05-02 | 5.2 | DB软件root.sh执行长回显 |
| LOG-05-03 | 5.3 | DB软件安装后集群状态长回显 |
| LOG-06-02 | 6.2 | 建库后集群状态长回显 |
| LOG-07-RU | 7.0.6~7.2 | 19.20/19.21 RU历史执行记录、opatchauto长日志和错误处理回显 |
| LOG-11-01-08 | 11.1.8 | Swingbench历史操作日志 |
| LOG-14-01 | 14.1 | CTSS/chrony历史错误处理记录 |
| LOG-14-02 | 14.2 | iSCSI参数调优历史对比记录 |


## 1.系统环境
### 1.0. 五台服务器

#本地深信服超融合环境，存储全部挂载给了虚拟化环境，没有多余的共享lun可以划出来，所以采用一台虚拟机搭建iscsi共享存储

```
#oracle 19c rac搭建两节点集群
k8s-19rac01: 172.18.13.172
k8s-19rac02: 172.18.13.173
k8s-19rac-store: 172.18.13.179


#配置adg
k8s-19rac-adg: 172.18.13.180

#19c rac添加第三个节点
k8s-19rac03: 172.18.13.177
```

### 1.1. 系统版本

```
[root@k8s-19rac01 ~]# cat /etc/os-release |grep PRETTY
PRETTY_NAME="Oracle Linux Server 7.9"

[root@k8s-19rac01 ~]# uname -r
5.4.17-2102.201.3.el7uek.x86_64
```
### 1.2. ASM 磁盘组规划

```
ASM 磁盘组 用途 大小 冗余
ocr、voting file   50G+50G+50G NORMAL        ocr01/ocr02/ocr03
DATA 数据文件       200G EXTERNAL             data01
FRA  归档日志       200G EXTERNAL             fra01
```




### 1.3. 主机网络规划

#分区---320G

```
/boot   1G
swap    32G
/       其余容量  
```

#IP规划

#三个网段：

```conf
#public
172.18.13.x
#private
10.100.100.x
#iscsi
3.3.3.x
```



```
网络配置               节点 1                               节点 2              iscsi虚拟机
主机名称               k8s-19rac01                        k8s-19rac02         k8s-oracle-store
public ip            172.18.13.172                      172.18.13.173        172.18.13.179
private ip           10.100.100.97                      10.100.100.98
vip                  172.18.13.174                      172.18.13.175
scan ip              172.18.13.176

iscsi ip             3.3.3.172                          3.3.3.173            3.3.3.179


网络配置               adg                              
主机名称               k8s-19rac-adg                        
public ip            172.18.13.180                                        


网络配置               节点 3                              
主机名称               k8s-19rac01                        
public ip            172.18.13.177                       
private ip           10.100.100.177                      
vip                  172.18.13.178    

iscsi ip             3.3.3.177
```
```bash
[root@k8s-19rac01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

#public ip 
172.18.13.172 k8s-19rac01
172.18.13.173 k8s-19rac02
#vip
172.18.13.174 k8s-19rac01-vip
172.18.13.175 k8s-19rac02-vip
#private ip
10.100.100.172 k8s-19rac01-prv
10.100.100.173 k8s-19rac02-prv
#scan ip
172.18.13.176 rac-scan
#scsi ip
3.3.3.172 k8s-19rac01-iscsi
3.3.3.173 k8s-19rac02-iscsi

#rac03
172.18.13.177 k8s-19rac03
172.18.13.178 k8s-19rac03-vip
10.100.100.177 k8s-19rac03-prv

3.3.3.177 k8s-19rac03-iscsi

#rac-store
172.18.13.179 k8s-19rac-store
3.3.3.179 k8s-19rac-store-iscsi

#rac-adg
172.18.13.180 k8s-19rac-adg
```



###最后实际参数

```
[root@k8s-19rac01 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdf           8:80   0  100G  0 disk 
sdd           8:48   0  100G  0 disk 
sdb           8:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
sdg           8:96   0  200G  0 disk 
sde           8:64   0  100G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot

[root@k8s-19rac02 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdf           8:80   0  100G  0 disk 
sdd           8:48   0  100G  0 disk 
sdb           8:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
sdg           8:96   0  200G  0 disk 
sde           8:64   0  100G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot


#部分学校因为使用的是深信服CAS虚拟化平台，无法支持scsi分区磁盘，故无法使用udev，只能采用oracleasm管理磁盘
[root@rac01 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

[root@rac02 ~]# ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh /dev/vdi /dev/vdj 

----------------------
#本次共享存储正常：
[root@k8s-19rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007



[root@k8s-19rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007

---------------------------------
[root@k8s-19rac01 network-scripts]# cat ifcfg-eth0
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth0
UUID=5cb29430-beb7-48b8-ba7a-2e49415d02eb
DEVICE=eth0
ONBOOT=yes
IPADDR=172.18.13.172
PREFIX=16
GATEWAY=172.18.209.40
DNS1=223.5.5.5
DNS2=223.6.6.6

[root@k8s-19rac01 network-scripts]# cat ifcfg-eth1
TYPE=Ethernet
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
NAME=eth1
HWADDR=FE:FC:FE:DB:83:4D
PEERDNS=no
IPADDR=10.100.100.97
NETMASK=255.255.255.0
GATEWAY=10.100.100.1
METRIC=105

[root@k8s-19rac01 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.18.209.40   0.0.0.0         UG    100    0        0 eth0
0.0.0.0         10.100.100.1    0.0.0.0         UG    101    0        0 eth1
10.100.100.0    0.0.0.0         255.255.255.0   U     101    0        0 eth1
172.18.0.0      0.0.0.0         255.255.0.0     U     100    0        0 eth0

[root@k8s-19rac01 ~]# ip route list
default via 172.18.209.40 dev eth0 proto static metric 100 
default via 10.100.100.1 dev eth1 proto static metric 101 
10.100.100.0/24 dev eth1 proto kernel scope link src 10.100.100.97 metric 101 
172.18.0.0/16 dev eth0 proto kernel scope link src 172.18.13.172 metric 100 

[root@k8s-19rac01 network-scripts]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  a51bd73a-44bc-44be-adf0-aa26c1506eb6  ethernet  eth0   
eth1  897abf73-23a4-4585-af73-b32a3c228f03  ethernet  eth1   



[root@k8s-19rac02 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth0
#UUID=5cb29430-beb7-48b8-ba7a-2e49415d02eb
UUID=01c42c1f-4e75-40d5-b250-10810b428bca
DEVICE=eth0
ONBOOT=yes
IPADDR=172.18.13.173
PREFIX=16
GATEWAY=172.18.209.40
DNS1=223.5.5.5
DNS2=223.6.6.6

[root@k8s-19rac02 ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth1
TYPE=Ethernet
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
NAME=eth1
UUID=9d03cbb7-affc-4f0e-9605-511a35f60d83
HWADDR=FE:FC:FE:43:24:AF
PEERDNS=no
IPADDR=10.100.100.98
NETMASK=255.255.255.0
GATEWAY=10.100.100.1
METRIC=103
[root@k8s-19rac02 ~]# ip route list
default via 172.18.209.40 dev eth0 proto static metric 100 
default via 10.100.100.1 dev eth1 proto static metric 101 
10.100.100.0/24 dev eth1 proto kernel scope link src 10.100.100.98 metric 101 
172.18.0.0/16 dev eth0 proto kernel scope link src 172.18.13.173 metric 100 
[root@k8s-19rac02 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  01c42c1f-4e75-40d5-b250-10810b428bca  ethernet  eth0   
eth1  9d03cbb7-affc-4f0e-9605-511a35f60d83  ethernet  eth1   
```
#网卡配置及多路径配置
```bash
ifconfig
nmcli conn show

#默认是NetworkManager管理网络
[root@k8s-19rac01 ~]# systemctl status network
● network.service - LSB: Bring up/down networking
   Loaded: loaded (/etc/rc.d/init.d/network; bad; vendor preset: disabled)
   Active: active (exited) since Fri 2023-11-17 18:21:11 CST; 3min 11s ago
     Docs: man:systemd-sysv-generator(8)
  Process: 30913 ExecStop=/etc/rc.d/init.d/network stop (code=exited, status=0/SUCCESS)
  Process: 31455 ExecStart=/etc/rc.d/init.d/network start (code=exited, status=0/SUCCESS)

Nov 17 18:21:10 k8s-19rac01 systemd[1]: Starting LSB: Bring up/down networking...
Nov 17 18:21:10 k8s-19rac01 network[31455]: Bringing up loopback interface:  [  OK  ]
Nov 17 18:21:10 k8s-19rac01 network[31455]: Bringing up interface eth0:  Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/7)
Nov 17 18:21:10 k8s-19rac01 network[31455]: [  OK  ]
Nov 17 18:21:11 k8s-19rac01 network[31455]: Bringing up interface eth1:  Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/8)
Nov 17 18:21:11 k8s-19rac01 network[31455]: [  OK  ]
Nov 17 18:21:11 k8s-19rac01 systemd[1]: Started LSB: Bring up/down networking.
[root@k8s-19rac01 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2023-11-17 11:30:08 CST; 6h ago
     Docs: man:NetworkManager(8)
 Main PID: 7190 (NetworkManager)
   CGroup: /system.slice/NetworkManager.service
           └─7190 /usr/sbin/NetworkManager --no-daemon

Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0810] agent-manager: req[0x562c38d1e330, :1.117/nmcli-connect/0]: agent registered
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0853] device (eth1): Activation: starting connection 'eth1' (897abf73-23a4-4585-af73-b32a3c228f03)
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0857] audit: op="connection-activate" uuid="897abf73-23a4-4585-af73-b32a3c228f03" name="eth1" pid=31655 uid=0 result="success"
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0858] device (eth1): state change: disconnected -> prepare (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0866] device (eth1): state change: prepare -> config (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0884] device (eth1): state change: config -> ip-config (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0904] device (eth1): state change: ip-config -> ip-check (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0926] device (eth1): state change: ip-check -> secondaries (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.0930] device (eth1): state change: secondaries -> activated (reason 'none', sys-iface-state: 'managed')
Nov 17 18:21:11 k8s-19rac01 NetworkManager[7190]: <info>  [1700216471.1051] device (eth1): Activation: successful, device activated.
[root@k8s-19rac01 ~]# nmcli dev
DEVICE  TYPE      STATE      CONNECTION 
eth0    ethernet  connected  eth0       
eth1    ethernet  connected  eth1       
lo      loopback  unmanaged  --         
[root@k8s-19rac01 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  a51bd73a-44bc-44be-adf0-aa26c1506eb6  ethernet  eth0   
eth1  897abf73-23a4-4585-af73-b32a3c228f03  ethernet  eth1  

--------------------------------------------------------------------
[root@k8s-19rac02 ~]# systemctl status network
● network.service - LSB: Bring up/down networking
   Loaded: loaded (/etc/rc.d/init.d/network; bad; vendor preset: disabled)
   Active: active (exited) since Fri 2023-11-17 18:22:21 CST; 2min 1s ago
     Docs: man:systemd-sysv-generator(8)
  Process: 30257 ExecStop=/etc/rc.d/init.d/network stop (code=exited, status=0/SUCCESS)
  Process: 30542 ExecStart=/etc/rc.d/init.d/network start (code=exited, status=0/SUCCESS)

Nov 17 18:22:20 k8s-19rac02 systemd[1]: Starting LSB: Bring up/down networking...
Nov 17 18:22:21 k8s-19rac02 network[30542]: Bringing up loopback interface:  [  OK  ]
Nov 17 18:22:21 k8s-19rac02 network[30542]: Bringing up interface eth0:  Connection successfully a...n/7)
Nov 17 18:22:21 k8s-19rac02 network[30542]: [  OK  ]
Nov 17 18:22:21 k8s-19rac02 network[30542]: Bringing up interface eth1:  Connection successfully a...n/8)
Nov 17 18:22:21 k8s-19rac02 network[30542]: [  OK  ]
Nov 17 18:22:21 k8s-19rac02 systemd[1]: Started LSB: Bring up/down networking.
Hint: Some lines were ellipsized, use -l to show in full.
[root@k8s-19rac02 ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2023-11-17 11:33:48 CST; 6h ago
     Docs: man:NetworkManager(8)
 Main PID: 893 (NetworkManager)
   CGroup: /system.slice/NetworkManager.service
           └─893 /usr/sbin/NetworkManager --no-daemon

Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2144] agent-manager: req[0x558...red
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2160] device (eth1): Activatio...83)
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2161] audit: op="connection-ac...ss"
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2162] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2167] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2172] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2183] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2197] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2199] device (eth1): state cha...d')
Nov 17 18:22:21 k8s-19rac02 NetworkManager[893]: <info>  [1700216541.2227] device (eth1): Activatio...ed.
Hint: Some lines were ellipsized, use -l to show in full.
[root@k8s-19rac02 ~]# nmcli dev
DEVICE  TYPE      STATE      CONNECTION 
eth0    ethernet  connected  eth0       
eth1    ethernet  connected  eth1       
lo      loopback  unmanaged  --         
[root@k8s-19rac02 ~]# nmcli con show
NAME  UUID                                  TYPE      DEVICE 
eth0  01c42c1f-4e75-40d5-b250-10810b428bca  ethernet  eth0   
eth1  9d03cbb7-affc-4f0e-9605-511a35f60d83  ethernet  eth1   
```

#网卡绑定---无

```
假如网卡绑定，本次没有网卡绑定：
#eno8为私有网卡
#ens3f0和ens3f1d1绑定为team0为业务网卡
```
#节点一rac01
```bash
nmcli con mod eno8 ipv4.addresses 10.100.100.97/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '172.18.13.172/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```
#节点二rac02
```bash
nmcli con mod eno8 ipv4.addresses 10.100.100.98/24 ipv4.method manual connection.autoconnect yes

#第一种方式activebackup
nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "activebackup"}}'

#第二种方式roundrobin
#nmcli con add type team con-name team0 ifname team0 config '{"runner":{"name": "roundrobin"}}'
 
nmcli con modify team0 ipv4.address '172.18.13.172/24' ipv4.gateway '192.168.203.254'
 
nmcli con modify team0 ipv4.method manual
 
ifup team0

nmcli con add type team-slave con-name team0-ens3f0 ifname ens3f0 master team0

nmcli con add type team-slave con-name team0-ens3f1d1 ifname ens3f1d1 master team0

teamdctl team0 state
```


### 1.4. 操作系统配置部分

#关闭防火墙

```bash
systemctl stop firewalld
systemctl disable firewalld

systemctl status firewalld
```
#关闭 selinux

```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0
```
### 1.5.多路径配置情况---无
```  
[root@rac02 ~]# cat /etc/multipath/
bindings  wwids     
[root@rac02 ~]# cat /etc/multipath/bindings 
# Multipath bindings, Version : 1.0
# NOTE: this file is automatically maintained by the multipath program.
# You should not need to edit this file in normal circumstances.
#
# Format:
# alias wwid
#
mpatha 24c740a67e89393fa6c9ce90079a4df08
mpathb 2bf57071b2488dae06c9ce90079a4df08
mpathc 2ee6c414e797cb16f6c9ce90079a4df08
mpathd 2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe 2086fa4c938d839c66c9ce90079a4df08
mpathf 27b44daa76accbc526c9ce90079a4df08
mpathg 2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac02 ~]# cat /etc/multipath/wwids 
# Multipath wwids, Version : 1.0
# NOTE: This file is automatically maintained by multipath and multipathd.
# You should not need to edit this file in normal circumstances.
#
# Valid WWIDs:
mpatha 24c740a67e89393fa6c9ce90079a4df08
mpathb 2bf57071b2488dae06c9ce90079a4df08
mpathc 2ee6c414e797cb16f6c9ce90079a4df08
mpathd 2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe 2086fa4c938d839c66c9ce90079a4df08
mpathf 27b44daa76accbc526c9ce90079a4df08
mpathg 2aa67dbb0c9c0573b6c9ce90079a4df08

[root@rac02 ~]# sfdisk -s|grep mpath
/dev/mapper/mpatha: 104857600
/dev/mapper/mpathb: 104857600
/dev/mapper/mpathc: 104857600
/dev/mapper/mpathd: 2147483648
/dev/mapper/mpathe: 2147483648
/dev/mapper/mpathf: 2147483648
/dev/mapper/mpathg: 2147483648

[root@rac01 ~]# multipathd show maps
name   sysfs uuid
mpatha dm-2  24c740a67e89393fa6c9ce90079a4df08
mpathb dm-3  2bf57071b2488dae06c9ce90079a4df08
mpathc dm-4  2ee6c414e797cb16f6c9ce90079a4df08
mpathd dm-5  2d96d1c2c86f4f6d26c9ce90079a4df08
mpathe dm-6  2086fa4c938d839c66c9ce90079a4df08
mpathf dm-7  27b44daa76accbc526c9ce90079a4df08
mpathg dm-8  2aa67dbb0c9c0573b6c9ce90079a4df08

#其他学校mysql情况
[root@DTMysql1 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 3600508b1001c2f58146de5792c5af902
/dev/sdb 360002ac0000000000000000300021f88
/dev/sdc 360002ac0000000000000000300021f88
/dev/sdd 360002ac0000000000000000300021f88
/dev/sde 360002ac0000000000000000300021f88
[root@DTMysql1 ~]# lsblk
NAME               MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sda                  8:0    0  1.6T  0 disk  
├─sda1               8:1    0  600M  0 part  /boot/efi
├─sda2               8:2    0    1G  0 part  /boot
└─sda3               8:3    0  1.6T  0 part  
  ├─openeuler-root 253:0    0  1.6T  0 lvm   /
  └─openeuler-swap 253:1    0   16G  0 lvm   [SWAP]
sdb                  8:16   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
sdc                  8:32   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
sdd                  8:48   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
sde                  8:64   0  800G  0 disk  
└─mpatha           253:2    0  800G  0 mpath 
  └─mpatha1        253:3    0  800G  0 part  /var/lib/mysql
  
[root@DTMysql1 ~]# cat /etc/multipath.conf 
# device-mapper-multipath configuration file

# For a complete list of the default configuration values, run either:
# # multipath -t
# or
# # multipathd show config

# For a list of configuration options with descriptions, see the
# multipath.conf man page.

defaults {
	user_friendly_names yes
	find_multipaths yes
}

blacklist_exceptions {
        property "(SCSI_IDENT_|ID_WWN)"
}

blacklist {
}


[root@DTMysql1 ~]# cat /etc/multipath
multipath/      multipath.conf  
[root@DTMysql1 ~]# cat /etc/multipath.conf 
# device-mapper-multipath configuration file

# For a complete list of the default configuration values, run either:
# # multipath -t
# or
# # multipathd show config

# For a list of configuration options with descriptions, see the
# multipath.conf man page.

defaults {
	user_friendly_names yes
	find_multipaths yes
}

blacklist_exceptions {
        property "(SCSI_IDENT_|ID_WWN)"
}

blacklist {
}
[root@DTMysql1 ~]# cat /etc/multipath
multipath/      multipath.conf  
[root@DTMysql1 ~]# cat /etc/multipath/
bindings  wwids     
[root@DTMysql1 ~]# cat /etc/multipath/bindings 
# Multipath bindings, Version : 1.0
# NOTE: this file is automatically maintained by the multipath program.
# You should not need to edit this file in normal circumstances.
#
# Format:
# alias wwid
#
mpatha 360002ac0000000000000000300021f88
[root@DTMysql1 ~]# cat /etc/multipath/wwids 
# Multipath wwids, Version : 1.0
# NOTE: This file is automatically maintained by multipath and multipathd.
# You should not need to edit this file in normal circumstances.
#
# Valid WWIDs:
/360002ac0000000000000000300021f88/
[root@DTMysql1 ~]# multipathd show maps
name   sysfs uuid                             
mpatha dm-2  360002ac0000000000000000300021f88

```

### 1.6.第三台虚拟机(k8s-oracle-store)搭建iscsi共享存储
#### 1.6.1.添加共享磁盘

#添加硬盘，创建方式：新磁盘，分配方式：预分配(类似于vsphere的厚置备，置零)

![image-20231117111420348](oracle-store\image-20231117111420348.png)

![image-20231117112712657](oracle-store\image-20231117112712657.png)





#### 1.6.2.配置iscsi

#关闭防火墙

```bash
systemctl stop firewalld
systemctl disable firewalld

systemctl status firewalld
```
#关闭 selinux
```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

setenforce 0
```

#安装iscsi管理工具

```bash
yum install -y targetcli
```

#启动iscsi服务

```bash
systemctl start target.service
systemctl enable target.service

systemctl status target.service
```

#查看磁盘信息

```bash
[root@k8s-19rac-store ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vdf         251:80   0  200G  0 disk 
vdd         251:48   0   50G  0 disk 
vdb         251:16   0   50G  0 disk 
sr0          11:0    1  4.5G  0 rom  
vde         251:64   0  200G  0 disk 
vdc         251:32   0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   87G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
```

#安装 scsi-target-utils

```bash
#yum install -y epel-release
#wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
#    rpm -ivh epel-release-latest-7.noarch.rpm

#归档地址
#https://archives.fedoraproject.org/pub/archive/epel/
#https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm

wget https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm
rpm -ivh epel-release-7-14.noarch.rpm

yum  -y install scsi-target-utils libxslt
#yum --enablerepo=epel -y install scsi-target-utils libxslt
```

#配置 targets.conf ，在文件末尾添加如下内容

```bash
cat >> /etc/tgt/targets.conf << EOF
<target iqn.2023-11.com.oracle:rac>
    backing-store /dev/vdb
    backing-store /dev/vdc
    backing-store /dev/vdd
    backing-store /dev/vde
    backing-store /dev/vdf
    initiator-address 3.3.3.0/24
    write-cache off
</target>
EOF
```

#注意

```
#iqn 名字可任意

#initiator-address 限定允许访问的客户端地址段或具体IP

#write-cache off 是否开启或关闭快取

[root@k8s-19rac-store ~]# ip a|grep 3.3.3
    inet 3.3.3.179/24 scope global eth1
```

```bash
# cat /etc/tgt/targets.conf |grep -v ^#|grep -v ^$
default-driver iscsi
<target iqn.2023-11.com.oracle:rac>
    backing-store /dev/vdb
    backing-store /dev/vdc
    backing-store /dev/vdd
    backing-store /dev/vde
    backing-store /dev/vdf
    initiator-address 3.3.3.0/24
    write-cache off
</target>
```

#启动 tgtd

```bash
systemctl restart tgtd.service

systemctl restart target.service

systemctl enable tgtd

tgt-admin -dump

tgtadm --lld iscsi --mode target --op show

netstat -anp|grep tgt
```

#日志

```bash
[root@k8s-19rac-store ~]# tgt-admin -dump
default-driver iscsi

<target iqn.2023-11.com.oracle:rac>
	backing-store /dev/vdb
	backing-store /dev/vdc
	backing-store /dev/vdd
	backing-store /dev/vde
	backing-store /dev/vdf
	initiator-address 3.3.3.0/24
</target>

[root@k8s-19rac-store ~]# tgtadm --lld iscsi --mode target --op show
Target 1: iqn.2023-11.com.oracle:rac
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags: 
        LUN: 1
            Type: disk
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdb
            Backing store flags: 
        LUN: 2
            Type: disk
            SCSI ID: IET     00010002
            SCSI SN: beaf12
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdc
            Backing store flags: 
        LUN: 3
            Type: disk
            SCSI ID: IET     00010003
            SCSI SN: beaf13
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdd
            Backing store flags: 
        LUN: 4
            Type: disk
            SCSI ID: IET     00010004
            SCSI SN: beaf14
            Size: 214748 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vde
            Backing store flags: 
        LUN: 5
            Type: disk
            SCSI ID: IET     00010005
            SCSI SN: beaf15
            Size: 214748 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdf
            Backing store flags: 
    Account information:
    ACL information:
        3.3.3.0/24
[root@k8s-19rac-store ~]# netstat -anp|grep tgt
tcp        0      0 0.0.0.0:3260            0.0.0.0:*               LISTEN      19186/tgtd
tcp        0      0 :::3260                 :::*                    LISTEN      19186/tgtd
unix  2      [ ACC ]     STREAM     LISTENING     11774654 19186/tgtd          /var/run/tgtd.ipc_abstract_namespace.0
unix  3      [ ]         STREAM     CONNECTED     11774652 19186/tgtd          
[root@k8s-19rac-store ~]# 

     
#oracle rac 连接后

[root@k8s-oracle-store ~]# tgtadm -L iscsi -o show -m target
Target 1: iqn.2023-11.com.oracle:rac
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
        I_T nexus: 2
            Initiator: iqn.2023-11.com.oracle:rac alias: k8s-19rac01
            Connection: 0
                IP Address: 172.18.13.172
        I_T nexus: 15
            Initiator: iqn.2023-11.com.oracle:rac alias: k8s-19rac02
            Connection: 0
                IP Address: 172.18.13.173
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags: 
        LUN: 1
            Type: disk
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdb
            Backing store flags: 
        LUN: 2
            Type: disk
            SCSI ID: IET     00010002
            SCSI SN: beaf12
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdc
            Backing store flags: 
        LUN: 3
            Type: disk
            SCSI ID: IET     00010003
            SCSI SN: beaf13
            Size: 53687 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdd
            Backing store flags: 
        LUN: 4
            Type: disk
            SCSI ID: IET     00010004
            SCSI SN: beaf14
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vde
            Backing store flags: 
        LUN: 5
            Type: disk
            SCSI ID: IET     00010005
            SCSI SN: beaf15
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdf
            Backing store flags: 
        LUN: 6
            Type: disk
            SCSI ID: IET     00010006
            SCSI SN: beaf16
            Size: 107374 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdg
            Backing store flags: 
        LUN: 7
            Type: disk
            SCSI ID: IET     00010007
            SCSI SN: beaf17
            Size: 214748 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/vdh
            Backing store flags: 
    Account information:
    ACL information:
        172.18.13.0/24
        
[root@k8s-oracle-store ~]# netstat -anp|grep tgt
netstat: showing only processes with your user ID
tcp        0      0 0.0.0.0:3260            0.0.0.0:*               LISTEN      25468/tgtd
tcp        0      0 3.3.3.179:3260      172.18.13.173:64708      ESTABLISHED 25468/tgtd
tcp        0      0 3.3.3.179:3260      172.18.13.172:33274      ESTABLISHED 25468/tgtd
tcp        0      0 :::3260                 :::*                    LISTEN      25468/tgtd
      
```

```bash
#内存不足时
sync
echo 1 > /proc/sys/vm/drop_caches
```

### 1.6.3.P3:使用LIO(targetcli)替代tgtd的推荐方案

#定位:本节是P3架构演进方案,不是对前文tgtd实录的直接覆盖。
#新建环境优先选择企业级共享存储;若仍需在Linux虚拟机上提供iSCSI LUN,优先使用内核态LIO/targetcli,不要继续把tgtd作为生产默认方案。
#存量环境从tgtd迁移到LIO属于存储侧变更,必须停库/停CRS/停RAC节点后执行,禁止在线切换target实现。

| 方案 | 适用场景 | 优点 | 风险/限制 |
| ---- | -------- | ---- | --------- |
| 企业级共享存储+多路径 | 正式生产 | 双控/多路径/缓存/快照/监控成熟 | 需要存储资源与规范实施 |
| LIO(targetcli) | 实验、准生产、无企业存储但希望替代tgtd | 内核态target,OL7原生支持,配置文件集中在`/etc/target/saveconfig.json` | 仍是单store节点,不解决存储单点 |
| tgtd/scsi-target-utils | 历史实录/兼容老环境 | 文档已有完整历史记录 | 用户态实现,维护性差,仅保留追溯价值 |

#### 1.6.3.1.LIO新部署原则

#1)RAC各节点initiator IQN建议唯一,便于ACL、审计和后续定位;存量环境如果已使用相同IQN,不要直接改,需在实验环境验证/by-path与udev影响。
#2)LUN顺序、LUN名称、scsi_id/ID_SERIAL必须在RAC所有节点完全一致,这是ASM设备映射的核心。
#3)完成LIO配置后,先在所有RAC节点只登录iSCSI并检查scsi_id,确认udev规则后,再进入GI/ASM安装或启动CRS。
#4)必须把`/etc/target/saveconfig.json`、`targetcli ls`输出、RAC侧udev规则和scsi_id对照表纳入6.5.2.2a的store配置备份。

#### 1.6.3.2.LIO配置模板(store节点root执行)

```bash
#安装并启动LIO管理工具
 yum install -y targetcli
 systemctl enable target --now
 systemctl status target

#建议先确认磁盘顺序;以下/dev/vdb~vdf仅为本环境示例
lsblk
for d in /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf; do
  echo "$d $(/usr/lib/udev/scsi_id -g -u -d $d 2>/dev/null || true)"
done

#进入targetcli交互模式配置
 targetcli
```

```text
#以下在targetcli交互界面执行;IQN和磁盘按变量表替换
/backstores/block create ocr01 /dev/vdb
/backstores/block create ocr02 /dev/vdc
/backstores/block create ocr03 /dev/vdd
/backstores/block create data01 /dev/vde
/backstores/block create fra01 /dev/vdf

/iscsi create <LIO_TARGET_IQN>
/iscsi/<LIO_TARGET_IQN>/tpg1/portals delete 0.0.0.0 3260
/iscsi/<LIO_TARGET_IQN>/tpg1/portals create 3.3.3.179 3260

#新部署建议每个RAC节点使用唯一initiator IQN
/iscsi/<LIO_TARGET_IQN>/tpg1/acls create <RAC01_INITIATOR_IQN>
/iscsi/<LIO_TARGET_IQN>/tpg1/acls create <RAC02_INITIATOR_IQN>
/iscsi/<LIO_TARGET_IQN>/tpg1/acls create <RAC03_INITIATOR_IQN>

/iscsi/<LIO_TARGET_IQN>/tpg1/luns create /backstores/block/ocr01
/iscsi/<LIO_TARGET_IQN>/tpg1/luns create /backstores/block/ocr02
/iscsi/<LIO_TARGET_IQN>/tpg1/luns create /backstores/block/ocr03
/iscsi/<LIO_TARGET_IQN>/tpg1/luns create /backstores/block/data01
/iscsi/<LIO_TARGET_IQN>/tpg1/luns create /backstores/block/fra01

ls
saveconfig
exit
```

```bash
#配置完成后验收
systemctl status target
targetcli ls
ss -lntp | grep 3260
cp -a /etc/target/saveconfig.json /root/saveconfig.json.$(date +%F_%H%M%S).bak
```

#### 1.6.3.3.LIO登录与ASM设备验收(RAC各节点root执行)

```bash
#新部署时,每个节点的InitiatorName建议使用唯一值
#节点1示例;节点2/3分别替换为<RAC02_INITIATOR_IQN>/<RAC03_INITIATOR_IQN>
cp /etc/iscsi/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi.bak.$(date +%F_%H%M%S)
echo 'InitiatorName=<RAC01_INITIATOR_IQN>' > /etc/iscsi/initiatorname.iscsi
systemctl restart iscsid

iscsiadm -m discovery -t sendtargets -p 3.3.3.179:3260
iscsiadm -m node -T <LIO_TARGET_IQN> -p 3.3.3.179:3260 -l
iscsiadm -m session -P 3
lsblk
ls -l /dev/disk/by-path/ | grep iscsi
for d in /dev/sd?; do echo "$d $(/usr/lib/udev/scsi_id -g -u -d $d 2>/dev/null || true)"; done
```

#验收标准:
#1)所有RAC节点能看到相同数量的LUN;
#2)同一LUN在不同节点的scsi_id/ID_SERIAL完全一致;
#3)udev规则仍生成`/dev/oracleasm/disks/OCR01/OCR02/OCR03/DATA01/FRA01`等稳定路径;
#4)GI/ASM磁盘发现路径只使用`/dev/oracleasm/disks/*`,禁止直接引用`/dev/sdX`;
#5)把`targetcli ls`、`/etc/target/saveconfig.json`、RAC侧`scsi_id`和udev规则同步到`<NFS_SERVER>`。

#### 1.6.3.4.tgtd存量迁移到LIO的边界

#!!!存量迁移不是简单把服务从tgtd重启成target。
#必须按以下原则执行:
#1)完整备份:RMAN、OCR/Voting/OLR、store配置、udev规则、scsi_id映射表;
#2)计划停机:按1.8.1停止应用、service、数据库、CRS、RAC节点OS,最后停store侧tgtd;
#3)配置LIO后只启动store和RAC OS,先不启动CRS,先验证LUN数量、scsi_id、udev链接;
#4)若scsi_id发生变化,必须先更新udev规则并重新触发udev,确认ASM设备名不变后再启动CRS;
#5)启动后执行13.2 postcheck、ASM磁盘组检查、OCR检查、ADG同步检查和备份脚本手工运行。


### 1.7. 配置 iscsi 客户端（所有rac节点）

#### 1.7.1.配置共享磁盘

#安装 iscsi-initiator-utils,安裝 iSCSI Client 软件

```bash
yum install -y iscsi-initiator-utils libiscsi
```

#配置 initiatorname.iscsi

```bash
vi /etc/iscsi/initiatorname.iscsi
#将上面的内容复制到这里
InitiatorName=iqn.2023-11.com.oracle:rac
```

#重启iscsi

```bash
systemctl restart iscsi.service
systemctl enable iscsi.service
```

#通过3260端口查看开放了哪些共享存储

```bash
iscsiadm -m discovery -tsendtargets -p 3.3.3.179:3260
```

#日志

```bash
# iscsiadm -m discovery -tsendtargets -p 3.3.3.179:3260
3.3.3.179:3260,1 iqn.2023-11.com.oracle:rac
```

#登录共享存储

```bash
iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 3.3.3.179:3260 -l
```

#日志

```bash
# iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 3.3.3.179:3260 -l
Logging in to [iface: default, target: iqn.2023-11.com.oracle:rac, portal: 3.3.3.179,3260] (multiple)
Login to [iface: default, target: iqn.2023-11.com.oracle:rac, portal: 3.3.3.179,3260] successful.

```

#探测下共享存储的目录

```bash
partprobe

lsblk

iscsiadm -m session -R

lsscsi

ll  /dev/disk/by-path
#可以看到三台rac节点的共享目录顺序不一致

yum install -y tree
tree /var/lib/iscsi/
cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#

```

#日志

```bash
[root@k8s-19rac01 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdd           8:48   0  200G  0 disk 
sdb           8:16   0   50G  0 disk 
vdb         251:16   0  200G  0 disk 
└─ol-root   252:0    0  287G  0 lvm  /
sr0          11:0    1  4.5G  0 rom  
sde           8:64   0  200G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0  287G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
[root@k8s-19rac01 ~]# partprobe
Warning: Unable to open /dev/sr0 read-write (Read-only file system).  /dev/sr0 has been opened read-only.
[root@k8s-19rac01 ~]# 
[root@k8s-19rac01 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdd           8:48   0  200G  0 disk 
sdb           8:16   0   50G  0 disk 
vdb         251:16   0  200G  0 disk 
└─ol-root   252:0    0  287G  0 lvm  /
sr0          11:0    1  4.5G  0 rom  
sde           8:64   0  200G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0  287G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
[root@k8s-19rac01 ~]# iscsiadm -m session -R
Rescanning session [sid: 1, target: iqn.2023-11.com.oracle:rac, portal: 3.3.3.179,3260]
[root@k8s-19rac01 ~]# lsscsi
[1:0:0:0]    cd/dvd  SANGFOR  DVD-ROM          2.5+  /dev/sr0 
[2:0:0:0]    storage IET      Controller       0001  -        
[2:0:0:1]    disk    IET      VIRTUAL-DISK     0001  /dev/sda 
[2:0:0:2]    disk    IET      VIRTUAL-DISK     0001  /dev/sdb 
[2:0:0:3]    disk    IET      VIRTUAL-DISK     0001  /dev/sdc 
[2:0:0:4]    disk    IET      VIRTUAL-DISK     0001  /dev/sdd 
[2:0:0:5]    disk    IET      VIRTUAL-DISK     0001  /dev/sde 
[root@k8s-19rac01 ~]# ll  /dev/disk/by-path
total 0
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-1 -> ../../sda
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-2 -> ../../sdb
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-3 -> ../../sdc
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-4 -> ../../sdd
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-5 -> ../../sde
lrwxrwxrwx 1 root root  9 Mar 26 17:15 pci-0000:00:01.1-ata-2.0 -> ../../sr0
lrwxrwxrwx 1 root root  9 Mar 27 17:48 pci-0000:00:0a.0 -> ../../vda
lrwxrwxrwx 1 root root 10 Mar 27 17:48 pci-0000:00:0a.0-part1 -> ../../vda1
lrwxrwxrwx 1 root root 10 Mar 27 17:48 pci-0000:00:0a.0-part2 -> ../../vda2
lrwxrwxrwx 1 root root  9 Mar 27 17:48 pci-0000:00:0b.0 -> ../../vdb
lrwxrwxrwx 1 root root  9 Mar 27 17:48 virtio-pci-0000:00:0a.0 -> ../../vda
lrwxrwxrwx 1 root root 10 Mar 27 17:48 virtio-pci-0000:00:0a.0-part1 -> ../../vda1
lrwxrwxrwx 1 root root 10 Mar 27 17:48 virtio-pci-0000:00:0a.0-part2 -> ../../vda2
lrwxrwxrwx 1 root root  9 Mar 27 17:48 virtio-pci-0000:00:0b.0 -> ../../vdb
[root@k8s-19rac01 ~]#

[root@k8s-19rac02 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdd           8:48   0  200G  0 disk 
sdb           8:16   0   50G  0 disk 
vdb         251:16   0  200G  0 disk 
└─ol-root   252:0    0  287G  0 lvm  /
sr0          11:0    1  4.5G  0 rom  
sde           8:64   0  200G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0  287G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
[root@k8s-19rac02 ~]# partprobe
Warning: Unable to open /dev/sr0 read-write (Read-only file system).  /dev/sr0 has been opened read-only.
[root@k8s-19rac02 ~]# 
[root@k8s-19rac02 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdd           8:48   0  200G  0 disk 
sdb           8:16   0   50G  0 disk 
vdb         251:16   0  200G  0 disk 
└─ol-root   252:0    0  287G  0 lvm  /
sr0          11:0    1  4.5G  0 rom  
sde           8:64   0  200G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0  287G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
[root@k8s-19rac02 ~]# iscsiadm -m session -R
Rescanning session [sid: 1, target: iqn.2023-11.com.oracle:rac, portal: 3.3.3.179,3260]
[root@k8s-19rac02 ~]# lsscsi
[1:0:0:0]    cd/dvd  SANGFOR  DVD-ROM          2.5+  /dev/sr0 
[2:0:0:0]    storage IET      Controller       0001  -        
[2:0:0:1]    disk    IET      VIRTUAL-DISK     0001  /dev/sda 
[2:0:0:2]    disk    IET      VIRTUAL-DISK     0001  /dev/sdb 
[2:0:0:3]    disk    IET      VIRTUAL-DISK     0001  /dev/sdc 
[2:0:0:4]    disk    IET      VIRTUAL-DISK     0001  /dev/sdd 
[2:0:0:5]    disk    IET      VIRTUAL-DISK     0001  /dev/sde 
[root@k8s-19rac02 ~]# ll  /dev/disk/by-path
total 0
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-1 -> ../../sda
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-2 -> ../../sdb
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-3 -> ../../sdc
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-4 -> ../../sdd
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-5 -> ../../sde
lrwxrwxrwx 1 root root  9 Mar 26 17:15 pci-0000:00:01.1-ata-2.0 -> ../../sr0
lrwxrwxrwx 1 root root  9 Mar 27 17:48 pci-0000:00:0a.0 -> ../../vda
lrwxrwxrwx 1 root root 10 Mar 27 17:48 pci-0000:00:0a.0-part1 -> ../../vda1
lrwxrwxrwx 1 root root 10 Mar 27 17:48 pci-0000:00:0a.0-part2 -> ../../vda2
lrwxrwxrwx 1 root root  9 Mar 27 17:48 pci-0000:00:0b.0 -> ../../vdb
lrwxrwxrwx 1 root root  9 Mar 27 17:48 virtio-pci-0000:00:0a.0 -> ../../vda
lrwxrwxrwx 1 root root 10 Mar 27 17:48 virtio-pci-0000:00:0a.0-part1 -> ../../vda1
lrwxrwxrwx 1 root root 10 Mar 27 17:48 virtio-pci-0000:00:0a.0-part2 -> ../../vda2
lrwxrwxrwx 1 root root  9 Mar 27 17:48 virtio-pci-0000:00:0b.0 -> ../../vdb
[root@k8s-19rac02 ~]#

[root@k8s-19rac03 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdd           8:48   0  200G  0 disk 
sdb           8:16   0   50G  0 disk 
vdb         251:16   0  200G  0 disk 
└─ol-root   252:0    0  287G  0 lvm  /
sr0          11:0    1  4.5G  0 rom  
sde           8:64   0  200G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0  287G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
[root@k8s-19rac03 ~]# partprobe
Warning: Unable to open /dev/sr0 read-write (Read-only file system).  /dev/sr0 has been opened read-only.
[root@k8s-19rac03 ~]# 
[root@k8s-19rac03 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdd           8:48   0  200G  0 disk 
sdb           8:16   0   50G  0 disk 
vdb         251:16   0  200G  0 disk 
└─ol-root   252:0    0  287G  0 lvm  /
sr0          11:0    1  4.5G  0 rom  
sde           8:64   0  200G  0 disk 
sdc           8:32   0   50G  0 disk 
sda           8:0    0   50G  0 disk 
vda         251:0    0  120G  0 disk 
├─vda2      251:2    0  119G  0 part 
│ ├─ol-swap 252:1    0   32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0  287G  0 lvm  /
└─vda1      251:1    0    1G  0 part /boot
[root@k8s-19rac03 ~]# iscsiadm -m session -R
Rescanning session [sid: 1, target: iqn.2023-11.com.oracle:rac, portal: 3.3.3.179,3260]
[root@k8s-19rac03 ~]# lsscsi
[1:0:0:0]    cd/dvd  SANGFOR  DVD-ROM          2.5+  /dev/sr0 
[2:0:0:0]    storage IET      Controller       0001  -        
[2:0:0:1]    disk    IET      VIRTUAL-DISK     0001  /dev/sdb 
[2:0:0:2]    disk    IET      VIRTUAL-DISK     0001  /dev/sda 
[2:0:0:3]    disk    IET      VIRTUAL-DISK     0001  /dev/sdc 
[2:0:0:4]    disk    IET      VIRTUAL-DISK     0001  /dev/sdd 
[2:0:0:5]    disk    IET      VIRTUAL-DISK     0001  /dev/sde 
[root@k8s-19rac03 ~]# ll  /dev/disk/by-path
total 0
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-1 -> ../../sdb
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-2 -> ../../sda
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-3 -> ../../sdc
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-4 -> ../../sdd
lrwxrwxrwx 1 root root  9 Mar 27 17:48 ip-3.3.3.179:3260-iscsi-iqn.2023-11.com.oracle:rac-lun-5 -> ../../sde
lrwxrwxrwx 1 root root  9 Mar 26 17:15 pci-0000:00:01.1-ata-2.0 -> ../../sr0
lrwxrwxrwx 1 root root  9 Mar 27 17:48 pci-0000:00:0a.0 -> ../../vda
lrwxrwxrwx 1 root root 10 Mar 27 17:48 pci-0000:00:0a.0-part1 -> ../../vda1
lrwxrwxrwx 1 root root 10 Mar 27 17:48 pci-0000:00:0a.0-part2 -> ../../vda2
lrwxrwxrwx 1 root root  9 Mar 27 17:48 pci-0000:00:0b.0 -> ../../vdb
lrwxrwxrwx 1 root root  9 Mar 27 17:48 virtio-pci-0000:00:0a.0 -> ../../vda
lrwxrwxrwx 1 root root 10 Mar 27 17:48 virtio-pci-0000:00:0a.0-part1 -> ../../vda1
lrwxrwxrwx 1 root root 10 Mar 27 17:48 virtio-pci-0000:00:0a.0-part2 -> ../../vda2
lrwxrwxrwx 1 root root  9 Mar 27 17:48 virtio-pci-0000:00:0b.0 -> ../../vdb
[root@k8s-19rac03 ~]#



[root@k8s-19rac01 ~]# tree /var/lib/iscsi/
/var/lib/iscsi/
├── ifaces
├── isns
├── nodes
│   └── iqn.2023-11.com.oracle:rac
│       └── 3.3.3.179,3260,1
│           └── default
├── send_targets
│   └── 3.3.3.179,3260
│       ├── iqn.2023-11.com.oracle:rac,3.3.3.179,3260,1,default -> /var/lib/iscsi/nodes/iqn.2023-11.com.oracle:rac/3.3.3.179,3260,1
│       └── st_config
├── slp
└── static

10 directories, 2 files
[root@k8s-19rac01 ~]# 

[root@k8s-19rac02 ~]# tree /var/lib/iscsi/
/var/lib/iscsi/
├── ifaces
├── isns
├── nodes
│   └── iqn.2023-11.com.oracle:rac
│       └── 3.3.3.179,3260,1
│           └── default
├── send_targets
│   └── 3.3.3.179,3260
│       ├── iqn.2023-11.com.oracle:rac,3.3.3.179,3260,1,default -> /var/lib/iscsi/nodes/iqn.2023-11.com.oracle:rac/3.3.3.179,3260,1
│       └── st_config
├── slp
└── static

10 directories, 2 files
[root@k8s-19rac02 ~]# 

[root@k8s-19rac01 ~]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
iscsid.startup = /bin/systemctl start iscsid.socket iscsiuio.socket
iscsid.safe_logout = Yes
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 120
node.conn[0].timeo.login_timeout = 15
node.conn[0].timeo.logout_timeout = 15
node.conn[0].timeo.noop_out_interval = 5
node.conn[0].timeo.noop_out_timeout = 5
node.session.err_timeo.abort_timeout = 15
node.session.err_timeo.lu_reset_timeout = 30
node.session.err_timeo.tgt_reset_timeout = 30
node.session.initial_login_retry_max = 8
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
[root@k8s-19rac01 ~]# 


[root@k8s-19rac02 iscsi]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
iscsid.startup = /bin/systemctl start iscsid.socket iscsiuio.socket
iscsid.safe_logout = Yes
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 120
node.conn[0].timeo.login_timeout = 15
node.conn[0].timeo.logout_timeout = 15
node.conn[0].timeo.noop_out_interval = 5
node.conn[0].timeo.noop_out_timeout = 5
node.session.err_timeo.abort_timeout = 15
node.session.err_timeo.lu_reset_timeout = 30
node.session.err_timeo.tgt_reset_timeout = 30
node.session.initial_login_retry_max = 8
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

#(此处原有的good/bad调参历史对比记录已移至附录14.2,主流程只保留现行标准)
```



#优化iscsid.conf参数

```bash
# cp /etc/iscsi/iscsid.conf /etc/iscsi/iscsid.conf.bak

# vi /etc/iscsi/iscsid.conf
#修改以下参数
node.session.cmds_max = 256
node.session.queue_depth = 128
node.conn[0].iscsi.MaxXmitDataSegmentLength = 262144
#!!!无多路径(no multipath)环境必须为1
#nr_sessions>1会对同一target建立多个session,同一LUN出现多个/dev/sdX重复设备,
#这正是前文"三台rac节点共享目录顺序不一致"的诱因之一;只有配合dm-multipath聚合时才允许>1
node.session.nr_sessions = 1
node.session.iscsi.RedirectSupport = Yes
#存储路径故障时IO最长挂起时间,需与CSS misscount(默认30s)联动考虑:
#设60s时存储抖动期间IO挂起>misscount,节点会先被驱逐;单路径iSCSI建议30
node.session.timeo.replacement_timeout = 30
node.conn[0].timeo.noop_out_interval = 2
node.conn[0].timeo.noop_out_timeout = 3
#内网可信环境可注释掉以省CPU;保留则有线路级校验
node.conn[0].iscsi.HeaderDigest = CRC32C

```

#最后完整的参数列表

```bash
[root@k8s-19rac01 ~]# cat /etc/iscsi/iscsid.conf |grep -v ^$|grep -v ^#
iscsid.startup = /bin/systemctl start iscsid.socket iscsiuio.socket
iscsid.safe_logout = Yes
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 30
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
node.session.nr_sessions = 1
node.session.iscsi.RedirectSupport = Yes
node.session.iscsi.FastAbort = Yes
node.session.scan = auto
```

#重启iscsi生效

```bash
# systemctl restart iscsi

# systemctl status iscsi

# iscsiadm -m session -P 3
```



#参数生效验收

```bash
iscsiadm -m session -P 3 | egrep -i "Recovery Timeout|Target:|SID|Attached scsi"
lsblk
ls -l /dev/disk/by-path/ | grep iscsi
```

#验收标准:
#1)每个RAC节点对同一target只有1个session(SID唯一),Recovery Timeout=30
#2)同一LUN只对应1个块设备,/dev/disk/by-path下每个LUN只有一条iscsi路径
#3)ASM只允许使用udev映射后的稳定设备名(本环境为/dev/oracleasm/disks/*),任何配置不得直接引用/dev/sdX

#!!!以下为参数优化前的旧日志(Recovery Timeout:120、HeaderDigest:None等与现行标准不一致),
#仅用于理解iscsiadm -P 3各输出字段的含义,不代表最终验收结果(验收以上方"参数生效验收"为准)

#iscsi.service的状态变化

```bash
#yum install -y iscsi-initiator-utils libiscsi后 
[root@k8s-19rac01 ~]# systemctl status iscsi
● iscsi.service - Login and scanning of iSCSI devices
   Loaded: loaded (/usr/lib/systemd/system/iscsi.service; enabled; vendor preset: disabled)
   Active: inactive (dead)
     Docs: man:iscsiadm(8)
           man:iscsid(8)
#重启后
[root@k8s-19rac01 ~]# systemctl restart iscsi
[root@k8s-19rac01 ~]# systemctl status iscsi
● iscsi.service - Login and scanning of iSCSI devices
   Loaded: loaded (/usr/lib/systemd/system/iscsi.service; enabled; vendor preset: disabled)
   Active: inactive (dead)
Condition: start condition failed at Wed 2023-11-22 10:12:27 CST; 1s ago
           ConditionDirectoryNotEmpty=/var/lib/iscsi/nodes was not met
     Docs: man:iscsiadm(8)
           man:iscsid(8)

#优化参数完成后，重启：
[root@k8s-19rac01 ~]#  systemctl status iscsi
● iscsi.service - Login and scanning of iSCSI devices
   Loaded: loaded (/usr/lib/systemd/system/iscsi.service; enabled; vendor preset: disabled)
   Active: active (exited) since Fri 2025-03-28 10:44:47 CST; 2s ago
     Docs: man:iscsiadm(8)
           man:iscsid(8)
  Process: 19701 ExecStart=/sbin/iscsiadm -m node --loginall=automatic (code=exited, status=0/SUCCESS)
 Main PID: 19701 (code=exited, status=0/SUCCESS)

Mar 28 10:44:47 k8s-19rac01 systemd[1]: Starting Login and scann...
Mar 28 10:44:47 k8s-19rac01 systemd[1]: Started Login and scanni...
Hint: Some lines were ellipsized, use -l to show in full.

[root@k8s-19rac01 ~]# iscsiadm -m session -P 3
iSCSI Transport Class version 2.0-870
version 6.2.0.874-22
Target: iqn.2023-11.com.oracle:rac (non-flash)
	Current Portal: 3.3.3.179:3260,1
	Persistent Portal: 3.3.3.179:3260,1
		**********
		Interface:
		**********
		Iface Name: default
		Iface Transport: tcp
		Iface Initiatorname: iqn.2023-11.com.oracle:rac
		Iface IPaddress: 3.3.3.172
		Iface HWaddress: <empty>
		Iface Netdev: <empty>
		SID: 1
		iSCSI Connection State: LOGGED IN
		iSCSI Session State: LOGGED_IN
		Internal iscsid Session State: NO CHANGE
		*********
		Timeouts:
		*********
		Recovery Timeout: 120
		Target Reset Timeout: 30
		LUN Reset Timeout: 30
		Abort Timeout: 15
		*****
		CHAP:
		*****
		username: <empty>
		password: ********
		username_in: <empty>
		password_in: ********
		************************
		Negotiated iSCSI params:
		************************
		HeaderDigest: None
		DataDigest: None
		MaxRecvDataSegmentLength: 262144
		MaxXmitDataSegmentLength: 8192
		FirstBurstLength: 65536
		MaxBurstLength: 262144
		ImmediateData: Yes
		InitialR2T: Yes
		MaxOutstandingR2T: 1
		************************
		Attached SCSI devices:
		************************
		Host Number: 2	State: running
		scsi2 Channel 00 Id 0 Lun: 0
		scsi2 Channel 00 Id 0 Lun: 1
			Attached scsi disk sda		State: running
		scsi2 Channel 00 Id 0 Lun: 2
			Attached scsi disk sdb		State: running
		scsi2 Channel 00 Id 0 Lun: 3
			Attached scsi disk sdc		State: running
		scsi2 Channel 00 Id 0 Lun: 4
			Attached scsi disk sdd		State: running
		scsi2 Channel 00 Id 0 Lun: 5
			Attached scsi disk sde		State: running

```



#### 1.7.2.后续如果出现共享磁盘的uuid乱了时，可以退出并重新扫描、登录

```bash
ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

# /u01/app/19.0.0/grid/bin/crsctl stop cluster -f

/usr/sbin/iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 3.3.3.179:3260 --logout

#iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 3.3.3.179:3260 -o delete
#systemctl restart iscsi.service

/usr/sbin/iscsiadm -m discovery -tsendtargets -p 3.3.3.179:3260

iscsiadm -m node -T iqn.2023-11.com.oracle:rac -p 3.3.3.179:3260 -l

lsblk

ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

/usr/sbin/partprobe

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service

ll /dev|grep asm

ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done

#root用户下
/u01/app/19.0.0/grid/bin/crsctl start cluster
/u01/app/19.0.0/grid/bin/crsctl status resource -t
```



#有时候oracle-store会报错tgtd.service，需要iscsi服务器端先重启tgtd和target，然后rac01/rac02做上面的配置

```
Apr 18 21:00:32 k8s-oracle-store tgtd: tgtd: conn_close(140) Forcing release of tx task 0x20aeea0 10000054 1
Apr 18 21:00:37 k8s-oracle-store kernel: tgtd[25468]: segfault at 0 ip 000000000040b25a sp 00007ffca4e858f0 error 6 in tgtd[400000+4b000]
Apr 18 21:00:37 k8s-oracle-store kernel: Code: 48 83 ec 08 48 8b 42 98 83 38 0a 74 43 48 8b 88 28 02 00 00 48 8d 72 b0 48 05 20 02 00 00 48 89 70 08 48 89 42 b0 48 89 4a b8 <48> 89 31 be 05 00 00 00 48 8b 7a 98 48 8b 87 68 02 00 00 ff 90 90
Apr 18 21:00:41 k8s-oracle-store systemd: tgtd.service: main process exited, code=killed, status=11/SEGV
Apr 18 21:00:41 k8s-oracle-store systemd: Unit tgtd.service entered failed state.
Apr 18 21:00:41 k8s-oracle-store systemd: tgtd.service failed.
```

```bash
systemctl restart tgtd.service

systemctl restart target.service

systemctl enable tgtd

tgt-admin -dump

tgtadm --lld iscsi --mode target --op show

netstat -anp|grep tgt
```





#ocrcheck -local报错处理

```bash
#如果ocrcheck -local报错，那么可以restore
[root@k8s-19rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
Status of Oracle Cluster Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      84464
	 Available space (kbytes) :     407220
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
	 Used space (kbytes)      :      83408
	 Available space (kbytes) :     408276
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-19rac02/olr/k8s-19rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed



[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-19rac02     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-19rac02/olr/autobackup_20231118_184948.olr     724960844

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-19rac02/olr/autobackup_20231118_184948.olr
[root@k8s-19rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-19rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-19rac02/olr/backup_20231118_183548.olr     724960844     

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



[root@k8s-19rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-19rac02 ~]# 
```





### 1.8.RAC/iSCSI/ADG启停SOP(P0必读)

#!!!本架构下store节点是RAC共享磁盘入口,启停顺序错误会导致ASM磁盘不可见、CRS资源异常、数据库实例启动失败。
#计划停机、机房断电演练、宿主机维护、store维护前必须按本节checklist执行。

#### 1.8.1.计划停机顺序

| 顺序 | 操作对象 | 执行动作 | 验收点 |
| ---- | -------- | -------- | ------ |
| 1 | 应用/连接池 | 停止业务写入,确认连接池不再新建连接 | 应用侧无新事务进入 |
| 2 | 数据库service | `srvctl stop service -d xydb` 或按PDB/service逐个停止 | `srvctl status service -d xydb`无业务service运行 |
| 3 | 数据库 | `srvctl stop database -d xydb -o immediate` | `srvctl status database -d xydb`全部not running |
| 3a | ADG备库 | 主库停库后可停止备库数据库/监听;若仅停主集群维护,备库可保持运行但需确认无角色切换动作 | 备库状态有记录,无误触发failover |
| 4 | CRS/GI | 各RAC节点root执行 `crsctl stop crs -f` 或按节点停cluster | `crsctl check crs`确认本节点CRS已停 |
| 5 | RAC节点OS | 关闭rac01/rac02/rac03 | OS关机完成 |
| 6 | store节点 | 最后关闭k8s-19rac-store | store必须最后关闭 |

```bash
#节点一oracle用户示例
srvctl status service -d xydb
srvctl stop service -d xydb
srvctl stop database -d xydb -o immediate
srvctl status database -d xydb

#各RAC节点root执行
/u01/app/19.0.0/grid/bin/crsctl stop crs -f
/u01/app/19.0.0/grid/bin/crsctl check crs
```

#### 1.8.2.计划开机顺序

| 顺序 | 操作对象 | 执行动作 | 验收点 |
| ---- | -------- | -------- | ------ |
| 1 | store节点 | 先启动k8s-19rac-store | OS、网络、tgtd/target正常 |
| 2 | iSCSI服务端 | 确认LUN导出 | `tgt-admin -dump`、`tgtadm --lld iscsi --mode target --op show`可见全部LUN |
| 3 | RAC节点OS | 启动rac01/rac02/rac03 | 能ping通public/private/iscsi地址 |
| 4 | iSCSI客户端 | 确认每节点session与LUN | `iscsiadm -m session -P 3`、`ls -l /dev/oracleasm/disks/`正常 |
| 5 | CRS/GI | 各节点启动CRS | `crsctl stat res -t`无异常OFFLINE |
| 6 | 数据库/service | 启动数据库与业务service | `srvctl status database/service`正常 |
| 6a | ADG备库 | 启动/核对备库MRP与传输状态 | `dgmgrl show configuration`为SUCCESS,`transport lag/apply lag`可接受 |
| 7 | 应用 | 恢复应用连接 | 应用连接串/连接池验证通过 |

```bash
#store节点root执行
#本环境实际使用tgtd(scsi-target-utils);若改用LIO/targetcli,只检查target.service,二选一按实际部署执行
systemctl start tgtd.service
systemctl status tgtd.service
#LIO/targetcli环境才执行以下两行;本tgtd环境保持注释
#systemctl start target.service
#systemctl status target.service
tgt-admin -dump
tgtadm --lld iscsi --mode target --op show

#RAC节点root执行
iscsiadm -m session -P 3 | egrep -i "Recovery Timeout|Target:|SID|Attached scsi"
ls -l /dev/oracleasm/disks/
/u01/app/19.0.0/grid/bin/crsctl start crs -wait
/u01/app/19.0.0/grid/bin/crsctl stat res -t

#节点一oracle用户执行
srvctl start database -d xydb
srvctl start service -d xydb
srvctl status database -d xydb
srvctl status service -d xydb
```

#### 1.8.3.异常开机后的最低自检

#若发生断电、误关store、tgtd崩溃、宿主机迁移、iSCSI重扫后盘符变化,禁止直接启动数据库,必须先完成以下检查:

```bash
#store节点
systemctl status tgtd target
tgt-admin -dump
tgtadm --lld iscsi --mode target --op show

#所有RAC节点
iscsiadm -m session
iscsiadm -m session -P 3 | egrep -i "Target:|SID|Recovery Timeout|Attached scsi"
ls -l /dev/oracleasm/disks/
for d in OCR01 OCR02 OCR03 DATA01 FRA01; do [ -e /dev/oracleasm/disks/$d ] && echo "OK $d" || echo "MISS $d"; done

#GI/DB层
/u01/app/19.0.0/grid/bin/crsctl stat res -t
/u01/app/19.0.0/grid/bin/ocrcheck
/u01/app/19.0.0/grid/bin/crsctl query css votedisk
su - grid -c 'asmcmd lsdg'
su - oracle -c 'srvctl status database -d xydb'
```

#验收口径:第13章postcheck.sh输出FAIL=0后,才允许宣布恢复完成。


## 2.准备工作（rac01 与 rac02 同时配置）

### 2.1. 配置本地 yum 源--可选

#挂载光驱
```bash
mount -t auto /dev/cdrom /mnt
```
#配置本地源
```bash
cat >> CentOS-Media.repo <<EOF
# CentOS-Media.repo
#
# This repo can be used with mounted DVD media, verify the mount point for
# CentOS-7. You can use this repo and yum to install items directly off the
# DVD ISO that we release.
#
# To use this repo, put in your DVD and use it with the other repos too:
# yum --enablerepo=c7-media [command]
#
# or for ONLY the media repo, do this:
#
# yum --disablerepo=\* --enablerepo=c7-media [command]
[c7-media]
name=CentOS-$releasever - Media
baseurl=file:///mnt/
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF


yum clean all

yum makecache
```
### 2.2. 安装 rpm 依赖包

#官网为准
```bash
yum install -y binutils
yum install -y compat-libcap1
yum install -y compat-libstdc++-33
yum install -y compat-libstdc++-33.i686
yum install -y gcc
yum install -y gcc-c++
yum install -y glibc
yum install -y glibc.i686
yum install -y glibc-devel
yum install -y glibc-devel.i686
yum install -y ksh
yum install -y libgcc
yum install -y libgcc.i686
yum install -y libstdc++
yum install -y libstdc++.i686
yum install -y libstdc++-devel
yum install -y libstdc++-devel.i686
yum install -y libaio
yum install -y libaio.i686
yum install -y libaio-devel
yum install -y libaio-devel.i686
yum install -y libXext
yum install -y libXext.i686
yum install -y libXtst
yum install -y libXtst.i686
yum install -y libX11
yum install -y libX11.i686
yum install -y libXau
yum install -y libXau.i686
yum install -y libxcb
yum install -y libxcb.i686
yum install -y libXi
yum install -y libXi.i686
yum install -y make
yum install -y sysstat
yum install -y unixODBC
yum install -y unixODBC-devel
yum install -y readline
yum install -y libtermcap-devel
yum install -y bc
yum install -y compat-libstdc++
yum install -y elfutils-libelf
yum install -y elfutils-libelf-devel
yum install -y fontconfig-devel
yum install -y libXi
yum install -y libXtst
yum install -y libXrender
yum install -y libXrender-devel
yum install -y libgcc
yum install -y librdmacm-devel
yum install -y libstdc++
yum install -y libstdc++-devel
yum install -y net-tools
yum install -y nfs-utils
yum install -y python
yum install -y python-configshell
yum install -y python-rtslib
yum install -y python-six
yum install -y targetcli
yum install -y smartmontools

rpm -qa   binutils  compat-libcap1  compat-libstdc++-33    gcc  gcc-c++  glibc    glibc-devel    ksh  libgcc   libstdc++    libstdc++-devel   libaio   libaio-devel    libXext   libXtst  libX11    libXau   libxcb    libXi   make  sysstat  unixODBC   unixODBC-devel  readline  libtermcap-devel  bc  compat-libstdc++  elfutils-libelf  elfutils-libelf-devel  fontconfig-devel  libXi  libXtst  libXrender  libXrender-devel  libgcc  librdmacm-devel  libstdc++  libstdc++-devel  net-tools  nfs-utils  python  python-configshell  python-rtslib  python-six  targetcli  smartmontools
```
### 2.3. 创建用户

#创建用户组及用户前，检查下gid和uid是否已经占用

```bash
cat /etc/group

cd /home

id xxx
```



```bash
groupadd -g 11001 oinstall
groupadd -g 11002 dba
groupadd -g 11003 oper
groupadd -g 11004 backupdba
groupadd -g 11005 dgdba
groupadd -g 11006 kmdba
groupadd -g 11007 asmdba
groupadd -g 11008 asmoper
groupadd -g 11009 asmadmin
groupadd -g 11010 racdba

useradd -u 11011 -g oinstall -G dba,asmdba,backupdba,dgdba,kmdba,racdba,oper oracle

useradd -u 11012 -g oinstall -G asmadmin,asmdba,asmoper,dba grid

passwd oracle
passwd grid

id grid
id oracle

#root/
#oracle/
#grid/
```
```bash
# id oracle
uid=11011(oracle) gid=11001(oinstall) groups=11001(oinstall),11002(dba),11003(oper),11004(backupdba),11005(dgdba),11006(kmdba),11007(asmdba),11010(racdba)
# id grid
uid=11012(grid) gid=11001(oinstall) groups=11001(oinstall),11002(dba),11007(asmdba),11008(asmoper),11009(asmadmin)
```



### 2.4. 配置 host 表


#修改hostname

```bash
#k8s-19rac01
hostnamectl set-hostname k8s-19rac01
#k8s-19rac02
hostnamectl set-hostname k8s-19rac02
#k8s-19rac03
hostnamectl set-hostname k8s-19rac03
#k8s-19rac-store
hostnamectl set-hostname k8s-19rac-store
#k8s-19rac-adg
hostnamectl set-hostname k8s-19rac-adg
```

#hosts 文件配置

```bash
cat >> /etc/hosts <<EOF

#public ip 
172.18.13.172 k8s-19rac01
172.18.13.173 k8s-19rac02
#vip
172.18.13.174 k8s-19rac01-vip					
172.18.13.175 k8s-19rac02-vip
#private ip
10.100.100.172 k8s-19rac01-prv
10.100.100.173 k8s-19rac02-prv
#scan ip
172.18.13.176 rac-scan
#scsi ip
3.3.3.172 k8s-19rac01-iscsi
3.3.3.173 k8s-19rac02-iscsi

#rac03
172.18.13.177 k8s-19rac03
172.18.13.178 k8s-19rac03-vip
10.100.100.177 k8s-19rac03-prv

3.3.3.177 k8s-19rac03-iscsi

#rac-store
172.18.13.179 k8s-19rac-store
3.3.3.179 k8s-19rac-store-iscsi

#rac-adg
172.18.13.180 k8s-19rac-adg
EOF
```




#检查下网络是否顺畅

```bash
ping k8s-19rac01 -c 1 -w 1

ping k8s-19rac02 -c 1 -w 1

ping k8s-19rac01-vip -c 1 -w 1

ping k8s-19rac02-vip -c 1 -w 1

ping k8s-19rac01-prv -c 1 -w 1

ping k8s-19rac02-prv -c 1 -w 1

ping k8s-19rac01-iscsi -c 1 -w 1

ping k8s-19rac02-iscsi -c 1 -w 1

#rac03和adg
ping k8s-19rac03 -c 1 -w 1

ping k8s-19rac03-vip -c 1 -w 1

ping k8s-19rac03-prv -c 1 -w 1

ping k8s-19rac03-iscsi -c 1 -w 1

ping k8s-19rac-adg -c 1 -w 1

#rac-iscsi
ping k8s-19rac-store -c 1 -w 1

ping k8s-19rac-store-iscsi -c 1 -w 1
```



#如果不配置/etc/hosts，那么在后面的dbca时会报错

```log
ora-12154 tns could not resolve the connect identifier specified
```


### 2.4.1.P3:生产SCAN/DNS标准化

#当前文档主流程采用`/etc/hosts`单SCAN IP,这是无DNS环境的降级方案。
#生产环境标准做法是:在DNS中为同一个SCAN名称配置3个A记录,由DNS轮询返回3个SCAN IP;所有RAC节点、ADG节点、应用服务器均通过DNS解析SCAN。

#### 2.4.1.1.DNS记录标准

```text
#DNS侧示例,由学校DNS管理员配置;TTL建议60~300秒
<SCAN_NAME>.    60    IN    A    <SCAN_IP1>
<SCAN_NAME>.    60    IN    A    <SCAN_IP2>
<SCAN_NAME>.    60    IN    A    <SCAN_IP3>

#本环境若仍使用hosts降级方案,只保留:
#172.18.13.176 rac-scan
```

#生产DNS模式下,不要在`/etc/hosts`中写SCAN名称,否则会绕过DNS轮询。
#普通主机名、VIP名、private名可以按环境继续写hosts或接入DNS,但SCAN必须优先走DNS三A记录。

#### 2.4.1.2.DNS解析验收

```bash
#所有RAC节点、ADG节点、应用服务器均执行
getent hosts <SCAN_NAME>
nslookup <SCAN_NAME>

#期望:多次解析能看到3个SCAN IP;顺序可以轮换
for i in {1..10}; do getent ahostsv4 <SCAN_NAME> | awk '{print $1}' | sort -u; sleep 1; done

#GI安装前或变更后检查
echo "<SCAN_IP1> <SCAN_IP2> <SCAN_IP3>"
/u01/app/19.0.0/grid/runcluvfy.sh comp scan -scanname <SCAN_NAME> -verbose
```

#### 2.4.1.3.已建集群从单SCAN/hosts演进到DNS SCAN的注意事项

#1)不要在业务高峰期直接改SCAN解析;该动作会影响客户端连接入口,需要变更窗口。
#2)先完成DNS三A记录并在所有节点确认解析,再清理`/etc/hosts`中SCAN行。
#3)使用`srvctl config scan`确认当前SCAN配置;如需修改SCAN名称,用`srvctl modify scan -scanname <SCAN_NAME>`并重启SCAN/SCAN listener。
#4)变更后必须验证本地监听、SCAN监听、服务注册和应用连接串。

```bash
#grid用户或root调用GRID_HOME/bin
srvctl config scan
srvctl config scan_listener

#如需修改SCAN名称,在变更窗口执行;IP由DNS解析提供
srvctl modify scan -scanname <SCAN_NAME>
srvctl stop scan_listener
srvctl stop scan
srvctl start scan
srvctl start scan_listener

srvctl status scan
srvctl status scan_listener
lsnrctl status LISTENER_SCAN1

#DB服务注册验证
srvctl status service -d xydb
lsnrctl services LISTENER_SCAN1 | egrep -i 'xydb|stuwork|portal|onecode|dataassets'
```

#验收标准:
#1)应用连接串使用SCAN名称,不直接写单节点VIP或单个SCAN IP;
#2)`srvctl status scan_listener`显示SCAN listener在线;
#3)`lsnrctl services LISTENER_SCAN1`能看到PDB服务;
#4)ADG/VNCR启用时,6.4.10的白名单同步包含所有SCAN IP和ADG地址。


### 2.5. 配置时间同步(chrony,CTSS自动转Observer模式)

#!!!不要直接禁用NTP/chrony(旧做法已废弃)
#若所有节点都没有NTP服务,Clusterware的CTSS会进入Active模式:它只保证集群内部相对同步,
#整个集群会与真实时间持续漂移,影响ADG传输/应用判断、应用对账、安全审计取证。
#正确做法:所有节点(rac01/02/03、adg、store)统一配置chronyd指向校园NTP源,CTSS自动转Observer。

```bash
#备份并重写chrony配置;NTP源按学校实际修改,建议校内源为主、公网源备用
cp /etc/chrony.conf /etc/chrony.conf.bak

cat > /etc/chrony.conf <<EOF
#校园NTP服务器(按实际修改)
server ntp.campus.edu.cn iburst
#公网备用源
server ntp.aliyun.com iburst
driftfile /var/lib/chrony/drift
#仅启动后前3次允许步进调整,之后只做渐变(slew),避免运行期时间跳变
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

systemctl enable chronyd --now
systemctl status chronyd

#验证同步状态
chronyc sources -v
chronyc tracking

#各节点间偏差检查
clockdiff k8s-19rac01
clockdiff k8s-19rac02
clockdiff k8s-19rac03
```

#GI安装完成后回头验证CTSS处于Observer模式

```bash
crsctl check ctss
#期望输出:
#CRS-4700: The Cluster Time Synchronization Service is in Observer mode.
#若输出CRS-4701/4702(Active mode),说明该节点未发现NTP服务,检查chronyd状态

cluvfy comp clocksync -n all -verbose
```

#!!!严禁在数据库运行期间手工大幅调整系统时间(date -s / ntpdate / rdate)
#时间回拨可能直接触发实例宕机或节点驱逐;偏差过大时,先停库停CRS,调整后再启动

#时区设置
```bash
#查看是否中国时区
date -R 
timedatectl

#设置中国时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#方法二
timedatectl list-timezones |grep Shanghai #查找中国时区的完整名称
--->Asia/Shanghai
timedatectl set-timezone Asia/Shanghai
```

#修改系统语言环境
```
env|grep LANG

sudo echo 'LANG="en_US.UTF-8"' >> /etc/profile;source /etc/profile
```

### 2.6. 创建所需要目录

```bash
mkdir -p /u01/app/19.0.0/grid
mkdir -p /u01/app/grid
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/oracle/product/19.0.0/db_1

chown -R grid:oinstall /u01
chown -R oracle:oinstall /u01/app/oracle
chmod -R 775 /u01
```
### 2.7. 其它优化配置

#P1强制基线:limits/memlock/sem必须与HugePages、SGA/PGA一起规划

#!!!以下配置替代早期“*通配用户 + memlock unlimited + stack 90000”的做法。
#原则:
#1)只对grid/oracle用户配置资源限制,不要用*影响所有系统用户;
#2)memlock不能简单写unlimited,应大于HugePages总量(KB)并预留5%~10%;
#3)stack采用Oracle常用基线soft 10240 / hard 32768;
#4)HugePages、SGA、PGA、processes、pga_aggregate_limit必须作为一组规划,详见6.4.5。

```bash
#以root在所有RAC节点执行;数值需按6.4.5计算结果替换
#示例:若本节点HugePages_Total=12288, Hugepagesize=2048kB,
#HugePages总量=25165824KB,memlock建议取>=26424116KB(预留约5%)。
#MEMLOCK_KB不要照抄,必须按现场计算。
MEMLOCK_KB=<CALCULATED_MEMLOCK_KB>

cat > /etc/security/limits.d/99-oracle-rac.conf <<EOF
# Oracle RAC resource limits, P1 baseline
# nofile/nproc按grid/oracle分别限制;memlock与HugePages绑定,禁止直接写unlimited
grid   soft   nofile    65536
grid   hard   nofile    65536
grid   soft   nproc     90000
grid   hard   nproc     90000
grid   soft   stack     10240
grid   hard   stack     32768
grid   soft   core      unlimited
grid   hard   core      unlimited
grid   soft   memlock   ${MEMLOCK_KB}
grid   hard   memlock   ${MEMLOCK_KB}

oracle soft   nofile    65536
oracle hard   nofile    65536
oracle soft   nproc     90000
oracle hard   nproc     90000
oracle soft   stack     10240
oracle hard   stack     32768
oracle soft   core      unlimited
oracle hard   core      unlimited
oracle soft   memlock   ${MEMLOCK_KB}
oracle hard   memlock   ${MEMLOCK_KB}
EOF

#不要再用sed全局替换20-nproc.conf;如需覆盖,仅追加oracle/grid专用项
cat > /etc/security/limits.d/99-oracle-nproc.conf <<EOF
grid   soft   nproc   90000
oracle soft   nproc   90000
EOF

#确保pam_limits生效
grep -q '^session required pam_limits.so' /etc/pam.d/login || echo 'session required pam_limits.so' >> /etc/pam.d/login

#验收:重新登录grid/oracle后检查
su - grid -c 'ulimit -Sn; ulimit -Hn; ulimit -Su; ulimit -Hu; ulimit -Ss; ulimit -Hs; ulimit -l'
su - oracle -c 'ulimit -Sn; ulimit -Hn; ulimit -Su; ulimit -Hu; ulimit -Ss; ulimit -Hs; ulimit -l'
```

#P1强制基线:sysctl最小补充项

```bash
#以下在原sysctl基础上补齐,不要重复写多份冲突配置;建议最终整理到/etc/sysctl.d/99-oracle-rac.conf
cat >> /etc/sysctl.d/99-oracle-rac.conf <<EOF
# P1 baseline additions
vm.swappiness = 1
kernel.panic_on_oops = 1
#建议512MB~1GB,按内存规模调整;防止内存碎片/低水位引发抖动
vm.min_free_kbytes = 1048576
EOF

sysctl --system
```

#P1说明:kernel.sem早期示例值`6144 50331648 4096 8192`来源不明且SEMMNS过大。
#本轮先不强制替换已运行环境,但新部署建议优先采用Oracle preinstall rpm基线`250 32000 100 128`,
#当processes显著增大时再按实例数、processes与并发连接模型计算并在变更单中说明依据。


#### 2.7.1.P2 OS参数终版基线与MTU 9000方案

#本节是P2阶段对2.7的生产化收口。已有运行环境不要盲目覆盖;先导出现值、评估变更窗口,再按变更单执行。

##### 2.7.1.1.kernel.sem与内存相关参数终版决策

| 参数 | P2建议 | 说明 |
| ---- | ------ | ---- |
| `kernel.sem` | 新部署优先采用`250 32000 100 128`;若`processes`/实例数很大,按连接模型计算后提高`SEMMSL/SEMMNI` | 早期`6144 50331648 4096 8192`不再作为默认模板;保留运行环境需在变更记录注明来源 |
| `vm.swappiness` | `1` | 减少Oracle进程被换出 |
| `kernel.panic_on_oops` | `1` | 内核oops时快速失败,避免节点长时间半死不活 |
| `vm.min_free_kbytes` | 512MB~1GB起步,大内存主机可按压测调整 | 防止低水位内存碎片引发抖动 |
| `rp_filter` | public=1, private/iscsi=2 | RAC私网/存储网必须松散模式,避免HAIP/多路径场景误丢包 |
| `memlock` | 大于HugePages总量KB并预留5%~10% | 与6.4.5一致,禁止简单照抄unlimited |

```bash
#执行前备份现状
mkdir -p /root/baseline_$(date +%F)
sysctl -a > /root/baseline_$(date +%F)/sysctl.before.txt
cat /etc/security/limits.d/*.conf > /root/baseline_$(date +%F)/limits.before.txt 2>/dev/null || true

#P2建议统一整理到单独文件,并清理旧写入源,避免多处重复覆盖。
#重要:sysctl --system会按顺序读取/etc/sysctl.d/*.conf,最后读取/etc/sysctl.conf;
#若/etc/sysctl.conf里仍有kernel.sem等同名键,会静默覆盖sysctl.d里的P2基线。
#因此执行P2基线前必须备份并注释/etc/sysctl.conf中的同名键,同时使用99-z前缀确保本文件在99-oracle-rac.conf之后加载。
cp /etc/sysctl.conf /root/baseline_$(date +%F)/sysctl.conf.before_p2 2>/dev/null || true
sed -ri 's/^([[:space:]]*(fs\.aio-max-nr|fs\.file-max|net\.ipv4\.ip_local_port_range|net\.core\.rmem_default|net\.core\.rmem_max|net\.core\.wmem_default|net\.core\.wmem_max|vm\.swappiness|kernel\.panic_on_oops|vm\.min_free_kbytes|kernel\.sem|net\.ipv4\.conf\.(all|default|eth[0-9]+)\.rp_filter)[[:space:]]*=)/# P2-moved-to-99-z-oracle-rac-p2.conf \1/' /etc/sysctl.conf
rm -f /etc/sysctl.d/99-oracle-rac-p2.conf

cat > /etc/sysctl.d/99-z-oracle-rac-p2.conf <<'EOF'
# Oracle RAC P2 baseline
fs.aio-max-nr = 3145728
fs.file-max = 6815744
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 4194304
vm.swappiness = 1
kernel.panic_on_oops = 1
vm.min_free_kbytes = 1048576
# 新部署默认值;老环境若已使用更大值,先评估再调整
kernel.sem = 250 32000 100 128
# 网卡名按实际替换:public=eth0, private=eth1, iscsi=eth2或留空
net.ipv4.conf.eth0.rp_filter = 1
net.ipv4.conf.eth1.rp_filter = 2
#net.ipv4.conf.eth2.rp_filter = 2
EOF
sysctl --system

#P2实际生效验收:以运行值为准,不要只看文件内容
sysctl -n kernel.sem
sysctl -n vm.swappiness
sysctl -n kernel.panic_on_oops
sysctl -n vm.min_free_kbytes
[ "$(sysctl -n kernel.sem | tr -s ' ')" = "250 32000 100 128" ] || echo "WARN: kernel.sem未使用P2默认值,如为老环境保留值,必须写入14.5变更记录"
```

##### 2.7.1.2.MTU 9000端到端启用条件

#MTU 9000只在端到端全链路一致时启用,否则会产生间歇性丢包,比1500更危险。
#必须同时确认:Oracle节点网卡、虚拟交换机、物理交换机、iSCSI store网卡/存储端口、ADG相关链路(如要启用)全部支持并已配置。
#建议优先在iSCSI网与RAC private interconnect上启用;public业务网是否启用由网络团队统一规划。

```bash
#示例:private=eth1, iscsi=eth2;按实际网卡名替换
PRIVATE_IF=eth1
ISCSI_IF=eth2
PRIVATE_PEER=10.100.100.173
ISCSI_PEER=3.3.3.179

#配置前查看
ip -br link show $PRIVATE_IF
[ -n "$ISCSI_IF" ] && ip -br link show $ISCSI_IF

#NetworkManager场景
nmcli con mod $PRIVATE_IF 802-3-ethernet.mtu 9000
nmcli con up  $PRIVATE_IF
#若有独立iSCSI网卡再启用
nmcli con mod $ISCSI_IF 802-3-ethernet.mtu 9000
nmcli con up  $ISCSI_IF

#验收:8972 + 28字节IP/ICMP头 = 9000,必须不分片成功
ping -M do -s 8972 -c 3 $PRIVATE_PEER
ping -M do -s 8972 -c 3 $ISCSI_PEER
ip link show $PRIVATE_IF | grep 'mtu 9000'
ip link show $ISCSI_IF   | grep 'mtu 9000'
```

#回退:任一链路不通或出现gc/iSCSI超时,立即统一回退到1500,不可只回退单端。

```bash
nmcli con mod $PRIVATE_IF 802-3-ethernet.mtu 1500
nmcli con up  $PRIVATE_IF
nmcli con mod $ISCSI_IF 802-3-ethernet.mtu 1500
nmcli con up  $ISCSI_IF
```

##### 2.7.2.THP关闭(原有步骤)

#关闭THP，检查是否开启
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```
--->[always] madvise never
#若以上命令执行结果显示为“always”，则表示开启了THP

##修改方法一，必须知道引导是BIOS还是EFI

#可以通过df -h或者cat /etc/fstab查看是否有/boot/efi分区
#[ -d /sys/firmware/efi ] && echo "UEFI" || echo "BIOS"

#则修改/etc/default/grub，在RUB_CMDLINE_LINUX中添加transparent_hugepage=never

#内容如下
```
GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet transparent_hugepage=never numa=off"
```
#执行如下命令，重新生成grub.cfg配置文件

#On BIOS-based machines
```bash
grub2-mkconfig -o /boot/grub2/grub.cfg

reboot
```
#On UEFI-based machines
```bash
grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg

reboot
```
#日志

```
[root@k8s-19rac01 ~]# grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1160.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1160.el7.x86_64.img
Found linux image: /boot/vmlinuz-0-rescue-ec5c058bc1d14a888efba10ef3d6c18f
Found initrd image: /boot/initramfs-0-rescue-ec5c058bc1d14a888efba10ef3d6c18f.img
done
```
重启节点后，检查配置是否正常：
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```
```
--->always madvise [never]
```
检查是否使用HugePages

```bash
# cat /proc/meminfo |grep -i hug
AnonHugePages:         0 kB
HugePages_Total:   128819
HugePages_Free:     5980
HugePages_Rsvd:       42
HugePages_Surp:        0
Hugepagesize:       2048 kB
# cat /sys/kernel/mm/transparent_hugepage/enabled
always madvise [never]
# cat /etc/fstab 

#
# /etc/fstab
# Created by anaconda on Fri Jan  8 23:19:04 2021
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=0483cd82-0c25-4c7f-b281-ab607253bfb4 /boot                   xfs     defaults        0 0
UUID=7E75-FE2E          /boot/efi               vfat    umask=0077,shortname=winnt 0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
```



##方法二
#修改/etc/rc.local，并重启OS

```bash
cat >> /etc/rc.local <<EOF
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

EOF

```
#修改pam.d/login
```bash
cat >> /etc/pam.d/login <<EOF
#ORACLE SETTING
session required pam_limits.so

EOF

```
##### 2.7.3.历史sysctl模板(禁止继续写入/etc/sysctl.conf)

#以下64G/32G块为v2.6.1前历史模板,仅保留用于理解参数来源。
#禁止继续使用cat >> /etc/sysctl.conf追加配置;终版统一走2.7.1.1的/etc/sysctl.d/99-z-oracle-rac-p2.conf,并清理/etc/sysctl.conf同名键。

#memory=64G

```bash
cat <<'EOF'
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 14062500
#memory*90%,此处为64G
kernel.shmmax = 57600000000
kernel.shmmni = 4096
kernel.sem = 6144 50331648 4096 8192
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 4194304
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
#!!!RAC私网网卡必须为松散反向路径过滤(rp_filter=2),依据MOS 1286796.1
#严格模式(=1)下HAIP/多私网网卡场景的互联流量会被内核丢弃,引发gc超时甚至节点驱逐
#内核对rp_filter取 conf/all 与 conf/<网卡> 两者的最大值,按网卡角色显式设置:
#  public业务网卡  : 保持严格(=1)
#  private互联网卡 : 必须松散(=2)
#  iscsi存储网卡   : 建议松散(=2)
#以下网卡名为本环境示例(public=eth0/private=eth1);先用 ip -br addr 对照IP规划
#确认每块网卡的角色后再替换网卡名,禁止照抄
net.ipv4.conf.eth0.rp_filter = 1
net.ipv4.conf.eth1.rp_filter = 2
#存在独立iSCSI存储网卡时,取消下行注释并改为实际网卡名;不存在则保持注释,
#否则 sysctl -p 会报 cannot stat /proc/sys/net/ipv4/conf/eth2/rp_filter
# v2.6.1起:历史模板禁止执行,终版统一走2.7.1.1的sysctl --system
#net.ipv4.conf.eth2.rp_filter = 2
net.ipv4.ipfrag_high_thresh = 16777216
net.ipv4.ipfrag_low_thresh = 15728640

EOF

#sysctl -p  # v2.6.1起:历史模板禁止执行;终版使用2.7.1.1的sysctl --system

#验收:逐网卡确认rp_filter生效值(private/iscsi网卡应为2)
for i in all default eth0 eth1 eth2; do
  [ -e /proc/sys/net/ipv4/conf/$i/rp_filter ] && echo -n "$i=" && cat /proc/sys/net/ipv4/conf/$i/rp_filter
done
```
#memory=32G

```bash
cat <<'EOF'
fs.aio-max-nr = 3145728
fs.file-max = 6815744
#shmax/4096
kernel.shmall = 7031250
#memory*90%,此处为32G
kernel.shmmax = 28800000000
kernel.shmmni = 4096
kernel.sem = 6144 50331648 4096 8192
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 4194304
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
#!!!RAC私网网卡必须为松散反向路径过滤(rp_filter=2),依据MOS 1286796.1
#严格模式(=1)下HAIP/多私网网卡场景的互联流量会被内核丢弃,引发gc超时甚至节点驱逐
#内核对rp_filter取 conf/all 与 conf/<网卡> 两者的最大值,按网卡角色显式设置:
#  public业务网卡  : 保持严格(=1)
#  private互联网卡 : 必须松散(=2)
#  iscsi存储网卡   : 建议松散(=2)
#以下网卡名为本环境示例(public=eth0/private=eth1);先用 ip -br addr 对照IP规划
#确认每块网卡的角色后再替换网卡名,禁止照抄
net.ipv4.conf.eth0.rp_filter = 1
net.ipv4.conf.eth1.rp_filter = 2
#存在独立iSCSI存储网卡时,取消下行注释并改为实际网卡名;不存在则保持注释,
#否则 sysctl -p 会报 cannot stat /proc/sys/net/ipv4/conf/eth2/rp_filter
# v2.6.1起:历史模板禁止执行,终版统一走2.7.1.1的sysctl --system
#net.ipv4.conf.eth2.rp_filter = 2
net.ipv4.ipfrag_high_thresh = 16777216
net.ipv4.ipfrag_low_thresh = 15728640

EOF

#sysctl -p  # v2.6.1起:历史模板禁止执行;终版使用2.7.1.1的sysctl --system

#验收:逐网卡确认rp_filter生效值(private/iscsi网卡应为2)
for i in all default eth0 eth1 eth2; do
  [ -e /proc/sys/net/ipv4/conf/$i/rp_filter ] && echo -n "$i=" && cat /proc/sys/net/ipv4/conf/$i/rp_filter
done
```



#关闭avahi-daemon---无

```bash
systemctl disable avahi-daemon.socket
systemctl disable avahi-daemon.service

ps -ef|grep avahi-daemon|grep -v grep

#avahi 2674 1 0 18:28 ? 00:00:00 avahi-daemon: running [linux.local]
#avahi 2704 2674 0 18:28 ? 00:00:00 avahi-daemon: chroot helper

#kill -9 2674 2704

ps -ef|grep avahi-daemon

```
#nozeroconf
```bash
cat  >> /etc/sysconfig/network <<EOF
NOZEROCONF=yes
EOF
```
#禁用virbr0网卡

```bash
brctl show

ifconfig virbr0 down
brctl delbr virbr0

systemctl disable libvirtd.service
systemctl mask libvirtd.service
```

#日志

```bash
[root@rac01 storage]# systemctl status libvirtd.service
● libvirtd.service - Virtualization daemon
   Loaded: loaded (/usr/lib/systemd/system/libvirtd.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2023-09-25 14:49:28 CST; 29min ago
     Docs: man:libvirtd(8)
           https://libvirt.org
 Main PID: 2542 (libvirtd)
    Tasks: 19 (limit: 32768)
   CGroup: /system.slice/libvirtd.service
           ├─2542 /usr/sbin/libvirtd
           ├─2793 /usr/sbin/dnsmasq --conf-file=/var/lib/libvirt/dnsmasq...
           └─2794 /usr/sbin/dnsmasq --conf-file=/var/lib/libvirt/dnsmasq...

Sep 25 14:49:28 rac01 dnsmasq[2793]: started, version 2.76 cachesize 150
Sep 25 14:49:28 rac01 dnsmasq[2793]: compile time options: IPv6 GNU-get...y
Sep 25 14:49:28 rac01 dnsmasq-dhcp[2793]: DHCP, IP range 192.168.122.2 ...h
Sep 25 14:49:28 rac01 dnsmasq-dhcp[2793]: DHCP, sockets bound exclusive...0
Sep 25 14:49:28 rac01 dnsmasq[2793]: reading /etc/resolv.conf
Sep 25 14:49:28 rac01 dnsmasq[2793]: using nameserver 202.206.16.2#53
Sep 25 14:49:28 rac01 dnsmasq[2793]: using nameserver 233.5.5.5#53
Sep 25 14:49:28 rac01 dnsmasq[2793]: read /etc/hosts - 9 addresses
Sep 25 14:49:28 rac01 dnsmasq[2793]: read /var/lib/libvirt/dnsmasq/defa...s
Sep 25 14:49:28 rac01 dnsmasq-dhcp[2793]: read /var/lib/libvirt/dnsmasq...e
Hint: Some lines were ellipsized, use -l to show in full.
[root@rac01 storage]# brctl show
bridge name     bridge id               STP enabled     interfaces
virbr0          8000.525400292db9       yes             virbr0-nic
[root@rac01 storage]# nmcli con show
NAME    UUID                                  TYPE      DEVICE
eth0    bdc16ef2-d1d0-4c97-889c-961adfa53039  ethernet  eth0
eth1    d5d1bda3-c00f-484f-b818-e68b5023dbc7  ethernet  eth1
virbr0  2c4afa19-bb2b-4fa3-a5a0-6ea5cb84cf96  bridge    virbr0


[root@rac01 storage]# ifconfig virbr0 down
[root@rac01 storage]# brctl delbr virbr0
[root@rac01 storage]# systemctl disable libvirtd.service
Removed symlink /etc/systemd/system/multi-user.target.wants/libvirtd.service.
Removed symlink /etc/systemd/system/sockets.target.wants/virtlogd.socket.
Removed symlink /etc/systemd/system/sockets.target.wants/virtlockd.socket.
[root@rac01 storage]# systemctl mask libvirtd.service
Created symlink from /etc/systemd/system/libvirtd.service to /dev/null.
[root@rac01 storage]#
```



### 2.8. 配置环境变量

#grid用户，注意rac01/rac02两台服务器的区别

```bash
su - grid

cat >> /home/grid/.bash_profile <<'EOF'

export ORACLE_SID=+ASM1
#注意rac02修改
#export ORACLE_SID=+ASM2
#注意rac03修改
#export ORACLE_SID=+ASM3
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF

```
#oracle用户，注意rac01/rac02的区别
```bash
su - oracle

cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/db_1
export ORACLE_SID=xydb1
#注意rac02修改
#export ORACLE_SID=xydb2
#注意rac03修改
#export ORACLE_SID=xydb3
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
EOF

```
### 2.9. 配置共享磁盘权限

#!!!本环境ASM设备命名规范:统一为 /dev/oracleasm/disks/<盘名>(由本节udev规则生成)。
#文档后文引用的其他环境历史示例(/dev/asm-crs1、/dev/asm-data等)仅作参考;
#本集群新增任何磁盘(含第8章扩容、第10章节点三)一律沿用 /dev/oracleasm/disks/ 命名,禁止混用

#### 2.9.1.无多路径模式

#适用于vsphere平台直接共享存储磁盘

#检查磁盘UUID
```bash
sfdisk -s
##如果由于H3C CAS虚拟化平台磁盘类型中没有scsi类型，导致不支持scsi_id命令识别磁盘，只能使用udevadm查看，而学校暂不支持改为裸块加入iscsi高速硬盘
##可以采用oracle asmlib管理磁盘
#/usr/lib/udev/scsi_id -g -u -d devicename
ls -1cv /dev/vs* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
ls -1cv /dev/vd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; udevadm info --query=all --name=$disk|grep ID_SERIAL ; done
```
#本次正常使用udev管理磁盘

```
[root@k8s-19rac01 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sde: 104857600
/dev/sdf: 104857600
/dev/sdg: 209715200
total: 932179968 blocks
[root@k8s-19rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007

[root@k8s-19rac02 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdf: 104857600
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sdg: 209715200
/dev/sde: 104857600
total: 932179968 blocks
[root@k8s-19rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
```
#oracleasm管理磁盘---本次不使用

```bash
#格式化存储分区：仅rac01执行！
       ##2T以上磁盘分区用parted，2T以下分区用fdisk，ASM管理磁盘只支持最大2T的分区加入卷
       fdisk -l
       
       fdisk /dev/vdb
       fdisk /dev/vdc
       fdisk /dev/vdd
       
       fdisk /dev/vde
       fdisk /dev/vdf
       fdisk /dev/vdg
       
       fdisk /dev/vdh
       fdisk /dev/vdi
       fdisk /dev/vdj       
       fdisk  -l
---------------------------------------------------
m--->n--->p--->1--->默认值回车--->默认值回车--->w
----------------------------------------------------


#如果不格式化磁盘，那么会报错：
oracleasm createdisk DATA1 /dev/vde
Device "/dev/vde" is not a partition


[root@rac01 ~]# mount /dev/sr0 /mnt
[root@rac01 ~]# cd /mnt/Packages

[root@rac01 Packages]# ls -lrth|grep oracleasm
-rw-rw-r-- 1 1039 1039   85K Feb  4  2018 oracleasm-support-2.1.11-2.el7.x86_64.rpm
-rw-rw-r-- 1 1039 1039  298K May 29  2020 kmod-oracleasm-2.0.8-28.0.1.el7.x86_64.rpm

#安装并配置asm:----root账户下
#安装kmod-oracleasm/oracleasmlib/oracleasm-support，注意安装顺序：
     yum -y install kmod-oracleasm
     rpm -ivh oracleasmlib-
     rpm -ivh oracleasm-support-

yum install kmod-oracleasm-2.0.8-28.0.1.el7.x86_64.rpm oracleasmlib-2.0.12-1.el7.x86_64.rpm oracleasm-support-2.1.11-2.el7.x86_64.rpm

# rpm -qa|grep oracleasm
oracleasmlib-2.0.12-1.el7.x86_64
oracleasm-support-2.1.11-2.el7.x86_64
kmod-oracleasm-2.0.8-28.0.1.el7.x86_64

#安装完成后配置asmlib使用如下命令：
     oracleasm --help
     #设置asmlib
     oracleasm configure -i
     grid-->asmadmin-->y-->y---->done
     #载入asm模块
     oracleasm init
     #创建ASM磁盘----仅rac01执行！
     oracleasm createdisk OCR1 /dev/vdb1
     oracleasm createdisk OCR2 /dev/vdc1
     oracleasm createdisk OCR3 /dev/vdd1
     
     oracleasm createdisk data01 /dev/vde1
     oracleasm createdisk data02 /dev/vdf1
     oracleasm createdisk data03 /dev/vdg1
     
     oracleasm createdisk fra01 /dev/vdh1
     oracleasm createdisk fra02 /dev/vdi1
     oracleasm createdisk fra03 /dev/vdj1
     
     oracleasm listdisks
     cd /dev/oracleasm/disks/
     ls -lrth
     oracleasm querydisk -p OCR1
     ......
     oracleasm querydisk -p FRA03
     
    #扫描ASM磁盘---rac02执行
     oracleasm scandisks
    #查看ASM磁盘
     oracleasm listdisks
     cd /dev/oracleasm/disks/
     ls -lrth
     oracleasm querydisk -p OCR1
     ......
     oracleasm querydisk -p FRA03
     
#重启，测试
reboot
oracleasm status
```

#asmlib配置日志

```bash
#rac01:
[root@rac01 Packages]# oracleasm configure -i
Configuring the Oracle ASM library driver.

This will configure the on-boot properties of the Oracle ASM library
driver.  The following questions will determine whether the driver is
loaded on boot and what permissions it will have.  The current values
will be shown in brackets ('[]').  Hitting <ENTER> without typing an
answer will keep that current value.  Ctrl-C will abort.

Default user to own the driver interface []: grid
Default group to own the driver interface []: asmadmin
Start Oracle ASM library driver on boot (y/n) [n]: y
Scan for Oracle ASM disks on boot (y/n) [y]: y
Writing Oracle ASM library driver configuration: done

[root@rac01 ~]# reboot

[root@rac01 ~]# oracleasm status
Checking if ASM is loaded: yes
Checking if /dev/oracleasm is mounted: yes

#rac02:
[root@rac02 ~]# oracleasm configure -i
Configuring the Oracle ASM library driver.

This will configure the on-boot properties of the Oracle ASM
driver.  The following questions will determine whether the d
loaded on boot and what permissions it will have.  The curren
will be shown in brackets ('[]').  Hitting <ENTER> without ty
answer will keep that current value.  Ctrl-C will abort.

Default user to own the driver interface []: grid
Default group to own the driver interface []: asmadmin
Start Oracle ASM library driver on boot (y/n) [n]: y
Scan for Oracle ASM disks on boot (y/n) [y]: y
Writing Oracle ASM library driver configuration: done

[root@rac02 ~]# reboot


[root@rac01 ~]# reboot

[root@rac02 ~]# oracleasm status
Checking if ASM is loaded: yes
Checking if /dev/oracleasm is mounted: yes

[root@rac01 ~]# fdisk -l

Disk /dev/vda: 1099.5 GB, 1099511627776 bytes, 2147483648 sec                                                                  tors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000031f0

   Device Boot      Start         End      Blocks   Id  Syste                                                                  m
/dev/vda1   *        2048     2099199     1048576   83  Linux
/dev/vda2         2099200  2147483647  1072692224   8e  Linux                                                                   LVM

Disk /dev/vdb: 107.4 GB, 107374182400 bytes, 209715200 sectors                                         
Disk /dev/vdc: 107.4 GB, 107374182400 bytes, 209715200 sectors                                         
Disk /dev/vdd: 107.4 GB, 107374182400 bytes, 209715200 sectors                                         

Disk /dev/vde: 2147.5 GB, 2147483648000 bytes, 4194304000 sectors
Disk /dev/vdf: 2147.5 GB, 2147483648000 bytes, 4194304000 sectors
Disk /dev/vdg: 2147.5 GB, 2147483648000 bytes, 4194304000 sectors

Disk /dev/vdh: 1610.6 GB, 1610612736000 bytes, 3145728000 sectors
Disk /dev/vdi: 1610.6 GB, 1610612736000 bytes, 3145728000 sectors
Disk /dev/vdj: 1610.6 GB, 1610612736000 bytes, 3145728000 sectors

Disk /dev/mapper/ol-root: 1064.1 GB, 1064073953280 bytes, 2078269440 sectors
Disk /dev/mapper/ol-swap: 34.4 GB, 34359738368 bytes, 67108864 sectors

[root@rac01 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
vdf         251:80   0     2T  0 disk
vdd         251:48   0   100G  0 disk
vdb         251:16   0   100G  0 disk
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
vde         251:64   0     2T  0 disk
vdc         251:32   0   100G  0 disk
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk

[root@rac01 ~]# oracleasm createdisk DATA01 /dev/vdb
Device "/dev/vdb" is not a partition


[root@rac01 ~]# fdisk /dev/vdb
[root@rac01 ~]# fdisk /dev/vdc
[root@rac01 ~]# fdisk /dev/vdd

[root@rac01 ~]# fdisk /dev/vde
Welcome to fdisk (util-linux 2.23.2).

Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table
Building a new DOS disklabel with disk identifier 0xb59a7a8a.

Command (m for help): m
Command action
   a   toggle a bootable flag
   b   edit bsd disklabel
   c   toggle the dos compatibility flag
   d   delete a partition
   g   create a new empty GPT partition table
   G   create an IRIX (SGI) partition table
   l   list known partition types
   m   print this menu
   n   add a new partition
   o   create a new empty DOS partition table
   p   print the partition table
   q   quit without saving changes
   s   create a new empty Sun disklabel
   t   change a partition's system id
   u   change display/entry units
   v   verify the partition table
   w   write table to disk and exit
   x   extra functionality (experts only)

Command (m for help): n
Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p): p
Partition number (1-4, default 1): 1
First sector (2048-4194303999, default 2048):
Using default value 2048
Last sector, +sectors or +size{K,M,G} (2048-4194303999, default 4194303999):
Using default value 4194303999
Partition 1 of type Linux and of size 2 TiB is set

Command (m for help): w
The partition table has been altered!

Calling ioctl() to re-read partition table.
Syncing disks.


[root@rac01 ~]# fdisk /dev/vdf
[root@rac01 ~]# fdisk /dev/vdg

[root@rac01 ~]# fdisk /dev/vdh
[root@rac01 ~]# fdisk /dev/vdi
[root@rac01 ~]# fdisk /dev/vdj

[root@rac01 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
vdh         251:112  0   1.5T  0 disk
└─vdh1      251:113  0   1.5T  0 part
vdf         251:80   0     2T  0 disk
└─vdf1      251:81   0     2T  0 part
vdd         251:48   0   100G  0 disk
└─vdd1      251:49   0   100G  0 part
vdb         251:16   0   100G  0 disk
└─vdb1      251:17   0   100G  0 part
sr2          11:2    1  1024M  0 rom
sr0          11:0    1   4.5G  0 rom
vdi         251:128  0   1.5T  0 disk
└─vdi1      251:129  0   1.5T  0 part
fd0           2:0    1     4K  0 disk
vdg         251:96   0     2T  0 disk
└─vdg1      251:97   0     2T  0 part
vde         251:64   0     2T  0 disk
└─vde1      251:65   0     2T  0 part
vdc         251:32   0   100G  0 disk
└─vdc1      251:33   0   100G  0 part
vda         251:0    0     1T  0 disk
├─vda2      251:2    0  1023G  0 part
│ ├─ol-swap 252:1    0    32G  0 lvm  [SWAP]
│ └─ol-root 252:0    0   991G  0 lvm  /
└─vda1      251:1    0     1G  0 part /boot
sr1          11:1    1 320.9M  0 rom
vdj         251:144  0   1.5T  0 disk
└─vdj1      251:145  0   1.5T  0 part

[root@rac01 dev]# oracleasm createdisk data01 /dev/vde1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk data02 /dev/vdf1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk data03 /dev/vdg1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]#
[root@rac01 dev]# oracleasm createdisk fra01 /dev/vdh1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk fra02 /dev/vdi1
Writing disk header: done
Instantiating disk: done
[root@rac01 dev]# oracleasm createdisk fra03 /dev/vdj1
Writing disk header: done
Instantiating disk: done

[root@rac01 dev]# oracleasm listdisks
DATA01
DATA02
DATA03
FRA01
FRA02
FRA03
OCR1
OCR2
OCR3


[root@rac01 ~]# cd /dev/oracleasm/disks/
[root@rac01 disks]# ls -lrth
total 0
brw-rw---- 1 grid asmadmin 251,  49 Sep 25 12:06 OCR3
brw-rw---- 1 grid asmadmin 251,  33 Sep 25 12:06 OCR2
brw-rw---- 1 grid asmadmin 251,  17 Sep 25 12:06 OCR1
brw-rw---- 1 grid asmadmin 251,  97 Sep 25 13:53 DATA03
brw-rw---- 1 grid asmadmin 251,  81 Sep 25 13:53 DATA02
brw-rw---- 1 grid asmadmin 251,  65 Sep 25 13:53 DATA01
brw-rw---- 1 grid asmadmin 251, 113 Sep 25 13:54 FRA01
brw-rw---- 1 grid asmadmin 251, 129 Sep 25 13:54 FRA02
brw-rw---- 1 grid asmadmin 251, 145 Sep 25 13:54 FRA03

[root@rac01 ~]#  oracleasm querydisk -p OCR1
Disk "OCR1" is a valid ASM disk
/dev/vdb1: LABEL="OCR1" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p OCR2
Disk "OCR2" is a valid ASM disk
/dev/vdc1: LABEL="OCR2" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p OCR3
Disk "OCR3" is a valid ASM disk
/dev/vdd1: LABEL="OCR3" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p DATA01
Disk "DATA01" is a valid ASM disk
/dev/vde1: LABEL="DATA01" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p DATA02
Disk "DATA02" is a valid ASM disk
/dev/vdf1: LABEL="DATA02" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p DATA03
Disk "DATA03" is a valid ASM disk
/dev/vdg1: LABEL="DATA03" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p FRA01
Disk "FRA01" is a valid ASM disk
/dev/vdh1: LABEL="FRA01" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p FRA02
Disk "FRA02" is a valid ASM disk
/dev/vdi1: LABEL="FRA02" TYPE="oracleasm"
[root@rac01 ~]#  oracleasm querydisk -p FRA03
Disk "FRA03" is a valid ASM disk
/dev/vdj1: LABEL="FRA03" TYPE="oracleasm"

[root@rac01 ~]# tail -f /var/log/message
Sep 25 14:13:32 rac01 kernel: blk_update_request: I/O error, dev fd0, sector 0 op 0x0:(READ) flags 0x0 phys_seg 1 prio class 0
Sep 25 14:13:32 rac01 kernel: floppy: error 10 while reading block 0
Sep 25 14:20:01 rac01 systemd: Started Session 18 of user root.


[root@rac01 ~]# lsmod | grep -i floppy
floppy                 81920  0

[root@rac01 log]# modprobe -r floppy

[root@rac01 log]# vi /etc/modprobe.d/fd-blacklist.conf
blacklist floppy

[root@rac01 log]# reboot -n

--------------

[root@rac02 ~]# oracleasm scandisks
Reloading disk partitions: done
Cleaning any stale ASM disks...
Scanning system for ASM disks...

Instantiating disk "OCR1"
Instantiating disk "OCR2"
Instantiating disk "OCR3"
Instantiating disk "DATA01"
Instantiating disk "DATA02"
Instantiating disk "DATA03"
Instantiating disk "FRA01"
Instantiating disk "FRA02"
Instantiating disk "FRA03"

[root@rac02 ~]# oracleasm listdisks
DATA01
DATA02
DATA03
FRA01
FRA02
FRA03
OCR1
OCR2
OCR3

[root@rac02 ~]# cd /dev/oracleasm/disks/
[root@rac02 disks]# ls -lrth
total 0
brw-rw---- 1 grid asmadmin 251,  49 Sep 25 12:06 OCR3
brw-rw---- 1 grid asmadmin 251,  33 Sep 25 12:06 OCR2
brw-rw---- 1 grid asmadmin 251,  17 Sep 25 12:06 OCR1
brw-rw---- 1 grid asmadmin 251, 145 Sep 25 14:06 FRA03
brw-rw---- 1 grid asmadmin 251, 129 Sep 25 14:06 FRA02
brw-rw---- 1 grid asmadmin 251, 113 Sep 25 14:06 FRA01
brw-rw---- 1 grid asmadmin 251,  97 Sep 25 14:06 DATA03
brw-rw---- 1 grid asmadmin 251,  81 Sep 25 14:06 DATA02
brw-rw---- 1 grid asmadmin 251,  65 Sep 25 14:06 DATA01

[root@rac02 ~]#  oracleasm querydisk -p OCR1
Disk "OCR1" is a valid ASM disk
/dev/vdb1: LABEL="OCR1" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p OCR2
Disk "OCR2" is a valid ASM disk
/dev/vdc1: LABEL="OCR2" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p OCR3
Disk "OCR3" is a valid ASM disk
/dev/vdd1: LABEL="OCR3" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p DATA01
Disk "DATA01" is a valid ASM disk
/dev/vde1: LABEL="DATA01" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p DATA02
Disk "DATA02" is a valid ASM disk
/dev/vdf1: LABEL="DATA02" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p DATA03
Disk "DATA03" is a valid ASM disk
/dev/vdg1: LABEL="DATA03" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p FRA01
Disk "FRA01" is a valid ASM disk
/dev/vdh1: LABEL="FRA01" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p FRA02
Disk "FRA02" is a valid ASM disk
/dev/vdi1: LABEL="FRA02" TYPE="oracleasm"
[root@rac02 ~]#  oracleasm querydisk -p FRA03
Disk "FRA03" is a valid ASM disk
/dev/vdj1: LABEL="FRA03" TYPE="oracleasm"


```





#其他正常学校的配置步骤---本次使用

```bash
[root@k8s-19rac01 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sde: 104857600
/dev/sdf: 104857600
/dev/sdg: 209715200
total: 932179968 blocks
[root@k8s-19rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
[root@k8s-19rac01 ~]#


[root@k8s-19rac02 ~]# sfdisk -s
/dev/vda: 125829120
/dev/mapper/ol-root:  91222016
/dev/mapper/ol-swap:  33554432
/dev/sdf: 104857600
/dev/sdb:  52428800
/dev/sda:  52428800
/dev/sdc:  52428800
/dev/sdd: 104857600
/dev/sdg: 209715200
/dev/sde: 104857600
total: 932179968 blocks
[root@k8s-19rac02 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
/dev/sdf 360000000000000000e00000000010006
/dev/sdg 360000000000000000e00000000010007
[root@k8s-19rac02 ~]#

```

#uuid不变，可以采用方法一

#99-oracle-asmdevices.rules

```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sda", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010001", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdb", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010002", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdc", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010003", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdd", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010004", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sde", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010005", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdf", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010006", OWNER="grid",GROUP="asmadmin", MODE="0660"
KERNEL=="sdg", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$name",RESULT=="360000000000000000e00000000010007", OWNER="grid",GROUP="asmadmin", MODE="0660"
EOF
```


#如果暂时没法绑定uuid到具体盘符

#采用方法二

#防止不同机器在重启后，iscsi共享磁盘的顺序不一致

```bash
[root@k8s-19rac01 ~]# ls -1cv /dev/sd* | grep -v [0-9] | while read disk; do  echo -n "$disk " ; /usr/lib/udev/scsi_id -g -u -d $disk ; done
/dev/sda 360000000000000000e00000000010001
/dev/sdb 360000000000000000e00000000010002
/dev/sdc 360000000000000000e00000000010003
/dev/sdd 360000000000000000e00000000010004
/dev/sde 360000000000000000e00000000010005
```



```bash
cat >> /etc/udev/rules.d/99-oracle-asmdevices.rules <<'EOF'
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="360000000000000000e00000000010004", SYMLINK+="oracleasm/disks/DATA01", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="360000000000000000e00000000010005", SYMLINK+="oracleasm/disks/FRA01", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="360000000000000000e00000000010001", SYMLINK+="oracleasm/disks/OCR01", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="360000000000000000e00000000010002", SYMLINK+="oracleasm/disks/OCR02", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="360000000000000000e00000000010003", SYMLINK+="oracleasm/disks/OCR03", OWNER="grid", GROUP="asmadmin", MODE="0660"
EOF

```



#启动udev

```bash
/usr/sbin/partprobe

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service
```
#检查asm磁盘

#采用方法一时

```bash
ll /dev|grep asm
```
#显示如下
```
[root@k8s-19rac01 ~]# ll /dev|grep asm
brw-rw----  1 grid asmadmin   8,   0 Nov 17 19:04 sda
brw-rw----  1 grid asmadmin   8,  16 Nov 17 19:04 sdb
brw-rw----  1 grid asmadmin   8,  32 Nov 17 19:04 sdc
brw-rw----  1 grid asmadmin   8,  48 Nov 17 19:04 sdd
brw-rw----  1 grid asmadmin   8,  64 Nov 17 19:04 sde
brw-rw----  1 grid asmadmin   8,  80 Nov 17 19:04 sdf
brw-rw----  1 grid asmadmin   8,  96 Nov 17 19:04 sdg
```



#采用方法二时

```bash
ll /dev/oracleasm/disks/

ll /dev/|grep asm
```



#显示如下

```bash
[root@k8s-19rac01 ~]# ll /dev/oracleasm/disks/
total 0
lrwxrwxrwx 1 root root 9 Mar 28 11:43 DATA01 -> ../../sdd
lrwxrwxrwx 1 root root 9 Mar 28 11:43 FRA01 -> ../../sde
lrwxrwxrwx 1 root root 9 Mar 28 11:43 OCR01 -> ../../sda
lrwxrwxrwx 1 root root 9 Mar 28 11:43 OCR02 -> ../../sdb
lrwxrwxrwx 1 root root 9 Mar 28 11:43 OCR03 -> ../../sdc
[root@k8s-19rac01 ~]# ll /dev/|grep asm
drwxr-xr-x  3 root root           60 Mar 28 11:43 oracleasm
brw-rw----  1 grid asmadmin   8,   0 Mar 28 11:43 sda
brw-rw----  1 grid asmadmin   8,  16 Mar 28 11:43 sdb
brw-rw----  1 grid asmadmin   8,  32 Mar 28 11:43 sdc
brw-rw----  1 grid asmadmin   8,  48 Mar 28 11:43 sdd
brw-rw----  1 grid asmadmin   8,  64 Mar 28 11:43 sde
[root@k8s-19rac01 ~]# 

```



#### 2.9.2.多路径模式--无

#适用于物理服务器、广交、存储多路跳线连接

#存储uuid
```
以下是oracle 卷的序列号，请按照这个顺序使用，跟存储上的名称才能对应。
data1(2TB): 2d96d1c2c86f4f6d26c9ce90079a4df08
/dev/sdf  /dev/sdm  /dev/sdt  /dev/sdaa
data2(2TB): 2086fa4c938d839c66c9ce90079a4df08
/dev/sdg  /dev/sdn  /dev/sdu  /dev/sdab
data3(2TB): 27b44daa76accbc526c9ce90079a4df08
/dev/sdh  /dev/sdao  /dev/sdv  /dev/sdac
FRA(2TB): 2f8505ff366f3732a6c9ce900b6fab6bc
/dev/sdi  /dev/sdp  /dev/sdw  /dev/sdad
OCR1(100GB): 24c740a67e89393fa6c9ce90079a4df08
/dev/sdc   /dev/sdj  /dev/sdq  /dev/sdx
OCR2(100GB): 2bf57071b2488dae06c9ce90079a4df08
/dev/sdd  /dev/sdk  /dev/sdr  /dev/sdy
OCR3(100GB): 2ee6c414e797cb16f6c9ce90079a4df08
/dev/sde  /dev/sdl  /dev/sds  /dev/sdz
```
#通过scsi_id检查
```
[root@rac01 ~]# sfdisk -s
/dev/sda: 468818776
/dev/sdc: 104857600
/dev/sdd: 104857600
/dev/sde: 104857600
/dev/sdf: 2147483648
/dev/sdg: 2147483648
/dev/sdh: 2147483648
/dev/sdi: 2147483648
/dev/mapper/centos-root: 419430400
/dev/sdj: 104857600
/dev/mapper/centos-swap:  33554432
/dev/sdk: 104857600
/dev/sdl: 104857600
/dev/sdm: 2147483648
/dev/sdn: 2147483648
/dev/sdo: 2147483648
/dev/sdp: 2147483648
/dev/mapper/mpatha: 104857600
/dev/mapper/mpathb: 104857600
/dev/mapper/mpathc: 104857600
/dev/mapper/mpathd: 2147483648
/dev/mapper/mpathe: 2147483648
/dev/mapper/mpathf: 2147483648
/dev/mapper/mpathg: 2147483648
/dev/sdq: 104857600
/dev/sdr: 104857600
/dev/sds: 104857600
/dev/sdt: 2147483648
/dev/sdu: 2147483648
/dev/sdv: 2147483648
/dev/sdw: 2147483648
/dev/sdx: 104857600
/dev/sdy: 104857600
/dev/sdz: 104857600
/dev/sdaa: 2147483648
/dev/sdab: 2147483648
/dev/sdac: 2147483648
/dev/sdad: 2147483648
/dev/loop0:   4601856
total: 45448942424 blocks

[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdc
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdd
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sde
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdg
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdh
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdi
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdj
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdk
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdl
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdm
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdn
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdo
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdp
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdq
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdr
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sds
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdt
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdu
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdv
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdw
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdx
24c740a67e89393fa6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdy
2bf57071b2488dae06c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdz
2ee6c414e797cb16f6c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdaa
2d96d1c2c86f4f6d26c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdab
2086fa4c938d839c66c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdac
27b44daa76accbc526c9ce90079a4df08
[root@rac01 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdad
2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]#

#通过循环来获取
for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4

[root@rac01 ~]# for i in `cat /proc/partitions |awk {'print $4'} |grep sd`; do echo "Device: $i WWID: `/usr/lib/udev/scsi_id --page=0x83 --whitelisted --device=/dev/$i` "; done |sort -k4
Device: sdab WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdg WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdn WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdu WWID: 2086fa4c938d839c66c9ce90079a4df08
Device: sdc WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdj WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdq WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdx WWID: 24c740a67e89393fa6c9ce90079a4df08
Device: sdac WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdh WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdo WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdv WWID: 27b44daa76accbc526c9ce90079a4df08
Device: sdad WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdi WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdp WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdw WWID: 2aa67dbb0c9c0573b6c9ce90079a4df08
Device: sdd WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdk WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdr WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdy WWID: 2bf57071b2488dae06c9ce90079a4df08
Device: sdaa WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sdf WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sdm WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sdt WWID: 2d96d1c2c86f4f6d26c9ce90079a4df08
Device: sde WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sdl WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sds WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sdz WWID: 2ee6c414e797cb16f6c9ce90079a4df08
Device: sda1 WWID: 3600508b1001c18a54136918e59858bef
Device: sda2 WWID: 3600508b1001c18a54136918e59858bef
Device: sda3 WWID: 3600508b1001c18a54136918e59858bef
Device: sda WWID: 3600508b1001c18a54136918e59858bef

[root@rac01 ~]# lsscsi -i
[0:0:0:0]    disk    Generic- SD/MMC CRW       1.00  /dev/sdb   Generic-_SD_MMC_CRW_29203008282014000-0:0
[1:0:0:0]    disk    Nimble   Server           1.0   /dev/sdc   24c740a67e89393fa6c9ce90079a4df08
[1:0:0:1]    disk    Nimble   Server           1.0   /dev/sdd   2bf57071b2488dae06c9ce90079a4df08
[1:0:0:2]    disk    Nimble   Server           1.0   /dev/sde   2ee6c414e797cb16f6c9ce90079a4df08
[1:0:0:3]    disk    Nimble   Server           1.0   /dev/sdf   2d96d1c2c86f4f6d26c9ce90079a4df08
[1:0:0:4]    disk    Nimble   Server           1.0   /dev/sdg   2086fa4c938d839c66c9ce90079a4df08
[1:0:0:5]    disk    Nimble   Server           1.0   /dev/sdh   27b44daa76accbc526c9ce90079a4df08
[1:0:0:6]    disk    Nimble   Server           1.0   /dev/sdi   2aa67dbb0c9c0573b6c9ce90079a4df08
[1:0:1:0]    disk    Nimble   Server           1.0   /dev/sdj   24c740a67e89393fa6c9ce90079a4df08
[1:0:1:1]    disk    Nimble   Server           1.0   /dev/sdk   2bf57071b2488dae06c9ce90079a4df08
[1:0:1:2]    disk    Nimble   Server           1.0   /dev/sdl   2ee6c414e797cb16f6c9ce90079a4df08
[1:0:1:3]    disk    Nimble   Server           1.0   /dev/sdm   2d96d1c2c86f4f6d26c9ce90079a4df08
[1:0:1:4]    disk    Nimble   Server           1.0   /dev/sdn   2086fa4c938d839c66c9ce90079a4df08
[1:0:1:5]    disk    Nimble   Server           1.0   /dev/sdo   27b44daa76accbc526c9ce90079a4df08
[1:0:1:6]    disk    Nimble   Server           1.0   /dev/sdp   2aa67dbb0c9c0573b6c9ce90079a4df08
[2:0:0:0]    enclosu HPE      Smart Adapter    3.53  -          -
[2:1:0:0]    disk    HPE      LOGICAL VOLUME   3.53  /dev/sda   3600508b1001c18a54136918e59858bef
[2:2:0:0]    storage HPE      P408i-a SR Gen10 3.53  -          -
[3:0:0:0]    disk    Nimble   Server           1.0   /dev/sdq   24c740a67e89393fa6c9ce90079a4df08
[3:0:0:1]    disk    Nimble   Server           1.0   /dev/sdr   2bf57071b2488dae06c9ce90079a4df08
[3:0:0:2]    disk    Nimble   Server           1.0   /dev/sds   2ee6c414e797cb16f6c9ce90079a4df08
[3:0:0:3]    disk    Nimble   Server           1.0   /dev/sdt   2d96d1c2c86f4f6d26c9ce90079a4df08
[3:0:0:4]    disk    Nimble   Server           1.0   /dev/sdu   2086fa4c938d839c66c9ce90079a4df08
[3:0:0:5]    disk    Nimble   Server           1.0   /dev/sdv   27b44daa76accbc526c9ce90079a4df08
[3:0:0:6]    disk    Nimble   Server           1.0   /dev/sdw   2aa67dbb0c9c0573b6c9ce90079a4df08
[3:0:1:0]    disk    Nimble   Server           1.0   /dev/sdx   24c740a67e89393fa6c9ce90079a4df08
[3:0:1:1]    disk    Nimble   Server           1.0   /dev/sdy   2bf57071b2488dae06c9ce90079a4df08
[3:0:1:2]    disk    Nimble   Server           1.0   /dev/sdz   2ee6c414e797cb16f6c9ce90079a4df08
[3:0:1:3]    disk    Nimble   Server           1.0   /dev/sdaa  2d96d1c2c86f4f6d26c9ce90079a4df08
[3:0:1:4]    disk    Nimble   Server           1.0   /dev/sdab  2086fa4c938d839c66c9ce90079a4df08
[3:0:1:5]    disk    Nimble   Server           1.0   /dev/sdac  27b44daa76accbc526c9ce90079a4df08
[3:0:1:6]    disk    Nimble   Server           1.0   /dev/sdad  2aa67dbb0c9c0573b6c9ce90079a4df08
[root@rac01 ~]#
```

#配置多路径配置
```bash
rpm -qa|grep device-mapper-multipath
yum install device-mapper-multipath
systemctl enable multipathd

cat >> /etc/multipath.conf  <<EOF
blacklist {
}
multipaths {
    multipath {
            wwid                    24c740a67e89393fa6c9ce90079a4df08
            alias                   mpatha
    }
    multipath {
            wwid                    2bf57071b2488dae06c9ce90079a4df08
            alias                   mpathb
    }
    multipath {
            wwid                    2ee6c414e797cb16f6c9ce90079a4df08
            alias                   mpathc
    }
    multipath {
            wwid                    2d96d1c2c86f4f6d26c9ce90079a4df08
            alias                   mpathd
    }
    multipath {
            wwid                    2086fa4c938d839c66c9ce90079a4df08
            alias                   mpathe
    }
    multipath {
            wwid                    27b44daa76accbc526c9ce90079a4df08
            alias                   mpathf
    }
    multipath {
            wwid                    2aa67dbb0c9c0573b6c9ce90079a4df08
            alias                   mpathg
    }
}
EOF


cat >> /etc/udev/rules.d/12-dm-permissions.rules <<'EOF'
ENV{DM_NAME}=="ocr1",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="ocr2",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="ocr3",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data1",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data2",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data3",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="data4",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
ENV{DM_NAME}=="fra",OWNER:="grid",GROUP:="asmadmin",MODE:="660"
EOF


systemctl restart multipathd

systemctl status multipathd

multipath -ll

/sbin/udevadm trigger --type=devices --action=change

ll /dev|grep asm

=============
[root@DTMysql1 mysql]# multipath -ll
mpatha (360002ac0000000000000000300021f88) dm-2 3PARdata,VV
size=800G features='1 queue_if_no_path' hwhandler='1 alua' wp=rw
`-+- policy='service-time 0' prio=50 status=active
  |- 13:0:0:0 sdb 8:16 active ready running
  |- 13:0:1:0 sdc 8:32 active ready running
  |- 14:0:0:0 sdd 8:48 active ready running
  `- 14:0:1:0 sde 8:64 active ready running

[root@DTMysql1 mysql]# ls /sys/class/fc_host/
host13  host14
[root@DTMysql1 mysql]# ls /sys/class/scsi_
scsi_device/  scsi_disk/    scsi_generic/ scsi_host/    
[root@DTMysql1 mysql]# ls /sys/class/scsi_host/
host0  host1  host10  host11  host12  host13  host14  host15  host2  host3  host4  host5  host6  host7  host8  host9

[root@DTMysql1 mysql]# echo "- - -" >/sys/class/scsi_host/host13/scan 
[root@DTMysql1 mysql]# echo "- - -" >/sys/class/scsi_host/host14/scan 

[root@DTMysql1 mysql]# multipath -ll
mpathb (368c83e8100174ef9003837b900000006) dm-4 HUAWEI,XSG1
size=5.0T features='1 queue_if_no_path' hwhandler='0' wp=rw
`-+- policy='service-time 0' prio=1 status=active
  |- 13:0:2:1 sdf 8:80  active ready running
  |- 13:0:3:1 sdg 8:96  active ready running
  |- 14:0:2:1 sdh 8:112 active ready running
  `- 14:0:3:1 sdi 8:128 active ready running
mpatha (360002ac0000000000000000300021f88) dm-2 3PARdata,VV
size=800G features='1 queue_if_no_path' hwhandler='1 alua' wp=rw
`-+- policy='service-time 0' prio=50 status=active
  |- 13:0:0:0 sdb 8:16  active ready running
  |- 13:0:1:0 sdc 8:32  active ready running
  |- 14:0:0:0 sdd 8:48  active ready running
  `- 14:0:1:0 sde 8:64  active ready running
[root@DTMysql1 mysql]# vi /etc/multipath.conf
```
### 2.10. 配置互信

```bash
#oracle/
#grid/

#可以用/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh
#仅在节点一root用户下执行

/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh -user grid  -hosts "k8s-19rac01 k8s-19rac02" -advanced exverify -confirm

/u01/app/19.0.0/grid/oui/prov/resources/scripts/sshUserSetup.sh -user grid  -hosts "k8s-19rac01 k8s-19rac02" -advanced exverify -confirm

#也可以用下面的步骤挨个执行
```

#grid用户

```bash
su - grid

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在k8s-19rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh k8s-19rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh k8s-19rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-19rac02:~/.ssh/authorized_keys

ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh  k8s-19rac01 date -Ins;ssh  k8s-19rac02 date -Ins;ssh  k8s-19rac01-prv date -Ins;ssh  k8s-19rac02-prv date -Ins

#在k8s-19rac02执行
ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh  k8s-19rac01 date -Ins;ssh  k8s-19rac02 date -Ins;ssh  k8s-19rac01-prv date -Ins;ssh  k8s-19rac02-prv date -Ins
```
#oracle用户
```bash
su - oracle

cd /home/oracle
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

#以下只在k8s-19rac01执行，逐条执行
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

ssh k8s-19rac02 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh k8s-19rac02 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-19rac02:~/.ssh/authorized_keys

ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh  k8s-19rac01 date -Ins;ssh  k8s-19rac02 date -Ins;ssh  k8s-19rac01-prv date -Ins;ssh  k8s-19rac02-prv date -Ins

#在k8s-19rac02上执行
ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date

ssh  k8s-19rac01 date -Ins;ssh  k8s-19rac02 date -Ins;ssh  k8s-19rac01-prv date -Ins;ssh  k8s-19rac02-prv date -Ins
```



#后面升级openssh后，原来配置的互信失效，重新配置，此时可以再次使用rsa和dsa，也可以使用ecdsa和ed25519，但是必须scp -O

#vi .bashrc

#alias scp="scp -O"

```bash
# Rename the original scp.
mv /usr/bin/scp /usr/bin/scp.orig

# Create a new file </usr/bin/scp>.
vi /usr/bin/scp

# Add the below line to the new created file </usr/bin/scp>.
/usr/bin/scp.orig -T -O $*

# Change the file permission.
chmod 555 /usr/bin/scp

# Begin operation（sush as installation, opatch(auto), CVU and so on）

# After operation
mv /usr/bin/scp.orig /usr/bin/scp
```

#grid用户


```bash
su - grid

cd /home/grid
mv .ssh .ssh.bak
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ecdsa

ssh-keygen -t ed25519

#以下只在oracle01执行，逐条执行
cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

scp -O ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
#在oracle02执行
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
```
#oracle用户


```bash
su - oracle

cd /home/oracle
mv .ssh .ssh.bak
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ecdsa

ssh-keygen -t ed25519

#以下只在oracle01执行，逐条执行
cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys
cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ecdsa.pub >>~/.ssh/authorized_keys

ssh oracle02 cat ~/.ssh/id_ed25519.pub >>~/.ssh/authorized_keys

scp -O ~/.ssh/authorized_keys oracle02:~/.ssh/authorized_keys

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins

#在oracle02上执行
ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date;ssh oracle02 date;ssh oracle01-prv date;ssh oracle02-prv date

ssh oracle01 date -Ins;ssh oracle02 date -Ins;ssh oracle01-prv date -Ins;ssh oracle02-prv date -Ins
```

## 3 开始安装 grid

### 3.1. 上传集群软件包
```bash
#注意不同的用户
[root@rac01 storage]# cd /u01/storage

[root@k8s-19rac01 storage]# ll
total 5809468
-rwxr-xr-x 1 root root 3059705302 Mar 28 16:02 LINUX.X64_193000_db_home.zip
-rwxr-xr-x 1 root root 2889184573 Mar 28 16:03 LINUX.X64_193000_grid_home.zip

[root@k8s-19rac01 storage]# chown grid:oinstall LINUX.X64_193000_grid_home.zip 
[root@k8s-19rac01 storage]# chown oracle:oinstall LINUX.X64_193000_db_home.zip 

[root@k8s-19rac01 storage]# ll -rth
total 5.6G
-rwxr-xr-x 1 oracle oinstall 2.9G Mar 28 16:02 LINUX.X64_193000_db_home.zip
-rwxr-xr-x 1 grid   oinstall 2.7G Mar 28 16:03 LINUX.X64_193000_grid_home.zip
```
### 3.2. 解压 grid 安装包

```bash
#在 19C 中需要把 grid 包解压放到 grid 用户下 ORACLE_HOME 目录内(/u01/app/19.0.0/grid)
#只在节点一上做解压缩
#如果节点二上也做了解压缩，必须全部删除，ls -a , rm -rfv ./* , rm -rfv ./opatch*, rm -rfv ./patch*
[grid@rac01 ~]$ cd /u01/app/19.0.0/grid
[grid@rac01 grid]$ unzip -oq /u01/storage/LINUX.X64_193000_grid_home.zip

#安装cvuqdisk包
cd /u01/app/19.0.0/grid/cv/rpm
cp cvuqdisk-1.0.10-1.rpm /u01
scp cvuqdisk-1.0.10-1.rpm k8s-19rac02:/u01

#两台服务器都安装
su - root
cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm

#节点一安装前检查：
[grid@rac01 ~]$ cd /u01/app/19.0.0/grid/
[grid@rac01 grid]$ ./runcluvfy.sh stage -pre crsinst -n k8s-19rac01,k8s-19rac02 -fixup -verbose|tee -a pre.log

#./runcluvfy.sh stage -pre crsinst -allnodes -fixup -verbose -method root|tee -a pre.log
```

#error检查

#会生成fixup脚本，需在oracle01/oracle02上执行

```
#可以忽略的
ERROR:
PRVG-10467 : The default Oracle Inventory group could not be determined.

Verifying Network Time Protocol (NTP) ...FAILED (PRVG-1017)
Verifying resolv.conf Integrity ...FAILED (PRVG-10048)

#centos7可以忽略：
Verifying /dev/shm mounted as temporary file system ...FAILED (PRVE-0421)
Verifying /dev/shm mounted as temporary file system ...FAILED
rac02: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm

rac01: PRVE-0421 : No entry exists in /etc/fstab for mounting /dev/shm
```


#如果报错以下，可以忽略

```
Check: Package existence for "pdksh" 
  Node Name     Available                 Required                  Status    
  ------------  ------------------------  ------------------------  ----------
  oracle02       missing                   pdksh-5.2.14              failed    
  oracle01       missing                   pdksh-5.2.14              failed    
Result: Package existence check failed for "pdksh"
```
#如果报错以下内容必须处理
```
Checking Core file name pattern consistency...

ERROR:
PRVF-6402 : Core file name pattern is not same on all the nodes.
Found core filename pattern "|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h" on nodes "oracle01".
Found core filename pattern "core.%p" on nodes "oracle02".
Core file name pattern consistency check failed.
```
#解决办法，可以将node1的abrt-hook-ccpp关闭
#查看core_pattern
```bash
[root@oracle01 ~]# more /proc/sys/kernel/core_pattern
|/usr/libexec/abrt-hook-ccpp %s %c %p %u %g %t e %P %I %h
[root@oracle01 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; enabled; vendor preset: enabled)
   Active: active (exited) since Wed 2021-11-03 10:58:38 CST; 1 months 18 days ago
  Process: 806 ExecStart=/usr/sbin/abrt-install-ccpp-hook install (code=exited, status=0/SUCCESS)
 Main PID: 806 (code=exited, status=0/SUCCESS)
    Tasks: 0
   CGroup: /system.slice/abrt-ccpp.service
Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.


[root@oracle02 ~]# more /proc/sys/kernel/core_pattern
core
[root@oracle02 ~]# systemctl status abrt-ccpp.service
Unit abrt-ccpp.service could not be found.
```
#oracle01关闭abrt-ccpp
```bash
systemctl stop abrt-ccpp.service
systemctl disable abrt-ccpp.service
systemctl status abrt-ccpp.service
```
#此时再次runcluvfy即可通过
```
[root@oracle01 ~]# systemctl stop abrt-ccpp.service
[root@oracle01 ~]# systemctl disable abrt-ccpp.service
Removed symlink /etc/systemd/system/multi-user.target.wants/abrt-ccpp.service.
[root@oracle01 ~]# systemctl status abrt-ccpp.service
● abrt-ccpp.service - Install ABRT coredump hook
   Loaded: loaded (/usr/lib/systemd/system/abrt-ccpp.service; disabled; vendor preset: enabled)
   Active: inactive (dead)

Dec 22 14:06:03 oracle01 systemd[1]: Starting Install ABRT coredump hook...
Dec 22 14:06:03 oracle01 systemd[1]: Started Install ABRT coredump hook.
Dec 22 14:47:32 oracle01 systemd[1]: Stopping Install ABRT coredump hook...
Dec 22 14:47:32 oracle01 systemd[1]: Stopped Install ABRT coredump hook.
[root@oracle01 ~]# more /proc/sys/kernel/core_pattern
core

runcluvfy.sh:
Checking Core file name pattern consistency...
Core file name pattern consistency check passed.
```

#安装xterm

```bash
yum install -y xterm*
#如果提示：已拒绝X11转移申请，那么安装xorg-x11-xauth
yum install -y xorg-x11-xauth 
#或者本地镜像需挨着安装包
yum install -y xorg-x11-xkb-utils
rpm -ivh xorg-x11-xkb-utils-7.7-14.el7.x86_64.rpm
rpm -ivh xorg-x11-xauth-1.0.9-1.el7.x86_64.rpm
rpm -ivh xterm-295-3.el7.x86_64.rpm

#本地打开xstart
#用grid账户通过ssh登录
#命令为/usr/bin/xterm -ls -display $DISPLAY
```
### 3.3. 进入 grid 集群软件目录执行安装
```bash
cd /u01/app/19.0.0/grid/
[grid@rac01 grid]$ ./gridSetup.sh
```
### 3.4. GI 安装步骤
#安装过程如下
```
1. 为新的集群配置GI(configure oracle grid infrastructure for a New Cluster)
2. 配置独立的集群(configure an oracle standalone cluster)
3. 配置集群名称以及 scan 名称(rac-cluster/rac-scan/1521)
4. 添加节点2并测试节点互信(Add k8s-19rac02/k8s-19rac02-vip, SSH connectivity--->Test)
5. 公网、私网网段选择(eth1-10.100.100.0-ASM&private/eth0-172.18.0.0-public/eth2-3.3.3.0-Do Not Use)
6. 选择 asm 存储(use oracle flex ASM for storage)
7. 选择不单独为GIMR配置磁盘组(No)
#uuid固定时：8. 选择 asm 磁盘组(ORC/normal/50G三块磁盘/扫描的磁盘路径: /dev/sd*)
#uuid不固定时，走以下配置：/dev/oracleasm/disks/OCR01|OCR02|OCR03
8. 选择 asm 磁盘组(ORC/normal/50G三块磁盘/扫描的磁盘路径: /dev/oracleasm/disks/)
9. 输入密码<SYS_PWD>
10. 保持默认No IPMI
11. 保持默认No EM
12. 默认用户组asmadmin/asmdba/asmoper
13. 确认 base 目录$ORACLE_BASE(/u01/app/grid)
14. Inventory Directory: /u01/app/orainventory
15. 这里可以选择自动 root 执行脚本,不自动执行,不选
16. 预安装检查
    解决相关依赖后，忽略如下报错:
       DNS/NIS name service
    如下警告可以忽略-警告是由于没有使用 DNS 解析造成可忽略
       SCAN
       RPM Package Manager database
       
     [INS-13016]--->yes
17. install
18. 执行 root 脚本.

    先在k8s-19rac01上执行完毕,再去k8s-19rac02执行
    /u01/app/oraInventory/orainstRoot.sh
    /u01/app/19.0.0/grid/root.sh
    
    执行完毕后,点击OK
    INS-20802 oracle cluster verification utility failed--->OK
    --->Next
    INS-43080--->YES
19. Close     
```
#基于asmlib的磁盘选择

#或者uuid不固定时

#/dev/oracleasm/disks/*

![image-20230925160246882](oracle19cRAC-neuq\image-20230925160246882.png)



![image-20230925160428599](oracle19cRAC-neuq\image-20230925160428599.png)



#安装前的忽略

![image-20230925160959650](oracle19cRAC-neuq\image-20230925160959650.png)



#采用uudi不固定时的报错

![image-20250401162917867](oracle19cRacole7threenodes\image-20250401162917867.png)

![image-20250401163117345](oracle19cRacole7threenodes\image-20250401163117345.png)

```error
Device Checks for ASM - This is a prerequisite check to verify that the specified devices meet the requirements for ASM.
  Operation Failed on Nodes: [k8s-19rac02,  k8s-19rac01]  
Verification result of failed node: k8s-19rac02 Back to Top  
Verification result of failed node: k8s-19rac01  Details: 
 - 
PRVG-2043 : Command "/usr/sbin/oracleasm listdisks" failed on node "k8s-19rac01" and produced the following output: sh: /usr/sbin/oracleasm: No such file or directory  - Cause:  An executed command failed.  - Action:  Respond based on the failing command and the reported results. 
 - 
PRVG-10524 : failed to determine whether disk "OCR03" is managed by ASMLib  - Cause:  An attempt to validate whether the indicated disk was managed by ASMLib failed.  - Action:  Ensure that the ASMLib is correctly configured on all the cluster nodes and that the indicated disk is listed by ''oracleasm'' on the Linux operating system platform. 
 - 
PRVG-10524 : failed to determine whether disk "OCR02" is managed by ASMLib  - Cause:  An attempt to validate whether the indicated disk was managed by ASMLib failed.  - Action:  Ensure that the ASMLib is correctly configured on all the cluster nodes and that the indicated disk is listed by ''oracleasm'' on the Linux operating system platform. 
 - 
PRVG-10524 : failed to determine whether disk "OCR01" is managed by ASMLib  - Cause:  An attempt to validate whether the indicated disk was managed by ASMLib failed.  - Action:  Ensure that the ASMLib is correctly configured on all the cluster nodes and that the indicated disk is listed by ''oracleasm'' on the Linux operating system platform. 
Back to Top  
```





#报错处理，安装进度到了5%的时候出现
###以下两个报错均是lib中文件的软链接出现了问题导致的

```
###第一个报错：libclntsh.so报错
INFO:
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libclntsh.so: file format not recognized; treating as linker script
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libclntsh.so:1: syntax error

INFO:
make[2]: *** [dlopenlib] Error 1

INFO:
make[2]: Leaving directory `/u01/app/19.0.0/grid/rdbms/lib'

INFO:
make[1]: Leaving directory `/u01/app/19.0.0/grid/rdbms/lib'

INFO:
make[1]: *** [/u01/app/19.0.0/grid/lib/libasmperl19.so] Error 2

INFO:
make: *** [libasmperl19.ohso] Error 2

INFO: End output from spawned process.
INFO: ----------------------------------
INFO: Exception thrown from action: make
Exception Name: MakefileException
Exception String: Error in invoking target 'libasmclntsh19.ohso libasmperl19.ohso client_sharedlib' of makefile '/u01/app/19.0.0/grid/rdbms/lib/ins_rdbms.mk'. See '/tmp/GridSetupActions2022-10-20_03-47-30PM/gridSetupActions2022-10-20_03-47-30PM.log' for details.
Exception Severity: 1

###第二个报错：libodm19.so
INFO:
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libodm19.so: file format not recognized; treating as linker script
/usr/bin/ld:/u01/app/19.0.0/grid/lib//libodm19.so:1: syntax error

INFO:
make: *** [/u01/app/19.0.0/grid/rdbms/lib/oracle] Error 1

INFO: End output from spawned process.
INFO: ----------------------------------
INFO: Exception thrown from action: make
Exception Name: MakefileException
Exception String: Error in invoking target 'irman ioracle' of makefile '/u01/app/19.0.0/grid/rdbms/lib/ins_rdbms.mk'. See '/tmp/GridSetupActions2022-10-20_03-47-30PM/gridSetupActions2022-10-20_03-47-30PM.log' for details.
Exception Severity: 1
```

#解决办法
```
#通过root账户，将grid文件重新解压缩，可以看到相关的正确软链接文件
cd /u01/app/tmp/
unzip -oq /u01/Storage/LINUX.X64_193000_grid_home.zip
cd lib

[root@rac02 grid]# cd lib/
[root@rac02 lib]# ll|grep ^l
lrwxrwxrwx 1 root root        15 Oct 20 16:00 libagtsh.so -> libagtsh.so.1.0
lrwxrwxrwx 1 root root        21 Oct 20 16:00 libclntshcore.so -> libclntshcore.so.19.1
lrwxrwxrwx 1 root root        17 Oct 20 16:00 libclntsh.so -> libclntsh.so.19.1
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.10.1 -> libclntsh.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.11.1 -> libclntsh.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.12.1 -> libclntsh.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libclntsh.so.18.1 -> libclntsh.so
lrwxrwxrwx 1 root root        36 Oct 20 16:00 libjavavm19.a -> ../javavm/jdk/jdk8/lib/libjavavm19.a
lrwxrwxrwx 1 root root        15 Oct 20 16:00 libocci.so -> libocci.so.19.1
lrwxrwxrwx 1 root root        10 Oct 20 16:00 libocci.so.18.1 -> libocci.so
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libodm19.so -> libodmd19.so


[root@rac02 lib]# ls -l libcln*
lrwxrwxrwx 1 root root       21 Oct 20 16:00 libclntshcore.so -> libclntshcore.so.19.1
-rwxr-xr-x 1 root root  8040416 Apr 18  2019 libclntshcore.so.19.1
lrwxrwxrwx 1 root root       17 Oct 20 16:00 libclntsh.so -> libclntsh.so.19.1
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.10.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.11.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.12.1 -> libclntsh.so
lrwxrwxrwx 1 root root       12 Oct 20 16:00 libclntsh.so.18.1 -> libclntsh.so
-rwxr-xr-x 1 root root 79927312 Apr 18  2019 libclntsh.so.19.1

[root@rac02 lib]# ll|grep libodm
-rw-r--r-- 1 root root     10594 Apr 17  2019 libodm19.a
lrwxrwxrwx 1 root root        12 Oct 20 16:00 libodm19.so -> libodmd19.so
-rw-r--r-- 1 root root     17848 Apr 17  2019 libodmd19.so
[root@rac02 lib]#

-------------------------------------------
#检查grid账户下正常解压缩文件，发现软连接文件成了正常文件，但是大小还是12
cd /u01/app/19.0.0.0/grid/lib
[grid@rac02 lib]$ ll|grep ^l
lrwxrwxrwx  1 grid oinstall        15 Oct 20 16:10 libagtsh.so -> libagtsh.so.1.0
lrwxrwxrwx  1 grid oinstall        10 Oct 20 16:10 libocci.so.18.1 -> libocci.so

[grid@rac02 lib]$ ls -l  libcln*
-rwxr-xr-x. 1 grid oinstall       21 Oct 20 15:16 libclntshcore.so
-rwxr-xr-x. 1 grid oinstall  8040416 Oct 20 15:16 libclntshcore.so.19.1
-rwxr-xr-x. 1 grid oinstall       17 Oct 20 15:16 libclntsh.so
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.10.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.11.1
-rwxr-x---. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.12.1
-rwxr-xr-x. 1 grid oinstall       12 Oct 20 15:16 libclntsh.so.18.1
-rwxr-xr-x. 1 grid oinstall 79927312 Oct 20 15:16 libclntsh.so.19.1

[grid@rac02 lib]$ ls -l|grep libjavavm19
-rwxr-xr-x. 1 grid oinstall        36 Oct 20 15:16 libjavavm19.a
[grid@rac02 lib]$ ls -l|grep libodm
-rw-r--r--. 1 grid oinstall     10594 Oct 20 15:16 libodm19.a
-rwxr-xr-x. 1 grid oinstall        12 Oct 20 15:16 libodm19.so
-rw-r--r--. 1 grid oinstall     17848 Oct 20 15:16 libodmd19.so

#解决办法：
#删除相关报错文件，重新建立软链接，然后在安装图形界面，点击重试即可

rm -rfv libclntshcore.so libclntsh.so libclntsh.so.10.1 libclntsh.so.11.1 libclntsh.so.12.1 libclntsh.so.18.1
ln -s libclntshcore.so.19.1 libclntshcore.so
ln -s libclntsh.so.19.1 libclntsh.so
ln -s libclntsh.so libclntsh.so.10.1
ln -s libclntsh.so libclntsh.so.11.1
ln -s libclntsh.so libclntsh.so.12.1
ln -s libclntsh.so libclntsh.so.18.1

rm -rfv libjavavm19.a libodm19.so
ln -s libodmd19.so libodm19.so
ln -s ../javavm/jdk/jdk8/lib/libjavavm19.a libjavavm19.a
```



#执行root脚本日志如下

```
[root@rac01 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.


[root@rac01 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/rac01/crsconfig/rootcrs_rac01_2022-08-12_11-09-12PM.log
2023/09/25 16:11:12 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2023/09/25 16:11:12 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2023/09/25 16:11:12 CLSRSC-363: User ignored prerequisites during installation
2023/09/25 16:11:12 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2023/09/25 16:11:14 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2023/09/25 16:11:14 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2023/09/25 16:11:15 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2023/09/25 16:11:15 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2023/09/25 16:11:25 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2023/09/25 16:11:28 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2023/09/25 16:11:34 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2023/09/25 16:11:40 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2023/09/25 16:11:40 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2023/09/25 16:11:44 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2023/09/25 16:11:44 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2023/09/25 16:12:05 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2023/09/25 16:12:09 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2023/09/25 16:12:13 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2023/09/25 16:12:17 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.

ASM has been created and started successfully.

[DBT-30001] Disk groups created successfully. Check /u01/app/grid/cfgtoollogs/asmca/asmca-220309PM061249.log for details.

2023/09/25 16:13:35 CLSRSC-482: Running command: '/u01/app/19.0.0/grid/bin/ocrconfig -upgrade grid oinstall'
CRS-4256: Updating the profile
Successful addition of voting disk 963be5e020964f73bfc4e8810d4d2d72.
Successful addition of voting disk 0cad1112ce4a4f21bf7fb68c81659713.
Successful addition of voting disk 37518f8cb4ed4fd5bf79d54a331cec28.
Successfully replaced voting disk group with +OCR.
CRS-4256: Updating the profile
CRS-4266: Voting file(s) successfully replaced
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   963be5e020964f73bfc4e8810d4d2d72 (/dev/dm-2) [OCR]
 2. ONLINE   0cad1112ce4a4f21bf7fb68c81659713 (/dev/dm-3) [OCR]
 3. ONLINE   37518f8cb4ed4fd5bf79d54a331cec28 (/dev/dm-4) [OCR]
Located 3 voting disk(s).
2023/09/25 16:14:58 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2023/09/25 16:16:04 CLSRSC-343: Successfully started Oracle Clusterware stack
2023/09/25 16:16:04 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2023/09/25 16:17:06 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2023/09/25 16:17:27 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded


[root@rac02 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.


[root@rac02 ~]# /u01/app/19.0.0/grid/root.sh
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
  /u01/app/grid/crsdata/rac02/crsconfig/rootcrs_rac02_2022-03-09_06-18-12PM.log
2023/09/25 16:18:15 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2023/09/25 16:18:15 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2023/09/25 16:18:15 CLSRSC-363: User ignored prerequisites during installation
2023/09/25 16:18:15 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2023/09/25 16:18:16 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2023/09/25 16:18:17 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2023/09/25 16:18:17 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2023/09/25 16:18:25 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2023/09/25 16:18:25 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2023/09/25 16:18:26 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2023/09/25 16:18:26 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2023/09/25 16:18:37 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2023/09/25 16:18:44 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2023/09/25 16:18:45 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2023/09/25 16:18:46 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2023/09/25 16:18:47 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2023/09/25 16:18:55 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2023/09/25 16:19:41 CLSRSC-343: Successfully started Oracle Clusterware stack
2023/09/25 16:19:41 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2023/09/25 16:19:50 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2023/09/25 16:19:55 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```
### 3.5.错误处理---oracle linux server不存在这些错误

#### 3.5.1.错误处理执行root.sh时报错缺少libcap.so.1

```
Installing Trace File Analyzer
Failed to create keys in the OLR, rc = 127, Message:
  /u01/app/11.2.0/grid/bin/clscfg.bin: error while loading shared libraries: libcap.so.1: cannot open shared object file: No such file or directory

Failed to create keys in the OLR at /u01/app/11.2.0/grid/crs/install/crsconfig_lib.pm line 7660.
/u01/app/11.2.0/grid/perl/bin/perl -I/u01/app/11.2.0/grid/perl/lib -I/u01/app/11.2.0/grid/crs/install /u01/app/11.2.0/grid/crs/install/rootcrs.pl execution failed

```

#解决办法，oracle01/oracle02都执行

```bash
cd /lib64
ll|grep libcap
ln -s libcap.so.2.22 libcap.so.1
ll|grep libcap
```

#然后oracle01重新执行root.sh

```bash
/u01/app/11.2.0/grid/root.sh
```

#### 3.5.2.执行root.sh报错ohasd failed to start

```
ohasd failed to start
Failed to start the Clusterware. Last 20 lines of the alert log follow:
2021-12-22 16:16:16.536:
[client(23029)]CRS-2101:The OLR was formatted using version 3.
2021-12-22 16:26:16.232:
[client(24751)]CRS-2101:The OLR was formatted using version 3.
```

#因为Centos7使用systemd而不是initd来启动/重新启动进程，并将它们作为服务运行，所以当前的11.2.0.4和12.1.0.1的软件安装不会成功，因为ohasd进程没有正常启动

#解决办法

```
#手动在systemd中添加ohasd服务

touch /usr/lib/systemd/system/ohas.service

#编辑文件ohasd.service添加如下内容

vi   /usr/lib/systemd/system/ohas.service

[Unit]
Description=Oracle High Availability Services
After=syslog.target

[Service]
ExecStart=/etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple
Restart=always

[Install]
WantedBy=multi-user.target

 
#添加和启动服务

systemctl daemon-reload
systemctl enable ohas.service
systemctl start ohas.service

#查看运行状态：

[root@oracle01 init.d]# systemctl status ohas.service
● ohas.service - Oracle High Availability Services
   Loaded: loaded (/usr/lib/systemd/system/ohas.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2022-01-04 11:45:14 CST; 8s ago
 Main PID: 42231 (init.ohasd)
   CGroup: /system.slice/ohas.service
           └─42231 /bin/sh /etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple

Jan 04 11:45:14 oracle01 systemd[1]: Started Oracle High Availability Services.


#此时oracle01的root.sh会继续安装下去，无需重新执行root.sh脚本

#注意： 为了避免其余节点遇到这种报错，可以在root.sh执行过程中，待/etc/init.d/目录下生成了init.ohasd 文件后，执行systemctl start ohas.service 启动ohas服务即可。若没有/etc/init.d/init.ohasd文件 systemctl start ohas.service 则会启动失败。
```

#### 3.5.3.asm及crsd报错CRS-4535: Cannot communicate with Cluster Ready Services

#如果是光纤直连服务器和SAN存储，因OCR检查时间是15s，但是服务器与存储间检查时间是30s，导致asm报错，从而crs整体报错

```bash
[root@oracle01 ~]# cat /sys/block/sdb/device/timeout 
30
[root@oracle01 ~]# sqlplus / as sysasm
```

```oracle
SQL> select name, state from v$asm_diskgroup;

NAME			       STATE
------------------------------ -----------
OCR			       DISMOUNTED

SQL> SELECT   ksppinm, ksppstvl, ksppdesc
   FROM   x$ksppi x, x$ksppcv y
  WHERE   x.indx = y.indx AND  ksppinm = '_asm_hbeatiowait' ;

KSPPINM
--------------------------------------------------------------------------------
KSPPSTVL
--------------------------------------------------------------------------------
KSPPDESC
--------------------------------------------------------------------------------
_asm_hbeatiowait
15
number of secs to wait for PST Async Hbeat IO return
```

#解决办法
#oracle01/oracle02都要修改

```oracle
SQL> select name, state from v$asm_diskgroup;

NAME			       STATE
------------------------------ -----------
OCR			       DISMOUNTED

SQL> alter diskgroup ocr mount;

Diskgroup altered.

SQL> alter system set "_asm_hbeatiowait"=120 scope=spfile sid='*';

System altered.
```

#oracle01/oracle02都要重启crs生效

```bash
crsctl stop crs -f 
crsctl start crs
crsctl enable crs
```

#重启集群后，查看下参数

```oracle
SQL> SELECT   ksppinm, ksppstvl, ksppdesc
   FROM   x$ksppi x, x$ksppcv y
  WHERE   x.indx = y.indx AND  ksppinm = '_asm_hbeatiowait' ;  2    3  

KSPPINM
--------------------------------------------------------------------------------
KSPPSTVL
--------------------------------------------------------------------------------
KSPPDESC
--------------------------------------------------------------------------------
_asm_hbeatiowait
120
number of secs to wait for PST Async Hbeat IO return
```

#报错日志

```
#/u01/app/grid/diag/asm/+asm/+ASM2/trace/alert_+ASM2.log
ue Jan 04 12:57:51 2022
ASM Health Checker found 1 new failures
Tue Jan 04 12:58:03 2022
SUCCESS: diskgroup OCR was dismounted
SUCCESS: alter diskgroup OCR dismount force /* ASM SERVER:238559154 */
SUCCESS: ASM-initiated MANDATORY DISMOUNT of group OCR
Tue Jan 04 12:58:03 2022
NOTE: diskgroup resource ora.OCR.dg is offline
Tue Jan 04 12:58:03 2022
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING: requested mirror side 1 of virtual extent 5 logical extent 0 offset 704512 is not allocated; I/O request failed
WARNING: requested mirror side 2 of virtual extent 5 logical extent 1 offset 704512 is not allocated; I/O request failed
Errors in file /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc:
ORA-15078: ASM diskgroup was forcibly dismounted
ORA-15078: ASM diskgroup was forcibly dismounted
Tue Jan 04 12:58:03 2022
SQL> alter diskgroup OCR check /* proxy */ 
ORA-15032: not all alterations performed
ORA-15001: diskgroup "OCR" does not exist or is not mounted
ERROR: alter diskgroup OCR check /* proxy */

#/u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_ora_12804.trc
*** 2022-01-04 14:09:06.969
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
WARNING:failed xlate 1 
ORA-15078: ASM diskgroup was forcibly dismounted
ksfdrfms:Mirror Read file=+OCR.255.4294967295 fob=0x90c03648 bufp=0x7f5878cb2a00 blkno=1125 nbytes=4096
WARNING:failed xlate 1 
WARNING: requested mirror side 1 of virtual extent 4 logical extent 0 offset 413696 is not allocated; I/O request failed
ksfdrfms:Read failed from mirror side=1 logical extent number=0 dskno=65535
WARNING:failed xlate 1 
WARNING: requested mirror side 2 of virtual extent 4 logical extent 1 offset 413696 is not allocated; I/O request failed
ksfdrfms:Read failed from mirror side=2 logical extent number=1 dskno=65535
ORA-15078: ASM diskgroup was forcibly dismounted
ORA-15078: ASM diskgroup was forcibly dismounted

#/u01/app/11.2.0/grid/log/oracle02/crsd/crsd.log
2022-01-04 12:58:15.154: [ CRSMAIN][859629376] Initializing OCR
[   CLWAL][859629376]clsw_Initialize: OLR initlevel [70000]
2022-01-04 12:58:15.480: [  OCRASM][859629376]proprasmo: Error in open/create file in dg [OCR]
[  OCRASM][859629376]SLOS : SLOS: cat=8, opn=kgfoOpen01, dep=15056, loc=kgfokge

2022-01-04 12:58:15.480: [  OCRASM][859629376]ASM Error Stack :
2022-01-04 12:58:15.512: [  OCRASM][859629376]proprasmo: kgfoCheckMount returned [6]
2022-01-04 12:58:15.512: [  OCRASM][859629376]proprasmo: The ASM disk group OCR is not found or not mounted
2022-01-04 12:58:15.513: [  OCRRAW][859629376]proprioo: Failed to open [+OCR]. Returned proprasmo() with [26]. Marking location as UNAVAILABLE.
2022-01-04 12:58:15.513: [  OCRRAW][859629376]proprioo: No OCR/OLR devices are usable
2022-01-04 12:58:15.513: [  OCRASM][859629376]proprasmcl: asmhandle is NULL
2022-01-04 12:58:15.513: [    GIPC][859629376] gipcCheckInitialization: possible incompatible non-threaded init from [prom.c : 690], original from [clsss.c : 5343]
2022-01-04 12:58:15.514: [ default][859629376]clsvactversion:4: Retrieving Active Version from local storage.
2022-01-04 12:58:15.516: [ CSSCLNT][859629376]clssgsgrppubdata: group (ocr_rac-scan) not found

2022-01-04 12:58:15.516: [  OCRRAW][859629376]proprio_repairconf: Failed to retrieve the group public data. CSS ret code [20]
2022-01-04 12:58:15.517: [  OCRRAW][859629376]proprioo: Failed to auto repair the OCR configuration.
2022-01-04 12:58:15.517: [  OCRRAW][859629376]proprinit: Could not open raw device
2022-01-04 12:58:15.517: [  OCRASM][859629376]proprasmcl: asmhandle is NULL
2022-01-04 12:58:15.519: [  OCRAPI][859629376]a_init:16!: Backend init unsuccessful : [26]
2022-01-04 12:58:15.519: [  CRSOCR][859629376] OCR context init failure.  Error: PROC-26: Error while accessing the physical storage

2022-01-04 12:58:15.519: [    CRSD][859629376] Created alert : (:CRSD00111:) :  Could not init OCR, error: PROC-26: Error while accessing the physical storage

2022-01-04 12:58:15.519: [    CRSD][859629376][PANIC] CRSD exiting: Could not init OCR, code: 26
2022-01-04 12:58:15.519: [    CRSD][859629376] Done.
```

#### 3.5.4.添加listener---grid用户

#上面错误解决后，发现集群缺少listener

```
[grid@oracle01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       oracle02                                     
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle02                             
      
[root@oracle02 ~]# lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 04-JAN-2022 16:54:49

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 111: Connection refused
[root@oracle02 ~]# su - grid
Last login: Tue Jan  4 14:06:57 CST 2022 on pts/0
[grid@oracle02 ~]$ srvctl config listener
PRCN-2044 : No listener exists
```

#尝试添加

```bash
[grid@oracle02 ~]$ srvctl add listener -l listener -p 1521 
PRCN-2061 : Failed to add listener ora.LISTENER.lsnr
PRCN-2065 : Port(s) 1521 are not available on the nodes given
PRCN-2067 : Port 1521 is not available across node(s) "oracle01-vip"

#先停止oracle01-vip和oracle02-vip
crsctl stop resource ora.oracle01.vip
crsctl stop resource ora.oracle01.vip
#检查是否有listener的残留进程
ps -ef|grep tns
#如果有以下类似进程，需kill掉，不然会存在Not All Endpoints Registered的问题
grid     17769     1  0 18:53 ?        00:00:00 /u01/app/11.2.0/grid/bin/tnslsnr LISTENER -inherit

kill -9 17769

#开始添加监听
srvctl add listener -l listener
srvctl config listener
srvctl start listener -l listener

crsctl status resource -t
```

#如果还存在问题，可以尝试重启集群解决

```bash
crsctl stop cluster -all

crsctl start cluster -all
```

#日志

```
[grid@oracle02 admin]$ srvctl stop scan_listener

[grid@oracle02 admin]$ srvctl add listener -l listener
PRCN-2061 : Failed to add listener ora.LISTENER.lsnr
PRCN-2065 : Port(s) 1521 are not available on the nodes given
PRCN-2067 : Port 1521 is not available across node(s) "oracle01-vip"

[grid@oracle02 admin]$ crsctl stop resource ora.oracle01.vip
CRS-2673: Attempting to stop 'ora.oracle01.vip' on 'oracle01'
CRS-2677: Stop of 'ora.oracle01.vip' on 'oracle01' succeeded

[grid@oracle02 admin]$ crsctl stop resource ora.oracle02.vip
CRS-2673: Attempting to stop 'ora.oracle02.vip' on 'oracle02'
CRS-2677: Stop of 'ora.oracle02.vip' on 'oracle02' succeeded

[grid@oracle02 admin]$ srvctl add listener -l listener

[grid@oracle02 admin]$ srvctl config listener
Name: LISTENER
Network: 1, Owner: grid
Home: <CRS home>
End points: TCP:1521

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------                              
ora.LISTENER.lsnr
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        OFFLINE OFFLINE                                                   
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        OFFLINE OFFLINE                                                   
ora.oracle02.vip
      1        OFFLINE OFFLINE                                                   
ora.scan1.vip
      1        ONLINE  ONLINE       oracle02                                     
[grid@oracle02 admin]$ srvctl start listener -l listener

[grid@oracle02 admin]$ crsctl start resource ora.oracle02.vip
CRS-5702: Resource 'ora.oracle02.vip' is already running on 'oracle02'
CRS-4000: Command Start failed, or completed with errors.

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE oracle01                 Not All Endpoints Registered           
               ONLINE  ONLINE       oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        OFFLINE OFFLINE                                                   
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle02                                     
[grid@oracle02 admin]$ crsctl status resource ora.LISTENER_SCAN1.lsnr
NAME=ora.LISTENER_SCAN1.lsnr
TYPE=ora.scan_listener.type
TARGET=OFFLINE
STATE=OFFLINE

[grid@oracle02 admin]$ srvctl start scan_listener

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE oracle01                 Not All Endpoints Registered           
               ONLINE  ONLINE       oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  INTERMEDIATE oracle01                 Not All Endpoints R 
                                                             egistered           
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01                                     
[grid@oracle02 admin]$ srvctl start scan_listener
PRCC-1014 : LISTENER_SCAN1 was already running
PRCR-1004 : Resource ora.LISTENER_SCAN1.lsnr is already running
PRCR-1079 : Failed to start resource ora.LISTENER_SCAN1.lsnr
CRS-5702: Resource 'ora.LISTENER_SCAN1.lsnr' is already running on 'oracle01'

[grid@oracle02 admin]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  INTERMEDIATE oracle01                 Not All Endpoints R 
                                                             egistered           
               ONLINE  ONLINE       oracle02                                     
ora.OCR.dg
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.asm
               ONLINE  ONLINE       oracle01                 Started             
               ONLINE  ONLINE       oracle02                 Started             
ora.gsd
               OFFLINE OFFLINE      oracle01                                     
               OFFLINE OFFLINE      oracle02                                     
ora.net1.network
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
ora.ons
               ONLINE  ONLINE       oracle01                                     
               ONLINE  ONLINE       oracle02                                     
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  INTERMEDIATE oracle01                 Not All Endpoints R 
                                                             egistered           
ora.cvu
      1        ONLINE  ONLINE       oracle02                                     
ora.oc4j
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle01.vip
      1        ONLINE  ONLINE       oracle01                                     
ora.oracle02.vip
      1        ONLINE  ONLINE       oracle02                                     
ora.scan1.vip
      1        ONLINE  ONLINE       oracle01                                     

[root@oracle02 ~]# . oraenv
ORACLE_SID = [+ASM2] ? 
The Oracle base remains unchanged with value /u01/app/grid
[root@oracle02 ~]# crsctl stop cluster -all
CRS-2673: Attempting to stop 'ora.crsd' on 'oracle02'
CRS-2673: Attempting to stop 'ora.crsd' on 'oracle01'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'oracle01'
CRS-2673: Attempting to stop 'ora.oc4j' on 'oracle01'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'oracle01'
CRS-2673: Attempting to stop 'ora.LISTENER_SCAN1.lsnr' on 'oracle01'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'oracle01'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'oracle01'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'oracle01'
CRS-2790: Starting shutdown of Cluster Ready Services-managed resources on 'oracle02'
CRS-2673: Attempting to stop 'ora.DATA.dg' on 'oracle02'
CRS-2673: Attempting to stop 'ora.FRA.dg' on 'oracle02'
CRS-2673: Attempting to stop 'ora.OCR.dg' on 'oracle02'
CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'oracle02'
CRS-2673: Attempting to stop 'ora.cvu' on 'oracle02'
CRS-2677: Stop of 'ora.cvu' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.oracle01.vip' on 'oracle01'
CRS-2677: Stop of 'ora.LISTENER_SCAN1.lsnr' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.scan1.vip' on 'oracle01'
CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.oracle02.vip' on 'oracle02'
CRS-2677: Stop of 'ora.DATA.dg' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.DATA.dg' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.FRA.dg' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.FRA.dg' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.oracle02.vip' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.oracle01.vip' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.scan1.vip' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.oc4j' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.OCR.dg' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'oracle01'
CRS-2677: Stop of 'ora.OCR.dg' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.asm' on 'oracle02'
CRS-2677: Stop of 'ora.asm' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.asm' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.ons' on 'oracle02'
CRS-2677: Stop of 'ora.ons' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'oracle02'
CRS-2677: Stop of 'ora.net1.network' on 'oracle02' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'oracle02' has completed
CRS-2673: Attempting to stop 'ora.ons' on 'oracle01'
CRS-2677: Stop of 'ora.ons' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.net1.network' on 'oracle01'
CRS-2677: Stop of 'ora.net1.network' on 'oracle01' succeeded
CRS-2792: Shutdown of Cluster Ready Services-managed resources on 'oracle01' has completed
CRS-2677: Stop of 'ora.crsd' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'oracle02'
CRS-2673: Attempting to stop 'ora.evmd' on 'oracle02'
CRS-2673: Attempting to stop 'ora.asm' on 'oracle02'
CRS-2677: Stop of 'ora.crsd' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.ctssd' on 'oracle01'
CRS-2673: Attempting to stop 'ora.evmd' on 'oracle01'
CRS-2673: Attempting to stop 'ora.asm' on 'oracle01'
CRS-2677: Stop of 'ora.evmd' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.evmd' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.ctssd' on 'oracle01' succeeded
CRS-2677: Stop of 'ora.asm' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'oracle02'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'oracle02' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'oracle02'
CRS-2677: Stop of 'ora.cssd' on 'oracle02' succeeded
CRS-2677: Stop of 'ora.asm' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.cluster_interconnect.haip' on 'oracle01'
CRS-2677: Stop of 'ora.cluster_interconnect.haip' on 'oracle01' succeeded
CRS-2673: Attempting to stop 'ora.cssd' on 'oracle01'
CRS-2677: Stop of 'ora.cssd' on 'oracle01' succeeded
[root@oracle02 ~]# 

```

### 3.6. root脚本执行日志

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-03-06 3.6 root脚本执行日志**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

### 3.7. 集群状态检查

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-03-07 3.7 集群状态检查长回显**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

### 3.8.P3:静默安装路径总览(无GUI/批量部署)

#定位:本节提供无图形界面、批量部署、自动化交付时的静默安装路径。
#GUI步骤仍保留作为教学和截图实录;正式交付建议把最终参数固化为响应文件,并纳入版本管理。
#响应文件中可能包含口令或路径信息,目录权限必须为700,文件权限必须为600,严禁随文档分发真实响应文件。

```bash
#统一响应文件目录
mkdir -p <SILENT_RSP_DIR>
chown -R grid:oinstall <SILENT_RSP_DIR>
chmod 700 <SILENT_RSP_DIR>
```

#### 3.8.1.Grid Infrastructure静默安装框架

#建议先用GUI或安装介质中的sample响应文件生成初稿,再按本环境变量替换。
#以下是关键字段框架,不是跨环境可直接照抄的最终文件。
#本节按当前全文三节点集群口径给出:k8s-19rac01/02/03均列入GI、DB软件和DBCA节点清单;若现场采用先两节点后addnode,必须另按第10章addnode流程执行并在变更单中说明。

```bash
su - grid
cat > <SILENT_RSP_DIR>/gridsetup_xydb.rsp <<'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0
INVENTORY_LOCATION=/u01/app/oraInventory
oracle.install.option=CRS_CONFIG
ORACLE_BASE=/u01/app/grid
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.clusterName=rac-cluster
oracle.install.crs.config.gpnp.scanName=<SCAN_NAME>
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.clusterNodes=k8s-19rac01:k8s-19rac01-vip,k8s-19rac02:k8s-19rac02-vip,k8s-19rac03:k8s-19rac03-vip
oracle.install.crs.config.networkInterfaceList=eth0:172.18.0.0:1,eth1:10.100.100.0:5,eth2:3.3.3.0:3
oracle.install.crs.config.storageOption=FLEX_ASM_STORAGE
oracle.install.crs.config.useIPMI=false
oracle.install.asm.SYSASMPassword=<SYS_PWD>
oracle.install.asm.diskGroup.name=OCR
oracle.install.asm.diskGroup.redundancy=NORMAL
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.disks=/dev/oracleasm/disks/OCR01,/dev/oracleasm/disks/OCR02,/dev/oracleasm/disks/OCR03
oracle.install.asm.monitorPassword=<SYS_PWD>
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false
EOF
chmod 600 <SILENT_RSP_DIR>/gridsetup_xydb.rsp

cd /u01/app/19.0.0/grid
./gridSetup.sh -silent -responseFile <SILENT_RSP_DIR>/gridsetup_xydb.rsp -ignorePrereqFailure | tee /tmp/gridSetup_silent_$(date +%F_%H%M%S).log
```

#root脚本仍必须按安装器提示顺序执行:先节点1,确认完成后再节点2,最后节点3。
#执行后验收:

```bash
/u01/app/19.0.0/grid/bin/crsctl check cluster -all
/u01/app/19.0.0/grid/bin/crsctl status resource -t
/u01/app/19.0.0/grid/bin/ocrcheck
/u01/app/19.0.0/grid/bin/crsctl check ctss
```

#### 3.8.2.DB软件静默安装框架

```bash
su - oracle
mkdir -p <SILENT_RSP_DIR>
chmod 700 <SILENT_RSP_DIR>
cat > <SILENT_RSP_DIR>/db_install_xydb.rsp <<'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.CLUSTER_NODES=k8s-19rac01,k8s-19rac02,k8s-19rac03
DECLINE_SECURITY_UPDATES=true
EOF
chmod 600 <SILENT_RSP_DIR>/db_install_xydb.rsp

cd /u01/app/oracle/product/19.0.0/db_1
./runInstaller -silent -responseFile <SILENT_RSP_DIR>/db_install_xydb.rsp -ignorePrereqFailure | tee /tmp/db_install_silent_$(date +%F_%H%M%S).log
```

#root脚本按提示在各节点执行后,再验证:

```bash
su - oracle
$ORACLE_HOME/OPatch/opatch lsinventory | head
srvctl status home -oraclehome $ORACLE_HOME -statefile /tmp/dbhome_state.txt || true
```

#### 3.8.3.DBCA静默建库框架

#dbca静默建库前必须完成6.4.5容量规划、HugePages、memlock、ASM DATA/FRA、Redo大小规划。
#命令行出现口令有ps暴露风险;建议在隔离变更窗口执行,执行后立即清理shell历史,或使用受控自动化平台的密文变量注入能力。

```bash
su - oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export PATH=$ORACLE_HOME/bin:$PATH

#示例框架:具体内存、字符集、PDB、redo、service仍以6.1和6.4.5规划为准
dbca -silent -createDatabase \
  -databaseConfigType RAC \
  -templateName General_Purpose.dbc \
  -gdbName xydb \
  -sid xydb \
  -nodelist k8s-19rac01,k8s-19rac02,k8s-19rac03 \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName stuwork \
  -pdbAdminPassword '<DSA_PWD>' \
  -sysPassword '<SYS_PWD>' \
  -systemPassword '<SYS_PWD>' \
  -storageType ASM \
  -diskGroupName DATA \
  -recoveryGroupName FRA \
  -datafileDestination +DATA \
  -recoveryAreaDestination +FRA \
  -databaseCharacterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -memoryMgmtType AUTO_SGA \
  -totalMemory 32768 \
  -emConfiguration NONE \
  -ignorePreReqs
```

#建库后必须立即执行:
#1)6.4.5 HugePages/use_large_pages验证;
#2)6.4.9 Redo调整;
#3)6.4.8 PDB service创建;
#4)6.5.1 RMAN配置和DBID归档;
#5)13.2 postcheck。

#### 3.8.4.静默安装交付物清单

| 交付物 | 路径示例 | 权限 | 说明 |
| ------ | -------- | ---- | ---- |
| Grid响应文件 | `<SILENT_RSP_DIR>/gridsetup_xydb.rsp` | 600 | 不随文档分发真实口令版 |
| DB响应文件 | `<SILENT_RSP_DIR>/db_install_xydb.rsp` | 600 | 记录最终用户组、ORACLE_HOME、节点列表 |
| 安装日志 | `/tmp/*silent*.log` | 600/640 | 归档到项目交付目录,脱敏后流转 |
| root脚本执行记录 | 变更单附件 | - | 必须记录节点顺序和执行时间 |
| postcheck结果 | 14.3 | - | 静默安装闭环门禁 |


## 4.创建 ASM 数据磁盘

### 4.1. grid 账户登录图形化界面，执行 asmca
#创建asm磁盘组步骤
```
1. DiskGroups界面点击Create
2. 
#asmlib管理的话
#或者uuid不固定的情况
#本次使用
DATA/External/(/dev/oracleasm/disks/DATA01)，点击OK

#uuid固定的情况
DATA/External/(/dev/sdd、/dev/sde、/dev/sdf)，点击OK

3. 继续点击Create

4.  
#asmlib管理的话
#或者uuid不固定的情况
#本次使用
FRA/External/(/dev/oracleasm/disks/FRA01)，点击OK

#uuid固定的情况
FRA/External/(/dev/sdg)，点击OK

5. Exit
```
![image-20231118184625244](oracle-store\image-20231118184625244.png)

### 4.2. 查看集群状态

```
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



#(此处原有的"移除chrony.conf使CTSS进入Active"历史错误处理记录已移至附录14.1,禁止照做;现行标准见2.5节)
```
## 5 安装 Oracle 数据库软件
#以 Oracle 用户登录图形化界面，将数据库软件解压至$ORACLE_HOME 

```bash
[oracle@rac01 db_1]$ pwd
/u01/app/oracle/product/19.0.0/db_1
[oracle@rac01 db_1]$ unzip -oq /u01/storage/LINUX.X64_193000_db_home.zip
```
#节点一安装前检查--也可以不进行该项检查

```bash
[grid@rac01 ~]$ cd /u01/app/19.0.0/grid/
[grid@rac01 grid]$ ./runcluvfy.sh stage -pre dbinst -n k8s-19rac01,k8s-19rac02 -fixup -verbose|tee -a /home/grid/pre-db.log
```

#关于rac-scan的解析失败，可以忽略

```
Verifying DNS/NIS name service 'rac-scan' ...FAILED
  PRVG-11826 : DNS resolved IP addresses "" for SCAN name "rac-scan" not found
  in the name service returned IP addresses "172.18.13.176"
  PRVG-11827 : Name service returned IP addresses "172.18.13.176" for SCAN name
  "rac-scan" not found in the DNS returned IP addresses ""

  k8s-19rac02: PRVF-4664 : Found inconsistent name resolution entries for SCAN
             name "rac-scan"

  k8s-19rac01: PRVF-4664 : Found inconsistent name resolution entries for SCAN
             name "rac-scan"
```



#通过xstart图形化连接服务器，同Grid连接方式

```bash
[oracle@rac01 ~]$ cd /u01/app/oracle/product/19.0.0/db_1

[oracle@rac01 db_1]$ ./runInstaller
```
### 5.1. oracle software安装步骤
#安装过程如下
```
1. 仅设置software---Set Up Software Only
2. oracle RAC
3. SSH互信测试(SSH connectivity--->Test)
4. Enterprise Edition
5. $ORACLE_BASE(/u01/app/oracle)
6. 用户组，保持默认
7. 不执行配置脚本，保持默认
8. 忽略全部--->Yes
9. Install
10. root账户先在k8s-19rac01执行完毕后再在k8s-19rac02上执行脚本(/u01/app/oracle/product/19.0.0/db_1/root.sh)，然后点击OK
11. Close
```




![image-20230928121556137](oracle19cRAC-neuq\image-20230928121556137.png)



### 5.2. 执行root.sh脚本记录

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-05-02 5.2 DB root.sh脚本记录**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

### 5.3. 查看集群状态

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-05-03 5.3 DB软件安装后集群状态长回显**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

## 6 建立数据库

以 oracle 账户登录。
### 6.1. 执行建库 dbca
#创建RAC数据库步骤

```
1. Create a database
2. Advanced Configuration
3. RAC/Admin Managed/General Purpose
4. Select All
5. xydb/xydb/Create as Container database/Use Local Undo tbs for PDBs/pdb:1/pdbname:stuwork
6. AMS:+DATA/{DB_UNIQUE_NAME}/Use OMF
7. ASM/+FRA/+FRA free space(点击Browse查看：2097012)/Enable archiving
8. 数据库组件，保持默认不选
9. ASMM自动共享内存管理
       #历史记录:sga=memory*65%*75%=64G*65%*75%=31.2G(向下十位取整为30G)
       #!!!v2.5.1起禁止按本旧公式直接填写dbca内存值;SGA/PGA/processes必须以6.4.5容量规划结果为准。
       #pga=memory*65%*25%=64G*65%*25%=10.4G(向下十位取整为10G)
       #sga=30G
       #pag=10G
       #此处为总32G，所以sga=15G,pga=5G
   Sizing: block size: 8192/processes: 3000
   Character Sets: AL32UTF8
   Connection mode: Dadicated server mode--->Next
10. 运行CVU和关闭EM
11. 使用相同密码<SYS_PWD>
12. 勾选：create database
    添加日志组：Customize Storage Locations...--->Redo Log Groups
              #!!!redo大小:dbca默认200MB过小,生产按"高峰期每小时切换<=4~6次"原则评估
              #建议2G起步、每thread至少3组;若建库时未调整,事后按6.4.9节在线调整
              --->先将默认Group#1~4的FileSize改为: 2097152KB(即2G)
              --->添加两组：Group#: 5/FileSize: 2097152KB/Thread: 1--->Apply
                          Group#: 6/FileSize: 2097152KB/Thread: 2--->Apply--->Close
13. Ignore all--->Yes
14. Finish
15. Close

```
### 6.2. 查看集群状态

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-06-02 6.2 建库后集群状态长回显**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

### 6.3. 查看数据库版本
```
[oracle@rac01 db_1]$ sqlplus / as sysdba
SQL> col banner_full for a120
SQL> select BANNER_FULL from v$version;

BANNER_FULL
--------------------------------------------------------------------------------
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select INST_NUMBER,INST_NAME FROM v$active_instances;

INST_NUMBER INST_NAME
----------- ----------------------------------------------
	  1 k8s-19rac01:xydb1
	  2 k8s-19rac02:xydb2

SQL> SELECT instance_name, host_name FROM gv$instance;

INSTANCE_NAME	 HOST_NAME
---------------- --------------------------------
xydb1		 k8s-19rac01
xydb2		 k8s-19rac02

SQL> col file_name format a80

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME									 TABLESPACE_NAME
------------------------------------------- ------------------------------
+DATA/XYDB/TEMPFILE/temp.264.1098977211 					 TEMP

SQL> select file_name,tablespace_name from dba_data_files;


FILE_NAME                                                                        TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/DATAFILE/system.257.1148734967                                        SYSTEM
+DATA/XYDB/DATAFILE/sysaux.258.1148735013                                        SYSAUX
+DATA/XYDB/DATAFILE/undotbs1.259.1148735037                                      UNDOTBS1
+DATA/XYDB/DATAFILE/users.260.1148735039                                         USERS
+DATA/XYDB/DATAFILE/undotbs2.269.1148735517                                      UNDOTBS2

SQL> 

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO

SQL>  alter session set container=STUWORK;

Session altered.

SQL> select file_name ,tablespace_name from dba_temp_files;

FILE_NAME                                                                        TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/TEMPFILE/temp.276.1148736023         TEMP

SQL> select file_name,tablespace_name from dba_data_files;

FILE_NAME                                                                        TABLESPACE_NAME
-------------------------------------------------------------------------------- ------------------------------
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/system.274.1148736011       SYSTEM
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/sysaux.275.1148736011       SYSAUX
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/undotbs1.273.1148736011     UNDOTBS1
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/undo_2.277.1148736039       UNDO_2
+DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/users.278.1148736041        USERS

SQL> 
```
### 6.4. Oracle RAC数据库优化

#### 6.4.1.口令策略(推荐基线 + 兼容例外)

#!!!推荐基线(默认采用,一个节点修改即可,CDB/PDB分别确认)

```oracle
select resource_name, limit from dba_profiles where profile='DEFAULT';

alter profile default limit
  failed_login_attempts 10
  password_lock_time 1
  password_life_time 180
  password_grace_time 7;

select resource_name, limit from dba_profiles where profile='DEFAULT';
```

#口令过期会导致老应用突然连不上;正确做法不是取消过期,而是把"口令剩余天数"纳入巡检告警:

```sql
select username, expiry_date from dba_users
where account_status = 'OPEN' and expiry_date < sysdate + 30;
```

#兼容例外(仅当业务方书面确认无法接受口令过期/锁定时执行,且必须登记风险接受表):

```oracle
--例外项,默认禁止;FAILED_LOGIN_ATTEMPTS unlimited等于放开口令暴破
--alter profile default limit password_life_time unlimited;
--alter profile default limit failed_login_attempts unlimited;
--alter profile ORA_STIG_PROFILE limit PASSWORD_LIFE_TIME UNLIMITED;
```

#风险接受表模板(每个例外一行,随文档归档):
#业务系统 | 负责人 | 必须例外的原因 | 预计整改时间 | 补偿措施落实情况
#补偿措施(执行例外时必须同时落实):

```
#  1)监听白名单(VNCR):限制可连接数据库的客户端来源

#  2)登录失败审计并告警: audit session whenever not successful;

#  3)结合校园CAS已长期遭遇撞库/口令喷洒的现实,数据库口令复杂度不得降低
```



#### 6.4.2.客户端版本兼容(推荐基线 + 兼容例外)

#推荐基线(两个节点都改)

```
su - oracle
cd $ORACLE_HOME/network/admin
vi sqlnet.ora

SQLNET.ALLOWED_LOGON_VERSION_SERVER=11
SQLNET.ALLOWED_LOGON_VERSION_CLIENT=11
#死连接检测:10分钟探测一次,异常断开的连接池连接可被及时清理
SQLNET.EXPIRE_TIME=10
```

#!!!兼容例外:设为8会启用10g弱口令哈希(等保/密评不过,且显著放大撞库风险),
#仅当存在无法升级的老客户端(10g及更早的JDBC/OCI)且业务方书面确认时才允许:
#SQLNET.ALLOWED_LOGON_VERSION_SERVER=8
#SQLNET.ALLOWED_LOGON_VERSION_CLIENT=8
#降级后必须:1)重置相关用户口令以生成对应版本哈希 2)登记6.4.1风险接受表并限定整改期限
#3)落实监听白名单与登录失败审计 4)整改完成后立即改回11并再次重置口令

#### 6.4.3.数据库自启动(cdb/pdb)

#数据库自启动---两个节点都要修改

```
su - root

/u01/app/19.0.0/grid/bin/crsctl enable crs
```


#PDB自启动---一个节点(k8s-19rac01或者k8s-19rac02)创建即可

#方法一

```oracle
CREATE OR REPLACE TRIGGER open_pdbs
  AFTER STARTUP ON DATABASE
BEGIN
   EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
END open_pdbs;
/
```


#完整触发器代码

```sql
-- 创建日志表（在 CDB 中执行）
CREATE TABLE pdb_startup_log (
  log_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  error_time     TIMESTAMP,
  error_message  VARCHAR2(4000)
);


-- 在 CDB 级别创建（需 SYSDBA 权限）
CREATE OR REPLACE TRIGGER auto_open_pdbs
AFTER STARTUP ON DATABASE
DECLARE
  v_error_msg VARCHAR2(4000);
BEGIN
  BEGIN
    -- 尝试打开所有 PDB
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
  EXCEPTION
    WHEN OTHERS THEN
      -- 记录错误到日志表（需提前创建）
      v_error_msg := 'Error opening PDBs: ' || SQLERRM;
      INSERT INTO pdb_startup_log (error_time, error_message)
      VALUES (SYSTIMESTAMP, v_error_msg);
      COMMIT; -- 需使用自治事务（见下方注释）
  END;
END auto_open_pdbs;
/

```



#如果pdb确认时

```sql
CREATE TABLE open_err (
  log_time     TIMESTAMP     DEFAULT SYSTIMESTAMP,
  pdb_name     VARCHAR2(128),
  error_message VARCHAR2(512)
);

-- 确认表创建成功
DESC open_err;


CREATE OR REPLACE TRIGGER open_all_pdbs
AFTER STARTUP ON DATABASE
DECLARE
  pdb_list   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('pdb1','pdb2','pdb3');
  v_sql      VARCHAR2(200);
BEGIN
  FOR i IN 1..pdb_list.COUNT LOOP
    BEGIN
      v_sql := 'ALTER PLUGGABLE DATABASE ' || pdb_list(i) || ' OPEN';
      EXECUTE IMMEDIATE v_sql;
    EXCEPTION
      WHEN OTHERS THEN
        INSERT INTO open_err (pdb_name, error_message)
        VALUES (pdb_list(i), SUBSTR(SQLERRM,1,512));
        COMMIT; -- 及时提交
    END;
  END LOOP;
END;
/


set linesize 200
col owner format a10
col trigger_name format a25
col status format a10

SELECT owner, trigger_name, status 
FROM DBA_TRIGGERS WHERE trigger_name = 'OPEN_ALL_PDBS';
```





#方法二

```oracle
alter pluggable database all open instances=all;
alter pluggable database all save state instances=all;
```



#重启数据库验证

```bash
# RAC 环境
srvctl stop database -db xydb
srvctl start database -db xydb

```

#查看状态

```sql
-- 检查触发器状态
SELECT trigger_name, status 
FROM dba_triggers 
WHERE trigger_name = 'AUTO_OPEN_PDBS';

-- 查看 PDB 状态
SELECT name, open_mode FROM v$pdbs;

-- 查询错误日志
SELECT * FROM pdb_startup_log ORDER BY error_time DESC;

```



#### 6.4.4.DB_FILES

#DB_FILES修改，默认1024

```oracle
alter system set DB_FILES=4096 scope=spfile sid='*';

srvctl stop database -d xydb
srvctl start database -d xydb

sqlplus / as sysdba
show parameter db_files
```

#### 6.4.5.HugePages/SGA/PGA/processes强制规划(P1必做)

#!!!本节从“建库后可选优化”升级为“建库前强制规划项”。
#原因:THP开启、HugePages缺失或memlock错误,会导致SGA回退到普通页,在高并发/大SGA场景下引发内存抖动、swap、实例异常甚至节点驱逐。
#任何生产或准生产部署,必须在dbca建库前完成本节规划;已有库变更HugePages时必须安排停库/停CRS窗口。

##### 6.4.5.1.规划原则

| 项目 | 推荐基线 | 验收标准 |
| ---- | -------- | -------- |
| THP | 必须关闭 | `/sys/kernel/mm/transparent_hugepage/enabled`显示`[never]`;`AnonHugePages=0` |
| SGA | 专用数据库主机通常按物理内存60%~70%评估,再结合PDB/连接数/压测调整 | `sga_target/sga_max_size`有明确容量依据 |
| PGA | 根据并发SQL、排序/Hash、ETL/expdp负载评估 | `pga_aggregate_limit`不得低于`max(2GB,2*pga_aggregate_target,3MB*processes)`并留余量 |
| processes | 按连接池总连接、后台进程、运维连接、批任务峰值计算 | `sessions`/`transactions`由Oracle派生或显式校验 |
| HugePages | 覆盖所有实例SGA总和,再预留5%~10% | `HugePages_Free`有少量余量,alert log显示Large Pages被使用 |
| memlock | 大于HugePages总量(KB),与2.7 limits一致 | `ulimit -l` >= HugePages_Total*Hugepagesize |
| use_large_pages | 生产建议`ONLY` | HugePages不足时启动失败,避免静默回退普通页 |

##### 6.4.5.2.建库前计算流程

```bash
#1)确认物理内存与THP状态
free -g
grep -i Huge /proc/meminfo
grep -i AnonHugePages /proc/meminfo
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag

#2)按计划SGA计算HugePages数量
#示例:计划单实例SGA=24G,三实例RAC每节点只运行本地一个实例,每节点按本节点SGA计算:
#HugePages页数 = SGA_GB * 1024 * 1024 / 2048 + 预留5%~10%
SGA_GB=<PER_NODE_SGA_GB>
BASE_HP=$(( SGA_GB * 1024 * 1024 / 2048 ))
HP=$(( BASE_HP * 110 / 100 ))
echo "vm.nr_hugepages = ${HP}"
echo "memlock_kb >= $(( HP * 2048 ))"

#3)写入sysctl;所有RAC节点分别按本节点实例SGA计算
cat >> /etc/sysctl.d/99-oracle-hugepages.conf <<EOF
vm.nr_hugepages = ${HP}
EOF
sysctl --system

#4)设置memlock,见2.7;修改后必须重新登录oracle/grid用户
```

##### 6.4.5.3.关闭THP

```bash
#推荐通过grub永久关闭;先确认BIOS/UEFI路径
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS

#在GRUB_CMDLINE_LINUX中追加 transparent_hugepage=never numa=off
cp /etc/default/grub /etc/default/grub.bak.$(date +%F_%H%M%S)
sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="transparent_hugepage=never numa=off /' /etc/default/grub

#BIOS:
[ ! -d /sys/firmware/efi ] && grub2-mkconfig -o /boot/grub2/grub.cfg
#UEFI,路径按实际发行版确认;Oracle Linux通常在/boot/efi/EFI/redhat或/boot/efi/EFI/centos
[ -d /sys/firmware/efi ] && grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg

reboot
```

#临时兜底方式仅用于验证或无法立即改grub的窗口,不能替代grub永久配置:

```bash
cat >> /etc/rc.local <<'EOF'
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
chmod +x /etc/rc.d/rc.local
```

##### 6.4.5.4.数据库参数设置

```sql
--以下在CDB root执行;RAC环境sid='*'
--数值按容量规划替换,不要照抄示例
alter system set sga_target=<SGA_SIZE> scope=spfile sid='*';
alter system set sga_max_size=<SGA_SIZE> scope=spfile sid='*';
alter system set pga_aggregate_target=<PGA_TARGET> scope=spfile sid='*';
alter system set pga_aggregate_limit=<PGA_LIMIT> scope=spfile sid='*';
alter system set processes=<PROCESSES> scope=spfile sid='*';
alter system set use_large_pages=ONLY scope=spfile sid='*';
```

#说明:
#1)设置`use_large_pages=ONLY`后,如果HugePages或memlock不足,实例会启动失败;这是预期保护,避免静默回退到普通页。
#2)修改SGA/processes/use_large_pages需要重启实例;RAC生产环境按滚动窗口或停机窗口执行。
#3)PGA limit校验公式:

```sql
set lines 200
col name for a30
select name,value from v$parameter
where name in ('sga_target','sga_max_size','pga_aggregate_target','pga_aggregate_limit','processes','sessions','use_large_pages')
order by name;

--按官方下限口径估算PGA limit: max(2GB,3MB*processes,2*pga_target)
col pga_target_gb for 9999990.00
col current_limit_gb for 9999990.00
col min_by_processes_gb for 9999990.00
col min_by_2gb_gb for 9999990.00
col min_by_2x_target_gb for 9999990.00
col recommended_min_gb for 9999990.00
col verdict for a12
with p as (
  select
    max(case when name='processes' then to_number(value) end) processes,
    max(case when name='pga_aggregate_target' then to_number(value) end) pga_target_bytes,
    max(case when name='pga_aggregate_limit' then to_number(value) end) pga_limit_bytes
  from v$parameter
  where name in ('processes','pga_aggregate_target','pga_aggregate_limit')
)
select processes,
       round(pga_target_bytes/1024/1024/1024,2) pga_target_gb,
       round(pga_limit_bytes/1024/1024/1024,2) current_limit_gb,
       round(processes*3/1024,2) min_by_processes_gb,
       2 min_by_2gb_gb,
       round(2*pga_target_bytes/1024/1024/1024,2) min_by_2x_target_gb,
       round(greatest(2*1024*1024*1024,processes*3*1024*1024,2*pga_target_bytes)/1024/1024/1024,2) recommended_min_gb,
       case when pga_limit_bytes >= greatest(2*1024*1024*1024,processes*3*1024*1024,2*pga_target_bytes)
            then 'OK' else 'TOO_LOW' end verdict
from p;

--若processes=3000,仅3MB*processes这一项下限约为8.79GB;最终仍需与2GB绝对下限、2*pga_aggregate_target取大值,再按业务排序/Hash/ETL/expdp负载预留余量。
```

##### 6.4.5.5.重启后验收

```bash
#OS层验收
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag
grep -E 'HugePages_Total|HugePages_Free|HugePages_Rsvd|HugePages_Surp|Hugepagesize|AnonHugePages' /proc/meminfo
su - oracle -c 'ulimit -l'

#GI/DB状态
crsctl stat res -t
srvctl status database -d xydb
```

```sql
--DB层验收
show parameter use_large_pages
show parameter sga
show parameter pga
show parameter processes

--查看alert日志中Large Pages信息,每个实例都要确认
define inst=xydb1
host grep -i "Large Pages" /u01/app/oracle/diag/rdbms/xydb/&inst/trace/alert_&inst.log | tail -20
```

#验收标准:
#1)`AnonHugePages`为0;
#2)`HugePages_Total`接近规划值,`HugePages_Free`有少量余量但不能大量闲置;
#3)`HugePages_Surp`为0;
#4)`use_large_pages=ONLY`;
#5)alert log显示SGA使用Large Pages/HugePages;
#6)precheck/postcheck脚本必须增加THP、HugePages、memlock、use_large_pages断言。


##### 6.4.5.6.P2 DB/ASM/FRA参数基线

#本节把P2参数基线与已有RMAN恢复窗口、FRA、ASM盘组和应用连接数绑定起来。所有参数必须先在测试环境验证,再以变更方式落地。

###### 6.4.5.6.1.数据库参数基线

| 参数 | 建议基线 | 说明/验收 |
| ---- | -------- | --------- |
| `control_file_record_keep_time` | `>= RMAN恢复窗口+7天`,本手册RMAN窗口7天时建议`14` | 防止控制文件里的备份记录早于备份文件过期,影响恢复 |
| `db_create_file_dest` | `+DATA` | 新建数据文件默认走DATA,避免落本地盘 |
| `db_recovery_file_dest` | `+FRA` | 与FRA磁盘组一致 |
| `db_recovery_file_dest_size` | 按FRA可用空间与归档增长评估,告警阈值80%/85% | 不得简单等于FRA物理总量;需预留控制文件快照、闪回/归档增长空间 |
| `fast_start_mttr_target` | 生产起步`300`,按恢复时间目标与写IO能力调整 | 过低会增加DBWR压力;过高会拉长实例恢复 |
| `open_cursors` | 起步`1000`,按应用报错/连接池SQL复杂度调整 | 结合`ORA-01000`监控 |
| `session_cached_cursors` | 起步`200` | 降低软解析开销,按AWR parse情况调整 |
| `parallel_max_servers` | 明确上限,避免默认值过高 | OLTP系统先保守设置,批处理/报表库按CPU与并发评估 |
| Resource Manager维护窗口 | 优先调整维护窗口与计划,不默认使用隐藏参数关闭 | `_resource_manager_always_off`等隐藏参数必须有MOS/SR依据 |

```sql
--查看当前值
show parameter control_file_record_keep_time
show parameter db_create_file_dest
show parameter db_recovery_file_dest
show parameter db_recovery_file_dest_size
show parameter fast_start_mttr_target
show parameter open_cursors
show parameter session_cached_cursors
show parameter parallel_max_servers

--P2建议样例,按容量规划替换后执行
alter system set control_file_record_keep_time=14 scope=both sid='*';
alter system set db_create_file_dest='+DATA' scope=both sid='*';
alter system set db_recovery_file_dest='+FRA' scope=both sid='*';
--示例值,必须小于FRA可承载容量并留余量
alter system set db_recovery_file_dest_size=150G scope=both sid='*';
alter system set fast_start_mttr_target=300 scope=both sid='*';
alter system set open_cursors=1000 scope=both sid='*';
alter system set session_cached_cursors=200 scope=both sid='*';
--示例值,按CPU核数/业务类型评估
alter system set parallel_max_servers=64 scope=both sid='*';
```

###### 6.4.5.6.2.FRA容量阈值与清理预案

```sql
--每日巡检和监控平台均应采集该结果
set lines 200 pages 100
select name,
       round(space_limit/1024/1024/1024,2) limit_gb,
       round(space_used/1024/1024/1024,2) used_gb,
       round(space_reclaimable/1024/1024/1024,2) reclaimable_gb,
       round(space_used/space_limit*100,2) used_pct
from v$recovery_file_dest;

--归档增长趋势
select trunc(first_time) day, thread#, count(*) logs,
       round(sum(blocks*block_size)/1024/1024/1024,2) arch_gb
from v$archived_log
where first_time > sysdate-14
  and deleted='NO'
group by trunc(first_time), thread#
order by 1,2;
```

#告警建议:
#1)FRA使用率>=80%告警,>=85%必须处理,>=90%进入故障手册9.7;
#2)禁止直接OS rm归档;优先用RMAN crosscheck/delete expired/delete archivelog until time;
#3)ADG环境必须结合`CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY`,防止主库删掉备库未应用归档。

###### 6.4.5.6.3.ASM属性基线

| 项目 | 建议 | 注意事项 |
| ---- | ---- | -------- |
| `compatible.asm` | `19.0.0.0.0` | 设置后不能降级,需确认不再回退低版本GI |
| `compatible.rdbms` | `19.0.0.0.0` | 与数据库版本一致 |
| DATA `au_size` | 新建盘组建议`4M` | AU size只能建盘组时指定,已有盘组不能直接alter修改 |
| `asm_power_limit` | 日常4~8,维护/重平衡窗口可临时提高 | 值越高重平衡越快,但会抢IO |

#!!!`compatible.asm`/`compatible.rdbms`属于单向门参数。已有运行库执行前必须二次确认:无回退低版本GI/DB计划、备份/OCR/OLR可用、变更窗口和回退路径已记录;否则只查询不修改。

```sql
--grid用户连接ASM实例
sqlplus / as sysasm

col name for a20
col value for a30
select dg.name diskgroup, a.name attr, a.value
from v$asm_diskgroup dg join v$asm_attribute a on dg.group_number=a.group_number
where a.name in ('compatible.asm','compatible.rdbms','au_size')
order by dg.name,a.name;

--新建或确认无版本回退需求后执行;已有运行环境先评估
alter diskgroup DATA set attribute 'compatible.asm'='19.0.0.0.0';
alter diskgroup DATA set attribute 'compatible.rdbms'='19.0.0.0.0';
alter diskgroup FRA  set attribute 'compatible.asm'='19.0.0.0.0';
alter diskgroup FRA  set attribute 'compatible.rdbms'='19.0.0.0.0';

--asm_power_limit按窗口调整
alter system set asm_power_limit=8 scope=both;
```

#新建DATA盘组时示例:

```sql
create diskgroup DATA external redundancy
  disk '/dev/oracleasm/disks/DATA01'
  attribute 'compatible.asm'='19.0.0.0.0',
            'compatible.rdbms'='19.0.0.0.0',
            'au_size'='4M';
```

#### 6.4.6.VKTM报错处理
#VKTM报错处理

```oracle
Warning: VKTM detected a forward time drift.
Please see the VKTM trace file for more details:
/u01/app/oracle/diag/rdbms/xydb/xydb2/trace/xydb2_vktm_9790.trc
```

#解决：

```sql
alter system set event="10795 trace name context forever, level 2" scope=spfile sid='*';

srvctl stop database -d xydb 
srvctl start database -d xydb 

#alter system  set event='10949 trace name context forever,level 1','28401 trace name context forever,level 1','10503 trace name context forever, level 4000','10795 trace name context forever, level 2' scope=spfile sid='*';

#10949---历史排障线索:与direct path read行为相关;默认不得写入生产模板,需MOS/SR确认适用版本后才可变更
#28401---历史排障线索:关闭密码错误登录延迟
#10503---历史排障线索:与bind length/child cursor行为相关;默认不得写入生产模板,需MOS/SR确认适用版本后才可变更
#P0安全收口:28401会关闭密码错误登录延迟,与6.4.1暴破防护方向冲突;默认不得启用,仅保留为历史说明

SELECT name, value
FROM v$parameter
WHERE isdefault = 'FALSE';


SET linesize 120
SET feedback off
SET SERVEROUTPUT ON
DECLARE
err_msg VARCHAR2(120);
BEGIN
dbms_output.enable (1000000);
FOR err_num IN 10000..10999
LOOP
err_msg := SQLERRM (-err_num);
IF err_msg NOT LIKE '%Message '||err_num||' not found%' THEN
dbms_output.put_line (err_msg);
END IF;
END LOOP;
END;




```

#### 6.4.7.resize operation completed for file# old size new size报错处理

#resize operation completed for file# old size new size报错处理

```bash
2023-10-30T01:13:27.378988+08:00
DATAASSETS(3):Resize operation completed for file# 11, fname +DATA/XYDB/0665763A0AE805D2E063760C140A0DB5/DATAFILE/sysaux.275.1148736011, old size 563200K, new size 573440K
```

#解决

#cdb设置，全体pdb也生效

```sql
col name for a52
col value for a24
col description for a50

Set linesize 300
Select a.ksppinm name, B.ksppstvl value, a.ksppdesc description
From x$ksppi a, x$ksppcv B
Where a.inst_id = USERENV ('instance')
And B.inst_id = USERENV ('instance')
And a.indx = B.indx
and upper (a.ksppinm) LIKE upper ('%&param%')
order by name
/

------------------------
col name for a30
col value for a20
col description for a70
set line 150
select a.ksppinm name,b.ksppstvl value,a.ksppdesc description
  from x$ksppi a,x$ksppcv b
 where a.inst_id = USERENV ('Instance')
   and b.inst_id = USERENV ('Instance')
   and a.indx = b.indx
   and upper(a.ksppinm) LIKE upper('%disable_file_resize_logging%')
   order by name;
-----------------------


 alter system set "_disable_file_resize_logging"=TRUE scope=both sid='*';
```



#优化2024(P0收口:隐藏event必须默认禁用,尤其28401)

```sql
-- !!!默认禁止直接套用event组合。
-- event 28401用于关闭密码错误登录延迟,会削弱6.4.1的失败登录/暴破防护,与failed_login_attempts 10的安全基线存在方向冲突。
-- 因此本文档默认不启用28401;如业务方要求启用,必须登记风险接受表,写明MOS依据/适用版本/回退命令/整改期限。

-- 10949/10503保守收口:
-- 未在公开官方资料中核验到可直接写入本交付模板的MOS Doc ID、Bug号、19c/RU适用边界和回退要求。
-- 因此10949/10503只保留为历史排障线索,不再作为默认模板、推荐项或待启用项。
-- 如现场确需使用,必须先在My Oracle Support或Oracle SR中确认:Doc ID/Bug号、数据库版本/RU、触发场景、风险、验证SQL、回退命令,并经变更审批。
-- 示例(默认禁止执行,仅供识别历史遗留):
-- alter system set event='10949 trace name context forever,level 1','10503 trace name context forever, level 4000' scope=spfile sid='*';

-- 回退示例(变更窗口内执行,重启数据库生效):
-- alter system reset event scope=spfile sid='*';
-- srvctl stop database -d xydb
-- srvctl start database -d xydb

-- 核查当前非默认event/隐藏参数,确认是否仍遗留28401:
show parameter event
select inst_id, name, value from gv$parameter where name = 'event';
```



#### 6.4.8.创建pdb service

##创建service

```bash
su - oracle

#11g + pdb
srvctl add service -d xydb -s s_stuwork -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb stuwork

#19c
#srvctl add service -d xydb -s s_stuwork_new -pdb stuwork -preferred xydb1,xydb2,xydb3 -policy AUTOMATIC -tafpolicy BASIC -failovertype SELECT -failovermethod BASIC -failoverretry 180  -failoverdelay 5

#srvctl add service -d xydb -s s_stuwork_swingbench -pdb stuwork -preferred xydb1,xydb2,xydb3 -policy AUTOMATIC -commit_outcome TRUE -tafpolicy BASIC -failovertype TRANSACTION  -failovermethod BASIC -failoverretry 180  -failoverdelay 5 -rlbgoal SERVICE_TIME -clbgoal SHORT

srvctl start service -d xydb -s s_stuwork

lsnrctl status 


for service in $(srvctl config service -d xydb | awk 'BEGIN {SERVICE=""; PREF=""; OFS=";"} { if($0 ~ /Service name:/) SERVICE=$NF; if($0 ~ /Preferred instances:/) {PREF=$NF;print SERVICE,PREF}}');do 
  SERVICE=$(echo ${service}|cut -d ";" -f1) 
  INSTANCES=$(echo ${service}|cut -d ";" -f2) 
  RUNNINGINSTANCES=$(srvctl status service -d xydb -s ${SERVICE}|awk '{print $NF}') 
  echo "${SERVICE}: Preferred=${INSTANCES}, Running=${RUNNINGINSTANCES}"
done

```

##连接方式

```oracle
SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 DATAASSETS			  READ WRITE NO
SQL> alter session set container=DATAASSETS;

Session altered.

SQL> alter user pdbadmin identified by <SYS_PWD> account unlock;

User altered.

SQL> grant dba to pdbadmin;

Grant succeeded.

SQL> exit
#sqlplus pdbadmin/<DSA_PWD>@172.18.13.176:1521/s_dataassets
#sqlplus portaluser/<PORTAL_PWD>@172.18.13.176:1521/s_portal
#sqlplus onecodeuser/<ONECODE_PWD>@172.18.13.176:1521/s_onecode

#sqlplus system/<SYS_PWD>@172.18.13.176:1521/s_dataassets

[oracle@rac02 ~]$ sqlplus pdbadmin/<DSA_PWD>@172.18.13.176:1521/s_dataassets

SQL*Plus: Release 19.0.0.0.0 - Production on Mon Mar 14 15:54:42 2022
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Last Successful login time: Mon Mar 14 2022 15:54:30 +08:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> select count(*) from dba_objects;

  COUNT(*)
----------
     72490

SQL> exit

```

#快速进入某pdb

```bash
export ORACLE_PDB_SID=portal
sqlplus / as sysdba
show con_name;

[oracle@rac01 ~]$ export ORACLE_PDB_SID=portal;
[oracle@rac01 ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Thu Oct 19 15:51:21 2023
Version 19.20.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.20.0.0.0

SQL> show con_name;

CON_NAME
------------------------------
PORTAL

SQL> alter session set container=cdb$root;  

Session altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 PORTAL			  READ WRITE NO
```

#### 6.4.9.Redo日志大小评估与在线调整

#dbca默认每组200MB,业务上量后切换过于频繁(checkpoint风暴、log file sync/switch等待、归档压力大)
#原则:高峰期每小时日志切换次数<=4~6次;超出则按比例加大redo

##评估:按小时统计各实例日志切换次数(关注峰值小时)

```sql
set linesize 200 pagesize 100
select to_char(first_time,'yyyy-mm-dd hh24') hour, thread#, count(*) switches
from v$log_history
where first_time > sysdate - 7
group by to_char(first_time,'yyyy-mm-dd hh24'), thread#
having count(*) > 6
order by 1,2;

--当前redo配置
col member for a60
select group#, thread#, bytes/1024/1024 size_mb, status, members
from v$log order by thread#, group#;
select group#, member from v$logfile order by group#;
```

##在线调整步骤(以三节点、每thread 3组、目标2G为例,业务低峰执行,不需停库)

```sql
--1.为每个thread新增2G日志组(组号避开现有组,示例用11~13/21~23/31~33)
alter database add logfile thread 1 group 11 ('+DATA') size 2G,
                                    group 12 ('+DATA') size 2G,
                                    group 13 ('+DATA') size 2G;
alter database add logfile thread 2 group 21 ('+DATA') size 2G,
                                    group 22 ('+DATA') size 2G,
                                    group 23 ('+DATA') size 2G;
alter database add logfile thread 3 group 31 ('+DATA') size 2G,
                                    group 32 ('+DATA') size 2G,
                                    group 33 ('+DATA') size 2G;

--2.把所有实例切换到新组(19c一条命令切全部实例,可多执行几次)
alter system archive log current;
alter system switch all logfile;

--3.确认旧组状态为INACTIVE后删除(ACTIVE先做全局checkpoint再查)
--!!!以下组号1~6仅为示例,必须用上一步select返回的实际INACTIVE组号逐一替换,严禁照抄
select group#, thread#, status from v$log order by thread#, group#;
alter system checkpoint global;

alter database drop logfile group 1;
alter database drop logfile group 2;
alter database drop logfile group 3;
alter database drop logfile group 4;
alter database drop logfile group 5;
alter database drop logfile group 6;
--第三节点(thread 3)原有组一并处理,组号以上面select结果为准

--4.OMF管理下drop会自动删除ASM中的文件,确认最终结果
select group#, thread#, bytes/1024/1024 size_mb, status from v$log order by 2,1;
```

#注意:
#1)组状态为ACTIVE时执行 alter system checkpoint global 后重查再drop
#2)报ORA-01623(current log)则到对应实例再switch一次
#3)已配置ADG时,standby redo log必须与online redo同尺寸,主备两侧都要同步调整(见12.2.2节);
#调整顺序:先调主库online redo,再重建两侧SRL,最后验证传输正常


#### 6.4.10.监听安全VNCR与SQLNET基线(P2)

#目标:在不破坏RAC/ADG自动注册的前提下,限制非法远程实例向监听注册服务,并启用死连接检测。
#关键风险:启用VALID_NODE_CHECKING_REGISTRATION后,主库RAC所有public/VIP/SCAN相关地址、ADG备库地址必须互相列入白名单;否则主备注册、redo传输或角色切换后的服务注册可能被监听拒绝,造成ADG断档或应用服务不可见。

##### 6.4.10.1.SQLNET.EXPIRE_TIME死连接检测

#6.4.2已在ORACLE_HOME/network/admin/sqlnet.ora配置`SQLNET.EXPIRE_TIME=10`,本节只做收口说明,避免重复`cat >>`导致同一文件累积重复行。
#DCD(Dead Connection Detection)由数据库服务端进程读取ORACLE_HOME侧sqlnet.ora生效;GRID_HOME侧sqlnet.ora对DCD通常不起决定作用,写入无害,但不能把它误认为监听参数。
#验收以ORACLE_HOME侧文件为准:

```bash
ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
grep -E '^SQLNET.EXPIRE_TIME[[:space:]]*=[[:space:]]*10$' $ORACLE_HOME/network/admin/sqlnet.ora
#若不存在,只追加一次;重复行先人工去重
```

##### 6.4.10.2.VNCR注册白名单配置示例

```bash
#在所有RAC节点GRID_HOME/network/admin/listener.ora中维护;如由srvctl/ASM Agent管理,修改前先备份
cd /u01/app/19.0.0/grid/network/admin
cp listener.ora listener.ora.bak.$(date +%F_%H%M%S)

cat >> listener.ora <<'EOF'
# P2 listener registration hardening
# 必须包含:所有RAC节点public IP、VIP、SCAN IP、ADG主机IP;ADG侧也要包含主库RAC所有public/VIP/SCAN
VALID_NODE_CHECKING_REGISTRATION_LISTENER=ON
REGISTRATION_INVITED_NODES_LISTENER=(172.18.13.172,172.18.13.173,172.18.13.177,172.18.13.174,172.18.13.175,172.18.13.178,172.18.13.176,172.18.13.180)
EOF

#重载前先确认语法,再逐节点reload
lsnrctl status LISTENER
lsnrctl reload LISTENER
lsnrctl status LISTENER
```

#SCAN监听注册面说明:
#若安全目标要求同时收紧SCAN监听注册,需要分别配置LISTENER_SCAN1/2/3的VNCR参数;
#若当前仍采用默认SUBNET,必须在14.5变更记录中注明“SCAN监听保持默认SUBNET,仅收紧节点LISTENER”。
#示例(按实际SCAN监听数量调整,单SCAN环境通常只有LISTENER_SCAN1):

```bash
cat >> listener.ora <<'EOF'
# Optional: SCAN listener registration hardening
VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN1=ON
REGISTRATION_INVITED_NODES_LISTENER_SCAN1=(172.18.13.172,172.18.13.173,172.18.13.177,172.18.13.174,172.18.13.175,172.18.13.178,172.18.13.176,172.18.13.180)
#VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN2=ON
#REGISTRATION_INVITED_NODES_LISTENER_SCAN2=(172.18.13.172,172.18.13.173,172.18.13.177,172.18.13.174,172.18.13.175,172.18.13.178,172.18.13.176,172.18.13.180)
#VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN3=ON
#REGISTRATION_INVITED_NODES_LISTENER_SCAN3=(172.18.13.172,172.18.13.173,172.18.13.177,172.18.13.174,172.18.13.175,172.18.13.178,172.18.13.176,172.18.13.180)
EOF

lsnrctl reload LISTENER_SCAN1
lsnrctl status LISTENER_SCAN1
```

#运维提示:GI代理或监听重配、RU补丁、add/delete node后可能改写listener.ora;
#每次变更后必须复核VNCR段仍存在,并重跑6.4.10.3与12章ADG传输检查。

#ADG备库监听也要配置对应白名单,至少包含:
#1)备库本机public IP:172.18.13.180;
#2)主库RAC public IP:172.18.13.172/173/177;
#3)主库VIP/SCAN:172.18.13.174/175/178/176;
#4)未来新增节点或切换后承载服务的地址。

##### 6.4.10.3.VNCR启用后验收

```bash
#主库检查服务注册
lsnrctl status LISTENER | egrep -i 's_portal|s_stuwork|s_onecode|s_dataassets|xydb'

#备库检查redo传输与注册状态
su - oracle -c "sqlplus -s / as sysdba <<'SQL'
set lines 200 pages 100
col dest_name for a20
col status for a12
col error for a80
select dest_id,dest_name,status,error from v\$archive_dest_status where status <> 'INACTIVE';
select name,value,unit,time_computed from v\$dataguard_stats;
SQL"

#Broker环境
su - oracle -c "echo 'show configuration;' | dgmgrl /"
```

#回退:若启用后出现服务不注册、ADG transport error、监听日志出现registration rejected,立即恢复listener.ora备份并reload;随后补齐白名单再重试。


### 6.5. 集群备份

#### 6.5.1.数据库备份 
#### 6.5.1.1.rman备份(生产化方案)

##### 6.5.1.1.1.备份目的地与挂载

#原则:备份必须与数据库存储处于不同故障域。本环境禁止以下目的地:

```logs
#  +FRA/+DATA磁盘组      --- 与数据库同在单点iSCSI上,存储一坏库和备份同时丢

#  RAC节点本机目录        --- 节点故障则备份不可达,且无法双节点互备

#  k8s-19rac-store节点   --- 它本身就是数据库存储,同一个单点
```



#要求:独立NFS/备份服务器(<NFS_SERVER>),所有RAC节点挂载同一路径/backup/rmanbak

```bash
#所有RAC节点(root);挂载参数适配RMAN直接读写(参考MOS 359515.1,actimeo=0为必须项)
mkdir -p /backup/rmanbak
mount -t nfs -o rw,bg,hard,nointr,rsize=1048576,wsize=1048576,tcp,vers=3,timeo=600,actimeo=0 <NFS_SERVER>:/export/rmanbak /backup/rmanbak

#/etc/fstab持久化
#<NFS_SERVER>:/export/rmanbak  /backup/rmanbak  nfs  rw,bg,hard,nointr,rsize=1048576,wsize=1048576,tcp,vers=3,timeo=600,actimeo=0  0 0

chown oracle:oinstall /backup/rmanbak
su - oracle -c "mkdir -p /backup/rmanbak/logs && touch /backup/rmanbak/testwrite && rm /backup/rmanbak/testwrite"
```

##### 6.5.1.1.2.一次性持久配置(任一节点执行一次,集群级生效)

```bash
su - oracle
rman target /
```

```
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/rmanbak/cf_%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+DATA/XYDB/CONTROLFILE/snapcf_xydb.f';
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;
SHOW ALL;
```

#!!!归档删除策略与ADG联动:
#未部署ADG阶段保持 TO NONE;第12章ADG部署完成后必须改为(见12.7节):
#CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

#开启块改变跟踪(BCT):level 1增量只扫描变化块,增量备份时间大幅缩短

```sql
alter database enable block change tracking using file '+DATA';
select status, filename from v$block_change_tracking;
```

##### 6.5.1.1.3.备份脚本(两节点相同部署)

#策略:周日 level 0 全备,周一~周六 level 1 增量;归档随每次备份并按删除策略清理
#脚本特性:

```conf
#  1)NFS互斥锁+当日成功防重 --- 两节点都配cron,正常仅节点一执行,节点一故障节点二自动接管

#  2)仅本地实例OPEN且角色PRIMARY才执行 --- 配ADG后角色互换不会误跑

#  3)退出码+RMAN错误堆栈双重判错,状态文件供监控采集

#  4)使用OS认证(target /),脚本中不出现任何口令
```



```bash
su - oracle
mkdir -p /home/oracle/rmanbak
vi /home/oracle/rmanbak/rmanbak.sh
chmod a+x /home/oracle/rmanbak/rmanbak.sh
```

#/home/oracle/rmanbak/rmanbak.sh

```bash
#!/bin/bash
#=====================================================================
# rmanbak.sh -- Oracle 19c RAC 物理备份   用法: rmanbak.sh L0|L1
#=====================================================================
BACKUP_BASE=/backup/rmanbak
LOCK_DIR=$BACKUP_BASE/.rman_lock
STATUS_FILE=$BACKUP_BASE/last_backup_status
LOG_DIR=$BACKUP_BASE/logs
LOG_KEEP_DAYS=30
LEVEL=${1:-L1}

[ -f $HOME/.bash_profile ] && . $HOME/.bash_profile

ts=$(date +"%Y%m%d_%H%M%S")
mkdir -p $LOG_DIR
LOG=$LOG_DIR/rman_${LEVEL}_${ts}_$(hostname -s).log

ok()   { echo "OK $(date +'%F %T') $LEVEL $(hostname -s)" > $STATUS_FILE; }
fail() { echo "FAIL $(date +'%F %T') $LEVEL $(hostname -s) $1" > $STATUS_FILE
         echo "[FATAL] $1" | tee -a $LOG; exit 1; }

#0.目的地必须真实挂载(防止NFS掉线后写进本地空目录造成假成功)
mountpoint -q $BACKUP_BASE || fail "NFS not mounted on $BACKUP_BASE"

#1.当日已成功则直接退出(两节点错峰场景防止重复备份)
grep -q "^OK $(date +%F)" $STATUS_FILE 2>/dev/null && exit 0

#2.NFS互斥锁(mkdir原子操作);锁存在超过12小时视为故障残留,清除后接管
if ! mkdir $LOCK_DIR 2>/dev/null; then
    if [ -n "$(find $BACKUP_BASE -maxdepth 1 -name .rman_lock -mmin +720 2>/dev/null)" ]; then
        rm -rf $LOCK_DIR
        mkdir $LOCK_DIR 2>/dev/null || exit 0
    else
        exit 0    #另一节点正在备份,正常退出
    fi
fi
echo "$(hostname -s) $ts" > $LOCK_DIR/owner
trap "rm -rf $LOCK_DIR" EXIT

#3.仅本地实例OPEN且数据库角色为PRIMARY时执行
ROLE_STAT=$(sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pagesize 0
select trim(d.database_role)||':'||trim(i.status) from v$database d, v$instance i;
SQL
)
echo "$ROLE_STAT" | grep -q "PRIMARY:OPEN" || fail "instance state=$ROLE_STAT, skip backup"

case $LEVEL in
  L0) INC="incremental level 0" ;;
  L1) INC="incremental level 1" ;;
  *)  fail "usage: $0 L0|L1" ;;
esac

#4.执行备份(并行度/压缩/控制文件自动备份由持久配置提供,不再手工allocate channel)
rman target / log=$LOG append <<EOF
run {
  backup as compressed backupset $INC database
    format '$BACKUP_BASE/db_${LEVEL}_%d_%T_%U'
    tag 'DB_${LEVEL}_${ts}';
  alter system archive log current;
  backup as compressed backupset archivelog all
    format '$BACKUP_BASE/arch_%d_%T_%U'
    tag 'ARCH_${ts}'
    delete input;
  crosscheck backup;
  crosscheck archivelog all;
  delete noprompt obsolete;
  delete noprompt expired backup;
}
exit;
EOF
RC=$?

#5.双重判错:rman退出码 + 错误堆栈标志RMAN-00569
if [ $RC -ne 0 ] || grep -q "RMAN-00569" $LOG; then
    fail "rman reported errors, check $LOG"
fi

ok
find $LOG_DIR -name 'rman_*.log' -mtime +$LOG_KEEP_DAYS -delete
exit 0
```

#说明:
#1)delete input受归档删除策略约束:配ADG后,未传输/未应用到备库的归档不会被删除,
#仅在日志中出现RMAN-08120/08137提示行,不属于失败(错误判定以RMAN-00569堆栈为准)
#2)未配ADG阶段(policy NONE)归档随备份即删,FRA仅作归档中转,不承担备份职能
#3)L0约定每周日;7天恢复窗口内任意时点 = 最近L0 + 后续L1 + 归档

##### 6.5.1.1.4.定时任务(两节点都配置,错峰10分钟)

```bash
#节点一 k8s-19rac01 (oracle用户 crontab -e)
30 0 * * 0   /home/oracle/rmanbak/rmanbak.sh L0 >/dev/null 2>&1
30 0 * * 1-6 /home/oracle/rmanbak/rmanbak.sh L1 >/dev/null 2>&1

#节点二 k8s-19rac02 错峰10分钟:
#正常情况下节点一在跑(互斥锁退出)或已成功(当日防重退出);节点一故障时自动接管
40 0 * * 0   /home/oracle/rmanbak/rmanbak.sh L0 >/dev/null 2>&1
40 0 * * 1-6 /home/oracle/rmanbak/rmanbak.sh L1 >/dev/null 2>&1
```

##### 6.5.1.1.5.恢复演练与备份有效性校验

#备份成功不等于可恢复;最低要求每月一次validate,每季度一次真实异机恢复

#/home/oracle/rmanbak/rman_validate.sh

```bash
#!/bin/bash
[ -f $HOME/.bash_profile ] && . $HOME/.bash_profile
LOG=/backup/rmanbak/logs/validate_$(date +%Y%m%d).log
STATUS=/backup/rmanbak/last_validate_status

rman target / log=$LOG <<EOF
restore database validate check logical;
restore controlfile validate;
restore archivelog from time 'sysdate-3' validate;
report need backup;
list backup summary;
exit;
EOF

if [ $? -ne 0 ] || grep -q "RMAN-00569" $LOG; then
    echo "FAIL $(date +'%F %T')" > $STATUS; exit 1
fi
echo "OK $(date +'%F %T')" > $STATUS
```

```bash
#每月第一个周六凌晨3点执行(节点一,validate会读全部备份片,放业务低谷)
0 3 * * 6 [ $(date +\%d) -le 7 ] && /home/oracle/rmanbak/rman_validate.sh >/dev/null 2>&1
```

#!!!validate只证明备份片可读且块校验通过,不等于恢复演练。
#每季度必须完成一次真实异机恢复(还原到测试机,或结合第12章ADG做switchover演练),
#记录实际恢复耗时并回填12.1节RTO;异机恢复步骤后续纳入应急手册章节

##### 6.5.1.1.6.监控对接与验收标准

```sql
--近7天备份作业概况(任一节点查询)
select start_time, end_time, status, input_type,
       round(input_bytes/1024/1024/1024,1) input_gb,
       round(output_bytes/1024/1024/1024,1) output_gb,
       round(elapsed_seconds/60) elapsed_min
from v$rman_backup_job_details
where start_time > sysdate - 7
order by start_time;
```

#验收标准(交付与日常巡检共用):
#1)/backup/rmanbak/last_backup_status 首行为"OK <当天日期>";监控按此告警:
#文件缺失、内容FAIL、日期非当日三种情况均告警(完整覆盖"静默失败")
#2)v$rman_backup_job_details近7天每天1条COMPLETED,周日为INCR L0
#3)report need backup无输出;list backup summary中最老备份不超过保留窗口+1天
#4)last_validate_status当月为OK;季度异机恢复演练有记录、有实测RTO
#监控对接:Zabbix用vfs.file.contents采集status文件,或node_exporter textfile collector暴露
#5)部署完成后立即归档DBID: `select dbid from v$database;` 的结果必须写入<NFS_SERVER>与变更记录;
#控制文件全损/异机恢复时需要 `set dbid <DBID>`,没有DBID会卡在恢复第一步。



#### 6.5.1.2.expdp/impdp逻辑备份与迁移(P1+v2.5.3按PDB子目录分文件并异地备份版)

#定位:
#1)Data Pump不能替代RMAN物理备份,只用于逻辑备份、对象级恢复、跨库迁移、上线前快照。
#2)本节要求按PDB分别导出,每个PDB生成独立dump/log/status目录,便于单PDB抽取恢复和异地留存。
#3)导出目录不得长期放在数据库本地盘或RAC节点单点目录;默认落独立NFS或备份服务器挂载目录。
#4)RAC环境用`cluster=n`固定在执行节点,避免dump/log分散到多个节点本地目录。
#5)本环境增加异地备份服务器:192.168.100.100,异地目录:/data。该目录必须位于数据库集群故障域之外。
#6)任何cron脚本必须有状态文件、日志检查、失败告警、异地同步校验和保留策略。
#7)安全边界:不推荐把口令直接写在命令行中,因为`ps`可见;生产优先使用Oracle Wallet/SEPS。
#若暂未配置wallet,至少使用600权限parfile并限制脚本/目录权限,且只写占位符不写真实口令。

##### 6.5.1.2.1.目录、异地服务器与权限

```bash
#所有可能执行expdp的节点都创建挂载点;建议由独立NFS提供
#v2.5.3重要修正:Data Pump文件由数据库服务端按DIRECTORY对象路径落盘;
#因此每个PDB必须有独立OS子目录,不能只靠脚本cd到子目录。
mkdir -p /backup/expdp/{stuwork,portal,onecode,dataassets}
chown -R oracle:oinstall /backup/expdp
chmod 750 /backup/expdp
chmod 750 /backup/expdp/{stuwork,portal,onecode,dataassets}

#确认NFS/备份目录不是本地根盘;输出应显示独立文件系统
su - oracle -c 'df -h /backup/expdp; touch /backup/expdp/.rwtest && rm -f /backup/expdp/.rwtest'
for p in stuwork portal onecode dataassets; do
  su - oracle -c "touch /backup/expdp/${p}/.rwtest && rm -f /backup/expdp/${p}/.rwtest"
done

#异地备份服务器,按实际创建SSH用户并配置免密;默认示例用户为backup,可改为oracle或备份平台用户
#异地目录统一放在192.168.100.100:/data/xydb/expdp/<PDB>/
REMOTE_USER=<EXPDP_REMOTE_USER>
REMOTE_HOST=192.168.100.100
REMOTE_BASE=/data

#在异地备份服务器上预建目录(在192.168.100.100执行)
mkdir -p /data/xydb/expdp/{stuwork,portal,onecode,dataassets}
chown -R ${REMOTE_USER}:${REMOTE_USER} /data/xydb/expdp
chmod -R 750 /data/xydb/expdp

#在RAC执行节点oracle用户上验证免密和写入能力
su - oracle -c "ssh ${REMOTE_USER}@${REMOTE_HOST} 'mkdir -p ${REMOTE_BASE}/xydb/expdp/.check && rmdir ${REMOTE_BASE}/xydb/expdp/.check'"
```

```sql
--在每个需要导出的PDB中创建同名DIRECTORY对象。不要在CDB root误建目录后就认为PDB可用。
--v2.5.3要求每个PDB的EXPDP_DIR指向自己的OS子目录,保证dump/log/status按PDB物理隔离。
--full=y需要DATAPUMP_EXP_FULL_DATABASE角色;当前示例账号具备DBA时可覆盖,若将来改最小权限账号需显式授权。
alter session set container=stuwork;
create or replace directory EXPDP_DIR as '/backup/expdp/stuwork';
grant read,write on directory EXPDP_DIR to system;
--grant DATAPUMP_EXP_FULL_DATABASE to system;

alter session set container=portal;
create or replace directory EXPDP_DIR as '/backup/expdp/portal';
grant read,write on directory EXPDP_DIR to portaluser;
--grant DATAPUMP_EXP_FULL_DATABASE to portaluser;

alter session set container=onecode;
create or replace directory EXPDP_DIR as '/backup/expdp/onecode';
grant read,write on directory EXPDP_DIR to onecodeuser;
--grant DATAPUMP_EXP_FULL_DATABASE to onecodeuser;

alter session set container=dataassets;
create or replace directory EXPDP_DIR as '/backup/expdp/dataassets';
grant read,write on directory EXPDP_DIR to pdbadmin;
--grant DATAPUMP_EXP_FULL_DATABASE to pdbadmin;

select sys_context('USERENV','CON_NAME') con_name, owner, directory_name, directory_path
from dba_directories
where directory_name='EXPDP_DIR';

--验收:directory_path必须分别为 /backup/expdp/<PDB>,禁止全部指向扁平的/backup/expdp
```

##### 6.5.1.2.2.按PDB手工导出/导入模板

```bash
#示例:导出dataassets PDB,生成独立文件名前缀 dataassets_YYYYMMDD_HH24MISS_%U.dmp
#生产优先使用wallet连接: expdp userid=/@s_dataassets parfile=exp_dataassets.par
#未配置wallet时,使用600权限parfile,避免口令出现在ps命令行;parfile内仍只能写占位符,真实口令由保密渠道替换。
umask 077
DATE_TAG=$(date +%Y%m%d_%H%M%S)
PDB_DIR=/backup/expdp/dataassets
mkdir -p ${PDB_DIR}
cat > ${PDB_DIR}/exp_dataassets_${DATE_TAG}.par <<EOF
userid=pdbadmin/<DSA_PWD>@rac-scan:1521/s_dataassets
full=y
directory=EXPDP_DIR
dumpfile=dataassets_${DATE_TAG}_%U.dmp
logfile=dataassets_${DATE_TAG}.log
job_name=EXPDP_DATAASSETS_${DATE_TAG}
filesize=20G
parallel=2
compression=all
cluster=n
metrics=y
logtime=all
EOF
expdp parfile=${PDB_DIR}/exp_dataassets_${DATE_TAG}.par
[ -f "${PDB_DIR}/dataassets_${DATE_TAG}.log" ] || { echo "expdp log not found"; exit 1; }

#异地同步单个PDB导出文件
rsync -av --partial --checksum ${PDB_DIR}/dataassets_${DATE_TAG}_*.dmp ${PDB_DIR}/dataassets_${DATE_TAG}.log   <EXPDP_REMOTE_USER>@192.168.100.100:/data/xydb/expdp/dataassets/

#导入前必须先确认目标PDB、表空间、用户配额、字符集和对象冲突
cat > ${PDB_DIR}/imp_dataassets_${DATE_TAG}.par <<EOF
userid=pdbadmin/<DSA_PWD>@rac-scan:1521/s_dataassets
directory=EXPDP_DIR
dumpfile=dataassets_${DATE_TAG}_%U.dmp
logfile=imp_dataassets_${DATE_TAG}.log
full=y
table_exists_action=skip
cluster=n
metrics=y
logtime=all
EOF
impdp parfile=${PDB_DIR}/imp_dataassets_${DATE_TAG}.par
```

#常见错误闭环:
#- full=y权限: 若导出账号不是DBA,必须在对应PDB授予DATAPUMP_EXP_FULL_DATABASE角色,否则会报权限不足。
#- ORA-01950: no privileges on tablespace: 给导入用户目标表空间quota,不要简单`grant dba`了事。
#- ORA-31626/ORA-31633: 检查master table创建权限、默认表空间、目录权限与剩余空间。
#- dump跨版本: 高版本导向低版本时加`version=<目标版本>`。
#- 异地rsync失败: 先确认SSH免密、远端目录权限、192.168.100.100:/data空间,再重跑同步,不要删除本地当日dump。

##### 6.5.1.2.3.生产化expdp脚本模板:多PDB分文件+异地同步

```bash
cat > /home/oracle/expdp_pdb_backup.sh <<'EOF'
#!/bin/bash
set -u
umask 077
source /home/oracle/.bash_profile

DB_UNIQUE_NAME="xydb"
SCAN_HOST="rac-scan"
LISTENER_PORT="1521"
EXP_DIR="EXPDP_DIR"
BASE_DIR="/backup/expdp"
RETENTION_DAYS=7
REMOTE_RETENTION_DAYS=14
REMOTE_USER="<EXPDP_REMOTE_USER>"        #按实际修改,例如backup/oracle
REMOTE_HOST="192.168.100.100"
REMOTE_BASE="/data"
CONNECT_MODE="password"                 #生产优先改为wallet,并把CONNECT_STRING切换为/@service
DATE_TAG=$(date +%Y%m%d_%H%M%S)
SUMMARY_STATUS="${BASE_DIR}/last_expdp_status"
SUMMARY_LOG="${BASE_DIR}/expdp_driver_${DATE_TAG}.log"

#格式:PDB_NAME:SERVICE:ADMIN_USER:PASSWORD_PLACEHOLDER:PARALLEL
#如已配置Wallet/SEPS,PASSWORD_PLACEHOLDER可保留占位,实际连接走/@SERVICE。
PDB_CONFIGS=(
  "stuwork:s_stuwork:system:<SYS_PWD>:2"
  "portal:s_portal:portaluser:<PORTAL_PWD>:2"
  "onecode:s_onecode:onecodeuser:<ONECODE_PWD>:2"
  "dataassets:s_dataassets:pdbadmin:<DSA_PWD>:2"
)

PASS=0
FAIL=0
mkdir -p "${BASE_DIR}"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "${SUMMARY_LOG}"; }
write_status(){ local pdb="$1" status="$2" msg="$3"; echo "${status} $(date '+%F %T') ${msg}" > "${BASE_DIR}/${pdb}/last_expdp_status"; }
mark_fail(){ local pdb="$1" msg="$2"; FAIL=$((FAIL+1)); write_status "$pdb" "FAIL" "$msg"; log "[FAIL][$pdb] $msg"; }
mark_ok(){ local pdb="$1" msg="$2"; PASS=$((PASS+1)); write_status "$pdb" "OK" "$msg"; log "[OK][$pdb] $msg"; }

[ -w "${BASE_DIR}" ] || { echo "FAIL $(date '+%F %T') ${BASE_DIR} not writable" > "${SUMMARY_STATUS}"; exit 1; }
df -h "${BASE_DIR}" | tee -a "${SUMMARY_LOG}"

for item in "${PDB_CONFIGS[@]}"; do
  IFS=':' read -r PDB_NAME PDB_SERVICE ADMIN_USER ADMIN_PWD PARALLEL_DEGREE <<< "${item}"
  PDB_DIR="${BASE_DIR}/${PDB_NAME}"
  mkdir -p "${PDB_DIR}"
  chmod 750 "${PDB_DIR}"
  #注意:Data Pump的dump/log由数据库服务端写入EXPDP_DIR对应路径,不是由客户端当前目录决定。
  #v2.5.3要求EXPDP_DIR在各PDB内分别指向 /backup/expdp/<PDB>,否则下方日志检查和rsync会找不到文件。

  LOG_FILE="${PDB_NAME}_${DATE_TAG}.log"
  DUMP_FILE="${PDB_NAME}_${DATE_TAG}_%U.dmp"
  JOB_NAME="EXPDP_${PDB_NAME^^}_${DATE_TAG}"
  PARFILE="${PDB_DIR}/expdp_${PDB_NAME}_${DATE_TAG}.par"
  REMOTE_DIR="${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp/${PDB_NAME}"

  if [ "${CONNECT_MODE}" = "wallet" ]; then
    CONNECT_STRING="/@${PDB_SERVICE}"
  else
    CONNECT_STRING="${ADMIN_USER}/${ADMIN_PWD}@${SCAN_HOST}:${LISTENER_PORT}/${PDB_SERVICE}"
  fi

  log "[START][${PDB_NAME}] service=${PDB_SERVICE} dump=${DUMP_FILE}"
  cat > "${PARFILE}" <<PAR
userid=${CONNECT_STRING}
full=y
directory=${EXP_DIR}
dumpfile=${DUMP_FILE}
logfile=${LOG_FILE}
job_name=${JOB_NAME}
filesize=20G
parallel=${PARALLEL_DEGREE}
compression=all
cluster=n
metrics=y
logtime=all
PAR
  chmod 600 "${PARFILE}"

  (cd "${PDB_DIR}" && expdp parfile="${PARFILE}") >> "${SUMMARY_LOG}" 2>&1
  RC=$?
  if [ ${RC} -ne 0 ]; then
    mark_fail "${PDB_NAME}" "expdp rc=${RC}, parfile=${PARFILE}, driver=${SUMMARY_LOG}"
    continue
  fi

  #Data Pump即使返回0也要扫描日志中的错误;ORA-31684对象已存在可按导入场景豁免,导出场景一般不应出现ORA-
  if [ ! -f "${PDB_DIR}/${LOG_FILE}" ]; then
    mark_fail "${PDB_NAME}" "log not found: ${PDB_DIR}/${LOG_FILE}; check EXPDP_DIR path in PDB"
    continue
  fi
  if grep -E "ORA-|UDE-|UDI-" "${PDB_DIR}/${LOG_FILE}" | grep -v "ORA-31684" >> "${SUMMARY_LOG}" 2>&1; then
    mark_fail "${PDB_NAME}" "expdp log contains ORA/UDE/UDI: ${PDB_DIR}/${LOG_FILE}"
    continue
  fi

  #异地同步:192.168.100.100:/data/xydb/expdp/<PDB>/
  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '${REMOTE_DIR}'" >> "${SUMMARY_LOG}" 2>&1
  if [ $? -ne 0 ]; then
    mark_fail "${PDB_NAME}" "remote mkdir failed: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
    continue
  fi

  rsync -av --partial --checksum --timeout=300 \
    "${PDB_DIR}/${PDB_NAME}_${DATE_TAG}_"*.dmp \
    "${PDB_DIR}/${LOG_FILE}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" >> "${SUMMARY_LOG}" 2>&1
  if [ $? -ne 0 ]; then
    mark_fail "${PDB_NAME}" "rsync failed to ${REMOTE_HOST}:${REMOTE_DIR}"
    continue
  fi

  #远端至少应能看到本PDB当日log和一个dump片段
  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
    "test -s '${REMOTE_DIR}/${LOG_FILE}' && ls '${REMOTE_DIR}/${PDB_NAME}_${DATE_TAG}_'*.dmp >/dev/null 2>&1" >> "${SUMMARY_LOG}" 2>&1
  if [ $? -ne 0 ]; then
    mark_fail "${PDB_NAME}" "remote validation failed: ${REMOTE_HOST}:${REMOTE_DIR}"
    continue
  fi

  mark_ok "${PDB_NAME}" "local=${PDB_DIR}/${LOG_FILE}; remote=${REMOTE_HOST}:${REMOTE_DIR}"
done

#本地保留策略:每个PDB独立清理
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.dmp' -mtime +${RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.log' -mtime +${RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name 'expdp_*.par' -mtime +${RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -maxdepth 1 -name 'expdp_driver_*.log' -mtime +${RETENTION_DAYS} -type f -delete

#远端保留策略:只删除本目录下过期dmp/log,不要删除其他备份类型
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
  "find '${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp' -type f \( -name '*.dmp' -o -name '*.log' \) -mtime +${REMOTE_RETENTION_DAYS} -delete" >> "${SUMMARY_LOG}" 2>&1 || \
  log "[WARN] remote retention cleanup failed, manual check required"

if [ ${FAIL} -eq 0 ]; then
  echo "OK $(date '+%F %T') PASS=${PASS} FAIL=0 remote=${REMOTE_HOST}:${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] OK PASS=${PASS} FAIL=0"
  exit 0
else
  echo "FAIL $(date '+%F %T') PASS=${PASS} FAIL=${FAIL} remote=${REMOTE_HOST}:${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] FAIL PASS=${PASS} FAIL=${FAIL}"
  exit 1
fi
EOF

chmod 700 /home/oracle/expdp_pdb_backup.sh
chown oracle:oinstall /home/oracle/expdp_pdb_backup.sh
#若CONNECT_MODE=password,脚本模板会集中保存各PDB口令占位符;替换真实口令后必须保持700权限,避免oinstall组内其他用户读取。
```

##### 6.5.1.2.4.cron与验收

```bash
#建议先手工实跑,确认所有PDB状态文件和汇总状态文件OK后再进入cron
su - oracle -c '/home/oracle/expdp_pdb_backup.sh'
cat /backup/expdp/last_expdp_status
for p in stuwork portal onecode dataassets; do cat /backup/expdp/${p}/last_expdp_status; done

#确认本地按PDB分文件生成
find /backup/expdp -maxdepth 2 -type f \( -name '*.dmp' -o -name '*.log' \) | sort

#确认异地服务器已有每个PDB目录和文件
su - oracle -c "ssh <EXPDP_REMOTE_USER>@192.168.100.100 'find /data/xydb/expdp -maxdepth 2 -type f | sort | tail -50'"

#cron示例:只在一个指定节点启用;更高要求可注册为cluster resource,避免节点宕机后静默中断
crontab -l > /tmp/oracle.cron.$(date +%F)
cat >> /tmp/oracle.cron.$(date +%F) <<EOF
#P1 expdp logical backup by PDB; remote copy to 192.168.100.100:/data; monitor /backup/expdp/last_expdp_status
30 2 * * * /home/oracle/expdp_pdb_backup.sh >/backup/expdp/expdp_cron.log 2>&1
EOF
crontab /tmp/oracle.cron.$(date +%F)
```

#验收标准:
#1)`/backup/expdp/last_expdp_status`首字段为OK且日期为当天;
#2)`/backup/expdp/stuwork|portal|onecode|dataassets/last_expdp_status`均为OK;
#3)每个PDB至少生成1个dump和1个log,文件名前缀包含PDB名和时间戳,且本地路径为/backup/expdp/<PDB>/;
#4)192.168.100.100:/data/xydb/expdp/<PDB>/下存在对应dump/log;
#5)expdp日志无未解释的ORA-/UDE-/UDI-;
#6)dump/log落在独立NFS/备份服务器,不是RAC本地盘或+FRA;
#7)至少每季度抽取一份dump做impdp验证,验证记录写入14.3或恢复演练台账;
#8)生产优先改造为wallet/SEPS;若使用parfile,权限必须为600,且不得把真实口令回填文档。

#### 6.5.2.OCR/Voting File/OLR备份与恢复

##### 6.5.2.1.自动备份机制与检查

#CRS每4小时自动备份OCR(保留最近3份4小时备份、1份日备、1份周备),由master节点执行
#!!!本环境共享存储是单台iSCSI虚拟机(单点),OCR备份必须定期复制到集群之外的独立NFS/备份服务器;store节点同属故障域,只能作为临时副本

```bash
su - grid

#查看自动备份
ocrconfig -showbackup auto

#查看/修改备份位置(19c支持放入ASM磁盘组,任一节点可见;也可保持默认Grid Home本地目录)
ocrconfig -showbackuploc

#root执行(可选,放入FRA磁盘组)
/u01/app/19.0.0/grid/bin/ocrconfig -backuploc +FRA
```

##### 6.5.2.2.手工备份与逻辑导出(纳入定时任务)

#打RU补丁、加删节点、修改集群配置(srvctl modify/crsctl set)之前必做一次手工备份

```bash
#root用户
#物理手工备份
/u01/app/19.0.0/grid/bin/ocrconfig -manualbackup
/u01/app/19.0.0/grid/bin/ocrconfig -showbackup manual

#逻辑导出
mkdir -p /home/grid/ocrbak
/u01/app/19.0.0/grid/bin/ocrconfig -export /home/grid/ocrbak/ocr_export_$(date +%Y%m%d).ocr

#OCR一致性检查
/u01/app/19.0.0/grid/bin/ocrcheck
/u01/app/19.0.0/grid/bin/cluvfy comp ocr -n all -verbose
```

#定时任务示例(节点一root crontab,每周一次,并复制到集群外)

```bash
0 1 * * 1 /u01/app/19.0.0/grid/bin/ocrconfig -manualbackup >> /home/grid/ocrbak/ocrbak.log 2>&1
10 1 * * 1 /u01/app/19.0.0/grid/bin/ocrconfig -export /home/grid/ocrbak/ocr_export_$(date +\%Y\%m\%d).ocr >> /home/grid/ocrbak/ocrbak.log 2>&1
20 1 * * 1 rsync -a /home/grid/ocrbak/ root@<NFS_SERVER>:/backup/ocr/ >> /home/grid/ocrbak/ocrbak.log 2>&1
#可选临时副本:store与数据库同故障域,不算离线备份;需要本地快速恢复副本时再取消下一行注释
#25 1 * * 1 scp /home/grid/ocrbak/ocr_export_*.ocr root@k8s-19rac-store:/backup/ocr/ >> /home/grid/ocrbak/ocrbak.log 2>&1
#定期清理:find /home/grid/ocrbak -name 'ocr_export_*.ocr' -mtime +60 -delete
```

#外置备份校验(纳入巡检):只存在于+FRA或RAC本机目录的OCR备份不算真正离线备份;
#store节点本身也是单点,OCR导出件必须至少另存一份到独立NFS/备份服务器

```bash
ocrconfig -showbackup
ls -lh /home/grid/ocrbak
ssh root@<NFS_SERVER> "ls -lh /backup/ocr/"
#可选临时副本核对: ssh root@k8s-19rac-store "ls -lh /backup/ocr/"
```


##### 6.5.2.2a.store节点配置备份(P0必做)

#背景:本环境由k8s-19rac-store导出iSCSI LUN。store全损重建时,仅有OCR/RMAN备份还不够;
#若targets.conf、LUN顺序、SCSI ID/ID_SERIAL、RAC节点udev规则无法恢复一致,ASM磁盘可能全部找不到。
#因此store配置和RAC侧磁盘映射必须和OCR导出件一样复制到独立<NFS_SERVER>。

```bash
#store节点root执行:采集iSCSI服务端配置、LUN定义、导出状态
mkdir -p /root/store_cfgbak
cp -a /etc/tgt/targets.conf /root/store_cfgbak/targets.conf.$(date +%F)
tgt-admin -dump > /root/store_cfgbak/tgt_admin_dump.$(date +%F).txt
tgtadm --lld iscsi --mode target --op show > /root/store_cfgbak/tgtadm_show.$(date +%F).txt
lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,WWN > /root/store_cfgbak/lsblk_store.$(date +%F).txt
for d in /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf /dev/vdg /dev/vdh; do
  [ -e "$d" ] && echo -n "$d " && /usr/lib/udev/scsi_id -g -u -d "$d" 2>/dev/null
done > /root/store_cfgbak/store_scsi_id.$(date +%F).txt
rsync -a /root/store_cfgbak/ root@<NFS_SERVER>:/backup/store_cfg/k8s-19rac-store/
```

```bash
#每个RAC节点root执行:采集udev规则、ASM稳定设备名、iSCSI session与by-path映射
mkdir -p /root/rac_diskmap_bak
cp -a /etc/udev/rules.d/99-oracle-asmdevices.rules /root/rac_diskmap_bak/99-oracle-asmdevices.rules.$(hostname).$(date +%F) 2>/dev/null
ls -l /dev/oracleasm/disks/ > /root/rac_diskmap_bak/oracleasm_disks.$(hostname).$(date +%F).txt
ls -l /dev/disk/by-path/ | grep iscsi > /root/rac_diskmap_bak/by_path_iscsi.$(hostname).$(date +%F).txt
iscsiadm -m session -P 3 > /root/rac_diskmap_bak/iscsi_session_P3.$(hostname).$(date +%F).txt
for d in /dev/sd?; do
  [ -e "$d" ] && echo -n "$d " && /usr/lib/udev/scsi_id -g -u -d "$d" 2>/dev/null
done > /root/rac_diskmap_bak/scsi_id.$(hostname).$(date +%F).txt
rsync -a /root/rac_diskmap_bak/ root@<NFS_SERVER>:/backup/store_cfg/$(hostname)/
```

#纳入定时任务建议:每次新增/删除LUN、调整targets.conf、修改udev规则、加删节点、重建store前后立即执行;
#平时每月执行一次配置快照即可。恢复时以<NFS_SERVER>上的store_cfg为准,先恢复LUN顺序和导出配置,再启动RAC节点。

##### 6.5.2.3.Voting File检查

#11.2起voting file随OCR所在磁盘组由ASM自动管理,不需要也不支持dd方式手工备份
#磁盘组完好时无需干预;磁盘组损坏时用crsctl replace votedisk重建(见6.5.2.6)

```bash
crsctl query css votedisk
#期望:+OCR磁盘组内3份(NORMAL冗余对应3个failgroup)
```

##### 6.5.2.4.OLR(本地注册表)备份与恢复

#OLR每节点一份,GI安装/升级后会自动备份一次;打补丁前建议各节点手工备份
#前文1.7.2节遇到的ocrcheck -local报错即OLR损坏场景

```bash
#root,每个节点分别执行
/u01/app/19.0.0/grid/bin/ocrcheck -local
/u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup
/u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

#OLR损坏恢复(仅故障节点)
crsctl stop crs -f

#!!!恢复文件以-showbackup输出为准,不要照抄路径
#19c的OLR备份位于$ORACLE_BASE/crsdata/<节点名>/olr/目录,例如:
#/u01/app/grid/crsdata/k8s-19rac01/olr/backup_20231118_183548.olr
#注意1.7.2节真实案例:autobackup_*.olr可能报PROTL-24不可用,优先使用backup_*.olr手工备份
/u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
/u01/app/19.0.0/grid/bin/ocrconfig -local -restore <上一步输出的可用.olr备份文件>

crsctl start crs
```

##### 6.5.2.5.恢复场景一:OCR内容损坏,+OCR磁盘组完好

```bash
#1.所有节点停CRS(root,每个节点执行)
crsctl stop crs -f

#2.仅节点一以独占模式启动(不启动CRSD)
crsctl start crs -excl -nocrs

#3.恢复OCR(物理备份或逻辑导出二选一)
ocrconfig -showbackup
ocrconfig -restore /u01/app/19.0.0/grid/cdata/k8s-19rac-cluster/backup00.ocr
#或: ocrconfig -import /home/grid/ocrbak/ocr_export_20260601.ocr

#4.校验并重启全部节点CRS
ocrcheck
crsctl stop crs -f
crsctl start crs          #所有节点依次执行
crsctl stat res -t
cluvfy comp ocr -n all -verbose
```

##### 6.5.2.6.恢复场景二:+OCR磁盘组整体丢失(含voting file)

#存储级故障导致ocr01/02/03三块盘全部不可用时使用;前提:存在manualbackup或export备份
#本环境经历过ASM磁盘组挂载故障,此场景必须演练
#!!!执行前强制确认:
#1)仅适用于+OCR磁盘组确认完全丢失且有可用OCR备份的场景
#2)必须确认DATA/FRA磁盘组未被误初始化;禁止对任何未确认归属的磁盘执行create diskgroup
#3)重建前保存所有节点alert/ocssd/crsd日志及磁盘头信息(kfed read <磁盘> 输出留档)

```bash
#1.所有节点停CRS(root)
crsctl stop crs -f

#2.节点一独占模式启动
crsctl start crs -excl -nocrs

#3.重建OCR磁盘组(磁盘路径按udev实际规则;若旧盘头损坏需先确认底层LUN已恢复)
su - grid
sqlplus / as sysasm
create diskgroup OCR normal redundancy
  disk '/dev/oracleasm/disks/OCR01','/dev/oracleasm/disks/OCR02','/dev/oracleasm/disks/OCR03'
  attribute 'compatible.asm'='19.0';
exit

#4.恢复OCR(root)
ocrconfig -restore /u01/app/19.0.0/grid/cdata/k8s-19rac-cluster/backup00.ocr

#5.重建voting file
crsctl replace votedisk +OCR
crsctl query css votedisk

#6.若ASM spfile也存放在该磁盘组,需要重建
su - grid
sqlplus / as sysasm
create spfile='+OCR' from memory;
exit

#7.重启验证(所有节点)
crsctl stop crs -f
crsctl start crs
crsctl stat res -t
ocrcheck
cluvfy comp ocr -n all -verbose
```

#!!!演练与SOP要求:
#1)每半年按场景一实际演练一次,演练前先做manualbackup
#2)机房断电恢复顺序必须固化:k8s-19rac-store先启动并确认tgtd/LUN就绪 ---> RAC节点再启动
#RAC节点启动后检查:iscsiadm -m session、ls -l /dev/asm-*、crsctl stat res -t、ASM磁盘组全部MOUNTED




#### 6.5.3.RMAN恢复演练(P1必做)

#原则:没有恢复演练的备份不算可用备份。本节用于把6.5.1 RMAN备份转化为可审计、可执行的恢复能力。
#每次演练必须记录:演练日期、负责人、备份片位置、起止时间、RTO、是否成功、问题与修正。

#### 6.5.3.1.演练前通用检查

```bash
su - oracle
rman target /
```

```rman
show all;
list backup summary;
report obsolete;
report need backup;
restore database validate;
restore archivelog from time 'sysdate-1' validate;
```

#验收标准:
#1)`restore ... validate`无RMAN-06023/RMAN-06025等缺失备份错误;
#2)备份片位于独立NFS/备份服务器,不是单独依赖+FRA或store;
#3)若启用ADG,归档删除策略必须与12.7一致,避免主库删除备库未应用归档。

#### 6.5.3.2.场景一:单数据文件丢失恢复

#适用:单个非SYSTEM数据文件误删、磁盘错误、数据文件offline。

```sql
--定位数据文件
set lines 200
col file_name for a80
select file_id,tablespace_name,file_name,status from dba_data_files order by file_id;
```

```rman
--示例:恢复file 7,按实际替换
sql 'alter database datafile 7 offline';
restore datafile 7;
recover datafile 7;
sql 'alter database datafile 7 online';
```

```sql
select file#,status,error from v$recover_file;
select file_id,tablespace_name,status from dba_data_files where file_id=7;
```

#### 6.5.3.3.场景二:控制文件恢复

#适用:控制文件损坏或丢失。RAC环境操作前先停库,确保备份控制文件和spfile可用。

```bash
srvctl stop database -d xydb -o immediate
rman target /
```

```rman
#控制文件全损时,RMAN无法从控制文件读取CONFIGURE CONTROLFILE AUTOBACKUP FORMAT,
#必须先设置DBID和autobackup格式;DBID见6.5.1.1.6交付记录。
set dbid <DBID>;
startup nomount;
run {
  set controlfile autobackup format for device type disk to '/backup/rmanbak/cf_%F';
  restore controlfile from autobackup;
}
alter database mount;
catalog start with '/backup/rmanbak/' noprompt;
recover database;
alter database open resetlogs;
```

#如使用恢复目录或明确控制文件备份片,按实际路径替换`restore controlfile from '<piece>'`。
#resetlogs后必须立即做一次全备,并记录新的incarnation。

```rman
list incarnation;
backup incremental level 0 database plus archivelog;
```

#### 6.5.3.4.场景三:PITR时间点恢复

#适用:误删表、误更新、批处理写错。优先考虑表级flashback/expdp恢复;只有影响范围大时做库级PITR。

```bash
#RAC库级PITR前必须停全库,只保留一个实例以mount方式恢复;禁止其他实例仍处于open状态。
srvctl stop database -d xydb -o immediate
export ORACLE_SID=xydb1
sqlplus / as sysdba <<'SQL'
startup mount;
SQL
rman target /
```

```rman
run {
  set until time "to_date('2026-01-01 10:30:00','yyyy-mm-dd hh24:mi:ss')";
  restore database;
  recover database;
}
alter database open resetlogs;
```

```bash
#resetlogs后再通过srvctl恢复RAC管理状态,并立即做一次L0全备
srvctl status database -d xydb
```

#PITR会产生resetlogs,影响主备关系和后续备份链。生产执行前必须有审批、业务确认和ADG重建/刷新方案。

#### 6.5.3.5.场景四:异机全库恢复

#适用:主集群不可用、存储全损、灾备恢复验证。异机恢复必须至少季度演练一次。

```bash
#目标主机准备:
#1)安装同版本Oracle软件与必要补丁;
#2)准备相同或可转换的目录/ASM磁盘组;
#3)复制spfile/password file/RMAN备份片;
#4)配置ORACLE_SID/ORACLE_HOME。
```

```rman
#异机全库恢复必须先设置DBID;DBID需在日常交付记录/NFS备份目录中保存。
set dbid <DBID>;
startup nomount;
run {
  set controlfile autobackup format for device type disk to '/backup/rmanbak/cf_%F';
  restore spfile from autobackup;
}
shutdown immediate;
startup nomount;
run {
  set controlfile autobackup format for device type disk to '/backup/rmanbak/cf_%F';
  restore controlfile from autobackup;
}
alter database mount;
catalog start with '/backup/rmanbak/' noprompt;
restore database;
recover database;
alter database open resetlogs;
```

#异机恢复验收:
#1)数据库open read write;
#2)PDB全部open;
#3)核心业务schema对象数量、无效对象、关键表行数抽查通过;
#4)记录实测RTO/RPO;
#5)resetlogs后立即做全备。

### 6.6. Oracle RAC其他操作
#创建pdb

```oracle
create pluggable database portal admin user portaluser identified by <PORTAL_PWD> roles=(dba);

alter pluggable database portal open;
alter session set container=portal;
grant dba to portaluser;
#如果不赋权，那么没有system表空间的权限
SQL> create table test as select * from dba_users;
create table test as select * from dba_users
                                   *
ERROR at line 1:
ORA-01950: no privileges on tablespace 'SYSTEM'


create tablespace PORTAL_SERVICE datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

alter tablespace PORTAL_SERVICE add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

create user PORTAL_SERVICE_V6 identified by <PORTAL_PWD> default tablespace PORTAL_SERVICE account unlock;

grant dba to PORTAL_SERVICE_V6;

grant select any table to PORTAL_SERVICE_V6;

------------------------------------------------


------------------------------------
create pluggable database onecode admin user onecodeuser identified by <ONECODE_PWD> roles=(dba);

alter pluggable database onecode open;
alter session set container=onecode;
grant dba to onecodeuser；

create pluggable database dataassets admin user pdbadmin identified by <DSA_PWD> roles=(dba);

alter pluggable database dataassets open;
alter session set container=dataassets;
grant dba to pdbadmin;
```
#连接方式

```bash
srvctl add service -d xydb -s s_portal -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb portal

srvctl start service -d xydb -s s_portal
srvctl status service -d xydb -s s_portal

sqlplus portaluser/<PORTAL_PWD>@172.18.13.176:1521/s_portal

--------------------------------
srvctl add service -d xydb -s s_onecode -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb onecode

srvctl start service -d xydb -s s_onecode
srvctl status service -d xydb -s s_onecode

sqlplus onecodeuser/<ONECODE_PWD>@172.18.13.176:1521/s_onecode

--------------------------------
srvctl add service -d xydb -s s_dataassets -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets

srvctl start service -d xydb -s s_dataassets
srvctl status service -d xydb -s s_dataassets

sqlplus pdbadmin/<DSA_PWD>@172.18.13.176:1521/s_dataassets

---------------------------------

#oracle 19c rac add service

srvctl add service -d xydb -s s_portal -pdb portal -preferred xydb1,xydb2,xydb3 -policy BASIC -failovertype SELECT -failovermethod BASIC -failoverretry 180  -failoverdelay 5


srvctl add service -d xydb -s s_portal \
  -pdb portal \                       # 指定PDB名称
  -preferred xydb1,xydb2,xydb3 \      # 首选实例
  -policy BASIC \                     # 故障转移策略
  -failovertype SELECT \              # 故障转移类型
  -failovermethod BASIC \             # 故障转移方法
  -failoverretry 180 \                # 故障转移重试时间
  -failoverdelay 5                    # 故障转移等待时间


```







### 6.7. Oracle RAC更改PDB的字符集

```
 SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 JMUPDB			  READ WRITE NO
	 4 DATAASSETS			  READ WRITE NO
	 5 EOTQPDB			  READ WRITE NO
	 6 EAMSPDB			  READ WRITE NO
	 7 CWPDB			  READ WRITE NO
	 8 RPTPDB			  READ WRITE NO
	 9 HRPDB			  READ WRITE NO

SQL> alter pluggable database hrpdb close immediate instances=all;

Pluggable database altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 JMUPDB			  READ WRITE NO
	 4 DATAASSETS			  READ WRITE NO
	 5 EOTQPDB			  READ WRITE NO
	 6 EAMSPDB			  READ WRITE NO
	 7 CWPDB			  READ WRITE NO
	 8 RPTPDB			  READ WRITE NO
	 9 HRPDB			  MOUNTED
SQL> alter pluggable database hrpdb  open read write restricted;

Pluggable database altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 JMUPDB			  READ WRITE NO
	 4 DATAASSETS			  READ WRITE NO
	 5 EOTQPDB			  READ WRITE NO
	 6 EAMSPDB			  READ WRITE NO
	 7 CWPDB			  READ WRITE NO
	 8 RPTPDB			  READ WRITE NO
	 9 HRPDB			  READ WRITE YES
SQL> alter session set container=hrpdb;

Session altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
----------------------------------------------------
AMERICAN_AMERICA.AL32UTF8

SQL> alter database character set internal_use ZHS16GBK;

Database altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
--------------------------------------------------------------------------------
AMERICAN_AMERICA.ZHS16GBK

SQL> alter pluggable database hrpdb close immediate;

Pluggable database altered.

SQL> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 9 HRPDB			  MOUNTED
SQL> alter pluggable database hrpdb open instances=all;

Pluggable database altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
--------------------------------------------------------------------------------
AMERICAN_AMERICA.ZHS16GBK

SQL> alter session set container=jmupdb;

Session altered.

SQL> select userenv('language') from dual;

USERENV('LANGUAGE')
----------------------------------------------------
AMERICAN_AMERICA.AL32UTF8

SQL> 

```






## 7 打补丁

### 7.0.P1季度RU补丁运维策略(先读本节,再看历史执行记录)

#定位:
#1)下方7.1/7.2保留的是本环境19.20、19.21的历史执行记录,可用于理解opatchauto流程,不能照抄版本号。
#2)新环境或后续运维应按Oracle当季RU重新下载补丁、阅读README、做冲突检查和演练。
#3)补丁策略必须覆盖:补丁前备份、冲突检查、rolling顺序、datapatch、回退、补丁后验收。

#### 7.0.1.补丁前准备

```bash
#所有节点记录当前版本和补丁清单
su - grid -c '$ORACLE_HOME/OPatch/opatch version; $ORACLE_HOME/OPatch/opatch lspatches; $ORACLE_HOME/OPatch/opatch lsinventory -detail' | tee /tmp/grid_lsinv_$(hostname)_$(date +%F).log
su - oracle -c '$ORACLE_HOME/OPatch/opatch version; $ORACLE_HOME/OPatch/opatch lspatches; $ORACLE_HOME/OPatch/opatch lsinventory -detail' | tee /tmp/db_lsinv_$(hostname)_$(date +%F).log

#集群和数据库状态
crsctl stat res -t
srvctl status database -d xydb
srvctl status service -d xydb
ocrcheck
ocrconfig -showbackup
```

#补丁前必须完成:
#- OCR手工备份和导出,并复制到<NFS_SERVER>;
#- RMAN L0或最近一次可用备份校验;
#- ORACLE_HOME/GI_HOME tar备份或存储快照;
#- 应用停机/滚动窗口确认;
#- ADG状态确认,必要时先暂停切换演练。

```bash
#root执行home备份示例;目录按实际修改
mkdir -p /backup/oracle_home_bak/$(date +%F)
cd /u01/app/19.0.0 && tar -zcpf /backup/oracle_home_bak/$(date +%F)/grid_$(hostname).tar.gz grid
cd /u01/app/oracle/product/19.0.0 && tar -zcpf /backup/oracle_home_bak/$(date +%F)/db_1_$(hostname).tar.gz db_1
```

#### 7.0.2.补丁分析与冲突检查

```bash
#解压当季RU后,按README设置PATCH_TOP
export PATCH_TOP=/u01/patch/<RU_PATCH_DIR>

#空间检查
df -h / /u01 /tmp

#冲突检查:所有节点分别执行
su - grid -c '$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir ${PATCH_TOP}'
su - oracle -c '$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir ${PATCH_TOP}'

#opatchauto分析;root执行
/u01/app/19.0.0/grid/OPatch/opatchauto apply ${PATCH_TOP} -analyze
```

#凡是README要求停服务、升级OPatch、应用one-off冲突补丁或回滚冲突补丁,必须先在测试环境验证,不得直接生产执行。

#### 7.0.3.推荐执行顺序

#两节点/三节点RAC优先采用GI rolling patch能力。典型顺序:
#1)补丁前postcheck保存基线;
#2)节点1执行GI home rolling patch,确认该节点资源恢复;
#3)节点2/节点3依次执行;
#4)DB home patch;
#5)所有实例启动后执行datapatch;
#6)补丁后postcheck、业务验证、ADG验证。

```bash
#root执行,按README选择apply或指定子补丁目录
/u01/app/19.0.0/grid/OPatch/opatchauto apply ${PATCH_TOP}

#数据库SQL补丁;任一数据库节点oracle用户执行,确保CDB/PDB打开
su - oracle
sqlplus / as sysdba <<'SQL'
set lines 200
show pdbs
select inst_id,instance_name,status from gv$instance order by inst_id;
SQL
$ORACLE_HOME/OPatch/datapatch -verbose
```

#### 7.0.4.补丁后验收

```bash
crsctl stat res -t
srvctl status database -d xydb
srvctl status service -d xydb
su - grid -c '$ORACLE_HOME/OPatch/opatch lspatches'
su - oracle -c '$ORACLE_HOME/OPatch/opatch lspatches'
su - oracle -c '$ORACLE_HOME/OPatch/datapatch -verbose'
```

```sql
set lines 200
col action_time for a30
col description for a80
select patch_id,patch_type,action,status,action_time,description
from dba_registry_sqlpatch
order by action_time;

select comp_id,comp_name,version,status from dba_registry order by comp_id;
```

#验收标准:
#1)CRS资源全部ONLINE/STABLE;
#2)opatch lspatches显示目标RU;
#3)dba_registry_sqlpatch为SUCCESS;
#4)PDB全部open且业务service正常;
#5)ADG broker配置、传输、apply lag正常;
#6)14.3或变更单记录补丁前后版本、耗时、异常与回退结果。

#### 7.0.5.回退策略

#回退必须以README为准。通用原则:
#- opatchauto失败先收集日志,不要反复重跑;
#- GI home异常优先使用opatchauto rollback或恢复home备份;
#- SQL patch已执行后,回退不仅是文件回退,还要处理datapatch rollback;
#- 回退后必须重新跑postcheck和业务验证。

```bash
#示例,具体补丁目录和参数以README为准
/u01/app/19.0.0/grid/OPatch/opatchauto rollback ${PATCH_TOP}
```

### 7.0.6.历史执行记录说明

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-07-RU 7.1/7.2 19.20与19.21 RU历史执行记录**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

## 8.Oracle RAC共享磁盘组添加新的共享磁盘

#当前共享数据盘满


```
[grid@oracle2:/home/grid]$asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  4194304     20480    20040                0           20040              0             Y  CRS/
MOUNTED  EXTERN  N         512   4096  1048576    563200   535532                0          535532              0             N  ORAARCH/
MOUNTED  EXTERN  N         512   4096  1048576    563200      426                0             426              0             N  ORADATA/
```



#查看当前共享磁盘情况及udev规则

```bash
[root@oracle2 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda           8:0    0   550G  0 disk 
sdb           8:16   0   550G  0 disk 
sdc           8:32   0    10G  0 disk 
sdd           8:48   0    10G  0 disk 
sde           8:64   0     1T  0 disk 
└─sde1        8:65   0  1024G  0 part 
sr0          11:0    1  1024M  0 rom  
vda         250:0    0   500G  0 disk 
├─vda1      250:1    0   512M  0 part /boot
├─vda2      250:2    0    64G  0 part [SWAP]
└─vda3      250:3    0 435.5G  0 part 
  ├─ol-root 251:0    0  85.5G  0 lvm  /
  └─ol-u01  251:1    0   350G  0 lvm  /u01

[root@oracle2 ~]# ls /etc/udev/rules.d/
70-persistent-ipoib.rules   99-oracle-asmdevices.rules  
[root@oracle2 ~]# cat /etc/udev/rules.d/99-oracle-asmdevices.rules 
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="36236036c004b93093a407a1364bdef42", RUN+="/bin/sh -c 'mknod /dev/asm-crs1 b $major $minor; chown grid:asmadmin /dev/asm-crs1; chmod 0660 /dev/asm-crs1'"
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="3645500ce5041750b1070d96b206c76f3", RUN+="/bin/sh -c 'mknod /dev/asm-crs2 b $major $minor; chown grid:asmadmin /dev/asm-crs2; chmod 0660 /dev/asm-crs2'"
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="3665a0630e04dd30a66804f0bb22ad181", RUN+="/bin/sh -c 'mknod /dev/asm-arch b $major $minor; chown grid:asmadmin /dev/asm-arch; chmod 0660 /dev/asm-arch'"
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="361ad039e404b9c097270648e2b6a3459", RUN+="/bin/sh -c 'mknod /dev/asm-data b $major $minor; chown grid:asmadmin /dev/asm-data; chmod 0660 /dev/asm-data'"
```



#在虚拟化平台添加新的共享磁盘后

#sdf---2T

```bash
[root@oracle2 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda           8:0    0   550G  0 disk 
sdb           8:16   0   550G  0 disk 
sdc           8:32   0    10G  0 disk 
sdd           8:48   0    10G  0 disk 
sde           8:64   0     1T  0 disk 
└─sde1        8:65   0  1024G  0 part 
sdf           8:80   0     2T  0 disk 
sr0          11:0    1  1024M  0 rom  
vda         250:0    0   500G  0 disk 
├─vda1      250:1    0   512M  0 part /boot
├─vda2      250:2    0    64G  0 part [SWAP]
└─vda3      250:3    0 435.5G  0 part 
  ├─ol-root 251:0    0  85.5G  0 lvm  /
  └─ol-u01  251:1    0   350G  0 lvm  /u01
  
[root@oracle2 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
3622c06a4f042460bf830cdeafb581fed
[root@oracle2 ~]# 


[root@oracle1 ~]# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda           8:0    0   550G  0 disk 
sdb           8:16   0   550G  0 disk 
sdc           8:32   0    10G  0 disk 
sdd           8:48   0    10G  0 disk 
sde           8:64   0     1T  0 disk 
└─sde1        8:65   0  1024G  0 part /orabackup
sdf           8:80   0     2T  0 disk 
sr0          11:0    1  1024M  0 rom  
vda         250:0    0   500G  0 disk 
├─vda1      250:1    0   512M  0 part /boot
├─vda2      250:2    0    64G  0 part [SWAP]
└─vda3      250:3    0 435.5G  0 part 
  ├─ol-root 251:0    0  85.5G  0 lvm  /
  └─ol-u01  251:1    0   350G  0 lvm  /u01
  
[root@oracle1 ~]# /usr/lib/udev/scsi_id -g -u -d /dev/sdf
3622c06a4f042460bf830cdeafb581fed
[root@oracle1 ~]# 

```



#udev规则备份及修改----rac01/rac02都要修改

```bash

[root@oracle1 ~]# cd /etc/udev/rules.d/

[root@oracle1 rules.d]# cp 99-oracle-asmdevices.rules 99-oracle-asmdevices.rules.bak

[root@oracle1 rules.d]# vi 99-oracle-asmdevices.rules
#添加一行
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="3622c06a4f042460bf830cdeafb581fed", RUN+="/bin/sh -c 'mknod /dev/asm-data1 b $major $minor; chown grid:asmadmin /dev/asm-data1; chmod 0660 /dev/asm-data1'"


[root@oracle1 rules.d]# cat 99-oracle-asmdevices.rules
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="36236036c004b93093a407a1364bdef42", RUN+="/bin/sh -c 'mknod /dev/asm-crs1 b $major $minor; chown grid:asmadmin /dev/asm-crs1; chmod 0660 /dev/asm-crs1'"
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="3645500ce5041750b1070d96b206c76f3", RUN+="/bin/sh -c 'mknod /dev/asm-crs2 b $major $minor; chown grid:asmadmin /dev/asm-crs2; chmod 0660 /dev/asm-crs2'"
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="3665a0630e04dd30a66804f0bb22ad181", RUN+="/bin/sh -c 'mknod /dev/asm-arch b $major $minor; chown grid:asmadmin /dev/asm-arch; chmod 0660 /dev/asm-arch'"
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="361ad039e404b9c097270648e2b6a3459", RUN+="/bin/sh -c 'mknod /dev/asm-data b $major $minor; chown grid:asmadmin /dev/asm-data; chmod 0660 /dev/asm-data'"
KERNEL=="sd*[!0-9]", ENV{DEVTYPE}=="disk", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d $devnode", RESULT=="3622c06a4f042460bf830cdeafb581fed", RUN+="/bin/sh -c 'mknod /dev/asm-data1 b $major $minor; chown grid:asmadmin /dev/asm-data1; chmod 0660 /dev/asm-data1'"
[root@oracle1 rules.d]# 

```



#触发udev规则生效----rac01/rac02都要执行

```bash
[root@oracle1 ~]# udevadm control --reload-rules

[root@oracle1 ~]# udevadm trigger --type=devices --action=change

[root@oracle1 ~]# ls -l /dev/|grep asm


[root@oracle2 ~]# udevadm control --reload-rules

[root@oracle2 ~]# udevadm trigger --type=devices --action=change

[root@oracle2 ~]# ls -l /dev/|grep asm
```



#此时asmcmd里还未识别新的磁盘，但是sysasm中已经有了

```bash
[grid@oracle2:/home/grid]$asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  4194304     20480    20040                0           20040              0             Y  CRS/
MOUNTED  EXTERN  N         512   4096  1048576    563200   535532                0          535532              0             N  ORAARCH/
MOUNTED  EXTERN  N         512   4096  1048576    563200      426                0             426              0             N  ORADATA/

ASMCMD> lsdsk
Path
/dev/asm-arch
/dev/asm-crs1
/dev/asm-crs2
/dev/asm-data
ASMCMD> 

[grid@oracle2:/home/grid]$ sqlplus / as sysasm

SQL>  select group_number,path,state,total_mb,free_mb from v$asm_disk;

GROUP_NUMBER PATH						STATE	   TOTAL_MB    FREE_MB
------------ -------------------------------------------------- -------- ---------- ----------
	   0 /dev/asm-data1					NORMAL		  0	     0
	   1 /dev/asm-crs1					NORMAL	      10240	  9996
	   2 /dev/asm-arch					NORMAL	     563200	518583
	   3 /dev/asm-data					NORMAL	     563200	    43
	   1 /dev/asm-crs2					NORMAL	      10240	 10044

SQL> 
```



#添加新的磁盘

```sql
[grid@oracle2:/home/grid]$ sqlplus / as sysasm

SQL> alter diskgroup ORADATA add disk '/dev/asm-data1' rebalance power 8;

Diskgroup altered.

SQL> 


SQL> select group_number,path,state,total_mb,free_mb from v$asm_disk;

GROUP_NUMBER PATH						STATE	   TOTAL_MB    FREE_MB
------------ -------------------------------------------------- -------- ---------- ----------
	   1 /dev/asm-crs1					NORMAL	      10240	  9996
	   2 /dev/asm-arch					NORMAL	     563200	518583
	   3 /dev/asm-data					NORMAL	     563200	   994
	   1 /dev/asm-crs2					NORMAL	      10240	 10044
	   3 /dev/asm-data1					NORMAL	    2097152    2094991

SQL> 

```



#此时asmcmd中已经可以识别，在rebalance

```bash
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  4194304     20480    20040                0           20040              0             Y  CRS/
MOUNTED  EXTERN  N         512   4096  1048576    563200   518583                0          518583              0             N  ORAARCH/
MOUNTED  EXTERN  Y         512   4096  1048576   2660352  2093936                0         2093936              0             N  ORADATA/
ASMCMD> lsdsk
Path
/dev/asm-arch
/dev/asm-crs1
/dev/asm-crs2
/dev/asm-data
/dev/asm-data1
ASMCMD> 


[grid@oracle2:/home/grid]$ sqlplus / as sysasm
SQL> select * from v$asm_operation;

GROUP_NUMBER OPERA STAT      POWER     ACTUAL	   SOFAR   EST_WORK   EST_RATE EST_MINUTES ERROR_CODE
------------ ----- ---- ---------- ---------- ---------- ---------- ---------- ----------- --------------------------------------------
	   3 REBAL RUN		 8	    8	    8526     443191	  5069          85


SQL>
```



#rebalance结束后

```bash
[grid@oracle1:/home/grid]$asmcmd
ASMCMD> lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  4194304     20480    20040                0           20040              0             Y  CRS/
MOUNTED  EXTERN  N         512   4096  1048576    563200   515920                0          515920              0             N  ORAARCH/
MOUNTED  EXTERN  N         512   4096  1048576   2660352  2088613                0         2088613              0             N  ORADATA/
ASMCMD> lsdsk
Path
/dev/asm-arch
/dev/asm-crs1
/dev/asm-crs2
/dev/asm-data
/dev/asm-data1
ASMCMD> exit
[grid@oracle1:/home/grid]$sqlplus / as sysasm

SQL*Plus: Release 11.2.0.4.0 Production on Mon Mar 31 15:20:17 2025

Copyright (c) 1982, 2013, Oracle.  All rights reserved.


Connected to:
Oracle Database 11g Enterprise Edition Release 11.2.0.4.0 - 64bit Production
With the Real Application Clusters and Automatic Storage Management options

SQL> select * from v$asm_operation;

no rows selected

SQL> 

```



#rebalance时间估算

```bash
SQL> select * from v$asm_operation;

GROUP_NUMBER OPERA STAT      POWER     ACTUAL	   SOFAR   EST_WORK   EST_RATE EST_MINUTES ERROR_CODE
------------ ----- ---- ---------- ---------- ---------- ---------- ---------- ----------- --------------------------------------------
	   3 REBAL RUN		 8	    8	    8526     443191	  5069          85

#关键指标解析
#字段名称	当前值	技术含义
GROUP_NUMBER	3	正在操作的ASM磁盘组编号（对应V$ASM_DISKGROUP.GROUP_NUMBER）
OPERA	REBAL	操作类型：磁盘组重平衡
STAT	RUN	操作状态：正在运行中
POWER	8	设置的并行进程数（即同时工作的ARB进程数量）
ACTUAL	8	实际生效的并行度（通常与POWER值一致）
SOFAR	8526	已完成的I/O操作单元数（每个单元对应一个分配单元的迁移）
EST_WORK	443191	预估总I/O操作单元数
EST_RATE	5069	当前处理速率（单位：操作单元/分钟）
EST_MINUTES	85	预计剩余完成时间（分钟）

#完成百分比：
进度百分比=8526/443191×100≈1.92%

#剩余时间估算：
当前速率：5069 操作单元/分钟
剩余单元：443191 - 8526 = 434665
理论剩余时间：434665 ÷ 5069 ≈ 85.7 分钟（与显示值吻合）
```



#POWER参数深度解析

```bash
参数值	资源消耗	预计完成时间（示例）	适用场景
1	最低CPU/I/O占用	10小时（1TB数据）	业务高峰时段维护
4	中等负载	2.5小时	常规维护窗口
8	高并发，占用约30%系统资源	1小时15分钟	紧急扩容且需快速完成
11+	可能引发资源争用	边际效益递减	测试环境/特殊优化场景
```

#动态调整

```sql
-- 运行中修改并行度
ALTER DISKGROUP ORADATA REBALANCE POWER 5;
```



#执行前后关键检查点

```sql
#预检清单
-- 检查磁盘状态
SELECT name, path, header_status FROM v$asm_disk 
WHERE path='/dev/asm-oredata';

-- 验证磁盘组容量
SELECT name, total_mb, free_mb FROM v$asm_diskgroup;


#执行后监控
-- 查看重平衡进度
SELECT * FROM v$asm_operation;

-- 实时I/O压力
SELECT * FROM V$ASM_DISK_IOSTAT;

#操作状态判断矩阵
#状态组合	含义	建议操作
STAT=RUN + ERROR_CODE空	正常进行中	定期监控即可
STAT=WAIT	等待资源	检查系统I/O或CPU瓶颈
ERROR_CODE非空	发生错误	立即查看V$ASM_OPERATION.ERROR_CODE
EST_MINUTES持续增长	存在处理瓶颈	降低并行度或排查存储性能

-- 最终磁盘分布验证
SELECT disk_number, name, total_mb, free_mb 
FROM v$asm_disk 
WHERE group_number = (SELECT group_number 
                       FROM v$asm_diskgroup 
                       WHERE name='ORADATA');


```

#参考命令

```sql
#首先添加的磁盘总量需要比原来的大一些或者一样大，不能偏小，不然在操作时会报错 ORA-15032、ORA-15250，还有每个磁盘可以比原来的大，即实现小盘换大盘
#其次，删除磁盘时使用的是 ARCH_0000 等这样的磁盘名，并不是磁盘路径
#最后，在添加磁盘的同时进行删除操作，平衡时间会缩短很多，当遇到数据量几十 T 时均衡时间大概要好几天的时间

--- 以下为本次迁移过程中盘符相对应命令，迁移中主要以数据库中
--- 查到的磁盘号为准。即上节中所查的 GROUP_NUMBER 为 0 的磁盘。
-- ARCH 盘
 alter diskgroup ARCH  add disk '/dev/rhdisk103','/dev/rhdisk104','/dev/rhdisk105','/dev/rhdisk106' 
 drop disk 'ARCH_0000','ARCH_0001','ARCH_0002','ARCH_0003','ARCH_0004','ARCH_0005','ARCH_0006','ARCH_0007','ARCH_0008','ARCH_0009','ARCH_0010';
 ALTER DISKGROUP ARCH REBALANCE POWER 10; 
 
 -- DATA盘
 alter diskgroup DATA  add disk '/dev/rhdisk107','/dev/rhdisk108','/dev/rhdisk109','/dev/rhdisk110','/dev/rhdisk111','/dev/rhdisk112','/dev/rhdisk113',
 '/dev/rhdisk114','/dev/rhdisk115','/dev/rhdisk116','/dev/rhdisk117','/dev/rhdisk118','/dev/rhdisk119','/dev/rhdisk120','/dev/rhdisk121','/dev/rhdisk122','/dev/rhdisk123' 
 drop disk 'DATA_0000','DATA_0001','DATA_0011','DATA_0013','DATA_0014','DATA_0015','DATA_0016','DATA_0017','DATA_0018','DATA_0019';
 ALTER DISKGROUP DATA REBALANCE POWER 10; 
 
 --OCR 盘
 alter diskgroup OCR  add disk '/dev/rhdisk100','/dev/rhdisk101','/dev/rhdisk102' drop disk 'OCR_0000','OCR_0001','OCR_0002';

```



## 9.集群故障处置手册(P1扩写版)

#目标:从“日志位置”升级为“可执行runbook”。
#原则:
#1)先保护现场,再恢复服务;故障日志和命令输出必须保存到变更/故障目录;
#2)RAC问题优先分网络、存储、CSS/CRS、ASM、DB实例、监听/service六条线判断;
#3)涉及强制启动、OCR恢复、voting变更、failover前,必须有双人复核。

### 9.1.日志位置与证据采集

```bash
#建议每次故障先建目录
mkdir -p /tmp/rac_diag_$(hostname)_$(date +%Y%m%d_%H%M%S)
cd /tmp/rac_diag_*

#GI/CRS/ASM/DB/listener关键日志路径
/u01/app/grid/diag/crs/$(hostname)/crs/trace
/u01/app/grid/diag/asm/+asm/+ASM*/trace
/u01/app/oracle/diag/rdbms/xydb/xydb*/trace
/u01/app/grid/diag/tnslsnr/$(hostname)/listener/trace

#基础状态
hostname; date; uptime
crsctl check crs
crsctl stat res -t
crsctl query css votedisk
ocrcheck
olsnodes -n -s -t
srvctl status database -d xydb
srvctl status service -d xydb
```

### 9.2.TFA/AHF安装与一键采集

#GI root.sh通常会安装TFA,但仍需验证是否可用。若现场已统一使用AHF,以AHF/tfactl为准。

```bash
#root执行
which tfactl || find /u01 -name tfactl 2>/dev/null | head
tfactl print status
tfactl print hosts

#采集最近4小时集群诊断,用于节点驱逐、ASM异常、实例hang等场景
tfactl diagcollect -last 4h -all -z /tmp/tfa_$(hostname)_$(date +%Y%m%d_%H%M%S).zip

#按组件采集示例
tfactl diagcollect -crs -asm -db -tns -last 2h -all
```

#TFA不可用时,至少手工打包:

```bash
tar -zcpf /tmp/rac_manual_diag_$(hostname)_$(date +%Y%m%d_%H%M%S).tar.gz \
  /u01/app/grid/diag/crs/$(hostname)/crs/trace \
  /u01/app/grid/diag/asm/+asm \
  /u01/app/oracle/diag/rdbms/xydb \
  /var/log/messages* /var/log/secure* 2>/dev/null
```

### 9.3.节点驱逐/重启排查

#### 9.3.1.快速判断

```bash
#所有节点执行或从存活节点执行
olsnodes -n -s -t
crsctl stat res -t
last -x | head -50
grep -Ei "evict|reboot|panic|cssd|misscount|split brain|fencing|I/O error|blocked for more than" /var/log/messages* | tail -200
```

#### 9.3.2.CSS/ocssd日志

```bash
#重点看被驱逐节点与存活节点同一时间段
cd /u01/app/grid/diag/crs/$(hostname)/crs/trace
grep -Ei "evict|misscount|clssnm|votedisk|network|heartbeat|fatal" ocssd.trc | tail -200
ls -ltr ocssd*.trc cssd*.log crsd*.trc 2>/dev/null | tail
```

#### 9.3.3.分支判断

| 现象 | 优先排查 | 关键证据 |
| ---- | -------- | -------- |
| ocssd提示network heartbeat丢失 | 私网/交换机/MTU/rp_filter | private ping、网卡错误包、ocssd.trc |
| ocssd提示disk heartbeat/votedisk异常 | iSCSI/store/ASM磁盘 | `/var/log/messages` I/O error、`iscsiadm -m session -P3`、ASM alert |
| OS panic或hung task | 内核/驱动/内存 | vmcore、messages、HugePages/swap、dmesg |
| 单实例异常但节点未驱逐 | DB hang/资源不足 | alert、hanganalyze/systemstate、ASH/AWR |

### 9.4.共享存储/iSCSI/ASM磁盘异常

```bash
#RAC节点检查iSCSI session和LUN映射
iscsiadm -m session -P 3 | egrep -i "Target:|SID|Recovery Timeout|Attached scsi|Current Portal"
lsblk
ls -l /dev/disk/by-path/ | grep iscsi
ls -l /dev/oracleasm/disks/

#store节点检查tgtd/target与LUN定义
systemctl status tgtd target
netstat -anp | grep 3260
tgt-admin -dump
tgtadm --lld iscsi --mode target --op show
```

#处置原则:
#1)禁止在CRS/ASM仍运行时随意重扫、删除iSCSI node或改udev;
#2)确认store端LUN定义、SCSI ID与6.5.2.2a备份一致后再恢复;
#3)设备名只能通过`/dev/oracleasm/disks/*`进入GI/ASM,不得引用`/dev/sdX`;
#4)如果ASM磁盘头疑似损坏,先收集`kfed read`和ASM alert,不要立即createdisk覆盖。

```bash
#ASM层检查(grid用户)
asmcmd lsdg
asmcmd lsdsk -k -p
sqlplus / as sysasm <<'SQL'
set lines 200
col path for a60
select group_number,disk_number,name,path,header_status,mount_status,mode_status,state,total_mb,free_mb
from v$asm_disk order by group_number,disk_number;
SQL
```

### 9.5.OCR/Voting/OLR异常

```bash
#root或grid执行
ocrcheck
ocrconfig -showbackup
ocrconfig -local -showbackup
crsctl query css votedisk
```

#处置原则:
#1)OLR是本地节点配置,OCR是集群配置,不要混用恢复命令;
#2)恢复前先备份现状和日志;
#3)OCR恢复优先使用最近自动备份/手工export,并参考6.5.2;
#4)voting file在ASM中时,重点确认OCR磁盘组可挂载和votedisk路径。

### 9.6.VIP/SCAN/listener/service异常

```bash
crsctl stat res -t | egrep "vip|scan|listener|service|xydb"
srvctl status scan
srvctl status scan_listener
srvctl status listener
srvctl status service -d xydb
lsnrctl status

#网络连通性
ping -c 3 rac-scan
nslookup rac-scan || getent hosts rac-scan
```

#常见处置:
#- VIP不漂移:检查public网卡、网关、ARP、防火墙、CRS资源依赖;
#- SCAN异常:hosts单SCAN IP仅为降级方案,生产应DNS三SCAN;
#- service未按角色启动:检查12.8.1角色服务配置、trigger状态和srvctl配置。

### 9.7.实例hang/性能故障证据采集

```sql
--sysdba执行,轻量检查
set lines 200 pages 200
select inst_id,event,count(*) from gv$session where wait_class <> 'Idle' group by inst_id,event order by 3 desc;
select inst_id,status,count(*) from gv$session group by inst_id,status order by inst_id,status;
select inst_id,name,value from gv$sysstat where name in ('logons current','opened cursors current') order by inst_id,name;
```

#hang时采集systemstate/hanganalyze,不要只重启:

```sql
oradebug setmypid
oradebug hanganalyze 3
oradebug dump systemstate 266
oradebug tracefile_name
```

#RAC全局hang可在每个实例采集,同时保留AWR/ASH时间段。

### 9.8.FRA/归档满故障

```sql
set lines 200
select name,space_limit/1024/1024/1024 limit_gb,space_used/1024/1024/1024 used_gb,space_reclaimable/1024/1024/1024 reclaim_gb,number_of_files
from v$recovery_file_dest;

select * from v$flash_recovery_area_usage;
archive log list;
```

```rman
crosscheck archivelog all;
delete expired archivelog all;
report obsolete;
--确认ADG应用策略后再删除,不要强删未应用归档
list archivelog all completed before 'sysdate-7';
```

#若启用ADG,必须先看12.7归档删除策略和`v$archive_dest_status`,确认备库已应用后再清理。

### 9.9.常见错误速查

| 错误/现象 | 方向 | 首查命令 |
| --------- | ---- | -------- |
| CRS-4535 | CRSD不可用 | `crsctl check crs`; crsd.trc |
| CRS-1604/节点驱逐 | CSS心跳 | ocssd.trc、messages、网络/存储 |
| ORA-15032/15040 | ASM磁盘组 | ASM alert、`asmcmd lsdsk -k` |
| ORA-00257 | 归档/FRA满 | `v$recovery_file_dest`; RMAN清理 |
| ORA-12154 | TNS解析 | tnsnames、service、SCAN/hosts |
| ORA-12514 | listener未注册服务 | `lsnrctl status`; `srvctl status service` |
| ORA-01017集中爆发 | 口令/客户端版本/暴破 | 6.4.1/6.4.2、安全审计日志 |

## 10.部署第三个节点

### 10.1. 根据前面内容做好节点三的优化、grid/oracle配置、ssh互信等
#如果已经升级openssh

#节点三root下修改scp

```
# Rename the original scp
mv /usr/bin/scp /usr/bin/scp.orig

# Create a new file scp
echo "/usr/bin/scp.orig -T \$*" > /usr/bin/scp

# Make the file executable
chmod a+rx /usr/bin/scp

# 查看scp的内容
cat /usr/bin/scp
/usr/bin/scp.orig -T $*
```

#配置共享磁盘

#为了保持节点间，对同一磁盘有一样的名称，需要使用一样的规则文件。需要在一个节点生成后，传输到其他节点。
#节点1:

```bash
scp /etc/udev/rules.d/99-oracle-asmdevices.rules k8s-19rac03:/etc/udev/rules.d/99-oracle-asmdevices.rules
```

#启动udev

```bash
/usr/sbin/partprobe

systemctl restart systemd-udev-trigger.service
systemctl enable systemd-udev-trigger.service
systemctl status systemd-udev-trigger.service
```
#检查asm磁盘
```bash
ll /dev|grep asm*

#uuid变动的方式
ll /dev/oracleasm/disks/
```

#配置互信
#k8s-19rac03:

```bash
su - grid

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa

su - oracle

cd /home/grid
mkdir ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa

ssh-keygen -t dsa
```
#k8s-19rac01:
#grid/oracle

```bash
ssh k8s-19rac03 cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

ssh k8s-19rac03 cat ~/.ssh/id_dsa.pub >>~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-19rac02:~/.ssh/authorized_keys

scp ~/.ssh/authorized_keys k8s-19rac03:~/.ssh/authorized_keys
```
#k8s-19rac01/k8s-19rac02/k8s-19rac03:
#grid/oracle

```bash
ssh k8s-19rac01 date;ssh k8s-19rac02 date;ssh k8s-19rac03 date;ssh k8s-19rac01-prv date;ssh k8s-19rac02-prv date;ssh k8s-19rac03-prv date
```



#安装cvuqdisk包

#k8s-19rac01

```bash
su - grid

cd /u01/app/19.0.0/grid/cv/rpm
scp cvuqdisk-1.0.10-1.rpm k8s-19rac03:/u01
```

#k8s-19rac03

```bash
su - root

cd /u01
rpm -ivh cvuqdisk-1.0.10-1.rpm
```



### 10.2. 安装前检查

```bash
#k8s-19rac01
su - grid
cd $ORACLE_HOME/
./runcluvfy.sh comp peer -refnode k8s-19rac01 -n k8s-19rac03 -verbose | tee -a ~/addnode3ref.log
```
#看到结果
```
Verifying Peer Compatibility ...PASSED

Verification of peer compatibility was successful. 
```


```bash
#k8s-19rac01
su - grid
cd $ORACLE_HOME/
 ./runcluvfy.sh  stage -pre nodeadd -n k8s-19rac03 -fixup -verbose | tee -a ~/addnode3.log
```

#看到以下有关共享磁盘的报错，可以忽略，继续安装
```
Verifying Device Checks for ASM ...
  Verifying Package: cvuqdisk-1.0.10-1 ...PASSED
  Verifying ASM device sharedness check ...
    Verifying Shared Storage Accessibility:/dev/sda,/dev/sdb,/dev/sdc,/dev/sde,/dev/sdh,/dev/sdd,/dev/sdf,/dev/sdg ...FAILED (PRVG-0806)

  Device                                Device Type             
  ------------------------------------  ------------------------
  /dev/sdh                              Disk                    
  /dev/sdg                              Disk                    
  /dev/sdf                              Disk                    
  /dev/sdc                              Disk                    
PRVG-10487 : Storage "/dev/sda" is not shared on all nodes.
PRVG-10487 : Storage "/dev/sde" is not shared on all nodes.
PRVG-10487 : Storage "/dev/sdd" is not shared on all nodes.
PRVG-10487 : Storage "/dev/sdb" is not shared on all nodes.
  Verifying ASM device sharedness check ...FAILED (PRVG-0806)


Failures were encountered during execution of CVU verification request "stage -pre nodeadd".

Verifying Device Checks for ASM ...FAILED
  Verifying ASM device sharedness check ...FAILED
    Verifying Shared Storage
    Accessibility:/dev/sda,/dev/sdb,/dev/sdc,/dev/sde,/dev/sdh,/dev/sdd,/dev/sdf
    ,/dev/sdg ...FAILED
    PRVG-0806 : Signature for storage path "/dev/sda" is inconsistent across
    the nodes.
    Signature was found as "36ff204468043c909acc0afa4094745b6|" on nodes:
    "k8s-19rac03".
    Signature was found as "366960e55904821091c9025e2c7255c7f|" on nodes:
    "k8s-19rac01".
    PRVG-0806 : Signature for storage path "/dev/sdb" is inconsistent across
    the nodes.
    Signature was found as "36ff204468043c909acc0afa4094745b6|" on nodes:
    "k8s-19rac01".
    Signature was found as "366960e55904821091c9025e2c7255c7f|" on nodes:
    "k8s-19rac03".
    PRVG-0806 : Signature for storage path "/dev/sde" is inconsistent across
    the nodes.
    Signature was found as "3643a008cc04b8e0b8e109a319a118822|" on nodes:
    "k8s-19rac03".
    Signature was found as "368350b4ed049f10a9b108e152738bc3d|" on nodes:
    "k8s-19rac01".
    PRVG-0806 : Signature for storage path "/dev/sdd" is inconsistent across
    the nodes.
    Signature was found as "3643a008cc04b8e0b8e109a319a118822|" on nodes:
    "k8s-19rac01".
    Signature was found as "368350b4ed049f10a9b108e152738bc3d|" on nodes:
    "k8s-19rac03".
```



#关于oracleasm报错也可以忽略

```bash
Pre-check for node addition was unsuccessful. 
Checks did not pass for the following nodes:
	k8s-19rac03,k8s-19rac01


Failures were encountered during execution of CVU verification request "stage -pre nodeadd".

Verifying Device Checks for ASM ...FAILED
k8s-19rac01: PRVG-2043 : Command "/usr/sbin/oracleasm listdisks" failed on node
             "k8s-19rac01" and produced the following output:
             sh: /usr/sbin/oracleasm: No such file or directory

k8s-19rac01: PRVG-10524 : failed to determine whether disk "DATA01" is managed
             by ASMLib
k8s-19rac01: PRVG-10524 : failed to determine whether disk "FRA01" is managed
             by ASMLib
k8s-19rac01: PRVG-10524 : failed to determine whether disk "OCR01" is managed
             by ASMLib
k8s-19rac01: PRVG-10524 : failed to determine whether disk "OCR02" is managed
             by ASMLib
k8s-19rac01: PRVG-10524 : failed to determine whether disk "OCR03" is managed
             by ASMLib
```





### 10.3. 在节点一上开始添加节点三的GI

#节点一k8s-19rac01上执行，xterm连接grid用户

```bash
cd $ORACLE_HOME
./gridSetup.sh
```
#安装过程
```
Add more nodes to the cluster--->Add：k8s-19rac03/k8s-19rac03-vip--->SSH connectivity、Test--->Ignore all(Device Checks for ASM)--->submit--->k8s-19rac03root执行脚本：/u01/app/oraInventory/orainstRoot.sh /u01/app/19.0.0/grid/root.sh-->OK-->Close
```

#脚本结果
```bash
[root@k8s-19rac03 u01]# cd /u01/app/oraInventory/
[root@k8s-19rac03 oraInventory]# ls
backup  ContentsXML  logs  oraInst.loc  orainstRoot.sh
[root@k8s-19rac03 oraInventory]# ./orainstRoot.sh 
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.

[root@k8s-19rac03 oraInventory]# cd /u01/app/19.0.0/grid/
[root@k8s-19rac03 grid]# ./root.sh
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
  /u01/app/grid/crsdata/k8s-19rac03/crsconfig/rootcrs_k8s-19rac03_2022-12-06_06-34-48PM.log
2022/12/06 18:34:52 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2022/12/06 18:34:52 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2022/12/06 18:34:53 CLSRSC-363: User ignored prerequisites during installation
2022/12/06 18:34:53 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2022/12/06 18:34:53 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2022/12/06 18:34:59 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
2022/12/06 18:34:59 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2022/12/06 18:35:00 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2022/12/06 18:35:01 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2022/12/06 18:35:02 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2022/12/06 18:35:10 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2022/12/06 18:35:10 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2022/12/06 18:35:12 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2022/12/06 18:35:12 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2022/12/06 18:35:16 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2022/12/06 18:35:31 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2022/12/06 18:35:32 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2022/12/06 18:35:34 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2022/12/06 18:35:35 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2022/12/06 18:35:42 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2022/12/06 18:37:48 CLSRSC-343: Successfully started Oracle Clusterware stack
2022/12/06 18:37:48 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
clscfg: EXISTING configuration version 19 detected.
Successfully accumulated necessary OCR keys.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
2022/12/06 18:38:08 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2022/12/06 18:38:12 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
```

### 10.4. 在节点一上开始添加节点三的数据库
#节点一k8s-19rac01上执行，xterm连接oracle用户
```bash
cd $ORACLE_HOME/addnode
./addnode.sh "CLUSTER_NEW_NODES={k8s-19rac03}"
```
#安装过程
```
k8s-19rac03前打勾--->SH connectivity---Test--->submit
--->k8s-19rac03root执行脚本：/u01/app/oracle/product/19.0.0/db_1/root.sh-->OK-->Close
```

#脚本结果

```
[root@k8s-19rac03 ~]# cd /u01/app/oracle/product/19.0.0/db_1/
[root@k8s-19rac03 db_1]# ./root.sh
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
[root@k8s-19rac03 db_1]#
```

#此时检查集群状态

```bash
#3个scan IP时
[grid@k8s-19rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac02                 STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 Started,STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02                 STABLE
ora.k8s-19rac03.vip
      1        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac02                 STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_portal.svc
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
--------------------------------------------------------------------------------


#2025
#单个scan IP时
[grid@k8s-19rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        ONLINE  ONLINE       k8s-19rac03              Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.k8s-19rac03.vip
      1        ONLINE  ONLINE       k8s-19rac03              STABLE
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
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------

[grid@k8s-19rac01 ~]$ 
```



###  10.5. 在节点一上开始安装节点三的instance

#xterm连接k8s-19rac01的oracle账户
```bash
dbca
```
#安装过程
```
Oracle RAC databas instnce management--->Add an instance--->勾选xydb/xydb1/ADMIN_MANAGED，下面填写sys/<SYS_PWD>--->Instance name：xydb3；Node name：k8s-19rac03；下面是xydb1/xydb2/active--->Finish--->开始安装--->Close
```
#此时集群检查
```bash
#3个scan IP时
[grid@k8s-19rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01                 STABLE
               ONLINE  ONLINE       k8s-19rac02                 STABLE
               ONLINE  ONLINE       k8s-19rac03                 STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac02                 STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 Started,STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02                 STABLE
ora.k8s-19rac03.vip
      1        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-19rac02                 STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       k8s-19rac03                 STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-19rac01                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      3        ONLINE  ONLINE       k8s-19rac03                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_portal.svc
      1        ONLINE  ONLINE       k8s-19rac01                 STABLE
      2        ONLINE  ONLINE       k8s-19rac02                 STABLE
--------------------------------------------------------------------------------



#2025
#单个scan IP时
[grid@k8s-19rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
ora.chad
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
ora.ons
               ONLINE  ONLINE       k8s-19rac01              STABLE
               ONLINE  ONLINE       k8s-19rac02              STABLE
               ONLINE  ONLINE       k8s-19rac03              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              Started,STABLE
      2        ONLINE  ONLINE       k8s-19rac02              Started,STABLE
      3        ONLINE  ONLINE       k8s-19rac03              Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
      3        ONLINE  ONLINE       k8s-19rac03              STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac01.vip
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
ora.k8s-19rac02.vip
      1        ONLINE  ONLINE       k8s-19rac02              STABLE
ora.k8s-19rac03.vip
      1        ONLINE  ONLINE       k8s-19rac03              STABLE
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
      3        ONLINE  ONLINE       k8s-19rac03              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-19rac01              STABLE
      2        ONLINE  ONLINE       k8s-19rac02              STABLE
--------------------------------------------------------------------------------
[grid@k8s-19rac01 ~]$ 

```

### 10.6修改原来的service

#查看当前服务

```bash
[oracle@k8s-19rac01 ~]$ srvctl status instance -d xydb -node k8s-19rac01,k8s-19rac02,k8s-19rac03
Instance xydb1 is running on node k8s-19rac01
Instance xydb2 is running on node k8s-19rac02
Instance xydb3 is running on node k8s-19rac03
[oracle@k8s-19rac01 ~]$ srvctl status service -d xydb
Service s_stuwork is running on instance(s) xydb1,xydb2
[oracle@k8s-19rac01 ~]$ srvctl modify service -d xydb -s s_stuwork -oldinst xydb1,xydb2 -newinst xydb3
PRKO-2101 : Failed to find database instances xydb1,xydb2
[oracle@k8s-19rac01 ~]$ srvctl config service -d xydb -s s_stuwork
Service name: s_stuwork
Server pool: 
Cardinality: 2
Service role: PRIMARY
Management policy: AUTOMATIC
DTP transaction: false
AQ HA notifications: false
Global: false
Commit Outcome: false
Failover type: SELECT
Failover method: BASIC
Failover retries: 180
Failover delay: 5
Failover restore: NONE
Connection Load Balancing Goal: LONG
Runtime Load Balancing Goal: NONE
TAF policy specification: BASIC
Edition: 
Pluggable database name: stuwork
Hub service: 
Maximum lag time: ANY
SQL Translation Profile: 
Retention: 86400 seconds
Replay Initiation Time: 300 seconds
Drain timeout: 
Stop option: 
Session State Consistency: DYNAMIC
GSM Flags: 0
Service is enabled
Preferred instances: xydb1,xydb2
Available instances: 
CSS critical: no
Service uses Java: false
[oracle@k8s-19rac01 ~]$ 
```



#使用modifyconfig参数

```bash
#使用-modifyconfig参数来一次性更新首选和可用实例列表
srvctl modify service -d xydb -s s_stuwork -modifyconfig -preferred "xydb1,xydb2,xydb3"

#将xydb3设置为可用实例而不是首选实例
srvctl modify service -d xydb -s s_stuwork -modifyconfig -preferred "xydb1,xydb2" -available "xydb3"

#验证服务
srvctl config service -d xydb -s s_stuwork
srvctl status service -d xydb -s s_stuwork

#srvctl start service -d xydb -s s_stuwork
```

#logs

```bash
[oracle@k8s-19rac01 ~]$ srvctl modify service -d xydb -s s_stuwork -modifyconfig -preferred "xydb1,xydb2" -available "xydb3"
[oracle@k8s-19rac01 ~]$ srvctl config service -d xydb -s s_stuwork
Service name: s_stuwork
Server pool: 
Cardinality: 2
Service role: PRIMARY
Management policy: AUTOMATIC
DTP transaction: false
AQ HA notifications: false
Global: false
Commit Outcome: false
Failover type: SELECT
Failover method: BASIC
Failover retries: 180
Failover delay: 5
Failover restore: NONE
Connection Load Balancing Goal: LONG
Runtime Load Balancing Goal: NONE
TAF policy specification: BASIC
Edition: 
Pluggable database name: stuwork
Hub service: 
Maximum lag time: ANY
SQL Translation Profile: 
Retention: 86400 seconds
Replay Initiation Time: 300 seconds
Drain timeout: 
Stop option: 
Session State Consistency: DYNAMIC
GSM Flags: 0
Service is enabled
Preferred instances: xydb1,xydb2
Available instances: xydb3
CSS critical: no
Service uses Java: false


[oracle@k8s-19rac01 ~]$ srvctl modify service -d xydb -s s_stuwork -modifyconfig -preferred "xydb1,xydb2,xydb3";
[oracle@k8s-19rac01 ~]$ srvctl config service -d xydb -s s_stuwork
Service name: s_stuwork
Server pool: 
Cardinality: 3
Service role: PRIMARY
Management policy: AUTOMATIC
DTP transaction: false
AQ HA notifications: false
Global: false
Commit Outcome: false
Failover type: SELECT
Failover method: BASIC
Failover retries: 180
Failover delay: 5
Failover restore: NONE
Connection Load Balancing Goal: LONG
Runtime Load Balancing Goal: NONE
TAF policy specification: BASIC
Edition: 
Pluggable database name: stuwork
Hub service: 
Maximum lag time: ANY
SQL Translation Profile: 
Retention: 86400 seconds
Replay Initiation Time: 300 seconds
Drain timeout: 
Stop option: 
Session State Consistency: DYNAMIC
GSM Flags: 0
Service is enabled
Preferred instances: xydb1,xydb2,xydb3
Available instances: 
CSS critical: no
Service uses Java: false

```



#删除后、重建，影响当前业务

```bash
#因为该命令的 -oldinst/-newinst 参数主要用于迁移单个实例（如将 xydb1 迁移到 xydb3），而无法批量替换多个旧实例
[oracle@k8s-19rac01 ~]$ srvctl modify service -d xydb -s s_stuwork -oldinst xydb1,xydb2 -newinst xydb3
PRKO-2101 : Failed to find database instances xydb1,xydb2

[oracle@k8s-19rac01 ~]$ srvctl modify service -d xydb -s s_stuwork -oldinst xydb1 -newinst xydb3
[oracle@k8s-19rac01 ~]$ srvctl config service -d xydb -s s_stuwork
Service name: s_stuwork
Server pool: 
Cardinality: 2
Service role: PRIMARY
Management policy: AUTOMATIC
DTP transaction: false
AQ HA notifications: false
Global: false
Commit Outcome: false
Failover type: SELECT
Failover method: BASIC
Failover retries: 180
Failover delay: 5
Failover restore: NONE
Connection Load Balancing Goal: LONG
Runtime Load Balancing Goal: NONE
TAF policy specification: BASIC
Edition: 
Pluggable database name: stuwork
Hub service: 
Maximum lag time: ANY
SQL Translation Profile: 
Retention: 86400 seconds
Replay Initiation Time: 300 seconds
Drain timeout: 
Stop option: 
Session State Consistency: DYNAMIC
GSM Flags: 0
Service is enabled
Preferred instances: xydb3,xydb2
Available instances: 
CSS critical: no
Service uses Java: false
[oracle@k8s-19rac01 ~]$ 


#将新实例添加为可用实例
srvctl modify service -d xydb -s s_stuwork -available "xydb3"

#先添加为可用实例，然后将其转换为首选实例
srvctl modify service -d xydb -s s_stuwork -available "xydb3" -toprefer

[oracle@k8s-19rac01 ~]$ srvctl modify service -d xydb -s s_stuwork -available "xydb3"
PRKO-3144 : Missing option '-modifyconfig' or '-preferred' was required by supplying '-available'.
[oracle@k8s-19rac01 ~]$ srvctl modify service -d xydb -s s_stuwork -available "xydb1" -toprefer
PRKO-3144 : Missing option '-modifyconfig' or '-preferred' was required by supplying '-available'.



[oracle@k8s-19rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 06-DEC-2022 21:37:08

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-DEC-2022 20:58:22
Uptime                    1 days 0 hr. 38 min. 46 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/k8s-19rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.1)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.2)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "ef14db5ce59d2d91e053018610ac1806" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[oracle@k8s-19rac01 ~]$ srvctl remove service -d xydb -s s_portal
PRCR-1025 : Resource ora.xydb.s_portal.svc is still running
[oracle@k8s-19rac01 ~]$ srvctl stop service -d xydb -s s_portal
[oracle@k8s-19rac01 ~]$ srvctl remove service -d xydb -s s_portal
[oracle@k8s-19rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 06-DEC-2022 21:37:51

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-DEC-2022 20:58:22
Uptime                    1 days 0 hr. 39 min. 28 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/k8s-19rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.1)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.2)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "ef14db5ce59d2d91e053018610ac1806" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[oracle@k8s-19rac01 ~]$ srvctl add service -help

Adds a service configuration to the Oracle Clusterware.

Usage: srvctl add service -db <db_unique_name> -service "<service_name_list>" 
       {-preferred "<preferred_list>" [-available "<available_list>"] [-tafpolicy {BASIC | NONE | PRECONNECT}] | -serverpool <pool_name> [-cardinality {UNIFORM | SINGLETON}] } 
       [-netnum <network_number>] [-role "[PRIMARY][,PHYSICAL_STANDBY][,LOGICAL_STANDBY][,SNAPSHOT_STANDBY]"] [-policy {AUTOMATIC | MANUAL}] 
       [-notification {TRUE | FALSE}] [-dtp {TRUE | FALSE}] [-clbgoal {SHORT | LONG}] [-rlbgoal {NONE | SERVICE_TIME | THROUGHPUT}] 
       [-failovertype {NONE | SESSION | SELECT | TRANSACTION | AUTO}] [-failovermethod {NONE | BASIC}] [-failoverretry <failover_retries>] [-failoverdelay <failover_delay>] [-failover_restore {NONE | LEVEL1}] [-failback {YES | NO}] 
       [-edition <edition>] [-pdb <pluggable_database>] [-global {TRUE | FALSE}] [-maxlag <max_lag_time>] [-sql_translation_profile <sql_translation_profile>] 
       [-commit_outcome {TRUE | FALSE}] [-retention <retention>] [-replay_init_time <replay_initiation_time>] [-session_state {STATIC | DYNAMIC}] 
       [-pqservice <pq_service>] [-pqpool "<pq_pool_list>"] [-gsmflags <gsm_flags>] [-tablefamilyid <table_family_id>] [-drain_timeout <drain_timeout>] [-stopoption <stop_option>] [-css_critical {YES | NO}] [-rfpool <pool_name> -hubsvc <hub_service>]
       [-force] [-eval] [-verbose]
    -db <db_unique_name>           Unique name for the database
    -service "<serv,...>"          Comma separated service names
    -preferred "<preferred_list>"  Comma separated list of preferred instances
    -available "<available_list>"  Comma separated list of available instances
    -serverpool <pool_name>        Server pool name
    -cardinality                   (UNIFORM | SINGLETON) Service runs on every active server in the server pool hosting this service (UNIFORM) or just one server (SINGLETON)
    -netnum  <network_number>      Network number (default number is 1)
    -tafpolicy                     (NONE | BASIC | PRECONNECT)        TAF policy specification
    -role <role>                   Role of the service (primary, physical_standby, logical_standby, snapshot_standby)
    -policy <policy>               Management policy for the service (AUTOMATIC or MANUAL)
    -failovertype                  (NONE | SESSION | SELECT | TRANSACTION | AUTO)      Failover type
    -failovermethod                (NONE | BASIC)     Failover method
    -failoverdelay <failover_delay> Failover delay (in seconds)
    -failoverretry <failover_retries> Number of attempts to retry connection
    -failover_restore <failover_restore>  Option to restore initial environment for Application Continuity and TAF (NONE or LEVEL1)
    -failback                      (YES|NO) Failback to a preferred instance for a administrator-managed database 
    -edition <edition>             Edition (or "" for empty edition value)
    -pdb <pluggable_database>      Pluggable database name
    -maxlag <max_lag_time>         Maximum replication lag time in seconds (Non-negative integer, default value is 'ANY')
    -clbgoal                       (SHORT | LONG)                   Connection Load Balancing Goal. Default is LONG.
    -rlbgoal                       (SERVICE_TIME | THROUGHPUT | NONE)     Runtime Load Balancing Goal
    -dtp                           (TRUE | FALSE)  Distributed Transaction Processing
    -notification                  (TRUE | FALSE)  Enable Fast Application Notification (FAN) for OCI connections
    -global <global>               Global attribute (TRUE or FALSE)
    -sql_translation_profile <sql_translation_profile> Specify a database object for SQL translation profile
    -commit_outcome                (TRUE | FALSE)          Commit outcome
    -retention <retention>         Specifies the number of seconds the commit outcome is retained
    -replay_init_time <replay_initiation_time> Seconds after which replay will not be initiated
    -session_state <session_state> Session state consistency (STATIC or DYNAMIC)
    -pqservice <pq_service>        Parallel query service name
    -pqpool "<pq_pool_list>"       Comma separated list of parallel query server pool names
    -gsmflags <gsm_flags>          Set locality and region failover values
    -tablefamilyid <table_family_id> Set table family ID for a given service
    -drain_timeout <drain_timeout> Service drain timeout specified in seconds
    -stopoption <stop_options>     Options to stop service (e.g. TRANSACTIONAL or IMMEDIATE)
    -css_critical {YES | NO}          Define whether the database or service is CSS critical
    -rfpool <pool_name>            Reader farm server pool name
    -hubsvc <hub_service>            Hub service used by Reader Farm service
    -eval                          Evaluates the effects of event without making any changes to the system
Usage: srvctl add service -db <db_unique_name> -service "<service_name_list>" -update {-preferred "<new_pref_inst>" | -available "<new_avail_inst>"} [-force] [-verbose]
    -db <db_unique_name>           Unique name for the database
    -service "<serv,...>"          Comma separated service names
    -update                        Add a new instance to service configuration
    -preferred <new_pref_inst>     Name of new preferred instance
    -available <new_avail_inst>    Name of new available instance
    -force                         Force the add operation even though a listener is not configured for a network
    -verbose                       Verbose output
    -help                          Print usage
    
#oracle11gRAC

[root@stuora1 ~]# su - oracle
Last login: Sun Oct  9 14:41:38 CST 2022 on pts/0
[oracle@stuora1 ~]$ srvctl add service -help

Adds a service configuration to the Oracle Clusterware.

Usage: srvctl add service -d <db_unique_name> -s <service_name> {-r "<preferred_list>" [-a "<available_list>"] [-P {BASIC | NONE | PRECONNECT}] | -g <pool_name> [-c {UNIFORM | SINGLETON}] } [-k   <net_num>] [-l [PRIMARY][,PHYSICAL_STANDBY][,LOGICAL_STANDBY][,SNAPSHOT_STANDBY]] [-y {AUTOMATIC | MANUAL}] [-q {TRUE|FALSE}] [-x {TRUE|FALSE}] [-j {SHORT|LONG}] [-B {NONE|SERVICE_TIME|THROUGHPUT}] [-e {NONE|SESSION|SELECT}] [-m {NONE|BASIC}] [-z <failover_retries>] [-w <failover_delay>] [-t <edition>] [-f]
    -d <db_unique_name>      Unique name for the database
    -s <service>             Service name
    -r "<preferred_list>"    Comma separated list of preferred instances
    -a "<available_list>"    Comma separated list of available instances
    -g <pool_name>           Server pool name
    -c {UNIFORM | SINGLETON} Service runs on every active server in the server pool hosting this service (UNIFORM) or just one server (SINGLETON)
    -k <net_num>             network number (default number is 1)
    -P {NONE | BASIC | PRECONNECT}        TAF policy specification
    -l <role>                Role of the service (primary, physical_standby, logical_standby, snapshot_standby)
    -y <policy>              Management policy for the service (AUTOMATIC or MANUAL)
    -e <Failover type>       Failover type (NONE, SESSION, or SELECT)
    -m <Failover method>     Failover method (NONE or BASIC)
    -w <integer>             Failover delay
    -z <integer>             Failover retries
    -t <edition>             Edition (or "" for empty edition value)
    -j <clb_goal>  Connection Load Balancing Goal (SHORT or LONG). Default is LONG.
    -B <Runtime Load Balancing Goal>     Runtime Load Balancing Goal (SERVICE_TIME, THROUGHPUT, or NONE)
    -x <Distributed Transaction Processing>  Distributed Transaction Processing (TRUE or FALSE)
    -q <AQ HA notifications> AQ HA notifications (TRUE or FALSE)
Usage: srvctl add service -d <db_unique_name> -s <service_name> -u {-r "<new_pref_inst>" | -a "<new_avail_inst>"} [-f]
    -d <db_unique_name>      Unique name for the database
    -s <service>             Service name
    -u                       Add a new instance to service configuration
    -r <new_pref_inst>       Name of new preferred instance
    -a <new_avail_inst>      Name of new available instance
    -f                       Force the add operation even though a listener is not configured for a network
    -h                       Print usage
[oracle@stuora1 ~]$

[oracle@k8s-19rac01 ~]$ srvctl add service -d xydb -s s_portal -r xydb1,xydb2,xydb3 -P basic -e select -m basic -z 180 -w 5 -pdb portal
[oracle@k8s-19rac01 ~]$ srvctl start service -d xydb -s s_portal
[oracle@k8s-19rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 06-DEC-2022 21:49:02

Copyright (c) 1991, 2019, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                05-DEC-2022 20:58:22
Uptime                    1 days 0 hr. 50 min. 40 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/k8s-19rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.1)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.16.134.2)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "ef14db5ce59d2d91e053018610ac1806" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[oracle@k8s-19rac01 ~]$ 

sqlplus pdbadmin/<DSA_PWD>@172.16.134.9:1521/s_dataassets

sqlplus pdbadmin/<DSA_PWD>@172.16.134.8:1521/s_portal
```



### 10.7.节点三加入后的redo/SRL一致性校验

#!!!添加节点不会自动继承6.4.9的redo调整,thread 3很可能仍是默认大小,必须校验

```sql
select thread#, group#, bytes/1024/1024 size_mb, status
from v$log order by thread#, group#;

--已配置ADG时同时校验SRL(主备两侧都要执行)
select thread#, group#, bytes/1024/1024 size_mb, status
from v$standby_log order by thread#, group#;
```

#验收标准:
#1)每个thread至少3组online redo
#2)所有online redo大小一致(本环境2G);thread 3不一致时按6.4.9步骤调整
#3)已配ADG时:SRL组数=各thread online组数+1,尺寸与online redo一致,主备两侧均满足



### 10.8.删除节点runbook(以删除节点三k8s-19rac03为例)

#适用:节点缩容、节点硬件报废后重建;与本章添加流程互为对称
#前置:OCR手工备份(6.5.2.2)、确认当日RMAN备份OK、确认无service仅以xydb3为preferred实例

```bash
#0.服务收缩(节点一,oracle)
su - oracle
srvctl status service -d xydb
srvctl modify service -d xydb -s s_portal -modifyconfig -preferred "xydb1,xydb2"
#其余service同理;观察确认无业务连接残留在实例三
```

```bash
#1.删除数据库实例(节点一,oracle,dbca静默)
dbca -silent -deleteInstance -nodeList k8s-19rac03 \
     -gdbName xydb -instanceName xydb3 \
     -sysDBAUserName sys -sysDBAPassword <SYS_PWD>
```

```sql
--确认thread 3已禁用、对应redo/undo已清理
select thread#, status, instance from gv$thread;
select group#, thread# from v$log order by thread#;

--已配ADG时,主备两侧同步删除thread 3的SRL(组号以v$standby_log实际值为准):
--alter database drop standby logfile group 61;  --61~64逐组执行
```

```bash
#2.缩减DB home节点清单
#2.1 被删节点k8s-19rac03(oracle):
$ORACLE_HOME/oui/bin/runInstaller -updateNodeList ORACLE_HOME=$ORACLE_HOME \
  "CLUSTER_NODES={k8s-19rac03}" -local
$ORACLE_HOME/deinstall/deinstall -local

#2.2 保留节点(节点一,oracle):
$ORACLE_HOME/oui/bin/runInstaller -updateNodeList ORACLE_HOME=$ORACLE_HOME \
  "CLUSTER_NODES={k8s-19rac01,k8s-19rac02}"
```

```bash
#3.GI层删除
#3.1 被删节点(root):反配置CRS
/u01/app/19.0.0/grid/crs/install/rootcrs.sh -deconfig -force

#3.2 保留节点(节点一,root):
crsctl delete node -n k8s-19rac03
olsnodes -n -s

#3.3 保留节点(节点一,grid):更新GI节点清单
/u01/app/19.0.0/grid/oui/bin/runInstaller -updateNodeList ORACLE_HOME=/u01/app/19.0.0/grid \
  "CLUSTER_NODES={k8s-19rac01,k8s-19rac02}" CRS=TRUE
```

```bash
#4.校验与清理(节点一)
su - grid
cluvfy stage -post nodedel -n k8s-19rac03 -verbose

#清理:各节点hosts/known_hosts中k8s-19rac03条目按需处理、监控摘除该节点、
#节点三上配置过的备份cron一并清理
#复核:重跑10.7节redo/SRL校验;ADG环境再执行12.6验证与13.2 postcheck
```



## 11.压测

### 11.1.Swingbench压测方案

#Swingbench is a free load generator (and benchmarks) designed to stress test an Oracle database (12c, 18c, 19c, 21c, 23c).

![img](oracle19cRacole7threenodes\cdeb554b6aa29d838456c8d5d3370681.png)

#### 11.1.1.准备测试环境

```bash
#压测机前置条件
#swingbenchlatest需要jdk1.17及以上
#需要有oracle客户端


#此处安装jdk1.21
#压测机root账户
cd /opt
wget https://download.oracle.com/java/21/archive/jdk-21.0.5_linux-x64_bin.tar.gz
tar -zxvf jdk-21.0.5_linux-x64_bin.tar.gz
cd /opt/jdk-21.0.5

cat >> /etc/profile <<'EOF'

export JAVA_HOME=/opt/jdk-21.0.5
#export JRE_HOME=$JAVA_HOME/jre
export CLASSPATH=$JAVA_HOME/lib:$CLASSPATH
export PATH=$JAVA_HOME/bin:$PATH
EOF

source /etc/profile

echo $JAVA_HOME

java -version


#压测机oracle账户
#连接oracle rac scanIP
sqlplus system/<SYS_PWD>@172.18.13.176:1521/s_stuwork


#官网
#https://www.dominicgiles.com/downloads/
#https://github.com/domgiles/swingbench-public
#Swingbench 2.7

#压测机oracle账户
mkdir -p /home/oracle/swingbench
cd /home/oracle/swingbench

#wget https://www.dominicgiles.com/site_downloads/swingbenchlatest.zip
wget https://github.com/domgiles/swingbench-public/releases/download/production/swingbench25092024.zip

unzip swingbench25092024.zip

```



#logs

```bash
[root@k8s-rac01 jdk-21.0.5]# echo $JAVA_HOME
/opt/jdk-21.0.5
[root@k8s-rac01 jdk-21.0.5]# java -version
java version "21.0.5" 2024-10-15 LTS
Java(TM) SE Runtime Environment (build 21.0.5+9-LTS-239)
Java HotSpot(TM) 64-Bit Server VM (build 21.0.5+9-LTS-239, mixed mode, sharing)


[root@k8s-rac01 ~]# su - oracle
Last login: Fri Apr  4 22:27:39 CST 2025

[oracle@k8s-rac01 ~]$ sqlplus system/<SYS_PWD>@172.18.13.176:1521/s_stuwork

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Apr 4 22:42:28 2025
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

Last Successful login time: Wed Apr 02 2025 14:28:32 +08:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SYSTEM@172.18.13.176:1521/s_stuwork> 



[oracle@k8s-rac01 ~]$ mkdir -p /home/oracle/swingbench
[oracle@k8s-rac01 ~]$ cd /home/oracle/swingbench

[oracle@k8s-rac01 swingbench]$ wget https://github.com/domgiles/swingbench-public/releases/download/production/swingbench25092024.zip

[oracle@k8s-rac01 swingbench]$ ll -rth
total 49M
-rw-r--r--  1 oracle oinstall  49M Apr  4 23:10 swingbench25092024.zip

[oracle@k8s-rac01 swingbench]$ unzip swingbench25092024.zip 
```



#### 11.1.2.准备测试数据

#创建测试用户和表空间---在rac集群中的某个节点上执行

```sql
#登录到RAC数据库，创建专用的测试用户和表空间
#
su - oracle
sqlplus / as sysdba
show pdbs;
alter session set container=stuwork;


-- 创建表空间
#normal tbs
CREATE TABLESPACE swingbench_data 
DATAFILE '+DATA' SIZE 10G 
AUTOEXTEND ON NEXT 1G MAXSIZE 31G;

ALTER TABLESPACE swingbench_data 
ADD DATAFILE '+DATA' SIZE 10G 
AUTOEXTEND ON NEXT 1G MAXSIZE 31G;

#推荐使用
#bigfile tbs
CREATE BIGFILE TABLESPACE swingbench_data
DATAFILE '+DATA' SIZE 5G 
AUTOEXTEND ON NEXT 1G MAXSIZE 50G;

CREATE TABLESPACE swingbench_index 
DATAFILE '+DATA' SIZE 5G 
AUTOEXTEND ON NEXT 1G MAXSIZE 31G;

-- 创建测试用户
CREATE USER soe IDENTIFIED BY soe
DEFAULT TABLESPACE swingbench_data 
TEMPORARY TABLESPACE temp;

-- 授予必要权限
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE JOB, CREATE EXTERNAL JOB TO soe;
GRANT UNLIMITED TABLESPACE TO soe;
GRANT EXECUTE ON DBMS_LOCK TO soe;
GRANT EXECUTE ON DBMS_RANDOM TO soe;
GRANT ANALYZE ANY DICTIONARY TO soe;
GRANT ANALYZE ANY TO soe;
GRANT ADMINISTER DATABASE TRIGGER TO soe;


#不能使用system，GRANT EXECUTE ON DBMS_LOCK TO soe;会权限不足
#sqlplus system/<SYS_PWD>@172.18.13.176:1521/s_stuwork
SYSTEM@172.18.13.176:1521/s_stuwork> GRANT EXECUTE ON DBMS_LOCK TO soe;
GRANT EXECUTE ON DBMS_LOCK TO soe
                 *
ERROR at line 1:
ORA-01031: insufficient privileges


```



#创建测试数据模型---在测试机上执行

```bash
#Swingbench提供了多种测试模型，这里使用Order Entry (SOE)模型

#oewizard : Installs a simple order entry schema that is used to create a heavy write workload
#shwizard : Installs a simple star schema that is used to create an analytics workload
#jsonwizard : Installs a simple JSON schema that is used to create a JSON CRUD workload
#tpcdswizard : Installs a TPC-DS like schema that is used to create a complex analytics workload
#tpchwizard : Installs a TPC-H like schema that is used to create a medium-complexity analytics workload
#moviewizard : Installs a Movie Stream schema that features primarily OLTP like transactions but also uses AQ Sharded Queues to simulate events used in microservices

#普通账户soe连接测试
sqlplus system/<SYS_PWD>@172.18.13.176:1521/s_stuwork


cd /home/oracle/swingbench/swingbench
# 设置环境变量
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export PATH=$ORACLE_HOME/bin:$PATH
export TNS_ADMIN=$ORACLE_HOME/network/admin


# 创建SOE架构和数据
#linux GUI创建./bin/oewizard
#windows cd .\winbin\  ---> oewizard.bat
  
#./oewizard -cl -create -scale 10 -cs "//rac-scan-ip:1521/your_service_name" -dbap "sys_password" -u swingbench -p swingbench -ts swingbench_tbs -tc 16
参数说明：
-cl：命令行模式
-create：创建数据
-scale：数据规模（10表示约10GB数据，根据需求调整）
-cs：连接字符串，使用RAC的SCAN IP和服务名
-dbap：系统用户密码
-u、-p：测试用户及密码
-ts：表空间名
-tc： 线程线程数（根据CPU核数调整）


./bin/oewizard -cl \
  -cs //172.18.13.176:1521/s_stuwork \
  #-dba "sys as sysdba" \
  -dbap "abc123" \
  -u soe \
  -p soe \
  -ts swingbench_data \
  -its swingbench_index \
  -scale 1 \
  -create \
  -v \
  #-c /home/oracle/swingbench/configs/SOE_Server_Side_V2.xml \
  -df +DATA \
  -nopart

./bin/oewizard -cl \
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
  -df +DATA \
  -nopart

```



#### 11.1.3.配置并执行压测

##### 11.1.3.1.基本压测配置---非必须，后面命令行指定的参数将覆盖配置文件中的参数设置

```bash
#创建一个自定义配置文件
cp configs/SOE_Server_Side_V2.xml configs/19RAC_Test.xml

#编辑配置文件，调整以下参数
vi configs/19RAC_Test.xml

#修改以下关键参数：

<Connection>: 确保使用RAC的SCAN地址
<UserCount>: 设置并发用户数
<MinThinkTime>: 最小思考时间（毫秒）
<MaxThinkTime>: 最大思考时间（毫秒）
<LogonGroupCount>: 登录组数量

#正确值
<ConnectString>//172.18.13.176:1521/s_stuwork</ConnectString>
<UserCount>: 设置并发用户数
<MinThinkTime>: 最小思考时间（毫秒）
<MaxThinkTime>: 最大思考时间（毫秒）
<LogonGroupCount>: 登录组数量
```



##### 11.1.3.2.执行基本压测

#图形压测swingbench

```bash
# 执行30分钟的压测，100个并发用户

#linux
cd /home/oracle/swingbench/swingbench
./bin/swingbench -c ../configs/SOE_Server_Side_V2.xml

#windows
 cd winbin
 swingbench.bat -c ..\configs\SOE_Server_Side_V2.xml
```

![image-20250408161129134](oracle19cRacole7threenodes\image-20250408161129134.png)

#命令行压测charbench

```bash
cd /home/oracle/swingbench/swingbench

# 执行30分钟的压测，100个并发用户
./bin/charbench \
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
  -r 100results.xml \
  -a

#参数说明：

-c: 配置文件路径
-cs: 连接字符串
-u: 用户名
-p: 密码
-v: 要显示的统计信息
-intermin/-intermax: 交互最小/最大思考时间
-min/-max: 最小/最大思考时间
-uc: 用户数量
-rt: 运行时间（HH:MM格式）
-r: 指定结果文件
-a: 自动启动
```



##### 11.1.3.3.逐步增加负载

```bash
# 执行200个并发用户的测试
./bin/charbench \
  -c ./configs/19RAC_Test.xml \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe \
  -p soe \
  -v users,tpm,tps,errs,resp,vresp,dbtime \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 200 \
  -rt 00:30 \
  -r 200results.xml \
  -a

# 执行500个并发用户的测试
./bin/charbench \
  -c ./configs/19RAC_Test.xml \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe \
  -p soe \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 500 \
  -rt 00:30 \
  -r 500results.xml \
  -a

# 执行1000个并发用户的测试
./bin/charbench \
  -c ./configs/19RAC_Test.xml \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe \
  -p soe \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 1000 \
  -rt 00:30 \
  -r 1000results.xml \
  -a
```



#### 11.1.4.高级测试场景

##### 11.1.4.1.节点故障转移测试

#在执行压测的同时，模拟节点故障

#driver Type 要切换到Oracle oci Driver

#在swingbench中配置使用AppContinuityDriver的驱动。如果不使用这个驱动，测试不会成功，这个就是应用连续性的驱动

#需开启参数

```conf
<Properties>
            <Property Key="FetchSize">20</Property>
            <Property Key="AppContinuityDriver">true</Property>
            <Property Key="StatementCaching">120</Property>
            <Property Key="FastFailover">true</Property>
</Properties>
```





```bash
# 在一个终端启动压测
./bin/charbench \
  -c ./configs/19RAC_Test.xml \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe \
  -p soe \
  -v users,tpm,tps \
  -intermin 0 \
  -intermax 0 \
  -min 0 \
  -max 0 \
  -uc 500 \
  -rt 01:00 \
  -a

# 在另一个终端，以root用户身份关闭一个RAC节点（例如node2）
ssh root@rac-node2 "/u01/app/19.0.0/grid/bin/crsctl stop crs -f"
```

#观察Swingbench输出，记录故障发生时的性能下降和恢复情况



##### 11.1.4.2.RAC负载均衡测试

#使用以下命令查看RAC各节点的负载分布

```bash
# 在压测过程中，登录到数据库并执行以下SQL
sqlplus / as sysdba

-- 查看各节点的会话分布
SELECT inst_id, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE01' 
GROUP BY inst_id;

select i.host_name, s.username from gv$session s join gv$instance i on (i.inst_id=s.inst_id) where username is not null;

-- 查看各节点的负载情况
SELECT inst_id, value 
FROM gv$sysmetric 
WHERE metric_name = 'CPU Usage Per Sec' 
AND group_id = 2;

```



##### 11.1.4.3.长时间稳定性测试

#执行一个长时间（如24小时）的压测，验证系统的稳定性

```bash
./bin/charbench \
  -c ./configs/19RAC_Test.xml \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe01 \
  -p soe01 \
  -v users,tpm,tps,trans,errs \
  -intermin 100 \
  -intermax 50 \
  -min 0 \
  -max 30 \
  -uc 300 \
  -rt 24:00 \
  -a \
  -r /home/oracle/swingbench/24hour_test.xml
```

![image-20250409181846141](oracle19cRacole7threenodes\image-20250409181846141.png)



#调整参数后压测

```sql
#cdb下
ALTER SYSTEM SET log_buffer=256M scope=spfile sid='*';

ALTER SYSTEM SET gcs_server_processes=16 SCOPE=SPFILE sid='*'; 
```





![image-20250411141746863](oracle19cRacole7threenodes\image-20250411141746863.png)



#logs

```bash
Swingbench 
Author  :  	 Dominic Giles 
Version :  	 2.7.0.1511  

Results will be written to results.xml 

Time      Users       TPM      TPS     
11:40:05  [0/300]     0        0       
The following error has occcured. Further occurences will be supressed but the error count will be incremented and recorded in the results file 
java.sql.SQLException: null 
11:40:06  [42/300]    40       40      
11:40:07  [93/300]    418      378     
11:40:08  [143/300]   1086     668     
11:40:09  [193/300]   2032     946     
11:40:10  [237/300]   3152     1120    
11:40:11  [288/300]   4454     1302    
11:40:12  [300/300]   6002     1548    
11:40:13  [300/300]   7569     1567    
11:40:14  [300/300]   9265     1696    
11:40:15  [300/300]   10817    1552    

```





#### 11.1.5.监控与分析

##### 11.1.5.1.实时监控

#在压测过程中，使用以下命令监控数据库性能

```sql
-- 查看等待事件
SELECT event, COUNT(*) 
FROM gv$session 
WHERE username = 'SOE' AND wait_class != 'Idle' 
GROUP BY event 
ORDER BY COUNT(*) DESC;

-- cdb 查看资源使用情况
SELECT inst_id, resource_name, current_utilization, max_utilization 
FROM gv$resource_limit 
WHERE resource_name IN ('processes', 'sessions', 'transactions') 
ORDER BY inst_id, resource_name;

--- cdb sga/pga使用率

select name,total,round(total-free,2) used, round(free,2) free,round((total-free)/total*100,2) pctused from
(select 'SGA' name,(select sum(value/1024/1024) from v$sga) total,
(select sum(bytes/1024/1024) from v$sgastat where name='free memory')free from dual)
union
select name,total,round(used,2)used,round(total-used,2)free,round(used/total*100,2)pctused from (
select 'PGA' name,(select value/1024/1024 total from v$pgastat where name='aggregate PGA target parameter')total,
(select value/1024/1024 used from v$pgastat where name='total PGA allocated')used from dual);



--- cdb sga/pga详细内存组件使用率

select name,total,round(total-free,2) used, round(free,2) free,round((total-free)/total*100,2) pctused from
(select 'SGA' name,(select sum(value/1024/1024) from v$sga) total,
(select sum(bytes/1024/1024) from v$sgastat where name='free memory')free from dual)
union
select name,total,round(used,2)used,round(total-used,2)free,round(used/total*100,2)pctused from (
select 'PGA' name,(select value/1024/1024 total from v$pgastat where name='aggregate PGA target parameter')total,
(select value/1024/1024 used from v$pgastat where name='total PGA allocated')used from dual)
union
select name,round(total,2) total,round((total-free),2) used,round(free,2) free,round((total-free)/total*100,2) pctused from (
select 'Shared pool' name,(select sum(bytes/1024/1024) from v$sgastat where pool='shared pool')total,
(select bytes/1024/1024 from v$sgastat where name='free memory' and pool='shared pool') free from dual)
union
select name,round(total,2)total,round(total-free,2) used,round(free,2) free,round((total-free)/total,2) pctused from (
select 'Default pool' name,( select a.cnum_repl*(select value from v$parameter where name='db_block_size')/1024/1024 total from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='DEFAULT' and p.block_size=(select value from v$parameter where name='db_block_size')) total,
(select a.anum_repl*(select value from v$parameter where name='db_block_size')/1024/1024 free from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='DEFAULT' and p.block_size=(select value from v$parameter where name='db_block_size')) free from dual)
union
select name,nvl(round(total,2),0)total,nvl(round(total-free,2),0) used,nvl(round(free,2),0) free,nvl(round((total-free)/total,2),0) pctused from (
select 'KEEP pool' name,(select a.cnum_repl*(select value from v$parameter where name='db_block_size')/1024/1024 total from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='KEEP' and p.block_size=(select value from v$parameter where name='db_block_size')) total,
(select a.anum_repl*(select value from v$parameter where name='db_block_size')/1024/1024 free from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='KEEP' and p.block_size=(select value from v$parameter where name='db_block_size')) free from dual)
union
select name,nvl(round(total,2),0)total,nvl(round(total-free,2),0) used,nvl(round(free,2),0) free,nvl(round((total-free)/total,2),0) pctused from (
select 'RECYCLE pool' name,( select a.cnum_repl*(select value from v$parameter where name='db_block_size')/1024/1024 total from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='RECYCLE' and p.block_size=(select value from v$parameter where name='db_block_size')) total,
(select a.anum_repl*(select value from v$parameter where name='db_block_size')/1024/1024 free from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='RECYCLE' and p.block_size=(select value from v$parameter where name='db_block_size')) free from dual)
union
select name,nvl(round(total,2),0)total,nvl(round(total-free,2),0) used,nvl(round(free,2),0) free,nvl(round((total-free)/total,2),0) pctused from(
select 'DEFAULT 16K buffer cache' name,(select a.cnum_repl*16/1024 total from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='DEFAULT' and p.block_size=16384) total,
(select a.anum_repl*16/1024 free from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='DEFAULT' and p.block_size=16384) free from dual)
union
select name,nvl(round(total,2),0)total,nvl(round(total-free,2),0) used,nvl(round(free,2),0) free,nvl(round((total-free)/total,2),0) pctused from(
select 'DEFAULT 32K buffer cache' name,(select a.cnum_repl*32/1024 total from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='DEFAULT' and p.block_size=32768) total,
(select a.anum_repl*32/1024 free from x$kcbwds a, v$buffer_pool p
where a.set_id=p.LO_SETID and p.name='DEFAULT' and p.block_size=32768) free from dual)
union
select name,total,total-free used,free, (total-free)/total*100 pctused from (
select 'Java Pool' name,(select sum(bytes/1024/1024) total from v$sgastat where pool='java pool' group by pool)total,
( select bytes/1024/1024 free from v$sgastat where pool='java pool' and name='free memory')free from dual)
union
select name,Round(total,2),round(total-free,2) used,round(free,2) free, round((total-free)/total*100,2) pctused from (
select 'Large Pool' name,(select sum(bytes/1024/1024) total from v$sgastat where pool='large pool' group by pool)total,
( select bytes/1024/1024 free from v$sgastat where pool='large pool' and name='free memory')free from dual)
order by pctused desc;

```



##### 11.1.5.2.生成AWR报告

###### 11.1.5.2.1.cdb级别

#在测试前后生成AWR报告，分析性能数据

```sql
-- 创建基准AWR快照
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();

-- 记下快照ID
SELECT snap_id, instance_number, begin_interval_time 
FROM dba_hist_snapshot 
ORDER BY begin_interval_time DESC;

-- 测试结束后，再创建一个快照
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();

-- 生成AWR报告（替换快照ID）
@?/rdbms/admin/awrgrpt.sql

Specify the location of AWR Data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
AWR_ROOT - Use AWR data from root (default)
AWR_PDB - Use AWR data from PDB
Enter value for awr_location:
```

###### 11.1.5.2.2.pdb级别

```sql
#在测试前后手动创建PDB级别的AWR快照
sqlplus / as sysdba
alter session set container=stuwork;
exec dbms_workload_repository.create_snapshot();


SQL> alter session set container=CDB$ROOT;
SQL> select con_id, instance_number, snap_id, begin_interval_time, end_interval_time from cdb_hist_snapshot order by 1,2,3;

#测试完成后，生成AWR报告---只需要进入一个实例，去pdb里生成awr报告
alter session set container=stuwork;

#rac
@?/rdbms/admin/awrgrpt.sql

Specify the location of AWR Data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
AWR_ROOT - Use AWR data from root (default)
AWR_PDB - Use AWR data from PDB
Enter value for awr_location:

#单独该实例的
@?/rdbms/admin/awrrpt.sql

Specify the location of AWR Data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
AWR_ROOT - Use AWR data from root (default)
AWR_PDB - Use AWR data from PDB
Enter value for awr_location:
```



#oracle文档说明

```bash
#AWR Snapshots and Reports from Oracle Multitentant Database(CDB, PDB) (Doc ID 2295998.1)
- In 12.1
AWR Snapshots and Reports can be created only at the CDB level.

- In 12.2 and later
AWR Snapshots and Reports can be created both at the CDB level and at the PDB level.
AWR Snapshots can be generated only at the CDB level by default.

 

#Manual creation of PDB AWR snapshot.
   SQL> connect <username>/<password> as sysdba
   SQL> alter session set container=PDB1;
   SQL> exec dbms_workload_repository.create_snapshot();


#Configuration for automatic creation of PDB AWR snapshots.

SQL> alter session set container = CDB$ROOT;
SQL> alter system set AWR_PDB_AUTOFLUSH_ENABLED = TRUE;
SQL> alter system set AWR_SNAPSHOT_TIME_OFFSET=1000000; 

SQL> select * from cdb_hist_wr_control;    

      DBID SNAP_INTERVAL                            RETENTION                                TOPNSQL        CON_ID
---------- ---------------------------------------- ---------------------------------------- ---------- ----------
1793141417 +00000 01:00:00.0                        +00008 00:00:00.0                        DEFAULT             0
4182556862 +40150 00:01:00.0                        +00008 00:00:00.0                        DEFAULT             3  

#The snap_interval for PDB is too long by default, so it is required to change it.

SQL> alter session set container=PDB1;
SQL> exec dbms_workload_repository.modify_snapshot_settings(interval => 30, dbid => 4182556862);

SQL> alter session set container = CDB$ROOT;
SQL> select * from cdb_hist_wr_control;

      DBID SNAP_INTERVAL                            RETENTION                                TOPNSQL        CON_ID
---------- ---------------------------------------- ---------------------------------------- ---------- ----------
1793141417 +00000 01:00:00.0                        +00008 00:00:00.0                        DEFAULT             0
4182556862 +00000 00:30:00.0                        +00008 00:00:00.0                        DEFAULT             3



#You can find AWR snapshots(CDB,PDB) from cdb_hist_snapshot.


SQL> alter session set container=CDB$ROOT;
SQL> select con_id, instance_number, snap_id, begin_interval_time, end_interval_time from cdb_hist_snapshot order by 1,2,3;

    CON_ID INSTANCE_NUMBER    SNAP_ID BEGIN_INTERVAL_TIME              END_INTERVAL_TIME
---------- --------------- ---------- -------------------------------- --------------------------------
         0               1          1 28-FEB-19 06.26.06.000 PM        28-FEB-19 07.00.14.425 PM
         0               1          2 28-FEB-19 07.00.14.425 PM        28-FEB-19 08.00.30.362 PM
         0               1          3 28-FEB-19 08.00.30.362 PM        28-FEB-19 09.00.46.286 PM
         0               1          4 28-FEB-19 09.00.46.286 PM        28-FEB-19 10.00.02.598 PM
         0               1          5 28-FEB-19 10.00.02.598 PM        28-FEB-19 11.00.15.351 PM
         3               1          1 28-FEB-19 07.00.14.425 PM        28-FEB-19 07.30.36.225 PM   <<--- PDB snapshot
         3               1          2 28-FEB-19 07.30.36.225 PM        28-FEB-19 08.00.31.532 PM   <<--- PDB snapshot
         3               1          3 28-FEB-19 08.00.31.532 PM        28-FEB-19 08.30.10.270 PM   <<--- PDB snapshot


#Creation of CDB AWR report
SQL> alter session set container=CDB$ROOT;
SQL> @?/rdbms/admin/awrrpt    

#Creation of PDB AWR report


SQL> alter session set container=PDB1;
SQL> @?/rdbms/admin/awrrpt

Specify the Report Type
~~~~~~~~~~~~~~~~~~~~~~~
AWR reports can be generated in the following formats.  Please enter the name of the format at the prompt.  Default value is 'html'.

'html'          HTML format (default)
'text'          Text format
'active-html'   Includes Performance Hub active report

Enter value for report_type:

Specify the location of AWR Data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
AWR_ROOT - Use AWR data from root (default)  
AWR_PDB  - Use AWR data from PDB          <<------- This can be chosen only if PDB snapshots have been created separately.
 
Enter value for awr_location: AWR_PDB
...........
```



#无法通过循环创建pdb的快照

#error

```sql
-- 在CDB$ROOT容器中执行，自动在所有实例的指定PDB中创建快照
sqlplus / as sysdba

DECLARE
  v_con_name VARCHAR2(30) := 'STUWORK';
BEGIN
  FOR rec IN (SELECT inst_id FROM gv$instance) LOOP
    dbms_workload_repository.create_snapshot(
      con_id => (SELECT con_id FROM cdb_pdbs WHERE pdb_name = v_con_name),
      inst_id => rec.inst_id
    );
  END LOOP;
END;
/
```

```sql
-- 在CDB$ROOT容器中执行，自动在所有实例的指定PDB中创建快照
sqlplus / as sysdba

DECLARE
  v_con_id NUMBER;
  v_pdb_name VARCHAR2(30) := 'STUWORK';
BEGIN
  -- 获取PDB的CON_ID
  SELECT con_id INTO v_con_id FROM cdb_pdbs WHERE pdb_name = v_pdb_name;

  -- 循环所有实例创建快照
  FOR rec IN (SELECT inst_id FROM gv$instance) LOOP
    dbms_workload_repository.create_snapshot(
      con_id => v_con_id,
      inst_id => rec.inst_id
    );
  END LOOP;
END;
/
```



#测试完成后，生成AWR报告

```sql
#测试完成后，生成AWR报告
alter session set container=stuwork;
@?/rdbms/admin/awrrpt.sql
```



##### 11.1.5.3.分析Swingbench结果

#Swingbench生成的结果文件可以用来分析性能

```bash
#生成pdf文件
./bin/results2pdf -c results.xml -o 100results.pdf

#下载查看
```

#图形化时

![image-20250408161626299](oracle19cRacole7threenodes\image-20250408161626299.png)



![image-20250408165010423](oracle19cRacole7threenodes\image-20250408165010423.png)



![image-20250408165113716](oracle19cRacole7threenodes\image-20250408165113716.png)



![image-20250408165246711](oracle19cRacole7threenodes\image-20250408165246711.png)



#### 11.1.6.清理测试环境

#测试完成后，可以清理测试数据

```bash
# 删除SOE架构
./bin/oewizard \
  -cl \
  -cs //172.18.13.176:1521/s_stuwork \
  -u soe \
  -p soe \
  -drop
  
```

```sql
-- 或者通过SQL删除用户和表空间
DROP USER soe CASCADE;
DROP TABLESPACE swingbench_data INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE swingbench_index INCLUDING CONTENTS AND DATAFILES;
```

#### 11.1.7.常见问题解决

##### 11.1.7.1.连接问题

如果遇到连接问题，检查：
- tnsnames.ora配置是否正确
- 监听器是否正常运行
- 防火墙设置是否允许连接

##### 11.1.7.2.性能问题

如果性能不如预期：
- 检查表空间是否有足够空间
- 确认数据库参数设置是否合理
- 检查网络延迟是否过高

##### 11.1.7.3.资源限制

如果遇到资源限制：
- 增加processes参数值
- 调整sessions参数
- 检查操作系统资源限制

#### 11.1.8.操作日志logs

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-11-01-08 11.1.8 Swingbench操作日志**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

### 11.2.P3:容量规划方法(由压测/AWR转生产规格)

#定位:11.1给出压测执行过程,本节把压测和AWR数据转换为容量规划结论。
#容量规划不是一次性表格,而是每次上线、扩容、补丁后压测、业务峰值变化后都要复核的过程。

#### 11.2.1.容量规划输入数据

| 输入项 | 获取方式 | 用途 |
| ------ | -------- | ---- |
| 业务峰值TPS/QPS/并发 | 应用压测、网关、连接池监控 | 估算sessions/processes、CPU、连接池规模 |
| AWR/ASH | `awrrpt.sql`、`ashrpt.sql`、`dba_hist_*` | CPU、等待事件、IO、Redo、SQL热点 |
| OS指标 | `sar`, `iostat -x`, `vmstat`, 监控平台 | CPU余量、IO延迟、swap、网络吞吐 |
| Redo/归档增长 | `v$archived_log`, `v$log_history` | Redo大小、FRA、ADG带宽、备份窗口 |
| RMAN/expdp大小与耗时 | 6.5.1状态文件和日志 | 备份容量、异地同步带宽、RTO/RPO |
| ASM/FRA空间 | `v$asm_diskgroup`, `v$recovery_file_dest` | DATA/FRA扩容阈值 |

#### 11.2.2.AWR与动态视图采样SQL

```sql
--最近7天每小时redo生成量(MB),用于redo log/FRA/ADG带宽规划
set lines 200 pages 200
col hour for a16
select to_char(first_time,'yyyy-mm-dd hh24') hour,
       round(sum(blocks*block_size)/1024/1024) redo_mb
from v$archived_log
where first_time >= sysdate-7
  and standby_dest='NO'
group by to_char(first_time,'yyyy-mm-dd hh24')
order by 1;

--每小时日志切换次数,目标通常控制在高峰每thread每小时4~6次以内
select thread#, to_char(first_time,'yyyy-mm-dd hh24') hour, count(*) switches
from v$log_history
where first_time >= sysdate-7
group by thread#, to_char(first_time,'yyyy-mm-dd hh24')
order by 2,1;

--连接数/processes/sessions峰值
select inst_id, resource_name, current_utilization, max_utilization, limit_value
from gv$resource_limit
where resource_name in ('processes','sessions','transactions')
order by inst_id, resource_name;

--FRA使用率
select name,
       round(space_limit/1024/1024/1024,2) limit_gb,
       round(space_used/1024/1024/1024,2) used_gb,
       round(space_reclaimable/1024/1024/1024,2) reclaimable_gb,
       round(space_used*100/space_limit,2) used_pct
from v$recovery_file_dest;

--表空间容量和增长趋势基础数据
select tablespace_name,
       round(sum(bytes)/1024/1024/1024,2) used_gb
from dba_segments
group by tablespace_name
order by used_gb desc;
```

#### 11.2.3.容量规划决策规则

| 资源 | 规划规则 | 建议阈值/动作 |
| ---- | -------- | ------------- |
| CPU | AWR DB CPU + OS CPU双口径;峰值AAS不应长期接近CPU核数 | CPU使用率持续>70%或run queue持续偏高时扩核/SQL优化 |
| SGA | 以6.4.5为准,专用DB主机通常按物理内存60%~70%起步 | 调整后同步HugePages/memlock/use_large_pages |
| PGA | 结合并发、排序/hash、`pga_aggregate_target`命中率 | 关注PGA over allocation、TEMP暴涨 |
| processes/sessions | 峰值连接数×1.3~1.5余量 | 修改processes后需重启实例,并复核PGA下限 |
| Redo log | 高峰每thread每小时切换4~6次以内 | 高峰切换过频则增大每组redo;SRL必须同尺寸 |
| FRA | 覆盖恢复窗口内归档、备份、闪回、控制文件快照并保留余量 | 80%预警、85%处理、90%故障态,见6.4.5.6/9.8 |
| DATA | 业务数据+索引+未来增长+重建/迁移余量 | 单盘组剩余<25%进入扩容评估 |
| UNDO | 峰值事务和最长查询决定 | ORA-01555或UNDO等待增多时扩容/调优 |
| TEMP | 排序/hash/报表/批处理决定 | TEMP使用率高且反复触顶时拆分报表或扩容 |
| 备份带宽 | RMAN/expdp耗时必须小于备份窗口 | 异地同步失败或跨天未完成时增加带宽/调整窗口 |

#### 11.2.4.容量规划输出模板

| 项目 | 当前值 | 峰值观测 | 目标/建议 | 变更动作 | 回退/验证 |
| ---- | ------ | -------- | --------- | -------- | --------- |
| CPU核数 |  |  |  |  | AWR/OS CPU复核 |
| 物理内存 |  |  |  |  | HugePages/memlock复核 |
| SGA/PGA |  |  |  |  | alert log Large Pages |
| processes/sessions |  |  |  |  | `gv$resource_limit` |
| Redo大小/组数 |  |  | 每thread 3~4组,高峰4~6次/h |  | `v$log_history` |
| DATA容量 |  |  |  |  | `v$asm_diskgroup` |
| FRA容量 |  |  |  |  | `v$recovery_file_dest` |
| RMAN窗口 |  |  | 7天或项目要求 |  | restore validate/恢复演练 |
| expdp异地 |  |  | 每PDB独立文件+异地保留14天 |  | last_expdp_status |

#### 11.2.5.AWR策略与基线

```sql
--示例:将AWR保留调整为45天,采样间隔30分钟;按审计/空间要求调整
begin
  dbms_workload_repository.modify_snapshot_settings(
    retention => 45*24*60,
    interval  => 30
  );
end;
/

--创建业务高峰基线示例;时间按压测或真实峰值替换
begin
  dbms_workload_repository.create_baseline(
    start_time => to_date('2026-01-01 09:00','yyyy-mm-dd hh24:mi'),
    end_time   => to_date('2026-01-01 11:00','yyyy-mm-dd hh24:mi'),
    baseline_name => 'PEAK_LOAD_BASELINE'
  );
end;
/
```

#AWR保留期增加会占用SYSAUX空间,必须同步巡检SYSAUX增长;不要无限制拉长retention。
#容量规划结论必须进入14.6记录模板,并和6.4.5/6.4.9/6.5.1/13.5监控阈值保持一致。


## 12.ADG物理备库部署(k8s-19rac-adg)

### 12.1.架构与前提

```
主库:   xydb (RAC三节点 xydb1/xydb2/xydb3),db_unique_name=xydb,存储ASM(+DATA/+FRA)
备库:   单实例物理备库,主机k8s-19rac-adg(172.18.13.180)
        db_unique_name=xydbadg,ORACLE_SID=xydbadg,存储本地文件系统
传输:   ASYNC(最大性能模式),通过Data Guard Broker管理
数据目录: /u01/app/oracle/oradata/XYDBADG
FRA目录:  /u01/app/oracle/fast_recovery_area
```

#前提条件:
#1)主库已开归档(建库时已启用,archive log list确认)
#2)redo已按6.4.9节调整为2G(SRL尺寸必须与online redo一致,务必先调redo再建SRL)
#3)备库与主库时间同步(2.5节chrony)、/etc/hosts互通(2.4节)
#4)备库GI不需要安装,仅安装数据库软件,且RU补丁级别必须与主库一致
#!!!注意:备库读写打开+实时应用(Active Data Guard)需要ADG选件License;
#无License时备库保持MOUNT状态应用日志,同样具备容灾能力

#!!!定位与能力边界(交付前与业务方确认):
#1)本ADG为容灾库,不等价于主库RAC的横向扩展;failover后由单实例承载全部业务,
#需提前评估CPU/内存/IO/连接数容量,必要时切换后通过service限流、暂停非核心业务
#2)ASYNC最大性能模式下,极端故障可能丢失最后未传输的事务,RPO不保证为0;
#实际RPO=transport lag监控值(告警阈值5分钟);RTO=failover演练实测值(首次演练后回填:____分钟)
#3)若业务要求RPO=0,需评估SYNC+最大可用模式,代价是主备网络抖动会直接拖累主库提交延迟

### 12.2.主库端准备(任一节点执行,标注sid='*'的对全部实例生效)

#### 12.2.1.强制日志与归档检查

```sql
sqlplus / as sysdba

select log_mode, force_logging, flashback_on from v$database;

--开启force logging(否则nologging操作会造成备库坏块)
alter database force logging;

--开启flashback(为failover后reinstate原主库做准备,需要FRA空间)
alter database flashback on;

select log_mode, force_logging, flashback_on from v$database;
```

#### 12.2.2.创建standby redo log

#数量原则:每个thread = online组数+1;本环境3个thread、每thread 3组online --> 每thread 4组SRL
#尺寸必须与online redo完全一致(2G);组号避开online组
#!!!前置门禁:6.4.9与10.7校验未全部通过(各thread online redo已统一为2G)之前,禁止执行本节

```sql
alter database add standby logfile thread 1 group 41 ('+DATA') size 2G,
                                            group 42 ('+DATA') size 2G,
                                            group 43 ('+DATA') size 2G,
                                            group 44 ('+DATA') size 2G;
alter database add standby logfile thread 2 group 51 ('+DATA') size 2G,
                                            group 52 ('+DATA') size 2G,
                                            group 53 ('+DATA') size 2G,
                                            group 54 ('+DATA') size 2G;
alter database add standby logfile thread 3 group 61 ('+DATA') size 2G,
                                            group 62 ('+DATA') size 2G,
                                            group 63 ('+DATA') size 2G,
                                            group 64 ('+DATA') size 2G;

select group#, thread#, bytes/1024/1024 size_mb, status from v$standby_log order by thread#, group#;
```

#### 12.2.3.主库参数

```sql
alter system set log_archive_config='dg_config=(xydb,xydbadg)' scope=both sid='*';

--传输目标先建为defer,duplicate完成后再enable
alter system set log_archive_dest_2='service=xydbadg async noaffirm valid_for=(online_logfiles,primary_role) db_unique_name=xydbadg' scope=both sid='*';
alter system set log_archive_dest_state_2=defer scope=both sid='*';

alter system set fal_server='xydbadg' scope=both sid='*';
alter system set standby_file_management=AUTO scope=both sid='*';

--角色互换(主库变备库)时才会用到的convert参数,静态参数,下次重启窗口生效即可
alter system set db_file_name_convert='/u01/app/oracle/oradata/XYDBADG/','+DATA/XYDB/' scope=spfile sid='*';
alter system set log_file_name_convert='/u01/app/oracle/oradata/XYDBADG/','+DATA/XYDB/' scope=spfile sid='*';
```

#### 12.2.4.复制密码文件

#19c RAC密码文件默认在ASM中,先定位再用asmcmd拷出

```bash
su - oracle
srvctl config database -d xydb | grep -i password
#---> Password file: +DATA/XYDB/PASSWORD/pwdxydb.xxx.xxxxxxxxx

su - grid
asmcmd
ASMCMD> pwcopy +DATA/XYDB/PASSWORD/pwdxydb.xxx.xxxxxxxxx /tmp/orapwxydb
ASMCMD> exit

scp /tmp/orapwxydb oracle@k8s-19rac-adg:/u01/app/oracle/product/19.0.0/db_1/dbs/orapwxydbadg
#备库上确认属主与权限
#chown oracle:oinstall orapwxydbadg && chmod 640 orapwxydbadg
```

### 12.3.备库主机准备

#### 12.3.1.OS与软件安装

```bash
#1)按第2章完成OS准备:依赖包(2.2)、oracle用户(2.3,不需要grid用户)、hosts(2.4)、
#  chrony(2.5)、目录(2.6,仅oracle相关)、limits与sysctl(2.7,无私网可不加rp_filter条目)
#2)环境变量(oracle用户):
cat >> /home/oracle/.bash_profile <<'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/db_1
export ORACLE_SID=xydbadg
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
EOF

#3)仅安装数据库软件(Set Up Software Only ---> Single instance),并随安装直接打到与主库相同的RU:
su - oracle
cd $ORACLE_HOME
unzip -q /soft/LINUX.X64_193000_db_home.zip
#升级OPatch后带RU安装(RU版本与主库一致,主库当前为19.21)
./runInstaller -applyRU /soft/35643107

#4)校验补丁级别,必须与主库opatch lspatches输出一致
$ORACLE_HOME/OPatch/opatch lspatches

#5)创建目录
mkdir -p /u01/app/oracle/oradata/XYDBADG
mkdir -p /u01/app/oracle/fast_recovery_area
mkdir -p /u01/app/oracle/admin/xydbadg/adump
```

#### 12.3.2.监听静态注册(备库)

#duplicate期间辅助实例处于nomount,动态注册不可用,必须静态注册;
#同时注册xydbadg_DGMGRL服务,供Broker在switchover重启实例时连接

```bash
su - oracle
cat > $ORACLE_HOME/network/admin/listener.ora <<'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-19rac-adg)(PORT = 1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = xydbadg)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydbadg)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = xydbadg_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydbadg)
    )
  )
EOF

lsnrctl start
lsnrctl status
```

#### 12.3.3.tnsnames配置(主库三个节点 + 备库,共四台都要配)

```bash
#oracle用户,追加到 $ORACLE_HOME/network/admin/tnsnames.ora
cat >> $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'

XYDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 172.18.13.176)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydb)
    )
  )

XYDBADG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 172.18.13.180)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydbadg)
    )
  )
EOF

#四台机器互测
tnsping xydb
tnsping xydbadg
```

### 12.4.RMAN duplicate创建备库

#### 12.4.1.辅助实例启动到nomount

```bash
su - oracle
cat > /tmp/initxydbadg.ora <<EOF
db_name='xydb'
db_unique_name='xydbadg'
EOF

sqlplus / as sysdba
SQL> startup nomount pfile='/tmp/initxydbadg.ora';
SQL> exit

#验证静态监听可连(主库节点一上测试)
sqlplus sys/<SYS_PWD>@xydbadg as sysdba
SQL> select status from v$instance;
--->STARTED
```

#### 12.4.2.执行duplicate(主库节点一发起)

#备库内存按ADG虚拟机实际规格调整(示例32G主机:sga 12G/pga 4G)

```bash
su - oracle
rman target sys/<SYS_PWD>@xydb auxiliary sys/<SYS_PWD>@xydbadg log=/home/oracle/dup_xydbadg.log

run {
  allocate channel c1 type disk;
  allocate channel c2 type disk;
  allocate channel c3 type disk;
  allocate auxiliary channel a1 type disk;
  allocate auxiliary channel a2 type disk;
  duplicate target database for standby from active database
    spfile
      set db_unique_name='xydbadg'
      set cluster_database='false'
      set sga_target='12G'
      set sga_max_size='12G'
      set pga_aggregate_target='4G'
      set control_files='/u01/app/oracle/oradata/XYDBADG/control01.ctl','/u01/app/oracle/fast_recovery_area/control02.ctl'
      set db_create_file_dest='/u01/app/oracle/oradata'
      set db_recovery_file_dest='/u01/app/oracle/fast_recovery_area'
      set db_recovery_file_dest_size='150G'
      set db_file_name_convert='+DATA/XYDB/','/u01/app/oracle/oradata/XYDBADG/'
      set log_file_name_convert='+DATA/XYDB/','/u01/app/oracle/oradata/XYDBADG/','+FRA/XYDB/','/u01/app/oracle/oradata/XYDBADG/'
      set log_archive_config='dg_config=(xydb,xydbadg)'
      set log_archive_dest_2='service=xydb async noaffirm valid_for=(online_logfiles,primary_role) db_unique_name=xydb'
      set fal_server='xydb'
      set standby_file_management='AUTO'
      set audit_file_dest='/u01/app/oracle/admin/xydbadg/adump'
      set local_listener=''
      set remote_listener=''
      set use_large_pages='TRUE'
    nofilenamecheck;
}
exit;
```

#duplicate完成后,备库处于MOUNT状态;启用主库传输:

```sql
--主库任一节点
alter system set log_archive_dest_state_2=enable scope=both sid='*';
alter system switch all logfile;
```

#### 12.4.3.备库自启动(无GI环境)

```bash
#/etc/oratab 增加一行
xydbadg:/u01/app/oracle/product/19.0.0/db_1:Y

#systemd服务示例(root)
cat > /etc/systemd/system/oracle-adg.service <<'EOF'
[Unit]
Description=Oracle ADG standby database
After=network-online.target

[Service]
Type=forking
User=oracle
Group=oinstall
RemainAfterExit=yes
ExecStart=/u01/app/oracle/product/19.0.0/db_1/bin/dbstart /u01/app/oracle/product/19.0.0/db_1
ExecStop=/u01/app/oracle/product/19.0.0/db_1/bin/dbshut /u01/app/oracle/product/19.0.0/db_1
TimeoutSec=600

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable oracle-adg.service
#注意:dbstart仅startup到open/mount由oratab的Y控制,broker启动后MRP由broker自动拉起
```

### 12.5.Broker配置与启用日志应用

#### 12.5.1.开启broker

```sql
--主库(RAC环境broker配置文件必须放共享存储,先于dg_broker_start设置)
alter system set dg_broker_config_file1='+DATA/XYDB/dr1xydb.dat' scope=both sid='*';
alter system set dg_broker_config_file2='+FRA/XYDB/dr2xydb.dat' scope=both sid='*';
alter system set dg_broker_start=true scope=both sid='*';

--备库
alter system set dg_broker_start=true scope=both;
```

#### 12.5.2.创建配置

```bash
su - oracle
dgmgrl sys/<SYS_PWD>@xydb

DGMGRL> create configuration xydb_dg as primary database is xydb connect identifier is xydb;
DGMGRL> add database xydbadg as connect identifier is xydbadg maintained as physical;
DGMGRL> enable configuration;

DGMGRL> show configuration;
#期望: SUCCESS (status updated xx seconds ago)
#刚enable后可能短暂显示ORA-16610/16809,等待1~2分钟刷新
```

#### 12.5.3.打开备库(二选一)

```sql
--方式一:有ADG License,只读打开+实时应用(Active Data Guard)
--备库执行
alter database open read only;
--broker确认APPLY-ON(默认即开启实时应用,使用SRL)

--方式二:无License,保持MOUNT应用
--什么都不用做,duplicate后默认MOUNT,broker自动启动MRP
```

### 12.6.部署后验证

```bash
dgmgrl sys/<SYS_PWD>@xydb
DGMGRL> show configuration verbose;
DGMGRL> show database verbose xydbadg;
DGMGRL> validate database xydbadg;
#关注: Ready for Switchover / Ready for Failover / Standby Apply-Related下无告警
```

```sql
--备库
select database_role, open_mode, protection_mode from v$database;
--->PHYSICAL STANDBY / MOUNTED(或READ ONLY WITH APPLY)

select name, value, time_computed from v$dataguard_stats
where name in ('transport lag','apply lag');
--->两项应为+00 00:00:00附近

--应用进程状态(19c推荐视图)
select name, role, action, client_role from v$dataguard_process order by role;

--主库切日志后核对各thread已应用序列号
--主库: alter system switch all logfile;
select thread#, max(sequence#) from v$archived_log where applied='YES' group by thread# order by 1;

--gap检查(主备都查,应无记录)
select * from v$archive_gap;

--SRL核对(主备两侧都查):各thread组数=online组数+1,尺寸与online redo一致(2G)
select thread#, group#, bytes/1024/1024 size_mb, status
from v$standby_log order by thread#, group#;
```

#通过标准(部署验收与日常巡检共用同一张表):

```sql
#  show configuration              SUCCESS,无WARNING/ERROR

#  transport lag                   接近0,持续>5分钟告警

#  apply lag                       接近0,持续>5分钟告警

#  Intended State                  APPLY-ON

#  validate database xydbadg       "Ready for Switchover: Yes"

#  v$archive_gap                   主备均无记录

#  v$standby_log                   主备两侧组数/尺寸一致且满足 online组数+1
```



### 12.7.归档删除策略(与6.5.1的rmanbak.sh联动)

#!!!配置ADG后必须调整归档删除策略,否则两种事故:
#1)主库脚本把尚未传到备库的归档删了 ---> 备库gap,只能增量恢复或重建
#2)备库归档无人清理 ---> FRA爆满,MRP停止

```bash
#主库(rman target /)
RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
#6.5.1脚本中的 delete all input / delete obsolete 此后会自动跳过未传备库的归档

#备库(rman target /)
RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON STANDBY;
#备库归档放FRA(db_recovery_file_dest),空间压力时Oracle会按该策略自动清理已应用归档
```

#注意:备库长时间宕机会导致主库FRA持续堆积归档(策略阻止删除)。
#监控主库FRA使用率,超阈值且确认备库短期无法恢复时,临时处理:

```sql
#  alter system set log_archive_dest_state_2=defer sid='*';   --暂停传输

#  恢复备库后enable,gap过大用 recover standby database from service 增量同步:

#  备库MOUNT下: rman target /  ---> recover standby database from service 'xydb';
```



### 12.8.切换演练Runbook

#### 12.8.1.应用连接切换方案(任何切换演练前必须先落实)

#原则:应用不直连节点IP,统一使用"双地址描述符 + 服务名";配合角色服务,
#切换后客户端按地址列表自动找到新主库,应用侧理想情况下零改动

##双地址连接串模板(以s_portal为例,其余service同构)

```
S_PORTAL_HA =
  (DESCRIPTION =
    (CONNECT_TIMEOUT = 5)(TRANSPORT_CONNECT_TIMEOUT = 3)(RETRY_COUNT = 3)(RETRY_DELAY = 2)
    (ADDRESS_LIST =
      (LOAD_BALANCE = ON)
      (ADDRESS = (PROTOCOL = TCP)(HOST = 172.18.13.176)(PORT = 1521))
    )
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 172.18.13.180)(PORT = 1521))
    )
    (CONNECT_DATA = (SERVICE_NAME = s_portal))
  )
```

#JDBC直接内嵌同一描述符(连接池配置中替换URL即可):
#jdbc:oracle:thin:@(DESCRIPTION=(CONNECT_TIMEOUT=5)(RETRY_COUNT=3)(RETRY_DELAY=2)(ADDRESS_LIST=(LOAD_BALANCE=ON)(ADDRESS=(PROTOCOL=TCP)(HOST=172.18.13.176)(PORT=1521)))(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.18.13.180)(PORT=1521)))(CONNECT_DATA=(SERVICE_NAME=s_portal)))

##主库侧:业务service改为角色服务,仅在PRIMARY角色自动启动

```bash
su - oracle
srvctl modify service -d xydb -s s_portal -role PRIMARY
srvctl modify service -d xydb -s s_stuwork -role PRIMARY
srvctl modify service -d xydb -s s_onecode -role PRIMARY
srvctl modify service -d xydb -s s_dataassets -role PRIMARY

#确认
srvctl config service -d xydb | grep -iE "Service name|role"
```

##服务定义与触发器:统一在主库PDB内创建,随redo自动同步到备库

#!!!物理备库(MOUNT或READ ONLY)上不能执行字典变更,dbms_service.create_service和触发器
#都必须在主库创建,经redo同步到备库;switchover/failover后在新主库侧自然生效

```sql
--主库任一节点执行,以portal为例,其余PDB同理;服务名与srvctl管理的service完全一致
alter session set container=portal;

--先查服务是否已在字典登记(srvctl管理的服务首次启动后即存在);未登记才create
select name from dba_services;
--exec dbms_service.create_service('s_portal','s_portal');

--启动触发器:仅在"单实例 + PRIMARY角色"(即角色转换后的原备库)上拉起服务;
--RAC侧cluster_database=TRUE时不动作,服务仍由CRS(srvctl)管理,避免服务脱管
create or replace trigger start_svc_after_open
after startup on database
declare
  v_role varchar2(30);
  v_rac  varchar2(10);
begin
  select database_role into v_role from v$database;
  select upper(value) into v_rac from v$parameter where name = 'cluster_database';
  if v_role = 'PRIMARY' and v_rac = 'FALSE' then
    dbms_service.start_service('s_portal');
  end if;
end;
/
```

#切换演练时验证:switchover后在xydbadg侧执行 lsnrctl status,确认s_portal等服务已注册

##演练前检查清单(应用接入部分)

```text
1)抽一台应用服务器,用双地址串分别在"主库开/备库开"两种状态实测连通性
2)核对全部连接池配置(JDBC URL/tnsnames/配置中心)已替换为双地址串,不残留单IP直连
3)连接池建议:开启连接有效性检测(testOnBorrow或validationQuery),
  切换瞬间的失效连接由连接池自动重建,避免应用重启
4)无法改造为双地址串的老应用:登记清单,切换演练时人工改配置并重启,计入RTO
```


#### 12.8.1a.FAN/ONS/TAC说明(P2)

#本节用于解释应用侧高可用增强能力,不要求所有老应用一次性启用。实际启用前必须确认JDBC/UCP/连接池版本支持,并在切换演练中验证。

| 能力 | 作用 | 适用前提 | 风险/注意 |
| ---- | ---- | -------- | --------- |
| FAN(Fast Application Notification) | RAC节点/服务状态变化时快速通知客户端,减少TCP超时等待 | 客户端驱动/连接池支持ONS/FAN,服务启用notification | 未配置ONS时仅靠连接串重试,切换感知较慢 |
| ONS | FAN事件传输通道 | RAC/客户端网络可达ONS端口,客户端配置ons nodes | 防火墙/VNCR/安全策略要放行对应端口 |
| AC(Application Continuity) | 故障后自动重放可重放请求 | 应用与驱动兼容,服务属性配置正确 | 有副作用事务、外部调用、非幂等逻辑需谨慎 |
| TAC(Transparent Application Continuity) | 19c增强版透明连续性 | 新版本JDBC/UCP或支持TAC的客户端 | 必须做应用认证,不能只靠DBA单侧开启 |

##### 12.8.1a.1.服务属性样例

```bash
#查看当前ONS与服务配置
srvctl config ons
srvctl config service -d xydb -s s_portal

#FAN基础能力:对支持FAN的客户端启用notification
srvctl modify service -d xydb -s s_portal -notification TRUE
srvctl modify service -d xydb -s s_stuwork -notification TRUE
srvctl modify service -d xydb -s s_onecode -notification TRUE
srvctl modify service -d xydb -s s_dataassets -notification TRUE

#Application Continuity样例(启用前必须先做应用认证;不同RU srvctl参数可能略有差异,以srvctl modify service -help为准)
#srvctl modify service -d xydb -s s_portal \
#  -failovertype TRANSACTION -failovermethod BASIC -failoverretry 30 -failoverdelay 5 \
#  -commit_outcome TRUE -retention 86400 -replay_init_time 900 -session_state DYNAMIC

#TAC样例(19c支持时使用AUTO;启用前必须由应用侧压测确认)
#srvctl modify service -d xydb -s s_portal \
#  -failovertype AUTO -commit_outcome TRUE -retention 86400 -replay_init_time 900 -session_state DYNAMIC

srvctl config service -d xydb -s s_portal
```

##### 12.8.1a.2.应用侧配置要点

```text
1)JDBC Thin/UCP场景:确认驱动版本支持FAN/ONS/AC/TAC;老Druid/Hikari连接池通常只能依赖连接检测与重试。
2)ONS nodes应包含RAC节点ONS端口;网络和防火墙必须放行。
3)启用AC/TAC前,应用必须确认事务中无不可重放副作用,例如外部HTTP调用、序列依赖、临时表状态强依赖等。
4)演练时记录:故障时间、FAN接收时间、连接池恢复时间、业务错误数、是否出现重复提交。
5)未通过认证的应用只启用双地址连接串+validationQuery+重试,不要贸然开启AC/TAC。
```

#### 12.8.2.Switchover(计划内主备互换,零数据丢失)

```bash
#前置检查清单(全部通过才执行):
#1) show configuration 无WARNING/ERROR
#2) validate database xydbadg ---> "Ready for Switchover: Yes"
#3) 主备无gap: select * from v$archive_gap;
#4) 应用侧确认:连接串具备主备双地址或切换后修改;通知相关系统负责人
#5) 做一次OCR手工备份(6.5.2.2)与当日RMAN备份确认

dgmgrl sys/<SYS_PWD>@xydb
DGMGRL> switchover to xydbadg;

#切换后:
#- xydbadg成为主库(单实例,注意容量仅承载核心业务)
#- 原RAC库自动重启为物理备库并启动应用
DGMGRL> show configuration;

#回切
dgmgrl sys/<SYS_PWD>@xydbadg
DGMGRL> switchover to xydb;
```

#### 12.8.3.Failover(主库整体故障,应急切换)

```bash
#仅当RAC主库确认无法在可接受时间内恢复时执行;ASYNC模式可能丢失最后未传输的事务

dgmgrl sys/<SYS_PWD>@xydbadg
DGMGRL> failover to xydbadg;

#已完成双地址连接串改造的应用:无需改IP,连接池自动重连到新主库上的服务(见12.8.1)
#未完成改造的老应用:人工改连接指向172.18.13.180并重启,耗时计入RTO

#原主库修复后重新纳管(reinstate,要求12.2.1已开flashback):
dgmgrl sys/<SYS_PWD>@xydbadg
DGMGRL> reinstate database xydb;
#若flashback未开启或FRA闪回日志不足,reinstate失败,只能按12.4节对原主库重新duplicate重建
```

### 12.9.日常巡检

```bash
#每日(可纳入巡检脚本,异常告警)
dgmgrl sys/<SYS_PWD>@xydb "show configuration" | grep -E "SUCCESS|WARNING|ERROR"
```

```sql
--延迟监控(备库),apply lag阈值建议>5分钟告警
select name, value from v$dataguard_stats where name in ('transport lag','apply lag');

--备库FRA使用率,>80%告警
select round(space_used/space_limit*100,1) pct_used from v$recovery_file_dest;

--主库dest_2传输状态
select dest_id, status, error from v$archive_dest_status where dest_id=2;
```

#alert log位置:
#备库: /u01/app/oracle/diag/rdbms/xydbadg/xydbadg/trace/alert_xydbadg.log
#broker日志: 同目录下 drcxydbadg.log(主库各节点为drcxydb1/2/3.log)

#每季度:执行一次12.8.2 switchover演练并回切,验证容灾真实可用


## 13.预检与验收脚本(precheck/postcheck)

#目的:把散落在各章节的检查命令固化为两份assert脚本,部署/变更前后各跑一次,
#输出逐项PASS/FAIL与汇总,存在FAIL即终止流程
#脚本只做只读检查,不修改任何配置;网卡名/节点清单等变量在脚本头部按实际环境修改

### 13.1.precheck_assert.sh(部署前预检,所有RAC节点逐台以root执行)

#执行时机:完成第1~2章全部准备后、开始第3章GI安装前;加节点前对新节点同样执行

```bash
cat > /root/precheck_assert.sh <<'EOF'
#!/bin/bash
#=====================================================================
# precheck_assert.sh -- Oracle 19c RAC 部署前预检(root执行)
#=====================================================================
PRIVATE_IF=eth1                                   #私网网卡,按实际修改
ISCSI_IF=""                                       #独立iSCSI网卡,没有则留空
MTU_EXPECT=1500                                   #P2:默认1500;端到端确认Jumbo后改为9000
PRIVATE_MTU_EXPECT=$MTU_EXPECT
ISCSI_MTU_EXPECT=$MTU_EXPECT
PRIVATE_MTU_TEST_IP=10.100.100.173                #P2:对端私网IP,按当前节点替换
ISCSI_MTU_TEST_IP=3.3.3.179                       #P2:store/iSCSI对端IP,按实际替换
NODES="k8s-19rac01 k8s-19rac02 k8s-19rac03"       #集群节点清单
ASMDISKS="OCR01 OCR02 OCR03 DATA01 FRA01"         #udev映射盘名(/dev/oracleasm/disks/下)

PASS=0; FAIL=0
ok(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
ng(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
chk(){ local d="$1"; local c="$2"; if eval "$c" >/dev/null 2>&1; then ok "$d"; else ng "$d"; fi; }

echo "===== OS基础 ====="
chk "SELinux=disabled"        "getenforce | grep -qi disabled"
chk "firewalld已停用"          "! systemctl is-active firewalld"
chk "THP=never"               "grep -q '\\[never\\]' /sys/kernel/mm/transparent_hugepage/enabled"
chk "内核参数numa=off"         "grep -q numa=off /proc/cmdline"
chk "avahi未运行"              "! systemctl is-active avahi-daemon"

echo "===== 时间同步 ====="
chk "chronyd运行中"            "systemctl is-active chronyd"
chk "chrony已同步"             "chronyc tracking | grep -q 'Leap status.*Normal'"

echo "===== 内核参数 ====="
chk "rp_filter:私网($PRIVATE_IF)=2"  "[ \$(cat /proc/sys/net/ipv4/conf/$PRIVATE_IF/rp_filter) -eq 2 ]"
[ -n "$ISCSI_IF" ] && chk "rp_filter:iscsi($ISCSI_IF)=2" "[ \$(cat /proc/sys/net/ipv4/conf/$ISCSI_IF/rp_filter) -eq 2 ]"
chk "fs.aio-max-nr>=1048576"   "[ \$(sysctl -n fs.aio-max-nr) -ge 1048576 ]"
chk "fs.file-max>=6815744"     "[ \$(sysctl -n fs.file-max) -ge 6815744 ]"

echo "===== 用户/目录/limits ====="
chk "grid用户存在"             "id grid"
chk "oracle用户存在"           "id oracle"
chk "grid nofile>=65536"       "[ \$(su - grid -c 'ulimit -n') -ge 65536 ]"
chk "oracle nofile>=65536"     "[ \$(su - oracle -c 'ulimit -n') -ge 65536 ]"
chk "HugePages已配置"          "[ \$(awk '/HugePages_Total/{print \$2}' /proc/meminfo) -gt 0 ]"
chk "oracle memlock覆盖HugePages" "[ \$(su - oracle -c 'ulimit -l') -ge \$(( \$(awk '/HugePages_Total/{print \$2}' /proc/meminfo) * \$(awk '/Hugepagesize/{print \$2}' /proc/meminfo) )) ]"
chk "GRID基目录属主grid"        "[ \$(stat -c %U /u01/app/19.0.0) = grid ]"
chk "ORACLE_BASE属主oracle"    "[ \$(stat -c %U /u01/app/oracle) = oracle ]"

echo "===== 网络与互信 ====="
chk "hosts含scan条目"          "grep -q rac-scan /etc/hosts"
chk "私网网卡存在"              "ip link show $PRIVATE_IF"
PRIVATE_MTU_PAYLOAD=$((PRIVATE_MTU_EXPECT-28))
chk "MTU:私网($PRIVATE_IF)=$PRIVATE_MTU_EXPECT" "ip link show $PRIVATE_IF | grep -q 'mtu $PRIVATE_MTU_EXPECT'"
chk "MTU:私网${PRIVATE_MTU_PAYLOAD}不分片"       "ping -M do -s $PRIVATE_MTU_PAYLOAD -c 2 -W 2 $PRIVATE_MTU_TEST_IP"
if [ -n "$ISCSI_IF" ]; then
  ISCSI_MTU_PAYLOAD=$((ISCSI_MTU_EXPECT-28))
  chk "MTU:iSCSI($ISCSI_IF)=$ISCSI_MTU_EXPECT" "ip link show $ISCSI_IF | grep -q 'mtu $ISCSI_MTU_EXPECT'"
  chk "MTU:iSCSI${ISCSI_MTU_PAYLOAD}不分片"       "ping -M do -s $ISCSI_MTU_PAYLOAD -c 2 -W 2 $ISCSI_MTU_TEST_IP"
fi
for h in $NODES; do
  chk "ping $h"                "ping -c1 -W2 $h"
  chk "grid互信->$h"           "su - grid   -c 'ssh -o BatchMode=yes -o ConnectTimeout=5 $h date'"
  chk "oracle互信->$h"         "su - oracle -c 'ssh -o BatchMode=yes -o ConnectTimeout=5 $h date'"
done

echo "===== iSCSI与ASM磁盘 ====="
chk "存在iscsi session"        "iscsiadm -m session"
chk "每target仅1个session"     "[ \$(iscsiadm -m session 2>/dev/null | awk '{print \$4}' | sort | uniq -d | wc -l) -eq 0 ]"
for d in $ASMDISKS; do
  chk "udev设备/dev/oracleasm/disks/$d存在" "[ -e /dev/oracleasm/disks/$d ]"
done
chk "asm盘属主grid:asmadmin"   "[ \"\$(stat -L -c %U:%G /dev/oracleasm/disks/OCR01)\" = grid:asmadmin ]"

echo
echo "================ 汇总: PASS=$PASS FAIL=$FAIL ================"
if [ $FAIL -ne 0 ]; then
  echo "存在FAIL项,禁止进入GI安装;修复后重跑本脚本"
  echo "随后仍需执行官方预检: runcluvfy.sh stage -pre crsinst -n <节点列表> -fixup -verbose"
  exit 1
fi
exit 0
EOF
chmod 750 /root/precheck_assert.sh
bash -n /root/precheck_assert.sh && echo 'OK: /root/precheck_assert.sh语法检查通过' || { echo 'FAIL: /root/precheck_assert.sh语法检查失败'; exit 1; }
```

### 13.2.postcheck.sh(部署后/重大变更后验收,节点一root执行)

#执行时机:建库完成、打RU补丁、加删节点、参数变更、故障恢复之后

```bash
cat > /root/postcheck.sh <<'EOF'
#!/bin/bash
#=====================================================================
# postcheck.sh -- Oracle 19c RAC 部署/变更后验收(节点一root执行)
#=====================================================================
GRID=/u01/app/19.0.0/grid
DB=xydb
VOTE_EXPECT=3            #期望voting file份数(NORMAL冗余=3)
ADG_ENABLED=no           #ADG部署完成后改为yes

PASS=0; FAIL=0
ok(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
ng(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
chk(){ local d="$1"; local c="$2"; if eval "$c" >/dev/null 2>&1; then ok "$d"; else ng "$d"; fi; }

echo "===== 集群层 ====="
chk "crsctl check cluster -all全部online" "! $GRID/bin/crsctl check cluster -all | grep -vi online | grep -q CRS-"
chk "无OFFLINE资源"            "! $GRID/bin/crsctl stat res -t | grep -wq OFFLINE"
chk "所有节点Active"           "! $GRID/bin/olsnodes -s | grep -vq Active"
chk "CTSS=Observer"           "$GRID/bin/crsctl check ctss | grep -qi observer"
chk "votedisk=${VOTE_EXPECT}且ONLINE" "[ \$($GRID/bin/crsctl query css votedisk | grep -c ONLINE) -eq $VOTE_EXPECT ]"
chk "OCR一致性检查通过"         "$GRID/bin/ocrcheck | grep -q succeeded"
chk "OLR一致性检查通过"         "$GRID/bin/ocrcheck -local | grep -q succeeded"
chk "磁盘组无DISMOUNT"         "! su - grid -c 'asmcmd lsdg' | grep -qi dismount"

echo "===== 数据库层 ====="
chk "全部实例running"          "! su - oracle -c 'srvctl status database -d $DB' | grep -v 'is running' | grep -q ."
chk "service无not running"    "! su - oracle -c 'srvctl status service -d $DB' | grep -q 'is not running'"
chk "use_large_pages=ONLY"     "su - oracle -c \"echo 'show parameter use_large_pages;' | sqlplus -s / as sysdba\" | grep -qiw only"
chk "HugePages_Surp=0"       "[ \$(awk '/HugePages_Surp/{print \$2}' /proc/meminfo) -eq 0 ]"
chk "kernel.sem生效值"       "[ \"\$(sysctl -n kernel.sem | tr -s ' ')\" = '250 32000 100 128' ]"
#老环境若经评估保留非默认kernel.sem,需同步调整上方期望值,并在14.5记录理由和回退方案。

REDO_BAD=$(su - oracle -c "sqlplus -s / as sysdba" <<'SQL'
set heading off feedback off pagesize 0
select (select count(*) from (select thread# from v$log group by thread# having count(*)<3))
     + (select count(distinct bytes)-1 from v$log) from dual;
SQL
)
chk "redo每thread>=3组且全库同尺寸" "[ \${REDO_BAD:-9} -eq 0 ]"

echo "===== 备份 ====="
chk "RMAN当日备份OK"           "grep -q \"^OK \$(date +%F)\" /backup/rmanbak/last_backup_status"
chk "RMAN保留策略=恢复窗口"     "su - oracle -c 'echo show retention policy\\; | rman target /' | grep -qi 'RECOVERY WINDOW'"

if [ "$ADG_ENABLED" = "yes" ]; then
echo "===== ADG ====="
chk "broker配置SUCCESS"        "su - oracle -c \"echo show configuration\\; | dgmgrl /\" | grep -q SUCCESS"
chk "ADG无传输错误(VNCR白名单)" "su - oracle -c \"sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pages 0
select count(*) from v\\$archive_dest_status where status <> 'INACTIVE' and error is not null;
SQL\" | grep -qx '0'"
fi

echo
echo "================ 汇总: PASS=$PASS FAIL=$FAIL ================"
[ $FAIL -eq 0 ] || { echo "存在FAIL项,验收不通过;逐项排查后重跑"; exit 1; }
exit 0
EOF
chmod 750 /root/postcheck.sh
bash -n /root/postcheck.sh && echo 'OK: /root/postcheck.sh语法检查通过' || { echo 'FAIL: /root/postcheck.sh语法检查失败'; exit 1; }
```

#验收口径:两份脚本输出FAIL=0才允许进入下一阶段/宣布变更完成;
#脚本结果(全文输出)随变更记录归档,与10.7/12.6等专项校验互为补充,不互相替代



### 13.3.P0脚本实跑门禁与修正记录

#目的:precheck/postcheck/rmanbak.sh/ADG巡检脚本进入生产流程或cron前,必须先在实验集群实跑。
#原因:脚本文档审稿只能发现部分问题;真正可靠的门禁是root/oracle/grid三个用户身份下的实跑输出。

#### 13.3.0.脚本落盘与语法预检

#13.1/13.2代码块已经包含`cat > /root/precheck_assert.sh`、`cat > /root/postcheck.sh`、`chmod 750`和`bash -n`显式OK/FAIL判定。
#执行13.3.1前必须先按13.1/13.2完成落盘;若从PDF/Word复制脚本,必须确认here-doc边界`EOF`未丢失、脚本中无中文引号。

#### 13.3.1.实跑顺序

```bash
#1)每个RAC节点root执行precheck
bash /root/precheck_assert.sh | tee /root/precheck_assert.$(hostname).$(date +%F).log

#2)节点一root执行postcheck
bash /root/postcheck.sh | tee /root/postcheck.$(hostname).$(date +%F).log

#3)oracle用户空跑RMAN脚本中的环境检查段;正式备份前先手工执行一次并观察日志
su - oracle -c 'bash /home/oracle/rmanbak/rmanbak.sh L1'

#4)ADG部署完成后再打开postcheck中的ADG_ENABLED=yes,验证dgmgrl OS认证
su - oracle -c "echo 'show configuration;' | dgmgrl /"
```

#### 13.3.2.已知高危检查点

| 检查点 | 风险 | 验证方式 |
| ------ | ---- | -------- |
| `chk()`中的`eval` | 引号嵌套、`$()`、中文描述导致判断误报 | 单独复制每条chk命令执行,确认PASS/FAIL符合真实状态 |
| heredoc | `<<'SQL'`内不应写成`v\$log`;单引号heredoc不会展开变量 | 直接运行SQL,确认SQL*Plus无ORA/SP2错误 |
| crontab `%` | cron中`date +%F/%Y%m%d`必须写成`\%F/\%Y\%m\%d` | `crontab -l`复核并观察实际生成文件名 |
| `srvctl status`解析 | 不同RU/语言环境输出可能不同 | 用当前环境真实输出调整grep模式 |
| `dgmgrl /` | oracle用户OS认证可能因环境变量/权限失败 | oracle用户直接执行并确认能show configuration |
| NFS挂载 | 备份目录不可写会导致备份静默失败 | `touch /backup/rmanbak/.rwtest`和RMAN日志双验证 |

#### 13.3.3.修正记录模板(写入附录14.3或变更单)

```text
日期:
执行人:
环境/节点:
脚本版本:
执行命令:
失败项/现象:
根因:
修正内容:
复验结果:
是否允许进入cron/生产流程: 是/否
```

#验收口径:所有P0脚本首次实跑必须有日志与修正记录;没有实跑记录,不得把脚本加入cron或作为生产变更门禁。


#### 13.3.4.首次上线前脚本实跑检查单

#本检查单用于把P0→P3阶段形成的脚本从"文档静态正确"推进到"现场确认能跑"。
#首次进入cron、监控或正式变更门禁前,必须逐项手工实跑,保存完整输出,并把结论写入14.3/14.6。
#若脚本输出FAIL、WARN未解释清楚、状态文件未生成或时间戳不更新,不得上线。

| 序号 | 脚本/动作 | 执行身份与建议命令 | 预期输出/产物 | 易错点 | 判定标准 |
| ---- | --------- | ------------------ | ------------- | ------ | -------- |
| 1 | `precheck_assert.sh` | root在每个RAC节点执行:`bash /root/precheck_assert.sh \| tee /root/precheck_assert.$(hostname).$(date +%F).log` | 汇总`FAIL=0`;节点网络、limits、HugePages、iSCSI、ASM设备等前置条件通过 | 网卡名/MTU变量未按现场替换;`rp_filter`因旧sysctl源覆盖;`/dev/oracleasm/disks/*`缺失 | 所有RAC节点均`FAIL=0`;WARN有变更记录解释 |
| 2 | `postcheck.sh` | root在节点1执行:`bash /root/postcheck.sh \| tee /root/postcheck.$(hostname).$(date +%F).log` | CRS、ASM、DB、service、FRA、ADG可选项均按现场状态通过 | `srvctl/crsctl`路径或执行用户不一致;ADG尚未启用却打开`ADG_ENABLED=yes`;SQL heredoc转义错误 | `FAIL=0`;ADG未上线时明确关闭检查,上线后重新实跑 |
| 3 | `rmanbak.sh` | oracle执行:`bash /home/oracle/rmanbak/rmanbak.sh L1` | `/backup/rmanbak/last_backup_status`首行以`OK`开头且时间戳为本次运行;日志有RMAN完成信息 | NFS不可写;DBID/控制文件自动备份未归档;cron中的`%`未转义;RMAN通道路径权限不足 | 手工L1成功,状态文件更新时间正确,日志无RMAN-或ORA-错误 |
| 4 | `expdp_pdb_backup.sh` | oracle执行:`/home/oracle/expdp_pdb_backup.sh` | `/backup/expdp/last_expdp_status`和每个PDB目录下`last_expdp_status`均为`OK`;dump/log生成并完成异地同步 | PDB目录对象路径未按PDB隔离;远端SSH/目录权限失败;脚本log不存在时未正确报错 | 全局与各PDB状态均OK;失败信息能直指本地目录或远端同步问题 |
| 5 | `rac_daily_check.sh` | root执行:`bash /root/rac_daily_check.sh` | `/var/lib/oracle_mon/rac_daily_check_status`为`OK`;输出日志覆盖CRS/ASM/DB/FRA/备份状态 | 状态目录不存在;grep模式不适配当前RU输出;备份状态文件过期但仍误判OK | 状态文件首行为OK,并能故意制造一个失败项验证告警可触发 |
| 6 | `oracle_rac_textfile_exporter.sh` | root执行:`bash /root/oracle_rac_textfile_exporter.sh && cat <MONITOR_TEXTFILE_DIR>/oracle_rac.prom` | Prom文件原子生成;含`oracle_rac_daily_check_ok`、`oracle_rman_backup_last_ok_timestamp`、`oracle_expdp_backup_last_ok_timestamp`等指标 | `<MONITOR_TEXTFILE_DIR>`未替换;prom临时文件残留;时间戳解析失败返回0;node_exporter未加载textfile目录 | Prometheus/Zabbix能采到指标;`time()-last_ok>93600`类规则可正常计算;textfile目录内只有`*.prom` |
| 7 | LIO/targetcli验收(如本轮实跑LIO) | store root执行:`targetcli ls`;RAC root执行:`iscsiadm -m session -P 3`和`scsi_id`对照 | LUN数量、LUN顺序、scsi_id/ID_SERIAL在三节点一致;`/etc/target/saveconfig.json`已备份 | 在线切换tgtd/LIO;initiator IQN混用;scsi_id变化后未更新udev;CRS未停就变更target | 停机迁移流程闭环;CRS启动前先完成三节点LUN和ASM设备一致性验证 |

#归档要求:
#1)每项实跑日志以`脚本名.节点.日期.log`命名,和变更单、本文档版本号一起归档;
#2)实跑中发现的问题必须写入13.3.3模板,并同步到14.3/14.6;
#3)所有计划任务首次进入cron后,第二天必须复核状态文件时间戳确实刷新,防止"手工能跑、cron静默停跑"。


### 13.4.P1日常巡检脚本与清单

#目标:把故障发现前移。巡检分每日、每周、每月/季度三类,先用脚本落地,后续P2再接Zabbix/Prometheus。

#### 13.4.1.每日巡检

```bash
cat > /root/rac_daily_check.sh <<'EOF'
#!/bin/bash
set -u
export GRID_HOME=/u01/app/19.0.0/grid
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export PATH=$GRID_HOME/bin:$ORACLE_HOME/bin:$PATH
OUT=/tmp/rac_daily_check_$(hostname)_$(date +%Y%m%d_%H%M%S).log
STATUS_DIR=/var/lib/oracle_mon
STATUS=$STATUS_DIR/rac_daily_check_status
mkdir -p "$STATUS_DIR"
fail=0

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$OUT"; }
chk(){ desc="$1"; shift; log "CHECK: $desc"; if eval "$@" >>"$OUT" 2>&1; then log "PASS: $desc"; else log "FAIL: $desc"; fail=1; fi; }

chk "CRS resources online/stable" "crsctl stat res -t | tee /tmp/crs.stat | grep -q ONLINE && ! egrep -q 'OFFLINE|INTERMEDIATE|UNKNOWN|FAILED' /tmp/crs.stat"
chk "OCR check" "ocrcheck | grep -q 'succeeded'"
chk "Voting disk visible" "crsctl query css votedisk | grep -q 'Located'"
chk "ASM diskgroup mounted" "su - grid -c 'asmcmd lsdg' | egrep -q 'OCR|DATA|FRA'"
chk "Database running" "srvctl status database -d xydb | grep -q 'is running'"
chk "Services status" "! srvctl status service -d xydb | grep -q 'is not running'"
chk "FRA not above 85 percent" "su - oracle -c \"sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pages 0
select case when max(space_used/space_limit) < .85 then 'OK' else 'FAIL' end from v\$recovery_file_dest;
SQL\" | grep -q OK"
chk "Tablespace usage not above 90 percent" "su - oracle -c \"sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pages 0
select case when count(*)=0 then 'OK' else 'FAIL' end
from (
select tablespace_name,used_percent from dba_tablespace_usage_metrics where used_percent>=90
);
SQL\" | grep -q OK"
chk "RMAN latest status file OK" "test -f /backup/rmanbak/last_backup_status && grep -q '^OK' /backup/rmanbak/last_backup_status"
chk "Expdp summary status OK if enabled" "test ! -f /backup/expdp/last_expdp_status || grep -q '^OK' /backup/expdp/last_expdp_status"
chk "Expdp PDB status OK if enabled" "for p in stuwork portal onecode dataassets; do [ ! -f /backup/expdp/\$p/last_expdp_status ] || grep -q '^OK' /backup/expdp/\$p/last_expdp_status || exit 1; done"
chk "THP disabled" "grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled"
chk "No AnonHugePages" "awk '/AnonHugePages/{exit !($2==0)}' /proc/meminfo"
chk "chrony running" "systemctl is-active chronyd"
chk "iSCSI session present" "iscsiadm -m session >/dev/null 2>&1"

if [ $fail -eq 0 ]; then
  echo "OK $(date '+%F %T') $OUT" | tee "$STATUS"
else
  echo "FAIL $(date '+%F %T') $OUT" | tee "$STATUS"
fi
exit $fail
EOF
chmod 750 /root/rac_daily_check.sh
bash -n /root/rac_daily_check.sh && echo 'OK: /root/rac_daily_check.sh语法检查通过' || { echo 'FAIL: /root/rac_daily_check.sh语法检查失败'; exit 1; }
```

#每日巡检验收:
#1)`/var/lib/oracle_mon/rac_daily_check_status`为OK;
#2)异常输出必须进入故障/变更记录;
#3)P2阶段将状态文件接入监控平台。

#### 13.4.2.每周巡检

```bash
#建议每周人工或cron执行,结果归档
crsctl stat res -t
cluvfy comp healthcheck -collect cluster -bestpractice -html
su - grid -c 'asmcmd lsdg; asmcmd lsdsk -k -p'
su - oracle -c "sqlplus -s / as sysdba <<'SQL'
set lines 200 pages 200
select * from v\$recovery_file_dest;
select tablespace_name,round(used_percent,2) used_pct from dba_tablespace_usage_metrics order by used_percent desc fetch first 20 rows only;
select inst_id,event,total_waits,time_waited from gv\$system_event where wait_class <> 'Idle' order by time_waited desc fetch first 20 rows only;
SQL"
```

#### 13.4.3.每月/季度巡检

#每月:
#- `restore database validate`;
#- 检查AWR保留策略和top wait趋势;
#- 检查补丁版本与下一季度RU计划;
#- 检查安全例外是否到期。

#每季度:
#- 至少一次异机恢复演练;
#- 至少一次ADG switchover演练;
#- 至少一次expdp抽样impdp验证;
#- 更新容量规划:DATA/FRA/归档/redo/UNDO/PGA/HugePages。

### 13.5.P2监控平台化接入(Zabbix/Prometheus)

#目标:把第13章脚本输出从“人工看日志”升级为“平台告警”。本节不替代13.3实跑门禁;脚本未实跑通过前不得接入正式监控。

#### 13.5.1.统一状态文件口径

#目录边界:
#1)`<MONITOR_STATUS_DIR>`(`/var/lib/oracle_mon`)只存放脚本状态文件和普通文本,不由node_exporter直接扫描;
#2)`<MONITOR_TEXTFILE_DIR>`(`/var/lib/node_exporter/textfile_collector`)只允许放`*.prom`指标文件;
#3)严禁把`last_backup_status`、`rac_daily_check_status`等普通状态文件放入textfile collector目录,否则node_exporter会按Prometheus格式解析并产生采集错误。

| 状态文件 | 产生脚本 | OK判定 | 建议告警 |
| -------- | -------- | ------ | -------- |
| `/var/lib/oracle_mon/rac_daily_check_status` | 13.4每日巡检 | 以`OK`开头 | FAIL立即告警;文件缺失也告警 |
| `/backup/rmanbak/last_backup_status` | rmanbak.sh | 以`OK`开头且时间戳为最近一次计划周期 | `time()-last_ok>93600`或FAIL告警 |
| `/backup/expdp/last_expdp_status` | expdp_pdb_backup.sh | 以`OK`开头且时间戳为最近一次计划周期 | `time()-last_ok>93600`或FAIL/缺失告警 |
| `/backup/expdp/<PDB>/last_expdp_status` | expdp_pdb_backup.sh | 每个PDB均OK | 单PDB失败告警 |
| ADG lag | SQL采集 | transport/apply lag低于阈值 | 超过阈值或transport error告警 |
| FRA使用率 | SQL采集 | <80% | >=80% warning, >=85% high |

#### 13.5.2.node_exporter textfile collector样例

```bash
#node_exporter启动参数需包含: --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
#目录边界: /var/lib/oracle_mon存普通状态文件; /var/lib/node_exporter/textfile_collector只放*.prom
MONITOR_TEXTFILE_DIR=/var/lib/node_exporter/textfile_collector
MONITOR_STATUS_DIR=/var/lib/oracle_mon
mkdir -p "$MONITOR_TEXTFILE_DIR" "$MONITOR_STATUS_DIR"
chown root:root "$MONITOR_TEXTFILE_DIR" "$MONITOR_STATUS_DIR"
chmod 755 "$MONITOR_TEXTFILE_DIR"
chmod 750 "$MONITOR_STATUS_DIR"

cat > /root/oracle_rac_textfile_exporter.sh <<'EOF'
#!/bin/bash
set -u
TEXTFILE_DIR=/var/lib/node_exporter/textfile_collector   #与变量表<MONITOR_TEXTFILE_DIR>一致
STATUS_DIR=/var/lib/oracle_mon                           #与变量表<MONITOR_STATUS_DIR>一致
OUT=$TEXTFILE_DIR/oracle_rac.prom.$$
FINAL=$TEXTFILE_DIR/oracle_rac.prom
DB=xydb

ok_file(){ [ -f "$1" ] && grep -q '^OK' "$1"; }
metric_bool(){ local name="$1"; local val="$2"; echo "$name $val" >> "$OUT"; }
last_ok_ts(){
  local f="$1"
  if ok_file "$f"; then
    awk 'NR==1{print $2" "$3}' "$f" 2>/dev/null | xargs -r -I{} date -d "{}" +%s 2>/dev/null || echo 0
  else
    echo 0
  fi
}

mkdir -p "$TEXTFILE_DIR"
#防止普通状态文件误入textfile collector;发现非*.prom文件时直接失败,避免node_exporter解析报错被忽略
if find "$TEXTFILE_DIR" -maxdepth 1 -type f ! -name '*.prom' | grep -q .; then
  echo "ERROR: non-prom files found in $TEXTFILE_DIR" >&2
  exit 1
fi

: > "$OUT"

ok_file "$STATUS_DIR/rac_daily_check_status" && metric_bool oracle_rac_daily_check_ok 1 || metric_bool oracle_rac_daily_check_ok 0
ok_file /backup/rmanbak/last_backup_status && metric_bool oracle_rman_backup_ok 1 || metric_bool oracle_rman_backup_ok 0
ok_file /backup/expdp/last_expdp_status && metric_bool oracle_expdp_backup_ok 1 || metric_bool oracle_expdp_backup_ok 0

echo "oracle_rman_backup_last_ok_timestamp $(last_ok_ts /backup/rmanbak/last_backup_status)" >> "$OUT"
echo "oracle_expdp_backup_last_ok_timestamp $(last_ok_ts /backup/expdp/last_expdp_status)" >> "$OUT"

for p in stuwork portal onecode dataassets; do
  if ok_file /backup/expdp/$p/last_expdp_status; then
    echo "oracle_expdp_pdb_backup_ok{pdb=\"$p\"} 1" >> "$OUT"
  else
    echo "oracle_expdp_pdb_backup_ok{pdb=\"$p\"} 0" >> "$OUT"
  fi
  echo "oracle_expdp_pdb_backup_last_ok_timestamp{pdb=\"$p\"} $(last_ok_ts /backup/expdp/$p/last_expdp_status)" >> "$OUT"
done

#FRA使用率,SQL失败时输出-1便于告警
FRA=$(su - oracle -c "sqlplus -s / as sysdba" <<'SQL'
set heading off feedback off pages 0
select round(max(space_used/space_limit),4) from v$recovery_file_dest;
SQL
)
FRA=$(echo "$FRA" | tr -d '[:space:]')
case "$FRA" in ''|*[!0-9.]* ) FRA=-1 ;; esac
echo "oracle_fra_used_ratio $FRA" >> "$OUT"

#ADG transport/apply lag可在ADG部署后打开,单位秒;未启用时输出-1
#建议用dgmgrl或v$dataguard_stats单独脚本采集并写入同一prom文件

echo "oracle_rac_textfile_exporter_last_run $(date +%s)" >> "$OUT"
mv "$OUT" "$FINAL"
EOF
chmod 750 /root/oracle_rac_textfile_exporter.sh
bash -n /root/oracle_rac_textfile_exporter.sh && echo 'OK: /root/oracle_rac_textfile_exporter.sh语法检查通过' || { echo 'FAIL: /root/oracle_rac_textfile_exporter.sh语法检查失败'; exit 1; }

#cron示例,每5分钟采集一次
(crontab -l 2>/dev/null; echo '*/5 * * * * /root/oracle_rac_textfile_exporter.sh >/tmp/oracle_rac_textfile_exporter.log 2>&1') | crontab -
```

#Prometheus告警建议:
#- `oracle_rac_daily_check_ok == 0` 立即告警;
#- `oracle_rman_backup_ok == 0` 立即告警;
#- `time() - oracle_rman_backup_last_ok_timestamp > 93600` 备份静默停跑告警(按每日备份+2小时余量调整);
#- `oracle_expdp_backup_ok == 0` 告警;
#- `time() - oracle_expdp_backup_last_ok_timestamp > 93600` expdp静默停跑告警;
#- `oracle_fra_used_ratio >= 0.80` warning, `>=0.85` high;
#- `oracle_adg_transport_lag_seconds > 300`或`oracle_adg_apply_lag_seconds > 300`告警,未启用时为-1;
#- `time() - oracle_rac_textfile_exporter_last_run > 600` 采集器失联告警。

#### 13.5.3.Zabbix UserParameter样例

#以下UserParameter中的`/var/lib/oracle_mon`对应变量`<MONITOR_STATUS_DIR>`。
#若现场调整状态目录,必须同步修改Zabbix配置、13.4巡检脚本和13.5 exporter脚本,保持三处一致。

```bash
cat > /etc/zabbix/zabbix_agentd.d/oracle_rac.conf <<'EOF'
UserParameter=oracle.rac.daily,grep -q '^OK' /var/lib/oracle_mon/rac_daily_check_status && echo 1 || echo 0
UserParameter=oracle.rman.backup,grep -q '^OK' /backup/rmanbak/last_backup_status && echo 1 || echo 0
UserParameter=oracle.rman.backup.timestamp,awk 'NR==1{print $2" "$3}' /backup/rmanbak/last_backup_status 2>/dev/null | xargs -r -I{} date -d "{}" +%s 2>/dev/null || echo 0
UserParameter=oracle.expdp.backup,grep -q '^OK' /backup/expdp/last_expdp_status && echo 1 || echo 0
UserParameter=oracle.expdp.backup.timestamp,awk 'NR==1{print $2" "$3}' /backup/expdp/last_expdp_status 2>/dev/null | xargs -r -I{} date -d "{}" +%s 2>/dev/null || echo 0
UserParameter=oracle.fra.used_ratio,su - oracle -c "sqlplus -s / as sysdba" <<'SQL' | awk 'NF{print $1}'
set heading off feedback off pages 0
select round(max(space_used/space_limit),4) from v$recovery_file_dest;
SQL
EOF
systemctl restart zabbix-agent
```

#Zabbix触发器建议:
#1)`oracle.rac.daily=0` 高危;
#2)`oracle.rman.backup=0` 高危;
#3)`oracle.expdp.backup=0` 中高危;
#4)`oracle.fra.used_ratio>0.8` warning, `>0.85` high。


## 14.附录:历史记录(仅供追溯,禁止作为执行依据)

#本章内容为部署过程中真实发生的旧日志与历史错误处理记录,统一从主流程移出;
#阅读价值在于理解"为什么现行标准长这样",任何命令禁止照抄执行



### 14.1.CTSS/chrony历史错误处理记录(禁止照做)

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-14-01 14.1 CTSS/chrony历史错误处理记录**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

### 14.2.iSCSI参数调优历史对比记录(含错误配置,禁止照抄)

> v3.0日志归档: 本节长回显已纯搬运至《Oracle19C_RAC_for_OLE7_9_安装手册-v3.0-历史日志归档.md》的 **LOG-14-02 14.2 iSCSI参数调优历史对比记录**。
> 正文仅保留归档索引;执行时以本手册对应主流程命令、验收标准和第13章脚本为准,禁止直接照抄历史回显。

### 14.3.P0脚本实跑修正记录(预留)

#本节用于归档第13.3节要求的实跑记录。首次上线前至少记录precheck、postcheck、rmanbak.sh、expdp_pdb_backup.sh、ADG巡检五类脚本的实跑结果。
#示例模板见13.3.3;若脚本无修正,也要记录"实跑通过,无修正"。
#v2.5.1新增要求:首次实跑必须覆盖HugePages/memlock/use_large_pages断言、RMAN L1脚本路径、service状态巡检、expdp按PDB分文件与192.168.100.100:/data异地同步、dgmgrl OS认证。


### 14.4.P1演练与巡检记录模板(预留)

| 日期 | 类型 | 执行人 | 环境 | 结果 | RTO/RPO | 问题 | 修正动作 | 复验人 |
| ---- | ---- | ------ | ---- | ---- | ------- | ---- | -------- | ------ |
| YYYY-MM-DD | HugePages/limits实跑 |  |  | PASS/FAIL |  |  |  |  |
| YYYY-MM-DD | RMAN restore validate |  |  | PASS/FAIL |  |  |  |  |
| YYYY-MM-DD | 单数据文件恢复演练 |  |  | PASS/FAIL |  |  |  |  |
| YYYY-MM-DD | 异机恢复演练 |  |  | PASS/FAIL |  |  |  |  |
| YYYY-MM-DD | expdp/impdp验证 |  |  | PASS/FAIL |  |  |  |  |
| YYYY-MM-DD | RU补丁演练 |  |  | PASS/FAIL |  |  |  |  |



### 14.5.P2参数与监控变更记录模板(预留)

```text
日期:
执行人:
变更类型: OS参数/DB参数/ASM属性/MTU/VNCR/FAN-ONS-TAC/监控接入
涉及节点/实例/PDB:
变更前值:
变更后值:
回退命令:
验证命令:
验证结果:
是否影响ADG/应用连接:
是否已更新监控阈值: 是/否
```

### 14.6.P3架构演进与容量规划记录模板(预留)

| 日期 | 变更主题 | 涉及章节 | 现状 | 目标方案 | 验证结果 | 回退方案 | 负责人 |
| ---- | -------- | -------- | ---- | -------- | -------- | -------- | ------ |
|  | tgtd->LIO/企业存储 | 1.6.3 |  |  | scsi_id/udev/ASM/postcheck | 恢复tgtd配置与旧udev规则 |  |
|  | SCAN/DNS三IP | 2.4.1 | hosts单SCAN | DNS三A记录 | cluvfy/srvctl/lsnrctl/应用连接 | 恢复hosts降级方案 |  |
|  | 静默安装响应文件 | 3.8 | GUI安装 | response file | root脚本/postcheck | 回退到GUI流程 |  |
|  | 容量规划 | 11.2 |  |  | AWR/OS/备份窗口/FRA阈值 | 回退参数或扩容计划 |  |

