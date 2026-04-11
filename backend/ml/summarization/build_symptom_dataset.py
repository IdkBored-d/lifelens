import argparse
import ast
import json
from pathlib import Path


def _extract_disease_dataset(py_file: Path):
    source = py_file.read_text(encoding="utf-8")
    module = ast.parse(source)

    for node in module.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == "DISEASE_DATASET":
                    return ast.literal_eval(node.value)

    raise ValueError("Could not find DISEASE_DATASET assignment in source file")


def _first_sentence(text: str) -> str:
    cleaned = " ".join(str(text).strip().split())
    if not cleaned:
        return ""
    parts = cleaned.split(".")
    first = parts[0].strip()
    return first + ("." if first and not first.endswith(".") else "")


def _build_row(item: dict, max_symptoms: int):
    condition = str(item.get("condition", "Unknown condition")).strip()
    symptoms = item.get("symptoms") or []
    symptoms = [str(s).strip() for s in symptoms if str(s).strip()][:max_symptoms]
    symptom_text = ", ".join(symptoms) if symptoms else "unspecified symptoms"
    severity = str(item.get("severity", "unknown")).strip()
    description = _first_sentence(item.get("description", ""))
    treatment = str(item.get("treatment", "")).strip()

    input_text = f"condition: {condition}; severity: {severity}; symptoms: {symptom_text}"

    if treatment:
        target = (
            f"{condition} is {severity} and often presents with {symptom_text}. "
            f"{description} Common treatments include {treatment}."
        )
    else:
        target = f"{condition} is {severity} and often presents with {symptom_text}. {description}"

    target = " ".join(target.split())
    return {"input": input_text, "target": target}


def convert(source_py: Path, output_json: Path, max_symptoms: int):
    dataset = _extract_disease_dataset(source_py)
    if not isinstance(dataset, list) or not dataset:
        raise ValueError("DISEASE_DATASET must be a non-empty list")

    rows = []
    seen = set()
    for item in dataset:
        row = _build_row(item, max_symptoms=max_symptoms)
        dedupe_key = (row["input"].lower(), row["target"].lower())
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        rows.append(row)

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(rows, indent=2), encoding="utf-8")
    return len(rows)


def main():
    parser = argparse.ArgumentParser(description="Build summarization dataset from DISEASE_DATASET source")
    parser.add_argument("--source", required=True, help="Path to Python file containing DISEASE_DATASET")
    parser.add_argument(
        "--output",
        default="summarization_dataset.json",
        help="Output dataset path (JSON list of {input,target})",
    )
    parser.add_argument("--max-symptoms", type=int, default=6)
    args = parser.parse_args()

    source_path = Path(args.source).expanduser().resolve()
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = (Path(__file__).resolve().parent / output_path).resolve()

    row_count = convert(source_path, output_path, max_symptoms=args.max_symptoms)
    print(f"Wrote {row_count} rows to {output_path}")


if __name__ == "__main__":
    main()
