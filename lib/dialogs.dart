import 'package:flutter/material.dart';
import 'erd_controller.dart';
import 'export.dart';

// ───────────────────────────── table color ─────────────────────────────

class ColorChoice {
  const ColorChoice.color(Color this.color) : reset = false;
  const ColorChoice.reset()
      : color = null,
        reset = true;
  final Color? color;
  final bool reset;
}

String colorToHex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class ColorDialog extends StatefulWidget {
  const ColorDialog({super.key, required this.count});
  final int count;
  @override
  State<ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<ColorDialog> {
  static const presets = <int>[
    0xFF3B82F6,
    0xFF6366F1,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFFEF4444,
    0xFFF97316,
    0xFFEAB308,
    0xFF22C55E,
    0xFF14B8A6,
    0xFF06B6D4,
    0xFF64748B,
    0xFF78716C,
    0xFF1F2937,
    0xFFA16207,
    0xFF0F766E,
    0xFFBE185D,
  ];
  final hex = TextEditingController();
  Color? picked;

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  Color? _parse(String s) {
    var h = s.trim().replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((e) => '$e$e').join();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.count == 1
          ? 'Table color'
          : 'Color for ${widget.count} tables'),
      content: SizedBox(
        width: 340,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final v in presets)
                  GestureDetector(
                    onTap: () => setState(() {
                      picked = Color(v);
                      hex.text = colorToHex(picked!);
                    }),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(v),
                        shape: BoxShape.circle,
                        border: Border.all(
                            width: picked?.value == v ? 3 : 1,
                            color: picked?.value == v
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.black26),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: hex,
                decoration: InputDecoration(
                  labelText: 'Custom hex color',
                  hintText: '#3B82F6',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                            color: picked ?? Colors.transparent,
                            shape: BoxShape.circle)),
                  ),
                ),
                onChanged: (s) => setState(() => picked = _parse(s)),
              ),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, const ColorChoice.reset()),
            child: const Text('Automatic')),
        FilledButton(
            onPressed: picked == null
                ? null
                : () => Navigator.pop(context, ColorChoice.color(picked!)),
            child: const Text('Apply')),
      ],
    );
  }
}

// ───────────────────────────── export ─────────────────────────────

class ExportOptions {
  const ExportOptions(this.format, this.scale, this.transparent);
  final ExportFormat format;
  final double scale;
  final bool transparent;
}

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key, required this.c});
  final ErdController c;
  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  double scale = 4;
  bool transparent = false;
  ExportFormat format = ExportFormat.png;

  @override
  Widget build(BuildContext context) {
    final sz = widget.c.exportSize(scale);
    return AlertDialog(
      title: const Text('Export diagram'),
      content: SizedBox(
        width: 340,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Format'),
              const SizedBox(height: 8),
              SegmentedButton<ExportFormat>(
                segments: const [
                  ButtonSegment(
                    value: ExportFormat.png,
                    label: Text('PNG'),
                    icon: Icon(Icons.image_outlined),
                  ),
                  ButtonSegment(
                    value: ExportFormat.pdf,
                    label: Text('PDF'),
                    icon: Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
                selected: {format},
                onSelectionChanged: (selected) =>
                    setState(() => format = selected.first),
              ),
              const SizedBox(height: 16),
              const Text('Resolution'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final s in [1.0, 2.0, 4.0, 8.0])
                  ChoiceChip(
                    label: Text('${s.toInt()}x'),
                    selected: scale == s,
                    onSelected: (_) => setState(() => scale = s),
                  ),
              ]),
              const SizedBox(height: 10),
              Text('Image size: ${sz.width.toInt()} × ${sz.height.toInt()} px',
                  style: Theme.of(context).textTheme.bodySmall),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: transparent,
                onChanged: (v) => setState(() => transparent = v ?? false),
                title: const Text('Transparent background'),
              ),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
          icon: const Icon(Icons.save_alt),
          label: const Text('Choose location…'),
          onPressed: () =>
              Navigator.pop(context, ExportOptions(format, scale, transparent)),
        ),
      ],
    );
  }
}
