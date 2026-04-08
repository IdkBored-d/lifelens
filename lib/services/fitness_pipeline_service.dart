import '../models/fitness_result.dart';
import '../models/escalation_level.dart';
import 'confidence_manager.dart';
import 'fitness_mlp_service.dart';
import 'model_lifecycle_service.dart';
import '../database/isar_service.dart';
import '../database/fitness_entry.dart';

// import '../database/isar_service.dart';

/// Orchestrates USE CASE 3: Background fitness scoring.
///
/// Runs when resource usage is low or when the user manually requests it.
/// Health data is gathered from Apple HealthKit (iOS) or
/// Android Health Connect (Android) via platform channels.
///
/// Flow:
///   1. Gather health features from platform health APIs
///   2. Check data freshness — flag stale data and optionally prompt user
///   3. Run Fitness MLP
///   4. Confidence check — flag uncertain results
///   5. WRITE to ISAR database
///   (No quick-tracking file for fitness — fitness score is read directly
///    from ISAR by the EOD pipeline)
///
/// NOTE: Low confidence does NOT escalate to Gemma2b or Gemini.
///       Gemma2b cannot improve a numerical fitness calculation.
///       Low confidence → flag data freshness to user.
class FitnessPipelineService {
  final FitnessMlpService  _mlp;
  final ConfidenceManager  _confidence;

  /// Platform channel callback to fetch health data.
  /// Returns raw health metrics or null if unavailable.
  /// Injected from the Flutter app layer (platform-specific).
  final Future<RawHealthData?> Function() _fetchHealthData;

  /// Maximum age of health data before it is considered stale.
  static const Duration _staleThreshold = Duration(hours: 6);

  FitnessPipelineService({
    required FitnessMlpService mlp,
    required ConfidenceManager confidence,
    required Future<RawHealthData?> Function() fetchHealthData,
  })  : _mlp          = mlp,
        _confidence   = confidence,
        _fetchHealthData = fetchHealthData;

  // ── Main entry point ────────────────────────────────────────────────────────

  /// Run fitness scoring.
  ///
  /// [forceRun] bypasses the resource-usage check (used for manual user requests).
  Future<FitnessPipelineResult?> score({bool forceRun = false}) async {
    // ── STEP 1: Gather health data ─────────────────────────────────────────
    final rawData = await _fetchHealthData();
    if (rawData == null) {
      // Health permissions not granted or data unavailable
      return null;
    }

    // ── STEP 2: Freshness check ────────────────────────────────────────────
    final dataAge      = DateTime.now().difference(rawData.timestamp);
    final isStale      = dataAge > _staleThreshold;

    // ── STEP 3: Build features ─────────────────────────────────────────────
    final features = _buildFeatures(rawData);

    // ── STEP 4: Run MLP ───────────────────────────────────────────────────
    await ModelLifecycleService.instance.ensureLoaded([ModelType.fitnessMlp]);
    final proba     = await _mlp.predict(features);
    final mlpResult = _confidence.evaluateFitness(proba);

    // ── STEP 5: Compute normalised fitness score (0–100) ──────────────────
    final fitnessScore = _normaliseScore(mlpResult.fitProbability);

    final result = FitnessPipelineResult(
      fitnessScore:          fitnessScore,
      isFit:                 mlpResult.isFit,
      confidenceOk:          mlpResult.confidenceOk,
      healthDataTimestamp:   rawData.timestamp,
      inferenceTimestamp:    DateTime.now(),
      dataFreshnessFlagged:  isStale || !mlpResult.confidenceOk,
    );

// ── STEP 6: WRITE TO ISAR (source of truth) ───────────────────────────
    final fitnessEntry = FitnessEntry()
      ..date                  = rawData.timestamp.toIso8601String().split('T').first
      ..fitnessScore          = result.fitnessScore
      ..fitProbability        = mlpResult.fitProbability
      ..isFit                 = result.isFit
      ..confidenceOk          = result.confidenceOk
      ..dataFreshnessFlagged  = result.dataFreshnessFlagged
      ..age                   = rawData.age
      ..bmi                   = (rawData.heightCm > 0) ? rawData.weightKg / ((rawData.heightCm / 100) * (rawData.heightCm / 100)) : 22.0
      ..heartRate             = rawData.restingHeartRate
      ..sleepHours            = rawData.sleepHours
      ..smokes                = rawData.smokes
      ..nutritionQuality      = rawData.nutritionQuality
      ..activityIndex         = rawData.activityIndex
      ..isMale                = rawData.isMale
      ..healthDataTimestamp   = result.healthDataTimestamp
      ..inferenceTimestamp    = result.inferenceTimestamp;

    await IsarService.instance.writeFitnessEntry(fitnessEntry);

    return result;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  FitnessFeatures _buildFeatures(RawHealthData data) {
    final weightKg = data.weightKg;
    final heightM  = data.heightCm / 100.0;
    final bmi      = (heightM > 0) ? weightKg / (heightM * heightM) : 22.0;

    return FitnessFeatures(
      age:              data.age,
      bmi:              bmi,
      heartRate:        data.restingHeartRate,
      sleepHours:       data.sleepHours,
      smokes:           data.smokes ? 1.0 : 0.0,
      nutritionQuality: data.nutritionQuality,
      activityIndex:    data.activityIndex,
      genderM:          data.isMale ? 1.0 : 0.0,
    );
  }

  /// Normalise P(is_fit=1) to a 0–100 fitness score.
  /// This allows longitudinal self-comparison rather than binary pass/fail.
  double _normaliseScore(double fitProbability) =>
      (fitProbability * 100).clamp(0.0, 100.0);

  /// Compute 7-day average fitness score from a list of past results.
  /// Used by the EOD pipeline.
  double weeklyAverage(List<FitnessPipelineResult> lastWeek) {
    if (lastWeek.isEmpty) return 0.0;
    final sum = lastWeek.fold(0.0, (acc, r) => acc + r.fitnessScore);
    return sum / lastWeek.length;
  }

  /// Determine fitness trend from a list of daily scores.
  String fitnessTrend(List<double> dailyScores) {
    if (dailyScores.length < 3) return 'stable';
    final recent = dailyScores.take(3).toList();
    final older  = dailyScores.skip(3).take(4).toList();
    if (older.isEmpty) return 'stable';
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg  = older.reduce((a, b) => a + b) / older.length;
    if (recentAvg > olderAvg + 3) return 'upward';
    if (recentAvg < olderAvg - 3) return 'downward';
    return 'stable';
  }
}

/// Raw health metrics from HealthKit / Health Connect.
/// Populated via platform channel in the Flutter app layer.
class RawHealthData {
  final double age;
  final double weightKg;
  final double heightCm;
  final double restingHeartRate;
  final double sleepHours;
  final bool   smokes;
  final double nutritionQuality;  // 0–10 scale, derived from HealthKit/Health Connect
  final double activityIndex;     // 0–10 scale, derived from step count + active minutes
  final bool   isMale;
  final DateTime timestamp;       // when this data was last recorded by the health platform

  const RawHealthData({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.restingHeartRate,
    required this.sleepHours,
    required this.smokes,
    required this.nutritionQuality,
    required this.activityIndex,
    required this.isMale,
    required this.timestamp,
  });
}
