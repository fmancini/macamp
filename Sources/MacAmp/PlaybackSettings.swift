import SwiftUI
import MacAmpKit

/// Settings > Playback: ReplayGain.
struct PlaybackSettings: View {
    @AppStorage("replaygain.mode", store: Store.defaults) private var mode = "track"
    @AppStorage("replaygain.preamp", store: Store.defaults) private var preamp = 0.0
    @AppStorage("replaygain.limit", store: Store.defaults) private var limit = true

    var body: some View {
        Section {
            Picker("Level tracks", selection: $mode) {
                Text("Off").tag("off")
                Text("By track").tag("track")
                Text("By album").tag("album")
            }
            .pickerStyle(.segmented)
            LabeledContent("Extra gain") {
                HStack {
                    Slider(value: $preamp, in: -6...6, step: 0.5)
                        .frame(width: 160) // grid: ok
                    Text("\(preamp, specifier: "%+.1f") dB").monospacedDigit().frame(width: 60, alignment: .trailing) // grid: ok
                }
            }
            .disabled(mode == "off")
            Toggle("Prevent clipping", isOn: $limit)
                .disabled(mode == "off")
        } header: {
            Text("ReplayGain")
        } footer: {
            Text("Plays tracks at similar loudness using the gain tags in your files. Tracks without tags play at normal volume. Tags in MP3 and M4A files are read; FLAC and Ogg tags are not yet.")
        }
    }
}
