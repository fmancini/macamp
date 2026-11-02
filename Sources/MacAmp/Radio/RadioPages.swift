import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import MacAmpKit

/// Radio > Browse: search the Radio Browser directory.
struct RadioPage: View {
    @Environment(Player.self) private var player
    @Query private var favorites: [FavoriteStation]
    @State private var query = ""
    @State private var field = RadioBrowserSearch.name
    @State private var results: [Station] = []
    @State private var loading = false
    @State private var failed = false
    @State private var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(results) { station in
                StationRow(station: station, isCurrent: player.station?.id == station.id, isPlaying: player.isPlaying,
                           isFavorite: favorites.contains { $0.stationID == station.id },
                           toggleFavorite: { toggle(station) })
                    .tag(station.id)
            }
        }
        .contextMenu(forSelectionType: String.self) { _ in } primaryAction: { ids in
            if let id = ids.first, let station = results.first(where: { $0.id == id }) { player.playStation(station) }
        }
        .overlay { state }
        .searchable(text: $query, prompt: "Search \(field.title)")
        .task(id: "\(field.rawValue):\(query)") { await search() }
        .navigationTitle("Radio")
        .navigationSubtitle(results.isEmpty ? "" : "\(results.count) stations")
        .toolbar {
            ToolbarItem {
                Picker("Search by", selection: $field) {
                    ForEach(RadioBrowserSearch.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Choose what to search by")
            }
        }
    }

    @ViewBuilder
    private var state: some View {
        if loading && results.isEmpty {
            ProgressView("Loading stations\u{2026}")
        } else if failed {
            ContentUnavailableView {
                Label("Can't reach the station list", systemImage: "wifi.slash")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try Again") { Task { await search() } }
            }
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        }
    }

    private func search() async {
        // Wait a moment so typing does not search on every key.
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        loading = true
        defer { loading = false }
        do {
            results = try await RadioBrowser.search(query, by: field)
            failed = false
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    private func toggle(_ station: Station) {
        let context = LibraryModel.shared.context
        if let existing = favorites.first(where: { $0.stationID == station.id }) {
            context.delete(existing)
        } else {
            context.insert(FavoriteStation(station))
        }
        try? context.save()
    }
}

/// Radio > Favorites: saved stations, plus stations added by address.
struct FavoritesPage: View {
    @Environment(Player.self) private var player
    @Query(sort: \FavoriteStation.addedAt) private var favorites: [FavoriteStation]
    @State private var adding = false
    @State private var selection: Set<String> = []

    var body: some View {
        List(selection: $selection) {
            ForEach(favorites) { favorite in
                StationRow(station: favorite.station, isCurrent: player.station?.id == favorite.stationID,
                           isPlaying: player.isPlaying, isFavorite: true, toggleFavorite: { remove([favorite.stationID]) })
                    .tag(favorite.stationID)
            }
            .onDelete { offsets in remove(offsets.map { favorites[$0].stationID }) }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if !ids.isEmpty { Button("Remove from Favorites") { remove(ids) } }
        } primaryAction: { ids in
            if let id = ids.first, let favorite = favorites.first(where: { $0.stationID == id }) { player.playStation(favorite.station) }
        }
        .onDeleteCommand { remove(selection); selection = [] }
        .overlay {
            if favorites.isEmpty {
                ContentUnavailableView {
                    Label("No Favorite Stations", systemImage: "star")
                } description: {
                    Text("Star a station in Browse, or add one by its address.")
                } actions: {
                    Button("Add Station\u{2026}") { adding = true }
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationSubtitle(favorites.isEmpty ? "" : "\(favorites.count) stations")
        .toolbar {
            ToolbarItem {
                Button("Add Station\u{2026}", systemImage: "plus") { adding = true }
                    .help("Add a station by its stream address")
            }
        }
        .sheet(isPresented: $adding) { AddStationSheet() }
    }

    private func remove(_ ids: some Collection<String>) {
        let context = LibraryModel.shared.context
        for favorite in favorites where ids.contains(favorite.stationID) { context.delete(favorite) }
        try? context.save()
    }
}

/// Add Station: a name and a stream address (a .pls or .m3u link is fine).
struct AddStationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Address", text: $address, prompt: Text("https://\u{2026}"))
            if let error { Text(error).font(.caption).foregroundStyle(Surface.warning) }
        }
        .formStyle(.grouped)
        .navigationTitle("Add Station")
        .frame(width: 420)
        .fitsContent()
        .noInitialFocus()
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") { Task { await add() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || working)
            }
            .padding(Space.lg)
        }
    }

    private func add() async {
        working = true
        defer { working = false }
        guard let resolved = await StreamResolver.resolve(address) else {
            error = "Can't play this address. Use an http or https stream, or a .pls or .m3u link."
            return
        }
        let title = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let host = URL(string: resolved)?.host ?? "Station"
        let context = LibraryModel.shared.context
        context.insert(FavoriteStation(Station(name: title.isEmpty ? host : title, url: resolved)))
        try? context.save()
        dismiss()
    }
}

/// Radio > History: the song titles heard on stations.
struct HistoryPage: View {
    @Query(sort: \PlayedTitle.playedAt, order: .reverse) private var titles: [PlayedTitle]
    @State private var confirmClear = false

    var body: some View {
        List(titles) { entry in
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.title).lineLimit(1)
                    Text(entry.stationName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: Space.sm)
                Text(entry.playedAt, format: .dateTime.day().month().hour().minute())
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .overlay {
            if titles.isEmpty {
                ContentUnavailableView("Nothing Played Yet", systemImage: "clock",
                                       description: Text("Song titles from stations show up here."))
            }
        }
        .navigationTitle("History")
        .navigationSubtitle(titles.isEmpty ? "" : "\(titles.count) titles")
        .toolbar {
            ToolbarItem {
                Button("Export CSV\u{2026}", systemImage: "square.and.arrow.up") { exportCSV() }
                    .help("Save the history as a CSV file")
                    .disabled(titles.isEmpty)
            }
            ToolbarItem {
                Button("Clear History", systemImage: "trash") { confirmClear = true }
                    .help("Remove every title from the history")
                    .disabled(titles.isEmpty)
            }
        }
        .confirmationDialog("Clear \(titles.count) Titles?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) {
                let context = LibraryModel.shared.context
                for entry in titles { context.delete(entry) }
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacAmp History.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? HistoryCSV.make(titles.map { ($0.playedAt, $0.stationName, $0.title) }).write(to: url, atomically: true, encoding: .utf8)
    }
}
