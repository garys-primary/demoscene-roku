param(
    [string]$Region = "",
    [string]$AvailabilityZone = "",
    [string]$InstanceName = "demoscene-roku-origin",
    [string]$KeyPairName = "demoscene-roku",
    [string]$PemPath = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
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

if (-not $Region) {
    $Region = $envVars["AWS_REGION"]
}
if (-not $AvailabilityZone) {
    $AvailabilityZone = $envVars["AWS_AVAILABILITY_ZONE"]
}
if (-not $Region -or -not $AvailabilityZone) {
    throw "AWS_REGION and AWS_AVAILABILITY_ZONE are required in .env."
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "AWS CLI is required."
}
if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    throw "OpenSSH ssh-keygen is required to import the Lightsail key."
}

& aws sts get-caller-identity --region $Region --output text
if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI rejected the current credentials. Refresh them with 'aws configure', then run this script again."
}

if (-not $PemPath) {
    $PemPath = Join-Path $Root "demoscene-roku.pem"
}
if (-not (Test-Path $PemPath)) {
    throw "PEM file not found: $PemPath"
}

& icacls $PemPath /inheritance:r | Out-Null
& icacls $PemPath /grant:r "${env:USERNAME}:(R)" | Out-Null

$PublicKey = & ssh-keygen -y -f $PemPath
if ($LASTEXITCODE -ne 0 -or -not $PublicKey) {
    throw "Could not read the public key from $PemPath"
}

$PublicKeyBytes = [Text.Encoding]::ASCII.GetBytes($PublicKey.Trim() + "`n")
$PublicKeyBase64 = [Convert]::ToBase64String($PublicKeyBytes)
$PreviousPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$Existing = & aws lightsail get-key-pair --region $Region --key-pair-name $KeyPairName --query "keyPair.name" --output text 2>$null
$LookupCode = $LASTEXITCODE
$ErrorActionPreference = $PreviousPreference
if ($LookupCode -ne 0 -or $Existing -eq "None") {
    & aws lightsail import-key-pair --region $Region --key-pair-name $KeyPairName --public-key-base64 $PublicKeyBase64
    if ($LASTEXITCODE -ne 0) { throw "Could not import the Lightsail key pair." }
}

$PublicIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com" -TimeoutSec 20).ToString().Trim()
if ($PublicIp -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
    throw "Could not determine this machine's public IP."
}

& (Join-Path $Root "infra\new-lightsail-origin.ps1") `
    -InstanceName $InstanceName `
    -Region $Region `
    -AvailabilityZone $AvailabilityZone `
    -SshCidr "$PublicIp/32" `
    -KeyPairName $KeyPairName
