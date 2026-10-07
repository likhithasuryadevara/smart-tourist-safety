import 'package:flutter/material.dart';

import '../models/tourist_device_status_model.dart';
import '../services/safe_zone_status_service.dart';
import '../services/tourist_device_status_service.dart';

class TouristDeviceStatusSection extends StatefulWidget {
  const TouristDeviceStatusSection({
    super.key,
    this.deviceStatusStream,
    this.gpsStatusStream,
  });

  final Stream<TouristDeviceStatusModel>? deviceStatusStream;
  final Stream<TouristSafetySnapshot>? gpsStatusStream;

  @override
  State<TouristDeviceStatusSection> createState() =>
      _TouristDeviceStatusSectionState();
}

class _TouristDeviceStatusSectionState
    extends State<TouristDeviceStatusSection> {
  late final Stream<TouristDeviceStatusModel> _deviceStatusStream;
  late final Stream<TouristSafetySnapshot> _gpsStatusStream;
  late final SafeZoneStatusService _safetyStatusService;

  @override
  void initState() {
    super.initState();
    _safetyStatusService = SafeZoneStatusService();
    _deviceStatusStream =
        widget.deviceStatusStream ??
        TouristDeviceStatusService().watchCurrentTouristDeviceStatus();
    _gpsStatusStream =
        widget.gpsStatusStream ?? _safetyStatusService.statusStream;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111C31),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263752)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.devices_other, color: Color(0xFF2DD4BF)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'TOURIST DEVICE STATUS',
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<TouristDeviceStatusModel>(
            stream: _deviceStatusStream,
            initialData: const TouristDeviceStatusModel(),
            builder: (context, deviceSnapshot) {
              if (deviceSnapshot.hasError) {
                debugPrint(
                  'Tourist device status stream failed: '
                  '${deviceSnapshot.error}',
                );
              }
              final device = deviceSnapshot.hasError || !deviceSnapshot.hasData
                  ? const TouristDeviceStatusModel()
                  : deviceSnapshot.data!;

              return StreamBuilder<TouristSafetySnapshot>(
                stream: _gpsStatusStream,
                initialData: _safetyStatusService.snapshot,
                builder: (context, gpsSnapshot) {
                  final gpsStatus =
                      gpsSnapshot.data?.gpsStatus ??
                      TouristGpsStatus.unavailable;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760
                          ? 3
                          : constraints.maxWidth >= 480
                          ? 2
                          : 1;
                      final spacing = 12.0;
                      final itemWidth =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      final values = [
                        _DeviceStatusValue(
                          title: 'Device ID',
                          value: device.deviceId ?? 'Unavailable',
                          icon: Icons.tag,
                        ),
                        _DeviceStatusValue(
                          title: 'Device Status',
                          value:
                              device.deviceStatus?.toUpperCase() ??
                              'Unavailable',
                          icon: Icons.sensors,
                        ),
                        _DeviceStatusValue(
                          title: 'Battery',
                          value: _formatBattery(device.batteryPercent),
                          icon: Icons.battery_std,
                        ),
                        _DeviceStatusValue(
                          title: 'LoRa Signal',
                          value: device.loraSignal ?? 'Unavailable',
                          icon: Icons.cell_tower,
                        ),
                        _DeviceStatusValue(
                          title: 'GPS Status',
                          value: _gpsLabel(gpsStatus),
                          icon: Icons.gps_fixed,
                        ),
                        _DeviceStatusValue(
                          title: 'Last Communication',
                          value: _formatLastCommunication(
                            device.lastCommunication,
                          ),
                          icon: Icons.access_time,
                        ),
                      ];

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final value in values)
                            SizedBox(width: itemWidth, child: value),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _gpsLabel(TouristGpsStatus status) => switch (status) {
    TouristGpsStatus.active => 'ACTIVE',
    TouristGpsStatus.disabled => 'DISABLED',
    TouristGpsStatus.permissionDenied => 'PERMISSION DENIED',
    TouristGpsStatus.unavailable => 'UNAVAILABLE',
    TouristGpsStatus.retrying => 'RETRYING',
  };

  String _formatBattery(double? battery) {
    if (battery == null) return 'Unavailable';
    final formatted = battery == battery.roundToDouble()
        ? battery.toStringAsFixed(0)
        : battery.toStringAsFixed(1);
    return '$formatted%';
  }

  String _formatLastCommunication(DateTime? timestamp) {
    if (timestamp == null) return 'Unavailable';
    final local = timestamp.toLocal();
    final month = _months[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$month ${local.day}, $hour:$minute $period';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _DeviceStatusValue extends StatelessWidget {
  const _DeviceStatusValue({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF182640),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF263752)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
