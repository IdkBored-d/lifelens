from services.intelligence import analyze_logs


CASES = [
    {
        "name": "declining_high_risk",
        "sleep": [6, 6, 5, 5, 4, 4, 4],
        "mood": [3, 3, 2, 2, 1, 1, 1],
        "exercise": [1, 1, 0, 0, 0, 0, 0],
        "symptom_count": [0, 1, 1, 1, 2, 2, 3],
    },
    {
        "name": "declining_moderate",
        "sleep": [7, 7, 6, 6, 6, 6, 6],
        "mood": [4, 4, 4, 4, 3, 3, 3],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [0, 0, 1, 1, 1, 1, 2],
    },
    {
        "name": "stable_good",
        "sleep": [7, 7, 7, 7, 7, 7, 7],
        "mood": [4, 4, 4, 4, 4, 4, 4],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [0, 0, 0, 0, 0, 0, 0],
    },
    {
        "name": "improving",
        "sleep": [5, 5, 5, 6, 6, 6, 7],
        "mood": [2, 2, 2, 3, 3, 3, 4],
        "exercise": [0, 0, 0, 1, 1, 1, 1],
        "symptom_count": [3, 3, 2, 2, 1, 1, 0],
    },
    {
        "name": "sleep_low_only",
        "sleep": [5, 5, 5, 5, 5, 5, 5],
        "mood": [4, 4, 4, 4, 4, 4, 4],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [1, 1, 1, 1, 1, 1, 1],
    },
    {
        "name": "mood_low_only",
        "sleep": [7, 7, 7, 7, 7, 7, 7],
        "mood": [2, 2, 2, 2, 2, 2, 2],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [1, 1, 1, 1, 1, 1, 1],
    },
    {
        "name": "inactive_only",
        "sleep": [7, 7, 7, 7, 7, 7, 7],
        "mood": [4, 4, 4, 4, 4, 4, 4],
        "exercise": [0, 0, 0, 0, 0, 0, 0],
        "symptom_count": [0, 0, 0, 0, 1, 1, 1],
    },
    {
        "name": "volatile_mood",
        "sleep": [6, 7, 6, 7, 6, 7, 6],
        "mood": [1, 5, 1, 5, 1, 5, 1],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [1, 1, 1, 1, 1, 1, 1],
    },
    {
        "name": "high_symptoms",
        "sleep": [7, 6, 6, 6, 6, 6, 6],
        "mood": [3, 3, 3, 3, 3, 3, 3],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [1, 2, 3, 3, 3, 3, 3],
    },
    {
        "name": "recovering_slow",
        "sleep": [5, 5, 5, 5, 6, 6, 6],
        "mood": [2, 2, 2, 2, 3, 3, 3],
        "exercise": [0, 0, 0, 1, 1, 1, 1],
        "symptom_count": [3, 3, 3, 2, 2, 1, 1],
    },
    {
        "name": "edge_best_case",
        "sleep": [8, 8, 8, 8, 8, 8, 8],
        "mood": [5, 5, 5, 5, 5, 5, 5],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [0, 0, 0, 0, 0, 0, 0],
    },
    {
        "name": "edge_neutral",
        "sleep": [6, 6, 6, 6, 6, 6, 6],
        "mood": [3, 3, 3, 3, 3, 3, 3],
        "exercise": [1, 1, 1, 1, 1, 1, 1],
        "symptom_count": [0, 0, 0, 0, 0, 0, 0],
    },
]


for case in CASES:
    result = analyze_logs(case)
    print(f"{case['name']}: {result.message}")
