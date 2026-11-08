# Builds corectl for the current platform (or $env:GOOS/$env:GOARCH) and runs tests with -Test.
param([switch]$Test)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$tags = 'with_quic,with_utls,with_clash_api,with_gvisor,with_wireguard'
$sb = (go list -m -f '{{.Version}}' github.com/sagernet/sing-box).TrimStart('v')
$mh = (go list -m -f '{{.Version}}' github.com/metacubex/mihomo).TrimStart('v')
$ld = "-s -w -X github.com/sagernet/sing-box/constant.Version=$sb -X github.com/metacubex/mihomo/constant.Version=$mh"

if ($Test) {
    go test -tags $tags -count=1 ./...
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
$ext = if (((go env GOOS) -eq 'windows')) { '.exe' } else { '' }
New-Item -ItemType Directory -Force bin | Out-Null
go build -trimpath -tags $tags -ldflags $ld -o "bin/corectl$ext" ./cmd/corectl
if ($LASTEXITCODE) { exit $LASTEXITCODE }
# The app ships the same binary as solahelm-core (it runs "solahelm-core serve").
Copy-Item -Force "bin/corectl$ext" "bin/solahelm-core$ext"
Write-Host "built bin/corectl$ext and bin/solahelm-core$ext (sing-box $sb, mihomo $mh)"
