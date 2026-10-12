import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dbml_service.dart' show DbmlIssue;

const kMonoFonts = <String>['Consolas', 'Menlo', 'DejaVu Sans Mono', 'Courier New', 'monospace'];
const double kEditorFontSize = 13;
const double kEditorLineFactor = 1.55;
const double kLineHeight = kEditorFontSize * kEditorLineFactor;

// ───────────────────────────── syntax highlighting ─────────────────────────────

enum _T { comment, string, keyword, type, setting, number, op, color }

class _Seg {
  const _Seg(this.s, this.e, this.t);
  final int s, e;
  final _T t;
}

const _blockKw = {
  'table', 'tablegroup', 'tablepartial', 'enum', 'ref', 'project', 'note', 'indexes'
};
const _settingKw = {
  'pk', 'primary', 'key', 'unique', 'not', 'null', 'increment', 'default', 'ref', 'note',
  'delete', 'update', 'color', 'headercolor', 'inactive', 'name', 'type', 'check',
  'cascade', 'restrict', 'set', 'no', 'action'
};
const _types = {
  'int', 'integer', 'bigint', 'smallint', 'tinyint', 'serial', 'bigserial', 'varchar',
  'char', 'text', 'string', 'boolean', 'bool', 'float', 'double', 'decimal', 'numeric',
  'real', 'timestamp', 'timestamptz', 'date', 'datetime', 'time', 'uuid', 'json',
  'jsonb', 'blob', 'bytea', 'money', 'enum'
};

class _Syn {
  const _Syn(this.comment, this.string, this.keyword, this.type, this.setting, this.number,
      this.op, this.color);
  final Color comment, string, keyword, type, setting, number, op, color;

  TextStyle of(_T t) => switch (t) {
        _T.comment => TextStyle(color: comment, fontStyle: FontStyle.italic),
        _T.string => TextStyle(color: string),
        _T.keyword => TextStyle(color: keyword, fontWeight: FontWeight.w700),
        _T.type => TextStyle(color: type),
        _T.setting => TextStyle(color: setting),
        _T.number => TextStyle(color: number),
        _T.op => TextStyle(color: op, fontWeight: FontWeight.w700),
        _T.color => TextStyle(color: color),
      };

  static const dark = _Syn(Color(0xFF7F8AA3), Color(0xFFC3E88D), Color(0xFFC792EA),
      Color(0xFF82AAFF), Color(0xFFF78C6C), Color(0xFFFFCB6B), Color(0xFF89DDFF),
      Color(0xFFFFCB6B));
  static const light = _Syn(Color(0xFF6B7280), Color(0xFF15803D), Color(0xFF7C3AED),
      Color(0xFF1D4ED8), Color(0xFFC2410C), Color(0xFFB45309), Color(0xFF0E7490),
      Color(0xFFB45309));
}

List<_Seg> _scan(String s, Set<String> enums) {
  final out = <_Seg>[];
  final n = s.length;
  var i = 0, bracket = 0;
  bool wordStart(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
  bool digit(int c) => c >= 48 && c <= 57;
  bool word(int c) => wordStart(c) || digit(c);
  bool hex(int c) => digit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102);
  bool firstOnLine(int idx) {
    for (var k = idx - 1; k >= 0; k--) {
      final c = s.codeUnitAt(k);
      if (c == 10) return true;
      if (c != 32 && c != 9 && c != 13) return false;
    }
    return true;
  }

  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 10) {
      bracket = 0;
      i++;
    } else if (c == 47 && i + 1 < n && s.codeUnitAt(i + 1) == 47) {
      var j = s.indexOf('\n', i);
      if (j < 0) j = n;
      out.add(_Seg(i, j, _T.comment));
      i = j;
    } else if (c == 47 && i + 1 < n && s.codeUnitAt(i + 1) == 42) {
      var j = s.indexOf('*/', i + 2);
      j = j < 0 ? n : j + 2;
      out.add(_Seg(i, j, _T.comment));
      i = j;
    } else if (s.startsWith("'''", i)) {
      var j = s.indexOf("'''", i + 3);
      j = j < 0 ? n : j + 3;
      out.add(_Seg(i, j, _T.string));
      i = j;
    } else if (c == 39 || c == 34 || c == 96) {
      var j = i + 1;
      while (j < n) {
        final d = s.codeUnitAt(j);
        if (d == 10) break;
        if (d == 92) {
          j += 2;
          continue;
        }
        j++;
        if (d == c) break;
      }
      if (j > n) j = n;
      out.add(_Seg(i, j, _T.string));
      i = j;
    } else if (c == 91) {
      bracket++;
      i++;
    } else if (c == 93) {
      if (bracket > 0) bracket--;
      i++;
    } else if (c == 35) {
      var j = i + 1;
      while (j < n && hex(s.codeUnitAt(j))) {
        j++;
      }
      if (j > i + 1) out.add(_Seg(i, j, _T.color));
      i = j;
    } else if (digit(c)) {
      var j = i;
      while (j < n && (digit(s.codeUnitAt(j)) || s.codeUnitAt(j) == 46)) {
        j++;
      }
      out.add(_Seg(i, j, _T.number));
      i = j;
    } else if (wordStart(c)) {
      var j = i + 1;
      while (j < n && word(s.codeUnitAt(j))) {
        j++;
      }
      final w = s.substring(i, j), l = w.toLowerCase();
      _T? t;
      if (bracket > 0) {
        if (_settingKw.contains(l)) t = _T.setting;
      } else if (l == 'as' || (_blockKw.contains(l) && firstOnLine(i))) {
        t = _T.keyword;
      } else if (!firstOnLine(i) &&
          !(i > 0 && s.codeUnitAt(i - 1) == 46) &&
          (_types.contains(l) || enums.contains(w))) {
        t = _T.type;
      }
      if (t != null) out.add(_Seg(i, j, t));
      i = j;
    } else if (c == 60 || c == 62) {
      var j = i + 1;
      if (c == 60 && j < n && s.codeUnitAt(j) == 62) j++;
      out.add(_Seg(i, j, _T.op));
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

// ─────────────────────── controller: colors + wavy error underline ───────────────────────

class DbmlTextController extends TextEditingController {
  DbmlTextController({super.text});

  static final _enumRe = RegExp(r'^\s*enum\s+(\w+)', multiLine: true, caseSensitive: false);
  static const _errStyle = TextStyle(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: Color(0xFFFF3B30),
    decorationThickness: 1.0,
  );

  List<DbmlIssue> _issues = const [];
  List<DbmlIssue> get issues => _issues;
  set issues(List<DbmlIssue> v) {
    if (identical(v, _issues)) return;
    _issues = v;
    notifyListeners();
  }

  bool _isWordChar(int c) =>
      (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;

  List<(int, int)> _errorRanges(String t) {
    if (_issues.isEmpty) return const [];
    final starts = <int>[0];
    for (var i = 0; i < t.length; i++) {
      if (t.codeUnitAt(i) == 10) starts.add(i + 1);
    }
    int lineEnd(int li) {
      var e = li + 1 < starts.length ? starts[li + 1] - 1 : t.length;
      if (e > starts[li] && t.codeUnitAt(e - 1) == 13) e--;
      return e;
    }

    final out = <(int, int)>[];
    for (final is_ in _issues) {
      var li = math.min(is_.line - 1, starts.length - 1);
      if (li < 0) continue;
      var ls = starts[li], le = lineEnd(li);
      // empty line (e.g. "block not closed" at EOF): use the previous non-empty line
      while (le <= ls && li > 0) {
        li--;
        ls = starts[li];
        le = lineEnd(li);
      }
      if (le <= ls) continue;
      int s, e;
      if (is_.column <= 0 || is_.line - 1 >= starts.length) {
        s = ls;
        while (s < le && (t.codeUnitAt(s) == 32 || t.codeUnitAt(s) == 9)) {
          s++;
        }
        e = le;
        while (e > s && (t.codeUnitAt(e - 1) == 32 || t.codeUnitAt(e - 1) == 9)) {
          e--;
        }
      } else {
        s = ls + is_.column - 1;
        if (s >= le) s = le - 1;
        if (s < ls) s = ls;
        e = s + 1;
        if (_isWordChar(t.codeUnitAt(s))) {
          while (e < le && _isWordChar(t.codeUnitAt(e))) {
            e++;
          }
        }
      }
      if (e > s) out.add((s, e));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in out) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
        if (r.$2 > merged.last.$2) merged[merged.length - 1] = (merged.last.$1, r.$2);
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    final base = style ?? const TextStyle();
    if (t.isEmpty) return TextSpan(style: base, text: '');
    final syn = Theme.of(context).brightness == Brightness.dark ? _Syn.dark : _Syn.light;
    final enums = {for (final m in _enumRe.allMatches(t)) m.group(1)!};
    final segs = _scan(t, enums);
    final errs = _errorRanges(t);
    final kids = <InlineSpan>[];

    void add(int a, int b, TextStyle st) {
      var p = a;
      for (final r in errs) {
        if (r.$2 <= p) continue;
        if (r.$1 >= b) break;
        final s0 = math.max(p, r.$1), e0 = math.min(b, r.$2);
        if (s0 > p) kids.add(TextSpan(text: t.substring(p, s0), style: st));
        kids.add(TextSpan(text: t.substring(s0, e0), style: st.merge(_errStyle)));
        p = e0;
      }
      if (p < b) kids.add(TextSpan(text: t.substring(p, b), style: st));
    }

    var p = 0;
    for (final sg in segs) {
      if (sg.s > p) add(p, sg.s, base);
      add(sg.s, sg.e, base.merge(syn.of(sg.t)));
      p = sg.e;
    }
    if (p < t.length) add(p, t.length, base);
    return TextSpan(style: base, children: kids);
  }
}

// ───────────────────────────── the editor widget ─────────────────────────────

class CodeEditor extends StatefulWidget {
  const CodeEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.vScroll,
    required this.focusNode,
  });
  final DbmlTextController controller;
  final ValueChanged<String> onChanged;
  final ScrollController vScroll;
  final FocusNode focusNode;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final _h = ScrollController();
  int _lines = 1, _maxLen = 0;
  List<DbmlIssue>? _iss;
  double _cw = 7.8;

  static const _strut = StrutStyle(
    fontSize: kEditorFontSize,
    height: kEditorLineFactor,
    forceStrutHeight: true,
  );
  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: kMonoFonts,
    fontSize: kEditorFontSize,
    height: kEditorLineFactor,
  );

  @override
  void initState() {
    super.initState();
    final tp = TextPainter(
      text: const TextSpan(text: '0000000000', style: _mono),
      textDirection: TextDirection.ltr,
    )..layout();
    _cw = tp.width / 10;
    _measure();
    widget.controller.addListener(_onCtl);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCtl);
    _h.dispose();
    super.dispose();
  }

  void _measure() {
    final t = widget.controller.text;
    var lines = 1, maxLen = 0, cur = 0;
    for (final u in t.codeUnits) {
      if (u == 10) {
        lines++;
        maxLen = math.max(maxLen, cur);
        cur = 0;
      } else {
        cur++;
      }
    }
    _lines = lines;
    _maxLen = math.max(maxLen, cur);
    _iss = widget.controller.issues;
  }

  void _onCtl() {
    final l = _lines, m = _maxLen, i = _iss;
    _measure();
    if (l != _lines || m != _maxLen || !identical(i, _iss)) setState(() {});
  }

  void _insertTab() {
    final c = widget.controller;
    final sel = c.selection;
    if (!sel.isValid) return;
    final nt = c.text.replaceRange(sel.start, sel.end, '  ');
    c.value = TextEditingValue(
        text: nt, selection: TextSelection.collapsed(offset: sel.start + 2));
    widget.onChanged(nt);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final errLines = {for (final i in widget.controller.issues) i.line};
    return LayoutBuilder(builder: (ctx, cons) {
      final minLines = math.max(1, ((cons.maxHeight - 24) / kLineHeight).floor());
      final gutterW = math.max(46.0, '$_lines'.length * _cw + 30);
      final textW = math.max(cons.maxWidth - gutterW, _maxLen * _cw + 90);
      final numStyle = _mono.copyWith(color: cs.onSurfaceVariant.withAlpha(150));
      final errNum = _mono.copyWith(color: const Color(0xFFFF3B30), fontWeight: FontWeight.w700);
      return ColoredBox(
        color: cs.surface,
        child: SingleChildScrollView(
          controller: widget.vScroll,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: gutterW,
              padding: const EdgeInsets.fromLTRB(0, 12, 10, 12),
              color: cs.surfaceContainerLow,
              child: Text.rich(
                TextSpan(style: numStyle, children: [
                  for (var i = 1; i <= _lines; i++)
                    TextSpan(
                        text: i == _lines ? '$i' : '$i\n',
                        style: errLines.contains(i) ? errNum : null),
                ]),
                textAlign: TextAlign.right,
                strutStyle: _strut,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _h,
                child: SizedBox(
                  width: textW,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.tab): _insertTab,
                    },
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      onChanged: widget.onChanged,
                      maxLines: null,
                      minLines: minLines,
                      keyboardType: TextInputType.multiline,
                      style: _mono.copyWith(color: cs.onSurface),
                      strutStyle: _strut,
                      cursorColor: cs.primary,
                      autocorrect: false,
                      enableSuggestions: false,
                      smartDashesType: SmartDashesType.disabled,
                      smartQuotesType: SmartQuotesType.disabled,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(10, 12, 16, 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
