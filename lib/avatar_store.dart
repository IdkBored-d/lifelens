import 'package:flutter/foundation.dart';
import 'package:lifelens/models/mini_me_companion.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarStore extends ChangeNotifier {
  static const String _bodyModelKey = 'bodyModel';
  static const String _hairModelKey = 'hairModel';
  static const String _shirtModelKey = 'shirtModel';
  static const String _bodyWidthScaleKey = 'bodyWidthScale';
  static const String _miniMeNameKey = 'miniMeName';
  static const String _hasAvatarCustomizationKey = 'hasAvatarCustomization';
  static const String _companionIdKey = 'miniMeCompanionId';
  static const String _isMiniMeHatchedKey = 'isMiniMeHatched';
  static const String _degradationLevelKey = 'miniMeDegradationLevel';
  static const String _autoBodyWidthScaleKey = 'miniMe.autoBodyWidthScale';
  static const String _trendBodyWidthScaleKey = 'miniMe.trendBodyWidthScale';
  static const String _fatigueAppearanceLevelKey =
      'miniMe.fatigueAppearanceLevel';
  static const String _healthTrendScoreKey = 'miniMe.healthTrendScore';

  String _bodyModel = miniMeCompanionPresets.first.bodyModel;
  String _hairModel = miniMeCompanionPresets.first.hairModel;
  String _shirtModel = miniMeCompanionPresets.first.shirtModel;
  double _bodyWidthScale = miniMeCompanionPresets.first.bodyWidthScale;
  String _miniMeName = 'Mini-Me';
  String _companionId = miniMeCompanionPresets.first.id;
  bool _isMiniMeHatched = false;
  double _degradationLevel = 0.0;
  double _autoBodyWidthScale = 1.0;
  double _trendBodyWidthScale = 1.0;
  double _fatigueAppearanceLevel = 0.0;
  double _healthTrendScore = 0.0;

  AvatarStore() {
    _loadFromPrefs();
  }

  String get bodyModel => _bodyModel;
  String get hairModel => _hairModel;
  String get shirtModel => _shirtModel;
  double get bodyWidthScale => _bodyWidthScale;
  double get effectiveBodyWidthScale =>
      (_bodyWidthScale * _autoBodyWidthScale * _trendBodyWidthScale)
          .clamp(0.7, 1.48)
          .toDouble();
  String get miniMeName => _miniMeName;
  String get companionId => _companionId;
  bool get isMiniMeHatched => _isMiniMeHatched;
  double get degradationLevel => _degradationLevel;
  double get fatigueAppearanceLevel => _fatigueAppearanceLevel;
  double get healthTrendScore => _healthTrendScore;
  MiniMeCompanionPreset get selectedCompanion => miniMePresetById(_companionId);

  Map<String, dynamic> toCommunityAvatarMap() {
    return {
      'bodyModel': _bodyModel,
      'hairModel': _hairModel,
      'shirtModel': _shirtModel,
      'bodyWidthScale': effectiveBodyWidthScale,
      'companionId': _companionId,
      'isHatched': _isMiniMeHatched,
      'degradationLevel': _degradationLevel,
      'miniMeName': _miniMeName,
    };
  }

  void setBodyModel(String model) {
    _bodyModel = model;
    _saveToPrefs(markCustomized: true);
    notifyListeners();
  }

  void setHairModel(String model) {
    _hairModel = model;
    _saveToPrefs(markCustomized: true);
    notifyListeners();
  }

  void setShirtModel(String model) {
    _shirtModel = model;
    _saveToPrefs(markCustomized: true);
    notifyListeners();
  }

  void setBodyWidthScale(double scale) {
    _bodyWidthScale = scale.clamp(0.72, 1.4).toDouble();
    _saveToPrefs(markCustomized: true);
    notifyListeners();
  }

  Future<void> setMiniMeName(String name) async {
    final next = name.trim();
    _miniMeName = next.isEmpty ? 'Mini-Me' : next;
    await _saveToPrefs();
    notifyListeners();
  }

  void setCompanionId(String id) {
    final preset = miniMePresetById(id);
    _companionId = preset.id;
    _bodyModel = preset.bodyModel;
    _hairModel = preset.hairModel;
    _shirtModel = preset.shirtModel;
    _bodyWidthScale = preset.bodyWidthScale;
    _saveToPrefs(markCustomized: true);
    notifyListeners();
  }

  void hatchMiniMe() {
    if (_isMiniMeHatched) return;
    _isMiniMeHatched = true;
    _saveToPrefs();
    notifyListeners();
  }

  void resetHatchState() {
    _isMiniMeHatched = false;
    _saveToPrefs();
    notifyListeners();
  }

  void setDegradationLevel(double value) {
    _degradationLevel = value.clamp(0.0, 1.0).toDouble();
    _saveToPrefs();
    notifyListeners();
  }

  void setAutoBodyWidthScale(double value) {
    _autoBodyWidthScale = value.clamp(0.82, 1.22).toDouble();
    _saveToPrefs();
    notifyListeners();
  }

  void updateAdaptiveHealthAppearance({
    required List<int> mood,
    required List<int> sleep,
    required List<int> exercise,
    required List<int> symptomCount,
  }) {
    if (mood.isEmpty || sleep.isEmpty || exercise.isEmpty) {
      return;
    }

    double average(List<int> values) {
      if (values.isEmpty) return 0;
      final total = values.fold<double>(0, (sum, value) => sum + value);
      return total / values.length;
    }

    final avgMood = average(mood);
    final avgSleep = average(sleep);
    final avgExercise = average(exercise);
    final avgSymptoms = average(symptomCount);
    final symptomDays = symptomCount.where((count) => count > 0).length;
    var consecutiveSymptomDays = 0;
    for (final count in symptomCount.reversed) {
      if (count <= 0) break;
      consecutiveSymptomDays += 1;
    }

    final moodHealth = ((avgMood - 1.0) / 4.0).clamp(0.0, 1.0);
    final sleepHealth = ((avgSleep - 4.0) / 4.0).clamp(0.0, 1.0);
    final exerciseHealth = (avgExercise / 2.0).clamp(0.0, 1.0);
    final symptomPressure = (avgSymptoms / 6.0).clamp(0.0, 1.0);
    final symptomContinuity = (consecutiveSymptomDays / 5.0).clamp(0.0, 1.0);
    final repeatedSymptomPressure = (symptomDays / 7.0).clamp(0.0, 1.0);
    final chronicSymptomPressure = symptomContinuity < 0.4
        ? 0.0
        : (symptomContinuity * 0.7 + repeatedSymptomPressure * 0.3)
              .clamp(0.0, 1.0)
              .toDouble();

    final positivePressure =
        (moodHealth * 0.44 + sleepHealth * 0.3 + exerciseHealth * 0.26).clamp(
          0.0,
          1.0,
        );
    final negativePressure =
        ((1 - moodHealth) * 0.34 +
                (1 - sleepHealth) * 0.34 +
                (1 - exerciseHealth) * 0.2 +
                symptomPressure * 0.12)
            .clamp(0.0, 1.0);

    final netTrend = (positivePressure - negativePressure).clamp(-1.0, 1.0);
    final nextTrendScore = (_healthTrendScore * 0.84 + netTrend * 0.16).clamp(
      -1.0,
      1.0,
    );

    final underRecovery = (-nextTrendScore).clamp(0.0, 1.0);
    final improving = nextTrendScore.clamp(0.0, 1.0);
    final inactivity = (1.0 - exerciseHealth).clamp(0.0, 1.0);
    final lowSleepPressure = (1.0 - sleepHealth).clamp(0.0, 1.0);

    // Poor trends can shift body shape either up (inactive + poor habits)
    // or down (high strain + symptoms), while positive trends gradually
    // move toward a fitter silhouette.
    final gainBias =
        (inactivity * 0.62 + lowSleepPressure * 0.24 + (1 - moodHealth) * 0.14)
            .clamp(0.0, 1.0);
    final lossBias =
        (symptomPressure * 0.24 +
                chronicSymptomPressure * 0.58 +
                lowSleepPressure * 0.28 +
                (exerciseHealth * 0.2))
            .clamp(0.0, 1.0);

    final negativeShift = underRecovery * (gainBias - lossBias) * 0.14;
    final symptomWeightLossShift =
        -chronicSymptomPressure *
        (0.05 + symptomPressure * 0.08 + lowSleepPressure * 0.03);
    final positiveShift = -improving * (0.06 + exerciseHealth * 0.06);
    final targetTrendBodyScale =
        (1.0 + negativeShift + symptomWeightLossShift + positiveShift)
            .clamp(0.82, 1.16)
            .toDouble();
    final nextTrendBodyScale =
        (_trendBodyWidthScale * 0.82 + targetTrendBodyScale * 0.18)
            .clamp(0.82, 1.16)
            .toDouble();

    final targetFatigue =
        (underRecovery * 0.32 +
                lowSleepPressure * 0.44 +
                symptomPressure * 0.2 -
                improving * 0.28)
            .clamp(0.0, 1.0)
            .toDouble();
    final nextFatigue = (_fatigueAppearanceLevel * 0.8 + targetFatigue * 0.2)
        .clamp(0.0, 1.0)
        .toDouble();

    final changed =
        (_healthTrendScore - nextTrendScore).abs() > 0.0005 ||
        (_trendBodyWidthScale - nextTrendBodyScale).abs() > 0.0005 ||
        (_fatigueAppearanceLevel - nextFatigue).abs() > 0.0005;

    if (!changed) {
      return;
    }

    _healthTrendScore = nextTrendScore;
    _trendBodyWidthScale = nextTrendBodyScale;
    _fatigueAppearanceLevel = nextFatigue;
    _saveToPrefs();
    notifyListeners();
  }

  void hydrateFromBackendSnapshot(MiniMeBackendAvatarSnapshot snapshot) {
    if (snapshot.companionId != null &&
        snapshot.companionId!.trim().isNotEmpty) {
      setCompanionId(snapshot.companionId!);
    }

    if (snapshot.miniMeName != null) {
      setMiniMeName(snapshot.miniMeName!);
    }

    if (snapshot.isHatched != null) {
      _isMiniMeHatched = snapshot.isHatched!;
    }

    if (snapshot.degradationLevel != null) {
      _degradationLevel = snapshot.degradationLevel!.clamp(0.0, 1.0).toDouble();
    }

    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCustomization = prefs.getBool(_hasAvatarCustomizationKey) ?? false;
    _companionId = prefs.getString(_companionIdKey) ?? _companionId;
    _isMiniMeHatched = prefs.getBool(_isMiniMeHatchedKey) ?? _isMiniMeHatched;
    _degradationLevel =
        prefs.getDouble(_degradationLevelKey) ?? _degradationLevel;
    _autoBodyWidthScale =
        prefs.getDouble(_autoBodyWidthScaleKey) ?? _autoBodyWidthScale;
    _trendBodyWidthScale =
        prefs.getDouble(_trendBodyWidthScaleKey) ?? _trendBodyWidthScale;
    _fatigueAppearanceLevel =
        prefs.getDouble(_fatigueAppearanceLevelKey) ?? _fatigueAppearanceLevel;
    _healthTrendScore =
        prefs.getDouble(_healthTrendScoreKey) ?? _healthTrendScore;

    if (hasCustomization) {
      _bodyModel = prefs.getString(_bodyModelKey) ?? _bodyModel;
      _hairModel = prefs.getString(_hairModelKey) ?? _hairModel;
      _shirtModel = prefs.getString(_shirtModelKey) ?? _shirtModel;
      _bodyWidthScale = prefs.getDouble(_bodyWidthScaleKey) ?? _bodyWidthScale;
    } else {
      final preset = miniMePresetById(_companionId);
      _bodyModel = preset.bodyModel;
      _hairModel = preset.hairModel;
      _shirtModel = preset.shirtModel;
      _bodyWidthScale = preset.bodyWidthScale;
    }

    _miniMeName = prefs.getString(_miniMeNameKey) ?? _miniMeName;
    notifyListeners();
  }

  Future<void> _saveToPrefs({bool markCustomized = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bodyModelKey, _bodyModel);
    await prefs.setString(_hairModelKey, _hairModel);
    await prefs.setString(_shirtModelKey, _shirtModel);
    await prefs.setDouble(_bodyWidthScaleKey, _bodyWidthScale);
    await prefs.setString(_miniMeNameKey, _miniMeName);
    await prefs.setString(_companionIdKey, _companionId);
    await prefs.setBool(_isMiniMeHatchedKey, _isMiniMeHatched);
    await prefs.setDouble(_degradationLevelKey, _degradationLevel);
    await prefs.setDouble(_autoBodyWidthScaleKey, _autoBodyWidthScale);
    await prefs.setDouble(_trendBodyWidthScaleKey, _trendBodyWidthScale);
    await prefs.setDouble(_fatigueAppearanceLevelKey, _fatigueAppearanceLevel);
    await prefs.setDouble(_healthTrendScoreKey, _healthTrendScore);
    if (markCustomized) {
      await prefs.setBool(_hasAvatarCustomizationKey, true);
    }
  }
}
