##mongo可以用navicat15连接

##数据库基本操作

```mongo
mongo
show dbs;
use guide;

show collections;
db.sysconfig.find();
db.sysconfig.insert(xxx,yyy);
```

##数据文件修复

```bash
mongod --repair --dbpath=/data
```

