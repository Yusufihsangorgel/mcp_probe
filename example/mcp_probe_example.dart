import 'dart:io';

import 'package:mcp_probe/mcp_probe.dart';

/// Runs the conformance checks against an MCP server command and prints the
/// report as Markdown.
///
///     dart run example/mcp_probe_example.dart <command> [args...]
///
/// With no arguments it probes the well-behaved fixture server that ships with
/// the package, so you can see a real report before pointing it at your own.
Future<void> main(List<String> args) async {
  const fixture = 'test/fixtures/well_behaved_server.dart';

  final String command;
  final List<String> commandArgs;
  if (args.isEmpty) {
    if (!File(fixture).existsSync()) {
      stderr.writeln(
        'Usage: dart run example/mcp_probe_example.dart <command> [args...]\n'
        '($fixture is missing, so there is nothing to fall back to)',
      );
      exitCode = 64;
      return;
    }
    stdout.writeln('No server given, probing $fixture.\n');
    command = Platform.resolvedExecutable;
    commandArgs = ['run', fixture];
  } else {
    command = args.first;
    commandArgs = args.sublist(1);
  }

  final report = await checkServer(command, args: commandArgs);
  stdout.write(report.toMarkdown());
  if (report.hasErrors) exitCode = 1;
}
