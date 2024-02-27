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
#如果主库中有pdb，那么这里也必须添加

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
    
      (SID_DESC =
      (GLOBAL_DBNAME = portal)
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
select name,role,instance,thread#,sequence#,action from gv$dataguard_process;



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





### 3.1.ADG做手动switchover切换测试

#### 3.1.0.switchover_status概念

```
A 如果switchover_status为TO_PRIMARY 说明标记恢复可以直接转换为primary库;
  alter database commit to switchover to primary ；

B 如果switchover_status为SESSION ACTIVE 就应该断开活动会话
alter database commit to switchover to primary with session shutdown; 

C 如果switchover_status为NOT ALLOWED 说明切换标记还没收到，此时不能执行转换。

D、状态由LOG SWITCH GAP变成了RESOLVABLE GAP，从字面理解是主备库之间存在GAP，于是执行： alter system switch logfile；手动切换归档即可（LLL）

E、当主库的SWITCHOVER_STATUS状态为FAILED DESTINATION时，是因为备库不在mount状态下，在备库中：startup mount

F、当主库的SWITCHOVER_STATUS状态为RESOLVABLE GAP时，可以shutdown和startup备库，问题可解决。



---------------------------------------

The switchover_status column of v$database can have the following values:

Not Allowed:-Either this is a standby database and the primary database has not been switched first, or this is a primary database and there are no standby databases

Session Active:- Indicates that there are active SQL sessions attached to the primary or standby database that need to be disconnected before the switchover operation is permitted

Switchover Pending:- This is a standby database and the primary database switchover request has been received but not processed.

Switchover Latent:- The switchover was in pending mode, but did not complete and went back to the primary database

To Primary:- This is a standby database, with no active sessions, that is allowed to switch over to a primary database

To Standby:- This is a primary database, with no active sessions, that is allowed to switch over to a standby database

Recovery Needed:- This is a standby database that has not received the switchover request
```



#### 3.1.1.主备切换---通过11g adg命令

##### 3.1.1.1.原主库操作

```sql
#查看当前库的状态
select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

#查看库的角色，和可以切换到的角色
select database_role,switchover_status from gv$database;

alter system archive log current;

#对主库进行切换，rac集群关闭第二个节点(也可以不关闭)。（如果SWITCHOVER_STATUS的值为TO STANDBY或者为SESSIONS ACTIVE都可以切换至备库）
alter database commit to switchover to physical standby with session shutdown;

#此时原主库的两个实例都关闭了
ps -x
srvctl status database -d xydb


#等待原备库切换为主库后(状态为FAILED DESTINATION)
srvctl start database -d xydb

srvctl status database -d xydb

select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

#此时原主库状态为READ ONLY/RECOVERY NEEDED

#原主库开启实时查询同步
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

#此时原主库状态为READ ONLY/NOT ALLOWED

select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

select process,client_process,sequence#, THREAD# ，status from v$managed_standby;
```



#logs

```sql
SYS@xydb1> select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     PROTECTION_MODE	  PROTECTION_LEVEL     SWITCHOVER_STATUS
-------------------- -------------------- -------------------- --------------------
READ WRITE	     MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  TO STANDBY

SYS@xydb1> select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     PROTECTION_MODE	  PROTECTION_LEVEL     SWITCHOVER_STATUS
-------------------- -------------------- -------------------- --------------------
READ WRITE	     MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  TO STANDBY
READ WRITE	     MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  TO STANDBY

SYS@xydb1> select database_role,switchover_status from v$database;

DATABASE_ROLE	 SWITCHOVER_STATUS
---------------- --------------------
PRIMARY 	 TO STANDBY

SYS@xydb1> select database_role,switchover_status from gv$database;

DATABASE_ROLE	 SWITCHOVER_STATUS
---------------- --------------------
PRIMARY 	 TO STANDBY
PRIMARY 	 TO STANDBY

SYS@xydb1> 

#开始切换
SYS@xydb1> alter database commit to  switchover to physical standby with session shutdown;

Database altered.

SYS@xydb1> select status from v$instance;
select status from v$instance
*
ERROR at line 1:
ORA-01034: ORACLE not available
Process ID: 26706
Session ID: 1989 Serial number: 60268

SYS@xydb1> exit

[oracle@k8s-rac01 ~]$ ps -x
  PID TTY      STAT   TIME COMMAND
11101 pts/0    S+     0:00 sqlplus   as sysdba
11102 ?        Ss     0:00 oraclexydb1 (DESCRIPTION=(LOCAL=YES)(ADDRESS=(PROTOCOL=beq)))
20751 pts/1    S      0:00 -bash
21765 pts/1    R+     0:00 ps -x
26536 pts/0    S      0:00 -bash

[oracle@k8s-rac01 ~]$ srvctl status database -d xydb
Instance xydb1 is not running on node k8s-rac01
Instance xydb2 is not running on node k8s-rac02

#原备库切换为主库后
[oracle@k8s-rac01 ~]$ srvctl start database -d xydb
[oracle@k8s-rac01 ~]$ srvctl status database -d xydb
Instance xydb1 is running on node k8s-rac01
Instance xydb2 is running on node k8s-rac02
[oracle@k8s-rac01 ~]$ 

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY	     PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	RECOVERY NEEDED
READ ONLY	     PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	RECOVERY NEEDED

#开启同步
SYS@xydb1> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

Database altered.

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED

SYS@xydb1> 


```





##### 3.1.1.2.原备库操作

```sql
select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

#查看备库是否可以切换至主库（SWITCHOVER_STATUS的值为TO PRIMARY或者SESSIONS ACTIVE都可以切换至主库）
select switchover_status from v$database;

#将备库切换到主库并打开
ALTER DATABASE COMMIT TO SWITCHOVER TO PRIMARY WITH SESSION SHUTDOWN;

#此时原备库状态为mounted/not allowed

select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

#变更为Open状态
alter database open;

#此时原备库状态为READ WRITE/FAILED DESTINATION

#原主库此时再次startup后

#此时原备库状态为READ WRITE/TO STANDBY

#查看切换完成后的状态
select open_mode,database_role,switchover_status from v$database;
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

#查看pdb
show pdbs;

alter pluggable database  all open;
show pdbs;
```



#logs

```sql
#主库切换前
SYS@xydbdg> select switchover_status from v$database;

SWITCHOVER_STATUS
--------------------
NOT ALLOWED

SYS@xydbdg> select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     PROTECTION_MODE	  PROTECTION_LEVEL     SWITCHOVER_STATUS
-------------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  NOT ALLOWED

SYS@xydbdg> 

#主库切换后
SYS@xydbdg> select switchover_status from v$database;

SWITCHOVER_STATUS
--------------------
TO PRIMARY

SYS@xydbdg> select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     PROTECTION_MODE	  PROTECTION_LEVEL     SWITCHOVER_STATUS
-------------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  TO PRIMARY


#原备库切换为主库
SYS@xydbdg> alter database commit to switchover to primary with session shutdown;

Database altered.

SYS@xydbdg> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydbdg> select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     PROTECTION_MODE	  PROTECTION_LEVEL     SWITCHOVER_STATUS
-------------------- -------------------- -------------------- --------------------
MOUNTED 	     MAXIMUM PERFORMANCE  UNPROTECTED	       NOT ALLOWED

SYS@xydbdg> alter database open;

Database altered.

SYS@xydbdg> 
SYS@xydbdg> select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     PROTECTION_MODE	  PROTECTION_LEVEL     SWITCHOVER_STATUS
-------------------- -------------------- -------------------- --------------------
READ WRITE	     MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  FAILED DESTINATION

SYS@xydbdg> 

#原主库再次startup后
SYS@xydbdg>  select OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     PROTECTION_MODE	  PROTECTION_LEVEL     SWITCHOVER_STATUS
-------------------- -------------------- -------------------- --------------------
READ WRITE	     MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  TO STANDBY

SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY

SYS@xydbdg> 

#查看pdb并启动
SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  MOUNTED
	 4 PORTAL			  MOUNTED
SYS@xydbdg> alter pluggable database all open;

Pluggable database altered.

SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO
SYS@xydbdg> 

```





##### 3.1.1.3.新主备检查

#检查状态

```sql
#新主库，即原备库
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

#原主库，即新备库
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;
```



#创建pdb及数据进行测试

#创建pdb

```oracle
create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba) FILE_NAME_CONVERT = ('+DATA', '/u01/app/oracle/oradata/xydbdg');

alter pluggable database dataassets open;
alter pluggable database all save state instances=all;



alter session set container=dataassets;

create tablespace pdb1user datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

alter tablespace pdb1user add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create user user1 identified by user1 default tablespace pdb1user account unlock;

grant dba to user1;
grant select any table to user1;
```
#连接方式
```bash
srvctl add service -d xydb -s s_dataassets -r xydb1,xydb2,xydb3 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets

srvctl start service -d xydb -s s_dataassets
srvctl status service -d xydb -s s_dataassets

sqlplus pdbadmin/J3my3xl4c12ed@172.16.134.9:1521/s_dataassets
```



#logs

#检查状态

```sql
#新主库
SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY



#原主库
SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED


```



#新主库创建pdb测试

```sql
SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO
SYS@xydbdg> create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba);
create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba)
                                                                                        *
ERROR at line 1:
ORA-65016: FILE_NAME_CONVERT must be specified



SYS@xydbdg> create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba) FILE_NAME_CONVERT = ('+DATA', '/u01/app/oracle/oradata/xydbdg');
create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba) FILE_NAME_CONVERT = ('+DATA', '/u01/app/oracle/oradata/xydbdg')
*
ERROR at line 1:
ORA-19505: failed to identify file "/u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/temp.268.1153251145"
ORA-27037: unable to obtain file status
Linux-x86_64 Error: 2: No such file or directory
Additional information: 7


#此时发现是pdb$seed的临时文件没有在原备库创建，先创建其目录，然后重启原备库(先主库)后，自动生成该tempfile
SYS@xydbdg> !mkdir -p /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/

SYS@xydbdg> shutdown immediate;
Database closed.
Database dismounted.
ORACLE instance shut down.


SYS@xydbdg> startup;
ORACLE instance started.

Total System Global Area 1.6106E+10 bytes
Fixed Size		   18625040 bytes
Variable Size		 2181038080 bytes
Database Buffers	 1.3892E+10 bytes
Redo Buffers		   14925824 bytes
Database mounted.
Database opened.
SYS@xydbdg> 

SYS@xydbdg> !ls -l /u01/app/oracle/oradata/xydbdg/datafile/xydb/0a6c993cc83542d9e063610d12ac4a80/tempfile/
total 1024
-rw-r----- 1 oracle oinstall 185606144 Feb  2 17:36 temp.268.1153251145

SYS@xydbdg> 



```







#### 3.1.2.主备再次切换-通过19c adg命令

##### 3.1.2.1.切换操作

```sql
#当前主库是单实例xydbdg，备库是rac库xydb

#查看当前主库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

#查看当备库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;


#主库执行切换
alter database switchover to xydb verify;
alter database switchover to xydb;

#执行命令之后，原主库xydbdg将会关闭，原备库xydb会重新启动到mount状态，且变成新主库角色；
#此时需要手工在新主库xydb上执行命令，打开数据库，k8s-rac01/k8s-rac02都需要执行
alter database open;


#然后手工将原主库xydbdg进行startup，承担新备库角色，并开启实时应用：
startup
recover managed standby database disconnect;

#注意：19c ADG 在未配置DG Broker的情况下，也很简单实现了主备角色互换，只需手工处理下开库的动作。
#此外，与11g ADG不同，现在MRP进程默认就是开启实时应用（前提是准备工作做好），也就是说：

#备库MRP实时开启默认无需指定 using current logfile 关键字。
#默认即是，如果不想实时，指定 using archived logfile 关键字。



#查看当前主库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

#查看当备库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

select process,client_process,sequence#, THREAD# ，status from v$managed_standby;
```



#logs

```sql
#主库状态
SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY

#备库状态
SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED

#主库执行切换
SYS@xydbdg> alter database switchover to xydb verify;

Database altered.

SYS@xydbdg> alter database switchover to xydb;

Database altered.

SYS@xydbdg> select instance_status from v$instance;
select instance_status from v$instance
*
ERROR at line 1:
ORA-01034: ORACLE not available
Process ID: 13294
Session ID: 2265 Serial number: 26490


#执行命令之后，原主库xydbdg将会关闭，原备库xydb会重新启动到mount状态，且变成新主库角色；
#此时需要手工在新主库xydb上执行命令，打开数据库
[grid@k8s-rac01 ~]$ crsctl status resource ora.xydb.db -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.xydb.db
      1        ONLINE  INTERMEDIATE k8s-rac01                Mounted (Closed),HOM
                                                             E=/u01/app/oracle/pr
                                                             oduct/19.0.0/db_1,ST
                                                             ABLE
      2        ONLINE  INTERMEDIATE k8s-rac02                Mounted (Closed),HOM
                                                             E=/u01/app/oracle/pr
                                                             oduct/19.0.0/db_1,ST
                                                             ABLE


#k8s-rac01
SYS@xydb1> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydb1> alter database open; 

Database altered.


#k8s-rac02
SYS@xydb2> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydb2> alter database open; 

Database altered.

SYS@xydb2> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	FAILED DESTINATION
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	FAILED DESTINATION



#然后手工将原主库xydbdg进行startup，承担新备库角色，并开启实时应用：
[oracle@k8s-oracle-store ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Feb 2 18:43:03 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

Connected to an idle instance.

SYS@xydbdg> startup;
ORACLE instance started.

Total System Global Area 1.6106E+10 bytes
Fixed Size		   18625040 bytes
Variable Size		 2181038080 bytes
Database Buffers	 1.3892E+10 bytes
Redo Buffers		   14925824 bytes
Database mounted.
Database opened.
SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY	     PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	RECOVERY NEEDED

SYS@xydbdg> recover managed standby database disconnect;
Media recovery complete.
SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED

SYS@xydbdg> 

#此时新主库也恢复正常
SYS@xydb2> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY

SYS@xydb2> 


#注意：19c ADG 在未配置DG Broker的情况下，也很简单实现了主备角色互换，只需手工处理下开库的动作。
#此外，与11g ADG不同，现在MRP进程默认就是开启实时应用（前提是准备工作做好），也就是说：

#备库MRP实时开启默认无需指定 using current logfile 关键字。
#默认即是，如果不想实时，指定 using archived logfile 关键字。



#查看当前主库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

#查看当备库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

select process,client_process,sequence#, THREAD# ，status from v$managed_standby;
select name,role,instance,thread#,sequence#,action from gv$dataguard_process;
```



##### 3.1.2.2.新主备检查

#主备库状态检查

```sql
#查看当前主库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

#查看当备库的状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

select process,client_process,sequence#, THREAD# ，status from v$managed_standby;

 select name,role,instance,thread#,sequence#,action from gv$dataguard_process;
```

#创建pdb及数据进行测试

#创建pdb

```oracle
create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba);

alter pluggable database dataassets open;
alter pluggable database all save state instances=all;



alter session set container=dataassets;

create tablespace pdb1user datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

alter tablespace pdb1user add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;


create user user1 identified by user1 default tablespace pdb1user account unlock;

grant dba to user1;
grant select any table to user1;
```
#连接方式
```bash
srvctl add service -d xydb -s s_dataassets -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets

srvctl start service -d xydb -s s_dataassets
srvctl status service -d xydb -s s_dataassets

sqlplus pdbadmin/J3my3xl4c12ed@172.16.134.9:1521/s_dataassets

--创建表

create table dgtest (
       id number(9) not null primary key,
       classname varchar2(40) not null
       );

	   
insert into dgtest values(28,'class one');

commit;


```



#logs

#检查状态

```sql
#查看当前主库的状态
SYS@xydb2> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY


#查看当备库的状态
SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from v$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED

SYS@xydbdg> 


SYS@xydbdg> select process,client_process,sequence#, THREAD# ，status from v$managed_standby;

PROCESS   CLIENT_P  SEQUENCE#	 THREAD# STATUS
--------- -------- ---------- ---------- ------------
ARCH	  ARCH		    0	       0 CONNECTED
DGRD	  N/A		    0	       0 ALLOCATED
DGRD	  N/A		    0	       0 ALLOCATED
ARCH	  ARCH		    0	       0 CONNECTED
ARCH	  ARCH		    0	       0 CONNECTED
ARCH	  ARCH		    0	       0 CONNECTED
RFS	  LGWR		  401	       2 IDLE
RFS	  Archival	    0	       2 IDLE
RFS	  LGWR		  428	       1 IDLE
RFS	  UNKNOWN	    0	       0 IDLE
RFS	  Archival	    0	       1 IDLE
RFS	  UNKNOWN	    0	       0 IDLE
MRP0	  N/A		  401	       2 APPLYING_LOG

13 rows selected.

SYS@xydbdg> 

SYS@xydbdg> select name,role,instance,thread#,sequence#,action from gv$dataguard_process;

NAME  ROLE			 INSTANCE    THREAD#  SEQUENCE# ACTION
----- ------------------------ ---------- ---------- ---------- ------------
TMON  redo transport monitor		0	   0	      0 IDLE
LGWR  log writer			0	   0	      0 IDLE
TT00  gap manager			0	   0	      0 IDLE
TT01  redo transport timer		0	   0	      0 IDLE
ARC0  archive local			0	   0	      0 IDLE
ARC1  archive redo			0	   0	      0 IDLE
ARC2  archive redo			0	   0	      0 IDLE
ARC3  archive redo			0	   0	      0 IDLE
rfs   RFS ping				0	   2	    401 IDLE
rfs   RFS async 			0	   2	    401 IDLE
rfs   RFS ping				0	   1	    428 IDLE
rfs   RFS async 			0	   1	    428 IDLE
MRP0  managed recovery			0	   0	      0 IDLE
PR00  recovery logmerger		0	   2	    401 APPLYING_LOG
PR01  recovery apply slave		0	   0	      0 IDLE
PR02  recovery apply slave		0	   0	      0 IDLE
PR03  recovery apply slave		0	   0	      0 IDLE
PR04  recovery apply slave		0	   0	      0 IDLE
PR05  recovery apply slave		0	   0	      0 IDLE
PR06  recovery apply slave		0	   0	      0 IDLE
PR07  recovery apply slave		0	   0	      0 IDLE
PR08  recovery apply slave		0	   0	      0 IDLE
PR09  recovery apply slave		0	   0	      0 IDLE
PR0A  recovery apply slave		0	   0	      0 IDLE
PR0B  recovery apply slave		0	   0	      0 IDLE
PR0C  recovery apply slave		0	   0	      0 IDLE
PR0D  recovery apply slave		0	   0	      0 IDLE
PR0E  recovery apply slave		0	   0	      0 IDLE
PR0F  recovery apply slave		0	   0	      0 IDLE
PR0G  recovery apply slave		0	   0	      0 IDLE

30 rows selected.

SYS@xydbdg> 


```

#新主库创建pdb测试

```sql
#rac库因为有参数设定，所以不需要指定FILE_NAME_CONVERT
SYS@xydb1> show parameter db_create_file_dest;

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
db_create_file_dest		     string	 +DATA

#create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba) FILE_NAME_CONVERT = ('+DATA', '+DATA');

SYS@xydb1> create pluggable database dataassets admin user pdbadmin identified by oracle roles=(dba);
Pluggable database created.

SYS@xydb1> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO
	 5 DATAASSETS			  MOUNTED


SYS@xydb1> alter pluggable database dataassets open;

Pluggable database altered.

SYS@xydb1> alter pluggable database all save state instances=all;

Pluggable database altered.

SYS@xydb1> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO
	 5 DATAASSETS			  READ WRITE NO
SYS@xydb1> alter session set container=dataassets;

Session altered.

SYS@xydb1> select file_name from dba_data_files;

FILE_NAME
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297
+DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297
+DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/undotbs1.285.1159901297

SYS@xydb1> select file_name from dba_temp_files;

FILE_NAME
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/TEMPFILE/temp.293.1159901313

SYS@xydb1> 

#首先在备库xydbdg中创建新pdb dataassets的tempfile文件的目录
[oracle@k8s-oracle-store tempfile]$ cd /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/

[oracle@k8s-oracle-store tempfile]$ mkdir -p tempfile

#此时备库pdb都是Mount阶段，将其open
SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  MOUNTED
	 4 PORTAL			  MOUNTED
	 5 DATAASSETS			  MOUNTED
SYS@xydbdg> alter pluggable database all open;

Pluggable database altered.

SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ ONLY  NO
	 4 PORTAL			  READ ONLY  NO
	 5 DATAASSETS			  READ ONLY  NO

#在此过程中alter_xydbdg.log中发现报错内容：
DATAASSETS(5):*********************************************************************
DATAASSETS(5):WARNING: The following temporary tablespaces in container(DATAASSETS)
DATAASSETS(5):         contain no files.
DATAASSETS(5):         This condition can occur when a backup controlfile has
DATAASSETS(5):         been restored.  It may be necessary to add files to these
DATAASSETS(5):         tablespaces.  That can be done using the SQL statement:
DATAASSETS(5): 
DATAASSETS(5):         ALTER TABLESPACE <tablespace_name> ADD TEMPFILE
DATAASSETS(5): 
DATAASSETS(5):         Alternatively, if these temporary tablespaces are no longer
DATAASSETS(5):         needed, then they can be dropped.
DATAASSETS(5):           Empty temporary tablespace: TEMP
DATAASSETS(5):*********************************************************************

#备库中先不添加tempfile，主库创建数据表空间及用户数据，进行测试下
SYS@xydb1> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ WRITE NO
	 4 PORTAL			  READ WRITE NO
	 5 DATAASSETS			  READ WRITE NO
SYS@xydb1> alter session set container=dataassets;

Session altered.

SYS@xydb1> create tablespace pdb1user datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

Tablespace created.

SYS@xydb1> create user user1 identified by user1 default tablespace pdb1user account unlock;

User created.

SYS@xydb1> grant dba to user1;

Grant succeeded.

SYS@xydb1> grant select any table to user1;

Grant succeeded.

SYS@xydb1>  exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

#为了外部访问，rac添加service s_dataassets
[oracle@k8s-rac01 ~]$ srvctl add service -d xydb -s s_dataassets -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb dataassets
[oracle@k8s-rac01 ~]$ srvctl start service -d xydb -s s_dataassets
[oracle@k8s-rac01 ~]$ srvctl status service -d xydb -s s_dataassets
Service s_dataassets is running on instance(s) xydb1,xydb2

[oracle@k8s-rac01 ~]$ sqlplus user1/user1@rac-scan:1521/dataassets

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Feb 2 19:08:38 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

USER1@rac-scan:1521/dataassets> 

USER1@rac-scan:1521/dataassets> create table dgtest (
       id number(9) not null primary key,
       classname varchar2(40) not null
       );  

Table created.

USER1@rac-scan:1521/dataassets> insert into dgtest values(28,'class one');

1 row created.

USER1@rac-scan:1521/dataassets> commit;

Commit complete.

USER1@rac-scan:1521/dataassets> select * from dgtest;

	ID CLASSNAME
---------- ----------------------------------------
	28 class one

USER1@rac-scan:1521/dataassets> 


#此时通过备库查询dgtest表
SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ ONLY  NO
	 4 PORTAL			  READ ONLY  NO
	 5 DATAASSETS			  READ ONLY  NO
SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 STUWORK			  READ ONLY  NO
	 4 PORTAL			  READ ONLY  NO
	 5 DATAASSETS			  READ ONLY  NO
SYS@xydbdg> alter session set container=DATAASSETS;

Session altered.

SYS@xydbdg> select * from user1.dgtest;

	ID CLASSNAME
---------- ----------------------------------------
	28 class one

SYS@xydbdg> 

#为了外部访问，备库添加监听的静态注册

[oracle@k8s-oracle-store admin]$ cat listener.ora
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

    (SID_DESC =
      (GLOBAL_DBNAME = dataassets)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/db_1)
      (SID_NAME = xydbdg)
    )
  )


[oracle@k8s-oracle-store admin]$ lsnrctl stop

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 02-FEB-2024 20:33:03

Copyright (c) 1991, 2023, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=k8s-oracle-store)(PORT=1521)))
The command completed successfully


[oracle@k8s-oracle-store admin]$ lsnrctl start

LSNRCTL for Linux: Version 19.0.0.0.0 - Production on 02-FEB-2024 20:33:06

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
Start Date                02-FEB-2024 20:33:06
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
Service "dataassets" has 1 instance(s).
  Instance "xydbdg", status UNKNOWN, has 1 handler(s) for this service...
Service "xydbdg" has 1 instance(s).
  Instance "xydbdg", status UNKNOWN, has 1 handler(s) for this service...
Service "xydbdg_dgmgrl" has 1 instance(s).
  Instance "xydbdg", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
[oracle@k8s-oracle-store admin]$ 


SYS@xydbdg> select con_name,name,network_name from v$active_services
  2  ;

CON_NAME	NAME								 NETWORK_NAME
--------------- ---------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
PORTAL		portal								 portal
PORTAL		s_portal							 s_portal
STUWORK 	stuwork 							 stuwork
CDB$ROOT	xydbdgXDB							 xydbdgXDB
CDB$ROOT	SYS$BACKGROUND
CDB$ROOT	SYS$USERS
STUWORK 	s_stuwork							 s_stuwork
CDB$ROOT	xydbdg								 xydbdg
DATAASSETS	dataassets							 dataassets

9 rows selected.


SYS@xydbdg>  exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0


[oracle@k8s-oracle-store admin]$ sqlplus user1/user1@172.18.13.104:1521/dataassets

SQL*Plus: Release 19.0.0.0.0 - Production on Fri Feb 2 20:41:27 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

Last Successful login time: Fri Feb 02 2024 19:21:52 +08:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

USER1@172.18.13.104:1521/dataassets> show con_name;

CON_NAME
------------------------------
DATAASSETS
USER1@172.18.13.104:1521/dataassets> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0
[oracle@k8s-oracle-store admin]$ 

```






### 3.2.ADG做手动failover切换测试

#### 3.2.0.主库开启flashback

#命令

```sql
show parameter db_recovery
select flashback_on from v$database;

alter database flashback on;
select flashback_on from v$database;
```



#步骤

```sql
#主库查询
SYS@xydb1> show parameter db_recovery

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
db_recovery_file_dest		     string	 +FRA
db_recovery_file_dest_size	     big integer 204668M

SYS@xydb1> select flashback_on from v$database;

FLASHBACK_ON
------------------
NO

SYS@xydb1> 

#备库查询
SYS@xydbdg> show parameter db_recovery

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
db_recovery_file_dest		     string	 /u01/app/oracle/fast_recovery_area
db_recovery_file_dest_size	     big integer 20G

SYS@xydbdg> select flashback_on from v$database;
FLASHBACK_ON
------------------
NO


#主库开启flashback
SYS@xydb1> alter database flashback on;

Database altered.

SYS@xydb1> select flashback_on from v$database;

FLASHBACK_ON
------------------
YES

SYS@xydb1> 


#备库并未开启
SYS@xydbdg>  select flashback_on from v$database;

FLASHBACK_ON
------------------
NO

SYS@xydbdg> 

#此时主备库状态
select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

#主库
SYS@xydb2> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY

#备库
SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS
-------------------- ---------------- -------------------- -------------------- --------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED

```



#### 3.2.1.备库failover，变主库

#步骤

```sql
#模拟主库故障，主库启动至mount阶段---可选
srvctl start database -h
srvctl stop database -db xydb
srvctl start database -db xydb -startoption mount

#如果只启动xydb1实例一，那么可以执行以下命令：
#SQL> ALTER SYSTEM FLUSH REDO TO 'xydbdg';

#备库查询状态---可选
SQL> SELECT UNIQUE THREAD# AS THREAD, MAX(SEQUENCE#) OVER (PARTITION BY thread#) AS LAST from V$ARCHIVED_LOG;


SQL> SELECT THREAD#, LOW_SEQUENCE#, HIGH_SEQUENCE# FROM V$ARCHIVE_GAP;

#假设物理主库宕机，无法启动，紧急启用备库。直接在备库上操作，将备库转换为主库角色。备库上执行下面四条命令即可

SQL > alter database recover managed standby database cancel;
SQL > alter database recover managed standby database finish;
SQL > alter database commit to switchover to primary with session shutdown;
SQL > alter database open;

```

```sql
#具体操作
#模拟主库故障，主库启动至mount阶段
[oracle@k8s-rac01 ~]$ srvctl start database -h

Starts the database.

Usage: srvctl start database -db <db_unique_name> [-startoption <start_options>] [-startconcurrency <start_concurrency>] [-node <node> | -serverpool "<serverpool_list>"] [-eval] [-verbose]
    -db <db_unique_name>           Unique name for the database
    -startoption <start_options>   Options to startup command (e.g. OPEN, MOUNT, or "READ ONLY")
    -startconcurrency <start_concurrency> Number of instances to be started simultaneously (or 0 for empty start_concurrency value)
    -node <node>                   Node on which to start the database
    -serverpool "<serverpool_list>" Comma separated list of database server pool names
    -eval                          Evaluates the effects of event without making any changes to the system
    -verbose                       Verbose output
    -help                          Print usage
    
[oracle@k8s-rac01 ~]$ srvctl stop database -db xydb
[oracle@k8s-rac01 ~]$ srvctl start database -db xydb -startoption mount

[oracle@k8s-rac01 ~]$ sqlplus / as sysdba

SYS@xydb1> select status from v$instance;

STATUS
------------
MOUNTED

#必须只有一个实例xydb1(或xydb2)启动至Mount状态时，才能执行命令ALTER SYSTEM FLUSH REDO TO 'xydbdg';

SYS@xydb1> ALTER SYSTEM FLUSH REDO TO 'xydbdg';
ALTER SYSTEM FLUSH REDO TO 'xydbdg'
*
ERROR at line 1:
ORA-38777: database must not be started in any other instance


SYS@xydb1> 

#备库查询
SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED	     NONE    YES

SYS@xydbdg> SELECT UNIQUE THREAD# AS THREAD, MAX(SEQUENCE#) OVER (PARTITION BY thread#) AS LAST from V$ARCHIVED_LOG;

    THREAD	 LAST
---------- ----------
	 2	  489
	 1	  531

SYS@xydbdg> SELECT THREAD#, LOW_SEQUENCE#, HIGH_SEQUENCE# FROM V$ARCHIVE_GAP;

no rows selected


#直接备库failover切换

#无GAP后，备库停止日志应用
SYS@xydbdg> alter database recover managed standby database cancel;

Database altered.

#完成所有已经接收日志的应用
SYS@xydbdg> alter database recover managed standby database finish;

Database altered.

#直接备库转换为主库
SYS@xydbdg> alter database commit to switchover to primary with session shutdown;

Database altered.

SYS@xydbdg> select status from v$instance;

STATUS
------------
MOUNTED


 
#打开新主库(即原备库)
SYS@xydbdg> alter database open;

Database altered.

SYS@xydbdg> select status from v$instance;

STATUS
------------
OPEN

SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	FAILED DESTINATION   NONE    YES

#现在备库成为了主库角色，failover切换完成；
```



#### 3.2.2.原主库(RAC库)恢复成为现主库的备库的三种方法
##### 3.2.2.1.通过重新搭建ADG，让rac库成为现主库的备库

##### 3.2.2.2.通过flashback，让rac库成为现主库的备库

#基本步骤

```sql
-- Flashing Back a Failed Primary Database into a Physical Standby Database
#1. 查询原备库转换成主库时的SCN   -->> xydbdg上操作

SYS@xydbdg> select to_char(standby_became_primary_scn) from v$database;

TO_CHAR(STANDBY_BECAME_PRIMARY_SCN)
----------------------------------------
29964459


#2. Flash back原主库  -->> 即：RAC节点
#先关闭rac数据库，再开启到mount阶段
#应该是只启动一个实例即xydb1至mount阶段，不能两个实例都到mount阶段
[oracle@k8s-rac01 ~]$ srvctl stop database -db xydb
[oracle@k8s-rac01 ~]$ srvctl start database -db xydb -startoption mount

[oracle@k8s-rac01 ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 17 16:45:46 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

SYS@xydb1> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydb1> flashback database to scn 29964459;

Flashback complete.

      -->> 注意，前提是 `flashback_on` 的特性必须开启，`alter database flashback on;`


#3. 将原主库转换为备库  -->> RAC节点 上操作

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
MOUNTED 	     PRIMARY	      MAXIMUM PERFORMANCE  UNPROTECTED		NOT ALLOWED	     NONE    YES
MOUNTED 	     PRIMARY	      MAXIMUM PERFORMANCE  UNPROTECTED		NOT ALLOWED	     NONE    YES


SYS@xydb1> alter database convert to physical standby;
alter database convert to physical standby
*
ERROR at line 1:
ORA-38777: database must not be started in any other instance


SYS@xydb1> select status from v$instance;

STATUS
------------
MOUNTED

#先关闭k8s-rac02，再在k8s-rac01上执行
SYS@xydb2> select status from v$instance;

STATUS
------------
MOUNTED


SYS@xydb2> shutdown immediate;
ORA-01109: database not open


Database dismounted.
ORACLE instance shut down.
SYS@xydb2> 

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
MOUNTED 	     PRIMARY	      MAXIMUM PERFORMANCE  UNPROTECTED		NOT ALLOWED	     NONE    YES

SYS@xydb1> alter database convert to physical standby;

Database altered.

SYS@xydb1> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
MOUNTED 	     PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	RECOVERY NEEDED      NONE    YES


[oracle@k8s-rac01 ~]$ srvctl stop database -db xydb
[oracle@k8s-rac01 ~]$ srvctl start database -db xydb

[oracle@k8s-rac01 ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 17 16:59:55 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2022, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ ONLY	     PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	RECOVERY NEEDED      NONE    YES
READ ONLY	     PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	RECOVERY NEEDED      NONE    YES

、
#4. 现备库上启用Redo Apply  -->> RAC节点 上操作

SYS@xydb1> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

Database altered.

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED	     NONE    YES
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED	     NONE    YES

SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY	     NONE    YES


#基本OK！
```



##### 3.2.2.3.通过rman备份

#步骤

```sql
-- Converting a Failed Primary into a Standby Database Using RMAN Backups

1. 查询原备库转换成主库时的SCN  -->> xydbdg 上操作

      SQL> select to_char(standby_became_primary_scn) from v$database;

2. 恢复原主库(单实例xydb1至mount阶段)      -->> 即：RAC节点

       RMAN > run
               { set until scn xxxxxx;  
                  restore database;            
                  recover database;
                }

3. 将原主库转换为备库  -->> 即：RAC节点

       SQL> alter database convert to physical standby;
       
       srvctl stop database -db xydb
       srvctl start database -db xydb

4. 现备库上启用Redo Apply       -->> 即：RAC节点

       SQL> alter database recover managed standby database disconnect from session;

基本OK！
```

#操作过程

```sql
-- Converting a Failed Primary into a Standby Database Using RMAN Backups

#1. 查询原备库转换成主库时的SCN  -->> xydbdg 上操作

SYS@xydbdg> select to_char(standby_became_primary_scn) from v$database;

TO_CHAR(STANDBY_BECAME_PRIMARY_SCN)
----------------------------------------
30182763


#2. 恢复原主库(单实例xydb1至mount阶段)      -->> 即：RAC节点
[oracle@k8s-rac01 ~]$ rman target /

Recovery Manager: Release 19.0.0.0.0 - Production on Sat Feb 17 17:20:07 2024
Version 19.21.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: XYDB (DBID=2062989406, not open)

RMAN> select status from v$instance;

using target database control file instead of recovery catalog
STATUS      
------------
MOUNTED     

RMAN> run
               { set until scn 30182763;  
                  restore database;            
                  recover database;
                }

executing command: SET until clause

Starting restore at 2024-02-17 17:20:24
flashing back control file to SCN 30182763
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=572 instance=xydb1 device type=DISK

skipping datafile 5; already restored to file +DATA/XYDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/system.265.1153251113
skipping datafile 6; already restored to file +DATA/XYDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/sysaux.266.1153251113
skipping datafile 8; already restored to file +DATA/XYDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/undotbs1.267.1153251113
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00022 to +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/pdb1user.294.1159902173
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/1064B454582A4AA4E063610D12AC9D59/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.268.1161045033
channel ORA_DISK_1: piece handle=+FRA/XYDB/1064B454582A4AA4E063610D12AC9D59/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.268.1161045033 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:15
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00004 to +DATA/XYDB/DATAFILE/undotbs1.259.1153250701
channel ORA_DISK_1: restoring datafile 00009 to +DATA/XYDB/DATAFILE/undotbs2.269.1153251451
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.292.1161045059
channel ORA_DISK_1: piece handle=+FRA/XYDB/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.292.1161045059 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:15
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00003 to +DATA/XYDB/DATAFILE/sysaux.258.1153250677
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.339.1161045033
channel ORA_DISK_1: piece handle=+FRA/XYDB/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.339.1161045033 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:01:15
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00019 to +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297
channel ORA_DISK_1: restoring datafile 00023 to +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/undo_2.295.1159902455
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/1064B454582A4AA4E063610D12AC9D59/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.334.1161045035
channel ORA_DISK_1: piece handle=+FRA/XYDB/1064B454582A4AA4E063610D12AC9D59/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.334.1161045035 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:45
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00020 to +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297
channel ORA_DISK_1: restoring datafile 00021 to +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/undotbs1.285.1159901297
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/1064B454582A4AA4E063610D12AC9D59/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.301.1161045081
channel ORA_DISK_1: piece handle=+FRA/XYDB/1064B454582A4AA4E063610D12AC9D59/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.301.1161045081 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:15
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00001 to +DATA/XYDB/DATAFILE/system.257.1153250631
channel ORA_DISK_1: restoring datafile 00007 to +DATA/XYDB/DATAFILE/users.260.1153250703
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.321.1161045033
channel ORA_DISK_1: piece handle=+FRA/XYDB/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.321.1161045033 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:01:16
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00016 to +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/sysaux.280.1153652419
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.294.1161045113
channel ORA_DISK_1: piece handle=+FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.294.1161045113 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:15
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00010 to +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/system.274.1153252181
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/0A6CD91492EE7956E063620D12AC6018/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.289.1161045083
channel ORA_DISK_1: piece handle=+FRA/XYDB/0A6CD91492EE7956E063620D12AC6018/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.289.1161045083 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:45
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00011 to +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/sysaux.275.1153252181
channel ORA_DISK_1: restoring datafile 00014 to +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/users.278.1153252229
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/0A6CD91492EE7956E063620D12AC6018/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.333.1161045127
channel ORA_DISK_1: piece handle=+FRA/XYDB/0A6CD91492EE7956E063620D12AC6018/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.333.1161045127 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:15
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00012 to +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/undotbs1.273.1153252181
channel ORA_DISK_1: restoring datafile 00013 to +DATA/XYDB/0A6CD91492EE7956E063620D12AC6018/DATAFILE/undo_2.277.1153252217
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/0A6CD91492EE7956E063620D12AC6018/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.320.1161045143
channel ORA_DISK_1: piece handle=+FRA/XYDB/0A6CD91492EE7956E063620D12AC6018/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.320.1161045143 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:07
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00015 to +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/system.281.1153652419
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.342.1161045097
channel ORA_DISK_1: piece handle=+FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.342.1161045097 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:45
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00017 to +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/undotbs1.279.1153652419
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.280.1161045147
channel ORA_DISK_1: piece handle=+FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.280.1161045147 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:03
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00018 to +DATA/XYDB/0ACA091340E201B7E063620D12ACBBBA/DATAFILE/undo_2.283.1153652669
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.308.1161045147
channel ORA_DISK_1: piece handle=+FRA/XYDB/0ACA091340E201B7E063620D12ACBBBA/BACKUPSET/2024_02_16/nnndf0_tag20240216t003031_0.308.1161045147 tag=TAG20240216T003031
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:03
Finished restore at 2024-02-17 17:26:42

Starting recover at 2024-02-17 17:26:43
using channel ORA_DISK_1

starting media recovery

archived log for thread 1 with sequence 525 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_525.297.1161045151
archived log for thread 1 with sequence 526 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_526.284.1161045161
archived log for thread 1 with sequence 527 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_527.265.1161045163
archived log for thread 1 with sequence 528 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_528.293.1161104445
archived log for thread 1 with sequence 529 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_529.299.1161123709
archived log for thread 1 with sequence 530 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_530.313.1161131443
archived log for thread 1 with sequence 531 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_531.341.1161176937
archived log for thread 1 with sequence 532 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_532.267.1161190565
archived log for thread 2 with sequence 482 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_2_seq_482.331.1161045157
archived log for thread 2 with sequence 483 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_2_seq_483.305.1161045163
archived log for thread 2 with sequence 484 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_16/thread_2_seq_484.269.1161111617
archived log for thread 2 with sequence 485 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_485.279.1161131473
archived log for thread 2 with sequence 486 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_486.282.1161131489
archived log for thread 2 with sequence 487 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_487.345.1161131493
archived log for thread 2 with sequence 488 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_488.302.1161131517
archived log for thread 2 with sequence 489 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_489.324.1161176935
archived log for thread 2 with sequence 490 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_490.270.1161190565
archived log for thread 1 with sequence 1 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_1.298.1161190567
archived log for thread 1 with sequence 2 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_2.326.1161191027
archived log for thread 1 with sequence 3 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_3.328.1161191247
archived log for thread 1 with sequence 4 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_4.288.1161191723
archived log for thread 2 with sequence 1 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_1.285.1161190567
archived log for thread 2 with sequence 2 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_2.307.1161191269
archived log for thread 2 with sequence 3 is already on disk as file +FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_3.275.1161191725
channel ORA_DISK_1: starting archived log restore to default destination
channel ORA_DISK_1: restoring archived log
archived log thread=2 sequence=481
channel ORA_DISK_1: reading from backup piece +FRA/XYDB/BACKUPSET/2024_02_16/annnf0_tag20240216t003231_0.340.1161045151
channel ORA_DISK_1: piece handle=+FRA/XYDB/BACKUPSET/2024_02_16/annnf0_tag20240216t003231_0.340.1161045151 tag=TAG20240216T003231
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:01
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_481.263.1161192409 thread=2 sequence=481
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_525.297.1161045151 thread=1 sequence=525
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_2_seq_482.331.1161045157 thread=2 sequence=482
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_526.284.1161045161 thread=1 sequence=526
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_2_seq_483.305.1161045163 thread=2 sequence=483
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_527.265.1161045163 thread=1 sequence=527
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_2_seq_484.269.1161111617 thread=2 sequence=484
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_528.293.1161104445 thread=1 sequence=528
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_16/thread_1_seq_529.299.1161123709 thread=1 sequence=529
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_485.279.1161131473 thread=2 sequence=485
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_530.313.1161131443 thread=1 sequence=530
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_486.282.1161131489 thread=2 sequence=486
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_531.341.1161176937 thread=1 sequence=531
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_487.345.1161131493 thread=2 sequence=487
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_488.302.1161131517 thread=2 sequence=488
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_489.324.1161176935 thread=2 sequence=489
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_490.270.1161190565 thread=2 sequence=490
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_532.267.1161190565 thread=1 sequence=532
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_1.298.1161190567 thread=1 sequence=1
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_2_seq_1.285.1161190567 thread=2 sequence=1
archived log file name=+FRA/XYDB/ARCHIVELOG/2024_02_17/thread_1_seq_2.326.1161191027 thread=1 sequence=2
Finished recover at 2024-02-17 17:27:24

RMAN> 


#3. 将原主库转换为备库  -->> 即：RAC节点

SYS@xydb1> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydb1> alter database convert to physical standby;

Database altered.

SYS@xydb1> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydb1> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.21.0.0.0

[oracle@k8s-rac01 ~]$ srvctl stop database -db xydb
[oracle@k8s-rac01 ~]$ srvctl start database -db xydb

#4. 现备库上启用Redo Apply       -->> 即：RAC节点

SYS@xydb1> alter database recover managed standby database disconnect from session;

Database altered.

SYS@xydb1> 

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	SWITCHOVER PENDING   NONE    YES
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	SWITCHOVER PENDING   NONE    YES

SYS@xydb1> 


SYS@xydbdg>  select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY	     NONE    YES

SYS@xydbdg> alter system switch logfile;

System altered.

SYS@xydbdg> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ WRITE	     PRIMARY	      MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	TO STANDBY	     NONE    YES

SYS@xydbdg> 

SYS@xydb1> select OPEN_MODE,DATABASE_ROLE,PROTECTION_MODE,PROTECTION_LEVEL,SWITCHOVER_STATUS,GUARD_STATUS,FORCE_LOGGING from gv$database;

OPEN_MODE	     DATABASE_ROLE    PROTECTION_MODE	   PROTECTION_LEVEL	SWITCHOVER_STATUS    GUARD_S FORCE_LOGGING
-------------------- ---------------- -------------------- -------------------- -------------------- ------- ---------------------------------------
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED	     NONE    YES
READ ONLY WITH APPLY PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE	NOT ALLOWED	     NONE    YES

SYS@xydb1> 


#基本OK！
```



### 3.2.3.通过switchover，进行主备切换

#同3.1.2.主备再次切换-通过19c adg命令



## 4.配置dg_broker







## 5.通过dg_broker进行切换测试



## 7.ADG RU升级
### 7.1.升级流程

#主库rac-19.21/备库单实例-19.21

```
#升级顺序
#可以先升级备库，然后主备切换后，再升级新备库
```



### 7.2.主库打19.22RU

#补丁列表

|                             Name                             |  Download Link   |
| :----------------------------------------------------------: | :--------------: |
|           Database Release Update 19.22.0.0.240116           | <Patch 35943157> |
|     Grid Infrastructure Release Update 19.22.0.0.240116      | <Patch 35940989> |
|             OJVM Release Update 19.22.0.0.240116             | <Patch 35926646> |
|  (there were no OJVM Release Update Revisions for Jan 2024)  |                  |
| Microsoft Windows 32-Bit & x86-64 Bundle Patch 19.22.0.0.240116 | <Patch 35962832> |

#You must use the OPatch utility version 12.2.0.1.40 or later to apply this patch.



```
#补丁位置：---k8s-rac01/k8s-rac02都一样
[oracle@k8s-rac01 opt]$ ls
19.20patch  19.21patch  opa  oracle  oracle.ahf  ORCLfmap
[oracle@k8s-rac01 opt]$ cd 19.21patch/
[oracle@k8s-rac01 19.21patch]$ ll
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
[grid@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-rac01 OPatch]$ ./opatch lspatches   
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
35332537;ACFS RELEASE UPDATE 19.20.0.0.0 (35332537)
35320149;OCW RELEASE UPDATE 19.20.0.0.0 (35320149)
35320081;Database Release Update : 19.20.0.0.230718 (35320081)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.

[grid@k8s-rac01 OPatch]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                Started,STABLE
      2        ONLINE  ONLINE       k8s-rac02                Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac01.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac02.vip
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       k8s-rac02                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
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

[grid@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[grid@k8s-rac01 OPatch]$ ./opatch version   

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



#### 7.2.6.补丁冲突检查 k8s-rac01/k8s-rac02两个节点都执行

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



#### 7.2.7.空间检查 k8s-rac01/k8s-rac02两个节点都执行

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

#k8s-rac01:
#k8s-rac01大约2分钟40秒，全部成功(最长有过4分17秒)

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze

#k8s-rac02:
#k8s-rac02大约2分钟40秒，全部成功(最长有过3分48秒)
#可能会有部分失败

/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze

-----------------------------
Reason: Failed during Analysis: CheckSystemCommandsAvailable Failed, [ Prerequisite Status: FAILED, Prerequisite output:
The details are:

Missing command :fuser]
---------------------------


#解决办法：
yum install -y psmisc

#k8s-rac02再次检查：
#k8s-rac02大约2分钟40秒，全部成功
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze       
```

#报错分析解决

```bash
[root@k8s-rac01 OPatch]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze 
OPatchauto session is initiated at Wed Nov 22 18:02:38 2023

System initialization log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchautodb/systemconfig2023-11-22_06-02-46PM.log.

Session log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-20PM.log
The id for this session is BY6I

Wrong OPatch software installed in following homes:
Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1

Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1

OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
OPatchAuto failed.

OPatchauto session completed at Wed Nov 22 18:03:51 2023
Time taken to complete the session 1 minute, 6 seconds

 opatchauto failed with error code 42

[root@k8s-rac02 OPatch]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -analyze 
OPatchauto session is initiated at Wed Nov 22 18:02:38 2023

System initialization log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchautodb/systemconfig2023-11-22_06-02-44PM.log.

Session log file is /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-14PM.log
The id for this session is YA4Q

Wrong OPatch software installed in following homes:
Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1

Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1

OPATCHAUTO-72088: OPatch version check failed.
OPATCHAUTO-72088: OPatch software version in homes selected for patching are different.
OPATCHAUTO-72088: Please install same OPatch software in all homes.
OPatchAuto failed.

OPatchauto session completed at Wed Nov 22 18:03:38 2023
Time taken to complete the session 0 minute, 54 seconds

 opatchauto failed with error code 42


[root@k8s-rac01 OPatch]# tail -100f /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-20PM.log
2023-11-22 18:03:50,374 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator -  OH  hostname  OH.getPath() /u01/app/oracle/product/19.0.0/db_1
2023-11-22 18:03:51,025 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac01
2023-11-22 18:03:51,025 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac02
2023-11-22 18:03:51,025 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='
Wrong OPatch software installed in following homes:'}
2023-11-22 18:03:51,025 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:51,026 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1
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

[root@k8s-rac02 OPatch]# tail -100f /u01/app/19.0.0/grid/cfgtoollogs/opatchauto/opatchauto2023-11-22_06-03-14PM.log
2023-11-22 18:03:38,228 INFO  [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator -  OH  hostname  OH.getPath() /u01/app/oracle/product/19.0.0/db_1
2023-11-22 18:03:38,731 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac01
2023-11-22 18:03:38,732 WARNING [1] com.oracle.glcm.patch.auto.db.product.validation.validators.OPatchVersionValidator - OPatch Version Check failed for Home /u01/app/oracle/product/19.0.0/db_1 on host k8s-rac02
2023-11-22 18:03:38,732 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='
Wrong OPatch software installed in following homes:'}
2023-11-22 18:03:38,732 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac01, Home:/u01/app/oracle/product/19.0.0/db_1
'}
2023-11-22 18:03:38,733 INFO  [1] com.oracle.cie.common.util.reporting.CommonReporter - Reporting console output : Message{id='null', message='Host:k8s-rac02, Home:/u01/app/oracle/product/19.0.0/db_1
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

#k8s-rac01约15分钟(最长有过80分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/19.0.0/grid   

#k8s-rac02约20分钟(最长有过60分36秒)
/u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/19.0.0/grid   
#报错后可以再次执行


#升级后的状态
su - grid
cd $ORACLE_HOME/OPatch

[grid@k8s-rac01 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35652062;ACFS RELEASE UPDATE 19.21.0.0.0 (35652062)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)
35553096;TOMCAT RELEASE UPDATE 19.0.0.0.0 (35553096)
33575402;DBWLM RELEASE UPDATE 19.0.0.0.0 (33575402)

OPatch succeeded.


[grid@k8s-rac02 OPatch]$ ./opatch lspatches
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
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/OPatch/opatchauto apply /opt/19.20patch/35319490 -oh /u01/app/19.0.0/grid   

Invalid current directory.  Please run opatchauto from other than '/root' or '/' directory.
And check if the home owner user has write permission set for the current directory.
opatchauto returns with error code = 2
------------------------------------------------------------------------
#(1)
#GI因为共享磁盘的UUID变化，没起来

CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-1705: Found 1 configured voting files but 2 voting files are required, terminating to ensure data integrity; details at (:CSSNM00021:) in /u01/app/grid/diag/crs/k8s-rac02/crs/trace/ocssd.trc
CRS-2883: Resource 'ora.cssd' failed during Clusterware stack start.
CRS-4406: Oracle High Availability Services synchronous start failed.
CRS-41053: checking Oracle Grid Infrastructure for file permission issues
PRVH-0116 : Path "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" with permissions "rw-r--r--" does not have execute permissions for the owner, file's group, and others on node "k8s-rac02".
PRVG-2031 : Owner of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-rac02". [Expected = "grid(11012)" ; Found = "root(0)"]
PRVG-2032 : Group of file "/u01/app/19.0.0/grid/crs/install/cmdllroot.sh" did not match the expected value on node "k8s-rac02". [Expected = "oinstall(11001)" ; Found = "root(0)"]
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
Postpatch operation log file location: /u01/app/grid/crsdata/k8s-rac02/crsconfig/crs_postpatch_apply_inplace_k8s-rac02_2023-11-19_09-07-00AM.log
Failed to start CRS service on home /u01/app/19.0.0/grid

Execution of [GIStartupAction] patch action failed, check log for more details. Failures:
Patch Target : k8s-rac02->/u01/app/19.0.0/grid Type[crs]
Details: [
---------------------------Patching Failed---------------------------------
Command execution failed during patching in home: /u01/app/19.0.0/grid, host: k8s-rac02.
Command failed:  /u01/app/19.0.0/grid/perl/bin/perl -I/u01/app/19.0.0/grid/perl/lib -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install -I/u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/xag /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install/rootcrs.pl -postpatch
Command failure output: 
Using configuration parameter file: /u01/app/19.0.0/grid/opatchautocfg/db/dbtmp/bootstrap_k8s-rac02/patchwork/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crs_postpatch_apply_inplace_k8s-rac02_2023-11-19_09-07-00AM.log
2023/11/19 09:07:16 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
Oracle Clusterware active version on the cluster is [19.0.0.0.0]. The cluster upgrade state is [NORMAL]. The cluster active patch level is [3976270074].
CRS-2672: Attempting to start 'ora.drivers.acfs' on 'k8s-rac02'
CRS-2676: Start of 'ora.drivers.acfs' on 'k8s-rac02' succeeded
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
[root@k8s-rac02 35319490]# 

#发现错误是2023/11/19 09:10:09 CLSRSC-180: An error occurred while executing the command 'ocrconfig -local -manualbackup' 
#手动执行，发现确实报错
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup manual

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 ~]# ll /u01/app/grid/crsdata/k8s-rac02/olr
total 495048
-rw-r--r-- 1 root root       1101824 Nov 18 18:49 autobackup_20231118_184948.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:35 backup_20231118_183548.olr
-rw------- 1 root oinstall 503484416 Nov 19 11:54 k8s-rac02_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 08:46 k8s-rac02_19.olr.bkp.patch
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup
PROTL-23: failed to back up Oracle Local Registry
PROCL-60: The Oracle Local Registry backup file '/u01/app/grid/crsdata/k8s-rac02/olr/backup_20231119_121545.olr' is corrupt.

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83168
	 Available space (kbytes) :     408516
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check failed


#但在k8s-rac01上手动备份没问题
[root@k8s-rac01 ContentsXML]# ocrconfig -local -manualbackup

k8s-rac01     2023/11/19 12:12:49     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231119_121249.olr     3976270074     

k8s-rac01     2023/11/19 01:25:37     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231119_012537.olr     3976270074     

k8s-rac01     2023/11/18 18:27:53     /u01/app/grid/crsdata/k8s-rac01/olr/backup_20231118_182753.olr     724960844     
[root@k8s-rac01 ContentsXML]# ll /u01/app/grid/crsdata/k8s-rac01/olr/
total 498160
-rw-r--r-- 1 root root       1114112 Nov 18 18:39 autobackup_20231118_183942.olr
-rw-r--r-- 1 root root       1024000 Nov 18 18:27 backup_20231118_182753.olr
-rw------- 1 root root       1150976 Nov 19 01:25 backup_20231119_012537.olr
-rw------- 1 root root       1593344 Nov 19 12:12 backup_20231119_121249.olr
-rw------- 1 root oinstall 503484416 Nov 19 12:12 k8s-rac01_19.olr
-rw-r--r-- 1 root root     503484416 Nov 19 00:11 k8s-rac01_19.olr.bkp.patch
[root@k8s-rac01 ~]#  /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83444
	 Available space (kbytes) :     408240
	 ID                       : 1567972045
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac01/olr/k8s-rac01_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#k8s-rac02，如果此时关闭cluster，将无法启动，特别是ora.asm/ora.OCR.dg(ora.asmgroup)/ora.DATA.dg(ora.asmgroup)/ora.FRA.dg(ora.asmgroup)等无法启动，但是vip/LISTENER等其他组件正常

[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-5017: The resource action "ora.asm start" encountered the following error: 
CRS-5048: Failure communicating with CRS to access a resource profile or perform an action on a resource
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_grid.trc".
CRS-2674: Start of 'ora.asm' on 'k8s-rac02' failed
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-5017: The resource action "ora.xydb.db start" encountered the following error: 
ORA-00600: internal error code, arguments: [kgfz_getDiskAccessMode:ntyp], [0], [], [], [], [], [], [], [], [], [], []
. For details refer to "(:CLSN00107:)" in "/u01/app/grid/diag/crs/k8s-rac02/crs/trace/crsd_oraagent_oracle.trc".
CRS-2674: Start of 'ora.xydb.db' on 'k8s-rac02' failed
===== Summary of resource auto-start failures follows =====
CRS-2807: Resource 'ora.asmgroup' failed to start automatically.
CRS-2807: Resource 'ora.xydb.db' failed to start automatically.
CRS-2807: Resource 'ora.xydb.s_stuwork.svc' failed to start automatically.
CRS-6016: Resource auto-start has completed for server k8s-rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.chad
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.net1.network
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
ora.ons
               ONLINE  ONLINE       k8s-rac01                STABLE
               ONLINE  ONLINE       k8s-rac02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                Started,STABLE
      2        ONLINE  OFFLINE                               STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  ONLINE       k8s-rac02                STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac01.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.k8s-rac02.vip
      1        ONLINE  ONLINE       k8s-rac02                STABLE
ora.qosmserver
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       k8s-rac01                STABLE
ora.xydb.db
      1        ONLINE  ONLINE       k8s-rac01                Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  OFFLINE                               STABLE
ora.xydb.s_stuwork.svc
      1        ONLINE  ONLINE       k8s-rac01                STABLE
      2        ONLINE  OFFLINE                               STABLE
--------------------------------------------------------------------------------


#此时对olr进行restore处理
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup

k8s-rac02     2023/11/18 18:49:48     /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr     724960844

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -restore /u01/app/grid/crsdata/k8s-rac02/olr/autobackup_20231118_184948.olr
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     

#再次检查ocrcheck -local，发现为succeeded
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck 
PROT-602: Failed to retrieve data from the cluster registry
[root@k8s-rac02 trace]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 trace]# 

------------------------------------------------------------------------
#(3)
#但是此时再次启动cluster报错，因为还原了Olr后与已经打的补丁不一致
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl start cluster
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.
[root@k8s-rac02 dispatcher.d]# /u01/app/19.0.0/grid/bin/crsctl check crs
CRS-4639: Could not contact Oracle High Availability Services

[root@k8s-rac02 dispatcher.d]# ps -ef|grep grid|grep app|awk '{print $2}'|xargs kill -9

[root@k8s-rac02 dispatcher.d]# ps -ef|grep grid
root     14717 11600  0 11:51 pts/4    00:00:00 grep --color=auto grid
root     26985 11598  0 Nov21 pts/2    00:00:00 su - grid
grid     26987 26985  0 Nov21 pts/2    00:00:00 -bash
grid     29819 26987  0 Nov21 pts/2    00:00:00 tail -100f alert_+ASM2.log


[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-6706: Oracle Clusterware Release patch level ('3976270074') does not match Software patch level ('724960844'). Oracle Clusterware cannot be started.
CRS-4000: Command Start failed, or completed with errors.

#解决办法：

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -unlock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crsunlock_k8s-rac02_2023-11-22_11-54-32AM.log
2023/11/22 11:54:33 CLSRSC-4012: Shutting down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:56 CLSRSC-4013: Successfully shut down Oracle Trace File Analyzer (TFA) Collector.
2023/11/22 11:54:58 CLSRSC-347: Successfully unlock /u01/app/19.0.0/grid

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/clscfg -localpatch
clscfg: EXISTING configuration version 0 detected.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83128
	 Available space (kbytes) :     408556
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/crs/install/rootcrs.sh -lock
Using configuration parameter file: /u01/app/19.0.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/k8s-rac02/crsconfig/crslock_k8s-rac02_2023-11-22_11-58-45AM.log
2023/11/22 11:58:52 CLSRSC-329: Replacing Clusterware entries in file 'oracle-ohasd.service'
[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl start crs -wait
CRS-4123: Starting Oracle High Availability Services-managed resources
CRS-2672: Attempting to start 'ora.evmd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.mdnsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.mdnsd' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.evmd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gpnpd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gpnpd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.gipcd' on 'k8s-rac02'
CRS-2676: Start of 'ora.gipcd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crf' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.cssdmonitor' on 'k8s-rac02'
CRS-2676: Start of 'ora.cssdmonitor' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cssd' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.diskmon' on 'k8s-rac02'
CRS-2676: Start of 'ora.diskmon' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.crf' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.cssd' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ctssd' on 'k8s-rac02'
CRS-2681: Clean of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.cluster_interconnect.haip' on 'k8s-rac02'
CRS-2676: Start of 'ora.cluster_interconnect.haip' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.ctssd' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.storage' on 'k8s-rac02'
CRS-2676: Start of 'ora.storage' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.crsd' on 'k8s-rac02'
CRS-2676: Start of 'ora.crsd' on 'k8s-rac02' succeeded
CRS-6017: Processing resource auto-start for servers: k8s-rac02
CRS-2672: Attempting to start 'ora.LISTENER.lsnr' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.chad' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.ons' on 'k8s-rac02'
CRS-2676: Start of 'ora.chad' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.LISTENER.lsnr' on 'k8s-rac02' succeeded
CRS-33672: Attempting to start resource group 'ora.asmgroup' on server 'k8s-rac02'
CRS-2672: Attempting to start 'ora.asmnet1.asmnetwork' on 'k8s-rac02'
CRS-2676: Start of 'ora.asmnet1.asmnetwork' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02'
CRS-2676: Start of 'ora.ASMNET1LSNR_ASM.lsnr' on 'k8s-rac02' succeeded
CRS-2679: Attempting to clean 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.ons' on 'k8s-rac02' succeeded
CRS-2681: Clean of 'ora.asm' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.asm' on 'k8s-rac02'
CRS-2676: Start of 'ora.asm' on 'k8s-rac02' succeeded
CRS-33676: Start of resource group 'ora.asmgroup' on server 'k8s-rac02' succeeded.
CRS-2672: Attempting to start 'ora.FRA.dg' on 'k8s-rac02'
CRS-2672: Attempting to start 'ora.DATA.dg' on 'k8s-rac02'
CRS-2676: Start of 'ora.FRA.dg' on 'k8s-rac02' succeeded
CRS-2676: Start of 'ora.DATA.dg' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.db' on 'k8s-rac02'
CRS-2676: Start of 'ora.xydb.db' on 'k8s-rac02' succeeded
CRS-2672: Attempting to start 'ora.xydb.s_stuwork.svc' on 'k8s-rac02'
CRS-2676: Start of 'ora.xydb.s_stuwork.svc' on 'k8s-rac02' succeeded
CRS-6016: Resource auto-start has completed for server k8s-rac02
CRS-6024: Completed start of Oracle Cluster Ready Services-managed resources
CRS-4123: Oracle High Availability Services has been started.
[root@k8s-rac02 ~]# 

[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck
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

[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrcheck -local
Status of Oracle Local Registry is as follows :
	 Version                  :          4
	 Total space (kbytes)     :     491684
	 Used space (kbytes)      :      83152
	 Available space (kbytes) :     408532
	 ID                       :   40730997
	 Device/File Name         : /u01/app/grid/crsdata/k8s-rac02/olr/k8s-rac02_19.olr
                                    Device/File integrity check succeeded

	 Local registry integrity check succeeded

	 Logical corruption check succeeded


#再次手动备份也正常了
[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -manualbackup

k8s-rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844     
[root@k8s-rac02 iscsi]# /u01/app/19.0.0/grid/bin/ocrconfig -local -showbackup
PROTL-24: No auto backups of the OLR are available at this time.

k8s-rac02     2023/11/22 12:12:26     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231122_121226.olr     3976270074     

k8s-rac02     2023/11/18 18:35:48     /u01/app/grid/crsdata/k8s-rac02/olr/backup_20231118_183548.olr     724960844    

#再次打补丁

```



#### 7.2.10.oracle 升级 root两个节点都要分别执行 --oracle upgrade

```bash
su - root

#k8s-rac01
#在非/和/root目录下执行

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/oracle/product/19.0.0/db_1

#k8s-rac01约25分钟 
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

#k8s-rac02

/u01/app/oracle/product/19.0.0/db_1/OPatch/opatchauto apply /opt/19.21patch/35642822 -oh /u01/app/oracle/product/19.0.0/db_1 

#k8s-rac02约33分钟(最长85 minutes, 13 seconds)

 
#检查补丁情况
su - oracle
cd $ORACLE_HOME/OPatch
./opatch lspatches  


[oracle@k8s-rac01 OPatch]$ ./opatch lspatches
35655527;OCW RELEASE UPDATE 19.21.0.0.0 (35655527)
35643107;Database Release Update : 19.21.0.0.231017 (35643107)

OPatch succeeded.


[oracle@k8s-rac02 OPatch]$ ./opatch lspatches
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


[oracle@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-rac01 OPatch]$ ./datapatch -sanity_checks 
[oracle@k8s-rac01 OPatch]$ ./datapatch -verbose 

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


[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl query crs releasepatch
Oracle Clusterware release patch level is [2204791795] and the complete list of patches [33575402 35553096 35643107 35652062 35655527 ] have been applied on the local node. The release patch string is [19.21.0.0.0].

[root@k8s-rac02 ~]# /u01/app/19.0.0/grid/bin/crsctl query css votedisk
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   dd0f67278ca64f02bf1be1f5476c5897 (/dev/sda) [OCR]
 2. ONLINE   0c98d89348b64f12bf7a4d996fdaff4f (/dev/sdb) [OCR]
 3. ONLINE   a4df36e0ad924f5abff76c6389c32ea8 (/dev/sdc) [OCR]

#常用集群检查命令
#grid用户
cluvfy  stage -post crsinst -n k8s-rac01,k8s-rac02 -verbose 
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


[oracle@k8s-rac01 ~]$ cd $ORACLE_HOME/OPatch
[oracle@k8s-rac01 OPatch]$ ./datapatch -verbose 

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
