import 'package:flutter_test/flutter_test.dart';

import 'package:dbml_erd_studio/presentation/app/erd_app.dart';

void main() {
  testWidgets('renders the ERD studio application', (WidgetTester tester) async {
    await tester.pumpWidget(const ErdApp());
    await tester.pump();

    expect(find.byType(ErdApp), findsOneWidget);
  });
}
