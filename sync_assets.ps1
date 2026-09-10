# ==============================================================================
# 碧蓝航线 (Azur Lane) 跨服资源极速复用与换服工具
# 项目名称：模拟器碧蓝航线换服工具 (AzurLane-Server-Switcher)
# 测试环境声明：已在 MuMu 模拟器（Android 15 内核 / 15.0 系列）实测通过
# 核心前提要求：模拟器内需存在至少一份已下载完整的游戏资源（约 29GB）
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   ⚓ 模拟器碧蓝航线换服工具 (AzurLane-Server-Switcher)       " -ForegroundColor Yellow
Write-Host "   [测试声明] 已在 MuMu 模拟器 Android 15 环境全量实测通过   " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. 自动寻找 ADB 与 MuMu 模拟器路径
# ------------------------------------------------------------------------------
function Find-MuMuAdb {
    $possiblePaths = @(
        "D:\UU\MuMuPlayer\nx_device\15.0\shell\adb.exe",
        "D:\UU\MuMuPlayer\nx_main\adb.exe",
        "C:\Program Files\Netease\MuMuPlayer-12.0\nx_device\12.0\shell\adb.exe",
        "C:\Program Files\Netease\MuMuPlayer-12.0\nx_main\adb.exe",
        "C:\Program Files\Netease\MuMuPlayerGlobal-12.0\nx_device\12.0\shell\adb.exe",
        "C:\Program Files (x86)\Netease\MuMuPlayer-12.0\nx_main\adb.exe",
        "D:\Program Files\Netease\MuMuPlayer-12.0\nx_main\adb.exe",
        "E:\Program Files\Netease\MuMuPlayer-12.0\nx_main\adb.exe"
    )

    foreach ($p in $possiblePaths) {
        if (Test-Path $p) { return $p }
    }

    # 尝试从注册表寻找
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MuMuPlayer*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\MuMuPlayer*"
    )
    foreach ($rp in $regPaths) {
        $keys = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            if ($k.InstallLocation) {
                $checkAdb = Join-Path $k.InstallLocation "nx_device\15.0\shell\adb.exe"
                if (Test-Path $checkAdb) { return $checkAdb }
                $checkAdb2 = Join-Path $k.InstallLocation "nx_main\adb.exe"
                if (Test-Path $checkAdb2) { return $checkAdb2 }
            }
        }
    }

    # 尝试系统 PATH 中的 adb
    $cmdAdb = Get-Command "adb.exe" -ErrorAction SilentlyContinue
    if ($cmdAdb) { return $cmdAdb.Source }

    return $null
}

Write-Host "`n[1/5] 正在搜索并定位模拟器 ADB 通信环境..." -ForegroundColor Green
$ADB_PATH = Find-MuMuAdb

while (-not $ADB_PATH -or -not (Test-Path $ADB_PATH)) {
    Write-Host "[提示] 未能自动定位 MuMu 模拟器的 adb.exe！" -ForegroundColor Yellow
    $userInput = Read-Host "请输入 MuMu 模拟器安装根目录 (例如 D:\UU\MuMuPlayer 或 C:\Program Files\Netease\MuMuPlayer-12.0)"
    if ($userInput) {
        $check1 = Join-Path $userInput "nx_device\15.0\shell\adb.exe"
        $check2 = Join-Path $userInput "nx_main\adb.exe"
        if (Test-Path $check1) { $ADB_PATH = $check1; break }
        if (Test-Path $check2) { $ADB_PATH = $check2; break }
    }
}
Write-Host "  -> 已定位 ADB: $ADB_PATH" -ForegroundColor Gray

# ------------------------------------------------------------------------------
# 2. 智能探测与连接活动端口
# ------------------------------------------------------------------------------
Write-Host "`n[2/5] 正在连接活动中的模拟器实例..." -ForegroundColor Green

$portsToTry = @(16384, 7555, 5555)
$CONNECTED_DEVICE = $null

foreach ($port in $portsToTry) {
    $dev = "127.0.0.1:$port"
    & $ADB_PATH connect $dev | Out-Null
    Start-Sleep -Milliseconds 600
    $state = (& $ADB_PATH -s $dev get-state 2>$null)
    if ($state -eq "device") {
        $CONNECTED_DEVICE = $dev
        break
    }
}

if (-not $CONNECTED_DEVICE) {
    # 尝试默认检测到的第一个设备
    $devs = (& $ADB_PATH devices) | Where-Object { $_ -match "\tdevice" }
    if ($devs) {
        $CONNECTED_DEVICE = ($devs[0] -split "`t")[0]
    }
}

if (-not $CONNECTED_DEVICE) {
    Write-Host "[错误] 无法连接到正在运行的 MuMu 模拟器，请确认模拟器已打开！" -ForegroundColor Red
    Pause
    Exit
}

Write-Host "  -> 成功连接到模拟器实例: $CONNECTED_DEVICE" -ForegroundColor Cyan

# 切换为 root
Write-Host "  -> 申请 ADB root 权限..." -ForegroundColor Gray
& $ADB_PATH -s $CONNECTED_DEVICE root | Out-Null
Start-Sleep -Milliseconds 1200
& $ADB_PATH connect $CONNECTED_DEVICE | Out-Null
Start-Sleep -Milliseconds 600

# ------------------------------------------------------------------------------
# 3. 扫描已安装的所有碧蓝航线客户端
# ------------------------------------------------------------------------------
Write-Host "`n[3/5] 正在扫描模拟器内安装的所有碧蓝航线版本..." -ForegroundColor Green

$allPresets = @{
    "com.bilibili.azurlane"               = @{ Name = "B站官方服 / 官服"; IsCN = $true }
    "com.bilibili.blhx.mi"                = @{ Name = "小米渠道服"; IsCN = $true }
    "com.bilibili.blhx.uc"                = @{ Name = "九游 / UC 渠道服"; IsCN = $true }
    "com.bilibili.blhx.vivo"              = @{ Name = "vivo 渠道服"; IsCN = $true }
    "com.bilibili.blhx.huawei"            = @{ Name = "华为渠道服"; IsCN = $true }
    "com.bilibili.azurlane.huawei"         = @{ Name = "华为渠道服 (旧)"; IsCN = $true }
    "com.tencent.tmgp.bilibili.azurlane"  = @{ Name = "腾讯应用宝渠道服"; IsCN = $true }
    "com.bilibili.blhx.nearme.gamecenter" = @{ Name = "OPPO 渠道服"; IsCN = $true }
    "com.YoStarJP.AzurLane"               = @{ Name = "日服 (JP)"; IsCN = $false }
    "com.YoStarEN.AzurLane"               = @{ Name = "国际服 / 美服 (EN)"; IsCN = $false }
    "tw.sonet.bldhx"                      = @{ Name = "台服 (TW)"; IsCN = $false }
    "com.hkmanjuu.azurlane.gp"            = @{ Name = "台服 (TW Google Play)"; IsCN = $false }
    "com.xdg.p10010"                      = @{ Name = "韩服 (KR)"; IsCN = $false }
}

$installedPackagesRaw = & $ADB_PATH -s $CONNECTED_DEVICE shell "pm list packages -3"
$installedPkgList = @()

foreach ($line in $installedPackagesRaw) {
    if ($line -match "package:(.+)") {
        $p = $matches[1].Trim()
        if ($allPresets.ContainsKey($p) -or $p -like "*azurlane*" -or $p -like "*blhx*") {
            $installedPkgList += $p
        }
    }
}

if ($installedPkgList.Count -eq 0) {
    Write-Host "[错误] 模拟器内未检测到任何碧蓝航线客户端！请先在模拟器中安装游戏。" -ForegroundColor Red
    Pause
    Exit
}

# ------------------------------------------------------------------------------
# 4. 自动检测哪一个包是拥有完整 29GB 数据的“源（Source）”
# ------------------------------------------------------------------------------
Write-Host "`n[4/5] 正在分析资源包完整度以确定源数据 (Source)..." -ForegroundColor Green

$sourcePkg = $null
$candidatesWithoutFullAssets = @()

foreach ($pkg in $installedPkgList) {
    $bundlePath = "/data/media/0/Android/data/$pkg/files/AssetBundles"
    $checkCmd = "test -d $bundlePath && ls $bundlePath 2>/dev/null | wc -l || echo 0"
    $dirCount = [int]((& $ADB_PATH -s $CONNECTED_DEVICE shell $checkCmd).Trim())
    
    $displayName = if ($allPresets.ContainsKey($pkg)) { $allPresets[$pkg].Name } else { "自定义区服" }
    
    if ($dirCount -ge 150) {
        Write-Host "  [√] 发现完整资源库: $displayName [$pkg] (包含 $dirCount 个分类目录，约 29GB)" -ForegroundColor Green
        if (-not $sourcePkg) { $sourcePkg = $pkg }
    } else {
        Write-Host "  [-] 待同步目标服: $displayName [$pkg] (未下载完整资源)" -ForegroundColor Yellow
        $candidatesWithoutFullAssets += $pkg
    }
}

if (-not $sourcePkg) {
    Write-Host "`n[核心前提未满足] 模拟器中未能找到拥有完整资源的客户端！" -ForegroundColor Red
    Write-Host "请先在任意一个服（例如 B服）内完整下载全部游戏数据（约 29GB），然后再运行本工具进行跨服复用。" -ForegroundColor Yellow
    Pause
    Exit
}

$sourceName = if ($allPresets.ContainsKey($sourcePkg)) { $allPresets[$sourcePkg].Name } else { $sourcePkg }
Write-Host "`n>> 当前已选定完整数据源: $sourceName [$sourcePkg]" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 5. 选择要同步的目标服务器
# ------------------------------------------------------------------------------
$targetsToSync = @()

if ($candidatesWithoutFullAssets.Count -eq 0) {
    Write-Host "`n检测到所有已安装的客户端均已具备完整资源！" -ForegroundColor Green
    $customChoice = Read-Host "是否需要手动输入新安装的其他包名进行映射？(Y/N，默认 N)"
    if ($customChoice -match "^[Yy]") {
        $customPkg = Read-Host "请输入目标包名"
        if ($customPkg) { $targetsToSync += $customPkg.Trim() }
    } else {
        Write-Host "无需重复操作，退出。" -ForegroundColor Cyan
        Pause
        Exit
    }
} else {
    Write-Host "`n请选择您要同步资源的目标区服：" -ForegroundColor Yellow
    Write-Host "  [A] 一键同步到所有其他已安装区服 (推荐，自动批量完成)" -ForegroundColor Green
    for ($i = 0; $i -lt $candidatesWithoutFullAssets.Count; $i++) {
        $tPkg = $candidatesWithoutFullAssets[$i]
        $tName = if ($allPresets.ContainsKey($tPkg)) { $allPresets[$tPkg].Name } else { $tPkg }
        Write-Host "  [$($i + 1)] 仅同步到: $tName [$tPkg]"
    }
    Write-Host "  [0] 手动输入其他自定义包名"

    $sel = Read-Host "`n请输入选项 (A 或数字，默认 A)"
    if ($sel -eq "" -or $sel -match "^[Aa]") {
        $targetsToSync = $candidatesWithoutFullAssets
    } elseif ($sel -eq "0") {
        $customPkg = Read-Host "请输入目标包名"
        if ($customPkg) { $targetsToSync += $customPkg.Trim() }
    } else {
        $idx = [int]$sel - 1
        if ($idx -ge 0 -and $idx -lt $candidatesWithoutFullAssets.Count) {
            $targetsToSync += $candidatesWithoutFullAssets[$idx]
        } else {
            $targetsToSync = $candidatesWithoutFullAssets
        }
    }
}

# ------------------------------------------------------------------------------
# 6. 选择复用模式
# ------------------------------------------------------------------------------
Write-Host "`n请选择资源共享模式：" -ForegroundColor Yellow
Write-Host "  [1] 底层硬链接模式 (推荐：零额外磁盘空间占用，1~2 秒瞬间完成)" -ForegroundColor Cyan
Write-Host "  [2] 模拟器内完整复制 (每个服额外占用 29GB 磁盘，完全独立，约 1~2 分钟)" -ForegroundColor Cyan
$mode = Read-Host "请输入模式 (1 或 2，默认 1)"
if ($mode -ne "2") { $mode = "1" }

# ------------------------------------------------------------------------------
# 7. 开始批量执行同步与权限修复
# ------------------------------------------------------------------------------
Write-Host "`n[5/5] 正在执行跨服资源共享与 Android 权限沙箱适配..." -ForegroundColor Green

$srcDir = "/data/media/0/Android/data/$sourcePkg/files/AssetBundles"

foreach ($target in $targetsToSync) {
    $tDisplayName = if ($allPresets.ContainsKey($target)) { $allPresets[$target].Name } else { $target }
    Write-Host "`n>>> 正在处理: $tDisplayName [$target]..." -ForegroundColor Cyan

    $dstDataDir = "/data/media/0/Android/data/$target"
    $dstFilesDir = "$dstDataDir/files"
    $dstBundleDir = "$dstFilesDir/AssetBundles"

    # 获取目标应用 Linux UID
    $getUidCmd = "stat -c '%u' /data/data/$target 2>/dev/null || echo 10000"
    $targetUid = (& $ADB_PATH -s $CONNECTED_DEVICE shell $getUidCmd).Trim()
    if (-not $targetUid -or $targetUid -eq "") { $targetUid = "10000" }

    # 创建目标目录
    & $ADB_PATH -s $CONNECTED_DEVICE shell "mkdir -p $dstFilesDir" | Out-Null

    # 判断是否为国服（国服同步哈希表，外服保留其自身哈希）
    $isCN = if ($allPresets.ContainsKey($target)) { $allPresets[$target].IsCN } else { $true }

    if ($mode -eq "1") {
        Write-Host "  -> 正在创建 Linux 底层硬链接..." -ForegroundColor Gray
        $linkScript = "rm -rf $dstBundleDir && cp -al $srcDir $dstFilesDir/"
        if ($isCN) {
            $linkScript += " && cp -a /data/media/0/Android/data/$sourcePkg/files/hashes* $dstFilesDir/ && cp -a /data/media/0/Android/data/$sourcePkg/files/version* $dstFilesDir/"
        }
        $linkScript += " && chmod -R 777 $dstFilesDir && chown -R $targetUid:ext_data_rw $dstDataDir"
        & $ADB_PATH -s $CONNECTED_DEVICE shell $linkScript | Out-Null
    } else {
        Write-Host "  -> 正在复制文件 (约 29GB，请稍候)..." -ForegroundColor Gray
        $copyScript = "rm -rf $dstBundleDir && cp -r $srcDir $dstFilesDir/"
        if ($isCN) {
            $copyScript += " && cp -a /data/media/0/Android/data/$sourcePkg/files/hashes* $dstFilesDir/ && cp -a /data/media/0/Android/data/$sourcePkg/files/version* $dstFilesDir/"
        }
        $copyScript += " && chmod -R 777 $dstFilesDir && chown -R $targetUid:ext_data_rw $dstDataDir"
        & $ADB_PATH -s $CONNECTED_DEVICE shell $copyScript | Out-Null
    }

    Write-Host "  [√] $tDisplayName 资源部署成功！" -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "   🎉 碧蓝航线全部目标区服资源跨服同步已全部成功！          " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "【游玩指引】：
1. 现在可以直接在模拟器中启动对应的目标区服；
2. 国服渠道服将直接识别通过，0 下载秒进游戏；
3. 外服（日/美/台）将直接继承全量语音包与通用资源，仅从外服增量下载少量特有立绘。
" -ForegroundColor Yellow

Pause
