param(
    [switch]$SkipDownloads
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$incoming = Join-Path $root "incoming"

$redditRaw = Join-Path $incoming "reddit_raw"
$counselRaw = Join-Path $incoming "counselchat_raw"
$sleepRaw = Join-Path $incoming "sleep_health_raw"

New-Item -ItemType Directory -Force -Path $redditRaw | Out-Null
New-Item -ItemType Directory -Force -Path $counselRaw | Out-Null
New-Item -ItemType Directory -Force -Path $sleepRaw | Out-Null

Write-Host "Created raw dataset folders:"
Write-Host "- $redditRaw"
Write-Host "- $counselRaw"
Write-Host "- $sleepRaw"
Write-Host ""
Write-Host "Dataset links:"
Write-Host "- Reddit posts: https://huggingface.co/datasets/jsfactory/mental_health_reddit_posts"
Write-Host "- CounselChat: https://www.kaggle.com/datasets/weiting016/counselchat-data"
Write-Host "- Sleep patterns: https://www.kaggle.com/datasets/siamaktahmasbi/insights-into-sleep-patterns-and-daily-habits"
Write-Host "- TalkLife Moments of Change (manual request): https://www.nature.com/articles/s41746-025-01688-2"
Write-Host ""

if ($SkipDownloads) {
    Write-Host "SkipDownloads enabled. Place exported csv/json/jsonl files into the folders above."
    exit 0
}

$hf = Get-Command huggingface-cli -ErrorAction SilentlyContinue
if ($hf) {
    Write-Host "Downloading Reddit dataset via huggingface-cli..."
    huggingface-cli download jsfactory/mental_health_reddit_posts --repo-type dataset --local-dir $redditRaw
} else {
    Write-Host "huggingface-cli not found. Install with: pip install huggingface_hub"
}

$kaggle = Get-Command kaggle -ErrorAction SilentlyContinue
if ($kaggle) {
    Write-Host "Downloading CounselChat dataset via kaggle..."
    kaggle datasets download -d weiting016/counselchat-data -p $counselRaw --unzip

    Write-Host "Downloading Sleep patterns dataset via kaggle..."
    kaggle datasets download -d siamaktahmasbi/insights-into-sleep-patterns-and-daily-habits -p $sleepRaw --unzip
} else {
    Write-Host "kaggle CLI not found. Install with: pip install kaggle"
    Write-Host "Then set up ~/.kaggle/kaggle.json credentials."
}

Write-Host "Done. Next step: run prepare_external_sources.py"
