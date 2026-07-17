import 'dart:async';

import 'package:dart_mcp/client.dart';
import 'package:json_rpc_2/error_code.dart' as error_code;
import 'package:json_rpc_2/json_rpc_2.dart' show RpcException;
import 'package:mcp_probe/mcp_probe.dart';
import 'package:test/test.dart';

import 'fixture_helpers.dart';

void main() {
  group('with the well-behaved fixture', () {
    late McpServerHarness harness;

    setUpAll(() async {
      harness = await startFixture('well_behaved_server');
    });

    tearDownAll(() => harness.shutdown());

    test('reports serverInfo from the handshake', () {
      expect(harness.serverInfo.name, 'well_behaved');
      expect(harness.serverInfo.version, '1.2.3');
    });

    test('reports the declared capabilities', () {
      expect(harness.serverCapabilities.tools, isNotNull);
      expect(harness.serverCapabilities.resources, isNotNull);
      expect(harness.serverCapabilities.prompts, isNotNull);
    });

    test('negotiates a supported protocol version', () {
      expect(harness.protocolVersion, isNotNull);
      expect(harness.protocolVersion!.isSupported, isTrue);
    });

    test('lists tools', () async {
      final result = await harness.listTools();
      final names = [for (final tool in result.tools) tool.name];
      expect(names, containsAll(['echo', 'fail_tool', 'read_env']));
    });

    test('calls a tool and returns its content', () async {
      final result = await harness.callTool('echo', arguments: {'text': 'hi'});
      expect(result.isError, isNot(isTrue));
      expect((result.content.single as TextContent).text, 'hi');
    });

    test('surfaces in-band tool errors on the result', () async {
      final result = await harness.callTool('fail_tool');
      expect(result.isError, isTrue);
    });

    test('answers unknown tool names with an in-band error', () async {
      final result = await harness.callTool('no_such_tool');
      expect(result.isError, isTrue);
    });

    test('lists and reads resources', () async {
      final resources = await harness.listResources();
      expect([
        for (final resource in resources.resources) resource.uri,
      ], contains('probe://greeting'));
      final read = await harness.readResource('probe://greeting');
      expect(
        (read.contents.single as TextResourceContents).text,
        'hello from fixture',
      );
    });

    test('lists and gets prompts', () async {
      final prompts = await harness.listPrompts();
      expect([
        for (final prompt in prompts.prompts) prompt.name,
      ], contains('greet'));
      final prompt = await harness.getPrompt(
        'greet',
        arguments: {'name': 'Ada'},
      );
      expect(prompt.messages, hasLength(1));
      expect(
        (prompt.messages.single.content as TextContent).text,
        contains('Ada'),
      );
    });

    test('raw requests to unknown methods throw RpcException', () {
      expect(
        harness.sendRawRequest('there/is-no-such-method'),
        throwsA(
          isA<RpcException>().having(
            (e) => e.code,
            'code',
            error_code.METHOD_NOT_FOUND,
          ),
        ),
      );
    });
  });

  test('passes extra environment variables to the server process', () async {
    final harness = await startFixture(
      'well_behaved_server',
      environment: {'MCP_PROBE_ENV': 'probe-value'},
    );
    addTearDown(harness.shutdown);
    final result = await harness.callTool('read_env');
    expect((result.content.single as TextContent).text, 'probe-value');
  });

  test('shutdown terminates the server process', () async {
    final harness = await startFixture('well_behaved_server');
    final pid = harness.pid;
    expect(await processIsAlive(pid), isTrue);
    await harness.shutdown();
    expect(await processIsAlive(pid), isFalse);
  });

  test('shutdown can be called more than once', () async {
    final harness = await startFixture('well_behaved_server');
    final first = await harness.shutdown();
    final second = await harness.shutdown();
    expect(second, first);
  });

  test('start times out and kills a server that never answers', () async {
    McpHandshakeException? caught;
    try {
      await startFixture('silent_server', timeout: const Duration(seconds: 2));
    } on McpHandshakeException catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(caught!.message, contains('did not answer'));
    expect(caught.rawInitializeResult, isNull);
    expect(caught.pid, isNotNull);
    expect(await processIsAlive(caught.pid!), isFalse);
  });

  test('start rejects unsupported protocol versions and cleans up', () async {
    McpHandshakeException? caught;
    try {
      await startFixture('bad_protocol_version_server');
    } on McpHandshakeException catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(caught!.rawInitializeResult?['protocolVersion'], '2099-12-31');
    expect(await processIsAlive(caught.pid!), isFalse);
  });

  test('requests time out when the server stops answering', () async {
    final harness = await startFixture(
      'unresponsive_methods_server',
      timeout: const Duration(seconds: 3),
    );
    addTearDown(harness.shutdown);
    expect(harness.listTools(), throwsA(isA<TimeoutException>()));
  });

  test('shutdown kills a server that ignores the connection close', () async {
    final harness = await startFixture(
      'unresponsive_methods_server',
      timeout: const Duration(seconds: 3),
    );
    final pid = harness.pid;
    await harness.shutdown(killAfter: const Duration(seconds: 1));
    expect(await processIsAlive(pid), isFalse);
  });
}
