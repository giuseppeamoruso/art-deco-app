import 'package:flutter/material.dart';

class ThemeManager {
  static ThemeData getTheme() => _standardTheme;

  static final ThemeData _standardTheme = ThemeData(
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: const Color(0xFF1a1a1a),
    cardColor: const Color(0xFF2d2d2d),
    colorScheme: ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.green,
      surface: const Color(0xFF2d2d2d),
    ),
  );
}
