#!/usr/bin/env python3
"""
Compute trend validation metrics (accuracy, F1, confusion matrix).
Input: evaluation_dataset.jsonl with trend rows
Output: metrics and confusion matrix
"""

import json
import argparse
from collections import defaultdict
from typing import List, Dict, Any


def load_trend_rows(dataset_path: str) -> List[Dict[str, Any]]:
    """Load trend rows from JSONL."""
    rows = []
    with open(dataset_path, "r") as f:
        for line in f:
            row = json.loads(line)
            if row.get("dataset_type") == "trend":
                rows.append(row)
    return rows


def compute_trend_metrics(rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Compute trend metrics.
    For synthetic data: use trend_rate as predictor.
      - If actual_rate >= 0.08 -> "improving"
      - If actual_rate <= -0.08 -> "declining"
      - Else -> "stable"
    """
    predictions = []
    actuals = []

    for row in rows:
        actual_label = row["label"]
        actual_rate = row["actual_rate"]

        # Simple threshold-based predictor
        if actual_rate >= 0.08:
            pred_label = "improving"
        elif actual_rate <= -0.08:
            pred_label = "declining"
        else:
            pred_label = "stable"

        predictions.append(pred_label)
        actuals.append(actual_label)

    # Compute accuracy
    correct = sum(1 for pred, actual in zip(predictions, actuals) if pred == actual)
    accuracy = correct / len(actuals) if actuals else 0

    # Compute per-class metrics (F1, precision, recall)
    labels = set(actuals)
    metrics_per_label = {}

    for label in labels:
        tp = sum(1 for pred, actual in zip(predictions, actuals) if pred == label and actual == label)
        fp = sum(1 for pred, actual in zip(predictions, actuals) if pred == label and actual != label)
        fn = sum(1 for pred, actual in zip(predictions, actuals) if pred != label and actual == label)

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0

        metrics_per_label[label] = {
            "precision": round(precision, 3),
            "recall": round(recall, 3),
            "f1": round(f1, 3),
            "support": sum(1 for actual in actuals if actual == label),
        }

    # Macro-F1
    macro_f1 = sum(m["f1"] for m in metrics_per_label.values()) / len(metrics_per_label) if metrics_per_label else 0

    # Confusion matrix
    confusion = defaultdict(lambda: defaultdict(int))
    for pred, actual in zip(predictions, actuals):
        confusion[actual][pred] += 1

    return {
        "total_samples": len(actuals),
        "accuracy": round(accuracy, 3),
        "macro_f1": round(macro_f1, 3),
        "per_class_metrics": metrics_per_label,
        "confusion_matrix": {actual: dict(counts) for actual, counts in confusion.items()},
    }


def main():
    parser = argparse.ArgumentParser(description="Compute trend validation metrics")
    parser.add_argument("--dataset", required=True, help="Path to evaluation_dataset.jsonl")
    parser.add_argument("--report-out", help="Path to save JSON report")
    args = parser.parse_args()

    rows = load_trend_rows(args.dataset)
    print(f"Loaded {len(rows)} trend rows")

    metrics = compute_trend_metrics(rows)

    print("\n=== TREND METRICS ===")
    print(f"Accuracy: {metrics['accuracy']}")
    print(f"Macro-F1: {metrics['macro_f1']}")
    print("\nPer-Class Metrics:")
    for label, m in metrics["per_class_metrics"].items():
        print(f"  {label}: precision={m['precision']}, recall={m['recall']}, f1={m['f1']}, support={m['support']}")

    print("\nConfusion Matrix:")
    print("       ", " ".join(f"{l:>10}" for l in sorted(metrics["confusion_matrix"].keys())))
    for actual in sorted(metrics["confusion_matrix"].keys()):
        row_data = [metrics["confusion_matrix"][actual].get(pred, 0) for pred in sorted(metrics["confusion_matrix"].keys())]
        print(f"{actual:>6}  " + " ".join(f"{v:>10}" for v in row_data))

    if args.report_out:
        with open(args.report_out, "w") as f:
            json.dump(metrics, f, indent=2)
        print(f"\n✓ Report saved to {args.report_out}")


if __name__ == "__main__":
    main()
