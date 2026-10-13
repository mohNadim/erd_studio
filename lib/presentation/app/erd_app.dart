import 'package:flutter/material.dart';

import '../pages/editor_page.dart';

class ErdApp extends StatefulWidget {
  const ErdApp({super.key});

  @override
  State<ErdApp> createState() => _ErdAppState();
}

class _ErdAppState extends State<ErdApp> {
  ThemeMode mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DBML ERD Studio',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: EditorPage(
          onToggleTheme: () => setState(
            () => mode =
                mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
          ),
        ),
      );
}
