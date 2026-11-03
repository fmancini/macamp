# MacAmp stories

Backlog for MacAmp, a Winamp-style Mac player with playlists and free internet radio. Built 2026-11-02 from docs/research/*.md and docs/screens/INDEX.md. There is no docs/BRIEF.md yet, so price and OGG scope are open (see Open decisions).
Checks: [snap] snapshot, [unit] unit test, [self] self-test, [manual] a person must try it.
"Screens:" names sections of docs/screens/INDEX.md (Swinsian, no PNGs) or MacAmp snapshot pages to create.
Status: todo, doing, done, dropped.

## Open decisions
- Price: free, paid ($30-35 like Swinsian/Doppler), or free with paid extras. Decide in app-brief.
- Decided in BRIEF.md: free app, OGG/Opus in v1 (S-044), English and Spanish UI (add story S-054).

## M1 Core loop (play local files, queue survives restart)

### S-001 Open files and play one
As the user, I choose Open Files (Command-O) or drop audio files on the window, and the first one plays.
Screens: MacAmp snapshot page "main-playing"
Acceptance:
- [unit] MP3, AAC, ALAC, FLAC, WAV and AIFF files decode and play.
- [self] A file that cannot be decoded shows an error row, and the next track plays.
- [snap] The main window shows title, artist, elapsed time and total time.
UX:
- Flow: Command-O, File > Open Files…, or drop files on the window -> first track plays, all files join the Queue -> end: title and time appear in the main window. Way back: Command-Z removes the added tracks.
- Surface: system open panel (sheet on the main window); drag and drop needs none.
- States: empty "Drop audio files here, or press ⌘O" with "Open Files…"; error row "Can't play this file" with the reason ("Unsupported format" or "File not found"); loading none.
- Words: "Open Files…", "Add to Queue", tooltip none (no icon-only control).
- Access: Command-O opens the panel; the dropped-files area has the label "Audio files drop area".
Status: done

### S-002 Play, pause, stop, next, previous
As the user, I use transport buttons and the Space bar to control playback.
Screens: main-playing
Depends: S-001
Acceptance:
- [self] Space toggles play and pause when the window is focused.
- [unit] Previous after 3 seconds restarts the track; within 3 seconds it goes to the previous one.
- [snap] The play button shows its paused and playing states.
UX:
- Flow: transport buttons, Space, or menu Playback > Play/Pause -> state changes at once -> end: button shows the new state.
- Surface: inline (main window controls).
- States: nothing queued disables Play/Pause, Previous and Next.
- Words: tooltips "Play (Space)", "Pause (Space)", "Go to the next track (⌘→)", "Go to the previous track (⌘←)", "Stop playback (⌘.)".
- Access: all by keyboard; VoiceOver "Play", "Pause", "Next", "Previous".
Status: done

### S-003 Seek and volume
As the user, I drag a seek bar and a volume slider.
Screens: main-playing
Depends: S-001
Acceptance:
- [self] Dragging the seek bar moves playback to that time within 200 ms.
- [unit] Volume persists across restarts.
- [snap] The seek bar shows elapsed fill and a drag handle.
UX:
- Flow: drag the Seek bar or press ← / → for 5 s, ⌥← / ⌥→ for 30 s; drag the Volume slider or press ↑ / ↓ -> time label and sound change at once.
- Surface: inline.
- States: radio hides the Seek bar and shows "Live".
- Words: tooltips "Seek in this track", "Change the volume".
- Access: sliders expose value to VoiceOver ("Position 1:23 of 3:45", "Volume 70 percent").
Status: done

### S-004 Queue (current playlist) with drag-reorder
As the user, I see the queue in a list and drag tracks to reorder or press Delete to remove them.
Screens: 08-playlist-window (INDEX), snapshot page "queue"
Depends: S-001
Acceptance:
- [unit] Reordering changes play order without interrupting the current track.
- [self] Delete removes the selected rows, and Command-Z restores them.
- [snap] Rows show index, title, artist, duration; the playing row is highlighted.
UX:
- Flow: drop tracks on the Queue, drag rows to reorder, select + Delete to remove -> end: the list shows the new order. Way back: Command-Z.
- Surface: sidebar page / playlist area of the main window (a place people come back to); a separate Queue window is a later option.
- States: empty "The Queue is empty" with "Open Files…"; Unavailable tracks are dimmed with a warning icon and the tooltip "File not found".
- Words: "Remove from Queue", "Clear Queue" (confirmation "Remove 12 Tracks from the Queue?" with "Remove" and "Cancel", only for more than one track).
- Access: arrow keys move the selection, Return plays the selected track; VoiceOver reads "Track 3 of 12, title, artist, 3:45".
Status: done

### S-005 Shuffle and repeat
As the user, I toggle shuffle and repeat (off, all, one).
Depends: S-004
Acceptance:
- [unit] Shuffle plays every track once before repeating.
- [unit] Repeat one loops the current track.
- [snap] The buttons show the three repeat states.
UX:
- Flow: Shuffle and Repeat toggle buttons or Playback menu -> state shows on the button.
- Surface: inline.
- States: Repeat cycles Off, All, One with an icon and a word in the tooltip (not color alone).
- Words: tooltips "Play the Queue in random order (⌘S)", "Repeat: Off. Click to repeat all".
- Access: VoiceOver reads the current state.
Status: done

### S-006 Gapless playback
As the user, I hear no silence between consecutive tracks of the same album.
Depends: S-004
Acceptance:
- [self] A test pair of gapless-encoded files shows a gap under 20 ms between the end of one and the start of the next.
- [manual] A known gapless album sounds seamless. Open test: whether AVAudioFile trims MP3 encoder padding (platform.md).
UX: none (no screen, action or words). Add a "Gapless" switch to Settings > Playback in S-051 if a user needs to turn it off.
Status: doing (scheduling verified by self-test; the gap under 20 ms is still a manual listen)

### S-007 Media keys and Now Playing
As the user, I use the keyboard media keys and the Control Center widget to control MacAmp.
Depends: S-002
Acceptance:
- [self] Play/pause, next and previous keys act on MacAmp while it is playing.
- [self] Control Center shows title, artist, art and elapsed time.
- [manual] With Music also open, the last app that played gets the keys.
UX:
- Flow: media keys or Control Center -> same effect as the main window controls.
- Surface: system (none in the app).
- States: nothing playing shows no Now Playing card.
- Words: Now Playing shows title, artist, album; for a Station, the Station name and the stream title.
- Access: follows system behavior.
Status: doing (Now Playing and keys wired; manual check with Music open pending)

### S-008 Restore the queue after restart
As the user, I quit and reopen MacAmp and find my queue, current track, and volume as I left them.
Depends: S-004
Acceptance:
- [self] After a relaunch the queue order and the playing track are the same; playback is paused.
- [unit] A missing file shows as unavailable, not as a crash.
UX:
- Flow: quit and reopen -> Queue and current track return, paused -> end: the user presses Play to continue.
- Surface: none (restores state silently).
- States: Unavailable tracks show as in S-004; no alert.
- Words: none new.
- Access: focus returns to the Queue.
Status: done

## M2 Library and playlists

### S-010 Add a music folder
As the user, I pick a folder and MacAmp scans it into my library.
Screens: 01-main-library (INDEX), snapshot "library"
Acceptance:
- [self] A folder of 5,000 files finishes scanning without freezing the window; progress is shown.
- [unit] Tags (title, artist, album, genre, year, track number, duration) are read from each file.
- [manual] The folder stays readable after relaunch (security-scoped bookmark).
Status: done

### S-011 Folder watching
As the user, new or removed files in a library folder appear or disappear on their own.
Depends: S-010
Acceptance:
- [self] A file copied into a watched folder shows up within 10 seconds.
- [self] A deleted file is marked unavailable, not silently dropped.
Status: done

### S-012 Library table with custom columns
As the user, I see all tracks in a table and choose which columns show.
Screens: 01-main-library, 04-custom-columns
Depends: S-010
Acceptance:
- [snap] Table with sortable column headers; a context menu on the header toggles columns.
- [self] A 20,000-track library scrolls at the display's refresh rate with no frame drops in the profiler.
Status: doing (built and snapshot; scrolling with 20,000 tracks not measured)

### S-013 Search the library
As the user, I type in a search field and the table filters by title, artist or album.
Depends: S-012
Acceptance:
- [unit] The filter matches case- and accent-insensitively.
- [self] Results update within 100 ms on a 20,000-track library.
Status: doing (built; the 100 ms target on 20,000 tracks not measured)

### S-014 Column browser
As the user, I narrow the library with genre, artist and album columns.
Screens: 02-column-browser
Depends: S-012
Acceptance:
- [snap] A browser row with three columns above the table; "All" is the first entry in each.
- [unit] Selecting an artist limits the album column to that artist.
Status: done

### S-015 Save a playlist
As the user, I save the queue as a named playlist and find it in the sidebar.
Screens: snapshot "sidebar"
Depends: S-004
Acceptance:
- [snap] Sidebar lists Library, Radio, and playlists.
- [unit] Playlists persist across restarts.
Status: done

### S-016 Edit a playlist
As the user, I rename, delete, add tracks by drag, and reorder a playlist.
Screens: 08-playlist-window
Depends: S-015
Acceptance:
- [self] Dragging tracks from the library onto a sidebar playlist adds them.
- [self] Delete asks for confirmation if the playlist has more than one track.
Status: done

### S-017 Import and export M3U/M3U8/PLS
As the user, I import a playlist file and export mine.
Depends: S-015
Acceptance:
- [unit] M3U with #EXTINF and PLS files parse into tracks; relative paths resolve against the file location.
- [unit] Export then import yields the same track list.
- [self] A URL entry in a playlist file becomes a radio entry.
Status: done

### S-018 Track inspector
As the user, I open an inspector for the selected track(s) and see its tags and artwork.
Screens: 05-track-inspector
Depends: S-012
Acceptance:
- [snap] A side panel with tag fields and artwork; it can be hidden.
- [self] Selecting several tracks shows "multiple values" for fields that differ.
Status: done

### S-019 Edit tags
As the user, I change tags on one or many tracks and they are saved to the files.
Screens: 05-track-inspector
Depends: S-018
Acceptance:
- [unit] Editing title on an MP3 and an M4A writes the tag and reads back the same.
- [self] A read-only file shows an error and leaves the tags unchanged.
Status: todo (blocked: AVFoundation cannot write tags; needs a tag library such as TagLib)

## M3 Internet radio

### S-020 Search stations
As the user, I search Radio Browser by name, country, language or tag.
Screens: snapshot "radio-browse"
Acceptance:
- [unit] The client picks a mirror from the DNS list, sends a descriptive User-Agent, and retries another mirror on failure.
- [snap] Results list station name, country, codec, bitrate and a Play button.
- [self] With no network, the page shows a clear offline state.
Status: done

### S-021 Play a station
As the user, I click a station and it plays.
Depends: S-020
Acceptance:
- [self] An MP3 and an AAC station start within 5 seconds.
- [unit] The click-count endpoint is called once per play.
- [snap] The main window shows the station name and a "live" mark instead of a seek bar.
Status: done

### S-022 Now-playing title from the stream (ICY)
As the user, I see the current song title from the stream.
Depends: S-021
Acceptance:
- [unit] The ICY parser extracts StreamTitle across chunk boundaries and handles an empty metadata block.
- [self] Against 3 real stations the title changes when the song changes.
- [self] A server answering `ICY 200 OK` connects (open test, platform.md).
Status: done (titles verified on a real MP3 station; an `ICY 200 OK` server is untested)

### S-023 Plain http stations
As the user, I can play stations that only offer http.
Depends: S-021
Acceptance:
- [self] An http-only station plays in a built build with the ATS exception set.
- [manual] Document the App Review justification for the exception.
Status: done

### S-024 Favorites
As the user, I star a station and find it under Favorites in the sidebar.
Screens: sidebar
Depends: S-021
Acceptance:
- [unit] Favorites persist across restarts.
- [snap] Starred and unstarred states.
Status: done

### S-025 Add a station by URL
As the user, I paste a stream URL, or a PLS/M3U link, and name the station.
Depends: S-021
Acceptance:
- [unit] A PLS or M3U URL resolves to the first playable stream.
- [self] An invalid URL shows "Can't play this address" with the reason.
Status: done

### S-026 Stream resilience
As the user, a dropped connection reconnects on its own.
Depends: S-021
Acceptance:
- [self] After a 10-second network drop, playback resumes within 15 seconds.
- [unit] Reconnect backs off and stops after 5 tries, with a visible message.
- [self] The buffer is configurable (small, normal, large).
Status: doing (reconnect with backoff and the buffer setting are built; a real 10-second network drop is untested)

### S-027 Station play history
As the user, I see the titles that played on a station.
Depends: S-022
Acceptance:
- [unit] Titles are stored with time and station, up to 500 entries.
- [self] Export to CSV from the history view.
Status: done

## M4 The Winamp feel

### S-030 Ten-band equalizer
As the user, I open an EQ window with 10 bands and a preamp, and presets.
Screens: 13-equalizer (INDEX), snapshot "eq"
Depends: S-001
Acceptance:
- [self] Moving a slider changes the sound within 100 ms, on local files and on radio.
- [unit] Presets save and load; bands are stored per user.
- [snap] Ten sliders, preamp slider and preset menu.
Status: done

### S-031 Spectrum analyzer
As the user, I see a live spectrum in the main window.
Screens: main-playing
Depends: S-001
Acceptance:
- [self] The spectrum updates at about 30 fps with CPU under 5% on Apple Silicon.
- [snap] Spectrum bars in light and dark themes.
Status: done (bars verified on a real tone; the CPU figure under 5% is not measured)

### S-032 Windowshade mini mode
As the user, I collapse the player to a thin bar that keeps play controls and title.
Screens: 10-mini-window (INDEX), snapshot "mini"
Depends: S-002
Acceptance:
- [snap] A bar of one row with title, transport, and a restore button.
- [self] Command-M style shortcut toggles it, and the window remembers its position.
Status: done (shortcut is ⌥⌘M)

### S-033 Winamp-style window set
As the user, the player, EQ and playlist windows snap to each other.
Depends: S-004, S-030
Acceptance:
- [self] Dragging a window near another snaps edges within 8 points and moves them together.
- [snap] Three windows docked in one stack.
Status: doing (snapping geometry is unit-tested; dragging real windows is untested)

### S-034 Themes with dark mode
As the user, I pick a theme in Settings, and each theme has light and dark looks.
Screens: snapshot "settings-themes"
Acceptance:
- [snap] At least two built-in themes, each shown in light and dark.
- [self] The theme changes without a restart.
Status: done

### S-035 Menu bar player
As the user, I control playback from a menu bar item.
Depends: S-002
Acceptance:
- [snap] A popover with art, title, transport buttons and volume.
- [self] The menu bar item can be hidden in Settings.
Status: doing (built and captured in a plain window; the real menu bar item needs a manual look)

### S-036 Global shortcuts
As the user, I set system-wide shortcuts for play/pause, next and previous.
Screens: 12-preferences (INDEX)
Depends: S-002
Acceptance:
- [self] Shortcuts work while another app is focused, without Accessibility permission.
- [self] A conflicting shortcut shows a warning, and can be rebound.
Status: doing (registration and actions are tested; a real key press from another app is untested)

## M5 Recording and audio extras

### S-040 Record a station
As the user, I press Record and MacAmp saves what I hear to a file.
Depends: S-022
Acceptance:
- [unit] Raw stream bytes are written without re-encoding.
- [self] A 2-minute recording opens and plays in MacAmp.
- [manual] Settings explain that the user is responsible for the legal use of recordings.
Status: done (verified with a real station: the recorded file plays back)

### S-041 Split recordings by song
As the user, I choose to start a new file at each title change.
Depends: S-040
Acceptance:
- [unit] A title change closes the file and opens a new one named with the title.
- [self] Characters invalid in file names are replaced.
Status: done

### S-042 ReplayGain
As the user, I turn on ReplayGain so tracks play at similar loudness.
Depends: S-001
Acceptance:
- [unit] Track and album gain tags are read and applied; peak is respected to avoid clipping.
- [self] A pair of files with +6 dB and -6 dB tags plays at equal level.
Status: doing (math and settings done; the tag reader only sees MP3 and M4A tags and is untested on a real tagged file; FLAC and Ogg need a tag library)

### S-043 Artwork
As the user, I see album art from the file or the folder.
Depends: S-001
Acceptance:
- [unit] Embedded art is used first, then cover.jpg or folder.jpg.
- [snap] Art shows in the main window and the Now Playing widget.
Status: done (folder art tested; art embedded in tags is read but not tested with a real file)

### S-044 OGG Vorbis and Opus
As the user, I play .ogg and .opus files.
Depends: S-001
Acceptance:
- [unit] A decoder library turns Vorbis and Opus into PCM for the engine.
- [self] A test .ogg and .opus play, and seek works.
Status: todo (blocked: needs a decoder library such as SFBAudioEngine; adding a third-party package was not approved)

### S-045 Duplicate finder
As the user, I find duplicates in my library and remove them.
Screens: 07-duplicate-finder
Depends: S-010
Acceptance:
- [unit] Matches by title+artist+duration within 2 seconds.
- [self] Removing a duplicate asks whether to delete the file or only the library entry.
Status: done (matching logic tested; the sheet has not been looked at on screen)

## M6 Polish

### S-050 Empty states
As the user, I see helpful empty screens with a clear next step.
Acceptance:
- [snap] Empty library ("Add a folder"), empty queue, empty favorites, no search results.
Status: todo

### S-051 Settings
As the user, I find all options in one Settings window.
Screens: 12-preferences
Acceptance:
- [snap] Panes: General, Library, Playback, Radio, Shortcuts, Appearance.
- [self] Changes apply immediately and survive a restart.
Status: todo

### S-052 App icon
As the user, I see a real icon in the Dock and Finder.
Acceptance:
- [snap] The icon is shown in light, dark and tinted looks.
Status: todo

### S-054 Spanish and English interface
As the user, I use MacAmp in English or Spanish, following the system language.
Acceptance:
- [self] Every user-visible string is in a String Catalog with both languages; no hardcoded text.
- [snap] Main window and Settings in both languages; long Spanish labels do not truncate.
Status: todo

### S-053 Menu bar commands
As the user, every action has a menu item with a shortcut shown.
Acceptance:
- [self] File, Playback, View, Radio and Window menus list the actions from M1 to M5.
- [manual] Review the menu against the Command map in docs/screens/INDEX.md once Swinsian is checked.
Status: todo

### S-055 Choose light or dark
As the user, I pick System, Light, or Dark in Settings > Appearance and every window follows.
Screens: settings-appearance
Acceptance:
- [self] The choice applies to all windows at once and survives a restart.
- [snap] Appearance tab shows a System / Light / Dark control, in light and dark.
- [unit] An unknown saved value falls back to System.
UX:
- Flow: Settings > Appearance > segmented control -> windows change at once.
- Surface: inline (changes one value on screen).
- Words: "Appearance", "System", "Light", "Dark"; footer "System follows the Mac's light or dark setting."
- Access: the control is keyboard operable; VoiceOver reads "Appearance, System".
Status: done

## Later
- Smart playlists (09-smart-playlist-editor), art grid (03-art-grid), find and replace (06-find-replace), separate playlist windows.
- Skin support for .wsz and plug-in visualizations such as MilkDrop.
- 31-band EQ, cue sheets, Last.fm scrobbling, AirPlay, notifications.
- SHOUTcast and Icecast directories (SHOUTcast needs an API key).

## Dropped
- Podcasts (Swinsian): not part of the Winamp-plus-radio idea.
- iOS transfer and sync: no companion app.
- Apple Music library import: low priority; revisit after M2.
- Desktop widget (11-desktop-widget): replaced by the menu bar player.
- AppleScript control: later, with a CLI if wanted.
- Accounts, sharing, subscriptions: radio stays free (market-and-reviews.md decision 2).
