import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/models/context_state.dart';
import '../../domain/models/persona_model.dart';
import '../services/context_service.dart';
import 'location_repository.dart';

class ContextRepository {
  ContextRepository(this._service, this._location);

  final ContextService _service;
  final LocationRepository _location;

  static const _contextTtl = Duration(minutes: 2);
  static const _personaTtl = Duration(minutes: 15);

  ContextState? _cachedContext;
  DateTime? _contextExpiresAt;

  PersonaModel? _cachedPersona;
  DateTime? _personaExpiresAt;

  Future<ContextState> getCurrentContext() async {
    final now = DateTime.now();
    if (_cachedContext != null &&
        _contextExpiresAt != null &&
        now.isBefore(_contextExpiresAt!)) {
      return _cachedContext!;
    }

    final position = await _location.getCurrentPosition();
    final locationLabel = position != null
        ? await _location.getAddressLabel(
            position.latitude,
            position.longitude,
          )
        : null;

    assert(() {
      if (position != null) {
        debugPrint(
          '[ContextRepository] GPS: ${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)} | '
          'speed: ${position.speed.toStringAsFixed(1)} m/s | '
          'accuracy: ${position.accuracy.toStringAsFixed(0)} m | '
          'address: $locationLabel',
        );
      } else {
        debugPrint(
          '[ContextRepository] GPS: no position '
          '(permission denied or service off)',
        );
      }
      return true;
    }());

    final notificationsGranted = await Permission.notification.isGranted;
    final speed = position?.speed ?? 0;
    final fresh = ContextState(
      greeting: _greeting(now.hour),
      contextDescription: _buildDescription(speed, now),
      isLocationEnabled: position != null,
      isNotificationsEnabled: notificationsGranted,
      lastUpdated: now,
      locationLabel: locationLabel,
      activityLabel: _activityLabel(speed),
    );
    _cachedContext = fresh;
    _contextExpiresAt = now.add(_contextTtl);
    return fresh;
  }

  Future<PersonaModel> getUserPersona() async {
    final now = DateTime.now();
    if (_cachedPersona != null &&
        _personaExpiresAt != null &&
        now.isBefore(_personaExpiresAt!)) {
      return _cachedPersona!;
    }
    final fresh = await _service.getUserPersona();
    _cachedPersona = fresh;
    _personaExpiresAt = now.add(_personaTtl);
    return fresh;
  }

  void invalidateContext() {
    _cachedContext = null;
    _contextExpiresAt = null;
  }

  void invalidatePersona() {
    _cachedPersona = null;
    _personaExpiresAt = null;
  }

  static String _greeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _activityLabel(double speed) {
    if (speed > 8) return 'In transit';
    if (speed > 1.5) return 'Walking';
    return 'Stationary';
  }

  static String _buildDescription(double speed, DateTime now) =>
      '${_activityLabel(speed)} · ${_timeLabel(now.hour)}';

  static String _timeLabel(int hour) {
    if (hour < 9) return 'Early start';
    if (hour < 12) return 'Morning';
    if (hour < 14) return 'Lunchtime';
    if (hour < 17) return 'Afternoon';
    if (hour < 20) return 'Evening';
    return 'Night';
  }
}
