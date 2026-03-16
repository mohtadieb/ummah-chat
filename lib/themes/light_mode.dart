import 'package:flutter/material.dart';

const Color kAccent = Color(0xFF467E55);

ThemeData lightMode = ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  colorScheme: ColorScheme.light(
    brightness: Brightness.light,
    primary: const Color(0xFF467E55),
    onPrimary: Colors.white,
    secondary: const Color(0xFFDDE9DF),
    onSecondary: const Color(0xFF16311E),
    tertiary: const Color(0xFFBFA67A),
    onTertiary: const Color(0xFF2C2114),
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    surface: const Color(0xFFF6FAF7),
    onSurface: const Color(0xFF1B1C18),
    surfaceContainerLowest: const Color(0xFFF3F0EA),
    surfaceContainer: Colors.white,
    surfaceContainerHigh: const Color(0xFFFCFAF7),
    surfaceContainerHighest: const Color(0xFFF1EEE8),
    outline: const Color(0xFFCBC5BA),
    outlineVariant: const Color(0xFFE3DDD2),
    shadow: Colors.black,
  ),
  scaffoldBackgroundColor: const Color(0xFFF7F5F1),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: false,
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFF1B1C18),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  dividerColor: const Color(0xFFE8E2D8),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: kAccent,
    foregroundColor: Colors.white,
    elevation: 6,
    shape: StadiumBorder(),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFFFCFAF7),
    selectedItemColor: kAccent,
    unselectedItemColor: Colors.grey[500],
    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    side: BorderSide.none,
    backgroundColor: const Color(0xFFEAF2EC),
    selectedColor: kAccent,
    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
  ),
);