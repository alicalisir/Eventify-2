import 'package:flutter/material.dart';

/// Design system color palette — "Calm Intelligence"
abstract final class AppColors {
  // Core
  static const Color primary = Color(0xFF4F46E5);
  static const Color primary600 = Color(0xFF4338CA);
  static const Color primary50 = Color(0xFFEEF2FF);
  static const Color secondary = Color(0xFF0D9488);
  static const Color secondary50 = Color(0xFFF0FDFA);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accent50 = Color(0xFFF5F3FF);

  // Light mode surfaces
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textDisabledLight = Color(0xFFCBD5E1);

  // Dark mode surfaces
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF475569);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color success50 = Color(0xFFECFDF5);
  static const Color error = Color(0xFFEF4444);
  static const Color error50 = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warning50 = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF3B82F6);
  static const Color info50 = Color(0xFFEFF6FF);

  // Shimmer
  static const Color shimmerBaseLight = Color(0xFFE2E8F0);
  static const Color shimmerHighlightLight = Color(0xFFF1F5F9);
  static const Color shimmerBaseDark = Color(0xFF334155);
  static const Color shimmerHighlightDark = Color(0xFF475569);

  // Other
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF334155);
  static const Color overlay = Color(0x80000000);

  /// Brand gradient stops (used by ContextHeader, BrandMark, etc.)
  static const List<Color> brandGradient = [primary, accent];

  // ─── Semantic Tokens ────────────────────────────────────────────────────────
  // Named aliases that describe *intent*. Widgets reference these; primitives
  // stay in the brand layer above.

  // Active / Selected States
  /// Background for an active navigation row or an enabled toggle icon.
  static const Color activeItemBackground = primary50;
  /// Border ring on a selected persona chip.
  static final Color selectedChipBorder = primary.withValues(alpha: 0.20);

  // Brand Shadows & Glows
  /// Drop shadow beneath gradient hero surfaces (header card, avatar).
  static final Color brandCardShadow = primary.withValues(alpha: 0.25);
  /// Close shadow under a primary filled button (brand glow, near layer).
  static final Color buttonGlowNear = primary.withValues(alpha: 0.30);
  /// Diffuse ambient shadow under a primary filled button (far layer).
  static final Color buttonGlowFar = primary.withValues(alpha: 0.18);
  /// Ambient halo beneath the brand logo tile.
  static final Color brandLogoHalo = primary.withValues(alpha: 0.35);

  // Intelligence Surface (AI rationale)
  /// Background for the AI rationale band inside recommendation cards.
  static const Color intelligenceBand = accent50;
  /// Border for priority (featured) recommendation cards.
  static final Color featuredCardBorder = accent.withValues(alpha: 0.25);
  /// Drop shadow for priority (featured) recommendation cards.
  static final Color featuredCardShadow = accent.withValues(alpha: 0.12);

  // Permission & Status Badges
  /// Background for inline "active" or "permission granted" status badges.
  static const Color permissionGrantedBackground = success50;

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
