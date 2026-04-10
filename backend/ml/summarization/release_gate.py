import argparse
import json
from pathlib import Path


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description="Release gate for summarization model promotion")
    parser.add_argument("--candidate", default="reports/latest_eval_metrics.json")
    parser.add_argument("--baseline", default="reports/baseline_eval_metrics.json")
    parser.add_argument("--human-quality-score", type=float, required=True)
    parser.add_argument("--min-human-quality-score", type=float, default=3.5)
    args = parser.parse_args()

    base = Path(__file__).resolve().parent
    candidate_path = base / args.candidate
    baseline_path = base / args.baseline

    if not candidate_path.exists():
        raise SystemExit(f"Candidate metrics file not found: {candidate_path}")

    candidate = load_json(candidate_path)
    baseline = load_json(baseline_path) if baseline_path.exists() else {
        "fallback_rate": 1.0,
        "malformed_output_rate": 1.0,
        "bucket_match_rate": 0.0,
    }

    checks = []
    checks.append((candidate.get("fallback_rate", 1.0) <= baseline.get("fallback_rate", 1.0), "fallback_rate did not improve"))
    checks.append((candidate.get("malformed_output_rate", 1.0) <= baseline.get("malformed_output_rate", 1.0), "malformed_output_rate did not improve"))
    checks.append((candidate.get("bucket_match_rate", 0.0) >= baseline.get("bucket_match_rate", 0.0), "bucket_match_rate regressed"))
    checks.append((args.human_quality_score >= args.min_human_quality_score, "human quality score below threshold"))

    failed = [reason for ok, reason in checks if not ok]
    if failed:
        print("Release gate FAILED")
        for reason in failed:
            print(f"- {reason}")
        raise SystemExit(1)

    print("Release gate PASSED")
    print(json.dumps({
        "candidate": candidate,
        "baseline": baseline,
        "human_quality_score": args.human_quality_score,
    }, indent=2))


if __name__ == "__main__":
    main()