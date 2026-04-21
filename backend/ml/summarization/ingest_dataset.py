import argparse
import csv
import json
import re
from pathlib import Path


INPUT_KEYS = (
    "input",
    "prompt",
    "source",
    "features",
    "text",
    "post",
    "post_text",
    "content",
    "question",
    "questionText",
)

TARGET_KEYS = (
    "target",
    "summary",
    "response",
    "output",
    "answer",
    "answerText",
)

ANCHOR_TAG_PATTERN = re.compile(r"^((?:\[[A-Z_]+\])+)(\s+)")


def _parse_feature_tokens(input_text: str) -> dict[str, float]:
    values = {}
    for token in input_text.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        try:
            values[key] = float(value)
        except ValueError:
            continue
    return values


def _derive_anchor_tags(input_text: str) -> list[str]:
    parsed = _parse_feature_tokens(input_text)
    tags = []

    sleep_avg = parsed.get("sleep_avg_3")
    mood_avg = parsed.get("mood_avg_3")
    sleep_slope = parsed.get("sleep_slope")
    mood_slope = parsed.get("mood_slope")
    risk = parsed.get("risk")
    trend = parsed.get("trend")

    if sleep_avg is not None and sleep_avg < 6.0:
        tags.append("LOW_SLEEP")
    if mood_avg is not None and mood_avg < 2.4:
        tags.append("LOW_MOOD")
    if sleep_slope is not None and sleep_slope < -0.08:
        tags.append("DECLINING_SLEEP")
    if mood_slope is not None and mood_slope < -0.08:
        tags.append("DECLINING_MOOD")
    if trend is not None and trend < -0.10:
        tags.append("DECLINING_TREND")
    if trend is not None and trend > 0.10:
        tags.append("IMPROVING_TREND")
    if risk is not None and risk >= 70.0:
        tags.append("HIGH_RISK")

    # Keep order stable while deduplicating.
    seen = set()
    deduped = []
    for tag in tags:
        if tag in seen:
            continue
        seen.add(tag)
        deduped.append(tag)
    return deduped


def _existing_anchor_tags(input_text: str) -> set[str]:
    match = ANCHOR_TAG_PATTERN.match(input_text)
    if not match:
        return set()
    return {segment.strip("[]") for segment in re.findall(r"\[[A-Z_]+\]", match.group(1))}


def _prepend_anchor_tags(input_text: str) -> str:
    tags = _derive_anchor_tags(input_text)
    if not tags:
        return input_text

    present = _existing_anchor_tags(input_text)
    missing = [tag for tag in tags if tag not in present]
    if not missing:
        return input_text

    tag_prefix = "".join(f"[{tag}]" for tag in missing)
    return f"{tag_prefix} {input_text}"


def _infer_bucket_from_target(target_text: str) -> str:
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


def _normalize_whitespace(text: str) -> str:
    return " ".join(str(text).strip().split())


def _extract_text(row: dict, keys: tuple[str, ...]) -> str:
    for key in keys:
        value = row.get(key)
        if value is None:
            continue
        normalized = _normalize_whitespace(str(value))
        if normalized:
            return normalized
    return ""


def _normalize_row(raw_row: object) -> dict | None:
    if not isinstance(raw_row, dict):
        return None

    input_text = _extract_text(raw_row, INPUT_KEYS)
    target_text = _extract_text(raw_row, TARGET_KEYS)

    if not input_text or not target_text:
        return None

    source_text = _normalize_whitespace(str(raw_row.get("source", "")))
    bucket_text = _normalize_whitespace(str(raw_row.get("bucket", "")))

    if not source_text:
        source_text = "unknown"
    if not bucket_text:
        bucket_text = _infer_bucket_from_target(target_text)

    return {
        "input": _prepend_anchor_tags(input_text),
        "target": target_text,
        "source": source_text,
        "bucket": bucket_text,
    }


def _iter_rows_from_json(path: Path):
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


def _iter_rows_from_jsonl(path: Path):
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        try:
            yield json.loads(stripped)
        except json.JSONDecodeError:
            continue


def _iter_rows_from_csv(path: Path):
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                yield row
    except Exception:
        return


def _collect_rows(incoming_dir: Path) -> tuple[list[dict], dict]:
    rows = []
    stats = {
        "files_scanned": 0,
        "rows_seen": 0,
        "rows_valid": 0,
        "rows_skipped": 0,
    }

    for path in sorted(incoming_dir.glob("*.json")):
        stats["files_scanned"] += 1
        try:
            iterator = _iter_rows_from_json(path)
            for raw_row in iterator:
                stats["rows_seen"] += 1
                normalized = _normalize_row(raw_row)
                if normalized is None:
                    stats["rows_skipped"] += 1
                    continue
                rows.append(normalized)
                stats["rows_valid"] += 1
        except Exception:
            continue

    for path in sorted(incoming_dir.glob("*.jsonl")):
        stats["files_scanned"] += 1
        try:
            for raw_row in _iter_rows_from_jsonl(path):
                stats["rows_seen"] += 1
                normalized = _normalize_row(raw_row)
                if normalized is None:
                    stats["rows_skipped"] += 1
                    continue
                rows.append(normalized)
                stats["rows_valid"] += 1
        except Exception:
            continue

    for path in sorted(incoming_dir.glob("*.csv")):
        stats["files_scanned"] += 1
        try:
            for raw_row in _iter_rows_from_csv(path):
                stats["rows_seen"] += 1
                normalized = _normalize_row(raw_row)
                if normalized is None:
                    stats["rows_skipped"] += 1
                    continue
                rows.append(normalized)
                stats["rows_valid"] += 1
        except Exception:
            continue

    return rows, stats


def _load_existing(output_path: Path) -> list[dict]:
    if not output_path.exists():
        return []

    try:
        payload = json.loads(output_path.read_text(encoding="utf-8"))
        if not isinstance(payload, list):
            return []
    except Exception:
        return []

    existing = []
    for row in payload:
        normalized = _normalize_row(row)
        if normalized is not None:
            existing.append(normalized)
    return existing


def ingest(incoming_dir: Path, output_path: Path, append_existing: bool):
    merged = []
    seen = set()

    if append_existing:
        for row in _load_existing(output_path):
            key = (row["input"].lower(), row["target"].lower())
            if key in seen:
                continue
            seen.add(key)
            merged.append(row)

    incoming_rows, stats = _collect_rows(incoming_dir)
    for row in incoming_rows:
        key = (row["input"].lower(), row["target"].lower())
        if key in seen:
            continue
        seen.add(key)
        merged.append(row)

    output_path.write_text(json.dumps(merged, indent=2), encoding="utf-8")

    print(f"Incoming dir: {incoming_dir}")
    print(f"Output dataset: {output_path}")
    print(f"Files scanned: {stats['files_scanned']}")
    print(f"Rows seen: {stats['rows_seen']}")
    print(f"Rows valid: {stats['rows_valid']}")
    print(f"Rows skipped: {stats['rows_skipped']}")
    print(f"Merged rows written: {len(merged)}")


def main():
    parser = argparse.ArgumentParser(description="Ingest incoming summarization rows into a unified dataset")
    parser.add_argument("--incoming-dir", default="incoming")
    parser.add_argument("--output", default="summarization_dataset.json")
    parser.add_argument(
        "--no-append-existing",
        action="store_true",
        help="Do not include existing output dataset rows before ingesting incoming files.",
    )
    args = parser.parse_args()

    base = Path(__file__).resolve().parent
    incoming_dir = base / args.incoming_dir
    output_path = base / args.output
    incoming_dir.mkdir(parents=True, exist_ok=True)

    ingest(
        incoming_dir=incoming_dir,
        output_path=output_path,
        append_existing=not args.no_append_existing,
    )


if __name__ == "__main__":
    main()