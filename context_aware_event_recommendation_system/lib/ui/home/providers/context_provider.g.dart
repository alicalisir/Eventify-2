// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
/// Backed by Supabase — survives app restarts.

@ProviderFor(DismissedSuggestions)
final dismissedSuggestionsProvider = DismissedSuggestionsProvider._();

/// IDs of suggestions the user has dismissed.
/// Backed by Supabase — survives app restarts.
final class DismissedSuggestionsProvider
    extends $AsyncNotifierProvider<DismissedSuggestions, Set<String>> {
  /// IDs of suggestions the user has dismissed.
  /// Backed by Supabase — survives app restarts.
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
    r'966dc5dd524fe292f2bd084e4ad7ef7e5a9a4dc7';

/// IDs of suggestions the user has dismissed.
/// Backed by Supabase — survives app restarts.

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

/// IDs of suggestions the user has explicitly disliked.
/// Loaded from Supabase on startup — persists across sessions.

@ProviderFor(DislikedSuggestions)
final dislikedSuggestionsProvider = DislikedSuggestionsProvider._();

/// IDs of suggestions the user has explicitly disliked.
/// Loaded from Supabase on startup — persists across sessions.
final class DislikedSuggestionsProvider
    extends $AsyncNotifierProvider<DislikedSuggestions, Set<String>> {
  /// IDs of suggestions the user has explicitly disliked.
  /// Loaded from Supabase on startup — persists across sessions.
  DislikedSuggestionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dislikedSuggestionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dislikedSuggestionsHash();

  @$internal
  @override
  DislikedSuggestions create() => DislikedSuggestions();
}

String _$dislikedSuggestionsHash() =>
    r'd65d0e3eff0462dad7fa9d7f3560511319e4481e';

/// IDs of suggestions the user has explicitly disliked.
/// Loaded from Supabase on startup — persists across sessions.

abstract class _$DislikedSuggestions extends $AsyncNotifier<Set<String>> {
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
