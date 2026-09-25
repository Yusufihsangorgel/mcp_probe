# Package engineering rules: mcp_probe

Rules-Version: mcp_probe/8424566eba41cb34b59d7074d13e74ff11631ad8941781d1fda24fe0ccc5c7b2
Core-Version: 1
Core-Digest: 1825fa7ff346dca23e65b1b3bf9b2e3e06959f1414bae9952d596d2f62f09b8f
Survey-Digest: f90f45c8a172068c3ed3b9488ba5a7cb4e58efa93c380d2d9a70b399349ec35e
Evidence-Revision: 4f7e092
Verified-Revision: unverified

Read CONTRIBUTING.md and docs/engineering/debt.json before editing.

## Current architecture
A test harness and conformance checker that starts an MCP server as a subprocess and drives it over stdio. There are two entry libraries: lib/mcp_probe.dart (McpServerHarness, checkServer, report types, McpHandshakeException) and lib/testing.dart (expect* helpers bound to package:matcher). Layers: harness.dart is infrastructure (Process, stdio channel, dart_mcp client, per-request timeout, pagination, kill escalation); conformance.dart is the rule engine (ConformanceRules identifiers, checkServer orchestration, private _check* functions that report through a finding callback); report.dart is the result model and formatters. Delivery surfaces: the bin/mcp_probe.dart CLI and the action.yml composite GitHub Action. Test fixtures: 13 servers, each one reproducing a defect. Maintainer docs are RELEASE-CHECKLIST.md and SPEC-ERA-RULES.md. Scanned HEAD: 4f7e092 (version 0.10.3).

## Layers and responsibilities
- lib/mcp_probe.dart, lib/testing.dart: The harness and checks are exposed from one entry point. The package:test surface is exposed from a separate entry point with `show`.
- lib/src/harness.dart: Process startup, stdout noise filter, broken pipe tolerance, handshake, timeouts, pagination loop detection, shutdown.
- lib/src/conformance.dart: Rule identifier constants, checkServer, one private _check function per rule. An error raised while reading server data becomes a finding.
- lib/src/report.dart, lib/src/exceptions.dart: Severity, finding, report (Markdown/JSON), handshake exception.
- lib/src/matchers.dart: expectToolExists, expectToolCallSucceeds, expectToolCallFails, expectResourceExists.
- bin/mcp_probe.dart, action.yml: CLI (flags, exit codes) and the composite Action used in CI.
- test/fixtures/, test/, tool/: Defective and conforming server fixtures, package tests, README figure generators.

## Public API and dependency direction
lib/mcp_probe.dart exposes with `show`: ConformanceRules, checkServer; McpHandshakeException; McpServerHarness, harnessVersion; ConformanceFinding, ConformanceReport, ConformanceSeverity (mcp_probe.dart:13-17). lib/testing.dart: expectResourceExists, expectToolCallFails, expectToolCallSucceeds, expectToolExists (testing.dart:9-14). dart_mcp types are not re-exported. `harness.connection` is an escape hatch to the raw client (harness.dart:58-62). CLI: `mcp_probe check [--format markdown|json] [--fail-on error|warning|info] <command> [args…]`. Exit codes: 0/1, usage error 64, internal error 70 (bin/mcp_probe.dart:15-118). Action inputs: command, fail-on, format, version (action.yml:9-30). The rule identifier strings (ConformanceRules) are a public contract visible in reports. Platforms are android/linux/macos/windows only (pubspec.yaml:28-37).

conformance.dart → exceptions, harness, report, json_rpc_2 (1-8). matchers.dart → harness, dart_mcp/client, matcher (1-4). harness.dart → exceptions, dart_mcp/client, dart_mcp/stdio, dart:io (1-8). report.dart → nothing. exceptions.dart → only a @docImport of harness. bin/mcp_probe.dart → package:mcp_probe/mcp_probe.dart (13). action.yml → the CLI via pub global activate. Direction: delivery → public API → rule engine → infrastructure → dart_mcp. matcher appears only in matchers.dart. No cycles.

## Error, state and platform contracts
- Rule identifiers live in `abstract final class ConformanceRules`. Each constant carries dartdoc that states the requirement (conformance.dart:10-59).
- Each rule is one private `_check...(harness, add)` function. Findings are added through the `_AddFinding` callback (conformance.dart:188-189, 191-485).
- Passing checks are recorded as info findings. The report shows what was covered (report.dart:44-48).
- checkServer never throws: a handshake error becomes part of the report, a server data read error becomes a finding (conformance.dart:71-73, 100-116, 118-120).
- Resource safety: shutdown in finally, _forceStop on failed startup, SIGTERM→SIGKILL escalation (conformance.dart:175-177; harness.dart:371-433).
- Every request is bounded by a timeout. A repeating cursor in pagination is detected (harness.dart:272-305, 402-412).
- Operating limits are documented public static const values (harness.dart:52-56).
- One fixture server per defective behavior (test/fixtures/, 13 servers).
- harnessVersion is kept in sync with the pubspec version by a test (harness.dart:10-20; test/harness_version_test.dart:10-25).
- Strict lint set and relative imports inside lib (analysis_options.yaml:1-17).

## Package rules
### mcp_probe/MCP-01 [MUST]
Public names go through lib/mcp_probe.dart or lib/testing.dart with a `show` list. Code that uses package:matcher stays in lib/src/matchers.dart and is exported only from lib/testing.dart.
Reason: Only code that performs validation inside tests should pull in the package:test surface. New public names pass through two libraries.
Evidence: lib/mcp_probe.dart:13-17; lib/testing.dart:1-14; lib/src/matchers.dart:1-2; AGENTS.md:68
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-02 [MUST]
A new conformance rule adds a documented constant to `ConformanceRules`, a private `_check` function reporting through the finding callback, a fixture server under test/fixtures/ that breaks the rule, and a test that names the constant.
Reason: All 14 current rules are this way. A rule without a fixture cannot be tested.
Evidence: lib/src/conformance.dart:10-59, 188-189; test/fixtures/ (13 servers); 14/14 named in the constant tests
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-03 [MUST]
`checkServer` returns a report whatever the server does. Each rule turns every failure while reading server data into a finding, including exception types it did not expect. Only `McpServerHarness.start` throws `McpHandshakeException`.
Reason: Batch conformance runs must not halt because of one server. The contract is written in the dartdoc and in AGENTS.
Evidence: lib/src/conformance.dart:71-73, 100-116, 118-120, 126-177; counterexample conformance.dart:429-464 (debt)
Evidence role: both
Existing violation: mcp_probe-D003

### mcp_probe/MCP-04 [MUST]
A passing check is an info finding under its rule ID. Error severity is for a spec violation or a missing answer.
Reason: The report also shows what is covered. The CLI and Action thresholds look at severity.
Evidence: lib/src/report.dart:1-12, 44-48; lib/src/conformance.dart:127-138
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-05 [MUST]
Every harness request is bounded by the harness timeout. Every path that starts a process ends it: `shutdown` in a `finally`, a forced stop after a failed start.
Reason: A hung server must not hang the test, and child processes must not leak.
Evidence: lib/src/harness.dart:100-111, 206-218, 371-400, 402-412, 414-433; lib/src/conformance.dart:175-177
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-06 [MUST]
Operational limits (timeouts, caps, page limits) are parameters or named `static const` values with dartdoc.
Reason: This is the current pattern (stderrCap, stdoutNoiseCap). Unnamed literal limits are recorded as debt.
Evidence: lib/src/harness.dart:52-56; counterexample harness.dart:300-301, 394, 420, 428
Evidence role: both
Existing violation: mcp_probe-D004

### mcp_probe/MCP-07 [MUST]
Bump `harnessVersion` in lib/src/harness.dart in the same commit as `version:` in pubspec.yaml.
Reason: This slipped three times in this release. The test only catches it after publishing.
Evidence: lib/src/harness.dart:10-20; test/harness_version_test.dart:10-25; AGENTS.md:74; commit 3368558, c6d9a6e, 81b6000
Evidence role: both
Existing violation: none

### mcp_probe/MCP-08 [MUST]
Inside lib/, use relative imports. The lint set in analysis_options.yaml stays clean under `dart analyze --fatal-infos`.
Reason: This package has the strictest analysis settings of the six. CI runs it as a gate.
Evidence: analysis_options.yaml:1-17; .github/workflows/ci.yaml:23-24; AGENTS.md:74
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-09 [MUST_NOT]
Do not list a platform where `Process.start` cannot run in the `platforms` block of pubspec.yaml.
Reason: The harness starts subprocesses. This is not possible on iOS and web, and pub.dev would declare wrong platform support.
Evidence: pubspec.yaml:28-37
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-10 [MUST]
Swallow an exception only on a cleanup path, with a comment naming what failed. Every other catch names its type or turns the error into a finding.
Reason: The exception swallows in cleanup paths carry justified comments today. A package-level named exception to the shared typed catch rule (J10).
Evidence: lib/src/harness.dart:166-177, 382-387, 418-425; lib/src/conformance.dart:335, 398, 442, 457
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-11 [MUST]
A change to bin/mcp_probe.dart or action.yml keeps the CI action job green: a conforming fixture passes and a broken one exits non-zero.
Reason: The Action is used from other repositories. A broken release directly affects user CIs.
Evidence: .github/workflows/ci.yaml:27-49; action.yml:46-59
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-12 [MUST]
A fixture that breaks the protocol on purpose explains it in a comment next to any `ignore:`.
Reason: The suppressions in the fixture are deliberate. A suppression without a rationale counts as debt.
Evidence: test/fixtures/paginated_tools_server.dart:41-42
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-13 [MUST]
A behavior change lands with a CHANGELOG entry and a test in the same commit.
Reason: Repository practice. Every release matches a CHANGELOG heading.
Evidence: commit 8deda64 (CHANGELOG + 2 test files); CHANGELOG.md top version 0.10.3 = pubspec
Evidence role: current-pattern
Existing violation: none

### mcp_probe/MCP-14 [MUST]
Public classes are `final`, or `abstract final` for a holder of constants.
Reason: All current public classes are sealed. Evolution does not break consumers.
Evidence: lib/src/harness.dart:35; lib/src/exceptions.dart:9; lib/src/report.dart:15, 49; lib/src/conformance.dart:12
Evidence role: current-pattern
Existing violation: none

## Required verification
- Working directory: repository root; command: dart pub get; conditions: ci.yaml job build; evidence: .github/workflows/ci.yaml:22.
- Working directory: repository root; command: dart format --output=none --set-exit-if-changed .; conditions: ci.yaml job build; evidence: .github/workflows/ci.yaml:23.
- Working directory: repository root; command: dart analyze --fatal-infos; conditions: ci.yaml job build; evidence: .github/workflows/ci.yaml:24.
- Working directory: repository root; command: dart test; conditions: ci.yaml job build; evidence: .github/workflows/ci.yaml:25.
- Working directory: repository root; command: dart pub get; conditions: ci.yaml job action; evidence: .github/workflows/ci.yaml:37.
- Working directory: repository root; command: dart pub global activate --source path .; conditions: ci.yaml job action; evidence: .github/workflows/ci.yaml:45.
- Working directory: repository root; command: if mcp_probe check dart run test/fixtures/noisy_stdout_server.dart; then; conditions: ci.yaml job action; evidence: .github/workflows/ci.yaml:46.
- Working directory: repository root; command: echo "expected a non-zero exit for a non-conforming server" >&2; conditions: ci.yaml job action; evidence: .github/workflows/ci.yaml:47.
- Working directory: repository root; command: exit 1; conditions: ci.yaml job action; evidence: .github/workflows/ci.yaml:48.
- Working directory: repository root; command: fi; conditions: ci.yaml job action; evidence: .github/workflows/ci.yaml:49.
Not verified by the survey:
- The scan used the local HEAD (4f7e092). Equality with origin and uncommitted changes were not measured.
- Whether a non-object result reaches the cast at harness.dart:368, or throws earlier inside dart_mcp/json_rpc_2, was not verified because the dependency sources were not read. The escape path in the debt item was inferred from the code.
- Whether the `--fail-on info` behavior is intentional: there is no test and the README is ambiguous.
- Cognitive complexity scores were not measured. Candidates: conformance.dart:74-186 (checkServer), 217-358 (_checkTools), harness.dart:112-253 (start).
- CLI behavior on Windows and the current test status: not run.

## Existing debt
The complete register is docs/engineering/debt.json.
- mcp_probe-D001 | medium | bin/mcp_probe.dart:94-105 (102-103); README.md:88-91; action.yml:15-20 | meaningless option / wrong behavior
  Fix: Define the meaning of the info threshold: either remove the `info` option or separate observation from passing. Add tests, update the README and action.yml.
  Closure: Either the info option is removed from bin/mcp_probe.dart, README.md and action.yml or passing observations no longer fail the run. Tests cover the chosen behavior and the CI action job stays green.
- mcp_probe-D002 | medium | bin/mcp_probe.dart:15-136 | untested behavior
  Fix: Move `_shouldFail` and `_severity` to lib/src (for example a threshold method on the report) and test them. Add Process.run based tests for flags and exit codes.
  Closure: _shouldFail and _severity move to lib/src, for example as a threshold method on the report, with unit tests. Process.run based tests cover flag parsing and the exit codes 0, 1, 64 and 70.
- mcp_probe-D003 | small | lib/src/conformance.dart:429-464 | contract gap
  Fix: Add the same 'turn every error into a finding' branch. Write a test with a fixture server that returns a non-object result for an unknown method.
  Closure: _checkMethodNotFound turns every error into a finding like its sibling rules. A fixture server returning a non-object result for an unknown method backs a test.
- mcp_probe-D004 | small | lib/src/harness.dart:300-301, 394, 420, 428 | unnamed operational constant
  Fix: Use a named static const with dartdoc, or derive the value from `killAfter`.
  Closure: The 10000 page limit and the 2 s kill stages are named static const values with dartdoc or derive from killAfter.
- mcp_probe-D005 | small | lib/src/harness.dart:128, 212; lib/src/conformance.dart:235, 350, 382, 406 | untyped catch
  Fix: `on Object catch` with a one-line rationale.
  Closure: All listed catch sites read on Object catch with a one-line rationale comment.
