param(
    [string]$MediaDirectory = "",
    [string]$User = "ubuntu",
    [string]$RemoteRoot = "/srv/demoscene"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot

# Load .env
$envVars = @{}

Get-Content (Join-Path $Root ".env") | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') {
        $envVars[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
    }
}

$Server       = $envVars["LIGHTSAIL_DOMAIN"]
$IdentityFile = $envVars["LIGHTSAIL_KEY"]

if (-not $Server) {
    throw "LIGHTSAIL_DOMAIN is missing from .env"
}

if (-not $IdentityFile -or -not (Test-Path $IdentityFile)) {
    throw "LIGHTSAIL_KEY is missing or invalid: $IdentityFile"
}

if (-not $MediaDirectory) {
    $MediaDirectory = Join-Path $Root "media"
}

if ((Split-Path $MediaDirectory -Leaf) -eq "media-src") {
    throw "Refusing to upload media-src. Run prepare-media.ps1 first."
}

if (-not (Test-Path $MediaDirectory)) {
    throw "Media directory does not exist: $MediaDirectory"
}

$Masters = @(Get-ChildItem $MediaDirectory -Recurse -Filter "master.m3u8")

if ($Masters.Count -eq 0) {
    throw "No HLS masters found. Run scripts/prepare-media.ps1 first."
}

Write-Host "Rendering deployment catalog..."
& (Join-Path $PSScriptRoot "package.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Could not generate the deployment catalog."
}

$Catalog = Join-Path $Root "build\package\content\catalog.sample.json"
if (-not (Test-Path $Catalog)) {
    throw "Rendered catalog not found: $Catalog"
}

$SshOptions = @(
    "-i", $IdentityFile,
    "-o", "IdentitiesOnly=yes",
    "-o", "StrictHostKeyChecking=accept-new"
)

$Release  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
$Incoming = "$RemoteRoot/releases/$Release"

Write-Host "Creating release $Release..."

& ssh @SshOptions "${User}@${Server}" `
    "mkdir -p '$Incoming/catalog/v1'"

if ($LASTEXITCODE -ne 0) {
    throw "Could not prepare remote release."
}

Write-Host "Uploading media..."

& scp @SshOptions -r `
    $MediaDirectory `
    "${User}@${Server}:$Incoming/"

if ($LASTEXITCODE -ne 0) {
    throw "Media upload failed."
}

Write-Host "Uploading catalog..."

& scp @SshOptions `
    $Catalog `
    "${User}@${Server}:$Incoming/catalog/v1/catalog.json"

if ($LASTEXITCODE -ne 0) {
    throw "Catalog upload failed."
}

Write-Host "Activating release..."

& ssh @SshOptions "${User}@${Server}" `
    "sudo ln -sfn '$Incoming' '$RemoteRoot/current' && sudo nginx -t && sudo systemctl reload nginx"

if ($LASTEXITCODE -ne 0) {
    throw "Activating release failed."
}

Write-Host ""
Write-Host "Activated media release $Release"
Write-Host "Catalog: https://$Server/catalog/v1/catalog.json"
Write-Host "Health:  https://$Server/health"