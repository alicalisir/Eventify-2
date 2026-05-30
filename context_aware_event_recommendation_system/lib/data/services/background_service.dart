import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/app_logger.dart';

const _kUserIdKey = 'current_user_id';
const _kSupabaseUrl = 'supabase_url';
const _kSupabaseKey = 'supabase_anon_key';
const _kStationaryStartKey = 'stationary_start_ts';

// Tick-level state — safe in background isolate (each isolate has own globals)
int _tickCount = 0;
DateTime? _stationaryStart;

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'caers_bg_service',
      initialNotificationTitle: 'Bağlam takibi aktif',
      initialNotificationContent: 'Arka planda veri toplanıyor',
      foregroundServiceNotificationId: 1002,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final url = prefs.getString(_kSupabaseUrl);
  final key = prefs.getString(_kSupabaseKey);

  if (url == null || key == null) {
    // Credentials not stored yet (auto-start before first app launch).
    // The timer below will keep ticking; once the user logs in and main app
    // stores credentials, the next reload() will find them.
    AppLogger.w('[BgService] Supabase credentials not set yet — waiting for first login');
    // Run a lightweight loop that retries until credentials appear
    Timer.periodic(const Duration(seconds: 10), (retryTimer) async {
      await prefs.reload();
      if (prefs.getString(_kSupabaseUrl) != null) {
        retryTimer.cancel();
        onStart(service); // re-enter with credentials now available
      }
    });
    return;
  }

  final supabaseUrl = prefs.getString(_kSupabaseUrl)!;
  AppLogger.d('[BgService] Connecting to Supabase: ${supabaseUrl.replaceAll('https://', '').split('.').first}');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: prefs.getString(_kSupabaseKey)!,
  );
  final client = Supabase.instance.client;

  // Verify session was auto-restored; if not, attempt manual recovery.
  if (client.auth.currentSession == null) {
    final stored = prefs.getString('supabase.auth.token');
    if (stored != null) {
      try {
        await client.auth.recoverSession(stored);
        AppLogger.d('[BgService] Session recovered: ${client.auth.currentUser?.email}');
      } catch (e) {
        AppLogger.w('[BgService] Session recovery failed: $e');
      }
    } else {
      AppLogger.w('[BgService] No stored session — inserts will be blocked by RLS');
    }
  } else {
    AppLogger.d('[BgService] Session auto-restored: ${client.auth.currentSession!.user.email}');
  }

  // Force token refresh — the stored access token may be expired.
  try {
    await client.auth.refreshSession();
    AppLogger.d('[BgService] Token refreshed ok');
  } catch (e) {
    AppLogger.w('[BgService] Token refresh failed: $e');
  }

  // Restore persisted stationaryStart across service restarts
  final savedStart = prefs.getString(_kStationaryStartKey);
  if (savedStart != null) {
    _stationaryStart = DateTime.tryParse(savedStart);
  }

  Future<void> tick() async {
    await prefs.reload(); // read latest userId / activity state from main isolate writes
    final userId = prefs.getString(_kUserIdKey);
    if (userId == null) {
      AppLogger.w('[BgService] Tick #$_tickCount — no userId, skipping');
      return;
    }
    AppLogger.d('[BgService] Tick #$_tickCount userId=${userId.substring(0, 8)}… auth=${Supabase.instance.client.auth.currentSession != null ? "ok" : "none"}');

    _tickCount++;

    // Every ~60 min: app usage + screen event flush.
    // Time-based so it survives service restarts (tick counter resets each restart).
    final lastAppUsageMs = prefs.getInt('last_app_usage_ts') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - lastAppUsageMs > 5 * 60 * 1000) {
      AppLogger.d('[BgService] Hourly flush triggered');
      await _flushAppUsage(userId, prefs, client);
      await _flushScreenEvents(userId, prefs, client);
      await prefs.setInt('last_app_usage_ts', nowMs);
    }

    await _collectGps(userId, prefs, client);
  }

  await tick(); // immediate first collection
  Timer.periodic(const Duration(minutes: 5), (_) => tick());
}

Future<void> _collectGps(
  String userId,
  SharedPreferences prefs,
  SupabaseClient client,
) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );

    final now = DateTime.now();
    final speedMps = position.speed < 0 ? 0.0 : position.speed;

    // Read activity recognition state written by ActivityRecognitionReceiver.kt
    // via the FlutterSharedPreferences bridge key
    final nativeActivity = prefs.getString('activity_recognition_state');
    final movementState = nativeActivity ?? _movementStateFromSpeed(speedMps);

    if (movementState == 'stationary') {
      if (_stationaryStart == null) {
        _stationaryStart = now;
        await prefs.setString(_kStationaryStartKey, now.toIso8601String());
      }
    } else {
      _stationaryStart = null;
      await prefs.remove(_kStationaryStartKey);
    }

    final dwellTimeS = _stationaryStart != null
        ? now.difference(_stationaryStart!).inSeconds.toDouble()
        : 0.0;

    final inserted = await client.from('gps_pings').insert({
      'user_id': userId,
      'timestamp': now.toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed_mps': speedMps,
      'movement_state': movementState,
      'dwell_time_s': dwellTimeS,
    }).select();

    AppLogger.d('[BgService] GPS insert → ${inserted.length} row(s), id=${inserted.isNotEmpty ? inserted.first['id'] : "none"}, ts=${inserted.isNotEmpty ? inserted.first['timestamp'] : "none"}');
    AppLogger.d(
      '[BgService] GPS ✓ $movementState | '
      '${speedMps.toStringAsFixed(1)} m/s | '
      'dwell ${dwellTimeS.toStringAsFixed(0)}s',
    );
  } catch (e, st) {
    AppLogger.w('[BgService] GPS collection failed: $e\n$st');
  }
}

Future<void> _flushAppUsage(
  String userId,
  SharedPreferences prefs,
  SupabaseClient client,
) async {
  try {
    // AppUsageCollector.kt writes to FlutterSharedPreferences key
    // "flutter.app_usage_buffer" — readable here as 'app_usage_buffer'
    final bufferJson = prefs.getString('app_usage_buffer') ?? '[]';
    final raw = jsonDecode(bufferJson) as List<dynamic>;
    if (raw.isEmpty) return;

    final sessions = raw
        .map((e) => {
              'user_id': userId,
              'app_name': (e as Map)['app_name'] as String,
              'category': e['category'] as String,
              'duration_min': (e['duration_min'] as num).toDouble(),
              'timestamp': e['timestamp'] as String,
              'state': e['state'] as String,
            })
        .toList();

    await client
        .from('app_sessions')
        .upsert(sessions, onConflict: 'user_id,app_name,timestamp');
    await prefs.remove('app_usage_buffer');
    AppLogger.i('[BgService] Flushed ${sessions.length} app usage sessions');
  } catch (e) {
    AppLogger.w('[BgService] App usage flush failed: $e');
  }
}

Future<void> _flushScreenEvents(
  String userId,
  SharedPreferences prefs,
  SupabaseClient client,
) async {
  try {
    // ScreenEventService.kt writes to FlutterSharedPreferences with key
    // "flutter.screen_events_buffer" — readable here as 'screen_events_buffer'
    final eventsJson = prefs.getString('screen_events_buffer') ?? '[]';
    final raw = jsonDecode(eventsJson) as List<dynamic>;
    if (raw.isEmpty) return;

    final events = raw
        .map((e) => {
              'user_id': userId,
              'timestamp': (e as Map)['timestamp'] as String,
              'event_type': e['event_type'] as String,
            })
        .toList();

    await client.from('screen_events').insert(events);
    await prefs.remove('screen_events_buffer');
    AppLogger.d('[BgService] Flushed ${events.length} screen events');
  } catch (e) {
    AppLogger.w('[BgService] Screen event flush failed', e);
  }
}

String _movementStateFromSpeed(double speedMps) {
  if (speedMps < 0.5) return 'stationary';
  if (speedMps < 2.0) return 'walking';
  if (speedMps < 5.0) return 'cycling';
  if (speedMps < 20.0) return 'transit';
  return 'vehicle';
}
