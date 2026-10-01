param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [switch]$IncludeHevc
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputFile)) {
    throw "Input file does not exist: $InputFile"
}
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg is required and was not found on PATH."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Encode-Rendition {
    param(
        [string]$CodecFamily,
        [int]$Height,
        [string]$VideoBitrate,
        [string]$MaxRate,
        [string]$BufferSize,
        [string]$Codec,
        [string[]]$CodecOptions
    )

    $RenditionDirectory = Join-Path $OutputDirectory "$CodecFamily/${Height}p"
    New-Item -ItemType Directory -Force -Path $RenditionDirectory | Out-Null
    $Playlist = Join-Path $RenditionDirectory "index.m3u8"
    $SegmentPattern = Join-Path $RenditionDirectory "segment_%05d.ts"

    $Arguments = @(
        "-hide_banner", "-y",
        "-i", $InputFile,
        "-map", "0:v:0", "-map", "0:a:0?",
        "-vf", "scale=-2:$Height",
        "-c:v", $Codec
    ) + $CodecOptions + @(
        "-b:v", $VideoBitrate,
        "-maxrate", $MaxRate,
        "-bufsize", $BufferSize,
        "-force_key_frames", "expr:gte(t,n_forced*2)",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-hls_time", "2",
        "-hls_playlist_type", "vod",
        "-hls_segment_type", "mpegts",
        "-hls_flags", "independent_segments",
        "-hls_segment_filename", $SegmentPattern,
        $Playlist
    )

    & ffmpeg @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed while encoding $CodecFamily ${Height}p."
    }
}

Encode-Rendition "h264" 360 "900k" "1200k" "1800k" "libx264" @("-profile:v", "high", "-level:v", "4.1", "-pix_fmt", "yuv420p")
Encode-Rendition "h264" 720 "2800k" "3800k" "5600k" "libx264" @("-profile:v", "high", "-level:v", "4.1", "-pix_fmt", "yuv420p")
Encode-Rendition "h264" 1080 "6000k" "8000k" "12000k" "libx264" @("-profile:v", "high", "-level:v", "4.2", "-pix_fmt", "yuv420p")

$H264Master = @"
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=1200000,AVERAGE-BANDWIDTH=900000,RESOLUTION=640x360,CODECS="avc1.64001f,mp4a.40.2"
360p/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3800000,AVERAGE-BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2"
720p/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=8000000,AVERAGE-BANDWIDTH=6000000,RESOLUTION=1920x1080,CODECS="avc1.64002a,mp4a.40.2"
1080p/index.m3u8
"@
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $OutputDirectory "h264/master.m3u8"), $H264Master, $Utf8NoBom)

if ($IncludeHevc) {
    Encode-Rendition "hevc" 1080 "5000k" "7000k" "10000k" "libx265" @("-tag:v", "hvc1", "-pix_fmt", "yuv420p", "-x265-params", "keyint=120:min-keyint=120:scenecut=0")
    Encode-Rendition "hevc" 2160 "16000k" "22000k" "32000k" "libx265" @("-tag:v", "hvc1", "-pix_fmt", "yuv420p", "-x265-params", "keyint=120:min-keyint=120:scenecut=0")

    $HevcMaster = @"
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=7000000,AVERAGE-BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="hvc1.1.6.L123.B0,mp4a.40.2"
1080p/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=22000000,AVERAGE-BANDWIDTH=16000000,RESOLUTION=3840x2160,CODECS="hvc1.1.6.L153.B0,mp4a.40.2"
2160p/index.m3u8
"@
    [IO.File]::WriteAllText((Join-Path $OutputDirectory "hevc/master.m3u8"), $HevcMaster, $Utf8NoBom)
}

Write-Host "HLS output created in $OutputDirectory"

