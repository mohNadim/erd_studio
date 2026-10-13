import 'package:flutter/material.dart';
import '../controllers/erd_controller.dart';
import '../canvas/erd_painter.dart';
import '../../application/export/erd_export_service.dart';
import '../app/theme_settings.dart';

// ───────────────────────────── table color ─────────────────────────────

class ColorChoice {
  const ColorChoice.color(Color this.color) : reset = false;
  const ColorChoice.reset()
      : color = null,
        reset = true;
  final Color? color;
  final bool reset;
}

class StickyNoteDraftValues {
  const StickyNoteDraftValues({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.size,
    this.delete = false,
  });

  final String text;
  final int color;
  final double fontSize;
  final Size size;
  final bool delete;
}

class StickyNoteDialog extends StatefulWidget {
  const StickyNoteDialog({
    super.key,
    this.initial,
    this.editing = false,
  });

  final StickyNoteDraftValues? initial;
  final bool editing;

  @override
  State<StickyNoteDialog> createState() => _StickyNoteDialogState();
}

class _StickyNoteDialogState extends State<StickyNoteDialog> {
  late final TextEditingController text;
  late int color;
  late double fontSize;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    text = TextEditingController(text: initial?.text);
    color = initial?.color ?? 0xFFFFF59D;
    fontSize = initial?.fontSize ?? 14;
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.editing ? 'Edit sticky note' : 'New sticky note'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: text,
                autofocus: true,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write a note…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final value in [
                    0xFFFFF59D,
                    0xFFFFCC80,
                    0xFFA5D6A7,
                    0xFF90CAF9,
                    0xFFCE93D8,
                    0xFFFFAB91,
                  ])
                    GestureDetector(
                      onTap: () => setState(() => color = value),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: color == value ? 3 : 1,
                            color: color == value
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.black26,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Font size: ${fontSize.toStringAsFixed(0)}'),
              Slider(
                value: fontSize,
                min: 10,
                max: 28,
                divisions: 18,
                onChanged: (value) => setState(() => fontSize = value),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.editing)
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete sticky note?'),
                    content: const Text(
                      'This action cannot be undone.',
                    ),
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
                if (confirmed == true && mounted) {
                  Navigator.pop(
                    context,
                    StickyNoteDraftValues(
                      text: text.text.trim(),
                      color: color,
                      fontSize: fontSize,
                      size: widget.initial?.size ?? const Size(220, 140),
                      delete: true,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = text.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(
                context,
                StickyNoteDraftValues(
                  text: value,
                  color: color,
                  fontSize: fontSize,
                  size: widget.initial?.size ?? const Size(220, 140),
                ),
              );
            },
            child: Text(widget.editing ? 'Save' : 'Create'),
          ),
        ],
      );
}

class EditorSettingsDialog extends StatelessWidget {
  const EditorSettingsDialog({
    super.key,
    required this.lineStyle,
    required this.themeSettings,
  });

  final RelationLineStyle lineStyle;
  final AppThemeSettings themeSettings;

  @override
  Widget build(BuildContext context) => _SettingsHome(
        lineStyle: lineStyle,
        themeSettings: themeSettings,
      );
}

class EditorSettingsValues {
  const EditorSettingsValues(this.lineStyle, this.themeSettings);

  final RelationLineStyle lineStyle;
  final AppThemeSettings themeSettings;
}

class _SettingsHome extends StatefulWidget {
  const _SettingsHome({
    required this.lineStyle,
    required this.themeSettings,
  });
  final RelationLineStyle lineStyle;
  final AppThemeSettings themeSettings;

  @override
  State<_SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<_SettingsHome> {
  late RelationLineStyle lineStyle = widget.lineStyle;
  late AppThemeSettings themeSettings = widget.themeSettings;

  Future<void> _openTheme() async {
    final result = await showDialog<EditorSettingsValues>(
      context: context,
      builder: (_) => _EditorSettingsDialogContent(
        lineStyle: lineStyle,
        themeSettings: themeSettings,
      ),
    );
    if (result != null) {
      setState(() {
        themeSettings = result.themeSettings;
        lineStyle = result.lineStyle;
      });
    }
  }

  Future<void> _openRelations() async {
    final result = await showDialog<RelationLineStyle>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Relationship lines'),
        content: SegmentedButton<RelationLineStyle>(
          segments: const [
            ButtonSegment(
              value: RelationLineStyle.curved,
              label: Text('Curved'),
              icon: Icon(Icons.timeline),
            ),
            ButtonSegment(
              value: RelationLineStyle.orthogonal,
              label: Text('Orthogonal'),
              icon: Icon(Icons.turn_right),
            ),
          ],
          selected: {lineStyle},
          onSelectionChanged: (value) => Navigator.pop(context, value.first),
        ),
      ),
    );
    if (result != null) setState(() => lineStyle = result);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Settings'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                subtitle: Text(themeSettings.preset.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openTheme,
              ),
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Relationship lines'),
                subtitle: Text(lineStyle == RelationLineStyle.curved
                    ? 'Curved'
                    : 'Orthogonal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openRelations,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              EditorSettingsValues(lineStyle, themeSettings),
            ),
            child: const Text('Done'),
          ),
        ],
      );
}

class _EditorSettingsDialogContent extends StatefulWidget {
  const _EditorSettingsDialogContent({
    required this.lineStyle,
    required this.themeSettings,
  });

  final RelationLineStyle lineStyle;
  final AppThemeSettings themeSettings;

  @override
  State<_EditorSettingsDialogContent> createState() =>
      _EditorSettingsDialogContentState();
}

class _EditorSettingsDialogContentState
    extends State<_EditorSettingsDialogContent> {
  late RelationLineStyle lineStyle = widget.lineStyle;
  late AppThemeSettings themeSettings = widget.themeSettings;

  void _selectPreset(AppThemePreset preset) {
    setState(() => themeSettings =
        AppThemeSettings(preset: preset, palette: palettes[preset]));
  }

  Future<void> _editColor(
      String label, Color current, void Function(Color) onChanged) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _ThemeColorDialog(label: label, initial: current),
    );
    if (color != null) setState(() => onChanged(color));
  }

  @override
  Widget build(BuildContext context) {
    final p = themeSettings.resolvedPalette;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Row(children: [
        const Expanded(child: Text('Settings')),
        IconButton(
          tooltip: 'Reset theme',
          icon: const Icon(Icons.restart_alt),
          onPressed: () => setState(() => themeSettings =
              AppThemeSettings(preset: AppThemePreset.defaultTheme)),
        ),
      ]),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme gallery',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.25,
                children: [
                  for (final preset in AppThemePreset.values)
                    _ThemeCard(
                      preset: preset,
                      palette: palettes[preset]!,
                      selected: themeSettings.preset == preset &&
                          themeSettings.palette == palettes[preset],
                      onTap: () => _selectPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Customize every visual layer',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ColorField(
                      'Background',
                      p.background,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(background: c))),
                  _ColorField(
                      'Panels',
                      p.surface,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(surface: c))),
                  _ColorField(
                      'Panel variants',
                      p.surfaceVariant,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(surfaceVariant: c))),
                  _ColorField(
                      'Borders',
                      p.outline,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(outline: c))),
                  _ColorField(
                      'Text',
                      p.foreground,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(foreground: c))),
                  _ColorField(
                      'Secondary text',
                      p.muted,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(muted: c))),
                  _ColorField(
                      'Grid',
                      p.grid,
                      (c) => themeSettings =
                          themeSettings.copyWith(palette: p.copyWith(grid: c))),
                  _ColorField(
                      'Relations',
                      p.edge,
                      (c) => themeSettings =
                          themeSettings.copyWith(palette: p.copyWith(edge: c))),
                  _ColorField(
                      'Accent',
                      p.accent,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(accent: c))),
                  _ColorField(
                      'Comments',
                      p.syntax.comment,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(
                              syntax: p.syntax.copyWith(comment: c)))),
                  _ColorField(
                      'Strings',
                      p.syntax.string,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(
                              syntax: p.syntax.copyWith(string: c)))),
                  _ColorField(
                      'Keywords',
                      p.syntax.keyword,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(
                              syntax: p.syntax.copyWith(keyword: c)))),
                  _ColorField(
                      'Types',
                      p.syntax.type,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette:
                              p.copyWith(syntax: p.syntax.copyWith(type: c)))),
                  _ColorField(
                      'Settings',
                      p.syntax.setting,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(
                              syntax: p.syntax.copyWith(setting: c)))),
                  _ColorField(
                      'Numbers',
                      p.syntax.number,
                      (c) => themeSettings = themeSettings.copyWith(
                          palette: p.copyWith(
                              syntax: p.syntax.copyWith(number: c)))),
                ].map((field) {
                  return InkWell(
                    onTap: () => _editColor(field.label, field.color,
                        (color) => field.onChanged(color)),
                    borderRadius: BorderRadius.circular(8),
                    child: field,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            EditorSettingsValues(lineStyle, themeSettings),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField(this.label, this.color, this.onChanged);
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            const Icon(Icons.edit_outlined, size: 16),
          ]),
        ),
      );
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.preset,
    required this.palette,
    required this.selected,
    required this.onTap,
  });
  final AppThemePreset preset;
  final AppThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? palette.accent : palette.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Icon(preset.icon, color: palette.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(preset.label,
                  style: TextStyle(
                      color: palette.foreground, fontWeight: FontWeight.w600)),
            ),
            Container(width: 12, height: 12, color: palette.accent),
            const SizedBox(width: 4),
            Container(width: 12, height: 12, color: palette.edge),
          ]),
        ),
      );
}

class _ThemeColorDialog extends StatefulWidget {
  const _ThemeColorDialog({required this.label, required this.initial});
  final String label;
  final Color initial;

  @override
  State<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<_ThemeColorDialog> {
  late HSVColor color = HSVColor.fromColor(widget.initial);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.label),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: color.toColor(),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            _hueSlider(),
            _valueSlider(),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, color.toColor()),
              child: const Text('Apply')),
        ],
      );

  Widget _hueSlider() => Slider(
        value: color.hue,
        min: 0,
        max: 360,
        label: 'Hue',
        activeColor: color.toColor(),
        onChanged: (value) => setState(() => color = color.withHue(value)),
      );

  Widget _valueSlider() => Slider(
        value: color.value,
        label: 'Brightness',
        onChanged: (value) => setState(() => color = color.withValue(value)),
      );
}

String colorToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

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
                            width: picked?.toARGB32() == v ? 3 : 1,
                            color: picked?.toARGB32() == v
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
