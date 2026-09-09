import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/safe_zone_status_service.dart';

import '../services/location_service.dart';
import '../services/safe_zone_service.dart';

class LiveSafetyMap extends StatefulWidget {
  final VoidCallback onFullscreen;

  const LiveSafetyMap({
    super.key,
    required this.onFullscreen,
  });

  @override
  State<LiveSafetyMap> createState() => _LiveSafetyMapState();
}

class _LiveSafetyMapState extends State<LiveSafetyMap> {
  final MapController _mapController = MapController();

  final LocationService _locationService = LocationService();
  final SafeZoneService _safeZoneService = SafeZoneService();
  final SafeZoneStatusService _statusService =
    SafeZoneStatusService();

  LatLng? _currentLocation;
  SafeZone? _safeZone;

  bool _isInsideSafeZone = true;
  double _distanceFromSafeZone = 0;

  final LatLng _fallbackLocation =
      const LatLng(16.4854, 80.6916);

  @override
  void initState() {
    super.initState();
    _loadSafeZone();
    _startLocationTracking();
  }

  Future<void> _loadSafeZone() async {
    final safeZone =
        await _safeZoneService.getActiveSafeZone();

    if (!mounted) return;

    setState(() {
      _safeZone = safeZone;
    });

    _checkSafeZone();
  }

  void _startLocationTracking() {
    _locationService.startTracking(
      onLocationUpdate: (Position position) {
        if (!mounted) return;

        final location = LatLng(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _currentLocation = location;
        });

        _checkSafeZone();

        _mapController.move(location, 15);
      },
    );
  }

  void _checkSafeZone() {
    if (_currentLocation == null || _safeZone == null) {
      return;
    }

    final distance = _safeZoneService.calculateDistance(
      touristLatitude: _currentLocation!.latitude,
      touristLongitude: _currentLocation!.longitude,
      safeZone: _safeZone!,
    );

    final inside = _safeZoneService.isInsideSafeZone(
      touristLatitude: _currentLocation!.latitude,
      touristLongitude: _currentLocation!.longitude,
      safeZone: _safeZone!,
    );

    if (!mounted) return;

    setState(() {
      _distanceFromSafeZone = distance;
      _isInsideSafeZone = inside;
    });
    _statusService.updateStatus(inside);
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentLocation ?? _fallbackLocation;

    return Container(
      height: 390,
      decoration: BoxDecoration(
        color: const Color(0xFF111C31),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Tourist Safety Map',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Real-world map • Safe zones',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onFullscreen,
                  child: const Text(
                    'Full Screen Map →',
                    style: TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.smart_tourist_safety',
                  ),

                  if (_safeZone != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(
                            _safeZone!.latitude,
                            _safeZone!.longitude,
                          ),
                          radius: _safeZone!.radius,
                          useRadiusInMeter: true,
                          color: _isInsideSafeZone
                              ? const Color(0x3322C55E)
                              : const Color(0x33EF4444),
                          borderColor: _isInsideSafeZone
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),

                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x332563EB),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2563EB),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _safeZone == null
                  ? 'Loading Safe Zone...'
                  : _isInsideSafeZone
                      ? '🟢 Inside Safe Zone'
                      : '🔴 Outside Safe Zone • ${_distanceFromSafeZone.toStringAsFixed(0)}m from center',
              style: TextStyle(
                color: _isInsideSafeZone
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}