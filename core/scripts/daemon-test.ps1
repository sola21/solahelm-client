# Exercises "solahelm-core serve" the way the UI does, on Windows, elevated:
#   1. TUN mode: traffic of the whole machine goes through the VPN, then is restored.
#   2. System proxy mode: WinINet proxy points at the core, then the previous value is restored.
#   3. Parent watch: when the "UI" process dies, the core exits and TUN disappears.
#   .\daemon-test.ps1 -Sub <subscription URL without /singbox or /clash>
param([Parameter(Mandatory = $true)][string]$Sub, [string]$Dir = '')
if (-not $Dir) { $Dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$exe = Join-Path $Dir 'corectl.exe'
$ip = { (& curl.exe -s -m 10 https://api.ipify.org) -join '' }
$tun = { (Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match 'sing-tun|Meta|Wintun' } | ForEach-Object Name) -join ',' }
$inet = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$proxyState = { $p = Get-ItemProperty $inet; "enable=$($p.ProxyEnable) server=$($p.ProxyServer)" }

function Start-Daemon([int]$parentPid) {
    $tmp = New-Item -ItemType Directory -Force (Join-Path $env:TEMP ("sh-" + [guid]::NewGuid().ToString('N').Substring(0, 8)))
    $secret = -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })
    Set-Content -Path "$tmp\secret" -Value $secret -NoNewline -Encoding ascii
    $a = @('serve', '-secret-file', "$tmp\secret", '-ready-file', "$tmp\ready", '-parent', "$parentPid", '-workdir', (Join-Path $Dir 'work'))
    $p = Start-Process -FilePath $exe -ArgumentList $a -PassThru -NoNewWindow -RedirectStandardError "$Dir\daemon.log" -RedirectStandardOutput "$Dir\daemon.log.out"
    for ($i = 0; $i -lt 50 -and -not (Test-Path "$tmp\ready"); $i++) { Start-Sleep -Milliseconds 200 }
    $addr = (Get-Content "$tmp\ready" -Raw).Trim()
    @{ Proc = $p; Base = "http://$addr"; H = @{ Authorization = "Bearer $secret" } }
}
function Call($d, [string]$method, [string]$path, $body = $null) {
    $args = @{ Method = $method; Uri = "$($d.Base)$path"; Headers = $d.H; TimeoutSec = 60; ContentType = 'application/json' }
    if ($body) { $args.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 5 -Compress)) }
    try { Invoke-RestMethod @args } catch { $_.ErrorDetails.Message }
}

$out = [ordered]@{}
$out.IpBefore = & $ip
$out.ProxyBefore = & $proxyState

# --- 1 + 2 with this script as the parent ---
$d = Start-Daemon $PID
$st = Call $d GET '/status'
$out.Elevated = $st.elevated
$sb = Call $d POST '/fetch' @{ url = "$Sub/singbox" }
$cl = Call $d POST '/fetch' @{ url = "$Sub/clash" }
$out.Fetch = "singbox->$($sb.detect.core) clash->$($cl.detect.core) title=$($sb.title)"

$st = Call $d POST '/start' @{ content = $sb.content; mode = 'tun'; port = 7890 }
Start-Sleep -Seconds 4
$out.TunStart = "running=$($st.running) core=$($st.core) mode=$($st.mode) port=$($st.port)"
$out.TunAdapter = & $tun
$out.TunIp = & $ip
$st = Call $d POST '/stop'
Start-Sleep -Seconds 2
$out.TunAfterStop = "adapter=[$(& $tun)] ip=$(& $ip)"

$st = Call $d POST '/start' @{ content = $cl.content; mode = 'system-proxy'; port = 7890 }
Start-Sleep -Seconds 2
$out.SysProxyStart = "running=$($st.running) core=$($st.core) port=$($st.port) tun=[$(& $tun)]"
$out.SysProxyDuring = & $proxyState
$out.SysProxyTraffic = & curl.exe -s -o NUL -w '%{http_code}' -m 10 -x "http://127.0.0.1:$($st.port)" https://www.gstatic.com/generate_204
Call $d POST '/stop' | Out-Null
$out.SysProxyAfterStop = & $proxyState
Call $d POST '/shutdown' | Out-Null
Start-Sleep -Seconds 1
$out.DaemonExited = $d.Proc.HasExited

# --- 3: parent dies while TUN is up ---
$fakeUi = Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 12' -PassThru -WindowStyle Hidden
$d2 = Start-Daemon $fakeUi.Id
$st = Call $d2 POST '/start' @{ content = $sb.content; mode = 'tun'; port = 7890 }
Start-Sleep -Seconds 3
$out.OrphanTunUp = "running=$($st.running) adapter=[$(& $tun)]"
$fakeUi.WaitForExit()
for ($i = 0; $i -lt 30 -and -not $d2.Proc.HasExited; $i++) { Start-Sleep -Milliseconds 300 }
Start-Sleep -Seconds 2
$out.OrphanAfterParentExit = "daemonExited=$($d2.Proc.HasExited) adapter=[$(& $tun)] ip=$(& $ip)"
if (-not $d2.Proc.HasExited) { Stop-Process -Id $d2.Proc.Id -Force }

$out.ProxyFinal = & $proxyState
[pscustomobject]$out | Format-List
