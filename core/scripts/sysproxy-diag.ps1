param([Parameter(Mandatory = $true)][string]$Sub, [string]$Dir = '', [string]$Variant = '/clash')
if (-not $Dir) { $Dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$exe = Join-Path $Dir 'corectl.exe'
$tmp = New-Item -ItemType Directory -Force (Join-Path $env:TEMP ("sh-" + [guid]::NewGuid().ToString('N').Substring(0, 8)))
$secret = -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })
Set-Content -Path "$tmp\secret" -Value $secret -NoNewline -Encoding ascii
$p = Start-Process -FilePath $exe -PassThru -NoNewWindow -RedirectStandardError "$Dir\diag.log" -RedirectStandardOutput "$Dir\diag.log.out" `
    -ArgumentList @('serve', '-secret-file', "$tmp\secret", '-ready-file', "$tmp\ready", '-parent', "$PID", '-workdir', (Join-Path $Dir 'work'))
for ($i = 0; $i -lt 50 -and -not (Test-Path "$tmp\ready"); $i++) { Start-Sleep -Milliseconds 200 }
$base = 'http://' + (Get-Content "$tmp\ready" -Raw).Trim()
$h = @{ Authorization = "Bearer $secret" }
$f = Invoke-RestMethod -Method POST -Uri "$base/fetch" -Headers $h -ContentType 'application/json' -Body (@{ url = "$Sub$Variant" } | ConvertTo-Json)
$body = [Text.Encoding]::UTF8.GetBytes((@{ content = $f.content; mode = 'system-proxy'; port = 7890 } | ConvertTo-Json -Compress))
try {
    $r = Invoke-WebRequest -Method POST -Uri "$base/start" -Headers $h -ContentType 'application/json' -Body $body -UseBasicParsing
    "HTTP $($r.StatusCode): $($r.Content)"
} catch {
    "ERROR: $($_.Exception.Message)"
    "BODY: $($_.ErrorDetails.Message)"
}
(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | ForEach-Object { "during: enable=$($_.ProxyEnable) server=$($_.ProxyServer)" })
Invoke-RestMethod -Method POST -Uri "$base/shutdown" -Headers $h | Out-Null
Start-Sleep 1
(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | ForEach-Object { "after: enable=$($_.ProxyEnable) server=$($_.ProxyServer)" })
Get-Content "$Dir\diag.log" -Tail 5
