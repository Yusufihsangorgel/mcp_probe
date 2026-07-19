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
