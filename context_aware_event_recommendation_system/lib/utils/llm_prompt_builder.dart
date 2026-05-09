import '../domain/models/llm_context_payload.dart';
import '../domain/models/place_model.dart';

/// Assembles a structured prompt string from [LlmContextPayload].
///
/// Keep the prompt compact — every token costs money and adds latency.
/// Format is optimised for instruction-following models (GPT-4o, Claude, Gemini).
abstract class LlmPromptBuilder {
  LlmPromptBuilder._();

  /// Returns the full prompt to be sent to the LLM.
  static String build(LlmContextPayload payload) {
    final buffer = StringBuffer();

    buffer.writeln(_systemInstruction());
    buffer.writeln();
    buffer.writeln(_personaSection(payload));
    buffer.writeln();
    buffer.writeln(_contextSection(payload));

    if (payload.nearbyPlaces.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(_placesSection(payload.nearbyPlaces));
    }

    buffer.writeln();
    buffer.writeln(_taskInstruction());

    return buffer.toString().trim();
  }

  static String _systemInstruction() =>
      'You are a context-aware event recommendation assistant. '
      'Suggest activities that match the user\'s personality, '
      'current situation, and nearby venues. '
      'Be concise and specific. Respond only in valid JSON.';

  static String _personaSection(LlmContextPayload p) {
    final traits = p.persona.traits
        .take(5)
        .map((t) => '${t.label} (${(t.confidence * 100).round()}%)')
        .join(', ');

    final prefs = p.persona.preferences.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}')
        .join(', ');

    return '## User Profile\n'
        'Traits: $traits\n'
        'Preferences: $prefs';
  }

  static String _contextSection(LlmContextPayload p) {
    final ctx = p.context;
    final time = _timeLabel(p.builtAt.hour);

    final lines = [
      '## Current Context',
      'Time: $time (${p.builtAt.hour}:${p.builtAt.minute.toString().padLeft(2, '0')})',
      'Activity: ${ctx.activityLabel}',
      if (ctx.locationLabel != null) 'Location: ${ctx.locationLabel}',
      if (ctx.weather != null) 'Weather: ${ctx.weather}',
    ];

    return lines.join('\n');
  }

  static String _placesSection(List<PlaceModel> places) {
    final lines = ['## Nearby Venues (within 1.5 km)'];

    for (var i = 0; i < places.length && i < 15; i++) {
      final p = places[i];
      final type = p.types.isNotEmpty ? p.types.first : 'venue';
      final dist = '${(p.distanceMeters / 1000).toStringAsFixed(1)} km';
      final rating = p.rating != null ? ' ★${p.rating!.toStringAsFixed(1)}' : '';
      final price = p.priceLevel != null ? ' ${_priceSymbol(p.priceLevel!)}' : '';
      lines.add('${i + 1}. ${p.name} — $type, $dist$rating$price');
    }

    return lines.join('\n');
  }

  static String _taskInstruction() =>
      '## Task\n'
      'Generate exactly 3 event suggestions tailored to this user.\n'
      'Return a JSON array with this shape:\n'
      '[\n'
      '  {\n'
      '    "title": "...",\n'
      '    "description": "...",\n'
      '    "rationale": "...",\n'
      '    "category": "Movement|Recharge|Learning|Social|Health",\n'
      '    "venue_name": "...",\n'
      '    "estimated_minutes": 0\n'
      '  }\n'
      ']';

  static String _timeLabel(int hour) {
    if (hour < 9) return 'Early morning';
    if (hour < 12) return 'Morning';
    if (hour < 14) return 'Lunchtime';
    if (hour < 17) return 'Afternoon';
    if (hour < 20) return 'Evening';
    return 'Night';
  }

  static String _priceSymbol(String priceLevel) => switch (priceLevel) {
        'PRICE_LEVEL_FREE' => '(free)',
        'PRICE_LEVEL_INEXPENSIVE' => r'$',
        'PRICE_LEVEL_MODERATE' => r'$$',
        'PRICE_LEVEL_EXPENSIVE' => r'$$$',
        'PRICE_LEVEL_VERY_EXPENSIVE' => r'$$$$',
        _ => '',
      };
}
