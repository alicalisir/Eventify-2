import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suggestion provider - manages suggestions state
/// This provider handles all suggestion-related state and operations
final suggestionProvider = StateNotifierProvider<SuggestionNotifier, SuggestionState>((ref) {
  return SuggestionNotifier();
});

class SuggestionState {
  final List<dynamic> suggestions;
  final bool isLoading;
  final String? error;

  const SuggestionState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
  });

  SuggestionState copyWith({
    List<dynamic>? suggestions,
    bool? isLoading,
    String? error,
  }) {
    return SuggestionState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SuggestionNotifier extends StateNotifier<SuggestionState> {
  SuggestionNotifier() : super(const SuggestionState());

  void setSuggestions(List<dynamic> suggestions) {
    state = state.copyWith(suggestions: suggestions, isLoading: false);
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  void clear() {
    state = const SuggestionState();
  }
}
