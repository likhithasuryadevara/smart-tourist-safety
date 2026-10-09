import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationAvailability {
  active,
  disabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

abstract interface class LocationPermissionGateway {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();
}

class _GeolocatorPermissionGateway implements LocationPermissionGateway {
  const _GeolocatorPermissionGateway();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
}

class LocationService {
  LocationService({LocationPermissionGateway? permissionGateway})
    : _permissionGateway =
          permissionGateway ?? const _GeolocatorPermissionGateway();

  final LocationPermissionGateway _permissionGateway;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  bool _isStarting = false;
  bool _disposed = false;
  Future<void> _pendingStop = Future<void>.value();

  bool get isTracking => _isTracking;

  Future<bool> checkPermission() async {
    final availability = await getAvailability(requestPermission: true);
    return availability == LocationAvailability.active;
  }

  Future<LocationAvailability> getAvailability({
    bool requestPermission = false,
  }) async {
    if (_disposed) return LocationAvailability.unavailable;
    try {
      final serviceEnabled = await _permissionGateway
          .isLocationServiceEnabled();
      debugPrint('LocationService: location services enabled: $serviceEnabled');
      if (!serviceEnabled) {
        return LocationAvailability.disabled;
      }
      var permission = await _permissionGateway.checkPermission();
      debugPrint('LocationService: permission before request: $permission');
      if (requestPermission && permission == LocationPermission.denied) {
        permission = await _permissionGateway.requestPermission();
        debugPrint('LocationService: permission after request: $permission');
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: location permission denied forever');
        return LocationAvailability.permissionDeniedForever;
      }
      if (permission == LocationPermission.denied) {
        debugPrint('LocationService: location permission denied');
        return LocationAvailability.permissionDenied;
      }
      debugPrint('LocationService: location permission granted');
      return LocationAvailability.active;
    } catch (error, stackTrace) {
      debugPrint('LocationService: availability check failed: $error');
      debugPrint('LocationService: availability check stack trace: $stackTrace');
      return LocationAvailability.unavailable;
    }
  }

  Future<LocationAvailability> startTracking({
    required Function(Position position) onLocationUpdate,
    required ValueChanged<LocationAvailability> onStatusChanged,
  }) async {
    await _pendingStop;
    if (_disposed) return LocationAvailability.unavailable;
    if (_isTracking || _isStarting) return LocationAvailability.active;

    _isStarting = true;
    try {
      final availability = await getAvailability(requestPermission: true);
      if (availability != LocationAvailability.active) {
        onStatusChanged(availability);
        return availability;
      }
      if (_disposed) return LocationAvailability.unavailable;

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (Position position) async {
          if (_disposed) return;

          try {
            onLocationUpdate(position);
            await _saveLocationToFirestore(position);
          } catch (error, stackTrace) {
            debugPrint('LocationService: location update failed: $error');
            debugPrint('LocationService: stack trace: $stackTrace');
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('LocationService: stream error: $error');
          debugPrint('LocationService: stream stack trace: $stackTrace');
          _isTracking = false;
          onStatusChanged(LocationAvailability.unavailable);
          unawaited(stopTracking());
        },
      );
      _isTracking = true;
      onStatusChanged(LocationAvailability.active);
      return LocationAvailability.active;
    } catch (error, stackTrace) {
      debugPrint('LocationService: start tracking failed: $error');
      debugPrint('LocationService: start tracking stack trace: $stackTrace');
      onStatusChanged(LocationAvailability.unavailable);
      return LocationAvailability.unavailable;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _saveLocationToFirestore(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _disposed) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (error, stackTrace) {
      debugPrint('LocationService: Firestore save failed: $error');
      debugPrint('LocationService: Firestore save stack trace: $stackTrace');
    }
  }

  Future<Position?> getCurrentLocation() async {
    if (_disposed) return null;

    final allowed = await checkPermission();
    if (!allowed) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('LocationService: unable to get current location: $error');
      debugPrint(
        'LocationService: get current location stack trace: $stackTrace',
      );
      return null;
    }
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<void> stopTracking() async {
    _isTracking = false;
    final subscription = _positionStream;
    _positionStream = null;
    final stop = subscription?.cancel() ?? Future<void>.value();
    _pendingStop = stop;
    await stop;
  }

  void dispose() {
    _disposed = true;
    unawaited(stopTracking());
  }
}
