import 'package:flutter/material.dart';
import 'dark_mode.dart';
import 'light_mode.dart';

/*

THEME PROVIDER

This class allows dynamic switching between light and dark themes across the app.

- Uses ChangeNotifier to notify widgets when the theme changes.
- Initially sets the app to light mode.
- Provides a simple toggle method for dark/light mode.

*/

class ThemeProvider extends ChangeNotifier {
  // Initially, set the theme to light mode
  ThemeData _themeData = lightMode;

  /// Get the current theme
  ThemeData get themeData => _themeData;

  /// Check if the current theme is dark mode
  bool get isDarkMode => _themeData == darkMode;

  /// Set the theme and notify listeners to rebuild UI
  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
  }

  /// Toggle between light and dark mode
  void toggleTheme() {
    if (_themeData == lightMode) {
      themeData = darkMode;
    } else {
      themeData = lightMode;
    }
  }
}