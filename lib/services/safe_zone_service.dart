import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafeZone {
  final double latitude;
  final double longitude;
  final double radius;

  SafeZone({
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

class SafeZoneService {
  Future<SafeZone?> getActiveSafeZone() async {
    try {
      debugPrint('🔄 Loading active safe zone...');

      final snapshot = await FirebaseFirestore.instance
          .collection('safe_zones')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      debugPrint('📄 Documents found: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        debugPrint('❌ No active safe zone found.');
        return null;
      }

      final data = snapshot.docs.first.data();

      debugPrint('✅ Safe zone data: $data');

      final safeZone = SafeZone(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        radius: (data['radius'] as num).toDouble(),
      );

      debugPrint(
        '✅ Active Safe Zone loaded: '
        'latitude=${safeZone.latitude}, '
        'longitude=${safeZone.longitude}, '
        'radius=${safeZone.radius}m',
      );

      return safeZone;
    } catch (e) {
      debugPrint('❌ SAFE ZONE FIRESTORE ERROR: $e');
      return null;
    }
  }
  double calculateDistance({
    required double touristLatitude,
    required double touristLongitude,
    required SafeZone safeZone,
  }) {
    return Geolocator.distanceBetween(
      touristLatitude,
      touristLongitude,
      safeZone.latitude,
      safeZone.longitude,
    );
  }

  bool isInsideSafeZone({
    required double touristLatitude,
    required double touristLongitude,
    required SafeZone safeZone,
  }) {
    final distance = calculateDistance(
      touristLatitude: touristLatitude,
      touristLongitude: touristLongitude,
      safeZone: safeZone,
    );

    return distance <= safeZone.radius;
  }
  Future<void> createSafeZoneNotification() async {
    debugPrint('🔄 Safe Zone notification creation started.');

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          '⚠️ Safe Zone notification creation skipped: '
          'no authenticated user.',
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'touristId': user.uid,
        'type': 'safe_zone',
        'title': 'Safe Zone',
        'message': 'You have entered a safe zone.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Safe zone notification created.');
    } catch (e) {
      debugPrint('❌ Safe Zone notification creation failed: $e');
    }
  }

  Future<void> createZoneExitNotification() async {
    debugPrint('🔄 Zone Exit notification creation started.');

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          '⚠️ Zone Exit notification creation skipped: '
          'no authenticated user.',
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'touristId': user.uid,
        'type': 'zone_exit',
        'title': 'Zone Exit',
        'message': 'You have left the safe zone.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Zone Exit notification created.');
    } catch (e) {
      debugPrint('❌ Zone Exit notification creation failed: $e');
    }
  }
}