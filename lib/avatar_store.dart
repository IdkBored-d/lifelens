import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarStore extends ChangeNotifier {
  String _bodyModel = "lib/assets/minime/body.glb";
  String _hairModel = "lib/assets/minime/hair/shortHair.glb";
  String _shirtModel = "lib/assets/minime/shirts/basicShirt.glb";

  AvatarStore() {
    _loadFromPrefs();
  }

  String get bodyModel => _bodyModel;
  String get hairModel => _hairModel;
  String get shirtModel => _shirtModel;

  void setBodyModel(String model) {
    _bodyModel = model;
    _saveToPrefs();
    notifyListeners();
  }

  void setHairModel(String model) {
    _hairModel = model;
    _saveToPrefs();
    notifyListeners();
  }

  void setShirtModel(String model) {
    _shirtModel = model;
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _bodyModel = prefs.getString('bodyModel') ?? _bodyModel;
    _hairModel = prefs.getString('hairModel') ?? _hairModel;
    _shirtModel = prefs.getString('shirtModel') ?? _shirtModel;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bodyModel', _bodyModel);
    await prefs.setString('hairModel', _hairModel);
    await prefs.setString('shirtModel', _shirtModel);
  }
}