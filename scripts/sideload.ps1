$ErrorActionPreference = "Stop"

$Settings = Join-Path $PSScriptRoot "local.settings.ps1"
if (-not (Test-Path $Settings)) {
    throw "Copy local.settings.example.ps1 to local.settings.ps1 and enter the Roku connection values."
}
. $Settings

$Root = Split-Path -Parent $PSScriptRoot
$Archive = Join-Path $Root "dist/demoscene-roku.zip"
if (-not (Test-Path $Archive)) {
    & (Join-Path $PSScriptRoot "package.ps1")
}

if (-not $RokuIp -or -not $RokuPassword) {
    throw "RokuIp and RokuPassword are required in local.settings.ps1."
}

& curl.exe `
    --fail `
    --show-error `
    --digest `
    --user "${RokuUser}:${RokuPassword}" `
    --form "mysubmit=Install" `
    --form "archive=@$Archive;type=application/zip" `
    "http://$RokuIp/plugin_install"

if ($LASTEXITCODE -ne 0) {
    throw "Roku sideload failed with exit code $LASTEXITCODE."
}
Write-Host "Installed $Archive on $RokuIp"

