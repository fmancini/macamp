# MacAmp

A native macOS app in SwiftUI. It runs on this Mac only, with a local
SwiftData database and no server.

## Layout

- `Sources/MacAmp/` the app. `App.swift` has the window, menus, and the database location.
- `Sources/MacAmpKit/` rules and data logic with no SwiftUI. Tests in `Tests/MacAmpKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/MacAmp.app`.
- `Icon/AppIcon.icon` the app icon, an Icon Composer file (JSON plus SVG layers). `build.sh` compiles it with `tools/make_icon.sh`; `tools/icon_review.sh` renders every look into one PNG.
- `docs/` the brief, the screen index, and the user stories, when they exist.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. The build shows warnings; fix them.
- Unit tests: `swift test --scratch-path ~/Library/Developer/MacAmp/test-build`.
- Self-test (the app's real functions on a /tmp store): `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every story with logic in `SelfTest.swift`.
- After every UI change, take snapshots with sample data and look at them: `tools/snap.sh`.
  It writes `/tmp/MacAmp-shots/<page>-light.png` and `-dark.png` for every sidebar page, and `settings-<tab>-light.png` and `-dark.png` for every Settings tab, then quits. `APP_SNAPSHOT_PAGES=all,settings tools/snap.sh` limits the pages.
  For a panel, sheet, or popover, add a capture to `Snapshot.swift` like the Settings loop.
- Snapshots, seed data, and the self-test refuse to run without `APP_STORE` in /tmp.
- Never test against the real database in `~/Library/Application Support/MacAmp/`.
- Then check the grid: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/MacAmp-shots/*-layout.json`. Both print PASS.
- A change is done when the build has no errors, the grid checks pass, and you looked at the light and dark snapshots.

## Design rules

- Design rules: `design/DESIGN-SYSTEM.md`. Use its tokens; never raw colors, radii, or durations.

- Use Apple's controls and system styles. Only the accent color is custom: `UI/Theme.swift` (`ThemeStore.defaultID`). People change it, and System, Light, or Dark mode, in Settings > Appearance (`UI/AppearanceMode.swift`).
- Views use `.tint`, `Palette.accent`, `Palette.accentText` (accent-colored text), and `Palette.onAccent` (text on an accent fill). Never hard-code colors, radii, or durations in views.
- Compare accents: add `APP_ACCENT=<id>` to the snapshot command.
- Spacing comes from `Space` in `UI/Grid.swift`, on a 4 pt grid. Mark custom pages and cards with `.gridArea` and `.gridProbe`.
- Windows open calm: `.noInitialFocus()` on every window and sheet (no focus ring or selected text on open), `.fitsContent()` on sheets and Settings tabs (no scroll bar with nothing to scroll). System scroll bars. Both in `UI/WindowBehavior.swift`.
- Settings: one tab per topic in `SettingsView.swift`, one grouped Form per tab. Add a case to `SettingsTab` for a new tab.
- Window chrome (title bar, toolbar, sidebar, menus, sheets) stays system. Buttons use system styles, like `.borderedProminent`.
- Colors: `.primary`, `.secondary`, `.tint`, and system colors. Never fixed grays or white for text.
- Every action has a menu bar item and a keyboard shortcut.
- `Label` for icon and text pairs. SF Symbols for icons.
- `ContentUnavailableView` for empty states.
- Liquid Glass belongs to floating controls only, never to content.

## Skills

The bama plugin has a skill for each step: `mac-design` (design rules),
`design-system` (accent and tokens), `layout-grid`, `ux-design`,
`swift-swiftui`, `os-integrations`, `performance`, `build-and-verify`,
`test-mac-app`, `app-icon`, `user-stories`, and `improve-loop`. Use them.

## Git

- Commit after each working change, with a message that says what the user can now do.

## Languages

- English and Spanish. The English text is the key; Spanish is in `Localization/es.lproj/Localizable.strings`, with plurals in `Localizable.stringsdict` (also for English). `build.sh` copies `Localization/*.lproj` into the app.
- Text from a `String` variable is not translated by SwiftUI. Use `String(localized: "...")`, or `Text("...")`, `Button("...")`, `.help("...")` with a literal. For a choice between two texts use `cond ? Text("a") : Text("b")`.
- After adding or changing a text, run `python3 tools/strings.py`: it lists texts without a Spanish translation and exits 1.
- Check a language: `APP_STORE=/tmp/x.store APP_SEED=1 APP_SNAPSHOT=/tmp/shots ~/Applications/MacAmp.app/Contents/MacOS/MacAmp -AppleLanguages "(es)"`.
- The Help text is `Localization/<lang>.lproj/Help.md` (English and Spanish). When a feature or shortcut changes, update both files.
