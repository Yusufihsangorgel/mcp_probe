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
