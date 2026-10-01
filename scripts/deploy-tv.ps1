$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent
$EnvFile = Join-Path $Root ".env"
if (-not (Test-Path $EnvFile)) {
    throw "Missing $EnvFile"
}

$envVars = @{}
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*(ROKU_TV_URL|ROKU_TV_USER|ROKU_TV_PASS)\s*=\s*(.*?)\s*$') {
        $envVars[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
    }
}

$ROKU_TV_URL = $envVars["ROKU_TV_URL"]
$ROKU_TV_USER = $envVars["ROKU_TV_USER"]
$ROKU_TV_PASS = $envVars["ROKU_TV_PASS"]
if (-not $ROKU_TV_URL -or -not $ROKU_TV_USER -or -not $ROKU_TV_PASS) {
    throw "ROKU_TV_URL, ROKU_TV_USER, and ROKU_TV_PASS are required in .env"
}

$Archive = Join-Path $Root "dist\demoscene-roku.zip"
if (-not (Test-Path $Archive)) {
    throw "Package missing. Run scripts/package.ps1 first."
}

& curl.exe --digest -u "${ROKU_TV_USER}:${ROKU_TV_PASS}" -F "mysubmit=Install" -F "archive=@$Archive" "$ROKU_TV_URL/plugin_install"
if ($LASTEXITCODE -ne 0) {
    throw "Roku install failed with exit code $LASTEXITCODE."
}

Write-Host "Installed on $ROKU_TV_URL"
