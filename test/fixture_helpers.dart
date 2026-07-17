/// Shared helpers for starting the fixture servers in `test/fixtures/`.
library;

import 'dart:io';

import 'package:mcp_probe/mcp_probe.dart';

/// The Dart VM running the tests, used to launch fixture servers.
final String dartExecutable = Platform.resolvedExecutable;

/// The `dart run` arguments that launch the fixture server [name].
List<String> fixtureArgs(String name) => ['run', 'test/fixtures/$name.dart'];

/// Starts the fixture server [name] in a harness.
Future<McpServerHarness> startFixture(
  String name, {
  Map<String, String>? environment,
  Duration timeout = const Duration(seconds: 15),
}) => McpServerHarness.start(
  dartExecutable,
  args: fixtureArgs(name),
  environment: environment,
  timeout: timeout,
);

/// Runs the conformance checks against the fixture server [name].
Future<ConformanceReport> checkFixture(
  String name, {
  Duration timeout = const Duration(seconds: 15),
  bool callTools = false,
}) => checkServer(
  dartExecutable,
  args: fixtureArgs(name),
  timeout: timeout,
  callTools: callTools,
);

/// Whether a process with [pid] is currently alive, according to `ps`.
Future<bool> processIsAlive(int pid) async {
  final result = await Process.run('ps', ['-p', '$pid']);
  return result.exitCode == 0;
}
