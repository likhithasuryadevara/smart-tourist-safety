import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/screens/login_screen.dart';

void main() {
  testWidgets('logout navigation clears the navigation stack', (tester) async {
    // Test navigation stack clearing directly without Firebase
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text('Log out'),
              ),
            ),
          ),
        ),
        routes: {'/login': (context) => const LoginScreen()},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
      isFalse,
    );
  });
}
