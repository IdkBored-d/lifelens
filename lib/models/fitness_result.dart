import 'escalation_level.dart';

/// Raw input features for the fitness MLP.
/// Field names match the training pipeline's feature list exactly:
/// ['age', 'bmi', 'heart_rate', 'sleep_hours', 'smokes',
///  'nutrition_quality', 'activity_index', 'gender_M']
class FitnessFeatures {
  final double age;
  final double bmi;
  final double heartRate;
  final double sleepHours;
  final double smokes;           // 1.0 = smoker, 0.0 = non-smoker
  final double nutritionQuality; // domain-specific scale from HealthKit/Health Connect
  final double activityIndex;    // domain-specific scale from HealthKit/Health Connect
  final double genderM;          // 1.0 = male, 0.0 = otherwise

  const FitnessFeatures({
    required this.age,
    required this.bmi,
    required this.heartRate,
    required this.sleepHours,
    required this.smokes,
    required this.nutritionQuality,
    required this.activityIndex,
    required this.genderM,
  });

  /// Convert to ordered float list matching model input order.
  List<double> toList() => [
    age, bmi, heartRate, sleepHours, smokes,
    nutritionQuality, activityIndex, genderM,
  ];

  /// Whether any required health fields appear stale / missing.
  bool get hasStaleData =>
      heartRate <= 0 || sleepHours <= 0 || activityIndex <= 0;
}

/// Raw output from Fitness MLP inference.
class FitnessMlpResult {
  final bool isFit;
  final double fitProbability;    // P(is_fit = 1), range 0–1
  final bool confidenceOk;
  final EscalationLevel escalation;
  final String reason;

  const FitnessMlpResult({
    required this.isFit,
    required this.fitProbability,
    required this.confidenceOk,
    required this.escalation,
    required this.reason,
  });
}

/// Full result stored in ISAR and surfaced to the UI.
class FitnessPipelineResult {
  /// Normalised fitness score 0–100 derived from fitProbability.
  /// Stored per-day and used for longitudinal self-comparison.
  final double fitnessScore;

  final bool isFit;
  final bool confidenceOk;

  /// Timestamp of the health data used (not the inference time).
  final DateTime healthDataTimestamp;

  /// Timestamp of when inference was run.
  final DateTime inferenceTimestamp;

  /// True if the user's health data was flagged as potentially stale.
  final bool dataFreshnessFlagged;

  const FitnessPipelineResult({
    required this.fitnessScore,
    required this.isFit,
    required this.confidenceOk,
    required this.healthDataTimestamp,
    required this.inferenceTimestamp,
    this.dataFreshnessFlagged = false,
  });
}
