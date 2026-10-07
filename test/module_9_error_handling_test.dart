import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/utils/app_error_message.dart';
import 'package:smart_tourist_safety/widgets/app_state_widgets.dart';

void main() {
  group('AppErrorMessage', () {
    test('maps Firebase permission and service errors to friendly text', () {
      expect(
        AppErrorMessage.from(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        'Access denied. Please sign in again or contact support.',
      );
      expect(
        AppErrorMessage.from(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        'Service is temporarily unavailable. Please try again.',
      );
    });

    test('maps authentication and unknown failures without raw details', () {
      expect(
        AppErrorMessage.from(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        contains('Check your internet connection'),
      );
      expect(
        AppErrorMessage.from(
          StateError('cloud_firestore/permission-denied: private details'),
        ),
        'Access denied. Please sign in again or contact support.',
      );
      expect(
        AppErrorMessage.from(Exception('private backend response')),
        'Something went wrong. Please try again.',
      );
    });
  });

  testWidgets('loading and empty states provide explicit non-error UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppLoadingState(message: 'Loading records...'),
              Expanded(child: AppEmptyState(message: 'No records yet.')),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading records...'), findsOneWidget);
    expect(find.text('No records yet.'), findsOneWidget);
    expect(find.textContaining('error'), findsNothing);
  });

  testWidgets(
    'retry disables itself and shows loading until the request ends',
    (tester) async {
      final completion = Completer<void>();
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              message: 'Unable to load records.',
              onRetry: () {
                attempts++;
                return completion.future;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(attempts, 1);
      expect(find.text('Retrying...'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      completion.complete();
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(attempts, 1);
    },
  );
}
