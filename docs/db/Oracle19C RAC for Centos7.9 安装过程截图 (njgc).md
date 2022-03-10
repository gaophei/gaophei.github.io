## GI安装

#grid用户$ORACLE_HOME/gridSetup.sh

#为新的集群配置GI

![image-20220309150328618](centos7-oracle19CRAC\image-20220309150328618.png)



#standalone cluster

![image-20220309151011801](centos7-oracle19CRAC\image-20220309151011801.png)



#集群名称等，与/etc/hosts内scanIP的名称一致

![image-20220309163443744](centos7-oracle19CRAC\image-20220309163443744.png)



#添加节点二

![image-20220309164325782](centos7-oracle19CRAC\image-20220309164325782.png)



#节点二信息

![image-20220309164417693](centos7-oracle19CRAC\image-20220309164417693.png)



#测试SSH互信

![image-20220309164508909](centos7-oracle19CRAC\image-20220309164508909.png)



![image-20220309164607100](centos7-oracle19CRAC\image-20220309164607100.png)



#私有网卡eno8: ASM&private，公有网卡team0: public

![image-20220309165535197](centos7-oracle19CRAC\image-20220309165535197.png)



#Flex ASM

![image-20220309165826318](centos7-oracle19CRAC\image-20220309165826318.png)



#不单独创建磁盘组

![image-20220309170138087](centos7-oracle19CRAC\image-20220309170138087.png)



#OCR磁盘组

![image-20220309170255015](centos7-oracle19CRAC\image-20220309170255015.png)



![image-20220309170641786](centos7-oracle19CRAC\image-20220309170641786.png)



#同一个密码

![image-20220309170909757](centos7-oracle19CRAC\image-20220309170909757.png)



#保持默认：No IPMI

![image-20220309171000584](centos7-oracle19CRAC\image-20220309171000584.png)



#保持默认：No EM

![image-20220309171121881](centos7-oracle19CRAC\image-20220309171121881.png)



#asmadmin/admindba/asmoper

![image-20220309171231893](centos7-oracle19CRAC\image-20220309171231893.png)



#$ORACLE_BASE(/u01/app/grid)

![image-20220309171312920](centos7-oracle19CRAC\image-20220309171312920.png)



#/u01/app/orainventory

![image-20220309171357100](centos7-oracle19CRAC\image-20220309171357101.png)



#保持默认

![image-20220309172006105](centos7-oracle19CRAC\image-20220309172006105.png)



#忽略全部

![image-20220309180507494](centos7-oracle19CRAC\image-20220309180507494.png)



![image-20220309180634638](centos7-oracle19CRAC\image-20220309180634638.png)



#Install

![image-20220309180700474](centos7-oracle19CRAC\image-20220309180700474.png)



#root账户在两台服务器上分别执行脚本，执行完后点击OK

![image-20220309180956779](centos7-oracle19CRAC\image-20220309180956779.png)



#点击OK继续

![image-20220309182425381](centos7-oracle19CRAC\image-20220309182425381.png)



![image-20220309182504267](centos7-oracle19CRAC\image-20220309182504267.png)



![image-20220309182547734](centos7-oracle19CRAC\image-20220309182547734.png)



＃安装完成

![image-20220309182613334](centos7-oracle19CRAC\image-20220309182613334.png)



## ASMCA创建磁盘组

#asmca，点击diskgroups，点击创建(create)

![image-20220309183223882](centos7-oracle19CRAC\image-20220309183223882.png)



#DATA磁盘组

![image-20220309183553786](centos7-oracle19CRAC\image-20220309183553786.png)



#FRA磁盘组

![image-20220309183737922](centos7-oracle19CRAC\image-20220309183737922.png)



![image-20220309183830029](centos7-oracle19CRAC\image-20220309183830029.png)











