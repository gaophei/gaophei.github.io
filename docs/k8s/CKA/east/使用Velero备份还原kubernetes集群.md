# velero简介

velero官方文档： [https://velero.io/docs/v1.7/](https://velero.io/docs/v1.7/)

veler代码托管地址： [https://github.com/vmware-tanzu/velero](https://github.com/vmware-tanzu/velero)

- Velero 是一个云原生的灾难恢复和迁移工具， 采用 Go 语言编写，可以安全的备份、恢复和迁移Kubernetes集群资源和持久卷。
- 使用velero可以对集群进行备份和恢复，降低集群DR造成的影响。其基本原理就是将集群的数据备份到对象存储中，在恢复的时候将数据从对象存储中拉取下来。
- 除了灾备之外velero还能做资源移转，支持把容器应用从一个集群迁移到另一个集群。
- Velero 是西班牙语，意思是帆船，其开发公司为 Heptio，已被 VMware 收购。



需要说明的是，在kubernetes的备份体系当中，etcd通常被作为主要的备份手段。与 Etcd 备份相比，直接备份 `Etcd` 是将集群的全部资源备份起来。而 `Velero` 可以对 `Kubernetes` 集群内对象级别进行备份。除了对 `Kubernetes` 集群进行整体备份外，`Velero` 还可以通过对 `Type`、`Namespace`、`Label` 等对象进行分类备份或者恢复。



适用场景： 

- `灾备场景`：提供备份恢复k8s集群的能力
- `迁移场景`：提供拷贝集群资源到其他集群的能力（复制同步开发，测试，生产环境的集群配置，简化环境配置）



# velero工作原理

![](https://secure2.wostatic.cn/static/hCQyNqH2w4sV7crCH1AaTc/image.png?auth_key=1680618907-q2XEXBx1zCDMYBsvDn2yUf-0-bda1275f6fee6cd0d3bf1c23e5aa7a9f)

![](https://secure2.wostatic.cn/static/utAPJWkYT3gdrLqPjxYDQ5/image.png?auth_key=1680618907-aLKz9A4GYBYdQGmn3TdTgf-0-0d26c34d02f572c29c7231b9b030387a)

1. `Velero` 客户端发送备份指令。
2. `Kubernetes` 集群内创建一个 `Backup` 对象。
3. `BackupController` 监测 `Backup` 对象并开始备份过程。
4. `BackupController` 会向 `API Server` 查询相关数据。
5. `BackupController` 将查询到的数据备份到远端的对象存储。

# velero的部署

## velero的组件

`Velero` 组件一共分两部分，分别是服务端和客户端。

- 服务端：运行在需要备份的 `Kubernetes` 集群中
- 客户端：运行在本地的命令行的工具，需要部署在已配置好 `kubectl` 及集群 `kubeconfig` 的机器上



安装客户端： 

```Bash
wget https://github.com/vmware-tanzu/velero/releases/download/v1.7.1/velero-v1.7.1-linux-amd64.tar.gz
tar -xf velero-v1.7.1-linux-amd64.tar.gz
cp velero-v1.7.1-linux-amd64/velero /usr/bin/

```

验证： 

```Bash
# velero version                                                                                                                                                                          ─╯ 
                                                                                                                                                                      ─╯ 
Client:
        Version: v1.7.1
        Git commit: 4729274d07eae7e788233d5c995d7f45f40c9c61
<error getting server version: no matches for kind "ServerStatusRequest" in version "velero.io/v1">
```

## velero支持的存储

velero通过插件的方式支持众多的第三方对象存储，包括AWS S3经及S3兼容的存储、Azure BloB存储、Google Cloud存储、Aliyun OSS等，更详细的支持列表可参考： [https://velero.io/docs/v1.7/supported-providers/](https://velero.io/docs/v1.7/supported-providers/)



在下面的部署中，分别使用S3兼容的存储以及Aliyun OSS作为其存储演示部署的过程。



### 部署velero使用S3作为备份存储

备份至S3，需要使用到velero-plugin-for-aws插件，插件地址： [https://github.com/vmware-tanzu/velero-plugin-for-aws](https://github.com/vmware-tanzu/velero-plugin-for-aws)



配置S3认证文件： 

```Bash
# vim credentials-velero 
[default]
aws_access_key_id=xxx
aws_secret_access_key=xxx
```

通过客户端工具velero执行服务端安装： 

```Bash
velero install    \
  --provider aws   \
  --bucket douyu-velero   \
  --prefix bdc-unp-pre \
  --image velero/velero:v1.7.0  \
  --plugins velero/velero-plugin-for-aws:v1.3.0  \
  --namespace velero  \
  --secret-file ./bdc-credentials-velero  \
  --use-volume-snapshots=false \
  --use-restic \
  --backup-location-config region=fwh,s3ForcePathStyle="true",s3Url=http://s3.fwh.bcebos.com
```



### 部署velero使用OSS作为备份存储



备份至OSS，需要使用到velero-plugin-alibabacloud插件，插件地址：[https://github.com/AliyunContainerService/velero-plugin](https://github.com/AliyunContainerService/velero-plugin)



配置OSS认证文件： 

```Bash
# vim credentials-velero

ALIBABA_CLOUD_ACCESS_KEY_ID=xxx
ALIBABA_CLOUD_ACCESS_KEY_SECRET=xxx

```

通过客户端工具velero执行服务端安装： 

```Bash
velero install    \
  --provider alibabacloud   \
  --bucket ops-docker-hub-test   \
  --image velero/velero:v1.7.0  \
  --plugins registry.cn-beijing.aliyuncs.com/acs/velero-plugin-alibabacloud:v1.2  \
  --namespace velero  \
  --secret-file ./credentials-velero  \
  --use-volume-snapshots=false \
  --use-restic \
  --backup-location-config region=cn-beijing

```



> 需要说明的是，OSS本身也支持S3接口，所以可以直接使用S3存储的配置方法将OSS作为velero的备份存储

# 备份与恢复

## 备份

### 备份参数

使用velero命令行工具执行备份操作，相关命令参数说明如下： 

```Bash
velero create backup NAME [flags]

# 使用restic的方式备份持久卷的数据
--default-volumes-to-restic optionalBool[=true]   Use restic by default to backup all pod volumes

# 排除指定namespace
--exclude-namespaces stringArray                  namespaces to exclude from the backup

# 排除资源类型
--exclude-resources stringArray                   resources to exclude from the backup, formatted as resource.group, such as storageclasses.storage.k8s.io

# 包含集群资源类型 
--include-cluster-resources optionalBool[=true]   include cluster-scoped resources in the backup

# 包含的namespace
--include-namespaces stringArray                  namespaces to include in the backup (use '*' for all namespaces) (default *)

# 包含的资源对象类型
--include-resources stringArray                   resources to include in the backup, formatted as resource.group, such as storageclasses.storage.k8s.io (use '*' for all resources)

# 给这个备份加上标签
--labels mapStringString                          labels to apply to the backup
-o, --output string                               Output display format. For create commands, display the object but do not send it to the server. Valid formats are 'table', 'json', and 'yaml'. 'table' is not valid for the install command.

# 对指定标签的资源进行备份
-l, --selector labelSelector                      only back up resources matching this label selector (default )

# 对PV创建快照
--snapshot-volumes optionalBool[=true]            take snapshots of PersistentVolumes as part of the backup

# 指定备份的位置
--storage-location string                         location in which to store the backup

# 备份数据多久删
--ttl duration                                    how long before the backup can be garbage collected (default 720h0m0s)

# 指定快照的位置，也就是哪一个公有云驱动
--volume-snapshot-locations strings               list of locations (at most one per provider) where volume snapshots should be stored

```



### 备份操作

执行备份： 

```Bash
# velero backup create default --include-namespaces default --default-volumes-to-restic                                                                                                   ─╯ 
Backup request "default" submitted successfully.
Run `velero backup describe default` or `velero backup logs default` for more details.

```

查看备份详情： 

```Bash
# 通过加上—detail参数可查看更详细的信息。
# velero backup describe default                                                                                                                                                          ─╯ 
Name:         default
Namespace:    velero
Labels:       velero.io/storage-location=default
Annotations:  velero.io/source-cluster-k8s-gitversion=v1.16.8
              velero.io/source-cluster-k8s-major-version=1
              velero.io/source-cluster-k8s-minor-version=16

Phase:  InProgress

Errors:    0
Warnings:  0

Namespaces:
  Included:  default
  Excluded:  <none>

Resources:
  Included:        *
  Excluded:        <none>
  Cluster-scoped:  auto

Label selector:  <none>

Storage Location:  default

Velero-Native Snapshot PVs:  auto

TTL:  720h0m0s

Hooks:  <none>

Backup Format Version:  1.1.0

Started:    2021-12-08 13:47:13 +0800 CST
Completed:  <n/a>

Expiration:  2022-01-07 13:47:13 +0800 CST

Velero-Native Snapshots: <none included>
```

查看备份信息：

```YAML
# velero backup get                                                                                                                                                                       ─╯ 
NAME      STATUS       ERRORS   WARNINGS   CREATED                         EXPIRES   STORAGE LOCATION   SELECTOR
default   InProgress   0        0          2021-12-08 13:47:13 +0800 CST   29d       default            <none>
```

查看备份日志： 

```Bash
velero backup logs default
```



## 恢复

### 恢复参数

使用velero命令行工具执行恢复操作，相关命令参数说明如下： 

```Bash
--exclude-namespaces stringArray                  Namespaces to exclude from the restore.
--exclude-resources stringArray                   Resources to exclude from the restore, formatted as resource.group, such as storageclasses.storage.k8s.io.
--from-backup string                              Backup to restore from
--from-schedule string                            Schedule to restore from
--include-cluster-resources optionalBool[=true]   Include cluster-scoped resources in the restore.
--include-namespaces stringArray                  Namespaces to include in the restore (use '*' for all namespaces) (default *)
--include-resources stringArray                   Resources to include in the restore, formatted as resource.group, such as storageclasses.storage.k8s.io (use '*' for all resources).  
--labels mapStringString                          Labels to apply to the restore.
--namespace-mappings mapStringString              Namespace mappings from name in the backup to desired restored name in the form src1:dst1,src2:dst2,...
--preserve-nodeports optionalBool[=true]          Whether to preserve nodeports of Services when restoring.
# 是否连同持久存储数据一起恢复
--restore-volumes optionalBool[=true]             Whether to restore volumes from snapshots.
-l, --selector labelSelector                          Only restore resources matching this label selector. (default <none>)
```

### 恢复操作

执行恢复： 

```Bash
# velero restore create --from-backup default                                                                                                                                         ─╯ 
Restore request "default-20211208165729" submitted successfully.
Run `velero restore describe default-20211208165729` or `velero restore logs default-20211208165729` for more details.
```

查看恢复信息： 

```Bash
# velero restore get                                                                                                                                                                      ─╯ 
NAME                     BACKUP    STATUS       STARTED                         COMPLETED   ERRORS   WARNINGS   CREATED                         SELECTOR
default-20211208165729   default   InProgress   2021-12-08 16:57:28 +0800 CST   <nil>       0        0          2021-12-08 16:57:28 +0800 CST   <none>
```

查看恢复进度： 

```Bash
# velero restore describe default-20211208165729 --details                                                                                                                                ─╯ 
Name:         default-20211208165729
Namespace:    velero
Labels:       <none>
Annotations:  <none>

Phase:                                 InProgress
Estimated total items to be restored:  172
Items restored so far:                 172

Started:    2021-12-08 16:57:28 +0800 CST
Completed:  <n/a>

Backup:  default

Namespaces:
  Included:  all namespaces found in the backup
  Excluded:  <none>

Resources:
  Included:        *
  Excluded:        nodes, events, events.events.k8s.io, backups.velero.io, restores.velero.io, resticrepositories.velero.io
  Cluster-scoped:  auto

Namespace mappings:  <none>

Label selector:  <none>

Restore PVs:  auto

Restic Restores:
  Completed:
    default/ratings-v1-c6cdf8d98-7cm22: istio-envoy
  In Progress:
    default/details-v1-5974b67c8-5g5tg: istio-envoy
    default/mongodb-754d6fd6d8-pp4zm: istio-envoy (0.00%)
    default/productpage-v1-64794f5db4-8h475: istio-envoy (0.00%)
    default/reviews-v2-6cb6ccd848-z88zm: istio-envoy (0.00%)
    default/reviews-v3-cc56b578-6t7lf: wlp-output
  New:
    default/reviews-v1-7f6558b974-56ntt: istio-envoy, tmp, wlp-output
    default/reviews-v2-6cb6ccd848-z88zm: tmp, wlp-output
    default/reviews-v3-cc56b578-6t7lf: istio-envoy, tmp

Preserve Service NodePorts:  auto
```

查看恢复日志： 

```Bash
velero restore logs default-20211208165729 
```

## 周期性备份 



可以通过类似cronjob的方式对kubernetes相关资源执行周期性备份。



示例如下 ：

```Bash
# Create a backup every 6 hours
velero create schedule NAME --schedule="0 */6 * * *"

# Create a backup every 6 hours with the @every notation
velero create schedule NAME --schedule="@every 6h"

# Create a daily backup of the web namespace
velero create schedule NAME --schedule="@every 24h" --include-namespaces web

# Create a weekly backup, each living for 90 days (2160 hours)
velero create schedule NAME --schedule="@every 168h" --ttl 2160h0m0s


velero create schedule xx-devops-dev --schedule="@every 24h" --include-namespaces xx-devops-dev 
velero create schedule xx-devops-test --schedule="@every 24h" --include-namespaces xx-devops-test
velero create schedule xx-devops-prod --schedule="@every 24h" --include-namespaces xx-devops-prod 
velero create schedule xx-devops-common-test --schedule="@every 24h" --include-namespaces xx-devops-common-test 

```





# 注意事项

- 在velero备份的时候，备份过程中创建的对象是不会被备份的。
- `velero restore` 恢复不会覆盖`已有的资源`，只恢复当前集群中`不存在的资源`。已有的资源不会回滚到之前的版本，如需要回滚，需在restore之前提前删除现有的资源。
- 可以将velero作为一个cronjob来运行，定期备份数据。

# 附录



## velero支持的后端存储CRD

`Velero` 支持两种关于后端存储的 `CRD`，分别是 `BackupStorageLocation` 和 `VolumeSnapshotLocation`。

### BackupStorageLocation

`BackupStorageLocation` 主要用来定义 `Kubernetes` 集群资源的数据存放位置，也就是集群对象数据，不是 `PVC` 的数据。主要支持的后端存储是 `S3` 兼容的存储，比如：`Mino` 和阿里云 `OSS` 等。

下面是一个基于百度云BOS的S3兼容存储的配置示例： 

```YAML
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
# 只有 aws gcp azure
  provider: aws
  # 存储主要配置
  objectStorage:
  # bucket 的名称
    bucket: myBucket
    # bucket内的
    prefix: backup
# 不同的 provider 不同的配置
  config:
    #bucket地区
    region: fwh
    # s3认证信息
    profile: "default"
    # 使用 Minio 的时候加上，默认为 false
    # AWS 的 S3 可以支持两种 Url Bucket URL
    # 1 Path style URL： http://s3endpoint/BUCKET
    # 2 Virtual-hosted style URL： http://oss-cn-beijing.s3endpoint 将 Bucker Name 放到了 Host Header中
    # 3 阿里云仅仅支持 Virtual hosted 如果下面写上 true, 阿里云 OSS 会报错 403
    s3ForcePathStyle: "true"
    # s3的地址，格式为 http://minio:9000
    s3Url: http://s3.fwh.bcebos.com

```



使用阿里云OSS作为S3兼容存储的配置示例： 

```YAML
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  labels:
    component: velero
  name: default
  namespace: velero
spec:
  config:
    profile: "default"
    region: oss-cn-beijing
    s3Url: http://oss-cn-beijing.aliyuncs.com
    s3ForcePathStyle: "false"
  objectStorage:
    bucket: douyu-velero
    prefix: ""
  provider: aws

```



### VolumeSnapshotLocation

VolumeSnapshotLocation 主要用来给 PV 做快照，需要云提供商提供插件。这个需要使用 CSI 等存储机制。当然也可以使用专门的备份工具 Restic，把 PV 数据备份到对象存储中去。



Restic 是一款 GO 语言开发的数据加密备份工具，可以将本地数据加密后传输到指定的仓库。支持的仓库有 Local、SFTP、Aws S3、Minio、OpenStack Swift、Backblaze B2、Azure BS、Google Cloud storage、Rest Server等，其项目地址： [https://github.com/restic/restic](https://github.com/restic/restic)



如果要使用Restic备份数据，可在安装velero时使用如下选项：

```YAML
# 安装时需要自定义选项

--use-restic

# 这里我们存储 PV 使用的是 OSS 也就是 BackupStorageLocation，因此不用创建 VolumeSnapshotLocation 对象

--use-volume-snapshots=false

```



### 通过命令行管理存储

```YAML
# 列出用于备份的存储
# velero backup-location get                                                                                                                                                              ─╯ 
NAME      PROVIDER   BUCKET/PREFIX   PHASE       LAST VALIDATED                  ACCESS MODE   DEFAULT
default   aws        douyu-velero    Available   2021-12-08 11:36:49 +0800 CST   ReadWrite     true

# 删除存储
velero backup-storage delete default

# 备份指定使用哪个存储
velero create backup specify-storage --include-namespaces default --storage-location 


```



## 参考

- [《Kubernetes备份恢复之velero实战》](https://blog.51cto.com/kaliarch/2531077)