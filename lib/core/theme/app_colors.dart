import 'package:flutter/material.dart';

import 'velora_tokens.dart';

class AppColors {
  const AppColors._();

  // Compatibility aliases for screens that have not moved to semantic tokens.
  static const warmPrimary = VeloraColors.plum;
  static const warmAccent = VeloraColors.coral;
  static const surfaceLight = VeloraColors.blush;
  static const surfaceDark = Color(0xFF1C1720);
  static const statusSafe = VeloraColors.success;
  static const statusNear = VeloraColors.apricot;
  static const statusOver = VeloraColors.critical;
  static const error = VeloraColors.critical;
}

class AppStatusStyle {
  final VeloraStatus status;

  const AppStatusStyle._(this.status);

  Color get color => status.color;
  IconData get icon => status.icon;
  String get labelKey => status.labelKey;

  static const safe = AppStatusStyle._(VeloraStatus.safe);
  static const near = AppStatusStyle._(VeloraStatus.near);
  static const over = AppStatusStyle._(VeloraStatus.over);
}
