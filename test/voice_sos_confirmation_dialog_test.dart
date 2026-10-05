import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/widgets/voice_sos_confirmation_dialog.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    ValueChanged<bool?> onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const VoiceSosConfirmationDialog(),
                ).then(onResult);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts at 10 and CANCEL prevents SOS and stops the timer', (
    tester,
  ) async {
    bool? result;
    await openDialog(tester, (value) => result = value);

    expect(find.text('Voice SOS Detected'), findsOneWidget);
    expect(
      find.text('Emergency assistance will be requested automatically.'),
      findsOneWidget,
    );
    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.pump(const Duration(seconds: 11));
    expect(result, isFalse);
  });

  testWidgets('SEND SOS NOW bypasses the remaining countdown', (tester) async {
    bool? result;
    await openDialog(tester, (value) => result = value);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('7'), findsOneWidget);

    await tester.tap(find.text('SEND SOS NOW'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.pump(const Duration(seconds: 10));
    expect(result, isTrue);
  });

  testWidgets('automatically proceeds when the 10-second countdown expires', (
    tester,
  ) async {
    bool? result;
    await openDialog(tester, (value) => result = value);

    for (var seconds = 9; seconds >= 0; seconds--) {
      await tester.pump(const Duration(seconds: 1));
      if (seconds > 0) expect(find.text('$seconds'), findsOneWidget);
    }

    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(VoiceSosConfirmationDialog), findsNothing);
  });
}
