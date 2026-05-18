import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/app_logger.dart';
import 'app_usage_service.dart';

const _kUserIdKey = 'current_user_id';
const _kSupabaseUrl = 'supabase_url';
const _kSupabaseKey = 'supabase_anon_key';

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
    AppLogger.w('[BgService] Supabase credentials not found — waiting for app launch');
    // Retry after 30s in case app hasn't stored creds yet (cold boot before first login)
    await Future.delayed(const Duration(seconds: 30));
    await prefs.reload();
    if (prefs.getString(_kSupabaseUrl) == null) return;
  }

  await Supabase.initialize(
    url: prefs.getString(_kSupabaseUrl)!,
    anonKey: prefs.getString(_kSupabaseKey)!,
  );
  final client = Supabase.instance.client;
  final appUsage = AppUsageService(client);

  Future<void> tick() async {
    await prefs.reload(); // read latest userId / activity state from main isolate writes
    final userId = prefs.getString(_kUserIdKey);
    if (userId == null) return; // not logged in

    _tickCount++;

    // Every 12 ticks ≈ 60 min: app usage + screen event flush
    if (_tickCount % 12 == 0) {
      await appUsage.collectAndUpload(userId);
      await _flushScreenEvents(userId, prefs, client);
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
      _stationaryStart ??= now;
    } else {
      _stationaryStart = null;
    }

    final dwellTimeS = _stationaryStart != null
        ? now.difference(_stationaryStart!).inSeconds.toDouble()
        : 0.0;

    await client.from('gps_pings').insert({
      'user_id': userId,
      'timestamp': now.toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed_mps': speedMps,
      'movement_state': movementState,
      'dwell_time_s': dwellTimeS,
    });

    AppLogger.d(
      '[BgService] GPS ✓ $movementState | '
      '${speedMps.toStringAsFixed(1)} m/s | '
      'dwell ${dwellTimeS.toStringAsFixed(0)}s',
    );
  } catch (e) {
    AppLogger.w('[BgService] GPS collection failed', e);
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
