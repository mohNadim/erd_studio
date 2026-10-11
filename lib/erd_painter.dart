import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'erd_controller.dart';
import 'layout.dart';
import 'models.dart';

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
    grid: Color(0xFFD9DCE6),
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
    grid: Color(0xFF262A38),
    card: Color(0xFF1E2230),
    cardAlt: Color(0xFF232838),
    border: Color(0xFF383E54),
    text: Color(0xFFE6E8F2),
    muted: Color(0xFF8F96B0),
    edge: Color(0xFF8F96B0),
    accent: Color(0xFFFFA94D),
  );
}

Color _headerColor(String name, bool dark) {
  var h = 7;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, dark ? 0.36 : 0.42).toColor();
}

class ErdPainter extends CustomPainter {
  ErdPainter(this.c, this.pal, {this.paintGrid = true}) : super(repaint: c);
  final ErdController c;
  final ErdPalette pal;
  final bool paintGrid;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintGrid) {
      canvas.drawRect(Offset.zero & size, Paint()..color = pal.bg);
      final pts = <Offset>[];
      for (var x = 0.0; x < size.width; x += 28) {
        for (var y = 0.0; y < size.height; y += 28) {
          pts.add(Offset(x, y));
        }
      }
      canvas.drawPoints(PointMode.points, pts,
          Paint()..color = pal.grid..strokeWidth = 1.6..strokeCap = StrokeCap.round);
    }
    final fk = <String>{for (final r in c.schema.refs) '${r.fromTable}.${r.fromColumn}'};
    for (final r in c.schema.refs) {
      _edge(canvas, r);
    }
    for (final t in c.schema.tables) {
      final o = c.pos[t.name], s = c.sizes[t.name];
      if (o != null && s != null) _table(canvas, t, o & s, fk);
    }
  }

  void _table(Canvas canvas, TableModel t, Rect r, Set<String> fk) {
    final sel = c.selected == t.name;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    canvas.drawShadow(Path()..addRRect(rr), Colors.black, sel ? 10 : 4, true);
    canvas.drawRRect(rr, Paint()..color = pal.card);
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, ErdMetrics.headerH),
        Paint()..color = _headerColor(t.name, pal.dark));
    final title = ErdText.lay(t.name, ErdText.title, r.width - ErdMetrics.pad * 2);
    title.paint(canvas,
        Offset(r.left + ErdMetrics.pad, r.top + (ErdMetrics.headerH - title.height) / 2));
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
        canvas.drawRRect(
            br,
            Paint()
              ..color = (badge == 'PK' ? pal.accent : pal.muted)
                  .withValues(alpha: 0.2));
        final bt = ErdText.lay(
            badge,
            TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: badge == 'PK' ? pal.accent : pal.muted));
        bt.paint(canvas, Offset(br.left + (24 - bt.width) / 2, br.top + (16 - bt.height) / 2));
      }
      final ty = ErdText.lay(col.type, ErdText.type(pal.muted));
      ty.paint(canvas,
          Offset(r.right - ErdMetrics.pad - ty.width, top + (ErdMetrics.rowH - ty.height) / 2));
      final nm = ErdText.lay(col.name, ErdText.name(pal.text, bold: col.pk),
          r.width - ty.width - ErdMetrics.pad * 3 - 34);
      nm.paint(canvas,
          Offset(r.left + ErdMetrics.pad + 30, top + (ErdMetrics.rowH - nm.height) / 2));
    }
    canvas.restore();
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sel ? 2.4 : 1
          ..color = sel ? pal.accent : pal.border);
  }

  double _colY(String table, String col) {
    final t = c.schema.tables.firstWhere((e) => e.name == table);
    final i = t.columns.indexWhere((e) => e.name == col);
    final o = c.pos[table]!;
    if (i < 0) return o.dy + ErdMetrics.headerH / 2;
    return o.dy + ErdMetrics.headerH + (i + 0.5) * ErdMetrics.rowH;
  }

  void _edge(Canvas canvas, RefModel r) {
    final ao = c.pos[r.fromTable], as_ = c.sizes[r.fromTable];
    final bo = c.pos[r.toTable], bs = c.sizes[r.toTable];
    if (ao == null || as_ == null || bo == null || bs == null) return;
    final a = ao & as_, b = bo & bs;
    bool fromRight = true, toRight = true;
    if (a.right + 40 <= b.left) {
      toRight = false;
    } else if (b.right + 40 <= a.left) {
      fromRight = false;
    }
    final p1 = Offset(fromRight ? a.right : a.left, _colY(r.fromTable, r.fromColumn));
    final p2 = Offset(toRight ? b.right : b.left, _colY(r.toTable, r.toColumn));
    final d1 = fromRight ? 1.0 : -1.0, d2 = toRight ? 1.0 : -1.0;
    final k = max(60.0, (p2.dx - p1.dx).abs() / 2);
    final hot = c.selected == r.fromTable || c.selected == r.toTable;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hot ? 2.2 : 1.5
      ..strokeCap = StrokeCap.round
      ..color = hot ? pal.accent : pal.edge;
    canvas.drawPath(
        Path()
          ..moveTo(p1.dx, p1.dy)
          ..cubicTo(p1.dx + d1 * k, p1.dy, p2.dx + d2 * k, p2.dy, p2.dx, p2.dy),
        paint);
    _marker(canvas, p1, d1, r.fromMany, paint);
    _marker(canvas, p2, d2, r.toMany, paint);
  }

  void _marker(Canvas c, Offset p, double d, bool many, Paint paint) {
    if (many) {
      final apex = p + Offset(d * 14, 0);
      c.drawLine(apex, p + const Offset(0, -7), paint);
      c.drawLine(apex, p + const Offset(0, 7), paint);
      c.drawLine(apex, p, paint);
    } else {
      for (final o in [9.0, 14.0]) {
        c.drawLine(p + Offset(d * o, -6), p + Offset(d * o, 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ErdPainter old) => old.pal != pal || old.paintGrid != paintGrid;
}
