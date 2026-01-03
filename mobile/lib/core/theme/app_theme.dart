import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1D9BF0); // X Blue
  static const Color primaryDark = Color(0xFF0C7ABF);
  static const Color accentColor = Color(0xFFF91880); // X Pink
  static const Color secondaryColor = Color(0xFFEFF3F4);
  static const Color backgroundColor = Color(0xFF000000); // Pure Black for OLED
  static const Color surfaceColor = Color(0xFF16181C); // Dark Grey

  static const Color textPrimary = Color(0xFFE7E9EA);
  static const Color textSecondary = Color(0xFF71767B);

  // Modern UI Colors
  static const Color glassBorder = Color(0xFF2F3336);
  static const Color cardGradientStart = Color(0xFF16181C);
  static const Color cardGradientEnd = Color(0xFF0D0F12);
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFF1D9BF0), Color(0xFF8B3DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      surface: surfaceColor,
      onSurface: textPrimary,
      surfaceContainer: surfaceColor,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: const TextStyle(color: textPrimary),
      bodyMedium: const TextStyle(color: textSecondary),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
