$ErrorActionPreference = "Stop"

$Request = @"
M-SEARCH * HTTP/1.1`r
HOST: 239.255.255.250:1900`r
MAN: "ssdp:discover"`r
MX: 2`r
ST: roku:ecp`r
`r
"@

$Client = New-Object System.Net.Sockets.UdpClient
$Client.Client.ReceiveTimeout = 3000
$Target = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse("239.255.255.250")), 1900
$Bytes = [Text.Encoding]::ASCII.GetBytes($Request)
[void]$Client.Send($Bytes, $Bytes.Length, $Target)

$Found = @{}
$Deadline = [DateTime]::UtcNow.AddSeconds(4)
while ([DateTime]::UtcNow -lt $Deadline) {
    try {
        $Remote = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
        $Response = [Text.Encoding]::ASCII.GetString($Client.Receive([ref]$Remote))
        if ($Response -match '(?im)^LOCATION:\s*(.+)$') {
            $Location = $Matches[1].Trim()
            $Found[$Location] = $Remote.Address.IPAddressToString
        }
    }
    catch [System.Net.Sockets.SocketException] {
        break
    }
}
$Client.Close()

if ($Found.Count -eq 0) {
    Write-Output "No Roku ECP device responded on this network."
    exit 2
}

foreach ($Location in $Found.Keys) {
    Write-Output "$($Found[$Location])`t$Location"
}

