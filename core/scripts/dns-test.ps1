# Measures how fast the core's own DNS resolver answers (Clash API /dns/query,
# mihomo only), in proxy-only mode: no TUN, nothing changes on the host.
#   .\dns-test.ps1 -Source <subscription URL or file>
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [string[]]$Names = @('www.google.com', 'api.ipify.org', 'github.com', 'ya.ru', 'youtube.com', 'telegram.org'),
    [string[]]$Types = @('A'),
    [int]$Rounds = 2,
    [string]$Dir = ''
)
if (-not $Dir) { $Dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
# powershell -File passes "a,b" as one string; split it.
$Names = $Names | ForEach-Object { $_ -split ',' } | Where-Object { $_ }
$Types = $Types | ForEach-Object { $_ -split ',' } | Where-Object { $_ }
$exe = Join-Path $Dir 'corectl.exe'
$log = Join-Path $Dir 'dns-run.log'
$p = Start-Process -FilePath $exe -PassThru -NoNewWindow -RedirectStandardError $log -RedirectStandardOutput "$log.out" `
    -ArgumentList @('run', '-duration', '60s', '-proxy-only', '-port', '17890', '-controller', '127.0.0.1:19090',
                    '-workdir', (Join-Path $Dir 'work'), $Source)
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 300
    try { Invoke-RestMethod 'http://127.0.0.1:19090/version' -TimeoutSec 2 | Out-Null; break } catch {}
}
foreach ($round in 1..$Rounds) {
    foreach ($n in $Names) {
        foreach ($t in $Types) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            try {
                $a = Invoke-RestMethod "http://127.0.0.1:19090/dns/query?name=$n&type=$t" -TimeoutSec 15
                $ips = ($a.Answer | Where-Object { $_.type -in 1, 28 } | Select-Object -First 2 | ForEach-Object data) -join ','
                $res = if ($ips) { $ips } else { "no records, status $($a.Status)" }
            } catch { $res = 'FAIL ' + $_.Exception.Message }
            '{0} {1,-16} {2,-4} {3,6} ms  {4}' -f $round, $n, $t, $sw.ElapsedMilliseconds, $res
        }
    }
}
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
