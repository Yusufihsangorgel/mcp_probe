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
          ConformanceRules.methodNotFound,
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
    // The fixture has three tools: echo (rejects the empty arguments
    // in-band), fail_tool (fails in-band), and read_env (succeeds). All
    // three shapes are conformant.
    expect(smoke, hasLength(3));
    expect(report.hasErrors, isFalse);
    for (final finding in smoke) {
      expect(finding.severity, ConformanceSeverity.info);
    }
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
