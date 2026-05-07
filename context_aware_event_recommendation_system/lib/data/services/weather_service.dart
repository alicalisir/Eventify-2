import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/app_logger.dart';

class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.condition,
    required this.summary,
  });

  /// Celsius, rounded.
  final int temperature;

  /// Lowercase OWM main condition: "clear", "clouds", "rain", "snow", etc.
  final String condition;

  /// Human-readable summary shown in the UI: "21° • Clear".
  final String summary;
}

class WeatherService {
  WeatherService(this._apiKey);

  final String _apiKey;

  static const _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  static const _ttl = Duration(minutes: 15);

  final Map<String, _CacheEntry> _cache = {};

  Future<WeatherData?> getCurrentWeather(double lat, double lon) async {
    if (_apiKey.isEmpty) {
      AppLogger.w('[Weather] No API key configured — skipping weather fetch');
      return null;
    }

    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      AppLogger.d('[Weather] Cache hit for $key');
      return cached.data;
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'units': 'metric',
          'appid': _apiKey,
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        AppLogger.w('[Weather] API returned ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final main = json['main'] as Map<String, dynamic>;
      final temp = (main['temp'] as num).round();
      final weatherList = json['weather'] as List<dynamic>;
      final conditionRaw =
          (weatherList.first as Map<String, dynamic>)['main'] as String;

      final data = WeatherData(
        temperature: temp,
        condition: conditionRaw.toLowerCase(),
        summary: '$temp° • $conditionRaw',
      );

      _cache[key] = _CacheEntry(data: data, expiresAt: DateTime.now().add(_ttl));
      AppLogger.i('[Weather] Fetched: ${data.summary} @ ($lat, $lon)');
      return data;
    } catch (e, s) {
      AppLogger.w('[Weather] Failed to fetch weather', e);
      AppLogger.d('[Weather] Stack', s);
      return null;
    }
  }
}

class _CacheEntry {
  const _CacheEntry({required this.data, required this.expiresAt});

  final WeatherData data;
  final DateTime expiresAt;
}
