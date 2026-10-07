import 'package:flutter/material.dart';

import '../services/safe_zone_status_service.dart';

class TouristSafetyStatus extends StatefulWidget {
  const TouristSafetyStatus({super.key});

  @override
  State<TouristSafetyStatus> createState() => _TouristSafetyStatusState();
}

class _TouristSafetyStatusState extends State<TouristSafetyStatus> {
  bool _retryingManually = false;

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
          TouristGpsStatus.unavailable => 'UNAVAILABLE',
          TouristGpsStatus.retrying => 'RETRYING',
        };
        final gpsColor = switch (status.gpsStatus) {
          TouristGpsStatus.active => const Color(0xFF15803D),
          TouristGpsStatus.retrying => const Color(0xFFB45309),
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

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.health_and_safety, color: Color(0xFF0F766E)),
                  SizedBox(width: 9),
                  Text(
                    'Tourist Safety Status',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _StatusValue(
                    title: 'GPS Status',
                    value: gpsLabel,
                    color: gpsColor,
                  ),
                  _StatusValue(
                    title: 'Current Zone',
                    value: zoneLabel,
                    color: isDanger
                        ? const Color(0xFFB91C1C)
                        : status.zoneStatus == TouristZoneStatus.safe
                        ? const Color(0xFF15803D)
                        : const Color(0xFF475569),
                  ),
                  _StatusValue(
                    title: 'Safe / Danger Indicator',
                    value: indicator,
                    color: indicatorColor,
                  ),
                  _StatusValue(
                    title: 'Distance to Safe Zone',
                    value: distanceText,
                    color: const Color(0xFF1E293B),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(
                status.hasLocation
                    ? 'Last Location: '
                        '${status.latitude!.toStringAsFixed(6)}, '
                        '${status.longitude!.toStringAsFixed(6)}'
                    : 'Last Location: Unavailable',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status.locationUpdatedAt case final updatedAt?) ...[
                const SizedBox(height: 5),
                Text(
                  'Updated: ${_formatTimestamp(updatedAt)}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
              if (status.gpsStatus != TouristGpsStatus.active) ...[
                const SizedBox(height: 12),
                if (status.gpsStatus == TouristGpsStatus.unavailable)
                  const Text(
                    'Unable to obtain current location.',
                    style: TextStyle(color: Color(0xFFB91C1C)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _retryingManually ? null : _retryGps,
                    icon: _retryingManually
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gps_fixed),
                    label: const Text('RETRY GPS'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

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
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
