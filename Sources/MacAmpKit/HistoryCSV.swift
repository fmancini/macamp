import Foundation

/// The play history as CSV: time, station, title. Quotes are doubled.
public enum HistoryCSV {
    public static func make(_ rows: [(Date, String, String)]) -> String {
        let formatter = ISO8601DateFormatter()
        func quote(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var out = "Time,Station,Title\n"
        for (time, station, title) in rows {
            out += "\(formatter.string(from: time)),\(quote(station)),\(quote(title))\n"
        }
        return out
    }
}
