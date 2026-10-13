part of 'erd_controller.dart';

mixin _ErdControllerParsing on _ErdControllerBase {
  void update(String source) {
    try {
      final parsedSchema = backend.parse(source);
      schema = parsedSchema;
      if (issues.isNotEmpty) issues = const [];
      byName
        ..clear()
        ..addAll({for (final table in parsedSchema.tables) table.name: table});

      sizes
        ..clear()
        ..addAll({
          for (final table in parsedSchema.tables) table.name: measureTable(table),
        });

      pos.removeWhere((key, _) => !sizes.containsKey(key));
      selection.removeWhere((name) => !sizes.containsKey(name));

      if (pos.isEmpty) {
        pos.addAll(autoLayout(parsedSchema, sizes));
        needsFit = true;
      } else {
        final currentBounds = bounds();
        var x = currentBounds.left;
        final y = currentBounds.bottom + 60;
        for (final table in parsedSchema.tables) {
          if (pos.containsKey(table.name)) continue;
          pos[table.name] = Offset(x, y);
          x += sizes[table.name]!.width + 60;
        }
      }
      if (needsFit && !viewport.isEmpty) {
        fit();
        return;
      }
    } on DbmlParseException catch (error) {
      issues = error.issues;
    } catch (error) {
      issues = [DbmlIssue(0, 0, '$error')];
    }
    notifyListeners();
  }

  void relayout() {
    pos
      ..clear()
      ..addAll(autoLayout(schema, sizes));
    fit();
  }
}
