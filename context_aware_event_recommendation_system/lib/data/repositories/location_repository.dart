import 'package:geolocator/geolocator.dart';

import '../../utils/app_logger.dart';
import '../services/location_service.dart';

class LocationRepository {
  LocationRepository(this._service);

  final LocationService _service;

  Position? _cachedPosition;
  DateTime? _positionExpiresAt;
  static const _ttl = Duration(minutes: 5);

  Future<bool> requestPermission() async {
    final permission = await _service.requestPermission();
    final granted = _service.isGranted(permission);
    AppLogger.i('[Location] Permission request → ${granted ? 'granted' : 'denied'} ($permission)');
    return granted;
  }

  Future<bool> hasPermission() async {
    final permission = await _service.checkPermission();
    return _service.isGranted(permission);
  }

  Future<Position?> getCurrentPosition() async {
    final now = DateTime.now();
    if (_cachedPosition != null &&
        _positionExpiresAt != null &&
        now.isBefore(_positionExpiresAt!)) {
      AppLogger.d('[Location] Returning cached position');
      return _cachedPosition;
    }
    final position = await _service.getCurrentPosition();
    if (position != null) {
      _cachedPosition = position;
      _positionExpiresAt = now.add(_ttl);
      AppLogger.i('[Location] Fresh position acquired');
    } else {
      AppLogger.w('[Location] Could not acquire position (permission denied or service off)');
    }
    return position;
  }

  Future<String?> getAddressLabel(double lat, double lon) =>
      _service.getAddressLabel(lat, lon);

  void invalidate() {
    _cachedPosition = null;
    _positionExpiresAt = null;
  }
}
