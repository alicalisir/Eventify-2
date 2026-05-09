import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../domain/models/place_model.dart';
import '../../utils/app_logger.dart';

class PlacesService {
  PlacesService(this._apiKey);

  final String _apiKey;

  static const _baseUrl =
      'https://places.googleapis.com/v1/places:searchNearby';

  // Fields requested from the API — only what's needed to keep costs low.
  static const _fieldMask =
      'places.id,places.displayName,places.types,'
      'places.rating,places.priceLevel,places.location,'
      'places.shortFormattedAddress';

  static const _ttl = Duration(minutes: 30);

  final Map<String, _CacheEntry> _cache = {};

  /// Returns nearby places within [radiusMeters] of the given coordinates.
  ///
  /// [includedTypes] filters by Google Places type (e.g. "restaurant", "park").
  /// Pass an empty list to fetch all venue types relevant for event suggestions.
  Future<List<PlaceModel>> getNearbyPlaces({
    required double lat,
    required double lon,
    int radiusMeters = 1500,
    List<String> includedTypes = const [
      'restaurant',
      'cafe',
      'bar',
      'night_club',
      'park',
      'museum',
      'art_gallery',
      'movie_theater',
      'performing_arts_theater',
      'sports_complex',
      'shopping_mall',
    ],
  }) async {
    if (_apiKey.isEmpty) {
      AppLogger.w('[Places] No API key configured — skipping places fetch');
      return [];
    }

    final key =
        '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}_${radiusMeters}_'
        '${includedTypes.join(',')}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      AppLogger.d('[Places] Cache hit for ($lat, $lon) r=${radiusMeters}m');
      return cached.places;
    }

    try {
      final body = jsonEncode({
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lon},
            'radius': radiusMeters.toDouble(),
          },
        },
        if (includedTypes.isNotEmpty) 'includedTypes': includedTypes,
        'maxResultCount': 20,
        'rankPreference': 'DISTANCE',
      });

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        AppLogger.w(
          '[Places] API returned ${response.statusCode}: ${response.body}',
        );
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawPlaces = (json['places'] as List<dynamic>?) ?? [];

      final places = rawPlaces
          .map((raw) => _parsePlaceModel(raw as Map<String, dynamic>, lat, lon))
          .whereType<PlaceModel>()
          .toList();

      _cache[key] =
          _CacheEntry(places: places, expiresAt: DateTime.now().add(_ttl));

      AppLogger.i(
        '[Places] Fetched ${places.length} places near ($lat, $lon)',
      );
      return places;
    } catch (e, s) {
      AppLogger.w('[Places] Failed to fetch nearby places', e);
      AppLogger.d('[Places] Stack', s);
      return [];
    }
  }

  PlaceModel? _parsePlaceModel(
    Map<String, dynamic> raw,
    double userLat,
    double userLon,
  ) {
    try {
      final id = raw['id'] as String? ?? '';
      final displayName = raw['displayName'] as Map<String, dynamic>?;
      final name = displayName?['text'] as String? ?? '';
      final types =
          (raw['types'] as List<dynamic>?)?.cast<String>() ?? <String>[];
      final location = raw['location'] as Map<String, dynamic>?;
      final placeLat = (location?['latitude'] as num?)?.toDouble() ?? 0;
      final placeLon = (location?['longitude'] as num?)?.toDouble() ?? 0;
      final address = raw['shortFormattedAddress'] as String?;
      final rating = (raw['rating'] as num?)?.toDouble();
      final priceLevel = raw['priceLevel'] as String?;

      final distanceMeters =
          _haversineMeters(userLat, userLon, placeLat, placeLon);

      if (id.isEmpty || name.isEmpty) return null;

      return PlaceModel(
        id: id,
        name: name,
        types: types,
        latitude: placeLat,
        longitude: placeLon,
        distanceMeters: distanceMeters,
        address: address,
        rating: rating,
        priceLevel: priceLevel,
      );
    } catch (e) {
      AppLogger.w('[Places] Failed to parse place: $e');
      return null;
    }
  }

  /// Haversine formula — straight-line distance in metres.
  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  double _toRad(double deg) => deg * math.pi / 180;
}

class _CacheEntry {
  const _CacheEntry({required this.places, required this.expiresAt});

  final List<PlaceModel> places;
  final DateTime expiresAt;
}
