import 'dart:async';

import 'package:json_rpc_2/error_code.dart' as error_code;
import 'package:json_rpc_2/json_rpc_2.dart' show RpcException;

import 'exceptions.dart';
import 'harness.dart';
import 'report.dart';

/// The names of the conformance rules applied by [checkServer], as they
/// appear in [ConformanceFinding.rule].
abstract final class ConformanceRules {
  /// The server must answer the initialize request.
  static const handshake = 'initialize/handshake';

  /// The server must answer with a recognized MCP protocol version.
  static const protocolVersion = 'initialize/protocol-version';

  /// `serverInfo.name` must be a non-empty string.
  static const serverInfoName = 'initialize/server-info-name';

  /// `serverInfo.version` must be a non-empty string.
  static const serverInfoVersion = 'initialize/server-info-version';

  /// A server that declares the `tools` capability must answer `tools/list`.
  static const toolsListable = 'capabilities/tools-listable';

  /// A server that declares the `tools` capability should list at least one
  /// tool.
  static const toolsNonEmpty = 'capabilities/tools-nonempty';

  /// Every listed tool must have a non-empty `name`.
  static const toolName = 'tools/name';

  /// Every listed tool must have an `inputSchema` whose root is a JSON
  /// object schema (`"type": "object"`).
  static const toolInputSchema = 'tools/input-schema';

  /// Optional smoke call of each tool, enabled with `callTools: true`.
  static const toolCallSmoke = 'tools/call-smoke';

  /// A server that declares the `resources` capability must answer
  /// `resources/list`.
  static const resourcesListable = 'capabilities/resources-listable';

  /// A server that declares the `prompts` capability must answer
  /// `prompts/list`.
  static const promptsListable = 'capabilities/prompts-listable';

  /// Unknown methods must be answered with a JSON-RPC `method not found`
  /// error (-32601).
  static const methodNotFound = 'jsonrpc/method-not-found';
}

/// Starts `command args`, runs every conformance rule in [ConformanceRules]
/// against it, shuts it down, and returns the collected findings.
///
/// The checks are read-only by default: the server is initialized and its
/// tool, resource, and prompt lists are fetched, but nothing is invoked.
/// With [callTools] set to true, every listed tool is additionally called
/// once with empty arguments. Only enable that for servers whose tools are
/// safe to invoke: a smoke call is a real call and runs whatever side
/// effects the tool has.
///
/// A server that fails the handshake still produces a report (with an
/// `initialize/handshake` or `initialize/protocol-version` error) instead of
/// throwing, so conformance runs can be batched.
Future<ConformanceReport> checkServer(
  String command, {
  List<String> args = const <String>[],
  Map<String, String>? environment,
  String? workingDirectory,
  Duration timeout = const Duration(seconds: 10),
  bool callTools = false,
}) async {
  final commandLine = [command, ...args].join(' ');
  final findings = <ConformanceFinding>[];

  void add(ConformanceSeverity severity, String rule, String message) {
    findings.add(
      ConformanceFinding(severity: severity, rule: rule, message: message),
    );
  }

  final McpServerHarness harness;
  try {
    harness = await McpServerHarness.start(
      command,
      args: args,
      environment: environment,
      workingDirectory: workingDirectory,
      timeout: timeout,
    );
  } on McpHandshakeException catch (e) {
    final raw = e.rawInitializeResult;
    if (raw != null) {
      add(
        ConformanceSeverity.error,
        ConformanceRules.protocolVersion,
        e.message,
      );
    } else {
      add(ConformanceSeverity.error, ConformanceRules.handshake, e.message);
    }
    return ConformanceReport(
      command: commandLine,
      protocolVersion: raw?['protocolVersion'] as String?,
      findings: findings,
    );
  }

  final rawResult = harness.initializeResult as Map<String, Object?>;
  final rawServerInfo =
      rawResult['serverInfo'] as Map<String, Object?>? ??
      const <String, Object?>{};
  final serverName = rawServerInfo['name'] as String?;
  final serverVersion = rawServerInfo['version'] as String?;
  final protocolVersion = rawResult['protocolVersion'] as String?;

  try {
    add(
      ConformanceSeverity.info,
      ConformanceRules.handshake,
      'server answered the initialize request',
    );
    add(
      ConformanceSeverity.info,
      ConformanceRules.protocolVersion,
      'negotiated protocol version $protocolVersion',
    );

    if (serverName == null || serverName.isEmpty) {
      add(
        ConformanceSeverity.error,
        ConformanceRules.serverInfoName,
        'serverInfo.name is missing or empty',
      );
    } else {
      add(
        ConformanceSeverity.info,
        ConformanceRules.serverInfoName,
        'serverInfo.name is "$serverName"',
      );
    }
    if (serverVersion == null || serverVersion.isEmpty) {
      add(
        ConformanceSeverity.error,
        ConformanceRules.serverInfoVersion,
        'serverInfo.version is missing or empty',
      );
    } else {
      add(
        ConformanceSeverity.info,
        ConformanceRules.serverInfoVersion,
        'serverInfo.version is "$serverVersion"',
      );
    }

    await _checkTools(harness, add, callTools: callTools);
    await _checkListable(
      declared: harness.serverCapabilities.resources != null,
      rule: ConformanceRules.resourcesListable,
      what: 'resources',
      list: () async => (await harness.listResources()).resources.length,
      add: add,
    );
    await _checkListable(
      declared: harness.serverCapabilities.prompts != null,
      rule: ConformanceRules.promptsListable,
      what: 'prompts',
      list: () async => (await harness.listPrompts()).prompts.length,
      add: add,
    );
    await _checkMethodNotFound(harness, add);
  } finally {
    await harness.shutdown();
  }

  return ConformanceReport(
    command: commandLine,
    serverName: serverName,
    serverVersion: serverVersion,
    protocolVersion: protocolVersion,
    findings: findings,
  );
}

typedef _AddFinding =
    void Function(ConformanceSeverity severity, String rule, String message);

Future<void> _checkTools(
  McpServerHarness harness,
  _AddFinding add, {
  required bool callTools,
}) async {
  if (harness.serverCapabilities.tools == null) {
    add(
      ConformanceSeverity.info,
      ConformanceRules.toolsListable,
      'tools capability not declared, tool checks skipped',
    );
    return;
  }

  final List<Map<String, Object?>> rawTools;
  try {
    final result = await harness.listTools();
    rawTools = [for (final tool in result.tools) tool as Map<String, Object?>];
  } catch (e) {
    add(
      ConformanceSeverity.error,
      ConformanceRules.toolsListable,
      'tools capability is declared but tools/list failed: $e',
    );
    return;
  }
  add(
    ConformanceSeverity.info,
    ConformanceRules.toolsListable,
    'tools/list answered with ${rawTools.length} tool(s)',
  );

  if (rawTools.isEmpty) {
    add(
      ConformanceSeverity.warning,
      ConformanceRules.toolsNonEmpty,
      'tools capability is declared but tools/list returned no tools',
    );
    return;
  }

  var namesOk = true;
  var schemasOk = true;
  for (final (index, tool) in rawTools.indexed) {
    final name = tool['name'] as String?;
    final label = name == null || name.isEmpty ? 'tool at index $index' : name;
    if (name == null || name.isEmpty) {
      namesOk = false;
      add(
        ConformanceSeverity.error,
        ConformanceRules.toolName,
        '$label has a missing or empty name',
      );
    }
    final schema = tool['inputSchema'];
    if (schema is! Map) {
      schemasOk = false;
      add(
        ConformanceSeverity.error,
        ConformanceRules.toolInputSchema,
        '$label has no inputSchema object',
      );
    } else if (schema['type'] != 'object') {
      schemasOk = false;
      add(
        ConformanceSeverity.error,
        ConformanceRules.toolInputSchema,
        '$label has inputSchema root type "${schema['type']}", '
        'expected "object"',
      );
    }
  }
  if (namesOk) {
    add(
      ConformanceSeverity.info,
      ConformanceRules.toolName,
      'every tool has a non-empty name',
    );
  }
  if (schemasOk) {
    add(
      ConformanceSeverity.info,
      ConformanceRules.toolInputSchema,
      'every tool has an object-rooted inputSchema',
    );
  }

  if (!callTools) return;
  for (final tool in rawTools) {
    final name = tool['name'] as String?;
    if (name == null || name.isEmpty) continue;
    try {
      final result = await harness.callTool(
        name,
        arguments: const <String, Object?>{},
      );
      if (result.isError ?? false) {
        add(
          ConformanceSeverity.info,
          ConformanceRules.toolCallSmoke,
          'smoke call of "$name" answered with an in-band error, which is '
          'the expected shape for rejected arguments',
        );
      } else {
        add(
          ConformanceSeverity.info,
          ConformanceRules.toolCallSmoke,
          'smoke call of "$name" succeeded',
        );
      }
    } catch (e) {
      add(
        ConformanceSeverity.error,
        ConformanceRules.toolCallSmoke,
        'smoke call of "$name" failed at the protocol level: $e',
      );
    }
  }
}

Future<void> _checkListable({
  required bool declared,
  required String rule,
  required String what,
  required Future<int> Function() list,
  required _AddFinding add,
}) async {
  if (!declared) {
    add(
      ConformanceSeverity.info,
      rule,
      '$what capability not declared, check skipped',
    );
    return;
  }
  try {
    final count = await list();
    add(
      ConformanceSeverity.info,
      rule,
      '$what/list answered with $count item(s)',
    );
  } catch (e) {
    add(
      ConformanceSeverity.error,
      rule,
      '$what capability is declared but $what/list failed: $e',
    );
  }
}

Future<void> _checkMethodNotFound(
  McpServerHarness harness,
  _AddFinding add,
) async {
  const method = 'mcp_probe/does-not-exist';
  try {
    await harness.sendRawRequest(method);
    add(
      ConformanceSeverity.warning,
      ConformanceRules.methodNotFound,
      'server answered unknown method "$method" with a result instead of '
      'an error',
    );
  } on RpcException catch (e) {
    if (e.code == error_code.METHOD_NOT_FOUND) {
      add(
        ConformanceSeverity.info,
        ConformanceRules.methodNotFound,
        'unknown method was answered with JSON-RPC error -32601',
      );
    } else {
      add(
        ConformanceSeverity.warning,
        ConformanceRules.methodNotFound,
        'unknown method was answered with JSON-RPC error ${e.code}, '
        'expected -32601 (method not found)',
      );
    }
  } on TimeoutException {
    add(
      ConformanceSeverity.error,
      ConformanceRules.methodNotFound,
      'server did not answer unknown method "$method" at all',
    );
  }
}
