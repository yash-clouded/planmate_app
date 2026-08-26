import 'package:flutter_test/flutter_test.dart';
import 'package:planmate/main.dart';

void main() {
  testWidgets('PlanMate app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PlanMateApp());
    expect(find.text('PlanMate'), findsOneWidget);
  });
}
