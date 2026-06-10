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
        feedbackServiceProvider,
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
/// Backed by Supabase — survives app restarts.
@Riverpod(keepAlive: true)
class DismissedSuggestions extends _$DismissedSuggestions {
  String? get _uid => ref.watch(authProvider).user?.id;

  @override
  Future<Set<String>> build() async {
    final uid = _uid;
    if (uid == null) return {};
    return ref.read(feedbackServiceProvider).loadDismissedIds(uid);
  }

  void dismiss(String id) {
    if (state.value?.contains(id) ?? false) return;
    state = AsyncData({...state.value ?? {}, id});
    // DB write happens at call site via feedbackService.logAction('dismiss')
  }

  void undismiss(String id) {
    // Session-only undo — dismiss persists across restarts by design
    final updated = Set<String>.from(state.value ?? {})..remove(id);
    state = AsyncData(updated);
  }

  void clear() {
    // Called only on logout to reset in-memory state
    state = const AsyncData({});
  }
}

/// IDs of suggestions the user has explicitly disliked.
/// Loaded from Supabase on startup — persists across sessions.
@Riverpod(keepAlive: true)
class DislikedSuggestions extends _$DislikedSuggestions {
  String? get _uid => ref.watch(authProvider).user?.id;

  @override
  Future<Set<String>> build() async {
    final uid = _uid;
    if (uid == null) return {};
    return ref.read(feedbackServiceProvider).loadDislikedIds();
  }

  void dislike(String id) {
    state = AsyncData({...state.value ?? {}, id});
  }

  void undislike(String id) {
    final updated = Set<String>.from(state.value ?? {})..remove(id);
    state = AsyncData(updated);
  }
}

/// Visible suggestions = stream results minus dismissed AND disliked IDs.
/// Plain synchronous Provider — no loading flicker when new suggestions arrive.
final visibleSuggestionsProvider = Provider<List<SuggestionModel>>((ref) {
  final allAsync = ref.watch(suggestionStreamProvider);
  final dismissedAsync = ref.watch(dismissedSuggestionsProvider);
  final dislikedAsync = ref.watch(dislikedSuggestionsProvider);
  final all = allAsync.value ?? const [];
  final dismissed = dismissedAsync.value ?? const <String>{};
  final disliked = dislikedAsync.value ?? const <String>{};
  return all.where((s) => !dismissed.contains(s.id) && !disliked.contains(s.id)).toList();
});
