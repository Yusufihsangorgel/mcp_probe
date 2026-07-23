import 'package:mcp_probe/mcp_probe.dart';
import 'package:test/test.dart';

import 'fixture_helpers.dart';

void main() {
  group('against the well-behaved fixture', () {
    late ConformanceReport report;

    setUpAll(() async {
      report = await checkFixture('well_behaved_server');
    });

    test('produces no errors or warnings', () {
      expect(report.errors, isEmpty);
      expect(report.warnings, isEmpty);
      expect(report.hasErrors, isFalse);
    });

    test('records every passing check as an info finding', () {
      final rules = {for (final finding in report.infos) finding.rule};
      expect(
        rules,
        containsAll([
          ConformanceRules.handshake,
          ConformanceRules.protocolVersion,
          ConformanceRules.serverInfoName,
          ConformanceRules.serverInfoVersion,
          ConformanceRules.toolsListable,
          ConformanceRules.toolName,
          ConformanceRules.toolInputSchema,
          ConformanceRules.resourcesListable,
          ConformanceRules.promptsListable,
          ConformanceRules.pingResponds,
          ConformanceRules.methodNotFound,
          ConformanceRules.cleanStdout,
        ]),
      );
    });

    test('records the server identity and probed command', () {
      expect(report.serverName, 'well_behaved');
      expect(report.serverVersion, '1.2.3');
      expect(report.protocolVersion, isNotNull);
      expect(report.command, contains('well_behaved_server.dart'));
    });

    test('does not call any tools by default', () {
      expect(
        report.findings.where(
          (finding) => finding.rule == ConformanceRules.toolCallSmoke,
        ),
        isEmpty,
      );
    });
  });

  test('smoke-calls every named tool when callTools is true', () async {
    final report = await checkFixture('well_behaved_server', callTools: true);
    final smoke = [
      for (final finding in report.findings)
        if (finding.rule == ConformanceRules.toolCallSmoke) finding,
    ];
    // The fixture has four tools: echo (rejects the empty arguments
    // in-band), fail_tool (fails in-band), read_env (succeeds), and
    // strict_args (rejects with JSON-RPC error -32602). All four shapes are
    // conformant.
    expect(smoke, hasLength(4));
    expect(report.hasErrors, isFalse);
    for (final finding in smoke) {
      expect(finding.severity, ConformanceSeverity.info);
    }
    expect(
      smoke.map((finding) => finding.message),
      anyElement(contains('-32602')),
    );
  });

  test('flags non-string serverInfo fields without throwing', () async {
    final report = await checkFixture('malformed_server_info_server');
    final errorsByRule = {
      for (final finding in report.errors) finding.rule: finding.message,
    };
    expect(
      errorsByRule[ConformanceRules.serverInfoName],
      contains('not a string (got int)'),
    );
    expect(
      errorsByRule[ConformanceRules.serverInfoVersion],
      contains('not a string (got int)'),
    );
    expect(report.serverName, isNull);
  });

  test('reports a handshake error when the command cannot start', () async {
    final report = await checkServer('/no/such/binary-mcp-probe');
    expect(report.errors.single.rule, ConformanceRules.handshake);
    expect(
      report.errors.single.message,
      contains('failed to start the server process'),
    );
  });

  test('flags log lines on stdout', () async {
    final report = await checkFixture('noisy_stdout_server');
    final finding = report.errors.singleWhere(
      (finding) => finding.rule == ConformanceRules.cleanStdout,
    );
    expect(finding.message, contains('starting up'));
  });

  test('flags empty serverInfo fields as errors', () async {
    final report = await checkFixture('empty_server_info_server');
    final errorRules = [for (final finding in report.errors) finding.rule];
    expect(errorRules, contains(ConformanceRules.serverInfoName));
    expect(errorRules, contains(ConformanceRules.serverInfoVersion));
  });

  test('flags malformed tool definitions as errors', () async {
    final report = await checkFixture('schemaless_tool_server');
    final schemaErrors = [
      for (final finding in report.errors)
        if (finding.rule == ConformanceRules.toolInputSchema) finding.message,
    ];
    expect(schemaErrors, hasLength(2));
    expect(schemaErrors, anyElement(contains('no_schema')));
    expect(schemaErrors, anyElement(contains('bad_root')));
    final nameErrors = [
      for (final finding in report.errors)
        if (finding.rule == ConformanceRules.toolName) finding,
    ];
    expect(nameErrors, hasLength(1));
  });

  test('warns when tools are declared but none are listed', () async {
    final report = await checkFixture('declares_but_empty_server');
    expect(report.hasErrors, isFalse);
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single.rule, ConformanceRules.toolsNonEmpty);
  });

  test('flags a server that silently drops requests', () async {
    final report = await checkFixture(
      'unresponsive_methods_server',
      timeout: const Duration(seconds: 3),
    );
    final errorRules = [for (final finding in report.errors) finding.rule];
    expect(errorRules, contains(ConformanceRules.toolsListable));
    expect(errorRules, contains(ConformanceRules.methodNotFound));
  });

  test('honors the configured timeout when checking ping', () async {
    // The server answers ping after 1.5 seconds, longer than the 1-second
    // default baked into `ServerConnection.ping` but well inside the 5-second
    // timeout configured here.
    final report = await checkFixture(
      'slow_ping_server',
      timeout: const Duration(seconds: 5),
    );
    expect(report.errors, isEmpty);
    final pingFindings = [
      for (final finding in report.findings)
        if (finding.rule == ConformanceRules.pingResponds) finding,
    ];
    expect(pingFindings.single.severity, ConformanceSeverity.info);
  });

  test('reports unsupported protocol versions instead of throwing', () async {
    final report = await checkFixture('bad_protocol_version_server');
    expect(report.hasErrors, isTrue);
    expect(report.errors.single.rule, ConformanceRules.protocolVersion);
    expect(report.protocolVersion, '2099-12-31');
  });

  test('reports a handshake error for a server that never answers', () async {
    final report = await checkFixture(
      'silent_server',
      timeout: const Duration(seconds: 2),
    );
    expect(report.errors.single.rule, ConformanceRules.handshake);
    expect(report.serverName, isNull);
  });
}
