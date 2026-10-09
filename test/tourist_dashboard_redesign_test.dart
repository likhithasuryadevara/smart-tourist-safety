import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/services/safe_zone_status_service.dart';
import 'package:smart_tourist_safety/widgets/dashboard_navigation_card.dart';
import 'package:smart_tourist_safety/widgets/danger_banner.dart';
import 'package:smart_tourist_safety/widgets/emergency_panel.dart';
import 'package:smart_tourist_safety/widgets/quick_actions.dart';
import 'package:smart_tourist_safety/widgets/tourist_device_status_section.dart';
import 'package:smart_tourist_safety/widgets/tourist_safety_status.dart';
import 'package:smart_tourist_safety/widgets/tourist_top_bar.dart';
import 'package:smart_tourist_safety/widgets/welcome_card.dart';

void main() {
  testWidgets(
    'light dashboard sections fit phone, tablet, and desktop widths',
    (tester) async {
      final statusService = SafeZoneStatusService();
      statusService.updateGpsStatus(TouristGpsStatus.active);
      statusService.updateGpsStatus(TouristGpsStatus.unavailable);

      for (final width in [320.0, 360.0, 390.0, 414.0, 768.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TouristTopBar(
                      name: 'A long tourist name for responsive layout',
                      email: 'tourist@example.com',
                      onLogout: () {},
                      onProfile: () {},
                    ),
                    const SizedBox(height: 12),
                    const WelcomeCard(name: 'Tourist'),
                    const SizedBox(height: 12),
                    DangerBanner(onTap: () {}),
                    const SizedBox(height: 12),
                    const TouristSafetyStatus(),
                    const SizedBox(height: 12),
                    const TouristDeviceStatusSection(
                      deviceStatusStream: Stream.empty(),
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(height: 12),
                    QuickActions(desktop: width >= 900, onAction: (_) {}),
                    const SizedBox(height: 12),
                    DashboardNavigationCard(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'View your latest safety alerts',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    EmergencyPanel(
                      onAction: _ignoreAction,
                      voiceListening: false,
                      voiceStatus: 'Voice SOS is waiting for speech.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width $width');
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('welcome card appears before the main safety sections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const WelcomeCard(name: 'Tourist'),
                DangerBanner(onTap: () {}),
                const TouristSafetyStatus(),
                const TouristDeviceStatusSection(
                  deviceStatusStream: Stream.empty(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final welcomeTop = tester.getTopLeft(find.text('Welcome back')).dy;
    final bannerTop = tester.getTopLeft(find.byType(DangerBanner)).dy;
    final safetyTop = tester.getTopLeft(find.text('Tourist Safety Status')).dy;
    final deviceTop = tester.getTopLeft(find.text('Tourist Device Status')).dy;

    expect(welcomeTop, lessThan(bannerTop));
    expect(bannerTop, lessThan(safetyTop));
    expect(safetyTop, lessThan(deviceTop));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'dashboard keeps one of each required section and preserves action callbacks',
    (tester) async {
      final actions = <String>[];
      final navigationTaps = <String>[];
      var sosTaps = 0;
      await tester.binding.setSurfaceSize(const Size(390, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const WelcomeCard(name: 'Tourist'),
                    DangerBanner(onTap: () {}),
                    const TouristSafetyStatus(),
                    const TouristDeviceStatusSection(
                      deviceStatusStream: Stream.empty(),
                    ),
                    QuickActions(desktop: false, onAction: actions.add),
                    DashboardNavigationCard(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'View your latest safety alerts',
                      onTap: () => navigationTaps.add('Notifications'),
                    ),
                    DashboardNavigationCard(
                      icon: Icons.history_rounded,
                      title: 'Safety History',
                      subtitle: 'Review your safety events',
                      onTap: () => navigationTaps.add('Safety History'),
                    ),
                    DashboardNavigationCard(
                      icon: Icons.sos_rounded,
                      title: 'SOS History',
                      subtitle: 'View emergency incidents',
                      onTap: () => navigationTaps.add('SOS History'),
                    ),
                    DashboardNavigationCard(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Manage your safety preferences',
                      onTap: () => navigationTaps.add('Settings'),
                    ),
                    EmergencyPanel(
                      onAction: actions.add,
                      voiceListening: false,
                      voiceStatus: 'Voice SOS is waiting for speech.',
                    ),
                  ],
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => sosTaps++,
              backgroundColor: Colors.red,
              child: const Icon(Icons.sos, size: 32),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Tourist Safety Status'), findsOneWidget);
      expect(find.text('Tourist Device Status'), findsOneWidget);
      expect(find.text('Safety Status'), findsNothing);
      expect(find.text('Live Location'), findsNothing);
      expect(find.text('Safe Zone'), findsOneWidget);
      expect(find.text('Emergency'), findsNothing);
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('Hospital'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Safety History'), findsOneWidget);
      expect(find.text('SOS History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Emergency Assistance'), findsOneWidget);
      expect(find.text('SEND SOS'), findsOneWidget);
      expect(find.text('CALL POLICE'), findsOneWidget);
      expect(find.text('FIND HOSPITAL'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
      }

      await tapVisible(find.text('Police'));
      await tapVisible(find.text('Hospital'));
      await tapVisible(find.text('SEND SOS'));
      await tapVisible(find.text('CALL POLICE'));
      await tapVisible(find.text('FIND HOSPITAL'));
      expect(actions, [
        'Police',
        'Hospital',
        'SOS Emergency',
        'Police',
        'Hospital',
      ]);

      await tapVisible(find.text('Notifications'));
      await tapVisible(find.text('Safety History'));
      await tapVisible(find.text('SOS History'));
      await tapVisible(find.text('Settings'));
      expect(navigationTaps, [
        'Notifications',
        'Safety History',
        'SOS History',
        'Settings',
      ]);

      await tester.tap(find.byType(FloatingActionButton));
      expect(sosTaps, 1);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'emergency assistance content stays visible at responsive widths',
    (tester) async {
      const widths = [320.0, 360.0, 390.0, 414.0, 768.0, 900.0, 1024.0, 1440.0];
      const visibleContent = [
        'Emergency Assistance',
        'Get immediate help during an emergency.',
        'VOICE SOS',
        'Voice SOS: Listening...',
        'SEND SOS',
        'CALL POLICE',
        'FIND HOSPITAL',
        'Your live location can help emergency services locate you.',
      ];

      for (final width in widths) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final panel = EmergencyPanel(
                      onAction: _ignoreAction,
                      voiceListening: true,
                      voiceStatus: 'Voice SOS: Listening...',
                    );

                    if (constraints.maxWidth >= 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: SizedBox(height: 240)),
                          const SizedBox(width: 14),
                          Expanded(flex: 3, child: panel),
                        ],
                      );
                    }
                    return panel;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        for (final text in visibleContent) {
          final finder = find.text(text);
          expect(finder, findsOneWidget, reason: 'width $width: $text');
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0), reason: 'width $width');
          expect(rect.right, lessThanOrEqualTo(width), reason: 'width $width');
          expect(rect.top, greaterThanOrEqualTo(0), reason: 'width $width');
          expect(rect.bottom, lessThanOrEqualTo(900), reason: 'width $width');
        }
        for (final label in ['SEND SOS', 'CALL POLICE', 'FIND HOSPITAL']) {
          final button = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (widget) => widget is FilledButton || widget is OutlinedButton,
            ),
          );
          expect(button, findsOneWidget, reason: 'width $width: $label');
          expect(
            tester.getSize(button).height,
            greaterThanOrEqualTo(48),
            reason: 'width $width: $label touch target',
          );
        }
        expect(find.byIcon(Icons.sos_rounded), findsOneWidget);
        expect(find.byIcon(Icons.local_police_rounded), findsOneWidget);
        expect(find.byIcon(Icons.local_hospital_rounded), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'width $width');
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('quick action and emergency taps keep forwarding action names', (
    tester,
  ) async {
    final actions = <String>[];
    await tester.binding.setSurfaceSize(const Size(360, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                QuickActions(desktop: false, onAction: actions.add),
                EmergencyPanel(
                  onAction: actions.add,
                  voiceListening: true,
                  voiceStatus: 'Voice SOS: Listening...',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Safe Zone'));
    await tester.tap(find.text('SEND SOS'));
    await tester.tap(find.text('CALL POLICE'));
    await tester.tap(find.text('FIND HOSPITAL'));
    expect(actions, ['Safe Zone', 'SOS Emergency', 'Police', 'Hospital']);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}

void _ignoreAction(String _) {}
