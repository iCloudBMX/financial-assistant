import 'package:flutter/material.dart';

// Uses the platform default font family, which covers Latin + Cyrillic on
// both iOS (SF) and Android (Roboto). Numerals kept tabular where shown.
TextTheme buildTextTheme(ColorScheme scheme) => Typography.material2021(
      platform: TargetPlatform.android,
    ).black.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
