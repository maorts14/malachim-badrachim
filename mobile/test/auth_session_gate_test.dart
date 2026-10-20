import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/screens/event_tab_screen.dart';
import 'package:rescue_app/widgets/auth_session_gate.dart';

void main() {
  testWidgets('loads Events only after session restoration succeeds',
      (tester) async {
    final restoration = Completer<void>();
    var authenticated = false;
    var eventsRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthSessionGate(
          sessionRestoration: restoration.future,
          isAuthenticated: () => authenticated,
          loadingChild: const Scaffold(body: Text('Restoring session')),
          unauthenticatedChild: const Scaffold(body: Text('Sign in')),
          authenticatedChild: Scaffold(
            body: EventTabScreen(
              loadAlerts: () async {
                eventsRequests += 1;
                return [];
              },
            ),
          ),
        ),
      ),
    );

    expect(eventsRequests, 0);
    expect(find.text('Restoring session'), findsOneWidget);

    authenticated = true;
    restoration.complete();
    await tester.pump();
    await tester.pump();

    expect(eventsRequests, 1);
  });

  testWidgets('does not load Events when session restoration fails',
      (tester) async {
    final restoration = Completer<void>();
    var eventsRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthSessionGate(
          sessionRestoration: restoration.future,
          isAuthenticated: () => false,
          loadingChild: const Scaffold(body: Text('Restoring session')),
          unauthenticatedChild: const Scaffold(body: Text('Sign in')),
          authenticatedChild: Scaffold(
            body: EventTabScreen(
              loadAlerts: () async {
                eventsRequests += 1;
                return [];
              },
            ),
          ),
        ),
      ),
    );

    restoration.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Sign in'), findsOneWidget);
    expect(eventsRequests, 0);
  });
}
