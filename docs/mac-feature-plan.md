# Ceiv: macOS feature plan

Status: M1 gate passed on 31 October 2026; see [M1 gate evidence](m1-gate.md). One engineer familiar with Cyna and AppKit. Estimates are focused engineering days; a day is about eight hours. Ranges include focused tests and documentation, but not waiting for Apple account access, certificates, or external review. The AppKit/WKWebView proof is the implementation base. [Architecture](framework-proposal.md) and [host reuse assessment](mac-host-reuse-assessment.md) define the wider context.

## Delivery boundaries

**M1: ordinary GUI apps (10–20 days, about 2–4 weeks).** A second Cyna app can supply identity, static Weiv assets, typed commands, and app configuration without editing framework internals. It builds and launches as a `.app`; no renderer or media module is linked.

**M2: optional native rendering (10–20 additional days, about 2–4 weeks).** An app can create a Metal surface or AVFoundation video surface in a webview slot, or use a full-window native surface. It can attach, resize, suspend, and destroy surfaces safely. The framework does not yet promise a broad graphics engine or frame-perfect HTML/native composition.

**M3: Mac release hardening (10–25 additional days, about 2–5 weeks).** A representative app passes multiwindow, permission, error, accessibility, packaging, signing, and clean-install checks. This milestone can be scoped to one distribution channel and the capabilities actually used by that app.

The ranges are milestone envelopes, not the sum of independent worst cases. Several items share implementation and tests. Review after each gate and re-estimate from observed work.

## M1: ordinary app framework

| ID | Feature and concrete work | Acceptance check | Depends on | Days |
| --- | --- | --- | --- | ---: |
| F01 | Define app-facing Cyna package and manifest: app ID/name, entry asset, window options, command schema, requested capabilities. Keep ObjC objects private. | Two apps express different IDs, titles, assets, and commands through configuration alone. | Proof | 1–2 |
| F02 | Extract `AppHost` into reusable Mac runtime: app launch, main-thread event loop, window creation, close, and cleanup. Separate example video and counter logic. | Counter proof still launches; a minimal second app launches from the same host library. | F01 | 2–3 |
| F03 | Make window and webview instances independent: IDs, page generations, per-window bridge handlers, asset roots, and navigation policy. | Open two windows; reload or close one without affecting pending calls or the other window. | F02 | 1–2 |
| F04 | Expand generated command schema beyond `int32`: bounded strings, booleans, finite numbers, records, optional values, arrays, and typed errors as needed by a second app. Validate on both sides. | Generated TS client and C ABI adapter agree; malformed, oversized, and unknown commands return structured errors. | F01–F02 | 2–4 |
| F05 | Add bridge lifecycle: handshake/version, request IDs, deadlines, cancellation, navigation invalidation, reply settlement, and bounded event subscriptions. | No unresolved JS promise after close/reload; late native reply is dropped; ordering is documented and tested. | F03–F04 | 2–3 |
| F06 | Make bundled asset service safe and reusable: canonical path handling, MIME map, missing asset response, main-frame origin check, remote navigation policy, release CSP. | Static Weiv bundle loads from `.app`; traversal, subframe bridge use, and unwanted remote navigation are rejected. | F02 | 1–2 |
| F07 | Provide `cyna app build/run` wrapper or repository CLI script: generate bindings, compile Weiv, build Cyna, link host, assemble Info.plist and resources. | One command builds each sample app from a clean checkout; generated files have a drift check. | F01–F06 | 1–2 |
| F08 | Document a small sample app and API: command, event, window lifecycle, error handling, packaging; add a second non-video example. | A developer can follow README to create and run the second app without editing host source. | F07 | 1–2 |

**M1 gate:** build and launch both apps from clean outputs; run a focused command/bridge test and a packaged UI smoke test. A reviewer checks the public API and verifies no AppKit/WebKit types leak into it. If F04 exposes a Cyna compiler or ABI limit, record a minimal reproduction in Cyna's `docs/LANGUAGE_GAPS.md` and use a narrow C-layout adapter.

## M2: optional rendering

| ID | Feature and concrete work | Acceptance check | Depends on | Days |
| --- | --- | --- | --- | ---: |
| R01 | Define opt-in surface API: create, attach, set bounds, visibility, suspend, resume, destroy; opaque IDs and window ownership. | An ordinary app links no surface module; attaching to the wrong/closed window fails predictably. | M1 | 1–2 |
| R02 | Implement Mac view composition: sibling native view, device scale, clipping to webview, resize/scroll/zoom updates, display migration. | A moving web slot tracks the native surface without stale views after navigation or close. | R01 | 2–4 |
| R03 | Implement a narrow Metal surface: device and layer setup, drawable resize, frame request, render callback or command submission, presentation, resource cleanup. | Color/geometry demo renders under resize and sleep/wake; app can request redraw without blocking UI input. | R01 | 2–4 |
| R04 | Define backend and capability report: Metal availability, pixel format, scale, timing support, optional software fallback; document unsupported features. | App receives explicit capability result and can choose a web-only path when Metal is unavailable. | R03 | 1–2 |
| R05 | Adapt AVPlayerLayer proof as optional media surface with play/pause/seek, revisions and bounded playback anchors. Keep decode and audio native. | Video example uses framework surface API; web timeline rejects stale seeks and survives surface teardown. | R01–R02 | 1–3 |
| R06 | Specify input, focus, accessibility, and z-order for native slots; route pointer/keyboard ownership and expose an accessibility label/role. | Keyboard focus can move between web controls and surface; pointer hit test and VoiceOver inspection match documented behavior. | R02–R05 | 1–3 |
| R07 | Measure and label timing boundaries: accepted command, seek completion, decoded frame ready, GPU submission/completion, displayed frame only if observable. | Diagnostic UI and logs never call a decoded buffer or command completion a scanout; unknown metrics report unavailable. | R03–R05 | 1–2 |

**M2 gate:** one standalone Metal sample and the video example build with the optional module; M1's plain app still builds without it. Exercise repeated attach/detach, navigation, close, sleep/wake, scale change, and device removal where reproducible. Record CPU/GPU usage and seek samples as observations rather than guarantees. Broad texture, compute, and shared-memory APIs are separate decisions after this gate.

## M3: release hardening

| ID | Feature and concrete work | Acceptance check | Depends on | Days |
| --- | --- | --- | --- | ---: |
| H01 | Capability policy and system permission mapping for the capabilities used by the sample; deny undeclared commands and make grants window scoped where appropriate. | A hostile page payload cannot invoke an undeclared command; permission rejection is typed and visible. | M1 | 2–4 |
| H02 | Failure paths: web content process termination, asset failure, native command failure, cancellation/timeout, renderer failure, and crash diagnostics. | App recovers or exits cleanly; pending work settles; diagnostic log identifies the failure without payload leakage. | M1–M2 | 2–4 |
| H03 | Multiwindow and lifecycle matrix: reopen, last-window close, unsaved-work veto deadline, background/foreground, sleep/wake, app termination. | Automated host checks plus manual UI passes; no window or handler leaks across repeated cycles. | M1 | 2–4 |
| H04 | Accessibility and input pass for web and optional native surfaces: VoiceOver, keyboard, focus return, scaling, reduced motion. | Representative workflows are usable without pointer input; known surface limitations are documented. | M1–M2 | 2–4 |
| H05 | Distribution build: reproducible release package, icon/metadata, entitlements, signing, notarization, stapling, architecture targets, dependency record. | Install and launch on a clean supported Mac; signature and notarization checks pass. | M1 | 2–5 |
| H06 | CI and release fixtures: unit/bridge tests, packaged launch, generated-code check, sample app builds, versioned release checklist. | CI builds both samples and catches a broken schema, asset bundle, or host link. | M1–H05 | 2–4 |

**M3 gate:** release candidate installed on another Mac, with its declared capabilities tested. Fix only issues found by these gates before widening scope. Additional OS APIs, automatic updates, a full native widget set, and a cross-platform GPU abstraction require their own feature plans.

## Dependency path and first packet

`F01 → F02 → F03/F04/F06 → F05 → F07 → F08` is the M1 critical path. R01 starts after the host/window ownership model stabilizes; R02/R03 can then proceed independently, followed by R05/R06/R07. H01–H06 can begin after the relevant M1 feature, but M3 acceptance follows M2 only for apps shipping surfaces.

The first implementation packet is **F01 + F02**: extract a host library and launch a second app with different ID/assets and a trivial typed command. This is the 2–3 day validation spike from the reuse assessment. Capture actual time, Cyna compiler/ABI friction, and host source edits; update all milestone estimates at its gate.

## Decisions to settle at gates

- **M1:** Cyna exports are the command source of truth; the build generates TypeScript clients and the native adapter. Protocol version policy, app versus window scoped Cyna services, and whether unsaved close veto belongs in the core remain design decisions.
- **M2:** callback versus command encoder exposure for Metal, software fallback scope, and whether the native-only sample graduates from an experimental mode to a supported first release API.
- **M3:** supported macOS versions and CPU architectures, distribution channel, entitlement set, and whether notarization is part of the first release.
