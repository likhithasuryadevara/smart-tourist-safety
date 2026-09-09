import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;

  Future<bool> checkPermission() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void startTracking({
    required Function(Position position) onLocationUpdate,
  }) async {
    final allowed = await checkPermission();

    if (!allowed) {
      print('Location permission not allowed.');
      return;
    }

    _positionStream =
        Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      // Send location back to the map/dashboard
      onLocationUpdate(position);

      // Save location to Firebase
      await _saveLocationToFirestore(position);
    });
  }

  Future<void> _saveLocationToFirestore(
    Position position,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt':
            FieldValue.serverTimestamp(),
      });

      print('Location saved to Firestore');
      print(
        'GPS: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('Firestore location error: $e');
    }
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}