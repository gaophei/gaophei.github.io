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



## 安装Oracle software

#仅安装software

![image-20220310103613492](centos7-oracle19CRAC\image-20220310103613492.png)



#oracle RAC

![image-20220310104108012](centos7-oracle19CRAC\image-20220310104108012.png)



#SSH互信

![image-20220310104212145](centos7-oracle19CRAC\image-20220310104212145.png)



![image-20220310104258596](centos7-oracle19CRAC\image-20220310104258596.png)



#企业版

![image-20220310104328887](centos7-oracle19CRAC\image-20220310104328887.png)



#$ORACLE_BASE(/u01/app/oracle)

![image-20220310105906175](centos7-oracle19CRAC\image-20220310105906175.png)



#用户组，保持默认

![image-20220310105940476](centos7-oracle19CRAC\image-20220310105940476.png)



#保持默认

![image-20220310110112209](centos7-oracle19CRAC\image-20220310110112209.png)



#可以忽略全部

![image-20220310135218118](centos7-oracle19CRAC\image-20220310135218118.png)



![image-20220310135243907](centos7-oracle19CRAC\image-20220310135243907.png)



#点击Install开始安装

![image-20220310135322686](centos7-oracle19CRAC\image-20220310135322686.png)





#以root账户分别依次在两个节点上运行

![image-20220310135718262](centos7-oracle19CRAC\image-20220310135718262.png)



#点击close结束

![image-20220310135842268](centos7-oracle19CRAC\image-20220310135842268.png)



## 创建RAC数据库

#oracle用户下执行dbca

#Create a database

![image-20220310141016043](centos7-oracle19CRAC\image-20220310141016043.png)



#高级配置

![image-20220310141849188](centos7-oracle19CRAC\image-20220310141849188.png)



#RAC/Admin Managed/General Purpose

![image-20220310142308219](centos7-oracle19CRAC\image-20220310142308219.png)



#全部选中

![image-20220310142340946](centos7-oracle19CRAC\image-20220310142340946.png)



#数据库名称xydb/CDB/PDB:dataassets

![image-20220310142820560](centos7-oracle19CRAC\image-20220310142820560.png)



#+DATA/{DB_UNIQUE_NAME}/Use OMF

![image-20220310143133993](centos7-oracle19CRAC\image-20220310143133993.png)



#ASM/+FRA/2097012/Enable archiving

![image-20220310143644189](centos7-oracle19CRAC\image-20220310143644189.png)



#数据库组件，保持默认

![image-20220310143946457](centos7-oracle19CRAC\image-20220310143946457.png)



#自动共享内存管理

![image-20220310145007338](centos7-oracle19CRAC\image-20220310145007338.png)



#processes:3840

![image-20220310145444193](centos7-oracle19CRAC\image-20220310145444193.png)



#AL32UTF8

![image-20220310150019775](centos7-oracle19CRAC\image-20220310150019775.png)



#连接模式

![image-20220310150333561](centos7-oracle19CRAC\image-20220310150333561.png)



#运行CVU和开启EM

![image-20220310151337378](centos7-oracle19CRAC\image-20220310151337378.png)



#使用相同密码

![image-20220310151637806](centos7-oracle19CRAC\image-20220310151637806.png)



#勾选：create database

![image-20220310151814822](centos7-oracle19CRAC\image-20220310151814822.png)



#忽略全部

![image-20220310152227046](centos7-oracle19CRAC\image-20220310152227046.png)



![image-20220310152257227](centos7-oracle19CRAC\image-20220310152257227.png)



#Finish

![image-20220310152324698](centos7-oracle19CRAC\image-20220310152324698.png)



#Close

![image-20220310154422107](centos7-oracle19CRAC\image-20220310154422107.png)



#检查集群状态

```
[grid@zhongtaidb1 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.chad
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.net1.network
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
ora.ons
               ONLINE  ONLINE       zhongtaidb1              STABLE
               ONLINE  ONLINE       zhongtaidb2              STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        ONLINE  OFFLINE                               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              Started,STABLE
      2        ONLINE  ONLINE       zhongtaidb2              Started,STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
      2        ONLINE  ONLINE       zhongtaidb2              STABLE
      3        OFFLINE OFFLINE                               STABLE
ora.cvu
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.qosmserver
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.xydb.db
      1        ONLINE  ONLINE       zhongtaidb1              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       zhongtaidb2              Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.zhongtaidb1.vip
      1        ONLINE  ONLINE       zhongtaidb1              STABLE
ora.zhongtaidb2.vip
      1        ONLINE  ONLINE       zhongtaidb2              STABLE
--------------------------------------------------------------------------------
```















