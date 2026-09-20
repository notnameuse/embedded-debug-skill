# debug_stop.ps1 —— 停止 OpenOCD 并释放 SWD, 停后复验端口
# 版权见 LICENSE(MIT)
. "$PSScriptRoot\lib\common.ps1"

$pkg = Get-PkgRoot
$tc  = Get-Toolchain
$pidPath = Join-Path $pkg "scripts/openocd.pid"

# 先按登记的 PID 精确停止, 再按进程名兜底(容忍 PID 文件缺失/PID 复用)
if (Test-Path $pidPath) {
    $id = (Get-Content $pidPath | Select-Object -First 1)
    Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
    Remove-Item $pidPath -ErrorAction SilentlyContinue
}
Get-Process openocd -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

# 停后复验端口是否已释放
foreach ($p in $tc.gdbPort, $tc.telnetPort) {
    $c = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    if ($c) { Write-Host ("[BUSY] 端口 {0} 仍被占用" -f $p) }
    else { Write-Host ("[FREE] 端口 {0} 已释放" -f $p) }
}
Write-Host "OpenOCD 已停止, SWD 应已释放"
