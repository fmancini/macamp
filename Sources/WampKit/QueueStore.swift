import Foundation

/// Saves and loads the Queue as JSON, so it survives a restart.
public enum QueueStore {
    public static func save(_ queue: QueueState, to url: URL) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) -> QueueState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(QueueState.self, from: data)
    }
}
