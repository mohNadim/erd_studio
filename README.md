# DBML ERD Studio

Open-source desktop ERD designer (Flutter). Write DBML on the left, get a diagram on the right.

## Run
```bash
flutter create --platforms=windows,linux,macos --project-name dbml_erd_studio .
flutter pub get
flutter run -d windows   # or linux / macos
```
macOS: add `com.apple.security.files.user-selected.read-write` (true) to
`macos/Runner/DebugProfile.entitlements` and `Release.entitlements` for open/save dialogs.

## Features
- Code editor: line numbers, DBML syntax colors, thin red wavy underline under errors, resizable (drag the divider)
- Problems panel: lists *all* errors (click to jump), closable and resizable
- Diagram: centered on start, drag tables (1:1 with the mouse), wheel/trackpad zoom, auto layout, fit
- Multi-select: Ctrl/Shift+click, Shift+drag box, Ctrl+A - then drag any selected table to move them all
- Per-table colors (toolbar palette or right-click); saved in the DBML as `[headercolor: #rrggbb]`
- PNG export dialog (1x-8x, transparent option) with a Save dialog
- Open/save `.dbml`, light/dark theme

## Parser
Parsing is done by the [`dbml_parser`](https://pub.dev/packages/dbml_parser) package, wrapped by
`DbmlParserPackageBackend` in `lib/data/parsing/dbml_service.dart` (AST -> `SchemaModel`).
A lenient built-in parser (`BuiltInDbmlBackend`) is kept as an optional fallback:
`ErdController(backend: BuiltInDbmlBackend())`.

## Architecture
The Flutter code follows a feature-oriented Clean Architecture layout:

- `lib/domain`: framework-independent schema entities, parser contracts, and DBML/layout services.
- `lib/data`: concrete DBML parser integrations and external package adapters.
- `lib/application`: application-level export orchestration.
- `lib/presentation`: app composition, pages, widgets, canvas rendering, and controllers.
  The editor page is split into file actions, canvas interaction, and problems-view
  responsibilities under `lib/presentation/pages/`.
  `ErdController` is split into parsing, geometry, viewport, and selection mixins under
  `lib/presentation/controllers/`.
- `lib/main.dart`: platform entry point only.

Presentation code depends on domain contracts and application services; parser package
details remain inside `lib/data`.

## License
MIT
