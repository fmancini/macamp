import AppKit
import AVFoundation
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

    static func runIfRequested(player: Player) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let dir = FileManager.default.temporaryDirectory.appending(path: "macamp-selftest", directoryHint: .isDirectory)
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

            player.clearQueue()
            check("Clear Queue empties the Queue", player.queue.isEmpty && !player.isPlaying)
            try? FileManager.default.removeItem(at: dir)

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
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
