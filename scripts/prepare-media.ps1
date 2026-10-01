param(
    [switch]$RepairOnly
)

$ErrorActionPreference = "Stop"

$RootDir   = Split-Path $PSScriptRoot -Parent
$SourceDir = Join-Path $RootDir "media-src"
$OutputDir = Join-Path $RootDir "media"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg not found in PATH."
}
if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    throw "ffprobe not found in PATH."
}

function Update-HlsPackage {
    param([Parameter(Mandatory = $true)][string]$VideoDir)

    $PlaylistPath = Join-Path $VideoDir "playlist.m3u8"
    if (-not (Test-Path $PlaylistPath)) {
        throw "Missing playlist in $VideoDir"
    }

    $MaxDuration = 0.0
    $Duration = 0.0
    $Refs = 0
    $Missing = 0
    $ExpectSegment = $false
    foreach ($Line in Get-Content $PlaylistPath) {
        if ($Line -like "#EXTINF:*") {
            $Raw = $Line.Substring(8).Trim().TrimEnd(",")
            $SegmentDuration = [double]$Raw
            $Duration += $SegmentDuration
            if ($SegmentDuration -gt $MaxDuration) { $MaxDuration = $SegmentDuration }
            $ExpectSegment = $true
        }
        elseif ($ExpectSegment -and $Line -and -not $Line.StartsWith("#")) {
            $Refs++
            $ExpectSegment = $false
            if (-not (Test-Path (Join-Path $VideoDir $Line.Trim()))) { $Missing++ }
        }
    }

    $PlaylistText = [IO.File]::ReadAllText($PlaylistPath)
    if ($PlaylistText -notmatch "#EXT-X-ENDLIST") {
        throw "Playlist is not a finished VOD file: $PlaylistPath"
    }
    if ($Refs -eq 0 -or $Missing -gt 0 -or $Duration -le 0) {
        throw "Segments are incomplete in ${VideoDir}: missing=$Missing refs=$Refs"
    }

    $Target = [int][Math]::Ceiling($MaxDuration - 0.0000001)
    if ($Target -lt 1) { $Target = 1 }
    $Updated = [regex]::Replace($PlaylistText, "#EXT-X-TARGETDURATION:\d+", "#EXT-X-TARGETDURATION:$Target")
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    if ($Updated -ne $PlaylistText) {
        [IO.File]::WriteAllText($PlaylistPath, $Updated, $Utf8)
    }

    $Segment = Get-ChildItem $VideoDir -Filter "segment000.ts" | Select-Object -First 1
    if (-not $Segment) { throw "No segment000.ts in $VideoDir" }

    $Probe = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height,codec_name,profile,pix_fmt,level -of json -- $Segment.FullName | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $Probe.streams) {
        throw "ffprobe failed for $($Segment.FullName)"
    }
    $Video = $Probe.streams[0]
    if ($Video.codec_name -ne "h264" -or $Video.pix_fmt -ne "yuv420p") {
        throw "Unsupported video in $($VideoDir): $($Video.codec_name) $($Video.pix_fmt)"
    }
    if (([int]$Video.width % 2) -ne 0 -or ([int]$Video.height % 2) -ne 0) {
        throw "Video dimensions must be divisible by 2: $($Video.width)x$($Video.height) in $VideoDir"
    }

    $Audio = & ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,profile,sample_rate,channels -of json -- $Segment.FullName | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $Audio.streams) {
        throw "Missing AAC audio in $VideoDir"
    }
    $AudioStream = $Audio.streams[0]
    if ($AudioStream.codec_name -ne "aac" -or $AudioStream.profile -ne "LC") {
        throw "Audio must be AAC-LC in $VideoDir"
    }

    $Bytes = (Get-ChildItem $VideoDir -Filter "*.ts" | Measure-Object Length -Sum).Sum
    $Average = [int][Math]::Ceiling(($Bytes * 8.0) / $Duration)
    $Peak = [int][Math]::Ceiling($Average * 1.25)
    $Level = [int]$Video.level
    $Codec = "avc1.6400{0:x2}" -f $Level
    $Master = @(
        "#EXTM3U",
        "#EXT-X-VERSION:4",
        "#EXT-X-STREAM-INF:BANDWIDTH=$Peak,AVERAGE-BANDWIDTH=$Average,RESOLUTION=$($Video.width)x$($Video.height),CODECS=`"$Codec,mp4a.40.2`",CLOSED-CAPTIONS=NONE",
        "playlist.m3u8",
        ""
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $VideoDir "master.m3u8"), $Master, $Utf8)

    Write-Host ("Ready {0}  {1}x{2}  {3}  avg={4}kbps" -f (Split-Path $VideoDir -Leaf), $Video.width, $Video.height, $Codec, [int]($Average / 1000))
}

if ($RepairOnly) {
    if (-not (Test-Path $OutputDir)) { throw "media directory does not exist: $OutputDir" }
    Get-ChildItem $OutputDir -Directory | ForEach-Object { Update-HlsPackage $_.FullName }
    Write-Host "Checked HLS packages in $OutputDir"
    return
}

if (-not (Test-Path $SourceDir)) {
    throw "media-src directory does not exist: $SourceDir"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Get-ChildItem $SourceDir -Filter *.mp4 | ForEach-Object {
    $InputFile = $_.FullName
    $Name = $_.BaseName
    $VideoDir = Join-Path $OutputDir $Name

    Write-Host ""
    Write-Host "Preparing: $($_.Name)"

    Remove-Item $VideoDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $VideoDir | Out-Null

    $Playlist = Join-Path $VideoDir "playlist.m3u8"
    $Segments = Join-Path $VideoDir "segment%03d.ts"

    & ffmpeg `
        -y `
        -i $InputFile `
        -vf "pad=ceil(iw/16)*16:ceil(ih/2)*2:(ow-iw)/2:(oh-ih)/2:black" `
        -c:v libx264 `
        -preset medium `
        -crf 20 `
        -pix_fmt yuv420p `
        -profile:v high `
        -c:a aac `
        -b:a 160k `
        -ac 2 `
        -ar 48000 `
        -hls_time 6 `
        -hls_playlist_type vod `
        -hls_segment_filename $Segments `
        $Playlist
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed for $($_.Name)" }

    Update-HlsPackage $VideoDir
}

Write-Host ""
Write-Host "Done."
Write-Host "HLS output: $OutputDir"
