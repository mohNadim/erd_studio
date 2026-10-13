class DbmlIssue {
  const DbmlIssue(this.line, this.column, this.message);

  final int line;
  final int column;
  final String message;
}

class DbmlParseException implements Exception {
  DbmlParseException(String message, [int? line])
      : issues = [DbmlIssue((line ?? -1) + 1, 0, message)];

  DbmlParseException.multi(this.issues);

  final List<DbmlIssue> issues;

  String get message => issues.first.message;

  @override
  String toString() => issues
      .map(
        (issue) => issue.line > 0
            ? 'Line ${issue.line}:${issue.column} — ${issue.message}'
            : issue.message,
      )
      .join('\n');
}
