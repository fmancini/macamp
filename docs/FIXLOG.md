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
