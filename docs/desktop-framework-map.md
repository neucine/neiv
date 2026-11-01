# Ceiv desktop framework map

Status: design review, 1 November 2026. P0–P3 have an initial implementation;
their evidence and remaining limits are in [P0–P3 gate](p0-p3-gate.md).
P4–P6 progress and open gates are in [P4–P6 progress](p4-p6-progress.md).
This map does not mark the broader v1 gate complete.

## Reference model

A desktop framework has three parts: an app runtime that owns native resources,
an app-facing library with stable value-based APIs, and tooling that turns source
into a distributable application. The web page is one view layer. Ordinary DOM
events and Weiv state remain there; Ceiv handles operations that require the
host or Cyna backend.

The patterns come from [Tauri's project structure](https://v2.tauri.app/start/project-structure/),
[commands](https://v2.tauri.app/develop/calling-rust/),
[events and channels](https://v2.tauri.app/develop/calling-frontend/),
[Electron's process model](https://www.electronjs.org/docs/latest/tutorial/process-model),
[IPC](https://www.electronjs.org/docs/latest/tutorial/ipc),
[menus](https://www.electronjs.org/docs/latest/tutorial/application-menu), and
[Wails' API inventory](https://v3.wails.io/reference/overview/). This is a
comparison of public concerns, not a proposal to copy another runtime.

| Concern | Typical framework responsibility | Ceiv state | Next contract |
| --- | --- | --- | --- |
| App identity and lifecycle | Identity, launch, activate, quit, reopen, close policy | Manifest identity; Cyna identity, lifecycle callback, quit; last close quits | Explicit lifecycle options and close decision |
| Windows | Create, focus, title, geometry, visibility, state, ownership | Cyna open/focus/title/close/reload; numeric ID shared with generated TS | Window options, query and state events |
| Web content | Bundled assets, navigation, isolation, process failure | Private asset scheme, navigation policy, per-window session | Recovery and controlled external URL opening |
| Commands | Typed frontend calls into backend, errors, cancellation | Generated TS from Cyna exports; host validates values and session | Better Cyna type extraction and stable error mapping |
| Notifications | Host/backend events to one page or all pages | Declared events, typed subscriptions, bounded delivery | System/window event catalog and overflow semantics |
| Actions | One intent triggered by menu, shortcut, toolbar or context menu | Cyna menu tree and state; TS scoped handlers | Complete dispatch metadata, acknowledgement, state ownership |
| Menus and dialogs | Native app/context menus; alerts and file pickers | Menu tree, context popup, dialogs; file capability check | Typed failures, cancellation and selection options |
| OS integration | Clipboard, drag/drop, notifications, tray, links, file associations | Mostly absent | Optional modules with declared capabilities |
| Persistence | Settings and app data locations | Cyna std can handle general files | Ceiv app directories and scoped file access only |
| Native content | Optional views, input, focus, accessibility and GPU/media lifecycle | Text slot and internal video placement | M2 provider contract and lifecycle gate |
| Tooling and release | Scaffold, build, dev loop, package, sign, update, diagnostics | `new/check/build/run`, packaged npm SDK | Dev loop, reproducible release, signing and update policy |

## Boundary decisions

1. **Cyna std owns general facilities.** Strings, memory, JSON, files, threads,
   HTTP and generic C interop stay in std. Ceiv supplies app directories,
   native UI, OS integration and the bridge. An OS feature is an opt-in Ceiv
   module when its permission and lifecycle belong to an app.
2. **Cyna code owns app-wide behavior.** Startup options, persistent services,
   native menu declarations and window creation live in Cyna. The Weiv page
   owns view state and focus-dependent action handlers. Public APIs carry
   values and opaque IDs; AppKit and WebKit types remain private.
3. **Use three delivery contracts.** A command has a result or typed failure.
   An event is a bounded best-effort notification, with no replay. A native
   action or close decision requires an acknowledgement and a deadline. A
   high-volume stream would need a separate channel with flow control.
4. **Separate static metadata from runtime policy.** The manifest contains
   bundle identity, resources and declared capabilities needed before app code
   runs. Cyna startup code sets window and runtime behavior. The CLI checks
   that the two agree.
5. **Keep the host modular.** Ordinary apps link the shell/web host. Media,
   renderer and optional OS integrations link only when used. This keeps the
   core small and avoids making a general Cyna program depend on a GUI SDK.

## Implementation packets

Each packet ends with a small example and an explicit gate. Finish and record
the gate before declaring that capability public.

The implementation split is consistent across packets:

| Layer | Work it owns | Constraint |
| --- | --- | --- |
| `src` | Cyna value types and app-facing calls | No AppKit/WebKit types; typed errors at the boundary |
| `native/` | AppKit/WebKit objects, main-thread state, lifetimes and permissions | Per-window ownership; validate every page message |
| `scripts/` | Export discovery, schema validation, TS and native adapter generation | One source declaration; deterministic output and drift check |
| `web/generated/` | Natural Promise calls, typed events, action contexts and disposers | No raw WebKit message API in app code |
| `bin/` | Scaffold, check, build, run and release commands | Installed SDK works outside its source checkout |

Start each packet with the developer call site, then update the relevant
backend module and host protocol together. Test host behavior through a
packaged app where focus, native menus or window ownership matter.

### P0. Correctness of the existing core

- Specify one `WindowId`: a process-scoped numeric handle in Cyna and branded
  TypeScript; keep the UUID as private session authentication. Test command,
  event and reload behavior with two windows.
- Replace the timed window close retention with ownership tied to AppKit's
  close transaction. Test repeated open/close, final-window exit and no stale
  callbacks. This is a release gate because a close crash was observed.
- Audit generated signatures, event payload validation, action state and
  context data against the packaged host. Fix the public docs when behavior
  differs. Gate: clean builds, focused tests and packaged two-window UI pass.

### P1. Lifecycle and window model

- Define `AppOptions` for last-window behavior and reopen activation. Define
  `WindowOptions` with title, size, minimum size and initial visibility.
- Add `window.get_state(id)` and `window.set_bounds(id, ...)` with typed errors.
  Publish focus, resize and closed state after native state changes.
- Add a close request callback with a bounded decision (`allow` or `cancel`).
  It must cover menu, title-bar and programmatic close with exactly one
  decision and a defined timeout outcome. Gate: unsaved document example and
  repeated close/quit matrix.

### P2. Actions, menu and shortcuts

- Keep one `ActionId` for menu, shortcut and context menu. Define dispatch
  payload `{ id, source, window, data }`; acknowledge success or typed failure.
- Make action ownership explicit: backend actions for app services, frontend
  actions for focused view state. Resolve focused view, window, then app.
  Disabled winners stay disabled. Menu state and dispatch must use the same
  selected handler.
- Validate shortcut conflicts at registration and use platform roles for
  standard editing. Gate: packaged app tests click, shortcut, focus switch,
  disabled state, context data and timeout.

### P3. Commands and events

- Treat Cyna exports and event declarations as the source of generated TS
  bindings. Derive types from signatures where possible; annotations specify
  only ABI information the signature cannot express. Regeneration follows an
  export change and `check` detects drift.
- Publish typed built-in app/window events and declared custom events. Define
  target window, app broadcast, subscription ownership, ordering, invalidation
  and saturation return. Gate: malformed payload, sequence gap, queue full,
  navigation and close cases.

### P4. Native services

- Add `shell.open_external` with URL scheme policy; clipboard read/write;
  notification and tray APIs as opt-in modules. Add file dialog filters and
  multi-selection where needed. Keep general file I/O in Cyna std.
- Every service declares capability, thread and ownership rules, cancellation
  behavior, and typed errors. Gate: one small app flow per service, including
  denial and window-close cases.

### P5. Optional native content

- Define `SurfaceId`, provider registration, attach/detach/destroy, visibility,
  scale, input, focus and accessibility. Avoid public `NSView` or `WKWebView`.
- Gate against the M2 rendering matrix in [mac-feature-plan.md](mac-feature-plan.md).
  The ordinary app must continue linking no media or renderer framework.

### P6. Developer and release experience

- Add a fast development loop with diagnostics that identify the Cyna export,
  generated binding or Weiv source at fault. Keep clean `check/build/run`.
- Define bundle metadata, icons, signing, notarization, clean install and
  update policy as release work. Gate on a representative app on another Mac.

## API refinement checklist

For each API, write one normal call site in Cyna or generated TypeScript, then
specify: who owns the resource, when the call is legal, return and error types,
thread or async behavior, cancellation, permission, native event consequences,
cleanup, and the packaged acceptance case. The API is ready when the call site
is natural and the host enforces the contract without app-authored bridge code.
