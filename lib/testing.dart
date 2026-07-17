/// Expectation helpers for testing MCP servers with `package:test`.
///
/// This entrypoint is separate from `package:mcp_probe/mcp_probe.dart` so
/// that only code which actually asserts inside tests pulls in the
/// `package:test` surface; the harness and the conformance checks do not
/// need it.
library;

export 'src/matchers.dart'
    show
        expectResourceExists,
        expectToolCallFails,
        expectToolCallSucceeds,
        expectToolExists;
