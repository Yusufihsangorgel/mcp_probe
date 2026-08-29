# Spec-era conformance rules (2026-07-28)

**Headline:** `2026-07-28` is a new protocol era, not a compatible bump of `2025-11-25`. It removes the client-to-server request methods `initialize`, `ping`, `logging/setLevel`, `resources/subscribe`, `resources/unsubscribe`, and the core `tasks/*` RPCs — while leaving several *capability bits of the same name* in place with changed meaning. This package cannot catch a server that still answers those removed methods, because `dart_mcp` 0.5.2 and `McpServerHarness.start` can only open a legacy (`initialize`) session and cannot send a well-formed 2026 request.

**Confidence:** **High** on the method inventory and the “method removed ≠ capability removed” distinction (schema + changelog + capability pages). **High** that this package cannot open a 2026-07-28 session today. **Medium** on the exact JSON-RPC error a stdio server must return for a well-formed 2026 request whose *method* is gone: HTTP is specified as `-32601`; stdio is not named per method, and `initialize` is explicitly implementation-defined.

Fetched 2026-08-29 from `modelcontextprotocol.io` and `raw.githubusercontent.com` with `curl`. `lib/` was not changed.

---

## How this document is marked

- **Verified** — quoted from a fetched page, with its URL.
- **Inferred** — a conclusion I drew from those pages or from this repo’s source, not a sentence the spec itself states.

---

## 1. What `/specification/latest` currently resolves to

**Verified.** Independent of the 307 you measured:

```
curl -sI https://modelcontextprotocol.io/specification/latest
HTTP/2 307
location: /specification/2026-07-28
```

Same target from neighboring aliases, also fetched:

| Request | Status | `Location` |
| --- | --- | --- |
| `https://modelcontextprotocol.io/specification/latest` | 307 | `/specification/2026-07-28` |
| `https://modelcontextprotocol.io/specification` | 307 | `/specification/2026-07-28` |
| `https://modelcontextprotocol.io/specification/latest.md` | 307 | `/specification/2026-07-28.md` |
| `https://modelcontextprotocol.io/specification/latest/changelog` | 307 | `/specification/2026-07-28/changelog` |

Following the markdown alias, the body is the 2026-07-28 specification index. It names that revision’s schema as the source of truth:

> This specification defines the authoritative protocol requirements, based on the TypeScript schema in [schema.ts](https://github.com/modelcontextprotocol/specification/blob/main/schema/2026-07-28/schema.ts).

Source: https://modelcontextprotocol.io/specification/2026-07-28/index.md (same bytes as `latest.md` after the 307).

The previous revision is **`2025-11-25`**. The 2026-07-28 changelog opens with:

> This document lists changes made to the Model Context Protocol (MCP) specification since the previous revision, [2025-11-25](/specification/2025-11-25).

Source: https://modelcontextprotocol.io/specification/2026-07-28/changelog.md

The versioning page names the era split:

> * **Modern**: protocol versions that convey version, identity, and capabilities as per-request metadata (revision `2026-07-28` and later).
> * **Legacy**: protocol versions that establish a session with an `initialize` handshake (`2025-11-25` and earlier).

Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning.md

---

## 2. `2026-07-28` vs `2025-11-25`: methods and capabilities

Method lists below are **verified** by extracting every `method: "…"` string from the two TypeScript schemas the spec calls the source of truth:

- https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts
- https://github.com/modelcontextprotocol/specification/blob/main/schema/2026-07-28/schema.ts

(Fetched as raw files from `raw.githubusercontent.com` on 2026-08-29.) Changelog prose is quoted from https://modelcontextprotocol.io/specification/2026-07-28/changelog.md.

A **request method** is a JSON-RPC method that takes an `id` and expects a response. A **notification** has no `id` and must not be answered. A **capability bit** is a field on `ClientCapabilities` / `ServerCapabilities`. Those three are independent; several rows below keep the bit and drop the method.

### 2.1 Client-to-server request methods REMOVED from the core schema

These strings appear as `method: "…"` in the 2025-11-25 schema and do **not** appear as methods in the 2026-07-28 schema.

| Method | 2025-11-25 (legacy) | 2026-07-28 (modern) | Changelog |
| --- | --- | --- | --- |
| `initialize` | request | **absent** | Major change 2 |
| `ping` | request | **absent** (0 occurrences in the 2026 schema) | Major change 5 |
| `logging/setLevel` | request | **absent as a method**; mentioned only as “the former `logging/setLevel` RPC” | Major change 5 |
| `resources/subscribe` | request | **absent as a method**; mentioned as “the former `resources/subscribe` RPC” | Major change 4 |
| `resources/unsubscribe` | request | **absent** | Major change 4 |
| `tasks/list` | request (experimental core) | **absent from core** | Major change 6 |
| `tasks/result` | request (experimental core) | **absent from core** | Major change 6 |
| `tasks/get` | request (experimental core) | **absent from core** (lives in the Tasks *extension*) | Major change 6 |
| `tasks/cancel` | request (experimental core) | **absent from core** (lives in the Tasks *extension*) | Major change 6 |

Changelog quotes:

> 2. Make MCP stateless: remove the `initialize`/`notifications/initialized` handshake. Every request now carries its protocol version and client capabilities in `_meta` (`io.modelcontextprotocol/protocolVersion`, `io.modelcontextprotocol/clientCapabilities`). […] ([SEP-2575](https://github.com/modelcontextprotocol/modelcontextprotocol/pull/2575)).

> 4. Replace the HTTP GET endpoint and `resources/subscribe`/`resources/unsubscribe` with `subscriptions/listen`: a single long-lived POST-response stream for opted-in server-to-client change notifications. […]

> 5. Remove `ping`, `logging/setLevel`, and `notifications/roots/list_changed`. Log level is now set per-request via `io.modelcontextprotocol/logLevel` in `_meta`; […]

> 6. Move experimental tasks out of the core protocol and into an official extension (`io.modelcontextprotocol/tasks`). The redesigned extension replaces the blocking `tasks/result` method with polling via `tasks/get` and a new `tasks/update` for client-to-server input, removes `tasks/list`, […]

Source for all four: https://modelcontextprotocol.io/specification/2026-07-28/changelog.md

The 2026 schema comment that `logging/setLevel` is gone as an RPC (the **capability** is a separate question, §2.4):

> If absent, the server MUST NOT send any `notifications/message` notifications for this request. The client opts in to log messages by explicitly setting a level. Replaces the former `logging/setLevel` RPC.

Source: https://github.com/modelcontextprotocol/specification/blob/main/schema/2026-07-28/schema.ts (the `io.modelcontextprotocol/logLevel` field on request `_meta`).

The 2026 schema comment that `resources/subscribe` is gone as an RPC (the **`resources.subscribe` bit** is a separate question, §2.4):

> Subscribe to `notifications/resources/updated` for these resource URIs. Replaces the former `resources/subscribe` RPC.

Source: same schema, `SubscriptionFilter.resourceSubscriptions`.

The 2025-11-25 ping method, for contrast:

```ts
export interface PingRequest extends JSONRPCRequest {
  method: "ping";
  params?: RequestParams;
}
```

Source: https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts

The live 2026 site no longer has a ping page. `GET /specification/2026-07-28/basic/utilities/ping` returned **308** to `/specification/2026-07-28/changelog`. The 2025 page is still up: https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/ping.md. `GET /specification/2026-07-28/basic/lifecycle` returned **308** to `/specification/2026-07-28/basic/versioning`. `GET /specification/2026-07-28/basic/utilities/tasks` returned **308** to `/extensions/tasks/overview`.

### 2.2 Client-to-server request methods ADDED in the core schema

| Method | 2025-11-25 | 2026-07-28 | Notes |
| --- | --- | --- | --- |
| `server/discover` | absent | request; **MUST** implement | Changelog major change 3 |
| `subscriptions/listen` | absent | request | Changelog major change 4 |

> 3. Add `server/discover`: servers MUST implement this RPC to advertise their supported protocol versions, capabilities, and identity. Clients MAY call it before any other request for up-front version selection, or use it as a backward-compatibility probe on STDIO ([SEP-2575](https://github.com/modelcontextprotocol/modelcontextprotocol/pull/2575)).

Source: https://modelcontextprotocol.io/specification/2026-07-28/changelog.md

The discovery page repeats the MUST:

> `server/discover` lets a client query a server's supported protocol versions, capabilities, and identity before sending any other requests. Servers **MUST** implement it.

Source: https://modelcontextprotocol.io/specification/2026-07-28/server/discover.md

`subscriptions/listen` is in the 2026 schema as a first-class request. The subscriptions page:

> `subscriptions/listen` opens a long-lived notification stream from the server to the client. […] It replaces the former `resources/subscribe` RPC and the HTTP GET endpoint.

Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/subscriptions.md

**Inferred (not stated as MUST for every server):** unlike `server/discover`, I did not find a sentence that every 2026-07-28 server MUST implement `subscriptions/listen`. A server that never emits list-changed or resource-updated notifications may still exist. The method is in the core schema; whether omitting it is a protocol error is not spelled out the way `server/discover` is.

Extension-only add (not core): `tasks/update`. Changelog major change 6; Tasks overview at https://modelcontextprotocol.io/extensions/tasks/overview.md.

### 2.3 Request methods that remain in *both* schemas

Unchanged as method names (shape of params/results did change — `resultType`, `_meta`, caching fields — that is out of scope for “removed/added methods”):

`resources/list`, `resources/templates/list`, `resources/read`, `prompts/list`, `prompts/get`, `tools/list`, `tools/call`, `completion/complete`.

Still present as method strings in the 2026 schema, but **no longer sent as server-to-client JSON-RPC requests** (see §2.6): `roots/list`, `sampling/createMessage`, `elicitation/create`.

### 2.4 Capability bits — checked separately from methods

This is the distinction that is easy to get wrong. **Verified** from the two `ClientCapabilities` / `ServerCapabilities` interfaces in the schemas, plus the feature pages.

#### Still present (not removed)

| Bit | 2025-11-25 | 2026-07-28 | Status |
| --- | --- | --- | --- |
| `ServerCapabilities.logging` | present | present, **`@deprecated`** | Feature deprecated, **not** removed. Registry: https://modelcontextprotocol.io/specification/2026-07-28/deprecated.md |
| `ServerCapabilities.resources.subscribe` | present | present | **Meaning changed** (below) |
| `ServerCapabilities.resources.listChanged` | present | present | Delivery changed (below) |
| `ServerCapabilities.prompts.listChanged` | present | present | Delivery changed |
| `ServerCapabilities.tools.listChanged` | present | present | Delivery changed |
| `ServerCapabilities.completions` | present | present | Unchanged role |
| `ClientCapabilities.roots` | present (`listChanged` nested) | present as `roots?: {}`, **`@deprecated`** | Feature deprecated, **not** removed |
| `ClientCapabilities.sampling` | present | present, **`@deprecated`** | Feature deprecated, **not** removed |
| `ClientCapabilities.elicitation` | present | present | Still a client feature; how it is *invoked* changed (§2.6) |

The deprecated-features registry is explicit that deprecation is not removal:

> A Deprecated feature remains part of the specification but is scheduled for removal […]
>
> ## Removed
>
> No features have been removed under this policy yet.

Source: https://modelcontextprotocol.io/specification/2026-07-28/deprecated.md

So: **`logging` the capability is still there. `logging/setLevel` the method is gone.** Same pattern for `resources.subscribe` vs `resources/subscribe`.

#### Removed from core capabilities

| Bit | 2025-11-25 | 2026-07-28 |
| --- | --- | --- |
| `ServerCapabilities.tasks` (including `tasks.list`, `tasks.cancel`, `tasks.requests.tools.call`) | present (experimental) | **absent** from `ServerCapabilities` |
| `ClientCapabilities.tasks` (including `tasks.list`, `tasks.cancel`, `tasks.requests.sampling.createMessage`, `tasks.requests.elicitation.create`) | present (experimental) | **absent** from `ClientCapabilities` |
| `ClientCapabilities.roots.listChanged` | nested boolean | **absent** — 2026 `roots` is an empty object type |

2025 server `tasks` capability (quote):

```ts
tasks?: {
  list?: object;
  cancel?: object;
  requests?: {
    tools?: {
      call?: object;
    };
  };
};
```

Source: https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts (`ServerCapabilities`)

2026 `ServerCapabilities` ends with `extensions?: { [key: string]: JSONObject }` and has **no** `tasks` field. Source: https://github.com/modelcontextprotocol/specification/blob/main/schema/2026-07-28/schema.ts

The 2025-11-25 tasks page required that capability at initialize:

> Servers and clients that support task-augmented requests **MUST** declare a `tasks` capability during initialization.

Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks.md

The 2026 Tasks *extension* advertises the same identifier under `capabilities.extensions`:

> 1. **Capability negotiation.** The client includes `io.modelcontextprotocol/tasks` in its per-request capabilities. The server advertises the same extension in its own `server/discover` capabilities.

Source: https://modelcontextprotocol.io/extensions/tasks/overview.md

#### Added capability field

`extensions` on both `ClientCapabilities` and `ServerCapabilities`.

> 1. Add `extensions` field to `ClientCapabilities` and `ServerCapabilities` to support optional [extensions](/docs/extensions/overview) beyond the core protocol.

Source: https://modelcontextprotocol.io/specification/2026-07-28/changelog.md (Minor changes)

#### Capability bits whose *meaning* changed

**`ServerCapabilities.logging` — method gone, bit stays, control path changed.**

2025 (session-scoped RPC):

> To configure the minimum log level, clients **MAY** send a `logging/setLevel` request

Source: https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/logging.md

2026 (per-request `_meta`; `logging/setLevel` not on this page as a request):

> To receive log messages for a specific request, include `io.modelcontextprotocol/logLevel` in the request's `_meta`. The server **MUST NOT** emit `notifications/message` for a request that does not include this field.

Source: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/logging.md

The logging *capability* declaration is the same JSON (`"logging": {}`) on both pages.

**`ServerCapabilities.resources.subscribe` — method gone, bit stays, wiring changed.**

2025:

> * `subscribe`: whether the client can subscribe to be notified of changes to individual resources.

and the protocol message is `resources/subscribe`.

Source: https://modelcontextprotocol.io/specification/2025-11-25/server/resources.md

2026 (same JSON key, different sentence):

> * `subscribe` : whether the server supports resource-specific update notifications for resources requested through subscriptions/listen using the resourceSubscriptions filter.

Source: https://modelcontextprotocol.io/specification/2026-07-28/server/resources.md

**`listChanged` (tools / prompts / resources) — bit stays, delivery is now opt-in on `subscriptions/listen`.**

2026 schema on `notifications/resources/list_changed`:

> This is only delivered on a `subscriptions/listen` stream when the client requested it via the `resourcesListChanged` filter field.

and on `SubscriptionFilter`:

> Each notification type is **opt-in**; the server **MUST NOT** send notification types the client has not explicitly requested here.

Source: https://github.com/modelcontextprotocol/specification/blob/main/schema/2026-07-28/schema.ts

In 2025 the same notification was a session-level push after `initialize`, with no listen RPC.

**There was never a `ping` capability.** Removing `ping` did not remove a capability bit. **There was never an `initialize` capability.**

### 2.5 Notifications removed / added (not request methods)

Listed so they are not mistaken for “methods a server answers.”

Removed as notification method strings:

| Notification | Direction | Changelog |
| --- | --- | --- |
| `notifications/initialized` | client → server | Major change 2 |
| `notifications/roots/list_changed` | client → server | Major change 5 |
| `notifications/elicitation/complete` | server → client | Minor change 11 |
| `notifications/tasks/status` | server → client | Major change 6 (tasks left core) |

Added:

| Notification | Direction |
| --- | --- |
| `notifications/subscriptions/acknowledged` | server → client |

Minor change 11 quote:

> 11. Remove the `notifications/elicitation/complete` notification and the `elicitationId` field of URL mode elicitation requests, both introduced in `2025-11-25`.

Source: https://modelcontextprotocol.io/specification/2026-07-28/changelog.md

### 2.6 Direction change that is not a method-name deletion

2026 stdio:

> The server **MUST NOT** write JSON-RPC *requests* to `stdout`. Server-to-client interactions are carried in `InputRequiredResult` replies; see Multi Round-Trip Requests.

Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio.md

Changelog major change 7: MRTR “replaces the previous approach of sending server-initiated requests, such as `roots/list`, `sampling/createMessage`, or `elicitation/create`.”

**Verified:** those three strings still exist as `method: "…"` in the 2026 schema (they are the embedded request types). **Inferred:** a 2026-07-28 server that *sends* `elicitation/create` as a top-level JSON-RPC request on stdio is violating the MUST NOT above; that is a different bug class from “still *answers* a removed client-to-server method.”

HTTP GET as a Streamable HTTP endpoint is also gone (changelog major change 4 / 9). That is a transport binding, not a JSON-RPC method.

---

## 3. What a conforming 2026-07-28 server should answer for each removed request method

Gate: these answers apply when the server is speaking **modern** 2026-07-28 (the request carries `_meta.io.modelcontextprotocol/protocolVersion` = `"2026-07-28"`). A **dual-era** server that receives a legacy `initialize` is specified to select legacy semantics and then *should* still answer `ping` and the rest. That split is verified:

> A dual-era **server** selects its behavior from how the client opens:
>
> * A request carrying modern per-request `_meta` is served statelessly according to this revision.
> * An `initialize` request selects legacy semantics, scoped to the stdio process (stdio) or the session (HTTP), as specified by the negotiated legacy protocol version.

Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning.md

Required `_meta` on every modern request:

> | `io.modelcontextprotocol/protocolVersion` | `string` | Yes | Protocol version for this request (e.g., `"2026-07-28"`) |
> | `io.modelcontextprotocol/clientCapabilities` | `ClientCapabilities` | Yes | Client capabilities relevant to this request |
>
> A request missing any required field is malformed; the server **MUST** reject it with JSON-RPC error code `-32602` (Invalid params).

Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/index.md

### 3.1 `initialize`

The spec **does** specify an outcome, and **does not** specify a single error code.

Compatibility matrix, Legacy client × Modern server:

> Fails. stdio: the server rejects `initialize` with a JSON-RPC error; **the exact code is implementation-defined** (`initialize` is an unknown method and the request also lacks the required `_meta` fields). HTTP: the request is missing the required headers and is rejected per server validation with `400 Bad Request` […].

and:

> A server that supports only [modern](#terminology) versions **SHOULD** name the protocol versions it supports in any error it returns to an `initialize` request, on any transport

Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning.md

Dual-era servers **MAY** answer `initialize` (same page, “Legacy | Dual-era | Works”). **Do not treat a successful `initialize` as a 2026-07-28 failure unless `server/discover` listed no legacy versions.**

### 3.2 `ping`, `logging/setLevel`, `resources/subscribe`, `resources/unsubscribe`

The 2026 spec **does not** contain a per-method sentence of the form “a server MUST respond to `ping` with …”. Those methods are simply not in the 2026 schema.

What the spec *does* say, which applies to any unimplemented RPC:

1. MCP messages are JSON-RPC 2.0. Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/index.md (“All messages between MCP clients and servers **MUST** follow the JSON-RPC 2.0 specification”).
2. MCP uses the standard JSON-RPC codes for general protocol failures, including the `-32600` to `-32603` range. Same page, “Error Codes”:

   > MCP uses the standard JSON-RPC 2.0 error codes (`-32700`, `-32600` to `-32603`) for general protocol failures.

3. JSON-RPC 2.0 defines `-32601` as “Method not found” / “The method does not exist / is not available.” Example: request method `"foobar"` → error `-32601`. Source: https://www.jsonrpc.org/specification
4. **On Streamable HTTP**, unknown methods are explicit:

   > If the server does not implement the requested RPC method, it **MUST** respond with `404 Not Found` and a JSON-RPC error with code `-32601` (`Method not found`).

   Source: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http.md

**Inferred for stdio (this package’s transport):** a well-formed 2026 request (required `_meta` present) whose method is one of the removed RPCs should be answered with JSON-RPC `-32601`, same as the existing `jsonrpc/method-not-found` rule. The spec does **not** repeat that MUST on the stdio page. A request that is *both* an unknown method *and* missing required `_meta` is the `initialize` situation the spec already called implementation-defined (`-32601` vs `-32602`); the same ambiguity exists for a raw `ping` sent without `_meta`.

**A successful result (empty or otherwise) is not conforming** for a modern 2026-07-28 request to these methods — **inferred** from their absence in the schema plus changelog “Remove `ping`” / “Replaces the former `logging/setLevel` RPC” / “Replaces the former `resources/subscribe` RPC”. The spec never says “MUST NOT return a result for `ping`”; it deletes the method.

### 3.3 Core `tasks/*`

**`tasks/list` and `tasks/result`:** removed from core *and* from the redesigned extension (“removes `tasks/list`”, “replaces the blocking `tasks/result` method”). A 2026-07-28 server should treat them as unknown methods even if it advertises `io.modelcontextprotocol/tasks`. Sources: changelog major change 6; Tasks overview does not mention `tasks/list` or `tasks/result` (https://modelcontextprotocol.io/extensions/tasks/overview.md).

**`tasks/get` and `tasks/cancel`:** removed from *core*. They remain as extension RPCs. A core-only 2026 server should treat them as unknown. A server that advertised `extensions["io.modelcontextprotocol/tasks"]` is expected to serve them. Source: https://modelcontextprotocol.io/extensions/tasks/overview.md (“Serve `tasks/get`”, “Handle `tasks/cancel`”).

**Inferred:** sending `tasks/get` to a 2026 server that did *not* advertise the extension should yield `-32601` (or possibly `-32021` MissingRequiredClientCapability if the server knows the method but the client omitted the extension — the spec’s `-32021` rule is about *processing a request that requires a capability the client did not declare*, not about a client calling a method the server does not implement). I would not encode `-32021` as the expected code without an extension-spec quote that says so.

---

## 4. What this package can actually test today

Read against `lib/src/harness.dart` and `package:dart_mcp` 0.5.2 at `/Users/yusufihsan/.pub-cache/hosted/pub.dev/dart_mcp-0.5.2`.

### 4.1 What the harness can send

`McpServerHarness.start` always:

1. Builds an `MCPClient` and `connectServer`.
2. Sends `initialize` with `protocolVersion: ProtocolVersion.latestSupported`.
3. Rejects the server if `ProtocolVersion.tryParse` fails or `!version.isSupported`.
4. Sends `notifications/initialized`.

After that, wrapped I/O is:

| Harness API | JSON-RPC method |
| --- | --- |
| `listTools` | `tools/list` (paginated) |
| `callTool` | `tools/call` |
| `listResources` | `resources/list` (paginated) |
| `readResource` | `resources/read` |
| `listPrompts` | `prompts/list` (paginated) |
| `getPrompt` | `prompts/get` |
| `sendRawRequest(method)` | `method` with **no params** |
| `connection.ping()` | `ping` (unwrapped; used by `utilities/ping`) |

`sendRawRequest` is documented as the unknown-method probe and takes only a method name — no `_meta`, no arguments.

Unwrapped `harness.connection` (`dart_mcp` `ServerConnection`) also has typed `subscribeResource`, `unsubscribeResource`, `setLogLevel`, `listResourceTemplates`, `requestCompletions`, and public `sendRequest(methodName, [request])`.

### 4.2 What `dart_mcp` 0.5.2 cannot do

**Verified** from `lib/src/api/api.dart`:

```dart
enum ProtocolVersion {
  v2024_11_05('2024-11-05'),
  v2025_03_26('2025-03-26'),
  v2025_06_18('2025-06-18'),
  v2025_11_25('2025-11-25');
  static const latestSupported = ProtocolVersion.v2025_11_25;
}
```

There is no `2026-07-28` value. `tryParse("2026-07-28")` is `null`. A server that answers `initialize` with `"2026-07-28"` already dies in `start` as `McpHandshakeException` / `initialize/protocol-version` (“cannot assess this server”).

Further gaps in that package: no `server/discover`, no `subscriptions/listen`, no per-request `_meta.io.modelcontextprotocol/*`, no `resultType`, no `extensions` on capabilities, no Tasks extension types. It still registers `ping`, `initialize`, `logging/setLevel`, `resources/subscribe`, `resources/unsubscribe`. Comment at the top of `api.dart`: “Interfaces are based on … schema/2025-06-18/schema.ts” (and the enum was later extended through 2025-11-25).

### 4.3 Testable now vs needs a `dart_mcp` capability that does not exist yet

| Probe | Testable now? | Why |
| --- | --- | --- |
| Open a **modern** 2026-07-28 session (no `initialize`, `_meta` on every request) | **No — needs dart_mcp (and harness `start`) that do not exist yet** | `start` always `initialize`s; `ProtocolVersion` tops out at 2025-11-25; no `_meta` injection |
| `server/discover` as a 2026 request | **No — needs dart_mcp** | Even `sendRawRequest('server/discover')` would go out *after* `initialize`, with no required `_meta`. A conforming modern server must reject missing `_meta` with `-32602` (`basic/index.md`), which is indistinguishable from “method exists but params are wrong.” |
| `subscriptions/listen` | **No — needs dart_mcp** | No typed API; long-lived stream; requires `_meta` and `params.notifications` (`sendRawRequest` cannot pass params) |
| Removed-method probe **on a modern request** (`ping` / `logging/setLevel` / `resources/subscribe` / `resources/unsubscribe` / `tasks/*` with 2026 `_meta`) | **No — needs dart_mcp** | Same `_meta` gap. Without `_meta`, §3.2’s `-32601` vs `-32602` ambiguity applies |
| Removed-method probe **after today’s handshake** | **Sendable, but it is the wrong era** | `sendRawRequest('ping')` works. On a dual-era server, `initialize` selected **legacy** semantics (versioning.md), so a successful `ping` is *correct*. Treating it as a 2026 failure would false-fail dual-era servers |
| `connection.ping()` / `utilities/ping` | **Yes, for legacy only** | Current rule **requires** ping to succeed. That is right for 2025-11-25 and the inverse of 2026-07-28 |
| `connection.setLogLevel` / `subscribeResource` / `unsubscribeResource` | **Yes as unwrapped dart_mcp APIs, wrong era** | Same legacy-session problem |
| `jsonrpc/method-not-found` (`mcp_probe/does-not-exist`) | **Yes today** | Already uses `sendRawRequest`. Still valid in 2026 (unknown methods → `-32601`), but does not cover *named removed* methods |
| `initialize` rejection for a modern-only server | **Not as a post-handshake rule** | `start` *is* the `initialize` call. A modern-only stdio server fails handshake (`initialize/handshake`). That failure is currently indistinguishable from a dead/broken binary |
| Assert `resources.subscribe` means `subscriptions/listen` | **No — needs dart_mcp** | Needs the new RPC |
| Assert `logging` capability without answering `logging/setLevel` | **No — needs a modern session** | On a legacy session the method is still valid |
| Tasks extension (`tasks/get`, `tasks/update`) | **No — needs dart_mcp** | dart_mcp 0.5.2 has no tasks API at all (not even the 2025-11-25 experimental one) |

**Inferred consequence:** every rule proposed in §5 is blocked on speaking 2026-07-28. The only current probe that is even *shaped* like the new rules is `sendRawRequest`, and it cannot carry `_meta` or params. Extending `sendRawRequest` to accept a params map would still not be enough until `start` can skip `initialize` and `ProtocolVersion` includes `2026-07-28` (or the harness bypasses `dart_mcp`’s handshake).

The existing rule `utilities/ping` will also have to become version-gated: requiring ping is a **2025-11-25** assertion; on 2026-07-28 it would certify the bug this research is about.

---

## 5. Proposed rule set

Naming follows `lib/src/conformance.dart`: `area/kebab-name` (`initialize/handshake`, `utilities/ping`, `jsonrpc/method-not-found`, `capabilities/tools-listable`). New area `era/` for revision-gated checks so the existing 2025-shaped ids can stay.

**Common preamble (all `era/*` rules):**

- Run only when the session is modern 2026-07-28 (negotiated via `server/discover` / per-request `_meta`, not via `initialize`).
- Send a **well-formed** 2026 request: `params._meta` includes `io.modelcontextprotocol/protocolVersion: "2026-07-28"` and `io.modelcontextprotocol/clientCapabilities`.
- Do not run these after a legacy `initialize`; that selects the other era.

Verdict pattern copied from `jsonrpc/method-not-found`, but a **result** is an **error** here (still implementing a deleted RPC), not a warning:

| Server response | Verdict |
| --- | --- |
| JSON-RPC `-32601` | info — method is gone |
| JSON-RPC result | **error** — still answers a removed method |
| JSON-RPC `-32602` on a well-formed 2026 body | **error** — the method is still implemented (bad params, not unknown) |
| Timeout | error |
| Any other JSON-RPC code | warning — answered, but not as method-not-found |
| HTTP (out of scope for this stdio harness) | spec says 404 + `-32601`; not testable here |

### 5.1 Removed client-to-server methods

| Rule id | Sends | Verdict | Spec justification |
| --- | --- | --- | --- |
| `era/removed-ping` | `ping` with 2026 `_meta`, no other params | `-32601` info; result error | Changelog major 5 “Remove `ping`”; 2026 schema has 0 `ping` methods; JSON-RPC `-32601`; HTTP MUST `-32601` (stdio inferred). **The spec does not name `ping` in 2026.** |
| `era/removed-logging-setLevel` | `logging/setLevel` with 2026 `_meta` and `params.level: "info"` | same | Changelog major 5; schema “Replaces the former `logging/setLevel` RPC”; 2026 logging page has no such request. **Do not require the `logging` capability to be absent** — it is deprecated, not removed (`deprecated.md`). |
| `era/removed-resources-subscribe` | `resources/subscribe` with 2026 `_meta` and `params.uri` | same | Changelog major 4; schema “Replaces the former `resources/subscribe` RPC”; 2026 resources page uses `subscriptions/listen`. **Do not require `resources.subscribe` to be absent** — the bit remains with new meaning. |
| `era/removed-resources-unsubscribe` | `resources/unsubscribe` with 2026 `_meta` and `params.uri` | same | Changelog major 4. |
| `era/removed-tasks-list` | `tasks/list` with 2026 `_meta` | same, **even if** `extensions["io.modelcontextprotocol/tasks"]` is advertised | Changelog major 6 “removes `tasks/list`”. |
| `era/removed-tasks-result` | `tasks/result` with 2026 `_meta` | same, even with the Tasks extension | Changelog major 6 “replaces the blocking `tasks/result` method”. |
| `era/removed-tasks-get-without-extension` | `tasks/get` with 2026 `_meta` | same **only when** the server did not advertise `io.modelcontextprotocol/tasks` | Core schema has no `tasks/get`; extension overview still has it. Skip (info) if the extension is advertised. |
| `era/removed-initialize` | `initialize` **as a subsequent modern request** (2026 `_meta` present, method `initialize`) | `-32601` info; result error | 2026 schema has no `initialize` method. **Not** the same as “server must reject a legacy handshake”: dual-era servers MAY answer a *legacy-shaped* `initialize` (versioning.md). Skip this rule unless `server/discover.supportedVersions` contains no legacy id. For modern-only servers, a *first* `initialize` without `_meta` is allowed to be any JSON-RPC error (“exact code is implementation-defined”). |

### 5.2 Added methods

| Rule id | Sends | Verdict | Spec justification |
| --- | --- | --- | --- |
| `discover/server-discover` | `server/discover` with 2026 `_meta` (empty `clientCapabilities` is valid per the example on the discovery page) | **error** if RPC error / timeout / missing `supportedVersions` or `capabilities`; **info** if `DiscoverResult` with `resultType: "complete"` (or absent `resultType`, which clients MUST treat as `"complete"`) | “Servers **MUST** implement it.” https://modelcontextprotocol.io/specification/2026-07-28/server/discover.md ; changelog major 3; `resultType` rule in https://modelcontextprotocol.io/specification/2026-07-28/basic/index.md |
| `era/subscriptions-listen` | `subscriptions/listen` with 2026 `_meta` and `params.notifications` matching declared bits (`resourcesListChanged` / `toolsListChanged` / `promptsListChanged` / `resourceSubscriptions`) | **error** if the server declared the corresponding `listChanged` or `resources.subscribe` bit and then fails the RPC or never sends `notifications/subscriptions/acknowledged`; **info** on ack whose filter is a subset of the request | Subscriptions page + 2026 resources “subscribe” meaning. **Inferred** that a server which declared none of those bits MAY omit the method — skip in that case. |

### 5.3 Capability-meaning checks (method vs bit)

| Rule id | Sends | Verdict | Spec justification |
| --- | --- | --- | --- |
| `era/logging-bit-not-setLevel` | (depends on `era/removed-logging-setLevel`) | If `logging` is declared, that is **info**, not error. The failure mode is still answering `logging/setLevel`. | `logging` is Deprecated, not Removed (`deprecated.md`, 2026 logging page). |
| `era/resources-subscribe-bit` | `subscriptions/listen` with `resourceSubscriptions: [<uri from resources/list>]` when `resources.subscribe == true` | **error** if the listen call is `-32601` or the ack omits `resourceSubscriptions` with no documented unsupported-type handling; **info** on ack | 2026 resources.md definition of the `subscribe` bit. **Inferred** severity if the server acknowledges a strictly smaller filter — the subscriptions page says the client SHOULD handle unsupported types gracefully, so an omitted URI is a warning at most unless the bit was `true` and *every* URI is dropped. |
| `era/no-core-tasks-capability` | inspect `server/discover` capabilities | **error** if `capabilities.tasks` is present as the 2025 core shape; **info** if tasks live only under `capabilities.extensions["io.modelcontextprotocol/tasks"]` or are absent | Changelog major 6; 2026 `ServerCapabilities` has `extensions`, not `tasks`. |

### 5.4 Existing rules that must become era-gated (not new ids, but they interact)

| Existing id | 2025-11-25 | 2026-07-28 |
| --- | --- | --- |
| `initialize/handshake` | error if `initialize` fails | a modern-only server *will* fail this; that is not a defect. Dual-era: keep. Needs an era fork inside `checkServer`. |
| `utilities/ping` | error if ping does not return an empty result | **invert**: answering ping on a modern session is the bug (`era/removed-ping`). |
| `jsonrpc/method-not-found` | keep | keep; still valid. Does not replace the named `era/removed-*` rules. |
| `capabilities/tools-listable` etc. | keep | keep (`tools/list` still exists). Results now require `resultType` — a possible later rule, not a removed-method rule. |

### 5.5 What I would *not* add yet

- A rule that “`logging` capability must be absent” — contradicts `deprecated.md`.
- A rule that “`resources.subscribe` must be absent” — the bit is still in the 2026 schema.
- A rule that every 2026 server MUST implement `subscriptions/listen` — not stated as MUST.
- Testing HTTP GET removal / `Mcp-Session-Id` — this package is stdio-only (`Agents.md`).
- Testing that the server does not *send* `elicitation/create` as a JSON-RPC request — needs a fixture that would have elicited; not a `sendRawRequest` probe.

---

## Appendix A — Request-method inventory (verified)

**2025-11-25 schema methods** (`method: "…"`):  
`initialize`, `ping`, `resources/list`, `resources/templates/list`, `resources/read`, `resources/subscribe`, `resources/unsubscribe`, `prompts/list`, `prompts/get`, `tools/list`, `tools/call`, `tasks/get`, `tasks/result`, `tasks/cancel`, `tasks/list`, `logging/setLevel`, `sampling/createMessage`, `completion/complete`, `roots/list`, `elicitation/create`  
plus notifications listed in §2.5.

**2026-07-28 schema methods:**  
`server/discover`, `resources/list`, `resources/templates/list`, `resources/read`, `subscriptions/listen`, `prompts/list`, `prompts/get`, `tools/list`, `tools/call`, `sampling/createMessage`, `completion/complete`, `roots/list`, `elicitation/create`  
plus notifications including `notifications/subscriptions/acknowledged`.

**Removed request methods (set difference, client-to-server in 2025):**  
`initialize`, `ping`, `logging/setLevel`, `resources/subscribe`, `resources/unsubscribe`, `tasks/get`, `tasks/result`, `tasks/cancel`, `tasks/list`.

**Added request methods:**  
`server/discover`, `subscriptions/listen`.

---

## Appendix B — Sources fetched

| URL | Role |
| --- | --- |
| https://modelcontextprotocol.io/specification/latest | 307 target |
| https://modelcontextprotocol.io/specification/2026-07-28/index.md | latest body |
| https://modelcontextprotocol.io/specification/2026-07-28/changelog.md | delta vs 2025-11-25 |
| https://modelcontextprotocol.io/specification/2026-07-28/deprecated.md | deprecation ≠ removal |
| https://modelcontextprotocol.io/specification/2026-07-28/basic/index.md | JSON-RPC, `_meta`, error codes, `resultType` |
| https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning.md | modern/legacy, initialize error |
| https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio.md | MUST NOT server-to-client requests; discover probe |
| https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http.md | unknown method MUST `-32601` |
| https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/subscriptions.md | `subscriptions/listen` |
| https://modelcontextprotocol.io/specification/2026-07-28/server/discover.md | MUST implement |
| https://modelcontextprotocol.io/specification/2026-07-28/server/resources.md | `subscribe` bit meaning |
| https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/logging.md | per-request log level |
| https://modelcontextprotocol.io/specification/2025-11-25/index.md | previous revision |
| https://modelcontextprotocol.io/specification/2025-11-25/changelog.md | confirms 2025-11-25 follows 2025-06-18 |
| https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle.md | `initialize` handshake |
| https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/ping.md | ping MUST empty result |
| https://modelcontextprotocol.io/specification/2025-11-25/server/resources.md | `resources/subscribe` method |
| https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/logging.md | `logging/setLevel` method |
| https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks.md | core `tasks` capability |
| https://modelcontextprotocol.io/extensions/tasks/overview.md | tasks as extension |
| https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts | method/capability source of truth |
| https://github.com/modelcontextprotocol/specification/blob/main/schema/2026-07-28/schema.ts | method/capability source of truth |
| https://www.jsonrpc.org/specification | `-32601` |
| `lib/src/harness.dart`, `lib/src/conformance.dart` | what this package can send |
| `dart_mcp` 0.5.2 `lib/src/api/api.dart` | `ProtocolVersion.latestSupported = v2025_11_25` |
