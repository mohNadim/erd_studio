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
import '../../domain/entities/schema_models.dart';
import '../../domain/services/erd_layout_service.dart';
import '../../domain/services/dbml_source_edit_service.dart';
import '../app/theme_settings.dart';

part 'editor_file_actions.dart';
part 'editor_canvas_interaction.dart';
part 'editor_problems_view.dart';

enum _Drag { none, tables, note, noteResize, pan, marquee }

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.themeSettings,
    required this.initialLineStyle,
    required this.onSettingsChanged,
  });
  final AppThemeSettings themeSettings;
  final RelationLineStyle initialLineStyle;
  final void Function(AppThemeSettings, RelationLineStyle) onSettingsChanged;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final c = ErdController();
  final text = DbmlTextController(text: kSample);
  final vScroll = ScrollController();
  final editorFocus = FocusNode();
  final canvasFocus = FocusNode();
  final _searchFocus = FocusNode();
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();

  Timer? _debounce;
  double _editorW = 440, _problemsH = 150, _editorVH = 400;
  bool _problemsOpen = true;
  bool _searchOpen = false;
  bool _replaceOpen = false;
  int _searchMatchIndex = -1;
  late RelationLineStyle _relationLineStyle = widget.initialLineStyle;
  List<DbmlIssue> _shownIssues = const [];

  _Drag _drag = _Drag.none;
  Offset? _mStart;
  Set<String> _mBase = {};
  double _tpScale = 1;
  bool _pointerMoved = false;
  bool _primaryPointerDown = false;
  String? _draggedNoteId;
  Offset? _noteResizeStart;
  Size? _noteResizeInitialSize;
  String? _hoveredNoteId;
  bool _hoveringNoteResize = false;
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
    _searchFocus.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  /// Pushes new problems to the editor (underlines) and the problems panel.
  void _onC() {
    if (identical(c.issues, _shownIssues)) return;
    _shownIssues = c.issues;
    text.issues = c.issues;
    if (mounted) setState(() {});
  }

  ErdPalette get pal {
    final p = widget.themeSettings.resolvedPalette;
    return ErdPalette(
      dark: p.brightness == Brightness.dark,
      bg: p.background,
      grid: p.grid,
      card: p.surface,
      cardAlt: p.surfaceVariant,
      border: p.outline,
      text: p.foreground,
      muted: p.muted,
      edge: p.edge,
      accent: p.accent,
    );
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 250), () => c.update(text.text));
  }

  Future<void> _openSettings() async {
    final selected = await showDialog<EditorSettingsValues>(
      context: context,
      builder: (_) => EditorSettingsDialog(
        lineStyle: _relationLineStyle,
        themeSettings: widget.themeSettings,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _relationLineStyle = selected.lineStyle);
      widget.onSettingsChanged(selected.themeSettings, selected.lineStyle);
    }
  }

  Future<void> _createStickyNote() async {
    final draft = await showDialog<StickyNoteDraftValues>(
      context: context,
      builder: (_) => const StickyNoteDialog(),
    );
    if (!mounted || draft == null) return;
    final center = c.screenToWorld(
      Offset(c.viewport.width / 2, c.viewport.height / 2),
    );
    final note = StickyNoteModel(
      id: c.nextNoteId(),
      text: draft.text,
      color: draft.color,
      fontSize: draft.fontSize,
      size: draft.size,
    );
    c.addNote(note, center - Offset(note.size.width / 2, note.size.height / 2));
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxEditor = math.max(260.0, MediaQuery.of(context).size.width - 340);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karasuno ERD Studio'),
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
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'New sticky note',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _createStickyNote,
          ),
        ],
      ),
      body: Row(children: [
        SizedBox(
          width: _editorW.clamp(240.0, maxEditor).toDouble(),
          child: Column(children: [
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: cs.surfaceContainerLow,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Search and replace (Ctrl/Cmd+F)',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.find_replace_outlined, size: 19),
                    onPressed: _openSearch,
                  ),
                  IconButton(
                    tooltip: 'Duplicate line (Ctrl/Cmd+D)',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.content_copy_outlined, size: 19),
                    onPressed: _duplicateLine,
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (_, cons) {
                _editorVH = cons.maxHeight;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CodeEditor(
                        controller: text,
                        onChanged: _changed,
                        vScroll: vScroll,
                        focusNode: editorFocus,
                        onSearch: _openSearch,
                        onDuplicateLine: _duplicateLine,
                      ),
                    ),
                    if (_searchOpen)
                      Positioned(
                        top: 4,
                        right: 6,
                        child: _searchBar(cs),
                      ),
                  ],
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

  Future<void> _openSearch() async {
    if (!_searchOpen) {
      final selection = text.selection;
      if (selection.isValid && !selection.isCollapsed) {
        _searchController.text = text.text.substring(
          selection.start,
          selection.end,
        );
      }
    }
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      }
    });
  }

  void _closeSearch() {
    text.setSearchHighlight('', -1);
    setState(() {
      _searchOpen = false;
      _replaceOpen = false;
      _searchMatchIndex = -1;
    });
    editorFocus.requestFocus();
  }

  Widget _searchBar(ColorScheme cs) {
    final query = _searchController.text;
    final matches =
        query.isEmpty ? const <int>[] : _matchOffsets(text.text, query);
    return SizedBox(
      width: 300,
      child: Material(
        color: cs.surfaceContainerHighest,
        elevation: 6,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _closeSearch();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        key: const ValueKey('editor-search-field'),
                        autofocus: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Find',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          suffixText: query.isEmpty
                              ? null
                              : matches.isEmpty
                                  ? 'No results'
                                  : '${_searchMatchIndex + 1}/${matches.length}',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                        ),
                        onChanged: (_) {
                          _searchMatchIndex = -1;
                          _selectNextMatch(
                            _searchController.text,
                            fromStart: true,
                          );
                        },
                        onSubmitted: (_) =>
                            _selectNextMatch(_searchController.text),
                      ),
                    ),
                    _searchIconButton(
                      tooltip: 'Previous match',
                      icon: Icons.keyboard_arrow_up,
                      onPressed: query.isEmpty
                          ? null
                          : () => _selectNextMatch(query, direction: -1),
                    ),
                    _searchIconButton(
                      tooltip: 'Next match',
                      icon: Icons.keyboard_arrow_down,
                      onPressed:
                          query.isEmpty ? null : () => _selectNextMatch(query),
                    ),
                    _searchIconButton(
                      tooltip: 'Toggle replace',
                      icon: Icons.find_replace_outlined,
                      onPressed: () =>
                          setState(() => _replaceOpen = !_replaceOpen),
                    ),
                    _searchIconButton(
                      tooltip: 'Close (Esc)',
                      icon: Icons.close,
                      onPressed: _closeSearch,
                    ),
                  ],
                ),
                if (_replaceOpen)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replaceController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Replace',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: query.isEmpty ? null : _replaceCurrent,
                        child: const Text('Replace'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: query.isEmpty ? null : _replaceAllFromBar,
                        child: const Text('All'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      iconSize: 17,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }

  List<int> _matchOffsets(String source, String query) {
    final offsets = <int>[];
    var offset = 0;
    while (offset <= source.length - query.length) {
      final match = source.indexOf(query, offset);
      if (match < 0) break;
      offsets.add(match);
      offset = match + math.max(1, query.length);
    }
    return offsets;
  }

  void _selectNextMatch(
    String query, {
    int direction = 1,
    bool fromStart = false,
  }) {
    if (query.isEmpty) {
      text.setSearchHighlight('', -1);
      return;
    }
    final matches = _matchOffsets(text.text, query);
    if (matches.isEmpty) {
      text.setSearchHighlight(query, -1);
      return;
    }
    final selectedIndex =
        text.selection.isValid ? matches.indexOf(text.selection.start) : -1;
    if (fromStart) {
      _searchMatchIndex = 0;
    } else if (selectedIndex >= 0) {
      _searchMatchIndex = selectedIndex + direction;
      _searchMatchIndex %= matches.length;
      if (_searchMatchIndex < 0) _searchMatchIndex += matches.length;
    } else if (_searchMatchIndex < 0) {
      _searchMatchIndex = direction > 0 ? 0 : matches.length - 1;
    } else {
      _searchMatchIndex = (_searchMatchIndex + direction) % matches.length;
      if (_searchMatchIndex < 0) _searchMatchIndex += matches.length;
    }
    final offset = matches[_searchMatchIndex];
    text.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + query.length,
    );
    text.setSearchHighlight(query, offset);
    if (mounted) {
      setState(() {});
      _revealSearchMatch(offset);
    }
  }

  void _revealSearchMatch(int offset) {
    if (!vScroll.hasClients) return;
    final line = '\n'.allMatches(text.text.substring(0, offset)).length;
    final target = line * kLineHeight;
    final top = vScroll.offset;
    final bottom = top + _editorVH;
    const padding = 2 * kLineHeight;
    final desired = target < top + padding
        ? target - padding
        : target + kLineHeight > bottom - padding
            ? target - _editorVH + 3 * kLineHeight
            : top;
    final clamped =
        desired.clamp(0.0, vScroll.position.maxScrollExtent).toDouble();
    if ((clamped - vScroll.offset).abs() > 1) {
      vScroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _replaceCurrent() {
    final query = _searchController.text;
    final selection = text.selection;
    if (query.isEmpty ||
        !selection.isValid ||
        selection.textInside(text.text) != query) {
      _selectNextMatch(query);
      return;
    }
    final start = selection.start;
    final updated = text.text.replaceRange(
      start,
      selection.end,
      _replaceController.text,
    );
    final end = start + _replaceController.text.length;
    text.value = TextEditingValue(
      text: updated,
      selection: TextSelection(baseOffset: start, extentOffset: end),
    );
    _changed(updated);
    setState(() {});
  }

  void _replaceAllFromBar() {
    final count = _replaceAll(
      _searchController.text,
      _replaceController.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              count == 0 ? 'No matches found' : 'Replaced $count matches',
            ),
          ),
        );
      setState(() {});
    }
  }

  int _replaceAll(String query, String replacement) {
    if (query.isEmpty) return 0;
    final matches = _matchOffsets(text.text, query);
    if (matches.isEmpty) return 0;
    final updated = text.text.replaceAll(query, replacement);
    text.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
    _changed(updated);
    return matches.length;
  }

  void _duplicateLine() {
    final selection = text.selection;
    if (!selection.isValid ||
        selection.start > selection.end ||
        selection.end > text.text.length) {
      return;
    }
    final lineStart = text.text.lastIndexOf('\n', selection.start - 1) + 1;
    final lineEnd = text.text.indexOf('\n', selection.end);
    final end = lineEnd < 0 ? text.text.length : lineEnd;
    final line = text.text.substring(lineStart, end);
    final insertion = '$line\n';
    final updated = text.text.replaceRange(lineStart, lineStart, insertion);
    final shift = insertion.length;
    text.value = TextEditingValue(
      text: updated,
      selection: TextSelection(
        baseOffset: selection.start + shift,
        extentOffset: selection.end + shift,
      ),
    );
    _changed(updated);
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
        },
        child: Focus(
          focusNode: canvasFocus,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              c.clearSelection();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ClipRect(
            child: Stack(children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: _canvasCursor,
                  onHover: _hoverCanvas,
                  onExit: (_) => _setNoteHover(null, false),
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
                    child: CustomPaint(
                      size: size,
                      painter: ErdPainter(
                        c,
                        pal,
                        relationLineStyle: _relationLineStyle,
                        hoveredNoteId: _hoveredNoteId,
                        activeNoteId: _draggedNoteId,
                      ),
                    ),
                  ),
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
                          .withAlpha(170),
                    ),
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
