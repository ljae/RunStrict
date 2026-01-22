// Basic widget test for 달리기로 하나되는 app
import 'package:flutter_test/flutter_test.dart';
import 'package:runner/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const RunnerApp());

    // Verify that the main home screen title is present
    expect(find.textContaining('달리기로 하나되는'), findsOneWidget);
  });
}
