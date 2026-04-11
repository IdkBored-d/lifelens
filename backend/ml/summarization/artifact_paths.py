import os
from pathlib import Path


def default_artifact_root() -> Path:
    configured = os.getenv("LL_ML_ARTIFACTS_DIR")
    if configured:
        return Path(configured).expanduser().resolve()

    local_app_data = os.getenv("LOCALAPPDATA")
    if local_app_data:
        base = Path(local_app_data)
    else:
        base = Path.home() / ".cache"

    return (base / "lifelens" / "ml" / "summarization").resolve()


def training_paths(artifact_root: Path):
    root = artifact_root.resolve()
    return {
        "root": root,
        "results_dir": root / "results",
        "model_dir": root / "summarization_model",
        "reports_dir": root / "reports",
    }