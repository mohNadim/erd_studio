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
}

class ErdController extends _ErdControllerBase
    with
        _ErdControllerParsing,
        _ErdControllerGeometry,
        _ErdControllerView,
        _ErdControllerSelection {
  ErdController({super.backend});
}
