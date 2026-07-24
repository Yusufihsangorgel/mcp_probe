## 0.6.0

- Seal the exported types. `ConformanceFinding`, `ConformanceReport`,
  `McpServerHarness` and `McpHandshakeException` carried no class modifier, so
  a later freeze would have made every field added to a report a breaking
  change for anyone who had subclassed it. None is meant to be subtyped and
  nothing in the package, its tests or its example does. `ConformanceRules` was
  already `abstract final`. No behaviour change.

## 0.5.1

- Fix `utilities/ping` ignoring the caller's configured `timeout`. `_checkPing`
  called `connection.ping()` with no arguments, which falls back to the
  1-second default on `dart_mcp`'s `ServerConnection.ping`, so any server
  whose ping round-trip took longer than 1 second failed this check even when
  it answered well inside the `timeout` passed to `checkServer` or
  `McpServerHarness.start`. It now passes `harness.timeout` through, matching
  every other request the harness makes.

## 0.5.0

- A composite GitHub Action, so a repository can gate its pull requests on MCP
  conformance in a few lines: `uses: Yusufihsangorgel/mcp_probe@v1` with a
  `command`, and optional `fail-on` and `format`. It sets up Dart, activates the
  CLI, and runs the check, failing the job when a finding at or above `fail-on`
  is present. Inputs are passed through the environment rather than interpolated
  into the shell, so a value cannot inject script. The package's own CI now
  exercises the action against a conforming and a non-conforming fixture on
  every push, so a change that breaks it fails CI.
- README notes a real `dart run` gotcha: `dart run` prints a resolution line to
  stdout the first time, which pollutes a server launched that way, so run
  `dart pub get` before checking such a server. A compiled, Node or Python
  server has nothing to resolve.

## 0.4.0

- Machine-readable output and a configurable gate, which is what makes the CLI a
  real CI step rather than something a human reads. `ConformanceReport.toJson()`
  (and `ConformanceFinding.toJson()`) render the report as a JSON-serializable
  map: the probed command, the server identity, a `summary` count per severity,
  and the full findings list. The CLI gains `--format json` to print it and
  `--fail-on error|warning|info` to choose the severity at which the exit code
  becomes 1 (default `error`), so a pipeline can fail on a warning and capture a
  structured report in one run. Invalid flags exit 64 with a usage message.

## 0.3.3

- Install instructions now say `pub add` instead of pinning a version. The
  pinned number was stale by several releases and would have been stale again
  after the next one: the README ships frozen in the archive, so a hand-edited
  version line is wrong the moment anything is published. This one cannot go
  out of date.

## 0.3.2

- `example/probe_demo.dart` prints a real report without a server of your own.
  It probes four servers that ship with the package: one that behaves and three
  that break something specific, so the output shows what a failure looks like
  before you have written anything to fail.
  The interesting one is a server that speaks the protocol correctly and is
  still unusable, because a `print` on the way up puts a line on stdout where
  the transport expects only JSON-RPC. Its own tests would not catch that; what
  a user sees is a client that will not connect.
- `example/README.md` covers reading the report, pointing the probe at your own
  command, the `mcp_probe check` front end for a pipeline, and asserting your
  server's actual behaviour with the `testing.dart` helpers.
- `test/readme_snippet_test.dart` compiles the snippet that README prints. It
  never runs, it only has to analyse, which is enough to keep a copied example
  from drifting away from the API it is describing.

## 0.3.1

- Declare the diagram in `pubspec.yaml` so pub.dev renders it on the package
  page. It was already in the repository and the README, but pub.dev shows only
  what the `screenshots:` field points at, so the page opened with prose where
  the picture should have been.

## 0.3.0

- Add the `utilities/ping` conformance rule. MCP requires a server to answer a
  `ping` request promptly with an empty result; `checkServer` and the CLI now
  send one and report an error if the server times out or answers with a
  protocol error, so a server that stops responding to liveness pings is caught.

## 0.2.0

- Add a command-line tool. `dart pub global activate mcp_probe` installs an
  `mcp_probe check <command> [args...]` executable that runs a server over stdio,
  prints each conformance finding, and exits non-zero if any check reports an
  error, so it drops into a CI step without writing any Dart.

## 0.1.3

- `listTools`, `listResources` and `listPrompts` now follow `nextCursor`
  pagination and return every page combined. Previously only the first page was
  fetched, so a conformance run against a paginated server validated just those
  items and could report the server green without ever seeing the rest.

## 0.1.2

- Docs: tightened the README wording and visuals.

## 0.1.1

- Expand the package description to name what the package does in the
  words people search for. No code changes.

## 0.1.0

- Initial release.
- `McpServerHarness`: runs an MCP server as a child process over stdio, with
  per-request timeouts and guaranteed process cleanup.
- `checkServer` and `ConformanceReport`: conformance rules for the initialize
  handshake, declared capabilities, tool definitions, and JSON-RPC error
  behavior, with Markdown rendering.
- `package:test` helpers in the `package:mcp_probe/testing.dart` entrypoint:
  `expectToolExists`, `expectToolCallSucceeds`, `expectToolCallFails`,
  `expectResourceExists`.
