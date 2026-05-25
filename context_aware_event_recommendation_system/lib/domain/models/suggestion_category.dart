import 'package:flutter/material.dart';

import '../../utils/app_logger.dart';

/// Maps a suggestion's [category] string to display values.
/// Centralised here so IconData and hue never live in the data model,
/// keeping the model JSON-serialisable without custom adapters.
extension SuggestionCategoryX on String {
  IconData get categoryIcon {
    switch (toLowerCase()) {
      case 'music':
        return Icons.music_note_outlined;
      case 'sports':
        return Icons.directions_run_outlined;
      case 'culture':
        return Icons.museum_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'outdoor':
        return Icons.park_outlined;
      case 'workshop':
        return Icons.build_outlined;
      case 'family':
        return Icons.family_restroom_outlined;
      default:
        AppLogger.w(
          'SuggestionCategoryX: unknown category "$this", using fallback icon',
        );
        return Icons.auto_awesome;
    }
  }

  /// HSL hue (0–360) used for card hero gradient and icon tint.
  double get categoryHue {
    switch (toLowerCase()) {
      case 'music':
        return 280;
      case 'sports':
        return 150;
      case 'culture':
        return 220;
      case 'food':
        return 30;
      case 'outdoor':
        return 120;
      case 'workshop':
        return 45;
      case 'family':
        return 200;
      default:
        return 250;
    }
  }
}
