import 'dart:io';

import 'package:mcp_probe/mcp_probe.dart';
import 'package:test/test.dart';

/// `harnessVersion` is what every server sees as this client's version, and
/// what a conformance report names. It sat at 0.1.0 through seven releases
/// before anyone noticed, because nothing compared it to anything. This does.
void main() {
  test('harnessVersion matches the package version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version');
    expect(
      harnessVersion,
      match!.group(1),
      reason:
          'harnessVersion is reported to every server this harness '
          'connects to; bump it with the package version',
    );
  });
}
