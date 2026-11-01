# Generic framework contract

## Default app

The default window is one webview. JavaScript owns view state and may own all
application state. Cyna supplies native commands, OS resources, background
work, and lifecycle hooks. Apps opt into native rendering when needed.

## Command bridge

Request: `{ id, command, args }`. Reply: `{ id, ok, value?, error? }`.
The generated dispatcher validates command names and bounded argument types.
The host accepts messages from the app scheme's main frame, runs Cyna commands
on a background queue, and returns numbered replies on the UI thread. Late
replies are dropped after navigation. The counter demo serializes its own
updates so rapid clicks retain order. A production bridge needs versioned
types, cancellation, deadlines, structured errors, and per-window permissions.

## Optional native surface

The macOS proof places an `AVPlayerLayer` sibling above the webview. The Weiv
page reports its placeholder's viewport rectangle after layout and on resize
or scroll. The host validates the rectangle, converts it to AppKit coordinates,
clips it to the webview, and positions the native view. Video and audio remain
inside AVFoundation; no decoded pixel buffer crosses JavaScript.

The bundled 640×360 H.264/AAC clip plays for ten seconds. A native 60 Hz timer
checks decoded-frame availability during seeks. The host sends a playback
anchor with media position, native monotonic timestamp, rate, and seek ID on
playback state changes and about once per second. The webview maps the anchor
to its local receipt time and advances the timeline on animation frames. Small
drift corrections are limited at each anchor; large discontinuities reset
the anchor. Each
seek has an ID. The host records receipt and AVPlayer seek completion, then
checks `AVPlayerItemVideoOutput` for a decoded buffer whose timestamp is within
50 ms of the target. The web page acknowledges its indicator on an animation
frame. The UI separately reports those boundaries and runs 20 sequential
seeks for decoded-frame median and p95.

The timeline has one position writer at a time. While the user scrubs or a
seek is in flight, the webview keeps the user's target position and ignores
periodic playback ticks. Native ticks carry the current seek ID, so a queued
anchor from an earlier seek cannot snap the thumb backward. Local playback
animation resumes after the matching decoded frame is available.

One packaged run on the development Mac measured decoded-frame availability at
14.97 ms median / 21.76 ms p95 when paused, and 70.12 ms median / 71.60 ms p95
while playback ran. A later 20-seek playback run after the timeline fix measured
15.77 ms median / 17.49 ms p95, showing substantial run-to-run variation. The
runs use one small test clip and do not establish a latency budget for
production media or hardware.

The decoded-buffer callback is not a display-present timestamp. The web
indicator acknowledgement confirms JavaScript handled the event and reached
an animation frame; it does not prove its pixels scanned out with the video.
The JavaScript acceptance round trip is an upper bound on one-way bridge delay.
Before using this for Lightcept, test target codecs and resolutions under CPU
and GPU load, measure actual displayed frames and audio drift, and count late
or dropped frames over sustained playback. The generic framework should expose
these as optional surface capabilities; ordinary windows need only the webview.

A native sibling is opaque and rectangular. HTML cannot overlap it or clip it
to arbitrary CSS shapes. Interactive native content still needs focus,
accessibility, input routing, display-change, and teardown contracts. Multiple
surfaces and other platform backends remain future work.
