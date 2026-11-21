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
Write-Host "   [免责声明] 仅供技术交流，使用产生的任何风险由用户自行承担" -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor Cyan

$allPresets = @{
    "com.bilibili.azurlane"               = @{ Name = "B站官方服 / 官服"; IsCN = $true }
    "com.bilibili.blhx.mi"                = @{ Name = "小米渠道服"; IsCN = $true }
    "com.bilibili.blhx.uc"                = @{ Name = "九游 / UC 渠道服"; IsCN = $true }
    "com.bilibili.blhx.vivo"              = @{ Name = "vivo 渠道服"; IsCN = $true }
    "com.bilibili.blhx.huawei"            = @{ Name = "华为渠道服"; IsCN = $true }
    "com.bilibili.azurlane.huawei"        = @{ Name = "华为渠道服 (旧)"; IsCN = $true }
    "com.tencent.tmgp.bilibili.azurlane"  = @{ Name = "腾讯应用宝渠道服"; IsCN = $true }
    "com.bilibili.blhx.nearme.gamecenter" = @{ Name = "OPPO 渠道服"; IsCN = $true }
    "com.YoStarJP.AzurLane"               = @{ Name = "日服 (JP)"; IsCN = $false }
    "com.YoStarEN.AzurLane"               = @{ Name = "国际服 / 美服 (EN)"; IsCN = $false }
    "tw.sonet.bldhx"                      = @{ Name = "台服 (TW)"; IsCN = $false }
    "com.hkmanjuu.azurlane.gp"            = @{ Name = "台服 (TW Google Play)"; IsCN = $false }
    "com.xdg.p10010"                      = @{ Name = "韩服 (KR)"; IsCN = $false }
}

function Get-PkgDisplayName($pkg) {
    if ($allPresets.ContainsKey($pkg)) { return $allPresets[$pkg].Name }
    return "自定义区服"
}

function Find-MuMuAdb {
    $mumuProcs = Get-Process -Name "MuMuNxMain", "MuMuPlayer", "NemuPlayer" -ErrorAction SilentlyContinue
    foreach ($proc in $mumuProcs) {
        if ($proc.Path) {
            $baseDir = Split-Path $proc.Path
            $candidates = @(
                (Join-Path $baseDir "adb.exe"),
                (Join-Path (Split-Path $baseDir) "nx_device\15.0\shell\adb.exe"),
                (Join-Path (Split-Path $baseDir) "nx_device\12.0\shell\adb.exe"),
                (Join-Path (Split-Path $baseDir) "nx_main\adb.exe")
            )
            foreach ($c in $candidates) {
                if (Test-Path $c) { return $c }
            }
        }
    }

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MuMuPlayer*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\MuMuPlayer*"
    )
    foreach ($rp in $regPaths) {
        $keys = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            if ($k.InstallLocation) {
                $checkAdb1 = Join-Path $k.InstallLocation "nx_device\15.0\shell\adb.exe"
                if (Test-Path $checkAdb1) { return $checkAdb1 }
                $checkAdb2 = Join-Path $k.InstallLocation "nx_device\12.0\shell\adb.exe"
                if (Test-Path $checkAdb2) { return $checkAdb2 }
                $checkAdb3 = Join-Path $k.InstallLocation "nx_main\adb.exe"
                if (Test-Path $checkAdb3) { return $checkAdb3 }
            }
        }
    }

    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    foreach ($drv in $drives) {
        $checkList = @(
            (Join-Path $drv "Program Files\Netease\MuMuPlayer-12.0\nx_device\12.0\shell\adb.exe"),
            (Join-Path $drv "Program Files\Netease\MuMuPlayer-12.0\nx_main\adb.exe"),
            (Join-Path $drv "Program Files (x86)\Netease\MuMuPlayer-12.0\nx_main\adb.exe"),
            (Join-Path $drv "MuMuPlayer\nx_device\15.0\shell\adb.exe"),
            (Join-Path $drv "MuMuPlayer\nx_main\adb.exe")
        )
        foreach ($p in $checkList) {
            if (Test-Path $p) { return $p }
        }
    }

    $cmdAdb = Get-Command "adb.exe" -ErrorAction SilentlyContinue
    if ($cmdAdb) { return $cmdAdb.Source }
    return $null
}

function Get-DeviceAzurLanePackages($adb, $device) {
    $raw = & $adb -s $device shell "pm list packages -3"
    $list = @()
    foreach ($line in $raw) {
        if ($line -match "package:(.+)") {
            $p = $matches[1].Trim()
            if ($allPresets.ContainsKey($p) -or $p -like "*azurlane*" -or $p -like "*blhx*") {
                $ver = (& $adb -s $device shell "cat /data/media/0/Android/data/$p/files/version.txt 2>/dev/null").Trim()
                $dirCount = [int]((& $adb -s $device shell "ls /data/media/0/Android/data/$p/files/AssetBundles 2>/dev/null | wc -l").Trim())
                $list += [PSCustomObject]@{
                    Package  = $p
                    Name     = Get-PkgDisplayName $p
                    Version  = if ($ver) { $ver } else { "未初始化" }
                    DirCount = $dirCount
                    IsCN     = if ($allPresets.ContainsKey($p)) { $allPresets[$p].IsCN } else { $true }
                }
            }
        }
    }
    return $list
}

function Sync-PackageWithinDevice($adb, $device, $sourcePkg, $targetPkg, $isCN, $mode) {
    $srcDir = "/data/media/0/Android/data/$sourcePkg/files/AssetBundles"
    $dstDataDir = "/data/media/0/Android/data/$targetPkg"
    $dstFilesDir = "$dstDataDir/files"
    $dstBundleDir = "$dstFilesDir/AssetBundles"

    $targetUid = (& $adb -s $device shell "stat -c '%u' /data/data/$targetPkg 2>/dev/null || echo 10000").Trim()
    if (-not $targetUid) { $targetUid = "10000" }

    & $adb -s $device shell "mkdir -p $dstFilesDir" | Out-Null
    $cpOp = if ($mode -eq "2") { "cp -r" } else { "cp -al" }
    $script = "rm -rf $dstBundleDir && $cpOp $srcDir $dstFilesDir/"
    if ($isCN) {
        $script += " && cp -a /data/media/0/Android/data/$sourcePkg/files/hashes* $dstFilesDir/ && cp -a /data/media/0/Android/data/$sourcePkg/files/version* $dstFilesDir/"
    }
    $script += " && chmod -R 777 $dstFilesDir && chown -R ${targetUid}:ext_data_rw $dstDataDir"
    & $adb -s $device shell $script | Out-Null
}

function Invoke-SingleDeviceSync($adb, $device) {
    Write-Host "`n>>> 正在扫描设备 [$device] 内的碧蓝航线客户端..." -ForegroundColor Green
    $pkgs = Get-DeviceAzurLanePackages $adb $device
    if ($pkgs.Count -eq 0) {
        Write-Host "[错误] 设备 [$device] 内未检测到任何碧蓝航线客户端！" -ForegroundColor Red
        return
    }

    $sourceObj = $pkgs | Where-Object { $_.DirCount -ge 150 } | Select-Object -First 1
    if (-not $sourceObj) {
        Write-Host "`n[核心前提未满足] 设备中未能找到拥有完整资源（约 29GB）的客户端！" -ForegroundColor Red
        Write-Host "若另一台多开设备有最新完整资源，请重启脚本选择【跨设备增量同步】。" -ForegroundColor Yellow
        return
    }

    Write-Host "  [√] 已选定完整数据源: $($sourceObj.Name) [$($sourceObj.Package)] (版本: $($sourceObj.Version))" -ForegroundColor Cyan
    $candidates = @($pkgs | Where-Object { $_.Package -ne $sourceObj.Package })

    $targetsToSync = @()
    if ($candidates.Count -eq 0) {
        $customChoice = Read-Host "`n未检测到其他区服，是否手动输入自定义包名进行映射？(Y/N，默认 N)"
        if ($customChoice -match "^[Yy]") {
            $cPkg = (Read-Host "请输入目标包名").Trim()
            if ($cPkg) { $targetsToSync += [PSCustomObject]@{ Package = $cPkg; Name = Get-PkgDisplayName $cPkg; IsCN = $true } }
        }
    } else {
        Write-Host "`n请选择要同步资源的目标区服：" -ForegroundColor Yellow
        Write-Host "  [A] 一键同步到所有其他已安装区服 (推荐)" -ForegroundColor Green
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "  [$($i + 1)] $($candidates[$i].Name) [$($candidates[$i].Package)] (当前版本: $($candidates[$i].Version))"
        }
        Write-Host "  [0] 手动输入其他自定义包名"

        $sel = Read-Host "`n请输入选项 (A 或数字，默认 A)"
        if ($sel -eq "" -or $sel -match "^[Aa]") {
            $targetsToSync = $candidates
        } elseif ($sel -eq "0") {
            $cPkg = (Read-Host "请输入目标包名").Trim()
            if ($cPkg) { $targetsToSync += [PSCustomObject]@{ Package = $cPkg; Name = Get-PkgDisplayName $cPkg; IsCN = $true } }
        } else {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $candidates.Count) { $targetsToSync += $candidates[$idx] }
            else { $targetsToSync = $candidates }
        }
    }

    if ($targetsToSync.Count -eq 0) { return }

    Write-Host "`n请选择资源共享模式：" -ForegroundColor Yellow
    Write-Host "  [1] 底层硬链接模式 (推荐：零额外空间占用，1~2 秒完成)" -ForegroundColor Cyan
    Write-Host "  [2] 模拟器内完整复制 (额外占用 29GB，约 1~2 分钟)" -ForegroundColor Cyan
    $mode = Read-Host "请输入模式 (1 或 2，默认 1)"
    if ($mode -ne "2") { $mode = "1" }

    foreach ($t in $targetsToSync) {
        Write-Host "  -> 正在同步到 $($t.Name) [$($t.Package)]..." -ForegroundColor Cyan
        & $adb -s $device shell "am force-stop $($t.Package)" | Out-Null
        Sync-PackageWithinDevice $adb $device $sourceObj.Package $t.Package $t.IsCN $mode
        Write-Host "  [√] $($t.Name) 同步完成！" -ForegroundColor Green
    }
}

function Invoke-CrossDeviceDiffSync($adb, $devices) {
    Write-Host "`n>>> 正在扫描所有已连接设备上的碧蓝航线版本..." -ForegroundColor Green
    $deviceMap = @{}
    for ($i = 0; $i -lt $devices.Count; $i++) {
        $dev = $devices[$i]
        $pkgs = Get-DeviceAzurLanePackages $adb $dev
        $deviceMap[$dev] = $pkgs
        Write-Host "`n  设备 [$($i + 1)] ($dev):" -ForegroundColor Yellow
        foreach ($p in $pkgs) {
            Write-Host "    - $($p.Name) [$($p.Package)] | 版本: $($p.Version) | 资源目录数: $($p.DirCount)"
        }
    }

    $srcIdx = [int](Read-Host "`n请选择【源设备】编号（拥有最新完整资源的设备，默认 1）") - 1
    if ($srcIdx -lt 0 -or $srcIdx -ge $devices.Count) { $srcIdx = 0 }
    $srcDev = $devices[$srcIdx]

    $srcPkgs = @($deviceMap[$srcDev] | Where-Object { $_.DirCount -ge 150 })
    if ($srcPkgs.Count -eq 0) {
        Write-Host "[错误] 源设备 [$srcDev] 上没有完整资源包！" -ForegroundColor Red
        return
    }
    $srcPkgObj = $srcPkgs[0]
    if ($srcPkgs.Count -gt 1) {
        Write-Host "`n源设备上有多个完整资源客户端，请选择作为更新基准的源服：" -ForegroundColor Yellow
        for ($j = 0; $j -lt $srcPkgs.Count; $j++) {
            Write-Host "  [$($j + 1)] $($srcPkgs[$j].Name) [$($srcPkgs[$j].Package)] (版本: $($srcPkgs[$j].Version))"
        }
        $pIdx = [int](Read-Host "请输入编号 (默认 1)") - 1
        if ($pIdx -ge 0 -and $pIdx -lt $srcPkgs.Count) { $srcPkgObj = $srcPkgs[$pIdx] }
    }

    $dstDevices = @($devices | Where-Object { $_ -ne $srcDev })
    foreach ($dstDev in $dstDevices) {
        $dstPkgs = $deviceMap[$dstDev]
        if ($dstPkgs.Count -eq 0) {
            Write-Host "`n[跳过] 目标设备 [$dstDev] 未安装碧蓝航线。" -ForegroundColor Yellow
            continue
        }

        Write-Host "`n>>> 正在对比差异并同步 [$srcDev ($($srcPkgObj.Version))] -> [$dstDev]..." -ForegroundColor Cyan
        foreach ($dp in $dstPkgs) { & $adb -s $dstDev shell "am force-stop $($dp.Package)" | Out-Null }

        $primaryDst = $dstPkgs | Where-Object { $_.Package -eq $srcPkgObj.Package } | Select-Object -First 1
        if (-not $primaryDst) {
            $primaryDst = $dstPkgs | Sort-Object DirCount -Descending | Select-Object -First 1
        }

        $tmpDir = Join-Path $env:TEMP ("azurlane_diff_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
        New-Item -ItemType Directory -Force -Path "$tmpDir\src", "$tmpDir\dst" | Out-Null

        try {
            $srcFilesRoot = "/data/media/0/Android/data/$($srcPkgObj.Package)/files"
            $dstFilesRoot = "/data/media/0/Android/data/$($primaryDst.Package)/files"

            Write-Host "  1. 拉取源端与目标端哈希校验清单..." -ForegroundColor Gray
            & $adb -s $srcDev shell "ls $srcFilesRoot/hashes*.csv $srcFilesRoot/version*.txt 2>/dev/null" | ForEach-Object {
                $f = $_.Trim()
                if ($f) { & $adb -s $srcDev pull $f "$tmpDir\src\" | Out-Null }
            }
            & $adb -s $dstDev shell "ls $dstFilesRoot/hashes*.csv 2>/dev/null" | ForEach-Object {
                $f = $_.Trim()
                if ($f) { & $adb -s $dstDev pull $f "$tmpDir\dst\" | Out-Null }
            }

            $oldMap = @{}
            Get-ChildItem "$tmpDir\dst\hashes*.csv" -ErrorAction SilentlyContinue | ForEach-Object {
                Get-Content $_.FullName | ForEach-Object {
                    $parts = $_ -split ','
                    if ($parts.Length -ge 3) { $oldMap[$parts[0]] = "$($parts[1]),$($parts[2])" }
                }
            }

            $newMap = @{}
            $diffList = [System.Collections.Generic.List[string]]::new()
            $diffBytes = [long]0
            Get-ChildItem "$tmpDir\src\hashes*.csv" | ForEach-Object {
                Get-Content $_.FullName | ForEach-Object {
                    $parts = $_ -split ','
                    if ($parts.Length -ge 3) {
                        $path = $parts[0]
                        $sig = "$($parts[1]),$($parts[2])"
                        $newMap[$path] = $true
                        if (-not $oldMap.ContainsKey($path) -or $oldMap[$path] -ne $sig) {
                            $diffList.Add($path)
                            $diffBytes += [long]$parts[1]
                        }
                    }
                }
            }
            $diffUnique = @($diffList | Select-Object -Unique)
            $obsoleteList = @($oldMap.Keys | Where-Object { -not $newMap.ContainsKey($_) })

            if ($obsoleteList.Count -gt 0) {
                [System.IO.File]::WriteAllText("$tmpDir\del_list.txt", ($obsoleteList -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
                & $adb -s $dstDev push "$tmpDir\del_list.txt" /data/local/tmp/del_list.txt | Out-Null
                & $adb -s $dstDev shell "cd $dstFilesRoot/AssetBundles 2>/dev/null && while IFS= read -r f; do rm -f `"`$f`"; done < /data/local/tmp/del_list.txt; rm -f /data/local/tmp/del_list.txt" | Out-Null
            }

            if ($diffUnique.Count -gt 0) {
                $sizeMb = [math]::Round($diffBytes / 1MB, 2)
                Write-Host "  2. 发现 $($diffUnique.Count) 个新增/变更资源文件（约 $sizeMb MB），正在打包传输..." -ForegroundColor Yellow

                [System.IO.File]::WriteAllText("$tmpDir\diff_list.txt", ($diffUnique -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
                & $adb -s $srcDev push "$tmpDir\diff_list.txt" /data/local/tmp/diff_list.txt | Out-Null

                $packCmd = "cd $srcFilesRoot/AssetBundles && rm -f /data/local/tmp/diff_existing.txt /data/local/tmp/diff_assets.tar && " +
                           "while IFS= read -r f; do [ -f `"`$f`" ] && echo `"`$f`"; done < /data/local/tmp/diff_list.txt > /data/local/tmp/diff_existing.txt && " +
                           "tar -cf /data/local/tmp/diff_assets.tar -T /data/local/tmp/diff_existing.txt"
                & $adb -s $srcDev shell $packCmd | Out-Null
                & $adb -s $srcDev pull /data/local/tmp/diff_assets.tar "$tmpDir\diff_assets.tar" | Out-Null
                & $adb -s $srcDev shell "rm -f /data/local/tmp/diff_assets.tar /data/local/tmp/diff_list.txt /data/local/tmp/diff_existing.txt" | Out-Null

                Write-Host "  3. 正在写入目标设备 [$dstDev] 并解除旧硬链接冲突..." -ForegroundColor Gray
                & $adb -s $dstDev push "$tmpDir\diff_assets.tar" /data/local/tmp/diff_assets.tar | Out-Null

                foreach ($other in $dstPkgs) {
                    if ($other.Package -ne $primaryDst.Package) {
                        & $adb -s $dstDev shell "rm -rf /data/media/0/Android/data/$($other.Package)/files/AssetBundles" | Out-Null
                    }
                }

                & $adb -s $dstDev shell "mkdir -p $dstFilesRoot/AssetBundles && tar -xf /data/local/tmp/diff_assets.tar -C $dstFilesRoot/AssetBundles && rm -f /data/local/tmp/diff_assets.tar" | Out-Null
            } else {
                Write-Host "  2. 资源文件已完全一致，仅同步版本校验文件..." -ForegroundColor Green
            }

            Write-Host "  4. 同步校验文件、修复权限并对设备内其他区服建立硬链接..." -ForegroundColor Gray
            Get-ChildItem "$tmpDir\src\*" | ForEach-Object {
                & $adb -s $dstDev push $_.FullName "$dstFilesRoot/$($_.Name)" | Out-Null
            }
            $pUid = (& $adb -s $dstDev shell "stat -c '%u' /data/data/$($primaryDst.Package) 2>/dev/null || echo 10000").Trim()
            if (-not $pUid) { $pUid = "10000" }
            & $adb -s $dstDev shell "chmod -R 777 $dstFilesRoot && chown -R ${pUid}:ext_data_rw /data/media/0/Android/data/$($primaryDst.Package)" | Out-Null

            foreach ($other in $dstPkgs) {
                if ($other.Package -ne $primaryDst.Package) {
                    Sync-PackageWithinDevice $adb $dstDev $primaryDst.Package $other.Package $other.IsCN "1"
                    Write-Host "    [√] 设备内 $($other.Name) 已通过硬链接共享最新资源！" -ForegroundColor Green
                }
            }
            Write-Host "  [√] 设备 [$dstDev] 跨设备增量同步完成！" -ForegroundColor Green
        } finally {
            Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------------------------
# 主流程入口
# ------------------------------------------------------------------------------
Write-Host "`n[1/3] 正在搜索并定位模拟器 ADB 通信环境..." -ForegroundColor Green
$ADB_PATH = Find-MuMuAdb

while (-not $ADB_PATH -or -not (Test-Path $ADB_PATH)) {
    Write-Host "[提示] 未能自动定位 MuMu 模拟器的 adb.exe！" -ForegroundColor Yellow
    $userInput = Read-Host "请输入 MuMu 模拟器安装根目录 (例如 C:\Program Files\Netease\MuMuPlayer-12.0)"
    if ($userInput) {
        $check1 = Join-Path $userInput "nx_device\15.0\shell\adb.exe"
        $check2 = Join-Path $userInput "nx_main\adb.exe"
        if (Test-Path $check1) { $ADB_PATH = $check1; break }
        if (Test-Path $check2) { $ADB_PATH = $check2; break }
    }
}
Write-Host "  -> 已定位 ADB: $ADB_PATH" -ForegroundColor Gray

Write-Host "`n[2/3] 正在探测所有运行中的模拟器实例..." -ForegroundColor Green
$candidatePorts = @(16384, 16416, 16448, 16480, 7555, 5555)
$listenPorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
               Where-Object { $_.LocalPort -ge 16384 -and $_.LocalPort -le 16600 } |
               Select-Object -ExpandProperty LocalPort -Unique
if ($listenPorts) {
    $candidatePorts = @($listenPorts + $candidatePorts | Select-Object -Unique)
}

$connectedDevices = @()
foreach ($port in $candidatePorts) {
    $dev = "127.0.0.1:$port"
    & $ADB_PATH connect $dev | Out-Null
    Start-Sleep -Milliseconds 300
    $state = (& $ADB_PATH -s $dev get-state 2>$null)
    if ($state -eq "device") {
        & $ADB_PATH -s $dev root | Out-Null
        Start-Sleep -Milliseconds 600
        & $ADB_PATH connect $dev | Out-Null
        $connectedDevices += $dev
    }
}

if ($connectedDevices.Count -eq 0) {
    $devs = (& $ADB_PATH devices) | Where-Object { $_ -match "\tdevice" }
    foreach ($d in $devs) {
        $devId = ($d -split "`t")[0]
        & $ADB_PATH -s $devId root | Out-Null
        $connectedDevices += $devId
    }
}

if ($connectedDevices.Count -eq 0) {
    Write-Host "[错误] 无法连接到正在运行的 MuMu 模拟器，请确认模拟器已打开！" -ForegroundColor Red
    Pause
    Exit
}

Write-Host "  -> 共检测到 $($connectedDevices.Count) 台在线设备: $($connectedDevices -join ', ')" -ForegroundColor Cyan

Write-Host "`n[3/3] 进入同步工作流..." -ForegroundColor Green
if ($connectedDevices.Count -ge 2) {
    Write-Host "`n检测到您同时开启了多台模拟器设备，请选择工作模式：" -ForegroundColor Yellow
    Write-Host "  [1] 跨设备增量同步（将设备 A 最新资源增量同步到设备 B，并在 B 内部自动硬链接，推荐）" -ForegroundColor Green
    Write-Host "  [2] 单设备内换服（仅操作某一台指定设备内部）" -ForegroundColor Cyan
    $workMode = Read-Host "请输入选择 (1 或 2，默认 1)"
    if ($workMode -eq "2") {
        for ($i = 0; $i -lt $connectedDevices.Count; $i++) {
            Write-Host "  [$($i + 1)] $($connectedDevices[$i])"
        }
        $dIdx = [int](Read-Host "请选择要操作的设备编号 (默认 1)") - 1
        if ($dIdx -lt 0 -or $dIdx -ge $connectedDevices.Count) { $dIdx = 0 }
        Invoke-SingleDeviceSync $ADB_PATH $connectedDevices[$dIdx]
    } else {
        Invoke-CrossDeviceDiffSync $ADB_PATH $connectedDevices
    }
} else {
    Invoke-SingleDeviceSync $ADB_PATH $connectedDevices[0]
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "   🎉 碧蓝航线资源跨服同步流程已全部完成！                  " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Pause
