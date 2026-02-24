import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary   = Color(0xFF1976D2);
  static const Color secondary = Color(0xFF42A5F5);
  static const Color danger    = Color(0xFFE53935);
  static const Color success   = Color(0xFF43A047);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primary,
    brightness: Brightness.light,
    fontFamily: 'Roboto',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primary,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
  );
}
