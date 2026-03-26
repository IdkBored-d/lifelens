import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class HealthSnapshot {
  const HealthSnapshot({
    required this.source,
    required this.capturedAt,
    this.heartRate,
    this.heartRateUnit,
    this.weight,
    this.weightUnit,
    this.sleepHours,
    this.workoutSummary,
  });

  final String source;
  final DateTime capturedAt;
  final double? heartRate;
  final String? heartRateUnit;
  final double? weight;
  final String? weightUnit;
  final double? sleepHours;
  final String? workoutSummary;

  bool get hasAnyData =>
      heartRate != null ||
      weight != null ||
      sleepHours != null ||
      (workoutSummary != null && workoutSummary!.isNotEmpty);

  Map<String, dynamic> toFirestore() {
    return {
      'source': source,
      'capturedAt': capturedAt.toIso8601String(),
      'heartRate': heartRate,
      'heartRateUnit': heartRateUnit,
      'weight': weight,
      'weightUnit': weightUnit,
      'sleepHours': sleepHours,
      'sleepUnit': sleepHours == null ? null : 'hours',
      'workoutSummary': workoutSummary,
    };
  }
}

class HealthService {
  final Health _health = Health();

  Future<HealthSnapshot> fetchSnapshot() async {
    if (kIsWeb) {
      throw Exception('This feature is not available on this device.');
    }

    await _health.configure();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final available = await _health.isHealthConnectAvailable();
      if (!available) {
        throw Exception('Data import is not available on this device yet.');
      }
    }

    const types = [
      HealthDataType.HEART_RATE,
      HealthDataType.WEIGHT,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WORKOUT,
    ];

    final permissions = List<HealthDataAccess>.filled(
      types.length,
      HealthDataAccess.READ,
    );

    final granted = await _health.requestAuthorization(
      types,
      permissions: permissions,
    );

    if (!granted) {
      throw Exception('Permission is needed to import data.');
    }

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 14));

    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: now,
    );

    final deduped = _health.removeDuplicates(points);

    final heartRatePoint = _latestPoint(deduped, HealthDataType.HEART_RATE);
    final weightPoint = _latestPoint(deduped, HealthDataType.WEIGHT);
    final workoutPoint = _latestPoint(deduped, HealthDataType.WORKOUT);
    final sleepHours = _recentSleepHours(deduped, now);

    final snapshot = HealthSnapshot(
      source: 'Phone',
      capturedAt: now,
      heartRate: _numericValue(heartRatePoint),
      heartRateUnit: heartRatePoint?.unitString,
      weight: _numericValue(weightPoint),
      weightUnit: weightPoint?.unitString,
      sleepHours: sleepHours,
      workoutSummary: _workoutSummary(workoutPoint),
    );

    if (!snapshot.hasAnyData) {
      throw Exception('No recent data was found.');
    }

    return snapshot;
  }

  HealthDataPoint? _latestPoint(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    final matches = points.where((point) => point.type == type).toList()
      ..sort((a, b) => b.dateTo.compareTo(a.dateTo));

    if (matches.isEmpty) {
      return null;
    }

    return matches.first;
  }

  double? _numericValue(HealthDataPoint? point) {
    if (point == null || point.value is! NumericHealthValue) {
      return null;
    }

    final value = (point.value as NumericHealthValue).numericValue;
    return value.toDouble();
  }

  double? _recentSleepHours(List<HealthDataPoint> points, DateTime now) {
    final cutoff = now.subtract(const Duration(days: 1));
    final relevantPoints = points.where(
      (point) =>
          point.type == HealthDataType.SLEEP_ASLEEP &&
          point.dateTo.isAfter(cutoff),
    );

    var totalMinutes = 0;
    for (final point in relevantPoints) {
      totalMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
    }

    if (totalMinutes == 0) {
      return null;
    }

    return totalMinutes / 60;
  }

  String? _workoutSummary(HealthDataPoint? point) {
    if (point == null || point.value is! WorkoutHealthValue) {
      return null;
    }

    final workout = point.value as WorkoutHealthValue;
    final durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes;
    final activity = workout.workoutActivityType.name.toLowerCase().replaceAll(
      '_',
      ' ',
    );

    if (durationMinutes <= 0) {
      return activity;
    }

    return '$activity - $durationMinutes min';
  }
}