import '../database/fitness_entry.dart';
import '../database/isar_service.dart';
import '../models/fitness_result.dart';
import 'confidence_manager.dart';
import 'fitness_mlp_service.dart';

/// Raw health metrics from HealthKit / Health Connect.
/// Populated via platform channel in the Flutter app layer.
class RawHealthData {
  final double age;
  final double weightKg;
  final double heightCm;
  final double restingHeartRate;
  final double sleepHours;
  final bool smokes;
  final double nutritionQuality;
  final double activityIndex;
  final bool isMale;
  final DateTime timestamp;

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

class FitnessPipelineService {
  FitnessPipelineService({
    required FitnessMlpService mlp,
    required ConfidenceManager confidence,
    required Future<RawHealthData?> Function() fetchHealthData,
  }) : _mlp = mlp,
       _confidence = confidence,
       _fetchHealthData = fetchHealthData;

  final FitnessMlpService _mlp;
  final ConfidenceManager _confidence;
  final Future<RawHealthData?> Function() _fetchHealthData;

  static const Duration _staleThreshold = Duration(hours: 6);

  Future<FitnessPipelineResult?> score({bool forceRun = false}) async {
    final rawData = await _fetchHealthData();
    if (rawData == null) {
      return null;
    }

    final dataAge = DateTime.now().difference(rawData.timestamp);
    final isStale = dataAge > _staleThreshold;
    final features = buildFeatures(rawData);
    final probabilities = await _mlp.predict(features);
    final mlpResult = _confidence.evaluateFitness(probabilities);
    final fitnessScore = normaliseScore(mlpResult.fitProbability);

    final result = FitnessPipelineResult(
      fitnessScore: fitnessScore,
      isFit: mlpResult.isFit,
      confidenceOk: mlpResult.confidenceOk,
      healthDataTimestamp: rawData.timestamp,
      inferenceTimestamp: DateTime.now(),
      dataFreshnessFlagged: isStale || !mlpResult.confidenceOk,
    );

    final bmi = _calculateBmi(
      weightKg: rawData.weightKg,
      heightCm: rawData.heightCm,
    );
    final fitnessEntry = FitnessEntry()
      ..date = rawData.timestamp.toIso8601String().split('T').first
      ..fitnessScore = result.fitnessScore
      ..fitProbability = mlpResult.fitProbability
      ..isFit = result.isFit
      ..confidenceOk = result.confidenceOk
      ..dataFreshnessFlagged = result.dataFreshnessFlagged
      ..age = rawData.age
      ..bmi = bmi
      ..heartRate = rawData.restingHeartRate
      ..sleepHours = rawData.sleepHours
      ..smokes = rawData.smokes
      ..nutritionQuality = rawData.nutritionQuality
      ..activityIndex = rawData.activityIndex
      ..isMale = rawData.isMale
      ..healthDataTimestamp = result.healthDataTimestamp
      ..inferenceTimestamp = result.inferenceTimestamp;

    await IsarService.instance.writeFitnessEntry(fitnessEntry);
    return result;
  }

  FitnessFeatures buildFeatures(RawHealthData data) {
    return FitnessFeatures(
      age: data.age,
      bmi: _calculateBmi(weightKg: data.weightKg, heightCm: data.heightCm),
      heartRate: data.restingHeartRate,
      sleepHours: data.sleepHours,
      smokes: data.smokes ? 1.0 : 0.0,
      nutritionQuality: data.nutritionQuality,
      activityIndex: data.activityIndex,
      genderM: data.isMale ? 1.0 : 0.0,
    );
  }

  double normaliseScore(double fitProbability) {
    return (fitProbability * 100).clamp(0.0, 100.0);
  }

  double weeklyAverage(List<FitnessPipelineResult> lastWeek) {
    if (lastWeek.isEmpty) {
      return 0.0;
    }
    final total = lastWeek.fold<double>(
      0.0,
      (value, item) => value + item.fitnessScore,
    );
    return total / lastWeek.length;
  }

  String fitnessTrend(List<double> dailyScores) {
    if (dailyScores.length < 3) {
      return 'stable';
    }

    final recent = dailyScores.take(3).toList(growable: false);
    final older = dailyScores.skip(3).take(4).toList(growable: false);
    if (older.isEmpty) {
      return 'stable';
    }

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    if (recentAvg > olderAvg + 3) {
      return 'upward';
    }
    if (recentAvg < olderAvg - 3) {
      return 'downward';
    }
    return 'stable';
  }

  double _calculateBmi({required double weightKg, required double heightCm}) {
    final heightM = heightCm / 100.0;
    if (heightM <= 0) {
      return 22.0;
    }
    return weightKg / (heightM * heightM);
  }
}
