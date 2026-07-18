import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_app_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

void main() {
  const adapter = ChimahonAppSettingsAdapter();
  const codec = ChimahonPreferenceCodec();

  group('export', () {
    test(
      'emits the complete explicit allowlist with exact primitive types',
      () {
        final projection = adapter.project(_fullyMappedSettings());
        final decoded = _decode(projection.preferences);

        expect(decoded.keys.toSet(), ChimahonAppSettingsAdapter.supportedKeys);
        expect(projection.unrepresentableKeys, isEmpty);
        expect(
          decoded.keys,
          isNot(
            anyOf(contains('pref_subtitle_lang'), contains('relative_time_v2')),
          ),
        );

        const stringKeys = <String>{
          'pref_theme_mode_key',
          'app_date_format',
          'pref_display_mode_library',
          'pref_display_mode_animelib',
          'pref_novel_display_mode_library',
          'library_sorting_mode',
          'animelib_sorting_mode',
          'pref_filter_library_downloaded_v2',
          'pref_filter_library_unread_v2',
          'pref_filter_library_started_v2',
          'pref_filter_library_bookmarked_v2',
          'pref_filter_library_completed_v2',
          'pref_filter_animelib_downloaded_v2',
          'pref_filter_animelib_unseen_v2',
          'pref_filter_animelib_started_v2',
          'pref_filter_animelib_bookmarked_v2',
          'pref_filter_animelib_completed_v2',
          'default_user_agent',
          'pref_audio_lang',
          'pref_audio_config',
          'pref_video_debanding',
        };
        const floatKeys = <String>{
          'pref_progress_preference',
          'pref_player_speed',
        };
        const booleanKeys = <String>{
          'pref_theme_dark_amoled_key',
          'display_download_badge',
          'display_language_badge',
          'display_local_badge',
          'display_continue_reading_button',
          'display_category_tabs',
          'display_number_of_items',
          'display_animelib_download_badge',
          'display_animelib_language_badge',
          'display_animelib_local_badge',
          'display_continue_watching_button',
          'display_anime_category_tabs',
          'display_anime_number_of_items',
          'display_novel_category_tabs',
          'display_novel_number_of_items',
          'pref_enable_transitions_pager_key',
          'pref_enable_transitions_webtoon_key',
          'pref_show_page_number_key',
          'fullscreen',
          'pref_keep_screen_on_key',
          'crop_borders',
          'crop_borders_webtoon',
          'pref_inverted_colors',
          'pref_grayscale',
          'pref_color_filter_key',
          'pref_download_only_over_wifi_key',
          'save_chapter_as_cbz',
          'show_nsfw_source',
          'auto_clear_chapter_cache',
          'verbose_logging',
          'pref_enable_discord_rpc',
          'pref_discord_show_progress',
          'pref_auto_update_manga_sync_key',
          'player_fullscreen',
          'pref_enable_ani_skip',
          'pref_enable_auto_skip_ani_skip',
          'pref_audio_pitch_correction',
          'pref_try_hwdec',
          'pref_gpu_next',
          'use_yuv420p',
          'pref_bold_subtitles',
          'pref_italic_subtitles',
        };

        for (final entry in decoded.entries) {
          final expectedKind = stringKeys.contains(entry.key)
              ? ChimahonPreferenceKind.string
              : floatKeys.contains(entry.key)
              ? ChimahonPreferenceKind.floatingPoint
              : booleanKeys.contains(entry.key)
              ? ChimahonPreferenceKind.boolean
              : ChimahonPreferenceKind.integer;
          expect(entry.value.kind, expectedKind, reason: entry.key);
        }
      },
    );

    test('uses Chimahon enum tokens and non-ordinal conversions', () {
      final values = _values(adapter.export(_fullyMappedSettings()));

      expect(values['pref_theme_mode_key'], 'SYSTEM');
      expect(values['pref_display_mode_library'], 'LIST');
      expect(values['pref_display_mode_animelib'], 'COVER_ONLY_GRID');
      expect(values['pref_novel_display_mode_library'], 'COVER_ONLY_GRID');
      expect(values['pref_library_columns_portrait_key'], 3);
      expect(values['pref_library_columns_landscape_key'], 3);
      expect(values['pref_animelib_columns_portrait_key'], 4);
      expect(values['pref_animelib_columns_landscape_key'], 4);
      expect(values['pref_novel_library_columns_portrait_key'], 5);
      expect(values['pref_novel_library_columns_landscape_key'], 5);
      expect(values['library_sorting_mode'], 'LATEST_CHAPTER,DESCENDING');
      expect(values['animelib_sorting_mode'], 'LAST_READ,ASCENDING');
      expect(values['pref_filter_library_downloaded_v2'], 'ENABLED_NOT');
      expect(values['pref_filter_animelib_unseen_v2'], 'ENABLED_IS');
      expect(values['pref_double_tap_anim_speed'], 250);
      expect(values['pref_default_reading_mode_key'], 2);
      expect(values['page_layout'], 1);
      expect(values['pref_image_scale_type_key'], 6);
      expect(values['pref_reader_theme_key'], 2);
      expect(values['crop_borders_webtoon'], isTrue);
      expect(values['color_filter_mode'], 5);
      expect((values['color_filter_value']! as int) & 0xffffffff, 0x80010203);
      expect(values['remove_after_read_slots'], 0);
      expect(values['doh_provider'], 12);
      expect(values['pref_progress_preference'], closeTo(0.73, 0.000001));
      expect(values['pref_audio_config'], 'ReverseStereo');
      expect(values['pref_video_debanding'], 'GPU');
      expect(values['pref_try_hwdec'], isTrue);
      expect(values['backup_interval'], 168);
      expect(values['verbose_logging'], isTrue);
      expect(values['pref_auto_update_manga_sync_key'], isFalse);

      expect(
        (values['pref_text_color_subtitles']! as int) & 0xffffffff,
        0xff804020,
      );
      expect(
        (values['pref_border_color_subtitles']! as int) & 0xffffffff,
        0x7f102030,
      );
      expect(
        (values['pref_background_color_subtitles']! as int) & 0xffffffff,
        0x80010203,
      );
    });

    test('omits nullable and locally unsupported values', () {
      final settings =
          Settings(
              defaultReaderMode: ReaderMode.horizontalContinuous,
              doHEnabled: true,
              doHProviderId: 99,
              doubleTapAnimationSpeed: 99,
              readerNavigationLayout: 99,
              markEpisodeAsSeenType: 101,
              libraryFilterMangasDownloadType: 99,
              defaultPageMode: PageMode.doublePageCover,
            )
            ..sortLibraryManga = SortLibraryManga(index: 99, reverse: false)
            ..relativeTimesTamps = 1
            ..mangaGridSize = 8
            ..defaultSubtitleLang = null;

      final projection = adapter.project(settings);
      final keys = projection.preferences.map((item) => item.key).toSet();

      expect(keys, isNot(contains('pref_default_reading_mode_key')));
      expect(keys, isNot(contains('doh_provider')));
      expect(keys, isNot(contains('pref_double_tap_anim_speed')));
      expect(keys, isNot(contains('reader_navigation_mode_pager')));
      expect(keys, isNot(contains('reader_navigation_mode_webtoon')));
      expect(keys, isNot(contains('pref_progress_preference')));
      expect(keys, isNot(contains('pref_filter_library_downloaded_v2')));
      expect(keys, isNot(contains('library_sorting_mode')));
      expect(keys, isNot(contains('relative_time_v2')));
      expect(keys, isNot(contains('pref_library_columns_portrait_key')));
      expect(keys, isNot(contains('pref_library_columns_landscape_key')));
      expect(keys, isNot(contains('page_layout')));
      expect(keys, isNot(contains('pref_subtitle_lang')));
      expect(projection.unrepresentableKeys, {
        'pref_default_reading_mode_key',
        'doh_provider',
        'pref_double_tap_anim_speed',
        'reader_navigation_mode_pager',
        'reader_navigation_mode_webtoon',
        'pref_progress_preference',
        'pref_filter_library_downloaded_v2',
        'library_sorting_mode',
        'pref_library_columns_portrait_key',
        'pref_library_columns_landscape_key',
        'page_layout',
      });
      expect(
        projection.unrepresentableKeys,
        isNot(contains('app_date_format')),
        reason: 'a nullable supported value remains an intentional omission',
      );
    });

    test('reports every invalid compound value as unrepresentable', () {
      final settings = Settings(
        customColorFilter: CustomColorFilter(a: 256, r: 0, g: 0, b: 0),
        playerSubtitleSettings: PlayerSubtitleSettings(
          textColorA: -1,
          textColorR: 0,
          textColorG: 0,
          textColorB: 0,
          borderColorA: 0,
          borderColorR: 0,
          borderColorG: 999,
          borderColorB: 0,
          backgroundColorA: 0,
          backgroundColorR: 0,
          backgroundColorG: 0,
          backgroundColorB: 999,
        ),
        backupFrequency: 99,
      );

      expect(
        adapter.project(settings).unrepresentableKeys,
        containsAll({
          'color_filter_value',
          'pref_text_color_subtitles',
          'pref_border_color_subtitles',
          'pref_background_color_subtitles',
          'backup_interval',
        }),
      );
    });
  });

  group('import', () {
    test('maps Chimahon reader values using their one-based wire enums', () {
      final settings = Settings(
        doubleTapAnimationSpeed: 2,
        scaleType: ScaleType.stretch,
      );

      adapter.importInto(settings, [
        codec.encode('pref_double_tap_anim_speed', 500),
        codec.encode('pref_image_scale_type_key', 1),
      ]);

      expect(settings.doubleTapAnimationSpeed, 1);
      expect(settings.scaleType, ScaleType.fitScreen);
    });

    test('round-trips every exact mapping and preserves local-only state', () {
      final source = _fullyMappedSettings();
      final exported = adapter.export(source);
      final destination =
          Settings(playerSubtitleSettings: PlayerSubtitleSettings(position: 91))
            ..relativeTimesTamps = 1
            ..mangaGridSize = 7
            ..animeGridSize = 6
            ..novelGridSize = 5
            ..readerBrightness = -0.4
            ..readerContrast = 1.7
            ..readerSaturation = 0.6
            ..customDns = 'local.invalid';

      adapter.importInto(destination, exported);

      final reexported = adapter.export(destination);
      expect(
        reexported.map((item) => base64Encode(item.writeToBuffer())),
        orderedEquals(
          exported.map((item) => base64Encode(item.writeToBuffer())),
        ),
      );
      expect(destination.relativeTimesTamps, 1);
      expect(destination.mangaGridSize, 3);
      expect(destination.animeGridSize, 4);
      expect(destination.novelGridSize, 5);
      expect(destination.defaultPageMode, PageMode.doublePage);
      expect(destination.enableHardwareAcceleration, isTrue);
      expect(destination.readerBrightness, -0.4);
      expect(destination.readerContrast, 1.7);
      expect(destination.readerSaturation, 0.6);
      expect(destination.customDns, 'local.invalid');
      expect(destination.playerSubtitleSettings!.position, 91);
    });

    test('requires paired Chimahon settings to agree', () {
      final settings = Settings(
        animatePageTransitions: false,
        readerNavigationLayout: 4,
        cropBorders: false,
      )..mangaGridSize = 6;

      adapter.importInto(settings, [
        codec.encode('pref_enable_transitions_pager_key', true),
        codec.encode('pref_enable_transitions_webtoon_key', false),
        codec.encode('reader_navigation_mode_pager', 1),
        codec.encode('reader_navigation_mode_webtoon', 2),
        codec.encode('crop_borders', true),
        codec.encode('crop_borders_webtoon', false),
        codec.encode('pref_library_columns_portrait_key', 2),
        codec.encode('pref_library_columns_landscape_key', 3),
      ]);

      expect(settings.animatePageTransitions, false);
      expect(settings.readerNavigationLayout, 4);
      expect(settings.cropBorders, isFalse);
      expect(settings.mangaGridSize, 6);

      adapter.importInto(settings, [
        codec.encode('pref_enable_transitions_pager_key', true),
        codec.encode('pref_enable_transitions_webtoon_key', true),
        codec.encode('reader_navigation_mode_pager', 3),
        codec.encode('reader_navigation_mode_webtoon', 3),
        codec.encode('crop_borders', true),
        codec.encode('crop_borders_webtoon', true),
        codec.encode('pref_library_columns_portrait_key', 2),
        codec.encode('pref_library_columns_landscape_key', 2),
      ]);

      expect(settings.animatePageTransitions, true);
      expect(settings.readerNavigationLayout, 3);
      expect(settings.cropBorders, isTrue);
      expect(settings.mangaGridSize, 2);
    });

    test(
      'can preserve a local unrepresentable setting during routine sync',
      () {
        final settings = Settings(
          defaultReaderMode: ReaderMode.horizontalContinuous,
          fullScreenReader: false,
        );
        final preserveLocalKeys = adapter.project(settings).unrepresentableKeys;

        adapter.importInto(settings, [
          codec.encode('pref_default_reading_mode_key', 3),
          codec.encode('fullscreen', true),
        ], preserveLocalKeys: preserveLocalKeys);

        expect(settings.defaultReaderMode, ReaderMode.horizontalContinuous);
        expect(settings.fullScreenReader, isTrue);
      },
    );

    test('leaves unsupported, unknown, and wrongly typed values untouched', () {
      final subtitles = PlayerSubtitleSettings(fontSize: 44, position: 17);
      final settings =
          Settings(
              displayType: DisplayType.list,
              libraryFilterMangasDownloadType: 2,
              sortLibraryManga: SortLibraryManga(index: 6, reverse: true),
              doubleTapAnimationSpeed: 1,
              defaultReaderMode: ReaderMode.horizontalContinuous,
              scaleType: ScaleType.smartFit,
              backgroundColor: BackgroundColor.automatic,
              fullScreenReader: false,
              deleteDownloadAfterReading: true,
              doHEnabled: true,
              doHProviderId: 3,
              markEpisodeAsSeenType: 85,
              audioChannels: AudioChannel.mono,
              debandingType: DebandingType.cpu,
              defaultPageMode: PageMode.doublePageCover,
              enableHardwareAcceleration: false,
              backupFrequency: 4,
              playerSubtitleSettings: subtitles,
            )
            ..relativeTimesTamps = 2
            ..mangaGridSize = 6;

      final malformed = codec.encode('pref_show_page_number_key', true)
        ..value.value = [0xff];
      expect(
        () => adapter.importInto(settings, [
          codec.encode('pref_display_mode_library', 'FUTURE_GRID'),
          codec.encode('pref_filter_library_downloaded_v2', 'FUTURE_STATE'),
          codec.encode('library_sorting_mode', 'RANDOM,ASCENDING'),
          codec.encode('pref_double_tap_anim_speed', 999),
          codec.encode('pref_default_reading_mode_key', 0),
          codec.encode('pref_image_scale_type_key', 99),
          codec.encode('pref_reader_theme_key', 99),
          codec.encode('fullscreen', 'true'),
          codec.encode('remove_after_read_slots', 2),
          codec.encode('doh_provider', 99),
          codec.encode('pref_progress_preference', 0.855),
          codec.encode('pref_audio_config', 'FutureChannels'),
          codec.encode('pref_video_debanding', 'FutureDebanding'),
          codec.encode('page_layout', 2),
          codec.encode('pref_try_hwdec', 'true'),
          codec.encode('backup_interval', 72),
          codec.encode('pref_subtitles_font_size', '55'),
          codec.encode('relative_time_v2', false),
          codec.encode('pref_library_columns_portrait_key', 2),
          codec.encode('pref_subtitle_lang', 'ja'),
          codec.encode('mangatan_private_setting', 'must stay local'),
          malformed,
        ]),
        returnsNormally,
      );

      expect(settings.displayType, DisplayType.list);
      expect(settings.libraryFilterMangasDownloadType, 2);
      expect(settings.sortLibraryManga!.index, 6);
      expect(settings.sortLibraryManga!.reverse, true);
      expect(settings.doubleTapAnimationSpeed, 1);
      expect(settings.defaultReaderMode, ReaderMode.horizontalContinuous);
      expect(settings.scaleType, ScaleType.smartFit);
      expect(settings.backgroundColor, BackgroundColor.automatic);
      expect(settings.fullScreenReader, false);
      expect(settings.deleteDownloadAfterReading, true);
      expect(settings.doHEnabled, true);
      expect(settings.doHProviderId, 3);
      expect(settings.markEpisodeAsSeenType, 85);
      expect(settings.audioChannels, AudioChannel.mono);
      expect(settings.debandingType, DebandingType.cpu);
      expect(settings.defaultPageMode, PageMode.doublePageCover);
      expect(settings.enableHardwareAcceleration, isFalse);
      expect(settings.backupFrequency, 4);
      expect(settings.playerSubtitleSettings, same(subtitles));
      expect(settings.playerSubtitleSettings!.fontSize, 44);
      expect(settings.playerSubtitleSettings!.position, 17);
      expect(settings.relativeTimesTamps, 2);
      expect(settings.mangaGridSize, 6);
    });

    test('decodes all supported enum values symmetrically', () {
      for (final display in DisplayType.values) {
        final source = Settings(
          displayType: display,
          animeDisplayType: display,
          novelDisplayType: display,
        );
        final destination = Settings();
        adapter.importInto(destination, adapter.export(source));
        expect(destination.displayType, display);
        expect(destination.animeDisplayType, display);
        expect(destination.novelDisplayType, display);
      }

      for (var state = 0; state <= 2; state++) {
        final source = Settings(
          libraryFilterMangasDownloadType: state,
          libraryFilterAnimeUnreadType: state,
        );
        final destination = Settings();
        adapter.importInto(destination, adapter.export(source));
        expect(destination.libraryFilterMangasDownloadType, state);
        expect(destination.libraryFilterAnimeUnreadType, state);
      }

      for (final channel in AudioChannel.values) {
        final source = Settings(audioChannels: channel);
        final destination = Settings();
        adapter.importInto(destination, adapter.export(source));
        expect(destination.audioChannels, channel);
      }

      for (final debanding in DebandingType.values) {
        final source = Settings(debandingType: debanding);
        final destination = Settings();
        adapter.importInto(destination, adapter.export(source));
        expect(destination.debandingType, debanding);
      }

      for (final pageMode in [PageMode.onePage, PageMode.doublePage]) {
        final source = Settings(defaultPageMode: pageMode);
        final destination = Settings(defaultPageMode: PageMode.doublePageCover);
        adapter.importInto(destination, adapter.export(source));
        expect(destination.defaultPageMode, pageMode);
      }
    });
  });
}

Settings _fullyMappedSettings() => Settings(
  displayType: DisplayType.list,
  animeDisplayType: DisplayType.coverOnlyGrid,
  novelDisplayType: DisplayType.coverOnlyGrid,
  mangaGridSize: 3,
  animeGridSize: 4,
  sortLibraryManga: SortLibraryManga(index: 5, reverse: true),
  sortLibraryAnime: SortLibraryManga(index: 1, reverse: false),
  libraryFilterMangasDownloadType: 2,
  libraryFilterMangasUnreadType: 1,
  libraryFilterMangasStartedType: 2,
  libraryFilterMangasBookMarkedType: 1,
  libraryFilterMangasCompletedType: 2,
  libraryFilterAnimeDownloadType: 1,
  libraryFilterAnimeUnreadType: 1,
  libraryFilterAnimeStartedType: 2,
  libraryFilterAnimeBookMarkedType: 1,
  libraryFilterAnimeCompletedType: 2,
  libraryDownloadedChapters: true,
  libraryShowLanguage: true,
  libraryLocalSource: true,
  libraryShowContinueReadingButton: true,
  libraryShowCategoryTabs: true,
  libraryShowNumbersOfItems: true,
  animeLibraryDownloadedChapters: true,
  animeLibraryShowLanguage: true,
  animeLibraryLocalSource: false,
  animeLibraryShowContinueReadingButton: true,
  animeLibraryShowCategoryTabs: true,
  animeLibraryShowNumbersOfItems: true,
  novelLibraryShowCategoryTabs: true,
  novelLibraryShowNumbersOfItems: true,
  followSystemTheme: true,
  themeIsDark: true,
  pureBlackDarkMode: true,
  dateFormat: 'yyyy-MM-dd',
  animatePageTransitions: false,
  doubleTapAnimationSpeed: 2,
  showPagesNumber: false,
  fullScreenReader: true,
  keepScreenOnReader: false,
  defaultReaderMode: ReaderMode.horizontalPaged,
  defaultReadingDirectionIndex: ReadingDirection.rightToLeft.index,
  defaultPageMode: PageMode.doublePage,
  scaleType: ScaleType.smartFit,
  backgroundColor: BackgroundColor.grey,
  cropBorders: true,
  enableCustomColorFilter: true,
  customColorFilter: CustomColorFilter(a: 128, r: 1, g: 2, b: 3),
  colorFilterBlendMode: ColorFilterBlendMode.darken,
  webtoonSidePadding: 17,
  invertColors: true,
  grayscale: true,
  readerNavigationLayout: 4,
  pagePreloadAmount: 9,
  downloadOnlyOnWifi: true,
  saveAsCBZArchive: true,
  concurrentDownloads: 4,
  deleteDownloadAfterReading: true,
  userAgent: 'Mangatan compatibility test',
  doHEnabled: true,
  doHProviderId: 11,
  showNSFW: true,
  clearChapterCacheOnAppLaunch: true,
  enableLogs: true,
  enableDiscordRpc: false,
  rpcShowReadingWatchingProgress: true,
  updateProgressAfterReading: false,
  markEpisodeAsSeenType: 73,
  defaultSkipIntroLength: 91,
  defaultDoubleTapToSkipLength: 12,
  defaultPlayBackSpeed: 1.25,
  fullScreenPlayer: true,
  enableAniSkip: true,
  enableAutoSkip: false,
  aniSkipTimeoutLength: 7,
  audioPreferredLanguages: 'ja,en',
  enableAudioPitchCorrection: false,
  audioChannels: AudioChannel.reverseStereo,
  volumeBoostCap: 42,
  debandingType: DebandingType.gpu,
  enableHardwareAcceleration: true,
  enableGpuNext: true,
  useYUV420P: true,
  playerSubtitleSettings: PlayerSubtitleSettings(
    fontSize: 51,
    position: 13,
    useBold: false,
    useItalic: true,
    textColorA: 255,
    textColorR: 128,
    textColorG: 64,
    textColorB: 32,
    borderColorA: 127,
    borderColorR: 16,
    borderColorG: 32,
    borderColorB: 48,
    backgroundColorA: 128,
    backgroundColorR: 1,
    backgroundColorG: 2,
    backgroundColorB: 3,
  ),
  backupFrequency: 5,
)..novelGridSize = 5;

Map<String, DecodedChimahonPreference> _decode(
  Iterable<BackupPreference> preferences,
) => {
  for (final preference in preferences)
    preference.key: const ChimahonPreferenceCodec().decode(preference),
};

Map<String, Object?> _values(Iterable<BackupPreference> preferences) => {
  for (final entry in _decode(preferences).entries)
    entry.key: entry.value.value,
};
