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


def format_for_model(features, scores, trends):
    return (
        f"sleep_avg_3={features.get('sleep_avg_3', 0)} "
        f"mood_avg_3={features.get('mood_avg_3', 0)} "
        f"sleep_slope={features.get('sleep_slope_7', 0)} "
        f"mood_slope={features.get('mood_slope_7', 0)} "
        f"risk={scores.get('health_score', 0)} "
        f"trend={trends.get('health_score_trend_rate', 0)}"
    )


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