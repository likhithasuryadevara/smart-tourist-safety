import 'dart:async';

import 'package:flutter/foundation.dart';

import 'safe_zone_service.dart';

enum TouristGpsStatus {
  active,
  disabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
  retrying,
}

enum TouristZoneStatus { safe, danger, outsideSafeZone, unknown }

@immutable
class TouristSafetySnapshot {
  final TouristGpsStatus gpsStatus;
  final TouristZoneStatus zoneStatus;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  final double? distanceToSafeZone;
  final bool isInsideSafeZone;

  const TouristSafetySnapshot({
    this.gpsStatus = TouristGpsStatus.unavailable,
    this.zoneStatus = TouristZoneStatus.unknown,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.distanceToSafeZone,
    this.isInsideSafeZone = false,
  });

  bool get hasLocation => latitude != null && longitude != null;

  String get safetyIndicator => switch (zoneStatus) {
    TouristZoneStatus.safe => 'SAFE',
    TouristZoneStatus.danger || TouristZoneStatus.outsideSafeZone => 'DANGER',
    TouristZoneStatus.unknown => 'UNKNOWN',
  };
}

class SafeZoneStatusService {
  static final SafeZoneStatusService _instance =
      SafeZoneStatusService._internal();

  factory SafeZoneStatusService() {
    return _instance;
  }

  StreamController<bool>? _safeZoneController;

  SafeZoneStatusService._internal() {
    _safeZoneController = StreamController<bool>.broadcast();
  }

  StreamController<TouristSafetySnapshot>? _statusController;
  TouristSafetySnapshot _snapshot = const TouristSafetySnapshot();
  Future<void> Function()? _retryHandler;
  Future<void> Function(bool enabled)? _trackingHandler;
  bool _locationTrackingEnabled = true;

  Stream<TouristSafetySnapshot> get statusStream {
    _statusController ??= StreamController<TouristSafetySnapshot>.broadcast();
    return _statusController!.stream;
  }

  TouristSafetySnapshot get snapshot => _snapshot;
  bool get locationTrackingEnabled => _locationTrackingEnabled;
  set locationTrackingEnabled(bool enabled) {
    _locationTrackingEnabled = enabled;
    _publish(_snapshot);
  }

  void updateGpsStatus(TouristGpsStatus status) {
    _publish(
      _snapshot.copyWith(
        gpsStatus: status,
        zoneStatus: status == TouristGpsStatus.active
            ? _snapshot.zoneStatus
            : TouristZoneStatus.unknown,
        isInsideSafeZone: status == TouristGpsStatus.active
            ? _snapshot.isInsideSafeZone
            : false,
        clearDistance: status != TouristGpsStatus.active,
      ),
    );
  }

  void updateLocation({
    required double latitude,
    required double longitude,
    required DateTime updatedAt,
    required SafeZone? safeZone,
    required List<DangerZone> dangerZones,
    required SafeZoneService safeZoneService,
    double? precomputedDistanceToSafeZone,
    bool? precomputedInsideSafeZone,
    bool? precomputedInsideDangerZone,
  }) {
    final gpsIsActive = _snapshot.gpsStatus == TouristGpsStatus.active;
    final insideDangerZone =
        precomputedInsideDangerZone ??
        dangerZones.any(
          (zone) => safeZoneService.isInsideDangerZone(
            touristLatitude: latitude,
            touristLongitude: longitude,
            dangerZone: zone,
          ),
        );
    final distance = !gpsIsActive || safeZone == null
        ? null
        : precomputedDistanceToSafeZone ??
              safeZoneService.calculateDistance(
                touristLatitude: latitude,
                touristLongitude: longitude,
                safeZone: safeZone,
              );
    final insideSafeZone =
        precomputedInsideSafeZone ??
        (gpsIsActive &&
            safeZone != null &&
            safeZoneService.isInsideSafeZone(
              touristLatitude: latitude,
              touristLongitude: longitude,
              safeZone: safeZone,
            ));

    final zoneStatus = !gpsIsActive
        ? TouristZoneStatus.unknown
        : insideDangerZone
        ? TouristZoneStatus.danger
        : safeZone == null
        ? TouristZoneStatus.unknown
        : insideSafeZone
        ? TouristZoneStatus.safe
        : TouristZoneStatus.outsideSafeZone;
    _publish(
      _snapshot.copyWith(
        latitude: latitude,
        longitude: longitude,
        locationUpdatedAt: updatedAt,
        distanceToSafeZone: distance,
        zoneStatus: zoneStatus,
        isInsideSafeZone: insideSafeZone,
        clearDistance: distance == null,
      ),
    );
    updateStatus(zoneStatus == TouristZoneStatus.safe);
  }

  void registerRetryHandler(Future<void> Function()? handler) {
    _retryHandler = handler;
  }

  void registerTrackingHandler(Future<void> Function(bool enabled)? handler) {
    _trackingHandler = handler;
  }

  Future<void> setLocationTrackingEnabled(bool enabled) async {
    locationTrackingEnabled = enabled;
    final handler = _trackingHandler;
    if (handler == null) {
      if (!enabled) updateGpsStatus(TouristGpsStatus.unavailable);
      return;
    }
    await handler(enabled);
  }

  Future<void> retryGps() async {
    final handler = _retryHandler;
    if (handler == null) {
      throw StateError(
        'GPS retry is not available while monitoring is stopped.',
      );
    }
    await handler();
  }

  void _publish(TouristSafetySnapshot snapshot) {
    _snapshot = snapshot;
    if (_statusController == null || _statusController!.isClosed) {
      _statusController = StreamController<TouristSafetySnapshot>.broadcast();
    }
    _statusController!.add(snapshot);
  }

  Stream<bool> get safeZoneStream {
    _safeZoneController ??= StreamController<bool>.broadcast();
    return _safeZoneController!.stream;
  }

  bool _isInsideSafeZone = true;

  bool get isInsideSafeZone => _isInsideSafeZone;

  void updateStatus(bool isInside) {
    _isInsideSafeZone = isInside;
    if (_safeZoneController == null || _safeZoneController!.isClosed) {
      _safeZoneController = StreamController<bool>.broadcast();
    }
    _safeZoneController!.add(isInside);
  }

  void dispose() {
    if (_safeZoneController != null && !_safeZoneController!.isClosed) {
      _safeZoneController!.close();
    }
    _safeZoneController = null;
    _retryHandler = null;
    _trackingHandler = null;
    if (_statusController != null && !_statusController!.isClosed) {
      _statusController!.close();
    }
    _statusController = null;
  }
}

extension on TouristSafetySnapshot {
  TouristSafetySnapshot copyWith({
    TouristGpsStatus? gpsStatus,
    TouristZoneStatus? zoneStatus,
    double? latitude,
    double? longitude,
    DateTime? locationUpdatedAt,
    double? distanceToSafeZone,
    bool? isInsideSafeZone,
    bool clearDistance = false,
  }) {
    return TouristSafetySnapshot(
      gpsStatus: gpsStatus ?? this.gpsStatus,
      zoneStatus: zoneStatus ?? this.zoneStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      distanceToSafeZone: clearDistance
          ? null
          : distanceToSafeZone ?? this.distanceToSafeZone,
      isInsideSafeZone: isInsideSafeZone ?? this.isInsideSafeZone,
    );
  }
}

class GpsRetryPolicy {
  GpsRetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 2),
    this.maximumDelay = const Duration(seconds: 12),
  }) : assert(maxRetries >= 0),
       assert(initialDelay > Duration.zero),
       assert(maximumDelay >= initialDelay);

  final int maxRetries;
  final Duration initialDelay;
  final Duration maximumDelay;
  int _retriesScheduled = 0;

  int get retriesScheduled => _retriesScheduled;
  bool get exhausted => _retriesScheduled >= maxRetries;

  Duration? nextDelay() {
    if (exhausted) return null;
    final multiplier = 1 << _retriesScheduled;
    final candidate = initialDelay * multiplier;
    _retriesScheduled++;
    return candidate > maximumDelay ? maximumDelay : candidate;
  }

  void reset() {
    _retriesScheduled = 0;
  }
}
