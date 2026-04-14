#!/usr/bin/env python3
"""
Compute risk validation metrics (AUC, calibration, Brier score, correlation).
Input: evaluation_dataset.jsonl with risk rows
Output: comprehensive risk assessment metrics
"""

import json
import argparse
from typing import List, Dict, Any


def load_risk_rows(dataset_path: str) -> List[Dict[str, Any]]:
    """Load risk rows from JSONL."""
    rows = []
    with open(dataset_path, "r") as f:
        for line in f:
            row = json.loads(line)
            if row.get("dataset_type") == "risk":
                rows.append(row)
    return rows


def label_to_score(label: str) -> float:
    """Convert label to numeric score for calculations."""
    mapping = {"low": 0.0, "medium": 0.5, "high": 1.0}
    return mapping.get(label, 0.5)


def score_to_label(score: float) -> str:
    """Convert score to label using thresholds."""
    if score < 0.35:
        return "low"
    elif score < 0.7:
        return "medium"
    else:
        return "high"


def compute_auc(predictions: List[float], actuals: List[float]) -> float:
    """Compute Area Under the Curve (AUC) for binary 'high risk' classification."""
    # Binary classification: high risk (1) vs not high risk (0)
    binary_preds = [1.0 if p >= 0.7 else 0.0 for p in predictions]
    binary_actuals = [1.0 if a >= 0.7 else 0.0 for a in actuals]

    # Simple AUC: sort by prediction, count concordant pairs
    if len(set(binary_actuals)) < 2:
        return 0.5  # Cannot compute AUC with single class

    # Sort by prediction scores
    sorted_pairs = sorted(zip(predictions, binary_actuals), reverse=True)

    positives = sum(binary_actuals)
    negatives = len(binary_actuals) - positives

    if positives == 0 or negatives == 0:
        return 0.5

    # Count concordant pairs
    concordant = 0
    for i, (pred_i, actual_i) in enumerate(sorted_pairs):
        for pred_j, actual_j in sorted_pairs[i + 1 :]:
            if actual_i > actual_j:  # actual_i is positive, actual_j is negative
                if pred_i > pred_j:
                    concordant += 1
            elif actual_i < actual_j:  # actual_i is negative, actual_j is positive
                if pred_i < pred_j:
                    concordant += 1

    total_pairs = positives * negatives
    auc = concordant / total_pairs if total_pairs > 0 else 0.5

    return auc


def compute_brier_score(predictions: List[float], actuals: List[float]) -> float:
    """Compute Brier score (mean squared error of probabilities)."""
    if not predictions:
        return 0.0
    mse = sum((pred - actual) ** 2 for pred, actual in zip(predictions, actuals)) / len(predictions)
    return mse


def compute_calibration(predictions: List[float], actuals: List[float], bins: int = 5) -> Dict[str, Any]:
    """Compute calibration curve (expected vs observed)."""
    if not predictions:
        return {"bins": [], "expected_calibration_error": 0.0}

    bin_edges = [i / bins for i in range(bins + 1)]
    bin_data = {i: {"preds": [], "actuals": []} for i in range(bins)}

    for pred, actual in zip(predictions, actuals):
        bin_idx = min(int(pred * bins), bins - 1)
        bin_data[bin_idx]["preds"].append(pred)
        bin_data[bin_idx]["actuals"].append(actual)

    ece = 0.0
    bins_summary = []

    for i in range(bins):
        if bin_data[i]["preds"]:
            avg_pred = sum(bin_data[i]["preds"]) / len(bin_data[i]["preds"])
            avg_actual = sum(bin_data[i]["actuals"]) / len(bin_data[i]["actuals"])
            weight = len(bin_data[i]["preds"]) / len(predictions)

            ece += weight * abs(avg_pred - avg_actual)

            bins_summary.append(
                {
                    "bin": i,
                    "confidence": round(avg_pred, 3),
                    "accuracy": round(avg_actual, 3),
                    "count": len(bin_data[i]["preds"]),
                }
            )

    return {"expected_calibration_error": round(ece, 3), "bins": bins_summary}


def compute_spearman_correlation(predictions: List[float], actuals: List[float]) -> float:
    """Compute Spearman rank correlation coefficient."""
    if len(predictions) < 2:
        return 0.0

    # Compute ranks
    def rank_list(values):
        sorted_vals = sorted(enumerate(values), key=lambda x: x[1])
        ranks = [0] * len(values)
        for rank, (original_idx, _) in enumerate(sorted_vals):
            ranks[original_idx] = rank + 1
        return ranks

    rank_preds = rank_list(predictions)
    rank_actuals = rank_list(actuals)

    # Spearman's rho = 1 - (6 * sum(d^2) / (n * (n^2 - 1)))
    d_squared = sum((rp - ra) ** 2 for rp, ra in zip(rank_preds, rank_actuals))
    n = len(predictions)

    if n < 2:
        return 0.0

    rho = 1 - (6 * d_squared) / (n * (n * n - 1))
    return rho


def compute_risk_metrics(rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Compute risk classification metrics.
    Predictions: use 'score' field
    Actuals: convert 'label' field to numeric score
    """
    predictions = []
    actuals = []

    for row in rows:
        # Prediction: use the score (0-1 normalized)
        score = row.get("score", 50)
        pred_normalized = score / 100.0

        # Actual: convert label to numeric
        label = row.get("label", "medium")
        actual_score = label_to_score(label)

        predictions.append(pred_normalized)
        actuals.append(actual_score)

    # Label-based accuracy (threshold: 0.35 for low, 0.7 for high)
    pred_labels = [score_to_label(p) for p in predictions]
    actual_labels = [score_to_label(a) for a in actuals]

    label_correct = sum(1 for pl, al in zip(pred_labels, actual_labels) if pl == al)
    label_accuracy = label_correct / len(actual_labels) if actual_labels else 0

    # Compute metrics
    auc = compute_auc(predictions, actuals)
    brier = compute_brier_score(predictions, actuals)
    calibration = compute_calibration(predictions, actuals)
    spearman = compute_spearman_correlation(predictions, actuals)

    # Per-class accuracy
    per_class = {}
    for label in ["low", "medium", "high"]:
        indices = [i for i, al in enumerate(actual_labels) if al == label]
        if indices:
            correct = sum(1 for i in indices if pred_labels[i] == label)
            per_class[label] = {
                "accuracy": round(correct / len(indices), 3),
                "support": len(indices),
            }

    return {
        "total_samples": len(actuals),
        "label_accuracy": round(label_accuracy, 3),
        "auc": round(auc, 3),
        "brier_score": round(brier, 3),
        "spearman_correlation": round(spearman, 3),
        "calibration": calibration,
        "per_class_accuracy": per_class,
        "label_counts": {label: sum(1 for al in actual_labels if al == label) for label in ["low", "medium", "high"]},
    }


def main():
    parser = argparse.ArgumentParser(description="Compute risk validation metrics")
    parser.add_argument("--dataset", required=True, help="Path to evaluation_dataset.jsonl")
    parser.add_argument("--report-out", help="Path to save JSON report")
    args = parser.parse_args()

    rows = load_risk_rows(args.dataset)
    print(f"Loaded {len(rows)} risk rows")

    metrics = compute_risk_metrics(rows)

    print("\n=== RISK METRICS ===")
    print(f"Label Accuracy: {metrics['label_accuracy']}")
    print(f"AUC (high-risk detection): {metrics['auc']}")
    print(f"Brier Score: {metrics['brier_score']}")
    print(f"Spearman Correlation: {metrics['spearman_correlation']}")

    print("\nCalibration (Expected vs Observed):")
    for bin_info in metrics["calibration"]["bins"]:
        print(f"  Bin {bin_info['bin']}: confidence={bin_info['confidence']}, accuracy={bin_info['accuracy']}, n={bin_info['count']}")
    print(f"  Expected Calibration Error: {metrics['calibration']['expected_calibration_error']}")

    print("\nPer-Class Accuracy:")
    for label, acc_info in metrics["per_class_accuracy"].items():
        print(f"  {label}: accuracy={acc_info['accuracy']}, support={acc_info['support']}")

    print(f"\nLabel Distribution: {metrics['label_counts']}")

    if args.report_out:
        with open(args.report_out, "w") as f:
            json.dump(metrics, f, indent=2)
        print(f"\n✓ Report saved to {args.report_out}")


if __name__ == "__main__":
    main()
