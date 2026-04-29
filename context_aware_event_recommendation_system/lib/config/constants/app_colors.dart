import 'package:flutter/material.dart';

/// Design system color palette
abstract final class AppColors {
  // Core Colors
  static const Color primary = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF0D9488);
  static const Color accent = Color(0xFF8B5CF6);

  // Light Mode
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textDisabledLight = Color(0xFFCBD5E1);

  // Dark Mode
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF475569);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Shimmer
  static const Color shimmerBaseLight = Color(0xFFE2E8F0);
  static const Color shimmerHighlightLight = Color(0xFFF1F5F9);
  static const Color shimmerBaseDark = Color(0xFF334155);
  static const Color shimmerHighlightDark = Color(0xFF475569);

  // Other
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF334155);
  static const Color overlay = Color(0x80000000);

  static ColorScheme get lightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accent,
        onTertiary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surfaceLight,
        onSurface: textPrimaryLight,
        surfaceContainerHighest: backgroundLight,
        onSurfaceVariant: textSecondaryLight,
      );

  static ColorScheme get darkColorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accent,
        onTertiary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surfaceDark,
        onSurface: textPrimaryDark,
        surfaceContainerHighest: backgroundDark,
        onSurfaceVariant: textSecondaryDark,
      );
}
