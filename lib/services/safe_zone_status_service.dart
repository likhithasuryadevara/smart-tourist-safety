import 'dart:async';

class SafeZoneStatusService {
  static final SafeZoneStatusService _instance =
      SafeZoneStatusService._internal();

  factory SafeZoneStatusService() {
    return _instance;
  }

  SafeZoneStatusService._internal();

  final StreamController<bool> _safeZoneController =
      StreamController<bool>.broadcast();

  Stream<bool> get safeZoneStream =>
      _safeZoneController.stream;

  bool _isInsideSafeZone = true;

  bool get isInsideSafeZone =>
      _isInsideSafeZone;

  void updateStatus(bool isInside) {
    _isInsideSafeZone = isInside;

    _safeZoneController.add(isInside);
  }

  void dispose() {
    _safeZoneController.close();
  }
}