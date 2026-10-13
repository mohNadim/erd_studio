import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/parsing/dbml_service.dart';
import '../../domain/entities/dbml_issue.dart';
import '../../domain/entities/schema_models.dart';
import '../../domain/repositories/dbml_parser.dart';
import '../../domain/services/erd_layout_service.dart';

part 'erd_controller_parsing.dart';
part 'erd_controller_geometry.dart';
part 'erd_controller_view.dart';
part 'erd_controller_selection.dart';

abstract class _ErdControllerBase extends ChangeNotifier {
  _ErdControllerBase({DbmlBackend? backend})
      : backend = backend ?? DbmlParserPackageBackend();

  final DbmlBackend backend;
  SchemaModel schema = const SchemaModel([], []);
  final Map<String, TableModel> byName = {};
  final Map<String, Offset> pos = {};
  final Map<String, Size> sizes = {};
  final List<StickyNoteModel> notes = [];
  final Map<String, Offset> notePos = {};
  int _nextNoteId = 1;
  List<DbmlIssue> issues = const [];

  final Set<String> selection = {};
  Rect? marquee;

  double scale = 1;
  Offset pan = Offset.zero;
  Size viewport = Size.zero;
  bool needsFit = true;

  Rect bounds();
  Rect? tableRect(String name);
  void fit();

  void addNote(StickyNoteModel note, Offset position) {
    notes.add(note);
    notePos[note.id] = position;
    notifyListeners();
  }

  void moveNote(String id, Offset delta) {
    final position = notePos[id];
    if (position == null) return;
    notePos[id] = position + delta;
    notifyListeners();
  }

  void resizeNote(String id, Size size) {
    final note = notes.where((item) => item.id == id).firstOrNull;
    if (note == null) return;
    note.size = size;
    notifyListeners();
  }

  void updateNote(
    String id, {
    required String text,
    required int color,
    required double fontSize,
    required Size size,
  }) {
    final note = notes.where((item) => item.id == id).firstOrNull;
    if (note == null) return;
    note
      ..text = text
      ..color = color
      ..fontSize = fontSize
      ..size = size;
    notifyListeners();
  }

  void deleteNote(String id) {
    notes.removeWhere((note) => note.id == id);
    notePos.remove(id);
    notifyListeners();
  }

  String nextNoteId() => 'note-${_nextNoteId++}';
}

class ErdController extends _ErdControllerBase
    with
        _ErdControllerParsing,
        _ErdControllerGeometry,
        _ErdControllerView,
        _ErdControllerSelection {
  ErdController({super.backend});
}
