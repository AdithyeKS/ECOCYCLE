import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    colorSchemeSeed: const Color(0xFF28A745), // greenish
    scaffoldBackgroundColor: Colors.white,
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Color(0xFFF7F8FA),
    ),
  );
}
