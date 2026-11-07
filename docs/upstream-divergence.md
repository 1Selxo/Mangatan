# Upstream divergence

Mangatan is rebased on Mangayomi v0.9.95. Most of upstream is adopted as is.
A few subsystems stay fork-owned because the fork's language-learning
features (OCR, dictionary lookup, mining, Anki, Jimaku subtitles, the EPUB
reader, Chimahon sync) are built into them. This file records what was left
out, so it can be adopted later on purpose rather than by accident.

## Fork-owned subsystems

| Area | Fork keeps | Upstream redesign not adopted | Effort to adopt |
| --- | --- | --- | --- |
| Anime player | `anime_player_view.dart` logic, subtitle widgets; the controls now use upstream's Shiori layout (floating timeline panel, top bar layout, lock, hold-and-slide speed) | Player split into mixins, shortcut pills, desktop volume/position buttons, settings sections | High: subtitles, mining, Jimaku and lookup live inside the player |
| Manga reader | `reader_view.dart`, `image_view_*.dart`; the bottom bar, mode picker (with a separate direction control), slider page preview, auto-scroll sheet and settings sheet follow upstream's Shiori design | Reader split into mixins | Medium-high: upstream merges reading mode and direction into one enum, so settings need a migration |
| Novel reader | `novel_reader_view.dart`, settings sheet | Split widgets and tap zones | High: the fork's EPUB reader is a different engine |
| Manga detail | `manga_detail_view.dart`, `manga_details_view.dart` | Quick filters, filter sheet | Medium |
| Local folders and onboarding | Plain folder paths (`Settings.localFolders`) | Named folders with virtual paths | Low-medium, pending a product decision |
| Extension server screen | Fork screen with iOS embedded runtime controls | Grouped settings screen | Medium |
| Sync screen | Fork screen with Chimahon modes | Upstream layout | Medium; Chimahon UI must stay |
| Mihon/Tachiyomi restore | `restore.dart` Mihon path | `TachiyomiRestoreService` | Low; the fork already covers upstream's history and anime fixes |
| Downloads, manga home | Fork versions | Upstream changes | Low-medium |

## Upstream files not present

These upstream v0.9.95 files were removed because nothing in the fork uses
them. Restore any of them with
`git checkout <v0.9.95 commit> -- <path>`.

- Anime player: `anime/mixins/anime_{mpv_bridge,player_controls,player_settings,track_selection}_mixin.dart`,
  `anime/utils/always_on_top.dart`, `anime/widgets/{anime_screenshot_sheet,desktop_fullscreen_button,desktop_position_indicator,desktop_volume_button,mobile_primary_button_bar,player_settings_sections,player_shortcut_pills,seek_indicator_text}.dart`
- Manga reader: `manga/reader/mixins/reader_{double_page,input_and_mode,prefetch}_mixin.dart`,
  `reader_zoom_control.dart`, `widgets/reader_page_content.dart`,
  `reader_common/mixins/reader_auto_scroll.dart`
- Novel reader: `novel/mixins/novel_pagination_tts_mixin.dart`,
  `novel/widgets/{novel_bottom_bar,novel_general_settings_tab,novel_html_content,novel_settings_controls,novel_tap_zones}.dart`
- Detail and home: `manga/detail/widgets/{chapter_filter_sort_bottom_sheet,chapter_quick_filters}.dart`,
  `manga/home/widget/{manga_home_image_card,saved_searches_sheet}.dart`
- Onboarding: `onboarding/widgets/{language_list,onboarding_controls,onboarding_folder_status,onboarding_local_folder_section,onboarding_nav_preview,onboarding_steps}.dart`
- Settings: `more/settings/browse/extension_server/extension_server_release_service.dart`,
  `extension_server/widgets/{android_proxy_group,extension_server_actions_group,extension_server_status_group,ios_runtime_group}.dart`
- Restore: `more/data_and_storage/providers/tachiyomi_restore_service.dart`
- Tests for the above: `reader_bottom_bar_test`, `reader_mode_picker_test`,
  `webtoon_gesture_test`, `tachiyomi_history_import_test`,
  `local_virtual_path_test`, `subtitle_style_switch_test`

## Shared code adapted to the fork

- `services/local_folders.dart` keeps upstream's location but the fork's
  plain-path model.
- `reader_mode_glyph.dart` draws upstream's glyphs for the fork's
  `ReaderMode` values.
- `color_filter_widget.dart` keeps the fork's RGBA slider helper, which
  upstream removed.
- The fork readers use upstream's `ReaderChapterNavigation` and
  `KeyBindings`, so custom shortcuts and chapter switching behave the same
  in every reader.
- The desktop YouTube browser closes and reopens its window around playback,
  because the published `desktop_webview_window` cannot hide a window.
- `download_provider.dart` keeps the fork's structure (stream preference,
  video list retry, Jimaku, Mokuro, `finalizeDownload`) with upstream's
  v0.9.95 fixes applied on top: enqueue before claiming the queue slot,
  ordered progress writes, CBZ pages of any image type, cover fetch after
  the download, and localized error toasts.
- The fork's downloads screen hosts upstream's `AutoDownloadGroup`, the
  delete-after-reading slot options, and the reader's download-ahead.
- Extension updates follow upstream: repositories are read first, then
  `applyExtensionUpdates` sets the newest version and auto-updates a source
  only from its own repository.
- The fork rejects a `.ts` segment that is not MPEG-TS, so tests that fetch
  segments must serve sync-aligned packets.

## Upstream fixes not adopted

These upstream fixes target the reader and player files the fork keeps. They
are worth porting by hand, or come for free with the redesign.

- `092d9196` reader page indexing and widget key stability
- `358a13db` panning a zoomed webtoon page without losing double tap
- `c4edbe9a` Ctrl and wheel zoom
- `305c4e47` press and hover overlays bounded to their decoration
- `a4db8257` memory work in the reader and restore service
- Player: the compact portrait bottom bar (`MobilePlayerBottomControlsLayout`
  with shortcut pills); the top bar and hold-and-slide speed are adopted

## Known debt

- Fork code reads the global `isar` from `main.dart`. The architecture test
  records those imports in a baseline under `test/core/fork_baseline`; the
  test fails on new ones and asks to tighten the baseline when one is
  removed. Refresh it with `UPDATE_FORK_BASELINE=1 flutter test test/core`.
- `manga/detail/widgets/manga_info_header.dart` is upstream's and only its
  tests use it, because the fork keeps its own detail header.
- The server fork (M-Extension-Server) now merges kodjodevf's upstream.
  The app sends the remote WebView port and token on every Mihon request,
  starting the WebView host first. `tool/prepare_embedded_mihon_ios.sh`
  pins the merged server's runtime, ios-runtime-v16.
- The server pins Suwayomi's `android-jar` stubs to a fixed commit, because
  Suwayomi republishes that version in place without classes the fork
  still needs.

## Checking a future rebase

Merge conflicts miss upstream changes that a fork-side resolution quietly
dropped. After each rebase, list every upstream commit since the merge base
and count its added lines that survive in upstream's final tree but are
missing from ours. Commits with many missing lines are either a deliberate
fork choice (listed above) or a lost fix to restore. The v0.9.95 rebase
found the download fixes, the auto-download settings and the external
browser helper this way.

## Suggested order for adopting the redesign

1. Decide on named local folders, then adopt onboarding and local folders.
2. Manga detail, then the extension server screen.
3. Manga reader: migrate `ReaderMode` and `ReadingDirection` first, then
   move OCR, lookup and mining into upstream's reader mixins.
4. Anime player last, porting subtitles, Jimaku, mining and lookup into
   upstream's player mixins one at a time.
