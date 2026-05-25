import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';
import '../repositories/location_repository.dart';
import '../repositories/places_repository.dart';
import '../services/weather_service.dart' show WeatherData, WeatherService;

class LlmService {
  LlmService(
    this._supabase,
    this._location,
    this._weather,
    this._places, {
    required String supabaseUrl,
    required String supabaseAnonKey,
  })  : _functionUrl = '$supabaseUrl/functions/v1/recommend',
        _supabaseAnonKey = supabaseAnonKey;

  final SupabaseClient _supabase;
  final LocationRepository _location;
  final WeatherService _weather;
  final PlacesRepository _places;
  final String _functionUrl;
  final String _supabaseAnonKey;

  // ── Public API ────────────────────────────────────────────────────────────

  /// SSE streaming — yields each suggestion as it arrives from the LLM.
  Stream<SuggestionModel> getSuggestionsStream() {
    return _streamSuggestions();
  }

  /// Non-streaming fallback — awaits the full SSE stream and returns the list.
  Future<List<SuggestionModel>> getSuggestions() async {
    final results = <SuggestionModel>[];
    await for (final s in _streamSuggestions()) {
      results.add(s);
    }
    return results;
  }

  // ── Implementation ────────────────────────────────────────────────────────

  Stream<SuggestionModel> _streamSuggestions() async* {
    final position = await _location.getCurrentPosition();
    final lat = position?.latitude ?? 41.0082;
    final lng = position?.longitude ?? 28.9784;

    // Start both fetches in parallel, then await each with correct types
    final weatherFuture = position != null
        ? _weather.getCurrentWeather(lat, lng)
        : Future<WeatherData?>.value(null);
    final placesFuture = _places.getNearbyPlaces();

    final weatherData = await weatherFuture;
    final nearbyPlaces = await placesFuture;

    final locationLabel = position != null
        ? await _location.getAddressLabel(lat, lng)
        : null;

    final city = _extractCity(locationLabel) ?? 'Istanbul';
    final now = DateTime.now();

    final placesPayload = nearbyPlaces
        .map(
          (p) => <String, dynamic>{
            'id': p.id,
            'name': p.name,
            'types': p.types,
            'distance_m': (p.distanceMeters as num).round(),
            if (p.address != null) 'address': p.address,
            if (p.rating != null) 'rating': p.rating,
            if (p.priceLevel != null) 'price_level': p.priceLevel,
          },
        )
        .toList();

    AppLogger.i('[LlmService] ${nearbyPlaces.length} places loaded, city=$city');

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

    // Get user JWT for auth header
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('[LlmService] Not authenticated');

    AppLogger.i(
      '[LlmService] SSE stream start — city=$city '
      'weather=${weatherData?.condition ?? 'unknown'} hour=${now.hour}',
    );

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(_functionUrl));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['apikey'] = _supabaseAnonKey;
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode(body);

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception(
          '[LlmService] Edge Function error ${streamedResponse.statusCode}: $errorBody',
        );
      }

      // SSE parser state
      String? currentEvent;
      String? currentData;
      var lineBuffer = '';

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        lineBuffer += chunk;

        while (true) {
          final newlineIdx = lineBuffer.indexOf('\n');
          if (newlineIdx == -1) break;

          final line = lineBuffer.substring(0, newlineIdx);
          lineBuffer = lineBuffer.substring(newlineIdx + 1);
          final trimmed = line.trimRight();

          if (trimmed.isEmpty) {
            // Blank line = event separator
            if (currentEvent != null && currentData != null) {
              yield* _handleSseEvent(currentEvent, currentData);
            }
            currentEvent = null;
            currentData = null;
          } else if (trimmed.startsWith('event: ')) {
            currentEvent = trimmed.substring(7);
          } else if (trimmed.startsWith('data: ')) {
            currentData = trimmed.substring(6);
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Stream<SuggestionModel> _handleSseEvent(
    String event,
    String data,
  ) async* {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      if (event == 'suggestion') {
        final suggestionJson = json['suggestion'] as Map<String, dynamic>;
        final cacheHit = json['cache_hit'] as bool? ?? false;
        final provider = json['llm_provider'] as String? ?? 'unknown';
        final index = json['index'] as int? ?? 0;
        final suggestion = _parseSuggestion(suggestionJson);

        AppLogger.i(
          '[LlmService] SSE[$index] ${suggestion.title} '
          '(provider=$provider cacheHit=$cacheHit)',
        );
        yield suggestion;
      } else if (event == 'done') {
        AppLogger.i(
          '[LlmService] SSE done — latency=${json['latency_ms']}ms '
          'total=${json['total']} cacheHit=${json['cache_hit']}',
        );
      } else if (event == 'error') {
        throw Exception('[LlmService] LLM error: ${json['error']}');
      }
    } catch (e) {
      if (event == 'error') rethrow;
      AppLogger.e('[LlmService] SSE event parse error (event=$event)', e);
    }
  }

  // ── Parsers / helpers ─────────────────────────────────────────────────────

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
