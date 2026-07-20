/// Runs the conformance checks against servers that ship with this package, so
/// the report can be read before writing a server of your own.
///
/// One server behaves. The others each break something specific, including the
/// kind of fault that is invisible from the outside: a server can speak the
/// protocol correctly and still be unusable because it writes a log line to
/// stdout, where the transport expects only JSON-RPC.
///
///     dart run example/probe_demo.dart              # the servers below
///     dart run example/probe_demo.dart my_server    # your own command
///
/// Run it from a checkout of this package, since the demo servers live in
/// `test/fixtures/`.
library;

import 'dart:io';

import 'package:mcp_probe/mcp_probe.dart';

/// The demo servers, and what each one gets wrong.
const _fixtures = [
  ('well_behaved_server', 'a server that behaves'),
  ('noisy_stdout_server', 'a server that logs to stdout'),
  ('schemaless_tool_server', 'a server whose tool has no input schema'),
  (
    'unresponsive_methods_server',
    'a server that ignores ping and unknown methods',
  ),
];

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    final report = await checkServer(args.first, args: args.sublist(1));
    stdout.write(report.toMarkdown());
    if (report.hasErrors) exitCode = 1;
    return;
  }

  for (final (fixture, label) in _fixtures) {
    final report = await checkServer(
      Platform.resolvedExecutable,
      args: ['run', 'test/fixtures/$fixture.dart'],
      // The default is 10 seconds, which is right for a real server on a busy
      // machine. Here one of the servers never answers at all, and waiting the
      // full default for each of its rules would make the demo slower than it
      // is instructive.
      timeout: const Duration(seconds: 3),
    );
    final errors = report.findings
        .where((f) => f.severity == ConformanceSeverity.error)
        .toList();

    print('## $label');
    if (errors.isEmpty) {
      print('   every rule passed\n');
      continue;
    }
    for (final finding in errors) {
      print('   ${finding.rule}');
      print('     ${finding.message}');
    }
    print('');
  }

  print('Point it at your own server to get the same report:');
  print('   dart run example/probe_demo.dart dart run bin/my_server.dart');
}
