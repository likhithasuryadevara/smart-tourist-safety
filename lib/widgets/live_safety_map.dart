import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/safe_zone_status_service.dart';

import '../services/location_service.dart';
import '../services/safe_zone_service.dart';
import '../services/tourist_settings_service.dart';

class LiveSafetyMap extends StatefulWidget {
  final VoidCallback onFullscreen;

  const LiveSafetyMap({super.key, required this.onFullscreen});

  @override
  State<LiveSafetyMap> createState() => _LiveSafetyMapState();
}

class _LiveSafetyMapState extends State<LiveSafetyMap>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();

  final LocationService _locationService = LocationService();
  final SafeZoneService _safeZoneService = SafeZoneService();
  final SafeZoneStatusService _statusService = SafeZoneStatusService();

  Timer? _safeZoneRefreshTimer;
  Timer? _dangerZoneRefreshTimer;
  Timer? _gpsRetryTimer;
  Timer? _locationFixTimer;
  Timer? _gpsStatusPollTimer;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  LatLng? _currentLocation;
  Position? _currentPosition;
  SafeZone? _safeZone;
  List<DangerZone> _dangerZones = [];
  final Map<String, bool> _dangerZoneInsideStates = {};
  final GpsRetryPolicy _gpsRetryPolicy = GpsRetryPolicy();

  bool _isInsideSafeZone = true;
  bool _isStartingLocationTracking = false;
  bool _isAppResumed = true;
  bool _hasReceivedLocation = false;
  bool _trackingEnabled = true;
  double _distanceFromSafeZone = 0;
  bool _hasCheckedSafeZone = false;
  bool _wasInsideSafeZone = false;

  final LatLng _fallbackLocation = const LatLng(16.4854, 80.6916);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusService.registerRetryHandler(_retryLocationTracking);
    _statusService.registerTrackingHandler(_setTrackingEnabled);
    _listenForLocationServiceChanges();
    _loadSafeZone();
    _loadDangerZones();
    _startZoneRefreshTimers();
    _initializeLocationTracking();
  }

  Future<void> _initializeLocationTracking() async {
    try {
      final settings = await TouristSettingsService.shared.load();
      if (!mounted) return;
      _trackingEnabled = settings.effectiveLocationTracking;
      _statusService.locationTrackingEnabled = _trackingEnabled;
      if (!_trackingEnabled) {
        _statusService.updateGpsStatus(TouristGpsStatus.unavailable);
        _statusService.updateStatus(false);
        return;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'LiveSafetyMap: settings unavailable, using safe defaults: $error',
      );
      debugPrint('LiveSafetyMap: settings load stack trace: $stackTrace');
    }
    await _startLocationTracking();
  }

  Future<void> _setTrackingEnabled(bool enabled) async {
    _trackingEnabled = enabled;
    _statusService.locationTrackingEnabled = enabled;
    if (!enabled) {
      _gpsRetryTimer?.cancel();
      _locationFixTimer?.cancel();
      await _locationService.stopTracking();
      if (!mounted) return;
      _statusService.updateGpsStatus(TouristGpsStatus.unavailable);
      _statusService.updateStatus(false);
      return;
    }

    _gpsRetryPolicy.reset();
    if (_isAppResumed) await _startLocationTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    if (_isAppResumed) {
      _startZoneRefreshTimers();
      _listenForLocationServiceChanges();
      if (_trackingEnabled) unawaited(_startLocationTracking());
      return;
    }

    _stopZoneRefreshTimers();
    _gpsRetryTimer?.cancel();
    _locationFixTimer?.cancel();
    _gpsStatusPollTimer?.cancel();
    _gpsStatusPollTimer = null;
    unawaited(_serviceStatusSubscription?.cancel());
    _serviceStatusSubscription = null;
    _statusService.updateGpsStatus(TouristGpsStatus.unavailable);
    _statusService.updateStatus(false);
    unawaited(_locationService.stopTracking());
  }

  void _startZoneRefreshTimers() {
    _safeZoneRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadSafeZone(),
    );
    _dangerZoneRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadDangerZones(),
    );
  }

  void _stopZoneRefreshTimers() {
    _safeZoneRefreshTimer?.cancel();
    _safeZoneRefreshTimer = null;
    _dangerZoneRefreshTimer?.cancel();
    _dangerZoneRefreshTimer = null;
  }

  void _listenForLocationServiceChanges() {
    if (_serviceStatusSubscription != null || _gpsStatusPollTimer != null) {
      return;
    }
    try {
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
        (status) {
          if (!mounted) return;
          if (status == ServiceStatus.disabled) {
            _gpsRetryTimer?.cancel();
            _locationFixTimer?.cancel();
            _statusService.updateGpsStatus(TouristGpsStatus.disabled);
            _statusService.updateStatus(false);
            unawaited(_locationService.stopTracking());
          } else if (_isAppResumed && _trackingEnabled) {
            _gpsRetryPolicy.reset();
            unawaited(_startLocationTracking());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('LiveSafetyMap: GPS service status stream failed: $error');
          debugPrint('LiveSafetyMap: status stream stack trace: $stackTrace');
        },
      );
    } catch (error, stackTrace) {
      debugPrint('LiveSafetyMap: GPS status monitoring unavailable: $error');
      debugPrint('LiveSafetyMap: GPS status stack trace: $stackTrace');
    }

    _gpsStatusPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_pollGpsAvailability()),
    );
  }

  Future<void> _pollGpsAvailability() async {
    if (!mounted || !_isAppResumed) return;
    final availability = await _locationService.getAvailability();
    if (!mounted) return;

    if (availability == LocationAvailability.disabled) {
      _gpsRetryTimer?.cancel();
      _locationFixTimer?.cancel();
      _statusService.updateGpsStatus(TouristGpsStatus.disabled);
      _statusService.updateStatus(false);
      await _locationService.stopTracking();
      return;
    }
    if (availability == LocationAvailability.permissionDenied) {
      _gpsRetryTimer?.cancel();
      _locationFixTimer?.cancel();
      _statusService.updateGpsStatus(TouristGpsStatus.permissionDenied);
      _statusService.updateStatus(false);
      await _locationService.stopTracking();
      return;
    }
    if (availability == LocationAvailability.active &&
        _trackingEnabled &&
        !_locationService.isTracking) {
      _gpsRetryTimer?.cancel();
      unawaited(_startLocationTracking());
    }
  }

  Future<void> _loadSafeZone() async {
    final safeZone = await _safeZoneService.getActiveSafeZone();

    if (!mounted) return;

    setState(() {
      _safeZone = safeZone;
    });

    _checkSafeZone();
    _publishSafetyStatus();
  }

  Future<void> _loadDangerZones() async {
    final dangerZones = await _safeZoneService.getActiveDangerZones();

    if (!mounted) return;

    setState(() {
      _dangerZones = dangerZones;
      _dangerZoneInsideStates.removeWhere(
        (id, _) => !dangerZones.any((zone) => zone.id == id),
      );
    });

    _checkDangerZones();
    _publishSafetyStatus();
  }

  Future<void> _startLocationTracking() async {
    if (!mounted ||
        !_isAppResumed ||
        !_trackingEnabled ||
        _isStartingLocationTracking) {
      return;
    }
    if (_locationService.isTracking) return;
    _isStartingLocationTracking = true;
    _hasReceivedLocation = false;
    try {
      await _locationService.startTracking(
        onLocationUpdate: (Position position) {
          if (!mounted) return;

          final location = LatLng(position.latitude, position.longitude);

          _currentPosition = position;
          _hasReceivedLocation = true;
          _gpsRetryPolicy.reset();
          _gpsRetryTimer?.cancel();
          _locationFixTimer?.cancel();
          setState(() {
            _currentLocation = location;
          });

          _statusService.updateGpsStatus(TouristGpsStatus.active);
          _checkSafeZone();
          _checkDangerZones();
          _publishSafetyStatus();

          _mapController.move(location, 15);
        },
        onStatusChanged: _handleLocationAvailability,
      );
    } finally {
      _isStartingLocationTracking = false;
    }
  }

  Future<void> _retryLocationTracking() async {
    if (!mounted || !_isAppResumed || !_trackingEnabled) return;
    _gpsRetryTimer?.cancel();
    _locationFixTimer?.cancel();
    _gpsRetryPolicy.reset();
    _hasReceivedLocation = false;
    await _locationService.stopTracking();
    if (!mounted) return;
    _statusService.updateGpsStatus(TouristGpsStatus.retrying);
    await _startLocationTracking();
  }

  void _handleLocationAvailability(LocationAvailability availability) {
    if (!mounted) return;
    switch (availability) {
      case LocationAvailability.active:
        _statusService.updateGpsStatus(TouristGpsStatus.active);
        _locationFixTimer?.cancel();
        _locationFixTimer = Timer(const Duration(seconds: 20), () {
          if (!mounted || _hasReceivedLocation) return;
          unawaited(_locationService.stopTracking());
          _scheduleGpsRetry();
        });
      case LocationAvailability.disabled:
        _gpsRetryTimer?.cancel();
        _locationFixTimer?.cancel();
        _statusService.updateGpsStatus(TouristGpsStatus.disabled);
        _statusService.updateStatus(false);
      case LocationAvailability.permissionDenied:
        _gpsRetryTimer?.cancel();
        _locationFixTimer?.cancel();
        _statusService.updateGpsStatus(TouristGpsStatus.permissionDenied);
        _statusService.updateStatus(false);
      case LocationAvailability.unavailable:
        _scheduleGpsRetry();
    }
  }

  void _scheduleGpsRetry() {
    _locationFixTimer?.cancel();
    final delay = _gpsRetryPolicy.nextDelay();
    if (delay == null) {
      _statusService.updateGpsStatus(TouristGpsStatus.unavailable);
      _statusService.updateStatus(false);
      return;
    }

    _statusService.updateGpsStatus(TouristGpsStatus.retrying);
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = Timer(delay, () {
      if (!mounted || !_isAppResumed) return;
      unawaited(_startLocationTracking());
    });
  }

  void _publishSafetyStatus() {
    final position = _currentPosition;
    if (position == null) {
      return;
    }
    _statusService.updateLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      updatedAt: position.timestamp,
      safeZone: _safeZone,
      dangerZones: _dangerZones,
      safeZoneService: _safeZoneService,
      precomputedDistanceToSafeZone: _safeZone == null
          ? null
          : _distanceFromSafeZone,
      precomputedInsideSafeZone: _safeZone == null ? null : _isInsideSafeZone,
      precomputedInsideDangerZone: _dangerZoneInsideStates.values.any(
        (inside) => inside,
      ),
    );
  }

  Future<void> _checkSafeZone() async {
    if (_currentLocation == null || _safeZone == null) {
      return;
    }

    final distance = _safeZoneService.calculateDistance(
      touristLatitude: _currentLocation!.latitude,
      touristLongitude: _currentLocation!.longitude,
      safeZone: _safeZone!,
    );

    final inside = distance <= _safeZone!.radius;

    debugPrint('📏 Distance from Safe Zone: ${distance.toStringAsFixed(1)}m.');
    debugPrint(
      '📍 Tourist Safe Zone state: '
      '${inside ? 'INSIDE' : 'OUTSIDE'}.',
    );

    if (!mounted) return;

    setState(() {
      _distanceFromSafeZone = distance;
      _isInsideSafeZone = inside;
    });

    // Detect outside → inside transition.
    final enteredSafeZone =
        _hasCheckedSafeZone && !_wasInsideSafeZone && inside;
    final exitedSafeZone = _hasCheckedSafeZone && _wasInsideSafeZone && !inside;

    // Record this state before awaiting Firestore so overlapping GPS updates
    // cannot treat the same transition as a second transition.
    _wasInsideSafeZone = inside;
    _hasCheckedSafeZone = true;
    _statusService.updateStatus(inside);
    _publishSafetyStatus();

    if (enteredSafeZone) {
      debugPrint('🚶 Outside → inside Safe Zone transition detected.');
      await _safeZoneService.createSafeZoneNotification();
    } else if (exitedSafeZone) {
      debugPrint('🚶 Inside → outside Safe Zone transition detected.');
      await _safeZoneService.createZoneExitNotification();
    }
  }

  Future<void> _checkDangerZones() async {
    final location = _currentLocation;
    if (location == null) return;

    final enteredDangerZones = <DangerZone>[];
    for (final dangerZone in _dangerZones) {
      final insideDangerZone = _safeZoneService.isInsideDangerZone(
        touristLatitude: location.latitude,
        touristLongitude: location.longitude,
        dangerZone: dangerZone,
      );
      final wasInsideDangerZone = _dangerZoneInsideStates[dangerZone.id];

      debugPrint(
        '📍 Danger Zone ${dangerZone.name}: '
        '${insideDangerZone ? 'INSIDE' : 'OUTSIDE'}.',
      );

      _dangerZoneInsideStates[dangerZone.id] = insideDangerZone;

      if (wasInsideDangerZone == false && insideDangerZone) {
        debugPrint(
          '🚨 Outside → inside Danger Zone detected: ${dangerZone.name}.',
        );
        enteredDangerZones.add(dangerZone);
      }
    }

    for (final _ in enteredDangerZones) {
      await _safeZoneService.createDangerZoneNotification();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopZoneRefreshTimers();
    _gpsRetryTimer?.cancel();
    _locationFixTimer?.cancel();
    _gpsStatusPollTimer?.cancel();
    unawaited(_serviceStatusSubscription?.cancel());
    _statusService.registerRetryHandler(null);
    _statusService.registerTrackingHandler(null);
    unawaited(_locationService.stopTracking());
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
        border: Border.all(color: const Color(0xFF334155)),
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
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 8),
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
                    userAgentPackageName: 'com.example.smart_tourist_safety',
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
