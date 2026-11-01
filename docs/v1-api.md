# Ceiv v1 public API design

Status: evolving implementation contract, 1 November 2026. The packaged v1
gate remains under verification. See
[desktop framework map](desktop-framework-map.md) for the refined sequence.
[Reference study](api-reference-study.md) explains the
Tauri, Electron, and Wails patterns behind the choices.

## Package boundary

Ceiv remains a separate SDK. `ceiv` is its CLI, `ceiv.app` and related
Cyna modules are its native API, generated `commands.ts` holds app bindings,
and package `ceiv/sdk` holds frontend framework services. The installed SDK supplies the host and generator. Apps depend
on a matching SDK
version; generated bindings record that version. AppKit, WebKit, NSView, and
renderer objects never cross a public API boundary.

The frontend uses Weiv and generated native functions. The Cyna module owns app
operations, startup configuration, and long lived services. The frontend owns
the DOM and view state. Both sides use opaque `WindowId` and
`ActionId` values; IDs are scoped to one app process.
The [app architecture guide](app-architecture.md) sets out the default division
of work and explains why some services have entry points on both sides.

## App and command entry points

An app has `app.json`, `cyna.toml`, `src/lib.cy`, and `web/App.weiv`.
`app.json` contains static identity, resources, and declared capabilities.
The initial window is configured in Cyna code before the host launches.

```json
{
  "id": "dev.example.editor",
  "name": "Editor",
  "entry": "index.html",
  "capabilities": []
}
```

```cyna
import { configure_window } from ceiv.lib;

export c("ceiv_app_configure") fn configure(): void {
    const configured = configure_window("Editor", 900, 650);
}
```

`export c("symbol") fn` under `src` is discovered as a frontend callable command.
`ceiv build` generates typed `web/generated/commands.ts` bindings,
`ceiv/sdk` for framework services, and the private host adapter.
The function name maps from snake case to camel case;
an adjacent `@ceiv` comment may set a stable wire name or express bounds and
types absent from the C ABI. Unsupported signatures fail the build. A
signature change regenerates the TypeScript type.

```cyna
export c("editor_word_count") fn word_count(text: c_str): c_int {
    // App implementation.
    return 0;
}
```

```ts
import { wordCount } from "./generated/commands.ts";
const count: number = await wordCount(text);
```

Calls are asynchronous. The final options argument is
`{ signal?: AbortSignal; deadlineMs?: number }`. The default deadline is 10
seconds; the maximum is 30 seconds. Cancellation settles the page promise but
does not undo native work already performed. Errors have `{ code, message }`.
The host validates arguments and results, origins, size limits, window
generation, and late replies.

## Shell and windows

`ceiv.app` exposes `current_app()`, `quit()`, `quit_on_last_window(bool)`,
and app lifecycle events. When the last window stays closed, dock activation
reopens one.
`ceiv.window` exposes `current()`, `open(title, width, height)`, `focus(id)`,
`open_with_options(WindowOptions)`, `get_state(id)`, `set_size(id, width, height)`,
`set_bounds(id, x, y, width, height)`,
`set_title(id, title)`, `close(id)`, and `reload(id)`. All operations return a
typed result. `open` returns a new `WindowId`; `current` is only valid while
handling a window scoped command or event. A closed or unknown ID returns
`WindowError.not_found`. Window IDs are not durable across launches.

Opening a window creates a separate webview, bridge session, event sequence,
slot registry, and pending call set. Navigation invalidates calls and view
contexts. Closing a window invalidates its calls before removal. The default
policy quits after the last window closes; `quit_on_last_window(false)` keeps
the process alive. The page can register one `setCloseHandler` callback.
The callback returns `true` to allow closing or `false` to cancel. A missing
reply after five minutes cancels the request. The same decision path handles
the title bar, menu and programmatic `performClose` paths.

The frontend API exposes `currentWindow(): Promise<WindowId>` and the event API
below. `WindowId` is a branded numeric handle on the frontend and a Cyna value
on the backend. The separate session UUID authenticates bridge traffic.
`app.windows` also reports `focused`, `blurred`, and `resized`; resize events
include width and height.

## Events

There are two app-facing sides: the **Cyna backend** and the **Weiv frontend**.
The native host sits between them. A frontend `click`, `input`, `keydown`, or
`focus` handler is an ordinary DOM/Weiv handler; it stays in the frontend and
does not need a Ceiv subscription. A **native event** is a notification
created by the host or Cyna backend that a frontend may need to observe.

| Direction | API | Example |
| --- | --- | --- |
| Frontend → Cyna backend | Call a generated command and await its result | `await saveDocument(text)` |
| Host/Cyna backend → frontend | Subscribe to a typed topic, then receive notifications | `events.subscribe("app.windows", handler)` |
| Frontend → frontend | Use DOM and Weiv events directly | `@click`, `addEventListener("focus", ...)` |

The subscription flow is concrete. The frontend calls a typed subscription
function. Ceiv sends `subscribe` through the same WebKit bridge used by
commands. The host validates the topic and owning window, creates a
subscription, and acknowledges it. Later, the host or Cyna backend publishes
an event; the host sends it to subscribed live windows; the generated frontend
client calls the handler. The returned function unsubscribes. An event has no
reply. Use a command when the caller needs a result or an action must be
acknowledged.

```text
Weiv handler ── command request ──> host ──> Cyna function
Weiv Promise <── command reply ───── host <── Cyna result

Cyna/host ── publish ──> host ── event ──> subscribed Weiv handler
Weiv ── subscribe/unsubscribe ──> host
```

`events.subscribe("app.windows", handler)` in the generated
`commands.ts` client resolves to an unsubscribe function. It listens to the
host topic `app.windows` and receives `{ state, window }`. States include
`opened`, `reloading`, `closed`, `focused`, `blurred`, and `resized` (with width
and height). The host sends these events to
subscribed live windows; a closing window cannot receive its own `closed`
notification. The page uses its ordinary DOM `pagehide` event for its own
cleanup.

```ts
import { events } from "./generated/events.ts";

const unsubscribe = await events.subscribe("app.windows", ({ state, window }) => {
  console.log(state, window);
});
// When the view no longer needs updates:
unsubscribe();
```

The same `events.subscribe(topic, handler)` function
covers app-defined native events. The generator expands the `NativeEvents`
type map from SDK events and Cyna event declarations. A literal topic selects
its payload type, so the handler is inferred without a separate function for
each topic. Unknown topics fail TypeScript checking and native validation.
Cyna publishes to one window with `publish_window` or all live windows with
`publish_app`. `// @ceiv-event` declarations generate topic payload types.
This follows the targeted emit and unlisten pattern in
[Tauri](https://v2.tauri.app/develop/calling-frontend/) and
[Wails](https://v3.wails.io/reference/events/), while keeping the page-facing
bridge narrow as recommended by [Electron's IPC guide](https://www.electronjs.org/docs/latest/tutorial/ipc).

```ts
import { events } from "./generated/events.ts";
const unsubscribe = await events.subscribe("document.changed", ({ documentId, revision }) => {
  refreshDocument(documentId, revision);
});
const nextChange = await events.once("document.changed");
```

The implemented signatures are
`subscribe<K extends keyof NativeEvents>(topic: K, handler:
(payload: NativeEvents[K]) => void, options?: { signal?: AbortSignal }):
Promise<Unsubscribe>` and `once<K extends keyof NativeEvents>(topic: K,
options?: { signal?: AbortSignal }): Promise<NativeEvents[K]>`.
`subscribe` resolves after host registration; `Unsubscribe` is idempotent.
`once` removes its subscription after the first delivery.

The publisher chooses `window` for one window or `app` to fan out to all live
windows. A subscription is always owned by the subscribing window, even when
the event was published app-wide. The host validates the declared topic and
payload before delivery. The frontend receives only payload values, not a
WebKit message or a native host object.

Subscriptions belong to one window and one page generation. Navigation or
window close removes them; the frontend subscribes again after reload. Events
are ordered per subscription with sequence numbers, and duplicate or old
sequences are ignored. Delivery is best effort: a slow page can miss events,
there is no replay, and an event is not a reliable request/reply channel. The
current host limits each window to 16 subscriptions and 64 in-flight event
deliveries, with a 64 KiB bridge envelope. V1 retains explicit limits and a
way for a publisher to observe queue saturation. Initial state comes from a
command; events report later changes.
Continuous, high-rate streams need a separate channel with flow control; v1
events are for occasional state and lifecycle notifications.

Menu clicks and shortcut actions use an acknowledged dispatch with a ten
second deadline. The host records failed or timed out page actions in its log.

## Actions, menus, and shortcuts

An `ActionId` is a stable string such as `document.save`. An action has a
label, optional standard role, optional focused shortcut, and runtime state:
`enabled`, `checked`, and `visible`. A menu item references an action ID.
Menu selection, a menu accelerator, a focused shortcut, and a context menu
selection dispatch the same action. Ordinary key and pointer events stay in
the page's DOM event system. The dispatch request includes the action ID,
source (`menu`, `shortcut`, or `context`), window ID, and context data. A Cyna
backend action callback can handle app actions when no page context owns them.

The app defines the native menu tree through `ceiv.menu.set_application`
and updates it with `set_state(action_id, enabled, checked, visible)`. Supported nodes are action,
separator, and submenu. Standard roles include quit, close, undo, redo, cut,
copy, paste, and select all; roles use platform behavior and cannot also have
an app callback. Menu IDs and action IDs are unique within the app. Unknown
action references and duplicate IDs fail registration. Native menus are
window aware: their enabled and checked state reflects the focused window.

The generated frontend API exposes `createActionContext({ scope, actions })`. `scope` is
`app`, `window`, or `view`. A context handle has `activate()`, `deactivate()`,
`update(actionId, state)`, and `dispose()`. App contexts live until disposed;
window contexts belong to the current window; view contexts belong to the
current page generation. A view context is active only while its associated
element or view has focus. Navigation and window close dispose page contexts.
An action callback receives `{ id, source, window, data }` and returns
`void | Promise<void>`. Failures are logged and do not invoke a lower priority
handler. A Cyna `menu.on_action` callback receives the same fields as C values;
it returns zero when handled and a nonzero value to pass to a page context.

Resolution uses the focused window and selects the highest active scope:
focused view, then window, then app. Within a scope, the most recently
activated context wins. A disabled winning action stays disabled; it does not
fall through to a lower scope. An absent action falls through. Menu state uses
the same resolution and updates before display. Standard text editing roles
retain native behavior in editable controls. System reserved combinations
cannot be overridden. Unsupported or conflicting shortcuts fail registration
with a typed error instead of silently disappearing.

Shortcut strings use `CmdOrCtrl+S`, `Cmd+S`, `Ctrl+S`, `Alt+S`, and `Shift`
modifiers with named keys such as `Enter`, `Escape`, and `F1`. The SDK parses
and canonicalizes them at registration. They work only while the app is
focused. System wide hotkeys are outside v1 and require a separate capability.

```ts
import { createActionContext } from "ceiv/sdk";

const editor = createActionContext({
  scope: "view",
  element: editorElement,
  actions: {
    "document.save": { enabled: dirty, run: saveDocument },
  },
});
editor.activate();
editor.update("document.save", { enabled: true });
editor.dispose();
```

## Context menus

`ceiv.menu.register_context(id, tree)` registers a reusable native menu.
The page calls `popupContextMenu(id, { element, data })`; the host anchors it
to the element and returns the selected action or cancellation. Context data
must be serializable and bounded by the bridge limit. The host supplies the
window ID. A context menu uses the same action state and resolution as the
application menu. Text inputs retain standard editing actions unless the app
explicitly adds or replaces them. A popup is cancelled when its window closes
or navigates.

## Webview and native slots

WebKit is private to the macOS host. v1 supports one bundled Weiv page per
window, a `cyna-app://local` asset origin, and no arbitrary remote navigation.
The page never receives a raw WebKit handle. Child webviews and remote content
are outside v1.

Native slots are opt-in. The page anchors a slot to a DOM element with
`attachNativeSlot(element, slotId)`, which returns a disposer. A native
surface provider registers a view under that ID for one window. The host owns
coordinate conversion, clipping, visibility, scale, and cleanup. Ordinary
apps link no media or renderer module. The internal placement boundary exists
today; a public provider API requires M2 lifecycle, input, accessibility, and
display-change work. v1 does not promise custom Metal surfaces until that
gate passes.

## CLI and diagnostics

`ceiv new <directory> --id <id>`, `check`, `build`, and `run` are the v1 CLI
verbs. `check` validates the manifest, exports, generated binding drift, and
Cyna source. `build` generates bindings and packages a `.app`. `run` builds
and opens a new instance. Diagnostics name the app file and declaration that
failed; they do not print bridge payloads. A distributable CLI must resolve
its own host and Weiv dependencies rather than depend on a sibling checkout.

## Error contract

| Code | Meaning |
| --- | --- |
| `INVALID_ARGUMENT`, `INVALID_RESULT` | Value violates generated command or event contract |
| `UNKNOWN_COMMAND`, `UNKNOWN_ACTION` | Unregistered command or action ID |
| `WindowError.not_found`, `WindowError.unavailable` | Cyna window ID is absent, or no current command window exists |
| `CONTEXT_DISPOSED` | Context handle outlived its page or window |
| Menu registration returns `false` | Shortcut conflicts, reserved keys or an invalid menu tree |
| `CAPABILITY_DENIED` | App lacks a requested optional capability |
| `TIMEOUT`, `CANCELLED`, `INVALIDATED` | Call deadline, abort, or page lifecycle ended it |
| `PROTOCOL_MISMATCH`, `LIMIT_EXCEEDED` | Incompatible bridge or bounded resource limit |
| `UNKNOWN_TOPIC` | Frontend attempted to subscribe to an undeclared topic |
| `PublishError.invalid_payload`, `.window_not_found`, `.queue_full` | Cyna event publication failed validation, target lookup or queue capacity |

## v1 gate

The v1 API is ready when a second app can create two windows, define and
update a native menu, activate a view shortcut context, show a context menu,
call Cyna functions from Weiv with generated types, and close or reload one
window without affecting the other. Generated event types, subscribe and
unsubscribe, sequence gaps, queue overflow, and page invalidation must pass
focused tests. Menu clicks and shortcuts must resolve to
the same action; disabled state and focus precedence must be tested in the
packaged app. Ordinary apps must link no renderer framework, and the public
Cyna and TypeScript APIs must contain no AppKit or WebKit types.
