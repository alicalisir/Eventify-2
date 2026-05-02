// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$suggestionHash() => r'e6c99773e82dbdbfc0bab0ea22b6d9e685011853';

/// Raw suggestions from the repository (TTL-cached, backed by ContextService).
///
/// Copied from [suggestion].
@ProviderFor(suggestion)
final suggestionProvider =
    AutoDisposeFutureProvider<List<SuggestionModel>>.internal(
      suggestion,
      name: r'suggestionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$suggestionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SuggestionRef = AutoDisposeFutureProviderRef<List<SuggestionModel>>;
String _$ambientContextHash() => r'7ba2f588110529f2c73bfcb23a60eb4fe452ea04';

/// Current ambient context (greeting, location, weather, activity).
///
/// Copied from [ambientContext].
@ProviderFor(ambientContext)
final ambientContextProvider = AutoDisposeFutureProvider<ContextState>.internal(
  ambientContext,
  name: r'ambientContextProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ambientContextHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AmbientContextRef = AutoDisposeFutureProviderRef<ContextState>;
String _$personaHash() => r'4e5dffacec43e7a98b3c0dc652f4ea23e38e0350';

/// Inferred persona — used by both Profile and (peripherally) Home.
///
/// Copied from [persona].
@ProviderFor(persona)
final personaProvider = AutoDisposeFutureProvider<PersonaModel>.internal(
  persona,
  name: r'personaProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$personaHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PersonaRef = AutoDisposeFutureProviderRef<PersonaModel>;
String _$visibleSuggestionsHash() =>
    r'16eb590195a09e91955b1b44c7fee3fd4680ffca';

/// Suggestions visible to the user — raw list minus dismissed.
///
/// Copied from [visibleSuggestions].
@ProviderFor(visibleSuggestions)
final visibleSuggestionsProvider =
    AutoDisposeFutureProvider<List<SuggestionModel>>.internal(
      visibleSuggestions,
      name: r'visibleSuggestionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visibleSuggestionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VisibleSuggestionsRef =
    AutoDisposeFutureProviderRef<List<SuggestionModel>>;
String _$dismissedSuggestionsHash() =>
    r'92b15900894a82a4ed01665e85baa7f768c0cfec';

/// IDs of suggestions the user has dismissed.
/// Loads persisted state on first access; persists every change.
///
/// Copied from [DismissedSuggestions].
@ProviderFor(DismissedSuggestions)
final dismissedSuggestionsProvider =
    AsyncNotifierProvider<DismissedSuggestions, Set<String>>.internal(
      DismissedSuggestions.new,
      name: r'dismissedSuggestionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dismissedSuggestionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DismissedSuggestions = AsyncNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
