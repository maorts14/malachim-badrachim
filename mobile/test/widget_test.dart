import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/models/alert_message.dart';
import 'package:rescue_app/screens/event_detail_screen.dart';
import 'package:rescue_app/widgets/event_list.dart';

void main() {
  testWidgets('renders an empty active-event state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: EventsList(events: [], onSelected: _ignoreEvent),
        ),
      ),
    );

    expect(find.text('הכל'), findsOneWidget);
    expect(find.text('דחוף'), findsOneWidget);
    expect(find.text('לא שובץ'), findsOneWidget);
    expect(find.text('בטיפול'), findsOneWidget);
    expect(find.text('טופל'), findsOneWidget);
    expect(find.text('אין אירועים להצגה כרגע'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the selected active event callback',
      (WidgetTester tester) async {
    var selectedId = -1;
    final event = AlertMessage(
      id: 2841,
      title: 'תאונת דרכים',
      description: 'פצוע קל',
      latitude: 32.1,
      longitude: 34.8,
      status: 'DISPATCHED',
      priority: 'HIGH',
      location: 'כביש 6',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: EventsList(
            events: [event],
            onSelected: (selected) => selectedId = selected.id,
          ),
        ),
      ),
    );

    await tester.tap(find.text('תאונת דרכים'));
    expect(selectedId, event.id);
  });

  testWidgets('renders a responsive event detail screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = AlertMessage(
      id: 2841,
      title: 'תאונת דרכים — פצוע קל',
      description: 'נדרשת בדיקה ראשונית של המצב בשטח.',
      latitude: 32.0853,
      longitude: 34.7818,
      status: 'OPEN',
      priority: 'HIGH',
      location: 'שדרות רוטשילד, תל אביב',
      createdAt: DateTime(2026, 10, 18, 10, 30),
      updatedAt: DateTime(2026, 10, 18, 10, 35),
    );

    await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
    await tester.pumpAndSettle();

    expect(find.text('אירוע #2841'), findsOneWidget);
    expect(find.text('אני מגיע/ה'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreEvent(AlertMessage _) {}
