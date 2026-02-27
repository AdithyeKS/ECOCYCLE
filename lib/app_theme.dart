import 'package:flutter/material.dart';

class AppTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: Colors.green,
    scaffoldBackgroundColor: Colors.grey[50],
    cardColor: Colors.white,
    shadowColor: Colors.black12,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      elevation: 2,
      centerTitle: false,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF2E7D32),
      unselectedItemColor: Colors.grey,
    ),
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.green,
    scaffoldBackgroundColor: const Color(0xFF0a0e27),
    cardColor: const Color(0xFF1a1f3a),
    shadowColor: Colors.black38,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      elevation: 4,
      centerTitle: false,
      backgroundColor: const Color(0xFF1a1f3a),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: const Color(0xFF1a1f3a),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1a1f3a),
      selectedItemColor: Color(0xFF60AD5E),
      unselectedItemColor: Colors.grey,
    ),
  );
}
