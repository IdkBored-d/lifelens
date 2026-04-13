#!/usr/bin/env python3
"""
Generate synthetic labeled evaluation dataset for validation.
Creates realistic trend and risk rows covering all signal combinations.
Output: evaluation_dataset.jsonl (ready to validate and evaluate)
"""

import json
import random
from pathlib import Path
from typing import List, Dict, Any

# Random seed for reproducibility
random.seed(42)


def generate_trend_rows(count: int = 100) -> List[Dict[str, Any]]:
    """Generate realistic trend validation rows."""
    signal_types = ["sleep", "mood", "activity"]
    trend_labels = ["declining", "stable", "improving"]
    rows = []

    for i in range(count):
        signal_type = random.choice(signal_types)

        # Realistic numeric ranges (matching the expected signal scale)
        if signal_type == "sleep":
            past_avg = random.uniform(4.0, 9.0)
            min_value = 0.0
            max_value = 12.0
        elif signal_type == "mood":
            past_avg = random.uniform(1.0, 5.0)
            min_value = 0.0
            max_value = 5.0
        else:  # activity
            past_avg = random.uniform(0.0, 120.0)  # minutes
            min_value = 0.0
            max_value = 180.0

        # Compute delta and rate to match the label after rounding.
        label = random.choice(trend_labels)
        if label == "improving":
            delta = random.uniform(0.06, 0.25)
            if signal_type == "activity":
                delta = random.uniform(0.5, 8.0)
            recent_avg = min(past_avg + delta, max_value)
        elif label == "declining":
            delta = random.uniform(0.06, 0.25)
            if signal_type == "activity":
                delta = random.uniform(0.5, 8.0)
            recent_avg = max(past_avg - delta, min_value)
        else:  # stable
            recent_avg = past_avg + random.uniform(-0.02, 0.02) * max(past_avg, 1.0)

        past_avg = round(past_avg, 2)
        recent_avg = round(recent_avg, 2)
        actual_delta = round(recent_avg - past_avg, 2)
        actual_rate = round(actual_delta / max(abs(past_avg), 0.1), 2)

        row = {
            "id": f"trend_{i:04d}",
            "dataset_type": "trend",
            "signal_type": signal_type,
            "recent_avg": round(recent_avg, 2),
            "past_avg": round(past_avg, 2),
            "actual_delta": round(actual_delta, 2),
            "actual_rate": round(actual_rate, 2),
            "label": label,
        }
        rows.append(row)

    return rows


def generate_risk_rows(count: int = 100) -> List[Dict[str, Any]]:
    """Generate realistic risk validation rows."""
    risk_labels = ["low", "medium", "high"]
    rows = []

    for i in range(count):
        label = random.choice(risk_labels)

        # Score aligns with label (with some noise)
        if label == "low":
            score = random.uniform(10, 35)
        elif label == "medium":
            score = random.uniform(35, 70)
        else:  # high
            score = random.uniform(70, 95)

        # Risk bucket (optional, but useful for validation)
        if score < 35:
            risk_bucket = "low"
        elif score < 70:
            risk_bucket = "medium"
        else:
            risk_bucket = "high"

        # Realistic feature distributions
        sleep_avg_3 = random.uniform(4.0, 9.0)
        mood_avg_3 = random.uniform(1.0, 5.0)
        activity_min_7 = random.uniform(0.0, 120.0)
        symptom_count = random.randint(0, 8)
        health_score = round(score, 1)

        # Volatility and interaction terms
        sleep_volatility = random.uniform(0.0, 2.0)
        mood_volatility = random.uniform(0.0, 2.0)

        row = {
            "id": f"risk_{i:04d}",
            "dataset_type": "risk",
            "score": round(score, 1),
            "risk_bucket": risk_bucket,
            "label": label,
            "sleep_avg_3": round(sleep_avg_3, 2),
            "mood_avg_3": round(mood_avg_3, 2),
            "activity_min_7": round(activity_min_7, 1),
            "symptom_count": symptom_count,
            "health_score": health_score,
            "sleep_volatility": round(sleep_volatility, 2),
            "mood_volatility": round(mood_volatility, 2),
        }
        rows.append(row)

    return rows


def main():
    """Generate full synthetic dataset and write to JSONL."""
    print("Generating synthetic evaluation dataset...")

    # Generate rows
    trend_rows = generate_trend_rows(100)
    risk_rows = generate_risk_rows(100)

    all_rows = trend_rows + risk_rows
    random.shuffle(all_rows)

    # Write to JSONL
    output_path = Path(__file__).resolve().parent / "evaluation_dataset.jsonl"

    with output_path.open("w", encoding="utf-8") as f:
        for row in all_rows:
            f.write(json.dumps(row) + "\n")

    print(f"✓ Generated {len(all_rows)} rows ({len(trend_rows)} trend + {len(risk_rows)} risk)")
    print(f"✓ Saved to {output_path}")

    # Print summary stats
    print("\nDataset Summary:")
    print(f"  Trend labels: {sum(1 for r in trend_rows if r['label'] == 'declining')} declining, "
          f"{sum(1 for r in trend_rows if r['label'] == 'stable')} stable, "
          f"{sum(1 for r in trend_rows if r['label'] == 'improving')} improving")
    print(f"  Risk labels: {sum(1 for r in risk_rows if r['label'] == 'low')} low, "
          f"{sum(1 for r in risk_rows if r['label'] == 'medium')} medium, "
          f"{sum(1 for r in risk_rows if r['label'] == 'high')} high")


if __name__ == "__main__":
    main()
