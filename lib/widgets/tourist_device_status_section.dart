import 'package:flutter/material.dart';

import '../models/tourist_device_status_model.dart';
import '../services/safe_zone_status_service.dart';
import '../services/tourist_device_status_service.dart';
import '../utils/app_error_message.dart';

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
  late Stream<TouristDeviceStatusModel> _deviceStatusStream;
  late final Stream<TouristSafetySnapshot> _gpsStatusStream;
  late final SafeZoneStatusService _safetyStatusService;

  @override
  void initState() {
    super.initState();
    _safetyStatusService = SafeZoneStatusService();
    _deviceStatusStream = _createDeviceStatusStream();
    _gpsStatusStream =
        widget.gpsStatusStream ?? _safetyStatusService.statusStream;
  }

  Stream<TouristDeviceStatusModel> _createDeviceStatusStream() =>
      widget.deviceStatusStream ??
      TouristDeviceStatusService().watchCurrentTouristDeviceStatus();

  Future<void> _retryDeviceStatus() async {
    setState(() => _deviceStatusStream = _createDeviceStatusStream());
  }

  @override
  Widget build(BuildContext context) {
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
                  Icons.devices_other_outlined,
                  color: Color(0xFF0F766E),
                  size: 19,
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Tourist Device Status',
                  softWrap: true,
                  style: TextStyle(
                    color: Color(0xFF172B35),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
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
                AppErrorMessage.log(
                  deviceSnapshot.error!,
                  deviceSnapshot.stackTrace ?? StackTrace.current,
                  context: 'Loading tourist device status',
                );
              }
              final device = deviceSnapshot.data ??
                  const TouristDeviceStatusModel();

              return StreamBuilder<TouristSafetySnapshot>(
                stream: _gpsStatusStream,
                initialData: _safetyStatusService.snapshot,
                builder: (context, gpsSnapshot) {
                  final gpsStatus =
                      gpsSnapshot.data?.gpsStatus ??
                      TouristGpsStatus.unavailable;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 3 : 2;
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
                          if (deviceSnapshot.hasError)
                            SizedBox(
                              width: constraints.maxWidth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7F5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFF3D6D1),
                                    ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          AppErrorMessage.from(
                                            deviceSnapshot.error!,
                                            fallback:
                                                'Unable to load device status.',
                                          ),
                                          style: const TextStyle(
                                            color: Color(0xFF8F352D),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _retryDeviceStatus,
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF0F766E),
                                        ),
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
    TouristGpsStatus.permissionDeniedForever =>
      'PERMISSION DENIED - SETTINGS REQUIRED',
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF73818A),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == 'ACTIVE'
                  ? const Color(0xFF16805D)
                  : value == 'Unavailable'
                  ? const Color(0xFF7A8A90)
                  : const Color(0xFF263943),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
