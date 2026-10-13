part of 'erd_controller.dart';

mixin _ErdControllerView on _ErdControllerBase {
  Offset screenToWorld(Offset point) => (point - pan) / scale;

  Rect visibleWorld(Size size) => Rect.fromLTWH(
        -pan.dx / scale,
        -pan.dy / scale,
        size.width / scale,
        size.height / scale,
      );

  @override
  void fit() {
    final currentViewport = viewport;
    if (currentViewport.isEmpty) return;
    final diagramBounds = bounds();
    if (diagramBounds.isEmpty) {
      scale = 1;
      pan = Offset(currentViewport.width / 2, currentViewport.height / 2);
    } else {
      final paddedBounds = diagramBounds.inflate(56);
      scale = min(
        currentViewport.width / paddedBounds.width,
        currentViewport.height / paddedBounds.height,
      ).clamp(0.1, 1.0).toDouble();
      pan = Offset(currentViewport.width / 2, currentViewport.height / 2) -
          paddedBounds.center * scale;
    }
    needsFit = false;
    notifyListeners();
  }

  void panBy(Offset delta) {
    pan += delta;
    notifyListeners();
  }

  void zoomAt(Offset screenPoint, double factor) {
    final nextScale = (scale * factor).clamp(0.1, 4.0).toDouble();
    final ratio = nextScale / scale;
    pan = screenPoint - (screenPoint - pan) * ratio;
    scale = nextScale;
    notifyListeners();
  }
}
