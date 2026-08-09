// Draws doc/timeout.svg from four runs performed at run time.
//
//   dart run tool/timeout_figure.dart
//   rsvg-convert -w 1600 doc/timeout.svg -o doc/timeout.png
//
// The figure is the harness guarantee in one picture: against a server that
// completes the handshake and then answers nothing, a request comes back at
// the timeout passed to `start`, and the child process is already gone when
// `shutdown` returns. The top row is the same fixture driven by a
// hand-written stdio client with no timeout anywhere, which is what a test
// suite does when nothing bounds the wait. Every number in the drawing was
// measured by this program.
//
// The fixture is compiled to a kernel snapshot first. `dart run` resolves
// the package graph on its first call and that cost would land inside the
// handshake, which has to fit in the same timeout as the request being
// measured.
//
// The tool refuses to write the file when the runs stop saying what the
// figure says: the control must go unanswered while its process stays
// alive, every harness run must fail with a TimeoutException, each failure
// must land within a short slack of its configured timeout, and the walls
// must come in the order their timeouts do.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:mcp_probe/mcp_probe.dart';

/// The fixture every row drives: it answers `initialize`, then drops every
/// request that follows.
const fixture = 'test/fixtures/unresponsive_methods_server.dart';

/// Timeouts handed to [McpServerHarness.start], one row each.
const timeouts = [
  Duration(milliseconds: 500),
  Duration(seconds: 1),
  Duration(seconds: 2),
];

/// How long the control row waits for a reply before it stops watching.
const observation = Duration(seconds: 6);

/// How late a timeout may fire and still count as landing on its mark.
const slack = Duration(milliseconds: 600);

/// One harness row: what a bounded `tools/list` cost, and what cleaning up
/// after it cost.
class Row {
  Row(this.timeout, this.waitMs, this.reapMs, this.exit, this.timedOut);

  final Duration timeout;

  /// Milliseconds from issuing the request to the failure arriving.
  final int waitMs;

  /// Milliseconds from that failure to [McpServerHarness.shutdown] returning.
  final int reapMs;

  /// The exit code the server process left behind.
  final int exit;

  /// Whether the request failed with a [TimeoutException], as claimed.
  final bool timedOut;
}

/// The control row: the same server with nothing bounding the wait.
class Control {
  Control(this.handshakeMs, this.waitMs, this.answered, this.exited);

  /// Milliseconds the server took to answer `initialize`, which it does.
  final int handshakeMs;

  /// Milliseconds spent waiting for the `tools/list` reply.
  final int waitMs;

  /// Whether a reply arrived after all.
  final bool answered;

  /// Whether the process died on its own during the wait.
  final bool exited;
}

void main() async {
  final snapshot = Directory.systemTemp.createTempSync('mcp_probe_figure');
  final dill = '${snapshot.path}/fixture.dill';
  final compile = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'kernel',
    fixture,
    '-o',
    dill,
  ]);
  if (compile.exitCode != 0) {
    stderr.writeln('could not compile the fixture: ${compile.stderr}');
    snapshot.deleteSync(recursive: true);
    exitCode = 1;
    return;
  }

  final Control control;
  final rows = <Row>[];
  try {
    control = await _control(dill);
    for (final timeout in timeouts) {
      rows.add(await _row(dill, timeout));
    }
  } finally {
    snapshot.deleteSync(recursive: true);
  }

  final failure = _claimBroken(control, rows);
  if (failure != null) {
    stderr.writeln(failure);
    exitCode = 1;
    return;
  }

  File('doc/timeout.svg').writeAsStringSync(_svg(control, rows));

  stdout.writeln('handshake, control row   ${control.handshakeMs} ms');
  stdout.writeln('row                 wait ms   reap ms   exit');
  stdout.writeln(
    'no harness'.padRight(20) +
        control.waitMs.toString().padLeft(7) +
        '-'.padLeft(10) +
        '-'.padLeft(7),
  );
  for (final row in rows) {
    stdout.writeln(
      'timeout ${_ms(row.timeout.inMilliseconds)}'.padRight(20) +
          row.waitMs.toString().padLeft(7) +
          row.reapMs.toString().padLeft(10) +
          row.exit.toString().padLeft(7),
    );
  }
  stdout.writeln('wrote doc/timeout.svg');
}

/// Drives the fixture with a hand-written stdio client that has no timeout,
/// which is the shape of a test that hangs.
Future<Control> _control(String dill) async {
  final process = await Process.start(Platform.resolvedExecutable, [dill]);
  var exited = false;
  unawaited(process.exitCode.then((_) => exited = true));

  final pending = <int, Completer<void>>{};
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('{')) return;
      final message = jsonDecode(trimmed) as Map<String, Object?>;
      final id = message['id'];
      if (id is int) pending.remove(id)?.complete();
    },
  );
  process.stderr.drain<void>().ignore();

  void send(int id, String method, Map<String, Object?> params) {
    process.stdin.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
  }

  final handshake = Completer<void>();
  pending[1] = handshake;
  final clock = Stopwatch()..start();
  send(1, 'initialize', {
    'protocolVersion': ProtocolVersion.latestSupported.versionString,
    'capabilities': <String, Object?>{},
    'clientInfo': {'name': 'hand-written', 'version': '0'},
  });
  await handshake.future;
  final handshakeMs = clock.elapsedMilliseconds;

  final reply = Completer<void>();
  pending[2] = reply;
  var answered = false;
  unawaited(reply.future.then((_) => answered = true));
  final wait = Stopwatch()..start();
  send(2, 'tools/list', <String, Object?>{});
  await Future<void>.delayed(observation);
  final waitMs = wait.elapsedMilliseconds;
  // Read the liveness flag before the kill below sets it.
  final exitedWhileWaiting = exited;

  process.kill(ProcessSignal.sigkill);
  await process.exitCode;
  return Control(handshakeMs, waitMs, answered, exitedWhileWaiting);
}

/// Runs one bounded `tools/list` against the fixture and times the cleanup.
Future<Row> _row(String dill, Duration timeout) async {
  final harness = await McpServerHarness.start(
    Platform.resolvedExecutable,
    args: [dill],
    timeout: timeout,
  );
  final clock = Stopwatch()..start();
  var timedOut = false;
  try {
    await harness.listTools();
  } on TimeoutException {
    timedOut = true;
  }
  final waitMs = clock.elapsedMilliseconds;
  final reap = Stopwatch()..start();
  final exit = await harness.shutdown();
  return Row(timeout, waitMs, reap.elapsedMilliseconds, exit, timedOut);
}

/// Returns why the figure would be lying, or null when the runs hold up.
String? _claimBroken(Control control, List<Row> rows) {
  if (control.answered) {
    return 'the control row got a reply, so the fixture is not the '
        'unresponsive case the figure is about';
  }
  if (control.exited) {
    return 'the control server exited on its own during the wait, so the '
        'figure cannot say the process was left running';
  }
  var previous = -1;
  for (final row in rows) {
    final label = _ms(row.timeout.inMilliseconds);
    if (!row.timedOut) {
      return 'the $label request did not fail with a TimeoutException';
    }
    final configured = row.timeout.inMilliseconds;
    if (row.waitMs < configured - 20) {
      return 'the $label request came back after ${row.waitMs} ms, earlier '
          'than the timeout it was given';
    }
    if (row.waitMs > configured + slack.inMilliseconds) {
      return 'the $label request came back after ${row.waitMs} ms, more than '
          '${slack.inMilliseconds} ms past the timeout it was given';
    }
    if (row.waitMs <= previous) {
      return 'the $label wall is not past the one before it, so the rows '
          'would not read as a ladder';
    }
    previous = row.waitMs;
  }
  return null;
}

String _ms(int ms) => ms >= 1000 ? '${ms ~/ 1000} s' : '$ms ms';

String _svg(Control control, List<Row> rows) {
  const w = 900.0, h = 434.0;
  const left = 168.0, right = 34.0, top = 96.0, rowH = 62.0;
  const barH = 24.0;
  final plotW = w - left - right;
  final axisY = top + (rows.length + 1) * rowH + 4;

  final span = ((control.waitMs / 500).ceil() * 500).toDouble();
  double x(num ms) => left + (ms / span) * plotW;
  double rowTop(int i) => top + i * rowH;

  final grid = StringBuffer();
  for (var s = 0; s <= span ~/ 1000; s++) {
    final gx = x(s * 1000).toStringAsFixed(1);
    grid.writeln(
      '<line x1="$gx" y1="${top - 12}" x2="$gx" y2="$axisY" '
      'stroke="#eceff3" stroke-width="1"/>',
    );
    grid.writeln(
      '<text x="$gx" y="${axisY + 18}" text-anchor="middle" font-size="12" '
      'fill="#6b7280">$s s</text>',
    );
  }

  String label(int i, String name, String detail) {
    final y = rowTop(i) + 18;
    return '<text x="24" y="$y" font-size="14" font-weight="600" '
        'font-family="monospace" fill="#111827">$name</text>\n'
        '<text x="24" y="${y + 17}" font-size="11.5" fill="#6b7280">'
        '$detail</text>';
  }

  final controlBar = rowTop(0) + 6;
  final controlEnd = x(control.waitMs);
  final body = StringBuffer()
    ..writeln(label(0, 'no harness', 'hand-written stdio client'))
    ..writeln(
      '<rect x="$left" y="$controlBar" '
      'width="${(controlEnd - left - 14).toStringAsFixed(1)}" '
      'height="$barH" rx="5" fill="#fee2e2" stroke="#f87171"/>',
    )
    ..writeln(
      '<path d="M ${(controlEnd - 14).toStringAsFixed(1)} $controlBar '
      'L ${controlEnd.toStringAsFixed(1)} ${controlBar + barH / 2} '
      'L ${(controlEnd - 14).toStringAsFixed(1)} ${controlBar + barH} Z" '
      'fill="#f87171"/>',
    )
    ..writeln(
      '<text x="${left + 12}" y="${controlBar + 16.5}" font-size="12.5" '
      'fill="#991b1b">no reply at '
      '${(control.waitMs / 1000).toStringAsFixed(1)} s, when this tool '
      'stopped watching; the process was still running</text>',
    );

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final y = rowTop(i + 1) + 6;
    final wall = x(row.waitMs);
    body
      ..writeln(
        label(
          i + 1,
          'timeout: ${_ms(row.timeout.inMilliseconds)}',
          'McpServerHarness.start',
        ),
      )
      ..writeln(
        '<rect x="$left" y="$y" width="${(wall - left).toStringAsFixed(1)}" '
        'height="$barH" rx="5" fill="#fef3c7" stroke="#f59e0b"/>',
      )
      ..writeln(
        '<line x1="${wall.toStringAsFixed(1)}" y1="${y - 6}" '
        'x2="${wall.toStringAsFixed(1)}" y2="${y + barH + 6}" '
        'stroke="#b45309" stroke-width="2"/>',
      )
      ..writeln(
        '<text x="${(wall + 12).toStringAsFixed(1)}" y="${y + 11}" '
        'font-size="12.5" font-weight="600" fill="#b45309">'
        'TimeoutException after ${row.waitMs} ms</text>',
      )
      ..writeln(
        '<circle cx="${(wall + 18).toStringAsFixed(1)}" '
        'cy="${y + 22}" r="4" fill="#047857"/>',
      )
      ..writeln(
        '<text x="${(wall + 28).toStringAsFixed(1)}" y="${y + 26}" '
        'font-size="12" fill="#047857">process gone ${row.reapMs} ms later, '
        'exit ${row.exit}</text>',
      );
  }

  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w.toInt()} ${h.toInt()}"
     font-family="-apple-system, Segoe UI, Roboto, sans-serif">
<rect width="100%" height="100%" fill="#ffffff"/>
<text x="24" y="34" font-size="17" font-weight="600" fill="#111827">
  A server that stops answering, asked for its tool list four times
</text>
<text x="24" y="58" font-size="13" fill="#6b7280">
  Same fixture and same request in every row. The only thing that changes is
  the timeout given to the harness, and that is where the failure lands.
</text>
$grid
$body
<line x1="$left" y1="$axisY" x2="${w - right}" y2="$axisY"
      stroke="#9ca3af" stroke-width="1"/>
<text x="${(left + plotW / 2).toStringAsFixed(1)}" y="${axisY + 40}"
      text-anchor="middle" font-size="12" fill="#6b7280">
  wall clock from the moment tools/list went out
</text>
<text x="24" y="${axisY + 66}" font-size="11.5" fill="#9ca3af">
  every row drives
  <tspan font-family="monospace">unresponsive_methods_server</tspan>, a fixture
  that answers the handshake in ${control.handshakeMs} ms and then replies to
  nothing
</text>
</svg>
''';
}
