import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';
import '../repositories/location_repository.dart';
import '../repositories/places_repository.dart';
import '../services/weather_service.dart' show WeatherData, WeatherService;

class LlmService {
  LlmService(this._supabase, this._location, this._weather, this._places);

  final SupabaseClient _supabase;
  final LocationRepository _location;
  final WeatherService _weather;
  final PlacesRepository _places;

  Future<List<SuggestionModel>> getSuggestions() async {
    final position = await _location.getCurrentPosition();

    final lat = position?.latitude ?? 41.0082;
    final lng = position?.longitude ?? 28.9784;

    // Weather ve places paralel çalışsın
    final weatherFuture = position != null
        ? _weather.getCurrentWeather(lat, lng)
        : Future<WeatherData?>.value(null);
    final placesFuture = _places.getNearbyPlaces();

    final WeatherData? weatherData = await weatherFuture;
    final nearbyPlaces = await placesFuture;

    final locationLabel = position != null
        ? await _location.getAddressLabel(lat, lng)
        : null;

    final city = _extractCity(locationLabel) ?? 'İstanbul';
    final now = DateTime.now();

    final placesPayload = nearbyPlaces
        .map(
          (p) => <String, dynamic>{
            'id': p.id,
            'name': p.name,
            'types': p.types,
            'distance_m': p.distanceMeters.round(),
            if (p.address != null) 'address': p.address,
            if (p.rating != null) 'rating': p.rating,
            if (p.priceLevel != null) 'price_level': p.priceLevel,
          },
        )
        .toList();

    AppLogger.i(
      '[LlmService] ${nearbyPlaces.length} mekan yüklendi '
      '(places API)',
    );

    final body = {
      'lat': lat,
      'lng': lng,
      'city': city,
      'weather_condition': weatherData?.condition ?? 'clear',
      'weather_temp_c': weatherData?.temperature ?? 20,
      'hour': now.hour,
      'day_of_week': now.weekday - 1,
      'motion_state': _motionState(position?.speed ?? 0),
      'user_interests': <String>[],
      'recent_dismissed_titles': <String>[],
      'recent_liked_categories': <String>[],
      'nearby_places': placesPayload,
    };

    AppLogger.i(
      '[LlmService] recommend çağrılıyor — city=$city '
      'weather=${weatherData?.condition ?? 'unknown'} '
      'hour=${now.hour}',
    );

    final response = await _supabase.functions.invoke(
      'recommend',
      body: body,
    );

    if (response.status != 200) {
      AppLogger.e(
        '[LlmService] Edge Function hata: ${response.status}',
        response.data,
      );
      throw Exception('recommend fonksiyonu başarısız: ${response.status}');
    }

    final data = response.data as Map<String, dynamic>;
    final rawList = data['suggestions'] as List<dynamic>? ?? [];
    final provider = data['llm_provider'] as String? ?? 'unknown';
    final cacheHit = data['cache_hit'] as bool? ?? false;
    final latencyMs = data['latency_ms'] as int? ?? 0;

    AppLogger.i(
      '[LlmService] ${rawList.length} öneri alındı — '
      'provider=$provider cacheHit=$cacheHit latency=${latencyMs}ms',
    );

    return rawList
        .map((s) => _parseSuggestion(s as Map<String, dynamic>))
        .toList();
  }

  static SuggestionModel _parseSuggestion(Map<String, dynamic> s) {
    final distanceM = (s['distance_m'] as num?)?.toDouble();
    final signals = (s['rationale_signals'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    return SuggestionModel(
      id: s['id'] as String? ?? 's${DateTime.now().millisecondsSinceEpoch}',
      title: s['title'] as String? ?? '',
      description: s['rationale'] as String? ?? '',
      rationale: s['rationale'] as String? ?? '',
      category: s['category'] as String? ?? 'culture',
      distance: distanceM != null && distanceM > 0 ? distanceM / 1000 : null,
      address: s['venue_name'] as String?,
      tags: signals,
      createdAt: DateTime.now(),
    );
  }

  // "Kadıköy, İstanbul" → "İstanbul"; "İstanbul" → "İstanbul"
  static String? _extractCity(String? label) {
    if (label == null) return null;
    final parts = label.split(', ');
    return parts.last.trim();
  }

  static String _motionState(double speed) {
    if (speed > 8) return 'driving';
    if (speed > 1.5) return 'walking';
    return 'stationary';
  }
}
