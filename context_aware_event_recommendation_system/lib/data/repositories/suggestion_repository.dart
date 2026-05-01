import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/suggestion_model.dart';
import '../services/context_service.dart';

class SuggestionRepository {
  SuggestionRepository(this._contextService, this._prefs);

  final ContextService _contextService;
  final SharedPreferences _prefs;

  static const _dismissedKey = 'suggestions.dismissed_ids';
  static const _cacheTtl = Duration(minutes: 5);

  List<SuggestionModel>? _cached;
  DateTime? _cacheExpiresAt;

  Future<List<SuggestionModel>> getSuggestions() async {
    final now = DateTime.now();
    if (_cached != null &&
        _cacheExpiresAt != null &&
        now.isBefore(_cacheExpiresAt!)) {
      return _cached!;
    }
    final fresh = await _contextService.getSuggestions();
    _cached = fresh;
    _cacheExpiresAt = now.add(_cacheTtl);
    return fresh;
  }

  /// Busts the in-memory cache so the next [getSuggestions] hits the service.
  void invalidateCache() {
    _cached = null;
    _cacheExpiresAt = null;
  }

  Future<Set<String>> getDismissedIds() async {
    final raw = _prefs.getStringList(_dismissedKey);
    return raw?.toSet() ?? {};
  }

  Future<void> dismiss(String id) async {
    final current = await getDismissedIds();
    await _prefs.setStringList(_dismissedKey, [...current, id]);
  }

  Future<void> clearDismissed() async {
    await _prefs.remove(_dismissedKey);
  }
}
