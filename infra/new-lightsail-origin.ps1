param(
    [string]$InstanceName = "demoscene-roku-origin",
    [string]$Region = "",
    [string]$AvailabilityZone = "",
    [string]$BlueprintId = "ubuntu_24_04",
    [string]$BundleId = "small_3_0",

    [Parameter(Mandatory = $true)]
    [string]$SshCidr,

    [string]$KeyPairName = ""
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

if ($SshCidr -notmatch '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$') {
    throw "SshCidr must be an IPv4 CIDR such as 203.0.113.10/32."
}

if (-not $AvailabilityZone.StartsWith($Region)) {
    throw "AvailabilityZone $AvailabilityZone is not in region $Region."
}

$StaticIpName = "$InstanceName-ip"


function Invoke-Aws {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$AwsArgs
    )

    & aws @AwsArgs --region $Region

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI failed: aws $($AwsArgs -join ' ')"
    }
}


function Test-InstanceExists {
    & aws lightsail get-instance `
        --instance-name $InstanceName `
        --region $Region `
        *> $null

    return ($LASTEXITCODE -eq 0)
}


function Test-StaticIpExists {
    & aws lightsail get-static-ip `
        --static-ip-name $StaticIpName `
        --region $Region `
        *> $null

    return ($LASTEXITCODE -eq 0)
}


#
# 1. Instance
#

if (-not (Test-InstanceExists)) {

    Write-Host "Creating Lightsail instance: $InstanceName"

    $CreateArguments = @(
        "lightsail", "create-instances",
        "--instance-names", $InstanceName,
        "--availability-zone", $AvailabilityZone,
        "--blueprint-id", $BlueprintId,
        "--bundle-id", $BundleId
    )

    if ($KeyPairName) {
        $CreateArguments += @("--key-pair-name", $KeyPairName)
    }

    Invoke-Aws @CreateArguments
}
else {
    Write-Host "Instance already exists. Skipping creation."
}


#
# 2. Wait until running
#

Write-Host "Waiting for instance to be running..."

do {
    $State = & aws lightsail get-instance-state `
        --instance-name $InstanceName `
        --region $Region `
        --query "state.name" `
        --output text

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to get instance state."
    }

    Write-Host "  State: $State"

    if ($State -ne "running") {
        Start-Sleep -Seconds 5
    }

} while ($State -ne "running")


#
# 3. Static IP
#

if (-not (Test-StaticIpExists)) {

    Write-Host "Allocating static IP: $StaticIpName"

    Invoke-Aws lightsail allocate-static-ip `
        --static-ip-name $StaticIpName
}
else {
    Write-Host "Static IP already exists. Skipping allocation."
}


#
# 4. Attach static IP
#

$AttachedTo = & aws lightsail get-static-ip `
    --static-ip-name $StaticIpName `
    --region $Region `
    --query "staticIp.attachedTo" `
    --output text

if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect static IP."
}

if ($AttachedTo -eq $InstanceName) {
    Write-Host "Static IP already attached to instance."
}
elseif ($AttachedTo -and $AttachedTo -ne "None" -and $AttachedTo -ne "null") {
    throw "Static IP is already attached to another resource: $AttachedTo"
}
else {
    Write-Host "Attaching static IP..."

    Invoke-Aws lightsail attach-static-ip `
        --static-ip-name $StaticIpName `
        --instance-name $InstanceName
}


#
# 5. Firewall
#

Write-Host "Configuring firewall..."

$Firewall = @{
    instanceName = $InstanceName

    portInfos = @(
        @{
            fromPort = 22
            toPort   = 22
            protocol = "tcp"
            cidrs    = @($SshCidr)
        },
        @{
            fromPort = 80
            toPort   = 80
            protocol = "tcp"
            cidrs    = @("0.0.0.0/0")
        },
        @{
            fromPort = 443
            toPort   = 443
            protocol = "tcp"
            cidrs    = @("0.0.0.0/0")
        }
    )
}

$FirewallFile = [IO.Path]::GetTempFileName()

try {
    $Firewall |
        ConvertTo-Json -Depth 6 |
        Set-Content $FirewallFile -Encoding ascii

    Invoke-Aws lightsail put-instance-public-ports `
        --cli-input-json "file://$FirewallFile"
}
finally {
    Remove-Item $FirewallFile -Force -ErrorAction SilentlyContinue
}


#
# 6. Result
#

$IP = & aws lightsail get-static-ip `
    --static-ip-name $StaticIpName `
    --region $Region `
    --query "staticIp.ipAddress" `
    --output text

Write-Host ""
Write-Host "========================================="
Write-Host "Lightsail origin ready"
Write-Host "========================================="
Write-Host "Instance: $InstanceName"
Write-Host "Region:   $Region"
Write-Host "IP:       $IP"
Write-Host ""
Write-Host "Point your media domain to:"
Write-Host "  $IP"
Write-Host ""
Write-Host "Then install the origin server:"
Write-Host "  sudo ./install-origin.sh YOUR_DOMAIN YOUR_EMAIL"
Write-Host ""