# openocd_halt.ps1 —— 向 OpenOCD telnet 端口发命令(默认 halt), 用于 continue/next 失控时兜底拉回
# 版权见 LICENSE(MIT)
# 注意: param() 必须是脚本首条语句, 故 dot-source 放在 param 之后
param([string]$Cmd = "halt", [int]$Port = 0)
. "$PSScriptRoot\lib\common.ps1"

# 未显式给端口时, 从配置读 telnetPort; 读不到再退回 4444
if ($Port -eq 0) {
    try { $Port = (Get-Toolchain).telnetPort } catch { $Port = 4444 }
    if (-not $Port) { $Port = 4444 }
}

# OpenOCD telnet 提示符 "> " 无换行, 禁用 ReadLine(会永久阻塞); 改超时+字节级收流
function Read-Available($stream, $timeoutMs) {
    $buf = New-Object byte[] 4096
    $sb = New-Object System.Text.StringBuilder
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        if ($stream.DataAvailable) {
            $n = $stream.Read($buf, 0, $buf.Length)
            if ($n -gt 0) { [void]$sb.Append([System.Text.Encoding]::ASCII.GetString($buf, 0, $n)) }
        } else { Start-Sleep -Milliseconds 50 }
    }
    return $sb.ToString()
}

# 连接/收发全程包 try/catch, 失败给可读提示而非抛栈
try {
    $c = New-Object System.Net.Sockets.TcpClient("127.0.0.1", $Port)
    $s = $c.GetStream()
    [void](Read-Available $s 300)                       # 吃掉 OpenOCD 横幅
    $cmdBytes = [System.Text.Encoding]::ASCII.GetBytes($Cmd + "`r`n")
    $s.Write($cmdBytes, 0, $cmdBytes.Length); $s.Flush()
    Write-Host (Read-Available $s 800)                   # 收命令回显
    $c.Close()
} catch {
    Write-Host ("[ERR] 与 OpenOCD telnet 端口 {0} 交互失败: {1} (OpenOCD 未起或端口不通)" -f $Port, $_.Exception.Message)
}
