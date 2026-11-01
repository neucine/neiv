# M1 extraction status

The first ordinary app path lives in `native/app_host.{h,m}` and `app-build.sh`.
The host owns AppKit, WKWebView, window placement, the private app asset scheme,
and asynchronous command dispatch. An app supplies `app.json`, `commands.json`,
`cyna.toml`, `src/lib.cy`, and `web/App.weiv`. The Cyna public boundary is a C
symbol named in the command schema; no AppKit or WebKit type appears in Cyna.

Run `sh app-build.sh examples/hello` and then open
`examples/hello/build/CeivApp.app`. The hello app has a distinct bundle ID,
title, Weiv page, and `math.double` Cyna command. `sh build.sh` now builds the
original video/counter proof through the same host. Its AVFoundation controller
is an optional private plugin; the ordinary hello app does not link media.

The schema remains `commands.json` for this packet. The generator now accepts
an app directory and produces app-local TypeScript and Objective-C dispatch.
The host's C ABI dispatcher is internal. The generated schema now supports
bounded `int32`, finite numbers, booleans, UTF-8 strings, records, optional
values, and arrays. Scalar arguments use C ABI scalars; composite arguments use
validated JSON text. String and composite results use a caller-owned output
buffer with a returned byte count. The generated TypeScript client and native
adapter both check the schema; errors carry a code and message.

## Verification on 31 October 2026

- `sh app-build.sh examples/hello`: passed using Cyna 0.4.1, local Weiv commit
  `05c5024`, macOS 26.6.2, and the macOS 27 SDK.
- `plutil -lint examples/hello/build/CeivApp.app/Contents/Info.plist`: passed.
- `open examples/hello/build/CeivApp.app`: process started; System Events
  reported window title `Hello from Cyna`. Pressing its command button returned
  `Cyna returned 4` through the packaged bridge.
- `sh build.sh`: passed through the extracted host, including its C dispatch
  assertions. The packaged proof opened with title `Cyna hybrid framework proof`.
- The hello app opened two windows with Command-N; Command-R reloaded the focused
  window; closing that window left the other open.
- `node scripts/bridge-test.mjs examples/hello/build/web/generated/commands.js`:
  passed handshake, cancellation, invalidation, and late-reply checks.
- `node scripts/generate-commands.mjs --check .` and the same command for
  `examples/hello`: passed after generation.
- The hello app's `text.score` and `data.size` commands returned `Score: 8` and
  `Record bytes: 49` in its packaged UI. Its native dispatch test covers valid
  scalar/composite values and malformed, oversized, nonfinite, and unknown
  commands. The bridge test covers client-side validation and typed errors.

The build uses the local Weiv source CLI and needed no Weiv workaround. One
generator omission surfaced during this packet: generated Objective-C called
the Cyna symbol without an `extern` declaration. The generator now emits the
declaration. This is Ceiv integration code, not a Weiv or Cyna defect.

## M1 follow-through

F03–F08 and the packaged gate were completed after this extraction packet.
See [M1 gate evidence](m1-gate.md) for the current checks and estimate update.
