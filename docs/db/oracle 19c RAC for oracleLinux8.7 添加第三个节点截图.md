                                                                   **19cRAC添加第三个节点**
### 安装GI

#xterm连接grid用户，$ORACLE_HOME/gridSetup.sh

#Add more  nodes to the cluster

![image-20221206174531542](oracle19cRACaddnodes\image-20221206174531542.png)



#Add：db-rac03/db-rac03-vip

![image-20221206174931025](oracle19cRACaddnodes\image-20221206174931025.png)



#SSH connectivity、Test

![image-20221206175809343](oracle19cRACaddnodes\image-20221206175809343.png)



#测试通过

![image-20221206180021556](oracle19cRACaddnodes\image-20221206180021556.png)



#Ignore all

![image-20221206180243757](oracle19cRACaddnodes\image-20221206180243757.png)



#submit

#开始安装

![image-20221206180411292](oracle19cRACaddnodes\image-20221206180411292.png)



#执行脚本

![image-20221206183326077](oracle19cRACaddnodes\image-20221206183326077.png)



#Close

![image-20221206183956197](oracle19cRACaddnodes\image-20221206183956197.png)



### 安装数据库软件

#oracle

```bash
cd $ORACLE_HOME/addnode
./addnode.sh "CLUSTER_NEW_NODES={db-rac03}"
````

![image-20221206184844737](oracle19cRACaddnodes\image-20221206184844737.png)



#SSH connectivity---Test

![image-20221206194215578](oracle19cRACaddnodes\image-20221206194215578.png)



#submit

![image-20221206194458335](oracle19cRACaddnodes\image-20221206194458335.png)



#开始安装

![image-20221206194617346](oracle19cRACaddnodes\image-20221206194617346.png)



#root.sh脚本

![image-20221206205437288](oracle19cRACaddnodes\image-20221206205437288.png)



#执行完脚本后，点击OK后，结束安装

![image-20221206205612779](oracle19cRACaddnodes\image-20221206205612779.png)



### dbca安装实例

#xterm连接db-rac01的oracle

#dbca

#Oracle RAC databas instnce management

![image-20221206211259921](oracle19cRACaddnodes\image-20221206211259921.png)



#Add an instance

![image-20221206211437142](oracle19cRACaddnodes\image-20221206211437142.png)



#勾选xydb/xydb1/ADMIN_MANAGED，下面填写sys/Ora543Cle

![image-20221206211604110](oracle19cRACaddnodes\image-20221206211604110.png)



#Instance name：xydb3；Node name：db-rac03；下面是xydb1/xydb2/active

![image-20221206211750077](oracle19cRACaddnodes\image-20221206211750077.png)



#Finish

![image-20221206211942288](oracle19cRACaddnodes\image-20221206211942288.png)



#开始安装

![image-20221206212111600](oracle19cRACaddnodes\image-20221206212111600.png)



#Close

![image-20221206212153657](oracle19cRACaddnodes\image-20221206212153657.png)



#集群检查

```
[grid@db-rac01 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.chad
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.net1.network
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
ora.ons
               ONLINE  ONLINE       db-rac01                 STABLE
               ONLINE  ONLINE       db-rac02                 STABLE
               ONLINE  ONLINE       db-rac03                 STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.FRA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.OCR.dg(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 Started,STABLE
      2        ONLINE  ONLINE       db-rac02                 Started,STABLE
      3        ONLINE  ONLINE       db-rac03                 Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
      3        ONLINE  ONLINE       db-rac03                 STABLE
ora.cvu
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac01.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.db-rac02.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.db-rac03.vip
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.qosmserver
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       db-rac02                 STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       db-rac03                 STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       db-rac01                 STABLE
ora.xydb.db
      1        ONLINE  ONLINE       db-rac01                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      2        ONLINE  ONLINE       db-rac02                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
      3        ONLINE  ONLINE       db-rac03                 Open,HOME=/u01/app/o
                                                             racle/product/19.0.0
                                                             /db_1,STABLE
ora.xydb.s_portal.svc
      1        ONLINE  ONLINE       db-rac01                 STABLE
      2        ONLINE  ONLINE       db-rac02                 STABLE
--------------------------------------------------------------------------------
[grid@db-rac01 ~]$ 
```

