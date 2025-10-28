可以。Oracle Linux 7 用 **GRUB2**，把默认启动项改成旧的 UEK 内核即可。给你三种做法，任选其一（都需 /boot 已挂载）。

------

### 方案 A：用 `grub2-set-default`（最直接）

1. 先列出菜单项，确认准确标题（你截图里已经有了）：

```bash
awk -F\' '$1=="menuentry " {print NR-1": "$2}' /boot/grub2/grub.cfg
# UEFI 机器改成：/boot/efi/EFI/redhat/grub.cfg
```

1. 设定默认启动项为 **5.4.17-2102.201.3.el7uek.x86_64**：

```bash
grub2-set-default 'Oracle Linux Server 7.9, with Unbreakable Enterprise Kernel 5.4.17-2102.201.3.el7uek.x86_64'
# 或者用索引号：grub2-set-default 1   （按上一步显示的编号为准）
```

1. 验证：

```bash
grub2-editenv list   # 应看到 saved_entry=... 指向上面那条
```

> 不需要重建 grub.cfg；重启后就会默认进旧内核。

------

### 方案 B：用 `grubby` 指定默认 **内核文件**

```bash
grubby --set-default /boot/vmlinuz-5.4.17-2102.201.3.el7uek.x86_64
grubby --default-kernel
```

------

### 方案 C：写到 `/etc/default/grub`（持久策略）

把默认策略改成“使用保存的条目”，以后就用 A/B 去修改 saved_entry：

```bash
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub
# 生成配置（BIOS/UEFI 二选一）
grub2-mkconfig -o /boot/grub2/grub.cfg
# 或：grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
# 再执行方案 A 中的 grub2-set-default 设定一次默认项
```

------

### 防止以后又自动升到有问题的内核

- 暂时锁版本（推荐）：

```bash
yum -y install yum-plugin-versionlock
yum versionlock kernel-uek-*      # 锁住当前已安装的 UEK 版本
```

- 或在 `/etc/yum.conf` 里临时排除：

```
exclude=kernel-uek* 
```

> 不建议立即卸载坏内核，先保留以便需要时手动选；等系统稳定后再决定是否 `yum remove kernel-uek-5.4.17-2136.338.4.2.el7uek`。

这样设置后，机器重启会默认进入 **5.4.17-2102.201.3.el7uek.x86_64**。需要我根据你是 BIOS 还是 UEFI 帮你确定使用哪个 grub.cfg 路径的话，贴一下 `ls /boot/efi/EFI` 的结果即可。