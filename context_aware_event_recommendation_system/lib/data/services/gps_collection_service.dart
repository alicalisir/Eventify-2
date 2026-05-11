import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/app_logger.dart';
import 'app_usage_service.dart';

/// Periodically collects GPS pings and uploads them to Supabase.
/// Every 12th tick (≈ once per hour) also triggers app usage collection.
///
/// Speed → movement_state thresholds match the synthetic training data:
///   < 0.5 m/s  → stationary
///   < 2.0 m/s  → walking
///   < 5.0 m/s  → cycling
///   < 20.0 m/s → transit
///   ≥ 20.0 m/s → vehicle
class GpsCollectionService {
  GpsCollectionService(this._client, this._appUsage);

  final SupabaseClient _client;
  final AppUsageService _appUsage;

  static const _interval = Duration(minutes: 5);
  static const _appUsageEveryNTicks = 12; // every 60 minutes

  int _tickCount = 0;

  Timer? _timer;
  String? _currentUserId;

  // Stationary tracking for dwell_time_s calculation
  DateTime? _stationaryStartTime;

  bool get isRunning => _timer != null;

  void start(String userId) {
    if (_timer != null && _currentUserId == userId) return;
    stop();
    _currentUserId = userId;
    AppLogger.i('[GpsCollection] Starting for user $userId');
    _collectAndUpload();
    _timer = Timer.periodic(_interval, (_) => _collectAndUpload());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _currentUserId = null;
    _stationaryStartTime = null;
    _tickCount = 0;
    AppLogger.i('[GpsCollection] Stopped');
  }

  Future<void> _collectAndUpload() async {
    final userId = _currentUserId;
    _tickCount++;

    // Collect app usage once per hour (every _appUsageEveryNTicks GPS ticks)
    if (userId != null && _tickCount % _appUsageEveryNTicks == 0) {
      await _appUsage.collectAndUpload(userId);
    }
    if (userId == null) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.d('[GpsCollection] Location service disabled — skipping');
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        AppLogger.d('[GpsCollection] No location permission — skipping');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      final now = DateTime.now();
      final speedMps = position.speed < 0 ? 0.0 : position.speed;
      final movementState = _movementStateFromSpeed(speedMps);

      if (movementState == 'stationary') {
        _stationaryStartTime ??= now;
      } else {
        _stationaryStartTime = null;
      }

      final dwellTimeS = _stationaryStartTime != null
          ? now.difference(_stationaryStartTime!).inSeconds.toDouble()
          : 0.0;

      await _client.from('gps_pings').insert({
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
        '[GpsCollection] ✓ $movementState | '
        '${speedMps.toStringAsFixed(1)} m/s | '
        'dwell ${dwellTimeS.toStringAsFixed(0)}s | '
        '(${position.latitude.toStringAsFixed(4)}, '
        '${position.longitude.toStringAsFixed(4)})',
      );
    } catch (e, s) {
      AppLogger.w('[GpsCollection] Failed to collect/upload', e);
      AppLogger.d('[GpsCollection] Stack', s);
    }
  }

  static String _movementStateFromSpeed(double speedMps) {
    if (speedMps < 0.5) return 'stationary';
    if (speedMps < 2.0) return 'walking';
    if (speedMps < 5.0) return 'cycling';
    if (speedMps < 20.0) return 'transit';
    return 'vehicle';
  }
}
