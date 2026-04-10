from pathlib import Path

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


def generate_summary(input_text: str) -> str:
    _ensure_model_loaded()
    inputs = tokenizer(input_text, return_tensors="pt", truncation=True)
    outputs = model.generate(**inputs, max_length=50)
    return tokenizer.decode(outputs[0], skip_special_tokens=True)