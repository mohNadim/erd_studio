import 'package:flutter/material.dart';
import 'dbml_service.dart';
import 'layout.dart';
import 'models.dart';

class ErdController extends ChangeNotifier {
  ErdController({DbmlBackend? backend}) : backend = backend ?? DbmlParserPackageBackend();

  final DbmlBackend backend;
  SchemaModel schema = const SchemaModel([], []);
  final Map<String, Offset> pos = {};
  final Map<String, Size> sizes = {};
  String? error;
  String? selected;

  void update(String source) {
    try {
      final s = backend.parse(source);
      schema = s;
      error = null;
      sizes
        ..clear()
        ..addAll({for (final t in s.tables) t.name: measureTable(t)});
      pos.removeWhere((k, _) => !sizes.containsKey(k));
      if (pos.isEmpty) {
        pos.addAll(autoLayout(s, sizes));
      } else {
        final b = bounds();
        var x = b.left;
        final y = b.bottom + 60;
        for (final t in s.tables) {
          if (pos.containsKey(t.name)) continue;
          pos[t.name] = Offset(x, y);
          x += sizes[t.name]!.width + 60;
        }
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void relayout() {
    pos
      ..clear()
      ..addAll(autoLayout(schema, sizes));
    notifyListeners();
  }

  Rect bounds() {
    Rect? r;
    for (final e in pos.entries) {
      final sz = sizes[e.key];
      if (sz == null) continue;
      final tr = e.value & sz;
      r = r == null ? tr : r.expandToInclude(tr);
    }
    return r ?? Rect.zero;
  }

  String? hit(Offset p) {
    for (final t in schema.tables.reversed) {
      final o = pos[t.name], s = sizes[t.name];
      if (o != null && s != null && (o & s).contains(p)) return t.name;
    }
    return null;
  }

  void select(String? n) {
    selected = n;
    notifyListeners();
  }

  void move(String name, Offset d) {
    final o = pos[name];
    if (o == null) return;
    pos[name] = Offset((o.dx + d.dx).clamp(0, 1e5), (o.dy + d.dy).clamp(0, 1e5));
    notifyListeners();
  }
}
