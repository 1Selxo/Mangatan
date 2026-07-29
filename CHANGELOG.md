# Changelog

## Unreleased

## 1.1.0+166 - 2026-07-30

- Added shared dictionary lookup history to manual, recursive, subtitle, and
  reader lookups, with quick recall and clear-history controls.
- Added safe dictionary display-name aliases plus Yomitan-compatible revision
  checks, manual updates, and configurable automatic dictionary updates.
- Added selected-chapter pre-OCR, configurable parallel OCR tasks, and OCR
  engine switching directly inside the manga reader.
- Added HEIC, HEIF, and JPEG XL discovery and MIME handling for local
  manga/archive and EPUB content alongside AVIF.
- Added Chimahon-compatible subtitle cleanup filters for speaker labels,
  bracketed text, uppercase cues, music markers, multiline merging, and custom
  regular expressions.
- Added two-finger OCR toggles for touch manga/video readers, a full-reader
  E-Ink mode, and an in-reader thumbnail grid for page previews and jumps.
- Added Chimahon-style YouTube support as a built-in anime source, including
  mixed video/channel/playlist search, direct YouTube URLs, recent searches,
  preferred-quality selection, optional library channel saving, live-stream
  fallback, closed captions, and alternate audio tracks in Mangatan's existing
  video OCR and mining player.
- Fixed alternate video audio tracks not initializing unless the video also
  exposed subtitles.
- Redesigned Yomitan Kanji entries into a compact three-column Meaning,
  Readings, and Statistics layout, keeping classifications, codepoints, and
  dictionary indices visible without long stacked sections.
- Added Chimahon-style dictionary popup paging with Page Up/Down, arrow,
  Home/End, and hardware volume keys, while respecting E-Ink instant scrolling.

## 1.0.8+123 - 2026-07-26

- Promoted Mangatan 1.0.8 from beta to the stable release channel.
- Fixed missing or inaccurate OCR on extremely tall webtoon pages by scanning
  overlapping vertical tiles, remapping results to full-page coordinates, and
  discarding duplicate detections at tile seams.
- Applied tall-page tiling to both local ScreenAI and Google Lens OCR while
  leaving ordinary manga pages on the existing single-request path.
- Updated the in-app, Rich Presence, README, issue-support, and GitHub
  repository links to the new Mangatan Discord server.

## 1.0.8-beta+122 - 2026-07-25

- Updated Mangatan to the latest Mangayomi base while preserving its reader,
  dictionary, OCR, EPUB, mining, and Chimahon-compatible sync features.
- Added Android TV discovery, navigation, player controls, packaging assets,
  update-error reporting, custom DNS-over-HTTPS, and Cloudflare proxy support.
- Added optimized tiled/subsampled manga image rendering and restored
  Mangatan's crop-border and OCR cache integration.
- Merged PR #61 to move local ScreenAI OCR work off the UI thread and serialize
  native OCR access.
- Merged PR #62 to optionally crop manga screenshots before exporting Anki
  cards.
- Published SHA-256 checksums for the unsigned Windows installer and portable
  archive.
- Fixed WebDAV credential validation, EPUB blob verification tests, TV settings
  isolation, and cross-platform protocol tests.

## 1.0.7-beta+121 - 2026-07-18

- Added Chimahon-compatible sync mode as a separate switchable sync path.
- Added persistent Mokuro OCR support and moved reader OCR progress below the visible menu.
- Added manga EPUB drag-and-drop import support.
- Added a default reader page-mode setting and unified desktop back navigation across readers and detail pages.
- Split dictionary settings into focused learning sections.
- Kept filtered language sources available to the library and fixed Mihon source compatibility/reading progress handling.
- Removed stale Kiwi plugin registrations after replacing Korean lookup with the Yomitan pipeline.
- Refined Korean Yomitan deinflection for additional irregular, vocative, particle, and noun-shortening forms while hiding internal Hangul processor traces from popup chips.
- Improved Escape/back handling to avoid duplicate navigation actions.

## 1.0.6-beta+120 - 2026-07-16

- Removed the Kiwi Korean runtime/model dependency and routed Korean lookup through the existing Yomitan language pipeline, including extra Korean irregular and particle-shortening lookup variants.
- Fixed manga OCR uploads for WebP and other source formats by normalizing decoded page images to PNG before sending them to Google Lens OCR.
- Fixed dictionary profile lookup/session caching when switching between languages such as Mandarin and Japanese.
- Improved MOE Concised Pinyin structured-content rendering in dictionary popups with MOE-specific layout styling.
- Added an optional live video OCR overlay that scans frames while playback continues, without changing the existing paused-frame OCR flow.
- Added a quick double-space shortcut for the existing manual video OCR capture, while keeping the toolbar OCR button.

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
