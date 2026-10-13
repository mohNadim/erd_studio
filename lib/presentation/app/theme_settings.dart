import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreset {
  defaultTheme('Default', Icons.auto_awesome),
  vscodeDark('VS Code Dark+', Icons.code),
  dracula('Dracula', Icons.nightlight_round),
  monokai('Monokai', Icons.terminal),
  nord('Nord', Icons.ac_unit),
  githubDark('GitHub Dark', Icons.dark_mode);

  const AppThemePreset(this.label, this.icon);
  final String label;
  final IconData icon;
}

class DbmlSyntaxColors {
  const DbmlSyntaxColors(this.comment, this.string, this.keyword, this.type,
      this.setting, this.number, this.op, this.color);
  final Color comment, string, keyword, type, setting, number, op, color;

  DbmlSyntaxColors copyWith({
    Color? comment,
    Color? string,
    Color? keyword,
    Color? type,
    Color? setting,
    Color? number,
    Color? op,
    Color? color,
  }) =>
      DbmlSyntaxColors(
        comment ?? this.comment,
        string ?? this.string,
        keyword ?? this.keyword,
        type ?? this.type,
        setting ?? this.setting,
        number ?? this.number,
        op ?? this.op,
        color ?? this.color,
      );
}

class DbmlEditorTheme extends ThemeExtension<DbmlEditorTheme> {
  const DbmlEditorTheme(this.syntax);
  final DbmlSyntaxColors syntax;

  @override
  DbmlEditorTheme copyWith({DbmlSyntaxColors? syntax}) =>
      DbmlEditorTheme(syntax ?? this.syntax);

  @override
  DbmlEditorTheme lerp(ThemeExtension<DbmlEditorTheme>? other, double t) =>
      this;
}

class AppThemePalette {
  const AppThemePalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.foreground,
    required this.muted,
    required this.grid,
    required this.edge,
    required this.accent,
    required this.syntax,
    required this.brightness,
  });
  final Color background, surface, surfaceVariant, outline;
  final Color foreground, muted, grid, edge, accent;
  final DbmlSyntaxColors syntax;
  final Brightness brightness;

  AppThemePalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? outline,
    Color? foreground,
    Color? muted,
    Color? grid,
    Color? edge,
    Color? accent,
    DbmlSyntaxColors? syntax,
    Brightness? brightness,
  }) =>
      AppThemePalette(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        outline: outline ?? this.outline,
        foreground: foreground ?? this.foreground,
        muted: muted ?? this.muted,
        grid: grid ?? this.grid,
        edge: edge ?? this.edge,
        accent: accent ?? this.accent,
        syntax: syntax ?? this.syntax,
        brightness: brightness ?? this.brightness,
      );
}

class AppThemeSettings {
  const AppThemeSettings({
    this.preset = AppThemePreset.defaultTheme,
    this.palette,
  });
  final AppThemePreset preset;
  final AppThemePalette? palette;
  AppThemePalette get resolvedPalette => palette ?? palettes[preset]!;

  AppThemeSettings copyWith({
    AppThemePreset? preset,
    AppThemePalette? palette,
    bool resetPalette = false,
  }) =>
      AppThemeSettings(
        preset: preset ?? this.preset,
        palette: resetPalette ? null : (palette ?? this.palette),
      );

  static AppThemeSettings load(SharedPreferences prefs) {
    final name = prefs.getString('theme.preset');
    final preset = AppThemePreset.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AppThemePreset.defaultTheme,
    );
    final ints = prefs.getStringList('theme.palette');
    if (ints == null || ints.length != 15) {
      return AppThemeSettings(preset: preset);
    }
    final base = palettes[preset]!;
    final values = ints.map((v) => int.tryParse(v)).toList();
    if (values.any((v) => v == null)) return AppThemeSettings(preset: preset);
    return AppThemeSettings(
      preset: preset,
      palette: base.copyWith(
        background: Color(values[0]!),
        surface: Color(values[1]!),
        surfaceVariant: Color(values[2]!),
        outline: Color(values[3]!),
        foreground: Color(values[4]!),
        muted: Color(values[5]!),
        grid: Color(values[6]!),
        edge: Color(values[7]!),
        accent: Color(values[8]!),
        syntax: base.syntax.copyWith(
          comment: Color(values[9]!),
          string: Color(values[10]!),
          keyword: Color(values[11]!),
          type: Color(values[12]!),
          setting: Color(values[13]!),
          number: Color(values[14]!),
        ),
        brightness: prefs.getBool('theme.dark') == true
            ? Brightness.dark
            : Brightness.light,
      ),
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    final p = resolvedPalette;
    await prefs.setString('theme.preset', preset.name);
    await prefs.setStringList('theme.palette', [
      for (final c in [
        p.background,
        p.surface,
        p.surfaceVariant,
        p.outline,
        p.foreground,
        p.muted,
        p.grid,
        p.edge,
        p.accent,
        p.syntax.comment,
        p.syntax.string,
        p.syntax.keyword,
        p.syntax.type,
        p.syntax.setting,
        p.syntax.number,
      ])
        c.toARGB32().toString(),
    ]);
    await prefs.setBool('theme.dark', p.brightness == Brightness.dark);
  }
}

const palettes = <AppThemePreset, AppThemePalette>{
  AppThemePreset.defaultTheme: AppThemePalette(
    background: Color(0xFF14161F),
    surface: Color(0xFF1E2230),
    surfaceVariant: Color(0xFF232838),
    outline: Color(0xFF383E54),
    foreground: Color(0xFFE6E8F2),
    muted: Color(0xFF8F96B0),
    grid: Color(0xFF2A2F40),
    edge: Color(0xFF8F96B0),
    accent: Color(0xFFFFA94D),
    syntax: DbmlSyntaxColors(
        Color(0xFF7F8AA3),
        Color(0xFFC3E88D),
        Color(0xFFC792EA),
        Color(0xFF82AAFF),
        Color(0xFFF78C6C),
        Color(0xFFFFCB6B),
        Color(0xFF89DDFF),
        Color(0xFFFFCB6B)),
    brightness: Brightness.dark,
  ),
  AppThemePreset.vscodeDark: AppThemePalette(
    background: Color(0xFF1E1E1E),
    surface: Color(0xFF252526),
    surfaceVariant: Color(0xFF333333),
    outline: Color(0xFF454545),
    foreground: Color(0xFFD4D4D4),
    muted: Color(0xFF858585),
    grid: Color(0xFF2D2D30),
    edge: Color(0xFF808080),
    accent: Color(0xFF007ACC),
    syntax: DbmlSyntaxColors(
        Color(0xFF6A9955),
        Color(0xFFCE9178),
        Color(0xFFC586C0),
        Color(0xFF4EC9B0),
        Color(0xFF9CDCFE),
        Color(0xFFB5CEA8),
        Color(0xFFD4D4D4),
        Color(0xFFDCDCAA)),
    brightness: Brightness.dark,
  ),
  AppThemePreset.dracula: AppThemePalette(
    background: Color(0xFF282A36),
    surface: Color(0xFF44475A),
    surfaceVariant: Color(0xFF6272A4),
    outline: Color(0xFF6272A4),
    foreground: Color(0xFFF8F8F2),
    muted: Color(0xFFBFBFBF),
    grid: Color(0xFF343746),
    edge: Color(0xFFFF79C6),
    accent: Color(0xFFBD93F9),
    syntax: DbmlSyntaxColors(
        Color(0xFF6272A4),
        Color(0xFFF1FA8C),
        Color(0xFFFF79C6),
        Color(0xFF8BE9FD),
        Color(0xFFFFB86C),
        Color(0xFFBD93F9),
        Color(0xFFF8F8F2),
        Color(0xFFF1FA8C)),
    brightness: Brightness.dark,
  ),
  AppThemePreset.monokai: AppThemePalette(
    background: Color(0xFF272822),
    surface: Color(0xFF3E3D32),
    surfaceVariant: Color(0xFF49483E),
    outline: Color(0xFF75715E),
    foreground: Color(0xFFF8F8F2),
    muted: Color(0xFFA6A6A0),
    grid: Color(0xFF3A3B32),
    edge: Color(0xFFF92672),
    accent: Color(0xFFA6E22E),
    syntax: DbmlSyntaxColors(
        Color(0xFF75715E),
        Color(0xFFE6DB74),
        Color(0xFFF92672),
        Color(0xFF66D9EF),
        Color(0xFFFD971F),
        Color(0xFFAE81FF),
        Color(0xFFF8F8F2),
        Color(0xFFE6DB74)),
    brightness: Brightness.dark,
  ),
  AppThemePreset.nord: AppThemePalette(
    background: Color(0xFF2E3440),
    surface: Color(0xFF3B4252),
    surfaceVariant: Color(0xFF434C5E),
    outline: Color(0xFF4C566A),
    foreground: Color(0xFFECEFF4),
    muted: Color(0xFFD8DEE9),
    grid: Color(0xFF3B4252),
    edge: Color(0xFF88C0D0),
    accent: Color(0xFF81A1C1),
    syntax: DbmlSyntaxColors(
        Color(0xFF616E88),
        Color(0xFFA3BE8C),
        Color(0xFFB48EAD),
        Color(0xFF8FBCBB),
        Color(0xFFD08770),
        Color(0xFFB48EAD),
        Color(0xFFEBCB8B),
        Color(0xFFEBCB8B)),
    brightness: Brightness.dark,
  ),
  AppThemePreset.githubDark: AppThemePalette(
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surfaceVariant: Color(0xFF21262D),
    outline: Color(0xFF30363D),
    foreground: Color(0xFFF0F6FC),
    muted: Color(0xFF8B949E),
    grid: Color(0xFF21262D),
    edge: Color(0xFF58A6FF),
    accent: Color(0xFFF78166),
    syntax: DbmlSyntaxColors(
        Color(0xFF8B949E),
        Color(0xFFA5D6FF),
        Color(0xFFFF7B72),
        Color(0xFF79C0FF),
        Color(0xFFD2A8FF),
        Color(0xFF79C0FF),
        Color(0xFFFFA657),
        Color(0xFFFFA657)),
    brightness: Brightness.dark,
  ),
};
