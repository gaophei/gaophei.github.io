# Git/Gitea 仓库同步实施与排障手册

> 适用场景：在 Linux 服务器上将已有目录中的代码或 Helm Charts 同步到内网 Gitea 仓库。  
> 本文根据 `charts`、`ds-middle` 两个仓库的实际操作和报错整理，供团队实施、复盘和排障使用。  
> 文档日期：2026-09-05

## 1. 文档目的

本文集中说明以下问题：

1. 空 Gitea 仓库首次克隆、提交和推送的标准流程。
2. `main`、`master` 分支名不一致导致推送失败的原因和处理方法。
3. Git 提交身份与 Gitea HTTP 登录凭据的区别。
4. `credential.helper store` 为什么首次仍会要求输入账号密码。
5. `origin` 拼写错误为何会被误判成仓库或权限问题。
6. 如何安全、完整地同步目录，包括隐藏文件和源端删除的文件。
7. 一套可重复执行的检查清单、排障顺序和参考脚本。

## 2. 本次环境和案例概览

| 项目 | 实际值或现象 |
| --- | --- |
| Git 服务 | Gitea 1.21.1 |
| Gitea 地址 | `http://192.168.72.25:3000` |
| 组织/用户 | `test` |
| 案例仓库 | `charts`、`ds-middle` |
| 操作系统用户 | `root` |
| `charts` 本地分支 | `master` |
| Gitea `charts` 页面示例分支 | `main` |
| 认证协议 | HTTP |
| 凭据助手 | `store` |
| 凭据文件 | `/root/.git-credentials` |

> 注意：文中保留内网地址以便对应现场。用户名、密码和令牌不得写入共享文档、脚本或截图。

## 3. 开始前先理解四个独立概念

### 3.1 本地仓库

包含 `.git/` 目录的工作目录。可用以下命令确认：

```bash
git rev-parse --show-toplevel
git status
```

### 3.2 本地分支

例如 `master` 或 `main`。推送命令中的最后一个参数通常必须是本地真实存在的分支：

```bash
git branch --show-current
git branch -vv
```

### 3.3 远程仓库别名

`origin` 只是远程地址在本地的默认别名，不是固定关键字，也不是服务器名。`git clone` 通常会自动创建它：

```bash
git remote -v
```

### 3.4 提交身份与远程认证

这两组配置作用完全不同：

| 配置 | 用途 | 是否用于 Gitea 登录 |
| --- | --- | --- |
| `user.name` | 写入 commit 的作者名 | 否 |
| `user.email` | 写入 commit 的作者邮箱 | 否 |
| `user.password` | 非 Git 标准认证项；即使能写入配置，推送也不会读取 | 否 |
| `credential.helper` | 指定如何获取或保存 HTTP 凭据 | 是 |

推荐配置：

```bash
git config --global user.name "test"
git config --global user.email "test@test.edu.cn"
git config --global credential.helper store
```

删除没有实际认证作用的自定义项：

```bash
git config --global --unset-all user.password || true
git config --unset-all user.password || true
```

## 4. 案例一：推送 `main` 报 `src refspec main does not match any`

### 4.1 现场操作

Gitea 的空仓库页面给出的示例使用 `main`：

```bash
git checkout -b main
git push -u origin main
```

服务器上克隆 `charts` 空仓库、复制文件、提交后执行：

```bash
git push -u origin main
```

报错：

```text
error: src refspec main does not match any
error: failed to push some refs to 'http://192.168.72.25:3000/test/charts.git'
```

随后 `git log` 显示：

```text
(HEAD -> master)
```

添加 `--force` 后仍然是相同报错。

### 4.2 根因

本地提交位于 `master`，本地没有 `main`。命令：

```bash
git push -u origin main
```

要求 Git 将“本地 `main`”推送到远程，但该引用不存在，因此报 `src refspec main does not match any`。

`--force` 只能允许非快进方式覆盖远程历史，不能创建一个本地不存在的分支，所以对该故障无效。

### 4.3 本次采用的解决方案：继续使用 `master`

用户没有强制改为 `main`，而是执行：

```bash
git push -u origin master
```

推送成功，并建立跟踪关系：

```text
[new branch]      master -> master
Branch 'master' set up to track remote branch 'master' from 'origin'.
```

以后可直接执行：

```bash
git push
git pull
```

### 4.4 可选方案：统一改为 `main`

如果团队规范要求使用 `main`：

```bash
git branch -M main
git push -u origin main
```

不改本地分支名、只映射到远程 `main` 也可以：

```bash
git push -u origin master:main
```

不过长期维护时，本地和远程同名更清楚。

### 4.5 诊断要点

遇到该错误先运行：

```bash
git status
git branch --show-current
git branch -a
git log -1 --oneline --decorate
```

还要区分另一种常见情况：仓库没有任何 commit 时，即使分支名看似正确，也可能报相同错误。检查：

```bash
git rev-parse --verify HEAD
```

若提示无法解析 `HEAD`，先创建首次提交，再推送。

## 5. 案例二：配置了用户名和密码，首次 push 仍要求输入凭据

### 5.1 现场现象

已经执行过：

```bash
git config --global user.name "test"
git config --global user.email "test@test.edu.cn"
git config user.name "test"
git config user.password "<已脱敏>"
git config --global credential.helper store
```

但首次执行以下命令时，Git 仍然提示输入 Username 和 Password：

```bash
git push -u origin master
```

输入正确凭据后，`charts` 仓库推送成功。

### 5.2 根因

`user.name` 和 `user.email` 是 commit 作者信息，不是 Gitea 登录信息。`user.password` 不是 Git HTTP 认证读取的标准配置项。

而：

```bash
git config --global credential.helper store
```

只是在告诉 Git：“用户成功输入一次凭据后，把它保存起来供以后使用。”它不会预先知道账号和密码，因此第一次访问该认证目标时仍然会询问。

### 5.3 如何确认已经生效

本次现场确认 `/root/.git-credentials` 中已有同一主机的凭据，这说明 `store` 已生效。不要打印文件内容，只检查文件和配置：

```bash
git config --show-origin --get-all credential.helper
test -f /root/.git-credentials && echo "credential file exists"
stat -c '%a %U %G %n' /root/.git-credentials
git remote -v
```

期望权限：

```text
600 root root /root/.git-credentials
```

若权限不正确：

```bash
chmod 600 /root/.git-credentials
```

### 5.4 为什么新仓库通常能复用凭据

默认情况下，HTTP 凭据主要按协议和主机匹配。本次两个仓库均位于：

```text
http://192.168.72.25:3000
```

因此成功保存后，对 `charts` 和 `ds-middle` 的后续 `push`、`pull`、`fetch` 通常都可复用，无需再次输入。

如果希望凭据严格区分仓库路径，可设置：

```bash
git config --global credential.useHttpPath true
```

设置后，不同仓库路径可能需要分别保存凭据。

### 5.5 仍反复询问时的检查顺序

```bash
whoami
git config --show-origin --get-all credential.helper
git remote -v
stat -c '%a %U %G %n' ~/.git-credentials
```

重点排查：

- 前后是否由不同 Linux 用户执行，例如一次是 `root`、一次是普通用户。
- 是否一次使用 IP、一次使用主机名，或端口、协议不同。
- 是否存在多条互相覆盖的 `credential.helper` 配置。
- Gitea 是否禁用了账户密码认证，要求使用 Access Token。
- 保存的密码或 Token 是否已经修改、过期或吊销。

### 5.6 安全要求

`credential.helper store` 会以可还原的明文形式保存凭据。仅建议在访问受控、权限严格的内网服务器使用。

本次截图中曾出现明文密码。若该密码仍有效，应立即：

1. 在 Gitea 中修改密码或吊销对应凭据。
2. 创建专用、最小权限的 Access Token。
3. 删除旧凭据并在下次 push 时输入 Token。

可通过 Git 的凭据接口删除对应记录，避免直接在命令行历史中写密码：

```bash
printf 'protocol=http\nhost=192.168.72.25:3000\n\n' | git credential reject
```

不要把密码或 Token 拼到远程 URL、脚本或 shell 命令中，否则可能进入 `.git/config`、shell history、日志或进程信息。

## 6. 案例三：`'orgin' does not appear to be a git repository`

### 6.1 现场操作和报错

`ds-middle` 已成功提交：

```text
[master (root-commit) ...] ds-middle
```

随后执行：

```bash
git push orgin master
```

报错：

```text
fatal: 'orgin' does not appear to be a git repository
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```

### 6.2 根因

命令中把 `origin` 拼成了 `orgin`，少了第二个字母 `i`。

截图中的检查结果证明远程配置本身是正确的：

```bash
git remote -v
```

输出中存在：

```text
origin  http://192.168.72.25:3000/test/ds-middle.git (fetch)
origin  http://192.168.72.25:3000/test/ds-middle.git (push)
```

`.git/config` 也包含正确的 `[remote "origin"]`。因此这不是仓库不存在、网络不通或权限不足，而只是远程别名拼写错误。

### 6.3 正确命令

```bash
git push -u origin master
```

### 6.4 为什么报错文本容易误导

Git 将第一个位置参数 `orgin` 当作远程仓库别名或 URL。由于没有名为 `orgin` 的远程配置，它只能给出通用的“不是 Git 仓库/无法读取远程仓库/检查权限”提示。

看到该提示时，不应立刻修改权限或重建仓库，先核对命令拼写和：

```bash
git remote -v
git remote get-url origin
```

### 6.5 真正缺少 `origin` 时如何处理

若 `git remote -v` 完全没有输出：

```bash
git remote add origin http://192.168.72.25:3000/test/ds-middle.git
git push -u origin master
```

若报：

```text
error: remote origin already exists.
```

说明别名已经存在，不要重复 `add`，应修改 URL：

```bash
git remote set-url origin http://192.168.72.25:3000/test/ds-middle.git
git remote -v
```

## 7. 空仓库首次导入的推荐实施流程

以下流程保留本次团队实际采用的 `master` 分支。

### 7.1 全局初始化（每个 Linux 用户只需配置一次）

```bash
git config --global user.name "test"
git config --global user.email "test@test.edu.cn"
git config --global credential.helper store
git config --global init.defaultBranch master
```

> 如果团队决定全面使用 `main`，最后一项改成 `main`，并统一 Gitea 默认分支和脚本。

### 7.2 克隆空仓库

```bash
cd /root
git clone http://192.168.72.25:3000/test/charts.git charts
cd /root/charts
```

空仓库出现类似警告通常是正常的：

```text
warning: You appear to have cloned an empty repository.
```

立即核对：

```bash
pwd
git status
git remote -v
git branch --show-current
```

### 7.3 同步源目录

不推荐：

```bash
cp -r /root/coding-charts/* /root/charts/
```

原因：

- `*` 不包含 `.gitignore`、`.helmignore` 等隐藏文件。
- 不会删除目标端已存在、但源端已经删除的文件。
- 若复制方式不慎，可能把源目录的 `.git/` 带入目标仓库。

推荐先预演：

```bash
rsync -a --delete --dry-run \
  --exclude='.git/' \
  /root/coding-charts/ /root/charts/
```

确认清单无误后正式执行：

```bash
rsync -a --delete \
  --exclude='.git/' \
  /root/coding-charts/ /root/charts/
```

> `--delete` 会删除目标仓库中源目录不存在的文件。运行前必须核对源、目标路径，并优先执行 `--dry-run`。

### 7.4 检查、提交、推送

```bash
git status --short
git add -A
git diff --cached --stat

dstr=$(date '+%Y-%m-%d-%H-%M-%S')
git commit -m "sync coding charts ${dstr}"

git push -u origin master
```

首次 HTTP 推送会提示输入账号密码。建议密码位置输入专用 Gitea Access Token。成功后，`store` 会保存凭据。

### 7.5 推送后的验收

```bash
git status
git branch -vv
git remote -v
git log -1 --oneline --decorate
git ls-remote --heads origin
```

验收标准：

- `git status` 显示工作区干净。
- 当前分支跟踪 `origin/master`。
- `git ls-remote` 能看到 `refs/heads/master`。
- Gitea 页面能看到最新 commit 和预期文件。
- 未上传密码、Token、私钥、配置密文、大型二进制或无关构建产物。

## 8. 后续增量同步的推荐流程

若保留完整历史，每次同步新增一个 commit：

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

src_dir='/root/coding-charts/'
repo_dir='/root/charts/'
branch='master'

test -d "${src_dir}"
git -C "${repo_dir}" rev-parse --is-inside-work-tree >/dev/null
git -C "${repo_dir}" remote get-url origin >/dev/null

rsync -a --delete --dry-run --exclude='.git/' "${src_dir}" "${repo_dir}"

# 人工核对预演结果后，再取消下一行注释执行正式同步。
# rsync -a --delete --exclude='.git/' "${src_dir}" "${repo_dir}"

git -C "${repo_dir}" add -A

if git -C "${repo_dir}" diff --cached --quiet; then
  echo 'No changes to commit.'
  exit 0
fi

timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
git -C "${repo_dir}" commit -m "sync coding charts ${timestamp}"
git -C "${repo_dir}" push origin "${branch}"
```

正式用于自动化前，应删除人为确认步骤并通过固定路径、权限隔离、日志脱敏和失败告警来降低风险。

## 9. 关于 `git commit --amend` 和强制推送

原操作曾使用：

```bash
git commit --amend -m "force sync coding charts $dstr"
git push --force
```

`--amend` 会重写最后一个 commit，而不是创建新的提交。它有以下问题：

- 空仓库第一次提交时没有可 amend 的 commit。
- commit ID 会变化。
- 已拉取旧提交的同事会发生历史分叉。
- 配合 `--force` 可能覆盖他人已经推送的提交。

一般团队仓库建议使用普通提交：

```bash
git commit -m "sync coding charts $dstr"
git push
```

只有仓库被明确设计为“始终只保留一个快照提交”，并且没有多人协作时，才考虑改写历史。即便如此，也优先使用：

```bash
git push --force-with-lease origin master
```

`--force-with-lease` 会在远程分支已被别人更新时拒绝覆盖，比裸 `--force` 更安全，但仍需建立明确的仓库管理规则。

## 10. 通用排障顺序

任何 `push` 失败，建议按以下顺序检查，避免看到通用报错后直接重建仓库或强推。

### 第一步：确认当前位置和仓库状态

```bash
pwd
git rev-parse --show-toplevel
git status
```

### 第二步：确认当前分支和提交

```bash
git branch --show-current
git branch -vv
git log -1 --oneline --decorate
```

### 第三步：确认远程别名和 URL

```bash
git remote -v
git remote get-url origin
```

### 第四步：确认远程可访问性

```bash
git ls-remote origin
```

### 第五步：查看配置来源

```bash
git config --show-origin --get-regexp '^(user\.|credential\.|remote\.|branch\.)'
```

> 输出用于分享前必须检查并脱敏。不要运行或分享 `cat ~/.git-credentials`。

### 第六步：用明确参数重新执行

```bash
git push -u origin "$(git branch --show-current)"
```

确认成功并建立 upstream 后，后续才可简化为 `git push`。

## 11. 常见报错速查表

| 报错/现象 | 常见根因 | 首要检查 | 典型解决方式 |
| --- | --- | --- | --- |
| `src refspec main does not match any` | 本地没有 `main`，或还没有 commit | `git branch -a`、`git log -1` | 推送真实分支；或创建/重命名分支并先提交 |
| 加 `--force` 仍报 refspec 错误 | 本地引用不存在，不是远程历史冲突 | `git branch --show-current` | 不要强推，改用正确分支名 |
| 首次 push 要账号密码 | `store` 只会保存成功输入过的凭据 | `git config --show-origin --get-all credential.helper` | 正确输入一次账号和 Token |
| 每次 push 都要账号密码 | 执行用户、协议、主机、端口或 helper 不一致 | `whoami`、`git remote -v` | 统一执行用户和 URL，修正 helper |
| `'orgin' does not appear...` | 把 `origin` 拼成 `orgin` | 对比命令和 `git remote -v` | 使用 `git push -u origin master` |
| `'origin' does not appear...` | 确实没有 `origin` 或 URL 配置错误 | `git remote -v` | `remote add` 或 `remote set-url` |
| `remote origin already exists` | 重复添加远程 | `git remote -v` | `git remote set-url origin ...` |
| `nothing to commit` | 暂存区没有变化 | `git status --short` | 无变化则跳过提交；有遗漏则检查同步规则 |
| `non-fast-forward` / rejected | 远程有本地未包含的新提交 | `git fetch`、`git log --graph --all` | 先合并/变基；不要默认强推 |
| `Authentication failed` | 密码/Token 错误、过期或权限不足 | Gitea Token 权限、凭据缓存 | 清除旧凭据，使用有效 Token 重试 |

## 12. 团队防踩坑规范

1. 团队统一选择 `master` 或 `main`，并同步修改 Gitea 默认分支、Git 默认分支和脚本。
2. 复制 Gitea 页面命令时，仍要用 `git branch --show-current` 验证本地真实分支。
3. 推送前固定执行 `git status`、`git branch -vv`、`git remote -v`。
4. 首次使用 `-u` 建立 upstream，之后用 `git push`，减少手工拼写参数。
5. 目录镜像优先使用 `rsync`，必须先 `--dry-run`，并排除 `.git/`。
6. 使用 `git add -A`，确保新增、修改和删除都被纳入提交。
7. 默认保留正常 commit 历史，不把 `--amend` 和 `--force` 当作常规同步方式。
8. 自动化账号使用专用、最小权限、可撤销的 Access Token，不使用个人登录密码。
9. 禁止把凭据写入 Git 配置自定义项、远程 URL、脚本、README、日志和截图。
10. 提交前检查敏感信息和大文件；必要时启用 Gitea 分支保护与 Secret 扫描。

## 13. 本次事件结论

本次所有截图没有证明 Gitea 服务或仓库本身故障：

- `charts` 第一次失败是本地分支为 `master`，却推送了不存在的 `main`。
- 改为 `git push -u origin master` 后已成功推送。
- 首次要求输入用户名和密码是 `credential.helper store` 的预期行为；成功后凭据已保存。
- `user.name`、`user.email` 仅用于 commit 作者信息，`user.password` 不参与 HTTP 认证。
- `ds-middle` 的远程 `origin` 和 URL 均已正确配置，失败原因是命令把 `origin` 拼成了 `orgin`。
- 正确命令为 `git push -u origin master`。
- 截图中出现过明文密码，应按泄露处理，立即轮换并改用 Access Token。

## 14. 最简操作卡片

首次导入：

```bash
git clone http://192.168.72.25:3000/test/REPO.git
cd REPO
git remote -v
git branch --show-current

rsync -a --delete --dry-run --exclude='.git/' /path/to/source/ ./
# 确认无误后去掉 --dry-run 再执行一次

git add -A
git diff --cached --stat
git commit -m "initial import"
git push -u origin master
```

日常推送前：

```bash
git status
git branch -vv
git remote -v
git push
```

出现报错时，先记住三个对应关系：

```text
main/master  = 分支名
origin       = 远程仓库别名，注意拼写
账号/Token   = 远程认证，与 user.name/user.email 无关
```
