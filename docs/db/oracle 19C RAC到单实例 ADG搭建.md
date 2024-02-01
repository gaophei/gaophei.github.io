## 1.系统环境

### 1.1.主备库信息

|                                                              | 主库                            | 备库                               |
| ------------------------------------------------------------ | ------------------------------- | ---------------------------------- |
| db_name(主备库必须一致)                                      | xydb                            | xydb                               |
| db_unique_name(主备库必须不一致)<br />(此处如果相同，必须修改备库参数) | xydb                            | xydbdg                             |
| service_name                                                 | xydb                            | xydb                               |
| instance_name                                                | xydb1/xydb2                     | xydbdg                             |
| 归档路径                                                     | +FRA                            | /u01/app/oracle/fast_recovery_area |
| 数据文件路径                                                 | +DATA                           | /u01/app/oracle/oradata/           |
| standby归档路径                                              |                                 |                                    |
| 物理IP                                                       | 172.18.13.97<br />172.18.13.98  | 172.18.13.104                      |
| VIP                                                          | 172.18.13.99<br />172.18.13.100 |                                    |
| Scan IP                                                      | 172.18.13.101                   |                                    |
| hostname                                                     | k8s-rac01<br />k8s-rac02        | k8s-oracle-store                   |
| DB version                                                   | 19.21.0.0.0                     | 19.21.0.0.0                        |
| 归档                                                         | 已开启                          | 已开启                             |

#注意事项，部署前必看

```
#默认xydbdg(standby库)不用建库，只安装数据库软件即可
#备库的pfile文件可以由主库产生并修改生成


#但是备库服务器配置一般和主库存在差异(硬件环境、oracle版本等)，建议先在备库根据实际环境创建一个数据库（开启归档和闪回，db_name、字符集要与主库一致），然后保留pfile删库，修改备库的配置文件：initXYDBDG.ora

#create pfile='/home/oracle/initXYDBDG.ora' from spfile;

#创建完该文件后，通过DBCA来删除备库，再来搭建ADG

```



#详细信息

#主库

```bash
SYS@xydb1> show parameter name

NAME				                   TYPE   	   VALUE
------------------------------------ ----------- ------------------------------
cdb_cluster_name		         string
cell_offloadgroup_name		     string
db_file_name_convert		     string
db_name 			             string	     xydb
db_unique_name			         string	     xydb
global_names			         boolean	 FALSE
instance_name			         string	     xydb1
lock_name_space 		         string
log_file_name_convert		     string
pdb_file_name_convert		     string
processor_group_name		     string
service_names			         string	     xydb


SYS@xydb1> archive log list
Database log mode	       Archive Mode
Automatic archival	       Enabled
Archive destination	       USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     258
Next log sequence to archive   259
Current log sequence	       259


SYS@xydb1> show parameter recovery

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
db_recovery_file_dest		     string	 +FRA
db_recovery_file_dest_size	     big integer 204668M
recovery_parallelism		     integer	 0
remote_recovery_file_dest	     string
SYS@xydb1> 


SYS@xydb1> select file_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------------------------------
+DATA/XYDB/DATAFILE/system.257.1153250631
+DATA/XYDB/DATAFILE/sysaux.258.1153250677
+DATA/XYDB/DATAFILE/undotbs1.259.1153250701
+DATA/XYDB/DATAFILE/users.260.1153250703
+DATA/XYDB/DATAFILE/undotbs2.269.1153251451

SYS@xydb1> select file_name from dba_temp_files;

FILE_NAME
--------------------------------------------------------------------------------------------------------
+DATA/XYDB/TEMPFILE/temp.264.1153250809


SYS@xydb1> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO
	 
SYS@xydb1> alter session set container=portal;

Session altered.

SYS@xydb1> select file_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------------------------------
+DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/system.281.1153652419
+DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/sysaux.280.1153652419
+DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/undotbs1.279.1153652419
+DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/undo_2.283.1153652669

SYS@xydb1> exit


[oracle@k8s-rac01 admin]$ cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.18.13.112 k8s-mysql-ole

#public ip 
172.18.13.97 k8s-rac01
172.18.13.98 k8s-rac02
#vip
172.18.13.99  k8s-rac01-vip
172.18.13.100 k8s-rac02-vip
#private ip
10.100.100.97 k8s-rac01-prv
10.100.100.98 k8s-rac02-prv
#scan ip
172.18.13.101 rac-scan

```



#备库

```bash
SYS@xydbdg> show parameter name

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
cdb_cluster_name		         string
cell_offloadgroup_name		     string
db_file_name_convert		     string
db_name 			             string	     xydb
db_unique_name			         string	     xydb
global_names			         boolean	 FALSE
instance_name			         string	     xydbdg
lock_name_space 		         string
log_file_name_convert		     string
pdb_file_name_convert		     string
processor_group_name		     string
service_names			         string	     xydb



SYS@xydbdg> archive log list
Database log mode	       Archive Mode
Automatic archival	       Enabled
Archive destination	       USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     26
Next log sequence to archive   28
Current log sequence	       28


SYS@xydbdg> show parameter recovery

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
db_recovery_file_dest		     string	 /u01/app/oracle/fast_recovery_area
db_recovery_file_dest_size	     big integer 20000M
recovery_parallelism		     integer	 0
remote_recovery_file_dest	     string
SYS@xydbdg> 


SYS@xydbdg> select file_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------------------------------
/u01/app/oracle/oradata/XYDB/system01.dbf
/u01/app/oracle/oradata/XYDB/sysaux01.dbf
/u01/app/oracle/oradata/XYDB/undotbs01.dbf
/u01/app/oracle/oradata/XYDB/users01.dbf


SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 TESTPDB			  READ WRITE NO
	 
SYS@xydbdg> alter session set container=testpdb;

Session altered.

SYS@xydbdg> select file_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------------------------------
/u01/app/oracle/oradata/XYDB/testpdb/system01.dbf
/u01/app/oracle/oradata/XYDB/testpdb/sysaux01.dbf
/u01/app/oracle/oradata/XYDB/testpdb/undotbs01.dbf
/u01/app/oracle/oradata/XYDB/testpdb/users01.dbf

SYS@xydbdg> exit

[root@k8s-oracle-store home]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.18.13.112 k8s-mysql-ole

172.18.13.104 k8s-oracle-store
```



## 2.配置部分

### 2.0.修改主、备库的/etc/hosts

#主库rac1


```bash
[root@k8s-rac01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

#public ip 
172.18.13.97 k8s-rac01
172.18.13.98 k8s-rac02
#vip
172.18.13.99  k8s-rac01-vip
172.18.13.100 k8s-rac02-vip
#private ip
10.100.100.97 k8s-rac01-prv
10.100.100.98 k8s-rac02-prv
#scan ip
172.18.13.101 rac-scan

#dg-database
172.18.13.104 k8s-oracle-store
```



#主库rac2

```bash
[root@k8s-rac02 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

#public ip 
172.18.13.97 k8s-rac01
172.18.13.98 k8s-rac02
#vip
172.18.13.99  k8s-rac01-vip
172.18.13.100 k8s-rac02-vip
#private ip
10.100.100.97 k8s-rac01-prv
10.100.100.98 k8s-rac02-prv
#scan ip
172.18.13.101 rac-scan

#dg-database
172.18.13.104 k8s-oracle-store
```



#备库

```bash
[root@k8s-oracle-store ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

172.18.13.104 k8s-oracle-store


#public ip
172.18.13.97 k8s-rac01
172.18.13.98 k8s-rac02
#vip
172.18.13.99  k8s-rac01-vip
172.18.13.100 k8s-rac02-vip
#private ip
10.100.100.97 k8s-rac01-prv
10.100.100.98 k8s-rac02-prv
#scan ip
172.18.13.101 rac-scan

#dg-database
172.18.13.104 k8s-oracle-store
```



### 2.1.配置备库(单实例)的db_unique_name

#从头搭建ADG时，该步骤忽略

#为了创建ADG，作为备库，db_name必须跟主库一致(xydb)，而db_unique_name不能一致(xydbdg)。但是在默认安装时，db_unique_name=db_name，所以部署完单实例后，要修改系统参数db_unique_name

```sql
show parameter name;

alter system set db_unique_name='xydbdg' scope=spfile;

shutdown immediate;

startup;

show parameter name;
```



#logs

```sql
SYS@xydbdg> show pdbs     

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 TESTPDB			  READ WRITE NO
SYS@xydbdg> show parameter name

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
cdb_cluster_name		     string
cell_offloadgroup_name		     string
db_file_name_convert		     string
db_name 			     string	 xydb
db_unique_name			     string	 xydb
global_names			     boolean	 FALSE
instance_name			     string	 xydbdg
lock_name_space 		     string
log_file_name_convert		     string
pdb_file_name_convert		     string
processor_group_name		     string
service_names			     string	 xydb
SYS@xydbdg> 

SYS@xydbdg> alter system set db_unique_name='xydbdg' scope=spfile;

System altered.

SYS@xydbdg>  shutdown immediate;
Database closed.
Database dismounted.
ORACLE instance shut down.

SYS@xydbdg> startup;
ORACLE instance started.

Total System Global Area 1.6106E+10 bytes
Fixed Size		   18625040 bytes
Variable Size		 2483027968 bytes
Database Buffers	 1.3590E+10 bytes
Redo Buffers		   14925824 bytes
Database mounted.
Database opened.

SYS@xydbdg> show parameter name;

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
cdb_cluster_name		     string
cell_offloadgroup_name		     string
db_file_name_convert		     string
db_name 			     string	 xydb
db_unique_name			     string	 xydbdg
global_names			     boolean	 FALSE
instance_name			     string	 xydbdg
lock_name_space 		     string
log_file_name_convert		     string
pdb_file_name_convert		     string
processor_group_name		     string
service_names			     string	 xydbdg
SYS@xydbdg> 
```

### 2.2.主库(rac库)开启归档及设置force logging模式
#### 2.2.1.查询

#查询语句

```sql
select log_mode,force_logging from v$database;
```

#logs

```sql
SYS@xydb1> select log_mode,force_logging from v$database;

LOG_MODE     FORCE_LOGGING
------------ ---------------------------------------
ARCHIVELOG   NO
```




#### 2.2.2.开启归档模式
#如果安装rac时已经开启归档，此步骤略过

```sql
#主库关闭所有节点
[oracle@k8s-rac01 ~]$ srvctl stop database -d xydb

#主库任意节点启动至mount状态
SYS@xydb1> startup mount

#修改log_archive_dest_1参数
SYS@xydb1> alter system set log_archive_dest_1='location=+far/xydb/arch' scope=spfile sid='*';

#修改log_archive_format参数（该参数可以修改也可以不修改）
SYS@xydb1> alter system set log_archive_format='arch_%d_%t_%s_%r.log' scope=spfile sid='*';

修改数据库为归档模式
SYS@xydb1> alter database archivelog;

#关闭实例并重新启动数据库
SYS@xydb1> shutdown immediate

[oracle@k8s-rac01 ~]$ srvctl start database -d xydb

SYS@xydb1> alter database open;

Database altered.

SYS@xydb1> archive log list
Database log mode	       Archive Mode
Automatic archival	       Enabled
Archive destination	       +FAR/xydb/arch
Oldest online log sequence     4
Next log sequence to archive   5
Current log sequence	       5
```



#### 2.2.3.设置force logging模式

#语句

```sql
alter database force logging;
```



#logs

```sql
SYS@xydb1> select log_mode, force_logging from v$database;

LOG_MODE     FORCE_LOGGING
------------ ---------------------------------------
ARCHIVELOG   NO

SYS@xydb1> alter database force logging;

Database altered.

SYS@xydb1> select log_mode, force_logging from v$database;

LOG_MODE     FORCE_LOGGING
------------ ---------------------------------------
ARCHIVELOG   YES

SYS@xydb1> 
```



### 2.3.主库添加standby redo log

#rac每个redo thread都需要创建对应的standby redo log。创建原则和单实例一样，包括日志文件大小相等，日志组数量至少要多1组，每个thread多一组

#查询现有redo log

```sql
SYS@xydb1> col member for a50
SYS@xydb1> select a.thread#,a.group#,a.bytes/1024/1024,b.member from v$log a,v$logfile b where a.group#=b.group#;

   THREAD#     GROUP# A.BYTES/1024/1024 MEMBER
---------- ---------- ----------------- --------------------------------------------------
	 1	    2		    200 +DATA/XYDB/ONLINELOG/group_2.263.1153250787
	 1	    2		    200 +FRA/XYDB/ONLINELOG/group_2.258.1153250793
	 1	    1		    200 +DATA/XYDB/ONLINELOG/group_1.262.1153250787
	 1	    1		    200 +FRA/XYDB/ONLINELOG/group_1.257.1153250793
	 2	    3		    200 +DATA/XYDB/ONLINELOG/group_3.270.1153251915
	 2	    3		    200 +FRA/XYDB/ONLINELOG/group_3.259.1153251919
	 2	    4		    200 +DATA/XYDB/ONLINELOG/group_4.271.1153251923
	 2	    4		    200 +FRA/XYDB/ONLINELOG/group_4.260.1153251927

8 rows selected.

```

#添加srl

```sql
alter database add standby logfile thread 1 group 10 ('+DATA','+FRA') size 200m;
alter database add standby logfile thread 1 group 11 ('+DATA','+FRA') size 200m;	
alter database add standby logfile thread 1 group 12 ('+DATA','+FRA') size 200m;

alter database add standby logfile thread 2 group 13 ('+DATA','+FRA') size 200m;
alter database add standby logfile thread 2 group 14 ('+DATA','+FRA') size 200m;
alter database add standby logfile thread 2 group 15 ('+DATA','+FRA') size 200m;
```

#如果添加错误，删除srl的语句

```sql
alter database drop standby logfile group 10;
```



#logs

```sql
SYS@xydb1> alter database add standby logfile thread 1 group 10 ('+DATA','+FRA') size 200m;

Database altered.

SYS@xydb1> alter database add standby logfile thread 1 group 11 ('+DATA','+FRA') size 200m;

Database altered.

SYS@xydb1> alter database add standby logfile thread 1 group 12 ('+DATA','+FRA') size 200m;

Database altered.

SYS@xydb1> alter database add standby logfile thread 2 group 13 ('+DATA','+FRA') size 200m;

Database altered.

SYS@xydb1> alter database add standby logfile thread 2 group 14 ('+DATA','+FRA') size 200m;

Database altered.

SYS@xydb1> alter database add standby logfile thread 2 group 15 ('+DATA','+FRA') size 200m;

Database altered.

SYS@xydb1> 

```

#添加后查询

```sql
SYS@xydb1> col member for a50
SYS@xydb1> select group#,type,member from v$logfile order by 2;

    GROUP# TYPE    MEMBER
---------- ------- --------------------------------------------------
	 1 ONLINE  +DATA/XYDB/ONLINELOG/group_1.262.1153250787
	 2 ONLINE  +FRA/XYDB/ONLINELOG/group_2.258.1153250793
	 2 ONLINE  +DATA/XYDB/ONLINELOG/group_2.263.1153250787
	 4 ONLINE  +FRA/XYDB/ONLINELOG/group_4.260.1153251927
	 4 ONLINE  +DATA/XYDB/ONLINELOG/group_4.271.1153251923
	 3 ONLINE  +FRA/XYDB/ONLINELOG/group_3.259.1153251919
	 3 ONLINE  +DATA/XYDB/ONLINELOG/group_3.270.1153251915
	 1 ONLINE  +FRA/XYDB/ONLINELOG/group_1.257.1153250793
	14 STANDBY +DATA/XYDB/ONLINELOG/group_14.287.1159637933
	14 STANDBY +FRA/XYDB/ONLINELOG/group_14.296.1159637937
	15 STANDBY +DATA/XYDB/ONLINELOG/group_15.286.1159637943
	13 STANDBY +FRA/XYDB/ONLINELOG/group_13.319.1159637925
	13 STANDBY +DATA/XYDB/ONLINELOG/group_13.288.1159637923
	12 STANDBY +FRA/XYDB/ONLINELOG/group_12.329.1159637917
	12 STANDBY +DATA/XYDB/ONLINELOG/group_12.289.1159637915
	11 STANDBY +FRA/XYDB/ONLINELOG/group_11.335.1159637909
	11 STANDBY +DATA/XYDB/ONLINELOG/group_11.290.1159637907
	15 STANDBY +FRA/XYDB/ONLINELOG/group_15.316.1159637945
	10 STANDBY +DATA/XYDB/ONLINELOG/group_10.291.1159637897
	10 STANDBY +FRA/XYDB/ONLINELOG/group_10.314.1159637899

20 rows selected.


SYS@xydb1> select thread#,group#,bytes/1024/1024 MB,status from v$standby_log;

   THREAD#     GROUP#	      MB STATUS
---------- ---------- ---------- ----------
	 1	   10	     200 UNASSIGNED
	 1	   11	     200 UNASSIGNED
	 1	   12	     200 UNASSIGNED
	 2	   13	     200 UNASSIGNED
	 2	   14	     200 UNASSIGNED
	 2	   15	     200 UNASSIGNED

6 rows selected.
```

### 2.4.配置主/备库为静态监听
#### 2.4.1.配置主库为静态监听（rac1/rac2两个节点都要配置）

#grid用户修改主库监听文件listener.ora

```bash
su - grid
cd $ORACLE_HOME/network/admin
ls

#备份listener.ora
cp listener.ora listener.ora.bak

vi listener.ora

#添加以下内容
#实例1  k8s0-rac01
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = xydb)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = xydb_dgmgrl)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb1)
    )
  )
 
#实例2  k8s0-rac02
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = xydb)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb2)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = xydb_dgmgrl)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb2)
    )
  )   
  

#主库两个实例都配置好后，重启监听
lsnrctl status

srvctl stop listener -l listener

lsnrctl status

srvctl start listener -l listener

lsnrctl status

```



#logs

#主库实例1: k8s-rac1

```bash
[root@k8s-rac01 ~]# su - grid
Last login: Tue Jan 30 17:25:20 CST 2024
[grid@k8s-rac01 ~]$ cd $ORACLE_HOME/network/admin
[grid@k8s-rac01 admin]$ ls
listener2311186PM3828.bak  listener.ora  listener.ora.2024  listener.ora.bak.k8s-rac01.grid  samples  shrept.lst  sqlnet.ora
[grid@k8s-rac01 admin]$ cp listener.ora listener.ora.bak

[grid@k8s-rac01 admin]$ cat listener.ora
LISTENER=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER))))		# line added by Agent
LISTENER_SCAN1=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER_SCAN1))))		# line added by Agent
ASMNET1LSNR_ASM=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=ASMNET1LSNR_ASM))))		# line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_ASMNET1LSNR_ASM=ON		# line added by Agent
VALID_NODE_CHECKING_REGISTRATION_ASMNET1LSNR_ASM=SUBNET		# line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER_SCAN1=ON		# line added by Agent
VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN1=OFF		# line added by Agent - Disabled by Agent because REMOTE_REGISTRATION_ADDRESS is set
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER=ON		# line added by Agent
VALID_NODE_CHECKING_REGISTRATION_LISTENER=SUBNET		# line added by Agent

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = xydb)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = xydb_dgmgrl)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb1)
    )
  )



```



#主库实例1: k8s-rac2

```bash
[root@k8s-rac02 ~]# su - grid
Last login: Tue Jan 30 17:25:20 CST 2024
[grid@k8s-rac02 ~]$ cd $ORACLE_HOME/network/admin
[grid@k8s-rac02 admin]$ ls
listener.ora  listener.ora.bak.k8s-rac02.grid  samples  shrept.lst  sqlnet.ora
[grid@k8s-rac01 admin]$ cp listener.ora listener.ora.bak

[grid@k8s-rac02 admin]$ cat listener.ora
LISTENER_SCAN1=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER_SCAN1))))		# line added by Agent
LISTENER=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER))))		# line added by Agent
ASMNET1LSNR_ASM=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=IPC)(KEY=ASMNET1LSNR_ASM))))		# line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_ASMNET1LSNR_ASM=ON		# line added by Agent
VALID_NODE_CHECKING_REGISTRATION_ASMNET1LSNR_ASM=SUBNET		# line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER=ON		# line added by Agent
VALID_NODE_CHECKING_REGISTRATION_LISTENER=SUBNET		# line added by Agent
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER_SCAN1=ON		# line added by Agent
VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN1=OFF		# line added by Agent - Disabled by Agent because REMOTE_REGISTRATION_ADDRESS is set

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = xydb)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb2)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = xydb_dgmgrl)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydb2)
    )
  ) 
```



#重启监听

```bash
[grid@k8s-rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 10:34:40

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                08-JAN-2024 16:54:19
Uptime                    22 days 17 hr. 40 min. 20 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/k8s-rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.18.13.97)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.18.13.99)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "0a6cd91492ee7956e063620d12ac6018" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "0aca091340e201b7e063620d12acbbba" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_stuwork" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "stuwork" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
The command completed successfully
[grid@k8s-rac01 ~]$ srvctl stop listener -l listener
[grid@k8s-rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 10:34:55

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 2: No such file or directory
[grid@k8s-rac01 ~]$ srvctl start listener -l listener
[grid@k8s-rac01 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 10:36:12

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                31-JAN-2024 10:34:59
Uptime                    0 days 0 hr. 1 min. 12 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/k8s-rac01/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.18.13.97)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.18.13.99)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "0a6cd91492ee7956e063620d12ac6018" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "0aca091340e201b7e063620d12acbbba" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_portal" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "s_stuwork" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "stuwork" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb" has 2 instance(s).
  Instance "xydb1", status UNKNOWN, has 1 handler(s) for this service...
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb1", status READY, has 1 handler(s) for this service...
Service "xydb_dgmgrl" has 1 instance(s).
  Instance "xydb1", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully


[grid@k8s-rac02 ~]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 10:38:31

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                31-JAN-2024 10:34:59
Uptime                    0 days 0 hr. 3 min. 31 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/19.0.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/k8s-rac02/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.18.13.98)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=172.18.13.100)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM2", status READY, has 1 handler(s) for this service...
Service "+ASM_DATA" has 1 instance(s).
  Instance "+ASM2", status READY, has 1 handler(s) for this service...
Service "+ASM_FRA" has 1 instance(s).
  Instance "+ASM2", status READY, has 1 handler(s) for this service...
Service "+ASM_OCR" has 1 instance(s).
  Instance "+ASM2", status READY, has 1 handler(s) for this service...
Service "0a6cd91492ee7956e063620d12ac6018" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "0aca091340e201b7e063620d12acbbba" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "portal" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "s_portal" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "s_stuwork" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "stuwork" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "xydb" has 2 instance(s).
  Instance "xydb2", status UNKNOWN, has 1 handler(s) for this service...
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "xydbXDB" has 1 instance(s).
  Instance "xydb2", status READY, has 1 handler(s) for this service...
Service "xydb_dgmgrl" has 1 instance(s).
  Instance "xydb2", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully

```





#### 2.4.2.配置备库为静态监听
#单实例数据库，oracle用户修改主库监听文件listener.ora

```bash
su - oracle
cd $ORACLE_HOME/network/admin
ls

#备份listener.ora
cp listener.ora listener.ora.bak

vi listener.ora

#添加以下内容

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = xydbdg)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydbdg)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = xydbdg_dgmgrl)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydbdg)
    )
  )
 
  
  

#重启监听
lsnrctl status

lsnrctl stop 

lsnrctl status

lsnrctl start 

lsnrctl status

```



#logs

```bash
[root@k8s-oracle-store ~]# su - oracle
Last login: Tue Jan 30 17:43:41 CST 2024 on pts/0
[oracle@k8s-oracle-store ~]$ cd $ORACLE_HOME/network/admin
[oracle@k8s-oracle-store admin]$ ls
listener.ora  samples  shrept.lst  sqlnet.ora  tnsnames.ora
[oracle@k8s-oracle-store admin]$ cp listener.ora listener.ora.bak
[oracle@k8s-oracle-store admin]$ vi listener.ora

# listener.ora Network Configuration File: /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
# Generated by Oracle configuration tools.

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = xydbdg)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydbdg)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = xydbdg_dgmgrl)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydbdg)
    )
  )


#备库DBCA删库前
[oracle@k8s-oracle-store admin]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 10:48:33

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                06-JAN-2024 14:43:47
Uptime                    24 days 20 hr. 4 min. 46 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "0e31c167f62f6743e063680d12ac3ce5" has 1 instance(s).
  Instance "xydbdg", status READY, has 1 handler(s) for this service...
Service "86b637b62fdf7a65e053f706e80a27ca" has 1 instance(s).
  Instance "xydbdg", status READY, has 1 handler(s) for this service...
Service "testpdb" has 1 instance(s).
  Instance "xydbdg", status READY, has 1 handler(s) for this service...
Service "xydbdg" has 1 instance(s).
  Instance "xydbdg", status READY, has 1 handler(s) for this service...
Service "xydbdgXDB" has 1 instance(s).
  Instance "xydbdg", status READY, has 1 handler(s) for this service...
The command completed successfully

#DBCA删库后
[oracle@k8s-oracle-store admin]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 16:19:11

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                31-JAN-2024 16:19:05
Uptime                    0 days 0 hr. 0 min. 5 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
The listener supports no services
The command completed successfully


[oracle@k8s-oracle-store admin]$ lsnrctl stop

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 10:48:37

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
The command completed successfully


[oracle@k8s-oracle-store admin]$ lsnrctl start

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 16:22:16

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Starting /u01/app/oracle/product/19.0.0/db_1/bin/tnslsnr: please wait...

TNSLSNR for Linux: Version 19.0.0.0.0 - Production
System parameter file is /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Log messages written to /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                31-JAN-2024 16:22:16
Uptime                    0 days 0 hr. 0 min. 0 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "xydbdg" has 1 instance(s).
  Instance "xydbdg", status UNKNOWN, has 1 handler(s) for this service...
Service "xydbdg_dgmgrl" has 1 instance(s).
  Instance "xydbdg", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully


[oracle@k8s-oracle-store admin]$ lsnrctl status

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 16:22:25

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0 - Production
Start Date                31-JAN-2024 16:22:16
Uptime                    0 days 0 hr. 0 min. 8 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/k8s-oracle-store/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=k8s-oracle-store)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "xydbdg" has 1 instance(s).
  Instance "xydbdg", status UNKNOWN, has 1 handler(s) for this service...
Service "xydbdg_dgmgrl" has 1 instance(s).
  Instance "xydbdg", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
[oracle@k8s-oracle-store admin]$ 
```





### 2.5.配置主、备库的tnsnames.ora

#### 2.5.1.配置主库的tnsnames.ora（rac1/rac2两个节点都要配置）

```bash
su - oracle

cd $ORACLE_HOME/network/admin

cp tnsnames.ora tnsnames.ora.bak

vi tnsnames.ora

XYDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydb)
    )
  )


XYDBDG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydbdg)
    )
  )
  
  
tnsping xydb

tnsping xydbdg
```



#logs

#k8s-rac01

```bash
[root@k8s-rac01 ~]# su - oracle

[oracle@k8s-rac01 ~]$ cd $ORACLE_HOME/network/admin

[oracle@k8s-rac01 admin]$ ls
samples  shrept.lst  sqlnet.ora  tnsnames.ora

[oracle@k8s-rac01 admin]$ vi tnsnames.ora 
# tnsnames.ora Network Configuration File: /u01/app/oracle/product/19.0.0/db_1/network/admin/tnsnames.ora
# Generated by Oracle configuration tools.

XYDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydb)
    )
  )


XYDBDG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydbdg)
    )
  )


[oracle@k8s-rac01 admin]$ tnsping xydb

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 13:51:20

Copyright (c) 1997, 2023, Oracle.  All rights reserved.

Used parameter files:
/u01/app/oracle/product/19.0.0/db_1/network/admin/sqlnet.ora


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = xydb)))
OK (0 msec)


[oracle@k8s-rac01 admin]$ tnsping xydbdg

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 13:51:23

Copyright (c) 1997, 2023, Oracle.  All rights reserved.

Used parameter files:
/u01/app/oracle/product/19.0.0/db_1/network/admin/sqlnet.ora


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = xydbdg)))
OK (0 msec)
[oracle@k8s-rac01 admin]$ 


```



#k8s-rac02

```bash
[root@k8s-rac02 ~]# su - oracle

[oracle@k8s-rac02 ~]$ cd $ORACLE_HOME/network/admin
[oracle@k8s-rac02 admin]$ ls
samples  shrept.lst  sqlnet.ora  tnsnames.ora


[oracle@k8s-rac02 admin]$ vi tnsnames.ora 

# tnsnames.ora Network Configuration File: /u01/app/oracle/product/19.0.0/db_1/network/admin/tnsnames.ora
# Generated by Oracle configuration tools.

XYDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydb)
    )
  )

XYDBDG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydbdg)
    )
  )
                                                                                                                                                                                                               
[oracle@k8s-rac02 admin]$ tnsping xydb

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 13:53:28

Copyright (c) 1997, 2023, Oracle.  All rights reserved.

Used parameter files:
/u01/app/oracle/product/19.0.0/db_1/network/admin/sqlnet.ora


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = xydb)))
OK (10 msec)


[oracle@k8s-rac02 admin]$ tnsping xydbdg

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 13:53:30

Copyright (c) 1997, 2023, Oracle.  All rights reserved.

Used parameter files:
/u01/app/oracle/product/19.0.0/db_1/network/admin/sqlnet.ora


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = xydbdg)))
OK (0 msec)
[oracle@k8s-rac02 admin]$ 
                                                                
```

#### 2.5.2.配置备库的tnsnames.ora

```bash
su - oracle

cd $ORACLE_HOME/network/admin

cp tnsnames.ora tnsnames.ora.bak

vi tnsnames.ora

XYDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydb)
    )
  )


XYDBDG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydbdg)
    )
  )
  
  
tnsping xydb

tnsping xydbdg
```



#logs

```bash
[root@k8s-oracle-store ~]# su - oracle

[oracle@k8s-oracle-store ~]$ cd $ORACLE_HOME/network/admin

[oracle@k8s-oracle-store admin]$ ls
listener.ora  listener.ora.bak  samples  shrept.lst  sqlnet.ora  tnsnames.ora

[oracle@k8s-oracle-store admin]$ cp tnsnames.ora tnsnames.ora.bak

[oracle@k8s-oracle-store admin]$ cat tnsnames.ora
# tnsnames.ora Network Configuration File: /u01/app/oracle/product/19.0.0/db_1/network/admin/tnsnames.ora
# Generated by Oracle configuration tools.

XYDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydb)
    )
  )


XYDBDG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = xydbdg)
    )
  )

[oracle@k8s-oracle-store admin]$ tnsping xydb

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 16:27:06

Copyright (c) 1997, 2023, Oracle.  All rights reserved.

Used parameter files:
/u01/app/oracle/product/19.0.0/db_1/network/admin/sqlnet.ora


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = xydb)))
OK (0 msec)
[oracle@k8s-oracle-store admin]$ tnsping xydbdg

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 31-JAN-2024 16:27:10

Copyright (c) 1997, 2023, Oracle.  All rights reserved.

Used parameter files:
/u01/app/oracle/product/19.0.0/db_1/network/admin/sqlnet.ora


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = k8s-oracle-store)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = xydbdg)))
OK (0 msec)
[oracle@k8s-oracle-store admin]$ 
```





### 2.6.创建备库相应目录

#因为xydbdg已经建库，部分目录可能已经存在

#可以参考文档开始的initXYDBDG.ora，或者新建也可以



#如果xydbdg没有建库，那么全部要重新建立

#创建adump路径、数据文件、日志文件、临时文件、归档日志文件目录

#注意因为onlinelog路径转换有问题，此处创建两个目录onlinelog01、onlinelog02及相关子目录

```bash
su - oracle

mkdir -p /u01/app/oracle/admin/xydbdg/adump
mkdir -p /u01/app/oracle/oradata/xydbdg
mkdir -p /u01/app/oracle/oradata/xydbdg/datafile/
mkdir -p /u01/app/oracle/oradata/xydbdg/tempfile/
mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog01/
mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog02/
mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog
mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog02/xydb/onlinelog
mkdir -p /u01/app/oracle/fast_recovery_area/xydbdg/archivelog
```



#logs

```bash
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/admin/xydbdg/adump
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/oradata/xydbdg
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/oradata/xydbdg/datafile/
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/oradata/xydbdg/tempfile/
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog01/
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog02/
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/oradata/xydbdg/onlinelog02/xydb/onlinelog
[oracle@k8s-oracle-store ~]$ mkdir -p /u01/app/oracle/fast_recovery_area/xydbdg/archivelog
```



### 2.7.创建备库口令文件

#主库通过grid用户copy出passwd文件，然后传输到备库，并改名

#主库

```bash
#查询passwd文件位置

#方式一，通过oracle用户
su - oracle
srvctl config database -d xydb
exit

#方式二，通过grid用户
ASMCMD> pwget --dbuniquename xydb
+DATA/XYDB/PASSWORD/pwdxydb.256.1153250601


su - grid

asmcmd

ASMCMD> pwget --dbuniquename xydb
+DATA/XYDB/PASSWORD/pwdxydb.256.1153250601

cd +DATA/XYDB/PASSWORD
ls

cp +DATA/XYDB/PASSWORD/pwdxydb.256.1153250601 /home/grid/
exit

ls

scp pwdxydb.256.1153250601 oracle@k8s-oracle-store:/u01/app/oracle/product/19.0.0/db_1/dbs/
```



#备库

```bash
su - oracle

cd /u01/app/oracle/product/19.0.0/db_1/dbs
ls

mv pwdxydb.256.1153250601 orapwxydbdg
```





#logs

#主库

```bash
[root@k8s-rac01 ~]# su - grid


[oracle@k8s-rac01 ~]$ srvctl config database -d xydb
Database unique name: xydb
Database name: xydb
Oracle home: /u01/app/oracle/product/19.0.0/db_1
Oracle user: oracle
Spfile: +DATA/XYDB/PARAMETERFILE/spfile.272.1153251931
Password file: +DATA/XYDB/PASSWORD/pwdxydb.256.1153250601
Domain: 
Start options: open
Stop options: immediate
Database role: PRIMARY
Management policy: AUTOMATIC
Server pools: 
Disk Groups: FRA,DATA
Mount point paths: 
Services: s_portal,s_stuwork
Type: RAC
Start concurrency: 
Stop concurrency: 
OSDBA group: dba
OSOPER group: oper
Database instances: xydb1,xydb2
Configured nodes: k8s-rac01,k8s-rac02
CSS critical: no
CPU count: 0
Memory target: 0
Maximum memory: 0
Default network number for database services: 
Database is administrator managed

[oracle@k8s-rac02 ~]$ exit
logout


[root@k8s-rac01 ~]# su - grid
Last login: Wed Jan 31 14:59:32 CST 2024 on pts/0
[grid@k8s-rac01 ~]$ asmcmd
ASMCMD> cd +DATA/XYDB/PASSWORD
ASMCMD> ls
pwdxydb.256.1153250601
ASMCMD> cp +DATA/XYDB/PASSWORD/pwdxydb.256.1153250601 /home/grid/
copying +DATA/XYDB/PASSWORD/pwdxydb.256.1153250601 -> /home/grid//pwdxydb.256.1153250601
ASMCMD> ls
pwdxydb.256.1153250601
ASMCMD> exit
[grid@k8s-rac01 ~]$ ls
pwdxydb.256.1153250601

[grid@k8s-rac01 ~]$ scp pwdxydb.256.1153250601 oracle@k8s-oracle-store:/u01/app/oracle/product/19.0.0/db_1/dbs/

The authenticity of host 'k8s-oracle-store (172.18.13.104)' can't be established.
ECDSA key fingerprint is SHA256:lCuH25nVLEzWv8/It70CaJstQosPPy8DqK/r4kaFcPw.
ECDSA key fingerprint is MD5:4f:e4:0e:73:05:e5:b2:fa:68:b6:89:3c:4a:8b:38:eb.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'k8s-oracle-store,172.18.13.104' (ECDSA) to the list of known hosts.
oracle@k8s-oracle-store's password: 
pwdxydb.256.1153250601                         100% 2048     1.0MB/s   00:00                                                                                         
```



#备库

```bash
[root@k8s-oracle-store ~]# su - oracle

[oracle@k8s-oracle-store ~]$ cd $ORACLE_HOME/dbs
[oracle@k8s-oracle-store dbs]$ ls
hc_xydbdg.dat  init.ora  lkXYDB  pwdxydb.256.1153250601

[oracle@k8s-oracle-store dbs]$ mv pwdxydb.256.1153250601 orapwxydbdg
```



### 2.8.修改主库参数并生成pfile文件，拷贝到备库

#主库

#修改db参数

```sql
alter system set log_archive_config='DG_CONFIG=(xydb,xydbdg)' scope=both sid='*';

alter system set log_archive_dest_1='LOCATION=+fra VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=xydb' scope=both sid='*';

alter system set log_archive_dest_2='SERVICE=xydbdg LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=xydbdg' scope=both sid='*';

alter system set standby_file_management=auto scope=both sid='*';

alter system set fal_client='xydb' scope=both sid='*';
alter system set fal_server='xydbdg' scope=both sid='*';

alter system set db_file_name_convert='/u01/app/oracle/oradata/xydbdg/datafile','+DATA','/u01/app/oracle/oradata/xydbdg/tempfile','+DATA' scope=spfile sid='*';
alter system set log_file_name_convert='/u01/app/oracle/oradata/xydbdg/onlinelog01','+DATA','/u01/app/oracle/oradata/xydbdg/onlinelog02','+FRA' scope=spfile sid='*';
```



#如果使用 dg_broker方式来管理ADG，那么下面的参数就不需要设置了，因为12c以后的版本这些参数都是有dg_broker来管理的

```sql
alter system set log_archive_dest_1='LOCATION=+fra VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=xydb' scope=both sid='*';

alter system set log_archive_dest_2='SERVICE=xydbdg LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=xydbdg' scope=both sid='*';
```



##其中db_file_name_convert和log_file_name_convert中的路径本来应该来自dba_data_files、dba_temp_files、v$logfile，写上具体路径，但是因为我们已经创建了部分PDB，路径还在这之外，所以直接使用了+DATA和+FRA

```sql
alter system set db_file_name_convert='/u01/app/oracle/oradata/xydbdg/datafile','+DATA/XYDB/DATAFILE','/u01/app/oracle/oradata/xydbdg/tempfile','+DATA/XYDB/TEMPFILE' scope=spfile sid='*';
alter system set log_file_name_convert='/u01/app/oracle/oradata/xydbdg/onlinelog01','+DATA/XYDB/ONLINELOG','/u01/app/oracle/oradata/xydbdg/onlinelog02','+FRA/XYDB/ONLINELOG' scope=spfile sid='*';
```





#主库重启数据库，将之前的参数生效

```bash
su - oracle

srvctl  stop database -db xydb
srvctl  start database -db xydb
```



#主库生成pfile文件

```bash
su - grid
asmcmd

cd +data/xydb/parameterfile
ls
#记下spfile文件的名字

su - oracle
sqlplus / as sysdba

create pfile='/home/oracle/initxydb1.ora' from spfile='+data/xydb/parameterfile/spfile.272.1153251931';

exit

ls

scp initxydb1.ora k8s-oracle-store:/u01/app/oracle/product/19.0.0/db_1/dbs/


```



#备库修改参数文件，生成pfile

```bash
su - oracle
cd /u01/app/oracle/product/19.0.0/db_1/dbs
ls
vi initxydbdg.ora
```

```bash
[oracle@k8s-oracle-store dbs]$ cat initxydbdg.ora 
*._disable_file_resize_logging=TRUE
*.audit_file_dest='/u01/app/oracle/admin/xydbdg/adump'
*.audit_trail='db'
*.cluster_database=false
*.compatible='19.0.0'
*.control_files='/u01/app/oracle/oradata/xydbdg/control01.ctl','/u01/app/oracle/fast_recovery_area/xydbdg/control02.ctl'
*.db_block_size=8192
*.db_file_name_convert='+DATA','/u01/app/oracle/oradata/xydbdg/datafile','+DATA','/u01/app/oracle/oradata/xydbdg/tempfile'
*.db_files=4096
*.db_name='xydb'
*.db_recovery_file_dest='/u01/app/oracle/fast_recovery_area'
*.db_recovery_file_dest_size=20g
*.db_unique_name='xydbdg'
*.diagnostic_dest='/u01/app/oracle'
*.dispatchers='(PROTOCOL=TCP) (SERVICE=xydbdgXDB)'
*.enable_pluggable_database=true
*.event='10795 trace name context forever, level 2'
*.fal_client='xydbdg'
*.fal_server='xydb'
family:dw_helper.instance_mode='read-only'
*.local_listener='-oraagent-dummy-'
*.log_archive_format='%t_%s_%r.dbf'
*.log_archive_config='DG_CONFIG=(xydbdg,xydb)'
*.log_archive_dest_1='LOCATION=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=xydbdg'
*.log_archive_dest_2='SERVICE=xydb LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=xydb'
*.log_file_name_convert='+DATA','/u01/app/oracle/oradata/xydbdg/onlinelog01','+FRA','/u01/app/oracle/oradata/xydbdg/onlinelog01'
*.nls_language='AMERICAN'
*.nls_territory='AMERICA'
*.open_cursors=300
*.pga_aggregate_target=5g
*.processes=3000
*.remote_login_passwordfile='EXCLUSIVE'
*.sga_target=15g
*.undo_tablespace='UNDOTBS1'
*.standby_file_management='AUTO'
```



#logs

#修改db参数

```sql
SYS@xydb1> alter system set log_archive_config='DG_CONFIG=(xydb,xydbdg)' scope=both sid='*';

System altered.

SYS@xydb1> alter system set log_archive_dest_1='LOCATION=+fra VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=xydb' scope=both sid='*';

System altered.

SYS@xydb1> alter system set log_archive_dest_2='SERVICE=xydbdg LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=xydbdg' scope=both sid='*';

System altered.

SYS@xydb1> alter system set standby_file_management=auto scope=both sid='*';

System altered.

SYS@xydb1> alter system set fal_client='xydb' scope=both sid='*';

System altered.

SYS@xydb1> alter system set fal_server='xydbdg' scope=both sid='*';

System altered.

SYS@xydb1> alter system set db_file_name_convert='/u01/app/oracle/oradata/xydbdg/datafile','+DATA','/u01/app/oracle/oradata/xydbdg/tempfile','+DATA' scope=spfile sid='*';

System altered.

SYS@xydb1> alter system set log_file_name_convert='/u01/app/oracle/oradata/xydbdg/onlinelog','+DATA' scope=spfile sid='*';

System altered.

SYS@xydb1> 

```



#主库重启数据库

```bash
[oracle@k8s-rac01 ~]$ srvctl  stop database -db  xydb
[oracle@k8s-rac01 ~]$ srvctl  start database -db  xydb
```



#生成pfile文件

```sql
[root@k8s-rac01 ~]# su - grid
Last login: Wed Jan 31 17:05:21 CST 2024
[grid@k8s-rac01 ~]$ asmcmd
ASMCMD> cd +data/xydb/parameterfile
ASMCMD> ls
spfile.272.1153251931
ASMCMD> exit
[grid@k8s-rac01 ~]$ exit
logout


[root@k8s-rac01 ~]# su - oracle
Last login: Wed Jan 31 17:09:53 CST 2024 on pts/0
[oracle@k8s-rac01 ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Wed Jan 31 17:14:12 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

SYS@xydb1> 


SYS@xydb1> create pfile='/home/oracle/initxydb1.ora' from spfile='+data/xydb/parameterfile/spfile.272.1153251931';

File created.

SYS@xydb1> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0
[oracle@k8s-rac01 ~]$ ls
initxydb1.ora

[oracle@k8s-rac01 ~]$ scp initxydb1.ora k8s-oracle-store:/u01/app/oracle/product/19.0.0/db_1/dbs/
The authenticity of host 'k8s-oracle-store (172.18.13.104)' can't be established.
ECDSA key fingerprint is SHA256:lCuH25nVLEzWv8/It70CaJstQosPPy8DqK/r4kaFcPw.
ECDSA key fingerprint is MD5:4f:e4:0e:73:05:e5:b2:fa:68:b6:89:3c:4a:8b:38:eb.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'k8s-oracle-store' (ECDSA) to the list of known hosts.
oracle@k8s-oracle-store's password: 
initxydb1.ora                                     100% 2449     1.0MB/s   00:00    
[oracle@k8s-rac01 ~]$ 
```



### 2.9.修改备库pfile文件

#可以比对主库拷贝过来的pfile和原本DBCA删库前生产的pfile，并根据实际情况调整参数

```bash
[oracle@k8s-oracle-store ~]$ cd $ORACLE_HOME/dbs/
[oracle@k8s-oracle-store dbs]$ pwd
/u01/app/oracle/product/19.0.0/db_1/dbs
[oracle@k8s-oracle-store dbs]$ ls
hc_xydbdg.dat  init.ora  initxydb1.ora  lkXYDB  pwdxydbdg
[oracle@k8s-oracle-store dbs]$ vi initxydbdg.ora 

```



#最终initxydbdg.ora

```conf
[oracle@k8s-oracle-store dbs]$ cat initxydbdg.ora 
*._disable_file_resize_logging=TRUE
*.audit_file_dest='/u01/app/oracle/admin/xydbdg/adump'
*.audit_trail='db'
*.cluster_database=false
*.compatible='19.0.0'
*.control_files='/u01/app/oracle/oradata/xydbdg/control01.ctl','/u01/app/oracle/fast_recovery_area/xydbdg/control02.ctl'
*.db_block_size=8192
*.db_file_name_convert='+DATA','/u01/app/oracle/oradata/xydbdg/datafile','+DATA','/u01/app/oracle/oradata/xydbdg/tempfile'
*.db_files=4096
*.db_name='xydb'
*.db_recovery_file_dest='/u01/app/oracle/fast_recovery_area'
*.db_recovery_file_dest_size=20g
*.db_unique_name='xydbdg'
*.diagnostic_dest='/u01/app/oracle'
*.dispatchers='(PROTOCOL=TCP) (SERVICE=xydbdgXDB)'
*.enable_pluggable_database=true
*.event='10795 trace name context forever, level 2'
*.fal_client='xydbdg'
*.fal_server='xydb'
family:dw_helper.instance_mode='read-only'
*.local_listener='-oraagent-dummy-'
*.log_archive_format='%t_%s_%r.dbf'
*.log_archive_config='DG_CONFIG=(xydbdg,xydb)'
*.log_archive_dest_1='LOCATION=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=xydbdg'
*.log_archive_dest_2='SERVICE=xydb LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=xydb'
*.log_file_name_convert='+DATA','/u01/app/oracle/oradata/xydbdg/onlinelog01','+FRA','/u01/app/oracle/oradata/xydbdg/onlinelog01'
*.nls_language='AMERICAN'
*.nls_territory='AMERICA'
*.open_cursors=300
*.pga_aggregate_target=5g
*.processes=3000
*.remote_login_passwordfile='EXCLUSIVE'
*.sga_target=15g
*.undo_tablespace='UNDOTBS1'
*.standby_file_management='AUTO'
```



### 2.10.备库启动至nomount状态

#备库

```bash
su - oracle
sqlplus / as sysdba

startup nomount;
```



#logs

```bash
[root@k8s-oracle-store ~]# su - oracle

[oracle@k8s-oracle-store ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Wed Jan 31 17:51:31 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

Connected to an idle instance.

SYS@xydbdg> startup nomount;
ORACLE instance started.

Total System Global Area 1.6106E+10 bytes
Fixed Size		   18625040 bytes
Variable Size		 2181038080 bytes
Database Buffers	 1.3892E+10 bytes
Redo Buffers		   14925824 bytes
SYS@xydbdg> 

```



### 2.11.主库准备连接辅助实例

#主库操作

```bash
su - oracle

rman target sys/Oracle2023#Sys@xydb auxiliary sys/Oracle2023#Sys@xydbdg

```



#logs

```bash
[root@k8s-rac01 ~]# su - oracle

[oracle@k8s-rac01 ~]$ rman target sys/Oracle2023#Sys@xydb auxiliary sys/Oracle2023#Sys@xydbdg

Recovery Manager: Release 19.0.0.0.0 - Production on Wed Jan 31 18:02:41 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: XYDB (DBID=2062989406)
connected to auxiliary database: XYDB (not mounted)

RMAN> 

```



#如果前面口令文件名称不对，会报错

#单实例的口令文件为orapwdxydbdg，而不是pwdxydbdg

```bash
[oracle@k8s-rac01 ~]$ rman target sys/Oracle2023#Sys@xydb auxiliary sys/Oracle2023#Sys@xydbdg

Recovery Manager: Release 19.0.0.0.0 - Production on Wed Jan 31 17:56:30 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: XYDB (DBID=2062989406)
RMAN-00571: ===========================================================
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
RMAN-00554: initialization of internal recovery manager package failed
RMAN-04006: error from auxiliary database: ORA-01017: invalid username/password; logon denied
```



### 2.12.开始duplicate，备库创建

#主库执行以下脚本

```sql
run {
	allocate channel c1 type disk;
	allocate channel c2 type disk;
	allocate channel c3 type disk;
	allocate channel c4 type disk;
	allocate channel c5 type disk;
	allocate channel c6 type disk;
	allocate channel c7 type disk;
	allocate channel c8 type disk;
	allocate auxiliary channel s1 type disk;
	allocate auxiliary channel s2 type disk;
	allocate auxiliary channel s3 type disk;
	allocate auxiliary channel s4 type disk;
	allocate auxiliary channel s5 type disk;
	allocate auxiliary channel s6 type disk;
	allocate auxiliary channel s7 type disk;
	allocate auxiliary channel s8 type disk;
	duplicate target database
		for standby
		from active database dorecover 
		nofilenamecheck;
	release channel c1;
	release channel c2;
	release channel c3;
	release channel c4;
	release channel c5;
	release channel c6;
	release channel c7;
	release channel s1;
	release channel s2;
	release channel s3;
	release channel s4;	
	release channel s5;
	release channel s6;
	release channel s7;
	release channel s8;	
}
```



#logs

#正确日志

```bash
[oracle@k8s-rac01 ~]$ rman target sys/Oracle2023#Sys@xydb auxiliary sys/Oracle2023#Sys@xydbdg

Recovery Manager: Release 19.0.0.0.0 - Production on Wed Jan 31 18:21:27 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: XYDB (DBID=2062989406)
connected to auxiliary database: XYDB (not mounted)

RMAN> run {
	allocate channel c1 type disk;
	allocate channel c2 type disk;
	allocate channel c3 type disk;
	allocate channel c4 type disk;
	allocate channel c5 type disk;
	allocate channel c6 type disk;
	allocate channel c7 type disk;
	allocate channel c8 type disk;
	allocate auxiliary channel s1 type disk;
	allocate auxiliary channel s2 type disk;
	allocate auxiliary channel s3 type disk;
	allocate auxiliary channel s4 type disk;
	allocate auxiliary channel s5 type disk;
	allocate auxiliary channel s6 type disk2> 3> 4> 5> 6> 7> 8> 9> 10> 11> 12> 13> 14> 15> ;
	allocate auxiliary channel s7 type disk;
	allocate auxiliary channel s8 type disk;
	duplicate target database
		for standby
		from active database dorecover 
		nofilenamecheck;
	release channel c1;
	release channel c2;
	release channel c3;
	release chan16> 17> 18> 19> 20> 21> 22> 23> 24> 25> nel c4;
	release channel c5;
	release channel c6;
	release channel c7;
	release channel s1;
	release channel s2;
	release channel s3;
	release channel s4;	
	release channel s5;
	release channel s6;
	release channel s7;
	release channel s8;	
}26> 27> 28> 29> 30> 31> 32> 33> 34> 35> 36> 37> 

using target database control file instead of recovery catalog
allocated channel: c1
channel c1: SID=13 instance=xydb2 device type=DISK

allocated channel: c2
channel c2: SID=2554 instance=xydb1 device type=DISK

allocated channel: c3
channel c3: SID=295 instance=xydb2 device type=DISK

allocated channel: c4
channel c4: SID=579 instance=xydb2 device type=DISK

allocated channel: c5
channel c5: SID=1144 instance=xydb2 device type=DISK

allocated channel: c6
channel c6: SID=1425 instance=xydb2 device type=DISK

allocated channel: c7
channel c7: SID=575 instance=xydb1 device type=DISK

allocated channel: c8
channel c8: SID=863 instance=xydb1 device type=DISK

allocated channel: s1
channel s1: SID=2267 device type=DISK

allocated channel: s2
channel s2: SID=2550 device type=DISK

allocated channel: s3
channel s3: SID=2833 device type=DISK

allocated channel: s4
channel s4: SID=3116 device type=DISK

allocated channel: s5
channel s5: SID=1418 device type=DISK

allocated channel: s6
channel s6: SID=3400 device type=DISK

allocated channel: s7
channel s7: SID=3682 device type=DISK

allocated channel: s8
channel s8: SID=3966 device type=DISK

Starting Duplicate Db at 2024-01-31 18:21:51
current log archived

contents of Memory Script:
{
   backup as copy reuse
   passwordfile auxiliary format  '/u01/app/oracle/product/19.0.0/db_1/dbs/orapwxydbdg'   ;
}
executing Memory Script

Starting backup at 2024-01-31 18:21:56
Finished backup at 2024-01-31 18:22:00

contents of Memory Script:
{
   restore clone from service  'xydb' standby controlfile;
}
executing Memory Script

Starting restore at 2024-01-31 18:22:00

channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: restoring control file
channel s1: restore complete, elapsed time: 00:00:02
output file name=/u01/app/oracle/oradata/xydbdg/control01.ctl
output file name=/u01/app/oracle/fast_recovery_area/xydbdg/control02.ctl
Finished restore at 2024-01-31 18:22:04

contents of Memory Script:
{
   sql clone 'alter database mount standby database';
}
executing Memory Script

sql statement: alter database mount standby database

contents of Memory Script:
{
   set newname for tempfile  1 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809";
   set newname for tempfile  2 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145";
   set newname for tempfile  3 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195";
   set newname for tempfile  4 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445";
   switch clone tempfile all;
   set newname for datafile  1 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/system.257.1153250631";
   set newname for datafile  3 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/sysaux.258.1153250677";
   set newname for datafile  4 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs1.259.1153250701";
   set newname for datafile  5 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/system.265.1153251113";
   set newname for datafile  6 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/sysaux.266.1153251113";
   set newname for datafile  7 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/users.260.1153250703";
   set newname for datafile  8 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/undotbs1.267.1153251113";
   set newname for datafile  9 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs2.269.1153251451";
   set newname for datafile  10 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/system.274.1153252181";
   set newname for datafile  11 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/sysaux.275.1153252181";
   set newname for datafile  12 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undotbs1.273.1153252181";
   set newname for datafile  13 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undo_2.277.1153252217";
   set newname for datafile  14 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/users.278.1153252229";
   set newname for datafile  15 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/system.281.1153652419";
   set newname for datafile  16 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/sysaux.280.1153652419";
   set newname for datafile  17 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undotbs1.279.1153652419";
   set newname for datafile  18 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undo_2.283.1153652669";
   restore
   from  nonsparse   from service 
 'xydb'   clone database
   ;
   sql 'alter system archive log current';
}
executing Memory Script

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

renamed tempfile 1 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809 in control file
renamed tempfile 2 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145 in control file
renamed tempfile 3 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195 in control file
renamed tempfile 4 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445 in control file

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

Starting restore at 2024-01-31 18:22:11

channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: specifying datafile(s) to restore from backup set
channel s1: restoring datafile 00001 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/system.257.1153250631
channel s2: starting datafile backup set restore
channel s2: using network backup set from service xydb
channel s2: specifying datafile(s) to restore from backup set
channel s2: restoring datafile 00003 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/sysaux.258.1153250677
channel s3: starting datafile backup set restore
channel s3: using network backup set from service xydb
channel s3: specifying datafile(s) to restore from backup set
channel s3: restoring datafile 00004 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs1.259.1153250701
channel s4: starting datafile backup set restore
channel s4: using network backup set from service xydb
channel s4: specifying datafile(s) to restore from backup set
channel s4: restoring datafile 00005 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/system.265.1153251113
channel s5: starting datafile backup set restore
channel s5: using network backup set from service xydb
channel s5: specifying datafile(s) to restore from backup set
channel s5: restoring datafile 00006 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/sysaux.266.1153251113
channel s6: starting datafile backup set restore
channel s6: using network backup set from service xydb
channel s6: specifying datafile(s) to restore from backup set
channel s6: restoring datafile 00007 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/users.260.1153250703
channel s7: starting datafile backup set restore
channel s7: using network backup set from service xydb
channel s7: specifying datafile(s) to restore from backup set
channel s7: restoring datafile 00008 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/undotbs1.267.1153251113
channel s8: starting datafile backup set restore
channel s8: using network backup set from service xydb
channel s8: specifying datafile(s) to restore from backup set
channel s8: restoring datafile 00009 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs2.269.1153251451
channel s1: restore complete, elapsed time: 00:00:34
channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: specifying datafile(s) to restore from backup set
channel s1: restoring datafile 00010 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/system.274.1153252181
channel s3: restore complete, elapsed time: 00:00:38
channel s3: starting datafile backup set restore
channel s3: using network backup set from service xydb
channel s3: specifying datafile(s) to restore from backup set
channel s3: restoring datafile 00011 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/sysaux.275.1153252181
channel s6: restore complete, elapsed time: 00:00:22
channel s6: starting datafile backup set restore
channel s6: using network backup set from service xydb
channel s6: specifying datafile(s) to restore from backup set
channel s6: restoring datafile 00012 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undotbs1.273.1153252181
channel s5: restore complete, elapsed time: 00:00:37
channel s5: starting datafile backup set restore
channel s5: using network backup set from service xydb
channel s5: specifying datafile(s) to restore from backup set
channel s5: restoring datafile 00013 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undo_2.277.1153252217
channel s7: restore complete, elapsed time: 00:00:48
channel s7: starting datafile backup set restore
channel s7: using network backup set from service xydb
channel s7: specifying datafile(s) to restore from backup set
channel s7: restoring datafile 00014 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/users.278.1153252229
channel s4: restore complete, elapsed time: 00:01:04
channel s4: starting datafile backup set restore
channel s4: using network backup set from service xydb
channel s4: specifying datafile(s) to restore from backup set
channel s4: restoring datafile 00015 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/system.281.1153652419
channel s8: restore complete, elapsed time: 00:00:45
channel s8: starting datafile backup set restore
channel s8: using network backup set from service xydb
channel s8: specifying datafile(s) to restore from backup set
channel s8: restoring datafile 00016 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/sysaux.280.1153652419
channel s1: restore complete, elapsed time: 00:00:45
channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: specifying datafile(s) to restore from backup set
channel s1: restoring datafile 00017 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undotbs1.279.1153652419
channel s3: restore complete, elapsed time: 00:00:42
channel s3: starting datafile backup set restore
channel s3: using network backup set from service xydb
channel s3: specifying datafile(s) to restore from backup set
channel s3: restoring datafile 00018 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undo_2.283.1153652669
channel s6: restore complete, elapsed time: 00:00:45
channel s7: restore complete, elapsed time: 00:00:18
channel s5: restore complete, elapsed time: 00:00:38
channel s1: restore complete, elapsed time: 00:00:10
channel s2: restore complete, elapsed time: 00:01:42
channel s3: restore complete, elapsed time: 00:00:31
channel s4: restore complete, elapsed time: 00:00:41
channel s8: restore complete, elapsed time: 00:00:35
Finished restore at 2024-01-31 18:24:05

sql statement: alter system archive log current
current log archived

contents of Memory Script:
{
   restore clone force from service  'xydb' 
           archivelog from scn  21315819;
   switch clone datafile all;
}
executing Memory Script

Starting restore at 2024-01-31 18:24:15

channel s1: starting archived log restore to default destination
channel s1: using network backup set from service xydb
channel s1: restoring archived log
archived log thread=1 sequence=396
channel s2: starting archived log restore to default destination
channel s2: using network backup set from service xydb
channel s2: restoring archived log
archived log thread=1 sequence=397
channel s3: starting archived log restore to default destination
channel s3: using network backup set from service xydb
channel s3: restoring archived log
archived log thread=1 sequence=398
channel s4: starting archived log restore to default destination
channel s4: using network backup set from service xydb
channel s4: restoring archived log
archived log thread=2 sequence=372
channel s5: starting archived log restore to default destination
channel s5: using network backup set from service xydb
channel s5: restoring archived log
archived log thread=2 sequence=373
channel s6: starting archived log restore to default destination
channel s6: using network backup set from service xydb
channel s6: restoring archived log
archived log thread=2 sequence=374
channel s1: restore complete, elapsed time: 00:00:01
channel s2: restore complete, elapsed time: 00:00:01
channel s3: restore complete, elapsed time: 00:00:01
channel s4: restore complete, elapsed time: 00:00:01
channel s5: restore complete, elapsed time: 00:00:00
channel s6: restore complete, elapsed time: 00:00:00
Finished restore at 2024-01-31 18:24:17

datafile 1 switched to datafile copy
input datafile copy RECID=5 STAMP=1159727072 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/system.257.1153250631
datafile 3 switched to datafile copy
input datafile copy RECID=6 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/sysaux.258.1153250677
datafile 4 switched to datafile copy
input datafile copy RECID=7 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs1.259.1153250701
datafile 5 switched to datafile copy
input datafile copy RECID=8 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/system.265.1153251113
datafile 6 switched to datafile copy
input datafile copy RECID=9 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/sysaux.266.1153251113
datafile 7 switched to datafile copy
input datafile copy RECID=10 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/users.260.1153250703
datafile 8 switched to datafile copy
input datafile copy RECID=11 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/undotbs1.267.1153251113
datafile 9 switched to datafile copy
input datafile copy RECID=12 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs2.269.1153251451
datafile 10 switched to datafile copy
input datafile copy RECID=13 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/system.274.1153252181
datafile 11 switched to datafile copy
input datafile copy RECID=14 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/sysaux.275.1153252181
datafile 12 switched to datafile copy
input datafile copy RECID=15 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undotbs1.273.1153252181
datafile 13 switched to datafile copy
input datafile copy RECID=16 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undo_2.277.1153252217
datafile 14 switched to datafile copy
input datafile copy RECID=17 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/users.278.1153252229
datafile 15 switched to datafile copy
input datafile copy RECID=18 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/system.281.1153652419
datafile 16 switched to datafile copy
input datafile copy RECID=19 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/sysaux.280.1153652419
datafile 17 switched to datafile copy
input datafile copy RECID=20 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undotbs1.279.1153652419
datafile 18 switched to datafile copy
input datafile copy RECID=21 STAMP=1159727073 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undo_2.283.1153652669

contents of Memory Script:
{
   set until scn  21316738;
   recover
   standby
   clone database
    delete archivelog
   ;
}
executing Memory Script

executing command: SET until clause

Starting recover at 2024-01-31 18:24:18

starting media recovery

archived log for thread 1 with sequence 397 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_397_1153250787.dbf
archived log for thread 1 with sequence 398 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_398_1153250787.dbf
archived log for thread 2 with sequence 373 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_373_1153250787.dbf
archived log for thread 2 with sequence 374 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_374_1153250787.dbf
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_397_1153250787.dbf thread=1 sequence=397
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_373_1153250787.dbf thread=2 sequence=373
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_374_1153250787.dbf thread=2 sequence=374
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_398_1153250787.dbf thread=1 sequence=398
media recovery complete, elapsed time: 00:00:02
Finished recover at 2024-01-31 18:24:23

contents of Memory Script:
{
   delete clone force archivelog all;
}
executing Memory Script

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_396_1153250787.dbf RECID=1 STAMP=1159727071
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_374_1153250787.dbf RECID=6 STAMP=1159727072
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_397_1153250787.dbf RECID=2 STAMP=1159727071
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_398_1153250787.dbf RECID=3 STAMP=1159727071
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_372_1153250787.dbf RECID=4 STAMP=1159727072
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_373_1153250787.dbf RECID=5 STAMP=1159727072
Deleted 1 objects

Finished Duplicate Db at 2024-01-31 18:25:22

released channel: c1

released channel: c2

released channel: c3

released channel: c4

released channel: c5

released channel: c6

released channel: c7

released channel: s1

released channel: s2

released channel: s3

released channel: s4

released channel: s5

released channel: s6

released channel: s7

released channel: s8
released channel: c8

RMAN> 

```



#错误日志

#错误一：onlinelog目录问题导致的错误

#因为online log 目录转换那里，只写了'+DATA'，没有写全路径'+DATA/xydb/onlinelog'，所以在'/u01/app/oracle/oradata/xydbdg/onlinelog'中又创建'/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog'时报错

```bash
[oracle@k8s-rac01 ~]$ rman target sys/Oracle2023#Sys@xydb auxiliary sys/Oracle2023#Sys@xydbdg

Recovery Manager: Release 19.0.0.0.0 - Production on Wed Jan 31 18:02:41 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: XYDB (DBID=2062989406)
connected to auxiliary database: XYDB (not mounted)

RMAN> run {
	allocate channel c1 type disk;
	allocate channel c2 type disk;
	allocate channel c3 type disk;
	allocate channel c4 type disk;
	allocate channel c5 type disk;
	allocate channel c6 type disk;
	allocate channel c7 type disk;
	allocate channel c8 type disk;
	allocate auxiliary channel s1 type disk;
	allocate auxiliary channel s2 type disk;
	allocate auxiliary channel s3 type disk;
	allocate auxiliary channel s4 type disk;
	allocate auxiliary channel s5 type disk;
	allocate auxiliary channel s6 type disk;
	allocate auxiliary channel s7 type disk;
	allocate auxiliary channel s8 type disk;
	duplicate target database
		for standby
		from active database dorecover 
		nofilenamecheck;
	release channel c1;
	release channel c2;
	release channel c3;
	release channel c4;
	release channel c5;
	release channel c6;
	release channel c7;
	release channel s1;
	release channel s2;
	release channel s3;
	release channel s4;	
	release channel s5;
	release channel s6;
	release channel s7;
	release channel s8;	
} 

using target database control file instead of recovery catalog
allocated channel: c1
channel c1: SID=2554 instance=xydb1 device type=DISK

allocated channel: c2
channel c2: SID=575 instance=xydb1 device type=DISK

allocated channel: c3
channel c3: SID=13 instance=xydb2 device type=DISK

allocated channel: c4
channel c4: SID=295 instance=xydb2 device type=DISK

allocated channel: c5
channel c5: SID=863 instance=xydb1 device type=DISK

allocated channel: c6
channel c6: SID=1145 instance=xydb1 device type=DISK

allocated channel: c7
channel c7: SID=1428 instance=xydb1 device type=DISK

allocated channel: c8
channel c8: SID=1705 instance=xydb1 device type=DISK

allocated channel: s1
channel s1: SID=1701 device type=DISK

allocated channel: s2
channel s2: SID=1982 device type=DISK

allocated channel: s3
channel s3: SID=2267 device type=DISK

allocated channel: s4
channel s4: SID=2550 device type=DISK

allocated channel: s5
channel s5: SID=2833 device type=DISK

allocated channel: s6
channel s6: SID=3116 device type=DISK

allocated channel: s7
channel s7: SID=3400 device type=DISK

allocated channel: s8
channel s8: SID=3682 device type=DISK

Starting Duplicate Db at 2024-01-31 18:10:17
current log archived

contents of Memory Script:
{
   backup as copy reuse
   passwordfile auxiliary format  '/u01/app/oracle/product/19.0.0/db_1/dbs/orapwxydbdg'   ;
}
executing Memory Script

Starting backup at 2024-01-31 18:10:20
Finished backup at 2024-01-31 18:10:24

contents of Memory Script:
{
   restore clone from service  'xydb' standby controlfile;
}
executing Memory Script

Starting restore at 2024-01-31 18:10:24

channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: restoring control file
channel s1: restore complete, elapsed time: 00:00:02
output file name=/u01/app/oracle/oradata/xydbdg/control01.ctl
output file name=/u01/app/oracle/fast_recovery_area/xydbdg/control02.ctl
Finished restore at 2024-01-31 18:10:28

contents of Memory Script:
{
   sql clone 'alter database mount standby database';
}
executing Memory Script

sql statement: alter database mount standby database

contents of Memory Script:
{
   set newname for tempfile  1 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809";
   set newname for tempfile  2 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145";
   set newname for tempfile  3 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195";
   set newname for tempfile  4 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445";
   switch clone tempfile all;
   set newname for datafile  1 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/system.257.1153250631";
   set newname for datafile  3 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/sysaux.258.1153250677";
   set newname for datafile  4 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs1.259.1153250701";
   set newname for datafile  5 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/system.265.1153251113";
   set newname for datafile  6 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/sysaux.266.1153251113";
   set newname for datafile  7 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/users.260.1153250703";
   set newname for datafile  8 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/undotbs1.267.1153251113";
   set newname for datafile  9 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs2.269.1153251451";
   set newname for datafile  10 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/system.274.1153252181";
   set newname for datafile  11 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/sysaux.275.1153252181";
   set newname for datafile  12 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undotbs1.273.1153252181";
   set newname for datafile  13 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undo_2.277.1153252217";
   set newname for datafile  14 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/users.278.1153252229";
   set newname for datafile  15 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/system.281.1153652419";
   set newname for datafile  16 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/sysaux.280.1153652419";
   set newname for datafile  17 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undotbs1.279.1153652419";
   set newname for datafile  18 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undo_2.283.1153652669";
   restore
   from  nonsparse   from service 
 'xydb'   clone database
   ;
   sql 'alter system archive log current';
}
executing Memory Script

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

renamed tempfile 1 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809 in control file
renamed tempfile 2 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145 in control file
renamed tempfile 3 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195 in control file
renamed tempfile 4 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445 in control file

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

Starting restore at 2024-01-31 18:10:36

channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: specifying datafile(s) to restore from backup set
channel s1: restoring datafile 00001 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/system.257.1153250631
channel s2: starting datafile backup set restore
channel s2: using network backup set from service xydb
channel s2: specifying datafile(s) to restore from backup set
channel s2: restoring datafile 00003 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/sysaux.258.1153250677
channel s3: starting datafile backup set restore
channel s3: using network backup set from service xydb
channel s3: specifying datafile(s) to restore from backup set
channel s3: restoring datafile 00004 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs1.259.1153250701
channel s4: starting datafile backup set restore
channel s4: using network backup set from service xydb
channel s4: specifying datafile(s) to restore from backup set
channel s4: restoring datafile 00005 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/system.265.1153251113
channel s5: starting datafile backup set restore
channel s5: using network backup set from service xydb
channel s5: specifying datafile(s) to restore from backup set
channel s5: restoring datafile 00006 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/sysaux.266.1153251113
channel s6: starting datafile backup set restore
channel s6: using network backup set from service xydb
channel s6: specifying datafile(s) to restore from backup set
channel s6: restoring datafile 00007 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/users.260.1153250703
channel s7: starting datafile backup set restore
channel s7: using network backup set from service xydb
channel s7: specifying datafile(s) to restore from backup set
channel s7: restoring datafile 00008 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/undotbs1.267.1153251113
channel s8: starting datafile backup set restore
channel s8: using network backup set from service xydb
channel s8: specifying datafile(s) to restore from backup set
channel s8: restoring datafile 00009 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs2.269.1153251451
channel s1: restore complete, elapsed time: 00:00:49
channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: specifying datafile(s) to restore from backup set
channel s1: restoring datafile 00010 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/system.274.1153252181
channel s5: restore complete, elapsed time: 00:00:34
channel s5: starting datafile backup set restore
channel s5: using network backup set from service xydb
channel s5: specifying datafile(s) to restore from backup set
channel s5: restoring datafile 00011 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/sysaux.275.1153252181
channel s6: restore complete, elapsed time: 00:00:32
channel s6: starting datafile backup set restore
channel s6: using network backup set from service xydb
channel s6: specifying datafile(s) to restore from backup set
channel s6: restoring datafile 00012 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undotbs1.273.1153252181
channel s3: restore complete, elapsed time: 00:00:59
channel s3: starting datafile backup set restore
channel s3: using network backup set from service xydb
channel s3: specifying datafile(s) to restore from backup set
channel s3: restoring datafile 00013 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undo_2.277.1153252217
channel s7: restore complete, elapsed time: 00:00:36
channel s7: starting datafile backup set restore
channel s7: using network backup set from service xydb
channel s7: specifying datafile(s) to restore from backup set
channel s7: restoring datafile 00014 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/users.278.1153252229
channel s4: restore complete, elapsed time: 00:01:02
channel s4: starting datafile backup set restore
channel s4: using network backup set from service xydb
channel s4: specifying datafile(s) to restore from backup set
channel s4: restoring datafile 00015 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/system.281.1153652419
channel s8: restore complete, elapsed time: 00:00:38
channel s8: starting datafile backup set restore
channel s8: using network backup set from service xydb
channel s8: specifying datafile(s) to restore from backup set
channel s8: restoring datafile 00016 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/sysaux.280.1153652419
channel s3: restore complete, elapsed time: 00:00:24
channel s3: starting datafile backup set restore
channel s3: using network backup set from service xydb
channel s3: specifying datafile(s) to restore from backup set
channel s3: restoring datafile 00017 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undotbs1.279.1153652419
channel s6: restore complete, elapsed time: 00:00:43
channel s6: starting datafile backup set restore
channel s6: using network backup set from service xydb
channel s6: specifying datafile(s) to restore from backup set
channel s6: restoring datafile 00018 to /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undo_2.283.1153652669
channel s5: restore complete, elapsed time: 00:00:50
channel s7: restore complete, elapsed time: 00:00:43
channel s1: restore complete, elapsed time: 00:01:07
channel s3: restore complete, elapsed time: 00:00:29
channel s4: restore complete, elapsed time: 00:00:49
channel s6: restore complete, elapsed time: 00:00:22
channel s8: restore complete, elapsed time: 00:00:51
channel s2: restore complete, elapsed time: 00:02:25
Finished restore at 2024-01-31 18:13:02

sql statement: alter system archive log current
current log archived

contents of Memory Script:
{
   restore clone force from service  'xydb' 
           archivelog from scn  21312269;
   switch clone datafile all;
}
executing Memory Script

Starting restore at 2024-01-31 18:13:12

channel s1: starting archived log restore to default destination
channel s1: using network backup set from service xydb
channel s1: restoring archived log
archived log thread=1 sequence=392
channel s2: starting archived log restore to default destination
channel s2: using network backup set from service xydb
channel s2: restoring archived log
archived log thread=1 sequence=393
channel s3: starting archived log restore to default destination
channel s3: using network backup set from service xydb
channel s3: restoring archived log
archived log thread=1 sequence=394
channel s4: starting archived log restore to default destination
channel s4: using network backup set from service xydb
channel s4: restoring archived log
archived log thread=2 sequence=370
channel s5: starting archived log restore to default destination
channel s5: using network backup set from service xydb
channel s5: restoring archived log
archived log thread=2 sequence=371
channel s1: restore complete, elapsed time: 00:00:01
channel s2: restore complete, elapsed time: 00:00:01
channel s3: restore complete, elapsed time: 00:00:01
channel s4: restore complete, elapsed time: 00:00:00
channel s5: restore complete, elapsed time: 00:00:01
Finished restore at 2024-01-31 18:13:15

datafile 1 switched to datafile copy
input datafile copy RECID=5 STAMP=1159726410 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/system.257.1153250631
datafile 3 switched to datafile copy
input datafile copy RECID=6 STAMP=1159726410 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/sysaux.258.1153250677
datafile 4 switched to datafile copy
input datafile copy RECID=7 STAMP=1159726410 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs1.259.1153250701
datafile 5 switched to datafile copy
input datafile copy RECID=8 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/system.265.1153251113
datafile 6 switched to datafile copy
input datafile copy RECID=9 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/sysaux.266.1153251113
datafile 7 switched to datafile copy
input datafile copy RECID=10 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/users.260.1153250703
datafile 8 switched to datafile copy
input datafile copy RECID=11 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/86b637b62fe07a65e053f706e80a27ca/datafile/undotbs1.267.1153251113
datafile 9 switched to datafile copy
input datafile copy RECID=12 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs2.269.1153251451
datafile 10 switched to datafile copy
input datafile copy RECID=13 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/system.274.1153252181
datafile 11 switched to datafile copy
input datafile copy RECID=14 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/sysaux.275.1153252181
datafile 12 switched to datafile copy
input datafile copy RECID=15 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undotbs1.273.1153252181
datafile 13 switched to datafile copy
input datafile copy RECID=16 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/undo_2.277.1153252217
datafile 14 switched to datafile copy
input datafile copy RECID=17 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/datafile/users.278.1153252229
datafile 15 switched to datafile copy
input datafile copy RECID=18 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/system.281.1153652419
datafile 16 switched to datafile copy
input datafile copy RECID=19 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/sysaux.280.1153652419
datafile 17 switched to datafile copy
input datafile copy RECID=20 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undotbs1.279.1153652419
datafile 18 switched to datafile copy
input datafile copy RECID=21 STAMP=1159726411 file name=/u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/datafile/undo_2.283.1153652669

contents of Memory Script:
{
   set until scn  21313700;
   recover
   standby
   clone database
    delete archivelog
   ;
}
executing Memory Script

executing command: SET until clause

Starting recover at 2024-01-31 18:13:16

starting media recovery

archived log for thread 1 with sequence 393 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_393_1153250787.dbf
archived log for thread 1 with sequence 394 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_394_1153250787.dbf
archived log for thread 2 with sequence 370 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_370_1153250787.dbf
archived log for thread 2 with sequence 371 is already on disk as file /u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_371_1153250787.dbf
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_393_1153250787.dbf thread=1 sequence=393
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_370_1153250787.dbf thread=2 sequence=370
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_371_1153250787.dbf thread=2 sequence=371
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_394_1153250787.dbf thread=1 sequence=394
media recovery complete, elapsed time: 00:00:01
Finished recover at 2024-01-31 18:13:21

contents of Memory Script:
{
   delete clone force archivelog all;
}
executing Memory Script

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_393_1153250787.dbf RECID=2 STAMP=1159726408
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_392_1153250787.dbf RECID=1 STAMP=1159726408
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_394_1153250787.dbf RECID=3 STAMP=1159726409
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_371_1153250787.dbf RECID=5 STAMP=1159726409
Deleted 1 objects

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_370_1153250787.dbf RECID=4 STAMP=1159726409
Deleted 1 objects

Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_1.262.1153250787'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_2.263.1153250787'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_3.270.1153251915'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_4.271.1153251923'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_10.291.1159637897'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_11.290.1159637907'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_12.289.1159637915'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_13.288.1159637923'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_14.287.1159637933'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Oracle error from auxiliary database: ORA-00344: unable to re-create online log '/u01/app/oracle/oradata/xydbdg/onlinelog/xydb/onlinelog/group_15.286.1159637943'
ORA-27040: file create error, unable to create file
Linux-x86_64 Error: 2: No such file or directory
Additional information: 1

RMAN-05535: warning: All redo log files were not defined properly.
Finished Duplicate Db at 2024-01-31 18:13:23

released channel: c1

released channel: c2

released channel: c3

released channel: c4

released channel: c5

released channel: c6

released channel: c7

released channel: s1

released channel: s2

released channel: s3

released channel: s4

released channel: s5

released channel: s6

released channel: s7

released channel: s8
released channel: c8

RMAN> 

```





#错误二：db_file_name_convert、log_file_name_convert配置错误导致的问题

```bash
[oracle@k8s-rac01 ~]$ rman target sys/Oracle2023#Sys@xydb auxiliary sys/Oracle2023#Sys@xydbdg

Recovery Manager: Release 19.0.0.0.0 - Production on Thu Feb 1 15:45:55 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: XYDB (DBID=2062989406)
connected to auxiliary database: XYDB (not mounted)

RMAN> run {
	allocate channel c1 type disk;
	allocate channel c2 type disk;
	allocate channel c3 type disk;
	allocate channel c4 type disk;
	allocate channel c5 type disk;
	allocate channel c6 type disk;
	allocate channel c7 type disk;
	allocate channel c8 type 2> 3> 4> 5> 6> 7> 8> 9> disk;
	allocate auxiliary channel s1 type disk;
	allocate auxiliary channel s2 type disk;
	allocate auxiliary channel s3 type disk;
	allocate auxiliary channel s4 type disk;
	allocate auxiliary channel s5 type disk;
	allocate auxiliary channel s6 type disk10> 11> 12> 13> 14> 15> ;
	allocate auxiliary channel s7 type disk;
	allocate auxiliary channel s8 type disk;
	duplicate target database
		for standby
		from active database dorecover 
		nofilenamecheck;
	release channel c1;
	release channel c2;
	release channel c3;
	release chan16> 17> 18> 19> 20> 21> 22> 23> 24> 25> nel c4;
	release channel c5;
	release channel c6;
	release channel c7;
	release channel s1;
	release channel s2;
	release channel s3;
	release channel s4;	
	release channel s5;
	release channel s6;
	release channel s7;
	release channel s8;	
}26> 27> 28> 29> 30> 31> 32> 33> 34> 35> 36> 37> 

using target database control file instead of recovery catalog
allocated channel: c1
channel c1: SID=291 instance=xydb1 device type=DISK

allocated channel: c2
channel c2: SID=3403 instance=xydb2 device type=DISK

allocated channel: c3
channel c3: SID=3970 instance=xydb2 device type=DISK

allocated channel: c4
channel c4: SID=4254 instance=xydb2 device type=DISK

allocated channel: c5
channel c5: SID=574 instance=xydb1 device type=DISK

allocated channel: c6
channel c6: SID=1141 instance=xydb1 device type=DISK

allocated channel: c7
channel c7: SID=1424 instance=xydb1 device type=DISK

allocated channel: c8
channel c8: SID=9 instance=xydb2 device type=DISK

allocated channel: s1
channel s1: SID=2267 device type=DISK

allocated channel: s2
channel s2: SID=2550 device type=DISK

allocated channel: s3
channel s3: SID=2833 device type=DISK

allocated channel: s4
channel s4: SID=3116 device type=DISK

allocated channel: s5
channel s5: SID=3400 device type=DISK

allocated channel: s6
channel s6: SID=3682 device type=DISK

allocated channel: s7
channel s7: SID=3966 device type=DISK

allocated channel: s8
channel s8: SID=4248 device type=DISK

Starting Duplicate Db at 2024-02-01 15:46:30
current log archived

contents of Memory Script:
{
   backup as copy reuse
   passwordfile auxiliary format  '/u01/app/oracle/product/19.0.0/db_1/dbs/orapwxydbdg'   ;
}
executing Memory Script

Starting backup at 2024-02-01 15:46:36
Finished backup at 2024-02-01 15:46:40

contents of Memory Script:
{
   restore clone from service  'xydb' standby controlfile;
}
executing Memory Script

Starting restore at 2024-02-01 15:46:40

channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: restoring control file
channel s1: restore complete, elapsed time: 00:00:02
output file name=/u01/app/oracle/oradata/xydbdg/control01.ctl
output file name=/u01/app/oracle/fast_recovery_area/xydbdg/control02.ctl
Finished restore at 2024-02-01 15:46:45

contents of Memory Script:
{
   sql clone 'alter database mount standby database';
}
executing Memory Script

sql statement: alter database mount standby database
Using previous duplicated file /u01/app/oracle/oradata/xydbdg/datafile/system.257.1153250631 for datafile 1 with checkpoint SCN of 21703729
Using previous duplicated file /u01/app/oracle/oradata/xydbdg/datafile/undotbs1.259.1153250701 for datafile 4 with checkpoint SCN of 21703756
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/system.265.1153251113 conflicts with a file used by the target database
RMAN-05529: warning: DB_FILE_NAME_CONVERT resulted in invalid ASM names; names changed to disk group only.
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/sysaux.266.1153251113 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/undotbs1.267.1153251113 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/system.274.1153252181 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/sysaux.275.1153252181 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/undotbs1.273.1153252181 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/undo_2.277.1153252217 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/users.278.1153252229 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/system.281.1153652419 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/sysaux.280.1153652419 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/undotbs1.279.1153652419 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (datafile) file name +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/undo_2.283.1153652669 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (tempfile) file name +DATA/XYDB/0A6C993CC83542D9E063610D12AC4A80/TEMPFILE/temp.268.1153251145 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (tempfile) file name +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/TEMPFILE/temp.276.1153252195 conflicts with a file used by the target database
RMAN-05158: WARNING: auxiliary (tempfile) file name +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/TEMPFILE/temp.282.1153652445 conflicts with a file used by the target database

contents of Memory Script:
{
   set newname for tempfile  1 to 
 "/u01/app/oracle/oradata/xydbdg/tempfile/temp.264.1153250809";
   set newname for tempfile  2 to 
 "+DATA";
   set newname for tempfile  3 to 
 "+DATA";
   set newname for tempfile  4 to 
 "+DATA";
   switch clone tempfile all;
   set newname for datafile  1 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/system.257.1153250631";
   set newname for datafile  3 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/sysaux.258.1153250677";
   set newname for datafile  4 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/undotbs1.259.1153250701";
   set newname for datafile  5 to 
 "+DATA";
   set newname for datafile  6 to 
 "+DATA";
   set newname for datafile  7 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/users.260.1153250703";
   set newname for datafile  8 to 
 "+DATA";
   set newname for datafile  9 to 
 "/u01/app/oracle/oradata/xydbdg/datafile/undotbs2.269.1153251451";
   set newname for datafile  10 to 
 "+DATA";
   set newname for datafile  11 to 
 "+DATA";
   set newname for datafile  12 to 
 "+DATA";
   set newname for datafile  13 to 
 "+DATA";
   set newname for datafile  14 to 
 "+DATA";
   set newname for datafile  15 to 
 "+DATA";
   set newname for datafile  16 to 
 "+DATA";
   set newname for datafile  17 to 
 "+DATA";
   set newname for datafile  18 to 
 "+DATA";
   restore
   from  nonsparse   from service 
 'xydb'   clone datafile
    3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18   ;
   sql 'alter system archive log current';
}
executing Memory Script

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

renamed tempfile 1 to /u01/app/oracle/oradata/xydbdg/tempfile/temp.264.1153250809 in control file
renamed tempfile 2 to +DATA in control file
renamed tempfile 3 to +DATA in control file
renamed tempfile 4 to +DATA in control file

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

Starting restore at 2024-02-01 15:46:53

channel s1: starting datafile backup set restore
channel s1: using network backup set from service xydb
channel s1: specifying datafile(s) to restore from backup set
channel s1: restoring datafile 00003 to /u01/app/oracle/oradata/xydbdg/datafile/sysaux.258.1153250677
channel s2: starting datafile backup set restore
channel s2: using network backup set from service xydb
channel s2: specifying datafile(s) to restore from backup set
channel s2: restoring datafile 00005 to +DATA
channel s3: starting datafile backup set restore
channel s3: using network backup set from service xydb
channel s3: specifying datafile(s) to restore from backup set
channel s3: restoring datafile 00006 to +DATA
channel s4: starting datafile backup set restore
channel s4: using network backup set from service xydb
channel s4: specifying datafile(s) to restore from backup set
channel s4: restoring datafile 00007 to /u01/app/oracle/oradata/xydbdg/datafile/users.260.1153250703
channel s5: starting datafile backup set restore
channel s5: using network backup set from service xydb
channel s5: specifying datafile(s) to restore from backup set
channel s5: restoring datafile 00008 to +DATA
channel s6: starting datafile backup set restore
channel s6: using network backup set from service xydb
channel s6: specifying datafile(s) to restore from backup set
channel s6: restoring datafile 00009 to /u01/app/oracle/oradata/xydbdg/datafile/undotbs2.269.1153251451
channel s7: starting datafile backup set restore
channel s7: using network backup set from service xydb
channel s7: specifying datafile(s) to restore from backup set
channel s7: restoring datafile 00010 to +DATA
channel s8: starting datafile backup set restore
channel s8: using network backup set from service xydb
channel s8: specifying datafile(s) to restore from backup set
channel s8: restoring datafile 00011 to +DATA
dbms_backup_restore.restoreCancel() failed
released channel: c1
released channel: c2
released channel: c3
released channel: c4
released channel: c5
released channel: c6
released channel: c7
released channel: c8
released channel: s1
released channel: s2
released channel: s3
released channel: s4
released channel: s5
released channel: s6
released channel: s7
released channel: s8
RMAN-00571: ===========================================================
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
RMAN-03002: failure of Duplicate Db command at 02/01/2024 15:47:27
RMAN-05501: aborting duplication of target database
RMAN-03015: error occurred in stored script Memory Script
ORA-19660: some files in the backup set could not be verified
ORA-19661: datafile 5 could not be verified due to corrupt blocks
ORA-19849: error while reading backup piece from service xydb
ORA-19504: failed to create file "+DATA"
ORA-17502: ksfdcre:4 Failed to create file +DATA
ORA-15001: diskgroup "DATA" does not exist or is not mounted
ORA-15374: invalid cluster configuration

RMAN> 

RMAN> exit

```



### 2.13.备库open，启动MRP进程

#备库

```sql
select status from v$instance;

show pdbs;

#open前可以检查下tempfile文件路径是否已经存在
#select * from v$tempfile;
#ls -l xxx

alter database open;

ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

#Warning: ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE has been deprecated.
# Oracle 12c 默认启用了实时应用（real-time apply）
#ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

select open_mode from v$database;

show pdbs;

select process,client_process,sequence#, THREAD# ，status from v$managed_standby;

select database_role,protection_mode,protection_level,open_mode from v$database;

select dest_name,status,error from v$archive_dest;
```

#如果经检查备库缺少tempfile，需要手动添加

```sql
select file_name from dba_data_files;

select file_name from dba_temp_files;

alter tablespace temp add tempfile '/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp02.dbf' size 5M autoextend on;

ALTER DATABASE TEMPFILE '/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809' DROP INCLUDING DATAFILES;
```



#或者提前创建好相关目录后，PDB在open过程中会自动创建tempfile

#PORTAL(4):Re-creating tempfile /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445

```bash
mkdir /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/
```

```sql
alter pluggable database all open;

show pdbs;
```





#logs

```sql
SYS@xydbdg> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydbdg>  select open_mode from v$database; 

OPEN_MODE
--------------------
MOUNTED

SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  MOUNTED
	 3 STUWORK			  MOUNTED
	 4 PORTAL			  MOUNTED
	 

SYS@xydbdg> select * from v$tempfile;

     FILE# CREATION_CHANGE# CREATION_TIME	       TS#     RFILE# STATUS  ENABLED	      BYTES	BLOCKS CREATE_BYTES BLOCK_SIZE NAME			         CON_ID
---------- ---------------- ------------------- ---------- ---------- ------- ---------- ---------- ---------- ------------ ---------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------
	 1	    1921095 2023-11-18 19:26:48 	 3	    1 ONLINE  READ WRITE	  0	     0	  184549376	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809															      1
	 2	    2011736 2023-11-18 19:32:25 	 3	    1 ONLINE  READ WRITE	  0	     0	  185597952	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145											      2
	 3	    2163250 2023-11-18 19:49:54 	 3	    1 ONLINE  READ WRITE	  0	     0	  157286400	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195											      3
	 4	    4409979 2023-11-23 11:00:44 	 3	    1 ONLINE  READ WRITE	  0	     0	  185597952	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445											      4

	 
	 
SYS@xydbdg>  alter database open;

Database altered.

SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  MOUNTED
	 4 PORTAL			  MOUNTED
SYS@xydbdg> select status from v$instance;

STATUS
------------
OPEN

SYS@xydbdg>  ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

Database altered.

SYS@xydbdg> select open_mode from v$database;  

OPEN_MODE
--------------------
READ ONLY WITH APPLY

SYS@xydbdg> select process,client_process,sequence#, THREAD# ，status from v$managed_standby;  

PROCESS   CLIENT_P  SEQUENCE#	 THREAD# STATUS
--------- -------- ---------- ---------- ------------
ARCH	  ARCH		    0	       0 CONNECTED
DGRD	  N/A		    0	       0 ALLOCATED
DGRD	  N/A		    0	       0 ALLOCATED
ARCH	  ARCH		    0	       0 CONNECTED
ARCH	  ARCH		    0	       0 CONNECTED
ARCH	  ARCH		    0	       0 CONNECTED
RFS	  Archival	    0	       1 IDLE
RFS	  LGWR		  414	       1 IDLE
RFS	  Archival	    0	       2 IDLE
RFS	  LGWR		  391	       2 IDLE
RFS	  UNKNOWN	    0	       0 IDLE
MRP0	  N/A		  391	       2 APPLYING_LOG

12 rows selected.

SYS@xydbdg>  select database_role,protection_mode,protection_level,open_mode from v$database;  

DATABASE_ROLE	 PROTECTION_MODE      PROTECTION_LEVEL	   OPEN_MODE
---------------- -------------------- -------------------- --------------------
PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  READ ONLY WITH APPLY

SYS@xydbdg> select dest_name,status,error from v$archive_dest;

DEST_NAME																			     STATUS    ERROR
--------------------------------- -----------------------------------------------------------------
LOG_ARCHIVE_DEST_1																		     VALID
LOG_ARCHIVE_DEST_2																		     VALID
LOG_ARCHIVE_DEST_3																		     INACTIVE
LOG_ARCHIVE_DEST_4																		     INACTIVE
LOG_ARCHIVE_DEST_5																		     INACTIVE
LOG_ARCHIVE_DEST_6																		     INACTIVE
LOG_ARCHIVE_DEST_7																		     INACTIVE
LOG_ARCHIVE_DEST_8																		     INACTIVE
LOG_ARCHIVE_DEST_9																		     INACTIVE
LOG_ARCHIVE_DEST_10																		     INACTIVE
LOG_ARCHIVE_DEST_11																		     INACTIVE
LOG_ARCHIVE_DEST_12																		     INACTIVE
LOG_ARCHIVE_DEST_13																		     INACTIVE
LOG_ARCHIVE_DEST_14																		     INACTIVE
LOG_ARCHIVE_DEST_15																		     INACTIVE
LOG_ARCHIVE_DEST_16																		     INACTIVE
LOG_ARCHIVE_DEST_17																		     INACTIVE
LOG_ARCHIVE_DEST_18																		     INACTIVE
LOG_ARCHIVE_DEST_19																		     INACTIVE
LOG_ARCHIVE_DEST_20																		     INACTIVE
LOG_ARCHIVE_DEST_21																		     INACTIVE
LOG_ARCHIVE_DEST_22																		     INACTIVE
LOG_ARCHIVE_DEST_23																		     INACTIVE
LOG_ARCHIVE_DEST_24																		     INACTIVE
LOG_ARCHIVE_DEST_25																		     INACTIVE
LOG_ARCHIVE_DEST_26																		     INACTIVE
LOG_ARCHIVE_DEST_27																		     INACTIVE
LOG_ARCHIVE_DEST_28																		     INACTIVE
LOG_ARCHIVE_DEST_29																		     INACTIVE
LOG_ARCHIVE_DEST_30																		     INACTIVE
LOG_ARCHIVE_DEST_31																		     INACTIVE
STANDBY_ARCHIVE_DEST																		 VALID

32 rows selected.



SYS@xydbdg> select file_name from dba_data_files;

FILE_NAME
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/system.257.1153250631
/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/sysaux.258.1153250677
/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs1.259.1153250701
/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/users.260.1153250703
/u01/app/oracle/oradata/xydbdg/datafile/xydb/datafile/undotbs2.269.1153251451

SYS@xydbdg> select file_name from dba_temp_files;
select file_name from dba_temp_files
                      *
ERROR at line 1:
ORA-01157: cannot identify/lock data file 4097 - see DBWR trace file
ORA-01110: data file 4097: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809'


SYS@xydbdg> alter tablespace temp add tempfile '/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp02.dbf' size 5M autoextend on;

Tablespace altered.

SYS@xydbdg> select file_name from dba_temp_files;
select file_name from dba_temp_files
                      *
ERROR at line 1:
ORA-01157: cannot identify/lock data file 4097 - see DBWR trace file
ORA-01110: data file 4097: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809'


SYS@xydbdg> alter tablespace temp delete^C

SYS@xydbdg> 
SYS@xydbdg> ALTER DATABASE TEMPFILE '/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp.264.1153250809' DROP INCLUDING DATAFILES;

Database altered.

SYS@xydbdg> select file_name from dba_temp_files;

FILE_NAME
-------------------------------------------------------------------------------------------------
/u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp02.dbf

SYS@xydbdg> 

SYS@xydbdg> alter pluggable database all open;

Pluggable database altered.

SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ ONLY  NO
	 4 PORTAL			  READ ONLY  NO

SYS@xydbdg> select * from v$tempfile;

     FILE# CREATION_CHANGE# CREATION_TIME	       TS#     RFILE# STATUS  ENABLED	      BYTES	BLOCKS CREATE_BYTES BLOCK_SIZE NAME			         CON_ID
---------- ---------------- ------------------- ---------- ---------- ------- ---------- ---------- ---------- ------------ ---------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------
	 2	    2011736 2023-11-18 19:32:25 	 3	    1 ONLINE  READ WRITE	  0	     0	  185597952	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145											      2
	 3	    2163250 2023-11-18 19:49:54 	 3	    1 ONLINE  READ WRITE  157286400	 19200	  157286400	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195											      3
	 4	    4409979 2023-11-23 11:00:44 	 3	    1 ONLINE  READ WRITE  185597952	 22656	  185597952	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445											      4
	 5	   21792539 2024-02-01 17:38:49 	 3	    2 ONLINE  READ WRITE    5242880	   640	    5242880	  8192 /u01/app/oracle/oradata/xydbdg/datafile/xydb/tempfile/temp02.dbf 																      1

SYS@xydbdg> !ls -l /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145
ls: cannot access /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145: No such file or directory

SYS@xydbdg> !ls -l /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195
-rw-r----- 1 oracle oinstall 157294592 Feb  1 17:45 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6cd91492ee7956e063620d12ac6018/tempfile/temp.276.1153252195

SYS@xydbdg> !ls -l /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445
-rw-r----- 1 oracle oinstall 185606144 Feb  1 17:45 /u01/app/oracle/oradata/xydbdg/datafile/xydb/0aca091340e201b7e063620d12acbbba/tempfile/temp.282.1153652445

SYS@xydbdg> 

```



### 2.14.主、备库ADG信息查询

```sql
#主库检查adg库状态
select database_role,protection_mode,open_mode,switchover_status from gv$database;

#备库检查adg库状态
select database_role,protection_mode,open_mode,switchover_status from v$database;

#接收归档日志传输序列与应用情况
select sequence#,first_time,next_time,applied from v$archived_log order by sequence#;

#检查日志传输与日志应用进程状态，若是没有mgr进行，则优先检查是否有gap
select role,thread#,sequence#,action from v$dataguard_process;

#检查是否有gap
select thread#,low_sequence#,high_sequence# from v$archive_gap;

#检查lag情况；可判断adg是否有延迟
col name for a23
col value for a13
col time_computed for a20
col datum_time for a20
select name,value,time_computed,datum_time from v$dataguard_stats;

#检查日志接受方式
select process,client_process,sequence#, THREAD# ，status from v$managed_standby;



#在主库进行强制归档

ALTER SYSTEM ARCHIVE LOG CURRENT;

alter system switch logfile;

#检查下两边的日志同步情况

select thread#,sequence#,creator,applied,first_time,next_time from v$archived_log where applied='YES' order by sequence#;

#这里注意，在备库创建之前的redo归档是不会写过来的。
```



#logs

#主库

```sql
SYS@xydb1> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO
SYS@xydb1> SELECT TABLESPACE_NAME, FILE_NAME FROM DBA_TEMP_FILES;

TABLESPACE_NAME 	       FILE_NAME
------------------------------ ------------------------------------------------------------------------
TEMP			       +DATA/XYDB/TEMPFILE/temp.264.1153250809

SYS@xydb1> select database_role,protection_mode,open_mode,switchover_status from gv$database;

DATABASE_ROLE	 PROTECTION_MODE      OPEN_MODE 	   SWITCHOVER_STATUS
---------------- -------------------- -------------------- --------------------
PRIMARY 	 MAXIMUM PERFORMANCE  READ WRITE	   TO STANDBY
PRIMARY 	 MAXIMUM PERFORMANCE  READ WRITE	   TO STANDBY

SYS@xydb1> select sequence#,first_time,next_time,applied from v$archived_log order by sequence#;

 SEQUENCE# FIRST_TIME	       NEXT_TIME	   APPLIED
---------- ------------------- ------------------- ---------
       311 2024-01-18 00:32:20 2024-01-18 19:00:52 NO
       312 2024-01-18 19:00:52 2024-01-19 00:30:08 NO
       313 2024-01-19 00:30:08 2024-01-19 00:30:15 NO
       314 2024-01-19 00:30:15 2024-01-19 00:32:13 NO
       315 2024-01-19 00:32:13 2024-01-19 00:32:18 NO
       316 2024-01-19 00:32:18 2024-01-19 00:32:23 NO
       317 2024-01-19 00:32:23 2024-01-19 22:00:19 NO
       318 2024-01-19 22:00:19 2024-01-20 00:30:06 NO
       319 2024-01-20 00:30:06 2024-01-20 00:30:12 NO
       320 2024-01-20 00:30:12 2024-01-20 00:32:12 NO
       321 2024-01-20 00:32:12 2024-01-20 00:32:18 NO
       322 2024-01-20 00:32:18 2024-01-20 00:32:25 NO
       323 2024-01-20 00:32:25 2024-01-20 10:02:38 NO
       324 2024-01-20 10:02:38 2024-01-21 00:30:06 NO
       325 2024-01-18 00:32:18 2024-01-18 00:32:24 NO
       325 2024-01-21 00:30:06 2024-01-21 00:30:18 NO
       326 2024-01-18 00:32:24 2024-01-18 22:00:42 NO
       326 2024-01-21 00:30:18 2024-01-21 00:32:26 NO
       327 2024-01-18 22:00:42 2024-01-19 00:30:09 NO
       327 2024-01-21 00:32:26 2024-01-21 00:32:32 NO
       328 2024-01-19 00:30:09 2024-01-19 00:30:15 NO
       328 2024-01-21 00:32:32 2024-01-21 00:32:36 NO
       329 2024-01-19 00:30:15 2024-01-19 00:30:22 NO
       329 2024-01-21 00:32:36 2024-01-21 09:00:07 NO
       330 2024-01-19 00:30:22 2024-01-19 00:32:13 NO
       330 2024-01-21 09:00:07 2024-01-22 00:30:08 NO
       331 2024-01-19 00:32:13 2024-01-19 00:32:19 NO
       331 2024-01-22 00:30:08 2024-01-22 00:30:13 NO
       332 2024-01-19 00:32:19 2024-01-19 00:32:22 NO
       332 2024-01-22 00:30:13 2024-01-22 00:32:17 NO
       333 2024-01-19 00:32:22 2024-01-19 23:00:04 NO
       333 2024-01-22 00:32:17 2024-01-22 00:32:21 NO
       334 2024-01-19 23:00:04 2024-01-20 00:30:08 NO
       334 2024-01-22 00:32:21 2024-01-22 00:32:27 NO
       335 2024-01-20 00:30:08 2024-01-20 00:30:14 NO
       335 2024-01-22 00:32:27 2024-01-22 22:07:29 NO
       336 2024-01-20 00:30:14 2024-01-20 00:32:12 NO
       336 2024-01-22 22:07:29 2024-01-23 00:30:05 NO
       337 2024-01-20 00:32:12 2024-01-20 00:32:24 NO
       337 2024-01-23 00:30:05 2024-01-23 00:30:12 NO
       338 2024-01-20 00:32:24 2024-01-20 00:32:27 NO
       338 2024-01-23 00:30:12 2024-01-23 00:32:05 NO
       339 2024-01-20 00:32:27 2024-01-20 18:13:36 NO
       339 2024-01-23 00:32:05 2024-01-23 00:32:13 NO
       340 2024-01-20 18:13:36 2024-01-21 00:30:07 NO
       340 2024-01-23 00:32:13 2024-01-23 00:32:15 NO
       341 2024-01-21 00:30:07 2024-01-21 00:30:19 NO
       341 2024-01-23 00:32:15 2024-01-23 22:00:11 NO
       342 2024-01-21 00:30:19 2024-01-21 00:30:22 NO
       342 2024-01-23 22:00:11 2024-01-24 00:30:06 NO
       343 2024-01-21 00:30:22 2024-01-21 00:32:26 NO
       343 2024-01-24 00:30:06 2024-01-24 00:30:13 NO
       344 2024-01-21 00:32:26 2024-01-21 00:32:35 NO
       344 2024-01-24 00:30:13 2024-01-24 00:32:10 NO
       345 2024-01-21 00:32:35 2024-01-21 00:32:38 NO
       345 2024-01-24 00:32:10 2024-01-24 00:32:19 NO
       346 2024-01-21 00:32:38 2024-01-21 14:06:46 NO
       346 2024-01-24 00:32:19 2024-01-24 00:32:23 NO
       347 2024-01-21 14:06:46 2024-01-22 00:30:07 NO
       347 2024-01-24 00:32:23 2024-01-24 20:00:26 NO
       348 2024-01-22 00:30:07 2024-01-22 00:30:16 NO
       348 2024-01-24 20:00:26 2024-01-24 22:09:42 NO
       349 2024-01-22 00:30:16 2024-01-22 00:32:16 NO
       349 2024-01-24 22:09:42 2024-01-25 00:30:06 NO
       350 2024-01-22 00:32:16 2024-01-22 00:32:26 NO
       350 2024-01-25 00:30:06 2024-01-25 00:30:13 NO
       351 2024-01-22 00:32:26 2024-01-22 00:32:29 NO
       351 2024-01-25 00:30:13 2024-01-25 00:32:15 NO
       352 2024-01-22 00:32:29 2024-01-22 20:00:26 NO
       352 2024-01-25 00:32:15 2024-01-25 00:32:20 NO
       353 2024-01-22 20:00:26 2024-01-23 00:30:06 NO
       353 2024-01-25 00:32:20 2024-01-25 00:32:25 NO
       354 2024-01-23 00:30:06 2024-01-23 00:30:12 NO
       354 2024-01-25 00:32:25 2024-01-25 22:00:19 NO
       355 2024-01-23 00:30:12 2024-01-23 00:32:06 NO
       355 2024-01-25 22:00:19 2024-01-26 00:30:06 NO
       356 2024-01-26 00:30:06 2024-01-26 00:30:16 NO
       356 2024-01-23 00:32:06 2024-01-23 00:32:12 NO
       357 2024-01-26 00:30:16 2024-01-26 00:32:06 NO
       357 2024-01-23 00:32:12 2024-01-23 00:32:16 NO
       358 2024-01-26 00:32:06 2024-01-26 00:32:14 NO
       358 2024-01-23 00:32:16 2024-01-23 20:00:25 NO
       359 2024-01-26 00:32:14 2024-01-26 00:32:20 NO
       359 2024-01-23 20:00:25 2024-01-24 00:30:07 NO
       360 2024-01-26 00:32:20 2024-01-26 22:01:39 NO
       360 2024-01-24 00:30:07 2024-01-24 00:30:13 NO
       361 2024-01-26 22:01:39 2024-01-26 22:01:40 NO
       361 2024-01-24 00:30:13 2024-01-24 00:32:10 NO
       362 2024-01-30 14:24:11 2024-01-31 00:30:08 NO
       362 2024-01-24 00:32:10 2024-01-24 00:32:19 NO
       363 2024-01-31 00:30:08 2024-01-31 00:30:11 NO
       363 2024-01-24 00:32:19 2024-01-24 00:32:23 NO
       364 2024-01-31 00:30:11 2024-01-31 00:32:41 NO
       364 2024-01-24 00:32:23 2024-01-24 20:00:25 NO
       365 2024-01-31 00:32:41 2024-01-31 00:32:47 NO
       365 2024-01-24 20:00:25 2024-01-25 00:30:08 NO
       366 2024-01-31 00:32:47 2024-01-31 00:32:54 NO
       366 2024-01-25 00:30:08 2024-01-25 00:30:14 NO
       367 2024-01-31 00:32:54 2024-01-31 14:00:46 NO
       367 2024-01-25 00:30:14 2024-01-25 00:32:15 NO
       368 2024-01-31 14:00:46 2024-01-31 17:10:44 NO
       368 2024-01-25 00:32:15 2024-01-25 00:32:24 NO
       369 2024-01-31 17:10:44 2024-01-31 18:10:17 NO
       369 2024-01-25 00:32:24 2024-01-25 00:32:30 NO
       370 2024-01-31 18:10:17 2024-01-31 18:13:04 NO
       370 2024-01-25 00:32:30 2024-01-26 00:30:06 NO
       371 2024-01-31 18:13:04 2024-01-31 18:13:10 NO
       371 2024-01-26 00:30:06 2024-01-26 00:30:16 NO
       372 2024-01-31 18:13:10 2024-01-31 18:21:54 NO
       372 2024-01-26 00:30:16 2024-01-26 00:32:07 NO
       373 2024-01-31 18:21:54 2024-01-31 18:24:07 NO
       373 2024-01-26 00:32:07 2024-01-26 00:32:16 NO
       374 2024-01-31 18:24:07 2024-01-31 18:24:13 NO
       374 2024-01-26 00:32:16 2024-01-26 00:32:19 NO
       375 2024-01-31 18:24:13 2024-02-01 00:30:07 YES
       375 2024-01-26 00:32:19 2024-01-26 22:01:51 NO
       375 2024-01-31 18:24:13 2024-02-01 00:30:07 NO
       376 2024-02-01 00:30:07 2024-02-01 00:30:11 YES
       376 2024-01-26 22:01:51 2024-01-27 02:12:51 NO
       376 2024-02-01 00:30:07 2024-02-01 00:30:11 NO
       377 2024-02-01 00:30:11 2024-02-01 00:32:13 NO
       377 2024-01-27 02:12:51 2024-01-27 14:00:16 NO
       377 2024-02-01 00:30:11 2024-02-01 00:32:13 YES
       378 2024-02-01 00:32:13 2024-02-01 00:32:18 NO
       378 2024-01-27 14:00:16 2024-01-27 22:19:57 NO
       378 2024-02-01 00:32:13 2024-02-01 00:32:18 YES
       379 2024-02-01 00:32:18 2024-02-01 00:32:23 NO
       379 2024-01-27 22:19:57 2024-01-28 06:10:23 NO
       379 2024-02-01 00:32:18 2024-02-01 00:32:23 YES
       380 2024-02-01 00:32:23 2024-02-01 14:00:01 YES
       380 2024-01-28 06:10:23 2024-01-28 18:02:28 NO
       380 2024-02-01 00:32:23 2024-02-01 14:00:01 NO
       381 2024-01-28 18:02:28 2024-01-28 22:49:44 NO
       381 2024-02-01 14:00:01 2024-02-01 15:35:16 NO
       382 2024-01-28 22:49:44 2024-01-29 18:00:12 NO
       382 2024-02-01 15:35:16 2024-02-01 15:42:15 NO
       383 2024-01-29 18:00:12 2024-01-30 05:00:27 NO
       383 2024-02-01 15:42:15 2024-02-01 15:46:33 NO
       384 2024-01-30 05:00:27 2024-01-30 12:00:41 NO
       384 2024-02-01 15:46:33 2024-02-01 16:05:44 NO
       385 2024-01-30 12:00:41 2024-01-30 22:49:55 NO
       385 2024-02-01 16:05:44 2024-02-01 16:17:10 NO
       386 2024-01-30 22:49:55 2024-01-31 00:30:07 NO
       386 2024-02-01 16:17:10 2024-02-01 16:21:14 NO
       387 2024-01-31 00:30:07 2024-01-31 00:30:17 NO
       387 2024-02-01 16:21:14 2024-02-01 16:28:41 NO
       388 2024-01-31 00:30:17 2024-01-31 00:32:41 NO
       388 2024-02-01 16:28:41 2024-02-01 16:32:29 NO
       389 2024-01-31 00:32:41 2024-01-31 00:32:50 NO
       389 2024-02-01 16:32:29 2024-02-01 16:34:30 NO
       390 2024-02-01 16:34:30 2024-02-01 16:34:36 NO
       390 2024-01-31 00:32:50 2024-01-31 00:32:56 NO
       390 2024-02-01 16:34:30 2024-02-01 16:34:36 YES
       391 2024-01-31 00:32:56 2024-01-31 17:10:43 NO
       392 2024-01-31 17:10:43 2024-01-31 18:10:18 NO
       393 2024-01-31 18:10:18 2024-01-31 18:13:04 NO
       394 2024-01-31 18:13:04 2024-01-31 18:13:10 YES
       394 2024-01-31 18:13:04 2024-01-31 18:13:10 NO
       395 2024-01-31 18:13:10 2024-01-31 18:21:54 NO
       396 2024-01-31 18:21:54 2024-01-31 18:22:00 NO
       397 2024-01-31 18:22:00 2024-01-31 18:24:07 NO
       398 2024-01-31 18:24:07 2024-01-31 18:24:13 NO
       398 2024-01-31 18:24:07 2024-01-31 18:24:13 NO
       399 2024-01-31 18:24:13 2024-02-01 00:30:06 NO
       399 2024-01-31 18:24:13 2024-02-01 00:30:06 NO
       400 2024-02-01 00:30:06 2024-02-01 00:30:15 NO
       400 2024-02-01 00:30:06 2024-02-01 00:30:15 NO
       401 2024-02-01 00:30:15 2024-02-01 00:32:13 NO
       401 2024-02-01 00:30:15 2024-02-01 00:32:13 NO
       402 2024-02-01 00:32:13 2024-02-01 00:32:22 NO
       402 2024-02-01 00:32:13 2024-02-01 00:32:22 NO
       403 2024-02-01 00:32:22 2024-02-01 00:32:25 NO
       403 2024-02-01 00:32:22 2024-02-01 00:32:25 NO
       404 2024-02-01 00:32:25 2024-02-01 15:35:19 NO
       405 2024-02-01 15:35:19 2024-02-01 15:42:21 NO
       406 2024-02-01 15:42:21 2024-02-01 15:46:34 NO
       407 2024-02-01 15:46:34 2024-02-01 16:05:45 NO
       408 2024-02-01 16:05:45 2024-02-01 16:17:11 NO
       409 2024-02-01 16:17:11 2024-02-01 16:21:13 NO
       410 2024-02-01 16:21:13 2024-02-01 16:28:42 NO
       411 2024-02-01 16:28:42 2024-02-01 16:32:27 NO
       412 2024-02-01 16:32:27 2024-02-01 16:34:30 NO
       413 2024-02-01 16:34:30 2024-02-01 16:34:33 NO

183 rows selected.

SYS@xydb1> select role,thread#,sequence#,action from v$dataguard_process;

ROLE			    THREAD#  SEQUENCE# ACTION
------------------------ ---------- ---------- ------------
log writer			  0	     0 IDLE
redo transport monitor		  0	     0 IDLE
gap manager			  1	   414 IDLE
redo transport timer		  0	     0 IDLE
archive local			  0	     0 IDLE
archive redo			  0	     0 IDLE
archive redo			  0	     0 IDLE
archive redo			  0	     0 IDLE
async ORL multi 		  1	   414 OPENING
heartbeat redo informer 	  0	     0 IDLE
async ORL single		  1	   414 WRITING

11 rows selected.

SYS@xydb1> select thread#,low_sequence#,high_sequence# from v$archive_gap;

no rows selected

SYS@xydb1> col name for a23
col value for a13
col time_computed for a20
col datum_time for a20
select name,value,time_computed,datum_time from v$dataguard_stats;SYS@xydb1> SYS@xydb1> SYS@xydb1> SYS@xydb1> 

no rows selected


SYS@xydb1> select process,client_process,sequence#, THREAD# ，status from v$managed_standby;

PROCESS   CLIENT_P  SEQUENCE#	 THREAD# STATUS
--------- -------- ---------- ---------- ------------
DGRD	  N/A		    0	       0 ALLOCATED
ARCH	  ARCH		  410	       1 CLOSING
DGRD	  N/A		    0	       0 ALLOCATED
ARCH	  ARCH		    0	       0 CONNECTED
ARCH	  ARCH		    0	       0 CONNECTED
ARCH	  ARCH		    0	       0 CONNECTED
LNS	  LNS		  411	       1 OPENING
DGRD	  N/A		    0	       0 ALLOCATED
LNS	  LNS		  414	       1 WRITING

9 rows selected.

SYS@xydb1> 

SYS@xydb1> ALTER SYSTEM ARCHIVE LOG CURRENT;

System altered.

SYS@xydb1> alter system switch logfile;

System altered.

SYS@xydb1> select thread#,sequence#,creator,applied,first_time,next_time from v$archived_log where applied='YES' order by sequence#;

   THREAD#  SEQUENCE# CREATOR APPLIED	FIRST_TIME	    NEXT_TIME
---------- ---------- ------- --------- ------------------- -------------------
	 2	  375 LGWR    YES	2024-01-31 18:24:13 2024-02-01 00:30:07
	 2	  376 LGWR    YES	2024-02-01 00:30:07 2024-02-01 00:30:11
	 2	  377 LGWR    YES	2024-02-01 00:30:11 2024-02-01 00:32:13
	 2	  378 LGWR    YES	2024-02-01 00:32:13 2024-02-01 00:32:18
	 2	  379 LGWR    YES	2024-02-01 00:32:18 2024-02-01 00:32:23
	 2	  380 LGWR    YES	2024-02-01 00:32:23 2024-02-01 14:00:01
	 2	  390 ARCH    YES	2024-02-01 16:34:30 2024-02-01 16:34:36
	 1	  394 ARCH    YES	2024-01-31 18:13:04 2024-01-31 18:13:10

8 rows selected.

SYS@xydb1> 

```





#备库

```sql
SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ ONLY  NO
	 4 PORTAL			  READ ONLY  NO


SYS@xydbdg> select database_role,protection_mode,open_mode,switchover_status from v$database;

DATABASE_ROLE	 PROTECTION_MODE      OPEN_MODE 	   SWITCHOVER_STATUS
---------------- -------------------- -------------------- --------------------
PHYSICAL STANDBY MAXIMUM PERFORMANCE  READ ONLY WITH APPLY NOT ALLOWED

SYS@xydbdg> select database_role,protection_mode,open_mode,switchover_status from v$database;

DATABASE_ROLE	 PROTECTION_MODE      OPEN_MODE 	   SWITCHOVER_STATUS
---------------- -------------------- -------------------- --------------------
PHYSICAL STANDBY MAXIMUM PERFORMANCE  READ ONLY WITH APPLY NOT ALLOWED

SYS@xydbdg> select sequence#,first_time,next_time,applied from v$archived_log order by sequence#;

 SEQUENCE# FIRST_TIME	       NEXT_TIME	   APPLIED
---------- ------------------- ------------------- ---------
       388 2024-02-01 16:28:41 2024-02-01 16:32:29 NO
       389 2024-02-01 16:32:29 2024-02-01 16:34:30 YES
       390 2024-02-01 16:34:30 2024-02-01 16:34:36 YES
       390 2024-02-01 16:34:30 2024-02-01 16:34:36 NO
       412 2024-02-01 16:32:27 2024-02-01 16:34:30 YES
       413 2024-02-01 16:34:30 2024-02-01 16:34:33 YES

6 rows selected.

SYS@xydbdg> select role,thread#,sequence#,action from v$dataguard_process;

ROLE			    THREAD#  SEQUENCE# ACTION
------------------------ ---------- ---------- ------------
redo transport monitor		  0	     0 IDLE
log writer			  0	     0 IDLE
gap manager			  0	     0 IDLE
redo transport timer		  0	     0 IDLE
archive local			  0	     0 IDLE
archive redo			  0	     0 IDLE
archive redo			  0	     0 IDLE
archive redo			  0	     0 IDLE
RFS ping			  1	   414 IDLE
RFS async			  1	   414 IDLE
RFS ping			  2	   391 IDLE
RFS async			  2	   391 IDLE
RFS archive			  0	     0 IDLE
managed recovery		  0	     0 IDLE
recovery logmerger		  2	   391 APPLYING_LOG
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE
recovery apply slave		  0	     0 IDLE

31 rows selected.

SYS@xydbdg> select thread#,low_sequence#,high_sequence# from v$archive_gap;

no rows selected

SYS@xydbdg> col name for a23
col value for a13
col time_computed for a20
col datum_time for a20
select name,value,time_computed,datum_time from v$dataguard_stats;SYS@xydbdg> SYS@xydbdg> SYS@xydbdg> SYS@xydbdg> 

NAME			VALUE	      TIME_COMPUTED	   DATUM_TIME
----------------------- ------------- -------------------- --------------------
transport lag		+00 00:00:00  02/01/2024 17:59:33  02/01/2024 17:59:31
apply lag		+00 00:00:00  02/01/2024 17:59:33  02/01/2024 17:59:31
apply finish time	+00 00:00:00. 02/01/2024 17:59:33
			000

estimated startup time	31	      02/01/2024 17:59:33

SYS@xydbdg> 

SYS@xydbdg>  select thread#,sequence#,creator,applied,first_time,next_time from v$archived_log where applied='YES' order by sequence#;

   THREAD#  SEQUENCE# CREATOR APPLIED	FIRST_TIME	    NEXT_TIME
---------- ---------- ------- --------- ------------------- -------------------
	 2	  389 SRMN    YES	2024-02-01 16:32:29 2024-02-01 16:34:30
	 2	  390 ARCH    YES	2024-02-01 16:34:30 2024-02-01 16:34:36
	 1	  412 SRMN    YES	2024-02-01 16:32:27 2024-02-01 16:34:30
	 1	  413 SRMN    YES	2024-02-01 16:34:30 2024-02-01 16:34:33

SYS@xydbdg> 


```



## 3.测试

### 3.0.主备同步测试

#主库操作

```sql
show pdbs;
alter session set contaienr=portal;

--创建用户

create user dgtest identified by oracle;

grant dba to dgtest;


--创建表

create table dgtest (
       id number(9) not null primary key,
       classname varchar2(40) not null
       );

	   
insert into dgtest values(28,'class one');

commit;


--sys用户：

insert into dgtest values(27,'sys one');


--dgtest用户：

insert into dgtest values(29,'detest one');

```



#备库查询

```sql
select * from sys.dgtest;

select * from dgtest.dgtest;
```



#主库清理

```sql
#drop tablespace dgtest including contents and datafiles;

drop user dgtest cascade;
```



#logs

#主库

```sql
SYS@xydb1> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO

SYS@xydb1> alter session set container=portal;

Session altered.

SYS@xydb1> create user dgtest identified by oracle;

User created.

SYS@xydb1> grant dba to dgtest;

Grant succeeded.

SYS@xydb1> exit


[oracle@k8s-rac01 ~]$ sqlplus dgtest/oracle@rac-scan:1521/s_portal

SQL*Plus: Release 19.0.0.0.0 - Production on Thu Feb 1 21:23:06 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

DGTEST@rac-scan:1521/s_portal> create table dgtest (
       id number(9) not null primary key,
       classname varchar2(40) not null
       );  

Table created.

DGTEST@rac-scan:1521/s_portal> insert into dgtest values(28,'class one');

1 row created.

DGTEST@rac-scan:1521/s_portal> commit;

Commit complete.

DGTEST@rac-scan:1521/s_portal> insert into dgtest values(29,'detest one');

1 row created.

DGTEST@rac-scan:1521/s_portal> commit;

Commit complete.

DGTEST@rac-scan:1521/s_portal> 

```



#备库

```sql
SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ ONLY  NO
	 4 PORTAL			  READ ONLY  NO
SYS@xydbdg> alter session set container=portal;

Session altered.

SYS@xydbdg> select * from dgtest.dgtest;

	ID CLASSNAME
---------- ----------------------------------------
	28 class one
	29 detest one

SYS@xydbdg> 

```





### 3.1.ADG做switchover切换测试









### 3.2.ADG做failover切换测试





## 4.配置dg_broker



