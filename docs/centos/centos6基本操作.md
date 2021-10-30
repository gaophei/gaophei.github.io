添加账户：

useradd user1

passwd user1

服务管理：

service sshd status

chkconfig --list

防火墙：

service iptables status

iptables -nL

#iptables示例

iptables -I INPUT -i eth0 -p tcp -d xxx.xxx.xxx.xxx/32 --destination-port 25 -j LOG

iptables -I INPUT -i eth0 -p tcp --syn --destination-port 25 -j  ACCEPT

iptables  -t nat -I FORWARD -d xxx.xxx.xxx.xxx/32 -j DROP

