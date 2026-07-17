/// A deliberately broken fixture: answers initialize with a non-string
/// `protocolVersion`, which makes the dart_mcp client fail with a TypeError
/// while decoding the result.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  MalformedProtocolVersionServer(stdioChannel(input: stdin, output: stdout));
}

base class MalformedProtocolVersionServer extends MCPServer {
  MalformedProtocolVersionServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'malformed_protocol_version',
          version: '1.0.0',
        ),
      );

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);
    return InitializeResult.fromMap({
      'protocolVersion': 42,
      'capabilities': result.capabilities,
      'serverInfo': result.serverInfo,
    });
  }
}
