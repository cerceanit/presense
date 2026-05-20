import 'package:flutter/material.dart';

class AppTheme {
  static const calm = Color(0xFF2D6A4F);
  static const warning = Color(0xFFB5B5B5);
  static const critical = Color(0xFFFFFFFF);
  static const background = Color(0xFF080808);
  static const surface = Color(0xFF141414);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF666666);

  static ThemeData get dark => ThemeData(
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: calm,
      surface: surface,
    ),
  );
}