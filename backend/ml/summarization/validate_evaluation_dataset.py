import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


TREND_LABELS = {"declining", "stable", "improving"}
RISK_LABELS = {"low", "medium", "high"}
TREND_SIGNAL_TYPES = {"sleep", "mood", "activity", "overall"}

TREND_REQUIRED = ("dataset_type", "id", "signal_type", "recent_avg", "past_avg", "actual_delta", "actual_rate", "label")
RISK_REQUIRED = ("dataset_type", "id", "risk_bucket", "label")

TREND_NUMERIC_FIELDS = {
    "recent_avg",
    "past_avg",
    "actual_delta",
    "actual_rate",
    "threshold",
}

RISK_NUMERIC_FIELDS = {
    "sleep_avg_3",
    "mood_avg_3",
    "exercise_avg_3",
    "sleep_avg_7",
    "mood_avg_7",
    "exercise_avg_7",
    "sleep_slope_7",
    "mood_slope_7",
    "exercise_slope_7",
    "symptom_avg_7",
    "symptom_slope_7",
    "sleep_variance_7",
    "mood_variance_7",
    "inactive_ratio_7",
    "predicted_risk_score",
    "actual_outcome_severity",
    "annotation_confidence",
}


def _is_blank(value: Any) -> bool:
    return value is None or (isinstance(value, str) and not value.strip())


def _coerce_number(value: Any) -> Optional[float]:
    if _is_blank(value):
        return None
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def _load_json_rows(dataset_path: Path) -> List[Dict[str, Any]]:
    payload = json.loads(dataset_path.read_text(encoding="utf-8"))
    if isinstance(payload, list):
        rows = payload
    elif isinstance(payload, dict):
        rows = payload.get("rows") or payload.get("data") or []
    else:
        rows = []
    return [row for row in rows if isinstance(row, dict)]


def _load_jsonl_rows(dataset_path: Path) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for line in dataset_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        row = json.loads(stripped)
        if isinstance(row, dict):
            rows.append(row)
    return rows


def _load_csv_rows(dataset_path: Path) -> List[Dict[str, Any]]:
    with dataset_path.open("r", encoding="utf-8", newline="") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def _load_rows(dataset_path: Path) -> List[Dict[str, Any]]:
    suffix = dataset_path.suffix.lower()
    if suffix == ".csv":
        return _load_csv_rows(dataset_path)
    if suffix == ".jsonl":
        return _load_jsonl_rows(dataset_path)
    return _load_json_rows(dataset_path)


def _normalize_row(row: Dict[str, Any]) -> Dict[str, Any]:
    normalized = dict(row)
    if "dataset_type" in normalized and not _is_blank(normalized["dataset_type"]):
        normalized["dataset_type"] = str(normalized["dataset_type"]).strip().lower()
    if "label" in normalized and not _is_blank(normalized["label"]):
        normalized["label"] = str(normalized["label"]).strip().lower()
    if "signal_type" in normalized and not _is_blank(normalized["signal_type"]):
        normalized["signal_type"] = str(normalized["signal_type"]).strip().lower()
    if "risk_bucket" in normalized and not _is_blank(normalized["risk_bucket"]):
        normalized["risk_bucket"] = str(normalized["risk_bucket"]).strip().lower()

    for key in TREND_NUMERIC_FIELDS | RISK_NUMERIC_FIELDS:
        if key in normalized:
            normalized[key] = _coerce_number(normalized[key])
    return normalized


def _bucket_from_trend_row(row: Dict[str, Any], delta_tolerance: float) -> str:
    actual_delta = row.get("actual_delta")
    if actual_delta is None:
        return "stable"
    if actual_delta > delta_tolerance:
        return "improving"
    if actual_delta < -delta_tolerance:
        return "declining"
    return "stable"


def _bucket_from_risk_score(score: Optional[float]) -> str:
    if score is None:
        return "unknown"
    if score >= 70:
        return "high"
    if score >= 35:
        return "medium"
    return "low"


def _validate_trend_row(row: Dict[str, Any], index: int, delta_tolerance: float) -> Tuple[List[str], Dict[str, Any]]:
    errors: List[str] = []
    metrics: Dict[str, Any] = {"trend_label": None, "delta_agrees": None, "rate_agrees": None, "abs_delta_error": None}
    prefix = f"row[{index}]"

    for key in TREND_REQUIRED:
        if _is_blank(row.get(key)):
            errors.append(f"{prefix}: missing required field {key}")

    if row.get("dataset_type") != "trend":
        errors.append(f"{prefix}: dataset_type must be trend")

    if row.get("signal_type") not in TREND_SIGNAL_TYPES:
        errors.append(f"{prefix}: signal_type must be one of {sorted(TREND_SIGNAL_TYPES)}")

    label = row.get("label")
    if label not in TREND_LABELS:
        errors.append(f"{prefix}: invalid trend label {label!r}")

    recent_avg = row.get("recent_avg")
    past_avg = row.get("past_avg")
    actual_delta = row.get("actual_delta")
    actual_rate = row.get("actual_rate")
    if recent_avg is not None and past_avg is not None and actual_delta is not None:
        expected_delta = recent_avg - past_avg
        metrics["abs_delta_error"] = round(abs(expected_delta - actual_delta), 6)
        if abs(expected_delta - actual_delta) > max(delta_tolerance, 1e-6):
            errors.append(f"{prefix}: actual_delta does not match recent_avg - past_avg within tolerance")

    if row.get("threshold") is not None and row["threshold"] < 0:
        errors.append(f"{prefix}: threshold must be non-negative when present")

    if label in TREND_LABELS:
        metrics["trend_label"] = _bucket_from_trend_row(row, delta_tolerance)
        metrics["delta_agrees"] = label == metrics["trend_label"]
        if actual_rate is not None:
            rate_label = _bucket_from_trend_row({"actual_delta": actual_rate}, delta_tolerance)
            metrics["rate_agrees"] = label == rate_label

    return errors, metrics


def _validate_risk_row(row: Dict[str, Any], index: int) -> Tuple[List[str], Dict[str, Any]]:
    errors: List[str] = []
    metrics: Dict[str, Any] = {"bucket_from_score": None, "bucket_agrees": None}
    prefix = f"row[{index}]"

    for key in RISK_REQUIRED:
        if _is_blank(row.get(key)):
            errors.append(f"{prefix}: missing required field {key}")

    if row.get("dataset_type") != "risk":
        errors.append(f"{prefix}: dataset_type must be risk")

    label = row.get("label")
    if label not in RISK_LABELS:
        errors.append(f"{prefix}: invalid risk label {label!r}")

    risk_bucket = row.get("risk_bucket")
    if risk_bucket not in RISK_LABELS:
        errors.append(f"{prefix}: invalid risk_bucket {risk_bucket!r}")

    score = row.get("predicted_risk_score")
    if score is None:
        score = row.get("score")
    if score is not None:
        metrics["bucket_from_score"] = _bucket_from_risk_score(score)
        metrics["bucket_agrees"] = metrics["bucket_from_score"] == risk_bucket

    if row.get("annotation_confidence") is not None and not (0.0 <= row["annotation_confidence"] <= 1.0):
        errors.append(f"{prefix}: annotation_confidence must be between 0 and 1")

    if row.get("inactive_ratio_7") is not None and not (0.0 <= row["inactive_ratio_7"] <= 1.0):
        errors.append(f"{prefix}: inactive_ratio_7 must be between 0 and 1")

    return errors, metrics


def _count_required_presence(row: Dict[str, Any], required: Iterable[str]) -> int:
    return sum(1 for key in required if not _is_blank(row.get(key)))


def validate_evaluation_dataset(dataset_path: Path, delta_tolerance: float) -> Tuple[int, Dict[str, Any]]:
    if not dataset_path.exists():
        return 1, {"error": f"dataset not found: {dataset_path}"}

    rows = _load_rows(dataset_path)
    if not rows:
        return 1, {"error": "dataset must contain at least one row"}

    errors: List[str] = []
    warnings: List[str] = []
    duplicate_counter = Counter()
    type_counter = Counter()
    trend_label_counter = Counter()
    risk_label_counter = Counter()
    risk_bucket_counter = Counter()
    trend_delta_agreements = 0
    trend_rate_agreements = 0
    trend_rows = 0
    risk_bucket_agreements = 0
    risk_rows = 0
    required_presence_counts = Counter()

    for index, raw_row in enumerate(rows):
        if not isinstance(raw_row, dict):
            errors.append(f"row[{index}]: must be an object")
            continue

        row = _normalize_row(raw_row)
        dataset_type = row.get("dataset_type")
        type_counter[dataset_type or "unknown"] += 1

        dedupe_key = json.dumps(row, sort_keys=True, ensure_ascii=True, default=str).lower()
        duplicate_counter[dedupe_key] += 1

        if dataset_type == "trend":
            required_presence_counts["trend"] += _count_required_presence(row, TREND_REQUIRED)
            row_errors, row_metrics = _validate_trend_row(row, index, delta_tolerance)
            errors.extend(row_errors)
            if row.get("label") in TREND_LABELS:
                trend_rows += 1
                trend_label_counter[row["label"]] += 1
                if row_metrics.get("delta_agrees"):
                    trend_delta_agreements += 1
                if row_metrics.get("rate_agrees"):
                    trend_rate_agreements += 1
        elif dataset_type == "risk":
            required_presence_counts["risk"] += _count_required_presence(row, RISK_REQUIRED)
            row_errors, row_metrics = _validate_risk_row(row, index)
            errors.extend(row_errors)
            if row.get("label") in RISK_LABELS:
                risk_rows += 1
                risk_label_counter[row["label"]] += 1
            if row.get("risk_bucket") in RISK_LABELS:
                risk_bucket_counter[row["risk_bucket"]] += 1
            if row_metrics.get("bucket_agrees"):
                risk_bucket_agreements += 1
        else:
            errors.append(f"row[{index}]: dataset_type must be trend or risk")

    duplicate_rows = sum(count - 1 for count in duplicate_counter.values() if count > 1)
    if duplicate_rows:
        warnings.append(f"duplicate rows detected: {duplicate_rows}")

    if trend_rows == 0 and risk_rows == 0:
        warnings.append("no valid trend or risk rows were detected")

    metrics = {
        "total_rows": len(rows),
        "type_counts": dict(type_counter),
        "trend": {
            "rows": trend_rows,
            "label_counts": dict(trend_label_counter),
            "delta_agreement_rate": round(trend_delta_agreements / trend_rows, 4) if trend_rows else 0.0,
            "rate_agreement_rate": round(trend_rate_agreements / trend_rows, 4) if trend_rows else 0.0,
        },
        "risk": {
            "rows": risk_rows,
            "label_counts": dict(risk_label_counter),
            "bucket_counts": dict(risk_bucket_counter),
            "score_bucket_agreement_rate": round(risk_bucket_agreements / risk_rows, 4) if risk_rows else 0.0,
        },
        "duplicate_rows": duplicate_rows,
        "warnings": warnings,
        "errors": errors[:100],
    }

    exit_code = 1 if errors else 0
    return exit_code, metrics


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate LifeLens trend/risk evaluation datasets")
    parser.add_argument("--dataset", required=True, help="Path to a JSON, JSONL, or CSV dataset")
    parser.add_argument("--delta-tolerance", type=float, default=0.05, help="Tolerance for trend delta agreement")
    parser.add_argument("--report-out", default=None, help="Optional path for a JSON report")
    args = parser.parse_args()

    dataset_path = Path(args.dataset).expanduser().resolve()
    exit_code, metrics = validate_evaluation_dataset(dataset_path, args.delta_tolerance)

    print(json.dumps(metrics, indent=2))
    if args.report_out:
        report_path = Path(args.report_out).expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()