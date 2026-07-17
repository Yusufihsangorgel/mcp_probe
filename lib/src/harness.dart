import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/stdio.dart';

import 'exceptions.dart';

/// The version reported to servers as the harness client version.
const String harnessVersion = '0.1.0';

/// Runs an MCP server as a child process and talks to it over stdio using the
/// `dart_mcp` client, so tests can exercise the server end to end.
///
/// Create one with [start], which spawns the process, performs the MCP
/// initialize handshake, and sends the `initialized` notification. After that
/// the list and call methods delegate to the underlying [ServerConnection],
/// adding a per-request [timeout] so a stuck server fails the test instead of
/// hanging it.
///
/// Always call [shutdown] when done, typically from `tearDown` or
/// `tearDownAll`. It closes the connection and guarantees the child process
/// is dead, escalating to SIGTERM and then SIGKILL if the server does not
/// exit on its own.
class McpServerHarness {
  McpServerHarness._(
    this._process,
    this._client,
    this.connection,
    this.initializeResult,
    this.timeout,
    this._stderrBuffer,
  );

  final Process _process;
  final MCPClient _client;
  final StringBuffer _stderrBuffer;
  bool _shutdown = false;

  /// The live `dart_mcp` connection to the server.
  ///
  /// Use this directly for APIs the harness does not wrap, such as resource
  /// subscriptions or progress notifications.
  final ServerConnection connection;

  /// The raw result of the initialize handshake.
  final InitializeResult initializeResult;

  /// How long [start] waited for the handshake and how long each request is
  /// given before it fails with a [TimeoutException].
  final Duration timeout;

  /// The pid of the server process.
  int get pid => _process.pid;

  /// Completes with the server process exit code once it exits.
  Future<int> get exitCode => _process.exitCode;

  /// The `serverInfo` reported by the server during initialization.
  Implementation get serverInfo => initializeResult.serverInfo;

  /// The capabilities the server declared during initialization.
  ServerCapabilities get serverCapabilities => initializeResult.capabilities;

  /// The negotiated protocol version.
  ProtocolVersion? get protocolVersion => initializeResult.protocolVersion;

  /// Everything the server has written to stderr so far.
  String get serverStderr => _stderrBuffer.toString();

  /// Starts `command args` as a child process, connects to it as an MCP
  /// server over stdio, and completes the initialize handshake.
  ///
  /// [environment] is added to the parent environment for the child process.
  /// [timeout] bounds the handshake and every later request made through the
  /// harness. [clientInfo] overrides the client name and version reported to
  /// the server.
  ///
  /// Throws [McpHandshakeException] if the server does not answer the
  /// handshake within [timeout], closes the connection early, or negotiates
  /// an unsupported protocol version. The process is killed before the
  /// exception is thrown.
  static Future<McpServerHarness> start(
    String command, {
    List<String> args = const <String>[],
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 10),
    Implementation? clientInfo,
  }) async {
    final process = await Process.start(
      command,
      args,
      environment: environment,
      workingDirectory: workingDirectory,
    );
    final stderrBuffer = StringBuffer();
    process.stderr
        .transform(utf8.decoder)
        .listen(stderrBuffer.write, onError: (Object _) {});

    final client = MCPClient(
      clientInfo ?? Implementation(name: 'mcp_probe', version: harnessVersion),
    );
    final connection = client.connectServer(
      stdioChannel(input: process.stdout, output: process.stdin),
    );

    Never fail(String message, {Map<String, Object?>? rawInitializeResult}) {
      throw McpHandshakeException(
        message,
        pid: process.pid,
        rawInitializeResult: rawInitializeResult,
        serverStderr: stderrBuffer.toString(),
      );
    }

    final InitializeResult result;
    final initializeFuture = connection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: client.capabilities,
        clientInfo: client.implementation,
      ),
    );
    try {
      result = await initializeFuture.timeout(timeout);
    } on TimeoutException {
      initializeFuture.ignore();
      await _forceStop(process, connection);
      fail('server did not answer the initialize request within $timeout');
    } catch (error) {
      await _forceStop(process, connection);
      fail('initialize handshake failed: $error');
    }

    final rawResult = result as Map<String, Object?>;
    final version = result.protocolVersion;
    if (version == null || !version.isSupported) {
      // dart_mcp already shut the connection down in this case.
      await _forceStop(process, connection);
      fail(
        'server answered initialize with unsupported protocol version '
        '"${rawResult['protocolVersion']}"',
        rawInitializeResult: rawResult,
      );
    }

    connection.notifyInitialized();
    return McpServerHarness._(
      process,
      client,
      connection,
      result,
      timeout,
      stderrBuffer,
    );
  }

  /// Lists the tools exposed by the server.
  Future<ListToolsResult> listTools() =>
      _request('tools/list', connection.listTools());

  /// Calls the tool [name] with [arguments].
  ///
  /// Returns the raw [CallToolResult]. Check `isError` to see whether the
  /// tool reported an in-band failure; protocol-level failures surface as
  /// thrown exceptions.
  Future<CallToolResult> callTool(
    String name, {
    Map<String, Object?>? arguments,
  }) => _request(
    'tools/call $name',
    connection.callTool(CallToolRequest(name: name, arguments: arguments)),
  );

  /// Lists the resources exposed by the server.
  Future<ListResourcesResult> listResources() =>
      _request('resources/list', connection.listResources());

  /// Reads the resource at [uri].
  Future<ReadResourceResult> readResource(String uri) => _request(
    'resources/read $uri',
    connection.readResource(ReadResourceRequest(uri: uri)),
  );

  /// Lists the prompts exposed by the server.
  Future<ListPromptsResult> listPrompts() =>
      _request('prompts/list', connection.listPrompts());

  /// Gets the prompt [name] with [arguments].
  Future<GetPromptResult> getPrompt(
    String name, {
    Map<String, Object?>? arguments,
  }) => _request(
    'prompts/get $name',
    connection.getPrompt(GetPromptRequest(name: name, arguments: arguments)),
  );

  /// Sends a request for [method] with no parameters and returns the raw
  /// result map.
  ///
  /// Useful for probing how a server reacts to methods it does not
  /// implement; a compliant server answers with a JSON-RPC error, which
  /// surfaces here as a thrown `RpcException`.
  Future<Map<String, Object?>?> sendRawRequest(String method) async {
    final result = await _request(
      method,
      connection.sendRequest<Result?>(method),
    );
    return result as Map<String, Object?>?;
  }

  /// Shuts the connection down and makes sure the server process exits.
  ///
  /// First closes the MCP connection, then waits [killAfter] for the process
  /// to exit on its own. If it does not, sends SIGTERM, and SIGKILL as a
  /// last resort. Returns the process exit code. Safe to call more than
  /// once.
  Future<int> shutdown({
    Duration killAfter = const Duration(seconds: 3),
  }) async {
    if (!_shutdown) {
      _shutdown = true;
      try {
        await _client.shutdown().timeout(killAfter);
      } catch (_) {
        // The connection may already be broken; process cleanup below is
        // what matters.
      }
    }
    try {
      return await _process.exitCode.timeout(killAfter);
    } on TimeoutException {
      _process.kill();
      try {
        return await _process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _process.kill(ProcessSignal.sigkill);
        return _process.exitCode;
      }
    }
  }

  Future<T> _request<T>(String description, Future<T> future) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      future.ignore();
      throw TimeoutException(
        'MCP request "$description" did not complete within $timeout',
        timeout,
      );
    }
  }

  static Future<void> _forceStop(
    Process process,
    ServerConnection connection,
  ) async {
    try {
      await connection.shutdown().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } catch (_) {
      // Best effort; killing the process below is the real cleanup.
    }
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }
}
