/// A deliberately broken fixture written without dart_mcp: it answers the
/// initialize request correctly (declaring the tools capability), then
/// silently ignores every other request, including unknown methods.
///
/// Exercises the per-request timeout in the harness and the
/// `capabilities/tools-listable` and `jsonrpc/method-not-found` conformance
/// rules.
library;

import 'dart:convert';
import 'dart:io';

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    final message = jsonDecode(line) as Map<String, dynamic>;
    final id = message['id'] as Object?;
    final method = message['method'] as String?;
    // Notifications need no response; requests are answered only for
    // initialize and deliberately dropped otherwise.
    if (id == null || method != 'initialize') return;
    final params = message['params'] as Map<String, dynamic>;
    stdout.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'protocolVersion': params['protocolVersion'],
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': {'name': 'unresponsive_methods', 'version': '1.0.0'},
        },
      }),
    );
  });
}
