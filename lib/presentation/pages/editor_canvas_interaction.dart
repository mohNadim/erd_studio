part of 'editor_page.dart';

extension _EditorCanvasInteraction on _EditorPageState {
  bool get _additive =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isShiftPressed;

  void _down(PointerDownEvent event) {
    _primaryPointerDown = false;
    canvasFocus.requestFocus();
    final world = c.screenToWorld(event.localPosition);
    if (event.buttons & kSecondaryMouseButton != 0) {
      final name = c.hit(world);
      if (name != null) {
        if (!c.selection.contains(name)) c.setSelection({name});
        _tableMenu(event.position);
      }
      return;
    }
    if (event.buttons & kMiddleMouseButton != 0) {
      _drag = _Drag.pan;
      return;
    }
    if (event.buttons & kPrimaryButton == 0) return;

    _primaryPointerDown = true;
    _pointerMoved = false;
    final note = c.hitNote(world);
    if (note != null) {
      _draggedNoteId = note.id;
      _drag = _Drag.note;
      return;
    }
    final name = c.hit(world);
    if (name != null) {
      if (_additive) {
        c.toggle(name);
        _drag = c.selection.contains(name) ? _Drag.tables : _Drag.none;
      } else {
        if (!c.selection.contains(name)) c.setSelection({name});
        _drag = _Drag.tables;
      }
    } else if (_additive) {
      _drag = _Drag.marquee;
      _mStart = world;
      _mBase = Set.of(c.selection);
      c.setMarquee(Rect.fromPoints(world, world), _mBase);
    } else {
      c.clearSelection();
      _drag = _Drag.pan;
    }
  }

  void _move(PointerMoveEvent event) {
    if (event.delta.distance > 1) _pointerMoved = true;
    switch (_drag) {
      case _Drag.tables:
        c.moveSelected(event.delta / c.scale);
      case _Drag.note:
        if (_draggedNoteId != null) {
          c.moveNote(_draggedNoteId!, event.delta / c.scale);
        }
      case _Drag.pan:
        c.panBy(event.delta);
      case _Drag.marquee:
        c.setMarquee(
          Rect.fromPoints(_mStart!, c.screenToWorld(event.localPosition)),
          _mBase,
        );
      case _Drag.none:
        break;
    }
  }

  void _up(PointerEvent event) {
    if (_drag == _Drag.marquee) c.setMarquee(null, _mBase);
    if (_primaryPointerDown &&
        !_pointerMoved &&
        event is PointerUpEvent &&
        event.buttons == 0) {
      final world = c.screenToWorld(event.localPosition);
      final isDoubleTap = _lastPrimaryTap != null &&
          event.timeStamp - _lastPrimaryTap! <=
              const Duration(milliseconds: 350) &&
          _lastPrimaryTapWorld != null &&
          (_lastPrimaryTapWorld! - world).distance <= 8 / c.scale;
      if (isDoubleTap) {
        _renameAt(world);
        _lastPrimaryTap = null;
        _lastPrimaryTapWorld = null;
      } else {
        _lastPrimaryTap = event.timeStamp;
        _lastPrimaryTapWorld = world;
      }
    }
    _primaryPointerDown = false;
    _draggedNoteId = null;
    _drag = _Drag.none;
  }

  Future<void> _renameAt(Offset world) async {
    final tableName = c.hit(world);
    if (tableName == null) return;
    final table = c.byName[tableName];
    final rect = c.tableRect(tableName);
    if (table == null || rect == null) return;

    final localY = world.dy - rect.top;
    String? oldName;
    String? tableForColumn;
    if (localY >= 0 && localY < ErdMetrics.headerH) {
      oldName = tableName;
    } else if (localY >= ErdMetrics.headerH) {
      final index = ((localY - ErdMetrics.headerH) / ErdMetrics.rowH).floor();
      if (index >= 0 && index < table.columns.length) {
        oldName = table.columns[index].name;
        tableForColumn = tableName;
      }
    }
    if (oldName == null) return;

    final controller = TextEditingController(text: oldName);
    final renamed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tableForColumn == null ? 'Rename table' : 'Rename field'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || renamed == null) return;

    final newName = renamed.trim();
    if (newName.isEmpty || newName == oldName) return;
    final updated = tableForColumn == null
        ? renameDbmlTable(text.text, oldName, newName)
        : renameDbmlColumn(text.text, tableForColumn, oldName, newName);
    text.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
    c.pos.clear();
    c.needsFit = true;
    c.update(updated);
  }

  void _signal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      c.zoomAt(event.localPosition, math.exp(-event.scrollDelta.dy / 400));
    }
  }
}
