import 'package:flutter_test/flutter_test.dart';
import 'package:aether_pulse/main.dart';

void main() {
  testWidgets('Phone AI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PhoneAiApp());
    expect(find.text('Inserisci numero'), findsOneWidget);
    expect(find.text('Tastierino'), findsOneWidget);
  });
}
