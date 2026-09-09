import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

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
      print('🔄 Loading active safe zone...');

      final snapshot = await FirebaseFirestore.instance
          .collection('safe_zones')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      print('📄 Documents found: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('❌ No active safe zone found.');
        return null;
      }

      final data = snapshot.docs.first.data();

      print('✅ Safe zone data: $data');

      return SafeZone(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        radius: (data['radius'] as num).toDouble(),
      );
    } catch (e) {
      print('❌ SAFE ZONE FIRESTORE ERROR: $e');
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
}