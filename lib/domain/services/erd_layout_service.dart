import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import '../entities/schema_models.dart';

class ErdMetrics {
  static const headerH = 38.0, rowH = 28.0, pad = 12.0, minW = 190.0;
}

class ErdText {
  static const title =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white);
  static TextStyle name(Color c, {bool bold = false}) => TextStyle(
      fontSize: 13, color: c, fontWeight: bold ? FontWeight.w600 : FontWeight.w400);
  static TextStyle type(Color c) =>
      TextStyle(fontSize: 12, color: c, fontFamily: 'monospace');

  static final Map<String, TextPainter> _cache = {};

  /// Cached: laying out text is the most expensive part of painting.
  static TextPainter lay(String s, TextStyle st, [double maxW = double.infinity]) {
    final key = '${st.hashCode}|${maxW.isFinite ? maxW.round() : -1}|$s';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 4000) _cache.clear();
    return _cache[key] = TextPainter(
      text: TextSpan(text: s, style: st),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
  }
}

Size measureTable(TableModel t) {
  var w = ErdText.lay(t.name, ErdText.title).width + ErdMetrics.pad * 2;
  for (final c in t.columns) {
    final n = ErdText.lay(c.name, ErdText.name(Colors.black, bold: true)).width;
    final ty = ErdText.lay(c.type, ErdText.type(Colors.black)).width;
    w = max(w, n + ty + ErdMetrics.pad * 3 + 34);
  }
  final rows = max(1, t.columns.length);
  return Size(max(ErdMetrics.minW, w),
      ErdMetrics.headerH + rows * ErdMetrics.rowH + 6);
}

/// BFS-ordered grid: connected tables end up next to each other.
Map<String, Offset> autoLayout(SchemaModel s, Map<String, Size> sizes,
    {double gapX = 150, double gapY = 100}) {
  final names = s.tables.map((t) => t.name).toList();
  final adj = {for (final n in names) n: <String>{}};
  for (final r in s.refs) {
    if (r.fromTable != r.toTable) {
      adj[r.fromTable]?.add(r.toTable);
      adj[r.toTable]?.add(r.fromTable);
    }
  }
  int deg(String n) => adj[n]!.length;
  final seen = <String>{}, order = <String>[];
  final starts = [...names]..sort((a, b) => deg(b).compareTo(deg(a)));
  for (final st in starts) {
    if (!seen.add(st)) continue;
    final q = Queue<String>()..add(st);
    while (q.isNotEmpty) {
      final n = q.removeFirst();
      order.add(n);
      final nb = adj[n]!.toList()..sort((a, b) => deg(b).compareTo(deg(a)));
      for (final x in nb) {
        if (seen.add(x)) q.add(x);
      }
    }
  }
  if (order.isEmpty) return {};
  final cols = max(1, sqrt(order.length).ceil());
  final rows = (order.length / cols).ceil();
  final colW = List.filled(cols, 0.0), rowH = List.filled(rows, 0.0);
  for (var i = 0; i < order.length; i++) {
    final sz = sizes[order[i]]!;
    colW[i % cols] = max(colW[i % cols], sz.width);
    rowH[i ~/ cols] = max(rowH[i ~/ cols], sz.height);
  }
  final xs = <double>[], ys = <double>[];
  var x = 60.0, y = 60.0;
  for (final w in colW) {
    xs.add(x);
    x += w + gapX;
  }
  for (final h in rowH) {
    ys.add(y);
    y += h + gapY;
  }
  return {
    for (var i = 0; i < order.length; i++)
      order[i]: Offset(xs[i % cols], ys[i ~/ cols])
  };
}
