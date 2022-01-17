**注意：本文指南讲的是rancher里nfs-client存储类的部署方案**

****

## 部署步骤

### 1. nfs服务器端设置

#如果学校里提供了nfs存储(非服务器形式)，本步忽略

#以centos7.9(IP192.168.1.100，最大分区为/)为例

#创建目录

```bash
mkdir /data
chmod -R 777 /data
```
#安装nfs服务并配置
```bash
yum install -y nfs*

cat >> /etc/exports <<EOF
/data 192.168.1.0/24(rw,sync,insecure,no_subtree_check,no_root_squash)
EOF

systemctl restart nfs && systemctl enable nfs

showmount -e
```

#### 2. nfs客户端配置

#每台docker节点都需配置
```bash
yum install -y nfs-utils
```
#可以某台docker节点上测试下，检查下是否会报错
```bash
mount -t nfs 192.168.1.100:/data /mnt
cd /mnt
```

#### 3. rancher里配置nfs-client

##### 3.1. 新建项目

#新建一个项目叫做infras，这个项目可以放置集群需要的各种基础设施

![image-20220117110551923](nfs\image-20220117110402271.png)


##### 3.2. 添加应用商店

#路径如下：全局-工具-商店设置-添加应用商店(多集群可以共享)

![image-20220117110749507](nfs\image-20220117110749507.png)

#URL：https://apphub.aliyuncs.com，范围：global，Helm版本：Helm v3

![image-20220117110952702](nfs\image-20220117110952702.png)

##### 3.3. 创建存储类并测试

#路径：在上面创建的项目infras中，选择"应用商店"，点击"启动"

![image-20220117111408186](nfs\image-20220117111408186.png)

#搜索 nfs-client-provisioner，然后点击进入配置页面：

![image-20220117111502034](nfs\image-20220117111502034.png)

#添加应答（就是所谓的参数），然后点击启动，参数如下

```
nfs.path=/data
nfs.server=192.168.1.100
storageClass.archiveOnDelete=false
```

![image-20220117111755040](nfs\image-20220117111755040.png)



#由于k8s v1.20的默认参数修改，导致默认pod报错，需升级替换

```
groundhog2k/nfs-subdir-external-provisioner:v3.2.0
```

![image-20220117112047805](nfs\image-20220117112047805.png)



#升级完成后，可以看到nfs-client存储类了

![image-20220117112458379](nfs\image-20220117112458379.png)



![image-20220117112529779](nfs\image-20220117112529779.png)



#创建pvc测试

![image-20220117112614541](nfs\image-20220117112614541.png)



#填写名称，选择命名空间、存储类及大小

![image-20220117112202875](nfs\image-20220117112202875.png)

#创建成功

![image-20220117112240082](nfs\image-20220117112240082.png)




