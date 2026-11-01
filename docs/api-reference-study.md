# Public GUI API reference study

This study informs Ceiv's future API. The examples below are proposed
Ceiv syntax, not current implementation.

| Concern | Framework pattern | Ceiv direction |
| --- | --- | --- |
| Native menus | [Tauri](https://v2.tauri.app/reference/javascript/api/namespacemenu/) creates menu items with IDs, accelerators, enabled state and popup/app menu placement. [Electron](https://www.electronjs.org/docs/latest/api/menu-item) adds native roles and click callbacks. [Wails](https://wails.io/reference/menu/) supports runtime enabled/checked updates. | Define actions by stable ID, build native menus from a tree, and update item state without rebuilding app code. Use platform roles for standard Edit/App actions. |
| Shortcuts | [Electron](https://www.electronjs.org/docs/latest/tutorial/keyboard-shortcuts) uses menu accelerators for focused apps and a separate global shortcut API. [Tauri](https://v2.tauri.app/plugin/global-shortcut/) makes system-wide shortcuts an optional plugin with permissions. | Keep focused app shortcuts in the menu/action system. Make system-wide hotkeys a separate opt-in capability. |
| Context menus | [Tauri](https://v2.tauri.app/reference/javascript/api/namespacemenu/) can popup a menu. [Wails](https://wails.io/features/menus/context/) associates native context menus with web elements. | Let a Weiv element request a native context menu by ID, with context data and the same action IDs used elsewhere. |
| Windows and webviews | [Electron](https://www.electronjs.org/docs/latest/api/browser-window) exposes window operations; [Tauri](https://v2.tauri.app/reference/javascript/api/namespacewebview/) distinguishes stable webview windows from child webviews. | Expose opaque window IDs and typed operations. Keep WebKit objects inside the host. Treat additional webviews as a later feature. |
| Native views | [Electron](https://www.electronjs.org/docs/latest/api/web-contents-view) uses a native view tree with explicit bounds and ownership. | Keep the window-owned slot host, but let the page anchor a native view to an element; expose lifecycle and failure results before making custom surfaces public. |
| Native calls | [Wails](https://v2.wails.io/docs/howdoesitwork/) generates JS bindings for bound Go methods. | Continue generating typed TS functions from Cyna exports; app code imports ordinary functions. |
| Native events | [Tauri](https://v2.tauri.app/develop/calling-frontend/) emits globally or to a specific webview; frontend `listen` returns an unlisten function, and channels serve streamed progress. [Electron](https://www.electronjs.org/docs/latest/tutorial/ipc) sends to a chosen `WebContents` and recommends a narrow preload wrapper. [Wails](https://v3.wails.io/reference/events/) provides app, window, and custom events with unsubscribe functions. | Keep commands as request/reply; generate typed frontend subscriptions for Cyna/host notifications, target a window or broadcast, and return an unsubscribe function. Reserve channels for continuous streams. Do not expose raw bridge channels to app code. |

## Proposed Ceiv shape

The primary abstraction is an **action**. Menus, focused shortcuts, and
context menus invoke the same action ID. The host resolves the action in the
focused window and sends it to the active handler. This follows the shared
menu accelerator model while adding explicit view contexts for editors and
similar apps.

```ts
// Proposed app API, not implemented.
const actions = defineActions({
  "document.save": { label: "Save", shortcut: "CmdOrCtrl+S" },
  "document.close": { role: "close" },
});

setApplicationMenu([
  menu("File", [action("document.save"), action("document.close")]),
]);

const editor = createActionContext({
  scope: "view",
  actions: {
    "document.save": { enabled: () => dirty, run: saveDocument },
  },
});
editor.activate();
editor.dispose();
```

The exact TS and Cyna entry points need an implementation spike. The contract
should require stable action IDs, one dispatch path for click and key input,
defined context precedence (view, then window, then app), automatic disposal
on navigation/window close, and synchronized native menu state. Standard text
editing and system shortcuts retain platform behavior. Global hotkeys require
separate registration and capability checks.

For event delivery, Tauri's target distinction and Electron's explicit
recipient make window ownership clear. Wails's `On`/`Emit` names are familiar,
but Ceiv should generate one typed event map from Cyna declarations, then
offer `events.subscribe(topic, handler)` with payload inference. Tauri uses channels for
streaming progress; Ceiv v1 can use bounded event notifications for modest
progress updates and should add a separate channel API if continuous streams
need stronger flow control. This is an inference from the cited APIs, not a
claim about their internal implementations.

The Cyna side should expose shell and window operations through values and
opaque IDs, with no AppKit or WebKit types. The page side can own view context
activation because it knows focus and editor state. Native rendering slots
remain optional and use a separate API from menus and actions.
