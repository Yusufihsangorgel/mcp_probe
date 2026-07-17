/// A deliberately broken fixture for the per-tool conformance rules.
///
/// Lists three malformed tools: `no_schema` (no inputSchema at all),
/// `bad_root` (inputSchema root type is not "object"), and an unnamed tool.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  SchemalessToolServer(stdioChannel(input: stdin, output: stdout));
}

base class SchemalessToolServer extends MCPServer with ToolsSupport {
  SchemalessToolServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'schemaless_tool',
          version: '1.0.0',
        ),
      ) {
    registerTool(
      Tool.fromMap({'name': 'no_schema'}),
      _ok,
      validateArguments: false,
    );
    registerTool(
      Tool.fromMap({
        'name': 'bad_root',
        'inputSchema': {'type': 'string'},
      }),
      _ok,
      validateArguments: false,
    );
  }

  CallToolResult _ok(CallToolRequest request) =>
      CallToolResult(content: [TextContent(text: 'ok')]);

  @override
  FutureOr<ListToolsResult> listTools([ListToolsRequest? request]) async {
    final result = await super.listTools(request);
    return ListToolsResult(
      tools: [
        ...result.tools,
        // A tool with no name, which ToolsSupport cannot register itself.
        Tool.fromMap({
          'inputSchema': {'type': 'object'},
        }),
      ],
    );
  }
}
