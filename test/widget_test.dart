import 'package:flutter_test/flutter_test.dart';
import 'package:dibi_family/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DibiFamilyApp());
    expect(find.byType(DibiFamilyApp), findsOneWidget);
  });
}
