import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();
  // Warm, calm palette (PRD §21.2). Red reserved strictly for error/critical.
  static const warmPrimary = Color(0xFF3E7C6A); // calm teal-green
  static const warmAccent = Color(0xFFE8A87C); // soft warm accent
  static const surfaceLight = Color(0xFFFBF7F2);
  static const surfaceDark = Color(0xFF1C2321);
  static const statusSafe = Color(0xFF3E7C6A);
  static const statusNear = Color(0xFFD9A441); // amber, not red
  static const statusOver = Color(0xFFB3462F); // reserved for over/critical
  static const error = Color(0xFFB3261E);
}

class AppStatusStyle {
  final Color color;
  final IconData icon;
  final String labelKey; // resolved by l10n later
  const AppStatusStyle(this.color, this.icon, this.labelKey);

  static const safe =
      AppStatusStyle(AppColors.statusSafe, Icons.check_circle, 'status_safe');
  static const near =
      AppStatusStyle(AppColors.statusNear, Icons.info, 'status_near');
  static const over =
      AppStatusStyle(AppColors.statusOver, Icons.warning_amber, 'status_over');
}
