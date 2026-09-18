import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colores alineados al Sistema de Guías RomEx.
class RomexColors {
  static const primary = Color(0xFF126044);
  static const primaryDark = Color(0xFF0B4936);
  static const primaryLight = Color(0xFF1B7A56);
  static const accent = Color(0xFF34D399);
  static const surface = Color(0xFFFCFDFC);
  static const surfaceAlt = Color(0xFFF3F6F4);
  static const border = Color(0xFFE2E8E2);
  static const textMuted = Color(0xFF68736B);
}

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: RomexColors.primary,
      brightness: Brightness.light,
      primary: RomexColors.primary,
    );

    return ThemeData(
      colorScheme: base,
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: RomexColors.surface,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: RomexColors.surface,
        foregroundColor: Color(0xFF1A1F1C),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RomexColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RomexColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RomexColors.primary, width: 1.5),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: RomexColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
