# Core, lifecycle, actions, commands and events gate

Status: implementation review, 1 November 2026. Covers P0–P3 in
[desktop framework map](desktop-framework-map.md). It does not cover optional
native renderer providers or release signing.

| Packet | Landed | Evidence |
| --- | --- | --- |
| P0 core | Numeric `WindowId` shared by Cyna and generated TypeScript; session UUID remains private. NSWindow close animation disabled and host ownership released on the next main loop turn. | Five packaged hello open/close cycles kept one live window; last close exited; no new `CeivApp` crash report. |
| P1 lifecycle | `app.quit_on_last_window`, dock reopen, window options with minimum size and visibility, state query, size/bounds setters, focus/resize events, and `setCloseHandler`. | Packaged hello opened a configured second window; closing it left the first page live with `closed` event. Reloading the second preserved the first window's counter. Edited text prompted on title-bar, menu, and Cyna close requests; Cancel kept the window, OK exited. A scaffold built with `quit_on_last_window(false)` remained running after close and reopened on activation. |
| P2 actions | Shared menu/shortcut/context ID; source, window and data passed to page handlers; Cyna `menu.on_action` callback handles backend actions; explicit action state and acknowledgement. | Packaged hello's menu, Command-D, and context menu doubled the counter. Focused text field won the shortcut. Disabling the app action blocked Command-D and context selection. The backend menu action renamed the window. Bridge test covers source/window/context data, view precedence and disabled winner. |
| P3 commands/events | Cyna exports continue to generate typed TS and host adapters; app event declarations generate payload types. `publish_app` and `publish_window` report invalid payload, missing window and queue saturation separately. Built-in lifecycle/window events get frontend validation. | Clean source builds and focused bridge/export tests passed. Packaged custom event delivery worked. The packaged host fixture showed `PASS host policy`, including the 17th subscription rejection, timeout, origin and frame checks. Bridge test rejects invalid resize payload and old sequences, and covers close handler replies. |

Gate command: `KEEP_M1_OUTPUT=1 sh tests/m1-check.sh` passed on 1 November
2026 after the expanded checks, producing `/tmp/ceiv-m1.V8gDLM`.
This includes clean proof, hello and
scaffold builds, generated binding drift checks, dispatch, asset, bridge and
slot host tests. The dispatch fixture also exercises Cyna window options and
the state snapshot. Packaged UI checks above used the hello app and a modified
scratch scaffold.
The clean gate now compiles each dispatch fixture beside the adapter generated
in its scratch app, so it cannot silently use a stale checkout adapter.

## API behavior to retain

- `window.close(id)` requests a close. It can return successfully even when
  the page close handler later cancels that request. Listen for `app.windows`
  `closed` when completion matters. A close handler has five minutes to reply;
  timeout cancels closing.
- `WindowState` reports native frame x/y, content width/height, focus and
  visibility from one main-thread host snapshot.
- Native action callbacks run on the main thread and should finish quickly.
  Return zero when handled; a nonzero result passes dispatch to the page.
  `menu.set_state` enables a backend action when no page context owns it.
- Event delivery is best effort. `PublishError.queue_full` reports a full
  target queue; it does not provide replay or backpressure.

## Next refinement before declaring the wider v1 API complete

The action acknowledgement is currently logged by the host; a native menu
selection has no caller awaiting that result. The full
multiwindow, capability, permission, and release matrix remains in
[mac-feature-plan.md](mac-feature-plan.md).

The following specific cases remain unverified: a real `PublishError.queue_full`
from the host's 64-delivery queue, the five-minute close-handler timeout,
native action timeout/failure logging, and shortcut conflict registration.
A 65-event packaged probe completed with no queue overflow because deliveries
drained during publication; it is not evidence for the saturation path.
