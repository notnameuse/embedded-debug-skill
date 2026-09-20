# debug_start.ps1 —— 按 config/toolchain.json 后台启动 OpenOCD, 轮询端口就绪后登记 PID
# 安全提示: 起 OpenOCD 会复位目标, 确认机械安全后再执行; 与编译/烧录共用 ST-Link 须串行
# 版权见 LICENSE(MIT)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"

$pkg = Get-PkgRoot
$tc  = Get-Toolchain

# OpenOCD 可执行文件存在性检查
if (-not (Test-Path $tc.openocdExe)) { throw "未找到 OpenOCD: $($tc.openocdExe) (请在 config/toolchain.json 校正 openocdExe)" }

# 传给 openocd 的路径一律正斜杠; 冻结 cfg 由配置生成
$scrDir   = To-FwdSlash $tc.openocdScriptsDir
$genCfg   = New-DbgmcuFreezeCfg $tc
$logFile  = To-FwdSlash (Join-Path $pkg "scripts/openocd.log")
$pidPath  = Join-Path $pkg "scripts/openocd.pid"
$logAbs   = Join-Path $pkg "scripts/openocd.log"

# 启动前端口互斥检查(端口取自配置), 避免与 Keil/另一 OpenOCD 抢同一 SWD
foreach ($p in $tc.gdbPort, $tc.telnetPort) {
    if (Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) {
        throw "端口 $p 被占用, 先运行 debug_stop.ps1 或关闭占用者"
    }
}

# 组装参数: Start-Process -ArgumentList 不给含空格元素补引号, 故路径/命令串一律自带内层双引号
$argList = @('-s', ('"' + $scrDir + '"'), '-f', $tc.interfaceCfg, '-f', $tc.targetCfg, '-c', ('"' + $tc.resetConfig + '"'), '-f', ('"' + $genCfg + '"'), '-l', ('"' + $logFile + '"'))
$proc = Start-Process -FilePath $tc.openocdExe -ArgumentList $argList -PassThru -WindowStyle Hidden

# 轮询等待 gdb 端口与 telnet 端口真正监听, 最长约 24s
$ok = $false
for ($i = 0; $i -lt 48; $i++) {
    Start-Sleep -Milliseconds 500
    $g = Get-NetTCPConnection -LocalPort $tc.gdbPort -State Listen -ErrorAction SilentlyContinue
    $t = Get-NetTCPConnection -LocalPort $tc.telnetPort -State Listen -ErrorAction SilentlyContinue
    if ($g -and $t) { $ok = $true; break }
    if ($proc.HasExited) { break }
}

if ($ok) {
    $proc.Id | Out-File -Encoding ascii $pidPath
    Write-Host "OpenOCD 启动成功 PID=$($proc.Id), 端口 $($tc.gdbPort)/$($tc.telnetPort) 已监听"
} else {
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item $pidPath -ErrorAction SilentlyContinue
    Write-Host "OpenOCD 启动失败或探针不可用, 已清理; 详见日志 $logAbs"
}

# 诊断落盘, 便于脚本化环境排障
$diag = "ok=$ok hasExited=$($proc.HasExited) pid=$($proc.Id) gdbPort=$($tc.gdbPort) telnetPort=$($tc.telnetPort)"
Set-Content -Encoding utf8 -Path (Join-Path $pkg "scripts/openocd.start.diag.txt") -Value $diag

if (Test-Path $logAbs) { Get-Content $logAbs -Tail 20 -ErrorAction SilentlyContinue }
else { Write-Host "openocd.log 尚未生成, 稍后再查 $logAbs" }
