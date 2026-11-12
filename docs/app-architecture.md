# Where app code belongs

A Neiv app has a Weiv page written in TypeScript and a native application
module written in Cyna. The host connects them.

| Layer | Owns | Examples |
| --- | --- | --- |
| Weiv / TypeScript | The page, direct user interaction, and short lived view state | Form input, selection, DOM focus, animation, view specific menu actions |
| Cyna | App operations, durable state, and native resources | Documents, persistence, background work, windows, native surfaces, app wide menu actions |
| Neiv host | Bridge validation, windows, webviews, and capability enforcement | Argument checks, page generation checks, native slot placement |

## Normal request flow

1. A Weiv event handler reads view input and calls a typed function from
   `web/generated/commands.ts`.
2. The exported Cyna function performs the app operation. It may call Neiv's
   Cyna API for native services.
3. The result updates the Weiv view. For later native changes, Cyna publishes
   an event and the page subscribes through `@neucine/neiv/sdk`.

The starter app's button calls `increment(value)` in TypeScript. That generated
function invokes the Cyna `increment(value: c_int)` export and returns a typed
result. The page displays the result. The host handles bridge messages and
validation.

## Choosing a service entry point

Some services have APIs on both sides because either side can initiate them.
Call the service where the action starts:

| Starting point | Use | Example |
| --- | --- | --- |
| Page control | TypeScript SDK | Show a file dialog, open a URL, read clipboard text for a focused field |
| Cyna operation or native callback | Cyna API | Update a window after background work, publish an event, act on an app menu selection |

A Cyna command is useful when the app must check state, perform work, or own a
native resource. A page click that only opens a dialog can call the TypeScript
SDK directly. A dialog can begin in TypeScript and pass the chosen path to a
Cyna command for an app operation; host capabilities still apply.

Define app wide menus and shortcuts in Cyna. Use TypeScript action contexts
when an action depends on the focused page element. For a native surface, Cyna
owns its `SurfaceId`; TypeScript anchors its slot to a DOM element with
`attachNativeSlot`.

`app.json` holds static identity, resources, and capabilities. `cyna.toml` and
`package.json` declare dependencies. App behavior belongs in Cyna and Weiv.
