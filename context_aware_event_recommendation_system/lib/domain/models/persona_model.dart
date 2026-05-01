/// A single inferred persona trait with confidence (0.0 — 1.0).
class PersonaTrait {
  final String label;
  final double confidence;

  const PersonaTrait({
    required this.label,
    required this.confidence,
  });

  /// Confidence rounded to a percentage (0–100) for UI display.
  int get confidencePercent => (confidence.clamp(0, 1) * 100).round();
}

/// Persona model — inferred behavioural traits from user activity.
class PersonaModel {
  final List<PersonaTrait> traits;
  final Map<String, double> preferences;
  final DateTime lastUpdated;
  final int signalsProcessedToday;

  const PersonaModel({
    required this.traits,
    required this.preferences,
    required this.lastUpdated,
    this.signalsProcessedToday = 0,
  });

  static PersonaModel get empty => PersonaModel(
        traits: const [],
        preferences: const {},
        lastUpdated: DateTime.now(),
      );
}
