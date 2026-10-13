import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../presentation/controllers/erd_controller.dart';
import '../../presentation/canvas/erd_painter.dart';

enum ExportFormat { png, pdf }

/// Renders the whole diagram (independent of the current zoom/selection) to a PNG.
/// [scale] 4 ≈ 384 dpi; automatically capped to keep the image under 16k px.
Future<Uint8List> renderErdPng(ErdController c, ErdPalette pal,
    {double scale = 4,
    bool transparent = false,
    RelationLineStyle relationLineStyle = RelationLineStyle.curved}) async {
  const margin = 56.0;
  final b = c.bounds().inflate(margin);
  if (b.isEmpty || !b.width.isFinite || !b.height.isFinite) {
    throw StateError('The diagram has no drawable content.');
  }

  if (!scale.isFinite || scale <= 0) {
    throw ArgumentError.value(
        scale, 'scale', 'must be a positive finite number');
  }
  final s = min(scale, 16000 / max(b.width, b.height));
  final w = max(1, (b.width * s).ceil());
  final h = max(1, (b.height * s).ceil());

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(s);
  if (!transparent) {
    canvas.drawRect(Offset.zero & b.size, Paint()..color = pal.bg);
  }
  canvas.translate(-b.left, -b.top);
  ErdPainter(c, pal,
          forExport: true, relationLineStyle: relationLineStyle)
      .paintWorld(canvas, b);

  final picture = rec.endRecording();
  try {
    final img = await picture.toImage(w, h);
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('PNG encoding returned no data.');
      }
      return data.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// Creates a PDF page containing the complete diagram as a rendered image.
/// The page keeps the diagram's aspect ratio and uses points as PDF units.
Future<Uint8List> renderErdPdf(ErdController c, ErdPalette pal,
    {double scale = 4,
    bool transparent = false,
    RelationLineStyle relationLineStyle = RelationLineStyle.curved}) async {
  final png = await renderErdPng(
    c,
    pal,
    scale: scale,
    transparent: transparent,
    relationLineStyle: relationLineStyle,
  );
  final b = c.bounds().inflate(56);
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        max(1, b.width),
        max(1, b.height),
        marginAll: 0,
      ),
      build: (_) => pw.Image(
        pw.MemoryImage(png),
        width: b.width,
        height: b.height,
        fit: pw.BoxFit.fill,
      ),
    ),
  );
  return document.save();
}
