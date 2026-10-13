import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dbml_erd_studio/core/constants/sample.dart';
import 'package:dbml_erd_studio/presentation/app/erd_app.dart';

void main() {
  testWidgets('renders the ERD studio application',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ErdApp());
    await tester.pump();

    expect(find.byType(ErdApp), findsOneWidget);
  });

  testWidgets('ignores unsupported keys and handles escape safely',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ErdApp());
    await tester.pump();

    final editor = find.byType(TextField).first;
    await tester.showKeyboard(editor);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.f12);
    await tester.pump();

    expect(tester.takeException(), isNull);
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
