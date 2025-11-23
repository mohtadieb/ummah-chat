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

ThemeData lightMode = ThemeData(
  colorScheme: ColorScheme.light(
    surface: const Color(0xFFF8F5F0),
    primary: Colors.grey.shade800,
    secondary: Colors.grey.shade300,
    tertiary: Colors.white,
    inversePrimary: Colors.grey.shade900,
  ),
);