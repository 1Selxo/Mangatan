# Changelog

## Unreleased

## 1.0.5-beta+119 - 2026-07-15

- Fixed dictionary profile Auto resolution using normalized source languages consistently across lookup, OCR, Anki mining, entry menus, and extension/source menus.
- Fixed Yomitan v3 `value` glossary objects, including MOE Concised Pinyin, rendering as flattened text instead of structured dictionary content.

## 1.0.4-beta+118 — 2026-07-15

- Added Chimahon-compatible cascading dictionary profiles with automatic selection by title, source, local novel, source language, and global fallback.
- Added dictionary-profile override pickers for individual titles, local novels, and extension sources, including an automatic-selection preview.
- Made dictionary lookup, OCR, and Anki mining use the profile resolved for the current content, with OCR language following that profile.
- Added per-profile dictionary collapse behavior and custom expand/collapse settings for individual dictionaries.
- Preserved dictionary-profile overrides, display settings, and local-novel language metadata through Chimahon-compatible backup and sync.
- Made novel paragraph spacing adjustable and changed its default to zero instead of forcing a gap between paragraphs.
- Fixed local EPUB TOC entries repeatedly reparsing the same book, replaced blank cold-load screens with visible progress, and prevented failed initialization from leaving the reader permanently blank.
- Hid stale internal EPUB character offsets that could appear as chapter dates after upgrading an existing library.
- Replaced raw Kiwi Korean POS codes such as `VV` and `VA-I` with readable part-of-speech and conjugation labels in dictionary lookups.
- Replaced Mangatan's Jimaku search and subtitle matching path with Chimahon's exact API, title-selection, entry-ranking, SRT filtering, and episode fallback behavior.

## 1.0.3-beta+117 — 2026-07-13

- Added explicit duplicate-card creation and an Anki browser button for existing matching cards.
- Reduced Anki media usage by resizing and JPEG-compressing mined screenshots before upload.
- Sped up streamed anime card mining and applied subtitle delay to sentence-audio clip timing.
- Fixed dictionary images that could remain broken in the popup by loading missing media directly from the installed dictionary.
- Matched Hoshi Reader's recursive lookup behavior by opening definition lookups as stacked child popups.
- Cleared anime subtitle highlights when their dictionary popup is dismissed.
- Fixed unreadable dictionary description text when a light popup is used with a dark operating-system theme.
- Fixed EPUB dictionary lookup ignoring Korean clicks by accepting Hangul during reader word scanning.
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
