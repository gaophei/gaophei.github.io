# ===== M-SEQ 挂载接入通用校验序列 —— 基线 1.4.4，域② / 域③ 共用 =====
# 版本：v1.11
# 用法（★ v1.9 更正：此前这一行与基线的 E-GATE 纪律【正好相反】）：
#   · 首次进入维护流程：必须执行《环境说明与参数基线》1.4.4 的 **E-GATE** ——
#     由 E-GATE 先用外部批准哈希校验本文件，校验通过后才 `. /root/kb_mseq.sh`。
#   · **E-GATE 成功之后：禁止再次裸 `. /root/kb_mseq.sh`。**
#     各后续步骤只做标准入口断言（重新校验磁盘文件哈希 + 确认函数已加载），继续使用已加载的函数。
#   ⚠️ 为什么这不只是注释问题：现场若单独拿到本脚本、照旧写法在每个步骤开头重新 source，
#      就会用【当前磁盘上的字节】覆盖 E-GATE 已验证过的函数 ——
#      正好重新打开基线 v1.3.23 才关闭的那条 TOCTOU。
# 约定：所有函数**成功返回 0；失败返回非 0** 并打印 STOP 原因。调用方一律接 "|| exit 1"。
#       个别函数有细分返回码，以各自契约注释为准：
#         kb_run          2 = 采集设施失败（mktemp/重定向）
#         kb_is_mountpoint 1 = 不是挂载点 / 2 = 无法判定
#         kb_dev_holders   1 = 扫描完整且无持有者 / 2 = 扫描不完整
#
# ★ 六条贯穿全库的原则（都是被事故换来的）：
#   1) 证据取不到 ≠ 没有问题。任何探针"没跑成"一律判 ERROR 并阻断，
#      不得与"跑成了且结果为空"共用一个分支（源头：kb_offcluster_copy.sh 的 lsof rc=1）。
#   2) 主路径与回退路径的断言语义不同：主路径是"这一步必须成功"，
#      回退路径是"必须达成某个终态"。两者用两个函数，不共用（M7 / M7b）。
#   3) 不可逆操作的授权依据必须是【本次即时证据】，不能是历史记录。
#      历史证据只作审计比对基准（M8 / M11）。
#   4) **采集与解释分离**：公共层只负责可靠采集 rc/stdout/stderr，不做语义分类；
#      "这条 rc 是什么意思"由调用者按【那条命令自己的协议】解释。
#   5) **解析器也是取证链的一环**。`awk` / `sed` / `wc` / `tr` / `stat` 失败同样等于"证据没拿到"。
#
# ★★ v1.6 把第 5 条从"纪律"升级为"**可机械验证的规则**"：
#    历史上它被反复违反 —— 每修好一层，下一层的解析器又冒出来（find→wc→sed→awk→stat，
#    连着五轮，每轮换一个位置）。逐点打补丁的方式已经证明会一直漏。
#    因此本版：
#      · 所有解析统一走 **kb_parse**（判 rc + **判输出形态**）；
#      · 全库**不得出现裸的命令替换解析**（`$(... | ...)` 或 `$(awk/sed/wc/tr/stat/grep/head ...)`）；
#      · 该规则由 **kb_mseq_scan_known_patterns**（M12）自检，**未登记命中数必须为 0**。
#    ⚠️ **但要诚实标注它的边界**：M12 是正则模式匹配，**只覆盖命令替换形式**，
#       独立语句形式的裸解析（如 `awk '{print $1}' f >/dev/null`）扫不到。
#       它是"已知危险模式扫描"，**不是"全库裸解析清零证明"** ——
#       v1.6 用了后一个名字，那是"声称能力 > 实际能力"，本版改名并写明局限。
#       真正的机械证明需要 shell 语法分析，不是继续打正则补丁。
#
#   6) ★ v1.10 新增：**同一类证据只能有一套失败模型**。
#      v1.9 的 M9a 里，fd 已经用"对象仍存在 = 扫描不完整 / 已消失 = 合法 race"，
#      而 map_files 还停在旧的 `|| continue` —— **同一个函数内两套标准**，
#      结果"所有映射都没查成"被打印成"mmap 已覆盖"，destroy 据此免去人工确认。
#      新增一类引用/一个分支时，必须**沿用该函数既有的失败模型**，不得另起一套。
#      （历史上同型错误已出现三次：M1b 没沿用 M9a 的模型、map_files 没沿用 fd 的模型、
#        部署文档修了而基线真源没改。）
#
# ★ 比较类断言的铁律：凡是"比较两个采集结果"的断言，**必须先各自确认采集成功，再比较**。
#   `diff <(find …|sort) <(find …|sort)` 在两侧 find 都失败时，两个空输出会让 diff 返回 0 ——
#   **两个错误互相抵消成一个 PASS**。给这种比较加 "|| exit" 只会得到一个更可信的假硬门。
#   ⚠️ 但这条铁律**不能套错对象**："没有扩展属性"是合法状态，其输出天然为空；
#      解法是让采集器产出永不为空的结构（见 kb_xattr_snapshot 的 sentinel），而不是给铁律开例外。
KB_MSEQ_VERSION="1.11"
# ★ 本体哈希（= 本文件【排除本行】后的 sha256）。M10 用它做机器判定。
#   ⚠️ 它只能证明"本文件内部自洽、未被随手改动"，【不能】单独证明"这是批准发布版" ——
#      外部信任锚是《集群部署文档》B.1 登记的【整文件 SHA256】，由 B.2 用 sha256sum -c 机器校验。
KB_MSEQ_APPROVED_SHA256="052b7cfb8610f310ebb6fc38ea687fdb62e0641e7ce653dc8d64758c46d3cb2b"

KB_NL='
'

kb_die(){ echo "STOP: $*" >&2; return 1; }

# ------------------------------------------------------------------
# M-1 采集器 —— **只采集，不解释**
#     用法：kb_run <描述> <命令...>
#       可选：先设 KB_RUN_IN=<字符串> 作为该命令的 stdin（用完自动清除）
#     返回 0 = 命令已执行完毕（它自己的返回码在 KB_RUN_RC，由调用者按该命令协议解释）
#     返回 2 = **采集设施本身失败**（mktemp / 重定向），调用者必须当 ERROR 处理
#     输出：KB_RUN_RC / KB_RUN_OUT / KB_RUN_ERR
# ------------------------------------------------------------------
kb_run(){
    local what=$1; shift
    local errf outf inf rc
    errf=$(mktemp 2>/dev/null) || { kb_die "[$what] mktemp 失败 —— 无法采集证据（/tmp 满？inode 用尽？权限？）"; return 2; }
    outf=$(mktemp 2>/dev/null) || { rm -f "$errf"; kb_die "[$what] mktemp 失败 —— 无法采集证据"; return 2; }
    if ! : >"$outf" 2>/dev/null || ! : >"$errf" 2>/dev/null; then
        rm -f "$outf" "$errf"; kb_die "[$what] 临时文件不可写 —— 无法采集证据"; return 2
    fi
    if [ -n "${KB_RUN_IN+x}" ]; then
        inf=$(mktemp 2>/dev/null) || { rm -f "$outf" "$errf"; kb_die "[$what] mktemp 失败"; return 2; }
        printf '%s' "$KB_RUN_IN" >"$inf" 2>/dev/null \
            || { rm -f "$outf" "$errf" "$inf"; unset KB_RUN_IN; kb_die "[$what] 写入 stdin 暂存失败"; return 2; }
        unset KB_RUN_IN
        "$@" <"$inf" >"$outf" 2>"$errf"; rc=$?
        rm -f "$inf"
    else
        "$@" >"$outf" 2>"$errf"; rc=$?
    fi
    KB_RUN_RC=$rc
    # ★★ v1.7：回读证据也必须判 rc —— 这是所有 kb_parse 的共同地基。
    #   v1.6 写成 `KB_RUN_OUT=$(cat "$outf" 2>/dev/null)`：命令明明执行成功（KB_RUN_RC=0），
    #   只要回读失败，KB_RUN_OUT 就变空，而 kb_parse 在 shape=any 下把空值当合法 ——
    #   实测：已挂载设备的 awk 跑成功、只让回读失败 → kb_dev_unmounted 返回 0（判"未挂载"）。
    #   **执行成功 ≠ 证据采集完成。**
    if ! KB_RUN_OUT=$(cat "$outf" 2>/dev/null); then
        rm -f "$outf" "$errf"; kb_die "[$what] 读取 stdout 证据失败 —— 采集未完成"; return 2
    fi
    if ! KB_RUN_ERR=$(cat "$errf" 2>/dev/null); then
        rm -f "$outf" "$errf"; kb_die "[$what] 读取 stderr 证据失败 —— 采集未完成"; return 2
    fi
    rm -f "$outf" "$errf"
    KB_RUN_WHAT=$what
    return 0
}

# 采集到的 stderr 摘要（打印用；自身也受控）
kb_run_err1(){ printf '%s' "${KB_RUN_ERR:-}" | tr '\n' ' '; }

# ------------------------------------------------------------------
# M-2 受控解析 —— ★ v1.6 新增，第 5 条原则的唯一入口
#     用法：kb_parse <描述> <期望形态> <命令...>
#       形态：number    结果必须是纯十进制数字
#             majmin    结果必须形如 数字:数字
#             single    结果必须是恰好一行且非空
#             nonempty  结果非空即可
#             any       不校验形态（仅判 rc）
#       可选：先设 KB_RUN_IN=<字符串> 把它作为解析命令的 stdin
#     成功：结果在 KB_PARSE_OUT，返回 0
#     失败：解析命令 rc≠0，或输出形态不符 —— 一律 kb_die 并返回 1
#     ⚠️ 为什么要判"形态"而不只判 rc：实测过一种组合 ——
#        sed 输出 "clean" 之后才返回 rc=2；若只看结果、不看 rc，就是完整假 PASS；
#        反过来，parser 半途失败也可能吐出一个"看起来合法"的短值。两者都要挡。
# ------------------------------------------------------------------
kb_parse(){
    local what=$1 shape=$2; shift 2
    kb_run "$what" "$@" || return 1
    [ "$KB_RUN_RC" -eq 0 ] \
        || { kb_die "[$what] 解析失败（rc=$KB_RUN_RC $(kb_run_err1)）—— 解析器也是取证链的一环"; return 1; }
    KB_PARSE_OUT=$KB_RUN_OUT
    case "$shape" in
      number)
        case "$KB_PARSE_OUT" in
          ''|*[!0-9]*) kb_die "[$what] 期望纯数字，实得 '$KB_PARSE_OUT'"; return 1 ;;
        esac ;;
      majmin)
        case "$KB_PARSE_OUT" in
          ''|*[!0-9:]*) kb_die "[$what] 期望 主:次 形态，实得 '$KB_PARSE_OUT'"; return 1 ;;
        esac
        case "${KB_PARSE_OUT%%:*}" in ''|*[!0-9]*) kb_die "[$what] 主设备号非法：'$KB_PARSE_OUT'"; return 1 ;; esac
        case "${KB_PARSE_OUT##*:}" in ''|*[!0-9]*) kb_die "[$what] 次设备号非法：'$KB_PARSE_OUT'"; return 1 ;; esac
        [ "${KB_PARSE_OUT%%:*}:${KB_PARSE_OUT##*:}" = "$KB_PARSE_OUT" ] \
            || { kb_die "[$what] 形态非法：'$KB_PARSE_OUT'"; return 1; } ;;
      single)
        [ -n "$KB_PARSE_OUT" ] || { kb_die "[$what] 解析结果为空"; return 1; }
        case "$KB_PARSE_OUT" in
          *"$KB_NL"*) kb_die "[$what] 期望恰好一行，实得多行"; return 1 ;;
        esac ;;
      nonempty)
        [ -n "$KB_PARSE_OUT" ] || { kb_die "[$what] 解析结果为空"; return 1; } ;;
      any) : ;;
      *) kb_die "[$what] 未知形态 '$shape'"; return 1 ;;
    esac
}

# 从字符串解析的便捷封装：kb_parse_str <描述> <形态> <输入> <命令...>
kb_parse_str(){
    local what=$1 shape=$2 input=$3; shift 3
    KB_RUN_IN=$input
    kb_parse "$what" "$shape" "$@"
}

# ------------------------------------------------------------------
# M0 两个设备路径是否指向同一块设备（dm 别名：/dev/klas/backup 与 /dev/mapper/klas-backup）
# ------------------------------------------------------------------
kb_same_dev(){
    local a=$1 b=$2 ra rb ma mb
    ra=$(readlink -f "$a" 2>/dev/null); rb=$(readlink -f "$b" 2>/dev/null)
    [ -n "$ra" ] && [ -n "$rb" ] || return 1
    [ "$ra" = "$rb" ] && return 0
    # ★ v1.7：改用 %r（十进制 st_rdev）。v1.6 用 %t:%T（**十六进制**）却套 majmin 形态校验
    #   （只接受 [0-9:]），遇到 'fd:0' 这类合法十六进制会直接判非法 —— fallback 分支本身是错的。
    kb_parse "取 $ra 的 rdev" number stat -c '%r' "$ra" || return 1
    ma=$KB_PARSE_OUT
    kb_parse "取 $rb 的 rdev" number stat -c '%r' "$rb" || return 1
    mb=$KB_PARSE_OUT
    [ "$ma" = "$mb" ]
}

# M0b 取块设备的 major:minor（十进制）
#     stat 的 %t/%T 是十六进制，/proc/self/mountinfo 第 3 字段是十进制，必须换算
#     ★ v1.6：两个 stat 都走 kb_parse 并校验形态 —— 此前是裸 stat，取空会让 KB_MAJMIN 变成
#       畸形值，导致后续所有 major:minor 比对全部失配（挂载表里明明有它也匹配不上）
kb_dev_majmin(){
    local dev=$1 rdev t T
    rdev=$(readlink -f "$dev" 2>/dev/null) || { kb_die "解析 $dev 的真实路径失败"; return 1; }
    [ -n "$rdev" ] && [ -b "$rdev" ] || { kb_die "$dev 不是块设备"; return 1; }
    kb_parse "取 $rdev 主设备号" nonempty stat -c '%t' "$rdev" || return 1
    t=$KB_PARSE_OUT
    kb_parse "取 $rdev 次设备号" nonempty stat -c '%T' "$rdev" || return 1
    T=$KB_PARSE_OUT
    kb_parse "换算主设备号" number printf '%d' "0x$t" || return 1
    KB_MAJ=$KB_PARSE_OUT
    kb_parse "换算次设备号" number printf '%d' "0x$T" || return 1
    KB_MIN=$KB_PARSE_OUT
    KB_MAJMIN="$KB_MAJ:$KB_MIN"
    # ★ v1.7 另取十进制 st_rdev：fd 比对用它，避免再做十六进制换算
    kb_parse "取 $rdev 的 rdev(十进制)" number stat -c '%r' "$rdev" || return 1
    KB_RDEV=$KB_PARSE_OUT
}

# ------------------------------------------------------------------
# M1b 设备当前是否未被挂载
#     完整读取 /proc/self/mountinfo（读取成功与否是明确的）+ 按 major:minor 匹配；
#     **不用"过滤查询的退出码"证明未挂载**（findmnt 把"没匹配到""路径不存在""其它错误"都归为 1）
# ------------------------------------------------------------------
kb_dev_unmounted(){
    local dev=$1 mi files hit unread_list scanned parsefail f
    kb_dev_majmin "$dev" || return 1
    # ★★ v1.8 重写实现（v1.7 的 P0）：
    #   v1.7 把遍历写成 `sh -c 'for … ; do awk … ; done; echo "#SCANNED=…"'` ——
    #   **循环内每个 awk 的 rc 完全没判**，而最后那条 echo 成功就让整个 sh -c 返回 0。
    #   实测：拿真实存在的 254:0 做目标、把内层 awk 全注入成 rc=2 →
    #   外层 rc=0、输出 "#SCANNED=50 #UNREAD=0"，**"所有解析都失败"被包装成"扫描完整且无命中"**。
    #   这正是本库第 5 条原则要消灭的东西，只是位置藏进了嵌套 shell 的内层。
    #
    #   本版改为【单次受控 awk】：一个 awk 进程读完所有 mountinfo，
    #   它自己的 rc 由 kb_parse 判定；每个文件的读取失败由 awk 用 getline 的返回值
    #   （<0 = 读失败）显式记录成 UNREAD 行，再由 shell 复查该文件是否仍存在 ——
    #   **仍存在 = 扫描不完整 → ERROR；已消失 = 合法 race → 跳过**，与 M9a 同一模型。
    [ -d /proc ] && [ -r /proc ] || { kb_die "/proc 不可读 —— 无法判断 $dev 是否已挂载"; return 1; }
    files=""
    for mi in /proc/[0-9]*/mountinfo; do
        [ -e "$mi" ] || continue
        files="${files}${mi}${KB_NL}"
    done
    [ -n "$files" ] || { kb_die "没有扫到任何 /proc/<PID>/mountinfo —— 证据不可信"; return 1; }

    KB_RUN_IN=$files
    kb_parse "跨 namespace 扫描 mountinfo" any awk -v mm="$KB_MAJMIN" '
        {
            f=$0; scanned++
            while ((r = (getline line < f)) > 0) {
                split(line, a, " ")
                if (a[3] == mm) print "HIT\t" f "\t" a[5]
            }
            if (r < 0) print "UNREAD\t" f
            close(f)
        }
        END { printf "#SCANNED=%d\n", scanned }' || return 1
    KB_SCAN_RAW=$KB_PARSE_OUT

    kb_parse_str "取扫描进程数" number "$KB_SCAN_RAW" \
        awk -F'=' '/^#SCANNED=/{print $2}' || { kb_die "扫描未产出统计行 —— 结果不可信"; return 1; }
    scanned=$KB_PARSE_OUT
    [ "$scanned" -gt 0 ] || { kb_die "扫描进程数为 0 —— 证据不可信"; return 1; }

    # 读取失败的文件：仍存在 = 扫描不完整（ERROR）；已消失 = 进程退出的合法 race
    kb_parse_str "取读取失败清单" any "$KB_SCAN_RAW" awk -F'\t' '$1=="UNREAD"{print $2}' || return 1
    unread_list=$KB_PARSE_OUT
    parsefail=0
    if [ -n "$unread_list" ]; then
        for f in $unread_list; do
            [ -e "$f" ] && parsefail=$(( parsefail + 1 ))
        done
    fi
    [ "$parsefail" -eq 0 ] \
        || { kb_die "有 $parsefail 个仍存在的 mountinfo 读取失败 —— 扫描不完整，无法证明 $dev 未挂载"; return 1; }

    kb_parse_str "取挂载命中" any "$KB_SCAN_RAW" awk -F'\t' '$1=="HIT"{print $2" "$3}' || return 1
    hit=$KB_PARSE_OUT
    if [ -n "$hit" ]; then
        printf '%s\n' "$hit" | head -5 | sed 's/^/    /'
        kb_die "$dev（$KB_MAJMIN）已挂载（可能在其它 mount namespace 中）"; return 1
    fi
    echo "  OK $dev（$KB_MAJMIN）在全部 $scanned 个进程的 mountinfo 中均未出现（读取全部成功）"
    return 0
}

# M0c mountpoint 三态
#     mountpoint(1)：0 = 是挂载点；32 = 不是挂载点；1 = 权限/系统错误/调用错误
#     返回 0 = 是挂载点 / 1 = 不是 / 2 = ERROR（不得与"不是"混为一谈）
kb_is_mountpoint(){
    local d=$1
    kb_run "mountpoint $d" mountpoint -q "$d" || return 2
    case "$KB_RUN_RC" in
      0)  return 0 ;;
      32) return 1 ;;
      *)  echo "  [mountpoint $d] rc=$KB_RUN_RC $(kb_run_err1)"; return 2 ;;
    esac
}

# ------------------------------------------------------------------
# M1 设备身份：存在 / 是块设备 / 未挂在别处 / FSTYPE / UUID 非空
# ------------------------------------------------------------------
kb_dev_ready(){
    local dev=$1 want=${2:-xfs} fstype uuid
    [ -b "$dev" ] || { kb_die "$dev 不存在或不是块设备"; return 1; }
    kb_dev_unmounted "$dev" || return 1
    # ★ v1.8：此前是 kb_run + 只看输出值 —— blkid 输出 "xfs" 但 rc≠0 时照样通过，
    #   违反第一原则"命令没跑成，不得因为输出碰巧像正确答案而 PASS"。
    kb_parse "取 $dev 的 FSTYPE" single blkid -s TYPE -o value "$dev" || return 1
    fstype=$KB_PARSE_OUT
    [ "$fstype" = "$want" ] || { kb_die "$dev FSTYPE=$fstype，预期 $want"; return 1; }
    kb_parse "取 $dev 的 UUID" single blkid -s UUID -o value "$dev" || return 1
    uuid=$KB_PARSE_OUT
    KB_DEV_UUID=$uuid
    echo "  OK 设备就绪 $dev  FSTYPE=$fstype  UUID=$uuid"
}

# ------------------------------------------------------------------
# M2 容量：实际字节数 >= 0b.1 规划值；给出源目录时再要求 >= 源用量 x1.2
# ------------------------------------------------------------------
kb_dev_capacity(){
    local dev=$1 plan=$2 src=${3:-} actual need used
    case "$plan" in ''|*[!0-9]*) kb_die "规划容量未填或非数字（见 0b.1）"; return 1;; esac
    kb_parse "取 $dev 容量" number blockdev --getsize64 "$dev" || return 1
    actual=$KB_PARSE_OUT
    [ "$actual" -ge "$plan" ] || { kb_die "实际容量 ${actual}B 小于 0b.1 规划 ${plan}B —— LV 建小了"; return 1; }
    if [ -n "$src" ]; then
        kb_run "du -sb $src" du -sb "$src" || return 1
        [ "$KB_RUN_RC" -eq 0 ] || { kb_die "统计 $src 用量失败（rc=$KB_RUN_RC $(kb_run_err1)）"; return 1; }
        # ★ v1.6：这一层解析此前是裸 awk —— parser 半途失败可能吐出一个偏小的数字，
        #   据此算出的 "用量×1.2" 会让一块偏小的卷通过附加容量门
        kb_parse_str "解析 du 输出" number "$KB_RUN_OUT" awk '{print $1}' || return 1
        used=$KB_PARSE_OUT
        need=$(( used * 12 / 10 ))
        [ "$actual" -ge "$need" ] || { kb_die "实际容量 ${actual}B 小于现有用量x1.2=${need}B"; return 1; }
    fi
    KB_DEV_BYTES=$actual
    echo "  OK 容量 实际=${actual}B >= 规划=${plan}B"
}

# ------------------------------------------------------------------
# M3 fstab：同一挂载点的活动行必须 0 或 1 条；为 1 条时设备必须是预期 UUID
#     第三参数 forbid_nofail=yes 时，额外断言挂载选项不含 nofail
#     ★ v1.6：扫描、计数、取设备字段、取选项字段 —— **四层全部受控**。
#       此前只判了第一层扫描的 awk；实测：fstab 行确实含 nofail，只让取 $4 的 awk 失败，
#       opts 变空 → case 不匹配 → **真实的 nofail 被解析没了并 PASS**。
# ------------------------------------------------------------------
kb_fstab_check(){
    local target=$1 uuid=$2 forbid=${3:-no} n line first opts
    [ -r /etc/fstab ] || { kb_die "读不到 /etc/fstab"; return 1; }
    kb_parse "扫描 fstab" any awk -v t="$target" '$0 !~ /^[[:space:]]*#/ && NF>=2 && $2==t' /etc/fstab || return 1
    line=$KB_PARSE_OUT
    if [ -z "$line" ]; then
        n=0
    else
        kb_parse_str "统计 fstab 活动行数" number "$line" awk 'END{print NR}' || return 1
        n=$KB_PARSE_OUT
    fi
    [ "$n" -le 1 ] || { kb_die "/etc/fstab 中挂载点 $target 有 $n 条活动行 —— mount 只用第一条"; return 1; }
    if [ "$n" -eq 1 ]; then
        kb_parse_str "取 fstab 设备字段" single "$line" awk '{print $1}' || return 1
        first=$KB_PARSE_OUT
        [ "$first" = "UUID=$uuid" ] || { kb_die "fstab 现有行设备为 $first，预期 UUID=$uuid"; return 1; }
        kb_parse_str "取 fstab 挂载选项" single "$line" awk '{print $4}' || return 1
        opts=$KB_PARSE_OUT
        if [ "$forbid" = yes ]; then
            case ",$opts," in *,nofail,*) kb_die "该挂载点不得含 nofail：$line"; return 1;; esac
        fi
        echo "  OK fstab 已有 1 条正确条目：$line"
    else
        echo "  OK fstab 尚无 $target 条目（扫描成功且无匹配），将由 kb_fstab_add 追加"
    fi
    KB_FSTAB_N=$n
}

# M4 追加 fstab（仅当 kb_fstab_check 判定为 0 条时调用）
kb_fstab_add(){
    local target=$1 uuid=$2 fs=${3:-xfs}
    [ -n "$uuid" ] || { kb_die "UUID 为空，拒绝写入 fstab"; return 1; }
    printf 'UUID=%s  %s  %s  defaults  0 0\n' "$uuid" "$target" "$fs" >> /etc/fstab \
        || { kb_die "写入 /etc/fstab 失败"; return 1; }
    echo "  OK 已追加：UUID=$uuid  $target  $fs  defaults  0 0"
}

# M3b 解析挂载选项并断言不含 nofail（2.10 等验收处共用）
#     用法：kb_opts_no_nofail <挂载点>
kb_opts_no_nofail(){
    local target=$1 opts
    kb_parse "取 $target 的挂载选项" single findmnt -no OPTIONS -T "$target" || return 1
    kb_parse_str "整理挂载选项" nonempty "$KB_PARSE_OUT" tr -d '[:space:]' || return 1
    opts=$KB_PARSE_OUT
    case ",$opts," in
      *,nofail,*) kb_die "$target 的挂载选项含 nofail —— 域② 禁止"; return 1 ;;
    esac
    echo "  OK $target 挂载选项不含 nofail（opts=$opts）"
}

# ------------------------------------------------------------------
# M5 挂载并验证"挂上的确实是那一块"
# ------------------------------------------------------------------
kb_mount_verify(){
    local target=$1 uuid=$2 src got
    mount "$target" || { kb_die "挂载 $target 失败"; return 1; }
    kb_is_mountpoint "$target"
    case $? in
      0) : ;;
      1) kb_die "$target 不是挂载点"; return 1 ;;
      *) kb_die "无法判定 $target 是否为挂载点（证据缺失）"; return 1 ;;
    esac
    kb_parse "取 $target 的挂载来源" single findmnt -no SOURCE -T "$target" || return 1
    src=$KB_PARSE_OUT
    kb_parse "取 $src 的 UUID" single blkid -s UUID -o value "$src" || return 1
    got=$KB_PARSE_OUT
    [ "$got" = "$uuid" ] || { kb_die "$target 实际挂的是 $src(UUID=$got)，预期 UUID=$uuid —— 挂错卷"; return 1; }
    echo "  OK $target 已挂载 SOURCE=$src UUID=$got（与预期一致）"
}

# ------------------------------------------------------------------
# M6 复制与校验；mode=delete 时目标端多余文件也算差异
# ------------------------------------------------------------------
kb_rsync_sync(){
    local src=$1 dst=$2 mode=${3:-nodelete} opt=""
    [ "$mode" = delete ] && opt="--delete"
    rsync -aHAX --numeric-ids $opt "$src" "$dst" || { kb_die "rsync 复制失败 src=$src dst=$dst"; return 1; }
    echo "  OK 复制完成 $src -> $dst"
}
kb_rsync_verify(){
    local src=$1 dst=$2 mode=${3:-nodelete} opt="" out
    [ "$mode" = delete ] && opt="--delete"
    out=$(mktemp 2>/dev/null) || { kb_die "mktemp 失败，无法校验"; return 1; }
    if ! rsync -aHAX --numeric-ids $opt --dry-run --itemize-changes "$src" "$dst" >"$out"; then
        rm -f "$out"; kb_die "rsync 校验命令未跑成（这是 ERROR，不是「无差异」）"; return 1
    fi
    if [ -s "$out" ]; then
        echo "  差异明细："; cat "$out"; rm -f "$out"
        kb_die "$src 与 $dst 内容不一致"; return 1
    fi
    rm -f "$out"
    echo "  OK 内容一致（口径：${mode}）"
}

# ------------------------------------------------------------------
# M6b 目录条目枚举 —— find 与计数两层都受控
# ------------------------------------------------------------------
kb_enum_entries(){
    local dir=$1 depth=${2:-0} lst errf rc
    lst=$(mktemp 2>/dev/null) || { kb_die "mktemp 失败，无法枚举 $dir"; return 1; }
    errf=$(mktemp 2>/dev/null) || { rm -f "$lst"; kb_die "mktemp 失败，无法枚举 $dir"; return 1; }
    if [ "$depth" -gt 0 ]; then
        find "$dir" -xdev -mindepth 1 -maxdepth "$depth" -printf '%y\t%s\t%P\n' >"$lst" 2>"$errf"; rc=$?
    else
        find "$dir" -xdev -mindepth 1 -printf '%y\t%s\t%P\n' >"$lst" 2>"$errf"; rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        kb_run "读取 find 错误输出" head -2 "$errf"
        echo "  find stderr：$KB_RUN_OUT"
        rm -f "$lst" "$errf"
        kb_die "遍历 $dir 失败（rc=$rc）—— 无法判断是否为空（证据采集失败 ≠ 没有数据）"; return 1
    fi
    rm -f "$errf"
    # ★ v1.7：删掉 wc 分支。`wc -l <文件>` 的输出是 "N 文件名"，在 number 形态下**必然先失败**，
    #   于是正常路径也会先打印一行 STOP、再走 fallback —— 函数返回 0 却留下 STOP 日志，
    #   会污染现场判断、自动日志采集与签字证据。这里根本不需要 fallback。
    kb_parse "统计 $dir 条目数" number awk 'END{print NR}' "$lst" || { rm -f "$lst"; return 1; }
    KB_ENUM_N=$KB_PARSE_OUT
    case "$KB_ENUM_N" in
      ''|*[!0-9]*) rm -f "$lst"; kb_die "$dir 的条目数不是有效数字：'$KB_ENUM_N'"; return 1 ;;
    esac
    KB_ENUM_LIST=$lst
}

# ------------------------------------------------------------------
# M6c 元数据快照 + 比较
# ------------------------------------------------------------------
kb_meta_snapshot(){
    local dir=$1 out=$2 errf rc
    errf=$(mktemp 2>/dev/null) || { kb_die "mktemp 失败"; return 1; }
    ( cd "$dir" 2>/dev/null && find . -printf '%p %u:%g %m\n' ) >"$out" 2>"$errf"; rc=$?
    if [ "$rc" -ne 0 ]; then
        kb_run "读取采集错误输出" head -2 "$errf"; echo "  采集 stderr：$KB_RUN_OUT"; rm -f "$errf"
        kb_die "采集 $dir 的属主/权限清单失败（rc=$rc）"; return 1
    fi
    rm -f "$errf"
    [ -s "$out" ] || { kb_die "采集 $dir 的清单为空 —— 目录不存在或不可读，证据不可信"; return 1; }
    sort -o "$out" "$out" || { kb_die "排序 $out 失败"; return 1; }
    kb_parse "统计清单行数" number awk 'END{print NR}' "$out" || return 1
    echo "  OK 已采集 $dir 的清单（$KB_PARSE_OUT 行）"
}
kb_files_equal(){
    local a=$1 b=$2 what=${3:-清单}
    [ -s "$a" ] && [ -s "$b" ] || { kb_die "$what 比较的两侧至少一侧为空 —— 采集未成功，不得据此判定一致"; return 1; }
    diff "$a" "$b" || { kb_die "$what 不一致（见上方 diff）"; return 1; }
    echo "  OK $what 一致"
}

# ------------------------------------------------------------------
# M6d xattr / ACL 快照 —— 带 sentinel 首行
#     "没有扩展属性"是合法状态、输出天然为空；sentinel 让"采集成功且集合为空"仍产出非空文件，
#     于是 kb_files_equal 的铁律无需开例外。
# ------------------------------------------------------------------
kb_xattr_snapshot(){
    local dir=$1 out=$2 errf rc
    command -v getfattr >/dev/null 2>&1 || { kb_die "缺少 getfattr（attr 包）"; return 1; }
    errf=$(mktemp 2>/dev/null) || { kb_die "mktemp 失败"; return 1; }
    { echo '# KB_XATTR_SNAPSHOT_V1'; ( cd "$dir" 2>/dev/null && getfattr -Rd -m- . ); } >"$out" 2>"$errf"; rc=$?
    if [ "$rc" -ne 0 ]; then
        kb_run "读取采集错误输出" head -2 "$errf"; echo "  采集 stderr：$KB_RUN_OUT"; rm -f "$errf"
        kb_die "采集 $dir 的 xattr 失败（rc=$rc）"; return 1
    fi
    rm -f "$errf"
    kb_parse "统计 xattr 行数" number awk 'END{print NR-1}' "$out" || return 1
    echo "  OK 已采集 $dir 的 xattr（$KB_PARSE_OUT 行，0 行表示无扩展属性，属合法状态）"
}
kb_acl_snapshot(){
    local dir=$1 out=$2 errf rc
    command -v getfacl >/dev/null 2>&1 || { kb_die "缺少 getfacl（acl 包）"; return 1; }
    errf=$(mktemp 2>/dev/null) || { kb_die "mktemp 失败"; return 1; }
    { echo '# KB_ACL_SNAPSHOT_V1'; ( cd "$dir" 2>/dev/null && getfacl -R . ); } >"$out" 2>"$errf"; rc=$?
    if [ "$rc" -ne 0 ]; then
        kb_run "读取采集错误输出" head -2 "$errf"; echo "  采集 stderr：$KB_RUN_OUT"; rm -f "$errf"
        kb_die "采集 $dir 的 ACL 失败（rc=$rc）"; return 1
    fi
    rm -f "$errf"
    kb_parse "统计 ACL 行数" number awk 'END{print NR-1}' "$out" || return 1
    echo "  OK 已采集 $dir 的 ACL（$KB_PARSE_OUT 行）"
}

# ------------------------------------------------------------------
# M7 卸载并验证 —— 主路径用
# ------------------------------------------------------------------
kb_umount_verify(){
    local target=$1
    umount "$target" || { kb_die "卸载 $target 失败（有进程持有？）"; return 1; }
    kb_is_mountpoint "$target"
    case $? in
      1) echo "  OK $target 已卸载" ;;
      0) kb_die "$target 仍是挂载点"; return 1 ;;
      *) kb_die "卸载后无法判定 $target 状态（证据缺失）"; return 1 ;;
    esac
}

# ------------------------------------------------------------------
# M7b 幂等卸载 —— 回退路径专用
#     未挂载 = 已达成终态；只有"仍挂载且卸不掉"才是失败。**不自动 umount -l**。
# ------------------------------------------------------------------
kb_umount_idempotent(){
    local target=$1
    kb_is_mountpoint "$target"
    case $? in
      1) echo "  OK $target 本就未挂载（回退终态已达成）"; return 0 ;;
      0) : ;;
      *) kb_die "无法判定 $target 是否为挂载点 —— 禁止在状态不明时继续回退"; return 1 ;;
    esac
    if ! umount "$target"; then
        command -v fuser >/dev/null 2>&1 && fuser -vm "$target" 2>&1 | head -20
        kb_die "$target 正常卸载失败（EBUSY?）—— 禁止继续；请先清掉持有者，不要用 umount -l 绕过"
        return 1
    fi
    kb_is_mountpoint "$target"
    case $? in
      1) echo "  OK $target 已卸载" ;;
      *) kb_die "$target 卸载后仍是挂载点或状态不明"; return 1 ;;
    esac
}

# ------------------------------------------------------------------
# M8a 文件系统"日志干净"的【正面证据】
#     xfs ：xfs_repair -n，**rc 一律按"非 0 即不干净"处理**，不依赖 1/2 的具体语义
#     ext ：dumpe2fs -h 的 Filesystem state 必须是 clean
#     ★ v1.6：ext 分支的 **sed 解析也受控** —— 此前只判了 dumpe2fs 的 rc；
#       实测"dumpe2fs rc=0、sed 输出 clean 后返回 rc=2"时，函数返回 0 并打印 OK（完整假 PASS）。
# ------------------------------------------------------------------
kb_fs_clean(){
    local dev=$1 fstype=$2 state
    case "$fstype" in
      xfs)
        command -v xfs_repair >/dev/null 2>&1 \
            || { kb_die "缺少 xfs_repair，无法取得 XFS 日志干净的正面证据（xfsprogs）"; return 1; }
        kb_run "xfs_repair -n" xfs_repair -n "$dev" || return 1
        printf '%s\n%s\n' "$KB_RUN_OUT" "$KB_RUN_ERR" | tail -5 | sed 's/^/    /'
        if [ "$KB_RUN_RC" -ne 0 ]; then
            if printf '%s%s' "$KB_RUN_OUT" "$KB_RUN_ERR" | grep -qiE 'dirty log|needs to be replayed|valuable metadata'; then
                kb_die "XFS 日志未回放（xfs_repair -n rc=$KB_RUN_RC）—— 内容不可判定，不得当作空盘"
            else
                kb_die "xfs_repair -n rc=$KB_RUN_RC —— 文件系统不干净或检查未完成，一律阻断"
            fi
            return 1
        fi
        echo "  OK XFS 一致性检查通过（xfs_repair -n rc=0）"
        ;;
      ext4|ext3)
        command -v dumpe2fs >/dev/null 2>&1 \
            || { kb_die "缺少 dumpe2fs，无法判定 ext 文件系统是否 clean（e2fsprogs）"; return 1; }
        kb_run "dumpe2fs -h" dumpe2fs -h "$dev" || return 1
        [ "$KB_RUN_RC" -eq 0 ] \
            || { echo "  dumpe2fs stderr：$(kb_run_err1)"; kb_die "dumpe2fs 检查失败（rc=$KB_RUN_RC）—— 内容不可判定"; return 1; }
        kb_parse_str "解析 Filesystem state" single "$KB_RUN_OUT" \
            sed -n 's/^Filesystem state:[[:space:]]*//p' || return 1
        state=$KB_PARSE_OUT
        echo "  ext Filesystem state：$state"
        case "$state" in
          clean) echo "  OK ext 文件系统 clean" ;;
          *)     kb_die "ext 文件系统状态为 '$state'（非 clean）—— 内容不可判定，不得当作空盘"; return 1 ;;
        esac
        ;;
      *) kb_die "未支持的文件系统类型：$fstype"; return 1 ;;
    esac
}

# ------------------------------------------------------------------
# M8 安全只读检查 —— 在 mkfs 之前判断"盘上有没有别人的数据"
#     KB_RO_ENTRIES（全部条目数）是 EMPTY 的唯一主判据；FILES / BYTES 为辅助证据
#     证据文件只是审计与比对基准，**不构成 mkfs 授权** —— 授权见 M11
# ------------------------------------------------------------------
KB_RO_EVIDENCE=${KB_RO_EVIDENCE:-/root/kb_ro_evidence.env}

kb_ro_inspect(){
    local dev=$1 mnt=$2 log=$3 fstype opts src uuid

    unset KB_RO_VERDICT KB_RO_ENTRIES KB_RO_FILES KB_RO_BYTES
    if [ -e "$KB_RO_EVIDENCE" ]; then
        mv -f "$KB_RO_EVIDENCE" "${KB_RO_EVIDENCE}.superseded.$(date +%s)" 2>/dev/null \
            || rm -f "$KB_RO_EVIDENCE"
        echo "  旧证据已作废（本次成功后才会重新生成）"
    fi

    [ -b "$dev" ] || { kb_die "$dev 不存在或不是块设备"; return 1; }
    kb_run "blkid TYPE" blkid -s TYPE -o value "$dev" || return 1
    [ "$KB_RUN_RC" -eq 0 ] || { kb_die "blkid 探测 $dev 失败（rc=$KB_RUN_RC $(kb_run_err1)）—— 不得据此断定为空"; return 1; }
    fstype=$KB_RUN_OUT
    case "$fstype" in
      xfs)        opts="ro,norecovery" ;;
      ext4|ext3)  opts="ro,noload" ;;
      "")         kb_die "$dev 上未探测到文件系统（blkid 无输出）—— 不得据此断定为空"; return 1 ;;
      *)          kb_die "未支持的文件系统类型：$fstype，停止自动处置"; return 1 ;;
    esac
    kb_parse "取 $dev 的 UUID" single blkid -s UUID -o value "$dev" || return 1
    uuid=$KB_PARSE_OUT
    kb_dev_unmounted "$dev" || return 1

    # ★ 先取"日志干净"的正面证据，再去看内容 —— 顺序不能反
    kb_fs_clean "$dev" "$fstype" || { KB_RO_VERDICT=INDETERMINATE; return 1; }

    mkdir -p "$mnt"
    kb_is_mountpoint "$mnt"
    case $? in
      0) kb_die "$mnt 已被占用，先清理"; return 1 ;;
      1) : ;;
      *) kb_die "无法判定 $mnt 状态，拒绝挂载"; return 1 ;;
    esac
    mount -o "$opts" "$dev" "$mnt" \
        || { kb_die "只读挂载 $dev 失败 —— 禁止把未挂载的空目录当成「盘上没东西」"; return 1; }
    kb_is_mountpoint "$mnt"
    case $? in
      0) : ;;
      *) kb_die "$mnt 不是挂载点或状态不明"; return 1 ;;
    esac
    kb_parse "取 $mnt 的挂载来源" single findmnt -no SOURCE -T "$mnt" || { kb_umount_idempotent "$mnt"; return 1; }
    src=$KB_PARSE_OUT
    kb_same_dev "$src" "$dev" \
        || { kb_umount_idempotent "$mnt"; kb_die "$mnt 实际来源是 $src，与预期 $dev 不是同一块设备"; return 1; }

    kb_enum_entries "$mnt" || { kb_umount_idempotent "$mnt"; return 1; }
    KB_RO_ENTRIES=$KB_ENUM_N
    kb_parse "统计普通文件数" number awk -F'\t' 'BEGIN{n=0} $1=="f"{n++} END{print n}' "$KB_ENUM_LIST" \
        || { rm -f "$KB_ENUM_LIST"; kb_umount_idempotent "$mnt"; return 1; }
    KB_RO_FILES=$KB_PARSE_OUT
    kb_parse "统计字节合计" number awk -F'\t' '$1=="f"{s+=$2} END{printf "%d\n", s+0}' "$KB_ENUM_LIST" \
        || { rm -f "$KB_ENUM_LIST"; kb_umount_idempotent "$mnt"; return 1; }
    KB_RO_BYTES=$KB_PARSE_OUT
    { echo "== kb_ro_inspect $(date -Is) dev=$dev fstype=$fstype uuid=$uuid"; cat "$KB_ENUM_LIST"; } > "$log" 2>&1
    rm -f "$KB_ENUM_LIST"
    echo "  条目数=$KB_RO_ENTRIES  普通文件=$KB_RO_FILES  字节=$KB_RO_BYTES  留证=$log"

    if [ "$KB_RO_ENTRIES" -eq 0 ]; then KB_RO_VERDICT=EMPTY; else KB_RO_VERDICT=NONEMPTY; fi
    kb_umount_idempotent "$mnt" || return 1

    umask 077
    # ★ v1.7：写入失败不得再打印 OK
    if ! cat > "$KB_RO_EVIDENCE" <<EOF
KB_RO_DEV="$dev"
KB_RO_UUID="$uuid"
KB_RO_FSTYPE="$fstype"
KB_RO_EPOCH="$(date +%s)"
KB_RO_WHEN="$(date -Is)"
KB_RO_VERDICT="$KB_RO_VERDICT"
KB_RO_ENTRIES="$KB_RO_ENTRIES"
KB_RO_FILES="$KB_RO_FILES"
KB_RO_BYTES="$KB_RO_BYTES"
KB_RO_LOG="$log"
EOF
    then
        kb_die "写入证据文件 $KB_RO_EVIDENCE 失败 —— 本次只读检查不得记为完成"; return 1
    fi
    [ -s "$KB_RO_EVIDENCE" ] || { kb_die "证据文件为空 —— 写入未完成"; return 1; }
    echo "  OK 只读检查结束：VERDICT=$KB_RO_VERDICT  证据=$KB_RO_EVIDENCE"
    echo "  ⚠️ 证据仅供审计与比对；mkfs 授权必须由 M11 在同一执行块内即时复验"
}

# ------------------------------------------------------------------
# M11 破坏性操作授权 —— 【即时复验 + 与历史证据比对】
#     授权依据是本次即时枚举；历史证据只作比对基准（UUID 不会因写入文件而变化）
# ------------------------------------------------------------------
kb_ro_evidence_ok(){
    local dev=$1 mnt=${2:-/mnt/kb-recheck} maxage=${3:-3600}
    local now age uuid_now fstype opts src n_now
    [ -r "$KB_RO_EVIDENCE" ] || { kb_die "找不到只读检查证据 $KB_RO_EVIDENCE —— 未执行 kb_ro_inspect"; return 1; }
    . "$KB_RO_EVIDENCE"
    kb_same_dev "${KB_RO_DEV:-}" "$dev" || { kb_die "证据记录的设备是 ${KB_RO_DEV:-(空)}，本次要操作的是 $dev"; return 1; }
    kb_parse "取 $dev 的 UUID" single blkid -s UUID -o value "$dev" || return 1
    uuid_now=$KB_PARSE_OUT
    [ "$uuid_now" = "${KB_RO_UUID:-}" ] \
        || { kb_die "设备 UUID 已变化（证据 ${KB_RO_UUID:-(空)} → 现在 ${uuid_now:-(空)}）"; return 1; }
    now=$(date +%s); age=$(( now - ${KB_RO_EPOCH:-0} ))
    [ "$age" -ge 0 ] && [ "$age" -le "$maxage" ] || { kb_die "证据已过期（${age}s > ${maxage}s，采集于 ${KB_RO_WHEN:-?}）"; return 1; }
    [ "${KB_RO_VERDICT:-}" = EMPTY ] || { kb_die "证据判定为 ${KB_RO_VERDICT:-(空)}，只有 EMPTY 才允许破坏性操作"; return 1; }
    [ "${KB_RO_ENTRIES:-}" = 0 ] || { kb_die "证据条目数为 ${KB_RO_ENTRIES:-(空)}，不是空盘"; return 1; }

    fstype=${KB_RO_FSTYPE:-}
    [ -n "$fstype" ] || { kb_die "证据中缺 FSTYPE"; return 1; }
    case "$fstype" in
      xfs)        opts="ro,norecovery" ;;
      ext4|ext3)  opts="ro,noload" ;;
      *)          kb_die "未支持的文件系统类型：$fstype"; return 1 ;;
    esac
    kb_dev_unmounted "$dev" || return 1
    kb_fs_clean "$dev" "$fstype" || return 1

    mkdir -p "$mnt"
    kb_is_mountpoint "$mnt"
    case $? in
      0) kb_die "$mnt 已被占用，先清理"; return 1 ;;
      1) : ;;
      *) kb_die "无法判定 $mnt 状态，拒绝挂载"; return 1 ;;
    esac
    mount -o "$opts" "$dev" "$mnt" || { kb_die "即时复验：只读挂载 $dev 失败"; return 1; }
    kb_is_mountpoint "$mnt"
    case $? in
      0) : ;;
      *) kb_die "即时复验：$mnt 不是挂载点或状态不明"; return 1 ;;
    esac
    kb_parse "取 $mnt 的挂载来源" single findmnt -no SOURCE -T "$mnt" || { kb_umount_idempotent "$mnt"; return 1; }
    src=$KB_PARSE_OUT
    kb_same_dev "$src" "$dev" || { kb_umount_idempotent "$mnt"; kb_die "即时复验：$mnt 来源 $src 与 $dev 不是同一块设备"; return 1; }

    if ! kb_enum_entries "$mnt"; then kb_umount_idempotent "$mnt"; return 1; fi
    n_now=$KB_ENUM_N
    if [ "$n_now" -ne 0 ]; then
        echo "  本次枚举到的条目："; head -20 "$KB_ENUM_LIST" | sed 's/^/    /'
    fi
    rm -f "$KB_ENUM_LIST"
    kb_umount_idempotent "$mnt" || return 1

    [ "$n_now" -eq 0 ] || { kb_die "即时复验：设备上现在有 $n_now 个条目（证据记录为 ${KB_RO_ENTRIES}）—— 期间有人写入过，禁止破坏性操作"; return 1; }
    [ "$n_now" = "${KB_RO_ENTRIES}" ] || { kb_die "即时复验结果($n_now)与证据(${KB_RO_ENTRIES})不一致"; return 1; }

    echo "  OK 授权通过：$dev 证据(${KB_RO_WHEN}，${age}s 前) + 本次即时复验，条目数均为 0"
}

# ------------------------------------------------------------------
# M9a 进程引用枚举：谁在引用这块设备 / 这个文件系统
#     返回 0 = 扫描完整且【找到】引用者（明细在 KB_HOLDERS）
#          1 = 扫描完整且【没有】引用者
#          2 = **扫描不完整** → ERROR
#     输出：KB_HOLDERS / KB_MMAP_COVERED（yes|no）/ KB_MMAP_UNREAD（不可读的进程数）
#
# ★★ v1.9 扩展（上一版的 P0）：v1.8 只遍历 /proc/<PID>/fd/*，
#    **cwd / root / exe / mmap 这四类引用完全没查**，而它们是与 fd 并列的持有形式
#    （fuser 自己就把访问类型分成 c=cwd / r=root / e=exe / m=mmap / f=fd）。
#    实测：起一个 cwd 位于目标文件系统、但不打开其中任何 fd 的进程 →
#    仅扫 fd 得 found=0（"无人持有"），而扫 cwd 立刻命中。
#
#    ⚠️ 为什么这在 mkfs 前是要命的：正常 umount 会因 cwd 而 EBUSY，挡得住；
#       但 **umount -l（懒卸载）是例外** —— 它立刻把挂载从 mountinfo 摘掉，
#       底层引用要等不再 busy 才真正清理。于是存在这条组合路径：
#         曾执行 umount -l → M1b 在 mountinfo 里看不到挂载（PASS）
#         → M9a 只扫 fd 也看不到（PASS）→ fuser/lsof 只是可选佐证
#         → "已完全释放" → 进入 mkfs 前置链
#
#    ★ 覆盖范围的取舍（诚实说明，不做成"看起来全覆盖"）：
#      · fd/* + cwd + root + exe → **硬覆盖**：都是单次 stat，开销可忽略，
#        权限要求与 fd 相同（能读 /proc/<PID>/fd 就能读这三个）。
#      · map_files/* → **尽力而为**：读取它需要 PTRACE_MODE_READ，
#        实测非 root 读 /proc/1/map_files 直接失败（rc=2）。
#        若做成硬门，在现场最可能的【非 root 执行】场景下会把整道门焊死，
#        反而逼现场绕过。因此：能读就查；读不了**如实记为覆盖缺口**，
#        由调用方（M9）决定是否接受该残余风险，而不是在这里假装查过。
# ------------------------------------------------------------------
kb_dev_holders(){
    local dev=$1 pid obj mm found=0 unreadable=0 statfail=0 scanned=0
    local mmap_unread=0 mmap_failed=0 mf
    kb_dev_majmin "$dev" || { kb_die "取不到 $dev 的 major:minor"; return 2; }
    KB_HOLDERS=""; KB_MMAP_COVERED=yes; KB_MMAP_UNREAD=0; KB_MMAP_FAILED=0
    [ -d /proc ] && [ -r /proc ] || { kb_die "/proc 不可读 —— 无法枚举引用者"; return 2; }
    for pid in /proc/[0-9]*; do
        [ -d "$pid" ] || continue
        scanned=$(( scanned + 1 ))

        # ① fd/*：st_dev 命中 = 该文件系统内的普通文件；st_rdev 命中 = 直接打开设备文件
        if [ ! -r "$pid/fd" ]; then
            [ -d "$pid/fd" ] && unreadable=$(( unreadable + 1 ))
        else
            for obj in "$pid"/fd/*; do
                # ★★ v1.11（v1.10 的 P0）：用 -L 而不是 -e。
                #   `/proc/<PID>/fd/*` 是特殊 symlink，**`test -e` 会跟随它**；
                #   跟不动（ptrace/权限受限）时 `-e` 自己就先返回 false，于是直接 continue，
                #   **根本到不了后面新加的"取证失败"计数** —— 漏洞从"stat 之后"前移到了"stat 之前"。
                #   实测（nobody 看 root 进程）：-L=true、-e=false、stat -L=Permission denied。
                [ -L "$obj" ] || continue
                mm=$(kb_proc_ref_devnums "$obj"); case $? in
                  0) : ;;
                  1) statfail=$(( statfail + 1 )); continue ;;   # 有目标却取不到设备号 = 取证不完整
                  *) continue ;;                                  # 无可解析目标 = race / 内核线程
                esac
                if [ "${mm%% *}" = "$KB_RDEV" ] || [ "${mm##* }" = "$KB_RDEV" ]; then
                    KB_HOLDERS="${KB_HOLDERS}${pid#/proc/} fd -> $(readlink "$obj" 2>/dev/null)
"
                    found=1
                fi
            done
        fi

        # ② cwd / root / exe：与 fd 同等硬覆盖
        for obj in cwd root exe; do
            [ -L "$pid/$obj" ] || continue          # ★ v1.11：同上，不能用 -e
            mm=$(kb_proc_ref_devnums "$pid/$obj"); case $? in
              0) : ;;
              1) statfail=$(( statfail + 1 )); continue ;;
              *) continue ;;
            esac
            if [ "${mm%% *}" = "$KB_RDEV" ] || [ "${mm##* }" = "$KB_RDEV" ]; then
                KB_HOLDERS="${KB_HOLDERS}${pid#/proc/} $obj -> $(readlink "$pid/$obj" 2>/dev/null)
"
                found=1
            fi
        done

        # ③ map_files/*：尽力而为；**但"尽力"不等于"失败可以当没发生"**
        #    ★★ v1.10 修正（v1.9 的 P0）：此前只有【整个目录不可读】才计入 mmap_unread，
        #    单个 map_files/* 取证失败只是一句 `continue` —— 既不计数、也不影响 KB_MMAP_COVERED。
        #    实测：让 fd/cwd/root/exe 全部正常、**只让所有 map_files/* 的 stat 失败** →
        #    函数仍打印"map_files 全部可读，mmap 引用亦已覆盖"、COVERED=yes、MMAP_UNREAD=0，
        #    随后 destroy 模式据此认为无需人工确认 —— **完整假 PASS**。
        #    根因是同一个函数里用了两套失败模型：fd 已经用"对象仍存在 = 扫描不完整"，
        #    而 map_files 还停在旧的 `|| continue`。本版统一到同一模型（统一由 kb_proc_ref_devnums 取证）。
        if [ -d "$pid/map_files" ]; then
            if [ ! -r "$pid/map_files" ]; then
                mmap_unread=$(( mmap_unread + 1 ))
            else
                for mf in "$pid"/map_files/*; do
                    [ -L "$mf" ] || continue        # ★ v1.11：同上，不能用 -e
                    mm=$(kb_proc_ref_devnums "$mf"); case $? in
                      0) : ;;
                      1) mmap_failed=$(( mmap_failed + 1 )); continue ;;   # 映射仍可解析却取不到设备号
                      *) continue ;;                                       # 映射已消失
                    esac
                    if [ "${mm%% *}" = "$KB_RDEV" ] || [ "${mm##* }" = "$KB_RDEV" ]; then
                        KB_HOLDERS="${KB_HOLDERS}${pid#/proc/} mmap -> $(readlink "$mf" 2>/dev/null)
"
                        found=1
                    fi
                done
            fi
        fi
    done

    KB_MMAP_UNREAD=$mmap_unread
    KB_MMAP_FAILED=$mmap_failed
    # ★ 只有"目录全可读"且"每一个仍存在的映射都取证成功"，才允许声称 mmap 已覆盖
    { [ "$mmap_unread" -eq 0 ] && [ "$mmap_failed" -eq 0 ]; } || KB_MMAP_COVERED=no

    [ "$scanned" -gt 0 ] || { kb_die "/proc 下没有扫到任何进程 —— 枚举不可信"; return 2; }
    if [ "$unreadable" -gt 0 ]; then
        kb_die "有 $unreadable 个进程的 fd 目录读不了（权限/namespace）—— 扫描不完整，无法证明无人引用"
        return 2
    fi
    if [ "$statfail" -gt 0 ]; then
        kb_die "有 $statfail 个仍存在的 fd/cwd/root/exe 对象取不到设备号 —— 扫描不完整"
        return 2
    fi
    if [ "$found" -eq 1 ]; then
        printf '%s' "$KB_HOLDERS" | head -10 | sed 's/^/    /'
        return 0
    fi
    echo "  OK 引用枚举完成（$scanned 个进程；已覆盖 fd / cwd / root / exe）"
    if [ "$KB_MMAP_COVERED" = no ]; then
        echo "  ⚠️ mmap 覆盖缺口：$mmap_unread 个进程的 map_files 不可读（需 PTRACE_MODE_READ）；"
        echo "     另有 $mmap_failed 个【仍存在的】映射取证失败"
        echo "     —— 本次【未能】排除 mmap 形式的引用，是否接受由调用方决定"
    else
        echo "  （map_files 全部可读，且每个仍存在的映射均取证成功 —— mmap 引用亦已覆盖）"
    fi
    return 1
}

# 取单个 /proc 引用对象（fd / cwd / root / exe / map_files 项）的 st_dev 与 st_rdev
#     输出 "<st_dev> <st_rdev>"，失败返回 1（不打印，由调用方区分 race）
#     ★ v1.11 改名为 kb_proc_ref_devnums —— 它取的是任意 /proc 引用对象，不只是 fd；
#       旧名 kb_fd_devnums 保留为别名，避免既有调用断链。
#
# ★ %t/%T 只是 st_rdev，对普通文件与目录恒为 0:0 —— 必须同时取 st_dev（%d），
#   否则"在这个文件系统里的引用"永远匹配不上（v1.7 修正过的同一件事）。
kb_proc_ref_devnums(){
    local obj=$1 out tgt
    # ★★ v1.11 三态返回，理由见下：
    #   0 = 取证成功，输出 "<st_dev> <st_rdev>"
    #   1 = **有可解析目标、但取设备号失败** → 调用方必须记为"取证不完整"
    #   2 = **没有可解析目标**（内核线程的 exe/cwd/root、或对象已消失）→ 调用方按 race 跳过
    #
    #   为什么不能只看 stat 成败：把 `-e` 换成 `-L` 之后，**内核线程**的 exe/cwd/root
    #   也会进入判定（它们的 symlink 存在但无目标），若一律计为"取证失败"就会
    #   在完全正常的系统上把 M9a 变成永远 ERROR —— 实测首版改完确实出现 68 例。
    #   用 readlink 是否拿得到目标来分流：拿得到目标却 stat 不了 = 真正的取证失败
    #   （评审复现的正是这种：readlink 成功、-e 为 false、stat -L = Operation not permitted）。
    #   ⚠️ 权限受限的情形另有兜底：那种进程的 fd 目录本就读不了，
    #      在上一层已由 unreadable 计数判成扫描不完整（矩阵场景③ 实测 rc=2）。
    tgt=$(readlink "$obj" 2>/dev/null) || return 2
    [ -n "$tgt" ] || return 2
    out=$(stat -L -c '%d %r' "$obj" 2>/dev/null) || return 1   # KB_SCAN_EXEMPT: 热循环，见函数头；失败已显式 return
    case "$out" in
      ''|*[!0-9\ ]*) return 1 ;;
    esac
    printf '%s' "$out"
}

# 兼容旧名
kb_fd_devnums(){ kb_proc_ref_devnums "$@"; }

# ------------------------------------------------------------------
# M9 设备引用检查（只读检查 / 破坏性操作之前）
#     用法：kb_dev_released <设备> [purpose]
#            purpose=destroy 时进入【破坏性授权模式】，见下方附加条件
#     主证据 = M9a 进程引用枚举；fuser / lsof 为佐证：
#     只在 rc=0（明确找到持有者）时升级为阻断，返回非零时不作为任何方向的证据。
#
# ★★ v1.9 调整授权表述（上一版的 P0 的另一半）：
#    v1.8 的 M9a 已诚实写明"未覆盖 cwd/root/exe/mmap"，
#    **而调用者仍照样打印"$dev 已完全释放"** —— 函数诚实、调用者夸大，
#    比单纯文案过头更糟：局限写在那里，反而让人以为已经处理过了。
#    本版：文案只陈述**实际覆盖到的范围**，并把"能否据此做不可逆操作"交给显式条件判断。
# ------------------------------------------------------------------
#     ★★ v1.11：破坏性授权的两项声明**改为本次调用的显式参数**（v1.10 的 P1）：
#         kb_dev_released <dev> destroy [--no-lazy-umount] [--accept-mmap-risk]
#       v1.10 用的是环境变量 KB_NO_LAZY_UMOUNT / KB_ACCEPT_MMAP_RISK ——
#       **那是会话级开关**：既不绑定当前设备，成功后也不清除。实测：为 /dev/A 声明一次之后，
#       紧接着对 /dev/B 调用 destroy **直接继承授权**。而文案写的却是"本设备从未被懒卸载"。
#       部署文档恰好存在连续两个设备的调用（syswal / kbbackup），声明只写在二者共同的注释上。
#       改成调用参数后：天然一次性、天然绑定本次调用，不会粘到下一个设备。
#       ⚠️ 旧的环境变量**不再被识别** —— 沿用旧写法会停在"缺少前置声明"，方向是 fail-closed。
kb_dev_released(){
    local dev=$1 purpose=${2:-check} pids
    local decl_no_lazy=no decl_accept_mmap=no _a
    if [ $# -ge 2 ]; then shift 2; else shift $#; fi
    for _a in "$@"; do
        case "$_a" in
          --no-lazy-umount)   decl_no_lazy=yes ;;
          --accept-mmap-risk) decl_accept_mmap=yes ;;
          *) kb_die "未知参数 '$_a'（只接受 --no-lazy-umount | --accept-mmap-risk）"; return 1 ;;
        esac
    done
    # ★★ v1.10（v1.9 的 P1）：purpose 必须白名单校验。
    #   此前是 `[ "$purpose" = destroy ] || return 0` —— **destroy 之外的任何字符串都当普通检查**，
    #   于是 `destory` 这类拼写错误会【静默跳过全部破坏性授权条件】。
    #   通用安全 API 的默认必须是"未知即拒绝"，不能是"未知即宽松"。
    case "$purpose" in
      check|destroy) : ;;
      *) kb_die "未知 purpose='$purpose'（只接受 check | destroy）—— 拒绝以不确定的安全等级继续"; return 1 ;;
    esac
    kb_dev_unmounted "$dev" || return 1

    kb_dev_holders "$dev"
    case $? in
      0) kb_die "$dev 仍被进程引用（见上方明细）"; return 1 ;;
      1) : ;;
      *) return 1 ;;
    esac

    # —— 佐证探针：只能把结论从 free 升级为 busy，不能反过来证明 free ——
    if command -v fuser >/dev/null 2>&1; then
        kb_run "fuser -m $dev" fuser -m "$dev" || return 1
        if [ "$KB_RUN_RC" -eq 0 ]; then
            kb_parse_str "整理 fuser 输出" any "$KB_RUN_OUT" tr -d '[:space:]' || return 1
            pids=$KB_PARSE_OUT
            if [ -n "$pids" ]; then
                fuser -vm "$dev" 2>&1 | head -20
                kb_die "$dev 仍被进程持有（fuser 佐证，PID: $pids）"; return 1
            fi
        else
            echo "  注：fuser rc=$KB_RUN_RC（其协议无法区分「没有」与「出错」，本次不作为证据）"
        fi
    else
        echo "  注：未安装 fuser，跳过佐证探针（主证据为进程引用枚举）"
    fi

    if command -v lsof >/dev/null 2>&1; then
        kb_run "lsof $dev" lsof -- "$dev" || return 1
        if [ "$KB_RUN_RC" -eq 0 ] && [ -n "$KB_RUN_OUT" ]; then
            printf '%s\n' "$KB_RUN_OUT" | head -10
            kb_die "$dev 被进程打开（lsof 佐证）"; return 1
        fi
        [ "$KB_RUN_RC" -eq 0 ] || echo "  注：lsof rc=$KB_RUN_RC（同上，本次不作为证据）"
    else
        echo "  注：未安装 lsof，跳过佐证探针"
    fi

    # ★ 只陈述实际覆盖范围，不再宣布"已完全释放"
    echo "  OK $dev：未发现 fd / cwd / root / exe 形式的引用"
    if [ "${KB_MMAP_COVERED:-no}" = yes ]; then
        echo "     （mmap 亦已覆盖：全部 map_files 可读）"
    else
        echo "     ⚠️ 残余风险：$KB_MMAP_UNREAD 个进程的 map_files 不可读，**mmap 形式的引用未能排除**"
    fi

    [ "$purpose" = destroy ] || return 0

    # ===== 破坏性授权模式：以下两项必须显式满足 =====
    # ① 懒卸载声明：这是"挂载表看不到、引用却仍在"的唯一现实入口。
    #    M1b 查的是 mountinfo，umount -l 之后那里本来就查不到 —— 工具无法自证，只能由人声明。
    if [ "$decl_no_lazy" != yes ]; then
        kb_die "破坏性授权缺少前置声明：请确认本设备/文件系统【从未被 umount -l 懒卸载过】，
        确认后在本次调用上加 --no-lazy-umount 再执行（v1.11 起不再识别环境变量写法）。
        原因：懒卸载会立刻把挂载从 mountinfo 摘掉，而 cwd/root/exe/mmap 引用仍可能存在，
        M1b 与 M9a 都无法从现场状态反推这段历史。"
        return 1
    fi
    # ② mmap 覆盖缺口：未覆盖时必须显式接受
    if [ "${KB_MMAP_COVERED:-no}" != yes ] && [ "$decl_accept_mmap" != yes ]; then
        kb_die "破坏性授权被拒：mmap 引用未能排除（$KB_MMAP_UNREAD 个进程的 map_files 不可读，另有 $KB_MMAP_FAILED 个仍存在的映射取证失败）。
        二选一：① 以 root 重跑本检查使 map_files 可读；
                ② 确认可接受该残余风险后，在本次调用上加 --accept-mmap-risk。"
        return 1
    fi
    echo "  OK 破坏性授权条件满足（无懒卸载声明 + mmap 覆盖或已显式接受残余风险）"
}

# ------------------------------------------------------------------
# M10 自身完整性（内部一致性检查）
#     ⚠️ 只能发现"随手改动"，【不能】证明"这是批准发布版"。
#        外部信任锚 = 部署文档 B.1 的整文件 SHA256，由 B.2 用 sha256sum -c 机器校验。
# ------------------------------------------------------------------
kb_mseq_selfcheck(){
    local self=${1:-/root/kb_mseq.sh} body got full rc
    [ -r "$self" ] || { kb_die "读不到 $self"; return 1; }
    body=$(mktemp 2>/dev/null) || { kb_die "mktemp 失败"; return 1; }
    grep -v '^KB_MSEQ_APPROVED_SHA256=' "$self" >"$body"; rc=$?
    [ "$rc" -le 1 ] || { rm -f "$body"; kb_die "剔除批准行失败（grep rc=$rc）"; return 1; }
    [ -s "$body" ] || { rm -f "$body"; kb_die "本体内容为空 —— 证据不可信"; return 1; }
    kb_parse "计算本体哈希" single sha256sum "$body" || { rm -f "$body"; return 1; }
    kb_parse_str "取本体哈希值" single "$KB_PARSE_OUT" awk '{print $1}' || { rm -f "$body"; return 1; }
    got=$KB_PARSE_OUT
    rm -f "$body"
    kb_parse "计算整文件哈希" single sha256sum "$self" || return 1
    kb_parse_str "取整文件哈希值" single "$KB_PARSE_OUT" awk '{print $1}' || return 1
    full=$KB_PARSE_OUT
    echo "  kb_mseq.sh 版本=${KB_MSEQ_VERSION}"
    echo "  整文件 SHA256=$full   ← ★ 外部信任锚，须与部署文档 B.1 机器校验一致"
    echo "  本体   SHA256=$got"
    [ "$got" = "$KB_MSEQ_APPROVED_SHA256" ] \
        || { kb_die "本体哈希与内置批准值不符（批准 $KB_MSEQ_APPROVED_SHA256）—— 文件已被改动"; return 1; }
    echo "  OK 内部自洽；★ 是否为批准发布版，以 B.2 的 sha256sum -c 结果为准"
}

# ------------------------------------------------------------------
# M12 已知危险模式扫描 —— ★ v1.7 改名并**降级表述**
#     用法：kb_mseq_scan_known_patterns [文件，默认 /root/kb_mseq.sh]
#     （旧名 kb_mseq_scan_parsers 保留为别名，避免既有 SOP 断链）
#
#     ⚠️⚠️ **它能证明什么、不能证明什么，必须说清楚**：
#       能：发现【命令替换形式】的裸解析 —— `$(... | ...)` 或 `$(stat|awk|sed|wc|tr|grep|head|cut|sort ...)`
#       **不能**：它是正则模式匹配，不是语法分析。**独立语句形式的裸解析扫不到**，例如
#                `awk '{print $1}' /etc/passwd >/dev/null` —— 完全符合"裸调用解析器"的定义，却不会命中。
#     v1.6 把它叫作"全库裸解析清零证明"，**这是给了一个比实际能力更强的名字** ——
#     而"声称能力 > 实际能力"正是本套文档反复批评的那类问题。本版改名并写明局限。
#     若要真正做到"机械证明"，需要 shell 语法分析（ShellCheck / AST），不是继续打正则补丁。
# ------------------------------------------------------------------
kb_mseq_scan_known_patterns(){
    local self=${1:-/root/kb_mseq.sh} mk
    [ -r "$self" ] || { kb_die "读不到 $self"; return 1; }
    # ★ 标记串在运行时拼出来，使本函数自身的源码不含该字面量 —— 否则扫描器会扫到自己
    mk="KB_SCAN""_EXEMPT"
    # ① 已登记豁免的行：必须带标记【且】有显式 || 失败分支，否则算违规
    kb_parse "列出已登记豁免" any awk -v mk="$mk" '
        index($0, mk) > 0 {
            ok = ($0 ~ /\|\|/)
            printf "%d: %s  [%s]\n", NR, $0, (ok ? "有失败分支" : "缺失败分支!")
        }' "$self" || return 1
    if [ -n "$KB_PARSE_OUT" ]; then
        echo "  已登记豁免（每次打印，交付 checklist 须逐条复核）："
        printf '%s\n' "$KB_PARSE_OUT" | sed 's/^/    /'
        case "$KB_PARSE_OUT" in
          *"缺失败分支!"*) kb_die "有豁免行缺少显式失败分支 —— 豁免的前提是不吞掉失败"; return 1 ;;
        esac
    fi
    # ② 未登记的裸解析：命中数必须为 0
    kb_parse "扫描已知危险模式" any awk -v mk="$mk" '
        {
            line=$0
            sub(/#.*$/,"",line)
            if (line ~ /kb_run|kb_parse/) next
            if (index($0, mk) > 0) next
            if (line ~ /\$\([^)]*\|/ || line ~ /\$\((stat|awk|sed|wc|tr|grep|head|cut|sort)[ \t]/)
                printf "%d: %s\n", NR, $0
        }' "$self" || return 1
    if [ -n "$KB_PARSE_OUT" ]; then
        printf '%s\n' "$KB_PARSE_OUT" | head -20 | sed 's/^/    /'
        kb_parse_str "统计命中数" number "$KB_PARSE_OUT" awk 'END{print NR}' || return 1
        kb_die "发现 $KB_PARSE_OUT 处【未登记】的命令替换式裸解析 —— 必须改走 kb_parse 或登记豁免"; return 1
    fi
    echo "  OK 已知危险模式扫描：未登记命中 0 处"
    echo "  ⚠️ 本扫描只覆盖【命令替换形式】，独立语句形式的裸解析扫不到 —— 它不是全库证明"
}
# 兼容旧名（既有 SOP / checklist 里写的是它）
kb_mseq_scan_parsers(){ kb_mseq_scan_known_patterns "$@"; }
