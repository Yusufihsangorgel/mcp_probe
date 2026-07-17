import 'package:dart_mcp/client.dart';
import 'package:mcp_probe/mcp_probe.dart';
import 'package:test/test.dart';

import 'fixture_helpers.dart';

void main() {
  late McpServerHarness harness;

  setUpAll(() async {
    harness = await startFixture('well_behaved_server');
  });

  tearDownAll(() => harness.shutdown());

  test('expectToolExists passes for a listed tool', () async {
    await expectToolExists(harness, 'echo');
  });

  test('expectToolExists fails for a missing tool', () {
    expect(
      expectToolExists(harness, 'nope'),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains('echo'),
        ),
      ),
    );
  });

  test('expectToolCallSucceeds returns the result', () async {
    final result = await expectToolCallSucceeds(
      harness,
      'echo',
      arguments: {'text': 'hi'},
    );
    expect((result.content.single as TextContent).text, 'hi');
  });

  test('expectToolCallSucceeds fails on an in-band error', () {
    expect(
      expectToolCallSucceeds(harness, 'fail_tool'),
      throwsA(isA<TestFailure>()),
    );
  });

  test('expectToolCallFails passes on an in-band error', () async {
    await expectToolCallFails(harness, 'fail_tool');
  });

  test('expectToolCallFails fails when the tool succeeds', () {
    expect(
      expectToolCallFails(harness, 'echo', arguments: {'text': 'hi'}),
      throwsA(isA<TestFailure>()),
    );
  });

  test('expectResourceExists passes for a listed resource', () async {
    await expectResourceExists(harness, 'probe://greeting');
  });

  test('expectResourceExists fails for a missing resource', () {
    expect(
      expectResourceExists(harness, 'probe://nope'),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains('probe://greeting'),
        ),
      ),
    );
  });
}
