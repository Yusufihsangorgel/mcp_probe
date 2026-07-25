/// An MCP server that declares pagination and never advances: every
/// `tools/list` answer carries the same `nextCursor`.
///
/// This is what a server looks like when it wires up the field but ignores the
/// incoming cursor. A client that follows the cursor blindly never terminates,
/// so the harness has to notice the repeat and say so.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  PaginatedToolsServer(stdioChannel(input: stdin, output: stdout));
}

base class PaginatedToolsServer extends MCPServer with ToolsSupport {
  PaginatedToolsServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'paginated_tools',
          version: '1.0.0',
        ),
        instructions: 'Fixture server that paginates tools/list.',
      );

  static final _toolA = Tool(
    name: 'tool_a',
    description: 'First page tool.',
    inputSchema: Schema.object(),
  );

  @override
  // Deliberately replaces the default list to serve a fixed two-page response.
  // ignore: must_call_super
  FutureOr<ListToolsResult> listTools([ListToolsRequest? request]) {
    return ListToolsResult(tools: [_toolA], nextCursor: Cursor('same'));
  }
}
