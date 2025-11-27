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

ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.dark(
    surface: Colors.grey.shade900,
    primary: Colors.grey.shade300,
    secondary: Colors.grey.shade700,
    tertiary: Colors.grey.shade800,
    inversePrimary: Colors.grey.shade100,
  ),
);