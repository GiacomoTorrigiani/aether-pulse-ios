import 'package:flutter_test/flutter_test.dart';
import 'package:aether_pulse/main.dart';

void main() {
  testWidgets('AetherPulse app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AetherPulseApp());
    expect(find.text('AETHER RESONANCE'), findsOneWidget);
    expect(find.text('Neural Entrainment'), findsOneWidget);
  });
}
