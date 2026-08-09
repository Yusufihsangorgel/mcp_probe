// What testing an MCP server looks like once this package is a dev dependency.
//
// This is a real test file. Copy it into your own `test/` directory, point the
// harness at your server instead of the fixture, and run `dart test`.
//
//   dart test example/server_test.dart
//
// The server under test does not have to be written in Dart. `start` takes a
// command, so `npx`, `python`, or a compiled binary all work the same way.

import 'package:dart_mcp/client.dart';
import 'package:mcp_probe/mcp_probe.dart';
import 'package:mcp_probe/testing.dart';
import 'package:test/test.dart';

void main() {
  late McpServerHarness harness;

  setUpAll(() async {
    harness = await McpServerHarness.start(
      'dart',
      args: [
        // Your server goes here.
        'test/fixtures/well_behaved_server.dart',
      ],
    );
  });

  tearDownAll(() async {
    // Returns the exit code. The process is killed if it ignores the shutdown.
    await harness.shutdown();
  });

  test('the tools the server advertises are the ones we depend on', () async {
    await expectToolExists(harness, 'echo');
    await expectToolExists(harness, 'fail_tool');
  });

  test('echo returns what it was given', () async {
    final result = await expectToolCallSucceeds(
      harness,
      'echo',
      arguments: {'text': 'hello'},
    );
    expect((result.content.first as TextContent).text, contains('hello'));
  });

  test('a failing tool reports the failure in band', () async {
    // Passes only if the server sets `isError: true`. A protocol-level
    // exception is a different thing and fails the test with its own message,
    // because the specification asks for tool failures to come back in band.
    await expectToolCallFails(harness, 'fail_tool');
  });

  test('the resource the docs promise is there', () async {
    await expectResourceExists(harness, 'probe://greeting');
  });

  test('the whole conformance suite passes', () async {
    // The same rules `dart run mcp_probe` applies from the command line.
    final report = await checkServer(
      'dart',
      args: ['test/fixtures/well_behaved_server.dart'],
    );
    expect(
      report.findings.where((f) => f.severity == ConformanceSeverity.error),
      isEmpty,
      reason: report.toMarkdown(),
    );
  });
}
