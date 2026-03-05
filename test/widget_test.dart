import 'package:flutter_test/flutter_test.dart';
import 'package:tally_calendar/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const TallyCalendarApp());
    // Just verify it doesn't crash on startup
    expect(find.textContaining('Tally'), findsWidgets);
  });
}
