# Builds the core and the Windows app and packs them into dist\:
#   SolaHelm-<version>-windows-x64.zip           regular: data in %APPDATA%\solahelm-client
#   SolaHelm-<version>-windows-x64-portable.zip  portable: data in .\userdata next to the exe
#   SolaHelm-<version>-windows-x64-setup.exe     installer (Inno Setup 6, per user, no admin rights)
#
#   powershell -ExecutionPolicy Bypass -File tools\package-windows.ps1 [-SkipBuild]
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$dist = Join-Path $root 'dist'

$version = (Select-String -Path (Join-Path $app 'pubspec.yaml') -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value

if (-not $SkipBuild) {
    & (Join-Path $root 'core\build.ps1') -Test
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    Push-Location $app
    try {
        flutter build windows --release
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    } finally { Pop-Location }
}

$release = Join-Path $app 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'solahelm-core.exe'))) { throw "solahelm-core.exe is missing in $release" }

New-Item -ItemType Directory -Force $dist | Out-Null
$name = "SolaHelm-$version-windows-x64"

foreach ($portable in $false, $true) {
    $folder = if ($portable) { "$name-portable" } else { $name }
    $stage = Join-Path $dist $folder
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    New-Item -ItemType Directory -Force $stage | Out-Null
    Copy-Item -Recurse -Path (Join-Path $release '*') -Destination $stage
    Copy-Item (Join-Path $root 'LICENSE') $stage
    if ($portable) {
        @(
            'SolaHelm portable.',
            'While this file sits next to solahelm_client.exe, settings, subscriptions and core state',
            'are kept in the "userdata" folder here and nothing is written to %APPDATA%.',
            'Delete this file to switch to the regular mode.',
            '',
            'Портативный режим SolaHelm.',
            'Пока этот файл лежит рядом с solahelm_client.exe, настройки, подписки и данные ядер',
            'хранятся в папке "userdata" здесь, в %APPDATA% ничего не пишется.',
            'Удалите файл, чтобы перейти в обычный режим.'
        ) | Set-Content -Path (Join-Path $stage 'portable.txt') -Encoding UTF8
    }
    $zip = Join-Path $dist "$folder.zip"
    if (Test-Path $zip) { Remove-Item -Force $zip }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
    '{0}  {1:N1} MB' -f $zip, ((Get-Item $zip).Length / 1MB)
    if (-not $portable) {
        # The installer packs the same files as the regular zip.
        $iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
                  "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($iscc) {
            & $iscc /Q "/DAppVersion=$version" "/DSourceDir=$stage" (Join-Path $root 'tools\windows-setup.iss')
            if ($LASTEXITCODE) { throw "Inno Setup failed ($LASTEXITCODE)" }
            $setup = Join-Path $dist "$name-setup.exe"
            '{0}  {1:N1} MB' -f $setup, ((Get-Item $setup).Length / 1MB)
        } else {
            Write-Warning 'Inno Setup 6 is not installed (winget install JRSoftware.InnoSetup): no setup.exe'
        }
    }
    Remove-Item -Recurse -Force $stage
}
