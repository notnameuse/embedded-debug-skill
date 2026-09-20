# dwarf-check.ps1 —— 离线 DWARF 门禁: 判断目标 axf 是否可被 arm-none-eabi-gdb 源码级解析
# 用法: dwarf-check.ps1 -AxfPath <axf绝对路径>
# exit 0 = 可源码级调试; exit 1 = 无源码级 DWARF(应在 Keil 开 DebugInformation/BrowseInformation 重编); exit 2 = 环境缺文件
# 版权见 LICENSE(MIT)
param([Parameter(Mandatory = $true)][string]$AxfPath)
. "$PSScriptRoot\lib\common.ps1"

$pkg = Get-PkgRoot
$tc  = Get-Toolchain
$gdb = $tc.gdbExe.Trim()

if (-not (Test-Path $gdb)) { Write-Host "[GATE][FAIL] 找不到 gdb: $gdb"; exit 2 }
if (-not (Test-Path $AxfPath)) { Write-Host "[GATE][FAIL] 找不到 axf: $AxfPath"; exit 2 }

# gdb 的 file 命令会吃反斜杠, 命令文件里路径用正斜杠并加引号
$axfFwd  = To-FwdSlash $AxfPath
$cmdFile = Join-Path $pkg "scripts/_dwarf_probe.cmd"
Set-Content -Encoding ascii -Path $cmdFile -Value @(
    ('file "{0}"' -f $axfFwd),
    'info line main',
    'break main'
)

# 用 Start-Process 把 gdb 的 stdout/stderr 分别重定向到文件(PS5.1 内联重定向对原生命令不可靠)
$outFile = Join-Path $pkg "scripts/_dwarf_probe.out.txt"
$errFile = Join-Path $pkg "scripts/_dwarf_probe.err.txt"
Start-Process -FilePath $gdb -ArgumentList @('-batch', '-x', (To-FwdSlash $cmdFile)) -NoNewWindow -Wait `
    -RedirectStandardOutput $outFile -RedirectStandardError $errFile

$combined = ""
if (Test-Path $outFile) { $combined += [string](Get-Content -Raw $outFile) }
if (Test-Path $errFile) { $combined += [string](Get-Content -Raw $errFile) }

Remove-Item $cmdFile, $outFile, $errFile -ErrorAction SilentlyContinue

# 判据: info line main 命中 'Line <N> of "...c"' 且带行号, 说明有源码级行表
if ($combined -match 'Line\s+\d+\s+of\s+"[^"]*\.(c|cpp|s)"') {
    Write-Host "[GATE][PASS] axf 具备源码级 DWARF, 可按文件+行定位:"
    ($combined -split "`n" | Where-Object { $_ -match 'Line\s+\d+\s+of|Breakpoint\s+\d+\s+at' } | Select-Object -First 4) | ForEach-Object { Write-Host ("  " + $_.Trim()) }
    exit 0
}
Write-Host "[GATE][FAIL] 该 axf 无源码级 DWARF(仅裸地址或无法解析行号)。"
Write-Host "  请在 Keil 工程开启 <DebugInformation> 与 <BrowseInformation> 后重新编译, 再重跑本门禁。"
if ($combined) { Write-Host ("  gdb 输出(截断): " + $combined.Substring(0, [Math]::Min(300, $combined.Length))) }
exit 1
