import 'package:dart_mcp/client.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// Fails the current test if the server behind [harness] does not list a
/// tool named [name].
Future<void> expectToolExists(McpServerHarness harness, String name) async {
  final result = await harness.listTools();
  final names = [
    for (final tool in result.tools)
      _describe((tool as Map<String, Object?>)['name'], '<unnamed>'),
  ];
  if (!names.contains(name)) {
    fail(
      'Expected the server to list a tool named "$name". '
      'Listed tools: ${names.isEmpty ? '(none)' : names.join(', ')}.',
    );
  }
}

/// Calls the tool [name] with [arguments] and fails the current test if the
/// call reports an in-band error.
///
/// Returns the [CallToolResult] so the test can make further assertions on
/// the content.
Future<CallToolResult> expectToolCallSucceeds(
  McpServerHarness harness,
  String name, {
  Map<String, Object?>? arguments,
}) async {
  final result = await harness.callTool(name, arguments: arguments);
  if (result.isError ?? false) {
    fail(
      'Expected tool "$name" to succeed, but it answered with an error: '
      '${_contentSummary(result)}',
    );
  }
  return result;
}

/// Calls the tool [name] with [arguments] and fails the current test unless
/// the call reports an in-band error (`isError: true`).
///
/// A protocol-level `RpcException` is not treated as a pass: the MCP
/// specification wants tool failures reported in-band, so an exception
/// propagates and fails the test with its own message.
Future<CallToolResult> expectToolCallFails(
  McpServerHarness harness,
  String name, {
  Map<String, Object?>? arguments,
}) async {
  final result = await harness.callTool(name, arguments: arguments);
  if (!(result.isError ?? false)) {
    fail(
      'Expected tool "$name" to answer with an in-band error, but it '
      'succeeded: ${_contentSummary(result)}',
    );
  }
  return result;
}

/// Fails the current test if the server behind [harness] does not list a
/// resource with the given [uri].
Future<void> expectResourceExists(McpServerHarness harness, String uri) async {
  final result = await harness.listResources();
  final uris = [
    for (final resource in result.resources)
      _describe((resource as Map<String, Object?>)['uri'], '<no uri>'),
  ];
  if (!uris.contains(uri)) {
    fail(
      'Expected the server to list a resource with URI "$uri". '
      'Listed resources: ${uris.isEmpty ? '(none)' : uris.join(', ')}.',
    );
  }
}

/// Renders a server-provided value for a failure message without assuming
/// it has the type the spec requires.
String _describe(Object? value, String whenNull) =>
    value == null ? whenNull : value.toString();

String _contentSummary(CallToolResult result) {
  final parts = [
    for (final content in result.content)
      content.isText ? (content as TextContent).text : content.type,
  ];
  return parts.isEmpty ? '(no content)' : parts.join(' | ');
}
