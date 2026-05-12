import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lifelens_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({bool initialDarkMode = true}) : _darkMode = initialDarkMode;

  static const String darkModePrefsKey = 'lifelens.darkMode';

  bool _darkMode;

  bool get isDarkMode => _darkMode;
  bool get isCalmMode => !_darkMode;

  ThemeData get theme => _darkMode ? lifeLensDarkTheme() : lifeLensCalmTheme();

  static Future<bool> loadInitialDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(darkModePrefsKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  void setDarkMode(bool value) {
    if (value == _darkMode) return;
    _darkMode = value;
    notifyListeners();
    unawaited(_persistDarkMode(value));
  }

  void setCalmMode(bool value) {
    setDarkMode(!value);
  }

  Future<void> _persistDarkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(darkModePrefsKey, value);
    } catch (_) {
      // Theme changes should still apply even if persistence fails.
    }
  }
}
