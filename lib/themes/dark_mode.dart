import 'package:flutter/material.dart';

/*

DARK MODE THEME

Defines the dark color scheme for the app.

- surface: background surfaces (cards, sheets)
- primary: main accent color
- secondary: secondary accent elements
- tertiary: for highlights or elevated surfaces
- inversePrimary: used for text/icons on primary surfaces

*/
const Color kAccent = Color(0xFF467E55);

ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.dark(
    surface: Colors.grey.shade900,
    primary: Colors.grey.shade300,
    secondary: Color(0xFF467E55).withValues(alpha: 0.15),
    tertiary: Colors.grey.shade800,
    inversePrimary: Colors.grey.shade100,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.grey.shade900,
    selectedItemColor: kAccent,
    unselectedItemColor: Colors.grey[500],
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
);