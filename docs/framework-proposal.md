# Ceiv: architecture proposal

Status: review draft, 31 October 2026. This is a target contract, not a claim that the proof already implements it.

**Project name:** Ceiv. It denotes the Cyna desktop application framework, including its ordinary webview path and optional native rendering modules.

## Decision and scope

The target is a general Cyna framework for desktop GUI applications. Cyna owns the application, windows, lifecycle, services, and OS integration. The default window hosts a web UI; ordinary apps need no native rendering code. JavaScript may own UI and application state, and Weiv is the default compiler for that web frontend. Apps opt into native, GPU accelerated surfaces for video, visualization, games, or other demanding regions. A native-only window is a supported mode for apps that need it, using the same optional surface system. The host consumes static web assets and does not depend on a particular JavaScript component runtime.

macOS is the first implementation and release target. The application, window, bridge, capability, and rendering contracts keep platform-specific types behind adapters so Windows and Linux can be added later. Portability is an architectural constraint, not a promise of current feature parity or simultaneous delivery. Generated command bindings serve windows with a webview. Native rendering and GPU acceleration are optional, first-class capabilities with explicit backend negotiation; ordinary webview apps do not initialize a graphics backend or carry its optional modules. The framework does not promise identical system controls, transparent native views under arbitrary HTML, frame accurate web/native compositing, a cross-platform media engine, or automatic persistence of JavaScript state. Mobile and embedded targets are outside this proposal.

## Evidence and constraints

The proof builds a Weiv 0.1.2 page from local commit `05c5024`, packages it under `cyna-app://local`, and hosts it in `WKWebView`. `commands.json` generates a TypeScript client and Objective-C dispatcher for bounded `int32` values. Cyna commit `d619ac05` supports explicit `export c fn` and C-layout adapters; the proof links a Cyna static library into an Objective-C host. An `AVPlayerLayer` sits in a sibling view above the webview. Playback anchors reach the page about once per second, and the page advances its indicator locally. The measured decoded-buffer and animation-frame callbacks do not identify display scanout or audio alignment. The proof has no Windows or Linux host.

The prototype therefore validates one webview and native video composition path, not the framework's full GUI model, native-only windows, general GPU drawing, protocol type system, security policy, compositor behavior, or latency guarantees. Existing `docs/architecture.md` remains the proof's narrower contract.

## Related frameworks and design lessons

Tauri uses a Rust core with window and webview layers, commands, and a capability system that limits frontend access. Wails uses a Go application core, system webviews, generated JavaScript bindings, and application events. These are useful precedents for webview hosting, command generation, and permission boundaries. Their documented architectures do not establish the native rendering and GPU surface contract required here. The Cyna framework should adopt proven host patterns while treating native-only and hybrid rendering as explicit product requirements, rather than deriving its architecture from the macOS video proof.

Sources reviewed: [Tauri architecture](https://tauri.app/concept/architecture/), [Tauri capabilities](https://tauri.app/security/capabilities/), [Wails architecture](https://wails.io/concepts/architecture/), and [Wails events](https://wails.io/reference/events/).

The Mac-first host reuse choice and planning ranges are in [mac-host-reuse-assessment.md](mac-host-reuse-assessment.md).

## Runtime layout

```text
Cyna application ── app/window/event loop ── OS capability adapters
        │                    │
        │                    ├─ native UI and render surfaces ── graphics backend
        │                    └─ optional webview ── Weiv/JS bundle
        │                                            │ generated typed client
        └─ typed services ◀──── per-window bridge ───┘
```

The application runtime owns windows, event dispatch, render scheduling, command scheduling, permission checks, and teardown. The web bridge is present only when a window contains a webview. Platform adapters implement native windows, webviews, dialogs, files, notifications, clipboard, input, accessibility, and graphics surfaces behind stable host interfaces. Capability availability is queried at runtime and declared in the package manifest. Public Cyna handles represent windows, surfaces, and resources; platform objects remain inside adapters.

## Core API and lifecycle

The first public API should be a small manifest plus generated bindings:

```text
app: id, display_name, version, capabilities
window: id, content_mode, title, initial_size, minimum_size, restore_policy
webview: entry, command_schema (when content_mode includes web)
surface: kind, backend_preference, presentation_mode, capability requirements
```

These names describe a proposed schema, not current Cyna syntax. The runtime starts Cyna app services, creates windows, initializes each window's content and renderer, then emits ready. A webview window installs its bridge before loading bundled assets and completes a protocol handshake before accepting web commands. Native-only windows have no page handshake. `window.suspend` and `window.resume` signal visibility and system sleep changes; services must tolerate repeated signals. `window.closeRequested` reaches Cyna first, with an optional bounded page veto for unsaved web state. The runtime then cancels in-flight operations, detaches surfaces, revokes window-scoped grants, destroys content, and releases the window. Process shutdown waits for bounded Cyna cleanup.

For webview windows, navigation creates a new page generation. The runtime rejects old messages and settles or cancels pending calls. Each window has its own request IDs, event subscriptions, and capability grants. App-wide Cyna services may be shared, but their mutable state must define serialization explicitly. Platform callbacks enter Cyna through generated C ABI functions or a small hand-written adapter; this avoids promising an unsupported direct Cyna/Objective-C or Cyna/webview object ABI.

## Native UI and GPU rendering contract

A native-only window exposes input events, focus, accessibility, layout, invalidation, and a render target. This mode is optional. The framework should provide a small native UI foundation for controls, text, images, menus, and accessibility, plus custom drawing surfaces for applications that need their own renderer. A design gate must choose whether this UI foundation wraps platform widgets, uses a framework renderer, or supports both; the choice needs prototypes for text input, IME, accessibility, and high-DPI behavior on all three desktop platforms. The webview path remains a complete choice for ordinary app UI.

A render surface has explicit creation, resize, frame request, render, present, suspend, device-loss, and destroy transitions. Apps negotiate a backend and features, such as texture formats, compute, HDR, shared textures, and presentation timing. The portable base supports a drawable, command submission, texture and buffer resources, synchronization, and a fallback path. Backend adapters can use Metal on macOS, Direct3D on Windows, and Vulkan or another proven Linux backend. Backend-specific extensions expose advanced features without pretending every GPU has identical behavior. Ownership rules cover GPU resource lifetime, thread affinity, resize, display migration, and device loss. Rendering work must not block the UI event loop.

Native surfaces may fill a window or occupy a region beside other native content. A hybrid web/native window additionally uses a webview slot, with the composition limits described below. Both native-only and hybrid windows use the same surface lifecycle and rendering API; slot placement is an additional hybrid concern. A software renderer is a capability fallback for basic drawing, not an implicit substitute for an app that requires GPU features.

## Web commands and events

The source schema defines named commands, argument and result types, size limits, concurrency policy, capability requirement, cancellation behavior, and version. A generator emits TypeScript declarations/client, host validators/dispatch tables, and C ABI declarations checked against exported Cyna symbols. Initial portable values are null, boolean, bounded integers, finite floating point numbers, UTF-8 strings, byte buffers, arrays, records, and tagged variants. File handles, surface IDs, and subscriptions are opaque host-issued tokens, never raw paths or pointers. Generator output is deterministic and checked in CI.

Every transport envelope carries `protocol`, `window`, `generation`, `id`, and `kind`. A command request adds `command`, `args`, and optional `deadlineMs`; a terminal reply has exactly one of `value` or a structured error `{code, message, details?}`. IDs are unique within a page generation. The host validates envelope shape and payload bounds before dispatch. Timeouts and cancellation settle the JavaScript promise once; cancellation is cooperative for Cyna work and may arrive after an operation has already committed. Commands that mutate shared state declare a serial lane or version precondition. The host does not assume concurrent commands finish in request order.

Events have `topic`, `subscriptionId`, monotonically increasing `sequence` per subscription, and payload. A subscription can provide an initial snapshot plus revision so the page can reconnect without treating missed events as current state. The broker bounds queues; high-rate telemetry is coalesced, while state transitions and terminal operation results are retained until acknowledged or the generation ends. No event delivery is promised after close. The generated client exposes `invoke`, `subscribe`, `unsubscribe`, and an `AbortSignal` option; app code uses named generated functions. Protocol negotiation rejects incompatible major versions and reports an actionable package error.

## State ownership

The app declares one authority for each domain. Ephemeral controls, routing, selection, and optimistic UI normally live in JavaScript. Cyna owns state that must survive page reloads, spans windows, controls privileged resources, or must be transactionally consistent. A command returns a revision with any durable mutation; events carry that revision. JavaScript may mirror native state but reconciles by revision, not arrival time. For a JS-owned domain, native commands act on explicit inputs and return results; the host does not duplicate a hidden store. Persistence is an opt-in Cyna service with an app-defined schema and migration policy.

## Hybrid surface composition and timing

A page reserves a rectangular slot and registers its `slot_id`. After layout, it reports a viewport rectangle and visibility; the host validates finite coordinates, clips to the webview, applies device scale, and attaches a native sibling view. Resize, scroll, zoom, display changes, and navigation update or remove it. The slot is opaque; HTML content cannot overlay it reliably, and arbitrary CSS clipping or transforms are unsupported. The framework must document z-order, input ownership, focus, accessibility node linkage, hit testing, and capture behavior. A surface is optional per window and can fail independently with a typed capability error.

The surface controller receives typed operations and publishes state or timing events. For video, the platform media engine owns decode, audio clock, and frame presentation. A playback anchor includes `mediaTime`, `nativeMonotonicTime`, `rate`, `playbackRevision`, and `seekId`. The web client maps native time to its own monotonic clock using a sampled offset and uncertainty; it advances indicators locally and corrects drift on anchors. During scrub or pending seek, the UI's target is authoritative; stale revisions cannot move it backward. Event names distinguish command accepted, seek completed, decoded frame available, submitted for presentation, and displayed frame when the backend can actually observe it. A decoded frame or GPU command completion must never be labeled displayed. Audio/video sync metrics require backend-specific clock evidence and a stated uncertainty. If a backend cannot expose a boundary, it reports the capability as unavailable.

The generic hybrid API handles attach, detach, bounds, input, and lifecycle using the native render surface contract. Media playback and its clocks are optional modules. No pixel buffer crosses the web command bridge by default. Large data uses a bounded native resource handle or an explicit shared-memory extension with lifetime rules.

## Platform adapters

| Platform | Window and webview | Initial surface path | Packaging |
| --- | --- | --- | --- |
| macOS | AppKit + WKWebView | sibling NSView; AVFoundation or Metal module | `.app`, signed and notarized release |
| Windows | Win32 window + WebView2 | child/composition visual; Media Foundation or Direct3D module | installer or MSIX; WebView2 runtime policy |
| Linux | GTK window + WebKitGTK | GTK/native child or compositor-specific module | distro package or portable bundle with explicit WebKitGTK dependency |

The macOS adapter is the first deliverable. Windows and Linux entries are implementation candidates, not verified parity or near-term release commitments. Platform interfaces must be narrow enough to implement macOS features without forcing lowest-common-denominator behavior, while keeping OS objects out of public Cyna APIs. A later adapter must pass the common bridge, lifecycle, and surface geometry conformance tests for every capability it claims. Linux native surface composition must be proven on both X11 and Wayland before calling the surface feature portable; if one compositor cannot provide the needed overlap and timing behavior, mark that capability unavailable. The framework chooses the adapter at build time and reports runtime capability versions.

## Security and resource policy

Only packaged, integrity-checked assets load as the app origin. The URL handler canonicalizes paths, rejects traversal and symlink escape, serves correct MIME types, and applies a restrictive content security policy. Remote navigation and subframes have no bridge access by default. The broker verifies origin, main frame, window, generation, and protocol on every message; a scheme name alone is insufficient authority. Development mode may use a local server only with an explicit separate trust policy and a visible development indicator.

The manifest lists requested OS capabilities. The host grants them per window or app scope and prompts through the platform when required. Commands enforce their declared capability independent of client-side typing. File access uses scoped handles with explicit expiry. Inputs have depth, byte, collection, and rate limits; results and event queues are bounded. Logs redact paths, user data, and payloads unless app code explicitly opts into diagnostic fields. Native crashes and web content crashes are contained where platform processes permit, and page reload invalidates all old handles.

## Build and distribution

The build pipeline validates the manifest and schema, generates bridge code, compiles Weiv static assets for web windows, builds the Cyna library, compiles the platform host and selected optional modules, then assembles and signs a platform package. An ordinary webview app does not link a GPU renderer or media module. A development command launches the same host with diagnostics and rebuilds assets; release builds embed immutable assets and a protocol/schema hash. The artifact records Cyna compiler revision, Weiv version or commit when used, host adapter version, target ABI, and dependency/runtime requirements. Windows and Linux installers remain platform-specific, but app source and command schema remain shared. CI checks generated files for drift and runs each target's packaging smoke test.

## Verification and staged implementation

1. **General contract and Mac foundation.** Define app, window, lifecycle, capability, and module APIs independently of the proof. Build a minimal Cyna app with a normal macOS webview window and typed command. Review the API against Tauri and Wails patterns and Cyna's supported ABI. Keep AppKit and WebKit types inside the macOS adapter.
2. **Usable macOS webview framework.** Complete static asset loading, generated bridge bindings, packaging, multiwindow behavior, permissions, lifecycle, and development workflow on macOS. Gate this milestone on real packaged launch and bridge/lifecycle conformance. An ordinary app needs no native renderer.
3. **Optional Mac rendering.** Define rendering lifecycle, backend negotiation, GPU resources, scheduling, device loss, and software fallback. Prove a native-only window and Metal drawing surface, then attach that surface to a webview slot. Test resize, display migration, input, focus, accessibility, and teardown. Add AVFoundation as an optional media module.
4. **Mac release evidence.** Measure presentation boundaries where supported, audio clock drift, dropped/late frames, seek distributions, and load on target media and hardware. Complete signing, notarization, crash recovery, and packaging tests before a stable macOS release claim.
5. **Later platform adapters.** Implement Windows and Linux against the established contracts, first for ordinary webview windows and then optional rendering and hybrid composition. Require real launch and conformance tests on each OS. Publish capability matrices, including X11 and Wayland composition behavior, instead of assuming Mac results transfer.

Review gates are an app API review after stage 1, macOS host review after stage 2, graphics and composition review after stage 3, and platform adapter review when stage 5 begins. The prototype's 20-seek samples are useful regression observations but do not set a framework latency budget.

## Open design decisions

- Whether command definitions remain JSON or use a Cyna declaration source with generated schema. Stage 1 should retain JSON, then compare ergonomics and ABI verification before changing the source of truth.
- Whether shared-memory transfer belongs in the core. Keep it an extension until a cross-platform ownership and cleanup contract is tested.
- Which Linux compositor/backends can satisfy native surface placement and timing. Ordinary windows proceed independently.
- Whether close veto is needed for every window or only windows that declare unsaved-work handling; either path needs a bounded host deadline.
