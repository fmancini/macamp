# Swinsian reference index (from public pages)

Reference app for WAMP: Swinsian 3. Built on 2026-11-02 from public pages only, because Swinsian is not installed and computer use was unavailable. There are no PNGs. Each section links the vendor's own screenshot instead.
Tags: [V] stated on a page, [K] general knowledge of Swinsian or player conventions, [U] not confirmed, check in the real app.
Sources: https://swinsian.com/ , https://swinsian.com/blog/2017/11/21/whats-new-in-swinsian-2 , https://mac.softpedia.com/get/Audio/Swinsian.shtml
Describes structure and behavior only. Nothing is copied from the app (no text, logo or icons). WAMP gets its own Winamp-style look.

## 01-main-library
Page: main library window. Image: https://swinsian.com/image/hero.png
Layout: track table in the center with customizable columns; column browser above or beside it; track inspector panel; all three can be hidden for a minimal window [V]. A source sidebar (Library, playlists, folders, podcasts) is likely [K/U].
Elements: track row, column header, browser columns, inspector.
Actions: play on double click, sort by column, inline tag edit in the table (since v2) [V].
Shortcuts seen: none documented.

## 02-column-browser
Page: column browser. Image: https://swinsian.com/image/browser.png
Layout: a row of columns (for example genre, artist, album) that filter the track table. Right-click the column header to change its field. Genre and artist columns can split multi-value entries [V].

## 03-art-grid
Page: album art grid view of the library. Image: https://swinsian.com/image/art-grid.png
Layout: grid of album covers, an alternative to the table [V].

## 04-custom-columns
Page: main table column settings. Image: https://swinsian.com/image/custom-columns.png
Layout: choose which columns the track table shows and their order [V].

## 05-track-inspector
Page: track inspector with tag editor. Image: https://swinsian.com/image/tag-editor.png
Elements: fields for title, artist, album, genre and more; edits one or many tracks at once [V]; multiple artists and genres per track [V, from reviews].
Actions: edit tags, change artwork [K].

## 06-find-replace
Page: find and replace for tags. Image: https://swinsian.com/image/regex-search.png
Actions: search and replace across selected tags, with regex [V].

## 07-duplicate-finder
Page: duplicate finder. Image: https://swinsian.com/image/duplicate-finder.png
Actions: find duplicates by configurable criteria, then remove [V].

## 08-playlist-window
Page: separate playlist window. Image: https://swinsian.com/image/playlist-window.png
Layout: a playlist opened in its own window, so several can be open at once [V].

## 09-smart-playlist-editor
Page: smart playlist rules. Image: https://swinsian.com/image/smart-playlists.png
Elements: rule rows (field, operator, value); rules can test membership in other playlists [V]. Matching/limit options [K/U].

## 10-mini-window
Page: mini window. Image: https://swinsian.com/image/mini-window.png
Layout: small playback window with global shortcuts for control [V]. Controls: previous, play/pause, next, track info, probably art and volume [K/U].

## 11-desktop-widget
Page: desktop widget. Image: https://swinsian.com/image/desktop-widget.png
Layout: customizable widget showing album art and the current track [V].

## 12-preferences
Page: Preferences. Panes seen in release notes: Shortcuts [V] (quick controller shortcut, AirPods/EarPods remote controls, global shortcuts including volume). Other panes (General, Library/folder watching, Playback with EQ and sample rate, Last.fm, Notifications) are likely [K/U].

## 13-equalizer
Page: equalizer. Image: none. 10- or 31-band graphic EQ [V]. Preset menu [K/U].

## 14-notifications
Page: playback notifications. Image: none. Shown on track change [V]. Content likely title, artist and art [K/U].

## Navigation map
- Library (all tracks): table, column browser, art grid, inspector toggles [V].
- Playlists and smart playlists: open in the main window or a separate window [V].
- Podcasts (automatic download) [V]; Apple Music import and folder watching in Preferences [V].
- Mini window and desktop widget [V].
- Tools: find and replace, duplicate finder, library stats [V].
- Sidebar contents [K/U].

## Command map
Menu bar and keyboard shortcuts are not documented in public pages [U]. Known: global shortcuts for the mini window and volume, a quick controller shortcut, and AirPods/EarPods remote control [V]. Check the trial for the full list.

## Data model guess
- Track: file path, title, artist(s), album, album artist, genre(s), year, track/disc number, rating, play count, last played, date added, duration, bitrate, format, artwork, ReplayGain, cue sheet [K].
- Playlist and smart playlist (rules, optional limit) [V/K].
- Folder (watched), device/AirPlay target, podcast feed and episode [V].
- Scrobble (Last.fm) [V].

## Dropped from Swinsian for WAMP (decide in user-stories)
Podcasts, AirPlay, iOS transfer, Apple Music import, 31-band EQ, desktop widget, AppleScript.
Added by WAMP: internet radio (Radio Browser), stream recording, Winamp-style skinned window and windowshade mode.
