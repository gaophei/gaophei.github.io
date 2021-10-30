su - oracle

lsnrctl status



<br>

env|grep LANG

env|grep NLS_LANG



<br>

sqlplus / as sysdba

##查看归档

```oracle
select * from dual;

archive log list;

show parameter recovery
```



<br>

##生产环境部分参数

```oracle
show parameter process;

alter profile default limit password_life_time unlimited;
```



<br>

##创建表空间及用户

```oracle
select file_name,tablespace_name from dba_data_files;

create tablespace portal_service datafile '/u01/app/oracle/oradata/xydb/portal01.dbf' size 1G autoextend on next 1G maxsize 31G ;

alter tablespace portal_service add datafile '/u01/app/oracle/oradata/xydb/portal02.dbf' size 1G autoextend on next 1G maxsize 31G ;

create user portal_service identified by Oraps485Cle default tablespace portal_service;
grant dba to portal_service;

drop user portal_service cascade;
```



<br>

##字符集

```
select userenv('language') from dual;
```

```bash
##学工客户端
export NLS_LANG="SIMPLIFIED CHINESE_CHINA".AL32UTF8
sqlplus / as sysdba
select userenv('language') from dual;
```



<br>

##数据泵导出导入

```oracle
sqlplus / as sysdba
create directory expdir as '/home/oracle';
grant read,write on directory expdir to public;
exit

expdp impdp idc_u_stuwork/password@xydb directory=expdir  dumpfile=oracle_6.0.8.dmp  remap_schema=bladex_release:idc_u_stuwork transform=segment_attributes:n logfile=oracle_6.0.8impdp.log exclude=statistics

impdp idc_u_stuwork/password@xydb directory=expdir  dumpfile=oracle_6.0.8.dmp  remap_schema=bladex_release:idc_u_stuwork transform=segment_attributes:n logfile=oracle_6.0.8impdp.log exclude=statistics

##如果impdp时有报错ORA-39082: 对象类型 ALTER_PROCEDURE:"IDC_U_STUWORK"."REPAIR_DORM_DATA" 已创建, 但带有编译警告
sqlplus idc_u_stuwork/password
alter procedure REPAIR_DORM_DATA compile;
```



<br>

##imp/exp

