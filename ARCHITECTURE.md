# MacAmp architecture

Targets (Package.swift):
- `MacAmpKit`: pure logic, no SwiftUI or audio. `Track`, `QueueState` (order, shuffle, repeat, next/previous), `QueueStore` (JSON). Tested in `Tests/MacAmpKitTests`.
- `MacAmp`: the app, main-actor by default. Depends on `MacAmpKit`.

Layers in `Sources/MacAmp`:
- `Player.swift`: the audio engine (AVAudioEngine + one AVAudioPlayerNode), gapless scheduling, Queue editing with undo, tag reading, Now Playing and media keys. `Player.shared` is the one instance; the app, menus, and test modes use it.
- Views: `PlayerView` (player window), `LibraryWindow` + `QueuePage` (Library window), `SettingsView`. Colors, radii, motion in `UI/` (see design/DESIGN-SYSTEM.md).
- Radio: `Player+Radio.swift` plays a `Station` through the same engine. `RadioStream` (URLSession, asks for ICY metadata) -> `ICYStreamParser` (Kit) -> `StreamDecoder` (AudioFileStream + AVAudioConverter) -> PCM buffers -> the player node. HLS and other types fall back to AVPlayer. `RadioBrowser` finds stations (mirrors by DNS, User-Agent, click count).
- Library: `Library/` holds the SwiftData models (`LibraryTrack`, `LibraryFolder`, `Playlist`, `FavoriteStation`, `PlayedTitle`), the scanner, an FSEvents watcher, and `LibraryModel.shared`.
- Audio chain: player node -> `EqualizerModel` (10 bands + preamp, saved) -> mixer (volume). A spectrum tap on the equalizer output feeds `SpectrumAnalyzer`; both taps are `nonisolated` and share data through locks. AVPlayer-fallback streams skip the chain.
- Windows: player (with a thin windowshade mode), `EqualizerView`, Library window, menu bar popover (`MenuBarPlayer`). `WindowSnapper` docks the player and equalizer (geometry in Kit `WindowSnap`). `GlobalShortcuts` uses Carbon hot keys.
- Rule: a scene binding must write only when the value changes, or SwiftUI re-evaluates the app in a loop (see `MenuBarSettings`).
- Test modes: `SelfTest.swift` and `Snapshot.swift`. Both start from `AppDelegate` or the first window and refuse to run without `APP_STORE` in /tmp, which also mutes output and isolates settings (`Store.defaults`).

Dependency direction: views -> Player -> MacAmpKit. Kit never imports the app.

Rules:
- Code that runs on the audio thread (taps, render callbacks) is `nonisolated` and shares data through a lock (`PeakStore`).
- Pure logic goes in `MacAmpKit` with a test.
- Seam still to make: `AudioSource` (file, stream). Radio currently lives in an extension of `Player`; extract it when a third source (recording, AirPlay) arrives.
