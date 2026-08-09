// Draws doc/rule-grid.svg from conformance runs performed at run time.
//
//   dart run tool/rule_grid_figure.dart
//   rsvg-convert -w 1600 doc/rule-grid.svg -o doc/rule-grid.png
//
// The figure is the package's whole argument in one picture: point
// `checkServer` at a command and every rule comes back with a verdict, so
// "does my server conform?" turns into a grid you can read. Every cell here
// is the severity of a finding from a real run against the fixture servers
// in `test/fixtures/`. Nothing is typed into the drawing.
//
// The tool refuses to write the file when the runs stop saying what the
// figure says: the clean fixture must come back clean, every broken one must
// come back broken, and no two servers may produce the same column.

import 'dart:io';

import 'package:mcp_probe/mcp_probe.dart';

/// One column of the grid: a fixture server and what is wrong with it.
class Probe {
  const Probe(this.fixture, this.label, this.defect, {this.timeout});

  /// File name under `test/fixtures/`, without the extension.
  final String fixture;

  /// Column heading.
  final String label;

  /// What this server does wrong, in two short lines.
  final List<String> defect;

  /// Overrides the default when a server has to be waited out.
  final Duration? timeout;
}

const probes = [
  Probe('well_behaved_server', 'well_behaved', [
    'nothing, this is',
    'the baseline',
  ]),
  Probe('declares_but_empty_server', 'declares_but_empty', [
    'declares tools,',
    'registers none',
  ]),
  Probe('schemaless_tool_server', 'schemaless_tool', [
    'tools with no name',
    'and no object schema',
  ]),
  Probe('noisy_stdout_server', 'noisy_stdout', [
    'print() lands on',
    'the protocol channel',
  ]),
  Probe('unresponsive_methods_server', 'unresponsive', [
    'answers initialize,',
    'then drops everything',
  ], timeout: Duration(seconds: 3)),
  Probe('bad_protocol_version_server', 'bad_version', [
    'negotiates a version',
    'no client knows',
  ]),
];

/// The default rule set, in the order [checkServer] runs it.
///
/// `ConformanceRules.toolCallSmoke` is absent on purpose: it only runs under
/// `callTools: true`, and these probes are read-only.
const rows = [
  ConformanceRules.handshake,
  ConformanceRules.protocolVersion,
  ConformanceRules.serverInfoName,
  ConformanceRules.serverInfoVersion,
  ConformanceRules.toolsListable,
  ConformanceRules.toolsNonEmpty,
  ConformanceRules.toolName,
  ConformanceRules.toolInputSchema,
  ConformanceRules.resourcesListable,
  ConformanceRules.promptsListable,
  ConformanceRules.pingResponds,
  ConformanceRules.methodNotFound,
  ConformanceRules.cleanStdout,
];

void main() async {
  final reports = <String, ConformanceReport>{};
  for (final probe in probes) {
    try {
      reports[probe.fixture] = await checkServer(
        Platform.resolvedExecutable,
        args: ['run', 'test/fixtures/${probe.fixture}.dart'],
        timeout: probe.timeout ?? const Duration(seconds: 10),
      );
    } catch (e) {
      stderr.writeln('${probe.fixture} did not produce a report: $e');
      exitCode = 1;
      return;
    }
  }

  final failure = _claimBroken(reports);
  if (failure != null) {
    stderr.writeln(failure);
    exitCode = 1;
    return;
  }

  File('doc/rule-grid.svg').writeAsStringSync(_svg(reports));

  stdout.writeln('server                findings     exit');
  for (final probe in probes) {
    final report = reports[probe.fixture]!;
    final counts =
        '${report.errors.length}E ${report.warnings.length}W '
        '${report.infos.length}I';
    stdout.writeln(
      probe.label.padRight(22) +
          counts.padRight(13) +
          (report.hasErrors ? '1' : '0'),
    );
  }
  stdout.writeln('wrote doc/rule-grid.svg');
}

/// Returns why the figure would be lying, or null when the runs hold up.
String? _claimBroken(Map<String, ConformanceReport> reports) {
  final baseline = reports[probes.first.fixture]!;
  if (baseline.errors.isNotEmpty || baseline.warnings.isNotEmpty) {
    return 'the baseline fixture is meant to be clean, and this run found '
        '${baseline.errors.length} error(s) and '
        '${baseline.warnings.length} warning(s)';
  }

  final columns = <String, String>{};
  for (final probe in probes) {
    final report = reports[probe.fixture]!;
    for (final finding in report.findings) {
      if (finding.rule == ConformanceRules.toolCallSmoke) {
        return 'the probes are read-only, and ${probe.label} produced a '
            'tools/call-smoke finding';
      }
      if (!rows.contains(finding.rule)) {
        return 'rule "${finding.rule}" from ${probe.label} has no row in '
            'the grid';
      }
    }
    if (probe != probes.first &&
        report.errors.isEmpty &&
        report.warnings.isEmpty) {
      return '${probe.label} is a broken server and this run found nothing '
          'wrong with it';
    }
    final signature = [
      for (final rule in rows) '$rule=${_verdict(report, rule)?.name ?? '-'}',
    ].join(',');
    final twin = columns[signature];
    if (twin != null) {
      return '${probe.label} and $twin report identically, so the grid '
          'would show one column twice';
    }
    columns[signature] = probe.label;
  }
  return null;
}

/// The worst severity [rule] reported in [report], or null when the rule
/// produced no finding at all.
ConformanceSeverity? _verdict(ConformanceReport report, String rule) {
  ConformanceSeverity? worst;
  for (final finding in report.findings) {
    if (finding.rule != rule) continue;
    if (worst == null || finding.severity.index < worst.index) {
      worst = finding.severity;
    }
  }
  return worst;
}

/// How many findings [rule] produced in [report].
int _count(ConformanceReport report, String rule) =>
    report.findings.where((finding) => finding.rule == rule).length;

String _svg(Map<String, ConformanceReport> reports) {
  const w = 1110.0, h = 612.0;
  const labelX = 24.0, gridX = 246.0, colW = 142.0;
  const gridY = 138.0, rowH = 26.0;
  final gridBottom = gridY + rows.length * rowH;
  final summaryY = gridBottom + 12;

  double colCentre(int i) => gridX + i * colW + colW / 2;

  final headers = StringBuffer();
  for (var i = 0; i < probes.length; i++) {
    final probe = probes[i];
    final cx = colCentre(i).toStringAsFixed(1);
    headers.writeln(
      '<text x="$cx" y="86" text-anchor="middle" font-size="11.5" '
      'font-weight="600" font-family="monospace" fill="#111827">'
      '${probe.label}</text>',
    );
    for (var line = 0; line < probe.defect.length; line++) {
      headers.writeln(
        '<text x="$cx" y="${106 + line * 14}" text-anchor="middle" '
        'font-size="11" fill="#6b7280">${probe.defect[line]}</text>',
      );
    }
  }

  final cells = StringBuffer();
  for (var r = 0; r < rows.length; r++) {
    final rule = rows[r];
    final y = gridY + r * rowH;
    if (r.isEven) {
      cells.writeln(
        '<rect x="$labelX" y="${y.toStringAsFixed(1)}" '
        'width="${(gridX + probes.length * colW - labelX).toStringAsFixed(1)}" '
        'height="$rowH" fill="#f8fafc"/>',
      );
    }
    cells.writeln(
      '<text x="$labelX" y="${(y + 17).toStringAsFixed(1)}" font-size="11" '
      'font-family="monospace" fill="#374151">$rule</text>',
    );
    for (var i = 0; i < probes.length; i++) {
      final report = reports[probes[i].fixture]!;
      final verdict = _verdict(report, rule);
      final count = _count(report, rule);
      final style = _style(verdict);
      final text = verdict == null
          ? '&#8211;'
          : count > 1
          ? '${verdict.name} &#215;$count'
          : verdict.name;
      cells.writeln(
        '<rect x="${(gridX + i * colW + 5).toStringAsFixed(1)}" '
        'y="${(y + 3).toStringAsFixed(1)}" width="${colW - 10}" height="20" '
        'rx="5" fill="${style.fill}" stroke="${style.stroke}"/>'
        '<text x="${colCentre(i).toStringAsFixed(1)}" '
        'y="${(y + 17).toStringAsFixed(1)}" text-anchor="middle" '
        'font-size="11" fill="${style.text}">$text</text>',
      );
    }
  }

  final summary = StringBuffer();
  summary.writeln(
    '<text x="$labelX" y="${(summaryY + 17).toStringAsFixed(1)}" '
    'font-size="11.5" fill="#374151">findings by severity</text>'
    '<text x="$labelX" y="${(summaryY + rowH + 17).toStringAsFixed(1)}" '
    'font-size="11.5" fill="#374151">'
    '<tspan font-family="monospace">mcp_probe check</tspan> exit code</text>',
  );
  for (var i = 0; i < probes.length; i++) {
    final report = reports[probes[i].fixture]!;
    final cx = colCentre(i).toStringAsFixed(1);
    summary.writeln(
      '<text x="$cx" y="${(summaryY + 17).toStringAsFixed(1)}" '
      'text-anchor="middle" font-size="11.5" font-family="monospace" '
      'fill="#374151">${report.errors.length}E &#183; '
      '${report.warnings.length}W &#183; ${report.infos.length}I</text>',
    );
    final failed = report.hasErrors;
    summary.writeln(
      '<text x="$cx" y="${(summaryY + rowH + 17).toStringAsFixed(1)}" '
      'text-anchor="middle" font-size="12.5" font-weight="600" '
      'font-family="monospace" fill="${failed ? '#b91c1c' : '#047857'}">'
      '${failed ? '1' : '0'}</text>',
    );
  }

  // Stated only when a column actually shows it, so the note can never
  // contradict the grid above it.
  final lenient = [
    for (final probe in probes)
      if (reports[probe.fixture]!.warnings.isNotEmpty &&
          !reports[probe.fixture]!.hasErrors)
        probe.label,
  ];
  final note = lenient.isEmpty
      ? ''
      : '<text x="$labelX" '
            'y="${(summaryY + 2 * rowH + 18).toStringAsFixed(1)}" '
            'font-size="11.5" fill="#6b7280">'
            '<tspan font-family="monospace">${lenient.join(', ')}</tspan> '
            'still exits 0, because the default gate fails on errors alone. '
            '<tspan font-family="monospace">--fail-on warning</tspan> moves '
            'that bar.</text>';

  final legend = [
    ('#ecfdf5', '#a7f3d0', '#047857', 'info, the rule passed'),
    ('#fffbeb', '#fcd34d', '#b45309', 'warning, legal but confusing'),
    ('#fee2e2', '#fca5a5', '#b91c1c', 'error, the run fails'),
    ('#f9fafb', '#e5e7eb', '#9ca3af', 'no finding, the rule never ran'),
  ];
  final legendMarks = StringBuffer();
  for (var i = 0; i < legend.length; i++) {
    final (fill, stroke, text, caption) = legend[i];
    final x = labelX + i * 268.0;
    legendMarks.writeln(
      '<rect x="${x.toStringAsFixed(1)}" y="${h - 30}" width="16" height="14" '
      'rx="4" fill="$fill" stroke="$stroke"/>'
      '<text x="${(x + 24).toStringAsFixed(1)}" y="${h - 19}" font-size="11.5" '
      'fill="$text">$caption</text>',
    );
  }

  // Both counts in the caption come from the runs, so a fixture added to
  // `probes` cannot leave a stale number behind in the drawing.
  final broken = probes.skip(1).toList();
  final shakeHands = broken
      .where(
        (probe) =>
            _verdict(reports[probe.fixture]!, ConformanceRules.handshake) ==
            ConformanceSeverity.info,
      )
      .length;

  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w.toInt()} ${h.toInt()}"
     font-family="-apple-system, Segoe UI, Roboto, sans-serif">
<rect width="100%" height="100%" fill="#ffffff"/>
<text x="$labelX" y="34" font-size="18" font-weight="600" fill="#111827">
  One rule set, ${probes.length} servers, one verdict per rule
</text>
<text x="$labelX" y="56" font-size="12.5" fill="#6b7280">
  Every cell is the severity <tspan font-family="monospace">checkServer</tspan>
  reported when it was pointed at that server over stdio. $shakeHands of the
  ${broken.length} broken servers complete the handshake and still break a rule.
</text>
$headers
$cells
<line x1="$labelX" y1="${gridBottom + 4}"
      x2="${(gridX + probes.length * colW).toStringAsFixed(1)}"
      y2="${gridBottom + 4}" stroke="#d1d5db" stroke-width="1"/>
$summary
$note
$legendMarks
</svg>
''';
}

({String fill, String stroke, String text}) _style(
  ConformanceSeverity? severity,
) => switch (severity) {
  ConformanceSeverity.info => (
    fill: '#ecfdf5',
    stroke: '#a7f3d0',
    text: '#047857',
  ),
  ConformanceSeverity.warning => (
    fill: '#fffbeb',
    stroke: '#fcd34d',
    text: '#b45309',
  ),
  ConformanceSeverity.error => (
    fill: '#fee2e2',
    stroke: '#fca5a5',
    text: '#b91c1c',
  ),
  null => (fill: '#f9fafb', stroke: '#e5e7eb', text: '#9ca3af'),
};
