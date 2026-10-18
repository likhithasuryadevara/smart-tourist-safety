import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';
import '../services/location_service.dart';
import '../services/safe_zone_service.dart';
import '../services/safe_zone_status_service.dart';
import '../services/tourist_settings_service.dart';
import '../utils/app_error_message.dart';

/// Full-screen Tourist safety map.
///
/// Shows the tourist's live location and the safe/danger zones already used by
/// the dashboard map, using the same `flutter_map`/OpenStreetMap configuration.
/// The screen only reads the shared safety status stream, so it never stops the
/// dashboard's live location tracking.
class TouristFullScreenMapScreen extends StatefulWidget {
  const TouristFullScreenMapScreen({
    super.key,
    this.safeZoneService,
    this.locationService,
  });

  final SafeZoneService? safeZoneService;
  final LocationService? locationService;

  @override
  State<TouristFullScreenMapScreen> createState() =>
      _TouristFullScreenMapScreenState();
}

class _TouristFullScreenMapScreenState extends State<TouristFullScreenMapScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  late final SafeZoneService _safeZoneService =
      widget.safeZoneService ?? SafeZoneService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
  final StreamController<void> _tileResetController = StreamController<void>();

  StreamSubscription<TouristSafetySnapshot>? _statusSubscription;
  Timer? _zoneRefreshTimer;

  LatLng? _currentLocation;
  bool _hasLiveLocation = false;
  TouristGpsStatus _gpsStatus = TouristGpsStatus.unavailable;
  bool _followLocation = true;
  bool _locatingLocation = false;
  String? _locationMessage;
  bool _locationTrackingDisabled = false;

  List<SafeZone> _safeZones = const [];
  List<DangerZone> _dangerZones = const [];
  bool _safeZonesLoading = true;
  bool _dangerZonesLoading = true;
  bool _safeZonesLoaded = false;
  bool _dangerZonesLoaded = false;
  Object? _safeZonesError;
  Object? _dangerZonesError;
  bool _loadingSafeZones = false;
  bool _loadingDangerZones = false;

  bool _mapReady = false;
  Object? _mapError;
  bool _tileLoadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySafetySnapshot(SafeZoneStatusService().snapshot);
    _statusSubscription = SafeZoneStatusService().statusStream.listen(
      _applySafetySnapshot,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Full-screen map: safety status stream failed: $error');
        debugPrint('Full-screen map: status stream stack trace: $stackTrace');
      },
    );
    _loadLocationTrackingPreference();
    _loadZones();
    _zoneRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadZones(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSubscription?.cancel();
    _zoneRefreshTimer?.cancel();
    _tileResetController.close();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadZones();
    }
  }

  Future<void> _loadLocationTrackingPreference() async {
    try {
      final settings = await TouristSettingsService.shared.load();
      if (!mounted) return;
      setState(
        () => _locationTrackingDisabled = !settings.effectiveLocationTracking,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Full-screen map: settings unavailable, using safe defaults: $error',
      );
      debugPrint('Full-screen map: settings load stack trace: $stackTrace');
    }
  }

  void _applySafetySnapshot(TouristSafetySnapshot snapshot) {
    final hasLiveLocation =
        snapshot.hasLocation && snapshot.gpsStatus == TouristGpsStatus.active;
    final location = hasLiveLocation
        ? LatLng(snapshot.latitude!, snapshot.longitude!)
        : _currentLocation;

    setState(() {
      _gpsStatus = snapshot.gpsStatus;
      _hasLiveLocation = hasLiveLocation;
      _currentLocation = location;
      _locationMessage = null;
    });

    if (hasLiveLocation && _followLocation) _centerOnCurrentLocation();
  }

  void _handleMapReady() {
    if (!mounted) return;
    setState(() => _mapReady = true);
    if (_followLocation) _centerOnCurrentLocation();
  }

  void _handlePositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && _followLocation && mounted) {
      setState(() => _followLocation = false);
    }
  }

  void _centerOnCurrentLocation() {
    final location = _currentLocation;
    if (location == null || !_mapReady || !mounted) return;
    try {
      _mapController.move(location, TouristMapConfig.initialZoom);
      setState(() => _mapError = null);
    } catch (error, stackTrace) {
      AppErrorMessage.log(error, stackTrace, context: 'Centering Tourist map');
      if (mounted) setState(() => _mapError = error);
    }
  }

  void _zoomBy(double zoomChange) {
    if (!_mapReady || !mounted) return;
    try {
      final camera = _mapController.camera;
      final nextZoom = (camera.zoom + zoomChange).clamp(
        TouristMapConfig.minZoom,
        TouristMapConfig.maxZoom,
      );
      _mapController.move(camera.center, nextZoom.toDouble());
      setState(() {
        _followLocation = false;
        _mapError = null;
      });
    } catch (error, stackTrace) {
      AppErrorMessage.log(error, stackTrace, context: 'Zooming Tourist map');
      if (mounted) setState(() => _mapError = error);
    }
  }

  Future<void> _locateCurrentLocation() async {
    if (_locatingLocation) return;
    if (_locationTrackingDisabled) {
      setState(
        () => _locationMessage =
            'Location tracking is turned off in your Tourist settings. '
            'Turn on location sharing and tracking to see your live location.',
      );
      return;
    }

    setState(() {
      _locatingLocation = true;
      _locationMessage = null;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (position == null) {
        setState(
          () => _locationMessage =
              'Unable to get your current location. Check that location '
              'permission is granted and try again.',
        );
        return;
      }

      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = location;
        _hasLiveLocation = true;
        _followLocation = true;
        _locationMessage = null;
      });
      _centerOnCurrentLocation();
    } catch (error, stackTrace) {
      AppErrorMessage.log(
        error,
        stackTrace,
        context: 'Getting Tourist current location',
      );
      if (mounted) {
        setState(
          () => _locationMessage = AppErrorMessage.from(
            error,
            fallback: 'Unable to get your current location. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locatingLocation = false);
    }
  }

  Future<void> _loadSafeZones() async {
    if (_loadingSafeZones) return;
    _loadingSafeZones = true;
    if (!_safeZonesLoaded && mounted) {
      setState(() => _safeZonesLoading = true);
    }
    try {
      final safeZones = await _safeZoneService.getActiveSafeZones();
      if (!mounted) return;
      setState(() {
        _safeZones = safeZones;
        _safeZonesError = null;
        _safeZonesLoading = false;
        _safeZonesLoaded = true;
      });
    } catch (error, stackTrace) {
      AppErrorMessage.log(error, stackTrace, context: 'Loading safe zones');
      if (!mounted) return;
      setState(() {
        _safeZones = const [];
        _safeZonesError = error;
        _safeZonesLoading = false;
        _safeZonesLoaded = true;
      });
    } finally {
      _loadingSafeZones = false;
    }
  }

  Future<void> _loadDangerZones() async {
    if (_loadingDangerZones) return;
    _loadingDangerZones = true;
    if (!_dangerZonesLoaded && mounted) {
      setState(() => _dangerZonesLoading = true);
    }
    try {
      final dangerZones = await _safeZoneService.getActiveDangerZones();
      if (!mounted) return;
      setState(() {
        _dangerZones = dangerZones;
        _dangerZonesError = null;
        _dangerZonesLoading = false;
        _dangerZonesLoaded = true;
      });
    } catch (error, stackTrace) {
      AppErrorMessage.log(error, stackTrace, context: 'Loading danger zones');
      if (!mounted) return;
      setState(() {
        _dangerZones = const [];
        _dangerZonesError = error;
        _dangerZonesLoading = false;
        _dangerZonesLoaded = true;
      });
    } finally {
      _loadingDangerZones = false;
    }
  }

  Future<void> _loadZones() =>
      Future.wait([_loadSafeZones(), _loadDangerZones()]);

  Future<void> _retryZones() async {
    _tileResetController.add(null);
    await _loadZones();
  }

  bool get _isInsideDangerZone {
    final location = _currentLocation;
    if (location == null || _dangerZones.isEmpty) return false;
    return _dangerZones.any(
      (zone) => _safeZoneService.isInsideDangerZone(
        touristLatitude: location.latitude,
        touristLongitude: location.longitude,
        dangerZone: zone,
      ),
    );
  }

  double? get _distanceToNearestSafeZone {
    final location = _currentLocation;
    if (location == null || _safeZones.isEmpty) return null;
    return _safeZones
        .map(
          (zone) => _safeZoneService.calculateDistance(
            touristLatitude: location.latitude,
            touristLongitude: location.longitude,
            safeZone: zone,
          ),
        )
        .reduce((a, b) => a < b ? a : b);
  }

  bool get _isInsideSafeZone {
    final location = _currentLocation;
    if (location == null || _safeZones.isEmpty) return false;
    return _safeZones.any(
      (zone) => _safeZoneService.isInsideSafeZone(
        touristLatitude: location.latitude,
        touristLongitude: location.longitude,
        safeZone: zone,
      ),
    );
  }

  String get _locationStatusText {
    if (_locationTrackingDisabled) {
      return 'Location tracking is off in your Tourist settings.';
    }
    if (_locationMessage != null) return _locationMessage!;
    if (_currentLocation != null && _hasLiveLocation) {
      return 'Live location ${_currentLocation!.latitude.toStringAsFixed(4)}, '
          '${_currentLocation!.longitude.toStringAsFixed(4)}';
    }
    if (_currentLocation != null) {
      return 'Last known location '
          '${_currentLocation!.latitude.toStringAsFixed(4)}, '
          '${_currentLocation!.longitude.toStringAsFixed(4)}; '
          'current location unavailable.';
    }
    switch (_gpsStatus) {
      case TouristGpsStatus.active:
        return 'Locating your current location...';
      case TouristGpsStatus.disabled:
        return 'Location services are turned off on this device.';
      case TouristGpsStatus.permissionDenied:
      case TouristGpsStatus.permissionDeniedForever:
        return 'Location permission is needed to show your current location.';
      case TouristGpsStatus.retrying:
        return 'Retrying to get your current location...';
      case TouristGpsStatus.unavailable:
        return 'Your current location is not available yet.';
    }
  }

  String get _zoneStatusText {
    if (_safeZonesError != null) {
      return AppErrorMessage.from(
        _safeZonesError!,
        fallback: 'Unable to load safe zone information.',
      );
    }
    if (_dangerZonesError != null) {
      return AppErrorMessage.from(
        _dangerZonesError!,
        fallback: 'Unable to load danger zone information.',
      );
    }
    if (_safeZonesLoading || _dangerZonesLoading) {
      return 'Loading safe and danger zone information...';
    }
    if (_safeZones.isEmpty && _dangerZones.isEmpty) {
      return 'No active safe or danger zones are available.';
    }
    if (_currentLocation == null) {
      return '${_safeZones.length} safe and ${_dangerZones.length} danger '
          'zone(s) shown; zone status needs your current location.';
    }
    if (_isInsideDangerZone) {
      return 'INSIDE DANGER ZONE (${_dangerZones.length} active)';
    }
    if (_isInsideSafeZone) return 'Inside Safe Zone';
    final distance = _distanceToNearestSafeZone;
    return distance == null
        ? 'No active safe zone is available.'
        : 'Outside Safe Zone • ${distance.toStringAsFixed(0)} m from nearest';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: TouristMapConfig.mapBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        title: const Text('Live Safety Map'),
        leading: _MapCircleButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mediaQuery.padding.top + kToolbarHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0x99111C31), const Color(0x00111C31)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: mediaQuery.padding.top + kToolbarHeight + 8,
            left: 12,
            right: 12,
            child: _buildMapIssueBanner(),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MapCircleButton(
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onPressed: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 10),
                  _MapCircleButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onPressed: () => _zoomBy(-1),
                  ),
                  const SizedBox(height: 10),
                  _MapCircleButton(
                    icon: _locatingLocation
                        ? Icons.hourglass_top
                        : Icons.my_location,
                    tooltip: 'My current location',
                    onPressed: _locatingLocation
                        ? null
                        : _locateCurrentLocation,
                  ),
                  if (!_followLocation && _currentLocation != null) ...[
                    const SizedBox(height: 10),
                    _MapCircleButton(
                      icon: Icons.center_focus_strong,
                      tooltip: 'Follow my location',
                      onPressed: () {
                        setState(() => _followLocation = true);
                        _centerOnCurrentLocation();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomPanel()),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _currentLocation ?? TouristMapConfig.fallbackCenter;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: TouristMapConfig.initialZoom,
        minZoom: TouristMapConfig.minZoom,
        maxZoom: TouristMapConfig.maxZoom,
        backgroundColor: TouristMapConfig.mapBackgroundColor,
        onMapReady: _handleMapReady,
        onPositionChanged: _handlePositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: TouristMapConfig.tileUrlTemplate,
          userAgentPackageName: TouristMapConfig.userAgentPackageName,
          reset: _tileResetController.stream,
          errorTileCallback: (_, Object error, StackTrace? stackTrace) {
            debugPrint('Full-screen map: tile load failed: $error');
            if (stackTrace != null) {
              debugPrint(
                'Full-screen map: tile failure stack trace: $stackTrace',
              );
            }
            if (!_tileLoadFailed && mounted) {
              setState(() => _tileLoadFailed = true);
            }
          },
        ),
        if (_safeZones.isNotEmpty)
          CircleLayer(
            circles: [
              for (final zone in _safeZones)
                CircleMarker(
                  point: LatLng(zone.latitude, zone.longitude),
                  radius: zone.radius,
                  useRadiusInMeter: true,
                  color: _currentLocation == null
                      ? const Color(0x1F64748B)
                      : _isInsideSafeZone
                      ? const Color(0x3322C55E)
                      : const Color(0x33EF4444),
                  borderColor: _currentLocation == null
                      ? const Color(0xFF64748B)
                      : _isInsideSafeZone
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
            if (_currentLocation != null)
              Marker(
                point: _currentLocation!,
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
                    child: Icon(Icons.person, color: Colors.white, size: 24),
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
    );
  }

  Widget _buildMapIssueBanner() {
    if (_mapError != null) {
      return _MapBanner(
        message: AppErrorMessage.from(
          _mapError!,
          fallback: 'The map could not be updated. Close and reopen the map.',
        ),
        actionLabel: 'DISMISS',
        onAction: () => setState(() => _mapError = null),
        isError: true,
      );
    }
    if (_tileLoadFailed) {
      return _MapBanner(
        message:
            'Map tiles could not be loaded. Check your internet connection '
            'and try again.',
        actionLabel: 'RETRY',
        onAction: () {
          setState(() => _tileLoadFailed = false);
          _tileResetController.add(null);
        },
        isError: true,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomPanel() {
    final locationHasError =
        _locationMessage != null ||
        _locationTrackingDisabled ||
        (!_hasLiveLocation &&
            (_gpsStatus == TouristGpsStatus.disabled ||
                _gpsStatus == TouristGpsStatus.permissionDenied ||
                _gpsStatus == TouristGpsStatus.permissionDeniedForever));
    final zonesHaveError = _safeZonesError != null || _dangerZonesError != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _hasLiveLocation
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  size: 20,
                  color: _hasLiveLocation
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF73818A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _locationStatusText,
                        style: TextStyle(
                          color: locationHasError
                              ? const Color(0xFFB5473C)
                              : const Color(0xFF172B35),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _locationAction,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            _locationActionLabel,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _zoneStatusText,
                    style: TextStyle(
                      color: _isInsideDangerZone || zonesHaveError
                          ? const Color(0xFFB5473C)
                          : const Color(0xFF73818A),
                      fontSize: 11,
                      fontWeight: _isInsideDangerZone || zonesHaveError
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (zonesHaveError)
                  TextButton(
                    onPressed: _retryZones,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'RETRY',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _LegendItem(color: Color(0xFF2563EB), label: 'You'),
                const _LegendItem(color: Color(0xFF22C55E), label: 'Safe zone'),
                const _LegendItem(
                  color: Color(0xFFEF4444),
                  label: 'Danger zone',
                ),
                const Text(
                  'Map data © OpenStreetMap',
                  style: TextStyle(
                    color: Color(0xFF73818A),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _locationActionLabel {
    if (_locatingLocation) return 'LOCATING...';
    if (_gpsStatus == TouristGpsStatus.disabled && !_hasLiveLocation) {
      return 'OPEN SETTINGS';
    }
    return 'LOCATE ME';
  }

  VoidCallback? get _locationAction {
    if (_locatingLocation) return null;
    if (_gpsStatus == TouristGpsStatus.disabled && !_hasLiveLocation) {
      return _openDeviceLocationSettings;
    }
    return _locateCurrentLocation;
  }

  Future<void> _openDeviceLocationSettings() async {
    try {
      final opened = await _locationService.openLocationSettings();
      if (!opened && mounted) {
        _showSnackBar('Unable to open device settings. Open them manually.');
      }
    } catch (error, stackTrace) {
      AppErrorMessage.log(
        error,
        stackTrace,
        context: 'Opening location settings',
      );
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF17233A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: enabled ? const Color(0xE6111C31) : const Color(0x8A111C31),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: enabled ? Colors.white : const Color(0xB3FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapBanner extends StatelessWidget {
  const _MapBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isError ? const Color(0xF2FEF2F2) : const Color(0xF2FFFFFF),
      elevation: 2,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              size: 18,
              color: isError
                  ? const Color(0xFFB5473C)
                  : const Color(0xFF172B35),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? const Color(0xFFB5473C)
                      : const Color(0xFF172B35),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  actionLabel!,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF73818A),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
