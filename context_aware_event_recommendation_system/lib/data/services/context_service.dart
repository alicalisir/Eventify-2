import '../../domain/models/context_state.dart';
import '../../domain/models/persona_model.dart';
import '../../domain/models/suggestion_model.dart';

/// Context service — Mock implementation aligned with the
/// "Calm Intelligence" design system mock data.
/// TODO: Replace with real AI/ML service and sensor data.
class ContextService {
  /// AI-generated suggestions based on the current context.
  Future<List<SuggestionModel>> getSuggestions() async {
    await Future.delayed(const Duration(seconds: 2));
    final now = DateTime.now();
    return [
      SuggestionModel(
        id: 's1',
        category: 'Movement',
        title: 'A 15-min walk to Riverside Park',
        description:
            "You've been stationary for 2h 40m during deep focus. A short walk in fresh air will reset your attention.",
        rationale:
            'Detected prolonged stillness + golden-hour daylight + clear weather within 600m. Walking now lines up with your recovery pattern from past Tue evenings.',
        distance: 0.6,
        estimatedMinutes: 15,
        address: 'Riverside Park, East Entrance',
        latitude: 40.7829,
        longitude: -73.9654,
        tags: const ['Outdoors', 'Low effort', '7,500 steps today'],
        weather: '21° • Clear',
        createdAt: now,
      ),
      SuggestionModel(
        id: 's2',
        category: 'Recharge',
        title: 'Pour-over at Mercer Coffee',
        description:
            'A calm, near-empty café two blocks from your current location — typical of your 4pm slow-down.',
        rationale:
            'Café occupancy is low right now (24%). You usually take a coffee break around 4:10pm on writing-heavy days.',
        distance: 0.2,
        estimatedMinutes: 5,
        address: '88 Mercer St',
        latitude: 40.7234,
        longitude: -74.0021,
        tags: const ['Quiet', '\$', 'Solo time'],
        weather: '21° • Clear',
        createdAt: now,
      ),
      SuggestionModel(
        id: 's3',
        category: 'Learning',
        title: 'Resume "Designing Data-Intensive Apps", ch. 6',
        description:
            'You stopped 12 minutes in last Thursday. Your commute home starts in ~20 min — perfect length.',
        rationale:
            'Synced with reading history + upcoming calendar gap + headphones connected.',
        estimatedMinutes: 22,
        address: 'Audiobook • Resume from 00:12:34',
        tags: const ['Audio', 'Resume', 'Commute-friendly'],
        createdAt: now,
      ),
    ];
  }

  /// Current user context (location, time, activity, weather).
  Future<ContextState> getCurrentContext() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return ContextState(
      greeting: _greeting(DateTime.now()),
      contextDescription: 'Deep work session, 2h 40m',
      isLocationEnabled: true,
      isNotificationsEnabled: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// Persona inferred from user activity history.
  Future<PersonaModel> getUserPersona() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return PersonaModel(
      traits: const [
        PersonaTrait(label: 'Morning Person', confidence: 0.92),
        PersonaTrait(label: 'Nature Lover', confidence: 0.81),
        PersonaTrait(label: 'Deep Worker', confidence: 0.88),
        PersonaTrait(label: 'Coffee Ritualist', confidence: 0.74),
        PersonaTrait(label: 'Audio Learner', confidence: 0.69),
        PersonaTrait(label: 'Solo Recharger', confidence: 0.77),
      ],
      preferences: const {
        'culture': 0.9,
        'outdoor': 0.8,
        'food': 0.7,
        'productivity': 0.6,
      },
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 12)),
      signalsProcessedToday: 247,
    );
  }

  String _greeting(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
