import 'package:mcp_probe/mcp_probe.dart';
import 'package:test/test.dart';

void main() {
  const findings = [
    ConformanceFinding(
      severity: ConformanceSeverity.info,
      rule: 'initialize/handshake',
      message: 'server answered the initialize request',
    ),
    ConformanceFinding(
      severity: ConformanceSeverity.warning,
      rule: 'capabilities/tools-nonempty',
      message: 'tools capability is declared but tools/list returned no tools',
    ),
    ConformanceFinding(
      severity: ConformanceSeverity.error,
      rule: 'tools/input-schema',
      message:
          'bad_root has inputSchema root type "string", expected '
          '"object"',
    ),
  ];

  const report = ConformanceReport(
    command: 'dart run server.dart',
    serverName: 'demo',
    serverVersion: '1.0.0',
    protocolVersion: '2025-11-25',
    findings: findings,
  );

  test('toMarkdown renders the expected document', () {
    const expected = '''
# MCP conformance report

Command: `dart run server.dart`
Server: demo 1.0.0
Protocol version: 2025-11-25

Summary: 1 error(s), 1 warning(s), 1 info.

| Severity | Rule | Detail |
| --- | --- | --- |
| info | initialize/handshake | server answered the initialize request |
| warning | capabilities/tools-nonempty | tools capability is declared but tools/list returned no tools |
| error | tools/input-schema | bad_root has inputSchema root type "string", expected "object" |
''';
    expect(report.toMarkdown(), expected);
  });

  test('severity getters partition the findings', () {
    expect(report.errors, hasLength(1));
    expect(report.warnings, hasLength(1));
    expect(report.infos, hasLength(1));
    expect(report.hasErrors, isTrue);
  });

  test('hasErrors is false without error findings', () {
    const clean = ConformanceReport(
      command: 'dart run server.dart',
      findings: [
        ConformanceFinding(
          severity: ConformanceSeverity.info,
          rule: 'initialize/handshake',
          message: 'ok',
        ),
      ],
    );
    expect(clean.hasErrors, isFalse);
  });

  test('toMarkdown escapes pipes and newlines in table cells', () {
    const tricky = ConformanceReport(
      command: 'dart run server.dart',
      findings: [
        ConformanceFinding(
          severity: ConformanceSeverity.error,
          rule: 'tools/name',
          message: 'a|b\nc',
        ),
      ],
    );
    expect(tricky.toMarkdown(), contains(r'a\|b c'));
  });

  test('finding toString is readable', () {
    expect(
      findings.first.toString(),
      '[info] initialize/handshake: server answered the initialize request',
    );
  });

  test('toJson carries the findings, the server info and a summary', () {
    final json = report.toJson();
    expect(json['command'], 'dart run server.dart');
    expect(json['serverName'], 'demo');
    expect(json['serverVersion'], '1.0.0');
    expect(json['protocolVersion'], '2025-11-25');
    // The summary lets a consumer gate on error count without walking findings.
    expect(json['summary'], {'error': 1, 'warning': 1, 'info': 1});
    final findingsJson = json['findings'] as List;
    expect(findingsJson, hasLength(3));
    expect(findingsJson.first, {
      'severity': 'info',
      'rule': 'initialize/handshake',
      'message': 'server answered the initialize request',
    });
  });

  test('toJson omits server fields that were never learned', () {
    const partial = ConformanceReport(command: 'x', findings: []);
    final json = partial.toJson();
    expect(json.containsKey('serverName'), isFalse);
    expect(json['summary'], {'error': 0, 'warning': 0, 'info': 0});
    expect(json['findings'], isEmpty);
  });
}
