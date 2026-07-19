/// An MCP server that returns its tools across two pages, to exercise the
/// harness following `nextCursor`.
///
/// Page one returns `tool_a` with a cursor; page two returns `tool_b` with no
/// cursor. A harness that stops after the first page would only ever see
/// `tool_a`.
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
        implementation: Implementation(name: 'paginated_tools', version: '1.0.0'),
        instructions: 'Fixture server that paginates tools/list.',
      );

  static final _toolA = Tool(
    name: 'tool_a',
    description: 'First page tool.',
    inputSchema: Schema.object(),
  );
  static final _toolB = Tool(
    name: 'tool_b',
    description: 'Second page tool.',
    inputSchema: Schema.object(),
  );

  @override
  // Deliberately replaces the default list to serve a fixed two-page response.
  // ignore: must_call_super
  FutureOr<ListToolsResult> listTools([ListToolsRequest? request]) {
    final cursor = request?.cursor;
    if (cursor == null) {
      return ListToolsResult(tools: [_toolA], nextCursor: Cursor('page2'));
    }
    return ListToolsResult(tools: [_toolB]);
  }
}
