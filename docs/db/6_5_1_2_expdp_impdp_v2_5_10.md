#### 6.5.1.2.expdp/impdp逻辑备份与迁移(P1+v2.5.10整合版:主方案+三附选方案+实测存档)

#v2.5.10变更记录(2026-07-15):
#1)新增rsync依赖预检:四套生产脚本预检段统一加入本地各节点与异地备份机的rsync存在性检查——
#2026-07-15 oracle01/02现场首跑(附选一rootfs)三PDB导出全部成功但三台均未装rsync,同步段全FAIL(见6.5.1.2.9);
#2)(C)/(D)部署步骤补rsync安装与两端依赖集中确认;常见错误闭环新增"rsync未找到"条目(含免重导补传流程);
#3)(F)补estimate=statistics低估警示:统计信息陈旧时最高低估≈3倍(实测),空间规划按估算×3上浮或blocks交叉验证;
#4)新增6.5.1.2.9实测记录存档(2026-07-15,附选方案一rootfs现场验证:oracle01/02双节点,含补传闭环与性能数据);
#5)验收标准增补第18条(依赖命令预检);
#6)执行账号策略定型:导出/导入默认统一以SYSTEM连接各PDB服务名执行(2026-07-15现场实测依据,见6.5.1.2.9)——
#(E)目录授权、(F)与6.5.1.2.2模板、四套脚本PDB_CONFIGS已同步改为system;非SYSTEM账号路径降级为附选
#(核查1/核查2即其适用场景),6.5.1.2.8历史存档(pdbadmin等混合账号形态)保持原貌不改写;
#7)新增6.5.1.2.10:空PDB全量恢复演练标准流程与实测存档(2026-07-15,portal 894M dump跨环境还原,
#107表行数逐一对齐、INVALID=0,验证通过)——验收第16条季度演练的标准执行路径;
#常见错误闭环ORA-01017条目补UDI-01017秒判特征(parfile截断而sqlplus命令行可登录)。

#v2.5.9变更记录:
#1)本版为整合版:合并v2.5.7(实测验证的主方案)与v2.5.8(附选方案完整化),
#形成单一自包含章节——四种存储/落点形态各自成篇,含完整执行步骤与可直接复制的生产脚本;
#2)主方案脚本自v2.5.7起无功能变更;附选方案一补齐完整脚本;实测记录存档(6.5.1.2.8)收录原始日志;
#3)验证状态:主方案已于2026-07-14在k8s-19rac01/02/03(xydb,四PDB)完成全链路实测,
#整改后全量运行PASS=4 FAIL=0;附选方案二的srvctl modify语法待测试窗口实测确认(见P5备注)。

#方案选型对照(先选型,再翻对应小节):

```log
#  主方案(6.5.1.2.1~6.5.1.2.4):SCAN+事后落点探测+三节点本地LV暂存+异地为准。

#    条件:三节点各一份LV、三节点到异地免密。已实测验证,默认选择。

#  附选一(6.5.1.2.5):根分区暂存。最快就位,无需新盘/服务/NFS;与OS共盘风险最高,仅限过渡。

#  附选二(6.5.1.2.6):落点钉死(VIP/singleton)。只需一份LV+一份异地免密;

#    需维护s_dp_*服务,执行节点宕机备份中断。

#  附选三(6.5.1.2.7):共享NFS。彻底落点无关、运维最省心;引入NFS可用性依赖,须soft挂载加固。
```

#定位:
#1)Data Pump不能替代RMAN物理备份,只用于逻辑备份、对象级恢复、跨库迁移、上线前快照。
#2)本节要求按PDB分别导出,每个PDB生成独立dump/log/status目录,便于单PDB抽取恢复和异地留存。
#3)架构(主方案):本地暂存+异地为准。dump/log先写入落点节点本地独立LV(非根分区、非+FRA),
#随后由落点节点rsync到172.18.13.135:/data并做远端校验;备份成功语义=异地校验通过,本地副本仅短期暂存(2天)。
#导出环节不依赖NFS;网络或异地服务器故障时当晚任务判FAIL并告警,次日修复后补传即可(本地2天即补传窗口)。
#已知裸露窗口:导出完成至异地校验完成期间(分钟级),落点节点整机损毁会丢失当晚逻辑备份,由6.5.1.1 RMAN物理备份兜底。
#4)落点策略(主方案):连接串走SCAN,负载均衡决定会话落点,dump由该实例所在节点服务端进程按DIRECTORY路径写盘;
#`cluster=n`保证单次导出的全部文件集中在落点这一个节点。落点不可预测但可探测:
#expdp返回后按DATE_TAG文件名逐节点find确认落点,后续日志校验、异地推送均定向到落点节点执行。
#实测验证:四轮6次落点覆盖三个节点、逐PDB独立分布,探测恰一命中率100%(见6.5.1.2.8)。
#由此产生两条硬性前提:①三个节点都必须有/backup/expdp独立LV且空间达标;②三个节点oracle都必须有到异地服务器的免密。
#注意:事前查SERVER_HOST对SCAN无效(查询会话与expdp会话是两次独立连接),探测必须事后做。
#5)本环境异地备份服务器:172.18.13.135(<EXPDP_REMOTE_HOST>),异地目录:/data(<EXPDP_REMOTE_DIR>)。该目录必须位于数据库集群故障域之外。
#6)任何cron脚本必须有并发锁、状态文件、日志检查、失败告警、异地同步校验和保留策略。
#7)安全边界:不推荐把口令直接写在命令行中,因为`ps`可见;生产优先使用Oracle Wallet/SEPS。
#若暂未配置wallet,至少使用600权限parfile并限制脚本/目录权限,且只写占位符不写真实口令;
#parfile用后立即抹除userid行——手工操作同样强制,漏抹的parfile一旦随目录归档外传即口令泄露(实测发生过一次,已处置)。
#8)许可边界:compression=all需要Advanced Compression Option许可,且违规使用不会报错;未确认许可前一律使用metadata_only。
#9)一致性边界:expdp默认只保证单表一致;凡用于迁移或快照,必须加flashback_time=systimestamp,并确保undo空间/undo_retention足够,否则可能报ORA-01555。

##### 6.5.1.2.1.主方案部署:三节点本地LV、免密与权限

```bash
#-----(A)三节点各自建立本地独立LV-----
#实测教训(2026-07-14):磁盘被直接扩容进根分区(centos-root)时,/backup/expdp落在/上,
#会被脚本预检整体拦截;full=y撑爆根分区的后果是OS/GI受损,必须独立LV。
#实测报错(预检拦截,状态文件):
#  FAIL 2026-07-14 12:17:47 k8s-19rac01:/backup/expdp mountpoint=/, expected /backup/expdp; LV not mounted?

#红线(先于一切操作):RAC节点上lsblk看到的"无分区无挂载"裸盘极可能是ASM共享磁盘,
#对ASM成员盘执行pvcreate会直接损毁磁盘组,属灾难级事故。pvcreate前必须核对:
su - grid
asmcmd lsdsk
#或 sqlplus / as sysasm: select path,name,group_number,header_status from v$asm_disk order by path;
#再从OS侧确认候选盘无任何签名(两条命令输出为空才是真空闲盘):
blkid /dev/<DISK>; wipefs -n /dev/<DISK>
#虚拟化环境下若无空闲盘,从平台为每节点新挂一块盘(virtio环境出现为vdc等),不要动存量共享盘。

#三节点各执行(<DISK>为核实过的空闲盘;单节点容量按(F)实测×本地保留天数(2天)×1.2,
#且按"全量都落本节点"的最坏情况留,三节点容量一致规划):
pvcreate <DISK>
vgcreate vg_backup <DISK>
lvcreate -l 100%FREE -n lv_expdp vg_backup
mkfs.xfs /dev/vg_backup/lv_expdp

#迁移已有内容:先移开旧目录再挂载。禁止直接mount覆盖——旧文件会被藏在挂载点之下,
#持续占用根分区空间且无法访问。
mv /backup/expdp /backup/expdp.old 2>/dev/null
mkdir -p /backup/expdp
cp /etc/fstab /etc/fstab.bak.$(date +%F)
echo "/dev/vg_backup/lv_expdp /backup/expdp xfs defaults,noatime 0 0" >> /etc/fstab
mount -a
[ -d /backup/expdp.old ] && cp -a /backup/expdp.old/. /backup/expdp/
mkdir -p /backup/expdp/{stuwork,portal,onecode,dataassets}
chown -R oracle:oinstall /backup/expdp
chmod 750 /backup/expdp /backup/expdp/{stuwork,portal,onecode,dataassets}
df -P /backup/expdp | awk 'NR==2{print $6}'   #必须输出/backup/expdp
#确认内容无遗漏后清理: rm -rf /backup/expdp.old

#三节点集中校验(在驱动节点oracle用户执行):
for h in k8s-19rac01 k8s-19rac02 k8s-19rac03; do
  echo "==== ${h} ===="
  ssh -o BatchMode=yes ${h} "df -P /backup/expdp | awk 'NR==2{print \$6}'"
  ssh -o BatchMode=yes ${h} "for p in stuwork portal onecode dataassets; do touch /backup/expdp/\${p}/.rwtest && rm -f /backup/expdp/\${p}/.rwtest; done && echo ${h} rw OK"
done
#验收:三节点挂载点均输出/backup/expdp(输出/即为落在根分区,不通过);三节点均rw OK。
#重要:本架构下任一节点缺目录,会话落到该节点时expdp报ORA-39002,当晚随机失败——目录必须三节点齐备。
```

```bash
#-----(B)节点间免密确认(探测与定向操作的前提)-----
#RAC安装时grid/oracle的SSH用户等效性通常已配置,这里只做确认,不重建:
for h in k8s-19rac01 k8s-19rac02 k8s-19rac03; do
  ssh -o BatchMode=yes -o ConnectTimeout=10 ${h} "hostname" || echo "FAIL: 到${h}的oracle免密不可用,需先修复用户等效性"
done
```

```bash
#-----(C)异地备份服务器准备:在172.18.13.135上以root执行-----
#建立专用备份接收用户(禁止直接用root收备份);用户名与占位符<EXPDP_REMOTE_USER>保持一致,本环境为backup
id backup >/dev/null 2>&1 || useradd -m -s /bin/bash backup
mkdir -p /data/xydb/expdp/{stuwork,portal,onecode,dataassets}
chown -R backup:backup /data/xydb/expdp
chmod -R 750 /data/xydb/expdp
rpm -q rsync || yum install -y rsync   #rsync需两端都有二进制,备份机必装(2026-07-15实测教训,见6.5.1.2.9)
df -h /data
#容量要求(依据2026-07-14实测):单轮全量≈15.1G/日,保留14天稳态≈212G,/data可用空间不得低于250G;
#不足则扩容,或单独收短最大PDB(stuwork)的保留天数。
```

```bash
#-----(D)三节点到异地服务器的免密:在每个节点的oracle登录shell内各执行一遍-----
#同步语义=谁接住谁推送,因此三个节点都必须能免密到异地,缺一不可。
#注意:变量不得跨su定义,以下命令全部在su - oracle之后的shell内执行。
su - oracle
REMOTE_USER=backup
REMOTE_HOST=172.18.13.135
REMOTE_BASE=/data
#已有密钥则复用,避免覆盖可能已用于其它用途的key
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}
ssh -o BatchMode=yes ${REMOTE_USER}@${REMOTE_HOST} \
  "mkdir -p ${REMOTE_BASE}/xydb/expdp/.check && rmdir ${REMOTE_BASE}/xydb/expdp/.check && echo $(hostname -s) remote rw OK"
exit

#三节点全部配置后,在驱动节点集中验收:
for h in k8s-19rac01 k8s-19rac02 k8s-19rac03; do
  ssh -o BatchMode=yes ${h} "ssh -o BatchMode=yes backup@172.18.13.135 hostname" \
    && echo "${h} -> 异地免密 OK" || echo "FAIL: ${h}到异地免密不可用"
done

#依赖命令集中确认(2026-07-15实测教训:rsync缺失时导出照常成功、同步段全FAIL,只能事后补传,见6.5.1.2.9):
for h in k8s-19rac01 k8s-19rac02 k8s-19rac03; do
  ssh -o BatchMode=yes ${h} "command -v rsync >/dev/null" && echo "${h} rsync OK" || echo "FAIL: ${h}缺rsync,yum install -y rsync"
done
ssh -o BatchMode=yes backup@172.18.13.135 "command -v rsync >/dev/null" && echo "remote rsync OK" || echo "FAIL: 异地缺rsync"
#rsync需连接两端都有二进制,任一端缺失即失败,故三节点与异地必须全部确认。
```

```sql
-----(E)测试前权限与账号形态核查:在CDB root以sys/system执行-----
--执行账号策略(v2.5.10定型,2026-07-15现场实测依据):导出与导入默认统一以SYSTEM连接各PDB服务名执行。
--依据:①SYSTEM在各PDB持有DBA,内含DATAPUMP_EXP/IMP_FULL_DATABASE,full=y导出与恢复演练导入均够用;
--②DBA带UNLIMITED TABLESPACE,master table建于SYSTEM默认表空间不触发ORA-01950(核查2针对的是无配额
--应用账号,DBA账号天然豁免);③统一账号使各PDB parfile模板完全同构,并整类消除ORA-31631/ORA-01950权限型失败。
--业务schema只是被导出对象(full=y自动涵盖;改SCHEMAS=精确导出也只是参数变化),不需要任何执行侧授权。
--禁止以SYS(as sysdba)执行Data Pump。核查1/核查2保留为附选路径:仅当现场安全基线禁止例行使用SYSTEM、
--改用应用账号或专用账号执行时才需走其整改流程;账号盘点查询本身仍建议每现场跑一遍留痕。
--中期目标态:建最小权限专用账号(如DP_BACKUP:仅两只DATAPUMP角色+目录读写+独立默认表空间),
--与SYSTEM口令轮换解耦,随wallet/SEPS改造一并落地。

--核查1(附选路径:改用非DBA账号执行时必查;默认SYSTEM执行时自动满足):
--非DBA导出账号full=y必须具备DATAPUMP_EXP_FULL_DATABASE,否则报ORA-31631/权限不足
select con_id, grantee, granted_role
from cdb_role_privs
where grantee in ('SYSTEM','PORTALUSER','ONECODEUSER','PDBADMIN')
  and granted_role in ('DBA','PDB_DBA','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE')
order by con_id, grantee;

--核查2(附选路径:改用非DBA账号执行时必查;实测教训详见6.5.1.2.8案例):非DBA导出账号默认表空间不得为SYSTEM,
--否则Data Pump建master table报ORA-31633/ORA-01950
select con_id, username, default_tablespace
from cdb_users
where username in ('SYSTEM','PORTALUSER','ONECODEUSER','PDBADMIN')
order by con_id;
--验收:除SYSTEM账号外,应用账号default_tablespace均为其应用表空间;
--若为SYSTEM(常见于建库时漏建应用表空间的空schema),先建应用表空间再修正,不要授DBA绕过:
--  create tablespace <APP_TS> datafile '+DATA' size 1G autoextend on next 1G maxsize 31G
--    extent management local segment space management auto;
--  alter user <用户> default tablespace <APP_TS> quota unlimited on <APP_TS>;
```

```sql
--在每个需要导出的PDB中创建同名DIRECTORY对象。不要在CDB root误建目录后就认为PDB可用。
--DIRECTORY路径为各节点本地同名路径:会话落在哪个节点,就写哪个节点的/backup/expdp/<PDB>,
--这正是(A)要求三节点目录/LV齐备的原因。
--授权对象:默认统一授予执行账号SYSTEM;业务schema只是被导出对象,不需要目录权限。

alter session set container=stuwork;
create or replace directory EXPDP_DIR as '/backup/expdp/stuwork';
grant read,write on directory EXPDP_DIR to system;

alter session set container=portal;
create or replace directory EXPDP_DIR as '/backup/expdp/portal';
grant read,write on directory EXPDP_DIR to system;

alter session set container=onecode;
create or replace directory EXPDP_DIR as '/backup/expdp/onecode';
grant read,write on directory EXPDP_DIR to system;

alter session set container=dataassets;
create or replace directory EXPDP_DIR as '/backup/expdp/dataassets';
grant read,write on directory EXPDP_DIR to system;

--注意:create or replace directory保留既有对象授权(SQL Reference:OR REPLACE即为重定义目录路径
--而无需drop/重建/重新授权而设),重复grant幂等无害;
--复核: select grantee,privilege from dba_tab_privs where table_name='EXPDP_DIR';
--若由SYSTEM自建目录,创建者自动获得读写,勿再grant给自己(报ORA-01749);
--OS路径大小写敏感,DIRECTORY路径须与实建目录完全一致。
--(附选)现场安全基线禁止例行使用SYSTEM时,目录读写授予实际执行账号,并补授DATAPUMP_EXP_FULL_DATABASE
--(承担导入再补DATAPUMP_IMP_FULL_DATABASE),且必须通过核查2(默认表空间非SYSTEM),例如:
--  grant read,write on directory EXPDP_DIR to portaluser;
--  grant DATAPUMP_EXP_FULL_DATABASE to portaluser;

--验收:在CDB root执行一次,直接核对全部PDB
alter session set container=cdb$root;
select con_id, directory_name, directory_path
from cdb_directories
where directory_name='EXPDP_DIR'
order by con_id;
--验收:四条记录,directory_path必须分别为 /backup/expdp/<PDB>,禁止全部指向扁平的/backup/expdp
```

```bash
#-----(F)首测前体量摸底:estimate_only不产生dump,用于确定各节点LV容量与脚本MIN_FREE_GB-----
su - oracle
umask 077
cat > /tmp/est_dataassets.par <<EOF
userid=system/"<SYS_PWD>"@172.18.13.176:1521/s_dataassets
full=y
estimate_only=y
estimate=statistics
cluster=n
EOF
chmod 600 /tmp/est_dataassets.par
expdp parfile=/tmp/est_dataassets.par
rm -f /tmp/est_dataassets.par
#对四个PDB各跑一次,记录估算总量;
#每节点LV容量与MIN_FREE_GB按"四PDB估算总量×LOCAL_RETENTION_DAYS(2天)"的1.2倍规划(最坏情况全落同一节点)。
#本环境实测参考(2026-07-14,metadata_only):stuwork≈15G,portal≈4.3M,onecode≈4.2M,dataassets≈4.3M,合计≈15.1G/轮。
#注意:estimate基于段大小,metadata_only压缩下dump接近估算值,不要按compression=all的压缩率估算空间。
#偏差警示(2026-07-15 oracle01/02现场实测,见6.5.1.2.9):estimate=statistics强依赖统计信息新旧,
#统计陈旧时严重低估——该现场三PDB估算2.7G/0.83G/17.9G,实际dump 5.8G/0.89G/53G,最高低估≈3倍。
#空间规划(LV容量/MIN_FREE_GB/异地容量)一律按估算×3上浮,或用estimate=blocks交叉验证,并以首跑实际值回头复核。
```

##### 6.5.1.2.2.按PDB手工导出/导入模板(含事后落点探测)

```bash
#示例:导出dataassets PDB,连接走SCAN;导出完成后逐节点探测落点,再由落点节点推送异地。
#生产优先使用wallet连接;未配置wallet时,使用600权限parfile,parfile内只写占位符,真实口令由保密渠道替换。
#口令统一双引号包裹(容忍#、@;冒号与双引号仍禁止);"用后立即sed抹除userid行"为强制步骤。
umask 077
DATE_TAG=$(date +%Y%m%d_%H%M%S)
PDB_DIR=/backup/expdp/dataassets
RAC_NODES="k8s-19rac01 k8s-19rac02 k8s-19rac03"

cat > ${PDB_DIR}/expdp_dataassets_${DATE_TAG}.par <<EOF
userid=system/"<SYS_PWD>"@172.18.13.176:1521/s_dataassets
full=y
directory=EXPDP_DIR
dumpfile=dataassets_${DATE_TAG}_%U.dmp
logfile=dataassets_${DATE_TAG}.log
job_name=EXPDP_DATAASSETS_${DATE_TAG}
filesize=20G
parallel=2
compression=metadata_only
flashback_time=systimestamp
cluster=n
metrics=y
logtime=all
EOF
chmod 600 ${PDB_DIR}/expdp_dataassets_${DATE_TAG}.par
expdp parfile=${PDB_DIR}/expdp_dataassets_${DATE_TAG}.par
#强制步骤,不得省略:无论成败,立即抹除口令行;parfile其余内容保留供排障。
#实测教训:手工流程漏抹的parfile随目录归档外传即口令泄露。
sed -i '/^userid=/d' ${PDB_DIR}/expdp_dataassets_${DATE_TAG}.par
#手工操作后必查:
grep -rl '^userid=' /backup/expdp --include='*.par' && echo "FAIL: parfile仍含口令行,立即处置" || echo "OK: parfile无口令残留"

#事后落点探测:按DATE_TAG逐节点找dump;tree适合人工核对,脚本判定用find/ls
for h in ${RAC_NODES}; do echo "==== ${h} ===="; ssh -o BatchMode=yes ${h} "tree -L 2 /backup/expdp/ 2>/dev/null || find /backup/expdp -maxdepth 2 -type f"; done

LANDED=""
for h in ${RAC_NODES}; do
  if ssh -o BatchMode=yes ${h} "ls ${PDB_DIR}/dataassets_${DATE_TAG}_*.dmp >/dev/null 2>&1"; then
    LANDED="${LANDED} ${h}"
  fi
done
LANDED=$(echo ${LANDED})
echo "落点节点: [${LANDED}]"
#必须恰好一个节点;为空=导出未产出文件,多个=异常,均不得继续同步

#由落点节点推送异地并校验(前提:该节点已完成(D)免密)
ssh -o BatchMode=yes ${LANDED} \
  "rsync -av --partial --timeout=300 ${PDB_DIR}/dataassets_${DATE_TAG}_*.dmp ${PDB_DIR}/dataassets_${DATE_TAG}.log backup@172.18.13.135:/data/xydb/expdp/dataassets/"
ssh -o BatchMode=yes backup@172.18.13.135 \
  "test -s /data/xydb/expdp/dataassets/dataassets_${DATE_TAG}.log && ls /data/xydb/expdp/dataassets/dataassets_${DATE_TAG}_*.dmp" \
  && echo "REMOTE OK" || echo "REMOTE FAIL:异地校验未通过,本次备份不算成功"

#导入:dump在哪个节点/异地都可导入,只要文件位于目标会话落点节点的EXPDP_DIR路径下。
#手工导入建议直接连文件所在节点的VIP(导入走SCAN时落点同样随机,落点节点无dump会报ORA-39002/ORA-31640)。
#空PDB全量恢复演练(验收第16条季度演练)的完整标准流程与判定口径见6.5.1.2.10。
cat > ${PDB_DIR}/impdp_dataassets_${DATE_TAG}.par <<EOF
userid=system/"<SYS_PWD>"@172.18.13.176:1521/s_dataassets
directory=EXPDP_DIR
dumpfile=dataassets_${DATE_TAG}_%U.dmp
logfile=impdp_dataassets_${DATE_TAG}.log
full=y
table_exists_action=skip
cluster=n
metrics=y
logtime=all
EOF
chmod 600 ${PDB_DIR}/impdp_dataassets_${DATE_TAG}.par
impdp parfile=${PDB_DIR}/impdp_dataassets_${DATE_TAG}.par
sed -i '/^userid=/d' ${PDB_DIR}/impdp_dataassets_${DATE_TAG}.par
```

#常见错误闭环:
#- 探测发现0个节点有dump: 导出实际未产出(看客户端输出与RC);常见于落点节点DIRECTORY路径缺失(ORA-39002)
#——回查(A)三节点目录是否齐备。
#- 探测发现多个节点有dump: 不符合cluster=n预期,人工核对是否误开cluster=y或存在历史同名残留,处理前不要清理任何一份。
#- ORA-31633+ORA-01950(tablespace 'SYSTEM')【2026-07-14实测案例,完整日志见6.5.1.2.8】:
#发起用户的默认表空间被误设为SYSTEM且无配额,Data Pump无法在其默认表空间创建master table,认证成功后建job即失败。
#识别特征(可秒判):expdp在1~2秒内rc=1退出;任何节点均无dump/log产出;
#sqlplus同账号可正常登录且"Last Successful login time"恰为expdp执行时刻(证明失败在认证之后)。
#修复:`alter user <用户> default tablespace <APP_TS> quota unlimited on <APP_TS>;`
#禁止用"授DBA"或"给SYSTEM配额"的方式绕过。master table在job结束时自动删除,修复无残留。预防:(E)核查2。
#- 导入报ORA-39002/ORA-31640: 导入会话落点节点上没有dump文件;连文件所在节点VIP导入,或先把dump放到导入落点节点的EXPDP_DIR。
#- full=y权限: 若导出账号不是DBA,必须在对应PDB授予DATAPUMP_EXP_FULL_DATABASE角色((E)核查1)。
#- ORA-01017/UDI-01017(口令含#)【2026-07-15实测,见6.5.1.2.10】: parfile中#为注释符,裸写口令自#起截断;
#必须用双引号包裹口令(模板中system/"<SYS_PWD>"的双引号即为此,替换真实口令时保留)。
#秒判特征:同一连接串sqlplus命令行可正常登录(shell不把行中#当注释,且此登录会刷新Last Successful login time)
#而impdp/expdp用parfile报ORA-01017,即可断定parfile截断,无需怀疑口令本身。
#- ORA-31626/ORA-31633(非SYSTEM表空间场景): 检查master table创建权限、默认表空间、目录权限与剩余空间。
#- ORA-01555(启用flashback_time后): undo不足以维持一致性快照;增大undo表空间/undo_retention,或把导出窗口移到写入低谷。
#- compression=all许可: 未购Advanced Compression时不会报错但违规;许可未确认前保持metadata_only。
#- dump跨版本: 高版本导向低版本时加`version=<目标版本>`。
#- 异地rsync失败: 当晚判FAIL属预期行为;修复后到落点节点手工补rsync并重做远端校验,不要删除本地当日dump(本地保留2天即为补传窗口)。
#- rsync: 未找到命令【2026-07-15实测案例,完整闭环见6.5.1.2.9】: rsync需连接两端都有二进制,任一端缺失则
#导出照常成功、同步段必FAIL(driver日志内嵌bash报错,易误判为网络/免密问题)。dump有效,无需重导:
#两端装rsync后到落点节点手工补传(rsync -av --partial [--bwlimit=白天限速] 本地PDB目录/ 远端PDB目录/),
#rsync -avc --dry-run两端校验一致后回写状态文件留痕。预防:依赖预检已入四套脚本(v2.5.10)与(C)/(D)部署步骤。

##### 6.5.1.2.3.主方案生产脚本(完整,直接复制可用)

```bash
cat > /home/oracle/expdp_pdb_backup_lvm.sh <<'EOF'
#!/bin/bash
#expdp_pdb_backup_lvm.sh —— 主方案:SCAN导出+落点探测+三节点独立LV暂存+异地为准
#2026-07-14实测验证:全量运行PASS=4 FAIL=0
umask 077
source /home/oracle/.bash_profile
set -u
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8   #固定消息语言,保证successfully completed校验可靠

#=====按现场修改区=====
DB_UNIQUE_NAME="xydb"
EXPECTED_HOST="k8s-19rac01"              #cron部署节点(仅驱动脚本;dump落点由SCAN决定,与本值无关)
RAC_NODES=("k8s-19rac01" "k8s-19rac02" "k8s-19rac03")   #全部RAC节点
CONNECT_HOST="172.18.13.176"             #SCAN地址,落点随机,事后探测
LISTENER_PORT="1521"
EXP_DIR="EXPDP_DIR"
BASE_DIR="/backup/expdp"
EXPECTED_MOUNT="/backup/expdp"           #三节点统一的独立LV挂载点;若整个/backup为独立文件系统则改为/backup
LOCAL_RETENTION_DAYS=2                   #本地仅暂存,兼作异地同步失败后的补传窗口
REMOTE_RETENTION_DAYS=14                 #异地为权威副本
REMOTE_USER="backup"                     #禁止使用root
REMOTE_HOST="172.18.13.135"
REMOTE_BASE="/data"
CONNECT_MODE="password"                  #生产优先改为wallet,CONNECT_STRING自动切换/@service
COMPRESSION_MODE="metadata_only"         #compression=all需Advanced Compression许可,确认已购后方可改为all
MIN_FREE_GB=100                          #按(F)estimate实测与本地保留天数调整;本环境实测15.1G/轮×2天,100G留有余量
#格式:PDB_NAME:SERVICE:ADMIN_USER:PASSWORD_PLACEHOLDER:PARALLEL
#执行账号默认统一system(v2.5.10);改用其他账号须先通过(E)核查1/核查2
#口令以双引号写入parfile,容忍#、@;冒号(字段分隔符)与双引号禁止,含之必须wallet
PDB_CONFIGS=(
  "stuwork:s_stuwork:system:<SYS_PWD>:2"
  "portal:s_portal:system:<SYS_PWD>:2"
  "onecode:s_onecode:system:<SYS_PWD>:2"
  "dataassets:s_dataassets:system:<SYS_PWD>:2"
)
#=====按现场修改区结束=====

DATE_TAG=$(date +%Y%m%d_%H%M%S)
SUMMARY_STATUS="${BASE_DIR}/last_expdp_status"
SUMMARY_LOG="${BASE_DIR}/expdp_driver_${DATE_TAG}.log"
PASS=0
FAIL=0
LOCAL_HOST=$(hostname -s)
mkdir -p "${BASE_DIR}"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "${SUMMARY_LOG}"; }
die(){ echo "FAIL $(date '+%F %T') $*" | tee "${SUMMARY_STATUS}" >&2; exit 1; }
write_status(){ local pdb="$1" status="$2" msg="$3"; echo "${status} $(date '+%F %T') ${msg}" > "${BASE_DIR}/${pdb}/last_expdp_status"; }
mark_fail(){ local pdb="$1" msg="$2"; FAIL=$((FAIL+1)); write_status "$pdb" "FAIL" "$msg"; log "[FAIL][$pdb] $msg"; }
mark_ok(){ local pdb="$1" msg="$2"; PASS=$((PASS+1)); write_status "$pdb" "OK" "$msg"; log "[OK][$pdb] $msg"; }
rsh(){ local h="$1"; shift; ssh -o BatchMode=yes -o ConnectTimeout=10 "${h}" "$@"; }

#驱动节点断言:防止cron被复制到多个节点重复驱动(与dump落点无关)
[ "${LOCAL_HOST}" = "${EXPECTED_HOST}" ] || die "wrong driver node: ${LOCAL_HOST}, expected ${EXPECTED_HOST}"

#并发锁:防止cron与手工补跑叠跑、或单次任务超长跨天叠跑;锁随脚本退出自动释放
exec 9>"${BASE_DIR}/.expdp.lock"
flock -n 9 || die "another expdp_pdb_backup.sh is running, this run aborted"

[ -w "${BASE_DIR}" ] || die "${BASE_DIR} not writable"

#全节点预检:落点随机,任一节点不达标=当晚随机失败,必须整体拒跑
#校验:①节点可达 ②挂载点为独立LV(防dump写进根分区) ③剩余空间达标
for node in "${RAC_NODES[@]}"; do
  rsh "${node}" true 2>/dev/null || die "node ${node} unreachable via ssh, all-node precheck aborted"
  rsh "${node}" "command -v rsync >/dev/null" || die "rsync missing on ${node}; yum install -y rsync (2026-07-15 lesson)"
  N_MOUNT=$(rsh "${node}" "timeout 15 df -P '${BASE_DIR}'" 2>/dev/null | awk 'NR==2{print $6}')
  [ "${N_MOUNT}" = "${EXPECTED_MOUNT}" ] || die "${node}:${BASE_DIR} mountpoint=${N_MOUNT:-NA}, expected ${EXPECTED_MOUNT}; LV not mounted?"
  N_FREE=$(rsh "${node}" "timeout 15 df -BG --output=avail '${BASE_DIR}'" 2>/dev/null | awk 'NR==2{gsub("G","");print $1}')
  { [ -n "${N_FREE}" ] && [ "${N_FREE}" -ge "${MIN_FREE_GB}" ]; } || die "${node}:${BASE_DIR} free=${N_FREE:-NA}G < MIN_FREE_GB=${MIN_FREE_GB}G"
  log "[PRECHECK][${node}] mount=${N_MOUNT} free=${N_FREE}G OK"
done
#rsync需两端二进制,异地侧同样预检(缺失时导出照常成功但同步段必FAIL,只能事后补传)
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "command -v rsync >/dev/null" || \
  die "rsync missing on remote ${REMOTE_HOST}; install rsync on backup server first"

for item in "${PDB_CONFIGS[@]}"; do
  IFS=':' read -r PDB_NAME PDB_SERVICE ADMIN_USER ADMIN_PWD PARALLEL_DEGREE <<< "${item}"
  PDB_DIR="${BASE_DIR}/${PDB_NAME}"
  mkdir -p "${PDB_DIR}"
  chmod 750 "${PDB_DIR}"
  #注意:Data Pump的dump/log由数据库服务端写入落点节点的EXPDP_DIR路径,与驱动节点无关;
  #parfile是客户端文件,始终留在驱动节点。

  LOG_FILE="${PDB_NAME}_${DATE_TAG}.log"
  DUMP_FILE="${PDB_NAME}_${DATE_TAG}_%U.dmp"
  JOB_NAME="EXPDP_${PDB_NAME^^}_${DATE_TAG}"
  PARFILE="${PDB_DIR}/expdp_${PDB_NAME}_${DATE_TAG}.par"
  REMOTE_DIR="${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp/${PDB_NAME}"

  if [ "${CONNECT_MODE}" = "wallet" ]; then
    CONNECT_STRING="/@${PDB_SERVICE}"
  else
    CONNECT_STRING="${ADMIN_USER}/\"${ADMIN_PWD}\"@${CONNECT_HOST}:${LISTENER_PORT}/${PDB_SERVICE}"
  fi

  log "[START][${PDB_NAME}] service=${PDB_SERVICE} via SCAN, dump=${DUMP_FILE} compression=${COMPRESSION_MODE}"
  cat > "${PARFILE}" <<PAR
userid=${CONNECT_STRING}
full=y
directory=${EXP_DIR}
dumpfile=${DUMP_FILE}
logfile=${LOG_FILE}
job_name=${JOB_NAME}
filesize=20G
parallel=${PARALLEL_DEGREE}
compression=${COMPRESSION_MODE}
flashback_time=systimestamp
cluster=n
metrics=y
logtime=all
PAR
  chmod 600 "${PARFILE}"

  expdp parfile="${PARFILE}" >> "${SUMMARY_LOG}" 2>&1
  RC=$?
  sed -i '/^userid=/d' "${PARFILE}"   #无论成败立即抹除口令行

  if [ ${RC} -ne 0 ]; then
    mark_fail "${PDB_NAME}" "expdp rc=${RC}, parfile=${PARFILE}, driver=${SUMMARY_LOG}"
    continue
  fi

  #落点探测:按DATE_TAG逐节点找dump;要求恰好一个节点命中
  LANDED=""
  MULTI="no"
  for node in "${RAC_NODES[@]}"; do
    if rsh "${node}" "ls ${PDB_DIR}/${PDB_NAME}_${DATE_TAG}_*.dmp >/dev/null 2>&1"; then
      [ -n "${LANDED}" ] && MULTI="yes"
      LANDED="${node}"
    fi
  done
  if [ -z "${LANDED}" ]; then
    mark_fail "${PDB_NAME}" "landing detect: no node holds ${PDB_NAME}_${DATE_TAG} dumps; check DIRECTORY path on all nodes (ORA-39002?)"
    continue
  fi
  if [ "${MULTI}" = "yes" ]; then
    mark_fail "${PDB_NAME}" "landing detect: dumps found on multiple nodes, manual check required (cluster=y? stale files?)"
    continue
  fi
  log "[LANDED][${PDB_NAME}] node=${LANDED}"

  #日志校验(在落点节点上执行)
  if ! rsh "${LANDED}" "test -f '${PDB_DIR}/${LOG_FILE}'"; then
    mark_fail "${PDB_NAME}" "log not found on ${LANDED}:${PDB_DIR}/${LOG_FILE}"
    continue
  fi
  #反向校验:Data Pump即使返回0也要扫描日志中的错误;ORA-31684(对象已存在)仅导入场景可豁免
  if rsh "${LANDED}" "grep -E 'ORA-|UDE-|UDI-' '${PDB_DIR}/${LOG_FILE}' | grep -v 'ORA-31684'" >> "${SUMMARY_LOG}" 2>&1; then
    mark_fail "${PDB_NAME}" "expdp log contains ORA/UDE/UDI on ${LANDED}:${PDB_DIR}/${LOG_FILE}"
    continue
  fi
  #正向校验:必须出现successfully completed(NLS_LANG已固定为英文,消息可靠)
  if ! rsh "${LANDED}" "grep -q 'successfully completed' '${PDB_DIR}/${LOG_FILE}'"; then
    mark_fail "${PDB_NAME}" "no 'successfully completed' on ${LANDED}:${PDB_DIR}/${LOG_FILE}, job may be incomplete"
    continue
  fi

  #异地同步与校验:由落点节点直接推送(前提:三节点到异地免密已就绪);此步通过才算备份成功
  rsh "${LANDED}" "ssh -o BatchMode=yes -o ConnectTimeout=10 ${REMOTE_USER}@${REMOTE_HOST} mkdir -p ${REMOTE_DIR}" >> "${SUMMARY_LOG}" 2>&1
  if [ $? -ne 0 ]; then
    mark_fail "${PDB_NAME}" "export OK on ${LANDED} but remote mkdir failed; retransfer within ${LOCAL_RETENTION_DAYS}d"
    continue
  fi
  rsh "${LANDED}" "rsync -av --partial --timeout=300 ${PDB_DIR}/${PDB_NAME}_${DATE_TAG}_*.dmp ${PDB_DIR}/${LOG_FILE} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" >> "${SUMMARY_LOG}" 2>&1
  if [ $? -ne 0 ]; then
    mark_fail "${PDB_NAME}" "export OK on ${LANDED} but rsync to ${REMOTE_HOST}:${REMOTE_DIR} failed; retransfer within ${LOCAL_RETENTION_DAYS}d"
    continue
  fi
  #远端至少应能看到本PDB当日log和一个dump片段(驱动节点自身也有异地免密,直接校验)
  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
    "test -s '${REMOTE_DIR}/${LOG_FILE}' && ls '${REMOTE_DIR}/${PDB_NAME}_${DATE_TAG}_'*.dmp >/dev/null 2>&1" >> "${SUMMARY_LOG}" 2>&1
  if [ $? -ne 0 ]; then
    mark_fail "${PDB_NAME}" "export OK on ${LANDED} but remote validation failed: ${REMOTE_HOST}:${REMOTE_DIR}"
    continue
  fi

  mark_ok "${PDB_NAME}" "landed=${LANDED} local=${LANDED}:${PDB_DIR}/${LOG_FILE}; remote=${REMOTE_HOST}:${REMOTE_DIR}"
done

#本地保留策略(暂存2天):历史落点分散,对全部节点循环清理dmp/log;
#parfile是驱动节点客户端文件且已不含口令,在驱动节点清理(含手工模板的expdp_/impdp_前缀)
for node in "${RAC_NODES[@]}"; do
  rsh "${node}" "find '${BASE_DIR}' -mindepth 2 -maxdepth 2 \( -name '*.dmp' -o -name '*.log' \) -mtime +${LOCAL_RETENTION_DAYS} -type f -delete" >> "${SUMMARY_LOG}" 2>&1 || \
    log "[WARN] local retention cleanup failed on ${node}, manual check required"
done
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.par' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -maxdepth 1 -name 'expdp_driver_*.log' -mtime +7 -type f -delete

#远端保留策略(权威副本14天):只删除本目录下过期dmp/log,不要删除其他备份类型
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
  "find '${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp' -type f \( -name '*.dmp' -o -name '*.log' \) -mtime +${REMOTE_RETENTION_DAYS} -delete" >> "${SUMMARY_LOG}" 2>&1 || \
  log "[WARN] remote retention cleanup failed, manual check required"

if [ ${FAIL} -eq 0 ]; then
  echo "OK $(date '+%F %T') PASS=${PASS} FAIL=0 remote=${REMOTE_HOST}:${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] OK PASS=${PASS} FAIL=0"; exit 0
else
  echo "FAIL $(date '+%F %T') PASS=${PASS} FAIL=${FAIL} remote=${REMOTE_HOST}:${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] FAIL PASS=${PASS} FAIL=${FAIL}"; exit 1
fi
EOF

chmod 700 /home/oracle/expdp_pdb_backup_lvm.sh
chown oracle:oinstall /home/oracle/expdp_pdb_backup_lvm.sh
#若CONNECT_MODE=password,脚本本体集中保存各PDB口令;替换真实口令后必须保持700权限。
#临时注释PDB_CONFIGS中某PDB仅限测试场景且必须当日恢复——被注释PDB无备份而总状态仍OK(见6.5.1.2.4监控)。
```

##### 6.5.1.2.4.cron、监控与验收

```bash
#以下操作全部在驱动节点(k8s-19rac01)oracle用户下执行
su - oracle

#建议先手工实跑,确认所有PDB状态文件和汇总状态文件OK后再进入cron
/home/oracle/expdp_pdb_backup_lvm.sh
cat /backup/expdp/last_expdp_status
for p in stuwork portal onecode dataassets; do cat /backup/expdp/${p}/last_expdp_status; done
#验收参考(2026-07-14实测输出):
#  OK 2026-07-14 15:54:16 landed=k8s-19rac03 local=k8s-19rac03:/backup/expdp/stuwork/stuwork_20260714_153713.log; remote=172.18.13.135:/data/xydb/expdp/stuwork
#  OK 2026-07-14 15:58:49 landed=k8s-19rac01 local=... ; remote=...
#  OK 2026-07-14 16:22:50 landed=k8s-19rac02 local=... ; remote=...
#  OK 2026-07-14 16:02:09 landed=k8s-19rac02 local=... ; remote=...

#确认落点探测记录:driver日志应含[PRECHECK]三节点OK与每个PDB的[LANDED]记录
grep -E '\[PRECHECK\]|\[LANDED\]' /backup/expdp/expdp_driver_*.log | tail -12

#人工核对三节点文件分布(tree便于目视;未装tree的节点自动回退find)
for h in k8s-19rac01 k8s-19rac02 k8s-19rac03; do
  echo "==== ${h} ===="
  ssh -o BatchMode=yes ${h} "tree -L 2 /backup/expdp/ 2>/dev/null || find /backup/expdp -maxdepth 2 -type f | sort"
done

#确认parfile已不含userid行(每次手工操作后必查,不限于上线验收)
grep -rl '^userid=' /backup/expdp --include='*.par' && echo "FAIL: parfile仍含口令行" || echo "OK: parfile无口令残留"

#确认异地服务器已有每个PDB目录和文件
ssh backup@172.18.13.135 'find /data/xydb/expdp -maxdepth 2 -type f | sort | tail -50'

#确认并发锁生效:实跑期间另开会话再次执行脚本,应立即退出且状态文件为"another ... is running"

#cron示例:仅在驱动节点k8s-19rac01启用(脚本内已有EXPECTED_HOST断言双保险)。
#时间必须与6.5.1.1.4的RMAN备份窗口错峰;02:30仅为示例,部署前核对本节点RMAN cron实际时间后再定。
crontab -l > /tmp/oracle.cron.$(date +%F) 2>/dev/null
cat >> /tmp/oracle.cron.$(date +%F) <<EOF
#P1 expdp logical backup by PDB via SCAN with landing detection; authoritative copy at 172.18.13.135:/data; monitor /backup/expdp/last_expdp_status
30 2 * * * /home/oracle/expdp_pdb_backup_lvm.sh >/backup/expdp/expdp_cron.log 2>&1
EOF
crontab /tmp/oracle.cron.$(date +%F)
crontab -l | tail -3
```

```bash
#监控要求(用于捕获驱动节点宕机/cron失效/PDB被遗漏的静默中断):
#1)/backup/expdp/last_expdp_status 首字段为FAIL → 告警;
#2)总状态+四个per-PDB状态文件mtime距今超过25小时 → 告警。
#   实测教训:某PDB被临时注释后,总状态每轮仍刷新为OK,该PDB备份缺失只有per-PDB陈旧检查能发现:
for f in /backup/expdp/last_expdp_status /backup/expdp/{stuwork,portal,onecode,dataassets}/last_expdp_status; do
  [ $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) )) -gt 90000 ] && \
    echo "ALERT: $(dirname $f | xargs basename) expdp status stale >25h"
done
#3)驱动节点计划内长时间停机时,将脚本+cron迁移到另一节点:仅需改EXPECTED_HOST并部署cron
#(无需动数据库服务;新驱动节点须已具备到异地和到各节点的免密——(B)(D)达标即满足)。
```

#验收标准(v2.5.10,共18条):
#1)`/backup/expdp/last_expdp_status`首字段为OK且日期为当天;
#2)`/backup/expdp/stuwork|portal|onecode|dataassets/last_expdp_status`均为OK,且msg中含landed=<节点名>;
#3)driver日志含三节点[PRECHECK]全部OK记录(挂载点=/backup/expdp独立LV+空间达标)与每个PDB的[LANDED]记录;
#4)每个PDB恰好在一个节点生成dump/log(0个或多个节点均为FAIL),路径为/backup/expdp/<PDB>/;
#5)172.18.13.135:/data/xydb/expdp/<PDB>/下存在对应dump/log,远端校验通过——这是备份成功的最终判据;
#6)expdp日志无未解释的ORA-/UDE-/UDI-,且每份日志含"successfully completed";
#7)所有*.par文件不含userid行(每次手工操作后必查);异地目录下无*.par文件;
#8)并发锁验证通过:叠跑第二实例立即退出;非驱动节点执行脚本被EXPECTED_HOST断言拒绝;
#9)三节点到172.18.13.135的oracle免密全部验证通过((D)集中验收命令留档);
#10)(E)执行账号策略核查通过:默认统一SYSTEM执行(各PDB持DBA、目录读写授权确认);若采用附选非SYSTEM账号,
#须具备DATAPUMP_EXP_FULL_DATABASE且default_tablespace非SYSTEM(核查1/核查2留痕);
#11)compression取值与许可一致:未确认Advanced Compression许可前必须为metadata_only,许可证明留档后方可改all;
#12)导出parfile含flashback_time=systimestamp;导出窗口内无ORA-01555,否则调整undo或窗口;
#13)异地/data可用空间≥250G(依据实测15.1G/日×14天+余量),并纳入容量巡检;
#14)监控三项(FAIL告警、总+per-PDB 25小时陈旧告警、驱动节点迁移预案)已对接并演练;
#15)PDB_CONFIGS无测试遗留的注释行;数据库无备份修复过程遗留的高权限闲置账号(有则删除或锁定);
#16)至少每季度从异地服务器抽取一份dump做impdp验证(验证异地副本而非本地暂存),记录写入14.3或恢复演练台账,
#标准流程与判定口径按6.5.1.2.10执行;
#17)生产优先改造为wallet/SEPS;若使用parfile,权限必须为600,且不得把真实口令回填文档;
#测试期间曾明文出现的口令必须完成轮换后方可通过验收;
#18)依赖命令预检通过:rsync已安装于全部本地节点与异地备份机((C)/(D)留痕),脚本预检含两端依赖检查(v2.5.10)。

##### 6.5.1.2.5.附选方案一:根分区暂存(过渡形态,独立LV就位前)

#适用条件:独立LV尚未就位、又需先行备份时的过渡;条件具备后切回主方案,仅需替换脚本本体。
#风险声明:dump与OS/GI共用根分区,爆满后果严重;由脚本"剩余空间+使用率"双重防线兜底,阈值必须保守,宁可拒跑。
#本方案不得长期使用:启用之日起列入技术债台账,LV就位后30日内切换主方案。

#-----步骤复用说明-----
#本方案除(A)外,其余步骤与6.5.1.2.1完全一致,原样执行即可:
#(B)节点间免密确认 / (C)异地备份服务器准备 / (D)三节点到异地免密 /
#(E)权限与账号形态核查+DIRECTORY创建 / (F)estimate体量摸底 → 均复用6.5.1.2.1对应小节
#(A)LV创建 → 不适用,替换为下方(A')

```bash
#-----(A')三节点根分区目录准备与形态基线(替代6.5.1.2.1(A))-----
#三节点各执行:
mkdir -p /backup/expdp/{stuwork,portal,onecode,dataassets}
chown -R oracle:oinstall /backup/expdp
chmod 750 /backup/expdp /backup/expdp/{stuwork,portal,onecode,dataassets}

#三节点集中校验(驱动节点oracle执行;与主方案的区别:不断言挂载点,但记录形态基线)
for h in k8s-19rac01 k8s-19rac02 k8s-19rac03; do
  echo "==== ${h} ===="
  ssh -o BatchMode=yes ${h} "df -hP /backup/expdp | awk 'NR==2{print \$2,\$4,\$5,\$6}'"   #容量/可用/使用率/挂载点,留档
  ssh -o BatchMode=yes ${h} "for p in stuwork portal onecode dataassets; do touch /backup/expdp/\${p}/.rwtest && rm -f /backup/expdp/\${p}/.rwtest; done && echo ${h} rw OK"
done
#部署基线:三节点根分区使用率不得高于70%,可用空间均≥(estimate总量×2天保留×1.5);不满足则不得启用本方案。
```

```bash
#-----完整脚本(直接复制可用)-----
cat > /home/oracle/expdp_pdb_backup_rootfs.sh <<'EOF'
#!/bin/bash
#expdp_pdb_backup_rootfs.sh —— 附选方案一(过渡):/backup/expdp直接位于根分区
#与主方案差异:①不校验挂载点,改为"剩余空间+使用率"双重防线;②每PDB导出前对三节点重检空间。
umask 077
source /home/oracle/.bash_profile
set -u
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

#=====按现场修改区=====
DB_UNIQUE_NAME="xydb"
EXPECTED_HOST="k8s-19rac01"
RAC_NODES=("k8s-19rac01" "k8s-19rac02" "k8s-19rac03")
CONNECT_HOST="172.18.13.176"             #SCAN
LISTENER_PORT="1521"
EXP_DIR="EXPDP_DIR"
BASE_DIR="/backup/expdp"
LOCAL_RETENTION_DAYS=2                   #根分区空间紧张时可降为1
REMOTE_RETENTION_DAYS=14
REMOTE_USER="backup"
REMOTE_HOST="172.18.13.135"
REMOTE_BASE="/data"
CONNECT_MODE="password"
COMPRESSION_MODE="metadata_only"
MIN_FREE_GB=200                          #根分区形态阈值须比独立LV更保守
MAX_USED_PCT=85                          #根分区使用率上限,给OS/GI留安全余量
PDB_CONFIGS=(
  "stuwork:s_stuwork:system:<SYS_PWD>:2"
  "portal:s_portal:system:<SYS_PWD>:2"
  "onecode:s_onecode:system:<SYS_PWD>:2"
  "dataassets:s_dataassets:system:<SYS_PWD>:2"
)
#=====按现场修改区结束=====

DATE_TAG=$(date +%Y%m%d_%H%M%S)
SUMMARY_STATUS="${BASE_DIR}/last_expdp_status"
SUMMARY_LOG="${BASE_DIR}/expdp_driver_${DATE_TAG}.log"
PASS=0
FAIL=0
LOCAL_HOST=$(hostname -s)
mkdir -p "${BASE_DIR}"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "${SUMMARY_LOG}"; }
die(){ echo "FAIL $(date '+%F %T') $*" | tee "${SUMMARY_STATUS}" >&2; exit 1; }
write_status(){ local pdb="$1" status="$2" msg="$3"; echo "${status} $(date '+%F %T') ${msg}" > "${BASE_DIR}/${pdb}/last_expdp_status"; }
mark_fail(){ local pdb="$1" msg="$2"; FAIL=$((FAIL+1)); write_status "$pdb" "FAIL" "$msg"; log "[FAIL][$pdb] $msg"; }
mark_ok(){ local pdb="$1" msg="$2"; PASS=$((PASS+1)); write_status "$pdb" "OK" "$msg"; log "[OK][$pdb] $msg"; }
rsh(){ local h="$1"; shift; ssh -o BatchMode=yes -o ConnectTimeout=10 "${h}" "$@"; }

check_node_space(){
  local node="$1" free pct
  free=$(rsh "${node}" "timeout 15 df -BG --output=avail '${BASE_DIR}'" 2>/dev/null | awk 'NR==2{gsub("G","");print $1}')
  pct=$(rsh "${node}" "timeout 15 df -P '${BASE_DIR}'" 2>/dev/null | awk 'NR==2{gsub("%","");print $5}')
  if [ -z "${free}" ] || [ -z "${pct}" ]; then SPACE_MSG="${node}: df failed or timed out"; return 1; fi
  if [ "${free}" -lt "${MIN_FREE_GB}" ] || [ "${pct}" -gt "${MAX_USED_PCT}" ]; then
    SPACE_MSG="${node}: free=${free}G(min ${MIN_FREE_GB}G) used=${pct}%(max ${MAX_USED_PCT}%)"; return 1
  fi
  SPACE_MSG="${node}: free=${free}G used=${pct}%"; return 0
}

[ "${LOCAL_HOST}" = "${EXPECTED_HOST}" ] || die "wrong driver node: ${LOCAL_HOST}, expected ${EXPECTED_HOST}"
exec 9>"${BASE_DIR}/.expdp.lock"
flock -n 9 || die "another expdp backup is running, this run aborted"
[ -w "${BASE_DIR}" ] || die "${BASE_DIR} not writable"

for node in "${RAC_NODES[@]}"; do
  rsh "${node}" true 2>/dev/null || die "node ${node} unreachable via ssh, all-node precheck aborted"
  rsh "${node}" "command -v rsync >/dev/null" || die "rsync missing on ${node}; yum install -y rsync (2026-07-15 lesson)"
  check_node_space "${node}" || die "precheck space guard: ${SPACE_MSG}"
  log "[PRECHECK][${SPACE_MSG}] OK"
done
#rsync需两端二进制,异地侧同样预检(缺失时导出照常成功但同步段必FAIL,只能事后补传)
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "command -v rsync >/dev/null" || \
  die "rsync missing on remote ${REMOTE_HOST}; install rsync on backup server first"

for item in "${PDB_CONFIGS[@]}"; do
  IFS=':' read -r PDB_NAME PDB_SERVICE ADMIN_USER ADMIN_PWD PARALLEL_DEGREE <<< "${item}"
  PDB_DIR="${BASE_DIR}/${PDB_NAME}"
  mkdir -p "${PDB_DIR}"
  chmod 750 "${PDB_DIR}"

  #每PDB导出前重检全节点空间(串行导出累计占用根分区,必须步步设防)
  SPACE_OK="yes"
  for node in "${RAC_NODES[@]}"; do
    if ! check_node_space "${node}"; then SPACE_OK="no"; break; fi
  done
  if [ "${SPACE_OK}" != "yes" ]; then
    mark_fail "${PDB_NAME}" "per-pdb space guard: ${SPACE_MSG}; skip export to protect root fs"
    continue
  fi

  LOG_FILE="${PDB_NAME}_${DATE_TAG}.log"
  DUMP_FILE="${PDB_NAME}_${DATE_TAG}_%U.dmp"
  JOB_NAME="EXPDP_${PDB_NAME^^}_${DATE_TAG}"
  PARFILE="${PDB_DIR}/expdp_${PDB_NAME}_${DATE_TAG}.par"
  REMOTE_DIR="${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp/${PDB_NAME}"

  if [ "${CONNECT_MODE}" = "wallet" ]; then
    CONNECT_STRING="/@${PDB_SERVICE}"
  else
    CONNECT_STRING="${ADMIN_USER}/\"${ADMIN_PWD}\"@${CONNECT_HOST}:${LISTENER_PORT}/${PDB_SERVICE}"
  fi

  log "[START][${PDB_NAME}] service=${PDB_SERVICE} via SCAN(rootfs transitional), dump=${DUMP_FILE}"
  cat > "${PARFILE}" <<PAR
userid=${CONNECT_STRING}
full=y
directory=${EXP_DIR}
dumpfile=${DUMP_FILE}
logfile=${LOG_FILE}
job_name=${JOB_NAME}
filesize=20G
parallel=${PARALLEL_DEGREE}
compression=${COMPRESSION_MODE}
flashback_time=systimestamp
cluster=n
metrics=y
logtime=all
PAR
  chmod 600 "${PARFILE}"

  expdp parfile="${PARFILE}" >> "${SUMMARY_LOG}" 2>&1
  RC=$?
  sed -i '/^userid=/d' "${PARFILE}"

  if [ ${RC} -ne 0 ]; then mark_fail "${PDB_NAME}" "expdp rc=${RC}, parfile=${PARFILE}"; continue; fi

  LANDED=""; MULTI="no"
  for node in "${RAC_NODES[@]}"; do
    if rsh "${node}" "ls ${PDB_DIR}/${PDB_NAME}_${DATE_TAG}_*.dmp >/dev/null 2>&1"; then
      [ -n "${LANDED}" ] && MULTI="yes"
      LANDED="${node}"
    fi
  done
  [ -n "${LANDED}" ] || { mark_fail "${PDB_NAME}" "landing detect: no node holds dumps (ORA-39002?)"; continue; }
  [ "${MULTI}" = "no" ] || { mark_fail "${PDB_NAME}" "landing detect: dumps on multiple nodes, manual check"; continue; }
  log "[LANDED][${PDB_NAME}] node=${LANDED}"

  rsh "${LANDED}" "test -f '${PDB_DIR}/${LOG_FILE}'" || { mark_fail "${PDB_NAME}" "log not found on ${LANDED}"; continue; }
  if rsh "${LANDED}" "grep -E 'ORA-|UDE-|UDI-' '${PDB_DIR}/${LOG_FILE}' | grep -v 'ORA-31684'" >> "${SUMMARY_LOG}" 2>&1; then
    mark_fail "${PDB_NAME}" "expdp log contains ORA/UDE/UDI on ${LANDED}"; continue
  fi
  rsh "${LANDED}" "grep -q 'successfully completed' '${PDB_DIR}/${LOG_FILE}'" || \
    { mark_fail "${PDB_NAME}" "no 'successfully completed' on ${LANDED}"; continue; }

  rsh "${LANDED}" "ssh -o BatchMode=yes -o ConnectTimeout=10 ${REMOTE_USER}@${REMOTE_HOST} mkdir -p ${REMOTE_DIR}" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "remote mkdir failed; retransfer within ${LOCAL_RETENTION_DAYS}d"; continue; }
  rsh "${LANDED}" "rsync -av --partial --timeout=300 ${PDB_DIR}/${PDB_NAME}_${DATE_TAG}_*.dmp ${PDB_DIR}/${LOG_FILE} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "rsync failed; retransfer within ${LOCAL_RETENTION_DAYS}d"; continue; }
  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
    "test -s '${REMOTE_DIR}/${LOG_FILE}' && ls '${REMOTE_DIR}/${PDB_NAME}_${DATE_TAG}_'*.dmp >/dev/null 2>&1" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "remote validation failed"; continue; }

  mark_ok "${PDB_NAME}" "landed=${LANDED}; remote=${REMOTE_HOST}:${REMOTE_DIR}"
done

for node in "${RAC_NODES[@]}"; do
  rsh "${node}" "find '${BASE_DIR}' -mindepth 2 -maxdepth 2 \( -name '*.dmp' -o -name '*.log' \) -mtime +${LOCAL_RETENTION_DAYS} -type f -delete" >> "${SUMMARY_LOG}" 2>&1 || \
    log "[WARN] local retention cleanup failed on ${node}"
done
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.par' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -maxdepth 1 -name 'expdp_driver_*.log' -mtime +7 -type f -delete
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
  "find '${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp' -type f \( -name '*.dmp' -o -name '*.log' \) -mtime +${REMOTE_RETENTION_DAYS} -delete" >> "${SUMMARY_LOG}" 2>&1 || \
  log "[WARN] remote retention cleanup failed"

if [ ${FAIL} -eq 0 ]; then
  echo "OK $(date '+%F %T') PASS=${PASS} FAIL=0 log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] OK PASS=${PASS} FAIL=0"; exit 0
else
  echo "FAIL $(date '+%F %T') PASS=${PASS} FAIL=${FAIL} log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] FAIL PASS=${PASS} FAIL=${FAIL}"; exit 1
fi
EOF

chmod 700 /home/oracle/expdp_pdb_backup_rootfs.sh
chown oracle:oinstall /home/oracle/expdp_pdb_backup_rootfs.sh
```

#cron/监控/验收:复用6.5.1.2.4,验收第3条"挂载点=独立LV"替换为"三节点形态基线留档+双重防线演练
#(人为调低MIN_FREE_GB触发一次拒跑)";追加:本方案启用即入技术债台账,LV就位后30日内切主方案。

##### 6.5.1.2.6.附选方案二:落点钉死(VIP/singleton服务)

#适用条件:不愿在三个节点都配置备份LV与异地免密的现场——把落点固定在单一执行节点,
#只需一份LV、一份异地免密、无需落点探测;代价:需维护s_dp_*专用服务,执行节点宕机时备份中断(靠陈旧告警发现)。
#原理:singleton服务preferred钉死单实例后,会话恒落该实例,文件恒落该节点。禁止配-available:服务漂移=落点漂移。

##### (P1)执行节点本地LV
```bash
#仅在执行节点(示例k8s-19rac01)执行,步骤与6.5.1.2.1(A)相同(含ASM红线、mv迁移);
#其余两个节点无需LV、无需/backup/expdp目录——这反而是一层保护:
#服务异常漂移时expdp因DIRECTORY路径不存在报ORA-39002直接失败,可被告警发现,不会静默散落。
df -P /backup/expdp | awk 'NR==2{print $6}'   #执行节点必须输出/backup/expdp
```

##### (P2)singleton专用服务
```bash
#先确认节点↔实例映射:
srvctl status database -db xydb
#示例输出:Instance xydb1 is running on node k8s-19rac01 ...
#按映射把四个服务的preferred钉死在执行节点实例(示例xydb1);禁止追加-available:
srvctl add service -db xydb -service s_dp_stuwork    -pdb stuwork    -preferred xydb1
srvctl add service -db xydb -service s_dp_portal     -pdb portal     -preferred xydb1
srvctl add service -db xydb -service s_dp_onecode    -pdb onecode    -preferred xydb1
srvctl add service -db xydb -service s_dp_dataassets -pdb dataassets -preferred xydb1
srvctl start service -db xydb -service s_dp_stuwork
srvctl start service -db xydb -service s_dp_portal
srvctl start service -db xydb -service s_dp_onecode
srvctl start service -db xydb -service s_dp_dataassets
srvctl status service -db xydb | grep s_dp_
#验收:四个s_dp_*服务均running于执行节点实例。
#连接串走SCAN或执行节点VIP等效(singleton下SCAN也会重定向到该实例);脚本默认用VIP,少一跳且语义直观。
```

##### (P3)异地免密与SQL
```bash
#(C)异地备份服务器准备:复用6.5.1.2.1(C)
#(D)免密:仅需执行节点一份,在执行节点oracle登录shell内执行6.5.1.2.1(D)单节点部分,无需三节点集中验收
#(E)权限/账号形态核查+DIRECTORY创建:复用6.5.1.2.1(E)——DIRECTORY路径仅需在执行节点存在
#(F)estimate摸底:复用6.5.1.2.1(F),连接串改为执行节点VIP+s_dp_*服务
```

##### (P4)生产化脚本(完整,直接复制可用)
```bash
cat > /home/oracle/expdp_pdb_backup_pinned.sh <<'EOF'
#!/bin/bash
#expdp_pdb_backup_pinned.sh —— 附选方案二:落点钉死(VIP+singleton服务)
#前提:s_dp_*服务preferred钉死在本节点实例;本节点具备独立LV与到异地免密
umask 077
source /home/oracle/.bash_profile
set -u
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

#=====按现场修改区=====
DB_UNIQUE_NAME="xydb"
EXPECTED_HOST="k8s-19rac01"              #执行节点(=cron部署节点=落点节点)
CONNECT_HOST="k8s-19rac01-vip"           #执行节点VIP;禁止填负载均衡SCAN
LISTENER_PORT="1521"
EXP_DIR="EXPDP_DIR"
BASE_DIR="/backup/expdp"
EXPECTED_MOUNT="/backup/expdp"
LOCAL_RETENTION_DAYS=2
REMOTE_RETENTION_DAYS=14
REMOTE_USER="backup"
REMOTE_HOST="172.18.13.135"
REMOTE_BASE="/data"
CONNECT_MODE="password"
COMPRESSION_MODE="metadata_only"
MIN_FREE_GB=100
PDB_CONFIGS=(
  "stuwork:s_dp_stuwork:system:<SYS_PWD>:2"
  "portal:s_dp_portal:system:<SYS_PWD>:2"
  "onecode:s_dp_onecode:system:<SYS_PWD>:2"
  "dataassets:s_dp_dataassets:system:<SYS_PWD>:2"
)
#=====按现场修改区结束=====

DATE_TAG=$(date +%Y%m%d_%H%M%S)
SUMMARY_STATUS="${BASE_DIR}/last_expdp_status"
SUMMARY_LOG="${BASE_DIR}/expdp_driver_${DATE_TAG}.log"
PASS=0
FAIL=0
LOCAL_HOST=$(hostname -s)
mkdir -p "${BASE_DIR}"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "${SUMMARY_LOG}"; }
die(){ echo "FAIL $(date '+%F %T') $*" | tee "${SUMMARY_STATUS}" >&2; exit 1; }
write_status(){ local pdb="$1" status="$2" msg="$3"; echo "${status} $(date '+%F %T') ${msg}" > "${BASE_DIR}/${pdb}/last_expdp_status"; }
mark_fail(){ local pdb="$1" msg="$2"; FAIL=$((FAIL+1)); write_status "$pdb" "FAIL" "$msg"; log "[FAIL][$pdb] $msg"; }
mark_ok(){ local pdb="$1" msg="$2"; PASS=$((PASS+1)); write_status "$pdb" "OK" "$msg"; log "[OK][$pdb] $msg"; }

[ "${LOCAL_HOST}" = "${EXPECTED_HOST}" ] || die "wrong node: ${LOCAL_HOST}, expected ${EXPECTED_HOST}"
exec 9>"${BASE_DIR}/.expdp.lock"
flock -n 9 || die "another expdp backup is running, this run aborted"
[ -w "${BASE_DIR}" ] || die "${BASE_DIR} not writable"

FS_MOUNT=$(timeout 15 df -P "${BASE_DIR}" 2>/dev/null | awk 'NR==2{print $6}')
[ "${FS_MOUNT}" = "${EXPECTED_MOUNT}" ] || die "${BASE_DIR} mountpoint=${FS_MOUNT:-NA}, expected ${EXPECTED_MOUNT}; LV not mounted?"
FREE_GB=$(timeout 15 df -BG --output=avail "${BASE_DIR}" 2>/dev/null | awk 'NR==2{gsub("G","");print $1}')
{ [ -n "${FREE_GB}" ] && [ "${FREE_GB}" -ge "${MIN_FREE_GB}" ]; } || die "free=${FREE_GB:-NA}G < MIN_FREE_GB=${MIN_FREE_GB}G"
log "[PRECHECK][${LOCAL_HOST}] mount=${FS_MOUNT} free=${FREE_GB}G OK"
command -v rsync >/dev/null || die "rsync missing on ${LOCAL_HOST}; yum install -y rsync (2026-07-15 lesson)"
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "command -v rsync >/dev/null" || \
  die "rsync missing on remote ${REMOTE_HOST}"

for item in "${PDB_CONFIGS[@]}"; do
  IFS=':' read -r PDB_NAME PDB_SERVICE ADMIN_USER ADMIN_PWD PARALLEL_DEGREE <<< "${item}"
  PDB_DIR="${BASE_DIR}/${PDB_NAME}"
  mkdir -p "${PDB_DIR}"
  chmod 750 "${PDB_DIR}"

  LOG_FILE="${PDB_NAME}_${DATE_TAG}.log"
  DUMP_FILE="${PDB_NAME}_${DATE_TAG}_%U.dmp"
  JOB_NAME="EXPDP_${PDB_NAME^^}_${DATE_TAG}"
  PARFILE="${PDB_DIR}/expdp_${PDB_NAME}_${DATE_TAG}.par"
  REMOTE_DIR="${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp/${PDB_NAME}"

  if [ "${CONNECT_MODE}" = "wallet" ]; then
    CONNECT_STRING="/@${PDB_SERVICE}"
  else
    CONNECT_STRING="${ADMIN_USER}/\"${ADMIN_PWD}\"@${CONNECT_HOST}:${LISTENER_PORT}/${PDB_SERVICE}"
  fi

  #落点自检(钉死方案核心):SERVER_HOST必须等于本机,否则服务漂移了,禁止导出。
  #/nolog+heredoc连接,口令不出现在ps命令行。
  DB_HOST=$(sqlplus -s /nolog <<SQLCHK 2>/dev/null | tr -d '[:space:]'
connect ${CONNECT_STRING}
set heading off feedback off pagesize 0
select sys_context('USERENV','SERVER_HOST') from dual;
exit
SQLCHK
)
  DB_HOST=${DB_HOST%%.*}
  if [ -z "${DB_HOST}" ]; then
    mark_fail "${PDB_NAME}" "landing check: cannot connect service=${PDB_SERVICE} via ${CONNECT_HOST}"
    continue
  fi
  if [ "${DB_HOST}" != "${LOCAL_HOST}" ]; then
    mark_fail "${PDB_NAME}" "landing check: session on ${DB_HOST}, not ${LOCAL_HOST}; service drifted? run: srvctl status service -db ${DB_UNIQUE_NAME}"
    continue
  fi

  log "[START][${PDB_NAME}] service=${PDB_SERVICE} landed=${DB_HOST} dump=${DUMP_FILE}"
  cat > "${PARFILE}" <<PAR
userid=${CONNECT_STRING}
full=y
directory=${EXP_DIR}
dumpfile=${DUMP_FILE}
logfile=${LOG_FILE}
job_name=${JOB_NAME}
filesize=20G
parallel=${PARALLEL_DEGREE}
compression=${COMPRESSION_MODE}
flashback_time=systimestamp
cluster=n
metrics=y
logtime=all
PAR
  chmod 600 "${PARFILE}"

  (cd "${PDB_DIR}" && expdp parfile="${PARFILE}") >> "${SUMMARY_LOG}" 2>&1
  RC=$?
  sed -i '/^userid=/d' "${PARFILE}"

  if [ ${RC} -ne 0 ]; then mark_fail "${PDB_NAME}" "expdp rc=${RC}, parfile=${PARFILE}"; continue; fi
  [ -f "${PDB_DIR}/${LOG_FILE}" ] || { mark_fail "${PDB_NAME}" "log not found: ${PDB_DIR}/${LOG_FILE}"; continue; }
  if grep -E "ORA-|UDE-|UDI-" "${PDB_DIR}/${LOG_FILE}" | grep -v "ORA-31684" >> "${SUMMARY_LOG}" 2>&1; then
    mark_fail "${PDB_NAME}" "expdp log contains ORA/UDE/UDI: ${PDB_DIR}/${LOG_FILE}"; continue
  fi
  grep -q "successfully completed" "${PDB_DIR}/${LOG_FILE}" || \
    { mark_fail "${PDB_NAME}" "no 'successfully completed' in ${PDB_DIR}/${LOG_FILE}"; continue; }

  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '${REMOTE_DIR}'" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "remote mkdir failed; retransfer within ${LOCAL_RETENTION_DAYS}d"; continue; }
  rsync -av --partial --timeout=300 \
    "${PDB_DIR}/${PDB_NAME}_${DATE_TAG}_"*.dmp \
    "${PDB_DIR}/${LOG_FILE}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "rsync failed; retransfer within ${LOCAL_RETENTION_DAYS}d"; continue; }
  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
    "test -s '${REMOTE_DIR}/${LOG_FILE}' && ls '${REMOTE_DIR}/${PDB_NAME}_${DATE_TAG}_'*.dmp >/dev/null 2>&1" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "remote validation failed"; continue; }

  mark_ok "${PDB_NAME}" "landed=${DB_HOST} local=${PDB_DIR}/${LOG_FILE}; remote=${REMOTE_HOST}:${REMOTE_DIR}"
done

find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.dmp' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.log' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.par' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -maxdepth 1 -name 'expdp_driver_*.log' -mtime +7 -type f -delete
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
  "find '${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp' -type f \( -name '*.dmp' -o -name '*.log' \) -mtime +${REMOTE_RETENTION_DAYS} -delete" >> "${SUMMARY_LOG}" 2>&1 || \
  log "[WARN] remote retention cleanup failed"

if [ ${FAIL} -eq 0 ]; then
  echo "OK $(date '+%F %T') PASS=${PASS} FAIL=0 log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] OK PASS=${PASS} FAIL=0"; exit 0
else
  echo "FAIL $(date '+%F %T') PASS=${PASS} FAIL=${FAIL} log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] FAIL PASS=${PASS} FAIL=${FAIL}"; exit 1
fi
EOF

chmod 700 /home/oracle/expdp_pdb_backup_pinned.sh
chown oracle:oinstall /home/oracle/expdp_pdb_backup_pinned.sh
```

##### (P5)cron、执行节点迁移预案与验收
```bash
#cron:复用6.5.1.2.4流程,脚本路径替换为expdp_pdb_backup_pinned.sh;监控同样复用
#(FAIL告警+总/per-PDB 25小时陈旧告警——本方案执行节点宕机时备份静默中断,陈旧告警是唯一兜底,必须接入)。

#执行节点计划停机/永久迁移预案(以迁往k8s-19rac02/实例xydb2为例):
#1)在新节点完成:独立LV(6.5.1.2.1(A))+ 到异地免密(6.5.1.2.1(D)单节点)
#2)迁移服务preferred实例(逐个执行;19c修改preferred/available需带-modifyconfig。
#   备注:本命令语法尚未在本环境实测,首次执行前先在一个服务上验证,如有出入以实测为准并更新本节):
srvctl modify service -db xydb -service s_dp_stuwork    -modifyconfig -preferred xydb2
srvctl modify service -db xydb -service s_dp_portal     -modifyconfig -preferred xydb2
srvctl modify service -db xydb -service s_dp_onecode    -modifyconfig -preferred xydb2
srvctl modify service -db xydb -service s_dp_dataassets -modifyconfig -preferred xydb2
srvctl stop service -db xydb -service "s_dp_stuwork,s_dp_portal,s_dp_onecode,s_dp_dataassets"
srvctl start service -db xydb -service "s_dp_stuwork,s_dp_portal,s_dp_onecode,s_dp_dataassets"
srvctl status service -db xydb | grep s_dp_
#3)复制脚本到新节点,修改EXPECTED_HOST/CONNECT_HOST两个变量,部署cron,原节点cron注释;
#4)手工实跑一次确认四PDB落点自检均通过(landed=新节点)。
```
#验收标准(在6.5.1.2.4基础上替换/追加):
#1)四个s_dp_*服务均running于执行节点实例,且配置中无available实例(srvctl config service核查留档);
#2)driver日志每个PDB均有landed=<执行节点>;人为将某服务relocate到其他实例演练一次,
#确认落点自检mark_fail且不产生导出(演练后relocate回来);
#3)其余节点不存在/backup/expdp目录(形态即防线);
#4)执行节点迁移预案演练一次并留档。

##### 6.5.1.2.7.附选方案三:共享NFS导出目录(含soft挂载加固)

#适用条件:现场有独立NFS服务器(或可新建)、希望彻底落点无关时选用;
#必须理解:NFS服务端或网络故障直接决定当晚导出成败,且hard挂载下Data Pump worker会卡死在D状态而非报错,
#因此备份目的地必须soft挂载+脚本timeout预检。落点无关后无需探测、异地免密仅需驱动节点一份。

##### (N1)NFS服务端配置(在NFS服务器上以root执行)
```bash
#前提确认:RAC各节点oracle的uid/gid一致(RAC安装要求本就如此),在任一RAC节点执行 id oracle 记录之
ORACLE_UID=54321      #按现场id oracle实际输出修改
OINSTALL_GID=54321    #按现场实际修改
RAC_CIDR="172.18.13.0/24"   #RAC节点所在网段,按现场修改;也可写成逐节点IP多行export

yum install -y nfs-utils
mkdir -p /export/expdp
chown ${ORACLE_UID}:${OINSTALL_GID} /export/expdp
chmod 750 /export/expdp

cp /etc/exports /etc/exports.bak.$(date +%F) 2>/dev/null
cat >> /etc/exports <<EOF
/export/expdp ${RAC_CIDR}(rw,sync,no_subtree_check)
EOF
#说明:保留默认root_squash(RAC节点root映射为nobody),写入方是oracle用户不受影响且更安全;
#不要使用no_root_squash,除非确有root写入需求并评估过风险。

systemctl enable --now nfs-server rpcbind
exportfs -rav
exportfs -v          #验收:/export/expdp已按网段导出,选项含rw,sync

#防火墙(如启用firewalld):
firewall-cmd --permanent --add-service=nfs --add-service=rpc-bind --add-service=mountd
firewall-cmd --reload

#服务端容量:≥(estimate总量×LOCAL_RETENTION_DAYS×1.2);本环境实测参考15.1G/轮。
df -h /export/expdp
```

##### (N2)RAC三节点客户端挂载(每节点以root执行)
```bash
NFS_SERVER="<NFS_SERVER_IP>"   #按现场修改
yum install -y nfs-utils
mkdir -p /backup/expdp
cp /etc/fstab /etc/fstab.bak.$(date +%F)
#关键:备份目的地使用soft挂载——NFS无响应约30秒后IO返回EIO,expdp立即报错退出(RC非零→mark_fail→告警),
#而不是hard挂载下的无限重试与D状态卡死。
#soft的静默截断风险由成功判据兜底:判OK依赖日志"successfully completed"+异地校验,半截dump必判FAIL。
#严禁将soft用于数据文件/redo/OCR等数据库自身依赖的NFS,只允许用于备份目的地。
cat >> /etc/fstab <<EOF
${NFS_SERVER}:/export/expdp  /backup/expdp  nfs  rw,soft,tcp,timeo=100,retrans=3,noatime,bg,_netdev  0 0
EOF
mount -a
df -T /backup/expdp | awk 'NR==2{print $1,$2,$NF}'
```
```bash
#共享目录初始化:任一节点oracle执行一次即全局可见
su - oracle
mkdir -p /backup/expdp/{stuwork,portal,onecode,dataassets}
chmod 750 /backup/expdp/{stuwork,portal,onecode,dataassets}

#三节点集中校验(驱动节点oracle执行):同源、同类型、可写
for h in k8s-19rac01 k8s-19rac02 k8s-19rac03; do
  echo "==== ${h} ===="
  ssh -o BatchMode=yes ${h} "timeout 15 df -T /backup/expdp | awk 'NR==2{print \$1,\$2,\$NF}'"
  ssh -o BatchMode=yes ${h} "timeout 15 touch /backup/expdp/.rwtest_${h} && rm -f /backup/expdp/.rwtest_${h}" && echo "${h} rw OK"
done
#验收:三节点类型均为nfs/nfs4且来源(第一列)完全相同;任一节点为xfs/ext4即不通过。
```

##### (N3)异地免密与SQL
```bash
#(C)异地备份服务器准备:复用6.5.1.2.1(C)
#(D)免密:落点无关后由驱动节点统一推送,仅需驱动节点一份,执行6.5.1.2.1(D)单节点部分即可
#(E)权限/账号形态核查+DIRECTORY创建:复用6.5.1.2.1(E)——DIRECTORY路径为共享NFS,天然三节点一致
#(F)estimate摸底:复用6.5.1.2.1(F)
```

##### (N4)生产化脚本(完整,直接复制可用)
```bash
cat > /home/oracle/expdp_pdb_backup_nfs.sh <<'EOF'
#!/bin/bash
#expdp_pdb_backup_nfs.sh —— 附选方案三:共享NFS导出目录(soft挂载)
#前提:三节点同源NFS挂载/backup/expdp;驱动节点到异地免密
umask 077
source /home/oracle/.bash_profile
set -u
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

#=====按现场修改区=====
DB_UNIQUE_NAME="xydb"
EXPECTED_HOST="k8s-19rac01"              #cron部署节点(仅驱动脚本;落点无关)
CONNECT_HOST="172.18.13.176"             #SCAN;共享NFS下落点无关,负载均衡无副作用
LISTENER_PORT="1521"
EXP_DIR="EXPDP_DIR"
BASE_DIR="/backup/expdp"
LOCAL_RETENTION_DAYS=2
REMOTE_RETENTION_DAYS=14
REMOTE_USER="backup"
REMOTE_HOST="172.18.13.135"
REMOTE_BASE="/data"
CONNECT_MODE="password"
COMPRESSION_MODE="metadata_only"
MIN_FREE_GB=100
PDB_CONFIGS=(
  "stuwork:s_stuwork:system:<SYS_PWD>:2"
  "portal:s_portal:system:<SYS_PWD>:2"
  "onecode:s_onecode:system:<SYS_PWD>:2"
  "dataassets:s_dataassets:system:<SYS_PWD>:2"
)
#=====按现场修改区结束=====

DATE_TAG=$(date +%Y%m%d_%H%M%S)
SUMMARY_STATUS="${BASE_DIR}/last_expdp_status"
SUMMARY_LOG="${BASE_DIR}/expdp_driver_${DATE_TAG}.log"
PASS=0
FAIL=0
LOCAL_HOST=$(hostname -s)

log(){ echo "[$(date '+%F %T')] $*" | tee -a "${SUMMARY_LOG}"; }
die(){ echo "FAIL $(date '+%F %T') $*" | tee "${SUMMARY_STATUS}" >&2; exit 1; }
write_status(){ local pdb="$1" status="$2" msg="$3"; echo "${status} $(date '+%F %T') ${msg}" > "${BASE_DIR}/${pdb}/last_expdp_status"; }
mark_fail(){ local pdb="$1" msg="$2"; FAIL=$((FAIL+1)); write_status "$pdb" "FAIL" "$msg"; log "[FAIL][$pdb] $msg"; }
mark_ok(){ local pdb="$1" msg="$2"; PASS=$((PASS+1)); write_status "$pdb" "OK" "$msg"; log "[OK][$pdb] $msg"; }

[ "${LOCAL_HOST}" = "${EXPECTED_HOST}" ] || die "wrong driver node: ${LOCAL_HOST}, expected ${EXPECTED_HOST}"

#NFS预检必须先于任何写操作(含锁文件),且全程timeout包裹(stale mount下df/touch都会挂死)
FS_TYPE=$(timeout 15 df -T "${BASE_DIR}" 2>/dev/null | awk 'NR==2{print $2}')
[ -n "${FS_TYPE}" ] || die "df on ${BASE_DIR} timed out or failed, NFS not responding"
case "${FS_TYPE}" in nfs*) : ;; *) die "${BASE_DIR} fstype=${FS_TYPE}, not NFS; mount missing? see (N2)";; esac
FREE_GB=$(timeout 15 df -BG --output=avail "${BASE_DIR}" 2>/dev/null | awk 'NR==2{gsub("G","");print $1}')
{ [ -n "${FREE_GB}" ] && [ "${FREE_GB}" -ge "${MIN_FREE_GB}" ]; } || die "free=${FREE_GB:-NA}G < MIN_FREE_GB=${MIN_FREE_GB}G"
timeout 15 touch "${BASE_DIR}/.rwcheck" && rm -f "${BASE_DIR}/.rwcheck" || die "${BASE_DIR} not writable via NFS"
log "[PRECHECK][${LOCAL_HOST}] fstype=${FS_TYPE} free=${FREE_GB}G OK"
command -v rsync >/dev/null || die "rsync missing on ${LOCAL_HOST}; yum install -y rsync (2026-07-15 lesson)"
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "command -v rsync >/dev/null" || \
  die "rsync missing on remote ${REMOTE_HOST}"

exec 9>"${BASE_DIR}/.expdp.lock"
flock -n 9 || die "another expdp backup is running, this run aborted"

for item in "${PDB_CONFIGS[@]}"; do
  IFS=':' read -r PDB_NAME PDB_SERVICE ADMIN_USER ADMIN_PWD PARALLEL_DEGREE <<< "${item}"
  PDB_DIR="${BASE_DIR}/${PDB_NAME}"
  mkdir -p "${PDB_DIR}"
  chmod 750 "${PDB_DIR}"
  #共享NFS:无论会话落哪个实例,服务端写入的都是同一文件系统,驱动节点本地可见,无需落点探测。

  LOG_FILE="${PDB_NAME}_${DATE_TAG}.log"
  DUMP_FILE="${PDB_NAME}_${DATE_TAG}_%U.dmp"
  JOB_NAME="EXPDP_${PDB_NAME^^}_${DATE_TAG}"
  PARFILE="${PDB_DIR}/expdp_${PDB_NAME}_${DATE_TAG}.par"
  REMOTE_DIR="${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp/${PDB_NAME}"

  if [ "${CONNECT_MODE}" = "wallet" ]; then
    CONNECT_STRING="/@${PDB_SERVICE}"
  else
    CONNECT_STRING="${ADMIN_USER}/\"${ADMIN_PWD}\"@${CONNECT_HOST}:${LISTENER_PORT}/${PDB_SERVICE}"
  fi

  log "[START][${PDB_NAME}] service=${PDB_SERVICE} via SCAN(NFS shared), dump=${DUMP_FILE}"
  cat > "${PARFILE}" <<PAR
userid=${CONNECT_STRING}
full=y
directory=${EXP_DIR}
dumpfile=${DUMP_FILE}
logfile=${LOG_FILE}
job_name=${JOB_NAME}
filesize=20G
parallel=${PARALLEL_DEGREE}
compression=${COMPRESSION_MODE}
flashback_time=systimestamp
cluster=n
metrics=y
logtime=all
PAR
  chmod 600 "${PARFILE}"

  expdp parfile="${PARFILE}" >> "${SUMMARY_LOG}" 2>&1
  RC=$?
  sed -i '/^userid=/d' "${PARFILE}"

  if [ ${RC} -ne 0 ]; then
    mark_fail "${PDB_NAME}" "expdp rc=${RC} (NFS EIO under soft mount also lands here), parfile=${PARFILE}"
    continue
  fi
  [ -f "${PDB_DIR}/${LOG_FILE}" ] || { mark_fail "${PDB_NAME}" "log not found: ${PDB_DIR}/${LOG_FILE}"; continue; }
  if grep -E "ORA-|UDE-|UDI-" "${PDB_DIR}/${LOG_FILE}" | grep -v "ORA-31684" >> "${SUMMARY_LOG}" 2>&1; then
    mark_fail "${PDB_NAME}" "expdp log contains ORA/UDE/UDI: ${PDB_DIR}/${LOG_FILE}"; continue
  fi
  if ! grep -q "successfully completed" "${PDB_DIR}/${LOG_FILE}"; then
    mark_fail "${PDB_NAME}" "no 'successfully completed' (soft mount truncation lands here)"; continue
  fi

  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '${REMOTE_DIR}'" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "remote mkdir failed; retransfer within ${LOCAL_RETENTION_DAYS}d"; continue; }
  rsync -av --partial --timeout=300 \
    "${PDB_DIR}/${PDB_NAME}_${DATE_TAG}_"*.dmp \
    "${PDB_DIR}/${LOG_FILE}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "rsync failed; retransfer within ${LOCAL_RETENTION_DAYS}d"; continue; }
  ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
    "test -s '${REMOTE_DIR}/${LOG_FILE}' && ls '${REMOTE_DIR}/${PDB_NAME}_${DATE_TAG}_'*.dmp >/dev/null 2>&1" >> "${SUMMARY_LOG}" 2>&1 || \
    { mark_fail "${PDB_NAME}" "remote validation failed"; continue; }

  mark_ok "${PDB_NAME}" "local(NFS)=${PDB_DIR}/${LOG_FILE}; remote=${REMOTE_HOST}:${REMOTE_DIR}"
done

#本地保留(共享NFS,执行一次即可):
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.dmp' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.log' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -mindepth 2 -maxdepth 2 -name '*.par' -mtime +${LOCAL_RETENTION_DAYS} -type f -delete
find "${BASE_DIR}" -maxdepth 1 -name 'expdp_driver_*.log' -mtime +7 -type f -delete
ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" \
  "find '${REMOTE_BASE}/${DB_UNIQUE_NAME}/expdp' -type f \( -name '*.dmp' -o -name '*.log' \) -mtime +${REMOTE_RETENTION_DAYS} -delete" >> "${SUMMARY_LOG}" 2>&1 || \
  log "[WARN] remote retention cleanup failed"

if [ ${FAIL} -eq 0 ]; then
  echo "OK $(date '+%F %T') PASS=${PASS} FAIL=0 log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] OK PASS=${PASS} FAIL=0"; exit 0
else
  echo "FAIL $(date '+%F %T') PASS=${PASS} FAIL=${FAIL} log=${SUMMARY_LOG}" > "${SUMMARY_STATUS}"
  log "[SUMMARY] FAIL PASS=${PASS} FAIL=${FAIL}"; exit 1
fi
EOF

chmod 700 /home/oracle/expdp_pdb_backup_nfs.sh
chown oracle:oinstall /home/oracle/expdp_pdb_backup_nfs.sh
```

##### (N5)NFS故障处置、演练与验收
```bash
#NFS故障导致Data Pump job悬挂/残留时的清理路径:
sqlplus / as sysdba
alter session set container=<PDB>;
select owner_name, job_name, state, attached_sessions from dba_datapump_jobs;
--state为NOT RUNNING且无attached session的残留job,直接删除同名master table即可释放:
drop table <OWNER>.<JOB_NAME> purge;
#OS层若有D状态卡死的expdp/DW进程,恢复NFS后通常自行退出;soft挂载下一般不会出现长期D状态。
#stale mount恢复:umount -l /backup/expdp && mount -a(必要时先在NFS服务端exportfs -rav)。
```
#验收标准(在6.5.1.2.4基础上替换/追加):
#1)三节点df -T校验记录留档:类型均nfs/nfs4、来源完全相同;fstab挂载参数包含soft(仅限本备份目的地);
#2)NFS服务端exportfs -v留档:导出网段与选项(rw,sync,root_squash)符合(N1);
#3)cron与监控复用6.5.1.2.4;
#4)NFS中断演练一次:导出期间在NFS服务端systemctl stop nfs-server,
#确认expdp在分钟级内报错退出、per-PDB状态FAIL并触发告警;恢复服务后补跑成功,演练记录留档;
#5)悬挂job清理路径演练或桌面推演一次,dba_datapump_jobs查询语句纳入运维手册速查。

##### 6.5.1.2.8.实测记录存档(2026-07-14,主方案验证依据)

#-----8.1 运行时间线-----
#10:31 手工模板测试(rac01执行,连SCAN 172.18.13.176):导出成功,但文件落rac03、parfile留rac01,
#实证SCAN负载均衡改变落点(rac01当日目录仅剩parfile,rac03目录有dmp×2+log),推动架构演进为落点探测。
#12:17 脚本首跑与预检拦截,原始输出:
```text
[oracle@k8s-19rac01 ~]$ ./expdp_pdb_backup.sh
/etc/bashrc: line 12: PS1: unbound variable
#(修复set -u顺序后再跑,静默退出,状态文件:)
[oracle@k8s-19rac01 ~]$ cat /backup/expdp/last_expdp_status
FAIL 2026-07-14 12:17:47 k8s-19rac01:/backup/expdp mountpoint=/, expected /backup/expdp; LV not mounted?
#(三节点核查确认根因:磁盘被直接扩容进centos-root,/backup/expdp均落根分区)
k8s-19rac01: /
k8s-19rac02: /
k8s-19rac03: /
```
#随后按6.5.1.2.1(A)完成三节点LV建设(200G/节点)。

#-----8.2 全量运行(15:37,driver: expdp_driver_20260714_153713.log)-----
```text
[2026-07-14 15:37:14] [PRECHECK][k8s-19rac01] mount=/backup/expdp free=200G OK
[2026-07-14 15:37:14] [PRECHECK][k8s-19rac02] mount=/backup/expdp free=200G OK
[2026-07-14 15:37:15] [PRECHECK][k8s-19rac03] mount=/backup/expdp free=200G OK
[2026-07-14 15:37:15] [START][stuwork] service=s_stuwork via SCAN, dump=stuwork_20260714_153713_%U.dmp compression=metadata_only
[2026-07-14 15:49:40] [LANDED][stuwork] node=k8s-19rac03
[2026-07-14 15:54:16] [OK][stuwork] landed=k8s-19rac03 local=k8s-19rac03:/backup/expdp/stuwork/stuwork_20260714_153713.log; remote=172.18.13.135:/data/xydb/expdp/stuwork
[2026-07-14 15:54:16] [START][portal] ...
[2026-07-14 15:58:47] [LANDED][portal] node=k8s-19rac01
[2026-07-14 15:58:49] [OK][portal] ...
[2026-07-14 15:58:50] [FAIL][onecode] expdp rc=1, parfile=/backup/expdp/onecode/expdp_onecode_20260714_153713.par, driver=...
[2026-07-14 15:58:50] [START][dataassets] ...
[2026-07-14 16:02:08] [LANDED][dataassets] node=k8s-19rac02
[2026-07-14 16:02:09] [OK][dataassets] ...
[2026-07-14 16:02:10] [SUMMARY] FAIL PASS=3 FAIL=1
```
#性能参考:stuwork导出约12.5分钟(dump≈15G,双dmp分片),rsync推送约4.5分钟。

#-----8.3 ORA-01950案例(onecode失败根因与修复)-----
#driver日志中onecode段报错原文:
```text
Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
ORA-31626: job does not exist
ORA-31633: unable to create master table "ONECODEUSER.EXPDP_ONECODE_20260714_153713"
ORA-06512: at "SYS.DBMS_SYS_ERROR", line 95
ORA-06512: at "SYS.KUPV$FT", line 1163
ORA-01950: no privileges on tablespace 'SYSTEM'
ORA-06512: at "SYS.KUPV$FT", line 1056
ORA-06512: at "SYS.KUPV$FT", line 1044
```
#定位链:①失败仅1秒且三节点均无dump/log→失败在建job阶段;②sqlplus同账号登录正常且
#"Last Successful login time: Tue Jul 14 2026 15:58:49"恰为expdp执行时刻→认证成功,排除口令;
#③错误栈显示master table创建失败于SYSTEM表空间。根因确认与修复:
```text
SQL> select username, default_tablespace from dba_users where username='ONECODEUSER';
ONECODEUSER    SYSTEM
SQL> select tablespace_name, round(sum(bytes)/1048576) mb
     from dba_segments where owner='ONECODEUSER' group by tablespace_name;
no rows selected      --空schema,该PDB建库时未创建应用表空间

SQL> create tablespace onecode datafile '+DATA' size 1G autoextend on next 1G maxsize 31G
     extent management local segment space management auto;
SQL> alter user onecodeuser default tablespace ONECODE quota unlimited on ONECODE;
```
#修复后16:20单跑onecode通过(落rac02);rac03预检读数185G(较15:37减少15G,与stuwork落点一致,
#证明预检读数真实反映占用)。
#附带处置:修复过程中曾误建独立用户onecode并授DBA,属高危闲置账号,已按验收第15条要求删除/锁定。

#-----8.4 cron验证(16:32)与异地确认-----
```text
[2026-07-14 16:43:42] [LANDED][dataassets] node=k8s-19rac03
sending incremental file list
dataassets_20260714_163201.log
dataassets_20260714_163201_01.dmp
dataassets_20260714_163201_02.dmp
[2026-07-14 16:43:44] [OK][dataassets] landed=k8s-19rac03 ...
[2026-07-14 16:43:44] [SUMMARY] OK PASS=3 FAIL=0
```
#异地服务器逐PDB确认(节选):
```text
[backup@dbserver expdp]$ tree -L 2
├── dataassets/{..._103026与..._153713与..._163201系列dmp/log}
├── onecode/{onecode_20260714_162014_01.dmp, _02.dmp, .log}
├── portal/{portal_20260714_153713_01.dmp, _02.dmp, .log}
└── stuwork/{stuwork_20260714_153713_01.dmp, _02.dmp, .log}
```
#注:16:32轮为cron测试,stuwork临时注释——暴露"总状态OK但单PDB缺备份"的监控盲区,
#由此新增per-PDB陈旧告警;整改恢复stuwork后全量复跑PASS=4 FAIL=0,验收通过。

#-----8.5 结论汇总-----
#落点分布:四轮共6次落点覆盖三节点(stuwork→rac03,portal→rac01,dataassets→rac02/rac03,onecode→rac02),
#探测恰一命中率100%,无散落、无多点;per-PDB状态landed=字段与driver日志[LANDED]一致,可作审计依据。
#容量:单轮全量≈15.1G(stuwork≈15G,其余三库各≈4.2~4.3M);异地14天稳态≈212G,/data按≥250G规划。
#口令残留:手工测试遗留1份含userid的parfile,已删除并将核查固化为手工操作后必查项。

##### 6.5.1.2.9.实测记录存档(2026-07-15,附选方案一rootfs现场验证:oracle01/02)

#现场:双节点RAC oracle01/02(xydb,三PDB:STUWORK/PORTAL/DATAASSETS),SCAN=rac-scan(10.4.0.45),
#异地10.4.1.2:/home/backup(ao-home 1.8T独立LV);选型=附选一(七盘全为ASM成员无法建LV,根分区使用率13%)。
#细化步骤与现场值见配套文档《6_5_1_2_v2_5_9_v2_现场适配版_oracle01-02.md》。

#-----9.1 estimate与实际体量(compression=metadata_only)-----
#stuwork    estimate(statistics)=2.701G → 实际dump≈5.8G (≈2.1倍)
#portal     estimate=828.7M             → 实际≈894M    (≈1.1倍)
#dataassets estimate=17.92G             → 实际≈53G     (≈3.0倍)    单轮合计≈59G
#教训:statistics估算强依赖统计信息新旧,规划按估算×3上浮或estimate=blocks交叉验证(已回写(F))。
#对照:2026-07-14现场估算与实际基本吻合,说明偏差纯由统计信息新旧决定,不可跨现场套用比值。

#-----9.2 白天业务期首跑(11:45)与rsync缺失故障-----
```text
[2026-07-15 11:45:57] [PRECHECK][oracle01: free=1304G used=13%] OK
[2026-07-15 11:45:58] [PRECHECK][oracle02: free=1344G used=10%] OK
[2026-07-15 11:55:59] [LANDED][stuwork] node=oracle01
[2026-07-15 11:56:00] [FAIL][stuwork] rsync failed to 10.4.1.2:/home/backup/xydb/expdp/stuwork; retransfer within 2d
[2026-07-15 12:00:26] [LANDED][portal] node=oracle02
[2026-07-15 12:00:27] [FAIL][portal] rsync failed ...
[2026-07-15 12:37:01] [LANDED][dataassets] node=oracle01
[2026-07-15 12:37:02] [FAIL][dataassets] rsync failed ...
[2026-07-15 12:37:03] [SUMMARY] FAIL PASS=0 FAIL=3
```
#根因:driver日志同步段内嵌"bash: rsync: 未找到命令"——两节点与备份机三台均未装rsync,当时预检不含依赖检查。
#三PDB expdp日志均"successfully completed"且无未解释ORA-,dump全部有效;失败被状态机正确限定在同步段,
#per-PDB状态FAIL并给出retransfer补传窗口提示,防线语义符合设计。

#-----9.3 补传闭环(免重导)-----
#三台装rsync后按落点补传(白天--bwlimit=51200限速,源路径末尾/表示同步目录内容):
#oracle01→stuwork/dataassets,oracle02→portal;rsync -avc --dry-run两端校验一致,
#异地du确认5.8G/894M/53G齐备;driver日志追加[RETRANSFER]审计行,状态文件回写PASS=3 FAIL=0(manual retransfer)。
#整改固化:四套脚本预检加rsync依赖检查(本地各节点+异地),(C)/(D)加安装与集中确认——即v2.5.10第1/2条变更。

#-----9.4 性能与落点数据-----
#导出耗时(白天业务期,parallel=2):portal 894M/4m21s;stuwork 5.8G/9m54s;dataassets 53G/36m29s(≈25MB/s)。
#补传耗时(限速50MB/s):合计≈59G/约20分钟;导出与限速补传全程无业务侧影响反馈。
#落点分布:stuwork→oracle01,portal→oracle02,dataassets→oracle01,再证SCAN负载均衡落点不定、探测恰一命中率100%。
#结论:附选方案一(rootfs过渡)全链路验证通过;白天试跑编排(先小库验链路→大库控并发→传输限速,
#STOP_JOB/START_JOB可续跑兜底)实测可行,收录为标准做法。

##### 6.5.1.2.10.空PDB全量恢复演练标准流程(验收第16条季度演练,含2026-07-15实测存档)

#-----10.1 适用场景与判定语义-----
#目的:以"建空PDB→full=y全量导入→四层校验→drop"验证dump可还原且完整,是最严格的完整性检验形态:
#表空间、用户(含口令哈希/权限/配额)、对象、数据全部由dump自建,手工预建反而会掩盖dump缺失元数据的问题。
#不需要预建用户;表空间通常也不需要——dump携带CREATE TABLESPACE(OMF形态无显式路径,自动落
#db_create_file_dest指向的磁盘组);仅当两端磁盘组名不一致时用remap_datafile或按preview DDL预建。
#空PDB内无同名表,不写table_exists_action(默认skip即可);向已有数据的PDB做覆盖式还原才用replace,
#且replace只作用于表(序列/视图/代码对象走ORA-31684跳过),并须先做目标端快照留回退。
#备份成功语义=四层校验全过:①日志白名单过滤后无ORA-;②对象数按owner/type两端一致;③行数逐表对账
#(基线=源端导出日志的metrics行数,即flashback_time快照值;禁止拿生产库当前count(*)对账,业务表会持续增长
#造成假差异);④INVALID对象为0(或utlrp后为0)。

#-----10.2 标准流程(在dump所在节点执行,连接一律该节点VIP,不走SCAN)-----
```sql
--(1)建空PDB(CDB root,sys;确认show parameter db_create_file_dest已指向ASM)
create pluggable database <PDBTEST> admin user pdbadmin identified by "<PDBADMIN_PWD>";
alter pluggable database <PDBTEST> open read write instances=all;
alter pluggable database <PDBTEST> save state instances=all;
--临时验证PDB直接用默认服务<pdbtest>,不必srvctl建s_*服务,用完即弃

--(2)新PDB内建DIRECTORY指向dump所在目录并授权SYSTEM
alter session set container=<PDBTEST>;
create directory EXPDP_DIR as '<dump所在目录>';
grant read, write on directory EXPDP_DIR to system;
```
```bash
#(3)sqlfile预览(不执行任何导入):确认dump携带的表空间DDL(OMF应无显式路径)与用户清单
cat > ${PDB_DIR}/impdp_preview.par <<EOF
userid=system/"<SYS_PWD>"@<本节点VIP>:1521/<pdbtest>
directory=EXPDP_DIR
dumpfile=<PDB>_${DATE_TAG}_%U.dmp
sqlfile=<PDB>_${DATE_TAG}_ddl_preview.sql
include=TABLESPACE,USER
EOF
chmod 600 ${PDB_DIR}/impdp_preview.par && impdp parfile=${PDB_DIR}/impdp_preview.par
sed -i '/^userid=/d' ${PDB_DIR}/impdp_preview.par
grep -E "CREATE (TABLESPACE|USER)" ${PDB_DIR}/<PDB>_${DATE_TAG}_ddl_preview.sql

#(4)全量导入(空PDB默认skip,不写table_exists_action)
cat > ${PDB_DIR}/impdp_<PDB>_${DATE_TAG}_pdbtest.par <<EOF
userid=system/"<SYS_PWD>"@<本节点VIP>:1521/<pdbtest>
directory=EXPDP_DIR
dumpfile=<PDB>_${DATE_TAG}_%U.dmp
logfile=impdp_<PDB>_${DATE_TAG}_pdbtest.log
full=y
cluster=n
metrics=y
logtime=all
EOF
chmod 600 ${PDB_DIR}/impdp_<PDB>_${DATE_TAG}_pdbtest.par
impdp parfile=${PDB_DIR}/impdp_<PDB>_${DATE_TAG}_pdbtest.par
sed -i '/^userid=/d' ${PDB_DIR}/impdp_<PDB>_${DATE_TAG}_pdbtest.par

#(5)四层校验
grep "ORA-" ${PDB_DIR}/impdp_*_pdbtest.log | grep -v "ORA-31684"   #①应为空
#②对象数:两端各执行同一语句对表
#  select owner,object_type,count(*) from dba_objects where owner in (<业务schema>) group by owner,object_type order by 1,2;
#③行数逐表对账(导出日志 vs 导入日志,均为metrics=y逐表记录):
for f in <PDB>_${DATE_TAG}.log impdp_<PDB>_${DATE_TAG}_pdbtest.log; do
  awk '/\. \. (exported|imported) "<业务SCHEMA>"/{
    for(i=1;i<=NF;i++){if($i~/^"<业务SCHEMA>"/)n=$i; if($i=="rows")r=$(i-1)}
    print n, r}' $f | sort > /tmp/$(basename $f).rows
done
diff /tmp/<PDB>_${DATE_TAG}.log.rows /tmp/impdp_<PDB>_${DATE_TAG}_pdbtest.log.rows && echo "行数逐表对齐"
#④select count(*) from dba_objects where status='INVALID'; 非0则@?/rdbms/admin/utlrp.sql后复查
```
```sql
--(6)清理与收尾:演练PDB含生产数据,验证完当日即清,不过夜滞留
alter pluggable database <PDBTEST> close immediate instances=all;
drop pluggable database <PDBTEST> including datafiles;
--parfile补查userid残留;演练期间明文出现的口令列入轮换;结果记恢复演练台账
```

#-----10.3 判读口径与已知良性信息-----
#①"completed with N error(s)"不直接判FAIL:逐条核对,若全部为ORA-31684白名单(新PDB自带的
#UNDOTBS1/TEMP等表空间、导入前手工建的EXPDP_DIR目录对象)则判PASS——过滤命令返回空即为证据;
#②"Cannot set an SCN larger than the current SCN"(Streams提示,无ORA号)为full=y导入常见良性信息;
#③结尾汇总段的"Completed N objects in XXXXX seconds"为记账口径(累计值),实际耗时以作业首尾墙钟为准;
#④AUDSYS统一审计分区随full=y一并导入属预期,提醒演练PDB含生产审计与业务数据,须按(6)及时drop。

#-----10.4 实测存档(2026-07-15,portal 894M dump跨环境还原:oracle01/02生产→k8s-19rac测试)-----
#时间线:16:25建PORTALTEST并建EXPDP_DIR(其间create or replace改路径,实证OR REPLACE保留既有授权);
#16:30 preview首跑UDI-01017/ORA-01017——parfile口令含#被截断(同串sqlplus可登录,秒判),双引号包裹后
#16:33 preview通过(14s):CREATE TABLESPACE "PORTAL"三数据文件均OMF无路径,+DATA零干预;
#用户PORTALADMIN/PORTAL_SERVICE_V6均IDENTIFIED BY VALUES原哈希重建;
#17:15-17:33 full=y导入,elapsed 17m59s,"completed with 3 error(s)"=ORA-31684×3(UNDOTBS1/TEMP/EXPDP_DIR),
#白名单过滤后无ORA-;18:09起校验。
#校验结果:对象数两端一致(PORTAL_SERVICE_V6: TABLE 107/INDEX 113/LOB 8;PORTALADMIN两端均空schema);
#约束203、表统计107、索引统计113全部载入;INVALID=0(未跑utlrp);
#行数逐表对账107表全对齐(导出日志vs导入日志diff为空),大表SERVICE_USER_TRACK 5,410,432行/527.7MB、
#SYSTEM_VISIT 4,673,051行/282.7MB均direct_path完整载入。
#保真观察:源端PORTALADMIN的EXPIRED(GRACE)状态以PASSWORD EXPIRE原样复现,反向印证还原保真度。
#结论:备份可还原且完整,验证通过;本轮dump取自本地暂存副本,台账注明,下轮按验收第16条从异地取件。
