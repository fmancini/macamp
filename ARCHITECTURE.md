# MacAmp architecture

Targets (Package.swift):
- `MacAmpKit`: pure logic, no SwiftUI or audio. `Track`, `QueueState` (order, shuffle, repeat, next/previous), `QueueStore` (JSON). Tested in `Tests/MacAmpKitTests`.
- `MacAmp`: the app, main-actor by default. Depends on `MacAmpKit`.

Layers in `Sources/MacAmp`:
- `Player.swift`: the audio engine (AVAudioEngine + one AVAudioPlayerNode), gapless scheduling, Queue editing with undo, tag reading, Now Playing and media keys. `Player.shared` is the one instance; the app, menus, and test modes use it.
- Views: `PlayerView` (player window), `LibraryWindow` + `QueuePage` (Library window), `SettingsView`. Colors, radii, motion in `UI/` (see design/DESIGN-SYSTEM.md).
- Test modes: `SelfTest.swift` and `Snapshot.swift`. Both start from `AppDelegate` or the first window and refuse to run without `APP_STORE` in /tmp, which also mutes output and isolates settings (`Store.defaults`).

Dependency direction: views -> Player -> MacAmpKit. Kit never imports the app.

Rules:
- Code that runs on the audio thread (taps, render callbacks) is `nonisolated` and shares data through a lock (`PeakStore`).
- Pure logic goes in `MacAmpKit` with a test.
- Seams (not yet needed): `AudioSource` (file, stream) arrives with radio in M3.
