# Ceiv: macOS host reuse assessment

31 October 2026. Scope: a reusable Cyna desktop app framework with an ordinary Weiv webview path and optional native/GPU surfaces. This is a source and API assessment, not an integration benchmark.

## Recommendation

Use the existing AppKit/WKWebView proof as the macOS host starting point. Extract a small C ABI boundary into Cyna, a reusable window and bridge layer, and an optional surface module. Use Tauri and Wails as references for lifecycle, generated bindings, capability scope, and packaging. Keep the public Cyna API free of AppKit types so another platform adapter remains possible.

Do not introduce a Rust or Go runtime solely to host the Mac webview. That would require another C ABI shim and runtime ownership model even though the proof already demonstrates the needed WKWebView, custom asset scheme, bridge, and sibling AVPlayerLayer. Reassess Wry/Tao when Windows/Linux implementation begins or if the Mac host grows substantially beyond the current scope.

## Options checked

| Host choice | Reusable parts | Cyna integration | Mac surface fit | Assessment |
| --- | --- | --- | --- | --- |
| Existing AppKit/WKWebView proof | Working asset scheme, JS message bridge, packaged `.app`, native sibling view | Already links Cyna static library through `export c fn` | Direct access to NSView, AVFoundation, and Metal | **Preferred for Mac first.** Extract and test reusable boundaries. |
| Tauri full framework | Mature app/window lifecycle, permissions, commands, packaging | Rust app owns runtime; Cyna needs a Rust/C shim and service lifecycle translation | Possible through platform access or plugin, but adds a Rust host layer | Useful design reference; reuse cost is high for this Mac proof. |
| Wry + Tao | Cross-platform webview and window/event-loop libraries, child webview, IPC, custom protocol | Rust/C shim required; Cyna would drive or be driven by Rust event loop | Wry exposes macOS WKWebView access; native composition still needs adapter code | Revisit for later cross-platform host. |
| `webview/webview` | Small C/C++ library, C API for window, navigation, JS binding, dispatch | Direct C ABI is attractive | Native window handle exists, but richer composition and host policy need Mac-specific extension | Good minimal-webview experiment; not clearly less work than the current proof. |
| Wails | Go webview host, generated bindings, events, packaging | Go runtime and cgo/C bridge needed; service ownership translated to Cyna | Mac-specific composition would still need Go/ObjC work | Design reference, not a direct Cyna host dependency. |

Tauri's architecture identifies Tao as its window layer and Wry as its webview layer. Wry documents child webviews, custom protocols, IPC handlers, permission hooks, and macOS WKWebView access. `webview/webview` documents a C API with `webview_bind`, `webview_return`, and native-window handles. Its public C API does not show the custom-scheme and navigation policy hooks already used by the proof, so adopting it would require an experiment or Mac extension before it could replace the host. These are API observations; no candidate was built into the Cyna proof.

Sources: [Tauri architecture](https://tauri.app/concept/architecture/), [Tauri capabilities](https://tauri.app/security/capabilities/), [Wry API](https://docs.rs/wry/latest/wry/struct.WebViewBuilder.html), [Wry macOS access](https://docs.rs/wry/latest/src/wry/lib.rs.html), [Tao repository](https://github.com/tauri-apps/tao), [webview C API](https://github.com/webview/webview/blob/master/core/include/webview/api.h), [Wails architecture](https://wails.io/concepts/architecture/).

## Effort with this reuse choice

Estimate for one engineer familiar with Cyna and macOS, assuming the existing proof remains the base and Weiv supplies the web UI:

| Deliverable | Focused effort | Completion evidence |
| --- | ---: | --- |
| Reusable Mac webview framework | 2–4 weeks | Second app builds without editing host internals; typed commands, lifecycle, asset loading, and `.app` packaging work. |
| Optional native surface API | 2–4 additional weeks | A simple Metal surface and the existing video surface attach, resize, detach, and survive navigation/close. |
| Release hardening | 2–5 additional weeks | Signed/notarized app, permissions and failure tests, multiwindow behavior, and clean installation on another Mac. |

These are planning ranges, not measured velocity. The first range excludes broad GPU resource abstractions, a native widget toolkit, and Windows/Linux implementation. The surface range covers a useful Mac interface, not a portable high-level graphics engine. A general resource API with device loss, synchronization, and multiple backends should be estimated only after a narrow Metal API prototype establishes what Cyna can express cleanly.

The feature breakdown and acceptance gates are in [mac-feature-plan.md](mac-feature-plan.md).

## Short validation spike

Before committing to the host choice for a wider release, spend 2–3 engineering days extracting the proof into a tiny host library and building a second Cyna app. Require: independent app identity/assets, generated command signatures, a clean close and reload, a native surface attached through an app-facing API, and no changes to host source for app-specific commands. Record actual build time and integration friction. If this fails because AppKit glue is consuming the schedule, build the same small app with `webview/webview` or Wry/Tao and compare code and packaging cost. The result should replace the planning ranges above with measured effort.
