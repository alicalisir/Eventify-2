import '../../domain/models/context_state.dart';
import '../../domain/models/persona_model.dart';
import '../services/context_service.dart';

class ContextRepository {
  ContextRepository(this._service);

  final ContextService _service;

  // Context changes every few minutes; persona inference is expensive.
  static const _contextTtl = Duration(minutes: 2);
  static const _personaTtl = Duration(minutes: 15);

  ContextState? _cachedContext;
  DateTime? _contextExpiresAt;

  PersonaModel? _cachedPersona;
  DateTime? _personaExpiresAt;

  Future<ContextState> getCurrentContext() async {
    final now = DateTime.now();
    if (_cachedContext != null &&
        _contextExpiresAt != null &&
        now.isBefore(_contextExpiresAt!)) {
      return _cachedContext!;
    }
    final fresh = await _service.getCurrentContext();
    _cachedContext = fresh;
    _contextExpiresAt = now.add(_contextTtl);
    return fresh;
  }

  Future<PersonaModel> getUserPersona() async {
    final now = DateTime.now();
    if (_cachedPersona != null &&
        _personaExpiresAt != null &&
        now.isBefore(_personaExpiresAt!)) {
      return _cachedPersona!;
    }
    final fresh = await _service.getUserPersona();
    _cachedPersona = fresh;
    _personaExpiresAt = now.add(_personaTtl);
    return fresh;
  }

  void invalidateContext() {
    _cachedContext = null;
    _contextExpiresAt = null;
  }

  void invalidatePersona() {
    _cachedPersona = null;
    _personaExpiresAt = null;
  }
}
