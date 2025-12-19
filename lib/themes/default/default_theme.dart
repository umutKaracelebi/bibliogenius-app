/// BiblioGenius Default Theme
///
/// The classic BiblioGenius look: warm, inviting with customizable accent color.

import 'package:flutter/material.dart';
import '../base/theme_interface.dart';

class DefaultTheme extends AppTheme {
  @override
  String get id => 'default';

  @override
  String get displayName => 'BiblioGenius Classic';

  @override
  String get description => 'Warm, inviting design with soft colors';

  @override
  Color get previewColor => const Color(0xFF6366F1);

  @override
  ThemeData buildTheme({Color? accentColor}) {
    final bannerColor = accentColor ?? const Color(0xFF6366F1);
    final brightness = ThemeData.estimateBrightnessForColor(bannerColor);
    final foregroundColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;

    // POC Theme Colors
    const bgBody = Color(0xFFFDFBF7); // Warm cream
    const bgCard = Colors.white;
    const textMain = Color(0xFF44403C); // Stone 700
    const border = Color(0xFFE7E5E4); // Stone 200

    return ThemeData(
      primaryColor: bannerColor,
      useMaterial3: true,
      scaffoldBackgroundColor: bgBody,
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: bannerColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: foregroundColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: bannerColor,
        primary: bannerColor,
        surface: bgCard,
        onSurface: textMain,
        outline: border,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textMain),
        bodyMedium: TextStyle(color: textMain),
        titleLarge: TextStyle(
          color: textMain,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(color: textMain, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bannerColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: bannerColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
