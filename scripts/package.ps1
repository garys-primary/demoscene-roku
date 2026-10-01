$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Root "build/package"
$Dist = Join-Path $Root "dist"
$Archive = Join-Path $Dist "demoscene-roku.zip"
$EmulatorArchive = Join-Path $Dist "demoscene-emulator.zip"
$EnvFile = Join-Path $Root ".env"

if (-not (Test-Path $EnvFile)) {
    throw "Missing $EnvFile. Copy .env.example to .env and enter the local values."
}

$envVars = @{}
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') {
        $envVars[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
    }
}

$CatalogUrl = $envVars["CATALOG_URL"]
$MediaBaseUrl = $envVars["MEDIA_BASE_URL"]
if (-not $CatalogUrl -or -not $MediaBaseUrl) {
    throw "CATALOG_URL and MEDIA_BASE_URL are required in .env."
}

$MediaBaseUrl = $MediaBaseUrl.TrimEnd("/")
foreach ($Url in @($CatalogUrl, $MediaBaseUrl)) {
    try {
        $ParsedUrl = [Uri]$Url
    }
    catch {
        throw "Invalid build URL in .env: $Url"
    }
    if (-not $ParsedUrl.IsAbsoluteUri -or $ParsedUrl.Scheme -ne "https") {
        throw "Build URLs must be absolute HTTPS URLs: $Url"
    }
}

Remove-Item $Build -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Build, $Dist | Out-Null

if (Test-Path $Dist) {
    Remove-Item $Dist -Recurse -Force
}
New-Item -ItemType Directory -Path $Dist | Out-Null

Copy-Item (Join-Path $Root "manifest") $Build
Copy-Item (Join-Path $Root "source") $Build -Recurse
Copy-Item (Join-Path $Root "components") $Build -Recurse
Copy-Item (Join-Path $Root "assets") $Build -Recurse
Copy-Item (Join-Path $Root "content") $Build -Recurse

$Utf8 = [Text.UTF8Encoding]::new($false)

$BuiltManifest = Join-Path $Build "manifest"
$ManifestText = Get-Content $BuiltManifest -Raw
if (-not $ManifestText.Contains("__CATALOG_URL__")) {
    throw "Manifest template is missing __CATALOG_URL__."
}
$ManifestText = $ManifestText.Replace("__CATALOG_URL__", $CatalogUrl)
[IO.File]::WriteAllText($BuiltManifest, $ManifestText, $Utf8)

$CatalogTemplate = Join-Path $Build "content/catalog.template.json"
$CatalogOutput = Join-Path $Build "content/catalog.sample.json"
$CatalogText = Get-Content $CatalogTemplate -Raw
if (-not $CatalogText.Contains("__MEDIA_BASE_URL__")) {
    throw "Catalog template is missing __MEDIA_BASE_URL__."
}
$CatalogText = $CatalogText.Replace("__MEDIA_BASE_URL__", $MediaBaseUrl)
[IO.File]::WriteAllText($CatalogOutput, $CatalogText, $Utf8)
Remove-Item $CatalogTemplate -Force

$RenderedCatalog = Get-Content $CatalogOutput -Raw | ConvertFrom-Json
if (-not $RenderedCatalog.exhibits -or $RenderedCatalog.exhibits.Count -eq 0) {
    throw "Rendered catalog contains no exhibits."
}

Remove-Item $Archive -Force -ErrorAction SilentlyContinue
Push-Location $Build
try {
    tar.exe -a -c -f $Archive *
}
finally {
    Pop-Location
}

Write-Host "Created $Archive"

# The lvcabral browser simulator also probes for main.brs at the archive
# root. Roku devices correctly use source/main.brs, so keep a separate
# compatibility package rather than changing the device artifact.
Copy-Item (Join-Path $Build "source/main.brs") (Join-Path $Build "main.brs")
Remove-Item $EmulatorArchive -Force -ErrorAction SilentlyContinue
Push-Location $Build
try {
    Compress-Archive -Path "*" -DestinationPath $EmulatorArchive -CompressionLevel Optimal
}
finally {
    Pop-Location
}
Remove-Item (Join-Path $Build "main.brs") -Force

Write-Host "Created $EmulatorArchive"

