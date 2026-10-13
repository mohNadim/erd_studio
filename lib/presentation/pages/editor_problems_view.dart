part of 'editor_page.dart';

extension _EditorProblemsView on _EditorPageState {
  void _goTo(DbmlIssue issue) {
    if (issue.line <= 0) return;
    final source = text.text;
    var offset = 0;
    var line = 1;
    while (line < issue.line) {
      final index = source.indexOf('\n', offset);
      if (index < 0) {
        offset = source.length;
        break;
      }
      offset = index + 1;
      line++;
    }
    offset = math.min(
      source.length,
      offset + math.max(0, issue.column - 1),
    );
    text.selection = TextSelection.collapsed(offset: offset);
    editorFocus.requestFocus();
    if (vScroll.hasClients) {
      final target = (issue.line - 1) * kLineHeight;
      final top = vScroll.offset;
      if (target < top || target > top + _editorVH - 3 * kLineHeight) {
        vScroll.animateTo(
          (target - _editorVH / 3)
              .clamp(0.0, vScroll.position.maxScrollExtent)
              .toDouble(),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _problemsPanel(ColorScheme colorScheme) {
    final issues = c.issues;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.resizeRow,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) => _setState(
              () => _problemsH =
                  (_problemsH - details.delta.dy).clamp(80.0, 420.0).toDouble(),
            ),
            child: Container(
              height: 6,
              color: colorScheme.outlineVariant.withAlpha(120),
            ),
          ),
        ),
        Container(
          height: _problemsH,
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                child: Row(
                  children: [
                    Text(
                      'PROBLEMS  ${issues.length}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _setState(() => _problemsOpen = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: issues.isEmpty
                    ? Center(
                        child: Text(
                          'No problems found',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: issues.length,
                        itemBuilder: (_, i) {
                          final issue = issues[i];
                          return InkWell(
                            onTap: () => _goTo(issue),
                            onDoubleTap: () => _goTo(issue),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 16,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      issue.message,
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (issue.line > 0)
                                    Text(
                                      '[${issue.line}:${issue.column}]',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBar(ColorScheme colorScheme) => ListenableBuilder(
        listenable: c,
        builder: (_, __) {
          final count = c.issues.length;
          return InkWell(
            onTap: () => _setState(() => _problemsOpen = !_problemsOpen),
            child: Container(
              height: 26,
              color: colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    count > 0
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 15,
                    color: count > 0 ? colorScheme.error : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    count > 0
                        ? '$count problem${count == 1 ? '' : 's'}'
                        : 'No problems',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '${c.schema.tables.length} tables · '
                      '${c.schema.refs.length} relations',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
