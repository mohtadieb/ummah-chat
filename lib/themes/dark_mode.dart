import 'package:flutter/material.dart';

const Color kAccent = Color(0xFF5C9A6A);

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  colorScheme: ColorScheme.dark(
    brightness: Brightness.dark,
    primary: const Color(0xFF5C9A6A),
    onPrimary: const Color(0xFF08110B),
    secondary: const Color(0xFF1E2B22),
    onSecondary: const Color(0xFFE5F2E7),
    tertiary: const Color(0xFFC9AE7B),
    onTertiary: const Color(0xFF1A140C),
    error: const Color(0xFFF2B8B5),
    onError: const Color(0xFF601410),
    surface: const Color(0xFF0B1511),
    onSurface: const Color(0xFFF2F1ED),
    surfaceContainerLowest: const Color(0xFF0B0D0C),
    surfaceContainer: const Color(0xFF161918),
    surfaceContainerHigh: const Color(0xFF1B1F1D),
    surfaceContainerHighest: const Color(0xFF222725),
    outline: const Color(0xFF3A423D),
    outlineVariant: const Color(0xFF2C332F),
    shadow: Colors.black,
  ),
  scaffoldBackgroundColor: const Color(0xFF0F1110),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: false,
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFFF2F1ED),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFF161918),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  dividerColor: const Color(0xFF232826),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: kAccent,
    foregroundColor: Color(0xFF08110B),
    elevation: 8,
    shape: StadiumBorder(),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF121514),
    selectedItemColor: kAccent,
    unselectedItemColor: Colors.grey[500],
    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    side: BorderSide.none,
    backgroundColor: const Color(0xFF202623),
    selectedColor: kAccent,
    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
  ),
);