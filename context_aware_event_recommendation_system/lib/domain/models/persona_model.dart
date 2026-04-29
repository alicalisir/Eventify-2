/// Persona model for user profile traits
class PersonaModel {
  final List<String> traits;
  final Map<String, double> preferences;
  final DateTime lastUpdated;

  const PersonaModel({
    required this.traits,
    required this.preferences,
    required this.lastUpdated,
  });

  static PersonaModel get empty => PersonaModel(
        traits: [],
        preferences: {},
        lastUpdated: DateTime.now(),
      );
}
