import 'dart:io';

import 'package:mcp_probe/mcp_probe.dart';

/// Runs the conformance checks against an MCP server command and prints the
/// report as Markdown.
///
/// Usage:
///
///     dart run example/mcp_probe_example.dart <command> [args...]
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run example/mcp_probe_example.dart <command> [args...]',
    );
    exitCode = 64;
    return;
  }
  final report = await checkServer(args.first, args: args.sublist(1));
  stdout.write(report.toMarkdown());
  if (report.hasErrors) exitCode = 1;
}
