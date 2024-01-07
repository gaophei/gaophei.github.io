## 1.系统环境

### 1.1.主备库信息

|                                                              | 主库                            | 备库                               |
| ------------------------------------------------------------ | ------------------------------- | ---------------------------------- |
| db_name(主备库必须一致)                                      | xydb                            | xydb                               |
| db_unique_name(主备库必须不一致)<br />(此处如果相同，必须修改备库参数) | xydb                            | xydb                               |
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





#主库

```bash
SYS@xydb1> show parameter name

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
cdb_cluster_name		     string
cell_offloadgroup_name		     string
db_file_name_convert		     string
db_name 			     string	 xydb
db_unique_name			     string	 xydb
global_names			     boolean	 FALSE
instance_name			     string	 xydb1
lock_name_space 		     string
log_file_name_convert		     string
pdb_file_name_convert		     string
processor_group_name		     string
service_names			     string	 xydb


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

### 2.1.配置备库的db_unique_name

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



### 2.2.配置主、备库的tnsnames.ora和备库的lisntener.ora

#### 2.2.1.配置主、备库的tnsnames.ora

#xydb1/xydb2/xydbdg三个都要修改

```bash
su - oracle

cd $ORACLE_HOME/network/admin

vi tnsnames.ora
```



#参考

```
xydb =
(DESCRIPTION =
(ADDRESS = (PROTOCOL = TCP)(HOST = 主库节点1vip)(PORT = 1521))
(ADDRESS = (PROTOCOL = TCP)(HOST = 主库节点2vip)(PORT = 1521))
(CONNECT_DATA =
(SERVER = DEDICATED)
(SERVICE_NAME = xydb)
)
)

xydbdg =
(DESCRIPTION =
(ADDRESS = (PROTOCOL = TCP)(HOST = 备库IP)(PORT = 1521))
(CONNECT_DATA =
(SERVER = DEDICATED)
(SERVICE_NAME = xydbdg)
)
```



#实际配置

```
xydb =
(DESCRIPTION =
(ADDRESS = (PROTOCOL = TCP)(HOST = 主库节点1vip)(PORT = 1521))
(ADDRESS = (PROTOCOL = TCP)(HOST = 主库节点2vip)(PORT = 1521))
(CONNECT_DATA =
(SERVER = DEDICATED)
(SERVICE_NAME = xydb)
)
)

xydbdg =
(DESCRIPTION =
(ADDRESS = (PROTOCOL = TCP)(HOST = 备库IP)(PORT = 1521))
(CONNECT_DATA =
(SERVER = DEDICATED)
(SERVICE_NAME = xydbdg)
)
```





### 2.3.主库修改





