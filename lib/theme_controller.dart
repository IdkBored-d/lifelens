import 'package:flutter/material.dart';
import 'lifelens_theme.dart';

class ThemeController extends ChangeNotifier {
  bool _calmMode = false; // default to dark mode until toggled

  bool get isCalmMode => _calmMode;

  ThemeData get theme => _calmMode ? lifeLensCalmTheme() : lifeLensDarkTheme();

  void setCalmMode(bool value) {
    if (value == _calmMode) return;
    _calmMode = value;
    notifyListeners();
  }
}
