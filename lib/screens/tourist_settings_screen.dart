import 'package:flutter/material.dart';

import '../models/tourist_settings_model.dart';
import '../services/safe_zone_status_service.dart';
import '../services/tourist_settings_service.dart';

class TouristSettingsScreen extends StatefulWidget {
  const TouristSettingsScreen({super.key, this.settingsRepository});

  final TouristSettingsRepository? settingsRepository;

  @override
  State<TouristSettingsScreen> createState() => _TouristSettingsScreenState();
}

class _TouristSettingsScreenState extends State<TouristSettingsScreen>
    with WidgetsBindingObserver {
  late final TouristSettingsRepository _settingsService;
  TouristSettingsModel? _settings;
  Object? _loadError;
  bool _loading = true;
  TouristSetting? _saving;

  @override
  void initState() {
    super.initState();
    _settingsService =
        widget.settingsRepository ?? TouristSettingsService.shared;
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadSettings();
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final settings = await _settingsService.load(force: true);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
      await SafeZoneStatusService().setLocationTrackingEnabled(
        settings.effectiveLocationTracking,
      );
    } catch (error, stackTrace) {
      debugPrint('Tourist settings load failed: $error');
      debugPrint('Tourist settings load stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _reloadSettings() async {
    if (!mounted || _loading || _saving != null) return;
    try {
      final settings = await _settingsService.load(force: true);
      if (!mounted) return;
      setState(() => _settings = settings);
      await SafeZoneStatusService().setLocationTrackingEnabled(
        settings.effectiveLocationTracking,
      );
    } catch (error, stackTrace) {
      debugPrint('Tourist settings refresh failed: $error');
      debugPrint('Tourist settings refresh stack trace: $stackTrace');
      if (mounted) _showError();
    }
  }

  Future<void> _changeSetting(TouristSetting setting, bool value) async {
    final previous = _settings;
    if (previous == null || _saving != null) return;
    final optimistic = _withSetting(previous, setting, value);
    setState(() {
      _settings = optimistic;
      _saving = setting;
    });

    try {
      await _settingsService.save(setting, value);
      if (!mounted) return;
      if (setting == TouristSetting.locationSharing ||
          setting == TouristSetting.locationTracking) {
        await SafeZoneStatusService().setLocationTrackingEnabled(
          optimistic.effectiveLocationTracking,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to save tourist setting ${setting.name}: $error');
      debugPrint('Tourist setting save stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _settings = previous);
      _showError();
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  TouristSettingsModel _withSetting(
    TouristSettingsModel model,
    TouristSetting setting,
    bool value,
  ) {
    return switch (setting) {
      TouristSetting.safetyNotifications => model.copyWith(
        safetyNotifications: value,
      ),
      TouristSetting.sosNotifications => model.copyWith(
        sosNotifications: value,
      ),
      TouristSetting.adminNotifications => model.copyWith(
        adminNotifications: value,
      ),
      TouristSetting.profileVisibility => model.copyWith(
        profileVisibility: value,
      ),
      TouristSetting.locationSharing => model.copyWith(locationSharing: value),
      TouristSetting.locationTracking => model.copyWith(
        locationTracking: value,
      ),
      TouristSetting.backgroundLocation => model.copyWith(
        backgroundLocation: value,
      ),
      TouristSetting.sosConfirmation => model.copyWith(sosConfirmation: value),
      TouristSetting.emergencyContactNotification => model.copyWith(
        emergencyContactNotification: value,
      ),
    };
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to save setting. Please try again.'),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tourist Settings'),
        backgroundColor: const Color(0xFF111C31),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildLoadError()
          : _buildSettings(),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load settings.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    final settings = _settings!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 900 ? 820.0 : double.infinity;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  _SettingsSection(
                    title: 'NOTIFICATION SETTINGS',
                    icon: Icons.notifications_active_outlined,
                    children: [
                      _toggle(
                        TouristSetting.safetyNotifications,
                        'Safety Notifications',
                        'Receive Safe Zone, Danger Zone and Zone Exit notifications',
                        settings.safetyNotifications,
                      ),
                      _toggle(
                        TouristSetting.sosNotifications,
                        'SOS Notifications',
                        'Receive SOS confirmation, acknowledgement and resolution notifications',
                        settings.sosNotifications,
                      ),
                      _toggle(
                        TouristSetting.adminNotifications,
                        'Admin Notifications',
                        'Receive administrator messages where supported',
                        settings.adminNotifications,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'PRIVACY SETTINGS',
                    icon: Icons.privacy_tip_outlined,
                    children: [
                      _toggle(
                        TouristSetting.profileVisibility,
                        'Profile Visibility',
                        'Control profile visibility in authorized application features',
                        settings.profileVisibility,
                      ),
                      _toggle(
                        TouristSetting.locationSharing,
                        'Location Sharing',
                        'Allow live location to be shared with the safety system',
                        settings.locationSharing,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'LOCATION SETTINGS',
                    icon: Icons.location_on_outlined,
                    children: [
                      _toggle(
                        TouristSetting.locationTracking,
                        'Location Tracking',
                        'Enable live GPS tracking for safety monitoring',
                        settings.locationTracking,
                      ),
                      SwitchListTile.adaptive(
                        value: false,
                        onChanged: null,
                        secondary: const Icon(Icons.public),
                        title: const Text('Background Location'),
                        subtitle: const Text(
                          'Not supported: background tracking is not configured',
                        ),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'EMERGENCY PREFERENCES',
                    icon: Icons.emergency_outlined,
                    children: [
                      _toggle(
                        TouristSetting.sosConfirmation,
                        'SOS Confirmation',
                        'Keep the existing SOS countdown and cancel safeguards enabled',
                        settings.sosConfirmation,
                      ),
                      _toggle(
                        TouristSetting.emergencyContactNotification,
                        'Emergency Contact Notification',
                        'Preference saved; contact notification delivery is not available in the current backend',
                        settings.emergencyContactNotification,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _toggle(
    TouristSetting setting,
    String title,
    String subtitle,
    bool value,
  ) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: _saving == null
          ? (enabled) => _changeSetting(setting, enabled)
          : null,
      secondary: _saving == setting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      title: Text(title),
      subtitle: Text(subtitle),
      activeThumbColor: const Color(0xFF0F766E),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: const Color(0xFF0F766E)),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
