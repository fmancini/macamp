import Foundation
import MacAmpKit

/// The Radio Browser directory (radio-browser.info): free, with no account.
/// Rules from its docs: find servers by DNS, send a descriptive User-Agent,
/// and report a click when a station starts.
nonisolated enum RadioBrowser {
    private static let fallbackMirrors = ["de1.api.radio-browser.info", "de2.api.radio-browser.info", "nl1.api.radio-browser.info"]
    private static let userAgent = "MacAmp/0.1 (macOS internet radio player)"
    private static let cache = MirrorCache()

    /// Server names behind `all.api.radio-browser.info`, found by reverse DNS.
    static func discoverMirrors() -> [String] {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_STREAM, ai_protocol: 0,
                             ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo("all.api.radio-browser.info", nil, &hints, &result) == 0, let first = result else {
            return fallbackMirrors
        }
        defer { freeaddrinfo(result) }
        var names: [String] = []
        var node: UnsafeMutablePointer<addrinfo>? = first
        while let current = node {
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if let address = current.pointee.ai_addr,
               getnameinfo(address, current.pointee.ai_addrlen, &host, socklen_t(host.count), nil, 0, NI_NAMEREQD) == 0 {
                let name = String(cString: host)
                if name.hasSuffix(".radio-browser.info"), !names.contains(name) { names.append(name) }
            }
            node = current.pointee.ai_next
        }
        return names.isEmpty ? fallbackMirrors : names
    }

    private static func mirrors() -> [String] {
        if let known = cache.value { return known.shuffled() }
        let found = discoverMirrors()
        cache.value = found
        return found.shuffled()
    }

    /// Searches stations, most listened first. An empty query lists the top stations.
    @concurrent
    static func search(_ query: String, by field: RadioBrowserSearch, limit: Int = 60) async throws -> [Station] {
        var items = [URLQueryItem(name: "hidebroken", value: "true"), URLQueryItem(name: "order", value: "clickcount"),
                     URLQueryItem(name: "reverse", value: "true"), URLQueryItem(name: "limit", value: String(limit))]
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { items.append(URLQueryItem(name: field.rawValue, value: text)) }
        let data = try await get("/json/stations/search", items: items)
        let stations = try JSONDecoder().decode([RadioBrowserStation].self, from: data).map(\.station)
        return stations.filter { !$0.url.isEmpty }
    }

    /// Tells the directory a station was played (it uses this to rank stations).
    @concurrent
    static func countClick(_ station: Station) async {
        guard UUID(uuidString: station.id) != nil else { return }
        _ = try? await get("/json/url/\(station.id)", items: [])
    }

    private static func get(_ path: String, items: [URLQueryItem]) async throws -> Data {
        var lastError: Error = URLError(.cannotFindHost)
        for host in mirrors() {
            var parts = URLComponents()
            parts.scheme = "https"
            parts.host = host
            parts.path = path
            parts.queryItems = items.isEmpty ? nil : items
            guard let url = parts.url else { continue }
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 200 { return data }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private final class MirrorCache: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [String]?
        var value: [String]? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }
}

/// Turns the address a person pastes into the address of a stream: a .pls or
/// .m3u playlist is read and its first address is used.
nonisolated enum StreamResolver {
    @concurrent
    static func resolve(_ text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return nil }
        let ext = url.pathExtension.lowercased()
        guard ext == "pls" || ext == "m3u" else { return trimmed }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let body = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return nil }
        return PlaylistFile.parse(body).first(where: \.isStream)?.location
    }
}
