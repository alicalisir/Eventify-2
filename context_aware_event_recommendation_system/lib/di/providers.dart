import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/context_repository.dart';
import '../data/repositories/location_repository.dart';
import '../data/repositories/suggestion_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/context_service.dart';
import '../data/services/location_service.dart';

/// Bootstrapped in main.dart via ProviderScope.overrides before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(locationServiceProvider));
});

final contextServiceProvider = Provider<ContextService>(
  (ref) => ContextService(),
);

final contextRepositoryProvider = Provider<ContextRepository>((ref) {
  return ContextRepository(
    ref.watch(contextServiceProvider),
    ref.watch(locationRepositoryProvider),
  );
});

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return SuggestionRepository(
    ref.watch(contextServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
