# Wamp design system

Tokens live in `Sources/Wamp/UI/`. Never use raw colors, radii, or durations in views.
Look: Apple's own parts, plus a custom player look in the player windows only (docs/DESIGN.md).

## Theme.swift: the accent
- Accent stays `system` (follows the Mac). `ThemeStore.brand` is nil: Wamp has no brand color.
- Accent fills and tint: `.tint` or `Palette.accent`.
- Accent-colored text: `Palette.accentText`. Text on an accent fill: `Palette.onAccent`, never fixed white.
- People change the accent in Settings > Appearance.

## Surfaces.swift: the player look
- `PlayerTheme` is `classic` (LCD display, green readout) or `mac` (system materials, accent readout). It changes the player, equalizer, and queue windows only. The Library window, Settings, and menu bar popover stay native.
- `Surface.playerBody`: window body. `Surface.display`: the inset display with title, time, and spectrum.
- `Surface.readout`: main text and lit bars in the display. `Surface.readoutDim`: secondary text and unlit bars.
- `Surface.hairline`, `Surface.surfaceHover`: lines and hover fills. `Surface.warning`: Unavailable tracks and connection errors, always with an icon or a word.
- Every custom color has light, dark, and Increase Contrast values (`Color(light:dark:highContrastLight:highContrastDark:)`).
- The Classic readout is the only green in the app. Do not use it for accent, status, or the Library window.

## Grid.swift: spacing
- `Space.xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, section 32`; window margin 20. See the layout-grid rules.

## Radius.swift
- `xs 6` chips, `sm 8` controls and the display inset, `row 10` row hover, `md 12` cards, `lg 18` popover, `xl 26` floating glass.
- Inner radius = outer radius - inset.

## Layout.swift
- Fixed sizes: player 320 x 148, equalizer 320 wide, windowshade 24 tall, snap distance 8, sidebar 180-220, popover 280 wide.

## Motion.swift
- Every animation uses `Motion.*` through `.motionSafe(_:value:)`, so Reduce Motion turns it off.
- `hover` and `select` for hover and selection, `quick` for presses, `ui` for panels, `appear`/`dismiss` for overlays, `listChange` for queue changes, `spectrumFall` for bar decay.
- Search results and the track table do not animate. Hover never moves a selection.
- Units ("kbps", "%") never animate; only the number does (`.contentTransition(.numericText())`).

## Not written yet (add when a view needs it)
- `Components.swift`: transport button style, slider styles for seek, volume, and equalizer (all through `ButtonStyle`/`Slider` styles, never rebuilt from shapes).
- `Overlay.swift`: the menu bar popover and toast builder.

## Rules
- Style controls with `ButtonStyle` and `ToggleStyle`. A seek bar or EQ slider keeps keyboard, focus, and VoiceOver.
- Custom fonts: none. System fonts only; the Classic readout may use `.monospaced`. Nothing under 10 pt.
- Glass only on the Library window's toolbar and sidebar. Never on the display area. Never glass on glass.
- Both themes are checked in light and dark in every snapshot.
- One primary button per page.
