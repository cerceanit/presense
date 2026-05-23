import 'package:flutter/material.dart';

/// PreSense warm palette — no pure white/black, no Material blue.
abstract final class AppColors {
  static const primaryBackground = Color(0xFFFAF7F2);
  static const secondaryBackground = Color(0xFFF5F0E8);
  static const cardBackground = Color(0xFFFFFFFF);
  static const primaryAccent = Color(0xFFC4956A);
  static const secondaryAccent = Color(0xFF8B6F5E);
  static const textPrimary = Color(0xFF2C2416);
  static const textSecondary = Color(0xFF6B5744);
  static const success = Color(0xFF7A9E7E);
  static const warning = Color(0xFFE8A838);
  static const alert = Color(0xFFE07B39);
  static const critical = Color(0xFFB85C5C);
  static const border = Color(0xFFE8E0D5);
  static const mutedText = Color(0xFFA89880);

  static const double radius = 12;

  static Color riskColor(double score) {
    if (score >= 85) return critical;
    if (score >= 70) return alert;
    if (score >= 60) return warning;
    return success;
  }

  static String riskLabel(double score) {
    if (score >= 85) return 'CRITICAL';
    if (score >= 70) return 'ALERT';
    if (score >= 60) return 'WATCH';
    return 'SAFE';
  }
}
