import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

/// Shared configuration for the Tourist-side OpenStreetMap implementation.
///
/// The embedded `LiveSafetyMap` widget and the full-screen map screen both use
/// these values so the Tourist app renders one consistent map. OpenStreetMap
/// raster tiles do not require an API key: they only require an internet
/// connection and a valid `userAgentPackageName`, as mandated by the
/// OpenStreetMap Tile Usage Policy.
class TouristMapConfig {
  const TouristMapConfig._();

  /// OpenStreetMap raster tile template used by both Tourist map surfaces.
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Package name reported to the OpenStreetMap tile servers. Keep it in sync
  /// with the Android `applicationId`.
  static const String userAgentPackageName = 'com.example.smart_tourist_safety';

  /// Camera center used until the tourist's live location is available.
  static const LatLng fallbackCenter = LatLng(16.4854, 80.6916);

  /// Camera zoom used when the map first opens and when recentering.
  static const double initialZoom = 15;

  /// Camera zoom limits shared by both Tourist map surfaces.
  static const double minZoom = 3;
  static const double maxZoom = 19;

  /// Neutral background shown behind map tiles while they load.
  static const Color mapBackgroundColor = Color(0xFFE8EEF2);
}
