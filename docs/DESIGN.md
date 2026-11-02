# Wamp design plan

Written 2026-11-02 with the mac-design skill. Read with docs/BRIEF.md and docs/STORIES.md.

## 1. Archetype
A mix, because Winamp's identity is a set of small windows:
- **Player window set** (main player, equalizer, playlist/queue) with custom compact chrome. Windows snap to each other (S-033) and collapse to a one-row windowshade bar (S-032).
- **Library window**: a standard sidebar window (`NavigationSplitView`: sidebar, table, inspector) for Library, Playlists, Radio and Favorites. Native toolbar, sidebar and inspector rules apply here in full.
- **Menu bar extra** with a popover player (S-035), and a **Settings window** (native tabs).

Why custom chrome only on the player windows: the compact, dense look is the product. It is a small control surface, not content. Everything with lists and tables stays native (concentric radii, system fonts, system spacing, `Space` 4 pt grid). Add this reason as a code comment where the chrome is built.

## 2. Information architecture
Library window sidebar, one level:
- Library (all tracks), Queue
- Radio: Browse, Favorites, History
- Playlists: one entry per saved playlist

Settings tabs: General, Library, Playback, Radio, Shortcuts, Appearance (S-051).

## 3. Command map
| Action | Menu | Shortcut |
| --- | --- | --- |
| Open Files… | File | ⌘O |
| Add Folder to Library… | File | ⇧⌘O |
| Import Playlist… / Export Playlist… | File | none |
| Play / Pause | Playback | Space |
| Stop | Playback | ⌘. |
| Next / Previous | Playback | ⌘→ / ⌘← |
| Seek forward / back 5 s | Playback | → / ← (⌥ for 30 s) |
| Volume up / down | Playback | ↑ / ↓ |
| Shuffle / Repeat | Playback | ⌘S / ⌘R |
| Record Station | Playback | ⇧⌘R |
| Show Equalizer | Window | ⌘E |
| Show Queue | Window | ⌘L |
| Show Library | Window | ⌘1 |
| Windowshade Mode | Window | ⌘M-style: ⌥⌘M |
| Show / hide Sidebar, Inspector | View | system (⌥⌘S, ⌥⌘I) |
| Find | Edit | ⌘F |
| Remove from Queue | Edit | Delete |
| Settings… | app menu | ⌘, |
Global shortcuts (system-wide, user-assigned): Play/Pause, Next, Previous (S-036). Media keys follow the system.
Menu order and labels follow Apple's (menus.md). Every toolbar item also has a menu item.

## 4. Empty states
One `ContentUnavailableView` per page, with the first action as a button:
- Library: "No Music Yet" - "Add Folder…"
- Queue: "The Queue is empty" - "Open Files…"
- Radio Browse, offline: "Can't reach the station list" - "Try Again"
- Favorites: "No Favorite Stations" - "Browse Stations"
- History: "Nothing Played Yet"
- Search with no matches: system search-empty view.
Main player with nothing queued: transport disabled, display reads "Wamp" and "Drop audio files here, or press ⌘O".

## 5. Feeling
Quick, familiar, a little nostalgic. Controls answer in the same frame; the spectrum is alive but quiet. Motion is short fades and slides, fades only under Reduce Motion.

## Look decisions
- **Two themes, each with light and dark:** "Classic" (dark LCD-style display, green-on-black readout, as a nod to Winamp) and "Mac" (system materials and system accent). Theme changes the player windows only; the Library window stays native in both (S-034). Tokens in `design-system`.
- **Liquid Glass:** only on the Library window's toolbar and sidebar (standard parts get it for free). Never in the player windows' display area; no glass on glass.
- **Type:** system fonts. The Classic readout may use a monospaced system font; nothing under 10 pt.
- **Density:** player controls use `.controlSize(.small)` and `.mini` only inside the player windows; the Library window uses regular sizes.
- **Spectrum:** drawn with `Canvas`, driven by a ~30 fps timer, paused when the window is hidden or occluded; Reduce Motion shows a static level bar.
- **Window snapping:** edges snap within 8 pt (S-033). Windows keep their frame via `@SceneStorage`/frame autosave.
- **Accessibility:** custom controls (seek bar, volume, EQ sliders, spectrum) expose label, value and adjustable actions; the spectrum is hidden from VoiceOver.

## Checks to run
After each UI story: snapshot every surface light and dark (main player, EQ, queue, mini, library, menu bar popover, each Settings tab), then walk docs/design-rules rules. Layout probes via `layout-grid` for the player windows, because custom chrome is where misalignment hides.
