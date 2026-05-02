import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'suggestion_model.freezed.dart';

@freezed
abstract class SuggestionModel with _$SuggestionModel {
  const factory SuggestionModel({
    required String id,
    required String title,
    required String description,

    /// Why the AI surfaced this — visible inside cards and detail view.
    required String rationale,
    required String category,

    /// Distance in km, null if not location-bound.
    double? distance,

    /// Estimated minutes for the activity.
    int? estimatedMinutes,
    String? address,
    double? latitude,
    double? longitude,
    @Default(<String>[]) List<String> tags,

    /// Optional context-weather summary (e.g. "21° • Clear").
    String? weather,

    /// Material icon used in the card hero + detail meta.
    @Default(Icons.auto_awesome) IconData icon,

    /// Hue (0–360) used to colour the card hero gradient.
    @Default(250.0) double hue,
    required DateTime createdAt,
  }) = _SuggestionModel;
}
