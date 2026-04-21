import argparse
import csv
import json
import random
from pathlib import Path

try:
    import pandas as pd  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    pd = None


def _normalize(text: str) -> str:
    return " ".join(str(text).strip().split())


def _iter_json(path: Path):
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, list):
        for row in payload:
            yield row
        return
    if isinstance(payload, dict):
        for key in ("rows", "data", "items", "examples"):
            value = payload.get(key)
            if isinstance(value, list):
                for row in value:
                    yield row
                return


def _iter_jsonl(path: Path):
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue


def _iter_csv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            yield row


def _iter_parquet(path: Path):
    if pd is None:
        return
    try:
        frame = pd.read_parquet(path)
    except Exception:
        return
    for row in frame.to_dict(orient="records"):
        yield row


def _iter_records(folder: Path):
    if not folder.exists():
        return
    for path in sorted(folder.glob("*.json")):
        try:
            yield from _iter_json(path)
        except Exception:
            continue
    for path in sorted(folder.glob("*.jsonl")):
        try:
            yield from _iter_jsonl(path)
        except Exception:
            continue
    for path in sorted(folder.glob("*.csv")):
        try:
            yield from _iter_csv(path)
        except Exception:
            continue
    for path in sorted(folder.glob("*.parquet")):
        try:
            yield from _iter_parquet(path)
        except Exception:
            continue


def _find_text(row: dict, keys: tuple[str, ...]) -> str:
    for key in keys:
        value = row.get(key)
        if value is None:
            continue
        cleaned = _normalize(value)
        if cleaned:
            return cleaned
    return ""


def _bucket_from_text(text: str) -> str:
    text_l = text.lower()
    high_risk_terms = ("panic", "unsafe", "hopeless", "suicid", "cannot cope")
    low_sleep_terms = ("insomnia", "sleep", "awake", "woke", "restless", "night")
    low_mood_terms = ("burnt out", "burned out", "brain fog", "empty", "numb", "down")
    declining_terms = ("worse", "declin", "spiral", "overwhelmed", "exhausted")

    if any(t in text_l for t in high_risk_terms):
        return "high_risk"
    if any(t in text_l for t in low_sleep_terms):
        return "low_sleep"
    if any(t in text_l for t in low_mood_terms):
        return "low_mood"
    if any(t in text_l for t in declining_terms):
        return "declining"
    return "stable"


def _bucket_target(bucket: str) -> str:
    templates = {
        "declining": [
            "Recent signals are declining, so keep today low-pressure and focus on one stabilizing step.",
            "Your trend looks declining this week, with rising strain and reduced resilience.",
        ],
        "low_sleep": [
            "Low sleep is the main concern right now, so prioritize rest structure and recovery habits.",
            "Sleep remains below target, so start with one practical sleep-support action today.",
        ],
        "low_mood": [
            "Low mood is the dominant concern in this window, so use gentle routines and supportive check-ins.",
            "Mood appears low right now, so keep the next step small and grounding.",
        ],
        "high_risk": [
            "High risk signals are present, so use safety-first pacing and seek support if symptoms escalate.",
            "Current pattern suggests high risk, and close support is recommended in the near term.",
        ],
        "improving": [
            "Your trend is improving, with better short-term resilience and recovery momentum.",
            "Signals are improving overall, so maintain a consistent and sustainable routine.",
        ],
        "stable": [
            "Signals look stable right now, so continue a steady routine with one practical check-in step.",
            "Current pattern appears stable, with no major short-term disruption.",
        ],
    }
    choices = templates.get(bucket, templates["stable"])
    return random.choice(choices)


def _sample_features(bucket: str) -> dict:
    if bucket == "declining":
        return {
            "sleep_avg_3": random.uniform(4.3, 6.1),
            "mood_avg_3": random.uniform(1.1, 3.0),
            "sleep_slope": random.uniform(-0.62, -0.16),
            "mood_slope": random.uniform(-0.58, -0.12),
            "risk": random.uniform(58.0, 90.0),
            "trend": random.uniform(-0.56, -0.12),
        }
    if bucket == "low_sleep":
        return {
            "sleep_avg_3": random.uniform(2.9, 5.0),
            "mood_avg_3": random.uniform(2.2, 4.2),
            "sleep_slope": random.uniform(-0.24, 0.06),
            "mood_slope": random.uniform(-0.16, 0.16),
            "risk": random.uniform(46.0, 84.0),
            "trend": random.uniform(-0.28, 0.06),
        }
    if bucket == "low_mood":
        return {
            "sleep_avg_3": random.uniform(5.2, 7.8),
            "mood_avg_3": random.uniform(0.7, 2.0),
            "sleep_slope": random.uniform(-0.12, 0.14),
            "mood_slope": random.uniform(-0.30, 0.04),
            "risk": random.uniform(44.0, 86.0),
            "trend": random.uniform(-0.28, 0.04),
        }
    if bucket == "high_risk":
        return {
            "sleep_avg_3": random.uniform(3.1, 5.7),
            "mood_avg_3": random.uniform(0.8, 2.4),
            "sleep_slope": random.uniform(-0.66, -0.10),
            "mood_slope": random.uniform(-0.62, -0.10),
            "risk": random.uniform(72.0, 100.0),
            "trend": random.uniform(-0.64, -0.10),
        }
    return {
        "sleep_avg_3": random.uniform(4.8, 7.2),
        "mood_avg_3": random.uniform(1.8, 4.2),
        "sleep_slope": random.uniform(-0.32, 0.32),
        "mood_slope": random.uniform(-0.32, 0.32),
        "risk": random.uniform(34.0, 78.0),
        "trend": random.uniform(-0.32, 0.32),
    }


def _feature_line(features: dict, text: str) -> str:
    return (
        f"sleep_avg_3={features['sleep_avg_3']:.2f} "
        f"mood_avg_3={features['mood_avg_3']:.2f} "
        f"sleep_slope={features['sleep_slope']:.3f} "
        f"mood_slope={features['mood_slope']:.3f} "
        f"risk={features['risk']:.2f} "
        f"trend={features['trend']:.3f} "
        f"user_text={text[:220]}"
    )


def _safe_float(row: dict, keys: tuple[str, ...], default: float) -> float:
    for key in keys:
        value = row.get(key)
        if value is None:
            continue
        try:
            return float(str(value).strip())
        except Exception:
            continue
    return default


def _bucket_from_metrics(sleep_hours: float, stress_level: float) -> str:
    if stress_level >= 8 or sleep_hours < 5.0:
        return "high_risk"
    if sleep_hours < 6.0:
        return "low_sleep"
    if stress_level >= 6.5:
        return "declining"
    if sleep_hours >= 7.0 and stress_level <= 4.0:
        return "improving"
    return "stable"


def _build_reddit_rows(raw_dir: Path, max_rows: int) -> list[dict]:
    rows = []
    for record in _iter_records(raw_dir):
        if not isinstance(record, dict):
            continue
        text = _find_text(record, ("text", "selftext", "post", "post_text", "content", "body"))
        title = _find_text(record, ("title",))
        if title and text:
            text = f"{title}. {text}"
        elif title and not text:
            text = title
        if not text:
            continue

        bucket = _bucket_from_text(text)
        features = _sample_features(bucket)
        rows.append(
            {
                "input": _feature_line(features, text),
                "target": _bucket_target(bucket),
                "source": "reddit_human_voice",
            }
        )
        if len(rows) >= max_rows:
            break
    return rows


def _build_counsel_rows(raw_dir: Path, max_rows: int) -> list[dict]:
    rows = []
    for record in _iter_records(raw_dir):
        if not isinstance(record, dict):
            continue
        question = _find_text(record, ("questionText", "question", "query", "text"))
        answer = _find_text(record, ("answerText", "answer", "response", "target"))
        if not question or not answer:
            continue

        bucket = _bucket_from_text(question)
        features = _sample_features(bucket)
        empathetic_seed = answer.split(".")[0]
        empathetic_seed = _normalize(empathetic_seed)[:120]
        target = _bucket_target(bucket)
        if empathetic_seed:
            target = f"{target} {empathetic_seed}."

        rows.append(
            {
                "input": _feature_line(features, question),
                "target": target,
                "source": "counselchat_app_voice",
            }
        )
        if len(rows) >= max_rows:
            break
    return rows


def _build_sleep_rows(raw_dir: Path, max_rows: int) -> list[dict]:
    rows = []
    for record in _iter_records(raw_dir):
        if not isinstance(record, dict):
            continue

        sleep_hours = _safe_float(record, ("Sleep Duration", "sleep_duration", "sleep_hours", "sleep"), 6.5)
        stress = _safe_float(record, ("Stress Level", "stress_level", "stress"), 5.0)
        quality = _safe_float(record, ("Quality of Sleep", "sleep_quality", "quality"), 6.0)

        bucket = _bucket_from_metrics(sleep_hours, stress)

        sleep_slope = random.uniform(-0.4, -0.1) if bucket in {"declining", "high_risk", "low_sleep"} else random.uniform(-0.05, 0.30)
        mood_slope = random.uniform(-0.35, -0.08) if bucket in {"declining", "high_risk"} else random.uniform(-0.05, 0.28)
        risk = max(0.0, min(100.0, stress * 10.0 + (7.0 - sleep_hours) * 8.0))
        trend = (sleep_slope + mood_slope) / 2.0

        input_line = (
            f"sleep_avg_3={sleep_hours:.2f} "
            f"mood_avg_3={(quality / 2.0):.2f} "
            f"sleep_slope={sleep_slope:.3f} "
            f"mood_slope={mood_slope:.3f} "
            f"risk={risk:.2f} "
            f"trend={trend:.3f}"
        )

        rows.append(
            {
                "input": input_line,
                "target": _bucket_target(bucket),
                "source": "sleep_health_grounding",
                "bucket": bucket,
            }
        )
        if len(rows) >= max_rows:
            break
    return rows


def _write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["input", "target", "source"])
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "input": row["input"],
                    "target": row["target"],
                    "source": row.get("source", "external"),
                }
            )


def _write_json(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare external wellness datasets into ingestion-ready files")
    parser.add_argument("--raw-reddit-dir", default="incoming/reddit_raw")
    parser.add_argument("--raw-counsel-dir", default="incoming/counselchat_raw")
    parser.add_argument("--raw-sleep-dir", default="incoming/sleep_health_raw")
    parser.add_argument("--incoming-dir", default="incoming")
    parser.add_argument("--bootstrap-dir", default="incoming_bootstrap")
    parser.add_argument("--max-reddit", type=int, default=1500)
    parser.add_argument("--max-counsel", type=int, default=1500)
    parser.add_argument("--max-sleep", type=int, default=4000)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    random.seed(args.seed)
    base = Path(__file__).resolve().parent

    reddit_rows = _build_reddit_rows(base / args.raw_reddit_dir, max_rows=max(0, args.max_reddit))
    counsel_rows = _build_counsel_rows(base / args.raw_counsel_dir, max_rows=max(0, args.max_counsel))
    sleep_rows = _build_sleep_rows(base / args.raw_sleep_dir, max_rows=max(0, args.max_sleep))

    reddit_out = base / args.incoming_dir / "reddit_samples.csv"
    counsel_out = base / args.incoming_dir / "counsel_chat.csv"
    sleep_out = base / args.bootstrap_dir / "synthetic_math.json"

    _write_csv(reddit_out, reddit_rows)
    _write_csv(counsel_out, counsel_rows)
    _write_json(sleep_out, sleep_rows)

    manifest = {
        "reddit_rows": len(reddit_rows),
        "counsel_rows": len(counsel_rows),
        "sleep_rows": len(sleep_rows),
        "outputs": {
            "reddit_samples": str(reddit_out),
            "counsel_chat": str(counsel_out),
            "synthetic_math": str(sleep_out),
        },
    }
    manifest_path = base / args.incoming_dir / "external_prepare_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print("Prepared external dataset files")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
