# mcp_probe

![mcp_probe banner](https://raw.githubusercontent.com/Yusufihsangorgel/mcp_probe/main/doc/banner.png)

Test harness and conformance checks for MCP servers, built on the official
[dart_mcp](https://pub.dev/packages/dart_mcp) client.

There are plenty of packages for writing MCP servers. This one is for testing
them. It runs any MCP server you can start as a command, over stdio, and lets
you assert on its behavior from `package:test`:

- `McpServerHarness` starts the server as a child process, performs the MCP
  initialize handshake, and exposes the tool, resource, and prompt APIs with
  a per-request timeout and guaranteed process cleanup.
- `checkServer` runs a fixed set of conformance rules against a server
  command and returns a `ConformanceReport` with error, warning, and info
  findings, plus a `toMarkdown()` renderer.
- `expectToolExists`, `expectToolCallSucceeds`, `expectToolCallFails`, and
  `expectResourceExists` are ready-made expectation helpers, exported from
  `package:mcp_probe/testing.dart`.

The server under test does not have to be written in Dart. Anything that
speaks MCP over stdio works: a Dart script, `npx -y some-server`, a Python
script, a compiled binary. On Windows, launch batch-file based tools such as
npx by their full script name (`npx.cmd`), since `Process.start` does not
resolve `.cmd` files by their bare name.

## Using the harness in tests

Add `mcp_probe` as a dev dependency next to `test`:

```yaml
dev_dependencies:
  mcp_probe: ^0.1.1
  test: ^1.25.0
```

Then start your server once per suite and assert on it:

```dart
import 'package:mcp_probe/mcp_probe.dart';
import 'package:mcp_probe/testing.dart';
import 'package:test/test.dart';

void main() {
  late McpServerHarness harness;

  setUpAll(() async {
    harness = await McpServerHarness.start(
      'dart',
      args: ['run', 'bin/my_server.dart'],
    );
  });

  tearDownAll(() => harness.shutdown());

  test('exposes the search tool', () async {
    await expectToolExists(harness, 'search');
  });

  test('search returns results', () async {
    final result = await expectToolCallSucceeds(
      harness,
      'search',
      arguments: {'query': 'dart'},
    );
    expect(result.content, isNotEmpty);
  });
}
```

Every request made through the harness is bounded by the `timeout` given to
`start`, so a server that stops answering fails the test with a
`TimeoutException` instead of hanging the suite. `shutdown` closes the
connection and then makes sure the process is dead, escalating to SIGTERM
and SIGKILL if the server does not exit on its own.

The harness wraps the common APIs. For anything else (resource
subscriptions, progress notifications, completions), the underlying
`dart_mcp` `ServerConnection` is available as `harness.connection`.

The expectation helpers live in the separate
`package:mcp_probe/testing.dart` entrypoint because they depend on
`package:test`. The harness and the conformance checks do not use it,
though the package still lists `test` as a dependency for that entrypoint.

## Conformance checks

`checkServer` starts the server, runs every rule, shuts the server down, and
reports what it found:

```dart
test('server passes the MCP conformance checks', () async {
  final report = await checkServer('dart', args: ['run', 'bin/my_server.dart']);
  expect(report.errors, isEmpty, reason: report.toMarkdown());
});
```

A server that fails the handshake still produces a report instead of
throwing, so batch runs over several servers do not need error handling per
server.

### Rules

| Rule | On failure | What it checks |
| --- | --- | --- |
| `initialize/handshake` | error | The server answers the initialize request within the timeout. |
| `initialize/protocol-version` | error | The response carries a recognized MCP protocol version. |
| `initialize/server-info-name` | error | `serverInfo.name` is a non-empty string. |
| `initialize/server-info-version` | error | `serverInfo.version` is a non-empty string. |
| `capabilities/tools-listable` | error | A server that declares the `tools` capability answers `tools/list`. |
| `capabilities/tools-nonempty` | warning | A server that declares `tools` lists at least one tool. |
| `tools/name` | error | Every listed tool has a non-empty `name`. |
| `tools/input-schema` | error | Every listed tool has an `inputSchema` whose root is `"type": "object"`. |
| `tools/call-smoke` | error | Optional, see below. Each tool answers a call at the protocol level. |
| `capabilities/resources-listable` | error | A server that declares `resources` answers `resources/list`. |
| `capabilities/prompts-listable` | error | A server that declares `prompts` answers `prompts/list`. |
| `jsonrpc/method-not-found` | error or warning | An unknown method is answered with JSON-RPC error -32601. |
| `stdio/clean-stdout` | error | The server writes nothing but protocol messages to stdout. |

Passing checks are recorded as info findings, so the report shows what was
covered rather than only what failed.

### About `callTools`

The checks are read-only by default: lists are fetched, nothing is invoked.
With `callTools: true`, `checkServer` additionally calls every listed tool
once with empty arguments. Be aware of what that means: a smoke call is a
real call, and whatever side effects the tool has will run. Only enable it
for servers whose tools are safe to invoke blindly, or point it at a
sandboxed instance. A tool that rejects the empty arguments with an in-band
error (`isError: true`) or with JSON-RPC error -32602 (invalid params)
still passes the rule, since the specification allows both; other
protocol-level failures are errors.

## Relationship to dart_mcp

This package is a thin layer over the official
[dart_mcp](https://pub.dev/packages/dart_mcp) client and does not
reimplement any of the protocol. Requests, responses, and capability types
in the public API are `dart_mcp` types. This release builds on dart_mcp
0.5.x, which recognizes protocol versions 2024-11-05 through 2025-11-25;
servers negotiating anything else fail `initialize/protocol-version`.

## Limits

- stdio is the only supported transport in this release.
- The conformance rule set is deliberately small and covers the handshake
  and the declared-capability surface, not the full specification.
- Stdout noise detection is line-based: any non-empty stdout line that does
  not start with `{` counts as noise for `stdio/clean-stdout` and is
  filtered out before it reaches the protocol parser.
