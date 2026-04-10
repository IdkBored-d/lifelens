import json

from fake_data_generator import generate_fake_logs
from label_generator import generate_summary_label


def compute_slope(values):
    n = len(values)
    x = list(range(n))
    x_mean = sum(x) / n
    y_mean = sum(values) / n

    num = sum((xi - x_mean) * (yi - y_mean) for xi, yi in zip(x, values))
    den = sum((xi - x_mean) ** 2 for xi in x)

    return num / den if den != 0 else 0


def extract_features(logs):
    return {
        "sleep_avg": sum(logs["sleep"]) / len(logs["sleep"]),
        "mood_avg": sum(logs["mood"]) / len(logs["mood"]),
        "activity_avg": sum(logs["activity"]) / len(logs["activity"]),
        "sleep_slope": compute_slope(logs["sleep"]),
        "mood_slope": compute_slope(logs["mood"]),
    }


def build_dataset(sample_count=100):
    dataset = []

    for _ in range(sample_count):
        logs = generate_fake_logs()
        features = extract_features(logs)
        label = generate_summary_label(features)

        dataset.append({
            "input": logs,
            "features": features,
            "target": label,
        })

    return dataset


def main():
    dataset = build_dataset()

    with open("summarization_dataset.json", "w", encoding="utf-8") as file_handle:
        json.dump(dataset, file_handle, indent=2)

    print("Dataset created with", len(dataset), "samples")


if __name__ == "__main__":
    main()
