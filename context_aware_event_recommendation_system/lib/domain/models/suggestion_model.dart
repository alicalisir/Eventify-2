import 'package:flutter/material.dart';

/// Suggestion model — a single AI-generated context recommendation.
class SuggestionModel {
  final String id;
  final String title;
  final String description;

  /// Why the AI surfaced this — visible inside cards and detail view.
  final String rationale;
  final String category;

  /// Distance in km, null if not location-bound.
  final double? distance;

  /// Estimated minutes for the activity.
  final int? estimatedMinutes;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> tags;

  /// Optional context-weather summary (e.g. "21° • Clear").
  final String? weather;

  /// Material icon used in the card hero + detail meta.
  final IconData icon;

  /// Hue (0–360) used to colour the card hero gradient. Lets each suggestion
  /// feel like its own little world without bespoke imagery.
  final double hue;

  final DateTime createdAt;

  const SuggestionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rationale,
    required this.category,
    this.distance,
    this.estimatedMinutes,
    this.address,
    this.latitude,
    this.longitude,
    this.tags = const [],
    this.weather,
    this.icon = Icons.auto_awesome,
    this.hue = 250,
    required this.createdAt,
  });
}
