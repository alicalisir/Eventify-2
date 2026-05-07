import 'package:freezed_annotation/freezed_annotation.dart';

part 'persona_model.freezed.dart';

@freezed
abstract class PersonaTrait with _$PersonaTrait {
  const PersonaTrait._();

  const factory PersonaTrait({
    required String label,
    required double confidence,
  }) = _PersonaTrait;

  /// Confidence rounded to a percentage (0–100) for UI display.
  int get confidencePercent => (confidence.clamp(0, 1) * 100).round();
}

@freezed
abstract class PersonaModel with _$PersonaModel {
  const PersonaModel._();

  const factory PersonaModel({
    required List<PersonaTrait> traits,
    required Map<String, double> preferences,
    required DateTime lastUpdated,
    @Default(0) int signalsProcessedToday,
  }) = _PersonaModel;

  static PersonaModel get empty => PersonaModel(
    traits: const [],
    preferences: const {},
    lastUpdated: DateTime.now(),
  );
}
