import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dbml_erd_studio/core/constants/sample.dart';
import 'package:dbml_erd_studio/presentation/app/erd_app.dart';
import 'package:dbml_erd_studio/presentation/widgets/code_editor.dart';

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

  testWidgets('replaces all matching editor text', (WidgetTester tester) async {
    await tester.pumpWidget(const ErdApp());
    await tester.pump();

    await tester.tap(
      find.byTooltip('Search and replace (Ctrl/Cmd+F)'),
      warnIfMissed: false,
    );
    await tester.pump();

    final findField = find.byType(TextField).at(1);
    await tester.enterText(findField, 'users');
    expect(
      tester.widget<TextField>(findField).focusNode!.hasFocus,
      isTrue,
    );
    await tester.tap(find.byTooltip('Toggle replace'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), 'accounts');
    await tester.tap(find.text('All'));
    await tester.pump();

    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('dbml-editor-field')),
    );
    expect(editor.controller!.text, contains('accounts'));
    expect(editor.controller!.text, isNot(contains('Table users')));
  });

  testWidgets('keeps search focus and cycles through matches',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ErdApp());
    await tester.pump();

    await tester.tap(
      find.byTooltip('Search and replace (Ctrl/Cmd+F)'),
      warnIfMissed: false,
    );
    await tester.pump();
    final search = find.byKey(const ValueKey('editor-search-field'));
    await tester.enterText(search, 'id');
    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('dbml-editor-field')),
    );
    final first = editor.controller!.selection.start;

    await tester.pump();
    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
        )
        .onPressed!
        .call();
    await tester.pump();
    final second = editor.controller!.selection.start;

    expect(first, isNot(second));
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
    expect(find.text('table'), findsNothing);
  });

  testWidgets('highlights search matches in the editor',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ErdApp());
    await tester.pump();

    await tester.tap(
      find.byTooltip('Search and replace (Ctrl/Cmd+F)'),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('editor-search-field')),
      'users',
    );
    await tester.pump();

    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('dbml-editor-field')),
    );
    final controller = editor.controller! as DbmlTextController;
    final span = controller.buildTextSpan(
      context: tester.element(find.byKey(const ValueKey('dbml-editor-field'))),
      style: const TextStyle(),
      withComposing: false,
    );
    final highlighted = span.children
        ?.whereType<TextSpan>()
        .any((child) => child.style?.backgroundColor != null);

    expect(highlighted, isTrue);
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
