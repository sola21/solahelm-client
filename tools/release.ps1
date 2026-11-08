# Publishes a GitHub release with the Windows zips (the client's updater looks
# for SolaHelm-<version>-windows-x64[-portable].zip in the latest release) and,
# when built, the Android APKs (run tools/package-android.sh first).
#
#   powershell -ExecutionPolicy Bypass -File tools\release.ps1 [-Notes "what changed"] [-Proxy http://127.0.0.1:7890] [-Prerelease]
#
# Before: bump "version:" in app/pubspec.yaml and appVersion in app/lib/screens/settings.dart.
param([string]$Notes = '', [string]$NotesFile = '', [string]$Proxy = '', [switch]$Prerelease, [switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$pubspec = (Select-String -Path "$root\app\pubspec.yaml" -Pattern '^version:\s*([0-9A-Za-z.\-]+)').Matches[0].Groups[1].Value
$inApp = (Select-String -Path "$root\app\lib\screens\settings.dart" -Pattern "const appVersion = '([^']+)'").Matches[0].Groups[1].Value
if ($pubspec -ne $inApp) { throw "Version mismatch: pubspec.yaml has $pubspec, settings.dart has $inApp" }
$tag = "v$pubspec"

if (-not $SkipBuild) {
    & "$root\tools\package-windows.ps1"
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
$zips = @("$root\dist\SolaHelm-$pubspec-windows-x64.zip", "$root\dist\SolaHelm-$pubspec-windows-x64-portable.zip")
foreach ($z in $zips) { if (-not (Test-Path $z)) { throw "missing $z" } }
$apks = @(Get-ChildItem "$root\dist\SolaHelm-$pubspec-android-*.apk" -ErrorAction SilentlyContinue | ForEach-Object FullName)
if ($apks.Count -eq 0) { Write-Warning "no Android APKs for $pubspec in dist (tools/package-android.sh); publishing Windows only" }
$assets = $zips + $apks

if ($Proxy) { $env:HTTPS_PROXY = $Proxy; $env:HTTP_PROXY = $Proxy }
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = 'C:\Users\user\dev\gh\bin\gh.exe' }
$ghArgs = @('release', 'create', $tag) + $assets + @('--repo', 'sola21/solahelm-client', '--title', "SolaHelm Client $pubspec")
if ($NotesFile) { $ghArgs += @('--notes-file', $NotesFile) } elseif ($Notes) { $ghArgs += @('--notes', $Notes) } else { $ghArgs += '--generate-notes' }
if ($Prerelease) { $ghArgs += '--prerelease' }
& $gh @ghArgs
