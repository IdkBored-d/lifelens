"""Quick stability checks for Mini-Me memory compiler.

Runs deterministic test cases and reports:
- JSON/schema validity
- risk/mood consistency checks
- contradiction counts
"""

from __future__ import annotations

import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from models.schemas import MiniMeChatHistoryItem, MiniMeChatRequest
from services.memory_compiler import compile_minime_memory_with_diff


def _cases():
    return [
        {
            "name": "declining_week",
            "user_message": "I have been tired and stressed all week",
            "latest_mood_label": "stressed",
            "latest_mood_intensity": 1,
            "active_symptoms": ["fatigue", "headache"],
            "intelligence_risk_score": 62.0,
            "intelligence_phase": "declining",
            "intelligence_actions": ["recommend_rest"],
            "chat_history": [
                MiniMeChatHistoryItem(role="user", text="I feel drained lately"),
                MiniMeChatHistoryItem(role="assistant", text="Try a gentler day plan"),
            ],
        },
        {
            "name": "stable_ok",
            "user_message": "Today was mostly okay and manageable",
            "latest_mood_label": "okay",
            "latest_mood_intensity": 3,
            "active_symptoms": [],
            "intelligence_risk_score": 18.0,
            "intelligence_phase": "stable",
            "intelligence_actions": ["maintain_routine"],
            "chat_history": [MiniMeChatHistoryItem(role="user", text="I am doing fine this week")],
        },
        {
            "name": "contradictory_signal",
            "user_message": "I feel good today",
            "latest_mood_label": "happy",
            "latest_mood_intensity": 4,
            "active_symptoms": ["insomnia", "fatigue", "anxiety"],
            "intelligence_risk_score": 82.0,
            "intelligence_phase": "acute-risk",
            "intelligence_actions": ["recommend_clinician_followup"],
            "chat_history": [MiniMeChatHistoryItem(role="user", text="Actually I slept very poorly all week")],
        },
    ]


def main() -> None:
    results = []
    previous_memory = None

    for case in _cases():
        request = MiniMeChatRequest(**case, previous_memory=previous_memory)
        memory_state, memory_diff, validation_passed = compile_minime_memory_with_diff(request)

        # Consistency check: high numeric risk should not be mapped to low risk.
        risk_score = case.get("intelligence_risk_score")
        consistent_risk = not (risk_score is not None and risk_score >= 70 and memory_state.risk == "low")

        results.append(
            {
                "name": case["name"],
                "validation_passed": validation_passed,
                "mood_state": memory_state.mood_state,
                "risk": memory_state.risk,
                "contradiction_count": memory_diff.contradiction_count,
                "stability_score": memory_diff.stability_score,
                "consistent_risk": consistent_risk,
            }
        )

        previous_memory = memory_state.model_dump()

    all_valid = all(item["validation_passed"] for item in results)
    all_consistent = all(item["consistent_risk"] for item in results)

    print({
        "all_valid": all_valid,
        "all_consistent": all_consistent,
        "results": results,
    })


if __name__ == "__main__":
    main()
