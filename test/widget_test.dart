import 'package:flutter_test/flutter_test.dart';

import 'package:dbml_erd_studio/core/constants/sample.dart';
import 'package:dbml_erd_studio/presentation/app/erd_app.dart';

void main() {
  testWidgets('renders the ERD studio application',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ErdApp());
    await tester.pump();

    expect(find.byType(ErdApp), findsOneWidget);
  });

  test('starts with one header color for every sample table', () {
    final colors = RegExp(
      r'^Table\s+[\w.]+\s+\[headercolor:\s*(#[0-9A-Fa-f]{6})\]',
      multiLine: true,
    ).allMatches(kSample).map((match) => match.group(1)).toSet();

    expect(colors, {'#3B82F6'});
    expect(colors.length, 1);
  });
}
