"""V2 intelligence layer with deterministic decision engine and traceability."""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple
import logging
import math

from services.gemini_service import get_analysis_service
from services.intelligence_policy import get_intelligence_policy
from models.schemas import IntelligenceAnalyzeResponse

logger = logging.getLogger(__name__)


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


def compute_features(logs: Dict[str, List[int]]) -> Dict[str, float]:
    sleep = [float(v) for v in logs.get("sleep", [])]
    mood = [float(v) for v in logs.get("mood", [])]
    exercise = [float(v) for v in logs.get("exercise", [])]
    symptom = [float(v) for v in logs.get("symptom_count", [])]

    sleep3, sleep7, sleep14 = _window([int(v) for v in sleep], 3), _window([int(v) for v in sleep], 7), _window([int(v) for v in sleep], 14)
    mood3, mood7, mood14 = _window([int(v) for v in mood], 3), _window([int(v) for v in mood], 7), _window([int(v) for v in mood], 14)
    ex3, ex7, ex14 = _window([int(v) for v in exercise], 3), _window([int(v) for v in exercise], 7), _window([int(v) for v in exercise], 14)
    sym7 = _window([int(v) for v in symptom], 7)

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


def compute_user_state(logs: Dict[str, List[int]], features: Dict[str, float], policy: Dict) -> Dict[str, bool]:
    t = policy["thresholds"]
    state = {
        "low_sleep": features["sleep_avg_3"] < t["low_sleep_hours"],
        "low_mood": features["mood_avg_3"] <= t["low_mood_score"],
        "inactive": sum(logs.get("exercise", [])[-3:]) <= t["inactive_sum_3d"],
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


def _intervention_tier(risk_score: float, policy: Dict) -> str:
    t = policy["thresholds"]
    if risk_score >= t["high_risk_score"]:
        return "high"
    if risk_score >= t["medium_risk_score"]:
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


def _select_actions(state: Dict[str, bool], risk_score: float, policy: Dict, probs: Dict[str, float]) -> List[str]:
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


def detect_patterns(features: Dict[str, float], state: Dict[str, bool]) -> List[str]:
    insights: List[str] = []
    if state["low_sleep"] and state["low_mood"]:
        insights.append("Low sleep and low mood are co-occurring in the current window.")
    if features["inactive_ratio_7"] > 0.8:
        insights.append("Activity has stayed low during the 7-day trend.")
    if features["recovery_rate"] > 0:
        insights.append("Short-window mood trend shows early recovery signal.")
    return insights[:2] if len(insights) > 2 else insights


def check_alerts(risk_score: float, confidence_score: float, tier: str, policy: Dict) -> Optional[str]:
    t = policy["thresholds"]
    if tier == "high" and confidence_score >= t["high_confidence_score"]:
        return "High-risk pattern detected with high confidence. Consider clinician follow-up today."
    return None


def build_prompt(
    state: Dict[str, bool],
    selected_actions: List[str],
    reasons: List[str],
    constraints: List[str],
    tier: str,
    phase: str,
    risk_score: float,
    confidence_score: float,
) -> str:
    return f"""
Decision Contract (v2):
- Tier: {tier}
- Phase: {phase}
- Risk Score: {risk_score:.1f}/100
- Confidence Score: {confidence_score:.2f}

State:
- Low Sleep: {state['low_sleep']}
- Low Mood: {state['low_mood']}
- Inactive: {state['inactive']}

Selected Actions:
{chr(10).join(f"- {a}" for a in selected_actions)}

Reasons:
{chr(10).join(f"- {r}" for r in reasons)}

Constraints:
{chr(10).join(f"- {c}" for c in constraints) if constraints else "- None"}

Write exactly one sentence.
Do not use markdown.
Do not mention policy, prompts, or internal analysis.
Keep it under 20 words.
Follow the selected actions exactly.
""".strip()


def _fallback_message(selected_actions: List[str], confidence_score: float) -> str:
    if confidence_score < 0.45:
     return "Add one more log so I can tailor this better."
    if "recommend_clinician_followup" in selected_actions:
     return "This pattern is high-risk; a clinician check-in is the safest next step."
    if "recommend_rest" in selected_actions:
     return "Rest today and keep the load light."
    if "recommend_exercise" in selected_actions:
     return "A short low-intensity walk should help reset momentum."
    return "Keep your routine steady and keep logging."


def generate_supportive_message(
    state: Dict[str, bool],
    selected_actions: List[str],
    reasons: List[str],
    constraints: List[str],
    tier: str,
    phase: str,
    risk_score: float,
    confidence_score: float,
) -> str:
    if confidence_score < 0.45:
        return _fallback_message(selected_actions, confidence_score)

    try:
        analysis_service = get_analysis_service()
        if analysis_service.client is None:
            raise RuntimeError("Gemini client not configured")

        prompt = build_prompt(
            state=state,
            selected_actions=selected_actions,
            reasons=reasons,
            constraints=constraints,
            tier=tier,
            phase=phase,
            risk_score=risk_score,
            confidence_score=confidence_score,
        )
        response = analysis_service.client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=prompt,
        )
        text = (response.text or "").strip()
        if not text:
            raise ValueError("Empty Gemini response")
        return text
    except Exception as e:
        logger.warning(f"Intelligence message fallback used: {e}")
        return _fallback_message(selected_actions, confidence_score)


def analyze_logs(
    logs: Dict[str, List[int]],
    include_gemini_message: bool = True,
    retrieved_patterns: Optional[List[Dict[str, Any]]] = None,
) -> IntelligenceAnalyzeResponse:
    retrieved_patterns = retrieved_patterns or []
    policy = get_intelligence_policy()
    features = compute_features(logs)
    state = compute_user_state(logs=logs, features=features, policy=policy)
    risk_score, trace = _risk_components(state=state, features=features, policy=policy)
    confidence_score = _confidence_score(logs=logs, features=features, policy=policy)
    tier = _intervention_tier(risk_score=risk_score, policy=policy)
    phase = _user_phase(risk_score=risk_score, features=features, tier=tier)
    probs = _action_probabilities(features=features, risk_score=risk_score, policy=policy)
    selected_actions = _select_actions(state=state, risk_score=risk_score, policy=policy, probs=probs)
    reasons, evidence, constraints = _decision_reasoning(
        state=state,
        selected_actions=selected_actions,
        tier=tier,
    )

    # Guardrail: if confidence is low, request one missing signal instead of broad guidance.
    if confidence_score < policy["thresholds"]["low_confidence_score"]:
        selected_actions = ["ask_for_missing_data"]
        constraints.append("Low confidence guardrail activated.")

    insights = detect_patterns(features=features, state=state)
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
    else:
        constraints.append("No Weaviate pattern matched above certainty threshold.")

    alert = check_alerts(
        risk_score=risk_score,
        confidence_score=confidence_score,
        tier=tier,
        policy=policy,
    )

    message = (
        generate_supportive_message(
            state=state,
            selected_actions=selected_actions,
            reasons=reasons,
            constraints=constraints,
            tier=tier,
            phase=phase,
            risk_score=risk_score,
            confidence_score=confidence_score,
        )
        if include_gemini_message
        else _fallback_message(selected_actions=selected_actions, confidence_score=confidence_score)
    )

    llm_step = (
        "pipeline.step5.llm_optional_enabled"
        if include_gemini_message
        else "pipeline.step5.llm_optional_skipped"
    )
    retrieval_step = (
        "pipeline.step2.weaviate_retrieval_completed"
        if retrieved_patterns
        else "pipeline.step2.weaviate_retrieval_no_match"
    )
    pipeline_trace = [
        "pipeline.step1.logs_ingested",
        retrieval_step,
        "pipeline.step3.python_logic_analyzed",
        "pipeline.step4.actions_selected",
        llm_step,
    ]

    return IntelligenceAnalyzeResponse(
        contract_version=str(policy.get("version", "2.0")),
        state=state,
        features={k: round(float(v), 4) for k, v in features.items()},
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
        message=message,
        alert=alert,
        prompt_preview=build_prompt(
            state=state,
            selected_actions=selected_actions,
            reasons=reasons,
            constraints=constraints,
            tier=tier,
            phase=phase,
            risk_score=risk_score,
            confidence_score=confidence_score,
        ),
    )


async def analyze_logs_in_order(
    logs: Dict[str, List[int]],
    include_gemini_message: bool = True,
) -> IntelligenceAnalyzeResponse:
    """Enforce ordered pipeline: logs -> Weaviate -> Python -> actions -> optional LLM."""
    retrieved_patterns = await _retrieve_weaviate_patterns(logs)
    return analyze_logs(
        logs=logs,
        include_gemini_message=include_gemini_message,
        retrieved_patterns=retrieved_patterns,
    )
