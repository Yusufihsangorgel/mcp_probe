/// Test harness and conformance checks for MCP servers, built on the
/// official `dart_mcp` client.
///
/// [McpServerHarness] runs an MCP server as a child process and exposes the
/// `dart_mcp` client API for it with per-request timeouts and guaranteed
/// process cleanup. [checkServer] runs a fixed set of conformance rules
/// against a server command and returns a [ConformanceReport]. The
/// `expect...` helpers integrate with `package:test`.
library;

export 'src/conformance.dart' show ConformanceRules, checkServer;
export 'src/exceptions.dart' show McpHandshakeException;
export 'src/harness.dart' show McpServerHarness, harnessVersion;
export 'src/matchers.dart'
    show
        expectResourceExists,
        expectToolCallFails,
        expectToolCallSucceeds,
        expectToolExists;
export 'src/report.dart'
    show ConformanceFinding, ConformanceReport, ConformanceSeverity;
