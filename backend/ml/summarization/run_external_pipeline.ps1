$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = "d:/Users/He846/OneDrive/Documents/GitHub/lifelens/.venv/Scripts/python.exe"

Push-Location $root
try {
    Write-Host "Step 1/8: Prepare external source files into incoming and incoming_bootstrap"
    & $python prepare_external_sources.py

    Write-Host "Step 2/8: Build dataset from incoming human/app voice rows"
    & $python ingest_dataset.py --incoming-dir incoming --output summarization_dataset.json --no-append-existing

    Write-Host "Step 3/8: Merge synthetic math rows from incoming_bootstrap"
    & $python ingest_dataset.py --incoming-dir incoming_bootstrap --output summarization_dataset.json

    Write-Host "Step 4/8: Inject real wellness text into synthetic targets"
    & $python merge_wellness_dumps.py --dataset summarization_dataset.json --replacements 300

    Write-Host "Step 5/8: Rebalance tracked label buckets"
    & $python rebalance_dataset.py --dataset summarization_dataset.json --output summarization_dataset.json --imbalance-ratio-threshold 4.0

    Write-Host "Step 6/8: Validate summarization dataset contract"
    & $python validate_dataset.py --dataset summarization_dataset.json

    Write-Host "Step 7/8: Smoke training pass (set LL_TRAIN_EPOCHS=1 recommended)"
    & $python run_experiment.py --dataset summarization_dataset.json

    Write-Host "Step 8/8: Done"
    Write-Host "Check reports under your artifact root and inspect summary outputs for token echo sanitization."
}
finally {
    Pop-Location
}
