# Ceiv macOS app framework

Ceiv hosts a Cyna app in an ordinary macOS window with a bundled Weiv page.
The reusable host owns AppKit, WKWebView, windows, the private asset scheme, and
the command bridge. App code supplies a manifest, Cyna exports, and a Weiv
page. The ordinary app links no video or renderer module.
The video proof in `examples/proof` uses the same host with an optional private
AVFoundation plugin. `examples/metal` uses an optional Metal color provider
through the emerging public `SurfaceId` API; the full M2 lifecycle gate is open.
[Native slot foundation](docs/native-slots.md) describes the shared placement
and lifecycle boundary now used by that plugin.

## Requirements

macOS with Xcode Command Line Tools, Cyna 0.4.1, Node 22, and the `weivjs` dependency supplied by the npm package. This repository was
verified against Weiv commit `05c5024`.

## Start an app

```sh
node bin/ceiv.mjs new ../my-app --id dev.example.my-app
node bin/ceiv.mjs check ../my-app
node bin/ceiv.mjs run ../my-app
```

To build the optional Metal sample, run `node bin/ceiv.mjs build examples/metal`.
Its manifest selects `CynaColorPlugin`; an ordinary app leaves `nativePlugin`
unset and does not link Metal.
`examples/provider` shows an app supplied native view: its manifest names the
plugin class and source file, and its Cyna code uses a `SurfaceId` for cleanup.
Each [example](examples/README.md) is structured as a standalone app project.

`build` assembles the `.app` without opening it. `run` builds and opens a new
instance. `check` validates the manifest, generated bindings, and Cyna source.
`package` builds a ZIP. For a signed Developer ID release, run
`ceiv package <directory> --sign "Developer ID Application: ..."`.
Add `--notarize-profile <keychain-profile>` to submit the signed ZIP with
`notarytool`, staple the ticket to the app, validate it, and recreate the ZIP.
The profile must already be configured with Apple's tools. `--sign -` makes an
ad hoc signed local test package; it cannot be notarized. The unsigned and ad
hoc paths are development artifacts, not validated release builds.
The CLI is also exposed as the `ceiv` binary when this package is installed
or linked with npm. [The public API](docs/api.md) describes its commands and
the Cyna and TypeScript interfaces. The existing shell scripts remain available
for the original proof and internal checks.

[Where app code belongs](docs/app-architecture.md) gives the default split:
Weiv/TypeScript owns the page and short lived view state; Cyna owns app
operations and native resources. Generated commands connect them.

For a build from clean source copies with focused checks, run:

```sh
sh scripts/m1-check.sh
```

Set `KEEP_M1_OUTPUT=1` to retain the temporary bundles for a packaged UI
smoke check. Generated files are checked with:

```sh
node scripts/generate-commands.mjs --check examples/proof
node scripts/generate-commands.mjs --check examples/hello
```

## App files

`ceiv new` creates the app files. Edit:

- `app.json`: unique reverse-domain `id`, display `name`, `entry`, and
  requested `capabilities`. The build also copies declared resources.
- `cyna.toml` and `src/lib.cy`: Cyna static library and its exported C ABI
  functions. Each `export c("symbol") fn` becomes a generated TypeScript
  function. No AppKit or WebKit type is needed in Cyna code.
  The `ceiv_app_configure` startup export calls `configure_window(title,
  width, height)` to set the initial window before launch.
- `web/App.weiv`: page and calls to app exports in
  `web/generated/commands.ts`, with framework APIs in `ceiv/sdk`.
  The build generates matching `.d.ts` files for app commands and events.
  Framework declarations come from the npm package.

Then run `node bin/ceiv.mjs build /absolute/path/to/new-app`. The CLI validates the
manifest, generates bindings, compiles Weiv and Cyna, links the Mac host, and
assembles the `.app`. It does not require edits to host source. The second app
uses different identity, title, assets, and commands from the video proof.

## Command schema and Cyna ABI

The Cyna exports under `src` are the source of truth for commands. The build
derives a TypeScript function name from each Cyna function name, maps `c_int`
to `number`, `c_double` to `number`, and `c_str` to `string`, and generates both
the client and native dispatcher. For example, `double_value(value: c_int):
c_int` becomes `doubleValue(value: number): Promise<number>`. Rebuilding after
an export signature change updates the generated client. The current scanner
requires the `export c("symbol") fn` signature on one line; other export
spellings and unsupported ABI types fail the build. A
`// @ceiv {"name":"math.double"}` comment immediately
before an export can set a stable wire name; `binding` can override the generated
TypeScript name.

Optional `@ceiv` argument and return descriptors supply semantics that a C
signature cannot encode, such as a boolean carried in `c_int`, JSON records
carried in `c_str`, or a caller-owned output buffer. Descriptors support `int32`
with optional `min`/`max`, finite `number`
with bounds, `boolean`, UTF-8 `string` with required `maxBytes`, `array` with
`items` and `maxItems`, `record` with named `fields`, and `optional` with
`value`. Nested descriptors are limited to eight levels. Records reject
unknown fields; optional fields may be omitted or `null`. The bridge envelope
is limited to 64 KiB. The generated TypeScript client and native adapter both
validate values.

The adapter passes `int32` and `boolean` as C `int`, `number` as C `double`,
`string` as a borrowed UTF-8 C string, and composite arguments as borrowed JSON
text. Cyna can use `c_int`, `c_double`, and `c_str` for those parameters. A
string or composite return uses a caller-owned `char *` output buffer and an
`int` byte count; return `-1` on failure. See the exported functions in
`examples/hello/src/lib.cy`. The buffer is valid only for that call.
The public Cyna modules cover app identity, windows, menus, dialogs, events,
and text slots. [GUI API plan](docs/gui-api-plan.md) records the boundary.

Generated functions return promises. They accept an optional final
`{ signal, deadlineMs }` argument. A deadline defaults to 10 seconds and is
limited to 30 seconds. Abort or timeout settles the JavaScript promise once;
cancellation cannot roll back Cyna work that already committed. Coded errors
include `INVALID_ARGUMENT`, `INVALID_RESULT`, `UNKNOWN_COMMAND`, `TIMEOUT`,
`CANCELLED`, `INVALIDATED`, `PROTOCOL_MISMATCH`, and `LIMIT_EXCEEDED`. The app handles them as
`CynaError` with `code` and `message`.

## Windows and events

Command-N opens another independent window; Command-R reloads the focused
window. Each window has an opaque ID, a page generation, its own bridge
handler, pending requests, and event subscriptions. Reload and close reject
pending page promises. A late native reply is dropped. The app terminates when
its last window closes.

`events.subscribe("app.windows", handler)` in the generated client returns
an unsubscribe function. The event payload contains
`state` (`opened`, `reloading`, `closed`, `focused`, `blurred`, or `resized`) and
`window` (a branded numeric `WindowId`, shared with Cyna). Resize events also
carry width and height.
Events have increasing sequence numbers per subscription; duplicate or older
sequences are ignored. Events are best effort: a subscription ends on page
navigation or close, no delivery is promised after close, and the host may
drop events when its per-window queue reaches 64 in-flight evaluations. The
host permits at most 16 subscriptions and 256 pending commands per window.
Subscribe again after a reload. The hello example displays the latest event.

## Assets and security boundary

The host serves the packaged Weiv bundle at `cyna-app://local/`. The handler
rejects traversal and symlink escape, reports missing assets, and assigns MIME
types by extension. Navigation to other origins is cancelled. Bridge messages
must come from the main frame of the app origin and carry the current protocol,
window ID, and page generation. The release bundle has a restrictive content
security policy. `app.json` capabilities gate file dialogs. Broader OS permission mapping
belongs to M3.

## Original video proof

`sh build.sh` packages `examples/proof`, the counter and ten-second sample video.
The example has its own `app.json`, `package.json`, Cyna project, Weiv page,
and media asset. It declares released Ceiv versions without paths back into
this repository. Once `ceiv@0.1.0` is available in the configured npm
registry, it can be copied outside
this checkout and built with `npm install && npm run build`.
The page owns
controls and timeline state; the optional AVFoundation plugin owns the native
video layer and playback. The proof reports seek completion and decoded-frame
availability, not display scanout. See `docs/architecture.md` and
`docs/mac-feature-plan.md` for the optional surface and release plans.
