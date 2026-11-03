# MacAmp Help

## Getting Started
MacAmp plays your music files and internet radio, in the spirit of Winamp. It opens two windows: the **Player** (a small window with the display, spectrum, and controls) and the **Library** (your music, the Queue, playlists, and radio).

1. Press ⌘O and choose some audio files, or drop files on the Player. The first one starts playing.
2. To fill the Library, press ⇧⌘O and choose a folder with your music. MacAmp reads it and keeps watching it for changes.
3. For radio, open Radio in the Library window (⌘2), search for a station, and double-click it.

## Playing Music
- Press Space to play or pause. Use the buttons in the Player for previous, play, stop, and next.
- Drag the position bar to move around a track, or press ⌥← and ⌥→ to jump 5 seconds.
- Change the volume with the slider, or press ⌥↑ and ⌥↓.
- Shuffle (⌘S) plays every track once in random order. Repeat (⌘R) cycles through Off, All, and One.
- Previous (⌘←) goes back one track. If the track has played for more than 3 seconds, it restarts the track instead.
- Tracks of the same album play without a gap between them.
- MacAmp plays MP3, AAC, ALAC, FLAC, WAV, and AIFF files. Ogg and Opus files are not supported.

## The Queue
The Queue is the list of tracks that play now and next. Open it with ⌘L.

- Drag tracks to reorder them. Press Delete to remove the selected ones.
- Double-click a track to play it.
- Drop files on the Queue to add them at the end.
- Press ⌘Z to undo a change to the Queue.
- Use "Save as Playlist…" to keep the Queue as a playlist, or the trash button to clear it.

## The Library
The Library shows all the music in the folders you added. Open it with ⌘1.

- Add a folder with the folder button or ⇧⌘O. Each folder also appears in the sidebar under Folders, with Rescan, Show in Finder, and Remove from Library.
- New files in a folder appear on their own. Files you delete stay in the list, dimmed, until you use "Remove Missing Tracks…".
- Narrow the list with the Genre, Artist, and Album columns, or type in the search field.
- Click a column heading to sort. Right-click the headings to choose which columns show.
- Double-click a track to play it. The Queue becomes the list you see, starting from that track.
- The inspector (⌥⌘I) shows the details and album art of the selected tracks. Tags can be read but not edited.
- "Find Duplicates…" lists tracks with the same title, artist, and length. You can remove them from the Library or move the files to the Trash.

## Playlists
- Create a playlist with "New Playlist" at the bottom of the sidebar, or with "Save as Playlist…" in the Queue.
- Drag tracks from the Library onto a playlist in the sidebar, or use Add to Playlist in the right-click menu.
- Open a playlist to reorder or remove its tracks. Double-click to play it.
- File > Import Playlist… reads M3U, M3U8, and PLS files. The Export button saves a playlist as M3U or PLS.

## Internet Radio
MacAmp finds stations in the free Radio Browser directory (radio-browser.info).

- Radio > Browse (⌘2) lists the most listened stations. Type to search, and choose whether to search by name, country, language, or tag.
- Double-click a station to play it. The Player shows the station name and the song title the station reports.
- Click the star to keep a station in Favorites.
- In Favorites, "Add Station…" adds a station by its address. A .pls or .m3u link works too.
- History keeps the last 500 song titles. You can export it as CSV or clear it.
- If the connection drops, MacAmp tries to reconnect up to 5 times.
- MP3 and AAC stations play through the equalizer. Other kinds (HLS) play with a simpler player: no equalizer, no spectrum, and no recording.

## Recording Radio
- While a station plays, press the red record button in the Player (or ⇧⌘R). Press it again to stop.
- Recordings are saved as they arrive, without re-encoding, in the Music folder under "MacAmp Recordings". Change the folder in Settings > Radio.
- With "Start a new file for each song" on, a new file begins every time the song title changes, named after the song. The first file may be partial.
- You are responsible for using recordings legally.

## Equalizer and Spectrum
- Open the equalizer with ⌘E. It has a preamp and 10 bands from 60 Hz to 16 kHz, from -12 to +12 dB. Choose a preset, or drag the sliders.
- The equalizer works on your files and on MP3 and AAC stations. Turn it off with the On checkbox.
- The spectrum in the Player display moves with the music. With Reduce Motion on, it stays still.

## Player Windows
- The Player, the equalizer, and the Library are separate windows. The Player, the equalizer, and the Library snap to each other when you drag them close, and move together while they touch. Drag the left or right edge of the Player to make it wider; a docked equalizer follows its width.
- Press ⌥⌘M (or the small button on the display) to shrink the Player to a thin bar. Press it again to bring it back.
- The menu bar item shows what is playing and has transport buttons and a volume slider. Turn it on or off in Settings > Appearance.
- Settings > Appearance also sets light or dark mode, the Player theme (Classic or Mac), the accent color, and the language.

## Keyboard Shortcuts
- ⌘O: Open Files. ⇧⌘O: Add Folder to Library.
- Space: Play or Pause. ⌘.: Stop. ⌘→ and ⌘←: Next and Previous.
- ⌥→ and ⌥←: Seek 5 seconds. ⌥↑ and ⌥↓: Volume.
- ⌘S: Shuffle. ⌘R: Repeat. ⇧⌘R: Record Station.
- ⌘0: Player. ⌘1: Library. ⌘2: Radio. ⌘L: Queue. ⌘E: Equalizer. ⌥⌘M: Windowshade mode. ⌥⌘I: Inspector.
- Global shortcuts work while another app is in front: ⌃⌥Space plays or pauses, ⌃⌥→ goes to the next track, and ⌃⌥← to the previous one. Change them in Settings > Shortcuts. The keyboard media keys work too.

## Settings
Open Settings with ⌘,.

- Library: the folders MacAmp reads.
- Playback: ReplayGain, which plays tracks at similar loudness using the gain tags in MP3 and M4A files.
- Radio: the stream buffer (a larger one survives a weak connection better) and where recordings go.
- Shortcuts: the global keys.
- Appearance: mode, theme, accent color, menu bar item, and language. The language changes the next time MacAmp opens.

## Troubleshooting
- No sound: check the volume slider and the output device in System Settings. If you switch headphones or speakers while playing, MacAmp reconnects on its own.
- A track is dimmed with a warning: its file was moved or deleted. Use "Remove Missing Tracks…" in the Library to clean up.
- A station does not play: some stations are offline. Try another one, or add the station again by its address.
- The shortcut says "In use by another app": choose a different combination in Settings > Shortcuts.
- Not supported: Ogg Vorbis and Opus files, editing tags, and ReplayGain tags in FLAC and Ogg files.
