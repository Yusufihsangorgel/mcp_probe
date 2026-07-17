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
