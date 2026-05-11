import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/context_state.dart';
import '../../domain/models/persona_model.dart';
import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';
import 'backend_service.dart';

class ContextService {
  ContextService(this._backend, this._supabase);

  final BackendService _backend;
  final SupabaseClient _supabase;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Returns AI-generated suggestions from the backend.
  /// Falls back to hardcoded mock data when the backend is unreachable.
  Future<List<SuggestionModel>> getSuggestions() async {
    final userId = _userId;
    if (userId != null) {
      final suggestions = await _backend.getRecommendations(userId);
      if (suggestions.isNotEmpty) {
        AppLogger.i('[Context] ${suggestions.length} suggestions from backend');
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
      contextDescription: 'Konum & bağlam yükleniyor…',
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
        title: 'Riverside Park\'a 15 Dakikalık Yürüyüş',
        description:
            '2 saat 40 dakikadır hareketsizsin. Kısa bir yürüyüş dikkatini sıfırlar.',
        rationale:
            'Uzun hareketsizlik + altın saat ışığı + 600m mesafede temiz hava.',
        distance: 0.6,
        estimatedMinutes: 15,
        address: 'Riverside Park, Doğu Girişi',
        tags: const ['Açık Hava', 'Düşük Efor'],
        weather: '21° • Açık',
        createdAt: now,
      ),
      SuggestionModel(
        id: 's2',
        category: 'Recharge',
        title: 'Mercer Coffee\'de Mola',
        description: 'İki blok ötede sakin, az kalabalık bir kafe.',
        rationale: 'Kafe doluluk oranı şu an düşük (%24). Öğleden sonra ritmine uyuyor.',
        distance: 0.2,
        estimatedMinutes: 5,
        address: '88 Mercer St',
        tags: const ['Sakin', r'$', 'Tek Başına'],
        weather: '21° • Açık',
        createdAt: now,
      ),
      SuggestionModel(
        id: 's3',
        category: 'Learning',
        title: 'Kitaba Kaldığın Yerden Devam Et',
        description:
            'Geçen Perşembe 12. dakikada bıraktın. Eve gitmene ~20 dakika var.',
        rationale: 'Okuma geçmişi + takvim boşluğu + kulaklık bağlı.',
        estimatedMinutes: 22,
        address: 'Sesli Kitap • 00:12:34\'ten devam et',
        tags: const ['Sesli', 'Devam', 'Yolculuk Dostu'],
        createdAt: now,
      ),
    ];
  }

  PersonaModel _mockPersona() => PersonaModel(
        traits: const [
          PersonaTrait(label: 'Sabah İnsanı', confidence: 0.92),
          PersonaTrait(label: 'Doğa Sever', confidence: 0.81),
          PersonaTrait(label: 'Derin Çalışan', confidence: 0.88),
          PersonaTrait(label: 'Kahve Ritüelcisi', confidence: 0.74),
          PersonaTrait(label: 'İşitsel Öğrenici', confidence: 0.69),
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
    if (hour < 12) return 'Günaydın';
    if (hour < 17) return 'İyi günler';
    return 'İyi akşamlar';
  }
}
