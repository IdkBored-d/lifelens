import argparse
import csv
import json
import random
from collections import Counter
from pathlib import Path

TRACKED_BUCKETS = ["declining", "stable", "improving", "low_sleep", "low_mood", "high_risk"]
SYNTHETIC_SOURCES = {
    "sleep_health_grounding",
    "silver_synthetic",
    "synthetic_math",
    "synthetic",
    "unknown",
}


def _bucket_from_target(target_text: str) -> str:
    t = target_text.lower()
    if "high" in t and "risk" in t:
        return "high_risk"
    if "low sleep" in t or "sleep deficit" in t:
        return "low_sleep"
    if "low mood" in t or ("mood" in t and "low" in t):
        return "low_mood"
    if "improv" in t or "recover" in t:
        return "improving"
    if "declin" in t or "worsen" in t:
        return "declining"
    if "stable" in t or "steady" in t:
        return "stable"
    return "other"


def _extract_user_text(input_text: str) -> str:
    marker = "user_text="
    idx = input_text.find(marker)
    if idx == -1:
        return ""
    text = input_text[idx + len(marker) :].strip()
    text = " ".join(text.split())
    return text[:180]


def _iter_csv_rows(path: Path):
    if not path.exists():
        return
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            yield row


def _build_wellness_pool(reddit_csv: Path, counsel_csv: Path) -> dict[str, list[str]]:
    pool = {bucket: [] for bucket in TRACKED_BUCKETS}

    for row in _iter_csv_rows(reddit_csv):
        target = str(row.get("target", "")).strip()
        bucket = _bucket_from_target(target)
        if bucket not in pool:
            continue
        text = _extract_user_text(str(row.get("input", "")))
        if not text:
            continue
        pool[bucket].append(text)

    for row in _iter_csv_rows(counsel_csv):
        target = str(row.get("target", "")).strip()
        bucket = _bucket_from_target(target)
        if bucket not in pool:
            continue
        text = _extract_user_text(str(row.get("input", "")))
        if not text:
            continue
        pool[bucket].append(text)

    return pool


def _compose_target(bucket: str, wellness_text: str) -> str:
    prefixes = {
        "declining": "Your trend looks declining this week, with rising strain and reduced resilience.",
        "stable": "Current pattern appears stable, with no major short-term disruption.",
        "improving": "Your trend is improving, with better short-term resilience and recovery momentum.",
        "low_sleep": "Low sleep is the main concern right now, so prioritize rest structure and recovery habits.",
        "low_mood": "Low mood is the dominant concern in this window, so use gentle routines and supportive check-ins.",
        "high_risk": "Current pattern suggests high risk, and close support is recommended in the near term.",
    }
    prefix = prefixes.get(bucket, prefixes["stable"])
    return f"{prefix} Example user context: {wellness_text}"


def _is_synthetic_row(row: dict) -> bool:
    source = str(row.get("source", "")).strip().lower()
    if source in SYNTHETIC_SOURCES:
        return True
    if "synthetic" in source:
        return True
    if source.startswith("sleep_health"):
        return True
    return False


def merge_wellness(
    dataset_path: Path,
    reddit_csv: Path,
    counsel_csv: Path,
    replacements: int,
    seed: int,
) -> None:
    rows = json.loads(dataset_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise SystemExit("Dataset must be a JSON list")

    wellness_pool = _build_wellness_pool(reddit_csv, counsel_csv)
    available = {bucket: len(texts) for bucket, texts in wellness_pool.items()}

    random.seed(seed)
    candidate_indices = []
    for i, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        if not _is_synthetic_row(row):
            continue
        bucket = str(row.get("bucket", "")).strip().lower() or _bucket_from_target(str(row.get("target", "")))
        if bucket not in TRACKED_BUCKETS:
            continue
        if not wellness_pool.get(bucket):
            continue
        candidate_indices.append(i)

    random.shuffle(candidate_indices)
    selected = candidate_indices[: max(0, replacements)]

    updated = 0
    by_bucket = Counter()
    for idx in selected:
        row = rows[idx]
        bucket = str(row.get("bucket", "")).strip().lower() or _bucket_from_target(str(row.get("target", "")))
        if bucket not in TRACKED_BUCKETS:
            continue
        texts = wellness_pool.get(bucket, [])
        if not texts:
            continue
        chosen = random.choice(texts)
        row["target"] = _compose_target(bucket, chosen)
        row["source"] = "wellness_hybrid"
        row["bucket"] = bucket
        updated += 1
        by_bucket[bucket] += 1

    dataset_path.write_text(json.dumps(rows, indent=2), encoding="utf-8")

    print("Wellness merge complete")
    print(f"Updated rows: {updated}")
    print(f"Pool availability: {available}")
    print(f"Updates by bucket: {dict(by_bucket)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Inject real wellness text into synthetic targets")
    parser.add_argument("--dataset", default="summarization_dataset.json")
    parser.add_argument("--reddit-csv", default="incoming/reddit_samples.csv")
    parser.add_argument("--counsel-csv", default="incoming/counsel_chat.csv")
    parser.add_argument("--replacements", type=int, default=300)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    base = Path(__file__).resolve().parent
    dataset_path = base / args.dataset
    reddit_csv = base / args.reddit_csv
    counsel_csv = base / args.counsel_csv

    merge_wellness(
        dataset_path=dataset_path,
        reddit_csv=reddit_csv,
        counsel_csv=counsel_csv,
        replacements=args.replacements,
        seed=args.seed,
    )


if __name__ == "__main__":
    main()
