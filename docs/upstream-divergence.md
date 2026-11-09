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
- Novel reader: `novel/mixins/novel_pagination_tts_mixin.dart`,
  `novel/widgets/{novel_bottom_bar,novel_general_settings_tab,novel_html_content,novel_settings_controls,novel_tap_zones}.dart`
- Detail and home: `manga/detail/widgets/{chapter_filter_sort_bottom_sheet,chapter_quick_filters}.dart`,
  `manga/home/widget/{manga_home_image_card,saved_searches_sheet}.dart`
- Onboarding: `onboarding/widgets/{language_list,onboarding_controls,onboarding_folder_status,onboarding_local_folder_section,onboarding_nav_preview,onboarding_steps}.dart`
- Settings: `more/settings/browse/extension_server/extension_server_release_service.dart`,
  `extension_server/widgets/{android_proxy_group,extension_server_actions_group,extension_server_status_group,ios_runtime_group}.dart`
- Restore: `more/data_and_storage/providers/tachiyomi_restore_service.dart`
- Tests for the above: `tachiyomi_history_import_test`,
  `local_virtual_path_test`, `subtitle_style_switch_test`

## Manga reader: upstream's, with the fork's additions

The manga reader is upstream's v0.9.95 reader, with its combined reading
modes (the direction is part of the mode). Settings saved with the old
separate direction fold into the mode when read, and the old cover-offset
double page becomes a double page with a single first page. The fork's
parts sit beside upstream's files, each with a hook in them:

- `mixins/reader_learning_mixin.dart`: the chapter OCR scan and its
  progress, immersion statistics, E-Ink mode, the page preview grid and
  panel navigation. `reader_view.dart` mixes it in and calls it from the
  page change, the app bar, the bottom bar and the keyboard handler, so
  the view is in the file size baseline. Page turns in
  `reader_input_and_mode_mixin.dart` ask it for a panel first.
- `mixins/page_ocr_mixin.dart`: the OCR boxes over each page. The image
  views (`image_view_paged.dart`, `image_view_vertical.dart`) pass its
  painter to the tiled and plain image views, which take a page overlay
  painter (`PageOverlayPainter`) given the whole page's rect: past cropped
  borders (`get_decoder_crop` in the native decoder) and split halves.
- `widgets/reader_gesture_handler.dart`: OCR taps, hover and middle-button
  lookup, and the two-finger OCR toggle around upstream's tap zones.
- `widgets/reader_ocr_settings_group.dart`: the OCR group and the E-Ink
  switch in the reader's settings sheet.
- The "Automatic" background picks each page's colour, Mihon's way plus a
  colour for each side (`utils/smart_background.dart`,
  `widgets/smart_page_background.dart`). Backgrounds are painted under the
  page tint directly (`ReaderBackgroundFill`), not through a colour filter
  layer, which spilled the tint onto pages not yet painted.
- `mixins/reader_split_pages_mixin.dart` puts split pages back together
  when splitting or the direction changes; `reader_wheel_interceptor.dart`
  takes the mouse wheel for paged reading and zoom.

## Shared code adapted to the fork

- `services/local_folders.dart` keeps upstream's location but the fork's
  plain-path model.
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

- `305c4e47` press and hover overlays bounded to their decoration
- `a4db8257` memory work in the restore service (the reader's came with it)
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

The manga reader is adopted (above).

1. Decide on named local folders, then adopt onboarding and local folders.
2. Manga detail, then the extension server screen.
3. Anime player last, porting subtitles, Jimaku, mining and lookup into
   upstream's player mixins one at a time.
