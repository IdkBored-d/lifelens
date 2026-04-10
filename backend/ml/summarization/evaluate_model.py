import json
import re
import sys
from pathlib import Path


def _is_malformed(summary: str) -> bool:
    lowered = summary.lower().strip()
    if _is_fallback(summary):
        return False
    if len(lowered) < 10:
        return True
    if len(lowered) > 280:
        return True
    if lowered.count("=") >= 2:
        return True
    if any(token in lowered for token in ("sleep_avg_3", "mood_avg_3", "sleep_slope", "mood_slope", "risk=", "trend=")):
        return True
    if re.search(r"\b(\w+)(\s+\1){2,}\b", lowered):
        return True
    return False


def _is_fallback(summary: str) -> bool:
    return summary.startswith("Deterministic analysis:")


def _bucket_match(summary: str, expected_bucket: str) -> bool:
    lowered = summary.lower()
    if expected_bucket == "declining":
        return "declin" in lowered or "worsen" in lowered
    if expected_bucket == "improving":
        return "improv" in lowered or "recover" in lowered
    if expected_bucket == "stable":
        return "stable" in lowered or "steady" in lowered
    if expected_bucket == "low_sleep":
        return "sleep" in lowered
    if expected_bucket == "low_mood":
        return "mood" in lowered
    if expected_bucket == "high_risk":
        return "risk" in lowered or "high" in lowered
    return True


def evaluate(gold_path: Path):
    backend_root = Path(__file__).resolve().parents[2]
    if str(backend_root) not in sys.path:
        sys.path.insert(0, str(backend_root))

    from services.intelligence import analyze_logs

    rows = json.loads(gold_path.read_text(encoding="utf-8"))
    outputs = []
    fallback_count = 0
    malformed_count = 0
    expected_hits = 0

    for row in rows:
        result = analyze_logs(row["logs"])
        message = result.message
        fallback = _is_fallback(message)
        malformed = _is_malformed(message)
        bucket_hit = _bucket_match(message, row.get("expected_bucket", "other"))

        fallback_count += int(fallback)
        malformed_count += int(malformed)
        expected_hits += int(bucket_hit)

        outputs.append(
            {
                "id": row.get("id", "unknown"),
                "expected_bucket": row.get("expected_bucket", "other"),
                "message": message,
                "is_fallback": fallback,
                "is_malformed": malformed,
                "bucket_match": bucket_hit,
            }
        )

    total = len(rows)
    metrics = {
        "total_cases": total,
        "fallback_rate": round(fallback_count / total, 4) if total else 0.0,
        "malformed_output_rate": round(malformed_count / total, 4) if total else 0.0,
        "bucket_match_rate": round(expected_hits / total, 4) if total else 0.0,
        "sample_outputs": outputs[:10],
    }
    return metrics, outputs


def main():
    base = Path(__file__).resolve().parent
    gold_path = base / "gold_eval_set.json"
    metrics, outputs = evaluate(gold_path)

    reports_dir = base / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    (reports_dir / "latest_eval_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    (reports_dir / "latest_eval_outputs.json").write_text(json.dumps(outputs, indent=2), encoding="utf-8")

    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()