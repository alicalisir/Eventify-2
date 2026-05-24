/// Smoke test — calls the real Google Places API with Kocaeli (İzmit) coordinates.
/// Run with: dart run test/places_api_smoke_test.dart
///
/// Standalone — no Flutter dependency. Reads API key directly from .env.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final apiKey = _readEnvKey('GOOGLE_PLACES_API_KEY');
  if (apiKey.isEmpty) _fail('GOOGLE_PLACES_API_KEY is empty in .env');

  const lat = 40.7654; // İzmit centre
  const lon = 29.9408;
  const radius = 1500;

  print('🔍 Fetching places near ($lat, $lon) — Kocaeli/İzmit, radius: ${radius}m ...\n');

  final response = await http
      .post(
        Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.types,'
              'places.rating,places.priceLevel,places.location,'
              'places.shortFormattedAddress',
        },
        body: jsonEncode({
          'locationRestriction': {
            'circle': {
              'center': {'latitude': lat, 'longitude': lon},
              'radius': radius.toDouble(),
            },
          },
          'includedTypes': [
            'restaurant', 'cafe', 'bar', 'park',
            'museum', 'movie_theater', 'sports_complex',
          ],
          'maxResultCount': 20,
          'rankPreference': 'DISTANCE',
        }),
      )
      .timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    _fail('API returned ${response.statusCode}: ${response.body}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final places = (json['places'] as List<dynamic>?) ?? [];

  if (places.isEmpty) {
    _fail('API returned 0 places — check API key, billing, or Places API (New) activation.');
  }

  print('✅ ${places.length} places returned\n');
  print('─' * 60);

  for (final raw in places) {
    final p = raw as Map<String, dynamic>;
    final name = (p['displayName'] as Map?)?.entries.first.value ?? '—';
    final types = (p['types'] as List?)?.cast<String>() ?? [];
    final type = types.isNotEmpty ? types.first : '—';
    final location = p['location'] as Map?;
    final pLat = (location?['latitude'] as num?)?.toDouble() ?? 0;
    final pLon = (location?['longitude'] as num?)?.toDouble() ?? 0;
    final dist = _distMeters(lat, lon, pLat, pLon);
    final rating = p['rating'] != null ? ' ★${p['rating']}' : '';
    final price = p['priceLevel'] != null ? ' ${_price(p['priceLevel'] as String)}' : '';
    final addr = p['shortFormattedAddress'] as String?;

    print('  $name');
    print('    type: $type | dist: ${dist.toStringAsFixed(0)}m$rating$price');
    if (addr != null) print('    addr: $addr');
    print('');
  }

  print('─' * 60);
  print('✅ Smoke test passed — Places API (New) is working correctly.\n');
  exit(0);
}

String _readEnvKey(String key) {
  final envFile = File('.env');
  if (!envFile.existsSync()) _fail('.env file not found');
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('#') || !trimmed.contains('=')) continue;
    final idx = trimmed.indexOf('=');
    if (trimmed.substring(0, idx).trim() == key) {
      return trimmed.substring(idx + 1).trim();
    }
  }
  return '';
}

double _distMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
  final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
  final midLat = (lat1 + lat2) / 2 * 3.141592653589793 / 180;
  final x = dLon * _cos(midLat);
  return r * _sqrt(dLat * dLat + x * x);
}

double _cos(double x) {
  var result = 1.0, term = 1.0;
  for (var i = 1; i <= 10; i++) {
    term *= -x * x / (2 * i * (2 * i - 1));
    result += term;
  }
  return result;
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  var r = x;
  for (var i = 0; i < 20; i++) r = (r + x / r) / 2;
  return r;
}

String _price(String level) => switch (level) {
      'PRICE_LEVEL_FREE' => '(free)',
      'PRICE_LEVEL_INEXPENSIVE' => r'$',
      'PRICE_LEVEL_MODERATE' => r'$$',
      'PRICE_LEVEL_EXPENSIVE' => r'$$$',
      'PRICE_LEVEL_VERY_EXPENSIVE' => r'$$$$',
      _ => level,
    };

Never _fail(String msg) {
  print('❌ $msg');
  exit(1);
}
