# macOS 虚拟机忘记开机密码 —— 恢复模式「重设密码」失败的排查与解决

> 处理时间：2026-08-26
> 虚拟机：`macbook1`（ESXi 主机 `192.168.1.205`，通过 VMware Workstation 连接管理）
> 结果：已解决，重启后正常登录系统

---

## 一、问题现象

虚拟机 `macbook1` 忘记开机密码，进入恢复模式后使用「重设密码」（Reset Password）工具：

1. 在「选择要恢复的宗卷」界面，可选项为：`Update`、`Recovery`、`VM`、`macos - 数据`
   —— **注意：系统宗卷 `macos` 并未出现在列表中**
2. 选择 `macos - 数据` 后点「下一步」，直接报错：

   > **重设密码失败**
   > 此宗卷上没有要为其重设密码的用户。

图形工具到此走不下去，需要转入命令行排查。

---

## 二、环境信息采集

### 2.1 磁盘工具中看到的数据卷

| 项目 | 值 |
|---|---|
| 宗卷名 | `macos - 数据` |
| 类型 | 逻辑宗卷 APFS（Case-sensitive） |
| 容量 | 85.69 GB |
| 已使用 | 65.93 GB |
| 实际可用 | 19.76 GB |
| 装载点 | `/Volumes/macos - 数据` |
| 设备 | `disk18s1` |
| 所有者 | 已启用 |
| 连接 | PCI |

### 2.2 `diskutil list` 关键输出

```
/dev/disk0 (external, physical):
   #:   TYPE                NAME                 SIZE       IDENTIFIER
   0:   GUID_partition_scheme                    *85.9 GB   disk0
   1:   EFI                 EFI                  209.7 MB   disk0s1
   2:   Apple_APFS          Container disk18     85.7 GB    disk0s2

/dev/disk1 (external, physical):
   #:   TYPE                NAME                    SIZE     IDENTIFIER
   0:   Apple_partition_scheme                      *7.0 GB  disk1
   1:   Apple_partition_map                         32.3 KB  disk1s1
   2:   Apple_HFS           Sierra Custom Installer 7.0 GB   disk1s2

/dev/disk18 (synthesized):
   #:   TYPE          NAME              SIZE       IDENTIFIER
   0:   APFS Container Scheme -          +85.7 GB   disk18
                      Physical Store disk0s2
   1:   APFS Volume   macos - 数据      42.6 GB    disk18s1
   2:   APFS Volume   Preboot           267.7 MB   disk18s2
   3:   APFS Volume   Recovery          1.1 GB     disk18s3
   4:   APFS Volume   VM                1.1 MB     disk18s4
   5:   APFS Volume   （无名称）        21.7 GB    disk18s5
   6:   APFS Volume   Update            104.3 MB   disk18s6
```

（disk2 ~ disk17 均为 Recovery 环境挂载的 disk image ramdisk，与本次问题无关。）

### 2.3 `diskutil apfs list` 关键输出

```
Container disk18  117A15F3-9366-41AA-BF76-2C577E435788
  APFS Container Reference:  disk18
  Capacity Ceiling (Size):   85689589760 B (85.7 GB)
  Capacity In Use By Volumes:65927770112 B (65.9 GB) (76.9% used)
  Capacity Available:        19761819648 B (19.8 GB) (23.1% free)
  Physical Store disk0s2     41E3440E-468F-4232-B2D6-A1C3A43C7780
```

| 宗卷 | UUID | Role | Name | Mount Point | Consumed | Encrypted |
|---|---|---|---|---|---|---|
| disk18s1 | A53D542C-F7C5-33D8-BCE0-82D797567531 | **No specific role** | `macos - 数据` | `/Volumes/macos - 数据` | 42.6 GB | No |
| disk18s2 | 63B40753-FF28-4E31-9506-083BF08F5F9B | Preboot | Preboot | Not Mounted | 267.7 MB | No |
| disk18s3 | 53A10DBB-C6C2-4FAC-BFDA-D8523D8AB1C8 | Recovery | Recovery | Not Mounted | 1.1 GB | No |
| disk18s4 | 8A19ACFC-C83E-4C0A-83BF-F6355D8F258D | VM | VM | Not Mounted | 1.1 MB | No |
| disk18s5 | —— | **System** | **（空）** | Not Mounted | 21.7 GB | No |
| disk18s6 | E018B2FB-3CFE-4784-BB6C-E5DEE21D970B | No specific role | Update | `/Volumes/Update` | 104.3 MB | No |

### 2.4 `df -h` —— 当前启动介质

```
Filesystem       Size   Used  Avail  Capacity  Mounted on
/dev/disk1s2     6.5Gi  6.0Gi  454Mi    94%    /
...
/dev/disk18s6     80Gi   99Mi   18Gi     1%    /Volumes/Update
/dev/disk18s1     80Gi   40Gi   18Gi    69%    /Volumes/macos - 数据
```

根目录挂的是 `/dev/disk1s2`，即那个 **Sierra Custom Installer**，说明当前恢复环境是从旧版安装器启动的。

---

## 三、根因分析

综合以上信息，报错「此宗卷上没有要为其重设密码的用户」由两个因素叠加造成：

### 3.1 主因：APFS 宗卷组（Volume Group）配对断裂

正常的 Catalina 及以后的 macOS，系统卷与数据卷成对存在：

- System 卷：`macos`，Role = System
- Data 卷：`macos - 数据`，Role = **Data**

而本机实际状态是：

- `disk18s5` Role = System，但**名称为空**、未挂载
- `disk18s1` 名为 `macos - 数据`，但 Role = **No specific role**（不是 Data）

两者没有构成宗卷组。恢复模式的「重设密码」工具是先定位宗卷组、再通过组内 Data 卷去读账号数据库的；配对断了，它自然认为"这个宗卷上没有用户"。同样的原因导致：

```bash
diskutil mount "macos"
# Unable to find disk for macos
```

### 3.2 次因：从旧版（Sierra）安装器启动

`df -h` 显示根挂载是 Sierra Custom Installer。Sierra 时代的重设密码工具早于 APFS 宗卷组机制，本身就不理解 Catalina+ 的卷结构，进一步加剧了识别失败。

### 3.3 有利条件

- 所有宗卷 `Encrypted: No` —— **FileVault 未启用**，数据卷可直接读写
- 数据卷已正常挂载在 `/Volumes/macos - 数据`，65.9 GB 数据完好
- 数据卷「所有者：已启用」，权限语义正常

因此可以绕过图形工具，直接操作本地账号数据库 `dslocal`。

---

## 四、解决过程

### 4.0 前置：恢复模式终端无法输入中文

宗卷名 `macos - 数据` 含中文和空格，终端下打不出来。三种绕法：

```bash
# 方法一：通配符（推荐，容器内只有这一个 macos 开头的卷）
cd /Volumes/macos*

# 方法二：Tab 补全，输入 /Volumes/mac 后按 Tab

# 方法三：八进制转义
cd /Volumes/macos\ -\ \346\225\260\346\215\256/
```

进入后用 `$PWD` 引用，后续命令全部避开中文。

```bash
cd /Volumes/macos*
pwd
# /Volumes/macos - 数据
```

### 4.1 确认本地账号数据库存在

```bash
cd /Volumes/macos*
ls private/var/db/dslocal/nodes/Default/users/
```

输出中除大量 `_` 开头的系统守护账号（`_amavisd.plist`、`_mysql.plist`、`_www.plist` 等）外，可见：

```
daemon.plist   nobody.plist   root.plist   user.plist
```

**`user.plist` 即目标账号**，说明用户数据完好，只是图形工具读不到。

### 4.2 用 dscl 列出并重置密码

```bash
cd /Volumes/macos*
NODE="$PWD/private/var/db/dslocal/nodes/Default/"
echo $NODE
# /Volumes/macos - 数据/private/var/db/dslocal/nodes/Default/

# 列出本地用户，确认短用户名
dscl -f "$NODE" localhost -list /Local/Default/Users
# ... _accessoryupdater / _amavisd / ... / daemon / nobody / root / user

# 重置密码（USERNAME = user）
dscl -f "$NODE" localhost -passwd /Local/Default/Users/user 'NewPass123'
```

`-passwd` 执行成功时**无任何输出**，直接返回提示符即代表已写入。

### 4.3 重启

```bash
reboot
```

重启前在 VMware 中断开 Sierra 安装器的虚拟磁盘/ISO，避免再次进入安装器环境。

**结果：重启后使用 `user` / `NewPass123` 正常登录系统。**

---

## 五、备选方案（本次未使用）

### 5.1 清空密码哈希，用空密码登录

若 `dscl -passwd` 报错或改后仍登录不上（旧版 Recovery 写入的哈希格式可能不兼容）：

```bash
cd /Volumes/macos*
plutil -remove ShadowHashData private/var/db/dslocal/nodes/Default/users/user.plist
reboot
```

登录时用户名 `user`、密码栏直接回车。进系统后**立即**在「系统偏好设置 → 用户与群组」中用系统自身接口设置新密码。

### 5.2 触发设置助理，新建管理员账号

成功率最高的兜底方案：

```bash
cd /Volumes/macos*
rm private/var/db/.AppleSetupDone
reboot
```

重启后走一遍初始化向导，创建一个**新用户名**的管理员账号；进入系统后在「用户与群组」中给原账号改密码，完成后可删除临时账号。

---

## 六、遗留事项

### 6.1 修复 APFS 宗卷角色（建议在系统内或恢复模式中处理，操作前先打快照）

```bash
# 把数据卷 Role 改回 Data
diskutil apfs changeVolumeRole disk18s1 D

# 给系统卷补名字
diskutil mount disk18s5
diskutil rename disk18s5 macos
```

若系统卷处于封签（sealed）状态，`rename` 会失败，可忽略——不影响日常使用，仅影响以后进恢复模式时图形工具能否正确识别宗卷组。

### 6.2 其他

- 密码 `NewPass123` 为临时密码，登录后应及时修改
- 登录后若提示钥匙串密码不匹配，选择「创建新钥匙串」
- 建议给该虚拟机建立定期快照，避免同类问题重复耗时

---

## 七、经验小结

| 关键点 | 说明 |
|---|---|
| 图形工具失败 ≠ 数据丢失 | 「重设密码」依赖宗卷组元数据，元数据异常时工具直接摆烂，但 `dslocal` 数据库通常完好 |
| 先看 `diskutil apfs list` | Role、Name、Mount Point、Encrypted 四列基本能定位所有 APFS 结构性问题 |
| `Encrypted: No` 是关键前提 | FileVault 未启用时才能直接改 `dslocal`；若已加密且无恢复密钥，任何方法都无解 |
| 别用旧版安装器进恢复模式 | Sierra 时代工具不认识 Catalina+ 的 APFS 宗卷组 |
| 中文/空格宗卷名 | 终端下用 `/Volumes/macos*` 通配符 + `$PWD`，避免输入法问题 |
| dscl 改密码的副作用 | 会导致该账号钥匙串失效；FileVault 开启时还会破坏 SecureToken，需谨慎 |
