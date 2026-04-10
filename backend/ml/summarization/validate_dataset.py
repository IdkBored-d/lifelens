import argparse
import json
import re
from collections import Counter
from pathlib import Path


REQUIRED_KEYS = (
    "sleep_avg_3",
    "mood_avg_3",
    "sleep_slope",
    "mood_slope",
    "risk",
    "trend",
)

RANGES = {
    "sleep_avg_3": (0.0, 12.0),
    "mood_avg_3": (0.0, 5.0),
    "sleep_slope": (-2.0, 2.0),
    "mood_slope": (-2.0, 2.0),
    "risk": (0.0, 100.0),
    "trend": (-2.0, 2.0),
}


def _parse_input_tokens(input_text: str):
    values = {}
    for token in input_text.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        try:
            values[key] = float(value)
        except ValueError:
            values[key] = None
    return values


def _bucket_target(target_text: str) -> str:
    t = target_text.lower()
    if "high" in t and "risk" in t:
        return "high_risk"
    if "low sleep" in t or "sleep deficit" in t:
        return "low_sleep"
    if "low mood" in t or "mood" in t and "low" in t:
        return "low_mood"
    if "improv" in t or "recover" in t:
        return "improving"
    if "declin" in t or "worsen" in t:
        return "declining"
    if "stable" in t or "steady" in t:
        return "stable"
    return "other"


def validate_dataset(dataset_path: Path, imbalance_ratio_threshold: float) -> int:
    errors = []
    warnings = []

    rows = json.loads(dataset_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list) or not rows:
        print("ERROR: dataset must be a non-empty JSON array")
        return 1

    seen = set()
    bucket_counter = Counter()

    for index, row in enumerate(rows):
        prefix = f"row[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix}: must be an object")
            continue

        input_text = str(row.get("input", "")).strip()
        target_text = str(row.get("target", "")).strip()

        if not input_text:
            errors.append(f"{prefix}: missing or empty input")
        if not target_text:
            errors.append(f"{prefix}: missing or empty target")

        dedupe_key = (input_text.lower(), target_text.lower())
        if dedupe_key in seen:
            errors.append(f"{prefix}: duplicate input-target pair")
        seen.add(dedupe_key)

        if input_text:
            parsed = _parse_input_tokens(input_text)
            for key in REQUIRED_KEYS:
                if key not in parsed:
                    errors.append(f"{prefix}: missing token {key} in input")
                    continue
                value = parsed[key]
                if value is None:
                    errors.append(f"{prefix}: token {key} has non-numeric value")
                    continue
                low, high = RANGES[key]
                if value < low or value > high:
                    errors.append(f"{prefix}: token {key} out of range [{low}, {high}] => {value}")

        if target_text:
            if any(token in target_text.lower() for token in ("sleep_avg_3=", "mood_avg_3=", "risk=", "trend=")):
                errors.append(f"{prefix}: target appears to contain malformed token echo")
            if re.search(r"\b(\w+)(\s+\1){2,}\b", target_text.lower()):
                warnings.append(f"{prefix}: repetitive target wording")

        bucket_counter[_bucket_target(target_text)] += 1

    tracked_buckets = ["declining", "stable", "improving", "low_sleep", "low_mood", "high_risk"]
    present = [bucket_counter[b] for b in tracked_buckets if bucket_counter[b] > 0]
    if len(present) >= 2:
        ratio = max(present) / max(1, min(present))
        if ratio > imbalance_ratio_threshold:
            errors.append(
                f"label imbalance too high: max/min ratio={ratio:.2f}, threshold={imbalance_ratio_threshold:.2f}"
            )
    else:
        warnings.append("insufficient label diversity across tracked buckets")

    print(f"Validated rows: {len(rows)}")
    print(f"Bucket counts: {dict(bucket_counter)}")
    if warnings:
        print("Warnings:")
        for warning in warnings[:20]:
            print(f"- {warning}")

    if errors:
        print("Errors:")
        for err in errors[:50]:
            print(f"- {err}")
        print(f"Validation failed with {len(errors)} errors")
        return 1

    print("Validation passed")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Validate summarization training dataset")
    parser.add_argument("--dataset", default="summarization_dataset.json")
    parser.add_argument("--imbalance-ratio-threshold", type=float, default=4.0)
    args = parser.parse_args()

    dataset_path = Path(args.dataset)
    exit_code = validate_dataset(dataset_path, args.imbalance_ratio_threshold)
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()