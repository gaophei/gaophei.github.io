su - oracle

sqlplus / as sysdba

show pdbs;



##创建PDB

```oracle
create pluggable database urpdb admin user urpdb identified by J38xmmAqbc12ed roles=(dba);

alter pluggable database urpdb open;

alter session set container=urpdb;
```



##创建tablespace

```oracle
create tablespace urpdb datafile '+DATA' size 1G autoextend on next 1G maxsize 31G extent management local segment space management auto;

alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;

alter tablespace urpdb add datafile '+DATA' size 1G autoextend on next 1G maxsize 31G;
```



##创建用户

```oracle
create user urpuser identified by L333xnneJJ6EYn default tablespace urpdb account unlock;

grant dba to urpuser;

grant select any table to urpuser;
```





##创建service

```oracle
srvctl add service -d xydb -s s_urpdb -r xydb1,xydb2 -P basic -e select -m basic -z 180 -w 5 -pdb urpdb

srvctl start service -d xydb -s s_urpdb

lsnrctl status 
```





##连接方式

```oracle
sqlplus urpuser/L333xnneJJ6EYn@10.8.14.15:1521/s_urpdb
```



