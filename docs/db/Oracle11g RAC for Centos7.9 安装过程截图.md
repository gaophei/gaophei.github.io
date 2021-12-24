## oracle11gR2 RAC安装截图

### GI安装过程

#跳过软件升级

![image-20211222150244735](oracle11gR2RAC\image-20211222150244735.png)



#安装和配置GI

![image-20211222150729011](E:oracle11gR2RAC\image-20211222150729011.png)



#高级安装

![image-20211222150835140](oracle11gR2RAC\image-20211222150835140.png)



#英语/简体中文

![image-20211222151016169](oracle11gR2RAC\image-20211222151016169.png)



#集群名称/scan名称/端口，此处要与/etc/hosts中对应

![image-20211222151905307](oracle11gR2RAC\image-20211222151905307.png)



#此处需添加oracle2的相关信息:oracle2/oracle2-vip

![image-20211222151952957](oracle11gR2RAC\image-20211222151952957.png)



![image-20211222153607319](oracle11gR2RAC\image-20211222153607319.png)



#SSH连接测试

![image-20211222153718824](oracle11gR2RAC\image-20211222153718824.png)



#网卡和用途匹配

![image-20211222153824266](oracle11gR2RAC\image-20211222153824266.png)



#ASM磁盘管理

![image-20211222154432287](oracle11gR2RAC\image-20211222154432287.png)



#磁盘发现目录

![image-20211222154646886](oracle11gR2RAC\image-20211222154646886.png)



#OCR磁盘组，冗余度为Normal，/dev/sdb、/dev/sdc、/dev/sdd三块磁盘

![image-20211222154736693](oracle11gR2RAC\image-20211222154736693.png)



#sys/asmsnmp共用一个密码

![image-20211222155113126](oracle11gR2RAC\image-20211222155113126.png)



#不启用IPMI

![image-20211222155226026](oracle11gR2RAC\image-20211222155226026.png)



#grid group，默认设置

![image-20211222155311598](oracle11gR2RAC\image-20211222155311598.png)



#grid用户的ORACLE_BASE、ORACLE_HOME目录

![image-20211222155419768](oracle11gR2RAC\image-20211222155419768.png)



#Inventory目录

![image-20211222155534412](oracle11gR2RAC\image-20211222155534412.png)



#开始检查

![image-20211222155618352](oracle11gR2RAC\image-20211222155618352.png)



#缺少pdksh，可以忽略

![image-20211222155936759](oracle11gR2RAC\image-20211222155936759.png)



#配置完毕，点击Installer开始安装

![image-20211222160145174](oracle11gR2RAC\image-20211222160145174.png)



#开始安装

![image-20211222160330611](oracle11gR2RAC\image-20211222160330611.png)



#用root账户分别在oracle1/oracle2上执行以下脚本

![image-20211222161307196](oracle11gR2RAC\image-20211222161307196.png)



#如果此处弹框不正常，可以用鼠标拖开

![rootsh弹窗不正常](oracle11gR2RAC\rootsh-mousedoit.png)

#执行root.sh时报错，分别进行处理，然后点击OK

#INS-20802，忽略

![image-20211222172408044](oracle11gR2RAC\image-20211222172408044.png)

#INS-32091忽略

![image-20211222172444865](oracle11gR2RAC\image-20211222172444865.png)

#如果上面两步警告弹窗，鼠标拖动不了，按4次tab键即可切换到下一步选项回车即可。

#安装完成

![image-20211222171914446](oracle11gR2RAC\image-20211222171914446.png)



### ASM磁盘组配置

#asmca

![image-20211222182100376](oracle11gR2RAC\image-20211222182100376.png)



#创建DATA磁盘组

![image-20211222183039732](oracle11gR2RAC\image-20211222183039732.png)



#创建FRA磁盘组

![image-20211222183406202](oracle11gR2RAC\image-20211222183406202.png)



#磁盘组创建完毕

![image-20211222183531019](oracle11gR2RAC\image-20211222183531019.png)


### oracle软件安装过程

#不接受邮件

![image-20211222184621420](oracle11gR2RAC\image-20211222184621420.png)



#YES

![image-20211222190017251](oracle11gR2RAC\image-20211222190017251.png)



#跳过升级

![image-20211222190140682](oracle11gR2RAC\image-20211222190140682.png)



#仅安装数据库软件

![image-20211222190304318](oracle11gR2RAC\image-20211222190304318.png)



#SSH连通测试

![image-20211222190445386](oracle11gR2RAC\image-20211222190445386.png)



#English/简体中文

![image-20211222190658504](oracle11gR2RAC\image-20211222190658504.png)



#企业版安装

![image-20211222190802032](oracle11gR2RAC\image-20211222190802032.png)



#安装路径

![image-20211222190850892](oracle11gR2RAC\image-20211222190850892.png)



#用户组权限

![image-20211222191045088](oracle11gR2RAC\image-20211222191045088.png)



#pdksh和scan name的解析报错，可以忽略

![image-20211222191302791](oracle11gR2RAC\image-20211222191302791.png)



#开始安装

![image-20211222191455493](oracle11gR2RAC\image-20211222191455493.png)



#报错中处理后点击Retry

![img](oracle11gR2RAC\bb.png)

#继续安装

![image-20211222192639499](oracle11gR2RAC\image-20211222192639499.png)



#分别在oracle1/oracle2上用root账户运行root.sh脚本

![image-20211223093943516](oracle11gR2RAC\image-20211223093943516.png)



#安装完毕

![image-20211223094158623](oracle11gR2RAC\image-20211223094158623.png)



### oracle实例安装过程



#安装Oracle RAC database

![image-20211223103026110](oracle11gR2RAC\image-20211223103026110.png)



#创建一个数据库

![image-20211223104113585](oracle11gR2RAC\image-20211223104113585.png)



#General Purpose

![image-20211223104224127](oracle11gR2RAC\image-20211223104224127.png)



#Admin-Managed/xydb/Select All

![image-20211223104426365](oracle11gR2RAC\image-20211223104426365.png)



#EM

![image-20211223105415168](oracle11gR2RAC\image-20211223105415168.png)



#sys等账户密码统一

![image-20211223105534771](oracle11gR2RAC\image-20211223105534771.png)



#数据文件放在+DATA磁盘组

![image-20211223105644958](oracle11gR2RAC\image-20211223105644958.png)



#输入GI时设置的ASMSNMP密码，此弹框需要鼠标拖开

![image-20211223105923281](oracle11gR2RAC\image-20211223105923281.png)



#指定FRA并启动归档

![image-20211223111323405](oracle11gR2RAC\image-20211223111323405.png)



#可以不安装sample schemas

![image-20211223111438511](oracle11gR2RAC\image-20211223111438511.png)



#内存分配，根据实际情况分配

![image-20211223114011443](oracle11gR2RAC\image-20211223114011443.png)



#process

![image-20211223114138985](oracle11gR2RAC\image-20211223114138985.png)



#字符集

![image-20211223114334627](oracle11gR2RAC\image-20211223114334627.png)



#专有模式

![image-20211223114622712](oracle11gR2RAC\image-20211223114622712.png)



#修改logfile，可以添加两组，并更改大小为200M

![image-20211223142148411](oracle11gR2RAC\image-20211223142148411.png)



#点击Finish

![image-20211223142326748](oracle11gR2RAC\image-20211223142326748.png)



#此时有竖线出来的话，可以鼠标拖动

![image-20211223142545993](oracle11gR2RAC\image-20211223142545993.png)



#鼠标拖动后为

![image-20211223142654332](C:\Users\SW\AppData\Roaming\Typora\typora-user-images\image-20211223142654332.png)



#等待安装，如果是竖线，也通过鼠标拖动后可以看到

![image-20211223142753492](oracle11gR2RAC\image-20211223142753492.png)



#执行完毕后，点击Exit

![image-20211223145115448](oracle11gR2RAC\image-20211223145115448.png)





















