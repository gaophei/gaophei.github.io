

```
# 现在有一套有三个节点组成的elasticsearch集群(node01/node02/node03，elasticsearch 7.7.1)，数据量200G，
ES访问： 
  https://10.40.10.124:9200
  https://10.40.10.125:9200
  https://10.40.10.126:9200

kibana访问: http://10.40.10.124:5601

原快照仓库为es_snp，
快照本地目录为/snp，为Nfs共享目录，挂载点：10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp

现在有三台新的节点(node11/node12/node13)，同样版本部署ES集群，新ES访问：
  https://222.24.203.42:9200
  https://222.24.203.43:9200
  https://222.24.203.44:9200

kibana访问: http://222.24.203.42:5601


请问在把旧ES集群原地保留的情况下，并且不破坏原来快照的前提下，如何迁移该ES集群数据到新的ES集群，请给出详细的实施步骤。
```

------------------------------------------------



下面给出一种在“保留旧集群不动、且不破坏原有快照”的前提下，将旧 ES 集群数据迁移到新 ES 集群的标准做法：借助现有的 NFS 快照仓库进行“跨集群恢复”。核心原则是：新集群对该仓库只读，旧集群继续负责写入/生成快照。

### 0、术语与环境变量

```
# 旧集群
OLD_CLUSTER=https://10.40.10.124:9200     # 同一集群任意节点即可
OLD_REPO=/snp                             # 旧集群快照目录（本地磁盘）
OLD_USER=elastic
OLD_PASS=xxxx

# 新集群
NEW_CLUSTER=https://222.24.203.42:9200
NEW_REPO=/snp                             # 给新集群也挂载到同一路径
NEW_USER=elastic
NEW_PASS=yyyy
```

### 一、迁移思路

- 继续使用旧集群当前的快照仓库 es_snp（NFS 共享10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp，对应本地路径 /snp）。
- 在新集群的三台节点上同样以只读模式挂载该 NFS 到 /snp，并在新集群里注册一个同名的快照仓库 es_snp，但设置为 readonly=true，且创建时 verify=false，避免任何写入或“验证写测试”，从而不改动现有仓库内容。
- 在旧集群上创建一次（或多次）快照；在新集群从该快照执行恢复,做 **Snapshot→Restore** 完成一次性全量迁移；通过 **增量快照** 或 **Reindex-from-Remote** 完成停机前的最后同步。
- 完成数据校验后切流量到新集群。为安全起见，切换后为新集群配置一个“新的、独立的”快照仓库用于后续备份，避免对原仓库造成影响。

### 二、前提与检查

- 版本匹配：两套 ES 都是 7.7.1（已满足），若版本不同，必须先把旧集群升/降到与新集群相同的 **次版本**（7.x.y）；Kibana 版本需与 ES 兼容。
- 插件一致：新集群需安装与旧集群相同的插件、分词器（例如 analysis-ik、ingest-attachment 等），否则恢复后索引可能因缺少 analyzer/pipeline 无法打开，可以检查目录`/opt/elasticsearch/plugins`。
- 资源与参数：新集群磁盘空间足够容纳 200G 数据与副本；JVM heap、磁盘水位线、水位线参数（cluster.routing.allocation.disk.watermark.*）合理。
- 权限/证书：已知 elastic（或具备快照/恢复权限的）账号的密码；curl 访问 https 需要加 -k（自签证书）或正确的 CA。

### 三、在旧集群上准备“最终快照”
为尽量减少切换时差，建议在窗口期前先做一次全量快照预热（可选），在真正切换时再做一次最终快照。

- 可选预热快照（不停机）：在旧集群任一节点上执行（示例取 10.40.10.124）
  ```bash
  curl -k -u elastic:$OLD_PASS https://10.40.10.124:9200/_snapshot/es_snp/pre_mig_1?wait_for_completion=true -X PUT -H "Content-Type: application/json" -d '{}'
  ```
  
- 真正切换前的最终快照（建议在停写后执行，见第六部分）：
  ```bash
  #curl -k -u elastic https://10.40.10.124:9200/_snapshot/es_snp/final_mig?wait_for_completion=true -X PUT -H "Content-Type: application/json" -d '{}'
  
  SNAP=full_$(date +%Y%m%d_%H%M)
  curl -u elastic -k -X PUT "https://10.40.10.124:9200/_snapshot/es_snp/$SNAP?wait_for_completion=true" -H 'Content-Type: application/json' -d'
  {
    "indices": "*,-.security-7,-.kibana_*,-.apm-*,-.monitoring-*",
    "ignore_unavailable": true,
    "include_global_state": true
  }'
  ```
  
  
  说明：
  
- 不指定 indices 就表示对所有可见索引拍快照（包括系统索引）。若你不想带上部分监控/历史索引，可在 body 中用 indices 进行过滤。

- wait_for_completion=true 便于直接等待任务完成并获知结果。

### 四、在新集群挂载 NFS 并注册“只读仓库”，让两套集群都能访问 **同一份** `/snp`  

#### 1. 在 node11/node12/node13 上以只读模式挂载 NFS（以 Linux 为例，确保已安装 nfs-utils）
- 创建本地挂载目录并授权：
  ```bash
  mkdir -p /snp
  #chown -R elasticsearch:elasticsearch /snp
  ```
  
- 挂载（示例参数，按你现网 NFS 实际版本/要求调整，可用 vers=3 或 vers=4，均需测试稳定性）
  ```bash
  #mount -t nfs -o vers=3,proto=tcp,hard,nointr,timeo=600,retrans=2,ro 10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp /snp
  
  mount -t nfs -o ro 10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp /snp
  ```
  
- 建议将该挂载写入 /etc/fstab，确保重启后仍自动挂载。

  ```bash
  cat >> /etc/fstab <<EOF
  10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp   /snp   nfs   ro,_netdev   0  0
  EOF
  ```

  

- 确认三台新节点的 /snp 内容与旧集群一致（能看到快照仓库下的 index-*, snap-*, meta-* 等文件/目录）。

- • 若不能共享网络存储，可先 `rsync -a --delete /snp/ node11:/snp/` 完成一次全量复制，后续再增量同步。

#### 2. 修改es节点的elasticsearch.yml

   ```bash
   su - elasticsearch
   
   cat >> /opt/elasticsearch/config/elasticsearch.yml <<EOF
   path.repo: ["/snp"]
   EOF
   
   su - root
   systemctl restart elasticsearch
   ```

   #否则在注册快照仓库时会报错
   ```log
   {
    "error" : {
    "root_cause" : [
      {
        "type" : "repository_exception",
        "reason" : "[es_snp] location [/snp] doesn't match any of the locations specified by path.repo because this setting is empty"
      }
    ],
    "type" : "repository_exception",
    "reason" : "[es_snp] failed to create repository",
    "caused_by" : {
      "type" : "repository_exception",
      "reason" : "[es_snp] location [/snp] doesn't match any of the locations specified by path.repo because this setting is empty"
    }
    },
    "status" : 500
   }
   ```

   ```log
   #/data/log/elasticsearch.log
   [2025-08-12T16:27:34,425][WARN ][r.suppressed             ] [node-1] path: /_snapshot/es_snp, params: {pretty=true, verify=false, repository=es_snp}
   org.elasticsearch.transport.RemoteTransportException: [node-2][222.24.203.43:9300][cluster:admin/repository/put]
   Caused by: org.elasticsearch.repositories.RepositoryException: [es_snp] failed to create repository
   
   ```
   ```bash
   [elasticsearch@es01 ~]$ curl -k -u elastic "https://222.24.203.42:9200/_snapshot/es_snp?verify=false" -X PUT -H "Content-Type: application/json" -d '{"type":"fs","settings":{"location":"/snp","compress":true,"readonly":true}}'
   Enter host password for user 'elastic':
   {"error":{"root_cause":[{"type":"repository_exception","reason":"[es_snp] location [/snp] doesn't match any of the locations specified by path.repo because this setting is empty"}],"type":"repository_exception","reason":"[es_snp] failed to create repository","caused_by":{"type":"repository_exception","reason":"[es_snp] location [/snp] doesn't match any of the locations specified by path.repo because this setting is empty"}},"status":500}
   
   ```

#### 3. 在新集群注册快照仓库 es_snp（新集群需要注册一模一样的仓库名字，只读，且跳过验证写）
- 在新集群任一节点上执行（示例取 222.24.203.42）：
  ```bash
  curl -k -u elastic "https://222.24.203.42:9200/_snapshot/es_snp?verify=false" -X PUT -H "Content-Type: application/json" -d '{"type":"fs","settings":{"location":"/snp","compress":true,"readonly":true}}'
  ```
  #或者在kibana上执行
  ```bash
  PUT _snapshot/es_snp?verify=false
  {
  "type": "fs",
  "settings": {
    "location": "/snp",
    "readonly": true
  }
  }
  ```
- 如果返回 `acknowledged=true` 则成功。
- 查看仓库内可用快照列表，确认读取正常：
  
  ```bash
  curl -k -u elastic https://222.24.203.42:9200/_snapshot/es_snp/_all
  ```

重要：
- 一定要 readonly=true，且 verify=false，避免新集群对仓库进行写测试或生成新快照文件，从而“改动/污染”原仓库。
- 新、旧集群不要同时对同一仓库进行写入。旧集群保持原仓库读写，新集群只读。

### 五、在新集群执行恢复

#### 1. 确认插件已安装、集群空干净（或没有会冲突的同名索引）
#### 2. 选择要恢复的快照（例如 final_mig，或预热时的 pre_mig_1）
- 恢复全部索引（不包含系统索引）到新集群，示例：
  
  ```bash
  curl -k -u elastic https://222.24.203.42:9200/_snapshot/es_snp/full_20250812_1809/_restore -X POST -H "Content-Type: application/json" -d '{"indices":"cas_server__*,authx_log__*","ignore_unavailable":true,"include_global_state":false}'
  ```
  `accepted` 表示已进入恢复队列。
  
  
  
   #参考命令
  
  ```bash
  curl -k -u elastic https://222.24.203.42:9200/_snapshot/es_snp/full_20250812_1809/_restore -X POST -H "Content-Type: application/json" -d '{"indices":"*,-.security-7,-.kibana_*,-.apm-*,-.monitoring-*","ignore_unavailable":true,"include_global_state":false}'
  
  curl -X POST "https://222.24.203.42:9200/_snapshot/my_repo/daily-snap-2025.08.11-ianpf4s9sackqil4a5mcdw/_restore" -H 'Content-Type: application/json' -d '{
    "indices": "cas_server__*,authx_log__*,test",
    "include_global_state": false  // 排除全局状态，避免覆盖模板/角色
  }'
  
  #1.临时关闭分片自动分配，避免磁盘风暴  
  curl -u $NEW_USER:$NEW_PASS -k -X PUT "$NEW_CLUSTER/_cluster/settings" -H 'Content-Type: application/json' -d'
  {
    "transient": {
      "cluster.routing.allocation.enable": "none"
    }
  }'
  
  #2.下达 Restore 请求  
  curl -u $NEW_USER:$NEW_PASS -k -X POST "$NEW_CLUSTER/_snapshot/es_snp/$SNAP/_restore" -H 'Content-Type: application/json' -d'
  {
    "indices": "*",
    "ignore_unavailable": true,
    "include_global_state": true,
    "rename_pattern": "^(.*)$",
    "rename_replacement": "$1",
    "index_settings": {
      "index.number_of_replicas": 0      # 先不建副本，加快恢复
    }
  }'
  
  #3.打开分片分配并观测进度  
  curl -u $NEW_USER:$NEW_PASS -k -X PUT "$NEW_CLUSTER/_cluster/settings" -H 'Content-Type: application/json' -d'
  {
    "transient": {
      "cluster.routing.allocation.enable": "all"
    }
  }'
  watch -n 30 "curl -u $NEW_USER:$NEW_PASS -k -s $NEW_CLUSTER/_cat/recovery?v"
  
  #4.恢复完成后，把副本数调回 1 或 2 并进行 force-merge（可选）
  for i in $(curl -s -k -u $NEW_USER:$NEW_PASS $NEW_CLUSTER/_cat/indices?h=index); do
    curl -u $NEW_USER:$NEW_PASS -k -X PUT "$NEW_CLUSTER/$i/_settings" -H 'Content-Type: application/json' -d'{"index.number_of_replicas":1}';
  done
  
  
  POST _snapshot/es_snp/daily-snap-2025.08.11-ianpf4s9sackqil4a5mcdw/_restore
  {
    "indices": [
      "*" ,             // Include all indices...
      "-.monitoring-*", // ...except monitoring indices
      "-.kibana_*",     // ...except Kibana indices
      "-.apm-*",        // ...except APM indices
      "-.security-7"    // ...except the security index
    ],
    "include_global_state": true,
    "rename_pattern": "(.+)",
    "rename_replacement": "$1"
  }
  ```
  说明与建议：
  
- include_global_state 的选择：
  - 若你希望把模板、ILM 策略、管道、别名等全量带过来，并且旧集群没有奇怪的持久化集群参数（如分配过滤设置），可以用 true（新集群是空集群时一般安全）。
  - 若担心把旧集群的持久化设置带来影响（如曾设置过分配过滤到旧节点名称等），可用 false，然后单独迁移模板/ILM/管道（通过 GET/PUT API 导入导出）。这更“干净”，但稍麻烦。
  
- 若仅迁移业务索引，不想带系统索引（.security、.kibana 等），可在 indices 中用通配符过滤，如："indices":"-*.*,mybiz-*"。但若要把 Kibana 的可视化/索引模式、X-Pack 用户角色一并迁移，需恢复 .kibana* 与 .security。

- 如果你已经在新集群里创建了同名索引，恢复会因冲突失败。要么先删除这些索引，要么使用 rename_pattern/rename_replacement 将恢复到新的索引名。

- 因为两套集群的账户、密码等不同，所以排除系统索引，否则恢复后可能会出现：安全认证失败（证书冲突）；Kibana 无法启动或配置丢失；监控数据混乱（旧数据在新集群无意义）。

  - 系统索引`.kibana*`
  
    ```
    如果业务需要视图与仪表盘，可在旧集群单独快照 `.kibana_*`，然后在新集群 RESTORE；或使用 `Export/Import`。
    ```

  - 系统索引`.security`（用户/角色），因新旧ES集群不一致，可以排除
  
  ```bash
  curl -k -u elastic "https://10.40.10.124:9200/_security/user"
  
  curl -k -u elastic "https://222.24.203.42:9200/_security/user"
  ```
  
  

#### 3. 观察恢复进度与分片
- 活动恢复进度：
  ```bash
  curl -k -u elastic "https://222.24.203.42:9200/_cat/recovery?v&active_only=true"
  ```
- 分片与健康：
  ```bash
   curl -k -u elastic https://222.24.203.42:9200/_cat/health?v
  ```
- 索引列表与大小：
  ```bash
   curl -k -u elastic https://222.24.203.42:9200/_cat/indices?v
  ```
  

#日志
  ```logs
[elasticsearch@es01 ~]$ curl -k -u elastic "https://222.24.203.42:9200/_cat/recovery?v&active_only=true"
index                                       shard time type     stage source_host source_node target_host   target_node repository snapshot           files files_recovered files_percent files_total bytes       bytes_recovered bytes_percent bytes_total translog_ops translog_ops_recovered translog_ops_percent
authx_log__service_access_log_index-2024.03 0     1.1m snapshot index n/a         n/a         222.24.203.44 node-3      es_snp     full_20250812_1809 79    69              87.3%         79          4449175058  2385475498      53.6%         4449175058  0            0                      100.0%
authx_log__service_access_log_index-2024.10 0     1.1m snapshot index n/a         n/a         222.24.203.43 node-2      es_snp     full_20250812_1809 139   29              20.9%         139         2353600721  601330436       25.5%         2353600721  0            0                      100.0%
authx_log__apply_call_log_index-2024.08     0     1.1m snapshot index n/a         n/a         222.24.203.43 node-2      es_snp     full_20250812_1809 145   19              13.1%         145         23063681041 603731943       2.6%          23063681041 0            0                      100.0%
authx_log__apply_call_log_index-2024.09     0     1.1m snapshot index n/a         n/a         222.24.203.42 node-1      es_snp     full_20250812_1809 97    0               0.0%          97          12045470757 0               0.0%          12045470757 0            0                      100.0%
authx_log__apply_call_log_index-2024.03     0     1.1m snapshot index n/a         n/a         222.24.203.44 node-3      es_snp     full_20250812_1809 112   0               0.0%          112         224579523   0               0.0%          224579523   0            0                      100.0%
authx_log__apply_call_log_index-2023.12     0     1.1m snapshot index n/a         n/a         222.24.203.42 node-1      es_snp     full_20250812_1809 100   100             100.0%        100         143151212   143151212       100.0%        143151212   0            0                      100.0%
authx_log__service_access_log_index-2024.09 0     1.1m snapshot index n/a         n/a         222.24.203.44 node-3      es_snp     full_20250812_1809 115   10              8.7%          115         6553685392  596596792       9.1%          6553685392  0            0                      100.0%
authx_log__service_access_log_index-2024.08 0     1.1m snapshot index n/a         n/a         222.24.203.42 node-1      es_snp     full_20250812_1809 199   145             72.9%         199         4514060414  2850895195      63.2%         4514060414  0            0                      100.0%
authx_log__service_access_log_index-2024.05 0     1.1m snapshot index n/a         n/a         222.24.203.42 node-1      es_snp     full_20250812_1809 178   0               0.0%          178         4075517449  0               0.0%          4075517449  0            0                      100.0%
authx_log__service_access_log_index-2024.04 0     1.1m snapshot index n/a         n/a         222.24.203.43 node-2      es_snp     full_20250812_1809 190   0               0.0%          190         4115635648  0               0.0%          4115635648  0            0                      100.0%
authx_log__service_access_log_index-2024.07 0     1.1m snapshot index n/a         n/a         222.24.203.43 node-2      es_snp     full_20250812_1809 157   83              52.9%         157         4240604267  1784977166      42.1%         4240604267  0            0                      100.0%
authx_log__service_access_log_index-2024.06 0     1.1m snapshot index n/a         n/a         222.24.203.44 node-3      es_snp     full_20250812_1809 109   0               0.0%          109         4902512596  0               0.0%          4902512596  0            0                      100.0%
[elasticsearch@es01 ~]$


[elasticsearch@es01 ~]$ curl -k -u elastic https://222.24.203.42:9200/_cat/health?v
epoch      timestamp cluster    status node.total node.data shards pri relo init unassign pending_tasks max_task_wait_time active_shards_percent
1754994510 10:28:30  nwpu-newes yellow          3         3     20  13    0   12      118             0                  -                 13.3%
[elasticsearch@es01 ~]$

[elasticsearch@es01 ~]$  curl -k -u elastic:XIlreSzGM51dH44yuxo1 https://222.24.203.42:9200/_cat/indices?v
health status index                                        uuid                   pri rep docs.count docs.deleted store.size pri.store.size
yellow open   authx_log__service_access_log_index-2024.01  bzHwI_vURRWbwlw2_bOEAQ   1   1
yellow open   authx_log__service_access_log_index-2024.03  UZYWeLmrS8GqDlOr4mIeVw   1   1    5688537            0      4.1gb          4.1gb
yellow open   authx_log__service_access_log_index-2024.02  MaohoITYReKggwwhdcHNZA   1   1
yellow open   cas_server__service_access_log_index-2023.09 DEk_xautTyK56hrzziOpYg   1   1
yellow open   authx_log__authentication_log_index-2023.10  L6YDvoPDRs6uti_AtBRU8w   1   1
yellow open   authx_log__authentication_log_index-2023.11  5hag8D6aQ-K_WzOk9LON7w   1   1
yellow open   authx_log__authentication_log_index-2023.12  dGHN9aX-QGSGcY8_gmaefw   1   1
yellow open   cas_server__sso_log_index-2024.05            uOaBUBTbT9ixJ28yzNArRg   1   1
green  open   .apm-custom-link                             oD8EsH3sSWmaB5b2fGE01Q   1   1          0            0       416b           208b
green  open   .kibana_task_manager_1                       VD29NydpS4iJPg4WHDH5nA   1   1          5            1       52kb           20kb
yellow open   cas_server__sso_log_index-2024.06            jCr5HMFuQoadiHxIzzCXkg   1   1
yellow open   cas_server__sso_log_index-2024.07            PrH-ulX8SOiFqxL0bUplrQ   1   1
yellow open   cas_server__sso_log_index-2024.08            jJPSK0yKSwCiZBgXZ5bfWw   1   1
yellow open   cas_server__authentication_log_index-2023.12 yukzLf77REKWY1Zb44WSFw   1   1
yellow open   cas_server__authentication_log_index-2024.01 etRk7Bn4R4qAb-Mh0Yilaw   1   1
yellow open   authx_log__authentication_log_index-2024.10  VlCdX60_QIeF4buEpB2xdA   1   1
yellow open   authx_log__service_access_log_index-2024.10  69PYW345SL26zaYzw-h4-g   1   1    2705091            0      2.1gb          2.1gb
green  open   .apm-agent-configuration                     aI32E9u1TlCcVqyWVuQAyA   1   1          0            0       416b           208b
yellow open   cas_server__sso_log_index-2024.01            6gIZmufUTBm5J1yKRNr9Yg   1   1
yellow open   cas_server__sso_log_index-2024.02            2625MQ5yQIWbmd2Ku0JeiQ   1   1
green  open   index                                        kwwxQ3-pRyqwnQqLfcqWrQ   1   1          4            0      7.6kb          3.8kb
yellow open   cas_server__sso_log_index-2024.03            Nb_tzNv1Sd-R0i8r50NKJA   1   1
yellow open   cas_server__sso_log_index-2024.04            q8OtmI8lRaOhnJxa5ZYgHQ   1   1
yellow open   cas_server__service_access_log_index-2023.12 2JASaeftQFiDEFZ4JziB_g   1   1
yellow open   cas_server__service_access_log_index-2023.10 ZqrhMhK6QFqzykZrhjTa4Q   1   1
yellow open   cas_server__service_access_log_index-2023.11 ab2s930ZRhWQZRIhAElmbw   1   1
yellow open   authx_log__authentication_log_index-2023.09  hvTatpsMSvemJgp2QEy5_w   1   1
green  open   my_index                                     -U38qxZJSf-WiaMDB4ZuuA   1   1          5            0      8.2kb          4.1kb
yellow open   authx_log__service_access_log_index-2024.09  C_iMl-8-ToiBx6FfDHfY2Q   1   1    7888396            0      6.1gb          6.1gb
yellow open   authx_log__service_access_log_index-2024.08  140RIEeqR4S72GKxDGKXIA   1   1    5449634            0      4.2gb          4.2gb
yellow open   authx_log__service_access_log_index-2024.05  5nWndIElTaOY73nRZMMKRA   1   1
yellow open   authx_log__service_access_log_index-2024.04  AUn8Lhf5RBOkHD0dqiL9fw   1   1    5125265            0      3.8gb          3.8gb
yellow open   authx_log__service_access_log_index-2024.07  reNhQK0RSUWQAVcxuD6l7g   1   1    5346681            0      3.9gb          3.9gb
yellow open   authx_log__service_access_log_index-2024.06  7J453IVGSD6rB9sZwRX7_w   1   1
yellow open   authx_log__service_access_log_index-2023.11  ARi3C4G5QwGIKmWNaUu9uQ   1   1
yellow open   authx_log__service_access_log_index-2023.10  G6kVwV8vRr6i8vdiUMHa9A   1   1
yellow open   authx_log__service_access_log_index-2023.12  RXAkfiQMS5GtIt5deKO4jw   1   1
yellow open   authx_log__authentication_log_index-2024.01  G044N5QgQgSRnlkeHhibjA   1   1
yellow open   authx_log__authentication_log_index-2024.02  hBXrCT4-SBiHBX1hb9W-pA   1   1
yellow open   authx_log__apply_call_log_index-2024.08      GL44UlzsStm_aWR9xgOGEg   1   1
yellow open   authx_log__authentication_log_index-2024.03  SCM2PSZQSomXPxm2fRdpLg   1   1
yellow open   authx_log__authentication_log_index-2024.04  JVU9r2TwTpGvOUIekMCw8A   1   1
yellow open   authx_log__apply_call_log_index-2024.09      7UhtWfCLSVaG-P0B4zk4uA   1   1
yellow open   authx_log__authentication_log_index-2024.05  _6mmw54pRTutY8vLnvXC2w   1   1
yellow open   authx_log__authentication_log_index-2024.06  w7iFmQC5Qz-6Xz2BwaNkvw   1   1
yellow open   authx_log__apply_call_log_index-2024.03      eIIcMl-1SBKe93Ulz_Azuw   1   1     533763            0    214.1mb        214.1mb
yellow open   authx_log__authentication_log_index-2024.07  6tqp8AYsS4afJein_i4bng   1   1
yellow open   authx_log__authentication_log_index-2024.08  rSh6jw6VQlOdrMUpDtq-7A   1   1
yellow open   authx_log__authentication_log_index-2024.09  NdxUjo_8RTqIzxTh1Oj00w   1   1
yellow open   cas_server__authentication_log_index-2024.08 nXW66reORWuq-80Srew9RA   1   1
yellow open   cas_server__authentication_log_index-2024.06 2-cN8sZVRviLYA8q92YUnQ   1   1
yellow open   cas_server__authentication_log_index-2024.07 tqDRwvoySqeuGmQEyNz9WA   1   1
yellow open   authx_log__service_access_log_index-2023.09  pxMxlRF5SQWEibLE_EELPg   1   1
yellow open   cas_server__authentication_log_index-2024.04 msbaWQvwRUOvOUb8ZK5Kbw   1   1
yellow open   cas_server__authentication_log_index-2024.05 XVaD_5vSTpeOEsI4LIO44A   1   1
yellow open   cas_server__authentication_log_index-2024.02 ptAe56IWTdSg_uqNBaHAJQ   1   1
yellow open   cas_server__authentication_log_index-2024.03 LXFt4yoSSiSaF0ZRGcUSsw   1   1
yellow open   cas_server__service_access_log_index-2024.07 HXZq9wPAQQyz_GqFoda18w   1   1
yellow open   cas_server__authentication_log_index-2023.10 FAEXDaSGTs2YvWKtPnzycA   1   1
yellow open   cas_server__authentication_log_index-2023.11 0CzDAKSOR_SKoTw-vxl6LQ   1   1
yellow open   cas_server__service_access_log_index-2024.06 j6yz0-FuSWeUfL_FOKQBqw   1   1
yellow open   cas_server__service_access_log_index-2024.05 kHyZpppsQ-evouLW75fPvQ   1   1
yellow open   cas_server__service_access_log_index-2024.04 K2NoGmBRSEm_6L2XdOykYQ   1   1
yellow open   cas_server__service_access_log_index-2024.08 Yx5INoefTcSsni21IxHPDQ   1   1
yellow open   cas_server__sso_log_index-2023.11            kpV2lsbhRBS2kwO_FGeFLQ   1   1
yellow open   cas_server__sso_log_index-2023.12            R5bXEtKxRfSMT_VGJZqXVA   1   1
yellow open   cas_server__service_access_log_index-2024.03 7wD13JLAQGKYyjfrjHULag   1   1
green  open   .kibana_1                                    w2BHj4rUT0u_nyNQxmNzpQ   1   1         65          233      2.7mb          1.3mb
yellow open   cas_server__service_access_log_index-2024.02 JG2gOgAOSZeboitmIeVO4g   1   1
yellow open   cas_server__service_access_log_index-2024.01 dHEx59-sQCycyW2l4iczJw   1   1
yellow open   cas_server__sso_log_index-2023.10            iLCvGEf0SqmPKP4KPcQLxA   1   1
yellow open   cas_server__sso_log_index-2023.09            BBPO_yf2S1uQxTMlICs2Pg   1   1
green  open   .security-7                                  4GDo6BlGQ5u4finqloG3zw   1   1         42            0    149.3kb         79.3kb
yellow open   authx_log__apply_call_log_index-2023.12      8bwgmGcYRy2IbYRssuo7gw   1   1     330540            0    136.5mb        136.5mb
yellow open   cas_server__authentication_log_index-2023.09 n_9xkfF-TFGgNQblODj9LA   1   1
[elasticsearch@es01 ~]$

  ```
#还原结束后
  ```bash
[elasticsearch@es01 ~]$ curl -k -u elastic "https://222.24.203.42:9200/_cat/recovery?v&active_only=true"
Enter host password for user 'elastic':
index shard time type stage source_host source_node target_host target_node repository snapshot files files_recovered files_percent files_total bytes bytes_recovered bytes_percent bytes_total translog_ops translog_ops_recovered translog_ops_percent

[elasticsearch@es01 ~]$  curl -k -u elastic https://222.24.203.42:9200/_cat/health?v
epoch      timestamp cluster    status node.total node.data shards pri relo init unassign pending_tasks max_task_wait_time active_shards_percent
1755051217 02:13:37  nwpu-newes green           3         3    150  75    0    0        0             0                  -                100.0%

  ```

#### 4. 恢复完成后核对数据量、文档数、关键查询

#迁移结束后，如何检查比对两套ES集群的数据？

从“快到严”的比对方法清单，配好可直接执行的命令。目标只校验业务索引：`cas_server__*` 与`authx_log__*`。

##### A. 快速健康与清单核对

- 两边集群健康
  - 旧：
  
    ```bash
    curl -k -u elastic https://10.40.10.124:9200/_cluster/health?pretty
    ```
  
  - 新：
    ```bash
    curl -k -u elastic https://222.24.203.42:9200/_cluster/health?pretty
    ```
    期望 status=green，unassigned_shards=0。
  
 - logs
   ```bash
    [elasticsearch@es01 log]$ curl -k -u elastic https://10.40.10.124:9200/_cluster/health?pretty
    Enter host password for user 'elastic':
    {
    "cluster_name" : "nwpu-es",
    "status" : "green",
    "timed_out" : false,
    "number_of_nodes" : 3,
    "number_of_data_nodes" : 3,
    "active_primary_shards" : 96,
    "active_shards" : 192,
    "relocating_shards" : 0,
    "initializing_shards" : 0,
    "unassigned_shards" : 0,
    "delayed_unassigned_shards" : 0,
    "number_of_pending_tasks" : 0,
    "number_of_in_flight_fetch" : 0,
    "task_max_waiting_in_queue_millis" : 0,
    "active_shards_percent_as_number" : 100.0
    }
    [elasticsearch@es01 log]$ curl -k -u elastic https://222.24.203.42:9200/_cluster/health?pretty
    Enter host password for user 'elastic':
    {
    "cluster_name" : "nwpu-newes",
    "status" : "green",
    "timed_out" : false,
    "number_of_nodes" : 3,
    "number_of_data_nodes" : 3,
    "active_primary_shards" : 75,
    "active_shards" : 150,
    "relocating_shards" : 0,
    "initializing_shards" : 0,
    "unassigned_shards" : 0,
    "delayed_unassigned_shards" : 0,
    "number_of_pending_tasks" : 0,
    "number_of_in_flight_fetch" : 0,
    "task_max_waiting_in_queue_millis" : 0,
    "active_shards_percent_as_number" : 100.0
    }
    [elasticsearch@es01 log]$
   ```
  
- 索引是否全部到位（按名称对比）
  - 旧：
    ```bash
    curl -k -u elastic 'https://10.40.10.124:9200/_cat/indices/cas_server__*,authx_log__*?s=index&h=index' > old.idx
    ```
  - 新：
  
    ```bash
    curl -k -u elastic 'https://222.24.203.42:9200/_cat/indices/cas_server__*,authx_log__*?s=index&h=index' > new.idx
    ```
  
    ```bash
    diff -u old.idx new.idx
    ```
    期望没有差异；若有，记录缺少的索引名，然后只恢复这些索引。

##### B. 文档数与主分片存储量比对（逐索引）

- 导出对比表（docs.count、pri.store.size 更有代表性）
  - 旧：
    ```bash
    curl -k -u elastic 'https://10.40.10.124:9200/_cat/indices/cas_server__*,authx_log__*?format=json&h=index,docs.count,pri.store.size' \
    | jq -r '.[]|[.index,.["docs.count"],.["pri.store.size"]]|@tsv' | sort > old.tsv
    ```
  - 新：
    ```bash
    curl -k -u elastic 'https://222.24.203.42:9200/_cat/indices/cas_server__*,authx_log__*?format=json&h=index,docs.count,pri.store.size' \
    | jq -r '.[]|[.index,.["docs.count"],.["pri.store.size"]]|@tsv' | sort > new.tsv
    ```
    ```bash
    diff -u old.tsv new.tsv
    ```
  
- 总量快速核对（所有业务索引合计）
  - 旧：
    ```bash
    curl -k -u elastic 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_count?ignore_unavailable=true'
    ```
    
  - 新：
    ```bash
    curl -k -u elastic 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_count?ignore_unavailable=true'
    ```
    
    #logs： 
    
    ```bash
    [elasticsearch@es01 logs]$ curl -k -u elastic 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_count?ignore_unavailable=true'
    Enter host password for user 'elastic':
    {"count":258306166,"_shards":{"total":68,"successful":68,"skipped":0,"failed":0}}
    
    [elasticsearch@es01 logs]$ curl -k -u elastic 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_count?ignore_unavailable=true'
    Enter host password for user 'elastic':
    {"count":258306166,"_shards":{"total":68,"successful":68,"skipped":0,"failed":0}}
    ```
    
    说明：
  
- docs.count 需一致；pri.store.size 通常应非常接近（快照恢复是段级恢复），不同文件系统可能有少量差异，但不应相差巨大。

##### C. 映射与关键设置一致性

- 比对 mappings（规范化后取哈希）
  - 旧：
    ```bash
    curl -s -k -u elastic 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_mapping' | jq -S . | sha256sum
    ```
  - 新：
    ```bash
    curl -s -k -u elastic 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_mapping' | jq -S . | sha256sum
    ```
    #logs
    
    ```bash
    [elasticsearch@es01 logs]$ curl -s -k -u elastic 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_mapping' | jq -S . | sha256sum
    Enter host password for user 'elastic':
    1da770a97c5be787d6347a752eae6bb498130d816600134d075060fc618a6ead  -
    
    [elasticsearch@es01 logs]$ curl -s -k -u elastic 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_mapping' | jq -S . | sha256sum
    Enter host password for user 'elastic':
    1da770a97c5be787d6347a752eae6bb498130d816600134d075060fc618a6ead  -
    ```
    
    
    
    哈希应一致。
- 比对关键 index settings（分片数、ILM 名称等）
  - 旧：
    ```bash
    curl -s -k -u elastic 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_settings/index.number_of_shards,index.number_of_replicas,index.lifecycle.name' | jq -S . | sha256sum
    ```
  - 新：
    ```bash
    curl -s -k -u elastic 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_settings/index.number_of_shards,index.number_of_replicas,index.lifecycle.name' | jq -S . | sha256sum
    ```
    
    
    #logs
    
    ```bash
    [elasticsearch@es01 logs]$ curl -s -k -u elastic 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_settings/index.number_of_shards,index.number_of_replicas,index.lifecycle.name' | jq -S . | sha256sum
    Enter host password for user 'elastic':
    a21cb3c4ba73295c342cc8a52e05c5224d20bf6e5caf70ed187a13b5a6ffa665  -
    
    [elasticsearch@es01 logs]$ curl -s -k -u elastic 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_settings/index.number_of_shards,index.number_of_replicas,index.lifecycle.name' | jq -S . | sha256sum
    Enter host password for user 'elastic':
    a21cb3c4ba73295c342cc8a52e05c5224d20bf6e5caf70ed187a13b5a6ffa665  -
    
    ```
    
    
    
    说明：
- number_of_shards 必须一致；replicas 可按新集群目标调整（不影响数据一致性）。
- 如看到 index.lifecycle.name 存在但新集群没有对应 ILM 策略，写入时会报 ILM 相关告警（不影响只读校验）。可选择导入旧策略或移除该设置。

##### D. 别名比对（如业务使用别名）

- 旧：
  ```bash
  curl -s -k -u elastic 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_alias?pretty'
  ```
- 新：
  ```bash
  curl -s -k -u elastic 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_alias?pretty'
  ```
  比对别名是否全部存在并指向相同索引。

##### E. 聚合级核对（时间分布是否一致）
按月/日统计量快速抽查（将 @timestamp 改为你实际时间字段）：

- 旧：
  ```bash
  curl -k -u elastic -X POST 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_search?size=0' -H 'Content-Type: application/json' -d '{
    "aggs":{"by_month":{"date_histogram":{"field":"@timestamp","calendar_interval":"1M"}}}
  }'
  ```
- 新：
  ```bash
  curl -k -u elastic -X POST 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_search?size=0' -H 'Content-Type: application/json' -d '{
    "aggs":{"by_month":{"date_histogram":{"field":"@timestamp","calendar_interval":"1M"}}}
  }'
  ```
  #logs
  
  ```bash
  
  [elasticsearch@es01 logs]$ curl -k -u elastic -X POST 'https://10.40.10.124:9200/cas_server__*,authx_log__*/_search?size=0' -H 'Content-Type: application/json' -d '{
  >   "aggs":{"by_month":{"date_histogram":{"field":"@timestamp","calendar_interval":"1M"}}}
  > }'
  Enter host password for user 'elastic':
  {"took":8854,"timed_out":false,"_shards":{"total":68,"successful":68,"skipped":0,"failed":0},"hits":{"total":{"value":10000,"relation":"gte"},"max_score":null,"hits":[]},"aggregations":{"by_month":{"buckets":[{"key_as_string":"2023-09-01T00:00:00.000Z","key":1693526400000,"doc_count":56191},{"key_as_string":"2023-10-01T00:00:00.000Z","key":1696118400000,"doc_count":14020438},{"key_as_string":"2023-11-01T00:00:00.000Z","key":1698796800000,"doc_count":12822661},{"key_as_string":"2023-12-01T00:00:00.000Z","key":1701388800000,"doc_count":15905642},{"key_as_string":"2024-01-01T00:00:00.000Z","key":1704067200000,"doc_count":14242139},{"key_as_string":"2024-02-01T00:00:00.000Z","key":1706745600000,"doc_count":8943619},{"key_as_string":"2024-03-01T00:00:00.000Z","key":1709251200000,"doc_count":15426623},{"key_as_string":"2024-04-01T00:00:00.000Z","key":1711929600000,"doc_count":13430703},{"key_as_string":"2024-05-01T00:00:00.000Z","key":1714521600000,"doc_count":13326562},{"key_as_string":"2024-06-01T00:00:00.000Z","key":1717200000000,"doc_count":16101845},{"key_as_string":"2024-07-01T00:00:00.000Z","key":1719792000000,"doc_count":13552475},{"key_as_string":"2024-08-01T00:00:00.000Z","key":1722470400000,"doc_count":74393450},{"key_as_string":"2024-09-01T00:00:00.000Z","key":1725148800000,"doc_count":42576140},{"key_as_string":"2024-10-01T00:00:00.000Z","key":1727740800000,"doc_count":3507678}]}}}
  
  [elasticsearch@es01 logs]$ curl -k -u elastic -X POST 'https://222.24.203.42:9200/cas_server__*,authx_log__*/_search?size=0' -H 'Content-Type: application/json' -d '{
  >   "aggs":{"by_month":{"date_histogram":{"field":"@timestamp","calendar_interval":"1M"}}}
  > }'
  Enter host password for user 'elastic':
  {"took":4845,"timed_out":false,"_shards":{"total":68,"successful":68,"skipped":0,"failed":0},"hits":{"total":{"value":10000,"relation":"gte"},"max_score":null,"hits":[]},"aggregations":{"by_month":{"buckets":[{"key_as_string":"2023-09-01T00:00:00.000Z","key":1693526400000,"doc_count":56191},{"key_as_string":"2023-10-01T00:00:00.000Z","key":1696118400000,"doc_count":14020438},{"key_as_string":"2023-11-01T00:00:00.000Z","key":1698796800000,"doc_count":12822661},{"key_as_string":"2023-12-01T00:00:00.000Z","key":1701388800000,"doc_count":15905642},{"key_as_string":"2024-01-01T00:00:00.000Z","key":1704067200000,"doc_count":14242139},{"key_as_string":"2024-02-01T00:00:00.000Z","key":1706745600000,"doc_count":8943619},{"key_as_string":"2024-03-01T00:00:00.000Z","key":1709251200000,"doc_count":15426623},{"key_as_string":"2024-04-01T00:00:00.000Z","key":1711929600000,"doc_count":13430703},{"key_as_string":"2024-05-01T00:00:00.000Z","key":1714521600000,"doc_count":13326562},{"key_as_string":"2024-06-01T00:00:00.000Z","key":1717200000000,"doc_count":16101845},{"key_as_string":"2024-07-01T00:00:00.000Z","key":1719792000000,"doc_count":13552475},{"key_as_string":"2024-08-01T00:00:00.000Z","key":1722470400000,"doc_count":74393450},{"key_as_string":"2024-09-01T00:00:00.000Z","key":1725148800000,"doc_count":42576140},{"key_as_string":"2024-10-01T00:00:00.000Z","key":1727740800000,"doc_count":3507678}]}}}
  
  ```
  
  
  
  各桶的 doc_count 应一致。也可针对关键业务过滤条件做同样聚合对比。

##### F. 样本文档逐条核对（抽样）
以每个索引取头部/尾部各100条 _id，对照两边是否存在且_source一致：

- 取样本 ID（旧）：
  ```bash
  curl -s -k -u elastic 'https://10.40.10.124:9200/cas_server__*/_search?size=100&sort=_id:asc&_source=false&filter_path=hits.hits._id'
  
  curl -s -k -u elastic 'https://10.40.10.124:9200/cas_server__*/_search?size=100&sort=_id:desc&_source=false&filter_path=hits.hits._id'
  ```
- 用 mget 在两边取相同 ID 比较 _source（可用 jq -S 规范化后比对哈希）。
也可写个小脚本随机选取 N 个 ID 做对比。

G. 一键脚本范例（Linux，需 jq、diff）
- 生成对比表并标出差异索引
  ```bash
  OLD=https://10.40.10.124:9200
  NEW=https://222.24.203.42:9200
  OLDAUTH="-k -u elastic:$OLD_PASS"
  NEWAUTH="-k -u elastic:$NEW_PASS"
  PATS='cas_server__*,authx_log__*'
  curl $OLDAUTH "$OLD/_cat/indices/$PATS?format=json&h=index,docs.count,pri.store.size" | jq -r '.[]|[.index,.["docs.count"],.["pri.store.size"]]|@tsv' | sort > /tmp/old.tsv
  curl $NEWAUTH "$NEW/_cat/indices/$PATS?format=json&h=index,docs.count,pri.store.size" | jq -r '.[]|[.index,.["docs.count"],.["pri.store.size"]]|@tsv' | sort > /tmp/new.tsv
  echo "Index/doc/size diff:"
  diff -u /tmp/old.tsv /tmp/new.tsv || true
  
  echo "Mappings hash:"
  curl -s $OLDAUTH "$OLD/$PATS/_mapping" | jq -S . | sha256sum
  curl -s $NEWAUTH "$NEW/$PATS/_mapping" | jq -S . | sha256sum
  
  echo "Total count:"
  curl $OLDAUTH "$OLD/$PATS/_count?ignore_unavailable=true"
  curl $NEWAUTH "$NEW/$PATS/_count?ignore_unavailable=true"
  ```
  判读与常见偏差说明
- docs.count 不一致：先确认是否在快照之后旧集群仍有写入；或新集群是否有写入/删除。如有，需在停写后做“最终快照并重恢”。
- pri.store.size 差异较大：检查是否有未分配主分片、索引是否 force merge 过、是否有压缩/编解码差异；通常应该很接近。
- 映射哈希不同：恢复不完整或恢复后被模板/应用改写。核对具体差异字段并修正。
- 别名不同：恢复时若使用 include_global_state=false，别名仍会随索引一起恢复；如不一致，按旧集群别名重新设置。
- ILM 警告：如果索引 settings 中带 index.lifecycle.name，但新集群未导入该策略，会出现 ILM 相关告警；不影响只读比对。需要写入时，导入策略或移除该设置。

按以上步骤逐项通过后，可认为两套集群在“业务索引层面”已一致。

#### 5. 索引模板的导出、导入及比对

#7.7 用的是“传统索引模板（legacy index templates）”，接口是 _template。

##### 5.1. 索引模板是什么

- 用途：当创建新索引且名称匹配模板的 index_patterns 时，自动把模板里定义的 settings、mappings、aliases 应用到该索引，确保分片数、副本数、字段类型、分析器、别名等一致。
- 组成关键点：
  - index_patterns：匹配哪些索引名（如 `cas_server__*`、`authx_log__*`）。
  - settings：如 number_of_shards、number_of_replicas、分析器配置、默认 pipeline 等。
  - mappings：字段类型、dynamic_templates 等。
  - aliases：要自动创建的别名。
  - order：同一索引命中多个模板时，按 order 从小到大合并，后者覆盖前者。
- 作用范围：仅“创建新索引”时生效；已存在的索引不会被模板改变。

##### 5.2. 导出（旧集群）

1) 导出全部模板（含系统模板）
```bash
curl -k -u elastic "https://10.40.10.124:9200/_template?pretty" > all.templates.old.json
```

2) 仅导出“业务相关模板”
- 过滤掉系统模板（模板名以点开头）：
```bash
curl -s -k -u elastic "https://10.40.10.124:9200/_template" \
| jq 'to_entries | map(select(.key|startswith(".")|not)) | from_entries' \
> custom.templates.old.json
```
#logs

#仅看到logstash索引模板

```bash
[elasticsearch@es01 logs]$ more custom.templates.old.json

#或者直接查询
[elasticsearch@es01 logs]$ curl -k -u elastic https://10.40.10.124:9200/_template/logstash?pretty
Enter host password for user 'elastic':

{
  "logstash": {
    "order": 0,
    "version": 60001,
    "index_patterns": [
      "logstash-*"
    ],
    "settings": {
      "index": {
        "number_of_shards": "1",
        "refresh_interval": "5s"
      }
    },
    "mappings": {
      "dynamic_templates": [
        {
          "message_field": {
            "path_match": "message",
            "mapping": {
              "norms": false,
              "type": "text"
            },
            "match_mapping_type": "string"
          }
        },
        {
          "string_fields": {
            "mapping": {
              "norms": false,
              "type": "text",
              "fields": {
                "keyword": {
                  "ignore_above": 256,
                  "type": "keyword"
                }
              }
            },
            "match_mapping_type": "string",
            "match": "*"
          }
        }
      ],
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "geoip": {
          "dynamic": true,
          "properties": {
            "ip": {
              "type": "ip"
            },
            "latitude": {
              "type": "half_float"
            },
            "location": {
              "type": "geo_point"
            },
            "longitude": {
              "type": "half_float"
            }
          }
        },
        "@version": {
          "type": "keyword"
        }
      }
    },
    "aliases": {}
  }
}

#这个名为 logstash 的模板不是 ES 或 MySQL 自动生成的，也不是手动在 ES 里创建的默认系统模板。它是由 Logstash 的 elasticsearch 输出插件自动安装的“默认模板”（当 manage_template=true，且索引名形如 logstash-* 时，Logstash 会在首次写入前 PUT 这个模板到 ES）。

#如果曾经用 Logstash 的 jdbc 插件从 MySQL 同步数据到 ES，并且输出索引叫 logstash-YYYY.MM.DD 之类，那么就是这条 Logstash pipeline 自动装的模板。

#迁移时该模板要不要带
#业务索引前缀是 cas_server__* 和 authx_log__，与 logstash- 无关，所以这个模板对业务索引不起作用，可以不导入。
#如果新集群未来还会用 Logstash 写 logstash-* 索引，Logstash 会在首次写入时再次自动安装该模板；或者你可在 Logstash 中自定义模板。
```

- 若只想要“匹配业务前缀”的模板（推荐，尽量精确）
```bash
curl -s -k -u elastic "https://10.40.10.124:9200/_template" \
| jq 'to_entries
| map(select(any(.value.index_patterns[]?; startswith("cas_server__") or startswith("authx_log__"))))
| from_entries' \
> biz.templates.old.json
```

说明：
- 你们的业务索引前缀为 cas_server__* 与 authx_log__*，这样导出仅包含与之相关的模板。
- jq 为命令行 JSON 工具，Linux 上可 yum/apt 安装。

##### 5.3. 导入（新集群）
- 确保新集群已安装业务需要的插件（如 IK）与旧集群一致，否则 mappings/分析器引用会报错。
- 如果模板里引用了 ILM 策略名（index.lifecycle.name）或默认 pipeline（index.default_pipeline），请先导入 ILM 与 pipelines（见后文第四节）。

1) 把业务模板导入新集群（覆盖式导入）
```bash
for n in $(jq -r 'keys[]' biz.templates.old.json); do
    body=$(jq -r --arg k "$n" '.[$k]' biz.templates.old.json)
    echo "PUT _template/$n"
    curl -k -u elastic -X PUT "https://222.24.203.42:9200/_template/$n" \
       -H "Content-Type: application/json" -d "$body"
    echo
done
```

提示：
- 以上是“幂等覆盖式”导入。如果你想防止意外覆盖已有同名模板，可用 create 模式（需要不存在才创建）：
  curl ... "_template/$n?create=true"
- order 字段会随 body 一同导入，确保合并顺序一致。

##### 5.4. ILM 策略与 ingest pipelines 的导出/导入（若模板中引用）
1) ILM 策略
- 导出旧集群全部策略：
```bash
curl -k -u elastic "https://10.40.10.124:9200/_ilm/policy?pretty" > ilm.old.json
- 导入新集群：
for p in $(jq -r 'keys[]' ilm.old.json); do
  body=$(jq -r --arg k "$p" '.[$k]' ilm.old.json)
  curl -k -u elastic -X PUT "https://222.24.203.42:9200/_ilm/policy/$p" \
       -H "Content-Type: application/json" -d "$body"
done
```

2) ingest pipelines
- 导出旧集群全部 pipeline：
```bash
curl -k -u elastic "https://10.40.10.124:9200/_ingest/pipeline?pretty" > pipelines.old.json
- 导入新集群：
for p in $(jq -r 'keys[]' pipelines.old.json); do
  body=$(jq -r --arg k "$p" '.[$k]' pipelines.old.json)
  curl -k -u elastic -X PUT "https://222.24.203.42:9200/_ingest/pipeline/$p" \
       -H "Content-Type: application/json" -d "$body"
done
```

##### 5.5. 比对（旧/新模板是否一致）
1) 导出新集群同样范围的模板
```bash
curl -s -k -u elastic "https://222.24.203.42:9200/_template" \ 
| jq 'to_entries
| map(select(any(.value.index_patterns[]?; startswith("cas_server__") or startswith("authx_log__"))))
| from_entries' \ 
> biz.templates.new.json
```
2) 规范化并比较
- 名称清单比对：
  ```bas
  jq -r 'keys[]' biz.templates.old.json | sort > /tmp/old.names
  jq -r 'keys[]' biz.templates.new.json | sort > /tmp/new.names
  
  diff -u /tmp/old.names /tmp/new.names || true
  ```

- 内容比对（规范化排序后做文本 diff 与哈希）：
  ```bash
  jq -S . biz.templates.old.json > /tmp/old.sorted.json
  jq -S . biz.templates.new.json > /tmp/new.sorted.json
  diff -u /tmp/old.sorted.json /tmp/new.sorted.json || true
  sha256sum /tmp/old.sorted.json /tmp/new.sorted.json
  ```

3) ILM 与 pipelines 的比对（如有导入）
- ILM：
  ```bash
  curl -s -k -u elastic "https://10.40.10.124:9200/_ilm/policy" | jq -S . > /tmp/ilm.old.json
  curl -s -k -u elastic "https://222.24.203.42:9200/_ilm/policy" | jq -S . > /tmp/ilm.new.json
  diff -u /tmp/ilm.old.json /tmp/ilm.new.json || true
  ```
- Pipelines：
  ```bash
  curl -s -k -u elastic "https://10.40.10.124:9200/_ingest/pipeline" | jq -S . > /tmp/pipe.old.json
  curl -s -k -u elastic "https://222.24.203.42:9200/_ingest/pipeline" | jq -S . > /tmp/pipe.new.json
  diff -u /tmp/pipe.old.json /tmp/pipe.new.json || true
  ```

##### 5.6. 导入后如何验证模板生效
- 模板只对“新建索引”有效。可在新集群临时创建一个测试索引验证，完成后删除。
- 示例：验证 cas_server__ 前缀会套用到的 settings/mappings
  ```bash
  url -k -u elastic -X PUT "https://222.24.203.42:9200/cas_server__verify-0001"
  curl -k -u elastic "https://222.24.203.42:9200/cas_server__verify-0001/_settings?pretty"
  curl -k -u elastic "https://222.24.203.42:9200/cas_server__verify-0001/_mapping?pretty"
  curl -k -u elastic -X DELETE "https://222.24.203.42:9200/cas_server__verify-0001"
  ```
- 若需确认别名是否自动创建，检查 _alias。


##### 5.7. 实务建议与注意
- 模板优先级：确保 order 与 index_patterns 与旧集群一致；多个模板命中时，order 大的覆盖前面的设置。
- 兼容性：模板中若设置 index.lifecycle.name 或 index.default_pipeline，请先把对应的 ILM 和 pipeline 导入，否则创建索引时会报错或告警。
- 插件：模板里若引用自定义分析器（如 IK），新集群插件必须已安装。
- 已恢复的历史索引不受模板影响；模板主要是保障后续“新写入/新月份滚动索引”的一致性。

#### 6.新建可读写快照仓库
##### 6.1.nfs服务器或者nfs存储

```bash
yum install -y nfs*

mkdir /newes

chmod -R 777 /newes

cat >> /etc/exports <<EOF
/newes 222.24.203.0/24(rw,sync,insecure,no_subtree_check,no_root_squash)

EOF


systemctl restart nfs

systemctl enable nfs

showmount -e
```



#all_squash 表示客户机写入nfs的数据全部映射为nobody用户 这里设置 all_squash并把目录设置为777 是为防止elasticsearch 集群的每个节点启动的uid和gid 不一致导致在创建快照仓库时无法创建成功

#uid/gid不同时，快照存储库验证失败

##### 6.2.每台es节点创建备份目录，并mount共享目录

```bash
su - root

mkdir /newessnp

yum install -y nfs-utils

#mount -t nfs 10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS/Ecampus_NAS/es-snp /snp
mount -t nfs 10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS_share/Ecampus_tmp /newessnp

chmod -R 777 /newessnp

cat >> /etc/fstab <<EOF
10.40.2.72:/CM_VFS1/CM_VFS1/Ecampus_NAS_share/Ecampus_tmp /newessnp      nfs  defaults,_netdev  0 0
EOF
```

##### 6.3.修改es节点的elasticsearch.yml

```bash
su - elasticsearch

cat >> /opt/elasticsearch/config/elasticsearch.yml <<EOF
#path.repo: ["/snp"]
path.repo: ["/snp","/newessnp"]
EOF

su - root
systemctl restart elasticsearch
```

##### 6.4.注册存储库
###### 6.4.1.通过kibana注册存储库

```yaml
Management ---> Stack Management ---> Snapshot and Restore
```

###### 6.4.2.通过命令注册存储库

```bash
#
PUT _snapshot/newes_snp
{
  "type": "fs",
  "settings": {
    "location": "/newessnp",
  }
}

#或者

curl -XPUT -k -u elastic https:222.24.203.42:9200/_snapshot/newes_snp -d 
'{
  "type": "fs",
  "settings": {
    "location": "/newessnp"
  }
}'

#注册后建议立即验证仓库可用性
curl -X POST -k -u elastic 'https://222.24.203.42:9200:9200/_snapshot/newes_snp/_verify'

POST /_snapshot/newes_snp/_verify
{
  "nodes" : {
    "s3cH7VN6RkqEkCNlo9C4bQ" : {
      "name" : "node-3"
    },
    "iNNFAI8vQc6EbszuTWIBAg" : {
      "name" : "node-1"
    },
    "avGPTYI_Qce5ykmbvKZpyA" : {
      "name" : "node-2"
    }
  }
}


#查看存储库
#GET /_snapshot/newes_snp

curl -XGET 222.24.203.42:9200/_snapshot/newes_snp

/*
{
  "es-nfs": {
    "type": "fs",
    "settings": {
      "location": "/newessnp"
    }
  }
}
*/




#GET _snapshot/newes_snp/_all

#GET /_cat/snapshots/newes_snp?v

#单个快照库时查询
curl -XGET -k -u elastic https://222.24.203.42:9200/_cat/snapshots?v

#多个快照库时查询，必须指定快照库的名字
#目前 ES 不支持一次性查询所有仓库的快照列表，只能分别查询每个仓库
GET /_cat/snapshots/newes_snp?v
curl -XGET -k -u elastic https://222.24.203.42:9200/_cat/snapshots/newes_snp?v

#
id                 status start_epoch start_time end_epoch  end_time duration indices successful_shards failed_shards total_shards
snapshot_20240814 SUCCESS 1755155369  07:09:29   1755155369 07:09:29    200ms       1                 1             0            1


curl -XGET -k -u elastic https://222.24.203.44:9200/_snapshot/newes_snp/snapshot_20240814/_status

#如果忘记仓库名，可以先查仓库列表
curl -XGET -k -u elastic "https://222.24.203.42:9200/_cat/repositories?v"
# /_cat/repositories?v
id          type
es_snp      fs
newes_snp   fs


#仓库属性，比如只读等
GET _snapshot/es_snp
GET _snapshot/newes_snp

# GET _snapshot/es_snp
{
  "es_snp" : {
    "type" : "fs",
    "settings" : {
      "readonly" : "true",
      "location" : "/snp"
    }
  }
}

# GET _snapshot/newes_snp
{
  "newes_snp" : {
    "type" : "fs",
    "settings" : {
      "location" : "/newessnp"
    }
  }
}



#curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/es_snp?verify=false" -X PUT -H "Content-Type: application/json" -d '{"type":"fs","settings":{"location":"/snp","compress":true,"readonly":true}}'

#curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/es_snp" -X PUT -H "Content-Type: application/json" -d '{"type":"fs","settings":{"location":"/snp","compress":true}}'
```

##### 6.5.快照
###### 6.5.1.通过kibana打快照

#配置完策略后，可以点击立即执行，会立即生成一份快照

```
Management ---> Stack Management ---> Snapshot and Restore ---> 策略

策略名称: daily-snap
快照名称: <daily-snap-{now/d}>
存储库: newes_snp
计划: 0 30 1 * * ?

快照保留: 5days

---> 所有数据流和索引
---> 单个索引等
```

```bash
创建与 Kibana 相同的 SLM 策略

- 策略名：daily-snap
- 调度：0 30 17 * * ?（每天 01:30）
- 快照名模板：<daily-snap-{now/d}>
- 仓库：newes_snp
- 索引：所有索引
- 忽略不可用索引：是
- 允许部分快照：是
- 包含全局状态：是
- 保留期限：5d
```



###### 6.5.2.通过命令打快照

```bash
# 创建单次快照
PUT /_snapshot/newes_snp/daily-snap-2024.05.11-16-43?wait_for_completion=true 
{
  "indices": "kibana_sample_data_ecommerce,kibana_sample_data_flights",
  "ignore_unavailable": true,
  "include_global_state": false,
  "metadata": {
    "taken_by": "supwisdom",
    "taken_because": "backup before upgrading"
  }
}
# 查看快照
GET /_snapshot/newes_snp/daily-snap-2024.05.11-16-43

#创建每日快照
curl -u elastic:$ESPASSWD -H 'Content-Type: application/json' -X PUT -k  "https://222.24.203.42:9200/_slm/policy/daily-snap" -d '{
  "schedule": "0 30 17 * * ?",
  "name": "<daily-snap-{now/d}>",
  "repository": "newes_snp",
  "config": {
    "indices": ["*"],
    "ignore_unavailable": true,
    "include_global_state": true,
    "partial": true
  },
  "retention": {
    "expire_after": "5d"
  }
}'


#立即执行一次此策略 
curl -X POST -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap/_execute"
#查看策略 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"
#查看 SLM 状态 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/status?pretty"
#立刻执行一次保留清理（删除超过 5d 的快照） 
curl -X POST -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/_execute_retention"


#查看进行中的快照进度
#查所有正在进行的快照 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/_status?pretty"
#只看指定仓库 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/newes_snp/_status?pretty"
#已知快照名时（进度最详细） 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/newes_snp/<SNAPSHOT_NAME>/_status?pretty"

#以上返回中的关键字段：
snapshots[0].state: IN_PROGRESS / SUCCESS / FAILED
snapshots[0].shards_stats: initializing/started/finalizing/done/failed/total
snapshots[0].stats.time_in_millis、size_in_bytes

#快速看状态列表
#列出仓库里快照及状态（IN_PROGRESS/SUCCESS/FAILED） 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_cat/snapshots/newes_snp?v&s=start_epoch:desc"

#通过任务查看（可选，看到创建快照的任务） 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_tasks?detailed=true&actions=cluster:admin/snapshot/*&pretty"

#查看策略的最近一次成功/失败时间 
curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"


#查询 SLM 历史（最近10条） 
#查询字段
curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_mapping?pretty&filter_path=**.properties"

#根据上面查询出的字段名称，来查询最近的十条---@timestamp
curl -H 'Content-Type: application/json' -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_search?pretty" -d '{"size":10,"sort":[{"@timestamp":"desc"}]}'

#（按快照名显示完成分片数/总数） SN=<执行策略后返回的snapshot_name> 
#daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw
export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
watch -n 5 "curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw/_status' | jq -r '.snapshots[0] | \"state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)\"'"

export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
while true; do
  curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/'"$SN"'/_status' \
  | jq -r '.snapshots[0] | "state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)"'
  sleep 5
done
```

```log
常规
版本
2
最后修改时间
2025年8月15日 GMT+8 09:50
快照名称
<daily-snap-{now/d}>
存储库
newes_snp
计划
0 30 17 * * ?
下一快照
2025年8月16日 GMT+8 01:30
索引
所有索引
忽略不可用索引
是
允许部分分片
是
包括全局状态
是
```

```bash
[elasticsearch@es03 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_cat/snapshots/newes_snp?v&s=start_epoch:desc"
id                                                status start_epoch start_time end_epoch  end_time duration indices successful_shards failed_shards total_shards
daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw IN_PROGRESS 1755222710  01:51:50   0          00:00:00    11.6m      75                 0             0            0
snapshot_20240814                                SUCCESS 1755155369  07:09:29   1755155369 07:09:29    200ms       1                 1             0            1


[elasticsearch@es03 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_tasks?detailed=true&actions=cluster:admin/snapshot/*&pretty"
{
  "nodes" : {
    "s3cH7VN6RkqEkCNlo9C4bQ" : {
      "name" : "node-3",
      "transport_address" : "222.24.203.44:9300",
      "host" : "222.24.203.44",
      "ip" : "222.24.203.44:9300",
      "roles" : [
        "ingest",
        "master",
        "transform",
        "data",
        "remote_cluster_client",
        "ml"
      ],
      "attributes" : {
        "ml.machine_memory" : "32322408448",
        "ml.max_open_jobs" : "20",
        "xpack.installed" : "true",
        "transform.node" : "true"
      },
      "tasks" : {
        "s3cH7VN6RkqEkCNlo9C4bQ:567925" : {
          "node" : "s3cH7VN6RkqEkCNlo9C4bQ",
          "id" : 567925,
          "type" : "transport",
          "action" : "cluster:admin/snapshot/create",
          "description" : "snapshot [newes_snp:daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw]",
          "start_time_in_millis" : 1755222710484,
          "running_time_in_nanos" : 833072763081,
          "cancellable" : false,
          "headers" : { }
        }
      }
    }
  }
}

#打快照中
[devel@docker-01 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"
{
  "daily-snap" : {
    "version" : 2,
    "modified_date_millis" : 1755222630730,
    "policy" : {
      "name" : "<daily-snap-{now/d}>",
      "schedule" : "0 30 17 * * ?",
      "repository" : "newes_snp",
      "config" : {
        "ignore_unavailable" : true,
        "partial" : true
      },
      "retention" : {
        "expire_after" : "5d"
      }
    },
    "next_execution_millis" : 1755279000000,
    "in_progress" : {
      "name" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
      "uuid" : "ZrS8LwCSQsG8dexSBWgQ9w",
      "state" : "STARTED",
      "start_time_millis" : 1755222710474
    },
    "stats" : {
      "policy" : "daily-snap",
      "snapshots_taken" : 0,
      "snapshots_failed" : 0,
      "snapshots_deleted" : 0,
      "snapshot_deletion_failures" : 0
    }
  }
}

#快照完毕
[elasticsearch@es03 ~]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_slm/policy/daily-snap?pretty"
{
  "daily-snap" : {
    "version" : 2,
    "modified_date_millis" : 1755222630730,
    "policy" : {
      "name" : "<daily-snap-{now/d}>",
      "schedule" : "0 30 17 * * ?",
      "repository" : "newes_snp",
      "config" : {
        "ignore_unavailable" : true,
        "partial" : true
      },
      "retention" : {
        "expire_after" : "5d"
      }
    },
    "last_success" : {
      "snapshot_name" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
      "time" : 1755224920313
    },
    "next_execution_millis" : 1755279000000,
    "stats" : {
      "policy" : "daily-snap",
      "snapshots_taken" : 1,
      "snapshots_failed" : 0,
      "snapshots_deleted" : 0,
      "snapshot_deletion_failures" : 0
    }
  }
}



[elasticsearch@es03 indices]$ curl -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/_status?pretty"
{
  "snapshots" : [
    {
      "snapshot" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
      "repository" : "newes_snp",
      "uuid" : "ZrS8LwCSQsG8dexSBWgQ9w",
      "state" : "STARTED",
      "include_global_state" : true,
      "shards_stats" : {
        "initializing" : 0,
        "started" : 61,
        "finalizing" : 0,
        "done" : 14,
        "failed" : 0,
        "total" : 75
      },
      "stats" : {
        "incremental" : {
          "file_count" : 8108,
          "size_in_bytes" : 145754282608
        },
        "processed" : {
          "file_count" : 1087,
          "size_in_bytes" : 24843215555
        },
        "total" : {
          "file_count" : 8108,
          "size_in_bytes" : 145754282608
        },
        "start_time_in_millis" : 1755222710474,
        "time_in_millis" : 299524
      },
      "indices" : {
        "authx_log__service_access_log_index-2024.01" : {
          "shards_stats" : {
            "initializing" : 0,
            "started" : 0,
            "finalizing" : 0,
            "done" : 1,
            "failed" : 0,
            "total" : 1
          },
          "stats" : {
            "incremental" : {
              "file_count" : 61,
              "size_in_bytes" : 4264903144
            },
            "processed" : {
              "file_count" : 44,
              "size_in_bytes" : 4264895242
            },
            "total" : {
              "file_count" : 61,
              "size_in_bytes" : 4264903144
            },
            "start_time_in_millis" : 1755222710474,
            "time_in_millis" : 238699
          },
          "shards" : {
            "0" : {
              "stage" : "DONE",
              "stats" : {
                "incremental" : {
                  "file_count" : 61,
                  "size_in_bytes" : 4264903144
                },
                "processed" : {
                  "file_count" : 44,
                  "size_in_bytes" : 4264895242
                },
                "total" : {
                  "file_count" : 61,
                  "size_in_bytes" : 4264903144
                },
                "start_time_in_millis" : 1755222710474,
                "time_in_millis" : 238699
              }
            }
          }
        },
        "authx_log__service_access_log_index-2024.03" : {
          "shards_stats" : {
            "initializing" : 0,
            "started" : 1,
            "finalizing" : 0,
            "done" : 0,
            "failed" : 0,
            "total" : 1
          },
          "stats" : {
            "incremental" : {
              "file_count" : 79,
              "size_in_bytes" : 4449175058
            },
            "processed" : {
              "file_count" : 0,
              "size_in_bytes" : 0
            },
            "total" : {
              "file_count" : 79,
              "size_in_bytes" : 4449175058
            },
            "start_time_in_millis" : 1755222710674,
            "time_in_millis" : 0
          },
          "shards" : {
            "0" : {
              "stage" : "STARTED",
              "stats" : {
                "incremental" : {
                  "file_count" : 79,
                  "size_in_bytes" : 4449175058
                },
                "processed" : {
                  "file_count" : 0,
                  "size_in_bytes" : 0
                },
                "total" : {
                  "file_count" : 79,
                  "size_in_bytes" : 4449175058
                },
                "start_time_in_millis" : 1755222710674,
                "time_in_millis" : 0
              },
              "node" : "s3cH7VN6RkqEkCNlo9C4bQ"
            }
          }
        },
  
#快照进度
export SN='daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw'   
watch -n 5 "curl -s -k -u elastic:$ESPASSWD 'https://222.24.203.42:9200/_snapshot/newes_snp/daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw/_status' | jq -r '.snapshots[0] | \"state=\(.state) done=\(.shards_stats.done)/\(.shards_stats.total)\"'"

Every 5.0s: curl -s -k -u elastic:XIlreSzGM51dH44yuxo1 'https://222.24.203.42:9200/_snapshot/newes_snp/daily-snap...  docker-01: Fri Aug 15 10:27:37 2025

state=STARTED done=72/75
......
state=SUCCESS done=75/75


#快照历史记录
#查询字段
[elasticsearch@es03 ~]$  curl -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_mapping?pretty&filter_path=**.properties"
{
  ".slm-history-2-000001" : {
    "mappings" : {
      "properties" : {
        "@timestamp" : {
          "type" : "date",
          "format" : "epoch_millis"
        },
        "configuration" : {
          "dynamic" : "false",
          "properties" : {
            "include_global_state" : {
              "type" : "boolean"
            },
            "indices" : {
              "type" : "keyword"
            },
            "partial" : {
              "type" : "boolean"
            }
          }
        },
        "error_details" : {
          "type" : "text",
          "index" : false
        },
        "operation" : {
          "type" : "keyword"
        },
        "policy" : {
          "type" : "keyword"
        },
        "repository" : {
          "type" : "keyword"
        },
        "snapshot_name" : {
          "type" : "keyword"
        },
        "success" : {
          "type" : "boolean"
        }
      }
    }
  }
}

[elasticsearch@es03 ~]$ curl -H 'Content-Type: application/json' -X GET -k -u elastic:$ESPASSWD "https://222.24.203.42:9200/.slm-history-*/_search?pretty" -d '{"size":10,"sort":[{"@timestamp":"desc"}]}'
{
  "took" : 1,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 1,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [
      {
        "_index" : ".slm-history-2-000001",
        "_type" : "_doc",
        "_id" : "UvCOq5gBbVBmE7QY0cWV",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755224920313,
          "policy" : "daily-snap",
          "repository" : "newes_snp",
          "snapshot_name" : "daily-snap-2025.08.15-cnkywxe1sycafrf_vtjouw",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755224920313
        ]
      }
    ]
  }
}

#其它多条记录的
GET /.slm-history-*/_search?pretty
{"size":6,"sort":[{"@timestamp":"desc"}]}

{
  "took" : 51,
  "timed_out" : false,
  "_shards" : {
    "total" : 4,
    "successful" : 4,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 188,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "y5pZq5gBhgCqahXjJMgo",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755221402664,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.09-vr1mvm1itcqafltjyivlna",
          "operation" : "DELETE",
          "success" : true,
          "configuration" : null,
          "error_details" : null
        },
        "sort" : [
          1755221402664
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "1ZahqZgBhgCqahXj5kd2",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755192616566,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.14-qwh4_zdxracjojhi2f2ymq",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755192616566
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "wo0yppgBhgCqahXjxj40",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755135002163,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.08-ahqjsvhatagf7cgczakvhq",
          "operation" : "DELETE",
          "success" : true,
          "configuration" : null,
          "error_details" : null
        },
        "sort" : [
          1755135002163
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "uYh7pJgBhgCqahXjjLbC",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755106217154,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.13-hqqw5k6usrifnkflhhp0ig",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755106217154
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "3H8MoZgBhgCqahXjj6qO",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755048611725,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.07-v8mf6pb6ragvxy5kgcpg-q",
          "operation" : "DELETE",
          "success" : true,
          "configuration" : null,
          "error_details" : null
        },
        "sort" : [
          1755048611725
        ]
      },
      {
        "_index" : ".slm-history-2-000014",
        "_type" : "_doc",
        "_id" : "kntVn5gBhgCqahXjHRt9",
        "_score" : null,
        "_source" : {
          "@timestamp" : 1755019812221,
          "policy" : "daily-snap",
          "repository" : "es_snp",
          "snapshot_name" : "daily-snap-2025.08.12-voemyurrtdwtdiwvltg7kg",
          "operation" : "CREATE",
          "success" : true,
          "configuration" : {
            "ignore_unavailable" : true,
            "partial" : true
          },
          "error_details" : null
        },
        "sort" : [
          1755019812221
        ]
      }
    ]
  }
}
```





##### 6.6.还原

###### 6.6.1.通过kibana还原快照

```
Management ---> Stack Management ---> Snapshot and Restore ---> Snapshot

---> 所有数据流和索引
---> 单个索引等
```



###### 6.6.2.通过命令恢复快照

```bash
POST /_snapshot/newes_snp/daily-snap-2024.05.11-pfsf0g5er7ophfuigczrqw/_restore
{
  "indices": "kibana_sample_data_ecommerce,kibana_sample_data_flights",
  "ignore_unavailable": true,
  "include_global_state": true,
  "rename_pattern": "index_(.+)",
  "rename_replacement": "restored_index_$1"
}


curl --k -u elastic:$ESPASSWD "https://222.24.203.42:9200/_snapshot/my_backup/snapshot_1/_restore' -H 'Content-Type: application/json' -d '{
  "indices": "my_index",
  "ignore_unavailable": true,
  "include_global_state": false,
  "rename_pattern": "my_index",
  "rename_replacement": "my_index_restored"
}'

```





### 六、低/零停机的切换建议

- 简单停机切换（最稳妥）：
  1. 通知停写窗口，停止向旧集群写入（关闭写流量或让应用以只读方式运行）。
  
     将应用或 Logstash/Beats 流量切到维护模式；或者把所有 index 设置为 `index.blocks.write=true`。
  
  2. 在旧集群强制同步落盘：
     ```bash
     curl -k -u elastic:$OLD_PASS https://10.40.10.124:9200/_flush/synced -X POST
     ```
  
  3. 立刻创建最终快照（见第三部分的 final_mig），等待完成。
  
  4. 在新集群删除已恢复的业务索引（如之前做过预热恢复），然后从最终快照恢复一次，确保数据是停写后的最终状态。
  
  5. 验证通过后，把客户端的 ES 地址切换到 222.24.203.42/43/44。
  
  6. 验证 Kibana 仪表盘、报警规则、ILM、模板、别名。  
  
- 预热+短窗口切换（减少窗口，但总恢复时间未必显著缩短）：
  1) 业务不停写的情况下，先用较早的快照在新集群做恢复预热，进行功能校验。
  2) 到切换窗口，停写，创建最终增量快照 final_mig。
  3) 新集群从 final_mig 恢复（注意：恢复本身不会“基于上次恢复增量”，仍需从仓库下载所需段文件，但因为仓库是增量存储，final_mig 生成较快；恢复耗时取决于 NFS/网络/磁盘）。
  4) 切流量。

### 七、切换后收尾

- Kibana 内容迁移：
  - 如果恢复时包含了 .kibana*，新 Kibana 会直接看到旧的可视化/仪表盘/索引模式。注意 Kibana 版本要与 ES 兼容。
  - 如果恢复包含了 .security，用户与角色将以旧集群状态为准；elastic 用户密码会被恢复成旧集群的密码。
- 为新集群配置“新的”快照仓库（不要再对旧仓库写）：
  - 准备一个新的 NFS 目录（例如挂载到 /snp-new），在新集群创建新的仓库，如 es_snp_new（非只读）：
    ```bash
    curl -k -u elastic "https://222.24.203.42:9200/_snapshot/es_snp_new" -X PUT -H "Content-Type: application/json" -d '{"type":"fs","settings":{"location":"/snp-new","compress":true}}'
    ```
  - 更新/新建 SLM 策略使用 es_snp_new。
- 观察一段时间后再下线旧集群；若要保留旧快照仓库做历史留存，不要让新集群对其写入。
- 如果恢复时使用了 include_global_state=true，建议检查并清理可能从旧集群带过来的持久化设置（举例：分配过滤、磁盘水位阈值、集群路由等）：
  - 查看：
   ```bash
   curl -k -u elastic https://222.24.203.42:9200/_cluster/settings?include_defaults=true
   ```
  - 必要时置空相关持久化设置。

### 八、常见问题与排查

- 新集群索引 red/无法打开：多为缺插件或分配过滤问题。安装缺失插件；检查 cluster.routing.allocation.* 持久化设置；确认新节点磁盘水位线未触发。
- 注册仓库报错/看不到快照：确认三台新节点的 /snp 内容一致、权限为 elasticsearch 用户可读，且仓库注册用了 readonly=true、verify=false。
- 恢复 .security 后无法登录：使用旧集群 elastic 用户的密码重试；必要时使用离线工具重置内置用户密码。
- 性能与耗时：200G 在 NFS 上的恢复时间取决于网络与存储吞吐，一般需数十分钟级别。可通过提升 NFS/网络带宽、增大并发（恢复受分片并发影响）来优化。

### 九、最小可执行清单（按顺序）

- 新集群三台机器以只读模式挂载 NFS 到 /snp 。
- 新集群注册只读仓库 es_snp（verify=false）。
- 旧集群在停写窗口创建最终快照 final_mig。
- 新集群从 final_mig 恢复（必要时 include_global_state=true）。
- 校验数据与查询，更新客户端地址到 222.24.203.42/43/44。
- 在新集群创建新的备份仓库 es_snp_new，SLM 指向新仓库。
- 保留旧集群与旧仓库一段时间，确认无误后再做后续处置。

如需，我可以根据你实际的索引命名、是否迁移系统索引、是否保留 ILM/模板，给出更精确的恢复语句与过滤策略。


### References

1. **elasticsearch 集群 - 轩脉刃 - 博客园**. [https://www.cnblogs.com](https://www.cnblogs.com/yjf512/p/4865930.html)
2. **详尽的 Elasticsearch7.X 安装及集群搭建教程 - Michael翔 - 博客园**. [https://www.cnblogs.com](https://www.cnblogs.com/michael-xiang/p/13715692.html)
3. **节点 | Elasticsearch 中文文档**. [https://elasticsearch.bookhub.tech](https://elasticsearch.bookhub.tech/set_up_elasticsearch/configuring_elasticsearch/node)
4. **Elasticsearch 7.16集群搭建指南-腾讯云开发者社区-腾讯云**. [https://cloud.tencent.com](https://cloud.tencent.com/developer/article/1934691)
5. **elasticsearch-7.3.2集群搭建_git elasticsearch7.0.32-CSDN博客**. [https://blog.csdn.net](https://blog.csdn.net/lzxlfly/article/details/101644156)
6. **在单台服务器部署多个ElasticSearch节点 - 张小凯的博客**. [https://jasonkayzk.github.io](https://jasonkayzk.github.io/2019/10/04/在单台服务器部署多个ElasticSearch节点/)
7. **Docker部署elasticsearch集群（Demo版）_一个有梦想的小白的博客-CSDN博客**. [https://blog.csdn.net](https://blog.csdn.net/weixin_42803027/article/details/115868852)
8. **elasticsearch三节点集群搭建 - 腾讯云开发者社区-腾讯云**. [https://cloud.tencent.com](https://cloud.tencent.com/developer/article/1589975)
9. **Elasticsearch 最佳运维实践 - 总结（二） - 散尽浮华 - 博客园**. [https://www.cnblogs.com](https://www.cnblogs.com/kevingrace/p/10682264.html)
10. **Elasticsearch 7.3 之 搭建三节点集群、安装 kibana 、head 插件 - 掘金**. [https://juejin.cn](https://juejin.cn/post/6924960980950581262)
11. **导入模板配置 · 帮助**. [https://doc.you.xin](https://doc.you.xin/2basicbuild/build/biaodan/daorumubanpeizhi.html)
2. **如何进行索引模板管理_检索分析服务 Elasticsearc...**. [https://help.aliyun.com](https://help.aliyun.com/document_detail/211576.html)
3. **怎么做进销存软件导入模板 | 零代码企业数字化知识站**. [https://www.jiandaoyun.com](https://www.jiandaoyun.com/blog/qa/35933.html)
4. **EasyExcel处理Mysql百万数据的导入导出案例，秒级效率，拿来即用！ - JavaBuild - 博客园**. [https://www.cnblogs.com](https://www.cnblogs.com/JavaBuild/p/18185854)
5. **初探 Elasticsearch Index Template（索引模板) - 简书**. [https://www.jianshu.com](https://www.jianshu.com/p/1f67e4436c37)
6. **一文读懂：大模型RAG（检索增强生成）含高级方法 - 知乎**. [https://zhuanlan.zhihu.com](https://zhuanlan.zhihu.com/p/675509396)
7. **Elasticsearch Service 默认索引模板说明和调整-实践教程-文档中心-腾讯云**. [https://cloud.tencent.com](https://cloud.tencent.com/document/product/845/35548)
8. **课件8下载――索引和查询 - 数据库系统原理课件 - 课外天地 李树青 - 李树青 论坛 南京 财经 课外天地**. [https://www.njcie.com](https://www.njcie.com/bbs/dispbbs.asp?boardid=19&Id=178)
9. **知识库_大模型服务平台百炼(Model Studio)-阿里云帮助中心**. [https://help.aliyun.com](https://help.aliyun.com/zh/model-studio/rag-knowledge-base)
10. **Tsinghua**. [https://lib.tsinghua.edu.cn](https://lib.tsinghua.edu.cn/resource/qh/guide/incoPat_manual.pdf)
