import 'dart:math';
import 'package:flutter/material.dart';
import 'dbml_service.dart';
import 'layout.dart';
import 'models.dart';

class ErdController extends ChangeNotifier {
  ErdController({DbmlBackend? backend}) : backend = backend ?? DbmlParserPackageBackend();

  final DbmlBackend backend;
  SchemaModel schema = const SchemaModel([], []);
  final Map<String, TableModel> byName = {};
  final Map<String, Offset> pos = {};
  final Map<String, Size> sizes = {};
  List<DbmlIssue> issues = const [];

  // selection / marquee (world coordinates)
  final Set<String> selection = {};
  Rect? marquee;

  // view: screen = world * scale + pan
  double scale = 1;
  Offset pan = Offset.zero;
  Size viewport = Size.zero;
  bool needsFit = true;

  // ---------------------------------------------------------------- parsing
  void update(String source) {
    try {
      final s = backend.parse(source);
      schema = s;
      if (issues.isNotEmpty) issues = const [];
      byName
        ..clear()
        ..addAll({for (final t in s.tables) t.name: t});
      sizes
        ..clear()
        ..addAll({for (final t in s.tables) t.name: measureTable(t)});
      pos.removeWhere((k, _) => !sizes.containsKey(k));
      selection.removeWhere((n) => !sizes.containsKey(n));
      if (pos.isEmpty) {
        pos.addAll(autoLayout(s, sizes));
        needsFit = true;
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
      if (needsFit && !viewport.isEmpty) {
        fit();
        return;
      }
    } on DbmlParseException catch (e) {
      issues = e.issues; // keep the last valid diagram on screen
    } catch (e) {
      issues = [DbmlIssue(0, 0, '$e')];
    }
    notifyListeners();
  }

  void relayout() {
    pos
      ..clear()
      ..addAll(autoLayout(schema, sizes));
    fit();
  }

  // ------------------------------------------------------------------ geometry
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

  Rect? tableRect(String n) {
    final o = pos[n], s = sizes[n];
    return (o == null || s == null) ? null : (o & s);
  }

  String? hit(Offset world) {
    for (final t in schema.tables.reversed) {
      final r = tableRect(t.name);
      if (r != null && r.contains(world)) return t.name;
    }
    return null;
  }

  Size exportSize(double scale) {
    final b = bounds().inflate(56);
    if (b.isEmpty) return Size.zero;
    final s = min(scale, 16000 / max(b.width, b.height));
    return Size((b.width * s).ceilToDouble(), (b.height * s).ceilToDouble());
  }

  // ---------------------------------------------------------------------- view
  Offset screenToWorld(Offset p) => (p - pan) / scale;

  Rect visibleWorld(Size size) =>
      Rect.fromLTWH(-pan.dx / scale, -pan.dy / scale, size.width / scale, size.height / scale);

  /// Fit everything in the viewport, centered.
  void fit() {
    final v = viewport;
    if (v.isEmpty) return;
    final b = bounds();
    if (b.isEmpty) {
      scale = 1;
      pan = Offset(v.width / 2, v.height / 2);
    } else {
      final bb = b.inflate(56);
      scale = min(v.width / bb.width, v.height / bb.height).clamp(0.1, 1.0).toDouble();
      pan = Offset(v.width / 2, v.height / 2) - bb.center * scale;
    }
    needsFit = false;
    notifyListeners();
  }

  void panBy(Offset d) {
    pan += d;
    notifyListeners();
  }

  void zoomAt(Offset screenPoint, double factor) {
    final ns = (scale * factor).clamp(0.1, 4.0).toDouble();
    final f = ns / scale;
    pan = screenPoint - (screenPoint - pan) * f;
    scale = ns;
    notifyListeners();
  }

  // ----------------------------------------------------------------- selection
  void setSelection(Set<String> s) {
    selection
      ..clear()
      ..addAll(s);
    notifyListeners();
  }

  void toggle(String n) {
    if (!selection.remove(n)) selection.add(n);
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
      ..addAll(schema.tables.map((t) => t.name));
    notifyListeners();
  }

  /// Rubber-band selection: [base] stays selected, plus anything the rect touches.
  void setMarquee(Rect? r, Set<String> base) {
    marquee = r;
    if (r != null) {
      selection
        ..clear()
        ..addAll(base);
      for (final t in schema.tables) {
        final tr = tableRect(t.name);
        if (tr != null && tr.overlaps(r)) selection.add(t.name);
      }
    }
    notifyListeners();
  }

  /// Moves every selected table by [d] (world units).
  void moveSelected(Offset d) {
    for (final n in selection) {
      final o = pos[n];
      if (o != null) pos[n] = o + d;
    }
    notifyListeners();
  }
}
