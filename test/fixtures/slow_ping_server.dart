/// A deliberately slow fixture written without dart_mcp: it answers the
/// initialize request immediately, declaring no capabilities, then delays
/// its `ping` response by 1.5 seconds. Every other request, including
/// unknown methods, is answered immediately.
///
/// Exercises `_checkPing` honoring the caller's configured `timeout` instead
/// of the 1-second default built into `ServerConnection.ping`.
library;

import 'dart:convert';
import 'dart:io';

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((
    line,
  ) async {
    final message = jsonDecode(line) as Map<String, dynamic>;
    final id = message['id'] as Object?;
    final method = message['method'] as String?;
    if (id == null) return; // notifications need no response
    if (method == 'initialize') {
      final params = message['params'] as Map<String, dynamic>;
      stdout.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': params['protocolVersion'],
            'capabilities': <String, Object?>{},
            'serverInfo': {'name': 'slow_ping', 'version': '1.0.0'},
          },
        }),
      );
    } else if (method == 'ping') {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      stdout.writeln(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': <String, Object?>{}}),
      );
    } else {
      stdout.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32601, 'message': 'Method not found'},
        }),
      );
    }
  });
}
