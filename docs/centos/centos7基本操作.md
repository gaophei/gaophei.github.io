系统管理：

top

free -m

df -h



<br>

服务管理：

systemctl status sshd



<br>

防火墙：

systemctl status firewalld

getenforce

setenforce 0

firewall-cmd --list-all











