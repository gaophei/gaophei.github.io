# mysql8版本升级(RPM包)8.0.11升级到8.0.27





#### 1、备份数据库

```bash
/usr/bin/mysqldump -u root -p --quick --events --all-databases --master-data=2 --single-transaction --set-gtid-purged=OFF > 20220117001.sql
```

#### 2、清理缓存并关闭mysql

```bash
mysql -u root -p --execute="SET GLOBAL innodb_fast_shutdown=0"

systemctl stop mysqld
```

#### 3、下载最新安装包

```bash
wget https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.27-1.el7.x86_64.rpm-bundle.tar

tar -xvf mysql-8.0.27-1.el7.x86_64.rpm-bundle.tar
```

#### 4、mysql数据库升级

```bash
rpm -Uvh  *.rpm
#提示依赖，执行下一步
rpm -Uvh  *.rpm  --nodeps --force
```

#### 5、启动升级

```bash
systemctl start mysqld
systemctl status mysql

mysqld --upgrade=NONE
```

#### 6、查看版本

```bash
mysql -V

mysql -u root -p
\s
```

#### 7、如果数据库出现数据问题，进行数据库还原，如果正常，本步忽略

```bash
mysql -u root -p
```

```mysql
source /root/20220117001.sql
```
