import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:dbml_erd_studio/core/constants/sample.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/code_editor.dart';
import '../../domain/entities/dbml_issue.dart' show DbmlIssue;
import '../widgets/dialogs.dart';
import '../controllers/erd_controller.dart';
import '../canvas/erd_painter.dart';
import '../../application/export/erd_export_service.dart';
import '../../domain/services/erd_layout_service.dart';
import '../../domain/services/dbml_source_edit_service.dart';

part 'editor_file_actions.dart';
part 'editor_canvas_interaction.dart';
part 'editor_problems_view.dart';


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
  bool _pointerMoved = false;
  bool _primaryPointerDown = false;
  Duration? _lastPrimaryTap;
  Offset? _lastPrimaryTapWorld;

  void _setState(VoidCallback callback) {
    if (mounted) setState(callback);
  }

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
