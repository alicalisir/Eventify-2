import 'dart:math' as math;

import '../../domain/models/place_model.dart';
import '../../utils/app_logger.dart';
import '../services/places_service.dart';
import 'location_repository.dart';

class PlacesRepository {
  PlacesRepository(this._service, this._location);

  final PlacesService _service;
  final LocationRepository _location;

  List<PlaceModel>? _cachedPlaces;
  DateTime? _placesExpiresAt;
  double? _cachedLat;
  double? _cachedLon;

  // Cache is invalidated when user moves more than this distance.
  static const _locationDriftThresholdMeters = 300.0;

  /// Returns nearby places for the current user location.
  ///
  /// Cache is reused if the position hasn't drifted beyond
  /// [_locationDriftThresholdMeters] and the TTL hasn't expired.
  /// On permission failure or network error, returns an empty list.
  Future<List<PlaceModel>> getNearbyPlaces({
    int radiusMeters = 1500,
    List<String> includedTypes = const [],
  }) async {
    final position = await _location.getCurrentPosition();
    if (position == null) {
      AppLogger.w('[Places] No position available — skipping places fetch');
      return [];
    }

    final lat = position.latitude;
    final lon = position.longitude;
    final now = DateTime.now();

    if (_isCacheValid(lat, lon, now)) {
      AppLogger.d('[Places] Repository cache hit near ($lat, $lon)');
      return _cachedPlaces!;
    }

    final places = await _service.getNearbyPlaces(
      lat: lat,
      lon: lon,
      radiusMeters: radiusMeters,
      includedTypes: includedTypes,
    );

    _cachedPlaces = places;
    _placesExpiresAt = now.add(const Duration(minutes: 30));
    _cachedLat = lat;
    _cachedLon = lon;

    AppLogger.i(
      '[Places] Repository stored ${places.length} places '
      'near ($lat, $lon)',
    );
    return places;
  }

  void invalidate() {
    _cachedPlaces = null;
    _placesExpiresAt = null;
    _cachedLat = null;
    _cachedLon = null;
    AppLogger.d('[Places] Cache invalidated');
  }

  bool _isCacheValid(double lat, double lon, DateTime now) {
    if (_cachedPlaces == null ||
        _placesExpiresAt == null ||
        _cachedLat == null ||
        _cachedLon == null) {
      return false;
    }
    if (now.isAfter(_placesExpiresAt!)) return false;
    final drift = _haversineMeters(_cachedLat!, _cachedLon!, lat, lon);
    if (drift > _locationDriftThresholdMeters) {
      AppLogger.d(
        '[Places] Position drifted ${drift.toStringAsFixed(0)}m — cache invalid',
      );
      return false;
    }
    return true;
  }

  // Equirectangular approximation — accurate enough for <5 km drift checks.
  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final midLat = (lat1 + lat2) / 2 * math.pi / 180;
    final x = dLon * math.cos(midLat);
    return r * math.sqrt(dLat * dLat + x * x);
  }
}
