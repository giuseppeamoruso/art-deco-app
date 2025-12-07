import 'package:flutter/material.dart';

enum AppTheme {
  standard,    // Tema normale
  christmas,   // Natale
  halloween,   // Halloween (solo 31 Ottobre)
  summer,      // Estate
}

class ThemeManager {
  static AppTheme getCurrentTheme() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    // 🎄 NATALE (neve: 1 Dic - 6 Gen)
    if ((month == 12 && day >= 1) || (month == 1 && day <= 6)) {
      return AppTheme.christmas;
    }

    // 🎃 HALLOWEEN (solo 31 Ottobre)
    if (month == 10 && day == 31) {
      return AppTheme.halloween;
    }

    // ☀️ ESTATE (1 Giugno - 31 Agosto)
    if (month >= 6 && month <= 8) {
      return AppTheme.summer;
    }

    return AppTheme.standard;
  }

  static ThemeData getTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.christmas:
        return _christmasTheme;
      case AppTheme.halloween:
        return _halloweenTheme;
      case AppTheme.summer:
        return _summerTheme;
      case AppTheme.standard:
      default:
        return _standardTheme;
    }
  }

  // 🎄 TEMA NATALE
  static final ThemeData _christmasTheme = ThemeData(
    primaryColor: const Color(0xFFD42F2F), // Rosso Natale
    scaffoldBackgroundColor: const Color(0xFF1a1a1a),
    cardColor: const Color(0xFF2d2d2d),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFD42F2F),
      secondary: const Color(0xFF2E7D32), // Verde albero
      surface: const Color(0xFF2d2d2d),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2d2d2d),
      elevation: 0,
    ),
  );

  // 🎃 TEMA HALLOWEEN
  static final ThemeData _halloweenTheme = ThemeData(
    primaryColor: const Color(0xFFFF6D00), // Arancione zucca
    scaffoldBackgroundColor: const Color(0xFF1a1a1a),
    cardColor: const Color(0xFF2d2d2d),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFFF6D00),
      secondary: const Color(0xFF6A1B9A), // Viola
      surface: const Color(0xFF2d2d2d),
    ),
  );

  // ☀️ TEMA ESTATE
  static final ThemeData _summerTheme = ThemeData(
    primaryColor: const Color(0xFF00BCD4), // Azzurro mare
    scaffoldBackgroundColor: const Color(0xFF1a1a1a),
    cardColor: const Color(0xFF2d2d2d),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF00BCD4),
      secondary: const Color(0xFFFFEB3B), // Giallo sole
      surface: const Color(0xFF2d2d2d),
    ),
  );

  // 🎨 TEMA STANDARD
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

  // 🎅 Colori speciali Natale
  static const Color christmasRed = Color(0xFFD42F2F);
  static const Color christmasGreen = Color(0xFF2E7D32);
  static const Color christmasGold = Color(0xFFFFD700);
  static const Color christmasSnow = Color(0xFFF5F5F5);

  // 🎃 Colori speciali Halloween
  static const Color halloweenOrange = Color(0xFFFF6D00);
  static const Color halloweenPurple = Color(0xFF6A1B9A);
  static const Color halloweenBlack = Color(0xFF212121);
}