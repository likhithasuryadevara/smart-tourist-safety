import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/safe_zone_status_service.dart';

class TouristSafetyStatus extends StatefulWidget {
  const TouristSafetyStatus({super.key});

  @override
  State<TouristSafetyStatus> createState() => _TouristSafetyStatusState();
}

class _TouristSafetyStatusState extends State<TouristSafetyStatus> {
  bool _retryingManually = false;
  final LocationService _locationService = LocationService();

  Future<void> _retryGps() async {
    setState(() => _retryingManually = true);
    try {
      await SafeZoneStatusService().retryGps();
    } catch (error, stackTrace) {
      debugPrint('Tourist safety GPS retry failed: $error');
      debugPrint('Tourist safety GPS retry stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to restart GPS monitoring.')),
        );
      }
    } finally {
      if (mounted) setState(() => _retryingManually = false);
    }
  }

  Future<void> _openLocationSettings({required bool appSettings}) async {
    try {
      final opened = appSettings
          ? await _locationService.openAppSettings()
          : await _locationService.openLocationSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open device settings. Please open them manually.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to open location settings: $error');
      debugPrint('Location settings stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open device settings. Please open them manually.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusService = SafeZoneStatusService();
    return StreamBuilder<TouristSafetySnapshot>(
      stream: statusService.statusStream,
      initialData: statusService.snapshot,
      builder: (context, snapshot) {
        final status = snapshot.data ?? statusService.snapshot;
        final gpsLabel = switch (status.gpsStatus) {
          TouristGpsStatus.active => 'ACTIVE',
          TouristGpsStatus.disabled => 'DISABLED',
          TouristGpsStatus.permissionDenied => 'PERMISSION DENIED',
          TouristGpsStatus.permissionDeniedForever =>
            'PERMISSION DENIED - SETTINGS REQUIRED',
          TouristGpsStatus.unavailable => 'UNAVAILABLE',
          TouristGpsStatus.retrying => 'RETRYING',
        };
        final gpsColor = switch (status.gpsStatus) {
          TouristGpsStatus.active => const Color(0xFF15803D),
          TouristGpsStatus.retrying => const Color(0xFFB45309),
          TouristGpsStatus.permissionDeniedForever => const Color(0xFFB91C1C),
          _ => const Color(0xFFB91C1C),
        };
        final zoneLabel = switch (status.zoneStatus) {
          TouristZoneStatus.safe => 'SAFE ZONE',
          TouristZoneStatus.danger => 'DANGER ZONE',
          TouristZoneStatus.outsideSafeZone => 'OUTSIDE SAFE ZONE',
          TouristZoneStatus.unknown => 'UNKNOWN',
        };
        final isDanger =
            status.zoneStatus == TouristZoneStatus.danger ||
            status.zoneStatus == TouristZoneStatus.outsideSafeZone;
        final indicator = switch (status.zoneStatus) {
          TouristZoneStatus.safe => 'SAFE',
          TouristZoneStatus.danger => 'DANGER',
          TouristZoneStatus.outsideSafeZone => 'DANGER',
          TouristZoneStatus.unknown => 'UNKNOWN',
        };
        final indicatorColor = switch (status.zoneStatus) {
          TouristZoneStatus.safe => const Color(0xFF15803D),
          TouristZoneStatus.danger ||
          TouristZoneStatus.outsideSafeZone => const Color(0xFFB91C1C),
          TouristZoneStatus.unknown => const Color(0xFF64748B),
        };
        final distanceText = status.distanceToSafeZone == null
            ? 'Unavailable'
            : status.isInsideSafeZone
            ? 'Inside Safe Zone'
            : status.distanceToSafeZone! >= 1000
            ? '${(status.distanceToSafeZone! / 1000).toStringAsFixed(1)} km'
            : '${status.distanceToSafeZone!.round()} m';
        final gpsMessage = _gpsMessage(status.gpsStatus);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFFE6F4F1),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      color: Color(0xFF0F766E),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tourist Safety Status',
                      style: TextStyle(
                        color: Color(0xFF172B35),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 4 : 2;
                  final gap = 10.0;
                  final metricWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final metrics = [
                    _StatusValue(
                      title: 'GPS Status',
                      value: gpsLabel,
                      color: gpsColor,
                      icon: Icons.gps_fixed_rounded,
                    ),
                    _StatusValue(
                      title: 'Current Zone',
                      value: zoneLabel,
                      color: isDanger
                          ? const Color(0xFFB5473C)
                          : status.zoneStatus == TouristZoneStatus.safe
                          ? const Color(0xFF16805D)
                          : const Color(0xFF697980),
                      icon: Icons.map_outlined,
                    ),
                    _StatusValue(
                      title: 'Safety',
                      value: indicator,
                      color: indicatorColor,
                      icon: Icons.shield_outlined,
                    ),
                    _StatusValue(
                      title: 'Distance to Safe Zone',
                      value: distanceText,
                      color: const Color(0xFF263943),
                      icon: Icons.near_me_outlined,
                    ),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final metric in metrics)
                        SizedBox(width: metricWidth, child: metric),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEBF0EF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LAST LOCATION',
                      style: TextStyle(
                        color: Color(0xFF73818A),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.hasLocation
                          ? '${status.latitude!.toStringAsFixed(6)}, '
                                '${status.longitude!.toStringAsFixed(6)}'
                          : 'Unavailable',
                      style: const TextStyle(
                        color: Color(0xFF263943),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status.locationUpdatedAt case final updatedAt?) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Updated ${_formatTimestamp(updatedAt)}',
                        style: const TextStyle(
                          color: Color(0xFF73818A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status.gpsStatus != TouristGpsStatus.active &&
                  !statusService.locationTrackingEnabled) ...[
                const SizedBox(height: 12),
                _InlineNotice(
                  message: 'Location tracking is OFF in Settings.',
                  icon: Icons.info_outline_rounded,
                  color: const Color(0xFF697980),
                ),
              ] else if (status.gpsStatus != TouristGpsStatus.active) ...[
                const SizedBox(height: 12),
                _InlineNotice(
                  message: gpsMessage,
                  icon: Icons.location_off_outlined,
                  color: status.gpsStatus == TouristGpsStatus.retrying
                      ? const Color(0xFFAE7411)
                      : const Color(0xFFB5473C),
                ),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    if (status.gpsStatus !=
                        TouristGpsStatus.permissionDeniedForever)
                      OutlinedButton.icon(
                        onPressed: _retryingManually ? null : _retryGps,
                        icon: _retryingManually
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.gps_fixed),
                        label: const Text('Retry GPS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFFB7D8D2)),
                          minimumSize: const Size(44, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    if (status.gpsStatus == TouristGpsStatus.disabled)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openLocationSettings(appSettings: false),
                        icon: const Icon(Icons.settings),
                        label: const Text('Location settings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFFB7D8D2)),
                          minimumSize: const Size(44, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    if (status.gpsStatus ==
                        TouristGpsStatus.permissionDeniedForever)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openLocationSettings(appSettings: true),
                        icon: const Icon(Icons.settings),
                        label: const Text('App settings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFFB7D8D2)),
                          minimumSize: const Size(44, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                  ],
                ),
                if (status.gpsStatus ==
                        TouristGpsStatus.permissionDeniedForever &&
                    status.hasLocation)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Showing the last known location above.',
                      style: TextStyle(color: Color(0xFF697980), fontSize: 11),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _gpsMessage(TouristGpsStatus status) => switch (status) {
    TouristGpsStatus.active => '',
    TouristGpsStatus.disabled =>
      'Location services are turned off. Please enable location to continue.',
    TouristGpsStatus.permissionDenied =>
      'Location permission is required to provide safety tracking.',
    TouristGpsStatus.permissionDeniedForever =>
      'Location permission is disabled. Please enable it in your device settings.',
    TouristGpsStatus.unavailable =>
      'Unable to obtain your current location. Please try again.',
    TouristGpsStatus.retrying => 'GPS is reconnecting. Please wait...',
  };

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute:$second';
  }
}

class _StatusValue extends StatelessWidget {
  const _StatusValue({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBF0EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF7A8A90)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF73818A),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
