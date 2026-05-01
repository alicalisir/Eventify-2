import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:context_aware_event_recommendation_system/data/repositories/context_repository.dart';
import 'package:context_aware_event_recommendation_system/data/repositories/suggestion_repository.dart';
import 'package:context_aware_event_recommendation_system/data/services/context_service.dart';
import 'package:context_aware_event_recommendation_system/domain/models/suggestion_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/persona_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/context_state.dart';
import 'package:context_aware_event_recommendation_system/ui/auth/providers/auth_provider.dart';

final contextServiceProvider = Provider((ref) => ContextService());

final contextRepositoryProvider = Provider<ContextRepository>((ref) {
  return ContextRepository(ref.watch(contextServiceProvider));
});

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return SuggestionRepository(
    ref.watch(contextServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

/// Raw suggestions from the repository (TTL-cached, backed by ContextService).
final suggestionProvider = FutureProvider<List<SuggestionModel>>((ref) async {
  return ref.watch(suggestionRepositoryProvider).getSuggestions();
});

/// Current ambient context (greeting, location, weather, activity).
final contextProvider = FutureProvider<ContextState>((ref) async {
  return ref.watch(contextRepositoryProvider).getCurrentContext();
});

/// Inferred persona — used by both Profile and (peripherally) Home.
final personaProvider = FutureProvider<PersonaModel>((ref) async {
  return ref.watch(contextRepositoryProvider).getUserPersona();
});

/// IDs of suggestions the user has dismissed.
/// Loads persisted state on first access; persists every change.
class DismissedSuggestionsNotifier extends AsyncNotifier<Set<String>> {
  SuggestionRepository get _repo => ref.read(suggestionRepositoryProvider);

  @override
  Future<Set<String>> build() => _repo.getDismissedIds();

  Future<void> dismiss(String id) async {
    // Optimistic update so the card disappears immediately.
    state = AsyncData({...state.valueOrNull ?? {}, id});
    await _repo.dismiss(id);
  }

  Future<void> clear() async {
    state = const AsyncData({});
    await _repo.clearDismissed();
  }
}

final dismissedSuggestionsProvider =
    AsyncNotifierProvider<DismissedSuggestionsNotifier, Set<String>>(
  DismissedSuggestionsNotifier.new,
);

/// Suggestions visible to the user — raw list minus dismissed.
final visibleSuggestionsProvider =
    FutureProvider<List<SuggestionModel>>((ref) async {
  final all = await ref.watch(suggestionProvider.future);
  final dismissed = await ref.watch(dismissedSuggestionsProvider.future);
  return all.where((s) => !dismissed.contains(s.id)).toList();
});
