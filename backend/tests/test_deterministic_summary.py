from pathlib import Path
import sys

# Allow running this file directly with: py .\test_deterministic_summary.py
BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from services.intelligence import _deterministic_summary

def run_tests():
    test_cases = [
        {
            "name": "High Risk + 2 Declining",
            "inputs": {
                "risk_score": 80.0,
                "tier": "high",
                "trend_classification": {"sleep": "declining", "mood": "declining", "activity": "stable"},
                "next_day": {}
            },
            "expected": "Elevated short-term risk is present, driven by declining momentum in sleep and mood."
        },
        {
            "name": "Medium Risk + Mixed Trends (1 Declining, 1 Improving)",
            "inputs": {
                "risk_score": 55.0,
                "tier": "medium",
                "trend_classification": {"sleep": "declining", "mood": "stable", "activity": "improving"},
                "next_day": {}
            },
            "expected": "Moderate risk requires observation, driven by declining sleep momentum, though activity shows early recovery."
        },
        {
            "name": "Low Risk + All Improving (Oxford Comma Check)",
            "inputs": {
                "risk_score": 20.0,
                "tier": "low",
                "trend_classification": {"sleep": "improving", "mood": "improving", "activity": "improving"},
                "next_day": {}
            },
            "expected": "Overall risk remains in a manageable range, featuring early recovery momentum in sleep, mood, and activity."
        },
        {
            "name": "Low Risk + All Stable",
            "inputs": {
                "risk_score": 15.0,
                "tier": "low",
                "trend_classification": {"sleep": "stable", "mood": "stable", "activity": "stable"},
                "next_day": {}
            },
            "expected": "Overall risk remains in a manageable range, with stable momentum across sleep, mood, and activity."
        },
        {
            "name": "High Risk + Complex Mixed (2 Declining, 1 Improving)",
            "inputs": {
                "risk_score": 75.0,
                "tier": "high",
                "trend_classification": {"sleep": "improving", "mood": "declining", "activity": "declining"},
                "next_day": {}
            },
            "expected": "Elevated short-term risk is present, driven by declining mood and activity momentum, though sleep shows early recovery."
        }
    ]

    passed = 0
    print("=" * 60)
    print("Running _deterministic_summary test suite...")
    print("=" * 60)

    for tc in test_cases:
        out = _deterministic_summary(**tc["inputs"])
        if out == tc["expected"]:
            print(f"✅ PASS: {tc['name']}")
            passed += 1
        else:
            print(f"❌ FAIL: {tc['name']}")
            print(f"   Expected: {tc['expected']}")
            print(f"   Got:      {out}")

    print("-" * 60)
    print(f"Ran {len(test_cases)} tests. {passed} passed, {len(test_cases) - passed} failed.")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()