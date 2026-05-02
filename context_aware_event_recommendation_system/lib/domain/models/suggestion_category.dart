import 'package:flutter/material.dart';

import '../../utils/app_logger.dart';

/// Maps a suggestion's [category] string to display values.
/// Centralised here so IconData and hue never live in the data model,
/// keeping the model JSON-serialisable without custom adapters.
extension SuggestionCategoryX on String {
  IconData get categoryIcon {
    switch (toLowerCase()) {
      case 'movement':
        return Icons.directions_walk_outlined;
      case 'recharge':
        return Icons.local_cafe_outlined;
      case 'learning':
        return Icons.menu_book_outlined;
      case 'social':
        return Icons.people_outline;
      case 'health':
        return Icons.favorite_outline;
      default:
        AppLogger.w('SuggestionCategoryX: unknown category "$this", using fallback icon');
        return Icons.auto_awesome;
    }
  }

  /// HSL hue (0–360) used for card hero gradient and icon tint.
  double get categoryHue {
    switch (toLowerCase()) {
      case 'movement':
        return 150;
      case 'recharge':
        return 30;
      case 'learning':
        return 270;
      case 'social':
        return 210;
      case 'health':
        return 340;
      default:
        return 250;
    }
  }
}
