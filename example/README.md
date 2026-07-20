# Examples

## See the report before you write a server

```
dart run example/probe_demo.dart
```

You do not need a server of your own. The demo probes four that ship with this
package: one that behaves, and three that each break something specific. Real
output, about ten seconds:

```
## a server that behaves
   every rule passed

## a server that logs to stdout
   stdio/clean-stdout
     server wrote 2 non-protocol line(s) to stdout, first: "starting up, this log line does not belong on stdout"

## a server whose tool has no input schema
   tools/input-schema
     no_schema has no inputSchema object
   tools/input-schema
     bad_root has inputSchema root type "string", expected "object"
   tools/name
     tool at index 2 has a missing or empty name

## a server that ignores ping and unknown methods
   capabilities/tools-listable
     tools capability is declared but tools/list failed: TimeoutException after 0:00:03.000000
   utilities/ping
     server did not answer a ping request within the timeout
   jsonrpc/method-not-found
     server did not answer unknown method "mcp_probe/does-not-exist" at all
```

The second server is the reason to run any of this. It speaks the protocol
correctly. Every message it sends is well formed, every capability it declares
is real, and it is still unusable, because a `print` on the way up puts a line
on stdout where the transport expects only JSON-RPC. Nothing in the server's own
tests would catch that, and the failure a user sees is a client that will not
connect.

The others are the ordinary kind: a tool declared without an input schema, a
schema whose root is a string, a tool with an empty name, a server that ignores
`ping` and never answers a method it does not know. Each finding names the rule
and the thing that broke it, so the next step is a code change, not an
investigation.

## Point it at your own

```
dart run example/probe_demo.dart dart run bin/my_server.dart
```

Anything after the first argument is passed to the command, so the same line
works for a compiled binary, a Node server, or a Python one.

There is a command-line front end for the same thing, which is what to put in a
pipeline. It exits 0 when every check passes and 1 when any reports an error:

```yaml
- run: dart pub global activate mcp_probe
- run: mcp_probe check dart run bin/my_server.dart
```

## Asserting inside your own tests

`checkServer` answers "is this a valid MCP server". The other half is "does it
do what I built it for", which belongs in your test suite:

```dart
import 'package:mcp_probe/mcp_probe.dart';
import 'package:mcp_probe/testing.dart';
import 'package:test/test.dart';

void main() {
  late McpServerHarness harness;

  setUp(() async {
    harness = await McpServerHarness.start(
      'dart',
      args: ['run', 'bin/my_server.dart'],
    );
  });
  tearDown(() => harness.shutdown());

  test('exposes the search tool and it runs', () async {
    await expectToolExists(harness, 'search');
    await expectToolCallSucceeds(harness, 'search', arguments: {'q': 'dart'});
  });
}
```

`McpServerHarness` runs the server as a child process, applies a timeout to
every request, and kills the process on teardown even when a test fails, which
is the part that otherwise leaves stray servers behind on a developer's machine.
The `expect...` helpers live in the separate `package:mcp_probe/testing.dart`
entrypoint so that the harness itself does not pull `package:test` into
anything that is not a test.

## The rules

Fourteen, grouped by what they are checking: the `initialize` handshake and the
protocol version, the server info it reports, whether a declared capability
actually answers its list call, the shape of each tool's name and input schema,
an optional `tools/call` smoke test, `ping`, the JSON-RPC error for an unknown
method, and clean stdout. `ConformanceRules` names them all as constants, so a
report can be filtered down to the ones you care about.
