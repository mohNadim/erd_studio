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
- Live DBML editing with error reporting
- Tables, PK/FK/UQ badges, crow's-foot relations (`>`, `<`, `-`, `<>`), inline `ref:`
- Drag tables, pan/zoom, auto layout, fit to screen, light/dark
- PNG export up to 8x (independent of zoom), optional transparent background
- Open/save `.dbml`

## Parser
Parsing is done by the [`dbml_parser`](https://pub.dev/packages/dbml_parser) package, wrapped by
`DbmlParserPackageBackend` in `lib/dbml_service.dart` (AST -> `SchemaModel`).
A lenient built-in parser (`BuiltInDbmlBackend`) is kept as an optional fallback:
`ErdController(backend: BuiltInDbmlBackend())`.

## License
MIT
