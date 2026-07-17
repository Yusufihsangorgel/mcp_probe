/// The severity of a [ConformanceFinding].
enum ConformanceSeverity {
  /// The server violates the MCP specification or failed to respond.
  error,

  /// The behavior is legal but likely to confuse clients.
  warning,

  /// A check that passed, or a neutral observation.
  info,
}

/// A single observation produced by a conformance rule.
class ConformanceFinding {
  /// Creates a finding for [rule] with the given [severity] and [message].
  const ConformanceFinding({
    required this.severity,
    required this.rule,
    required this.message,
  });

  /// How serious the finding is.
  final ConformanceSeverity severity;

  /// The identifier of the rule that produced this finding, for example
  /// `tools/input-schema`.
  final String rule;

  /// A human-readable description of what was observed.
  final String message;

  @override
  String toString() => '[${severity.name}] $rule: $message';
}

/// The result of running [checkServer] against an MCP server.
///
/// Findings appear in the order the checks ran. Passing checks are recorded
/// as [ConformanceSeverity.info] findings so the report shows what was
/// actually covered, not only what failed.
class ConformanceReport {
  /// Creates a report for the server started by [command].
  const ConformanceReport({
    required this.command,
    required this.findings,
    this.serverName,
    this.serverVersion,
    this.protocolVersion,
  });

  /// The command line that was probed.
  final String command;

  /// The server name from `serverInfo`, if the handshake got that far.
  final String? serverName;

  /// The server version from `serverInfo`, if the handshake got that far.
  final String? serverVersion;

  /// The protocol version string the server answered with, if any.
  final String? protocolVersion;

  /// All findings, in the order the checks ran.
  final List<ConformanceFinding> findings;

  /// Findings with [ConformanceSeverity.error].
  List<ConformanceFinding> get errors => [
    for (final f in findings)
      if (f.severity == ConformanceSeverity.error) f,
  ];

  /// Findings with [ConformanceSeverity.warning].
  List<ConformanceFinding> get warnings => [
    for (final f in findings)
      if (f.severity == ConformanceSeverity.warning) f,
  ];

  /// Findings with [ConformanceSeverity.info].
  List<ConformanceFinding> get infos => [
    for (final f in findings)
      if (f.severity == ConformanceSeverity.info) f,
  ];

  /// Whether any finding is an error.
  bool get hasErrors => errors.isNotEmpty;

  /// Renders the report as Markdown.
  String toMarkdown() {
    final buffer = StringBuffer('# MCP conformance report\n\n');
    buffer.writeln('Command: `$command`');
    if (serverName != null) {
      final version = serverVersion == null || serverVersion!.isEmpty
          ? ''
          : ' $serverVersion';
      buffer.writeln('Server: ${_escape(serverName!)}$version');
    }
    if (protocolVersion != null) {
      buffer.writeln('Protocol version: $protocolVersion');
    }
    buffer
      ..writeln()
      ..writeln(
        'Summary: ${errors.length} error(s), ${warnings.length} warning(s), '
        '${infos.length} info.',
      )
      ..writeln()
      ..writeln('| Severity | Rule | Detail |')
      ..writeln('| --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| ${finding.severity.name} | ${_escape(finding.rule)} '
        '| ${_escape(finding.message)} |',
      );
    }
    return buffer.toString();
  }

  static String _escape(String text) =>
      text.replaceAll('|', r'\|').replaceAll('\n', ' ');
}
