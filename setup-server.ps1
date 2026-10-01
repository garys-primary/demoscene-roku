$ErrorActionPreference = "Stop"

$RootDir = $PSScriptRoot

$envVars = @{}
Get-Content (Join-Path $RootDir ".env") | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') {
        $envVars[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
    }
}

$Email  = $envVars["AWS_EMAIL"]
$Domain = $envVars["LIGHTSAIL_DOMAIN"]
$IP     = $envVars["LIGHTSAIL_IP"]
$Key    = $envVars["LIGHTSAIL_KEY"]

$Source = Join-Path $RootDir "infra"
$Dist   = Join-Path $RootDir "infra-dist"
$Server = "ubuntu@$IP"

Write-Host "Preparing infra-dist..."

Remove-Item $Dist -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $Source $Dist -Recurse

Get-ChildItem $Dist -Recurse -File |
Where-Object { $_.Extension -in ".sh", ".conf" } |
ForEach-Object {
    $text = Get-Content $_.FullName -Raw
    $text = $text -replace "`r`n", "`n"

    [IO.File]::WriteAllText(
        $_.FullName,
        $text,
        [Text.UTF8Encoding]::new($false)
    )
}

Write-Host "Uploading..."

scp -i $Key -r $Dist "$Server`:/home/ubuntu/infra"

if ($LASTEXITCODE -ne 0) {
    throw "SCP upload failed."
}

Write-Host "Installing origin server..."

ssh -i $Key $Server `
    "sudo bash ~/infra/install-origin.sh '$Domain' '$Email'"

if ($LASTEXITCODE -ne 0) {
    throw "Server setup failed."
}

Remove-Item $Dist -Recurse -Force

Write-Host ""
Write-Host "Server ready:"
Write-Host "https://$Domain/health"