import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'erd_controller.dart';
import 'erd_painter.dart';
import 'export.dart';

const kSample = r'''
Table users {
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

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final c = ErdController();
  final text = TextEditingController(text: kSample);
  final tc = TransformationController();
  Timer? _debounce;
  Size _vp = Size.zero;
  String? _dragging;

  @override
  void initState() {
    super.initState();
    c.update(text.text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    c.dispose();
    text.dispose();
    tc.dispose();
    super.dispose();
  }

  ErdPalette get pal =>
      Theme.of(context).brightness == Brightness.dark ? ErdPalette.darkPal : ErdPalette.light;

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => c.update(text.text));
  }

  void _fit() {
    final b = c.bounds().inflate(48);
    if (b.isEmpty || _vp.isEmpty) return;
    final s = min(_vp.width / b.width, _vp.height / b.height).clamp(0.1, 1.5).toDouble();
    final tx = -b.left * s + (_vp.width - b.width * s) / 2;
    final ty = -b.top * s + (_vp.height - b.height * s) / 2;
    tc.value = Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _open() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['dbml', 'txt']);
    final path = r?.files.single.path;
    if (path == null) return;
    text.text = await File(path).readAsString();
    c.pos.clear();
    c.update(text.text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  Future<String?> _savePath(String name, String ext) async {
    var p = await FilePicker.platform.saveFile(
        fileName: name, type: FileType.custom, allowedExtensions: [ext]);
    if (p != null && !p.toLowerCase().endsWith('.$ext')) p = '$p.$ext';
    return p;
  }

  Future<void> _saveDbml() async {
    final p = await _savePath('schema.dbml', 'dbml');
    if (p == null) return;
    await File(p).writeAsString(text.text);
    _toast('Saved $p');
  }

  Future<void> _exportPng(double scale, {bool transparent = false}) async {
    if (c.schema.tables.isEmpty) return;
    final p = await _savePath('erd.png', 'png');
    if (p == null) return;
    final bytes = await renderErdPng(c, pal, scale: scale, transparent: transparent);
    await File(p).writeAsBytes(bytes);
    _toast('Exported $p');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DBML ERD Studio'),
        actions: [
          IconButton(tooltip: 'Open .dbml', icon: const Icon(Icons.folder_open), onPressed: _open),
          IconButton(tooltip: 'Save .dbml', icon: const Icon(Icons.save_outlined), onPressed: _saveDbml),
          PopupMenuButton<(double, bool)>(
            tooltip: 'Export PNG',
            icon: const Icon(Icons.image_outlined),
            onSelected: (v) => _exportPng(v.$1, transparent: v.$2),
            itemBuilder: (_) => const [
              PopupMenuItem(value: (2.0, false), child: Text('PNG  2x')),
              PopupMenuItem(value: (4.0, false), child: Text('PNG  4x (print quality)')),
              PopupMenuItem(value: (8.0, false), child: Text('PNG  8x (poster)')),
              PopupMenuItem(value: (4.0, true), child: Text('PNG  4x, transparent')),
            ],
          ),
          IconButton(
              tooltip: 'Auto layout',
              icon: const Icon(Icons.auto_awesome_mosaic_outlined),
              onPressed: () {
                c.relayout();
                _fit();
              }),
          IconButton(tooltip: 'Fit to screen', icon: const Icon(Icons.fit_screen), onPressed: _fit),
          IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleTheme),
        ],
      ),
      body: Row(children: [
        SizedBox(
          width: 400,
          child: Column(children: [
            Expanded(
              child: TextField(
                controller: text,
                onChanged: _changed,
                expands: true,
                maxLines: null,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
                decoration: const InputDecoration(
                    border: InputBorder.none, contentPadding: EdgeInsets.all(14)),
              ),
            ),
            ListenableBuilder(
              listenable: c,
              builder: (_, __) => c.error == null
                  ? const SizedBox.shrink()
                  : Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.all(10),
                      child: Text(c.error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    ),
            ),
          ]),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: LayoutBuilder(builder: (_, cons) {
            _vp = cons.biggest;
            return ClipRect(
              child: ListenableBuilder(
                listenable: c,
                builder: (_, __) {
                  final b = c.bounds();
                  final size = Size(max(_vp.width, b.right + 800), max(_vp.height, b.bottom + 800));
                  return InteractiveViewer(
                    transformationController: tc,
                    constrained: false,
                    panEnabled: _dragging == null,
                    minScale: 0.1,
                    maxScale: 4,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: Listener(
                      onPointerDown: (e) {
                        final n = c.hit(e.localPosition);
                        c.select(n);
                        if (n != null) setState(() => _dragging = n);
                      },
                      onPointerMove: (e) {
                        if (_dragging != null) c.move(_dragging!, e.delta);
                      },
                      onPointerUp: (_) => setState(() => _dragging = null),
                      onPointerCancel: (_) => setState(() => _dragging = null),
                      child: CustomPaint(size: size, painter: ErdPainter(c, pal)),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ]),
    );
  }
}
