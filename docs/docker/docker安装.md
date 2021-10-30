##安装依赖包，添加源，安装docker指定版本

```bash
 yum install -y yum-utils device-mapper-persistent-data lvm2 bash-completion;
 
 yum-config-manager --add-repo \
    https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo;

 yum -y install docker-ce-19.03.15-3.el7
```

