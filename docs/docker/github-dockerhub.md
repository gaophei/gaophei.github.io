###由于国内对dockhub的封杀，所以通过github来实现对dockerhub的镜像转存

### 0.前置说明

#需要：

#1、github账户

#2、阿里云账户

### 1.配置步骤

#### 1.1.配置阿里云

#登录阿里云容器镜像服务

```docker
https://cr.console.aliyun.com/
```

#启动个人实例，创建一个命名空间(ALIYUN_NAME_SPACE)

![image-20240623221108468](E:\workpc\git\gitio\gaophei.github.io\docs\docker\github-dockerhub\image-20240623221108468.png)

#三个变量

| KEY                      | VALUE                             |      |
| ------------------------ | --------------------------------- | ---- |
| ALIYUN_REGISTRY_USER     | 阿里云账户                        |      |
| ALIYUN_REGISTRY_PASSWORD | 阿里云镜像仓库密码                |      |
| ALIYUN_REGISTRY          | registry.cn-hangzhou.aliyuncs.com |      |



#### 1.2.配置github

