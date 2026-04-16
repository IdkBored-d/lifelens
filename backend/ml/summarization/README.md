# LifeLens Summarization Training Workflow

This folder contains the training pipeline for the custom LifeLens summarization model.

## No Dataset Yet?

If you do not have any files yet, generate a starter 60/30/10 pack first:

```powershell
python bootstrap_dataset_pack.py --output-dir incoming_bootstrap --total 500
```

This creates:

- `incoming_bootstrap/gold_seed_rows.json` (60%)
- `incoming_bootstrap/silver_synthetic_rows.json` (30%)
- `incoming_bootstrap/edge_case_rows.json` (10%)

Then run ingestion and validation as usual.

## 1) Add dataset files

Drop contributor datasets into `incoming/` as one of:

- `.json` with either a top-level list of rows or an object that contains `rows`, `data`, `items`, or `examples`.
- `.jsonl` with one JSON row per line.

Each row should contain input and target text fields. Supported aliases:

- Input: `input`, `prompt`, `source`, `features`
- Target: `target`, `summary`, `response`, `output`

## 2) Ingest and normalize incoming rows

From `backend/ml/summarization/` run:

```powershell
python ingest_dataset.py --incoming-dir incoming --output summarization_dataset.json

# for bootstrap-only runs:
python ingest_dataset.py --incoming-dir incoming_bootstrap --output summarization_dataset.json --no-append-existing
```

Optional clean rebuild (ignore existing output file rows):

```powershell
python ingest_dataset.py --incoming-dir incoming --output summarization_dataset.json --no-append-existing
```

## 3) Validate dataset contract

```powershell
python validate_dataset.py --dataset summarization_dataset.json
```

Fix all reported errors before training.

## 4) Configure artifact storage outside git

Set this once per shell session:

```powershell
$env:LL_ML_ARTIFACTS_DIR = "D:\lifelens-ml-artifacts"
```

## 5) Run tracked experiment

```powershell
python run_experiment.py --dataset summarization_dataset.json
```

The run executes:

1. Validation
2. Training
3. Evaluation
4. Report generation

Reports are written under the artifact root in `reports/`.

## 6) Quick iteration tips

- Use `LL_TRAIN_EPOCHS=1` for smoke tests before longer runs.
- Keep a stable `gold_eval_set.json` for regression checks.
- Only promote a model when malformed output and fallback rates improve on your baseline.