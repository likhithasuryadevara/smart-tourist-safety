import 'package:flutter/material.dart';

import '../services/safe_zone_status_service.dart';

class StatsSection extends StatelessWidget {
  final bool desktop;

  const StatsSection({super.key, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final statusService = SafeZoneStatusService();

    return StreamBuilder<TouristSafetySnapshot>(
      stream: statusService.statusStream,
      initialData: statusService.snapshot,
      builder: (context, snapshot) {
        final status = snapshot.data ?? statusService.snapshot;
        final safetyColor = switch (status.zoneStatus) {
          TouristZoneStatus.safe => const Color(0xFF16A34A),
          TouristZoneStatus.danger ||
          TouristZoneStatus.outsideSafeZone => const Color(0xFFEF4444),
          TouristZoneStatus.unknown => const Color(0xFF64748B),
        };
        final zoneLabel = switch (status.zoneStatus) {
          TouristZoneStatus.safe => 'INSIDE SAFE ZONE',
          TouristZoneStatus.danger => 'DANGER ZONE',
          TouristZoneStatus.outsideSafeZone => 'OUTSIDE SAFE ZONE',
          TouristZoneStatus.unknown => 'UNKNOWN',
        };
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
          TouristGpsStatus.active => const Color(0xFF16805D),
          TouristGpsStatus.retrying => const Color(0xFFAE7411),
          TouristGpsStatus.disabled ||
          TouristGpsStatus.permissionDenied ||
          TouristGpsStatus.permissionDeniedForever => const Color(0xFF697980),
          TouristGpsStatus.unavailable => const Color(0xFF697980),
        };

        final cards = [
          _StatCard(
            icon: Icons.shield_rounded,
            title: 'Safety Status',
            value: status.safetyIndicator,
            valueColor: safetyColor,
          ),

          _StatCard(
            icon: Icons.location_on_rounded,
            title: 'Live Location',
            value: gpsLabel,
            valueColor: gpsColor,
          ),

          _StatCard(
            icon: Icons.gps_fixed_rounded,
            title: 'Safe Zone',
            value: zoneLabel,
            valueColor: safetyColor,
          ),

          const _StatCard(
            icon: Icons.emergency_rounded,
            title: 'Emergency',
            value: 'READY',
            valueColor: Color(0xFF16805D),
          ),
        ];

        if (desktop) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EBEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F766E),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: valueColor, size: 19),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF73818A),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
