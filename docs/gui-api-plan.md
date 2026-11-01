# Ceiv GUI API boundary

[Framework API comparison](api-reference-study.md) records the Tauri,
Electron, and Wails patterns used to shape this boundary.
[V1 API design](v1-api.md) defines the public contract and gate. The
[desktop framework map](desktop-framework-map.md) tracks capability scope and
implementation packets.

Ceiv's public API should describe desktop app behavior. The Cyna standard
library remains responsible for general strings, memory, files, and C interop.
The current `ceiv.lib` byte helpers serve the prototype bridge and are not a
stable public interface.

| Area | Current API | Boundary |
| --- | --- | --- |
| Shell | `ceiv.app` identity, lifecycle, quit | AppKit stays in host |
| Windows | `ceiv.window` open, focus, title, close, reload | Opaque numeric `WindowId` |
| Menus and shortcuts | `ceiv.menu` tree and state; generated TypeScript action contexts | Focused view, window, then app scope |
| Dialogs | `ceiv.dialog` and generated `dialogs` | File capabilities declared in manifest |
| Commands and events | Cyna exports and event declarations generate typed TypeScript client | Host validates both directions |
| Native slots | `ceiv.slot.set_text` and `attachNativeSlot` | Arbitrary providers remain M2 |

The API must use values and opaque IDs, with AppKit and WebKit types private to
the macOS host. App-wide operations should have explicit ownership; window
operations should take a window ID and report a typed error for a closed or
unknown window. Menu and shortcut declarations should share action IDs, so a
single app handler can respond to either input path. The framework must own
main-thread dispatch, validation, and cleanup.

## Menu and shortcut contract

Menus and shortcuts share action IDs. Cyna defines native menu trees; the page
registers app, window, and view action contexts. The focused view takes
precedence over the window and app context. The host validates menu trees and
shortcuts and handles native presentation.

Arbitrary native renderer providers and distribution hardening remain separate
milestones. See [native slot foundation](native-slots.md).
