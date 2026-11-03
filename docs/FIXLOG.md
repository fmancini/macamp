# Fix log

## The app spun at 100% CPU after adding a menu bar item
Symptom: self-test and snapshots printed nothing; a sample showed SwiftUI re-evaluating `_ResolvedCommands` and scenes forever.
Cause: `MenuBarExtra(isInserted:)` got a binding over `@AppStorage`. SwiftUI wrote the value back on every pass, and each write re-evaluated the app.
Fix: an `@Observable` `MenuBarSettings` whose binding writes only when the value changes.
Rule: never give a scene a binding that writes on every set; compare first.

## Self-test ran no checks (twice)
Symptom: no output from `--selftest` or `snap.sh`.
Cause: (1) the Mac's display was unavailable, so windows never appeared and window-based hooks never ran; (2) a "reopen windows?" prompt from saved state when launching without `tools/*.sh`.
Fix: test modes start from `AppDelegate`; always run through `tools/selftest.sh` and `tools/snap.sh`, which clear saved state.
Rule: start test modes from the app delegate, not from a window.

## Audio-thread closures crashed the app
Symptom: SIGTRAP at launch with `_dispatch_assert_queue_fail`.
Cause: tap closures written in a main-actor type run on the audio thread.
Fix: install taps from `nonisolated` functions and share data through a `nonisolated` class with a lock.
Rule: any closure Core Audio calls must be `nonisolated`.

## The spectrum updated only about 10 times a second
Symptom: the bars looked choppy even though the view drew at 60 fps.
Cause: an `AVAudioEngine` tap delivers audio in blocks of about 100 ms (4800 frames), whatever `bufferSize` asks for. The FFT ran once per block.
Fix: a pass-through `AUAudioUnit` (`SpectrumAudioUnit`) copies each render pass (about 470 frames) into a ring buffer; the FFT runs when the view draws. The self-test counts how many of 30 readings, 17 ms apart, change.
Rule: for anything that must look live, do not use an engine tap; use a render-time unit or compute at draw time.

## The spectrum still looked slow after the audio unit
Symptom: the bars moved in slow steps. A draw counter (`APP_SPECTRUM_DEBUG=1`) showed the canvas drawing about 4 times a second, not 60.
Cause: the `Canvas` inside `TimelineView(.animation)` never read the timeline date, so SwiftUI saw an identical drawing and skipped the redraw. It only repainted when the 0.25 s clock of the parent display re-created it.
Fix: read `timeline.date` in the canvas; spring smoothing (`Spring(duration:bounce:)`, quick rise and slower fall) and peak caps.
Rule: measure the draw rate before tuning the data path. A Canvas in a TimelineView must use the timeline date.

## Crash when a track with a cover started playing
Symptom: SIGTRAP (`_dispatch_assert_queue_fail`) in `Player.updateNowPlaying` once artwork existed.
Cause: the `MPMediaItemArtwork` handler closure was created in main-actor code, but the system calls it from a background queue.
Fix: create it in a `nonisolated` helper.
Rule: any closure handed to a system framework that may call it off the main thread must be built in a `nonisolated` context.

## Added music folders were not shown
Symptom: after adding a folder, Settings > Library listed nothing, and the Library window had no list of folders.
Cause: the Settings scene had no `modelContainer`, so its `@Query` returned nothing; and the sidebar never listed folders.
Fix: attach `LibraryModel.shared.container` to the Settings scene; add a Folders section to the sidebar (a page per folder, with Rescan, Show in Finder, Remove) and select the new folder after adding it.
Rule: every scene that uses `@Query` needs `.modelContainer(...)`; Settings is its own scene.

## Radio could queue audio without limit; playhead cost 19% CPU
Symptom: playing a track used 20-30% CPU; a fast stream could grow memory. Cause: a 0.25 s TimelineView re-laid out the time label and seek bar; radio buffers were scheduled with no cap. Fix: 0.5 s playhead, 30 s cap on queued radio audio, http/https-only station URLs, mirror suffix check, undo and artwork cache limits, disk-space guard for recording (docs/SECURITY.md).
Rule: Measure CPU with a bisect (env switches) before guessing, and give every queue that a network can fill a limit.

## Equalizer drifted away from the player when dragging
Symptom: dragging the player, the docked equalizer ended up offset or left behind. Cause: the system sets the dragged window from the mouse and ignores our snap correction, so the move delta applied to docked windows included the snap jump and errors added up. Fix: remember each docked window's offset at the start of the drag and place it from the dragged window's final position.
Rule: Move a group from fixed offsets to the leader, never by accumulating deltas.

## Windowshade mode kept the full window height
Symptom: collapsing the player left an empty window of the same height. Cause: the player window became resizable (content minimum size), and such a window does not shrink by itself when its content does. Fix: `WindowSnapper.fitHeight` sets the window to the content height on every shade change, top edge fixed, and moves windows docked below.
Rule: A window that is resizable in one direction needs an explicit resize when its content size changes.
