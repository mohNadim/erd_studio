part of 'editor_page.dart';

extension _EditorFileActions on _EditorPageState {
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  String _downloads(String name) {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    final dir = Directory('$home${Platform.pathSeparator}Downloads');
    return '${dir.existsSync() ? dir.path : home}${Platform.pathSeparator}$name';
  }

  Future<void> _open() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dbml', 'txt'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final source = await File(path).readAsString();
      text.text = source;
      c.pos.clear();
      c.needsFit = true;
      c.update(source);
    } catch (error) {
      _toast('Could not open file: $error');
    }
  }

  Future<void> _saveDbml() async {
    try {
      var path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save DBML',
        fileName: 'schema.dbml',
        type: FileType.custom,
        allowedExtensions: ['dbml'],
      );
      if (path == null) return;
      if (!path.toLowerCase().endsWith('.dbml')) path = '$path.dbml';
      await File(path).writeAsString(text.text);
      _toast('Saved → $path');
    } catch (error) {
      _toast('Could not save: $error');
    }
  }

  Future<void> _export() async {
    if (c.schema.tables.isEmpty) {
      _toast('Nothing to export yet — the diagram is empty.');
      return;
    }
    final palette = pal;
    final options = await showDialog<ExportOptions>(
      context: context,
      builder: (_) => ExportDialog(c: c),
    );
    if (options == null) return;

    final extension = options.format == ExportFormat.pdf ? 'pdf' : 'png';
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export diagram',
        fileName: 'erd.$extension',
        type: FileType.custom,
        allowedExtensions: [extension],
      );
    } catch (error) {
      path = _downloads('erd.$extension');
      _toast('Save dialog unavailable ($error). Saving to $path');
    }
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.$extension')) {
      path = '$path.$extension';
    }

    try {
      final bytes = options.format == ExportFormat.pdf
          ? await renderErdPdf(
              c,
              palette,
              scale: options.scale,
              transparent: options.transparent,
            )
          : await renderErdPng(
              c,
              palette,
              scale: options.scale,
              transparent: options.transparent,
            );
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      _toast('Exported → $path');
    } catch (error) {
      _toast('Export failed: $error');
    }
  }

  Future<void> _pickColor() async {
    if (c.selection.isEmpty) return;
    final result = await showDialog<ColorChoice>(
      context: context,
      builder: (_) => ColorDialog(count: c.selection.length),
    );
    if (result == null) return;

    final source = setTableHeaderColor(
      text.text,
      Set.of(c.selection),
      result.reset ? null : colorToHex(result.color!),
    );
    final offset = text.selection.isValid
        ? math.min(text.selection.baseOffset, source.length)
        : 0;
    text.value = TextEditingValue(
      text: source,
      selection: TextSelection.collapsed(offset: math.max(0, offset)),
    );
    c.update(source);
  }

  Future<void> _tableMenu(Offset global) async {
    final size = MediaQuery.of(context).size;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(global.dx, global.dy, 0, 0),
        Offset.zero & size,
      ),
      items: [
        PopupMenuItem(
          value: 'color',
          child: Text(
            c.selection.length > 1
                ? 'Change color of ${c.selection.length} tables…'
                : 'Change color…',
          ),
        ),
        const PopupMenuItem(
          value: 'all',
          child: Text('Select all tables'),
        ),
      ],
    );
    if (value == 'color') _pickColor();
    if (value == 'all') c.selectAll();
  }
}
