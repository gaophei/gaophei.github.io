****oracle日常操作及运维****

<strong style="color:red;">生产环境注意操作安全！！！</strong>


### 日常操作

#查看监听
```bash
su - oracle

lsnrctl status
```

#查看OS字符集
```bash
env|grep LANG

env|grep NLS_LANG
```
```bash
sqlplus / as sysdba
```
##查看归档

```oracle
select * from dual;

archive log list;

show parameter recovery

select * from v$recovery_area_usage;
```

##开启归档，注意需重启数据库实例！
```oracle
shutdown immediate;

startup mount;
alter database archivelog ;
alter database open;

archive log list;

show parameter recovery;
#根据实际磁盘大小设置FRA大小
 alter system set db_recovery_file_dest_size=100G;
```

##删除归档

```oracle
rman target /

#全部删除
delete noprompt archivelog all;

###删除三天前归档
delete noprompt archivelog until time 'sysdate-3';
```

##生产环境部分参数

```oracle
#process参数,需重启oracle实例
show parameter process;

alter system set processes=2000 scope=spfile;

#用户密码过期时间
alter profile default limit password_life_time unlimited;
```

#创建表空间及用户

#单实例

```oracle
select file_name,tablespace_name from dba_data_files;

create tablespace portal_service datafile '/u01/app/oracle/oradata/xydb/portal01.dbf' size 1G autoextend on next 1G maxsize 31G ;

alter tablespace portal_service add datafile '/u01/app/oracle/oradata/xydb/portal02.dbf' size 1G autoextend on next 1G maxsize 31G ;

create user portal_service identified by Oraps485Cle default tablespace portal_service;
grant dba to portal_service;

drop user portal_service cascade;
```

#RAC中表空间添加数据文件，以实际环境为准

```oracle
select file_name,tablespace_name from dba_data_files;

alter tablespace portal_service add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G ;
```
#oracle字符集

```oracle
select userenv('language') from dual;
```

```bash
#比如学工客户端
export NLS_LANG="SIMPLIFIED CHINESE_CHINA".AL32UTF8

sqlplus / as sysdba
select userenv('language') from dual;
```
### 备份

##数据泵导出导入，需oracle服务器端执行

```oracle
sqlplus / as sysdba
create directory expdir as '/home/oracle';
grant read,write on directory expdir to public;
exit

expdp idc_u_stuwork/password directory=expdir  dumpfile=oracle_6.0.8.dmp logfile=oracle_6.0.8impdp.log exclude=statistics

impdp idc_u_stuwork/password directory=expdir  dumpfile=oracle_6.0.8.dmp  remap_schema=bladex_release:idc_u_stuwork transform=segment_attributes:n logfile=oracle_6.0.8impdp.log exclude=statistics

#如果impdp时有报错ORA-39082: 对象类型 ##ALTER_PROCEDURE:"IDC_U_STUWORK"."REPAIR_DORM_DATA" 已创建, 但带有编译警告
sqlplus idc_u_stuwork/password
alter procedure REPAIR_DORM_DATA compile;
```

#i#mp/exp，可以非oracle服务器端执行

```oracle
#用户idc_u_stuwork导出
exp username/password@ip:1521/xydb owner=idc_u_stuwork file=20211216.dmp log=20211216.log statistics=none

#全库导出
exp username/password@ip:1521/xydb full=y file=20211216.dmp log=20211216.log statistics=none

#导入
imp username/password@ip:1521/xydb file=20211216.dmp log=20211216.log
```

#rman备份

```bash
crontab -e
```
#添加以下内容
30 1 * * * /home/oracle/rmanbak/rmanbak.sh

#备份脚本rmanbak.sh

```
#!/bin/bash

time=$(date +"%Y%m%d")

#备份目录，以实际情况为准
rman_dir=/home/oracle/rmanbak

if [ -f $HOME/.bash_profile ]; then
    . $HOME/.bash_profile
elif [ -f $HOME/.profile ]; then
        . $HOME/.profile
fi

echo `date` > $rman_dir/rmanrun.log
  
rman target / log=$rman_dir/rmanfullbak_$time.log append <<EOF
run{
   CONFIGURE CONTROLFILE AUTOBACKUP ON;
   CONFIGURE BACKUP OPTIMIZATION ON;
   allocate channel c1 type disk;
   allocate channel c2 type disk;
   allocate channel c3 type disk;
   allocate channel c4 type disk;
   sql 'alter system archive log current';
   backup as compressed backupset database plus archivelog delete all input; 
   sql 'alter system archive log current';
   backup archivelog all;
   crosscheck backup;
   delete noprompt obsolete;
   delete noprompt expired backup;
   release channel c1;
   release channel c2;
   release channel c3;
   release channel c4;
}
exit;
EOF
 >> $rman_dir/rmanrun.log
#delete 7days before log 
find $rman_dir -name 'rmanfullbak_*.log' -mtime +7 -exec rm {} \;
echo `date ` >> $rman_dir/rmanrun.log

```

### 异常处理

###process耗尽

```bash
###linux 查看
ps -x|grep LOCAL=NO|grep –v |wc –l
```

```oracle
###sqlplus 查看
select * from v$resource_limit where resource_name in ('processes','sessinos');

select username,count(username) from v$session where username is not null group by username;

###将异常用户锁定
alter user user1 account lock; 
```

```bash
###快速关闭连接
ps -ef|grep LOCAL=NO|grep -v grep|cut –c 9-15|xargs kill -9 
```

#死锁

#查询

```oracle
select osuser,machine,program,module,sid,serial#,event,t2.logon_time
from v$locked_object t1,v$session t2
where t1.session_id=t2.sid order by t2.logon_time;
```
#kill session

```oracle
alter system kill session 'sid,serial#';
```



