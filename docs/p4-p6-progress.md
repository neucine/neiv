# P4–P6 progress

Status: in progress, 1 November 2026. The M2 and M3 gates are open.

The video proof has moved to `examples/proof`; all examples now declare
versioned Ceiv dependencies without paths into this checkout. Generated
TypeScript separates framework services in `ceiv/sdk` from app exports in
`commands.ts`. The clean M1 gate passed in `/tmp/ceiv-m1.Jqata6`, the proof
build wrapper passed, and an isolated copy of the proof built in
`/tmp/ceiv-standalone.FoP9g4` using a local npm tarball. `ceiv@0.1.0` is
not yet published on npm, so ordinary registry installation remains a release
step. The M2 navigation and close results appear below.

The npm package now packs the matching Cyna library artifact during `prepack`.
The CLI and build script bootstrap that library from the bundled artifact,
then resolve the app's dependencies normally so other Cyna packages can use
their configured artifact source. `npm pack` confirmed the manifest and
surface source are present in `ceiv-0.1.0.tgz`. A proof copy in
`/tmp/ceiv-m2-standalone.MTFk1H` built with that tarball, and the clean M1
gate passed in `/tmp/ceiv-m1.BWT0PN`. A fresh user account install and npm
registry installation remain untested until the package is published.

## Verified foundation

- P4: shell links, text clipboard, tray title/clear and click, notification permission request, and file dialogs have capability checks. Generated TypeScript supports filtered, multiple file selection. Packaged hello exercised undeclared capability denial; allowed service paths and window-close behavior still need a packaged acceptance pass. Notification delivery is unverified.
- P5: a window-owned `SurfaceId` can create, update, label for accessibility, and destroy a text view in a web slot. The opt-in `CynaColorPlugin` provides a Metal color view through that lifecycle, with visibility, suspend/resume, and stale-ID checks. The host accepts named native providers from an app plugin, with bounded options JSON and per-surface provider ownership. `attach` and `detach` return typed state errors and preserve the view across detachment; the slot host caches bounded placements for immediate reattachment. Providers receive point frame, backing scale, and visibility changes; Cyna can query those metrics by surface ID. The [provider sample](../examples/provider) reported 2x scale on the laptop display and passed create, detach, attach, destroy, reload and recreate, and close. On 1 November its packaged focus check passed native keyboard `A`, Escape return, and focus return on detach. The focused slot test and clean M1 gate passed (`/tmp/ceiv-m1.5BQAmE`). It links no Metal or media framework. The [Metal sample](../examples/metal) builds with pixel drawable resizing. The ordinary hello app links no Metal, MetalKit, QuartzCore, or AVFoundation. Display migration, VoiceOver, video migration, and the full M2 matrix remain.
- P6: `ceiv dev` rebuilds and restarts on source changes; `ceiv package` makes a ZIP with optional version and icon metadata. It accepts a signing identity and optional notarization profile, verifies the signature, staples and validates after notarization, then recreates the ZIP. The ad hoc signing path passed `codesign --verify --strict` and `unzip -tq` on 1 November 2026. Developer ID signing and notarization are untested because no release identity or profile was supplied. A scratch scaffold exercised restart and SIGTERM cleanup. The clean M1 check passed again in `/tmp/ceiv-m1.5fb4XI` after surface metrics work. Clean installation on another Mac, release reproducibility, and update policy remain.

## M2 video packet

The video proof in `examples/proof` now creates `video.player` through `SurfaceId`; the plugin
owns playback and frees the player, timer, and observer on surface teardown.
The root app build passed. Its packaged UI showed the native preview, played,
paused, and completed a seek with 46.28 ms receipt-to-seek completion and
55.28 ms receipt-to-decoded-frame on one observation. Its 20-seek sample
reported median 16.40 ms and p95 21.08 ms for decoded-frame readiness. These
are observations on this Mac, not display or scanout latency guarantees.
The proof now exposes detach and attach commands; two consecutive packaged
detach/attach cycles restored the preview. The clean M1 regression gate first
found missing surface/window stubs in the proof's dispatch test; after adding
those stubs it passed in `/tmp/ceiv-m1.yT3bkY`. The earlier crash report at
13:44 preceded this packet's UI checks; no new CeivApp report appeared.

## M2 lifecycle and capability packet

The video plugin now resets its seek revision when its surface is destroyed and
rejects delayed callbacks from an earlier surface generation. A packaged
Command-R recreated the video and a new seek completed (4.98 ms to seek
completion; 14.61 ms to decoded frame). Reload during the 20-seek run also
recovered, and close during playback exited cleanly. Resizing the video window
kept the preview in its slot. A local `ps` snapshot showed the proof host at
1.9% CPU and 86.6 MiB RSS while idle, and 6.2% CPU and 87.3 MiB RSS during
playback; these snapshots exclude WebKit helper processes. `powermetrics`
requires superuser access here, so GPU usage was not measured.

Native provider, Metal, and video views are now exposed as accessibility
elements with labels. The macOS accessibility tree showed `App provider
surface`, `Metal color preview`, and `Native video preview`; keyboard input
and focus return passed earlier. A packaged Metal sample rendered after resize.
VoiceOver navigation itself has not been exercised.

`surface.capabilities(window, kind)` now reports provider and renderer flags
before creation without linking Metal into the ordinary host. The Metal and
video samples check availability before creating their surfaces. The clean M1
gate passed in `/tmp/ceiv-m1.K4APWC`; packaged Metal and video builds passed.
The focused slot test and clean M1 gate passed after the capability default
change in `/tmp/ceiv-m1.sK99NJ`. A concurrent Metal build briefly read the
Cyna package cache while the M1 script replaced it; a sequential Metal build
then passed. Avoid overlapping clean install and example build commands against
the shared Cyna package store.

## Next packet

Next exact edit: exercise sleep/wake, display migration and scale change,
and device removal where reproducible; obtain a GPU observation with suitable
tool access and inspect native surfaces with VoiceOver. The full-window native
surface path remains to be implemented before claiming the full M2 scope. The
P4 allowed-service gate and M3 distribution gate follow with their own evidence.
