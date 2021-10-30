本文讲述如何升级openssh。



## 制作 RPM 包

### 安装相关依赖

```
yum install rpm-build zlib-devel openssl-devel gcc perl-devel pam-devel unzip libXt-devel imake gtk2-devel openssl-libs -y
```

### 创建所需目录

```
mkdir -p /root/rpmbuild/{SOURCES,SPECS}
cd /root/rpmbuild/SOURCES
```

### 下载源码包

> 下载地址：
>
> http://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/
> https://src.fedoraproject.org/repo/pkgs/openssh/

```bash
wget https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-8.4p1.tar.gz
wget https://src.fedoraproject.org/repo/pkgs/openssh/x11-ssh-askpass-1.2.4.1.tar.gz/8f2e41f3f7eaa8543a2440454637f3c3/x11-ssh-askpass-1.2.4.1.tar.gz

tar -xvzf openssh-8.4p1.tar.gz
tar -xvzf x11-ssh-askpass-1.2.4.1.tar.gz
```

### 修改配置文件

```
cp openssh-8.4p1/contrib/redhat/openssh.spec /root/rpmbuild/SPECS/
cd /root/rpmbuild/SPECS/

sed -i -e "s/%define no_x11_askpass 0/%define no_x11_askpass 1/g" openssh.spec
sed -i -e "s/%define no_gnome_askpass 0/%define no_gnome_askpass 1/g" openssh.spec
```

### 构建

```
rpmbuild -ba openssh.spec

构建成功结果如下：
Wrote: /root/rpmbuild/SRPMS/openssh-8.4p1-1.el7.src.rpm
Wrote: /root/rpmbuild/RPMS/x86_64/openssh-8.4p1-1.el7.x86_64.rpm
Wrote: /root/rpmbuild/RPMS/x86_64/openssh-clients-8.4p1-1.el7.x86_64.rpm
Wrote: /root/rpmbuild/RPMS/x86_64/openssh-server-8.4p1-1.el7.x86_64.rpm
Wrote: /root/rpmbuild/RPMS/x86_64/openssh-askpass-8.4p1-1.el7.x86_64.rpm
Wrote: /root/rpmbuild/RPMS/x86_64/openssh-askpass-gnome-8.4p1-1.el7.x86_64.rpm
Wrote: /root/rpmbuild/RPMS/x86_64/openssh-debuginfo-8.4p1-1.el7.x86_64.rpm
Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.pshj6r
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd openssh-8.4p1
+ rm -rf /root/rpmbuild/BUILDROOT/openssh-8.4p1-1.el7.x86_64
+ exit 0
```

### 验证软件包

```
ls /root/rpmbuild/RPMS/x86_64/
openssh-8.4p1-1.el7.x86_64.rpm                openssh-clients-8.4p1-1.el7.x86_64.rpm
openssh-askpass-8.4p1-1.el7.x86_64.rpm        openssh-debuginfo-8.4p1-1.el7.x86_64.rpm
openssh-askpass-gnome-8.4p1-1.el7.x86_64.rpm  openssh-server-8.4p1-1.el7.x86_64.rpm
```

### 构建过程报错解决

> 错误1：
> error: Failed build dependencies: openssl-devel < 1.1 is needed by openssh-8.4p1-1.el7.x86_64
> 解决办法：
> 注释BuildRequires: openssl-devel < 1.1这一行

```
sed -i 's/BuildRequires: openssl-devel < 1.1/#&/' openssh.spec
```

> 错误2：
> error: Failed build dependencies: /usr/include/X11/Xlib.h is needed by openssh-8.4p1-1.el7.x86_64
> 解决办法：
> 安装libXt-devel imake gtk2-devel openssl-libs

```
yum install libXt-devel imake gtk2-devel openssl-libs -y
```

## 开始升级

### 备份配置文件

```
cp /etc/pam.d/{sshd,sshd.bak}
cp /etc/ssh/{sshd_config,sshd_config.bak}
```

### 安装telnet（胆大的跳过）

> 避免 `openssh` 升级识别无法登陆，安装`telnet`（同时开启两个窗口）

```
yum install telnet-server xinetd -y
systemctl enable --now xinetd.service
systemctl enable --now telnet.socket
```

> 配置 `telnet` 登陆
>
> //注释auth [user_unknown=ignore success=ok ignore=ignore default=bad] pam_securetty.so这一行

```
sed -i 's/^auth \[user_unknown=/#&/' /etc/pam.d/login

cat >> /etc/securetty <<EOF
pts/1
pts/2
EOF

//测试登陆
[C:\~]$ telnet 192.168.3.179
Trying 192.168.3.179...
Connected to 192.168.3.179.
Escape character is '^]'.

Kernel 3.10.0-957.27.2.el7.x86_64 on an x86_64
localhost0 login: root
Password: 
Last login: Thu Dec 31 15:28:23 from 192.168.3.144
[root@localhost0 ~]# 
```

### 安装新版本

> 更新`openssh`版本

将编译好的包拷贝到需要升级的机器

```
yum update ./openssh* -y
```

### 启动ssh服务

> 恢复备份的配置文件，并重启sshd

```
\mv /etc/pam.d/sshd.bak /etc/pam.d/sshd
\mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config

chmod 600 /etc/ssh/*
systemctl restart sshd
```

如果无法登陆

修改`/etc/ssh/sshd_config`

取消注释并修改`PermitRootLogin yes`

```
sed -i "s|.*PermitRootLogin.*|PermitRootLogin yes|g" /etc/ssh/sshd_config
sed -i 's|.*PasswordAuthentication.*|PasswordAuthentication yes|g' /etc/ssh/sshd_config
```

### 验证登陆

> 新开窗口连接登陆测试，没有问题后再进行下面的关闭`telnet`步骤。
>
> **注意：**请勿关闭当前窗口，另外新开窗口连接没问题，再关闭。

### 关闭 telnet

> 注意：开启`telnet`的`root`远程登录极度不安全，账号密码都是明文传输，尤其在公网，所以一般只限于在某些情况下内网中ssh无法使用时，临时调测，使用完后，将相关配置复原，彻底关闭`telnet`服务！

```
systemctl stop telnet.socket && systemctl disable telnet.socket
systemctl stop xinetd.service && systemctl disable xinetd.service
```

### 验证当前版本

```
ssh -V
OpenSSH_8.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017
```

最后，我写了一个一键升级的[脚本](https://gitee.com/yuanfusc/packages/raw/master/openssh_upgrade.sh)

```bash
#!/usr/bin/env bash
# @Date   :2021/4/14 16:13
# @Author :YaoKun
# @Email  :yaokun@bwcxtech.com
# @File   :openssh_upgrade.sh
# @Desc   :升级openssh版本至8.4p1

# 如果非root可能存在权限问题，使用如下命令执行
# sudo su - root<<EOF
# sh openssh_upgrade.sh
# EOF

# 下载软件包
function download_package() {
    mkdir -p /tmp/openssh
	cd /tmp/openssh
	echo -e "\033[34;1m 开始下载软件包openssh-8.4p1-1.el7.centos.x86_64.rpm \033[0m"
	wget https://gitee.com/yuanfusc/packages/attach_files/671314/download/openssh-8.4p1-1.el7.centos.x86_64.rpm
    if [ $? -ne 0 ]; then
        echo "openssh-8.4p1-1.el7.centos.x86_64.rpm下载失败...请检查网络环境或版本是否存在"
        exit 2
    fi
	sleep 2
	echo -e "\033[34;1m 开始下载软件包openssh-server-8.4p1-1.el7.centos.x86_64.rpm \033[0m"
	wget https://gitee.com/yuanfusc/packages/attach_files/671313/download/openssh-server-8.4p1-1.el7.centos.x86_64.rpm
    if [ $? -ne 0 ]; then
        echo "openssh-server-8.4p1-1.el7.centos.x86_64.rpm下载失败...请检查网络环境是否正常"
        exit 2
	fi
	sleep 2
	echo -e "\033[34;1m 开始下载软件包openssh-clients-8.4p1-1.el7.centos.x86_64.rpm \033[0m"
	wget https://gitee.com/yuanfusc/packages/attach_files/671316/download/openssh-clients-8.4p1-1.el7.centos.x86_64.rpm
	if [ $? -ne 0 ]; then
		echo "openssh-8.4p1-1.el7.centos.x86_64.rpm下载失败...请检查网络环境或版本是否存在"
		exit 2
	fi
}

# 备份配置
function bakup() {
	cp /etc/pam.d/{sshd,sshd.bak}
	cp /etc/ssh/{sshd_config,sshd_config.bak}
}

# 升级
function update() {
	yum update ./openssh* -y
    if [ $? -eq 0 ]; then
        echo -e "\033[34;1m 安装成功 \033[0m"
    else
        echo -e "\033[33;1m 安装失败 \033[0m"
    fi
}

# 还原配置
function reduction_and_restart() {
	\mv /etc/pam.d/sshd.bak /etc/pam.d/sshd
	\mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
	chmod 600 /etc/ssh/*
	sed -i "s|.*PermitRootLogin.*|PermitRootLogin yes|g" /etc/ssh/sshd_config
	sed -i 's|.*PasswordAuthentication.*|PasswordAuthentication yes|g' /etc/ssh/sshd_config
	systemctl restart sshd
    if [ $? -eq 0 ]; then
        echo -e "\033[34;1m openssh重启成功 \033[0m"
    else
        echo -e "\033[33;1m openssh重启失败 \033[0m"
    fi
}

# 删除软件包
function remove_files() {
	cd /tmp
	rm -rf openssh
}

function main() {
    download_package
    bakup
    update
	reduction_and_restart
	remove_files
}
main
```



参考链接：[CentOS通过yum升级Openssh8.x](https://www.cnblogs.com/yanjieli/p/14220914.html)