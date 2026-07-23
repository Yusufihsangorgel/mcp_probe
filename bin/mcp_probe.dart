// Command-line front end for mcp_probe: run an MCP server and report whether it
// conforms. Install with `dart pub global activate mcp_probe`, then:
//
//   mcp_probe check dart run my_server.dart
//   mcp_probe check --format json dart run my_server.dart
//   mcp_probe check --fail-on warning node build/server.js
//
// Exit code is 0 when nothing at or above the fail-on severity is found
// (default: error), 1 otherwise.
import 'dart:convert';
import 'dart:io';

import 'package:mcp_probe/mcp_probe.dart';

Future<void> main(List<String> argv) async {
  if (argv.isEmpty || argv.first == '-h' || argv.first == '--help') {
    _usage(stdout);
    return;
  }
  if (argv.first != 'check') {
    stderr.writeln('mcp_probe: unknown command "${argv.first}"');
    _usage(stderr);
    exitCode = 64; // EX_USAGE
    return;
  }

  // Flags sit between `check` and the server command; the command (`dart`,
  // `node`, ...) never begins with `--`, so the first non-flag token starts it.
  final rest = argv.sublist(1);
  var format = 'markdown';
  var failOn = ConformanceSeverity.error;
  var i = 0;
  while (i < rest.length && rest[i].startsWith('--')) {
    final flag = rest[i];
    if (flag == '--format') {
      if (i + 1 >= rest.length) return _fail('--format needs a value');
      format = rest[i + 1];
      if (format != 'markdown' && format != 'json') {
        return _fail('--format must be markdown or json, got "$format"');
      }
      i += 2;
    } else if (flag == '--fail-on') {
      if (i + 1 >= rest.length) return _fail('--fail-on needs a value');
      final level = _severity(rest[i + 1]);
      if (level == null) {
        return _fail(
          '--fail-on must be error, warning or info, '
          'got "${rest[i + 1]}"',
        );
      }
      failOn = level;
      i += 2;
    } else {
      return _fail('unknown option "$flag"');
    }
  }

  final command = rest.length > i ? rest[i] : null;
  if (command == null) {
    return _fail('check: needs a server command to run');
  }
  final args = rest.sublist(i + 1);

  final ConformanceReport report;
  try {
    report = await checkServer(command, args: args);
  } on Object catch (error) {
    stderr.writeln('mcp_probe: could not check the server: $error');
    exitCode = 70; // EX_SOFTWARE
    return;
  }

  if (format == 'json') {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    for (final finding in report.findings) {
      final sink = finding.severity == ConformanceSeverity.error
          ? stderr
          : stdout;
      sink.writeln(finding);
    }
    stdout
      ..writeln('')
      ..writeln(
        '$command: ${report.findings.length} checks, '
        '${report.errors.length} error(s), '
        '${report.warnings.length} warning(s)',
      );
  }

  exitCode = _shouldFail(report, failOn) ? 1 : 0;
}

/// Whether the report has any finding at or above [failOn]. `error` is the
/// highest severity, then `warning`, then `info`.
bool _shouldFail(ConformanceReport report, ConformanceSeverity failOn) {
  switch (failOn) {
    case ConformanceSeverity.error:
      return report.errors.isNotEmpty;
    case ConformanceSeverity.warning:
      return report.errors.isNotEmpty || report.warnings.isNotEmpty;
    case ConformanceSeverity.info:
      return report.findings.isNotEmpty;
  }
}

ConformanceSeverity? _severity(String name) {
  for (final value in ConformanceSeverity.values) {
    if (value.name == name) return value;
  }
  return null;
}

void _fail(String message) {
  stderr.writeln('mcp_probe: $message');
  _usage(stderr);
  exitCode = 64; // EX_USAGE
}

void _usage(IOSink out) {
  out
    ..writeln('mcp_probe — conformance checks for MCP servers')
    ..writeln('')
    ..writeln('usage: mcp_probe check [options] <command> [args...]')
    ..writeln('')
    ..writeln('Runs <command> as an MCP server over stdio, completes the')
    ..writeln('initialize handshake, and reports each conformance finding.')
    ..writeln('')
    ..writeln('options:')
    ..writeln('  --format markdown|json   output format (default: markdown)')
    ..writeln('  --fail-on error|warning|info')
    ..writeln('       exit 1 when a finding at or above this severity is found')
    ..writeln('       (default: error)')
    ..writeln('')
    ..writeln('example: mcp_probe check --format json dart run my_server.dart');
}
