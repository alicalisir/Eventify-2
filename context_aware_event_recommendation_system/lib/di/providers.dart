import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/context_repository.dart';
import '../data/repositories/suggestion_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/context_service.dart';

part 'providers.g.dart';

/// Bootstrapped in main.dart via ProviderScope.overrides before runApp.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
}

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
}

@Riverpod(keepAlive: true)
ContextService contextService(Ref ref) => ContextService();

@Riverpod(keepAlive: true)
ContextRepository contextRepository(Ref ref) {
  return ContextRepository(ref.watch(contextServiceProvider));
}

@Riverpod(keepAlive: true)
SuggestionRepository suggestionRepository(Ref ref) {
  return SuggestionRepository(
    ref.watch(contextServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
}
