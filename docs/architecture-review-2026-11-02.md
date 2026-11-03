# Architecture review, end of M1 (2026-11-02)

Survey: 2,297 lines in Sources, 10 Kit tests, 26 self-test checks. Largest file: `Player.swift` (514 lines). No file over 600 lines, no god model, no drifted copies. The code is small and mostly fine. Nothing here is `Strong`, so no refactor was done.

## Player does five jobs  [Worth exploring]

Files: Sources/MacAmp/Player.swift (514 lines)
Signal: nearest to the 600-line limit; M2 and M3 add to it (S-017 playlist play, S-021 radio play).
Problem: engine control, gapless scheduling, Queue editing with undo, tag reading, and Now Playing / media keys share one class. A radio stream in M3 needs a second source behind the same transport.
Proposal: move Now Playing and remote commands into `NowPlaying.swift` (takes a `Player`'s state), and tag reading into `TrackMetadata.swift` (a plain async function, already `nonisolated`). Keep engine and scheduling in `Player`. When radio arrives, introduce a small `AudioSource` seam (file, stream) with two adapters.
Benefits: Player drops under 400 lines; tag reading is reused by the Library scan (S-010) with no Player dependency.
Proof of same behavior: the 26 self-test checks and 10 Kit tests.
Plan: one commit for `TrackMetadata` (do it as part of S-010, which needs it anyway), one for `NowPlaying`, one for the `AudioSource` seam at the start of M3.

## Queue and Library will both hold tracks  [Worth exploring]

Files: Sources/MacAmpKit/Track.swift, QueueState.swift; M2 adds a SwiftData Library.
Signal: before a big feature.
Problem: the Queue stores full `Track` values in JSON. A Library `Track` in SwiftData would be a second copy with its own title/artist, and tag edits (S-019) would not reach the Queue.
Proposal: keep the Queue as plain values (it needs pure-logic tests), but add a Library id to `Track` (`libraryID: UUID?`) and refresh queue entries from the Library after a tag edit or scan. Library tracks are the source of truth; Queue tracks are references plus a cached title.
Benefits: one place changes on a tag edit; Queue logic stays testable without SwiftData.
Proof of same behavior: Kit queue tests stay as they are; add a test for refresh.
Plan: decide in S-010 (model), implement with S-019.

## Engine scheduling is not testable without audio hardware  [Speculative]

Files: Player.swift (`scheduleNext`, `segmentFinished`)
Problem: gapless hand-off logic needs a real engine, so only the self-test covers it.
Proposal: none yet. Revisit if a bug appears in this area twice.

## Top recommendation

None is Strong. Do the `TrackMetadata` extraction inside S-010, and settle the Queue/Library id question there. Write `ARCHITECTURE.md` now (done in this check-in).

## Considered, not recommended
- Moving `Store` into its own file: 40 lines, no pain.
- Making the player a protocol for tests: one conformer, no second adapter yet.
- Splitting `AppearanceSettings.swift` (183 lines): it is a Settings page and sits with its feature.

## End of M6 update
- `Player.swift` passed 600 lines after M5 (661). Moved Now Playing, media keys, artwork, and ReplayGain into `Player+NowPlaying.swift` (565 lines left, no behavior change; 59 self-test checks and 37 unit tests pass before and after).
- Still open: the `AudioSource` seam (file, stream). Radio lives in `Player+Radio.swift`; extract it only when a third source appears.
- The Library window's `LibraryPage` (about 250 lines) is the largest view; fine for now.
