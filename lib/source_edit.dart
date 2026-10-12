/// Writes (or removes) `headercolor: #rrggbb` on the `Table ... {` line of every
/// table in [tables], so a chosen color lives in the DBML file itself.
String setTableHeaderColor(String src, Set<String> tables, String? hex) {
  final head = RegExp(
      r'^(\s*)(table)(\s+)("[^"]+"|[\w\.]+)((?:\s+as\s+\w+)?)\s*(\[[^\]]*\])?\s*\{',
      caseSensitive: false);
  final lines = src.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final m = head.firstMatch(lines[i]);
    if (m == null) continue;
    var name = m.group(4)!;
    if (name.startsWith('"')) name = name.substring(1, name.length - 1);
    if (!tables.contains(name)) continue;
    final br0 = m.group(6);
    var inner = br0 == null ? '' : br0.substring(1, br0.length - 1);
    inner = inner
        .replaceAll(
            RegExp(r'\s*,?\s*headercolor\s*:\s*#?[0-9a-fA-F]+',
                caseSensitive: false),
            '')
        .replaceFirst(RegExp(r'^\s*,\s*'), '')
        .trim();
    if (hex != null) {
      inner = inner.isEmpty ? 'headercolor: $hex' : '$inner, headercolor: $hex';
    }
    final br = inner.isEmpty ? '' : ' [$inner]';
    lines[i] = lines[i].replaceRange(0, m.end,
        '${m.group(1)}${m.group(2)}${m.group(3)}${m.group(4)}${m.group(5)}$br {');
  }
  return lines.join('\n');
}

String renameDbmlTable(String src, String oldName, String newName) {
  final escaped = RegExp.escape(oldName);
  return src.replaceAllMapped(
    RegExp('(?<![\\w.])(["]?)$escaped\\1(?![\\w])'),
    (m) => m.group(1) == '"' ? '"$newName"' : newName,
  );
}

String renameDbmlColumn(
    String src, String tableName, String oldName, String newName) {
  final lines = src.split('\n');
  final tableHead = RegExp(
      r'^\s*table\s+("[^"]+"|[\w\.]+)(?:\s+as\s+\w+)?(?:\s+\[[^\]]*\])?\s*\{',
      caseSensitive: false);
  final column = RegExp(
    '^([ \t]*)(["]?)${RegExp.escape(oldName)}\\2(?=\\s+)',
  );
  var inTable = false;
  var depth = 0;
  for (var i = 0; i < lines.length; i++) {
    final head = tableHead.firstMatch(lines[i]);
    if (head != null) {
      var name = head.group(1)!;
      if (name.startsWith('"')) name = name.substring(1, name.length - 1);
      inTable = name == tableName;
      depth = 1;
      continue;
    }
    if (!inTable) continue;
    if (lines[i].contains('{')) depth++;
    if (lines[i].contains('}')) {
      depth--;
      if (depth <= 0) {
        inTable = false;
        continue;
      }
    }
    if (depth == 1) {
      lines[i] = lines[i].replaceFirstMapped(
          column, (m) => '${m.group(1)}${m.group(2)}$newName${m.group(2)}');
    }
  }
  final qualified = RegExp(
      '(["]?)${RegExp.escape(tableName)}\\1\\.\\s*(["]?)${RegExp.escape(oldName)}\\2');
  return lines.join('\n').replaceAllMapped(
      qualified,
      (m) =>
          '${m.group(1)}$tableName${m.group(1)}.${m.group(2)}$newName${m.group(2)}');
}
