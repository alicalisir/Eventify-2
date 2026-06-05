import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/context_repository.dart';
import '../data/repositories/location_repository.dart';
import '../data/repositories/places_repository.dart';
import '../data/repositories/suggestion_repository.dart';
import '../data/services/app_usage_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/backend_service.dart';
import '../data/services/context_service.dart';
import '../data/services/feedback_service.dart';
import '../data/services/gps_collection_service.dart';
import '../data/services/llm_service.dart';
import '../data/services/location_service.dart';
import '../data/services/places_service.dart';
import '../data/services/screen_event_service.dart';
import '../data/services/weather_service.dart';
import '../domain/models/suggestion_model.dart';

/// Bootstrapped in main.dart via ProviderScope.overrides before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider));
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(locationServiceProvider));
});

final backendServiceProvider = Provider<BackendService>((ref) {
  final url = dotenv.env['BACKEND_URL'] ?? '';
  return BackendService(url);
});

final contextServiceProvider = Provider<ContextService>((ref) {
  return ContextService(
    ref.watch(backendServiceProvider),
    ref.watch(supabaseClientProvider),
    ref.watch(locationRepositoryProvider),
  );
});

final appUsageServiceProvider = Provider<AppUsageService>((ref) {
  return AppUsageService(ref.watch(supabaseClientProvider));
});

final screenEventServiceProvider = Provider<ScreenEventService>((ref) {
  return ScreenEventService(ref.watch(supabaseClientProvider));
});

final gpsCollectionServiceProvider = Provider<GpsCollectionService>((ref) {
  final service = GpsCollectionService(
    ref.watch(supabaseClientProvider),
    ref.watch(appUsageServiceProvider),
    ref.watch(screenEventServiceProvider),
  );
  ref.onDispose(service.stop);
  return service;
});

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService(dotenv.env['OPENWEATHER_API_KEY'] ?? '');
});

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService(dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '');
});

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository(
    ref.watch(placesServiceProvider),
    ref.watch(locationRepositoryProvider),
  );
});

final contextRepositoryProvider = Provider<ContextRepository>((ref) {
  return ContextRepository(
    ref.watch(contextServiceProvider),
    ref.watch(locationRepositoryProvider),
    ref.watch(weatherServiceProvider),
    ref.watch(placesRepositoryProvider),
  );
});

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(ref.watch(supabaseClientProvider));
});

final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService(
    ref.watch(supabaseClientProvider),
    ref.watch(locationRepositoryProvider),
    ref.watch(weatherServiceProvider),
    ref.watch(placesRepositoryProvider),
    supabaseUrl: dotenv.env['SUPABASE_URL'] ?? '',
    supabaseAnonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
});

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return SuggestionRepository(
    ref.watch(contextServiceProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(contextRepositoryProvider),
    ref.watch(llmServiceProvider),
  );
});

// ─── Streaming suggestion providers ──────────────────────────────────────────

/// Progressive suggestion loader — starts as AsyncLoading, grows as each
/// suggestion arrives via SSE, completing when the stream closes.
final suggestionStreamProvider =
    AsyncNotifierProvider<SuggestionStreamNotifier, List<SuggestionModel>>(
  SuggestionStreamNotifier.new,
);

class SuggestionStreamNotifier
    extends AsyncNotifier<List<SuggestionModel>> {
  @override
  Future<List<SuggestionModel>> build() async {
    final accumulated = <SuggestionModel>[];

    await for (final s
        in ref.read(suggestionRepositoryProvider).getSuggestionsStream()) {
      accumulated.add(s);
      // Progressively expose each card as it arrives
      state = AsyncData(List.unmodifiable(accumulated));
    }

    return accumulated;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

// visibleSuggestionsProvider is defined in context_provider.dart
// (it needs dismissedSuggestionsProvider which lives there).
