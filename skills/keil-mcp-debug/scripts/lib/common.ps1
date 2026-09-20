# common.ps1 —— keil-mcp-debug 各脚本共用的工具函数(定位包根/读配置/路径转换/生成冻结cfg)
# 采用 dot-source 引入: . "$PSScriptRoot\lib\common.ps1"
# 版权见仓库根 LICENSE(MIT)

# 求包根目录: 本文件位于 <pkg>/scripts/lib, 上溯两级即 <pkg>。不依赖当前 CWD
function Get-PkgRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

# 正斜杠转换: 传给 openocd/gdb file 的路径必须用 '/', 否则 Windows 下反斜杠被当转义吃掉
function To-FwdSlash($p) {
    return ($p -replace '\\', '/')
}

# 返回 toolchain.json 的绝对路径(优先用户配置, 缺失则回退 example 并告警)
function Get-ToolchainPath {
    $pkg = Get-PkgRoot
    $real = Join-Path $pkg "config/toolchain.json"
    if (Test-Path $real) {
        return $real
    }
    Write-Warning "config/toolchain.json 不存在, 回退到 toolchain.example.json(请用 env-doctor 生成或手动复制填写)"
    return (Join-Path $pkg "config/toolchain.example.json")
}

# 读取配置为对象(带 openocdExe/gdbExe/dbgmcu 等字段); _comment 字段无害, 直接保留
function Get-Toolchain {
    $path = Get-ToolchainPath
    return (Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json)
}

# 依据配置的 DBGMCU 地址/位, 生成 OpenOCD 冻结片段(掩码写), 返回其正斜杠绝对路径
# 依据 OpenOCD 官方文档: reset-init 仅在 'reset init' 触发, 'reset halt' 不触发;
# 故同时挂 examine-end(连接 examine 时必触发), 配合"冻结位仅 POR 清除"语义一次写入即持续生效
function New-DbgmcuFreezeCfg {
    param($tc)
    $pkg = Get-PkgRoot
    $outDir = Join-Path $pkg "scripts/openocd"
    # 确保输出目录存在(包内不预建 openocd 子目录, 首次运行自动创建)
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
    $outPath = Join-Path $outDir "dbgmcu_freeze.gen.cfg"
    $apb2 = $tc.dbgmcu.apb2Fz
    $apb1 = $tc.dbgmcu.apb1Fz
    # 掩码 = 1 << 位; mmw addr setbits clearbits -> new=(old & ~clearbits) | setbits, setbits=clearbits=mask 强制该位置1不清其余
    $mask2 = '0x{0:X}' -f (1 -shl [int]$tc.dbgmcu.tim1StopBit)
    $mask1 = '0x{0:X}' -f (1 -shl [int]$tc.dbgmcu.can1StopBit)
    $lines = @()
    $lines += "# dbgmcu_freeze.gen.cfg - auto-generated from config/toolchain.json; do not edit (edit config and re-run)"
    $lines += "# Freeze TIM1 (PWM off for safety) and CAN1 on halt; sets only target bits, keeps others. MIT licensed."
    $lines += "proc dbgmcu_apply_freeze {} {"
    $lines += ("    mmw {0} {1} {1}" -f $apb2, $mask2)
    $lines += ("    mmw {0} {1} {1}" -f $apb1, $mask1)
    $lines += "}"
    $lines += '$_TARGETNAME configure -event reset-init { dbgmcu_apply_freeze }'
    $lines += '$_TARGETNAME configure -event examine-end { dbgmcu_apply_freeze }'
    # 生成 cfg 供 openocd -f 读取; 注释用纯 ASCII 避免编码降级为乱码
    Set-Content -Encoding ascii -Path $outPath -Value $lines
    return (To-FwdSlash $outPath)
}
