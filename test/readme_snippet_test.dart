// Compiles the snippet printed in example/README.md, so a reader who copies it
// gets working code. It is never run against a real server; the point is that
// the API names and parameter shapes are the ones the package actually has.
@Skip('compile-only check of the README snippet')
library;

import 'package:mcp_probe/mcp_probe.dart';
import 'package:mcp_probe/testing.dart';
import 'package:test/test.dart';

void main() {
  late McpServerHarness harness;

  setUp(() async {
    harness = await McpServerHarness.start(
      'dart',
      args: ['run', 'bin/my_server.dart'],
    );
  });
  tearDown(() => harness.shutdown());

  test('exposes the search tool and it runs', () async {
    await expectToolExists(harness, 'search');
    await expectToolCallSucceeds(harness, 'search', arguments: {'q': 'dart'});
  });
}
