/// A fixture that declares the tools capability but never registers a tool,
/// so `tools/list` answers with an empty list.
library;

import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  DeclaresButEmptyServer(stdioChannel(input: stdin, output: stdout));
}

base class DeclaresButEmptyServer extends MCPServer with ToolsSupport {
  DeclaresButEmptyServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'declares_but_empty',
          version: '1.0.0',
        ),
      );
}
