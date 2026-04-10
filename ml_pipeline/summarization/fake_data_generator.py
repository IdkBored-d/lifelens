import random


def generate_fake_logs():
    return {
        "sleep": [round(random.uniform(4, 8), 2) for _ in range(7)],
        "mood": [round(random.uniform(1, 5), 2) for _ in range(7)],
        "activity": [round(random.uniform(0, 1), 2) for _ in range(7)],
        "symptom_count": [random.randint(0, 3) for _ in range(7)],
    }