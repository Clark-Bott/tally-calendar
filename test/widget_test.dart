import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tally_calendar/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const TallyCalendarApp());
    // Just verify it doesn't crash on startup
    expect(find.textContaining('Tally'), findsWidgets);
  });
}
