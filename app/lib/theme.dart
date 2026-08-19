import 'package:flutter/material.dart';

/// Paleta del reino.
class RN {
  static const night = Color(0xFF0D1026);
  static const nightSoft = Color(0xFF1A1F3A);
  static const panel = Color(0xFF232945);
  static const parchment = Color(0xFFF0E6D2);
  static const parchmentDim = Color(0xFFC9BFA8);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0xFFE8CE7A);
  static const teal = Color(0xFF5FB8C4);
  static const danger = Color(0xFFC94F4F);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RN.gold,
      brightness: Brightness.dark,
      surface: RN.nightSoft,
    ),
    scaffoldBackgroundColor: RN.night,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: RN.parchment,
      displayColor: RN.parchment,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RN.night,
      foregroundColor: RN.parchment,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: RN.panel,
      elevation: 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RN.gold,
        foregroundColor: RN.night,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );
}

/// Estilo de título "de fantasía" usando la serif del sistema.
TextStyle fantasyTitle(double size, {Color color = RN.parchment}) {
  return TextStyle(
    fontFamily: 'serif',
    fontSize: size,
    fontWeight: FontWeight.bold,
    color: color,
    height: 1.15,
  );
}
