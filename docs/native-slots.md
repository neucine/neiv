# Web view and native slot foundation

The macOS host owns one `WKWebView` and one `CynaSlotHost` per window. A native
module registers an `NSView` under a slot ID with that window's slot host. The
Weiv page anchors the slot to an element with the generated
`attachNativeSlot(element, id)` helper. The helper sends viewport coordinates
when the element or window moves or resizes and returns a cleanup function.
Only the packaged main frame at `cyna-app://local` can send slot messages.

The slot host validates coordinates, clips them to the web view bounds, hides
invalid or offscreen slots, hides all slots when navigation starts, and removes
registered views on navigation or window close. Cyna `surface.set_visible` is
combined with placement visibility, so a geometry update cannot reveal a
surface the app hid. Metal surfaces can suspend and resume drawing while their
slot remains attached. Registration, updates, and cleanup
run on the macOS main thread. Each window has its own slot map; a slot ID does
not identify a view in another window. The ordinary app links the slot host but
does not link the video or Metal module.

The video proof uses slot `preview`. Its AVPlayer view is created by the
optional `video.player` provider through `surface.create_native`, then the page
imports `attachNativeSlot` from the generated module. Playback messages remain
private to that proof plugin. Surface destroy, navigation, and close release
the player, timer, and notification observer.

The opt-in Metal sample uses `surface.create_color(window, "color", 500)`,
`set_visible`, `set_suspended`, `set_accessibility_label`, `is_alive`, and
`destroy`. Its `CynaColorPlugin` is private to the Mac host. In the packaged
sample, create, destroy, recreate, reload and recreate, and close with an active
surface passed on 1 November 2026. The sample stores one active surface ID for
its single-window flow.

An app can supply a native provider without editing the host. Its manifest sets
`nativePlugin` to an Objective-C class, lists `.m` files in `nativeSources`, and
optionally lists link frameworks in `nativeFrameworks`. The class implements
`CynaHostPlugin` and returns a kind-to-provider dictionary from
`surfaceProviders`. A provider implements `CynaSurfaceProvider` and creates an
`NSView` for validated options. The host owns the view after registration and
calls optional `destroySurface:` on explicit destroy, navigation, or close.
The app's Cyna module calls `surface.create_native(window, slot, kind,
options_json)`; a provider package can wrap this low-level JSON boundary in a
typed Cyna function. [The provider sample](../examples/provider) demonstrates
this path with an app-owned view. It passed packaged create, destroy, recreate,
reload and recreate, and close on 1 November 2026, without Metal or media
linkage.

The host now registers app-owned native providers, while `SurfaceId` and slot
IDs remain value-based in Cyna. `surface.detach(id)` removes the view from its
slot but retains the surface and provider; `surface.attach(id)` registers that
same view again. Both calls return typed state errors. The host caches up to 64
recent slot placements for the page generation, so reattachment uses the
current element rectangle immediately. Visibility set while detached is
applied on reattachment. Navigation clears placements and destroys surfaces.
The packaged provider sample visibly passed detach, attach, reload and
recreate, and close with an attached surface on 1 November 2026.

`surface.get_metrics(id)` returns the placed view's width and height in macOS
points, its window's backing scale, whether it is attached, and whether the
native view is visible. Optional providers receive frame, scale, and visibility
changes on the main thread through `surface:didChangeFrame:scale:visible:`.
The slot host refreshes placement when backing properties change; the Metal
provider sizes its drawable in pixels from the point dimensions and scale.
The provider sample reported 2x scale on the laptop display. Display migration
and sleep/wake behavior still need a packaged check.

Before creation, Cyna can call `surface.capabilities(window, kind)`. It returns
provider availability and explicit flags for Metal, native media, BGRA8 color,
GPU completion timing, decoded-frame timing, and software fallback. An unknown
kind returns `unsupported`; an absent window returns `not_found`. A custom
provider without a capability report is available by registration but has no
declared renderer, timing, or fallback flags. The Metal provider reports its
device availability; the video provider reports bundled media availability.
Neither provider promises a software fallback. The color provider currently
does not expose GPU completion timing as a public measurement, so that flag is
false. A successful report does not guarantee creation with arbitrary options.

An attached, visible surface can request keyboard focus with `surface.focus(id)`.
`surface.release_focus(id)` returns focus to the webview when that surface owns it.
The native view receives pointer events inside its clipped slot and may take focus
on click. Hide, detach, destroy, and navigation return focus to the webview before
removing a focused view. Providers own their view's keyboard behavior; the demo
handles `A` and Escape. The host places native views above web content inside
the slot rectangle and clips them to the webview. A provider supplies its native
accessibility role and value; `surface.set_accessibility_label` sets its label.
The packaged demo passed focus by command, `A` color change, Escape return, and
focus return on detach on 1 November 2026. VoiceOver inspection and tab-order
behavior remain open.

The provider contract still needs display migration, VoiceOver navigation, and
broader lifecycle testing.
An app with no native module gets a clear error from `attachNativeSlot` if it
tries to attach a slot.
