# Platform: macOS APIs for WAMP

Research for WAMP. Done 2026-11-02.
[V] verified in a source, [K] from knowledge, [U] unverified, test first.

Only two web searches backed this track. Almost everything is [K] or [U] and needs a prototype.

## Findings

| Topic | Finding | Tag |
| --- | --- | --- |
| Decoders | AVFoundation decodes MP3, AAC, ALAC, FLAC, WAV, AIFF natively | [K] |
| OGG/Opus | Not native. Needs libvorbis/libopus or ffmpeg (LGPL); decode to PCM into AVAudioEngine | [K] |
| Engine choice | AVAudioEngine: EQ (AVAudioUnitEQ), taps, PCM, but AVAudioFile reads local files only. AVPlayer: HTTP streaming, ICY, but no PCM without MTAudioProcessingTap and no AVAudioUnitEQ | [K] |
| Gapless | Schedule next AVAudioFile on AVAudioPlayerNode before the current ends. Same format is gapless. MP3 encoder padding: test whether AVAudioFile trims it | [K] / [U] |
| ICY protocol | Client sends `Icy-MetaData: 1`; server answers `icy-metaint`; every N bytes one length byte (x16) then `StreamTitle='...';` | [V](https://www.liquidsoap.info/doc-dev/icy_metadata.html) |
| AVPlayer ICY titles | Often exposed as timed metadata; inconsistent for HE-AAC, Ogg and servers without `icy-metaint` | [K] / [U] |
| ICY status line | Some servers answer `ICY 200 OK`; URLSession may reject it (maybe need NWConnection) | [U] |
| ATS | Plain `http://` streams blocked by default; `NSAllowsArbitraryLoadsForMedia` covers AVFoundation only; URLSession needs broader flag or per-domain exceptions; App Store review may ask why | [K] |
| Radio Browser | Discover servers by DNS on `all.api.radio-browser.info`, pick a random mirror, prefer HTTPS | [V](https://api.radio-browser.info) |
| Radio Browser etiquette | Descriptive User-Agent; call the click endpoint on play; `url_resolved` resolves M3U/PLS/ASX | [V](https://de1.api.radio-browser.info/) |
| Now Playing / media keys | MPRemoteCommandCenter and MPNowPlayingInfoCenter; with AVAudioEngine set nowPlayingInfo and playbackState yourself; no Accessibility permission | [K] / [U] |
| Sandbox | `network.client`, `files.user-selected.read-only`, security-scoped bookmarks for music folders (refresh stale ones) | [K] |
| Spectrum | `installTap` on the mixer, vDSP FFT, Hann window, 1024-2048 buffer, ~30 fps. With AVPlayer, MTAudioProcessingTap is harder and breaks on streams | [K] |
| Playlists | M3U (`#EXTINF`) and PLS (INI) are trivial; M3U8 may be HLS, hand to AVPlayer | [K] |
| Recording | With a custom pipeline write the raw pre-decode bytes, split on title change | [K] |
| Menu bar | SwiftUI `MenuBarExtra` (`.window` style), no permission | [K] |
| Global shortcuts | Carbon `RegisterEventHotKey` needs no permission; CGEventTap for media keys needs Accessibility/Input Monitoring; other players also claim media keys | [K] / [U] |

## Decisions
1. Hybrid engine: AVAudioEngine for local files; custom URLSession ICY pipeline decoding to PCM into the same engine for radio. Because EQ, spectrum and recording then work on streams. Fallback for v1: AVPlayer for streams without EQ/visualizer. Planned test: AVPlayer ICY titles on 10 real stations.
2. Use MPRemoteCommandCenter for media keys, not an event tap. Because it needs no permission. Planned test: confirm keys work with AVAudioEngine playing, and what happens when Music is also open.
3. Decide OGG/Opus scope: ship in v1 only if a decoder integrates in under a day; else v1.1. Because it is the only third-party dependency [K].
4. Allow `http://` streams via ATS exceptions, and plan an App Review justification. Planned test: a build with `NSAllowsArbitraryLoadsForMedia` plus URLSession on an http station.
5. Menu bar mini player with `MenuBarExtra` plus a windowshade main window. Because Radiola, Triode and Vox users value menu bar control [V, see market-and-reviews.md].

## Open questions
- Does URLSession accept an `ICY 200 OK` response? Test against an Icecast/SHOUTcast station; fall back to NWConnection.
- Does AVAudioFile trim MP3 encoder padding for gapless? Test with a known gapless album.
- Does the sandbox allow everything needed for stream recording to a user-chosen folder?
- Legal and ToS exposure of recording [U].
