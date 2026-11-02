import Foundation

/// Splits a SHOUTcast/Icecast stream into audio bytes and song titles.
/// The client asks for metadata with `Icy-MetaData: 1`; the server answers
/// with `icy-metaint`. After every `metaInterval` audio bytes comes one length
/// byte (times 16) and then that many bytes of text like `StreamTitle='Song';`.
public struct ICYStreamParser: Sendable {
    private enum State: Sendable {
        case audio(remaining: Int)
        case length
        case metadata(remaining: Int)
    }

    private let metaInterval: Int
    private var state: State
    private var block = Data()

    /// `metaInterval` 0 means the stream has no metadata: everything is audio.
    public init(metaInterval: Int) {
        self.metaInterval = max(0, metaInterval)
        state = .audio(remaining: max(0, metaInterval))
    }

    /// Feeds the next chunk of the stream. Chunks may split anywhere.
    public mutating func feed(_ data: Data) -> (audio: Data, titles: [String]) {
        guard metaInterval > 0 else { return (data, []) }
        var audio = Data()
        var titles: [String] = []
        var index = data.startIndex
        while index < data.endIndex {
            switch state {
            case .audio(let remaining):
                let take = min(remaining, data.endIndex - index)
                audio.append(data[index..<(index + take)])
                index += take
                state = take == remaining ? .length : .audio(remaining: remaining - take)
            case .length:
                let size = Int(data[index]) * 16
                index += 1
                block = Data()
                state = size == 0 ? .audio(remaining: metaInterval) : .metadata(remaining: size)
            case .metadata(let remaining):
                let take = min(remaining, data.endIndex - index)
                block.append(data[index..<(index + take)])
                index += take
                if take == remaining {
                    if let title = Self.title(in: block) { titles.append(title) }
                    state = .audio(remaining: metaInterval)
                } else {
                    state = .metadata(remaining: remaining - take)
                }
            }
        }
        return (audio, titles)
    }

    /// The text between `StreamTitle='` and the closing `';`. Empty titles are nil.
    static func title(in block: Data) -> String? {
        let text = String(data: block, encoding: .utf8) ?? String(data: block, encoding: .isoLatin1) ?? ""
        guard let start = text.range(of: "StreamTitle='") else { return nil }
        let rest = text[start.upperBound...]
        // The title may contain apostrophes: it ends at the first "';" that is
        // followed by the end of the block or by another field like StreamUrl='.
        var end = rest.endIndex
        var search = rest.startIndex
        while let close = rest.range(of: "';", range: search..<rest.endIndex) {
            let after = rest[close.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))
            if after.isEmpty || after.range(of: #"^\w+='"#, options: .regularExpression) != nil {
                end = close.lowerBound
                break
            }
            search = close.upperBound
        }
        let title = rest[..<end].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0")))
        return title.isEmpty ? nil : title
    }
}
