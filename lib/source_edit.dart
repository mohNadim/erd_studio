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
        .replaceAll(RegExp(r'\s*,?\s*headercolor\s*:\s*#?[0-9a-fA-F]+', caseSensitive: false), '')
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
