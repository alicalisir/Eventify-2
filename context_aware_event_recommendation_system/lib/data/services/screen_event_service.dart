import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/app_logger.dart';

/// Starts/stops the Android native ScreenEventService and periodically
/// flushes buffered screen events (on/off/unlock) to Supabase.
///
/// The native service listens to ACTION_SCREEN_ON/OFF/USER_PRESENT broadcasts
/// via a ForegroundService, storing events in SharedPreferences.
/// This class reads them via MethodChannel and uploads to `screen_events`.
class ScreenEventService {
  static const _screenChannel   = MethodChannel('com.example.caers/screen_events');
  static const _activityChannel = MethodChannel('com.example.caers/activity_recognition');

  ScreenEventService(this._client);

  final SupabaseClient _client;

  Future<void> start() async {
    try {
      await _screenChannel.invokeMethod<void>('startService');
      await _activityChannel.invokeMethod<void>('startTracking');
      AppLogger.i('[ScreenEvents] Native services started');
    } catch (e) {
      AppLogger.w('[ScreenEvents] Could not start native services', e);
    }
  }

  Future<void> stop() async {
    try {
      await _screenChannel.invokeMethod<void>('stopService');
      await _activityChannel.invokeMethod<void>('stopTracking');
    } catch (e) {
      AppLogger.w('[ScreenEvents] Could not stop native services', e);
    }
  }

  /// Reads buffered events from SharedPreferences, uploads to Supabase, then clears.
  Future<void> flush(String userId) async {
    try {
      final raw = await _screenChannel.invokeMethod<String>('getPendingEvents') ?? '[]';
      final events = (jsonDecode(raw) as List<dynamic>);
      if (events.isEmpty) return;

      final rows = events
          .cast<Map<dynamic, dynamic>>()
          .map((e) => {
                'user_id': userId,
                'timestamp': e['timestamp'] as String,
                'event_type': e['event_type'] as String,
              })
          .toList();

      await _client.from('screen_events').insert(rows);
      await _screenChannel.invokeMethod<void>('clearEvents');
      AppLogger.i('[ScreenEvents] Flushed ${rows.length} real screen events');
    } catch (e) {
      AppLogger.w('[ScreenEvents] Flush failed', e);
    }
  }

  /// Returns the current movement state detected by Android Activity Recognition.
  /// Falls back to null if unavailable (caller uses GPS speed instead).
  Future<String?> getCurrentActivityState() async {
    try {
      return await _activityChannel
          .invokeMethod<String>('getCurrentActivity')
          .timeout(const Duration(seconds: 1));
    } catch (_) {
      return null;
    }
  }
}
