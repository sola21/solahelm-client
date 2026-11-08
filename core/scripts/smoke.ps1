# Smoke test for corectl on a Windows machine. Proxy-port mode only: no TUN,
# no system proxy, listens on 127.0.0.1 only, so nothing else on the host is affected.
#
#   .\smoke.ps1 [-Dir <folder with corectl.exe and configs>] [-Sub <subscription URL>]
#
# Runs each config for a few seconds, checks that the Clash API answers and
# that an HTTP request goes through the local proxy port.
param(
    [string]$Dir = $PSScriptRoot,
    [string]$Sub = '',
    [int]$ProxyPort = 17890,
    [int]$ApiPort = 19090
)
$ErrorActionPreference = 'Stop'
$exe = Join-Path $Dir 'corectl.exe'
$work = Join-Path $Dir 'work'
$probe = 'https://www.gstatic.com/generate_204'

function Get-Json([string]$url) {
    try { Invoke-RestMethod -Uri $url -TimeoutSec 3 } catch { $null }
}

function Test-Config([string]$name, [string]$source, [bool]$expectTraffic) {
    $log = Join-Path $Dir "$name.log"
    $p = Start-Process -FilePath $exe -PassThru -NoNewWindow -RedirectStandardError $log -RedirectStandardOutput "$log.out" `
        -ArgumentList @('run', '-workdir', $work, '-controller', "127.0.0.1:$ApiPort", $source)
    $ver = $null
    for ($i = 0; $i -lt 30 -and -not $ver; $i++) {
        Start-Sleep -Milliseconds 300
        if ($p.HasExited) { break }
        $ver = Get-Json "http://127.0.0.1:$ApiPort/version"
    }
    $proxies = Get-Json "http://127.0.0.1:$ApiPort/proxies"
    $types = if ($proxies) { ($proxies.proxies.PSObject.Properties.Value | ForEach-Object type | Sort-Object -Unique) -join ',' } else { '' }
    $code = '-'
    if ($expectTraffic -and $ver) {
        $code = & curl.exe -s -o NUL -w '%{http_code}' -m 10 -x "http://127.0.0.1:$ProxyPort" $probe
    }
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
    Start-Sleep -Milliseconds 500
    $detected = (Get-Content $log -ErrorAction SilentlyContinue | Select-String 'corectl: .* -> ' | Select-Object -First 1).Line
    $err = (Get-Content $log -ErrorAction SilentlyContinue | Select-String 'corectl: (sing-box|mihomo):|FATAL|panic' | Select-Object -First 1).Line
    [pscustomobject]@{
        Config   = $name
        Detected = if ($detected) { $detected -replace '^corectl: ', '' } else { '' }
        Version  = if ($ver) { $ver.version } else { 'NO API' }
        Proxy    = $code
        Types    = $types
        Error    = $err
    }
}

$sbDirect = @"
{"log":{"level":"warn"},
 "inbounds":[{"type":"mixed","tag":"in","listen":"127.0.0.1","listen_port":$ProxyPort}],
 "outbounds":[{"type":"direct","tag":"direct"}]}
"@
$mhDirect = "mixed-port: $ProxyPort`nbind-address: 127.0.0.1`nallow-lan: false`nmode: rule`nlog-level: warning`nproxies: []`nrules:`n  - MATCH,DIRECT`n"
Set-Content -Path (Join-Path $Dir 'sb-direct.json') -Value $sbDirect -Encoding ascii
Set-Content -Path (Join-Path $Dir 'mh-direct.yaml') -Value $mhDirect -Encoding ascii

Write-Host (& $exe version | Out-String)
$results = @(
    Test-Config 'sb-direct' (Join-Path $Dir 'sb-direct.json') $true
    Test-Config 'mh-direct' (Join-Path $Dir 'mh-direct.yaml') $true
)
foreach ($f in Get-ChildItem $Dir -Filter 'panel-*') {
    $results += Test-Config $f.BaseName $f.FullName $false
}
if ($Sub) {
    $results += Test-Config 'subscription' $Sub $false
}
$results | Format-List
