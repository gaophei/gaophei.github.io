su - oracle

###登录

```bash
sqlplus / as sysdba
```

###查看PDBs

```oracle
show pdbs;
```

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

##rman备份

- crontab -l

```bash
30 0 * * * /home/oracle/rmanbak/rmanbak.sh
```



- rmanbak.sh

```bash
#!/bin/bash

time=$(date +"%Y%m%d")
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
   alter system archive log current;
   backup as compressed backupset database plus archivelog delete all input; 
   alter system archive log current;
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





