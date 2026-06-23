import 'package:flutter_test/flutter_test.dart';
import 'package:kokonuts_manager/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KokonutsManagerApp());
    expect(find.byType(KokonutsManagerApp), findsOneWidget);
  });
}
