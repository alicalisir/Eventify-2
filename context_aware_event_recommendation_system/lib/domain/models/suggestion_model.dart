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

    /// Category string is the single source of truth for icon and hue.
    /// Use [SuggestionCategoryX] extension to derive display values.
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

    /// Context signals that triggered this suggestion (e.g. "Time of day", "Weather").
    /// Populated by the backend when available; falls back to default pills in the UI.
    @Default(<String>[]) List<String> signals,
    required DateTime createdAt,
  }) = _SuggestionModel;
}
