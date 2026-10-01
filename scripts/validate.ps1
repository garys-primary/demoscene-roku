$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$CatalogPath = Join-Path $Root "content/catalog.template.json"
$FontPath = Join-Path $Root "assets/fonts/ShareTechMono-Regular.ttf"

if (-not (Test-Path (Join-Path $Root "manifest"))) {
    throw "Roku manifest is missing."
}
if (-not (Test-Path $FontPath)) {
    throw "Bundled custom font is missing."
}

$Catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
if ($Catalog.schemaVersion -ne 1) {
    throw "Unsupported catalog schema version."
}
if ($Catalog.mediaHost -ne "__MEDIA_BASE_URL__") {
    throw "Catalog mediaHost must use the __MEDIA_BASE_URL__ placeholder."
}
if (-not $Catalog.exhibits -or $Catalog.exhibits.Count -eq 0) {
    throw "Catalog must contain at least one exhibit."
}

foreach ($Exhibit in $Catalog.exhibits) {
    if (-not $Exhibit.id -or -not $Exhibit.title -or -not $Exhibit.streams.h264) {
        throw "Every exhibit needs id, title, and an H.264 stream."
    }
    if (-not $Exhibit.streams.h264.StartsWith("__MEDIA_BASE_URL__/media/")) {
        throw "Exhibit $($Exhibit.id) must use the media URL placeholder."
    }
    if ($null -ne $Exhibit.parts) {
        $Parts = @($Exhibit.parts)
        if ($Parts.Count -lt 2) {
            throw "Exhibit $($Exhibit.id) parts must contain at least two timestamps."
        }
        if ([double]$Parts[0] -ne 0) {
            throw "Exhibit $($Exhibit.id) parts must begin at 0 seconds."
        }

        $PreviousPart = -1.0
        foreach ($Part in $Parts) {
            if (-not ($Part -is [ValueType]) -or $Part -is [bool]) {
                throw "Exhibit $($Exhibit.id) part timestamps must be numeric."
            }
            $PartSeconds = [double]$Part
            if ($PartSeconds -lt 0 -or $PartSeconds -le $PreviousPart) {
                throw "Exhibit $($Exhibit.id) part timestamps must be nonnegative and strictly ascending."
            }
            $PreviousPart = $PartSeconds
        }
    }
    if ($null -ne $Exhibit.guide) {
        if ($null -eq $Exhibit.guide.start -or -not ($Exhibit.guide.start -is [ValueType]) -or $Exhibit.guide.start -is [bool]) {
            throw "Exhibit $($Exhibit.id) guide start must be numeric."
        }
        if ([double]$Exhibit.guide.start -lt 0 -or -not $Exhibit.guide.text) {
            throw "Exhibit $($Exhibit.id) guide needs a nonnegative start and narration text."
        }
    }
    foreach ($Chapter in $Exhibit.quickGuide) {
        if ($Chapter.start -lt 0 -or $Chapter.end -le $Chapter.start -or -not $Chapter.text) {
            throw "Invalid Quick Guide range in $($Exhibit.id)."
        }
    }
}

$XmlFiles = Get-ChildItem (Join-Path $Root "components") -Filter "*.xml" -Recurse
foreach ($XmlFile in $XmlFiles) {
    try {
        [xml](Get-Content $XmlFile.FullName -Raw) | Out-Null
    }
    catch {
        throw "Invalid XML in $($XmlFile.FullName): $($_.Exception.Message)"
    }
}

Push-Location $Root
try {
    & npx bsc --project bsconfig.json
    if ($LASTEXITCODE -ne 0) {
        throw "BrightScript validation failed."
    }
}
finally {
    Pop-Location
}

Write-Host "Catalog, XML, assets, and BrightScript validated."

