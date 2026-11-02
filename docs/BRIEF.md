# MacAmp

A free Winamp-style music player for Mac that plays local files, manages playlists, and streams internet radio, for someone who misses Winamp and does not want a subscription. Bundle id: `com.felipemancini.macamp`. Project folder: `/Users/felipemancini/dev/os-wamp`.

## Replaces
Winamp on Windows. On Mac: Cog (no library), Swinsian ($34.95, no radio), Vox (radio is paid).

## Main jobs
1. Play local music with a queue, playlists, a 10-band equalizer and gapless playback.
2. Listen to internet radio (Radio Browser, favorites, manual URLs) with song titles, and record it.
3. Keep a fast library of music folders, with search, column browser and tag editing.

## Data
- Track: file path, title, artist, album, genre, year, track number, duration, artwork, ReplayGain.
- Playlist: name, ordered tracks (local files and stations).
- Station: name, stream URL, country, codec, bitrate, favorite flag.
- Play history: station, title, time (up to 500 entries).

## Shape
Windows, not one big window: main player, equalizer and playlist windows that snap together (Winamp style), with a windowshade mini mode. Plus a menu bar player and global shortcuts. macOS 26 or later. Local data, offline for local files. The internet is used only for radio (Radio Browser API, stream URLs). No accounts.

## System hooks
Media keys and Now Playing (MPRemoteCommandCenter), global shortcuts (no Accessibility permission), menu bar item (`MenuBarExtra`), security-scoped folder access, plain `http://` radio via ATS exception.

## Reference
Swinsian for library, tags and playlists (from public pages, no screenshots: docs/screens/INDEX.md). Classic Winamp for the window set, mini mode and equalizer. Triode and Radiola for radio.

## Look
Own look, Winamp-inspired (compact, dense, spectrum in the main window), two built-in themes, each with light and dark. No `.wsz` skins in v1. Accent: decide in design-system. Interface in English and Spanish (String Catalog).

## Decisions
- Price: free, no ads, no subscription. Radio included (decided by the user).
- OGG Vorbis and Opus: in version one with a decoder library (decided by the user). Story S-044 moves to M1-M2 priority.
- Languages: English and Spanish (decided by the user).
- Engine: AVAudioEngine for files; own URLSession plus ICY reader for radio, so EQ, spectrum and recording work on streams (decided by the agent from research).

## Not in version one
- `.wsz` skin compatibility and MilkDrop plugins.
- Smart playlists, art grid, find and replace, cue sheets, 31-band EQ.
- Podcasts, AirPlay, Last.fm, iOS companion, Apple Music import, sync.
- SHOUTcast and Icecast directories (Radio Browser only).
