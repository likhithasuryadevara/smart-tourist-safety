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
          TouristGpsStatus.unavailable => 'UNAVAILABLE',
          TouristGpsStatus.retrying => 'RETRYING',
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
            valueColor: status.gpsStatus == TouristGpsStatus.active
                ? const Color(0xFF2563EB)
                : const Color(0xFFB45309),
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
            valueColor: Color(0xFFE11D48),
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
        color: const Color(0xFF111C31),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF263752)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 22),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
