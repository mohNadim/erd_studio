import 'dart:math';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import '../controllers/erd_controller.dart';
import '../../domain/entities/schema_models.dart';
import '../../domain/services/erd_layout_service.dart';

enum RelationLineStyle { curved, orthogonal }

class ErdPalette {
  const ErdPalette({
    required this.dark,
    required this.bg,
    required this.grid,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.text,
    required this.muted,
    required this.edge,
    required this.accent,
  });
  final bool dark;
  final Color bg, grid, card, cardAlt, border, text, muted, edge, accent;

  static const light = ErdPalette(
    dark: false,
    bg: Color(0xFFF6F7FB),
    grid: Color(0xFFD3D7E3),
    card: Colors.white,
    cardAlt: Color(0xFFF3F4F9),
    border: Color(0xFFCBD0DE),
    text: Color(0xFF1B1E2B),
    muted: Color(0xFF6B7186),
    edge: Color(0xFF6B7186),
    accent: Color(0xFFE8590C),
  );
  static const darkPal = ErdPalette(
    dark: true,
    bg: Color(0xFF14161F),
    grid: Color(0xFF2A2F40),
    card: Color(0xFF1E2230),
    cardAlt: Color(0xFF232838),
    border: Color(0xFF383E54),
    text: Color(0xFFE6E8F2),
    muted: Color(0xFF8F96B0),
    edge: Color(0xFF8F96B0),
    accent: Color(0xFFFFA94D),
  );
}

Color _autoColor(String name, bool dark) {
  var h = 7;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, dark ? 0.36 : 0.42)
      .toColor();
}

class ErdPainter extends CustomPainter {
  ErdPainter(this.c, this.pal,
      {this.forExport = false,
      this.relationLineStyle = RelationLineStyle.curved})
      : super(repaint: c);
  final ErdController c;
  final ErdPalette pal;
  final bool forExport;
  final RelationLineStyle relationLineStyle;

  bool _sel(String n) => !forExport && c.selection.contains(n);

  /// Interactive painting: background, grid, then the world through the view transform.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.bg);
    final vis = c.visibleWorld(size);
    _grid(canvas, vis);
    canvas.save();
    canvas.translate(c.pan.dx, c.pan.dy);
    canvas.scale(c.scale);
    paintWorld(canvas, vis);
    final m = c.marquee;
    if (m != null) {
      canvas.drawRect(m, Paint()..color = pal.accent.withAlpha(34));
      canvas.drawRect(
          m,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / c.scale
            ..color = pal.accent);
    }
    canvas.restore();
  }

  void _grid(Canvas canvas, Rect vis) {
    if (c.scale < 0.25) return;
    final step = c.scale < 0.6 ? 56.0 : 28.0;
    final x0 = (vis.left / step).floorToDouble() * step;
    final y0 = (vis.top / step).floorToDouble() * step;
    final pts = <Offset>[];
    for (var x = x0; x < vis.right; x += step) {
      for (var y = y0; y < vis.bottom; y += step) {
        pts.add(Offset(x, y) * c.scale + c.pan);
      }
    }
    canvas.drawPoints(
        PointMode.points,
        pts,
        Paint()
          ..color = pal.grid
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);
  }

  /// Draws tables + relations in world coordinates (also used by PNG export).
  void paintWorld(Canvas canvas, Rect vis) {
    final cull = vis.inflate(240);
    final fk = <String>{
      for (final r in c.schema.refs) '${r.fromTable}.${r.fromColumn}'
    };
    for (final r in c.schema.refs) {
      _edge(canvas, r, cull);
    }
    for (final t in c.schema.tables) {
      final rect = c.tableRect(t.name);
      if (rect == null || !rect.overlaps(cull)) continue;
      _table(canvas, t, rect, fk);
    }
    for (final note in c.notes) {
      final position = c.notePos[note.id];
      if (position == null || !(position & note.size).overlaps(cull)) continue;
      _note(canvas, note, position);
    }
  }

  void _note(Canvas canvas, StickyNoteModel note, Offset position) {
    final rect = position & note.size;
    final fill = Color(note.color);
    canvas.drawRect(rect.shift(const Offset(0, 3)),
        Paint()..color = Colors.black.withAlpha(35));
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withAlpha(45));
    final text = ErdText.lay(
      note.text,
      TextStyle(
        color: fill.computeLuminance() > 0.55 ? Colors.black87 : Colors.white,
        fontSize: note.fontSize,
        height: 1.25,
      ),
      rect.width - 24,
    );
    text.paint(canvas, position + const Offset(12, 12));
  }

  void _table(Canvas canvas, TableModel t, Rect r, Set<String> fk) {
    final sel = _sel(t.name);
    final hc = t.headerColor != null
        ? Color(t.headerColor!)
        : _autoColor(t.name, pal.dark);
    final onHeader =
        hc.computeLuminance() > 0.55 ? const Color(0xFF111827) : Colors.white;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    canvas.drawRRect(rr.shift(const Offset(0, 3)),
        Paint()..color = Colors.black.withAlpha(pal.dark ? 90 : 38));
    canvas.drawRRect(rr, Paint()..color = pal.card);
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, ErdMetrics.headerH),
        Paint()..color = hc);
    final title = ErdText.lay(
        t.name,
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onHeader),
        r.width - ErdMetrics.pad * 2);
    title.paint(
        canvas,
        Offset(r.left + ErdMetrics.pad,
            r.top + (ErdMetrics.headerH - title.height) / 2));
    for (var i = 0; i < t.columns.length; i++) {
      final col = t.columns[i];
      final top = r.top + ErdMetrics.headerH + i * ErdMetrics.rowH;
      if (i.isOdd) {
        canvas.drawRect(Rect.fromLTWH(r.left, top, r.width, ErdMetrics.rowH),
            Paint()..color = pal.cardAlt);
      }
      final badge = col.pk
          ? 'PK'
          : fk.contains('${t.name}.${col.name}')
              ? 'FK'
              : col.unique
                  ? 'UQ'
                  : null;
      if (badge != null) {
        final br = RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + ErdMetrics.pad, top + 6, 24, 16),
            const Radius.circular(4));
        final bc = badge == 'PK' ? pal.accent : pal.muted;
        canvas.drawRRect(br, Paint()..color = bc.withAlpha(51));
        final bt = ErdText.lay(badge,
            TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: bc));
        bt.paint(
            canvas,
            Offset(
                br.left + (24 - bt.width) / 2, br.top + (16 - bt.height) / 2));
      }
      final ty = ErdText.lay(col.type, ErdText.type(pal.muted));
      ty.paint(
          canvas,
          Offset(r.right - ErdMetrics.pad - ty.width,
              top + (ErdMetrics.rowH - ty.height) / 2));
      final nm = ErdText.lay(col.name, ErdText.name(pal.text, bold: col.pk),
          r.width - ty.width - ErdMetrics.pad * 3 - 34);
      nm.paint(
          canvas,
          Offset(r.left + ErdMetrics.pad + 30,
              top + (ErdMetrics.rowH - nm.height) / 2));
    }
    canvas.restore();
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sel ? 2.6 : 1
          ..color = sel ? pal.accent : pal.border);
  }

  double _colY(String table, String col) {
    final t = c.byName[table];
    final o = c.pos[table]!;
    final i = t == null ? -1 : t.columns.indexWhere((e) => e.name == col);
    if (i < 0) return o.dy + ErdMetrics.headerH / 2;
    return o.dy + ErdMetrics.headerH + (i + 0.5) * ErdMetrics.rowH;
  }

  void _edge(Canvas canvas, RefModel r, Rect cull) {
    final a = c.tableRect(r.fromTable), b = c.tableRect(r.toTable);
    if (a == null || b == null) return;
    if (!a.expandToInclude(b).overlaps(cull)) return;
    final horizontal = (b.center.dx - a.center.dx).abs() >=
        (b.center.dy - a.center.dy).abs();
    late Offset p1, p2, d1, d2;
    if (horizontal) {
      final fromRight = b.center.dx >= a.center.dx;
      final toRight = !fromRight;
      p1 = Offset(
        fromRight ? a.right : a.left,
        _colY(r.fromTable, r.fromColumn),
      );
      p2 = Offset(
        toRight ? b.right : b.left,
        _colY(r.toTable, r.toColumn),
      );
      d1 = Offset(fromRight ? 1 : -1, 0);
      d2 = Offset(toRight ? 1 : -1, 0);
    } else {
      final fromBottom = b.center.dy >= a.center.dy;
      final toBottom = !fromBottom;
      p1 = Offset(
        _colX(r.fromTable, r.fromColumn),
        fromBottom ? a.bottom : a.top,
      );
      p2 = Offset(
        _colX(r.toTable, r.toColumn),
        toBottom ? b.bottom : b.top,
      );
      d1 = Offset(0, fromBottom ? 1 : -1);
      d2 = Offset(0, toBottom ? 1 : -1);
    }
    final k = max(60.0, (p2 - p1).distance / 2);
    final hot = _sel(r.fromTable) || _sel(r.toTable);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hot ? 2.2 : 1.5
      ..strokeCap = StrokeCap.round
      ..color = hot ? pal.accent : pal.edge;
    final path = Path()..moveTo(p1.dx, p1.dy);
    if (relationLineStyle == RelationLineStyle.orthogonal) {
      const clearance = 40.0;
      final q1 = p1 + d1 * clearance;
      final q2 = p2 + d2 * clearance;
      if (horizontal) {
        path
          ..lineTo(q1.dx, q1.dy)
          ..lineTo(q2.dx, q1.dy)
          ..lineTo(q2.dx, q2.dy)
          ..lineTo(p2.dx, p2.dy);
      } else {
        path
          ..lineTo(q1.dx, q1.dy)
          ..lineTo(q1.dx, q2.dy)
          ..lineTo(q2.dx, q2.dy)
          ..lineTo(p2.dx, p2.dy);
      }
    } else {
      final q1 = p1 + d1 * k;
      final q2 = p2 + d2 * k;
      path.cubicTo(q1.dx, q1.dy, q2.dx, q2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(path, paint);
    _marker(canvas, p1, d1, r.fromMany, paint);
    _marker(canvas, p2, d2, r.toMany, paint);
  }

  double _colX(String table, String col) {
    final t = c.byName[table];
    final rect = c.tableRect(table)!;
    final i = t == null ? -1 : t.columns.indexWhere((e) => e.name == col);
    if (i < 0) return rect.center.dx;
    return rect.left + ErdMetrics.pad + 30;
  }

  void _marker(Canvas c, Offset p, Offset d, bool many, Paint paint) {
    if (many) {
      final normal = Offset(-d.dy, d.dx);
      final apex = p + d * 14;
      c.drawLine(apex, p + normal * 7, paint);
      c.drawLine(apex, p - normal * 7, paint);
      c.drawLine(apex, p, paint);
    } else {
      for (final o in [9.0, 14.0]) {
        final center = p + d * o;
        final normal = Offset(-d.dy, d.dx) * 6;
        c.drawLine(center - normal, center + normal, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ErdPainter old) =>
      old.pal != pal || old.relationLineStyle != relationLineStyle;
}
