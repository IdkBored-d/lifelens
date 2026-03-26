import 'package:isar/isar.dart';

part 'fitness_entry.g.dart';

/// ISAR collection for daily fitness scoring results.
/// Written by FitnessPipelineService.
/// One entry per inference run (may be multiple per day if user manually triggers).
/// The EOD pipeline uses the most recent entry per day for trend calculations.
@Collection()
class FitnessEntry {
  Id id = Isar.autoIncrement;

  /// ISO 8601 date string of this entry.
  @Index()
  late String date;

  /// Normalised fitness score 0–100 (derived from MLP fitProbability × 100).
  late double fitnessScore;

  /// Raw P(is_fit=1) from MLP predict_proba. Range 0–1.
  late double fitProbability;

  /// Binary fit/not-fit classification from the MLP.
  late bool isFit;

  /// Whether the MLP's confidence passed the threshold (currently 0.70).
  late bool confidenceOk;

  /// Whether health data was flagged as stale or incomplete.
  late bool dataFreshnessFlagged;

  // ── Raw input features (stored for debugging + future retraining) ─────────

  late double age;
  late double bmi;
  late double heartRate;
  late double sleepHours;
  late bool   smokes;
  late double nutritionQuality;
  late double activityIndex;
  late bool   isMale;

  /// Timestamp of the health data used (from HealthKit / Health Connect).
  late DateTime healthDataTimestamp;

  /// Timestamp of when inference was run.
  @Index()
  late DateTime inferenceTimestamp;
}
