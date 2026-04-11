import argparse
import json
from pathlib import Path


def _normalize_row(raw_row):
    if not isinstance(raw_row, dict):
        return None
    input_text = str(raw_row.get("input", "")).strip()
    target_text = str(raw_row.get("target", "")).strip()
    if not input_text or not target_text:
        return None
    return {
        "input": " ".join(input_text.split()),
        "target": " ".join(target_text.split()),
    }


def merge_datasets(incoming_dir: Path, output_file: Path):
    merged = []
    seen = set()

    if output_file.exists():
        try:
            existing_payload = json.loads(output_file.read_text(encoding="utf-8"))
            if isinstance(existing_payload, list):
                for row in existing_payload:
                    normalized = _normalize_row(row)
                    if not normalized:
                        continue
                    key = (normalized["input"].lower(), normalized["target"].lower())
                    if key in seen:
                        continue
                    seen.add(key)
                    merged.append(normalized)
        except Exception:
            pass

    for file_path in sorted(incoming_dir.glob("*.json")):
        try:
            payload = json.loads(file_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(payload, list):
            continue

        for row in payload:
            normalized = _normalize_row(row)
            if not normalized:
                continue
            key = (normalized["input"].lower(), normalized["target"].lower())
            if key in seen:
                continue
            seen.add(key)
            merged.append(normalized)

    output_file.write_text(json.dumps(merged, indent=2), encoding="utf-8")
    print(f"Merged rows: {len(merged)}")
    print(f"Output: {output_file}")


def main():
    parser = argparse.ArgumentParser(description="Merge teammate summarization datasets")
    parser.add_argument("--incoming-dir", default="incoming")
    parser.add_argument("--output", default="summarization_dataset.json")
    args = parser.parse_args()

    base = Path(__file__).resolve().parent
    incoming_dir = base / args.incoming_dir
    output_file = base / args.output
    incoming_dir.mkdir(parents=True, exist_ok=True)

    merge_datasets(incoming_dir=incoming_dir, output_file=output_file)


if __name__ == "__main__":
    main()