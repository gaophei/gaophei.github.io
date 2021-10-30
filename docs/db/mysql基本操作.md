###登录mysql

```bash
mysql -u root -p
```



<br>

###库相关操作

```mysql
show databases;

create database test1 character set utf8mb4 collate utf8mb4_unicode_ci;

drop database test1;
```



<br>

##表相关操作

```mysql
use mysql;

show tables;

create table table1 (id varchar(20),age char(1));

analyze table table1;

show index from table1;

drop table table1;


```



<br>

##用户相关操作

```mysql
set global validate_password.policy=0;

set global validate_password.length=1;

create user 'admin_center'@'%' identified with mysql_native_password  by 'xg@sufe1917';

grant all privileges on  admin_center.* to 'admin_center'@'%' with grant option;

flush privileges;

drop user  'admin_center'@'%' ;
```



<br>

##性能查询相关

```mysql
show processlist;

select * from information_schema.innodb_trx;

select * from performance_schema.data_lock_waits;

select * from performance_schema.data_locks;

kill sql_pid;
```



<br>

###执行计划

```mysql
explain select xxxx from xxx left join xxxxxx where xxx=xxxx;
```















