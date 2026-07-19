import 'package:flutter/material.dart';

abstract final class VeloraColors {
  static const plum = Color(0xFF5B3A6E);
  static const coral = Color(0xFFE96F5C);
  static const apricot = Color(0xFFFFB46A);
  static const blush = Color(0xFFFFF8F5);
  static const inkberry = Color(0xFF332A3A);
  static const success = Color(0xFF2E9D7C);
  static const critical = Color(0xFFC94E58);
}

abstract final class VeloraSpacing {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0;
}

abstract final class VeloraRadii {
  static const control = 16.0, card = 22.0, sheet = 28.0;
}

abstract final class VeloraMotion {
  static const standard = Duration(milliseconds: 200);
}

enum VeloraStatus { safe, near, over }

extension VeloraStatusVisuals on VeloraStatus {
  Color get color => switch (this) {
    VeloraStatus.safe => VeloraColors.success,
    VeloraStatus.near => VeloraColors.apricot,
    VeloraStatus.over => VeloraColors.critical,
  };

  IconData get icon => switch (this) {
    VeloraStatus.safe => Icons.check_circle,
    VeloraStatus.near => Icons.info,
    VeloraStatus.over => Icons.warning_amber,
  };

  String get labelKey => switch (this) {
    VeloraStatus.safe => 'status_safe',
    VeloraStatus.near => 'status_near',
    VeloraStatus.over => 'status_over',
  };
}
