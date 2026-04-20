import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

enum HealthImportSource { appleHealth, androidHealth }

extension HealthImportSourceX on HealthImportSource {
  String get label {
    switch (this) {
      case HealthImportSource.appleHealth:
        return 'Apple Health';
      case HealthImportSource.androidHealth:
        return 'Android Health';
    }
  }
}

class HealthSnapshot {
  const HealthSnapshot({
    required this.source,
    required this.capturedAt,
    this.heartRate,
    this.heartRateUnit,
    this.weight,
    this.weightUnit,
    this.height,
    this.heightUnit,
    this.sleepHours,
    this.workoutSummary,
    this.workoutCount14d,
  });

  final String source;
  final DateTime capturedAt;
  final double? heartRate;
  final String? heartRateUnit;
  final double? weight;
  final String? weightUnit;
  final double? height;
  final String? heightUnit;
  final double? sleepHours;
  final String? workoutSummary;
  final int? workoutCount14d;

  bool get hasAnyData =>
      heartRate != null ||
      weight != null ||
      height != null ||
      sleepHours != null ||
      (workoutCount14d != null && workoutCount14d! > 0) ||
      (workoutSummary != null && workoutSummary!.isNotEmpty);

  Map<String, dynamic> toFirestore() {
    return {
      'source': source,
      'capturedAt': capturedAt.toIso8601String(),
      'heartRate': heartRate,
      'heartRateUnit': heartRateUnit,
      'weight': weight,
      'weightUnit': weightUnit,
      'height': height,
      'heightUnit': heightUnit,
      'sleepHours': sleepHours,
      'sleepUnit': sleepHours == null ? null : 'hours',
      'workoutSummary': workoutSummary,
      'workoutCount14d': workoutCount14d,
    };
  }
}

class HealthService {
  final Health _health = Health();

  static const Duration _authorizationTimeout = Duration(seconds: 20);
  static const Duration _queryTimeout = Duration(seconds: 8);

  Future<HealthSnapshot> fetchSnapshot({HealthImportSource? source}) async {
    if (kIsWeb) {
      throw Exception('This feature is not available on this device.');
    }

    final resolvedSource = source ?? _defaultSourceForPlatform();
    _ensureSourceSupportedOnPlatform(resolvedSource);

    await _health.configure();

    if (resolvedSource == HealthImportSource.androidHealth) {
      final available = await _ensureAndroidHealthConnectAvailable();
      if (!available) {
        throw Exception(
          'Android Health Connect is not available. Install or update Health Connect and try again.',
        );
      }
    }

    const coreTypes = [
      HealthDataType.HEART_RATE,
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
    ];

    const optionalTypes = [HealthDataType.SLEEP_ASLEEP, HealthDataType.WORKOUT];

    const types = [...coreTypes, ...optionalTypes];

    final permissions = List<HealthDataAccess>.filled(
      types.length,
      HealthDataAccess.READ,
    );

    final granted = await _health
        .requestAuthorization(types, permissions: permissions)
        .timeout(_authorizationTimeout);

    if (!granted) {
      throw Exception(
        'Permission was not granted. Allow health permissions to import your data.',
      );
    }

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 14));

    final heartRatePoints = await _readType(
      type: HealthDataType.HEART_RATE,
      start: start,
      end: now,
    );
    final weightPoints = await _readType(
      type: HealthDataType.WEIGHT,
      start: start,
      end: now,
    );
    final heightPoints = await _readType(
      type: HealthDataType.HEIGHT,
      start: start,
      end: now,
    );
    final sleepPoints = await _readType(
      type: HealthDataType.SLEEP_ASLEEP,
      start: start,
      end: now,
    );
    final workoutPoints = await _readType(
      type: HealthDataType.WORKOUT,
      start: start,
      end: now,
    );

    final points = [
      ...heartRatePoints,
      ...weightPoints,
      ...heightPoints,
      ...sleepPoints,
      ...workoutPoints,
    ];
    final deduped = _health.removeDuplicates(points);

    final heartRatePoint = _latestPoint(deduped, HealthDataType.HEART_RATE);
    final weightPoint = _latestPoint(deduped, HealthDataType.WEIGHT);
    final heightPoint = _latestPoint(deduped, HealthDataType.HEIGHT);
    final workoutPoint = _latestPoint(deduped, HealthDataType.WORKOUT);
    final sleepHours = _recentSleepHours(deduped, now);
    final workoutCount14d = _workoutCount(deduped);

    final snapshot = HealthSnapshot(
      source: resolvedSource.label,
      capturedAt: now,
      heartRate: _numericValue(heartRatePoint),
      heartRateUnit: heartRatePoint?.unitString,
      weight: _numericValue(weightPoint),
      weightUnit: weightPoint?.unitString,
      height: _numericValue(heightPoint),
      heightUnit: heightPoint?.unitString,
      sleepHours: sleepHours,
      workoutSummary: _workoutSummary(workoutPoint),
      workoutCount14d: workoutCount14d,
    );

    if (!snapshot.hasAnyData) {
      throw Exception('No recent data was found.');
    }

    return snapshot;
  }

  Future<bool> _ensureAndroidHealthConnectAvailable() async {
    final available = await _health.isHealthConnectAvailable();
    if (available) {
      return true;
    }

    // Attempt to open install/update flow when supported by the plugin.
    try {
      final dynamic healthDynamic = _health;
      await healthDynamic.installHealthConnect();
    } catch (_) {
      // Keep fallback behavior below.
    }

    final afterAttempt = await _health.isHealthConnectAvailable();
    return afterAttempt;
  }

  HealthImportSource _defaultSourceForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return HealthImportSource.appleHealth;
      case TargetPlatform.android:
        return HealthImportSource.androidHealth;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw Exception('This feature is not available on this device.');
    }
  }

  void _ensureSourceSupportedOnPlatform(HealthImportSource source) {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        source != HealthImportSource.appleHealth) {
      throw Exception('Android Health is only available on Android devices.');
    }

    if (defaultTargetPlatform == TargetPlatform.android &&
        source != HealthImportSource.androidHealth) {
      throw Exception('Apple Health is only available on iPhone devices.');
    }
  }

  Future<List<HealthDataPoint>> _readType({
    required HealthDataType type,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final points = await _health
          .getHealthDataFromTypes(types: [type], startTime: start, endTime: end)
          .timeout(_queryTimeout);
      return _health.removeDuplicates(points);
    } catch (_) {
      return const [];
    }
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

  int _workoutCount(List<HealthDataPoint> points) {
    return points.where((point) => point.type == HealthDataType.WORKOUT).length;
  }
}
