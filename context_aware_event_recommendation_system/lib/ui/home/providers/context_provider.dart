import 'package:context_aware_event_recommendation_system/data/repositories/suggestion_repository.dart';
import 'package:context_aware_event_recommendation_system/di/providers.dart';
import 'package:context_aware_event_recommendation_system/domain/models/context_state.dart';
import 'package:context_aware_event_recommendation_system/domain/models/persona_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/suggestion_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:context_aware_event_recommendation_system/di/providers.dart'
    show contextRepositoryProvider, suggestionRepositoryProvider;

part 'context_provider.g.dart';

/// Raw suggestions from the repository (TTL-cached, backed by ContextService).
@riverpod
Future<List<SuggestionModel>> suggestion(Ref ref) {
  return ref.watch(suggestionRepositoryProvider).getSuggestions();
}

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
/// Loads persisted state on first access; persists every change.
@Riverpod(keepAlive: true)
class DismissedSuggestions extends _$DismissedSuggestions {
  SuggestionRepository get _repo => ref.read(suggestionRepositoryProvider);

  @override
  Future<Set<String>> build() => _repo.getDismissedIds();

  Future<void> dismiss(String id) async {
    state = AsyncData({...state.valueOrNull ?? {}, id});
    await _repo.dismiss(id);
  }

  Future<void> clear() async {
    state = const AsyncData({});
    await _repo.clearDismissed();
  }
}

/// Suggestions visible to the user — raw list minus dismissed.
@riverpod
Future<List<SuggestionModel>> visibleSuggestions(Ref ref) async {
  final all = await ref.watch(suggestionProvider.future);
  final dismissed = await ref.watch(dismissedSuggestionsProvider.future);
  return all.where((s) => !dismissed.contains(s.id)).toList();
}
