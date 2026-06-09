import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/llm_context_payload.dart';
import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';
import '../../utils/llm_prompt_builder.dart';
import '../services/context_service.dart';
import '../services/llm_service.dart';
import 'context_repository.dart';

class SuggestionRepository {
  SuggestionRepository(
    this._contextService,
    this._prefs,
    this._contextRepository,
    this._llmService,
  );

  final ContextService _contextService;
  final SharedPreferences _prefs;
  final ContextRepository _contextRepository;
  final LlmService _llmService;

  static String _dismissedKey(String uid) => 'suggestions.dismissed_ids_$uid';
  static const _cacheTtl = Duration(minutes: 5);

  List<SuggestionModel>? _cached;
  DateTime? _cacheExpiresAt;

  /// Streaming variant — yields each suggestion as it arrives from the Edge Function SSE.
  Stream<SuggestionModel> getSuggestionsStream() {
    return _llmService.getSuggestionsStream().handleError((Object e, StackTrace s) {
      AppLogger.e('[SuggestionRepository] SSE stream error', e);
    });
  }

  Future<List<SuggestionModel>> getSuggestions() async {
    final now = DateTime.now();
    if (_cached != null &&
        _cacheExpiresAt != null &&
        now.isBefore(_cacheExpiresAt!)) {
      AppLogger.d('[SuggestionRepository] In-memory cache hit');
      return _cached!;
    }
    try {
      final fresh = await _llmService.getSuggestions();
      _cached = fresh;
      _cacheExpiresAt = now.add(_cacheTtl);
      return fresh;
    } catch (e, s) {
      AppLogger.e('[SuggestionRepository] LLM failed, falling back to backend', e);
      AppLogger.d('[SuggestionRepository] Stack', s);
      try {
        return await _contextService.getSuggestions();
      } catch (e2, s2) {
        AppLogger.e('[SuggestionRepository] Backend also failed, returning empty', e2);
        AppLogger.d('[SuggestionRepository] Stack', s2);
        return [];
      }
    }
  }

  /// Busts the in-memory cache so the next [getSuggestions] hits the service.
  void invalidateCache() {
    _cached = null;
    _cacheExpiresAt = null;
  }

  /// Builds the LLM context payload from live context + persona data.
  ///
  /// In Faz 3, [LlmService] will receive this payload and return real suggestions.
  /// Call [LlmPromptBuilder.build] on the result to get the ready-to-send prompt.
  Future<LlmContextPayload> buildLlmPayload() async {
    final context = await _contextRepository.getCurrentContext();
    final persona = await _contextRepository.getUserPersona();

    final payload = LlmContextPayload(
      persona: persona,
      context: context,
      nearbyPlaces: context.nearbyPlaces,
      builtAt: DateTime.now(),
    );

    AppLogger.d(
      '[Suggestion] LLM payload built — '
      '${persona.traits.length} traits, '
      '${context.nearbyPlaces.length} places\n'
      '${LlmPromptBuilder.build(payload)}',
    );

    return payload;
  }

  Future<Set<String>> getDismissedIds(String uid) async {
    final raw = _prefs.getStringList(_dismissedKey(uid));
    return raw?.toSet() ?? {};
  }

  Future<void> dismiss(String id, String uid) async {
    final current = await getDismissedIds(uid);
    await _prefs.setStringList(_dismissedKey(uid), [...current, id]);
  }

  Future<void> clearDismissed(String uid) async {
    await _prefs.remove(_dismissedKey(uid));
  }
}
