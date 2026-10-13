part of 'erd_controller.dart';

mixin _ErdControllerGeometry on _ErdControllerBase {
  @override
  Rect bounds() {
    Rect? result;
    for (final entry in pos.entries) {
      final size = sizes[entry.key];
      if (size == null) continue;
      final tableRect = entry.value & size;
      result = result == null ? tableRect : result.expandToInclude(tableRect);
    }
    for (final note in notes) {
      final position = notePos[note.id];
      if (position == null) continue;
      final noteRect = position & note.size;
      result = result == null ? noteRect : result.expandToInclude(noteRect);
    }
    return result ?? Rect.zero;
  }

  @override
  Rect? tableRect(String name) {
    final offset = pos[name];
    final size = sizes[name];
    return (offset == null || size == null) ? null : offset & size;
  }

  String? hit(Offset world) {
    for (final table in schema.tables.reversed) {
      final rect = tableRect(table.name);
      if (rect != null && rect.contains(world)) return table.name;
    }
    return null;
  }

  StickyNoteModel? hitNote(Offset world) {
    for (final note in notes.reversed) {
      final position = notePos[note.id];
      if (position != null && (position & note.size).contains(world)) {
        return note;
      }
    }
    return null;
  }

  Size exportSize(double scale) {
    final diagramBounds = bounds().inflate(56);
    if (diagramBounds.isEmpty) return Size.zero;
    final constrainedScale =
        min(scale, 16000 / max(diagramBounds.width, diagramBounds.height));
    return Size(
      (diagramBounds.width * constrainedScale).ceilToDouble(),
      (diagramBounds.height * constrainedScale).ceilToDouble(),
    );
  }
}
