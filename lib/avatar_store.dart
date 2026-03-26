import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarStore extends ChangeNotifier {
  static const String _bodyModelKey = 'bodyModel';
  static const String _hairModelKey = 'hairModel';
  static const String _shirtModelKey = 'shirtModel';
  static const String _bodyWidthScaleKey = 'bodyWidthScale';
  static const String _miniMeNameKey = 'miniMeName';
  static const String _hasAvatarCustomizationKey = 'hasAvatarCustomization';

  String _bodyModel = "lib/assets/minime/body.glb";
  String _hairModel = "";
  String _shirtModel = "";
  double _bodyWidthScale = 1.0;
  String _miniMeName = 'Mini-Me';

  AvatarStore() {
    _loadFromPrefs();
  }

  String get bodyModel => _bodyModel;
  String get hairModel => _hairModel;
  String get shirtModel => _shirtModel;
  double get bodyWidthScale => _bodyWidthScale;
  String get miniMeName => _miniMeName;

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
    _bodyWidthScale = scale.clamp(0.75, 1.35).toDouble();
    _saveToPrefs(markCustomized: true);
    notifyListeners();
  }

  void setMiniMeName(String name) {
    final next = name.trim();
    _miniMeName = next.isEmpty ? 'Mini-Me' : next;
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCustomization = prefs.getBool(_hasAvatarCustomizationKey) ?? false;

    if (hasCustomization) {
      _bodyModel = prefs.getString(_bodyModelKey) ?? _bodyModel;
      _hairModel = prefs.getString(_hairModelKey) ?? _hairModel;
      _shirtModel = prefs.getString(_shirtModelKey) ?? _shirtModel;
      _bodyWidthScale = prefs.getDouble(_bodyWidthScaleKey) ?? _bodyWidthScale;
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
    if (markCustomized) {
      await prefs.setBool(_hasAvatarCustomizationKey, true);
    }
  }
}
