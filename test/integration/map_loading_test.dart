import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:eventfinder_recess/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Critical path: Map loading, location selection, event creation, marker display', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Verify main map screen loads
    expect(find.text('Events Map'), findsOneWidget);

    // Tap add event button (assuming it exists on home screen)
    final addEventButton = find.byIcon(Icons.add_circle);
    expect(addEventButton, findsOneWidget);
    await tester.tap(addEventButton);
    await tester.pumpAndSettle();

    // Verify add event dialog opens
    expect(find.text('Add New Event'), findsOneWidget);

    // Tap location field to open location picker
    final locationField = find.widgetWithText(TextFormField, 'Location *');
    expect(locationField, findsOneWidget);
    await tester.tap(locationField);
    await tester.pumpAndSettle();

    // Verify location picker screen opens
    expect(find.text('Select Location'), findsOneWidget);

    // Tap on map to select location (simulate tap at center)
    final flutterMap = find.byType(FlutterMap);
    expect(flutterMap, findsOneWidget);
    await tester.tap(flutterMap);
    await tester.pumpAndSettle();

    // Confirm location selection
    final confirmButton = find.byIcon(Icons.check);
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    // Verify returned to add event dialog with location filled
    expect(find.text('Add New Event'), findsOneWidget);
    expect(find.textContaining('Lat:'), findsOneWidget);

    // Fill required fields
    final titleField = find.widgetWithText(TextFormField, 'Event Title *');
    await tester.enterText(titleField, 'Test Event');
    final dateField = find.widgetWithText(TextFormField, 'Date *');
    await tester.enterText(dateField, '01/01/2025');

    // Submit event
    final addButton = find.widgetWithText(ElevatedButton, 'Add Event');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Verify event added success snackbar
    expect(find.text('Event added successfully!'), findsOneWidget);

    // Verify main map screen shows new marker (basic check)
    expect(find.byIcon(Icons.location_on), findsWidgets);
  });
}
