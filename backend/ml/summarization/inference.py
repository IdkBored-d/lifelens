from pathlib import Path
import re

from transformers import T5ForConditionalGeneration, T5Tokenizer


MODEL_PATH = Path(__file__).resolve().parent / "summarization_model"

tokenizer = None
model = None


def _ensure_model_loaded() -> None:
    global tokenizer, model
    if tokenizer is None:
        tokenizer = T5Tokenizer.from_pretrained(str(MODEL_PATH))
    if model is None:
        model = T5ForConditionalGeneration.from_pretrained(str(MODEL_PATH))


def _trend_label(trend_rate: float, slope: float, threshold: float = 0.08) -> str:
    if trend_rate > threshold or slope > threshold:
        return "improving"
    if trend_rate < -threshold or slope < -threshold:
        return "declining"
    return "stable"


def _signal_sentence(signal_name: str, label: str, detail: str = "") -> str:
    label = (label or "stable").strip().lower()
    signal_name = signal_name.strip().lower()

    if label == "improving":
        lead = f"{signal_name.capitalize()} is trending upward."
    elif label == "declining":
        lead = f"{signal_name.capitalize()} is trending downward."
    else:
        lead = f"{signal_name.capitalize()} is stable."

    if detail:
        return f"{lead} {detail.strip()}"
    return lead


def _mixed_state_sentence(sleep_label: str, mood_label: str, activity_label: str) -> str:
    labels = [sleep_label, mood_label, activity_label]
    declining_count = labels.count("declining")
    improving_count = labels.count("improving")
    stable_count = labels.count("stable")

    if declining_count == 0 and improving_count == 0:
        return "All tracked signals are stable, so the overall trend is stable."
    if declining_count == 3:
        return "Sleep, mood, and activity are all declining, so the overall trend is worsening."
    if improving_count == 3:
        return "Sleep, mood, and activity are all improving, so the overall trend is recovering."
    if declining_count >= 2 and improving_count == 0:
        return "Most tracked signals are declining, so the overall trend is worsening."
    if improving_count >= 2 and declining_count == 0:
        return "Most tracked signals are improving, so the overall trend is recovering."
    if declining_count >= 1 and improving_count >= 1:
        if declining_count > improving_count:
            return "The signals are mixed, but the declining signals outweigh the improving ones, so the overall trend is still worsening."
        if improving_count > declining_count:
            return "The signals are mixed, but the improving signals outweigh the declining ones, so the overall trend is gradually recovering."
        return "The signals are mixed evenly, so the overall trend is still uncertain and best described as stable for now."
    if stable_count >= 2 and declining_count == 1:
        return "Two signals are stable and one is declining, so the overall trend should be treated as mildly worsening."
    if stable_count >= 2 and improving_count == 1:
        return "Two signals are stable and one is improving, so the overall trend should be treated as mildly recovering."
    return "The tracked signals are mixed, so the overall trend is best described as stable for now."


def _overall_sentence(trend_labels: dict, risk_score: float) -> str:
    overall = (trend_labels.get("overall") or "stable").strip().lower()
    sleep = (trend_labels.get("sleep") or "stable").strip().lower()
    mood = (trend_labels.get("mood") or "stable").strip().lower()
    activity = (trend_labels.get("activity") or "stable").strip().lower()

    if overall == "stable" and sleep == mood == activity == "stable":
        return "User is stable overall."
    if overall == "improving":
        return "User is improving overall."
    if overall == "declining":
        return "User is declining overall."

    parts = [f"sleep is {sleep}", f"mood is {mood}", f"activity is {activity}"]
    risk_text = "low" if risk_score < 35 else "medium" if risk_score < 70 else "high"
    return f"Signals are mixed overall: {', '.join(parts)}. Risk is {risk_text}."


def _evidence_sentence(features, scores, trends) -> str:
    return (
        "This conclusion is backed by the computed recent averages, past averages, trend rates, and composite health score, "
        f"not by a guess. Recent sleep={features.get('sleep_avg_3', 0):.2f}, recent mood={features.get('mood_avg_3', 0):.2f}, "
        f"sleep trend={float(trends.get('sleep_trend_rate', 0.0)):.2f}, mood trend={float(trends.get('mood_trend_rate', 0.0)):.2f}, "
        f"activity trend={float(trends.get('activity_trend_rate', 0.0)):.2f}, overall trend={float(trends.get('health_score_trend_rate', 0.0)):.2f}, "
        f"health score={float(scores.get('health_score', 0.0)):.1f}."
    )


def _signal_narrative(features, scores, trends):
    sleep_label = _trend_label(float(trends.get("sleep_trend_rate", 0.0)), float(features.get("sleep_slope_7", 0.0)))
    mood_label = _trend_label(float(trends.get("mood_trend_rate", 0.0)), float(features.get("mood_slope_7", 0.0)))
    activity_label = _trend_label(float(trends.get("activity_trend_rate", 0.0)), float(features.get("exercise_slope_7", 0.0)))
    overall_label = _trend_label(float(trends.get("health_score_trend_rate", 0.0)), float(trends.get("health_score_trend_delta", 0.0)))
    risk_score = float(scores.get("health_score", 0.0))

    lines = [
        _signal_sentence("sleep", sleep_label, f"Recent sleep is {features.get('sleep_avg_3', 0):.2f} hours on average."),
        _signal_sentence("mood", mood_label, f"Recent mood is {features.get('mood_avg_3', 0):.2f} on average."),
        _signal_sentence("activity", activity_label, f"Recent activity is {features.get('exercise_avg_3', 0):.2f} on average."),
        _signal_sentence("overall", overall_label, f"Composite health score is {risk_score:.1f}."),
        _mixed_state_sentence(sleep_label, mood_label, activity_label),
        _overall_sentence({"sleep": sleep_label, "mood": mood_label, "activity": activity_label, "overall": overall_label}, risk_score),
        _evidence_sentence(features, scores, trends),
    ]

    if risk_score >= 70:
        lines.append("Risk is high, so the model should treat the recent pattern as concerning.")
    elif risk_score >= 35:
        lines.append("Risk is moderate, so the model should monitor the pattern closely.")
    else:
        lines.append("Risk is low, so the model can frame the pattern as manageable.")

    return lines


def format_for_model(features, scores, trends):
    tokens = (
        f"sleep_avg_3={features.get('sleep_avg_3', 0)} "
        f"mood_avg_3={features.get('mood_avg_3', 0)} "
        f"sleep_slope={features.get('sleep_slope_7', 0)} "
        f"mood_slope={features.get('mood_slope_7', 0)} "
        f"risk={scores.get('health_score', 0)} "
        f"trend={trends.get('health_score_trend_rate', 0)}"
    )

    narrative = "\n".join(_signal_narrative(features, scores, trends))
    return f"{tokens}\n\nSignal narratives:\n{narrative}"


def _parse_input_features(input_text: str) -> dict:
    parsed = {}
    for key in ("sleep_avg_3", "mood_avg_3", "sleep_slope", "mood_slope", "risk", "trend"):
        match = re.search(rf"{key}=(-?\d+(?:\.\d+)?)", input_text)
        if match:
            parsed[key] = float(match.group(1))
    return parsed


def _heuristic_summary(input_text: str) -> str:
    values = _parse_input_features(input_text)
    sleep_avg = values.get("sleep_avg_3", 0.0)
    mood_avg = values.get("mood_avg_3", 0.0)
    sleep_slope = values.get("sleep_slope", 0.0)
    mood_slope = values.get("mood_slope", 0.0)
    risk = values.get("risk", 0.0)
    trend = values.get("trend", 0.0)

    if risk >= 80 or trend <= -0.25 or (sleep_slope < -0.2 and mood_slope < -0.2):
        return "Sleep and mood are trending downward, suggesting rising fatigue risk."
    if trend >= 0.18 or (sleep_slope > 0.15 and mood_slope > 0.15):
        return "Recent trends indicate recovery, with improving sleep and mood."
    if sleep_avg <= 5.0 and mood_avg >= 3.0:
        return "Low sleep remains the main concern in the latest window."
    if mood_avg <= 2.0:
        return "Mood has stayed low and may require supportive follow-up."
    if risk >= 65:
        return "Multiple indicators suggest elevated short-term risk."
    if abs(trend) <= 0.08 and abs(sleep_slope) <= 0.1 and abs(mood_slope) <= 0.1:
        return "Current sleep and mood signals are stable overall."
    return "Your recent signals look balanced, with no major short-term change."


def _is_generated_summary_usable(summary: str) -> bool:
    normalized = summary.strip()
    lowered = normalized.lower()

    if not normalized:
        return False
    if len(normalized) < 10:
        return False
    if len(normalized) > 280:
        return False
    if lowered.startswith("deterministic analysis:"):
        return False
    if lowered.count("=") >= 1:
        return False
    if any(token in lowered for token in ("sleep_avg_3", "mood_avg_3", "sleep_slope", "mood_slope", "risk=", "trend=")):
        return False
    if re.search(r"\b(\w+)(\s+\1){2,}\b", lowered):
        return False
    return True


def generate_summary(input_text: str) -> str:
    _ensure_model_loaded()
    inputs = tokenizer(input_text, return_tensors="pt", truncation=True)
    outputs = model.generate(
        **inputs,
        max_new_tokens=32,
        num_beams=4,
        length_penalty=1.1,
        no_repeat_ngram_size=3,
        early_stopping=True,
    )
    decoded = tokenizer.decode(outputs[0], skip_special_tokens=True).strip()
    if not _is_generated_summary_usable(decoded):
        return _heuristic_summary(input_text)
    return decoded