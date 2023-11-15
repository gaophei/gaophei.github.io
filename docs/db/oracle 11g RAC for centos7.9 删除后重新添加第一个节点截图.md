                                                                   **11gRAC添加第一个节点**
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

#xterm连接rac2的oracle

#dbca

#Oracle RAC database

![image-20231019115852063](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019115852063.png)

#Instance Management

![image-20231019120035531](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120035531.png)



#Add an instance

![image-20231019120111292](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120111292.png)



#选中CasDb--active---Admin-Managed---Running

#sys/Ora678Cle

![image-20231019120332042](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120332042.png)



#确认当前是rac2:CasDb2 ----active，然后点击Next

![image-20231019120433001](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120433001.png)



#查看实例名和node名：CasDb1---rac1

![image-20231019120600365](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120600365.png)



#点击Finish开始安装

![image-20231019120656617](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120656617.png)



#确认信息，点击OK

![image-20231019120748835](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120748835.png)



#开始安装

![image-20231019120922724](E:\workpc\git\gitio\gaophei.github.io\docs\db\oracle11gRACaddnodes\image-20231019120922724.png)



#No

#最后点击No结束

