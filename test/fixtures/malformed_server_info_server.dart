/// A deliberately broken fixture: answers initialize with non-string
/// `serverInfo.name` and `serverInfo.version` values.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  MalformedServerInfoServer(stdioChannel(input: stdin, output: stdout));
}

base class MalformedServerInfoServer extends MCPServer {
  MalformedServerInfoServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'ignored', version: 'ignored'),
      );

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);
    return InitializeResult.fromMap({
      'protocolVersion': result.protocolVersion!.versionString,
      'capabilities': result.capabilities,
      'serverInfo': {'name': 42, 'version': 7},
    });
  }
}
