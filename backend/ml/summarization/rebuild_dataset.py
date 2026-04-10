import json
import random


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
        "Sleep and mood are trending downward, suggesting rising fatigue risk.",
        "Recent patterns show declining rest and mood, indicating increased strain.",
        "Health signals are worsening with lower sleep and mood over time.",
    ],
    "stable": [
        "Health metrics look stable with no major short-term decline.",
        "Current sleep, mood, and trend indicators are generally steady.",
        "Signals are stable overall, with balanced near-term patterns.",
    ],
    "improving": [
        "Sleep and mood are improving, showing positive recovery momentum.",
        "Recent trends suggest gradual recovery in wellbeing indicators.",
        "Key metrics are moving in a healthier direction.",
    ],
    "low_sleep": [
        "Sleep levels are low and should be prioritized for recovery.",
        "Recent data indicates persistent sleep deficit.",
        "Low sleep is the primary concern in the latest window.",
    ],
    "low_mood": [
        "Mood has remained low and may need supportive intervention.",
        "Recent mood values are consistently below target.",
        "Low mood is the dominant concern in current signals.",
    ],
    "high_risk": [
        "Overall risk is elevated with multiple declining health indicators.",
        "The profile suggests high short-term risk and requires close follow-up.",
        "Combined trends indicate a high-risk pattern.",
    ],
}


def _build_sample(case):
    if case == "declining":
        return {
            "sleep_avg_3": random.uniform(4.3, 6.1),
            "mood_avg_3": random.uniform(1.2, 3.2),
            "sleep_slope": random.uniform(-0.6, -0.18),
            "mood_slope": random.uniform(-0.55, -0.15),
            "risk": random.uniform(55.0, 88.0),
            "trend": random.uniform(-0.52, -0.12),
        }
    if case == "stable":
        return {
            "sleep_avg_3": random.uniform(6.2, 7.6),
            "mood_avg_3": random.uniform(3.1, 4.5),
            "sleep_slope": random.uniform(-0.08, 0.08),
            "mood_slope": random.uniform(-0.08, 0.08),
            "risk": random.uniform(45.0, 72.0),
            "trend": random.uniform(-0.08, 0.08),
        }
    if case == "improving":
        return {
            "sleep_avg_3": random.uniform(5.4, 7.6),
            "mood_avg_3": random.uniform(2.6, 4.7),
            "sleep_slope": random.uniform(0.12, 0.55),
            "mood_slope": random.uniform(0.12, 0.55),
            "risk": random.uniform(28.0, 62.0),
            "trend": random.uniform(0.12, 0.55),
        }
    if case == "low_sleep":
        return {
            "sleep_avg_3": random.uniform(3.8, 5.1),
            "mood_avg_3": random.uniform(2.8, 4.4),
            "sleep_slope": random.uniform(-0.2, 0.1),
            "mood_slope": random.uniform(-0.15, 0.15),
            "risk": random.uniform(50.0, 80.0),
            "trend": random.uniform(-0.22, 0.05),
        }
    if case == "low_mood":
        return {
            "sleep_avg_3": random.uniform(5.8, 7.5),
            "mood_avg_3": random.uniform(1.0, 2.1),
            "sleep_slope": random.uniform(-0.12, 0.12),
            "mood_slope": random.uniform(-0.2, 0.05),
            "risk": random.uniform(46.0, 82.0),
            "trend": random.uniform(-0.25, 0.02),
        }
    return {
        "sleep_avg_3": random.uniform(4.0, 5.8),
        "mood_avg_3": random.uniform(1.0, 2.8),
        "sleep_slope": random.uniform(-0.6, -0.12),
        "mood_slope": random.uniform(-0.6, -0.12),
        "risk": random.uniform(72.0, 98.0),
        "trend": random.uniform(-0.55, -0.12),
    }


def build_dataset(samples_per_case=240):
    dataset = []
    ordered_cases = ["declining", "stable", "improving", "low_sleep", "low_mood", "high_risk"]
    for case in ordered_cases:
        for _ in range(samples_per_case):
            sample = _build_sample(case)
            dataset.append(
                {
                    "input": _format_input(sample),
                    "target": random.choice(TEMPLATES[case]),
                }
            )
    random.shuffle(dataset)
    return dataset


def main():
    dataset = build_dataset(samples_per_case=240)
    with open("summarization_dataset.json", "w", encoding="utf-8") as file_handle:
        json.dump(dataset, file_handle, indent=2)
    print(f"Dataset regenerated with {len(dataset)} samples")


if __name__ == "__main__":
    main()