/// A fixture that behaves correctly at the protocol level but also writes
/// log lines to stdout, which the stdio transport forbids.
library;

import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  print('starting up, this log line does not belong on stdout');
  NoisyStdoutServer(stdioChannel(input: stdin, output: stdout));
  print('ready');
}

base class NoisyStdoutServer extends MCPServer with ToolsSupport {
  NoisyStdoutServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'noisy_stdout', version: '1.0.0'),
      ) {
    registerTool(
      Tool(
        name: 'noop',
        description: 'Does nothing.',
        inputSchema: Schema.object(),
      ),
      (request) => CallToolResult(content: [TextContent(text: 'ok')]),
    );
  }
}
