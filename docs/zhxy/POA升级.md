**注意：本文指南讲的是非商店部署 迁移到 商店部署的方案**

****

## 升级步骤

第一步：导出旧POA的Client信息

以域名为例：https://poa-sa.xxx.edu.cn/

网页打开`https://poa-sa.xxx.edun.cn/v1/clients/dump`，并保存内容

第二步：删除旧POA的Ingress

先做好备份，然后记住旧POA的域名

第三步：商店安装

商店安装最新稳定版POA（版本号里不带alpha的都是稳定版）

注意：

* 新的POA的Ingress的域名设置为第二步中提到的域名
* 新的POA和旧的POA不在同一个Namespace
* 安装完新POA之后，所有指向旧POA K8S集群内部地址的服务，都要修改
* 新POA依然使用旧POA的MySQL数据库

第四步：导入旧POA的Client信息

将第一步得到的Client信息，导入到新POA中

```bash
curl -i -s -X POST -H 'Content-Type: application/json' -d '<CLIENT信息JSON>' 'https://poa-sa.xxx.edu.cn/v1/clients/import'
```

### 已知问题

如果MySQL版本过低，比如8.0.11，pod `db-initializer`会报错：

解决办法：

1）手动到POA数据库执行以下SQL：

```mysql
CREATE TABLE API_FIELD_MOD_RULES
(
    SERVICE_ID     VARCHAR(100) NOT NULL COMMENT '所属Service',
    API_VERSION    VARCHAR(100) NOT NULL COMMENT '所属ApiVersion',
    OPERATION_ID   VARCHAR(100) NOT NULL COMMENT 'OperationId',
    JSONPATH_RULES LONGTEXT     NOT NULL  COMMENT '字段jsonpath->规则',

    CONSTRAINT API_FIELD_MOD_RULES$UK UNIQUE (SERVICE_ID, API_VERSION, OPERATION_ID)
)
    COMMENT 'API响应字段值修改规则';

CREATE TABLE CLIENT_BACKUP
(
    TIMESTAMP CHAR(19) NOT NULL,
    REMARK    TEXT,
    DATA      MEDIUMTEXT,
    CONSTRAINT PK PRIMARY KEY (TIMESTAMP)
)
    COMMENT 'Client数据备份';
    
```

2）修改数据库`schema_version`表中的最后一行的`success`列改为`1`

## 部署后检查

部署完成后的检查：

1. 打开`https://poa-sa.xxx.edu.cn/v1/clients`，查看是否与原内容相符；
2. 把旧POA的Pod数量都改为0。
3. 打开门户、流程等需要调用poa的应用，是否正常。

如果一切检查正常，建议保留一周，如果现场没有发生问题，再把旧POA完全删除。

## 回退步骤

1）在应用商店里把新POA删除。

2）恢复旧POA的Ingress。
