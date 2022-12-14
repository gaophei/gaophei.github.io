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
# sudo -i
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
# sudo apt-get update -y && sudo apt upgrade -y
# sudo install openssh-server -y
# sudo systemctl enable --now ssh
# sudo systemctl status ssh
```

##### 1.3.2.3.安装docker

```bash
step 1: 安装必要的一些系统工具
# sudo apt-get update
# sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
step 2: 安装GPG证书
# curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
Step 3: 写入软件源信息
# sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
Step 4: 更新并安装Docker-CE
# sudo apt-get -y update
# sudo apt-get -y install docker-ce
# sudo systemctl enable --now docker
# sudo systemctl status docker

安装指定版本的Docker-CE:
Step 1: 查找Docker-CE的版本:
# apt-cache madison docker-ce
  docker-ce | 17.03.1~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
  docker-ce | 17.03.0~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
Step 2: 安装指定版本的Docker-CE: (VERSION例如上面的17.03.1~ce-0~ubuntu-xenial)
# sudo apt-get -y install docker-ce=[VERSION]
```

```bash
#修改默认仓库
# sudo -i
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





#### 1.4.容器基本操作

##### 1.4.1.运行一个容器

```bash
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
--- 官网：https://docs.docker.com/engine/reference/commandline/attach/
```
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
b064fc7ce564   nginx     "/docker-entrypoint.…"   23 minutes ago   Up 23 minutes   0.0.0.0:8081->80/tcp, :::8081->80/tcp   stoic_wilson
0dfd41b80266   httpd     "httpd-foreground"       11 hours ago     Up 11 minutes   0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison

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
b064fc7ce564   nginx     "/docker-entrypoint.…"   About an hour ago   Up About an hour   0.0.0.0:8081->80/tcp, :::8081->80/tcp   stoic_wilson
0dfd41b80266   httpd     "httpd-foreground"       12 hours ago        Up 53 minutes      0.0.0.0:8080->80/tcp, :::8080->80/tcp   exciting_jemison

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
root       13742    8797  0 10:19 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8081 -container-ip 172.17.0.3 -container-port 80
root       13747    8797  0 10:19 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 8081 -container-ip 172.17.0.3 -container-port 80
root       16263    8797  0 10:31 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8080 -container-ip 172.17.0.2 -container-port 80
root       16268    8797  0 10:31 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 8080 -container-ip 172.17.0.2 -container-port 80
root       25497   13612  0 11:26 pts/7    00:00:00 docker attach inspiring_fermat
root       25800   25266  0 11:28 pts/2    00:00:00 grep --color=auto docker


# kill -9 25497

# ps -ef|grep docker
root        8797       1  0 10:01 ?        00:00:10 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root       13742    8797  0 10:19 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8081 -container-ip 172.17.0.3 -container-port 80
root       13747    8797  0 10:19 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 8081 -container-ip 172.17.0.3 -container-port 80
root       16263    8797  0 10:31 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8080 -container-ip 172.17.0.2 -container-port 80
root       16268    8797  0 10:31 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 8080 -container-ip 172.17.0.2 -container-port 80
root       25877   13612  0 11:28 pts/7    00:00:00 docker attach inspiring_fermat
root       26013   25266  0 11:29 pts/2    00:00:00 grep --color=auto docker

kill 父线程号才有效
# kill -9 13612

# ps -ef|grep docker
root        8797       1  0 10:01 ?        00:00:10 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root       13742    8797  0 10:19 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8081 -container-ip 172.17.0.3 -container-port 80
root       13747    8797  0 10:19 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 8081 -container-ip 172.17.0.3 -container-port 80
root       16263    8797  0 10:31 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8080 -container-ip 172.17.0.2 -container-port 80
root       16268    8797  0 10:31 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 8080 -container-ip 172.17.0.2 -container-port 80
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

| step |   NAME   |                             URL                              |         FUNC          |
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



#### A3.ubuntu快捷键

| step |                            快捷键                            |       FUNC       |
| :--: | :----------------------------------------------------------: | :--------------: |
|  1   | <kbd>crtl</kbd>-<kbd>shift</kbd>-<kbd>=</kbd>\|<kbd>ctrl</kbd>-<kbd>+</kbd> |     字体放大     |
|  2   |        <kbd>crtl</kbd>-<kbd>shift</kbd>-<kbd>T</kbd>         | 新建terminal标签 |
|  3   |   <kbd>Alt</kbd>-<kbd>1</kbd>\|<kbd>Alt</kbd>-<kbd>2</kbd>   |     切换标签     |
|      |                                                              |                  |
|      |                                                              |                  |



#### A4.vi快捷键

| step |    快捷键     |       FUNC        |
| :--: | :-----------: | :---------------: |
|  1   |   :%s/^/#/g   | 全部行首快速添加# |
|  2   |   :%s/$/#/g   | 全部行尾快速添加# |
|  3   | :r !seq 1 100 |     递归数字      |
|  4   |               |                   |



#### A5.typora快捷键

| step |                    快捷键                     |      FUNC      |
| :--: | :-------------------------------------------: | :------------: |
|  1   |         <kbd>crtl</kbd>-<kbd>T</kbd>          |    插入表格    |
|  2   | <kbd>crtl</kbd>-<kbd>shift</kbd>-<kbd>K</kbd> |   添加代码块   |
|  3   |   <kbd>-</kbd><kbd>-</kbd><kbd>-</kbd> 回车   | 添加一行分隔符 |
|  4   |                                               |                |

```

```



#### 目录

![image-20221213163404248](cka培训截图\image-20221213163404248.png)