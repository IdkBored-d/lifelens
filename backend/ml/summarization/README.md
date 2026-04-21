# LifeLens Summarization Training Workflow

This folder contains the training pipeline for the custom LifeLens summarization model.

## External Data Sources (One-Pass Setup)

Run this to create raw folders and pull public datasets when your CLI auth is configured:

```powershell
powershell -ExecutionPolicy Bypass -File .\download_external_sources.ps1
```

Dataset links:

- Reddit human voice: https://huggingface.co/datasets/jsfactory/mental_health_reddit_posts
- CounselChat app voice: https://www.kaggle.com/datasets/weiting016/counselchat-data
- Sleep health grounding: https://www.kaggle.com/datasets/siamaktahmasbi/insights-into-sleep-patterns-and-daily-habits
- TalkLife moments of change (research-only/manual access): https://www.nature.com/articles/s41746-025-01688-2

If you only want folder scaffolding and will drop files manually:

```powershell
powershell -ExecutionPolicy Bypass -File .\download_external_sources.ps1 -SkipDownloads
```

Parquet support:

- `prepare_external_sources.py` now reads `.parquet` directly from raw folders.
- Install parquet deps once if needed:

```powershell
pip install pandas pyarrow
```

Expected raw folders:

- `incoming/reddit_raw`
- `incoming/counselchat_raw`
- `incoming/sleep_health_raw`

Then run full prep plus smoke pass:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_external_pipeline.ps1
```

What this script does:

1. `prepare_external_sources.py` builds
	- `incoming/reddit_samples.csv`
	- `incoming/counsel_chat.csv`
	- `incoming_bootstrap/synthetic_math.json`
2. `ingest_dataset.py` merges human/app voice + synthetic math into `summarization_dataset.json`
3. `merge_wellness_dumps.py` replaces synthetic targets with real wellness text snippets (default 300 rows)
4. `rebalance_dataset.py` trims overrepresented buckets to pass imbalance checks
5. `validate_dataset.py` checks dataset contract
6. `run_experiment.py` runs validation, training, evaluation, and reporting

Recommended smoke setting:

```powershell
$env:LL_TRAIN_EPOCHS = "1"
```

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

Use this hybrid folder layout:

```text
backend/ml/summarization/
	incoming/
		gold_seed.json
		reddit_samples.csv
		counsel_chat.csv
	incoming_bootstrap/
		synthetic_math.json
```

Drop contributor datasets into `incoming/` as one of:

- `.json` with either a top-level list of rows or an object that contains `rows`, `data`, `items`, or `examples`.
- `.jsonl` with one JSON row per line.
- `.csv` with a header row.

Each row should contain input and target text fields. Supported aliases:

- Input: `input`, `prompt`, `source`, `features`, `text`, `post`, `post_text`, `content`, `question`, `questionText`
- Target: `target`, `summary`, `response`, `output`, `answer`, `answerText`

Notes for the real-world sources:

- `jsfactory/mental_health_reddit_posts` (Hugging Face): map `text` into input-side rows and pair with summary targets before training.
- `weiting016/counselchat-data` (Kaggle): `answerText` works as target voice examples.
- `siamaktahmasbi/insights-into-sleep-patterns-and-daily-habits` (Kaggle): use numerical columns to synthesize realistic input feature strings.

Reference links:

- Reddit posts: https://huggingface.co/datasets/jsfactory/mental_health_reddit_posts
- CounselChat: https://www.kaggle.com/datasets/weiting016/counselchat-data
- Sleep patterns: https://www.kaggle.com/datasets/siamaktahmasbi/insights-into-sleep-patterns-and-daily-habits

If a source arrives as parquet, convert it to csv/json before ingestion.

## 2) Ingest and normalize incoming rows

From `backend/ml/summarization/` run:

```powershell
python ingest_dataset.py --incoming-dir incoming --output summarization_dataset.json

# for bootstrap-only runs:
python ingest_dataset.py --incoming-dir incoming_bootstrap --output summarization_dataset.json --no-append-existing

# for hybrid runs (incoming + bootstrap merged):
python ingest_dataset.py --incoming-dir incoming --output summarization_dataset.json --no-append-existing
python ingest_dataset.py --incoming-dir incoming_bootstrap --output summarization_dataset.json
python merge_wellness_dumps.py --dataset summarization_dataset.json --replacements 300
python rebalance_dataset.py --dataset summarization_dataset.json --output summarization_dataset.json --imbalance-ratio-threshold 4.0
```

Notes:

- `ingest_dataset.py` now preserves `source` and `bucket` fields and prepends numerical anchor tags such as `[LOW_SLEEP][DECLINING_MOOD]` to inputs when feature tokens are present.
- `merge_wellness_dumps.py` keeps bucket logic keywords in targets while injecting real user context text to improve semantic grounding.

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
- Use `LL_GOLD_OVERSAMPLE_FACTOR=5` (default) to oversample `source=gold_seed` rows during training.
- Keep a stable `gold_eval_set.json` for regression checks.
- Only promote a model when malformed output and fallback rates improve on your baseline.
- During first runs, inspect generated summary text to confirm token-echo sanitization (raw feature keys and numeric token dumps should not leak into user-facing responses).