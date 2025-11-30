import 'package:flutter/material.dart';

/*

LIGHT MODE THEME

Defines the light color scheme for the app.

- surface: background surfaces (cards, sheets)
- primary: main accent color
- secondary: secondary accent elements
- tertiary: for highlights or elevated surfaces
- inversePrimary: used for text/icons on primary surfaces

*/
const Color kAccent = Color(0xFF467E55);

ThemeData lightMode = ThemeData(
  colorScheme: ColorScheme.light(
    surface: const Color(0xFFF8F5F0),
    primary: Color(0xFF467E55),
    secondary: Color(0xFF467E55).withValues(alpha: 0.15),
    tertiary: Colors.white,
    inversePrimary: Colors.grey.shade900,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFFF8F5F0),
    selectedItemColor: kAccent,
    unselectedItemColor: Colors.grey[500],
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
);