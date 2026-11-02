# Ceiv app SDK API

Ceiv is a separate SDK for Cyna desktop apps. The `ceiv` CLI owns app
creation, binding generation, building, and launching. The generated TypeScript
module is the page's native command API. The Cyna package supplies app, window, menu, dialog, event, and slot modules. See [GUI API plan](gui-api-plan.md).

See [v1 API design](v1-api.md) for menu and event semantics.
For a new app, start with [where app code belongs](app-architecture.md).

## CLI

Run `node /path/to/ceiv/packages/ceiv/bin/ceiv.mjs` or use the `ceiv` binary when the
package is installed or linked. Commands accept an app directory; `build`,
`run`, and `check` default to the current directory.

| Command | Behavior |
| --- | --- |
| `new <directory> [--id dev.example.app]` | Create a Cyna static library, Weiv page, app manifest, and initial generated bindings. The destination must not exist. |
| `check [directory]` | Validate the manifest, detect stale generated bindings, install local Cyna dependencies, and check Cyna source. |
| `build [directory]` | Generate bindings, compile Cyna and Weiv, link the macOS host, and package `build/CeivApp.app`. |
| `run [directory]` | Build and open a new app instance. |

The build currently requires macOS, Cyna 0.4.1, Node 22, Xcode Command Line
Tools, and the package-provided `weivjs` dependency. The npm package can be installed
outside the Ceiv checkout.

## Cyna API

Declare a Cyna `staticlib`. Prefer a public Cyna function with a `// @ceiv`
annotation. Ceiv generates the C export and derives its TypeScript name from
the Cyna function name. It validates supported arguments and results on both
sides. Ceiv compiles generated exports from its build entry; app source does not import them.

Ceiv writes generated Cyna modules under `src/generated/`: `ceiv_generated_entry`,
`ceiv_generated_commands`, and `ceiv_generated_callbacks`. The build copies
them with authored source into `build/cyna-src` and compiles the staged manifest. The app's web code imports the public TypeScript bindings from
`web/generated/commands.ts` and `web/generated/events.ts`.

```cyna
// @ceiv
pub fn score(value: i32): i32 {
    return value + 1;
}
```

The existing `ceiv.lib` module contains `text_length` and `write_result`
helpers for the prototype's C ABI boundary. They are not the intended GUI API
and should not be used as the basis for new app code. Byte handling belongs in
the bridge implementation or general Cyna facilities.

`i32` maps to TypeScript `number`; `// @ceiv {...}` can describe booleans
carried as integers and records carried as JSON strings. Ceiv writes a Cyna
`string` result into a bounded native result buffer. Existing C exports remain
supported for older apps. Unsupported signatures fail the build. See
`examples/hello/src/lib.cy` for the supported descriptors.

For `// @ceiv`, the Cyna function name supplies the default TypeScript function
name in camel case. Use the `binding` metadata field when the TypeScript export
needs a different name; `name` sets the command's public route. Ceiv derives
the native command symbol internally. App annotations do not name C symbols.

## TypeScript API

The generated `web/generated/commands.ts` module exports one function per
Cyna command. Framework services and bridge types live in
`ceiv/sdk`; `ceiv/slots` handles native slot placement. The npm package includes their `.d.ts` declarations. Generated app commands and events have their own declarations. The
example above becomes:

```ts
import { score } from "./generated/commands.ts";
import { CynaError } from "ceiv/sdk";

try {
  const result: number = await score(4);
} catch (error) {
  if (error instanceof CynaError) console.log(error.code, error.message);
}
```

Commands accept an optional final `{ signal, deadlineMs }` argument.
`ceiv/sdk` exports `events.subscribe(topic, handler)` and `events.once(topic)`.
Built-in topics are `app.windows` and `app.lifecycle`; app declarations add
typed topics. `ceiv build` refreshes both generated app modules after Cyna
exports change; `ceiv check` reports stale generated files.

The Cyna modules expose `app.quit_on_last_window`, `window.open_with_options`,
`window.get_state`, `window.set_size`, `menu.on_action`, and typed
`events.publish_app` / `events.publish_window` failures. The generated client
exposes `currentWindow`, `setCloseHandler`, and `createActionContext`. A close
handler returns a boolean or promise; a missing reply cancels the close after
five minutes. The hello app exercises these APIs.

## Native plugin callbacks

An app with a native plugin can expose a Cyna function to that plugin without
handwriting a C export. Put `// @ceiv-callback` immediately above a public
Cyna function. Ceiv chooses its native symbol from the function name and
generates both the bridge and `native/generated/ceiv_callbacks.h` for the
plugin to include. The bridge lives under `src/generated` and is copied into the build tree; app source does
not import it. `ceiv check` regenerates and checks the bridge. Use `i32`, `u32`, `i64`, or `usize`
for scalar values and `*const u8`, `*u8`, or `*u32` for native buffers and
output slots. Ceiv maps these to C ABI types in the generated wrapper. Pointer
casts preserve the address; the callback still checks pointer validity and
buffer bounds. Native C callers may use `const char *` for a NUL terminated
path passed as `*const u8`; both carry the same pointer at this ABI boundary.

For a pointer and length pair, import `ceiv.native_buffer` and declare one
`native_buffer.ReadBuffer` or `native_buffer.WriteBuffer` callback parameter.
This API is in the Ceiv Cyna package version `0.1.3`.
Ceiv expands it to a pointer followed by `c_size_t` in the native ABI, rejects
a null pointer with status 1, and passes the borrowed pointer and length to
the callback. These callbacks return `i32`. The native caller owns the memory
through the synchronous call; the callback must not retain either pointer.
The callback checks its operation specific length limits before reading or
writing bytes.

The callback function remains app owned. Ceiv owns its C export spelling and
linkage. Native plugin imports belong in a focused provider adapter; Ceiv's
`surface` module owns surface handle validation and lifetime operations.

## Private implementation

`native/`, `scripts/`, and the generated Objective-C dispatcher are SDK
internals. App code uses public Cyna functions and the generated TypeScript functions.
The optional video plugin belongs to the proof
and is not part of the ordinary app API.
