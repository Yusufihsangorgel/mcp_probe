/// A deliberately broken fixture: answers initialize with a protocol version
/// string no client recognizes.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  BadProtocolVersionServer(stdioChannel(input: stdin, output: stdout));
}

base class BadProtocolVersionServer extends MCPServer {
  BadProtocolVersionServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'bad_protocol_version',
          version: '1.0.0',
        ),
      );

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);
    return InitializeResult.fromMap({
      'protocolVersion': '2099-12-31',
      'capabilities': result.capabilities,
      'serverInfo': result.serverInfo,
    });
  }
}
