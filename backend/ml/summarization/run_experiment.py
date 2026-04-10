import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def _sha256(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as file_handle:
        for chunk in iter(lambda: file_handle.read(8192), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _run(command, cwd: Path):
    result = subprocess.run(command, cwd=str(cwd), capture_output=True, text=True)
    return result.returncode, result.stdout, result.stderr


def main():
    parser = argparse.ArgumentParser(description="Run tracked summarization training experiment")
    parser.add_argument("--human-quality-score", type=float, default=None)
    args = parser.parse_args()

    base = Path(__file__).resolve().parent
    python_cmd = sys.executable

    dataset_path = base / "summarization_dataset.json"
    reports_dir = base / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    v_code, v_out, v_err = _run([python_cmd, "validate_dataset.py", "--dataset", "summarization_dataset.json"], base)
    if v_code != 0:
        print(v_out)
        print(v_err)
        raise SystemExit("Dataset validation failed. Training aborted.")

    t_code, t_out, t_err = _run([python_cmd, "train_model.py"], base)
    if t_code != 0:
        print(t_out)
        print(t_err)
        raise SystemExit("Training failed")

    e_code, e_out, e_err = _run([python_cmd, "evaluate_model.py"], base)
    if e_code != 0:
        print(e_out)
        print(e_err)
        raise SystemExit("Evaluation failed")

    eval_metrics_path = reports_dir / "latest_eval_metrics.json"
    eval_outputs_path = reports_dir / "latest_eval_outputs.json"
    eval_metrics = json.loads(eval_metrics_path.read_text(encoding="utf-8"))
    eval_outputs = json.loads(eval_outputs_path.read_text(encoding="utf-8"))

    run_id = datetime.utcnow().strftime("run_%Y%m%d_%H%M%S")
    report = {
        "run_id": run_id,
        "dataset": {
            "path": str(dataset_path),
            "sha256": _sha256(dataset_path),
            "last_modified_utc": datetime.utcfromtimestamp(dataset_path.stat().st_mtime).isoformat() + "Z",
        },
        "training_args": {
            "LL_TRAIN_BATCH_SIZE": os.getenv("LL_TRAIN_BATCH_SIZE", "4"),
            "LL_TRAIN_EPOCHS": os.getenv("LL_TRAIN_EPOCHS", "3"),
            "LL_SAVE_STEPS": os.getenv("LL_SAVE_STEPS", "25"),
        },
        "checkpoint_used": "auto_latest_if_available",
        "evaluation": eval_metrics,
        "sample_outputs": eval_outputs[:10],
        "human_quality_score": args.human_quality_score,
        "logs": {
            "validation_stdout": v_out[-4000:],
            "training_stdout": t_out[-4000:],
            "evaluation_stdout": e_out[-4000:],
        },
    }

    output_path = reports_dir / f"{run_id}.json"
    output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Experiment report saved: {output_path}")


if __name__ == "__main__":
    main()