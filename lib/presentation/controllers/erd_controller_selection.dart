part of 'erd_controller.dart';

mixin _ErdControllerSelection on _ErdControllerBase {
  void setSelection(Set<String> names) {
    selection
      ..clear()
      ..addAll(names);
    notifyListeners();
  }

  void toggle(String name) {
    if (!selection.remove(name)) selection.add(name);
    notifyListeners();
  }

  void clearSelection() {
    if (selection.isEmpty && marquee == null) return;
    selection.clear();
    marquee = null;
    notifyListeners();
  }

  void selectAll() {
    selection
      ..clear()
      ..addAll(schema.tables.map((table) => table.name));
    notifyListeners();
  }

  void setMarquee(Rect? rect, Set<String> base) {
    marquee = rect;
    if (rect != null) {
      selection
        ..clear()
        ..addAll(base);
      for (final table in schema.tables) {
        final tableBounds = tableRect(table.name);
        if (tableBounds != null && tableBounds.overlaps(rect)) {
          selection.add(table.name);
        }
      }
    }
    notifyListeners();
  }

  void moveSelected(Offset delta) {
    for (final name in selection) {
      final offset = pos[name];
      if (offset != null) pos[name] = offset + delta;
    }
    notifyListeners();
  }
}
