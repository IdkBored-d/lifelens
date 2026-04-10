def generate_summary_label(features):
    if features["sleep_slope"] < -0.3 and features["mood_slope"] < -0.2:
        return "Sleep and mood are declining, indicating fatigue buildup."

    if features["sleep_avg"] < 5:
        return "User is experiencing low sleep levels."

    if features["mood_avg"] < 2:
        return "Mood has been consistently low."

    return "Health metrics are stable."