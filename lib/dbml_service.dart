import 'package:dbml_parser/dbml_parser.dart' as dbml;

import 'models.dart';

/// One problem found in the source. [line] and [column] are 1-based; 0 = unknown.
class DbmlIssue {
  const DbmlIssue(this.line, this.column, this.message);
  final int line, column;
  final String message;
}

class DbmlParseException implements Exception {
  /// [line] is 0-based (convention of the built-in parser).
  DbmlParseException(String message, [int? line])
      : issues = [DbmlIssue((line ?? -1) + 1, 0, message)];
  DbmlParseException.multi(this.issues);
  final List<DbmlIssue> issues;
  String get message => issues.first.message;
  @override
  String toString() => issues
      .map((i) => i.line > 0 ? 'Line ${i.line}:${i.column} — ${i.message}' : i.message)
      .join('\n');
}

/// The only place the app talks to a DBML parser.
abstract class DbmlBackend {
  SchemaModel parse(String source);
}

/// Uses the `dbml_parser` package (https://pub.dev/packages/dbml_parser).
/// Converts its AST (`DbmlDocument`) into the app's own `SchemaModel`.
class DbmlParserPackageBackend implements DbmlBackend {
  @override
  SchemaModel parse(String source) {
    final text = _normalize(source);
    final dbml.DbmlDocument doc;
    try {
      doc = dbml.parseDbml(text);
    } on dbml.ParseError catch (e) {
      throw _recover(text, _issue(e.line, e.column, e.message));
    } on dbml.LexError catch (e) {
      throw _recover(text, _issue(e.line, e.column, e.message));
    }
    return _toSchema(doc);
  }

  SchemaModel _toSchema(dbml.DbmlDocument doc) {
    final tables = <TableModel>[];
    // lookup (full name, short name, alias) -> canonical table name
    final lookup = <String, String>{};
    for (final t in doc.tables) {
      final key = t.fullName;
      tables.add(TableModel(
        name: key,
        alias: t.alias,
        note: t.note,
        headerColor: _hex(t.headerColor),
        columns: [
          for (final c in t.columns)
            ColumnModel(
              name: c.name,
              type: c.formattedType,
              pk: c.isPrimaryKey,
              notNull: c.isNotNull,
              unique: c.isUnique,
              autoInc: c.isIncrement,
              note: c.note,
              defaultValue: c.defaultValue,
            ),
        ],
      ));
      lookup[key] = key;
      lookup.putIfAbsent(t.name, () => key);
      if (t.alias != null) lookup[t.alias!] = key;
    }

    final refs = <RefModel>[];
    void add(String fromTable, String fromCol, dbml.RefEndpoint to,
        dbml.RefCardinality card) {
      final a = lookup[fromTable] ?? lookup[fromTable.split('.').last];
      final b = lookup[to.fullTable] ?? lookup[to.table];
      if (a == null || b == null || to.columns.isEmpty) return;
      refs.add(RefModel(
        fromTable: a,
        fromColumn: fromCol,
        toTable: b,
        toColumn: to.columns.first, // composite refs: first column is enough to anchor
        type: _card(card),
      ));
    }

    for (final r in doc.refs) {
      if (r.from.columns.isEmpty) continue;
      add(r.from.fullTable, r.from.columns.first, r.to, r.cardinality);
    }
    for (final t in doc.tables) {
      for (final c in t.columns) {
        for (final ir in c.inlineRefs) {
          add(t.fullName, c.name, ir.target, ir.cardinality);
        }
      }
    }
    return SchemaModel(tables, refs);
  }

  // --- positions -----------------------------------------------------------
  // The package may count lines/columns from 0 or 1. Measure once with a
  // known-bad input ("?" at line 2, column 3) so underlines land correctly.
  static ({int line, int col})? _cal;
  static ({int line, int col}) get _adj => _cal ??= _calibrate();
  static ({int line, int col}) _calibrate() {
    try {
      dbml.parseDbml('\n  ?');
    } on dbml.LexError catch (e) {
      return (line: 2 - e.line, col: 3 - e.column);
    } on dbml.ParseError catch (e) {
      return (line: 2 - e.line, col: 3 - e.column);
    } catch (_) {}
    return (line: 0, col: 0);
  }

  DbmlIssue _issue(int line, int col, String msg) =>
      DbmlIssue(line + _adj.line, col + _adj.col, msg);

  // --- multi-error recovery -------------------------------------------------
  // The package stops at the first error. To list *all* of them, split the text
  // into top-level blocks, parse each one on its own (padded with blank lines so
  // line numbers stay true) and collect every failure.
  DbmlParseException _recover(String text, DbmlIssue first) {
    final issues = <DbmlIssue>[];
    for (final ch in _chunks(text)) {
      if (issues.length >= 100) break;
      try {
        dbml.parseDbml('\n' * ch.$1 + ch.$2);
      } on dbml.ParseError catch (e) {
        issues.add(_issue(e.line, e.column, e.message));
      } on dbml.LexError catch (e) {
        issues.add(_issue(e.line, e.column, e.message));
      } catch (_) {}
    }
    return DbmlParseException.multi(issues.isEmpty ? [first] : issues);
  }

  List<(int, String)> _chunks(String text) {
    final lines = text.split('\n');
    final out = <(int, String)>[];
    var i = 0;
    while (i < lines.length) {
      if (_strip(lines[i]).isEmpty) {
        i++;
        continue;
      }
      var j = i, depth = 0, opened = false;
      while (j < lines.length) {
        for (final ch in _strip(lines[j]).codeUnits) {
          if (ch == 123) {
            depth++;
            opened = true;
          } else if (ch == 125) {
            depth--;
          }
        }
        j++;
        if (opened && depth <= 0) break;
        if (!opened) {
          var k = j;
          while (k < lines.length && _strip(lines[k]).isEmpty) {
            k++;
          }
          if (k < lines.length && _strip(lines[k]).startsWith('{')) {
            j = k;
            continue;
          }
          break;
        }
      }
      out.add((i, lines.sublist(i, j).join('\n')));
      i = j;
    }
    return out;
  }

  String _strip(String l) {
    final i = l.indexOf('//');
    return (i >= 0 ? l.substring(0, i) : l).trim();
  }

  int? _hex(String? s) {
    if (s == null) return null;
    var h = s.trim().replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length < 6) return null;
    final v = int.tryParse(h.substring(0, 6), radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }

  // Friendly extensions, rewritten line-by-line (line numbers never shift):
  //   `id uuid pk`            ->  `id uuid [pk]`
  //   `[ref: >? users.id]`    ->  `[ref: > users.id]`   (also `<?`)
  static final _bareFlags = RegExp(
      r'^(\s*(?:"[^"]+"|\w+)\s+[\w\.]+(?:\([^)]*\))?(?:\[\])?)\s+'
      r'((?:(?:pk|primary\s+key|unique|not\s+null|null|increment)\s*)+)$',
      caseSensitive: false);
  static final _flagToken =
      RegExp(r'primary\s+key|not\s+null|\w+', caseSensitive: false);
  static final _optionalOp = RegExp(r'([<>])\?');
  static final _refWord = RegExp(r'\bref\b', caseSensitive: false);

  String _normalize(String src) => src.split('\n').map((line) {
        final m = _bareFlags.firstMatch(line);
        if (m != null) {
          final flags = _flagToken
              .allMatches(m.group(2)!)
              .map((x) => x.group(0)!.toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
              .join(', ');
          return '${m.group(1)} [$flags]';
        }
        if (_refWord.hasMatch(line)) {
          return line.replaceAllMapped(_optionalOp, (x) => x.group(1)!);
        }
        return line;
      }).join('\n');

  RelType _card(dbml.RefCardinality c) => switch (c) {
        dbml.RefCardinality.manyToOne => RelType.manyToOne,
        dbml.RefCardinality.oneToMany => RelType.oneToMany,
        dbml.RefCardinality.oneToOne => RelType.oneToOne,
        dbml.RefCardinality.manyToMany => RelType.manyToMany,
      };
}

/// Optional dependency-free fallback (lenient: accepts `id uuid pk`, `>?`).
/// Covering the common DBML subset:
/// Table (+alias), columns with settings, inline `ref:`, `Ref:` lines/blocks,
/// notes. Enum / indexes / Project / TableGroup blocks are skipped.
class BuiltInDbmlBackend implements DbmlBackend {
  static final _tableHead = RegExp(
      r'^table\s+("[^"]+"|[\w\.]+)(?:\s+as\s+(\w+))?\s*(?:\[[^\]]*\])?\s*\{\s*(\})?\s*$',
      caseSensitive: false);
  // name type [settings] bare-flags   (e.g. `id uuid [pk]` or `id uuid pk`)
  static final _col = RegExp(
      r'^("[^"]+"|\w+)\s+([\w\.]+(?:\([^)]*\))?(?:\[\])?)\s*(?:\[(.*)\])?\s*([\w\s]*)$');
  // operators: >  <  -  <>  and the optional variants >?  <?
  static final _rel = RegExp(
      r'("?[\w\.]+"?)\.("?\w+"?)\s*(<>|>\??|<\??|-)\s*("?[\w\.]+"?)\.("?\w+"?)');
  static final _inlineRef = RegExp(
      r'ref:\s*(<>|>\??|<\??|-)\s*("?[\w\.]+"?)\.("?\w+"?)',
      caseSensitive: false);
  static final _blockHead = RegExp(
      r'^(?:enum|project|tablegroup|note)\b.*\{\s*$',
      caseSensitive: false);
  static const _keywords = ['Table', 'Enum', 'Ref', 'Project', 'TableGroup', 'Note'];

  @override
  SchemaModel parse(String source) {
    final lines = source.split('\n');
    final tables = <TableModel>[];
    final refs = <RefModel>[];
    var i = 0;
    while (i < lines.length) {
      final l = _clean(lines[i]);
      if (l.isEmpty) {
        i++;
        continue;
      }
      final t = _tableHead.firstMatch(l);
      final word = RegExp(r'^\w+').firstMatch(l)?.group(0) ?? '';
      final lw = word.toLowerCase();
      if (t != null) {
        final r = _readTable(lines, i, t, refs);
        tables.add(r.$1);
        i = r.$2;
      } else if (lw == 'ref') {
        i = _readRef(lines, i, refs);
      } else if (_blockHead.hasMatch(l)) {
        i = _skipBlock(lines, i);
      } else if (lw == 'note') {
        i++;
      } else if (l.startsWith('}')) {
        throw DbmlParseException('Unexpected "}" (no open block)', i);
      } else if (_keywords.any((k) => k.toLowerCase() == lw)) {
        throw DbmlParseException(
            'Invalid $word declaration: "$l". Expected e.g. "Table name {"', i);
      } else {
        final hint = _suggest(word);
        throw DbmlParseException(
            hint != null
                ? 'Unknown keyword "$word". Did you mean "$hint"?'
                : 'Unexpected text: "$l"',
            i);
      }
    }
    return _resolve(tables, refs);
  }

  SchemaModel _resolve(List<TableModel> tables, List<RefModel> refs) {
    final byName = {for (final t in tables) t.name: t.name};
    final byAlias = {
      for (final t in tables)
        if (t.alias != null) t.alias!: t.name
    };
    final byShort = {for (final t in tables) t.name.split('.').last: t.name};
    String? res(String n) => byName[n] ?? byAlias[n] ?? byShort[n.split('.').last];
    final out = <RefModel>[];
    for (final r in refs) {
      final a = res(r.fromTable), b = res(r.toTable);
      if (a == null || b == null) continue;
      out.add(RefModel(
          fromTable: a,
          fromColumn: r.fromColumn,
          toTable: b,
          toColumn: r.toColumn,
          type: r.type));
    }
    return SchemaModel(tables, out);
  }

  (TableModel, int) _readTable(
      List<String> lines, int start, RegExpMatch m, List<RefModel> refs) {
    final name = _unq(m.group(1)!);
    if (m.group(3) != null) {
      return (TableModel(name: name, alias: m.group(2), columns: const []), start + 1);
    }
    final cols = <ColumnModel>[];
    String? note;
    var i = start + 1;
    while (i < lines.length) {
      final l = _clean(lines[i]);
      if (l.isEmpty) {
        i++;
        continue;
      }
      if (l.startsWith('}')) {
        return (
          TableModel(name: name, alias: m.group(2), note: note, columns: cols),
          i + 1
        );
      }
      if (RegExp(r'^([Ii]ndexes|[Nn]ote)\s*\{').hasMatch(l)) {
        i = _skipBlock(lines, i);
        continue;
      }
      if (RegExp(r'^[Nn]ote\s*:').hasMatch(l)) {
        if (l.contains("'''")) {
          if ("'''".allMatches(l).length == 1) {
            i++;
            while (i < lines.length && !lines[i].contains("'''")) {
              i++;
            }
          }
        } else {
          note = _unq(l.substring(l.indexOf(':') + 1).trim());
        }
        i++;
        continue;
      }
      final cm = _col.firstMatch(l);
      if (cm == null) throw DbmlParseException(
            'Cannot parse column: "$l". Expected: name type [settings]', i);
      final colName = _unq(cm.group(1)!);
      var pk = false, nn = false, uq = false, inc = false;
      String? cnote, def;
      final bare = (cm.group(4) ?? '').toLowerCase();
      if (RegExp(r'\bpk\b|primary\s+key').hasMatch(bare)) pk = true;
      if (bare.contains('not null')) nn = true;
      if (RegExp(r'\bunique\b').hasMatch(bare)) uq = true;
      if (RegExp(r'\bincrement\b').hasMatch(bare)) inc = true;
      for (final s in _split(cm.group(3) ?? '')) {
        final low = s.toLowerCase();
        if (low == 'pk' || low == 'primary key') {
          pk = true;
        } else if (low == 'not null') {
          nn = true;
        } else if (low == 'unique') {
          uq = true;
        } else if (low == 'increment') {
          inc = true;
        } else if (low.startsWith('note:')) {
          cnote = _unq(s.substring(5).trim());
        } else if (low.startsWith('default:')) {
          def = _unq(s.substring(8).trim());
        } else {
          final rm = _inlineRef.firstMatch(s);
          if (rm != null) {
            refs.add(RefModel(
              fromTable: name,
              fromColumn: colName,
              toTable: _unq(rm.group(2)!),
              toColumn: _unq(rm.group(3)!),
              type: _op(rm.group(1)!),
            ));
          }
        }
      }
      cols.add(ColumnModel(
        name: colName,
        type: cm.group(2)!,
        pk: pk,
        notNull: nn,
        unique: uq,
        autoInc: inc,
        note: cnote,
        defaultValue: def,
      ));
      i++;
    }
    throw DbmlParseException('Table "$name" is not closed', start);
  }

  int _readRef(List<String> lines, int i, List<RefModel> refs) {
    final l = _clean(lines[i]);
    if (l.endsWith('{')) {
      var j = i + 1;
      while (j < lines.length) {
        final x = _clean(lines[j]);
        if (x.startsWith('}')) return j + 1;
        _addRel(x, refs, j);
        j++;
      }
      throw DbmlParseException('Ref block is not closed', i);
    }
    _addRel(l, refs, i);
    return i + 1;
  }

  void _addRel(String s, List<RefModel> refs, int line) {
    final m = _rel.firstMatch(s);
    if (m == null) {
      throw DbmlParseException(
          'Invalid relationship: "$s". Expected: Ref: table.col > table.col', line);
    }
    refs.add(RefModel(
      fromTable: _unq(m.group(1)!),
      fromColumn: _unq(m.group(2)!),
      toTable: _unq(m.group(4)!),
      toColumn: _unq(m.group(5)!),
      type: _op(m.group(3)!),
    ));
  }

  RelType _op(String o) {
    if (o == '<>') return RelType.manyToMany;
    if (o.startsWith('>')) return RelType.manyToOne;
    if (o.startsWith('<')) return RelType.oneToMany;
    return RelType.oneToOne;
  }

  /// Closest known keyword (edit distance <= 2), or null.
  String? _suggest(String w) {
    if (w.isEmpty) return null;
    String? best;
    var bd = 3;
    for (final k in _keywords) {
      final d = _lev(w.toLowerCase(), k.toLowerCase());
      if (d < bd) {
        bd = d;
        best = k;
      }
    }
    return best;
  }

  int _lev(String a, String b) {
    var prev = List.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = [i, ...List.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  int _skipBlock(List<String> lines, int start) {
    var depth = 0, i = start;
    do {
      final l = _clean(lines[i]);
      depth += '{'.allMatches(l).length - '}'.allMatches(l).length;
      i++;
    } while (i < lines.length && depth > 0);
    return i;
  }

  String _clean(String l) {
    final i = l.indexOf('//');
    return (i >= 0 ? l.substring(0, i) : l).trim();
  }

  String _unq(String s) {
    if (s.length >= 2 && '"\'`'.contains(s[0]) && s[0] == s[s.length - 1]) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  List<String> _split(String s) {
    final out = <String>[];
    var buf = StringBuffer(), q = '', depth = 0;
    for (final ch in s.split('')) {
      if (q.isNotEmpty) {
        buf.write(ch);
        if (ch == q) q = '';
        continue;
      }
      if (ch == "'" || ch == '"' || ch == '`') q = ch;
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        out.add(buf.toString().trim());
        buf = StringBuffer();
        continue;
      }
      buf.write(ch);
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out.where((e) => e.isNotEmpty).toList();
  }
}
