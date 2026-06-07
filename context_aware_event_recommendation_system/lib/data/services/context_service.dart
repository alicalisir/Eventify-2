import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/context_state.dart';
import '../../domain/models/persona_model.dart';
import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';
import '../repositories/location_repository.dart';
import 'backend_service.dart';

class ContextService {
  ContextService(this._backend, this._supabase, this._location);

  final BackendService _backend;
  final SupabaseClient _supabase;
  final LocationRepository _location;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Returns AI-generated suggestions from the backend.
  /// Passes current GPS coordinates so the backend can fetch real nearby venues.
  /// Falls back to hardcoded mock data when the backend is unreachable.
  Future<List<SuggestionModel>> getSuggestions() async {
    final userId = _userId;
    if (userId != null) {
      final position = await _location.getCurrentPosition();
      final suggestions = await _backend.getRecommendations(
        userId,
        lat: position?.latitude,
        lon: position?.longitude,
      );
      if (suggestions.isNotEmpty) {
        AppLogger.i('[Context] ${suggestions.length} suggestions from backend '
            '(gps: ${position != null ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}' : 'unavailable'})');
        return suggestions;
      }
    }
    AppLogger.w('[Context] Backend unavailable — using mock suggestions');
    return _mockSuggestions();
  }

  /// Returns the inferred persona from the backend.
  /// Falls back to a hardcoded mock when backend is unreachable.
  Future<PersonaModel> getUserPersona() async {
    final userId = _userId;
    if (userId != null) {
      final persona = await _backend.getPersona(userId);
      if (persona != null) {
        AppLogger.i('[Context] Persona from backend: ${persona.traits.length} traits');
        return persona;
      }
    }
    AppLogger.w('[Context] Backend unavailable — using mock persona');
    return _mockPersona();
  }

  /// Current user context (location, time, activity, weather).
  /// This is derived locally — no backend call needed.
  Future<ContextState> getCurrentContext() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return ContextState(
      greeting: _greeting(DateTime.now()),
      contextDescription: 'Loading location & context…',
      isLocationEnabled: true,
      isNotificationsEnabled: true,
      lastUpdated: DateTime.now(),
    );
  }

  // ────────────────────────────── Mock fallbacks ──────────────────────────────

  List<SuggestionModel> _mockSuggestions() {
    final now = DateTime.now();
    return [
      SuggestionModel(
        id: 's1',
        category: 'Movement',
        title: '15-Minute Walk to Riverside Park',
        description:
            'You have been stationary for 2h 40min. A short walk will reset your focus.',
        rationale:
            'Long inactivity + golden hour light + fresh air just 600 m away.',
        distance: 0.6,
        estimatedMinutes: 15,
        address: 'Riverside Park, East Entrance',
        tags: const ['Outdoor', 'Low Effort'],
        weather: '21° • Clear',
        createdAt: now,
      ),
      SuggestionModel(
        id: 's2',
        category: 'Recharge',
        title: 'Coffee Break at Mercer Coffee',
        description: 'A quiet, low-crowd cafe two blocks away.',
        rationale: 'Cafe occupancy is low right now (24%). Fits your afternoon rhythm.',
        distance: 0.2,
        estimatedMinutes: 5,
        address: '88 Mercer St',
        tags: const ['Quiet', r'$', 'Solo'],
        weather: '21° • Clear',
        createdAt: now,
      ),
      SuggestionModel(
        id: 's3',
        category: 'Learning',
        title: 'Continue Where You Left Off',
        description:
            'You stopped at minute 12 last Thursday. You have ~20 min before heading home.',
        rationale: 'Reading history + calendar gap + headphones connected.',
        estimatedMinutes: 22,
        address: 'Audiobook • Resume from 00:12:34',
        tags: const ['Audio', 'Resume', 'Commute-Friendly'],
        createdAt: now,
      ),
    ];
  }

  PersonaModel _mockPersona() => PersonaModel(
        traits: const [
          PersonaTrait(label: 'Morning Person', confidence: 0.92),
          PersonaTrait(label: 'Nature Lover', confidence: 0.81),
          PersonaTrait(label: 'Deep Worker', confidence: 0.88),
          PersonaTrait(label: 'Coffee Ritualist', confidence: 0.74),
          PersonaTrait(label: 'Auditory Learner', confidence: 0.69),
        ],
        preferences: const {
          'culture': 0.9,
          'outdoor': 0.8,
          'food': 0.7,
          'productivity': 0.6,
        },
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 12)),
        signalsProcessedToday: 0,
      );

  String _greeting(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
