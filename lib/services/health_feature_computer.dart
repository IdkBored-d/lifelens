import 'dart:math' show sqrt, max;

import '../database/mood_entry.dart';
import '../database/symptom_entry.dart';

/// Computes the 25 numerical health features used as input to
/// [HealthSummaryModelService] and [HealthSuggestionsModelService].
///
/// Ported from `backend/services/intelligence.py` → `compute_features()`.
///
/// Feature vector order (fixed — must match model training):
///   [0]  sleep_avg_3
///   [1]  sleep_avg_7
///   [2]  sleep_avg_14
///   [3]  mood_avg_3
///   [4]  mood_avg_7
///   [5]  mood_avg_14
///   [6]  exercise_avg_3
///   [7]  exercise_avg_7
///   [8]  exercise_avg_14
///   [9]  inactive_ratio_7
///   [10] sleep_slope_7
///   [11] mood_slope_7
///   [12] exercise_slope_7
///   [13] symptom_slope_7
///   [14] sleep_variance_7
///   [15] mood_variance_7
///   [16] sleep_volatility_7
///   [17] mood_volatility_7
///   [18] low_sleep_streak
///   [19] low_mood_streak
///   [20] recovery_rate
///   [21] sleep_drop_vs_14
///   [22] mood_drop_vs_14
///   [23] interaction_sleep_inactive_symptom
///   [24] interaction_low_sleep_low_mood
class HealthFeatureComputer {
  const HealthFeatureComputer();

  /// Total number of base features. Must match ONNX model input dimension.
  static const int featureCount = 25;

  /// Compute the 25-feature vector from available app data.
  ///
  /// [recentMoods]   last 14 mood entries, newest first.
  /// [fitnessScores] last 14 fitness scores (0–100), newest first.
  /// [activeSymptoms] currently active symptom entries.
  /// [sleepHours]    optional 14-day sleep history (hours/night), newest first.
  ///                 Defaults to 7.0 per day when not available.
  List<double> compute({
    required List<MoodEntry>    recentMoods,
    required List<double>       fitnessScores,
    required List<SymptomEntry> activeSymptoms,
    List<double>?               sleepHours,
  }) {
    // ── Build daily value arrays ───────────────────────────────────────────
    final mood     = recentMoods.map((e) => _moodScore(e.resolvedMood)).toList();
    // Fitness score [0–100] → binary active: >50 = 1.0, else 0.0
    final exercise = fitnessScores.map((s) => s > 50.0 ? 1.0 : 0.0).toList();
    // Use provided sleep data or fill with 7.0 (healthy default)
    final sleep    = (sleepHours != null && sleepHours.isNotEmpty)
        ? sleepHours
        : List.filled(14, 7.0);
    // Approximate daily symptom count using current active count
    final symptomCount = List.filled(7, activeSymptoms.length.toDouble());

    // ── Windowed sub-lists ─────────────────────────────────────────────────
    final sleep3   = _window(sleep,  3);
    final sleep7   = _window(sleep,  7);
    final sleep14  = _window(sleep, 14);
    final mood3    = _window(mood,   3);
    final mood7    = _window(mood,   7);
    final mood14   = _window(mood,  14);
    final ex3      = _window(exercise,  3);
    final ex7      = _window(exercise,  7);
    final ex14     = _window(exercise, 14);
    final sym7     = _window(symptomCount, 7);

    // ── Feature computation ────────────────────────────────────────────────
    final sleepAvg3  = _mean(sleep3);
    final sleepAvg7  = _mean(sleep7);
    final sleepAvg14 = _mean(sleep14);
    final moodAvg3   = _mean(mood3);
    final moodAvg7   = _mean(mood7);
    final moodAvg14  = _mean(mood14);
    final exAvg3     = _mean(ex3);
    final exAvg7     = _mean(ex7);
    final exAvg14    = _mean(ex14);

    final inactiveRatio7 = ex7.isNotEmpty ? 1.0 - exAvg7 : 0.0;

    final sleepSlope7    = _slope(sleep7);
    final moodSlope7     = _slope(mood7);
    final exerciseSlope7 = _slope(ex7);
    final symptomSlope7  = _slope(sym7);

    final sleepVariance7 = _variance(sleep7);
    final moodVariance7  = _variance(mood7);
    final sleepVol7      = sqrt(sleepVariance7);
    final moodVol7       = sqrt(moodVariance7);

    final lowSleepStreak = _streakLength(sleep7, (v) => v < 6.0).toDouble();
    final lowMoodStreak  = _streakLength(mood7,  (v) => v <= 2.0).toDouble();

    final recoveryRate = max(0.0, _slope(mood3));
    final sleepDrop14  = sleepAvg3 - sleepAvg14;
    final moodDrop14   = moodAvg3  - moodAvg14;

    final interactionSleepInactiveSymptom = (
      sleepDrop14 < -0.5 &&
      inactiveRatio7 > 0.8 &&
      symptomSlope7 > 0.0
    ) ? 1.0 : 0.0;

    final interactionLowSleepLowMood = (
      sleepAvg3 < 6.0 && moodAvg3 <= 2.0
    ) ? 1.0 : 0.0;

    return [
      sleepAvg3,                        // [0]
      sleepAvg7,                        // [1]
      sleepAvg14,                       // [2]
      moodAvg3,                         // [3]
      moodAvg7,                         // [4]
      moodAvg14,                        // [5]
      exAvg3,                           // [6]
      exAvg7,                           // [7]
      exAvg14,                          // [8]
      inactiveRatio7,                   // [9]
      sleepSlope7,                      // [10]
      moodSlope7,                       // [11]
      exerciseSlope7,                   // [12]
      symptomSlope7,                    // [13]
      sleepVariance7,                   // [14]
      moodVariance7,                    // [15]
      sleepVol7,                        // [16]
      moodVol7,                         // [17]
      lowSleepStreak,                   // [18]
      lowMoodStreak,                    // [19]
      recoveryRate,                     // [20]
      sleepDrop14,                      // [21]
      moodDrop14,                       // [22]
      interactionSleepInactiveSymptom,  // [23]
      interactionLowSleepLowMood,       // [24]
    ];
  }

  // ── Math helpers (same as EodCorrelationEngine, kept local for isolation) ─────

  List<double> _window(List<double> values, int n) {
    if (values.isEmpty) return [];
    final start = values.length > n ? values.length - n : 0;
    return values.sublist(start);
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _variance(List<double> values) {
    if (values.length < 2) return 0.0;
    final m = _mean(values);
    return values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / values.length;
  }

  double _slope(List<double> values) {
    if (values.length < 2) return 0.0;
    final n     = values.length;
    final xs    = List<double>.generate(n, (i) => i.toDouble());
    final xMean = _mean(xs);
    final yMean = _mean(values);
    double num  = 0;
    double den  = 0;
    for (int i = 0; i < n; i++) {
      num += (xs[i] - xMean) * (values[i] - yMean);
      den += (xs[i] - xMean) * (xs[i] - xMean);
    }
    return den == 0 ? 0.0 : num / den;
  }

  int _streakLength(List<double> values, bool Function(double) predicate) {
    int streak = 0;
    for (final v in values.reversed) {
      if (predicate(v)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  double _moodScore(String mood) => switch (mood.toLowerCase()) {
    'joy'      => 5.0,
    'love'     => 4.5,
    'content'  => 4.0,
    'surprise' => 3.5,
    'neutral'  => 3.0,
    'anxious'  => 2.5,
    'fear'     => 2.0,
    'sadness'  => 1.5,
    'anger'    => 1.0,
    _          => 3.0,
  };
}
