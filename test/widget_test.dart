import 'package:flutter_test/flutter_test.dart';
import 'package:aether_pulse/main.dart';

void main() {
  testWidgets('Synapse Life OS smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SynapseLifeOSApp());
    expect(find.text('SYNAPTIC MASTERY'), findsOneWidget);
    expect(find.text('SPAWN ORB'), findsOneWidget);
  });
}
