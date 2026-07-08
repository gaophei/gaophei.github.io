可以完全套用 §19.4 的骨架(rsync 先复制、校验、切换挂载、fstab UUID、留旧目录回退),但 NFS 服务器有**三处本质差异**,直接照抄会出事,先讲清楚再给对应到 19.4.x 各步的执行方案。

## 〇、与 §19.4 的三处本质差异

**1. "停库"的对应物是停 K8s 侧的写入方,不是停本机服务。** 这台机器的"业务进程"在 7 台 K8s 节点上——13 个 PVC 目录是 nfs-subdir-provisioner 的典型命名(`<ns>-<pvcname>-pvc-<uuid>`),里面有**正在活跃写入的负载**(cas-server 的 Redis AOF mtime 16:42、formflow 15:32 还在动)。真正要停的是使用这些 PVC 的 Deployment/StatefulSet(缩到 0),让 kubelet 把 NFS 挂载卸掉。

**2. 核心风险不是 systemd 反拉,而是 stale file handle。** NFS 文件句柄编码了 fsid + inode;换了底层文件系统后 inode 全变、fsid 也变,**老挂载上持有的句柄全部失效**——不重启客户端挂载绕不过去。这就是为什么必须缩容(kubelet 卸载)而不能"服务端偷偷换盘":否则切换完成后所有 pod 会 ESTALE 报错、崩溃重启,等于被动经历一次无序的全体重启。

**3. 数据只有 238M,复制是秒级**;窗口时长由 K8s 缩容/扩容主导。另外注意 CAS(校园 SSO)的 Redis 在这批 PVC 里——**缩容窗口 = SSO 中断窗口**,按业务低峰(晚间)安排。

还有一个开工前的**布局决策**:450G 全给 238M 的导出太奢侈,而这台机还是 vbdb01 的异地备份目标(`/backup/vbdb01`,现在在 59G 系统盘上)。建议 VG 里切两个 LV 并**留空闲余量**——这正是 §19.4.7 说的多卷拆分场景,且 LVM 天生支持以后 `lvextend` 在线加:

- 方案 A(完全照 §19.4):一个 LV 吃满 100%FREE,最简单;
- **方案 B(推荐)**:`lvnfs` 100G 挂 `/opt/nfs/rancher` + `lvbackup` 100G 挂 `/backup`(把异地备份也从系统盘挪走),VG 剩 ~250G 空闲,谁涨扩谁。

下面按方案 B 写,方案 A 只需把 lvcreate 改回 `-l 100%FREE` 并跳过 lvbackup。

## 一、迁移前确认(对应 §19.4.1)

```bash
# nfs 主机,root 执行
du -shx /opt/nfs/rancher          # 238M,已确认
lsblk -f /dev/vdc
wipefs -n /dev/vdc                # 无输出 = 干净裸盘
getenforce
systemctl cat nfs-server | grep -E 'Type|Restart' ; systemctl is-enabled nfs-server
# 属主基线:目录混有 root / 1000 / 1001(no_root_squash 环境),rsync 必须 --numeric-ids
ls -ldn /opt/nfs/rancher          # 记录:root:root 755
```

K8s 侧梳理(在 rancher/kubectl 所在机执行)——这是本次的"第 5 步库外表空间排查"对应物,**必须拿到完整清单**:

```bash
# 1) 指向本 NFS 的全部 PV → PVC 映射(应对上 13 个目录)
kubectl get pv -o json | jq -r '.items[] | select(.spec.nfs.server=="10.120.0.33")
  | "\(.spec.claimRef.namespace)/\(.spec.claimRef.name)\t\(.spec.nfs.path)"' | sort

# 2) 每个 PVC 被哪些 Pod 使用 → 反推出要缩容的工作负载,记录当前副本数
kubectl get pods -A -o json | jq -r '.items[]
  | . as $p | .spec.volumes[]? | select(.persistentVolumeClaim)
  | "\($p.metadata.namespace)\t\($p.metadata.name)\t\(.persistentVolumeClaim.claimName)"' \
  | grep -Ff <(kubectl get pv -o json | jq -r '.items[] | select(.spec.nfs.server=="10.120.0.33") | .spec.claimRef.name')

# 3) ★别漏 nfs-subdir-provisioner 本身——它直接挂着导出根目录,也要缩 0
kubectl get deploy -A | grep -iE 'nfs.*(provisioner|client)'
```

把「namespace / 工作负载 / 类型 / 原副本数」记成表,这是扩容回来的依据。迁移前快照基线(对应第 7 步表计数):

```bash
# nfs 主机
cd /opt/nfs/rancher
find . | sort > /tmp/nfslist_pre_$(date +%F_%H%M%S).txt
du -s --block-size=1 */ | sort > /tmp/nfsdu_pre_$(date +%F_%H%M%S).txt
```

## 二、停写入方 + 停 NFS(对应 §19.4.2 的安全闸)

```bash
# K8s 侧:按清单缩 0(业务负载先、provisioner 最后;StatefulSet 用 scale 同理)
kubectl -n <ns> scale deploy/<name> --replicas=0
kubectl -n <ns> scale statefulset/<name> --replicas=0
# ...逐个执行,等 pod 全部 Terminated

# ★验证 7 台节点已无本 NFS 的残留挂载(kubelet 随最后一个使用 pod 的销毁而卸载)
for i in 37 38 39 40 41 42 43; do
  echo "== 10.120.0.$i"; ssh 10.120.0.$i "grep 10.120.0.33 /proc/mounts" || true
done                                # 全部无输出才继续

# nfs 主机:服务端确认无活动连接后停服(对应 mask 安全闸——此窗口谁也别再挂上来)
ss -tn state established '( sport = :2049 )'    # 应为空
systemctl stop nfs-server
fuser -m /opt/nfs/rancher 2>/dev/null            # 应无输出
```

> 客户端若有漏网挂载,NFS 硬挂载的行为是 **hang 住重试**而不是报错——这比数据库反拉安全,但也意味着切换后它拿到的是 stale handle,所以上面的逐节点验证不能省。

## 三、建 LVM 并复制(对应 §19.4.3)

```bash
pvcreate /dev/vdc
vgcreate vgdata /dev/vdc
lvcreate -n lvnfs    -L 100G vgdata          # 方案 A 改:-l 100%FREE,且无 lvbackup
lvcreate -n lvbackup -L 100G vgdata          # 顺手把 /backup 挪出系统盘(可选)
mkfs.ext4 -m 1 /dev/vgdata/lvnfs
mkfs.ext4 -m 1 /dev/vgdata/lvbackup
vgs                                           # 确认剩余 ~250G 空闲备扩

mkdir -p /mnt/nfsnew
mount /dev/vgdata/lvnfs /mnt/nfsnew
rsync -aAXH --numeric-ids --info=progress2 /opt/nfs/rancher/ /mnt/nfsnew/   # 238M,秒级
```

## 四、校验一致后切换挂载(对应 §19.4.4,含 v1.46 的 daemon-reload)

```bash
diff <(cd /opt/nfs/rancher && find . | sort) \
     <(cd /mnt/nfsnew && find . -path ./lost+found -prune -o -print | sort)   # 无输出即一致

umount /mnt/nfsnew
mv /opt/nfs/rancher /opt/nfs/rancher_old
mkdir /opt/nfs/rancher

UUID_N=$(blkid -s UUID -o value /dev/vgdata/lvnfs)
UUID_B=$(blkid -s UUID -o value /dev/vgdata/lvbackup)
echo "UUID=$UUID_N  /opt/nfs/rancher  ext4  defaults,noatime  0 0" >> /etc/fstab
echo "UUID=$UUID_B  /backup           ext4  defaults,noatime  0 0" >> /etc/fstab   # 可选项
mount /opt/nfs/rancher
findmnt /opt/nfs/rancher
systemctl daemon-reload && findmnt --verify

# 挂载后还原根目录属主/权限(原为 root:root 755)
chown root:root /opt/nfs/rancher && chmod 755 /opt/nfs/rancher
ls -ld /opt/nfs/rancher /opt/nfs/rancher/*pvc* | head
[ "$(getenforce)" = "Enforcing" ] && restorecon -Rv /opt/nfs/rancher
```

`/backup` 的迁移同理(rsync 现有 `/backup` 内容到 lvbackup 后再切,数据也很小;它没有客户端挂载问题,随时可做)。

## 五、受控重启 → 起服务 → 扩容回来(对应 §19.4.5)

这里顺序和 vbdb01 不同,**受控重启插在扩容之前做**——客户端还都缩着 0,重启零感知,正好验证 fstab 持久性:

```bash
reboot
# 重启后:
findmnt /opt/nfs/rancher                       # 来自 /dev/mapper/vgdata-lvnfs
systemctl status nfs-server --no-pager         # enabled,应已随开机自启
exportfs -v ; showmount -e localhost           # 7 条导出齐全

# 从任一 K8s 节点做一次手工挂载读写测试(比等 pod 起来排错快)
ssh 10.120.0.40 "mkdir -p /mnt/t && mount -t nfs 10.120.0.33:/opt/nfs/rancher /mnt/t \
  && touch /mnt/t/.rwtest && rm /mnt/t/.rwtest && umount /mnt/t && echo RW-OK"

# K8s 侧按记录的副本数恢复:★provisioner 先起,再业务负载
kubectl -n <ns> scale deploy/nfs-...-provisioner --replicas=1
kubectl -n <ns> scale deploy/<name> --replicas=<原值>   # 逐个恢复
kubectl get pods -A | grep -vE 'Running|Completed'       # 直到为空
```

验收(对应表计数比对):pod 全 Running 后,在 nfs 主机重跑 find/du 快照与 pre 版比对(差异应只有各负载启动后的新写入);重点抽查 cas-server Redis 的 `appendonly.aof` **恢复增长**、CAS 登录链路可用、formflow 上传可写。观察一两天后:

```bash
rm -rf /opt/nfs/rancher_old        # §1 红线,确认无误后执行
```

**回退方案**(删 rancher_old 之前任一环节出问题):缩容 → `systemctl stop nfs-server` → `umount /opt/nfs/rancher` → 删本次 fstab 行 → `mv rancher_old rancher` → 起 nfs-server → 扩容。与 §19.4.5 回退等价。

最后两点提醒:这台 nfs 虚机也在 pitrix 平台上,**同样每 30 分钟被时钟锯**(§14.9 的工单覆盖它);另外这次跑通后值得作为 §19.4 的变体固化进文档(比如 §19.4.9「变体:NFS 导出目录迁移——停写入方与 stale handle 处理」),等你执行完带着记录来,我们连同 vbdb01 的观察期收尾一起进 v1.47。