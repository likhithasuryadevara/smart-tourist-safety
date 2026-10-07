import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/tourist_settings_model.dart';
import '../utils/app_error_message.dart';
import 'tourist_settings_service.dart';

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

class DangerZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;

  DangerZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

class SafeZoneService {
  Future<SafeZone?> getActiveSafeZone() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('safe_zones')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data = snapshot.docs.first.data();

      final safeZone = SafeZone(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        radius: (data['radius'] as num).toDouble(),
      );

      return safeZone;
    } catch (e, stackTrace) {
      AppErrorMessage.log(
        e,
        stackTrace,
        context: 'Loading active safe zone',
      );
      rethrow;
    }
  }

  Future<List<DangerZone>> getActiveDangerZones() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('danger_zones')
          .where('isActive', isEqualTo: true)
          .get();

      final dangerZones = snapshot.docs.map((doc) {
        final data = doc.data();
        return DangerZone(
          id: doc.id,
          name: data['name'] as String,
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          radius: (data['radius'] as num).toDouble(),
        );
      }).toList();

      return dangerZones;
    } catch (e, stackTrace) {
      AppErrorMessage.log(
        e,
        stackTrace,
        context: 'Loading active danger zones',
      );
      rethrow;
    }
  }

  bool isInsideDangerZone({
    required double touristLatitude,
    required double touristLongitude,
    required DangerZone dangerZone,
  }) {
    final distance = Geolocator.distanceBetween(
      touristLatitude,
      touristLongitude,
      dangerZone.latitude,
      dangerZone.longitude,
    );

    return distance <= dangerZone.radius;
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
      if (!await TouristSettingsService.shared.isNotificationEnabled(
        TouristNotificationCategory.safety,
      )) {
        return;
      }
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          '⚠️ Safe Zone notification creation skipped: '
          'no authenticated user.',
        );
        return;
      }

      await FirebaseFirestore.instance.collection('notifications').add({
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
      if (!await TouristSettingsService.shared.isNotificationEnabled(
        TouristNotificationCategory.safety,
      )) {
        return;
      }
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          '⚠️ Zone Exit notification creation skipped: '
          'no authenticated user.',
        );
        return;
      }

      await FirebaseFirestore.instance.collection('notifications').add({
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

  Future<void> createDangerZoneNotification() async {
    debugPrint('🔄 Danger Zone notification creation started.');

    try {
      if (!await TouristSettingsService.shared.isNotificationEnabled(
        TouristNotificationCategory.safety,
      )) {
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('Danger Zone notification Auth UID: ${user?.uid}.');

      if (user == null) {
        debugPrint(
          '⚠️ Danger Zone notification creation skipped: '
          'no authenticated user.',
        );
        return;
      }

      debugPrint('Writing Danger Zone notification to Firestore.');
      final notification = await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'touristId': user.uid,
            'type': 'danger_zone',
            'title': 'Danger Zone',
            'message': 'You have entered a danger zone.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      debugPrint(
        '✅ Danger Zone notification created successfully: '
        'documentId=${notification.id}.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Danger Zone notification creation failed: $e');
      debugPrint('Danger Zone notification failure stack trace: $stackTrace');
    }
  }
}
