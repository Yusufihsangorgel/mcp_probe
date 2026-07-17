/// A deliberately broken fixture: answers initialize with empty
/// `serverInfo.name` and `serverInfo.version`.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  EmptyServerInfoServer(stdioChannel(input: stdin, output: stdout));
}

base class EmptyServerInfoServer extends MCPServer {
  EmptyServerInfoServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'ignored', version: 'ignored'),
      );

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);
    return InitializeResult.fromMap({
      'protocolVersion': result.protocolVersion!.versionString,
      'capabilities': result.capabilities,
      'serverInfo': Implementation.fromMap({'name': '', 'version': ''}),
    });
  }
}
