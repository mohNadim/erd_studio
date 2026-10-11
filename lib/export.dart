import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'erd_controller.dart';
import 'erd_painter.dart';

/// Renders the whole diagram (independent of the current zoom) to a PNG.
/// [scale] 4 ≈ 384 dpi; automatically capped to keep the image under 16k px.
Future<Uint8List> renderErdPng(ErdController c, ErdPalette pal,
    {double scale = 4, bool transparent = false}) async {
  const margin = 56.0;
  final b = c.bounds().inflate(margin);
  final s = min(scale, 16000 / max(b.width, b.height));
  final w = (b.width * s).ceil(), h = (b.height * s).ceil();

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(s);
  if (!transparent) {
    canvas.drawRect(Offset.zero & b.size, Paint()..color = pal.bg);
  }
  canvas.translate(-b.left, -b.top);
  ErdPainter(c, pal, paintGrid: false).paint(canvas, b.size);

  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
