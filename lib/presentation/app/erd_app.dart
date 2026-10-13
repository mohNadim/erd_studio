import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/editor_page.dart';
import '../canvas/erd_painter.dart';
import 'theme_settings.dart';

class ErdApp extends StatefulWidget {
  const ErdApp({super.key, this.preferences});
  final SharedPreferences? preferences;

  @override
  State<ErdApp> createState() => _ErdAppState();
}

class _ErdAppState extends State<ErdApp> {
  late AppThemeSettings themeSettings = widget.preferences == null
      ? const AppThemeSettings()
      : AppThemeSettings.load(widget.preferences!);
  late RelationLineStyle relationLineStyle = RelationLineStyle
      .values[widget.preferences?.getInt('relation.lineStyle') ?? 0];

  Future<void> _updateSettings(
      AppThemeSettings settings, RelationLineStyle lineStyle) async {
    setState(() {
      themeSettings = settings;
      relationLineStyle = lineStyle;
    });
    if (widget.preferences != null) {
      try {
        await themeSettings.save(widget.preferences!);
        await widget.preferences!
            .setInt('relation.lineStyle', lineStyle.index);
      } on PlatformException catch (error, stackTrace) {
        debugPrint('Preferences could not be saved: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DBML ERD Studio',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(themeSettings.resolvedPalette),
        home: EditorPage(
          themeSettings: themeSettings,
          initialLineStyle: relationLineStyle,
          onSettingsChanged: _updateSettings,
        ),
      );

  ThemeData _buildTheme(AppThemePalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: p.brightness == Brightness.dark ? Colors.black : Colors.white,
      secondary: p.edge,
      onSecondary:
          p.brightness == Brightness.dark ? Colors.black : Colors.white,
      error: const Color(0xFFE06C75),
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.foreground,
      outline: p.outline,
      surfaceContainerHighest: p.surfaceVariant,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      useMaterial3: true,
      brightness: p.brightness,
      extensions: [DbmlEditorTheme(p.syntax)],
    );
  }
}
