# VastBase G100 数据库在麒麟 V10 上的部署文档（V3.0.8PSU4 / MySQL 兼容模式）

> **适用范围**：VastBase G100（基于 openGauss 内核）单机部署，MySQL 兼容模式  
> **操作系统**：银河麒麟高级服务器操作系统 V10（Kylin Linux Advanced Server V10）  
> **架构**：x86_64 / aarch64（命令一致，安装包按架构选择）  
> **数据库版本**：VastBase G100 V3.0 Build 8 Patch No.4（常见交付简称 V3.0.8PSU4；以安装介质和 `SELECT version()` 为准）  
> **命令标识**：文内使用【通用】、【通用关键】、【V3.0.8PSU4】、【V3.0.8PSU4 增强】、【现场确认】标注命令/参数适用范围  
> **文档版本**：v1.48（**新增 §19.4.10「变体：Harbor 主机（/data + /var/lib/docker）与 K8s 工作节点（/var/lib/docker）迁移到 LVM」（A 部分 harbor 与 B 部分首台 worker01 当日实执行闭环）+ ★迁移证据快照路径事故修正（含 §19.4.9 同款隐患）**：§19.4.10 复用 §19.4 骨架完成 harbor 主机（/data 21G/17444 条目 + /var/lib/docker 7.7G/192506 条目 → vgdata：lvharbordata 300G + lvdocker 100G，VFree <50G）与首台工作节点 k8s-worker01（/var/lib/docker 18G/296714 条目 → vgdata/lvdocker 150G，VG 留 ~50G）双场景迁移——挂载路径不变、harbor.yml/daemon.json/compose/RKE 容器定义零改动；切换前 find diff 全部零差异；受控重启验证 fstab 持久 + docker/harbor.service 开机自启链路；harbor 验收 login/pull/push + Rancher 侧拉取 + 外部 harbor 复制全过、docker info 指纹一致（Images 39，验收 pull 后 40 差值可解释）；worker01 验收 Images 71 指纹一致 + kubelet/kube-proxy 随 docker 自起 + uncordon 后调度即回流 + 全集群无非 Running/Completed pod。**与 §19.4/§19.4.9 三处本质差异固化为流程**：①停写入方的反拉来源须现场核实——现场实证 `docker-compose stop` 被 `harbor.service`（Restart=on-failure、前台 compose up）整栈反拉（stop 全 done 后十容器复活 "Up About a minute"，与 §19.4.2 禁 vb_ctl stop 同构），停栈固化为 `systemctl stop harbor`；docker 一律 stop + mask（Kylin docker 20.10 包无 docker.socket/containerd 独立单元，"not loaded" 属预期）；②核心风险 = overlay2 `trusted.overlay.*` xattr 与残留 overlay/shm 挂载——rsync 必须 root + `-aAXH --numeric-ids`，`findmnt -R /var/lib/docker` 清零为硬闸；③harbor 窗口与工作节点窗口严禁重叠（drain 依赖 harbor 在线拉镜像）、节点逐台滚动。**★事故修正：迁移前后证据快照一律写持久目录 /root/migrate_evidence**——harbor 首执写 /tmp，Kylin V10 /tmp 为 tmpfs、受控重启即清，pre/post 比对落空（迁移一致性结论不受影响：权威闸门为切换前新旧目录 diff 零差异；证据从 *_old 旧目录补生成）；**§19.4.9 同款隐患（快照写 /tmp、步骤 5 重启先于收尾比对）一并修正**。偏差与里程碑：harbor 侧 mask 安全闸连续第二次被跳过且窗口内真实发生反拉、lvharbordata 当场 lvextend 200G→300G 致 VFree <50G（再扩须 vgextend 加盘）、rsync 两台均未预装窗口内临时安装（前置检查已补入 A1/B1）；**worker01 侧 mask 安全闸自 §19.4.8 警告以来首次完整执行（stop→mask→迁移→unmask→reboot），主流程零偏差**。判读固化：DaemonSet pod RESTARTS +1 与 docker info Containers 计数波动属预期，跨迁移指纹只看 Images/Storage Driver/Root Dir 三项；drain 后节点仅剩三个 DaemonSet pod（cattle-node-agent/nginx-ingress-controller/calico-node）即驱逐完成；drain 的 Throttling request 为 Rancher 代理限流噪音。衍生发现：k8s-master01 内存 87% 显著高于 master02/03（62–66%），另案关注。worker02–04 待逐台滚动，全部完成观察 1–2 天后统一回收各 *_old 目录（harbor 系统盘预计回落 ~29G））承 v1.47：（**新增 §19.4.9「变体：NFS 导出目录迁移到 LVM（K8s PVC 后端）」+ §14.9 时钟处置进展补记 + 巡检判据修正**：§19.4.9 固化 nfs 主机（10.120.0.33）`/opt/nfs/rancher`（238M/1447 条目，13 个 PVC 目录）与 `/backup` 双目录迁移至 vgdata（lvnfs 100G + lvbackup 200G、VG 留余量）的完整流程——与数据库迁移的三处本质差异（停写入方=K8s 缩容而非本机服务、核心风险是 NFS stale file handle 而非 systemd 反拉、窗口由缩/扩容主导）、K8s 侧 PV/PVC/负载清单化命令（kubectl+jq）、ansible 全网残留挂载硬闸、受控重启前置、动态供给功能验证必做项，以及 **provisioner 漏缩致 ESTALE 的现场事故复盘**（`mkdir /persistentvolumes: file exists` 指纹、MkdirAll 三步机理、rollout restart 处置、三条教训）与 lvextend 100G→200G 不停服在线扩容实证。§14.9 补记：2026-07-08 ~17:00 平台停 agent 对时后锯齿即止（harbor 末次 step 16:57/50.723s），07-09 10:19 全网 15 台今日 chronyd 日志零记录（~17h 干净）；`Frequency 15.33ppm slow + Skew 0.51ppm` 证明宿主机仍在漂移——止血≠根治，工单保持打开；makestep 收敛与多源加固窗口已到。§18.2/§14.9 判据修正：`grep -c was stepped` 是历史累计（vbdb01 累计 463 次永不归零），现状判据改看「今日无记录/最后一次 step 时间戳」）承 v1.46：（**§19.4 迁移流程按 vbdb01 现场首执结果修订闭环 + 新增 §14.9 虚拟化平台周期性时钟回拨现场案例**：修复 §19.4.1/§19.4.5 `su -c "$VB_SQL ..."` 双引号外层展开缺陷与「root 交互 shell source backup.env 污染 LD_LIBRARY_PATH → su 经 PAM 报 `Module is unknown`」问题，两处改 `su - vastbase <<'EOF'` heredoc 会话内 source；§19.4.4 fstab 写入后补 `systemctl daemon-reload` + `findmnt --verify` + `vastbase.mount` 核验；§19.4.5 验收升级（迁移前后逐库表计数快照比对、`rm -rf` 前手动全量备份、窗口内受控重启以 pg_log 判定干净启停、归档 off 记不适用并列风险项、手工改名备份目录须手动回收）；新增 §19.4.8 vbdb01 现场执行记录（mask 偏差、GAUSSLOG 噪音、du 差异判读、location 与 spcname 不一致严禁 rename）。§14.9 新增：虚拟化平台（pitrix guest-agent）每 30 分钟将自由漂移（~16.4ppm）的宿主机时钟强制同步全部虚机、与 chronyd `makestep 1.0 -1` 形成每小时 4 次 ±50 秒锯齿——vbdb01/nginx01/harbor 三机日志相位互锁定责的完整排查序列、定量证据、平台工单要点与处置顺序；§2.3 时钟同步加固（≥3 源、makestep 收敛、虚拟化双重对时红线）、§18.2 巡检新增时钟健康判据）承 v1.45：（**修复 §11.6.3 清理收尾在保留 `appdb` 的目标机上会误删在用表空间目录的缺陷：`pg_location` 孤儿目录清理改为 catalog 驱动豁免名单 + 逐目录显式删除，废止 `rm -rf ./tbs_*` 裸通配**：目标机按 KEEP 名单保留 `appdb` 时，其在用表空间 `tbs_app_data`/`tbs_app_idx` 的 location 目录与孤儿 `tbs_*` 同层混在 `pg_location` 下、`\db` 也仍显示这两个表空间——v1.44 的前置检查"\db 只应剩 pg_default/pg_global"在该场景永不成立，`rm -rf ./tbs_*` 会连在用表空间的活数据一并删掉。改法：清理前先查 `pg_tablespace_location(oid)` 取"在用 location"权威豁免名单（查询失败即停手，拿不到名单绝不删）、在用目录跳过、孤儿目录逐个且仅在内部无任何文件时 `rm -rf "./$d"`；§11.6.1 KEEP 名单与 §11.6.3 第 2 步 `KEEP_TBS` 同步补 `tbs_app_data`/`tbs_app_idx`（`DROP TABLESPACE` 对非空表空间本会报 not empty 拒绝，属内置保险，但名单写全免噪声误判）。承 v1.44：（**新增灌数日志落盘 + 生产/恢复逐库表数比对（含整库漏备检测）+ `pg_location` 孤儿目录清理；并定位修复 `dog` 库被 `databases.list` 注释陷阱静默漏备**：§11.4 b) 灌数重输出落盘 `restore_<ts>.log`、屏幕只留 OK/FAIL；§11.4 d/e/f 用 `comm`/`join` 比对生产与恢复逐库表数，抓"整库漏备"与"表数不一致"；§10.3.2 示例清单不再用真库名作排除示例、`cat`/`dog` 列为激活库并加"真业务库勿留注释"告警；§11.6.3 补方案二清理后 `pg_location` 残留目录的红线清理收尾）承 v1.43：（**修正 §11.4 c) search_path 自检误报**：旧判据 `*\"*)` 会把正常默认值 `"$user",public` 当坏值告警；改为 `*\"*,*\"*` 只在"引号包整串、逗号在引号内"的真坏形态 `"ai_helper, public"` 时才告警。并把告警前缀 `!!` 改 `WARN:`，规避交互粘贴时 `!!` 被 bash 历史展开。`pg_db_role_setting` 权威查询不变）承 v1.42：（**修复校验文件写死绝对路径问题**：①②§10.4 的 create.sql/globals sidecar 由 `sha256sum 绝对路径` 改为 `cd $RUN_DIR && sha256sum basename`，不再把 `.running.<ts>` 临时目录绝对路径写进 sidecar——否则改名/搬迁后 `sha256sum -c` 在任何机器都报 `No such file or directory`；③§10.7 `SHA256SUMS` 改 `cd $BASE_DIR && find . ... ! -name SHA256SUMS`，相对路径可搬迁；④§11.4 还原校验由 `sha256sum -c` 改为**直接比对哈希**，对旧坏 sidecar 与新 basename sidecar 都兼容、历史备份无需重做）

---

## 版本修订记录

| 版本 | 日期 | 修订内容 |
|------|------|----------|
| v1.0 | 2026-05-26 09:00 | 基于原 Oracle 兼容模式 v1.5 部署文档改写为 MySQL 兼容模式版本：统一兼容模式为 `B`，替换初始化、建库、恢复、验收、预检脚本中的 `DBCOMPATIBILITY`；重写 MySQL 兼容参数、建表示例、兼容性验证与常见问题；保留原文生产交付优化、备份/PITR、审计、巡检和交接闭环。 |
| v1.1 | 2026-05-26 10:00 | 按兼容模式合规性审查修订：修正审计查询中残留的 Oracle 风格时间函数；主键索引显式落到索引表空间；补充 `vastbase_sql_mode` 起步基线与验收/预检；补充不依赖 `DELIMITER` 的过程示例；备份 manifest 写入兼容模式并在恢复脚本中校验；修正附录裸 `gs_ctl`/`gs_initdb` 命令与 `vb_*` 兜底。 |
| v1.2 | 2026-05-26 18:00 | 针对 VastBase G100 V3.0.8PSU4 定版：新增命令适用性标识与版本注意事项；补充 `vb_dump/vb_restore` PSU4 增强选项说明；修正 WDR 示例为非 PG 兼容模式可用的位置参数写法；补充 `lower_case_function_names`、`DATE_FORMAT/FROM_UNIXTIME/STR_TO_DATE` B 模式专用、`now()/CURRENT_TIMESTAMP` 精度行为、`block_return_multi_results` 等版本注意事项。 |
| v1.3 | 2026-05-26 22:00 | 按 V3.0.8PSU4 审计复核修订：初始化改为 `--pwfile` 推荐并要求留存 `vb_initdb --help` 证据；新增建库前 MySQL 关键参数节；PITR 脚本支持新旧恢复控制文件；备份/恢复兼容模式校验增加字面值归一化；补充微秒精度回归 SQL、审计目录创建、审计位掩码说明、同步复制风险提示、`databases.list` 与 `appdb` 示例拉齐。 |
| v1.4 | 2026-05-26 | 修正 §4.4 首次部署未启动实例调用 `restart`/`SHOW` 的阻塞问题；§6.7 改为参数台账核查，避免与 §4.4 重复 `set`/`restart`；统一 §11.3 `appdb` 恢复示例；将 `audit_system_object` 改为可解释位掩码 `15`；补强 `--pwfile` 中断清理、PITR `auto` 注释、预检分组和 root shell 验收命令。 |
| v1.5 | 2026-05-26 | 按通读复核意见修订：补齐 PITR 解包 `pg_wal.tar.gz` 与自定义 tablespace tar；修正 `log_temp_files`、`lower_case_column_names` 现场确认、默认权限 `FOR ROLE`、RELATIVE LOCATION 注释、归档/恢复脚本、分区表统计、MySQL 前置参数提示、license 日检、`max_wal_senders` 预检和交付物清单。 |
| v1.6 | 2026-05-28 | 补充部署后性能压测闭环：扩展第 20 章为可执行压测方案，新增 32GB/64GB 内存规格参数起步基线、sysbench/业务回放示例、OS/数据库/WDR 采集、通过标准、调参闭环和压测报告模板；同步更新投产顺序、验收清单与交付物清单。 |
| v1.7 | 2026-05-28 | 按压测审核意见修订：§6 与 §20.3 统一为 32GB 起步保守值；修正 sysbench 并发档与断点续跑；改用 `$VB_GUC` 启用 WDR 并补充 interval/retention；新增 huge_pages 与 fio 基线；§20.12 改为引用标准压测报告模板；补充 MySQL 协议层澄清、并行执行参数、缓存预热、VACUUM ANALYZE、CPU 分级验收、稳定性压测避开 cron、压测清理 checklist 与 §22 交付物。 |
| v1.8 | 2026-05-28 交付复核版 | 按三文档一致性审核修订：补齐性能采集参数下发链路、WDR 去重提示、硬件三档基线、日常监控 CPU/内存/swap/命中率阈值、fio 工程化基线、sysbench 断点续跑/预热/连接保护、MySQL 兼容 SQL 回放清单、参数变更兼容回归列、压测清理与报告模板 v1.2 对齐。 |
| v1.9 | 2026-05-28 二次修订版 | 按压测报告目录一致性审核修订：§20 统一 `REPORT_DIR` 与 `.perf_test_current` 哨兵文件；修正 OS 采集启动/停止目录与进程复核；补充 iperf3 网络基线、pgbench fallback、稳定性 soak 命令；统一 WDR/结果提取/清理证据路径；报告模板升级为 v1.3。 |
| v1.10 | 2026-05-28 三次修订版 | 修正 `perf_collect_os.sh` 用法提示引号问题；明确 sysbench 默认只输出 P95、P99 需 `SYSBENCH_PERCENTILE=99` 复跑或由业务压测平台提供；补齐 §6.8/§20.3 的 `sysadmin_reserved_connections=10` 下发；补充 `db_collect_during_NN.log`/`db_collect_after.log` 生成示例；统一标准报告模板路径为 `template-v1_4.md`；补充 iperf3 跨机器执行提醒和 fio 单文件多线程说明。 |
| v1.11 | 2026-05-28 四次修订版 | 按压测四次审核意见修订：统一 `REPORT_DIR` 引导块在首次执行时自动生成目录；修正 `sysbench_summary.csv` 提取器以支持 `sysbench_p95/p99_threads_*.log`、正确识别并发并输出表头；补齐 `default_statistics_target` 32GB/64GB 下发；DB 采集改为除 template 库外全采并增加 `pg_stat_bgwriter`；补充 WAL fio 同盘说明、压测机侧资源采集和 `pg_prewarm` 兜底说明；报告模板升级为 v1.5。 |
| v1.12 | 2026-06-06 | 修复 §11.2 `db_restore.sh` 恢复成功却误报对象级错误的问题：异名恢复 `-n`（目标为新库）与远端 `-r` 拉回到已手工 `drop` 的库时，前置 `DROP DATABASE IF EXISTS` 打出的良性提示 `NOTICE: database "<db>" does not exist, skipping` 被全日志错误扫描的 `does not exist` 命中，导致 `vb_restore exit=0` 仍判 `not trustworthy`。改为：恢复阶段输出单独落 `VBRESTORE_LOG` 再并入主日志，错误扫描仅限恢复阶段、不扫 DROP/CREATE 阶段，并额外排除 `... does not exist, skipping` 良性提示；保留对真实 `ERROR: ... does not exist`（角色/schema 缺失等）的检测。 |
| v1.13 | 2026-06-07 | 按物理备份/PITR 一致性复核修订 §17：修复 `pitr_restore.sh`“等待 recovery 完成”循环与最终校对处直接调用 `${VB_SQL:-vsql} -h … -U … -d postgres` 绕过口令注入的问题——本机 VastBase（openGauss 内核）`vsql`/`vb_*` 不消费 `~/.pgpass`/`PGPASSFILE`，原写法在 cron/自动化下会回退到交互式 `Password for user vbadmin:` 并将恢复流程挂起，与 §10.3.1 全文采用的 `vb_sql`（`-2`/`--pipeline` 经 stdin 注入口令）方案不一致；统一改用 `vb_sql postgres` 封装。同步：§17.2.3 `archive_check.sh` 改用标准 `vb_sql` 封装、删除重复的 `vbq`/`ACK_PW` 口令路径；§17.2.2 归档验证 SQL 块、§17.4 演练速记补充“工具不读 `.pgpass`、连接须走 `vb_sql` 封装或交互输入口令”的说明（appuser 未配置在 `.pgpass`，演练时交互输入）；`pitr_restore.sh` 增加 `require_cmds VB_SQL VB_CTL` 快速失败，并在恢复等待循环处提示需 `hot_standby=on` 才能只读探测。§17.3 `db_basebackup.sh`（已正确使用 `vb_sql`/`vb_basebackup_run`）经核对无需改动。 |
| v1.14 | 2026-06-07 | 修复 §3.5 `license_check.sh` 在 V3.0.8PSU4 上无法读取到期日的问题：原脚本“方法 1”查询的 `dbe_perf.license_status` 视图与 `license_expire_date` GUC 在本版并不存在（实测报 `ERROR: relation "dbe_perf.license_status" does not exist`），“方法 2”又因 license 文件是加密/二进制、文本抽取不到明文日期（`file_parse=empty`），导致最终只能 WARN。改为以 VastBase 引擎启动时打印到服务器日志的 `License info ... Expires On:'YYYY-MM-DD HH:MM:SS'` 为权威到期来源，取值顺序为「服务器日志 → 可选 SQL（默认空、需现场确认后填 `SQL_CANDIDATES`）→ license 文件名日期（如 `*_license_20250731`）→ `strings` 兜底」；并修复若干健壮性问题：SQL 分支只接受非空结果（原 `||` 链在“查询成功但 0 行”时会误判已取到值并短路）、license 文件缺失改为 NOTE 告警而非直接判 CRITICAL、日志搜索目录可经 `LIC_LOG_DIRS` 覆盖。新增 §3.5 现场探测命令：定位 `License info` 日志路径、探测本版是否存在 license 查询函数/视图/GUC、核对 license 文件命名。 |
| v1.15 | 2026-06-07 | §3.5 落实现场探测结果：探测确认本版在 `pg_catalog` 下提供无参函数 `license_expired_time()`（返回 `timestamp without time zone`），并存在 `license_path`/`vb_license_path`/`vb_license_expired_notify_time` 三个 GUC；`pg_class` 无 license 相关视图。据此把 `SELECT license_expired_time();`（含 schema 限定变体）预置进 `license_check.sh` 的 `SQL_CANDIDATES`，并将取值顺序由「日志优先」调整为「SQL 函数优先 → 启动日志 `Expires On` → license 文件名日期 → `strings`」——SQL 函数由引擎实时返回、跨重启稳定，不依赖日志保留周期，比日志更可靠（上一版日志为空正是因为 `License info` 行已随日志轮转清理）。同步更新 §3.5 说明：给出 `license_expired_time()` 输出示例、相关 GUC 用途、以及该函数仍需经 `pgpass_lookup`+`-2` 注入 vbadmin 口令（本机不消费 `.pgpass`）。 |
| v1.16 | 2026-06-08 | 全文清理 openGauss 内核不存在的 PG10+/PG9.4+ WAL/归档对象。现场实测：`SELECT pg_switch_wal();` → `ERROR: function pg_switch_wal() does not exist`；`SELECT * FROM pg_stat_archiver;` → `ERROR: relation "pg_stat_archiver" does not exist`——VastBase G100 基于 openGauss（PG 9.2.4 内核），WAL 函数沿用 9.2 时代 `xlog` 命名（`pg_switch_xlog()`/`pg_current_xlog_location()`/`pg_xlogfile_name()`/`pg_xlog_location_diff()`），且 `pg_stat_archiver` 视图（PG9.4 引入）整体缺失；WAL 目录为 `pg_xlog`。本版统一修订 7 处：**(1) §17.2.2** 验证改两步——vsql 内 `SELECT pg_xlogfile_name(pg_switch_xlog());` 触发切换，再退 shell 核对 `/vastbase/arch` 新段、`archive_status/*.ready` 堆积、`wal_archive.log`。**(2) §17.2.3** `archive_check.sh` 彻底弃用查库（原 `... FROM pg_stat_archiver 2>/dev/null \|\| true` 在本内核必报错被吞、`$ROW` 恒空，导致脚本静默退化为“只查盘容量、永远报 OK”，归档真断也不告警——高危隐患），改为统计 `$PGDATA/pg_xlog(或 pg_wal)/archive_status/*.ready` 堆积量，自动适配目录名，WARN≥3 / CRIT≥10 双阈值，不再连库（须以可读 `$PGDATA` 的用户执行）。**(3) §1 红线表**：“`pg_stat_archiver` 持续失败”改为“`archive_status/` 下 `.ready` 持续堆积”。**(4) §12.3.4** 复制槽 lag 查询：`pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn))` 改为 `pg_size_pretty(pg_xlog_location_diff(pg_current_xlog_location(), restart_lsn))`（openGauss 中 `pg_xlog_location_diff(text,text)` 返回 numeric，`pg_size_pretty` 直接接收）。**(5) §18 `monitor.sh`** 第 7 项归档检查：同 §17.2.3 改为 `.ready` 堆积判断，复用脚本既有 `warn`/`crit` 与同档阈值，目录未找到时 `warn` 而非静默放行。**(6) §20** `perf_collect_db.sql` 删除 `SELECT * FROM pg_stat_archiver;`（会报错污染采集日志），改为注释说明；并在 §20 采集 shell 块新增 `collect_arch` 函数，在 before/during_NN/after 三个采集点把 `.ready` 堆积量、归档目录文件数与盘使用率写入 `$REPORT_DIR/arch_health.log`，压测报告仍保留归档健康证据。**(7) §21** 验收表 WAL/归档行与 §21.5 `monitor.sh` 衔接备注（`pg_wal_lsn_diff` → `pg_xlog_location_diff(...)`）一并改正。归档健康判据全文统一为“`.ready` 是否持续堆积”。 |
| v1.17 | 2026-06-08 | 修复 §10.3.1 `backup.env` 中 `vb_basebackup_run` 误用本版不支持的 `--pipeline`。现场实测 `db_basebackup.sh` 报 `/vastbase/app/bin/vb_basebackup: unrecognized option '--pipeline'` 后失败（v1.16 的归档验证此前已在现场全部跑通：`pg_xlogfile_name(pg_switch_xlog())` 正常切换、归档目录紧跟出现新段、`archive_status` 全 `.done` 无 `.ready`、`archive_check.sh` 输出 `OK .ready=0`）。根因：`--pipeline`（经 stdin 注入口令）是 `vsql`/`vb_dump`/`vb_restore` 支持的选项，但本版 `vb_basebackup` 没有（`vb_basebackup --help | grep -- '--pipeline'` 为空）。原 v1.13 复核误判“§17.3 已正确使用 `vb_basebackup_run` 无需改动”，实为该封装套用了 `--pipeline` 写法但从未在本版实跑过。改法：`vb_basebackup_run` 改为**运行时探测**——`vb_basebackup --help` 含 `--pipeline` 则仍走 stdin 注入（首选，零明文）；不含则降级为**子 shell 内** `PGPASSWORD`（`( export PGPASSWORD=...; exec "$VB_BASEBACKUP" ... )`），口令不进父环境/命令行/`ps` args，仅在备份进程运行期间存在于其 `/proc/<pid>/environ`（同用户/root 可读），随子 shell 销毁，与 §3.x 对 `vb_restore`/`vb_dumpall` 既有的降级策略一致。同步：§10.3.1 安全说明把“不使用 `PGPASSWORD`”修正为“首选不用、无 `--pipeline` 时子 shell 限定降级”并说明残留暴露面；§17.3 部署前检查说明改为“封装已内置探测自动降级、无需手工改脚本”。 |
| v1.18 | 2026-06-08 | 修复 §17.3 `db_basebackup.sh` 在本内核上的 WAL 方式不兼容。v1.17 修好口令注入后，现场实测改报 `vb_basebackup: wal streaming can only be used in plain mode`。根因：本版 `vb_basebackup`（openGauss 9.2.4 内核）沿用 PG10 之前行为——**tar 格式 (`-F t`) 不能与 `-X stream` 同用**（tar+stream 是 PG10 才引入，commit 56c7d8d4）。原脚本用 `-F t -z -P -X stream`，且 §17.4 解包逻辑按 PG10+ 产物 `base.tar.gz + pg_wal.tar.gz + <oid>.tar.gz` 编写——这套假设在本内核不成立。改法：**(1) §17.3** 调用改为 `-X fetch`（`-F t -z -P -X fetch`）：所需 WAL 在备份结束时从服务器 `pg_xlog` 收取并写入 `base.tar` 内部（pre-10 服务器落在 tar 内 `pg_xlog/`），不再单独产出 `pg_wal.tar.gz`；引言补充 fetch 需 `wal_keep_segments` 足够覆盖备份窗口（fetch 不流式拉取、结束时一次取 WAL，起点 WAL 若被 checkpoint 回收则备份不可用）、fetch 仅用一条普通连接不占 walsender、以及如需 stream 特性只能改 plain 格式整体改造的说明。**(2) §17.4** `pitr_restore.sh` 把“解 `pg_wal.tar.gz`”单分支改为防御性循环：本版 fetch 备份的 WAL 已随 `base.tar.gz` 解到 `$PGDATA/pg_xlog/`，无需单独解；循环仅在存在 `pg_wal.tar.gz`/`pg_xlog.tar.gz`（未来 tar+stream 版本或 plain+stream 手工打包）时按内核命名解到对应 `pg_wal`/`pg_xlog`。**(3) §21.5** 备库搭建示例补充提示：本版 `vb_basebackup --help` 未列出 `-R`，若不支持需手工写 `standby.signal`/`primary_conninfo` 或用官方 `gs_ctl build`/`gs_om` 流程（该节为 L1 方向性示意，正式主备以独立 HA/DR 文档为准）。注：§21.5 主备建库的 `-F p -X stream` 属 plain+stream，本就合法，未改。 |
| v1.19 | 2026-06-08 | **修复 openGauss tar 格式备份包的解包工具误用——此前 PITR 恢复必然失败的致命缺陷。** v1.18 备份成功后现场实测：`tar -zxf base.tar.gz` 报 `does not look like a tar archive`，`MANIFEST.txt` 的 `start_wal` 为 `unknown`。根因：`vb_basebackup -F t` 产出的 `base.tar(.gz)`/`<oid>.tar(.gz)` 是 **openGauss 私有 tar 封装，必须用 `gs_tar`/`vb_tar` 解，GNU `tar` 解不了**；且本版 `gs_tar`（实为 `gs_basebackup` 的 multi-call 软链，无独立 `vb_tar`）**不自带 gzip**——直接喂 `.tar.gz` 报 `could not parse file size`，须**先 `gunzip` 去 `.gz` 层再 `gs_tar -D <dir> -F <tar>`**（现场已用该流程实测成功解出完整 `$PGDATA`，`backup_label`、fetch 收进的起点 WAL `pg_xlog/<seg>` 均在）。影响面：§17.4 PITR 解包、§17.3 `extract_backup_label`、§17.6 `wal_cleanup.sh` 的 `extract_start_wal` 全部误用 GNU `tar -xzf`/`tar -xOf`，**备份其实无法恢复**。改法：**(1) backup.env** 新增 `VB_TAR` 探测（`vb_tar`→`gs_tar` 兜底）与 `vb_untar_gz <包> <目标>` 封装（gunzip + gs_tar；并把 openGauss 双写文件 `global/pg_dw.build` 的良性 `Invalid argument` 告警视为成功，该文件启动自动重建）。**(2) §17.4** `pitr_restore.sh` 的 `base.tar.gz`、`<oid>.tar.gz` 表空间包、防御性 WAL 包分支全部改用 `vb_untar_gz`，并在解 base 后加 `PG_VERSION`/`global` 哨兵校验；`require_cmds` 增 `VB_TAR`。**(3) §17.3** `extract_backup_label` 改用 `vb_untar_gz` 解到临时目录读 `backup_label`；并新增更省的 `start_wal` 主路径——从 `gs_basebackup` 日志的起始 LSN（`The starting position of the xlog copy ... is: 0/XXXX`）经 `pg_xlogfile_name()` 求文件名（库在线、知当前时间线，不必解 60M 包），失败再退化为解包读 label；`require_cmds` 增 `VB_TAR`。**(4) §17.6** `wal_cleanup.sh` 补 `source backup.env`，`extract_start_wal` 的 tar 分支改 `vb_untar_gz`（其 `MANIFEST.txt` 主路径已因本版 `start_wal` 修复而可靠，且抽不到起点 WAL 时拒删，安全）。**(5)** §17.3 引言新增 openGauss tar 解包工具说明与“手工验证备份可恢复”片段；附录自检 `require_cmds` 增 `VB_TAR`。 |
| v1.20 | 2026-06-08 | **修复 §17.4 `pitr_restore.sh` 三处缺陷（带自定义表空间时此前 PITR 必然失败）。** 现场实测 `./pitr_restore.sh -b <full_path> -t ...` 报 `line NN: die: command not found` 后接 `ERROR: cannot find tablespace path for OID=23561`，恢复中断。排查确认该实例有三个表空间（`23561 tbs_app_data`、`23562 tbs_app_idx` 落在 `$PGDATA/pg_location/` 下的库内相对位置；`23567 jobs_server` 在库外 `/data/tbs/jobs_server`），备份目录确有对应 `<oid>.tar.gz` 且无 `tablespace_map`。改法：**(1)** 脚本只定义 `say()` 却大量用 `... || die`，`die` 从未定义、`backup.env` 也不提供，加之 `set -uo pipefail` 无 `set -e`，未定义的 die 只打印 `command not found` 并继续，所有失败护栏静默失效——在 `say()` 后补 `die() { say "ERROR: $*"; exit 2; }` 恢复 fail-fast。**(2)** `find_tablespace_path` 误查 `backup_label`（任何版本都不含表空间映射）、本版 openGauss tar 备份不生成 `tablespace_map`、`pg_tblspc/<oid>` 软链常被 gs_tar 漏建，路径解析全落空——改为优先读【刚移到 `$SAVE` 的旧 PGDATA】的 `pg_tblspc/<oid>` 软链（`readlink` 取字面目标、勿用 `-f`），并支持 `TBLSPC_MAP_FILE`/`TBLSPC_<oid>` 异机 DR 覆盖，`tablespace_map` 仅末位兜底。**(3)** 表空间解包用 `[[ "$TBL_PATH/" == "$PGDATA"/* ]]` 区分库内/库外：库内（旧数据已随 PGDATA 进 `$SAVE`）清空重解、不留 `.crashed` 垃圾；库外先移现存目录到同级 `.crashed.<ts>` 再解；两类解后均 `ln -sfn` 重建 `pg_tblspc/<oid>` 软链。另：`-b` 支持只给目录名自动补 `$BACKUP_DIR/base/<name>`、演练验证查询改列全部非默认表空间、新增 `-t` 目标时间须落在“备份完成后、误操作前”区间且带时区的提示。 |
| v1.21 | 2026-06-08 | **修复 §17.4 PITR 解包被 `gs_tar: destination dir "..." no empty.` 卡死、及实例被自动拉起的安全隐患。** v1.20 补回 die 后现场实测，恢复在解包哨兵处早停：`gs_tar` 要求目标目录为空，而停库后有进程在 `$PGDATA` 留下 `pg_ctl.lock` 致其“非空”，更严重的是可能在半恢复目录上普通启动、绕过 `recovery.conf` 使 PITR 静默失效。改法：**(1)** 第 3 步解包改到独立 staging 目录 `${PGDATA}.restore.<ts>`（同文件系统），`PG_VERSION`/`global` 哨兵过后 `rm -rf $PGDATA && mv staging $PGDATA` 原子换入，规避 gs_tar 空目录要求并把锁竞争窗口压到微秒级。**(2)** 第 1 步在销毁 PGDATA 之前加安全闸：停库后 `sleep 8` 探测 `postmaster.pid` 重现或 `om_monitor`，被拉起则 `die` 早停（数据完好可重试）；新增 `PITR_STOP_MONITOR_CMD`/`PITR_START_MONITOR_CMD` 钩子在恢复前后停/复原监控。`postmaster.pid` 重现作为内核无关信号，适配 cluster/非 cluster 安装。 |
| v1.22 | 2026-06-08 | **定位 §17.4 解包卡死真凶为 systemd 反拉，加 systemd 托管安全闸。** 接 v1.21 现场诊断：停库后等 8 秒 `postmaster.pid` 未重现、无 `om_monitor`/`cm_agent`/`gaussdb` 进程、无 cron、`monitor.sh` 无 start 逻辑，`pg_ctl.lock` 时间戳停留在 16:32（上一次失败 run），即【一次性残留而非周期重建】。真凶是 `vastbase.service`：`Type=forking` + `Restart=on-failure` + `ExecStart=/vastbase/app/bin/vb_ctl start -D /vastbase/data`。机制：脚本用 `vb_ctl stop` 绕过 systemd 停 postmaster，systemd 视为主进程异常退出，按 `Restart=on-failure` 立即 `ExecStart=vb_ctl start`，正撞在脚本刚 `mkdir` 的空 `/vastbase/data` 上——建了 `pg_ctl.lock` 但空目录起不来（无 `postmaster.pid`），systemd 转 `failed`，留下孤儿锁，gs_tar 随即因“目录非空”罢工。改法：**(1)** 第 1 步在停库前自动探测 `ExecStart` 指向本 `$PGDATA` 的 systemd unit（`systemctl cat` 匹配 `-D $PGDATA`，限定名含 vastbase/gauss/opengauss），用只读、无需 root 的 `systemctl is-active` 判定；若为 active/activating/reloading 则 `die` 早停（数据完好），提示运维以 root 执行 `systemctl stop && systemctl mask` 后重跑，并给出验收后 `vb_ctl stop; systemctl unmask; systemctl start` 的交还流程；`PITR_SYSTEMD_UNIT=<unit>` 可显式指定、`=none` 可跳过探测。**(2)** 原 `postmaster.pid` 兜底安全闸保留，覆盖 om_monitor/自建脚本等非 systemd 来源。**(3)** §17.4 演练说明新增“systemd 托管实例（`Restart=on-failure`）必读”的停/屏蔽→恢复→交还标准流程，强调 `systemctl stop` 属主动停止不触发 Restart、`mask` 再加保险、promote 后 `recovery.conf` 自动转 `recovery.done` 故交还时为正常启动。说明：v1.21 的 staging 解包对本问题的表层（gs_tar 目录非空）本已免疫，本版进一步在源头拦截 systemd 反拉、消除“半恢复目录被普通启动”的一致性风险。 |
| v1.23 | 2026-06-08 | **修复 §17.4 自动拉起安全闸对“过期 postmaster.pid”的误报。** v1.22 现场实测：`./pitr_restore.sh -b 2026-06-08_121947 -t '...+08'`，systemd 闸正常通过（`vastbase.service`=inactive），但停库 8 秒后兜底闸报“检测到 postmaster.pid 重现”而 `die` 早停；然而 `ps -x` 无 gaussdb 进程、`ls $PGDATA` 为完整数据目录——该 `postmaster.pid` 是上次强杀/非正常退出的**过期残留**，实例并未运行。根因：v1.22 闸判据 `[[ -f "$PGDATA/postmaster.pid" ]]` 把“文件存在”等同于“实例在运行”，对过期 pid 文件必然误报。改法：判据改为读 `postmaster.pid` 首行 PID 并核验其为【存活进程】（`kill -0 $PMPID`）且【cmdline 含 gaussdb】（`tr '\0' ' ' < /proc/$PMPID/cmdline | grep gaussdb`，防 PID 复用误判），二者皆真才判定在运行；仍保留 `om_monitor` 外部来源检测。过期 pid（进程已不存在）不再阻断，仅记一条提示，随后整目录移到 `$SAVE`。临时绕过办法：确认 `vb_ctl status -D $PGDATA` 报未运行后 `rm -f $PGDATA/postmaster.pid*` 再跑。 |
| v1.24 | 2026-06-08 | **修复 §17.4 legacy `recovery.conf` 误写 `recovery_target_action` 致恢复后实例无法启动。** v1.23 现场实测：解包、三个表空间（库内 `tbs_app_data`/`tbs_app_idx` + 库外 `jobs_server`）、写 recovery 全部成功，但 `vb_ctl start` 在 `waiting for server to start...` 后 `waitpid ... exitstatus 256 / could not start server`；root `systemctl start vastbase` 用同一恢复数据同样失败。捞 `$PGDATA/pg_log/postgresql-*.log` 得真因：`database system was interrupted; last known up at 2026-06-08 12:19:49` 之后 `FATAL: unrecognized recovery parameter "recovery_target_action"`，startup 进程被 signal 1 终止。根因：`recovery_target_action` 为 PG12+ 引入参数，本版 openGauss 9.2.4 内核的 legacy `recovery.conf` 不识别，解析即 FATAL。旁证：归档完整（`/vastbase/arch` 含起点段 `...B9` 及其后 `BA`～`C6`，覆盖 12:19→12:30 目标窗口）、`backup_label` 起点 LSN `0/B9000028` 与 `pg_xlog/0000000100000000000000B9` 均在——数据与归档侧本无问题，纯属配置行不兼容。改法：**(1)** `write_recovery_settings` 的 legacy 分支删去 `recovery_target_action = 'promote'`，仅写 `restore_command` + `recovery_target_time`/`recovery_target_xid` + `recovery_target_inclusive`；本内核归档恢复到点后、在无 `standby.signal`/`primary_conninfo` 时自动结束恢复并以读写库开服（`recovery.conf` 自动转 `recovery.done`）。signal 分支（PG12+ 派生包）保留 `recovery_target_action`，并在 §17.4 注释与 style 说明中标注其内核适用范围。**(2)** §17.4 演练说明补“本内核 legacy `recovery.conf` 不支持 `recovery_target_action`”及现场实测可用的 `recovery.conf` 范例。验证：删行后 `vb_ctl start -t 600` 正常起库，`SELECT * FROM app.t_order` 返回恢复目标点前的 3 行，PITR 达成。 |
| v1.25 | 2026-06-08 | **§17.4 PITR 自动接管 systemd 停/起，免人工切 root 交接（A 模式）+ 优雅降级到手工（B）。** 背景：v1.24 端到端跑通（systemd 闸拦截→停库→解包→三表空间→写 recovery→`pg_is_in_recovery()=f`→`t_order` 三行回归），但需运维手工 `systemctl stop/mask` 与验收后 `vb_ctl stop`+`systemctl unmask/start` 交还，较繁。改法：**(1)** 第 1 步新增 systemd 控制能力探测——脚本以 root 跑则用 `systemctl`；否则以合法 is-active 状态词判定 `sudo -n systemctl` 免密是否可用（不能只看返回码，因 is-active 对 inactive 返回非 0）。**(2)** A 模式（`PITR_SYSTEMD_AUTO=1` 默认 + 探测到控制能力）：unit 为 active 时自动 `systemctl stop`（主动停止不触发 `Restart=on-failure`，故无需 `mask`），轮询确认已停，置 `SYSTEMD_DID_STOP=1`；新增第 8 步在校验后自动 `vb_ctl stop` 恢复实例并 `systemctl start` 交还（`recovery.conf` 已转 `recovery.done` 属正常启动），失败则 WARN 不静默。**(3)** B 模式（无 root/免密 sudo 或 `PITR_SYSTEMD_AUTO=0`）：维持 v1.24 行为——active 时销毁数据前 `die` 早停，提示配免密 sudo（给出 `/etc/sudoers.d` 一行范例）或手工 `stop/mask→恢复→unmask/start`。**(4)** §17.4 演练说明改写为 A（免密 sudo 全自动）/ B（手工）双路径并附 sudoers 配置。注：仅当本脚本自动停过 unit（`SYSTEMD_DID_STOP=1`）才自动交还；运维手工 stop+mask 的 B 路径不自动 start，按其手工流程恢复，避免与 mask 冲突。 |
| v1.26 | 2026-06-15 | **新增 §18.3 VastBase 内存专项巡检与排障。** 将现场内存排查经验固化到运维文档：补充 `free/top/ps/proc/smaps_rollup/vmstat/dmesg` 等 OS 命令、数据库侧 `SHOW`/`pg_settings`/`pg_stat_activity`/内存视图探测 SQL、OOM/Swap/慢 SQL/临时文件日志定位、一键采集脚本 `/vastbase/scripts/memory_check.sh` 与示例日志。明确 `VIRT` 不等于真实占用，重点看 `RSS/PSS/Private/Swap`；现场样例 `Pss≈2.6GB、Swap=0、vmstat si/so=0` 判定为当前无内存压力，但需关注 `max_connections=3000` 与 `work_mem=64MB` 的高并发放大风险。 |
| v1.27 | 2026-06-15 | **新增 §17.2.4 pg_xlog 膨胀、归档失败与同名 WAL 冲突排查处置。** 将现场 `/vastbase/data/pg_xlog=27G`、`1690` 个 WAL 段、`archive_status/*.ready=1680`、`.done=0`、`wal_archive.log` 反复报 `FAIL: 0000000100000000000000BA exists with different md5` 的完整处理过程固化到文档：补充 OS 排查命令、数据库参数/复制槽 SQL、归档链路验证、测试环境隔离旧 `/vastbase/arch`、恢复归档、开启 `enable_xlog_prune`、checkpoint 验证、生产配置建议、归档容量估算、清理边界和禁止直接删除 `pg_xlog` 的红线。 |
| v1.28 | 2026-06-15 | 按高级 DBA 审核意见修订 §17.2.4/§18.3：`enable_xlog_prune` 不再作为归档失败修复步骤，仅在告警/兜底说明中作为需配套 `max_size_for_xlog_prune` 的磁盘保命阀，并明确归档失败时触发 prune 可能回收未归档 WAL、断裂 PITR 链；补充隔离旧 `/vastbase/arch` 后必须重做物理全量备份；细化复制槽 `active/restart_lsn` 判读和旧槽处置；修正 VastBase/openGauss 参数名为 `sysadmin_reserved_connections`；加固 `memory_check.sh` 在 cron 下使用 `vb_sql` 封装取数，避免数据库段静默为空；补充 `enable_memory_limit`、`max_process_memory` 与 `work_mem` 的内存判读链条。 |
| v1.29 | 2026-06-15 | 按高级 DBA 二次反馈微调：`.ready` 归档健康判据、阈值与目录自适应逻辑保持不变；将 §18.5 `monitor.sh` 中 `/vastbase/arch` 归档盘使用率 WARN 阈值由通用磁盘 75% 单独提前为 70%，与 §17.2.3/§17.2.4 对齐；在 §17.2.4 补充隔离旧 `/vastbase/arch` 并重做物理全量后，应同步清退或归档失效旧 basebackup 目录，避免 §17.5 `wal_cleanup.sh` 继续以不可恢复的旧备份 `start_wal` 作为清理边界。 |
| v1.30 | 2026-06-16 | 按高级 DBA 对内存专项脚本的两轮反馈修订 §18.3：`memory_check.sh` 升级为 v3，修复 `vb_sql` 作为 `backup.env` 中 shell 函数在 `bash -c` 子 shell 中不可见的问题，确保 `pg_total_memory_detail` 可真实采集；数据库日志扫描拆分为“内存高信号”“严重级别事件”“磁盘写失败事件”，避免 `grep -i ERROR` 误命中 WDR `error_count`；增加 cgroup v1 `memory.stat` 的 `rss/cache` 拆分说明，避免把 page cache 误判为数据库 RSS；整理 2026-06-16 现场运行效果，明确当前无内存问题，真正事故线索为 2026-06-14 磁盘打满导致数据库 PANIC。 |
| v1.31 | 2026-06-16 | 按高级 DBA 对 `monitor.sh` 的反馈修订 §18.5：修复长事务检查误报内部 WLM 后台线程的问题，长事务与 idle in transaction 仅统计真实客户端会话，并通过 `application_name` 白名单兜底排除 `workload`/`WLMmonitor`/`WLMarbiter`；新增监控日志策略，日常只记录异常与状态翻转，避免每 5 分钟落一条 `all OK` 噪声；补充 `/etc/logrotate.d/vastbase-monitor` 轮转配置和按需 `bash -x` trace 排查方法。 |
| v1.32 | 2026-06-16 | 按高级 DBA 三次反馈修订 §18.5：废弃 crontab 中的多行复合命令，新增 `/vastbase/scripts/monitor_cron.sh` wrapper，避免 cronie 不支持反斜杠续行和 cron 默认 `/bin/sh` 不支持 `[[ ]]` 的风险；`vbq` 统一注入 `PG_HOST`/`PG_PORT`/`PG_USER`，避免非 5432 端口下连接数、长事务、idle in transaction、死元组检查静默漏测；本地备份 `BACKUP.OK` 增加 `BACKUP_DEADLINE_HOUR` 时间闸，避免每日备份窗口前 CRITICAL 邮件风暴；补充 `client_addr IS NOT NULL` 对本地 unix socket 业务连接的监控盲区、`license_check.last` 输出格式契约以及 trace/白名单使用边界。 |
| v1.33 | 2026-06-16 | 按高级 DBA 四次反馈修订 §18.5：修正 License crontab `0 9 * * * *` 六字段错误为标准 cronie 五字段 `0 9 * * *`，避免第六个 `*` 被当作命令导致 license 日检实际不执行；第 10 项 License 检查增加 `LIC_CACHE_MAX_AGE_H` 新鲜度闸，默认缓存超过 36 小时即 WARN，不再信任冻结的旧 `remaining=NNd`；补充 `monitor_cron.sh` 和异地备份邮件告警依赖 `mail`/`mailx` 与本机 MTA 的前置说明。 |
| v1.34 | 2026-06-16 | 按高级 DBA 最终复核修订 §18.5.3：将 `/vastbase/scripts/monitor_cron.sh` 示例中的 `printf` 从单引号跨行形式还原为 `printf '%s\n' "$out" | mail ...` 单行写法，避免归档文档看起来像转义符被误处理，也降低复制粘贴和格式化工具处理风险；逻辑不变，§18.5 监控脚本定稿。 |
| v1.35 | 2026-06-18 | **新增 §14.8 应用接入时间类型不匹配（TIMESTAMPTZ ↔ Java LocalDateTime）现场排障案例。** 将一次 Spring Boot + MyBatis(-Plus) 业务容器访问 `ai_helper.sg_aigc_session` 报 `BadSqlGrammarException → PSQLException: Cannot convert the column of type TIMESTAMPTZ to requested type java.time.LocalDateTime`（驱动 42.7.8）的排障固化到文档：澄清该错被 Spring 包装成"语法错"实为结果集类型转换失败；给出 RCA（库列 timestamptz + 实体 LocalDateTime + PG JDBC 42.x 对 timestamptz 调 `getLocalDateTime()` 直接抛错，与兼容模式无关）、全量定位 timestamptz 列的 SQL、现场已执行的临时处置 `ALTER COLUMN create_time TYPE timestamp without time zone USING create_time::timestamp` 及其三类风险（时区语义丢失、仅改单列未覆盖 `update_time`/其它表导致复发、`ALTER TYPE` 整表重写持 ACCESS EXCLUSIVE 锁）、以及根因级方案（应用侧改 `OffsetDateTime`/`Instant` 或自定义 TypeHandler 为首选，库侧统一无时区为次选）。同步纠正配套报告的两处问题：把"改 `timestamp without time zone`"误列为无效方案与现场实际处置自相矛盾（实为有效但有时区代价）、以及报告所述"Invalid username/password / set role denied / Flyway 认证异常"在本次容器日志中并未出现，应另案排查。 |
| v1.36 | 2026-06-22 | **新增 §19.4 将 `/vastbase` 迁移到 LVM 逻辑卷（系统盘容量不足、`/` 非 LVM 无法直接扩容、新加大容量裸盘场景）。** 现场背景：`vbdb01` 程序与数据均在 `/vastbase`，落在系统盘 `/dev/vda2`（98G、已用 88%、`/` 为 ext4 非 LVM 不能直接扩），新加 `/dev/vdc` 410G 裸盘。将一次目录迁移方案固化到文档，采用「**先挂临时点 → `rsync -aAXH --numeric-ids` 整目录复制 → `du`+`find diff` 校验一致 → 卸临时点、源 `mv` 改名保留 → 建正式空挂载点 → UUID 写 fstab 并 `mount /vastbase` → 挂载后 `chown vastbase:dbgrp`+`chmod 750`+`restorecon` → 起库验收 → 稳定后 `rm -rf` 旧目录**」全程源不动、可回退的流程。要点：**(1)** 挂载路径保持 `/vastbase` 不变，使 systemd unit、`app -> app_29407` 软链、`pg_tblspc/<oid>` 表空间软链、`postgresql.conf` 内 `archive_command`/`log_directory` 等绝对路径全部无需改动。**(2)** §19.4.2 针对本文 `vastbase.service`（`Type=forking`+`Restart=on-failure`，且 `ExecStart` 的 `vb_ctl` 二进制就在被迁移卷上）的反拉风险，停库统一用 `systemctl stop`（主动停不触发 Restart）+ 迁移窗口 `systemctl mask` 兜底，验收后 `unmask`/`start`，复用修订记录 v1.22/v1.25 现场教训，禁止用 `vb_ctl stop` 绕过 systemd。**(3)** 显式纠正常见错误写法：手动 `mount` 不写 fstab（重启丢挂载）、挂载前 `chown`（被新卷根目录覆盖）、`mv ./*` 跨文件系统迁移（漏隐藏文件且中断即两边俱损）。**(4)** §19.4.1 增库外表空间排查（`pg_tablespace_location()`），明确 `/vastbase` 之外的表空间不在本流程内、须另案处理；库内 `pg_location` 相对表空间随迁。**(5)** §19.4.6 给出迁移后 `vgextend/pvresize + lvextend + resize2fs`（XFS 用 `xfs_growfs`）在线扩容流程——即本次迁移要解决的核心诉求。**(6)** `mkfs.ext4 -m 1` 降保留块、`noatime`、LVM 快照边界、ext4/XFS 选择与多卷拆分等可选优化与边界说明。本节按 §19.1 通用变更流程与 §1 `rm -rf`/停库红线执行（审批、备份、测试演练、留存证据、附回退方案）。 |
| v1.37 | 2026-06-23 | **完善 §10 备份策略，补齐“裸机/异机可恢复性”与“rsync 两端可用性”两处生产隐患。** 现场背景：(1) 备份脚本只导出业务库的库内对象（`vb_dump -F c` 单库）与全局对象（`vb_dumpall -g`，仅角色/表空间），**两者都不含 `CREATE DATABASE`**，在刚装好的 VastBase 上无法直接重建业务库后恢复；(2) 异地同步报 `bash: rsync: command not found` + `rsync error ... code 12 [sender=3.1.3]`，本机 `which rsync` 却正常——断点在远端（远端未装或非交互式 SSH 的 PATH 不含 rsync）。改法：**(1)** §10.4 逐库备份循环新增生成 `*.create.sql`，抓取该库属主/编码/排序规则/`LC_CTYPE`/表空间/连接数上限与库级 `ALTER DATABASE ... SET`（如 `search_path`，单库 custom dump 不含）并附 `sha256`；本版 `CREATE DATABASE` 不接受 `DBCOMPATIBILITY`（见 §8.2），DDL 不写该选项，仅注释记录期望模式并强调“裸机恢复前目标实例须先 initdb 为 B/MySQL 模式由 template0 继承”；manifest 增加 `create_file` 字段。§10.1 目录约定与设计要点、§11.4 同步补充基于 `*.create.sql` 的裸机恢复手工序列（先 globals 建角色/表空间 → 执行 create.sql 建库 → `vb_restore` 灌数据）。**(2)** §10.3.1 `backup.env` 新增 `REMOTE_RSYNC_PATH`（默认 `/usr/bin/rsync`），§10.4 主同步命令与 §10.7 示例均加 `--rsync-path="${REMOTE_RSYNC_PATH:-rsync}"` 显式指定远端绝对路径，规避非交互式 PATH 不确定性；§10.2.3、§10.4 补充“rsync 两端都要装”、用 `ssh -o BatchMode=yes <远端> 'command -v rsync'` 非交互式验证的方法，并澄清与 `env -u LD_LIBRARY_PATH`（OpenSSL 加载问题）属两类不同故障；§10.7 加固清单新增第 7、8 条。 |
| v1.38 | 2026-06-23 | **§10.4 备份脚本新增"业务库自动发现 + `databases.list` 漂移回填"，解决上线后新建库未及时登记导致的漏备。** 背景：业务方上线后可能再建新库，`databases.list` 人工维护易滞后。改法：无参数全量备份时（指定子集 `./db_backup.sh <db...>` 不触发），在确认主库后查询实例中"可连接的非模板库"（排除 `template0/template1`），与清单比对，将缺失库**追加**进 `databases.list` 并纳入当次备份。关键安全设计：**(1)** 被**显式注释**掉的库名（如 `# cat`、`# postgres`）识别为人工排除，不会被加回——尊重运维主动屏蔽意图；整行删除的库才会被重新发现回填。**(2)** 演练/压测/临时库（`*_check`/`*_drill`/`*_verify`/`*_restore`/`*_tmp`/`benchdb` 等）默认按 `AUTO_DISCOVER_EXCLUDE_REGEX` 跳过，避免把异名恢复库、`backup_verify` 深度校验库、sysbench 压测库误纳入；显式置空可关闭正则排除。**(3)** 库名过不了 `valid_ident`（需引号/特殊字符）的只在日志与 FYI 邮件告警、不自动加、不静默漏备。**(4)** 仅追加不重写，保留原注释与排序；在主库确认与全局 `flock` 内进行，无并发写冲突。**(5)** 新增开关 `AUTO_DISCOVER_DBS`（默认 1，设 0 回到纯手工清单模式）、`ALERT_ON_DRIFT`（默认 1，备份成功但检出漂移时发 `[VastBase Backup DRIFT]` FYI 邮件，不改退出码），均落入 `backup.env`。同步更新 §10.3.2 清单说明（排除请用注释而非删除）、§10.4 加固清单与汇总段漂移提示。 | 现场背景：(1) 备份脚本只导出业务库的库内对象（`vb_dump -F c` 单库）与全局对象（`vb_dumpall -g`，仅角色/表空间），**两者都不含 `CREATE DATABASE`**，在刚装好的 VastBase 上无法直接重建业务库后恢复；(2) 异地同步报 `bash: rsync: command not found` + `rsync error ... code 12 [sender=3.1.3]`，本机 `which rsync` 却正常——断点在远端（远端未装或非交互式 SSH 的 PATH 不含 rsync）。改法：**(1)** §10.4 逐库备份循环新增生成 `*.create.sql`，抓取该库属主/编码/排序规则/`LC_CTYPE`/表空间/连接数上限与库级 `ALTER DATABASE ... SET`（如 `search_path`，单库 custom dump 不含）并附 `sha256`；本版 `CREATE DATABASE` 不接受 `DBCOMPATIBILITY`（见 §8.2），DDL 不写该选项，仅注释记录期望模式并强调"裸机恢复前目标实例须先 initdb 为 B/MySQL 模式由 template0 继承"；manifest 增加 `create_file` 字段。§10.1 目录约定与设计要点、§11.4 同步补充基于 `*.create.sql` 的裸机恢复手工序列（先 globals 建角色/表空间 → 执行 create.sql 建库 → `vb_restore` 灌数据）。**(2)** §10.3.1 `backup.env` 新增 `REMOTE_RSYNC_PATH`（默认 `/usr/bin/rsync`），§10.4 主同步命令与 §10.7 示例均加 `--rsync-path="${REMOTE_RSYNC_PATH:-rsync}"` 显式指定远端绝对路径，规避非交互式 PATH 不确定性；§10.2.3、§10.4 补充"rsync 两端都要装"、用 `ssh -o BatchMode=yes <远端> 'command -v rsync'` 非交互式验证的方法，并澄清与 `env -u LD_LIBRARY_PATH`（OpenSSL 加载问题）属两类不同故障；§10.7 加固清单新增第 7、8 条。 | 现场背景：`vbdb01` 程序与数据均在 `/vastbase`，落在系统盘 `/dev/vda2`（98G、已用 88%、`/` 为 ext4 非 LVM 不能直接扩），新加 `/dev/vdc` 410G 裸盘。将一次目录迁移方案固化到文档，采用「**先挂临时点 → `rsync -aAXH --numeric-ids` 整目录复制 → `du`+`find diff` 校验一致 → 卸临时点、源 `mv` 改名保留 → 建正式空挂载点 → UUID 写 fstab 并 `mount /vastbase` → 挂载后 `chown vastbase:dbgrp`+`chmod 750`+`restorecon` → 起库验收 → 稳定后 `rm -rf` 旧目录**」全程源不动、可回退的流程。要点：**(1)** 挂载路径保持 `/vastbase` 不变，使 systemd unit、`app -> app_29407` 软链、`pg_tblspc/<oid>` 表空间软链、`postgresql.conf` 内 `archive_command`/`log_directory` 等绝对路径全部无需改动。**(2)** §19.4.2 针对本文 `vastbase.service`（`Type=forking`+`Restart=on-failure`，且 `ExecStart` 的 `vb_ctl` 二进制就在被迁移卷上）的反拉风险，停库统一用 `systemctl stop`（主动停不触发 Restart）+ 迁移窗口 `systemctl mask` 兜底，验收后 `unmask`/`start`，复用修订记录 v1.22/v1.25 现场教训，禁止用 `vb_ctl stop` 绕过 systemd。**(3)** 显式纠正常见错误写法：手动 `mount` 不写 fstab（重启丢挂载）、挂载前 `chown`（被新卷根目录覆盖）、`mv ./*` 跨文件系统迁移（漏隐藏文件且中断即两边俱损）。**(4)** §19.4.1 增库外表空间排查（`pg_tablespace_location()`），明确 `/vastbase` 之外的表空间不在本流程内、须另案处理；库内 `pg_location` 相对表空间随迁。**(5)** §19.4.6 给出迁移后 `vgextend/pvresize + lvextend + resize2fs`（XFS 用 `xfs_growfs`）在线扩容流程——即本次迁移要解决的核心诉求。**(6)** `mkfs.ext4 -m 1` 降保留块、`noatime`、LVM 快照边界、ext4/XFS 选择与多卷拆分等可选优化与边界说明。本节按 §19.1 通用变更流程与 §1 `rm -rf`/停库红线执行（审批、备份、测试演练、留存证据、附回退方案）。 |
| v1.39 | 2026-06-23 | **新增 §11.4.1"角色与口令的存放、备份覆盖范围与跨机恢复处置"，依据现场实际 `globals_*.sql` 把口令/角色相关事实固化进文档。** 起因：运维询问 vbadmin 口令存在哪个库/表、备份还原是否改口令。据现场 `globals_*.sql` 实测：**(1)** 角色口令是实例级全局对象，存于共享系统表 `pg_authid.rolpassword`（`$PGDATA/global/`，所有库共享），不在任何业务库/`postgres`/`vastbase` 库；备份产物中逐库 `*.dump` 与 `*.create.sql` 均不含口令，仅 `globals_*.sql`（`vb_dumpall -g`）承载。**(2)** 本版 globals 中每个角色以 `CREATE ROLE ... PASSWORD 'sha256...'` + 不带口令的 `ALTER ROLE ... WITH <属性>` 导出，口令以 hash 形式跨机可移植。**(3)** 关键缺口：`vbadmin` 被多处用作表空间/数据库 OWNER 却**不在 globals 中**（与 OS 同名的引导超级用户 `vastbase` 在），故 vbadmin 口令不在备份里，且裸机恢复 globals 时 `CREATE TABLESPACE ... OWNER vbadmin` 会因 owner 缺失失败。处置：明确"同实例库级恢复（`db_restore.sh`）不动任何角色/口令"；跨机恢复按格式分解（目标不存在的角色按源端口令建出、已存在角色 `CREATE` 报已存在不覆盖口令但 `ALTER ROLE ... WITH` 会重置属性/权限、未导出的管理账户须先手工建）；给出"先建缺口管理账户→恢复 globals→执行 create.sql→灌数据→更新 .pgpass"的正确顺序与 `comm` 自查命令。同步补充安全提示：现场多数业务角色带 `SUPERUSER/SYSADMIN`（与 §16.1 最小权限相悖，建议收敛）、`globals_*.sql` 含口令 hash 须 600+加密、`tbs_reservation` 的 `RELATIVE LOCATION 'tbs_preservation'` 命名与落盘目录差一字母的提示；§10.2.2 `.pgpass` 处补 vbadmin 口令为实例级属性、不随备份导出的交叉引用。本次仅新增说明性内容，未改动任何脚本逻辑。 |
| v1.40 | 2026-06-23 | **按现场 `pg_authid` 实测结果修正/细化 §11.4.1 的角色导出规律与跨机恢复指引。** v1.39 据 globals 文件推断"管理账户 vbadmin 不在 globals"，现以实例 `pg_authid` 全量角色清单（含 OID）确认更精确的规律：`vb_dumpall -g` **只导出引导超级用户 `vastbase`（oid=10）+ 用户自建角色（oid≥16384）**；`initdb` 阶段创建的初始系统/管理账户（`oid<16384`，本现场为 `vbadmin`(33)/`vbaudit`(34)/`vbsso`(35)/`vb_read_all_settings`(37)，即三权分立的系统/审计/安全管理员）及内置 `gs_role_*`(1044–1059)**一律不导出**（视作各实例 initdb 时自行重建的初始账户）。据此修正三点：**(1)** "缺口账户"不止 `vbadmin`，`vbaudit`/`vbsso` 同样缺席，只是 `comm` 自查仅能抓到被用作 OWNER 的 `vbadmin`；**(2)** 跨机 DR 顺序由"手工建 vbadmin"修正为"先核对目标实例（相同安装/三权分立配置）initdb 时已自动重建这些初始账户、知道/设定其目标机口令并更新 `.pgpass`，仅在确实缺失时才手工补建"；§11.4 步骤 0 注释同步更新。**(3)** 安全提示据 `rolsuper` 列给出确切的超级用户业务角色清单（authx_service/cas_server/message/transaction_service/formflow/fileupload/powerjob/jobs_server/reservation/question_feedback/ai_helper/cat），并新增"近名角色 `ai_helper`(超级)/`aihelper`(仅 SYSADMIN) 并存、疑冗余需核实"的提示。补充自查命令的现场实测结果锚点。仅说明性修订，未改动脚本逻辑。 |
| v1.41 | 2026-06-29 | **修复裸机/异机"库级还原"三处脚本缺陷 + create.sql 生成 search_path 的引号 bug，并把 §11.4 恢复序列改为可直接全量执行的循环。** 现场背景：按 v1.40 流程在新机做库级还原，依次踩到三个坑。**(1) 建库只建出一个库。** §11.4 旧写法 `vb_sql postgres -f "${DAY}/"*.create.sql` 用通配喂 `-f`，而 vsql 的 `-f` 只接受**一个**文件参数——通配展开成 N 个文件后只执行字母序第一个（`admin_center`），其余被报 `extra command-line argument ... ignored` 丢弃。改为 `for f in *.create.sql; do vb_sql -f "$f"; done` 循环逐文件执行，并保留逐文件 `sha256 -c` 校验、system 库报已存在视为良性。**(2) 灌数据循环化 + 防重灌。** 把单库示例 `vb_restore_db "$db" ... "${DAY}/${db}_"*.dump` 改为遍历 `*.dump` 的循环；库名用 `${base%_*_*.dump}` 反推（不能按 `_` 切分，`ai_helper`/`authx_service` 等库名含下划线），跳过 `postgres/vastbase/template*`，带失败计数；并强调必须灌**空库**——`vb_restore` 默认不 drop 已存在对象，往已有数据库重复灌会刷满 `already exists/duplicate key/multiple primary keys`（非致命、仍报 successful，纯属重复执行噪声）。**(3) ★根因：create.sql 的 search_path 被写坏导致"表像没还原"。** §10.4 生成库级 `ALTER DATABASE ... SET` 时，对 `search_path` 这类**列表型 GUC** 误用 `quote_literal()` 把整串逗号值包成一个字符串，生成 `SET search_path = 'ai_helper, public'`；落库时带逗号的引号串被当作**一个**名为 `ai_helper, public` 的 schema（逗号被引号保护、不再拆分），该 schema 不存在 → 恢复后 search_path 指向空 → `\dt`／不带 schema 前缀的查询都看不到表（表其实已灌入对应 schema、数据完好），极易误判为"未还原"。本现场命中 `ai_helper`/`aihelper`/`formflow`/`reservation`（带逗号的多 schema），而 `fileupload`/`powerjob`（单 schema 无逗号）不受影响。修复：列表型 GUC 按逗号拆开、每段 `quote_ident` 后输出**裸标识符列表** `SET search_path = ai_helper, public`，其余标量 GUC 仍用 `quote_literal`。**即时处置（无需重灌）**：对受影响库执行 `ALTER DATABASE <db> SET search_path = <schema>, public;` 后**断开重连**即恢复可见；验证数据在不在用 schema 全限定名 `SELECT count(*) FROM <db>.<表>;`。同步澄清：`SET ... TO` 与 `SET ... =` **完全等价、不是病因**，病因仅是单引号包列表。配套改动：§11.4 恢复序列新增 c) "校正/核对 search_path"与 d) 整体校验循环；§11.4 全实例 db_restore.sh 恢复改为按 `databases.list` 循环（去注释/空行）；全文 `SET search_path TO ...` 统一规范为 `SET search_path = ...` 裸标识符列表形式（仅风格统一，原文本就是正确的裸列表）。**本次仅改恢复侧脚本与文档，不影响备份产物布局；旧坏备份的 create.sql 仍需按上法手工改 search_path 或用本版脚本重做备份。另新增 §11.6「清理重置」runbook（演练/重恢复前清场目标实例：方案一只删业务库、方案二库+表空间+角色全清，配 KEEP 名单与 DROP 安全闸，初始账户 oid<16384 自动豁免）。** |
| v1.42 | 2026-06-30 | **修复 sidecar/SHA256SUMS 校验文件写死绝对路径、跨机/改名后 `sha256sum -c` 必失败的问题，并使还原侧校验对历史坏备份向后兼容。** 现场背景：把 06-30 备份拷到新机（不在 `/vastbase/backup` 下）做还原，`sha256sum -c *.create.sql.sha256` 报 `/vastbase/backup/2026-06-30.running.2026-06-30_011001/...: No such file or directory / FAILED open or read`。**根因**：§10.4 在临时运行目录 `$RUN_DIR=${BACKUP_DIR}/${DATE}.running.${TS}` 内用 `sha256sum "$CREATE_SQL"`（绝对路径）生成 sidecar，会把 `.running.<ts>` 绝对路径写进校验文件第二列；备份末尾 `mv "$RUN_DIR" "$DAY_DIR"` 改名后该路径在**任何机器/目录都不存在**——即 sidecar 用 `-c` 校验从生成起就是坏的，与文件放哪无关（原生产机最终目录里同样失败）。`globals_*.sql.sha256` 同理；`*.dump` 无独立 sidecar、哈希在 `*.manifest` 的 `SHA256=` 字段、不受影响。**修复（三处脚本）**：① §10.4 create.sql sidecar 改为 `( cd "$RUN_DIR" && sha256sum "${DB}_${TS}.create.sql" > "${DB}_${TS}.create.sql.sha256" )`，只写 basename；② §10.4 globals sidecar 同法 basename 化；③ §10.7 物理基础备份 `SHA256SUMS` 由 `find "$BASE_DIR" -type f -exec sha256sum {}` 改为 `( cd "$BASE_DIR" && find . -type f ! -name SHA256SUMS -exec sha256sum {} \; > SHA256SUMS )`，相对路径 + 排除自身，搬走后 `cd <dir> && sha256sum -c SHA256SUMS` 仍可用。**还原侧（§11.4）**：建库循环里的 `sha256sum -c "${f}.sha256"` 改为**直接比对哈希**（`want=$(awk '{print $1}' "${f}.sha256")` 对 `got=$(sha256sum "$f"|awk '{print $1}')`），忽略 sidecar 内路径——对**旧坏 sidecar 与 v1.42 修复后的 basename sidecar 都适用**，历史备份无需重做即可在新机校验还原。新机临时校验（不改脚本）可用：方案 A 逐文件比对哈希；方案 B `sed 's#[ *].*/#  #' file.sha256 | sha256sum -c -` 剥路径后再 `-c`；dump 用 manifest 的 `SHA256=` 比对。仅改备份生成与还原校验，**不改备份产物布局，dump/manifest 不受影响**。 |
| v1.43 | 2026-06-30 | **修正 §11.4 c) search_path 自检的误报，并消除 `!!` 在交互粘贴时被历史展开的坑。** 现场背景：用 v1.42 修复版备份在新机裸机恢复后跑 §11.4 c) 自检，admin_center/authx_service/cas_server/cat/jobs_server/message/platform_openapi/question_feedback/transaction_service 一片 `可疑 search_path` 告警。**实为误报**：这些库未设过库级 search_path，`SHOW` 回显的是**默认值** `"$user",public`——引号套在 `$user` 占位符上、逗号在引号外，是正常两段式列表；权威查询 `pg_db_role_setting` 同时确认所有自定义 search_path 均为正确裸列表（`ai_helper, public` 等），**本次恢复完全正确、无需改任何库**。根因是旧告警判据 `case "$sp" in *\"*)`（出现任何双引号即告警）把默认值里 `"$user"` 的引号也命中了。**修复**：判据改为 `*\"*,*\"*`——仅当"引号→…→逗号→…→引号"同段出现（即整串被一对引号包住、逗号落在引号内的坏形态 `"ai_helper, public"`）才告警；已验证默认 `"$user",public`、裸列表 `ai_helper, public`、`app, public`、`fileupload` 等均不再误报，坏形态仍能命中。**另**：告警前缀 `!!` 改为 `WARN:`——`!!` 在交互式 bash 粘贴执行时会触发历史展开、被替换成上一条命令（现场实测打印成 `done`）；脚本文件/非交互执行无此问题，但文档供手工粘贴故规避。`case` 拆成多行以便阅读。仅改自检告警逻辑，不影响建库/灌数/恢复结果，§11.6.4 的 `pg_db_role_setting` 权威查询本就正确、不变。 |
| v1.44 | 2026-06-30 | **新增灌数日志落盘、生产/恢复逐库表数比对（含整库漏备检测），定位并修复 `dog` 库被静默漏备的清单陷阱，补全 §11.6.3 `pg_location` 孤儿目录清理。** ① **§11.4 b) 灌数日志落盘**：`vb_restore -v` 输出极多、屏幕一闪而过，改为每库重输出 `>>"$RESTORE_LOG" 2>&1` 落盘到 `/vastbase/backup/restore_<ts>.log`，屏幕只留每库 OK/FAIL 摘要，并附事后 `grep -nE "ERROR|could not|duplicate key|already exists|FAIL"` 筛错与 `grep -c "restore operation successful"` 计数。② **§11.4 d/e/f 逐库表数比对**：把恢复侧 d) 与生产侧 e) 的逐库 `pg_stat_user_tables` 计数各自落盘，f) 用 `comm`/`join` 比对，**同时暴露"整库漏备/漏恢复"与"表数不一致"**。③ **★ dog 库漏备根因**：现场比对查出生产有 `dog`（5 表）但备份集无 `dog_*.dump`——`dog` 角色与 `tbs_dog` 都在 globals、唯独整库未备份。根因在 §10.3.2：`databases.list` 把 `dog` 当排除示例写成 `# dog`，自动发现视"注释=人工排除、永不回填"，真业务库遂被静默漏备。修复：示例清单不再用真库名（`cat`/`dog`/`fox`）作排除示例，改用 `legacy_*` 占位名，并把 `cat`/`dog` 列为激活业务库；新增醒目告警"真业务库切勿留注释"，并将 d/e/f 表数比对定为恢复/演练验收必做项（search_path 自检、单库灌数日志都发现不了整库缺失）。④ **§11.6.3 清理收尾**：方案二 `DROP TABLESPACE` 后 `$PGDATA/pg_location/<location>` 常残留空壳孤儿目录，可能导致下次 `CREATE TABLESPACE` 报 `directory already in use`；补"两步确认（catalog 已无业务表空间 + 逐目录查空）→ `cd $PGLOC && rm -rf ./tbs_*`"的红线收尾步骤，并提示 location 名按 LOCATION 串走（如 reservation→`tbs_preservation`）。仅增补恢复/清理/校验侧，不改备份产物布局。 |
| v1.45 | 2026-07-08 | **修复 §11.6.3 "pg_location 孤儿目录清理"在保留 `appdb` 的目标机上会误删在用表空间目录的缺陷：清理改为 catalog 驱动的豁免名单，废止 `rm -rf ./tbs_*` 裸通配。** 现场背景：目标机按 §11.6.1 KEEP 名单保留自有的 `appdb` 系列库，其数据/索引落在表空间 `tbs_app_data`/`tbs_app_idx`——两者的 location 目录与 16 个孤儿 `tbs_*` 目录**同层混在 `$PGDATA/pg_location` 下**（现场 `ls` 共 18 个 `tbs_*`），且 `\db` 仍显示这两个表空间。v1.44 的清理收尾在该场景有两处致命冲突：**(1)** 前置检查写死"`\db` 只应剩 `pg_default`/`pg_global`"，保留 appdb 时永不成立，照文执行者要么卡死、要么误以为第 2 步没删干净反复重试；**(2)** 检查循环 `for d in tbs_*` 与删除命令 `rm -rf ./tbs_*` 均按裸通配扫全目录，会把**在用**的 `tbs_app_data`/`tbs_app_idx` 一并端掉——删的是 appdb 的活数据文件，实例立刻损坏且无 catalog 层保险（文件系统 rm 不经过 DROP TABLESPACE 的非空检查）。**修复**：① 清理第 0 步先向 catalog 要权威豁免名单——`SELECT pg_tablespace_location(oid) FROM pg_tablespace WHERE spcname NOT IN ('pg_default','pg_global')` 取 basename 得"仍在用的 location 目录"（该函数在本文 §19.4.1/§12 已现场验证可用）；查询失败（实例没起来等）立即停手——**拿不到名单绝不删**，故本步要求实例运行中；② 检查与删除两个循环都先比对豁免名单，在用目录只报 "在用（catalog 有主），跳过"；③ 删除改为**逐目录显式 `rm -rf "./$d"`**，且仅当 `find "$d" -mindepth 1 ! -type d | wc -l` 为 0（目录内无任何文件/链接）才删，有残留文件一律 SKIP 并 WARN；④ 前置 `\db` 检查改述为"剩下的表空间应全部属于 KEEP_DB 自有库"；⑤ §11.6.1 KEEP 名单表空间列与 §11.6.3 第 2 步 `KEEP_TBS` 补上 `tbs_app_data`/`tbs_app_idx`，与 KEEP_DB 对齐（`DROP TABLESPACE` 对非空表空间会报 `tablespace ... is not empty` 拒绝，属内置保险，但名单写全可免报错噪声与误判；若把 appdb 移出 KEEP_DB，这两个表空间也应同步移出 KEEP_TBS）。仅改清理侧脚本与说明，不影响备份/恢复产物。 |
| v1.46 | 2026-07-08 | **§19.4 `/vastbase`→LVM 迁移流程按 vbdb01 现场首执结果修订闭环，新增 §19.4.8 现场执行记录、§14.9 虚拟化平台周期性时钟回拨现场案例，§2.3/§18.2 时钟同步与巡检加固。** 现场背景：按 §19.4 完成 vbdb01 `/vastbase`（18G、46817 条目）→ `/dev/vdc` 410G LVM（vgdata/lvvastbase，ext4 -m 1）迁移：rsync 复制 + `find` diff 零差异、UUID 写 fstab、起库验收、迁移前后 16 业务库逐库表计数完全一致、受控重启验证开机自动挂载 + 实例自启 + pg_log `database system was shut down` 干净关闭、迁移后手动全量备份（16 库 + globals + 异地 rsync）全绿——**迁移成功**。执行中暴露并修复：**(1) `su - vastbase -c "$VB_SQL ..."` 双引号外层展开缺陷（§19.4.1 第 5 步与 §19.4.5 验收段）**——root 未 source backup.env 时 `$VB_SQL` 为空、命令退化为 `-bash: -d: command not found`；为补救在 root 交互 shell source 后，`LD_LIBRARY_PATH=$GAUSSHOME/lib` 污染 root 环境（root 执行 su 时 ruid==euid、非 secure-execution、动态链接器尊重 LD_LIBRARY_PATH），su 经 PAM dlopen 模块时依赖库被 VastBase 自带 libssl/libcrypto 顶替，实测报 `su: cannot open session: Module is unknown`（与 §10.3.1 ssh/rsync `OPENSSL_1_1_1f not found` 同源污染）。改法：两处均改 `su - vastbase <<'EOF'` heredoc、在 vastbase 会话内 source 后用 `vb_sql` 封装执行，新增「严禁在 root 交互 shell source backup.env」红线与执行身份说明。**(2)** §19.4.4 fstab 写入后补 `systemctl daemon-reload` + `findmnt --verify` + `systemctl status vastbase.mount` 核验（fstab 头注释本就要求 reload；不做则 systemd 视图无该 mount 单元）。**(3)** §19.4.5 验收升级：新增迁移前（§19.4.1 第 7 步）/后逐库 `pg_stat_user_tables` 计数快照 diff 比对（文件名带 pre/post + 时分秒防同日覆盖）；`rm -rf /vastbase_old` 前必须手动跑一次完整备份验证新卷上备份链路（同时满足 §1 红线）；推荐窗口内受控重启验证 fstab 持久性、以数据目录内 pg_log（非易失 journal）`was shut down` 判定干净启停；归档复核改「archive_mode=off 记不适用并把无 PITR/RPO=逻辑备份间隔列为风险项」；手工改名的备份目录（如 `<date>.old`）不匹配保留期清理 glob、须与 `/vastbase_old` 一并手动回收。**(4)** §19.4.8 现场执行记录：`wipefs -n` root 下无输出即无签名、vastbase 用户 Permission denied 属预期；`du -sx` 两侧差 1572KB（0.008%）为新旧 ext4 目录块分配差异、`find` diff 一致即一致；SELinux Disabled 时 restorecon 条件跳过；vb_ctl `Failed to obtain environment ... $GAUSSLOG` 为 systemd 不读 profile 的既有噪音（可选 unit drop-in `Environment=GAUSSLOG=` 消音）；偏差项如实记录——§19.4.2 mask 安全闸本次被跳过、未造成后果但下次必须照做；`tbs_reservation` location 为 `tbs_preservation`（历史笔误）记台账、严禁 rename 目录。**(5) §14.9 新增**：迁移日备份日志「时间倒流」~50 秒（15:02:34 下一行 15:01:45）为入口，`chronyc tracking` RMS offset 36.79s 证实近期大跳变但当前值健康、journal 无肇事记录→定位到 pitrix guest-agent 直接设钟不走 syslog；横向取证 nginx01（每 30 分钟一轮 Backward time jump→~2 分钟后 step ~50s，全天 119 次）、harbor（唯一内网 NTP 源、上游 ntp1.aliyun.com，自身同样被锯 120 次；客户端 :22/:52 `no selectable sources` 正是 harbor 被拽偏的相位，两侧日志相位互锁）；宿主机时钟无 NTP 约束自由漂移 ~16.4ppm（47.11s→50.63s/59.7h，vbdb01 独立测算 ~17ppm 一致）、nginx01 与 vbdb01 同时刻偏差小数点后四位一致证明集群级同一坏钟、按漂移率回推归零点约 6 月初（平台上线以来即如此）。处置按根到梢：①平台工单修宿主机 NTP（勿逐台关 agent 时间同步）；②锯齿消失后各机 `makestep 1.0 -1`→`makestep 1.0 3`（顺序不可颠倒，锯齿未除先收 makestep 会令 chronyd 长期 slew 追 50s 坑）；③NTP 拓扑 ≥3 源、内网勿单指 harbor；④数据库主机开 journald 持久化。影响面：PITR 时间语义、cron 重复/漏触发、CAS/SSO ticket 与 JWT 秒级窗口、K8s/etcd、日志取证。**(6)** §2.3 加固（≥3 源、makestep 1.0 3、虚拟化「单一时间权威」红线），§18.2 新增时钟健康巡检（RMS offset 毫秒级、运行期 `was stepped` 计数为 0）。 |
| v1.48 | 2026-07-09 | **新增 §19.4.10「变体：Harbor 主机（/data + /var/lib/docker）与 K8s 工作节点（/var/lib/docker）迁移到 LVM」（A 部分 harbor 与 B 部分首台 worker01 当日实执行闭环）+ ★迁移证据快照路径事故修正（含 §19.4.9 同款隐患）**：§19.4.10 复用 §19.4 骨架完成 harbor 主机（/data 21G/17444 条目 + /var/lib/docker 7.7G/192506 条目 → vgdata：lvharbordata 300G + lvdocker 100G，VFree <50G）与首台工作节点 k8s-worker01（/var/lib/docker 18G/296714 条目 → vgdata/lvdocker 150G，VG 留 ~50G）双场景迁移——挂载路径不变、harbor.yml/daemon.json/compose/RKE 容器定义零改动；切换前 find diff 全部零差异；受控重启验证 fstab 持久 + docker/harbor.service 开机自启链路；harbor 验收 login/pull/push + Rancher 侧拉取 + 外部 harbor 复制全过、docker info 指纹一致（Images 39，验收 pull 后 40 差值可解释）；worker01 验收 Images 71 指纹一致 + kubelet/kube-proxy 随 docker 自起 + uncordon 后调度即回流 + 全集群无非 Running/Completed pod。**与 §19.4/§19.4.9 三处本质差异固化为流程**：①停写入方的反拉来源须现场核实——现场实证 `docker-compose stop` 被 `harbor.service`（Restart=on-failure、前台 compose up）整栈反拉（stop 全 done 后十容器复活 "Up About a minute"，与 §19.4.2 禁 vb_ctl stop 同构），停栈固化为 `systemctl stop harbor`；docker 一律 stop + mask（Kylin docker 20.10 包无 docker.socket/containerd 独立单元，"not loaded" 属预期）；②核心风险 = overlay2 `trusted.overlay.*` xattr 与残留 overlay/shm 挂载——rsync 必须 root + `-aAXH --numeric-ids`，`findmnt -R /var/lib/docker` 清零为硬闸；③harbor 窗口与工作节点窗口严禁重叠（drain 依赖 harbor 在线拉镜像）、节点逐台滚动。**★事故修正：迁移前后证据快照一律写持久目录 /root/migrate_evidence**——harbor 首执写 /tmp，Kylin V10 /tmp 为 tmpfs、受控重启即清，pre/post 比对落空（迁移一致性结论不受影响：权威闸门为切换前新旧目录 diff 零差异；证据从 *_old 旧目录补生成）；**§19.4.9 同款隐患（快照写 /tmp、步骤 5 重启先于收尾比对）一并修正**。偏差与里程碑：harbor 侧 mask 安全闸连续第二次被跳过且窗口内真实发生反拉、lvharbordata 当场 lvextend 200G→300G 致 VFree <50G（再扩须 vgextend 加盘）、rsync 两台均未预装窗口内临时安装（前置检查已补入 A1/B1）；**worker01 侧 mask 安全闸自 §19.4.8 警告以来首次完整执行（stop→mask→迁移→unmask→reboot），主流程零偏差**。判读固化：DaemonSet pod RESTARTS +1 与 docker info Containers 计数波动属预期，跨迁移指纹只看 Images/Storage Driver/Root Dir 三项；drain 后节点仅剩三个 DaemonSet pod（cattle-node-agent/nginx-ingress-controller/calico-node）即驱逐完成；drain 的 Throttling request 为 Rancher 代理限流噪音。衍生发现：k8s-master01 内存 87% 显著高于 master02/03（62–66%），另案关注。worker02–04 待逐台滚动，全部完成观察 1–2 天后统一回收各 *_old 目录（harbor 系统盘预计回落 ~29G） |
| v1.47 | 2026-07-09 | **新增 §19.4.9「变体：NFS 导出目录迁移到 LVM（K8s PVC 后端存储）」（含 provisioner 漏缩致 ESTALE 的现场事故复盘）；§14.9 补记时钟处置进展；修正 §18.2/§14.9 时钟巡检判据。** 现场背景：nfs 主机（10.120.0.33）导出目录 `/opt/nfs/rancher` 为 K8s 集群 nfs-client-provisioner/`managed-nfs-storage` 全部 PVC 后端（13 个 PVC 目录、238M/1447 条目，含 CAS/authx/admin-platform 等 Redis AOF、Kafka、ES、MinIO、formflow 上传），原落 60G 系统盘；新加 `/dev/vdc` 450G。按 §19.4 骨架完成迁移并顺带把 vbdb01 异地备份目标 `/backup` 一并迁出系统盘：vgdata 切 lvnfs 100G + lvbackup 200G（VG 留余量，§19.4.7 多卷拆分落地实例）、rsync + `find` diff 双目录零差异、UUID 写 fstab + daemon-reload + `findmnt --verify`、受控重启验证双挂载持久 + nfs-server 自启 + 导出齐全、K8s 节点手工 mount RW-OK、按清单扩容后全 pod Running、迁移前后 find/du 快照留证；并当场实证 §19.4.6 核心诉求——`lvextend -L +100G` + `resize2fs` 将 lvnfs 100G→200G **业务在线不停服**。**与 §19.4 数据库迁移的三处本质差异**（直接照抄会出事）：①「停库」对应物是**停 K8s 侧写入方**（使用 PVC 的负载缩 0、kubelet 卸载 NFS 挂载），本机 nfs-server（Type=oneshot、无 Restart）只是通道、无反拉问题；②核心风险是 **NFS stale file handle**——句柄编码服务端 fsid+inode，换底层文件系统后旧句柄永久失效不自愈，带老挂载穿越迁移的进程必 ESTALE；③数据小、rsync 秒级，窗口由缩/扩容主导，且 CAS Redis 在列——缩容窗口=SSO 中断窗口须低峰。**现场事故（本节最重要教训）**：nfs-client-provisioner 不经 PVC、在 Deployment 里直接以 nfs 卷挂导出根（容器内 `/persistentvolumes`），「缩所有挂 PVC 的负载」覆盖不到它；17:48 ansible 核查已显示 10.120.0.41（k8s-worker02）残留一条 `nfs-client-root` 挂载，**未按住继续停服切盘**——业务 pod 因扩容时全部重建侥幸无恙，provisioner 老 pod 带失效句柄穿越迁移，次日步骤 6 动态供给验证时 PVC `default/test` 长挂 Pending，日志每轮报 `unable to create directory to provision new pv: mkdir /persistentvolumes: file exists`（failures 0→15 重试永不自愈）。**机理三步**：MkdirAll 先 Stat 新 PV 子目录→经失效根句柄返回 **ESTALE**（非「不存在」）；MkdirAll 误判为不存在、递归对 `/persistentvolumes` 本身 Stat→仍 ESTALE；遂 `Mkdir("/persistentvolumes")`→该 syscall 解析容器 overlay 根 `/`，挂载点目录已存在→**EEXIST**。处置：`kubectl -n default rollout restart deploy/nfs-client-provisioner`，新 pod 重新 mount 取新句柄，controller 对 Pending claim 的重试仍在队列、**无需动 PVC**，十几秒自动转 Bound（现场实证）。**三条教训固化为流程**：①缩容清单必须**单列 provisioner**；②「逐节点无残留挂载」是**硬闸**不是巡检项，未清零不得停服切盘；③ESTALE 指纹速查——provisioner 报 `mkdir /persistentvolumes: file exists` 或任意 pod 报 `Stale file handle`，处置一律重建持有老挂载的 pod、勿去 NFS 服务端找原因。**§14.9 处置进展补记**：07-08 ~17:00 平台侧停 agent 对时，锯齿即止（harbor 末次 step 16:57、50.723s，此后 17:23/17:53/18:23 相位均未发作）；07-09 10:19 ansible 全网 15 台 `journalctl -u chronyd --since today` 全部 No entries（~17h 零跳变），**止血确认**。但 harbor `chronyc tracking` 显示 `Frequency 15.330 ppm slow`、`Skew 0.510 ppm`——chronyd 测得底层时钟仍以 ~15.3ppm 漂移（与此前宿主机 16.4ppm 测算吻合），即**修的是 agent 而非宿主机 NTP，根治待办**：残余风险为宿主机本地时间持续漂移（日 +1.4s）与虚机冷启动从宿主机 RTC 取时、开机头几分钟时钟错待 chronyd 校正（数据库主机重启窗口不理想），工单改「止血确认、宿主机 NTP 待配置」保持打开；RMS offset 36.79s→3.5s 为旧跳变余波、数日自然归零；下一步（处置第 2/3 步窗口已到）：确认 24-48h 无新锯齿后 ansible 全网 `makestep 1.0 -1`→`makestep 1.0 3` 并重启 chronyd、NTP 源扩 ≥3。**判据修正（§18.2/§14.9）**：`grep -c 'was stepped'` 为历史累计计数（vbdb01 累计 463 次——默默锯了一个月，计数永不归零），不可作现状判据；改看 `journalctl -u chronyd --since today` 应 No entries、`grep 'was stepped' /var/log/messages \| tail -1` 的最后时间戳，并固化 ansible 全网核查两条命令。另：nfs/vbdb01 两台受控重启后 journal「Logs begin」即重启时刻，再证 §14.9 处置第 4 步 journald 持久化必要性。 |

## 使用前必读

1. 本文中的 IP、端口、库名、账号、口令均为示例，交付前必须替换为客户现场值。
2. VastBase G100 V3.0.8PSU4 交付时优先使用随包 `vb_*` 工具（如 `vb_initdb`、`vsql`、`vb_ctl`、`vb_dump`、`vb_restore`、`vb_basebackup`）；`gs_*` 仅作为历史包或 openGauss 生态命名的兼容兜底。本文统一以 `$VB_*` 变量封装实际命令，现场按 `command -v` 结果记录最终命令路径。
3. MySQL 兼容模式应在实例初始化时确认。生产实例初始化完成后，不建议、也不应在同一实例中混用不同兼容模式。
4. 文档中所有带 `DROP DATABASE`、`VACUUM FULL`、`rm -rf`、`firewall-cmd --reload` 的命令，执行前必须完成变更审批、备份与回退方案确认。
5. 如客户执行等保、密评或商用密码要求，认证方式、SSL、SM3、审计、口令复杂度和日志保留周期应以客户安全基线为准。
6. 本文所有生产脚本落地后，必须先执行 `bash -n 脚本名`、在测试库完成一次演练，再纳入 crontab 或监控平台。
7. 文中出现【V3.0.8PSU4】、【V3.0.8PSU4 增强】、【现场确认】标识时，必须把验证输出纳入交付证据；后续升级、补丁回退、换架构安装包时应重新核验。

## 目录

1. 环境规划与版本说明
2. 操作系统优化（部署前必做，含防火墙配置）
3. 数据库安装前准备
4. VastBase G100 安装与初始化
5. 数据库启停与监听配置
6. 数据库参数优化（postgresql.conf）
7. 客户端访问与认证配置（pg_hba.conf）
8. 创建数据库、表空间与用户
9. MySQL 兼容性验证
10. 备份策略（多库逻辑备份 + 异地 rsync 同步）
11. 恢复操作（含远端拉回与单库重建脚本）
12. 运维常用 SQL（跨库访问、慢 SQL、死元组、长事务等）
13. 验收检查清单
14. 附录：常见问题排查
15. 生产交付预检模板
16. 安全加固与审计建议
17. 物理备份、归档与 PITR 补充方案
18. 监控指标、告警阈值与日常巡检
19. 变更、升级与回滚流程
20. 性能压测、参数优化与压测报告（含 fio/WDR/清理 checklist）
21. 高可用、连接池与读写分离规划（范围说明）
22. 交付物清单与运维交接
23. 附录：脚本落地与语法验证清单
24. 参考资料

---

## 1. 环境规划与版本说明

### 1.1 软件版本

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| 操作系统 | Kylin V10 SP2/SP3 (AArch64 或 x86_64) | 内核 4.19+ |
| VastBase G100 | V3.0.8PSU4 / V3.0 Build 8 Patch No.4 | 兼容模式 = B（MySQL）；命令名优先使用 `vb_*`，`gs_*` 仅兜底 |
| 文件系统 | XFS（推荐）或 ext4 | XFS 对大文件/高并发更友好 |
| Python | Python 3.7+（系统自带即可） | 安装脚本、巡检脚本依赖 |
| License | 商业授权文件 | 生产必须配置正式 license，试用 license 不应用于正式投产 |

### 1.1.1 V3.0.8PSU4 定版说明与命令适用性

本文按 **VastBase G100 V3.0 Build 8 Patch No.4** 定版，现场常见介质简称为 **V3.0.8PSU4**。交付前必须以安装包、补丁说明和数据库实际输出为准，建议在验收证据中保留以下输出：

```sql
SELECT version();
SHOW server_version;
```

```bash
# 【V3.0.8PSU4】确认客户端和备份恢复工具是否为本版本随包工具
$VB_SQL --version 2>/dev/null || vsql --version 2>/dev/null || gsql --version
$VB_DUMP --help 2>/dev/null | grep -E -- '--stat-obj|--statistics|--no-statistics' || true
$VB_RESTORE --help 2>/dev/null | grep -E -- '--stat-obj|--validate-obj|--statistics' || true
```

**命令/参数标识说明：**

| 标识 | 含义 | 落地要求 |
|------|------|----------|
| 【通用】 | Linux/Kylin 或 VastBase V2/V3 常见通用命令 | 可直接使用，但仍需按现场路径、端口、账号改写。 |
| 【通用关键】 | 跨版本通用，但影响兼容模式、数据安全或恢复能力 | 必须保留验收证据，不得随意改写。 |
| 【V3.0.8PSU4】 | 针对 V3.0.8PSU4 已纳入本文定版口径的命令、参数或行为 | 以本版本安装介质为准；升级/降级后重新复核。 |
| 【V3.0.8PSU4 增强】 | V3.0.8PSU4 新增或增强的能力 | 默认不强制启用；脚本中通过可选变量打开，避免回退到旧版本时不可用。 |
| 【现场确认】 | 不同补丁、License、安装方式或安全基线可能不同 | 先执行 `SHOW`、`\df`、`--help` 或厂家手册核验，再写入生产配置。 |
| 【MySQL 兼容模式 专用】 | 仅适用于当前兼容模式 | 不得复制到其他兼容模式文档或恢复脚本。 |

**V3.0.8PSU4 需要特别写入文档的版本点：**

| 项目 | 标识 | 文档落地方式 |
|------|------|--------------|
| `vb_initdb` / `vsql` / `vb_ctl` / `vb_guc` / `vb_dump` / `vb_restore` / `vb_basebackup` | 【V3.0.8PSU4】 | 本文 `$VB_*` 变量优先探测 `vb_*`，`gs_*` 仅作历史包兼容兜底。 |
| `--dbcompatibility=B` 与 `CREATE DATABASE ... DBCOMPATIBILITY='B'` | 【通用关键】 | 初始化实例、创建业务库、恢复临时库必须保持一致。 |
| `vb_dump` / `vb_dumpall` / `vb_restore` 的 `--stat-obj`、`--validate-obj`、`--statistics`、`--no-statistics` 等选项 | 【V3.0.8PSU4 增强】 | 通过 `DUMP_EXTRA_OPTS`、`RESTORE_EXTRA_OPTS` 控制；启用前用 `--help` 确认。 |
| `generate_wdr_report(:begin_snap,:end_snap,'all','cluster',NULL)` | 【V3.0.8PSU4】 | A/B 非 PG 兼容模式不要使用 `begin_snap_id := 101` 这类命名参数写法；示例必须用变量替代固定 snapshot_id。 |
| `pg_query_audit()` / `dbe_perf.*` / `snapshot.*` 视图 | 【现场确认】 | 受审计开关、角色权限和补丁影响；先 `\df *audit*`、`\dn snapshot`、`\d dbe_perf.*` 核验。 |
| `vb_enable_comm_shm` 与 `enable_thread_pool` | 【V3.0.8PSU4 注意】 | 两者不能同时为 `on`，预检脚本需检查并阻止投产。 |
| `max_vector_indexer_query_threads` | 【V3.0.8PSU4 注意】 | 使用向量索引时不要开启并行向量查询；默认 `0` 即关闭。 |
| PL/Python `plpy` 模块 | 【V3.0.8PSU4 禁止】 | 不在生产中使用基于 `plpy` 的自定义过程语言。 |
| `lower_case_function_names` | 【V3.0.8PSU4/B 模式增强】 | 控制自定义存储过程和函数名称写入 `pg_proc` 时是否大小写敏感；仅在完成应用回归后落盘。 |
| `DATE_FORMAT` / `FROM_UNIXTIME` / `STR_TO_DATE` | 【B 模式专用】 | V3.0.8PSU4 起这三类函数仅 MySQL 兼容模式支持；A/PG 模式不要依赖。 |
| `CURRENT_TIMESTAMP` / `now()` | 【V3.0.8PSU4/B 模式注意】 | MySQL 兼容模式下返回类型按 `timestamp(0)` 处理；业务需要微秒时显式写 `CURRENT_TIMESTAMP(6)`。 |
| `behavior_compat_options` 中 `block_return_multi_results` | 【V3.0.8PSU4 可选】 | 存储过程/函数需要返回多结果集且客户端已验证时再开启。 |

> 建议把本节作为变更评审和运维交接的第一页检查项：凡是标记为【V3.0.8PSU4】或【现场确认】的命令，在升级、补丁回退、迁移到其他架构安装包时都要重新验证。

### 1.2 硬件基线（生产建议）

| 资源档位 | 适用场景 | CPU | 内存 | 数据盘 | 网络 | 参数起步口径 |
|----------|----------|-----|------|--------|------|--------------|
| 最低准入 | 功能验证、开发测试、小型非核心系统 | 4 核 | 8 GB | 200 GB，建议独立挂载 | 1 GbE | 仅用于功能验证，不建议承载正式压测结论 |
| 生产起步 | 中小型 OLTP、迁移验证、准生产压测 | 8–16 核 | 32 GB | 独立 LUN，SSD/NVMe，XFS 推荐 | 1/10 GbE | 按 §6 与 §20.3 的 32GB 列作为起步参数 |
| 推荐生产 | 常规生产 OLTP/混合负载 | 16 核+ | 64 GB | 数据/WAL/备份尽量分盘或分 LUN | 10 GbE，业务/管理双网 | 按 §20.3 的 64GB 列作为起步参数 |
| 大型业务 | 高并发、报表/批处理、长稳压测或多业务库 | 32 核+ | 128 GB+ | NVMe/企业级 SAN，需 fio 基线证明 | 10/25 GbE | 以 64GB 列为下限，按压测结果滚动调参 |

> 参数不能只按硬件档位静态套用。32GB/64GB 起步参数见 §20.3；投产最终值必须以压测报告、业务 SLA、连接池配置、fio/WDR/OS 采集证据共同定稿。
### 1.3 目录规划

| 目录 | 用途 | 建议挂载 |
|------|------|----------|
| `/vastbase/app` | 数据库二进制（$GAUSSHOME） | 系统盘或独立目录 |
| `/vastbase/data` | 数据目录（$PGDATA） | 数据盘（SSD） |
| `/vastbase/arch` | WAL 归档目录 | 独立盘或大容量盘 |
| `/vastbase/backup` | 备份目录 | 独立盘 |
| `/vastbase/log` | 运行日志 | 系统盘 |
| `/vastbase/tools` | 安装包暂存 | 系统盘 |

### 1.4 网络与端口

| 端口 | 用途 |
|------|------|
| 5432 | 数据库监听（默认，可按需调整为 26000 等） |
| 5434 | HA 复制端口（如启用主备） |

---

### 1.5 生产交付变量表（部署前填写）

| 变量 | 示例 | 现场值 |
|------|------|--------|
| 主机名 | `vbdb01` |  |
| 管理 IP | `192.168.20.11` |  |
| 业务 IP | `192.168.10.11` |  |
| 数据库端口 | `5432` |  |
| 运维网段 | `192.168.20.0/24` |  |
| 业务网段 | `192.168.10.0/24` |  |
| 备份服务器 | `192.168.100.100` |  |
| 数据盘设备 | `/dev/sdb1` |  |
| 数据目录 | `/vastbase/data` |  |
| 归档目录 | `/vastbase/arch` |  |
| 本地备份保留 | `14` 天 |  |
| 异地备份保留 | `30` 天 |  |
| RPO/RTO | `RPO≤24h / RTO≤4h` |  |

### 1.6 部署前准入条件

| 类别 | 检查项 | 命令/依据 | 通过标准 |
|------|--------|-----------|----------|
| 硬件 | CPU/内存 | `lscpu; free -h` | 满足 1.2 规划 |
| 磁盘 | 数据盘独立挂载 | `lsblk -f; df -hT` | 数据、归档、备份目录容量充足 |
| OS | 版本与架构 | `cat /etc/os-release; uname -m` | 与安装包架构一致 |
| 网络 | DNS/hosts/路由 | `ip a; ip r; getent hosts vbdb01` | 主机名可解析，业务网可达 |
| 时间 | NTP 同步 | `chronyc tracking` | 时钟已同步，偏移可接受 |
| 安全 | 防火墙策略 | 变更单/规则表 | 22/5432 仅对授权网段开放 |
| 介质 | 安装包与 license | `sha256sum`、厂家签名 | 校验通过，license 正式有效 |
| 备份 | 异地链路 | `ssh vastbase@备份服务器 hostname` | 免密或受控密钥可用 |
| 回退 | 快照/备份 | 虚拟化快照、系统盘快照或配置备份 | 可回滚 OS 与配置 |

### 1.7 实施角色、职责与交付边界

| 角色 | 主要职责 | 交付证据 |
|------|----------|----------|
| 系统工程师 | OS 安装、磁盘挂载、内核参数、防火墙、NTP、SELinux、systemd | OS 预检报告、磁盘/网络截图或命令输出 |
| DBA | VastBase 安装初始化、参数配置、用户/表空间/备份恢复/审计 | 初始化日志、参数清单、备份与恢复演练记录 |
| 应用负责人 | 提供业务库名、账号、连接池、SQL 兼容验证、停机窗口 | 应用连通性测试、核心交易回归结果 |
| 安全负责人 | 审核账号权限、口令策略、SSL/SM3、审计、日志保留、远程访问控制 | 安全基线确认单、审计查询截图 |
| 运维负责人 | 接管巡检、告警、备份介质、恢复演练、变更流程 | 交接清单、监控告警策略、应急联系人表 |

**本文交付边界**：本文覆盖单实例 L1 级部署、备份恢复、PITR、巡检、基础安全加固和运维交接。主备高可用、自动切换、读写分离、跨机房容灾属于独立 HA/DR 方案，本文仅给出规划边界和脚本衔接点。

### 1.8 投产实施顺序与回退触发条件

建议按以下顺序实施，避免“数据库已上线但备份/监控未闭环”的风险：

1. 完成 OS 预检和磁盘挂载，输出预检报告。
2. 安装 VastBase 二进制和正式 License，确认工具命名。
3. 初始化实例并设置 MySQL 兼容模式。
4. 配置监听、认证、日志、安全参数和审计。
5. 创建业务库、表空间、账号、schema 与最小授权。
6. 完成应用连通性、MySQL 兼容 SQL、核心交易回归。
7. 按第 20 章完成基准压测、业务 SQL/接口回放、参数优化复测和稳定性观察，输出压测报告。
8. 配置逻辑备份、物理备份、WAL 归档和异地同步。
9. 完成一次逻辑恢复演练和一次 PITR 演练。
10. 接入监控告警、License 到期监控、巡检报告。
11. 归档交付物，运维签收后进入试运行。

**立即回退或暂停投产的触发条件**：

| 条件 | 处理 |
|------|------|
| 预检脚本存在 FAIL 项 | 暂停安装，修复后重新预检 |
| License 为试用或无法确认有效期 | 暂停投产，换正式授权 |
| 逻辑备份或异地同步失败 | 不允许业务上线 |
| 恢复演练失败或未演练 | 不允许签署验收 |
| 未完成压测报告，或压测 P95/P99、错误率、资源水位不满足业务 SLA | 不允许投产签收，需按第 20 章完成调参复测或由业务书面接受限制条件 |
| 归档目录增长异常、`archive_status/` 下 `.ready` 持续堆积（即归档失败/滞后） | 暂停压测或上线，先修复归档链路 |
| 应用核心 SQL 在 B 兼容模式下失败 | 退回兼容性改造或参数评审 |

## 2. 操作系统优化（麒麟 V10）

> 以下操作 **全部以 root 执行**，每一步建议留有变更前的 `cp -a xxx xxx.bak.$(date +%F)` 快照。

### 2.1 防火墙与 SELinux 配置

#### 2.1.1 关闭 SELinux

VastBase / openGauss 与 SELinux 的标签机制存在兼容问题，统一关闭：

```bash
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
# 重启后生效；getenforce 应输出 Disabled
```

#### 2.1.2 启用并配置 firewalld（生产推荐，带回退保护）

> 设计目标：仅放行业务和运维必要入口，默认拒绝其他入站连接；出站默认允许，便于主动推送异地备份。  
> 生产执行原则：**先配置 runtime 规则并验证，确认 SSH 不会断开后再落盘到 permanent**。

**建议先在当前 SSH 会话外，再开一个备用 SSH 会话。** 若只有一个会话，先准备临时回退任务：

```bash
# root 执行：10 分钟后自动恢复 ssh 服务放行，验证通过后再删除该 at 任务
systemctl enable --now atd 2>/dev/null || true
echo "firewall-cmd --permanent --zone=public --add-service=ssh; firewall-cmd --reload" | at now + 10 minutes
atq
```

配置规则：

```bash
systemctl enable --now firewalld
firewall-cmd --state

# 备份当前规则，便于回滚
mkdir -p /root/firewalld_bak
cp -a /etc/firewalld /root/firewalld_bak/firewalld.$(date +%F_%H%M%S)

# 清理默认服务，仅保留按源地址精确放行的 rich rule
firewall-cmd --zone=public --remove-service=ssh --permanent 2>/dev/null || true
firewall-cmd --zone=public --remove-service=cockpit --permanent 2>/dev/null || true
firewall-cmd --zone=public --remove-service=dhcpv6-client --permanent 2>/dev/null || true

# 先配置 runtime 规则，避免直接 permanent 后误锁远程会话
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.20.0/24" port port="22" protocol="tcp" accept'
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.10.0/24" port port="5432" protocol="tcp" accept'
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.20.10/32" port port="5432" protocol="tcp" accept'
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.0.0/16" protocol value="icmp" accept'

# 不再添加“drop all”的 rich-rule，避免规则优先级理解不一致导致误拦截。
# 通过 zone target 实现默认拒绝入站。
firewall-cmd --permanent --zone=public --set-target=DROP

# 从业务网段、运维跳板机、非授权主机分别验证后，再永久保存
firewall-cmd --runtime-to-permanent
firewall-cmd --reload
firewall-cmd --get-active-zones
firewall-cmd --list-all --zone=public


#添加新的网段规则

#方式A：先 runtime 验证、再持久化"模式
# 1. 只加到 runtime，先验证
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.30.0/24" port port="5432" protocol="tcp" accept'

# 2. 从 192.168.30.0/24 内的机器实测能连 5432
# 3. 验证通过后，把 runtime 固化为 permanent
firewall-cmd --runtime-to-permanent

#方式B：直接持久化 + reload
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.30.0/24" port port="5432" protocol="tcp" accept'
firewall-cmd --reload
```

```bash
firewall-cmd --zone=public --remove-service=ssh --permanent 2>/dev/null || true
firewall-cmd --zone=public --remove-service=cockpit --permanent 2>/dev/null || true
firewall-cmd --zone=public --remove-service=dhcpv6-client --permanent 2>/dev/null || true

firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="172.18.13.0/24" port port="22" protocol="tcp" accept'


firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="172.18.13.0/24" port port="5432" protocol="tcp" accept'


firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="172.18.212.167/32" port port="22" protocol="tcp" accept'

firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="172.18.212.167/32" port port="5432" protocol="tcp" accept'

firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="172.18.0.0/16" protocol value="icmp" accept'

firewall-cmd --permanent --zone=public --set-target=DROP

firewall-cmd --runtime-to-permanent
firewall-cmd --reload
firewall-cmd --get-active-zones
firewall-cmd --list-all --zone=public
```



**异地备份服务器说明：** 当前备份脚本是本机主动通过 SSH/rsync 推送到 `192.168.100.100:22`，属于出站连接，默认无需开放本机入站端口。只有当远端采用“反向拉取”方式时，才需要额外开放本机入站 SSH。

**验证清单：**

```bash
# 本机端口监听
ss -ntlp | grep 5432

# 授权业务网段/跳板机应连通
nc -vz 192.168.10.11 5432

# 非授权 IP 应被拒绝或超时
nc -vz 192.168.10.11 5432

# 出站到异地备份服务器应连通
ssh -o BatchMode=yes vastbase@192.168.100.100 'hostname'
```

**回滚：**

```bash
# 临时回滚为默认放行 ssh
firewall-cmd --permanent --zone=public --set-target=default
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --reload

# 或恢复备份目录后 complete-reload
# cp -a /root/firewalld_bak/firewalld.YYYY-MM-DD_HHMMSS/* /etc/firewalld/
# firewall-cmd --complete-reload
```

> 切勿在生产长期 `systemctl disable firewalld`。排障临时停止后，应在变更窗口内恢复并复测。

### 2.2 主机名与 hosts

```bash
hostnamectl set-hostname vbdb01
cat >> /etc/hosts <<EOF
192.168.10.11   vbdb01
EOF
```

### 2.3 时钟同步（chrony）

```bash
yum install -y chrony
# NTP 源 ≥3（单源无 falseticker 仲裁能力，源自身漂移全网跟着漂——现场教训见 §14.9）
sed -i 's|^pool .*|server ntp1.aliyun.com iburst\nserver ntp2.aliyun.com iburst\nserver ntp.ntsc.ac.cn iburst|' /etc/chrony.conf
# 运行期禁止大步跳变：仅开机前 3 次允许 step，之后一律 slew（数据库主机必配；
# 但若环境已存在 §14.9 的周期性锯齿，须先根治锯齿再收敛本参数，顺序见 §14.9 处置）
grep -q '^makestep' /etc/chrony.conf \
  && sed -i 's|^makestep.*|makestep 1.0 3|' /etc/chrony.conf \
  || echo 'makestep 1.0 3' >> /etc/chrony.conf
systemctl enable --now chronyd
chronyc sources -v
chronyc tracking          # 部署后复核：System time 与 RMS offset 应为毫秒级
```

> **虚拟化环境两条红线**（完整现场案例与排查方法见 §14.9）：
> ① **单一时间权威**——平台 guest agent（qemu-guest-agent / pitrix guest-agent 等）的「同步宿主机时间」功能与 chronyd 只能留一个，双重对时会形成周期性时钟锯齿。数据库主机应以 NTP 为准，请平台侧仅关闭该虚机 agent 的时间同步功能（agent 还承担改密码/配 IP 等，**勿整体禁用**）。
> ② **时间源健康前提**——若上游（宿主机或内网 NTP 源）自身漂移，客户端配置再对也无济于事；`chronyc tracking` 的 RMS offset 达到秒级即为异常信号，按 §14.9 序列取证。

### 2.4 关闭透明大页（THP）

VastBase / openGauss 与 PostgreSQL 同源，THP 会导致延迟抖动，必须关闭。

```bash
# 临时
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# 持久化：写入 rc.local
cat >> /etc/rc.d/rc.local <<'EOF'
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
chmod +x /etc/rc.d/rc.local
```


### 2.5 内核参数优化（/etc/sysctl.conf）

> 下面按 **32GB 内存** 示例给出。生产现场应先记录变更前值，并按实际内存、连接数、共享内存配置调整。为避免不同 `sysctl` 版本对行内注释解析不一致，配置文件中建议 **注释单独成行**，不要把说明写在同一行参数值后面。

```bash
cp -a /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%F_%H%M%S)

cat > /etc/sysctl.conf <<'EOF'

#net.bridge.bridge-nf-call-ip6tables=1
#net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_interval=60
net.ipv4.neigh.default.gc_stale_time=120
kernel.perf_event_paranoid=-1
net.ipv4.tcp_slow_start_after_idle=0
fs.inotify.max_user_watches=524288
kernel.softlockup_all_cpu_backtrace=1
kernel.softlockup_panic=0
kernel.watchdog_thresh=30
fs.inotify.max_user_instances=8192
fs.inotify.max_queued_events=16384
vm.max_map_count=262144
#fs.may_detach_mounts=1
net.core.wmem_max=16777216
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
#kernel.yama.ptrace_scope=0
vm.swappiness=10
kernel.core_uses_pid=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.promote_secondaries=1
net.ipv4.conf.all.promote_secondaries=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_synack_retries=2
kernel.sysrq=1
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
#net.ipv4.conf.all.rp_filter=1
#net.ipv4.conf.default.rp_filter=1
kernel.dmesg_restrict=1
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0

#32G
kernel.shmmax = 17179869184
kernel.shmall = 4194304
kernel.shmmni = 4096
kernel.sem = 4096 2097152000 4096 512000
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
kernel.pid_max = 4194303
kernel.numa_balancing = 0

#kernel.randomize_va_space = 2

vm.overcommit_memory = 0
vm.dirty_ratio = 40
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
vm.min_free_kbytes = 524288
vm.zone_reclaim_mode = 0
vm.extfrag_threshold = 500
fs.file-max = 6553600
fs.aio-max-nr = 1048576
fs.nr_open = 20480000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.tcp_retries2 = 12
net.ipv4.ip_local_port_range = 26000 65500
net.ipv4.tcp_rmem = 8192 250000 16777216
net.ipv4.tcp_wmem = 8192 250000 16777216

EOF

sysctl -p

```

校验：

```bash
sysctl kernel.shmmax kernel.shmall vm.swappiness fs.file-max net.core.somaxconn
```

> ⚠️ `kernel.shmmax` 必须 ≥ 数据库 `shared_buffers` 的字节数。若现场内存为 64GB、`shared_buffers=16GB`，`kernel.shmmax` 建议至少设置为 34359738368（32GB）或更高。
> ⚠️ `kernel.randomize_va_space=0` 会关闭 ASLR，降低系统安全性。仅当特定版本安装预检明确要求且经过安全例外审批时，才临时设置为 `0`。


### 2.5.1 huge_pages 与 OS 大页配置示例

数据库参数中默认使用 `huge_pages = try`。只有在 OS 已分配足够 HugePages 并完成验证后，才允许改为 `huge_pages = on`；否则实例可能因无法分配大页而启动失败。

按 2MB HugePage 粗略估算：

```bash
# 以 32GB 主机、shared_buffers=8GB 为例：8GB / 2MB = 4096 页，再预留约 5%
HUGEPAGES=$(( (8 * 1024 / 2) * 105 / 100 ))
echo "vm.nr_hugepages = $HUGEPAGES"   # 约 4300

# 临时设置
sysctl -w vm.nr_hugepages=$HUGEPAGES

# 持久化示例；64GB 且 shared_buffers=16GB 时，按同样公式把 8 改为 16
cat >> /etc/sysctl.conf <<EOF
# VastBase huge_pages for shared_buffers=8GB, 2MB page + 5% reserve
vm.nr_hugepages = $HUGEPAGES
EOF
sysctl -p

grep -E 'HugePages_Total|HugePages_Free|Hugepagesize' /proc/meminfo
```

验收口径：`HugePages_Total × Hugepagesize` 应覆盖 `shared_buffers` 并保留约 5% 余量；压测准入时还需执行 `SHOW huge_pages;` 与 `/proc/meminfo` 交叉核验。

### 2.6 资源限制（/etc/security/limits.conf）

```bash
# 文件句柄可按全局基线放大；进程数/栈/锁内存等高风险 unlimited 仅授予数据库运行用户。
cat >> /etc/security/limits.conf <<'EOF'
*            soft    nofile          1048576
*            hard    nofile          1048576
*            soft    core            unlimited
*            hard    core            unlimited
*            soft    sigpending      90000
*            hard    sigpending      90000
*            soft    nproc           90000
*            hard    nproc           90000
vastbase soft   stack    unlimited
vastbase hard   stack    unlimited
vastbase soft   memlock  unlimited
vastbase hard   memlock  unlimited
EOF

# systemd 全局只放大 nofile；NPROC 保留为有限值。数据库服务自身在 vastbase.service 中设置 LimitNPROC。
sed -i 's/^#\?DefaultLimitNOFILE=.*/DefaultLimitNOFILE=1000000/' /etc/systemd/system.conf
sed -i 's/^#\?DefaultLimitNPROC=.*/DefaultLimitNPROC=65535/'  /etc/systemd/system.conf
systemctl daemon-reexec
```

### 2.7 I/O 调度器（SSD/NVMe 建议 none/noop，HDD 用 mq-deadline）

```bash
# 查看
cat /sys/block/sdb/queue/scheduler

# 临时设置（举例 sdb）
echo none > /sys/block/sdb/queue/scheduler

# 持久化（写入 udev 规则）
cat > /etc/udev/rules.d/60-ssd-scheduler.rules <<'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"
EOF
```

### 2.8 文件系统挂载选项（XFS 推荐）

```bash
# 建议格式化数据盘为 XFS，并使用 noatime
mkfs.xfs -f /dev/sdb1
mkdir -p /vastbase
echo "/dev/sdb1  /vastbase  xfs  defaults,noatime,nodiratime,inode64  0 0" >> /etc/fstab
mount -a
```

### 2.9 关闭不必要的服务

```bash
systemctl disable --now postfix       # 如不使用邮件
systemctl disable --now cups          # 如非桌面环境
systemctl disable --now avahi-daemon  # 局域网服务发现
```

### 2.10 CPU 性能模式（避免节能降频）

```bash
yum install -y cpupowerutils 2>/dev/null || yum install -y kernel-tools
cpupower frequency-set -g performance
echo 'cpupower frequency-set -g performance' >> /etc/rc.d/rc.local
```

### 2.11 时区与字符集

```bash
timedatectl set-timezone Asia/Shanghai
localectl set-locale LANG=en_US.UTF-8
```

完成上述操作后建议 **重启一次** 确认所有变更生效。

### 2.12 IPC参数配置

当RemoveIPC=yes时，操作系统会在用户退出时，删除该用户的IPC资源（共享内存段和信号量），从而使得 Vastbase服务器使用的IPC资源被清理，可能引发数据库宕机，所以需要设置 RemoveIPC 参数为no



新增或修改配置，若文件中已设置则跳过本步骤

```bash
vi /etc/systemd/logind.conf

RemoveIPC=no
```

```bash
vi /usr/lib/systemd/system/systemd-logind.service

RemoveIPC=no
```

重新加载配置参数

```bash
systemctl daemon-reload
systemctl restart systemd-logind
```



检查修改是否生效

```bash
#由于CentOS操作系统环境的removeIPC默认为关闭，则执行如下语句是无返回结果的
loginctl show-session | grep RemoveIPC
systemctl show systemd-logind | grep RemoveIPC
```





### 2.13 OS 变更后重启验收

完成 2.1–2.11 后建议重启一次，避免仅临时生效导致投产后参数回退。

```bash
reboot
```

重启后 root 执行：

```bash
hostnamectl
getenforce
systemctl is-active firewalld chronyd
cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
sysctl vm.swappiness kernel.shmmax fs.file-max net.core.somaxconn
su - vastbase -c 'ulimit -n; ulimit -u' 2>/dev/null || true
df -hT /vastbase
mount | grep /vastbase
```

验收口径：THP 为 `[never]`，firewalld/chronyd 为 `active`，`/vastbase` 独立挂载且文件系统为 XFS 或 ext4，`vastbase` 用户文件句柄满足规划值。

---

## 3. 数据库安装前准备

### 3.1 创建用户与组

```bash
groupadd dbgrp -g 1100
useradd  vastbase -u 1100 -g dbgrp -d /home/vastbase -m -s /bin/bash
passwd vastbase
```

### 3.2 创建目录并授权

```bash
mkdir -p /vastbase/{app,data,arch,backup,log,tools}
chown -R vastbase:dbgrp /vastbase
chmod 750 /vastbase
chmod 750 /vastbase/{app,data,arch,backup,log,tools}
# 如监控账号需要读取 /vastbase/log，请将其加入 dbgrp，或仅将 /vastbase/log 按安全审批调整为 755。
# 数据目录初始化前保持空目录；初始化后 PGDATA 通常应为 700
chmod 700 /vastbase/data
```

### 3.3 安装依赖包

```bash
yum install -y bzip2 libicu cracklib libaio libaio-devel flex bison ncurses-devel ncurses-libs glibc-devel patch readline readline-devel net-tools libnsl python3 expect libuuid krb5-libs libxslt tcl perl libxml2 bzip2 gettext libatomic
```

> 注：麒麟 V10 默认仓库通常已包含上述包；如缺包请挂载系统 ISO 作为本地源。

### 3.4 上传安装介质

将 `Vastbase-G100-CentOS-64bit-X.X.X.tar.gz` 上传至 `/vastbase/tools/`，并校验 MD5：

```bash
cd /vastbase/tools
md5sum Vastbase-G100-*.tar.gz
chown vastbase:dbgrp Vastbase-G100-*.tar.gz
```

建议同时保留以下介质信息，便于审计和回溯：

```bash
cd /vastbase/tools
sha256sum Vastbase-G100-*.tar.gz | tee Vastbase-G100.sha256
ls -lh Vastbase-G100-*.tar.gz
# 如安装包附带签名文件，应按厂家说明执行签名校验
```

### 3.5 License 文件与命令名称确认

VastBase G100 生产环境应配置正式 license。若安装阶段未配置，需在初始化后将 license 文件路径写入 `postgresql.conf`，并保证 `vastbase` 用户可读：

```bash
# root 上传 license 后授权，路径按现场约定调整
mkdir -p /vastbase/license
cp /vastbase/tools/vastbase_license /vastbase/license/vastbase_license
chown -R vastbase:dbgrp /vastbase/license
chmod 750 /vastbase/license
chmod 640 /vastbase/license/vastbase_license

# vastbase 用户写入参数
su - vastbase
printf "license_path = '/vastbase/license/vastbase_license'\n" >> $PGDATA/postgresql.conf
```

> 若当前阶段尚未初始化 `$PGDATA`，可先记录 license 路径，待第 4 章初始化后再写入并重启。试用 license 仅用于测试，不应作为正式投产依据。

【V3.0.8PSU4】现场先确认随包 `vb_*` 工具；如仅存在 `gs_*`，按历史包兼容方式处理：

```bash
su - vastbase
for c in vb_initdb vsql vb_ctl vb_guc vb_dump vb_dumpall vb_restore vb_basebackup gs_initdb gsql gs_ctl gs_guc gs_dump gs_dumpall gs_restore gs_basebackup; do
  command -v $c >/dev/null 2>&1 && echo "$c -> $(command -v $c)"
done
```

建议在脚本中定义兼容变量，避免版本切换后脚本失效：

```bash
export VB_INITDB=$(command -v vb_initdb 2>/dev/null || command -v gs_initdb)
export VB_SQL=$(command -v vsql 2>/dev/null || command -v gsql)
export VB_CTL=$(command -v vb_ctl 2>/dev/null || command -v gs_ctl)
export VB_GUC=$(command -v vb_guc 2>/dev/null || command -v gs_guc)
export VB_DUMP=$(command -v vb_dump 2>/dev/null || command -v gs_dump)
export VB_DUMPALL=$(command -v vb_dumpall 2>/dev/null || command -v gs_dumpall)
export VB_RESTORE=$(command -v vb_restore 2>/dev/null || command -v gs_restore)
export VB_BASEBACKUP=$(command -v vb_basebackup 2>/dev/null || command -v gs_basebackup)
```

**License 到期监控（生产必备）：**

VastBase 商业 license 过期后实例可能拒绝新连接或拒绝启动，必须提前告警。

> **【V3.0.8PSU4 实测要点】优先用 SQL 函数 `license_expired_time()` 读到期时间。**
> 本版**没有** `dbe_perf.license_status` 视图，也没有 `license_expire_date` GUC（旧脚本里这两个查询是早期版本的猜测，在本版会直接报
> `ERROR: relation "dbe_perf.license_status" does not exist`）。现场探测确认本版在 `pg_catalog` 下提供了无参函数 `license_expired_time()`（返回 `timestamp without time zone`），这是引擎实时返回的到期时间，最权威也最新：
>
> ```sql
> SELECT license_expired_time();
> --  license_expired_time
> -- ----------------------
> --  2026-09-30 09:42:46
> ```
>
> 相关 GUC（供定位/告警用，非必须）：`license_path`、`vb_license_path`（license 文件路径）、`vb_license_expired_notify_time`（提前通知时长）。
>
> 此外，VastBase 引擎在**启动/加载 license 时**也会把有效期打到服务器日志，形如：
>
> ```text
> LOG: License info: Customer:'Vastbase', Begins On:'2025-02-06 09:39:51', Expires On:'2025-07-31 09:42:46', MAC:''
> ```
>
> 因此监控以 **SQL 函数为首选**，数据库不可达时再回退到启动日志的 `Expires On`。license 文件本身是加密/二进制，**文本里取不到明文日期**（这正是原脚本 `file_parse=empty` 的原因），只作文件名/`strings` 末位兜底。
>
> 注意：`license_expired_time()` 需以能连库的账号（如 `vbadmin`）执行；本机工具不消费 `~/.pgpass`，脚本通过 `pgpass_lookup` + `-2`/`--pipeline` 经 stdin 注入口令（见 §10.3.1）。

**先做一次现场探测，确认本机的 license 到期来源与日志路径**：

```bash
su - vastbase
source /vastbase/scripts/backup.env 2>/dev/null || true

# 1) 在服务器日志里找 License info（最权威）。日志目录按现场实际可能是 $GAUSSLOG、$GAUSSLOG/pg_log 或 $PGDATA/pg_log。
grep -rh "License info" "${GAUSSLOG:-/vastbase/log/gauss}" "${PGDATA:-/vastbase/data}/pg_log" /vastbase/log 2>/dev/null | tail -3
# 若历史日志已轮转清理、grep 不到，可在停业务窗口重启一次让其重新打印（生产慎用）：
#   $VB_CTL restart -D "$PGDATA" -m fast    然后再 grep 最新日志

# 2) 顺带探测本版是否真有 license 相关的函数/视图/GUC（多数 V3.0.8PSU4 没有，确认即可）。
#    交互输入口令或先 source backup.env 后用 vb_sql 封装：
vb_sql postgres -c "\df *license*"  2>/dev/null
vb_sql postgres -At -c "SELECT relname FROM pg_class   WHERE relname ILIKE '%license%';" 2>/dev/null
vb_sql postgres -At -c "SELECT name    FROM pg_settings WHERE name   ILIKE '%license%';" 2>/dev/null

# 3) 确认 license 文件与命名（厂家常把到期日编进文件名，如 *_license_20250731）。
ls -l /vastbase/license/
```

> 如果第 2 步在你的补丁版本里**确实**返回了可用的函数/视图，请把对应 SQL 填进下面脚本的 `SQL_CANDIDATES`；否则保持为空，脚本将只用日志/文件名兜底。

脚本 `/vastbase/scripts/license_check.sh`：

```bash
#!/bin/bash
#==============================================================================
# license_check.sh —— 检查 VastBase license 到期日，剩余天数 ≤ 阈值则告警
# 建议加 crontab：0 9 * * *  /vastbase/scripts/sql/license_check.sh
#
# 到期来源优先级（V3.0.8PSU4 实测）：
#   1) SQL 函数 pg_catalog.license_expired_time()（引擎实时返回，最权威、最新；需 vbadmin 口令经 pipeline 注入）
#   2) 服务器日志 "License info ... Expires On:'...'"（DB 不可达时兜底，可能是上次启动时的值）
#   3) license 文件名中的日期（厂家命名约定，如 *_license_20250731）
#   4) strings 扫 license 文件（最后兜底）
# 任一来源取到合法日期即用；全部失败则告警（不误判为正常）。
#==============================================================================
set -uo pipefail
source /vastbase/scripts/backup.env 2>/dev/null || true

LIC_FILE="${LIC_FILE:-/vastbase/license/vastbase_license}"
WARN_DAYS="${WARN_DAYS:-30}"      # 提前 30 天告警
CRIT_DAYS="${CRIT_DAYS:-7}"       # 提前 7 天严重告警
DB_TIMEOUT="${DB_TIMEOUT:-10}"
LOG=/vastbase/log/license_check.log
# 服务器日志搜索目录（按现场实际补充/覆盖：export LIC_LOG_DIRS="/path1 /path2"）
LIC_LOG_DIRS="${LIC_LOG_DIRS:-${GAUSSLOG:-/vastbase/log/gauss} ${GAUSSLOG:-/vastbase/log/gauss}/pg_log ${PGDATA:-/vastbase/data}/pg_log /vastbase/log}"

log_msg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

# 文件缺失只告警、不直接判 CRITICAL：部分部署用内置/试用 license，license_path 未必落到该路径。
[[ -f "$LIC_FILE" ]] || log_msg "NOTE: license file not found at $LIC_FILE (将仅用服务器日志判断到期)"

# ---- 方法 1（权威）：从服务器日志解析 "Expires On:'...'" ----
# 取“含 License info 的最新一份日志里的最后一条”作为当前生效到期时间。
read_expire_from_log() {
    local d dirs=() files=() f val
    for d in $LIC_LOG_DIRS; do [[ -d "$d" ]] && dirs+=("$d"); done
    [[ ${#dirs[@]} -gt 0 ]] || return 1
    mapfile -t files < <(grep -rl "License info" "${dirs[@]}" 2>/dev/null | xargs -r ls -1t 2>/dev/null)
    for f in "${files[@]}"; do
        val=$(sed -nE "s/.*Expires On:'([^']+)'.*/\1/p" "$f" 2>/dev/null | tail -1)
        [[ -n "$val" ]] && { printf '%s\n' "$val"; return 0; }
    done
    return 1
}

# ---- 方法 2（可选 best-effort）：SQL 查询 ----
# 工具不消费 .pgpass：有口令则经 -2 pipeline 注入，无口令则普通调用（失败即跳过）。
# 默认 SQL_CANDIDATES 为空——本版无 dbe_perf.license_status / license_expire_date GUC，
# 用上面的探测命令确认后，再把可用语句填进来。只接受“非空”结果，任何报错都忽略。
read_expire_from_sql() {
    local sql_bin="${VB_SQL:-$(command -v vsql 2>/dev/null || command -v gsql 2>/dev/null || true)}"
    [[ -n "$sql_bin" ]] || return 1
    local pw=""
    command -v pgpass_lookup >/dev/null 2>&1 && \
        pw=$(pgpass_lookup 127.0.0.1 "${PG_PORT:-5432}" postgres "${PG_USER:-vbadmin}" 2>/dev/null || true)
    _run_sql() {
        if [[ -n "$pw" ]]; then
            printf '%s\n' "$pw" | timeout "$DB_TIMEOUT" "$sql_bin" -2 \
                -h 127.0.0.1 -p "${PG_PORT:-5432}" -U "${PG_USER:-vbadmin}" -d postgres -At -c "$1" 2>/dev/null
        else
            timeout "$DB_TIMEOUT" "$sql_bin" \
                -h 127.0.0.1 -p "${PG_PORT:-5432}" -U "${PG_USER:-vbadmin}" -d postgres -At -c "$1" </dev/null 2>/dev/null
        fi
    }
    local q out
    local SQL_CANDIDATES=(
        # 【V3.0.8PSU4 实测确认】本版提供 pg_catalog.license_expired_time()（无参，返回 timestamp）。
        "SELECT license_expired_time();"
        "SELECT pg_catalog.license_expired_time();"
        # 兜底/其他版本可能的接口（不存在即自动跳过）：
        # "SELECT expire_date FROM dbe_perf.license_status;"
        # "SELECT setting FROM pg_settings WHERE name='license_expire_date';"
    )
    for q in "${SQL_CANDIDATES[@]}"; do
        out=$(_run_sql "$q" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}( [0-9]{2}:[0-9]{2}:[0-9]{2})?' | head -1)
        [[ -n "$out" ]] && { printf '%s\n' "$out"; return 0; }
    done
    return 1
}

# ---- 方法 3：license 文件名中的日期（如 *_license_20250731 或 *_2025-07-31）----
read_expire_from_filename() {
    local base v; base=$(basename "$LIC_FILE")
    v=$(printf '%s' "$base" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    if [[ -z "$v" ]]; then
        v=$(printf '%s' "$base" | grep -oE '[0-9]{8}' | head -1)
        [[ -n "$v" ]] && v="${v:0:4}-${v:4:2}-${v:6:2}"
    fi
    [[ -n "$v" ]] && { printf '%s\n' "$v"; return 0; }
    return 1
}

# ---- 方法 4：strings 扫 license 文件（最后兜底）----
read_expire_from_strings() {
    [[ -f "$LIC_FILE" ]] || return 1
    local v
    v=$(strings "$LIC_FILE" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort -u | tail -1)
    [[ -n "$v" ]] && { printf '%s\n' "$v"; return 0; }
    return 1
}

EXPIRE_RAW=""; SRC="none"
# SQL 函数 license_expired_time() 由引擎实时返回、始终最新，故作为首选；
# 数据库不可达时回退到启动日志（可能是上次启动时的值），再退文件名/strings。
if   EXPIRE_RAW=$(read_expire_from_sql);      then SRC="sql"
elif EXPIRE_RAW=$(read_expire_from_log);      then SRC="server-log"
elif EXPIRE_RAW=$(read_expire_from_filename); then SRC="license-filename"
elif EXPIRE_RAW=$(read_expire_from_strings);  then SRC="license-strings"
else EXPIRE_RAW=""
fi

if [[ -z "$EXPIRE_RAW" ]]; then
    log_msg "WARN: cannot determine license expire date (log/sql/filename/strings all empty)."
    log_msg "      请用 §3.5 探测命令确认到期来源；多数情况下看服务器启动日志的 'License info ... Expires On'。"
    exit 1
fi

NOW_TS=$(date +%s)
EXP_TS=$(date -d "$EXPIRE_RAW" +%s 2>/dev/null) || { log_msg "WARN: bad expire date parsed: '$EXPIRE_RAW' (src=$SRC)"; exit 1; }
LEFT=$(( (EXP_TS - NOW_TS) / 86400 ))

log_msg "license expire=$EXPIRE_RAW  remaining=${LEFT}d  (src=$SRC)"

if   [[ $LEFT -lt 0          ]]; then log_msg "CRITICAL: license EXPIRED";    exit 2
elif [[ $LEFT -le $CRIT_DAYS ]]; then log_msg "CRITICAL: ${LEFT}d to expire"; exit 2
elif [[ $LEFT -le $WARN_DAYS ]]; then log_msg "WARN: ${LEFT}d to expire";     exit 1
else                                  log_msg "OK: ${LEFT}d remaining";       exit 0
fi
```
#logs
```bash
[vastbase@kylin-vastbaseg100 sql]$ ./license_check.sh 
[2026-06-07 21:22:27] license expire=2026-10-10 00:06:05  remaining=124d  (src=sql)
[2026-06-07 21:22:27] OK: 124d remaining
```

> 注：到期时间以 SQL 函数 `license_expired_time()` 为权威来源（引擎实时计算、跨重启稳定），数据库不可达时回退到启动日志的 `License info ... Expires On`；license 文件为加密/二进制，故文件名日期与 `strings` 仅作末位兜底。四种来源都取不到时，脚本返回告警而非误判正常。无论哪种方式，**告警阈值设置不少于 30 天**，给现场办理续期留出窗口。

### 3.6 配置 vastbase 用户环境变量---跳过，安装过程会写入~/.bashrc

```bash
#su - vastbase
cat >> ~/.bash_profile <<'EOF'
export GAUSSHOME=/vastbase/app
export PGDATA=/vastbase/data
export GAUSSLOG=/vastbase/log/gauss
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
export LANG=en_US.UTF-8
export PGPORT=5432
umask 077

# 【V3.0.8PSU4】工具命名兼容：优先使用 VastBase 官方 vb_* 命令；不存在时回退到历史/生态 gs_* 命令
export VB_INITDB=$(command -v vb_initdb 2>/dev/null || command -v gs_initdb 2>/dev/null)
export VB_SQL=$(command -v vsql 2>/dev/null || command -v gsql 2>/dev/null)
export VB_CTL=$(command -v vb_ctl 2>/dev/null || command -v gs_ctl 2>/dev/null)
export VB_GUC=$(command -v vb_guc 2>/dev/null || command -v gs_guc 2>/dev/null)
export VB_DUMP=$(command -v vb_dump 2>/dev/null || command -v gs_dump 2>/dev/null)
export VB_DUMPALL=$(command -v vb_dumpall 2>/dev/null || command -v gs_dumpall 2>/dev/null)
export VB_RESTORE=$(command -v vb_restore 2>/dev/null || command -v gs_restore 2>/dev/null)
export VB_BASEBACKUP=$(command -v vb_basebackup 2>/dev/null || command -v gs_basebackup 2>/dev/null)
EOF

mkdir -p /vastbase/log/gauss
source ~/.bash_profile
```

---

## 4. VastBase G100 安装与初始化

### 4.1 解压并安装(包括初始化)

```bash
# 切换到 vastbase 用户
su - vastbase
cd /vastbase/tools
tar -zxvf Vastbase-G100-*.tar.gz
cd Vastbase-installer/

$ ls -lrth
total 255M
-rwx------ 1 vastbase dbgrp 5.5M Dec  7 21:17 vastbase_installer
-rw------- 1 vastbase dbgrp 250M Dec  7 21:17 Vastbase-G100-3.0_Build8_29407-Linux-x86_64-no_mot.tar.gz
drwx------ 2 vastbase dbgrp   60 Dec  7 21:17 locales

$ ./vastbase_installer --help
===============================================================================

vastbase_installer parameter description:

None: Default database installation (manual interactive)
--uninstall   : Uninstall database (cannot be used with other parameters)
--silent      : Silent installation database
-responseFile : Specify the configuration file for silent installation (with --silent, the parameter is followed by the path to the configuration file)
-multi-pkg    : Supports the selection of database packages of different block sizes during installation

---------------


# 【现场确认】执行安装脚本：V3.0.8PSU4 不同介质可能提供 installer/install.sh/vbinstall.sh
#./install.sh -D /vastbase/app
#./vastbase_installer -multi-pkg 
./vastbase_installer
```

安装脚本会将二进制拷贝至 `$GAUSSHOME=/vastbase/app`。如果安装包带有 `om`（运维管理工具），可使用：

```bash
gs_install -X /vastbase/tools/cluster_config.xml
```

但单机环境通常用 `$VB_INITDB`（实际为 `vb_initdb` 或 `gs_initdb`）直接初始化更简洁，下面以此为例。



安装日志

```bash
[vastbase@kylin-vastbaseg100 vastbase-installer]$ ./vastbase_installer 
===============================================================================

#安装环境检查
Welcome to the installation tool (V1.0) and start installing Vastbase.

===============================================================================
Check whether the installation package is complete
---------------

ok
===============================================================================

Type <Enter> to continue: 

#系统配置信息
===============================================================================
System configuration information
---------------

Operation System : Kylin Linux Advanced Server V10 (Sword)
        CPU cores: 16
     Memory size : 30877 MB
Current user name: vastbase

Type <Enter> to continue: 

#依赖检查（检查服务器是否已经安装需要的依赖包）
===============================================================================
Dependency check
---------------

  readline : 8.0
   python2 : 2.7.18
    libicu : 62.1
  cracklib : 2.9.7
   libxslt : 1.1.34
       tcl : 8.6.10
      perl : 5.28.3
  openldap : 2.4.50
       pam : 1.4.0
systemd-libs : 243
     bzip2 : 1.0.8
   gettext : 0.21
    libaio : 0.3.112
ncurses-libs : 6.2

Type <Enter> to continue: 

#IPC参数检查
#若检查通过，自动跳转下一步，否则根据提示进行设置即可
------------------
Preparing the installation environment...

Finish to prepare the installation environment
===============================================================================
IPC parameter check
---------------

The IPC parameter check is complete

#选择是否进行实例化安装--->输入Y
===============================================================================
Install database
---------------

Whether to instantiate the database (Y/N):Y

#选择安装类型--->输入2
Select installation type

Typical installation    : Use default parameters to init database
Custom installation  : Configure installation parameters and functions manually

  -> 1- Typical installation
     2- Custom installation

Select the installation type, or type <Enter> to select the default (1):
2

#设置超级管理员密码
#设置的密码最少包含8个字符，最多包含16个字符。密码由大小写字母、数字、特殊符号组成，例如：aA123***
===============================================================================
Database Initialization User Password (Press the backspace key to go back)
---------------

Enter the password of database initialization user (vastbase): *********

Please enter your password again: *********

#设置密钥--->输入1
===============================================================================
Database encryption key(PGENCRYPTIONKEY)
---------------

Set database encryption key(PGENCRYPTIONKEY): 

  ->  1-   Use the database initialization password (default)
      2-   Enter the encryption key manually

Select the database encryption key setting, or type <Enter> to select the default(1):1

#设置数据库安装路径，或者输入<回车>使用默认路径（默认路径：/home/vastbase/local/vastbase））
#使用前面创建的目录/vastbase/app--->输入/vastbase/app
===============================================================================
Vastbase installation directory
---------------

Vastbase installation directory
 Default location: /home/vastbase/local/vastbase

Type the absolute path (ctrl+ backspace to backspace), or type <Enter> to use the default path :

/vastbase/app

#设置数据库数据目录
#注意前面设置的软件安装目录不能与这里的数据库目录相同
#使用前面创建的目录/vastbase/data--->输入/vastbase/data
===============================================================================
Database initialization directory
---------------

Select the database initialization directory Default location: /home/vastbase/data/vastbase

Type the absolute path (ctrl+ backspace to backspace), or type <Enter> to use the default path :
/vastbase/data

#监听端口：默认5432--->直接回车即可
===============================================================================
listener port
---------------

Enter the listening port, or type <Enter> to select the default (5432):

#最大连接数：默认500--->输入3000
===============================================================================
Max Connections
---------------

Enter the maximum number of client connections, or type <Enter> to select the default (500):
3000

#共享内存：默认为系统内存的1/4--->直接回车即可
===============================================================================
Shared buffers
---------------

Enter the shared memory size in MB, or enter <Enter> to select the default (7719):


#选择实例兼容模式
#可选值为A、B、PG、MSSQL,分别表示兼容Oracle、MySQL、PostgreSQL和SQL Server
#默认为Oracle兼容模式
#初始化成功后不可修改
#同一个实例中不能存在不同兼容模式的数据库

#我们选基于Mysql模式--->输入B
===============================================================================
Database compatibility mode
---------------

Specify the database compatibility mode (A|B|PG|MSSQL)

Default compatibility:A

Type compatibility above or <Enter> to use the default value

B
Database compatibility mode:B

#磁盘IO调度算法检查
===============================================================================
Check disk IO scheduling algorithm
---------------

The disk IO scheduling algorithm to which directory /vastbase/data belongs is being checked

The scheduling algorithm of disk IO is checked

#安装概要查看，核对信息
===============================================================================
Installation summary
---------------

Vastbase installation directory:
    /vastbase/app

Vastbase directory:
    /vastbase/data

Database initialization user :
    vastbase

Database initialization parameter :
   listen_addresses='*'
   port=5432
   max_connections=3000
   shared_buffers=7719MB
   max_process_memory=20533MB
   work_mem=4MB


Type <Enter> to continue: 

#开始初始化
Installation underway, please wait...
Initialize database successfully, data directory :/vastbase/data

The default passwords of the three default database administrators vbaudit, vbsso, and vbadmin are:
system admin[vbadmin] initial password: Xaa29!f3
security admin[vbsso] initial password: T>1ae228
audit admin[vbaudit] initial password: A37&5cd3

Generate the encryption key file
The encryption key file is generated successfully

The configuration file /vastbase/data/postgresql.conf was successfully updated

Writing configuration file

Writing cluster_config.xml file

Writing environment variables
The configuration file:'/home/vastbase/.bashrc' is successfully updated

---------------
#可以自己查看下环境变量
[vastbase@kylin-vastbaseg100 vastbase]$ cat ~/.bashrc
# Source default setting
[ -f /etc/bashrc ] && . /etc/bashrc

# User environment PATH
PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export PATH

source /home/vastbase/.Vastbase

[vastbase@kylin-vastbaseg100 vastbase]$ ls -a ~/
.  ..  .bash_logout  .bash_profile  .bashrc  .Vastbase  .zshrc

[vastbase@kylin-vastbaseg100 vastbase]$ cat ~/.Vastbase 
export PGPORT=5432
export PGUSER=vastbase
export PGDATA=/vastbase/data
export LD_LIBRARY_PATH=/vastbase/app/jre/lib/amd64:/vastbase/app/jre/lib/amd64/server:$LD_LIBRARY_PATH
export GAUSSHOME=/vastbase/app
export PATH=/vastbase/app/bin:$PATH
export OM_GPHOME=/vastbase/omTmp
export LD_LIBRARY_PATH=$OM_GPHOME/lib:$LD_LIBRARY_PATH
export PATH=$OM_GPHOME/script/gspylib/pssh/bin:$OM_GPHOME/script:$PATH
export PYTHONPATH=$OM_GPHOME/lib
export OM_GAUSS_VERSION=3.0.8
export OM_PGHOST=/vastbase/omTmp/tmp
export OM_GAUSSLOG=/vastbase/data/pg_log
export OM_GAUSS_ENV=2
export OM_GS_CLUSTER_NAME=dbCluster
--------------

#配置license
#输入Y，提示输入license路径，正确输入即可
#输入N，自动生成有效期90天的license作为试用版本
===============================================================================
Loading an Official license
---------------

Whether to load an official license (Y/N): Y
Input the license path
Type the absolute path (ctrl+ backspace to backspace):
/vastbase/license/vastbase_license
license path: /vastbase/license/vastbase_license

license info: Customer:'迪爱斯', Begins On:'2025-10-10 00:00:00', Expires On:'2026-10-10 00:06:05', MAC:'', Model:'G100', Support Module:'BASIC, VECTOR'

#安装数据库（提示安装完成）
#按回车退出
===============================================================================
Installation complete
---------------

To initialize the database running environment:
    source ~/.bashrc

To start, stop, and restart the database:
    vb_ctl <start/stop/restart>


If the installation is complete, Enter <Enter> to exit:

```

整个安装过程的配置信息会记录到install_config.log文件中

```bash
[vastbase@kylin-vastbaseg100 vastbase-installer]$ cat install_config.log 
Whether to instantiate the database (Y/N): Y

Select installation type

Typical installation    : Use default parameters to init database
Custom installation  : Configure installation parameters and functions manually

  -> 1- Typical installation
     2- Custom installation
Select the installation type, or type <Enter> to select the default (1):
2

Vastbase installation directory
 Default location: /home/vastbase/local/vastbase

Type the absolute path (ctrl+ backspace to backspace), or type <Enter> to use the default path :
/vastbase/app

Select the database initialization directory Default location: /home/vastbase/data/vastbase

Type the absolute path (ctrl+ backspace to backspace), or type <Enter> to use the default path :
/vastbase/data
Enter the listening port, or type <Enter> to select the default (5432):
5432

Enter the maximum number of client connections, or type <Enter> to select the default (500):
3000
Enter the shared memory size in MB, or enter <Enter> to select the default (7719):
7719
Whether to load an official license (Y/N): Y

Input the license path
Type the absolute path (ctrl+ backspace to backspace):
/vastbase/license/vastbase_license

```



### 4.2 安装时，未选择初始化--->初始化数据库实例（关键：开启 MySQL 兼容模式）

> 【V3.0.8PSU4 / 现场确认】`vb_initdb`/`gs_initdb` 的 `-W`、`-w` 在不同介质中可能表示“命令行明文密码”而非交互式提示。生产基线不再把 `-W` 作为默认初始化写法；初始化前必须留存 `$VB_INITDB --help` 输出，并以 `--pwfile` 一次性密码文件作为推荐方案。若当前介质的 `--help` 明确提供交互式提示参数，可由 DBA 手工改用，但必须在实施记录中写明。

查看下帮助信息
```bash
[vastbase@kylin-vastbaseg100 ~]$ which vb_initdb 
/vastbase/app/bin/vb_initdb
[vastbase@kylin-vastbaseg100 ~]$ vb_initdb --help
vb_initdb initializes a database cluster.

Usage:
  vb_initdb [OPTION]... [DATADIR]

Options:
  -A, --auth=METHOD         default authentication method for local connections
      --auth-host=METHOD    default authentication method for local TCP/IP connections
      --auth-local=METHOD   default authentication method for local-socket connections
  -c, --enable-dcf          enable DCF mode
      --enable-dss          enable shared storage mode
  -I,                       Specify the node ID and initialize the resource pooling parameter ss_instance_id.
                            Value range: [0-63], needs to be specified starting from 0.
 [-D, --pgdata=]DATADIR     location for this database cluster
      --nodename=NODENAME   name of single node initialized, this is mandatory
      --vgname=VGNAME       name of dss volume group
      --socketpath=SOCKETPATH
                            dss connect socket file path
      --dms_url=URL         message communication url between nodes
  -E, --encoding=ENCODING   set default encoding for new databases
      --locale=LOCALE       set default locale for new databases
      --dbcompatibility=DBCOMPATIBILITY   set default dbcompatibility for new database
      --enable-oralob-type   enable new version of clob/blob
      --pad-attribute=PADATTRIBUTE        set default pad attribute for new database
                                          support NO PAD(N, default) and PAD SPACE(S)
      --lc-collate=, --lc-ctype=, --lc-messages=LOCALE
      --lc-monetary=, --lc-numeric=, --lc-time=LOCALE
                            set default locale in the respective category for
                            new databases (default taken from environment)
      --no-locale           equivalent to --locale=C
      --pwfile=FILE         read password for the new system admin from file
  -T, --text-search-config=CFG
                            default text search configuration
  -U, --username=NAME       database system admin name
  -W, --pwprompt            prompt for a password for the new system admin
  -w, --pwpasswd=PASSWD     get password from command line for the new system admin
  -C, --enpwdfiledir=DIR    get encrypted password of AES128 from cipher and rand file
  -X, --xlogdir=XLOGDIR     location for the transaction log directory
  -S, --security            remove normal user's privilege on public schema in security mode
  -g, --xlogpath=XLOGPATH   xlog file path of shared storage

Less commonly used options:
  -d, --debug               generate lots of debugging output
  -L DIRECTORY              where to find the input files
  -n, --noclean             do not clean up after errors
  -s, --show                show internal settings

Other options:
  -H, --host-ip             node_host of database node initialized
      --audit_encrypt_algorithm=AUDITENCRYPTALGORITHM   encrypt algorithm of audit file
      --audit_master_key=MASTERKEY   master key to encrypt key of audit file
      --audit_encrypt_key=ENCRYPTKEY   encrypt key of audit file
  -?, --help                show this help, then exit

If the data directory is not specified, the environment variable PGDATA
is used.
[vastbase@kylin-vastbaseg100 ~]$ 

```

```bash
# 【V3.0.8PSU4 验收证据】初始化前先保存工具帮助，重点核对 -W/-w/--pwfile 语义。
mkdir -p /vastbase/docs/evidence
$VB_INITDB --help | tee /vastbase/docs/evidence/vb_initdb_help_$(date +%F_%H%M%S).txt
$VB_INITDB --help | grep -E -- '(-W|-w|--pwfile|dbcompatibility)' || true

# 【通用关键】仍在 vastbase 用户下：初始化时固定 MySQL 兼容模式，后续不跨模式混用。
# 推荐：使用一次性密码文件，避免密码进入 shell history 和进程参数。
umask 077
PWFILE=$(mktemp /tmp/vb_initdb.pw.XXXXXX)
trap 'shred -u "$PWFILE" 2>/dev/null || rm -f "$PWFILE"; trap - EXIT INT TERM' EXIT INT TERM
printf '%s\n' '替换为强密码' > "$PWFILE"

$VB_INITDB -D $PGDATA \
           -E UTF8 \
           --locale=en_US.UTF-8 \
           --nodename=vbdb01 \
           -U vbadmin \
           --pwfile="$PWFILE" \
           --dbcompatibility=B

INITDB_RC=$?
shred -u "$PWFILE" 2>/dev/null || rm -f "$PWFILE"
trap - EXIT INT TERM
[[ $INITDB_RC -eq 0 ]] || exit $INITDB_RC
```

参数说明：

| 参数 | 含义 |
|------|------|
| `-D` | 数据目录 |
| `-E UTF8` | 字符集 |
| `--locale` | 本地化设置 |
| `--nodename` | 节点名（控制工具启动时识别） |
| `-U` | 初始超级用户 |
| `--pwfile` | 【推荐】从一次性文件读取初始密码；文件权限应为 `600`，初始化结束或中断时通过 `trap` 删除或粉碎 |
| `-W` / `-w` | 【现场确认】不作为默认写法；只有 `--help` 明确显示其为交互提示时才可手工使用，若描述为 `PASSWORD`/明文参数则禁止生产使用 |
| `--dbcompatibility=B` | **B 模式 = MySQL 兼容**（A、B、PG、MSSQL,分别表示兼容Oracle、MySQL、PostgreSQL和SQL Server） |

> 💡 `--dbcompatibility` 决定实例级兼容模式。VastBase 官方安装说明强调初始化成功后不可修改，同一实例不应混用不同兼容模式；后续 `CREATE DATABASE ... DBCOMPATIBILITY` 应与实例模式保持一致。

### 4.3 调整核心配置文件

```bash
# 监听地址
$VB_GUC set -D $PGDATA -c "listen_addresses = '0.0.0.0'"
$VB_GUC set -D $PGDATA -c "port = 5432"
$VB_GUC set -D $PGDATA -c "max_connections = 300"

# 日志目录
mkdir -p /vastbase/log/pg_log
$VB_GUC set -D $PGDATA -c "log_directory = '/vastbase/log/pg_log'"
```

### 4.4 MySQL 兼容模式关键参数（建库前定稿）

> 【通用关键 / B 模式专用】以下参数必须在创建业务数据库、表和执行导入前定稿，尤其 `lower_case_table_names` 为 POSTMASTER 级参数。`template0/template1` 在初始化后已经存在不是主要风险；真正的风险是在创建业务对象、导入 dump 或搭建主备后再修改，导致对象名大小写、索引名、过程名和恢复行为不一致。

```bash
# 在创建业务库与对象前定稿；POSTMASTER 级参数会在第一次 start 时生效。
$VB_GUC set -D $PGDATA -c "b_compatibility_mode = on"
$VB_GUC set -D $PGDATA -c "enable_set_variable_b_format = on"
$VB_GUC set -D $PGDATA -c "lower_case_table_names = 1"
$VB_GUC set -D $PGDATA -c "explicit_defaults_for_timestamp = on"
$VB_GUC set -D $PGDATA -c "vastbase_sql_mode = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION,NO_ZERO_DATE,NO_ZERO_IN_DATE'"

# V3.0.8PSU4 增强项：仅当应用确实依赖过程/函数名大小写折叠时启用。
# $VB_GUC set -D $PGDATA -c "lower_case_function_names = 1"

# 首次部署：实例尚未启动，参数将在 §5.1 第一次 start 时生效，无需 restart。
# 已运行实例（升级或回归）：仅当 status 显示正在运行时才 restart。
if $VB_CTL status -D $PGDATA >/dev/null 2>&1; then
    $VB_CTL restart -D $PGDATA -m fast
else
    echo "instance not started yet; parameters will apply at next start (see §5.1)"
fi

# 验证留到实例启动后执行。注意：本机 vsql 不消费 .pgpass，手动执行时直接用 -W 交互输入密码即可；
# 脚本中（已 source backup.env）应改用 vb_sql 封装（经 --pipeline 注入口令，见 §10.3.1）。
# $VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -W \
#         -c "SHOW b_compatibility_mode; SHOW lower_case_table_names; SHOW vastbase_sql_mode;"
```

> 后续第 6.7 节改为参数说明与台账核查；现场实施顺序以本节“建库前定稿”为准，不再重复 `set`/`restart`。

---

## 5. 数据库启停与监听配置

### 5.1 启停命令

```bash
# 启动
$VB_CTL start  -D $PGDATA

# 停止（smart：等待事务完成，fast：立即回滚未提交事务）
$VB_CTL stop   -D $PGDATA -m fast

# 重启
$VB_CTL restart -D $PGDATA -m fast

# 重载配置（不重启）
$VB_CTL reload -D $PGDATA

# 状态
$VB_CTL status -D $PGDATA
```



### 5.2 设置开机自启（systemd）

以 root 用户创建。为兼容 `vb_ctl` / `gs_ctl` 命名差异，先创建统一控制命令软链接：

```bash
CTL_BIN=$(su - vastbase -c 'command -v vb_ctl 2>/dev/null || command -v gs_ctl 2>/dev/null')
[[ -n "$CTL_BIN" ]] || { echo "vb_ctl/gs_ctl not found"; exit 1; }
ln -sf "$CTL_BIN" /vastbase/app/bin/vastbase_ctl
chown -h vastbase:dbgrp /vastbase/app/bin/vastbase_ctl

cat > /etc/systemd/system/vastbase.service <<'EOF'
[Unit]
Description=VastBase G100 Database
After=network.target

[Service]
Type=forking
User=vastbase
Group=dbgrp
Environment=GAUSSHOME=/vastbase/app
Environment=PGDATA=/vastbase/data
Environment=GAUSSLOG=/vastbase/log/gauss
Environment=LD_LIBRARY_PATH=/vastbase/app/lib
Environment=PATH=/vastbase/app/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/vastbase/app/bin/vb_ctl start  -D /vastbase/data
ExecStop=/vastbase/app/bin/vb_ctl stop   -D /vastbase/data -m fast
ExecReload=/vastbase/app/bin/vb_ctl reload -D /vastbase/data
LimitNOFILE=1000000
#LimitNPROC=unlimited
TimeoutSec=300
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vastbase
```

---

启动失败，查看错误

```bash
journalctl -u vastbase --no-pager -n 100
```





## 6. 数据库参数优化（postgresql.conf）

> 以下示例 **基于 32GB 内存、16 核 CPU、SSD 数据盘**，定位为压测前的“起步保守值”。本节与 §20.3 的 32GB 列保持一致；64GB 或更高规格按 §20.3 的 64GB 列起步。以上为压测起步值，最终值以 §20 压测结论和投产参数定稿单为准。

vbadmin的单独参数

```bash
su - vastbase -c 'source /vastbase/scripts/backup.env
vb_sql postgres -c "ALTER ROLE vbadmin SET statement_timeout = 0;"
vb_sql postgres -c "ALTER ROLE vbadmin SET idle_in_transaction_session_timeout = 0;"'
```



### 6.1 内存类参数

```ini
shared_buffers           = 8GB        # 物理内存 25%
work_mem                 = 32MB       # 单个排序/Hash 操作内存；高并发先保守，出现临时文件后再评估上调
maintenance_work_mem     = 2GB        # vacuum/create index 用
effective_cache_size     = 24GB       # 物理内存 75%，仅用于优化器估算
temp_buffers             = 32MB
wal_buffers              = 64MB       # 默认 -1 由 shared_buffers 推算；显式给值更稳定
huge_pages               = try        # 仅当 §2.5 已分配 OS 大页且验证通过时才改为 on
```

> `work_mem` 是单连接、单算子级别内存，不是全实例共享池。压测和投产时必须同时核算“实际活跃并发 × work_mem”，不要仅按 `max_connections × work_mem` 机械放大。

### 6.2 连接与并发

```ini
max_connections                 = 300
sysadmin_reserved_connections  = 10
max_prepared_transactions       = 0   # 不用两阶段提交时设 0；用 XA 时设 = max_connections
max_locks_per_transaction       = 256
max_pred_locks_per_transaction  = 256
```

> 32GB 主机不建议把 `max_connections` 直接设为 500。若业务连接数膨胀，应优先通过应用连接池或 PgBouncer/Pgpool-II 控制真实活跃连接，而不是单纯增大数据库后端进程数。

### 6.3 WAL 与 Checkpoint

```ini
wal_level                       = replica          # 主备时用 replica/hot_standby
fsync                           = on
synchronous_commit              = on               # 跨数据中心可设 local 降延迟
#full_page_writes                = on
wal_compression                 = on
#max_wal_size                    = 16GB
min_wal_size                    = 2GB
checkpoint_timeout              = 15min
checkpoint_completion_target    = 0.9
checkpoint_warning              = 30s

# 归档（按需启用）
archive_mode                    = on
archive_command                 = 'test ! -f /vastbase/arch/%f && cp %p /vastbase/arch/%f'
```

### 6.4 查询优化器与并行执行

```ini
random_page_cost                = 1.1          # SSD：1.1；HDD：4
effective_io_concurrency        = 200          # SSD 200，NVMe 可更高，HDD 设 2
default_statistics_target       = 200
seq_page_cost                   = 1
cpu_tuple_cost                  = 0.01
cpu_index_tuple_cost            = 0.005

# 并行执行起步基线；报表/汇总场景会明显受影响，OLTP 场景可按压测结果下调。
max_worker_processes            = 16           # 全局后台进程数，含 autovacuum、parallel worker、logical apply
max_parallel_workers            = 8            # 全实例并行 worker 上限
max_parallel_workers_per_gather = 2            # 单查询并行度；OLTP 建议 0–2，OLAP 可评估 4–8
max_parallel_maintenance_workers= 2            # CREATE INDEX 等维护操作并行度
```

### 6.5 Autovacuum

```ini
autovacuum                      = on
autovacuum_max_workers          = 6
autovacuum_naptime              = 30s
autovacuum_vacuum_threshold     = 50
autovacuum_vacuum_scale_factor  = 0.1
autovacuum_analyze_threshold    = 50
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_cost_delay    = 10ms
autovacuum_vacuum_cost_limit    = 2000
```

### 6.6 日志（运维必备）

```ini
logging_collector             = on
log_directory                 = '/vastbase/log/pg_log'
log_filename                  = 'vastbase-%Y-%m-%d_%H%M%S.log'
log_file_mode                 = 0600
log_truncate_on_rotation      = off
log_rotation_age              = 1d
log_rotation_size             = 100MB

log_min_duration_statement    = 1000           # 慢 SQL ≥ 1s 记录；压测期间可临时降到 500，压测后恢复
log_connections               = on
log_disconnections            = on
log_lock_waits                = on
log_temp_files                = 10240          # 10MB 阈值；0=记录所有临时文件，-1=禁用
log_statement                 = 'ddl'          # 记录所有 DDL
log_line_prefix               = '%m [%p] %q%u@%d/%a from %h '
log_timezone                  = 'Asia/Shanghai'

# 性能采集开关：§12.2、§13、§20 压测准入和采集 SQL 均依赖本组参数
# 若现场版本缺少某个参数，需在参数台账中说明并从采集 SQL 中注释对应 SHOW。
enable_resource_track        = on
track_stmt_stat_level        = 'L1,L1'
enable_resource_record       = on
instr_unique_sql_count       = 10000
track_activity_query_size    = 4096
```

### 6.7 MySQL 兼容相关

```ini
# 【MySQL 兼容模式专用】关键参数，生产应在创建业务库和对象前定稿
b_compatibility_mode          = on      # 冲突语法优先按 MySQL 行为解析；USERSET，可按库/用户设置
enable_set_variable_b_format  = on      # 支持 MySQL 风格用户变量，如 @v := 1；按版本确认
lower_case_table_names        = 1       # 对象名大小写不敏感；仅 B 模式支持，POSTMASTER，需重启
# 【现场确认】lower_case_column_names 在不同 VastBase/openGauss 补丁中支持情况不稳定；
# 如需启用，先 SHOW lower_case_column_names; 或查 pg_settings，确认存在后再写入 postgresql.conf。
# lower_case_column_names     = 0       # 列名/别名大小写兼容 MySQL 行为；确认存在后再启用
explicit_defaults_for_timestamp = on    # TIMESTAMP 默认值/空值行为更接近现代 MySQL
vastbase_sql_mode = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION,NO_ZERO_DATE,NO_ZERO_IN_DATE'

# 【V3.0.8PSU4/B 模式增强】控制自定义存储过程和函数名称在 pg_proc 中是否大小写敏感。
# 仅当源库/应用确实依赖函数名大小写行为时设置，并在建对象前定稿。
# lower_case_function_names = 1

# 【V3.0.8PSU4 可选】过程/函数需要多结果集返回时，经客户端验证后可追加：
# behavior_compat_options = 'block_return_multi_results'

# 【V3.0.8PSU4 注意】使用向量索引时不要开启向量并行查询，默认 0 即关闭。
max_vector_indexer_query_threads = 0

# 如源库依赖 || 做字符串拼接，再追加 pipes_as_concat
# 如源库依赖 CHAR 尾部填充，再追加 pad_char_to_full_length
# enable_duplicate_indexnames = off     # 默认 off；仅源 MySQL 大量存在“不同表同名索引”时评审后开启
```

关键说明：

1. `lower_case_table_names` 必须在创建业务数据库、表和执行导入前定稿；导出端和导入端应保持一致，主备节点也必须保持一致。
2. `lower_case_column_names` 不作为默认下发项；当前介质必须先 `SHOW lower_case_column_names;` 或 `SELECT name FROM pg_settings WHERE name='lower_case_column_names';` 确认存在。不存在时写入 `postgresql.conf` 会导致实例启动失败。
3. 本组关键参数已在 §4.4 完成建库前定稿；如已创建过业务对象后才发现需要变更，必须参考 §19 变更与回滚流程，先完成备份、恢复演练和应用全量回归。
4. `enable_duplicate_indexnames` 会影响索引命名、删除索引语法和 dump/restore 行为，除非迁移评估确认需要，不建议默认开启。
5. `vastbase_sql_mode` 可用于对齐 MySQL `sql_mode` 行为。上方给出的是生产迁移常用的起步基线，投产前仍必须根据源库 `SELECT @@sql_mode;`、应用 SQL 回归和数据质量要求逐项裁剪。
6. V3.0.8PSU4 中 `DATE_FORMAT`、`FROM_UNIXTIME`、`STR_TO_DATE` 明确属于 B 模式能力；其他兼容模式脚本不要复用。
7. V3.0.8PSU4 的 MySQL 兼容模式下 `CURRENT_TIMESTAMP`、`localtimestamp`、`now()`、`localtime` 返回类型按 `timestamp(0)` 处理；业务依赖微秒时在 DDL/DML 中显式写 `CURRENT_TIMESTAMP(6)`。
8. `vb_enable_comm_shm` 与 `enable_thread_pool` 不得同时设置为 `on`；如启用线程池或共享内存连接，必须在预检脚本中增加互斥检查。
9. 压测报告中必须记录 `b_compatibility_mode`、`vastbase_sql_mode`、`lower_case_table_names`、`lower_case_function_names`、`behavior_compat_options` 等兼容相关参数；兼容选项任何变更后必须复测核心 SQL。

```bash
# 这些参数应已在 §4.4 建库前定稿；本节只做参数台账核查与按需微调。
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -c "SHOW b_compatibility_mode;"
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -c "SHOW lower_case_table_names;"
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -c "SHOW explicit_defaults_for_timestamp;"
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -c "SELECT name FROM pg_settings WHERE name='lower_case_column_names';"
```

### 6.8 批量下发参数

```bash
# 用 $VB_GUC set 持久化，需重启的参数会提示。
# 本示例为 32GB 压测起步值；64GB 按 §20.3 的 64GB 列执行。
$VB_GUC set -D $PGDATA -c "shared_buffers = 8GB"
$VB_GUC set -D $PGDATA -c "effective_cache_size = 24GB"
$VB_GUC set -D $PGDATA -c "work_mem = 32MB"
$VB_GUC set -D $PGDATA -c "maintenance_work_mem = 2GB"
$VB_GUC set -D $PGDATA -c "temp_buffers = 32MB"
$VB_GUC set -D $PGDATA -c "wal_buffers = 64MB"
$VB_GUC set -D $PGDATA -c "max_connections = 300"
$VB_GUC set -D $PGDATA -c "sysadmin_reserved_connections = 10"
$VB_GUC set -D $PGDATA -c "max_wal_size = 16GB"
$VB_GUC set -D $PGDATA -c "min_wal_size = 2GB"
$VB_GUC set -D $PGDATA -c "checkpoint_timeout = 15min"
$VB_GUC set -D $PGDATA -c "checkpoint_completion_target = 0.9"
$VB_GUC set -D $PGDATA -c "autovacuum_max_workers = 6"
$VB_GUC set -D $PGDATA -c "autovacuum_vacuum_cost_limit = 2000"
$VB_GUC set -D $PGDATA -c "default_statistics_target = 200"
$VB_GUC set -D $PGDATA -c "max_worker_processes = 16"
$VB_GUC set -D $PGDATA -c "max_parallel_workers = 8"
$VB_GUC set -D $PGDATA -c "max_parallel_workers_per_gather = 2"
$VB_GUC set -D $PGDATA -c "max_parallel_maintenance_workers = 2"

# 性能采集开关；§12.2、§13、§20 压测准入和采集 SQL 均依赖本组参数。
$VB_GUC set -D $PGDATA -c "enable_resource_track = on"
$VB_GUC set -D $PGDATA -c "track_stmt_stat_level = 'L1,L1'"
$VB_GUC set -D $PGDATA -c "enable_resource_record = on"
$VB_GUC set -D $PGDATA -c "instr_unique_sql_count = 10000"
$VB_GUC set -D $PGDATA -c "track_activity_query_size = 4096"

# 修改完后重启；仅 SIGHUP 参数可按提示 reload。
$VB_CTL restart -D $PGDATA -m fast
```

---
### 6.9 当前参数
#32G

```conf
#==============================================================================
# VastBase G100 V3.0.8PSU4 — 参数纯净版（32GB 内存 / MySQL(B) 兼容 / 单实例）
#------------------------------------------------------------------------------
# 用途：替换原 postgresql.conf 末尾那段杂乱、重复、值互相冲突的覆盖块。
#       本文件只列“实际下发并生效”的参数，已去重、已纠错、已按 32GB 调优。
#
# 使用方式：
#   1. 本文件中的值放在 postgresql.conf 末尾即可（后出现的覆盖先出现的）；
#      为避免再次出现“一个参数多处定义”，建议直接用本文件作为唯一覆盖段。
#   2. initdb 在 MySQL(B) 兼容模式下设定的 vb_*/behavior_compat_options 等
#      兼容行为参数【不在本文件内】，保持初始化值不动；改动需做兼容回归测试。
#   3. 标 (RESTART) 的参数改动需重启实例；其余 reload 生效。
#
# 相对原配置的关键改动：
#   - max_connections        3000 → 500   （32GB 直连 3000 必撑爆内存；详见下方说明）
#   - log_min_duration_statement 50000 → 10000  （单位是毫秒）
#   - work_mem               64MB → 32MB  （高连接数下保守起步）
#   - cstore_buffers         512MB → 16MB （行存 OLTP 用不到列存缓冲）
#   - bulk_write_ring_size   2GB → 256MB  （无大批量 COPY 时不必预留 2GB）
#   - autovacuum             三套冲突定义 → 合并为一套
#   - 其余内存/WAL/checkpoint 维持原合理值
#==============================================================================


#------------------------------------------------------------------------------
# 连接与认证
#------------------------------------------------------------------------------
listen_addresses = '*'                  # (RESTART)
port = 5432                             # (RESTART)

# ★ 待实测后收口 ★
# 32GB 服务器的安全直连上限约 500–600（每个后端常驻约 5MB，500 连接≈2.5GB，
# 叠加 shared_buffers 8GB ≈ 10.5GB，对 32GB 健康）。
# 现状是 8 个项目各开 300 池 = 2400，远超 32GB 直连能力。等业务上线后，按
# pg_stat_activity 里 state='active' 的真实活跃峰值决定走哪条路：
# select count(1) from pg_stat_activity where state='active';
# select * from pg_stat_activity where state='active';
#   方案A：把每个项目池 maxPoolSize 降到 40–60（8×50=400），max_connections 设 500；
#   方案B：前置 PgBouncer(transaction)，2400 逻辑连接→100~150 物理后端，max_connections 设 200；
#   方案C：连接规模确属刚需且活跃度高 → 加内存到 64GB+，再上调本值。
# 在此之前先用 500 起步，绝不要保留 3000 直连。
# 备选：openGauss 线程池 enable_thread_pool=on 可让连接与线程解耦、缓解高连接开销，
#       但需厂家配合按核数规划 thread_pool_attr，本版上线前务必小并发验证，故此处不默认开启。
max_connections = 500                   # (RESTART)
sysadmin_reserved_connections = 10      # (RESTART) 保留 DBA 应急连接

password_encryption_type = 1            # 0=md5(PG) 1=sha256+md5 2=sha256；保持 1
username_check_enabled = on

# 空闲会话超时：与连接池共存时，过短会导致池内空闲连接被服务端断开、引发池抖动。
# 默认禁用；若安全基线要求启用，请同时在应用池配置 keepalive/testOnIdle 并取较大值。
session_timeout = 0                     # 0=禁用；启用示例 30min


#------------------------------------------------------------------------------
# 内存
#------------------------------------------------------------------------------
shared_buffers = 8GB                     # (RESTART) ≈25% 物理内存
effective_cache_size = 24GB              # ≈75% 物理内存；仅供优化器估算，不实际分配
max_process_memory = 20GB                # (RESTART) 实例总动态内存上限(≈62%)，余量留给 OS/page cache
enable_memory_limit = on                # 保持开启：超限时查询报错而非内核 OOM

work_mem = 32MB                          # 单算子内存；出现大量临时文件且活跃并发不高时再评估上调
                                         # 经验上限：活跃并发 × work_mem ≤ 物理内存 × 25%(=8GB)
maintenance_work_mem = 2GB               # VACUUM / CREATE INDEX / 导入
temp_buffers = 32MB

cstore_buffers = 16MB                    # 列存缓冲；行存 OLTP 调到最小即可
bulk_write_ring_size = 256MB             # 批量装载环形缓冲；有大批量 COPY 再上调
max_prepared_transactions = 0            # (RESTART) 不用 XA/两阶段提交则设 0，省共享内存；用到再设 200


#------------------------------------------------------------------------------
# WAL
#------------------------------------------------------------------------------
wal_level = hot_standby                  # (RESTART) 预留主备能力
fsync = on
full_page_writes = off                   # 与下面 enable_double_write=on + 增量检查点配套，
                                         # 由 double-write 防 torn page，是本内核的正确组合，勿误开
enable_double_write = on
wal_log_hints = on
wal_buffers = 64MB                        # (RESTART)
synchronous_commit = on
advance_xlog_file_num = 10
vb_wal_directory = 'pg_xlog'             # (RESTART)


#------------------------------------------------------------------------------
# 检查点
# 注意：本内核(openGauss/PG9.2.4 血统)用 checkpoint_segments，没有 max_wal_size。
#------------------------------------------------------------------------------
enable_incremental_checkpoint = on
incremental_checkpoint_timeout = 60s
checkpoint_segments = 256                 # ×16MB ≈ 4GB；默认为128约2G
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
checkpoint_warning = 5min
checkpoint_wait_timeout = 60s
pagewriter_sleep = 5ms


#------------------------------------------------------------------------------
# 复制（单实例暂不启用，参数预置便于将来搭备）
# 注意：本内核用 wal_keep_segments（段数），没有 PG13 的 wal_keep_size。
#------------------------------------------------------------------------------
max_wal_senders = 4                       # (RESTART)
max_replication_slots = 8
wal_keep_segments = 16                    # 将来搭主备时按需上调（256 ≈ 4GB）
hot_standby = on                          # (RESTART)
enable_stream_replication = on
enable_xlog_prune = off                   # 防止备库未连接时 WAL 被过早清理


#------------------------------------------------------------------------------
# 查询优化（OLTP 起步）
#------------------------------------------------------------------------------
query_dop = 1                             # 单查询并行度；OLAP/报表场景再按需上调
enable_mergejoin = on
enable_nestloop = on
enable_hashjoin = on
enable_bitmapscan = on
enable_codegen = off                      # LLVM；OLTP 收益有限，保持关闭
#default_statistics_target = 100          # 计划不稳/复杂查询多时上调后重新 ANALYZE


#------------------------------------------------------------------------------
# 磁盘类型相关（★ 按实际盘型二选一，部署前务必确认 ★）
# 以下为优化器 I/O 成本/预取参数，与盘型强相关、与内存无关，32G/64G 取值相同。
# 默认启用【SAS 10k RAID5 / 旋转盘】安全值；若实际是 SSD/NVMe，注释这两行、改用下方 SSD 组。
# 误用风险不对称：旋转盘上若错配 SSD 的低 random_page_cost，会诱导优化器过度走随机访问，
# 慢盘上计划更糟；故默认取旋转盘安全值，SSD 为显式 opt-in。
#------------------------------------------------------------------------------
seq_page_cost = 1.0                       # 顺序扫描成本基准，两种盘都用 1.0
# —— SAS 10k RAID5 / 旋转盘（默认启用）——
random_page_cost = 4.0                    # [盘型切换] 旋转盘随机寻道贵，保持默认
effective_io_concurrency = 4              # [盘型切换] ≈ RAID5 数据盘块数(总盘数-1)，常见 2–6，按实际阵列填
# —— SSD / NVMe（如用 SSD：注释上面两行，启用下面两行）——
#random_page_cost = 1.1                   # [盘型切换] SSD 随机≈顺序，降到接近 1
#effective_io_concurrency = 200           # [盘型切换] SSD 高并发预取；NVMe 可更高
#
# ─────── RAID5 写放大降压（本版 openGauss/增量检查点 语义，非原生 PG9.2 口径）───────
# 约定：凡标 [盘型切换] 的行都按同一盘型取舍；可 `grep 盘型切换` 一次性核对全文。
# 默认盘型=RAID5，故下方 autovacuum 段 cost 两行也已默认取 RAID5 温和值（同样标 [盘型切换]）。
#
# 第①层 确定执行（RAID5）：autovacuum 调温和，直接限制 vacuum 的 IO 强度 —— 见下方 autovacuum 段。
#
# 第②层 验证后按需（先测再调，不盲设值）：
#   · pagewriter_sleep：本版 enable_incremental_checkpoint=on，脏页下刷由 pagewriter 线程负责
#     （非原生 PG 的 bgwriter）。当前 5ms 偏激进，RAID5 上频繁小随机写会被校验写惩罚放大；
#     若观测阵列被检查点/pagewriter IO 打满，再测试放宽到 50–100ms。
#   · bgwriter_lru_maxpages / bgwriter_delay：增量检查点开启后其作用被 pagewriter 大幅接管，
#     照搬 PG 的 400/200ms 未必生效；先用下方 SQL 确认本版语义再决定是否动。
#   · 评估手段：高峰/压测看 pg_stat_bgwriter 与 WDR 报告的 checkpoint/IO 段，按实测调。
#
# 第③层 不建议（破除“WAL 三件套”误区）：
#   · commit_delay/commit_siblings/wal_writer_delay 主要作用于“异步提交”的 WAL 节奏；
#     本配置 synchronous_commit=on，收益有限，不为“凑齐”而设。
#   · RAID5 上 WAL 真正有效的是物理隔离：pg_xlog 与归档分到独立物理盘/阵列；
#     wal_buffers 已设 64MB，足够，不必再加。
#   · 写密集型库本不宜用 RAID5，条件允许优先 RAID10。
#
# ── 下发前先跑这段，确认每个参数“本版是否存在 + 单位/语义 + 是否需重启” ──
#    缺失的参数不会返回；context=sighup 可 reload，postmaster 需重启。
# SELECT name, setting, unit, context, min_val, max_val, boot_val
#   FROM pg_settings
#  WHERE name IN (
#    'random_page_cost','effective_io_concurrency','seq_page_cost',
#    'autovacuum_vacuum_cost_delay','autovacuum_vacuum_cost_limit','autovacuum_max_workers',
#    'pagewriter_sleep','enable_incremental_checkpoint','incremental_checkpoint_timeout',
#    'bgwriter_delay','bgwriter_lru_maxpages','bgwriter_lru_multiplier',
#    'checkpoint_completion_target','checkpoint_timeout',
#    'commit_delay','commit_siblings','wal_writer_delay','synchronous_commit','wal_buffers')
#  ORDER BY name;
# ──────────────────────────────────────────────────────────────────────────


#------------------------------------------------------------------------------
# autovacuum（已合并原三套冲突定义为一套）
#------------------------------------------------------------------------------
autovacuum = on
autovacuum_max_workers = 6                 # (RESTART)
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_cost_delay = 20ms        # [盘型切换] RAID5 默认温和；SSD 改 10ms
autovacuum_vacuum_cost_limit = 1000        # [盘型切换] RAID5 默认；SSD 改 2000（IO 富余可更激进回收死元组）

idle_in_transaction_session_timeout = 1h  # 事务里空闲最多挂多久（1h）
statement_timeout = 60min                 # 单条语句总执行时间上限

#管理与备份角色不受 statement_timeout 限制（vb_dump、大维护以 vbadmin 跑）
#ALTER ROLE vbadmin SET statement_timeout = 0;
#ALTER ROLE vbadmin SET idle_in_transaction_session_timeout = 0;


#------------------------------------------------------------------------------
# 日志
#------------------------------------------------------------------------------
logging_collector = on                    # (RESTART)
#log_directory = 'pg_log'                  # 默认 PGDATA/pg_log；如改绝对路径在此设
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0600
log_rotation_size = 50MB
log_rotation_age = 1d
log_min_messages = warning

# 
log_min_duration_statement = 10000         # ≥10s 记录；压测期可临时降到 500，压测后恢复
log_connections = on
log_disconnections = on
log_lock_waits = on
log_checkpoints = on                       # 便于检查点/WAL 调参
log_temp_files = 102400                      # ≥100MB 的临时文件；0=全记，-1=禁用
log_statement = 'ddl'                       # 记录所有 DDL
log_line_prefix = '%m [%p] %q%u@%d/%a from %h '
log_timezone = 'Asia/Shanghai'


#------------------------------------------------------------------------------
# 运行统计 / WDR（性能诊断与压测采集依赖，见 §18/§20）
#------------------------------------------------------------------------------
track_activities = on
track_counts = on
enable_instr_track_wait = on
enable_resource_track = on
enable_resource_record = on
instr_unique_sql_count = 10000
track_stmt_stat_level = 'L1,L1'
track_activity_query_size = 4096           # (RESTART)
enable_wdr_snapshot = on
wdr_snapshot_interval = 1h
wdr_snapshot_retention_days = 8


#------------------------------------------------------------------------------
# 本地化 / 格式
#------------------------------------------------------------------------------
datestyle = 'iso, ymd'
timezone = 'Asia/Shanghai'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric  = 'en_US.UTF-8'
lc_time     = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'


#------------------------------------------------------------------------------
# 锁管理
#------------------------------------------------------------------------------
#deadlock_timeout = 1s
lockwait_timeout = 300s                     # 300s(5分钟)对 OLTP 偏长，可减少到120s，暂时保留5min；
                                            # 须 ≥ deadlock_timeout，按业务最长合理持锁时间调整
update_lockwait_timeout = 300s             # 300s(5分钟)对 OLTP 偏长，可减少到120s，暂时保留5min；
#max_locks_per_transaction = 256           # (RESTART) 分区表多/大事务时再上调


#------------------------------------------------------------------------------
# 归档（PITR / 异地备份依赖）
#------------------------------------------------------------------------------
archive_mode = off                          # (RESTART)
archive_timeout = 300                       # 低峰也强制切段，控制 RPO
archive_command = '/vastbase/scripts/archive_wal.sh %p %f'


#------------------------------------------------------------------------------
# 作业调度 / 审计 / 其它
#------------------------------------------------------------------------------
job_queue_processes = 10
audit_enabled = off                        # 按等保/安全基线需要再开启（开启后注意审计盘容量）
pgxc_node_name = 'node1'                    # (RESTART)
license_path = '/vastbase/license/vastbase_license'
vastbase_login_info = off

#==============================================================================
# 上线后必做的两件复核：
#   1. 用 pg_stat_activity 数 state='active' 的真实活跃峰值，回头定 max_connections / 池策略。
#   2. 盯 pg_total_memory_detail 的 dynamic_used_memory / max_dynamic_memory 水位，
#      逼近 max_process_memory 时优先降连接数/活跃并发，而非盲目加 work_mem。
#==============================================================================

```



64G

```conf
#==============================================================================
# VastBase G100 V3.0.8PSU4 — 参数纯净版（64GB 内存 / MySQL(B) 兼容 / 单实例）
#------------------------------------------------------------------------------
# 用途：替换原 postgresql.conf 末尾那段杂乱、重复、值互相冲突的覆盖块。
#       本文件只列“实际下发并生效”的参数，已去重、已纠错、已按 64GB 调优。
#
# 来源：在 32GB 纯净版基础上，仅对“随内存缩放”的参数放大到 64GB 口径；
#       超时策略、日志降噪阈值、连接策略、兼容口径等“策略类”参数原样沿用。
#
# 使用方式：
#   1. 本文件中的值放在 postgresql.conf 末尾即可（后出现的覆盖先出现的）；
#      为避免再次出现“一个参数多处定义”，建议直接用本文件作为唯一覆盖段。
#   2. initdb 在 MySQL(B) 兼容模式下设定的 vb_*/behavior_compat_options 等
#      兼容行为参数【不在本文件内】，保持初始化值不动；改动需做兼容回归测试。
#   3. 标 (RESTART) 的参数改动需重启实例；其余 reload 生效。
#
# 相对 32GB 版的内存类缩放：
#   - shared_buffers          8GB  → 16GB   （≈25% 物理内存）
#   - effective_cache_size    24GB → 48GB   （≈75%）
#   - max_process_memory      20GB → 40GB   （≈62%）
#   - work_mem                32MB → 64MB
#   - maintenance_work_mem    2GB  → 4GB
#   - temp_buffers            32MB → 64MB
#   - wal_buffers             64MB → 128MB
#   - checkpoint_segments     256  → 512    （≈8GB；写多则受益，注意恢复时长/WAL 盘）
#   - autovacuum_max_workers  6    → 8
#   - autovacuum_vacuum_cost_limit 2000 → 4000
#   - max_connections         500  → 800    （64GB 直连上限更高，但仍建议连接池，详见下方）
# 策略类（超时/降噪/连接收口注释/兼容）与 32GB 版一致，未改。
#==============================================================================


#------------------------------------------------------------------------------
# 连接与认证
#------------------------------------------------------------------------------
listen_addresses = '*'                  # (RESTART)
port = 5432                             # (RESTART)

# ★ 待实测后收口 ★
# 64GB 服务器的安全直连上限约 800–1000（每个后端常驻约 5MB，800 连接≈4GB，
# 叠加 shared_buffers 16GB ≈ 20GB，对 64GB 健康）。
# 现状是 8 个项目各开 300 池 = 2400；即便 64GB，2400 直连且高活跃仍偏险
# （2400×5MB≈12GB 常驻 + 16GB shared_buffers ≈ 28GB，叠加查询 work_mem 突发易逼近上限）。
# 真正的约束是“活跃并发”：活跃排序/hash 并发 × work_mem ≤ 物理内存 × 25%(=16GB)，
# work_mem=64MB 时活跃上限约 250。故仍按真实活跃峰值收口：
#   方案A：每个项目池 maxPoolSize 降到 60–100（8×80≈640），max_connections 设 800；
#   方案B：前置 PgBouncer(transaction)，2400 逻辑连接→150~200 物理后端，max_connections 设 300；
#   方案C：确需 2400 高活跃直连 → 需再评估内存/CPU，并考虑线程池。
# 上线前先用 800 起步，按 pg_stat_activity 里 state='active' 峰值回收。
# select count(1) from pg_stat_activity where state='active';
# select * from pg_stat_activity where state='active';
# 备选：openGauss 线程池 enable_thread_pool=on 可让连接与线程解耦、缓解高连接开销，
#       但需厂家配合按核数规划 thread_pool_attr，本版上线前务必小并发验证，故此处不默认开启。
max_connections = 800                   # (RESTART)
sysadmin_reserved_connections = 10      # (RESTART) 保留 DBA 应急连接

password_encryption_type = 1            # 0=md5(PG) 1=sha256+md5 2=sha256；保持 1
username_check_enabled = on

# 空闲会话超时：与连接池共存时，过短会导致池内空闲连接被服务端断开、引发池抖动。
# 默认禁用；若安全基线要求启用，请同时在应用池配置 keepalive/testOnIdle 并取较大值。
session_timeout = 0                     # 0=禁用；启用示例 30min


#------------------------------------------------------------------------------
# 内存
#------------------------------------------------------------------------------
shared_buffers = 16GB                    # (RESTART) ≈25% 物理内存
effective_cache_size = 48GB              # ≈75% 物理内存；仅供优化器估算，不实际分配
max_process_memory = 40GB                # (RESTART) 实例总动态内存上限(≈62%)，余量留给 OS/page cache
enable_memory_limit = on                # 保持开启：超限时查询报错而非内核 OOM

work_mem = 64MB                          # 单算子内存；出现大量临时文件且活跃并发不高时再评估上调
                                         # 经验上限：活跃并发 × work_mem ≤ 物理内存 × 25%(=16GB)，约 250
maintenance_work_mem = 4GB               # VACUUM / CREATE INDEX / 导入
temp_buffers = 64MB

cstore_buffers = 16MB                    # 列存缓冲；行存 OLTP 调到最小即可
bulk_write_ring_size = 256MB             # 批量装载环形缓冲；有大批量 COPY 再上调
max_prepared_transactions = 0            # (RESTART) 不用 XA/两阶段提交则设 0，省共享内存；用到再设 200


#------------------------------------------------------------------------------
# WAL
#------------------------------------------------------------------------------
wal_level = hot_standby                  # (RESTART) 预留主备能力
fsync = on
full_page_writes = off                   # 与下面 enable_double_write=on + 增量检查点配套，
                                         # 由 double-write 防 torn page，是本内核的正确组合，勿误开
enable_double_write = on
wal_log_hints = on
wal_buffers = 128MB                       # (RESTART)
synchronous_commit = on
advance_xlog_file_num = 10
vb_wal_directory = 'pg_xlog'             # (RESTART)


#------------------------------------------------------------------------------
# 检查点
# 注意：本内核(openGauss/PG9.2.4 血统)用 checkpoint_segments，没有 max_wal_size。
#------------------------------------------------------------------------------
enable_incremental_checkpoint = on
incremental_checkpoint_timeout = 60s
checkpoint_segments = 512                 # ×16MB ≈ 8GB；写入高峰检查点过频可上调，注意恢复时长/WAL 盘容量
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
checkpoint_warning = 5min
checkpoint_wait_timeout = 60s
pagewriter_sleep = 5ms


#------------------------------------------------------------------------------
# 复制（单实例暂不启用，参数预置便于将来搭备）
# 注意：本内核用 wal_keep_segments（段数），没有 PG13 的 wal_keep_size。
#------------------------------------------------------------------------------
max_wal_senders = 4                       # (RESTART)
max_replication_slots = 8
wal_keep_segments = 16                    # 将来搭主备时按需上调（256 ≈ 4GB）
hot_standby = on                          # (RESTART)
enable_stream_replication = on
enable_xlog_prune = off                   # 防止备库未连接时 WAL 被过早清理


#------------------------------------------------------------------------------
# 查询优化（OLTP 起步）
#------------------------------------------------------------------------------
query_dop = 1                             # 单查询并行度；OLAP/报表场景再按需上调
enable_mergejoin = on
enable_nestloop = on
enable_hashjoin = on
enable_bitmapscan = on
enable_codegen = off                      # LLVM；OLTP 收益有限，保持关闭
#default_statistics_target = 100          # 计划不稳/复杂查询多时上调后重新 ANALYZE（64GB 可评估 300）


#------------------------------------------------------------------------------
# 磁盘类型相关（★ 按实际盘型二选一，部署前务必确认 ★）
# 以下为优化器 I/O 成本/预取参数，与盘型强相关、与内存无关，32G/64G 取值相同。
# 默认启用【SAS 10k RAID5 / 旋转盘】安全值；若实际是 SSD/NVMe，注释这两行、改用下方 SSD 组。
# 误用风险不对称：旋转盘上若错配 SSD 的低 random_page_cost，会诱导优化器过度走随机访问，
# 慢盘上计划更糟；故默认取旋转盘安全值，SSD 为显式 opt-in。
#------------------------------------------------------------------------------
seq_page_cost = 1.0                       # 顺序扫描成本基准，两种盘都用 1.0
# —— SAS 10k RAID5 / 旋转盘（默认启用）——
random_page_cost = 4.0                    # [盘型切换] 旋转盘随机寻道贵，保持默认
effective_io_concurrency = 4              # [盘型切换] ≈ RAID5 数据盘块数(总盘数-1)，常见 2–6，按实际阵列填
# —— SSD / NVMe（如用 SSD：注释上面两行，启用下面两行）——
#random_page_cost = 1.1                   # [盘型切换] SSD 随机≈顺序，降到接近 1
#effective_io_concurrency = 200           # [盘型切换] SSD 高并发预取；NVMe 可更高
#
# ─────── RAID5 写放大降压（本版 openGauss/增量检查点 语义，非原生 PG9.2 口径）───────
# 约定：凡标 [盘型切换] 的行都按同一盘型取舍；可 `grep 盘型切换` 一次性核对全文。
# 默认盘型=RAID5，故下方 autovacuum 段 cost 两行也已默认取 RAID5 温和值（同样标 [盘型切换]）。
#
# 第①层 确定执行（RAID5）：autovacuum 调温和，直接限制 vacuum 的 IO 强度 —— 见下方 autovacuum 段。
#
# 第②层 验证后按需（先测再调，不盲设值）：
#   · pagewriter_sleep：本版 enable_incremental_checkpoint=on，脏页下刷由 pagewriter 线程负责
#     （非原生 PG 的 bgwriter）。当前 5ms 偏激进，RAID5 上频繁小随机写会被校验写惩罚放大；
#     若观测阵列被检查点/pagewriter IO 打满，再测试放宽到 50–100ms。
#   · bgwriter_lru_maxpages / bgwriter_delay：增量检查点开启后其作用被 pagewriter 大幅接管，
#     照搬 PG 的 400/200ms 未必生效；先用下方 SQL 确认本版语义再决定是否动。
#   · 评估手段：高峰/压测看 pg_stat_bgwriter 与 WDR 报告的 checkpoint/IO 段，按实测调。
#
# 第③层 不建议（破除“WAL 三件套”误区）：
#   · commit_delay/commit_siblings/wal_writer_delay 主要作用于“异步提交”的 WAL 节奏；
#     本配置 synchronous_commit=on，收益有限，不为“凑齐”而设。
#   · RAID5 上 WAL 真正有效的是物理隔离：pg_xlog 与归档分到独立物理盘/阵列；
#     wal_buffers 已设 128MB，足够，不必再加。
#   · 写密集型库本不宜用 RAID5，条件允许优先 RAID10。
#
# ── 下发前先跑这段，确认每个参数“本版是否存在 + 单位/语义 + 是否需重启” ──
#    缺失的参数不会返回；context=sighup 可 reload，postmaster 需重启。
# SELECT name, setting, unit, context, min_val, max_val, boot_val
#   FROM pg_settings
#  WHERE name IN (
#    'random_page_cost','effective_io_concurrency','seq_page_cost',
#    'autovacuum_vacuum_cost_delay','autovacuum_vacuum_cost_limit','autovacuum_max_workers',
#    'pagewriter_sleep','enable_incremental_checkpoint','incremental_checkpoint_timeout',
#    'bgwriter_delay','bgwriter_lru_maxpages','bgwriter_lru_multiplier',
#    'checkpoint_completion_target','checkpoint_timeout',
#    'commit_delay','commit_siblings','wal_writer_delay','synchronous_commit','wal_buffers')
#  ORDER BY name;
# ──────────────────────────────────────────────────────────────────────────


#------------------------------------------------------------------------------
# autovacuum（已合并原三套冲突定义为一套）
#------------------------------------------------------------------------------
autovacuum = on
autovacuum_max_workers = 8                 # (RESTART)
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_cost_delay = 20ms        # [盘型切换] RAID5 默认温和；SSD 改 10ms
autovacuum_vacuum_cost_limit = 1000        # [盘型切换] RAID5 默认；SSD 改 4000（IO 富余可更激进回收死元组）

idle_in_transaction_session_timeout = 1h  # 事务里空闲最多挂多久（1h）
statement_timeout = 60min                 # 单条语句总执行时间上限

#管理与备份角色不受 statement_timeout 限制（vb_dump、大维护以 vbadmin 跑）
#ALTER ROLE vbadmin SET statement_timeout = 0;
#ALTER ROLE vbadmin SET idle_in_transaction_session_timeout = 0;


#------------------------------------------------------------------------------
# 日志
#------------------------------------------------------------------------------
logging_collector = on                    # (RESTART)
#log_directory = 'pg_log'                  # 默认 PGDATA/pg_log；如改绝对路径在此设
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0600
log_rotation_size = 50MB
log_rotation_age = 1d
log_min_messages = warning

# 
log_min_duration_statement = 10000         # ≥10s 记录；压测期可临时降到 500，压测后恢复
log_connections = on
log_disconnections = on
log_lock_waits = on
log_checkpoints = on                       # 便于检查点/WAL 调参
log_temp_files = 102400                      # ≥100MB 的临时文件；0=全记，-1=禁用
log_statement = 'ddl'                       # 记录所有 DDL
log_line_prefix = '%m [%p] %q%u@%d/%a from %h '
log_timezone = 'Asia/Shanghai'


#------------------------------------------------------------------------------
# 运行统计 / WDR（性能诊断与压测采集依赖，见 §18/§20）
#------------------------------------------------------------------------------
track_activities = on
track_counts = on
enable_instr_track_wait = on
enable_resource_track = on
enable_resource_record = on
instr_unique_sql_count = 10000
track_stmt_stat_level = 'L1,L1'
track_activity_query_size = 4096           # (RESTART)
enable_wdr_snapshot = on
wdr_snapshot_interval = 1h
wdr_snapshot_retention_days = 8


#------------------------------------------------------------------------------
# 本地化 / 格式
#------------------------------------------------------------------------------
datestyle = 'iso, ymd'
timezone = 'Asia/Shanghai'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric  = 'en_US.UTF-8'
lc_time     = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'


#------------------------------------------------------------------------------
# 锁管理
#------------------------------------------------------------------------------
#deadlock_timeout = 1s
lockwait_timeout = 300s                     # 300s(5分钟)对 OLTP 偏长，可减少到120s，暂时保留5min；
                                            # 须 ≥ deadlock_timeout，按业务最长合理持锁时间调整
update_lockwait_timeout = 300s             # 300s(5分钟)对 OLTP 偏长，可减少到120s，暂时保留5min；
#max_locks_per_transaction = 256           # (RESTART) 分区表多/大事务时再上调


#------------------------------------------------------------------------------
# 归档（PITR / 异地备份依赖）
#------------------------------------------------------------------------------
archive_mode = off                          # (RESTART)
archive_timeout = 300                       # 低峰也强制切段，控制 RPO
archive_command = '/vastbase/scripts/archive_wal.sh %p %f'


#------------------------------------------------------------------------------
# 作业调度 / 审计 / 其它
#------------------------------------------------------------------------------
job_queue_processes = 10
audit_enabled = off                        # 按等保/安全基线需要再开启（开启后注意审计盘容量）
pgxc_node_name = 'node1'                    # (RESTART)
license_path = '/vastbase/license/vastbase_license'
vastbase_login_info = off

#==============================================================================
# 上线后必做的两件复核：
#   1. 用 pg_stat_activity 数 state='active' 的真实活跃峰值，回头定 max_connections / 池策略。
#   2. 盯 pg_total_memory_detail 的 dynamic_used_memory / max_dynamic_memory 水位，
#      逼近 max_process_memory(40GB) 时优先降连接数/活跃并发，而非盲目加 work_mem。
#==============================================================================

```



#### 6.9.1 32G 纯净版参数列表

```conf
#32G
listen_addresses = '*'
port = 5432
max_connections = 1000
sysadmin_reserved_connections = 10
password_encryption_type = 1
username_check_enabled = on
session_timeout = 0
shared_buffers = 8GB
effective_cache_size = 24GB
max_process_memory = 20GB
enable_memory_limit = on
work_mem = 32MB
maintenance_work_mem = 2GB
temp_buffers = 32MB
cstore_buffers = 16MB
bulk_write_ring_size = 256MB
max_prepared_transactions = 0
max_parallel_workers = 8
max_parallel_workers_per_gather = 0
wal_level = hot_standby
fsync = on
full_page_writes = off
enable_double_write = on
wal_log_hints = on
wal_buffers = 64MB
synchronous_commit = on
advance_xlog_file_num = 10
vb_wal_directory = 'pg_xlog'
enable_incremental_checkpoint = on
incremental_checkpoint_timeout = 60s
checkpoint_segments = 256
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
checkpoint_warning = 5min
checkpoint_wait_timeout = 60s
pagewriter_sleep = 5ms
max_wal_senders = 4
max_replication_slots = 8
wal_keep_segments = 16
hot_standby = on
enable_stream_replication = on
enable_xlog_prune = off
query_dop = 1
enable_mergejoin = on
enable_nestloop = on
enable_hashjoin = on
enable_bitmapscan = on
enable_codegen = off
seq_page_cost = 1.0
random_page_cost = 4.0
effective_io_concurrency = 4
autovacuum = on
autovacuum_max_workers = 6
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_cost_delay = 20ms
autovacuum_vacuum_cost_limit = 1000
idle_in_transaction_session_timeout = 1h
statement_timeout = 60min
logging_collector = on
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0600
log_rotation_size = 50MB
log_rotation_age = 1d
log_min_messages = warning
log_min_duration_statement = 10000
log_connections = on
log_disconnections = on
log_lock_waits = on
log_checkpoints = on
log_temp_files = 102400
log_statement = 'ddl'
log_line_prefix = '%m [%p] %q%u@%d/%a from %h '
log_timezone = 'Asia/Shanghai'
track_activities = on
track_counts = on
enable_instr_track_wait = on
enable_resource_track = on
enable_resource_record = on
instr_unique_sql_count = 10000
track_stmt_stat_level = 'L1,L1'
track_activity_query_size = 4096
enable_wdr_snapshot = on
wdr_snapshot_interval = 1h
wdr_snapshot_retention_days = 8
datestyle = 'iso, ymd'
timezone = 'Asia/Shanghai'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric  = 'en_US.UTF-8'
lc_time     = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'
lockwait_timeout = 300s
update_lockwait_timeout = 300s
archive_mode = off
archive_timeout = 300
archive_command = '/vastbase/scripts/archive_wal.sh %p %f'
job_queue_processes = 10
audit_enabled = off
pgxc_node_name = 'node1'
license_path = '/vastbase/license/vastbase_license'
vastbase_login_info = off
```



#### 6.9.2 64G 纯净版参数列表

```conf
#64g
listen_addresses = '*'
port = 5432
max_connections = 2000
sysadmin_reserved_connections = 10
password_encryption_type = 1
username_check_enabled = on
session_timeout = 0
shared_buffers = 16GB
effective_cache_size = 48GB
max_process_memory = 40GB
enable_memory_limit = on
work_mem = 64MB
maintenance_work_mem = 4GB
temp_buffers = 64MB
cstore_buffers = 16MB
bulk_write_ring_size = 256MB
max_prepared_transactions = 0
max_parallel_workers = 16
max_parallel_workers_per_gather = 0
wal_level = hot_standby
fsync = on
full_page_writes = off
enable_double_write = on
wal_log_hints = on
wal_buffers = 128MB
synchronous_commit = on
advance_xlog_file_num = 10
vb_wal_directory = 'pg_xlog'
enable_incremental_checkpoint = on
incremental_checkpoint_timeout = 60s
checkpoint_segments = 512
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
checkpoint_warning = 5min
checkpoint_wait_timeout = 60s
pagewriter_sleep = 5ms
max_wal_senders = 4
max_replication_slots = 8
wal_keep_segments = 16
hot_standby = on
enable_stream_replication = on
enable_xlog_prune = off
query_dop = 1
enable_mergejoin = on
enable_nestloop = on
enable_hashjoin = on
enable_bitmapscan = on
enable_codegen = off
seq_page_cost = 1.0
random_page_cost = 4.0
effective_io_concurrency = 4
autovacuum = on
autovacuum_max_workers = 8
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_cost_delay = 20ms
autovacuum_vacuum_cost_limit = 1000
idle_in_transaction_session_timeout = 1h
statement_timeout = 60min
logging_collector = on
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0600
log_rotation_size = 50MB
log_rotation_age = 1d
log_min_messages = warning
log_min_duration_statement = 10000
log_connections = on
log_disconnections = on
log_lock_waits = on
log_checkpoints = on
log_temp_files = 102400
log_statement = 'ddl'
log_line_prefix = '%m [%p] %q%u@%d/%a from %h '
log_timezone = 'Asia/Shanghai'
track_activities = on
track_counts = on
enable_instr_track_wait = on
enable_resource_track = on
enable_resource_record = on
instr_unique_sql_count = 10000
track_stmt_stat_level = 'L1,L1'
track_activity_query_size = 4096
enable_wdr_snapshot = on
wdr_snapshot_interval = 1h
wdr_snapshot_retention_days = 8
datestyle = 'iso, ymd'
timezone = 'Asia/Shanghai'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric  = 'en_US.UTF-8'
lc_time     = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'
lockwait_timeout = 300s
update_lockwait_timeout = 300s
archive_mode = off
archive_timeout = 300
archive_command = '/vastbase/scripts/archive_wal.sh %p %f'
job_queue_processes = 10
audit_enabled = off
pgxc_node_name = 'node1'
license_path = '/vastbase/license/vastbase_license'
vastbase_login_info = off
```



## 7. 客户端访问与认证配置（pg_hba.conf）

`$PGDATA/pg_hba.conf` 控制谁能从哪里、用什么方式连接。VastBase 默认使用 `sha256` 认证。

### 7.1 推荐条目

```conf
# TYPE   DATABASE   USER     ADDRESS            METHOD
local    all        all                         sha256
host     all        all      127.0.0.1/32       sha256
host     all        all      ::1/128            sha256

# 业务网段（按实际改）
host     appdb      appuser  192.168.10.0/24    sha256

# 运维跳板机
host     all        vbadmin  192.168.20.10/32   sha256

# 主备复制（如启用）
host     replication repuser 192.168.10.12/32   sha256
```

### 7.2 应用

```bash
$VB_CTL reload -D $PGDATA
```

> 安全建议：业务密码强度 ≥ 12 位，含大小写+数字+符号；禁止使用 `trust` 方式开放给非本机。

---

## 8. 创建数据库、表空间与用户

以下命令通过 `vsql/gsql` 客户端执行（按实际安装包命令选择）：

**注意**：VastBase G100（openGauss 内核）和原生 PostgreSQL 的一个典型差异:**普通用户默认对 `public` schema 没有 CREATE 权限**。即使 `admin_center` 是数据库的 owner,它也不拥有该库里的 `public` schema——`public` 属于初始管理员用户,出于三权分立/安全加固的考虑,普通用户默认只能读不能建

**解决方法:用管理员账号(如 vastbase)连接到 `jobs_server` 这个库**(注意 schema 权限是库级别的,必须连到目标库再授权,连在 vastbase/postgres 库里执行是无效的):

```bash
$VB_SQL -d postgres -p 5432 -U vbadmin

create user jobs_server connection limit -1 password 'Authxuser123';
create tablespace jobs_server owner jobs_server location '/data/tbs/jobs_server';
create database jobs_server with owner jobs_server tablespace jobs_server ENCODING 'UTF8';
alter user jobs_server superuser;
#\c jobs_server vbadmin
#GRANT USAGE, CREATE ON SCHEMA public TO jobs_server;
#ALTER SCHEMA public OWNER TO jobs_server;
#CREATE SCHEMA 
#\c jobs_server jobs_server
#CREATE SCHEMA jobs_server AUTHORIZATION jobs_server;
#ALTER DATABASE jobs_server SET search_path = jobs_server, public;

#vsql -d jobs_server -U postgres
ALTER USER jobs_server SET search_path = jobs_server, public;


create user jobs_server connection limit -1 password 'Authxuser123';
create tablespace tbs_jobs_server relative location 'tbs_jobs_server';
create database jobs_server with owner jobs_server tablespace tbs_jobs_server encoding 'UTF8';
alter user jobs_server superuser;
#\c jobs_server jobs_server
#CREATE SCHEMA jobs_server AUTHORIZATION jobs_server;
#ALTER DATABASE jobs_server SET search_path = jobs_server, public;

#\c jobs_server vbadmin
#GRANT USAGE, CREATE ON SCHEMA public TO jobs_server;
#ALTER SCHEMA public OWNER TO jobs_server;

```

### 8.1 创建表空间（数据/索引分离）

```sql
-- 使用 RELATIVE LOCATION 时，VastBase 会在 $PGDATA/pg_location/ 下维护相对表空间目录。
-- 不需要手工 mkdir /vastbase/data/tbs_app_data；创建后可在 $PGDATA/pg_location/ 下核对。
-- 手工指定目录时，不能使用$PGDATA目录，必须另外新建目录，比如/data等

CREATE TABLESPACE tbs_app_data
    RELATIVE LOCATION 'tbs_app_data';

CREATE TABLESPACE tbs_app_idx
    RELATIVE LOCATION 'tbs_app_idx';
```

> RELATIVE LOCATION 表示相对于 `$PGDATA/pg_location/` 的子目录，VastBase 会按表空间定义维护目录和 `pg_tblspc` 映射；不要误以为会落在 `$PGDATA/tbs_app_data`。

### 8.2 创建业务数据库（MySQL 兼容）

```sql
CREATE DATABASE appdb
    WITH OWNER = vbadmin
    ENCODING  = 'UTF8'
    LC_COLLATE= 'en_US.UTF-8'
    LC_CTYPE  = 'en_US.UTF-8'
    TEMPLATE  = template0
    CONNECTION LIMIT = 200;
    
    -- DBCOMPATIBILITY = 'B'        -- 关键：B = MySQL 兼容；必须与实例初始化兼容模式一致
    
```

> VastBase 的 `ENCODING='UTF8'` 属于完整 UTF-8 编码，覆盖 MySQL `utf8mb4` 的 4 字节字符范围，可存储 emoji 与 4 字节生僻字。迁移时真正需要单独评估的是：字段比较/排序所用 collation 在 B 模式下的可用对照，以及应用是否依赖 MySQL `utf8mb4_general_ci`、`utf8mb4_unicode_ci`、`utf8mb4_0900_ai_ci` 等大小写/重音不敏感比较行为。`lower_case_table_names` 影响对象名大小写，不等同于数据比较大小写不敏感；数据比较应通过列级 `COLLATE`、应用 SQL 回归与 `vastbase_sql_mode` 配合验证。



### 8.3 创建业务用户（角色）

```sql
-- 应用账号：业务读写，禁止超级权限
CREATE USER appuser
    WITH PASSWORD 'Appuser@2026'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    LOGIN
    CONNECTION LIMIT 100;

-- 投产时按客户口令策略计算到期日，并纳入 §16 口令轮换提醒；不要照抄固定日期。
-- 示例：ALTER USER appuser VALID UNTIL '<YYYY-MM-DD>';

-- 只读账号：报表/查询
CREATE USER rouser
    WITH PASSWORD 'Rouser@2026'
    NOSUPERUSER
    NOCREATEDB
    LOGIN
    CONNECTION LIMIT 30;
```

### 8.4 切换到 appdb 创建 schema 并授权

```sql
#以下账户在执行sql时都会提示没权限ERROR:  Permission denied.：ALTER USER appuser SET search_path = app, public; 
#\c appdb appuser
#\c appdb vbadmin

\c appdb vastbase

-- 创建业务 schema。MySQL 迁移场景下，可将源库名/业务域映射为 schema，便于权限隔离。
CREATE SCHEMA app AUTHORIZATION appuser;

-- 设置默认 schema 检索顺序，应用可直接访问 t_order，也可显式使用 app.t_order。
ALTER USER appuser SET search_path = app, public;
ALTER USER rouser  SET search_path = app, public;

ALTER USER question_feedback IN DATABASE question_feedback
SET search_path = question_feedback, public;

-- 库级权限
GRANT CONNECT ON DATABASE appdb TO appuser, rouser;

-- 表空间使用权
GRANT CREATE ON TABLESPACE tbs_app_data TO appuser;
GRANT CREATE ON TABLESPACE tbs_app_idx  TO appuser;

-- schema 权限
GRANT USAGE  ON SCHEMA app TO appuser, rouser;
GRANT CREATE ON SCHEMA app TO appuser;

-- 现有对象权限
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA app TO appuser;
GRANT USAGE, SELECT                  ON ALL SEQUENCES IN SCHEMA app TO appuser;
GRANT SELECT                          ON ALL TABLES   IN SCHEMA app TO rouser;

-- 未来新建对象的默认权限
-- 注意：ALTER DEFAULT PRIVILEGES 只作用于“指定创建者”后续创建的对象。
-- 生产业务 DDL 通常由 appuser 执行，因此必须显式写 FOR ROLE appuser。
ALTER DEFAULT PRIVILEGES FOR ROLE appuser IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO appuser;
ALTER DEFAULT PRIVILEGES FOR ROLE appuser IN SCHEMA app
    GRANT SELECT                         ON TABLES TO rouser;
ALTER DEFAULT PRIVILEGES FOR ROLE appuser IN SCHEMA app
    GRANT USAGE, SELECT                  ON SEQUENCES TO appuser;

-- 如果现场由 vbadmin 执行业务 DDL，再为 vbadmin 补一份同样的默认授权。
-- ALTER DEFAULT PRIVILEGES FOR ROLE vbadmin IN SCHEMA app
--     GRANT SELECT ON TABLES TO rouser;
```

### 8.5 建表示例（MySQL 风格语法 + 指定表空间）

> 前置条件：本节示例依赖 §4.4/§6.7 中 `b_compatibility_mode=on`、`explicit_defaults_for_timestamp=on` 等关键参数已生效，尤其 `ON UPDATE CURRENT_TIMESTAMP(6)` 不要脱离参数基线单独复制。

```sql
\c appdb appuser

CREATE TABLE app.t_order (
    order_id    BIGINT        NOT NULL AUTO_INCREMENT,
    user_id     BIGINT        NOT NULL,
    amount      DECIMAL(18,2) NOT NULL,
    status      VARCHAR(20)   DEFAULT 'INIT',
    create_time TIMESTAMP(6)  DEFAULT CURRENT_TIMESTAMP(6),
    update_time TIMESTAMP(6)  DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_t_order PRIMARY KEY (order_id) USING INDEX TABLESPACE tbs_app_idx
) TABLESPACE tbs_app_data;

CREATE INDEX idx_t_order_userid ON app.t_order(user_id) TABLESPACE tbs_app_idx;

COMMENT ON TABLE  app.t_order IS '订单表';
COMMENT ON COLUMN app.t_order.order_id IS '订单ID，自增主键';
```

> MySQL 兼容模式可解析部分 MySQL DDL 语法，例如 `AUTO_INCREMENT`、`COMMENT`、`KEY/INDEX`、`ENGINE`、`CHARSET`、`ON UPDATE CURRENT_TIMESTAMP` 等。涉及存储引擎、字符集和排序规则的语法兼容不等于存储行为完全一致，生产迁移前仍需用真实 DDL 做兼容验证。

---



### 8.6 创建生产库

服务器一块磁盘模式

```sql
create user platform_openapi connection limit -1 password 'Authxuser123';
create tablespace tbs_platform_openapi relative location 'tbs_platform_openapi';
create database platform_openapi with owner platform_openapi tablespace tbs_platform_openapi encoding 'UTF8';

\c platform_openapi platform_openapi
create schema platform_openapi authorization platform_openapi;
ALTER DATABASE platform_openapi SET search_path = platform_openapi;

create user authx_service connection limit -1 password 'Authxuser123';
create tablespace tbs_authx_service relative location 'tbs_authx_service';
create database authx_service with owner authx_service tablespace tbs_authx_service encoding 'UTF8';
alter user authx_service superuser;

create user cas_server connection limit -1 password 'Authxuser123';
create tablespace tbs_cas_server relative location 'tbs_cas_server';
create database cas_server with owner cas_server tablespace tbs_cas_server encoding 'UTF8';
alter user cas_server superuser;

create user jobs_server connection limit -1 password 'Authxuser123';
create tablespace tbs_jobs_server relative location 'tbs_jobs_server';
create database jobs_server with owner jobs_server tablespace tbs_jobs_server encoding 'UTF8';
alter user jobs_server superuser;

#\c jobs_server vbadmin
#GRANT USAGE, CREATE ON SCHEMA public TO jobs_server;
#ALTER SCHEMA public OWNER TO jobs_server;

create user admin_center connection limit -1 password 'Authxuser123';
create tablespace tbs_admin_center relative location 'tbs_admin_center';
create database admin_center with owner admin_center tablespace tbs_admin_center encoding 'UTF8';
alter user admin_center superuser;

#\c admin_center vbadmin
#GRANT USAGE, CREATE ON SCHEMA public TO admin_center;
#ALTER SCHEMA public OWNER TO admin_center;

create user message connection limit -1 password 'Authxuser123';
create tablespace tbs_message relative location 'tbs_message';
create database message with owner message tablespace tbs_message encoding 'UTF8';
alter user message superuser;

create user transaction_service connection limit -1 password 'Authxuser123';
create tablespace tbs_transaction relative location 'tbs_transaction';
create database transaction_service with owner transaction_service tablespace tbs_transaction encoding 'UTF8';
alter user transaction_service superuser;

create user data_view connection limit -1 password 'Authxuser123';
create tablespace tbs_data_view relative location 'tbs_data_view';
create database data_view with owner data_view tablespace tbs_data_view encoding 'UTF8';
alter user data_view superuser;

create user formflow connection limit -1 password 'Authxuser123';
create tablespace tbs_formflow relative location 'tbs_formflow';
create database formflow with owner formflow tablespace tbs_formflow encoding 'UTF8';
alter user formflow superuser;
#\c formflow vbadmin
#GRANT USAGE, CREATE ON SCHEMA public TO formflow;
#ALTER SCHEMA public OWNER TO formflow;

#vsql -d formflow postgres
ALTER USER formflow SET search_path = formflow, public;

#vsql -d formflow -U formflow
ALTER DATABASE formflow SET search_path = formflow, public;

create user fileupload connection limit -1 password 'Authxuser123';
create tablespace tbs_fileupload relative location 'tbs_fileupload';
create database fileupload with owner fileupload tablespace tbs_fileupload encoding 'UTF8';
alter user fileupload superuser;
create schema fileupload authorization fileupload;
ALTER DATABASE fileupload SET search_path = fileupload;

create user powerjob connection limit -1 password 'Authxuser123';
create tablespace tbs_powerjob relative location 'tbs_powerjob';
create database powerjob with owner powerjob tablespace tbs_powerjob encoding 'UTF8';
alter user powerjob superuser;
create schema powerjob authorization powerjob;
ALTER DATABASE powerjob SET search_path = powerjob;


create user portal connection limit -1 password 'Authxuser123';
create tablespace tbs_portal relative location 'tbs_portal';
create database portal with owner portal tablespace tbs_portal encoding 'UTF8';
alter user portal superuser;

create user datacenter connection limit -1 password 'DataCenter961';
create tablespace tbs_datacenter relative location 'tbs_datacenter';
create database datacenter with owner datacenter tablespace tbs_datacenter encoding 'UTF8';

create user dataassets connection limit -1 password 'Authxuser123';
create tablespace tbs_dataassets relative location 'tbs_dataassets';
create database dataassets with owner dataassets tablespace tbs_dataassets encoding 'UTF8';
alter user dataassets superuser;

create user dataassetszusi connection limit -1 password 'Authxuser123';
create tablespace tbs_dataassetszusi relative location 'tbs_dataassetszusi';
create database dataassetszusi with owner dataassetszusi tablespace tbs_dataassetszusi encoding 'UTF8';
alter user dataassetszusi superuser;

create user reservation connection limit -1 password 'Authxuser123';
create tablespace tbs_reservation relative location 'tbs_preservation';
create database reservation with owner reservation tablespace tbs_reservation encoding 'UTF8';
#\c reservation vbadmin
#GRANT USAGE, CREATE ON SCHEMA public TO reservation;
#ALTER SCHEMA public OWNER TO reservation;
alter user reservation superuser;
#\c reservation reservation
#CREATE SCHEMA reservation AUTHORIZATION reservation;
#ALTER DATABASE reservation SET search_path = reservation, public;

create user question_feedback connection limit -1 password 'Authxuser123';
create tablespace tbs_question_feedback relative location 'tbs_question_feedback';
create database question_feedback with owner question_feedback tablespace tbs_question_feedback encoding 'UTF8';
#\c question_feedback vbadmin
#GRANT USAGE, CREATE ON SCHEMA public TO question_feedback;
#ALTER SCHEMA public OWNER TO question_feedback;
alter user question_feedback superuser;


create user aihelper connection limit -1 password 'Authxuser123';
create tablespace tbs_aihelper relative location 'tbs_aihelper';
create database aihelper with owner aihelper tablespace tbs_aihelper encoding 'UTF8';
alter user aihelper superuser;

\c aihelper aihelper
CREATE SCHEMA aihelper AUTHORIZATION aihelper;
ALTER DATABASE aihelper SET search_path = aihelper, public;

create user ai_helper connection limit -1 password 'Authxuser123';
create tablespace tbs_ai_helper relative location 'tbs_ai_helper';
create database ai_helper with owner ai_helper tablespace tbs_ai_helper encoding 'UTF8';
alter user ai_helper superuser;

\c ai_helper ai_helper
CREATE SCHEMA ai_helper AUTHORIZATION ai_helper;
ALTER DATABASE ai_helper SET search_path = ai_helper, public;
```

检查search_path

```sql
SELECT * FROM (
  SELECT
    CASE WHEN s.setdatabase = 0 THEN '(all dbs)'
         ELSE (SELECT datname FROM pg_database WHERE oid = s.setdatabase) END AS database,
    CASE WHEN s.setrole = 0 THEN '(all roles)'
         ELSE pg_get_userbyid(s.setrole) END AS role,
    unnest(s.setconfig) AS cfg
  FROM pg_db_role_setting s
) t
WHERE cfg LIKE 'search_path=%'
ORDER BY 1, 2;
```

logs

```sql
  database   |    role     |                cfg                
-------------+-------------+-----------------------------------
 ai_helper   | (all roles) | search_path=ai_helper, public
 aihelper    | (all roles) | search_path="aihelper, public"
 (all dbs)   | appuser     | search_path=app, public
 (all dbs)   | rouser      | search_path=app, public
 fileupload  | (all roles) | search_path=fileupload
 formflow    | (all roles) | search_path="formflow, public"
 powerjob    | (all roles) | search_path=powerjob
 reservation | (all roles) | search_path="reservation, public"
(8 rows)

vastbase=# 
```

单独磁盘挂载数据库的数据

```sql

create user platform_openapi connection limit -1 password 'Authxuser123';

create tablespace platform_openapi owner platform_openapi location '/data/tbs/platform_openapi';

create database platform_openapi with owner platform_openapi tablespace platform_openapi encoding 'UTF8';


create user authx_service connection limit -1 password 'Authxuser123';

create tablespace authx_service owner authx_service location '/data/tbs/authx_service';

create database authx_service with owner authx_service tablespace authx_service encoding 'UTF8';


create user cas_server connection limit -1 password 'Authxuser123';

create tablespace cas_server owner cas_server location '/data/tbs/cas_server';

create database cas_server with owner cas_server tablespace cas_server encoding 'UTF8';


create user jobs_server connection limit -1 password 'Authxuser123';

create tablespace jobs_server owner jobs_server location '/data/tbs/jobs_server';

create database jobs_server with owner jobs_server tablespace jobs_server encoding 'UTF8';


alter user authx_service superuser;

alter user cas_server superuser;

alter user jobs_server superuser;


create user admin_center connection limit -1 password 'Authxuser123';

create tablespace admin_center owner admin_center location '/data/tbs/admin_center';

create database admin_center with owner admin_center tablespace admin_center encoding 'UTF8';




create user message connection limit -1 password 'Authxuser123';

create tablespace message owner message location '/data/tbs/message';

create database message with owner message tablespace message encoding 'UTF8';


create user transaction_service connection limit -1 password 'Authxuser123';

create tablespace transaction_service owner transaction_service location '/data/tbs/transaction_service';

create database transaction_service with owner transaction_service tablespace transaction_service encoding 'UTF8';



create user data_view connection limit -1 password 'Authxuser123';

create tablespace data_view owner data_view location '/data/tbs/data_view';

create database data_view with owner data_view tablespace data_view encoding 'UTF8';


alter user message superuser;

alter user transaction_service superuser;

alter user data_view superuser;



create user formflow connection limit -1 password 'Authxuser123';

create tablespace formflow owner formflow location '/data/tbs/formflow';

create database formflow with owner formflow tablespace formflow encoding 'UTF8';


create user fileupload connection limit -1 password 'Authxuser123';

create tablespace fileupload owner fileupload location '/data/tbs/fileupload';

create database fileupload with owner fileupload tablespace fileupload encoding 'UTF8';


create user powerjob connection limit -1 password 'Authxuser123';

create tablespace powerjob owner powerjob location '/data/tbs/powerjob';

create database powerjob with owner powerjob tablespace powerjob encoding 'UTF8';


alter user formflow superuser;

alter user fileupload superuser;

alter user powerjob superuser;

create schema powerjob_product authorization powerjob;


create user portal connection limit -1 password 'Authxuser123';

create tablespace portal owner portal location '/data/tbs/portal';

create database portal with owner portal tablespace portal encoding 'UTF8';

alter user portal superuser;

create user datacenter connection limit -1 password 'DataCenter961';

create tablespace datacenter owner datacenter location '/data/tbs/datacenter';

create database datacenter with owner datacenter tablespace datacenter encoding 'UTF8';


create user dataassets connection limit -1 password 'Authxuser123';

create tablespace dataassets owner dataassets location '/data/tbs/dataassets';

create database dataassets with owner dataassets tablespace dataassets encoding 'UTF8';

alter user dataassets superuser;




create user dataassetszusi connection limit -1 password 'Authxuser123';

create tablespace dataassetszusi owner dataassetszusi location '/data/tbs/dataassets-zusi';

create database dataassetszusi with owner dataassetszusi tablespace dataassetszusi encoding 'UTF8';

alter user dataassetszusi superuser;

```



### 8.7 查询是否系统关键字

#### 8.7.1 查询某个词是不是关键字

例如查 `transaction`：

```sql
SELECT
    word,
    catcode,
    catdesc
FROM pg_catalog.pg_get_keywords()
WHERE lower(word) = lower('transaction');
```

结果判断：

```text
catcode = R  保留关键字，强烈不建议直接用
catcode = U  非保留关键字，通常可以用，但不推荐作为对象名
catcode = C  可作为列名，但有上下文限制
catcode = T  类型名或函数名相关关键字，有上下文限制
无结果      当前版本不认为它是关键字
```

#### 8.7.2 一次性检查用户名/库名

```sql
WITH names(name) AS (
    VALUES
        ('platform_openapi'),
        ('authx_service'),
        ('cas_server'),
        ('jobs_server'),
        ('admin_center'),
        ('message'),
        ('transaction'),
        ('data_view'),
        ('formflow'),
        ('fileupload'),
        ('powerjob'),
        ('portal'),
        ('datacenter'),
        ('dataassets'),
        ('dataassetszusi')
)
SELECT
    n.name,
    k.word,
    k.catcode,
    k.catdesc,
    CASE
        WHEN k.word IS NULL THEN '不是关键字'
        WHEN k.catcode = 'R' THEN '保留关键字，建议改名或加双引号'
        ELSE '非保留/上下文关键字，建议尽量避免'
    END AS check_result
FROM names n
LEFT JOIN pg_catalog.pg_get_keywords() k
       ON lower(k.word) = lower(n.name)
ORDER BY n.name;
```

#### 8.7.3 只查保留关键字

```sql
SELECT
    word,
    catcode,
    catdesc
FROM pg_catalog.pg_get_keywords()
WHERE catcode = 'R'
ORDER BY word;
```

#### 8.7.4 检查某个 schema 下是否已有表名/字段名撞关键字

查表名：

```sql
SELECT
    n.nspname AS schema_name,
    c.relname AS object_name,
    k.catcode,
    k.catdesc
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
JOIN pg_catalog.pg_get_keywords() k
  ON lower(k.word) = lower(c.relname)
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, c.relname;
```

查字段名：

```sql
SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    a.attname AS column_name,
    k.catcode,
    k.catdesc
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c
  ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
JOIN pg_catalog.pg_get_keywords() k
  ON lower(k.word) = lower(a.attname)
WHERE a.attnum > 0
  AND NOT a.attisdropped
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, c.relname, a.attname;
```

#### 8.7.5 针对 `transaction` 的建议

建议你先执行：

```sql
SELECT *
FROM pg_catalog.pg_get_keywords()
WHERE lower(word) = 'transaction';
```

如果查出来是关键字，最好把用户、库、表空间统一改名，例如：

```sql
create user transaction_service connection limit -1 password 'Authxuser123';
create tablespace tbs_transaction_service relative location 'tbs_transaction_service';
create database transaction_service with owner transaction_service tablespace tbs_transaction_service encoding 'UTF8';
alter user transaction_service superuser;
```

不太建议长期使用双引号对象名：

```sql
create user "transaction" connection limit -1 password 'Authxuser123';
```

因为后续所有连接、授权、导入导出、脚本都要保持大小写和双引号一致，维护成本更高。







## 9. MySQL 兼容性验证

B 模式下，VastBase 支持大量 MySQL 语法/函数，以下用于快速验收：

> 前置条件：以下 SQL 至少需要 §4.4/§6.7 关键参数全部生效；例如用户变量依赖 `enable_set_variable_b_format=on`，时间戳自动更新依赖 `b_compatibility_mode=on` 与 `explicit_defaults_for_timestamp=on`。

```sql
\c appdb appuser

-- 1) MySQL 常用元数据语法
SHOW TABLES;
SHOW CREATE TABLE app.t_order;
DESCRIBE app.t_order;
SHOW INDEX FROM app.t_order;

-- 2) AUTO_INCREMENT 与 LAST_INSERT_ID
INSERT INTO app.t_order(user_id, amount, status)
VALUES (99, 199.99, 'INIT');
SELECT LAST_INSERT_ID();

-- 3) LIMIT / OFFSET
SELECT order_id, user_id, amount, status
  FROM app.t_order
 ORDER BY order_id DESC
 LIMIT 10 OFFSET 0;

-- 4) MySQL 常用函数
SELECT IFNULL(NULL, 'X')              AS ifnull_demo,
       CONCAT('Vast', 'Base')         AS concat_demo,
       SUBSTRING('VastBase', 1, 4)    AS substr_demo,
       DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d %H:%i:%s') AS fmt_time;

-- 4.1) V3.0.8PSU4 B 模式时间函数精度回归：默认 timestamp(0)，微秒需显式 (6)
SELECT pg_typeof(CURRENT_TIMESTAMP)      AS default_ts_type,
       pg_typeof(CURRENT_TIMESTAMP(6))   AS micro_ts_type,
       CURRENT_TIMESTAMP(6) - CURRENT_TIMESTAMP(0) AS precision_diff;

-- 5) 用户变量（需 enable_set_variable_b_format=on，按版本确认）
      -- 默认off
SET @min_amount := 100;
SELECT @min_amount AS min_amount;
SELECT * FROM app.t_order WHERE amount >= @min_amount LIMIT 5;

-- 6) MySQL 风格 UPSERT
INSERT INTO app.t_order(order_id, user_id, amount, status)
VALUES (1001, 99, 199.99, 'INIT')
ON DUPLICATE KEY UPDATE amount = VALUES(amount), status = 'UPDATED';

-- 7) REPLACE INTO（会按主键/唯一键替换，生产需注意触发 delete+insert 语义差异）
REPLACE INTO app.t_order(order_id, user_id, amount, status)
VALUES (1002, 88, 299.99, 'REPLACED');

-- 8) 存储过程 CALL 验证
-- 写法 1：B 模式 MySQL 风格。DELIMITER 是 mysql 客户端元命令，不是 SQL；vsql/gsql 不一定支持。
-- 若现场客户端支持，可在迁移测试中验证以下风格；若提示 DELIMITER 不支持，不要直接粘贴执行。
-- DELIMITER //
-- CREATE PROCEDURE app.proc_demo(IN p_id BIGINT)
-- BEGIN
--     SELECT CONCAT('order=', order_id) AS msg
--       FROM app.t_order
--      WHERE order_id = p_id;
-- END//
-- DELIMITER ;

-- 写法 2：vsql/gsql 稳定可执行的 PL/pgSQL 风格，用于部署验收兜底。
CREATE OR REPLACE PROCEDURE app.proc_demo(p_id BIGINT)
LANGUAGE plpgsql AS $$
DECLARE
    v_msg text;
BEGIN
    SELECT 'order=' || order_id INTO v_msg
      FROM app.t_order
     WHERE order_id = p_id;
    RAISE NOTICE '%', v_msg;
END;
$$;
CALL app.proc_demo(1001);
```
## 10. 备份策略（多库逻辑备份 + 异地 rsync 同步）

> 场景：实例中存在一个或多个业务库（示例以 `appdb` 为主，多业务库可追加 `appdb_report`、`appdb_archive` 等），需要 **每库独立逻辑备份**，加上一份全局对象备份；本地保留若干天，并通过 rsync 推送到异地备份服务器 `192.168.100.100`（已经 `ssh-copy-id` 完成免密互信）。

### 10.1 备份架构与目录约定

```
/vastbase/backup/                          ← 本地备份根目录
├── 2026-05-25/                            ← 按日期分目录，rsync 整目录推送
│   ├── appdb_2026-05-25_020001.dump       ← vb_dump/gs_dump 自定义格式（已压缩）
│   ├── appdb_2026-05-25_020001.create.sql ← 建库 DDL：CREATE DATABASE + ALTER DATABASE SET（裸机恢复用）
│   ├── appdb_2026-05-25_020001.manifest   ← 元数据：大小、md5、兼容模式、时间
│   ├── globals_2026-05-25_020130.sql      ← 全局对象（用户/角色/表空间）
│   └── BACKUP.OK                          ← 全部成功后才生成的"哨兵"文件
└── 2026-05-24/
    └── …
```

远端：

```
192.168.100.100:/backup/vbdb01/
├── 2026-05-25/
└── 2026-05-24/
```

设计要点：

- **每库一份独立 dump** —— 便于按库恢复，单库损坏不影响其他库还原。
- **每库一份建库 DDL (`*.create.sql`)** —— 单库自定义格式 dump（`-F c`）与全局对象 dump（`vb_dumpall -g`）都**不含 `CREATE DATABASE` 语句**，全新实例上"建库"这一步是断的。本方案在备份时额外抓取该库的属主、编码、排序规则、表空间、连接数上限与库级 `ALTER DATABASE ... SET` 参数，落盘成 `*.create.sql`，使备份集在裸机/异机上可自洽重建（见 §10.4 与 §11.4）。
- **目录按日期** —— rsync 整目录原子推送，远端按日期天然分版本。
- **manifest 文件** —— 记录文件大小、MD5/SHA256 与数据库兼容模式，恢复脚本可校验。
- **`BACKUP.OK` 哨兵** —— 任何一个子任务失败都不生成，监控只看这一个文件即可判断当日是否完整。
- **自定义压缩格式 (`-F c`)** —— `vb_restore/gs_restore` 可并行恢复、可挑表恢复。

### 10.2 准备工作

#### 10.2.1 创建脚本目录

```bash
# root 用户执行
mkdir -p /vastbase/scripts /vastbase/log/backup
chown -R vastbase:dbgrp /vastbase/scripts /vastbase/log/backup
chmod 750 /vastbase/scripts
```

#### 10.2.2 配置 `.pgpass` 口令文件（vastbase 用户）

口令**只存放在 `~/.pgpass`（权限 600）**，脚本与命令行里不出现任何明文。

> 这里的 `vbadmin` 口令是**本实例自身的属性**，存放在共享系统表 `pg_authid`（实例级、所有库共享），不在任何业务库里；不同机器初始化时各不相同，也**不随逻辑备份导出**（本版 `vb_dumpall -g` 实测甚至不创建 `vbadmin` 角色）。备份/恢复对它的影响、以及跨机恢复时的处置，见 §11.4.1。

```bash
su - vastbase
cat > ~/.pgpass <<'EOF'
# hostname:port:database:username:password
127.0.0.1:5432:*:vbadmin:Vbadmin@2026
EOF
chmod 600 ~/.pgpass
```

> **重要：本机 VastBase G100（基于 openGauss）的 `vsql` / `vb_dump` / `vb_dumpall` 不会自动消费 `.pgpass` / `PGPASSFILE`。**
> 实测表现：即便文件权限、属主、内容、`PGPASSFILE` 都正确，连接仍会回退到交互式 `Password for user ...` 提示，在 cron 下会永久挂起。
> 验证方法（仍提示输入密码即说明本机工具不读 `.pgpass`）：
>
> ```bash
> PGPASSFILE=~/.pgpass vsql -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -c "select 1;" </dev/null
> ```
>
> 因此本方案**不依赖工具内置的 `.pgpass` 机制**，而是由 `backup.env` 中的 `pgpass_lookup()` 按 libpq 规则自行解析 `.pgpass`，再用 VastBase 自带的 `--pipeline`（`vsql` 为 `-2`）经 **stdin** 把口令喂给工具。这样：
>
> - 口令唯一落盘点是 `~/.pgpass`（600），脚本文件、`backup.env`、命令行参数中均无明文；
> - 口令经管道传入，不进入命令行，`ps -ef` / `/proc/<pid>/cmdline` 看不到；
> - 首选不使用 `PGPASSWORD` 环境变量（会通过 `/proc/<pid>/environ` 泄露）；**例外**：个别工具本版不支持 `--pipeline`（实测 `vb_basebackup` 即如此），此时 `vb_basebackup_run` 降级为**子 shell 内**临时 `PGPASSWORD`，口令不进父环境/命令行/`ps` args，仅在该工具进程运行期间存在于其 `/proc/<pid>/environ`（同用户/root 可读），用完随子 shell 销毁——这是无 `--pipeline` 时可接受的最小暴露；
> - 若将来某个补丁版本恢复了对 `.pgpass` 的原生支持，本文件格式完全兼容，可平滑切回。
>
> `.pgpass` 中的 `*` 通配、`#` 注释行、值里的 `\:` 与 `\\` 转义，`pgpass_lookup()` 均按 libpq 语义处理。

#### 10.2.3 验证免密 SSH（指向异地备份服务器）

```bash
su - vastbase
ssh-keygen

ssh-copy-id root@192.168.100.100

ssh -o BatchMode=yes root@192.168.100.100 'echo ok && hostname && mkdir -p /backup/vbdb01'
```

> 如远端用户名不同，请按实际改 `REMOTE_USER`。

**同时确认异地服务器上装了 `rsync`**（rsync 是两端协作的，远端没有可执行文件，同步必然失败——参见 §10.4 故障说明）。务必用**非交互式** SSH 验证（与脚本里 `BatchMode` 的取值环境一致），不要登录后在交互 shell 里 `which rsync`：

```bash
# 关键：非交互式 ssh 取到的 PATH 往往比交互登录窄，要按脚本真实运行的环境验证
ssh -o BatchMode=yes root@192.168.100.100 'command -v rsync || echo RSYNC_MISSING; echo "PATH=$PATH"'
```

> - 输出 `RSYNC_MISSING` —— 远端没装，在异地服务器上 `yum install -y rsync`（麒麟/openEuler 系用 `dnf install -y rsync`）。
> - 能打印出路径（如 `/usr/bin/rsync`）—— 远端已装；把该绝对路径填进 `backup.env` 的 `REMOTE_RSYNC_PATH`（见 §10.3.1），脚本会用 `--rsync-path` 显式指定，绕开非交互式 PATH 的不确定性。

### 10.3 配置文件


#### 10.3.1 `/vastbase/scripts/backup.env`

```bash
#==============================================================================
# backup.env —— VastBase 运维脚本公共配置
# 说明：由 db_backup.sh / db_restore.sh / db_basebackup.sh / monitor.sh 等脚本共同 source
#==============================================================================

# ---- 数据库连接 ----
export PG_HOST=127.0.0.1
export PG_PORT=5432
export PG_USER=vbadmin
export PGPASSFILE=/home/vastbase/.pgpass
export GAUSSHOME=/vastbase/app
export PGDATA=/vastbase/data
export GAUSSLOG=/vastbase/log/gauss
export PATH=$GAUSSHOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:${LD_LIBRARY_PATH:-}

# ---- 【V3.0.8PSU4】工具命令：优先 vb_*，gs_* 仅兜底 ----
_resolve_cmd() {
    local preset="${1:-}"
    shift || true

    if [[ -n "$preset" ]]; then
        if [[ "$preset" == */* ]]; then
            [[ -x "$preset" ]] && { printf '%s\n' "$preset"; return 0; }
        else
            command -v "$preset" 2>/dev/null && return 0
        fi
    fi

    local c
    for c in "$@"; do
        command -v "$c" 2>/dev/null && return 0
    done

    return 1
}

export VB_INITDB="$(_resolve_cmd "${VB_INITDB:-}" vb_initdb gs_initdb || true)"
export VB_SQL="$(_resolve_cmd "${VB_SQL:-}" vsql gsql || true)"
export VB_CTL="$(_resolve_cmd "${VB_CTL:-}" vb_ctl gs_ctl || true)"
export VB_GUC="$(_resolve_cmd "${VB_GUC:-}" vb_guc gs_guc || true)"
export VB_DUMP="$(_resolve_cmd "${VB_DUMP:-}" vb_dump gs_dump || true)"
export VB_DUMPALL="$(_resolve_cmd "${VB_DUMPALL:-}" vb_dumpall gs_dumpall || true)"
export VB_RESTORE="$(_resolve_cmd "${VB_RESTORE:-}" vb_restore gs_restore || true)"
export VB_BASEBACKUP="$(_resolve_cmd "${VB_BASEBACKUP:-}" vb_basebackup gs_basebackup || true)"
# openGauss tar 格式备份包必须用 gs_tar/vb_tar 解（GNU tar 解不了，报 "does not look like a tar archive"）。
# 本版 gs_tar 是 gs_basebackup 的 multi-call 软链；无独立 vb_tar 时回退 gs_tar。
export VB_TAR="$(_resolve_cmd "${VB_TAR:-}" vb_tar gs_tar || true)"

require_cmds() {
    local miss=0 v
    for v in "$@"; do
        if [[ -z "${!v:-}" || ! -x "${!v:-}" ]]; then
            echo "ERROR: required command variable $v is not set or not executable" >&2
            miss=$((miss+1))
        fi
    done
    return $miss
}

# ---- 口令读取与工具封装 ----
# 本机 vsql/vb_dump/vb_dumpall 不消费 .pgpass / PGPASSFILE，故由脚本自行按 libpq 规则
# 解析 .pgpass，并通过 --pipeline（vsql 为 -2）经 stdin 传入口令。
# 口令唯一落盘点是 $PGPASSFILE（权限 600）；脚本、命令行、ps、environ 中均无明文。

_pg_match() { [[ "$1" == "*" || "$1" == "$2" ]]; }

# 在 .pgpass 中按 host:port:database:username 查找口令（支持 * 通配、# 注释、\: \\ 转义）。
# 用法: pw=$(pgpass_lookup "$PG_HOST" "$PG_PORT" "$db" "$PG_USER")
pgpass_lookup() {
    local want_host="$1" want_port="$2" want_db="$3" want_user="$4"
    local f="${PGPASSFILE:-$HOME/.pgpass}"
    [[ -f "$f" ]] || { echo "pgpass not found: $f" >&2; return 1; }
    local perm; perm=$(stat -c '%a' "$f" 2>/dev/null)
    [[ "$perm" == "600" || "$perm" == "400" ]] \
        || { echo "insecure perm on $f: ${perm:-?} (need 600)" >&2; return 1; }

    local line fields cur ch i esc
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        fields=(); cur=""; esc=0
        for (( i=0; i<${#line}; i++ )); do
            ch="${line:i:1}"
            if (( esc )); then cur+="$ch"; esc=0; continue; fi
            case "$ch" in
                \\) esc=1 ;;
                :)  fields+=("$cur"); cur="" ;;
                *)  cur+="$ch" ;;
            esac
        done
        fields+=("$cur")
        [[ ${#fields[@]} -eq 5 ]] || continue
        _pg_match "${fields[0]}" "$want_host" && _pg_match "${fields[1]}" "$want_port" \
            && _pg_match "${fields[2]}" "$want_db" && _pg_match "${fields[3]}" "$want_user" || continue
        printf '%s' "${fields[4]}"
        return 0
    done < "$f"
    echo "no matching .pgpass entry for ${want_user}@${want_host}:${want_port}/${want_db}" >&2
    return 1
}

# 统一封装：取口令 -> --pipeline/-2 经 stdin 传入工具，命令行无明文。
# vb_sql <db> <vsql 其余参数...>
vb_sql() {
    local db="$1"; shift
    local pw; pw=$(pgpass_lookup "$PG_HOST" "$PG_PORT" "$db" "$PG_USER") || return 1
    printf '%s\n' "$pw" | "$VB_SQL" -2 -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" "$@"
}

# vb_dump_db <db> <vb_dump 其余参数...>（db 作为最后一个位置参数自动追加）
vb_dump_db() {
    local db="$1"; shift
    local pw; pw=$(pgpass_lookup "$PG_HOST" "$PG_PORT" "$db" "$PG_USER") || return 1
    printf '%s\n' "$pw" | "$VB_DUMP" --pipeline -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$@" "$db"
}

# vb_dumpall_globals <vb_dumpall 其余参数...>（连默认库 postgres）
vb_dumpall_globals() {
    local pw; pw=$(pgpass_lookup "$PG_HOST" "$PG_PORT" postgres "$PG_USER") || return 1
    printf '%s\n' "$pw" | "$VB_DUMPALL" --pipeline -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$@"
}

# vb_restore_db <db> <vb_restore 其余参数...>（最后通常跟 dump 文件路径；连库恢复才需口令，
# 纯本地 "$VB_RESTORE" -l <file> 列对象不连库、无需口令，直接用原命令即可）
vb_restore_db() {
    local db="$1"; shift
    local pw; pw=$(pgpass_lookup "$PG_HOST" "$PG_PORT" "$db" "$PG_USER") || return 1
    printf '%s\n' "$pw" | "$VB_RESTORE" --pipeline -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" "$@"
}

# vb_basebackup_run <vb_basebackup 其余参数...>（物理备份/复制连接，.pgpass 的 * 通配即可匹配）
# 注意：部分 VastBase 版本的 vb_basebackup 不支持 --pipeline（实测 V3.0.8PSU4 即如此，
# 报 unrecognized option '--pipeline'）。故本封装运行时探测：
#   有 --pipeline → 经 stdin 注入口令（首选，命令行/ps/environ 均无明文）；
#   无 --pipeline → 降级为子 shell 内 PGPASSWORD（口令不进父环境、不上命令行、不进 ps args；
#                   仅在备份进行期间存在于 vb_basebackup 进程的 /proc/<pid>/environ，且仅同用户/root 可读）。
vb_basebackup_run() {
    local pw; pw=$(pgpass_lookup "$PG_HOST" "$PG_PORT" replication "$PG_USER") || return 1
    if "$VB_BASEBACKUP" --help 2>/dev/null | grep -q -- '--pipeline'; then
        printf '%s\n' "$pw" | "$VB_BASEBACKUP" --pipeline -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$@"
    else
        ( export PGPASSWORD="$pw"; exec "$VB_BASEBACKUP" -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$@" )
    fi
}

# vb_untar_gz <包.tar.gz|包.tar> <目标目录>
# openGauss tar 格式包的解压：gs_tar/vb_tar 不自带 gzip，须先 gunzip 去 .gz 层，再 gs_tar -D <dir> -F <tar>。
# 直接对 .tar.gz 调 gs_tar 会报 "could not parse file size"；用 GNU tar 解则报 "does not look like a tar archive"。
# 良性告警处理：gs_tar 对双写文件 global/pg_dw.build 常报 "could not open ... Invalid argument"，
# 该文件实例启动时自动重建，若错误仅此一类则视为成功（仍以调用方对 PG_VERSION/global 等哨兵的校验为准）。
vb_untar_gz() {
    local src="$1" dst="$2"
    [[ -n "${VB_TAR:-}" && -x "${VB_TAR:-}" ]] || { echo "vb_untar_gz: VB_TAR (gs_tar/vb_tar) not found" >&2; return 2; }
    [[ -f "$src" ]] || { echo "vb_untar_gz: no such file: $src" >&2; return 1; }
    mkdir -p "$dst" || return 1
    local tmp; tmp=$(mktemp "${TMPDIR:-/tmp}/vbuntar.XXXXXX.tar") || return 1
    if [[ "$src" == *.gz ]]; then
        gunzip -c "$src" > "$tmp" || { echo "vb_untar_gz: gunzip failed: $src" >&2; rm -f "$tmp"; return 1; }
    else
        cp -f "$src" "$tmp" || { rm -f "$tmp"; return 1; }
    fi
    local out rc
    out=$("$VB_TAR" -D "$dst" -F "$tmp" 2>&1); rc=$?
    rm -f "$tmp"
    [[ -n "$out" ]] && printf '%s\n' "$out"
    if [[ $rc -ne 0 ]]; then
        # 仅 pg_dw.build 一类告警则降级为成功
        local nonbenign
        nonbenign=$(printf '%s\n' "$out" | grep -v 'pg_dw\.build' | grep -iE 'could not|error|invalid|fail|cannot' || true)
        [[ -z "$nonbenign" ]] && rc=0
    fi
    return $rc
}

# ---- 本地路径 ----
export BACKUP_DIR=/vastbase/backup
export LOG_DIR=/vastbase/log/backup
export LOCAL_RETENTION_DAYS=14

# ---- 异地备份服务器 ----
export REMOTE_HOST=192.168.100.100
export REMOTE_USER=root
export REMOTE_DIR=/backup/vbdb01
export REMOTE_RETENTION_DAYS=30
export RSYNC_BWLIMIT=0
# 远端 rsync 可执行文件的绝对路径。rsync 是两端协作的，远端必须也装有 rsync。
# 非交互式 SSH（脚本运行环境）的 PATH 往往比交互登录窄，可能找不到 rsync 而报
# "bash: rsync: command not found"；用 --rsync-path 显式指定绝对路径最稳妥（见 §10.2.3 验证方法）。
# 用 ssh -o BatchMode=yes <远端> 'command -v rsync' 查出实际路径后回填；为空则回退为 PATH 查找。
export REMOTE_RSYNC_PATH=/usr/bin/rsync

# ---- V3.0.8PSU4 逻辑备份/恢复增强选项（默认关闭）----
# 启用前先执行：$VB_DUMP --help / $VB_RESTORE --help，确认当前工具支持这些选项。
# 例：export DUMP_EXTRA_OPTS="--stat-obj"
# 例：export RESTORE_EXTRA_OPTS="--stat-obj --validate-obj"
export DUMP_EXTRA_OPTS="${DUMP_EXTRA_OPTS:-}"
export RESTORE_EXTRA_OPTS="${RESTORE_EXTRA_OPTS:-}"

export SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes"

# ---- 网络命令包装：强制 ssh/rsync 使用系统 OpenSSL ----
# 原因：上面把 $GAUSSHOME/lib 加进了 LD_LIBRARY_PATH，其中 VastBase 自带的
#       libcrypto.so.1.1 缺少系统 ssh 所需的 OPENSSL_1_1_1f 版本符号，会导致
#       ssh/rsync 报 "version `OPENSSL_1_1_1f' not found" 而加载失败。
#       这里仅在网络命令上剥离 LD_LIBRARY_PATH（等价于交互 shell 的纯净环境），
#       不影响 vb_dump/vsql 等 DB 工具对 VastBase 库的依赖。
ssh_sys()   { env -u LD_LIBRARY_PATH ssh "$@"; }
rsync_sys() { env -u LD_LIBRARY_PATH rsync "$@"; }

# ---- 自动发现业务库并回填 databases.list（见 §10.4 备份脚本 auto-discover 段）----
# AUTO_DISCOVER_DBS=1     ：无参数全量备份时，自动发现可连接的非模板库；清单缺失的自动追加到
#                          databases.list（被显式注释掉的库名视为人工排除，不会被加回）。设 0 关闭。
# AUTO_DISCOVER_EXCLUDE_REGEX：默认排除演练/压测/临时库；显式 export 为 "" 可关闭正则排除。
# ALERT_ON_DRIFT=1        ：备份成功但检出清单漂移（新增库或有待人工处理库）时发 FYI 邮件（需 ALERT_MAIL）。
export AUTO_DISCOVER_DBS="${AUTO_DISCOVER_DBS:-1}"
export AUTO_DISCOVER_EXCLUDE_REGEX="${AUTO_DISCOVER_EXCLUDE_REGEX-(_check|_drill|_verify|_restore|_tmp|_temp)$|^benchdb$}"
export ALERT_ON_DRIFT="${ALERT_ON_DRIFT:-1}"

# ---- License 与通知 ----
export LIC_FILE=/vastbase/license/vastbase_license
export ALERT_MAIL=""
```

落地后验证：

```bash
su - vastbase
source /vastbase/scripts/backup.env
require_cmds VB_SQL VB_CTL VB_DUMP VB_DUMPALL VB_RESTORE
printf 'VB_SQL=%s\nVB_CTL=%s\nVB_DUMP=%s\nVB_RESTORE=%s\n' "$VB_SQL" "$VB_CTL" "$VB_DUMP" "$VB_RESTORE"
```

#### 10.3.2 `/vastbase/scripts/databases.list`

```text
# 需要备份的业务数据库列表，一行一个，# 开头为注释
appdb
#
# ↓↓ 人工排除示例：用明显的占位名，切勿把真业务库名留在注释里（会被静默漏备，详见下方告警）
# legacy_appdb_2024   # 已下线库的排除示例
#
admin_center
ai_helper
aihelper
authx_service
cas_server
cat
dog
fileupload
formflow
jobs_server
message
platform_openapi
postgres
powerjob
question_feedback
reservation
transaction_service
```

> 示例为单业务库 `appdb`；多业务库部署时按现场库名逐行加入。增减业务库时只改这个文件，**脚本本身不用动**。
>
> **⚠️ 真业务库切勿留在注释里（v1.44 现场教训）。** 被注释的库名会被自动发现视为"人工排除、永不回填"。本现场曾把 `dog` 当排除示例写成 `# dog`，而 `dog` 实为有 5 张表的真业务库（§12.1 跨库演示 cat→dog 即用它），结果它被静默漏备、裸机恢复时整库缺失，直到 §11.4 f) 的"生产 vs 恢复 逐库表数比对"才查出。**规避**：排除示例一律用 `legacy_*`/`old_*` 这类明显占位名；真业务库（如本现场的 `cat`/`dog`）必须在清单里**取消注释、保持激活**；并把 §11.4 d/e/f 的逐库表数比对纳入每次恢复/演练验收，作为"整库漏备"的兜底检测（search_path 自检、单库灌数日志都发现不了某个库压根没进备份集）。
>
> **自动发现与回填（§10.4）。** 无参数全量备份时，脚本会比对实例中"可连接的非模板库"与本清单，把**缺失**的库自动追加到本文件并纳入当次备份，以防上线后新建库忘了登记而漏备。追加项形如：
>
> ```text
> # >>> auto-added by db_backup.sh @ 2026-06-23 02:00:01 —— 上线后新建、清单未及时维护的业务库
> new_business_db
> ```
>
> 几条须知：
>
> - **要排除某库，请把它"注释掉"而不是"删除"**：被注释的库名会被识别为人工排除，**不会**被自动加回；而整行删除的库下次会被重新发现并回填。**但正因如此，注释里绝不能出现真业务库名**——否则它会被当成"故意排除"而长期漏备且不告警（这正是 `dog` 漏备的根因）。
> - **有意排除务必在注释行写明原因与日期**
> - **演练/压测/临时库默认跳过**：`*_check`、`*_drill`、`*_verify`、`*_restore`、`*_tmp`、`benchdb` 等按 `AUTO_DISCOVER_EXCLUDE_REGEX` 默认正则忽略，避免把异名恢复库、`backup_verify` 深度校验库、sysbench 压测库等误纳入备份。需要调整范围就改这个正则；显式 `export AUTO_DISCOVER_EXCLUDE_REGEX=""` 可关闭正则排除。
> - **需引号/特殊字符的库名不会被自动加**（本脚本只处理未加引号的普通标识符，见 §10.4 名称约束）：这类库只在日志与 FYI 邮件中告警，请人工用手工 dump/restore 处理，不会被静默漏备。
> - **关闭自动发现**：`export AUTO_DISCOVER_DBS=0`，回到"清单即唯一事实来源"的纯手工维护模式。
> - 自动发现是只读查询 + 仅追加写，且在主库确认与全局文件锁内进行；指定子集运行（`./db_backup.sh cat dog`）时不触发发现、不改清单。
> - **演练/压测/临时库默认跳过**：`*_check`、`*_drill`、`*_verify`、`*_restore`、`*_tmp`、`benchdb` 等按 `AUTO_DISCOVER_EXCLUDE_REGEX` 默认正则忽略，避免把异名恢复库、`backup_verify` 深度校验库、sysbench 压测库等误纳入备份。需要调整范围就改这个正则；显式 `export AUTO_DISCOVER_EXCLUDE_REGEX=""` 可关闭正则排除。
> - **需引号/特殊字符的库名不会被自动加**（本脚本只处理未加引号的普通标识符，见 §10.4 名称约束）：这类库只在日志与 FYI 邮件中告警，请人工用手工 dump/restore 处理，不会被静默漏备。
> - **关闭自动发现**：`export AUTO_DISCOVER_DBS=0`，回到"清单即唯一事实来源"的纯手工维护模式。
> - 自动发现是只读查询 + 仅追加写，且在主库确认与全局文件锁内进行；指定子集运行（`./db_backup.sh cat dog`）时不触发发现、不改清单。


### 10.4 主备份脚本 `/vastbase/scripts/db_backup.sh`

下面脚本相较原版做了生产加固：

- **口令零明文**：所有 DB 工具调用经 `backup.env` 的 `vb_sql` / `vb_dump_db` / `vb_dumpall_globals` 封装，口令从 `~/.pgpass`（600）取出后经 `--pipeline`/`-2` 由 stdin 传入，脚本、命令行、`ps`、environ 中均无明文；
- 对数据库名做白名单校验，避免命令注入和误传特殊字符；
- **自动发现业务库并回填清单**：无参数全量备份时，自动比对实例中可连接的非模板库与 `databases.list`，把缺失的库追加进清单并纳入本次备份，解决上线后新建库未及时登记导致的漏备；被显式注释掉的库名视为人工排除、不会被加回（详见脚本 auto-discover 段与 §10.3.2）；
- 备份前检查目标库是否存在，避免 `databases.list` 拼错后误以为成功；
- 本地先写到 `${DATE}.running`，全部成功后原子发布为 `${DATE}`；
- 远端先同步到 `${DATE}.partial`，校验 `BACKUP.OK` 后原子发布；
- **每库生成建库 DDL `*.create.sql`**：单库 `-F c` dump 与 `vb_dumpall -g` 都不含 `CREATE DATABASE`，本脚本额外抓取库的属主/编码/排序规则/表空间/连接数上限与库级 `ALTER DATABASE ... SET`，使备份集可在全新实例上自洽重建（本版兼容模式靠 initdb 实例级继承，DDL 中不写 `DBCOMPATIBILITY`，详见脚本注释与 §11.4）；
- 不使用 `--inplace` 覆盖远端有效备份，降低网络中断后的损坏风险；
- **rsync 远端可执行文件显式定位**：经 `--rsync-path="${REMOTE_RSYNC_PATH:-rsync}"` 指定远端 rsync 绝对路径，规避非交互式 SSH 的 PATH 不含 rsync 而报 `command not found`；
- **网络命令隔离 OpenSSL**：`ssh`/`rsync` 经 `ssh_sys`/`rsync_sys` 包装、剥离 `LD_LIBRARY_PATH`，避免被 VastBase 自带的 `libcrypto.so.1.1` 顶替系统 OpenSSL 而报 `OPENSSL_1_1_1f not found`；
- 退出码非 0 即表示失败，可直接接入 cron/Zabbix/Prometheus。

> 名称约束：脚本中的 `valid_ident` 只支持未加引号的普通标识符（字母/下划线开头，最多 63 字符）。如源库名以数字开头、包含 `$` 或必须使用双引号，请不要直接走自动脚本，改用手工 dump/restore 并逐项确认对象引用。
>

安装 rsync 工具（**本机与异地服务器两端都要装**）

rsync 通过 SSH 在远端拉起一个 rsync 进程与本地协作，**任一端缺可执行文件都会失败**。典型现象：本机 `which rsync` 明明有，同步却报远端 `bash: rsync: command not found`，随后本地 sender 收到连接关闭，报 `rsync error: ... (code 12) ... [sender=3.1.3]`——这说明本地 rsync 正常启动了，断点在**远端**。原因有二：(1) 远端确实没装；(2) 远端装了，但**非交互式 SSH 的 PATH** 不含其所在目录（`mkdir`/`rm` 能成功只因它们在 `/usr/bin` 这类基础 PATH 里，而 root 的 `.bashrc` 常在非交互段之前就 `return`，自定义 PATH 不生效）。

```bash
# 1) 本机（发送端）安装
su - root
yum install -y rsync          # 麒麟/openEuler 系：dnf install -y rsync

# 2) 异地服务器（接收端）同样安装
ssh root@192.168.100.100 'yum install -y rsync'   # 或 dnf install -y rsync

# 3) 用“非交互式”ssh 确认远端真能找到 rsync，并记下绝对路径
ssh -o BatchMode=yes root@192.168.100.100 'command -v rsync || echo RSYNC_MISSING'
```

把上一步查到的绝对路径（通常 `/usr/bin/rsync`）填进 `backup.env` 的 `REMOTE_RSYNC_PATH`。脚本的 rsync 命令带 `--rsync-path="${REMOTE_RSYNC_PATH:-rsync}"`，直接告诉远端用哪个绝对路径执行，绕开非交互式 PATH 的不确定性——这也是跨机器同步的常规稳妥做法。

> `backup.env` 里 `rsync_sys`/`ssh_sys` 用 `env -u LD_LIBRARY_PATH` 剥掉 VastBase 注入的 `LD_LIBRARY_PATH`（避免系统 ssh/rsync 误加载 VastBase 自带的不兼容 libssl/libcrypto 而报 `OPENSSL_1_1_1f not found`）。这与"远端找不到 rsync"是两类不同问题：前者是本机加载库的问题，后者是远端可执行文件/PATH 的问题。

将 vastbase 加入 crontab 允许用户

```bash
echo "vastbase" >> /etc/cron.allow
```

否则会报错

```bash
[root@vbdb01 ~]# su - vastbase -c 'crontab -e'
You (vastbase) are not allowed to use this program (crontab)
See crontab(1) for more information
```



备份脚本`/vastbase/scripts/db_backup.sh`

```bash
#!/bin/bash
#==============================================================================
# db_backup.sh —— VastBase G100 多库逻辑备份 + 异地 rsync 原子同步
# 用法:  ./db_backup.sh           # 备份 databases.list 中所有库
#        ./db_backup.sh cat dog   # 仅备份指定库
#==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/backup.env" || exit 2
DB_LIST_FILE="${SCRIPT_DIR}/databases.list"

DATE=$(date +%F)
TS=$(date +%F_%H%M%S)
RUN_DIR="${BACKUP_DIR}/${DATE}.running.${TS}"
DAY_DIR="${BACKUP_DIR}/${DATE}"
LOG_FILE="${LOG_DIR}/backup_${TS}.log"
LOCK_FILE="/tmp/vastbase_backup.lock"
FAILED=0

mkdir -p "$RUN_DIR" "$LOG_DIR"
chmod 750 "$RUN_DIR"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 2; }
valid_ident() { [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]{0,62}$ ]]; }
normalize_dbcompat() {
    # 兼容不同 VastBase/openGauss 补丁中 datcompatibility 的字面值差异。
    # 输出统一短码：A / B / C / PG / SQLSERVER / unknown。
    local v="${1:-unknown}"
    v="$(printf '%s' "$v" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
    case "$v" in
        A|ORA|ORACLE) echo "A" ;;
        B|MYSQL) echo "B" ;;
        C|TD|TERADATA) echo "C" ;;
        PG|POSTGRES|POSTGRESQL) echo "PG" ;;
        SQLSERVER|SQL_SERVER|MSSQL) echo "SQLSERVER" ;;
        ""|UNKNOWN) echo "unknown" ;;
        *) echo "$v" ;;
    esac
}

require_cmds VB_SQL VB_DUMP VB_DUMPALL || die "required VastBase tools missing"
[[ -f "$DB_LIST_FILE" ]] || die "missing $DB_LIST_FILE"

exec 200>"$LOCK_FILE"
flock -n 200 || die "another backup is running"

log "===================== Backup START ====================="
log "Host=$(hostname)  RunDir=$RUN_DIR"

if [[ $# -gt 0 ]]; then
    EXPLICIT_MODE=1
    DB_LIST=("$@")
else
    EXPLICIT_MODE=0
    mapfile -t DB_LIST < <(grep -vE '^\s*(#|$)' "$DB_LIST_FILE" | awk '{print $1}')
fi

# 先确认当前实例为主库：自动发现会改写 databases.list，必须只在主库上进行；
# 这也是"不在备库上误跑备份"的安全闸。后续库存在性检查复用此连接通道。
INREC=$(vb_sql postgres -At -c "SELECT pg_is_in_recovery();" 2>>"$LOG_FILE" || echo "?")
[[ "$INREC" == "f" ]] || die "current instance is not primary or cannot confirm pg_is_in_recovery()=$INREC"

# ---- 自动发现业务库并回填 databases.list（解决上线后新建库漏备）----
# 仅在"全量模式"（无命令行参数）下启用；./db_backup.sh <子集> 指定库时不发现、不改清单。
# 设计要点：
#   1) 发现集 = 可连接的非模板库（排除 template0/template1）；
#   2) 已在清单中的活跃条目、以及被显式注释掉的库名（如 "# cat"）均视为"已知"，不重复追加——
#      尊重运维主动注释屏蔽某库的意图，避免被强行加回；
#   3) 演练/压测/临时库（*_check/*_drill/*_verify/*_restore/*_tmp/benchdb 等）默认按正则跳过，
#      可用 AUTO_DISCOVER_EXCLUDE_REGEX 覆盖；显式置为空字符串则不按正则排除；
#   4) 库名过不了 valid_ident（需引号/特殊字符）的只告警、不自动追加、不静默漏备，须人工处理；
#   5) 只"追加"不重写，保留原有注释与排序；追加在全局 flock 内进行，无并发写冲突。
DRIFT=0
if [[ $EXPLICIT_MODE -eq 0 && "${AUTO_DISCOVER_DBS:-1}" == "1" ]]; then
    log "----- auto-discover business DBs (drift check against databases.list)"
    # 清单中"已知"的库名：活跃条目（非注释行首列）+ 被注释排除的标识符（"# name" 行取 name）
    declare -A KNOWN=()
    while read -r k; do [[ -n "$k" ]] && KNOWN["$k"]=1; done < <(
        grep -vE '^\s*(#|$)' "$DB_LIST_FILE" | awk '{print $1}'
        grep -oE '^[[:space:]]*#[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*' "$DB_LIST_FILE" \
            | sed -E 's/^[[:space:]]*#[[:space:]]*//'
    )
    mapfile -t ALL_DBS < <(vb_sql postgres -At -c \
        "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate AND datname NOT IN ('template0','template1') ORDER BY datname;" \
        2>>"$LOG_FILE")
    # 默认排除瞬时/演练/压测库；用 - 而非 :- 取默认，使显式 export AUTO_DISCOVER_EXCLUDE_REGEX="" 可关闭正则排除
    EXCL_RE="${AUTO_DISCOVER_EXCLUDE_REGEX-(_check|_drill|_verify|_restore|_tmp|_temp)\$|^benchdb\$}"
    ADDED=()
    for d in "${ALL_DBS[@]:-}"; do
        [[ -z "$d" ]] && continue
        [[ -n "${KNOWN[$d]:-}" ]] && continue                       # 已在清单或被注释排除
        if [[ -n "$EXCL_RE" && "$d" =~ $EXCL_RE ]]; then
            log "  skip (exclude regex): $d"; continue
        fi
        if ! valid_ident "$d"; then
            log "  WARN: discovered DB needs manual handling (non-bare identifier), NOT auto-added: $d"
            DRIFT=1; continue
        fi
        ADDED+=("$d")
    done
    if [[ ${#ADDED[@]} -gt 0 ]]; then
        {
            echo ""
            echo "# >>> auto-added by db_backup.sh @ $(date '+%F %T') —— 上线后新建、清单未及时维护的业务库"
            for d in "${ADDED[@]}"; do echo "$d"; done
        } >> "$DB_LIST_FILE"
        DB_LIST+=("${ADDED[@]}")
        DRIFT=1
        log "  appended ${#ADDED[@]} new DB(s) to databases.list: ${ADDED[*]}"
    else
        log "  no drift: databases.list already covers all eligible business DBs"
    fi
fi

[[ ${#DB_LIST[@]} -gt 0 ]] || die "empty database list"

for DB in "${DB_LIST[@]}"; do
    valid_ident "$DB" || die "invalid database name: $DB"
done
log "Targets: ${DB_LIST[*]}"

# 备份前检查各目标库存在且允许连接
for DB in "${DB_LIST[@]}"; do
    EXISTS=$(vb_sql postgres -At \
        -c "SELECT 1 FROM pg_database WHERE datname='${DB}' AND datallowconn" 2>>"$LOG_FILE")
    [[ "$EXISTS" == "1" ]] || die "database not found or not allow connection: $DB"
done

# 磁盘保护：备份根目录可用空间低于 20GB 直接失败，阈值可按现场调大
FREE_GB=$(df -BG --output=avail "$BACKUP_DIR" | tail -1 | tr -dc '0-9')
[[ "${FREE_GB:-0}" -ge 20 ]] || die "backup dir free space too low: ${FREE_GB}GB"

declare -A RESULT

# ---- 1. 逐库备份 ----
for DB in "${DB_LIST[@]}"; do
    DUMP="${RUN_DIR}/${DB}_${TS}.dump"
    MAN="${RUN_DIR}/${DB}_${TS}.manifest"
    CREATE_SQL="${RUN_DIR}/${DB}_${TS}.create.sql"
    log "----- [$DB] dump -> $DUMP"

    # DUMP_EXTRA_OPTS 用于 V3.0.8PSU4 增强选项，如 --stat-obj；默认空。
    # vb_dump_db 内部经 --pipeline 从 .pgpass 取口令，命令行无明文；db 作为末位参数自动追加。
    # shellcheck disable=SC2086
    if vb_dump_db "$DB" -F c -Z 6 ${DUMP_EXTRA_OPTS:-} -f "$DUMP" >>"$LOG_FILE" 2>&1; then
        SIZE=$(stat -c %s "$DUMP")
        SHA256=$(sha256sum "$DUMP" | awk '{print $1}')
        MD5=$(md5sum "$DUMP" | awk '{print $1}')
        DBCOMPAT_RAW=$(vb_sql postgres -At \
                   -c "SELECT datcompatibility FROM pg_database WHERE datname='${DB}'" 2>>"$LOG_FILE" || echo "unknown")
        DBCOMPAT=$(normalize_dbcompat "$DBCOMPAT_RAW")
        [[ -z "$DBCOMPAT" ]] && DBCOMPAT="unknown"
        cat > "$MAN" <<EOF
version:  1
host:     $(hostname)
database: $DB
dbcompatibility: $DBCOMPAT
dbcompatibility_raw: ${DBCOMPAT_RAW:-unknown}
file:     $(basename "$DUMP")
create_file: $(basename "$CREATE_SQL")
size:     $SIZE
sha256:   $SHA256
md5:      $MD5
created:  $TS
tool:     $VB_DUMP
EOF
        # ---- 生成建库 DDL：使全新/异机实例可直接重建该库（见 §11.4 裸机恢复）----
        # 单库 -F c dump 与 vb_dumpall -g 均不含 CREATE DATABASE；这里抓库级属性补齐。
        # 本版 CREATE DATABASE 不接受 DBCOMPATIBILITY（见 §8.2）：兼容模式由 initdb 实例级经
        # template0 继承，故 DDL 不写该选项，仅在注释中记录期望模式，恢复前须确保实例默认即为该模式。
        DBPROPS=$(vb_sql postgres -At -F '|' -c "
            SELECT pg_catalog.pg_get_userbyid(d.datdba),
                   pg_catalog.pg_encoding_to_char(d.encoding),
                   d.datcollate, d.datctype, d.datconnlimit, t.spcname
            FROM pg_database d JOIN pg_tablespace t ON d.dattablespace = t.oid
            WHERE d.datname = '${DB}'" 2>>"$LOG_FILE")
        if [[ -n "$DBPROPS" ]]; then
            IFS='|' read -r DB_OWNER DB_ENC DB_COLLATE DB_CTYPE DB_CONNLIMIT DB_TBLSPC <<<"$DBPROPS"
            {
                echo "-- VastBase G100 建库 DDL（自动生成）"
                echo "-- database=${DB}  host=$(hostname)  created=${TS}"
                echo "-- 期望兼容模式=${DBCOMPAT}（本版 CREATE DATABASE 不接受 DBCOMPATIBILITY，"
                echo "--   目标实例须已 initdb 为 ${DBCOMPAT} 模式并由 template0 继承——见 §8.2/§11.4）"
                echo "-- 恢复顺序：1) vb_sql -f globals_*.sql 建角色/表空间(表空间 LOCATION 目录须先存在)"
                echo "--           2) 执行本文件建库  3) vb_restore -d ${DB} <db>_*.dump 灌数据"
                echo "\\set ON_ERROR_STOP on"
                printf "CREATE DATABASE \"%s\" WITH OWNER=\"%s\" ENCODING='%s' LC_COLLATE='%s' LC_CTYPE='%s' TEMPLATE=template0" \
                       "$DB" "$DB_OWNER" "$DB_ENC" "$DB_COLLATE" "$DB_CTYPE"
                [[ -n "$DB_TBLSPC" && "$DB_TBLSPC" != "pg_default" ]] && printf " TABLESPACE=\"%s\"" "$DB_TBLSPC"
                [[ -n "$DB_CONNLIMIT" && "$DB_CONNLIMIT" != "-1" ]] && printf " CONNECTION LIMIT=%s" "$DB_CONNLIMIT"
                echo ";"
            } > "$CREATE_SQL"
            # 库级 ALTER DATABASE ... SET（如 search_path）：setrole=0 表示库级（非"库+角色"组合级）。
            # 单库 custom dump 不含这些库级 GUC，必须在此补出，否则裸机恢复后 search_path 等会丢失。
            #
            # ★ v1.41 关键修复：search_path/temp_tablespaces 是**列表型 GUC**，存储值形如
            #   "search_path=ai_helper, public"。旧版用 quote_literal() 把整串逗号值包成一个字符串，
            #   生成 `SET search_path = 'ai_helper, public'`——VastBase/PG 落库时会把这个带逗号的引号串
            #   当作**一个**名为 "ai_helper, public" 的 schema（逗号被引号保护、不再拆分），该 schema 不存在，
            #   恢复后 search_path 指向空、`\dt` 看不到表（表其实已灌入，仅不可见）、应用报"表不存在"。
            #   正确做法：列表型 GUC 按逗号拆开、每段各自 quote_ident，输出裸标识符列表
            #   `SET search_path = ai_helper, public`；其余标量 GUC 仍用 quote_literal。
            #   排障/自查：恢复后 `SHOW search_path` 若回显带引号的单段值即中招，按本规则改 ALTER 即可，
            #   数据无需重灌（详见 §11.4 注记与本版修订记录）。
            vb_sql postgres -At -c "
                SELECT 'ALTER DATABASE \"${DB}\" SET '||opt||' = '||val||';'
                FROM (
                    SELECT split_part(s,'=',1) AS opt,
                           CASE WHEN split_part(s,'=',1) IN ('search_path','temp_tablespaces')
                                THEN (SELECT string_agg(quote_ident(btrim(e)), ', ')
                                      FROM regexp_split_to_table(
                                               regexp_replace(s,'^[^=]+=',''), ',') AS e
                                      WHERE btrim(e) <> '')
                                ELSE quote_literal(regexp_replace(s,'^[^=]+=',''))
                           END AS val
                    FROM (SELECT unnest(setconfig) AS s
                          FROM pg_db_role_setting r JOIN pg_database d ON r.setdatabase=d.oid
                          WHERE d.datname='${DB}' AND r.setrole=0) x
                ) y
                WHERE val IS NOT NULL AND val <> ''" 2>>"$LOG_FILE" >> "$CREATE_SQL"
            # ★ v1.42：sidecar 只写 basename，避免把 $RUN_DIR(.running.<ts>) 绝对路径写死——
            #   该临时目录在备份末尾 mv 成最终目录后即不存在，绝对路径会让 `sha256sum -c` 在任何
            #   机器/目录都失败。进目录用 basename 生成，校验文件与数据同目录、可随意搬迁。
            ( cd "$RUN_DIR" && sha256sum "${DB}_${TS}.create.sql" > "${DB}_${TS}.create.sql.sha256" )
            log "       create.sql OK -> $(basename "$CREATE_SQL")"
        else
            log "       create.sql FAIL: cannot read db properties for $DB"
            FAILED=$((FAILED+1))
        fi
        RESULT[$DB]="OK $(numfmt --to=iec "$SIZE") sha256=${SHA256:0:12}"
        log "       OK size=$SIZE sha256=$SHA256"
    else
        RESULT[$DB]="FAIL"
        FAILED=$((FAILED+1))
        log "       FAIL"
    fi
done

# ---- 2. 全局对象 ----
GLOBALS="${RUN_DIR}/globals_${TS}.sql"
log "----- [globals] -> $GLOBALS"
if vb_dumpall_globals -g -f "$GLOBALS" >>"$LOG_FILE" 2>&1; then
    ( cd "$RUN_DIR" && sha256sum "globals_${TS}.sql" > "globals_${TS}.sql.sha256" )   # ★ v1.42 basename，可搬迁
    log "       OK size=$(stat -c %s "$GLOBALS")"
else
    log "       FAIL"
    FAILED=$((FAILED+1))
fi

# ---- 3. 校验 dump 可读性 ----
for DUMP in "$RUN_DIR"/*.dump; do
    [[ -f "$DUMP" ]] || continue
    if "$VB_RESTORE" -l "$DUMP" >/dev/null 2>>"$LOG_FILE"; then
        log "verify list OK: $(basename "$DUMP")"
    else
        log "verify list FAIL: $(basename "$DUMP")"
        FAILED=$((FAILED+1))
    fi
done

# ---- 4. 本地原子发布 ----
if [[ $FAILED -eq 0 ]]; then
    touch "${RUN_DIR}/BACKUP.OK"
    rm -rf "${DAY_DIR}.previous"
    [[ -d "$DAY_DIR" ]] && mv "$DAY_DIR" "${DAY_DIR}.previous"
    mv "$RUN_DIR" "$DAY_DIR"
    rm -rf "${DAY_DIR}.previous"
    log "local publish OK: $DAY_DIR"
else
    log "$FAILED job(s) FAILED, local publish skipped; run dir kept: $RUN_DIR"
fi

# ---- 5. rsync 远端原子发布 ----
if [[ $FAILED -eq 0 ]]; then
    REMOTE_TMP="${REMOTE_DIR}/${DATE}.partial.${TS}"
    REMOTE_FINAL="${REMOTE_DIR}/${DATE}"
    log "----- rsync -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP}/"
    if ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf '${REMOTE_TMP}'; mkdir -p '${REMOTE_TMP}'" >>"$LOG_FILE" 2>&1 \
       && rsync_sys -avz --partial-dir=.rsync-partial --delay-updates \
             --rsync-path="${REMOTE_RSYNC_PATH:-rsync}" \
             --bwlimit="${RSYNC_BWLIMIT:-0}" -e "env -u LD_LIBRARY_PATH ssh $SSH_OPTS" \
             "${DAY_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP}/" >>"$LOG_FILE" 2>&1 \
       && ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
             "test -f '${REMOTE_TMP}/BACKUP.OK' && rm -rf '${REMOTE_FINAL}.old' && { [ ! -d '${REMOTE_FINAL}' ] || mv '${REMOTE_FINAL}' '${REMOTE_FINAL}.old'; } && mv '${REMOTE_TMP}' '${REMOTE_FINAL}' && rm -rf '${REMOTE_FINAL}.old'" >>"$LOG_FILE" 2>&1; then
        log "remote publish OK."
    else
        log "remote publish FAIL."
        FAILED=$((FAILED+1))
    fi
fi

# ---- 6. 清理过期备份 ----
log "----- cleanup local backups older than ${LOCAL_RETENTION_DAYS} days"
find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*-*-*' \
     -mtime +"$LOCAL_RETENTION_DAYS" -print -exec rm -rf {} \; >>"$LOG_FILE" 2>&1 || true

log "----- cleanup remote backups older than ${REMOTE_RETENTION_DAYS} days"
ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
    "find '${REMOTE_DIR}' -maxdepth 1 -type d -name '20*-*-*' -mtime +${REMOTE_RETENTION_DAYS} -print -exec rm -rf {} \;" \
    >>"$LOG_FILE" 2>&1 || log "remote cleanup warning"

# ---- 7. 汇总 ----
log "===================== Summary ====================="
for DB in "${!RESULT[@]}"; do
    log "  $DB : ${RESULT[$DB]}"
done
log "Failed jobs: $FAILED"
[[ $DRIFT -eq 1 ]] && log "Drift: databases.list 发生过自动回填或检出需人工处理的库（详见上文 auto-discover 段）"
log "===================== Backup END ====================="

if [[ $FAILED -gt 0 && -n "${ALERT_MAIL:-}" ]]; then
    tail -100 "$LOG_FILE" | mail -s "[VastBase Backup FAIL] $(hostname) ${DATE}" "$ALERT_MAIL" || true
fi
# 备份成功但检出库清单漂移时，发一封 FYI（不计失败、不改退出码），提醒运维复核新库归属与备份范围
if [[ $FAILED -eq 0 && $DRIFT -eq 1 && "${ALERT_ON_DRIFT:-1}" == "1" && -n "${ALERT_MAIL:-}" ]]; then
    grep -E 'auto-discover|appended|exclude regex|NOT auto-added' "$LOG_FILE" \
        | mail -s "[VastBase Backup DRIFT] $(hostname) ${DATE} databases.list 已更新/有待处理库" "$ALERT_MAIL" || true
fi
exit $FAILED
```

授权并测试：

```bash
chmod 750 /vastbase/scripts/db_backup.sh
chown vastbase:dbgrp /vastbase/scripts/db_backup.sh
su - vastbase -c 'bash -n /vastbase/scripts/db_backup.sh'
su - vastbase -c '/vastbase/scripts/db_backup.sh'
```

> **首次部署务必先确认三件事**（任一不满足都会导致备份在 cron 下挂起或失败）：
>
> ```bash
> su - vastbase
> source /vastbase/scripts/backup.env
> # 1) 三个工具都支持 --pipeline / -2（vb_dumpall 与 vsql/vb_dump 通常一致，但请实测确认）
> "$VB_SQL" --help     | grep -E -- '-2|--pipeline'
> "$VB_DUMP" --help    | grep -- '--pipeline'
> "$VB_DUMPALL" --help | grep -- '--pipeline'
> # 2) 封装函数能连上库（应输出 f，表示当前为主库且非恢复态；不再弹密码提示）
> vb_sql postgres -At -c "SELECT pg_is_in_recovery();"
> # 3) 全脚本与配置中确无明文口令（应无任何输出）
> grep -RnE 'Vbadmin@|PGPASSWORD|-W[[:space:]]' /vastbase/scripts/ || echo "no plaintext password: OK"
> ```
>
> 备份运行期间另开一个会话核对进程参数里没有口令：
>
> ```bash
> ps -ef | grep -E 'vb_dump|vsql' | grep -v grep   # 命令行不应出现口令字样
> ```
>
> 若第 1 步中 `vb_dumpall` 没有 `--pipeline`（极少见），把 `vb_dumpall_globals` 内的全局对象导出临时改用 `expect` 喂口令，或单独为该步设置仅当前 shell 生效的 `PGPASSWORD`（用 `env -u PGPASSWORD` 确保不外泄、用完即清），其余步骤仍走 pipeline。

### 10.5 定时任务（vastbase 用户 crontab）

```bash
su - vastbase -c 'crontab -e'
```

```cron
# ---- VastBase G100 备份任务 ----
# 每天 02:00 全量逻辑备份 + 异地同步
0 2 * * *  /vastbase/scripts/db_backup.sh >> /vastbase/log/backup/cron.log 2>&1

# WAL 归档清理必须结合物理备份/PITR 保留策略；未建立归档备份链前不要启用简单 mtime 删除。
# 0 * * * *  find /vastbase/arch -type f -mtime +14 -delete
```

### 10.6 监控检查点

| 检查 | 命令 |
|------|------|
| 当日备份是否完成 | `test -f /vastbase/backup/$(date +%F)/BACKUP.OK && echo OK \|\| echo MISS` |
| 异地是否同步成功 | `ssh vastbase@192.168.100.100 "test -f /backup/vbdb01/$(date +%F)/BACKUP.OK && echo OK"` |
| 最近 5 次任务结果 | `ls -1t /vastbase/log/backup/backup_*.log \| head -5` |
| 备份占用 | `du -sh /vastbase/backup/*` |

### 10.7 备份脚本生产加固建议

原脚本可满足“多库逻辑备份 + 异地同步”的基本目标，生产建议再补充以下加固点：

1. **远端原子发布**：先同步到 `${DATE}.partial/`，全部成功后远端 `mv ${DATE}.partial ${DATE}`，避免监控误读半成品目录。
2. **避免 `--inplace` 覆盖远端有效备份**：网络中断时 `--inplace` 可能留下损坏文件。建议使用 `--partial-dir=.rsync-partial --delay-updates`。
3. **备份前校验数据库存在**：防止 `databases.list` 拼错导致漏备。
4. **加密与脱敏**：含敏感数据的 dump 文件建议落盘后使用 `gpg`、`openssl enc` 或企业 KMS 加密，再异地传输。
5. **备份不可变性**：远端备份目录建议只允许追加写，结合对象存储 WORM、快照或备份系统防勒索策略。
6. **定期恢复演练**：至少每月恢复一次，不仅检查 dump 文件存在，还要检查业务关键表行数、最大时间戳、序列值、对象数量。
7. **裸机/异机可恢复性**：单库 `-F c` dump 与 `vb_dumpall -g` 都不含 `CREATE DATABASE`，全新实例上"建库"这一步会断。本脚本已为每库生成 `*.create.sql`（属主/编码/排序规则/表空间/连接数 + 库级 `ALTER DATABASE SET`）。注意本版 `CREATE DATABASE` 不接受 `DBCOMPATIBILITY`，兼容模式由 `initdb` 实例级经 template0 继承——**裸机恢复前必须先把目标实例初始化为与源库一致的兼容模式（本文为 B/MySQL）**，否则灌数据时 B 模式 DDL 会在非 B 模式实例上报错或静默失败。
8. **rsync 两端可用性与显式路径**：rsync 是两端协作的，**异地服务器也必须装 rsync**；同时用 `--rsync-path` 指定远端绝对路径，规避非交互式 SSH 的窄 PATH（典型报错 `bash: rsync: command not found` + `rsync error ... code 12`）。部署前用 `ssh -o BatchMode=yes <远端> 'command -v rsync'` 验证（见 §10.2.3、§10.4）。

远端原子同步示例：

```bash
REMOTE_TMP="${REMOTE_DIR}/${DATE}.partial"
REMOTE_FINAL="${REMOTE_DIR}/${DATE}"
ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf ${REMOTE_TMP}; mkdir -p ${REMOTE_TMP}"
rsync_sys -avz --partial-dir=.rsync-partial --delay-updates \
      --rsync-path="${REMOTE_RSYNC_PATH:-rsync}" \
      --bwlimit="${RSYNC_BWLIMIT:-0}" \
      -e "env -u LD_LIBRARY_PATH ssh $SSH_OPTS" \
      "${DAY_DIR}/" \
      "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP}/"
ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
    "test -f ${REMOTE_TMP}/BACKUP.OK && rm -rf ${REMOTE_FINAL} && mv ${REMOTE_TMP} ${REMOTE_FINAL}"
```

### 10.8 日志巡检常用 SQL（运维通用，与备份独立）

```sql
-- 活跃会话
SELECT pid, usename, application_name, client_addr, state,
       NOW()-xact_start AS xact_age, query
  FROM pg_stat_activity
 WHERE state <> 'idle'
 ORDER BY xact_age DESC NULLS LAST;

-- 表空间与库大小
SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) FROM pg_tablespace;
SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database
 ORDER BY pg_database_size(datname) DESC;

-- 长事务
SELECT pid, usename, state, NOW()-xact_start AS age, query
  FROM pg_stat_activity
 WHERE state <> 'idle' AND NOW()-xact_start > INTERVAL '5 min';
```

### 10.9 备份完整性校验脚本

> "已经成功生成的 dump" 不等于"可恢复的 dump"。每天应自动用 `$VB_RESTORE -l` 验证 dump 头部，每周应**实际还原到临时库**做最强校验。

`/vastbase/scripts/backup_verify.sh`：

```bash
#!/bin/bash
#==============================================================================
# backup_verify.sh —— 备份完整性校验
# 用法:  ./backup_verify.sh           # 校验今日所有 dump 文件头部
#        ./backup_verify.sh --deep    # 额外抽一个库实际还原到 _verify 临时库
#==============================================================================
set -uo pipefail
source /vastbase/scripts/backup.env

DATE=$(date +%F)
DAY_DIR="${BACKUP_DIR}/${DATE}"
LOG="${LOG_DIR}/verify_${DATE}.log"
mkdir -p "$LOG_DIR"

say() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
DEEP=0; [[ "${1:-}" == "--deep" ]] && DEEP=1

say "===== Verify START  dir=$DAY_DIR  deep=$DEEP ====="
[[ ! -d "$DAY_DIR" ]] && { say "no backup dir for today"; exit 2; }

FAILED=0

# ---- 1. 哨兵文件 ----
if [[ ! -f "${DAY_DIR}/BACKUP.OK" ]]; then
    say "FAIL: BACKUP.OK missing"; FAILED=$((FAILED+1))
fi

# ---- 2. 每个 dump 文件：MD5 + restore --list 头部检查 ----
for DUMP in "${DAY_DIR}"/*.dump; do
    [[ -f "$DUMP" ]] || continue
    MAN="${DUMP%.dump}.manifest"
    NAME=$(basename "$DUMP")

    # MD5 校验
    if [[ -f "$MAN" ]]; then
        EXPECT=$(awk '/^md5:/{print $2}' "$MAN")
        ACTUAL=$(md5sum "$DUMP" | awk '{print $1}')
        if [[ "$EXPECT" != "$ACTUAL" ]]; then
            say "FAIL: $NAME md5 mismatch"; FAILED=$((FAILED+1)); continue
        fi
    fi

    # 头部完整性：restore --list 读取目录，能列出对象就说明文件头未损坏
    OBJ_CNT=$(${VB_RESTORE:-vb_restore} -l "$DUMP" 2>/dev/null | grep -cE '^[0-9]+;' || echo 0)
    if [[ "$OBJ_CNT" -lt 1 ]]; then
        say "FAIL: $NAME restore --list returned no objects"
        FAILED=$((FAILED+1))
    else
        say "OK  : $NAME  objects=$OBJ_CNT  md5=${ACTUAL:-skip}"
    fi
done

VERIFY_DB=""
cleanup_verify_db() {
    if [[ -n "${VERIFY_DB:-}" ]]; then
        vb_sql postgres -c "DROP DATABASE IF EXISTS ${VERIFY_DB};" >>"$LOG" 2>&1 || true
    fi
}
trap cleanup_verify_db EXIT INT TERM

# ---- 3. 深度校验：实际还原一个库到 _verify 临时库 ----
if [[ $DEEP -eq 1 && $FAILED -eq 0 ]]; then
    PICK_DUMP=$(ls -1 "${DAY_DIR}"/*.dump 2>/dev/null | shuf -n 1)
    if [[ -n "$PICK_DUMP" ]]; then
        DB_NAME=$(basename "$PICK_DUMP" | sed -E 's/_[0-9-]+_[0-9]+\.dump$//')
        VERIFY_DB="${DB_NAME}_verify_$(date +%s)"
        say "deep verify: $PICK_DUMP -> $VERIFY_DB"

        # 本版 CREATE DATABASE 不接受 DBCOMPATIBILITY（见 §8.2）：靠 initdb 实例级设置经 template0 继承。
        vb_sql postgres -v ON_ERROR_STOP=1 \
            -c "CREATE DATABASE ${VERIFY_DB} WITH TEMPLATE=template0;" \
            >>"$LOG" 2>&1 || { say "create verify db fail"; FAILED=$((FAILED+1)); }

        T0=$(date +%s)
        if vb_restore_db "$VERIFY_DB" -j 4 --no-owner --no-privileges \
                "$PICK_DUMP" >>"$LOG" 2>&1; then
            T1=$(date +%s)
            TBL_CNT=$(vb_sql "$VERIFY_DB" -At -c "SELECT count(*) FROM pg_class WHERE relkind IN ('r','p');")
            say "deep verify OK  duration=$((T1-T0))s  tables=$TBL_CNT  (RTO baseline)"
        else
            say "deep verify FAIL"
            FAILED=$((FAILED+1))
        fi

        # 清理验证库
        vb_sql postgres -c "DROP DATABASE IF EXISTS ${VERIFY_DB};" >>"$LOG" 2>&1
        VERIFY_DB=""
    fi
fi

say "===== Verify END    FAILED=$FAILED ====="
exit $FAILED
```

加进 crontab：

```cron
# 每天 04:00 头部校验，每周日 04:30 做一次深度还原校验
0  4 * * *  /vastbase/scripts/backup_verify.sh        >> /vastbase/log/backup/verify_cron.log 2>&1
30 4 * * 0  /vastbase/scripts/backup_verify.sh --deep >> /vastbase/log/backup/verify_cron.log 2>&1
```

> 深度校验顺便记录了 **RTO 基线**（duration），随业务库增长，恢复时长会变化，应纳入容量评估。

---

## 11. 恢复操作（含远端拉回与单库重建脚本）

### 11.1 恢复流程总览

```
                    ┌──────────────────────────────┐
                    │  确认备份源（本地 / 远端）     │
                    └──────────────┬───────────────┘
                                   ▼
                    ┌──────────────────────────────┐
                    │  校验 MD5（manifest）         │
                    └──────────────┬───────────────┘
                                   ▼
                    ┌──────────────────────────────┐
                    │  断开目标库会话               │
                    │  DROP / CREATE DATABASE      │
                    └──────────────┬───────────────┘
                                   ▼
                    ┌────────────────────────────────────────┐
                    │  vb_restore/gs_restore -j 4 并行恢复    │
                    └──────────────┬─────────────────────────┘
                                   ▼
                    ┌──────────────────────────────┐
                    │  ANALYZE + 业务校验           │
                    └──────────────────────────────┘
```

恢复有三种典型形态：

| 形态 | 用法 |
|------|------|
| 原地恢复 | 把生产库 `appdb` 还原到一个**已知良好的时间点版本**，覆盖现有数据 |
| 异名恢复 | 把 `appdb` 恢复到 `appdb_check`，用于核对/取数，不影响生产 |
| 异机恢复 | 在另一台 VastBase 上从异地服务器拉回 dump 还原（DR 演练） |

下面的脚本三种都支持。


### 11.2 恢复脚本 `/vastbase/scripts/db_restore.sh`

下面脚本把数据库名白名单校验、远端拉回、MD5/SHA256 校验、交互确认、重建库、并行恢复和恢复后 ANALYZE 集成到一处。生产恢复前仍需按变更流程完成审批，并建议先异名恢复核对数据。

```bash
#!/bin/bash
#==============================================================================
# db_restore.sh —— VastBase G100 单库恢复（支持远端拉回 / 异名恢复）
# 注意：本脚本假定源 dump 与目标实例均为 B（MySQL） 兼容模式；如需跨兼容模式恢复，
#       请先手工建库并完成 SQL/对象兼容性改写，不要直接套用本脚本。
#==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/backup.env" || exit 2

usage() {
cat <<EOF
Usage: $0 -d <dbname> [options]
  -d <dbname>       源数据库名（必填，用于匹配 dump 文件）
  -f <dump_file>    指定具体 .dump 文件（绝对路径）
  -D <YYYY-MM-DD>   指定备份日期目录（缺省用最新）
  -r                从远端 (${REMOTE_HOST}) 拉取备份再恢复
  -n <new_dbname>   异名恢复到新库；缺省覆盖源库
  -j <jobs>         恢复并行度（默认 4）
  -F                跳过交互确认（仅限自动化演练）
  -x                跨环境恢复：用 --no-owner --no-privileges（目标实例无对应角色时才用）。
                    缺省保留 owner 与权限（同实例恢复必须，否则 appuser 等会丢访问权）。
  -h                帮助
EOF
exit 1
}

DB=""; DUMP_FILE=""; SPEC_DATE=""; NEW_NAME=""; JOBS=4
USE_REMOTE=0; FORCE=0; NOACL=0

while getopts "d:f:D:rn:j:Fxh" opt; do
    case $opt in
        d) DB="$OPTARG" ;;
        f) DUMP_FILE="$OPTARG" ;;
        D) SPEC_DATE="$OPTARG" ;;
        r) USE_REMOTE=1 ;;
        n) NEW_NAME="$OPTARG" ;;
        j) JOBS="$OPTARG" ;;
        F) FORCE=1 ;;
        x) NOACL=1 ;;
        h|*) usage ;;
    esac
done
[[ -z "$DB" ]] && usage

TARGET_DB="${NEW_NAME:-$DB}"
TS=$(date +%F_%H%M%S)
RESTORE_LOG="${LOG_DIR}/restore_${TARGET_DB}_${TS}.log"
mkdir -p "$LOG_DIR"

say()  { echo "[$(date '+%F %T')] $*" | tee -a "$RESTORE_LOG"; }
die()  { say "ERROR: $*"; exit 1; }
valid_ident() { [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]{0,62}$ ]]; }
normalize_dbcompat() {
    # 兼容不同 VastBase/openGauss 补丁中 datcompatibility 的字面值差异。
    # 输出统一短码：A / B / C / PG / SQLSERVER / unknown。
    local v="${1:-unknown}"
    v="$(printf '%s' "$v" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
    case "$v" in
        A|ORA|ORACLE) echo "A" ;;
        B|MYSQL) echo "B" ;;
        C|TD|TERADATA) echo "C" ;;
        PG|POSTGRES|POSTGRESQL) echo "PG" ;;
        SQLSERVER|SQL_SERVER|MSSQL) echo "SQLSERVER" ;;
        ""|UNKNOWN) echo "unknown" ;;
        *) echo "$v" ;;
    esac
}

require_cmds VB_SQL VB_RESTORE || die "required VastBase tools missing"
valid_ident "$DB" || die "invalid source db name: $DB"
valid_ident "$TARGET_DB" || die "invalid target db name: $TARGET_DB"
[[ "$JOBS" =~ ^[0-9]+$ && "$JOBS" -ge 1 && "$JOBS" -le 32 ]] || die "invalid jobs: $JOBS"

say "===== Restore START db=$DB target=$TARGET_DB ====="

# ---- 1. 定位 dump 文件 ----
if [[ -z "$DUMP_FILE" ]]; then
    if [[ $USE_REMOTE -eq 1 ]]; then
        if [[ -z "$SPEC_DATE" ]]; then
            SPEC_DATE=$(ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
                        "ls -1 '${REMOTE_DIR}' | grep -E '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' | sort -r | head -1" 2>>"$RESTORE_LOG")
            [[ -z "$SPEC_DATE" ]] && die "no backup directory on remote"
        fi
        [[ "$SPEC_DATE" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]] || die "bad date: $SPEC_DATE"
        STAGE="${BACKUP_DIR}/_restore_stage/${SPEC_DATE}_${TS}"
        mkdir -p "$STAGE"
        say "pulling remote backup ${DB}_*.dump from ${REMOTE_DIR}/${SPEC_DATE}"
        rsync_sys -avz -e "env -u LD_LIBRARY_PATH ssh $SSH_OPTS" \
              "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/${SPEC_DATE}/${DB}_*" \
              "${STAGE}/" >>"$RESTORE_LOG" 2>&1 || die "rsync from remote failed"
        DUMP_FILE=$(ls -1t "${STAGE}/${DB}_"*.dump 2>/dev/null | head -1)
    else
        if [[ -n "$SPEC_DATE" ]]; then
            [[ "$SPEC_DATE" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]] || die "bad date: $SPEC_DATE"
            SEARCH="${BACKUP_DIR}/${SPEC_DATE}"
        else
            SEARCH="${BACKUP_DIR}"
        fi
        DUMP_FILE=$(find "$SEARCH" -name "${DB}_*.dump" -type f 2>/dev/null | sort -r | head -1)
    fi
fi
[[ -n "$DUMP_FILE" && -f "$DUMP_FILE" ]] || die "dump file not found"
say "Dump file: $DUMP_FILE ($(numfmt --to=iec "$(stat -c %s "$DUMP_FILE")"))"

# ---- 2. 校验 manifest ----
MAN="${DUMP_FILE%.dump}.manifest"
if [[ -f "$MAN" ]]; then
    EXPECT_SHA=$(awk '/^sha256:/{print $2}' "$MAN" | head -1)
    EXPECT_MD5=$(awk '/^md5:/{print $2}' "$MAN" | head -1)
    if [[ -n "$EXPECT_SHA" ]]; then
        ACT_SHA=$(sha256sum "$DUMP_FILE" | awk '{print $1}')
        [[ "$EXPECT_SHA" == "$ACT_SHA" ]] || die "SHA256 mismatch: expect=$EXPECT_SHA actual=$ACT_SHA"
        say "SHA256 verified: $ACT_SHA"
    elif [[ -n "$EXPECT_MD5" ]]; then
        ACT_MD5=$(md5sum "$DUMP_FILE" | awk '{print $1}')
        [[ "$EXPECT_MD5" == "$ACT_MD5" ]] || die "MD5 mismatch: expect=$EXPECT_MD5 actual=$ACT_MD5"
        say "MD5 verified: $ACT_MD5"
    fi

    SRC_COMPAT=$(awk -F: '/^dbcompatibility:/{gsub(/^[ 	]+|[ 	]+$/, "", $2); print $2; exit}' "$MAN")
    EXPECT_COMPAT="B"
    SRC_COMPAT_N=$(normalize_dbcompat "$SRC_COMPAT")
    EXPECT_COMPAT_N=$(normalize_dbcompat "$EXPECT_COMPAT")
    if [[ -n "$SRC_COMPAT_N" && "$SRC_COMPAT_N" != "unknown" && "$SRC_COMPAT_N" != "$EXPECT_COMPAT_N" ]]; then
        die "dump compatibility mismatch: source=$SRC_COMPAT(normalized=$SRC_COMPAT_N), this restore script expects=$EXPECT_COMPAT_N; please create target DB manually and convert SQL if cross-compat restore is required"
    fi
    [[ -n "$SRC_COMPAT" ]] && say "source dbcompatibility=$SRC_COMPAT normalized=$SRC_COMPAT_N verified for this script"
else
    say "WARN: no manifest, checksum and compatibility check skipped"
fi

# dump 头部可读性检查
"$VB_RESTORE" -l "$DUMP_FILE" >/dev/null 2>>"$RESTORE_LOG" || die "dump cannot be listed by restore tool"

# ---- 3. 交互确认 ----
if [[ $FORCE -eq 0 ]]; then
    echo ""
    echo "  >>> 即将 DROP 并重建数据库: ${TARGET_DB}"
    echo "  >>> 数据源 dump 文件     : ${DUMP_FILE}"
    echo ""
    read -r -p "  请输入 'YES' 确认继续: " ans
    [[ "$ans" == "YES" ]] || { say "user aborted"; exit 0; }
fi

# ---- 4. 断开会话 + 重建库 ----
say "terminating sessions on $TARGET_DB"
vb_sql postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${TARGET_DB}' AND pid <> pg_backend_pid();" >>"$RESTORE_LOG" 2>&1

say "dropping and recreating $TARGET_DB"
# 本版 CREATE DATABASE 不接受 DBCOMPATIBILITY 选项（见 §8.2）：兼容模式由 initdb 实例级设置经
# template0 继承，须确保实例默认即为 B。ON_ERROR_STOP=1 让 CREATE 失败立即非零返回，
# 避免“已 DROP 未重建”却继续往下跑导致空库覆盖。
vb_sql postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS ${TARGET_DB}; CREATE DATABASE ${TARGET_DB} WITH ENCODING='UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE=template0;" \
    >>"$RESTORE_LOG" 2>&1 || die "drop/create failed"

# 校验新库兼容模式与 dump 一致（B），不一致立即中止，防止 A 模式空库覆盖生产
NEWCOMPAT=$(normalize_dbcompat "$(vb_sql postgres -At \
    -c "SELECT datcompatibility FROM pg_database WHERE datname='${TARGET_DB}';" 2>>"$RESTORE_LOG")")
[[ "$NEWCOMPAT" == "B" ]] || die "recreated ${TARGET_DB} compatibility=$NEWCOMPAT (expect B); fix instance/template default before restore"

# ---- 5. 恢复 ----
say "restoring jobs=$JOBS"
# 默认保留 owner + 权限（同实例恢复必须，否则 appuser/rouser 会丢访问权）。
# 这要求目标实例已存在对应角色：全实例 DR 时先按 §11.4 恢复 globals（角色、表空间）。
# -x（NOACL=1）才加 --no-owner --no-privileges，仅用于目标无对应角色的跨环境恢复。
OWNER_OPTS=""
if [[ $NOACL -eq 1 ]]; then
    OWNER_OPTS="--no-owner --no-privileges"
    say "WARN: -x set, restoring WITHOUT owner/privileges (cross-env mode)"
fi

# 恢复阶段输出单独落一个日志 VBRESTORE_LOG，再并入主日志做审计。
# 错误扫描只看“恢复阶段日志”，绝不扫前面 DROP DATABASE IF EXISTS / CREATE DATABASE
# 阶段的输出——否则当目标库原本不存在时（异名恢复 -n 新建库、或 -r 拉回到已手工
# drop 的库），DROP ... IF EXISTS 打出的良性提示
#     NOTICE:  database "<db>" does not exist, skipping
# 会被下面的 'does not exist' 命中，造成“恢复明明成功却报对象错误、库被判 not trustworthy”
# 的误报（exit=0 但 say ERROR）。
VBRESTORE_LOG="${RESTORE_LOG%.log}.vbrestore.log"
: > "$VBRESTORE_LOG"
# RESTORE_EXTRA_OPTS 用于 V3.0.8PSU4 增强选项，如 --stat-obj --validate-obj；默认空。
# shellcheck disable=SC2086
if vb_restore_db "$TARGET_DB" ${OWNER_OPTS} \
              ${RESTORE_EXTRA_OPTS:-} -j "$JOBS" -v "$DUMP_FILE" >>"$VBRESTORE_LOG" 2>&1; then
    say "vb_restore exit=0"
    cat "$VBRESTORE_LOG" >>"$RESTORE_LOG"
else
    cat "$VBRESTORE_LOG" >>"$RESTORE_LOG"
    die "restore failed (vb_restore non-zero); check $RESTORE_LOG"
fi

# 关键：vb_restore 即便有对象级错误（如 B 模式 DDL 在 A 模式失败）也可能 exit 0。
# 必须显式扫描恢复阶段日志错误，否则 "restore OK" 是假成功，会得到一个缺表的空壳库。
# 扫描范围限定 VBRESTORE_LOG（仅恢复阶段输出）；并再排除 DROP ... IF EXISTS 的良性
# "... does not exist, skipping" 提示，双重防止异名 / 远端恢复时误报，
# 同时保留对真实 "ERROR: ... does not exist"（角色 / schema 缺失等）的检测能力。
ERR_RE='error:|could not|does not exist|not recognized|errors ignored on restore'
BENIGN_RE='does not exist, skipping'
ERR_LINES=$(grep -iE "$ERR_RE" "$VBRESTORE_LOG" | grep -ivcE "$BENIGN_RE" || true)
if [[ "${ERR_LINES:-0}" -gt 0 ]]; then
    say "restore reported ${ERR_LINES} error line(s) — target may be INCOMPLETE:"
    grep -iE "$ERR_RE" "$VBRESTORE_LOG" | grep -ivE "$BENIGN_RE" \
        | tail -20 | sed 's/^/  > /' | tee -a "$RESTORE_LOG"
    die "restore completed WITH object errors; $TARGET_DB is not trustworthy"
fi

# ---- 6. ANALYZE 与核对 ----
say "ANALYZE"
vb_sql "$TARGET_DB" -c "ANALYZE;" >>"$RESTORE_LOG" 2>&1 || say "ANALYZE warning"

# 只数用户表（排除系统目录），避免被 150+ 张系统表掩盖“用户表没还原”的事实。
USER_TBL=$(vb_sql "$TARGET_DB" -At -c "SELECT count(*) FROM pg_stat_user_tables;" 2>>"$RESTORE_LOG")
say "User tables in $TARGET_DB after restore: ${USER_TBL:-unknown}"
[[ "${USER_TBL:-0}" -ge 1 ]] || die "no user tables after restore; check compatibility mode and $RESTORE_LOG"
say "restore OK"
say "===== Restore DONE target=$TARGET_DB ====="
```

授权：

```bash
chmod 750 /vastbase/scripts/db_restore.sh
chown vastbase:dbgrp /vastbase/scripts/db_restore.sh
su - vastbase -c 'bash -n /vastbase/scripts/db_restore.sh'
```

> 与 `db_backup.sh` 同源：本脚本经 `backup.env` 的 `vb_sql` / `vb_restore_db` 封装连库（口令从 `.pgpass` 经 `--pipeline` 注入，无明文）、ssh/rsync 走 `ssh_sys`/`rsync_sys`（剥离 `LD_LIBRARY_PATH`）。部署前确认 `vb_restore` 支持 `--pipeline`：
>
> ```bash
> source /vastbase/scripts/backup.env
> "$VB_RESTORE" --help | grep -- '--pipeline' || echo "本版 vb_restore 无 --pipeline，见下方降级说明"
> ```
>
> 若本版 `vb_restore` 无 `--pipeline`（少见），把 `vb_restore_db` 改为在子 shell 内临时 `export PGPASSWORD`（用完即随子 shell 销毁、不进父环境、不上命令行），其余封装不变。

### 11.3 典型恢复场景速查

#### A. 误删表，需要回滚到昨天 02:00 备份点（覆盖生产）

```bash
# 1) 先备份当前现状（事故现场快照），以防恢复后还想取数
$VB_DUMP -h 127.0.0.1 -U vbadmin -F c -f /tmp/appdb_before_restore.dump appdb

# 2) 用本地最新备份直接还原
/vastbase/scripts/db_restore.sh -d appdb
```

#### B. 不动生产，先恢复到检查库取数

```bash
/vastbase/scripts/db_restore.sh -d appdb -n appdb_check
# 然后从 appdb_check 里把误删表导回生产
$VB_DUMP -h 127.0.0.1 -U vbadmin -F p -t app.t_lost \
        -f /tmp/t_lost.sql appdb_check
$VB_SQL -h 127.0.0.1 -U vbadmin -d appdb -f /tmp/t_lost.sql
```

#### C. DR 演练：在异地或新机器上从备份服务器拉回还原

```bash
# 假设这是一台全新的 VastBase 主机，scripts 已部署、backup.env 已配置
/vastbase/scripts/db_restore.sh -d appdb -r  -n appdb_drill_remote            # 拉最新
/vastbase/scripts/db_restore.sh -d appdb -r -D 2026-05-10   # 拉指定日期
```

### 11.4 全局对象（角色、表空间）恢复

如果是全实例级灾难，需要先恢复全局对象，再恢复各业务库：

```bash
# 0) 跨机/裸机恢复前置（关键，见 §11.4.1）：globals 不导出 initdb 阶段创建的初始账户
#    （三权分立 vbadmin/vbaudit/vbsso 等，oid<16384），它们由目标实例 initdb 时各自重建。
#    用相同方式初始化的目标机这些账户已存在（口令为目标机的值）——核对存在性即可：
#      vb_sql postgres -c "SELECT oid,rolname FROM pg_authid WHERE oid<16384 ORDER BY oid;"
#    仅当目标缺少被引用为 owner 的账户（如 vbadmin）时才手工补建，否则下一步
#    CREATE TABLESPACE ... OWNER vbadmin 会因 owner 不存在而失败：
#      vb_sql postgres -c "CREATE ROLE vbadmin WITH LOGIN SYSADMIN PASSWORD '<目标机口令>';"

# 1) 恢复角色、表空间：自动选择最近一份 globals 备份，避免复制示例日期后忘记修改。
#    需先 source backup.env 以加载 vb_sql 封装（工具不消费 .pgpass，口令经 pipeline 注入）。
#    注意：本版 globals 中已存在的角色会报 "already exists"（良性，口令不被覆盖），但随后的
#    ALTER ROLE ... WITH 会重置其属性/权限；不想扰动目标既有账户权限时，见 §11.4.1。
LATEST_GLOBALS=$(ls -1t /vastbase/backup/*/globals_*.sql 2>/dev/null | head -1)
[[ -n "$LATEST_GLOBALS" ]] || { echo "globals backup not found"; exit 1; }
vb_sql postgres -f "$LATEST_GLOBALS"

# 2) 逐库恢复。db_restore.sh -F 内部自带 DROP/CREATE 目标库（同实例重建），可反复执行。
#    单业务库直接 `for db in appdb`；多业务库按 databases.list 循环（跳过空行与 # 注释行）。
DB_LIST=/vastbase/scripts/databases.list
while read -r db; do
    db="${db%%#*}"; db="$(echo "$db" | xargs)"   # 去注释、去首尾空白
    [[ -z "$db" ]] && continue
    /vastbase/scripts/db_restore.sh -d "$db" -F
done < "$DB_LIST"
# 单库场景（不读清单）等价写法：
#   for db in appdb; do /vastbase/scripts/db_restore.sh -d "$db" -F; done
```

> **裸机恢复时的库级属性还原（配合 §10.4 生成的 `*.create.sql`）**
>
> `db_restore.sh` 内部用的是一条**最小化** `CREATE DATABASE`（仅 ENCODING/LC_COLLATE/LC_CTYPE/TEMPLATE，见 §11.2），它**不还原属主、表空间、连接数上限与库级 `ALTER DATABASE ... SET`**。同实例恢复时这些属性本就还在、无碍；但在**全新/异机**上，要忠实还原这些库级属性，请改用基于 `*.create.sql` 的手工序列（绕开 `db_restore.sh` 的最小化重建）：
>
> ```bash
> # 前提：目标实例已 initdb 为 B（MySQL）兼容模式；globals 已恢复（角色、表空间已存在，
> #       且表空间 LOCATION 指向的目录在本机已 mkdir 并属主正确）。
> DAY=/vastbase/backup/2026-05-25          # 按实际备份日期
> source /vastbase/scripts/backup.env
> 
> # 先还原全局对象（角色、表空间）。globals_*.sql 只有一个文件，可直接 -f。
> vb_sql postgres -f ${DAY}/globals_*.sql
> 
> # ── a) 逐库建库（用备份时抓取的精确属性：owner/tablespace/连接数/库级 SET）─────────────
> #    ★ v1.41 修复：vsql 的 -f 只接受**一个**文件参数。旧写法
> #         vb_sql postgres -f "${DAY}/"*.create.sql
> #      通配会展开成 N 个文件，-f 只吃字母序第一个（admin_center），其余被当多余位置参数
> #      "extra command-line argument ... ignored" 丢弃——结果只建出一个库。必须用循环逐文件执行。
> 
> # ★ v1.42：直接比对哈希、不走 `sha256sum -c`。原因：旧版 sidecar 里写死了备份时
> #   .running.<ts> 临时目录的**绝对路径**（mv 成最终目录后即不存在），`-c` 在任何机器都会
> #   报 "No such file or directory / FAILED open or read"。比对哈希忽略路径，对旧坏 sidecar
> #   与 v1.42 修复后的 basename sidecar 都适用，无需重做备份。
> for f in "${DAY}/"*.create.sql; do
> want=$(awk '{print $1}' "${f}.sha256"); got=$(sha256sum "$f" | awk '{print $1}')
> [[ "$want" == "$got" ]] || { echo "校验失败，跳过: $f"; continue; }
> echo ">>> create db <- $(basename "$f")"
> vb_sql postgres -f "$f"      # create.sql 内含 \set ON_ERROR_STOP on，建库出错即止于该文件
> done
> # postgres/vastbase 是系统库、目标 initdb 后已存在，其 create.sql 会报 "already exists"（良性，可忽略）。
> 
> # ── b) 逐库灌数据 ───────────────────────────────────────────────────────────────────────
> #    库名不能按 '_' 切分（ai_helper/authx_service 等含下划线）；备份名固定为
> #    <db>_<YYYY-MM-DD>_<HHMMSS>.dump，日期用连字符、库名后恰好跟两个下划线，
> #    用 ${base%_*_*.dump} 去掉最短的 "_<date>_<time>.dump" 后缀即精确得到库名。
> #    ★ 务必灌入**空库**（刚由上一步 create.sql 建出）。vb_restore 默认不 drop 已存在对象，
> #      往已有数据的库里重复灌会刷满 "already exists / duplicate key / multiple primary keys"
> #      （非致命、最终仍报 successful，但纯属重复执行的噪声）。重做某库须先 DROP 重建再灌。
> 
> # ★ v1.44：vb_restore -v 输出极多、屏幕一闪而过。把每库重输出落盘到带时间戳的日志，
> #   屏幕只留每库 OK/FAIL 摘要；事后用 grep 在日志里筛错，不必盯屏。
> 
> # 若目标缺少与源端一致的角色，追加 --no-owner --no-privileges，并按目标策略另行授权。
> 
> FAILED=0
> 
> RESTORE_LOG="${RESTORE_LOG:-/vastbase/backup/restore_$(date +%F_%H%M%S).log}"
> echo "灌数日志 -> $RESTORE_LOG"
> for dump in "${DAY}"/*.dump; do
> base=$(basename "$dump")
> db=${base%_*_*.dump}
> case "$db" in
>   postgres|vastbase|template0|template1) echo "  skip system db: $db"; continue ;;
> esac
> echo ">>> restore $db <- $base" | tee -a "$RESTORE_LOG"
> 
> if vb_restore_db "$db" -j 4 -v "$dump" >>"$RESTORE_LOG" 2>&1; then
>   echo "    OK:   $db"
> else
>   rc=$?; echo "    FAIL: $db (rc=$rc，详见 $RESTORE_LOG)"; FAILED=$((FAILED+1))
> fi
> done
> [[ $FAILED -eq 0 ]] && echo "ALL OK" || echo "$FAILED db(s) FAILED"
> # 事后筛错：往**空库**灌正常情况下不应出现 already exists / duplicate key；若出现，多半是没灌空库或重复执行。
> grep -nE "ERROR|could not|duplicate key|already exists|multiple primary keys|FAIL" "$RESTORE_LOG" | head -50
> # 每库正常结尾都有一行 "restore operation successful"；统计成功库数，应等于业务库数：
> grep -c "restore operation successful" "$RESTORE_LOG"
> 
> # ── c) 校正/核对 search_path（★ v1.41 新增，必做）──────────────────────────────────────
> #    建库 DDL 已由 §10.4 修复版生成正确的裸标识符列表 search_path；这里二次核对，
> #    若发现哪个库的 search_path 回显成带引号的"单段值"（历史坏备份遗留），逐库改回正确形式：
> #       ALTER DATABASE <db> SET search_path = <schema>, public;   -- 注意：不要加外层单引号
> #    search_path 在**建立连接时**生效，改完须断开重连（应用同理）才看得到表；数据无需重灌。
> 
> # 只在"整段被一对引号包住、逗号落在引号内"时告警（坏形态如  "ai_helper, public"  ——单个不存在的 schema）。
> # 不要用 *\"* ——默认值 "$user",public 的引号是套在 $user 上、逗号在引号外，是正常两段式列表，会误报。
> # 判据：引号 → 任意 → 逗号 → 任意 → 引号  全在一段里，才是坏值（用 WARN: 而非 !!，避免交互粘贴触发历史展开）。
> 
> for dump in "${DAY}"/*.dump; do
> base=$(basename "$dump"); db=${base%_*_*.dump}
> case "$db" in postgres|vastbase|template0|template1) continue ;; esac
> sp=$(vb_sql "$db" -At -c "SHOW search_path")
> echo "$db: search_path = $sp"
> case "$sp" in
>   *\"*,*\"*) echo "   WARN: 可疑 search_path（疑似引号包整串），请核对并按上面 ALTER DATABASE 改正" ;;
> esac
> done
> 
> # ── d) 恢复侧逐库表数（本机），落盘到文件便于比对 ──────────────────────────────────────
> #    口径与生产侧 e) 完全一致（pg_stat_user_tables，已自动排除 pg_catalog/information_schema/pg_toast）。
> #    注：表计数与统计信息新旧无关，可不跑 ANALYZE；这里保留仅为顺带刷新统计。
> REST_CNT=/tmp/restore_tablecount_$(date +%F).txt
> for dump in "${DAY}"/*.dump; do
> base=$(basename "$dump"); db=${base%_*_*.dump}
> case "$db" in postgres|vastbase|template0|template1) continue ;; esac
> n=$(vb_sql "$db" -At -c "SELECT count(*) FROM pg_stat_user_tables;")
> echo "$db $n"
> done | sort > "$REST_CNT"
> column -t "$REST_CNT"; echo "已存 -> $REST_CNT"
> ```
>
> ```bash
> # ── e) 生产侧逐库表数（★ 在原生产库 vbdb01 上执行），同口径落盘 ────────────────────────
> #    生产上库名从 pg_database 取（裸机目录拿不到）。EXCL 视现场决定是否排除 appdb 系列。
> EXCL="'postgres','template0','template1','vastbase'"
> for db in $(vb_sql postgres -At -c \
> "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ($EXCL) ORDER BY 1"); do
>  n=$(vb_sql "$db" -At -c "SELECT count(*) FROM pg_stat_user_tables;")
>  echo "$db $n"
> done | sort > /tmp/prod_tablecount_$(date +%F).txt
> column -t /tmp/prod_tablecount_$(date +%F).txt
> ```
>
> ```bash
> # ── f) 差异比对（★ v1.44 新增，恢复验收必做）：把生产侧 e) 的文件拷到本机，与 d) 比对 ──────
> #    join 同时暴露两类问题：① 某库只在生产有、恢复侧没有 → **整库漏备/漏恢复**（如本现场的 dog）；
> #                          ② 两侧都有但表数不一致 → 该库部分对象未恢复。
> PROD_CNT=/tmp/prod_tablecount_$(date +%F).txt     # 从 vbdb01 scp 过来
> REST_CNT=/tmp/restore_tablecount_$(date +%F).txt
> echo "== 只在生产、恢复侧缺失的库（整库漏备/漏恢复，重点核查 databases.list 是否把它注释掉了）=="
> comm -23 <(cut -d' ' -f1 "$PROD_CNT") <(cut -d' ' -f1 "$REST_CNT")
> echo "== 只在恢复侧、生产没有的库（一般为演练/异名库，正常）=="
> comm -13 <(cut -d' ' -f1 "$PROD_CNT") <(cut -d' ' -f1 "$REST_CNT")
> echo "== 两侧都有但表数不一致的库（应为空）=="
> join "$PROD_CNT" "$REST_CNT" | awk '$2!=$3{printf "  %-22s prod=%s restore=%s\n",$1,$2,$3}'
> echo "比对完成；以上三段均为空才算恢复完整。"
> ```
>
> > **★ 本现场实测发现（v1.44）：** f) 的第一段查出 `dog` ——生产有 `dog` 库（5 张表）、`dog` 角色与
> > `tbs_dog` 表空间都在 globals 里，但**备份集没有 `dog_*.dump`**，恢复侧因此缺这个库。根因见 §10.3.2：
> > `databases.list` 把 `dog` 当**排除示例注释掉了**（`# dog`），而自动发现规则视"注释行为人工排除、不回填"，
> > 于是这个真业务库被静默漏备。处置：确认 `dog` 是否需保护——需要就在生产 `databases.list` 里**取消 `dog` 的注释**
> > （或显式加一行 `dog`）后重跑备份；确属可弃才保留注释。**逐库表数比对（d/e/f）应纳入每次恢复/演练的验收项**，
> > 它是唯一能抓出"整库漏备"这类清单缺漏的手段（search_path、单库灌数日志都看不出某个库压根没进备份集）。
>
> **关于"表没还原成功"的常见误判（v1.41 现场定位）：** 带库级 `search_path` 的库若用旧版坏备份
> （`SET search_path = 'ai_helper, public'` 单引号包整串）恢复，表其实已全部灌入对应 schema，
> 但 search_path 指向不存在的单段 schema，导致 `\dt`／不加 schema 前缀的查询都看不到表，极易误判为
> "未还原"。验证数据在不在用 **schema 全限定名**即可：`SELECT count(*) FROM <db>.<表>;` 或 `\dt <db>.*`。
> 修复只需上面 c) 步的 `ALTER DATABASE ... SET search_path = <schema>, public;` 再重连，**无需重灌**。
> 补充：`SET ... TO` 与 `SET ... =` 完全等价，**`TO`/`=` 不是病因**，病因是把多 schema 列表用单引号包成了一个字符串。

#### 11.4.1 角色与口令的存放、备份覆盖范围与跨机恢复处置（V3.0.8PSU4 实测）

**口令存在哪。** 角色（用户）是**实例级全局对象**，存放在共享系统表 `pg_authid` 的 `rolpassword` 列（物理上位于 `$PGDATA/global/`，所有库共享同一份），**不属于任何业务库，也不在 `postgres`/`vastbase` 库里**。连到任意库都能查到，但它不归某个库所有。`pg_roles`/`pg_user` 视图会把口令打码成 `********`，要看密文须查 `pg_authid`（用初始超级用户连）：

```bash
vb_sql postgres -c "SELECT rolname, rolpassword FROM pg_authid WHERE rolname='vbadmin';"
```

备份产物的覆盖范围：逐库 `*.dump`（`vb_dump -F c`）**完全不含角色/口令**；`*.create.sql` 只含建库 DDL；**只有 `globals_*.sql`（`vb_dumpall -g`）承载角色与口令**。

**本版 `globals_*.sql` 的实测事实**（据现场文件）：

- 每个角色以 `CREATE ROLE <name> PASSWORD 'sha256...'` + 紧随一条**不带口令**的 `ALTER ROLE <name> WITH <属性>` 形式导出。`sha256...` 是口令校验值（hash），跨机恢复后该角色仍以**与源端相同的明文口令**登录——口令以 hash 形式被带走。
- 表空间以 `CREATE TABLESPACE ... OWNER <role> RELATIVE LOCATION '...'` 导出，并含 `ALTER ROLE ... [IN DATABASE ...] SET search_path` 等设置。
- **哪些角色会/不会被导出（按 OID 区分，现场 `pg_authid` 实测规律）：**
  - **会导出**：引导超级用户 `vastbase`（`oid=10`，与 OS 同名）+ 所有用户自建角色（`oid≥16384`，如各业务库同名账户、`cat`/`dog` 等）。
  - **不会导出**：`initdb` 阶段创建的初始系统/管理账户（`oid<16384`）——本现场即 `vbadmin`(33)、`vbaudit`(34)、`vbsso`(35)、`vb_read_all_settings`(37)，以及内置 `gs_role_*`(1044–1059)。这些是 VastBase 三权分立模型的固定账户（`vbadmin`=系统管理员、`vbaudit`=审计管理员、`vbsso`=安全管理员），被视作"每台实例 `initdb` 时各自重建"的初始账户，故不进逻辑备份。
- **由此带来的后果**：`vbadmin`(及 `vbaudit`/`vbsso`)的口令**根本不在备份里**；其中只有 `vbadmin` 因被多处用作表空间/数据库 OWNER，才会被下面的 `comm` 自查命令抓到，但 `vbaudit`/`vbsso` 同样缺席。裸机恢复 globals 时，若目标实例上 `vbadmin` 不存在，`CREATE TABLESPACE ... OWNER vbadmin` 会因 owner 缺失而失败。

> 在你的实例上自查（按现场结果处置，勿照搬）：
>
> ```bash
> G=$(ls -1t /vastbase/backup/*/globals_*.sql | head -1)
> # 1) 谁是引导超级用户（oid=10）、各角色及其超级权限
> vb_sql postgres -c "SELECT oid, rolname, rolsuper, rolsystemadmin FROM pg_authid ORDER BY oid;"
> # 2) globals 里"被当 OWNER 引用、却没有 CREATE ROLE"的角色（跨机恢复前必须先手工建好）
> comm -13 \
>   <(grep -oE 'CREATE ROLE [A-Za-z_][A-Za-z0-9_]*' "$G" | awk '{print $3}' | sort -u) \
>   <(grep -oE 'OWNER [A-Za-z_][A-Za-z0-9_]*'        "$G" | awk '{print $2}' | sort -u)
> # 3) 各角色是否带口令、属性如何（安全自查）
> grep -E 'CREATE ROLE|ALTER ROLE .* WITH' "$G"
> ```
>
> 现场实测结果（节选）：命令 1 返回 `vastbase(10)`、`vbadmin(33)`、`vbaudit(34)`、`vbsso(35)`、`vb_read_all_settings(37)`、`gs_role_*(1044–1059)` 及业务角色（`oid≥16384`）；命令 2 仅输出 `vbadmin`（被引用为 OWNER 却未导出的角色）。可据此确认本实例的"缺口管理账户"清单，再决定跨机恢复时如何补齐。

```bash
[vastbase@vbdb01 scripts]$ G=$(ls -1t /vastbase/backup/*/globals_*.sql | head -1)
[vastbase@vbdb01 scripts]$ echo $G
/vastbase/backup/2026-06-23/globals_2026-06-23_174001.sql
[vastbase@vbdb01 scripts]$ vb_sql postgres -c "SELECT oid, rolname, rolsuper, rolsystemadmin FROM pg_authid ORDER BY oid;"
  oid  |         rolname          | rolsuper | rolsystemadmin 
-------+--------------------------+----------+----------------
    10 | vastbase                 | t        | t
    33 | vbadmin                  | t        | t
    34 | vbaudit                  | f        | f
    35 | vbsso                    | f        | f
    37 | vb_read_all_settings     | f        | f
  1044 | gs_role_copy_files       | f        | f
  1045 | gs_role_signal_backend   | f        | f
  1046 | gs_role_tablespace       | f        | f
  1047 | gs_role_replication      | f        | f
  1048 | gs_role_account_lock     | f        | f
  1055 | gs_role_pldebugger       | f        | f
  1056 | gs_role_directory_create | f        | f
  1059 | gs_role_directory_drop   | f        | f
 26935 | platform_openapi         | f        | f
 26941 | authx_service            | t        | f
 26947 | cas_server               | t        | f
 26953 | admin_center             | f        | f
 26959 | message                  | t        | f
 26965 | transaction_service      | t        | f
 26971 | formflow                 | t        | f
 26977 | fileupload               | t        | f
 26983 | powerjob                 | t        | f
 26990 | jobs_server              | t        | f
 27384 | reservation              | t        | f
 27390 | question_feedback        | t        | f
 70558 | aihelper                 | f        | t
 71048 | ai_helper                | t        | t
 88321 | dog                      | f        | f
 88327 | cat                      | t        | f
(29 rows)

[vastbase@vbdb01 scripts]$ comm -13 \
> <(grep -oE 'CREATE ROLE [A-Za-z_][A-Za-z0-9_]*' "$G" | awk '{print $3}' | sort -u) \
> <(grep -oE 'OWNER [A-Za-z_][A-Za-z0-9_]*'        "$G" | awk '{print $2}' | sort -u)
vbadmin
[vastbase@vbdb01 scripts]$ grep -E 'CREATE ROLE|ALTER ROLE .* WITH' "$G"
CREATE ROLE admin_center PASSWORD 'sha25639f91e8093ecde1bc82936768ccc73d2f2bd652f0b84ebab86866bb16a83c11ea4adbc11e6ac7209e6ecfea404abb7aac00f1f60368cedbdedd73d5be0e469a888c176822e486534d672abda1549ac7e1c669c3157ad06dd40039df9fc43f809md5593ca57527e2bafc3487680663eb6206ecdfecefade';
ALTER ROLE admin_center WITH NOSUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE ai_helper PASSWORD 'sha256bdc21da21c5944b4fb66569bf59f5d205af48e4f23c11a325dd5bc563b905c707b8bb3d64d249e9999cbc612a977963aef54471bb4ed4015dcd585555bb30469fcf08928bedbf2dbec9573eeab7468dbff3d71223f5f7fea359c102ae3168c0fmd5e89f6c2a4cd8c6153391f327364a4374ecdfecefade';
ALTER ROLE ai_helper WITH SUPERUSER SYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE aihelper PASSWORD 'sha256aaef75d5566522e1771ef6c485f0a37b767a6d9ce3a560cef359d66d26dd73ef0aa40f43726cbbbfaa3d0dd0bafe00002ce53fb3106f31170e522d48d6eeceb3a84926945620b445c1a5dff61ae79d7cf1a75409ca66c50c7b1d5d007e4f93b1md5ecec56efdf17d884193997e8631e7eebecdfecefade';
ALTER ROLE aihelper WITH NOSUPERUSER SYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE authx_service PASSWORD 'sha2564307adbeb447af38654f787a36f5165b955f16d2856fdf606a90abad86566cca2eeb9049464271c837d107484a77bd2293b10ffd254682bc32d38d1879fcf3b5becc6427f3d530208da921f624522d6694f275a6f06e4e8b8995731f522a7203md55ffeddd008b2d210decea3e2987d1c42ecdfecefade';
ALTER ROLE authx_service WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE cas_server PASSWORD 'sha256c475d0408ffb38a65529783f84c839ac0b4afa72315572abd2cb5c066444ad94585b3d913d4461cfaf9e60f329d7b70a8f72552f2125b9f1481f0598f1d0b4b9cdcf2e9b36f4c1c9077950cd14eab72b99a85d3864787e45cc0787dc26517b49md523ab49ae3aecac63532ebc23945628b8ecdfecefade';
ALTER ROLE cas_server WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE cat PASSWORD 'sha2565140edf5017c6a84dd9abbfc736b048ddbd04e7145d466c6f322903220412829b09af4c1d1f6d7ac615c822f6b00680fc0f5fd7fa0f737099446c11eb2f2c8867fecbcbb0692569286ea9380e0f027f23626f418e704e0f02102ed9b56a47d84md5165a87980d434de46b0cfa2c3ff6e518ecdfecefade';
ALTER ROLE cat WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE dog PASSWORD 'sha2560b72f7cb5b7b1ddc5e46655f6dfb286e0615ffcced2e12a60f900c255e1024d49dcf94c4f64fa2293a89fe9b8acb69a7ae70f72adfd1b6c9467108d28d9f7bde3bcac54dbd5ae021070be4766d8969052cd30887c7fa795dbac4f0c33874623fmd50c50a95a94aa779ad22e26633c43039cecdfecefade';
ALTER ROLE dog WITH NOSUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE fileupload PASSWORD 'sha2563a52b8b97070c06ea10020420df25563f6624e8ec15ae38125b33df30bcad04abf770c5b877883ed81e1b3c7748bdf09d032acf17cc477558dde7c40d2e6200036c1f4983c07ba83a0bf99caa8756ded658bb38c08599249720ff257af7e3918md5a16ef939e95e37a873c1ffbfdec397c4ecdfecefade';
ALTER ROLE fileupload WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE formflow PASSWORD 'sha256a7a49db061be36ebe377ecf7375da92af29cf050bccb540a5c307f46c7460d31b260232cbb20d2dcae5829ad0ce30f805acaf64784f993a17ba43435968a9606604a28442dce161b24ce9541a43c78d206b21bb9bcd907dddd7f524f6d770574md53ccb5a21a5d4f9d799e2d3d40aca2640ecdfecefade';
ALTER ROLE formflow WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE jobs_server PASSWORD 'sha256e1458600be7e0947186a818c99f65df889b18448c5f650caaa94856be837a73540789d7e1aafaef4064ad96a9f50a796208362e03eefd36fe3470439e73ef362ef998b2698212727a525d333be0561bb3401b92a027e0e951e64753f7cbc1efdmd5512756e0da8053041b7f947abd385932ecdfecefade';
ALTER ROLE jobs_server WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE message PASSWORD 'sha25647aed0d2039914a766cced80d67456df4ff56ff5377ac33ffad6e63965efd411e1c9d8352ff748955dddbf4f4d910c5f4f38167299e64eab4e789c58bcc2a7e988ca35f060a1d442fd88d7b7b538d3b92ca3d1ca1f81e6a6a2d340293db3ee45md5413ef5459800868e497f391e269a56fdecdfecefade';
ALTER ROLE message WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE platform_openapi PASSWORD 'sha2567fde47bc30a8200cb1a33ae5ffa68d3c11d1da1b1ea550f303618c1c33d04a364f7cfe3b70998e3f2a2c86d7951655d3605ba38fccdce8cf5375698c81d6189f50d99a8c588682b819662cf050a26e3e5f834439402946bd4b7e9d7d8215ad1dmd5147a4f6d790a8a50f31d9db7f0fab487ecdfecefade';
ALTER ROLE platform_openapi WITH NOSUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE powerjob PASSWORD 'sha25624416db41f4d9612ec873747c5cf578564ab94ce588861af010ab848d820331aa95435d6774f0678f2c8dea6232ca9425b710917b770762bec37772708a37215d7e2672b834a5d3b6cd240868377904257a426412298de3cca135012cd5ffab0md596d02006fdf40a13c073bf4e5aea834fecdfecefade';
ALTER ROLE powerjob WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE question_feedback PASSWORD 'sha256eafb49ed333e2b3fd07376f5e26021a9385610c1efc00173771ce48be73f9937ee151cfe142f897106c5dd0486f2bb636dd6d804722f31ef498eb4e2257cad2dc17203d45fa7a725ec2105cd58997a3253daa2f9298465e24fcfb10c82c0952amd5f44b9ed1aa010ed8d6a091059a6944c2ecdfecefade';
ALTER ROLE question_feedback WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE reservation PASSWORD 'sha25665a056b4473b8a3b5dddf30e602bd0ccdeb021a7cc15430f81acc021ec16372d8d26c19d884b3f079fef9cfc0af54262b2a93a65a0738c0fae64fdec0fa86f17d7f66d80bf78141b66705ca91296e392e75d119904fd21c9af28321e94f39ca4md52b21f16d935ace70404461b3d414c78eecdfecefade';
ALTER ROLE reservation WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE transaction_service PASSWORD 'sha25607931c2046e350e85356d64bce7404fa3cf1630bc4523428b5f919954bb1e42984b4509d1aa9382796859056c1dda0f05b077b76ad12a54920f6d64b2c9c3a3bf1a20130d8a05b32c1bc0349a5c7b941da8bd1212174846b29a648046ee134ebmd59601748812738aa6d5b19ba68ee41a0eecdfecefade';
ALTER ROLE transaction_service WITH SUPERUSER NOSYSADMIN INHERIT NOCREATEROLE NOCREATEDB NOUSEFT LOGIN NOREPLICATION NOAUDITADMIN RESOURCE POOL "default_pool";
CREATE ROLE vastbase PASSWORD 'sha2568ec2abf05577ebad6162e680af04fe7760ca339e51498130f2c1cdbc195b72ddab9a68164c7cba7d40f38a032b1f760842e44c844c25d80b9a3a3842cea838879842930c54e772d0712aec1da8fec3f8f857f049e36c74e300baf45aa4cde0e4md5de57ece72bc79df88ecda5f36178db45ecdfecefade';
ALTER ROLE vastbase WITH SUPERUSER SYSADMIN INHERIT CREATEROLE CREATEDB USEFT LOGIN REPLICATION AUDITADMIN MONADMIN OPRADMIN POLADMIN RESOURCE POOL "default_pool";
[vastbase@vbdb01 scripts]$ 
```



**还原会不会改口令——分场景：**

| 场景 | 是否动角色/口令 |
|------|----------------|
| 同实例库级恢复（`db_restore.sh`，日常操作） | **不动。** 脚本只 `DROP/CREATE` 目标**数据库**并灌库内对象，完全不重放 globals、不碰 `pg_authid`。所有角色口令原样不变。 |
| 跨机 / 全实例 DR 恢复 globals | 见下分解 |

跨机恢复 globals 时，按本版"口令只在 `CREATE ROLE`、属性在独立 `ALTER ROLE`"的格式：

- **目标上不存在的角色** → `CREATE ROLE` 成功，按**源端口令**建出（hash 可移植，明文与源端一致）。新机若要不同口令，恢复后另行 `ALTER ROLE ... PASSWORD` 重设。
- **目标上已存在的角色**（如引导超级用户，或目标已建的管理账户）→ `CREATE ROLE` 报 `already exists`（良性，**口令不会被覆盖**）；但随后的 `ALTER ROLE ... WITH <属性>` 会执行，**会把该角色的属性/权限重置为源端值**（可能翻转 SUPERUSER/SYSADMIN/CREATEDB 等）。要保持目标既有权限时，先把对应 `ALTER ROLE` 行删掉再执行。
- **`vbadmin` 这类未出现在 globals 的管理账户** → globals 不创建它，但 `CREATE TABLESPACE ... OWNER vbadmin` 会因 owner 缺失而失败。

因此**跨机/裸机恢复的正确顺序**是：

1. **核对目标实例的初始账户**：用相同 VastBase 安装介质、相同三权分立配置初始化的目标实例，`vbadmin`/`vbaudit`/`vbsso` 会在 `initdb` 时**自动重建**（口令为目标机各自设定）。先 `SELECT rolname FROM pg_authid WHERE oid<16384;` 确认它们已存在；存在则只需**知道/设定这些账户在目标机的口令**（不依赖备份），并相应更新 `~/.pgpass`。仅当目标初始化方式不同导致缺失时，才手工补建被引用为 owner 的账户（如 `vbadmin`），口令按目标机既定策略；
2. 恢复 `globals_*.sql`（角色、表空间）——注意表空间 `RELATIVE LOCATION` 目录会建在 `$PGDATA/pg_location/` 下，库外绝对路径表空间则需目标机预先 `mkdir` 且属主正确；
3. 执行各库 `*.create.sql` 建库（见 §11.4 注记）；
4. `vb_restore` 灌数据；
5. 复核目标机 `~/.pgpass`（`vbadmin` 等初始账户口令为目标机的值，非源端值）。

> **口令属机器级、不应跨机覆盖。** `vbadmin`/`vbaudit`/`vbsso` 等初始账户口令各实例不同、是该实例 `initdb` 时自身设定的属性；它们既不在备份里，DR 时也不该让源端口令去覆盖目标账户。统一原则：初始/登录类管理账户在目标机按既定口令使用或显式重设；业务角色可沿用 globals 重建后再按 §16 口令策略轮换。

**安全与一致性提示（据现场 `pg_authid`/globals，建议复核）：**

- **大量业务角色是超级用户**（`rolsuper=t`，现场实测）：`authx_service`、`cas_server`、`message`、`transaction_service`、`formflow`、`fileupload`、`powerjob`、`jobs_server`、`reservation`、`question_feedback`、`ai_helper`、`cat`。与 §16.1"业务账号应 `NOSUPERUSER`、最小权限"严重相悖——任一应用账号失陷即等于整实例失陷。建议按 §16.1 评审收敛：业务连接账号去掉 `SUPERUSER`/`SYSADMIN`，仅授予其库内必要权限。
- **存在近名角色 `ai_helper`(oid 71048, 超级) 与 `aihelper`(oid 70558, 仅 SYSADMIN) 并存**，疑为历史遗留或命名混淆，建议核实是否冗余、应用实际连的是哪一个，避免清理时误删在用账户。
- `globals_*.sql` 含口令 hash，属敏感文件：权限 600、属主 `vastbase`，异地传输/留存按 §10.7 第 4 点加密。
- 留意命名与落盘不一致：现场 `CREATE TABLESPACE tbs_reservation ... RELATIVE LOCATION 'tbs_preservation'`——位置目录名 `tbs_preservation` 与表空间名 `tbs_reservation` 差一个字母。`RELATIVE LOCATION` 下该目录建在 `$PGDATA/pg_location/tbs_preservation`，功能不受影响，但 DR 排查时目录名与表空间名对不上易困惑，建议知悉或择机统一。

### 11.5 演练与验证

> **铁律：未演练过的备份等于没有备份。**

建议每月一次：

1. 拉一个本地最新 dump，用 `-n {dbname}_drill` 异名恢复；
2. 对比关键表行数 / 业务字段汇总值；
3. 恢复完成后 `DROP DATABASE {dbname}_drill` 释放空间；
4. 把演练结果（耗时、是否成功、问题点）记入运维日志。

```bash
# 演练脚本片段
for db in cat dog fox; do
    /vastbase/scripts/db_restore.sh -d $db -n ${db}_drill -F \
        && echo "[$db] drill OK" \
        || echo "[$db] drill FAIL"
done
```

---

### 11.6 清理重置（演练 / 重恢复前的目标实例清场）

> **适用场景**：在裸机/演练目标机上，已经恢复过一批业务库，现在要**清掉旧恢复物、再重放一份新备份**（换备份日期、换源、或重做一次完整演练）。**本节只清"恢复进来的业务对象"，绝不碰目标机自有对象。**

> **⚠️ 红线安全闸（执行任何 DROP 前必跑，不通过就停手）**
> 本现场业务角色几乎全是 `Superuser`，下面的批量 `DROP` 在生产库上等同灾难。先确认"在对的机器、没人在连"：
>
> ```bash
> hostname                                   # 必须是裸机/演练目标机，不是生产
> source /vastbase/scripts/backup.env
> vb_sql postgres -At -c \
>   "SELECT datname,count(*) FROM pg_stat_activity
>    WHERE datname IS NOT NULL GROUP BY 1 ORDER BY 1"   # 业务库上应无活跃连接
> ```
>
> 本节遵循 §1 / §19.1 的 `DROP`/停库红线：审批、留存 `\l`+`\dg`+`\db` 现状快照、确认目标机身份后再执行。

#### 11.6.1 先界定"留"与"删"（KEEP 名单）

目标机上有两类对象，**只能删本次恢复带来的，不能删目标机 initdb/自有的**。统一以下保留名单（与清理脚本中的 `KEEP_*` 变量一致）：

| 类别 | 保留（目标机自有，**不删**） | 删除（本次恢复进来的业务对象） |
|------|------------------------------|-------------------------------|
| 数据库 | `postgres` `template0` `template1` `vastbase`；以及目标机自有的 `appdb` `appdb_check` `appdb_drill` `appdb_drill_remote` | 15 个业务库：`admin_center` `ai_helper` `aihelper` `authx_service` `cas_server` `cat` `fileupload` `formflow` `jobs_server` `message` `platform_openapi` `powerjob` `question_feedback` `reservation` `transaction_service` |
| 角色 | `vastbase` `vbadmin` `vbaudit` `vbsso` `vb_read_all_settings` `appuser` `rouser` | 16 个业务角色：上述同名 + `dog` |
| 表空间 | `pg_default` `pg_global`；以及 `appdb` 自有的 `tbs_app_data` `tbs_app_idx`（★ v1.45） | 16 个 `tbs_*`：`tbs_admin_center` `tbs_ai_helper` `tbs_aihelper` `tbs_authx_service` `tbs_cas_server` `tbs_cat` `tbs_dog` `tbs_fileupload` `tbs_formflow` `tbs_jobs_server` `tbs_message` `tbs_platform_openapi` `tbs_powerjob` `tbs_question_feedback` `tbs_reservation` `tbs_transaction` |

> `appdb` 系列与 `appuser/rouser` 是目标机自有、不在备份里，默认保留；**appdb 的表空间 `tbs_app_data`/`tbs_app_idx` 随 appdb 一并保留**（在 `KEEP_TBS` 与 §11.6.3 清理豁免名单中，★ v1.45）。若这台是专用空壳、想一并清掉，把它们从 `KEEP_DB`/`KEEP_ROLE`/`KEEP_TBS` 同步移走即可。初始账户 `oid<16384`（`vbadmin`/`vbaudit`/`vbsso` 等）由方案二的 `oid>=16384` 过滤天然豁免，不会误删（见 §11.4.1）。

#### 11.6.2 方案一（推荐，最快）：只删业务库，再重放新备份

同源重恢复时角色与表空间留着复用即可——新备份的 globals 重放对它们只报 `already exists`（良性）。**坏掉的库级 `search_path` 存在 `pg_db_role_setting`、随 `DROP DATABASE` 自动清除**，新备份（v1.41 修复版 create.sql）会重新写对。

```bash
source /vastbase/scripts/backup.env
KEEP_DB="'postgres','template0','template1','vastbase','appdb','appdb_check','appdb_drill','appdb_drill_remote'"

# 1) 先打印将要删除的库，务必逐个核对！
vb_sql postgres -At -c \
 "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ($KEEP_DB) ORDER BY 1"

# 2) 逐库踢连接 + DROP
for db in $(vb_sql postgres -At -c \
 "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ($KEEP_DB)"); do
    echo ">>> drop database $db"
    vb_sql postgres -c \
      "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
       WHERE datname='$db' AND pid<>pg_backend_pid()" >/dev/null
    vb_sql postgres -c "DROP DATABASE IF EXISTS \"$db\""
done
```

删完直接按 §11.4 循环序列从**新备份**恢复（`DAY` 指向新备份目录）：a) `for f in *.create.sql` 循环建库 → b) `for dump in *.dump` 循环灌数 → c) 核对 search_path。角色/表空间已在、create.sql 里的 `CREATE DATABASE` 会重新建库，**全程无需重放 globals**。

#### 11.6.3 方案二（彻底）：业务库 + 表空间 + 角色全清

换源、或要完整验证"globals 建角色/表空间 → create.sql 建库 → 灌数"全链路时用。**删除顺序固定为 库 → 表空间 → 角色**（库占用表空间、角色拥有库，先拆下游）：

```bash
# ★ v1.45 与 KEEP_DB 对齐：appdb 在留，其表空间必须一并留

source /vastbase/scripts/backup.env
KEEP_DB="'postgres','template0','template1','vastbase','appdb','appdb_check','appdb_drill','appdb_drill_remote'"
KEEP_ROLE="'vastbase','vbadmin','vbaudit','vbsso','vb_read_all_settings','appuser','rouser'"
KEEP_TBS="'pg_default','pg_global','tbs_app_data','tbs_app_idx'"  

# 1) 删业务库（同方案一：先踢连接再 DROP）
for db in $(vb_sql postgres -At -c \
 "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ($KEEP_DB)"); do
    echo ">>> drop database $db"
    vb_sql postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity \
        WHERE datname='$db' AND pid<>pg_backend_pid()" >/dev/null
    vb_sql postgres -c "DROP DATABASE IF EXISTS \"$db\""
done

# 2) 删业务表空间（库删完后已空；tbs_dog 本就无库占用，可直接删）
#    注：DROP TABLESPACE 对仍被占用的表空间会报 "tablespace ... is not empty" 拒绝执行（内置保险），
#    但 KEEP_TBS 仍须写全（含 appdb 的 tbs_app_data/tbs_app_idx），避免报错噪声与误判
for ts in $(vb_sql postgres -At -c \
 "SELECT spcname FROM pg_tablespace WHERE spcname NOT IN ($KEEP_TBS)"); do
    echo ">>> drop tablespace $ts"
    vb_sql postgres -c "DROP TABLESPACE IF EXISTS \"$ts\""
done

# 3) 删业务角色（只动用户自建 oid>=16384 且不在保留名单；初始账户 oid<16384 自动豁免）
for r in $(vb_sql postgres -At -c \
 "SELECT rolname FROM pg_authid WHERE oid>=16384 AND rolname NOT IN ($KEEP_ROLE)"); do
    echo ">>> drop role $r"
    # 保险：清掉该角色在保留库内可能残留的属主对象/权限（业务角色通常无残留，DROP ROLE 一般直接成功）
    for d in postgres vastbase appdb; do
        vb_sql "$d" -c "DROP OWNED BY \"$r\" CASCADE" 2>/dev/null
    done
    vb_sql postgres -c "DROP ROLE IF EXISTS \"$r\""
done

# 4) 清理 pg_location 孤儿目录：见下方"清理收尾"——必须先按 catalog 拿豁免名单逐个删，
#    严禁 rm -rf ./tbs_* 裸通配（appdb 在用的 tbs_app_data/tbs_app_idx 就混在同层，★ v1.45）
```

清完按 §11.4 **完整序列**从新备份恢复：globals（建角色/表空间——注意表空间 `RELATIVE LOCATION` 目录如 `$PGDATA/pg_location/tbs_*` 须先存在且属主正确）→ create.sql 循环建库 → restore 循环灌数 → search_path 核对。

**清理收尾：清掉 `pg_location` 下的孤儿 location 目录（★ v1.44 新增，★ v1.45 改为 catalog 驱动豁免名单）。** `DROP TABLESPACE` 会删掉表空间内的 `PG_9.x_*` 版本子目录，但**常保留 `$PGDATA/pg_location/<location>` 这层根目录空壳**。若残留目录里还留着空的版本子目录，下次 globals 的 `CREATE TABLESPACE ... RELATIVE LOCATION '<location>'` 可能报 `directory ... already in use` / `File exists` 而中断恢复，故建议在重放前把**孤儿目录**清成"不存在"状态。

> **⚠️ 两条红线（★ v1.45）。①** `pg_location` 在 `$PGDATA` 内，属 §1 `rm -rf` 红线区：命令必须收敛、先 `cd` 再删。**② 目录里不全是孤儿——严禁 `rm -rf ./tbs_*` 裸通配。** 目标机按 §11.6.1 保留 `appdb` 时，其**在用**表空间 `tbs_app_data`/`tbs_app_idx` 的 location 目录与孤儿目录**同层混在 `pg_location` 下**（`\db` 也仍显示这两个表空间——"只剩 pg_default/pg_global"在这类机器上永不成立），裸通配会连活数据文件一并删掉、实例立刻损坏，且文件系统层 `rm` **没有** `DROP TABLESPACE` 的非空检查兜底。必须先向 catalog 拿"在用 location"豁免名单、只删名单之外的孤儿目录；因此**本步要求实例运行中**（拿不到名单绝不删）。

```bash
# 注意 location 名按 LOCATION 串走，未必与表空间名一致：reservation 表空间的 location 是 tbs_preservation
# 按现场实际，如 /vastbase/data/pg_location
PGLOC="$PGDATA/pg_location"
cd "$PGLOC" || exit 1

# 0) ★ v1.45：先从 catalog 取"仍在用"的 location 目录名单——唯一权威豁免名单
#    本现场：KEEP_DB 保留 appdb → \db 仍有 tbs_app_data / tbs_app_idx，这两个目录绝不能删
IN_USE=$(vb_sql postgres -At -c \
 "SELECT pg_tablespace_location(oid) FROM pg_tablespace
   WHERE spcname NOT IN ('pg_default','pg_global')") \
 || { echo "WARN: 在用表空间查询失败（实例没起来?），停手，禁止继续删除"; exit 1; }
IN_USE=$(printf '%s\n' "$IN_USE" | sed 's#.*/##; /^$/d')   # 取 basename、去空行
echo "== 在用 location（跳过不删）=="; printf '%s\n' "${IN_USE:-（无）}"

in_use() { printf '%s\n' "$IN_USE" | grep -qxF -- "$1"; }

# 1) 现状核对：\db 里除 pg_default/pg_global 外剩下的，应全部属于 KEEP_DB 自有库（如 appdb 的两个表空间）；
#    若还看到业务表空间（tbs_admin_center 等），说明第 2 步 DROP TABLESPACE 没删干净，先回去处理
vb_sql postgres -c "\db"

# 2) 逐个查目录：在用的只报不动；孤儿目录应为空、或只剩**空的** PG_9.x_* 版本子目录；发现任何文件立即停手排查
for d in tbs_*; do
    [ -e "$d" ] || continue                            # 无残留时通配不展开，防误跑
    if in_use "$d"; then echo "== $d == 在用（catalog 有主），跳过"; continue; fi
    entries=$(find "$d" -mindepth 1 | wc -l)           # 文件+子目录全算
    files=$(find "$d" -mindepth 1 ! -type d | wc -l)   # 只算文件/链接；0 才允许删
    printf "== %s == entries=%s files=%s\n" "$d" "$entries" "$files"
    [ "$files" -gt 0 ] && echo "WARN: $d 内仍有数据文件，禁删，停手排查！"
done
du -h --max-depth=1

# 3) 两步都符合预期后，只删孤儿目录：逐个显式删除，禁止 rm -rf ./tbs_* 裸通配
for d in tbs_*; do
    [ -e "$d" ] || continue
    in_use "$d" && continue
    files=$(find "$d" -mindepth 1 ! -type d | wc -l)
    if [ "$files" -eq 0 ]; then
        echo ">>> rm -rf ./$d"
        rm -rf "./$d"
    else
        echo "SKIP: $d 内有文件，未删（先排查）"
    fi
done
ls -la
# 期望：只剩在用的 location（本现场为 tbs_app_data、tbs_app_idx）与 . / ..
```

清掉后再走上面的 §11.4 完整序列；globals 的 `CREATE TABLESPACE` 会在干净的 `pg_location` 下重建孤儿对应的目录，**在用的 `tbs_app_data`/`tbs_app_idx` 原样保留、全程不受影响**（新备份 globals 若含同名 `CREATE TABLESPACE` 只报 already exists，良性）。`tbs_dog`（dog 角色对应）、`tbs_cat` 等同样按孤儿目录处理。

> 若确认孤儿目录里**只有空根、无任何 `PG_9.x_*` 子目录**，留着不删通常也能让 `CREATE TABLESPACE` 成功（直接往空目录建版本子目录）；但"删干净再建"风险最低、最可预期，演练/重恢复推荐这么做。

#### 11.6.4 重放前后两点必查

```bash
# 1) 确认新备份的 create.sql 是 v1.41 修复版生成的，否则 search_path 坏值会再现
grep -H "SET search_path" /vastbase/backup/<新日期>/*.create.sql
#    期望：SET search_path = ai_helper, public;   ← 裸标识符列表、无外层单引号

# 2) 清理是否到位：删干净后应查不到任何业务库的 search_path 行（见 §11.5 / 本节查询）
vb_sql postgres -c "
SELECT * FROM (
  SELECT CASE WHEN s.setdatabase=0 THEN '(all dbs)'
              ELSE (SELECT datname FROM pg_database WHERE oid=s.setdatabase) END AS database,
         CASE WHEN s.setrole=0 THEN '(all roles)'
              ELSE pg_get_userbyid(s.setrole) END AS role,
         unnest(s.setconfig) AS cfg
  FROM pg_db_role_setting s) t
WHERE cfg LIKE 'search_path=%' ORDER BY 1,2;"
```

> **更彻底但更重**：停库 `re-initdb` 重建整个实例（连 `appdb` 系列与三权分立配置一起重做），可把实例级参数/兼容模式一并重置。日常演练重恢复用不上，仅在需要从零核验实例初始化链路时采用，且须按 §8 重新走初始化流程。

---

## 12. 运维常用 SQL（跨库访问、慢 SQL、死元组、长事务等）

### 12.1 跨库访问：cat 库的 catuser 访问 dog 库的表/视图

VastBase G100（openGauss 内核）跨库访问主要有两种方案：

| 方案 | 特点 | 适用场景 |
|------|------|----------|
| **dblink 函数调用** | 显式构造连接串，逐次调用 | 偶发查询、临时取数 |
| **postgres_fdw 外部表** | 一次性映射，本地表用法 | 经常性访问、做 JOIN 分析 |

#### 方案 A：dblink 扩展（轻量）

**第一步：在两侧分别准备扩展与代理账号（DBA 操作）**

```sql
-- ① 在 cat 库中安装 dblink 扩展
\c cat vbadmin
CREATE EXTENSION IF NOT EXISTS dblink;
GRANT USAGE ON FOREIGN DATA WRAPPER dblink_fdw TO catuser;

-- ② 在 dog 库中创建一个"只读代理"账号，只授必要权限
\c dog vbadmin
CREATE USER cat_proxy WITH PASSWORD 'CatProxy@2026' LOGIN
    NOSUPERUSER NOCREATEDB NOCREATEROLE
    CONNECTION LIMIT 20;
GRANT CONNECT ON DATABASE dog TO cat_proxy;
GRANT USAGE  ON SCHEMA app       TO cat_proxy;
GRANT SELECT ON app.dogtable01   TO cat_proxy;
GRANT SELECT ON app.dogview01    TO cat_proxy;

-- ③ pg_hba.conf 放行本机访问（如果跨实例则加远端 IP）
--    本机访问可用 127.0.0.1/32 trust 风险大，建议仍走 sha256
```

**第二步：catuser 在 cat 库内查询 dog 的表/视图**

```sql
\c cat catuser

-- 方式 1：临时构造连接串
SELECT * FROM dblink(
    'host=127.0.0.1 port=5432 dbname=dog user=cat_proxy password=CatProxy@2026',
    'SELECT id, name, amount FROM app.dogtable01 WHERE amount > 100'
) AS t(id INT, name VARCHAR(100), amount NUMERIC(18,2));

-- 方式 2：先建 Foreign Server，连接信息收敛（推荐）
-- ↓ 由 vbadmin 一次性创建
\c cat vbadmin
CREATE SERVER dog_link
    FOREIGN DATA WRAPPER dblink_fdw
    OPTIONS (host '127.0.0.1', port '5432', dbname 'dog');

CREATE USER MAPPING FOR catuser
    SERVER dog_link
    OPTIONS (user 'cat_proxy', password 'CatProxy@2026');

GRANT USAGE ON FOREIGN SERVER dog_link TO catuser;

-- catuser 使用时：
\c cat catuser
SELECT * FROM dblink('dog_link', 'SELECT id, name FROM app.dogview01')
       AS t(id INT, name VARCHAR(200));
```

#### 方案 B：postgres_fdw 外部表（推荐：用法透明）

```sql
\c cat vbadmin
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- 外部服务器（指向 dog 库）
CREATE SERVER dog_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '127.0.0.1', port '5432', dbname 'dog');

-- 用户映射
CREATE USER MAPPING FOR catuser
    SERVER dog_srv
    OPTIONS (user 'cat_proxy', password 'CatProxy@2026');

GRANT USAGE ON FOREIGN SERVER dog_srv TO catuser;

-- 把 dog 的表 / 视图 映射成 cat 库下的"外部表"
CREATE SCHEMA IF NOT EXISTS dog_remote AUTHORIZATION catuser;

CREATE FOREIGN TABLE dog_remote.dogtable01 (
    id          INT,
    name        VARCHAR(100),
    amount      NUMERIC(18,2),
    create_time TIMESTAMP
) SERVER dog_srv
  OPTIONS (schema_name 'app', table_name 'dogtable01');

CREATE FOREIGN TABLE dog_remote.dogview01 (
    id   INT,
    name VARCHAR(200)
) SERVER dog_srv
  OPTIONS (schema_name 'app', table_name 'dogview01');

GRANT SELECT ON ALL TABLES IN SCHEMA dog_remote TO catuser;
```

**使用时和本地表完全一致：**

```sql
\c cat catuser

-- 直接像查本地表一样
SELECT * FROM dog_remote.dogtable01 WHERE amount > 100;

-- 甚至可以与 cat 自己的表做 JOIN
SELECT c.order_id, c.user_id, d.name
  FROM app.t_order c
  JOIN dog_remote.dogtable01 d ON c.user_id = d.id
 WHERE c.create_time > CURRENT_DATE - 7;
```

> ⚠️ **跨库性能注意**：跨库 JOIN 时尽量在 WHERE 中带上**外部表的过滤条件**，让 FDW 下推到 dog 库执行，否则会全表拉到 cat 再过滤。

> ⚠️ **密码安全**：`USER MAPPING` 的密码以明文存储在系统表 `pg_user_mappings` 中，**仅 owner 与超级用户可见**；务必使用单独的最小权限代理账号（如本例的 `cat_proxy`），不要复用业务账号或超管账号。

---

### 12.2 慢 SQL：TOP 10 查询

VastBase / openGauss 内置 `dbe_perf` schema 收集 SQL 执行统计，无需额外扩展。

**前提：postgresql.conf 已开启相关采集**

```ini
enable_resource_track     = on
enable_resource_record    = on
instr_unique_sql_count    = 10000
track_activity_query_size = 4096
```

**TOP 10 总耗时最长**

```sql
SELECT
    user_name,
    db_name,
    n_calls                                              AS calls,
    ROUND(total_elapse_time::numeric/1000000, 2)         AS total_sec,
    ROUND((total_elapse_time/NULLIF(n_calls,0))::numeric/1000, 2) AS avg_ms,
    ROUND(max_elapse_time::numeric/1000, 2)              AS max_ms,
    n_returned_rows                                      AS rows,
    LEFT(query, 200)                                     AS query
  FROM dbe_perf.statement
 ORDER BY total_elapse_time DESC
 LIMIT 10;
```

**TOP 10 单次最慢（更关注极端 SQL）**

```sql
SELECT
    user_name, db_name, n_calls,
    ROUND(max_elapse_time::numeric/1000, 2) AS max_ms,
    ROUND((total_elapse_time/NULLIF(n_calls,0))::numeric/1000, 2) AS avg_ms,
    LEFT(query, 200) AS query
  FROM dbe_perf.statement
 WHERE n_calls >= 5
 ORDER BY max_elapse_time DESC
 LIMIT 10;
```

**当前正在执行的慢 SQL（实时）**

```sql
SELECT pid, usename, datname, client_addr,
       NOW() - query_start AS run_age,
       state, wait_event_type, wait_event,
       LEFT(query, 200) AS query
  FROM pg_stat_activity
 WHERE state = 'active'
   AND NOW() - query_start > INTERVAL '5 seconds'
 ORDER BY query_start;
```

**查看 SQL 的执行计划（先取 unique_sql_id）**

```sql
-- 在 dbe_perf.statement 拿到 unique_sql_id 后
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT ...;     -- 把慢 SQL 原文粘进来
```

如使用 `pg_stat_statements` 扩展（PG 系生态更通用）也可：

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
-- postgresql.conf: shared_preload_libraries='pg_stat_statements'  (需重启)

SELECT userid::regrole AS usr,
       calls,
       ROUND(total_time::numeric, 2) AS total_ms,
       ROUND(mean_time::numeric,  2) AS avg_ms,
       rows,
       LEFT(query, 200) AS query
  FROM pg_stat_statements
 ORDER BY total_time DESC
 LIMIT 10;

-- 重置统计窗口
SELECT pg_stat_statements_reset();
```

---

### 12.3 死元组：成因、TOP 10、处理与优化参数

#### 12.3.1 死元组是怎么来的？

PostgreSQL 系（含 VastBase）采用 **MVCC 多版本并发控制**：

- `UPDATE` 实质是 "插入新版本 + 标记旧版本死亡"
- `DELETE` 不真正物理删除，只标记 xmax
- 这些"死亡的旧版本"就是 **dead tuples（死元组）**
- 死元组靠 **VACUUM / autovacuum** 回收成可重用空间

**什么情况下死元组会暴涨？**

| 触发因素 | 说明 |
|---------|------|
| 高频 UPDATE/DELETE | 业务表本身就会持续产生 |
| 长事务持锁 | autovacuum 不能回收事务可见性范围内的死元组 |
| 复制槽不消费 | wal/xmin horizon 卡住，所有库都受影响 |
| 索引列被频繁更新 | 阻止 HOT update，每次更新都产生新行新索引项 |
| `autovacuum_vacuum_scale_factor` 过大 | 触发门槛太高，垃圾堆积 |

#### 12.3.2 死元组 TOP 10 查询

```sql
SELECT
    schemaname || '.' || relname                          AS table,
    n_live_tup                                            AS live,
    n_dead_tup                                            AS dead,
    ROUND(n_dead_tup::numeric * 100
        / NULLIF(n_live_tup + n_dead_tup, 0), 2)          AS dead_pct,
    pg_size_pretty(pg_relation_size(relid))               AS size,
    last_autovacuum,
    last_autoanalyze,
    autovacuum_count,
    autoanalyze_count
  FROM pg_stat_user_tables
 WHERE n_dead_tup > 0
 ORDER BY n_dead_tup DESC
 LIMIT 10;
```

**膨胀率比绝对数更值得关注**（>20% 一般就要处理）：

```sql
SELECT
    schemaname || '.' || relname AS table,
    n_dead_tup, n_live_tup,
    ROUND(n_dead_tup::numeric * 100
        / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
  FROM pg_stat_user_tables
 WHERE (n_dead_tup + n_live_tup) > 1000
 ORDER BY dead_pct DESC NULLS LAST
 LIMIT 10;
```

#### 12.3.3 处理：手工 VACUUM / 重组

```sql
-- 常规清理（不锁表，可在线）
VACUUM (VERBOSE, ANALYZE) app.t_order;

-- 严重膨胀，需要真正回收磁盘空间（会持有 AccessExclusive 锁，阻塞读写！）
VACUUM FULL app.t_order;

-- 更优雅的在线重建（仅当当前 VastBase 发行包已提供并经测试验证时，才使用 pg_repack 扩展）
-- 优点：在线、不阻塞 DML；缺点：需要额外磁盘空间和扩展
CREATE EXTENSION IF NOT EXISTS pg_repack;
-- shell 中执行
-- pg_repack -h 127.0.0.1 -U vbadmin -d appdb -t app.t_order
```

#### 12.3.4 排查"为什么 vacuum 没生效"

```sql
-- 是否被长事务卡住 xmin horizon？
SELECT pid, usename, datname, state,
       NOW() - xact_start AS xact_age,
       backend_xmin, LEFT(query, 100) AS query
  FROM pg_stat_activity
 WHERE backend_xmin IS NOT NULL
 ORDER BY backend_xmin;

-- 是否被未消费的复制槽卡住？（openGauss 内核为 xlog 命名，无 PG10+ 的 pg_wal_lsn_diff/pg_current_wal_lsn）
SELECT slot_name, plugin, active, restart_lsn,
       pg_size_pretty(pg_xlog_location_diff(pg_current_xlog_location(), restart_lsn)) AS lag
  FROM pg_replication_slots
 ORDER BY restart_lsn;

-- autovacuum 是否在跑？
SELECT pid, datname, query, state, NOW()-query_start AS run_age
  FROM pg_stat_activity
 WHERE query LIKE 'autovacuum%';
```

#### 12.3.5 预防：表级 / 全局优化参数

**对高频更新表设置更激进的 autovacuum 阈值：**

```sql
ALTER TABLE app.t_order SET (
    fillfactor = 80,                              -- 给 HOT update 留空间
    autovacuum_vacuum_scale_factor   = 0.05,      -- 5% 死元组就触发
    autovacuum_vacuum_threshold      = 1000,
    autovacuum_analyze_scale_factor  = 0.02,
    autovacuum_vacuum_cost_delay     = 5
);
```

**全局参数（postgresql.conf，参见第 6.5 节）：**

| 参数 | 作用 | 调优方向 |
|------|------|---------|
| `autovacuum` | 总开关 | `on`，**永远不要关** |
| `autovacuum_max_workers` | 并行 worker 数 | 大表多时调大，4–8 |
| `autovacuum_naptime` | worker 唤醒间隔 | 默认 1min，繁忙库 30s |
| `autovacuum_vacuum_scale_factor` | 触发阈值（占活元组比） | 默认 0.2 偏大，0.05–0.1 更稳 |
| `autovacuum_vacuum_threshold` | 死元组绝对数下限 | 50–1000 |
| `autovacuum_vacuum_cost_delay` | 每次 IO 的等待 | 10ms 默认；SSD 可降到 2–5ms |
| `autovacuum_vacuum_cost_limit` | 每轮 IO 配额 | 2000–4000 |
| `maintenance_work_mem` | vacuum 用内存 | 1–2 GB，越大越快 |
| `idle_in_transaction_session_timeout` | 自动 kill 闲事务 | 10–30 分钟，**强烈建议设置** |

> 一句话：**没有"消灭死元组"，只有"让 vacuum 跟得上死元组生成的速度"。**

---

### 12.4 长事务查询

#### 12.4.1 当前长事务（>5 分钟）

```sql
SELECT
    pid,
    usename,
    datname,
    client_addr,
    application_name,
    state,
    NOW() - xact_start  AS xact_age,
    NOW() - query_start AS query_age,
    wait_event_type,
    wait_event,
    LEFT(query, 200)    AS query
  FROM pg_stat_activity
 WHERE state <> 'idle'
   AND xact_start IS NOT NULL
   AND NOW() - xact_start > INTERVAL '5 minutes'
 ORDER BY xact_start;
```

#### 12.4.2 "idle in transaction"（连接占着事务但不干活，最危险）

```sql
SELECT
    pid, usename, datname, client_addr, application_name,
    NOW() - state_change AS idle_age,
    LEFT(query, 200)     AS last_query
  FROM pg_stat_activity
 WHERE state = 'idle in transaction'
   AND NOW() - state_change > INTERVAL '5 minutes'
 ORDER BY state_change;
```

#### 12.4.3 终止会话

```sql
-- 软取消当前 SQL（保留连接）
SELECT pg_cancel_backend(12345);

-- 强制断开连接（连同事务一起回滚）
SELECT pg_terminate_backend(12345);

-- 批量清理所有 >30 分钟的 idle in transaction
SELECT pid, pg_terminate_backend(pid)
  FROM pg_stat_activity
 WHERE state = 'idle in transaction'
   AND NOW() - state_change > INTERVAL '30 minutes';
```

#### 12.4.4 让数据库自动兜底（postgresql.conf）

```ini
idle_in_transaction_session_timeout = 600000   # 10 分钟，超时自动终止
statement_timeout                   = 0        # 单语句超时，0=不限；OLTP 建议 60000–300000
lock_timeout                        = 30000    # 30s 拿不到锁就放弃
```

---

### 12.5 查看所有数据库的大小列表

```sql
SELECT
    datname                                            AS database,
    pg_size_pretty(pg_database_size(datname))          AS size,
    pg_database_size(datname)                          AS size_bytes,
    pg_encoding_to_char(encoding)                      AS encoding,
    datcollate                                         AS collate
  FROM pg_database
 WHERE datistemplate = false
 ORDER BY pg_database_size(datname) DESC;
```

**含每库连接数 / 兼容模式（更全面）：**

```sql
SELECT
    d.datname,
    pg_size_pretty(pg_database_size(d.datname)) AS size,
    d.datconnlimit                              AS conn_limit,
    (SELECT count(*) FROM pg_stat_activity a
       WHERE a.datname = d.datname)             AS current_conn,
    CASE d.datcompatibility
         WHEN 'A'  THEN 'Oracle'
         WHEN 'B'  THEN 'MySQL'
         WHEN 'C'  THEN 'Teradata'
         WHEN 'PG' THEN 'PostgreSQL'
         ELSE d.datcompatibility
    END                                         AS compatibility
  FROM pg_database d
 WHERE d.datistemplate = false
 ORDER BY pg_database_size(d.datname) DESC;
```

---

### 12.6 当前库表大小 TOP 10

**仅看表（含索引、TOAST）：**

```sql
SELECT
    n.nspname || '.' || c.relname             AS table,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_relation_size(c.oid))       AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid))        AS index_size,
    pg_total_relation_size(c.oid)                 AS bytes
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE c.relkind IN ('r','p')                  -- r=普通表, p=分区表
   AND n.nspname NOT IN ('pg_catalog','information_schema','dbe_perf','snapshot','db4ai')
 ORDER BY pg_total_relation_size(c.oid) DESC
 LIMIT 10;
```

**表 + 索引一起排，看清单大对象：**

```sql
SELECT
    n.nspname || '.' || c.relname AS object,
    CASE c.relkind
         WHEN 'r' THEN 'table'
         WHEN 'i' THEN 'index'
         WHEN 'p' THEN 'partitioned'
         WHEN 'm' THEN 'matview'
         WHEN 't' THEN 'toast'
         ELSE c.relkind::text
    END                                       AS type,
    pg_size_pretty(pg_relation_size(c.oid))   AS size
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname NOT IN ('pg_catalog','information_schema','dbe_perf','snapshot','db4ai')
 ORDER BY pg_relation_size(c.oid) DESC
 LIMIT 10;
```

**单表细化：行数 + 表/索引/TOAST 占比：**

```sql
WITH t AS (
  SELECT 'app.t_order'::regclass AS oid
)
SELECT
    pg_size_pretty(pg_relation_size(oid))                       AS heap,
    pg_size_pretty(pg_indexes_size(oid))                        AS indexes,
    pg_size_pretty(pg_total_relation_size(oid)
                 - pg_relation_size(oid)
                 - pg_indexes_size(oid))                        AS toast,
    pg_size_pretty(pg_total_relation_size(oid))                 AS total,
    (SELECT reltuples::bigint FROM pg_class WHERE oid=t.oid)    AS est_rows
  FROM t;
```

---

### 12.7 速查脚本封装

把上述查询保存到 `/vastbase/scripts/sql/` 下，便于一键调用：

```bash
mkdir -p /vastbase/scripts/sql
chown vastbase:dbgrp /vastbase/scripts/sql

# 例如：每天早上自动出一份巡检报告
cat > /vastbase/scripts/daily_report.sh <<'EOF'
#!/bin/bash
source /vastbase/scripts/backup.env
OUT=/vastbase/log/daily_$(date +%F).txt
{
  echo "===== 数据库大小 ====="
  ${VB_SQL} -h $PG_HOST -U $PG_USER -d postgres -f /vastbase/scripts/sql/db_size.sql
  echo "===== 表 TOP 10 (appdb) ====="
  ${VB_SQL} -h $PG_HOST -U $PG_USER -d appdb -f /vastbase/scripts/sql/table_top10.sql
  echo "===== 死元组 TOP 10 (appdb) ====="
  ${VB_SQL} -h $PG_HOST -U $PG_USER -d appdb -f /vastbase/scripts/sql/dead_tup.sql
  echo "===== 长事务 ====="
  ${VB_SQL} -h $PG_HOST -U $PG_USER -d postgres -f /vastbase/scripts/sql/long_xact.sql
  echo "===== 慢 SQL TOP 10 ====="
  ${VB_SQL} -h $PG_HOST -U $PG_USER -d postgres -f /vastbase/scripts/sql/slow_sql.sql
} > $OUT 2>&1
EOF
chmod 750 /vastbase/scripts/daily_report.sh
```

加进 crontab：

```cron
# 每天 08:30 出巡检报告
30 8 * * *  /vastbase/scripts/daily_report.sh
```

---

### 12.8 索引膨胀与未使用索引

#### 索引膨胀检测（rough）

PostgreSQL 系没有官方"索引膨胀率"视图，常用近似法：比较 `pg_relation_size` 与按行数估算的理论大小。

```sql
-- 索引大小 TOP 10（粗略发现可疑膨胀对象）
SELECT
    s.schemaname || '.' || s.indexrelname            AS index,
    s.schemaname || '.' || s.relname                 AS table,
    pg_size_pretty(pg_relation_size(s.indexrelid))   AS idx_size,
    pg_size_pretty(pg_relation_size(s.relid))        AS tbl_size,
    s.idx_scan, s.idx_tup_read, s.idx_tup_fetch
  FROM pg_stat_user_indexes s
 ORDER BY pg_relation_size(s.indexrelid) DESC
 LIMIT 10;
```

#### 未使用 / 极少使用的索引（可考虑下线）

```sql
SELECT
    s.schemaname || '.' || s.relname       AS table,
    s.indexrelname                          AS index,
    s.idx_scan,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS idx_size,
    pg_get_indexdef(s.indexrelid)          AS ddl
  FROM pg_stat_user_indexes s
  JOIN pg_index i ON i.indexrelid = s.indexrelid
 WHERE s.idx_scan < 50                                    -- 调用次数极低
   AND NOT i.indisunique AND NOT i.indisprimary           -- 非唯一/主键索引才能删
   AND pg_relation_size(s.indexrelid) > 10 * 1024 * 1024  -- 大于 10MB 才值得删
 ORDER BY pg_relation_size(s.indexrelid) DESC;
```

> 评估 ≥ 7 天的统计数据再决定下线，避免删掉夜间批处理或月底报表才用的索引。

#### 在线重建索引

```sql
-- VastBase / openGauss 支持 REINDEX CONCURRENTLY（部分版本）：不阻塞 DML
REINDEX INDEX CONCURRENTLY app.idx_t_order_userid;

-- 不支持 CONCURRENTLY 时退化为加锁重建：
REINDEX INDEX app.idx_t_order_userid;          -- 阻塞 SELECT 之外的写
REINDEX TABLE app.t_order;                     -- 重建该表全部索引
```

可放进周末维护窗口的批处理：

```sql
-- 生成所有 > 100MB 索引的 REINDEX 语句（人审后再执行）
SELECT 'REINDEX INDEX CONCURRENTLY '
       || quote_ident(schemaname) || '.' || quote_ident(indexrelname) || ';' AS cmd
  FROM pg_stat_user_indexes
 WHERE pg_relation_size(indexrelid) > 100*1024*1024
 ORDER BY pg_relation_size(indexrelid) DESC;
```

### 12.9 锁等待分析

#### 当前正在阻塞别人的"罪魁"会话

```sql
SELECT
    bl.pid              AS blocked_pid,
    bl.usename          AS blocked_user,
    LEFT(bl.query, 80)  AS blocked_query,
    NOW() - bl.query_start AS blocked_age,
    kl.pid              AS blocking_pid,
    kl.usename          AS blocking_user,
    kl.state            AS blocking_state,
    LEFT(kl.query, 80)  AS blocking_query,
    NOW() - kl.xact_start AS blocking_xact_age
  FROM pg_stat_activity bl
  JOIN pg_locks lbl ON bl.pid = lbl.pid AND NOT lbl.granted
  JOIN pg_locks lkl ON  lkl.locktype = lbl.locktype
                    AND lkl.database IS NOT DISTINCT FROM lbl.database
                    AND lkl.relation IS NOT DISTINCT FROM lbl.relation
                    AND lkl.page     IS NOT DISTINCT FROM lbl.page
                    AND lkl.tuple    IS NOT DISTINCT FROM lbl.tuple
                    AND lkl.virtualxid IS NOT DISTINCT FROM lbl.virtualxid
                    AND lkl.transactionid IS NOT DISTINCT FROM lbl.transactionid
                    AND lkl.classid  IS NOT DISTINCT FROM lbl.classid
                    AND lkl.objid    IS NOT DISTINCT FROM lbl.objid
                    AND lkl.objsubid IS NOT DISTINCT FROM lbl.objsubid
                    AND lkl.pid != lbl.pid
                    AND lkl.granted
  JOIN pg_stat_activity kl ON kl.pid = lkl.pid;
```

#### 当前所有锁等待对象（按热度）

```sql
SELECT
    l.locktype, l.mode, l.relation::regclass AS relation,
    COUNT(*) AS waiters
  FROM pg_locks l
 WHERE NOT l.granted
 GROUP BY 1,2,3
 ORDER BY waiters DESC;
```

#### 一键找出"应该被 kill 的"长事务

```sql
-- 持锁 > 5 分钟 且 在阻塞别人 的事务
SELECT DISTINCT kl.pid, kl.usename, kl.datname, kl.client_addr,
       NOW() - kl.xact_start AS xact_age, kl.state,
       LEFT(kl.query, 200) AS query
  FROM pg_stat_activity kl
  JOIN pg_locks lkl ON lkl.pid = kl.pid AND lkl.granted
  JOIN pg_locks lbl ON  lbl.locktype = lkl.locktype
                    AND lbl.relation IS NOT DISTINCT FROM lkl.relation
                    AND lbl.transactionid IS NOT DISTINCT FROM lkl.transactionid
                    AND NOT lbl.granted
                    AND lbl.pid != kl.pid
 WHERE NOW() - kl.xact_start > INTERVAL '5 min';
```

### 12.10 WDR / 性能诊断报告（VastBase / openGauss 原生）

WDR（Workload Diagnostic Report）类似 Oracle AWR，能在两个 snapshot 之间生成完整的性能报告。为避免 `ALTER SYSTEM` 写入 `postgresql.auto.conf` 后与 `$VB_GUC` 下发方式产生优先级差异，本文统一使用 `$VB_GUC` 持久化 WDR 参数。

**启用 WDR 采集：**

```bash
$VB_GUC set -D $PGDATA -c "enable_wdr_snapshot = on"
$VB_GUC set -D $PGDATA -c "wdr_snapshot_interval = 30"       # 压测/诊断期间可缩短到 30min
$VB_GUC set -D $PGDATA -c "wdr_snapshot_retention_days = 8"   # 显式限制保留期，避免快照堆积

WDR_CONTEXT=$($VB_SQL -h 127.0.0.1 -p $PGPORT -U vbadmin -d postgres -At \
  -c "SELECT context FROM pg_settings WHERE name='enable_wdr_snapshot';" 2>/dev/null || echo postmaster)
if [ "$WDR_CONTEXT" = "postmaster" ]; then
  $VB_CTL restart -D $PGDATA -m fast
else
  $VB_CTL reload -D $PGDATA
fi

$VB_SQL -h 127.0.0.1 -p $PGPORT -U vbadmin -d postgres \
  -c "SHOW enable_wdr_snapshot; SHOW wdr_snapshot_interval; SHOW wdr_snapshot_retention_days;"
```

**生成 WDR 报告：**

```sql
# vbadmin用户看不到snapshot，只能是初始化用户vastbase
vsql -d postgres -U vastbase
# 用初始用户 vastbase 执行，把监控权限MONADMIN授给 vbadmin
ALTER USER vbadmin MONADMIN;


#切换到vbadmin用户，可以执行了
-- 1) 列出已有 snapshot
SELECT snapshot_id, start_ts, end_ts
  FROM snapshot.snapshot
 ORDER BY snapshot_id DESC LIMIT 20;

-- 2) 手工创建 snapshot（在重要变更或压测前后各调一次，便于对比）
SELECT create_wdr_snapshot();

-- 3) 查看节点名称
SHOW pgxc_node_name;

select * from pg_node_env;

-- 4) 生成 WDR 报告（begin/end 用上面查到的 snapshot_id）
-- 单机：report_scope='node'，集群级：'cluster'；report_type 可选 summary/detail/all
-- SELECT generate_wdr_report(<begin_snap_id>, <end_snap_id>, 'all', 'node', 'node name');
-- 可以格式化为html报告

\a
\t on
\o /tmp/wdr_snap2_3.html
SELECT generate_wdr_report(2, 3, 'all', 'node', 'node1');
\o
\t off
\a


-- 4) 使用变量替代裸数字，避免误复制固定 snapshot_id
\set begin_snap  101    -- 替换为上方查询到的起始 snapshot_id
\set end_snap    102    -- 替换为上方查询到的结束 snapshot_id

-- 5) 个入参：begin_id, end_id, report_type('all'/'summary'/'detail'),
--          report_scope('cluster'/'node'), node_name（cluster 模式下传 NULL）
SELECT generate_wdr_report(:begin_snap, :end_snap, 'all', 'cluster', NULL);

```

通过 `vsql/gsql` 导出 HTML 报告示例：

```bash
REPORT_DIR=/vastbase/docs/perf_test_<YYYYMMDD_HHMMSS>
mkdir -p "$REPORT_DIR"
$VB_SQL -h 127.0.0.1 -p $PGPORT -U vbadmin -d postgres <<'EOSQL'
\set begin_snap  101
\set end_snap    102
\a
\t
\o :report_dir/wdr_cluster.html
-- 某些版本返回的是 HTML 片段；如需独立 HTML 文件，可打开下面两行包装。
-- \echo '<html><body>'
SELECT generate_wdr_report(:begin_snap, :end_snap, 'all', 'cluster', NULL);
-- \echo '</body></html>'
\o
\a
\t
EOSQL
```

精简版

```logs
设置输出格式相关命令说明：
\a: 切换查询结果的输出是对齐格式（aligned）还是非对齐格式（unaligned）。
\t: 切换是否显示查询结果的列名（表头）和末尾的行计数信息。
\o:  指定输出文件，将所有的查询结果发送至服务器文件里。
/home/vastbase/wdrTestNode.html：生成性能报告文件存放路径和报告名。用户需要拥有此路径的读写权限。
```



```sql
\a \t \o /home/vastbase/wdrTestNode.html
select generate_wdr_report(2, 3, 'all', 'node', pgxc_node_str()::cstring);
\a \t \o
```

> 函数名 / 视图名因版本而异，现场以 `\df *wdr*`、`\dn snapshot`、`\d snapshot.*` 实际可用对象为准；如 `create_wdr_snapshot()` 报 `function does not exist`，先用 `\df *wdr*` 确认可用 schema 后再改写。若 `enable_wdr_snapshot` 的 context 为 `postmaster`，必须把 restart 证据写入诊断或压测报告。

---

## 13. 验收检查清单

| # | 项目 | 命令/检查点 | 期望结果 |
|---|------|------------|----------|
| 1 | OS 内核参数 | `sysctl -a | egrep 'shmmax|swappiness|file-max'` | 与 2.5 一致 |
| 2 | THP | `cat /sys/kernel/mm/transparent_hugepage/enabled` | `[never]` |
| 3 | 资源限制 | `su - vastbase -c 'ulimit -n'` | `1000000` |
| 4 | SELinux 状态 | `getenforce` | `Disabled` |
| 5 | firewalld 状态 | `systemctl is-active firewalld` | `active` |
| 6 | 防火墙规则 | `firewall-cmd --list-all --zone=public` | 含 22/5432 rich rule |
| 7 | 业务网段连通 | 从 192.168.10.x telnet 5432 | 通 |
| 8 | 非授权 IP 拒绝 | 从未授权 IP telnet 5432 | 超时/拒绝 |
| 9 | 出栈到备份服务器 | `ssh vastbase@192.168.100.100 hostname` | 立即返回主机名 |
| 10 | 服务状态 | `systemctl status vastbase` | active (running) |
| 11 | 端口监听 | `ss -ntlp \| grep 5432` | 0.0.0.0:5432 |
| 12 | 实例信息 | `su - vastbase -c '$VB_CTL status -D $PGDATA'` | server is running |
| 13 | 数据库登录 | `su - vastbase -c '$VB_SQL -d appdb -U appuser -W -c "select 1"'` | 1 |
| 14 | MySQL 兼容 | `SELECT datcompatibility FROM pg_database WHERE datname='appdb'; SHOW lower_case_table_names; SHOW vastbase_sql_mode;` | `appdb` 为 `B`；大小写策略与 `sql_mode` 基线符合迁移方案 |
| 14.1 | V3.0.8PSU4 工具版本 | `$VB_SQL --version; $VB_DUMP --help \| grep -E -- '--stat-obj\|--statistics'` | 随包工具可识别；增强选项按需可用 |
| 14.1.1 | 初始化密码参数证据 | `ls /vastbase/docs/evidence/vb_initdb_help_*; grep -E -- '(-W|-w|--pwfile)' /vastbase/docs/evidence/vb_initdb_help_*` | 已归档 `$VB_INITDB --help`，并确认初始化密码参数语义 |
| 14.2 | V3.0.8PSU4 时间函数精度 | `SELECT pg_typeof(CURRENT_TIMESTAMP), pg_typeof(CURRENT_TIMESTAMP(6));` | B 模式确认默认精度与微秒精度；需微秒时使用 `CURRENT_TIMESTAMP(6)` |
| 14.3 | V3.0.8PSU4 WDR 写法 | `grep -n "begin_snap_id :=" 本文档` | 不在非 PG 兼容模式示例中使用命名参数调用 |
| 14.4 | V3.0.8PSU4 互斥参数 | `SHOW vb_enable_comm_shm; SHOW enable_thread_pool;` | 不同时为 `on` |
| 14.5 | V3.0.8PSU4 向量并行 | `SHOW max_vector_indexer_query_threads;` | 使用向量索引时为 `0` |
| 15 | 兼容性测试 | 第 9 章脚本全部通过 | 无报错 |
| 15.1 | 压测报告 | `$REPORT_DIR/perf_test_report_<YYYYMMDD>.md`；`REPORT_DIR` 由 `/vastbase/docs/.perf_test_current` 确认 | 包含 32GB/64GB 参数基线、并发曲线、P95/P99、fio、iperf3、OS/DB/WDR 证据、调参记录、清理 checklist 和最终参数建议 |
| 15.2 | 压测达标 | 第 20 章通过标准和业务 SLA | 基准压测、业务回放、稳定性观察通过；无 OOM、持续 swap、归档堆积、长锁等待和未解释错误 |
| 16 | `.pgpass` 权限 | `ls -l /home/vastbase/.pgpass` | `-rw------- vastbase` |
| 17 | databases.list | `cat /vastbase/scripts/databases.list` | 至少含 `appdb`；多业务库按现场库名逐行列出 |
| 18 | 手工备份 | `/vastbase/scripts/db_backup.sh` 退出码 | `0` |
| 19 | 本地备份产物 | `ls /vastbase/backup/$(date +%F)/` | 每库一个 .dump + manifest（含 `dbcompatibility`）+ `BACKUP.OK` |
| 20 | 异地备份产物 | `ssh vastbase@192.168.100.100 "ls /backup/vbdb01/$(date +%F)/"` | 与本地一致 |
| 21 | 备份哨兵监控 | `test -f /vastbase/backup/$(date +%F)/BACKUP.OK` | 退出码 0 |
| 22 | Cron 任务 | `crontab -l -u vastbase` | 含 02:00 备份行 + 08:30 巡检行；WAL 清理按 PITR 策略单独审批 |
| 23 | 恢复演练 | `db_restore.sh -d appdb -n appdb_drill -F` | 完成且行数一致 |
| 24 | 远端拉回恢复 | `db_restore.sh -d appdb -r -n appdb_drill_remote -F` | 完成 |
| 25 | 跨库访问（dblink） | catuser 在 cat 库查 dog 表 | 返回数据 |
| 26 | 跨库访问（FDW） | `SELECT * FROM dog_remote.dogtable01 LIMIT 1` | 返回数据 |
| 27 | 慢 SQL 采集 | `SHOW enable_resource_track` | `on` |
| 28 | 慢 SQL TOP10 | `dbe_perf.statement` 有数据 | 至少 1 行 |
| 29 | 死元组监控 | 12.3.2 SQL 可执行 | 输出表清单 |
| 30 | 长事务超时 | `SHOW idle_in_transaction_session_timeout` | `10min`（或自定义） |
| 31 | 日志归档 | 查看 `/vastbase/log/pg_log/` 当日文件 | 有滚动 |
| 32 | 慢日志记录 | 触发一条 `SELECT pg_sleep(2)` 查询 | 日志中出现 |

---

## 14. 附录：常见问题排查

### 14.1 启动失败 "could not bind IPv4 socket: Address already in use"
端口被占：`ss -ntlp | grep 5432`，停掉占用进程或换端口。

### 14.2 "FATAL: no pg_hba.conf entry"
客户端 IP 不在白名单。推荐直接编辑 `$PGDATA/pg_hba.conf`，或使用准确的 GUC 工具写法追加条目，例如：`$VB_GUC set -D $PGDATA -h "host appdb appuser 192.168.10.0/24 sha256"`；修改后执行 `$VB_CTL reload -D $PGDATA`。

### 14.3 "could not create shared memory segment"
`kernel.shmmax` 小于 `shared_buffers`。调大 shmmax 后 `sysctl -p` 再启动。

### 14.4 启动慢 / 抖动
检查 THP 是否关闭、I/O 调度器是否为 none、是否启用 numa_balancing；查看 `dmesg` 是否有 `task hung` 或 `soft lockup`。

### 14.5 中文显示乱码
确认初始化时使用 `$VB_INITDB -E UTF8 --locale=en_US.UTF-8 ...`，客户端会话设置：`\encoding UTF8`，并保证终端 LANG=UTF-8。

### 14.6 MySQL 函数/语法报错 "function xxx does not exist"
检查实例和业务库是否为 `B` 兼容模式、`b_compatibility_mode`/`vastbase_sql_mode`/`lower_case_table_names` 是否符合迁移方案；某些 MySQL 语法只在 B 兼容数据库下生效。

### 14.7 autovacuum 跟不上写入
观察 `pg_stat_user_tables.n_dead_tup`，按需调小 `autovacuum_vacuum_scale_factor`、调大 `autovacuum_max_workers`、调大 `maintenance_work_mem`，并对高频写表手工：

```sql
VACUUM (VERBOSE, ANALYZE) app.t_order;
```

### 14.8 业务接入报错 "Cannot convert the column of type TIMESTAMPTZ to requested type java.time.LocalDateTime"（应用时间类型不匹配，现场案例）

将一次 Spring Boot + MyBatis(-Plus) 业务容器访问 VastBase G100 的时间类型排障经验固化到文档。**本质是 Java 时间类型与库列时区语义错配，非 SQL 语法错误、非数据库本身故障。**

**现象（业务容器日志）**

- 业务查询 `ai_helper.sg_aigc_session` 时抛 `org.springframework.jdbc.BadSqlGrammarException: Error attempting to get column 'create_time' from result set`。
- 根因异常：`Caused by: org.postgresql.util.PSQLException: Cannot convert the column of type TIMESTAMPTZ to requested type java.time.LocalDateTime.`（`org.postgresql.jdbc.PgResultSet.getLocalDateTime`，驱动 `postgresql-42.7.8`，经 `org.apache.ibatis.type.LocalDateTimeTypeHandler` 触发）。
- **排查提示**：Spring 的 `SQLStateSQLExceptionTranslator` 会把该 `SQLState` 归类并包装成 `BadSqlGrammarException`，但它**不是 SQL 语法问题**，是结果集类型转换失败，排查时勿被 "grammar" 字样误导。

**根因（RCA）**

1. 库列 `create_time` 实际类型为 `timestamp with time zone`（`timestamptz`，OID 1184）。
2. Java 实体字段声明为 `java.time.LocalDateTime`，MyBatis 选用 `LocalDateTimeTypeHandler` 读取。
3. PostgreSQL JDBC 自 42.x 起，`timestamptz` 默认映射为 `OffsetDateTime`；对 `timestamptz` 列调用 `getLocalDateTime()` 会**直接抛错**（不再静默丢弃时区），故 `LocalDateTime` 取数必然失败。
4. 该行为属 **JDBC 协议/驱动层**，与实例兼容模式（B/MySQL 或 PG）无关。VastBase G100 基于 openGauss（PG 9.2.4 内核），`timestamp with time zone` 列同样返回 timestamptz 类型 OID，驱动据此判定。

**定位 SQL（务必全量排查，不止报错的那一列）**

```sql
-- 列出目标 schema 内所有 timestamptz 字段
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE data_type = 'timestamp with time zone'
  AND table_schema = 'ai_helper'
ORDER BY table_name, column_name;

-- 处置前先确认会话时区，影响 ::timestamp 的折算结果
SHOW timezone;
```

**现场已执行的临时处置（含风险，须知边界）**

```sql
ALTER TABLE ai_helper.sg_aigc_session
  ALTER COLUMN create_time TYPE timestamp without time zone
  USING create_time::timestamp;
```

- **是否有效**：列由 `timestamptz` 改为 `timestamp`（无时区）后，驱动即可按 `LocalDateTime` 读取，运行时报错消除——该处置对**消除当前报错是有效的**。若某些分析文档把"改 `timestamp without time zone`"归为"无效方案"，与此处的实际效果及现场处置自相矛盾：它并非无效，只是以**牺牲时区语义**为代价。
- ⚠ **风险 1（时区语义丢失）**：`::timestamp` 会按**会话 TimeZone** 把 timestamptz 折算成墙钟时间后落库，之后不再携带时区。跨时区部署、夏令时、多地访问会产生歧义。现场样例数据 `2026-06-18 17:53:09` 即 `+08` 墙钟，执行前务必确认 `SHOW timezone;`。
- ⚠ **风险 2（处置不完整）**：本次仅改了 `create_time`。**同表 `update_time` 同为 timestamptz**（验证表数据时可见），且其它表可能也存在 timestamptz 列——只要被映射成 `LocalDateTime` 查询，仍会报同样的错。必须按上面的定位 SQL **全量排查**，对所有需被 `LocalDateTime` 读取的 timestamptz 列统一处置，否则问题会在 `update_time` 或其它表复发。
- ⚠ **风险 3（锁与表重写）**：`ALTER COLUMN ... TYPE` 会**重写整表并持 ACCESS EXCLUSIVE 锁**，大表期间阻塞读写。须安排在业务低峰/变更窗口，先在测试库演练，并遵循"使用前必读"第 4 条的变更审批与回退要求。

**推荐的根因级方案（择一；优先不改库结构）**

1. **应用侧对齐类型（推荐，保留 timestamptz 时区语义）**：把实体字段由 `LocalDateTime` 改为 `OffsetDateTime`（或 `Instant`），并使用对应 TypeHandler；或注册**全局自定义 TypeHandler**，读出时以 `rs.getObject(col, OffsetDateTime.class).toLocalDateTime()` 完成 timestamptz→LocalDateTime 的显式折算，业务实体可不大改。此方案不改库结构、不丢时区。
2. **库侧统一为无时区（仅当业务确实不需要时区语义）**：按定位 SQL 把相关 timestamptz 列统一改为 `timestamp without time zone`，并在建表/迁移规范（如 Flyway 脚本）中固化，避免后续新表再次引入 timestamptz 与 `LocalDateTime` 的错配。

**两点澄清（避免误判方向）**

- `stringtype=unspecified` 等 JDBC URL 改动**不解决**本问题：它影响参数**发送方向**的字符串绑定，与结果集**读取**无关，将其列为无效方案是正确的。
- 与时间类型问题**无关**的"Invalid username/password / set role denied / Flyway 认证异常"在本次容器日志中**并未出现**——本日志仅含 TIMESTAMPTZ→LocalDateTime 转换错误。若现场确有 set role/认证报错，应另取对应日志**单独排查**，不要与本时间类型问题混为一谈。

**结论**：报错本质是 Java `LocalDateTime`（无时区）与库列 `timestamptz`（带时区）经 PG JDBC 映射后的**语义错配**。临时 ALTER SQL 可消除报错，但有时区语义损失、需全量覆盖（含 `update_time` 及其它表）、并注意大表锁与重写；长期建议应用侧改用 `OffsetDateTime`/`Instant` 或自定义 TypeHandler 对齐。

### 14.9 虚拟化平台周期性时钟回拨（每 30 分钟 ±50 秒“锯齿”，现场案例：排查方法与处置）

2026-07-08 §19.4 迁移验收当天，从一条备份日志的“时间倒流”顺藤摸瓜，定位出**全平台、全天候、每 30 分钟一次的周期性时钟回拨**。本节固化完整排查过程与判据，作为同类虚拟化环境（青云/pitrix 系、YUNIFY 等）时钟问题的标准排查路径。

**现象（入口线索）**

- 备份脚本日志时间轴顺序推进到 `15:02:34` 后，下一行突然变成 `15:01:45`，其后所有步骤都落在 15:01:45~15:01:47——同一脚本顺序执行、墙钟倒退约 50 秒；`ls -lrth` 中最后生成的文件 mtime 反而排最前，互为佐证。
- `chronyc tracking` **当前值健康**（System time 偏差 0.07ms、Last offset 0.1ms），但 **`RMS offset : 36.79 seconds`**——近期测量偏差均方根达几十秒（正常应为毫秒级），证明近期确有大幅跳变。**当前 tracking 健康 ≠ 时钟健康，RMS offset 与 step 计数才是判据。**

**排查过程（可复用的取证序列）**

```bash
# 1) chrony 状态与源
chronyc tracking            # 重点看 RMS offset：毫秒级=健康；秒级以上=近期有跳变
chronyc sources -v          # 源数量、当前偏差；单源本身即是隐患

# 2) chronyd 日志（★journal 若非持久化，重启即清空——务必用 rsyslog /var/log/messages 兜底）
journalctl -u chronyd --since today --no-pager
grep 'chronyd' /var/log/messages | grep -E 'Backward time jump|was stepped'
grep 'chronyd' /var/log/messages | grep -cE 'was stepped'    # 跳变次数（正常应为 0）

# 3) 找绕过 chronyd 直接设钟的第三方（平台 guest agent 设钟不写 syslog，日志里查不到肇事者时主动查它）
rpm -qa | grep -iE 'qemu-guest|guest-agent'
systemctl list-units | grep -i guest

# 4) 横向对比同平台其它虚机 + 内网 NTP 源自身（多机日志相位互锁 = 平台统一调度的铁证）
#    在 nginx/rancher/harbor 等同平台机器上重复 1)~3)
```

**现场证据链与根因（2026-07-08，vbdb01 / nginx01 / harbor 三机取证）**

- **三机同一剧本、严格 30 分钟周期**：guest agent 按计划把虚机时钟拽回宿主机时间（`Backward time jump detected!`，倒退 ~50s）→ chronyd 作废全部测量、约 2 分钟后判定 `System clock wrong by ~50s` 并 step 拽回 → 半小时后重复。每机**每小时 4 次 ±50 秒跳变**（2 退 2 进）；rsyslog 计数 harbor 120 次、nginx01 119 次 / 约 60 小时覆盖期，不间断。
- **肇事者**：三机均安装并运行 pitrix guest-agent（`guest-agent-1.1-0.x86_64`，systemd 日志 “Started guest agent for pitrix”；青云系平台内部代号，与 swap 的 YUNIFYSWAP 标签互证）。agent 直接 settime、不写 syslog——15:00-15:06 事发窗口 grep chrony/clock/step 查无肇事记录，正是其行为特征。
- **宿主机时钟自由漂移（无 NTP 约束）**：偏差从 7 月 6 日 47.11s 单调涨至 7 月 8 日 50.63s，漂移率 **≈16.4 ppm**（vbdb01 独立测算 ~17 ppm，一致），即每天再多落后 ~1.4 秒；按漂移率回推，偏差归零点约在 6 月初——平台上线以来宿主机即未配置 NTP。
- **集群级同一坏钟**：nginx01 15:03 偏差 50.615073s，vbdb01 15:05 偏差 50.615097s——**小数点后四位一致**，排除“个别宿主机”，是整个计算集群（或平台时间主）的问题。
- **NTP 源自身也在锯**：harbor 为内网唯一 NTP 源（上游 ntp1.aliyun.com），自己同样每 30 分钟被拽一次；客户端每轮 :22/:52 报 `Can't synchronise: no selectable sources`——正是 harbor 被拽偏 50 秒、被客户端判为不可选的相位，两侧日志相位严丝合缝互相咬合。
- 各机 `makestep 1.0 -1`（无限次 step）使 chronyd 每次都能拽回，**掩盖了问题的可见性**：表面一切正常，实际全网时钟每小时锯 4 次。

**影响面（为什么必须处置）**

数据库侧：PITR `recovery_target_time` 语义、日志/审计取证排序、备份日志时间轴（本案入口）；系统侧：cron 遇倒跳**重复触发**、遇前跳**漏触发**；平台侧：CAS/SSO ticket 与 JWT 的秒级有效期窗口（50 秒足以造成“未生效/已过期”偶发认证失败）、K8s/etcd、TLS 证书有效期边界、跨机日志关联。如近期存在解释不通的偶发认证失败或定时任务异常，此为首要嫌疑。

**处置（按根到梢排序，顺序不可颠倒）**

1. **平台工单（根因）**：给虚拟化团队——「计算集群宿主机（或平台时间主）未配置 NTP，时钟以 ~16.4ppm 自由漂移、当前落后约 50 秒且每日再落后 ~1.4 秒；平台 guest-agent 每 30 分钟将坏时钟强制同步至所有虚机，造成全部虚机每小时 4 次 ±50 秒跳变，自约 6 月初持续至今。请为宿主机配置 NTP（校园 NTP 或公网源均可）。」附多机日志与漂移曲线。宿主机修好后，agent 同步过来的即是正确时间，锯齿自然消失——**不必逐台虚机关 agent 时间同步**（治标且工作量大；agent 还承担改密码/配 IP 等功能，勿整体 disable）。
2. **宿主机修复、锯齿确认消失后**，各虚机把 `makestep 1.0 -1` 收敛为 `makestep 1.0 3`（仅开机前 3 次允许 step，运行期一律 slew）。**顺序不可颠倒**：锯齿未除先收 makestep，chronyd 只能以 slew 慢慢追 50 秒的坑、期间时钟长期不准，更糟。
3. **NTP 拓扑加固**：harbor 上游由单一 ntp1.aliyun.com 扩为 ≥3 源（阿里云 ntp1~ntp3 或加校园源）；内网客户端也不要只指 harbor 一台（可加二级源），单源无 falseticker 仲裁能力。
4. **数据库主机开启 journald 持久化**：`mkdir -p /var/log/journal && systemctl restart systemd-journald`。本案取证全靠 rsyslog 兜底——易失 journal 重启即清空，生产数据库主机不可接受（§19.4.8 受控重启核验同样因此改用 pg_log 作凭据）。

**日常巡检判据**（已并入 §18.2）：`chronyc tracking` 的 RMS offset 应为毫秒级；chronyd **今日**应无任何 step/跳变记录。★注意 `grep -c 'was stepped'` 是**历史累计计数**（现场 vbdb01 累计 463 次——默默锯了一个月，计数永不归零），不可作现状判据；现状看 `journalctl -u chronyd --since today`（应 No entries）或 `grep 'was stepped' /var/log/messages | tail -1` 的**最后时间戳**。任一超标即时钟异常，按本节序列取证。全网核查（ansible）：

```bash
ansible -i ./hosts all -m shell -a "journalctl -u chronyd --since today --no-pager | tail -3" -o
ansible -i ./hosts all -m shell -a "grep 'was stepped' /var/log/messages | tail -1" -o
```

**处置进展补记（2026-07-08 ~ 07-09）**

- **07-08 ~17:00 平台侧反馈「已修改」，锯齿即时停止**：harbor 最后一次 step 为 16:57（50.723489s），此后 17:23/17:53/18:23 三个本应发作的相位均未响。
- **07-09 10:19 全网复核**：ansible 15 台 `journalctl -u chronyd --since today` 全部 `No entries`——连续 ~17 小时零跳变，**止血正式确认**。
- **但修的是 agent 时间同步，不是宿主机 NTP（根治待办）**。铁证在 harbor `chronyc tracking`：`Frequency : 15.330 ppm slow`、`Skew : 0.510 ppm`——chronyd 测得底层时钟仍以 ~15.3ppm 持续变慢（与此前测算的宿主机 16.4ppm 吻合），只是无人再拽、chronyd 的频率补偿完全罩得住（Skew 0.51ppm 表明补偿已锁定）。`RMS offset 3.5s` 是旧跳变的衰减余波，数日后自然归零，不必处理。
- **残余风险（工单改「止血确认、宿主机 NTP 待配置」，保持打开）**：①宿主机本地时间继续漂移（日 +1.4 秒，数月即分钟级），其自身日志/服务受影响；②虚机**冷启动从宿主机 RTC 取时**，开机头几分钟时钟错、待 chronyd 选源后 step 校正——数据库主机的重启窗口内不理想。
- **下一步（本节处置第 2/3 步窗口已到）**：确认 24-48h 无新锯齿后，ansible 全网将 `makestep 1.0 -1` 收敛为 `makestep 1.0 3` 并重启 chronyd；NTP 源扩为 ≥3（harbor 上游加 ntp2/ntp3.aliyun 或校园源，内网客户端勿单指 harbor）。
- 附带实证：nfs 与 vbdb01 两台受控重启后 journal 的 `Logs begin` 即重启时刻（易失 journal 重开）——再证本节处置第 4 步「数据库主机开 journald 持久化」的必要性。

---

## 15. 生产交付预检模板

### 15.1 操作系统一键预检脚本

保存为 `/vastbase/scripts/sql/precheck_os.sh`，root 执行：

```bash
#!/bin/bash
set -u
OUT=/tmp/vastbase_precheck_$(hostname)_$(date +%F_%H%M%S).txt
{
  echo "===== 基本信息 ====="
  hostnamectl
  cat /etc/os-release
  uname -a
  date

  echo "===== CPU / Memory ====="
  lscpu
  free -h

  echo "===== Disk / Filesystem ====="
  lsblk -f
  df -hT
  mount | grep vastbase || true

  echo "===== Network ====="
  ip -br addr
  ip route
  ss -ntlp | egrep '(:22|:5432|:26000)' || true

  echo "===== Time ====="
  timedatectl
  chronyc tracking 2>/dev/null || true
  chronyc sources -v 2>/dev/null || true

  echo "===== Kernel Parameters ====="
  sysctl kernel.shmmax kernel.shmall kernel.sem vm.swappiness fs.file-max net.core.somaxconn 2>/dev/null
  cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
  cat /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true

  echo "===== Limits ====="
  su - vastbase -c 'ulimit -a' 2>/dev/null || true

  echo "===== Firewall / SELinux ====="
  getenforce 2>/dev/null || true
  systemctl is-active firewalld 2>/dev/null || true
  firewall-cmd --list-all --zone=public 2>/dev/null || true

  echo "===== VastBase Env ====="
  su - vastbase -c 'echo GAUSSHOME=$GAUSSHOME; echo PGDATA=$PGDATA; command -v vb_initdb gs_initdb vsql gsql gs_ctl vb_ctl 2>/dev/null' 2>/dev/null || true
} | tee "$OUT"
echo "Precheck report: $OUT"
```

### 15.2 数据库一键预检 SQL

保存为 `/vastbase/scripts/sql/precheck_db.sql`：

```sql
\echo '===== version ====='
SELECT version();

\echo '===== instance settings ====='
SELECT name, setting, unit, context
  FROM pg_settings
 WHERE name IN ('listen_addresses','port','max_connections','shared_buffers','work_mem',
                'archive_mode','archive_command','logging_collector','log_min_duration_statement',
                'b_compatibility_mode','lower_case_table_names','vastbase_sql_mode','enable_set_variable_b_format','password_encryption_type')
 ORDER BY name;

\echo '===== database list ====='
SELECT datname, datcompatibility, datistemplate, datallowconn, datconnlimit,
       pg_size_pretty(pg_database_size(datname)) AS size
  FROM pg_database
 ORDER BY pg_database_size(datname) DESC;

\echo '===== tablespace list ====='
SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) AS size
  FROM pg_tablespace
 ORDER BY pg_tablespace_size(spcname) DESC;

\echo '===== active sessions ====='
SELECT datname, usename, state, count(*)
  FROM pg_stat_activity
 GROUP BY datname, usename, state
 ORDER BY 1,2,3;
```

执行：

```bash
su - vastbase
$VB_SQL -h 127.0.0.1 -p $PGPORT -U vbadmin -d postgres -f /vastbase/scripts/sql/precheck_db.sql \
  | tee /vastbase/log/precheck_db_$(date +%F_%H%M%S).txt
```

### 15.3 带 PASS/FAIL 判定的预检脚本（推荐用于交付验收）

15.1 的脚本侧重"抓现场"，本节脚本侧重"明确给出能不能投产的结论"。  
保存为 `/vastbase/scripts/sql/precheck_assert.sh`，root 执行，**退出码非 0 即代表不通过**：

```bash
#!/bin/bash
#==============================================================================
# precheck_assert.sh ?? 带 pass/fail 判定的部署预检 (VastBase G100 v8.0.3)
# 退出码: 0=全部通过；非0=失败项数
#
# 可调变量(均可在调用前 export 覆盖):
#   DATA_DIR=/vastbase/data          PGDATA 目录(单盘目录隔离场景)
#   REQUIRE_DEDICATED_MOUNT=0        1=要求 DATA_DIR 为独立挂载点(FAIL);0=单盘可接受(WARN)
#   DB_PORT=5432                     实例端口
#   DB_PROBE_DB=postgres             探活库
#   REPL_NODES=0                     备机数量(算 max_wal_senders)
#   BASEBACKUP_CONCURRENCY=1         并发 basebackup 数
#   REMOTE_SSH_TARGET=root@192.168.100.100   远端备份目标(免密 SSH 验证)
#
# 重要: DB 探活使用"初始超级用户"(initdb 时的 OS 安装用户 vastbase, 走本地 socket
#       peer 认证)。切勿用 vbadmin 等业务账户做探针??连接失败会累加
#       failed_login_attempts, 跑够阈值会把账户锁定(FATAL: account has been locked)。
#==============================================================================
set -u
RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
PASS=0; FAIL=0; WARN=0
REPORT=/tmp/vastbase_precheck_$(date +%F_%H%M%S).txt
: > "$REPORT"

DATA_DIR=${DATA_DIR:-/vastbase/data}
REQUIRE_DEDICATED_MOUNT=${REQUIRE_DEDICATED_MOUNT:-0}
DB_PORT=${DB_PORT:-5432}
DB_PROBE_DB=${DB_PROBE_DB:-postgres}
REPL_NODES=${REPL_NODES:-0}
BASEBACKUP_CONCURRENCY=${BASEBACKUP_CONCURRENCY:-1}
REMOTE_SSH_TARGET=${REMOTE_SSH_TARGET:-root@172.18.13.197}

check() {
    # check "标签" "实际值" "期望正则" [WARN|FAIL]
    local label="$1" actual="$2" expect="$3" level="${4:-FAIL}"
    if [[ "$actual" =~ $expect ]]; then
        printf "${GRN}[PASS]${RST} %-40s actual=%s\n" "$label" "$actual" | tee -a "$REPORT"
        PASS=$((PASS+1))
    else
        if [[ "$level" == "WARN" ]]; then
            printf "${YLW}[WARN]${RST} %-40s actual=%s expect=%s\n" "$label" "$actual" "$expect" | tee -a "$REPORT"
            WARN=$((WARN+1))
        else
            printf "${RED}[FAIL]${RST} %-40s actual=%s expect=%s\n" "$label" "$actual" "$expect" | tee -a "$REPORT"
            FAIL=$((FAIL+1))
        fi
    fi
}

warn_note() {  # 仅打印一条 WARN, 不做正则匹配
    printf "${YLW}[WARN]${RST} %-40s %s\n" "$1" "$2" | tee -a "$REPORT"
    WARN=$((WARN+1))
}

echo "===== VastBase precheck on $(hostname)  $(date '+%F %T') =====" | tee -a "$REPORT"
echo "DATA_DIR=$DATA_DIR  DB_PORT=$DB_PORT  REQUIRE_DEDICATED_MOUNT=$REQUIRE_DEDICATED_MOUNT" | tee -a "$REPORT"

# ---- OS ----
check "OS family"          "$(grep -oE 'Kylin|CentOS|RedHat|openEuler' /etc/os-release | head -1)" "Kylin|openEuler"
check "Arch"               "$(uname -m)"                                                          "x86_64|aarch64"
check "Kernel"             "$(uname -r)"                                                          "4\.|5\.|6\."
check "CPU cores"          "$(nproc)"                                                              "^([4-9]|[1-9][0-9]+)$"
check "Memory(GB)"         "$(free -g | awk '/^Mem:/{print $2}')"                                  "^([8-9]|[1-9][0-9]+)$"

# ---- THP / SELinux / Firewall ----
check "THP"                "$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -oE '\[never\]')" "\[never\]"
check "SELinux"            "$(getenforce 2>/dev/null)"                                             "Disabled|Permissive"
check "firewalld"          "$(systemctl is-active firewalld 2>/dev/null)"                          "active"
check "fw rule has 5432"   "$(firewall-cmd --list-all --zone=public 2>/dev/null | grep -c '5432')"  "[1-9]"

# ---- Kernel sysctl ----
check "vm.swappiness"      "$(sysctl -n vm.swappiness 2>/dev/null)"                                "^([0-9]|10)$"  WARN
check "fs.file-max"        "$(sysctl -n fs.file-max 2>/dev/null)"                                  "^[1-9][0-9]{6,}$"
check "net.somaxconn"      "$(sysctl -n net.core.somaxconn 2>/dev/null)"                           "^[1-9][0-9]{3,}$"
check "kernel.shmmax(GB)"  "$(( $(sysctl -n kernel.shmmax 2>/dev/null) / 1024 / 1024 / 1024 ))"    "^([3-9]|[1-9][0-9]+)$"

# ---- Disk / Data dir ----
# 单盘环境只能做目录隔离, DATA_DIR 不是独立挂载点是设计决定; 通过 REQUIRE_DEDICATED_MOUNT 控制严格度
check "data dir exists"    "$(test -d "$DATA_DIR" && echo yes || echo no)"                          "yes"
if mountpoint -q "$DATA_DIR" 2>/dev/null; then
    check "data dir mounted"   "mounted"     "mounted"
elif [[ "$REQUIRE_DEDICATED_MOUNT" == "1" ]]; then
    check "data dir mounted"   "not-mounted" "mounted"   # 触发 FAIL
else
    warn_note "data dir dedicated mount" "shared-with-root (单盘目录隔离: 数据/WAL/归档/日志共用 root LV, 必须配 / 磁盘水位告警)"
fi
check "data dir free(GB)"  "$(df -BG --output=avail "$DATA_DIR" 2>/dev/null | tail -1 | tr -d 'G ')" "^([5-9][0-9]|[1-9][0-9]{2,})$"
check "filesystem"         "$(df -T "$DATA_DIR" 2>/dev/null | awk 'NR==2{print $2}')"               "xfs|ext4"

# ---- Limits ----
check "ulimit nofile"      "$(su - vastbase -c 'ulimit -n' 2>/dev/null)"                           "^[1-9][0-9]{5,}$"
check "ulimit nproc"       "$(su - vastbase -c 'ulimit -u' 2>/dev/null)"                           "unlimited|^[1-9][0-9]{4,}$"

# ---- VastBase env ----
INITDB=$(su - vastbase -c 'command -v vb_initdb 2>/dev/null || command -v gs_initdb 2>/dev/null')
check "VB initdb binary"   "$INITDB"                                                                "/.+"
check "GAUSSHOME exists"   "$(test -d /vastbase/app && echo yes || echo no)"                       "yes"

# ---- Install evidence ----
check "initdb help evidence" "$(ls /vastbase/docs/evidence/vb_initdb_help_* 2>/dev/null | head -1)"       "/.+"  WARN

# ---- DB connectivity (有实例时才检查; 用初始超级用户走本地 socket, 不碰 vbadmin) ----
SQL=$(su - vastbase -c 'command -v vsql 2>/dev/null || command -v gsql 2>/dev/null')
if [[ -n "$SQL" ]] && su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -c 'select 1' >/dev/null 2>&1"; then
    check "DB login"           "ok" "ok"
    check "appdb compat"        "$(su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -At -c \"SELECT datcompatibility FROM pg_database WHERE datname='appdb';\" 2>/dev/null")" "B"
    check "lower_case_table_names" "$(su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -At -c \"SHOW lower_case_table_names;\" 2>/dev/null")" "0|1"

    # vastbase_sql_mode: VastBase 用小写内部 token(如 sql_mode_strict / only_full_group_by),
    # 与 MySQL 风格大写 token 不同。小写化后按 token 存在性校验, 单列出严格模式与 group_by。
    SQLMODE=$(su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -At -c \"SHOW vastbase_sql_mode;\" 2>/dev/null" | tr 'A-Z' 'a-z')
    check "sql_mode strict"     "$SQLMODE" "strict"
    check "sql_mode group_by"   "$SQLMODE" "only_full_group_by"

    check "archive_mode"        "$(su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -At -c \"SHOW archive_mode;\" 2>/dev/null")"     "on"  WARN
    check "logging_collector"   "$(su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -At -c \"SHOW logging_collector;\" 2>/dev/null")" "on"

    # wal_level: 物理备份(basebackup/probackup)需 >= hot_standby; 逻辑复制/逻辑解码需 = logical
    check "wal_level"           "$(su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -At -c \"SHOW wal_level;\" 2>/dev/null")" "hot_standby|logical"

    MAX_WAL_SENDERS=$(su - vastbase -c "$SQL -p $DB_PORT -d $DB_PROBE_DB -At -c \"SHOW max_wal_senders;\" 2>/dev/null")
    REQUIRED_WALSENDERS=$((REPL_NODES + BASEBACKUP_CONCURRENCY + 2))
    if [[ "$MAX_WAL_SENDERS" =~ ^[0-9]+$ && "$MAX_WAL_SENDERS" -ge "$REQUIRED_WALSENDERS" ]]; then
        check "max_wal_senders capacity" "$MAX_WAL_SENDERS" "^[0-9]+$" WARN
    else
        warn_note "max_wal_senders capacity" "actual=${MAX_WAL_SENDERS:-unknown} expect=>=$REQUIRED_WALSENDERS (repl_nodes + basebackup_concurrency + 2)"
    fi
else
    warn_note "DB checks" "SKIP: instance not reachable (预初始化阶段正常; initdb 起实例后请重跑验 B 兼容那一组)"
fi

# ---- Backup readiness ----
check "backup.env exists"   "$(test -f /vastbase/scripts/backup.env && echo yes || echo no)"        "yes"
check "databases.list"      "$(test -f /vastbase/scripts/databases.list && echo yes || echo no)"    "yes"
check ".pgpass perm"        "$(stat -c '%a' /home/vastbase/.pgpass 2>/dev/null)"                    "600"
check "remote SSH"          "$(su - vastbase -c "ssh -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_SSH_TARGET hostname 2>/dev/null")" ".+"  WARN

echo "----------------------------------------" | tee -a "$REPORT"
echo "PASS=$PASS  WARN=$WARN  FAIL=$FAIL  ->  report: $REPORT" | tee -a "$REPORT"
exit $FAIL

```

加进 crontab 做日常体检（任何项变红立即告警）：

```cron
0 7 * * *  /vastbase/scripts/precheck_assert.sh > /vastbase/log/precheck_daily.log 2>&1 \
          || mail -s "[VastBase precheck FAIL] $(hostname)" ops@example.com < /vastbase/log/precheck_daily.log
```

---

## 16. 安全加固与审计建议

### 16.1 账号与权限分层

| 账号类型 | 示例 | 权限原则 |
|----------|------|----------|
| 实例管理员 | `vbadmin` | 仅 DBA 使用，不给应用程序配置 |
| 应用写账号 | `appuser` | 只授业务 schema 的 DML 权限 |
| 只读账号 | `rouser` | 只授 SELECT，连接数受限 |
| 备份账号 | `backup_user` | 优先使用最小备份权限；如工具要求高权限，限制来源 IP 与使用场景 |
| 跨库代理账号 | `cat_proxy` | 只授被访问对象的 SELECT，不复用业务账号 |

建议：

```sql
-- 禁止 public schema 被随意创建对象
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 限制连接数，避免单账号打满连接
ALTER USER appuser CONNECTION LIMIT 100;
ALTER USER rouser  CONNECTION LIMIT 30;

-- 到期策略按客户安全基线计算，不写固定年份示例；将 <YYYY-MM-DD> 替换为投产时计算值。
-- ALTER USER appuser VALID UNTIL '<YYYY-MM-DD>';  -- 例如按投产日 + 180 天生成
```

### 16.2 口令、认证与传输加密

`pg_hba.conf` 中生产禁止对远端使用 `trust`。优先使用 `sha256`、`scram-sha256` 或客户要求的国密 `sm3`；如启用 SSL，优先使用 `hostssl` 并配置服务端证书。

示例：

```conf
# 只允许业务网段通过 SSL 连接业务库
hostssl  appdb  appuser  192.168.10.0/24  sha256

# 禁止所有未显式授权来源
host     all    all      0.0.0.0/0        reject
```

SSL 参数示例（路径按实际证书调整）：

```ini
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file  = 'server.key'
ssl_ca_file   = 'ca.crt'
```


#### 16.2.1 自签证书生成脚本（内网测试 / POC 用）

> 生产环境应使用客户 PKI 或商业 CA 签发的证书；下面这段仅用于内网测试 / 无外部 CA 时的兜底。root 执行时通常没有 `PGDATA` 环境变量，因此脚本显式提供默认值。

```bash
#!/bin/bash
# /vastbase/scripts/gen_ssl_cert.sh —— root 执行
set -euo pipefail
PGDATA=${PGDATA:-/vastbase/data}
SSL_DIR="$PGDATA"
HOST=$(hostname -f 2>/dev/null || hostname)
DAYS=730

[[ -d "$SSL_DIR" ]] || { echo "PGDATA not found: $SSL_DIR"; exit 1; }
cd "$SSL_DIR"

# 1) CA 私钥与自签 CA 证书
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days $((DAYS*2)) \
            -subj "/C=CN/ST=Shaanxi/L=Xian/O=Customer/OU=DBA/CN=VastBase-CA" \
            -out ca.crt

# 2) 服务端私钥 + CSR
openssl genrsa -out server.key 2048
openssl req -new -key server.key \
            -subj "/C=CN/ST=Shaanxi/L=Xian/O=Customer/OU=DB/CN=${HOST}" \
            -out server.csr

# 3) SAN 扩展：用 IP 直连时必须包含 IP
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
cat > server_ext.cnf <<EOF
subjectAltName = DNS:${HOST},IP:127.0.0.1,IP:${PRIMARY_IP}
EOF

# 4) CA 签发
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
             -out server.crt -days $DAYS -sha256 -extfile server_ext.cnf

# 5) 权限
chown vastbase:dbgrp server.key server.crt ca.crt
chmod 600 server.key
chmod 644 server.crt ca.crt
rm -f server.csr server_ext.cnf ca.srl

echo "SSL 证书生成完毕。将 postgresql.conf 中 ssl/ssl_cert_file/ssl_key_file/ssl_ca_file 指向上述文件后重启实例。"
```

应用证书后重启实例：

```bash
su - vastbase -c '$VB_CTL restart -D $PGDATA -m fast'
su - vastbase -c '$VB_SQL -d postgres -U vbadmin -c "SHOW ssl;"'
```

#### 16.2.2 口令复杂度与账号锁定（VastBase / openGauss 原生）

不依赖 OS PAM，数据库内部即可实现：

```ini
# postgresql.conf —— 需重启
password_encryption_type     = 2                    # 0=md5, 1=sha256, 2=sha256+md5, 3=sm3(国密)
password_policy              = 1                    # 1=开启口令策略，0=关
password_min_length          = 12
password_max_length          = 32
password_min_uppercase       = 1
password_min_lowercase       = 1
password_min_digital         = 1
password_min_special         = 1
password_reuse_max           = 5                    # 不能与最近 5 次重复
password_reuse_time          = 60                   # 60 天内不能复用旧密码
password_effect_time         = 90                   # 口令有效期 90 天
password_notify_time         = 7                    # 到期前 7 天提示
failed_login_attempts        = 5                    # 5 次失败即锁
password_lock_time           = 1                    # 锁定 1 天，0 表示需 DBA 手工解锁
auth_iteration_count         = 10000                # 哈希迭代次数（≥ 客户基线）
```

```bash
$VB_CTL restart -D $PGDATA -m fast
```

账号锁定查询与解锁：

```sql
-- 锁定报错 failed_login_attempts = 5
Password for user vbadmin: 
vsql: FATAL:  The account has been locked.

-- vbadmin账户需要初始化账户vastbase来解锁
su - vastbase -c 'vsql -d postgres -p 5432 -c "ALTER USER vbadmin ACCOUNT UNLOCK;"'

-- 锁定状态（视图名因版本而异，常见为 pg_authid 的 rolstatus / pg_roles）
SELECT rolname, rolvaliduntil
  FROM pg_roles
 WHERE rolname NOT IN ('vbadmin', 'pg_signal_backend');
 
su - vastbase -c "vsql -d postgres -p 5432 -At -c \
  \"SELECT rolname, rolstatus FROM pg_authid WHERE rolname='vbadmin';\""
  
-- 全部账户状态查询
SELECT
    r.rolname AS username,
    CASE s.rolstatus
        WHEN 0 THEN '正常'
        WHEN 1 THEN '登录失败次数超限，临时锁定'
        WHEN 2 THEN '管理员手工锁定'
        ELSE '未知状态'
    END AS account_lock_status,
    s.failcount AS failed_login_count,
    s.locktime AS lock_time,
    CASE s.passwordexpired
        WHEN 0 THEN '密码有效'
        WHEN 1 THEN '密码失效'
        ELSE '未知'
    END AS password_status,
    CASE r.rolcanlogin
        WHEN true THEN '允许登录'
        ELSE '禁止登录(NOLOGIN)'
    END AS login_attr,
    r.rolvalidbegin AS valid_begin,
    r.rolvaliduntil AS valid_until
FROM pg_roles r
LEFT JOIN pg_user_status s
       ON r.oid = s.roloid
WHERE r.rolcanlogin = true
ORDER BY r.rolname;

-- 单账户查询
SELECT
    r.rolname AS username,
    CASE s.rolstatus
        WHEN 0 THEN '正常'
        WHEN 1 THEN '登录失败次数超限，临时锁定'
        WHEN 2 THEN '管理员手工锁定'
        ELSE '未知状态'
    END AS account_lock_status,
    s.failcount AS failed_login_count,
    s.locktime AS lock_time,
    CASE s.passwordexpired
        WHEN 0 THEN '密码有效'
        WHEN 1 THEN '密码失效'
        ELSE '未知'
    END AS password_status,
    r.rolcanlogin,
    r.rolvalidbegin,
    r.rolvaliduntil
FROM pg_roles r
LEFT JOIN pg_user_status s
       ON r.oid = s.roloid
WHERE r.rolname = 'vbadmin';

-- 手工解锁
ALTER USER appuser ACCOUNT UNLOCK;

-- 强制下一次登录修改密码
ALTER USER appuser PASSWORD EXPIRE;
```

### 16.3 审计与日志保留

日志目录 `/vastbase/log/pg_log` 应纳入集中日志平台或至少进行本机轮转与归档。建议记录：连接/断连、DDL、锁等待、慢 SQL、临时文件、错误码。日志保留周期按合规要求配置，常见为本机 30 天、集中平台 180 天或更长。

```ini
log_connections            = on
log_disconnections         = on
log_statement              = 'ddl'
log_lock_waits             = on
log_min_duration_statement = 1000
log_temp_files             = 10240     # 10MB 阈值；0=记录所有临时文件，-1=禁用
```

#### 16.3.1 VastBase 原生审计开关（独立于 pg_log）

VastBase / openGauss 自带审计功能（audit），日志独立写到 `$GAUSSLOG/pg_audit/`。启用前先显式创建审计子目录，避免部分补丁包无法自动创建目录导致启动或审计写入失败：

```bash
su - vastbase -c 'mkdir -p /vastbase/log/gauss/pg_audit && chmod 700 /vastbase/log/gauss/pg_audit'
```

```ini
# postgresql.conf —— 多数审计项支持 reload；首次启用或目录变更后建议重启一次验收
audit_enabled               = on
audit_directory             = '/vastbase/log/gauss/pg_audit'
audit_data_format           = 'binary'
audit_rotation_interval     = 1d
audit_rotation_size         = 100MB
audit_resource_policy       = on         # on=空间不足时按 audit_space_limit/audit_file_remain_time 自动清理

# 采集事件（按位与，按合规要求开启）
audit_login_logout          = 7           # 1=login, 2=logout, 4=fail
audit_database_process      = 1           # 启停事件
audit_user_locked           = 1
audit_grant_revoke          = 1
audit_system_object         = 15          # DATABASE(0)+SCHEMA(1)+USER(2)+DATA SOURCE(3) = 1+2+4+8
audit_dml_state             = 1           # 表级 DML 审计开关
audit_dml_state_select      = 0           # 0=不审计 SELECT；合规要求时设 1，但代价大
audit_function_exec         = 1
audit_copy_exec             = 1
audit_set_parameter         = 1

# 位掩码说明：audit_login_logout = 1(login) + 2(logout) + 4(login_failed) = 7。
# audit_system_object：审计哪些对象类型的 DDL；按 V3.0.8PSU4 手册的位表换算。
# 起步示例：DATABASE(0) + SCHEMA(1) + USER(2) + DATA SOURCE(3) = 1+2+4+8 = 15。
# 如需扩大到 TABLE/INDEX/VIEW/FUNCTION/TRIGGER 等，请按“位运算 + 注释”方式自行换算，
# 不要直接复用历史模板的魔数（如 67121159 或 12295）。

# 空间约束
audit_space_limit           = 1024000     # KB，1GB
audit_file_remain_threshold = 1048576     # 单文件大小阈值
audit_file_remain_time      = 90          # 审计文件保留天数
```

查询审计日志：

```sql
-- 查询近一天登录失败
SELECT * FROM pg_query_audit(
    now() - INTERVAL '1 day',
    now()
) WHERE type = 'login_failed';

-- 查询 DDL 历史
SELECT * FROM pg_query_audit(now() - INTERVAL '7 days', now())
 WHERE operation IN ('CREATE','DROP','ALTER')
 ORDER BY time DESC LIMIT 100;
```

> 如 `pg_query_audit` 报函数签名不匹配（例如提示 `function pg_query_audit(... timestamp, ...) does not exist`），把入参显式转换为 `timestamp without time zone`，例如：`pg_query_audit(CAST(now() - INTERVAL '1 day' AS timestamp), CAST(now() AS timestamp))`。

> 函数 `pg_query_audit` 仅审计员（拥有 `auditadmin` 属性的角色）可执行；DBA 角色与审计员应**职责分离**，避免 DBA 删自己的操作记录：
> ```sql
> CREATE USER auditor WITH PASSWORD 'XXX' AUDITADMIN LOGIN;
> REVOKE AUDITADMIN FROM vbadmin;     -- 部分版本默认带，按需收回
> ```

#### 16.3.2 操作系统层 auditd

```bash
yum install -y audit audit-libs
systemctl enable --now auditd
cat >> /etc/audit/rules.d/vastbase.rules <<'EOF'
-w /vastbase/app  -p wa -k vastbase_app_change
-w /vastbase/data -p wa -k vastbase_data_change
-w /vastbase/scripts -p wa -k vastbase_script_change
-w /etc/systemd/system/vastbase.service -p wa -k vastbase_service_change
EOF
auditctl -R /etc/audit/rules.d/vastbase.rules
```

#### 16.3.3 logrotate（备份与脚本日志）

`pg_log` 自带轮转，但 `/vastbase/log/backup/` 等业务脚本日志需要单独管：

```bash
cat > /etc/logrotate.d/vastbase <<'EOF'
/vastbase/log/backup/*.log /vastbase/log/*.log {
    daily
    rotate 60
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su vastbase dbgrp
    create 0640 vastbase dbgrp
}
EOF
logrotate -d /etc/logrotate.d/vastbase   # 仅 dry-run 验证
```

### 16.4 敏感信息处理

交付文档、脚本和日志中不应保留真实口令。建议交付前执行：

```bash
grep -RInE "password|passwd|Vbadmin@|Appuser@|Rouser@|CatProxy@" /vastbase/scripts /vastbase/tools 2>/dev/null
history -c
```

---

## 17. 物理备份、归档与 PITR 补充方案

逻辑备份适合按库、按表恢复，但恢复大库耗时较长，且只能恢复到 dump 时刻。生产建议同时启用“物理全量备份 + WAL 归档”，用于整实例快速恢复和时间点恢复（PITR）。

### 17.1 适用场景对比

| 方案 | 恢复粒度 | 优点 | 局限 |
|------|----------|------|------|
| 逻辑备份 `vb_dump/gs_dump` | 库/表/对象 | 灵活、可跨环境、可选择对象 | 大库恢复慢，只到备份时刻 |
| 物理备份 `vb_basebackup/gs_basebackup` | 整实例 | 恢复快，适合大库和灾难恢复 | 不适合单表取数 |
| WAL 归档 + PITR | 整实例到指定时间点 | 降低 RPO，可恢复到误操作前 | 依赖归档完整性，需演练 |

### 17.2 开启归档

#### 17.2.1 基础参数

```bash
su - vastbase
mkdir -p /vastbase/arch
chmod 700 /vastbase/arch

#参数
archive_mode = on
wal_level = hot_standby			# minimal, archive, hot_standby or logical

$VB_GUC set -D $PGDATA -c "wal_level = hot_standby"
$VB_GUC set -D $PGDATA -c "archive_mode = on"
$VB_GUC set -D $PGDATA -c "archive_timeout = 300"
```

#### 17.2.2 可靠的 `archive_command`

简单 `cp` 在以下情况会丢 WAL：
- 目标盘满 → cp 部分写入，文件不完整
- 同名文件已存在但内容不同（极少见，但有先例）
- 进程被信号打断 → 半截文件

下面这个脚本封装了**原子写入 + 校验 + 锁**，比 `cp` 安全得多。

`/vastbase/scripts/archive_wal.sh`：

```bash
#!/bin/bash
# 用法（由 archive_command 调用）: archive_wal.sh <%p> <%f>
# %p = WAL 源完整路径   %f = WAL 文件名（如 000000010000000000000005）
set -uo pipefail
SRC="$1"
NAME="$2"
ARCH_DIR=/vastbase/arch
LOG=/vastbase/log/wal_archive.log

DST="${ARCH_DIR}/${NAME}"
TMP="${ARCH_DIR}/.${NAME}.tmp.$$"

# 1) 已存在且 md5 一致 -> 视作成功（幂等）
if [[ -f "$DST" ]]; then
    if [[ "$(md5sum < "$DST" | awk '{print $1}')" == \
          "$(md5sum < "$SRC" | awk '{print $1}')" ]]; then
        echo "[$(date '+%F %T')] $NAME already archived (md5 match)" >> $LOG
        exit 0
    else
        echo "[$(date '+%F %T')] FAIL: $NAME exists with different md5" >> $LOG
        exit 1
    fi
fi

# 2) 原子拷贝：tmp -> fsync 文件 -> rename -> fsync 父目录
cp "$SRC" "$TMP" || { echo "[$(date '+%F %T')] cp fail $NAME" >> $LOG; exit 1; }
# Kylin V10 默认 coreutils 支持 sync FILE；若极老版本不支持，回退为整机 sync。
sync "$TMP" 2>/dev/null || sync
if mv "$TMP" "$DST"; then
    # fsync 父目录，确保 rename 后的目录项也持久化；极老 coreutils 不支持 sync DIR 时回退整机 sync。
    sync "$ARCH_DIR" 2>/dev/null || sync
    # 可选：再 rsync 一份到异地归档库（注释掉了，按需启用）
    # 注意：archive_command 在数据库后端环境中执行，LD_LIBRARY_PATH 含 $GAUSSHOME/lib，
    #       直接调 rsync/ssh 会撞 OPENSSL_1_1_1f 缺失；启用时务必加 env -u LD_LIBRARY_PATH。
    # env -u LD_LIBRARY_PATH rsync -q -e 'env -u LD_LIBRARY_PATH ssh' "$DST" vastbase@192.168.100.100:/backup/wal/ || true
    echo "[$(date '+%F %T')] OK $NAME" >> $LOG
    exit 0
else
    rm -f "$TMP"
    echo "[$(date '+%F %T')] mv fail $NAME" >> $LOG
    exit 1
fi
```

```bash
chmod 750 /vastbase/scripts/archive_wal.sh
chown vastbase:dbgrp /vastbase/scripts/archive_wal.sh

su - vastbase
$VB_GUC set -D $PGDATA -c "archive_command = '/vastbase/scripts/archive_wal.sh %p %f'"
#$VB_CTL restart -D $PGDATA -m fast

su - root
systemctl restart vastbase
systemctl status vastbase
```

验证分两步：先在 vsql 会话内触发一次 WAL 切换，再退到 shell 看归档结果。

> **VastBase G100 基于 openGauss 内核（PostgreSQL 9.2.4 分支），WAL 相关对象沿用 9.2 时代命名，不能照搬 PG10+/PG9.4+ 的写法：**
> - 切换函数是 **`pg_switch_xlog()`**，没有 PG10 才改名的 `pg_switch_wal()`（实测报 `function pg_switch_wal() does not exist`）；
> - **没有 PG9.4 才引入的 `pg_stat_archiver` 视图**（实测报 `relation "pg_stat_archiver" does not exist`），归档健康不能靠它判断。

第 1 步，在 vsql 交互会话内执行（本机工具不读 `.pgpass`，连接方式见 §10.3.1，可用 `vb_sql postgres` 进入或在提示时手工输入口令）：

```sql
SHOW archive_mode;
SHOW archive_command;
SELECT pg_current_xlog_location();              -- 记录切换前 WAL 位置
SELECT pg_xlogfile_name(pg_switch_xlog());      -- 触发一次 WAL 切换，返回被切出的段文件名
```

第 2 步，退出 vsql，以 vastbase 用户在 shell 中确认归档真的落地（这才是权威信号，因为没有 `pg_stat_archiver` 可查）：

```bash
# 1) 归档目录里应出现刚切换出的 WAL 段文件
ls -lt /vastbase/arch | head

# 2) archive_status 里 .ready 不应堆积：.ready=待归档，archive_command 成功(exit 0)后内核改名为 .done
#    openGauss 内核 WAL 目录为 pg_xlog（以 `ls $PGDATA` 实际名称为准；个别版本可能是 pg_wal）
ls -l "$PGDATA"/pg_xlog/archive_status/ | tail

# 3) archive_wal.sh 自身写的归档日志，确认刚切出的段有一行 OK
tail -n 20 /vastbase/log/wal_archive.log
```

> 归档健康的权威判据是 **`$PGDATA/pg_xlog/archive_status/` 下 `.ready` 文件是否堆积**：`.ready` 持续堆积 == `archive_command` 失败或严重滞后，等价于 PG 里 `pg_stat_archiver.failed_count` 持续非零，**必须报警**（自动化检查见 §17.2.3）。切换瞬间出现个位数 `.ready` 属正常瞬时态。


#### 17.2.3 归档目录监控

openGauss 内核没有 `pg_stat_archiver` 视图，因此**不能靠查库判断归档健康**——原先依赖该视图的脚本会在 `2>/dev/null` 下静默退化成“只查到空值、永远报 OK”，反而埋雷。可靠且与版本无关的判据是文件系统信号：`$PGDATA/pg_xlog/archive_status/` 下 `.ready` 文件堆积量（`.ready`=待归档，`archive_command` 成功后内核改名为 `.done`），辅以归档盘使用率。`.ready` 持续堆积即归档失败或严重滞后。

```bash
# 加进 crontab：每 5 分钟检查归档健康
*/5 * * * * /vastbase/scripts/archive_check.sh
```

`/vastbase/scripts/archive_check.sh`：

```bash
#!/bin/bash
set -uo pipefail
source /vastbase/scripts/backup.env   # 提供 PGDATA
ARCH_DIR=/vastbase/arch

# openGauss 内核（VastBase G100）无 PG9.4+ 的 pg_stat_archiver 视图，
# 归档健康改用文件系统信号：$PGDATA/pg_xlog(或 pg_wal)/archive_status/ 下
#   .ready = 待归档；archive_command 成功(exit 0)后由内核改名为 .done。
# .ready 持续堆积 == 归档失败/严重滞后，等价于 PG 里 failed_count 非零。
# 注意：本脚本不再连库，须以能读 $PGDATA 的用户（通常 vastbase）执行。
if [[ -d "${PGDATA:-}/pg_xlog/archive_status" ]]; then
    ASTAT_DIR="${PGDATA}/pg_xlog/archive_status"
elif [[ -d "${PGDATA:-}/pg_wal/archive_status" ]]; then
    ASTAT_DIR="${PGDATA}/pg_wal/archive_status"
else
    echo "ALERT: archive_status dir not found under \$PGDATA=${PGDATA:-unset}; check PGDATA in backup.env and run user perms" >&2
    exit 2
fi

READY=$(find "$ASTAT_DIR" -maxdepth 1 -name '*.ready' -type f 2>/dev/null | wc -l)
USED_PCT=$(df -P "$ARCH_DIR" | awk 'NR==2{gsub(/%/,"",$5); print $5}')

# 切换瞬间出现个位数 .ready 属正常瞬时态；持续堆积才是异常。
# 阈值按 WAL 生成速率与 5 分钟巡检间隔现场调整。
READY_WARN=3
READY_CRIT=10

if [[ "${READY:-0}" -ge "$READY_CRIT" ]]; then
    echo "ALERT: WAL archiving backlog: ${READY} .ready files in ${ASTAT_DIR} (archive_command likely failing); see /vastbase/log/wal_archive.log" >&2
    exit 2
fi

if [[ "${USED_PCT:-0}" -ge 85 ]]; then
    echo "ALERT: archive dir usage=${USED_PCT}% (.ready=${READY})" >&2
    exit 2
fi

if [[ "${READY:-0}" -ge "$READY_WARN" || "${USED_PCT:-0}" -ge 70 ]]; then
    echo "WARN: archive backlog .ready=${READY} dir_usage=${USED_PCT}%" >&2
    exit 1
fi

echo "OK: archive .ready=${READY} dir_usage=${USED_PCT}%"
```


#### 17.2.4 `pg_xlog` 膨胀、归档失败与同名 WAL 冲突排查处置

本节用于处理以下典型现象：`$PGDATA/pg_xlog` 持续增长、根分区或数据盘被 WAL 占满、`archive_status` 下 `.ready` 大量堆积、`wal_archive.log` 反复出现归档失败。现场案例中，`/vastbase/data/pg_xlog` 达到 **27G**，WAL 段文件约 **1690** 个，`archive_status/*.ready=1680`、`.done=0`，归档日志持续报：

```text
FAIL: 0000000100000000000000BA exists with different md5
```

根因是：`/vastbase/arch` 中已存在同名 WAL 文件，但与当前实例要归档的 `$PGDATA/pg_xlog/<wal>` md5 不一致。`archive_wal.sh` 为防止覆盖错误 WAL，按设计返回失败，导致最早的 `.ready` 一直不能归档，后续 `.ready` 也持续堆积，`pg_xlog` 无法回收。

> **红线**：不要在数据库运行时手工删除 `$PGDATA/pg_xlog/000000*`。`pg_xlog` 是数据库恢复一致性必需目录，直接删除 WAL 可能导致实例崩溃、无法启动、物理备份/PITR 链路失效。应先修复归档链路，让 `archive_command` 成功返回，由数据库自行把 `.ready` 转成 `.done` 并在 checkpoint 后回收。

> **prune 红线**：`enable_xlog_prune` 不是归档失败的修复手段，只有在归档健康（`.ready` 不持续堆积）且已明确配套 `max_size_for_xlog_prune` 阈值时，才可作为磁盘保命阀评审。若归档仍失败时让 prune 触发，可能回收尚未归档的 WAL，导致归档链/PITR 链静默断裂且不一定立刻报错。

**一、确认 `pg_xlog` 占用和 WAL 文件数量**

```bash
su - vastbase
cd /vastbase/data

echo "==== pg_xlog 总大小 ===="
du -sh pg_xlog

echo "==== WAL 段文件数量 ===="
find pg_xlog -maxdepth 1 -type f -regextype posix-extended \
  -regex '.*/[0-9A-F]{24}$' | wc -l

echo "==== archive_status 文件数量 ===="
find pg_xlog/archive_status -maxdepth 1 -type f 2>/dev/null | wc -l

echo "==== .ready/.done 数量 ===="
echo -n ".ready = "
find pg_xlog/archive_status -maxdepth 1 -name '*.ready' -type f 2>/dev/null | wc -l
echo -n ".done  = "
find pg_xlog/archive_status -maxdepth 1 -name '*.done' -type f 2>/dev/null | wc -l
```

判断口径：

| 现象 | 判断 |
|------|------|
| `.ready` 很多、`.done=0` 或很少 | 归档失败或严重滞后，是 `pg_xlog` 膨胀的首要嫌疑 |
| `.ready=0`，但 `pg_xlog` 仍偏大 | 可能是 checkpoint 尚未触发回收、复制槽/备库拖住、`wal_keep_segments`/`checkpoint_segments` 等保留参数较大 |
| `.ready=0`，`wal_archive.log` 持续 `OK` | 归档链路正常，重点关注归档目录 `/vastbase/arch` 的保留与清理策略 |

**二、查看 WAL 新旧分布，判断是历史积压还是短时突增**

```bash
cd /vastbase/data

echo "==== 最老的 WAL 文件 ===="
find pg_xlog -maxdepth 1 -type f -regextype posix-extended \
  -regex '.*/[0-9A-F]{24}$' \
  -printf '%TY-%Tm-%Td %TH:%TM:%TS %s %f\n' | sort | head -20

echo "==== 最新的 WAL 文件 ===="
find pg_xlog -maxdepth 1 -type f -regextype posix-extended \
  -regex '.*/[0-9A-F]{24}$' \
  -printf '%TY-%Tm-%Td %TH:%TM:%TS %s %f\n' | sort | tail -20

echo "==== 按日期统计 WAL 文件数量 ===="
find pg_xlog -maxdepth 1 -type f -regextype posix-extended \
  -regex '.*/[0-9A-F]{24}$' \
  -printf '%TY-%Tm-%Td\n' | sort | uniq -c
```

现场样例按日期连续堆积 7 天：

```text
69  2026-06-08
289 2026-06-09
288 2026-06-10
290 2026-06-11
289 2026-06-12
292 2026-06-13
128 2026-06-14
45  2026-06-15
```

说明不是单次 SQL 瞬时写入，而是归档长期失败后 WAL 被持续保留。

**三、检查归档日志和归档目录权限/空间**

```bash
cd /vastbase/data

echo "==== 最近的 .ready 文件 ===="
find pg_xlog/archive_status -maxdepth 1 -name '*.ready' -type f \
  -printf '%TY-%Tm-%Td %TH:%TM:%TS %f\n' 2>/dev/null | sort | tail -30

echo "==== 最近的 .done 文件 ===="
find pg_xlog/archive_status -maxdepth 1 -name '*.done' -type f \
  -printf '%TY-%Tm-%Td %TH:%TM:%TS %f\n' 2>/dev/null | sort | tail -30

echo "==== 归档脚本日志 ===="
tail -n 100 /vastbase/log/wal_archive.log 2>/dev/null

echo "==== 数据库日志中的归档失败 ===="
grep -RniE "archive command failed|could not be archived|too many failures|exists with different md5|permission|denied|no space|cannot|could not" \
  /vastbase/log/wal_archive.log /vastbase/data/pg_log /vastbase/log/pg_log 2>/dev/null | tail -100

echo "==== 归档目录权限和空间 ===="
ls -ld /vastbase/arch
df -h /vastbase/arch
touch /vastbase/arch/test_write_by_vastbase && rm -f /vastbase/arch/test_write_by_vastbase
```

如果日志出现：

```text
FAIL: 0000000100000000000000BA exists with different md5
archive command failed with exit code 1
xlog file "0000000100000000000000BA" could not be archived: too many failures
```

并且 `/vastbase/arch` 可写、磁盘空间充足，则重点判断为：**归档目录中存在旧实例、旧时间线、PITR 演练或重建前残留的同名 WAL，和当前实例 WAL 同名但内容不同**。

**四、数据库侧确认归档参数、WAL 保留参数、复制槽和备库状态**

```sql
select name, setting, unit, context
from pg_settings
where name in (
  'archive_mode',
  'archive_command',
  'archive_timeout',
  'wal_level',
  'wal_keep_segments',
  'checkpoint_segments',
  'checkpoint_timeout',
  'checkpoint_completion_target',
  'max_wal_senders',
  'max_replication_slots',
  'enable_xlog_prune',
  'max_size_for_xlog_prune',
  'advance_xlog_file_num'
)
order by name;

-- 复制槽细查：空结果通常不是槽拖住；有槽时重点看 active=false 且 restart_lsn 很旧的失效槽。
select slot_name, slot_type, active, restart_lsn, confirmed_flush_lsn
from pg_replication_slots
order by slot_name;

-- 估算复制槽保留 WAL 量；restart_lsn 为空时跳过。
select slot_name, active, restart_lsn,
       case when restart_lsn is null then null
            else pg_size_pretty(pg_xlog_location_diff(pg_current_xlog_location(), restart_lsn))
       end as retained_wal
from pg_replication_slots
order by slot_name;

-- 如当前版本支持 wal_status，可额外执行；不支持则不要写死到脚本中。
-- select slot_name, active, restart_lsn, wal_status from pg_replication_slots;

select * from pg_stat_replication;
```

现场异常参数样例：

```text
archive_mode            = on
archive_command         = /vastbase/scripts/archive_wal.sh %p %f
archive_timeout         = 300s
wal_level               = hot_standby
wal_keep_segments       = 16
checkpoint_segments     = 128
enable_xlog_prune       = off
max_replication_slots   = 8
max_wal_senders         = 4
```

判断说明：

- `pg_replication_slots` 为空：通常不是复制槽拖住 WAL；
- `pg_replication_slots` 有记录但 `active=false`、`restart_lsn` 很旧：即使 `pg_stat_replication` 为空，也可能因失效旧槽拖住 WAL；测试环境确认无业务依赖后，可在变更记录中执行 `SELECT pg_drop_replication_slot('<slot_name>');` 清理；生产必须先确认订阅、备库或 CDC 是否仍依赖该槽；
- `pg_stat_replication` 为空：单机测试环境无备库连接；但不能替代复制槽检查；
- `enable_xlog_prune`：不作为本案归档失败的修复手段。它更偏向备机断连场景下的 WAL 保留兜底，且必须与 `max_size_for_xlog_prune` 成对评审；
- `archive_command` 为脚本方式时，应优先看 `/vastbase/log/wal_archive.log` 的 `OK/FAIL`。

**五、验证归档链路是否仍卡在同一个 WAL**

```sql
show archive_mode;
show archive_command;
select pg_current_xlog_location();
select pg_xlogfile_name(pg_switch_xlog());
```

> 排障时手工切换 WAL 一两次足够。连续多次执行 `pg_switch_xlog()` 会快速制造新的小 WAL 段，反而干扰 `.ready`、归档日志和容量趋势判读；已有 `archive_timeout=300` 时更不应反复切换。

退出 vsql 后：

```bash
ls -lt /vastbase/arch | head -20
ls -lt /vastbase/data/pg_xlog/archive_status | head -20
tail -n 50 /vastbase/log/wal_archive.log 2>/dev/null
```

如果手工切换出的新 WAL 也只是新增 `.ready`，而日志仍反复报最早的旧段 `0000000100000000000000BA exists with different md5`，说明归档队列被最早失败段卡住，需要先处理归档目录中的冲突文件或冲突目录。

**六、测试环境推荐处置：隔离旧归档目录，重建空归档目录**

适用条件：本地测试环境、归档目录中数据不作为生产 PITR 依据、可接受将旧 `/vastbase/arch` 作为问题证据单独保留。

```bash
su - vastbase

cd /vastbase
mv arch arch.bad_md5.$(date +%F_%H%M%S)
mkdir -p /vastbase/arch
chmod 700 /vastbase/arch

ls -ld /vastbase/arch
touch /vastbase/arch/test_write_by_vastbase && rm -f /vastbase/arch/test_write_by_vastbase

vb_guc set -D $PGDATA -c "archive_command = '/vastbase/scripts/archive_wal.sh %p %f'"
vb_ctl reload -D $PGDATA
```

> 注意：将旧 `/vastbase/arch` 隔离并新建空归档目录后，新归档链会从当前 LSN 重新开始，与隔离前任何旧物理全量备份不再天然连续。测试环境也建议在归档恢复并验收通过后，立即重做一次 `vb_basebackup`/`gs_basebackup` 物理全量备份；生产环境必须重做全量，否则新的归档目录不能单独支撑 PITR。重做全量后，还应同步将隔离前已经失去连续归档链的旧 basebackup 目录移入失效归档区或按备份保留策略清退，不要继续放在 `/vastbase/backup/base` 参与 §17.5 `wal_cleanup.sh` 的边界计算；否则清理脚本可能锚定一个实际不可恢复的旧备份，导致少删/不删，并造成“旧备份仍可 PITR”的误判。

手工触发归档和 checkpoint：

```bash
vsql -d postgres -U vbadmin
```

```sql
select pg_xlogfile_name(pg_switch_xlog());
checkpoint;
\q
```

观察恢复过程：

```bash
tail -n 50 /vastbase/log/wal_archive.log

echo -n ".ready = "
find /vastbase/data/pg_xlog/archive_status -maxdepth 1 -name '*.ready' | wc -l

echo -n ".done  = "
find /vastbase/data/pg_xlog/archive_status -maxdepth 1 -name '*.done' | wc -l

du -sh /vastbase/data/pg_xlog /vastbase/arch
```

正常恢复现象：

```text
[2026-06-15 15:05:19] OK 0000000100000003000000A9
[2026-06-15 15:05:20] OK 0000000100000003000000AA
...
.ready = 0
.done  = 20
/vastbase/data/pg_xlog  从 27G 降到 4.3G
/vastbase/arch          增长到 27G
```

解释：`/vastbase/arch` 增长是正常的，说明历史积压 WAL 已经补归档；`pg_xlog` 下降说明数据库已开始回收本地 WAL。归档追平后再执行一次：

```sql
checkpoint;
```

再复核：

```bash
find /vastbase/data/pg_xlog/archive_status -name '*.ready' | wc -l
find /vastbase/data/pg_xlog/archive_status -name '*.done'  | wc -l
du -sh /vastbase/data/pg_xlog /vastbase/arch
```

**七、生产环境处置原则**

生产环境不能直接清空 `/vastbase/arch`，必须先确认备份链路和 PITR 需求：

1. 确认最近一次可用物理全量备份及其 `start_wal`；
2. 确认从最旧保留全量备份开始之后的 WAL 已连续保存；
3. 确认归档目录是否被多个实例、重建实例、PITR 演练实例共用；
4. 对同名 md5 冲突文件，优先隔离到带时间戳的证据目录，不要覆盖；
5. 归档恢复后做一次 `pg_switch_xlog()` + `checkpoint` + `archive_check.sh` 验收；
6. 若曾隔离、重建或清空归档目录，必须立即重做一次物理全量备份，并把新全量备份起点之后的 WAL 作为新的 PITR 链；
7. PITR 能力必须通过恢复演练验证，而不是只看归档文件存在。

生产推荐目录隔离：

```text
/vastbase/data                      数据目录
/vastbase/arch/vbdb01/              当前生产实例 WAL 归档目录
/vastbase/backup                    物理/逻辑备份目录
/archive/vastbase/prod-vbdb01/      异地或独立归档副本
/archive/vastbase/test-vbdb01/      测试实例归档，不与生产混用
/archive/vastbase/pitr-drill-vbdb01/ PITR 演练归档，不与生产混用
```

生产推荐参数：

```bash
su - vastbase

vb_guc set -D $PGDATA -c "wal_level = hot_standby"
vb_guc set -D $PGDATA -c "archive_mode = on"
vb_guc set -D $PGDATA -c "archive_timeout = 300"
vb_guc set -D $PGDATA -c "archive_command = '/vastbase/scripts/archive_wal.sh %p %f'"
vb_guc set -D $PGDATA -c "wal_keep_segments = 16"
```

`wal_level`、`archive_mode` 等 `postmaster` 级参数需要重启：

```bash
vb_ctl restart -D $PGDATA -m fast
# 或 systemd 托管时由 root 执行：systemctl restart vastbase
```

**八、归档容量估算与告警**

现场案例：约 1690 个 16MB WAL 段，约 27GB；从 2026-06-08 到 2026-06-15，平均约 4GB/天。生产归档盘应按实际 WAL 生成速率估算：

```text
归档盘容量 >= 日均 WAL 量 × 保留天数 × 1.5
```

示例：日均 20GB，保留 14 天：

```text
20GB × 14 × 1.5 = 420GB
```

建议告警：

| 指标 | WARN | CRIT | 说明 |
|------|------|------|------|
| `archive_status/*.ready` | `>=3` | `>=10` | 每 5 分钟巡检一次；持续堆积即归档失败/滞后 |
| `/vastbase/arch` 使用率 | `>=70%` | `>=85%` | 归档盘需早于数据盘告警 |
| `/vastbase/data/pg_xlog` 异常增长 | 超过日常基线 2 倍 | 接近数据盘 80% | 优先查 `.ready`、归档日志、复制槽 |
| `wal_archive.log` 失败 | 出现 `FAIL` | 连续失败 | 重点看 `exists with different md5`、权限、空间、网络 |

> `enable_xlog_prune` 只作为磁盘保命阀纳入告警/容量评审，不作为归档替代。确需启用时必须同时设置现实阈值 `max_size_for_xlog_prune`（可按数据盘或归档盘可承受空间的 1/4～1/3 起步评审），并把前提写入告警 runbook：只有归档健康、`.ready` 不堆积时才允许依赖该兜底；归档失败期间禁止用 prune 解决空间问题。

**九、测试环境归档清理**

测试环境若不需要 PITR，且 `.ready=0`、归档链路已恢复，可清理 `/vastbase/arch`，但仍禁止删除 `pg_xlog`：

```bash
# 确认没有待归档 WAL
find /vastbase/data/pg_xlog/archive_status -name '*.ready' | wc -l

# 测试环境按时间清理归档目录；比 rm -f /vastbase/arch/000000* 更稳，能覆盖 .history/.backup 等文件，
# 也避免 timeline 或文件名前缀变化导致遗漏。示例：仅保留最近 1 天。
find /vastbase/arch -maxdepth 1 -type f -mtime +1 -print -delete

du -sh /vastbase/arch
```

生产环境严禁照搬上述测试清理方式，必须使用 §17.5 的 `wal_cleanup.sh`，并以物理备份起点 WAL 为边界。若前面执行过隔离旧 `/vastbase/arch` 并重建空归档目录，必须先清退或移走已经与新归档链不连续的旧 basebackup，再启用 `wal_cleanup.sh`，避免脚本以失效备份的 `start_wal` 作为边界。

**十、排障一键采集脚本**

建议落地 `/vastbase/scripts/wal_archive_bloat_check.sh`，用于归档异常时快速收集证据。

```bash
#!/bin/bash
# wal_archive_bloat_check.sh —— pg_xlog 膨胀/归档失败证据采集
set -uo pipefail
PGDATA=${PGDATA:-/vastbase/data}
ARCH=${ARCH:-/vastbase/arch}
LOG=${LOG:-/vastbase/log/wal_archive.log}
OUT=${1:-/vastbase/log/wal_archive_bloat_check_$(date +%F_%H%M%S).log}

{
  echo "time=$(date '+%F %T')"
  echo "PGDATA=$PGDATA"
  echo "ARCH=$ARCH"
  echo

  echo "==== disk ===="
  df -h "$PGDATA" "$ARCH" 2>/dev/null || true
  du -sh "$PGDATA/pg_xlog" "$ARCH" 2>/dev/null || true
  echo

  echo "==== wal files ===="
  find "$PGDATA/pg_xlog" -maxdepth 1 -type f -regextype posix-extended \
    -regex '.*/[0-9A-F]{24}$' 2>/dev/null | wc -l
  echo

  echo "==== archive_status ===="
  echo -n ".ready = "
  find "$PGDATA/pg_xlog/archive_status" -maxdepth 1 -name '*.ready' -type f 2>/dev/null | wc -l
  echo -n ".done  = "
  find "$PGDATA/pg_xlog/archive_status" -maxdepth 1 -name '*.done' -type f 2>/dev/null | wc -l
  echo

  echo "==== oldest wal ===="
  find "$PGDATA/pg_xlog" -maxdepth 1 -type f -regextype posix-extended \
    -regex '.*/[0-9A-F]{24}$' \
    -printf '%TY-%Tm-%Td %TH:%TM:%TS %s %f\n' 2>/dev/null | sort | head -20
  echo

  echo "==== newest wal ===="
  find "$PGDATA/pg_xlog" -maxdepth 1 -type f -regextype posix-extended \
    -regex '.*/[0-9A-F]{24}$' \
    -printf '%TY-%Tm-%Td %TH:%TM:%TS %s %f\n' 2>/dev/null | sort | tail -20
  echo

  echo "==== wal by day ===="
  find "$PGDATA/pg_xlog" -maxdepth 1 -type f -regextype posix-extended \
    -regex '.*/[0-9A-F]{24}$' \
    -printf '%TY-%Tm-%Td\n' 2>/dev/null | sort | uniq -c
  echo

  echo "==== archive log tail ===="
  tail -n 100 "$LOG" 2>/dev/null || true
  echo

  echo "==== archive errors ===="
  grep -RniE "archive command failed|could not be archived|too many failures|exists with different md5|permission|denied|no space|cannot|could not|FAIL" \
    "$LOG" "$PGDATA/pg_log" /vastbase/log/pg_log 2>/dev/null | tail -100 || true
} | tee "$OUT"
```

落地与验收：

```bash
chmod 750 /vastbase/scripts/wal_archive_bloat_check.sh
bash -n /vastbase/scripts/wal_archive_bloat_check.sh
/vastbase/scripts/wal_archive_bloat_check.sh
```

**十一、最终验收标准**

| 检查项 | 通过标准 |
|--------|----------|
| `wal_archive.log` | 最近切换 WAL 有 `OK <wal>`，无连续 `FAIL` |
| `.ready` | `0` 或仅切换瞬间个位数，不能持续增长 |
| `.done` | 会随归档成功增加；长期数量受内核清理影响，不作为唯一指标 |
| `pg_xlog` | 从异常峰值回落到稳定基线；允许保留几 GB，受 checkpoint/WAL 保留参数影响 |
| `/vastbase/arch` | 容量增长符合 WAL 生成速率，受清理策略控制 |
| `checkpoint` | 执行后无错误，`pg_xlog` 可进一步回收或保持稳定 |
| PITR | 生产必须完成一次“物理备份 + WAL 归档 + 指定时间点恢复”演练 |


### 17.3 物理全量备份脚本

> **WAL 方式：本版 `vb_basebackup`（openGauss 9.2.4 内核）不支持 tar 格式 + `-X stream` 组合**（实测报 `wal streaming can only be used in plain mode`；tar+stream 是 PG10+ 才有的能力）。因此压缩 tar 备份必须用 **`-X fetch`**：所需 WAL 在备份结束时从服务器 `pg_xlog` 收取并写入 `base.tar` 内部（pre-10 服务器放在 tar 里的 `pg_xlog/` 下），**不会**另外生成 `pg_wal.tar.gz`。
> - fetch 在备份结束时一次性取 WAL，不像 stream 边备份边流式拉取，因此**必须保证备份窗口内 backup_start 之后的 WAL 不被回收**：`wal_keep_segments` 要足够大（按备份时长 × WAL 生成速率估算），否则大库 + 高写入时起点 WAL 可能被 checkpoint 回收导致备份不可用。
> - fetch 只用一条普通连接（不占 walsender），所以不像 stream 那样与主备复制争抢 `max_wal_senders`；若仅为本机物理备份，`max_wal_senders` 无额外要求（主备复制本身的需求另算）。
> - 若现场需要 stream 的“无需 wal_keep_segments”特性，只能改用 **plain 格式**（`-F p -X stream`）产出目录树，但那会改变本脚本的 tar.gz 产物与 §17.4 解包逻辑，需整体改造——本文默认采用 tar + fetch。

`vb_basebackup -F t -z` 生成 tar 压缩格式时，`backup_label` 通常在 `base.tar.gz` 内部而不是备份目录根路径下。下面脚本兼容 tar/plain 两种备份格式，能正确抽取备份起点 WAL，便于后续归档清理和 PITR 校验。

> **关键：openGauss tar 格式包不能用 GNU `tar` 解。** `vb_basebackup -F t` 产出的 `base.tar(.gz)`、`<oid>.tar(.gz)` 是 openGauss 私有 tar 封装，必须用 **`gs_tar`/`vb_tar`** 解，且该工具**不自带 gzip**——直接喂 `.tar.gz` 会报 `could not parse file size`，用 GNU `tar -xzf` 则报 `does not look like a tar archive`。正确流程是**先 `gunzip` 去 `.gz` 层，再 `gs_tar -D <目标目录> -F <.tar>`**。本文 `backup.env` 已封装为 `vb_untar_gz <包> <目标目录>`，§17.3 `extract_backup_label` 与 §17.4 解包均经它处理。手工核对一个备份是否可恢复：
> ```bash
> source /vastbase/scripts/backup.env
> rm -rf /tmp/bbverify && vb_untar_gz /vastbase/backup/base/<TS>/base.tar.gz /tmp/bbverify
> cat /tmp/bbverify/backup_label                       # 应有 START WAL LOCATION ... (file <24hex>)
> ls  /tmp/bbverify/pg_xlog/ | grep -E '^[0-9A-F]{24}$' # fetch 收进来的起点 WAL 段
> ```
> 注：解包时 `gs_tar` 可能对双写文件 `global/pg_dw.build` 报 `could not open ... Invalid argument`，该文件实例启动时自动重建，属**良性**，`vb_untar_gz` 已将其视为成功（仍以 `PG_VERSION`/`global` 等是否解出为准）。

```bash
#!/bin/bash
#==============================================================================
# db_basebackup.sh —— VastBase 物理全量备份 + 异地原子同步
#==============================================================================
set -uo pipefail
source /vastbase/scripts/backup.env

require_cmds VB_SQL VB_BASEBACKUP VB_TAR || { echo "required tools missing" >&2; exit 2; }

TS=$(date +%F_%H%M%S)
BASE_ROOT=/vastbase/backup/base
BASE_DIR="${BASE_ROOT}/${TS}"
LOG="${LOG_DIR}/basebackup_${TS}.log"
LOCK=/tmp/vastbase_basebackup.lock
RETENTION_DAYS=21
FAILED=0

mkdir -p "$BASE_DIR" "$LOG_DIR"
exec 220>"$LOCK"
flock -n 220 || { echo "another basebackup running"; exit 1; }

say() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
die() { say "ERROR: $*"; exit 2; }

extract_backup_label() {
    # plain 格式：backup_label 直接在目录根；tar 格式（openGauss）须 gunzip + gs_tar 解到临时目录再读，
    # 不能用 GNU tar -xOf（openGauss tar 格式 GNU tar 解不了）。
    local dir="$1"
    if [[ -f "$dir/backup_label" ]]; then
        cat "$dir/backup_label"; return 0
    fi
    local src=""
    [[ -f "$dir/base.tar.gz" ]] && src="$dir/base.tar.gz"
    [[ -z "$src" && -f "$dir/base.tar" ]] && src="$dir/base.tar"
    [[ -n "$src" ]] || return 0
    local tmpx; tmpx=$(mktemp -d "${TMPDIR:-/tmp}/vblabel.XXXXXX") || return 0
    if vb_untar_gz "$src" "$tmpx" >/dev/null 2>&1 && [[ -f "$tmpx/backup_label" ]]; then
        cat "$tmpx/backup_label"
    fi
    rm -rf "$tmpx"
}

say "===== Basebackup START dir=$BASE_DIR ====="
INREC=$(vb_sql postgres -At -c "SELECT pg_is_in_recovery();" 2>>"$LOG" || echo "?")
[[ "$INREC" == "f" ]] || die "basebackup should run against primary; pg_is_in_recovery()=$INREC"

T0=$(date +%s)
# 本版内核不支持 tar+stream，用 -X fetch（WAL 收进 base.tar 内的 pg_xlog/）；需 wal_keep_segments 足够，见 §17.3 引言。
if vb_basebackup_run \
        -D "$BASE_DIR" -F t -z -P -X fetch --label "base_${TS}" >>"$LOG" 2>&1; then
    T1=$(date +%s)
    say "basebackup OK duration=$((T1-T0))s"
else
    die "basebackup failed"
fi

# 起点 WAL：优先从 gs_basebackup 日志的起始 LSN 经 pg_xlogfile_name 求文件名（最省，不解 60M 包；
# 备份期间库在线，pg_xlogfile_name 知道当前时间线）。失败再退化为解 base 包读 backup_label。
START_WAL=""
START_LSN=$(grep -oiE 'starting position of the xlog copy[^0-9]*:[[:space:]]*[0-9A-F]+/[0-9A-F]+' "$LOG" 2>/dev/null \
            | grep -oiE '[0-9A-F]+/[0-9A-F]+' | head -1)
if [[ -n "$START_LSN" ]]; then
    START_WAL=$(vb_sql postgres -At -c "SELECT pg_xlogfile_name('${START_LSN}')" 2>>"$LOG" | tr -d '[:space:]')
fi
if [[ -z "$START_WAL" ]]; then
    LABEL_TEXT=$(extract_backup_label "$BASE_DIR")
    START_WAL=$(printf '%s\n' "$LABEL_TEXT" | grep -Eo 'file [0-9A-F]{24}' | awk '{print $2}' | head -1)
fi

{
  echo "label     : base_${TS}"
  echo "host      : $(hostname)"
  echo "created   : $TS"
  echo "duration  : $((T1-T0))s"
  echo "format    : tar.gz"
  echo "start_wal : ${START_WAL:-unknown}"
  echo "version   : $(vb_sql postgres -At -c 'SELECT version();' 2>/dev/null)"
  echo "size      : $(du -sb "$BASE_DIR" | awk '{print $1}')"
} > "${BASE_DIR}/MANIFEST.txt"
# ★ v1.42：进目录用相对路径生成，避免写死绝对路径（异地/新机搬走后仍可 `cd <dir> && sha256sum -c SHA256SUMS`）；
#   顺带 ! -name SHA256SUMS 排除自身，免去"边写边被 find 收录"的自引用。
( cd "$BASE_DIR" && find . -type f ! -name SHA256SUMS -exec sha256sum {} \; > SHA256SUMS )
touch "${BASE_DIR}/BASEBACKUP.OK"

# 异地同步，先 partial 后发布
REMOTE_TMP="${REMOTE_DIR}/base/${TS}.partial"
REMOTE_FINAL="${REMOTE_DIR}/base/${TS}"
say "rsync to remote ${REMOTE_HOST}:${REMOTE_TMP}"
if ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf '${REMOTE_TMP}'; mkdir -p '${REMOTE_TMP}'" >>"$LOG" 2>&1 \
   && rsync_sys -avz --partial-dir=.rsync-partial --delay-updates \
        --bwlimit="${RSYNC_BWLIMIT:-0}" -e "env -u LD_LIBRARY_PATH ssh $SSH_OPTS" \
        "${BASE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP}/" >>"$LOG" 2>&1 \
   && ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
        "test -f '${REMOTE_TMP}/BASEBACKUP.OK' && rm -rf '${REMOTE_FINAL}' && mv '${REMOTE_TMP}' '${REMOTE_FINAL}'" >>"$LOG" 2>&1; then
    say "remote basebackup publish OK"
else
    say "remote basebackup publish FAIL"
    FAILED=$((FAILED+1))
fi

say "cleanup local basebackups older than $RETENTION_DAYS d"
find "$BASE_ROOT" -maxdepth 1 -type d -name '20*' -mtime +"$RETENTION_DAYS" -print -exec rm -rf {} \; >>"$LOG" 2>&1 || true

say "===== Basebackup END failed=$FAILED ====="
exit $FAILED
```

加进 crontab（每周日凌晨 1:00，与日常逻辑备份 02:00 错开）：

```cron
0 1 * * 0  /vastbase/scripts/db_basebackup.sh >> /vastbase/log/backup/basebackup_cron.log 2>&1
```

> 同样经 `vb_sql`/`vb_basebackup_run` 注入口令、`ssh_sys`/`rsync_sys` 处理网络命令。`vb_basebackup_run` 已内置 `--pipeline` 探测并自动降级，无需手工改脚本；但仍需确认 `vbadmin` 具备 REPLICATION 权限且 `pg_hba.conf` 放行其 `replication` 连接。下面这条只用于确认本版走哪条注入路径（输出"降级"属正常，封装会自动处理）：
>
> ```bash
> source /vastbase/scripts/backup.env
> "$VB_BASEBACKUP" --help | grep -- '--pipeline' || echo "本版 vb_basebackup 无 --pipeline，vb_basebackup_run 自动降级为子 shell PGPASSWORD"
> ```

### 17.4 PITR 恢复脚本

> ⚠️ 该流程会**完全销毁现有 `$PGDATA`**，仅用于：(1) 同机灾难恢复、(2) 异机 DR 演练。执行前必须把现场 `$PGDATA` 做完整快照保护。

root账户下先将vastbase设置为sudo账户

```bash
su - root

echo 'vastbase ALL=(root) NOPASSWD: /usr/bin/systemctl stop vastbase.service, /usr/bin/systemctl start vastbase.service, /usr/bin/systemctl is-active vastbase.service' | sudo tee /etc/sudoers.d/vastbase-pitr
```



`/vastbase/scripts/pitr_restore.sh`：

```bash
#!/bin/bash
#==============================================================================
# pitr_restore.sh —— 物理基础备份 + WAL 归档 -> 指定时间点恢复
#
# 用法:  ./pitr_restore.sh -b <basebackup_dir> -t '2026-05-25 10:29:00+08'
#        ./pitr_restore.sh -b <basebackup_dir> -x <recovery_target_xid>
#==============================================================================
set -uo pipefail
source /vastbase/scripts/backup.env
require_cmds VB_SQL VB_CTL VB_TAR || { echo "required tools (VB_SQL/VB_CTL/VB_TAR) missing" >&2; exit 2; }

BASE_DIR=""; TARGET_TIME=""; TARGET_XID=""; ARCH_SRC="/vastbase/arch"
FORCE=0

usage() {
cat <<EOF
Usage: $0 -b <basebackup_dir> [-t <target_time> | -x <target_xid>] [-A <arch_dir>] [-F]
  -b   物理基础备份目录（含 base.tar.gz / backup_label）
  -t   恢复目标时间，例如  '2026-05-25 10:29:00+08'
  -x   恢复目标事务号（与 -t 二选一）
  -A   归档源目录（默认 /vastbase/arch）
  -F   force, 跳过交互确认
EOF
exit 1
}

while getopts "b:t:x:A:Fh" opt; do
    case $opt in
        b) BASE_DIR="$OPTARG" ;;
        t) TARGET_TIME="$OPTARG" ;;
        x) TARGET_XID="$OPTARG" ;;
        A) ARCH_SRC="$OPTARG" ;;
        F) FORCE=1 ;;
        *) usage ;;
    esac
done
[[ -z "$BASE_DIR" || ( -z "$TARGET_TIME" && -z "$TARGET_XID" ) ]] && usage
# -b 允许只给备份目录名（自动补成 $BACKUP_DIR/base/<name>），也允许给绝对路径。
[[ "$BASE_DIR" != /* ]] && BASE_DIR="$BACKUP_DIR/base/$BASE_DIR"
[[ ! -f "$BASE_DIR/BASEBACKUP.OK" ]] && { echo "basebackup not OK: 缺 $BASE_DIR/BASEBACKUP.OK（请确认 -b 指向有效备份目录）"; exit 1; }

LOG="${LOG_DIR}/pitr_$(date +%F_%H%M%S).log"
say() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
# 关键：本脚本大量用 `... || die "..."` 做“失败即停”的护栏，但此前从未定义 die，backup.env
# 也不提供（die 仅在 db_backup.sh/db_restore.sh/db_basebackup.sh 各自定义）。因脚本是
# `set -uo pipefail`（无 set -e），未定义的 die 只会打印 "die: command not found" 并继续——
# 所有护栏失效，解包/哨兵失败后脚本仍会在已销毁 PGDATA 的情况下硬冲到表空间循环才停。
# 必须在此补回 die，恢复 fail-fast 语义。
die() { say "ERROR: $*"; exit 2; }

# ---- 0. 确认 ----
say "BASE_DIR    = $BASE_DIR"
say "TARGET_TIME = ${TARGET_TIME:-(none)}"
say "TARGET_XID  = ${TARGET_XID:-(none)}"
say "ARCH_SRC    = $ARCH_SRC"
say "PGDATA      = $PGDATA  (将被销毁!)"
if [[ $FORCE -eq 0 ]]; then
    read -r -p "请输入 PITR-GO 确认: " ans
    [[ "$ans" == "PITR-GO" ]] || { say "abort"; exit 0; }
fi

# ---- 1. 停库 + 确认不会被自动拉起 ----
# 致命陷阱：若实例由 systemd 托管且配了 Restart=on-failure（典型 vastbase.service），用 vb_ctl stop
# 直接停 postmaster 会【绕过 systemd】，systemd 视其为异常退出并立刻 ExecStart=vb_ctl start 反拉，
# 在刚清空的 PGDATA 留下 pg_ctl.lock（卡死 gs_tar 的“目录非空”校验），甚至在半恢复目录上普通启动、
# 绕过 recovery.conf 使 PITR 静默失效。
# 处理策略：先识别托管本 PGDATA 的 systemd unit。
#   A（自动）：若能“免切 root”控制 systemd（脚本以 root 跑，或 vastbase 配了免密 sudo systemctl），
#              且 PITR_SYSTEMD_AUTO=1（默认），则恢复前自动 `systemctl stop`（主动停止不触发 Restart），
#              恢复验收后自动 `systemctl start` 交还——全程无需人工切 root。
#   B（降级）：无上述能力时，在【销毁数据前】早停并给出 root 手工 stop/mask→恢复→交还的指引。
# is-active 是只读查询、无需 root；只有 stop/start 需要权限。PITR_SYSTEMD_UNIT 可显式指定、=none 跳过。
SYSTEMD_UNIT="${PITR_SYSTEMD_UNIT:-}"
[[ "$SYSTEMD_UNIT" == "none" ]] && SYSTEMD_UNIT="__SKIP__"   # 显式跳过 systemd 探测
if [[ -z "$SYSTEMD_UNIT" ]] && command -v systemctl >/dev/null 2>&1; then
    while read -r u; do
        [[ -n "$u" ]] || continue
        systemctl cat "$u" 2>/dev/null | grep -Eq -- "-D[[:space:]]+${PGDATA}([[:space:]]|$)" \
            && { SYSTEMD_UNIT="$u"; break; }
    done < <(systemctl list-unit-files --type=service --no-legend 2>/dev/null \
             | awk '{print $1}' | grep -iE 'vastbase|gauss|opengauss')
fi

# 探测可用的 systemd 控制方式（A 模式）；探测不到则 SYSTEMCTL 为空、走 B。
SYSTEMCTL=""; SYSTEMD_DID_STOP=0
PITR_SYSTEMD_AUTO="${PITR_SYSTEMD_AUTO:-1}"
if [[ -n "$SYSTEMD_UNIT" && "$SYSTEMD_UNIT" != "__SKIP__" && "$PITR_SYSTEMD_AUTO" == "1" ]]; then
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        SYSTEMCTL="systemctl"
    elif command -v sudo >/dev/null 2>&1; then
        # 用合法状态词判定免密 sudo 是否通过（is-active 在 inactive 时返回非0属正常，不能只看 rc）。
        probe=$(sudo -n systemctl is-active "$SYSTEMD_UNIT" 2>&1 || true)
        [[ "$probe" =~ ^(active|inactive|failed|activating|deactivating|reloading|unknown)$ ]] \
            && SYSTEMCTL="sudo -n systemctl"
    fi
fi

if [[ -n "$SYSTEMD_UNIT" && "$SYSTEMD_UNIT" != "__SKIP__" ]]; then
    state=$(systemctl is-active "$SYSTEMD_UNIT" 2>/dev/null || true)
    if [[ "$state" == "active" || "$state" == "activating" || "$state" == "reloading" ]]; then
        if [[ -n "$SYSTEMCTL" ]]; then
            # A：自动优雅停止（systemctl stop 是主动停止，不触发 Restart=on-failure），记录待交还
            say "systemd unit '$SYSTEMD_UNIT' 当前 $state；自动经 '$SYSTEMCTL stop' 优雅停止（验收后将自动交还）"
            $SYSTEMCTL stop "$SYSTEMD_UNIT" >>"$LOG" 2>&1 \
                || die "自动 '$SYSTEMCTL stop $SYSTEMD_UNIT' 失败；请手工 'systemctl stop $SYSTEMD_UNIT' 后重跑，或设 PITR_SYSTEMD_AUTO=0 走手工流程。"
            SYSTEMD_DID_STOP=1
            for _i in 1 2 3 4 5 6; do
                [[ "$(systemctl is-active "$SYSTEMD_UNIT" 2>/dev/null || true)" != "active" ]] && break
                sleep 2
            done
            [[ "$(systemctl is-active "$SYSTEMD_UNIT" 2>/dev/null || true)" == "active" ]] \
                && die "'$SYSTEMCTL stop' 后 $SYSTEMD_UNIT 仍 active，放弃（$PGDATA 未动）。"
            say "systemd unit '$SYSTEMD_UNIT' 已停止，继续。"
        else
            # B：无 root/免密 sudo（或 PITR_SYSTEMD_AUTO=0）。数据完好时早停并给手工指引。
            die "本实例由 systemd unit '$SYSTEMD_UNIT' 托管（当前 $state），且未检测到可免切 root 的 systemd 控制能力。二选一后重跑：
     (A 推荐, 全自动) 给 vastbase 配免密 sudo（仅放行该 unit 的 systemctl stop/start/is-active），例：
         echo 'vastbase ALL=(root) NOPASSWD: /usr/bin/systemctl stop $SYSTEMD_UNIT, /usr/bin/systemctl start $SYSTEMD_UNIT, /usr/bin/systemctl is-active $SYSTEMD_UNIT' | sudo tee /etc/sudoers.d/vastbase-pitr
       配好后脚本自动停库/交还，无需人工切 root。
     (B, 手工) 以 root 先停并临时屏蔽： systemctl stop $SYSTEMD_UNIT && systemctl mask $SYSTEMD_UNIT
       （验收后： vb_ctl stop -D $PGDATA; systemctl unmask $SYSTEMD_UNIT; systemctl start $SYSTEMD_UNIT ）
     当前 $PGDATA 未被破坏，可安全重试。确知本机无 systemd 自动拉起可用 PITR_SYSTEMD_UNIT=none 跳过。"
        fi
    else
        say "systemd unit '$SYSTEMD_UNIT' 状态=$state（非 active，继续）"
        # 注意：若运维已手工 stop+mask（B 路径），SYSTEMD_DID_STOP 保持 0，脚本不自动交还，按手工流程恢复。
    fi
fi

say "stopping instance ..."
${VB_CTL:-vb_ctl} stop -D "$PGDATA" -m fast >>"$LOG" 2>&1 || true

# 若设置了停监控命令（如 'gs_om -t stop'、或临时停用其它自动拉起来源），先执行。
# 恢复完成后用 PITR_START_MONITOR_CMD 复原（见脚本末尾提示）。
if [[ -n "${PITR_STOP_MONITOR_CMD:-}" ]]; then
    say "stopping monitor via PITR_STOP_MONITOR_CMD ..."
    eval "$PITR_STOP_MONITOR_CMD" >>"$LOG" 2>&1 || say "WARN: stop-monitor 命令返回非零，继续探测"
fi

# 兜底安全闸：确认实例【确实没在运行】，而非仅凭 postmaster.pid 文件存在——该文件可能是上次非正常
# 退出/强杀后残留的过期文件（旧版据“文件存在”即判定被拉起，会对过期 pid 误报）。权威判据：
# postmaster.pid 第一行的 PID 是否为【存活且 cmdline 含 gaussdb】的进程；并兼顾 om_monitor 等外部来源。
sleep 8
INST_RUNNING=0
if [[ -f "$PGDATA/postmaster.pid" ]]; then
    PMPID=$(head -1 "$PGDATA/postmaster.pid" 2>/dev/null)
    if [[ "$PMPID" =~ ^[0-9]+$ ]] && kill -0 "$PMPID" 2>/dev/null \
       && tr '\0' ' ' < "/proc/$PMPID/cmdline" 2>/dev/null | grep -q 'gaussdb'; then
        INST_RUNNING=1
    fi
fi
if [[ $INST_RUNNING -eq 1 ]] || pgrep -af 'om_monitor' >/dev/null 2>&1; then
    die "实例在停库后仍在运行 / 被自动拉起（postmaster.pid 指向存活 gaussdb，或检测到 om_monitor）。PITR 期间必须保持停止：
     cluster 安装用 'gs_om -t stop'；systemd 用 'systemctl stop && systemctl mask'；自建 monitor.sh 临时停用；
     或用 PITR_STOP_MONITOR_CMD='<停止命令>' 重跑本脚本。当前 $PGDATA 未被破坏，可安全重试。"
fi
# 走到这里实例确已停止；$PGDATA 里若有过期 postmaster.pid 无妨——下一步会把整目录移到 $SAVE。
[[ -f "$PGDATA/postmaster.pid" ]] && say "注意：检测到过期 postmaster.pid（进程已不存在），将随整目录移走，不影响恢复。"

# ---- 2. 保护现场 ----
SAVE="$PGDATA.crashed.$(date +%F_%H%M%S)"
say "moving current PGDATA -> $SAVE"
mv "$PGDATA" "$SAVE"

# ---- 3. 解包基础备份 ----
# openGauss tar 格式：必须 gunzip + gs_tar/vb_tar 解（GNU tar 解不了）；vb_untar_gz 已封装该流程。
# 注意 gs_tar 要求【目标目录为空】，否则报 `destination dir "..." no empty.` 拒绝解包。直接解到
# $PGDATA 时，监控/自动拉起进程可能在 mkdir 与 gs_tar 之间往里写 pg_ctl.lock 致其“非空”而失败。
# 故解到独立 staging 目录（同文件系统，保证后续 mv 为原子 rename），校验通过后再整体换入 $PGDATA。
STAGE="${PGDATA}.restore.$(date +%F_%H%M%S)"
rm -rf "$STAGE"
say "extracting basebackup (gunzip + ${VB_TAR##*/}) -> $STAGE ..."
vb_untar_gz "$BASE_DIR/base.tar.gz" "$STAGE" >>"$LOG" 2>&1 || die "extract base.tar.gz failed (see $LOG)"
# 解包成功哨兵校验：openGauss 双写文件 pg_dw.build 的良性告警不阻断，但 PG_VERSION/global 必须就位。
[[ -f "$STAGE/PG_VERSION" && -d "$STAGE/global" ]] || die "extracted basebackup looks incomplete (missing PG_VERSION/global in $STAGE)"
# 换入到位：先清掉可能被监控进程重建的空 $PGDATA，再原子 rename staging。
rm -rf "$PGDATA"
mv "$STAGE" "$PGDATA"
chmod 700 "$PGDATA"

# 本版以 -F t -z -X fetch 备份：所需 WAL 已收进 base.tar.gz 内部的 pg_xlog/，上一步解包时
# 已随之落到 $PGDATA/pg_xlog/，无需单独解 WAL 包，也不会有 pg_wal.tar.gz。
# 下面分支仅作防御：兼容 (a) 未来支持 tar+stream 的版本产出的 pg_wal.tar.gz / pg_xlog.tar.gz，
# 或 (b) 改用 plain+stream 时手工打包的 WAL 包。命中才解，未命中跳过即可。
for WAL_TAR in "$BASE_DIR/pg_wal.tar.gz" "$BASE_DIR/pg_xlog.tar.gz"; do
    [[ -f "$WAL_TAR" ]] || continue
    # pg_wal 包解到 pg_wal/，pg_xlog 包解到 pg_xlog/，与服务器内核命名一致。
    if [[ "$(basename "$WAL_TAR")" == pg_wal.tar.gz ]]; then WAL_SUBDIR=pg_wal; else WAL_SUBDIR=pg_xlog; fi
    say "extracting WAL package $(basename "$WAL_TAR") -> $WAL_SUBDIR ..."
    vb_untar_gz "$WAL_TAR" "$PGDATA/$WAL_SUBDIR" >>"$LOG" 2>&1 || die "extract $(basename "$WAL_TAR") failed"
done

# 解析表空间 OID 对应的原始绝对路径。
# 关键事实（现场实测）：本版 openGauss tar 格式备份【不生成 tablespace_map】；backup_label
# 【任何版本都不含表空间路径映射】（原代码查 backup_label 属错误来源，已删）；且 base 包内的
# pg_tblspc/<oid> 符号链接常被 gs_tar 解包时漏建（与 pg_dw.build Invalid argument 同源——
# openGauss 私有 tar 对特殊文件/软链支持不全）。最可靠来源是【刚被移到 $SAVE 的旧 PGDATA】里的
# pg_tblspc 符号链接（同机恢复必有）；异机 DR 用显式覆盖。
find_tablespace_path() {
    local oid="$1" map path ev
    # (1) 显式覆盖（异机 DR）：TBLSPC_MAP_FILE 每行 "<oid> <绝对路径>"，或环境变量 TBLSPC_<oid>
    if [[ -n "${TBLSPC_MAP_FILE:-}" && -f "$TBLSPC_MAP_FILE" ]]; then
        path=$(awk -v o="$oid" '$1==o{$1="";sub(/^[ \t]+/,"");print;exit}' "$TBLSPC_MAP_FILE")
        [[ -n "$path" ]] && { printf '%s\n' "$path"; return 0; }
    fi
    ev="TBLSPC_${oid}"
    [[ -n "${!ev:-}" ]] && { printf '%s\n' "${!ev}"; return 0; }
    # (2) 同机恢复首选：旧 PGDATA（已移到 $SAVE）的符号链接，readlink 取字面绝对目标（勿用 -f）
    [[ -L "$SAVE/pg_tblspc/$oid" ]]   && { readlink "$SAVE/pg_tblspc/$oid";   return 0; }
    # (3) 新解包出的 PGDATA 符号链接（若 gs_tar 侥幸还原成功）
    [[ -L "$PGDATA/pg_tblspc/$oid" ]] && { readlink "$PGDATA/pg_tblspc/$oid"; return 0; }
    # (4) 极少数确实生成 tablespace_map 的版本兜底
    for map in "$PGDATA/tablespace_map" "$BASE_DIR/tablespace_map"; do
        [[ -f "$map" ]] || continue
        path=$(awk -v o="$oid" '$1==o{$1="";sub(/^[ \t]+/,"");print;exit}' "$map")
        [[ -n "$path" ]] && { printf '%s\n' "$path"; return 0; }
    done
    return 1
}

# 若有自定义表空间，对应 <oid>.tar.gz 必须解到其原始位置。须区分两类，处理方式不同：
#   - 库内（相对位置 RELATIVE LOCATION，路径落在 $PGDATA/pg_location/ 下，如 tbs_app_data/idx）：
#     旧数据已随 PGDATA 整体进 $SAVE，对应目录直接清空重解；【切勿】往这里 mv .crashed，否则会在
#     新 PGDATA 的 pg_location/ 下留垃圾目录，实例启动扫描时可能困惑或报错。
#   - 库外（独立路径，如 /data/tbs/jobs_server）：移 PGDATA 时未触及，活动目录仍是误操作后的旧
#     数据，必须先把现存目录移到同级 .crashed 再解，避免备份内容与旧文件混杂。
mkdir -p "$PGDATA/pg_tblspc"
TS_TBL=$(date +%F_%H%M%S)
for TBL_TAR in "$BASE_DIR"/[0-9]*.tar.gz; do
    [[ -f "$TBL_TAR" ]] || continue
    TBL_OID=$(basename "$TBL_TAR" .tar.gz)
    TBL_PATH=$(find_tablespace_path "$TBL_OID" || true)
    [[ -n "${TBL_PATH:-}" ]] || die "cannot resolve path for tablespace OID=$TBL_OID; 设 TBLSPC_${TBL_OID}=/abs/path 或 TBLSPC_MAP_FILE 后重跑"

    if [[ "$TBL_PATH/" == "$PGDATA"/* ]]; then
        # 库内：旧数据已在 $SAVE，直接清空重解（末尾显式 / 防 /vastbase/database 误判为库内）
        rm -rf "$TBL_PATH"; mkdir -p "$TBL_PATH" && chmod 700 "$TBL_PATH"
        say "  [in-PGDATA] tablespace $TBL_OID -> $TBL_PATH"
    else
        # 库外：先把现存目录移走再解
        [[ -e "$TBL_PATH" ]] && mv "$TBL_PATH" "${TBL_PATH}.crashed.${TS_TBL}"
        mkdir -p "$TBL_PATH" && chmod 700 "$TBL_PATH"
        say "  [external] tablespace $TBL_OID -> $TBL_PATH (旧目录已存为 ${TBL_PATH}.crashed.${TS_TBL})"
    fi

    # 表空间包同为 openGauss tar 格式，须经 gunzip + gs_tar/vb_tar，不能用 GNU tar。
    vb_untar_gz "$TBL_TAR" "$TBL_PATH" >>"$LOG" 2>&1 || die "extract tablespace $TBL_OID failed"
    chown -R vastbase:dbgrp "$TBL_PATH"
    # gs_tar 多半没还原 pg_tblspc/<oid> 软链，强制重建指向恢复后的位置。
    ln -sfn "$TBL_PATH" "$PGDATA/pg_tblspc/$TBL_OID"
done
chown -h vastbase:dbgrp "$PGDATA/pg_tblspc/"* 2>/dev/null || true

chown -R vastbase:dbgrp "$PGDATA"

# ---- 4. 写 recovery 参数 ----
# V3.0.8PSU4 官方 PITR 文档仍以 recovery.conf 为准；部分 PG12+ 派生包走
# postgresql.auto.conf + recovery.signal。脚本支持 auto / legacy / signal 三种模式：
#   PITR_RECOVERY_STYLE=legacy  强制写 recovery.conf
#   PITR_RECOVERY_STYLE=signal  强制写 postgresql.auto.conf 并 touch recovery.signal
#   PITR_RECOVERY_STYLE=auto    自动探测；默认优先兼容 V3.0.8PSU4 官方 legacy 路径
# 说明：auto 模式基于刚解包的 PGDATA 判断，普通主库备份通常会走 legacy。
# 如 promote 启动失败、日志提示 recovery.conf 被忽略或要求 recovery.signal，请改用
# PITR_RECOVERY_STYLE=signal 重跑脚本。
# 重要：recovery_target_action 仅 PG12+ 内核（signal 模式）支持；本版 openGauss 9.2.4 的
# legacy recovery.conf 不认该参数，故仅 signal 分支写它，legacy 分支不写（见各分支内注释）。
write_recovery_settings() {
    local style="${PITR_RECOVERY_STYLE:-auto}"
    local conf_file
    # ARCH_SRC 会在本脚本写配置时展开成固定路径；双引号用于保护含空格路径。
    # 如现场归档侧保留 md5/sha256 清单，可把 restore_command 替换为反向 restore_wal.sh 做完整性校验。

    if [[ "$style" == "auto" ]]; then
        if [[ -f "$PGDATA/recovery.signal" || -f "$PGDATA/standby.signal" ]] || \
           grep -qE '^[#[:space:]]*(restore_command|recovery_target_|primary_conninfo)' \
                    "$PGDATA/postgresql.conf" "$PGDATA/postgresql.auto.conf" 2>/dev/null; then
            style="signal"
        else
            style="legacy"
        fi
    fi

    case "$style" in
        signal)
            conf_file="$PGDATA/postgresql.auto.conf"
            say "writing recovery settings to $conf_file and touching recovery.signal"
            rm -f "$PGDATA/recovery.conf" "$PGDATA/standby.signal"
            cat >> "$conf_file" <<EOF
restore_command = 'test -f "${ARCH_SRC}/%f" && cp "${ARCH_SRC}/%f" "%p"'
recovery_target_action = 'promote'
EOF
            if [[ -n "$TARGET_TIME" ]]; then
                echo "recovery_target_time = '${TARGET_TIME}'" >> "$conf_file"
            elif [[ -n "$TARGET_XID" ]]; then
                echo "recovery_target_xid = '${TARGET_XID}'" >> "$conf_file"
            fi
            echo "recovery_target_inclusive = true" >> "$conf_file"
            touch "$PGDATA/recovery.signal"
            ;;
        legacy)
            conf_file="$PGDATA/recovery.conf"
            say "writing legacy recovery settings to $conf_file"
            rm -f "$PGDATA/recovery.signal" "$PGDATA/standby.signal"
            # 注意：本版 openGauss 9.2.4 内核的 recovery.conf 【不支持 recovery_target_action】
            #（该参数是 PG12+ 才引入）。误写会让 startup 进程 FATAL: unrecognized recovery parameter
            # "recovery_target_action" 而退出、库起不来（v1.23 现场实测即栽于此）。本内核归档恢复到点后、
            # 在无 standby.signal/primary_conninfo 的情况下会自动结束恢复并以读写库开服（recovery.conf
            # 自动转 recovery.done），无需该参数。故 legacy 分支仅写 restore_command + 目标点 + inclusive。
            cat > "$conf_file" <<EOF
restore_command          = 'test -f "${ARCH_SRC}/%f" && cp "${ARCH_SRC}/%f" "%p"'
EOF
            if [[ -n "$TARGET_TIME" ]]; then
                echo "recovery_target_time = '${TARGET_TIME}'" >> "$conf_file"
            elif [[ -n "$TARGET_XID" ]]; then
                echo "recovery_target_xid  = '${TARGET_XID}'" >> "$conf_file"
            fi
            echo "recovery_target_inclusive = true" >> "$conf_file"
            ;;
        *)
            say "ERROR: invalid PITR_RECOVERY_STYLE=$style, expected auto|legacy|signal"
            exit 2
            ;;
    esac
}
write_recovery_settings

# ---- 5. 启动并等待 promote ----
say "starting recovery ..."
${VB_CTL:-vb_ctl} start -D "$PGDATA" -t 600 >>"$LOG" 2>&1 || {
    say "start failed, see $LOG"; exit 2
}

# ---- 6. 等待 recovery 完成 ----
# 本机 vsql 不消费 .pgpass，必须走 backup.env 的 vb_sql 封装（经 -2/--pipeline 由 stdin 注入口令）；
# 直接调 ${VB_SQL:-vsql} 会回退到交互式 "Password for user vbadmin:" 提示，把本循环和下面的校对挂起。
# 注：恢复期间需 postgresql.conf 中 hot_standby=on（wal_level=replica/hot_standby）才允许只读连接探测。
for i in {1..120}; do
    INREC=$(vb_sql postgres -At -c "SELECT pg_is_in_recovery();" 2>/dev/null || echo "?")
    say "  pg_is_in_recovery() = $INREC  (try $i)"
    [[ "$INREC" == "f" ]] && break
    sleep 5
done

# ---- 7. 校对 ----
NOW=$(vb_sql postgres -At \
      -c "SELECT now(), txid_current(), pg_last_xact_replay_timestamp();" 2>/dev/null)
say "recovered. server reports: $NOW"

# 若第 1 步停了监控，校验无误后再恢复自动拉起（避免恢复期间被并发拉起）。
if [[ -n "${PITR_START_MONITOR_CMD:-}" ]]; then
    say "restoring monitor via PITR_START_MONITOR_CMD ..."
    eval "$PITR_START_MONITOR_CMD" >>"$LOG" 2>&1 || say "WARN: start-monitor 命令返回非零，请手工确认监控已恢复"
elif [[ -n "${PITR_STOP_MONITOR_CMD:-}" ]]; then
    say "提醒：第 1 步曾用 PITR_STOP_MONITOR_CMD 停过监控，请手工恢复自动拉起（或设 PITR_START_MONITOR_CMD 由脚本恢复）。"
fi

# ---- 8. 交还 systemd（A 模式自动）----
# 若第 1 步由脚本自动停过 systemd 托管 unit，则把恢复实例交还 systemd：先停脚本起的恢复实例
#（vb_ctl 起的、不在 systemd 管理下），再 systemctl start（recovery.conf 已转 recovery.done，属正常启动）。
# 这样恢复完即由 systemd 接管运行，无需人工切 root 做交接。
if [[ "${SYSTEMD_DID_STOP:-0}" -eq 1 && -n "${SYSTEMCTL:-}" ]]; then
    say "handing back to systemd: 停恢复实例后 '$SYSTEMCTL start $SYSTEMD_UNIT'"
    ${VB_CTL:-vb_ctl} stop -D "$PGDATA" -m fast >>"$LOG" 2>&1 || true
    if $SYSTEMCTL start "$SYSTEMD_UNIT" >>"$LOG" 2>&1; then
        sleep 3
        say "systemd unit '$SYSTEMD_UNIT' 交还后状态=$(systemctl is-active "$SYSTEMD_UNIT" 2>/dev/null || true)"
    else
        say "WARN: 自动 '$SYSTEMCTL start $SYSTEMD_UNIT' 失败，恢复实例已停；请手工 systemctl start 并检查。"
    fi
fi
say "===== PITR DONE ====="
```

**演练流程速记**：

```bash
# 1) 准备一份"已知良好"的基础备份目录
ls /vastbase/backup/base/

# 2) 找出误操作时间（看 pg_log）
grep -i 'drop table' /vastbase/log/pg_log/*.log | tail

# 3) 恢复到误操作前 1 分钟
/vastbase/scripts/pitr_restore.sh \
    -b /vastbase/backup/base/2026-05-25_010001 \
    -t '2026-05-25 10:28:00+08'

# 4) 验证业务对象（appuser 未配置在 .pgpass/vb_sql 封装中，下面命令会交互提示输入 appuser 口令，
#    手工演练时输入即可；若想免交互，可临时把 appuser 加入 ~/.pgpass 后改用 vb_sql 封装）
$VB_SQL -h 127.0.0.1 -p 5432 -d appdb -U appuser -c "SELECT count(*) FROM app.t_order;"

# 5) 如使用 tbs_app_data/tbs_app_idx 等自定义表空间，必须验证表空间路径与对象可读性
#    vbadmin 已在 .pgpass 中，须走 backup.env 的 vb_sql 封装（先 source backup.env），否则同样会被提示输入口令
source /vastbase/scripts/backup.env
vb_sql appdb -c "SELECT spcname, pg_tablespace_location(oid) FROM pg_tablespace WHERE spcname NOT IN ('pg_default','pg_global');"
# 库内表空间应回 $PGDATA/pg_location/...（tbs_app_data、tbs_app_idx），库外表空间回独立路径
# （如 /data/tbs/jobs_server）；任一为空或路径异常说明该表空间未正确恢复。
```

> V3.0.8PSU4 官方 PITR 文档使用 `recovery.conf`；如果现场补丁包提示 `recovery.conf` 被忽略或要求信号文件，可设置 `PITR_RECOVERY_STYLE=signal` 重跑脚本。首次部署后必须做一次 PITR 演练并归档日志；包含自定义 tablespace 的实例，PITR 验收必须覆盖表空间对象。
>
> **本内核 legacy `recovery.conf` 不支持 `recovery_target_action`**：openGauss 9.2.4 内核遇到该参数会 `FATAL: unrecognized recovery parameter "recovery_target_action"` 而拒绝启动（PG12+ 才支持，仅 signal 模式可用）。现场实测可用的 legacy `recovery.conf` 内容如下，恢复到点后自动结束并以读写库开服（`recovery.conf` 自动转 `recovery.done`）：
>
> ```ini
> restore_command          = 'test -f "/vastbase/arch/%f" && cp "/vastbase/arch/%f" "%p"'
> recovery_target_time = '2026-06-08 12:30:00+08'
> recovery_target_inclusive = true
> ```
>
> **关于 `-t` 目标时间**：必须落在【备份完成之后、误操作之前】的区间，并带时区（如 `+08`）。若把目标时间设成早于备份完成（例如等于备份目录名所示的“起始”时刻），恢复会在到达一致性点前就停在目标处，库无法 promote，日志报 `recovery_target_time ... is before backup end / could not reach consistency`。不确定误操作精确时间时，优先用 `-x <xid>` 指定到误操作前一个事务号。
>
> **systemd 托管实例（如 `vastbase.service`，`Restart=on-failure`）必读**：切勿用 `vb_ctl stop` 停一个 systemd 正在管理的实例——systemd 会把它当异常退出并按 `Restart` 立刻反拉，在恢复刚清空的目录上留 `pg_ctl.lock`（卡死 `gs_tar` 的“目录非空”校验），甚至在半恢复目录上普通启动、绕过 `recovery.conf` 使 PITR 静默失效。脚本第 1 步会自动探测托管本 `$PGDATA` 的 unit 并按下面两种模式处理：
>
> **A（推荐，全自动）**：给 `vastbase` 配一条精准免密 sudo（仅放行该 unit 的 `stop`/`start`/`is-active`），脚本即可在恢复前自动 `systemctl stop`、验收后自动 `systemctl start` 交还，**全程无需人工切 root**：
>
> ```bash
> # 以 root 配置一次（注意确认 systemctl 实际路径，麒麟通常为 /usr/bin/systemctl）
> echo 'vastbase ALL=(root) NOPASSWD: /usr/bin/systemctl stop vastbase.service, /usr/bin/systemctl start vastbase.service, /usr/bin/systemctl is-active vastbase.service' \
>   | sudo tee /etc/sudoers.d/vastbase-pitr && sudo chmod 440 /etc/sudoers.d/vastbase-pitr
> # 之后 vastbase 用户一条命令跑通（停库/恢复/交还全自动）
> ./pitr_restore.sh -b <basebackup_dir> -t '<target_time>+08'
> ```
>
> **B（降级，手工）**：未配免密 sudo（或设 `PITR_SYSTEMD_AUTO=0`）时，脚本会在销毁数据前早停并提示。手工流程：
>
> ```bash
> # ① 恢复前（root）：优雅停 + 临时屏蔽，systemctl stop 是主动停止、不触发 Restart
> systemctl stop vastbase && systemctl mask vastbase
> # ② vastbase 用户跑 PITR（脚本里的 vb_ctl stop 此时为无害空操作）
> ./pitr_restore.sh -b <basebackup_dir> -t '<target_time>+08'
> # ③ 验收无误后（root）：停掉脚本起的恢复实例，解除屏蔽，交还 systemd 正常启动
> #    （promote 后 recovery.conf 已自动转 recovery.done，③ 为正常启动而非再次恢复）
> vb_ctl stop -D /vastbase/data
> systemctl unmask vastbase && systemctl start vastbase
> ```
>
> 说明：A 模式下脚本以 `systemctl stop`（主动停止，不触发 `Restart`）替代裸 `vb_ctl stop`，故无需 `mask`；探测不到免密 sudo（或非 root）则自动降级为 B。`PITR_SYSTEMD_UNIT=<unit>` 显式指定 unit、`=none` 跳过探测。


### 17.5 归档清理策略

只有在“物理备份 + 所需 WAL 已经异地保存并通过恢复演练”后，才能清理旧归档。严禁单纯按 `mtime` 删除仍可能用于 PITR 的 WAL。建议保留规则：

- 最近一次可用全量物理备份以来的所有 WAL 必须保留；
- 至少保留 7–14 天归档，具体按 RPO/RTO 与存储成本确定；
- 清理前确认备份系统已有不可变副本；
- 如果存在多时间线（failover/promote 后常见），必须人工确认时间线关系后再清理。

**安全归档清理脚本**（兼容 tar/plain basebackup，不按 mtime 粗暴删除）：

```bash
#!/bin/bash
# /vastbase/scripts/wal_cleanup.sh —— 仅清理早于“最旧保留 basebackup 起点”的 WAL
set -uo pipefail
source /vastbase/scripts/backup.env   # 提供 VB_TAR / vb_untar_gz（tar 格式 backup_label 解析用）
ARCH=/vastbase/arch
BASE_ROOT=/vastbase/backup/base
DRYRUN=${DRYRUN:-0}     # DRYRUN=1 只打印不删除

extract_start_wal() {
    local dir="$1"
    if [[ -f "$dir/MANIFEST.txt" ]]; then
        awk -F: '/start_wal/{gsub(/ /,"",$2); print $2}' "$dir/MANIFEST.txt" | head -1
        return 0
    fi
    if [[ -f "$dir/backup_label" ]]; then
        grep -Eo 'file [0-9A-F]{24}' "$dir/backup_label" | awk '{print $2}' | head -1
        return 0
    fi
    # tar 格式：openGauss tar 须 gunzip + gs_tar 解（GNU tar -xOf 解不了），解到临时目录再读 backup_label。
    local src=""
    [[ -f "$dir/base.tar.gz" ]] && src="$dir/base.tar.gz"
    [[ -z "$src" && -f "$dir/base.tar" ]] && src="$dir/base.tar"
    if [[ -n "$src" ]]; then
        local tmpx; tmpx=$(mktemp -d "${TMPDIR:-/tmp}/vbcleanlabel.XXXXXX") || return 0
        if vb_untar_gz "$src" "$tmpx" >/dev/null 2>&1 && [[ -f "$tmpx/backup_label" ]]; then
            grep -Eo 'file [0-9A-F]{24}' "$tmpx/backup_label" | awk '{print $2}' | head -1
        fi
        rm -rf "$tmpx"
        return 0
    fi
}

mapfile -t BASES < <(find "$BASE_ROOT" -maxdepth 1 -mindepth 1 -type d -name '20*' | sort)
[[ ${#BASES[@]} -gt 0 ]] || { echo "no basebackup, refuse to clean"; exit 1; }

# 找出仍保留的最旧 basebackup，以其 start_wal 作为清理边界
OLDEST="${BASES[0]}"
START_WAL=$(extract_start_wal "$OLDEST")
[[ -n "$START_WAL" && "$START_WAL" != "unknown" ]] || { echo "cannot find START WAL from $OLDEST"; exit 1; }

echo "Keep WAL >= $START_WAL (from basebackup $(basename "$OLDEST"))"
cd "$ARCH" || exit 1
for f in $(ls -1 | grep -E '^[0-9A-F]{24}$' | sort); do
    if [[ "$f" < "$START_WAL" ]]; then
        if [[ "$DRYRUN" == "1" ]]; then
            echo "would rm $f"
        else
            echo "rm $f"
            rm -f "$f"
        fi
    fi
done
```

上线前先 dry-run：

```bash
DRYRUN=1 /vastbase/scripts/wal_cleanup.sh
```

确认边界无误后再加 crontab：

```cron
0 5 * * *  /vastbase/scripts/wal_cleanup.sh >> /vastbase/log/wal_cleanup.log 2>&1
```

---

### 17.6 保留逻辑备份，彻底停物理归档

**处理步骤（保留逻辑备份，彻底停物理归档）**

1. 改配置：archive_command 可以一并注释/置空，避免日后误启，用 guc 工具或直接改 postgresql.conf 都行

   ```conf
   archive_mode = off
   ```

2. reload 生效：

```bash
vb_ctl reload -D /vastbase/data/
# 然后进库确认
vsql -c "show archive_mode;"   # 应为 off
```

3. 关掉归档后，`.ready` 依赖即失效，手动触发回收：

```sql
CHECKPOINT;
```

回收是增量的，必要时隔几秒连做两三次。WAL 会逐步降到由 `checkpoint_segments=128` 决定的稳态——大致 `2×128+1 ≈ 257` 个段再叠加 `wal_keep_segments=16`，也就是 **4GB 左右**。从 72GB 降到 4GB 上下你就别再担心了，那是正常水位。

**两条红线**

- 不要 `rm pg_xlog/` 里的段文件，手删会直接搞坏实例。空间只能靠 checkpoint 自然回收。
- 清的是 archive_wal.sh **本该写入的那个归档目标目录**（如果之前有部分落盘的话），那里的旧归档随便删；pg_xlog 本身不要碰。逻辑备份（gs_dump/vb_dump 那套）完全不受影响，照常保留。


## 18. 监控指标、告警阈值与日常巡检

### 18.1 推荐告警阈值

> 日常监控阈值应与 §20.10 压测验收口径保持一致。CPU 阈值随业务类型不同：OLTP、混合、OLAP/批处理的稳态和峰值线详见 §20.10；下表给出日常告警的通用落地口径。

| 指标 | 告警阈值 | 严重阈值 | 处理建议 |
|------|----------|----------|----------|
| CPU 使用率（稳态） | OLTP >75%；混合 >80%；OLAP/批处理 >85% | 连续 10 分钟超过对应阈值 | 结合 TOP SQL、连接数、并行 worker、应用并发判断是否限流或调参 |
| CPU 使用率（峰值） | OLTP >85%；混合 >90%；OLAP/批处理 >95% | 峰值持续 5 分钟以上或伴随超时 | 排查执行计划、热点锁、连接池、并行策略，必要时降低并发 |
| 内存使用率 | > 80% 且可用内存持续下降 | > 90% 或接近 OOM | 核算 `work_mem × 活跃并发`、批处理并发、连接池和 shared_buffers |
| swap 增长率 | 10 分钟内持续增长 | 持续增长并伴随延迟抖动/OOM kill | 立即降低并发，评估下调 `work_mem` / `max_connections` |
| buffer cache 命中率 | OLTP < 99%；混合 < 98% | 持续低于阈值且读 I/O 升高 | 使用 `blks_hit/(blks_hit+blks_read)` 计算；优先查 SQL/索引，再评估内存参数 |
| 数据盘使用率 | > 75% | > 85% | 清理无效文件、扩容、排查膨胀 |
| 归档盘使用率 | > 70% | > 85% | 检查 archive_command、备份链路和清理策略 |
| 连接数使用率 | > 70% | > 90% | 排查连接池、长连接、空闲事务 |
| 长事务 | > 10 分钟 | > 30 分钟 | 联系业务或终止会话 |
| 慢 SQL | > 1 秒持续增多 | > 5 秒高频 | 分析执行计划与索引 |
| 死元组比例 | > 20% | > 40% | VACUUM、调 autovacuum、排查长事务 |
| 复制/归档延迟 | > 5 分钟 | > 30 分钟 | 检查网络、归档目录、备库状态 |
| 备份哨兵 | 当日缺失 | 连续 2 次缺失 | 立即人工介入 |
### 18.2 日常巡检命令

```bash
# 服务和端口
systemctl status vastbase --no-pager
ss -ntlp | grep -E ':5432|:26000'

# 磁盘与归档
df -hT /vastbase /vastbase/arch /vastbase/backup
du -sh /vastbase/arch /vastbase/backup/* 2>/dev/null | sort -h | tail

# 备份状态
test -f /vastbase/backup/$(date +%F)/BACKUP.OK && echo "backup ok" || echo "backup missing"
ls -1t /vastbase/log/backup/backup_*.log | head

# 最近错误日志
grep -iE "error|fatal|panic|could not|failed" /vastbase/log/pg_log/*$(date +%F)* 2>/dev/null | tail -50

# 时钟健康（判据与现场案例见 §14.9：RMS offset 应为毫秒级；今日应无 step/跳变记录）
chronyc tracking | grep -E 'RMS offset|System time|Frequency'
journalctl -u chronyd --since today --no-pager | tail -3     # 期望 No entries
grep 'was stepped' /var/log/messages 2>/dev/null | tail -1   # 看最后一次 step 的时间戳
# ★勿用 grep -c 累计计数作现状判据——它是历史总数、永不归零（§14.9 判据修正）
```

### 18.3 VastBase 内存专项巡检与排障

> 本节用于固化现场内存排查脚本、运行效果和日志分析方法。2026-06-16 现场复核结论：**当前内存状态健康，未发现 OOM、Swap 抖动或数据库动态内存逼近上限；真正需要跟进的是 2026-06-14 磁盘打满导致数据库 `PANIC` 的事故链路。**

#### 18.3.1 适用场景与执行方式

建议在以下场景执行本节脚本：

- 业务侧反馈数据库连接异常、SQL 卡顿、疑似 OOM、疑似 Swap 抖动。
- 服务器 `free/top` 看到内存使用异常，需区分数据库真实占用、共享内存和 page cache。
- 数据库报错中出现 `out of memory`、`could not fork`、`temporary file`、`PANIC` 等关键字。
- 例行巡检时需要保留 OS、数据库、cgroup、日志的同一时间点证据。

推荐以 `root` 执行，便于完整采集 `dmesg`、`journalctl`、cgroup 与服务日志：

```bash
chmod +x /vastbase/scripts/memory_check.sh
sudo /vastbase/scripts/memory_check.sh
```

如果只能以 `vastbase` 用户执行，脚本仍可采集 OS 与数据库大部分信息，但 `dmesg`、`journalctl` 可能因权限不足输出 WARN。出现 WARN 时，不能据此下结论“无 OOM kill 证据”。

#### 18.3.2 一键采集脚本 `/vastbase/scripts/memory_check.sh`（v3）

> 该版本已经修复两轮高级 DBA 反馈中的关键问题：
>
> 1. `backup.env` 中的 `vb_sql` 是 shell 函数，必须在当前 shell 直接执行，不能通过 `bash -c` 子 shell 调用，否则会出现 `vb_sql: command not found`，导致 `pg_total_memory_detail` 为空。
> 2. 数据库日志扫描不能使用 `grep -i ... ERROR`，否则会误命中 WDR SQL 里的 `error_count` 字段，产生大量无害噪声并淹没真正的 `PANIC`。
> 3. cgroup v1 的 `MemoryCurrent` / `memory.usage_in_bytes` 包含 page cache，不等于 VastBase RSS，必须结合 `memory.stat` 中的 `rss` 与 `cache` 拆分判断。

```bash
#!/bin/bash
#==============================================================================
# memory_check.sh —— VastBase 内存专项巡检/排障采集 v3
#
# 用法：
#   bash /vastbase/scripts/memory_check.sh
#   sudo bash /vastbase/scripts/memory_check.sh   # 推荐：完整采 dmesg/journalctl/cgroup
#
# 输出：
#   /vastbase/log/memory_check/memory_check_YYYYmmdd_HHMMSS.log
#
# v3 修订重点：
#   1. DB SQL 段不再通过 bash -c 执行，避免 backup.env 中的 vb_sql 函数丢失。
#   2. 数据库日志 grep 拆成“内存高信号”和“严重级别事件”，避免 -i ERROR 误命中 error_count。
#   3. cgroup v1 增加 memory.stat 中 rss/cache 拆分，避免把 page cache 误判为数据库实际占用。
#   4. pmap 改为按 RSS 排序取 Top，避免 tail 只看到 libs/stack。
#   5. grep 无匹配不再误报 WARN；权限不足才显式 WARN。
#==============================================================================

set -uo pipefail

source /vastbase/scripts/backup.env 2>/dev/null || true

BASE_DIR=${BASE_DIR:-/vastbase/log/memory_check}
PGDATA=${PGDATA:-/vastbase/data}
PG_PORT=${PG_PORT:-5432}
PG_USER=${PG_USER:-vbadmin}
VB_SERVICE=${VB_SERVICE:-vastbase}
VB_BIN_PATTERN=${VB_BIN_PATTERN:-/vastbase/app/bin/vastbase}
VB_SQL=${VB_SQL:-$(command -v vsql 2>/dev/null || command -v gsql 2>/dev/null || true)}

mkdir -p "$BASE_DIR"
LOG="$BASE_DIR/memory_check_$(date +%Y%m%d_%H%M%S).log"
SQLF="$(mktemp /tmp/vb_memory_check.XXXXXX.sql)"
trap 'rm -f "$SQLF"' EXIT

ts() { date '+%F %T'; }

section() {
  echo
  echo "===== $(ts) $* ====="
}

run() {
  echo "+ $*"
  bash -c "$*" 2>&1 || true
}

run_warn() {
  echo "+ $*"
  local out rc
  out="$(bash -c "$*" 2>&1)"
  rc=$?
  [ -n "$out" ] && echo "$out"
  [ "$rc" -ne 0 ] && echo "WARN: command failed rc=$rc: $*"
  return 0
}

run_perm_sensitive_grep() {
  echo "+ $*"
  local out rc
  out="$(bash -c "$*" 2>&1)"
  rc=$?
  [ -n "$out" ] && echo "$out"

  if echo "$out" | grep -Eiq 'Operation not permitted|Permission denied|No journal files were opened|insufficient permissions|not seeing messages'; then
    echo "WARN: insufficient permission; run as root/sudo, or grant journal/dmesg access."
  elif [ "$rc" -eq 1 ]; then
    echo "INFO: no matching OOM/kernel records found."
  elif [ "$rc" -ne 0 ]; then
    echo "WARN: command failed rc=$rc: $*"
  fi

  return 0
}

run_log_grep() {
  echo "+ $*"
  local out rc
  out="$(bash -o pipefail -c "$*" 2>&1)"
  rc=$?
  [ -n "$out" ] && echo "$out"

  if [ "$rc" -eq 1 ]; then
    echo "INFO: no matching log records found."
  elif [ "$rc" -ne 0 ]; then
    echo "WARN: log grep failed rc=$rc: $*"
  fi

  return 0
}

has_vb_sql() {
  declare -F vb_sql >/dev/null 2>&1 || command -v vb_sql >/dev/null 2>&1
}

db_scalar() {
  local sql="$1"
  if has_vb_sql; then
    vb_sql postgres -At -c "$sql" 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -1
  elif [ -n "$VB_SQL" ] && [ -t 0 ]; then
    "$VB_SQL" -h 127.0.0.1 -p "$PG_PORT" -U "$PG_USER" -d postgres -At -c "$sql" 2>/dev/null \
      | sed '/^[[:space:]]*$/d' | tail -1
  else
    return 1
  fi
}

run_db_file() {
  local rc

  if has_vb_sql; then
    echo "+ vb_sql postgres -f '$SQLF'"
    vb_sql postgres -f "$SQLF" 2>&1
    rc=$?
    [ "$rc" -ne 0 ] && echo "WARN: db command failed rc=$rc: vb_sql postgres -f '$SQLF'"
    return 0
  fi

  if [ -n "$VB_SQL" ] && [ -t 0 ]; then
    echo "+ '$VB_SQL' -h 127.0.0.1 -p '$PG_PORT' -U '$PG_USER' -d postgres -f '$SQLF'"
    "$VB_SQL" -h 127.0.0.1 -p "$PG_PORT" -U "$PG_USER" -d postgres -f "$SQLF" 2>&1
    rc=$?
    [ "$rc" -ne 0 ] && echo "WARN: db command failed rc=$rc: $VB_SQL -f '$SQLF'"
    return 0
  fi

  echo "WARN: non-interactive run and vb_sql wrapper unavailable; skip database SQL to avoid password hang/empty report."
  return 0
}

resolve_pg_log_dir() {
  local raw resolved

  # 不使用 LOG_DIR，避免被 /vastbase/scripts/backup.env 中的 LOG_DIR=/vastbase/log/backup 污染。
  raw="${PG_LOG_DIR:-}"

  if [ -z "$raw" ]; then
    raw="$(db_scalar "show log_directory;" 2>/dev/null || true)"
  fi

  if [ -n "$raw" ]; then
    case "$raw" in
      /*) resolved="$raw" ;;
      *)  resolved="$PGDATA/$raw" ;;
    esac

    if [ -d "$resolved" ]; then
      echo "$resolved"
      return 0
    fi
  fi

  for resolved in "$PGDATA/pg_log" "$PGDATA/log" "/vastbase/log/pg_log" "/vastbase/log/vastbase"; do
    if [ -d "$resolved" ]; then
      echo "$resolved"
      return 0
    fi
  done

  echo ""
  return 1
}

{
section "host"
run "hostnamectl 2>/dev/null || hostname"
run "date"
run "uptime"
run "whoami"
run "id"

section "free/top snapshot"
run "free -h"
run "top -b -n 1 | head -40"

section "disk snapshot"
run "df -hT"
run "df -ihT"
run "du -sh /vastbase/log /vastbase/data /vastbase/log/backup 2>/dev/null || true"

section "meminfo and vm tunables"
run "egrep 'MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Committed_AS|CommitLimit|Slab|SReclaimable|SUnreclaim|Dirty|Writeback|AnonHugePages|Shmem' /proc/meminfo"
run "sysctl vm.overcommit_memory vm.overcommit_ratio vm.swappiness vm.min_free_kbytes 2>/dev/null"
run "cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true"
run "cat /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true"

section "process rss top"
run "ps -eo pid,user,rss,vsz,pmem,comm,args --sort=-rss | head -30"
run "ps -eo pid,user,rss,vsz,pmem,comm,args --sort=-rss | grep -E 'vastbase|gaussdb|postgres' | grep -v grep"

section "vastbase proc status/smaps"
PID="$(pgrep -u vastbase -f "$VB_BIN_PATTERN" | head -1 || true)"
[ -n "${PID:-}" ] || PID="$(pgrep -u vastbase -f "gaussdb.*-D.*${PGDATA}" | head -1 || true)"
[ -n "${PID:-}" ] || PID="$(pgrep -f "vastbase.*-D.*${PGDATA}" | head -1 || true)"
echo "PID=${PID:-not_found}"

if [ -n "${PID:-}" ] && [ -r "/proc/$PID/status" ]; then
  run "cat /proc/$PID/status | egrep 'Name|State|Threads|VmRSS|VmSize|VmPeak|RssAnon|RssFile|RssShmem|VmSwap'"
  run "cat /proc/$PID/smaps_rollup 2>/dev/null | egrep 'Rss|Pss|Shared|Private|Swap|Hugetlb'"
  run "pmap -x $PID 2>/dev/null | awk 'NR==1 || /^total/ {print; next} /^[0-9a-f]/ {print}' | sort -k3 -n -r | head -15"
else
  echo "WARN: VastBase main PID not found or /proc status unreadable."
fi

section "vmstat"
run "vmstat 1 10"

section "swap users"
for p in /proc/[0-9]*; do
  pid="${p##*/}"
  [ -r "$p/status" ] || continue

  swap="$(awk '/^VmSwap:/{print $2}' "$p/status" 2>/dev/null)"
  [ -n "$swap" ] && [ "$swap" -gt 0 ] || continue

  name="$( { tr '\0' ' ' <"$p/cmdline"; } 2>/dev/null )"
  [ -n "$name" ] || name="$(awk '/^Name:/{print $2}' "$p/status" 2>/dev/null)"

  echo "$swap KB  PID=$pid  $name"
done | sort -nr | head -20

section "oom/kernel logs"
run_perm_sensitive_grep "dmesg -T | egrep -i 'out of memory|oom|killed process|memory allocation failure'"
run_perm_sensitive_grep "journalctl -k --since '24 hours ago' --no-pager -q | egrep -i 'out of memory|oom|killed process|memory allocation failure'"

section "systemd vastbase logs"
run "journalctl -u $VB_SERVICE --since '24 hours ago' --no-pager -q | tail -200"

section "systemd and cgroup memory limits"
run_warn "systemctl show $VB_SERVICE -p MainPID -p MemoryMax -p MemoryHigh -p MemoryCurrent -p TasksCurrent -p Restart -p OOMPolicy 2>/dev/null"

echo "INFO: On cgroup v1, MemoryCurrent/memory.usage_in_bytes includes page cache; it is not equal to VastBase RSS."
echo "INFO: Use memory.stat rss/cache split below to distinguish process RSS from page cache."

# cgroup v2 常见路径
run "cat /sys/fs/cgroup/system.slice/${VB_SERVICE}.service/memory.max 2>/dev/null || true"
run "cat /sys/fs/cgroup/system.slice/${VB_SERVICE}.service/memory.high 2>/dev/null || true"
run "cat /sys/fs/cgroup/system.slice/${VB_SERVICE}.service/memory.current 2>/dev/null || true"
run "cat /sys/fs/cgroup/system.slice/${VB_SERVICE}.service/memory.events 2>/dev/null || true"
run "egrep '^(anon|file|kernel_stack|pagetables|slab|sock|shmem|rss|cache) ' /sys/fs/cgroup/system.slice/${VB_SERVICE}.service/memory.stat 2>/dev/null || true"

# cgroup v1 常见路径
run "cat /sys/fs/cgroup/memory/system.slice/${VB_SERVICE}.service/memory.limit_in_bytes 2>/dev/null || true"
run "cat /sys/fs/cgroup/memory/system.slice/${VB_SERVICE}.service/memory.usage_in_bytes 2>/dev/null || true"
run "cat /sys/fs/cgroup/memory/system.slice/${VB_SERVICE}.service/memory.failcnt 2>/dev/null || true"
run "egrep '^(rss|cache|mapped_file|pgfault|pgmajfault|inactive_file|active_file|inactive_anon|active_anon) ' /sys/fs/cgroup/memory/system.slice/${VB_SERVICE}.service/memory.stat 2>/dev/null || true"

section "database memory parameters and connections"
cat >"$SQLF" <<'SQL'
\pset pager off

SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
  'max_connections',
  'sysadmin_reserved_connections',
  'shared_buffers',
  'work_mem',
  'maintenance_work_mem',
  'temp_buffers',
  'wal_buffers',
  'max_process_memory',
  'enable_memory_limit',
  'cstore_buffers',
  'effective_cache_size',
  'enable_resource_track',
  'track_activity_query_size',
  'logging_collector',
  'log_directory',
  'log_filename',
  'log_min_messages',
  'log_temp_files'
)
ORDER BY name;

SELECT 'pg_stat_activity_by_state' AS section, state, count(*)
FROM pg_stat_activity
GROUP BY state
ORDER BY count(*) DESC;

SELECT 'pg_stat_activity_by_db' AS section, datname, count(*)
FROM pg_stat_activity
GROUP BY datname
ORDER BY count(*) DESC;

SELECT pid,
       usename,
       datname,
       state,
       query_start,
       now() - query_start AS runtime,
       left(query, 200) AS query
FROM pg_stat_activity
WHERE state <> 'idle'
  AND query_start IS NOT NULL
ORDER BY query_start;

SELECT 'pg_total_memory_detail' AS section,
       memorytype,
       memorymbytes
FROM pg_total_memory_detail
ORDER BY memorymbytes DESC;

SELECT 'memory_views' AS section,
       schemaname,
       viewname
FROM pg_views
WHERE lower(viewname) LIKE '%memory%'
ORDER BY schemaname, viewname;

SELECT *
FROM dbe_perf.global_session_memory_detail
LIMIT 50;
SQL

if [ -n "$VB_SQL" ] || has_vb_sql; then
  run_db_file
else
  echo "WARN: vsql/gsql not found in PATH and vb_sql wrapper unavailable; skip database SQL."
fi

section "database error/temp-file logs"
DB_LOG_DIR_SETTING="$(db_scalar "show log_directory;" 2>/dev/null || true)"
DB_LOG_FILENAME_SETTING="$(db_scalar "show log_filename;" 2>/dev/null || true)"
DB_LOG_TEMP_FILES="$(db_scalar "show log_temp_files;" 2>/dev/null || true)"
PG_LOG_DIR_RESOLVED="$(resolve_pg_log_dir || true)"

echo "DB log_directory setting=${DB_LOG_DIR_SETTING:-unknown}"
echo "DB log_filename setting=${DB_LOG_FILENAME_SETTING:-unknown}"
echo "DB log_temp_files setting=${DB_LOG_TEMP_FILES:-unknown}"
echo "PG_LOG_DIR=${PG_LOG_DIR_RESOLVED:-not_found}"

if [ -n "$PG_LOG_DIR_RESOLVED" ] && [ -d "$PG_LOG_DIR_RESOLVED" ]; then
  echo
  echo "----- memory related high-signal logs -----"
  run_log_grep "grep -RniE 'out of memory|memory exhausted|cannot allocate memory|insufficient memory|could not fork new process|memory allocation (failed|failure)|invalid memory alloc|temporary file' '$PG_LOG_DIR_RESOLVED' 2>/dev/null | grep -vE 'PMstate PM_(STARTUP|RECOVERY)' | tail -100"

  echo
  echo "----- severe database events -----"
  run_log_grep "grep -RnE ' (ERROR|FATAL|PANIC):' '$PG_LOG_DIR_RESOLVED' 2>/dev/null | grep -vE 'terminating connection due to administrator command|Invalid username/password|syntax error|does not exist|already exists|terminate because cancel interrupts' | tail -200"

  echo
  echo "----- disk full / write failure events -----"
  run_log_grep "grep -RniE 'No space left on device|could not extend file|could not write to file|could not create file|Write error|cannot write compressed block' '$PG_LOG_DIR_RESOLVED' 2>/dev/null | tail -100"
else
  echo "WARN: database log directory not found. Set PG_LOG_DIR explicitly, e.g. PG_LOG_DIR=/vastbase/data/pg_log bash memory_check.sh"
fi

section "summary hint"
cat <<'EOF'
判读重点：
1. OS 层：MemAvailable 是否持续下降；Committed_AS 是否逼近 CommitLimit；Dirty/Writeback 是否异常。
2. Swap 层：vmstat si/so 是否持续 >0；VastBase 主进程 VmSwap/SwapPss 是否 >0。
3. 进程层：VastBase PSS/Private_Dirty 是否持续增长；RssShmem 是否主要来自 shared_buffers。
4. 数据库层：重点看 pg_total_memory_detail 中 dynamic_used_memory、max_dynamic_memory、process_used_memory、max_process_memory、dynamic_peak_memory。
5. 日志层：PG_LOG_DIR 必须指向数据库日志；严重事件按 ' ERROR:'/' FATAL:'/' PANIC:' 锚定，不再用 -i ERROR。
6. temporary file：如果 log_temp_files=-1，未匹配到 temporary file 不能说明没有 work_mem 溢出到磁盘，只说明未记录。
7. cgroup 层：cgroup v1 的 MemoryCurrent/memory.usage_in_bytes 包含 page cache，不等于数据库 RSS；需看 memory.stat 的 rss/cache 拆分。
8. 磁盘层：No space left on device、could not extend/write/create file、PANIC/write error 优先按磁盘容量事故处理，不要误判为内存问题。
EOF

} | tee "$LOG"

echo "memory check log: $LOG"
```

#### 18.3.3 v3 脚本运行效果摘要

2026-06-16 11:05 以 root 执行 `memory_check_v3.sh` 后，脚本完成以下关键采集：

| 采集项 | 现场结果 | 判读 |
|---|---:|---|
| 主机与系统 | Kylin Linux Advanced Server V10，内核 `4.19.90-25.44.v2101.ky10.x86_64` | 与部署文档适用范围一致。 |
| 内存总量 | `MemTotal≈30Gi` | 32GB 档位主机。 |
| 可用内存 | `available≈24Gi` / `MemAvailable≈25GB` | 内存余量充足。 |
| Swap | 总量 15Gi，使用约 2MiB；`vmstat si/so=0` | 没有持续换入换出。 |
| VastBase 主进程 | PID `4174`，RSS≈3.9GB，SHR≈3.1GB | 大头来自共享内存段，不是异常私有内存暴涨。 |
| `/proc/$PID/status` | `VmSwap=0`，`RssShmem≈3105616kB` | 数据库主进程未进入 Swap。 |
| `smaps_rollup` | `Swap=0`，`SwapPss=0`，`Pss≈3938431kB` | 进程实际内存稳定。 |
| pmap Top RSS | 最大段为 `[ shmid=0x0 ]`，RSS≈3105604kB | 证明 3.1GB 来自共享内存段，符合 `shared_buffers` 预期。 |
| OOM 日志 | `INFO: no matching OOM/kernel records found.` | root 执行下未发现近 24 小时 OOM kill 证据。 |
| cgroup | `MemoryMax=infinity`，v1 `memory.limit_in_bytes=9223372036854771712`，`failcnt=0` | 未设置 systemd/cgroup 内存硬限制，也无 cgroup OOM 计数。 |
| cgroup v1 拆分 | `cache≈29.5GB`，`rss≈711MB` | `MemoryCurrent≈30GB` 主要是 page cache，不是 VastBase 进程 RSS。 |
| 数据库内存视图 | `pg_total_memory_detail` 正常出数 | v3 已修复 DB SQL 段为空的问题。 |
| 数据库日志目录 | `PG_LOG_DIR=/vastbase/data/pg_log` | 已避免 `backup.env` 中 `LOG_DIR=/vastbase/log/backup` 污染。 |

#### 18.3.4 数据库内存视图判读

v3 脚本已能成功查询 `pg_total_memory_detail`，现场关键输出如下：

```text
memorytype                memorymbytes
---------------------------------------
max_process_memory        20533
max_shared_memory         11859
max_dynamic_memory         7813
process_used_memory        3856
shared_used_memory         3172
dynamic_peak_memory         901
dynamic_used_memory         817
dynamic_peak_shrctx         405
dynamic_used_shrctx         400
backend_used_memory           2
```

判读：

- `process_used_memory=3856MB`，仅占 `max_process_memory=20533MB` 的约 **18.8%**。
- `dynamic_used_memory=817MB`，仅占 `max_dynamic_memory=7813MB` 的约 **10.5%**。
- `dynamic_peak_memory=901MB`，约占 `max_dynamic_memory` 的 **11.5%**。
- `shared_used_memory=3172MB`，与 OS 层 `RssShmem≈3.1GB`、pmap `[ shmid=0x0 ]≈3.1GB` 对得上。
- 当前没有接近 `max_process_memory` 或 `max_dynamic_memory` 的迹象。

因此，本次内存专项的数据库侧结论为：**内存使用健康，未发现数据库动态内存逼近上限。**

#### 18.3.5 日志输出分析

v3 将日志扫描拆成三段，避免噪声和误判。

**1）内存相关高信号日志**

```text
----- memory related high-signal logs -----
INFO: no matching log records found.
```

说明：未匹配到 `out of memory`、`memory exhausted`、`cannot allocate memory`、`temporary file` 等内存高信号。现场 `log_temp_files=10MB`，因此超过 10MB 的临时文件理论上会被记录；未匹配到 `temporary file` 可以作为“当前未见明显大临时文件日志”的证据。若某现场 `log_temp_files=-1`，则不能用“未匹配到 temporary file”推断没有 work_mem 溢出，只能说明数据库未记录该类日志。

**2）严重数据库事件日志**

```text
----- severe database events -----
grep -RnE ' (ERROR|FATAL|PANIC):' ...
```

该段区分大小写，并按 ` ERROR:` / ` FATAL:` / ` PANIC:` 锚定，避免把 WDR 快照 SQL 中的 `snap_error_count`、`error_count` 误判为错误日志。常见连接终止、登录失败、语法错误等噪声已在 grep 后排除。

**3）磁盘打满 / 写失败事件**

现场最重要的异常在此段暴露：

```text
2026-06-14 09:33:32 ERROR: could not write to file "pg_xlog/xlogtemp...": No space left on device
2026-06-14 09:38:29 ERROR: could not extend file "base/23560/54159": No space left on device
2026-06-14 09:39:51 ERROR: could not extend file "base/23560/54179": No space left on device
2026-06-14 09:41:13 ERROR: could not extend file "base/23560/54203": No space left on device
2026-06-14 09:42:35 ERROR: could not extend file "base/23560/54227": No space left on device
2026-06-14 09:43:57 ERROR: could not extend file "base/23560/54251": No space left on device
2026-06-14 09:45:19 ERROR: could not extend file "base/23560/54275": No space left on device
2026-06-14 09:46:34 PANIC: could not create file "pg_logical/replorigin_checkpoint.tmp": No space left on device
Error 36 : Write error : cannot write compressed block
```

这条链路说明：

- 6 月 14 日 09:33 起，数据库已经无法写入 WAL 临时文件。
- 随后 WDR 快照写入系统表/快照表时连续 `could not extend file`。
- 09:46 因无法创建 `pg_logical/replorigin_checkpoint.tmp` 触发 `PANIC`。
- `Error 36 : Write error : cannot write compressed block` 与磁盘写失败同向。

因此本次真正应上报的事故不是内存，而是：**磁盘空间被逐步消耗直至打满，最终导致数据库 PANIC。**

#### 18.3.6 与 v1/v2 脚本问题的对比

| 版本/问题 | 现象 | 影响 | v3 修复方式 |
|---|---|---|---|
| v1：`LOG_DIR` 被 `backup.env` 污染 | 实际扫描 `/vastbase/log/backup` | 数据库日志完全漏扫，真实 `PANIC` 会被漏掉 | 改用 `PG_LOG_DIR`，优先 `SHOW log_directory` 推导真实日志目录。 |
| v1：只列内存视图不查询 | 只输出 `pg_views WHERE viewname LIKE '%memory%'` | 无法判断是否逼近 `max_process_memory` / `max_dynamic_memory` | 增加 `pg_total_memory_detail` 查询。 |
| v1：`dmesg/journalctl` 权限不足静默吞掉 | 看似已采集，实际无证据 | 误判“无 OOM” | 权限不足显式 WARN；root 执行时输出无匹配 INFO。 |
| v1：`/proc/*/cmdline` 竞态 | `No such file or directory` | 输出噪声 | 用花括号整体兜住重定向错误，并先判断可读性。 |
| v2：`vb_sql: command not found` | `run_warn "vb_sql ..."` 进入 `bash -c` 子 shell | 数据库 SQL 段彻底为空 | DB 命令用 `run_db_file` 在当前 shell 直接执行。 |
| v2：`grep -i ERROR` 命中 `error_count` | 满屏 WDR `LOG` 行 | 淹没真正 `PANIC` | 严重事件按 ` (ERROR|FATAL|PANIC):` 区分大小写锚定。 |
| v2：cgroup `MemoryCurrent≈30GB` 裸输出 | 可能被误解为数据库占用 30GB | 误判内存异常 | 明确 cgroup v1 包含 page cache，并输出 `memory.stat rss/cache`。 |

#### 18.3.7 本次现场结论

**内存结论：健康。**

证据如下：

- `MemAvailable≈25GB`，系统可用内存充足。
- Swap 仅约 2MB，且 `vmstat si/so=0`，无持续换页。
- VastBase 主进程 `VmSwap=0`、`Swap=0`、`SwapPss=0`。
- 主进程 RSS≈3.9GB，其中约 3.1GB 为共享内存段；不是私有内存异常增长。
- `process_used_memory=3856MB`，距离 `max_process_memory=20533MB` 很远。
- `dynamic_used_memory=817MB`、`dynamic_peak_memory=901MB`，距离 `max_dynamic_memory=7813MB` 很远。
- cgroup `MemoryMax=infinity`、`memory.limit_in_bytes=9223372036854771712`、`failcnt=0`，未见 cgroup OOM。
- root 权限下 `dmesg` / `journalctl -k` 未匹配到 OOM kill。

**事故结论：6 月 14 日磁盘打满导致数据库 PANIC。**

证据如下：

- 数据库真实日志目录为 `/vastbase/data/pg_log`。
- 6 月 14 日 09:33–09:46 连续出现 `No space left on device`。
- 最终出现 `PANIC: could not create file "pg_logical/replorigin_checkpoint.tmp": No space left on device`。
- 之后 6 月 15 日 10:27、14:25 出现重启/启动日志；当前实例运行时间与 14:25 启动时间一致。

#### 18.3.8 后续处置建议

1. **磁盘容量与归档链路优先处理**
   - 复查 `/vastbase/data`、`/vastbase/arch`、`/vastbase/backup` 的历史增长曲线。
   - 复查备份脚本和归档清理脚本是否在 6 月 11 日至 6 月 14 日持续告警未处理。
   - 确认是否存在备份目录、归档目录、数据库目录共盘导致互相挤占。

2. **PANIC 后一致性确认**
   - 确认 6 月 15 日启动后的恢复日志是否完整，无残留 redo/recovery 异常。
   - 对核心业务表执行抽样校验、业务对账或应用层一致性检查。
   - 检查是否有 `pg_xlog`、`archive_status/*.ready` 堆积，防止再次因归档失败撑满磁盘。

3. **保留当前内存巡检脚本作为生产版本**
   - 将 v3 脚本落地为 `/vastbase/scripts/memory_check.sh`。
   - 日志保留路径 `/vastbase/log/memory_check/`。
   - 例行巡检可每天跑一次；不建议分钟级高频执行。

4. **参数风险提醒**
   - 现场 `max_connections=3000`、`work_mem=64MB` 在高并发复杂排序/Hash 场景下理论放大风险较高。
   - 当前 `enable_memory_limit=on`、`max_process_memory≈20GB` 有兜底，但仍应通过连接池控制真实活跃并发。
   - 后续若出现 `dynamic_used_memory` 持续接近 `max_dynamic_memory`，再结合 SQL、会话级内存视图和临时文件日志做专项分析。

#### 18.3.9 定时巡检建议

```bash
# root 或具备 sudo 权限的运维用户
mkdir -p /vastbase/log/memory_check

# 每天 08:30 采集一次；保留 30 天
cat >/etc/cron.d/vastbase_memory_check <<'EOF'
30 8 * * * root /vastbase/scripts/memory_check.sh >/dev/null 2>&1
10 1 * * * root find /vastbase/log/memory_check -name 'memory_check_*.log' -mtime +30 -delete
EOF
```

验收时至少保留以下证据：

```bash
ls -lh /vastbase/log/memory_check/
grep -A40 'database memory parameters and connections' /vastbase/log/memory_check/memory_check_*.log | tail -80
grep -A80 'database error/temp-file logs' /vastbase/log/memory_check/memory_check_*.log | tail -120
grep -A40 'systemd and cgroup memory limits' /vastbase/log/memory_check/memory_check_*.log | tail -80
```

### 18.4 周期性巡检报告建议

| 周期 | 内容 |
|------|------|
| 每日 | 实例状态、备份成功、磁盘容量、连接数、慢 SQL、长事务 |
| 每周 | 表膨胀、索引膨胀、TOP 表、归档增长、权限变更 |
| 每月 | 恢复演练、参数复核、补丁评估、容量趋势与扩容预测 |
| 每季度 | 安全基线复核、账号清理、口令轮换、灾备切换演练 |

### 18.5 自包含监控脚本（无 Zabbix/Prometheus 时的兜底）

如果暂时没有接入企业监控平台，下面这段脚本可覆盖 §18.1 的核心指标，并以“分级退出码”驱动 cron 邮件告警。

本节脚本已经按现场反馈做四类加固：

1. **长事务判据排除内部后台线程**：VastBase/openGauss 的 WLM 后台线程可能在 `pg_stat_activity` 中长期显示为 `active`，例如 `application_name='workload'`、`query='WLM fetch collect info from data nodes'`、`client_addr IS NULL`。这类本地后台不是业务长事务，不应触发 `[CRITICAL] long transaction(s) > 30min`。
2. **SQL 连接参数统一**：所有数据库检查都经 `vbq()` 注入 `PG_HOST`、`PG_PORT`、`PG_USER` 和口令，避免非 5432 端口下部分指标连错默认端口后静默漏测。
3. **监控日志低噪声落盘**：日常日志只记录异常与状态翻转；`OK→OK` 不写入日志，避免每 5 分钟一条 `all OK` 把真实告警淹没。交互和 cron stdout 仍保持每次都有输出。
4. **cron 与备份哨兵防误报**：cron 只调用 wrapper，不在 crontab 中写多行复合逻辑；`BACKUP.OK` 只在每日预设备份完成时刻之后才判 CRITICAL，避免备份窗口前邮件风暴。

`/vastbase/scripts/monitor.sh`：

```bash
#!/bin/bash
#==============================================================================
# monitor.sh —— VastBase 综合健康检查
# 退出码:  0=全部 OK   1=有 WARN   2=有 CRITICAL
#
# 日志策略：
#   - stdout 每次输出，便于交互执行、cron 邮件或外部监控采集。
#   - monitor.log 只记录异常和状态翻转，避免 all OK 噪声。
#   - 需要排查脚本内部 SQL/变量时，用 bash -x 临时生成 trace。
#==============================================================================
set -uo pipefail
source /vastbase/scripts/backup.env

LOG_DIR="${LOG_DIR:-/vastbase/log/backup}"
MON_LOG="${MON_LOG:-$LOG_DIR/monitor.log}"
STATE_FILE="${STATE_FILE:-$LOG_DIR/.monitor.lastlevel}"

mkdir -p "$LOG_DIR" 2>/dev/null || true

# 健康检查均连 postgres；VastBase 本机工具不消费 .pgpass，统一走 backup.env 中的口令注入逻辑。
MON_PW=$(pgpass_lookup "${PG_HOST:-127.0.0.1}" "${PG_PORT:-5432}" postgres "${PG_USER:-vbadmin}" 2>/dev/null || true)
# 所有 SQL 调用都由 vbq 统一注入 host/port/user，避免非 5432 端口下部分指标静默漏测。
# 调用点如重复传入 -h/-p/-U，以后者为准；常规调用无需重复写连接参数。
vbq() {
    printf '%s\n' "$MON_PW" | "${VB_SQL:-vsql}" -2 \
        -h "${PG_HOST:-127.0.0.1}" -p "${PG_PORT:-5432}" -U "${PG_USER:-vbadmin}" "$@"
}
SQL=vbq

ALERTS=()
LEVEL=0   # 0=ok 1=warn 2=crit

warn() { ALERTS+=("[WARN] $*");      [[ $LEVEL -lt 1 ]] && LEVEL=1; }
crit() { ALERTS+=("[CRITICAL] $*");  LEVEL=2; }

# ---------- 1. 服务状态 ----------
if ! systemctl is-active --quiet vastbase; then
    crit "vastbase service NOT running"
fi
if ! $SQL -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
    crit "DB login failed"
fi

# ---------- 2. 磁盘 ----------
# 数据盘/备份盘按通用阈值告警；归档盘单独提前 WARN 到 70%，与 §17.2.3/§17.2.4 对齐。
for MP in /vastbase /vastbase/backup; do
    [[ -d "$MP" ]] || continue
    USED=$(df -P "$MP" | awk 'NR==2{gsub(/%/,"",$5);print $5}')
    [[ "${USED:-0}" -ge 85 ]] && crit "disk $MP used=${USED}%"
    [[ "${USED:-0}" -ge 75 && "${USED:-0}" -lt 85 ]] && warn "disk $MP used=${USED}%"
done
if [[ -d /vastbase/arch ]]; then
    USED=$(df -P /vastbase/arch | awk 'NR==2{gsub(/%/,"",$5);print $5}')
    [[ "${USED:-0}" -ge 85 ]] && crit "disk /vastbase/arch used=${USED}%"
    [[ "${USED:-0}" -ge 70 && "${USED:-0}" -lt 85 ]] && warn "disk /vastbase/arch used=${USED}%"
fi

# ---------- 3. 连接数 ----------
read -r CONN MAXC < <($SQL -d postgres -At -F ' ' \
    -c "SELECT (SELECT count(*) FROM pg_stat_activity), current_setting('max_connections')::int" 2>/dev/null)
if [[ -n "${CONN:-}" && -n "${MAXC:-}" && "${MAXC:-0}" -gt 0 ]]; then
    PCT=$(( CONN * 100 / MAXC ))
    [[ $PCT -ge 90 ]] && crit "connections ${CONN}/${MAXC} (${PCT}%)"
    [[ $PCT -ge 70 && $PCT -lt 90 ]] && warn "connections ${CONN}/${MAXC} (${PCT}%)"
fi

# ---------- 4. 长事务 ----------
# 排除内部后台线程（WLM/WDR 等）：client_addr 为空的本地后台不计；application_name 白名单兜底。
# 现场误报样例：application_name='workload'，query='WLM fetch collect info from data nodes'，xact_start 跨天。
# 注意：如现场存在本地 unix socket 业务连接，client_addr 也可能为空，应改用 application_name 白名单策略，见 §18.5.1。
LONG=$($SQL -d postgres -At \
    -c "SELECT count(*) FROM pg_stat_activity
          WHERE state = 'active'
            AND xact_start IS NOT NULL
            AND client_addr IS NOT NULL
            AND application_name NOT IN ('workload','WLMmonitor','WLMarbiter','WDRSnapshot')
            AND NOW()-xact_start > INTERVAL '30 minutes'" 2>/dev/null)
[[ "${LONG:-0}" -gt 0 ]] && crit "$LONG long transaction(s) > 30min"

MID=$($SQL -d postgres -At \
    -c "SELECT count(*) FROM pg_stat_activity
          WHERE state = 'active'
            AND xact_start IS NOT NULL
            AND client_addr IS NOT NULL
            AND application_name NOT IN ('workload','WLMmonitor','WLMarbiter','WDRSnapshot')
            AND NOW()-xact_start > INTERVAL '10 minutes'
            AND NOW()-xact_start <= INTERVAL '30 minutes'" 2>/dev/null)
[[ "${MID:-0}" -gt 0 ]] && warn "$MID transaction(s) > 10min and <=30min"

# ---------- 5. idle in transaction ----------
# idle in transaction 只统计客户端会话；内部后台线程 client_addr 通常为空，不纳入业务告警。
IDLE=$($SQL -d postgres -At \
    -c "SELECT count(*) FROM pg_stat_activity
          WHERE state = 'idle in transaction'
            AND client_addr IS NOT NULL
            AND NOW()-state_change > INTERVAL '10 minutes'" 2>/dev/null)
[[ "${IDLE:-0}" -gt 0 ]] && warn "$IDLE idle-in-transaction > 10min"

# ---------- 6. 死元组 ----------
BLOAT_TBL=$($SQL -d postgres -At \
    -c "SELECT count(*) FROM pg_stat_user_tables
          WHERE n_dead_tup > 100000
            AND n_dead_tup::float / NULLIF(n_live_tup+n_dead_tup,0) > 0.4" 2>/dev/null)
[[ "${BLOAT_TBL:-0}" -gt 0 ]] && crit "$BLOAT_TBL table(s) dead_ratio > 40%"

# ---------- 7. 归档健康 ----------
# openGauss 内核无 pg_stat_archiver 视图；改用 archive_status 下 .ready 堆积量判断。
# .ready=待归档，archive_command 成功(exit 0)后内核改名为 .done；持续堆积即归档失败/滞后。
# 阈值与 §17.2.3 archive_check.sh 对齐（WARN≥3 / CRIT≥10）。需 monitor.sh 运行用户可读 $PGDATA。
ASTAT_DIR=""
if   [[ -d "${PGDATA:-}/pg_xlog/archive_status" ]]; then ASTAT_DIR="${PGDATA}/pg_xlog/archive_status"
elif [[ -d "${PGDATA:-}/pg_wal/archive_status"  ]]; then ASTAT_DIR="${PGDATA}/pg_wal/archive_status"
fi
if [[ -z "$ASTAT_DIR" ]]; then
    warn "archive_status dir not found under \$PGDATA=${PGDATA:-unset} (check PGDATA / monitor.sh run-user perms)"
else
    READY=$(find "$ASTAT_DIR" -maxdepth 1 -name '*.ready' -type f 2>/dev/null | wc -l)
    [[ "${READY:-0}" -ge 10 ]] && crit "WAL archive backlog: ${READY} .ready in $ASTAT_DIR (see /vastbase/log/wal_archive.log)"
    [[ "${READY:-0}" -ge 3 && "${READY:-0}" -lt 10 ]] && warn "WAL archive backlog: ${READY} .ready in $ASTAT_DIR"
fi

# ---------- 8. 备份哨兵 ----------
# 避免每日备份窗口前误报：只有超过预期完成小时后，仍未生成 BACKUP.OK，才判 CRITICAL。
# 用 date +%-H 去掉前导零，避免 08/09 被 bash 当八进制解析报错。
BACKUP_DEADLINE_HOUR=${BACKUP_DEADLINE_HOUR:-6}
if [[ ! -f "/vastbase/backup/$(date +%F)/BACKUP.OK" ]]; then
    [[ "$(date +%-H)" -ge "$BACKUP_DEADLINE_HOUR" ]] && crit "today's BACKUP.OK missing after ${BACKUP_DEADLINE_HOUR}:00"
fi

# ---------- 9. 异地备份 ----------
if ! ssh_sys $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
       "test -f ${REMOTE_DIR}/$(date +%F)/BACKUP.OK" 2>/dev/null; then
    warn "remote BACKUP.OK missing on ${REMOTE_HOST}"
fi

# ---------- 10. License 剩余天数 ----------
# monitor.sh 每 5 分钟执行，不直接调用 license_check.sh 连库；读取每日 09:00 生成的缓存即可。
# 契约：license_check.last 中需包含形如 remaining=124d 的 token；§3.5 的 license_check.sh 已按该格式输出。
# 关键：必须检查缓存新鲜度。若 license cron 静默失效，不能长期信任冻结的旧 remaining 值。
LIC_CACHE=/vastbase/log/license_check.last
LIC_CACHE_MAX_AGE_H=${LIC_CACHE_MAX_AGE_H:-36}   # 日检 09:00 跑；正常 <24h，超 36h 视为巡检失效
LEFT=""
if [[ -f "$LIC_CACHE" ]]; then
    # 缓存过期（license cron 可能已停或写入失败）→ 不再解析旧 remaining 值。
    if [[ -n "$(find "$LIC_CACHE" -mmin +$((LIC_CACHE_MAX_AGE_H*60)) 2>/dev/null)" ]]; then
        warn "license cache stale (> ${LIC_CACHE_MAX_AGE_H}h); check license_check cron"
    else
        LEFT=$(grep -oE 'remaining=[0-9]+d' "$LIC_CACHE" | grep -oE '[0-9]+' | head -1)
        [[ -z "$LEFT" ]] && warn "license cache unreadable; missing remaining=NNd token"
    fi
else
    warn "license cache missing; check license_check cron"
fi
if [[ -n "$LEFT" ]]; then
    [[ "$LEFT" -le 7  ]] && crit "license ${LEFT}d remaining"
    [[ "$LEFT" -le 30 && "$LEFT" -gt 7 ]] && warn "license ${LEFT}d remaining"
fi

# ---------- 输出与低噪声落盘 ----------
# monitor.log 只记录：异常、告警持续、状态翻转、恢复 OK。OK→OK 不落盘。
LAST=$(cat "$STATE_FILE" 2>/dev/null || echo -1)

if [[ $LEVEL -ne 0 || "$LEVEL" != "$LAST" ]]; then
    {
        echo "===== $(date '+%F %T') $(hostname) (level=$LEVEL) ====="
        if [[ ${#ALERTS[@]} -eq 0 ]]; then
            if [[ "$LAST" = "-1" ]]; then echo "all OK (initial)"; else echo "all OK (recovered)"; fi
        else
            printf '%s\n' "${ALERTS[@]}"
        fi
    } >> "$MON_LOG"
fi
printf '%s\n' "$LEVEL" > "$STATE_FILE" 2>/dev/null || true

# stdout 仍按原样输出，给交互执行、cron 邮件或外部监控采集。
echo "===== $(date '+%F %T') $(hostname) ====="
if [[ ${#ALERTS[@]} -eq 0 ]]; then
    echo "all OK"
else
    printf '%s\n' "${ALERTS[@]}"
fi
exit $LEVEL
```

#### 18.5.1 现场误报修复说明

现场原脚本执行时曾出现：

```text
[CRITICAL] 1 long transaction(s) > 30min
```

进一步查询 `pg_stat_activity` 后确认，该会话为 VastBase 内部 WLM 后台线程：

```text
application_name = workload
client_addr      = NULL
state            = active
query            = WLM fetch collect info from data nodes
```

这类线程不是客户端业务事务，不能作为“业务长事务”告警。修订后的长事务 SQL 同时要求：

```sql
state = 'active'
AND xact_start IS NOT NULL
AND client_addr IS NOT NULL
AND application_name NOT IN ('workload','WLMmonitor','WLMarbiter','WDRSnapshot')
```

因此同一现场复跑后输出：

```text
===== 2026-06-16 18:25:16 kylin-vastbaseg100 =====
all OK
```

如后续现场出现新的内部后台 `application_name`，不要直接放宽为 `state <> 'idle'` 全量统计，应先用下面 SQL 确认来源，再追加到白名单：

```sql
SELECT pid,
       usename,
       application_name,
       client_addr,
       state,
       xact_start,
       query
FROM pg_stat_activity
WHERE state <> 'idle'
  AND xact_start IS NOT NULL
  AND NOW()-xact_start > INTERVAL '10 minutes'
ORDER BY xact_start;
```

#### 18.5.2 监控日志与轮转

日常不建议把每个健康项都输出到日志。监控脚本最忌讳日志里全是 `OK`，真实异常反而被噪声淹没。推荐策略是：

- **stdout 每次输出**：便于手工执行、cron 邮件、外部平台采集。
- **`monitor.log` 只记异常与状态翻转**：异常必记，恢复 OK 也记；连续 OK 不记。
- **全量明细只在排障时开 trace**：不要作为常态日志。

补充两个生产约束：

- `BACKUP.OK` 不是从 00:00 开始立即检查，而是由 `BACKUP_DEADLINE_HOUR` 控制，默认 06:00 之后仍不存在才告警。若现场全量备份完成时间晚于 06:00，应在 `backup.env` 或 crontab 环境中设置 `BACKUP_DEADLINE_HOUR=8` 等现场值。
- `monitor.sh` 读取 `/vastbase/log/license_check.last` 时依赖 `license_check.sh` 输出中存在 `remaining=NNd`。§3.5 的脚本已按该契约输出，例如 `license expire=... remaining=124d (src=sql)`；如后续改造 license 脚本，需同步保留该 token 或修改本节解析逻辑。
- `monitor.sh` 同时检查 `license_check.last` 的 mtime：默认 `LIC_CACHE_MAX_AGE_H=36`，超过 36 小时即视为 license 日检失效并 WARN，不再解析旧的 `remaining=NNd`。这个闸用于兜底 crontab 写错、`mailx`/MTA 问题、SQL 连接失败或脚本权限变更等导致的静默失效。

建议配置 logrotate，避免 `monitor.log` 无限增长：

```bash
cat > /etc/logrotate.d/vastbase-monitor <<'EOF'
/vastbase/log/backup/monitor.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    copytruncate
}
EOF
```

按需排查“该报没报 / 不该报却报”时，用临时 trace：

```bash
bash -x /vastbase/scripts/monitor.sh \
  2>/vastbase/log/backup/monitor.trace.$(date +%F_%H%M).log
```

trace 文件中会记录每条 SQL、变量赋值和判断分支，用完即可清理，不建议长期保留。

#### 18.5.3 cron 配置

推荐以 `vastbase` 用户每 5 分钟执行。脚本内部已使用绝对路径 `source /vastbase/scripts/backup.env`，避免 cron 环境下 `PATH`、`HOME`、`.pgpass` 行为不一致。

不要在 crontab 里写多行复合命令。cronie 按行解析，不支持用反斜杠把一条任务拆成多行；同时 cron 默认用 `/bin/sh` 执行命令，`[[ ... ]]` 这类 bash 语法不应直接写进 crontab。推荐把邮件逻辑放进 wrapper。

> 前置依赖：`monitor_cron.sh` 中的 `mail` 需要系统已安装 `mailx`（或等效 mail 命令）并配置可用的本机 MTA/SMTP 转发；第 9 项异地备份检查还依赖 `backup.env` 中 `REMOTE_USER`/`REMOTE_HOST`/`REMOTE_DIR` 和 SSH 免密或受控密钥可用。若现场统一接入 Zabbix/Prometheus，可不启用邮件 wrapper，仅采集 `monitor.sh` 的退出码。

`/vastbase/scripts/monitor_cron.sh`：

```bash
#!/bin/bash
set -uo pipefail

out=$(/vastbase/scripts/monitor.sh)
ec=$?

# 只对 CRITICAL 直接发邮件；WARN 由 monitor.log 或统一监控平台承接。
if [ "$ec" -eq 2 ]; then
    printf '%s\n' "$out" | mail -s "[VastBase CRIT] $(hostname)" ops@example.com
fi

# 不把 monitor.sh 的非 0 退出码直接交给 cron，避免 cron 自带邮件与脚本邮件重复。
exit 0
```

落地：

```bash
chmod 750 /vastbase/scripts/monitor_cron.sh
```

crontab 只保留单行任务：

```cron
# 每 5 分钟检查；CRITICAL 立即邮件，WARN 只由 monitor.log 记录状态变化/异常。
*/5 * * * * /vastbase/scripts/monitor_cron.sh

# License 到期检查每天 09:00 单独执行一次，monitor.sh 只读取 /vastbase/log/license_check.last。
0 9 * * * /vastbase/scripts/license_check.sh > /vastbase/log/license_check.last 2>&1
```

如需要把 WARN 也发邮件，可在 wrapper 中把 `[ "$ec" -eq 2 ]` 改为 `[ "$ec" -ge 1 ]`，但生产上建议先接入统一告警平台，避免邮件风暴。

接入 Zabbix / Prometheus 时：把 `exit $LEVEL` 当数值指标暴露即可，告警策略走平台规则。

---

## 19. 变更、升级与回滚流程

### 19.1 通用变更流程

1. 明确变更目标、影响范围、执行窗口、责任人和审批单号。
2. 变更前采集当前配置：`postgresql.conf`、`pg_hba.conf`、`systemd service`、防火墙规则、`sysctl`、`limits.conf`。
3. 完成逻辑备份或物理快照，确认可恢复。
4. 先在测试环境验证命令和回滚步骤。
5. 生产执行时实时记录命令输出。
6. 变更后执行验收清单，观察至少一个业务低峰/高峰周期。
7. 更新本文档与参数台账。

### 19.2 配置变更回滚模板

```bash
# 备份
cp -a $PGDATA/postgresql.conf $PGDATA/postgresql.conf.bak.$(date +%F_%H%M%S)
cp -a $PGDATA/pg_hba.conf     $PGDATA/pg_hba.conf.bak.$(date +%F_%H%M%S)

# 变更
$VB_GUC set -D $PGDATA -c "work_mem = 64MB"
$VB_CTL reload -D $PGDATA

# 验证
$VB_SQL -d postgres -p $PGPORT -U vbadmin -c "SHOW work_mem;"

# 回滚
cp -a $PGDATA/postgresql.conf.bak.YYYY-MM-DD_HHMMSS $PGDATA/postgresql.conf
$VB_CTL reload -D $PGDATA
```

### 19.3 升级前检查

- 确认版本升级路径由厂家支持；
- 阅读 release notes，重点关注兼容性、参数废弃、系统表变化、备份恢复工具变化；
- 完成全量备份和恢复验证；
- 记录扩展、FDW、dblink、存储过程、MySQL 兼容参数和源库 sql_mode；
- 准备回退包、旧版本二进制、旧配置和停机窗口；
- 升级后执行应用回归测试和 SQL 兼容性测试。

### 19.4 将 `/vastbase` 迁移到 LVM 逻辑卷（解决系统盘容量不足、为后续在线扩容铺路）

> **适用场景**：实例当前 `/vastbase`（程序 + 数据）落在容量很小的系统盘（如 `/dev/vda2`，且 `/` **不是** LVM、无法直接扩容）；新加了一块大容量裸盘（如 `/dev/vdc` 410G）。本节将 `/vastbase` 整体迁移到基于 `/dev/vdc` 的 LVM 逻辑卷上，**挂载路径仍保持 `/vastbase` 不变**，迁移后即可用 `lvextend + resize2fs` 在线扩容（见 §19.4.6）。
>
> **核心原则**：① 挂载路径保持 `/vastbase` 绝对不变——这样 systemd unit、`app` 软链、`pg_tblspc/<oid>` 表空间软链、`postgresql.conf` 里 `archive_command`/`log_directory` 等所有绝对路径都无需修改；② 全程 `rsync` 先复制、校验通过、确认实例能起来之后才删源，源目录留作回退；③ 这是 §1 红线级 `rm -rf` + 停库变更，须按 §19.1 走审批、备份、测试环境演练。

#### 19.4.1 迁移前确认（务必逐项核对）

> **执行身份**：本节及 §19.4 后续命令除注明外均**以 root 执行**（wipefs 探测块设备、systemctl、LVM、fstab 均需 root；vastbase 用户执行 `wipefs -n` 报 `Permission denied` 属预期）。凡需数据库环境变量的命令，一律经 `su - vastbase <<'EOF'` 进入 vastbase 会话**内部** source，**严禁在 root 交互 shell 里 source backup.env**（红线原因见本节末警示框）。

```bash
# 1) 数据量必须远小于目标卷容量（du 用 -x 不跨文件系统，避免把 /vastbase 下其它挂载点算进来）
du -shx /vastbase

# 2) 目标盘是干净裸盘、无分区无文件系统（确认 vdc 无 FSTYPE/无挂载，勿误操作系统盘）
lsblk -f /dev/vdc
wipefs -n /dev/vdc          # dry-run，确认无残留签名；有残留再评估是否 wipefs -a

# 3) SELinux 状态（Kylin V10 常为 Enforcing，迁移后需 restorecon）
getenforce

# 4) 确认托管本实例的 systemd unit 名（本文为 vastbase；ExecStart 指向 -D /vastbase/data）
systemctl list-units --type=service | grep -iE 'vast|gauss'
systemctl cat vastbase | grep -E 'ExecStart|Restart|Type'

# 5) ★库外表空间排查（关键）：本过程只迁移 /vastbase 内的内容。
#    若实例有位于 /vastbase 之外的表空间（spclocation 不以 /vastbase 开头），
#    它们不在本次迁移范围内；如它们也落在拥挤的系统盘上，须另行规划单独迁移/扩容。
su - vastbase <<'EOF'
source /vastbase/scripts/backup.env
vb_sql postgres -c "SELECT spcname, pg_tablespace_location(oid) AS loc FROM pg_tablespace WHERE pg_tablespace_location(oid) <> '' ORDER BY 1;"
EOF
# 判读：loc 为相对路径（不带前导 /，如 tbs_xxx）= 库内相对表空间（$PGDATA/pg_location 下），
#       随 /vastbase 一并迁移，无需额外处理；loc 为 /vastbase 之外的绝对路径 = 库外表空间，
#       不在本流程内，须另案处理（见 §19.4.7）。
# 注意：location 名与 spcname 不一致（现场实例：tbs_reservation → tbs_preservation）属历史
#       登记事实，记录台账即可，严禁 rename 目录“对齐”——目录名是 catalog 登记的实际位置，
#       文件系统层改名即表空间报废（rm/mv 不经过 catalog 任何保险）。

# 6) 若本机为主备集群成员，停库迁移须与备库/集群管理协调；单机实例按本节直接执行。

# 7) ★采集迁移前逐库表计数快照，作为 §19.4.5 验收基线
#    （文件名带 pre 与时分秒——pre/post 同日生成，仅带日期会互相覆盖）
su - vastbase <<'EOF'
source /vastbase/scripts/backup.env
EXCL="'postgres','template0','template1','vastbase'"
for db in $(vb_sql postgres -At -c \
  "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ($EXCL) ORDER BY 1"); do
  n=$(vb_sql "$db" -At -c "SELECT count(*) FROM pg_stat_user_tables;")
  echo "$db $n"
done | sort > /tmp/tablecount_pre_$(date +%F_%H%M%S).txt
column -t /tmp/tablecount_pre_*.txt
EOF
```

> **★严禁在 root 的交互 shell 里 `source backup.env`（现场事故复盘）**：backup.env 含 `export LD_LIBRARY_PATH=$GAUSSHOME/lib:...`，会污染 root 环境。root 执行 `su` 时 ruid==euid（非 secure-execution 模式），动态链接器**会尊重 LD_LIBRARY_PATH**——su 打开会话经 PAM `dlopen` 一串模块，模块依赖的 libssl/libcrypto 等被解析到 VastBase 自带的不兼容版本，dlopen 失败即报 `su: cannot open session: Module is unknown`（现场实测；同类污染打在 ssh/rsync 上即 §10.3.1 记录的 `OPENSSL_1_1_1f not found`）。另一半坑：root **不** source 时，`su - vastbase -c "$VB_SQL ..."` 这种双引号写法会在 root 外层 shell 展开 `$VB_SQL` 为空串，命令退化为 `-bash: -d: command not found`。两坑同源同解：凡需 DB 环境变量，一律用本节的 `su - vastbase <<'EOF'` heredoc、在 vastbase 会话内部 source（与 §6 vbadmin 参数一节写法一致）。若已误 source：`unset LD_LIBRARY_PATH` 或退出重登——迁移窗口内 root shell 必须保持干净，后续 systemctl/lvm/rsync 都在这个 shell 里跑。
>
> **为什么不能直接 `mv /vastbase` 后手动 `mount` 就完事**：① 不写 `/etc/fstab`，重启后挂载丢失、`/vastbase` 退回系统盘空目录，实例起不来；② `chown` 若在挂载前做，会被新文件系统根目录覆盖；③ `mv ./*` 匹配不到隐藏文件，且跨文件系统 `mv` 是“拷一个删一个”，中断即两边俱损、源被破坏。本节用 `rsync -aAXH` + 后置 `chown` + fstab(UUID) 规避这三类问题。

#### 19.4.2 停库并加 systemd 防反拉安全闸（关键）

本文 `vastbase.service` 为 `Type=forking` + `Restart=on-failure`，且 `ExecStart` 的 `vb_ctl` 二进制就在被迁移的 `/vastbase/app` 上。迁移期间若实例被 systemd 反拉到“半迁移/空”的 `/vastbase`，会造成数据不一致（参见修订记录 v1.22 的现场事故）。因此：

```bash
# 以 root 执行
systemctl stop vastbase            # 主动停止——不会触发 Restart=on-failure
sleep 5

# 确认彻底停止、无残留进程、无占用
systemctl is-active vastbase || true
ps -ef | grep -iE 'gaussdb|vb_ctl|om_monitor' | grep -v grep
fuser -m /vastbase 2>/dev/null     # 应无输出

# ★加保险：迁移窗口内屏蔽 unit，杜绝任何来源把实例拉起到半迁移目录
systemctl mask vastbase
```

> 切勿在本流程里用 `vb_ctl stop` 绕过 systemd 停库——systemd 会视为主进程异常退出并按 `Restart=on-failure` 立即反拉。统一用 `systemctl stop` + `systemctl mask`。

#### 19.4.3 创建 LVM 并在临时挂载点用 rsync 复制（源目录全程不动）

```bash
# 1) 建 PV / VG / LV（vg、lv 名按现场命名规范；此处整盘一个卷最简单稳妥）
pvcreate /dev/vdc
vgcreate vgdata /dev/vdc
lvcreate -n lvvastbase -l 100%FREE vgdata

# 2) 建文件系统。-m 1 把 ext4 默认 5% 的保留块降到 1%，410G 上可省回约 16G。
#    （§2.8 推荐 XFS；如本机标准为 XFS，则用 mkfs.xfs /dev/vgdata/lvvastbase，
#     后续在线扩容相应改为 xfs_growfs，其余流程一致。本例沿用现状 ext4。）
mkfs.ext4 -m 1 /dev/vgdata/lvvastbase

# 3) 先挂到临时点，rsync 整目录复制
#    -a 归档(权限/属主/时间/软链/递归)，-A ACL，-X xattr，-H 硬链接，--numeric-ids 按数字 UID/GID 保权属
mkdir -p /mnt/vbnew
mount /dev/vgdata/lvvastbase /mnt/vbnew
rsync -aAXH --numeric-ids --info=progress2 /vastbase/ /mnt/vbnew/
```

> 注意 `rsync` 源写 `/vastbase/`（带末尾斜杠）= 复制目录“内容”到目标，避免多套一层 `/mnt/vbnew/vastbase`。`app -> /vastbase/app_29407` 这类软链按字面复制即可，因目标路径仍是 `/vastbase`，软链解析不变。

#### 19.4.4 校验一致后切换挂载点

```bash
# 1) 容量与文件清单比对（diff 排除 ext4 自带的 lost+found，无输出即一致）
du -sx /vastbase /mnt/vbnew
diff <(cd /vastbase && find . | sort) \
     <(cd /mnt/vbnew && find . -path ./lost+found -prune -o -print | sort)

# 2) 卸临时点，源改名保留作回退，建正式空挂载点
umount /mnt/vbnew
mv /vastbase /vastbase_old
mkdir /vastbase

# 3) 写 fstab（用 UUID 最稳，避免设备名漂移；noatime 对数据库有利）
UUID=$(blkid -s UUID -o value /dev/vgdata/lvvastbase)
echo "UUID=$UUID  /vastbase  ext4  defaults,noatime  0 0" >> /etc/fstab
# 用 fstab 挂载，同时验证 fstab 写对了（写错这里就会报错，早暴露）
mount /vastbase
findmnt /vastbase          # 确认来源为 /dev/mapper/vgdata-lvvastbase

# ★让 systemd 重新生成 mount 单元并对 fstab 做静态体检（本机 fstab 头注释亦要求 daemon-reload；
#   不做则 systemd 视图里没有 vastbase.mount，依赖排序与状态展示不完整）
systemctl daemon-reload
findmnt --verify           # 期望：Success, no errors or warnings detected
systemctl status vastbase.mount --no-pager   # Loaded: (/etc/fstab; generated)，Active: active (mounted)

# 4) ★挂载之后再还原根目录属主/权限（挂载前的 chown 会被新卷根目录覆盖）
#    原 /vastbase 为 750（drwxr-x---），按原状还原
chown vastbase:dbgrp /vastbase
chmod 750 /vastbase
# 抽查内部关键目录属主仍为 vastbase:dbgrp、data 仍为 700
ls -ld /vastbase /vastbase/app /vastbase/data

# 5) SELinux 为 Enforcing 时还原安全上下文
[ "$(getenforce)" = "Enforcing" ] && restorecon -Rv /vastbase
```

#### 19.4.5 解屏蔽、起库、验收

```bash
systemctl unmask vastbase
systemctl start vastbase
systemctl status vastbase --no-pager

# 实例侧验收（source 在 vastbase 会话内做，勿在 root shell source——见 §19.4.1 红线）
su - vastbase <<'EOF'
source /vastbase/scripts/backup.env
$VB_CTL status -D /vastbase/data
vb_sql postgres -c "SELECT version();"
vb_sql postgres -c "SELECT pg_is_in_recovery();"
EOF

# ★采集迁移后逐库表计数快照，与 §19.4.1 第 7 步的 pre 快照比对（diff 无输出即一致）
su - vastbase <<'EOF'
source /vastbase/scripts/backup.env
EXCL="'postgres','template0','template1','vastbase'"
for db in $(vb_sql postgres -At -c \
  "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ($EXCL) ORDER BY 1"); do
  n=$(vb_sql "$db" -At -c "SELECT count(*) FROM pg_stat_user_tables;")
  echo "$db $n"
done | sort > /tmp/tablecount_post_$(date +%F_%H%M%S).txt
diff /tmp/tablecount_pre_*.txt /tmp/tablecount_post_*.txt && echo "TABLECOUNT MATCH"
EOF

# 抽查业务库可读、表空间可访问（按现场库/表替换；vsql 交互 \l、\db、业务表 count 皆可）
# 归档健康：archive_mode=on 时复核 archive_status 无持续堆积的 .ready（参见 §17.2.3）；
#   archive_mode=off（如现场 vbdb01）记“不适用”，并把「无 PITR、RPO=逻辑备份间隔」作为
#   风险项写入变更单——迁移后新卷余量充足即具备启用条件，按 §17 另开窗口补齐。

df -h /vastbase            # 确认容量已是新卷（数百 G）
```

**起库验收通过后、回收旧目录前，还须完成以下三步**：

```bash
# 1) ★手动执行一次完整备份，验证备份链路（本地发布 + 异地 rsync + 保留期清理）在新卷上无恙
#    ——同时满足 §1 红线“rm -rf 前有可用备份”。注意：当日 cron 已产出的备份目录若改名保留
#    （如 <date>.old），改名后不再匹配保留期清理的日期 glob、会永久滞留，观察期结束后须与
#    /vastbase_old 一并手动回收。
su - vastbase -c "/vastbase/scripts/db_backup.sh"

# 2) ★推荐在变更窗口内做一次受控重启，验证 fstab 持久性、开机自动挂载与实例自启
reboot
# 重启后核验：
last -x reboot shutdown | head -3
findmnt /vastbase                          # 仍来自 /dev/mapper/vgdata-lvvastbase
systemctl status vastbase --no-pager       # active (running)，由开机自动拉起
# ★以数据目录内的 pg_log 判定干净启停（易失 journal 重启即清空，不可作凭据）：
su - vastbase -c "grep -iE 'was shut down|not properly|database system' \
  /vastbase/data/pg_log/postgresql-$(date +%F)*.log | head -5"
# 期望：database system was shut down at <时间>（干净关闭）+ ready to accept connections。
# 若出现 not properly shut down / redo 恢复字样：实例未被正常停止，记入变更单并排查停库路径。

# 3) 观察至少一个业务高峰/低峰周期（建议一两天）：
#    盯 df -h /vastbase、journalctl -u vastbase、pg_log 错误、备份 cron 正常产出。
```

**观察期满、以上全部通过后**，再回收旧数据释放系统盘空间：

```bash
rm -rf /vastbase_old                  # §1 红线级 rm -rf，确认无误、有备份后再执行
rm -rf /vastbase/backup/<date>.old    # 如有手工改名保留的迁移前备份目录，一并回收
df -h /                               # 系统盘占用应明显回落
```

**回退方案**（在删除 `/vastbase_old` 之前任何环节出问题，均可快速回退）：

```bash
systemctl stop vastbase 2>/dev/null; systemctl mask vastbase
umount /vastbase 2>/dev/null
rmdir /vastbase 2>/dev/null
# 删除本次新增的 fstab 行（按 UUID 精确删除，勿误删其它行）
sed -i "\|UUID=$UUID .*/vastbase .*|d" /etc/fstab
mv /vastbase_old /vastbase            # 恢复原系统盘上的目录
systemctl unmask vastbase
systemctl start vastbase              # 回到迁移前状态
```

#### 19.4.6 迁移后的在线扩容（本次迁移要解决的核心诉求）

迁移到 LVM 后，将来 `/vastbase` 空间不足时无需停库即可扩容：

```bash
# 方式 A：给同一 VG 再加一块新盘（如 /dev/vdd），扩 VG 后扩 LV
pvcreate /dev/vdd
vgextend vgdata /dev/vdd
lvextend -l +100%FREE /dev/vgdata/lvvastbase
resize2fs /dev/vgdata/lvvastbase        # ext4 在线扩容；若用 XFS 则 xfs_growfs /vastbase

# 方式 B：底层 vdc 由虚拟化平台/云在线扩盘后，先让内核识别新容量再扩 PV
#   先确认新容量已被内核看到（如未识别可 echo 1 > /sys/block/vdc/device/rescan）
pvresize /dev/vdc
lvextend -l +100%FREE /dev/vgdata/lvvastbase
resize2fs /dev/vgdata/lvvastbase        # XFS 用 xfs_growfs /vastbase

df -h /vastbase                          # 确认容量已增长
```

#### 19.4.7 可选优化与边界说明

- **是否拆分多卷**：本节“整个 `/vastbase` 一个 LV”最简单稳妥，先用足够。若将来对 IO 隔离/独立快照有需求，可把 `data`、`arch`、`backup` 拆成独立 LV 分别挂载、分别扩容，但会改变挂载结构、复杂度上升，需相应调整本节流程与 fstab。多卷布局的现场落地实例见 §19.4.9（nfs 主机：lvnfs + lvbackup + VG 留余量）与 §19.4.10（harbor：lvharbordata + lvdocker；工作节点：lvdocker，均留 VG 余量）。
- **库外表空间不在本流程内**：§19.4.1 第 5 步查出的、位于 `/vastbase` 之外的表空间不会被本过程迁移；若它们也在拥挤的系统盘上，需单独制定停库迁移（移动目录 + 重建 `pg_tblspc/<oid>` 软链 + 修正 `spclocation`）方案，不要与本节混做。
- **快照备份**：迁移并稳定后，LVM 快照可作为变更前的快速回退点（注意 LVM 快照需 VG 预留空闲空间，且非数据库一致性备份，不能替代 §10/§17 的逻辑/物理备份）。
- **文件系统选择**：§2.8 推荐 XFS。本节为贴合现状示例用 ext4；若现场标准为 XFS，建表与扩容命令相应替换（`mkfs.xfs` / `xfs_growfs`），其余流程不变。

#### 19.4.8 现场执行记录与经验（vbdb01，2026-07-08，本节首次实执行）

**结果**：`/vastbase`（18G，46817 个条目）成功迁移至 `/dev/vdc` 410G LVM 卷（vgdata/lvvastbase，ext4 `-m 1`），挂载路径保持 `/vastbase` 不变。`find` 清单 diff 零差异；迁移前后 16 个业务库逐库 `pg_stat_user_tables` 计数完全一致；受控重启后开机自动挂载 + 实例自启 + pg_log `database system was shut down at 2026-07-08 15:05:54`（干净关闭，时间线 5 无变化）；迁移后手动全量备份（16 库 + globals + 异地 rsync + 双端保留期清理）Failed jobs: 0。迁移后 `/vastbase` 使用率 5%（18G/403G），系统盘释放待观察期后回收 `/vastbase_old`。

**执行要点与判读经验**：

- `wipefs -n /dev/vdc` root 下**无输出即无残留签名**，可直接 `pvcreate` 而无需 `wipefs -a`；vastbase 用户执行报 `Permission denied` 属预期（探测块设备需 root）。
- `du -sx` 新旧两侧相差 1572KB（0.008%）：新旧 ext4 目录块分配差异所致（老文件系统目录经历过增删、块分配更碎）。**`find` 清单 diff 一致即为一致**，不必追查 du 差值。
- SELinux 为 Disabled 时，§19.4.4 第 5 步 restorecon 按条件写法自动跳过，无需动作。
- systemd 拉起时 vb_ctl 打印 `[EXECUTOR] WARNING: Failed to obtain environment ... $GAUSSLOG` / `Incorrect environment value`：systemd 不 source 用户 profile、unit 内仅注入 LD_LIBRARY_PATH 所致，vb_ctl 走默认路径后正常 `server started`——属**既有噪音**、与迁移无关。可选消音：unit drop-in 追加 `Environment=GAUSSLOG=/vastbase/log/gauss`（需重启服务生效，建议与其它需重启的变更合并窗口执行）。
- 迁移前后表计数快照务必按本版 pre/post + 时分秒命名——首执时两次快照同名（仅带日期）互相覆盖，靠人眼比对兜底，已在 §19.4.1/§19.4.5 修正。

**偏差项（如实记录；流程要求不变）**：

- §19.4.2 的 `systemctl mask` 安全闸本次被跳过（stop 后直接进入 LVM 操作，起库时直接 start 未经 unmask）。窗口短且无反拉来源，未造成后果，但该步针对修订记录 v1.22 现场事故而设，**下次执行必须照做**。

**衍生发现（均已另案跟进，不影响迁移结论）**：

- 迁移后手动备份日志出现约 50 秒“时间倒流”（15:02:34 的下一行为 15:01:45，文件 mtime 佐证）。顺藤定位为**虚拟化平台周期性时钟回拨**，波及全部虚机（含内网 NTP 源 harbor 自身）——完整现象、排查序列、定量证据与处置见 **§14.9**。对迁移结论无影响：备份 sha256/verify 全过，数据一致性验证与墙钟无关。
- 本实例 `archive_mode = off`（无 PITR，RPO = 每日逻辑备份间隔）。迁移前系统盘 88% 满或为未启用归档的历史原因；迁移后余量充足、`wal_level = hot_standby` 等前置参数齐备，仅差 `archive_mode = on` 一项（需重启），按 §17 另开窗口补齐并配套物理基础备份。
- 表空间 `tbs_reservation` 的 location 为 `tbs_preservation`（历史登记笔误），已记台账；**严禁 rename 目录“对齐”**（见 §19.4.1 第 5 步注意）。

#### 19.4.9 变体：NFS 导出目录迁移到 LVM（K8s PVC 后端存储；现场案例：nfs 主机，2026-07-08）

> **适用场景**：nfs 主机（10.120.0.33）的导出目录 `/opt/nfs/rancher` 是 K8s 集群（nfs-client-provisioner / `managed-nfs-storage` 存储类）全部 PVC 的后端存储（现场 13 个 PVC 目录、238M/1447 个条目，含 CAS/authx/admin-platform 等多套 Redis AOF、Kafka、ES、MinIO、formflow 上传件），原落在 60G 系统盘；新加 `/dev/vdc` 450G 裸盘。本节复用 §19.4 骨架（rsync 先复制 → 校验 → 切挂载 → fstab UUID → 留旧目录回退），但与数据库迁移有**三处本质差异**，直接照抄 §19.4.1~19.4.5 会出事：
>
> ① **「停库」的对应物是停 K8s 侧的写入方**——本机 nfs-server 只是通道（且为 `Type=oneshot`、无 `Restart=`，不存在 §19.4.2 的反拉问题、无需 mask），真正的写入进程在 K8s 节点上经 PVC 挂载，须将使用这些 PVC 的工作负载缩容到 0、让 kubelet 卸载 NFS 挂载。
> ② **核心风险不是 systemd 反拉，而是 NFS stale file handle**——NFS 文件句柄编码了服务端 fsid + inode，换底层文件系统后旧句柄**永久失效且不会自愈**；任何带着老挂载穿越迁移的客户端进程都会 ESTALE（本节末事故复盘即为实证）。
> ③ **数据量小、窗口由 K8s 缩/扩容主导**（238M rsync 秒级）；且 CAS（校园 SSO）的 Redis 在 PVC 之列——**缩容窗口 = SSO 中断窗口**，须安排业务低峰。
>
> **布局决策（§19.4.7 多卷拆分的落地实例）**：450G 不必给 238M 的导出独占。现场切两个 LV——`lvnfs`（100G，挂 `/opt/nfs/rancher`）+ `lvbackup`（200G，挂 `/backup`，顺带把 vbdb01 异地备份目标也迁出系统盘），VG 留空闲余量、谁涨扩谁。

**步骤 1：迁移前确认（对应 §19.4.1）**

```bash
# —— nfs 主机（root）——
du -shx /opt/nfs/rancher                 # 现场 238M
lsblk -f /dev/vdc ; wipefs -n /dev/vdc   # 无输出 = 干净裸盘
getenforce
systemctl cat nfs-server | grep -E 'Type|Restart' ; systemctl is-enabled nfs-server
cat /etc/exports ; showmount -e          # 记录导出与授权网段基线
ls -ldn /opt/nfs/rancher                 # 记录根目录属主/权限基线（现场 root:root 755）
# 注意：no_root_squash 环境下目录内混有 uid 1000/1001 等属主，rsync 必须 --numeric-ids
```

```bash
# —— K8s 侧（kubectl + jq；对应 §19.4.1 第 5 步“范围排查”，必须拿到完整清单）——
# 1) 指向本 NFS 的全部 PV → PVC 映射（现场 13 条，与导出下目录一一对应）
kubectl get pv -o json | jq -r '.items[] | select(.spec.nfs.server=="10.120.0.33")
  | "\(.spec.claimRef.namespace)/\(.spec.claimRef.name)\t\(.spec.nfs.path)"' | sort

# 2) 每个 PVC 被哪些 Pod 使用 → 反推要缩容的负载，记「ns / 负载 / 类型 / 原副本数」表（扩容依据）
kubectl get pods -A -o json | jq -r '.items[]
  | . as $p | .spec.volumes[]? | select(.persistentVolumeClaim)
  | "\($p.metadata.namespace)\t\($p.metadata.name)\t\(.persistentVolumeClaim.claimName)"' \
  | grep -Ff <(kubectl get pv -o json | jq -r '.items[]
      | select(.spec.nfs.server=="10.120.0.33") | .spec.claimRef.name')

# 3) ★★nfs-client-provisioner 必须单列——它不经 PVC，在 Deployment 里直接以 nfs 卷
#    挂载导出根目录（容器内挂 /persistentvolumes），“缩所有挂 PVC 的负载”永远覆盖不到它
kubectl get deploy -A | grep -iE 'nfs.*(provisioner|client)'
```

```bash
# —— 迁移前快照基线（对应 §19.4.1 第 7 步）——
# ★快照必须写持久目录——本流程步骤 5 的受控重启先于收尾比对，而 Kylin V10 /tmp 为 tmpfs
#   重启即清（§19.4.10 harbor 首执实证：pre 快照被重启清空、比对落空），严禁写 /tmp
mkdir -p /root/migrate_evidence
cd /opt/nfs/rancher
find . | sort > /root/migrate_evidence/nfslist_pre_$(date +%F_%H%M%S).txt
du -s --block-size=1 */ | sort > /root/migrate_evidence/nfsdu_pre_$(date +%F_%H%M%S).txt
```

**步骤 2：停写入方（缩容）→ 验证无残留挂载 → 停 nfs-server（对应 §19.4.2 安全闸）**

```bash
# K8s 侧：按清单缩 0——业务负载在先，★provisioner 单列且不可遗漏
kubectl -n <ns> scale deploy/<name> --replicas=0
kubectl -n <ns> scale statefulset/<name> --replicas=0
kubectl -n default scale deploy/nfs-client-provisioner --replicas=0

# ★★硬闸：全部节点必须无本 NFS 的残留挂载，未清零不得停服切盘（ansible 全网核查）
ansible -i ./hosts all -m shell -a "grep 10.120.0.33 /proc/mounts" -o
# rc=1（无输出）= 该节点干净；任何有 stdout 的节点 = 仍有挂载，回头找漏缩的负载

# nfs 主机：服务端确认无活动连接后停服
ss -tn state established '( sport = :2049 )'    # 应为空
systemctl stop nfs-server
fuser -m /opt/nfs/rancher 2>/dev/null            # 应无输出
```

> **★为什么残留挂载是硬闸（现场事故实证）**：现场 17:48 核查显示 10.120.0.41（k8s-worker02）仍有一条 `nfs-client-root` 挂载——正是漏缩的 nfs-client-provisioner——当时未按住、继续停服切盘。业务 pod 因扩容时全部重建而侥幸无恙；provisioner 老 pod 则带着失效句柄穿越了迁移，次日供给新 PVC 时精确踩雷（见本节末复盘）。NFS 硬挂载（hard）的行为是 hang 住重试而非报错，容易造成“没影响”的错觉——**句柄已死，只是还没人碰它**。

**步骤 3：建 LVM（多卷）并复制（对应 §19.4.3）**

```bash
pvcreate /dev/vdc
vgcreate vgdata /dev/vdc
lvcreate -n lvnfs    -L 200G vgdata      # 导出目录（238M 数据，200G 已很宽裕）
lvcreate -n lvbackup -L 200G vgdata      # vbdb01 异地备份目标，顺带迁出系统盘
mkfs.ext4 -m 1 /dev/vgdata/lvnfs
mkfs.ext4 -m 1 /dev/vgdata/lvbackup
vgs                                       # 确认 VG 留有空闲余量

mkdir -p /mnt/nfsnew
mount /dev/vgdata/lvnfs /mnt/nfsnew
rsync -aAXH --numeric-ids --info=progress2 /opt/nfs/rancher/ /mnt/nfsnew/   # 238M 秒级完成

mkdir -p /mnt/nfsbackupnew
mount /dev/vgdata/lvbackup /mnt/nfsbackupnew
rsync -aAXH --numeric-ids --info=progress2 /backup/ /mnt/nfsbackupnew/ 
```

**步骤 4：校验一致后切换挂载（对应 §19.4.4，含 daemon-reload）**

```bash
#nfs
diff <(cd /opt/nfs/rancher && find . | sort) \
     <(cd /mnt/nfsnew && find . -path ./lost+found -prune -o -print | sort)   # 无输出即一致

umount /mnt/nfsnew
mv /opt/nfs/rancher /opt/nfs/rancher_old
mkdir /opt/nfs/rancher

UUID_N=$(blkid -s UUID -o value /dev/vgdata/lvnfs)
echo "UUID=$UUID_N  /opt/nfs/rancher  ext4  defaults,noatime  0 0" >> /etc/fstab
mount /opt/nfs/rancher ; findmnt /opt/nfs/rancher
systemctl daemon-reload && findmnt --verify        # Success, no errors or warnings detected

chown root:root /opt/nfs/rancher && chmod 755 /opt/nfs/rancher   # 挂载后按基线还原根目录
ls -ld /opt/nfs/rancher /opt/nfs/rancher/*pvc* | head            # 抽查子目录属主随 rsync 保留
#[ "$(getenforce)" = "Enforcing" ] && restorecon -Rv /opt/nfs/rancher

# /backup → lvbackup 同法（rsync→diff→umount→mv 留旧→fstab→mount）；它无客户端挂载问题，随做随切
#海量数据库的异地备份
diff <(cd /backup && find . | sort) \
     <(cd /mnt/nfsbackupnew && find . -path ./lost+found -prune -o -print | sort)   # 无输出即一致

umount /mnt/nfsbackupnew
mv /backup /backup_old
mkdir /backup

UUID_B=$(blkid -s UUID -o value /dev/vgdata/lvbackup)
echo "UUID=$UUID_B  /backup           ext4  defaults,noatime  0 0" >> /etc/fstab
mount /backup ; findmnt /backup
systemctl daemon-reload && findmnt --verify        # Success, no errors or warnings detected

chown root:root /backup && chmod 755 /backup   # 挂载后按基线还原根目录
ls -ld /backup /backup/vbdb01         # 抽查子目录属主随 rsync 保留
ls -l /backup/vbdb01/
ls -l /backup/vbdb01/2026-07-08
#[ "$(getenforce)" = "Enforcing" ] && restorecon -Rv /opt/nfs/rancher
```

**步骤 5：受控重启 → 起服务 → 扩容恢复（对应 §19.4.5；顺序与数据库迁移不同——重启插在扩容之前，客户端全缩 0 时重启零感知，正好验证 fstab 持久性）**

```bash
reboot
# 重启后核验：
findmnt /opt/nfs/rancher ; findmnt /backup       # 均来自 /dev/mapper/vgdata-*
systemctl status nfs-server --no-pager           # active（enabled 随开机自启）
exportfs -v ; showmount -e localhost             # 导出与授权网段齐全

# 从任一 K8s 节点做手工挂载读写测试（比等 pod 起来再排错快）
ssh 10.120.0.40 "mkdir -p /mnt/t && mount -t nfs 10.120.0.33:/opt/nfs/rancher /mnt/t \
  && touch /mnt/t/.rwtest && rm -f /mnt/t/.rwtest && umount /mnt/t && echo RW-OK"

# K8s 侧按步骤 1 记录的副本数恢复：★provisioner 先起，再业务负载
kubectl -n default scale deploy/nfs-client-provisioner --replicas=1
kubectl -n <ns> scale deploy/<name> --replicas=<原值>        # 逐个恢复
kubectl get pods -A | grep -vE 'Running|Completed'            # 直到输出为空
```

**步骤 6：★动态供给功能验证（必做）**——业务 pod 全 Running 只证明**静态挂载**可用，不证明 provisioner 可用（现场正是这一步暴露了 ESTALE 事故）：

```bash
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pvc-migrate-test, namespace: default}
spec:
  accessModes: [ReadWriteMany]
  resources: {requests: {storage: 1Mi}}
  storageClassName: managed-nfs-storage
YAML
kubectl get pvc pvc-migrate-test -w    # 期望十几秒内 Bound；nfs 侧同步出现 default-pvc-migrate-test-* 新目录
kubectl delete pvc pvc-migrate-test
# 删除后到 nfs 侧确认目录是被删除还是改名 archived-*（取决于 StorageClass 的 archiveOnDelete），记入台账
```

**验收比对与观察（对应 §19.4.5 收尾）**：pod 全 Running 后在 nfs 主机重跑 find/du 快照与 pre 版比对（差异应仅为负载重启后的新写入；重点抽查 cas-server Redis 的 `appendonly.aof` 恢复持续增长、CAS 登录链路、formflow 上传可写）；次日核对 vbdb01 凌晨备份日志 `remote publish OK`（异地目标 `/backup` 已换底层盘、路径未变应无感，留证）。观察一两天后回收 `/opt/nfs/rancher_old` 与 `/backup_old`。

**回退方案**（删 `rancher_old` 之前任一环节出问题）：缩容全部相关负载（含 provisioner）→ `systemctl stop nfs-server` → `umount /opt/nfs/rancher` → 删本次 fstab 行 → `mv /opt/nfs/rancher_old /opt/nfs/rancher` → 起 nfs-server → 按清单扩容恢复。与 §19.4.5 回退等价。

**现场事故复盘：provisioner 漏缩 → ESTALE 的识别指纹与处置**

现场次日按步骤 6 验证动态供给：PVC `default/test` 长挂 Pending，provisioner 每 15~30 秒重试并报（failures 0→15 重试永不自愈）：

```
E0709 02:01:21 controller.go:761] error syncing claim "default/test":
  failed to provision volume with StorageClass "managed-nfs-storage":
  unable to create directory to provision new pv: mkdir /persistentvolumes: file exists
```

这条“目录已存在却建不了”的报错是 **ESTALE 在 nfs-client-provisioner 里的教科书指纹**，机理三步：① provisioner 容器把 NFS 导出根挂在容器内 `/persistentvolumes`，收到 PVC 后 Go 的 `os.MkdirAll` 先 `Stat` 新 PV 子目录——经由**迁移前的失效根句柄**返回 **ESTALE**（不是“不存在”）；② MkdirAll 把 Stat 失败当“不存在”，递归对 `/persistentvolumes` 本身 Stat → 仍 ESTALE；③ 于是尝试 `Mkdir("/persistentvolumes")`——该 syscall 解析的父目录是容器 overlay 根 `/`，挂载点目录当然已存在 → **EEXIST**（"file exists"）。死句柄不会自愈，唯一出路是重新 mount，对 pod 即重建：

```bash
kubectl -n default rollout restart deploy/nfs-client-provisioner
kubectl -n default get pod -l app=nfs-client-provisioner -w
# 新 pod Running 后：controller 对 Pending claim 的重试仍在队列中，无需动 PVC，
# 十几秒内自动转 Bound（现场实证：rollout 后 test 即 Bound）
```

**三条教训（固化为本节流程要求）**：① provisioner 不经 PVC 挂载，缩容清单必须**单列**（步骤 2 已内化）；② “逐节点无残留挂载”是**硬闸**不是巡检项，未清零不得停服切盘（本次被闯，靠业务 pod 全部重建侥幸兜底）；③ **ESTALE 指纹速查**——provisioner 报 `mkdir /persistentvolumes: file exists`、或任意 pod 报 `Stale file handle`：处置一律**重建持有老挂载的 pod**，不要去 NFS 服务端找原因。

**迁移后在线扩容实证（对应 §19.4.6，业务不停服）**：现场将 lvnfs 100G→200G，业务 pod 全程在线：

```bash
lvextend -L +100G /dev/vgdata/lvnfs
resize2fs /dev/mapper/vgdata-lvnfs     # on-line resizing，df -h 立即可见 197G
```

**余量提醒**：现场 lvnfs 扩至 200G 后 VG 仅剩 <50G 空闲——已扩不回缩，但**不宜再扩**：剩余空间留作紧急缓冲/LVM 快照；再要扩先加盘 `vgextend`（§19.4.6 方式 A）。

#### 19.4.10 变体：Harbor 主机（`/data` + `/var/lib/docker`）与 K8s 工作节点（`/var/lib/docker`）迁移到 LVM（现场案例：harbor / k8s-worker0x，2026-07）

> **适用场景**：harbor 主机（`/opt/harbor`，Harbor v2.7.0，`data_volume: /data`，docker `data-root: /var/lib/docker`）与 K8s 工作节点（Rancher/RKE1，docker 20.10.24，kubelet 等基础组件均为 docker 容器）的数据目录均落在 60G 系统盘（harbor 已 71%，`df` 可见 10 个 overlay merged 挂载与根盘同底）；两类主机均已新加干净裸盘：harbor `/dev/vdc` 450G、工作节点 `/dev/vdc` 200G。本节复用 §19.4 骨架（rsync 先复制 → 校验 → 切挂载 → fstab UUID + daemon-reload → 留旧目录回退 → 受控重启验证），**挂载路径保持 `/data`、`/var/lib/docker` 绝对不变**——harbor.yml、daemon.json、compose 文件、RKE 容器定义全部零改动。但与 §19.4（数据库）/§19.4.9（NFS）有**三处本质差异**，直接照抄会出事：
>
> ① **「停库」的对应物是「停托管单元/驱逐负载 + 停并屏蔽 docker」，反拉来源必须现场核实**——harbor 主机的 compose 栈由 `harbor.service`（Type=simple、Restart=on-failure、ExecStart=`docker-compose up`、ExecStop=`docker-compose down`）托管，**`docker-compose stop` 刚停完就被该单元整栈反拉**（2026-07-09 首执实证：stop 全部 done 后 `docker ps` 十个容器齐刷刷 "Up About a minute"——容器退出令前台 `up` 主进程异常退出、`Restart=on-failure` 重拉整栈，与 §19.4.2「禁 vb_ctl stop 绕过 systemd」同构）。正解是 **`systemctl stop harbor`**（走 ExecStop 干净 down；harbor-db 是 PostgreSQL，必须冷迁移）。工作节点侧先 `cordon + drain`（kubelet 本身是容器，停 docker 即停 kubelet，drain 未做完就停 docker = pod 硬杀）。之后 docker 一律 **stop + mask**；`docker.socket` 如存在须一并 stop + mask——只停 service 不停 socket，窗口内一条 `docker ps` 就会 socket-activate 拉起 dockerd（Kylin 的 docker 20.10 包**无 socket/containerd 独立单元**，stop 报 "not loaded" 属预期噪音）。这是本变体里 §19.4.2 安全闸的等价物，不许跳过（§19.4.8 偏差项前车之鉴——本次又跳过 mask，且窗口内真实发生了反拉）。
>
> ② **核心风险是 overlay2 的 `trusted.overlay.*` 扩展属性与残留 overlay/shm 挂载，而非 systemd 反拉或 ESTALE**——镜像层的白化/不透明目录标记存放在 `trusted.*` xattr 命名空间（仅 root 可读写），rsync 必须 **root 执行 + `-aAXH --numeric-ids`**，丢了 opaque 标记 = 层内容错乱、容器起来后被删文件“复活”。且复制前 **`findmnt -R /var/lib/docker` 必须为空（硬闸，等价 §19.4.9 残留挂载硬闸）**：docker 停得不彻底时残留的 overlay merged / shm 挂载会让 rsync 把“联合视图”当真实数据拷走——目录膨胀数倍且层结构报废。未清零不得开拷。
>
> ③ **harbor 窗口与工作节点窗口严禁重叠，工作节点必须逐台滚动**——drain 会让 pod 在其它节点重建、需从 harbor 拉镜像；harbor 停机期间全网 pull 必失败。执行顺序固定为：**先逐台完成全部工作节点（harbor 在线兜底），最后单独窗口做 harbor（集群静稳、无调度发生）**。工作节点每次只做一台，drain 前确认其余节点容量足以接住负载。

**布局决策（延续 §19.4.7/§19.4.9 多卷 + VG 留余量原则）**：

| 主机 | 裸盘 | VG | LV 划分 | 挂载点 | 余量 |
|------|------|----|---------|--------|------|
| harbor | vdc 450G | vgdata | lvharbordata 300G（原设计 200G，现场当场 `lvextend +100G`） | `/data`（registry blob 主增长点） | **<50G 空闲**——已低于余量原则，再扩须先 `vgextend` 加盘 |
| | | | lvdocker 100G | `/var/lib/docker` | |
| k8s-worker0x | vdc 200G | vgdata | lvdocker 150G | `/var/lib/docker` | ~50G 空闲（应急/快照缓冲） |

> 工作节点 `/var/lib/kubelet`、`/var/lib/rancher` **不在本次迁移范围**（占用大头是 docker 的镜像层/容器可写层/json-file 日志）；harbor 侧 `/data/database` 为 harbor-db（PostgreSQL）数据目录、`/data/registry` 为镜像 blob，随 `/data` 整体冷迁。

---

**A. Harbor 主机（`/data` + `/var/lib/docker` 双目录）**

**步骤 A1：迁移前确认（对应 §19.4.1，root 执行）**

```bash
# 1) 数据量 vs 目标卷（-x 不跨文件系统）
du -shx /data /var/lib/docker

# 2) 目标盘为干净裸盘（现场 lsblk -f 已示 vdc 无 FSTYPE 无挂载）
lsblk -f /dev/vdc
wipefs -n /dev/vdc            # 无输出 = 无残留签名，可直接 pvcreate

# 3) SELinux 状态（Kylin V10）
getenforce

# 4) ★识别 compose 栈的 systemd 托管单元（就是 §19.4.1 第 4 步「确认托管 unit」；
#    本变体首执漏了这步 → docker-compose stop 被 harbor.service 反拉）
systemctl list-unit-files | grep -iE 'harbor|docker'
systemctl cat harbor 2>/dev/null | grep -E 'ExecStart|ExecStop|Restart|Type'
#    现场：harbor.service Restart=on-failure —— 停栈必须 systemctl stop harbor

# 5) 服务基线：compose 栈 10/10 healthy、docker 关键指纹（迁移后逐项比对）
cd /opt/harbor && docker-compose ps
docker info | grep -E 'Images|Containers|Storage Driver|Docker Root Dir'
systemctl is-enabled docker harbor         # 均应 enabled——重启后靠它自启
#    （containerd 独立单元在 Kylin docker 20.10 包中不存在，报错属预期）

# 6) ★工具前置：rsync 未预装则现在装，勿等停机窗口内临时 yum（首执教训 +1 分钟停机）
command -v rsync || yum install -y rsync

# 7) 权限基线（切挂载后按此还原两个根目录；/data 下混有 uid 999/10000 等
#    容器内用户属主，rsync 必须 --numeric-ids）
ls -ldn /data /var/lib/docker

# 8) ★迁移前 find 快照基线（对应 §19.4.1 第 7 步；pre + 时分秒命名防覆盖）
#    ★★路径必须持久目录——Kylin V10 的 /tmp 是 tmpfs（df 可见），本流程含受控重启，
#    写 /tmp 重启即清、post/pre 比对落空（2026-07-09 首执实证，证据链断档）
mkdir -p /root/migrate_evidence
cd /data           && find . | sort > /root/migrate_evidence/harbordata_pre_$(date +%F_%H%M%S).txt
cd /var/lib/docker && find . | sort > /root/migrate_evidence/harbordocker_pre_$(date +%F_%H%M%S).txt
```

> **变更单备注两条**：① harbor 主机兼内网 NTP 上游（§14.9），窗口内含受控重启，下游 chronyd 短暂失源可自愈，报备即可；② harbor 停机期间全网镜像拉取不可用，须业务低峰，且确认**当窗无任何工作节点在 drain/扩容**（差异③）。

**步骤 A2：停写入方 → 停并屏蔽 docker → 残留挂载硬闸（对应 §19.4.2）**

```bash
# 1) 冷停 compose 栈——必须走 systemd 托管单元，严禁 docker-compose stop 绕过
#    （Restart=on-failure 会整栈反拉，首执实证；与 §19.4.2 禁 vb_ctl stop 同理）
systemctl stop harbor
docker ps -q | wc -l                      # 必须为 0；不为 0 = 被反拉/漏停，回头查托管单元

# 2) 停 docker 并 mask 双保险（docker.socket / containerd 单元如存在一并处理；
#    Kylin docker 20.10 无此二单元，"not loaded" 报错属预期噪音）
systemctl stop docker.socket docker.service containerd 2>/dev/null; systemctl stop docker
systemctl mask docker.service; systemctl mask docker.socket 2>/dev/null
ps -ef | grep -E 'dockerd|containerd' | grep -v grep     # 应无输出

# 3) ★★硬闸：两目录下不得有任何残留挂载（overlay merged/shm），未清零不得开拷
findmnt -R /var/lib/docker
findmnt -R /data
# 如有残留：umount <挂载点> 逐个卸载后复查；卸不掉先找占用（fuser -vm）
fuser -m /data /var/lib/docker 2>/dev/null               # 应无输出
```

**步骤 A3：建 LVM（双卷 + 余量）并 rsync 复制（对应 §19.4.3）**

```bash
pvcreate /dev/vdc
vgcreate vgdata /dev/vdc
lvcreate -n lvharbordata -L 200G vgdata   # 现场建后当场 lvextend 至 300G（见执行记录，VFree 随之降至 <50G）
lvcreate -n lvdocker     -L 100G vgdata
mkfs.ext4 -m 1 /dev/vgdata/lvharbordata
mkfs.ext4 -m 1 /dev/vgdata/lvdocker
vgs                                        # 确认 VG 留有 ~150G 空闲

mkdir -p /mnt/datanew /mnt/dockernew
mount /dev/vgdata/lvharbordata /mnt/datanew
mount /dev/vgdata/lvdocker     /mnt/dockernew

# ★root 执行 + -AXH --numeric-ids 缺一不可：-X 保 trusted.overlay.* xattr（差异②）、
#   -H 保镜像层间硬链接、--numeric-ids 保容器内 uid 属主
rsync -aAXH --numeric-ids --info=progress2 /data/           /mnt/datanew/
rsync -aAXH --numeric-ids --info=progress2 /var/lib/docker/ /mnt/dockernew/
```

**步骤 A4：校验一致后切换挂载（对应 §19.4.4，含 daemon-reload）**

```bash
# 1) 清单比对（无输出即一致）
diff <(cd /data && find . | sort) \
     <(cd /mnt/datanew && find . -path ./lost+found -prune -o -print | sort)
diff <(cd /var/lib/docker && find . | sort) \
     <(cd /mnt/dockernew && find . -path ./lost+found -prune -o -print | sort)

# 2) 卸临时点，源改名留作回退，建正式空挂载点
umount /mnt/datanew /mnt/dockernew
mv /data /data_old               && mkdir /data
mv /var/lib/docker /var/lib/docker_old && mkdir /var/lib/docker

# 3) fstab（UUID）+ 挂载 + systemd 静态体检
UUID_D=$(blkid -s UUID -o value /dev/vgdata/lvharbordata)
UUID_K=$(blkid -s UUID -o value /dev/vgdata/lvdocker)
echo "UUID=$UUID_D  /data            ext4  defaults,noatime  0 0" >> /etc/fstab
echo "UUID=$UUID_K  /var/lib/docker  ext4  defaults,noatime  0 0" >> /etc/fstab
mount /data ; mount /var/lib/docker
findmnt /data ; findmnt /var/lib/docker      # 均来自 /dev/mapper/vgdata-*
systemctl daemon-reload && findmnt --verify  # Success, no errors or warnings detected

# 4) ★挂载之后按 A1 基线还原两个根目录属主/权限（挂载前 chown 会被新卷根覆盖）
#    （现场基线以 A1 的 ls -ldn 记录为准；/var/lib/docker 通常 root:root 710）
chown root:root /data /var/lib/docker
chmod 755 /data ; chmod 710 /var/lib/docker
ls -ldn /data /var/lib/docker                # 与 A1 记录逐项一致
ls -ln /data | head                          # 抽查子目录 uid（999/10000 等）随 rsync 保留

# 5) SELinux Enforcing 时还原上下文
[ "$(getenforce)" = "Enforcing" ] && restorecon -Rv /data /var/lib/docker
```

**步骤 A5：解屏蔽 → 受控重启 → 起栈 → 验收（对应 §19.4.5；重启插在起栈前——反正已停机，正好一并验证 fstab 持久与开机自启链路）**

```bash
# ★先解屏蔽再重启——mask 状态下开机 docker 起不来
systemctl unmask docker.service; systemctl unmask docker.socket 2>/dev/null
reboot

# —— 重启后核验 ——
findmnt /data ; findmnt /var/lib/docker      # 仍来自 /dev/mapper/vgdata-*
systemctl status docker --no-pager           # active，开机自动拉起
systemctl status harbor --no-pager           # active——fstab 挂载 → docker → harbor 单元链全通
docker info | grep -E 'Images|Storage Driver|Docker Root Dir'   # 与 A1 基线一致（镜像数不变）

# harbor.service enabled 随开机自启并 up 整栈；未自起时 systemctl start harbor，勿手敲 compose。
# jobservice 开机初期偶发 exited code 2 一次后自愈转 healthy，属启动时序噪音（首执实见）
cd /opt/harbor && watch -n5 'docker-compose ps'   # 直到 10/10 Up (healthy)

# —— 功能验收（缺一不可）——
# 1) UI 登录 https://harbor.xaad.edu.cn 正常，项目/镜像列表完整
# 2) 本机推拉冒烟（对应 §19.4.9 步骤 6 的“动态功能验证必做”思想：
#    容器全 healthy 只证明栈能起，不证明 registry 读写链路）
docker login harbor.xaad.edu.cn
docker pull  harbor.xaad.edu.cn/<项目>/<现有镜像:tag>          # 读通
docker tag   <现有镜像> harbor.xaad.edu.cn/<项目>/migratetest:v1
docker push  harbor.xaad.edu.cn/<项目>/migratetest:v1          # 写通（blob 落 /data/registry 新卷）
# 3) 从任一 K8s 节点 docker pull 同一镜像——验证集群侧拉取链路
# 4) find 快照 post 比对（与 pre 同在 /root/migrate_evidence——勿用 /tmp，tmpfs 重启已清）：
#    差异应仅为启动后新写入（db WAL、redis dump、日志、刚 push 的 blob）
cd /data && find . | sort > /root/migrate_evidence/harbordata_post_$(date +%F_%H%M%S).txt
diff /root/migrate_evidence/harbordata_pre_*.txt /root/migrate_evidence/harbordata_post_*.txt | head -30

df -h /data /var/lib/docker                  # 容量已是新卷
```

**观察 1–2 天**（盯 compose 健康、K8s 各节点拉取、`df -h`、/var/log/harbor）后回收：

```bash
rm -rf /data_old /var/lib/docker_old         # §1 红线级 rm -rf，验收全过再执行
df -h /                                      # 系统盘应从 71% 明显回落
```

**回退方案**（删旧目录前任一环节出问题）：`systemctl stop harbor` → `systemctl stop docker` + mask → `umount /data /var/lib/docker` → 按 UUID 精确删除本次两条 fstab 行 → `mv /data_old /data ; mv /var/lib/docker_old /var/lib/docker` → unmask → `systemctl start docker` → `systemctl start harbor`。与 §19.4.5 回退等价。

**A-现场执行记录（harbor，2026-07-09，A 部分首次实执行）**

**结果**：`/data`（21G，17444 条目）与 `/var/lib/docker`（7.7G，192506 条目）成功迁移至 vgdata（**lvharbordata 300G + lvdocker 100G**，ext4 `-m 1`），挂载路径不变、harbor.yml/daemon.json/compose 零改动。rsync 分别 1′53″（~181MB/s）/ 1′39″；切换前双目录 `find` diff **零差异**；受控重启后 fstab 双挂载持久、docker + harbor.service 开机自启、compose 10/10 healthy；验收 `docker login/pull/push`、Rancher 侧拉取、从外部 harbor 复制镜像全部通过；`docker info` 指纹 Images 39 与迁移前一致（验收 pull 新镜像后 40，差值可解释；tag 不增计数）。系统盘 39G 占用暂不变（`*_old` 仍在原盘），观察期后回收预计回落 ~29G。

**执行要点与判读经验**：

- **反拉实证（差异①的现场版本）**：`docker-compose stop` 全部 done 后 `docker ps` 十个容器 "Up About a minute (healthy)"——`harbor.service`（前台 `docker-compose up` + Restart=on-failure）整栈反拉。改走 `systemctl stop harbor`（ExecStop=down）后 `docker ps -q | wc -l` 归零。教训与 §19.4.2「禁 vb_ctl stop 绕过 systemd」完全同构：**停任何东西之前先查它的托管单元**（§19.4.1 第 4 步本就有此要求，本变体首稿漏移植，已补入 A1 第 4 步）。
- Kylin 的 docker 20.10 包**无 docker.socket、无独立 containerd.service**（`dockerd -H unix://` 自拉 containerd，`systemctl status docker` 的 CGroup 内可见 containerd 为其子进程），stop 二者报 "not loaded" 属预期噪音；socket 激活反拉风险仅适用于带该单元的发行版。
- `docker-compose down` 时 registryctl/harbor-log `exited 137`（停止超时被 SIGKILL）、开机初期 jobservice `exited with code 2` 一次后自愈转 healthy——均为既有启停时序噪音，与迁移无关。
- 新卷根目录 `ls -ldn /data` 硬链接数 10→11、`ls -ln` 多出一行：ext4 自带 `lost+found`，find diff 已 prune，判读勿慌。

**偏差项（如实记录；流程要求不变）**：

- **mask 安全闸连续第二次被跳过**（§19.4.8 已警告一次），且本次窗口内**真实发生了一次反拉**（虽来源是 harbor.service 而非 docker）。业务无损是因反拉发生在动盘之前；下次执行 A2/B2 的 mask 必须照做。
- lvharbordata 建后当场 `lvextend` 200G→300G，VFree 由 ~150G 压至 **<50G**——余量原则被压缩：剩余空间仅够应急缓冲/LVM 快照，再要扩先 `vgextend` 加盘（同 §19.4.9 余量提醒）。
- rsync 未预装，停机窗口内临时 `yum install`（约 +1 分钟停机）——工具前置检查已补入 A1/B1。
- **★pre 快照写入 /tmp，受控重启后被清空**（Kylin V10 `/tmp` 为 tmpfs，`df -h` 即可见），post/pre 比对落空。**迁移一致性结论不受影响**——权威闸门是切换前新旧目录的双 `find` diff 零差异（A4 第 1 步，已通过且留屏）；pre/post 快照只是验收辅证，但证据链断档。快照路径已全量改为 `/root/migrate_evidence`；**§19.4.9 存在同款潜伏隐患**（快照写 /tmp、步骤 5 受控重启在比对之前），v1.48 一并修正。

**证据补救（回收 `*_old` 之前执行——旧目录本身就是 pre 状态的完整留存）**：

```bash
mkdir -p /root/migrate_evidence
(cd /data_old           && find . | sort > /root/migrate_evidence/harbordata_pre_fromold.txt)
(cd /var/lib/docker_old && find . | sort > /root/migrate_evidence/harbordocker_pre_fromold.txt)
(cd /data               && find . | sort > /root/migrate_evidence/harbordata_post_$(date +%F_%H%M%S).txt)
diff /root/migrate_evidence/harbordata_pre_fromold.txt \
     /root/migrate_evidence/harbordata_post_*.txt | head -30
# /data 差异应仅为停栈后的新写入（database WAL、redis、job_logs、验收 push 的 registry blob）。
# /var/lib/docker 新旧差异会很大且属预期——down/up 重建了全部容器（containers/ 全换 ID、
#   network/buildkit 文件重写、验收新 pull 一个镜像），留证即可、不逐条追查。
```

---

**B. K8s 工作节点（`/var/lib/docker`；逐台滚动，禁与 harbor 窗口重叠）**

**步骤 B1：迁移前确认（对应 §19.4.1；kubectl 命令在管理机执行，其余在目标节点 root 执行）**

```bash
# —— 目标节点 ——
du -shx /var/lib/docker                      # 现场约 20G 级
lsblk -f /dev/vdc ; wipefs -n /dev/vdc       # 无输出 = 干净裸盘
getenforce
docker info | grep -E 'Images|Containers|Storage Driver|Docker Root Dir'
#   基线现场：Images: 71 / overlay2 / /var/lib/docker
#   （Containers 数随调度波动——首查 80、迁移当日 76——不作跨迁移判据，指纹看 Images/Driver/RootDir）
systemctl is-enabled docker                  # enabled（containerd 独立单元不存在属预期）
systemctl list-unit-files | grep -iE 'docker|rke|rancher'   # ★确认无额外托管单元（A 部分反拉教训）
command -v rsync || yum install -y rsync     # ★工具前置（harbor 首执教训）
ls -ldn /var/lib/docker                      # 权限基线
mkdir -p /root/migrate_evidence              # ★证据一律持久目录，勿写 /tmp（tmpfs 重启即清）

# —— 管理机（kubectl）——
kubectl get pods -A -o wide | grep k8s-worker01 > /root/migrate_evidence/w01_pods_pre.txt   # 负载清单留证
kubectl top nodes                            # ★确认其余节点余量能接住被驱逐负载
```

**步骤 B2：cordon + drain → 停并屏蔽 docker → 硬闸（对应 §19.4.2；对应 §19.4.9 步骤 2「先停写入方」）**

```bash
# —— 管理机 ——
kubectl cordon k8s-worker01
kubectl drain  k8s-worker01 --ignore-daemonsets --delete-emptydir-data
# 等 drain 完成、业务 pod 全部在其它节点 Running（此过程依赖 harbor 在线拉镜像——差异③）
kubectl get pods -A -o wide | grep k8s-worker01   # 应只剩 DaemonSet pod 即为“驱逐完成”
#   （现场三个：cattle-node-agent / nginx-ingress-controller / calico-node，属预期）

# —— 目标节点 ——
# 停 docker 会连带停掉 kubelet/kube-proxy/nginx-proxy 及 DaemonSet 容器（RKE1 全容器化，
# live-restore=false）——drain 已做完，无业务影响；节点将在 Rancher 显示 NotReady，属预期
systemctl stop docker.socket docker.service containerd 2>/dev/null; systemctl stop docker
systemctl mask docker.service; systemctl mask docker.socket 2>/dev/null
ps -ef | grep -E 'dockerd|containerd' | grep -v grep      # 无输出

# ★★硬闸：残留 overlay/shm 挂载清零后才许开拷（DaemonSet 容器残留 shm 较常见）
findmnt -R /var/lib/docker                   # 必须无输出；有则逐个 umount 后复查
fuser -m /var/lib/docker 2>/dev/null         # 无输出
# /var/lib/kubelet 下的 NFS/secret 挂载不在迁移范围，无需处理（本次只动 /var/lib/docker）
```

**步骤 B3：建 LVM 并复制（对应 §19.4.3）**

```bash
pvcreate /dev/vdc
vgcreate vgdata /dev/vdc
lvcreate -n lvdocker -L 150G vgdata          # 留 ~50G 余量；将来不够 lvextend 在线扩（§19.4.6）
mkfs.ext4 -m 1 /dev/vgdata/lvdocker
mkdir -p /mnt/dockernew
mount /dev/vgdata/lvdocker /mnt/dockernew
rsync -aAXH --numeric-ids --info=progress2 /var/lib/docker/ /mnt/dockernew/
```

**步骤 B4：校验一致后切换挂载（对应 §19.4.4）**

```bash
diff <(cd /var/lib/docker && find . | sort) \
     <(cd /mnt/dockernew && find . -path ./lost+found -prune -o -print | sort)   # 无输出即一致

umount /mnt/dockernew
mv /var/lib/docker /var/lib/docker_old && mkdir /var/lib/docker

UUID_K=$(blkid -s UUID -o value /dev/vgdata/lvdocker)
echo "UUID=$UUID_K  /var/lib/docker  ext4  defaults,noatime  0 0" >> /etc/fstab
mount /var/lib/docker ; findmnt /var/lib/docker
systemctl daemon-reload && findmnt --verify              # Success ...

chown root:root /var/lib/docker && chmod 710 /var/lib/docker    # 按 B1 基线还原
[ "$(getenforce)" = "Enforcing" ] && restorecon -Rv /var/lib/docker
```

**步骤 B5：解屏蔽 → 受控重启 → 节点回归 → uncordon（对应 §19.4.5）**

```bash
systemctl unmask docker.service; systemctl unmask docker.socket 2>/dev/null
reboot

# —— 重启后（目标节点）——
findmnt /var/lib/docker                      # 来自 /dev/mapper/vgdata-lvdocker
systemctl status docker --no-pager           # active，开机自启
docker info | grep -E 'Images|Storage Driver|Docker Root Dir'   # Images 数与 B1 一致
docker ps | grep -E 'kubelet|kube-proxy'     # RKE 基础容器 restart=always 已随 docker 自起

# —— 管理机 ——
kubectl get nodes                            # k8s-worker01 回 Ready（仍 SchedulingDisabled）
kubectl uncordon k8s-worker01
kubectl get pods -A -o wide | grep k8s-worker01   # 观察调度回流、全 Running
kubectl get pods -A | grep -vE 'Running|Completed'   # 直到输出为空
```

**逐台推进**：本台观察 30–60 分钟无异常（pod 稳定、无 ImagePullBackOff/CrashLoop、`journalctl -u docker` 无报错）再做下一台。全部节点完成并观察 1–2 天后，各节点回收 `rm -rf /var/lib/docker_old`。

**回退方案**（单台任一环节出问题；节点已 cordon，无扩散风险）：`systemctl stop docker.socket docker.service` + mask → `umount /var/lib/docker` → 按 UUID 删本次 fstab 行 → `mv /var/lib/docker_old /var/lib/docker` → unmask → `systemctl start docker` → 节点 Ready 后 `kubectl uncordon`。

**B-现场执行记录（k8s-worker01，2026-07-09，B 部分首台实执行）**

**结果**：`/var/lib/docker`（18G，296714 条目）成功迁移至 vgdata/lvdocker 150G（ext4 `-m 1`，VG 留 ~50G 余量）。rsync 2′13″（~121MB/s）；切换前 `find` diff **零差异**；fstab UUID + `daemon-reload` + `findmnt --verify` Success；受控重启后挂载持久、docker 开机自启、kubelet/kube-proxy（RKE 容器 restart=always）随 docker 自动拉起 "Up 3 minutes"、节点回 `Ready,SchedulingDisabled`；`docker info` 指纹 **Images 71 与迁移前一致**；uncordon 后约 2 分钟即有新 pod（cas-server-webapp）调度落回本节点。**★mask 安全闸自 §19.4.8 警告以来首次被完整执行**（stop → mask → 迁移 → unmask → reboot），主流程零偏差跑通。

**执行要点与判读经验**：

- drain 驱逐 24 个业务 pod，含 cas-server webapp/mf、kafka、rabbitmq、多套 redis——**CAS 组件在列，缩容窗口=SSO 抖动窗口须低峰**（同 §19.4.9 差异③）；`WARNING: ignoring DaemonSet-managed Pods`（cattle-node-agent / nginx-ingress-controller / calico-node 三个）属预期，drain 后 grep 本节点**仅剩这三个 DaemonSet pod 即为“驱逐完成”判据**。
- drain 过程 `Throttling request took 1.19s`（kubectl 经 Rancher 代理的 client 端限流）为噪音，非集群异常。
- 重启后 DaemonSet pod 的 RESTARTS 计数 +1（2→3）：容器随 docker 重启而重建，属预期，勿当异常追查。
- `docker info` 的 Containers 计数在 drain/重启前后必然变化（业务容器随驱逐消亡）；**跨迁移可比指纹是 Images / Storage Driver / Docker Root Dir 三项**，Containers 数不作判据。
- kubectl 在被迁移节点本机执行亦可行（API 走 rancher.xaad.edu.cn 远端，与本机 docker 停开无关），但 drain 输出与负载清单建议统一在管理机留证（本次清单已存管理机 `/root/migrate_evidence/w01_pods_pre.txt`）。

**待补证据（不影响结论）**：B1 权限基线 `ls -ldn` 未留屏（按默认 `root:root 710` 还原，与 harbor 台账一致）。收尾 `kubectl get pods -A | grep -vE 'Running|Completed'` 已补留屏——**输出为空，全集群无非 Running/Completed pod**；30–60 分钟观察随 worker02 窗口衔接。

**衍生发现（另案跟进，不影响迁移结论）**：`kubectl top nodes` 留证时见 k8s-master01 内存 87%（2867Mi），显著高于 master02/03（62–66%）——非本流程范围，建议另案关注 master 内存水位与组件分布。

---

**边界与备选说明（对应 §19.4.7）**

- **daemon.json / harbor.yml / compose 零改动**：`data-root`、`data_volume` 路径不变是本流程的根基（§19.4 核心原则①）；严禁借迁移之机顺手改 `data-root` 指到新路径——那是另一套流程且放弃了“留旧目录回退”能力。
- **rsync 之外的备选（工作节点适用、harbor 不适用）**：工作节点镜像均可从 harbor 重拉，理论上可“新卷空目录挂上直接起 docker”让 kubelet 重建一切——目录最干净，但重拉 71 个镜像依赖 harbor 带宽且窗口不可控；本节统一选 rsync 保留现场，与 §19.4 骨架一致。harbor 主机的 `/data` 是唯一数据源，**只能 rsync 冷迁**。
- **异常指纹速查**：起服后若 `docker images` 数量骤减、容器报 `layer does not exist` / 文件“复活”或凭空消失——即 xattr/硬链接未保真（差异②被违反），**一律整体回退重做，勿在新卷上修补**。
- **迁移后在线扩容**：两类主机均按 §19.4.6 执行（`lvextend` + `resize2fs`，业务在线）；harbor 的 `/data` 为主要增长点，纳入 §18 巡检 `df -h /data` 水位。

---

## 20. 性能压测、参数优化与压测报告（含 fio/WDR/清理 checklist）

> **交付要求**：VastBase 部署完成后，不能只按硬件模板固化参数。必须按“准入 → 起步基线 → 基准 → 业务回放 → 稳定性 → 调参 → 报告 → 投产签收”的闭环执行，形成《性能压测报告》后再进入投产签收。压测结果应作为 `shared_buffers`、`work_mem`、`max_connections`、WAL/checkpoint、autovacuum、并行执行、连接池等参数定稿依据。


**统一压测证据目录（必须先执行）**：第 20 章所有 fio、sysbench、OS/DB 采集、WDR、结果提取和清理证据都必须写入同一个 `REPORT_DIR`。建议在压测第一个窗口执行一次，并在后续 shell、脚本和窗口中复用；跨窗口执行时可从 `.perf_test_current` 回读。

```bash
export REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
if [ -z "$REPORT_DIR" ]; then
  REPORT_DIR="/vastbase/docs/perf_test_$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p "$REPORT_DIR"
echo "$REPORT_DIR" > /vastbase/docs/.perf_test_current
printf '[INFO] REPORT_DIR=%s\n' "$REPORT_DIR"
```

> 后续代码块如重新打开终端，应先执行：`export REPORT_DIR=$(cat /vastbase/docs/.perf_test_current)`。禁止在 fio、sysbench、DB 采集或清理步骤中再次各自生成新的 `perf_test_<时间戳>` 目录，否则证据会被打散，影响 §13 验收、§22 交付和压测报告附件清单。

### 20.1 压测目标、准入条件与停止条件

**压测目标**：

1. 验证当前服务器、OS、磁盘、网络和 VastBase 参数能否满足业务 SLA。
2. 找出主要瓶颈：CPU、内存、I/O、WAL/checkpoint、连接数、锁等待、慢 SQL、临时文件或归档链路。
3. 在 32GB/64GB 内存规格下形成可解释的参数基线，避免简单套用“越大越好”的配置。
4. 输出可归档的压测报告，明确最终参数、调整原因、风险和回滚方式。

**压测准入条件**：


压测准入前若尚未按 §6.6/§6.8 下发性能采集开关，先执行以下最小启用块，再根据 `pg_settings.context` 判断 reload 或 restart：

```bash
$VB_GUC set -D $PGDATA -c "enable_resource_track = on"
$VB_GUC set -D $PGDATA -c "track_stmt_stat_level = 'L1,L1'"
$VB_GUC set -D $PGDATA -c "enable_resource_record = on"
$VB_GUC set -D $PGDATA -c "instr_unique_sql_count = 10000"
$VB_GUC set -D $PGDATA -c "track_activity_query_size = 4096"
$VB_CTL reload -D $PGDATA || $VB_CTL restart -D $PGDATA -m fast
```

| 类别 | 准入要求 |
|------|----------|
| 部署状态 | VastBase 已初始化为MySQL兼容模式；监听、认证、业务库、业务账号、表空间已配置完成。 |
| 安全与回退 | 已完成配置备份；若使用真实业务数据，必须按 §16.4 完成脱敏、授权和备份。 |
| 监控 | 已能采集 CPU、内存、磁盘 I/O、网络、数据库连接、慢 SQL、锁等待、WAL、checkpoint、归档状态。 |
| 性能采集开关 | `enable_resource_track=on`；`track_stmt_stat_level >= 'L1,L1'`；`enable_wdr_snapshot=on` 或已确认压测前开启；`pg_stat_statements` 可用或已说明不使用。 |
| huge_pages 校验 | `SHOW huge_pages;` 与 `grep Huge /proc/meminfo` 一致；`on/try` 模式下 `HugePages_Total` 满足 shared_buffers 需求。 |
| 裸盘 I/O 基线 | 已完成数据盘 4K 随机读、WAL 盘 16K fsync 写、WAL 盘 8K 单连接/并发 fsync 写基线采集，并写入压测报告。 |
| 数据规模 | 基准压测数据量建议不小于 `shared_buffers` 的 1.5–2 倍；业务回放应覆盖核心高频 SQL 和典型批处理。 |
| 业务 SLA | 已明确 TPS/QPS、P95/P99 延迟、批处理窗口、CPU/IO 资源水位、错误率等验收阈值。 |
| 网络基线 | 远程压测机、数据库服务器、备份/归档链路已完成 iperf3 单流/多流基线，确认压测机和网络不是瓶颈。 |
| 工具验证 | sysbench/pgbench/JMeter/业务压测工具的驱动、字符集、事务语义和连接方式已在小并发下验证通过。 |

**fio 裸盘 I/O 基线、iperf3 网络基线示例**：

```bash
su  - root
yum install -y fio
yum install -y iperf3
```



切换到vastbase用户

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
mkdir -p "$REPORT_DIR"

# 测试文件不放在 $PGDATA 内，避免污染数据库目录权限审计；如 WAL 独立挂载，请把 WAL_FIO_DIR 改到 WAL 盘。
# 若 FIO_DIR 与 WAL_FIO_DIR 保持相同默认值，下面 4 个 WAL fsync 数值仅代表同一块盘上的不同写型基线，不构成独立 WAL 盘基线；fio 子项按顺序串行执行，避免同盘互相干扰。
FIO_DIR=/vastbase/perf_baseline
WAL_FIO_DIR=/vastbase/perf_baseline
mkdir -p "$FIO_DIR" "$WAL_FIO_DIR"

MEM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
FIO_SIZE_GB=$(( MEM_GB * 2 ))
[ "$FIO_SIZE_GB" -lt 16 ] && FIO_SIZE_GB=16

# 数据盘 4K 随机读；size 至少 16GB，推荐不小于 2 × 物理内存，并用 ramp_time 跳过预热抖动。
# 这里采用“单测试文件 + 4 个 job 并发 randread”模型，测试容量仍为 FIO_SIZE_GB，不是 FIO_SIZE_GB × 4。
fio --name=randread --rw=randread --bs=4k --size=${FIO_SIZE_GB}G --numjobs=4 \
    --runtime=120 --ramp_time=30 --time_based --ioengine=libaio --direct=1 \
    --filename="$FIO_DIR/fio_data_test" --group_reporting \
    | tee "$REPORT_DIR/fio_data_randread_4k.log"

# WAL 盘 16K fsync 写（每 16K 写触发 fdatasync），用于观察 WAL 同步提交受限场景能力。
fio --name=walwrite16k --rw=write --bs=16k --size=16G --numjobs=1 \
    --runtime=120 --ramp_time=30 --time_based --ioengine=libaio --direct=1 --fdatasync=1 \
    --filename="$WAL_FIO_DIR/fio_wal_test_16k" --group_reporting \
    | tee "$REPORT_DIR/fio_wal_write_16k_fsync.log"

# WAL 盘 8K 单连接 fdatasync，对照单连接 commit 极限。
fio --name=walwrite8k_1job --rw=write --bs=8k --size=16G --numjobs=1 \
    --runtime=120 --ramp_time=30 --time_based --ioengine=libaio --direct=1 --fdatasync=1 \
    --filename="$WAL_FIO_DIR/fio_wal_test_8k_1job" --group_reporting \
    | tee "$REPORT_DIR/fio_wal_write_8k_1job_fsync.log"

# WAL 盘 8K 多连接 fdatasync，对照并发 fsync 能力。
fio --name=walwrite8k_4job --rw=write --bs=8k --size=16G --numjobs=4 \
    --runtime=120 --ramp_time=30 --time_based --ioengine=libaio --direct=1 --fdatasync=1 \
    --filename="$WAL_FIO_DIR/fio_wal_test_8k_4job" --group_reporting \
    | tee "$REPORT_DIR/fio_wal_write_8k_4job_fsync.log"

rm -f "$FIO_DIR/fio_data_test" "$WAL_FIO_DIR"/fio_wal_test_*
```

报告中至少保留 baseline：`数据盘 4K randread IOPS = ?`、`WAL 盘 16K fsync 写 IOPS = ?`、`WAL 盘 8K 单连接 fsync 写 IOPS = ?`、`WAL 盘 8K 并发 fsync 写 IOPS = ?`。后续压测若 `iostat util%=100%`，应把数据库曲线与该裸盘上限对齐判断。

**iperf3 网络基线示例（远程压测机/备份链路建议必做）**：

> 以下命令跨数据库服务器与压测机两台机器执行：服务端命令在数据库服务器执行，客户端命令在压测机执行，请勿整段粘贴到同一终端。

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
mkdir -p "$REPORT_DIR"

# 数据库服务器临时启动 iperf3 服务端；压测完成后必须关闭并记录清理证据。
iperf3 -s -D --pidfile "$REPORT_DIR/iperf3_server.pid" --logfile "$REPORT_DIR/iperf3_server.log"

# 压测机执行：单流与 4 并发流各跑 60 秒；DB_IP 按现场替换。
DB_IP=172.18.13.152
iperf3 -c "$DB_IP" -t 60 -P 1 --json | tee "/root/iperf3_client_p1.json"
iperf3 -c "$DB_IP" -t 60 -P 4 --json | tee "/root/iperf3_client_p4.json"

# 数据库服务器压测后关闭临时 iperf3 服务端。
[ -f "$REPORT_DIR/iperf3_server.pid" ] && kill "$(cat "$REPORT_DIR/iperf3_server.pid")" 2>/dev/null || true
```

报告中至少记录：`iperf3 单流吞吐 = ? Gbps`、`iperf3 4 并发流吞吐 = ? Gbps`、`重传数 = ?`。若远程压测机与数据库服务器之间吞吐接近链路上限或重传明显，应先排除网络/压测机瓶颈，再解释数据库 TPS/QPS。


**立即停止压测并回退排查的条件**：

| 停止条件 | 处理建议 |
|----------|----------|
| 操作系统出现 OOM、swap 持续增长、数据库进程被 kill | 停止压测，降低并发和 `work_mem`，复核 `max_connections` 与连接池。 |
| 数据盘或归档盘使用率超过 85%，或归档失败持续增长 | 停止写入压测，清理归档/扩容/修复异地同步后再继续。 |
| 数据库日志出现 `PANIC`、持续 `FATAL`、大量连接失败 | 暂停压测，先恢复实例稳定性。 |
| P95/P99 延迟超过 SLA 2 倍且持续 10 分钟以上 | 保留现场，采集 WDR/慢 SQL/锁等待后降低并发。 |
| 磁盘 await 或 util 长时间满载，业务请求大量超时 | 降低写入并发，重点检查 checkpoint、WAL、索引、SQL 和存储性能。 |

### 20.2 压测类型与执行顺序

| 阶段 | 建议时长 | 主要目的 | 通过标准 |
|------|----------|----------|----------|
| 连通性冒烟压测 | 5–10 分钟 | 验证账号、驱动、字符集、事务、工具参数 | 无连接失败，无语法/权限错误 |
| 起步基线压测 | 每档并发 10–30 分钟 | 在 §20.3 参数下获取吞吐、延迟和资源曲线 | 找到吞吐拐点和资源瓶颈 |
| 业务 SQL/接口回放 | 30–60 分钟或按业务窗口 | 验证核心交易、报表、批处理 SQL | 满足业务 SLA，错误率为 0 或低于业务阈值 |
| 参数复测 | 每次只调整一类参数后复跑关键并发档 | 验证参数调整是否有效 | 同一负载下吞吐/延迟/资源至少一项改善，且无副作用 |
| 稳定性压测 | 4–24 小时 | 验证长时间运行、归档、日志、autovacuum、连接池稳定性 | 无 OOM、无归档堆积、无持续锁等待、无日志异常 |

建议顺序：**冒烟压测 → 32G/64G 起步基线 → 基准压测 → 业务回放 → 参数调整 → 复测 → 稳定性压测 → 出具压测报告 → 参数定稿 → 清理临时变更**。

> 稳定性压测启动前，必须确认并按变更单临时暂停所有会影响数据库 I/O 或连接数的调度：`crontab -u vastbase`、`crontab -u root`、`/etc/cron.d/`、`/etc/cron.{hourly,daily,weekly,monthly}/`，以及客户备份/巡检平台（如 Ansible Tower、Rundeck、集中备份软件）的相关任务。压测前保存 `crontab_before_perf_test.txt`、`root_crontab_before_perf_test.txt` 和 `/etc/cron*` 清单；压测后必须恢复并归档 after 证据。

### 20.3 32GB / 64GB 内存规格的参数起步基线

以下参数用于压测起步，不是最终值。32GB 列与 §6 的部署初始值保持一致；如果现场曾按旧稿下发更激进值（如 `work_mem=64MB`、`max_connections=500`），应先回退到本基线后再压测。

| 参数 | 32GB 内存起步值 | 64GB 内存起步值 | 调整说明 |
|------|-----------------|-----------------|----------|
| `shared_buffers` | `8GB` | `16GB` | 通常从物理内存 25% 起步；读多且命中率不足时可逐步上调，但一般不建议超过 40%。 |
| `effective_cache_size` | `24GB` | `48GB` | 约为物理内存 75%，用于优化器估算，不直接分配内存。 |
| `work_mem` | `32MB` | `64MB` | 单连接、单算子内存；高并发或复杂 SQL 多时先保守，出现大量临时文件后再评估上调。 |
| `maintenance_work_mem` | `2GB` | `4GB` | 影响 VACUUM、CREATE INDEX、恢复导入效率；批量建索引可临时上调。 |
| `temp_buffers` | `32MB` | `64MB` | 临时表较多时观察临时文件和会话内存后调整。 |
| `wal_buffers` | `64MB` | `128MB` | 写入压力大时可固定显式值，避免默认推算过小。 |
| `max_connections` | `500` | `800` | 建议配合应用连接池；32GB 若必须保留 500 连接，应降低 `work_mem` 并控制活跃连接。 |
| `sysadmin_reserved_connections` | `10` | `10` | 保留 DBA 应急连接。 |
| #`max_worker_processes` | `16` | `32` | 全局后台进程数，含 autovacuum、parallel worker、logical apply。 |
| `max_parallel_workers` | `8` | `16` | 全实例并行 worker 上限。 |
| `max_parallel_workers_per_gather` | `2` | `4` | 单查询并行度；OLTP 建议 0–2，OLAP 可评估 4–8。 |
| ---`max_parallel_maintenance_workers` | `2` | `4` | CREATE INDEX 等维护操作并行度。 |
| #`max_wal_size` | `16GB` | `32GB` | 写入高峰 checkpoint 过频时优先增大。 |
| #`min_wal_size` | `2GB` | `4GB` | 与 `max_wal_size` 成比例设置。 |
| `checkpoint_timeout` | `15min` | `15min` | 批量写入场景可结合恢复时间目标评审。 |
| `checkpoint_completion_target` | `0.9` | `0.9` | 平滑 checkpoint I/O。 |
| `autovacuum_max_workers` | `6` | `8` | 高更新表多时增加，但需观察 I/O。 |
| `autovacuum_vacuum_cost_limit` | `2000` | `4000` | 高更新业务可逐步上调，避免死元组堆积。 |
| ---`default_statistics_target` | `200` | `300` | SQL 计划不稳定或复杂查询多时上调后重新 `ANALYZE`。 |
| `enable_resource_track` | `on` | `on` | 性能诊断与 §20.8 采集 SQL 依赖；若版本不支持需记录说明。 |
| `track_stmt_stat_level` | `'L1,L1'` | `'L1,L1'` | TOP SQL/语句级统计采集起步值；需要更细粒度时按厂家建议上调。 |
| `enable_resource_record` | `on` | `on` | 资源记录留痕，便于压测后回溯。 |
| `instr_unique_sql_count` | `10000` | `10000` | 提高唯一 SQL 统计容量，避免压测期间 TOP SQL 被挤出。 |
| `track_activity_query_size` | `4096` | `4096` | 保留较完整 SQL 文本，便于 WDR/活动会话分析。 |
| `log_min_duration_statement` | `10000` | `10000` | 压测期间可临时降到 `500` 捕获更多慢 SQL，投产前按运维策略恢复。 |

> ⚠️ 经验上限：`实际活跃并发 × work_mem ≤ 物理内存 × 25%`。32GB 服务器若把 `work_mem` 上调到 `64MB`，要确保实际活跃并发不超过 130；64GB 服务器若把 `work_mem` 上调到 `128MB`，也要确保实际活跃并发不超过 130，并优先验证是否存在 SQL/索引问题。

**32GB 起步下发示例**：

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
mkdir -p "$REPORT_DIR"
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -At \
  -c "SELECT name,setting,unit,context FROM pg_settings ORDER BY name;" \
  > "$REPORT_DIR/params_before.tsv"

$VB_GUC set -D $PGDATA -c "shared_buffers = 8GB"
$VB_GUC set -D $PGDATA -c "effective_cache_size = 24GB"
$VB_GUC set -D $PGDATA -c "work_mem = 32MB"
$VB_GUC set -D $PGDATA -c "maintenance_work_mem = 2GB"
$VB_GUC set -D $PGDATA -c "temp_buffers = 32MB"
#$VB_GUC set -D $PGDATA -c "wal_buffers = 64MB" -- 1G
$VB_GUC set -D $PGDATA -c "max_connections = 300"
$VB_GUC set -D $PGDATA -c "sysadmin_reserved_connections = 10"
$VB_GUC set -D $PGDATA -c "max_worker_processes = 16"
$VB_GUC set -D $PGDATA -c "max_parallel_workers = 8"
$VB_GUC set -D $PGDATA -c "max_parallel_workers_per_gather = 2"
$VB_GUC set -D $PGDATA -c "max_parallel_maintenance_workers = 2"
$VB_GUC set -D $PGDATA -c "max_wal_size = 16GB"
$VB_GUC set -D $PGDATA -c "min_wal_size = 2GB"
$VB_GUC set -D $PGDATA -c "checkpoint_timeout = 15min"
$VB_GUC set -D $PGDATA -c "checkpoint_completion_target = 0.9"
$VB_GUC set -D $PGDATA -c "autovacuum_max_workers = 6"
$VB_GUC set -D $PGDATA -c "autovacuum_vacuum_cost_limit = 2000"
$VB_GUC set -D $PGDATA -c "default_statistics_target = 200"

# 性能采集开关；§12.2、§13、§20 压测准入和采集 SQL 均依赖本组参数。
$VB_GUC set -D $PGDATA -c "enable_resource_track = on"
$VB_GUC set -D $PGDATA -c "track_stmt_stat_level = 'L1,L1'"
$VB_GUC set -D $PGDATA -c "enable_resource_record = on"
$VB_GUC set -D $PGDATA -c "instr_unique_sql_count = 10000"
$VB_GUC set -D $PGDATA -c "track_activity_query_size = 4096"
$VB_CTL restart -D $PGDATA -m fast
```

**64GB 起步下发示例**：

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
mkdir -p "$REPORT_DIR"
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -At \
  -c "SELECT name,setting,unit,context FROM pg_settings ORDER BY name;" \
  > "$REPORT_DIR/params_before.tsv"

$VB_GUC set -D $PGDATA -c "shared_buffers = 16GB"
$VB_GUC set -D $PGDATA -c "effective_cache_size = 48GB"
$VB_GUC set -D $PGDATA -c "work_mem = 64MB"
$VB_GUC set -D $PGDATA -c "maintenance_work_mem = 4GB"
$VB_GUC set -D $PGDATA -c "temp_buffers = 64MB"
$VB_GUC set -D $PGDATA -c "wal_buffers = 128MB"
$VB_GUC set -D $PGDATA -c "max_connections = 500"
$VB_GUC set -D $PGDATA -c "sysadmin_reserved_connections = 10"
$VB_GUC set -D $PGDATA -c "max_worker_processes = 32"
$VB_GUC set -D $PGDATA -c "max_parallel_workers = 16"
$VB_GUC set -D $PGDATA -c "max_parallel_workers_per_gather = 4"
$VB_GUC set -D $PGDATA -c "max_parallel_maintenance_workers = 4"
$VB_GUC set -D $PGDATA -c "max_wal_size = 32GB"
$VB_GUC set -D $PGDATA -c "min_wal_size = 4GB"
$VB_GUC set -D $PGDATA -c "checkpoint_timeout = 15min"
$VB_GUC set -D $PGDATA -c "checkpoint_completion_target = 0.9"
$VB_GUC set -D $PGDATA -c "autovacuum_max_workers = 8"
$VB_GUC set -D $PGDATA -c "autovacuum_vacuum_cost_limit = 4000"
$VB_GUC set -D $PGDATA -c "default_statistics_target = 300"

# 性能采集开关；§12.2、§13、§20 压测准入和采集 SQL 均依赖本组参数。
$VB_GUC set -D $PGDATA -c "enable_resource_track = on"
$VB_GUC set -D $PGDATA -c "track_stmt_stat_level = 'L1,L1'"
$VB_GUC set -D $PGDATA -c "enable_resource_record = on"
$VB_GUC set -D $PGDATA -c "instr_unique_sql_count = 10000"
$VB_GUC set -D $PGDATA -c "track_activity_query_size = 4096"
$VB_CTL restart -D $PGDATA -m fast
```

### 20.4 压测工具选择

| 工具/方式 | 适用场景 | 注意事项 |
|-----------|----------|----------|
| 业务压测平台 / JMeter / Locust | 最贴近真实业务交易、接口和连接池行为 | 推荐作为最终验收依据；需固定接口比例、思考时间、数据分布和 SLA。 |
| sysbench `oltp_read_write` | 快速获取通用 OLTP 吞吐、延迟和并发拐点 | 使用 `pgsql` 驱动前必须小并发验证 VastBase 连接协议、事务语义和 SQL 兼容性。 |
| pgbench | PostgreSQL/openGauss 生态基准测试 | 仅在现场确认工具可连接当前 VastBase 版本时使用；结果只代表基准模型。 |
| 业务 SQL 回放 | 验证迁移后的真实 SQL、索引和兼容参数 | 应包含 TOP SQL、慢 SQL、批量写入、报表查询、事务冲突场景。 |
| `vsql/gsql` 自定义脚本 | 冒烟验证、单 SQL 或小规模并发 | 不建议作为唯一容量结论，连接建立开销会影响结果。 |


MySQL 兼容模式需要特别澄清：VastBase G100 的 MySQL 兼容主要是 **SQL 层兼容**，协议层仍采用 PostgreSQL/openGauss 生态协议。业务连接必须使用 VastBase 提供的 JDBC（如 `org.opengauss.Driver`）或厂家认证的兼容驱动；不要用 `com.mysql.cj.jdbc.Driver` 直接连接 VastBase。sysbench 走 `--db-driver=pgsql` 测得的是内核 OLTP 容量，不能验证 `INSERT ... ON DUPLICATE KEY UPDATE`、`REPLACE INTO`、自增列、MySQL 风格函数与 `vastbase_sql_mode` 等特有 SQL 行为；这些必须由业务回放覆盖。

**pgbench fallback 最小示例**（仅当现场确认 `pgbench` 可连接当前 VastBase 版本，且 sysbench 无可用 `pgsql` 驱动时使用）：

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
mkdir -p "$REPORT_DIR"

export PGPASSWORD='Benchuser@2026'
PGHOST=192.168.10.11
PGPORT=5432
PGUSER=benchuser
PGDATABASE=benchdb

# 初始化规模按现场内存调整：scale=200 约数 GB 级，正式基准建议让数据量不小于 shared_buffers 的 1.5–2 倍。
pgbench -i -s "${PGBENCH_SCALE:-200}" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$PGDATABASE" \
  | tee "$REPORT_DIR/pgbench_init.log"

# 32GB 可从 -c 32/64/128 起步；64GB 可从 -c 64/128/256 起步。结果只代表 pgbench 模型，不能替代业务回放。
pgbench -c "${PGBENCH_CLIENTS:-64}" -j "${PGBENCH_JOBS:-8}" -T "${PGBENCH_TIME:-1800}" \
  -P 10 -r -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$PGDATABASE" \
  | tee "$REPORT_DIR/pgbench_c${PGBENCH_CLIENTS:-64}.log"
```


### 20.5 创建压测库、压测用户与权限

以下示例使用独立 `benchdb`，避免压测对象污染业务库。若必须在业务库回放，应使用独立 schema，并提前确认数据脱敏、清理和回退方案。

```sql
-- 以 vbadmin 登录 postgres 执行
CREATE USER benchuser
    WITH PASSWORD 'Benchuser@2026'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    LOGIN
    CONNECTION LIMIT 500;

CREATE DATABASE benchdb
    WITH OWNER = vbadmin
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0
    DBCOMPATIBILITY = 'B'
    CONNECTION LIMIT = 500;

\c benchdb vbadmin
CREATE SCHEMA bench AUTHORIZATION benchuser;
GRANT CONNECT ON DATABASE benchdb TO benchuser;
GRANT USAGE, CREATE ON SCHEMA bench TO benchuser;
ALTER USER benchuser SET search_path = bench, public;
```

`pg_hba.conf` 需要按压测机 IP 精确放行，压测完成后必须删除临时规则并归档清理证据。

```conf
# 压测机，按现场 IP 精确放行；压测完成后删除或注释
host    benchdb    benchuser    192.168.20.50/32    sha256
```

```bash
$VB_CTL reload -D $PGDATA
```

> `benchuser` 与示例口令仅用于压测临时账号。`sysbench --pgsql-password` 会让口令出现在命令行参数、shell history 或进程列表中；生产压测可接受的前提是：该账号只访问 `benchdb`，压测完成即按 §20.13 删除，且报告中不展示真实口令。若客户安全基线不允许命令行口令，应改用受控环境变量或临时 `.pgpass`，并在清理 checklist 中删除。

### 20.6 sysbench 基准压测示例（按 32GB / 64GB 自动选择参数）

> sysbench 用于基准压测，不能替代业务 SQL 回放。若现场 sysbench 未编译 `pgsql` 驱动，或连接当前 VastBase 版本失败，应改用业务压测工具或 pgbench，并在报告中说明。

**工具验证**：

```bash
sysbench --version
sysbench --help | grep -i pgsql
```



**需要缓存预热插件**

```bash
#缓存预热：优先 pg_prewarm；失败时不阻断压测，再用低并发 warm-up 丢弃结果。
$VB_SQL -h "$DB_HOST" -p "$DB_PORT" -U vbadmin -d "$DB_NAME" <<'EOSQL' | tee "$REPORT_DIR/prewarm.log" || true

CREATE EXTENSION IF NOT EXISTS pg_prewarm;
```



**压测脚本模板**：

```bash
cat > /vastbase/scripts/vb_sysbench_run.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-benchdb}"
DB_USER="${DB_USER:-benchuser}"
DB_PASS="${DB_PASS:-Benchuser@2026}"
LUA="${LUA:-/usr/share/sysbench/oltp_read_write.lua}"
REPORT_ROOT="${REPORT_ROOT:-/vastbase/docs}"
PERF_TEST_CURRENT="${PERF_TEST_CURRENT:-/vastbase/docs/.perf_test_current}"
VB_SQL="${VB_SQL:-vsql}"
MEM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)

if [ "$MEM_GB" -lt 48 ]; then
  TABLES="${TABLES:-32}"
  TABLE_SIZE="${TABLE_SIZE:-1000000}"
  THREAD_STEPS="${THREAD_STEPS:-32 64 128 200}"
  RUN_TIME="${RUN_TIME:-1800}"
else
  TABLES="${TABLES:-64}"
  TABLE_SIZE="${TABLE_SIZE:-1000000}"
  THREAD_STEPS="${THREAD_STEPS:-64 128 256 384}"
  RUN_TIME="${RUN_TIME:-1800}"
fi

REPORT_DIR="${REPORT_DIR:-$(cat "$PERF_TEST_CURRENT" 2>/dev/null || true)}"
if [ -z "$REPORT_DIR" ]; then
  REPORT_DIR="$REPORT_ROOT/perf_test_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$REPORT_DIR"
  echo "$REPORT_DIR" > "$PERF_TEST_CURRENT"
else
  mkdir -p "$REPORT_DIR"
fi
export REPORT_DIR
export PGPASSWORD="$DB_PASS"
SYSBENCH_PERCENTILE="${SYSBENCH_PERCENTILE:-95}"

# sysbench 单次只输出 --percentile 指定的一个分位数；默认跑 P95。
# 报告需要 P99 时，使用同一数据集和并发档设置 SYSBENCH_PERCENTILE=99 复跑，日志会写入 sysbench_p99_threads_*.log。
COMMON_OPTS="--db-driver=pgsql --pgsql-host=$DB_HOST --pgsql-port=$DB_PORT --pgsql-user=$DB_USER --pgsql-password=$DB_PASS --pgsql-db=$DB_NAME --tables=$TABLES --table-size=$TABLE_SIZE --report-interval=10 --percentile=$SYSBENCH_PERCENTILE"

# 防止并发档超过 max_connections，保留 sysadmin 应急连接和至少 20 个运维/监控连接。
MAX_CONN=$($VB_SQL -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -At -c "SHOW max_connections;" 2>/dev/null || echo 0)
MAX_CONN=$(echo "$MAX_CONN" | tr -d '[:space:]')
SYSADMIN_RESERVED=$($VB_SQL -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -At -c "SHOW sysadmin_reserved_connections;" 2>/dev/null || echo 10)
SYSADMIN_RESERVED=$(echo "$SYSADMIN_RESERVED" | tr -d '[:space:]')
SAFE_MAX=0
if [[ "$MAX_CONN" =~ ^[0-9]+$ ]] && [ "$MAX_CONN" -gt 0 ]; then
  [[ "$SYSADMIN_RESERVED" =~ ^[0-9]+$ ]] || SYSADMIN_RESERVED=10
  SAFE_MAX=$((MAX_CONN - SYSADMIN_RESERVED - 20))
  [ "$SAFE_MAX" -lt 1 ] && SAFE_MAX=1
  FILTERED=""
  for th in $THREAD_STEPS; do
    if [ "$th" -le "$SAFE_MAX" ]; then FILTERED="$FILTERED $th"; else echo "[WARN] skip threads=$th, safe_max=$SAFE_MAX" | tee -a "$REPORT_DIR/run.log"; fi
  done
  THREAD_STEPS="${FILTERED# }"
fi
[ -n "$THREAD_STEPS" ] || { echo "[ERROR] THREAD_STEPS empty after max_connections check" | tee -a "$REPORT_DIR/run.log"; exit 2; }
PREPARE_THREADS="${PREPARE_THREADS:-16}"
if [[ "$SAFE_MAX" =~ ^[0-9]+$ ]] && [ "$SAFE_MAX" -gt 0 ] && [ "$PREPARE_THREADS" -gt "$SAFE_MAX" ]; then
  echo "[WARN] reduce prepare threads from $PREPARE_THREADS to safe_max=$SAFE_MAX" | tee -a "$REPORT_DIR/run.log"
  PREPARE_THREADS="$SAFE_MAX"
fi
[ "$PREPARE_THREADS" -lt 1 ] && PREPARE_THREADS=1

{
  echo "[INFO] report dir: $REPORT_DIR"
  echo "[INFO] MEM_GB=$MEM_GB TABLES=$TABLES TABLE_SIZE=$TABLE_SIZE THREAD_STEPS=$THREAD_STEPS RUN_TIME=$RUN_TIME MAX_CONN=$MAX_CONN SYSBENCH_PERCENTILE=$SYSBENCH_PERCENTILE"
} | tee "$REPORT_DIR/run.log"

echo "[INFO] prepare data" | tee -a "$REPORT_DIR/run.log"
sysbench "$LUA" $COMMON_OPTS --threads="$PREPARE_THREADS" prepare | tee "$REPORT_DIR/prepare.log"

# prepare 后强制统计信息刷新，避免 COPY/批量装载后第一档计划失真。
$VB_SQL -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "VACUUM ANALYZE;" \
  | tee "$REPORT_DIR/vacuum_analyze_after_prepare.log" || true

# 记录数据规模；如小于 shared_buffers 的 1.5 倍，应增加 TABLES 或 TABLE_SIZE 后重建。
#$VB_SQL -h "$DB_HOST" -p "$DB_PORT" -U vbadmin -d postgres -At \
#  -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datname IN ('benchdb','appdb') #ORDER BY 1;" \
#  | tee "$REPORT_DIR/db_size_before.txt" || true

# db_size：连到 benchdb 查自己，别连 postgres（§20.5 的 pg_hba 只放行了 benchdb/benchuser，
# benchuser 连 postgres 会在 pg_hba 处被拒）
$VB_SQL -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -At \
  -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" \
  | tee "$REPORT_DIR/db_size_before.txt" || true
  
# 缓存预热：优先 pg_prewarm；失败时不阻断压测，再用低并发 warm-up 丢弃结果。
#$VB_SQL -h "$DB_HOST" -p "$DB_PORT" -U vbadmin -d "$DB_NAME" <<'EOSQL' | tee "$REPORT_DIR/prewarm.log" || true
#CREATE EXTENSION IF NOT EXISTS pg_prewarm;
-- benchuser 的 search_path 为 bench, public。这里按 sysbench 表名前缀精确预热，避免把冷表/大表全部拉入 shared_buffers。
-- pg_prewarm 第一参数为 regclass，直接传 c.oid 即可；同时限制累计预热对象大小 <= shared_buffers × 0.8。
WITH cfg AS (
    SELECT setting::numeric * 8192 * 0.8 AS max_bytes
      FROM pg_settings
     WHERE name = 'shared_buffers'
), rels AS (
    SELECT c.oid,
           pg_total_relation_size(c.oid) AS bytes,
           sum(pg_total_relation_size(c.oid)) OVER (ORDER BY pg_total_relation_size(c.oid) DESC, c.oid) AS cum_bytes
      FROM pg_class c
      JOIN pg_namespace n ON c.relnamespace = n.oid
     WHERE n.nspname = 'bench'
       AND c.relkind IN ('r','i')
       AND c.relname LIKE 'sbtest%'
)
SELECT count(*) AS prewarm_objects,
       pg_size_pretty(coalesce(sum(bytes),0)) AS prewarm_bytes,
       coalesce(sum(pg_prewarm(oid)),0) AS prewarm_blocks
  FROM rels, cfg
 WHERE cum_bytes <= max_bytes;
EOSQL

echo "[INFO] warm-up 5min @ $PREPARE_THREADS threads (results discarded)" | tee -a "$REPORT_DIR/run.log"
sysbench "$LUA" $COMMON_OPTS --threads="$PREPARE_THREADS" --time=300 run > "$REPORT_DIR/warmup_discarded.log" 2>&1 || true

for th in $THREAD_STEPS; do
  log="$REPORT_DIR/sysbench_p${SYSBENCH_PERCENTILE}_threads_${th}.log"
  if [ -s "$log" ] && grep -Eq "general statistics:|execution time" "$log"; then
    echo "[INFO] threads=$th already done, skip" | tee -a "$REPORT_DIR/run.log"
    continue
  fi
  echo "[INFO] run threads=$th" | tee -a "$REPORT_DIR/run.log"
  sleep 60
  sysbench "$LUA" $COMMON_OPTS --threads="$th" --time="$RUN_TIME" run | tee "$log"
done

# 可选：压测完成后清理。正式报告归档前不建议立即 cleanup，便于复测。
# sysbench "$LUA" $COMMON_OPTS cleanup | tee "$REPORT_DIR/cleanup.log"

echo "[INFO] done: $REPORT_DIR" | tee -a "$REPORT_DIR/run.log"
EOF
chmod 750 /vastbase/scripts/vb_sysbench_run.sh

# 如需补齐报告 P99 列：保持同一 REPORT_DIR、同一数据集和并发档，单独复跑 P99。
# export SYSBENCH_PERCENTILE=99
# /vastbase/scripts/vb_sysbench_run.sh
```

执行示例：

```bash
export VB_SQL=${VB_SQL:-vsql}
export DB_HOST=192.168.10.11
export DB_PORT=5432
export DB_NAME=benchdb
export DB_USER=benchuser
export DB_PASS='Benchuser@2026'

/vastbase/scripts/vb_sysbench_run.sh
```

每档日志是独立文件；如果压测中断，重新执行脚本时已生成 `general statistics:` 或 `execution time` 收尾标记的档位会自动跳过，也可删除单档日志后重跑该档。

**稳定性压测（soak）示例**：基准档位找到稳态并发后，可复用 sysbench 脚本跑 4–24 小时。例如 8 小时稳态压测：

```bash
export REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
export THREAD_STEPS="${SOAK_THREADS:-128}"
export RUN_TIME="${SOAK_TIME:-28800}"
/vastbase/scripts/vb_sysbench_run.sh
```

> 若最大 sysbench 表或业务热表已超过 `shared_buffers × 0.8`，脚本中的 `pg_prewarm` 保护条件可能不会预热任何对象；这是为了避免把冷数据强行挤满 shared buffers。此时以 5 分钟 warm-up run 和正式 soak 前的业务预热为准，并在报告中说明。 `pg_prewarm` 扩展可能未随包提供，脚本中的预热失败会以 `|| true` 放行；此时应以 warm-up run 作为兜底预热证据。

### 20.7 业务 SQL/接口回放要求

基准压测只能说明通用能力，最终参数必须经过业务负载验证。业务回放建议至少覆盖：

| 负载类型 | 示例 | 关注指标 |
|----------|------|----------|
| 高频点查 | 按主键/唯一索引查询订单、用户、账户 | QPS、P95/P99、buffer 命中率、CPU |
| 小事务写入 | 下单、状态流转、流水写入 | TPS、WAL 生成速率、锁等待、索引维护成本 |
| 范围查询/分页 | 按时间、机构、状态筛选 | 是否走索引、排序内存、临时文件 |
| 汇总报表 | `GROUP BY`、窗口函数、复杂 JOIN | `work_mem`、临时文件、并行执行、执行计划稳定性 |
| 批处理/导入 | 日终、对账、批量入库、建索引 | WAL、checkpoint、归档、磁盘吞吐、维护内存 |
| 事务冲突 | 同一热点账户/库存/状态行更新 | 锁等待、死锁、重试策略 |

业务回放报告中应记录：接口比例、并发用户、连接池配置、事务比例、读写比例、数据分布、是否有思考时间、是否有缓存预热、错误请求明细。


MySQL 兼容业务回放还必须覆盖以下专有 SQL/行为，不能用 sysbench 结果替代：

| 类别 | 必测项 | 验收关注点 |
|------|--------|------------|
| MySQL DML | `INSERT ... ON DUPLICATE KEY UPDATE`、`REPLACE INTO`、自增列 | 冲突更新、替换语义、自增值连续性 |
| MySQL 查询语法 | `LIMIT offset,count`、大小写访问路径 | 结果顺序、分页边界、`lower_case_table_names` 行为 |
| 日期时间函数 | `STR_TO_DATE`、`DATE_FORMAT`、`FROM_UNIXTIME`、`NOW(6)`、`CURRENT_TIMESTAMP(6)` | 格式、时区、微秒精度 |
| SQL mode | `vastbase_sql_mode` 下严格模式 INSERT、零日期、分组查询 | 与源库 `@@sql_mode` 差异可解释 |
| 兼容参数 | `lower_case_function_names`、`behavior_compat_options` 变更前后 | 对象名、函数名、过程返回行为稳定 |


### 20.8 压测期间监控采集

> **压测机侧资源采集建议**：远程压测时，数据库服务器侧 OS 采集不能证明压测机没有打满。建议在压测机同步运行一份 vmstat/iostat/sar/top 或平台监控采集，并把日志归档到 `$REPORT_DIR/loadgen_os/`，避免把压测机 CPU/网络瓶颈误判为数据库瓶颈。

**OS 采集脚本**：

```bash
cat > /vastbase/scripts/perf_collect_os.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPORT_DIR="${1:-${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR is required. Usage: perf_collect_os.sh <REPORT_DIR>"; exit 2; }
mkdir -p "$REPORT_DIR"

(vmstat 5 > "$REPORT_DIR/vmstat.log" 2>&1 & echo $! > "$REPORT_DIR/vmstat.pid")
(iostat -xmt 5 > "$REPORT_DIR/iostat.log" 2>&1 & echo $! > "$REPORT_DIR/iostat.pid")
(sar -n DEV,TCP,ETCP 5 > "$REPORT_DIR/sar_net.log" 2>&1 & echo $! > "$REPORT_DIR/sar_net.pid") || true
(top -b -d 5 > "$REPORT_DIR/top.log" 2>&1 & echo $! > "$REPORT_DIR/top.pid")

echo "$REPORT_DIR"
EOF
chmod 750 /vastbase/scripts/perf_collect_os.sh
```

启动采集（必须传入统一 `REPORT_DIR`）：

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
/vastbase/scripts/perf_collect_os.sh "$REPORT_DIR" | tee "$REPORT_DIR/os_collect_start.log"
```

停止采集：

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
for pidfile in "$REPORT_DIR"/{vmstat,iostat,sar_net,top}.pid; do
  [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null || true
done
ps -ef | grep -E 'vmstat|iostat|sar|top' | grep -v grep | tee "$REPORT_DIR/os_collect_process_after.txt" || true
```


**数据库采集 SQL**：

```sql
-- /vastbase/scripts/sql/perf_collect_db.sql
\pset pager off
\timing on

SELECT now() AS collect_time;
SELECT version();
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW work_mem;
SHOW maintenance_work_mem;
SHOW max_connections;
SHOW max_worker_processes;
SHOW max_parallel_workers;
SHOW max_parallel_workers_per_gather;
-- SHOW max_wal_size;
SHOW checkpoint_timeout;
SHOW checkpoint_completion_target;
SHOW autovacuum_max_workers;
SHOW enable_resource_track;
SHOW track_stmt_stat_level;
SHOW enable_resource_record;
SHOW instr_unique_sql_count;
SHOW track_activity_query_size;
SHOW enable_wdr_snapshot;
SHOW huge_pages;
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';

SELECT name, setting, unit, context
  FROM pg_settings
 WHERE name IN ('enable_resource_track','track_stmt_stat_level','enable_resource_record','instr_unique_sql_count','track_activity_query_size','enable_wdr_snapshot','wdr_snapshot_interval','wdr_snapshot_retention_days','shared_preload_libraries')
 ORDER BY name;

SELECT s.datname, s.numbackends, s.xact_commit, s.xact_rollback,
       s.blks_read, s.blks_hit,
       s.tup_returned, s.tup_fetched, s.tup_inserted, s.tup_updated, s.tup_deleted,
       s.conflicts, s.deadlocks, s.temp_files, pg_size_pretty(s.temp_bytes) AS temp_bytes
  FROM pg_stat_database s
  JOIN pg_database d ON d.datname = s.datname
 WHERE d.datistemplate = false
 ORDER BY s.datname;

-- 默认采集除 template 库外的全部数据库，适配 appdb_report、appdb_archive 等多业务库场景。
-- 如现场只允许采集指定业务库，可把上一段 WHERE 改为：WHERE d.datistemplate = false AND d.datname IN ('postgres','appdb','benchdb')。
-- 如当前 openGauss/VastBase 老版本的 pg_stat_database 不含 temp_bytes，可改查 dbe_perf.stat_database，或临时注释 temp_bytes 本列并在报告中说明。

SELECT pid, usename, datname, state, wait_event, wait_event_type,
       now() - xact_start AS xact_age,
       now() - query_start AS query_age,
       left(query, 200) AS query_sample
  FROM pg_stat_activity
 WHERE state <> 'idle'
 ORDER BY query_age DESC NULLS LAST
 LIMIT 30;

SELECT locktype, mode, granted, count(*)
  FROM pg_locks
 GROUP BY locktype, mode, granted
 ORDER BY locktype, mode, granted;

-- 归档健康：openGauss 内核无 pg_stat_archiver 视图（查询会报 relation does not exist）。
-- 归档信号在 shell 侧采集（archive_status 下 .ready 堆积量 + 归档目录文件数），见下方采集脚本的 collect_arch 段。

-- checkpoint/bgwriter 计数器：用于量化 checkpoints_timed/checkpoints_req、buffers_checkpoint 等指标。
-- 如当前版本无 pg_stat_bgwriter，可在报告中标注 N/A，并保留日志 checkpoint 警告作为补充证据。
SELECT * FROM pg_stat_bgwriter;
```

执行采集：

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
mkdir -p "$REPORT_DIR"

# 归档健康 shell 侧采集（openGauss 内核无 pg_stat_archiver，改采 archive_status 下 .ready 堆积量 + 归档目录文件数）。
# 需运行用户可读 $PGDATA；source backup.env 取 PGDATA。
collect_arch() {
    local tag="$1"
    source /vastbase/scripts/backup.env 2>/dev/null || true
    local astat=""
    if   [ -d "${PGDATA:-}/pg_xlog/archive_status" ]; then astat="${PGDATA}/pg_xlog/archive_status"
    elif [ -d "${PGDATA:-}/pg_wal/archive_status"  ]; then astat="${PGDATA}/pg_wal/archive_status"
    fi
    {
        echo "== archive health @ ${tag} : $(date '+%F %T') =="
        if [ -n "$astat" ]; then
            echo "ready_count=$(find "$astat" -maxdepth 1 -name '*.ready' -type f 2>/dev/null | wc -l)  (dir=$astat)"
        else
            echo "ready_count=N/A  (archive_status not found under \$PGDATA=${PGDATA:-unset})"
        fi
        echo "arch_files=$(ls -1 /vastbase/arch 2>/dev/null | wc -l)  arch_dir_used=$(df -P /vastbase/arch 2>/dev/null | awk 'NR==2{print $5}')"
    } >> "$REPORT_DIR/arch_health.log"
}

$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres \
  -f /vastbase/scripts/sql/perf_collect_db.sql \
  > "$REPORT_DIR/db_collect_before.log" 2>&1
collect_arch before

# 压测中：按并发档、业务场景或采集序号生成 NN 编号，便于和 sysbench/JMeter 档位对应。
STEP="${STEP:-01}"
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres \
  -f /vastbase/scripts/sql/perf_collect_db.sql \
  > "$REPORT_DIR/db_collect_during_$(printf '%02d' "$STEP").log" 2>&1
collect_arch "during_$(printf '%02d' "$STEP")"

# 压测后：结束负载、创建 end WDR snapshot 后再采集一次。
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres \
  -f /vastbase/scripts/sql/perf_collect_db.sql \
  > "$REPORT_DIR/db_collect_after.log" 2>&1
collect_arch after
```

**WDR 报告采集**：

> 如 §12.10 已启用 WDR，且 `SHOW enable_wdr_snapshot;`、`SHOW wdr_snapshot_interval;`、`SHOW wdr_snapshot_retention_days;` 已满足压测要求，可直接跳到 `create_wdr_snapshot()`，不要重复触发不必要的 restart。若 `pg_settings.context` 为 `sighup`，只需 reload；若为 `postmaster`，必须把 restart 证据写入报告。

```bash
# 压测前统一用 $VB_GUC 持久化，不使用 ALTER SYSTEM，避免 postgresql.auto.conf 优先级差异。
$VB_GUC set -D $PGDATA -c "enable_wdr_snapshot = on"
$VB_GUC set -D $PGDATA -c "wdr_snapshot_interval = 30"
$VB_GUC set -D $PGDATA -c "wdr_snapshot_retention_days = 8"

WDR_CONTEXT=$($VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -At \
  -c "SELECT context FROM pg_settings WHERE name='enable_wdr_snapshot';" 2>/dev/null || echo postmaster)
if [ "$WDR_CONTEXT" = "postmaster" ]; then
  $VB_CTL restart -D $PGDATA -m fast
else
  $VB_CTL reload -D $PGDATA
fi

$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres \
  -c "SHOW enable_wdr_snapshot; SHOW wdr_snapshot_interval; SHOW wdr_snapshot_retention_days;"

# 生成 WDR 文件时通过 -v report_dir="$REPORT_DIR" 传入统一目录。
```

```sql
-- 压测前创建 begin snapshot
SELECT create_wdr_snapshot();
SELECT snapshot_id, start_ts, end_ts FROM snapshot.snapshot ORDER BY snapshot_id DESC LIMIT 5;

-- 压测结束后创建 end snapshot
SELECT create_wdr_snapshot();
SELECT snapshot_id, start_ts, end_ts FROM snapshot.snapshot ORDER BY snapshot_id DESC LIMIT 5;

-- 用 psql/vsql 变量替代裸数字，避免误复制。
\set begin_snap  101    -- 替换为上方查询到的起始 snapshot_id
\set end_snap    102    -- 替换为上方查询到的结束 snapshot_id
-- 执行本段时建议用：$VB_SQL ... -v report_dir="$REPORT_DIR"

\a
\t
\o :report_dir/wdr_cluster.html
-- 5 个入参：begin_id, end_id, report_type('all'/'summary'/'detail'),
--          report_scope('cluster'/'node'), node_name（cluster 模式下传 NULL）
SELECT generate_wdr_report(:begin_snap, :end_snap, 'all', 'cluster', NULL);
\o
\a
\t
```

> `generate_wdr_report()` 的入参和可见 schema 受版本、权限和兼容模式影响，现场必须先用 `\df *generate_wdr_report*`、`\dn snapshot`、`SELECT * FROM snapshot.snapshot LIMIT 1;` 验证。若 `enable_wdr_snapshot` 的 context 为 `postmaster`，必须把 restart 证据写入压测报告。

### 20.9 结果提取与报告归档

sysbench 日志可先用以下命令提取核心指标，最终仍需结合 OS/WDR/慢 SQL 证据分析：

> 重要口径：sysbench 单次只输出 `--percentile` 指定的一个分位数。本文脚本默认 `SYSBENCH_PERCENTILE=95`，只能填报告中的 P95；P99 需在相同数据集、相同并发档下设置 `SYSBENCH_PERCENTILE=99` 单独复跑，或由 JMeter/业务压测平台提供完整 P95/P99。禁止把 P95 结果直接填入 P99 列。

```bash
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
mkdir -p "$REPORT_DIR"
echo "percentile,threads,tps,qps,latency_p,errors,reconnects" | tee "$REPORT_DIR/sysbench_summary.csv"
for f in "$REPORT_DIR"/sysbench_p*_threads_*.log; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  pct=$(echo "$base" | sed -E 's/^sysbench_p([0-9]+)_threads_.*/\1/')
  th=$(echo "$base"  | sed -E 's/^sysbench_p[0-9]+_threads_([0-9]+)\.log/\1/')
  tps=$(grep -E "transactions:" "$f" | awk -F'\(' '{print $2}' | awk '{print $1}')
  qps=$(grep -E "queries:" "$f" | awk -F'\(' '{print $2}' | awk '{print $1}')
  lat=$(grep -E "${pct}th percentile:" "$f" | awk '{print $3}')
  errors=$(grep -E "ignored errors:" "$f" | awk '{print $3}')
  reconnects=$(grep -E "reconnects:" "$f" | awk '{print $2}')
  echo "$pct,$th,$tps,$qps,$lat,$errors,$reconnects"
done | tee -a "$REPORT_DIR/sysbench_summary.csv"
```

报告和证据建议归档到：

```text
/vastbase/docs/perf_test_<YYYYMMDD_HHMMSS>/
├── perf_test_report_<YYYYMMDD>.md
├── fio_data_randread_4k.log
├── fio_wal_write_16k_fsync.log
├── fio_wal_write_8k_1job_fsync.log
├── fio_wal_write_8k_4job_fsync.log
├── params_before.tsv
├── params_after.tsv
├── params_final.tsv
├── sysbench_p95_threads_*.log
├── sysbench_p99_threads_*.log（如需填 P99，由 SYSBENCH_PERCENTILE=99 复跑生成）
├── sysbench_summary.csv
├── db_collect_before.log
├── db_collect_during_NN.log
├── db_collect_after.log
├── vmstat.log
├── iostat.log
├── sar_net.log
├── top.log
├── wdr_cluster.html
├── tuning_change_record.tsv
└── perf_test_cleanup_checklist.tsv
```

### 20.10 压测通过标准

| 类别 | 建议通过标准 | 未通过时优先排查 |
|------|--------------|------------------|
| 业务 SLA | P95/P99、TPS/QPS 达到业务验收阈值 | SQL、索引、连接池、热点锁、I/O |
| 错误率 | 基准压测错误率为 0；业务压测低于业务定义阈值 | 连接数、认证、SQL 兼容、锁等待、超时 |
| CPU | OLTP：稳态 ≤75%，峰值 ≤85%；混合：稳态 ≤80%，峰值 ≤90%；OLAP/批处理：稳态 ≤85%，短时峰值可接受 ≤95% | SQL 执行计划、并发过高、连接池、并行策略 |
| 内存 | 无 OOM；swap 不持续增长；cache/buffer 稳定 | `work_mem`、`max_connections`、批量作业、内存泄漏 |
| 磁盘 I/O | await/util 不长时间满载；WAL 和数据盘无持续瓶颈；与 fio 基线对比可解释 | checkpoint、WAL、索引、存储性能、归档链路 |
| WAL/归档 | `archive_status/` 下 `.ready` 无持续堆积；归档目录无堆积 | 归档命令、远端链路、归档盘容量、WAL 生成速率 |
| checkpoint | 日志无频繁 checkpoint 警告，写入延迟无周期性尖刺 | `max_wal_size`、`checkpoint_timeout`、磁盘写入能力 |
| 锁等待 | 无持续长锁等待，死锁为 0 或有明确业务解释 | 事务边界、热点行、索引缺失、批处理窗口 |
| 临时文件 | 临时文件量可解释，不因排序/hash 溢出导致延迟失控 | `work_mem`、SQL 改写、索引、统计信息 |
| 稳定性 | 4–24 小时无异常退出、无归档堆积、无日志爆量 | 资源泄漏、日志级别、监控、备份/归档策略 |

### 20.11 参数优化闭环

压测调参必须遵循“**一次只改一类参数、同一负载复测、保留证据、可回滚**”原则。

| 现象 | 可能原因 | 优先动作 | 相关参数/对象 |
|------|----------|----------|----------------|
| 并发升高后 TPS 不升反降 | 连接争用、CPU 饱和、锁等待 | 控制连接池，降低无效并发，分析锁等待和 TOP SQL | `max_connections`、应用连接池、索引、事务范围 |
| 大量临时文件，报表延迟高 | 排序/hash 溢出 | 先优化 SQL/索引，再小步上调 `work_mem` | `work_mem`、`log_temp_files`、统计信息 |
| 写入压测出现周期性卡顿 | checkpoint 过频或 WAL 盘瓶颈 | 增大 `max_wal_size`，平滑 checkpoint，检查 WAL/归档盘 | `max_wal_size`、`checkpoint_timeout`、`checkpoint_completion_target` |
| 归档目录堆积 | 归档命令慢、远端网络慢、WAL 生成过快 | 提升归档链路，拆分归档盘，评估压缩和同步策略 | `archive_command`、归档盘、rsync/网络 |
| CPU 高但 I/O 低 | SQL 计划差、函数计算重、并发过高 | 生成 WDR，查看 TOP SQL，补统计信息和索引 | `default_statistics_target`、`ANALYZE`、索引 |
| 读 I/O 高、命中率低 | 热数据超过内存、索引缺失、扫描过多 | 核查 SQL 和索引，再评估 `shared_buffers` | `shared_buffers`、`effective_cache_size`、索引 |
| swap 增长或内存逼近上限 | 并发连接 × `work_mem` 过大 | 降低 `work_mem`/连接数，限制批处理并发 | `work_mem`、`max_connections`、连接池 |
| 报表/汇总 P95 抖动大 | 并行度不足或并行 worker 争用 | 分场景评估并行参数；OLTP 与 OLAP 分开复测 | `max_parallel_workers_per_gather`、`max_parallel_workers` |
| 死元组增长快 | 高更新表 autovacuum 跟不上 | 设置表级 autovacuum，降低膨胀，安排维护窗口 | autovacuum 表级参数、`fillfactor` |

参数调整记录模板：

涉及 `behavior_compat_options`、`b_compatibility_mode`、`vastbase_sql_mode`、`lower_case_table_names`、`lower_case_function_names` 等兼容行为参数的变更，`是否触发兼容回归测试` 必须填“是”，并在报告附件中提供核心 SQL 回归结果。

| 时间 | 变更项 | 调整前 | 调整后 | 调整原因 | 复测结果 | 是否触发兼容回归测试 | 是否保留 | 回滚方式 |
|------|--------|--------|--------|----------|----------|--------------------------|----------|----------|
|      |        |        |        |          |          | 是 / 否                  |          |          |

### 20.12 压测报告模板

压测报告必须按标准模板 `/vastbase/docs/templates/VastBase-G100-performance-test-report-template-v1_5.md` 输出，归档路径建议为 `$REPORT_DIR/perf_test_report_<YYYYMMDD>.md`。

本节不再内嵌简化模板，避免与独立标准模板分叉。标准模板应作为交付物纳入 §22，报告至少包含：测试环境、裸盘 I/O 基线、参数快照、兼容相关参数、压测结果、数据库侧观测、WDR TOP SQL、调参记录、风险限制、附件清单和签字确认。

### 20.13 压测清理与投产前定稿

压测完成并确认不再复测后，必须清理临时对象、临时访问规则和临时观测参数，并把清理证据写入 `$REPORT_DIR/perf_test_cleanup_checklist.tsv`。

```sql
-- 确认无业务依赖后再执行
DROP DATABASE IF EXISTS benchdb;
DROP USER IF EXISTS benchuser;
```

```bash
# 删除 pg_hba.conf 中 benchuser/压测机临时规则后 reload
$VB_CTL reload -D $PGDATA

# 恢复压测期间临时调低的慢 SQL 阈值，示例按 1000ms 恢复
$VB_GUC set -D $PGDATA -c "log_min_duration_statement = 1000"
$VB_CTL reload -D $PGDATA

# 恢复压测前保存的 crontab
# crontab -u vastbase "$REPORT_DIR/crontab_before_perf_test.txt"
# crontab -u root "$REPORT_DIR/root_crontab_before_perf_test.txt"

# 停止 OS 采集后台进程；压测报告中需保留 ps 输出作为证据。
REPORT_DIR="${REPORT_DIR:-$(cat /vastbase/docs/.perf_test_current 2>/dev/null || true)}"
[ -n "$REPORT_DIR" ] || { echo "ERROR: REPORT_DIR not set; run the §20 unified REPORT_DIR block first"; exit 2; }
for pidfile in "$REPORT_DIR"/{vmstat,iostat,sar_net,top}.pid; do
  [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null || true
done
ps -ef | grep -E 'vmstat|iostat|sar|top' | grep -v grep | tee "$REPORT_DIR/os_collect_process_after.txt" || true

# 留存最终参数
$VB_SQL -h 127.0.0.1 -p 5432 -U vbadmin -d postgres -At \
  -c "SELECT name,setting,unit,context FROM pg_settings ORDER BY name;" \
  > "$REPORT_DIR/params_final.tsv"
```

压测清理 checklist：

| 清理项 | 处理要求 | 证据 |
|--------|----------|------|
| 临时 `pg_hba.conf` 规则 | 删除或注释压测机、`benchuser` 规则，并 reload | `pg_hba_before/after`、reload 输出 |
| `benchdb` / `benchuser` | 无复测需求时删除；若保留需业务批准 | `DROP` 输出或保留审批 |
| 临时防火墙规则 | 删除压测机临时白名单 | `firewall-cmd --list-all` 前后对比 |
| `log_min_duration_statement` | 从压测临时值恢复到运维基线 | `SHOW log_min_duration_statement;` |
| WDR 开关 | 一般压测后关闭；若 PITR/性能诊断要求保留 on，需写明原因和保留周期 | `SHOW enable_wdr_snapshot;`、审批说明 |
| 备份/巡检 cron | 恢复压测前停用的 vastbase/root cron、`/etc/cron*` 和客户备份/巡检平台任务 | `crontab -u vastbase -l`、`crontab -u root -l`、平台恢复截图 |
| OS 采集进程 | 停止 `vmstat`/`iostat`/`sar`/`top` 后台进程 | `ps -ef | grep -E 'vmstat|iostat|sar|top' | grep -v grep` 输出为空 |
| 临时数据文件 | 删除 fio/sysbench 临时数据；保留报告目录证据 | `find`/`ls` 输出 |
| 参数定稿单 | `params_final.tsv` 与 `postgresql.conf` / `$VB_GUC` 内容一致 | `SHOW` 输出、配置文件摘要 |

投产前必须完成以下确认：

1. 压测报告已归档，结论为“通过”或“有条件通过且限制条件已被业务接受”。
2. 最终参数已写入 `postgresql.conf` 或通过 `$VB_GUC` 固化，重启/重载后 `SHOW` 结果一致。
3. 应用连接池参数与数据库 `max_connections` 匹配，保留 DBA 应急连接。
4. 慢 SQL、WDR、OS 指标、fio 基线和压测原始日志已归档到 `$REPORT_DIR/`。
5. 压测临时账号、临时防火墙/`pg_hba.conf` 规则、临时 cron 变更和临时数据已按 checklist 清理并形成交付证据。

---
## 21. 高可用、连接池与读写分离规划（范围说明）

> 本文档的范围是 **单实例部署**。若客户对可用性 / 性能有更高要求，下列方案应在交付前由方案组与 DBA 一起评审。这里只给出规划边界与选型提示，落地配置另立 HA 设计文档。

### 21.1 连接池：为什么必须考虑

VastBase 每个连接是独立后端进程，内存占用与 `work_mem` 强相关。**应用直连 + `max_connections = 1000+` 是典型反模式**：

- 连接建立/销毁开销大，OLTP 抖动；
- `work_mem` × 真实并发可能撑爆内存；
- 慢 SQL 持锁时占用连接资源呈指数级放大；
- VACUUM/autovacuum 在高连接数下排队严重。

**推荐**：应用层使用连接池（HikariCP / Druid / Tomcat JDBC pool）+ 中间连接池二选一：

| 方案 | 说明 | 适用 |
|------|------|------|
| 仅应用池 | 配置 maxActive=50，每个应用实例独立池 | 单应用、应用实例数 ≤ 10 |
| PgBouncer（开源） | 部署在 DB 主机或独立 VIP 后，transaction-pooling 模式 | 多应用、连接数膨胀 |
| Pgpool-II（开源） | 同时支持读写分离与连接池 | 有主备时统一接入 |
| 客户提供的国产中间件 | 按客户基线 | 等保/信创环境 |

**PgBouncer 关键参数**：

```ini
[databases]
appdb = host=127.0.0.1 port=5432 dbname=appdb

[pgbouncer]
listen_port = 6432
auth_type = md5                      # 或 scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction              # 推荐 transaction（注意 prepared statement / temp table）
max_client_conn = 2000
default_pool_size = 50               # 后端到数据库的最大连接，应 <= max_connections * 0.6
reserve_pool_size = 10
server_idle_timeout = 600
```

> `pool_mode = transaction` 下，session 级 GUC / `SET LOCAL` 之外的 `SET`、临时表、advisory lock 行为会受影响。**上线前必须做兼容性测试**。

### 21.2 主备流复制（HA 第一步）

VastBase / openGauss 的主备同步与 PostgreSQL 流复制基本一致：

| 角色 | 说明 |
|------|------|
| Primary（主） | 处理读写，生成 WAL |
| Standby（备） | 物理复制，read-only；可作为热备查询节点 |
| Cascaded Standby | 备的下游备，分担同步压力 |

**最小可用配置（primary 侧）**：

```ini
wal_level                 = replica        # 已配置
max_wal_senders           = 10
#wal_keep_size             = 4GB            # 备库短暂断连时 WAL 保留量 #PG13 参数
wal_keep_segments = 256    # ≈ 256 × 16MB = 4GB；本版以 vb_guc --help / pg_settings 实际为准
hot_standby               = on
synchronous_commit        = on             # 想要“零数据丢失”时设 remote_apply
synchronous_standby_names = 'standby01'    # 同步备库名（如启用同步复制）
```

> ⚠️ 单备 `synchronous_standby_names='standby01'` 的同步复制风险很高：备库故障或网络抖动会立即阻塞主库 commit，业务连接可能整体 hang。生产建议使用 `ANY 1 (s1,s2)` 这类多备仲裁式同步；若只有一个备库，优先评估 `synchronous_commit=local` 或 `remote_write` 并接受 RPO>0。同步策略变更必须做“踢掉备库验证主库阻塞行为”的演练。

pg_hba.conf 放行：

```conf
host    replication   repuser   192.168.10.12/32   sha256
```

**搭建备库**：

```bash
# 在 standby 主机
$VB_BASEBACKUP -h <primary_ip> -p 5432 -U repuser -D $PGDATA \
               -F p -X stream -R -P
$VB_CTL start -D $PGDATA
# -R 自动写入 standby 配置文件
```

> 注意：本版 `vb_basebackup --help` 未列出 `-R`（实测 V3.0.8PSU4 的选项仅到 `-c/-l/-P/-v`）。若本版不支持 `-R`，需在 basebackup 完成后**手工**写备库配置：openGauss 内核通常是在 `$PGDATA` 下创建 `standby.signal`（或老式 `recovery.conf`，视本版而定，以 `vb_ctl build`/官方搭备文档为准）并在 `postgresql.conf`/`recovery.conf` 写入 `primary_conninfo`。本块仅为 L1 文档的方向性示意，正式主备搭建以独立 HA/DR 设计文档与本版官方搭备流程（如 `gs_ctl build -b full` / `gs_om`）为准。

**切换/接管**（switchover/failover）：建议用 VastBase 提供的 `gs_om` 工具或 patroni 风格的仲裁机制，**不要靠人工 `$VB_CTL promote`** 在生产做切换。

### 21.3 读写分离

实现路径：

1. **应用层路由**：业务自己识别“读”与“写”，分别走主/备 DSN。开发改造量大但最可控。
2. **中间件路由**：Pgpool-II、ShardingSphere-Proxy、客户国产中间件。
3. **DB 侧 VIP + LB**：HAProxy/keepalived 提供 read VIP（轮询所有 standby）+ write VIP（指向 master）。

**注意事项**：

- 备库有同步延迟，强一致读必须走主库；
- 长查询打到备库会推迟 WAL apply，超过 `max_standby_streaming_delay` 会被取消；
- 备库上的查询会受到 vacuum cleanup 锁影响（`hot_standby_feedback = on` 可缓解但会让主库膨胀）。

### 21.4 容灾（DR）拓扑参考

| 等级 | 拓扑 | RPO | RTO | 备注 |
|------|------|-----|-----|------|
| L1 | 单实例 + 异地逻辑/物理备份（本文档） | ≤ 24h | ≤ 4h | 适合内部系统 |
| L2 | 同城主备（同步流复制）+ 异地备份 | 0 | < 10min | 推荐生产基线 |
| L3 | 同城主备 + 异地备节点（异步流复制） | 秒级 | < 30min | 关键业务 |
| L4 | 多数据中心 + 仲裁 + 自动切换 | 0 | < 5min | 金融级 |

> **本文档**对应 **L1**。客户业务确定为 L2/L3/L4 时，必须输出独立的 HA/DR 设计文档，覆盖：复制拓扑、仲裁机制、心跳与脑裂保护、客户端透明切换、演练计划。

### 21.5 连接池/HA 与本文档脚本的衔接

部署连接池或主备后，本文档脚本需要同步调整：

- `backup.env` 中 `PG_HOST` 指向 **主库**，不要指向 PgBouncer（pool_mode=transaction 与 `pg_dump` 不兼容）；
- `db_backup.sh` 中应额外检查主备延迟，备份前 `SELECT pg_is_in_recovery()` 必须为 `f`；
- `pg_hba.conf` 增加 `replication` 条目，主备双方互信；
- 监控脚本 `monitor.sh` 增补：“主备延迟（`pg_xlog_location_diff(pg_current_xlog_location(), replay_location)`，openGauss 内核 xlog 命名）、replication slot 状态、备库可达性”。

---

## 22. 交付物清单与运维交接

| 交付物 | 路径/形式 | 说明 |
|--------|-----------|------|
| 部署文档 | 本文档 | 与现场实际值一致，目录应包含第 20 章性能压测闭环 |
| 参数清单 | `/vastbase/docs/params_<YYYYMMDD>.txt` | `SHOW ALL`、关键 OS 参数 |
| 标准压测报告模板 | `/vastbase/docs/templates/VastBase-G100-performance-test-report-template-v1_5.md` | 第 20 章统一引用的标准模板，不再使用内嵌简化模板 |
| 压测报告 | `$REPORT_DIR/perf_test_report_<YYYYMMDD>.md` | 包含基准压测、业务回放、稳定性观察、调参记录和最终建议 |
| 压测原始证据 | `$REPORT_DIR/` | sysbench_p95/sysbench_p99/业务压测日志、fio 4K/16K/8K 基线、iperf3 网络基线、OS 采集、`db_collect_before.log`、`db_collect_during_NN.log`、`db_collect_after.log`、WDR 报告、参数快照 |
| 压测清理 checklist | `$REPORT_DIR/perf_test_cleanup_checklist.tsv` | 临时 `pg_hba`、防火墙、`benchdb/benchuser`、vastbase/root cron、OS 采集进程、WDR、慢 SQL 阈值等清理证据 |
| 压测临时变更前后对比 | `pg_hba_before.conf`、`pg_hba_after.conf`、`crontab_before_perf_test.txt`、`crontab_after_perf_test.txt`、`root_crontab_before_perf_test.txt`、`root_crontab_after_perf_test.txt` | 与标准报告模板 §13/§14 对齐，便于交付核验 |
| 参数定稿单 | `$REPORT_DIR/params_final.tsv` | 压测后最终 `pg_settings` 快照，与生产 `postgresql.conf` 保持一致 |
| 安装介质校验 | `/vastbase/tools/*.sha256` | 安装包与 license 校验 |
| 配置备份 | `/vastbase/docs/config_bak/` | postgresql.conf、pg_hba.conf、service、firewalld |
| 备份脚本 | `/vastbase/scripts/` | backup.env、databases.list、db_backup.sh、db_restore.sh、db_basebackup.sh、pitr_restore.sh、archive_wal.sh、wal_archive_bloat_check.sh、wal_cleanup.sh、backup_verify.sh |
| 监控/预检脚本 | `/vastbase/scripts/` | monitor.sh、precheck_assert.sh、precheck_os.sh、license_check.sh、archive_check.sh |
| `initdb` / 工具 `--help` 证据 | `/vastbase/docs/evidence/` | `vb_initdb_help_*` 等 V3.0.8PSU4 命令语义证据，支撑 `--pwfile`/兼容模式参数验收 |
| 巡检 SQL | `/vastbase/scripts/sql/` | precheck_db.sql、daily_report.sh、perf_collect_db.sql 等 |
| SSL 证书 | `$PGDATA/server.crt`、`ca.crt` | 生产应换为客户 CA 签发 |
| 验收报告 | `/vastbase/docs/acceptance_<YYYYMMDD>.md` | 第 13 章执行结果，需引用第 20 章压测结论 |
| 恢复演练记录 | `/vastbase/docs/restore_drill_<YYYYMMDD>.md` | 每月至少一次 |
| 运维账号清单 | 受控密码系统 | 不在文档明文保存 |
| HA/DR 设计文档 | 另文 | 仅当客户需求超出 L1 时输出 |

---
## 23. 附录：脚本落地与语法验证清单

将本文脚本复制到服务器后，建议按以下顺序执行一次“脚本级验收”，避免上线后才发现变量、权限或命令名差异。

### 23.1 文件权限标准

```bash
chown -R vastbase:dbgrp /vastbase/scripts /vastbase/log/backup /vastbase/backup
find /vastbase/scripts -type f -name '*.sh' -exec chmod 750 {} \;
chmod 640 /vastbase/scripts/backup.env /vastbase/scripts/databases.list
chmod 600 /home/vastbase/.pgpass
```

### 23.2 语法检查

```bash
for f in /vastbase/scripts/*.sh; do
  echo "bash -n $f"
  bash -n "$f" || exit 1
done
```

### 23.3 公共变量检查

```bash
su - vastbase -c '
  source /vastbase/scripts/backup.env
  require_cmds VB_SQL VB_CTL VB_DUMP VB_DUMPALL VB_RESTORE VB_BASEBACKUP VB_TAR
  echo "PG_HOST=$PG_HOST PG_PORT=$PG_PORT PG_USER=$PG_USER"
'
```

### 23.4 数据库连通性检查

```bash
su - vastbase -c '
  source /vastbase/scripts/backup.env
  vb_sql postgres -c "SELECT version();"
  vb_sql postgres -c "SELECT pg_is_in_recovery();"
'
```

### 23.5 备份恢复演练证据模板

| 项目 | 结果 | 证据路径/命令输出 |
|------|------|------------------|
| 手工逻辑备份 | 通过 / 未通过 | `/vastbase/log/backup/backup_*.log` |
| 本地 `BACKUP.OK` | 通过 / 未通过 | `/vastbase/backup/YYYY-MM-DD/BACKUP.OK` |
| 远端 `BACKUP.OK` | 通过 / 未通过 | `ssh ${REMOTE_HOST} ls ${REMOTE_DIR}/YYYY-MM-DD/` |
| `vb_restore -l` 校验 | 通过 / 未通过 | `/vastbase/log/backup/verify_*.log` |
| 异名恢复演练 | 通过 / 未通过 | `db_restore.sh -d appdb -n appdb_drill -F` |
| 物理备份 | 通过 / 未通过 | `/vastbase/backup/base/YYYY-MM-DD_HHMMSS/BASEBACKUP.OK` |
| PITR 演练 | 通过 / 未通过 | `/vastbase/log/backup/pitr_*.log` |
| 归档监控 | 通过 / 未通过 | `archive_check.sh` 输出 |
| `pg_xlog` 膨胀/归档失败专项排查 | 通过 / 未通过 | `wal_archive_bloat_check.sh` 输出，重点保留 `.ready/.done`、最老/最新 WAL、`wal_archive.log` 与数据库归档参数证据 |
| 综合监控 | 通过 / 未通过 | `monitor.sh` 输出 |

> 验收时必须把上述证据归档到 `/vastbase/docs/acceptance_YYYYMMDD.md`，并由 DBA、系统工程师、应用负责人共同确认。

---

## 24. 参考资料

1. VastBase G100 V3.0 Build 8 Patch No.4（V3.0.8PSU4）发布说明：版本发布日期、升级方式、新增工具选项、GUC 与行为变更说明。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V3.0.8/1/a183929e40fc4be4bebd5bbcd45ee751`
2. VastBase G100 官方知识中心：产品介绍、安装部署、管理运维、安全管理、工具参考与兼容性说明。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/`
3. VastBase G100 安装指南：单机安装、环境准备、安装和配置、集群部署说明。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V2.2.15/1/a7ef717f568b4e8e8bb8314004cc1559`
4. VastBase G100 初始化数据库：`vb_initdb` 初始化数据库并指定兼容模式，实例创建后仅提供该兼容模式特有功能。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V3.0.8/1/df83d799ccb9426eb231b35bb775e246`
5. VastBase G100 客户端接入认证：`pg_hba.conf`、`host/hostssl/reject`、`sha256/sm3/scram-sha256`、SSL 连接配置。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V3.0.9/1/b068ec11958a40f18ef38db8c8a838a8`
6. VastBase G100 逻辑备份 `vb_dump`：导出格式、压缩、恢复工具、注意事项。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V2.2.15/1/570e1c4bc33646828c7c2eb764bbdfe1`
7. VastBase G100 物理备份与恢复：`vb_basebackup`、`vb_probackup`、PITR 与归档 WAL。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V2.2.15/1/d98c8a9e7c6c4ef187553d80d678a8a5`
8. VastBase G100 PITR 指定时间点恢复：基础备份、归档日志、`recovery.conf`、`restore_command`、目标时间/事务/LSN。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V3.0.8/1/d9e94b93d7c344908afb935cf7093ebe`
9. VastBase G100 操作审计：`audit_enabled`、审计项、审计日志、三权分立与审计管理员权限。  
   `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V3.0.8/1/2f4fb0e4adcc49f8b19dd4710f2a6549`
10. VastBase G100 MySQL 兼容性：MySQL 兼容特性总览、数据类型、函数、SQL 语法、PLSQL、UTF8MB4 与兼容性参数。  
      `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V3.0.8/1/9363aeb3a4264c468b93079db61cdf6e`
11. VastBase G100 MySQL 兼容性参数：`b_compatibility_mode`、`lower_case_table_names`、`enable_set_variable_b_format`、`vastbase_sql_mode` 等。  
      `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V2.2.15/1/4d9790983b0842fd81a08aa6ce48bbcf`
12. VastBase G100 MySQL 兼容 CREATE TABLE：`AUTO_INCREMENT`、`COMMENT`、`KEY/INDEX`、`ON UPDATE CURRENT_TIMESTAMP` 等。  
      `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V3.0.8/1/7250661905044daa92e83f5026a6d30b`
13. VastBase G100 WDR Snapshot：`enable_wdr_snapshot`、`snapshot.snapshot`、`snapshot.create_wdr_snapshot()`、`generate_wdr_report()`。  
      `https://docs.vastdata.com.cn/zh_CN/VastbaseG100/V2.2.10/1/54f698382ff242d2bb2cfdf36bba4bea`
14. openGauss 工具参考：`gs_initdb`、`gs_dump`、`gs_restore`、`gs_ctl` 等命令语法可作为生态参考；现场以 VastBase 安装包实际命令为准。

---

**文档维护说明**：本文档已按 VastBase G100 V3.0.8PSU4 定版补充版本标识。具体参数仍必须结合客户现场硬件、安装介质、License、压测结果与业务画像调整。每次大版本升级、补丁升级、参数大改动、兼容模式切换或 HA/DR 架构调整后，必须重新核验本文中【V3.0.8PSU4】与【现场确认】项目，并同步更新文档版本号归档。

