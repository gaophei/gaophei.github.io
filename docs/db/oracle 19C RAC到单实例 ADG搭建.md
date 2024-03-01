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
select name,value,time_computed,datum_time from v$dataguard_stats;

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
select name,value,time_computed,datum_time from v$dataguard_stats;

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



## 6.ADG备份

### 6.1.主库备份及归档清理


### 6.2.备库备份及归档清理




### 6.3.备库磁盘满处理
#发生原因：主库impdp一个pdb全库数据，而备库从建立ADG后未曾清理归档日志，导致归档满
#备库error-log
```bash
[oracle@k8s-oracle-store ~]$ tail -f /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/alert_xydbdg.log

2024-03-01T00:33:23.249701+08:00
 rfs (PID:32363): Selected LNO:13 for T-2.S-87 dbid 2062989406 branch 1161189366
2024-03-01T00:33:23.279809+08:00
ARC1 (PID:8926): Archived Log entry 421 added for T-2.S-86 ID 0x7b6fba49 LAD:1
2024-03-01T00:33:23.625728+08:00
PR00 (PID:11197): Media Recovery Waiting for T-2.S-87 (in transit)
2024-03-01T00:33:23.626537+08:00
Recovery of Online Redo Log: Thread 2 Group 13 Seq 87 Reading mem 0
  Mem# 0: /u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_13.288.1159637923
  Mem# 1: /u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_13.319.1159637925
2024-03-01T00:33:28.144011+08:00
 rfs (PID:1021): Selected LNO:10 for T-1.S-97 dbid 2062989406 branch 1161189366
2024-03-01T00:33:28.144282+08:00
ARC3 (PID:8930): Archived Log entry 422 added for T-1.S-96 ID 0x7b6fba49 LAD:1
2024-03-01T00:33:28.676687+08:00
PR00 (PID:11197): Media Recovery Waiting for T-1.S-97 (in transit)
2024-03-01T00:33:28.677390+08:00
Recovery of Online Redo Log: Thread 1 Group 10 Seq 97 Reading mem 0
  Mem# 0: /u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_10.291.1159637897
  Mem# 1: /u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_10.314.1159637899
2024-03-01T11:52:55.889803+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.296.1162468273
2024-03-01T11:53:18.147589+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.297.1162468285
2024-03-01T11:53:27.402659+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.298.1162468311
DATAASSETS(5):Successfully added datafile 24 to media recovery
2024-03-01T11:53:27.624667+08:00
Buffer Cache Full DB Caching mode changing from FULL CACHING ENABLED to FULL CACHING DISABLED
Full DB Caching disabled: DEFAULT_CACHE_SIZE should be at least 1251 MBs bigger than current size.
DATAASSETS(5):Datafile #24: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.296.1162468273'
2024-03-01T11:53:27.770041+08:00
DATAASSETS(5):Successfully added datafile 25 to media recovery
DATAASSETS(5):Datafile #25: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.297.1162468285'
DATAASSETS(5):Successfully added datafile 26 to media recovery
DATAASSETS(5):Datafile #26: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.298.1162468311'
2024-03-01T11:54:33.225676+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.299.1162468333
2024-03-01T11:54:44.174645+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.300.1162468385
2024-03-01T11:54:55.424683+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.301.1162468399
2024-03-01T11:55:04.754159+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.302.1162468413
DATAASSETS(5):Successfully added datafile 27 to media recovery
DATAASSETS(5):Datafile #27: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.299.1162468333'
DATAASSETS(5):Successfully added datafile 28 to media recovery
DATAASSETS(5):Datafile #28: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.300.1162468385'
DATAASSETS(5):Successfully added datafile 29 to media recovery
DATAASSETS(5):Datafile #29: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.301.1162468399'
DATAASSETS(5):Successfully added datafile 30 to media recovery
DATAASSETS(5):Datafile #30: '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.302.1162468413'
2024-03-01T11:56:13.052801+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.303.1162468429
2024-03-01T11:56:24.184431+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.304.1162468479
2024-03-01T11:56:37.688443+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.305.1162468491
2024-03-01T11:56:44.288583+08:00
DATAASSETS(5):Recovery created file /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.306.1162468505
2024-03-01T11:56:45.142948+08:00
DATAASSETS(5):Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_pr00_11197.trc:
ORA-27072: File I/O error
Linux-x86_64 Error: 28: No space left on device
Additional information: 4
Additional information: 16128
Additional information: 4294967295
2024-03-01T11:56:45.261992+08:00
DATAASSETS(5):Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_pr00_11197.trc:
ORA-19502: write error on file "/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517", block number 16128 (block size=8192)
ORA-27072: File I/O error
Linux-x86_64 Error: 28: No space left on device
Additional information: 4
Additional information: 16128
Additional information: 4294967295
DATAASSETS(5):File #35 added to control file as 'UNNAMED00035'.
DATAASSETS(5):Originally created as:
DATAASSETS(5):'+DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.307.1162468517'
DATAASSETS(5):Recovery was unable to create the file as:
DATAASSETS(5):'/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517'
2024-03-01T11:56:45.923349+08:00
PR00 (PID:11197): MRP0: Background Media Recovery terminated with error 1274
2024-03-01T11:56:45.923594+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_pr00_11197.trc:
ORA-01274: cannot add data file that was originally created as '+DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.307.1162468517'
PR00 (PID:11197): Managed Standby Recovery not using Real Time Apply
2024-03-01T11:56:47.501093+08:00
Recovery interrupted!
2024-03-01T11:56:58.471770+08:00

IM on ADG: Start of Empty Journal

IM on ADG: End of Empty Journal
Recovered data files to a consistent state at change 36581438
Stopping change tracking
2024-03-01T11:56:58.474453+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_pr00_11197.trc:
ORA-01274: cannot add data file that was originally created as '+DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.307.1162468517'
2024-03-01T11:56:58.504363+08:00
Background Media Recovery process shutdown (xydbdg)
2024-03-01T12:01:22.518901+08:00
ARC1 (PID:8926): Encountered disk I/O error 19502
2024-03-01T12:01:22.583286+08:00
Closing local archive destination LOG_ARCHIVE_DEST_1 '/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_97_1161189366.dbf', error=19502 (xydbdg)
2024-03-01T12:01:22.681837+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_arc1_8926.trc:
ORA-27072: File I/O error
Additional information: 4
Additional information: 1
Additional information: 3584
ORA-19502: write error on file "/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_97_1161189366.dbf", block number 1 (block size=512)
2024-03-01T12:01:22.685414+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_arc1_8926.trc:
ORA-19502: write error on file "/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_97_1161189366.dbf", block number 1 (block size=512)
ORA-27072: File I/O error
Additional information: 4
Additional information: 1
Additional information: 3584
ORA-19502: write error on file "/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_97_1161189366.dbf", block number 1 (block size=512)
ARC1 (PID:8926): I/O error 19502 archiving LNO:10 to '/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/1_97_1161189366.dbf'
2024-03-01T12:01:22.719713+08:00
 rfs (PID:1021): Selected LNO:11 for T-1.S-98 dbid 2062989406 branch 1161189366
2024-03-01T12:01:22.956380+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_arc1_8926.trc:
ORA-16038: log 10 sequence# 97 cannot be archived
ORA-19502: write error on file "", block number  (block size=)
ORA-00312: online log 10 thread 1: '/u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_10.291.1159637897'
ORA-00312: online log 10 thread 1: '/u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_10.314.1159637899'
2024-03-01T12:01:22.956466+08:00
ARC1 (PID:8926): Archival error occurred on a closed thread, archiver continuing
2024-03-01T12:01:22.956528+08:00
ORACLE Instance xydbdg, archival error, archiver continuing
2024-03-01T12:04:41.841082+08:00
 rfs (PID:32363): Selected LNO:14 for T-2.S-88 dbid 2062989406 branch 1161189366
2024-03-01T12:07:17.316892+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_arc2_8928.trc:
ORA-19502: write error on file "/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_87_1161189366.dbf", block number 1 (block size=512)
ORA-27072: File I/O error
Additional information: 4
Additional information: 1
Additional information: 3584
ORA-19502: write error on file "/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_87_1161189366.dbf", block number 1 (block size=512)
ARC2 (PID:8928): I/O error 19502 archiving LNO:13 to '/u01/app/oracle/fast_recovery_area/xydbdg/archivelog/2_87_1161189366.dbf'
2024-03-01T12:07:17.337549+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_arc2_8928.trc:
ORA-16038: log 13 sequence# 87 cannot be archived
ORA-19502: write error on file "", block number  (block size=)
ORA-00312: online log 13 thread 2: '/u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_13.288.1159637923'
ORA-00312: online log 13 thread 2: '/u01/app/oracle/oradata/xydbdg/onlinelog01/xydb/onlinelog/group_13.319.1159637925'


```



#主库alter_xydb1.log

```bash
[oracle@k8s-rac01 ~]$ tail -f /u01/app/oracle/diag/rdbms/xydb/xydb1/trace/alert_xydb1.log

2024-03-01T00:32:53.744017+08:00
ARC3 (PID:24801): Archived Log entry 1611 added for T-1.S-96 ID 0x7b6fba49 LAD:1
2024-03-01T01:01:20.646253+08:00
TABLE SYS.WRP$_REPORTS: ADDED INTERVAL PARTITION SYS_P1438 (5174) VALUES LESS THAN (TO_DATE(' 2024-03-02 01:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN'))
TABLE SYS.WRP$_REPORTS_DETAILS: ADDED INTERVAL PARTITION SYS_P1439 (5174) VALUES LESS THAN (TO_DATE(' 2024-03-02 01:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN'))
2024-03-01T02:00:00.079652+08:00
Closing Resource Manager plan via scheduler window
Clearing Resource Manager CDB plan via parameter
2024-03-01T11:23:58.291206+08:00
TABLE AUDSYS.AUD$UNIFIED: ADDED INTERVAL PARTITION SYS_P1442 (117) VALUES LESS THAN (TIMESTAMP' 2024-04-01 00:00:00')
2024-03-01T11:25:35.385005+08:00
DATAASSETS(5):TABLE AUDSYS.AUD$UNIFIED: ADDED INTERVAL PARTITION SYS_P412 (117) VALUES LESS THAN (TIMESTAMP' 2024-04-01 00:00:00')
2024-03-01T11:50:37.642111+08:00
DATAASSETS(5):Resize operation completed for file# 19, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297, old size 583680K, new size 593920K
2024-03-01T11:50:41.760727+08:00
DATAASSETS(5):Started service SYS.KUPC$C_1_20240301115038_0/SYS$SYS.KUPC$C_1_20240301115038_0.DATAASSETS/SYS$SYS.KUPC$C_1_20240301115038_0.DATAASSETS
2024-03-01T11:50:41.948771+08:00
DATAASSETS(5):Started service SYS.KUPC$S_1_20240301115038_0/SYS$SYS.KUPC$S_1_20240301115038_0.DATAASSETS/SYS$SYS.KUPC$S_1_20240301115038_0.DATAASSETS
2024-03-01T11:50:42.696551+08:00
DATAASSETS(5):DM00 started with pid=162, OS id=16122, job PDBADMIN.SYS_IMPORT_FULL_01
2024-03-01T11:50:46.113595+08:00
DATAASSETS(5):
DATAASSETS(5):DW00 started with pid=166, OS id=17272, wid=1, job PDBADMIN.SYS_IMPORT_FULL_01
2024-03-01T11:50:50.129359+08:00
DATAASSETS(5):Resize operation completed for file# 19, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297, old size 593920K, new size 604160K
2024-03-01T11:50:51.125043+08:00
DATAASSETS(5):Resize operation completed for file# 19, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297, old size 604160K, new size 614400K
DATAASSETS(5):Resize operation completed for file# 19, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297, old size 614400K, new size 624640K
2024-03-01T11:50:52.607384+08:00
DATAASSETS(5):Resize operation completed for file# 19, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297, old size 624640K, new size 634880K
2024-03-01T11:50:53.627727+08:00
DATAASSETS(5):Resize operation completed for file# 19, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297, old size 634880K, new size 645120K
2024-03-01T11:51:12.906850+08:00
DATAASSETS(5):CREATE TABLESPACE "IDC_DATA_STANDCODE" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:52:13.134663+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "IDC_DATA_STANDCODE" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
DATAASSETS(5):CREATE UNDO TABLESPACE "UNDO_2" DATAFILE SIZE 173015040 AUTOEXTEND ON NEXT 173015040 MAXSIZE 32767M BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE
DATAASSETS(5):ORA-1543 signalled during: CREATE UNDO TABLESPACE "UNDO_2" DATAFILE SIZE 173015040 AUTOEXTEND ON NEXT 173015040 MAXSIZE 32767M BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE...
DATAASSETS(5):CREATE TEMPORARY TABLESPACE "TEMP" TEMPFILE SIZE 159383552 AUTOEXTEND ON NEXT 655360 MAXSIZE 32767M EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1048576
DATAASSETS(5):ORA-1543 signalled during: CREATE TEMPORARY TABLESPACE "TEMP" TEMPFILE SIZE 159383552 AUTOEXTEND ON NEXT 655360 MAXSIZE 32767M EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1048576...
DATAASSETS(5):CREATE UNDO TABLESPACE "UNDOTBS1" DATAFILE SIZE 104857600 AUTOEXTEND ON NEXT 5242880 MAXSIZE 32767M BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE
DATAASSETS(5):ORA-1543 signalled during: CREATE UNDO TABLESPACE "UNDOTBS1" DATAFILE SIZE 104857600 AUTOEXTEND ON NEXT 5242880 MAXSIZE 32767M BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE...
DATAASSETS(5):CREATE TABLESPACE "IDC_DATA_DATAQUALITY" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:53:49.223438+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "IDC_DATA_DATAQUALITY" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
DATAASSETS(5):CREATE TABLESPACE "IDC_DATA_SHAREDB" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:55:34.176039+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "IDC_DATA_SHAREDB" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
DATAASSETS(5):CREATE TABLESPACE "IDC_DATA_API" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:56:54.427683+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "IDC_DATA_API" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
DATAASSETS(5):CREATE TABLESPACE "IDC_DATA_SWOPWORK" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:57:37.678917+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "IDC_DATA_SWOPWORK" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
DATAASSETS(5):CREATE TABLESPACE "IDC_DATA_ASSETS" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:58:44.512441+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "IDC_DATA_ASSETS" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
DATAASSETS(5):CREATE TABLESPACE "USERS" DATAFILE SIZE 74711040 AUTOEXTEND ON NEXT 74711040 MAXSIZE 32767M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:58:45.867230+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "USERS" DATAFILE SIZE 74711040 AUTOEXTEND ON NEXT 74711040 MAXSIZE 32767M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
DATAASSETS(5):CREATE TABLESPACE "IDC_DATA_SWOP" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T11:59:39.786096+08:00
DATAASSETS(5):Completed: CREATE TABLESPACE "IDC_DATA_SWOP" DATAFILE SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M,SIZE 1073741824 AUTOEXTEND ON NEXT 1073741824 MAXSIZE 31744M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT MANAGEMENT LOCAL AUTOALLOCATE DEFAULT  NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO
2024-03-01T12:00:14.808585+08:00
DATAASSETS(5):Data Pump Worker: Cannot set an SCN larger than the current SCN. If a Streams Capture configuration was imported then the Apply that processes the captured messages needs to be dropped and recreated. See My Oracle Support article number 1380295.1.
2024-03-01T12:00:47.438983+08:00
Thread 1 advanced to log sequence 98 (LGWR switch),  current SCN: 36587578
  Current log# 1 seq# 98 mem# 0: +DATA/XYDB/ONLINELOG/group_1.262.1153250787
  Current log# 1 seq# 98 mem# 1: +FRA/XYDB/ONLINELOG/group_1.257.1153250793
2024-03-01T12:00:51.023527+08:00
ARC0 (PID:24788): Archived Log entry 1613 added for T-1.S-97 ID 0x7b6fba49 LAD:1
2024-03-01T12:01:06.827821+08:00
DATAASSETS(5):Resize operation completed for file# 20, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297, old size 512000K, new size 522240K
2024-03-01T12:01:07.409312+08:00
DATAASSETS(5):Resize operation completed for file# 20, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297, old size 522240K, new size 542720K
2024-03-01T12:03:14.576500+08:00
DATAASSETS(5):Resize operation completed for file# 19, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297, old size 645120K, new size 655360K
2024-03-01T12:04:06.072891+08:00
Thread 1 advanced to log sequence 99 (LGWR switch),  current SCN: 36618681
  Current log# 2 seq# 99 mem# 0: +DATA/XYDB/ONLINELOG/group_2.263.1153250787
  Current log# 2 seq# 99 mem# 1: +FRA/XYDB/ONLINELOG/group_2.258.1153250793
2024-03-01T12:04:13.367897+08:00
ARC1 (PID:24796): Archived Log entry 1616 added for T-1.S-98 ID 0x7b6fba49 LAD:1
2024-03-01T12:04:40.136996+08:00
Thread 1 advanced to log sequence 100 (LGWR switch),  current SCN: 36622591
  Current log# 1 seq# 100 mem# 0: +DATA/XYDB/ONLINELOG/group_1.262.1153250787
  Current log# 1 seq# 100 mem# 1: +FRA/XYDB/ONLINELOG/group_1.257.1153250793
2024-03-01T12:04:43.655384+08:00
ARC2 (PID:24798): Archived Log entry 1618 added for T-1.S-99 ID 0x7b6fba49 LAD:1
2024-03-01T12:05:00.419762+08:00
TT03 (PID:19749): LAD:2 not using SRLs; cannot reconnect
2024-03-01T12:05:00.419950+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydb/xydb1/trace/xydb1_tt03_19749.trc:
ORA-19502: write error on file "", block number  (block size=)
TT03 (PID:19749): Error 19502 for LNO:1 to 'xydbdg'
2024-03-01T12:05:00.458257+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydb/xydb1/trace/xydb1_tt03_19749.trc:
ORA-19502: write error on file "", block number  (block size=)
2024-03-01T12:05:00.458443+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydb/xydb1/trace/xydb1_tt03_19749.trc:
ORA-19502: write error on file "", block number  (block size=)
2024-03-01T12:10:01.613026+08:00
DATAASSETS(5):Resize operation completed for file# 20, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297, old size 573440K, new size 583680K
2024-03-01T12:10:23.632574+08:00
DATAASSETS(5):
DATAASSETS(5):XDB installed.
DATAASSETS(5):
DATAASSETS(5):XDB initialized.
2024-03-01T12:10:50.801678+08:00
DATAASSETS(5):TABLE SYS.WRI$_OPTSTAT_HISTHEAD_HISTORY: ADDED INTERVAL PARTITION SYS_P475 (45351) VALUES LESS THAN (TO_DATE(' 2024-03-02 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN'))
2024-03-01T12:11:42.601308+08:00
TT06 (PID:17202): LAD:2 not using SRLs; cannot reconnect
2024-03-01T12:11:42.601494+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydb/xydb1/trace/xydb1_tt06_17202.trc:
ORA-19502: write error on file "", block number  (block size=)
TT06 (PID:17202): Error 19502 for LNO:1 to 'xydbdg'
2024-03-01T12:11:42.642797+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydb/xydb1/trace/xydb1_tt06_17202.trc:
ORA-19502: write error on file "", block number  (block size=)
2024-03-01T12:11:42.643045+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydb/xydb1/trace/xydb1_tt06_17202.trc:
ORA-19502: write error on file "", block number  (block size=)
2024-03-01T12:13:05.595364+08:00
DATAASSETS(5):TABLE AUDSYS.AUD$UNIFIED: ADDED INTERVAL PARTITION SYS_P478 (111) VALUES LESS THAN (TIMESTAMP' 2023-10-01 00:00:00')
DATAASSETS(5):TABLE AUDSYS.AUD$UNIFIED: ADDED INTERVAL PARTITION SYS_P485 (112) VALUES LESS THAN (TIMESTAMP' 2023-11-01 00:00:00')
2024-03-01T12:13:12.072380+08:00
DATAASSETS(5):Resize operation completed for file# 20, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297, old size 583680K, new size 593920K
2024-03-01T12:13:12.578468+08:00
DATAASSETS(5):Resize operation completed for file# 20, fname +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297, old size 593920K, new size 614400K
2024-03-01T12:13:13.605189+08:00
Thread 1 advanced to log sequence 101 (LGWR switch),  current SCN: 36730604
  Current log# 2 seq# 101 mem# 0: +DATA/XYDB/ONLINELOG/group_2.263.1153250787
  Current log# 2 seq# 101 mem# 1: +FRA/XYDB/ONLINELOG/group_2.258.1153250793
2024-03-01T12:13:16.750479+08:00
ARC0 (PID:24788): Archived Log entry 1620 added for T-1.S-100 ID 0x7b6fba49 LAD:1
2024-03-01T12:13:17.959002+08:00
DATAASSETS(5):TABLE AUDSYS.AUD$UNIFIED: ADDED INTERVAL PARTITION SYS_P492 (114) VALUES LESS THAN (TIMESTAMP' 2024-01-01 00:00:00')
DATAASSETS(5):TABLE AUDSYS.AUD$UNIFIED: ADDED INTERVAL PARTITION SYS_P499 (115) VALUES LESS THAN (TIMESTAMP' 2024-02-01 00:00:00')
2024-03-01T12:13:51.285254+08:00
DATAASSETS(5):Stopped service SYS.KUPC$C_1_20240301115038_0
2024-03-01T12:13:51.983155+08:00
DATAASSETS(5):Stopped service SYS.KUPC$S_1_20240301115038_0
2024-03-01T12:13:53.249126+08:00
DATAASSETS(5):DM00 stopped with pid=162, OS id=16122, job PDBADMIN.SYS_IMPORT_FULL_01 
2024-03-01T12:17:17.110832+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:22:35.175846+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:27:53.599789+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:33:11.550464+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:38:29.479865+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:43:47.423361+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:49:05.401992+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:54:23.336376+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T12:59:41.304979+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:04:59.253026+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:10:17.201146+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:15:35.153006+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:20:53.093657+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:26:11.046401+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:31:28.985539+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:36:46.951189+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T13:42:04.900197+08:00
TT00 (PID:24790): Error 2002 received logging on to the standby
2024-03-01T14:00:00.117131+08:00
STUWORK(3):Setting Resource Manager plan DEFAULT_MAINTENANCE_PLAN via parameter
2024-03-01T14:00:00.219034+08:00
PORTAL(4):Setting Resource Manager plan SCHEDULER[0x4D52]:DEFAULT_MAINTENANCE_PLAN via scheduler window
PORTAL(4):Setting Resource Manager plan DEFAULT_MAINTENANCE_PLAN via parameter
2024-03-01T14:00:00.380089+08:00
DATAASSETS(5):Setting Resource Manager plan DEFAULT_MAINTENANCE_PLAN via parameter
2024-03-01T14:00:08.137753+08:00
STUWORK(3):TABLE SYS.WRI$_OPTSTAT_HISTHEAD_HISTORY: ADDED INTERVAL PARTITION SYS_P1056 (45351) VALUES LESS THAN (TO_DATE(' 2024-03-02 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN'))
STUWORK(3):TABLE SYS.WRI$_OPTSTAT_HISTGRM_HISTORY: ADDED INTERVAL PARTITION SYS_P1059 (45351) VALUES LESS THAN (TO_DATE(' 2024-03-02 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN'))
2024-03-01T14:00:22.182429+08:00
DATAASSETS(5):TABLE SYS.WRI$_OPTSTAT_HISTGRM_HISTORY: ADDED INTERVAL PARTITION SYS_P506 (45351) VALUES LESS THAN (TO_DATE(' 2024-03-02 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN'))

```





#此时检查备库磁盘，果然100%，抓紧清理磁盘，执行

```bash
[oracle@k8s-oracle-store ~]$ df -h
Filesystem           Size  Used Avail Use% Mounted on
devtmpfs              16G     0   16G   0% /dev
tmpfs                 16G     0   16G   0% /dev/shm
tmpfs                 16G  433M   16G   3% /run
tmpfs                 16G     0   16G   0% /sys/fs/cgroup
/dev/mapper/ol-root   87G   87G  100k  100% /
/dev/vda1           1014M  204M  811M  21% /boot
tmpfs                3.2G     0  3.2G   0% /run/user/0


SYS@xydbdg> show parameter LOG_ARCHIVE_DEST_2

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
log_archive_dest_2		     string	 SERVICE=xydb LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)                                        DB_UNIQUE_NAME=xydb

log_archive_dest_20		     string
log_archive_dest_21		     string
log_archive_dest_22		     string
log_archive_dest_23		     string
log_archive_dest_24		     string
log_archive_dest_25		     string
log_archive_dest_26		     string
log_archive_dest_27		     string
log_archive_dest_28		     string
log_archive_dest_29		     string


SYS@xydbdg> show parameter LOG_ARCHIVE_DEST_1

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
log_archive_dest_1		     string	 LOCATION=/u01/app/oracle/fast_recovery_area/xydbdg/archivelog                                            VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=xydbdg
log_archive_dest_10		     string
log_archive_dest_11		     string
log_archive_dest_12		     string
log_archive_dest_13		     string
log_archive_dest_14		     string
log_archive_dest_15		     string
log_archive_dest_16		     string
log_archive_dest_17		     string
log_archive_dest_18		     string
log_archive_dest_19		     string


SYS@xydbdg> archive log list;
Database log mode	       Archive Mode
Automatic archival	       Enabled
Archive destination	       /u01/app/oracle/fast_recovery_area/xydbdg/archivelog
Oldest online log sequence     0
Next log sequence to archive   0
Current log sequence	       0
SYS@xydbdg> 


[root@k8s-oracle-store ~]# cd /u01/app/oracle/fast_recovery_area/xydbdg/archivelog
[root@k8s-oracle-store archivelog]# du -hs
17G	.

[root@k8s-oracle-store archivelog]# ll |wc -l
364
[root@k8s-oracle-store archivelog]# du -hs
18G	.
[root@k8s-oracle-store archivelog]# ll -rth|more
total 18G
-rw-r----- 1 oracle oinstall 6.5K Feb  1 16:38 2_390_1153250787.dbf
-rw-r----- 1 oracle oinstall  13M Feb  1 18:11 2_391_1153250787.dbf
-rw-r----- 1 oracle oinstall  15M Feb  1 18:11 1_414_1153250787.dbf
-rw-r----- 1 oracle oinstall  13K Feb  1 18:11 1_415_1153250787.dbf
-rw-r----- 1 oracle oinstall  44M Feb  2 00:30 2_392_1153250787.dbf
-rw-r----- 1 oracle oinstall 155M Feb  2 00:30 1_416_1153250787.dbf
-rw-r----- 1 oracle oinstall 9.0K Feb  2 00:30 1_417_1153250787.dbf
-rw-r----- 1 oracle oinstall  10K Feb  2 00:30 2_393_1153250787.dbf
-rw-r----- 1 oracle oinstall  85K Feb  2 00:32 2_394_1153250787.dbf
-rw-r----- 1 oracle oinstall  82K Feb  2 00:32 1_418_1153250787.dbf
-rw-r----- 1 oracle oinstall 7.0K Feb  2 00:32 2_395_1153250787.dbf
-rw-r----- 1 oracle oinstall 7.5K Feb  2 00:32 1_419_1153250787.dbf
-rw-r----- 1 oracle oinstall 4.5K Feb  2 00:32 2_396_1153250787.dbf
-rw-r----- 1 oracle oinstall 5.0K Feb  2 00:32 1_420_1153250787.dbf
-rw-r----- 1 oracle oinstall 169M Feb  2 14:00 1_421_1153250787.dbf
-rw-r----- 1 oracle oinstall  43M Feb  2 16:23 1_422_1153250787.dbf
-rw-r----- 1 oracle oinstall 113M Feb  2 16:23 2_397_1153250787.dbf
-rw-r----- 1 oracle oinstall  69K Feb  2 16:25 1_423_1153250787.dbf
-rw-r----- 1 oracle oinstall  66K Feb  2 16:25 2_398_1153250787.dbf
-rw-r----- 1 oracle oinstall 1.0K Feb  2 16:36 1_424_1153250787.dbf
-rw-r----- 1 oracle oinstall 1.0K Feb  2 16:36 2_399_1153250787.dbf
-rw-r----- 1 oracle oinstall  19M Feb  2 17:36 1_425_1153250787.dbf

#竟然是归档日志一直未清理

#查看归档应用情况
SYS@xydbdg> select thread#,sequence#,creator,applied,first_time,next_time from v$archived_log where applied='YES' order by sequence#;

   THREAD#  SEQUENCE# CREATOR APPLIED	FIRST_TIME	    NEXT_TIME
---------- ---------- ------- --------- ------------------- -------------------
	 2	    3 ARCH    YES	2024-02-17 17:07:48 2024-02-17 17:15:24
	 1	    4 ARCH    YES	2024-02-17 17:07:26 2024-02-17 17:15:23
	 2	    4 ARCH    YES	2024-02-17 17:16:43 2024-02-17 17:16:52
	 2	    5 ARCH    YES	2024-02-17 17:36:23 2024-02-17 17:36:23
	 1	    6 ARCH    YES	2024-02-17 17:16:51 2024-02-17 17:34:57
	 1	    6 LGWR    YES	2024-02-17 17:16:51 2024-02-17 17:34:57
	 2	    6 ARCH    YES	2024-02-17 17:36:23 2024-02-18 00:30:07
	 1	    7 FGRD    YES	2024-02-17 17:34:57 2024-02-17 17:36:08
	 2	    7 ARCH    YES	2024-02-18 00:30:07 2024-02-18 00:30:18
	 1	    8 ARCH    YES	2024-02-17 17:35:56 2024-02-17 17:36:15
	 2	    8 ARCH    YES	2024-02-18 00:30:18 2024-02-18 00:33:01
	 1	    9 ARCH    YES	2024-02-17 17:36:15 2024-02-18 00:30:09
	 2	    9 ARCH    YES	2024-02-18 00:33:01 2024-02-18 00:33:09
	 1	   10 ARCH    YES	2024-02-18 00:30:09 2024-02-18 00:30:18
	 2	   10 ARCH    YES	2024-02-18 00:33:09 2024-02-18 00:33:14
	 1	   11 ARCH    YES	2024-02-18 00:30:18 2024-02-18 00:30:21
	 2	   11 ARCH    YES	2024-02-18 00:33:14 2024-02-18 18:00:10
	 1	   12 ARCH    YES	2024-02-18 00:30:21 2024-02-18 00:33:01
	 2	   12 ARCH    YES	2024-02-18 18:00:10 2024-02-18 23:00:36
	 1	   13 ARCH    YES	2024-02-18 00:33:01 2024-02-18 00:33:13
	 2	   13 ARCH    YES	2024-02-18 23:00:36 2024-02-19 00:30:06
	 1	   14 ARCH    YES	2024-02-18 00:33:13 2024-02-18 00:33:16
	 2	   14 ARCH    YES	2024-02-19 00:30:06 2024-02-19 00:30:14
	 1	   15 ARCH    YES	2024-02-18 00:33:16 2024-02-18 09:02:46
	 2	   15 ARCH    YES	2024-02-19 00:30:14 2024-02-19 00:32:53
	 1	   16 ARCH    YES	2024-02-18 09:02:46 2024-02-18 18:00:10
	 2	   16 ARCH    YES	2024-02-19 00:32:53 2024-02-19 00:33:01
	 1	   17 ARCH    YES	2024-02-18 18:00:10 2024-02-19 00:30:07
	 2	   17 ARCH    YES	2024-02-19 00:33:01 2024-02-19 00:33:07
	 1	   18 ARCH    YES	2024-02-19 00:30:07 2024-02-19 00:30:13
	 2	   18 ARCH    YES	2024-02-19 00:33:07 2024-02-19 19:46:07
	 1	   19 ARCH    YES	2024-02-19 00:30:13 2024-02-19 00:32:55
	 2	   19 ARCH    YES	2024-02-19 19:46:07 2024-02-20 00:30:06
	 1	   20 ARCH    YES	2024-02-19 00:32:55 2024-02-19 00:33:04
	 2	   20 ARCH    YES	2024-02-20 00:30:06 2024-02-20 00:30:15
	 1	   21 ARCH    YES	2024-02-19 00:33:04 2024-02-19 00:33:10
	 2	   21 ARCH    YES	2024-02-20 00:30:15 2024-02-20 00:32:19
	 1	   22 ARCH    YES	2024-02-19 00:33:10 2024-02-19 15:00:51
	 2	   22 ARCH    YES	2024-02-20 00:32:19 2024-02-20 00:32:28
	 1	   23 ARCH    YES	2024-02-19 15:00:51 2024-02-20 00:30:07
	 2	   23 ARCH    YES	2024-02-20 00:32:28 2024-02-20 00:32:31
	 1	   24 ARCH    YES	2024-02-20 00:30:07 2024-02-20 00:30:16
	 2	   24 ARCH    YES	2024-02-20 00:32:31 2024-02-20 10:00:51
	 1	   25 ARCH    YES	2024-02-20 00:30:16 2024-02-20 00:32:19
	 2	   25 ARCH    YES	2024-02-20 10:00:51 2024-02-21 00:30:07
	 1	   26 ARCH    YES	2024-02-20 00:32:19 2024-02-20 00:32:28
	 2	   26 ARCH    YES	2024-02-21 00:30:07 2024-02-21 00:30:14
	 1	   27 ARCH    YES	2024-02-20 00:32:28 2024-02-20 00:32:32
	 2	   27 ARCH    YES	2024-02-21 00:30:14 2024-02-21 00:32:27
	 1	   28 ARCH    YES	2024-02-20 00:32:32 2024-02-20 00:32:35
	 2	   28 ARCH    YES	2024-02-21 00:32:27 2024-02-21 00:32:38
	 1	   29 ARCH    YES	2024-02-20 00:32:35 2024-02-20 14:00:14
	 2	   29 ARCH    YES	2024-02-21 00:32:38 2024-02-21 00:32:44
	 1	   30 ARCH    YES	2024-02-20 14:00:14 2024-02-20 22:02:21
	 2	   30 ARCH    YES	2024-02-21 00:32:44 2024-02-21 13:00:09
	 1	   31 ARCH    YES	2024-02-20 22:02:21 2024-02-21 00:30:08
	 2	   31 ARCH    YES	2024-02-21 13:00:09 2024-02-22 00:30:06
	 1	   32 ARCH    YES	2024-02-21 00:30:08 2024-02-21 00:30:14
	 2	   32 ARCH    YES	2024-02-22 00:30:06 2024-02-22 00:30:18
	 1	   33 ARCH    YES	2024-02-21 00:30:14 2024-02-21 00:32:30
	 2	   33 ARCH    YES	2024-02-22 00:30:18 2024-02-22 00:32:30
	 1	   34 ARCH    YES	2024-02-21 00:32:30 2024-02-21 00:32:39
	 2	   34 ARCH    YES	2024-02-22 00:32:30 2024-02-22 00:32:36
	 1	   35 ARCH    YES	2024-02-21 00:32:39 2024-02-21 00:32:45
	 2	   35 ARCH    YES	2024-02-22 00:32:36 2024-02-22 00:32:42
	 1	   36 ARCH    YES	2024-02-21 00:32:45 2024-02-21 00:32:51
	 2	   36 ARCH    YES	2024-02-22 00:32:42 2024-02-22 13:08:42
	 1	   37 ARCH    YES	2024-02-21 00:32:51 2024-02-21 13:00:09
	 2	   37 ARCH    YES	2024-02-22 13:08:42 2024-02-22 22:02:00
	 1	   38 ARCH    YES	2024-02-21 13:00:09 2024-02-21 22:01:20
	 2	   38 ARCH    YES	2024-02-22 22:02:00 2024-02-23 00:30:06
	 1	   39 ARCH    YES	2024-02-21 22:01:20 2024-02-22 00:30:06
	 2	   39 ARCH    YES	2024-02-23 00:30:06 2024-02-23 00:30:14
	 1	   40 ARCH    YES	2024-02-22 00:30:06 2024-02-22 00:30:18
	 2	   40 ARCH    YES	2024-02-23 00:30:14 2024-02-23 00:32:26
	 1	   41 ARCH    YES	2024-02-22 00:30:18 2024-02-22 00:32:29
	 2	   41 ARCH    YES	2024-02-23 00:32:26 2024-02-23 00:32:33
	 1	   42 ARCH    YES	2024-02-22 00:32:29 2024-02-22 00:32:41
	 2	   42 ARCH    YES	2024-02-23 00:32:33 2024-02-23 00:32:39
	 1	   43 ARCH    YES	2024-02-22 00:32:41 2024-02-22 00:32:44
	 2	   43 ARCH    YES	2024-02-23 00:32:39 2024-02-23 13:17:52
	 1	   44 ARCH    YES	2024-02-22 00:32:44 2024-02-22 15:08:24
	 2	   44 ARCH    YES	2024-02-23 13:17:52 2024-02-23 22:01:48
	 1	   45 ARCH    YES	2024-02-22 15:08:24 2024-02-23 00:30:06
	 2	   45 ARCH    YES	2024-02-23 22:01:48 2024-02-24 00:30:06
	 1	   46 ARCH    YES	2024-02-23 00:30:06 2024-02-23 00:30:12
	 2	   46 ARCH    YES	2024-02-24 00:30:06 2024-02-24 00:30:15
	 1	   47 ARCH    YES	2024-02-23 00:30:12 2024-02-23 00:32:28
	 2	   47 ARCH    YES	2024-02-24 00:30:15 2024-02-24 00:32:35
	 1	   48 ARCH    YES	2024-02-23 00:32:28 2024-02-23 00:32:37
	 2	   48 ARCH    YES	2024-02-24 00:32:35 2024-02-24 00:32:44
	 1	   49 ARCH    YES	2024-02-23 00:32:37 2024-02-23 00:32:43
	 2	   49 ARCH    YES	2024-02-24 00:32:44 2024-02-24 00:32:47
	 1	   50 ARCH    YES	2024-02-23 00:32:43 2024-02-23 15:18:24
	 2	   50 ARCH    YES	2024-02-24 00:32:47 2024-02-24 13:00:15
	 1	   51 ARCH    YES	2024-02-23 15:18:24 2024-02-24 00:30:09
	 2	   51 ARCH    YES	2024-02-24 13:00:15 2024-02-25 00:30:07
	 1	   52 ARCH    YES	2024-02-24 00:30:09 2024-02-24 00:30:15
	 2	   52 ARCH    YES	2024-02-25 00:30:07 2024-02-25 00:30:15
	 1	   53 ARCH    YES	2024-02-24 00:30:15 2024-02-24 00:32:36
	 2	   53 ARCH    YES	2024-02-25 00:30:15 2024-02-25 00:32:35
	 1	   54 ARCH    YES	2024-02-24 00:32:36 2024-02-24 00:32:45
	 2	   54 ARCH    YES	2024-02-25 00:32:35 2024-02-25 00:32:39
	 1	   55 ARCH    YES	2024-02-24 00:32:45 2024-02-24 00:32:48
	 2	   55 ARCH    YES	2024-02-25 00:32:39 2024-02-25 00:32:46
	 1	   56 ARCH    YES	2024-02-24 00:32:48 2024-02-24 10:04:09
	 2	   56 ARCH    YES	2024-02-25 00:32:46 2024-02-25 08:15:47
	 1	   57 ARCH    YES	2024-02-24 10:04:09 2024-02-24 22:00:15
	 2	   57 ARCH    YES	2024-02-25 08:15:47 2024-02-26 00:30:13
	 1	   58 ARCH    YES	2024-02-24 22:00:15 2024-02-25 00:30:07
	 2	   58 ARCH    YES	2024-02-26 00:30:13 2024-02-26 00:30:24
	 1	   59 ARCH    YES	2024-02-25 00:30:07 2024-02-25 00:30:19
	 2	   59 ARCH    YES	2024-02-26 00:30:24 2024-02-26 00:33:28
	 1	   60 ARCH    YES	2024-02-25 00:30:19 2024-02-25 00:32:35
	 2	   60 ARCH    YES	2024-02-26 00:33:28 2024-02-26 00:33:37
	 1	   61 ARCH    YES	2024-02-25 00:32:35 2024-02-25 00:32:44
	 2	   61 ARCH    YES	2024-02-26 00:33:37 2024-02-26 00:33:44
	 1	   62 ARCH    YES	2024-02-25 00:32:44 2024-02-25 00:32:47
	 2	   62 ARCH    YES	2024-02-26 00:33:44 2024-02-26 11:05:14
	 1	   63 ARCH    YES	2024-02-25 00:32:47 2024-02-25 10:04:20
	 2	   63 ARCH    YES	2024-02-26 11:05:14 2024-02-27 00:30:05
	 1	   64 ARCH    YES	2024-02-25 10:04:20 2024-02-25 19:32:26
	 2	   64 ARCH    YES	2024-02-27 00:30:05 2024-02-27 00:30:13
	 1	   65 ARCH    YES	2024-02-25 19:32:26 2024-02-26 00:30:07
	 2	   65 ARCH    YES	2024-02-27 00:30:13 2024-02-27 00:32:27
	 1	   66 ARCH    YES	2024-02-26 00:30:07 2024-02-26 00:30:27
	 2	   66 ARCH    YES	2024-02-27 00:32:27 2024-02-27 00:32:37
	 1	   67 ARCH    YES	2024-02-26 00:30:27 2024-02-26 00:33:30
	 2	   67 ARCH    YES	2024-02-27 00:32:37 2024-02-27 00:32:40
	 1	   68 ARCH    YES	2024-02-26 00:33:30 2024-02-26 00:33:43
	 2	   68 ARCH    YES	2024-02-27 00:32:40 2024-02-27 13:00:54
	 1	   69 ARCH    YES	2024-02-26 00:33:43 2024-02-26 00:33:49
	 2	   69 ARCH    YES	2024-02-27 13:00:54 2024-02-28 00:30:08
	 1	   70 ARCH    YES	2024-02-26 00:33:49 2024-02-26 15:03:14
	 2	   70 ARCH    YES	2024-02-28 00:30:08 2024-02-28 00:30:15
	 1	   71 ARCH    YES	2024-02-26 15:03:14 2024-02-26 23:37:31
	 2	   71 ARCH    YES	2024-02-28 00:30:15 2024-02-28 00:32:24
	 1	   72 ARCH    YES	2024-02-26 23:37:31 2024-02-27 00:30:06
	 2	   72 ARCH    YES	2024-02-28 00:32:24 2024-02-28 00:32:29
	 1	   73 ARCH    YES	2024-02-27 00:30:06 2024-02-27 00:30:12
	 2	   73 ARCH    YES	2024-02-28 00:32:29 2024-02-28 00:32:35
	 1	   74 ARCH    YES	2024-02-27 00:30:12 2024-02-27 00:32:28
	 2	   74 ARCH    YES	2024-02-28 00:32:35 2024-02-28 13:00:31
	 1	   75 ARCH    YES	2024-02-27 00:32:28 2024-02-27 00:32:37
	 2	   75 ARCH    YES	2024-02-28 13:00:31 2024-02-28 22:02:50
	 1	   76 ARCH    YES	2024-02-27 00:32:37 2024-02-27 00:32:40
	 2	   76 ARCH    YES	2024-02-28 22:02:50 2024-02-29 00:30:05
	 1	   77 ARCH    YES	2024-02-27 00:32:40 2024-02-27 14:00:20
	 2	   77 ARCH    YES	2024-02-29 00:30:05 2024-02-29 00:30:12
	 1	   78 ARCH    YES	2024-02-27 14:00:20 2024-02-27 22:02:17
	 2	   78 ARCH    YES	2024-02-29 00:30:12 2024-02-29 00:32:29
	 1	   79 ARCH    YES	2024-02-27 22:02:17 2024-02-28 00:30:09
	 2	   79 ARCH    YES	2024-02-29 00:32:29 2024-02-29 00:32:38
	 1	   80 ARCH    YES	2024-02-28 00:30:09 2024-02-28 00:30:15
	 2	   80 ARCH    YES	2024-02-29 00:32:38 2024-02-29 00:32:44
	 1	   81 ARCH    YES	2024-02-28 00:30:15 2024-02-28 00:32:24
	 2	   81 ARCH    YES	2024-02-29 00:32:44 2024-02-29 13:00:29
	 1	   82 ARCH    YES	2024-02-28 00:32:24 2024-02-28 00:32:33
	 2	   82 ARCH    YES	2024-02-29 13:00:29 2024-03-01 00:30:06
	 1	   83 ARCH    YES	2024-02-28 00:32:33 2024-02-28 00:32:39
	 2	   83 ARCH    YES	2024-03-01 00:30:06 2024-03-01 00:30:15
	 1	   84 ARCH    YES	2024-02-28 00:32:39 2024-02-28 14:00:19
	 2	   84 ARCH    YES	2024-03-01 00:30:15 2024-03-01 00:32:35
	 1	   85 ARCH    YES	2024-02-28 14:00:19 2024-02-29 00:30:07
	 2	   85 ARCH    YES	2024-03-01 00:32:35 2024-03-01 00:32:41
	 1	   86 ARCH    YES	2024-02-29 00:30:07 2024-02-29 00:30:13
	 2	   86 ARCH    YES	2024-03-01 00:32:41 2024-03-01 00:32:48
	 1	   87 ARCH    YES	2024-02-29 00:30:13 2024-02-29 00:32:30
	 1	   88 ARCH    YES	2024-02-29 00:32:30 2024-02-29 00:32:39
	 1	   89 ARCH    YES	2024-02-29 00:32:39 2024-02-29 00:32:45
	 1	   90 ARCH    YES	2024-02-29 00:32:45 2024-02-29 17:00:53
	 1	   91 ARCH    YES	2024-02-29 17:00:53 2024-02-29 23:59:49
	 1	   92 ARCH    YES	2024-02-29 23:59:49 2024-03-01 00:30:06
	 1	   93 ARCH    YES	2024-03-01 00:30:06 2024-03-01 00:30:15
	 1	   94 ARCH    YES	2024-03-01 00:30:15 2024-03-01 00:32:35
	 1	   95 ARCH    YES	2024-03-01 00:32:35 2024-03-01 00:32:47
	 1	   96 ARCH    YES	2024-03-01 00:32:47 2024-03-01 00:32:53

177 rows selected.

#清理掉2天前的全部归档日志
[oracle@k8s-oracle-store ~]$ cd /u01/app/oracle/fast_recovery_area/xydbdg/archivelog

[oracle@k8s-oracle-store archivelog]$  find  -mtime +5 -name "*.dbf" -exec ls -lrt  {} \;

[oracle@k8s-oracle-store archivelog]$ find  -mtime +5 -name "*.dbf" -exec rm -fr {} \;



#清理磁盘空间后
[oracle@k8s-oracle-store archivelog]$ df -h
Filesystem           Size  Used Avail Use% Mounted on
devtmpfs              16G     0   16G   0% /dev
tmpfs                 16G     0   16G   0% /dev/shm
tmpfs                 16G  433M   16G   3% /run
tmpfs                 16G     0   16G   0% /sys/fs/cgroup
/dev/mapper/ol-root   87G   62G   26G  71% /
/dev/vda1           1014M  204M  811M  21% /boot
tmpfs                3.2G     0  3.2G   0% /run/user/0
[oracle@k8s-oracle-store archivelog]$ du -hs
4.7G	.
[oracle@k8s-oracle-store archivelog]$ 
```



#查询备库同步日志情况

```sql
SYS@xydbdg> select name,value,time_computed,datum_time from v$dataguard_stats;

NAME				 VALUE								  TIME_COMPUTED 		 DATUM_TIME
-------------------------------- ---------------------------------------------------------------- ------------------------------ ------------------------------
transport lag			 +00 01:35:56							  03/01/2024 13:49:54		 03/01/2024 13:49:52
apply lag			 +00 01:53:46							  03/01/2024 13:49:54		 03/01/2024 13:49:52
apply finish time		 +00 00:04:15.788						  03/01/2024 13:49:54
estimated startup time		 26								  03/01/2024 13:49:54


SYS@xydbdg> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

Database altered.
```



#再次查看alter_xydbdg.log日志

#同步报错，因为卡在了datafile 35#文件

```bash
[oracle@k8s-oracle-store ~]$ tail -f /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/alert_xydbdg.log

Starting background process MRP0
2024-03-01T13:57:35.076944+08:00
MRP0 started with pid=62, OS id=14683
2024-03-01T13:57:35.078323+08:00
Background Managed Standby Recovery process started (xydbdg)
2024-03-01T13:57:40.135526+08:00
 Started logmerger process
2024-03-01T13:57:40.145958+08:00

IM on ADG: Start of Empty Journal

IM on ADG: End of Empty Journal
PR00 (PID:15078): Managed Standby Recovery starting Real Time Apply
2024-03-01T13:57:40.285162+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_dbw0_7437.trc:
ORA-01186: file 35 failed verification tests
ORA-01157: cannot identify/lock data file 35 - see DBWR trace file
ORA-01111: name for data file 35 is unknown - rename to correct file
ORA-01110: data file 35: '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035'
2024-03-01T13:57:40.285281+08:00
File 35 not verified due to error ORA-01157
2024-03-01T13:57:40.313298+08:00
max_pdb is 5
PR00 (PID:15078): MRP0: Background Media Recovery terminated with error 1111
2024-03-01T13:57:40.333200+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_pr00_15078.trc:
ORA-01111: name for data file 35 is unknown - rename to correct file
ORA-01110: data file 35: '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035'
ORA-01157: cannot identify/lock data file 35 - see DBWR trace file
ORA-01111: name for data file 35 is unknown - rename to correct file
ORA-01110: data file 35: '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035'
PR00 (PID:15078): Managed Standby Recovery not using Real Time Apply
Stopping change tracking
2024-03-01T13:57:40.480502+08:00
Recovery Slave PR00 previously exited with exception 1111.
2024-03-01T13:57:40.511154+08:00
Errors in file /u01/app/oracle/diag/rdbms/xydbdg/xydbdg/trace/xydbdg_mrp0_14683.trc:
ORA-01111: name for data file 35 is unknown - rename to correct file
ORA-01110: data file 35: '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035'
ORA-01157: cannot identify/lock data file 35 - see DBWR trace file
ORA-01111: name for data file 35 is unknown - rename to correct file
ORA-01110: data file 35: '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035'
2024-03-01T13:57:40.511277+08:00
Background Media Recovery process shutdown (xydbdg)
2024-03-01T13:57:41.083648+08:00
Completed: ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT
```



#主、备库数据文件查询

```sql
-- 主库数据文件：
SYS@xydb1> select file#,name from v$datafile;

     FILE# NAME
---------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	19 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297
	20 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297
	21 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/undotbs1.285.1159901297
	22 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/pdb1user.294.1159902173
	23 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/undo_2.295.1159902455
	24 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_standcode.296.1162468273
	25 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_standcode.297.1162468285
	26 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_standcode.298.1162468311
	27 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.299.1162468333
	28 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.300.1162468385
	29 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.301.1162468399
	30 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.302.1162468413
	31 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.303.1162468429
	32 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.304.1162468479
	33 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.305.1162468491
	34 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.306.1162468505
	35 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.307.1162468517
	36 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_api.308.1162468535
	37 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_api.309.1162468579
	38 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_api.310.1162468593
	39 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swopwork.311.1162468615
	40 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swopwork.312.1162468629
	41 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swopwork.313.1162468643
	42 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.314.1162468657
	43 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.315.1162468671
	44 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.316.1162468685
	45 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.317.1162468697
	46 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.318.1162468711
	47 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/users.319.1162468725
	48 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.320.1162468725
	49 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.321.1162468739
	50 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.322.1162468753
	51 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.323.1162468765

33 rows selected.

SYS@xydb1> 


SYS@xydb1> select file_id,file_name from dba_data_files;

   FILE_ID FILE_NAME
---------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	19 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/system.292.1159901297
	20 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/sysaux.284.1159901297
	21 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/undotbs1.285.1159901297
	22 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/pdb1user.294.1159902173
	23 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/undo_2.295.1159902455
	24 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_standcode.296.1162468273
	25 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_standcode.297.1162468285
	26 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_standcode.298.1162468311
	27 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.299.1162468333
	28 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.300.1162468385
	29 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.301.1162468399
	30 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_dataquality.302.1162468413
	31 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.303.1162468429
	32 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.304.1162468479
	33 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.305.1162468491
	34 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.306.1162468505
	35 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_sharedb.307.1162468517
	36 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_api.308.1162468535
	37 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_api.309.1162468579
	38 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_api.310.1162468593
	39 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swopwork.311.1162468615
	40 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swopwork.312.1162468629
	41 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swopwork.313.1162468643
	42 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.314.1162468657
	43 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.315.1162468671
	44 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.316.1162468685
	45 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.317.1162468697
	46 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_assets.318.1162468711
	47 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/users.319.1162468725
	48 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.320.1162468725
	49 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.321.1162468739
	50 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.322.1162468753
	51 +DATA/XYDB/1064B454582A4AA4E063610D12AC9D59/DATAFILE/idc_data_swop.323.1162468765

33 rows selected.

SYS@xydb1> 



--备库数据文件：
SYS@xydbdg> alter session set container=dataassets;

Session altered.

SYS@xydbdg> set linesize 300
SYS@xydbdg> col name format a200
SYS@xydbdg> col file_name format a200
SYS@xydbdg> select file#,name from v$datafile;

     FILE# NAME
---------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	19 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/system.292.1159901297
	20 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/sysaux.284.1159901297
	21 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/undotbs1.285.1159901297
	22 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/pdb1user.294.1159902173
	23 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/undo_2.295.1159902455
	24 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.296.1162468273
	25 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.297.1162468285
	26 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.298.1162468311
	27 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.299.1162468333
	28 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.300.1162468385
	29 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.301.1162468399
	30 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.302.1162468413
	31 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.303.1162468429
	32 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.304.1162468479
	33 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.305.1162468491
	34 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.306.1162468505
	35  /u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035

17 rows selected.

SYS@xydbdg> select file_id,file_name from dba_data_files;

   FILE_ID FILE_NAME
---------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	19 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/system.292.1159901297
	20 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/sysaux.284.1159901297
	21 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/undotbs1.285.1159901297
	22 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/pdb1user.294.1159902173
	23 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/undo_2.295.1159902455
	24 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.296.1162468273
	25 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.297.1162468285
	26 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.298.1162468311
	27 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.299.1162468333
	28 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.300.1162468385
	29 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.301.1162468399
	30 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.302.1162468413

12 rows selected.

```





#查询归档日志是否跟主库同步完毕

```sql
#备库
SYS@xydbdg> select sequence#,first_time,next_time,applied from v$archived_log order by sequence#;

 SEQUENCE# FIRST_TIME	       NEXT_TIME	   APPLIED
---------- ------------------- ------------------- ---------
	 3 2024-02-17 17:07:48 2024-02-17 17:15:24 YES
	 4 2024-02-17 17:07:26 2024-02-17 17:15:23 YES
	 4 2024-02-17 17:16:43 2024-02-17 17:16:52 YES
...........................
	65 2024-02-27 00:30:13 2024-02-27 00:32:27 YES
	66 2024-02-26 00:30:07 2024-02-26 00:30:27 YES
	66 2024-02-27 00:32:27 2024-02-27 00:32:37 YES
	67 2024-02-26 00:30:27 2024-02-26 00:33:30 YES
	67 2024-02-27 00:32:37 2024-02-27 00:32:40 YES
	68 2024-02-26 00:33:30 2024-02-26 00:33:43 YES
	68 2024-02-27 00:32:40 2024-02-27 13:00:54 YES
	69 2024-02-26 00:33:43 2024-02-26 00:33:49 YES
	69 2024-02-27 13:00:54 2024-02-28 00:30:08 YES
	70 2024-02-26 00:33:49 2024-02-26 15:03:14 YES
	70 2024-02-28 00:30:08 2024-02-28 00:30:15 YES
	71 2024-02-28 00:30:15 2024-02-28 00:32:24 YES
	71 2024-02-26 15:03:14 2024-02-26 23:37:31 YES
	72 2024-02-28 00:32:24 2024-02-28 00:32:29 YES
	72 2024-02-26 23:37:31 2024-02-27 00:30:06 YES
	73 2024-02-28 00:32:29 2024-02-28 00:32:35 YES
	73 2024-02-27 00:30:06 2024-02-27 00:30:12 YES
	74 2024-02-28 00:32:35 2024-02-28 13:00:31 YES
	74 2024-02-27 00:30:12 2024-02-27 00:32:28 YES
	75 2024-02-27 00:32:28 2024-02-27 00:32:37 YES
	75 2024-02-28 13:00:31 2024-02-28 22:02:50 YES
	76 2024-02-27 00:32:37 2024-02-27 00:32:40 YES
	76 2024-02-28 22:02:50 2024-02-29 00:30:05 YES
	77 2024-02-29 00:30:05 2024-02-29 00:30:12 YES
	77 2024-02-27 00:32:40 2024-02-27 14:00:20 YES
	78 2024-02-29 00:30:12 2024-02-29 00:32:29 YES
	78 2024-02-27 14:00:20 2024-02-27 22:02:17 YES
	79 2024-02-27 22:02:17 2024-02-28 00:30:09 YES
	79 2024-02-29 00:32:29 2024-02-29 00:32:38 YES
	80 2024-02-28 00:30:09 2024-02-28 00:30:15 YES
	80 2024-02-29 00:32:38 2024-02-29 00:32:44 YES
	81 2024-02-29 00:32:44 2024-02-29 13:00:29 YES
	81 2024-02-28 00:30:15 2024-02-28 00:32:24 YES
	82 2024-02-29 13:00:29 2024-03-01 00:30:06 YES
	82 2024-02-28 00:32:24 2024-02-28 00:32:33 YES
	83 2024-03-01 00:30:06 2024-03-01 00:30:15 YES
	83 2024-02-28 00:32:33 2024-02-28 00:32:39 YES
	84 2024-03-01 00:30:15 2024-03-01 00:32:35 YES
	84 2024-02-28 00:32:39 2024-02-28 14:00:19 YES
	85 2024-02-28 14:00:19 2024-02-29 00:30:07 YES
	85 2024-03-01 00:32:35 2024-03-01 00:32:41 YES
	86 2024-02-29 00:30:07 2024-02-29 00:30:13 YES
	86 2024-03-01 00:32:41 2024-03-01 00:32:48 YES
	87 2024-02-29 00:30:13 2024-02-29 00:32:30 YES
	87 2024-03-01 00:32:48 2024-03-01 12:04:06 NO
	88 2024-02-29 00:32:30 2024-02-29 00:32:39 YES
	89 2024-02-29 00:32:39 2024-02-29 00:32:45 YES
	90 2024-02-29 00:32:45 2024-02-29 17:00:53 YES
	91 2024-02-29 17:00:53 2024-02-29 23:59:49 YES
	92 2024-02-29 23:59:49 2024-03-01 00:30:06 YES
	93 2024-03-01 00:30:06 2024-03-01 00:30:15 YES
	94 2024-03-01 00:30:15 2024-03-01 00:32:35 YES
	95 2024-03-01 00:32:35 2024-03-01 00:32:47 YES
	96 2024-03-01 00:32:47 2024-03-01 00:32:53 YES
	97 2024-03-01 00:32:53 2024-03-01 12:00:47 NO
	98 2024-03-01 12:00:47 2024-03-01 12:04:06 NO
	99 2024-03-01 12:04:06 2024-03-01 12:04:40 NO
    100 2024-03-01 12:04:40 2024-03-01 12:13:13 NO

183 rows selected.

SYS@xydbdg> 


SYS@xydbdg>  select max(sequence#)  from v$archived_log;

MAX(SEQUENCE#)
--------------
	   100

SYS@xydbdg> select max(sequence#) from v$archived_log where applied='YES'; 

MAX(SEQUENCE#)
--------------
	    96



#主库
SYS@xydb1> archive log list;
Database log mode	       Archive Mode
Automatic archival	       Enabled
Archive destination	       +FRA
Oldest online log sequence     100
Next log sequence to archive   101
Current log sequence	       101
SYS@xydb1> 


SYS@xydb1> SELECT SEQUENCE#, NAME FROM V$ARCHIVED_LOG WHERE SEQUENCE# > 100 ORDER BY SEQUENCE#;

 SEQUENCE# NAME
---------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
       481

SYS@xydb1> 

```





#在备库针对报错的35号文件进行手动修改：

```sql
#SYS@xydbdg> alter database rename file '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035' to '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517';
#alter database rename file '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035' to '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517'
*
#ERROR at line 1:
#ORA-01275: Operation RENAME is not allowed if standby file management is automatic.


SYS@xydbdg> alter database create datafile '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035' as '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517';

ERROR at line 1:
ORA-01275: Operation RENAME is not allowed if standby file management is automatic.
```

#先改成manual，再创建数据文件

```sql
SYS@xydbdg> select name,open_mode,database_role from v$database;

NAME	  OPEN_MODE	       DATABASE_ROLE
--------- -------------------- ----------------
XYDB	  READ ONLY	       PHYSICAL STANDBY

SYS@xydbdg> 

SYS@xydbdg> shutdown immediate;
Database closed.
Database dismounted.
ORACLE instance shut down.
SYS@xydbdg> startup mount; 
ORACLE instance started.

Total System Global Area 1.6106E+10 bytes
Fixed Size		   18625040 bytes
Variable Size		 2181038080 bytes
Database Buffers	 1.3892E+10 bytes
Redo Buffers		   14925824 bytes
Database mounted.
SYS@xydbdg> select name,open_mode,database_role from v$database;

NAME	  OPEN_MODE	       DATABASE_ROLE
--------- -------------------- ----------------
XYDB	  MOUNTED	       PHYSICAL STANDBY

SYS@xydbdg> 

#在cdb下执行报错
SYS@xydbdg> alter database create datafile '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035' as '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517';
alter database create datafile '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035' as '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517'
*
ERROR at line 1:
ORA-01516: nonexistent log file, data file, or temporary file "/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035" in the current container



SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  MOUNTED
	 3 STUWORK			  MOUNTED
	 4 PORTAL			  MOUNTED
	 5 DATAASSETS			  MOUNTED
	 
	 
#必须切换到相关pdb下执行才可以
SYS@xydbdg> alter session set container=dataassets;

Session altered.

SYS@xydbdg> alter database create datafile '/u01/app/oracle/product/19.0.0/db_1/dbs/UNNAMED00035' as '/u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517';

Database altered.

SYS@xydbdg> 

SYS@xydbdg> select file#,name from v$datafile where file#=35;

     FILE# NAME
---------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	35 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517

SYS@xydbdg> 
SYS@xydbdg> alter system set standby_file_management=auto;
alter system set standby_file_management=auto
*
ERROR at line 1:
ORA-65040: operation not allowed from within a pluggable database


SYS@xydbdg> 

#再次切换到cdb执行，修改为auto
SYS@xydbdg> alter session set container=cdb$root;

Session altered.

SYS@xydbdg> alter system set standby_file_management=auto;

System altered.

SYS@xydbdg> show parameter standby;

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
enabled_PDBs_on_standby 	     string	 *
standby_db_preserve_states	     string	 NONE
standby_file_management 	     string	 AUTO
standby_pdb_source_file_dblink	     string
standby_pdb_source_file_directory    string
SYS@xydbdg> 


#再次执行同步
SYS@xydbdg> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

Database altered.

SYS@xydbdg> select process,status,thread#,sequence#,block# from v$managed_standby;

PROCESS   STATUS	  THREAD#  SEQUENCE#	 BLOCK#
--------- ------------ ---------- ---------- ----------
ARCH	  CONNECTED		0	   0	      0
DGRD	  ALLOCATED		0	   0	      0
DGRD	  ALLOCATED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
RFS	  WRITING		2	  88	 104008
RFS	  IDLE			1	   0	      0
RFS	  WRITING		1	 101	 309690
RFS	  IDLE			2	   0	      0
MRP0	  APPLYING_LOG		2	  87	 319599

11 rows selected.

SYS@xydbdg> select process,status,thread#,sequence#,block# from v$managed_standby;

PROCESS   STATUS	  THREAD#  SEQUENCE#	 BLOCK#
--------- ------------ ---------- ---------- ----------
ARCH	  CONNECTED		0	   0	      0
DGRD	  ALLOCATED		0	   0	      0
DGRD	  ALLOCATED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
RFS	  IDLE			2	  88	 104456
RFS	  IDLE			1	   0	      0
RFS	  IDLE			1	 101	 310425
RFS	  IDLE			2	   0	      0
MRP0	  APPLYING_LOG		1	 101	 310424

11 rows selected.

SYS@xydbdg> select sequence#,first_time,next_time,applied from v$archived_log order by sequence#;

 SEQUENCE# FIRST_TIME	       NEXT_TIME	   APPLIED
---------- ------------------- ------------------- ---------
	 3 2024-02-17 17:07:48 2024-02-17 17:15:24 YES
	 4 2024-02-17 17:07:26 2024-02-17 17:15:23 YES
	 4 2024-02-17 17:16:43 2024-02-17 17:16:52 YES
	 5 2024-02-17 17:36:23 2024-02-17 17:36:23 YES
	 6 2024-02-17 17:16:51 2024-02-17 17:34:57 YES
	 6 2024-02-17 17:16:51 2024-02-17 17:34:57 YES
	 6 2024-02-17 17:36:23 2024-02-18 00:30:07 YES
	 7 2024-02-17 17:34:57 2024-02-17 17:36:08 NO
	 7 2024-02-17 17:34:57 2024-02-17 17:36:08 YES
	 7 2024-02-18 00:30:07 2024-02-18 00:30:18 YES
	 8 2024-02-17 17:35:56 2024-02-17 17:36:15 YES
	 8 2024-02-18 00:30:18 2024-02-18 00:33:01 YES
	 9 2024-02-17 17:36:15 2024-02-18 00:30:09 YES
	 9 2024-02-18 00:33:01 2024-02-18 00:33:09 YES
	10 2024-02-18 00:30:09 2024-02-18 00:30:18 YES
	10 2024-02-18 00:33:09 2024-02-18 00:33:14 YES
	11 2024-02-18 00:30:18 2024-02-18 00:30:21 YES
	11 2024-02-18 00:33:14 2024-02-18 18:00:10 YES
	12 2024-02-18 00:30:21 2024-02-18 00:33:01 YES
	12 2024-02-18 18:00:10 2024-02-18 23:00:36 YES
	13 2024-02-18 00:33:01 2024-02-18 00:33:13 YES
	13 2024-02-18 23:00:36 2024-02-19 00:30:06 YES
	14 2024-02-18 00:33:13 2024-02-18 00:33:16 YES
	14 2024-02-19 00:30:06 2024-02-19 00:30:14 YES
	15 2024-02-18 00:33:16 2024-02-18 09:02:46 YES
	15 2024-02-19 00:30:14 2024-02-19 00:32:53 YES
	16 2024-02-18 09:02:46 2024-02-18 18:00:10 YES
	16 2024-02-19 00:32:53 2024-02-19 00:33:01 YES
	17 2024-02-18 18:00:10 2024-02-19 00:30:07 YES
	17 2024-02-19 00:33:01 2024-02-19 00:33:07 YES
	18 2024-02-19 00:30:07 2024-02-19 00:30:13 YES
	18 2024-02-19 00:33:07 2024-02-19 19:46:07 YES
	19 2024-02-19 00:30:13 2024-02-19 00:32:55 YES
	19 2024-02-19 19:46:07 2024-02-20 00:30:06 YES
	20 2024-02-19 00:32:55 2024-02-19 00:33:04 YES
	20 2024-02-20 00:30:06 2024-02-20 00:30:15 YES
	21 2024-02-19 00:33:04 2024-02-19 00:33:10 YES
	21 2024-02-20 00:30:15 2024-02-20 00:32:19 YES
	22 2024-02-19 00:33:10 2024-02-19 15:00:51 YES
	22 2024-02-20 00:32:19 2024-02-20 00:32:28 YES
	23 2024-02-19 15:00:51 2024-02-20 00:30:07 YES
	23 2024-02-20 00:32:28 2024-02-20 00:32:31 YES
	24 2024-02-20 00:30:07 2024-02-20 00:30:16 YES
	24 2024-02-20 00:32:31 2024-02-20 10:00:51 YES
	25 2024-02-20 00:30:16 2024-02-20 00:32:19 YES
	25 2024-02-20 10:00:51 2024-02-21 00:30:07 YES
	26 2024-02-20 00:32:19 2024-02-20 00:32:28 YES
	26 2024-02-21 00:30:07 2024-02-21 00:30:14 YES
	27 2024-02-20 00:32:28 2024-02-20 00:32:32 YES
	27 2024-02-21 00:30:14 2024-02-21 00:32:27 YES
	28 2024-02-20 00:32:32 2024-02-20 00:32:35 YES
	28 2024-02-21 00:32:27 2024-02-21 00:32:38 YES
	29 2024-02-20 00:32:35 2024-02-20 14:00:14 YES
	29 2024-02-21 00:32:38 2024-02-21 00:32:44 YES
	30 2024-02-20 14:00:14 2024-02-20 22:02:21 YES
	30 2024-02-21 00:32:44 2024-02-21 13:00:09 YES
	31 2024-02-20 22:02:21 2024-02-21 00:30:08 YES
	31 2024-02-21 13:00:09 2024-02-22 00:30:06 YES
	32 2024-02-21 00:30:08 2024-02-21 00:30:14 YES
	32 2024-02-22 00:30:06 2024-02-22 00:30:18 YES
	33 2024-02-21 00:30:14 2024-02-21 00:32:30 YES
	33 2024-02-22 00:30:18 2024-02-22 00:32:30 YES
	34 2024-02-21 00:32:30 2024-02-21 00:32:39 YES
	34 2024-02-22 00:32:30 2024-02-22 00:32:36 YES
	35 2024-02-21 00:32:39 2024-02-21 00:32:45 YES
	35 2024-02-22 00:32:36 2024-02-22 00:32:42 YES
	36 2024-02-21 00:32:45 2024-02-21 00:32:51 YES
	36 2024-02-22 00:32:42 2024-02-22 13:08:42 YES
	37 2024-02-21 00:32:51 2024-02-21 13:00:09 YES
	37 2024-02-22 13:08:42 2024-02-22 22:02:00 YES
	38 2024-02-21 13:00:09 2024-02-21 22:01:20 YES
	38 2024-02-22 22:02:00 2024-02-23 00:30:06 YES
	39 2024-02-21 22:01:20 2024-02-22 00:30:06 YES
	39 2024-02-23 00:30:06 2024-02-23 00:30:14 YES
	40 2024-02-22 00:30:06 2024-02-22 00:30:18 YES
	40 2024-02-23 00:30:14 2024-02-23 00:32:26 YES
	41 2024-02-22 00:30:18 2024-02-22 00:32:29 YES
	41 2024-02-23 00:32:26 2024-02-23 00:32:33 YES
	42 2024-02-22 00:32:29 2024-02-22 00:32:41 YES
	42 2024-02-23 00:32:33 2024-02-23 00:32:39 YES
	43 2024-02-22 00:32:41 2024-02-22 00:32:44 YES
	43 2024-02-23 00:32:39 2024-02-23 13:17:52 YES
	44 2024-02-22 00:32:44 2024-02-22 15:08:24 YES
	44 2024-02-23 13:17:52 2024-02-23 22:01:48 YES
	45 2024-02-22 15:08:24 2024-02-23 00:30:06 YES
	45 2024-02-23 22:01:48 2024-02-24 00:30:06 YES
	46 2024-02-23 00:30:06 2024-02-23 00:30:12 YES
	46 2024-02-24 00:30:06 2024-02-24 00:30:15 YES
	47 2024-02-24 00:30:15 2024-02-24 00:32:35 YES
	47 2024-02-23 00:30:12 2024-02-23 00:32:28 YES
	48 2024-02-23 00:32:28 2024-02-23 00:32:37 YES
	48 2024-02-24 00:32:35 2024-02-24 00:32:44 YES
	49 2024-02-23 00:32:37 2024-02-23 00:32:43 YES
	49 2024-02-24 00:32:44 2024-02-24 00:32:47 YES
	50 2024-02-23 00:32:43 2024-02-23 15:18:24 YES
	50 2024-02-24 00:32:47 2024-02-24 13:00:15 YES
	51 2024-02-24 13:00:15 2024-02-25 00:30:07 YES
	51 2024-02-23 15:18:24 2024-02-24 00:30:09 YES
	52 2024-02-25 00:30:07 2024-02-25 00:30:15 YES
	52 2024-02-24 00:30:09 2024-02-24 00:30:15 YES
	53 2024-02-25 00:30:15 2024-02-25 00:32:35 YES
	53 2024-02-24 00:30:15 2024-02-24 00:32:36 YES
	54 2024-02-24 00:32:36 2024-02-24 00:32:45 YES
	54 2024-02-25 00:32:35 2024-02-25 00:32:39 YES
	55 2024-02-24 00:32:45 2024-02-24 00:32:48 YES
	55 2024-02-25 00:32:39 2024-02-25 00:32:46 YES
	56 2024-02-24 00:32:48 2024-02-24 10:04:09 YES
	56 2024-02-25 00:32:46 2024-02-25 08:15:47 YES
	57 2024-02-25 08:15:47 2024-02-26 00:30:13 YES
	57 2024-02-24 10:04:09 2024-02-24 22:00:15 YES
	58 2024-02-24 22:00:15 2024-02-25 00:30:07 YES
	58 2024-02-26 00:30:13 2024-02-26 00:30:24 YES
	59 2024-02-26 00:30:24 2024-02-26 00:33:28 YES
	59 2024-02-25 00:30:07 2024-02-25 00:30:19 YES
	60 2024-02-25 00:30:19 2024-02-25 00:32:35 YES
	60 2024-02-26 00:33:28 2024-02-26 00:33:37 YES
	61 2024-02-26 00:33:37 2024-02-26 00:33:44 YES
	61 2024-02-25 00:32:35 2024-02-25 00:32:44 YES
	62 2024-02-25 00:32:44 2024-02-25 00:32:47 YES
	62 2024-02-26 00:33:44 2024-02-26 11:05:14 YES
	63 2024-02-25 00:32:47 2024-02-25 10:04:20 YES
	63 2024-02-26 11:05:14 2024-02-27 00:30:05 YES
	64 2024-02-25 10:04:20 2024-02-25 19:32:26 YES
	64 2024-02-27 00:30:05 2024-02-27 00:30:13 YES
	65 2024-02-25 19:32:26 2024-02-26 00:30:07 YES
	65 2024-02-27 00:30:13 2024-02-27 00:32:27 YES
	66 2024-02-26 00:30:07 2024-02-26 00:30:27 YES
	66 2024-02-27 00:32:27 2024-02-27 00:32:37 YES
	67 2024-02-26 00:30:27 2024-02-26 00:33:30 YES
	67 2024-02-27 00:32:37 2024-02-27 00:32:40 YES
	68 2024-02-26 00:33:30 2024-02-26 00:33:43 YES
	68 2024-02-27 00:32:40 2024-02-27 13:00:54 YES
	69 2024-02-26 00:33:43 2024-02-26 00:33:49 YES
	69 2024-02-27 13:00:54 2024-02-28 00:30:08 YES
	70 2024-02-26 00:33:49 2024-02-26 15:03:14 YES
	70 2024-02-28 00:30:08 2024-02-28 00:30:15 YES
	71 2024-02-28 00:30:15 2024-02-28 00:32:24 YES
	71 2024-02-26 15:03:14 2024-02-26 23:37:31 YES
	72 2024-02-28 00:32:24 2024-02-28 00:32:29 YES
	72 2024-02-26 23:37:31 2024-02-27 00:30:06 YES
	73 2024-02-28 00:32:29 2024-02-28 00:32:35 YES
	73 2024-02-27 00:30:06 2024-02-27 00:30:12 YES
	74 2024-02-28 00:32:35 2024-02-28 13:00:31 YES
	74 2024-02-27 00:30:12 2024-02-27 00:32:28 YES
	75 2024-02-27 00:32:28 2024-02-27 00:32:37 YES
	75 2024-02-28 13:00:31 2024-02-28 22:02:50 YES
	76 2024-02-27 00:32:37 2024-02-27 00:32:40 YES
	76 2024-02-28 22:02:50 2024-02-29 00:30:05 YES
	77 2024-02-29 00:30:05 2024-02-29 00:30:12 YES
	77 2024-02-27 00:32:40 2024-02-27 14:00:20 YES
	78 2024-02-29 00:30:12 2024-02-29 00:32:29 YES
	78 2024-02-27 14:00:20 2024-02-27 22:02:17 YES
	79 2024-02-27 22:02:17 2024-02-28 00:30:09 YES
	79 2024-02-29 00:32:29 2024-02-29 00:32:38 YES
	80 2024-02-28 00:30:09 2024-02-28 00:30:15 YES
	80 2024-02-29 00:32:38 2024-02-29 00:32:44 YES
	81 2024-02-29 00:32:44 2024-02-29 13:00:29 YES
	81 2024-02-28 00:30:15 2024-02-28 00:32:24 YES
	82 2024-02-29 13:00:29 2024-03-01 00:30:06 YES
	82 2024-02-28 00:32:24 2024-02-28 00:32:33 YES
	83 2024-03-01 00:30:06 2024-03-01 00:30:15 YES
	83 2024-02-28 00:32:33 2024-02-28 00:32:39 YES
	84 2024-03-01 00:30:15 2024-03-01 00:32:35 YES
	84 2024-02-28 00:32:39 2024-02-28 14:00:19 YES
	85 2024-02-28 14:00:19 2024-02-29 00:30:07 YES
	85 2024-03-01 00:32:35 2024-03-01 00:32:41 YES
	86 2024-02-29 00:30:07 2024-02-29 00:30:13 YES
	86 2024-03-01 00:32:41 2024-03-01 00:32:48 YES
	87 2024-02-29 00:30:13 2024-02-29 00:32:30 YES
	87 2024-03-01 00:32:48 2024-03-01 12:04:06 YES
	88 2024-02-29 00:32:30 2024-02-29 00:32:39 YES
	89 2024-02-29 00:32:39 2024-02-29 00:32:45 YES
	90 2024-02-29 00:32:45 2024-02-29 17:00:53 YES
	91 2024-02-29 17:00:53 2024-02-29 23:59:49 YES
	92 2024-02-29 23:59:49 2024-03-01 00:30:06 YES
	93 2024-03-01 00:30:06 2024-03-01 00:30:15 YES
	94 2024-03-01 00:30:15 2024-03-01 00:32:35 YES
	95 2024-03-01 00:32:35 2024-03-01 00:32:47 YES
	96 2024-03-01 00:32:47 2024-03-01 00:32:53 YES
	97 2024-03-01 00:32:53 2024-03-01 12:00:47 YES
	98 2024-03-01 12:00:47 2024-03-01 12:04:06 YES
	99 2024-03-01 12:04:06 2024-03-01 12:04:40 IN-MEMORY
    100 2024-03-01 12:04:40 2024-03-01 12:13:13 IN-MEMORY

183 rows selected.

SYS@xydbdg> select process,status,thread#,sequence#,block# from v$managed_standby;

PROCESS   STATUS	  THREAD#  SEQUENCE#	 BLOCK#
--------- ------------ ---------- ---------- ----------
ARCH	  CONNECTED		0	   0	      0
DGRD	  ALLOCATED		0	   0	      0
DGRD	  ALLOCATED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
ARCH	  CONNECTED		0	   0	      0
RFS	  IDLE			2	  88	 104678
RFS	  IDLE			1	   0	      0
RFS	  IDLE			1	 101	 310550
RFS	  IDLE			2	   0	      0
MRP0	  APPLYING_LOG		1	 101	 310550

11 rows selected.

SYS@xydbdg> select sequence#,first_time,next_time,applied from v$archived_log order by sequence#;

 SEQUENCE# FIRST_TIME	       NEXT_TIME	   APPLIED
---------- ------------------- ------------------- ---------
	 3 2024-02-17 17:07:48 2024-02-17 17:15:24 YES
	 4 2024-02-17 17:07:26 2024-02-17 17:15:23 YES
	 4 2024-02-17 17:16:43 2024-02-17 17:16:52 YES
	 5 2024-02-17 17:36:23 2024-02-17 17:36:23 YES
	 6 2024-02-17 17:16:51 2024-02-17 17:34:57 YES
	 6 2024-02-17 17:16:51 2024-02-17 17:34:57 YES
	 6 2024-02-17 17:36:23 2024-02-18 00:30:07 YES
	 7 2024-02-17 17:34:57 2024-02-17 17:36:08 NO
	 7 2024-02-17 17:34:57 2024-02-17 17:36:08 YES
	 7 2024-02-18 00:30:07 2024-02-18 00:30:18 YES
	 8 2024-02-17 17:35:56 2024-02-17 17:36:15 YES
	 8 2024-02-18 00:30:18 2024-02-18 00:33:01 YES
	 9 2024-02-17 17:36:15 2024-02-18 00:30:09 YES
	 9 2024-02-18 00:33:01 2024-02-18 00:33:09 YES
	10 2024-02-18 00:30:09 2024-02-18 00:30:18 YES
	10 2024-02-18 00:33:09 2024-02-18 00:33:14 YES
	11 2024-02-18 00:30:18 2024-02-18 00:30:21 YES
	11 2024-02-18 00:33:14 2024-02-18 18:00:10 YES
	12 2024-02-18 00:30:21 2024-02-18 00:33:01 YES
	12 2024-02-18 18:00:10 2024-02-18 23:00:36 YES
	13 2024-02-18 00:33:01 2024-02-18 00:33:13 YES
	13 2024-02-18 23:00:36 2024-02-19 00:30:06 YES
	14 2024-02-18 00:33:13 2024-02-18 00:33:16 YES
	14 2024-02-19 00:30:06 2024-02-19 00:30:14 YES
	15 2024-02-18 00:33:16 2024-02-18 09:02:46 YES
	15 2024-02-19 00:30:14 2024-02-19 00:32:53 YES
	16 2024-02-18 09:02:46 2024-02-18 18:00:10 YES
	16 2024-02-19 00:32:53 2024-02-19 00:33:01 YES
	17 2024-02-18 18:00:10 2024-02-19 00:30:07 YES
	17 2024-02-19 00:33:01 2024-02-19 00:33:07 YES
	18 2024-02-19 00:30:07 2024-02-19 00:30:13 YES
	18 2024-02-19 00:33:07 2024-02-19 19:46:07 YES
	19 2024-02-19 00:30:13 2024-02-19 00:32:55 YES
	19 2024-02-19 19:46:07 2024-02-20 00:30:06 YES
	20 2024-02-19 00:32:55 2024-02-19 00:33:04 YES
	20 2024-02-20 00:30:06 2024-02-20 00:30:15 YES
	21 2024-02-19 00:33:04 2024-02-19 00:33:10 YES
	21 2024-02-20 00:30:15 2024-02-20 00:32:19 YES
	22 2024-02-19 00:33:10 2024-02-19 15:00:51 YES
	22 2024-02-20 00:32:19 2024-02-20 00:32:28 YES
	23 2024-02-19 15:00:51 2024-02-20 00:30:07 YES
	23 2024-02-20 00:32:28 2024-02-20 00:32:31 YES
	24 2024-02-20 00:30:07 2024-02-20 00:30:16 YES
	24 2024-02-20 00:32:31 2024-02-20 10:00:51 YES
	25 2024-02-20 00:30:16 2024-02-20 00:32:19 YES
	25 2024-02-20 10:00:51 2024-02-21 00:30:07 YES
	26 2024-02-20 00:32:19 2024-02-20 00:32:28 YES
	26 2024-02-21 00:30:07 2024-02-21 00:30:14 YES
	27 2024-02-20 00:32:28 2024-02-20 00:32:32 YES
	27 2024-02-21 00:30:14 2024-02-21 00:32:27 YES
	28 2024-02-20 00:32:32 2024-02-20 00:32:35 YES
	28 2024-02-21 00:32:27 2024-02-21 00:32:38 YES
	29 2024-02-20 00:32:35 2024-02-20 14:00:14 YES
	29 2024-02-21 00:32:38 2024-02-21 00:32:44 YES
	30 2024-02-20 14:00:14 2024-02-20 22:02:21 YES
	30 2024-02-21 00:32:44 2024-02-21 13:00:09 YES
	31 2024-02-20 22:02:21 2024-02-21 00:30:08 YES
	31 2024-02-21 13:00:09 2024-02-22 00:30:06 YES
	32 2024-02-21 00:30:08 2024-02-21 00:30:14 YES
	32 2024-02-22 00:30:06 2024-02-22 00:30:18 YES
	33 2024-02-21 00:30:14 2024-02-21 00:32:30 YES
	33 2024-02-22 00:30:18 2024-02-22 00:32:30 YES
	34 2024-02-21 00:32:30 2024-02-21 00:32:39 YES
	34 2024-02-22 00:32:30 2024-02-22 00:32:36 YES
	35 2024-02-21 00:32:39 2024-02-21 00:32:45 YES
	35 2024-02-22 00:32:36 2024-02-22 00:32:42 YES
	36 2024-02-21 00:32:45 2024-02-21 00:32:51 YES
	36 2024-02-22 00:32:42 2024-02-22 13:08:42 YES
	37 2024-02-21 00:32:51 2024-02-21 13:00:09 YES
	37 2024-02-22 13:08:42 2024-02-22 22:02:00 YES
	38 2024-02-21 13:00:09 2024-02-21 22:01:20 YES
	38 2024-02-22 22:02:00 2024-02-23 00:30:06 YES
	39 2024-02-21 22:01:20 2024-02-22 00:30:06 YES
	39 2024-02-23 00:30:06 2024-02-23 00:30:14 YES
	40 2024-02-22 00:30:06 2024-02-22 00:30:18 YES
	40 2024-02-23 00:30:14 2024-02-23 00:32:26 YES
	41 2024-02-22 00:30:18 2024-02-22 00:32:29 YES
	41 2024-02-23 00:32:26 2024-02-23 00:32:33 YES
	42 2024-02-22 00:32:29 2024-02-22 00:32:41 YES
	42 2024-02-23 00:32:33 2024-02-23 00:32:39 YES
	43 2024-02-22 00:32:41 2024-02-22 00:32:44 YES
	43 2024-02-23 00:32:39 2024-02-23 13:17:52 YES
	44 2024-02-22 00:32:44 2024-02-22 15:08:24 YES
	44 2024-02-23 13:17:52 2024-02-23 22:01:48 YES
	45 2024-02-22 15:08:24 2024-02-23 00:30:06 YES
	45 2024-02-23 22:01:48 2024-02-24 00:30:06 YES
	46 2024-02-23 00:30:06 2024-02-23 00:30:12 YES
	46 2024-02-24 00:30:06 2024-02-24 00:30:15 YES
	47 2024-02-24 00:30:15 2024-02-24 00:32:35 YES
	47 2024-02-23 00:30:12 2024-02-23 00:32:28 YES
	48 2024-02-23 00:32:28 2024-02-23 00:32:37 YES
	48 2024-02-24 00:32:35 2024-02-24 00:32:44 YES
	49 2024-02-23 00:32:37 2024-02-23 00:32:43 YES
	49 2024-02-24 00:32:44 2024-02-24 00:32:47 YES
	50 2024-02-23 00:32:43 2024-02-23 15:18:24 YES
	50 2024-02-24 00:32:47 2024-02-24 13:00:15 YES
	51 2024-02-24 13:00:15 2024-02-25 00:30:07 YES
	51 2024-02-23 15:18:24 2024-02-24 00:30:09 YES
	52 2024-02-25 00:30:07 2024-02-25 00:30:15 YES
	52 2024-02-24 00:30:09 2024-02-24 00:30:15 YES
	53 2024-02-25 00:30:15 2024-02-25 00:32:35 YES
	53 2024-02-24 00:30:15 2024-02-24 00:32:36 YES
	54 2024-02-24 00:32:36 2024-02-24 00:32:45 YES
	54 2024-02-25 00:32:35 2024-02-25 00:32:39 YES
	55 2024-02-24 00:32:45 2024-02-24 00:32:48 YES
	55 2024-02-25 00:32:39 2024-02-25 00:32:46 YES
	56 2024-02-24 00:32:48 2024-02-24 10:04:09 YES
	56 2024-02-25 00:32:46 2024-02-25 08:15:47 YES
	57 2024-02-25 08:15:47 2024-02-26 00:30:13 YES
	57 2024-02-24 10:04:09 2024-02-24 22:00:15 YES
	58 2024-02-24 22:00:15 2024-02-25 00:30:07 YES
	58 2024-02-26 00:30:13 2024-02-26 00:30:24 YES
	59 2024-02-26 00:30:24 2024-02-26 00:33:28 YES
	59 2024-02-25 00:30:07 2024-02-25 00:30:19 YES
	60 2024-02-25 00:30:19 2024-02-25 00:32:35 YES
	60 2024-02-26 00:33:28 2024-02-26 00:33:37 YES
	61 2024-02-26 00:33:37 2024-02-26 00:33:44 YES
	61 2024-02-25 00:32:35 2024-02-25 00:32:44 YES
	62 2024-02-25 00:32:44 2024-02-25 00:32:47 YES
	62 2024-02-26 00:33:44 2024-02-26 11:05:14 YES
	63 2024-02-25 00:32:47 2024-02-25 10:04:20 YES
	63 2024-02-26 11:05:14 2024-02-27 00:30:05 YES
	64 2024-02-25 10:04:20 2024-02-25 19:32:26 YES
	64 2024-02-27 00:30:05 2024-02-27 00:30:13 YES
	65 2024-02-25 19:32:26 2024-02-26 00:30:07 YES
	65 2024-02-27 00:30:13 2024-02-27 00:32:27 YES
	66 2024-02-26 00:30:07 2024-02-26 00:30:27 YES
	66 2024-02-27 00:32:27 2024-02-27 00:32:37 YES
	67 2024-02-26 00:30:27 2024-02-26 00:33:30 YES
	67 2024-02-27 00:32:37 2024-02-27 00:32:40 YES
	68 2024-02-26 00:33:30 2024-02-26 00:33:43 YES
	68 2024-02-27 00:32:40 2024-02-27 13:00:54 YES
	69 2024-02-26 00:33:43 2024-02-26 00:33:49 YES
	69 2024-02-27 13:00:54 2024-02-28 00:30:08 YES
	70 2024-02-26 00:33:49 2024-02-26 15:03:14 YES
	70 2024-02-28 00:30:08 2024-02-28 00:30:15 YES
	71 2024-02-28 00:30:15 2024-02-28 00:32:24 YES
	71 2024-02-26 15:03:14 2024-02-26 23:37:31 YES
	72 2024-02-28 00:32:24 2024-02-28 00:32:29 YES
	72 2024-02-26 23:37:31 2024-02-27 00:30:06 YES
	73 2024-02-28 00:32:29 2024-02-28 00:32:35 YES
	73 2024-02-27 00:30:06 2024-02-27 00:30:12 YES
	74 2024-02-28 00:32:35 2024-02-28 13:00:31 YES
	74 2024-02-27 00:30:12 2024-02-27 00:32:28 YES
	75 2024-02-27 00:32:28 2024-02-27 00:32:37 YES
	75 2024-02-28 13:00:31 2024-02-28 22:02:50 YES
	76 2024-02-27 00:32:37 2024-02-27 00:32:40 YES
	76 2024-02-28 22:02:50 2024-02-29 00:30:05 YES
	77 2024-02-29 00:30:05 2024-02-29 00:30:12 YES
	77 2024-02-27 00:32:40 2024-02-27 14:00:20 YES
	78 2024-02-29 00:30:12 2024-02-29 00:32:29 YES
	78 2024-02-27 14:00:20 2024-02-27 22:02:17 YES
	79 2024-02-27 22:02:17 2024-02-28 00:30:09 YES
	79 2024-02-29 00:32:29 2024-02-29 00:32:38 YES
	80 2024-02-28 00:30:09 2024-02-28 00:30:15 YES
	80 2024-02-29 00:32:38 2024-02-29 00:32:44 YES
	81 2024-02-29 00:32:44 2024-02-29 13:00:29 YES
	81 2024-02-28 00:30:15 2024-02-28 00:32:24 YES
	82 2024-02-29 13:00:29 2024-03-01 00:30:06 YES
	82 2024-02-28 00:32:24 2024-02-28 00:32:33 YES
	83 2024-03-01 00:30:06 2024-03-01 00:30:15 YES
	83 2024-02-28 00:32:33 2024-02-28 00:32:39 YES
	84 2024-03-01 00:30:15 2024-03-01 00:32:35 YES
	84 2024-02-28 00:32:39 2024-02-28 14:00:19 YES
	85 2024-02-28 14:00:19 2024-02-29 00:30:07 YES
	85 2024-03-01 00:32:35 2024-03-01 00:32:41 YES
	86 2024-02-29 00:30:07 2024-02-29 00:30:13 YES
	86 2024-03-01 00:32:41 2024-03-01 00:32:48 YES
	87 2024-02-29 00:30:13 2024-02-29 00:32:30 YES
	87 2024-03-01 00:32:48 2024-03-01 12:04:06 YES
	88 2024-02-29 00:32:30 2024-02-29 00:32:39 YES
	89 2024-02-29 00:32:39 2024-02-29 00:32:45 YES
	90 2024-02-29 00:32:45 2024-02-29 17:00:53 YES
	91 2024-02-29 17:00:53 2024-02-29 23:59:49 YES
	92 2024-02-29 23:59:49 2024-03-01 00:30:06 YES
	93 2024-03-01 00:30:06 2024-03-01 00:30:15 YES
	94 2024-03-01 00:30:15 2024-03-01 00:32:35 YES
	95 2024-03-01 00:32:35 2024-03-01 00:32:47 YES
	96 2024-03-01 00:32:47 2024-03-01 00:32:53 YES
	97 2024-03-01 00:32:53 2024-03-01 12:00:47 YES
	98 2024-03-01 12:00:47 2024-03-01 12:04:06 YES
	99 2024-03-01 12:04:06 2024-03-01 12:04:40 YES
    100 2024-03-01 12:04:40 2024-03-01 12:13:13 YES

183 rows selected.

SYS@xydbdg> 

SYS@xydbdg> select name,value,time_computed,datum_time from v$dataguard_stats;

NAME				 VALUE								  TIME_COMPUTED 		 DATUM_TIME
-------------------------------- ---------------------------------------------------------------- ------------------------------ ------------------------------
transport lag			 +00 00:00:00							  03/01/2024 17:10:57		 03/01/2024 17:10:56
apply lag			 +00 00:00:00							  03/01/2024 17:10:57		 03/01/2024 17:10:56
apply finish time		 +00 00:00:00.000						  03/01/2024 17:10:57
estimated startup time		 26								  03/01/2024 17:10:57

SYS@xydbdg> 

#此时数据文件跟主库一致了
SYS@xydbdg> select file#,name from v$datafile;

     FILE# NAME
---------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	19 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/system.292.1159901297
	20 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/sysaux.284.1159901297
	21 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/undotbs1.285.1159901297
	22 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/pdb1user.294.1159902173
	23 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/undo_2.295.1159902455
	24 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.296.1162468273
	25 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.297.1162468285
	26 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_standcode.298.1162468311
	27 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.299.1162468333
	28 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.300.1162468385
	29 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.301.1162468399
	30 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_dataquality.302.1162468413
	31 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.303.1162468429
	32 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.304.1162468479
	33 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.305.1162468491
	34 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.306.1162468505
	35 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_sharedb.307.1162468517
	36 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_api.308.1162468535
	37 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_api.309.1162468579
	38 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_api.310.1162468593
	39 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_swopwork.311.1162468615
	40 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_swopwork.312.1162468629
	41 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_swopwork.313.1162468643
	42 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_assets.314.1162468657
	43 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_assets.315.1162468671
	44 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_assets.316.1162468685
	45 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_assets.317.1162468697
	46 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_assets.318.1162468711
	47 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/users.319.1162468725
	48 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_swop.320.1162468725
	49 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_swop.321.1162468739
	50 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_swop.322.1162468753
	51 /u01/app/oracle/oradata/xydbdg/datafile/xydb/1064b454582a4aa4e063610d12ac9d59/datafile/idc_data_swop.323.1162468765

33 rows selected.

SYS@xydbdg> 



#同步完毕，切换到cdb，将数据库启动到open read only模式

SYS@xydbdg> alter session set container=cdb$root;

Session altered.


SYS@xydbdg> select status from v$instance;

STATUS
------------
MOUNTED

SYS@xydbdg> alter database open;
alter database open
*
ERROR at line 1:
ORA-10456: cannot open standby database; media recovery session may be in progress


SYS@xydbdg> show pdbs;

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  MOUNTED
	 3 STUWORK			  MOUNTED
	 4 PORTAL			  MOUNTED
	 5 DATAASSETS			  MOUNTED
	 
	 
SYS@xydbdg> select name,value,time_computed,datum_time from v$dataguard_stats;

NAME				 VALUE								  TIME_COMPUTED 		 DATUM_TIME
-------------------------------- ---------------------------------------------------------------- ------------------------------ ------------------------------
transport lag			 +00 00:00:00							  03/01/2024 17:12:38		 03/01/2024 17:12:36
apply lag			 +00 00:00:00							  03/01/2024 17:12:38		 03/01/2024 17:12:36
apply finish time		 +00 00:00:00.000						  03/01/2024 17:12:38
estimated startup time		 26								  03/01/2024 17:12:38


SYS@xydbdg> alter database open read only;
alter database open read only
*
ERROR at line 1:
ORA-10456: cannot open standby database; media recovery session may be in progress


SYS@xydbdg> SELECT PROCESS, STATUS FROM V$MANAGED_STANDBY;

PROCESS   STATUS
--------- ------------
ARCH	  CONNECTED
DGRD	  ALLOCATED
DGRD	  ALLOCATED
ARCH	  CONNECTED
ARCH	  CONNECTED
ARCH	  CONNECTED
RFS	  IDLE
RFS	  IDLE
RFS	  IDLE
RFS	  IDLE
MRP0	  APPLYING_LOG

11 rows selected.


SYS@xydbdg> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

Database altered.

SYS@xydbdg>  alter database open;

Database altered.

SYS@xydbdg> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

Database altered.

SYS@xydbdg> select database_role,protection_mode,protection_level,open_mode from v$database;

DATABASE_ROLE	 PROTECTION_MODE      PROTECTION_LEVEL	   OPEN_MODE
---------------- -------------------- -------------------- --------------------
PHYSICAL STANDBY MAXIMUM PERFORMANCE  MAXIMUM PERFORMANCE  READ ONLY WITH APPLY

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
SYS@xydbdg> 


SYS@xydbdg> SELECT inst_id, thread#, process, pid, status, client_process, client_pid,
sequence#, block#, active_agents, known_agents FROM gv$managed_standby ORDER BY thread#, pid;  2  

   INST_ID    THREAD# PROCESS	PID			 STATUS       CLIENT_P CLIENT_PID				 SEQUENCE#     BLOCK# ACTIVE_AGENTS KNOWN_AGENTS
---------- ---------- --------- ------------------------ ------------ -------- ---------------------------------------- ---------- ---------- ------------- ------------
	 1	    0 DGRD	7339			 ALLOCATED    N/A      N/A						 0	    0		  0	       0
	 1	    0 DGRD	7341			 ALLOCATED    N/A      N/A						 0	    0		  0	       0
	 1	    0 ARCH	7343			 CONNECTED    ARCH     7343						 0	    0		  0	       0
	 1	    0 ARCH	7347			 CONNECTED    ARCH     7347						 0	    0		  0	       0
	 1	    1 RFS	19607			 IDLE	      LGWR     19749					       102     260121		  0	       0
	 1	    1 ARCH	7345			 CLOSING      ARCH     7345					       101     354304		  0	       0
	 1	    1 RFS	8344			 IDLE	      Archival 24790						 0	    0		  0	       0
	 1	    2 MRP0	18654			 APPLYING_LOG N/A      N/A						89	16000		 17	      17
	 1	    2 RFS	19361			 IDLE	      LGWR     4037						89	16001		  0	       0
	 1	    2 ARCH	7337			 CLOSING      ARCH     7337						88     129024		  0	       0
	 1	    2 RFS	8352			 IDLE	      Archival 5124						 0	    0		  0	       0

11 rows selected.

SYS@xydbdg> select * from v$archive_gap;

no rows selected

SYS@xydbdg> 

```









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
