import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code_editor.dart';
import 'dbml_service.dart' show DbmlIssue;
import 'dialogs.dart';
import 'erd_controller.dart';
import 'erd_painter.dart';
import 'export.dart';
import 'source_edit.dart';

const kSample = r'''
Table users [headercolor: #3B82F6] {
  id integer [pk, increment]
  username varchar(60) [unique, not null]
  email varchar(120) [unique, not null]
  created_at timestamp
}

Table products {
  id integer [pk]
  name varchar(120) [not null]
  price decimal(10,2)
  category_id integer [ref: > categories.id]
}

Table categories {
  id integer [pk]
  name varchar
}

Table orders {
  id integer [pk]
  user_id integer [ref: > users.id]
  status varchar
  created_at timestamp
}

Table order_items {
  order_id integer [pk]
  product_id integer [pk]
  quantity integer
}

Ref: order_items.order_id > orders.id
Ref: order_items.product_id > products.id
''';

enum _Drag { none, tables, pan, marquee }

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final c = ErdController();
  final text = DbmlTextController(text: kSample);
  final vScroll = ScrollController();
  final editorFocus = FocusNode();
  final canvasFocus = FocusNode();

  Timer? _debounce;
  double _editorW = 440, _problemsH = 150, _editorVH = 400;
  bool _problemsOpen = true;
  List<DbmlIssue> _shownIssues = const [];

  _Drag _drag = _Drag.none;
  Offset? _mStart;
  Set<String> _mBase = {};
  double _tpScale = 1;

  @override
  void initState() {
    super.initState();
    c.update(text.text);
    _shownIssues = c.issues;
    text.issues = c.issues;
    c.addListener(_onC);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    c.removeListener(_onC);
    c.dispose();
    text.dispose();
    vScroll.dispose();
    editorFocus.dispose();
    canvasFocus.dispose();
    super.dispose();
  }

  /// Pushes new problems to the editor (underlines) and the problems panel.
  void _onC() {
    if (identical(c.issues, _shownIssues)) return;
    _shownIssues = c.issues;
    text.issues = c.issues;
    if (mounted) setState(() {});
  }

  ErdPalette get pal => Theme.of(context).brightness == Brightness.dark
      ? ErdPalette.darkPal
      : ErdPalette.light;

  void _changed(String _) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 250), () => c.update(text.text));
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(m), duration: const Duration(seconds: 4)));
  }

  // ─────────────────────────────── files ───────────────────────────────

  String _downloads(String name) {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    final dir = Directory('$home${Platform.pathSeparator}Downloads');
    return '${dir.existsSync() ? dir.path : home}${Platform.pathSeparator}$name';
  }

  Future<void> _open() async {
    try {
      final r = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['dbml', 'txt']);
      final path = r?.files.single.path;
      if (path == null) return;
      final src = await File(path).readAsString();
      text.text = src;
      c.pos.clear();
      c.needsFit = true;
      c.update(src);
    } catch (e) {
      _toast('Could not open file: $e');
    }
  }

  Future<void> _saveDbml() async {
    try {
      var p = await FilePicker.platform.saveFile(
          dialogTitle: 'Save DBML',
          fileName: 'schema.dbml',
          type: FileType.custom,
          allowedExtensions: ['dbml']);
      if (p == null) return;
      if (!p.toLowerCase().endsWith('.dbml')) p = '$p.dbml';
      await File(p).writeAsString(text.text);
      _toast('Saved → $p');
    } catch (e) {
      _toast('Could not save: $e');
    }
  }

  Future<void> _export() async {
    if (c.schema.tables.isEmpty) {
      _toast('Nothing to export yet — the diagram is empty.');
      return;
    }
    final palette = pal;
    final opt = await showDialog<ExportOptions>(
        context: context, builder: (_) => ExportDialog(c: c));
    if (opt == null) return;
    final extension = opt.format == ExportFormat.pdf ? 'pdf' : 'png';
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
          dialogTitle: 'Export diagram',
          fileName: 'erd.$extension',
          type: FileType.custom,
          allowedExtensions: [extension]);
    } catch (e) {
      path = _downloads('erd.$extension');
      _toast('Save dialog unavailable ($e). Saving to $path');
    }
    if (path == null) return; // user cancelled
    if (!path.toLowerCase().endsWith('.$extension')) {
      path = '$path.$extension';
    }
    try {
      final bytes = opt.format == ExportFormat.pdf
          ? await renderErdPdf(c, palette,
              scale: opt.scale, transparent: opt.transparent)
          : await renderErdPng(c, palette,
              scale: opt.scale, transparent: opt.transparent);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      _toast('Exported → $path');
    } catch (e) {
      _toast('Export failed: $e');
    }
  }

  // ───────────────────────────── table colors ─────────────────────────────

  Future<void> _pickColor() async {
    if (c.selection.isEmpty) return;
    final r = await showDialog<ColorChoice>(
        context: context,
        builder: (_) => ColorDialog(count: c.selection.length));
    if (r == null) return;
    final src = setTableHeaderColor(
        text.text, Set.of(c.selection), r.reset ? null : colorToHex(r.color!));
    final off = text.selection.isValid
        ? math.min(text.selection.baseOffset, src.length)
        : 0;
    text.value = TextEditingValue(
        text: src,
        selection: TextSelection.collapsed(offset: math.max(0, off)));
    c.update(src);
  }

  Future<void> _tableMenu(Offset global) async {
    final size = MediaQuery.of(context).size;
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          Rect.fromLTWH(global.dx, global.dy, 0, 0), Offset.zero & size),
      items: [
        PopupMenuItem(
            value: 'color',
            child: Text(c.selection.length > 1
                ? 'Change color of ${c.selection.length} tables…'
                : 'Change color…')),
        const PopupMenuItem(value: 'all', child: Text('Select all tables')),
      ],
    );
    if (v == 'color') _pickColor();
    if (v == 'all') c.selectAll();
  }

  // ───────────────────────────── canvas input ─────────────────────────────

  bool get _additive =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isShiftPressed;

  void _down(PointerDownEvent e) {
    canvasFocus.requestFocus();
    final w = c.screenToWorld(e.localPosition);
    if (e.buttons & kSecondaryMouseButton != 0) {
      final n = c.hit(w);
      if (n != null) {
        if (!c.selection.contains(n)) c.setSelection({n});
        _tableMenu(e.position);
      }
      return;
    }
    if (e.buttons & kMiddleMouseButton != 0) {
      _drag = _Drag.pan;
      return;
    }
    if (e.buttons & kPrimaryButton == 0) return;
    final n = c.hit(w);
    if (n != null) {
      if (_additive) {
        c.toggle(n);
        _drag = c.selection.contains(n) ? _Drag.tables : _Drag.none;
      } else {
        if (!c.selection.contains(n)) c.setSelection({n});
        _drag = _Drag.tables;
      }
    } else if (_additive) {
      _drag = _Drag.marquee;
      _mStart = w;
      _mBase = Set.of(c.selection);
      c.setMarquee(Rect.fromPoints(w, w), _mBase);
    } else {
      c.clearSelection();
      _drag = _Drag.pan;
    }
  }

  void _move(PointerMoveEvent e) {
    switch (_drag) {
      case _Drag.tables:
        c.moveSelected(e.delta / c.scale); // exactly follows the cursor
      case _Drag.pan:
        c.panBy(e.delta);
      case _Drag.marquee:
        c.setMarquee(
            Rect.fromPoints(_mStart!, c.screenToWorld(e.localPosition)),
            _mBase);
      case _Drag.none:
        break;
    }
  }

  void _up(PointerEvent e) {
    if (_drag == _Drag.marquee) c.setMarquee(null, _mBase);
    _drag = _Drag.none;
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      c.zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy / 400));
    }
  }

  // ───────────────────────────── problems ─────────────────────────────

  void _goTo(DbmlIssue i) {
    if (i.line <= 0) return;
    final t = text.text;
    var off = 0, line = 1;
    while (line < i.line) {
      final k = t.indexOf('\n', off);
      if (k < 0) {
        off = t.length;
        break;
      }
      off = k + 1;
      line++;
    }
    off = math.min(t.length, off + math.max(0, i.column - 1));
    text.selection = TextSelection.collapsed(offset: off);
    editorFocus.requestFocus();
    if (vScroll.hasClients) {
      final target = (i.line - 1) * kLineHeight;
      final top = vScroll.offset;
      if (target < top || target > top + _editorVH - 3 * kLineHeight) {
        vScroll.animateTo(
          (target - _editorVH / 3)
              .clamp(0.0, vScroll.position.maxScrollExtent)
              .toDouble(),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _problemsPanel(ColorScheme cs) {
    final issues = c.issues;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) => setState(() => _problemsH =
              (_problemsH - d.delta.dy).clamp(80.0, 420.0).toDouble()),
          child: Container(height: 6, color: cs.outlineVariant.withAlpha(120)),
        ),
      ),
      Container(
        height: _problemsH,
        color: cs.surfaceContainerLow,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
            child: Row(children: [
              Text('PROBLEMS  ${issues.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: .6)),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _problemsOpen = false),
              ),
            ]),
          ),
          Expanded(
            child: issues.isEmpty
                ? Center(
                    child: Text('No problems found',
                        style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
                    itemCount: issues.length,
                    itemBuilder: (_, i) {
                      final it = issues[i];
                      return InkWell(
                        onTap: () => _goTo(it),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 16, color: cs.error),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(it.message,
                                        style:
                                            const TextStyle(fontSize: 12.5))),
                                const SizedBox(width: 8),
                                if (it.line > 0)
                                  Text('[${it.line}:${it.column}]',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                              ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    ]);
  }

  Widget _statusBar(ColorScheme cs) => ListenableBuilder(
        listenable: c,
        builder: (_, __) {
          final n = c.issues.length;
          return InkWell(
            onTap: () => setState(() => _problemsOpen = !_problemsOpen),
            child: Container(
              height: 26,
              color: cs.surfaceContainerHigh,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Icon(n > 0 ? Icons.error_outline : Icons.check_circle_outline,
                    size: 15, color: n > 0 ? cs.error : Colors.green),
                const SizedBox(width: 6),
                Text(n > 0 ? '$n problem${n == 1 ? '' : 's'}' : 'No problems',
                    style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Text(
                    '${c.schema.tables.length} tables · ${c.schema.refs.length} relations',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
          );
        },
      );

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxEditor = math.max(260.0, MediaQuery.of(context).size.width - 340);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DBML ERD Studio'),
        actions: [
          IconButton(
              tooltip: 'Open .dbml',
              icon: const Icon(Icons.folder_open),
              onPressed: _open),
          IconButton(
              tooltip: 'Save .dbml',
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveDbml),
          IconButton(
              tooltip: 'Export diagram…',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: _export),
          const SizedBox(width: 6),
          IconButton(
              tooltip: 'Auto layout',
              icon: const Icon(Icons.auto_awesome_mosaic_outlined),
              onPressed: c.relayout),
          IconButton(
              tooltip: 'Fit to screen',
              icon: const Icon(Icons.fit_screen),
              onPressed: c.fit),
          IconButton(
              tooltip: 'Select all tables (Ctrl+A)',
              icon: const Icon(Icons.select_all),
              onPressed: c.selectAll),
          ListenableBuilder(
            listenable: c,
            builder: (_, __) => IconButton(
              tooltip: c.selection.isEmpty
                  ? 'Select tables to change their color'
                  : 'Color of ${c.selection.length} selected table(s)',
              icon: const Icon(Icons.palette_outlined),
              onPressed: c.selection.isEmpty ? null : _pickColor,
            ),
          ),
          IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleTheme),
        ],
      ),
      body: Row(children: [
        SizedBox(
          width: _editorW.clamp(240.0, maxEditor).toDouble(),
          child: Column(children: [
            Expanded(
              child: LayoutBuilder(builder: (_, cons) {
                _editorVH = cons.maxHeight;
                return CodeEditor(
                  controller: text,
                  onChanged: _changed,
                  vScroll: vScroll,
                  focusNode: editorFocus,
                );
              }),
            ),
            if (_problemsOpen) _problemsPanel(cs),
            _statusBar(cs),
          ]),
        ),
        // draggable divider: resize the code editor
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => setState(() => _editorW =
                (_editorW + d.delta.dx).clamp(240.0, maxEditor).toDouble()),
            child: Container(width: 7, color: cs.outlineVariant.withAlpha(120)),
          ),
        ),
        Expanded(child: _canvas()),
      ]),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(builder: (ctx, cons) {
      final size = cons.biggest;
      if (size != c.viewport) {
        c.viewport = size;
        if (c.needsFit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && c.needsFit) c.fit();
          });
        }
      }
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyA, control: true):
              c.selectAll,
          const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
              c.selectAll,
          const SingleActivator(LogicalKeyboardKey.escape): c.clearSelection,
        },
        child: Focus(
          focusNode: canvasFocus,
          child: ClipRect(
            child: Stack(children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  onPointerSignal: _signal,
                  onPointerPanZoomStart: (_) => _tpScale = 1,
                  onPointerPanZoomUpdate: (e) {
                    c.panBy(e.panDelta);
                    final f = e.scale / _tpScale;
                    _tpScale = e.scale;
                    if (f != 1) c.zoomAt(e.localPosition, f);
                  },
                  child: CustomPaint(size: size, painter: ErdPainter(c, pal)),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 8,
                child: IgnorePointer(
                  child: Text(
                    'Drag: pan · Wheel: zoom · Click: select · Ctrl/Shift+click: multi-select · '
                    'Shift+drag: box select · Right-click: color',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurfaceVariant
                            .withAlpha(170)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
