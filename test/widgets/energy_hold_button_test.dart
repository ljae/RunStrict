import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner/widgets/energy_hold_button.dart';

void main() {
  testWidgets('EnergyHoldButton triggers onComplete once and locks',
      (WidgetTester tester) async {
    int callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EnergyHoldButton(
              icon: Icons.play_arrow,
              baseColor: Colors.grey,
              fillColor: Colors.blue,
              iconColor: Colors.white,
              onComplete: () {
                callCount++;
              },
              duration: const Duration(milliseconds: 100), // Fast for test
            ),
          ),
        ),
      ),
    );

    // 1. Press and hold to trigger completion
    // Manual gesture control
    final gesture = await tester.startGesture(tester.getCenter(find.byType(EnergyHoldButton)));
    await tester.pump(); 
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100)); // Should be complete now (total > 100ms)
    
    expect(callCount, 1, reason: 'onComplete should be called once after hold');

    // 2. Try to trigger it again
    // Release
    await gesture.up();
    await tester.pumpAndSettle();

    // Tap/Hold again
    await tester.startGesture(tester.getCenter(find.byType(EnergyHoldButton)));
    await tester.pump(const Duration(milliseconds: 200));
    
    expect(callCount, 1, reason: 'Subsequent interactions should be ignored after completion');
  });
}
