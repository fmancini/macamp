import Foundation

/// The help text, split into topics. Written in a small Markdown subset:
/// `## Title` starts a topic, `- ` is a bullet, `1. ` is a numbered step,
/// anything else is a paragraph (blank lines separate paragraphs). Inline
/// **bold** and `code` are left for the view to render.
public enum HelpDocument {
    public enum Block: Equatable, Sendable {
        case paragraph(String)
        case bullet(String)
        case step(Int, String)
    }

    public struct Topic: Identifiable, Equatable, Sendable {
        public var id: String { title }
        public let title: String
        public let blocks: [Block]

        /// All the topic's text, for searching.
        public var plainText: String {
            blocks.map { block in
                switch block {
                case .paragraph(let text), .bullet(let text), .step(_, let text): text
                }
            }.joined(separator: " ")
        }
    }

    public static func parse(_ text: String) -> [Topic] {
        var topics: [Topic] = []
        var title: String?
        var blocks: [Block] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
        }
        func flushTopic() {
            flushParagraph()
            if let title { topics.append(Topic(title: title, blocks: blocks)) }
            blocks = []
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flushTopic()
                title = String(line.dropFirst(3))
            } else if line.isEmpty {
                flushParagraph()
            } else if line.hasPrefix("- ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else if let dot = line.firstIndex(of: "."), let number = Int(line[..<dot]), line[line.index(after: dot)...].hasPrefix(" ") {
                flushParagraph()
                blocks.append(.step(number, line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)))
            } else if !line.hasPrefix("# ") && title != nil {
                paragraph.append(line)
            }
        }
        flushTopic()
        return topics
    }
}
