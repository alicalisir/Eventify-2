import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/persona_model.dart';
import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';

class BackendService {
  BackendService(this._baseUrl);

  final String _baseUrl;
  static const _timeout = Duration(seconds: 15);

  Future<PersonaModel?> getPersona(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/persona/$userId');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        AppLogger.w('[Backend] getPersona HTTP ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PersonaModel(
        traits: (json['traits'] as List<dynamic>)
            .map((t) {
              final trait = t as Map<String, dynamic>;
              return PersonaTrait(
                label: trait['label'] as String,
                confidence: (trait['confidence'] as num).toDouble(),
              );
            })
            .toList(),
        preferences: Map<String, double>.from(
          (json['preferences'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        ),
        lastUpdated: DateTime.parse(json['last_updated'] as String),
        signalsProcessedToday: json['signals_processed_today'] as int? ?? 0,
      );
    } catch (e) {
      AppLogger.w('[Backend] getPersona failed', e);
      return null;
    }
  }

  Future<List<SuggestionModel>> getRecommendations(
    String userId, {
    double? lat,
    double? lon,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl/api/recommendations/$userId');
      if (lat != null && lon != null) {
        uri = uri.replace(queryParameters: {
          'lat': lat.toStringAsFixed(6),
          'lon': lon.toStringAsFixed(6),
        });
      }
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        AppLogger.w('[Backend] getRecommendations HTTP ${response.statusCode}');
        return [];
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((raw) {
        final m = raw as Map<String, dynamic>;
        return SuggestionModel(
          id: m['id'] as String,
          title: m['title'] as String,
          description: m['description'] as String,
          rationale: m['rationale'] as String,
          category: m['category'] as String,
          distance: (m['distance'] as num?)?.toDouble(),
          estimatedMinutes: m['estimated_minutes'] as int?,
          address: m['address'] as String?,
          latitude: (m['latitude'] as num?)?.toDouble(),
          longitude: (m['longitude'] as num?)?.toDouble(),
          tags: (m['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
          weather: m['weather'] as String?,
          createdAt: DateTime.parse(m['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      AppLogger.w('[Backend] getRecommendations failed', e);
      return [];
    }
  }
}
