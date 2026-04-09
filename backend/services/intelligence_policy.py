"""Policy loader and validation for the intelligence decision engine."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any, Dict
import json


REQUIRED_TOP_LEVEL_KEYS = {
    "version",
    "thresholds",
    "weights",
    "action_policies",
    "model_coefficients",
}


def _default_policy_path() -> Path:
    return Path(__file__).resolve().parent.parent / "config" / "intelligence_policy.yaml"


def _validate_policy(policy: Dict[str, Any]) -> None:
    missing = REQUIRED_TOP_LEVEL_KEYS.difference(policy.keys())
    if missing:
        raise ValueError(f"Intelligence policy missing keys: {sorted(missing)}")

    thresholds = policy.get("thresholds", {})
    for key in [
        "low_sleep_hours",
        "low_mood_score",
        "high_risk_score",
        "medium_risk_score",
        "low_confidence_score",
        "high_confidence_score",
    ]:
        if key not in thresholds:
            raise ValueError(f"Intelligence policy thresholds missing '{key}'")

    if thresholds["high_risk_score"] <= thresholds["medium_risk_score"]:
        raise ValueError("high_risk_score must be greater than medium_risk_score")

    if not (0 <= thresholds["low_confidence_score"] <= 1):
        raise ValueError("low_confidence_score must be in [0, 1]")
    if not (0 <= thresholds["high_confidence_score"] <= 1):
        raise ValueError("high_confidence_score must be in [0, 1]")


@lru_cache()
def get_intelligence_policy() -> Dict[str, Any]:
    """Load and validate policy config from versioned yaml file.

    The file is YAML-compatible JSON to avoid an additional parser dependency.
    """
    policy_path = _default_policy_path()
    raw = policy_path.read_text(encoding="utf-8")
    policy: Dict[str, Any] = json.loads(raw)
    _validate_policy(policy)
    return policy
