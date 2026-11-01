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

Declare a Cyna `staticlib`. An exported C function under
`src` becomes a command. Ceiv derives its TypeScript name from the Cyna
function name and validates supported arguments and results on both sides.

```cyna
extern c("strlen") fn strlen(text: c_str): c_size_t;

export c("my_app_score") fn score(text: c_str): c_int {
    return strlen(text) as c_int;
}
```

The existing `ceiv.lib` module contains `text_length` and `write_result`
helpers for the prototype's C ABI boundary. They are not the intended GUI API
and should not be used as the basis for new app code. Byte handling belongs in
the bridge implementation or general Cyna facilities.

`c_int`, `c_double`, and `c_str` map to TypeScript `number`, `number`, and
`string`. A `// @ceiv {...}` comment immediately before an export supplies
wire-name or semantic information absent from the C ABI, such as bounded
strings, booleans carried as integers, records carried as JSON, or buffer
returns. Unsupported export signatures fail the build. See
`examples/hello/src/lib.cy` for the supported descriptors.

## TypeScript API

The generated `web/generated/commands.ts` module exports one function per
Cyna command. Framework services and bridge types live in
`ceiv/sdk`; `ceiv/slots` handles native slot placement. The npm package includes their `.d.ts` declarations. Generated app commands and events have their own declarations. The
example above becomes:

```ts
import { score } from "./generated/commands.ts";
import { CynaError } from "ceiv/sdk";

try {
  const result: number = await score("Cyna");
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

## Private implementation

`native/`, `scripts/`, and the generated Objective-C dispatcher are SDK
internals. App code uses Cyna exports and the generated TypeScript functions.
The optional video plugin belongs to the proof
and is not part of the ordinary app API.
