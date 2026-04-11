"""V2 intelligence layer with deterministic decision engine and traceability."""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple
import logging
import math
import re

from services.intelligence_policy import get_intelligence_policy
from models.schemas import IntelligenceAnalyzeResponse
from ml.summarization.inference import format_for_model, generate_summary

logger = logging.getLogger(__name__)

SLEEP_IDEAL_HOURS = 8.0
ACTIVITY_IDEAL_SCORE = 1.0
MOOD_IDEAL_SCORE = 5.0
SYMPTOM_IDEAL_SCORE = 5.0
COMPOSITE_WEIGHTS = {
    "sleep": 0.4,
    "activity": 0.3,
    "mood": 0.3,
}
WEAVIATE_RISK_TERMS = {
    "depression",
    "anxiety",
    "insomnia",
    "burnout",
    "chronic",
    "fatigue",
    "stress",
}

FLAG_VISUAL_MAP = {
    "low_sleep": "sleepy",
    "low_activity": "sluggish",
    "low_mood": "sad",
    "sleep_declining": "drowsy",
    "activity_declining": "static",
    "mood_declining": "concerned",
    "symptoms_increasing": "alert",
    "sleep_mood_compound_risk": "stressed",
    "high_risk": "critical",
    "elevated_risk": "elevated",
    "needs_more_data": "uncertain",
    "follow_up_today": "urgent",
}


def _build_weaviate_query_text(logs: Dict[str, List[int]]) -> str:
    """Build a compact retrieval query from recent user logs."""
    sleep = logs.get("sleep", [])
    mood = logs.get("mood", [])
    exercise = logs.get("exercise", [])
    symptom_count = logs.get("symptom_count", [])

    recent_sleep = sleep[-7:]
    recent_mood = mood[-7:]
    recent_exercise = exercise[-7:]
    recent_symptoms = symptom_count[-7:]

    return (
        "Find relevant health behavior patterns for: "
        f"sleep(last7)={recent_sleep}, "
        f"mood(last7)={recent_mood}, "
        f"exercise(last7)={recent_exercise}, "
        f"symptom_count(last7)={recent_symptoms}."
    )


async def _retrieve_weaviate_patterns(logs: Dict[str, List[int]]) -> List[Dict[str, Any]]:
    """Retrieve candidate patterns from Weaviate before deterministic analysis."""
    try:
        from models.schemas import RAGQuery
        from services.rag_service import get_rag_service

        rag_service = get_rag_service()
        query = RAGQuery(
            query_text=_build_weaviate_query_text(logs),
            max_results=3,
            min_certainty=0.65,
        )

        results = await rag_service.search_similar_conditions(query)
        patterns = []
        for item in results:
            patterns.append(
                {
                    "condition": item.condition,
                    "relevance_score": round(float(item.relevance_score), 4),
                    "source": item.source,
                }
            )
        return patterns
    except Exception as e:
        logger.warning(f"Weaviate retrieval unavailable for intelligence pipeline: {e}")
        return []


def _safe_stddev(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    return math.sqrt(_variance(values))


def _build_calibration(logs: Dict[str, List[int]], policy: Dict[str, Any]) -> Dict[str, Any]:
    thresholds = policy["thresholds"]
    sleep14 = _window(logs.get("sleep", []), 14)
    mood14 = _window(logs.get("mood", []), 14)
    exercise14 = _window(logs.get("exercise", []), 14)
    symptom14 = _window(logs.get("symptom_count", []), 14)

    sleep_baseline = _mean(sleep14) if sleep14 else SLEEP_IDEAL_HOURS
    mood_baseline = _mean(mood14) if mood14 else MOOD_IDEAL_SCORE
    activity_baseline = _mean(exercise14) if exercise14 else ACTIVITY_IDEAL_SCORE
    symptom_baseline = _mean(symptom14) if symptom14 else 0.0

    sleep_variability = _safe_stddev(sleep14)
    mood_variability = _safe_stddev(mood14)
    behavior_volatility = (sleep_variability + mood_variability) / 2.0

    adaptive_low_sleep = _clamp(
        max(
            float(thresholds["low_sleep_hours"]),
            sleep_baseline * 0.78,
        ),
        lower=4.5,
        upper=8.0,
    )
    adaptive_low_mood = _clamp(
        max(
            float(thresholds["low_mood_score"]),
            mood_baseline - max(0.6, mood_variability * 0.8),
        ),
        lower=1.0,
        upper=4.0,
    )
    adaptive_inactive_sum = int(
        round(
            _clamp(
                _mean(exercise14[-7:]) if exercise14 else 0.0,
                lower=0.0,
                upper=2.0,
            )
        )
    )
    adaptive_medium_risk = _clamp(
        float(thresholds["medium_risk_score"]) - behavior_volatility * 2.5,
        lower=30.0,
        upper=65.0,
    )
    adaptive_high_risk = _clamp(
        max(
            adaptive_medium_risk + 12.0,
            float(thresholds["high_risk_score"]) - behavior_volatility * 3.5,
        ),
        lower=50.0,
        upper=90.0,
    )

    return {
        "baselines": {
            "sleep": round(sleep_baseline, 4),
            "mood": round(mood_baseline, 4),
            "activity": round(activity_baseline, 4),
            "symptom_count": round(symptom_baseline, 4),
        },
        "adaptive_thresholds": {
            "low_sleep_hours": round(adaptive_low_sleep, 4),
            "low_mood_score": round(adaptive_low_mood, 4),
            "inactive_sum_3d": adaptive_inactive_sum,
            "medium_risk_score": round(adaptive_medium_risk, 4),
            "high_risk_score": round(adaptive_high_risk, 4),
            "decline_rate": -0.08 if behavior_volatility < 0.9 else -0.05,
            "increase_rate": 0.08 if behavior_volatility < 0.9 else 0.05,
        },
        "volatility": round(behavior_volatility, 4),
        "window_days": min(14, max(len(sleep14), len(mood14), len(exercise14))),
        "strategy": "user_adaptive_v1",
    }


def _weaviate_influence(retrieved_patterns: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not retrieved_patterns:
        return {
            "risk_adjustment": 0.0,
            "confidence_adjustment": 0.0,
            "matched_conditions": [],
            "action_hints": [],
        }

    top = retrieved_patterns[:3]
    weighted_relevance = _mean([float(item.get("relevance_score", 0.0)) for item in top])
    condition_blob = " ".join(str(item.get("condition", "")).lower() for item in top)
    risk_term_hits = len({term for term in WEAVIATE_RISK_TERMS if re.search(rf"\\b{re.escape(term)}\\b", condition_blob)})

    risk_adjustment = _clamp(weighted_relevance * 14.0 + (risk_term_hits * 3.5), lower=0.0, upper=20.0)
    confidence_adjustment = _clamp(weighted_relevance * 0.16 + len(top) * 0.01, lower=0.0, upper=0.14)

    action_hints: List[str] = []
    if any(term in condition_blob for term in ("insomnia", "fatigue", "sleep")):
        action_hints.append("recommend_rest")
    if any(term in condition_blob for term in ("anxiety", "depression", "burnout", "stress")):
        action_hints.append("recommend_social_support")
    if "chronic" in condition_blob:
        action_hints.append("recommend_clinician_followup")

    return {
        "risk_adjustment": round(risk_adjustment, 4),
        "confidence_adjustment": round(confidence_adjustment, 4),
        "matched_conditions": [str(item.get("condition", "unknown")) for item in top],
        "action_hints": list(dict.fromkeys(action_hints)),
        "weighted_relevance": round(weighted_relevance, 4),
    }


def _evaluate_predictive_quality(logs: Dict[str, List[int]], calibration: Dict[str, Any]) -> Dict[str, Any]:
    size = min(len(logs.get("sleep", [])), len(logs.get("mood", [])), len(logs.get("exercise", [])))
    if size < 8:
        return {
            "samples": 0,
            "accuracy": None,
            "precision": None,
            "recall": None,
            "low_sleep_flag_accuracy": None,
            "low_mood_flag_accuracy": None,
            "notes": "not_enough_history",
        }

    low_sleep_t = float(calibration["adaptive_thresholds"]["low_sleep_hours"])
    low_mood_t = float(calibration["adaptive_thresholds"]["low_mood_score"])

    tp = fp = tn = fn = 0
    low_sleep_match = 0
    low_mood_match = 0
    evaluated = 0

    for idx in range(5, size - 1):
        sleep_now = [float(v) for v in logs["sleep"][max(0, idx - 2): idx + 1]]
        mood_now = [float(v) for v in logs["mood"][max(0, idx - 2): idx + 1]]

        predicted_low_sleep = _mean(sleep_now) < low_sleep_t
        predicted_low_mood = _mean(mood_now) <= low_mood_t
        predicted_risk = predicted_low_sleep or predicted_low_mood

        observed_next_low_sleep = float(logs["sleep"][idx + 1]) < low_sleep_t
        observed_next_low_mood = float(logs["mood"][idx + 1]) <= low_mood_t
        observed_outcome = observed_next_low_sleep or observed_next_low_mood

        low_sleep_match += int(predicted_low_sleep == observed_next_low_sleep)
        low_mood_match += int(predicted_low_mood == observed_next_low_mood)
        evaluated += 1

        if predicted_risk and observed_outcome:
            tp += 1
        elif predicted_risk and not observed_outcome:
            fp += 1
        elif not predicted_risk and observed_outcome:
            fn += 1
        else:
            tn += 1

    accuracy = (tp + tn) / evaluated if evaluated else None
    precision = tp / (tp + fp) if (tp + fp) else None
    recall = tp / (tp + fn) if (tp + fn) else None

    return {
        "samples": evaluated,
        "accuracy": round(accuracy, 4) if accuracy is not None else None,
        "precision": round(precision, 4) if precision is not None else None,
        "recall": round(recall, 4) if recall is not None else None,
        "low_sleep_flag_accuracy": round(low_sleep_match / evaluated, 4) if evaluated else None,
        "low_mood_flag_accuracy": round(low_mood_match / evaluated, 4) if evaluated else None,
        "notes": "rolling_next_day_proxy",
    }


def _build_mini_me_linkage(flags: List[str], projection: Dict[str, Any], tier: str, phase: str) -> Dict[str, Any]:
    visual_tags = [FLAG_VISUAL_MAP[flag] for flag in flags if flag in FLAG_VISUAL_MAP]
    unique_visual_tags = list(dict.fromkeys(visual_tags))

    if phase == "acute-risk" or tier == "high":
        animation_state = "alert_pulse"
    elif projection.get("direction", 0) > 0:
        animation_state = "recover_rise"
    elif projection.get("direction", 0) < 0:
        animation_state = "decline_fade"
    else:
        animation_state = "steady_idle"

    return {
        "avatar_visual_state": unique_visual_tags[0] if unique_visual_tags else "neutral",
        "avatar_visual_tags": unique_visual_tags,
        "animation_state": animation_state,
        "projection_animation_map": {
            "health_score_next_window": animation_state,
            "direction": "up" if projection.get("direction", 0) > 0 else "down" if projection.get("direction", 0) < 0 else "flat",
        },
        "flag_visual_map": {flag: FLAG_VISUAL_MAP.get(flag, "neutral") for flag in flags},
    }


def _z_score(value: float, values: List[float]) -> float:
    mean_value = _mean(values)
    std_value = _safe_stddev(values)
    if std_value == 0:
        return 0.0
    return (value - mean_value) / std_value


def _trend_label(trend_rate: float, slope: float, threshold: float = 0.08) -> str:
    if trend_rate > threshold or slope > threshold:
        return "improving"
    if trend_rate < -threshold or slope < -threshold:
        return "declining"
    return "stable"


def _health_state_vector(features: Dict[str, float], trends: Dict[str, Any]) -> Dict[str, Any]:
    labels = [
        "sleep_avg",
        "mood_avg",
        "activity_avg",
        "symptom_trend",
        "variance_sleep",
        "slope_mood",
    ]
    vector = [
        round(float(features.get("sleep_avg_7", 0.0)), 4),
        round(float(features.get("mood_avg_7", 0.0)), 4),
        round(float(features.get("exercise_avg_7", 0.0)), 4),
        round(float(trends.get("symptom_count_trend_rate", 0.0)), 4),
        round(float(features.get("sleep_variance_7", 0.0)), 4),
        round(float(features.get("mood_slope_7", 0.0)), 4),
    ]
    return {
        "labels": labels,
        "vector": vector,
    }


def _build_regression_features(logs: Dict[str, List[int]], end_index: int) -> Dict[str, float]:
    slice_logs = {
        key: values[: end_index + 1]
        for key, values in logs.items()
    }
    return compute_features(slice_logs)


def _linear_regression_fit(samples: List[List[float]], targets: List[float]) -> Dict[str, Any]:
    if not samples or not targets or len(samples) != len(targets):
        return {"coefficients": [], "intercept": 0.0, "r2": 0.0}

    feature_count = len(samples[0])
    x_rows = [[1.0, *row] for row in samples]
    matrix_size = feature_count + 1
    xtx = [[0.0 for _ in range(matrix_size)] for _ in range(matrix_size)]
    xty = [0.0 for _ in range(matrix_size)]

    for row, target in zip(x_rows, targets):
        for i in range(matrix_size):
            xty[i] += row[i] * target
            for j in range(matrix_size):
                xtx[i][j] += row[i] * row[j]

    ridge = 0.01
    for i in range(1, matrix_size):
        xtx[i][i] += ridge

    solution = _solve_linear_system(xtx, xty)
    if not solution:
        return {"coefficients": [], "intercept": 0.0, "r2": 0.0}

    intercept = solution[0]
    coefficients = solution[1:]
    predictions = [intercept + sum(w * x for w, x in zip(coefficients, row)) for row in samples]
    mean_target = _mean(targets)
    ss_tot = sum((target - mean_target) ** 2 for target in targets)
    ss_res = sum((target - pred) ** 2 for target, pred in zip(targets, predictions))
    r2 = 1.0 - (ss_res / ss_tot) if ss_tot else 0.0

    return {
        "coefficients": [round(float(value), 6) for value in coefficients],
        "intercept": round(float(intercept), 6),
        "r2": round(float(r2), 4),
    }


def _solve_linear_system(matrix: List[List[float]], values: List[float]) -> List[float]:
    size = len(values)
    augmented = [row[:] + [values[index]] for index, row in enumerate(matrix)]

    for pivot_index in range(size):
        pivot_row = max(range(pivot_index, size), key=lambda row_index: abs(augmented[row_index][pivot_index]))
        pivot_value = augmented[pivot_row][pivot_index]
        if abs(pivot_value) < 1e-9:
            continue
        if pivot_row != pivot_index:
            augmented[pivot_index], augmented[pivot_row] = augmented[pivot_row], augmented[pivot_index]

        for row_index in range(pivot_index + 1, size):
            factor = augmented[row_index][pivot_index] / augmented[pivot_index][pivot_index]
            for column_index in range(pivot_index, size + 1):
                augmented[row_index][column_index] -= factor * augmented[pivot_index][column_index]

    solution = [0.0 for _ in range(size)]
    for row_index in range(size - 1, -1, -1):
        diagonal = augmented[row_index][row_index]
        if abs(diagonal) < 1e-9:
            solution[row_index] = 0.0
            continue
        remainder = sum(augmented[row_index][column_index] * solution[column_index] for column_index in range(row_index + 1, size))
        solution[row_index] = (augmented[row_index][size] - remainder) / diagonal
    return solution


def _forecast_next_day(logs: Dict[str, List[int]]) -> Dict[str, Any]:
    keys = ["sleep", "mood", "exercise"]
    response: Dict[str, Any] = {}
    sample_rows: List[List[float]] = []
    targets_by_key: Dict[str, List[float]] = {key: [] for key in keys}

    total_length = min(len(logs.get("sleep", [])), len(logs.get("mood", [])), len(logs.get("exercise", [])))
    if total_length < 4:
        return {
            "method": "heuristic_fallback",
            "r2": 0.0,
            "next_day": {
                "sleep": _mean([float(v) for v in logs.get("sleep", [])[-3:]]),
                "mood": _mean([float(v) for v in logs.get("mood", [])[-3:]]),
                "activity": _mean([float(v) for v in logs.get("exercise", [])[-3:]]),
            },
            "model": {"coefficients": [], "intercept": 0.0},
        }

    feature_names = [
        "sleep_avg_3",
        "sleep_avg_7",
        "mood_avg_3",
        "mood_avg_7",
        "exercise_avg_3",
        "exercise_avg_7",
        "symptom_avg_7",
        "sleep_slope_7",
        "mood_slope_7",
        "exercise_slope_7",
        "symptom_slope_7",
        "sleep_variance_7",
        "mood_variance_7",
    ]

    for index in range(6, total_length - 1):
        features = _build_regression_features(logs, index)
        sample_rows.append([float(features.get(name, 0.0)) for name in feature_names])
        targets_by_key["sleep"].append(float(logs["sleep"][index + 1]))
        targets_by_key["mood"].append(float(logs["mood"][index + 1]))
        targets_by_key["exercise"].append(float(logs["exercise"][index + 1]))

    if not sample_rows:
        return {
            "method": "heuristic_fallback",
            "r2": 0.0,
            "next_day": {
                "sleep": _mean([float(v) for v in logs.get("sleep", [])[-3:]]),
                "mood": _mean([float(v) for v in logs.get("mood", [])[-3:]]),
                "activity": _mean([float(v) for v in logs.get("exercise", [])[-3:]]),
            },
            "model": {"coefficients": [], "intercept": 0.0},
        }

    fitted_models: Dict[str, Any] = {}
    for key, targets in targets_by_key.items():
        fitted_models[key] = _linear_regression_fit(sample_rows, targets)

    latest_features = compute_features(logs)
    latest_row = [float(latest_features.get(name, 0.0)) for name in feature_names]

    def predict(model: Dict[str, Any]) -> float:
        coefficients = model.get("coefficients", [])
        intercept = float(model.get("intercept", 0.0))
        if not coefficients:
            return 0.0
        return intercept + sum(float(weight) * float(value) for weight, value in zip(coefficients, latest_row))

    next_day = {
        "sleep": _clamp(predict(fitted_models["sleep"]), lower=0.0, upper=12.0),
        "mood": _clamp(predict(fitted_models["mood"]), lower=0.0, upper=5.0),
        "activity": _clamp(predict(fitted_models["exercise"]), lower=0.0, upper=5.0),
    }

    response["method"] = "linear_regression"
    response["feature_names"] = feature_names
    response["models"] = fitted_models
    response["next_day"] = {k: round(float(v), 4) for k, v in next_day.items()}
    response["r2"] = round(_mean([float(model.get("r2", 0.0)) for model in fitted_models.values()]), 4)
    return response


def _detect_anomalies(logs: Dict[str, List[int]], features: Dict[str, float]) -> List[Dict[str, Any]]:
    anomalies: List[Dict[str, Any]] = []
    windows = {
        "sleep": [float(v) for v in logs.get("sleep", [])[-14:]],
        "mood": [float(v) for v in logs.get("mood", [])[-14:]],
        "activity": [float(v) for v in logs.get("exercise", [])[-14:]],
        "symptom_count": [float(v) for v in logs.get("symptom_count", [])[-14:]],
    }
    current_values = {
        "sleep": float(features.get("sleep_avg_3", 0.0)),
        "mood": float(features.get("mood_avg_3", 0.0)),
        "activity": float(features.get("exercise_avg_3", 0.0)),
        "symptom_count": float(features.get("symptom_avg_3", 0.0)),
    }

    for metric_name, values in windows.items():
        if len(values) < 4:
            continue
        z_value = _z_score(current_values[metric_name], values)
        if abs(z_value) >= 2.0:
            anomalies.append(
                {
                    "metric": metric_name,
                    "z_score": round(float(z_value), 4),
                    "direction": "high" if z_value > 0 else "low",
                    "threshold": 2.0,
                }
            )

    return anomalies[:5]


def _classify_trends(trends: Dict[str, Any], features: Dict[str, float]) -> Dict[str, str]:
    return {
        "sleep": _trend_label(float(trends.get("sleep_trend_rate", 0.0)), float(features.get("sleep_slope_7", 0.0))),
        "mood": _trend_label(float(trends.get("mood_trend_rate", 0.0)), float(features.get("mood_slope_7", 0.0))),
        "activity": _trend_label(float(trends.get("activity_trend_rate", 0.0)), float(features.get("exercise_slope_7", 0.0))),
        "overall": _trend_label(float(trends.get("health_score_trend_rate", 0.0)), float(trends.get("health_score_trend_delta", 0.0))),
    }


def _deterministic_summary(risk_score: float, tier: str, trend_classification: Dict[str, str], next_day: Dict[str, Any]) -> str:
    dominant_trend = trend_classification.get("overall", "stable")

    if tier == "high":
        opening = "Your current pattern suggests elevated short-term risk."
    elif tier == "medium":
        opening = "Your recent signals show moderate risk that should be watched closely."
    else:
        opening = "Your overall trend is currently in a manageable range."

    if dominant_trend == "declining":
        trend_note = "Sleep and mood trends are moving downward."
    elif dominant_trend == "improving":
        trend_note = "Recent signals show early recovery momentum."
    else:
        trend_note = "Your short-term trends look fairly stable."

    return f"{opening} {trend_note}"


def _action_to_user_text(action: str) -> str:
    mapping = {
        "ask_for_missing_data": "Log another day of sleep, mood, and activity for higher-confidence guidance.",
        "recommend_rest": "Prioritize rest and lower stress load today.",
        "recommend_exercise": "Add a short, low-pressure activity block to support momentum.",
        "recommend_social_support": "Reach out to someone you trust and use supportive coping routines.",
        "recommend_clinician_followup": "Consider timely clinician follow-up if these patterns continue.",
        "maintain_routine": "Keep your current healthy routine consistent.",
    }
    return mapping.get(action, "Continue logging and maintain steady health habits.")


def _strip_recommended_action_clause(text: str) -> str:
    cleaned = re.sub(r"\s*Recommended action: .*?Confidence=[0-9.]+\.?", "", text, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", cleaned).strip()


def _fallback_message(
    selected_actions: List[str],
    confidence_score: float,
    risk_score: float,
    tier: str,
    trend_classification: Dict[str, str],
    next_day: Dict[str, Any],
) -> str:
    base = _deterministic_summary(
        risk_score=risk_score,
        tier=tier,
        trend_classification=trend_classification,
        next_day=next_day,
    )
    if confidence_score < 0.45:
        confidence_note = "Data confidence is limited right now."
    elif confidence_score < 0.7:
        confidence_note = "Confidence is moderate."
    else:
        confidence_note = "Confidence is high."
    return f"{base} {confidence_note}"


def _is_summary_usable(summary: str) -> bool:
    normalized = summary.strip()
    lowered = normalized.lower()

    if lowered.startswith("deterministic analysis:"):
        return False

    if len(normalized) < 10:
        return False
    if len(normalized) > 280:
        return False
    if "unknown" in lowered:
        return False
    if lowered.count("=") >= 2:
        return False
    if any(token in lowered for token in ("sleep_avg_3", "mood_avg_3", "sleep_slope", "mood_slope", "risk=", "trend=")):
        return False
    if re.search(r"\b(\w+)(\s+\1){2,}\b", lowered):
        return False

    word_count = len([part for part in re.split(r"\s+", normalized) if part])
    if word_count < 4:
        return False

    return True


def _window(values: List[int], n: int) -> List[float]:
    if not values:
        return []
    return [float(v) for v in values[-n:]]


def _mean(values: List[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _variance(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    m = _mean(values)
    return sum((v - m) ** 2 for v in values) / len(values)


def _slope(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    n = len(values)
    xs = list(range(n))
    x_mean = sum(xs) / n
    y_mean = _mean(values)
    num = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, values))
    den = sum((x - x_mean) ** 2 for x in xs)
    return num / den if den else 0.0


def _streak_length(values: List[float], predicate) -> int:
    streak = 0
    for v in reversed(values):
        if predicate(v):
            streak += 1
        else:
            break
    return streak


def _sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


def _clamp(value: float, lower: float = 0.0, upper: float = 100.0) -> float:
    return max(lower, min(upper, value))


def _normalize_to_score(value: float, ideal_value: float) -> float:
    if ideal_value <= 0:
        return 0.0
    return _clamp((value / ideal_value) * 100.0)


def _comparison_windows(values: List[float]) -> Tuple[List[float], List[float]]:
    if len(values) >= 14:
        return values[-7:], values[-14:-7]
    if len(values) >= 6:
        return values[-3:], values[-6:-3]
    if len(values) >= 4:
        midpoint = len(values) // 2
        return values[midpoint:], values[:midpoint]
    return [], []


def _trend_rate(recent_avg: float, past_avg: float) -> float:
    if past_avg == 0:
        if recent_avg == 0:
            return 0.0
        return 1.0
    return (recent_avg - past_avg) / abs(past_avg)


def _window_score(values: List[float], ideal_value: float) -> float:
    return _normalize_to_score(_mean(values), ideal_value) if values else 0.0


def _build_scores(logs: Dict[str, List[int]]) -> Dict[str, float]:
    sleep_recent, _ = _comparison_windows([float(v) for v in logs.get("sleep", [])])
    mood_recent, _ = _comparison_windows([float(v) for v in logs.get("mood", [])])
    exercise_recent, _ = _comparison_windows([float(v) for v in logs.get("exercise", [])])
    symptom_recent, _ = _comparison_windows([float(v) for v in logs.get("symptom_count", [])])

    sleep_score = _window_score(sleep_recent, SLEEP_IDEAL_HOURS)
    activity_score = _window_score(exercise_recent, ACTIVITY_IDEAL_SCORE)
    mood_score = _window_score(mood_recent, MOOD_IDEAL_SCORE)
    symptom_burden_score = 100.0 - _window_score(symptom_recent, SYMPTOM_IDEAL_SCORE)

    health_score = (
        COMPOSITE_WEIGHTS["sleep"] * sleep_score
        + COMPOSITE_WEIGHTS["activity"] * activity_score
        + COMPOSITE_WEIGHTS["mood"] * mood_score
    )

    return {
        "sleep": round(sleep_score, 4),
        "activity": round(activity_score, 4),
        "mood": round(mood_score, 4),
        "symptom_burden": round(_clamp(symptom_burden_score), 4),
        "health_score": round(_clamp(health_score), 4),
    }


def _build_trends(logs: Dict[str, List[int]], scores: Dict[str, float]) -> Dict[str, Any]:
    trend_map: Dict[str, Any] = {}
    for metric_name, ideal_value in (
        ("sleep", SLEEP_IDEAL_HOURS),
        ("activity", ACTIVITY_IDEAL_SCORE),
        ("mood", MOOD_IDEAL_SCORE),
        ("symptom_count", SYMPTOM_IDEAL_SCORE),
    ):
        recent_values, past_values = _comparison_windows([float(v) for v in logs.get(metric_name, [])])
        recent_avg = _mean(recent_values)
        past_avg = _mean(past_values)
        trend_rate = _trend_rate(recent_avg, past_avg)
        trend_map[f"{metric_name}_recent_avg"] = round(recent_avg, 4)
        trend_map[f"{metric_name}_past_avg"] = round(past_avg, 4)
        trend_map[f"{metric_name}_trend_rate"] = round(trend_rate, 4)
        trend_map[f"{metric_name}_trend_delta"] = round(_normalize_to_score(recent_avg, ideal_value) - _normalize_to_score(past_avg, ideal_value), 4)

    trend_map["sleep_recent_score"] = round(_normalize_to_score(trend_map["sleep_recent_avg"], SLEEP_IDEAL_HOURS), 4)
    trend_map["sleep_past_score"] = round(_normalize_to_score(trend_map["sleep_past_avg"], SLEEP_IDEAL_HOURS), 4)
    trend_map["activity_recent_score"] = round(_normalize_to_score(trend_map["activity_recent_avg"], ACTIVITY_IDEAL_SCORE), 4)
    trend_map["activity_past_score"] = round(_normalize_to_score(trend_map["activity_past_avg"], ACTIVITY_IDEAL_SCORE), 4)
    trend_map["mood_recent_score"] = round(_normalize_to_score(trend_map["mood_recent_avg"], MOOD_IDEAL_SCORE), 4)
    trend_map["mood_past_score"] = round(_normalize_to_score(trend_map["mood_past_avg"], MOOD_IDEAL_SCORE), 4)
    trend_map["health_score_recent_avg"] = round(
        (
            COMPOSITE_WEIGHTS["sleep"] * trend_map["sleep_recent_score"]
            + COMPOSITE_WEIGHTS["activity"] * trend_map["activity_recent_score"]
            + COMPOSITE_WEIGHTS["mood"] * trend_map["mood_recent_score"]
        ),
        4,
    )
    trend_map["health_score_past_avg"] = round(
        (
            COMPOSITE_WEIGHTS["sleep"] * trend_map["sleep_past_score"]
            + COMPOSITE_WEIGHTS["activity"] * trend_map["activity_past_score"]
            + COMPOSITE_WEIGHTS["mood"] * trend_map["mood_past_score"]
        ),
        4,
    )
    trend_map["health_score_trend_rate"] = round(
        _trend_rate(trend_map["health_score_recent_avg"], trend_map["health_score_past_avg"]),
        4,
    )
    trend_map["health_score_trend_delta"] = round(trend_map["health_score_recent_avg"] - trend_map["health_score_past_avg"], 4)
    return trend_map


def _build_projection(scores: Dict[str, float], trends: Dict[str, Any]) -> Dict[str, Any]:
    projection = {
        "health_score_next_window": round(_clamp(scores["health_score"] + trends["health_score_trend_delta"]), 4),
        "sleep_next_window": round(_clamp(scores["sleep"] + trends["sleep_trend_delta"]), 4),
        "activity_next_window": round(_clamp(scores["activity"] + trends["activity_trend_delta"]), 4),
        "mood_next_window": round(_clamp(scores["mood"] + trends["mood_trend_delta"]), 4),
    }
    projection["direction"] = 1 if projection["health_score_next_window"] >= scores["health_score"] else -1
    return projection


def _build_flags(
    state: Dict[str, bool],
    scores: Dict[str, float],
    trends: Dict[str, float],
    tier: str,
    confidence_score: float,
    alert: Optional[str],
    calibration: Dict[str, Any],
) -> List[str]:
    flags: List[str] = []
    adaptive = calibration.get("adaptive_thresholds", {})
    decline_rate = float(adaptive.get("decline_rate", -0.1))
    increase_rate = float(adaptive.get("increase_rate", 0.1))
    sleep_score_floor = _normalize_to_score(float(adaptive.get("low_sleep_hours", 6.0)), SLEEP_IDEAL_HOURS)
    mood_score_floor = _normalize_to_score(float(adaptive.get("low_mood_score", 2.0)), MOOD_IDEAL_SCORE)

    if scores["sleep"] < sleep_score_floor:
        flags.append("low_sleep")
    if scores["activity"] < 60.0:
        flags.append("low_activity")
    if scores["mood"] < mood_score_floor:
        flags.append("low_mood")
    if trends["sleep_trend_rate"] < decline_rate:
        flags.append("sleep_declining")
    if trends["activity_trend_rate"] < decline_rate:
        flags.append("activity_declining")
    if trends["mood_trend_rate"] < decline_rate:
        flags.append("mood_declining")
    if trends["symptom_count_trend_rate"] > increase_rate:
        flags.append("symptoms_increasing")
    if state["low_sleep"] and state["low_mood"]:
        flags.append("sleep_mood_compound_risk")
    if tier == "high":
        flags.append("high_risk")
    elif tier == "medium":
        flags.append("elevated_risk")
    if confidence_score < 0.45:
        flags.append("needs_more_data")
    if alert:
        flags.append("follow_up_today")
    return flags[:8]


def compute_features(logs: Dict[str, List[int]]) -> Dict[str, float]:
    sleep = [float(v) for v in logs.get("sleep", [])]
    mood = [float(v) for v in logs.get("mood", [])]
    exercise = [float(v) for v in logs.get("exercise", [])]
    symptom = [float(v) for v in logs.get("symptom_count", [])]

    sleep3, sleep7, sleep14 = _window([int(v) for v in sleep], 3), _window([int(v) for v in sleep], 7), _window([int(v) for v in sleep], 14)
    mood3, mood7, mood14 = _window([int(v) for v in mood], 3), _window([int(v) for v in mood], 7), _window([int(v) for v in mood], 14)
    ex3, ex7, ex14 = _window([int(v) for v in exercise], 3), _window([int(v) for v in exercise], 7), _window([int(v) for v in exercise], 14)
    sym3, sym7, sym14 = _window([int(v) for v in symptom], 3), _window([int(v) for v in symptom], 7), _window([int(v) for v in symptom], 14)

    features = {
        "sleep_avg_3": _mean(sleep3),
        "sleep_avg_7": _mean(sleep7),
        "sleep_avg_14": _mean(sleep14),
        "mood_avg_3": _mean(mood3),
        "mood_avg_7": _mean(mood7),
        "mood_avg_14": _mean(mood14),
        "exercise_avg_3": _mean(ex3),
        "exercise_avg_7": _mean(ex7),
        "exercise_avg_14": _mean(ex14),
        "symptom_avg_3": _mean(sym3),
        "symptom_avg_7": _mean(sym7),
        "symptom_avg_14": _mean(sym14),
        "inactive_ratio_7": 1.0 - _mean(ex7) if ex7 else 0.0,
        "sleep_slope_7": _slope(sleep7),
        "mood_slope_7": _slope(mood7),
        "exercise_slope_7": _slope(ex7),
        "symptom_slope_7": _slope(sym7),
        "sleep_variance_7": _variance(sleep7),
        "mood_variance_7": _variance(mood7),
        "sleep_volatility_7": math.sqrt(_variance(sleep7)),
        "mood_volatility_7": math.sqrt(_variance(mood7)),
        "low_sleep_streak": float(_streak_length(sleep7, lambda v: v < 6)),
        "low_mood_streak": float(_streak_length(mood7, lambda v: v <= 2)),
        "recovery_rate": max(0.0, _slope(mood3)),
        "sleep_drop_vs_14": _mean(sleep3) - _mean(sleep14),
        "mood_drop_vs_14": _mean(mood3) - _mean(mood14),
    }

    features["interaction_sleep_inactive_symptom"] = 1.0 if (
        features["sleep_drop_vs_14"] < -0.5
        and features["inactive_ratio_7"] > 0.8
        and features["symptom_slope_7"] > 0.0
    ) else 0.0
    features["interaction_low_sleep_low_mood"] = 1.0 if (
        features["sleep_avg_3"] < 6.0 and features["mood_avg_3"] <= 2.0
    ) else 0.0
    return features


def compute_user_state(logs: Dict[str, List[int]], features: Dict[str, float], calibration: Dict[str, Any]) -> Dict[str, bool]:
    t = calibration.get("adaptive_thresholds", {})
    state = {
        "low_sleep": features["sleep_avg_3"] < float(t.get("low_sleep_hours", 6.0)),
        "low_mood": features["mood_avg_3"] <= float(t.get("low_mood_score", 2.0)),
        "inactive": sum(logs.get("exercise", [])[-3:]) <= int(t.get("inactive_sum_3d", 0)),
    }
    return state


def _risk_components(state: Dict[str, bool], features: Dict[str, float], policy: Dict) -> Tuple[float, List[str]]:
    w = policy["weights"]
    trace: List[str] = []
    score = 0.0

    if state["low_sleep"]:
        score += w["low_sleep"]
        trace.append(f"rule.low_sleep => +{w['low_sleep']:.1f}")
    if state["low_mood"]:
        score += w["low_mood"]
        trace.append(f"rule.low_mood => +{w['low_mood']:.1f}")
    if state["inactive"]:
        score += w["inactive"]
        trace.append(f"rule.inactive => +{w['inactive']:.1f}")
    if features["sleep_slope_7"] < 0:
        score += w["sleep_slope_decline"] * min(abs(features["sleep_slope_7"]), 1.0)
        trace.append("trend.sleep_slope_decline fired")
    if features["mood_slope_7"] < 0:
        score += w["mood_slope_decline"] * min(abs(features["mood_slope_7"]), 1.0)
        trace.append("trend.mood_slope_decline fired")
    if features["sleep_volatility_7"] > policy["thresholds"]["volatility_high"]:
        score += w["sleep_volatility"]
        trace.append("volatility.sleep_high fired")
    if features["mood_volatility_7"] > policy["thresholds"]["volatility_high"]:
        score += w["mood_volatility"]
        trace.append("volatility.mood_high fired")
    if features["recovery_rate"] > 0:
        score += w["recovery_bonus"] * min(features["recovery_rate"], 1.0)
        trace.append("trend.recovery_bonus fired")
    if features["interaction_sleep_inactive_symptom"] > 0:
        score += w["interaction_sleep_inactive_symptom"]
        trace.append("interaction.sleep_drop+inactive+rising_symptom fired")
    if features["interaction_low_sleep_low_mood"] > 0:
        score += w["interaction_low_sleep_low_mood"]
        trace.append("interaction.low_sleep+low_mood fired")

    return max(0.0, min(100.0, score)), trace


def _confidence_score(logs: Dict[str, List[int]], features: Dict[str, float], policy: Dict) -> float:
    coverage = min(len(logs.get("sleep", [])), len(logs.get("mood", [])), len(logs.get("exercise", []))) / 14.0
    coverage = max(0.0, min(1.0, coverage))
    volatility_penalty = min(0.35, (features["sleep_volatility_7"] + features["mood_volatility_7"]) * 0.08)
    confidence = coverage - volatility_penalty
    if len(logs.get("symptom_count", [])) < 3:
        confidence -= policy["thresholds"]["missing_window_penalty"]
    return max(0.0, min(1.0, confidence))


def _intervention_tier(risk_score: float, calibration: Dict[str, Any]) -> str:
    t = calibration.get("adaptive_thresholds", {})
    if risk_score >= float(t.get("high_risk_score", 70.0)):
        return "high"
    if risk_score >= float(t.get("medium_risk_score", 40.0)):
        return "medium"
    return "low"


def _user_phase(risk_score: float, features: Dict[str, float], tier: str) -> str:
    if tier == "high" and features["mood_slope_7"] <= 0:
        return "acute-risk"
    if features["mood_slope_7"] > 0 and features["sleep_slope_7"] >= 0:
        return "recovering"
    if features["mood_slope_7"] < 0 or features["sleep_slope_7"] < 0:
        return "declining"
    if risk_score < 25:
        return "stable"
    return "declining"


def _action_probabilities(features: Dict[str, float], risk_score: float, policy: Dict) -> Dict[str, float]:
    model = policy["model_coefficients"]
    probs: Dict[str, float] = {}
    for action_name, coeffs in model.items():
        z = float(coeffs.get("bias", 0.0))
        for feature_name, weight in coeffs.items():
            if feature_name == "bias":
                continue
            z += float(weight) * float(features.get(feature_name, 0.0))
        z += float(coeffs.get("risk_score", 0.0)) * risk_score
        probs[action_name] = round(_sigmoid(z), 4)
    return probs


def _select_actions(
    state: Dict[str, bool],
    risk_score: float,
    policy: Dict,
    probs: Dict[str, float],
    prioritized_actions: Optional[List[str]] = None,
) -> List[str]:
    selected: List[str] = []
    for action_name, action_policy in policy["action_policies"].items():
        requirements = action_policy.get("requires", [])
        if any(not state.get(req, False) for req in requirements):
            continue
        if risk_score < float(action_policy.get("min_risk_score", 0.0)):
            continue
        probability_key = action_name.replace("recommend_", "")
        if probs.get(probability_key, 0.0) >= 0.5:
            selected.append(action_name)

    if not selected:
        selected.append("maintain_routine")

    if prioritized_actions:
        for action in prioritized_actions:
            if action not in selected and action in policy.get("action_policies", {}):
                selected.insert(0, action)
    return selected


def _decision_reasoning(state: Dict[str, bool], selected_actions: List[str], tier: str) -> Tuple[List[str], List[str], List[str]]:
    reasons: List[str] = []
    evidence: List[str] = []
    constraints: List[str] = []

    if state["low_sleep"]:
        reasons.append("Recent sleep window indicates sustained sleep debt.")
        evidence.append("low_sleep=true across rolling 3-day average")
    if state["low_mood"]:
        reasons.append("Recent mood scores are below the target baseline.")
        evidence.append("low_mood=true across rolling 3-day average")
    if state["inactive"]:
        reasons.append("Movement activity is low in the recent window.")
        evidence.append("inactive=true in the last 3 days")

    if tier == "high":
        constraints.append("High-risk tier: prioritize safety and short-horizon stabilization.")
    if "maintain_routine" in selected_actions:
        constraints.append("No strong intervention trigger fired; keep monitoring.")
    if not reasons:
        reasons.append("Decision confidence is based on current available logs and trend features.")

    return reasons, evidence, constraints


def detect_patterns(features: Dict[str, float], state: Dict[str, bool], trends: Optional[Dict[str, Any]] = None, scores: Optional[Dict[str, float]] = None) -> List[str]:
    insights: List[str] = []
    if state["low_sleep"] and state["low_mood"]:
        insights.append("Low sleep and low mood are co-occurring in the current window.")
    if features["inactive_ratio_7"] > 0.8:
        insights.append("Activity has stayed low during the 7-day trend.")
    if features["recovery_rate"] > 0:
        insights.append("Short-window mood trend shows early recovery signal.")
    if trends:
        if trends.get("health_score_trend_rate", 0.0) > 0:
            insights.append("Composite health score is improving over the comparison window.")
        elif trends.get("health_score_trend_rate", 0.0) < 0:
            insights.append("Composite health score is declining over the comparison window.")
    if scores and scores.get("health_score", 0.0) < 60.0:
        insights.append("Composite health score remains below the preferred baseline.")
    return insights[:2] if len(insights) > 2 else insights


def check_alerts(risk_score: float, confidence_score: float, tier: str, policy: Dict) -> Optional[str]:
    t = policy["thresholds"]
    if tier == "high" and confidence_score >= t["high_confidence_score"]:
        return "High-risk pattern detected with high confidence. Consider clinician follow-up today."
    return None


def _format_mapping_lines(mapping: Dict[str, Any]) -> str:
    if not mapping:
        return "- None"
    return chr(10).join(f"- {key}: {value}" for key, value in mapping.items())


def analyze_logs(
    logs: Dict[str, List[int]],
    include_gemini_message: bool = True,
    retrieved_patterns: Optional[List[Dict[str, Any]]] = None,
) -> IntelligenceAnalyzeResponse:
    retrieved_patterns = retrieved_patterns or []
    policy = get_intelligence_policy()
    calibration = _build_calibration(logs=logs, policy=policy)
    features = compute_features(logs)
    scores = _build_scores(logs)
    trends = _build_trends(logs, scores=scores)
    projection = _build_projection(scores=scores, trends=trends)
    forecast = _forecast_next_day(logs)
    state = compute_user_state(logs=logs, features=features, calibration=calibration)
    risk_score, trace = _risk_components(state=state, features=features, policy=policy)
    confidence_score = _confidence_score(logs=logs, features=features, policy=policy)
    weaviate_signal = _weaviate_influence(retrieved_patterns)
    risk_score = _clamp(risk_score + float(weaviate_signal["risk_adjustment"]), lower=0.0, upper=100.0)
    confidence_score = _clamp(confidence_score + float(weaviate_signal["confidence_adjustment"]), lower=0.0, upper=1.0)

    tier = _intervention_tier(risk_score=risk_score, calibration=calibration)
    phase = _user_phase(risk_score=risk_score, features=features, tier=tier)
    probs = _action_probabilities(features=features, risk_score=risk_score, policy=policy)
    selected_actions = _select_actions(
        state=state,
        risk_score=risk_score,
        policy=policy,
        probs=probs,
        prioritized_actions=weaviate_signal.get("action_hints", []),
    )
    reasons, evidence, constraints = _decision_reasoning(
        state=state,
        selected_actions=selected_actions,
        tier=tier,
    )
    health_state_vector = _health_state_vector(features=features, trends=trends)
    trend_classification = _classify_trends(trends=trends, features=features)
    anomalies = _detect_anomalies(logs=logs, features=features)
    # Guardrail: if confidence is low, request one missing signal instead of broad guidance.
    if confidence_score < policy["thresholds"]["low_confidence_score"]:
        selected_actions = ["ask_for_missing_data"]
        constraints.append("Low confidence guardrail activated.")

    insights = detect_patterns(features=features, state=state, trends=trends, scores=scores)
    if retrieved_patterns:
        top_matches = ", ".join(
            str(item.get("condition", "unknown"))
            for item in retrieved_patterns[:2]
        )
        insights.insert(0, f"Weaviate pattern match: {top_matches}.")

        evidence.append(f"weaviate.pattern_count={len(retrieved_patterns)}")
        for item in retrieved_patterns[:2]:
            evidence.append(
                "weaviate.match="
                f"{item.get('condition', 'unknown')}"
                f" score={item.get('relevance_score', 0)}"
            )
        evidence.append(f"weaviate.risk_adjustment={weaviate_signal['risk_adjustment']}")
        evidence.append(f"weaviate.confidence_adjustment={weaviate_signal['confidence_adjustment']}")
    else:
        constraints.append("No Weaviate pattern matched above certainty threshold.")

    alert = check_alerts(
        risk_score=risk_score,
        confidence_score=confidence_score,
        tier=tier,
        policy=policy,
    )

    flags = _build_flags(
        state=state,
        scores=scores,
        trends=trends,
        tier=tier,
        confidence_score=confidence_score,
        alert=alert,
        calibration=calibration,
    )

    evaluation = _evaluate_predictive_quality(logs=logs, calibration=calibration)
    mini_me_linkage = _build_mini_me_linkage(
        flags=flags,
        projection=projection,
        tier=tier,
        phase=phase,
    )

    retrieval_step = (
        "pipeline.step2.weaviate_retrieval_completed"
        if retrieved_patterns
        else "pipeline.step2.weaviate_retrieval_no_match"
    )
    pipeline_trace = [
        "pipeline.step1.logs_ingested",
        "pipeline.step1.normalization_completed",
        retrieval_step,
        "pipeline.step3.trend_projection_completed",
        "pipeline.step4.calibration_applied",
        "pipeline.step5.rule_engine_applied",
        "pipeline.step6.actions_selected",
        "pipeline.step7.statistical_forecast_completed",
    ]
    pipeline_trace.append(f"pipeline.weaviate.risk_adjustment={weaviate_signal['risk_adjustment']}")
    pipeline_trace.append(f"pipeline.evaluation.samples={evaluation.get('samples', 0)}")
    pipeline_trace.append(f"pipeline.anomalies.count={len(anomalies)}")

    input_text = format_for_model(features, scores, trends)
    logger.info(f"[Summarization Input] {input_text}")
    try:
        summary_message = generate_summary(input_text)
        summary_message = _strip_recommended_action_clause(summary_message)
        if not _is_summary_usable(summary_message):
            summary_message = _fallback_message(
                selected_actions=selected_actions,
                confidence_score=confidence_score,
                risk_score=risk_score,
                tier=tier,
                trend_classification=trend_classification,
                next_day=forecast.get("next_day", {}),
            )
    except Exception as e:
        logger.warning(f"Summarization model generation failed, using deterministic fallback: {e}")
        summary_message = _fallback_message(
            selected_actions=selected_actions,
            confidence_score=confidence_score,
            risk_score=risk_score,
            tier=tier,
            trend_classification=trend_classification,
            next_day=forecast.get("next_day", {}),
        )
    logger.info(f"[Summarization Output] {summary_message}")

    return IntelligenceAnalyzeResponse(
        contract_version=str(policy.get("version", "2.0")),
        state=state,
        health_state_vector=health_state_vector["vector"],
        health_state_vector_labels=health_state_vector["labels"],
        features={k: round(float(v), 4) for k, v in features.items()},
        health_score=round(scores["health_score"], 2),
        scores={k: round(float(v), 4) for k, v in scores.items()},
        trends={k: round(float(v), 4) if isinstance(v, (int, float)) else v for k, v in trends.items()},
        trend_classification=trend_classification,
        projection={k: round(float(v), 4) if isinstance(v, (int, float)) else v for k, v in projection.items()},
        next_day_predictions={k: round(float(v), 4) if isinstance(v, (int, float)) else v for k, v in forecast.get("next_day", {}).items()},
        prediction_model={
            "method": forecast.get("method", "linear_regression"),
            "feature_names": forecast.get("feature_names", []),
            "models": forecast.get("models", {}),
            "r2": forecast.get("r2", 0.0),
        },
        anomalies=anomalies,
        flags=flags,
        risk_score=round(risk_score, 2),
        confidence_score=round(confidence_score, 4),
        intervention_tier=tier,
        user_phase=phase,
        selected_actions=selected_actions,
        reasons=reasons,
        evidence=evidence,
        constraints=constraints,
        explanation_trace=pipeline_trace + trace,
        action_probabilities=probs,
        insights=insights,
        actions=selected_actions,
        message=summary_message,
        alert=alert,
        calibration=calibration,
        evaluation=evaluation,
        weaviate_signal=weaviate_signal,
        mini_me_linkage=mini_me_linkage,
        prompt_preview=None,
    )


async def analyze_logs_in_order(
    logs: Dict[str, List[int]],
    include_gemini_message: bool = True,
) -> IntelligenceAnalyzeResponse:
    """Enforce ordered pipeline: logs -> Weaviate -> Python -> forecast -> actions."""
    retrieved_patterns = await _retrieve_weaviate_patterns(logs)
    return analyze_logs(
        logs=logs,
        include_gemini_message=include_gemini_message,
        retrieved_patterns=retrieved_patterns,
    )
