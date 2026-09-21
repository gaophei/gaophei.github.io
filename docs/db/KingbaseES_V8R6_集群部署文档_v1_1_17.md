# KingbaseES V8R6 数据守护集群（DG）部署文档

**可照抄执行版 · 基于 64GB / 32C / ARM64 / Kylin V10 / 超融合虚拟机现场实做**

| 项 | 内容 |
| --- | --- |
| 文档版本 | **v1.1.17（可执行版）** |
| 首次编制日期 | 2026-09-05 |
| 当前修订日期 | 2026-09-13 |
| 适用形态 | **数据守护集群** `ha_running_mode='DG'`，1 Primary + 1 Standby，无 kingbasecluster 中间件 |
| 参考现场 | node1 `192.168.72.18` / node2 `192.168.72.19` / VIP `192.168.72.22`，`KESRealPro/V008R006C009B0014PS062`，aarch64 |
| 配套文档 | 《KingbaseES V8R6 环境说明与参数基线》**v1.3.27**（附录 F 现场参数、附录 G 配置文件原文、7.0 的 21 项 P0、**1.4.4 存储 SOP：E-GATE 统一入口门 + M-SEQ v1.11 通用校验序列（受控解析 kb_parse / 已知危险模式扫描 / 持有者正向枚举（st_dev+st_rdev 双语义）/ 跨 namespace 挂载判定 / 幂等卸载 / 文件系统干净的正面证据 / 破坏性操作的即时复验授权）+ 第 0b 块设备准备 + 两版方案 + 2.S 域② 接入 + 2.7c 配置同步硬门**） |
| 配套脚本 | `kb_collect_all.sh v1.2.5`（现场文件名 `kbdc.sh`）<br>SHA256 `5c04873b750c5a74f64ddae73b8b946116ddadf30f68e746a445243f4ba80d5c`<br>**巡检与备份脚本集 `kb_scripts` v1.1.7**（tar 内 **8 个文件**：5 个 shell + `backup8.conf` + `README.md` + `SHA256SUMS`）<br>⚠️ **完整批准清单与 SHA256 见附录 B.1；`kbdc.sh` 必须与脚本集一同交付**（v1.1.1 的发布包曾遗漏它，v1.1.6 的 README 又写成"单独交付"，v1.1.7 已统一为**必须在发布 ZIP 根目录内**） |

---

## 如何使用本文档

```
本文档 = 怎么把集群装起来（含可直接复制的命令）
参数基线文档 = 装起来之后参数怎么调、怎么验收、21 项 P0 怎么关闭
```

**命令块的约定：**

| 标记 | 含义 |
| --- | --- |
| `# [root]` | 该块以 root 执行 |
| `# [kingbase]` | 该块以 kingbase 执行 |
| `# [两节点]` | node1、node2 **分别**执行 |
| `# [仅主节点]` | 只在 node1 执行 |
| ⚠️ | 照抄前必须先读的说明 |

> **变量约定**：以下命令中已把现场实际路径写死，换现场时只需改开头的变量块。

```bash
# ===== 全文使用的变量（换现场时只改这里）=====
NODE1=192.168.72.18
NODE2=192.168.72.19
VIP=192.168.72.22/24
NET_DEV=enp18s0
DB_PORT=54321
KB_ROOT=/home/kingbase/cluster           # install_dir
KB_HOME=$KB_ROOT/kingbase                # 软件与 bin
KB_DATA=$KB_HOME/data                    # 数据目录
KB_ETC=$KB_HOME/etc                      # repmgr.conf 所在
REPO=/data/kingbase/backup/rman          # sys_rman 仓库
DUMP=/data/kingbase/backup/dump          # 逻辑备份产物
BKS=/home/kingbase/backup_script         # 逻辑备份脚本目录
GW=192.168.72.254                        # 网关（trusted_servers 候选）

# ===== 存储方案相关（★ 二选一，见 §2.1 与基线 1.4.4）=====
# MNT-SITE（现场环境版）：备份卷挂在 /data/kingbase/backup，DATA 不动
MNT=/data/kingbase/backup
LOGDIR=/data/kingbase/backup/log
# MNT-MOVE（建议版）：先把 DATA 迁出 /data，备份卷挂在 /data
# MNT=/data
# LOGDIR=/data/kingbase/log
```

> ⚠️ **`MNT` / `LOGDIR` 必须与现场实际选定的存储方案一致**，否则 §7.2 的 `log_directory`、附录 B.4 的日志清理 cron、`kb_offcluster_copy.sh` 的 `EXPECT_REPO_MOUNT` 会互相打架。**全新装机现场**若 PGDATA 不在 `/data` 下，两种取值都可用，推荐直接用 `MNT=/data`。

---

## 目录

1. [第 0 章 部署前必须先定的 9 件事](#第-0-章-部署前必须先定的-9-件事)
2. [第 1 章 授权（License）核查](#第-1-章-授权license核查)
3. [第 2 章 存储规划与 LVM 实操](#第-2-章-存储规划与-lvm-实操)
   - **2A 装机前：规划与块设备准备**（§2.1 ~ §2.4）
   - **2B 装机后（受控维护窗口）：域② `sys_wal` 接入** —— ★ 执行时点在**第 5 章之后**，由 §5.5 跳转
4. [第 3 章 操作系统准备](#第-3-章-操作系统准备)
5. [第 4 章 介质准备与 install.conf](#第-4-章-介质准备与-installconf)
6. [第 5 章 集群安装执行](#第-5-章-集群安装执行)
7. [第 6 章 ★ 安装后立即做配置源收敛](#第-6-章--安装后立即做配置源收敛)
8. [第 7 章 参数落地](#第-7-章-参数落地)
9. [第 8 章 备份体系部署](#第-8-章-备份体系部署)
10. [第 9 章 安全加固](#第-9-章-安全加固)
11. [第 10 章 安装后验证](#第-10-章-安装后验证)
12. [第 11 章 启停与维护 SOP](#第-11-章-启停与维护-sop)
13. [第 12 章 常见坑与排查](#第-12-章-常见坑与排查)
14. [附录 A 官方《集群安装指南》需修正项](#附录-a-官方集群安装指南需修正项)
15. [附录 B 配套脚本索引](#附录-b-配套脚本索引-不再内嵌源码)
16. [附录 C 装机 checklist](#附录-c-装机-checklist)

---

# 第 0 章 部署前必须先定的 9 件事

**这 9 项一旦装完再改，代价都是停机级别的。**

| # | 事项 | 为什么必须提前定 | 本现场取值 |
| --- | --- | --- | --- |
| 1 | **License 类型与有效期** | ★ 试用授权到期后行为未知 | ⚠️ 见第 1 章 |
| 2 | **两 VM 的反亲和策略** | 同宿主机 → 整套 HA 归零 | 待确认 |
| 3 | **三个容量域的 LV 划分** | 装完再拆需停机迁移 | ⚠️ 本现场只划了一个 `/` |
| 4 | `db_mode` / `db_case_sensitive` / `encoding` / `locale` / `db_checksums` | **initdb 期属性，装完不可改** | oracle / no / UTF8 / en_US.UTF-8 / yes |
| 5 | `max_connections` | 已建集群中**不得常规调小** | ⚠️ 现为 2000 |
| 6 | `synchronous` 与**备库是否承担读** | 决定 `synchronous_commit` / `hot_standby_feedback` | quorum / 不承担读 |
| 7 | `trusted_servers`（建议 2~3 个） | 单点会成为 HA 判定的软肋 | ⚠️ 现为单点网关 |
| 8 | **预计数据量** | 决定 `/data` 容量、WAL 空间、repo 大小 | 待确认 |
| 9 | **`statement_timeout` 是否设置** | 全局设置会强杀长事务作业 | ⚠️ 现为 60min |

> **★ 现场教训（1）**：该现场装机时划了一个 23.1G 的 `klas-backup` LV，**却没有挂载**，备份全部写在 `/` 上。**LV 建了没挂比不建更隐蔽**——`lvs` 看着规划完整，只有 `df` 对照才露馅。

---

# 第 1 章 授权（License）核查

> **★ 现场教训（2）**：本现场实测 license 为 **「官方网站试用授权」，浮动基准 + 有效期 90 天**，却用在准生产集群上。**这一项比任何参数调优都根本**——到期后数据库能否服务是未知数。

**装机前必查（在介质解压目录或已装环境的 `$KB_HOME/bin` 下）：**

```bash
# [kingbase]
cat $KB_HOME/bin/license.dat | tail -40
```

**重点看这几行：**

```
细分版本模板名 --- SALES-企业版 V8R6      ← 版本
用户名称       --- 官方网站试用授权        ← ★ 是否为正式项目授权
项目名称       --- 官方网站试用授权        ← ★ 同上
浮动基准日期   --- 启用                    ← 启用 = 从首次使用起算
有效期间       --- 90                      ← ★ 天数；正式授权通常为 0(永久) 或长期
最大连接数     --- 0                       ← 0 = 不限
数据守护集群   --- 启用                    ← DG 形态必须为启用
分区/并行查询/审计/透明加密 ...            ← 按业务需要逐项核对
```

**验收判据：**

| 结果 | 处置 |
| --- | --- |
| 用户名称/项目名称为**正式项目名**，有效期间为 **0** 或长期 | ✅ 通过 |
| 出现「试用」「测试」字样，或有效期间为有限天数 | ⛔ **上线阻断**，须取得正式 license 并记录续期责任人与时间表 |
| 「数据守护集群」为禁用 | ⛔ DG 形态无法部署 |

---

# 第 2 章 存储规划与 LVM 实操

> ## ★ 先看时间轴：本章分成【装机前】与【装机后】两段（v1.1.5 拆分）
>
> **本章在目录里排在第 5 章集群安装之前，但它的内容并不都在装机前做。**
> v1.1.4 把域② 的接入指向了基线 2.S，而 2.S 要求 `$PGDATA/sys_wal` **已经存在** ——
> 顺序读到这里的人会卡住：到底现在做，还是装完再做？
>
> ```
> 【2A · 装机前】容量定值 → 加盘/vgextend → lvcreate + mkfs → 域③ 挂载与目录
>        ↓                              ★ 只到块设备与域③为止，不碰 PGDATA
> 第 3 章 OS  →  第 4 章 介质  →  第 5 章 集群安装（initdb + 建备库 + 拉起集群）
>        ↓
> 【2B · 装机后 · 受控维护窗口】域② sys_wal 接入（基线 2.S）
>        ↓
> 第 6 章 配置源收敛  →  第 7 章 参数落地（WAL 参数按 2A 的定值写入）
> ```
>
> **一句话**：**在 2A 只把块设备准备好；`syswal` 建完就停在那里，不要挂**。
> 集群装完、进入受控维护窗口后，再回到 **2B** 执行基线 2.S。

## 2A 装机前：规划与块设备准备

## 2.1 三个容量域

| 域 | 内容 | 挂载点 | 为什么必须分开 |
| --- | --- | --- | --- |
| ① 系统 / DATA | OS + 软件 + 数据文件 | `/` | — |
| ② **`sys_wal`** | WAL + 复制槽滞留 | 独立 LV（**接入 SOP 见基线 1.4.4 的 2.S**）**或**走补偿分支 | ★ 见下 |
| ③ backup + log | sys_rman 仓库 + 数据库日志 | **独立 LV，挂载点须【不包含 PGDATA】**（见下方判据） | 日志/备份涨满不得拖死数据库 |

> ⚠️⚠️ **v1.1.3 更正：域③ 的挂载点不能笼统写成 `/data`。**
>
> v1.1.2 及以前把域③ 直接定义为 `/data`。**在本现场这是错的**：`$KB_DATA` 是指向 `/data/kingbase/data` 的软链（见下方教训 24），PGDATA 本身就在 `/data` 树下。把备份卷挂到整个 `/data`，只是把 **DATA + backup + log 一起搬到新卷**，域① 与域③ 仍在同一个文件系统里 —— **域③ 从未分开**。
>
> **判据不是挂载点叫什么名字，而是 SOURCE 是否相同：**
>
> ```bash
> DATA=$(readlink -f $KB_DATA)                    # ★ 必须先解软链
> findmnt -no SOURCE -T "$DATA"                   # A
> findmnt -no SOURCE -T "$REPO"                   # B
> findmnt -no SOURCE -T "$LOGDIR"                 # C
> # 判定：B ≠ A 且 C ≠ A 才算域③ 独立；任一取不到值 → ERROR，不得判通过
> ```
>
> **两版合法方案（★ 必须二选一并书面记录，完整 SOP 见基线 1.4.4）：**
>
> | | `MNT-SITE`（现场环境版） | `MNT-MOVE`（建议版） |
> | --- | --- | --- |
> | 备份卷挂载点 | `/data/kingbase/backup` | `/data` |
> | DATA 处置 | **完全不动**（软链保留，DATA 留在根盘 = 域①） | 先解除软链、把 DATA 迁回 `$KB_DATA` 实体目录（同文件系统 `mv`，**零拷贝**） |
> | `log_directory` | `/data/kingbase/backup/log` | `/data/kingbase/log` |
> | 适用 | **已投产、DATA 已在 `/data` 下**的现场，改动最小 | 新装现场；或愿意在维护窗口内把结构做干净的已投产现场 |
>
> **全新装机现场**：只要 PGDATA 不在 `/data` 之下（默认即 `$KB_HOME/data`，在 `/` 上），直接用 `MNT-MOVE` 的布局即可，不需要任何迁移动作。

> **★ 现场教训（24）：判断容量域必须 `readlink -f` + `findmnt -T`，不能看目录名。**
>
> 本现场 `/home/kingbase/cluster/kingbase/data` 是**指向 `/data/kingbase/data` 的软链**，而 `/data` **并非独立挂载点**：
>
> ```
> $ df -hT <DATA> <sys_wal> </data> <repo> <dump>
> /dev/mapper/klas-root  xfs  1.1T  48G  1.1T  5%  /     ← 五行全部相同
> ```
>
> `/data/kingbase/backup` 这样的路径**看起来像独立卷，实际不是**。必须：
>
> ```bash
> readlink -f <路径>                       # 解开软链
> findmnt -no SOURCE,TARGET -T <路径>      # 看真实文件系统与挂载点
> ```
>
> ⚠️ 另一个此前未记录的事实：**`log_directory` 落在 `.../data/sys_log`，即数据目录内部** —— 这比"同盘"更紧，日志涨满会直接顶到数据目录。

> **★ 现场教训（3）：为什么 `sys_wal` 值得单独拆。**
> 本现场 PS062 **实测不存在 `max_slot_wal_keep_size`**（`SHOW` 返回 `unrecognized configuration parameter`）——被遗弃的复制槽可以**无限撑满磁盘，引擎侧没有任何拦截**。若 `sys_wal` 与 DATA、备份同盘，一个 slot 滞留就能把整个数据库拖死。
> *（其他补丁版本请以实测为准，不要直接沿用本结论。）*

## 2.2 容量估算

```
sys_wal 工程参考 ≈ wal_keep_segments × 16MB + max_wal_size + 余量
   例：4096 × 16MB(=64GB) + 8GB ≈ 72GB   ← 工程参考值，非理论下限
   规划目标：100GB
backup 规划   ≈ (全备保留份数 × 单次全备大小) + 保留期内 WAL 归档 + 余量
   ⚠️ 若 compress-type=none（本现场即是），空间需求约翻倍
```

> `max_wal_size` 是**软限制**，检查点压力大时 WAL 可以超出；实际占用并非"两块独立固定空间简单相加"。**应以容量告警兜底，而非静态公式。**

> ⚠️⚠️ **上面的 100GB 是【示例值】，不要照抄（v1.1.5 强调）。**
> `syswal` 的尺寸不能脱离 WAL 参数单独拍板 —— 基线采用的 **8 倍规则**是
> `wal_keep_segments × 16MB ≥ 8 × max_wal_size`：
>
> | 若最终参数 | WAL 稳态上限（约） | 100GB 够不够 |
> | --- | --- | --- |
> | `max_wal_size=8GB` + `wal_keep_segments=4096`（64GB） | ≈ 64GB + 检查点余量 | 勉强够，余量不厚 |
> | **维持现场的 `max_wal_size=64GB`** | 8 倍规则要求 ≈ **512GB** | **差一个量级** |
>
> 现场当前 `max_wal_size = 64GB`、`wal_keep_segments = 512`（8GB），**违反该规则 64 倍**。
> 因此 **`max_wal_size` / `wal_keep_segments` / `syswal` 容量必须一起定死**，
> 定值表见**基线 1.4.4 的 0b.1**，第 7 章的 WAL 参数必须与这里的定值一致。
> **三个数字缺任一项，不得开始建 LV。**

## 2.3 LVM 实操（可复制）—— ★ 只到块设备与域③ 为止

**★ 动手之前先跑依赖预检（v1.1.8 新增）**

```bash
# [root][两节点]  —— M-SEQ 的 M8 / M9 会在缺工具时直接 STOP（这是预期行为），
#   但在破坏性维护窗口里临时发现缺工具，代价是整段窗口作废 —— 必须提前查。
miss=0
# ★★ v1.1.13：`fuser` / `lsof` 从硬依赖移出（P1-3）。
#   v1.1.12 已在正文与 checklist 把它们写成"佐证工具、缺失不阻断"，
#   **但这个 for 循环没改** —— 真实行为仍是"缺 fuser 就 STOP"，与说明正好相反。
#   这是本文档第三次出现"说明改了、可复制代码没改"，本版一并收掉。
for c in mountpoint blkid blockdev dumpe2fs xfs_repair stat readlink findmnt install \
         rsync find awk wc sed tr mktemp sha256sum getfattr getfacl; do
    command -v "$c" >/dev/null 2>&1 || { echo "★ 缺少 $c（硬依赖）"; miss=1; }
done
# 佐证工具：缺失只告警，不阻断 —— M9 的主证据是 M9a 正向枚举
for c in fuser lsof; do
    command -v "$c" >/dev/null 2>&1 || echo "注：未安装 $c（佐证探针，将被跳过；强烈建议安装）"
done
[ "$miss" -eq 0 ] || { echo "STOP: 先补齐上述硬依赖再继续（dumpe2fs←e2fsprogs，xfs_repair←xfsprogs，getfattr←attr，getfacl←acl）"; exit 1; }

# ★★ v1.1.12：改为执行【基线 1.4.4 的 E-GATE】—— 不在本文档复制那串哈希。
#    E-GATE = 外部哈希门 + 加载 + kb_mseq_selfcheck + kb_mseq_scan_parsers(M12)，
#    哈希只在基线 1.4.4 定义一次；复制出来的字面量一旦升版就会漏改（本文档在版本号上栽过两次）。
#    ⚠️ time-of-use 的理由不变：安装到实际维护之间可能隔着数天，期间文件可能被编辑；
#       而 kb_mseq_selfcheck 只能证明【内部自洽】—— 改内容时把内置常量一起改掉，它照样通过。
#
#    → 打开《环境说明与参数基线》1.4.4 的 E-GATE 代码块，按其执行；然后回到本节继续。

# 本节的断言：确认 E-GATE 确实跑过（未跑过即 STOP，不允许"直接从这里开始"）
[ -n "${KB_MSEQ_SHA:-}" ] && command -v kb_parse >/dev/null 2>&1 \
    || { echo "STOP: 未执行基线 1.4.4 的 E-GATE —— 请先回到该节执行入口前置"; exit 1; }
```

> ⚠️ **v1.1.10 之前这里只跑 `kb_mseq_selfcheck`，并把失败文案写成"与批准版不符"** ——
> 而 M10 自己已经明确它**证明不了批准版**。文案与能力不符，比没有检查更容易误导。
>
> ⚠️⚠️ **v1.1.12：这道门现在真正覆盖每一个入口了。**
> v1.1.11 时只有本节和基线 2.S 有门，而已投产环境的 DBA 完全可能**直接进入基线 2.4 / 2.6 / 2.R 做维护** ——
> 那条路径两道门都不经过。基线 **v1.3.22 把它抽成 E-GATE**（哈希只定义一次），
> **2.S / 2.4 / 2.6 / 2.R / 第 0 阶段各自断言"E-GATE 已执行"，未执行即 STOP**。
> ⚠️ 同时要承认一个**引导限制**：总得有东西先被信任 ——
> **基线文档及其内嵌批准哈希是信任根**；基线文档自身的真伪，由本文档 B.1 / B.2 的交付链负责。

> ⚠️ **硬依赖清单（缺任一项，相关步骤即 STOP）**：
> · **`xfs_repair`**（xfsprogs）—— M8a 用它取"XFS 日志干净"的**正面证据**；
> · **`dumpe2fs`**（e2fsprogs）—— M8a 对 ext3/4 判 `Filesystem state`；
> · **`getfattr` / `getfacl`**（**attr** / **acl** 包）—— 2.7 的 xattr / ACL 比对是 `REPO-KEEP` 的硬门，
> 　缺了会**走到维护窗口后半程才发现**；
> · `mountpoint` / `blkid` / `blockdev` / `findmnt` / `stat` / `awk` / `wc` / `sed` / `tr` / `sha256sum` —— M-SEQ 的取证与解析基础。
>
> ⚠️⚠️ **v1.1.12 统一口径：`fuser` / `lsof` 是【佐证】，不是主证据（P1-3）。**
> 本文档 v1.1.10 / v1.1.11 的 checklist 写着「**`lsof` 与 `fuser` 均为必需，M9 不接受单探针**」，
> 而 M-SEQ **v1.5 起的代码**已经是「未安装则跳过佐证探针」—— **两套相反的安全模型同时存在**。
>
> **本版按代码口径统一，理由是举证责任已经换人**：M9 的主证据现在是 **M9a 正向枚举**
> （扫 `/proc/<pid>/fd/*` 比对 major:minor，"扫描完整且没找到"才算无人持有，**扫描不完整一律 ERROR**）。
> 而 `fuser(1)` 的返回码协议**本身就不提供"证明无人持有"的能力** —— "没有"和 fatal error 都返回非零，
> 把它写成"必需"也换不来任何证明力；它只能在 rc=0 时**把结论从 free 升级为 busy**。
>
> ⚠️ **但仍强烈建议安装**：多一条独立佐证没有坏处，`fuser -vm` 的输出在排障时也好用。
> ⚠️ **若项目政策坚持"双探针必需"，那必须改【代码】让它缺任一即 STOP，而不是只在签字表上写"必需"** ——
> 　签字表与代码相反，是比两者都宽松更糟的状态。
>
> ⚠️ **`xfs_repair -n` 的退出码请在现场这套 xfsprogs 上先实测一次**（干净 / 脏日志 / 损坏 各跑一遍记录 rc）。
> M8a 的判定**不依赖具体码值**（一律"非 0 即阻断"），实测是为了**知道现场会看到什么**，不是去调判据。

> ⚠️⚠️ **本节【不执行】基线 2.S。** `syswal` LV 在这里只做 `lvcreate` + `mkfs`，**建完就停**。
> 它的接入要等集群装完、进入受控维护窗口后，按 **§2B** 回到基线 2.S 执行。
>
> **对应基线的第 0b 阶段**（块设备准备，维护窗口之前）：0b.1 容量定值 → 0b.2 加盘/`vgextend`
> → 0b.3 `lvcreate` + `mkfs` → 0b.4 出场检查。本节是它在装机流程中的落点。
>
> ⚠️ **已投产现场**（本现场即是）：`klas-backup` 上已有文件系统，**必须先走 §2.4 的第 0 阶段安全只读检查与授权**；
> 而**全新创建的 `syswal` 不需要**套用那套流程（它是新 LV，盘上不可能有别人的数据）。**两类动作不可混用。**

```bash
# [root][两节点]  —— 先看现状
pvs; vgs; lvs -o +devices
lsblk -f
df -hT
```

> ⚠️⚠️ **本节仅适用于【全新装机】（数据库尚未部署，或已确认 PGDATA 不在挂载点之下）。**
> **已投产现场的存储改造 / 迁移，一律以《参数基线》1.4.4 为唯一执行真源**（含 `MNT-SITE` / `MNT-MOVE` 两版方案、`REPO-NEW` / `REPO-KEEP` 两条 repo 路径、2.R 回退 SOP）。
> **本章自 v1.1.3 起不再维护第二份可执行迁移 SOP** —— 同一过程存在两份真源必然漂移，这与附录 B「不再内嵌脚本源码」是同一条治理原则。

**情形 A：VG 有剩余 extent（`vgs` 的 VFree > 0）**

```bash
# [root][两节点]
VG=klas                                    # 按 vgs 输出替换

# ★ v1.1.6：容量不再写死示例值 —— 一律从 0b.1 的签字定值读取
#   /root/kb_plan.env 由基线 1.4.4 的 0b.1 产出，两节点各一份
. /root/kb_plan.env 2>/dev/null || { echo "STOP: /root/kb_plan.env 不存在 —— 0b.1 未完成"; exit 1; }
case "${SYSWAL_SIZE_GB:-}" in ''|*[!0-9]*) echo "STOP: SYSWAL_SIZE_GB 未填写或非纯数字"; exit 1 ;; esac
case "${BACKUP_SIZE_GB:-}" in ''|*[!0-9]*) echo "STOP: BACKUP_SIZE_GB 未填写或非纯数字"; exit 1 ;; esac

# ★★ v1.1.14：这四行此前【完全没有守卫】—— 既无 `|| exit 1` 也无 `set -e`（P0-2）。
#   实测把两个 lvcreate 注入 rc=5 后，两条 mkfs.xfs 照样被调用、整段 FINAL_RC=0。
#   真实语义是："创建没成功" 并不会阻止 "格式化那个名字对应的设备"。
#   危险场景很具体：**重跑时 lvcreate 因同名 LV 已存在而失败 → 紧接着 mkfs 那个设备**，
#   而那上面可能正是上一轮留下的数据。
#   ⚠️ 不能把安全寄托在"mkfs.xfs 恰好能识别出目标上的签名并拒绝" ——
#      旧 LV 未格式化、签名损坏或设备状态异常时，它不会拒绝。
#   ⚠️ 这不是新引入的缺陷，而是**从 v1.1.0 一路活到现在的原始写法**。本版另做了一次
#      **全文破坏性命令回扫**（见 B.5 第 8 条），共修正 11 处裸写法。

# ① 创建前：目标 LV 必须尚不存在（重跑现场最容易踩的就是这一条）
for lv in syswal kbbackup; do
    if [ -e "/dev/$VG/$lv" ]; then
        echo "STOP: /dev/$VG/$lv 已存在 —— 这是重跑现场。"
        echo "      请先确认其内容归属（走 §2.4 的安全只读检查），不得直接重建/格式化"
        exit 1
    fi
done

# ② 创建：任一失败即停
lvcreate -L "${SYSWAL_SIZE_GB}G" -n syswal   "$VG" \
    || { echo "STOP: syswal LV 创建失败"; exit 1; }
lvcreate -L "${BACKUP_SIZE_GB}G" -n kbbackup "$VG" \
    || { echo "STOP: kbbackup LV 创建失败"; exit 1; }

# ③ 格式化前：设备必须真的存在、且实际容量 ≥ 规划
for lv in syswal kbbackup; do
    [ -b "/dev/$VG/$lv" ] || { echo "STOP: /dev/$VG/$lv 不存在或不是块设备"; exit 1; }
done
ACT_WAL=$(blockdev --getsize64 "/dev/$VG/syswal")   || { echo "STOP: 取 syswal 容量失败"; exit 1; }
ACT_BAK=$(blockdev --getsize64 "/dev/$VG/kbbackup") || { echo "STOP: 取 kbbackup 容量失败"; exit 1; }
[ "$ACT_WAL" -ge $(( SYSWAL_SIZE_GB * 1024 * 1024 * 1024 )) ] \
    || { echo "STOP: syswal 实际容量 ${ACT_WAL}B 小于规划 ${SYSWAL_SIZE_GB}G"; exit 1; }
[ "$ACT_BAK" -ge $(( BACKUP_SIZE_GB * 1024 * 1024 * 1024 )) ] \
    || { echo "STOP: kbbackup 实际容量 ${ACT_BAK}B 小于规划 ${BACKUP_SIZE_GB}G"; exit 1; }

# ④ 破坏性授权（★ v1.1.16：所有 mkfs 之前一律要求 destroy 授权，不留"这里显然安全"的例外）
#    ⚠️ 这两个 LV 是刚 lvcreate 出来的新设备、上面还有"同名 LV 必须不存在"的硬门，
#      看起来不可能有持有者 —— 但"理论上不可能"正是本套 SOP 反复翻车的地方
#      （"正常 umount 会 EBUSY 挡住"就被 umount -l 绕开过）。授权检查的代价只有几秒。
#    ⚠️⚠️ **v1.1.17：两项声明改为【本次调用的参数】**（M-SEQ v1.11）。
#      v1.10 及以前用的是环境变量 KB_NO_LAZY_UMOUNT / KB_ACCEPT_MMAP_RISK ——
#      **那是会话级开关**：不绑定设备、用完不清除。**本节恰好是连续两个设备**，
#      旧写法下为 syswal 声明一次，kbbackup 会**直接继承**该授权，而声明文案写的是"本设备"。
#      改成参数后天然一次性、绑定本次调用；旧环境变量写法**不再被识别**（fail-closed）。
#      · --no-lazy-umount    确认本设备从未被 umount -l 懒卸载过
#      · --accept-mmap-risk  仅当 mmap 覆盖有缺口（KB_MMAP_COVERED=no）时才补
kb_dev_released "/dev/$VG/syswal"   destroy --no-lazy-umount || exit 1
kb_dev_released "/dev/$VG/kbbackup" destroy --no-lazy-umount || exit 1

# ⑤ 格式化：任一失败即停
mkfs.xfs "/dev/$VG/syswal"   || { echo "STOP: syswal 格式化失败"; exit 1; }
mkfs.xfs "/dev/$VG/kbbackup" || { echo "STOP: kbbackup 格式化失败"; exit 1; }
echo "✓ 两个 LV 已创建并格式化（容量已校验）"
```

> ⚠️⚠️ **v1.1.6 修掉了一条验收假 PASS 通道。** 上一版这里写的是 `lvcreate -L 100G -n syswal`，
> 而 §2.2 刚刚写完"100GB 是示例值、不可照抄" —— **警告在文字里，错误在可复制块里，永远是复制粘贴赢**。
> 实际发生过的路径是：
>
> ```
> 0b.1 签字 600G → 照可复制块建成 100G → 出场检查不看容量，全 PASS
> → 当前 sys_wal 只有几 GB，基线 2.S 的"用量×1.2"门也 PASS
> → checklist 填「规划 600G + 全绿」→ 实际 LV 仍是 100G，全程无人发现
> ```
>
> 现在容量只能来自 `/root/kb_plan.env` 的签字值，**留空即 STOP**；下方出场检查再机器断言**实际容量 ≥ 规划值**。

> ⚠️ **v1.1.4 更名：域③ 的 LV 由 `kbdata` 改名为 `kbbackup`。** 这块卷**恰恰要求不能包含 DATA**，
> 再叫 `kbdata` 在经历过「DATA 与 backup 域混淆」之后极易误导。
> **注意区分**：本现场已存在的那块 LV 名字是 **`klas-backup`**（见 §2.4 的 `/dev/klas/backup`），**不要连带改动**；
> 这里改的只是全新装机的示例命名。

> ⚠️⚠️ **`lvcreate` + `mkfs.xfs` 之后，域② 还没有任何东西落地。**
> 下面的 fstab / 挂载 / 属主 / 目录步骤**只处理域③ `$MNT`**；`syswal` 的接入另有完整执行链，见本节末尾。

```bash
# [root][两节点]  —— ★ 挂载前硬门：挂载点之下不得包含 PGDATA
#   MNT 取值见开头变量块（MNT-SITE=/data/kingbase/backup；MNT-MOVE=/data）
mkdir -p "$MNT" || { echo "STOP: 创建挂载点失败"; exit 1; }

if [ -e "$KB_DATA" ]; then
    D=$(readlink -f "$KB_DATA")
    case "$D/" in "$MNT"/*)
        echo "STOP: PGDATA($D) 位于挂载点 $MNT 之下 —— 挂上去域①与域③仍会同盘"
        echo "      请改用 MNT-SITE 布局，或按基线 1.4.4 的 MNT-MOVE 先把 DATA 迁出"
        exit 1 ;;
    esac
    echo "✓ PGDATA=$D，不在 $MNT 之下"
else
    echo "✓ 数据库尚未部署（全新装机），无 PGDATA 冲突"
fi
```

> ⚠️⚠️ **v1.1.7：本块改用 M-SEQ（P0-3）。** 上一版这里是 `UU1=$(blkid …)` → `grep`/`echo` 写 fstab → 裸 `mount` → 裸 `findmnt`，
> **正是基线 v1.3.16 刚在 2.6 定性为 P0 的那套写法**，却原样留在了部署文档里。三个缺口：
> ① `UU1` 取空会往 fstab 写出 `UUID=  /path xfs defaults 0 0` 的坏行；
> ② `grep` 只查「正确 UUID + 该挂载点」这一对，**同挂载点已有错 UUID 的活动行时查不到 → 追加正确行 → 而 `mount` 用第一条 → 挂上错误的卷**；
> ③ `mount` / `findmnt` 都没有硬门，挂载失败后流程继续，`mkdir -p "$LOGDIR" "$DUMP"` 会把目录建在**根盘**上，
> 　日志与逻辑备份从此静默写 `/` —— 而 `df` 上看起来一切正常。

```bash
# [root][两节点]
[ -n "${KB_MSEQ_SHA:-}" ] && [ -n "${KB_EGATE_OK:-}" ] \
    || { echo "STOP: 未执行基线 1.4.4 的 E-GATE"; exit 1; }
printf '%s  %s\n' "$KB_MSEQ_SHA" /root/kb_mseq.sh | sha256sum -c - \
    || { echo "STOP: /root/kb_mseq.sh 已与批准值不符（E-GATE 之后被改动过）"; exit 1; }
command -v kb_parse >/dev/null 2>&1 \
    || { echo "STOP: M-SEQ 未加载 —— 请重新执行 E-GATE（不要在此裸 source）"; exit 1; }
DEV=/dev/$VG/kbbackup

kb_dev_ready   "$DEV" xfs                        || exit 1   # M1 存在/未挂别处/FSTYPE/UUID非空
kb_fstab_check "$MNT" "$KB_DEV_UUID"             || exit 1   # M3 活动行 0 或 1 条，且 UUID 必须匹配
[ "$KB_FSTAB_N" -eq 0 ] && { kb_fstab_add "$MNT" "$KB_DEV_UUID" xfs || exit 1; }   # M4
kb_mount_verify "$MNT" "$KB_DEV_UUID"            || exit 1   # M5 ★ 实际挂上的 UUID 必须 = 预期

chown kingbase:kingbase "$MNT" || { echo "STOP: 设置挂载点属主失败"; exit 1; }
mkdir -p "$LOGDIR" "$DUMP" || { echo "STOP: 创建 LOGDIR/DUMP 失败"; exit 1; }
chown -R kingbase:kingbase "$LOGDIR" "$DUMP" || { echo "STOP: 设置 LOGDIR/DUMP 属主失败"; exit 1; }

# ★ 再确认这两个目录确实落在新卷上，而不是根盘
# ★★ v1.1.13：改为分别采集再比较。此前写成
#     [ "$(findmnt … "$d")" = "$(findmnt … "$MNT")" ]
#   —— **两个 findmnt 同时失败时两侧都是空串，"" = "" 成立 → PASS**，
#   正是本套文档自己总结过的"两个错误互相抵消成一个 PASS"。
kb_parse "取 $MNT 的挂载来源" single findmnt -no SOURCE -T "$MNT" || exit 1
MNT_SRC=$KB_PARSE_OUT
for d in "$LOGDIR" "$DUMP"; do
    kb_parse "取 $d 的挂载来源" single findmnt -no SOURCE -T "$d" || exit 1
    [ "$KB_PARSE_OUT" = "$MNT_SRC" ] \
      || { echo "STOP: $d 在 $KB_PARSE_OUT 上，而 $MNT 在 $MNT_SRC 上 —— 不是同一个卷"; exit 1; }
done
echo "✓ 域③ 已挂载并就绪：$MNT（UUID=$KB_DEV_UUID）"
```

> ⚠️ **`rman` 目录不要手工创建结构** —— 交由 `sys_backup.sh init` 按官方流程创建（见 §8.1）。`$LOGDIR` 与 `$DUMP` 则**必须在数据库首次启动前存在**，否则日志采集器启动失败、`backup8.sh` 报错。

**情形 B：VFree = 0（本现场即是）**

```bash
# [root][两节点]  —— 由超融合管理员先加一块虚拟盘，假设为 /dev/vdc
pvcreate /dev/vdc        || { echo "STOP: pvcreate 失败"; exit 1; }
vgextend klas /dev/vdc   || { echo "STOP: vgextend 失败"; exit 1; }
vgs                                        # 确认 VFree 已增加
# 然后按情形 A 的 lvcreate 继续；★ 禁止用 -l +100%FREE，见下
```

> **★ 现场教训（4）**：**不要用 `lvextend -l +100%FREE`。** 若把新盘 extent 一次性吃给 backup，将来就没有空间再建 `sys_wal` LV。**先完成容量规划，再按 `-L <规划容量>` 分别分配。**

### ★ 2A 出场检查（= 基线 0b.4；**下表各项全 ✅** 才能进第 3 章）

```bash
# [root][两节点]  —— 仅当决定拆独立 sys_wal 时执行本检查
# ★ 改用基线 1.4.4「六」的 M-SEQ，与基线 0b.4 完全同源，避免两边判据漂移
# ★★ v1.1.13：不再裸 source —— E-GATE 之后重新 source 等于用当前磁盘字节覆盖已验证的函数
[ -n "${KB_MSEQ_SHA:-}" ] && [ -n "${KB_EGATE_OK:-}" ] \
    || { echo "STOP: 未执行基线 1.4.4 的 E-GATE"; exit 1; }
printf '%s  %s\n' "$KB_MSEQ_SHA" /root/kb_mseq.sh | sha256sum -c - \
    || { echo "STOP: /root/kb_mseq.sh 已与批准值不符（E-GATE 之后被改动过）"; exit 1; }
command -v kb_parse >/dev/null 2>&1 \
    || { echo "STOP: M-SEQ 未加载 —— 请重新执行 E-GATE（不要在此裸 source）"; exit 1; }
. /root/kb_plan.env
SYSWAL_DEV=/dev/klas/syswal

case "${SYSWAL_SIZE_GB:-}" in ''|*[!0-9]*) echo "STOP: SYSWAL_SIZE_GB 未填写"; exit 1 ;; esac
SYSWAL_PLAN_BYTES=$(( SYSWAL_SIZE_GB * 1024 * 1024 * 1024 ))

kb_dev_ready    "$SYSWAL_DEV" xfs                  || exit 1   # M1 存在/未挂别处/FSTYPE/UUID非空
kb_dev_capacity "$SYSWAL_DEV" "$SYSWAL_PLAN_BYTES" || exit 1   # M2 ★ 实际容量 ≥ 签字规划值

echo "✓ syswal 块设备就绪：UUID=$KB_DEV_UUID  实际容量=${KB_DEV_BYTES}B"
echo "★ 把 UUID 与实际容量抄进附录 C 的证据格 —— 只填规划值不构成证据"
echo "★ 尚未接入 PGDATA，接入见 §2B"
```

| 项 | 要求 |
| --- | --- |
| 三个数字已定并签字，并写入 `/root/kb_plan.env` | 见 §2.2 与基线 0b.1 |
| **M2 通过：实际设备容量 ≥ 签字规划值** | ⚠️ **本版新增** —— 只查"存在/格式化"会放过"建小了" |
| `syswal` LV 已创建并格式化（如决定拆） | **两节点都要有**，两节点的实际容量与 UUID 都要记录 |
| **未挂载到任何 PGDATA 路径** | 挂了 = 已经出事，回退后重来 |
| 域③ 已挂载、`$LOGDIR` / `$DUMP` 已建并 chown | 见 §2.3 情形 A |

## 2.4 ⚠️ 若目标 LV 上已有文件系统（本现场即是）

> 本现场 `klas-backup`（23.1G）上**存在 XFS，LABEL=`KYLIN-BACKUP`** —— `lvs` 显示 `-wi-a-----`（active 但未 open）**只能说明当前没有进程打开它，不能推断为空**。

```bash
# [root]  —— 第 0 阶段：安全只读检查（★ 不写盘）
LV=/dev/klas/backup
lsblk -f $LV ; blkid $LV ; wipefs -n $LV ; file -sL $LV
findmnt $LV ; fuser -vm $LV
```

> ⚠️⚠️⚠️ **v1.1.7 重写本段 —— 它是 `mkfs` 前唯一的数据保护门，而上一版是 fail-open。**
> 旧写法的 `mount -o ro,norecovery` **不判返回码、不做 `mountpoint` 确认、`umount` 也不判**。
> 挂载失败时，后面的 `ls -laR` / `du -sh` 看的是**根盘上那个刚 `mkdir` 出来的空目录**：
>
> ```
> mount 失败（无人发现）→ ls 无输出、du 显示 4.0K
>   → 打勾"只读检查已完成、内容可丢弃" → mkfs -f → 格掉一个从未真正看过的卷
> ```
>
> **改用基线 M-SEQ 的 M8 / M9**，并把结论从"一段目测"变成**三个必须记录的数值**。

```bash
# [root]  —— 需要 M-SEQ：先执行基线 1.4.4 的 E-GATE
[ -n "${KB_MSEQ_SHA:-}" ] && [ -n "${KB_EGATE_OK:-}" ] \
    || { echo "STOP: 未执行基线 1.4.4 的 E-GATE"; exit 1; }
printf '%s  %s\n' "$KB_MSEQ_SHA" /root/kb_mseq.sh | sha256sum -c - \
    || { echo "STOP: /root/kb_mseq.sh 已与批准值不符（E-GATE 之后被改动过）"; exit 1; }
command -v kb_parse >/dev/null 2>&1 \
    || { echo "STOP: M-SEQ 未加载 —— 请重新执行 E-GATE（不要在此裸 source）"; exit 1; }
LV=/dev/klas/backup
LOG=~/lv-inspect.$(date +%F).log

# ★★ v1.1.16：注释更正 —— 旧文案"未挂载 + 无进程持有（findmnt/fuser 均三分）"已不符实际模型。
#   M9 v1.10 的真实证据链是：M1b 跨 namespace mountinfo 未命中
#   + M9a 枚举 fd / cwd / root / exe（硬覆盖）与 map_files（尽力而为，结果记入 KB_MMAP_COVERED）
#   + fuser / lsof 仅作佐证（只能把结论从 free 升级为 busy，非零时不作为任何方向的证据）。
kb_dev_released "$LV"                       || exit 1   # M9（普通 check；破坏性操作须用 destroy）
kb_ro_inspect   "$LV" /mnt/lv-inspect "$LOG" || exit 1   # M8 安全只读检查
#   ★ v1.1.9：M8 内部会【先】用 M8a 取"文件系统日志干净"的正面证据（XFS→xfs_repair -n；ext→dumpe2fs -h），
#     通过之后才只读挂载枚举 —— 日志不干净时只读视图本身可能不完整，那时数出的 0 条目毫无意义。

echo "===== 只读检查结论（必须抄进下方授权单）====="
echo "  判定 KB_RO_VERDICT  = $KB_RO_VERDICT    # EMPTY / NONEMPTY / INDETERMINATE"
echo "  条目数 KB_RO_ENTRIES = $KB_RO_ENTRIES   # ★ EMPTY 的主判据（目录/软链也计入）"
echo "  文件数 KB_RO_FILES   = $KB_RO_FILES     # 辅助证据"
echo "  字节数 KB_RO_BYTES   = $KB_RO_BYTES     # 辅助证据"
echo "  证据文件            = $KB_RO_EVIDENCE   # ★ mkfs 前的硬门读它，不读内存变量"

kb_dev_released "$LV"                       || exit 1   # 检查完毕，再次确认已释放
```

| `KB_RO_VERDICT` | 处置 |
| --- | --- |
| **`EMPTY`** | 挂载成功、来源设备已核对（**按同一块设备判定，不是路径字符串**）、**全部条目数 = 0** → 可进入破坏性块 |
| **`NONEMPTY`** | ⛔ 盘上确有数据，**不得 `mkfs`**。先查明归属、取得书面授权 |
| **`INDETERMINATE`** | ⛔ **v1.1.9 起由 M8a 取正面证据判定**：XFS `xfs_repair -n` 返回非 0（含脏日志）；ext3/4 `dumpe2fs -h` 的 `Filesystem state` 非 `clean` 或取不到。**看到的内容不完整，"看不到" ≠ "没有"**，不得判为空 |

> ⚠️⚠️ **v1.1.10 同步基线的一处修正**：M8a 的 **ext 分支**此前写成 `state=$(dumpe2fs -h dev 2>/dev/null | sed …)`，
> **`dumpe2fs` 的 rc 被管道吃掉** —— 实测"输出 `Filesystem state: clean` 但 rc=2"时函数返回 0 并打印 OK，**完整假 PASS**。
> 现已与 XFS 分支同构：**先判 rc，再取 state**。本现场是 XFS，但 B 分支的流程对两种文件系统都适用。

> ⚠️⚠️ **这条判据换过三次，值得记一笔**：最早用 `dmesg \| grep` 猜（不按设备过滤、环形缓冲区会滚掉 → **漏判走向 EMPTY**）；
> 上一版改为靠"只读挂载是否被拒绝"（**从没有报错反推日志干净**，且依赖内核提示文案匹配，文案一换就失效、失效方向是放行）；
> **本版才改成取正面证据**。前两版的共同毛病是：**用"没观察到异常"代替"观察到正常"** —— 在 `mkfs -f` 前面，这两者不是一回事。

> ⚠️⚠️ **v1.1.8 同步基线两处修正**：
> ① **`EMPTY` 的主判据由"普通文件数"改为"全部条目数"** —— 盘上只有 `important_dir/` 与一个软链时，
> 　"普通文件数 = 0、字节数 = 0"，旧判据会判 **EMPTY 并直通 `mkfs -f`**（实测该组合：`FILES=0 / BYTES=0`，实际条目数 = 2）。**目录和软链也是别人的数据。**
> ② **`INDETERMINATE` 换了信号源** —— 旧版用 `dmesg | grep` 猜，既不按设备过滤，环形缓冲区还会把真提示滚掉（漏判 → 走向 `EMPTY`，危险方向）。

**破坏性操作前逐条打勾（★ 以下【全部项】，本文档不再维护手工项数）：**

```
☐ kb_ro_inspect（M8）返回 0
☐ ★ KB_RO_VERDICT  = EMPTY     （NONEMPTY / INDETERMINATE 一律不得继续）
☐ ★ KB_RO_ENTRIES = ______     （**主判据**，必须为 0；目录与软链也计入）
☐ ★ KB_RO_FILES   = ______     （辅助证据；必须填数字，填不出 = 根本没挂上）
☐ ★ KB_RO_BYTES   = ______     （辅助证据）
☐ ★ 证据文件 /root/kb_ro_evidence.env 已生成
☐ 内容已留证（~/lv-inspect.*.log）并确认可丢弃
☐ 书面授权已取得（授权人：______ 日期：______）
☐ ★ M9 证据项逐条记录（**不要只写"无进程持有"这种笼统结论** —— P0 级的"mmap 被错标成已覆盖"正是藏在这种结论后面）：
     · M1b 跨 namespace mountinfo 未命中：PASS □      （扫描进程数 = ______）
     · M9a fd / cwd / root / exe：无命中 PASS □
     · KB_MMAP_COVERED = ______（yes / no）；若 no：KB_MMAP_UNREAD = ____，KB_MMAP_FAILED = ____
     · 破坏性操作授权（destroy）：PASS □；KB_NO_LAZY_UMOUNT = ______；KB_ACCEPT_MMAP_RISK = ______
☐ 设备名已二次确认
```

```bash
# [root]  ★ 不可逆
# ★ v1.1.8：执行时硬门改为读【证据文件】，不再依赖上一段留在内存里的变量
#   原因：KB_RO_* 只活在同一个 shell 会话，而现场节奏是"检查 → 找人签字 → 过一阵子回来 mkfs"，
#   多半已是另一个终端 → 硬门必然 STOP → 操作员会发现"手动 export 就能过"，这道门从此形同虚设。
# ★★ v1.1.9：M11 已重写为【即时复验 + 与历史证据比对】—— 授权依据是本次枚举，不是历史记录
#   原因：blkid 的 UUID【不会因为写入文件而变化】，只读历史证据挡不住"期间有人挂上写了数据"：
#     10:00 判 EMPTY → 10:30 别人 mount rw 写入 → 11:00 五项校验全过 → mkfs 格掉
#   现在 M11 会重新只读挂载并枚举，条目数须为 0 且与证据记录一致；有效期也由 24h 压到 1h。
kb_ro_evidence_ok /dev/klas/backup /mnt/kb-recheck 3600 || exit 1   # M11
# ★★ v1.1.16：此前是普通 check —— **普通 check 不得作为破坏性授权**
#   （它不查懒卸载声明，也不管 mmap 覆盖缺口）。改为 destroy 模式。
kb_dev_released   /dev/klas/backup destroy --no-lazy-umount || exit 1   # M9（破坏性授权）

mkfs.xfs      /dev/klas/backup   || { echo "STOP: 格式化失败"; exit 1; }   # 无历史文件系统时
# mkfs.xfs -f /dev/klas/backup   || { echo "STOP: 格式化失败"; exit 1; }   # 有历史文件系统时才需要 -f
```

> **★ 现场教训（5）**：`mkfs.xfs` 检测到已有文件系统时**会拒绝执行——这是它唯一的自动防护**。**不要因为报错就顺手加 `-f`。**

---

## 2B 装机后（受控维护窗口）：域② `sys_wal` 接入

> ⚠️⚠️ **本节的执行时点是【第 5 章集群安装完成之后】，不是现在。**
> 顺序读到这里请先继续第 3～5 章；集群装好、进入受控维护窗口后，再回到本节。
> **§5.5** 是返回本节的跳转点（v1.1.5 误写为 §5.4，v1.1.6 更正）。

### ★ 域② `sys_wal` 的接入：执行步骤见基线 **1.4.4 的 2.S**

> ⚠️⚠️ **v1.1.4 更正：删除了 v1.1.3 那句「`sys_wal` 的挂载必须在 initdb 之后、数据库首次启动之前」。**
> 那句话暗示存在一个「目录还是空的、可以直接 mount」的干净窗口，**在本安装方式下这个窗口基本不存在** ——
> `V8R6_cluster_install.sh` 一次性完成 initdb、建备库并把集群拉起（安装结束时 kbha cron 已生成，见 §5.4）。
> 也就是说，`$PGDATA/sys_wal` 里**一定已经有 WAL 段与 `archive_status`**，
> **直接 `mount /dev/$VG/syswal $PGDATA/sys_wal` 会把原内容整个遮住** —— 库要么起不来，要么丢掉未归档的 WAL。

**因此域② 只有两条合法路径，二选一并书面记录：**

| 选择 | 做法 |
| --- | --- |
| **拆独立 LV**（推荐配置版） | ⛔ **不要按本文档执行 —— 打开《环境说明与参数基线》1.4.4 的 2.S，逐条照做。** 本节只负责告诉你"什么时候做、前置条件是什么"，**不复述任何执行步骤** |
| **不拆**，走补偿分支 | 不建 `syswal` LV，改为落实 WAL 容量硬控制 + 70/80/90 三级告警 + slot `retained_wal` 告警 + 恢复 SOP + 架构/业务方**书面接受残留风险**（基线 C.5-14 ③ 的第二个勾） |

> ⚠️⚠️ **v1.1.6 删除了本节原有的 2.S 步骤摘要。**
> 上一版在这里写了一句"停库硬门 → 临时挂载 + rsync 迁移 → 二次 dry-run → `.old` → fstab → 恢复 + **三条断言**"，
> 而基线 v1.3.16 的 2.S 实际已经是"**纯预检（不挂载不复制）→ `.old` → fstab + 挂载并复核 UUID → 唯一一次带 `--delete` 的复制 → 五条机器断言 → 重试前清空目标卷**"。
> **摘要也是一种副本，一样会漂移** —— 这与附录 B「不再内嵌脚本源码」、第 2 章「不维护第二份可执行 SOP」是同一条治理原则。
>
> **本节的唯一执行真源是基线 1.4.4 的 2.S，禁止按本文摘要替代执行。**

**本节只保留三件事：**

| # | 内容 |
| --- | --- |
| 1 | **前置状态**：集群已装完并拉起，`$PGDATA/sys_wal` 里已有 WAL 段与 `archive_status`；块设备已在 §2A 备好且**未挂载**；`/root/kb_plan.env` 与 `/root/kb_mseq.sh` 两节点各一份 |
| 2 | **时间点**：第 5 章之后、**第 7 章 WAL 参数落地之前**，在受控维护窗口内执行（见 §5.5） |
| 3 | **不可协商的约束**：域② 的 fstab 条目**不得含 `nofail`**；两节点分别执行；接入后须记录**实际挂载设备的 UUID 与容量**，填入附录 C |

> ⚠️ **只 `lvcreate` + `mkfs` 不等于域② 已独立** —— 那只会得到一块格式化完、从此没挂上的 LV，
> 而真正的 `$PGDATA/sys_wal` 仍在 DATA 盘上。**这是 v1.1.3 的执行链缺口，v1.1.4 补上指引。**

> ⚠️⚠️ **域② 一律不加 `nofail`（与域③ 的取舍不同，见基线 2.S）**：
> 域③ 挂载失败只是备份与日志写回根盘，`df` 看得出来；
> **域② 挂载失败是 WAL 静默写回根盘 —— 库照常跑、复制照常、备份照常，没有任何现象，隔离已经没了却无人知晓。**
> 并把 `findmnt -T "$KB_DATA/sys_wal"` 纳入开机后巡检。

> **本章仍不维护第二份可执行 SOP** —— 域② 与域③ 的执行步骤一律以基线 1.4.4 为唯一真源。


---

# 第 3 章 操作系统准备

## 3.1 用户与目录

```bash
# [root][两节点]
groupadd kingbase 2>/dev/null
useradd -g kingbase -m -d /home/kingbase kingbase 2>/dev/null
# ★ v1.1.6：不要把占位符直接粘进命令 —— 那会把口令字面设成"<设定口令>"
KB_OS_PASS=            # 填入 kingbase 系统用户口令，留空即 STOP
[ -n "${KB_OS_PASS:-}" ] || { echo "STOP: KB_OS_PASS 未填写"; exit 1; }
printf 'kingbase:%s\n' "$KB_OS_PASS" | chpasswd
unset KB_OS_PASS
mkdir -p /home/kingbase/cluster || { echo "STOP: 创建目录失败"; exit 1; }
chown -R kingbase:kingbase /home/kingbase || { echo "STOP: 设置属主失败"; exit 1; }
```

## 3.2 limits.conf

```bash
# [root][两节点]
cat >> /etc/security/limits.conf <<'EOF'
root            soft    core            unlimited
root            hard    core            unlimited
root            soft    nproc           unlimited
root            hard    nproc           unlimited
root            soft    nofile          300000
root            hard    nofile          300000
kingbase        soft    core            unlimited
kingbase        hard    core            unlimited
kingbase        soft    nproc           unlimited
kingbase        hard    nproc           unlimited
kingbase        soft    nofile          300000
kingbase        hard    nofile          300000
kingbase        soft    memlock         unlimited
kingbase        hard    memlock         unlimited
EOF
```

> **★ 现场教训（6）**：厂商官方《集群安装指南》中这一行写作 **`kingbase soft nole 300000`** —— **`nofile` 拼成了 `nole`**。这个拼写错误**不会报错，只会被静默忽略**，导致 soft nofile 实际未生效。**照抄指南的现场都会中招。**

**必须实测两个层面（`limits.conf` 只对登录会话生效）：**

```bash
# [root][两节点]
su - kingbase -c 'ulimit -Sn; ulimit -Hn'                    # 期望 300000 300000
# 数据库起来后再查进程实际限制：
grep -E 'Max open files|Max locked memory' /proc/$(pgrep -o kingbase)/limits
```

## 3.3 sysctl（★ 已修正官方指南的 6 处问题）

```bash
# [root][两节点]
cat >> /etc/sysctl.conf <<'EOF'
# ===== 内核资源 =====
kernel.sem = 50100 64128000 50100 1280
fs.file-max = 7672460
fs.aio-max-nr = 1048576

# ===== 内存 =====
vm.swappiness = 1
vm.min_free_kbytes = 512000
vm.vfs_cache_pressure = 200
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5

# ===== 网络（HA 流复制链路需要较大 socket buffer）=====
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 32768
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 8192 87380 16777216
net.ipv4.tcp_wmem = 8192 65536 16777216
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2

# ===== 以下三项【刻意不设置】，回落内核按内存自动计算的默认值 =====
#   net.ipv4.tcp_mem              官方指南值不满足 low<pressure<max，且 64KB 页折合约 5.7TB
#   net.ipv4.tcp_max_tw_buckets   官方指南值 6000，远低于内核默认
#   net.ipv4.tcp_max_orphans      官方指南值 3276800，折合约 200GB
# ===== 以下一项【禁止设置】 =====
#   net.ipv4.tcp_tw_recycle       Linux 4.12+ 已移除；NAT 环境下导致连接被静默丢弃
EOF

sysctl -p
```

> **★ 现场教训（7）**：上面注释掉的四项**全部出自厂商官方《集群安装指南》**，不是现场随手写的。若已经写进过 `sysctl.conf`：
>
> ```bash
> # [root][两节点]  删除这三行后【必须重启 OS】才能恢复内核默认值
> sed -i -E '/^net\.ipv4\.tcp_mem/d; /^net\.ipv4\.tcp_max_tw_buckets/d; /^net\.ipv4\.tcp_max_orphans/d; /^net\.ipv4\.tcp_tw_recycle/d' /etc/sysctl.conf
> # 重启后复验（应为内核计算值，而非人为设定值）
> sysctl net.ipv4.tcp_mem net.ipv4.tcp_max_tw_buckets net.ipv4.tcp_max_orphans
> ```
>
> **从 `sysctl.conf` 删行不会让已写入 `/proc/sys/` 的运行值自动恢复。**

## 3.4 THP 与大页

```bash
# [root][两节点]  —— 立即生效
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
cat /sys/kernel/mm/transparent_hugepage/enabled     # 期望 always madvise [never]

# 持久化
sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 transparent_hugepage=never"/' /etc/default/grub
grep GRUB_CMDLINE_LINUX /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg    # UEFI 机器路径可能是 /boot/efi/EFI/kylin/grub.cfg
```

**大页尺寸随架构而变，装机前必须实测：**

```bash
# [root][两节点]
getconf PAGESIZE                        # ARM64 Kylin V10 通常 65536（64KB）
grep -i hugepagesize /proc/meminfo      # 64KB 页 → 512MB 大页；x86 4KB 页 → 2MB 大页
```

| 平台 | 大页尺寸 | 预留方式 | 首轮建议 |
| --- | --- | --- | --- |
| **ARM64 / Kylin V10** | 512MB | 内核 cmdline（运行期分配易失败） | `huge_pages = off` |
| **x86_64** | 2MB | `vm.nr_hugepages`（运行期可设） | `huge_pages = on` |

> **★ 现场教训（8）**：ARM64 的 64KB 基础页已提供相当于 x86 4KB 页 **16 倍**的 TLB 覆盖，缺大页仅损失约 800MB 页表；**而 x86 上不配大页会浪费数 GB**。
> ⚠️ **预留与启用必须成对**：预留了大页而 `huge_pages=off`，这块内存被内核划走但数据库不用。**归还方式**：未被占用时缩减 `vm.nr_hugepages` 即可归还；ARM64 的实际困难是运行期重新分配 512MB 连续物理页容易失败，且 **GRUB 中的预留参数不删除、下次重启会重新预留**。

## 3.5 systemd

```bash
# [root][两节点]
sed -i 's/^#\?DefaultTasksAccounting=.*/DefaultTasksAccounting=no/' /etc/systemd/system.conf
sed -i 's/^#\?RemoveIPC=.*/RemoveIPC=no/'                        /etc/systemd/logind.conf
systemctl daemon-reload && systemctl daemon-reexec
systemctl restart systemd-logind
systemctl set-property cron.service TasksMax=65535
```

## 3.6 时间同步（★ HA 集群必须）

```bash
# [root][两节点]
timedatectl set-timezone Asia/Shanghai
systemctl enable --now chronyd 2>/dev/null || systemctl enable --now ntpd
chronyc sources 2>/dev/null || ntpq -p
date                                    # 两节点时间差应在秒级以内
```

## 3.7 防火墙与 SELinux

```bash
# [root][两节点]
# 【通用做法】按安全策略放通，而不是直接关闭
firewall-cmd --permanent --add-port=${DB_PORT}/tcp --add-port=8890/tcp
firewall-cmd --permanent --add-rich-rule='rule protocol value=icmp accept'
firewall-cmd --reload
firewall-cmd --list-all

# 【若项目已书面批准关闭，才执行以下两行】
# systemctl disable --now firewalld
# setenforce 0 && sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
```

## 3.8 ★ ping capability 验证（trusted_servers 检测依赖）

```bash
# [root][两节点]
getcap /bin/ping                              # 期望含 cap_net_raw
sysctl net.ipv4.ping_group_range
id -g kingbase
sudo -u kingbase /bin/ping -c 3 -w 2 $GW      # ★ 唯一有效的功能验证
```

> **★ 现场教训（9）**：本现场 `/bin/ping` 是 **755、无 setuid**，靠 **file capability** 才能被非特权用户使用。**`test -x` 只验证可执行位，证明不了能发 ICMP 包。**
> 若 capability 因升级/重装/还原丢失，`repmgrd` 的 trusted_servers 检测会持续失败 → **repmgrd 关闭 → HA 静默降级**：**数据库端口通、监控全绿，直到真正需要切换才发现**。
> **把 `getcap /bin/ping` 纳入日常巡检。**

**若 capability 丢失：**

```bash
# [root]
setcap cap_net_raw+ep /bin/ping
getcap /bin/ping
```

---

# 第 4 章 介质准备与 install.conf

## 4.1 介质

```bash
# [kingbase][仅主节点]
mkdir -p /home/kingbase/kdb_install || { echo "STOP: 创建目录失败"; exit 1; }
# 上传 KingbaseES_V008R006C009B0014_Aarch64_install.iso 与 license.dat 到该目录
# [root]
chown -R kingbase:kingbase /home/kingbase/kdb_install || { echo "STOP: 设置属主失败"; exit 1; }
mount -o loop /home/kingbase/kdb_install/KingbaseES_*_install.iso /mnt
ls /mnt
```

> ⚠️ **注意架构**：aarch64 机器必须用 Aarch64 介质。

## 4.2 install.conf 完整配置

```bash
# [kingbase][仅主节点]
mkdir -p /home/kingbase/r6_install || { echo "STOP: 创建目录失败"; exit 1; }
cd /home/kingbase/r6_install
# 从 /mnt/ClientTools/guitools/DeployTools/zip/ 拷贝 db.zip、V8R6_cluster_install.sh、install.conf
cp /mnt/ClientTools/guitools/DeployTools/zip/{db.zip,V8R6_cluster_install.sh,install.conf} .
cp /home/kingbase/kdb_install/license.dat .
```

```ini
# ===================== install.conf（本现场实际取值）=====================
# ---- 节点 ----
on_bmj=0
all_ip=(192.168.72.18 192.168.72.19)
witness_ip=""                      # ⚠️ 两节点无 witness —— 脑裂风险见 §12.1
production_ip=()
local_disaster_recovery_ip=()
remote_disaster_recovery_ip=()
virtual_ip="192.168.72.22/24"
net_device=(enp18s0 enp18s0)
net_device_ip=(192.168.72.18 192.168.72.19)
trusted_servers="192.168.72.254"   # ⚠️ 建议 2~3 个，见 §4.3

# ---- 安装 ----
install_dir="/home/kingbase/cluster"
zip_package="/home/kingbase/r6_install/db.zip"
license_file=(license.dat)
data_directory="/home/kingbase/cluster/kingbase/data"
super_user="root"
execute_user="kingbase"
deploy_by_sshd=0                   # 0=手动分发 1=SSHD 自动分发
use_scmd=1                         # 走 sys_securecmdd，非 SSH
ssh_port="22"
scmd_port="8890"
ipaddr_path="/sbin"
arping_path="/opt/kes/bin"
ping_path="/bin"

# ---- 数据库（★ initdb 期属性，装完不可改）----
db_user="system"
db_port="54321"
db_mode="oracle"
db_case_sensitive="no"             # → enable_ci=on
db_auth="scram-sha-256"            # ★ 装机即设定，可免去事后重置全部口令
db_checksums="yes"                 # ★ 数据校验和；隐含 hint bit 日志（sys_rewind 前提）
encoding="UTF8"
locale="en_US.UTF-8"

# ---- HA ----
ha_running_mode="DG"
synchronous="quorum"
failover="automatic"
recovery="automatic"
auto_cluster_recovery_level='1'
reconnect_attempts="10"
reconnect_interval="6"
monitoring_history="no"
use_check_disk='off'               # 超融合虚拟存储抖动可能误判

# ---- 归档 ----
archive_mode="always"              # ★ single-pro 每节点独立 repo 时必须为 always
```

## 4.3 关键选型说明

**`synchronous` 与备库定位的联动：**

| 备库定位 | `synchronous` | `synchronous_commit` | `hot_standby_feedback` |
| --- | --- | --- | --- |
| **纯故障接管，不承担读**（本现场） | `quorum` | **`on`** | **`off`** |
| 承担读，且要求写后立即可见 | `quorum` | `remote_apply` | `on` + `max_standby_streaming_delay` |
| 可用性优先，接受数据丢失 | `async` | `on` | `off` |

> **★ 现场教训（10）**：**在同步备库健康、且 `synchronous_standby_names` 非空的前提下**，`on` 与 `remote_apply` 的 RPO 都是 0 —— `on` 等备库 fsync 落盘，已保证不丢数据。`remote_apply` 多出的"等重放"买到的是**备库读一致性**和 replay lag≈0。**备库不读时，这笔延迟基本白花，且每笔事务都要付。**
> ⚠️ **前提不成立则结论失效**：若同步备库故障导致降级为异步，`synchronous_commit=on` **不再保证 RPO=0**。

**`trusted_servers` 选型原则：**

> **目标应当在「本节点真正被隔离时恰好不可达」。**
> 判定逻辑是「**任一可达即认为网络正常**」，因此增加目标**降低误判、但会提高漏判**——同二层域内的服务器在上联口故障时可能仍可达，反而掩盖真实隔离。**按此标准网关是合理选择**（ping 不通自己的网关基本等同于真被隔离），厂商官方也推荐网关地址。建议 **2~3 个且分布在不同故障路径**。

**`running_under_failure_trusted_servers`（repmgr.conf，默认 `on`）：**

| 取值 | 全部 trusted_server 不可达时 |
| --- | --- |
| `on`（默认） | 数据库**继续运行**；但 **repmgrd 关闭，自动 failover 能力丧失** |
| `off` | 集群**关闭数据库**，避免数据分歧 |

> ⚠️ `on` 是**静默降级**：端口通、监控全绿，HA 已死。**必须把 repmgrd / kbha 进程存活纳入独立监控。**

---

# 第 5 章 集群安装执行

## 5.1 手动分发方式（`deploy_by_sshd=0`，本现场采用）

```bash
# [kingbase][两节点]
mkdir -p /home/kingbase/cluster/kingbase || { echo "STOP: 创建目录失败"; exit 1; }
# 将 db.zip 与 license.dat 拷贝到每个节点的该目录
cd /home/kingbase/cluster/kingbase
unzip -q db.zip
cp /home/kingbase/r6_install/license.dat ./bin/
ls -l bin/license.dat
```

```bash
# [root][两节点]  —— 启动 sys_securecmdd
cd /home/kingbase/cluster/kingbase/bin
./sys_HAscmdd.sh init
./sys_HAscmdd.sh start
ss -lntp | grep 8890                 # 期望监听
```

```bash
# [kingbase][仅主节点]  —— 执行安装
cd /home/kingbase/r6_install
sh V8R6_cluster_install.sh
```

## 5.2 SSHD 自动分发方式（`deploy_by_sshd=1`）

```bash
# [root][仅主节点]  —— 先做 SSH 免密
cd /home/kingbase/r6_install
sh trust_cluster.sh
# 验证所有节点 root 与 kingbase 之间免密
ssh 192.168.72.19 hostname
su - kingbase -c 'ssh 192.168.72.19 hostname'
```

```bash
# [kingbase][仅主节点]
sh V8R6_cluster_install.sh
```

## 5.3 环境变量

```bash
# [kingbase][两节点]
cat >> ~/.bash_profile <<'EOF'
export KB_HOME=/home/kingbase/cluster/kingbase
export PATH=$PATH:$KB_HOME/bin
export KINGBASE_DATA=$KB_HOME/data
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$KB_HOME/lib
EOF
source ~/.bash_profile
which ksql repmgr sys_ctl
```

## 5.4 安装后自动生成的产物

| 产物 | 位置 | 说明 |
| --- | --- | --- |
| 数据目录 | `$KB_HOME/data` | — |
| `kingbase.conf` | 同上 | 主配置 |
| **`es_rep.conf`** | 同上 | **★ 集群工具生成，经 include 覆盖 `kingbase.conf`** —— 见第 6 章 |
| `kingbase.auto.conf` | 同上 | repmgr 维护（`primary_conninfo` / `primary_slot_name` / `synchronous_standby_names`） |
| `initdb.conf` | 同上 | initdb 期属性 |
| `repmgr.conf` | `$KB_ETC` | 集群配置 |
| `logrotate_ha.conf` | `$KB_ETC` | HA 日志轮转（**由 `sys_monitor.sh` 生成/重写**） |
| `all_nodes_tools.conf` | `$KB_ETC` | ⚠️ **含 base64 编码的 system 口令**，见 §9.2 |
| **kbha 拉起 cron** | `kingbase` 用户 crontab | **★ 每分钟一次 —— 这就是启动控制链** |

> **★ 现场教训（11）：数据库不由 systemd 管理。**
> 本现场 `kingbased.service` **不存在**，`/etc/rc.local` 只有默认模板，root 无 crontab。真正的启动链是：
>
> ```cron
> */1 * * * *  . /etc/profile;$KB_HOME/bin/kbha -A daemon -f .../etc/repmgr.conf
> ```
>
> **VM 重启后的行为取决于回归策略决策：**
>
> | 策略 | kbha cron | VM 重启后 |
> | --- | --- | --- |
> | **自动回归** | 保留（活动行 = 1） | ≤60 秒内 cron 拉起 kbha，依 `recovery=automatic` 尝试 rejoin |
> | **人工回归** | 注释（活动行 = 0） | **数据库不应自行拉起**（这是预期行为，不是故障） |
>
> **两种都是合法策略，必须书面决定。** 保留人工决策点的**唯一办法是注释这行 cron**——`systemctl disable` 在这套环境里无效。

---

## 5.5 ★ 跳转点：若选择独立 `sys_wal`，现在回到 §2B

> **集群到这里已经装完并拉起，`$PGDATA/sys_wal` 里已经有 WAL 段与 `archive_status`。**
> 这正是 **§2B（= 基线 1.4.4 的 2.S）** 要求的前置状态。

| 域② 的决策 | 现在做什么 |
| --- | --- |
| **拆独立 LV** | ⛔ **先不要进第 6 章。** 进入受控维护窗口，回到 **§2B**，**打开基线 1.4.4 的 2.S 逐条照做**（本文档不复述步骤，理由见 §2B）。完成判据：2.S 的全部机器断言通过，且已记录**实际挂载设备的 UUID 与容量** |
| **不拆，走补偿分支** | 直接进第 6 章；但必须在上线前落实 WAL 容量硬控制 + 三级告警 + slot `retained_wal` 告警 + 恢复 SOP + **书面接受残留风险** |

> ⚠️ **顺序不能颠倒的两点：**
> · **2.S 必须在第 7 章 WAL 参数落地【之前】完成** —— 否则 `wal_keep_segments` 一提上去，`sys_wal` 会先把根盘撑起来；
> · **已投产现场若还要做域③ 的存储改造（基线 1.4.4 的 2.3b / 2.4～2.7c）**，`sys_wal` 的接入要与之放在**同一个维护窗口**内按基线顺序执行，
> 　因为 2.S 取的是 `readlink -f $KB_DATA` 的**解链后真实路径**，DATA 一旦移动，fstab 里的 `sys_wal` 条目就要跟着改（见基线 2.3b 的警示）。

---

# 第 6 章 ★ 安装后立即做配置源收敛

> **本章是全文最重要的一章。跳过它，后面所有参数调优都可能白做。**

## 6.1 实际加载链

```
kingbase.conf
   └── 第 773 行:  include_if_exists = 'es_rep.conf'      ← 在文件【末尾】
          └── es_rep.conf                                  ← 后加载 = 覆盖前面
kingbase.auto.conf                                         ← repmgr 维护，优先级最高
```

**优先级（低 → 高）：**
`kingbase.conf` → `es_rep.conf` → `kingbase.auto.conf` → 命令行 → `ALTER DATABASE/ROLE SET` → 会话 `SET`

## 6.2 ★ 现场教训（12）：改了不生效

本现场实测到的覆盖：

| 参数 | `kingbase.conf` | `es_rep.conf` | **实际生效** |
| --- | --- | --- | --- |
| `shared_buffers` | `:122` = 24GB | `:41` = 16GB | **16GB** |
| `work_mem` | `:132` = 32MB | `:35` = 10MB | **10MB** |
| `max_wal_size` | `:227` = 1GB | `:38` = 64GB | **64GB** |
| `timezone` | `:658` = Asia/Shanghai | `:24` = PRC | **PRC** |
| `archive_command` | `:237` = **`exit 0`** | `:10` = sys_rman | sys_rman |

**有人在 `kingbase.conf` 里做的调优，其中一部分根本没有生效。**

> ⚠️⚠️ **`kingbase.conf:237` 的 `archive_command = exit 0`** 是一条"假装归档成功"的空操作，目前**仅靠 `es_rep.conf` 覆盖才没生效**。**若日后删除或改动那行 `include_if_exists`，归档会立刻变成静默丢弃且不报任何错。**

## 6.3 `es_rep.conf` 自身也是两段拼接

本现场 `es_rep.conf` 由**部署工具生成的上半段**与**人工追加的下半段**组成，**内部有 12 处同名参数**：

| 参数 | 上半段 | 下半段 | 生效 |
| --- | --- | --- | --- |
| `shared_buffers` | 512MB | **16GB** | 16GB |
| `max_connections` | 100 | **2000** | 2000 |
| `log_destination` | csvlog | **stderr** | stderr |
| `listen_addresses` / `port` / `logging_collector` / `log_checkpoints` | 各 1 次 | 各 1 次 | 值相同 |

## 6.4 收敛操作（可复制）

```bash
# [kingbase][两节点]  —— ① 先看 include 链
grep -nE '^[[:space:]]*include' $KB_DATA/kingbase.conf
ls -l $KB_DATA/*.conf
ls -l $KB_DATA/conf.d/ 2>/dev/null || echo "(无 conf.d)"
```

```sql
-- ② 配置错误【必须 0 行】
SELECT sourcefile, sourceline, name, setting, applied, error
FROM sys_file_settings
WHERE error IS NOT NULL
ORDER BY sourcefile, sourceline;
```

```sql
-- ③ 被重复定义的参数
SELECT name, count(*) AS n,
       string_agg(sourcefile || ':' || sourceline || ' = ' || setting, ' | '
                  ORDER BY sourcefile, sourceline) AS entries
FROM sys_file_settings
GROUP BY name HAVING count(*) > 1
ORDER BY name;
```

```sql
-- ④ ★ 被覆盖的条目及其覆盖者 —— 改参数前必看
SELECT f.name,
       f.sourcefile || ':' || f.sourceline AS ignored_at, f.setting AS ignored_val,
       w.sourcefile || ':' || w.sourceline AS winner_at,  w.setting AS winner_val
FROM sys_file_settings f
LEFT JOIN LATERAL (SELECT sourcefile, sourceline, setting
                   FROM sys_file_settings w
                   WHERE w.name = f.name AND w.applied
                   ORDER BY sourceline DESC LIMIT 1) w ON true
WHERE f.applied = false AND f.error IS NULL
ORDER BY f.name;
```

**收敛动作：**

```bash
# [kingbase][两节点]  —— 备份后编辑
cp -a $KB_DATA/kingbase.conf $KB_DATA/kingbase.conf.$(date +%Y%m%d_%H%M%S).bak
cp -a $KB_DATA/es_rep.conf   $KB_DATA/es_rep.conf.$(date +%Y%m%d_%H%M%S).bak

# ① 删除 kingbase.conf 中的 archive_command = exit 0
# ② 清理 es_rep.conf 内部的同名重复，每个参数只保留一次
# ③ 明确每个待调参数落在哪个文件（推荐统一收敛到 es_rep.conf）
vi $KB_DATA/kingbase.conf
vi $KB_DATA/es_rep.conf
```

```bash
# [kingbase][仅主节点]  —— reload 后复验
ksql -U system -p $DB_PORT -d test -c "SELECT sys_reload_conf();"
# 再跑一次上面的 ②③④，确认无 error、无未解释的重复
```

---

# 第 7 章 参数落地

## 7.1 落地位置

> ⚠️ **本现场须写入 `es_rep.conf`**（`kingbase.conf` 的同名项会被覆盖）。其他现场先用 §6.4 的第 ④ 条 SQL 确认自己的覆盖链。

## 7.2 推荐参数（64GB / 32C / ARM64 / DG / 备库不承担读）

```ini
# ===== 内存与连接 =====
# ★★ 必填项：未取得外部输入前【保持注释】，不得凭默认值上线（与基线 F.18 同口径）
#    取值 = 应用连接池 maxTotal 汇总峰值 × 1.2，一次定值
#    ⚠️ 不要写成 max_connections = <待定> —— 整段复制会让数据库【配置解析报错】
# max_connections = 500
superuser_reserved_connections = 3
shared_buffers = 20GB
effective_cache_size = 40GB
work_mem = 8MB
maintenance_work_mem = 2GB
autovacuum_work_mem = 512MB
wal_buffers = 16MB
max_locks_per_transaction = 1024
max_prepared_transactions = 100

# ===== WAL 与检查点（★ 两项必须成对，满足 8 倍规则）=====
wal_level = replica
max_wal_size = 8GB
min_wal_size = 2GB
wal_keep_segments = 4096
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
wal_log_hints = on
wal_compression = on
full_page_writes = on
fsync = on

# ===== 复制与高可用 =====
hot_standby = on
hot_standby_feedback = off
synchronous_commit = on
max_wal_senders = 32
max_replication_slots = 32
wal_sender_timeout = 30000
wal_receiver_timeout = 30000
wal_receiver_status_interval = 2
archive_mode = always

# ===== TCP（服务端）=====
tcp_keepalives_idle = 2
tcp_keepalives_interval = 2
tcp_keepalives_count = 3
tcp_user_timeout = 9000

# ===== 自动清理 =====
autovacuum = on
autovacuum_max_workers = 6
autovacuum_naptime = 30s
autovacuum_vacuum_cost_limit = 2000

# ===== 并行（约束：per_gather + maintenance ≤ parallel_workers ≤ worker_processes）=====
max_worker_processes = 32
max_parallel_workers = 16
max_parallel_workers_per_gather = 2
max_parallel_maintenance_workers = 4

# ===== IO（UAT 起点值，需实测调整）=====
random_page_cost = 1.2
effective_io_concurrency = 128

# ===== 大页（ARM64 首轮 off；x86 应为 on 并先设 vm.nr_hugepages）=====
huge_pages = off

# ===== 日志 =====
logging_collector = on
log_destination = csvlog
# ===== 存储方案二选一：本文档全篇 active = MNT-SITE（与基线 v1.3.14 一致）=====
log_directory = /data/kingbase/backup/log   # MNT-SITE（现场环境版）
# log_directory = /data/kingbase/log        # MNT-MOVE（推荐配置版：用本行替换上行）
# ★★ 两版方案【都】必须显式修改本项，不存在"不改"的那一版：
#    现场当前值是【相对路径】sys_log，它相对数据目录解析、跟着 DATA 走 ——
#    MNT-SITE 下仍在 DATA 内部；MNT-MOVE 下会随 DATA 一起回到根盘。
# ★★ 必须改在 es_rep.conf，不是 kingbase.conf（见第 6 章覆盖链），
#    执行位置是基线 1.4.4 的 2.7c 配置同步硬门，起库后由 2.10 第五项断言以 SHOW 运行值复验。
# 判据：实际日志目录必须与 DATA 不在同一文件系统（§2.1）
log_filename = kingbase-%Y-%m-%d_%H%M%S.log
log_rotation_age = 1d
log_rotation_size = 0
log_truncate_on_rotation = off
log_line_prefix = %m [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h
log_min_duration_statement = 2000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_statement = ddl
log_temp_files = 0
log_autovacuum_min_duration = 0
log_replication_commands = on
log_timezone = Asia/Shanghai

# ===== 其他 =====
listen_addresses = *
port = 54321
password_encryption = scram-sha-256
timezone = Asia/Shanghai
datestyle = iso, ymd
```

> ⚠️ **`log_filename` 用时间戳形式后文件名永不重复，`log_truncate_on_rotation` 失去作用** —— **必须由 OS 侧独立清理任务负责保留期**（同时覆盖 `.csv` 与 `.log`）。**轮转 ≠ 保留。**

## 7.3 ★ WAL 8 倍规则校验（落地后必做）

```
wal_keep_segments × wal_segment_size ≥ 8 × max_wal_size
```

```sql
-- [两节点]
SELECT (SELECT setting::bigint FROM sys_settings WHERE name='wal_keep_segments')
     * (SELECT setting::bigint FROM sys_settings WHERE name='wal_segment_size') AS keep_bytes,
       8 * (SELECT setting::bigint*1048576 FROM sys_settings WHERE name='max_wal_size') AS need_bytes;
-- keep_bytes ≥ need_bytes 才算合规
```

> **★ 现场教训（13）**：本现场实测 `max_wal_size = 64GB` 而 `wal_keep_segments = 512`：
>
> ```
> 保留 512 × 16MB = 8GB      需要 8 × 64GB = 512GB      ❌ 差 64 倍
> down_wal_size 设计上限 = 512 × 16MB ÷ 4 = 2GB
> ```
>
> 即主库只要产生超过约 2GB WAL，故障备库就不再保证能仅靠本地 WAL 自动 rejoin——而 `max_wal_size` 却允许两次检查点间累积 64GB。**这两个值必须成对设计。**

> ⚠️ **改动顺序有依赖**：`wal_keep_segments` 从 512 提到 4096，本地 WAL 常驻量从 8GB 涨到 64GB。**必须先完成第 2 章的容量域隔离，再改 WAL 参数**——否则等于把根盘写满的风险放大 8 倍。

## 7.4 ★ 全局超时参数（必须与业务确认）

```ini
statement_timeout = 60min                    # ★ 全局语句超时
idle_in_transaction_session_timeout = '2h'
```

> **★ 现场教训（14）**：本现场 `es_rep.conf` 下半段设了 **`statement_timeout = 60min`，全局生效** —— 任何运行超过 60 分钟的语句会被强制终止，**包括在线建索引、大批量导入、大表 VACUUM FULL、数据迁移**。
> **必须确认是有意设置还是随模板带入。** 若保留，所有运维作业须显式：
>
> ```sql
> SET statement_timeout = 0;
> ```

---

# 第 8 章 备份体系部署

## 8.1 ★ 物理备份（sys_rman）执行顺序不可颠倒

```
集群安装完成
   ↓
启动数据库，确认 Primary + Standby 均 online
   ↓
sys_backup.sh init          ← ★ 全集群【只执行一次】
   ↓
确认两节点 repo 结构与 archive_command、首次全备已成功
   ↓
sys_backup.sh start         ← ★ single-pro 形态下【每节点分别执行】
   ↓
复核 cron
```

> **★ 现场教训（15）**：`sys_backup.sh init` **依赖数据库实例正常运行** —— 它会检查未归档 WAL、修改各节点 `archive_command`、reload 数据库、创建 stanza 并执行第一次全备，**停库状态下执行必然失败**。
> 同时：**「每节点独立 repo」不等于「两节点分别 init」**。`single-pro` 的规则是**整个集群只 init 一次、`start` 逐节点执行**。

```bash
# [kingbase][仅主节点]
repmgr cluster show                              # 确认主备均 online
$KB_HOME/bin/sys_backup.sh init
```

```sql
-- 确认归档推进
SELECT * FROM sys_stat_archiver;
```

```bash
# [kingbase][两节点分别执行]
$KB_HOME/bin/sys_backup.sh start
```

## 8.2 `sys_rman.conf` 关键项

```ini
[kingbase]
kb1-path=/home/kingbase/cluster/kingbase/data
kb1-port=54321
kb1-user=esrep
kb2-path=/home/kingbase/cluster/kingbase/data
kb2-port=54321
kb2-user=esrep
kb2-host=192.168.72.19
kb2-host-user=kingbase

[global]
repo1-path=/data/kingbase/backup/rman
repo1-retention-full=2          # 保留 2 个全备
compress-type=none              # ⚠️ 不压缩 → 空间需求约翻倍，建议评估改 gz
compress-level=3
process-max=4
repo-disk-warn=16384MB          # ⚠️ 剩余空间告警阈值；卷容量小时该值几乎立即触发
repo-disk-error=1024MB
non-archived-space=1024
archive-timeout=600
backup-from=single-pro          # 每节点独立 repo
archive-mode-check=n
cmd-ssh=/home/kingbase/cluster/kingbase/bin/sys_securecmd
```

> ⚠️ **`repo-disk-warn=16384MB` 与卷容量必须匹配。** 本现场若把 `/data` 挂到 23.1G 的 `klas-backup` 上，该阈值几乎一挂载就触发。

## 8.3 ★ 现场教训（16）：`sys_backup.sh start` 会回写 cron

它按 `_crond_full_days` 重新生成定时任务，`_crond_full_days=7` 生成的正是 `0 2 */7 * *`。

> ⚠️ **`*/7` 在「日」字段不是「每 7 天」**，而是 **1 / 8 / 15 / 22 / 29 日** —— 29 号到下月 1 号只隔 2~3 天。
> 若手工改成 `0 2 * * 0`（每周日），**下一次 `sys_backup.sh start` 会把它改回去**。

**必须先定死「调度配置的唯一真源」：**

| 方案 | 做法 |
| --- | --- |
| **A** | 接受自动生成的 `*/7`，向业务方书面说明其实际日期语义 |
| **B** | 自定义周调度，并写入规程：**每次 `sys_backup.sh start` 后必须重新校验 cron** |

> **★ 现场教训（17）：cron 可能在两个位置。**
> 官方 `sys_backup.sh start/stop` 操作的是 **`/etc/cron.d/KINGBASECRON`**，而本现场实测备份任务在 **kingbase 用户 crontab**，`/etc/cron.d/KINGBASECRON` 根本不存在。

```bash
# [root][两节点]  —— ★ 合并两个域后，每类任务恰好 1 条
ACTIVE=$( { crontab -l -u kingbase 2>/dev/null
            cat /etc/cron.d/KINGBASECRON 2>/dev/null; } | grep -Ev '^[[:space:]]*(#|$)' )
echo "kbha          = $(printf '%s\n' "$ACTIVE" | grep -Fc 'kbha -A daemon')"
echo "backup8.sh    = $(printf '%s\n' "$ACTIVE" | grep -Fc 'backup8.sh')"
echo "sys_rman full = $(printf '%s\n' "$ACTIVE" | grep -Ec 'sys_rman.*--type=full')"
echo "sys_rman incr = $(printf '%s\n' "$ACTIVE" | grep -Ec 'sys_rman.*--type=incr')"
```

**判据**：`backup8.sh` / `full` / `incr` **各恰好 1**（=0 是备份静默停止，≥2 是重复备份）；`kbha` 按回归策略为 0 或 1。

## 8.4 ★ 逻辑备份（backup8.sh）—— 本现场发现的最隐蔽问题

> **★ 现场教训（18）**：本现场 `backup8-edit.conf` 内容为：
>
> ```ini
> kdb_home="/home/kingbase/ES/V8/Server"      # ← 单机版路径
> kdb_bin="/home/kingbase/ES/V8/Server/bin"   # ← 本现场实为 /home/kingbase/cluster/kingbase/bin
> password="12345678ab!"                      # ← 明文口令
> kdb_list=`${kdb_home}/bin/ksql ...`         # ← kdb_home 已含 /Server，拼出 .../Server/bin/bin/ksql
> ```
>
> **路径与现场不符，疑为未适配的模板。** 若 crontab 中 `0 2 * * * backup8.sh` 读的就是这份配置，**逻辑备份每天都在失败**——而这**从归档状态、repmgr 状态、甚至自动巡检脚本中都看不出来**（只检查 cron 行是否存在，不检查执行是否成功）。

**必须立即核实：**

```bash
# [kingbase]
ls -l  $BKS/
cat    $BKS/backup8.conf                  # ★ 脚本实际读的是 backup8.conf，不是 backup8-edit.conf
tail -50 $BKS/logical_backup.log
ls -lh /home/kingbase/backup/ 2>/dev/null # 是否真有 dmp 产出
```

**正确的 `backup8.conf`（适配本现场路径 + 免密，见附录 B.1）。**

## 8.4a ★ 逻辑备份的正确核对方式（本现场踩过三个坑）

> **核心原则：从数据库查出「应备份库清单」，再逐库核对产物 —— 而不是看 dump 目录下有什么。**
> 后者永远发现不了「某个库从来没被备过」。

### 坑一：每次备份产出两类文件，按最新取会取到日志包

```
/data/kingbase/backup/dump/dataassets/
  dataassets_2026090902.tar.gz              4.3M    ← 数据
  backup_log_dataassets_2026090902.tar.gz   184B    ← 日志归档，mtime 更晚
```

本现场曾因此判出「最新逻辑备份产物仅 184B」的 FAIL，实际备份完全正常。**必须显式排除 `backup_log_*`。**

### 坑二：★ 绝对字节阈值从根本上不成立

本现场实测：

| 库 | 最新产物 | `gzip -t` |
| --- | ---: | --- |
| `dataassets` | 4,435,601B | 完整 |
| **`esrep`** | **914B** | 完整 |
| **`test`** | **683B** | 完整 |
| `dataassets`（9/3 空库时期） | **618B** | 完整 |

> **这两个库本来就小，空库时期的备份更小。** 任何形式的「最小字节阈值」都会把它们误判为 FAIL。
>
> **正确的代理指标是 `gzip -t` 完整性**：中途失败的 tar.gz 无论大小都会报错，而空库的小备份再小也能通过 —— **与库大小无关**。趋势判断改用「与上次相比缩减 ≥50% 才 WARN」。

### 坑三：全树取最新会把某个库的缺失完全盖住

若只 `find dump/ -newest`，`dataassets` 正常就会掩盖其他库的问题。

### 正确做法

```bash
# [kingbase][两节点]
# ① 排除规则必须与 backup8.conf 同源（不要另写一份）
grep -o "not in ([^)]*)" /home/kingbase/backup_script/backup8.conf

# ② 查出应备份库清单
ksql -U system -p 54321 -d test -Atc \
  "SELECT datname FROM sys_database
   WHERE datname NOT IN ('kingbase','template1','template0','security') ORDER BY 1"

# ③ 逐库核对：排除 backup_log_*、按 mtime 取最新、校验完整性
for db in $(上一步的清单); do
    D=/data/kingbase/backup/dump/$db
    [ -d "$D" ] || { echo "$db  无 dump 目录（若为新建库属正常，须确认建库时间）"; continue; }
    f=$(find "$D" -maxdepth 1 -name '*.tar.gz' ! -name 'backup_log_*' \
             -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
    printf '%-20s %-42s %10sB  ' "$db" "$(basename "$f")" "$(stat -c%s "$f")"
    gzip -t "$f" 2>/dev/null && echo "完整" || echo "★ 损坏"
done
```

> **新建库的处理**：dump 目录不存在时应判 **WARN 转人工**（可能是建库晚于最近一次备份），不要直接 FAIL。本现场 `data_view` / `data_view_newdata` 即属此情形。
>
> ⚠️ **`gzip 完整` ≠ 可恢复** —— 最终仍以 **restore 演练**为准。

> **配套脚本 `kb_backup_check.sh` v1.1.7 已实现以上全部逻辑**（排除规则自动从 `backup8.conf` 解析，保持同源；v1.1.7 另补了 `-w`，并让连通性 ERROR 带出失败原因）。

---

## 8.5 off-cluster 副本

> **主库 VM、备库 VM、两份 repo 若都在同一超融合存储域内，这四份数据没有跨出同一个存储 / 管理保护域。**
> 需要准确表述：AIO 内部仍有多宿主机、多副本、磁盘与节点级容错，**并非任一单点硬件故障都会让四份全丢**。真正的风险在**存储池级、集群管理级或人为误操作级**故障。

> ⚠️⚠️ **「全备完成」不等于「repo 静止」** —— `archive_mode=always` 下 WAL 归档**持续**写入 repo。**「与备份 cron 错开」不能证明可以安全 rsync。**

**合法路径只有三条：**

| # | 方案 | 说明 |
| --- | --- | --- |
| **A** | 厂商受支持的 repo 复制 / 多仓库机制 | 首选，由产品保证一致性 |
| **B** | 存储级一致性快照后，复制**快照副本** | ⚠️ 复制对象是**快照副本**，不是活动 repo |
| **C** | 受控窗口内**真正停止 repo 写入**后再复制 | 判据：数据库已停 **AND** 无 `sys_rman`/`backup8.sh` 进程 **AND** repo 无写入进程持有 |

**方案 C 的实现**：`kb_offcluster_copy.sh`（脚本集 v1.1.7，批准清单见附录 B.1）。

> ✅ **v1.1.3 起该脚本已批准用于正式容灾复制**。v1.1.2 曾标注「暂不批准」，原因是 `lsof rc=1` 被解释成"确认无占用"（扫描不完整时同样返回 1，属 fail-open）；该缺陷已由脚本集 **v1.1.6** 修复为「结合 stderr 三分：扫描完整且 0 个打开文件 → PASS / 发现打开文件 → FAIL / 扫描不完整或权限错误 → ERROR」，并经定向故障注入复测确认。
>
> ⚠️ **运行前必须按现场存储方案设置 `EXPECT_REPO_MOUNT`**（repo 挂载点身份断言，防 `/data` 未挂载时误复制根盘下的同名空目录）：
>
> | 现场状态 | 取值 |
> | --- | --- |
> | 存储改造前（repo 仍在根盘） | `EXPECT_REPO_MOUNT=/` |
> | `MNT-SITE` 落地后 | `EXPECT_REPO_MOUNT=/data/kingbase/backup` |
> | `MNT-MOVE` 落地后 | `EXPECT_REPO_MOUNT=/data` |
>
> 取值命令：`findmnt -no TARGET -T "$REPO"`。**取错会被硬门直接挡下（这是预期行为，不是脚本故障）。**

---

# 第 9 章 安全加固

## 9.1 `sys_hba.conf` 收敛

> **★ 现场教训（19）**：本现场 `sys_hba.conf` 含：
>
> ```
> host  all          all  0.0.0.0/0  scram-sha-256
> host  replication  all  0.0.0.0/0  scram-sha-256
> host  replication  all  ::0/0      scram-sha-256
> ```
>
> **复制权限对全网开放。** 虽为 scram 认证，等保场景通常不接受。

**推荐写法：**

```
# TYPE  DATABASE     USER    ADDRESS              METHOD
local   all          all                          scram-sha-256
host    all          all     127.0.0.1/32         scram-sha-256
host    all          all     ::1/128              scram-sha-256

# 复制：仅两节点与 VIP 网段
host    replication  esrep   192.168.72.18/32     scram-sha-256
host    replication  esrep   192.168.72.19/32     scram-sha-256

# 业务：按实际来源网段收敛，不要用 0.0.0.0/0
host    all          all     192.168.72.0/24      scram-sha-256
# host  all          all     <应用服务器网段>      scram-sha-256
```

```bash
# [kingbase][两节点]
cp -a $KB_DATA/sys_hba.conf $KB_DATA/sys_hba.conf.$(date +%F).bak
vi $KB_DATA/sys_hba.conf
ksql -U system -p $DB_PORT -d test -c "SELECT sys_reload_conf();"
ksql -U system -p $DB_PORT -d test -c "SELECT * FROM sys_hba_file_rules;"
```

## 9.2 口令与凭据

> **★ 现场教训（20）**：本现场口令以**两种不安全形式落盘**：
>
> | 文件 | 内容 |
> | --- | --- |
> | `backup_script/backup8-edit.conf` | `password="12345678ab!"` —— **明文** |
> | `$KB_ETC/all_nodes_tools.conf` | `db_password=MTIzNDU2NzhhYiEK` —— **base64，解开即同一口令** |
>
> **base64 是编码不是加密。** 数据库侧口令哈希全部合规（scram-sha-256），**问题在运维脚本侧**。

**推荐改用 `.kbpass`（免密文件）：**

> ⚠️ **v1.1.2 更正三处**（v1.1.1 写错）：
>
> | 项 | v1.1.1（错） | 正确 |
> | --- | --- | --- |
> | 环境变量名 | `KBPASSFILE` | **`KINGBASE_PASSFILE`**（默认位置本就是 `~/.kbpass`，通常无需设置） |
> | `-w` 参数 | 因现场注释「不能加 `-W`」而**撤销了 `-w`** | **两者相反，不能混为一谈**：`-w` = `--no-password`（禁止交互提示，**批处理正需要**）；`-W` = `--password`（强制提示输入密码，无人值守本就不该加）。现场证据只否定了 `-W`，**推不出 `-w` 不可用** |
> | 连接是否带 `-h` | 声称带、实际 `kdb_list` 未带 | **必须显式带 `-h`** —— `.kbpass` 首列按实际连接的 host 匹配；不带 `-h` 时匹配目标是 `localhost` 而非 `127.0.0.1` |

```bash
# [kingbase][两节点]
# ★ v1.1.6：口令改用变量，避免把"<口令>"字面写进 .kbpass
KB_DB_PASS=            # 填入 system 数据库用户口令，留空即 STOP
[ -n "${KB_DB_PASS:-}" ] || { echo "STOP: KB_DB_PASS 未填写"; exit 1; }
umask 077
printf '127.0.0.1:54321:*:system:%s\n' "$KB_DB_PASS" > ~/.kbpass
unset KB_DB_PASS
chmod 600 ~/.kbpass || { echo "STOP: 设置 .kbpass 权限失败"; exit 1; }   # ★ 权限必须 0600
export KINGBASE_PASSFILE=/home/kingbase/.kbpass  # 可选；默认即 ~/.kbpass。写入 ~/.bash_profile

# ★ 验证：-h 让 .kbpass 首列可匹配；-w 使无凭据时立即失败而非交互等待
ksql -h 127.0.0.1 -p 54321 -U system -d test -w -c "select 1;"
```

> ⚠️ **按 P0-20 的要求，须在现场真实跑通后再替换现有凭据**，不要直接照搬。

```bash
# [kingbase][两节点]  —— 收敛现有文件权限
chmod 600 $BKS/backup8.conf $KB_ETC/all_nodes_tools.conf || { echo "STOP: 设置配置文件权限失败"; exit 1; }
ls -l $BKS/backup8.conf $KB_ETC/all_nodes_tools.conf
# 并安排一次口令轮换
```

## 9.3 口令哈希核查

```sql
SELECT rolname,
       CASE WHEN rolpassword IS NULL               THEN '(无口令)'
            WHEN rolpassword LIKE 'SCRAM-SHA-256%' THEN 'scram-sha-256'
            WHEN rolpassword LIKE 'md5%'           THEN 'md5'
            ELSE 'other' END AS pwd_type
FROM sys_authid ORDER BY 2, 1;
-- 期望：无 md5 账号
```

---

# 第 10 章 安装后验证

## 10.1 一次跑完（推荐）

```bash
# [root][两节点]
sha256sum kbdc.sh    # 应为 5c04873b750c5a74f64ddae73b8b946116ddadf30f68e746a445243f4ba80d5c
bash kbdc.sh test
```

**输出为四态自动判定：**

| 状态 | 含义 | 处置 |
| --- | --- | --- |
| **PASS** | 满足判据 | — |
| **FAIL** | 不满足判据 | **阻断验收** |
| **WARN** | 需人工确认 | **必须有人工结论与证据记录** |
| **ERROR** | **证据缺失**（命令失败/查询失败/路径不存在） | **同样阻断——「取不到证据」不等于「通过」** |

> ⚠️ **该脚本只自动判定其覆盖的技术子项。全 PASS 不等于所有 P0 已关闭** —— 演练、restore、反亲和、业务签字、数据量确认、回归策略选择、VIP 全链路、告警实际触发验证均无法由单机脚本关闭。

## 10.2 集群层

```bash
# [kingbase][两节点]
repmgr cluster show
repmgr service status                     # ★ Paused? 列应全为 no
ps -ef | grep -E 'repmgrd|kbha|securecmdd' | grep -v grep
ss -lntp | grep 8890
ip -4 addr show $NET_DEV | grep secondary # VIP 归属
```

## 10.3 数据库层

```sql
-- initdb 期属性（装完不可改，必须核对）
SHOW database_mode;        -- 预期 oracle
SHOW enable_ci;            -- 预期 on
SELECT 'A' = 'a';          -- enable_ci=on 时预期 t
SHOW data_checksums;       -- 预期 on
SHOW server_encoding; SHOW lc_collate; SHOW lc_ctype;

-- HA
SHOW archive_mode;                   -- 预期 always
SHOW synchronous_standby_names;      -- ★ 主库应非空
SELECT * FROM sys_stat_replication;  -- ★ 主库：state=streaming 且 sync_state∈{sync,quorum}
SELECT * FROM sys_stat_wal_receiver; -- ★ 备库：status=streaming
SELECT * FROM sys_replication_slots;
SELECT * FROM sys_stat_archiver;

-- 配置健康
SELECT * FROM sys_file_settings WHERE error IS NOT NULL;   -- 必须 0 行
SELECT * FROM sys_settings WHERE pending_restart;          -- 应 0 行
```

> ⚠️ **同步复制的判据不能只看 `synchronous_standby_names` 非空** —— **备库上该值同样非空**。必须按角色分别验证（主库看 `sys_stat_replication`，备库看 `sys_stat_wal_receiver`）。

## 10.4 ★ socket 相关 GUC 的验证陷阱

```bash
# [kingbase]  ⚠️ 必须用 TCP 连接（带 -h），本地 socket 下这四项恒显示 0
ksql -h $NODE1 -p $DB_PORT -U system -d test \
     -c "SHOW tcp_keepalives_idle; SHOW tcp_keepalives_interval;
         SHOW tcp_keepalives_count; SHOW tcp_user_timeout;"
# 预期 2 / 2 / 3 / 9000
```

> **★ 现场教训（21）**：这四个 GUC 带 **show hook**，`SHOW` 返回的是**当前会话所在 socket 的实际取值**；对 **Unix domain socket** 一律返回 **0**。不带 `-h` 采集会被误判为"服务端未设置"。

## 10.5 OS 与工具链

```bash
# [root][两节点]
su - kingbase -c 'ulimit -Sn'
grep -E 'Max open files|Max locked memory' /proc/$(pgrep -o kingbase)/limits
cat /sys/kernel/mm/transparent_hugepage/enabled          # 应 [never]
getcap /bin/ping
sudo -u kingbase /bin/ping -c 3 -w 2 $GW
stat -c '%A %a %U:%G %n' /bin/ping /sbin/ip /opt/kes/bin/arping
findmnt -no SOURCE,FSTYPE,OPTIONS -T $KB_DATA
findmnt -no SOURCE,FSTYPE,OPTIONS -T $KB_DATA/sys_wal
findmnt -no SOURCE,FSTYPE,OPTIONS -T /data
```

## 10.6 trusted_servers 量化复测

> **★ 现场教训（22）：不要用 `ping` 的退出码判定可达性。**
>
> 本现场曾据退出码判出「trusted_servers 全部不可达」，而手工 `ping` 明明是：
>
> ```
> 2 packets transmitted, 2 received, 0% packet loss, time 1038ms
> rtt min/avg/max/mdev = 0.686/0.708/0.731/0.022 ms
> ```
>
> **根因是 `-c 3 -w 2` 这个组合本身**：`ping` 默认包间隔 **1 秒**，`-w 2` 的 deadline 在 t=2 到达，因此只能发出 t=0、t=1 两个包，**count 永远凑不满 3**。而 iputils 的规则是「同时指定 count 与 deadline 时，deadline 前收到的包少于 count **也返回 1**」——**退出码恒为 1，与网络好坏无关**。
>
> ⚠️ 曾有一版把它归因为「RTT 长尾触碰 deadline」，**该解释同样错误**：node1 的 RTT 仅 0.7ms，照样"失败"。

```bash
# [root][两节点]  —— ★ 判据是【收到回包数 > 0】，不是退出码，也不是平均延迟
fail=0
for i in $(seq 1 200); do
    sudo -u kingbase /bin/ping -c 3 -w 2 $GW 2>/dev/null \
        | grep -qE '[1-9][0-9]* *(packets )?received' || fail=$((fail+1))
    sleep 1
done
echo "探测失败次数 = $fail / 200"
```

> **只要 `fail > 0`，该地址就不适合作为唯一的网络健康判定参照** —— 它失效的时刻恰好是真正需要 failover 的时刻。

> **★ 现场教训（23）：`trusted_servers` 检测平时根本不跑。**
>
> `hamgr.log` 实测显示 repmgrd 正常状态下**只有每 5 分钟一次的 `monitoring ... in normal state`**，没有任何 ping / trusted 相关记录 —— **该探测只在节点察觉连接异常时才触发**。
>
> 含义有两面：① **紧迫性不高**（不是"现在正在失败"）；② **但风险性质不变** —— 正因平时不探测、日志也无痕迹，**它是否可用无法通过常规观察验证**，只能主动复现。
>
> ⚠️ repmgr 内部实际使用的命令与判据**仍未查证**（日志无痕迹，正常状态下 `strace` 也抓不到）。**建议并入 C 类演练**：临时把 `trusted_servers` 指向不可达地址，观察 repmgrd 的实际反应与日志输出。

---

# 第 11 章 启停与维护 SOP

## 11.1 顺序

```
停止：cron（注释 kbha 行）→ kbha / repmgrd → 数据库
启动：所有节点数据库 → 所有节点 repmgrd → 所有节点 kbha → 最后恢复 cron
```

> ⚠️ **启动按「组件层」推进，不是「按节点」逐台启完。** 若按 `node1: DB→repmgrd→kbha` 再 `node2: ...`，node1 的 repmgrd 会在 node2 数据库尚未起来时运行，可能触发非预期判定。

## 11.2 ★ 人工维护停库前必须先 pause

```bash
# [kingbase]
repmgr service pause
repmgr service status            # ★ 确认所有节点 Paused = yes
```

**维护结束后：**

```bash
# [kingbase]
repmgr service unpause
repmgr service status            # ★ 必须确认 Paused = no
```

> ⚠️ **忘记 `unpause` 的后果是静默的**：集群状态看着完全正常，但**自动 failover 一直处于禁用状态**，直到真正需要切换时才发现。**纳入巡检。**

## 11.3 手工启停命令

```bash
# [kingbase]  —— 停止（三阶段）
pkill -f 'kbha -A daemon'
pkill -f 'repmgrd -d -v -f'
sys_ctl -D $KB_DATA -m fast stop           # 先备后主
pgrep -af 'kbha|repmgrd|kingbase'          # 应无输出
```

```bash
# [kingbase]  —— ★ 启动前硬门 ⓪：DATA 路径完好性（两节点分别执行）
#   $KB_DATA 在本现场是软链；若其目标被挂载遮住或未重建，会成为【悬空软链】，
#   下面的 standby.signal 判据恒为假 → 两节点都被判成 PRIMARY candidate，
#   看起来像脑裂，实际是路径问题。先把真实原因暴露出来。
D=$(readlink -f $KB_DATA 2>/dev/null)
[ -n "$D" ] && [ -d "$D" ] || { echo "STOP: $KB_DATA 解析失败或目标不存在（悬空软链？）"; exit 1; }
[ -f "$D/sys_control" ] || [ -d "$D/global" ] || { echo "STOP: $D 不像是 PGDATA"; exit 1; }
echo "✓ DATA=$D  设备=$(findmnt -no SOURCE -T "$D")"

# [kingbase]  —— ★ 启动前硬门 ①：单主状态检查（两节点分别执行）
test -f $KB_DATA/standby.signal \
  && echo "$(hostname -s): STANDBY candidate" \
  || echo "$(hostname -s): PRIMARY candidate"
```

| 检查结果 | 处置 |
| --- | --- |
| 恰好 **1 个** PRIMARY candidate | ✅ 可继续 |
| **2 个** PRIMARY candidate | ⛔ **立即停止，不得 `sys_ctl start`** —— 防脑裂前置门 |
| 全部 STANDBY candidate | ⛔ 停止，查明原因 |

```bash
# [kingbase]  —— 启动（阶段 A：所有节点数据库）
sys_ctl -D $KB_DATA start                  # node1 → node2
sys_ctl -D $KB_DATA status

# 阶段 B：所有节点 repmgrd
$KB_HOME/bin/repmgrd -d -v -f $KB_ETC/repmgr.conf

# 阶段 C：所有节点 kbha
$KB_HOME/bin/kbha -A daemon -f $KB_ETC/repmgr.conf

# 阶段 D：恢复 cron
```

## 11.4 `sys_monitor.sh` 一键启停

```bash
# [kingbase][仅主节点]
sys_monitor.sh stop
sys_monitor.sh start
sys_monitor.sh restart
```

**实测行为（2026-09-07）：**

```
停：repmgrd(两节点) → DB(先备后主)
起：主 DB → ping trusted_servers → 备 DB → 加载 VIP → repmgrd(两节点) → kbha(两节点)
```

> ⚠️ **实测发现它会重写 `logrotate_ha.conf`**（文件头时间戳即执行时刻）—— **具有改写配置文件的行为**。
> **是否也改写 cron 尚未验证**，故在本现场**暂列为待验证路径**。转为批准路径前须补测：
>
> ```bash
> crontab -l -u kingbase > /tmp/cron.before ; ls -l /etc/cron.d/ > /tmp/crond.before
> sys_monitor.sh restart
> crontab -l -u kingbase > /tmp/cron.after  ; ls -l /etc/cron.d/ > /tmp/crond.after
> diff /tmp/cron.before /tmp/cron.after ; diff /tmp/crond.before /tmp/crond.after
> ```

---

# 第 12 章 常见坑与排查

## 12.1 两节点无 witness 的脑裂风险

**这是该拓扑的固有限制，不是配置问题。**

官方对 1:1 网络分区的描述：备库无法连接主库、但仍能 ping 通网关，于是认为自身正常并升主，**结果产生多主**。

> ⚠️ **VIP、`connection_check_type=mix`、`trusted_servers` 都不是严格意义上的 fencing。**
>
> ```
> 业务方须书面三选一：
> ☐ 接受风险（记录补偿措施：监控告警 / 人工介入流程 / RTO 预期）
> ☐ 增加 witness 节点 或 外部 fencing
> ☐ 调整 HA 架构
> ```

## 12.2 排查速查表

| 现象 | 先查 |
| --- | --- |
| **改了参数不生效** | 第 6 章加载链；`sys_file_settings` 的 `applied` / `error` |
| **归档看似正常但没有文件** | `archive_command` 是否被 `exit 0` 覆盖；`sys_stat_archiver.last_failed_*` |
| **failover 没触发** | `repmgr service status` 的 `Paused`；repmgrd / kbha 进程是否存活；`getcap /bin/ping` |
| **备库无法 rejoin** | §7.3 的 `down_wal_size` 上限；sys_rman 归档能否补齐 WAL |
| **VM 重启后数据库自己起来了** | §5.4 的 kbha cron —— 这是设计行为，不是故障 |
| **备份突然不跑了** | §8.3 两个 cron 域的活动行计数；`sys_backup.sh start` 是否回写过 |
| **逻辑备份 dmp 一直没产出** | §8.4；`tail logical_backup.log`；`backup8.conf` 路径是否适配 |
| **VIP 漂移后业务不通** | `arping` 是否存在且可执行；升主流程是否因 VIP/arping 失败中止 |
| **`SHOW tcp_keepalives_*` 是 0** | §10.4 —— 用 TCP 连接复测 |
| **长事务作业被强杀** | §7.4 的 `statement_timeout = 60min` |
| **脚本报 `$'\r': 未找到命令`** | 文件被 Windows 中转带上 CRLF：`sed -i 's/\r$//' <文件>` |

---

# 附录 A 官方《集群安装指南》需修正项

> **以下问题**出自厂商官方《KingbaseES V8R6 集群安装指南》**，不是现场随手写的。下一个现场若照抄同一份指南，会重复全部问题。**

| # | 指南原文 | 问题 | 正确做法 |
| --- | --- | --- | --- |
| 1 | `kingbase soft nole 300000` | **`nofile` 拼成 `nole`** —— 不报错、被静默忽略 | `kingbase soft nofile 300000` |
| 2 | `net.ipv4.tcp_mem = 94500000 91500000 92700000` | 不满足 `low < pressure < max`；64KB 页 ARM64 折合约 5.7TB | **删除该行**，回落内核默认 |
| 3 | `net.ipv4.tcp_max_tw_buckets = 6000` | 远低于内核按内存计算的默认值 | **删除该行** |
| 4 | `net.ipv4.tcp_max_orphans = 3276800` | 折合约 200GB | **删除该行** |
| 5 | **`net.ipv4.tcp_tw_recycle = 1`** | **Linux 4.12+ 已移除**；NAT 环境下导致连接被静默丢弃 | **删除该行**（本现场内核 4.19，该设置无效但留下误导） |
| 6 | `tcp_wmem = 8192 436600 873200`<br>`tcp_rmem = 32768 436600 873200` | max 仅约 850KB，与同指南中 `net.core.*mem_max = 16MB` 不匹配 | `tcp_rmem = 8192 87380 16777216`<br>`tcp_wmem = 8192 65536 16777216` |
| 7 | 指南未提及 `fs.file-max` / `fs.aio-max-nr` / `vm.min_free_kbytes` / `vm.vfs_cache_pressure` / `net.core.somaxconn` | 这五项在实际部署中会被设置（与厂商 HA 巡检基线一致），但指南未列 | 见 §3.3 |
| 8 | 指南未提及 THP | 生产必须关闭 | 见 §3.4 |
| 9 | 指南未提及 `getcap /bin/ping` 验证 | trusted_servers 检测的隐性前提 | 见 §3.8 |

---

# 附录 B 配套脚本索引（★ 不再内嵌源码）

> ⚠️⚠️ **本附录自 v1.1.2 起【不再提供脚本源码】，只给出批准清单。**
>
> **原因（v1.1.1 的实际事故）**：v1.1.0/v1.1.1 的附录 B 内嵌了脚本全文，而脚本自
> v1.0 起已迭代五轮至 v1.1.5，附录**一次都没同步**。结果是：文档首页写着「可照抄
> 执行版 · 配套 v1.1.5」，附录 B 里却是 **v1.0** —— 其中含
> `[ "$1" = FAIL ] && FAIL=1`（**ERROR 不阻断退出码**）、`pgrep -f`（**会被无关
> 进程骗过**）、`ping` 退出码判可达（**会把 9 月 9 日现场刚证明是假的
> `trusted_servers` FAIL 再造一遍**）。
>
> **只要有人相信"可照抄"并从附录复制，就会绕过发布包里真正的脚本。**
>
> **结构性修法**：源码只存在于发布包，文档只维护「批准版本 + SHA256」的索引。
> 脚本日后每改一次，只需更新本表的版本与哈希，**不存在源码副本再次漂移的可能**。

## B.1 批准交付清单

**发布包（ZIP 根目录）= 14 个对象**：`kb_scripts_v1.1.7.tar.gz` + 解包后的 **8 个文件** + **`kbdc.sh`** + **`kb_mseq.sh`** + **《环境说明与参数基线》** + **《集群部署文档》** + **`RELEASE_SHA256SUMS`**

> ⚠️⚠️ **v1.1.13 新增 `RELEASE_SHA256SUMS`（P1-5）—— 把信任链的最后一环补上。**
>
> 基线 1.4.4 的 E-GATE 把**基线文档自身**当作 M-SEQ 批准哈希的信任根，并写着"文档的真伪由本文档 B.1/B.2 负责"。
> 但在 v1.1.12 之前，**B.1 的 11 个批准对象里根本没有这两份文档** —— 那句话是悬空的：
>
> ```
> 基线文档 ──(内嵌 hash)──> kb_mseq.sh        ← 这一段有机器校验
>    ↑
>    └── "这份基线文档本身是批准版吗？"        ← 此前无任何机器层证明
> ```
>
> **`RELEASE_SHA256SUMS` 列出【除它自身以外的 13 个对象】**（★ v1.1.15 更正，见下方数学关系）：
>
> ```
> <sha256>  KingbaseES_V8R6_环境说明与参数基线_v1_3_27.md
> <sha256>  KingbaseES_V8R6_集群部署文档_v1_1_17.md
> <sha256>  kb_mseq.sh
> <sha256>  kbdc.sh
> <sha256>  kb_scripts_v1.1.7.tar.gz
> <sha256>  kb_lib.sh
> <sha256>  kb_backup_check.sh
> <sha256>  kb_ha_watch.sh
> <sha256>  kb_offcluster_copy.sh
> <sha256>  kb_log_cleanup.sh
> <sha256>  backup8.conf
> <sha256>  README.md
> <sha256>  SHA256SUMS
> ```
>
> ⚠️⚠️ **v1.1.15 一次性改清楚三处（P1-2）**：
> ① v1.1.13/v1.1.14 的示例只列 **5 行**却称"覆盖全部交付物" —— **示意 ≠ 完整清单**，现已列全 13 项；
> ② 示例里的文件名还停在 `v1_3_23` / `v1_1_13`，与当前版本不符 —— 现已改为当前文件名，
> 　 **且这两行必须随每次改版同步更新**（已写进 B.5 第 6 条）；
> ③ B.1 首段此前的"根目录 = tar + 8 文件 + kbdc + kb_mseq + RELEASE"**不含两份 Markdown**，
> 　 与表格里的 14 互相矛盾 —— 现已统一。
>
> **★ 数学关系（此前写错，必须说清楚）**：
>
> ```
> ZIP 根目录对象总数                      = 14
> 步骤①：独立渠道给出的 SHA256 → 验 manifest 自身   =  1   ← manifest 不可能验证自身
> 步骤②：manifest → sha256sum -c 验其余对象         = 13
> ```
>
> ⚠️ **诚实标注它的边界**：`RELEASE_SHA256SUMS` 自己的哈希不可能写在它自己里面。
> 它是**交付侧的信任根**，必须通过**独立渠道**送达并核对 —— 交付邮件 / 工单正文里附上它的 SHA256，
> 收件方先核对这一个值，再用它校验其余全部对象。**链条总要有一个起点，把起点标出来比假装闭环更重要。**

> **★ v1.1.4 统一计数口径**（v1.1.3 的三个「7」指的不是同一个集合，极易误判）：
>
> | 集合 | 内容 | 数量 |
> | --- | --- | --- |
> | **tar 内文件** | 5 个 shell + `backup8.conf` + `README.md` + `SHA256SUMS` | **8** |
> | `SHA256SUMS` 覆盖的文件 | 5 个 shell + `backup8.conf` + `README.md`（**不含它自身**） | 7 |
> | 需部署到 `$BKS` 的文件 | 上面 8 个全部（`README.md` 一并留存，便于现场查自测项与边界） | 8 |
> | 发布 ZIP 根目录 | 上面 8 个 + `kb_scripts_v1.1.7.tar.gz` + **`kbdc.sh`** + **`kb_mseq.sh`** + **两份 Markdown 文档** + **`RELEASE_SHA256SUMS`** | **14** |
>
> ⚠️⚠️ **v1.1.14 更正计数（P1-4）**：v1.1.13 一边说 `RELEASE_SHA256SUMS` **覆盖两份 Markdown 文档本身**，
> 一边把根目录计数定义成 **12（不含文档）** —— **照 B.2 执行 `sha256sum -c` 会直接报找不到这两个文件**。
> 这是确定性的流程不一致：**引入信任根这个概念时，没有同步它在交付清单里的位置。**
> 现正式定义为 **14 个对象**：tar 解包后的 8 个 + tar + `kbdc.sh` + `kb_mseq.sh` + **部署文档** + **参数基线** + `RELEASE_SHA256SUMS`。
>
> ⚠️⚠️ **v1.1.8：`kb_mseq.sh` 正式进入发布 ZIP（口径由 10 改为 11）。**
> v1.1.7 已经把它登记进 B.1 的批准表，**却没有把它算进发布包，B.2 也没有安装步骤** ——
> 等于"一边宣称受控交付，一边要求现场从 Markdown 代码块里手抄"。
> 而正文 §2.3 / §2A / §2.4 已经把 `/root/kb_mseq.sh` 设成**确定性前置依赖，缺失即 STOP**。
> 手抄的文件不可能保证与批准哈希逐字节相同，**受控交付的最后一步必须是交付实体文件**。
>
> **本文档此后一律按「tar 内 8 个文件」表述。**

> ⚠️⚠️ **`kbdc.sh` 必须与脚本集一同交付，且必须位于发布 ZIP 根目录。**
> v1.1.1 的发布包**遗漏了它**，而重新冻结的唯一前提正是「用 v1.2.5 复采」—— 按包执行的人拿不到采集脚本。
> 脚本集 **v1.1.6 的 README 曾写成「本包不含 `kbdc.sh`，单独交付」**，与本条直接冲突；**v1.1.7 已统一为本文档的口径**：`tar` 自身可以只是脚本增量包，但**发布 ZIP 必须含 `kbdc.sh`，缺失即不得交付、不得进演练**。

| 文件 | 批准版本 | SHA256 | 用途 | 执行身份 | 安装位置 | 权限 |
| --- | --- | --- | --- | --- | --- | --- |
| `kbdc.sh` | **v1.2.5** | `5c04873b750c5a74f64ddae73b8b946116ddadf30f68e746a445243f4ba80d5c` | 全现场取证 + 四态自动判定 | **root** | `/tmp` 或 `/root` | 750 |
| `kb_mseq.sh` | **v1.11** | **整文件（★ 外部信任锚）** `35a77ded102cd87a7cfb68c946a93f3db1cc75a7fcf9a16c8b234ff81188b969`<br>本体（M10 内置） `052b7cfb8610f310ebb6fc38ea687fdb62e0641e7ce653dc8d64758c46d3cb2b` | **M-SEQ 挂载接入通用校验序列**（采集器（只采集不解释）/ 设备等同判定 / major:minor / mountpoint 三态 / 设备身份 / 容量 / fstab / 挂载 UUID 绑定 / 条目枚举 / 比较类断言护栏 / **xattr·ACL sentinel 快照** / rsync 校验 / 幂等卸载 / **持有者正向枚举** / 文件系统干净的正面证据 / 安全只读检查 / 破坏性操作即时复验授权 / 自身完整性）。**源在基线 1.4.4「六」** | **root** | **`/root`** | **600** |
| `kb_lib.sh` | **v1.1.7** | `e345e93d38c6db6261a03358731a819119e77444fa89e5ac60cb69fb8a9d3fea` | **公用库**：四态判定 / Paused 表头解析 / `kb_ping_ok` / `kb_role` / `kb_need_int` | — **不可直接执行** | `$BKS` | **640** |
| `kb_backup_check.sh` | **v1.1.7** | `11faf99efd93082a43ce07ba4aee3506daacb5b53af8050607f7ec15af393fcd` | 备份健康巡检（**按库核对 + `gzip -t`**；v1.1.7 补 `-w`） | kingbase | `$BKS` | 750 |
| `kb_ha_watch.sh` | **v1.1.7** | `25514b1422a7d60b5913757a833a68193f27f2eb905b7eb07974174a75be03c0` | HA 静默降级巡检 | kingbase | `$BKS` | 750 |
| `kb_offcluster_copy.sh` | **v1.1.7** | `4b545f12dfe273f15df1a6da827858c083c1eed28ae84164f8712b841eb05264` | off-cluster 副本（受控停写） | kingbase | `$BKS` | 750 |
| `kb_log_cleanup.sh` | **v1.1.7** | `b1516ee7ec24bf046478d954f5e40df5b1fdf66e82cffc91aff852b136cdd1d3` | 数据库日志保留 | kingbase | `$BKS` | 750 |
| `backup8.conf` | **v1.1.7**（建议稿） | `6b707afc9d4587526aafda2709a69f6ebb996bcc4a1f9187780a9d85ae31dbd4` | 逻辑备份配置参考 | kingbase | `$BKS` | **600** |
| `README.md` | **v1.1.7** | `0c4ad3d8c5b3351326e35a1ff59c43e0f64d8701b509d166f9f7741ec5c691b9` | 脚本集说明、自测、边界 | — | `$BKS` | 644 |
| `SHA256SUMS` | **v1.1.7** | `5f95469109dbc70195270bbc95e6b381f6a5ef1bed7d443b27af318726e8133a` | 哈希清单（覆盖上表 7 个文件，**不含它自身**） | — | `$BKS` | 644 |
| `kb_scripts_v1.1.7.tar.gz` | **v1.1.7** | `f564b91e06f40c65aec5e40e171a8ac1b58cd775d0bbc6a83f4b46543038d52e` | 打包体（**内含 8 个文件**，与解包后逐字节一致） | — | — | — |

> `$BKS` = `/home/kingbase/backup_script`

> ⚠️ **`kb_mseq.sh` 的位置与身份和其余文件都不同（v1.1.7 新增）**：它装在 **`/root`**、权限 **600**、**不进 `$BKS`、不进 cron**
> —— 它是 root 存储维护 SOP 的一部分，不是巡检脚本集成员。但它承担 `fstab` 判定、UUID 绑定、`rsync --delete`、`mount` / `umount` 这些安全门，
> 所以**同样纳入批准清单**，并自 v1.1.8 起**随发布 ZIP 交付实体文件**（见 B.2 的安装步骤）。
>
> **两个哈希的分工**：**整文件 SHA256 是【外部信任锚】**，由 B.2 用 `sha256sum -c` **机器校验**；
> **本体 SHA256**（= 排除 `KB_MSEQ_APPROVED_SHA256=` 那一行后的哈希）内置在脚本里，由 **M10 `kb_mseq_selfcheck`** 做内部自洽判定。
> 分两个是因为批准值写在脚本自己里面，对整文件算哈希会**自引用**；把承载哈希的那一行排除掉，本体哈希就能自洽计算。
>
> ⚠️⚠️ **必须清楚 M10 能证明什么（v1.1.9 更正表述）**：它只是**内部一致性检查** ——
> **改内容的同时把内置常量一起改掉，自检照样 `rc=0` 并打印"与批准版一致"**。
> 所以「这是不是批准发布版」**只能由 B.2 的整文件 `sha256sum -c` 回答**，M10 回答不了。
> v1.1.8 及以前把两者混为一谈，是把内部自洽当成了外部信任。
> **它的唯一源是基线 1.4.4「六」的代码块** —— 本文档只登记版本与哈希，不复制内容（同附录 B 的既有纪律）。

> ✅ **`kb_offcluster_copy.sh` 自 v1.1.3 起已批准用于正式容灾复制。** v1.1.2 标注的「不批准」原因（`lsof rc=1` 的 fail-open）已由脚本集 **v1.1.6** 修复并经定向故障注入复测；**v1.1.7** 进一步修掉了字节比对的系统性假 FAIL（原 `du -sb` 会把目录元数据与目标端 marker 计入，刷新模式几乎必然报「字节数不一致」）。**运行前须按 §8.5 设置 `EXPECT_REPO_MOUNT`。**

## B.2 落地与校验（★ node1 / node2 分别执行）

### ★ 第 0 步：交付侧信任根校验（**必须是解包 ZIP 后的第一个动作**）

> ⚠️⚠️ **v1.1.14 把这一步移到了最前（P1-5）。** v1.1.13 虽然写着"解包后第一步"，
> 但按实际阅读顺序，它排在"**用本文档 B.1 的值验 tar → 解包 → 验 tar 内文件**"**之后** ——
> 也就是说，用来证明"**这份部署文档本身是不是批准版**"的信任根，
> 反而在**已经信任了这份文档、并且解完包之后**才执行。**信任链顺序不闭合。**
>
> **现在的顺序是：RELEASE 全通过 → 才允许使用本文档 B.1 内的任何批准哈希。**

```bash
# [任意用户][解包 ZIP 后的第一个动作]
# ① 先人工核对清单自身的 SHA256（它不可能自证，必须来自独立渠道）
sha256sum RELEASE_SHA256SUMS
#   ← 与【交付邮件 / 工单正文】里给出的值逐字比对；不一致则整包作废，后续一步都不要做

# ② 用清单校验【其余 13 个对象】（含两份 Markdown 文档本身）
#    ⚠️ manifest 不可能验证自身 —— 它自己由上面第 ① 步的独立渠道值负责。14 = 1 + 13。
sha256sum -c RELEASE_SHA256SUMS \
    || { echo "STOP: 发布包内有对象与 RELEASE_SHA256SUMS 不符 —— 整包不得使用"; exit 1; }
echo "✓ 交付侧信任根校验通过，可以开始使用本文档 B.1 的批准哈希"
```

> ⚠️ **诚实标注边界**：`RELEASE_SHA256SUMS` 自己的哈希不可能写在它自己里面。
> **链条总要有一个起点** —— 这里的起点是"交付通知里的那一个值 + 人工核对一次"。
> 把起点标出来，比假装闭环更重要。


> ⚠️⚠️⚠️ **v1.1.11 修了两处交付信任链的漏洞（P0-4 / P1-2）。**
>
> **① 上一版的 `cat > /tmp/kb_approved.sha256 <<EOF` 没有检查写入是否成功。**
> 以非 root 身份执行时，若 `/tmp` 下已存在同名文件且不可覆盖（`/tmp` 带 sticky 位，
> 别人的文件你删不掉也写不了），`cat` 失败 **而脚本不停**，接着 `sha256sum -c` 读的是
> **预置的那份旧清单** —— 篡改过的文件照样得到 `OK`。
> 实测（`setpriv --reuid=65534`）：`cat rc=2`、`CHECK_RC=0`、篡改文件被放行。
> **这是 v1.1.10 为了修"人眼比对"而引入的新缺陷** —— 修法本身写成了可被绕过的形式。
> **本版不再经过任何临时文件**：`sha256sum -c -` 直接吃 heredoc。
>
> **② 上一版是"先解包、再校验"，而且 tar 自身根本不在机器硬门内。**
> 因此 v1.1.10 宣称的"11 个交付对象全部有机器硬门"**不准确 —— 实际只有 10 个**（解出的 8 + `kbdc.sh` + `kb_mseq.sh`）。
> **本版改为先验包、再解包**，tar 补进硬门，口径这才与事实相符。

```bash
# [kingbase][两节点]  —— scp 直传，勿经 Windows 中转（CRLF 会使脚本无法执行）
cd /home/kingbase/backup_script

# ★★ 第 0 步：先验整包，再解包（tar 自身也是 B.1 的批准对象）
sha256sum -c - <<'EOF' || { echo "STOP: kb_scripts_v1.1.7.tar.gz 与 B.1 批准值不符"; exit 1; }
f564b91e06f40c65aec5e40e171a8ac1b58cd775d0bbc6a83f4b46543038d52e  kb_scripts_v1.1.7.tar.gz
EOF

tar -zxvf kb_scripts_v1.1.7.tar.gz --strip-components=1

# ★ 第一步：包内清单自校验（v1.1.7 起随包提供 SHA256SUMS）
sha256sum -c SHA256SUMS               # ★ 必须全部 OK，任一 FAILED 即停止

# ★★ 第二步：与【本文档 B.1 的外部批准值】机器比对
#    包内 SHA256SUMS 只证明"包没被改坏"（内部自洽）；
#    与 B.1 比对才证明"拿到的是被批准的那一版"（外部信任锚）。**两者不能互相替代。**
#    ⚠️ 直接用 heredoc 喂给 sha256sum -c -，**不要落地成临时文件**（理由见本节开头 ①）
sha256sum -c - <<'EOF' || { echo "STOP: 有文件与 B.1 的批准值不符 —— 不是被批准的那一版"; exit 1; }
e345e93d38c6db6261a03358731a819119e77444fa89e5ac60cb69fb8a9d3fea  kb_lib.sh
11faf99efd93082a43ce07ba4aee3506daacb5b53af8050607f7ec15af393fcd  kb_backup_check.sh
25514b1422a7d60b5913757a833a68193f27f2eb905b7eb07974174a75be03c0  kb_ha_watch.sh
4b545f12dfe273f15df1a6da827858c083c1eed28ae84164f8712b841eb05264  kb_offcluster_copy.sh
b1516ee7ec24bf046478d954f5e40df5b1fdf66e82cffc91aff852b136cdd1d3  kb_log_cleanup.sh
6b707afc9d4587526aafda2709a69f6ebb996bcc4a1f9187780a9d85ae31dbd4  backup8.conf
0c4ad3d8c5b3351326e35a1ff59c43e0f64d8701b509d166f9f7741ec5c691b9  README.md
5f95469109dbc70195270bbc95e6b381f6a5ef1bed7d443b27af318726e8133a  SHA256SUMS
EOF

file kb_*.sh                          # 应无 "CRLF line terminators"
ls -1 kb_lib.sh kb_backup_check.sh kb_ha_watch.sh kb_offcluster_copy.sh \
      kb_log_cleanup.sh backup8.conf README.md SHA256SUMS | wc -l   # ★ 必须为 8（tar 内文件数）

chmod 750 kb_backup_check.sh kb_ha_watch.sh kb_offcluster_copy.sh kb_log_cleanup.sh || { echo "STOP: 设置脚本权限失败"; exit 1; }
chmod 640 kb_lib.sh || { echo "STOP: 设置 kb_lib.sh 权限失败"; exit 1; }   # ★ 不要给执行位；它是库
chmod 600 backup8.conf || { echo "STOP: 设置 backup8.conf 权限失败"; exit 1; }
```

```bash
# [root][两节点]  —— ★ 确认 kbdc.sh 确实随包到场（v1.1.1 曾遗漏），并做外部批准值机器校验
ls -l kbdc.sh || { echo "STOP: 发布包缺 kbdc.sh"; exit 1; }
sha256sum -c - <<'EOF' || { echo "STOP: kbdc.sh 与 B.1 批准值不符"; exit 1; }
5c04873b750c5a74f64ddae73b8b946116ddadf30f68e746a445243f4ba80d5c  kbdc.sh
EOF
```

> ⚠️⚠️ **统一治理**：`sha256sum` **打印 + 人眼比对**已从本文档中清除。
> 原则是「**内部自洽 ≠ 外部批准**」。
> **当前口径（v1.1.15）**：ZIP 根目录 **14 个对象**；`RELEASE_SHA256SUMS` 由独立渠道值验证其自身，
> 再由它 `sha256sum -c` 校验**其余 13 个**；B.1 的批准值另在各自步骤做二次机器校验。
> ⚠️ v1.1.11 曾写"11 个交付对象全部有机器硬门"——那是**加入两份 Markdown 与 manifest 之前**的旧口径。
> ⚠️ v1.1.10 曾写过同一句话，但当时 **tar 自身并不在硬门内，实际只有 10 个** —— 本版才名副其实。

```bash
# [root][两节点]  —— 安装 kb_mseq.sh（存储维护 SOP 的执行依赖）
#   ⚠️ 它【不进 $BKS、不进 cron】，装在 /root、权限 600
ls -l kb_mseq.sh || { echo "STOP: 发布包缺 kb_mseq.sh —— 不得开始任何存储操作"; exit 1; }

# ★★ v1.1.9：外部信任锚改为【机器校验】，不再靠人眼比对那一长串哈希
KB_MSEQ_SHA=35a77ded102cd87a7cfb68c946a93f3db1cc75a7fcf9a16c8b234ff81188b969
printf '%s  %s\n' "$KB_MSEQ_SHA" kb_mseq.sh | sha256sum -c - \
    || { echo "STOP: kb_mseq.sh 不是批准发布版（整文件哈希不符）"; exit 1; }

install -o root -g root -m 600 kb_mseq.sh /root/kb_mseq.sh || { echo "STOP: 安装 kb_mseq.sh 失败"; exit 1; }

# 安装后再校验一次落地文件（防拷贝过程出错）
printf '%s  %s\n' "$KB_MSEQ_SHA" /root/kb_mseq.sh | sha256sum -c - \
    || { echo "STOP: /root/kb_mseq.sh 整文件哈希不符"; exit 1; }

# 内部自洽检查（★ 它【不能】证明这是批准版，只能发现随手改动）
. /root/kb_mseq.sh && kb_mseq_selfcheck || { echo "STOP: kb_mseq.sh 内部自检不通过"; exit 1; }

# ★★ v1.1.12 新增：裸解析机械扫描（M12）—— 未登记命中数必须为 0
#    它把"解析器也是取证链的一环"这条原则变成可跑出来的规则。
#    ⚠️ 输出里会打印【已登记豁免】及其理由，**交付验收时必须逐条复核**：
#       豁免是最容易被后人扩大的东西，所以它始终可见，而不是藏在白名单里。
kb_mseq_scan_known_patterns || { echo "STOP: 已知危险模式扫描未通过"; exit 1; }
```

> ⚠️ **上面两步不能互相替代**：`sha256sum -c` 回答"**这是不是批准发布版**"（外部信任锚）；
> `kb_mseq_selfcheck` 只回答"**文件内部是否自洽**" —— 改内容时把内置常量一起改掉，它照样通过。
> **两步都要跑，且 `sha256sum -c` 是硬门。**
>
> ⚠️ **为什么这里仍然出现哈希字面量，而 §2.3 却改成引用 E-GATE**：这是**引导顺序**决定的 ——
> 交付安装时 `/root/kb_mseq.sh` 还不存在，E-GATE 跑不起来，**安装步骤必须自带批准值**。
> 而**维护入口**（§2.3 / 基线 2.S / 2.4 / 2.6 / 2.R）一律引用基线 1.4.4 的 E-GATE，不再各自复制。
> **因此本哈希在全套文档里只有两个权威落点：B.1 的批准表 + B.2 的安装步骤（本处），以及基线 E-GATE 的一处定义。**
> 升版时这三处必须同时改 —— 已写入 B.5 的维护动作清单。

> ⚠️ **不要从基线文档的代码块手抄 `kb_mseq.sh`。** 手抄无法保证与批准哈希逐字节相同，
> 而 §2.3 / §2A / §2.4 的硬门都依赖它 —— 自检不通过时这些步骤会直接 STOP。
> 基线 1.4.4「六」的代码块是**源**，发布包里的文件才是**交付物**。

> **`kb_ha_watch.sh` 与 `kb_backup_check.sh` 两节点都要部署、都要接 cron** ——
> HA 状态与本地 repo 都是每节点独立的，只装一台等于只看半个集群。

## B.3 接入 cron 前的故障注入自测

**自测项与判据以发布包内 `README.md` 为准** —— **脚本集 v1.1.7 为 10 项**故障注入 + **3 类静态回归断言**，均为 rc 与失败原因双校验。

> ⚠️ **本文档不再写死项数。** v1.1.2 写死「8 项」，而 v1.1.6 已增至 10 项（新增两项数值参数入口校验），导致正式验收会漏执行两个回归。**以 README 为准，本节只记录判据要求。**

> ⚠️ **不要只判"非零退出码"** —— 文件缺失返回 `127`，同样非零，会**冒充通过**。
> 自测必须**精确判 `rc = 1` 且命中预期失败原因**，否则「测到了别的分支」也会显示 OK。

> ⚠️ **先跑依赖预检再跑自测**：缺 `rsync` / `lsof` 会改变失败原因（offcluster 那一项会停在「缺少必需命令」而非「repo 目录不存在」），表现为「rc 正确但未命中预期原因」，容易被误判成脚本缺陷。

**★ 静态回归断言（v1.1.7 新增，必须与故障注入一起跑）**：故障注入测不出「README 宣称已修、代码其实没改」这类问题 —— 脚本集 v1.1.6 就发生过（README 写「凭据三处全部修完」，而 `kb_backup_check.sh` 的 `-w` 漏改）。断言命令见 README。

**故障注入全部 `OK` + 静态断言全部 `OK`，才可接入 cron 与告警。**

## B.4 cron 建议配置

```cron
# ===== kingbase 用户 crontab（★ 每类任务恰好 1 条）=====

# HA 启动控制链（按回归策略决定是否保留，见 §5.4）
*/1 * * * *  . /etc/profile;/home/kingbase/cluster/kingbase/bin/kbha -A daemon -f /home/kingbase/cluster/kingbase/etc/repmgr.conf

# HA 日志轮转
0 0 * * *    . /etc/profile;/usr/sbin/logrotate -s /home/kingbase/cluster/kingbase/etc/logrotate_status /home/kingbase/cluster/kingbase/etc/logrotate_ha.conf

# 逻辑备份（★ 与物理全备错开，不要同为 02:00）
0 3 * * *    . /etc/profile; sh /home/kingbase/backup_script/backup8.sh >> /home/kingbase/backup_script/logical_backup.log 2>&1

# 物理全备（⚠️ sys_backup.sh start 会回写本行，见 §8.3）
0 2 * * 0    . /etc/profile;/home/kingbase/cluster/kingbase/bin/sys_rman --config=/data/kingbase/backup/rman/sys_rman.conf --stanza=kingbase --archive-copy --type=full backup >> /home/kingbase/cluster/kingbase/log/sys_rman_backup_full.log 2>&1

# 物理增备
0 4 * * *    . /etc/profile;/home/kingbase/cluster/kingbase/bin/sys_rman --config=/data/kingbase/backup/rman/sys_rman.conf --stanza=kingbase --archive-copy --type=incr backup >> /home/kingbase/cluster/kingbase/log/sys_rman_backup_incr.log 2>&1

# ★ 备份健康巡检（查产物是否真的生成，见 §8.4a）
0 8 * * *    . /etc/profile; bash /home/kingbase/backup_script/kb_backup_check.sh >> /home/kingbase/backup_script/backup_check.log 2>&1

# ★ HA 静默降级巡检
*/5 * * * *  . /etc/profile; bash /home/kingbase/backup_script/kb_ha_watch.sh >> /home/kingbase/backup_script/ha_watch.log 2>&1

# 数据库日志清理（轮转 ≠ 保留）
# ★ 路径必须 = $LOGDIR，随所选存储方案取值：
#     MNT-SITE → /data/kingbase/backup/log     MNT-MOVE → /data/kingbase/log
30 1 * * *   . /etc/profile; bash /home/kingbase/backup_script/kb_log_cleanup.sh /data/kingbase/backup/log >> /home/kingbase/backup_script/log_cleanup.log 2>&1
```

> ⚠️ **日志清理的路径必须与 `log_directory` 实际取值一致。** `kb_log_cleanup.sh` 内置固定白名单（v1.1.7 起同时覆盖两版方案的日志路径，**不接受环境变量覆盖**）：路径不在白名单内会被直接拒绝执行，表现为**日志保留策略静默停止**；路径在白名单内但写错了目录，则是**清理了一个空目录、真正的日志无人清理**。两种都不会报错到显眼的地方，**必须在落地时核对一次**。

> ⚠️ **`kb_offcluster_copy.sh` 不进 cron** —— 它必须在受控维护窗口内人工执行（需停库、`repmgr service pause`、人工确认）。

## B.5 脚本集版本升级时的更新动作

> **本附录唯一需要维护的就是 B.1 那张表。** 升级脚本集时：
>
> 1. 更新 B.1 的**批准版本**与 **SHA256**（含 `SHA256SUMS` 与 `tar` 自身的哈希）
> 2. 更新首页「配套脚本」栏的版本号
> 3. **不要**把新脚本源码贴回文档 —— 那正是 v1.1.1 事故的成因
> 4. **不要在本文档写死自测项数** —— 一律「以发布包 README 为准」。v1.1.2 写死「8 项」，一轮后脚本增至 10 项即过期（v1.1.3 已改正）
> 5. 核对 README 与本文档的**交付政策**是否一致（`kbdc.sh` 是否随包）—— v1.1.6 曾出现两份相反的政策
> 6. **`kb_mseq.sh` 升版时，三处哈希落点必须同时改**：B.1 批准表、B.2 安装步骤、**基线 1.4.4 的 E-GATE**。
>    维护入口不再各自复制哈希（复制的字面量一旦升版必漏改 —— 本套文档在版本号上已栽过两次）
> 7. **★ 破坏性授权接入检查（v1.1.16 新增，与基线 1.4.4 改版纪律第 0 条对称）**：
>    扫全文每个 `mkfs*` / `wipefs` / `lvremove`，**逐条列出它前面有没有 `kb_dev_released … destroy`**，
>    清单贴进变更记录。**普通 `check` 不得作为破坏性授权。**
>    ⚠️ 立这条的原因很具体：基线 v1.3.25 的变更记录写了"mkfs 前置链已改调 destroy"，
>    而当时**七个 mkfs 入口只有一个接上了**。
>    **凡是会在变更记录里写"都改了"的地方，都必须有一个能跑出来的清单。**
> 8. **每次改版必须做一次【全文破坏性命令回扫】**（与基线纪律第 1 条同规则、同脚本）：`mkfs` / `lvcreate` / `lvremove` / `lvextend` /
>    `pvcreate` / `vgextend` / `wipefs` / `dd` / `rm -rf` / `mv --` / `chown -R` / `install` ——
>    **每一条都必须有 `|| exit 1` 或等价守卫**。
>    ⚠️ v1.1.14 首次做这件事时，**11 条破坏性命令里 11 条都是裸写法**，其中最要命的
>    `lvcreate → mkfs` 是**从 v1.1.0 活到现在的原始写法** ——
>    十几轮把 M-SEQ 打磨到"连解析器都判 rc"，**而老代码块没人回头看过**。
> 9. **★ 镜像面检查（v1.1.15 新增，与基线 1.4.4 的改版纪律对称）**：
>    凡修改**同时存在于两份文档的同一段 SOP** —— 本文档 §2.3 ↔ 基线 0b.3、§2.4 ↔ 基线 2.2、
>    §2.3 的 E-GATE 前置 ↔ 基线 1.4.4 —— **必须同时改、同时记录，只改一侧即视为未关闭**。
>    ⚠️ v1.1.14 修了本文档的 `lvcreate → mkfs`，**而基线真源直到 v1.3.25 才修**，
>    中间形成"部署副本安全、基线真源危险"；**回扫纪律**也曾只在本文档跑过，
>    基线首次跑出 35 条中 32 条裸写法。**这类错误靠记性防不住。**
> 10. **★ manifest 示例中的两行文档文件名必须随每次改版同步更新**
>    （它们带版本号：`…_v1_3_25.md` / `…_v1_1_15.md`）。v1.1.13→v1.1.14 就漏改过一次。
> 11. **代码与签字表的口径必须一致**：若改了 M-SEQ 对某个工具的依赖强度（必需/佐证），
>    **checklist 与依赖清单必须同步改** —— v1.1.10~v1.1.11 的 `fuser`/`lsof` 就是两套相反模型并存的例子
>
> **升级顺序有讲究**：先冻结脚本集并算出最终哈希，再更新 B.1。反过来做，B.1 里填的一定是旧哈希。

# 附录 C 装机 checklist

```
【第 0~1 章：装机前决策与授权】
☐ License 为【正式项目授权】，非试用；有效期与续期责任人已记录
☐ License 中「数据守护集群」为启用
☐ 反亲和策略已配置并有平台侧书面确认
☐ 内存气球已关闭、vCPU 已预留、磁盘 flush/FUA 语义已由平台方确认
☐ ★【2A·装机前】三个数字已一起定死并签字：max_wal_size = ______ / wal_keep_segments = ______ / syswal 容量 = ______（满足 8 倍规则；100GB 是示例值，不可照抄）
☐ ★【2A·装机前】2A 出场检查全 ✅（**项数与内容以【当前配套基线】0b.4 为准** —— 此处不再写死基线版本号，避免每轮追版），且 syswal【未】挂到任何 PGDATA 路径
☐ ★ 只读检查证据（M8，仅对已有文件系统的 LV）：KB_RO_VERDICT = ______（须 EMPTY）、**KB_RO_ENTRIES = ______（主判据，须 0）**、KB_RO_FILES = ______、KB_RO_BYTES = ______
☐ ★ 证据文件 /root/kb_ro_evidence.env 已生成（M8 入口会先作废上一轮旧证据）
☐ ★ mkfs 前 M11【即时复验】通过：本次重新枚举条目数 = ______（须 0，且与证据记录一致）
     ⚠️ 历史证据本身不构成授权 —— UUID 不会因写入文件而变化
☐ ★ M8a 正面证据：xfs_repair -n rc = ______（须 0） 或 dumpe2fs Filesystem state = ________（须 clean）
☐ ★ kb_mseq.sh **v1.11 已随发布 ZIP 交付**并 install 到 /root（600）
☐ ★ kb_mseq_scan_known_patterns（M12）通过：**未登记命中 = 0**；已登记豁免 ______ 条，逐条复核理由成立 □
   ⚠️ M12 只覆盖【命令替换形式】，独立语句形式的裸解析扫不到 —— 它不是全库证明
☐ ★ RELEASE_SHA256SUMS 校验通过（**14 个对象，含两份 Markdown 文档本身**）；其自身 SHA256 已与交付通知独立核对 □
   ⚠️ 该校验必须是**解包 ZIP 后的第一个动作**，通过后才允许使用本文档 B.1 的批准哈希
☐ ★ §2.3 的 lvcreate → mkfs 全链 fail-close 已生效（LV 预先存在即 STOP、容量校验、逐条 || exit）
☐ ★ 每次进入存储维护前执行基线 1.4.4 的 **E-GATE**（外部哈希门 + 加载 + 自检 + M12），**未执行不得从任何一节开始**
☐ ★ kb_mseq.sh 整文件 sha256sum -c 机器校验通过（外部信任锚；★ selfcheck 不能替代它）
☐ ★ tar 自身（**解包前**）、tar 内 8 个文件、kbdc.sh、kb_mseq.sh 均已用 B.1 批准值做 sha256sum -c 机器校验
☐ ★ 交付对象计数：**14 = 独立渠道验 manifest 自身 1 + manifest 验其余 13**（★ 不要再写"11 个对象全覆盖"，那是 v1.1.11 的旧口径）
☐ ★ 校验清单一律用 heredoc 直接喂 sha256sum -c -，**不得落地成 /tmp 临时文件**
☐ ★ 每次进入存储维护前，对 /root/kb_mseq.sh 重做整文件校验（time-of-use，不只是安装时一次）
☐ ★ 两节点整文件 SHA256 相同：node1 = ____________，node2 = ____________，且 = 35a77ded…b969
   ⚠️ **本行的版本与哈希必须随每次 M-SEQ 升版同步**（B.5 第 6 条）—— v1.1.16 的 checklist 曾停在 `v1.8` / `8869ec8b…84fc`，
      与 B.1 和 E-GATE 的当前值三方打架；**而 v1.8 恰好是已知带 P0 的版本**。运行时会被 E-GATE 的哈希门拦住，
      但**签字表不该出现一个已知有缺陷的版本号**。
☐ ★【2B·装机后】域② 接入已按基线 2.S 在受控窗口完成，SOURCE(sys_wal) = ____________（≠ DATA）；或已走补偿分支并签字
☐ ★ 实际设备证据（只填规划值不构成证据，两节点分别记录）：
     node1：blockdev --getsize64 = ____________ B   UUID = ____________
     node2：blockdev --getsize64 = ____________ B   UUID = ____________
     ⚠️ 实际容量必须 ≥ /root/kb_plan.env 中的签字规划值（由 M2 机器断言）
☐ ★ 实际挂载设备 = 预期设备（M5）：findmnt -no SOURCE -T 的 blkid UUID = 上面记录的 UUID
     ⚠️ 只断言 SOURCE ≠ DATA 证明不了挂的是哪一块 —— 同挂载点若有错 UUID 的旧 fstab 行会挂错卷而一路全绿
☐ ★ /etc/fstab 中该挂载点的活动行【恰好 1 条】且 UUID 正确（M3）
☐ ★ 2.S 在第 7 章 WAL 参数落地【之前】完成（否则 wal_keep_segments 提上去会先撑爆根盘）
☐ ★ /etc/fstab 的 sys_wal 条目与当前存储方案一致，且【不含 nofail】
☐ ★ 容量域分域到位（**v1.1.17 改为条件式 —— 旧写法"三个容量域的 LV 已划分并已挂载"与文档自己认可的补偿分支互相矛盾：
   选补偿分支时域② 本就没有独立 LV，那一项永远勾不上**）：
     ☐ 域① DATA：SOURCE = ____________
     ☐ 域③ 独立 LV 已挂载，且 SOURCE 与 DATA 分离（SOURCE = ____________）
     ☐ 域② 见下一条的二选一（**不要求它一定有独立 LV**）
☐ ★ 存储方案已二选一并书面记录：☐ MNT-SITE  ☐ MNT-MOVE（决策人 ____ 日期 ____，见 §2.1 / 基线 1.4.4）
☐ ★ 域③ 独立性已用 SOURCE 判据验证：findmnt -no SOURCE -T 的 repo 与 log_directory 均 ≠ DATA（readlink -f 解链后）所在设备
   ⚠️ log_directory 取【SHOW 运行值】，且相对路径须【相对 DATA】解析（现场原值是相对路径 sys_log）
☐ ★ 域② sys_wal 已二选一并书面记录：☐ 按基线 2.S 完成独立 LV 接入（附 SOURCE 断言输出）  ☐ 走补偿分支（容量硬控制+三级告警+slot 告警+SOP+风险签字）
   ⚠️ 只 lvcreate + mkfs 不算「已独立」；域② 的 fstab 条目【不得加 nofail】
☐ ★ log_directory 已改为绝对路径、改在 es_rep.conf、生效行恰好 1 条，SHOW 运行值 = ____________（基线 2.7c + 2.10 第五项）
☐ initdb 期属性已定：db_mode / db_case_sensitive / encoding / locale / db_checksums
☐ max_connections 已按连接池峰值 ×1.2 定值（如需下调须原厂确认）
☐ synchronous 与备库定位已定，联动确定 synchronous_commit / hot_standby_feedback
☐ trusted_servers 已定（2~3 个，不同故障路径）
☐ 预计数据量已确认，据此规划 sys_wal 与 backup 容量
☐ statement_timeout 是否设置已与业务确认

【第 2~3 章：存储与 OS】
☐ 目标 LV 若已有文件系统，已完成 ro,norecovery/noload 只读检查并留证
☐ ★ 挂载前已确认 PGDATA 不在挂载点之下（readlink -f $KB_DATA 后比对，见 §2.3）
☐ 大页尺寸已实测（getconf PAGESIZE / Hugepagesize）
☐ THP 已设 never 并写入 GRUB
☐ limits.conf 无 nole 拼写错误，且已实测 ulimit -Sn 与 /proc/PID/limits
☐ sysctl 已按附录 A 修正官方指南的 6 处问题
☐ tcp_mem / tcp_max_tw_buckets / tcp_max_orphans / tcp_tw_recycle 已删除并【重启后】复验
☐ 时间同步已启用，两节点时间差在秒级内
☐ getcap /bin/ping 有 cap_net_raw，且 sudo -u kingbase ping 实测成功

【第 5~7 章：安装与参数】
☐ repmgr cluster show / service status 正常，Paused 全为 no
☐ 主库 synchronous_standby_names 非空，且 sys_stat_replication 有 streaming + sync/quorum 的备库
☐ 备库 sys_stat_wal_receiver.status = streaming
☐ sys_file_settings 无 error 行
☐ ★ 配置加载链已梳理，es_rep.conf 与 kingbase.conf 无冲突残留
☐ ★ kingbase.conf 中的 archive_command = exit 0 已清除
☐ ★ es_rep.conf 内部同名重复已收敛为每参数一次
☐ ★ WAL 8 倍规则校验通过（keep_bytes ≥ need_bytes）
☐ Oracle 兼容 GUC 基线已归档

【第 8~9 章：备份与安全】
☐ sys_backup.sh init（全集群一次）→ start（逐节点）已完成，首次全备验证通过
☐ ★ backup8.conf 路径已适配集群，且【手工跑通一次】确认有备份产物
☐ ★ 逐库核对通过：从 sys_database 查应备份清单，每库均有近期产物且 gzip -t 完整（§8.4a）
☐ ★ 核对时已排除 backup_log_*（否则会取到约 184B 的日志归档）
☐ ★ 未使用任何「最小字节阈值」作为判据（现场实测 esrep 914B / test 683B 均为合法备份）
☐ ★ 两个 cron 域的活动行计数：每类任务恰好一份
☐ 备份调度的「唯一真源」已确定并记录（A：接受 */7 / B：周调度 + start 后复验）
☐ off-cluster 副本方案已确定（官方机制 / 快照副本 / 受控停写）
☐ kb_backup_check.sh / kb_ha_watch.sh / kb_log_cleanup.sh 已部署并接入 cron
☐ 口令哈希全部 scram-sha-256
☐ ★ 明文/base64 口令已处置，相关文件权限已收敛为 600
   ⚠️ 改用 .kbpass 前须先在现场验证可行
   ⚠️ 环境变量是 KINGBASE_PASSFILE（非 KBPASSFILE）；连接须显式带 -h，否则 .kbpass 首列按 localhost 匹配
   ⚠️ -w(--no-password) 与 -W(--password) 相反：现场只否定了 -W，-w 是批处理所需、不应撤销
☐ ★ sys_hba.conf 已收敛（replication 仅两节点 IP，业务按来源网段）

【第 10~11 章：验证与 SOP】
☐ kbdc.sh v1.2.5 已在两节点执行，SHA256 与批准值一致，且 FAIL=0 且 ERROR=0
☐ kb_scripts v1.1.7 **tar 内 8 个文件**已在两节点部署（kb_lib.sh 权限 640、不给执行位）
☐ 依赖预检已跑（ssh/rsync/pgrep/awk/df/find/findmnt/lsof/gzip/ping/mktemp 齐全）
☐ ★ 存储侧依赖预检已跑（mountpoint/blkid/blockdev/**fuser**/**lsof**/**dumpe2fs**/**xfs_repair**/stat/readlink/findmnt/install/sha256sum 齐全，见 §2.3）
   ⚠️ dumpe2fs←e2fsprogs、xfs_repair←xfsprogs、getfattr←attr、getfacl←acl、fuser←psmisc
   ⚠️ **xfs_repair / dumpe2fs / getfattr / getfacl 缺失即 STOP**；**fuser / lsof 为佐证工具**（强烈建议装，缺失不阻断 —— 主证据是 M9a 正向枚举）
☐ kb_scripts 故障注入自测全部 OK（rc=1 **且命中预期失败原因**；**项数以发布包 README 为准**，v1.1.7 为 10 项）
☐ ★ 静态回归断言全部 OK（backup_check 含 -w、offcluster 无 du -sb、各文件声明 v1.1.7）
☐ ★ sha256sum -c SHA256SUMS 全部 OK（覆盖 7 个文件，不含它自身），且 8 个文件已与附录 B.1 逐行核对
☐ ★ 发布包根目录中确认含 kbdc.sh（v1.1.1 曾遗漏，v1.1.6 README 曾写成"单独交付"）
☐ ★ kb_offcluster_copy.sh 的 EXPECT_REPO_MOUNT 已按现场存储方案设置（见 §8.5）
☐ ★ 日志清理 cron 的路径 = log_directory 实际取值（见附录 B.4）
☐ 所有 WARN 项均已有人工结论与证据记录
☐ TCP 连接下 SHOW tcp_keepalives_* 为 2/2/3/9000（非本地 socket 的 0）
☐ trusted_servers 200 次量化复测 fail=0（★ 判据为【收到回包数 > 0】，不是退出码，见 §10.6）
☐ 单主检查（standby.signal）纳入启停 SOP
☐ 人工维护「pause → 维护 → unpause」流程已写入规程，unpause 纳入巡检
☐ sys_monitor.sh 对 cron 的影响已实测（决定是否批准为一键启停路径）
☐ 脑裂风险已由业务方书面三选一
```

---

## 变更记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| v1.0 | 2026-09-05 | 首版 |
| v1.0.1 | 2026-09-05 | 修订 6 项从参数基线回归的表述 + 3 项 P2 |
| v1.0.2 | 2026-09-05 | 四态判定说明；checklist 由「无 FAIL」改为「FAIL=0 且 ERROR=0 且 WARN 均有结论」；`max_connections` 适用范围限定 |
| v1.0.3 | 2026-09-06 | 可打印 checklist 的同步复制判据由弱版改为强判据（Primary 两条 + Standby 一条） |
| **v1.1.17** | 2026-09-13 | 第四十一轮评审修订（P0×1 / P1×3 / P2×2，全部成立）。P0-1、P1-1 与 P2-2 的主体在 **M-SEQ v1.11**（`/proc` 对象存在性判定由 `-e` 改 `-L`、取证函数改三态、授权声明改调用参数、删除 `kb_ref_probe` 悬空引用）；本文档承接 **P1-2 / P1-3 / P2-1** 与调用点同步。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P1-2：checklist 仍要求 `kb_mseq.sh v1.8` 与旧哈希 `8869ec8b…84fc`。** 而 B.1 与基线 E-GATE 都是当前版本 —— **签字链三方打架**，且 **v1.8 恰好是已知带 P0 的版本**（`map_files` 单项取证失败被 `continue` 吞掉）。运行时会被 E-GATE 的哈希门拦住，故非运行时 P0；但**签字表不该出现一个已知有缺陷的版本号**。已更新为 **v1.11 / `35a77ded…b969`**，并在该行旁注明"随每次 M-SEQ 升版同步"（B.5 第 6 条）。<br>**★ P1-3：三容量域 checklist 与合法补偿分支互相矛盾。** 旧写法"**三个容量域的 LV 已划分【并已挂载】**"是按推荐架构写的通用句，而文档自己明确允许域② 二选一 —— **选补偿分支时域② 本就没有独立 LV，那一项永远勾不上**，于是一个被认可的合法方案在最终签字时必然留一个空 checkbox。改为**条件式**：域① 记 SOURCE、域③ 要求独立 LV 且与 DATA 分离、**域② 交给下一条的二选一，不要求它一定有独立 LV**。<br>**★ 调用点同步 destroy 参数形式。** §2.3 恰好是**连续两个设备**（syswal / kbbackup）—— 旧的环境变量写法下，为 syswal 声明一次后 **kbbackup 会直接继承**该授权，而声明文案写的是"本设备"。三处调用点全部改为 `destroy --no-lazy-umount`；旧环境变量不再被识别（fail-closed）。**接入清单**：397 / 398 / 633 三条 `mkfs` 前均为 `kb_dev_released … destroy --no-lazy-umount`。<br>**P2-1**：checklist 不再写死基线版本号（原"v1.3.21 为…"），改"以**当前配套基线** 0b.4 为准" —— 避免每轮追版。<br>B.1 换 M-SEQ **v1.11** 双哈希（整文件 `35a77ded…b969` / 本体 `052b7cfb…cb2b`）；manifest 示例的两行文档文件名同步为 `v1_3_27` / `v1_1_17`。配套基线指向 **v1.3.27**。 |
| **v1.1.16** | 2026-09-13 | 第四十轮评审修订（P0×2 / P1×3 / P2×1，全部成立）。P0-1 与 P1-3 的主体在 **M-SEQ v1.10**（`map_files` 单项取证失败沿用 race 模型、`purpose` 白名单），P1-1/P1-2 在基线 **v1.3.26**；本文档承接 **P0-2 的部署侧**与 **P2-1**。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P0-2（部署侧）：三处 `mkfs` 全部接上 `destroy` 授权。** 上一版 §2.3 的两条 `mkfs` **完全没有 M9 调用**、§2.4 用的是**普通 `check`** —— 而**普通 check 不得作为破坏性授权**（它不查懒卸载声明，也不管 mmap 覆盖缺口）。⚠️ §2.3 那两个 LV 虽是刚 `lvcreate` 出来的新设备、前面还有"同名 LV 必须不存在"的硬门，看起来不可能有持有者，**但"理论上不可能"正是本套 SOP 反复翻车的地方**（"正常 `umount` 会 EBUSY 挡住"就被 `umount -l` 绕开过），而授权检查的代价只有几秒 —— **不留例外**。**接入后的机械扫描清单**：393 / 394 / 621 三条 `mkfs` 前均为 `kb_dev_released … destroy`。<br>**★ P2-1：§2.4 与 checklist 的旧 M9 描述改成实际证据项。** 旧文案"未挂载 + 无进程持有（findmnt/fuser 均三分）"已不符 v1.10 的模型（M1b 跨 namespace + M9a 的 fd/cwd/root/exe 硬覆盖 + map_files 尽力而为 + fuser/lsof 仅佐证）。checklist 改为**逐项记录证据**：M1b 扫描进程数、M9a 四类引用无命中、`KB_MMAP_COVERED`（为 no 时另记 `UNREAD`/`FAILED`）、destroy 授权及两项声明。⚠️ **这样改还顺带堵住一类问题** —— P0 级的"mmap 被错标成已覆盖"正是藏在"无进程持有"这种笼统结论后面的。<br>**★ B.5 新增第 7 条纪律：破坏性授权接入检查**（与基线改版纪律第 0 条对称）—— 扫全文每个 `mkfs*`/`wipefs`/`lvremove` 并逐条列出其 `destroy` 授权，清单贴进变更记录。立这条的原因：基线 v1.3.25 写了"mkfs 前置链已改调 destroy"，**而当时七个入口只有一个接上了**。**凡是会写"都改了"的地方，都必须有一个能跑出来的清单。** 原第 7~10 条顺延为 8~11，并注明回扫与基线**同规则、同脚本**。<br>B.1 换 M-SEQ **v1.10** 双哈希（整文件 `3bd7014a…e5d3` / 本体 `c9d3e09a…c7b7`）；manifest 示例的两行文档文件名同步为 `v1_3_26` / `v1_1_16`（B.5 第 10 条要求）。配套基线指向 **v1.3.26**。 |
| **v1.1.15** | 2026-09-13 | 第三十九轮评审修订（P0×2 / P1×4 / P2×1，全部成立）。两个 P0 与两项 P1 的主体在基线 **v1.3.25** 与 **M-SEQ v1.9**（M9a 扩为 `fd/*+cwd+root+exe` 硬覆盖 + `map_files` 尽力而为、新增 `destroy` 破坏性授权模式、文件头"用法"改为 E-GATE 口径；基线 0b.3/2.2 同步 fail-close、全文回扫 32 处、2.7b/2.10 改走 `kb_parse`）；本文档承接 **P1-2 / P2-1** 与两条改版纪律。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P1-2：B.1 的四处互相冲突一次性改清楚。** ① 首段此前写"根目录 = tar + 8 文件 + kbdc + kb_mseq + RELEASE"**不含两份 Markdown**，与表格的 14 矛盾 —— 现已统一为 **14 个对象**；② manifest 示例的文档文件名还停在 `v1_3_23` / `v1_1_13` —— 现改为当前文件名，**并写入 B.5 第 9 条要求随每次改版同步更新**；③ 示例只列 **5 行**却称"覆盖全部交付物"——**示意 ≠ 完整清单**，现已列全 **13 项**；④ **数学关系写错**：manifest 不可能验证自身，正确是 **14 = 独立渠道验 manifest 自身 1 + manifest 验其余 13**，B.2 措辞与 checklist 一并更正，并清掉"11 个交付对象全覆盖"的 v1.1.11 旧口径。<br>**★ P2-1 + 回扫用同一把尺子重跑。** §2.3 的 `chown kingbase:kingbase "$MNT"` 补守卫；**并用与基线相同的回扫规则重扫本文档** —— 上一轮我用的正则较窄（未含 `mkdir -p` 与不带 `-R` 的 `chmod`），这次按同一规则扫出 **10 处新漏网**（5 处 `mkdir -p`、5 处 `chmod`），已全部加守卫，**复扫 23 条、无守卫 0**。⚠️ 这正说明"同规则、同脚本"这条纪律的必要性：**两边用不同的尺子，等于没有统一纪律。**<br>**★ B.5 新增两条纪律**：第 8 条**镜像面检查** —— 凡修改同时存在于两份文档的同一段 SOP（§2.3 ↔ 基线 0b.3、§2.4 ↔ 基线 2.2、E-GATE 前置 ↔ 基线 1.4.4），**必须同时改、同时记录，只改一侧视为未关闭**（v1.1.14 修了本文档的 `lvcreate → mkfs` 而基线直到 v1.3.25 才修，中间形成"部署副本安全、基线真源危险"）；第 9 条 manifest 示例文件名随版本同步。<br>B.1 换 M-SEQ **v1.9** 双哈希（整文件 `a74cae75…a8cf` / 本体 `670bcfe0…78f6`）。配套基线指向 **v1.3.25**。 |
| **v1.1.14** | 2026-09-13 | 第三十八轮评审修订（P0×2 / P1×5 / P2×2，全部成立）。P0-1 与三项 P1 的主体在基线 **v1.3.24**（**M-SEQ 升 v1.8**：M1b 改单次受控 `awk` + `getline` 判读取失败、M1 的 `blkid TYPE` 改 `kb_parse`、M9a 文案降级）；本文档承接 **P0-2** 与 **P1-4 / P1-5 / P2-1**。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P0-2：`lvcreate → mkfs` 先决条件失败仍继续。** §2.3 的四行破坏性命令之间**既无 `\|\| exit 1` 也无 `set -e`**；实测两个 `lvcreate` 注入 rc=5 后 `mkfs.xfs` 照样被调用、FINAL_RC=0。真实语义是"**创建没成功并不会阻止格式化那个名字对应的设备**" —— 危险场景很具体：**重跑时 `lvcreate` 因同名 LV 已存在而失败 → 紧接着 `mkfs` 那个设备**，而那上面可能正是上一轮留下的数据。⚠️ 不能把安全寄托在"`mkfs.xfs` 恰好识别出签名并拒绝"（旧 LV 未格式化、签名损坏时它不会拒绝）。**修法**：创建前断言 LV 尚不存在（重跑现场最易踩）、逐条 `\|\| exit 1`、格式化前校验 `-b` 与**实际容量 ≥ 规划**。<br>**★ 顺带做了首次【全文破坏性命令回扫】**：`mkfs`/`lvcreate`/`pvcreate`/`vgextend`/`chown -R`/`install` 等 **11 条全部是裸写法，现已全部加守卫**。⚠️ 其中 `lvcreate → mkfs` 是**从 v1.1.0 活到现在的原始写法** —— 十几轮把 M-SEQ 打磨到"连解析器都判 rc"，**而老代码块没人回头看过**。该回扫已写入 B.5 第 7 条，**此后每次改版必做**。<br>**★ P1-4：ZIP 对象计数与 manifest 矛盾。** v1.1.13 一边说 `RELEASE_SHA256SUMS` 覆盖两份 Markdown，一边把根目录定义成 **12（不含文档）** —— **照 B.2 执行 `sha256sum -c` 会直接报找不到**。正式定义为 **14 个对象**。<br>**★ P1-5：RELEASE 校验移到 B.2 第 0 步最前。** 此前它排在"用本文档 B.1 的值验 tar → 解包 → 验 tar 内文件"**之后** —— 用来证明"这份文档是不是批准版"的信任根，反而在**已经信任了这份文档并解完包之后**才执行，**信任链顺序不闭合**。现改为：RELEASE 全通过 → 才允许使用 B.1 内任何批准哈希。<br>**P2-1**：依赖预检的 STOP 文案不再把 `fuser` 列为需补齐项（它已是佐证工具）。<br>B.1 换 M-SEQ **v1.8** 双哈希（整文件 `8869ec8b…84fc` / 本体 `8cad0e26…322a`）。配套基线指向 **v1.3.24**。 |
| **v1.1.13** | 2026-09-13 | 第三十七轮评审修订（P0×3 / P1×5 / P2×2，全部成立）。三个 P0 与两项 P1 的主体在基线 **v1.3.23**（**M-SEQ 升 v1.7**：`kb_run` 回读判 rc、**M9a 改用 st_dev+st_rdev 双语义**、**M1b 跨 namespace 遍历**、M12 改名降级、M6b 删 `wc` 分支）；本文档承接 **P0-3 的部署侧**与 **P1-3 / P1-4 / P1-5**。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P0-3（部署侧）：清除三处裸 `. /root/kb_mseq.sh`。** 在 E-GATE 之后重新 source，等于用"当前磁盘字节"把刚验证过的函数覆盖一遍 —— 期间文件被改，验证就白做了。三处全部改为**标准断言**：不仅查 `KB_EGATE_OK`，还**重新校验 `/root/kb_mseq.sh` 的整文件哈希**（旧写法只查变量非空 + 有 `kb_parse` 函数，**只能证明"以前跑过"**）。<br>**★ P1-3：依赖预检的 `for` 循环终于改了。** v1.1.12 已在正文与 checklist 把 `fuser`/`lsof` 写成"佐证工具、缺失不阻断"，**但那个 `for` 循环没改** —— 真实行为仍是"缺 `fuser` 就 STOP"，与说明正好相反。**这是本文档第三次"说明改了、可复制代码没改"。** 本版拆成两组：硬依赖组（缺即 STOP）与佐证组（缺只告警）。<br>**★ P1-4：§2.3 的两个 `findmnt` 相等比较。** `[ "$(findmnt … "$d")" = "$(findmnt … "$MNT")" ]` —— **两侧同时失败时都是空串，`"" = ""` 成立 → PASS**，正是本套文档自己总结过的"两个错误互相抵消成一个 PASS"。改为 `kb_parse ... single` 分别采集、再比较，并在报错里打印两侧实际设备。<br>**★ P1-5：新增 `RELEASE_SHA256SUMS`，ZIP 对象 11 → 12。** 基线 E-GATE 把**基线文档自身**当作信任根，并写着"文档真伪由本文档 B.1/B.2 负责" —— 而 B.1 的批准对象里**根本没有这两份 Markdown**，那句话是悬空的。新清单覆盖全部交付物**含两份文档**，B.2 增加"解包后第一步先 `sha256sum -c RELEASE_SHA256SUMS`"。⚠️ **诚实标注边界**：该清单自身的哈希不可能写在它自己里面，必须通过**交付邮件/工单正文**独立送达并人工核对一次 —— **链条总要有一个起点，把起点标出来比假装闭环更重要。**<br>B.1 换 M-SEQ **v1.7** 双哈希（整文件 `28a122a8…6116` / 本体 `d320ac85…12a1`）；checklist 同步 M12 新名与"只覆盖命令替换形式"的局限说明。配套基线指向 **v1.3.23**。 |
| **v1.1.12** | 2026-09-13 | 第三十六轮评审修订（P0×3 / P1×4 / P2×2，全部成立）。三个 P0 与两项 P1 的主体在基线 **v1.3.22**（**M-SEQ 升 v1.6**：新增 **M-2 `kb_parse` 受控解析**、**M12 裸解析机械扫描**、**E-GATE 统一入口门**，M9a 的 `stat` 失败改为区分 race）；本文档承接 **P1-3 口径统一**与交付/入口两项。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P1-3：`fuser` / `lsof` 的文档口径与代码相反 —— 两套安全模型同时存在。** 本文档 v1.1.10/v1.1.11 的 checklist 写「**均为必需，M9 不接受单探针**」，而 M-SEQ **v1.5 起的代码**已是「未安装则跳过佐证探针」。**本版按代码口径统一**：M9 的主证据是 **M9a 正向枚举**（扫 `/proc/<pid>/fd/*`，扫描完整且没找到才算无人持有，**扫描不完整一律 ERROR**）；而 `fuser(1)` 的返回码协议**本身不提供"证明无人持有"的能力**（"没有"与 fatal error 都非零），写成"必需"也换不来证明力，它只能在 rc=0 时把结论从 free 升级为 busy。**仍强烈建议安装**，但缺失不阻断。⚠️ **若政策坚持双探针必需，必须改【代码】而不是只在签字表上写"必需"** —— 签字表与代码相反，比两者都宽松更糟。<br>**★ §2.3 改为执行基线 1.4.4 的 E-GATE**，不再在本文档复制那串哈希（复制的字面量一旦升版必漏改 —— 本文档在版本号上栽过两次）。E-GATE = 外部哈希门 + 加载 + `kb_mseq_selfcheck` + **M12 裸解析扫描**；基线 v1.3.22 已让 **2.S / 2.4 / 2.6 / 2.R / 第 0 阶段**各自断言"E-GATE 已执行"，**这道门这才真正覆盖每一个入口**（v1.1.11 时只有本节与 2.S 有门，直接从基线 2.4 开始维护的路径两道门都不过）。⚠️ 同时写明**引导限制**：基线文档及其内嵌批准哈希是信任根，其自身真伪由本文档 B.1/B.2 的交付链负责。<br>**★ B.2 增加 M12 扫描**（未登记命中必须为 0），并要求**逐条复核已登记豁免**（M12 每次打印豁免行与理由 —— 豁免最容易被后人扩大，所以让它始终可见）。<br>**依赖清单重新分层**：`xfs_repair` / `dumpe2fs` / `getfattr` / `getfacl` 缺失即 STOP；`fuser` / `lsof` 为佐证工具。<br>B.1 换 M-SEQ **v1.6** 双哈希（整文件 `ad049baf…b275` / 本体 `7694bce9…2f0b`）。配套基线指向 **v1.3.22**。 |
| **v1.1.11** | 2026-09-13 | 第三十五轮评审修订（P0×4 / P1×4 / P2×3，全部成立）。三个 P0 与两项 P1 的主体在基线 **v1.3.21**（**M-SEQ 升 v1.5**：新增 **M9a 持有者正向枚举**、M1b/M6b 的解析器判 rc、**M6d xattr·ACL sentinel 快照**，`fuser`/`lsof` 降为佐证）；本文档承接 **P0-4** 与两项 P1/P2。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P0-4：B.2 的 `/tmp` manifest 可被预置文件绕过 —— 这是 v1.1.10 为修"人眼比对"而引入的新缺陷。** `cat > /tmp/kb_approved.sha256 <<EOF` **没有检查写入是否成功**：以非 root 执行时，若 `/tmp` 下已有同名文件且不可覆盖（sticky 位），`cat` 失败**而脚本不停**，`sha256sum -c` 读的是**攻击者预置的旧清单**，篡改文件照样 `OK`（已用 `setpriv --reuid=65534` 复现：`cat rc=2`、`CHECK_RC=0`）。**修法：不再经过任何临时文件**，`sha256sum -c -` 直接吃 heredoc；`kbdc.sh` 的校验也统一成同一形式。<br>**★ P1-2：tar 先解包后校验，且 tar 自身不在硬门内。** 因此 v1.1.10 宣称的"11 个交付对象全部有机器硬门"**不准确 —— 实际只有 10 个**。**修法：先验包、再解包**，tar 补进硬门；口径这才名副其实，并在文中注明上一版的说法错在哪里。<br>**★ P1-1（另一半）**：§2.3 的 time-of-use 哈希门在 **2B → 基线 2.S** 这条路径上**根本不会被执行到**（2B 要求直接跳到基线）。基线 v1.3.21 已把同一道门加在 **2.S 入口**；本文档补充说明"**外部哈希门必须放在每一个存储维护流程的公共入口**"。<br>**★ 依赖预检补 `getfattr` / `getfacl`**（attr / acl 包）：2.7 的 xattr / ACL 比对是 `REPO-KEEP` 的硬门，缺了会**走到维护窗口后半程才发现**；另补 `wc`（M6b 现在判它的 rc）。<br>**P2**：checklist 的版本残留清除（`v1.3.19` → `v1.3.21`、`kb_mseq.sh v1.3` → `v1.5`、两节点哈希 → `cfb68043…d859d`）；新增一条"校验清单一律 heredoc 直喂、不得落地成临时文件"。<br>B.1 换 M-SEQ **v1.5** 双哈希。配套基线指向 **v1.3.21**。 |
| **v1.1.10** | 2026-09-13 | 第三十四轮评审修订（P0×3 / P1×4 / P2×3，全部成立）。三个 P0 与三项 P1 的主体在基线 **v1.3.20**（**M-SEQ 升 v1.4**：M-1 退回纯采集器 `kb_run`、M1b 改读 `/proc/self/mountinfo` 按 major:minor 匹配、M8a 的 ext 分支先判 rc、新增 M0c `kb_is_mountpoint` 三态与 M6c 比较类断言护栏、M3 去掉 `awk\|wc` 遮蔽）；本文档承接 **P1-4 的统一治理**与依赖/口径。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P1-4：把"内部自洽 ≠ 外部批准"这条原则铺到全部 11 个交付对象。** 上一版只有 `kb_mseq.sh` 用了 `sha256sum -c` 机器硬门，而 **`kbdc.sh` 与 tar 内 8 个文件仍是"`sha256sum` 打印 + 人眼比对 B.1 的长哈希"**。本版：B.2 用 heredoc 写出 B.1 的 8 个批准值做 `sha256sum -c` 机器校验，`kbdc.sh` 单独做同样校验；**打印+目测的写法已从本文档清除**。并写明包内 `SHA256SUMS`（内部自洽）与 B.1 批准值（外部信任锚）**不能互相替代**。<br>**★ P1-4（另一半）：存储维护入口改为 time-of-use 重校验。** 上一版 §2.3 只跑 `kb_mseq_selfcheck`，**且把失败文案写成"与批准版不符"**——而 M10 自己已明确它证明不了批准版，**文案与能力不符比没有检查更容易误导**。本版在每次进入存储维护前重做 `/root/kb_mseq.sh` 的整文件批准值校验（安装到实际维护之间可能隔着数天）。<br>**★ 依赖与口径**：`lsof` **由"可选第二探针"提为必需**（M9 紧贴破坏性操作，不接受单探针），消除上一版"正文 `for` 当必需、说明写可选"的打架；附录 C 的存储侧依赖清单补齐 **`xfs_repair` / `lsof` / `findmnt` / `sha256sum`** 并标注各自所属软件包。<br>**★ §2.4** 同步基线对 M8a **ext 分支吞 `dumpe2fs` rc** 的修正（输出 clean 但 rc=2 时旧写法返回 0 并打印 OK）。<br>**checklist** 增补：11 对象全覆盖的机器校验、time-of-use 重校验、依赖清单更新；`kb_mseq.sh` 两节点哈希改为 `b0059648…2d24`。配套基线指向 **v1.3.20**。 |
| **v1.1.9** | 2026-09-13 | 第三十三轮评审修订（P0×4 / P1×3 / P2×3）。四个 P0 与两项 P1 的主体在基线 **v1.3.19**（**M-SEQ 升 v1.3**：新增 M-1 三分探针 / M6b 条目枚举 / M8a 文件系统干净的正面证据，M11 重写为即时复验授权，M9 的 findmnt 与 fuser 均改三分，M8 入口清状态并作废旧证据，M10 降级为内部自洽检查）；本文档承接**交付信任链、依赖与口径**三类。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P1-1：M10 不能证明"这是批准发布版"，B.2 却只做人工目测。** 批准常量就写在 `kb_mseq.sh` 自己里面，**改内容时把常量一起改掉，selfcheck 照样 `rc=0` 并打印"与批准版一致"** —— 它只是内部一致性检查。而真正的外部信任锚（B.1 的整文件哈希）此前只靠 `sha256sum` 打印 + 人眼比对一长串十六进制。**修法**：B.2 改为 `printf '%s  %s\n' "$KB_MSEQ_SHA" kb_mseq.sh \| sha256sum -c -` 的**机器校验**（安装前、安装后各一次），并写明**两步不能互相替代**：`sha256sum -c` 回答"是不是批准版"，`selfcheck` 只回答"内部是否自洽"。<br>**★ B.1 更新 `kb_mseq.sh` 至 v1.3**：整文件 `d055a4ba…58ab`（★ 外部信任锚）、本体 `ee5b623a…c6d9`（M10 内置）。<br>**★ 依赖预检补 `xfs_repair` 与 `lsof`**：M8a 用 `xfs_repair -n` 取 XFS 日志干净的**正面证据**（v1.1.8 及以前是从"只读挂载没报错"反推日志干净 —— 间接推理，且依赖内核提示文案匹配，**失效方向是放行**）；`lsof` 为 M9 的可选第二探针。并注明 **`xfs_repair -n` 的退出码须现场实测一次**（M8a 判定不依赖具体码值，一律"非 0 即阻断"，实测是为了知道现场会看到什么）。<br>**★ §2.4 的 `mkfs` 授权改用 M11 即时复验**：`blkid` 的 UUID **不会因为写入文件而变化**，所以"10:00 判 EMPTY → 10:30 别人 mount rw 写入 → 11:00 五项校验全过 → mkfs 格掉"这条 TOCTOU 成立。现在 M11 会**重新只读挂载并枚举**，条目数须为 0 且与证据记录一致，有效期由 24h 压到 1h。<br>**P2**：checklist 中"v1.3.17 为…"的过期口径改为"以基线 0b.4 为准（v1.3.19 为…）"；§2.4 的"由五项改为八项"改为"**以下全部项**" —— **本文档不再维护手工项数**（它已经过期两次）。<br>配套基线指向 **v1.3.19**。 |
| **v1.1.8** | 2026-09-13 | 第三十二轮评审修订（P0×4 / P1×4 / P2×2）。四个 P0 与多数 P1 的主体在基线 **v1.3.18**（**M-SEQ 升 v1.2**：M7b 删除 `umount -l`、M8 改用条目数主判据并换掉 `INDETERMINATE` 信号源、M9 缺 `fuser` 即 STOP、M10 改为真比较、新增 M0 设备等同判定与 M11 跨会话证据校验）；本文档承接**交付与依赖**两类。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P1-3：`kb_mseq.sh` 宣称受控交付，却不在发布 ZIP 里。** v1.1.7 已把它登记进 B.1 批准表，**但 ZIP 口径仍是 10（不含它），B.2 也没有安装步骤** —— 等于"一边宣称受控交付，一边要求现场从 Markdown 代码块手抄"，而手抄不可能保证与批准哈希逐字节相同。**修法**：ZIP 口径由 **10 改为 11**，B.2 增加 `install -o root -g root -m 600 kb_mseq.sh /root/kb_mseq.sh` + `kb_mseq_selfcheck` 机器自检 + 两节点整文件哈希人工比对；并写明"**基线 1.4.4「六」的代码块是源，发布包里的文件才是交付物**"。<br>**★ B.1 更新 `kb_mseq.sh` 至 v1.2，登记【两个哈希】**：整文件 `c7df0f76…65c3`（交付核对与两节点比对）、本体 `9428b714…bf20`（内置于脚本，M10 机器判定）。分两个是因为批准值写在脚本自己里面，对整文件算哈希会**自引用**；排除承载哈希那一行后，本体哈希可自洽计算。<br>**★ 依赖预检补齐（P0-4 连带）**：M9 缺 `fuser` 即 STOP、M8 对 ext3/4 缺 `dumpe2fs` 即 STOP，而原依赖列表里**两者都没有**。§2.3 开头新增存储侧依赖预检（mountpoint / blkid / blockdev / **fuser** / **dumpe2fs** / stat / readlink / findmnt / install），并附 M-SEQ 自检 —— **在破坏性维护窗口里临时发现缺工具，代价是整段窗口作废**。<br>**★ §2.4 同步基线两处修正**：① `EMPTY` 主判据由"普通文件数"改为**"全部条目数"** —— 盘上只有目录与软链时"文件数 0 / 字节 0"，旧判据会判 EMPTY 并直通 `mkfs -f`（实测实际条目数 = 2）；② `INDETERMINATE` 换信号源（XFS 靠 `norecovery` 被拒绝的 stderr、ext3/4 靠 `dumpe2fs -h` 的 `Filesystem state`），旧版 `dmesg \| grep` 不按设备过滤且环形缓冲区会滚掉。<br>**★ `mkfs` 前硬门改读证据文件**：`KB_RO_*` 只活在同一 shell，而"检查→签字→`mkfs`"多半跨会话 → 硬门必然 STOP → **操作员会发现"手动 `export` 就能过"**，门就废了。改用 **M11 `kb_ro_evidence_ok`**（设备 / UUID / 时效 / 判定 / 条目数 五重校验）。<br>**checklist** 同步：条目数主判据、证据文件与 M11、`kb_mseq.sh` 交付与两节点哈希、存储侧依赖预检。配套基线指向 **v1.3.18**。 |
| **v1.1.7** | 2026-09-13 | 第三十一轮评审修订（P0×3 / P1×4 / P2×3）。P0-1 / P0-2 与四项 P1 的主体在基线 **v1.3.17**（M-SEQ 升 **v1.1**：新增 **M7b 幂等卸载**、**M8 安全只读检查**、**M9 设备释放**、**M10 自身完整性**）；本文档承接 **P0-3**、**P1-4**、**P2-2** 及配套登记。**`kb_scripts` v1.1.7 不需升版。**<br>**★ P0-3：§2.3 全新装机的域③ 挂载块仍绕过 M-SEQ。** 上一版这里是 `UU1=$(blkid)` → `grep`/`echo` 写 fstab → 裸 `mount` → 裸 `findmnt`，**正是基线 v1.3.16 刚在 2.6 定性为 P0 的那套写法**，却原样留在部署文档里。三个缺口：① `UU1` 取空会写出坏 fstab 行；② `grep` 只查「正确 UUID + 该挂载点」这一对，同挂载点已有**错 UUID 活动行**时查不到 → 追加正确行 → 而 `mount` 用**第一条** → **挂上错误的卷**；③ `mount` 无硬门，挂载失败后 `mkdir -p "$LOGDIR" "$DUMP"` 会把目录建在**根盘**，日志与逻辑备份从此静默写 `/`。**修法**：改用 M1 + M3 + M4 + M5，并在建完目录后断言 `LOGDIR` / `DUMP` 与 `$MNT` 在同一卷上。<br>**★ §2.4 只读检查重写（同步基线 P0-2）。** 旧写法 `mount -o ro,norecovery` 不判返回码、无 `mountpoint` 确认、`umount` 也不判 —— 挂载失败时 `ls`/`du` 看的是**根盘上刚 `mkdir` 的空目录**，于是"内容可丢弃"被打勾、`mkfs` 格掉一个**从未真正看过的卷**。改用 **M8 `kb_ro_inspect` + M9 `kb_dev_released`**，判定三分（`EMPTY` / `NONEMPTY` / **`INDETERMINATE`** —— 未回放日志下"看不到"≠"没有"）；破坏性前置由**五项改八项**，其中"只读检查已完成"替换为 **`KB_RO_VERDICT` / `KB_RO_FILES` / `KB_RO_BYTES` 三个必须填数字的格**；`mkfs` 前另加执行时硬门。**"空"必须是一个数字，不能是一段目测。**<br>**★ 附录 B.1 登记 `kb_mseq.sh` v1.1**（SHA256 `6e113fe4…c6a89`，装 `/root`、权限 600、**不进 `$BKS`、不进 cron**）。它已是破坏性维护的关键依赖，此前没有任何可核验的交付身份；**唯一源是基线 1.4.4「六」**，本文档只登记版本与哈希、不复制内容。<br>**P1-4：占位符纪律扩到全部代码块。** §7.2 的活动行 `max_connections = <待定>` 整段复制会让数据库**配置解析报错**，改为注释掉 + "未定值不得上线"（与基线 F.18 同口径）；另清理 checklist 中两处 `<…>`。<br>**P2-2**："2A 出场检查四项全 ✅"口径已过期（v1.1.6 起含 M2 容量断言），改为"**项数以基线 0b.4 为准**"。<br>**checklist** 增补只读检查三数值与 `kb_mseq.sh` 两节点哈希一致两项。配套基线指向 **v1.3.17**。 |
| **v1.1.6** | 2026-09-13 | 第三十轮评审修订（P0×4 / P1×4 / P2×1，全部成立）。四个 P0 主体在基线 **v1.3.16**（新增 **M-SEQ 挂载接入通用校验序列**、`--delete` 重试语义、容量与 UUID 的实际证据绑定、回退步骤 fail-close），本文档承接其中的**联动项与两条文档级问题**。**`kb_scripts` v1.1.7 不需升版**，附录 B.1 哈希未改动。<br>**★ §2B 删除 2.S 步骤摘要。** 上一版在此摘录了"临时挂载 + rsync 迁移 → 三条断言"，而基线 v1.3.16 的 2.S 已是"纯预检（不挂载不复制）→ `.old` → fstab + 挂载并复核 UUID → 唯一一次带 `--delete` 的复制 → 五条机器断言 → 重试前清空目标卷" —— **摘要也是一种副本，一样会漂移**。本版起 §2B 只保留**前置状态 / 时间点 / 不可协商的约束**三件事，并明确写出「**唯一执行真源是基线 1.4.4 的 2.S，禁止按本文摘要替代执行**」。这与附录 B「不再内嵌脚本源码」、第 2 章「不维护第二份可执行 SOP」是同一条治理原则。<br>**★ §2.3 的 `lvcreate -L 100G` / `-L 300G` 改为从 `/root/kb_plan.env` 读签字定值**（留空即 STOP）。上一版 §2.2 刚写完"100GB 是示例值不可照抄"，下面的可复制块就写着 `-L 100G` —— **警告在文字里、错误在可复制块里，永远是复制粘贴赢**，由此形成"签字 600G、实际建成 100G、全程全绿"的验收假 PASS 通道。<br>**★ §2.3 的 2A 出场检查改用基线 M-SEQ**（`kb_dev_ready` + `kb_dev_capacity`），与基线 0b.4 同源，**新增"实际容量 ≥ 签字规划值"的机器断言**，避免两边判据漂移。<br>**★ 占位符清理（基线 v1.3.16 起的统一纪律）**：可执行代码块内不得出现 `<…>` 尖括号占位符。本文档扫出 3 处并修正，其中 `chpasswd` 与 `.kbpass` 两处若被直接复制，会把口令**字面设成"<设定口令>"** —— 改为变量 + 留空即 STOP，`.kbpass` 另加 `umask 077`。<br>**P2**：§2B 引用的跳转点由 **§5.4** 更正为 **§5.5**。<br>**checklist** 增补三项实际证据格：两节点的实际设备容量与 UUID、实际挂载设备 = 预期设备（M5）、该挂载点 fstab 活动行恰好 1 条（M3）。配套基线指向 **v1.3.16**。 |
| **v1.1.5** | 2026-09-13 | 第二十九轮评审修订（P0×1 / P1×3）。评审确认：上一轮修订**已真正落地**；**双方案架构无回归**；**`kb_scripts` v1.1.7 不需升版**（B.1 哈希与实际包一致，未改动）。<br>**★ 本章拆成 2A / 2B 两段（结构性修订）。** 上一版把域② 接入指向基线 2.S，而 2.S 要求 `$PGDATA/sys_wal` **已存在**；但本章在目录里排在第 5 章集群安装**之前** —— 顺序阅读的人无从判断"现在做还是装完做"。**修法**：章首加**时间轴**；**§2A「装机前：规划与块设备准备」**（§2.1~§2.4，只到块设备与域③ 为止，`syswal` 建完就停）；**§2B「装机后（受控维护窗口）：域② `sys_wal` 接入」**移到章末；**新增 §5.5 跳转点**，在集群装完、`$PGDATA/sys_wal` 已有内容时把读者送回 §2B。目录中一并体现 2A / 2B。<br>**★ 顺序约束写死两条**：① **2.S 必须在第 7 章 WAL 参数落地之前完成**（否则 `wal_keep_segments` 一提上去，`sys_wal` 会先把根盘撑起来）；② 已投产现场若同时要做域③ 改造，`sys_wal` 接入须与之放在**同一维护窗口**内按基线顺序执行（2.S 取的是 `readlink -f` 的解链真实路径，DATA 一移动，fstab 的 `sys_wal` 条目就要跟着改）。<br>**★ §2.2 容量：`100GB` 明确标为示例值，不可照抄。** `syswal` 尺寸不能脱离 WAL 参数单独拍板 —— 按基线 8 倍规则，现场 `max_wal_size=64GB` 时要求的稳态上限约 **512GB**，**与 100GB 差一个量级**；`max_wal_size` / `wal_keep_segments` / `syswal` 容量**必须一起定死**（定值表见基线 **0b.1**），第 7 章的 WAL 参数须与之一致。<br>**★ §2.3 新增「2A 出场检查」**（= 基线 **0b.4**）：块设备存在、`FSTYPE=xfs`、`UUID` 非空、未挂载在别处，四项全 ✅ 才能进第 3 章；并写明**新建 `syswal` 不套用第 0 阶段只读检查流程**（那是针对盘上可能有别人数据的已有 LV），**两类动作不可混用**。<br>**checklist** 增补 2A/2B 时点、三数字定值、`fstab` 与方案一致且不含 `nofail` 五项。配套基线指向 **v1.3.15**。 |
| **v1.1.4** | 2026-09-13 | 第二十八轮评审修订（P0×1 / P1×5 / P2×2）。评审同时确认：**「现场环境版 `MNT-SITE` + 推荐配置版 `MNT-MOVE`」两套并存是正确设计**；**`kb_scripts` v1.1.7 通过静态审核，本轮不升版**（B.1 的批准哈希与实际包一致，无需改动）。<br>**★ P0（本文档侧）：域② `sys_wal` 只有创建没有接入。** §2.3 会 `lvcreate -n syswal` + `mkfs.xfs`，但其后的 fstab / 挂载 / 属主 / 目录步骤**只处理域③ `$MNT`** —— 照抄执行得到的是**一块格式化完、从此没挂上的 LV**，而真正的 `$PGDATA/sys_wal` 仍在 DATA 盘上。**修法**：§2.3 末尾新增「域② 的接入」小节，给出**二选一**（按基线 **1.4.4 的 2.S** 完成完整接入 SOP / 走 P0-15 补偿分支），并写明「只 `lvcreate` + `mkfs` 不等于已独立」。<br>**★ 删除一句误导性表述**：v1.1.3 写「`sys_wal` 的挂载必须在 initdb 之后、数据库首次启动之前」，暗示存在一个可以直接 `mount` 空目录的干净窗口 —— **该窗口在本安装方式下基本不存在**（`V8R6_cluster_install.sh` 一次性完成 initdb、建备库并拉起集群，见 §5.4），所以 `$PGDATA/sys_wal` 里一定已有 WAL 段与 `archive_status`，**直接挂载会把原内容整个遮住**。<br>**★ 域② 明确禁止 `nofail`**：域③ 挂载失败只是备份与日志写回根盘（`df` 可见），**域② 挂载失败是 WAL 静默写回根盘 —— 库照常跑、没有任何现象**，两者危险程度不对等，不能沿用域③ 的取舍。<br>**P1：`log_directory` 两版方案都必须改。** 现场当前值是**相对路径 `sys_log`**，跟着 DATA 走（`MNT-MOVE` 下会随 DATA 回到根盘）。§7.2 改为「active 一行 + 注释另一行」并写明：**必须改在 `es_rep.conf`**、执行位置是基线 **2.7c**、起库后由 **2.10 第五项**以 `SHOW` 运行值复验。<br>**P2：统一交付计数口径。** v1.1.3 的三个「7」不是同一个集合（tar 内 8、`SHA256SUMS` 覆盖 7、部署 8），B.1 新增口径对照表，B.2 的计数断言由 7 改为 **8**；此后一律按「tar 内 8 个文件」表述。<br>**P2：域③ 示例 LV 改名** `kbdata` → **`kbbackup`**（这块卷恰恰要求不能包含 DATA；注意本现场既有 LV 仍是 `klas-backup`，不连带改动）。<br>**checklist** 增补域②、`log_directory` 运行值、计数口径三类勾选项。配套基线指向 **v1.3.14**。 |
| **v1.1.3** | 2026-09-13 | 第二十七轮评审修订（P0×3 / P1×6 / P2×3，全部成立），本文档承接其中 **2 个 P0 + 2 个 P1**。<br>**★ P0：第 2 章的存储方案本身不成立。** §2.1 把域③ 定义为 `/data`，而本现场 `$KB_DATA` 是指向 `/data/kingbase/data` 的软链（§2.1 教训 24 自己记录过）—— **PGDATA 就在 `/data` 树下**，把备份卷挂到整个 `/data`，只是把 DATA+backup+log 一起搬到新卷，**域③ 从未分开**。修法：域③ 改为「独立 LV，挂载点须不包含 PGDATA」，给出 **SOURCE 比较判据**（`findmnt -no SOURCE -T` 的 repo / `log_directory` 均须 ≠ 解链后的 DATA）与 **`MNT-SITE` / `MNT-MOVE` 两版方案**；§2.3 增加**挂载前硬门**（PGDATA 不得在挂载点之下），并按 `$MNT` / `$LOGDIR` 参数化。<br>**★ 结构性修订**：**本章不再维护第二份可执行迁移 SOP** —— 已投产现场的存储改造一律以《参数基线》**1.4.4** 为唯一真源（含两版方案、两条 repo 路径、2.R 回退）。这与 v1.1.2「附录 B 不再内嵌脚本源码」是同一条治理原则：同一过程有两份真源必然漂移。<br>**★ P0：发布身份脱节。** v1.1.2 全文批准的是 `kb_scripts v1.1.5`，而实际交付包已是 v1.1.6 —— 现场严格照文档执行会「找不到 v1.1.5 的 tar」或「哈希全不匹配而必须停止」。B.1 全表更新为 **v1.1.7** 的实际 SHA256（并新增 `SHA256SUMS` 与 tar 自身的哈希），B.2 的解包命令同步。<br>**★ P0：交付政策自相矛盾。** 本文档要求 `kbdc.sh` 随包交付，而 v1.1.6 的 README 明写「本包不含、单独交付」。**统一为本文档口径**：tar 可以只是脚本增量包，但**发布 ZIP 根目录必须含 `kbdc.sh`**，缺失即不得交付；B.2 增加落地时的存在性与哈希核对。<br>**P1：自测项数过期。** B.3 与 checklist 写死「8 项」，而 v1.1.6 起为 10 项 —— 会漏执行两个输入校验回归。改为**一律以发布包 README 为准、不再写死项数**，并在 B.5 增补该维护纪律。<br>**P1：`kb_offcluster_copy.sh` 解禁。** v1.1.2 的「暂不批准」原因（`lsof rc=1` 的 fail-open）已由脚本集 v1.1.6 修复并复测，v1.1.7 又修掉了字节比对的系统性假 FAIL；§8.5 与 B.1 同步改为**已批准**，并补充 `EXPECT_REPO_MOUNT` 的三种取值。<br>**其他**：§7.2 的 `log_directory` 与附录 B.4 的日志清理 cron 路径随方案参数化；§11.3 增加**启动前硬门 ⓪ DATA 路径完好性**（悬空软链会伪装成「2 个主库候选」，极易误读为脑裂）；开头变量块新增 `MNT` / `LOGDIR` / `DUMP`。配套基线指向 **v1.3.13**。 |
| **v1.1.2** | 2026-09-11 | **★ 结构性修订：附录 B 不再内嵌脚本源码，改为「批准版本 + SHA256」索引。**<br>**事故背景**：v1.1.0/v1.1.1 的附录 B 内嵌脚本全文，而脚本已迭代五轮至 v1.1.5，附录**一次未同步** —— 文档首页写「可照抄执行版 · 配套 v1.1.5」，附录里却是 **v1.0**，其中含 `ERROR 不阻断退出码`、`pgrep -f`（会被无关进程骗过）、`ping 退出码判可达`（**会把 9 月 9 日现场刚证明是假的 trusted_servers FAIL 再造一遍**）。只要有人相信「可照抄」并从附录复制，就会绕过发布包里真正的脚本。<br>**修法是结构性的**：源码只存在于发布包，文档只维护索引；日后升级仅更新 B.1 的版本与哈希，**不存在源码副本再次漂移的可能**（B.5 写明该维护动作）。<br>**★ 补上遗漏的交付物**：`kbdc.sh` v1.2.5 —— v1.1.1 的发布包**遗漏了它**，而重新冻结的唯一前提正是「用 v1.2.5 复采」，按包执行的人拿不到采集脚本。<br>**凭据方案更正三处**：① 环境变量是 `KINGBASE_PASSFILE` 不是 `KBPASSFILE`；② **`-w` 与 `-W` 相反** —— 现场注释只否定了 `-W`（`--password`，强制交互提示），**推不出 `-w`（`--no-password`，批处理所需）不可用**，v1.1.1 据此撤销 `-w` 是误推；③ 连接必须显式带 `-h`，否则 `.kbpass` 首列按 `localhost` 匹配。<br>**标注 `kb_offcluster_copy.sh` 暂不批准用于正式容灾复制**（`lsof rc=1` 被解释为「确认无占用」，而扫描不完整时同样返回 1，属 fail-open；待脚本集 v1.1.6 修复）。<br>**checklist**：自测「七项」改为**八项**并强调需命中预期失败原因；新增 SHA256 逐行核对、发布包含 `kbdc.sh` 两项。配套基线指向 **v1.3.12**。 |
| **v1.1.1** | 2026-09-09 | **并入 2026-09-09 两节点实跑结果**；配套版本统一指向参数基线 **v1.3.11**、采集脚本 **v1.2.5**（SHA256 `5c04873b…0d5c`）、巡检脚本集 **v1.1.5**。<br>**新增 §8.4a「逻辑备份的正确核对方式」**，记录本现场三个坑：① 每次备份同时产出 `backup_log_*`（约 184B、mtime 更晚），按最新取会误判为「产物仅 184B」；② **绝对字节阈值从根本上不成立** —— 实测 `esrep` 914B、`test` 683B、空库期 618B 均为合法备份，正确代理指标是 `gzip -t` 完整性；③ 全树取最新会掩盖单库缺失，必须**从 `sys_database` 查清单逐库核对**（排除规则与 `backup8.conf` 同源）。<br>**新增教训 22**：不要用 `ping` 退出码判可达性 —— `-c 3 -w 2` 在默认 1s 包间隔下 count 凑不满 3、**退出码恒为 1**；曾归因为「RTT 长尾」的解释同样错误（node1 RTT 仅 0.7ms 照样"失败"）。§10.6 复测命令同步改判**收包数**。<br>**新增教训 23**：`trusted_servers` 检测**平时根本不跑**（`hamgr.log` 仅有 normal state 记录），只在察觉连接异常时触发；repmgr 内部实际命令仍未查证，建议并入 C 类演练。<br>**新增教训 24**：判断容量域必须 `readlink -f` + `findmnt -T` —— 本现场 `data` 是软链、`/data` 并非独立挂载点，五路径 `df` 全为 `klas-root on /`；另记录 `log_directory` 落在 DATA 目录内部。<br>**checklist 增补** 8 条：逐库核对、排除 `backup_log_*`、禁用字节阈值、容量域取证方式、`.kbpass` 需先现场验证、脚本集部署与自测。 |
| **v1.1.0** | **2026-09-07** | **重构为「可照抄执行版」**。<br>**新增章节**：第 1 章 License 核查（试用授权为新发现的上线阻断项）、第 2 章 LVM 实操（含情形 A/B 与已有文件系统的安全处置）、第 6 章 配置源收敛（含 4 条核查 SQL）、第 9 章 安全加固（`sys_hba` 收敛、`.kbpass` 免密）。<br>**新增附录 A**：官方《集群安装指南》需修正项 9 条（含新发现的 `tcp_tw_recycle=1`，该参数在 Linux 4.12+ 已移除且在 NAT 下会静默丢连接）。<br>**新增附录 B 完整脚本集**：B.1 适配集群路径的 `backup8.conf`、**B.2 `kb_backup_check.sh`（★ 查备份产物是否真的生成，专治「cron 在跑但每天都失败」）**、B.3 off-cluster 受控复制、B.4 `kb_ha_watch.sh`（★ 查 repmgrd 关闭 / `Paused=yes` 未恢复 / ping capability 丢失三类静默降级）、B.5 日志清理、B.6 cron 建议配置。<br>**新增现场教训**：`statement_timeout=60min` 全局生效、逻辑备份配置未适配集群路径、`sys_monitor.sh` 会重写配置文件、口令明文/base64 落盘、`sys_hba` 全网开放 replication。<br>**全文命令改为可直接复制**，统一变量块、执行身份与节点范围标注。 |
