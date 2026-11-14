import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const indigo = Color(0xFF4F46E5);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const text = Color(0xFF111111);
  static const border = Color(0xFFE5E7EB);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      primary: AppColors.indigo,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}
