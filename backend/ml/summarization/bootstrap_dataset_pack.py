import argparse
import json
import random
from pathlib import Path


BUCKETS = ("declining", "stable", "improving", "low_sleep", "low_mood", "high_risk", "mixed")


TEMPLATES = {
    "declining": [
        "Sleep and mood are declining, so short term strain is rising.",
        "Recent patterns are worsening with lower rest and mood over the latest window.",
        "Current signals are declining, so fatigue risk is increasing this week.",
        "Your trend is declining with falling sleep and mood.",
    ],
    "stable": [
        "Your signals are stable right now, with no major short term shift.",
        "Sleep and mood look steady, so continue your current routine consistently.",
        "Recent patterns are balanced overall and do not show strong movement.",
        "The latest window appears stable with manageable short term risk.",
    ],
    "improving": [
        "Your trend is improving with gradual gains in sleep and mood.",
        "Recent data suggests recovery momentum across key wellbeing indicators.",
        "Sleep and mood are moving in a healthier direction this week.",
        "The latest window shows improvement and better short term resilience.",
    ],
    "low_sleep": [
        "Low sleep is the main concern right now and should be prioritized first.",
        "Sleep remains below target, so recovery habits should be your top focus.",
        "Low sleep remains the weakest signal and needs immediate support.",
        "Low sleep debt is building even though other indicators are only mildly affected.",
    ],
    "low_mood": [
        "Low mood is the dominant concern in the current window.",
        "Mood remains below baseline and may need added support this week.",
        "Low mood is persisting despite moderate movement elsewhere.",
        "Your recent pattern is mostly limited by low mood levels.",
    ],
    "high_risk": [
        "Overall short term risk is elevated due to reinforcing negative signals.",
        "Combined indicators suggest a high risk profile that needs close follow up.",
        "Current trends point to heightened risk and require careful monitoring.",
        "Risk remains high as multiple core signals continue to deteriorate.",
    ],
    "mixed": [
        "Signals are mixed, so progress is uneven and should be monitored closely.",
        "Some indicators improved while others declined, leading to a mixed pattern.",
        "Your recent window is inconsistent, with offsetting gains and losses.",
        "The trend is mixed overall and best treated as cautiously stable.",
    ],
}


def _format_input(sample: dict) -> str:
    return (
        f"sleep_avg_3={sample['sleep_avg_3']:.2f} "
        f"mood_avg_3={sample['mood_avg_3']:.2f} "
        f"sleep_slope={sample['sleep_slope']:.3f} "
        f"mood_slope={sample['mood_slope']:.3f} "
        f"risk={sample['risk']:.2f} "
        f"trend={sample['trend']:.3f}"
    )


def _sample_by_bucket(bucket: str) -> dict:
    if bucket == "declining":
        return {
            "sleep_avg_3": random.uniform(4.2, 6.2),
            "mood_avg_3": random.uniform(1.1, 3.0),
            "sleep_slope": random.uniform(-0.70, -0.15),
            "mood_slope": random.uniform(-0.62, -0.12),
            "risk": random.uniform(58.0, 92.0),
            "trend": random.uniform(-0.60, -0.12),
        }
    if bucket == "stable":
        return {
            "sleep_avg_3": random.uniform(6.0, 7.8),
            "mood_avg_3": random.uniform(3.0, 4.6),
            "sleep_slope": random.uniform(-0.07, 0.07),
            "mood_slope": random.uniform(-0.07, 0.07),
            "risk": random.uniform(30.0, 65.0),
            "trend": random.uniform(-0.07, 0.07),
        }
    if bucket == "improving":
        return {
            "sleep_avg_3": random.uniform(5.1, 7.8),
            "mood_avg_3": random.uniform(2.6, 4.8),
            "sleep_slope": random.uniform(0.10, 0.62),
            "mood_slope": random.uniform(0.10, 0.56),
            "risk": random.uniform(22.0, 55.0),
            "trend": random.uniform(0.10, 0.56),
        }
    if bucket == "low_sleep":
        return {
            "sleep_avg_3": random.uniform(2.8, 5.0),
            "mood_avg_3": random.uniform(2.4, 4.4),
            "sleep_slope": random.uniform(-0.25, 0.08),
            "mood_slope": random.uniform(-0.18, 0.16),
            "risk": random.uniform(45.0, 82.0),
            "trend": random.uniform(-0.22, 0.08),
        }
    if bucket == "low_mood":
        return {
            "sleep_avg_3": random.uniform(5.4, 7.8),
            "mood_avg_3": random.uniform(0.6, 2.0),
            "sleep_slope": random.uniform(-0.14, 0.16),
            "mood_slope": random.uniform(-0.30, 0.05),
            "risk": random.uniform(44.0, 85.0),
            "trend": random.uniform(-0.26, 0.06),
        }
    if bucket == "high_risk":
        return {
            "sleep_avg_3": random.uniform(3.2, 5.8),
            "mood_avg_3": random.uniform(0.8, 2.4),
            "sleep_slope": random.uniform(-0.65, -0.10),
            "mood_slope": random.uniform(-0.60, -0.10),
            "risk": random.uniform(72.0, 100.0),
            "trend": random.uniform(-0.62, -0.10),
        }
    return {
        "sleep_avg_3": random.uniform(4.6, 7.2),
        "mood_avg_3": random.uniform(1.8, 4.2),
        "sleep_slope": random.uniform(-0.35, 0.35),
        "mood_slope": random.uniform(-0.35, 0.35),
        "risk": random.uniform(32.0, 78.0),
        "trend": random.uniform(-0.35, 0.35),
    }


def _build_rows(total: int, bucket_weights: dict[str, int], tag: str) -> list[dict]:
    weight_sum = sum(bucket_weights.values())
    raw_counts = {bucket: (total * w) / weight_sum for bucket, w in bucket_weights.items()}
    counts = {bucket: int(value) for bucket, value in raw_counts.items()}

    remainder = total - sum(counts.values())
    if remainder > 0:
        order = sorted(BUCKETS, key=lambda b: raw_counts.get(b, 0) - counts.get(b, 0), reverse=True)
        for bucket in order[:remainder]:
            counts[bucket] += 1

    rows = []
    for bucket in BUCKETS:
        for _ in range(counts.get(bucket, 0)):
            sample = _sample_by_bucket(bucket)
            rows.append(
                {
                    "input": _format_input(sample),
                    "target": random.choice(TEMPLATES[bucket]),
                    "source": tag,
                    "bucket": bucket,
                }
            )

    random.shuffle(rows)
    return rows


def _write_rows(path: Path, rows: list[dict]) -> None:
    path.write_text(json.dumps(rows, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Create starter summarization datasets with a 60/30/10 split")
    parser.add_argument("--output-dir", default="incoming")
    parser.add_argument("--total", type=int, default=500)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    random.seed(args.seed)
    total = max(100, args.total)

    gold_n = int(total * 0.60)
    silver_n = int(total * 0.30)
    edge_n = total - gold_n - silver_n

    output_dir = Path(__file__).resolve().parent / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    gold_rows = _build_rows(
        total=gold_n,
        bucket_weights={
            "declining": 17,
            "stable": 16,
            "improving": 16,
            "low_sleep": 16,
            "low_mood": 16,
            "high_risk": 16,
            "mixed": 3,
        },
        tag="gold_seed",
    )

    silver_rows = _build_rows(
        total=silver_n,
        bucket_weights={
            "declining": 16,
            "stable": 16,
            "improving": 16,
            "low_sleep": 16,
            "low_mood": 16,
            "high_risk": 16,
            "mixed": 4,
        },
        tag="silver_synthetic",
    )

    edge_rows = _build_rows(
        total=edge_n,
        bucket_weights={
            "declining": 12,
            "stable": 10,
            "improving": 10,
            "low_sleep": 20,
            "low_mood": 20,
            "high_risk": 24,
            "mixed": 4,
        },
        tag="edge_case",
    )

    gold_path = output_dir / "gold_seed_rows.json"
    silver_path = output_dir / "silver_synthetic_rows.json"
    edge_path = output_dir / "edge_case_rows.json"

    _write_rows(gold_path, gold_rows)
    _write_rows(silver_path, silver_rows)
    _write_rows(edge_path, edge_rows)

    manifest = {
        "total": total,
        "split": {
            "gold_seed": len(gold_rows),
            "silver_synthetic": len(silver_rows),
            "edge_case": len(edge_rows),
        },
        "files": {
            "gold_seed": str(gold_path),
            "silver_synthetic": str(silver_path),
            "edge_case": str(edge_path),
        },
    }
    (output_dir / "dataset_pack_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print("Created starter dataset pack")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()