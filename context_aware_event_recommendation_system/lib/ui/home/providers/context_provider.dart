import 'package:context_aware_event_recommendation_system/data/repositories/suggestion_repository.dart';
import 'package:context_aware_event_recommendation_system/di/providers.dart';
import 'package:context_aware_event_recommendation_system/domain/models/context_state.dart';
import 'package:context_aware_event_recommendation_system/domain/models/persona_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/suggestion_model.dart';
import 'package:context_aware_event_recommendation_system/ui/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:context_aware_event_recommendation_system/di/providers.dart'
    show
        contextRepositoryProvider,
        suggestionRepositoryProvider,
        suggestionStreamProvider,
        SuggestionStreamNotifier;

part 'context_provider.g.dart';

/// Current ambient context (greeting, location, weather, activity).
@riverpod
Future<ContextState> ambientContext(Ref ref) {
  return ref.watch(contextRepositoryProvider).getCurrentContext();
}

/// Inferred persona — used by both Profile and (peripherally) Home.
@riverpod
Future<PersonaModel> persona(Ref ref) {
  return ref.watch(contextRepositoryProvider).getUserPersona();
}

/// IDs of suggestions the user has dismissed.
/// Scoped to the current user — rebuilds automatically on login/logout.
@Riverpod(keepAlive: true)
class DismissedSuggestions extends _$DismissedSuggestions {
  SuggestionRepository get _repo => ref.read(suggestionRepositoryProvider);
  String? get _uid => ref.watch(authProvider).user?.id;

  @override
  Future<Set<String>> build() async {
    final uid = _uid;
    if (uid == null) return {};
    return _repo.getDismissedIds(uid);
  }

  Future<void> dismiss(String id) async {
    if (state.value?.contains(id) ?? false) return;
    state = AsyncData({...state.value ?? {}, id});
    final uid = ref.read(authProvider).user?.id;
    if (uid != null) await _repo.dismiss(id, uid);
  }

  Future<void> clear() async {
    state = const AsyncData({});
    final uid = ref.read(authProvider).user?.id;
    if (uid != null) await _repo.clearDismissed(uid);
  }
}

/// Visible suggestions = stream results minus dismissed IDs.
/// Plain synchronous Provider — no loading flicker when new suggestions arrive.
final visibleSuggestionsProvider = Provider<List<SuggestionModel>>((ref) {
  final allAsync = ref.watch(suggestionStreamProvider);
  final dismissedAsync = ref.watch(dismissedSuggestionsProvider);
  final all = allAsync.value ?? const [];
  final dismissed = dismissedAsync.value ?? const <String>{};
  return all.where((s) => !dismissed.contains(s.id)).toList();
});
