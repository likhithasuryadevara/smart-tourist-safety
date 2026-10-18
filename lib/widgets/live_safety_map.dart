import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/safe_zone_status_service.dart';

import '../config/map_config.dart';
import '../services/location_service.dart';
import '../services/safe_zone_service.dart';
import '../services/tourist_settings_service.dart';
import '../utils/app_error_message.dart';

class LiveSafetyMap extends StatefulWidget {
  final VoidCallback onFullscreen;
  final SafeZoneService? safeZoneService;
  final void Function(DangerZone?)? onDangerZoneChanged;

  const LiveSafetyMap({
    super.key,
    required this.onFullscreen,
    this.safeZoneService,
    this.onDangerZoneChanged,
  });

  @override
  State<LiveSafetyMap> createState() => _LiveSafetyMapState();
}

class _LiveSafetyMapState extends State<LiveSafetyMap>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();

  final LocationService _locationService = LocationService();
  late final SafeZoneService _safeZoneService =
      widget.safeZoneService ?? SafeZoneService();
  final SafeZoneStatusService _statusService = SafeZoneStatusService();

  Timer? _safeZoneRefreshTimer;
  Timer? _dangerZoneRefreshTimer;
  Timer? _gpsRetryTimer;
  Timer? _locationFixTimer;
  Timer? _gpsStatusPollTimer;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  LatLng? _currentLocation;
  Position? _currentPosition;
  List<SafeZone> _safeZones = [];
  SafeZone? get _safeZone => _safeZones.isNotEmpty ? _safeZones.first : null;
  final Map<String, bool> _safeZoneInsideStates = {};
  List<DangerZone> _dangerZones = [];
  final Map<String, bool> _dangerZoneInsideStates = {};
  final ZoneTransitionTracker _safeZoneTransitions = ZoneTransitionTracker();
  final ZoneTransitionTracker _dangerZoneTransitions = ZoneTransitionTracker();
  final GpsRetryPolicy _gpsRetryPolicy = GpsRetryPolicy();

  bool _isInsideSafeZone = false;
  bool _isStartingLocationTracking = false;
  bool _isAppResumed = true;
  bool _hasReceivedLocation = false;
  bool _trackingEnabled = true;
  double _distanceFromSafeZone = 0;
  bool _safeZoneLoading = true;
  bool _dangerZonesLoading = true;
  Object? _safeZoneError;
  Object? _dangerZonesError;
  bool _hasLoadedSafeZone = false;
  bool _hasLoadedDangerZones = false;
  bool _loadingSafeZoneRequest = false;
  bool _loadingDangerZoneRequest = false;
  bool _retryingZones = false;

  final LatLng _fallbackLocation = TouristMapConfig.fallbackCenter;

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
      _invalidateLiveLocation(TouristGpsStatus.unavailable);
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
    _invalidateLiveLocation(TouristGpsStatus.unavailable);
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
            _invalidateLiveLocation(TouristGpsStatus.disabled);
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
      _invalidateLiveLocation(TouristGpsStatus.disabled);
      await _locationService.stopTracking();
      return;
    }
    if (availability == LocationAvailability.permissionDenied) {
      _gpsRetryTimer?.cancel();
      _locationFixTimer?.cancel();
      _invalidateLiveLocation(TouristGpsStatus.permissionDenied);
      await _locationService.stopTracking();
      return;
    }
    if (availability == LocationAvailability.permissionDeniedForever) {
      _gpsRetryTimer?.cancel();
      _locationFixTimer?.cancel();
      _invalidateLiveLocation(TouristGpsStatus.permissionDeniedForever);
      await _locationService.stopTracking();
      return;
    }
    if (availability == LocationAvailability.active &&
        _trackingEnabled &&
        !_locationService.isTracking) {
      _gpsRetryTimer?.cancel();
      unawaited(_startLocationTracking());
      return;
    }
    if (availability == LocationAvailability.unavailable) {
      _scheduleGpsRetry();
    }
  }

  Future<void> _loadSafeZone() async {
    if (_loadingSafeZoneRequest) return;
    _loadingSafeZoneRequest = true;
    if (!_hasLoadedSafeZone && mounted) {
      setState(() => _safeZoneLoading = true);
    }
    try {
      final safeZones = await _safeZoneService.getActiveSafeZones();
      if (!mounted) return;
      setState(() {
        _safeZones = safeZones;
        _safeZoneError = null;
        _safeZoneLoading = false;
        _hasLoadedSafeZone = true;
      });
      _safeZoneInsideStates.removeWhere(
        (id, _) => !safeZones.any((zone) => (zone.id ?? '') == id),
      );
      if (safeZones.isEmpty) {
        _safeZoneTransitions.reset();
        _isInsideSafeZone = false;
        _distanceFromSafeZone = 0;
        _statusService.updateStatus(false);
      }
      await _checkSafeZones(processTransitions: false);
      _publishSafetyStatus();
    } catch (error, stackTrace) {
      AppErrorMessage.log(error, stackTrace, context: 'Loading safe zones');
      if (!mounted) return;
      setState(() {
        _safeZones = [];
        _safeZoneError = error;
        _safeZoneLoading = false;
        _hasLoadedSafeZone = true;
      });
      _safeZoneTransitions.reset();
      _safeZoneInsideStates.clear();
      _isInsideSafeZone = false;
      _distanceFromSafeZone = 0;
      _statusService.updateStatus(false);
      _publishSafetyStatus();
    } finally {
      _loadingSafeZoneRequest = false;
    }
  }

  Future<void> _loadDangerZones() async {
    if (_loadingDangerZoneRequest) return;
    _loadingDangerZoneRequest = true;
    if (!_hasLoadedDangerZones && mounted) {
      setState(() => _dangerZonesLoading = true);
    }
    try {
      final dangerZones = await _safeZoneService.getActiveDangerZones();
      if (!mounted) return;
      setState(() {
        _dangerZones = dangerZones;
        _dangerZonesError = null;
        _dangerZonesLoading = false;
        _hasLoadedDangerZones = true;
      });
      _dangerZoneInsideStates.removeWhere(
        (id, _) => !dangerZones.any((zone) => zone.id == id),
      );
      await _checkDangerZones(processTransitions: false);
      _publishSafetyStatus();
    } catch (error, stackTrace) {
      AppErrorMessage.log(error, stackTrace, context: 'Loading danger zones');
      if (!mounted) return;
      setState(() {
        _dangerZones = [];
        _dangerZonesError = error;
        _dangerZonesLoading = false;
        _hasLoadedDangerZones = true;
      });
      _dangerZoneTransitions.reset();
      _dangerZoneInsideStates.clear();
      _publishSafetyStatus();
    } finally {
      _loadingDangerZoneRequest = false;
    }
  }

  Future<void> _retryZoneInformation() async {
    if (_retryingZones) return;
    setState(() => _retryingZones = true);
    try {
      await Future.wait([_loadSafeZone(), _loadDangerZones()]);
    } finally {
      if (mounted) setState(() => _retryingZones = false);
    }
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
    _invalidateLiveLocation(TouristGpsStatus.retrying);
    try {
      await _locationService.startTracking(
        onLocationUpdate: (Position position) {
          if (!mounted) return;
          if (!SafeZoneService.isValidCoordinate(
            position.latitude,
            position.longitude,
          )) {
            debugPrint(
              'LiveSafetyMap: rejecting invalid location coordinates '
              '(${position.latitude}, ${position.longitude}).',
            );
            _invalidateLiveLocation(TouristGpsStatus.unavailable);
            return;
          }

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

          _mapController.move(location, TouristMapConfig.initialZoom);
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
    _invalidateLiveLocation(TouristGpsStatus.retrying);
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
        _invalidateLiveLocation(TouristGpsStatus.disabled);
      case LocationAvailability.permissionDenied:
        _gpsRetryTimer?.cancel();
        _locationFixTimer?.cancel();
        _invalidateLiveLocation(TouristGpsStatus.permissionDenied);
      case LocationAvailability.permissionDeniedForever:
        _gpsRetryTimer?.cancel();
        _locationFixTimer?.cancel();
        _invalidateLiveLocation(TouristGpsStatus.permissionDeniedForever);
      case LocationAvailability.unavailable:
        _scheduleGpsRetry();
    }
  }

  void _scheduleGpsRetry() {
    _locationFixTimer?.cancel();
    final delay = _gpsRetryPolicy.nextDelay();
    if (delay == null) {
      _invalidateLiveLocation(TouristGpsStatus.unavailable);
      return;
    }

    _invalidateLiveLocation(TouristGpsStatus.retrying);
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = Timer(delay, () {
      if (!mounted || !_isAppResumed) return;
      unawaited(_startLocationTracking());
    });
  }

  void _invalidateLiveLocation(TouristGpsStatus status) {
    _currentPosition = null;
    _currentLocation = null;
    _hasReceivedLocation = false;
    _safeZoneTransitions.reset();
    _dangerZoneTransitions.reset();
    _safeZoneInsideStates.clear();
    _dangerZoneInsideStates.clear();
    _isInsideSafeZone = false;
    _distanceFromSafeZone = 0;
    _statusService.updateGpsStatus(status);
    if (mounted) setState(() {});
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
      safeZones: _safeZones,
      dangerZones: _dangerZones,
      safeZoneService: _safeZoneService,
      precomputedDistanceToSafeZone: _safeZones.isEmpty
          ? null
          : _distanceFromSafeZone,
      precomputedInsideSafeZone: _safeZones.isEmpty ? null : _isInsideSafeZone,
      precomputedInsideDangerZone: _dangerZoneInsideStates.values.any(
        (inside) => inside,
      ),
      zoneInformationAvailable:
          _hasLoadedSafeZone &&
          _hasLoadedDangerZones &&
          _safeZoneError == null &&
          _dangerZonesError == null,
    );
  }

  Future<void> _checkSafeZone({bool processTransitions = true}) =>
      _checkSafeZones(processTransitions: processTransitions);

  Future<void> _checkSafeZones({bool processTransitions = true}) async {
    final location = _currentLocation;
    if (location == null || _safeZones.isEmpty) {
      return;
    }

    final currentStates = <String, bool>{};
    double? minDistance;
    var anyInside = false;

    for (var i = 0; i < _safeZones.length; i++) {
      final safeZone = _safeZones[i];
      final zoneId = safeZone.id ?? 'safe_zone_$i';
      final distance = _safeZoneService.calculateDistance(
        touristLatitude: location.latitude,
        touristLongitude: location.longitude,
        safeZone: safeZone,
      );
      final inside = distance <= safeZone.radius;
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
      }
      if (inside) {
        anyInside = true;
      }
      _safeZoneInsideStates[zoneId] = inside;
      currentStates[zoneId] = inside;

      debugPrint(
        'Safe Zone ${safeZone.name ?? zoneId}: '
        '${inside ? 'INSIDE' : 'OUTSIDE'} (${distance.toStringAsFixed(1)}m).',
      );
    }

    if (!mounted) return;

    setState(() {
      _distanceFromSafeZone = minDistance ?? 0;
      _isInsideSafeZone = anyInside;
    });

    final transitions = _safeZoneTransitions.update(currentStates);
    _statusService.updateStatus(anyInside);
    _publishSafetyStatus();

    if (processTransitions) {
      for (final transition in transitions) {
        final zoneMatches = _safeZones.where(
          (item) => (item.id ?? '') == transition.zoneId,
        );
        final zone = zoneMatches.isNotEmpty ? zoneMatches.first : null;
        final zoneName = zone?.name ?? transition.zoneId;

        if (transition.entered) {
          debugPrint(
            'Outside → inside Safe Zone (${transition.zoneId}) transition detected.',
          );
          await _safeZoneService.recordGeoFenceAlert(
            zoneId: transition.zoneId,
            zoneName: zoneName,
            eventType: 'ENTER',
            latitude: location.latitude,
            longitude: location.longitude,
            zoneType: 'Safe',
          );
        } else {
          debugPrint(
            'Inside → outside Safe Zone (${transition.zoneId}) transition detected.',
          );
          await _safeZoneService.recordGeoFenceAlert(
            zoneId: transition.zoneId,
            zoneName: zoneName,
            eventType: 'EXIT',
            latitude: location.latitude,
            longitude: location.longitude,
            zoneType: 'Safe',
          );
        }
      }
    }
  }

  Future<void> _checkDangerZones({bool processTransitions = true}) async {
    final location = _currentLocation;
    if (location == null) return;

    final currentStates = <String, bool>{};
    for (final dangerZone in _dangerZones) {
      final insideDangerZone = _safeZoneService.isInsideDangerZone(
        touristLatitude: location.latitude,
        touristLongitude: location.longitude,
        dangerZone: dangerZone,
      );
      debugPrint(
        'Danger Zone ${dangerZone.name ?? dangerZone.id}: '
        '${insideDangerZone ? 'INSIDE' : 'OUTSIDE'}.',
      );

      _dangerZoneInsideStates[dangerZone.id] = insideDangerZone;
      currentStates[dangerZone.id] = insideDangerZone;
    }

    final transitions = _dangerZoneTransitions.update(currentStates);
    _notifyDangerZoneChange();
    if (!processTransitions) return;

    for (final transition in transitions) {
      final zoneMatches = _dangerZones.where(
        (item) => item.id == transition.zoneId,
      );
      final zone = zoneMatches.isNotEmpty ? zoneMatches.first : null;
      final zoneName = zone?.name ?? transition.zoneId;

      if (transition.entered) {
        debugPrint('Outside → inside Danger Zone detected: $zoneName.');
        await _safeZoneService.recordGeoFenceAlert(
          zoneId: transition.zoneId,
          zoneName: zoneName,
          eventType: 'ENTER',
          latitude: location.latitude,
          longitude: location.longitude,
          zoneType: 'Danger',
        );
      } else {
        debugPrint('Inside → outside Danger Zone detected: $zoneName.');
        await _safeZoneService.recordGeoFenceAlert(
          zoneId: transition.zoneId,
          zoneName: zoneName,
          eventType: 'EXIT',
          latitude: location.latitude,
          longitude: location.longitude,
          zoneType: 'Danger',
        );
      }
    }
  }

  void _notifyDangerZoneChange() {
    if (widget.onDangerZoneChanged == null) return;

    DangerZone? currentDangerZone;
    for (final zone in _dangerZones) {
      if (_dangerZoneInsideStates[zone.id] == true) {
        currentDangerZone = zone;
        break;
      }
    }

    widget.onDangerZoneChanged!(currentDangerZone);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopZoneRefreshTimers();
    _gpsRetryTimer?.cancel();
    _locationFixTimer?.cancel();
    _gpsStatusPollTimer?.cancel();
    unawaited(_serviceStatusSubscription?.cancel());
    _serviceStatusSubscription = null;
    _statusService.registerRetryHandler(null);
    _statusService.registerTrackingHandler(null);
    unawaited(_locationService.stopTracking());
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentLocation ?? _fallbackLocation;
    final hasLiveLocation =
        _statusService.snapshot.gpsStatus == TouristGpsStatus.active &&
        _currentLocation != null;

    return Container(
      height: 390,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EBEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F766E),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 10, 11),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Tourist Safety Map',
                        style: TextStyle(
                          color: Color(0xFF172B35),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Real-time safety and location',
                        style: TextStyle(
                          color: Color(0xFF73818A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onFullscreen,
                  icon: const Icon(Icons.open_in_full_rounded, size: 16),
                  label: const Text(
                    'Full screen',
                    maxLines: 1,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE4EBEA)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: TouristMapConfig.initialZoom,
                      minZoom: TouristMapConfig.minZoom,
                      maxZoom: TouristMapConfig.maxZoom,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: TouristMapConfig.tileUrlTemplate,
                        userAgentPackageName:
                            TouristMapConfig.userAgentPackageName,
                      ),

                      if (_safeZones.isNotEmpty)
                        CircleLayer(
                          circles: [
                            for (var i = 0; i < _safeZones.length; i++)
                              CircleMarker(
                                point: LatLng(
                                  _safeZones[i].latitude,
                                  _safeZones[i].longitude,
                                ),
                                radius: _safeZones[i].radius,
                                useRadiusInMeter: true,
                                color: !_hasReceivedLocation
                                    ? const Color(0x1F64748B)
                                    : (_safeZoneInsideStates[_safeZones[i].id ??
                                              'safe_zone_$i'] ??
                                          false)
                                    ? const Color(0x3322C55E)
                                    : const Color(0x33EF4444),
                                borderColor: !_hasReceivedLocation
                                    ? const Color(0xFF64748B)
                                    : (_safeZoneInsideStates[_safeZones[i].id ??
                                              'safe_zone_$i'] ??
                                          false)
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                                borderStrokeWidth: 2,
                              ),
                          ],
                        ),

                      if (_dangerZones.isNotEmpty)
                        CircleLayer(
                          circles: [
                            for (final zone in _dangerZones)
                              CircleMarker(
                                point: LatLng(zone.latitude, zone.longitude),
                                radius: zone.radius,
                                useRadiusInMeter: true,
                                color: const Color(0x22EF4444),
                                borderColor: const Color(0xFFEF4444),
                                borderStrokeWidth: 2,
                              ),
                          ],
                        ),

                      MarkerLayer(
                        markers: [
                          if (hasLiveLocation)
                            Marker(
                              point: center,
                              width: 60,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0x442563EB),
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
                          for (final zone in _safeZones)
                            Marker(
                              point: LatLng(zone.latitude, zone.longitude),
                              width: 32,
                              height: 32,
                              child: Tooltip(
                                message: zone.name != null
                                    ? (zone.type != null
                                          ? '${zone.name} (${zone.type})'
                                          : zone.name!)
                                    : 'Safe zone',
                                child: const Icon(
                                  Icons.shield_rounded,
                                  color: Color(0xFF16805D),
                                  size: 28,
                                ),
                              ),
                            ),
                          for (final zone in _dangerZones)
                            Marker(
                              point: LatLng(zone.latitude, zone.longitude),
                              width: 32,
                              height: 32,
                              child: Tooltip(
                                message: zone.name != null
                                    ? (zone.dangerLevel != null
                                          ? '${zone.name} (${zone.dangerLevel})'
                                          : zone.name!)
                                    : 'Danger zone',
                                child: const Icon(
                                  Icons.warning_rounded,
                                  color: Color(0xFFB5473C),
                                  size: 28,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _safeZoneStatusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _safeZoneError != null
                        ? const Color(0xFFB5473C)
                        : !_hasReceivedLocation
                        ? const Color(0xFF64748B)
                        : _isInsideSafeZone
                        ? const Color(0xFF16805D)
                        : const Color(0xFFB5473C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _dangerZoneStatusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        _dangerZonesError != null ||
                            _dangerZoneInsideStates.values.any((v) => v)
                        ? const Color(0xFFB5473C)
                        : const Color(0xFF73818A),
                    fontSize: 10,
                    fontWeight: _dangerZoneInsideStates.values.any((v) => v)
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                if (_safeZoneError != null || _dangerZonesError != null)
                  TextButton.icon(
                    onPressed: _retryingZones ? null : _retryZoneInformation,
                    icon: _retryingZones
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 15),
                    label: Text(
                      _retryingZones
                          ? 'Retrying zone information...'
                          : 'Retry zone information',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2DD4BF),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _safeZoneStatusText {
    if (_safeZoneError != null) {
      return AppErrorMessage.from(
        _safeZoneError!,
        fallback: 'Unable to load safe zone information.',
      );
    }
    if (_safeZoneLoading) return 'Loading safe zone information...';
    if (_safeZones.isEmpty) return 'No active safe zone information available.';
    if (!_hasReceivedLocation ||
        _statusService.snapshot.gpsStatus != TouristGpsStatus.active) {
      return 'Safe-zone status unavailable without a current location.';
    }
    if (_isInsideSafeZone) {
      return 'Inside Safe Zone';
    }
    return _safeZones.length > 1
        ? 'Outside Safe Zones • ${_distanceFromSafeZone.toStringAsFixed(0)} m from nearest'
        : 'Outside Safe Zone • ${_distanceFromSafeZone.toStringAsFixed(0)} m from center';
  }

  String get _dangerZoneStatusText {
    if (_dangerZonesError != null) {
      return AppErrorMessage.from(
        _dangerZonesError!,
        fallback: 'Unable to load danger zone information.',
      );
    }
    if (_dangerZonesLoading) return 'Loading danger zone information...';
    if (_dangerZones.isEmpty) return 'No active danger zones.';
    if (!_hasReceivedLocation ||
        _statusService.snapshot.gpsStatus != TouristGpsStatus.active) {
      return '${_dangerZones.length} active danger zone(s); proximity unavailable without a current location.';
    }
    final insideCount = _dangerZoneInsideStates.values.where((v) => v).length;
    if (insideCount > 0) {
      return 'INSIDE DANGER ZONE ($insideCount active)';
    }
    return '${_dangerZones.length} active danger zone(s) monitored';
  }
}
