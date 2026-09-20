# env-doctor.ps1 —— 探测/登记在线调试工具链(仅 Windows + ST-Link + STM32F4)
# 探测策略: PATH 优先 -> 递归搜常见安装位 -> 命中登记绝对路径到 config/toolchain.json
# 全程只读探测 + 写本包 config, 不改 PATH、不碰全局、不自动安装(安装命令仅打印, 由 SKILL 逐步征得同意再执行)
# 用法: env-doctor.ps1 [-Register] [-InstallGuide] [-Dwarf <axf路径>] [-Clean]
#   -Register    探测命中后把绝对路径写入 config/toolchain.json(不存在则基于 example 生成)
#   -InstallGuide 打印缺失项的建议安装命令(winget), 不执行
#   -Dwarf       对给定 axf 跑 DWARF 源码级门禁(转发 dwarf-check.ps1)
#   -Clean       结束残留 openocd/gdb 进程
# 版权见 LICENSE(MIT)
param([switch]$Register, [switch]$InstallGuide, [string]$Dwarf, [switch]$Clean)
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\lib\common.ps1"

$pkg = Get-PkgRoot

# 返回某可执行文件的绝对路径: 先 PATH, 再在候选根里递归搜(过滤名)
function Find-Exe([string]$pathName, [string]$fileName, [string[]]$roots) {
    $c = Get-Command $pathName -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($r in $roots) {
        if (Test-Path $r) {
            $hit = Get-ChildItem $r -Recurse -Filter $fileName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    return $null
}

# 从 openocd.exe 位置定位其脚本目录(含 interface/stlink.cfg 的那层), 兼容不同打包布局
function Find-OpenocdScripts([string]$exe) {
    if (-not $exe) { return $null }
    $root = Split-Path (Split-Path $exe -Parent) -Parent   # bin 的上一级
    $probe = Get-ChildItem $root -Recurse -Filter "stlink.cfg" -ErrorAction SilentlyContinue |
             Where-Object { $_.Directory.Name -eq 'interface' } | Select-Object -First 1
    if ($probe) { return $probe.Directory.Parent.FullName }
    return $null
}

$roots = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
    "C:\Program Files", "C:\Program Files (x86)",
    "$env:USERPROFILE\scoop\apps", "C:\ProgramData\chocolatey\bin"
)

$oce   = Find-Exe "openocd" "openocd.exe" $roots
$gdb   = Find-Exe "arm-none-eabi-gdb" "arm-none-eabi-gdb.exe" $roots
$scr   = Find-OpenocdScripts $oce
$node  = (Get-Command node -ErrorAction SilentlyContinue).Source

# 端口从配置读(缺 toolchain.json 时用 example 默认); 静默回退不告警
$gdbPort = 3333; $telnetPort = 4444
try {
    $cfgPath = Join-Path $pkg "config/toolchain.json"
    if (-not (Test-Path $cfgPath)) { $cfgPath = Join-Path $pkg "config/toolchain.example.json" }
    $tc0 = Get-Content -Raw -Encoding UTF8 $cfgPath | ConvertFrom-Json
    if ($tc0.gdbPort) { $gdbPort = $tc0.gdbPort }
    if ($tc0.telnetPort) { $telnetPort = $tc0.telnetPort }
} catch { }

Write-Host "==== 工具链探测 (PATH 优先 -> 递归搜常见安装位) ===="
Write-Host ("[NODE]  {0}" -f ($(if ($node) {"$node"} else {"[MISS] 未找到 node (mcp-gdb 需要, 请安装 Node.js LTS)"})))
Write-Host ("[OOCD]  {0}" -f ($(if ($oce) {$oce} else {"[MISS] openocd"})))
Write-Host ("[SCR]   {0}" -f ($(if ($scr) {$scr} else {"[WARN] 未定位到 openocd 脚本目录(含 interface/stlink.cfg)"})))
Write-Host ("[GDB]   {0}" -f ($(if ($gdb) {$gdb} else {"[MISS] arm-none-eabi-gdb"})))

# ST-Link 探针(正则放宽以覆盖枚举名 STM32 STLink)
$st = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'ST-?LINK|STMicroelectronics' }
if ($st) { Write-Host ("[PROBE] 检测到: {0}" -f (($st | ForEach-Object { $_.FriendlyName }) -join ', ')) }
else { Write-Host "[PROBE] 未检测到 ST-Link (检查接线/驱动)" }

# 端口占用
foreach ($p in $gdbPort, $telnetPort) {
    $c = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    if ($c) { Write-Host ("[BUSY] 端口 {0} 被 PID {1} 占用" -f $p, (($c | ForEach-Object { $_.OwningProcess }) -join ',')) }
    else { Write-Host ("[FREE] 端口 {0} 空闲" -f $p) }
}

# 缺失项: 打印建议安装命令(不执行)
if ($InstallGuide -or (-not $oce) -or (-not $gdb)) {
    Write-Host "`n==== 缺失/建议安装(先探测再装, 由你确认后执行) ===="
    if (-not $oce) { Write-Host 'OpenOCD 缺:  winget install -e --id xpack-dev-tools.openocd-xpack' }
    if (-not $gdb) { Write-Host 'GDB 缺:     winget install -e --id Arm.GnuArmEmbeddedToolchain' }
    if (-not $node){ Write-Host 'Node 缺:    winget install -e --id OpenJS.NodeJS.LTS' }
    Write-Host '装完重跑本脚本; 若 winget 搜不到 ID, 用 `winget search openocd` / `winget search arm gnu` 查真实 ID。'
}

# 登记: 以现有 toolchain.json 为基底(无则用 example), 只覆盖探测到的路径字段, 保留用户定制(dbgmcu/ports/target/axfPath)
if ($Register) {
    $dst = Join-Path $pkg "config/toolchain.json"
    $base = if (Test-Path $dst) { $dst } else { Join-Path $pkg "config/toolchain.example.json" }
    $tcr = Get-Content -Raw -Encoding UTF8 $base | ConvertFrom-Json
    if ($oce) { $tcr.openocdExe        = To-FwdSlash $oce }
    if ($scr) { $tcr.openocdScriptsDir = To-FwdSlash $scr }
    if ($gdb) { $tcr.gdbExe            = To-FwdSlash $gdb }
    if (-not ($oce -or $gdb -or $scr)) {
        Write-Warning "一个工具都没探测到, 不写入 toolchain.json(避免写入 example 假路径)。请按上面提示安装或手动填写绝对路径。"
    } else {
        $tcr | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $dst
        Write-Host "`n[REGISTER] 已(合并)写入 $dst"
        if (-not ($oce -and $gdb -and $scr)) { Write-Warning "部分路径未探测到, 保留原值, 请手动校正。" }
    }
}

# DWARF 门禁转发
if ($Dwarf) { & "$PSScriptRoot\dwarf-check.ps1" -AxfPath $Dwarf; exit $LASTEXITCODE }

if ($Clean) {
    Get-Process openocd, arm-none-eabi-gdb -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host "[CLEAN] 已结束 openocd / arm-none-eabi-gdb 残留进程"
}
