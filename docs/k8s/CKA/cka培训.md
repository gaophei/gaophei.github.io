***CKA培训***
### 1.容器技术
#### 1.1.容器技术发展

#docker镜像
```
---打包了应用及其依赖(包括完整操作系统的所有文件和目录)
---包含了应用运行所需要的所有依赖
---核心在于实现应用及其运行环境整体打包及打包格式统一
```

#容器
```
redhat: podman

2013年，dotCloud开源docker项目
docker: docker CE/docker EE
```

#容器是什么
```
定义：容器是容器image运行时的实例
主要是隔离、封装
```

#container VS VM
```
VM: Infrastructure--->Hypervisor--->Virtual Machine: Guest OS---App A/App B/App C...

Container Applications: Infrastructure--->Host OS--->docker: App A/App B/App C...
```

![image-20221211103247528](cka培训截图\image-20221211103247528.png)

![image-20221211104019837](cka培训截图\image-20221211104019837.png)



#### 1.2.容器技术基础

#OCI(open container initiative)
```
--- runtime spec
--- image format spec
```

![image-20221213095847003](cka培训截图\image-20221213095847003.png)

#docker engine

```
--- network
--- data volumes
--- image
--- container
```



![image-20221213100038103](cka培训截图\image-20221213100038103.png)

#dockers架构
```
cs架构：docker cli----docker server
```

![image-20221213100425634](cka培训截图\image-20221213100425634.png)


#### 1.3.docker安装
#步骤
```
1)安装虚拟化软件，比如：vmware
2)安装虚拟机操作系统，比如：ubuntu 
3)安装docker-ce
```

#VMware，创建虚拟机

![image-20221213155712072](cka培训截图\image-20221213155712072.png)



#安装ubuntu

```
ubuntu22.04.tls
miniinstall/shanghai
1core/4G/20Gdisk
```

```
网络配置：
sudo -i
# /etc/NetworkManager/system-connections/

```

```
# /etc/netplan/01-network-manager-all.yaml
network:
    ethernets:
        ens160:                    ## network card name
            dhcp4: false
            addresses:
              - 192.168.1.240/24   ## set static IP
            routes:
              - to: default
                via: 192.168.1.1  ## gateway
            nameservers:
              addresses: [202.96.203.133,114.114.114.114]
    version: 2
```

```bash
netplan apply
```

```
# 安装openssh
sudo apt-get update -y && sudo apt upgrade -y
sudo install openssh-server -y
sudo systemctl enable --now ssh
sudo systemctl status ssh
```



#安装docker

```
# step 1: 安装必要的一些系统工具
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
# step 2: 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
# Step 3: 写入软件源信息
sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
# Step 4: 更新并安装Docker-CE
sudo apt-get -y update
sudo apt-get -y install docker-ce
sudo systemctl enable --now docker
sudo systemctl status docker

# 安装指定版本的Docker-CE:
# Step 1: 查找Docker-CE的版本:
# apt-cache madison docker-ce
#   docker-ce | 17.03.1~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
#   docker-ce | 17.03.0~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
# Step 2: 安装指定版本的Docker-CE: (VERSION例如上面的17.03.1~ce-0~ubuntu-xenial)
# sudo apt-get -y install docker-ce=[VERSION]
```

```
#修改默认仓库
sudo -i
mkdir /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
 "registry-mirrors": ["https://ktjk1d0g.mirror.aliyuncs.com"]
}
EOF

systemctl daemon-reload
systemctl restart docker
systemctl status docker

docker search nginx
```





#### 1.4.容器基本操作
















































### 附录
#### 学习方法

| step |                |                    |               示例                |
| :--: | :------------: | :----------------: | --------------------------------- |
|  1   |      word      |    查单词，释义    |            pull，拉取             |
|  2   | <kbd>Tab</kbd> | 一下不全，两下列出 | # doc<kbd>Tab</kbd><br /># docker <kbd>空格</kbd> <kbd>Tab</kbd><kbd>Tab</kbd> |
|  3   |   man,--help   |        帮助        | # man docker <br># docker --help |
|  4   | echo $? | 查看回显 | 0 == 正确执行<br>非0 == 错误执行 |
|  5   |                |                    |                                   |



#### 相关软件

|      |   NAME   |                             URL                              |         FUNC          |
| :--: | :------: | :----------------------------------------------------------: | :-------------------: |
|  1   | 欧路词典 |                    https://www.eudic.net/                    |       翻译软件        |
|  2   |  Typora  |                     https://typoraio.cn                      |   MarkDown格式文档    |
|  3   |  VMware  |                   https://www.vmware.com/                    |      虚拟化软件       |
|  4   |  ubunt   |                     https://ubuntu.com/                      |      系统光盘iso      |
|  5   |  docker  |       https://docs.docker.com/desktop/install/ubuntu/        |         国外          |
|      |          | https://developer.aliyun.com/mirror/docker-ce?spm=a2c6h.13651102.0.0.4ea21b11CvJUSb |      国内阿里云       |
|      |          | https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors  | 仓库加速器daemon.json |
|  6   |          |                                                              |                       |
|      |          |                                                              |                       |



#### 目录

![image-20221213163404248](cka培训截图\image-20221213163404248.png)