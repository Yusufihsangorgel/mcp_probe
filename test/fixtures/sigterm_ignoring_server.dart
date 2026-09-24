/// A valid MCP server that stays alive after its stdio connection closes and
/// ignores SIGTERM, allowing the harness's SIGKILL escalation to be tested.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  ProcessSignal.sigterm.watch().listen((_) {});
  Timer.periodic(const Duration(days: 1), (_) {});
  SigtermIgnoringServer(stdioChannel(input: stdin, output: stdout));
}

base class SigtermIgnoringServer extends MCPServer {
  SigtermIgnoringServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'sigterm_ignoring',
          version: '1.0.0',
        ),
      );
}
