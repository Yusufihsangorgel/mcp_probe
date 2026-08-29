# mcp_probe

`McpServerHarness` starts an MCP server as a child process over stdio, completes the initialize handshake, and times out every later request; `checkServer` runs a fixed rule list and returns a `ConformanceReport`; `package:mcp_probe/testing.dart` wraps the harness as `package:test` expectations. It does not implement a server, does not speak HTTP or SSE, does not cover the full MCP spec, and is the wrong tool for an in-process Dart `MCPServer` over a stream channel.

## Usage

`dart pub add dev:mcp_probe dev:test`. Copy `example/server_test.dart` and change the command. The setup that file actually runs:

```dart
import 'package:mcp_probe/mcp_probe.dart';
import 'package:mcp_probe/testing.dart';
import 'package:test/test.dart';

void main() {
  late McpServerHarness harness;

  setUpAll(() async {
    harness = await McpServerHarness.start(
      'dart',
      args: [
        'test/fixtures/well_behaved_server.dart',
      ],
    );
  });

  tearDownAll(() async {
    await harness.shutdown();
  });

  test('the tools the server advertises are the ones we depend on', () async {
    await expectToolExists(harness, 'echo');
    await expectToolExists(harness, 'fail_tool');
  });
}
```

`checkServer` starts, runs the rules, and shuts down itself (`example/mcp_probe_example.dart`): `final report = await checkServer(command, args: commandArgs);` then `report.toMarkdown()` / `report.hasErrors`.

## Contracts

- Construct only via `McpServerHarness.start`. Await it. The private constructor, initialize, and `notifyInitialized` all happen inside `start`. Then list/call/read. Then `await harness.shutdown()`.
- Await `shutdown` on a harness `start` returned. It closes the connection, waits `killAfter` (default 3s), then SIGTERM, then SIGKILL, and returns the exit code. Safe to call twice. Skip it if `start` threw — the child is already dead. `checkServer` shuts down in a `finally`; it never returns a live harness.
- Await `checkServer`, every harness I/O method (`listTools`, `callTool`, `listResources`, `readResource`, `listPrompts`, `getPrompt`, `sendRawRequest`), and the four `expect*` helpers.
- `McpServerHarness.start` throws `McpHandshakeException` (process already killed): missing executable (`failed to start the server process`), handshake timeout (`did not answer the initialize request within …`), malformed initialize (`malformed result`), unsupported protocol version (`cannot assess this server`). `pid` is null if the process never started.
- `checkServer` does **not** throw those. A dead command becomes `report.errors` with rule `initialize/handshake` (or `initialize/protocol-version` if the server answered with a version this client cannot speak).
- Each harness request is bounded by the `timeout` given to `start` (default 10s). A stuck server throws `TimeoutException` with `MCP request "<method>" did not complete within …`. Pagination (`listTools` / `listResources` / `listPrompts`) throws `StateError` if a cursor repeats (`returned the cursor "…" a second time`).
- `callTool`: in-band failure is `CallToolResult.isError == true` (nullable `bool?`; do not use it as a raw condition). Protocol-level failure throws `RpcException` from `package:json_rpc_2/json_rpc_2.dart`. `expectToolCallFails` only accepts `isError: true`; an `RpcException` propagates. `expectToolCallSucceeds` fails the test on `isError`.
- `expectToolExists`, `expectToolCallSucceeds`, `expectToolCallFails`, `expectResourceExists` live in `package:mcp_probe/testing.dart`, not `mcp_probe.dart`.
- Result types (`CallToolResult`, `TextContent`, `Tool`, …) come from `package:dart_mcp/client.dart`, which this package does not re-export. Unwrapped APIs: `harness.connection`. `connection.ping()` defaults to 1s unless you pass `timeout: harness.timeout`.
- `Process.start` split: executable then `args`. Default `checkServer` is read-only; `callTools: true` invokes every named tool with `{}` (real side effects). stdio only. On Windows use `npx.cmd`, not `npx`.

## Mistakes

- **`start('dart run bin/server.dart')` as one string.** `McpHandshakeException: failed to start the server process`. Use `start('dart', args: ['run', 'bin/server.dart'])`.
- **`import 'package:mcp_probe/mcp_probe.dart'` then `expectToolExists`.** `Undefined name 'expectToolExists'`. Also import `package:mcp_probe/testing.dart`.
- **`import 'package:test/test.dart'` after adding only `mcp_probe`.** `Target of URI doesn't exist: 'package:test/test.dart'`. `test` is not transitive; add `dev:test`.
- **`expect(report.findings, isEmpty)`.** Fails on a clean server: passing rules are `ConformanceSeverity.info` findings. Gate on `report.errors` or `report.hasErrors`.
- **`on McpHandshakeException` around `checkServer`.** The catch never runs. Missing binary: `report.errors` with `initialize/handshake` and `failed to start the server process`. That exception is only from `McpServerHarness.start`.
- **`expect(harness.callTool('fail_tool'), throwsA(…))`.** It does not throw; `isError` is true. `expectToolCallSucceeds` then reports `Expected tool "fail_tool" to succeed, but it answered with an error`. Use `expectToolCallFails`. A protocol reject (`strict_args` with no args) **does** throw `RpcException` (`-32602`); `expectToolCallFails` will not swallow it.
- **`print` on the server, or first-time `dart run` resolution on stdout.** `start` still succeeds (`harness.stdoutNoise`). `checkServer` errors `stdio/clean-stdout`: `server wrote N non-protocol line(s) to stdout, first: "…"`. Log to stderr; run `dart pub get` before probing a `dart run` server.
- **Stuck method, default 10s too long to wait, or too short.** `TimeoutException after 0:00:03.000000: MCP request "tools/list" did not complete within 0:00:03.000000`. Pass `timeout:` to `start` / `checkServer`.
- **No `shutdown` after a successful `start`.** Child process stays alive. `tearDownAll(() => harness.shutdown())` or `addTearDown(harness.shutdown)` after `start` returns. `late` + failed `start` then `harness.shutdown()` in `tearDownAll` is `LateInitializationError`.

## Layout

- `lib/mcp_probe.dart` — `McpServerHarness`, `harnessVersion`, `checkServer`, `ConformanceRules`, `ConformanceReport`, `ConformanceFinding`, `ConformanceSeverity`, `McpHandshakeException`
- `lib/testing.dart` — the four `expect*` helpers
- `lib/src/` — implementation; new public names go through the two libraries above
- `bin/mcp_probe.dart` — `mcp_probe check [--format markdown|json] [--fail-on error|warning|info] <command> [args…]`
- `example/server_test.dart` — copyable suite; `example/mcp_probe_example.dart`, `example/probe_demo.dart`
- `test/` — package tests; `test/fixtures/` — servers they launch
- `action.yml` — composite Action, required input `command`
- `dart test` — package tests. `dart test example/server_test.dart` — the copyable suite. `dart run example/probe_demo.dart` — four fixture reports. `dart run example/mcp_probe_example.dart` — Markdown report of the well-behaved fixture. `dart analyze`
- In `lib/`, relative imports. Bump `harnessVersion` in `lib/src/harness.dart` in the same edit as `version:` in `pubspec.yaml` (`test/harness_version_test.dart` compares them)
