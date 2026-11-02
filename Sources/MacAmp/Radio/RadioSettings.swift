import SwiftUI

/// Settings > Radio.
struct RadioSettings: View {
    @AppStorage("radio.buffer") private var buffer = "normal"

    var body: some View {
        Section {
            Picker("Buffer", selection: $buffer) {
                Text("Small").tag("small")
                Text("Normal").tag("normal")
                Text("Large").tag("large")
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Streaming")
        } footer: {
            Text("A larger buffer waits a few seconds longer to start but survives a weak connection better.")
        }
    }
}
