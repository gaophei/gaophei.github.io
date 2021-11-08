##POA升级，一般安装应用商店最新稳定版

###假设前期为yaml文件部署，版本较旧为0.1.0-SNAPSHOT

****

**升级步骤如下：**

1、首先做好以下备份：

   (1)rancher方面：

- 工作负载
- 负载均衡
- 服务发现
- 服务发现
- pvc
- 密文
- 配置映射

   (2)poa-sa的clients/secrets，以域名为例：https://poa-sa.xxx.edu.cn/

   网页打开`https://poa-sa.xxx.edun.cn/v1/clients/dump`，并保存内容

```yaml
{
  "items": [
    {
      "clientId": "0jIAbV3KSfliKlGjTzM36K9F2fs=",
      "clientName": "消息服务",
      "scopes": [
        "authz:v1:readRole",
        "messagecenter:v1:readMessage",
        "messagecenter:v1:sendMessage",
        "messagecenter:v1:writeMessage",
        "user:v1:readGroup",
        "user:v1:readLabel",
        "user:v1:readOrganization",
        "user:v1:readPost",
        "user:v1:readUser",
        "user:v1:readUserSecret"
      ],
      "clientSecretHash": "SRF-eEYflkxGG4-veutLxB9WgLtJDpQt8TYUkVb-aDY="
    },
    {
      "clientId": "UJrCCoYjssBnGvWKI46lzAVOqQM=",
      "clientName": "formflow",
      "scopes": [
        "authz:v1:readRole",
        "messagecenter:v1:sendMessage",
        "user:v1:readGroup",
        "user:v1:readLabel",
        "user:v1:readOrganization",
        "user:v1:readUser"
      ],
      "clientSecretHash": "hKza6ULjkT2S-8GvjGGtHyZqvcQP4AhTtAhwTnRoclI="
    },
    {
      "clientId": "17xlMHqHJPQoXwDVhh8PYttKoBM=",
      "clientName": "ttc",
      "scopes": [
        "authz:v1:readRole",
        "messagecenter:v1:sendMessage",
        "user:v1:readGroup",
        "user:v1:readLabel",
        "user:v1:readOrganization",
        "user:v1:readUser"
      ],
      "clientSecretHash": "g87xM8hfk8PpN1TA3JpYyJK3iM6VJUxuOF6Ms5rusyA="
    },
    {
      "clientId": "fXeA4BxB43k4xn1kjxSoBAaplZU=",
      "clientName": "portal-service",
      "scopes": [
        "admincenter:v1:readMenu",
        "authz:v1:readRole",
        "communicate:v1:communicationCheck",
        "communicate:v1:communicationSend",
        "messagecenter:v1:readMessage",
        "messagecenter:v1:sendMessage",
        "messagecenter:v1:writeMessage",
        "user:v1:readGroup",
        "user:v1:readLabel",
        "user:v1:readOrganization",
        "user:v1:readPost",
        "user:v1:readUser"
      ],
      "clientSecretHash": "QkPt73w_jq9t3CdZlgV_2Xn5m5J6rEhUHB87eNSLrNU="
    },
    {
      "clientId": "fe9LXzGkgfzX8RUzxrXHrgoS6gQ=",
      "clientName": "数据资产",
      "scopes": [
        "admincenter:v1:readMenu",
        "authz:v1:readRole",
        "user:v1:readGroup",
        "user:v1:readLabel",
        "user:v1:readOrganization",
        "user:v1:readUser",
        "user:v1:readUserSecret"
      ],
      "clientSecretHash": "Dsc1Qbdub23R3yYq_RSG_1NRGujtK8vdIasfMYfZrV4="
    }
  ]
}
```
2、将第一步中rancher方面的内容全部删除

3、点击应用商店安装最新稳定版

​       应用商店搜索platform-openapi，当前版本为1.4.1，填写相关内容，重新生成poa的相关内容，如果缺少poa-sa的ingress，需要自己手动加一下。

​       注意：如果mysql版本为8.0.11，pod`db-initializer`可能会报错，需要

​       (1)在数据库platform-openapi下单独执行以下sql：

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

​     (2)将platform-openapi库下的`schema_version`表中的最后一项内容seccess列改为`1`

 4、将原poa-sa的clients/secrets导入，需在docker服务器上执行，将第一步中保存的内容放到`-d ''`中，比如：

 ```yaml
 curl -i -s -X POST -H 'Content-Type: application/json' -d '{
   "items": [
     {
       "clientId": "0jIAbV3KSfliKlGjTzM36K9F2fs=",
       "clientName": "消息服务",
       "scopes": [
         "authz:v1:readRole",
         "messagecenter:v1:readMessage",
         "messagecenter:v1:sendMessage",
         "messagecenter:v1:writeMessage",
         "user:v1:readGroup",
         "user:v1:readLabel",
         "user:v1:readOrganization",
         "user:v1:readPost",
         "user:v1:readUser",
         "user:v1:readUserSecret"
       ],
       "clientSecretHash": "SRF-eEYflkxGG4-veutLxB9WgLtJDpQt8TYUkVb-aDY="
     },
     {
       "clientId": "UJrCCoYjssBnGvWKI46lzAVOqQM=",
       "clientName": "formflow",
       "scopes": [
         "authz:v1:readRole",
         "messagecenter:v1:sendMessage",
         "user:v1:readGroup",
         "user:v1:readLabel",
         "user:v1:readOrganization",
         "user:v1:readUser"
       ],
       "clientSecretHash": "hKza6ULjkT2S-8GvjGGtHyZqvcQP4AhTtAhwTnRoclI="
     },
     {
       "clientId": "17xlMHqHJPQoXwDVhh8PYttKoBM=",
       "clientName": "ttc",
       "scopes": [
         "authz:v1:readRole",
         "messagecenter:v1:sendMessage",
         "user:v1:readGroup",
         "user:v1:readLabel",
         "user:v1:readOrganization",
         "user:v1:readUser"
       ],
       "clientSecretHash": "g87xM8hfk8PpN1TA3JpYyJK3iM6VJUxuOF6Ms5rusyA="
     },
     {
       "clientId": "fXeA4BxB43k4xn1kjxSoBAaplZU=",
       "clientName": "portal-service",
       "scopes": [
         "admincenter:v1:readMenu",
         "authz:v1:readRole",
         "communicate:v1:communicationCheck",
         "communicate:v1:communicationSend",
         "messagecenter:v1:readMessage",
         "messagecenter:v1:sendMessage",
         "messagecenter:v1:writeMessage",
         "user:v1:readGroup",
         "user:v1:readLabel",
         "user:v1:readOrganization",
         "user:v1:readPost",
         "user:v1:readUser"
       ],
       "clientSecretHash": "QkPt73w_jq9t3CdZlgV_2Xn5m5J6rEhUHB87eNSLrNU="
     },
     {
       "clientId": "fe9LXzGkgfzX8RUzxrXHrgoS6gQ=",
       "clientName": "数据资产",
       "scopes": [
         "admincenter:v1:readMenu",
         "authz:v1:readRole",
         "user:v1:readGroup",
         "user:v1:readLabel",
         "user:v1:readOrganization",
         "user:v1:readUser",
         "user:v1:readUserSecret"
       ],
       "clientSecretHash": "Dsc1Qbdub23R3yYq_RSG_1NRGujtK8vdIasfMYfZrV4="
     }
   ]
 }' 'https://poa-sa.xxx.edu.cn/v1/clients/import'
 ```

如果服务器返回`HTTP/1.1 200 OK`，则表示导入成功

5、部署完成后的检查：

(1)打开`https://poa-sa.xxx.edu.cn/v1/clients`，查看是否与原内容相符；

(2)打开门户、流程等需要调用poa的应用，是否正常。
