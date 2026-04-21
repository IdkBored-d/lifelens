import argparse
import json
import random
from collections import Counter
from pathlib import Path

TRACKED_BUCKETS = ["declining", "stable", "improving", "low_sleep", "low_mood", "high_risk"]


def _bucket_target(target_text: str) -> str:
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


def rebalance_dataset(dataset_path: Path, output_path: Path, threshold: float, seed: int) -> None:
    rows = json.loads(dataset_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise SystemExit("Dataset must be a JSON list")

    grouped = {bucket: [] for bucket in TRACKED_BUCKETS + ["other"]}
    for row in rows:
        if not isinstance(row, dict):
            continue
        target = str(row.get("target", ""))
        bucket = _bucket_target(target)
        grouped.setdefault(bucket, []).append(row)

    tracked_counts = {bucket: len(grouped.get(bucket, [])) for bucket in TRACKED_BUCKETS}
    present = [count for count in tracked_counts.values() if count > 0]
    if len(present) < 2:
        output_path.write_text(json.dumps(rows, indent=2), encoding="utf-8")
        print("Skipped rebalance: insufficient tracked bucket diversity")
        return

    min_count = min(present)
    max_allowed = int(max(1, min_count * threshold))

    random.seed(seed)
    final_rows = []
    for bucket in TRACKED_BUCKETS:
        bucket_rows = grouped.get(bucket, [])
        if len(bucket_rows) > max_allowed:
            random.shuffle(bucket_rows)
            bucket_rows = bucket_rows[:max_allowed]
        final_rows.extend(bucket_rows)

    final_rows.extend(grouped.get("other", []))
    random.shuffle(final_rows)

    output_path.write_text(json.dumps(final_rows, indent=2), encoding="utf-8")

    after_counts = Counter(_bucket_target(str(row.get("target", ""))) for row in final_rows if isinstance(row, dict))
    after_tracked = {bucket: after_counts.get(bucket, 0) for bucket in TRACKED_BUCKETS}
    print("Rebalance complete")
    print(f"Before tracked counts: {tracked_counts}")
    print(f"After tracked counts: {after_tracked}")
    print(f"Kept total rows: {len(final_rows)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Trim overrepresented target buckets to satisfy imbalance threshold")
    parser.add_argument("--dataset", default="summarization_dataset.json")
    parser.add_argument("--output", default="summarization_dataset.json")
    parser.add_argument("--imbalance-ratio-threshold", type=float, default=4.0)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rebalance_dataset(
        dataset_path=Path(args.dataset),
        output_path=Path(args.output),
        threshold=args.imbalance_ratio_threshold,
        seed=args.seed,
    )


if __name__ == "__main__":
    main()
