// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Raw suggestions from the repository (TTL-cached, backed by ContextService).

@ProviderFor(suggestion)
final suggestionProvider = SuggestionProvider._();

/// Raw suggestions from the repository (TTL-cached, backed by ContextService).

final class SuggestionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SuggestionModel>>,
          List<SuggestionModel>,
          FutureOr<List<SuggestionModel>>
        >
    with
        $FutureModifier<List<SuggestionModel>>,
        $FutureProvider<List<SuggestionModel>> {
  /// Raw suggestions from the repository (TTL-cached, backed by ContextService).
  SuggestionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'suggestionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suggestionHash();

  @$internal
  @override
  $FutureProviderElement<List<SuggestionModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SuggestionModel>> create(Ref ref) {
    return suggestion(ref);
  }
}

String _$suggestionHash() => r'e6c99773e82dbdbfc0bab0ea22b6d9e685011853';

/// Current ambient context (greeting, location, weather, activity).

@ProviderFor(ambientContext)
final ambientContextProvider = AmbientContextProvider._();

/// Current ambient context (greeting, location, weather, activity).

final class AmbientContextProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContextState>,
          ContextState,
          FutureOr<ContextState>
        >
    with $FutureModifier<ContextState>, $FutureProvider<ContextState> {
  /// Current ambient context (greeting, location, weather, activity).
  AmbientContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ambientContextProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ambientContextHash();

  @$internal
  @override
  $FutureProviderElement<ContextState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContextState> create(Ref ref) {
    return ambientContext(ref);
  }
}

String _$ambientContextHash() => r'7ba2f588110529f2c73bfcb23a60eb4fe452ea04';

/// Inferred persona — used by both Profile and (peripherally) Home.

@ProviderFor(persona)
final personaProvider = PersonaProvider._();

/// Inferred persona — used by both Profile and (peripherally) Home.

final class PersonaProvider
    extends
        $FunctionalProvider<
          AsyncValue<PersonaModel>,
          PersonaModel,
          FutureOr<PersonaModel>
        >
    with $FutureModifier<PersonaModel>, $FutureProvider<PersonaModel> {
  /// Inferred persona — used by both Profile and (peripherally) Home.
  PersonaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personaHash();

  @$internal
  @override
  $FutureProviderElement<PersonaModel> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PersonaModel> create(Ref ref) {
    return persona(ref);
  }
}

String _$personaHash() => r'4e5dffacec43e7a98b3c0dc652f4ea23e38e0350';

/// IDs of suggestions the user has dismissed.
/// Loads persisted state on first access; persists every change.

@ProviderFor(DismissedSuggestions)
final dismissedSuggestionsProvider = DismissedSuggestionsProvider._();

/// IDs of suggestions the user has dismissed.
/// Loads persisted state on first access; persists every change.
final class DismissedSuggestionsProvider
    extends $AsyncNotifierProvider<DismissedSuggestions, Set<String>> {
  /// IDs of suggestions the user has dismissed.
  /// Loads persisted state on first access; persists every change.
  DismissedSuggestionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dismissedSuggestionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dismissedSuggestionsHash();

  @$internal
  @override
  DismissedSuggestions create() => DismissedSuggestions();
}

String _$dismissedSuggestionsHash() =>
    r'92b15900894a82a4ed01665e85baa7f768c0cfec';

/// IDs of suggestions the user has dismissed.
/// Loads persisted state on first access; persists every change.

abstract class _$DismissedSuggestions extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Suggestions visible to the user — raw list minus dismissed.

@ProviderFor(visibleSuggestions)
final visibleSuggestionsProvider = VisibleSuggestionsProvider._();

/// Suggestions visible to the user — raw list minus dismissed.

final class VisibleSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SuggestionModel>>,
          List<SuggestionModel>,
          FutureOr<List<SuggestionModel>>
        >
    with
        $FutureModifier<List<SuggestionModel>>,
        $FutureProvider<List<SuggestionModel>> {
  /// Suggestions visible to the user — raw list minus dismissed.
  VisibleSuggestionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleSuggestionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleSuggestionsHash();

  @$internal
  @override
  $FutureProviderElement<List<SuggestionModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SuggestionModel>> create(Ref ref) {
    return visibleSuggestions(ref);
  }
}

String _$visibleSuggestionsHash() =>
    r'16eb590195a09e91955b1b44c7fee3fd4680ffca';
