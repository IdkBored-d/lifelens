"""Deterministic Mini-Me memory compiler (chat + quick track -> structured state)."""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Tuple

from models.schemas import MiniMeChatRequest, MiniMeMemoryDiff, MiniMeMemoryState

NEGATIVE_MOOD_TERMS = {
    "sad",
    "down",
    "anxious",
    "stressed",
    "overwhelmed",
    "angry",
    "depressed",
    "tired",
    "exhausted",
    "low",
}
POSITIVE_MOOD_TERMS = {
    "good",
    "better",
    "calm",
    "okay",
    "happy",
    "focused",
    "motivated",
}

RISK_ORDER = {"low": 0, "medium": 1, "high": 2}


def _recent_user_lines(chat_input: MiniMeChatRequest, max_items: int = 8) -> List[str]:
    lines: List[str] = []
    for item in chat_input.chat_history[-max_items:]:
        if item.role == "user" and item.text.strip():
            lines.append(item.text.strip())
    if chat_input.user_message.strip():
        lines.append(chat_input.user_message.strip())
    return lines


def _infer_mood_state(chat_input: MiniMeChatRequest, user_lines: List[str]) -> str:
    mood_label = (chat_input.latest_mood_label or "").strip().lower()
    intensity = chat_input.latest_mood_intensity
    joined = " ".join([mood_label] + user_lines).lower()

    if any(term in joined for term in NEGATIVE_MOOD_TERMS):
        return "negative"
    if any(term in joined for term in POSITIVE_MOOD_TERMS):
        return "positive"
    if intensity is not None and intensity <= 1:
        return "negative"
    if intensity is not None and intensity >= 4:
        return "positive"
    return "neutral"


def _infer_risk(chat_input: MiniMeChatRequest, mood_state: str) -> str:
    risk_score = chat_input.intelligence_risk_score
    tier = (chat_input.intelligence_tier or "").strip().lower()
    symptom_count = len(chat_input.active_symptoms)

    if risk_score is not None:
        if risk_score >= 70:
            return "high"
        if risk_score >= 40:
            return "medium"
        return "low"

    if tier == "high":
        return "high"
    if tier == "medium":
        return "medium"

    if mood_state == "negative" and symptom_count >= 3:
        return "medium"
    return "low"


def _phase_to_mood_hint(phase: str) -> float:
    value = (phase or "").strip().lower()
    if value in {"declining", "acute-risk"}:
        return -1.0
    if value in {"recovering", "stable"}:
        return 0.4
    return 0.0


def _infer_weighted_mood_state(chat_input: MiniMeChatRequest, user_lines: List[str]) -> str:
    chat_mood = _infer_mood_state(chat_input, user_lines)
    score = 0.0

    score += {"negative": -1.0, "neutral": 0.0, "positive": 1.0}[chat_mood] * 0.55
    score += _phase_to_mood_hint(chat_input.intelligence_phase or "") * 0.30

    risk_score = chat_input.intelligence_risk_score
    if risk_score is not None:
        if risk_score >= 70:
            score -= 0.35
        elif risk_score <= 25:
            score += 0.2

    if score <= -0.35:
        return "negative"
    if score >= 0.35:
        return "positive"
    return "neutral"


def _collect_key_points(chat_input: MiniMeChatRequest, user_lines: List[str]) -> List[str]:
    points: List[str] = []

    mood_label = (chat_input.latest_mood_label or "").strip().lower()
    if mood_label:
        points.append(f"mood label: {mood_label}")

    symptoms = [s.strip().lower() for s in chat_input.active_symptoms if s.strip()]
    if symptoms:
        points.append(f"symptoms reported: {', '.join(symptoms[:3])}")

    if chat_input.intelligence_phase:
        points.append(f"trend phase: {chat_input.intelligence_phase.strip().lower()}")

    if chat_input.intelligence_risk_score is not None:
        points.append(f"risk score: {round(float(chat_input.intelligence_risk_score), 1)}")

    if user_lines:
        compact = " ".join(user_lines[-1].split()).lower()
        compact = re.sub(r"[^a-z0-9\s]", "", compact)
        if compact:
            points.append(f"recent concern: {compact[:80]}")

    for insight in chat_input.intelligence_insights[:2]:
        text = " ".join(insight.strip().split()).lower()
        if text:
            points.append(f"signal: {text[:90]}")

    unique: List[str] = []
    seen = set()
    for item in points:
        key = item.lower()
        if key in seen:
            continue
        # Skip near-duplicates if core tokens already represented.
        tokens = {t for t in re.split(r"\s+", key) if t and len(t) > 2}
        if any(len(tokens & {t for t in re.split(r"\s+", existing.lower()) if len(t) > 2}) >= max(3, len(tokens) - 1) for existing in unique):
            continue
        unique.append(item)
        seen.add(key)
    return unique[:6]


def _primary_key_signal(key_points: List[str]) -> str:
    if not key_points:
        return "limited recent detail"

    priority_prefixes = [
        "risk score:",
        "trend phase:",
        "symptoms reported:",
        "recent concern:",
        "mood label:",
        "signal:",
    ]
    for prefix in priority_prefixes:
        for point in key_points:
            if point.lower().startswith(prefix):
                return point
    return key_points[0]


def _build_summary(mood_state: str, risk: str, key_points: List[str], trend_label: str) -> str:
    trend = (trend_label or "").strip().lower()

    if risk == "high":
        lead = f"Current signals indicate high near-term risk with a {mood_state} mood pattern."
    elif risk == "medium":
        lead = f"Current signals suggest moderate near-term risk with a {mood_state} mood pattern."
    else:
        lead = f"Current signals indicate low near-term risk with a {mood_state} mood pattern."

    if trend in {"declining", "acute-risk"}:
        trend_note = "Trend is moving in a concerning direction."
    elif trend in {"recovering", "stable"}:
        trend_note = "Trend appears stable or improving."
    else:
        trend_note = "Trend signal is limited."

    anchor = _primary_key_signal(key_points)
    return f"{lead} {trend_note} Key signal: {anchor}."


def _build_quick_track(chat_input: MiniMeChatRequest) -> Dict[str, Any]:
    state_flags = []
    if chat_input.intelligence_state:
        state_flags = [k for k, v in chat_input.intelligence_state.items() if v]

    return {
        "sleep_slope": None,
        "mood_slope": None,
        "risk_score": chat_input.intelligence_risk_score,
        "trend_label": chat_input.intelligence_phase or "",
        "tier": chat_input.intelligence_tier or "",
        "confidence": chat_input.intelligence_confidence,
        "alert": chat_input.intelligence_alert or "",
        "state_flags": state_flags,
        "actions": chat_input.intelligence_actions,
    }


def _coerce_previous_memory(previous_memory: Optional[Dict[str, Any]]) -> Optional[MiniMeMemoryState]:
    if not previous_memory:
        return None
    try:
        return MiniMeMemoryState.model_validate(previous_memory)
    except Exception:
        return None


def _max_risk(*risks: str) -> str:
    best = "low"
    for candidate in risks:
        candidate = (candidate or "low").lower()
        if candidate not in RISK_ORDER:
            continue
        if RISK_ORDER[candidate] > RISK_ORDER[best]:
            best = candidate
    return best


def _merge_key_points(old_points: List[str], new_points: List[str], cap: int = 10) -> List[str]:
    merged: List[str] = []
    seen = set()
    for item in (new_points + old_points):
        key = item.strip().lower()
        if not key or key in seen:
            continue
        merged.append(item.strip())
        seen.add(key)
        if len(merged) >= cap:
            break
    return merged


def _merge_quick_track(old_track: Dict[str, Any], new_track: Dict[str, Any]) -> Dict[str, Any]:
    merged = dict(old_track or {})
    for key, value in new_track.items():
        if value is not None and value != "":
            merged[key] = value
        elif key not in merged:
            merged[key] = value
    return merged


def _count_contradictions(
    chat_mood: str,
    weighted_mood: str,
    risk: str,
    risk_score: Optional[float],
    phase: str,
    latest_mood_label: str,
) -> Tuple[int, List[str]]:
    reasons: List[str] = []
    if chat_mood != weighted_mood:
        reasons.append("chat_mood_disagrees_with_weighted_mood")
    if risk_score is not None and risk_score >= 70 and weighted_mood == "positive":
        reasons.append("high_numeric_risk_with_positive_mood")
    if (latest_mood_label or "").strip().lower() in POSITIVE_MOOD_TERMS and risk_score is not None and risk_score >= 70:
        reasons.append("positive_self_label_conflicts_with_high_numeric_risk")
    if risk == "high" and weighted_mood == "positive":
        reasons.append("high_merged_risk_with_positive_mood")
    if (phase or "").strip().lower() == "acute-risk" and risk == "low":
        reasons.append("acute_risk_phase_conflicts_with_low_risk")
    return len(reasons), reasons


def _stability_score(previous: Optional[MiniMeMemoryState], current: MiniMeMemoryState) -> float:
    if previous is None:
        return 1.0

    def _jaccard(a: List[str], b: List[str]) -> float:
        sa = {x.strip().lower() for x in a if x.strip()}
        sb = {x.strip().lower() for x in b if x.strip()}
        if not sa and not sb:
            return 1.0
        if not sa or not sb:
            return 0.0
        return len(sa & sb) / len(sa | sb)

    components = [
        1.0 if previous.summary == current.summary else 0.0,
        1.0 if previous.mood_state == current.mood_state else 0.0,
        1.0 if previous.risk == current.risk else 0.0,
        _jaccard(previous.key_points, current.key_points),
        _jaccard(
            [f"{k}:{v}" for k, v in sorted((previous.quick_track or {}).items())],
            [f"{k}:{v}" for k, v in sorted((current.quick_track or {}).items())],
        ),
    ]
    return round(sum(components) / len(components), 4)


def _validate_memory_state(candidate: MiniMeMemoryState) -> bool:
    if candidate.mood_state not in {"positive", "neutral", "negative"}:
        return False
    if candidate.risk not in {"low", "medium", "high"}:
        return False
    if not isinstance(candidate.quick_track, dict):
        return False
    if len(candidate.key_points) > 10:
        return False
    if not candidate.summary.strip():
        return False
    return True


def _fallback_memory(chat_input: MiniMeChatRequest) -> MiniMeMemoryState:
    risk = _infer_risk(chat_input, "neutral")
    quick_track = _build_quick_track(chat_input)
    return MiniMeMemoryState(
        summary=f"Current signals indicate {risk} near-term risk with limited chat context.",
        key_points=["limited reliable input; fallback memory used"],
        mood_state="neutral",
        risk=risk,
        quick_track=quick_track,
    )


def compile_minime_memory_with_diff(chat_input: MiniMeChatRequest) -> Tuple[MiniMeMemoryState, MiniMeMemoryDiff, bool]:
    previous = _coerce_previous_memory(chat_input.previous_memory)
    user_lines = _recent_user_lines(chat_input)

    chat_mood = _infer_mood_state(chat_input, user_lines)
    mood_state = _infer_weighted_mood_state(chat_input, user_lines)

    inferred_risk = _infer_risk(chat_input, mood_state)
    previous_risk = previous.risk if previous else "low"
    risk = _max_risk(inferred_risk, previous_risk)

    new_key_points = _collect_key_points(chat_input, user_lines)
    merged_key_points = _merge_key_points(previous.key_points if previous else [], new_key_points)

    quick_track = _build_quick_track(chat_input)
    merged_quick_track = _merge_quick_track(previous.quick_track if previous else {}, quick_track)

    summary = _build_summary(
        mood_state,
        risk,
        merged_key_points,
        chat_input.intelligence_phase or "",
    )
    if previous and previous.mood_state == mood_state and previous.risk == risk and not new_key_points:
        summary = previous.summary

    candidate = MiniMeMemoryState(
        summary=summary,
        key_points=merged_key_points,
        mood_state=mood_state,
        risk=risk,
        quick_track=merged_quick_track,
    )

    validation_passed = _validate_memory_state(candidate)
    memory_state = candidate if validation_passed else _fallback_memory(chat_input)

    changed_fields: List[str] = []
    if previous:
        if previous.summary != memory_state.summary:
            changed_fields.append("summary")
        if previous.key_points != memory_state.key_points:
            changed_fields.append("key_points")
        if previous.mood_state != memory_state.mood_state:
            changed_fields.append("mood_state")
        if previous.risk != memory_state.risk:
            changed_fields.append("risk")
        if previous.quick_track != memory_state.quick_track:
            changed_fields.append("quick_track")
    else:
        changed_fields = ["summary", "key_points", "mood_state", "risk", "quick_track"]

    contradiction_count, contradiction_reasons = _count_contradictions(
        chat_mood=chat_mood,
        weighted_mood=memory_state.mood_state,
        risk=memory_state.risk,
        risk_score=chat_input.intelligence_risk_score,
        phase=chat_input.intelligence_phase or "",
        latest_mood_label=chat_input.latest_mood_label or "",
    )

    stability_score = _stability_score(previous, memory_state)

    if not previous:
        reason = "Initialized memory from current chat and quick-track signals."
    elif not changed_fields:
        reason = "No material state change; previous memory preserved."
    else:
        reason = "Updated changed fields using conflict rules: quick-track numeric signals override chat inference."

    memory_diff = MiniMeMemoryDiff(
        changed_fields=changed_fields,
        reason=reason,
        contradiction_count=contradiction_count,
        contradiction_reasons=contradiction_reasons,
        stability_score=stability_score,
    )

    return memory_state, memory_diff, validation_passed


def compile_minime_memory(chat_input: MiniMeChatRequest) -> MiniMeMemoryState:
    memory_state, _, _ = compile_minime_memory_with_diff(chat_input)
    return memory_state
