import argparse
import json
from pathlib import Path


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

    input_text = _extract_text(raw_row, ("input", "prompt", "source", "features"))
    target_text = _extract_text(raw_row, ("target", "summary", "response", "output"))

    if not input_text or not target_text:
        return None

    return {
        "input": input_text,
        "target": target_text,
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