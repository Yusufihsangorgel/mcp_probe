## 0.9.7

- Two figures. `tool/rule_grid_figure.dart` draws the conformance rules against
  the servers that ship with this package, and `tool/timeout_figure.dart` draws
  what the harness does when a server stops answering. Docs and tooling only.

## 0.9.6

- Add `example/server_test.dart`, a working test file rather than a sketch of
  one. This package is a test harness, and until now nothing in the examples
  wrote a test: `probe_demo.dart` prints a conformance report, which shows the
  command-line half and none of the part you would actually put in your repo.
  The new file starts the bundled fixture server and uses all four expectation
  helpers, then runs the conformance suite from inside `dart test` and passes
  the rendered report as the failure reason. Five tests, about a second, and
  `dart test example/server_test.dart` runs it as it ships.
- The README and the example README point at it. The bullet listing the
  expectation helpers had named four functions with nowhere to see them used.

## 0.9.5

Packaging only. Nothing in the library changed.

- Keep the compiled CLI out of the published archive. This package declares
  an executable, and `dart build cli` writes a 5 MB binary to `build/`, a
  directory `.gitignore` did not list. Measured on this machine: with that
  directory present, `dart pub publish --dry-run` put the binary in the package
  and reported a 2 MB compressed archive; with the directory ignored and the
  binary still on disk, the same command reports just over 300 KB. The 0.9.4
  archive on pub.dev is clean, checked by listing it, because no one had run
  `dart build cli` in the tree it was published from. The defect was latent
  rather than shipped, and the next publish from a tree where that command had
  been run would have carried the binary.
- `harnessVersion` reads `0.9.5`, checked by `test/harness_version_test.dart`
  after the bump rather than before it.

## 0.9.4

- **Fix `harnessVersion`, which 0.9.3 shipped stale.** It still read `0.9.2`,
  so a server talking to 0.9.3 was told the client was 0.9.2, and
  `test/harness_version_test.dart`, which exists precisely to catch this, was
  red in the published archive. The constant was not updated with the pubspec
  and the suite was not re-run after the bump. 0.9.3 is superseded; use this.

## 0.9.3

- The example runs without an argument. It used to print a usage line and exit
  64 unless you already had an MCP server command, which is the first thing
  anyone following the Example tab on pub.dev would hit. It now probes
  `test/fixtures/well_behaved_server.dart`, which ships in the archive, and
  prints a real report: handshake, negotiated protocol version, server info,
  four tools, twelve info-level findings and no errors. Seeing the output is
  most of what decides whether this package is worth adding. Passing a command
  works exactly as before.

## 0.9.2

- **Fix the version this harness reports to servers.** `harnessVersion` was
  left at `0.9.0` when 0.9.1 went out, so every server saw the wrong client
  version in its logs and every conformance report named it. The test written
  to catch exactly this drift was red at publish time: the version bump is
  what turns it red, and it was run before the bump rather than after.

- **Say who is behind when the protocol versions do not match.** A server that
  speaks only a newer revision answers `initialize` with it, which the
  specification asks it to do; the report called that
  "unsupported protocol version" and read as the server's fault, sending its
  author to look for a defect that was not there. The finding now names both
  sides (the version the server returned and the newest this harness speaks)
  and says plainly that it could not assess the server. The check still stops
  there, because a session that never opened cannot be probed further.

## 0.9.1

- **Declare the platforms the harness can actually run on.** With no
  `platforms:` block in the pubspec, pub.dev inferred the full set and
  advertised iOS. The harness starts the server under test with
  `Process.start`, which iOS refuses outright: built against an iPhone 17 Pro
  simulator on iOS 26.5, the run raised `ProcessException: Starting new
  processes is not supported on iOS` from `McpServerHarness.start`. Android,
  Linux, macOS and Windows are now declared and iOS is not; web is excluded
  too, having no `dart:io`. Android was checked on a live arm64 Android 15
  image with SELinux enforcing, where the handshake and the conformance rules
  pass.

- Name a repeated pagination cursor instead of only reporting that the page
  count ran out. A server that hands back the cursor it was given is not
  paginating, it is ignoring the parameter, the usual shape of a server that
  wires up `nextCursor` without implementing it. The 10000-page backstop caught
  the symptom and reported "did not terminate after 10000 pages"; the report
  now says which cursor repeated and that the server is not advancing. For a
  tool whose product is the diagnosis, the difference is the whole point. The
  backstop stays for a server that keeps minting fresh cursors.

## 0.9.0

- **Fix the version this harness reports to servers.** `harnessVersion` was
  still `0.1.0` (it had not moved through seven releases), and it is what every
  server sees as the connecting client's version, and what a conformance report
  names. Anyone reading their server logs to see which client probed them got the
  wrong answer. It now tracks the package version, and a test compares the two so
  it cannot drift again: nothing had ever compared that constant to anything,
  which is why it went stale silently.

## 0.8.0

- **Fix an unhandled async error that could take down the caller's isolate.**
  When a server process exits immediately (a wrong command, a binary that
  crashes on startup, a server that rejects its arguments), the next write to
  its stdin breaks the pipe. `start` reported the failure correctly as an
  `McpHandshakeException`, but the broken pipe surfaced separately as a
  `SocketException` that nothing observed, so a caller who caught the documented
  exception could still lose the isolate to an unhandled error a moment later.
  The harness now writes through a sink it owns and absorbs the broken pipe
  there, leaving exactly one catchable failure.

  Found by running the failure paths inside a guarded zone rather than reading
  them: the exception at the call site looked right, which is why an ordinary
  test could not see the problem. `test/dead_server_test.dart` now watches the
  zone for all three cases (a server that exits at once, a command that does not
  exist, and `checkServer` against a dead server).

Still pinned to `dart_mcp` 0.5.x. Because this package's API hands back
`dart_mcp` types (the right shape for a conformance prober), a 1.0.0 here has
to wait for that package to stabilise, or freezing would guarantee a major bump
the moment it changes.

## 0.7.0

- **Stop shipping the test runner to consumers.** `package:test` was a runtime
  dependency because `lib/src/matchers.dart` imported it for one function,
  `fail()`. `package:test` pulls 25 direct dependencies of its own, including
  `analyzer`, `shelf`, `coverage` and `node_preamble`, and every one of them
  landed in the dependency graph of anything that depended on this package.
  The import is now `package:matcher/expect.dart`, which exports the same
  `fail()` and brings five small packages, all of which `test` already depends
  on. Measured on a scratch project depending on this package: **50 resolved
  packages before, 16 after.** `test` moved to `dev_dependencies`, where it
  belongs.

  This is breaking only for a consumer that was relying on getting `test`
  transitively from here; declare it in your own `dev_dependencies` instead.

## 0.6.0

- Seal the exported types. `ConformanceFinding`, `ConformanceReport`,
  `McpServerHarness` and `McpHandshakeException` carried no class modifier.
  A later freeze would have made every field added to a report a breaking
  change for anyone who had subclassed it. None is meant to be subtyped and
  nothing in the package, its tests or its example does. `ConformanceRules` was
  already `abstract final`. No behaviour change.

## 0.5.1

- Fix `utilities/ping` ignoring the caller's configured `timeout`. `_checkPing`
  called `connection.ping()` with no arguments, which falls back to the
  1-second default on `dart_mcp`'s `ServerConnection.ping`. Any server
  whose ping round-trip took longer than 1 second failed this check even when
  it answered well inside the `timeout` passed to `checkServer` or
  `McpServerHarness.start`. It now passes `harness.timeout` through, matching
  every other request the harness makes.

## 0.5.0

- A composite GitHub Action, letting a repository gate its pull requests on MCP
  conformance in a few lines: `uses: Yusufihsangorgel/mcp_probe@v1` with a
  `command`, and optional `fail-on` and `format`. It sets up Dart, activates the
  CLI, and runs the check, failing the job when a finding at or above `fail-on`
  is present. Inputs are passed through the environment rather than interpolated
  into the shell, which stops a value from injecting script. The package's own
  CI now exercises the action against a conforming and a non-conforming fixture
  on every push, and a change that breaks it fails CI.
- README notes a real `dart run` gotcha: `dart run` prints a resolution line to
  stdout the first time, which pollutes a server launched that way. Run
  `dart pub get` before checking such a server. A compiled, Node or Python
  server has nothing to resolve.

## 0.4.0

- Machine-readable output and a configurable gate, which is what makes the CLI a
  real CI step rather than something a human reads. `ConformanceReport.toJson()`
  (and `ConformanceFinding.toJson()`) render the report as a JSON-serializable
  map: the probed command, the server identity, a `summary` count per severity,
  and the full findings list. The CLI gains `--format json` to print it and
  `--fail-on error|warning|info` to choose the severity at which the exit code
  becomes 1 (default `error`), letting a pipeline fail on a warning and capture
  a structured report in one run. Invalid flags exit 64 with a usage message.

## 0.3.3

- Install instructions now say `pub add` instead of pinning a version. The
  pinned number was stale by several releases and would have been stale again
  after the next one: the README ships frozen in the archive, and a hand-edited
  version line is wrong the moment anything is published. This one cannot go
  out of date.

## 0.3.2

- `example/probe_demo.dart` prints a real report without a server of your own.
  It probes four servers that ship with the package: one that behaves and three
  that break something specific, so the output shows what a failure looks like
  before you have written anything to fail.
  The interesting one is a server that speaks the protocol correctly and is
  still unusable, because a `print` on the way up puts a line on stdout where
  the transport expects only JSON-RPC. Its own tests would not catch that; what
  a user sees is a client that will not connect.
- `example/README.md` covers reading the report, pointing the probe at your own
  command, the `mcp_probe check` front end for a pipeline, and asserting your
  server's actual behaviour with the `testing.dart` helpers.
- `test/readme_snippet_test.dart` compiles the snippet that README prints. It
  never runs, it only has to analyse, which is enough to keep a copied example
  from drifting away from the API it is describing.

## 0.3.1

- Declare the diagram in `pubspec.yaml` so pub.dev renders it on the package
  page. It was already in the repository and the README, but pub.dev shows only
  what the `screenshots:` field points at, so the page opened with prose where
  the picture should have been.

## 0.3.0

- Add the `utilities/ping` conformance rule. MCP requires a server to answer a
  `ping` request promptly with an empty result; `checkServer` and the CLI now
  send one and report an error if the server times out or answers with a
  protocol error, so a server that stops responding to liveness pings is caught.

## 0.2.0

- Add a command-line tool. `dart pub global activate mcp_probe` installs an
  `mcp_probe check <command> [args...]` executable that runs a server over stdio,
  prints each conformance finding, and exits non-zero if any check reports an
  error. It drops into a CI step without writing any Dart.

## 0.1.3

- `listTools`, `listResources` and `listPrompts` now follow `nextCursor`
  pagination and return every page combined. Previously only the first page was
  fetched. A conformance run against a paginated server validated just those
  items and could report the server green without ever seeing the rest.

## 0.1.2

- Docs: tightened the README wording and visuals.

## 0.1.1

- Expand the package description to name what the package does in the
  words people search for. No code changes.

## 0.1.0

- Initial release.
- `McpServerHarness`: runs an MCP server as a child process over stdio, with
  per-request timeouts and guaranteed process cleanup.
- `checkServer` and `ConformanceReport`: conformance rules for the initialize
  handshake, declared capabilities, tool definitions, and JSON-RPC error
  behavior, with Markdown rendering.
- `package:test` helpers in the `package:mcp_probe/testing.dart` entrypoint:
  `expectToolExists`, `expectToolCallSucceeds`, `expectToolCallFails`,
  `expectResourceExists`.
