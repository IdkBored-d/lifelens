"""Lightweight JSONL logger for Mini-Me memory compiler I/O."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
from typing import Any, Dict

from models.schemas import MiniMeChatRequest, MiniMeMemoryDiff, MiniMeMemoryState


def _default_log_path() -> Path:
    configured = os.getenv("LL_MEMORY_LOG_PATH")
    if configured:
        return Path(configured).expanduser().resolve()

    local_app_data = os.getenv("LOCALAPPDATA")
    if local_app_data:
        base = Path(local_app_data)
    else:
        base = Path.home() / ".cache"

    return (base / "lifelens" / "logs" / "minime_memory_events.jsonl").resolve()


def _request_snapshot(chat_input: MiniMeChatRequest) -> Dict[str, Any]:
    return {
        "user_message": chat_input.user_message,
        "latest_mood_label": chat_input.latest_mood_label,
        "latest_mood_intensity": chat_input.latest_mood_intensity,
        "active_symptoms": chat_input.active_symptoms,
        "recent_moods": chat_input.recent_moods,
        "intelligence_tier": chat_input.intelligence_tier,
        "intelligence_phase": chat_input.intelligence_phase,
        "intelligence_risk_score": chat_input.intelligence_risk_score,
        "intelligence_confidence": chat_input.intelligence_confidence,
        "intelligence_actions": chat_input.intelligence_actions,
        "intelligence_alert": chat_input.intelligence_alert,
        "chat_history_tail": [
            {"role": item.role, "text": item.text}
            for item in chat_input.chat_history[-6:]
        ],
    }


def log_memory_event(
    chat_input: MiniMeChatRequest,
    memory_state: MiniMeMemoryState,
    memory_diff: MiniMeMemoryDiff,
    validation_passed: bool,
) -> None:
    """Append one memory compilation event as a JSONL record."""
    path = _default_log_path()
    path.parent.mkdir(parents=True, exist_ok=True)

    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "input": _request_snapshot(chat_input),
        "output": {
            "memory_state": memory_state.model_dump(),
            "validation_passed": validation_passed,
        },
    }

    with path.open("a", encoding="utf-8") as file_handle:
        file_handle.write(json.dumps(record, ensure_ascii=True) + "\n")
