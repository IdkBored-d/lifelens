import json
import random
from pathlib import Path


def _format_input(sample):
    return (
        f"sleep_avg_3={sample['sleep_avg_3']:.2f} "
        f"mood_avg_3={sample['mood_avg_3']:.2f} "
        f"sleep_slope={sample['sleep_slope']:.3f} "
        f"mood_slope={sample['mood_slope']:.3f} "
        f"risk={sample['risk']:.2f} "
        f"trend={sample['trend']:.3f}"
    )


TEMPLATES = {
    "declining": [
        "Sleep and mood are both trending downward this week, suggesting rising strain.",
        "Recent signals show declining rest and mood, so fatigue risk is increasing.",
        "Your short-term pattern is worsening, with lower sleep and mood over time.",
        "Current trends indicate reduced resilience as sleep and mood continue to drop.",
    ],
    "stable": [
        "Your health signals are stable right now, with no major short-term decline.",
        "Sleep and mood look steady overall; keep your current routine consistent.",
        "The latest pattern is stable and balanced across key wellbeing signals.",
        "No strong change is visible in your recent trend, which suggests stability.",
    ],
    "improving": [
        "Your trend is improving, with gradual gains in sleep and mood.",
        "Recent data shows recovery momentum across your key wellbeing indicators.",
        "Sleep and mood are moving in a healthier direction over the latest window.",
        "You are showing early recovery signs, especially in short-term trend values.",
    ],
    "low_sleep": [
        "Low sleep is the main concern right now and should be prioritized.",
        "Your recent sleep level is below target, even though other signals are mixed.",
        "Sleep debt appears to be building, so recovery-focused habits are recommended.",
        "Rest quality is currently the weakest signal and needs immediate attention.",
    ],
    "low_mood": [
        "Mood has remained low in the recent window and may need added support.",
        "Low mood is the dominant concern in your current pattern.",
        "Your emotional wellbeing trend is subdued and warrants supportive interventions.",
        "Mood remains below baseline despite otherwise moderate signals.",
    ],
    "high_risk": [
        "Overall risk is elevated due to multiple negative trend signals.",
        "Combined indicators suggest a high-risk short-term profile that needs close follow-up.",
        "Your current pattern reflects heightened risk with reinforcing declines.",
        "Risk remains high as key health signals continue trending in the wrong direction.",
    ],
}


def _build_sample(case):
    if case == "declining":
        return {
            "sleep_avg_3": random.uniform(4.2, 6.1),
            "mood_avg_3": random.uniform(1.1, 3.1),
            "sleep_slope": random.uniform(-0.62, -0.18),
            "mood_slope": random.uniform(-0.55, -0.14),
            "risk": random.uniform(55.0, 88.0),
            "trend": random.uniform(-0.54, -0.12),
        }
    if case == "stable":
        return {
            "sleep_avg_3": random.uniform(6.2, 7.7),
            "mood_avg_3": random.uniform(3.1, 4.6),
            "sleep_slope": random.uniform(-0.07, 0.07),
            "mood_slope": random.uniform(-0.07, 0.07),
            "risk": random.uniform(42.0, 72.0),
            "trend": random.uniform(-0.07, 0.07),
        }
    if case == "improving":
        return {
            "sleep_avg_3": random.uniform(5.2, 7.6),
            "mood_avg_3": random.uniform(2.5, 4.8),
            "sleep_slope": random.uniform(0.12, 0.56),
            "mood_slope": random.uniform(0.12, 0.56),
            "risk": random.uniform(28.0, 62.0),
            "trend": random.uniform(0.12, 0.56),
        }
    if case == "low_sleep":
        return {
            "sleep_avg_3": random.uniform(3.8, 5.1),
            "mood_avg_3": random.uniform(2.7, 4.4),
            "sleep_slope": random.uniform(-0.20, 0.10),
            "mood_slope": random.uniform(-0.14, 0.16),
            "risk": random.uniform(50.0, 80.0),
            "trend": random.uniform(-0.20, 0.05),
        }
    if case == "low_mood":
        return {
            "sleep_avg_3": random.uniform(5.8, 7.6),
            "mood_avg_3": random.uniform(1.0, 2.1),
            "sleep_slope": random.uniform(-0.10, 0.12),
            "mood_slope": random.uniform(-0.20, 0.05),
            "risk": random.uniform(46.0, 82.0),
            "trend": random.uniform(-0.22, 0.03),
        }
    return {
        "sleep_avg_3": random.uniform(4.0, 5.8),
        "mood_avg_3": random.uniform(1.0, 2.7),
        "sleep_slope": random.uniform(-0.62, -0.12),
        "mood_slope": random.uniform(-0.62, -0.12),
        "risk": random.uniform(72.0, 98.0),
        "trend": random.uniform(-0.56, -0.12),
    }


def build_starter_dataset():
    random.seed(42)
    plan = {
        "declining": 17,
        "stable": 17,
        "improving": 17,
        "low_sleep": 17,
        "low_mood": 16,
        "high_risk": 16,
    }

    rows = []
    for case, count in plan.items():
        for _ in range(count):
            sample = _build_sample(case)
            rows.append(
                {
                    "input": _format_input(sample),
                    "target": random.choice(TEMPLATES[case]),
                }
            )

    random.shuffle(rows)
    return rows


def main():
    base = Path(__file__).resolve().parent
    incoming_dir = base / "incoming"
    incoming_dir.mkdir(parents=True, exist_ok=True)
    output_path = incoming_dir / "starter_human_summaries_100.json"

    rows = build_starter_dataset()
    output_path.write_text(json.dumps(rows, indent=2), encoding="utf-8")
    print(f"Wrote {len(rows)} rows to {output_path}")


if __name__ == "__main__":
    main()