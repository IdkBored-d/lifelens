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

  String _bodyModel = miniMeCompanionPresets.first.bodyModel;
  String _hairModel = miniMeCompanionPresets.first.hairModel;
  String _shirtModel = miniMeCompanionPresets.first.shirtModel;
  double _bodyWidthScale = miniMeCompanionPresets.first.bodyWidthScale;
  String _miniMeName = 'Mini-Me';
  String _companionId = miniMeCompanionPresets.first.id;
  bool _isMiniMeHatched = false;
  double _degradationLevel = 0.0;
  double _autoBodyWidthScale = 1.0;

  AvatarStore() {
    _loadFromPrefs();
  }

  String get bodyModel => _bodyModel;
  String get hairModel => _hairModel;
  String get shirtModel => _shirtModel;
  double get bodyWidthScale => _bodyWidthScale;
  double get effectiveBodyWidthScale =>
      (_bodyWidthScale * _autoBodyWidthScale).clamp(0.7, 1.48).toDouble();
  String get miniMeName => _miniMeName;
  String get companionId => _companionId;
  bool get isMiniMeHatched => _isMiniMeHatched;
  double get degradationLevel => _degradationLevel;
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

  void setMiniMeName(String name) {
    final next = name.trim();
    _miniMeName = next.isEmpty ? 'Mini-Me' : next;
    _saveToPrefs();
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
    if (markCustomized) {
      await prefs.setBool(_hasAvatarCustomizationKey, true);
    }
  }
}
