

***CKA培训***

[TOC]

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

Containerized Applications: Infrastructure--->Host OS--->docker: App A/App B/App C...
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
cs架构：
```

![image-20221213100425634](cka培训截图\image-20221213100425634.png)


#### 1.3.docker安装
##### 1.3.0.步骤  
```
1)安装虚拟化软件，比如：vmware
2)安装虚拟机操作系统，比如：ubuntu 
3)安装docker-ce
```

##### 1.3.1.VMware，创建虚拟机

![image-20221213155712072](cka培训截图\image-20221213155712072.png)



##### 1.3.2.安装ubuntu

```
ubuntu20.04.tls
mini-install/shanghai
1core/4G/20Gdisk
```

##### 1.3.2.1.网络配置

```bash
$ sudo -i
```
图形界面配置的IP等在 /etc/NetworkManager/system-connections/'Wired connection 1.nmconnection'
```bash
# cat /etc/NetworkManager/system-connections/Wired\ connection\ 1.nmconnection 
[connection]
id=Wired connection 1
uuid=eb96f5e8-e2c2-3ceb-810c-73d9ffd87a59
type=ethernet
autoconnect-priority=-999
interface-name=ens160
timestamp=1670924516

[ethernet]

[ipv4]
address1=192.168.1.240/24,192.168.1.1
dns=202.96.209.133;114.114.114.114;
method=manual

[ipv6]
addr-gen-mode=stable-privacy
method=disabled

[proxy]

```

手动配置网络时，设置/etc/netplan/01-network-manager-all.yaml
```bash
# cat /etc/netplan/01-network-manager-all.yaml
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
# netplan apply
```

##### 1.3.2.2.安装openssh
```bash
$ sudo -i
# apt-get update -y && sudo apt upgrade -y
# apt search ssh|grep server

# apt install openssh-server -y
# systemctl enable --now ssh
# systemctl status ssh

可以允许root账户远程登录
# passwd root

# echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
# systemctl restart ssh
# systemctl status ssh
```

##### 1.3.2.3.安装docker---22.04

```bash
step 1: 安装必要的一些系统工具
$ sudo -i
# apt-get update
# apt-get -y install apt-transport-https ca-certificates curl software-properties-common
step 2: 安装GPG证书
# curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
Step 3: 写入软件源信息
# add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
Step 4: 更新并安装Docker-CE
# apt-get -y update
# apt-get -y install docker-ce
# systemctl enable --now docker
# systemctl status docker

安装指定版本的Docker-CE:
Step 1: 查找Docker-CE的版本:
# apt-cache madison docker-ce
  docker-ce | 17.03.1~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
  docker-ce | 17.03.0~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
Step 2: 安装指定版本的Docker-CE: (VERSION例如上面的17.03.1~ce-0~ubuntu-xenial)
# apt-get -y install docker-ce=[VERSION]
```

```bash
修改默认仓库
$ sudo -i
# mkdir /etc/docker
# tee /etc/docker/daemon.json <<-'EOF'
{
 "registry-mirrors": ["https://ktjk1d0g.mirror.aliyuncs.com"]
}
EOF

# systemctl daemon-reload
# systemctl restart docker
# systemctl status docker

# docker search nginx
```

##### 1.3.2.4.安装docker---20.04
```bash
step 1: 安装必要的一些系统工具
$ sudo -i
# apt-get update
# apt-get install -y ca-certificates curl gnupg lsb-release
step 2: 安装GPG证书
# mkdir -p /etc/apt/keyrings
#  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
Step 3: 写入软件源信息
# add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
Step 4: 更新并安装Docker-CE
# apt-get -y update
# apt-get -y install docker-ce
# systemctl enable --now docker
# systemctl status docker

安装指定版本的Docker-CE:
Step 1: 查找Docker-CE的版本: apt-cache madison docker-ce 
# apt-cache madison docker-ce | awk '{ print $3 }'
  5:19.03.15~3-0~ubuntu-focal
  5:20.10.22~3-0~ubuntu-focal
  .......输出省略......
Step 2: 安装指定版本的Docker-CE: (VERSION例如上面的17.03.1~ce-0~ubuntu-xenial)
# VERSION_STRING=5:20.10.13~3-0~ubuntu-jammy
# apt-get install -y docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-compose-plugin

#systemctl status docker
#docker run hello-world
```

```bash
修改默认仓库
$ sudo -i
# mkdir /etc/docker
# tee /etc/docker/daemon.json <<-'EOF'
{
 "registry-mirrors": ["https://ktjk1d0g.mirror.aliyuncs.com"]
}
EOF

# systemctl daemon-reload
# systemctl restart docker
# systemctl status docker

# docker search nginx
# docker run hello-world
# mkdir -p /etc/xiaoya
# touch /etc/xiaoya/mytoken.txt
# docker run -d -p 5678:80 -v /etc/xiaoya/mytoken.txt:/mytoken.txt --restart=always --name=xiaoya xiaoyaliu/alist:latest
```


#### 1.4.容器基本操作

##### 1.4.1.运行一个容器

```bash
$ sudo -i
# docker run --help
# man docker run

# docker run -d -p 8080:80 httpd
```

```bash
# docker run -d -p 8080:80 httpd
Unable to find image 'httpd:latest' locally
latest: Pulling from library/httpd
a2abf6c4d29d: Pull complete 
dcc4698797c8: Pull complete 
41c22baa66ec: Pull complete 
67283bbdd4a0: Pull complete 
d982c879c57e: Pull complete 
Digest: sha256:0954cc1af252d824860b2c5dc0a10720af2b7a3d3435581ca788dff8480c7b32
Status: Downloaded newer image for httpd:latest
0dfd41b8026694a025e5e5a6bbb4f4ea9abbdfd9eb3362019b2abeca42271bd2

# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED          STATUS          PORTS                                   NAMES
0dfd41b80266   httpd     "httpd-foreground"   15 seconds ago   Up 12 seconds   0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
httpd        latest    dabbfbe0c57b   11 months ago   144MB

# docker logs exciting_jemison
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 172.17.0.2. Set the 'ServerName' directive globally to suppress this message
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 172.17.0.2. Set the 'ServerName' directive globally to suppress this message
[Tue Dec 13 15:24:18.202035 2022] [mpm_event:notice] [pid 1:tid 139696380173632] AH00489: Apache/2.4.52 (Unix) configured -- resuming normal operations
[Tue Dec 13 15:24:18.202266 2022] [core:notice] [pid 1:tid 139696380173632] AH00094: Command line: 'httpd -D FOREGROUND'

# curl localhost:8080
<html><body><h1>It works!</h1></body></html>
```

##### 1.4.2.容器的生命周期管理

```bash
# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED        STATUS        PORTS                                   NAMES
0dfd41b80266   httpd     "httpd-foreground"   10 hours ago   Up 10 hours   0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison

# docker stop exciting_jemison 
exciting_jemison

# docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES

# docker ps -a
CONTAINER ID   IMAGE     COMMAND              CREATED        STATUS                     PORTS     NAMES
0dfd41b80266   httpd     "httpd-foreground"   10 hours ago   Exited (0) 6 seconds ago             exciting_jemison

# docker start exciting_jemison 
exciting_jemison

# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED        STATUS        PORTS                                   NAMES
0dfd41b80266   httpd     "httpd-foreground"   10 hours ago   Up 1 second   0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison

# docker ps -a
CONTAINER ID   IMAGE     COMMAND              CREATED        STATUS         PORTS                                   NAMES
0dfd41b80266   httpd     "httpd-foreground"   10 hours ago   Up 4 seconds   0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison

场景B：
# docker run -d  centos

# docker ps

```

##### 1.4.3.进入容器的方法

###### 1.4.3.1.方法一：docker attach 命令

```
--- 直接进入已启容器的命令终端，不会启用新的进程
--- Usage:  docker attach [OPTIONS] CONTAINER
--- 通过<ctrl+p><ctrl+q> 退出attach命令 
```
> 官网：https://docs.docker.com/engine/reference/commandline/attach/
```bash
A场景：-it interactive交互模式，tty终端。可以用<ctrl+p><ctrl+q>快捷键退出attach
# docker run -d -it centos /bin/bash -c 'while true; do sleep 1; echo hello; done'
Unable to find image 'centos:latest' locally
latest: Pulling from library/centos
a1d0c7532777: Pull complete 
Digest: sha256:a27fd8080b517143cbbbab9dfb7c8571c40d67d534bbdee55bd6c473f432b177
Status: Downloaded newer image for centos:latest
03aed8b857b753d3bcef84ffec76a090a9752c4cb67850b6edbbb92737f6511a

# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                   NAMES
03aed8b857b7   centos    "/bin/bash -c 'while…"   3 seconds ago    Up 2 seconds                                            cool_bouman

# docker logs cool_bouman 
hello
hello
hello
hello
hello

# docker attach cool_bouman 
hello
hello
hello
hello
hello
^Chello   ---> ctrl+C 无法退出
hello
hello
hello
hello    ---> ctrl+p ctrl+q 退出 
read escape sequence

```
注意：如果docker run时没有加-it参数，那么docker attach 进入容器后，通过<ctrl+p><ctrl+q>无法退出attach命令；只能通过关闭这个终端界面或者kill 线程号来结束
```bash
B场景：docker run后容器一直运行不会退出。<ctrl+p><ctrl+q>快捷键不可用
# docker run -d centos /bin/bash -c 'while true; do sleep 1; echo haha; done'
cf375cdfeaf57573c772335f16153c37ca9e6e0f8f41b52b3bd6caa4d75a8464

# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED             STATUS             PORTS                                   NAMES
cf375cdfeaf5   centos    "/bin/bash -c 'while…"   3 seconds ago       Up 1 second                                                inspiring_fermat
03aed8b857b7   centos    "/bin/bash -c 'while…"   41 minutes ago      Up 41 minutes                                              cool_bouman

通过<ctrl+p><ctrl+q>无法退出attach命令；只能通过关闭这个终端界面或者kill 线程号来结束
# docker attach inspiring_fermat
haha
haha
haha
haha
haha
haha

kill 线程号无效
# ps -ef|grep docker
root        8797       1  0 10:01 ?        00:00:10 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root       25497   13612  0 11:26 pts/7    00:00:00 docker attach inspiring_fermat
root       25800   25266  0 11:28 pts/2    00:00:00 grep --color=auto docker


# kill -9 25497

# ps -ef|grep docker
root        8797       1  0 10:01 ?        00:00:10 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root       `25877`   `13612`  0 11:28 pts/7    00:00:00 docker attach inspiring_fermat
root       26013   25266  0 11:29 pts/2    00:00:00 grep --color=auto docker

kill 父线程号才有效
# ps -ef|grep 13612
root     `13612` `13600`  0 15:29 pts/1    00:00:00 -bash
root       `25877`   `13612`  0 11:28 pts/7    00:00:00 docker attach inspiring_fermat
root     3398883 3360424  0 15:45 pts/2    00:00:00 grep --color=auto 13612

# kill -9 13612

# ps -ef|grep docker
root        8797       1  0 10:01 ?        00:00:10 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root       26067   25266  0 11:29 pts/2    00:00:00 grep --color=auto docker
```

```bash
C场景：容器运行后直接退出。容器当中没有服务或正在运行的程序
# docker run -d centos
50ce62352cb7c0917148c571c1170a3a33e426ee39d79a85c660ce4e675caf06

# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED        STATUS       PORTS                                   NAMES

# docker ps -a
CONTAINER ID   IMAGE     COMMAND                  CREATED         STATUS                     PORTS                                   NAMES
50ce62352cb7   centos    "/bin/bash"              4 seconds ago   Exited (0) 3 seconds ago                                           hardcore_sammet
```
###### 1.4.3.2.方法二：docker exec 命令
```
--- 在容器中打开新的终端
--- Usage:  docker exec [OPTIONS] CONTAINER COMMAND [ARG...]
```

```bash
# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED        STATUS       PORTS                                   NAMES
cf375cdfeaf5   centos    "/bin/bash -c 'while…"   5 hours ago    Up 5 hours                                           inspiring_fermat
03aed8b857b7   centos    "/bin/bash -c 'while…"   6 hours ago    Up 6 hours                                           cool_bouman
b064fc7ce564   nginx     "/docker-entrypoint.…"   6 hours ago    Up 6 hours   0.0.0.0:8081->80/tcp, :::8081->80/tcp   stoic_wilson
0dfd41b80266   httpd     "httpd-foreground"       17 hours ago   Up 6 hours   0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison

# docker exec -it cool_bouman /bin/bash

[root@03aed8b857b7 /]# cat /etc/redhat-release 
CentOS Linux release 8.4.2105

[root@03aed8b857b7 /]# pwd
/

[root@03aed8b857b7 /]# ps -x
    PID TTY      STAT   TIME COMMAND
      1 pts/0    Ss+    0:07 /bin/bash -c while true; do sleep 1; echo hello; done
  20963 pts/1    Ss     0:00 /bin/bash
  21006 pts/0    S+     0:00 /usr/bin/coreutils --coreutils-prog-shebang=sleep /usr/bin/sleep 1
  21007 pts/1    R+     0:00 ps -x

<ctrl+c>
[root@03aed8b857b7 /]# ^C

<ctrl+d>退出
[root@03aed8b857b7 /]# exit

```

### 2.容器镜像
#### 2.1.容器镜像结构
```
Linux操作系统结构由内核空间和用户空间构成
--- kernel: bootfs，Linux系统内核，/boot
--- rootfs: Linux系统中的用户空间文件系统，除了/boot外的其他文件目录
```
> 官网https://www.kernel.org/

```bash
# cd /boot
# ls
config-5.15.0-43-generic  efi   initrd.img                    initrd.img-5.15.0-56-generic  memtest86+.bin  memtest86+_multiboot.bin      System.map-5.15.0-56-generic  vmlinuz-5.15.0-43-generic  vmlinuz.old
config-5.15.0-56-generic  grub  initrd.img-5.15.0-43-generic  initrd.img.old                memtest86+.elf  System.map-5.15.0-43-generic  vmlinuz                       `vmlinuz-5.15.0-56-generic`
# uname -a
Linux ubuntu001-virtual-machine `5.15.0-56-generic` #62-Ubuntu SMP Tue Nov 22 19:54:14 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
```



```
容器镜像
--- 容器镜像是容器的模板，容器是镜像的运行实例，runtime(比如docker)根据容器镜像创建容器
--- 容器镜像挂载在容器根目录下，是为容器中的应用提供隔离后执行环境的文件系统
       容器镜像打包了整个操作系统的文件和目录(rootfs)，当然也包括应用本身。即，应用及其运行所需的所有依赖，都在被封装在容器镜像中
--- 容器镜像采用分层结构
       所有容器共享宿主机Kernel，并且不能修改宿主机Kernel。即，容器运行过程中使用容器镜像里的文件，使用宿主机OS上的Kernel 
```
```bash
容器运行时，不能删除相关容器镜像
# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED        STATUS        PORTS                                   NAMES
0dfd41b80266   httpd     "httpd-foreground"       35 hours ago   Up 24 hours   0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison
# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
httpd        latest    dabbfbe0c57b   11 months ago   144MB
httpd        v9.1      dabbfbe0c57b   11 months ago   144MB

# docker rmi dabbfbe0c57b
Error response from daemon: conflict: unable to delete dabbfbe0c57b (must be forced) - image is referenced in multiple repositories

# docker rmi httpd:latest 
Untagged: httpd:latest
# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
httpd        v9.1      dabbfbe0c57b   11 months ago   144MB

# docker rmi httpd:v9.1 
Error response from daemon: conflict: unable to remove repository reference "httpd:v9.1" (must force) - container 0dfd41b80266 is using its referenced image dabbfbe0c57b

先停止后删除容器后，再删除容器镜像
# docker stop 0dfd41b80266
# docker rm 0dfd41b80266

# docker rmi dabbfbe0c57b
Error response from daemon: conflict: unable to delete dabbfbe0c57b (must be forced) - image is referenced in multiple repositories

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
nginx        latest    605c77e624dd   11 months ago   141MB
httpd        latest    dabbfbe0c57b   11 months ago   144MB
httpd        v10.1     dabbfbe0c57b   11 months ago   144MB
centos       latest    5d0da3dc9764   15 months ago   231MB
# docker rmi httpd:latest 
Untagged: httpd:latest
# docker rmi httpd:v10.1 
Untagged: httpd:v10.1
Untagged: httpd@sha256:0954cc1af252d824860b2c5dc0a10720af2b7a3d3435581ca788dff8480c7b32
Deleted: sha256:dabbfbe0c57b6e5cd4bc089818d3f664acfad496dc741c9a501e72d15e803b34
Deleted: sha256:0e16a5a61bcb4e6b2bb2d746c2d6789d6c0b66198208b831f74b52198d744189
Deleted: sha256:f79670638074ff7fd293e753c11ea2ca0a2d92ab516d2f6b0bac3f4c6fed5d86
Deleted: sha256:189d55cdd18e4501032bb700a511c2d69c82fd75f1b619b5218ea6870e71e4aa
Deleted: sha256:cb038ed3e490a8c0f195cf135ac0d27dd8d3872598b1cb858c2666f2dae95a61
# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE

# docker pull httpd
Using default tag: latest
latest: Pulling from library/httpd
a2abf6c4d29d: Already exists 
dcc4698797c8: Pull complete 
41c22baa66ec: Pull complete 
67283bbdd4a0: Pull complete 
d982c879c57e: Pull complete 
Digest: sha256:0954cc1af252d824860b2c5dc0a10720af2b7a3d3435581ca788dff8480c7b32
Status: Downloaded newer image for httpd:latest
docker.io/library/httpd:latest
```


```
base镜像
--- scratch空镜像
--- 常用base镜像：ubuntu/CentOS/debian/alpine/BuildRoot
```

```
容器镜像分层结构
--- docker镜像中引入层layer的概念。镜像制作过程中的每一步操作，都会生成一个新的镜像层
--- 容器由若干只读镜像层和最上面的一个可写容器层构成
```



![image-20221215144955248](cka培训截图\image-20221215144955248.png)



```bash
检查镜像的分层架构
# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
nginx        latest    605c77e624dd   11 months ago   141MB

# docker inspect nginx:latest 
# docker image inspect nginx:latest

[
    {
        "Id": "sha256:605c77e624ddb75e6110f997c58876baa13f8754486b461117934b24a9dc3a85",
     .......省略部分.......
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/0397492a4ec7cf671195430a76b2863e4e39a3660ee051473a7ca99d49e3a734/diff:/var/lib/docker/overlay2/9457405d44ebe6080d780835b26a4f6194bf74bb148db95a6748df921e7e0266/diff:/var/lib/docker/overlay2/3a5ce64ff1acc72e562091f88fac96e7f9ba0d45dd03647103f351f6c954f395/diff:/var/lib/docker/overlay2/d8ee1384effeaeeb8c28e498be3bef1366c3a91a1016680db9d5a69014a470c4/diff:/var/lib/docker/overlay2/91f0262328445181897369ccf6a73ab34f472481ca47aa7929f8bfee6f776dce/diff",
                "MergedDir": "/var/lib/docker/overlay2/455d86552f7cd95e147c34553366f070ca606b726c4a6fd721d068cc8590eb34/merged",
                "UpperDir": "/var/lib/docker/overlay2/455d86552f7cd95e147c34553366f070ca606b726c4a6fd721d068cc8590eb34/diff",
                "WorkDir": "/var/lib/docker/overlay2/455d86552f7cd95e147c34553366f070ca606b726c4a6fd721d068cc8590eb34/work"
            },
            "Name": "overlay2"
        },
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:2edcec3590a4ec7f40cf0743c15d78fb39d8326bc029073b41ef9727da6c851f",
                "sha256:e379e8aedd4d72bb4c529a4ca07a4e4d230b5a1d3f7a61bc80179e8f02421ad8",
                "sha256:b8d6e692a25e11b0d32c5c3dd544b71b1085ddc1fddad08e68cbd7fda7f70221",
                "sha256:f1db227348d0a5e0b99b15a096d930d1a69db7474a1847acbc31f05e4ef8df8c",
                "sha256:32ce5f6a5106cc637d09a98289782edf47c32cb082dc475dd47cbf19a4f866da",
                "sha256:d874fd2bc83bb3322b566df739681fbd2248c58d3369cb25908d68e7ed6040a6"
            ]
        },
        "Metadata": {
            "LastTagTime": "0001-01-01T00:00:00Z"
        }
    }
]

```

```
UpperDir---容器层，可读写
LowerDir---镜像层，只读
MergeDir---合并层，容器挂载点
WorkDir---当前工作目录
```

```
UnionFS联合文件系统
--- UnionFS主要的功能是将多个不同位置的目录联合挂载(union mount)到同一个目录下
    每一个镜像层都是Linux操作系统文件与目录的一部分。在使用镜像时，docker会将所有的镜像层联合挂载到一个统一的挂载点上，表现为一个完整的Linux操作系统供容器使用
```
#aaa

![image-20230203182304524](cka培训截图\image-20230203182304524.png)


```
容器copy-on-write特性(写时复制)
对容器的增、删、改、查操作：
1.创建文件：新文件只能被添加在容器层中
2.删除文件：依据容器分层结构由上往下依次查找。找到后，在容器层记录该删除操作。具体实现是，UnionFS会在容器层创建一个"whiteout"文件，将被删除的文件"遮挡"起来
3.修改文件：依据容器分层结构由上往下依次查找。找到后，将镜像层中的数据复制到容器层进行修改，修改后的数据保存在容器层中(copy-on-write)
4.读取文件：依据容器分层结构由上往下依次查找
```



#### 2.2.构建容器镜像

```
两种方法：
1. cmd
   1) docker  ps
   2) 修改容器
   3) docker commit 容器ID 镜像名称
2. file
   1) vi dockerfile
   2) docker build .
```




##### 2.2.1.docker commit 构建镜像

```
docker commit命令：可以将一个运行中的容器保存为镜像。
1. 运行一个容器
2. 修改容器内容
3. 将容器保存为镜像
```

```bash
Lab1. nginx镜像
# docker run -d -p 8081:80 nginx


# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
nginx        latest    605c77e624dd   11 months ago   141MB

# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                   NAMES
69b43d989318   nginx     "/docker-entrypoint.…"   46 minutes ago   Up 46 minutes   0.0.0.0:8081->80/tcp, :::8081->80/tcp   eager_cerf

# docker exec -it eager_cerf /bin/bash
root@69b43d989318:/# echo "hello" > /usr/share/nginx/html/index.html

root@69b43d989318:/# cat /usr/share/nginx/html/index.html
`hello`

# curl localhost:8081
hello

# docker commit eager_cerf hello
sha256:e9055ad9d1d497508cfefc2e77fcb944af9e993992d23bec6751588b3b2d6b4e

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
hello        latest    e9055ad9d1d4   5 seconds ago   141MB
nginx        latest    605c77e624dd   11 months ago   141MB

# docker image inspect hello:latest
[
    {
        "Id": "sha256:e9055ad9d1d497508cfefc2e77fcb944af9e993992d23bec6751588b3b2d6b4e",
        "RepoTags": [
            "hello:latest"
        ],
     ......省略内容......
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/455d86552f7cd95e147c34553366f070ca606b726c4a6fd721d068cc8590eb34/diff:/var/lib/docker/overlay2/0397492a4ec7cf671195430a76b2863e4e39a3660ee051473a7ca99d49e3a734/diff:/var/lib/docker/overlay2/9457405d44ebe6080d780835b26a4f6194bf74bb148db95a6748df921e7e0266/diff:/var/lib/docker/overlay2/3a5ce64ff1acc72e562091f88fac96e7f9ba0d45dd03647103f351f6c954f395/diff:/var/lib/docker/overlay2/d8ee1384effeaeeb8c28e498be3bef1366c3a91a1016680db9d5a69014a470c4/diff:/var/lib/docker/overlay2/91f0262328445181897369ccf6a73ab34f472481ca47aa7929f8bfee6f776dce/diff",
                "MergedDir": "/var/lib/docker/overlay2/049d3b9edd454e32ed5d3e3fb401bb4980425d37ed2ede4d3c80a38c60652601/merged",
                "UpperDir": "/var/lib/docker/overlay2/049d3b9edd454e32ed5d3e3fb401bb4980425d37ed2ede4d3c80a38c60652601/diff",
                "WorkDir": "/var/lib/docker/overlay2/049d3b9edd454e32ed5d3e3fb401bb4980425d37ed2ede4d3c80a38c60652601/work"
            },
            "Name": "overlay2"
        },
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:2edcec3590a4ec7f40cf0743c15d78fb39d8326bc029073b41ef9727da6c851f",
                "sha256:e379e8aedd4d72bb4c529a4ca07a4e4d230b5a1d3f7a61bc80179e8f02421ad8",
                "sha256:b8d6e692a25e11b0d32c5c3dd544b71b1085ddc1fddad08e68cbd7fda7f70221",
                "sha256:f1db227348d0a5e0b99b15a096d930d1a69db7474a1847acbc31f05e4ef8df8c",
                "sha256:32ce5f6a5106cc637d09a98289782edf47c32cb082dc475dd47cbf19a4f866da",
                "sha256:d874fd2bc83bb3322b566df739681fbd2248c58d3369cb25908d68e7ed6040a6",
                "sha256:f5a093ffdc14daaabfdbc8fe40e1302f7a62e1d0de1ce9ff27e39c993af883a3"
            ]
        },
        "Metadata": {
            "LastTagTime": "2022-12-15T15:42:30.739649322+08:00"
        }
    }
]

# docker image inspect nginx:latest 
[
    {
        "Id": "sha256:605c77e624ddb75e6110f997c58876baa13f8754486b461117934b24a9dc3a85",
        "RepoTags": [
            "nginx:latest"
        ],
        ......省略内容......
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/0397492a4ec7cf671195430a76b2863e4e39a3660ee051473a7ca99d49e3a734/diff:/var/lib/docker/overlay2/9457405d44ebe6080d780835b26a4f6194bf74bb148db95a6748df921e7e0266/diff:/var/lib/docker/overlay2/3a5ce64ff1acc72e562091f88fac96e7f9ba0d45dd03647103f351f6c954f395/diff:/var/lib/docker/overlay2/d8ee1384effeaeeb8c28e498be3bef1366c3a91a1016680db9d5a69014a470c4/diff:/var/lib/docker/overlay2/91f0262328445181897369ccf6a73ab34f472481ca47aa7929f8bfee6f776dce/diff",
                "MergedDir": "/var/lib/docker/overlay2/455d86552f7cd95e147c34553366f070ca606b726c4a6fd721d068cc8590eb34/merged",
                "UpperDir": "/var/lib/docker/overlay2/455d86552f7cd95e147c34553366f070ca606b726c4a6fd721d068cc8590eb34/diff",
                "WorkDir": "/var/lib/docker/overlay2/455d86552f7cd95e147c34553366f070ca606b726c4a6fd721d068cc8590eb34/work"
            },
            "Name": "overlay2"
        },
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:2edcec3590a4ec7f40cf0743c15d78fb39d8326bc029073b41ef9727da6c851f",
                "sha256:e379e8aedd4d72bb4c529a4ca07a4e4d230b5a1d3f7a61bc80179e8f02421ad8",
                "sha256:b8d6e692a25e11b0d32c5c3dd544b71b1085ddc1fddad08e68cbd7fda7f70221",
                "sha256:f1db227348d0a5e0b99b15a096d930d1a69db7474a1847acbc31f05e4ef8df8c",
                "sha256:32ce5f6a5106cc637d09a98289782edf47c32cb082dc475dd47cbf19a4f866da",
                "sha256:d874fd2bc83bb3322b566df739681fbd2248c58d3369cb25908d68e7ed6040a6"
            ]
        },
        "Metadata": {
            "LastTagTime": "0001-01-01T00:00:00Z"
        }
    }
]

# docker history hello:latest 
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
`e9055ad9d1d4   40 minutes ago   nginx -g daemon off;                            1.29kB`    
605c77e624dd   11 months ago    /bin/sh -c #(nop)  CMD ["nginx" "-g" "daemon…   0B        
<missing>      11 months ago    /bin/sh -c #(nop)  STOPSIGNAL SIGQUIT           0B        
<missing>      11 months ago    /bin/sh -c #(nop)  EXPOSE 80                    0B        
<missing>      11 months ago    /bin/sh -c #(nop)  ENTRYPOINT ["/docker-entr…   0B        
<missing>      11 months ago    /bin/sh -c #(nop) COPY file:09a214a3e07c919a…   4.61kB    
<missing>      11 months ago    /bin/sh -c #(nop) COPY file:0fd5fca330dcd6a7…   1.04kB    
<missing>      11 months ago    /bin/sh -c #(nop) COPY file:0b866ff3fc1ef5b0…   1.96kB    
<missing>      11 months ago    /bin/sh -c #(nop) COPY file:65504f71f5855ca0…   1.2kB     
<missing>      11 months ago    /bin/sh -c set -x     && addgroup --system -…   61.1MB    
<missing>      11 months ago    /bin/sh -c #(nop)  ENV PKG_RELEASE=1~bullseye   0B        
<missing>      11 months ago    /bin/sh -c #(nop)  ENV NJS_VERSION=0.7.1        0B        
<missing>      11 months ago    /bin/sh -c #(nop)  ENV NGINX_VERSION=1.21.5     0B        
<missing>      11 months ago    /bin/sh -c #(nop)  LABEL maintainer=NGINX Do…   0B        
<missing>      11 months ago    /bin/sh -c #(nop)  CMD ["bash"]                 0B        
<missing>      11 months ago    /bin/sh -c #(nop) ADD file:09675d11695f65c55…   80.4MB    
# docker history nginx:latest 
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
605c77e624dd   11 months ago   /bin/sh -c #(nop)  CMD ["nginx" "-g" "daemon…   0B        
<missing>      11 months ago   /bin/sh -c #(nop)  STOPSIGNAL SIGQUIT           0B        
<missing>      11 months ago   /bin/sh -c #(nop)  EXPOSE 80                    0B        
<missing>      11 months ago   /bin/sh -c #(nop)  ENTRYPOINT ["/docker-entr…   0B        
<missing>      11 months ago   /bin/sh -c #(nop) COPY file:09a214a3e07c919a…   4.61kB    
<missing>      11 months ago   /bin/sh -c #(nop) COPY file:0fd5fca330dcd6a7…   1.04kB    
<missing>      11 months ago   /bin/sh -c #(nop) COPY file:0b866ff3fc1ef5b0…   1.96kB    
<missing>      11 months ago   /bin/sh -c #(nop) COPY file:65504f71f5855ca0…   1.2kB     
<missing>      11 months ago   /bin/sh -c set -x     && addgroup --system -…   61.1MB    
<missing>      11 months ago   /bin/sh -c #(nop)  ENV PKG_RELEASE=1~bullseye   0B        
<missing>      11 months ago   /bin/sh -c #(nop)  ENV NJS_VERSION=0.7.1        0B        
<missing>      11 months ago   /bin/sh -c #(nop)  ENV NGINX_VERSION=1.21.5     0B        
<missing>      11 months ago   /bin/sh -c #(nop)  LABEL maintainer=NGINX Do…   0B        
<missing>      11 months ago   /bin/sh -c #(nop)  CMD ["bash"]                 0B        
<missing>      11 months ago   /bin/sh -c #(nop) ADD file:09675d11695f65c55…   80.4MB  

# docker run -d  -p 8080:80  hello
fbe9a76cb37ea66aa08666f6c2a1a90d5caa107e590ba8046143825295f2bd2c

# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                   NAMES
fbe9a76cb37e   hello     "/docker-entrypoint.…"   2 seconds ago    Up 1 second     0.0.0.0:8080->80/tcp, :::8080->80/tcp   strange_davinci
69b43d989318   nginx     "/docker-entrypoint.…"   52 minutes ago   Up 52 minutes   0.0.0.0:8081->80/tcp, :::8081->80/tcp   eager_cerf

# curl localhost:8080
`hello`
```



```bash
Lab2. centos镜像

# docker run -itd --privileged centos /sbin/init
Unable to find image 'centos:latest' locally
latest: Pulling from library/centos
a1d0c7532777: Pull complete 
Digest: sha256:a27fd8080b517143cbbbab9dfb7c8571c40d67d534bbdee55bd6c473f432b177
Status: Downloaded newer image for centos:latest
d2bbf9ce9faa6076faa9ee463426d5660bd5767337acb5782ef32c55134bd8aa

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
centos       latest    5d0da3dc9764   15 months ago    231MB
# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED              STATUS              PORTS                                   NAMES
d2bbf9ce9faa   centos    "/sbin/init"             About a minute ago   Up About a minute                                           pedantic_franklin

# docker exec -it pedantic_franklin /bin/bash

[root@d2bbf9ce9faa /]# yum install -y httpd
Failed to set locale, defaulting to C.UTF-8
CentOS Linux 8 - AppStream                                                                                                                                                         78  B/s |  38  B     00:00    
Error: Failed to download metadata for repo 'appstream': Cannot prepare internal mirrorlist: No URLs in mirrorlist
[root@d2bbf9ce9faa /]# cd /etc/yum.repos.d/
[root@d2bbf9ce9faa yum.repos.d]# ls
CentOS-Linux-AppStream.repo  CentOS-Linux-ContinuousRelease.repo  CentOS-Linux-Devel.repo   CentOS-Linux-FastTrack.repo		CentOS-Linux-Media.repo  CentOS-Linux-PowerTools.repo
CentOS-Linux-BaseOS.repo     CentOS-Linux-Debuginfo.repo	  CentOS-Linux-Extras.repo  CentOS-Linux-HighAvailability.repo	CentOS-Linux-Plus.repo	 CentOS-Linux-Sources.repo
[root@d2bbf9ce9faa yum.repos.d]# rm -rfv ./*

参考阿里云镜像站修改yum源https://developer.aliyun.com/mirror/centos

[root@d2bbf9ce9faa yum.repos.d]# whereis curl
curl: /usr/bin/curl
[root@d2bbf9ce9faa yum.repos.d]# whereis wget
wget:
[root@d2bbf9ce9faa yum.repos.d]# curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2495  100  2495    0     0   1115      0  0:00:02  0:00:02 --:--:--  1115
[root@d2bbf9ce9faa yum.repos.d]# ls
CentOS-Base.repo
[root@d2bbf9ce9faa yum.repos.d]# cd
[root@d2bbf9ce9faa /]# yum repolist
Failed to set locale, defaulting to C.UTF-8
repo id                                                                               repo name
AppStream                                                                             CentOS-8.5.2111 - AppStream - mirrors.aliyun.com
base                                                                                  CentOS-8.5.2111 - Base - mirrors.aliyun.com
extras                                                                                CentOS-8.5.2111 - Extras - mirrors.aliyun.com


[root@d2bbf9ce9faa /]# yum install -y httpd
......省略内容......
Complete!

[root@d2bbf9ce9faa /]# systemctl status httpd
● httpd.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
     Docs: man:httpd.service(8)
[root@d2bbf9ce9faa /]# systemctl enable --now  httpd
Created symlink /etc/systemd/system/multi-user.target.wants/httpd.service → /usr/lib/systemd/system/httpd.service.

[root@d2bbf9ce9faa /]# systemctl status httpd
● httpd.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2022-12-15 08:07:32 UTC; 1s ago
     Docs: man:httpd.service(8)
 Main PID: 188 (httpd)
   Status: "Started, listening on: port 80"
    Tasks: 213 (limit: 3696)
   Memory: 16.1M
......省略内容......
Dec 15 08:07:32 d2bbf9ce9faa systemd[1]: Started The Apache HTTP Server.
Dec 15 08:07:32 d2bbf9ce9faa httpd[188]: Server configured, listening on: port 80

[root@d2bbf9ce9faa ~]# echo haha > /var/www/html/index.html
[root@d2bbf9ce9faa ~]# systemctl restart httpd
[root@d2bbf9ce9faa ~]# curl localhost
`haha`
[root@d2bbf9ce9faa ~]# exit
exit

# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED             STATUS             PORTS                                   NAMES
d2bbf9ce9faa   centos    "/sbin/init"             17 minutes ago      Up 17 minutes                                              pedantic_franklin

# docker commit pedantic_franklin testcentos
sha256:2e4796dfc411fb890c57b0a617f4b2f4ac951beee2d4aede1b46e59c11c5223b

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
`testcentos`   latest    2e4796dfc411   3 seconds ago    280MB
  centos       latest    5d0da3dc9764   15 months ago    231MB

# docker history testcentos:latest 
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
`2e4796dfc411   7 minutes ago   /sbin/init                                      48.5MB` 
5d0da3dc9764   15 months ago   /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B        
<missing>      15 months ago   /bin/sh -c #(nop)  LABEL org.label-schema.sc…   0B        
<missing>      15 months ago   /bin/sh -c #(nop) ADD file:805cb5e15fb6e0bb0…   231MB     
# docker history centos:latest 
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
5d0da3dc9764   15 months ago   /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B        
<missing>      15 months ago   /bin/sh -c #(nop)  LABEL org.label-schema.sc…   0B        
<missing>      15 months ago   /bin/sh -c #(nop) ADD file:805cb5e15fb6e0bb0…   231MB  

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
testcentos   latest    2e4796dfc411   9 minutes ago    280MB
centos       latest    5d0da3dc9764   15 months ago    231MB
# docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                   NAMES
d2bbf9ce9faa   centos    "/sbin/init"             27 minutes ago   Up 27 minutes                                           pedantic_franklin

# docker run -itd --privileged testcentos /sbin/init
d9177a39a3e8ca61ab3c471fbb9bd30dd5d361267c91c08e9576b73c70b81454
# docker ps
CONTAINER ID   IMAGE        COMMAND                  CREATED          STATUS          PORTS                                   NAMES
d9177a39a3e8   testcentos   "/sbin/init"             5 seconds ago    Up 4 seconds                                            vigilant_rubin
d2bbf9ce9faa   centos       "/sbin/init"             27 minutes ago   Up 27 minutes                                           pedantic_franklin

# docker exec -it vigilant_rubin /bin/bash
[root@d9177a39a3e8 /]# curl localhost 
`haha`

[root@d9177a39a3e8 /]# cat /var/www/html/index.html 
haha
[root@d9177a39a3e8 /]# rpm -q httpd
httpd-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64

[root@d9177a39a3e8 /]# systemctl status httpd
● httpd.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2022-12-15 08:24:28 UTC; 1min 52s ago
     Docs: man:httpd.service(8)
 Main PID: 55 (httpd)
   Status: "Total requests: 1; Idle/Busy workers 100/0;Requests/sec: 0.00917; Bytes served/sec:   2 B/sec"
    Tasks: 213 (limit: 3696)
   Memory: 16.3M
......省略内容......
Dec 15 08:24:28 d9177a39a3e8 systemd[1]: Started The Apache HTTP Server.
Dec 15 08:24:29 d9177a39a3e8 httpd[55]: Server configured, listening on: port 80

[root@d9177a39a3e8 /]# curl localhost 
`haha`
[root@d9177a39a3e8 /]# exit

注意：使用centos镜像时，如果容器中要使用systemctl，必须在docker run时加上--privileged和/sbin/init
     不然容器中会报错：
# systemctl enable --now httpd
Created symlink /etc/systemd/system/multi-user.target.wants/httpd.service → /usr/lib/systemd/system/httpd.service.
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
# systemctl status  httpd
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
```


##### 2.2.2.dockerfile 构建镜像

```
Dockerfile
---文件指令集，描述如何自动创建docker镜像
1. 是包含若干指令的文本文件，可以通过这些指令创建出docker image
2. 文件中的指令执行后，会创建出一个个新的镜像层
3. 文件中的注释以"#"开始
4. 一般由4部分组成：
   1) 基础镜像信息
   2) 容器启动指令
   3) 维护者信息
   4) 镜像操作指令
5. build context: 为镜像构建提供所需的文件或目录
```

Dockerfile常用命令

![image-20230204200034148](cka培训截图\image-20230204200034148.png)

见附录A.6

|       指令       |                     作用                     |                           命令格式                           | 例子                                                         |
| :--------------: | :------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------- |
|       FROM       |                 指定base镜像                 |  `FROM [--platform=<platform>] <image>[:<tag>] [AS <name>]`  | FROM  centos                                                 |
| MAINTAINER LABEL |                  维护者信息                  |    `LABEL <key>=<value> <key>=<value> <key>=<value> ...`     | LABEL "com.example.vendor"="ACME Incorporated"  <br/>LABEL com.example.label-with-value="foo" <br/>LABEL version="1.0" |
|       RUN        |                运行指定的命令                | RUN <command>： <br/>Linux: /bin/sh -c  <br/>Windows: cmd /S /C <br/> <br/>RUN ["executable", "param1", "param2"] | RUN /bin/bash -c 'source $HOME/.bashrc; echo $HOME' <br/> <br/>RUN ["/bin/bash", "-c", "echo hello"] <br/>RUN ["c:\windows\system32\tasklist.exe"] |
|       ADD        | 将文件从build context复制到镜像中 可以解压缩 | `ADD [--chown=<user>:<group>] [--checksum=<checksum>] <src>... <dest>`  <br/>`ADD [--chown=<user>:<group>] ["<src>",... "<dest>"]` | ADD hom* /mydir/  <br/>ADD --chown=55:mygroup files* /somedir/ |
|       COPY       |      将文件从build context复制到镜像中       | `COPY [--chown=<user>:<group>] <src>... <dest>`  <br/>`COPY [--chown=<user>:<group>] ["<src>",... "<dest>"]` | COPY hom* /mydir/  <br/>COPY --chown=55:mygroup files* /somedir/ |
|       ENV        |                 设置环境变量                 |                   `ENV <key>=<value> ...`                    | ENV MY_NAME="John Doe" <br/>ENV MY_DOG=Rex\ The\ Dog <br/>ENV MY_CAT=fluffy |
|      EXPOSE      |          指定容器中的应用坚挺的端口          |            `EXPOSE <port> [<port>/<protocol>...]`            | EXPOSE 80/tcp <br/>EXPOSE 80/udp                             |
|       USER       |              设置启动容器的用户              |                   `USER <user>[:<group>]`                    | USER tommy                                                   |
|       CMD        |     设置在容器启动时运行指定的脚本或命令     | CMD ["executable","param1","param2"] (*exec* form, this is the preferred form)  CMD ["param1","param2"] (as *default parameters to ENTRYPOINT*) CMD command param1 param2 (*shell* form) | CMD echo "This is a test." \|wc - <br/>CMD ["/usr/bin/wc","--help"] |
|    ENTRYPOINT    |    指定的是一个可执行的脚本或者程序的路径    |               ENTRYPOINT command param1 param2               | FROM ubuntu<br/>ENTRYPOINT ["top", "-b"]<br/>CMD ["-c"]  <br/> <br/>FROM debian:stable <br/>RUN apt-get update && apt-get install -y --force-yes apache2  <br/>EXPOSE 80 443  <br/>VOLUME ["/var/www", "/var/log/apache2", "/etc/apache2"] <br/>ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"] |
|      VOLUME      |    将文件或目录声明为volume，挂载到容器中    |                       VOLUME ["/data"]                       | FROM ubuntu <br/>RUN mkdir /myvol  <br/>RUN echo "hello world" > /myvol/greeting <br/>VOLUME /myvol |
|     WORKDIR      |            设置镜像的当前工作目录            |                   WORKDIR /path/to/workdir                   | WORKDIR /a <br>WORKDIR b <br/>WORKDIR c <br/>RUN pwd         |
>  官网https://docs.docker.com/engine/reference/builder/



```bash
dockerfile示例
1. 本地创建index.html
# echo hello > index.html

2. # vim dockerfile
```

```dockerfile
FROM httpd
COPY index.html /
RUN echo haha
```
```bash
3. docker build
# docker build -t testhttpd01 .
```
```bash
过程记录:
# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE

# cat index.html 
hello
f# cat dockerfile 
FROM  httpd
COPY index.html /
RUN echo haha

# docker build -t testhttpd01 .
Sending build context to Docker daemon  3.072kB
Step 1/3 : FROM  httpd
latest: Pulling from library/httpd
a2abf6c4d29d: Already exists 
dcc4698797c8: Pull complete 
41c22baa66ec: Pull complete 
67283bbdd4a0: Pull complete 
d982c879c57e: Pull complete 
Digest: sha256:0954cc1af252d824860b2c5dc0a10720af2b7a3d3435581ca788dff8480c7b32
Status: Downloaded newer image for httpd:latest
 ---> dabbfbe0c57b
Step 2/3 : COPY index.html /
 ---> e1e6bd941212
Step 3/3 : RUN echo haha
 ---> Running in f9b581ca2762
haha
Removing intermediate container f9b581ca2762
 ---> 17de6194e75f
Successfully built 17de6194e75f
Successfully tagged testhttpd01:latest


# docker images
REPOSITORY    TAG       IMAGE ID       CREATED          SIZE
testhttpd01   latest    17de6194e75f   29 seconds ago   144MB
httpd         latest    dabbfbe0c57b   12 months ago    144MB

# docker history testhttpd01:latest 
IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
`17de6194e75f   About a minute ago   /bin/sh -c echo haha                            0B`        
`e1e6bd941212   About a minute ago   /bin/sh -c #(nop) COPY file:44be4544761aa076…   6B`        
dabbfbe0c57b   12 months ago        /bin/sh -c #(nop)  CMD ["httpd-foreground"]     0B        
<missing>      12 months ago        /bin/sh -c #(nop)  EXPOSE 80                    0B        
<missing>      12 months ago        /bin/sh -c #(nop) COPY file:c432ff61c4993ecd…   138B      
<missing>      12 months ago        /bin/sh -c #(nop)  STOPSIGNAL SIGWINCH          0B        
<missing>      12 months ago        /bin/sh -c set -eux;   savedAptMark="…          60.5MB    
<missing>      12 months ago        /bin/sh -c #(nop)  ENV HTTPD_PATCHES=           0B        
<missing>      12 months ago        /bin/sh -c #(nop)  ENV HTTPD_SHA256=0127f7dc…   0B        
<missing>      12 months ago        /bin/sh -c #(nop)  ENV HTTPD_VERSION=2.4.52     0B        
<missing>      12 months ago        /bin/sh -c set -eux;  apt-get update;  apt-g…   2.63MB    
<missing>      12 months ago        /bin/sh -c #(nop) WORKDIR /usr/local/apache2    0B        
<missing>      12 months ago        /bin/sh -c mkdir -p "$HTTPD_PREFIX"  && chow…   0B        
<missing>      12 months ago        /bin/sh -c #(nop)  ENV PATH=/usr/local/apach…   0B        
<missing>      12 months ago        /bin/sh -c #(nop)  ENV HTTPD_PREFIX=/usr/loc…   0B        
<missing>      12 months ago        /bin/sh -c #(nop)  CMD ["bash"]                 0B        
<missing>      12 months ago        /bin/sh -c #(nop) ADD file:09675d11695f65c55…   80.4MB    
f# docker history httpd:latest 
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
dabbfbe0c57b   12 months ago   /bin/sh -c #(nop)  CMD ["httpd-foreground"]     0B        
<missing>      12 months ago   /bin/sh -c #(nop)  EXPOSE 80                    0B        
<missing>      12 months ago   /bin/sh -c #(nop) COPY file:c432ff61c4993ecd…   138B      
<missing>      12 months ago   /bin/sh -c #(nop)  STOPSIGNAL SIGWINCH          0B        
<missing>      12 months ago   /bin/sh -c set -eux;   savedAptMark="…          60.5MB    
<missing>      12 months ago   /bin/sh -c #(nop)  ENV HTTPD_PATCHES=           0B        
<missing>      12 months ago   /bin/sh -c #(nop)  ENV HTTPD_SHA256=0127f7dc…   0B        
<missing>      12 months ago   /bin/sh -c #(nop)  ENV HTTPD_VERSION=2.4.52     0B        
<missing>      12 months ago   /bin/sh -c set -eux;  apt-get update;  apt-g…   2.63MB    
<missing>      12 months ago   /bin/sh -c #(nop) WORKDIR /usr/local/apache2    0B        
<missing>      12 months ago   /bin/sh -c mkdir -p "$HTTPD_PREFIX"  && chow…   0B        
<missing>      12 months ago   /bin/sh -c #(nop)  ENV PATH=/usr/local/apach…   0B        
<missing>      12 months ago   /bin/sh -c #(nop)  ENV HTTPD_PREFIX=/usr/loc…   0B        
<missing>      12 months ago   /bin/sh -c #(nop)  CMD ["bash"]                 0B        
<missing>      12 months ago   /bin/sh -c #(nop) ADD file:09675d11695f65c55…   80.4MB 
```



```bash
容器镜像缓存特性
--- docker会缓存已有镜像的镜像层，构建或下载镜像时，如果某镜像层已经存在，则直接使用，无需重新创建或下载
```



```bash
在上面dockerfile里末尾添加一条指令：MAINTAINER test@163.com

# echo "MAINTAINER test@163.com" >> dockerfile 

# docker build -t testhttpd02 .
Sending build context to Docker daemon  3.072kB
Step 1/4 : FROM  httpd
 ---> dabbfbe0c57b
Step 2/4 : COPY index.html /
 ---> `Using cache`
 ---> e1e6bd941212
Step 3/4 : RUN echo haha
 ---> `Using cache`
 ---> 17de6194e75f
Step 4/4 : MAINTAINER test@163.com
 ---> Running in 49f2c610e9c4
Removing intermediate container 49f2c610e9c4
 ---> f1764c18d0fc
Successfully built f1764c18d0fc
Successfully tagged testhttpd02:latest

# docker images
REPOSITORY    TAG       IMAGE ID       CREATED              SIZE
testhttpd02   latest    f1764c18d0fc   About a minute ago   144MB
testhttpd01   latest    17de6194e75f   23 minutes ago       144MB
httpd         latest    dabbfbe0c57b   12 months ago        144MB

# docker history testhttpd02
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
`f1764c18d0fc   2 minutes ago    /bin/sh -c #(nop)  MAINTAINER test@163.com      0B`        
17de6194e75f   23 minutes ago   /bin/sh -c echo haha                            0B        
e1e6bd941212   23 minutes ago   /bin/sh -c #(nop) COPY file:44be4544761aa076…   6B        
dabbfbe0c57b   12 months ago    /bin/sh -c #(nop)  CMD ["httpd-foreground"]     0B        
<missing>      12 months ago    /bin/sh -c #(nop)  EXPOSE 80                    0B        
<missing>      12 months ago    /bin/sh -c #(nop) COPY file:c432ff61c4993ecd…   138B      
<missing>      12 months ago    /bin/sh -c #(nop)  STOPSIGNAL SIGWINCH          0B        
<missing>      12 months ago    /bin/sh -c set -eux;   savedAptMark="…          60.5MB    
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_PATCHES=           0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_SHA256=0127f7dc…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_VERSION=2.4.52     0B        
<missing>      12 months ago    /bin/sh -c set -eux;  apt-get update;  apt-g…   2.63MB    
<missing>      12 months ago    /bin/sh -c #(nop) WORKDIR /usr/local/apache2    0B        
<missing>      12 months ago    /bin/sh -c mkdir -p "$HTTPD_PREFIX"  && chow…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV PATH=/usr/local/apach…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_PREFIX=/usr/loc…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  CMD ["bash"]                 0B        
<missing>      12 months ago    /bin/sh -c #(nop) ADD file:09675d11695f65c55…   80.4MB    
```



```bash
对比试验，如果dockerfile里的指令进行了不同行的顺序交换，即使全部内容不变，那么也会重新创建，不会使用上面的缓存技术
# cat dockerfile 
FROM  httpd
MAINTAINER test@163.com
COPY index.html /
RUN echo haha

# docker build -t testhttpd03 .
Sending build context to Docker daemon  3.072kB
Step 1/4 : FROM  httpd
 ---> dabbfbe0c57b
Step 2/4 : MAINTAINER test@163.com
 ---> Running in 3bbf21256403
Removing intermediate container 3bbf21256403
 ---> da7b660ac80d
Step 3/4 : COPY index.html /
 ---> fb85b0e2235a
Step 4/4 : RUN echo haha
 ---> Running in fb933e50449e
haha
Removing intermediate container fb933e50449e
 ---> b710b771c28c
Successfully built b710b771c28c
Successfully tagged testhttpd03:latest

# docker images
REPOSITORY    TAG       IMAGE ID       CREATED          SIZE
`testhttpd03   latest    b710b771c28c   9 seconds ago    144MB`
testhttpd02   latest    f1764c18d0fc   5 minutes ago    144MB
testhttpd01   latest    17de6194e75f   26 minutes ago   144MB
testcentos    latest    2e4796dfc411   18 hours ago     280MB
hello         latest    e9055ad9d1d4   18 hours ago     141MB
nginx         latest    605c77e624dd   11 months ago    141MB
httpd         latest    dabbfbe0c57b   12 months ago    144MB
centos        latest    5d0da3dc9764   15 months ago    231MB
# docker history testhttpd03
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
b710b771c28c   18 seconds ago   /bin/sh -c echo haha                            0B        
fb85b0e2235a   19 seconds ago   /bin/sh -c #(nop) COPY file:44be4544761aa076…   6B        
da7b660ac80d   19 seconds ago   /bin/sh -c #(nop)  MAINTAINER test@163.com      0B        
dabbfbe0c57b   12 months ago    /bin/sh -c #(nop)  CMD ["httpd-foreground"]     0B        
<missing>      12 months ago    /bin/sh -c #(nop)  EXPOSE 80                    0B        
<missing>      12 months ago    /bin/sh -c #(nop) COPY file:c432ff61c4993ecd…   138B      
<missing>      12 months ago    /bin/sh -c #(nop)  STOPSIGNAL SIGWINCH          0B        
<missing>      12 months ago    /bin/sh -c set -eux;   savedAptMark="$(apt-m…   60.5MB    
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_PATCHES=           0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_SHA256=0127f7dc…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_VERSION=2.4.52     0B        
<missing>      12 months ago    /bin/sh -c set -eux;  apt-get update;  apt-g…   2.63MB    
<missing>      12 months ago    /bin/sh -c #(nop) WORKDIR /usr/local/apache2    0B        
<missing>      12 months ago    /bin/sh -c mkdir -p "$HTTPD_PREFIX"  && chow…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV PATH=/usr/local/apach…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  ENV HTTPD_PREFIX=/usr/loc…   0B        
<missing>      12 months ago    /bin/sh -c #(nop)  CMD ["bash"]                 0B        
<missing>      12 months ago    /bin/sh -c #(nop) ADD file:09675d11695f65c55…   80.4MB    
```

#### 2.3.容器镜像命名
```bash
镜像命名格式
--- image name = repository:tag
--- tag 一般用于描述镜像版本。若未指定tag，则默认为"latest"

# docker pull harbor.hello.com/admin-platform/account-center:1.0.2-RELEASE
```
```bash
# docker images
REPOSITORY    TAG       IMAGE ID       CREATED          SIZE
testhttpd03   latest    b710b771c28c   9 minutes ago    144MB
testhttpd02   latest    f1764c18d0fc   15 minutes ago   144MB
testhttpd01   latest    17de6194e75f   36 minutes ago   144MB
httpd         latest    dabbfbe0c57b   12 months ago    144MB
# docker tag httpd:latest httpd:v8.1
# docker images
REPOSITORY    TAG       IMAGE ID       CREATED          SIZE
testhttpd03   latest    b710b771c28c   10 minutes ago   144MB
testhttpd02   latest    f1764c18d0fc   15 minutes ago   144MB
testhttpd01   latest    17de6194e75f   37 minutes ago   144MB
httpd         latest    dabbfbe0c57b   12 months ago    144MB
httpd         v8.1      dabbfbe0c57b   12 months ago    144MB

因为有testhttpd等依赖镜像，所以无法通过imageID将两个image一起删除
# docker rmi dabbfbe0c57b -f
Error response from daemon: conflict: unable to delete dabbfbe0c57b (cannot be forced) - image has dependent child images

首先删除testhttpd镜像，再来删除httpd镜像
# docker rmi testhttpd03
Untagged: testhttpd03:latest
Deleted: sha256:b710b771c28c0ab1bcc0278131fc8073f03e72c4f1bad2b3b67161f312fa197d
Deleted: sha256:fb85b0e2235a3bce40a258b510173c3d4ae753fa6fa570ecc8092832657f28b4
Deleted: sha256:da7b660ac80db9931d90d2c7312e86c5e31c91b25b23cf7a007822c36614658e
# docker rmi testhttpd02
Untagged: testhttpd02:latest
Deleted: sha256:f1764c18d0fcdcb940c35566518f483ce2864dc3394bc2aec79f6162fd7934b5
# docker rmi testhttpd01
Untagged: testhttpd01:latest
Deleted: sha256:17de6194e75f6d68a9ab365b5c7b976646ef938aa8b788576cbedb0346bf3ffb
Deleted: sha256:e1e6bd9412124c49400db4e852fed360a62e03be8652b7d23083b7aeb1c2d697
Deleted: sha256:f19d5718d851e18cd24667f8d0a21e21f57494ac162c3f583ab9235e91cdfc00
# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
httpd        latest    dabbfbe0c57b   12 months ago   144MB
httpd        v8.1      dabbfbe0c57b   12 months ago   144MB
# docker rmi dabbfbe0c57b -f
Untagged: httpd:latest
Untagged: httpd:v8.1
Untagged: httpd@sha256:0954cc1af252d824860b2c5dc0a10720af2b7a3d3435581ca788dff8480c7b32
Deleted: sha256:dabbfbe0c57b6e5cd4bc089818d3f664acfad496dc741c9a501e72d15e803b34
Deleted: sha256:0e16a5a61bcb4e6b2bb2d746c2d6789d6c0b66198208b831f74b52198d744189
Deleted: sha256:f79670638074ff7fd293e753c11ea2ca0a2d92ab516d2f6b0bac3f4c6fed5d86
Deleted: sha256:189d55cdd18e4501032bb700a511c2d69c82fd75f1b619b5218ea6870e71e4aa
Deleted: sha256:cb038ed3e490a8c0f195cf135ac0d27dd8d3872598b1cb858c2666f2dae95a61

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
```

#### 2.4.搭建私有仓库
```
仓库分两类：
--- 公有镜像仓库：hub.docker.com  quay.io
--- 私有镜像仓库：docker registry  harbor
```
##### 2.4.1.搭建私有仓库docker registry
```bash
$ sudo -i
# mkdir /root/myregistry

# docker run -d -p 1000:5000 -v /root/myregistry:/var/lib/registry --restart always registry
Unable to find image 'registry:latest' locally
latest: Pulling from library/registry
79e9f2f55bf5: Pull complete 
0d96da54f60b: Pull complete 
5b27040df4a2: Pull complete 
e2ead8259a04: Pull complete 
3790aef225b9: Pull complete 
Digest: sha256:169211e20e2f2d5d115674681eb79d21a217b296b43374b8e39f97fcf866b375
Status: Downloaded newer image for registry:latest
f50ba994cd98200ee7afbf389063fd8d868bbc453d872e59e667e5173b61efed
# docker ps
CONTAINER ID   IMAGE        COMMAND                  CREATED          STATUS          PORTS                                       NAMES
f50ba994cd98   registry     "/entrypoint.sh /etc…"   40 seconds ago   Up 39 seconds   0.0.0.0:1000->5000/tcp, :::1000->5000/tcp   mystifying_allen
# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
hello        latest    e9055ad9d1d4   23 hours ago    141MB
registry     latest    b8604a3fe854   13 months ago   26.2MB

# vim /etc/docker/daemon.json 
# cat /etc/docker/daemon.json 
{
 "registry-mirrors": ["https://ktjk1d0g.mirror.aliyuncs.com"],
 "insecure-registries": ["192.168.1.240:1000"]
}

# systemctl daemon-reload
# systemctl restart docker

# docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
# docker ps -a
CONTAINER ID   IMAGE        COMMAND                  CREATED         STATUS                            PORTS     NAMES
f50ba994cd98   registry     "/entrypoint.sh /etc…"   6 minutes ago   Exited (2) 10 seconds ago                   mystifying_allen
# docker start mystifying_allen 
mystifying_allen
# docker ps
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS        PORTS                                       NAMES
f50ba994cd98   registry   "/entrypoint.sh /etc…"   6 minutes ago   Up 1 second   0.0.0.0:1000->5000/tcp, :::1000->5000/tcp   mystifying_allen

# docker tag hello:latest 192.168.1.240:1000/library/hello:v1.0
# docker push 192.168.1.240:1000/library/hello:v1.0
The push refers to repository [192.168.1.240:1000/library/hello]
f5a093ffdc14: Pushed 
d874fd2bc83b: Pushed 
32ce5f6a5106: Pushed 
f1db227348d0: Pushed 
b8d6e692a25e: Pushed 
e379e8aedd4d: Pushed 
2edcec3590a4: Pushed 
v1.0: digest: sha256:0dac7c6943143d8122ee23e04aeb7757d46ce8b7392cb86143b0f45c937516a4 size: 1778


# docker images
REPOSITORY                         TAG       IMAGE ID       CREATED         SIZE
192.168.1.240:1000/library/hello   v1.0      e9055ad9d1d4   23 hours ago    141MB
hello                              latest    e9055ad9d1d4   23 hours ago    141MB
registry                           latest    b8604a3fe854   13 months ago   26.2MB

# docker image inspect registry:latest 
[
    {
        "Id": "sha256:b8604a3fe8543c9e6afc29550de05b36cd162a97aa9b2833864ea8a5be11f3e2",
        "RepoTags": [
            "registry:latest"
        ],
       ...................
       "ContainerConfig": {
            "Image": "sha256:0d072f831f2a6137443ac3a59c3814d19d84047afdf81ccc8ddb3b41930c2fcd",
            "Volumes": {
                "/var/lib/registry": {}
       .................省略部分.............
       "Config": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "ExposedPorts": {
                "5000/tcp": {}
            },
       .................省略部分.............
       
## ss -anutlp|grep 1000       

# curl -v  http://localhost:1000
*   Trying 127.0.0.1:1000...
* Connected to localhost (127.0.0.1) port 1000 (#0)
> GET / HTTP/1.1
> Host: localhost:1000
> User-Agent: curl/7.81.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< `HTTP/1.1 200 OK`
< Cache-Control: no-cache
< Date: Fri, 16 Dec 2022 06:26:32 GMT
< Content-Length: 0
< 
* Connection #0 to host localhost left intact

# netstat -tnulp|grep :1000
Command 'netstat' not found, but can be installed with:
apt install net-tools

# apt install net-tools

# netstat -tnulp|grep :1000
tcp        0      0 0.0.0.0:1000            0.0.0.0:*               LISTEN      946289/docker-proxy 
tcp6       0      0 :::1000                 :::*                    LISTEN      946294/docker-proxy 

# cd /root/myregistry/docker/registry/v2/repositories/library/hello/
# ls
_layers  _manifests  _uploads
# cd _layers/sha256
# ls
186b1aaa4aa6c480e92fbd982ee7c08037ef85114fbed73dbb62503f24c1dd7d  a0bcbecc962ed2552e817f45127ffb3d14be31642ef3548997f58ae054deb5b2  b4df32aa5a72e2a4316aad3414508ccd907d87b4ad177abd7cbd62fa4dab2a2f
1b2e261a0dfcaecfea4545b6fbf4fa1dd1cc44f99aafe46c711ee243539f54e1  a2abf6c4d29d43a4bf9fbb769f524d0fb36a2edab49819c1bf3e76f409f953ea  e9055ad9d1d497508cfefc2e77fcb944af9e993992d23bec6751588b3b2d6b4e
589b7251471a3d5fe4daccdddfefa02bdc32ffcba0a6d6a2768bf2c401faf115  a9edb18cadd1336142d6567ebee31be2a03c0905eeefe26cb150de7b0fbc520b

# docker images
REPOSITORY                         TAG       IMAGE ID       CREATED         SIZE
192.168.1.240:1000/library/hello   v1.0      e9055ad9d1d4   23 hours ago    141MB
hello                              latest    e9055ad9d1d4   23 hours ago    141MB
registry                           latest    b8604a3fe854   13 months ago   26.2MB

# docker rmi 192.168.1.240:1000/library/hello:v1.0

# docker images
REPOSITORY                         TAG       IMAGE ID       CREATED         SIZE
hello                              latest    e9055ad9d1d4   23 hours ago    141MB
registry                           latest    b8604a3fe854   13 months ago   26.2MB

# docker pull 192.168.1.240:1000/library/hello:v1.0
v1.0: Pulling from library/hello
Digest: sha256:0dac7c6943143d8122ee23e04aeb7757d46ce8b7392cb86143b0f45c937516a4
Status: Downloaded newer image for 192.168.1.240:1000/library/hello:v1.0
192.168.1.240:1000/library/hello:v1.0

# docker images
REPOSITORY                         TAG       IMAGE ID       CREATED         SIZE
192.168.1.240:1000/library/hello   v1.0      e9055ad9d1d4   23 hours ago    141MB
hello                              latest    e9055ad9d1d4   23 hours ago    141MB
registry                           latest    b8604a3fe854   13 months ago   26.2MB


如果不设置/etc/docker/daemon.json，那么会报https错误
# cat /etc/docker/daemon.json 
{
 "registry-mirrors": ["https://ktjk1d0g.mirror.aliyuncs.com"]
}

# docker images
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
hello        latest    e9055ad9d1d4   23 hours ago    141MB
nginx        latest    605c77e624dd   11 months ago   141MB
registry     latest    b8604a3fe854   13 months ago   26.2MB

# docker tag nginx:latest 192.168.1.240:1000/library/nginx:v10.0

# docker push 192.168.1.240:1000/library/nginx:v10.0
The push refers to repository [192.168.1.240:1000/library/nginx]
Get "https://192.168.1.240:1000/v2/": http: server gave HTTP response to HTTPS client

# echo $?
1

私有仓库registry可视化：
# docker run -d -p 1000:5000 -v /root/myregistry:/var/lib/registry --restart always --name registry registry
# docker ps
CONTAINER ID   IMAGE      COMMAND                  CREATED             STATUS          PORTS                                       NAMES
f50ba994cd98   registry   "/entrypoint.sh /etc…"   About an hour ago   Up 29 minutes   0.0.0.0:1000->5000/tcp, :::1000->5000/tcp   mystifying_allen

# docker run -it -p 8080:8080 --name registry-web --link mystifying_allen -e REGISTRY_URL=http://mystifying_allen:5000/v2 -e REGISTRY_NAME=localhost:1000 hyper/docker-registry-web 
Unable to find image 'hyper/docker-registry-web:latest' locally
latest: Pulling from hyper/docker-registry-web
04c996abc244: Pull complete 
d394d3da86fe: Pull complete 
bac77aae22d4: Pull complete 
b48b86b78e97: Pull complete 
09b3dd842bf5: Pull complete 
69f4c5394729: Pull complete 
b012980650e9: Pull complete 
7c7921c6fda1: Pull complete 
e20331c175ea: Pull complete 
40d5e82892a5: Pull complete 
a414fa9c865a: Pull complete 
0304ae3409f3: Pull complete 
13effc1a664f: Pull complete 
e5628d0e6f8c: Pull complete 
0b0e130a3a52: Pull complete 
d0c73ab65cd2: Pull complete 
240c0b145309: Pull complete 
f1fd6f874e5e: Pull complete 
40b5e021928e: Pull complete 
88a8c7267fbc: Pull complete 
f9371a03010e: Pull complete 
Digest: sha256:723ffa29aed2c51417d8bd32ac93a1cd0e7ef857a0099c1e1d7593c09f7910ae
Status: Downloaded newer image for hyper/docker-registry-web:latest
CATALINA_OPTS: -Djava.security.egd=file:/dev/./urandom -Dcontext.path=
Using CATALINA_BASE:   /var/lib/tomcat7
Using CATALINA_HOME:   /usr/share/tomcat7
Using CATALINA_TMPDIR: /var/lib/tomcat7/temp
Using JRE_HOME:        /usr/lib/jvm/java-7-openjdk-amd64
Using CLASSPATH:       /usr/share/tomcat7/bin/bootstrap.jar:/usr/share/tomcat7/bin/tomcat-juli.jar
Dec 16, 2022 7:25:42 AM org.apache.coyote.AbstractProtocol init
INFO: Initializing ProtocolHandler ["http-bio-8080"]
Dec 16, 2022 7:25:42 AM org.apache.catalina.startup.Catalina load
INFO: Initialization processed in 997 ms
Dec 16, 2022 7:25:42 AM org.apache.catalina.core.StandardService startInternal
INFO: Starting service Catalina
Dec 16, 2022 7:25:42 AM org.apache.catalina.core.StandardEngine startInternal
INFO: Starting Servlet Engine: Apache Tomcat/7.0.52 (Ubuntu)

2022-12-16 07:26:12,128 [localhost-startStop-1] INFO  hibernate4.HibernatePluginSupport  - Set db generation strategy to 'update' for datasource DEFAULT

Configuring Spring Security Core ...
... finished configuring Spring Security Core

2022-12-16 07:26:13,679 [localhost-startStop-1] INFO  cache.CacheBeanPostProcessor  - postProcessBeanDefinitionRegistry start
2022-12-16 07:26:13,693 [localhost-startStop-1] INFO  cache.CacheBeanPostProcessor  - postProcessBeanFactory
2022-12-16 07:26:15,675 [localhost-startStop-1] WARN  config.ConfigurationFactory  - No configuration found. Configuring ehcache from ehcache-failsafe.xml  found in the classpath: jar:file:/var/lib/tomcat7/webapps/ROOT/WEB-INF/lib/ehcache-2.9.0.jar!/ehcache-failsafe.xml
2022-12-16 07:26:17,240 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: access_control
2022-12-16 07:26:17,250 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: event
2022-12-16 07:26:17,252 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: role
2022-12-16 07:26:17,254 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: role_access
2022-12-16 07:26:17,256 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: user
2022-12-16 07:26:17,257 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: user_role
2022-12-16 07:26:17,265 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: access_control
2022-12-16 07:26:17,267 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: event
2022-12-16 07:26:17,268 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: role
2022-12-16 07:26:17,271 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: role_access
2022-12-16 07:26:17,273 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: user
2022-12-16 07:26:17,275 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: user_role
2022-12-16 07:26:17,281 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: access_control
2022-12-16 07:26:17,282 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: event
2022-12-16 07:26:17,283 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: role
2022-12-16 07:26:17,289 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: role_access
2022-12-16 07:26:17,291 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: user
2022-12-16 07:26:17,292 [localhost-startStop-1] INFO  sql.DatabaseMetaData  - HHH000262: Table not found: user_role
2022-12-16 07:26:17,849 [localhost-startStop-1] INFO  ehcache.GrailsEhCacheManagerFactoryBean  - Initializing EHCache CacheManager
2022-12-16 07:26:21,825 [localhost-startStop-1] WARN  web.TokenService  - Authorization disabled

2022-12-16 07:26:26,626 [localhost-startStop-1] INFO  filter.AnnotationSizeOfFilter  - Using regular expression provided through VM argument net.sf.ehcache.pool.sizeof.ignore.pattern for IgnoreSizeOf annotation : ^.*cache\..*IgnoreSizeOf$
2022-12-16 07:26:26,638 [localhost-startStop-1] INFO  sizeof.AgentLoader  - Located valid 'tools.jar' at '/usr/lib/jvm/java-7-openjdk-amd64/jre/../lib/tools.jar'
2022-12-16 07:26:26,650 [localhost-startStop-1] INFO  sizeof.JvmInformation  - Detected JVM data model settings of: 64-Bit OpenJDK JVM with Compressed OOPs
2022-12-16 07:26:26,894 [localhost-startStop-1] INFO  sizeof.AgentLoader  - Extracted agent jar to temporary file /var/lib/tomcat7/temp/ehcache-sizeof-agent1842321385303346490.jar
2022-12-16 07:26:26,895 [localhost-startStop-1] INFO  sizeof.AgentLoader  - Trying to load agent @ /var/lib/tomcat7/temp/ehcache-sizeof-agent1842321385303346490.jar
2022-12-16 07:26:26,901 [localhost-startStop-1] INFO  impl.DefaultSizeOfEngine  - using Agent sizeof engine
2022-12-16 07:26:26,953 [localhost-startStop-1] INFO  impl.DefaultSizeOfEngine  - using Agent sizeof engine
2022-12-16 07:26:27,010 [localhost-startStop-1] INFO  context.GrailsConfigUtils  - [GrailsContextLoader] Grails application loaded.
2022-12-16 07:26:27,090 [localhost-startStop-1] INFO  conf.BootStrap  - Starting registry-web ver. 0.1.3-SNAPSHOT-bededf47611365f0a6d2bb87942e3b86c1e92d9f
2022-12-16 07:26:27,173 [localhost-startStop-1] INFO  web.ConfigService  - [environmentProperties, localProperties]
2022-12-16 07:26:27,184 [localhost-startStop-1] INFO  web.ConfigService  - resolved config:
2022-12-16 07:26:27,188 [localhost-startStop-1] INFO  web.ConfigService  - registry.url: http://mystifying_allen:5000/v2
2022-12-16 07:26:27,189 [localhost-startStop-1] INFO  web.ConfigService  - registry.auth.key: /config/auth.key
2022-12-16 07:26:27,190 [localhost-startStop-1] INFO  web.ConfigService  - registry.readonly: true
2022-12-16 07:26:27,196 [localhost-startStop-1] INFO  web.ConfigService  - registry.trust_any_ssl: false
2022-12-16 07:26:27,197 [localhost-startStop-1] INFO  web.ConfigService  - registry.basic_auth: 
2022-12-16 07:26:27,198 [localhost-startStop-1] INFO  web.ConfigService  - registry.auth.enabled: false
2022-12-16 07:26:27,198 [localhost-startStop-1] INFO  web.ConfigService  - registry.context_path: 
2022-12-16 07:26:27,199 [localhost-startStop-1] INFO  web.ConfigService  - registry.auth.issuer: test-issuer
2022-12-16 07:26:27,200 [localhost-startStop-1] INFO  web.ConfigService  - registry.name: localhost:1000
2022-12-16 07:26:27,203 [localhost-startStop-1] INFO  conf.BootStrap  - auth enabled: false
Dec 16, 2022 7:26:27 AM org.apache.coyote.AbstractProtocol start
INFO: Starting ProtocolHandler ["http-bio-8080"]
Dec 16, 2022 7:26:27 AM org.apache.catalina.startup.Catalina start
INFO: Server startup in 45453 ms


# docker ps
CONTAINER ID   IMAGE                       COMMAND                  CREATED             STATUS          PORTS                                       NAMES
f4ae4764efa8   hyper/docker-registry-web   "start.sh"               11 minutes ago      Up 11 minutes   0.0.0.0:8080->8080/tcp, :::8080->8080/tcp   registry-web
f50ba994cd98   registry                    "/entrypoint.sh /etc…"   About an hour ago   Up 43 minutes   0.0.0.0:1000->5000/tcp, :::1000->5000/tcp   mystifying_allen
```



![image-20221216152930360](cka培训截图\image-20221216152930360.png)

```bash
registry删除镜像
# cd /root/myregistry/docker/registry/v2/repositories/library
# ls
hello  nginx
# rm -rfv hello/

# docker ps
CONTAINER ID   IMAGE                       COMMAND                  CREATED          STATUS          PORTS                                       NAMES
f50ba994cd98   registry                    "/entrypoint.sh /etc…"   2 hours ago      Up 2 hours      0.0.0.0:1000->5000/tcp, :::1000->5000/tcp   mystifying_allen

# docker exec mystifying_allen bin/registry garbage-collect /etc/docker/registry/config.yml
```

![image-20221216162710489](cka培训截图\image-20221216162710489.png)

##### 2.4.2.搭建私有仓库harbor

###### 2.4.2.1.生成root证书信息

```bash
openssl genrsa -out /etc/ssl/private/selfsignroot.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=Root" \
-key /etc/ssl/private/selfsignroot.key \
-out /usr/local/share/ca-certificates/selfsignroot.crt

```

###### 2.4.2.2.生成服务器私钥以及证书请求文件

```bash
openssl genrsa -out /etc/ssl/private/registry.key 4096
openssl req -sha512 -new \
-subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=xiaohui.cn" \
-key /etc/ssl/private/registry.key \
-out registry.csr

```

###### 2.4.2.3.生成openssl cnf扩展文件

```bash
cat > certs.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = registry.xiaohui.cn
EOF

```

###### 2.4.2.4.签发证书

```bash
openssl x509 -req -in registry.csr \
-CA /usr/local/share/ca-certificates/selfsignroot.crt \
-CAkey /etc/ssl/private/selfsignroot.key -CAcreateserial \
-out /etc/ssl/certs/registry.crt \
-days 3650 -extensions v3_req -extfile certs.cnf

```

###### 2.4.2.5.信任根证书

```bash
update-ca-certificates
```

###### 2.4.2.6.部署Harbor仓库

先部署Docker CE

```bash
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://mirror.nju.edu.cn/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirror.nju.edu.cn/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

```

再添加Docker 镜像加速器，这里只限在国内部署时才需要加速，在国外这样加速反而缓慢

```bash

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
EOF

```
添加Compose支持，并启动Docker服务

```bash
curl -L "https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.13.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
sudo systemctl daemon-reload
sudo systemctl restart docker

```

```bash
wget https://ghproxy.com/https://github.com/goharbor/harbor/releases/download/v1.10.15/harbor-offline-installer-v1.10.15.tgz

wget https://ghproxy.com/https://github.com/goharbor/harbor/releases/download/v2.6.3/harbor-offline-installer-v2.6.3.tgz

tar xf harbor-offline-installer-v1.10.15.tgz -C /usr/local/bin
cd /usr/local/bin/harbor
docker load -i harbor.v1.10.15.tar.gz

```

在harbor.yml中，修改以下参数，定义了网址、证书、密码

```bash
cp harbor.yml.tmpl harbor.yml

vim harbor.yml
# 修改hostname为registry.xiaohui.cn
# 修改https处的certificate为/etc/ssl/certs/registry.crt
# 修改https处的private_key为/etc/ssl/private/registry.key
# 修改harbor_admin_password为admin
```

```bash
./prepare
./install.sh
```

###### 2.4.2.7.生成服务文件

```bash
cat > /etc/systemd/system/harbor.service <<EOF
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor
[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/bin/docker-compose -f /usr/local/bin/harbor/docker-compose.yml up
ExecStop=/usr/local/bin/docker-compose -f /usr/local/bin/harbor/docker-compose.yml down
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
systemctl enable harbor --now
```



```bash
#centos的与ubuntu的有些区别：位置、依赖的服务等不同
cat > /usr/lib/systemd/system/harbor.service <<EOF
[Unit]
Description=Harbor
After=network-online.target firewalld.service docker.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor
[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/bin/docker-compose -f /root/harbor/docker-compose.yml up
ExecStop=/usr/local/bin/docker-compose -f /root/harbor/docker-compose.yml down
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable harbor --now
```



在所有的机器上，将registry.xiaohui.cn以及其对应的IP添加到/etc/hosts，然后将上述实验中的httpd:v1镜像，改名为带上IP:PORT形式，尝试上传我们的镜像到本地仓库

```bash
docker login registry.xiaohui.cn
docker tag httpd:v1 registry.xiaohui.cn/library/httpd:v1
docker push registry.xiaohui.cn/library/httpd:v1
```


### 3.容器网络

#### 3.1.容器网络

```bash
docker native network drivers
docker提供了5中原生的网络驱动
```

|      | 模型    | 说明                                                         |
| ---- | ------- | ------------------------------------------------------------ |
| 1    | bridge  | 默认网络驱动程序。主要用于多个容器在同一个docker宿主机上进行通信 |
| 2    | host    | 容器加入到宿主机的network namespace，容器直接使用宿主机网络  |
| 3    | none    | none网络中的容器，不能与外部通信                             |
| 4    | Overlay | Overlay网络可基于Linux网桥和Vxlan，实现跨主机的容器通信      |
| 5    | Macvlan | Macvlan用于跨主机通信场景                                    |

```bash
# man docker run
/--network
```
```
--network=type
          Set the Network mode for the container. Supported values are:

       ┌────────────────────────┬───────────────────────────────────────────────────────────────┐
       │Value                   │ Description                                                   │
       ├────────────────────────┼───────────────────────────────────────────────────────────────┤
       │none                    │ No networking in the container.                               │
       ├────────────────────────┼───────────────────────────────────────────────────────────────┤
       │bridge                  │ Connect the container to the default Docker bridge  via  veth │
       │                        │ interfaces.                                                   │
       ├────────────────────────┼───────────────────────────────────────────────────────────────┤
       │host                    │ Use the host's network stack inside the container.            │
       ├────────────────────────┼───────────────────────────────────────────────────────────────┤
       │container:name|id       │ Use the network stack of another container, specified via its │
       │                        │ name or id.                                                   │
       ├────────────────────────┼───────────────────────────────────────────────────────────────┤
       │network-name|network-id │ Connects the container  to  a  user  created  network  (using │
       │                        │ docker network create command)                                │
       └────────────────────────┴───────────────────────────────────────────────────────────────┘
    
       Default is bridge.
       
       --network="bridge" : Connect a container to a network
                      'bridge': create a network stack on the default Docker bridge
                      'none': no networking
                      'container:<name|id>': reuse another container's network stack
                      'host': use the Docker host network stack
                      '<network-name>|<network-id>': connect to a user-defined network
```

```bash
docker安装时，自动在host上创建了如下3个网络：
# docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
6236b3d380dc   bridge    bridge    local
4d726e7f4251   host      host      local
b138d0f41e9b   none      null      local
```

|      |      none      |         host         |                   bridge                   |
| :--: | :------------: | :------------------: | :----------------------------------------: |
|  1   | container/`lo` | container == phsical | container/eth0-net1<br>container/eth1-net2 |
|  2   |                |                      |                                            |

```bash
默认bridge网络驱动：
# docker run -d --privileged -p 8088:80 httpdcentos /sbin/init
31ff339b9356f4452f377e4b34d67ff95219fa46910d6e9b309fdc89e6118f32
# docker ps
CONTAINER ID   IMAGE         COMMAND        CREATED         STATUS        PORTS                                   NAMES
31ff339b9356   httpdcentos   "/sbin/init"   2 seconds ago   Up 1 second   0.0.0.0:8088->80/tcp, :::8088->80/tcp   bold_bouman
# curl localhost:8088
haha

# docker exec -it bold_bouman /bin/bash
[root@31ff339b9356 /]# curl localhost
haha

none网络驱动：
# docker run -d --privileged --network=none -p 8089:80 httpdcentos /sbin/init
7ac110757eecbf8ce2a552ab2ba2a42059ab985470dd8b927baf4a20b7ee41c7
# docker ps
CONTAINER ID   IMAGE         COMMAND        CREATED         STATUS         PORTS                                   NAMES
7ac110757eec   httpdcentos   "/sbin/init"   2 seconds ago   Up 1 second                                            loving_beaver
31ff339b9356   httpdcentos   "/sbin/init"   2 minutes ago   Up 2 minutes   0.0.0.0:8088->80/tcp, :::8088->80/tcp   bold_bouman

# curl localhost:8089
curl: (7) Failed to connect to localhost port 8089 after 0 ms: Connection refused

# docker exec -it loving_beaver /bin/bash
[root@7ac110757eec /]# curl localhost
haha
[root@7ac110757eec /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever

host网络驱动：
# docker run -d --privileged --network=host -p 8090:80 httpdcentos /sbin/init
WARNING: Published ports are discarded when using host network mode
ffcca87fbf7720ae56bd3df71a44f3c6d0a8b0f4b5a55dc96083ceeef7f1905e
# docker ps
CONTAINER ID   IMAGE         COMMAND        CREATED          STATUS          PORTS                                   NAMES
ffcca87fbf77   httpdcentos   "/sbin/init"   45 seconds ago   Up 44 seconds                                           great_liskov
7ac110757eec   httpdcentos   "/sbin/init"   3 minutes ago    Up 3 minutes                                            loving_beaver
31ff339b9356   httpdcentos   "/sbin/init"   5 minutes ago    Up 5 minutes    0.0.0.0:8088->80/tcp, :::8088->80/tcp   bold_bouman

# curl localhost:8090
curl: (7) Failed to connect to localhost port 8090 after 0 ms: Connection refused
root@ubuntu001-virtual-machine:~# curl localhost
haha

# docker exec -it great_liskov /bin/bash
[root@ubuntu001-virtual-machine /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
124: veth897064e@if123: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether 6e:a5:9c:43:b8:9e brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::6ca5:9cff:fe43:b89e/64 scope link 
       valid_lft forever preferred_lft forever
[root@ubuntu001-virtual-machine /]# exit
exit

# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
124: veth897064e@if123: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether 6e:a5:9c:43:b8:9e brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::6ca5:9cff:fe43:b89e/64 scope link 
       valid_lft forever preferred_lft forever
```



#### 3.1.1.none网络

```bash
none网络的driver类型是null，IPAM字段为空
挂在none网络上的容器只有lo，无法与外界通信
# docker network inspect none
[
    {
        "Name": "none",
        "Id": "b138d0f41e9bf57d7809af2a7c96ca17b4b029455fbad52da74ebfe69beef524",
        "Created": "2022-12-13T18:08:44.904333584+08:00",
        "Scope": "local",
        `"Driver": "null"`,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            `"Config": []`
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]

# docker run -itd --network none centos
6a40a2d2a72d096e300aa053f2f130f6d860cd56834081b515f617b6381ac309
# docker ps
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS        PORTS                                       NAMES
6a40a2d2a72d   centos     "/bin/bash"              3 seconds ago   Up 1 second                                               laughing_williamson

# docker exec -it laughing_williamson /bin/bash
[root@6a40a2d2a72d /]# ifconfig
bash: ifconfig: command not found
[root@6a40a2d2a72d /]# ip a
1: `lo`: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever

[root@6a40a2d2a72d /]# ping localhost
PING localhost (127.0.0.1) 56(84) bytes of data.
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.028 ms
64 bytes from localhost (127.0.0.1): icmp_seq=2 ttl=64 time=0.033 ms
^C
--- localhost ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.028/0.030/0.033/0.006 ms
[root@6a40a2d2a72d /]# ping 8.8.8.8
connect: Network is unreachable
[root@6a40a2d2a72d /]# exit
exit

# docker inspect laughing_williamson 
...输出省略...
        "HostConfig": {
            "Binds": null,
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "json-file",
                "Config": {}
            },
            "NetworkMode": `"none"`,
            "PortBindings": {},
            "RestartPolicy": {
                "Name": "no",
                "MaximumRetryCount": 0
            },
        ...输出省略...
        "NetworkSettings": {
        ...输出省略...
            "Networks": {
                `"none"`: {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "b138d0f41e9bf57d7809af2a7c96ca17b4b029455fbad52da74ebfe69beef524",
                    "EndpointID": "14c636e55215df738f616d6b81c2b245906ed5a76cd99d4923fc2634b547f323",
                    "Gateway": "",
                    "IPAddress": "",
                    "IPPrefixLen": 0,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "",
                    "DriverOpts": null
                }
            }
...输出省略...



```
#### 3.1.2.host网络

```
挂在host网络上的容器共享宿主机的network namespace
即容器的网络配置与host网络配置完全一样
当docker run 两个容器都采用host网络时，监听端口不能一样，否则冲突，后面第二个容器的服务会异常
```

![image-20221217111121082](cka培训截图\image-20221217111121082.png)



```bash
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever

# docker run -itd --network host centos
eda0b197442386dc351ce145b540f76a02dfc65e88024152153a6494fe306d67
root@ubuntu001-virtual-machine:~# docker ps
CONTAINER ID   IMAGE     COMMAND       CREATED          STATUS          PORTS     NAMES
eda0b1974423   centos    "/bin/bash"   2 seconds ago    Up 1 second               practical_pasteur

# docker exec -it practical_pasteur /bin/bash
[root@ubuntu001-virtual-machine /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
[root@ubuntu001-virtual-machine /]# ping localhost -c 3
PING localhost (127.0.0.1) 56(84) bytes of data.
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.087 ms
64 bytes from localhost (127.0.0.1): icmp_seq=2 ttl=64 time=0.041 ms
64 bytes from localhost (127.0.0.1): icmp_seq=3 ttl=64 time=0.052 ms

--- localhost ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2027ms
rtt min/avg/max/mdev = 0.041/0.060/0.087/0.019 ms

[root@ubuntu001-virtual-machine /]# ping 8.8.8.8 -c 3
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=108 time=32.0 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=108 time=31.10 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=108 time=31.7 ms

--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2002ms
rtt min/avg/max/mdev = 31.737/31.908/32.012/0.190 ms
[root@ubuntu001-virtual-machine /]# ifconfig
bash: ifconfig: command not found
[root@ubuntu001-virtual-machine /]# exit
exit
# 

# docker run -itd --network host --name centosnew centos
d086e86e6cc868cb260bd8c51f06fd622ff8697604eb9e381365f40e0ac50412
root@ubuntu001-virtual-machine:~# docker ps
CONTAINER ID   IMAGE     COMMAND       CREATED          STATUS          PORTS     NAMES
d086e86e6cc8   centos    "/bin/bash"   2 seconds ago    Up 1 second               centosnew
eda0b1974423   centos    "/bin/bash"   15 minutes ago   Up 15 minutes             practical_pasteur

root@ubuntu001-virtual-machine:~# docker exec -it centosnew /bin/bash
[root@ubuntu001-virtual-machine /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
[root@ubuntu001-virtual-machine /]# ping localhost -c 3
PING localhost (127.0.0.1) 56(84) bytes of data.
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.087 ms
64 bytes from localhost (127.0.0.1): icmp_seq=2 ttl=64 time=0.041 ms
64 bytes from localhost (127.0.0.1): icmp_seq=3 ttl=64 time=0.052 ms

--- localhost ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2027ms
rtt min/avg/max/mdev = 0.041/0.060/0.087/0.019 ms
[root@ubuntu001-virtual-machine /]# ping 8.8.8.8 -c 3
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=108 time=32.1 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=108 time=31.10 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=108 time=31.7 ms

--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2002ms
rtt min/avg/max/mdev = 31.694/31.945/32.146/0.237 ms
[root@ubuntu001-virtual-machine /]# exit
#

# docker network inspect host
[
    {
        "Name": "host",
        "Id": "4d726e7f42510ee1a8d40233b35e819f1490418488a8b125a031790557a44026",
        "Created": "2022-12-13T18:08:44.919053249+08:00",
        "Scope": "local",
        "Driver": "host",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": []
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]

# docker inspect centosnew |grep -A 15 Networks
            "Networks": {
                `"host"`: {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "4d726e7f42510ee1a8d40233b35e819f1490418488a8b125a031790557a44026",
                    "EndpointID": "9e8d76f15ae9a7b4ed6911cc8e4779014687810de46a066c554d445b285a1085",
                    "Gateway": "",
                    "IPAddress": "",
                    "IPPrefixLen": 0,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "",
                    "DriverOpts": null
                }
```

#### 3.1.3.bridge网络

```
docker0网络
---容器创建时，默认挂载在docker0上
---docker0是一个linux bridge
---docker0网络创建时已默认配置了Subnet
```

![image-20230206211608368](cka培训截图/image-20230206211608368.png)



```bash
# docker run -d --privileged -p 8088:80 httpdcentos /sbin/init
31ff339b9356f4452f377e4b34d67ff95219fa46910d6e9b309fdc89e6118f32
# docker ps
CONTAINER ID   IMAGE         COMMAND        CREATED        STATUS              PORTS                                   NAMES
31ff339b9356   httpdcentos   "/sbin/init"   34 hours ago   Up About a minute   0.0.0.0:8088->80/tcp, :::8088->80/tcp   bold_bouman

# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
128: vethf44d9fa@if127: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether 5a:86:a3:9f:ed:2e brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::5886:a3ff:fe9f:ed2e/64 scope link 
       valid_lft forever preferred_lft forever

# docker exec -it bold_bouman  /bin/bash
[root@31ff339b9356 /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
127: eth0@if128: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
       
# docker network inspect bridge
[
    {
        "Name": "bridge",
        "Id": "6236b3d380dcd135aec85b1be1c033b2bf08bcd9b140b61009a6c317eb79d469",
        "Created": "2022-12-16T14:53:31.345859172+08:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "31ff339b9356f4452f377e4b34d67ff95219fa46910d6e9b309fdc89e6118f32": {
                "Name": "bold_bouman",
                "EndpointID": "9cc65c90c85e96c4b0ae91b6476f291413d2a5a0835638111bc18f3501b0d2c9",
                "MacAddress": "02:42:ac:11:00:02",
                "IPv4Address": "172.17.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]


# docker inspect bold_bouman |grep -A 15 Networks
            "Networks": {
                "bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "6236b3d380dcd135aec85b1be1c033b2bf08bcd9b140b61009a6c317eb79d469",
                    "EndpointID": "9cc65c90c85e96c4b0ae91b6476f291413d2a5a0835638111bc18f3501b0d2c9",
                    "Gateway": "172.17.0.1",
                    "IPAddress": "172.17.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:11:00:02",
                    "DriverOpts": null
                }
                
docker run 第二个容器：
# docker run -d -p 8092:80 nginx
ad90470fa726dff4b09e53bd6d6a77af5d6314abdc67aab2060d15479bf2d14f
# docker ps
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS         PORTS                                   NAMES
ad90470fa726   nginx         "/docker-entrypoint.…"   4 seconds ago   Up 2 seconds   0.0.0.0:8092->80/tcp, :::8092->80/tcp   sleepy_bhaskara
31ff339b9356   httpdcentos   "/sbin/init"             34 hours ago    Up 7 minutes   0.0.0.0:8088->80/tcp, :::8088->80/tcp   bold_bouman

# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
128: vethf44d9fa@if127: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether 5a:86:a3:9f:ed:2e brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::5886:a3ff:fe9f:ed2e/64 scope link 
       valid_lft forever preferred_lft forever
130: vethf942135@if129: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether b2:1e:41:62:1a:01 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::b01e:41ff:fe62:1a01/64 scope link 
       valid_lft forever preferred_lft forever

# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.1.1     0.0.0.0         UG    100    0        0 ens160
169.254.0.0     0.0.0.0         255.255.0.0     U     1000   0        0 ens160
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.1.0     0.0.0.0         255.255.255.0   U     100    0        0 ens160

# docker inspect sleepy_bhaskara |grep -A 15 Networks
            "Networks": {
                "bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "6236b3d380dcd135aec85b1be1c033b2bf08bcd9b140b61009a6c317eb79d469",
                    "EndpointID": "34c2bf3ac825b9012ebe54df24734bf5684caab361baa9f168e21e7daa8c5c4f",
                    "Gateway": "172.17.0.1",
                    "IPAddress": "172.17.0.3",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:11:00:03",
                    "DriverOpts": null
                }
# docker network inspect bridge
[
    {
        "Name": "bridge",
        "Id": "6236b3d380dcd135aec85b1be1c033b2bf08bcd9b140b61009a6c317eb79d469",
        "Created": "2022-12-16T14:53:31.345859172+08:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "31ff339b9356f4452f377e4b34d67ff95219fa46910d6e9b309fdc89e6118f32": {
                "Name": "bold_bouman",
                "EndpointID": "9cc65c90c85e96c4b0ae91b6476f291413d2a5a0835638111bc18f3501b0d2c9",
                "MacAddress": "02:42:ac:11:00:02",
                "IPv4Address": "172.17.0.2/16",
                "IPv6Address": ""
            },
            "ad90470fa726dff4b09e53bd6d6a77af5d6314abdc67aab2060d15479bf2d14f": {
                "Name": "sleepy_bhaskara",
                "EndpointID": "34c2bf3ac825b9012ebe54df24734bf5684caab361baa9f168e21e7daa8c5c4f",
                "MacAddress": "02:42:ac:11:00:03",
                "IPv4Address": "172.17.0.3/16",
                "IPv6Address": ""
            }
        },
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]
```

#### 3.1.3.1.user-defined Bridge网络
```
用户可按需创建bridge网桥，成为user-defined bridge
```



![image-20230206214842408](cka培训截图/image-20230206214842408.png)



```bash
创建第一个网桥：
# docker network create --driver bridge net1
8a47db528c58e1c2ec3f299030e8d4dbf5658ebdad33d199533ff32c5202a9c5
# docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
6236b3d380dc   bridge    bridge    local
4d726e7f4251   host      host      local
8a47db528c58   net1      bridge    local
b138d0f41e9b   none      null      local

# docker network inspect net1
[
    {
        "Name": "net1",
        "Id": "8a47db528c58e1c2ec3f299030e8d4dbf5658ebdad33d199533ff32c5202a9c5",
        "Created": "2023-02-06T21:52:30.419641306+08:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "172.19.0.0/16",
                    "Gateway": "172.19.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]

创建第二个网桥：
# docker network create --driver=bridge --subnet=172.20.0.0/24 --gateway=172.20.0.1 net2
b8087febf61e639f27fd9cf5fb57c8c583f991bc84e39c38243ed058f8496e25
# docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
6236b3d380dc   bridge    bridge    local
4d726e7f4251   host      host      local
8a47db528c58   net1      bridge    local
b8087febf61e   net2      bridge    local
b138d0f41e9b   none      null      local

# docker inspect net2
[
    {
        "Name": "net2",
        "Id": "b8087febf61e639f27fd9cf5fb57c8c583f991bc84e39c38243ed058f8496e25",
        "Created": "2023-02-06T21:58:16.432573175+08:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "172.20.0.0/24",
                    "Gateway": "172.20.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]


启动3个centos容器，分别命名为c1、c2、c3
其中c1加入到net1，c2加入到net2，c3加入net2并配置静态IP

# docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES

# docker run -itd --network=net1 --name=c1 centos
496d4ddad025a9c624a5cc5741e944cfb3cb3441cbe4115a1c1689b593b64fe4

# docker run -itd --network=net2 --name=c2 centos
f4dc0cf34db6ffeb9b4ea8fa5a9bfc4934d265ac587b0156ba019cc09323f927

# docker run -itd --network=net2 --name=c3 --ip=172.20.0.100 centos
94e0bc6720f311d9bfbfb7ec63dbd08847b516bb3cd4d5fcd97d0ca3451602fc

# docker ps
CONTAINER ID   IMAGE     COMMAND       CREATED              STATUS              PORTS     NAMES
94e0bc6720f3   centos    "/bin/bash"   48 seconds ago       Up 46 seconds                 c3
f4dc0cf34db6   centos    "/bin/bash"   About a minute ago   Up About a minute             c2
496d4ddad025   centos    "/bin/bash"   About a minute ago   Up About a minute             c1

# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
131: br-8a47db528c58: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:8e:76:7a:26 brd ff:ff:ff:ff:ff:ff
    inet 172.19.0.1/16 brd 172.19.255.255 scope global br-8a47db528c58
       valid_lft forever preferred_lft forever
    inet6 fe80::42:8eff:fe76:7a26/64 scope link 
       valid_lft forever preferred_lft forever
132: br-b8087febf61e: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:cc:85:2d:2f brd ff:ff:ff:ff:ff:ff
    inet 172.20.0.1/24 brd 172.20.0.255 scope global br-b8087febf61e
       valid_lft forever preferred_lft forever
    inet6 fe80::42:ccff:fe85:2d2f/64 scope link 
       valid_lft forever preferred_lft forever
140: vethf6fae61@if139: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-8a47db528c58 state UP group default 
    link/ether 8a:8c:16:32:67:66 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::888c:16ff:fe32:6766/64 scope link 
       valid_lft forever preferred_lft forever
142: vethb90b0d4@if141: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-b8087febf61e state UP group default 
    link/ether d6:ab:98:43:2c:8b brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::d4ab:98ff:fe43:2c8b/64 scope link 
       valid_lft forever preferred_lft forever
144: veth6461145@if143: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-b8087febf61e state UP group default 
    link/ether ba:6c:88:2f:4b:b5 brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::b86c:88ff:fe2f:4bb5/64 scope link 
       valid_lft forever preferred_lft forever

# docker ps
CONTAINER ID   IMAGE     COMMAND       CREATED          STATUS          PORTS     NAMES
94e0bc6720f3   centos    "/bin/bash"   37 minutes ago   Up 37 minutes             c3
f4dc0cf34db6   centos    "/bin/bash"   38 minutes ago   Up 38 minutes             c2
496d4ddad025   centos    "/bin/bash"   38 minutes ago   Up 38 minutes             c1

查看容器IP地址：
# docker inspect c1 |grep -A 15 Networks
            "Networks": {
                "net1": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": [
                        "496d4ddad025"
                    ],
                    "NetworkID": "8a47db528c58e1c2ec3f299030e8d4dbf5658ebdad33d199533ff32c5202a9c5",
                    "EndpointID": "61d79767658364f19da6591f339b2180ab07653472b90837ed6c215fc0ecb371",
                    "Gateway": "172.19.0.1",
                    "IPAddress": "172.19.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:13:00:02",
# docker inspect c2 |grep -A 15 Networks
            "Networks": {
                "net2": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": [
                        "f4dc0cf34db6"
                    ],
                    "NetworkID": "b8087febf61e639f27fd9cf5fb57c8c583f991bc84e39c38243ed058f8496e25",
                    "EndpointID": "d1b73acbbf484f6f7ec4a63b054ae74cc123b23ca6555f15990c8f161a7b8288",
                    "Gateway": "172.20.0.1",
                    "IPAddress": "172.20.0.2",
                    "IPPrefixLen": 24,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:14:00:02",
# docker inspect c3 |grep -A 15 Networks
            "Networks": {
                "net2": {
                    "IPAMConfig": {
                        "IPv4Address": "172.20.0.100"
                    },
                    "Links": null,
                    "Aliases": [
                        "94e0bc6720f3"
                    ],
                    "NetworkID": "b8087febf61e639f27fd9cf5fb57c8c583f991bc84e39c38243ed058f8496e25",
                    "EndpointID": "4ff7ab19f2dbc0682c0c8487be5e60b059ed2a31139d6de34ff904aa1f3554c3",
                    "Gateway": "172.20.0.1",
                    "IPAddress": "172.20.0.100",
                    "IPPrefixLen": 24,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",

容器的IP必须在子网范围内，不然会报错：
# docker run -itd --name=c4 --network=net2 --ip=172.21.0.101 centos
32f6fd999f2b96345d665d1a7b35d64d5b2a320b6279107aefe7bef0b4ff4866
docker: Error response from daemon: Invalid address 172.21.0.101: It does not belong to any of this network's subnets.

# docker ps -a|grep c4
32f6fd999f2b   centos        "/bin/bash"              About a minute ago   Created    c4 



# docker inspect c1 |grep -i ipaddress
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.19.0.2",
# docker inspect c2 |grep -i ipaddress
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.20.0.2",
# docker inspect c3 |grep -i ipaddress
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.20.0.100",

容器c2与c3在同一个子网，可以相互通信，与c1不在一个子网，不能相互通信
# docker exec -it c1 ping -c 3 172.20.0.2
PING 172.20.0.2 (172.20.0.2) 56(84) bytes of data.
^C
--- 172.20.0.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2027ms

# docker exec -it c3 ping -c 3 172.20.0.2
PING 172.20.0.2 (172.20.0.2) 56(84) bytes of data.
64 bytes from 172.20.0.2: icmp_seq=1 ttl=64 time=0.101 ms
64 bytes from 172.20.0.2: icmp_seq=2 ttl=64 time=0.072 ms
64 bytes from 172.20.0.2: icmp_seq=3 ttl=64 time=0.071 ms

--- 172.20.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2037ms
rtt min/avg/max/mdev = 0.071/0.081/0.101/0.015 ms
# docker exec -it c2 ping -c 3 172.20.0.100
PING 172.20.0.100 (172.20.0.100) 56(84) bytes of data.
64 bytes from 172.20.0.100: icmp_seq=1 ttl=64 time=0.072 ms
64 bytes from 172.20.0.100: icmp_seq=2 ttl=64 time=0.103 ms
64 bytes from 172.20.0.100: icmp_seq=3 ttl=64 time=0.088 ms

--- 172.20.0.100 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2055ms
rtt min/avg/max/mdev = 0.072/0.087/0.103/0.016 ms

# docker exec -it c2 ping -c3 172.19.0.2
PING 172.19.0.2 (172.19.0.2) 56(84) bytes of data.
^C
--- 172.19.0.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2025ms

想要c1与c2或c3相互通信，可以为c1添加一块网卡，加入到net2网络
# docker network connect net2 c1

# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:b6:9b:17 brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 192.168.1.240/24 brd 192.168.1.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:96:88:d3:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:96ff:fe88:d321/64 scope link 
       valid_lft forever preferred_lft forever
131: br-8a47db528c58: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:8e:76:7a:26 brd ff:ff:ff:ff:ff:ff
    inet 172.19.0.1/16 brd 172.19.255.255 scope global br-8a47db528c58
       valid_lft forever preferred_lft forever
    inet6 fe80::42:8eff:fe76:7a26/64 scope link 
       valid_lft forever preferred_lft forever
132: br-b8087febf61e: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:cc:85:2d:2f brd ff:ff:ff:ff:ff:ff
    inet 172.20.0.1/24 brd 172.20.0.255 scope global br-b8087febf61e
       valid_lft forever preferred_lft forever
    inet6 fe80::42:ccff:fe85:2d2f/64 scope link 
       valid_lft forever preferred_lft forever
140: vethf6fae61@if139: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-8a47db528c58 state UP group default 
    link/ether 8a:8c:16:32:67:66 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::888c:16ff:fe32:6766/64 scope link 
       valid_lft forever preferred_lft forever
142: vethb90b0d4@if141: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-b8087febf61e state UP group default 
    link/ether d6:ab:98:43:2c:8b brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::d4ab:98ff:fe43:2c8b/64 scope link 
       valid_lft forever preferred_lft forever
144: veth6461145@if143: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-b8087febf61e state UP group default 
    link/ether ba:6c:88:2f:4b:b5 brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::b86c:88ff:fe2f:4bb5/64 scope link 
       valid_lft forever preferred_lft forever
146: veth7a1ad65@if145: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-b8087febf61e state UP group default 
    link/ether ba:f0:06:a8:e6:14 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::b8f0:6ff:fea8:e614/64 scope link 
       valid_lft forever preferred_lft forever

# docker inspect c1|grep -i ipaddr
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.19.0.2",
                    "IPAddress": "172.20.0.3",
# docker inspect c2|grep -i ipaddr
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.20.0.2",
# docker inspect c3|grep -i ipaddr
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.20.0.100",
                    
# docker exec -it c1 ping -c 2 172.20.0.2
PING 172.20.0.2 (172.20.0.2) 56(84) bytes of data.
64 bytes from 172.20.0.2: icmp_seq=1 ttl=64 time=0.135 ms
64 bytes from 172.20.0.2: icmp_seq=2 ttl=64 time=0.078 ms

--- 172.20.0.2 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 0.078/0.106/0.135/0.030 ms
# docker exec -it c1 ping -c 2 172.20.0.100
PING 172.20.0.100 (172.20.0.100) 56(84) bytes of data.
64 bytes from 172.20.0.100: icmp_seq=1 ttl=64 time=0.128 ms
64 bytes from 172.20.0.100: icmp_seq=2 ttl=64 time=0.080 ms

--- 172.20.0.100 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1003ms
rtt min/avg/max/mdev = 0.080/0.104/0.128/0.024 ms
# docker exec -it c2 ping -c 2 172.20.0.3
PING 172.20.0.3 (172.20.0.3) 56(84) bytes of data.
64 bytes from 172.20.0.3: icmp_seq=1 ttl=64 time=0.097 ms
64 bytes from 172.20.0.3: icmp_seq=2 ttl=64 time=0.075 ms

--- 172.20.0.3 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1016ms
rtt min/avg/max/mdev = 0.075/0.086/0.097/0.011 ms
# docker exec -it c3 ping -c 2 172.20.0.3
PING 172.20.0.3 (172.20.0.3) 56(84) bytes of data.
64 bytes from 172.20.0.3: icmp_seq=1 ttl=64 time=0.077 ms
64 bytes from 172.20.0.3: icmp_seq=2 ttl=64 time=0.087 ms

--- 172.20.0.3 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1019ms
rtt min/avg/max/mdev = 0.077/0.082/0.087/0.005 ms

# docker exec -it c1 /bin/bash
[root@496d4ddad025 /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
155: eth0@if156: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:13:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.19.0.2/16 brd 172.19.255.255 scope global eth0
       valid_lft forever preferred_lft forever
163: eth1@if164: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:14:00:03 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.20.0.3/24 brd 172.20.0.255 scope global eth`
       valid_lft forever preferred_lft forever

# docker network disconnect net2 c1

# docker inspect c1|grep -i ipaddr
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.19.0.2",
```

### 3.容器存储

![image-20230207192146050](cka培训截图/image-20230207192146050.png)



官方说明：

```bash
`Volumes` are stored in a part of the host filesystem which is managed by Docker (`/var/lib/docker/volumes/` on Linux). Non-Docker processes should not modify this part of the filesystem. Volumes are the best way to persist data in Docker.
docker run -v containerDir

`Bind mounts` may be stored anywhere on the host system. They may even be important system files or directories. Non-Docker processes on the Docker host or a Docker container can modify them at any time.
docker run -v hostDir:containerDir

`tmpfs` mounts are stored in the host system’s memory only, and are never written to the host system’s filesystem.
```





```bash
# man docker run

-v|--volume[=[[HOST-DIR:]CONTAINER-DIR[:OPTIONS]]]
          Create a bind mount. If you specify, -v /HOST-DIR:/CONTAINER-DIR, Docker
          bind mounts /HOST-DIR in the host to /CONTAINER-DIR in the Docker
          container. If 'HOST-DIR' is omitted,  Docker automatically creates the new
          volume on the host.  The OPTIONS are a comma delimited list and can be:

              • [rw|ro]

              • [z|Z]

              • [[r]shared|[r]slave|[r]private]

              • [delegated|cached|consistent]

              • [nocopy]

       The  CONTAINER-DIR  must be an absolute path such as /src/docs. The HOST-DIR can be an absolute
       path or a name value.
       
--volumes-from=[]
          Mount volumes from the specified container(s)
```

#### 3.1.持久存储之volume

测试volume：

```bash
# docker volume ls
DRIVER    VOLUME NAME

# docker run -d -p 8094:80 -v /usr/local/apache2/htdocs httpd
Unable to find image 'httpd:latest' locally
latest: Pulling from library/httpd
a2abf6c4d29d: Already exists 
dcc4698797c8: Pull complete 
41c22baa66ec: Pull complete 
67283bbdd4a0: Pull complete 
d982c879c57e: Pull complete 
Digest: sha256:0954cc1af252d824860b2c5dc0a10720af2b7a3d3435581ca788dff8480c7b32
Status: Downloaded newer image for httpd:latest
47bd9ceb4d9a11a880bb656035b9d823d9d1dbedbe5aeebe32ddcba5cd3fb32f

# docker volume inspect b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411
[
    {
        "CreatedAt": "2023-02-07T10:21:32+08:00",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411/_data",
        "Name": "b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411",
        "Options": null,
        "Scope": "local"
    }
]

# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED         STATUS         PORTS                                   NAMES
47bd9ceb4d9a   httpd     "httpd-foreground"   7 seconds ago   Up 6 seconds   0.0.0.0:8094->80/tcp, :::8094->80/tcp   amazing_volhard

# docker volume ls
DRIVER    VOLUME NAME
local     b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411

# docker inspect amazing_volhard |grep -A 8 Mounts
        "Mounts": [
            {
                "Type": "volume",
                "Name": "b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411",
                "Source": "/var/lib/docker/volumes/b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411/_data",
                "Destination": "/usr/local/apache2/htdocs",
                "Driver": "local",
                "Mode": "",
                "RW": true,

# cd /var/lib/docker/volumes/b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411/_data

# ls
index.html

# cat index.html 
<html><body><h1>It works!</h1></body></html>

# curl localhost:8094
<html><body><h1>It works!</h1></body></html>

# echo haha > /var/lib/docker/volumes/b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411/_data/index.html 

# curl localhost:8094
haha

# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED       STATUS       PORTS                                   NAMES
47bd9ceb4d9a   httpd     "httpd-foreground"   9 hours ago   Up 9 hours   0.0.0.0:8094->80/tcp, :::8094->80/tcp   amazing_volhard

# docker stop amazing_volhard 
amazing_volhard
# docker rm amazing_volhard 
amazing_volhard

# docker volume ls
DRIVER    VOLUME NAME
local     b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411

# cat /var/lib/docker/volumes/b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411/_data/index.html 
haha

# docker volume ls
DRIVER    VOLUME NAME
local     b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411

# docker volume rm b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411 
b5a51f86f4a32517d6d3cf491770fce8ac920fe2c89b063d00debbce07792411

# docker volume ls
DRIVER    VOLUME NAME

还可以指定volume的名称：
# docker run -d -p 8097:80 -v httpdvol:/usr/local/apache2/htdocs --name httpvol httpd
ad449fa1f1072f7e9c10cf0c0a89e93c9c26da2e393edd480596bbec1251b0ae

# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED         STATUS        PORTS                                   NAMES
ad449fa1f107   httpd     "httpd-foreground"   2 seconds ago   Up 1 second   0.0.0.0:8097->80/tcp, :::8097->80/tcp   httpvol

# docker volume ls
DRIVER    VOLUME NAME
local     httpdvol

# docker inspect httpvol |grep -A 8 Mounts
        "Mounts": [
            {
                "Type": "volume",
                "Name": "httpdvol",
                "Source": "/var/lib/docker/volumes/httpdvol/_data",
                "Destination": "/usr/local/apache2/htdocs",
                "Driver": "local",
                "Mode": "z",
                "RW": true,
```





#### 3.2.持久存储之bind mount

![image-20230207191931216](cka培训截图/image-20230207191931216.png)



```bash
创建宿主机上要被挂载的目录和文件，也可以不创建，在docker run -v时，宿主机目录会被自动创建
# mkdir /root/htdocs
# echo hehe > /root/htdocs/index.html

# docker run -d -p 8095:80 -v /root/htdocs:/usr/local/apache2/htdocs httpd
98cb0b6c8d5acbc165423cdb9c67ba3269a6cb0ef1c8399fd84792d7b1d9dd45

# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED         STATUS         PORTS                                   NAMES
98cb0b6c8d5a   httpd     "httpd-foreground"   3 seconds ago   Up 2 seconds   0.0.0.0:8095->80/tcp, :::8095->80/tcp   peaceful_feynman

# docker volume ls
DRIVER    VOLUME NAME
local     2e79e8bbb087c8e1ca452b1a520c6b5d0113956000ce8c5c1ea25abf815ec953
local     8e3af73bed3661847a904a0022b621d748be628beae34a796ba230eb5275c4b4
local     9470255d89b8455f700907f934e40c3e76794f0f7d0a66490c38805e127f73e0
local     1715027545ac6842754f4c5911a9125e97d9bf80645062d509587373e125c327
local     a432c7e7cf5c739682be27442ec9246b34938e44e5a48294ee4b33ccc7eb4acb
local     ae8cf42eade17a00309e6039ed68b9e1e7b51d118cc759276896229a56b4d994
local     c22a51e19a433475ea9f149b604a7450e81b1ed890aa3f05e04d134247c80e73
local     d1b3e04182dd1953cf5ef024dc6af3a52726bb8f0d52f2280e5a450675dcea4d
local     d8699189b9b33c3221730ff230a3c1b33bdeeca34fc7f21e08800765c91215b2
local     de3b996f07dfaab734393b70847484b9eee2e4f9f669a1bc37ca8d45cdbbd69b

# docker inspect peaceful_feynman |grep -A 8 Mounts
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/root/htdocs",
                "Destination": "/usr/local/apache2/htdocs",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            }

# curl localhost:8095
hehe

# echo heihei > /root/htdocs/index.html 
# curl localhost:8095
heihei

# docker rm peaceful_feynman -f
peaceful_feynman
# docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES

# cat /root/htdocs/index.html 
heihei
```



#### 3.3.容器间数据共享之bind mount
#### 3.3.1.主机与容器间

```
主机与容器数据共享：
---volume：将Host上的数据copy到容器的volume中
           也可使用docker cp命令在容器和主机Host之间复制数据
---bind mount：将Host上的目录或文件mount到容器中
```



![image-20230207200732560](cka培训截图/image-20230207200732560.png)







#### 3.3.2.容器与容器间

![image-20230207201123680](cka培训截图/image-20230207201123680.png)



```bash
# docker run -d --name=h1 -p 8010:80 -v /root/htdocs:/usr/local/apache2/htdocs httpd 
eb790644f8d0c09eeee264d7666cd0a9ddd298fc9e87302a5bd7cd530fefccbd

# docker run -d --name=h2 -p 8011:80 -v /root/htdocs:/usr/local/apache2/htdocs httpd 
bc2edf6f056c34e9928cb7ebeade8e82f6bcc1aa074b690823574a63a78246d5

# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED          STATUS          PORTS                                   NAMES
bc2edf6f056c   httpd     "httpd-foreground"   3 seconds ago    Up 1 second     0.0.0.0:8011->80/tcp, :::8011->80/tcp   h2
eb790644f8d0   httpd     "httpd-foreground"   31 seconds ago   Up 29 seconds   0.0.0.0:8010->80/tcp, :::8010->80/tcp   h1

# cat /root/htdocs/index.html 
heihei

# curl localhost:8010
heihei
# curl localhost:8011
heihei

# echo new > /root/htdocs/index.html 

# curl localhost:8010
new
# curl localhost:8011
new
```





#### 3.4.容器间数据共享之volume container



![image-20230207201456242](cka培训截图/image-20230207201456242.png)

```bash
# docker run -d --name vc -v /root/htdocs:/usr/local/apache2/htdocs httpdddbeb27b8a7d976f3e0d7e88f80f7a74a0509cb7860ec8fc42424503d6e8ad15
# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED         STATUS        PORTS     NAMES
ddbeb27b8a7d   httpd     "httpd-foreground"   2 seconds ago   Up 1 second   80/tcp    vc
# docker inspect vc|grep -A 8  Mounts
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/root/htdocs",
                "Destination": "/usr/local/apache2/htdocs",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            }

# docker run -d -p 8012:80 --volumes-from=vc --name h3 httpd
6cc18976bcd8f92a2c7c3b0b9d66a70cbf6a59f1671960f4ad80cdd6191c7dc5
# docker run -d -p 8013:80 --volumes-from=vc --name h4 httpd
d246e7b9c11307a003d50e5aaf4add140fe668b915d6667746774d3f0994b7ca
# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED              STATUS              PORTS                                   NAMES
d246e7b9c113   httpd     "httpd-foreground"   3 seconds ago        Up 1 second         0.0.0.0:8013->80/tcp, :::8013->80/tcp   h4
6cc18976bcd8   httpd     "httpd-foreground"   13 seconds ago       Up 11 seconds       0.0.0.0:8012->80/tcp, :::8012->80/tcp   h3
ddbeb27b8a7d   httpd     "httpd-foreground"   About a minute ago   Up About a minute   80/tcp                                  vc

# docker inspect h3|grep -A 8  Mounts
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/root/htdocs",
                "Destination": "/usr/local/apache2/htdocs",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            }
# docker inspect h4|grep -A 8  Mounts
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/root/htdocs",
                "Destination": "/usr/local/apache2/htdocs",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            }
            
# curl localhost:8012
new
# curl localhost:8013
new

# echo hehe > /root/htdocs/index.html 

# curl localhost:8012
hehe
# curl localhost:8013
hehe

# docker run -d -p 8014:80 --volumes-from vc --name h5 httpd
800a8adddb7273be76dcd0d6c606e8abee43ab3062de1f4761c140d9a74a424b
# docker ps
CONTAINER ID   IMAGE     COMMAND              CREATED         STATUS         PORTS                                   NAMES
800a8adddb72   httpd     "httpd-foreground"   2 seconds ago   Up 1 second    0.0.0.0:8014->80/tcp, :::8014->80/tcp   h5
d246e7b9c113   httpd     "httpd-foreground"   6 minutes ago   Up 6 minutes   0.0.0.0:8013->80/tcp, :::8013->80/tcp   h4
6cc18976bcd8   httpd     "httpd-foreground"   6 minutes ago   Up 6 minutes   0.0.0.0:8012->80/tcp, :::8012->80/tcp   h3
ddbeb27b8a7d   httpd     "httpd-foreground"   7 minutes ago   Up 7 minutes   80/tcp                                  vc

# curl localhost:8014
hehe
```



### 4.容器底层实现技术

### 4.1.Namespace和Cgroup





### 4.2.cpu和mem资源限制







===abc===

--cd--

---e---

---








### 附录
#### A1.学习方法

| step |                |                    |               示例                |
| :--: | :------------: | :----------------: | --------------------------------- |
|  1   |      word      |    查单词，释义    |            pull，拉取             |
|  2   | <kbd>Tab</kbd> | 一下不全，两下列出 | # doc<kbd>Tab</kbd><br /># docker <kbd>空格</kbd> <kbd>Tab</kbd><kbd>Tab</kbd> |
|  3   |   man,--help   |        帮助        | # man docker run <br># docker --help |
|  4   | echo $? | 查看回显 | 0 == 正确执行<br>非0 == 错误执行 |
|  5   |                |                    |                                   |



#### A2.相关软件

| step |   NAME   |                             URL                              |            FUNC            |
| :--: | :------: | :----------------------------------------------------------: | :------------------------: |
|  1   | 欧路词典 |                    https://www.eudic.net/                    |          翻译软件          |
|  2   |  Typora  |                     https://typoraio.cn                      |      MarkDown格式文档      |
|  3   |  VMware  |                   https://www.vmware.com/                    |         虚拟化软件         |
|  4   |  ubuntu  |                     https://ubuntu.com/                      |        系统光盘iso         |
|  5   |  docker  |       https://docs.docker.com/desktop/install/ubuntu/        |            国外            |
|      |          | https://developer.aliyun.com/mirror/docker-ce?spm=a2c6h.13651102.0.0.4ea21b11CvJUSb |         国内阿里云         |
|      |          | https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors  |   仓库加速器daemon.json    |
|      |          |              https://docs.docker.com/reference/              | docker命令及dockerfile介绍 |
|  6   |          |                                                              |                            |



#### A3.ubuntu快捷键

| step |                            快捷键                            |       FUNC       |
| :--: | :----------------------------------------------------------: | :--------------: |
|  1   | <kbd>crtl</kbd>-<kbd>shift</kbd>-<kbd>=</kbd>\|<kbd>ctrl</kbd>-<kbd>+</kbd> |     字体放大     |
|  2   |        <kbd>crtl</kbd>-<kbd>shift</kbd>-<kbd>T</kbd>         | 新建terminal标签 |
|  3   |   <kbd>Alt</kbd>-<kbd>1</kbd>\|<kbd>Alt</kbd>-<kbd>2</kbd>   |     切换标签     |
|      |                                                              |                  |
|      |                                                              |                  |



#### A4.vim

```bash
# vim
# apt install vim
```



| mode |   模式   |                |              |                     |
| :--: | :------: | :------------: | :----------: | :-----------------: |
|  1   | 命令模式 |  <kbd>i</kbd>  |              |   默认的工作模式    |
|  2   | 输入模式 | <kbd>Esc</kbd> | -- INSERT -- |    退出输入模式     |
|  3   | 末行模式 |      :wq       |              | write quit 保存退出 |



| step |    快捷键     |                FUNC                |
| :--: | :-----------: | :--------------------------------: |
|  1   |   :%s/^/#/g   |         全部行首快速添加#          |
|  2   |   :%s/$/#/g   |         全部行尾快速添加#          |
|  3   | :r !seq 1 100 |              递归数字              |
|  4   | :r dockerfile | 导入所在文件夹下的dockerfile的内容 |



#### A5.typora快捷键

| step |                    快捷键                     |      FUNC      |
| :--: | :-------------------------------------------: | :------------: |
|  1   |         <kbd>crtl</kbd>-<kbd>T</kbd>          |    插入表格    |
|  2   | <kbd>crtl</kbd>-<kbd>shift</kbd>-<kbd>K</kbd> |   添加代码块   |
|  3   |   <kbd>-</kbd><kbd>-</kbd><kbd>-</kbd> 回车   | 添加一行分隔符 |
|  4   |                                               |                |

```

```



#### A6.dockerfile

Dockerfile常用命令




|         指令          |                       作用                        |                           命令格式                           | 例子                                                         |
| :-------------------: | :-----------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------- |
|         FROM          |                   指定base镜像                    |   FROM [--platform=<platform>] <image>[:<tag>] [AS <name>]   | FROM  centos                                                 |
| MAINTAINER<br />LABEL |                    维护者信息                     |     LABEL <key>=<value> <key>=<value> <key>=<value> ...      | LABEL "com.example.vendor"="ACME Incorporated" <br />LABEL com.example.label-with-value="foo" LABEL version="1.0" |
|          RUN          |                  运行指定的命令                   | RUN <command>：<br />Linux: /bin/sh -c, Windows: cmd /S /C<br />RUN ["executable", "param1", "param2"] | RUN /bin/bash -c 'source $HOME/.bashrc; echo $HOME'<br />RUN ["/bin/bash", "-c", "echo hello"]<br />RUN ["c:\\windows\\system32\\tasklist.exe"] |
|          ADD          | 将文件从build context复制到镜像中<br />可以解压缩 | ADD [--chown=<user>:<group>] [--checksum=<checksum>] <src>... <dest><br/>ADD [--chown=<user>:<group>] ["<src>",... "<dest>"] | ADD hom* /mydir/<br /><br />ADD --chown=55:mygroup files* /somedir/ |
|         COPY          |         将文件从build context复制到镜像中         | COPY [--chown=<user>:<group>] <src>... <dest><br/>COPY [--chown=<user>:<group>] ["<src>",... "<dest>"] | COPY hom* /mydir/<br />COPY --chown=55:mygroup files* /somedir/ |
|          ENV          |                   设置环境变量                    |                    ENV <key>=<value> ...                     | ENV MY_NAME="John Doe"<br/>ENV MY_DOG=Rex\ The\ Dog<br/>ENV MY_CAT=fluffy |
|        EXPOSE         |            指定容器中的应用坚挺的端口             |             EXPOSE <port> [<port>/<protocol>...]             | EXPOSE 80/tcp<br/>EXPOSE 80/udp                              |
|         USER          |                设置启动容器的用户                 |                    USER <user>[:<group>]                     | USER tommy                                                   |
|          CMD          |       设置在容器启动时运行指定的脚本或命令        | `CMD ["executable","param1","param2"]` (*exec* form, this is the preferred form) <br />`CMD ["param1","param2"]` (as *default parameters to ENTRYPOINT*) <br />`CMD command param1 param2` (*shell* form) | CMD echo "This is a test." \| wc -<br />CMD ["/usr/bin/wc","--help"] |
|      ENTRYPOINT       |      指定的是一个可执行的脚本或者程序的路径       |               ENTRYPOINT command param1 param2               | FROM ubuntu<br/>ENTRYPOINT ["top", "-b"]<br/>CMD ["-c"]<br /><br />FROM debian:stable<br/>RUN apt-get update && apt-get install -y --force-yes apache2<br/>EXPOSE 80 443<br/>VOLUME ["/var/www", "/var/log/apache2", "/etc/apache2"]<br/>ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"] |
|        VOLUME         |      将文件或目录声明为volume，挂载到容器中       |                       VOLUME ["/data"]                       | FROM ubuntu <br />RUN mkdir /myvol <br />RUN echo "hello world" > /myvol/greeting <br />VOLUME /myvol |
|        WORKDIR        |              设置镜像的当前工作目录               |                   WORKDIR /path/to/workdir                   | WORKDIR /a<br/>WORKDIR b<br/>WORKDIR c<br/>RUN pwd           |


> 官网https://docs.docker.com/engine/reference/builder/




#### 目录

![image-20221213163404248](cka培训截图\image-20221213163404248.png)