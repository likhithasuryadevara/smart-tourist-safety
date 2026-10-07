import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/services/safe_zone_status_service.dart';
import 'package:smart_tourist_safety/widgets/dashboard_navigation_card.dart';
import 'package:smart_tourist_safety/widgets/danger_banner.dart';
import 'package:smart_tourist_safety/widgets/emergency_panel.dart';
import 'package:smart_tourist_safety/widgets/quick_actions.dart';
import 'package:smart_tourist_safety/widgets/stats_section.dart';
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
                    DangerBanner(onTap: () {}),
                    const SizedBox(height: 12),
                    const TouristSafetyStatus(),
                    const SizedBox(height: 12),
                    const TouristDeviceStatusSection(
                      deviceStatusStream: Stream.empty(),
                    ),
                    const SizedBox(height: 12),
                    const WelcomeCard(name: 'Tourist'),
                    const SizedBox(height: 12),
                    StatsSection(desktop: width >= 900),
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

  testWidgets(
    'emergency assistance content stays visible at responsive widths',
    (tester) async {
      const widths = [320.0, 360.0, 390.0, 414.0, 768.0, 900.0, 1024.0, 1440.0];
      const visibleContent = [
        'Emergency Assistance',
        'Get immediate help during an emergency.',
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
