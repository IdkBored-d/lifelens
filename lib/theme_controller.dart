import 'package:flutter/material.dart';
import 'lifelens_theme.dart';

class ThemeController extends ChangeNotifier {
  bool _darkMode = true;

  bool get isDarkMode => _darkMode;
  bool get isCalmMode => !_darkMode;

  ThemeData get theme => _darkMode ? lifeLensDarkTheme() : lifeLensCalmTheme();

  void setDarkMode(bool value) {
    if (value == _darkMode) return;
    _darkMode = value;
    notifyListeners();
  }

  void setCalmMode(bool value) {
    setDarkMode(!value);
  }
}
