# Changelog

## 1.0.3-beta+117 — 2026-07-13

- Replaced the hand-written Korean lookup analyzer with Kiwi contextual morphology, retaining the legacy rules only as a runtime fallback.
- Added previous/next subtitle synchronization controls and saved subtitle delay per anime entry across episodes.
- Preserved the selected streaming server, subtitle/dub variant, and quality across episode changes and application sessions.

## 1.0.2-beta+116 — 2026-07-12

- Fixed Jimaku title cleanup truncating titles that end in the letter `e`, including `One Piece`.

## 1.0.1-beta+115 — 2026-07-12

- Fixed Jimaku subtitle matching for long-running anime whose files contain both season-relative and absolute episode numbers, such as One Piece `S03E051` / `第279話`.
- Reduced light-novel trackpad sensitivity so one continuous two-finger gesture advances only one paginated page.

## 0.1.0-alpha+113 — 2026-07-10

This private alpha build continues the Mangatan language-learning work and includes the changes made since `v0.1.0-alpha`.

- Added a dictionary lookup tab and improved dictionary imports, popup positioning, cached-result handling, keyboard focus, and text editing.
- Improved reader interactions with configurable tap zones, adjustable animation speed, better OCR hit areas, smoother pointer behavior, and more reliable shortcuts.
- Added audio mining and source activation options, plus Lapis-specific autofill handling for Anki cards.
- Added the initial Chimahon-compatible sync foundation, including broader Mihon backup data and settings support.
- Improved the Mihon bridge so it starts reliably, uses loopback-safe connections, and handles grouped anime filters more consistently.
- Refined anime playback controls, extension interactions, library readability, popup contrast, and dark-mode gloss images.
- Updated user-facing branding and support text to use Mangatan consistently.
- Improved desktop release automation and native dictionary build setup, including prerelease handling and platform-specific toolchain fixes.
- Removed patches that are no longer needed and ignored generated runtime files that should not be committed.
