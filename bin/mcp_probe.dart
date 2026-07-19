// Command-line front end for mcp_probe: run an MCP server and report whether it
// conforms. Install with `dart pub global activate mcp_probe`, then:
//
//   mcp_probe check dart run my_server.dart
//   mcp_probe check node build/server.js --flag
//
// Exit code is 0 when every check passes, 1 when any check reports an error.
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

  final rest = argv.sublist(1);
  if (rest.isEmpty) {
    stderr.writeln('mcp_probe check: needs a server command to run');
    _usage(stderr);
    exitCode = 64;
    return;
  }
  final command = rest.first;
  final args = rest.sublist(1);

  final ConformanceReport report;
  try {
    report = await checkServer(command, args: args);
  } on Object catch (error) {
    stderr.writeln('mcp_probe: could not check the server: $error');
    exitCode = 70; // EX_SOFTWARE
    return;
  }

  for (final finding in report.findings) {
    final sink =
        finding.severity == ConformanceSeverity.error ? stderr : stdout;
    sink.writeln(finding);
  }

  final errors = report.errors.length;
  final warnings = report.warnings.length;
  stdout
    ..writeln('')
    ..writeln('$command: ${report.findings.length} checks, '
        '$errors error(s), $warnings warning(s)');
  exitCode = errors == 0 ? 0 : 1;
}

void _usage(IOSink out) {
  out
    ..writeln('mcp_probe — conformance checks for MCP servers')
    ..writeln('')
    ..writeln('usage: mcp_probe check <command> [args...]')
    ..writeln('')
    ..writeln('Runs <command> as an MCP server over stdio, completes the')
    ..writeln('initialize handshake, and reports each conformance finding. The')
    ..writeln('exit code is 1 if any check reports an error, 0 otherwise.')
    ..writeln('')
    ..writeln('example: mcp_probe check dart run my_server.dart');
}
