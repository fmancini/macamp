import AppKit
import SwiftData
import SwiftUI

// MacAmp
//   MacAmp                      the app
//   APP_STORE=<file> MacAmp     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> MacAmp   save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 MacAmp           fill an empty Queue with sample tracks (tools/snap.sh)
//   MacAmp --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> MacAmp      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 MacAmp           draw the 8 pt grid and the layout probes over the window

@main
struct MacAmpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    @State private var player = Player.shared
    @Environment(\.openWindow) private var openWindow
    private var menuBar = MenuBarSettings.shared

    var body: some Scene {
        Window("MacAmp", id: "main") {
            PlayerView()
                .environment(model)
                .environment(player)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: Layout.playerWidth, height: Layout.playerHeight)
        .defaultLaunchBehavior(.presented)
        .commands { commands }

        Window("Equalizer", id: "equalizer") {
            EqualizerView()
                .environment(player)
                .themed()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: Layout.equalizerWidth, height: 200)

        Window("MacAmp Help", id: "help") {
            HelpView()
                .themed()
        }
        .defaultSize(width: 820, height: 560)

        Window("Library", id: "library") {
            LibraryWindow()
                .environment(model)
                .environment(player)
                .themed()
                .frame(minWidth: 640, minHeight: 400)
                .modelContainer(LibraryModel.shared.container)
        }
        .defaultSize(width: 880, height: 560)
        .defaultLaunchBehavior(.presented)
        .windowToolbarStyle(.unified)

        MenuBarExtra("MacAmp", systemImage: "waveform", isInserted: menuBar.binding) {
            MenuBarPlayer()
                .environment(player)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .themed()
                .modelContainer(LibraryModel.shared.container)
        }
        .windowResizability(.contentSize)
    }

    @CommandsBuilder
    private var commands: some Commands {
        SidebarCommands()
        ToolbarCommands()
        CommandGroup(replacing: .newItem) {
            Button("Open Files\u{2026}") { Player.chooseFiles { player.open($0) } }
                .keyboardShortcut("o")
        }
        CommandGroup(after: .newItem) {
            Button("Add Folder to Library\u{2026}") {
                LibraryPanels.chooseFolder { url in
                    Task {
                        await LibraryModel.shared.addFolder(url)
                        model.selection = .folder(url.standardizedFileURL.path)
                        openWindow(id: "library")
                    }
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Import Playlist\u{2026}") {
                LibraryPanels.choosePlaylist { url in
                    if let playlist = LibraryModel.shared.importPlaylist(from: url) {
                        model.selection = .playlist(playlist.uuid)
                        openWindow(id: "library")
                    }
                }
            }
        }
        CommandMenu("Playback") {
            Button(player.isPlaying ? LocalizedStringKey("Pause") : LocalizedStringKey("Play")) { player.togglePlay() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!player.canPlay)
            Button("Stop") { player.stop() }
                .keyboardShortcut(".")
                .disabled(!player.canPlay)
            Button(player.isRecording ? LocalizedStringKey("Stop Recording") : LocalizedStringKey("Record Station")) { player.toggleRecording() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!player.canRecord && !player.isRecording)
            Divider()
            Button("Next") { player.next() }
                .keyboardShortcut(.rightArrow)
                .disabled(!player.hasTracks)
            Button("Previous") { player.previous() }
                .keyboardShortcut(.leftArrow)
                .disabled(!player.hasTracks)
            Divider()
            Button("Seek Forward 5 Seconds") { player.seek(by: 5) }
                .keyboardShortcut(.rightArrow, modifiers: .option)
                .disabled(!player.hasTracks)
            Button("Seek Back 5 Seconds") { player.seek(by: -5) }
                .keyboardShortcut(.leftArrow, modifiers: .option)
                .disabled(!player.hasTracks)
            Button("Volume Up") { player.adjustVolume(by: 0.1) }
                .keyboardShortcut(.upArrow, modifiers: .option)
            Button("Volume Down") { player.adjustVolume(by: -0.1) }
                .keyboardShortcut(.downArrow, modifiers: .option)
            Divider()
            Toggle("Shuffle", isOn: Binding(get: { player.queue.shuffle }, set: { _ in player.toggleShuffle() }))
                .keyboardShortcut("s")
            Button("Repeat: \(player.queue.repeatMode.label)") { player.cycleRepeat() }
                .keyboardShortcut("r")
        }
        CommandGroup(replacing: .help) {
            Button("MacAmp Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
        }
        CommandMenu("Radio") {
            Button("Browse Stations") { model.sidebar = .radio; openWindow(id: "library") }
            Button("Favorites") { model.sidebar = .favorites; openWindow(id: "library") }
            Button("History") { model.sidebar = .history; openWindow(id: "library") }
            Divider()
            Button(player.isRecording ? LocalizedStringKey("Stop Recording") : LocalizedStringKey("Record Station")) { player.toggleRecording() }
                .disabled(!player.canRecord && !player.isRecording)
            Button("Show Recordings in Finder") { NSWorkspace.shared.open(Player.recordingsFolder) }
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show Library") { model.sidebar = .library; openWindow(id: "library") }
                .keyboardShortcut("1")
            Button("Show Queue") { model.sidebar = .queue; openWindow(id: "library") }
                .keyboardShortcut("l")
            Button(PlayerWindowState.shared.shade ? LocalizedStringKey("Show Full Player") : LocalizedStringKey("Windowshade Mode")) {
                PlayerWindowState.shared.shade.toggle()
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
            Button("Show Equalizer") { openWindow(id: "equalizer") }
                .keyboardShortcut("e")
            Button("Show Radio") { model.sidebar = .radio; openWindow(id: "library") }
                .keyboardShortcut("2")
            Button("Show Player") { openWindow(id: "main") }
                .keyboardShortcut("0")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Started from a terminal, the process is not a foreground app yet.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        AppearanceStore.shared.apply()
        GlobalShortcuts.shared.registerAll()
        // Test modes start here, so they do not depend on a window being on screen.
        Task { @MainActor in
            SeedData.insertIfRequested(player: Player.shared)
            SelfTest.runIfRequested(player: Player.shared)
            // Bring the Library in step with the disk at launch.
            if !Store.isOverridden { await LibraryModel.shared.syncAll() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

/// Where the data lives: ~/Library/Application Support/MacAmp/
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    /// Settings and volume. Test and snapshot runs never touch the real ones.
    static var defaults: UserDefaults {
        isOverridden ? (UserDefaults(suiteName: "com.felipemancini.macamp.test") ?? .standard) : .standard
    }

    static var directory: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        let dir = URL.applicationSupportDirectory.appending(path: "MacAmp", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var queueURL: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path + ".queue.json")
        }
        return directory.appending(path: "queue.json")
    }
}

extension Store {
    static var databaseURL: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return directory.appending(path: "MacAmp.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: LibraryTrack.self, LibraryFolder.self, Playlist.self, FavoriteStation.self, PlayedTitle.self,
                                      configurations: ModelConfiguration(url: databaseURL))
        } catch {
            fatalError("Could not open the database at \(databaseURL.path): \(error)")
        }
    }
}
