import AppKit
import IOKit.pwr_mgt
import MacAmpKit
import SwiftUI

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots ~/Applications/MacAmp.app/Contents/MacOS/MacAmp
/// writes <page>-light.png and <page>-dark.png for every sidebar page, and
/// settings-<tab>-light.png and settings-<tab>-dark.png for every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=library,queue,player limits the pages. Add "settings" to include Settings.
/// Add APP_ACCENT=<id> to see the pages in another accent.
enum Snapshot {
    static func runIfRequested(model: AppModel, player: Player, openSettings: OpenSettingsAction, openWindow: OpenWindowAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            openWindow(id: "library")
            // Show a track part-way through, paused, so the player has content.
            if let id = player.queue.currentID, player.queue.tracks.count > 1 {
                player.playTrack(player.queue.tracks[min(2, player.queue.tracks.count - 1)].id)
                try? await Task.sleep(for: .seconds(0.4))
                player.seek(to: player.duration * 0.4)
                player.pause()
                _ = id
            }
            try? await Task.sleep(for: .seconds(0.8))
            let playerWindow = NSApp.windows.first { $0.title == "MacAmp" && $0.canBecomeMain }
            let library = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet && $0.title != "MacAmp"
                && (SidebarItem.allCases.map(\.title) + ["Library"]).contains($0.title) }
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                for page in SidebarItem.allCases where only?.contains(page.rawValue) ?? true {
                    model.sidebar = page
                    // Browse loads stations from the internet.
                    try? await Task.sleep(for: .seconds(page == .radio ? 4 : 0.8))
                    capture(to: "\(dir)/\(page.rawValue)-\(mode).png", window: library)
                    if page == SidebarItem.allCases.first, only?.contains("player") ?? true {
                        capture(to: "\(dir)/player-\(mode).png", window: playerWindow)
                    }
                }
            }
            // The equalizer, the thin player bar, and the Mac theme.
            if only?.contains("player") ?? true {
                openWindow(id: "equalizer")
                try? await Task.sleep(for: .seconds(1))
                let equalizer = NSApp.windows.first { $0.title == String(localized: "Equalizer") }
                player.equalizer.state.apply(EqualizerPreset.all[1])
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    try? await Task.sleep(for: .seconds(0.6))
                    capture(to: "\(dir)/equalizer-\(mode).png", window: equalizer)
                    PlayerWindowState.shared.shade = true
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/shade-\(mode).png", window: playerWindow)
                    PlayerWindowState.shared.shade = false
                    PlayerThemeStore.shared.theme = .mac
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/mac-player-\(mode).png", window: playerWindow)
                    capture(to: "\(dir)/mac-equalizer-\(mode).png", window: equalizer)
                    PlayerThemeStore.shared.theme = .classic
                }
                player.equalizer.state = EqualizerState()
            }
            // The About panel with the credits.
            if only?.contains("player") ?? true {
                NSApp.orderFrontStandardAboutPanel(nil)
                try? await Task.sleep(for: .seconds(1))
                if let about = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) && $0.frame.width < 500
                    && $0.title != "MacAmp" && $0.title != String(localized: "Equalizer") && $0.title != "Menu Bar" }) {
                    capture(to: "\(dir)/about.png", window: about)
                    about.close()
                }
            }
            // The menu bar popover, in a plain window.
            if only?.contains("player") ?? true {
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    let host = NSHostingController(rootView: MenuBarPlayer().environment(player).themed())
                    let popover = NSWindow(contentViewController: host)
                    popover.title = "Menu Bar"
                    popover.setContentSize(host.view.fittingSize)
                    popover.center()
                    popover.makeKeyAndOrderFront(nil)
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/menubar-\(mode).png", window: popover)
                    popover.close()
                }
            }
            // A folder page.
            if only?.contains("folder") ?? true, let folder = LibraryModel.shared.folders.first {
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    model.selection = .folder(folder.path)
                    try? await Task.sleep(for: .seconds(0.8))
                    let title = URL(fileURLWithPath: folder.path).lastPathComponent
                    capture(to: "\(dir)/folder-\(mode).png", window: NSApp.windows.first { $0.canBecomeMain && $0.title == title })
                }
            }
            // A playlist page, once per appearance.
            if only?.contains("playlist") ?? true, let playlist = LibraryModel.shared.playlists.first {
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    model.selection = .playlist(playlist.uuid)
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/playlist-\(mode).png", window: NSApp.windows.first { $0.canBecomeMain && $0.title == playlist.name })
                }
            }
            if only == nil || only?.contains("settings") == true {
                let main = library
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        let titles = SettingsTab.allCases.map(\.title)
                        let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet && titles.contains($0.title) }
                        capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settings)
                    }
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    private static func capture(to path: String, window: NSWindow? = nil) {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, sidebars and glass are blank)")
        }
    }
}
