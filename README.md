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
  `package:mcp_probe/testing.dart`. `example/server_test.dart` is a working
  test file that uses all four against a bundled server; copy it and change
  the command.

The server under test does not have to be written in Dart. Anything that
speaks MCP over stdio works: a Dart script, `npx -y some-server`, a Python
script, a compiled binary. On Windows, launch batch-file based tools such as
npx by their full script name (`npx.cmd`), since `Process.start` does not
resolve `.cmd` files by their bare name.

![Diagram: the harness drives an MCP server over stdio and turns each reply into a ConformanceReport](https://raw.githubusercontent.com/Yusufihsangorgel/mcp_probe/main/doc/architecture.png)

## Why this instead of what you already have

**Instead of a hand-rolled stdio client.** Starting a server with
`Process.start` and speaking JSON-RPC at it is not the hard part. Getting it
back down is: a server that never answers hangs the test run, and a failed
handshake leaves an orphan process behind. `McpServerHarness` puts a timeout on
every request and kills the child on the way out either way. `checkServer`
(`lib/src/conformance.dart:74`) then runs the named rules in `ConformanceRules`
(`:12`), including ones you would not think to write, such as
`stdio/clean-stdout` (`:58`) for a server that prints a banner into the
transport.

**Instead of `mcp_dart_cli`.** Its `inspect-server` command does point at a live
server and report pass, warning, and fail checks, so the command line is
covered. Your test suite is not. Its `conformance` command describes itself as
"not a live target inspector" (`lib/src/conformance_command.dart:16`), and its
library file says it exists "without exposing an additional public API"
(`lib/mcp_dart_cli.dart`), so there is nothing to import. mcp_probe goes in
`dev_dependencies`, and `expectToolExists` and the three beside it
(`lib/src/matchers.dart:8`) are ordinary `package:test` expectations.

**Reach for it when**

- You maintain an MCP server and want a red test when a rename drops a tool or
  an `inputSchema` stops being an object.
- You are about to build on a third-party server, in any language, and want to
  see what it actually answers first.
- CI needs an exit code, which `mcp_probe check --fail-on warning` returns
  (`bin/mcp_probe.dart:91`).

Skip it if the server under test is a Dart `MCPServer` in the same repo that you
can drive in-process over a stream channel, since then the subprocess and the
stdio transport are cost with no coverage behind them.

## Command line

To check a server without writing any Dart, install the CLI and point it at the
command that launches your server:

```sh
dart pub global activate mcp_probe
mcp_probe check dart run my_server.dart
mcp_probe check node build/server.js --flag
```

It runs the server over stdio, completes the handshake, prints each finding, and
exits non-zero if any check reports an error, which drops it straight into a CI
step.

Two flags make it a real gate. `--format json` prints the report as JSON, with a
`summary` count per severity and the full findings list, for a pipeline or a
dashboard that wants structured output. `--fail-on warning` (or `info`) lowers
the bar for a non-zero exit, so a warning fails the build the way an error does.

```sh
# Fail the build on any warning, and capture the machine-readable report.
mcp_probe check --fail-on warning --format json dart run my_server.dart > report.json
```

```json
{
  "command": "dart run my_server.dart",
  "serverName": "my-server",
  "summary": { "error": 0, "warning": 1, "info": 12 },
  "findings": [
    { "severity": "info", "rule": "initialize/handshake", "message": "server answered the initialize request" }
  ]
}
```

## In a GitHub Actions workflow

A composite action gates a pull request on conformance in a few lines. It sets
up Dart, activates the CLI, and runs the check:

```yaml
- uses: Yusufihsangorgel/mcp_probe@v0.9.8
  with:
    command: dart run bin/server.dart
    fail-on: warning   # error (default), warning, or info
    format: markdown   # or json
```

`command` is the only required input; it is the command that launches your
server over stdio, and it is passed through whole, so `dart run` and
`npx -y some-server` both work. The step fails the job when a finding at or
above `fail-on` is present.

Checked against the servers in this repository: the well-behaved fixture exits
0 with 12 checks and no findings, and the one that logs to stdout exits 1 on
the same 12.

If your server launches with `dart run`, run `dart pub get` earlier in the job.
`dart run` prints a resolution line to stdout the first time, which would land
in the server's output; resolving up front keeps the channel clean. A compiled
server or a Node/Python one has nothing to resolve and needs no such step.

## Using the harness in tests

Add `mcp_probe` as a dev dependency next to `test`:

```sh
dart pub add dev:mcp_probe dev:test
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

![Four timed runs against the same unresponsive MCP server. The top row, a
hand-written stdio client with no timeout, is still waiting when the
measurement stops six seconds in, and its server process is still alive.
Below it three harness runs fail with a TimeoutException at the 500
millisecond, 1 second and 2 second marks they were given, each followed by
the server process exiting a few milliseconds
later.](https://raw.githubusercontent.com/Yusufihsangorgel/mcp_probe/main/doc/timeout.png)

The three lower rows differ in one argument. Whatever you pass as `timeout`
is where the request gives up, to within a few milliseconds, and by the time
`shutdown` returns the child process is already gone. The top row is the
same server driven by a hand-written client with nothing bounding the wait,
which is the shape of a suite that hangs. `dart run tool/timeout_figure.dart`
measures all four and refuses to write the file when the control server
answers or a wall lands off its mark.

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

![Grid of thirteen conformance rules across six MCP servers. The clean fixture
is green on every rule, the five broken ones show amber or red cells on exactly
the rules they violate, and a bottom row gives the exit code each would return
from the CLI.](https://raw.githubusercontent.com/Yusufihsangorgel/mcp_probe/main/doc/rule-grid.png)

Every cell above is a severity from a real run against the fixture servers in
`test/fixtures/`. Four of the five broken ones finish the handshake and then
break a rule anyway, which is the case these checks exist for. The image comes
out of `dart run tool/rule_grid_figure.dart`, which measures first and refuses
to write the file if the clean fixture stops coming back clean.

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
| `utilities/ping` | error | The server answers a `ping` request promptly with an empty result. |
| `jsonrpc/method-not-found` | error or warning | An unknown method is answered with JSON-RPC error -32601. |
| `stdio/clean-stdout` | error | The server writes nothing but protocol messages to stdout. |

Passing checks are recorded as info findings; the report then shows what was
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
