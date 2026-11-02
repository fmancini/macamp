# Market, reviews and features

Research for WAMP (Winamp-style local player with playlists and internet radio for Mac). Done 2026-11-02.
[V] verified in a source, [K] from knowledge, [U] unverified, test first.

Evidence is thinner than planned: Reddit was blocked, and no Reddit, Hacker News or Mac App Store review text was found. Several [V] tags rest on search snippets only (marked "snippet").

## Findings

| App | Price | Platform | Headline features |
| --- | --- | --- | --- |
| Swinsian 3 | $34.95, trial [V](https://swinsian.com/) (one review says $24.95, older: use the vendor page) | Mac, native Apple Silicon [V](https://x-cmd.com/blog/250822) | Column browser, tag editing with regex, duplicates, smart playlists, 10/31-band EQ, gapless, ReplayGain, cue, mini window, global shortcuts. No radio listed [V] |
| Doppler | $30, trial [V](https://brushedtype.co/doppler/) | Mac 11+, iPhone | Album-focused UI, artwork search, Wi-Fi/USB/AirDrop import and iPhone sync. No radio found [U] |
| Vox | Free; Premium $4.99/mo or $49.99/yr; Radio IAP $9.99 [V](https://apps.apple.com/us/app/vox-mp3-flac-music-player/id461369673) | Mac 10.15+ | FLAC/APE/DSD, M3U/PLS/XSPF/CUE, EQ, crossfade, gapless, Last.fm, 30,000+ radio stations and AirPlay (paid) |
| Cog | Free, open source [V](https://cog.losno.co) | Mac 12+ | Streams, HLS, Shoutcast/Icecast metadata, gapless, CUE, ReplayGain, EQ, spectrum. No library management [V](https://alternativeto.net/software/cog/about) |
| foobar2000 (Mac) | Free for personal use [K, Mac build unverified] | Mac 11+ [V](https://www.foobar2000.org/mac) | Components. Radio not mentioned |
| Plexamp | Free basic, Plex Pass for more [U] | Mac desktop | Needs a Plex server [K] |
| Triode (radio) | $19.99 once or $9.99/yr [V](https://www.macstories.net/?p=61609) | Mac | 31 curated stations, search, manual URL, menu bar, global shortcuts, AirPlay 2. Recording not mentioned [V] |
| Radiola, RadioBar | Free [V snippet](https://www.ifun.de/radiola-10-freier-radioplayer-jetzt-mit-hotkeys-und-export-267856/) | Mac | Menu bar radio |
| Winamp | No official modern Mac app [U] | | Mac clones: re:AMP (free, 2020), MacWamp (proof of concept) [V snippet]. Check dates |

Note: the Reviews track said Vox, Cog and others have no radio [K]. The Market track found Vox sells radio and Cog plays Shoutcast/Icecast streams [V]. Trust the [V] listings.

## Likes and dislikes

| App | People like | People dislike | Sources |
| --- | --- | --- | --- |
| Swinsian | Speed with large libraries; deep tagging (multiple artists/genres), duplicates, mini window; Last.fm and iOS transfer | No dark mode or themes (newer versions may differ [U]); metadata not auto-updated; paid, "complex" | [anymp4](https://www.anymp4.com/player/swinsian-review.html), [softpedia](https://mac.softpedia.com/get/Audio/Swinsian.shtml) |
| Doppler | Album/artist UI, native feel; fast import and iPhone transfer; artwork search | Artwork search fails on bad metadata; heavy CPU on large imports; basic feature set; Apple Music import came late | [macstories](https://www.macstories.net/reviews/doppler-for-mac-offers-an-excellent-album-and-artist-focused-listening-experience-for-your-owned-music-collection/), [9to5mac](https://9to5mac.com/2022/09/01/doppler-hifi-music-player-mac-import-library/) |
| Vox | Gapless, crossfade, EQ, FLAC; minimal floating window, media keys; drag and drop | Subscription lock-ins; large libraries slow or crash (2.0-era, may be outdated [U]); redesign complaints; App Store reports of EQ and lockup bugs (snippet) | [tidbits](https://tidbits.com/?p=14488), [alternativeto](https://www.alternativeto.net/software/vox/about/) |
| Cog | Free, no ads, revived; very wide formats; hotkeys, gapless, EQ, menu bar spectrum | No library; playing one file means building a playlist; ~10 years unmaintained before revival; dated UI [K] | [ifun](https://www.ifun.de/download-befehl-cog-fuer-macos-bleibt-ein-starker-mp3-player-250552/) |
| Winamp seekers | Simple "just plays"; Milkdrop, 10-band EQ, M3U, drag and drop; nostalgia | No skins or themes on Mac; nothing feels as good; small mini-player [U] | [cdm.link](https://cdm.link/winamp-for-mac/), [macrumors](https://forums.macrumors.com/threads/best-mac-audio-player.532272/) |
| foobar2000 | Fast scanning, tiny installer, good lossless output | Fewer plugins than Windows; plain UI; beta-era bugs [U] | [sspai](https://sspai.com/post/54115) |
| Plexamp | Music-focused UI | Weak queue/playlist editing; library navigation gaps; limited offline; needs Plex server | [plex forum](https://forums.plex.tv/t/plexamp-requests-suggestions/581711.md) |
| Radiola | Menu bar, one-click search and save, global pause hotkey, bigger buffer, play history; under 2 MB | UI only DE/EN/IT; older builds Intel only | [ifun](https://www.ifun.de/radiola-10-freier-radioplayer-jetzt-mit-hotkeys-und-export-267856/) |

Patterns:
- Must have (repeats): gapless, EQ, wide formats, media keys, mini window, fast large-library browsing, global hotkeys.
- Our chance (repeats): no Winamp feel or skins on Mac; weak playlist/queue editing; subscription lock-ins; radio paywalled (Vox) or separate from the local player; slow or missing library.

## Feature matrix

| Feature | Winamp | Swinsian | Cog | Vox | Triode | Version one? |
| --- | --- | --- | --- | --- | --- | --- |
| MP3/AAC/FLAC/ALAC/WAV/AIFF | yes | yes | yes | yes | n/a | Yes |
| OGG/Opus | yes | yes | yes | yes | n/a | Decide (needs a decoder) |
| Playlists M3U/M3U8/PLS | yes [K] | not listed | yes | yes | n/a | Yes |
| Drag-reorder queue/playlist | yes | yes | partial | yes | n/a | Yes |
| 10-band EQ + preamp | yes [K] | yes | yes | yes | no | Yes |
| Gapless | yes | yes | yes | yes | n/a | Yes |
| ReplayGain | yes | yes | yes | n/a | n/a | Yes |
| Mini/windowshade mode | yes [K] | yes | no | yes | menu bar | Yes |
| Skins (.wsz) | yes | no | no | no | no | No (own theme in v1, .wsz later) |
| Visualizer | plugins | no | spectrum | no | no | Simple spectrum/oscilloscope |
| Library + tag editing | yes | yes | no | basic | no | Basic library, folder watching |
| Internet radio | yes (directory) | no | streams only | paid | yes | Yes, free |
| Station directory | Shoutcast | no | no | yes (paid) | curated + Radio Browser [V weak] | Radio Browser only |
| ICY now-playing | yes | no | yes | n/a | yes | Yes |
| Stream recording | no | no | no | no | not mentioned | v1.1 differentiator [U] |
| Media keys / global hotkeys | n/a | yes | yes | yes | yes | Yes |
| Menu bar control | no | no | yes | yes | yes | Yes |

## Decisions
1. Position as "Winamp feel with radio included, no subscription". Because no Mac app combines a skinned Winamp-style UI with free radio; re:AMP and MacWamp look unmaintained [V snippet]. Planned test: check both repos' last commit dates.
2. Radio is free in the core app. Because Vox charges $9.99 for it and Radiola is free [V].
3. Use Radio Browser as the only directory in v1, plus manual URLs and M3U/PLS import. Because it is free, documented, and returns resolved URLs [V](https://de1.api.radio-browser.info/). Defer SHOUTcast (needs key) and Icecast directory (uncertain).
4. Own the stream pipeline (URLSession + ICY parser), so titles, EQ, spectrum and recording work on radio. Because Cog-style AVPlayer metadata is inconsistent [K]. Planned test: see platform.md.
5. v1 core: gapless, 10-band EQ, M3U/PLS, queue editing, mini mode, media keys, simple spectrum. Because these repeat across all peers' praised items.
6. Defer .wsz skin compatibility and MilkDrop plugins; ship one or two own themes with dark mode. Because skins are the stated gap but a large effort [U]; Swinsian lacks dark mode.
7. Pricing is undecided. Peers: Swinsian $34.95, Doppler $30, Cog and radio apps free. Decide in app-brief.
8. Fast library scan and auto metadata/artwork lookup are quality bars. Because Vox is slow on large libraries and Doppler's artwork search fails on bad tags [V].

## Open questions
- Does Swinsian 3 now have dark mode and a stated macOS minimum? Check its changelog.
- Does any Mac radio app record streams? Absence of evidence only [U]; test Triode, Radiola, Radium directly.
- Radium's current price and status; myTuner price [U].
- Apple Music Radio is free without subscription [V](https://www.apple.com/apple-music/); recording it is out of scope.
- Legal exposure of stream recording [U].
