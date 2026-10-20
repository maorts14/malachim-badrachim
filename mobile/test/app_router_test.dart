import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/models/alert_message.dart';
import 'package:rescue_app/presentation/router/app_router.dart';
import 'package:rescue_app/screens/event_tab_screen.dart';

void main() {
  final event = AlertMessage(
    id: 42,
    title: 'תאונת דרכים',
    description: 'נדרשת בדיקה בשטח',
    latitude: 32.0853,
    longitude: 34.7818,
    status: 'OPEN',
    priority: 'HIGH',
    location: 'תל אביב',
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );

  testWidgets('redirects an unauthenticated event URL to sign in',
      (tester) async {
    final session = ValueNotifier(false);
    var loadCalls = 0;
    final router = createAppRouter(
      session: session,
      isAuthenticated: () => session.value,
      initialLocation: AppRoutePaths.eventDetails(event.id),
      loadEvent: (_) async {
        loadCalls += 1;
        return event;
      },
    );
    addTearDown(() {
      session.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(),
        '/sign-in?next=%2Fevents%2F42');
    expect(find.text('ברוך שובך'), findsOneWidget);
    expect(loadCalls, 0);
  });

  testWidgets('loads an authorized event URL', (tester) async {
    final session = ValueNotifier(true);
    final router = createAppRouter(
      session: session,
      isAuthenticated: () => session.value,
      initialLocation: AppRoutePaths.eventDetails(event.id),
      loadEvent: (eventId) async {
        expect(eventId, event.id);
        return event;
      },
    );
    addTearDown(() {
      session.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('אירוע #42'), findsOneWidget);
    expect(find.text('תאונת דרכים'), findsOneWidget);
  });

  testWidgets('restores an event URL after sign in and redirects on expiry',
      (tester) async {
    final session = ValueNotifier(false);
    final router = createAppRouter(
      session: session,
      isAuthenticated: () => session.value,
      initialLocation: AppRoutePaths.eventDetails(event.id),
      loadEvent: (_) async => event,
    );
    addTearDown(() {
      session.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('ברוך שובך'), findsOneWidget);

    session.value = true;
    await tester.pumpAndSettle();
    expect(find.text('אירוע #42'), findsOneWidget);

    session.value = false;
    await tester.pumpAndSettle();
    expect(find.text('ברוך שובך'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.toString(),
        '/sign-in?next=%2Fevents%2F42');
  });

  testWidgets('returns to Events after backing out of an event detail',
      (tester) async {
    final session = ValueNotifier(true);
    final router = createAppRouter(
      session: session,
      isAuthenticated: () => session.value,
      homeBuilder: (_) => Scaffold(
        body: EventTabScreen(loadAlerts: () async => [event]),
      ),
      loadEvent: (_) async => event,
      initialLocation: AppRoutePaths.home,
    );
    addTearDown(() {
      session.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text(event.title));
    await tester.pumpAndSettle();
    expect(find.text('אירוע #42'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text(event.title), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutePaths.home);
  });
}
