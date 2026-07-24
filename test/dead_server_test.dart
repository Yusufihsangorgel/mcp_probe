import 'dart:async';

import 'package:mcp_probe/mcp_probe.dart';
import 'package:test/test.dart';

/// A server that dies immediately breaks the pipe on the next write to its
/// stdin. That failure arrives asynchronously, so it cannot be caught at the
/// call site: it reaches the zone and takes the isolate down with it, even
/// though `start` itself reports the failure properly. A normal test cannot see
/// that, because the exception the caller catches looks correct — the probe has
/// to watch the zone.
void main() {
  Future<({Object? caught, Object? unhandled})> runGuarded(
    Future<void> Function() body,
  ) async {
    final done = Completer<void>();
    Object? caught;
    Object? unhandled;

    runZonedGuarded(
      () {
        unawaited(() async {
          try {
            await body().timeout(const Duration(seconds: 15));
          } catch (error) {
            caught = error;
          }
          if (!done.isCompleted) done.complete();
        }());
      },
      (error, _) {
        unhandled ??= error;
        if (!done.isCompleted) done.complete();
      },
    );

    await done.future;
    // Give a late broken-pipe error time to surface before reporting.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return (caught: caught, unhandled: unhandled);
  }

  test(
    'a server that exits at once fails without an unhandled async error',
    () async {
      final result = await runGuarded(() => McpServerHarness.start('true'));

      expect(result.caught, isA<McpHandshakeException>());
      expect(
        result.unhandled,
        isNull,
        reason:
            'writing to the dead server left an unobserved error: '
            '${result.unhandled}',
      );
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'a command that does not exist fails cleanly',
    () async {
      final result = await runGuarded(
        () => McpServerHarness.start('mcp-probe-no-such-binary-xyz'),
      );

      expect(result.caught, isA<McpHandshakeException>());
      expect(result.unhandled, isNull);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'checkServer on a dead server reports instead of crashing',
    () async {
      ConformanceReport? report;
      final result = await runGuarded(() async {
        report = await checkServer('true');
      });

      expect(result.unhandled, isNull);
      expect(report, isNotNull);
      expect(
        report!.findings,
        isNotEmpty,
        reason: 'a server that will not start should produce findings',
      );
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );
}
