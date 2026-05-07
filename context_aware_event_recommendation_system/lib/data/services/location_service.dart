import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../utils/app_logger.dart';

class LocationService {
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<Position?> getCurrentPosition() async {
    if (!await isLocationServiceEnabled()) return null;
    final permission = await checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  /// Reverse geocodes via Nominatim (OpenStreetMap).
  /// Falls back to a formatted coordinate string on any failure.
  Future<String?> getAddressLabel(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lon&zoom=14&addressdetails=1',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'context_aware_event_recommendation_system/1.0',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return _coordLabel(lat, lon);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) return _coordLabel(lat, lon);

      final neighbourhood =
          address['quarter'] as String? ??
          address['suburb'] as String? ??
          address['neighbourhood'] as String?;
      final city =
          address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String?;

      if (neighbourhood != null && city != null) return '$neighbourhood, $city';
      if (city != null) return city;
      if (neighbourhood != null) return neighbourhood;
      return _coordLabel(lat, lon);
    } catch (e, s) {
      AppLogger.w('[LocationService] Geocoding error', e);
      AppLogger.d('[LocationService] Geocoding stack', s);
      return _coordLabel(lat, lon);
    }
  }

  bool isGranted(LocationPermission permission) =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  static String _coordLabel(double lat, double lon) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lonDir = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}°$latDir, '
        '${lon.abs().toStringAsFixed(2)}°$lonDir';
  }
}
