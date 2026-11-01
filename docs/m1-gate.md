# Ceiv M1 gate — 31 October 2026

**Result: passed** on macOS 26.6.2, arm64, macOS 27 SDK, Cyna 0.4.1,
Node 22.22.1, and local Weiv 0.1.2 at commit `05c5024`.

| Requirement | Evidence |
| --- | --- |
| F01 app package and manifest | `packages/ceiv` is an app-facing Cyna dependency; manifests give distinct IDs and assets. Cyna startup exports configure the window titles and sizes. Command exports generate the bridge. The manifest validator rejects invalid identity and paths. |
| F02 shared host | `native/app_host.m` builds both apps. The proof's video controller is in `native/video_plugin.m`; the ordinary hello binary has no direct AVFoundation, CoreMedia, QuartzCore, or Metal link. Both clean bundles launched. |
| F03 independent windows | The hello app opened two windows. A slow command in one was followed by reload; a command in the other still returned `Cyna returned 4`. Window IDs, page generations, bridge handlers, asset handlers, and pending sets are per window. After fixing close ownership, five repeated Command-N/Command-W cycles left the first window responsive; closing the last window exited cleanly. |
| F04 typed commands | The hello app uses integer, bounded string, boolean, finite number, record, optional, and array schemas. Its native dispatch test and generated client test pass valid and invalid cases. The packaged host fixture returned structured errors for unknown and oversized direct requests. A composite return passed native and client checks. |
| F05 bridge lifecycle and events | The client test covers handshake, protocol mismatch, cancellation, invalidation, late reply, event sequence, and unsubscribe. The packaged fixture got one `TIMEOUT` reply for a one millisecond slow command and no late second reply; a wrong-window request got no reply. The 17th event subscription returned `LIMIT_EXCEEDED`. An existing packaged window displayed a `Window opened` event. Ordering and best-effort limits are in the README. |
| F06 bundled asset and origin policy | The packaged Weiv pages loaded. Asset tests passed traversal, double encoding, symlink escape, MIME, and remote-origin checks. A WebKit frame test accepted one main-frame message and rejected an iframe message. The packaged fixture confirmed an iframe command got no reply and remote navigation was cancelled. The bundle contains the release CSP. |
| F07 build and drift check | `KEEP_M1_OUTPUT=1 sh scripts/m1-check.sh` built both apps from source-only copies in a fresh temporary directory, including the local Cyna package dependency, and passed focused checks. `node scripts/generate-commands.mjs --check` passed for both source apps. |
| F08 sample and API docs | The README gives build/run, app copying, manifest, Cyna ABI, typed errors, events, windows, assets, and packaging instructions. `examples/hello` is the second non-video app. |

The gate's packaged UI smoke check opened both clean bundles. The proof
counter changed from 0 to 1; the hello app displayed `Score: 8` and a window
event. The copied host fixture displayed `PASS host policy`. Both Info.plists
had the intended distinct bundle IDs, and the proof's media asset was present.
The final clean rebuild passed `scripts/m1-check.sh` from source-only copies.
The rebuilt proof app again advanced its counter to 1. No new CeivApp crash
report appeared during the repeated hello close cycles or final-window exit.
Review of all `.cy` files under `src`, `examples/hello/src`, and
`packages/ceiv/src` found no AppKit/WebKit names or types. AppKit and WebKit
remain in the private macOS host.

F04 exposed two Cyna ABI boundaries. `docs/LANGUAGE_GAPS.md` in the Cyna
checkout now records the direct raw-pointer indexing reproduction under LG-02
and an identical foreign-symbol declaration reproduction under LG-32. The
framework package uses a narrow caller-owned output buffer and one shared
foreign declaration. No Weiv setup, compile, or runtime friction was observed
in this M1 work; the local Weiv friction ledger required no new entry.

## Estimate update after the F01/F02 packet

The first packet reached two packaged app builds in roughly five minutes of
elapsed assisted session time, from the goal start at 15:57 NZDT through the
host/plugin extraction around 16:02. This is a wall-clock observation, not a
manual engineering-day rate. The full M1 gate took about 35 minutes of elapsed
assisted session time, including implementation and local verification.

| Milestone | Original planning envelope | Updated status or estimate |
| --- | ---: | --- |
| M1 ordinary GUI apps | 10–20 focused days | Gate passed on this Mac. A separate target-app adoption and cross-machine check should be estimated from its requirements. |
| M2 optional native rendering | 10–20 additional days | Retain 10–20 days; M1's optional video proof does not establish a public surface API or Metal lifecycle effort. |
| M3 release hardening | 10–25 additional days | Retain 10–25 days; signing, notarization, clean-machine installation, and capability policy have not been implemented. |

The M1 gate proves the ordinary macOS app path on this development Mac. M2's
public surface API and M3's distribution checks remain separate milestones.

## Command generation update

The command source of truth is now each app's Cyna exports under `src`.
`scripts/generate-commands.mjs` discovers their symbols, parameter names, and
C ABI types, then generates the typed TypeScript client and Objective-C
dispatcher. `commands.json` was removed from both apps. Adjacent `@ceiv`
comments provide only wire names and semantic descriptors that the C ABI cannot
express. The clean M1 check passed again, including an export discovery test
that changes a parameter and return type and checks the generated schema.
The freshly packaged hello app returned `Cyna returned 4` after invoking its
generated `doubleValue` function.

The SDK CLI now provides `new`, `check`, `build`, and `run`. The M1 check creates
a fresh scaffold, checks its generated bindings and Cyna source, and builds its
`.app`. A separate packaged UI smoke check launched that scaffold and its
generated `increment` command returned `1`. The public CLI, Cyna helpers, and
generated TypeScript API are described in `docs/api.md`.
