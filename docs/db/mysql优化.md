 /etc/my.cnf
```mysql
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
server-id=220 #第二台server-id=82
port=3306
character-set-server=utf8mb4
default-time_zone='+8:00'
#lower_case_table_names=1

binlog_format=ROW
log-bin=mysql-bin
auto_increment_increment=2 
auto_increment_offset=1   #第二台auto_increment_offset=2
binlog_expire_logs_seconds=604800
max_binlog_size = 100M

innodb_buffer_pool_chunk_size=536870912
innodb_buffer_pool_instances=4
innodb_buffer_pool_size=4294967296

max_connections=2000
max_connect_errors=100000

default_authentication_plugin=mysql_native_password
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock

log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid


skip_name_resolve = 1


long_query_time=15
slow_query_log = 1
slow_query_log_file=/var/lib/mysql/slow.log



[client]
port=3306
#default-character-set=utf8mb4
socket=/var/lib/mysql/mysql.sock

[mysql]
no-auto-rehash
default-character-set=utf8mb4

```
    


安装完MySQL后，优化MySQL的几个参数：

## buffer pool size

修改`/etc/my.cnf`添加以下：

如果服务器有32G内存：

```mysql
...
[mysqld]
...
innodb_buffer_pool_chunk_size=1073741824
innodb_buffer_pool_instances=4
innodb_buffer_pool_size=8589934592
```

如果服务器有16G内存：

```mysql
...
[mysqld]
...
innodb_buffer_pool_chunk_size=536870912
innodb_buffer_pool_instances=4
innodb_buffer_pool_size=4294967296
```

如果服务器有8G内存：

```mysql
...
[mysqld]
...
innodb_buffer_pool_chunk_size=536870912
innodb_buffer_pool_instances=4
innodb_buffer_pool_size=2147483648
```

如果你要自由调整，一定要注意：

* innodb_buffer_pool_size 必须是 innodb_buffer_pool_instances * innodb_buffer_pool_chunk_size 的倍数。

参考文档 [Configuring InnoDB Buffer Pool Size](https://dev.mysql.com/doc/refman/5.7/en/innodb-buffer-pool-resize.html)。

## 客户端连接数

TODO


