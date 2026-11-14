import 'package:flutter_test/flutter_test.dart';
import 'package:aether_pulse/main.dart';

void main() {
  testWidgets('VoxMind Call Co-Pilot smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VoxMindApp());
    expect(find.text('DOMANDE SUGGERITE IN TEMPO REALE'), findsOneWidget);
    expect(find.text('Marco Rossi'), findsOneWidget);
  });
}
