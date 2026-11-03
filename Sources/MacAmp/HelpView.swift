import MacAmpKit
import SwiftUI

/// The Help window: topics on the left, the text on the right. The text is
/// Help.md in the app's language (Localization/<lang>.lproj).
struct HelpView: View {
    @State private var topics = HelpView.load()
    @State private var selection: String?
    @State private var query = ""

    private var visible: [HelpDocument.Topic] {
        guard !query.isEmpty else { return topics }
        return topics.filter { $0.title.localizedStandardContains(query) || $0.plainText.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationSplitView {
            List(visible, selection: $selection) { topic in
                Text(topic.title).tag(topic.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            if let topic = topics.first(where: { $0.id == selection }) ?? visible.first {
                ScrollView {
                    TopicView(topic: topic)
                        .padding(Space.xxl)
                        .frame(maxWidth: 640, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .navigationTitle(topic.title)
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, prompt: "Search Help")
        .frame(minWidth: 640, minHeight: 400)
        .onAppear { if selection == nil { selection = topics.first?.id } }
        .onChange(of: query) { selection = visible.first?.id }
    }

    /// Help.md for the current language, falling back to English.
    static func load() -> [HelpDocument.Topic] {
        guard let url = Bundle.main.url(forResource: "Help", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return HelpDocument.parse(text)
    }
}

private struct TopicView: View {
    let topic: HelpDocument.Topic

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(topic.title).font(.title2.weight(.semibold))
            ForEach(Array(topic.blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let text):
                    rich(text)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                        Text("\u{2022}").foregroundStyle(.secondary)
                        rich(text)
                    }
                    .padding(.leading, Space.sm)
                case .step(let number, let text):
                    HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                        Text("\(number).").foregroundStyle(.secondary).monospacedDigit().frame(width: 20, alignment: .trailing) // grid: ok
                        rich(text)
                    }
                }
            }
        }
        .textSelection(.enabled)
    }

    /// Text with **bold** and `code` rendered.
    private func rich(_ text: String) -> some View {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return Text((try? AttributedString(markdown: text, options: options)) ?? AttributedString(text))
            .fixedSize(horizontal: false, vertical: true)
    }
}
