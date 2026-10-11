enum RelType { manyToOne, oneToMany, oneToOne, manyToMany }

class ColumnModel {
  const ColumnModel({
    required this.name,
    required this.type,
    this.pk = false,
    this.notNull = false,
    this.unique = false,
    this.autoInc = false,
    this.note,
    this.defaultValue,
  });
  final String name, type;
  final bool pk, notNull, unique, autoInc;
  final String? note, defaultValue;
}

class TableModel {
  const TableModel({required this.name, this.alias, this.note, required this.columns});
  final String name;
  final String? alias, note;
  final List<ColumnModel> columns;
}

/// `from` is the left side of the DBML operator, `to` the right side.
/// manyToOne  (>) : from = many, to = one
/// oneToMany  (<) : from = one,  to = many
class RefModel {
  const RefModel({
    required this.fromTable,
    required this.fromColumn,
    required this.toTable,
    required this.toColumn,
    required this.type,
  });
  final String fromTable, fromColumn, toTable, toColumn;
  final RelType type;

  bool get fromMany => type == RelType.manyToOne || type == RelType.manyToMany;
  bool get toMany => type == RelType.oneToMany || type == RelType.manyToMany;
}

class SchemaModel {
  const SchemaModel(this.tables, this.refs);
  final List<TableModel> tables;
  final List<RefModel> refs;
}
