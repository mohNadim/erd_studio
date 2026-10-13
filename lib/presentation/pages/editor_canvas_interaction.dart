part of 'editor_page.dart';

extension _EditorCanvasInteraction on _EditorPageState {
  MouseCursor get _canvasCursor {
    if (_drag == _Drag.noteResize || _hoveringNoteResize) {
      return SystemMouseCursors.resizeDownRight;
    }
    if (_drag == _Drag.note) {
      return SystemMouseCursors.grabbing;
    }
    if (_hoveredNoteId != null) {
      return SystemMouseCursors.grab;
    }
    return SystemMouseCursors.basic;
  }

  void _hoverCanvas(PointerHoverEvent event) {
    _updateNoteHover(event.localPosition);
  }

  void _updateNoteHover(Offset localPosition) {
    final world = c.screenToWorld(localPosition);
    final note = c.hitNote(world);
    if (note == null) {
      _setNoteHover(null, false);
      return;
    }
    final position = c.notePos[note.id];
    if (position == null) return;
    final handleSize = 16 / c.scale;
    final inHandle = world.dx >= position.dx + note.size.width - handleSize &&
        world.dy >= position.dy + note.size.height - handleSize;
    _setNoteHover(note.id, inHandle);
  }

  void _setNoteHover(String? id, bool resize) {
    if (_hoveredNoteId == id && _hoveringNoteResize == resize) return;
    _setState(() {
      _hoveredNoteId = id;
      _hoveringNoteResize = resize;
    });
  }

  bool get _additive =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isShiftPressed;

  void _down(PointerDownEvent event) {
    _primaryPointerDown = false;
    canvasFocus.requestFocus();
    final world = c.screenToWorld(event.localPosition);
    if (event.buttons & kSecondaryMouseButton != 0) {
      final note = c.hitNote(world);
      if (note != null) {
        _noteMenu(event.position, note);
        return;
      }
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
      final position = c.notePos[note.id];
      final handleSize = 16 / c.scale;
      if (position != null &&
          world.dx >= position.dx + note.size.width - handleSize &&
          world.dy >= position.dy + note.size.height - handleSize) {
        _drag = _Drag.noteResize;
        _noteResizeStart = world;
        _noteResizeInitialSize = note.size;
      } else {
        _drag = _Drag.note;
      }
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
    _updateNoteHover(event.localPosition);
    if (event.delta.distance > 1) _pointerMoved = true;
    switch (_drag) {
      case _Drag.tables:
        c.moveSelected(event.delta / c.scale);
      case _Drag.note:
        if (_draggedNoteId != null) {
          c.moveNote(_draggedNoteId!, event.delta / c.scale);
        }
      case _Drag.noteResize:
        if (_draggedNoteId != null &&
            _noteResizeStart != null &&
            _noteResizeInitialSize != null) {
          final world = c.screenToWorld(event.localPosition);
          final delta = world - _noteResizeStart!;
          c.resizeNote(
            _draggedNoteId!,
            Size(
              (_noteResizeInitialSize!.width + delta.dx).clamp(140.0, 600.0),
              (_noteResizeInitialSize!.height + delta.dy).clamp(90.0, 500.0),
            ),
          );
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
        final note = c.hitNote(world);
        if (note != null) {
          _editNote(note);
        } else {
          _renameAt(world);
        }
        _lastPrimaryTap = null;
        _lastPrimaryTapWorld = null;
      } else {
        _lastPrimaryTap = event.timeStamp;
        _lastPrimaryTapWorld = world;
      }
    }
    _primaryPointerDown = false;
    _draggedNoteId = null;
    _noteResizeStart = null;
    _noteResizeInitialSize = null;
    _drag = _Drag.none;
  }

  Future<void> _editNote(StickyNoteModel note) async {
    final draft = await showDialog<StickyNoteDraftValues>(
      context: context,
      builder: (_) => StickyNoteDialog(
        editing: true,
        initial: StickyNoteDraftValues(
          text: note.text,
          color: note.color,
          fontSize: note.fontSize,
          size: note.size,
        ),
      ),
    );
    if (!mounted || draft == null) return;
    if (draft.delete) {
      c.deleteNote(note.id);
      return;
    }
    c.updateNote(
      note.id,
      text: draft.text,
      color: draft.color,
      fontSize: draft.fontSize,
      size: draft.size,
    );
  }

  Future<void> _noteMenu(Offset global, StickyNoteModel note) async {
    final size = MediaQuery.of(context).size;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(global.dx, global.dy, 0, 0),
        Offset.zero & size,
      ),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('Edit note…')),
        PopupMenuItem(value: 'delete', child: Text('Delete note')),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editNote(note);
    } else if (action == 'delete') {
      await _confirmDeleteNote(note);
    }
  }

  Future<void> _confirmDeleteNote(StickyNoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sticky note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      c.deleteNote(note.id);
    }
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

    final column = tableForColumn == null
        ? null
        : table.columns.firstWhere((item) => item.name == oldName);
    final result = await showDialog<Object>(
      context: context,
      builder: (context) => column == null
          ? RenameTableDialog(initial: oldName!)
          : ColumnEditorDialog(
              initial: ColumnDraftValues(
                name: column.name,
                type: column.type,
                pk: column.pk,
                notNull: column.notNull,
                unique: column.unique,
                autoInc: column.autoInc,
                note: column.note ?? '',
                defaultValue: column.defaultValue ?? '',
              ),
            ),
    );
    if (!mounted || result == null) return;

    final columnDraft = result is ColumnDraftValues ? result : null;
    final newName = result is String ? result.trim() : columnDraft!.name;
    if (newName.isEmpty) return;
    final updated = tableForColumn == null
        ? renameDbmlTable(text.text, oldName, newName)
        : updateDbmlColumn(
            text.text,
            tableForColumn,
            oldName,
            newName: newName,
            type: columnDraft!.type,
            pk: columnDraft.pk,
            notNull: columnDraft.notNull,
            unique: columnDraft.unique,
            autoInc: columnDraft.autoInc,
            note: columnDraft.note,
            defaultValue: columnDraft.defaultValue,
          );
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
