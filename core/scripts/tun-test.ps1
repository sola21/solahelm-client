# TUN check for corectl on Windows. Needs an elevated session (admin).
# The core runs with a hard time limit (-duration), so it stops by itself even
# if this script or the SSH session dies. Listeners stay on 127.0.0.1 and the
# gvisor stack opens no sockets, so Windows Firewall does not prompt.
#
#   .\tun-test.ps1 -Source <subscription URL or file> [-Seconds 40] [-Stack gvisor]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [int]$Seconds = 40,
    [string]$Stack = 'gvisor',
    [string]$Gateway = '',
    [string]$Dir = ''
)
if (-not $Dir) { $Dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$exe = Join-Path $Dir 'corectl.exe'
$ipUrl = 'https://api.ipify.org'

function Get-ExitIP { (& curl.exe -s -m 10 $ipUrl) -join '' }
function Get-TunAdapters {
    Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'Wintun|sing|Meta|tun' -or $_.Name -match 'sing|Meta|tun' } |
        ForEach-Object { '{0} ({1}, {2})' -f $_.Name, $_.InterfaceDescription, $_.Status }
}
function Get-DefaultRoutes {
    Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.DestinationPrefix -in '0.0.0.0/0', '0.0.0.0/1', '128.0.0.0/1' } |
        ForEach-Object { '{0} -> {1} (metric {2})' -f $_.DestinationPrefix, $_.InterfaceAlias, $_.RouteMetric }
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Output 'not elevated: TUN needs admin'; exit 1 }
if (-not $Gateway) {
    $Gateway = (Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1).NextHop
}

$r = [ordered]@{}
$r.IpBefore = Get-ExitIP
$r.TunBefore = (Get-TunAdapters) -join '; '

$log = Join-Path $Dir 'tun-run.log'
$p = Start-Process -FilePath $exe -PassThru -NoNewWindow -RedirectStandardError $log -RedirectStandardOutput "$log.out" `
    -ArgumentList @('run', '-duration', "${Seconds}s", '-loopback', '-tun-stack', $Stack, '-port', '17890',
                    '-controller', '127.0.0.1:19090', '-workdir', (Join-Path $Dir 'work'), $Source)

$api = $null
for ($i = 0; $i -lt 40 -and -not $api; $i++) {
    Start-Sleep -Milliseconds 300
    if ($p.HasExited) { break }
    try { $api = Invoke-RestMethod -Uri 'http://127.0.0.1:19090/version' -TimeoutSec 2 } catch {}
}
Start-Sleep -Seconds 4   # let routes settle

$r.Core = if ($api) { $api.version } else { 'NO API (exited: ' + $p.HasExited + ')' }
$r.TunDuring = (Get-TunAdapters) -join '; '
$r.RoutesDuring = (Get-DefaultRoutes) -join '; '
$r.IpDuring = Get-ExitIP
$fmt = '%{http_code} ip=%{remote_ip} dns=%{time_namelookup} conn=%{time_connect} tls=%{time_appconnect} total=%{time_total}'
$r.HttpsGoogle = & curl.exe -s -o NUL -w $fmt -m 10 https://www.google.com/generate_204
$r.HttpsGoogleV4 = & curl.exe -4 -s -o NUL -w $fmt -m 10 https://www.google.com/generate_204
try { $r.GoogleDns = ((Resolve-DnsName www.google.com -DnsOnly -ErrorAction Stop | Where-Object IPAddress | ForEach-Object { $_.IPAddress }) -join ', ') }
catch { $r.GoogleDns = 'FAIL ' + $_.Exception.Message }
$r.HttpsYa = & curl.exe -s -o NUL -w '%{http_code} %{time_total}s' -m 10 https://ya.ru
try { $r.Dns = ((Resolve-DnsName github.com -Type A -DnsOnly -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 2).IPAddress) -join ', ' }
catch { $r.Dns = 'FAIL ' + $_.Exception.Message }
$r.LanGateway = if (Test-Connection $Gateway -Count 1 -Quiet) { "$Gateway ok" } else { "$Gateway FAIL" }
try {
    $conns = Invoke-RestMethod -Uri 'http://127.0.0.1:19090/connections' -TimeoutSec 3
    $r.Connections = ($conns.connections | ForEach-Object { '{0}->{1}' -f $_.metadata.host, ($_.chains -join '/') } | Select-Object -First 4) -join '; '
} catch { $r.Connections = 'n/a' }

# Wait for the auto-stop, then make sure it really stopped.
if (-not $p.WaitForExit(($Seconds + 20) * 1000)) {
    Stop-Process -Id $p.Id -Force
    $r.Stop = 'KILLED (did not stop in time)'
} else {
    $r.Stop = 'auto-stop ok'
}
Start-Sleep -Seconds 3
$r.TunAfter = (Get-TunAdapters) -join '; '
$r.RoutesAfter = (Get-DefaultRoutes) -join '; '
$r.IpAfter = Get-ExitIP
$r.LanAfter = if (Test-Connection $Gateway -Count 1 -Quiet) { "$Gateway ok" } else { "$Gateway FAIL" }
$r.Errors = ((Get-Content $log -ErrorAction SilentlyContinue | Select-String 'FATAL|panic|ERROR|error' |
    Where-Object { $_.Line -notmatch 'Server closed' } | Select-Object -First 3).Line) -join ' | '

[pscustomobject]$r | Format-List
