import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_tourist_safety/screens/login_screen.dart';
import 'package:smart_tourist_safety/services/safe_zone_status_service.dart';

void main() {
  testWidgets('LoginScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: const LoginScreen()));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });

  test('SafeZoneStatusService broadcasts zone state changes', () async {
    final service = SafeZoneStatusService();
    final updates = <bool>[];

    final subscription = service.safeZoneStream.listen(updates.add);
    service.updateStatus(false);
    await Future<void>.delayed(Duration.zero);

    expect(service.isInsideSafeZone, isFalse);
    expect(updates, [false]);

    await subscription.cancel();
  });
}
