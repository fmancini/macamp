import AppKit
import AVFoundation
import SwiftData
import MacAmpKit

/// Self-test for agents: runs the app's real functions on test files,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/MacAmp-self.store ~/Applications/MacAmp.app/Contents/MacOS/MacAmp --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
/// Output is muted (the player's volume is 0 whenever APP_STORE is set).
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0
    nonisolated(unsafe) private static var activity: NSObjectProtocol?

    static func runIfRequested(player: Player) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        // Keep App Nap from throttling timers while nothing is on screen.
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Self-test")
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let dir = URL.cachesDirectory.appending(path: "macamp-selftest", directoryHint: .isDirectory)
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let a = silence(dir.appending(path: "a.wav"), seconds: 8, rate: 44_100)
            let b = silence(dir.appending(path: "b.wav"), seconds: 8, rate: 44_100)
            let c = silence(dir.appending(path: "c.wav"), seconds: 8, rate: 48_000)
            let bad = dir.appending(path: "broken.mp3")
            try? Data("not audio".utf8).write(to: bad)

            // Real audio must flow: a system sound, measured at the player node.
            player.open([URL(fileURLWithPath: "/System/Library/Sounds/Hero.aiff")])
            try? await Task.sleep(for: .seconds(0.5))
            let peak = player.takePeak()
            check("samples reach the output (not silence)", peak > 0.01, "peak \(peak)")
            player.clearQueue()

            // S-001 open files and play
            player.open([a, b, c])
            check("Open Files adds three tracks to the Queue", player.queue.tracks.count == 3)
            check("the first track plays", player.isPlaying && player.current?.path == a.path)
            try? await Task.sleep(for: .seconds(0.6))
            check("elapsed time advances while playing", player.elapsed > 0.2, "elapsed \(player.elapsed)")
            check("duration is read from the file", abs(player.duration - 8) < 0.1, "duration \(player.duration)")

            // S-002 transport
            player.togglePlay()
            let held = player.elapsed
            try? await Task.sleep(for: .seconds(0.4))
            check("Pause holds the position", !player.isPlaying && abs(player.elapsed - held) < 0.05)
            player.togglePlay()
            check("Play resumes", player.isPlaying)

            // S-003 seek
            player.seek(to: 5)
            check("Seek moves playback to the chosen time", abs(player.elapsed - 5) < 0.4, "elapsed \(player.elapsed)")
            player.volume = 0.5
            check("Volume is saved", Store.defaults.float(forKey: "player.volume") == 0.5)

            // S-002 next and previous
            player.next()
            check("Next goes to the second track", player.current?.path == b.path)
            try? await Task.sleep(for: .seconds(0.4))
            player.previous()
            check("Previous within 3 seconds goes back one track", player.current?.path == a.path)
            player.seek(to: 5)
            player.previous()
            check("Previous after 3 seconds restarts the track", player.current?.path == a.path && player.elapsed < 1)

            // S-006 gapless: the next same-format track is scheduled ahead
            check("the next track is scheduled ahead (gapless)", player.nextScheduled)
            player.seek(to: 7.4)
            try? await Task.sleep(for: .seconds(1.2))
            check("the Queue moves on by itself at the end of a track", player.current?.path == b.path && player.isPlaying)

            // S-005 repeat and shuffle
            player.cycleRepeat()
            check("Repeat cycles to All", player.queue.repeatMode == .all)
            player.cycleRepeat()
            player.cycleRepeat()
            check("Repeat cycles back to Off", player.queue.repeatMode == .off)
            player.toggleShuffle()
            check("Shuffle turns on", player.queue.shuffle)
            player.toggleShuffle()

            // S-004 queue editing
            player.move(from: IndexSet(integer: 0), to: 3)
            check("drag reorder changes the order", player.queue.tracks.map(\.path) == [b.path, c.path, a.path])
            check("reordering keeps the current track", player.current?.path == b.path)
            player.remove(ids: [player.queue.tracks[2].id])
            check("Remove from Queue removes the track", player.queue.tracks.count == 2)

            // S-001 a file that cannot be decoded
            player.open([bad], play: false)
            if let id = player.queue.tracks.last?.id { player.playTrack(id) }
            try? await Task.sleep(for: .seconds(0.3))
            check("an undecodable file is marked unavailable", player.message != nil && !player.unavailable.isEmpty)

            // S-008 restore
            let saved = player.queue
            QueueStore.save(saved, to: dir.appending(path: "queue.json"))
            check("the Queue survives a save and load", QueueStore.load(from: dir.appending(path: "queue.json")) == saved)

            // S-030 equalizer and S-031 spectrum, measured on a 440 Hz tone
            let tone = sine(dir.appending(path: "tone.wav"), seconds: 8)
            player.open([tone])
            try? await Task.sleep(for: .seconds(0.8))
            let loud = player.spectrum.bars.max() ?? 0
            check("the spectrum shows the tone while playing", loud > 0.2, "max bar \(loud)")
            // The bars must change at the display rate, not once per audio block (about 100 ms).
            player.clearQueue()
            player.open([noise(dir.appending(path: "noise.wav"), seconds: 8)])
            try? await Task.sleep(for: .seconds(0.6))
            var distinct = 0
            var last = player.spectrum.bars
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(17))
                let now = player.spectrum.bars
                if now != last { distinct += 1 }
                last = now
            }
            print("  tap block: \(player.spectrum.lastBlockFrames) frames")
            check("the spectrum updates on nearly every frame", distinct >= 24, "\(distinct) of 30 readings changed")
            player.clearQueue()
            player.open([tone])
            try? await Task.sleep(for: .seconds(0.8))
            player.equalizer.state.preamp = -12
            try? await Task.sleep(for: .seconds(0.6))
            let quiet = player.spectrum.bars.max() ?? 0
            check("the preamp changes the sound", loud - quiet > 0.08, "\(loud) -> \(quiet)")
            player.equalizer.state.enabled = false
            try? await Task.sleep(for: .seconds(0.6))
            check("turning the equalizer off restores it", (player.spectrum.bars.max() ?? 0) > quiet + 0.08)
            player.equalizer.state.enabled = true
            player.equalizer.state.apply(EqualizerPreset.all[1])
            check("equalizer settings are saved", EqualizerModel().state == player.equalizer.state)
            player.equalizer.state = EqualizerState()
            player.clearQueue()

            // S-010 and S-011 Library folders
            let music = dir.appending(path: "Music/Album", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: music, withIntermediateDirectories: true)
            let l1 = silence(music.appending(path: "one.wav"), seconds: 2, rate: 44_100)
            _ = silence(music.appending(path: "two.wav"), seconds: 3, rate: 44_100)
            _ = silence(music.appending(path: "three.wav"), seconds: 4, rate: 44_100)
            try? Data("notes".utf8).write(to: music.appending(path: "notes.txt"))
            let library = LibraryModel.shared
            await library.addFolder(dir.appending(path: "Music"))
            check("an added folder is listed", library.folders.map(\.path).contains { $0.hasSuffix("macamp-selftest/Music") })
            check("a scanned folder adds its audio files", library.trackCount == 3, "count \(library.trackCount)")
            let scannedTracks = (try? library.context.fetch(FetchDescriptor<LibraryTrack>())) ?? []
            check("tags and duration are read", scannedTracks.contains { abs($0.duration - 3) < 0.1 })
            try? FileManager.default.removeItem(at: l1)
            await library.syncAll()
            let gone = ((try? library.context.fetch(FetchDescriptor<LibraryTrack>())) ?? []).filter { !$0.isAvailable }
            check("a deleted file is marked unavailable, not dropped", gone.count == 1 && library.trackCount == 3)
            _ = silence(music.appending(path: "four.wav"), seconds: 2, rate: 44_100)
            var waited = 0.0
            while library.trackCount < 4, waited < 12 {
                try? await Task.sleep(for: .seconds(0.5))
                waited += 0.5
            }
            check("a new file in a watched folder appears on its own", library.trackCount == 4, "count \(library.trackCount) after \(waited) s")

            // Missing tracks can be removed from the Library
            let missingBefore = library.trackCount
            check("a deleted file still has its entry until it is removed", ((try? library.context.fetch(FetchDescriptor<LibraryTrack>())) ?? []).filter { !$0.isAvailable }.count == 1)
            let removedCount = library.removeMissing()
            check("Remove Missing Tracks removes only the deleted files", removedCount == 1 && library.trackCount == missingBefore - 1,
                  "removed \(removedCount), \(missingBefore) -> \(library.trackCount)")
            check("no missing tracks are left", ((try? library.context.fetch(FetchDescriptor<LibraryTrack>())) ?? []).allSatisfy(\.isAvailable))

            // S-015, S-016, S-017 playlists
            let roadTrip = library.createPlaylist(name: "  Road   trip ", items: player.queue.tracks.map(\.path))
            check("a playlist is roadTrip from the Queue", roadTrip.name == "Road trip" && roadTrip.items.count == player.queue.tracks.count)
            library.add([l1.path], to: roadTrip)
            check("tracks can be added to a playlist", roadTrip.items.last == l1.path)
            let m3u = dir.appending(path: "list.m3u")
            library.exportPlaylist(roadTrip, as: .m3u, to: m3u)
            let imported = library.importPlaylist(from: m3u)
            check("an exported M3U imports as the same playlist", imported?.items == roadTrip.items)
            let pls = dir.appending(path: "list.pls")
            library.exportPlaylist(roadTrip, as: .pls, to: pls)
            check("an exported PLS imports as the same playlist", library.importPlaylist(from: pls)?.items == roadTrip.items)
            check("playable tracks of a playlist come from files", library.tracks(of: roadTrip).count == roadTrip.items.count)
            library.deletePlaylist(roadTrip)
            check("a playlist can be deleted", !library.playlists.contains { $0.uuid == roadTrip.uuid })

            // S-040 and S-041 recording, from synthetic stream pieces
            let recFolder = dir.appending(path: "rec", directoryHint: .isDirectory)
            let recorder = StreamRecorder(folder: recFolder, stationName: "Test FM", fileExtension: "mp3", splitByTitle: true, currentTitle: nil)
            let partA = Data(repeating: 0xA1, count: 500), partB = Data(repeating: 0xB2, count: 700), partC = Data(repeating: 0xC3, count: 300)
            recorder.write(partA)
            recorder.title("Artist / One")
            recorder.write(partB)
            recorder.title("Two")
            recorder.write(partC)
            recorder.title("Two")   // the same title again must not cut a file
            recorder.finish()
            let recorded = recorder.savedFiles
            check("a title change starts a new file", recorded.count == 3, "\(recorded.map(\.lastPathComponent))")
            check("recordings are raw bytes, cut where the title changes",
                  recorded.count == 3 && (try? Data(contentsOf: recorded[0])) == partA && (try? Data(contentsOf: recorded[1])) == partB
                  && (try? Data(contentsOf: recorded[2])) == partC)
            check("file names come from the title and are safe", recorded.count == 3 && recorded[1].lastPathComponent == "Artist - One.mp3"
                  && recorded[2].lastPathComponent == "Two.mp3")

            // S-020, S-021, S-022 radio (needs the internet; skipped when offline)
            if let jazz = try? await RadioBrowser.search("jazz", by: .name), !jazz.isEmpty {
                check("a station search returns stations", jazz.count > 5, "\(jazz.count) results")
                let candidates = jazz.filter { $0.codec.uppercased() == "MP3" && !$0.isHLS }.prefix(3)
                var played = false
                for station in candidates where !played {
                    played = await tryStation(station, player: player)
                }
                check("an MP3 station plays real audio", played, "tried \(candidates.map(\.name))")
                // S-040: record a real station for a few seconds, then play the file.
                if let first = candidates.first {
                    player.playStation(first)
                    var waited = 0.0
                    while !player.radioNodeStarted, waited < 25 { try? await Task.sleep(for: .seconds(0.5)); waited += 0.5 }
                    player.toggleRecording(folder: dir.appending(path: "live", directoryHint: .isDirectory))
                    check("Record starts on a playing station", player.isRecording)
                    try? await Task.sleep(for: .seconds(8))
                    player.stopRecording()
                    let files = player.lastRecording
                    let size = files.compactMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int }.reduce(0, +)
                    check("a recording of a real station has audio in it", size > 40_000, "\(files.count) files, \(size) bytes")
                    player.stopRadio(clearStation: true)
                    if let biggest = files.max(by: { ((try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int) ?? 0) < ((try? FileManager.default.attributesOfItem(atPath: $1.path)[.size] as? Int) ?? 0) }) {
                        _ = player.takePeak()
                        player.open([biggest])
                        try? await Task.sleep(for: .seconds(1.2))
                        check("the recorded file plays in MacAmp", player.isPlaying && player.takePeak() > 0.001)
                        player.clearQueue()
                    }
                }
                if let more = try? await RadioBrowser.search("news", by: .name) {
                    let aacList = more.filter { $0.codec.uppercased().hasPrefix("AAC") && !$0.isHLS }.prefix(3)
                    var aacPlayed = false
                    for station in aacList where !aacPlayed { aacPlayed = await tryStation(station, player: player) }
                    check("an AAC station plays real audio", aacList.isEmpty || aacPlayed, "tried \(aacList.map(\.name))")
                }
                if let first = candidates.first {
                    player.playStation(first)
                    try? await Task.sleep(for: .seconds(2))
                    player.stop()
                    check("Stop disconnects the station and keeps it selected", !player.isPlaying && player.station?.id == first.id)
                    player.togglePlay()
                    check("Play reconnects the station", player.isPlaying && player.isLive)
                    player.stopRadio(clearStation: true)
                }
            } else {
                print("SKIP radio checks: the directory is not reachable")
            }

            // S-036 global shortcuts
            GlobalShortcuts.shared.registerAll(force: true)
            check("the global shortcuts register without a conflict", GlobalShortcuts.shared.conflicts.isEmpty,
                  "\(GlobalShortcuts.shared.conflicts)")
            GlobalShortcuts.shared.unregisterAll()
            player.open([tone], play: false)
            GlobalShortcuts.fire(GlobalShortcuts.Action.playPause.rawValue)
            check("the Play / Pause shortcut starts playback", player.isPlaying,
                  "queue \(player.queue.tracks.count), file \(player.file != nil), station \(player.station != nil), message \(player.message ?? "-")")
            GlobalShortcuts.fire(GlobalShortcuts.Action.playPause.rawValue)
            check("the Play / Pause shortcut pauses playback", !player.isPlaying)
            player.clearQueue()

            // S-043 artwork next to a file, and S-042 ReplayGain without tags
            let artFolder = dir.appending(path: "Art", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: artFolder, withIntermediateDirectories: true)
            let withArt = silence(artFolder.appending(path: "song.wav"), seconds: 2, rate: 44_100)
            let cover = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
            try? cover?.representation(using: .png, properties: [:])?.write(to: artFolder.appending(path: "cover.png"))
            let foundArt = await ArtworkLoader.image(forPath: withArt.path)
            check("cover.png next to a file is used as its artwork", foundArt != nil)
            check("a file without any artwork has none", await ArtworkLoader.image(forPath: dir.appending(path: "a.wav").path) == nil)
            player.open([withArt])
            try? await Task.sleep(for: .seconds(0.6))
            check("the player shows the artwork of the current track", player.artwork != nil)
            check("a track without ReplayGain tags plays at full volume", player.node.volume == 1)
            player.clearQueue()

            // S-054 Spanish
            if let path = Bundle.main.path(forResource: "es", ofType: "lproj"), let es = Bundle(path: path) {
                func spanish(_ key: String) -> String { es.localizedString(forKey: key, value: nil, table: nil) }
                check("the Spanish strings are in the app", spanish("Library") == "Biblioteca" && spanish("Queue") == "Cola"
                      && spanish("Play") == "Reproducir")
                let plural = es.localizedString(forKey: "%lld tracks", value: nil, table: nil)
                check("Spanish counts use the right plural", String.localizedStringWithFormat(plural, 1) == "1 pista"
                      && String.localizedStringWithFormat(plural, 3) == "3 pistas", plural)
            } else {
                check("the Spanish strings are in the app", false, "no es.lproj in the app bundle")
            }

            // S-055 light and dark
            AppearanceStore.shared.mode = .dark
            check("Dark mode applies to the app", NSApp.appearance?.name == .darkAqua)
            AppearanceStore.shared.mode = .light
            check("Light mode applies to the app", NSApp.appearance?.name == .aqua)
            AppearanceStore.shared.mode = .system
            check("System mode follows the Mac", NSApp.appearance == nil)

            player.clearQueue()
            check("Clear Queue empties the Queue", player.queue.isEmpty && !player.isPlaying)
            try? FileManager.default.removeItem(at: dir)

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// Plays a station and waits for real samples (up to 25 seconds).
    private static func tryStation(_ station: Station, player: Player) async -> Bool {
        _ = player.takePeak()
        player.playStation(station)
        var waited = 0.0
        while !player.radioNodeStarted, waited < 25 {
            try? await Task.sleep(for: .seconds(0.5))
            waited += 0.5
        }
        try? await Task.sleep(for: .seconds(1.5))
        let peak = player.takePeak()
        print("  station \(station.name) [\(station.codec)]: started \(player.radioNodeStarted), peak \(peak), title \(player.streamTitle ?? "-")")
        let ok = player.radioNodeStarted && peak > 0.001
        player.stopRadio(clearStation: true)
        return ok
    }

    /// White noise, for tests.
    private static func noise(_ url: URL, seconds: Double) -> URL {
        let rate = 44_100.0
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: false)!
        let frames = AVAudioFrameCount(seconds * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<2 {
            let data = buffer.floatChannelData![channel]
            for i in 0..<Int(frames) { data[i] = Float.random(in: -0.4...0.4) }
        }
        if let file = try? AVAudioFile(forWriting: url, settings: format.settings) { try? file.write(from: buffer) }
        return url
    }

    /// A 440 Hz tone, for tests.
    private static func sine(_ url: URL, seconds: Double) -> URL {
        let rate = 44_100.0
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: false)!
        let frames = AVAudioFrameCount(seconds * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<2 {
            let data = buffer.floatChannelData![channel]
            for i in 0..<Int(frames) { data[i] = 0.5 * sinf(2 * .pi * 440 * Float(i) / Float(rate)) }
        }
        if let file = try? AVAudioFile(forWriting: url, settings: format.settings) { try? file.write(from: buffer) }
        return url
    }

    /// A silent WAV, for tests.
    private static func silence(_ url: URL, seconds: Double, rate: Double) -> URL {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: false)!
        let frames = AVAudioFrameCount(seconds * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        if let file = try? AVAudioFile(forWriting: url, settings: format.settings) { try? file.write(from: buffer) }
        return url
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
