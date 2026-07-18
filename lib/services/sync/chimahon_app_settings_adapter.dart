import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

/// The portable values produced from one local settings snapshot, plus keys
/// whose current non-null local values cannot be represented by Chimahon.
///
/// The distinction matters during sync: an intentionally absent supported
/// value is a deletion, while an unrepresentable value must stay local and
/// leave the last valid Chimahon value untouched.
class ChimahonAppSettingsProjection {
  ChimahonAppSettingsProjection({
    required Iterable<BackupPreference> preferences,
    required Iterable<String> unrepresentableKeys,
  }) : preferences = List.unmodifiable(preferences),
       unrepresentableKeys = Set.unmodifiable(unrepresentableKeys);

  final List<BackupPreference> preferences;
  final Set<String> unrepresentableKeys;
}

/// Pure, storage-agnostic translation between Mangatan settings and Chimahon's
/// backed-up app preferences.
///
/// This deliberately exposes an explicit allowlist. Settings without a
/// lossless Chimahon representation stay local, and unsupported incoming
/// values leave the corresponding Mangatan field untouched.
class ChimahonAppSettingsAdapter {
  const ChimahonAppSettingsAdapter({
    this.codec = const ChimahonPreferenceCodec(),
  });

  final ChimahonPreferenceCodec codec;

  static const supportedKeys = <String>{
    'pref_theme_mode_key',
    'pref_theme_dark_amoled_key',
    'app_date_format',
    'pref_display_mode_library',
    'pref_display_mode_animelib',
    'pref_novel_display_mode_library',
    'pref_library_columns_portrait_key',
    'pref_library_columns_landscape_key',
    'pref_animelib_columns_portrait_key',
    'pref_animelib_columns_landscape_key',
    'pref_novel_library_columns_portrait_key',
    'pref_novel_library_columns_landscape_key',
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
    'pref_double_tap_anim_speed',
    'pref_show_page_number_key',
    'fullscreen',
    'pref_keep_screen_on_key',
    'pref_default_reading_mode_key',
    'page_layout',
    'pref_image_scale_type_key',
    'pref_reader_theme_key',
    'crop_borders',
    'crop_borders_webtoon',
    'webtoon_side_padding',
    'pref_inverted_colors',
    'pref_grayscale',
    'pref_color_filter_key',
    'color_filter_value',
    'color_filter_mode',
    'reader_navigation_mode_pager',
    'reader_navigation_mode_webtoon',
    'eh_preload_size',
    'pref_download_only_over_wifi_key',
    'save_chapter_as_cbz',
    'download_slots',
    'remove_after_read_slots',
    'default_user_agent',
    'doh_provider',
    'show_nsfw_source',
    'auto_clear_chapter_cache',
    'verbose_logging',
    'pref_enable_discord_rpc',
    'pref_discord_show_progress',
    'pref_auto_update_manga_sync_key',
    'pref_progress_preference',
    'pref_default_intro_length',
    'pref_skip_length_preference',
    'pref_player_speed',
    'player_fullscreen',
    'pref_enable_ani_skip',
    'pref_enable_auto_skip_ani_skip',
    'pref_waiting_time_aniskip',
    'pref_audio_lang',
    'pref_audio_pitch_correction',
    'pref_audio_config',
    'pref_audio_volume_boost_cap',
    'pref_video_debanding',
    'pref_try_hwdec',
    'pref_gpu_next',
    'use_yuv420p',
    'pref_subtitles_font_size',
    'pref_bold_subtitles',
    'pref_italic_subtitles',
    'pref_text_color_subtitles',
    'pref_border_color_subtitles',
    'pref_background_color_subtitles',
    'backup_interval',
  };

  static const _displayModeToWire = <DisplayType, String>{
    DisplayType.compactGrid: 'COMPACT_GRID',
    DisplayType.comfortableGrid: 'COMFORTABLE_GRID',
    DisplayType.coverOnlyGrid: 'COVER_ONLY_GRID',
    DisplayType.list: 'LIST',
  };
  static const _displayModeFromWire = <String, DisplayType>{
    'COMPACT_GRID': DisplayType.compactGrid,
    'COMFORTABLE_GRID': DisplayType.comfortableGrid,
    'COVER_ONLY_GRID': DisplayType.coverOnlyGrid,
    'LIST': DisplayType.list,
  };
  static const _sortTypeToWire = <int, String>{
    0: 'ALPHABETICAL',
    1: 'LAST_READ',
    2: 'LAST_MANGA_UPDATE',
    3: 'UNREAD_COUNT',
    4: 'TOTAL_CHAPTERS',
    5: 'LATEST_CHAPTER',
    6: 'DATE_ADDED',
  };
  static const _sortTypeFromWire = <String, int>{
    'ALPHABETICAL': 0,
    'LAST_READ': 1,
    'LAST_MANGA_UPDATE': 2,
    'UNREAD_COUNT': 3,
    'TOTAL_CHAPTERS': 4,
    'LATEST_CHAPTER': 5,
    'DATE_ADDED': 6,
  };
  static const _triStateToWire = <int, String>{
    0: 'DISABLED',
    1: 'ENABLED_IS',
    2: 'ENABLED_NOT',
  };
  static const _triStateFromWire = <String, int>{
    'DISABLED': 0,
    'ENABLED_IS': 1,
    'ENABLED_NOT': 2,
  };
  static const _doubleTapToWire = <int, int>{0: 1, 1: 500, 2: 250};
  static const _doubleTapFromWire = <int, int>{1: 0, 500: 1, 250: 2};
  static const _backgroundToWire = <BackgroundColor, int>{
    BackgroundColor.white: 0,
    BackgroundColor.black: 1,
    BackgroundColor.grey: 2,
    BackgroundColor.automatic: 3,
  };
  static const _backgroundFromWire = <int, BackgroundColor>{
    0: BackgroundColor.white,
    1: BackgroundColor.black,
    2: BackgroundColor.grey,
    3: BackgroundColor.automatic,
  };
  static const _colorFilterModeToWire = <ColorFilterBlendMode, int>{
    ColorFilterBlendMode.none: 0,
    ColorFilterBlendMode.multiply: 1,
    ColorFilterBlendMode.screen: 2,
    ColorFilterBlendMode.overlay: 3,
    ColorFilterBlendMode.lighten: 4,
    ColorFilterBlendMode.darken: 5,
  };
  static const _colorFilterModeFromWire = <int, ColorFilterBlendMode>{
    0: ColorFilterBlendMode.none,
    1: ColorFilterBlendMode.multiply,
    2: ColorFilterBlendMode.screen,
    3: ColorFilterBlendMode.overlay,
    4: ColorFilterBlendMode.lighten,
    5: ColorFilterBlendMode.darken,
  };
  static const _audioChannelToWire = <AudioChannel, String>{
    AudioChannel.auto: 'Auto',
    AudioChannel.autoSafe: 'AutoSafe',
    AudioChannel.mono: 'Mono',
    AudioChannel.stereo: 'Stereo',
    AudioChannel.reverseStereo: 'ReverseStereo',
  };
  static const _audioChannelFromWire = <String, AudioChannel>{
    'Auto': AudioChannel.auto,
    'AutoSafe': AudioChannel.autoSafe,
    'Mono': AudioChannel.mono,
    'Stereo': AudioChannel.stereo,
    'ReverseStereo': AudioChannel.reverseStereo,
  };
  static const _debandingToWire = <DebandingType, String>{
    DebandingType.none: 'None',
    DebandingType.cpu: 'CPU',
    DebandingType.gpu: 'GPU',
  };
  static const _debandingFromWire = <String, DebandingType>{
    'None': DebandingType.none,
    'CPU': DebandingType.cpu,
    'GPU': DebandingType.gpu,
  };
  static const _pageLayoutToWire = <PageMode, int>{
    PageMode.onePage: 0,
    PageMode.doublePage: 1,
  };
  static const _pageLayoutFromWire = <int, PageMode>{
    0: PageMode.onePage,
    1: PageMode.doublePage,
  };
  static const _backupFrequencyToWire = <int, int>{
    0: 0,
    1: 6,
    2: 12,
    3: 24,
    4: 48,
    5: 168,
  };
  static const _backupFrequencyFromWire = <int, int>{
    0: 0,
    6: 1,
    12: 2,
    24: 3,
    48: 4,
    168: 5,
  };

  List<BackupPreference> export(Settings settings) =>
      project(settings).preferences;

  ChimahonAppSettingsProjection project(Settings settings) {
    final values = <String, Object>{};
    final unrepresentableKeys = <String>{};

    values['pref_theme_mode_key'] = settings.followSystemTheme == true
        ? 'SYSTEM'
        : settings.themeIsDark == true
        ? 'DARK'
        : 'LIGHT';
    _put(values, 'pref_theme_dark_amoled_key', settings.pureBlackDarkMode);
    _put(values, 'app_date_format', settings.dateFormat);

    values['pref_display_mode_library'] =
        _displayModeToWire[settings.displayType]!;
    values['pref_display_mode_animelib'] =
        _displayModeToWire[settings.animeDisplayType]!;
    values['pref_novel_display_mode_library'] =
        _displayModeToWire[settings.novelDisplayType]!;
    _putGridColumns(
      values,
      portraitKey: 'pref_library_columns_portrait_key',
      landscapeKey: 'pref_library_columns_landscape_key',
      columns: settings.mangaGridSize,
      unrepresentableKeys: unrepresentableKeys,
    );
    _putGridColumns(
      values,
      portraitKey: 'pref_animelib_columns_portrait_key',
      landscapeKey: 'pref_animelib_columns_landscape_key',
      columns: settings.animeGridSize,
      unrepresentableKeys: unrepresentableKeys,
    );
    _putGridColumns(
      values,
      portraitKey: 'pref_novel_library_columns_portrait_key',
      landscapeKey: 'pref_novel_library_columns_landscape_key',
      columns: settings.novelGridSize,
      unrepresentableKeys: unrepresentableKeys,
    );
    _putSort(
      values,
      'library_sorting_mode',
      settings.sortLibraryManga,
      unrepresentableKeys,
    );
    _putSort(
      values,
      'animelib_sorting_mode',
      settings.sortLibraryAnime,
      unrepresentableKeys,
    );

    _putTriState(
      values,
      'pref_filter_library_downloaded_v2',
      settings.libraryFilterMangasDownloadType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_library_unread_v2',
      settings.libraryFilterMangasUnreadType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_library_started_v2',
      settings.libraryFilterMangasStartedType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_library_bookmarked_v2',
      settings.libraryFilterMangasBookMarkedType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_library_completed_v2',
      settings.libraryFilterMangasCompletedType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_animelib_downloaded_v2',
      settings.libraryFilterAnimeDownloadType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_animelib_unseen_v2',
      settings.libraryFilterAnimeUnreadType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_animelib_started_v2',
      settings.libraryFilterAnimeStartedType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_animelib_bookmarked_v2',
      settings.libraryFilterAnimeBookMarkedType,
      unrepresentableKeys,
    );
    _putTriState(
      values,
      'pref_filter_animelib_completed_v2',
      settings.libraryFilterAnimeCompletedType,
      unrepresentableKeys,
    );

    _put(values, 'display_download_badge', settings.libraryDownloadedChapters);
    _put(values, 'display_language_badge', settings.libraryShowLanguage);
    _put(values, 'display_local_badge', settings.libraryLocalSource);
    _put(
      values,
      'display_continue_reading_button',
      settings.libraryShowContinueReadingButton,
    );
    _put(values, 'display_category_tabs', settings.libraryShowCategoryTabs);
    _put(values, 'display_number_of_items', settings.libraryShowNumbersOfItems);
    _put(
      values,
      'display_animelib_download_badge',
      settings.animeLibraryDownloadedChapters,
    );
    _put(
      values,
      'display_animelib_language_badge',
      settings.animeLibraryShowLanguage,
    );
    _put(
      values,
      'display_animelib_local_badge',
      settings.animeLibraryLocalSource,
    );
    _put(
      values,
      'display_continue_watching_button',
      settings.animeLibraryShowContinueReadingButton,
    );
    _put(
      values,
      'display_anime_category_tabs',
      settings.animeLibraryShowCategoryTabs,
    );
    _put(
      values,
      'display_anime_number_of_items',
      settings.animeLibraryShowNumbersOfItems,
    );
    _put(
      values,
      'display_novel_category_tabs',
      settings.novelLibraryShowCategoryTabs,
    );
    _put(
      values,
      'display_novel_number_of_items',
      settings.novelLibraryShowNumbersOfItems,
    );

    final transitions = settings.animatePageTransitions;
    if (transitions != null) {
      values['pref_enable_transitions_pager_key'] = transitions;
      values['pref_enable_transitions_webtoon_key'] = transitions;
    }
    final doubleTap = _doubleTapToWire[settings.doubleTapAnimationSpeed];
    _put(values, 'pref_double_tap_anim_speed', doubleTap);
    if (settings.doubleTapAnimationSpeed != null && doubleTap == null) {
      unrepresentableKeys.add('pref_double_tap_anim_speed');
    }
    _put(values, 'pref_show_page_number_key', settings.showPagesNumber);
    _put(values, 'fullscreen', settings.fullScreenReader);
    _put(values, 'pref_keep_screen_on_key', settings.keepScreenOnReader);
    final readerMode = _exportReaderMode(settings);
    _put(values, 'pref_default_reading_mode_key', readerMode);
    if (readerMode == null) {
      unrepresentableKeys.add('pref_default_reading_mode_key');
    }
    final pageLayout = _pageLayoutToWire[settings.defaultPageMode];
    _put(values, 'page_layout', pageLayout);
    if (pageLayout == null) unrepresentableKeys.add('page_layout');
    values['pref_image_scale_type_key'] = settings.scaleType.index + 1;
    values['pref_reader_theme_key'] =
        _backgroundToWire[settings.backgroundColor]!;
    final cropBorders = settings.cropBorders;
    if (cropBorders != null) {
      // Mangatan has one crop toggle for every reader layout. Chimahon stores
      // paged and webtoon values separately, so emit the same value for both.
      values['crop_borders'] = cropBorders;
      values['crop_borders_webtoon'] = cropBorders;
    }
    _put(values, 'webtoon_side_padding', settings.webtoonSidePadding);
    _put(values, 'pref_inverted_colors', settings.invertColors);
    _put(values, 'pref_grayscale', settings.grayscale);
    _put(values, 'pref_color_filter_key', settings.enableCustomColorFilter);
    final customColor = settings.customColorFilter;
    if (customColor != null) {
      _putColor(
        values,
        'color_filter_value',
        customColor.a,
        customColor.r,
        customColor.g,
        customColor.b,
        unrepresentableKeys: unrepresentableKeys,
      );
    }
    _put(
      values,
      'color_filter_mode',
      _colorFilterModeToWire[settings.colorFilterBlendMode],
    );
    final navigation = settings.readerNavigationLayout;
    if (navigation != null && navigation >= 0 && navigation <= 5) {
      values['reader_navigation_mode_pager'] = navigation;
      values['reader_navigation_mode_webtoon'] = navigation;
    } else if (navigation != null) {
      unrepresentableKeys.addAll(const {
        'reader_navigation_mode_pager',
        'reader_navigation_mode_webtoon',
      });
    }
    _put(values, 'eh_preload_size', settings.pagePreloadAmount);

    _put(
      values,
      'pref_download_only_over_wifi_key',
      settings.downloadOnlyOnWifi,
    );
    _put(values, 'save_chapter_as_cbz', settings.saveAsCBZArchive);
    _put(values, 'download_slots', settings.concurrentDownloads);
    final deleteAfterReading = settings.deleteDownloadAfterReading;
    if (deleteAfterReading != null) {
      values['remove_after_read_slots'] = deleteAfterReading ? 0 : -1;
    }
    _put(values, 'default_user_agent', settings.userAgent);
    final providerId = settings.doHProviderId;
    if (settings.doHEnabled == false) {
      values['doh_provider'] = -1;
    } else if (settings.doHEnabled == true &&
        providerId != null &&
        providerId >= 0 &&
        providerId <= 11) {
      values['doh_provider'] = providerId + 1;
    } else if (settings.doHEnabled == true) {
      unrepresentableKeys.add('doh_provider');
    }
    _put(values, 'show_nsfw_source', settings.showNSFW);
    _put(
      values,
      'auto_clear_chapter_cache',
      settings.clearChapterCacheOnAppLaunch,
    );
    _put(values, 'verbose_logging', settings.enableLogs);
    _put(values, 'pref_enable_discord_rpc', settings.enableDiscordRpc);
    _put(
      values,
      'pref_discord_show_progress',
      settings.rpcShowReadingWatchingProgress,
    );
    _put(
      values,
      'pref_auto_update_manga_sync_key',
      settings.updateProgressAfterReading,
    );

    final seenPercent = settings.markEpisodeAsSeenType;
    if (seenPercent != null && seenPercent >= 0 && seenPercent <= 100) {
      values['pref_progress_preference'] = seenPercent / 100;
    } else if (seenPercent != null) {
      unrepresentableKeys.add('pref_progress_preference');
    }
    _put(values, 'pref_default_intro_length', settings.defaultSkipIntroLength);
    _put(
      values,
      'pref_skip_length_preference',
      settings.defaultDoubleTapToSkipLength,
    );
    _put(values, 'pref_player_speed', settings.defaultPlayBackSpeed);
    _put(values, 'player_fullscreen', settings.fullScreenPlayer);
    _put(values, 'pref_enable_ani_skip', settings.enableAniSkip);
    _put(values, 'pref_enable_auto_skip_ani_skip', settings.enableAutoSkip);
    _put(values, 'pref_waiting_time_aniskip', settings.aniSkipTimeoutLength);
    _put(values, 'pref_audio_lang', settings.audioPreferredLanguages);
    _put(
      values,
      'pref_audio_pitch_correction',
      settings.enableAudioPitchCorrection,
    );
    values['pref_audio_config'] = _audioChannelToWire[settings.audioChannels]!;
    _put(values, 'pref_audio_volume_boost_cap', settings.volumeBoostCap);
    values['pref_video_debanding'] = _debandingToWire[settings.debandingType]!;
    _put(values, 'pref_try_hwdec', settings.enableHardwareAcceleration);
    _put(values, 'pref_gpu_next', settings.enableGpuNext);
    _put(values, 'use_yuv420p', settings.useYUV420P);

    final subtitles = settings.playerSubtitleSettings;
    if (subtitles != null) {
      _put(values, 'pref_subtitles_font_size', subtitles.fontSize);
      _put(values, 'pref_bold_subtitles', subtitles.useBold);
      _put(values, 'pref_italic_subtitles', subtitles.useItalic);
      _putColor(
        values,
        'pref_text_color_subtitles',
        subtitles.textColorA,
        subtitles.textColorR,
        subtitles.textColorG,
        subtitles.textColorB,
        unrepresentableKeys: unrepresentableKeys,
      );
      _putColor(
        values,
        'pref_border_color_subtitles',
        subtitles.borderColorA,
        subtitles.borderColorR,
        subtitles.borderColorG,
        subtitles.borderColorB,
        unrepresentableKeys: unrepresentableKeys,
      );
      _putColor(
        values,
        'pref_background_color_subtitles',
        subtitles.backgroundColorA,
        subtitles.backgroundColorR,
        subtitles.backgroundColorG,
        subtitles.backgroundColorB,
        unrepresentableKeys: unrepresentableKeys,
      );
    }

    final backupFrequency = _backupFrequencyToWire[settings.backupFrequency];
    _put(values, 'backup_interval', backupFrequency);
    if (settings.backupFrequency != null && backupFrequency == null) {
      unrepresentableKeys.add('backup_interval');
    }

    assert(values.keys.every(supportedKeys.contains));
    assert(unrepresentableKeys.every(supportedKeys.contains));
    assert(unrepresentableKeys.every((key) => !values.containsKey(key)));
    return ChimahonAppSettingsProjection(
      preferences: [
        for (final entry in values.entries)
          codec.encode(entry.key, entry.value),
      ],
      unrepresentableKeys: unrepresentableKeys,
    );
  }

  /// Applies only understood, correctly typed Chimahon values to [settings].
  /// The object is mutated so callers can preserve Isar links and control the
  /// transaction in which it is persisted.
  void importInto(
    Settings settings,
    Iterable<BackupPreference> preferences, {
    Set<String> preserveLocalKeys = const {},
  }) {
    final decoded = _decodeKnown(
      preferences.where(
        (preference) => !preserveLocalKeys.contains(preference.key),
      ),
    );

    final theme = _string(decoded, 'pref_theme_mode_key');
    switch (theme) {
      case 'SYSTEM':
        settings.followSystemTheme = true;
      case 'LIGHT':
        settings
          ..followSystemTheme = false
          ..themeIsDark = false;
      case 'DARK':
        settings
          ..followSystemTheme = false
          ..themeIsDark = true;
    }
    _applyBool(
      decoded,
      'pref_theme_dark_amoled_key',
      (value) => settings.pureBlackDarkMode = value,
    );
    _applyString(
      decoded,
      'app_date_format',
      (value) => settings.dateFormat = value,
    );

    _applyDisplayMode(
      decoded,
      'pref_display_mode_library',
      (value) => settings.displayType = value,
    );
    _applyDisplayMode(
      decoded,
      'pref_display_mode_animelib',
      (value) => settings.animeDisplayType = value,
    );
    _applyDisplayMode(
      decoded,
      'pref_novel_display_mode_library',
      (value) => settings.novelDisplayType = value,
    );
    _applyGridColumns(
      decoded,
      portraitKey: 'pref_library_columns_portrait_key',
      landscapeKey: 'pref_library_columns_landscape_key',
      assign: (value) => settings.mangaGridSize = value,
    );
    _applyGridColumns(
      decoded,
      portraitKey: 'pref_animelib_columns_portrait_key',
      landscapeKey: 'pref_animelib_columns_landscape_key',
      assign: (value) => settings.animeGridSize = value,
    );
    _applyGridColumns(
      decoded,
      portraitKey: 'pref_novel_library_columns_portrait_key',
      landscapeKey: 'pref_novel_library_columns_landscape_key',
      assign: (value) => settings.novelGridSize = value,
    );
    _applySort(
      decoded,
      'library_sorting_mode',
      (value) => settings.sortLibraryManga = value,
    );
    _applySort(
      decoded,
      'animelib_sorting_mode',
      (value) => settings.sortLibraryAnime = value,
    );

    _applyTriState(
      decoded,
      'pref_filter_library_downloaded_v2',
      (value) => settings.libraryFilterMangasDownloadType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_library_unread_v2',
      (value) => settings.libraryFilterMangasUnreadType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_library_started_v2',
      (value) => settings.libraryFilterMangasStartedType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_library_bookmarked_v2',
      (value) => settings.libraryFilterMangasBookMarkedType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_library_completed_v2',
      (value) => settings.libraryFilterMangasCompletedType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_animelib_downloaded_v2',
      (value) => settings.libraryFilterAnimeDownloadType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_animelib_unseen_v2',
      (value) => settings.libraryFilterAnimeUnreadType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_animelib_started_v2',
      (value) => settings.libraryFilterAnimeStartedType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_animelib_bookmarked_v2',
      (value) => settings.libraryFilterAnimeBookMarkedType = value,
    );
    _applyTriState(
      decoded,
      'pref_filter_animelib_completed_v2',
      (value) => settings.libraryFilterAnimeCompletedType = value,
    );

    _applyBool(
      decoded,
      'display_download_badge',
      (value) => settings.libraryDownloadedChapters = value,
    );
    _applyBool(
      decoded,
      'display_language_badge',
      (value) => settings.libraryShowLanguage = value,
    );
    _applyBool(
      decoded,
      'display_local_badge',
      (value) => settings.libraryLocalSource = value,
    );
    _applyBool(
      decoded,
      'display_continue_reading_button',
      (value) => settings.libraryShowContinueReadingButton = value,
    );
    _applyBool(
      decoded,
      'display_category_tabs',
      (value) => settings.libraryShowCategoryTabs = value,
    );
    _applyBool(
      decoded,
      'display_number_of_items',
      (value) => settings.libraryShowNumbersOfItems = value,
    );
    _applyBool(
      decoded,
      'display_animelib_download_badge',
      (value) => settings.animeLibraryDownloadedChapters = value,
    );
    _applyBool(
      decoded,
      'display_animelib_language_badge',
      (value) => settings.animeLibraryShowLanguage = value,
    );
    _applyBool(
      decoded,
      'display_animelib_local_badge',
      (value) => settings.animeLibraryLocalSource = value,
    );
    _applyBool(
      decoded,
      'display_continue_watching_button',
      (value) => settings.animeLibraryShowContinueReadingButton = value,
    );
    _applyBool(
      decoded,
      'display_anime_category_tabs',
      (value) => settings.animeLibraryShowCategoryTabs = value,
    );
    _applyBool(
      decoded,
      'display_anime_number_of_items',
      (value) => settings.animeLibraryShowNumbersOfItems = value,
    );
    _applyBool(
      decoded,
      'display_novel_category_tabs',
      (value) => settings.novelLibraryShowCategoryTabs = value,
    );
    _applyBool(
      decoded,
      'display_novel_number_of_items',
      (value) => settings.novelLibraryShowNumbersOfItems = value,
    );

    final pagerTransitions = _boolean(
      decoded,
      'pref_enable_transitions_pager_key',
    );
    final webtoonTransitions = _boolean(
      decoded,
      'pref_enable_transitions_webtoon_key',
    );
    if (pagerTransitions != null && pagerTransitions == webtoonTransitions) {
      settings.animatePageTransitions = pagerTransitions;
    }
    final doubleTap = _integer(decoded, 'pref_double_tap_anim_speed');
    final localDoubleTap = _doubleTapFromWire[doubleTap];
    if (localDoubleTap != null) {
      settings.doubleTapAnimationSpeed = localDoubleTap;
    }
    _applyBool(
      decoded,
      'pref_show_page_number_key',
      (value) => settings.showPagesNumber = value,
    );
    _applyBool(
      decoded,
      'fullscreen',
      (value) => settings.fullScreenReader = value,
    );
    _applyBool(
      decoded,
      'pref_keep_screen_on_key',
      (value) => settings.keepScreenOnReader = value,
    );
    _importReaderMode(
      settings,
      _integer(decoded, 'pref_default_reading_mode_key'),
    );
    final pageLayout = _pageLayoutFromWire[_integer(decoded, 'page_layout')];
    if (pageLayout != null) settings.defaultPageMode = pageLayout;
    final scaleType = _integer(decoded, 'pref_image_scale_type_key');
    if (scaleType != null &&
        scaleType >= 1 &&
        scaleType <= ScaleType.values.length) {
      settings.scaleType = ScaleType.values[scaleType - 1];
    }
    final background =
        _backgroundFromWire[_integer(decoded, 'pref_reader_theme_key')];
    if (background != null) settings.backgroundColor = background;
    final pagedCropBorders = _boolean(decoded, 'crop_borders');
    final webtoonCropBorders = _boolean(decoded, 'crop_borders_webtoon');
    if (pagedCropBorders != null && pagedCropBorders == webtoonCropBorders) {
      settings.cropBorders = pagedCropBorders;
    }
    _applyInt(
      decoded,
      'webtoon_side_padding',
      (value) => settings.webtoonSidePadding = value,
    );
    _applyBool(
      decoded,
      'pref_inverted_colors',
      (value) => settings.invertColors = value,
    );
    _applyBool(
      decoded,
      'pref_grayscale',
      (value) => settings.grayscale = value,
    );
    _applyBool(
      decoded,
      'pref_color_filter_key',
      (value) => settings.enableCustomColorFilter = value,
    );
    final customColor = _integer(decoded, 'color_filter_value');
    if (customColor != null) {
      final unsigned = customColor & 0xffffffff;
      settings.customColorFilter = CustomColorFilter(
        a: (unsigned >> 24) & 0xff,
        r: (unsigned >> 16) & 0xff,
        g: (unsigned >> 8) & 0xff,
        b: unsigned & 0xff,
      );
    }
    final colorFilterMode =
        _colorFilterModeFromWire[_integer(decoded, 'color_filter_mode')];
    if (colorFilterMode != null) {
      settings.colorFilterBlendMode = colorFilterMode;
    }
    final pagerNavigation = _integer(decoded, 'reader_navigation_mode_pager');
    final webtoonNavigation = _integer(
      decoded,
      'reader_navigation_mode_webtoon',
    );
    if (pagerNavigation != null &&
        pagerNavigation == webtoonNavigation &&
        pagerNavigation >= 0 &&
        pagerNavigation <= 5) {
      settings.readerNavigationLayout = pagerNavigation;
    }
    _applyInt(
      decoded,
      'eh_preload_size',
      (value) => settings.pagePreloadAmount = value,
    );

    _applyBool(
      decoded,
      'pref_download_only_over_wifi_key',
      (value) => settings.downloadOnlyOnWifi = value,
    );
    _applyBool(
      decoded,
      'save_chapter_as_cbz',
      (value) => settings.saveAsCBZArchive = value,
    );
    _applyInt(
      decoded,
      'download_slots',
      (value) => settings.concurrentDownloads = value,
    );
    final removeAfterRead = _integer(decoded, 'remove_after_read_slots');
    if (removeAfterRead == 0) {
      settings.deleteDownloadAfterReading = true;
    } else if (removeAfterRead == -1) {
      settings.deleteDownloadAfterReading = false;
    }
    _applyString(
      decoded,
      'default_user_agent',
      (value) => settings.userAgent = value,
    );
    final doh = _integer(decoded, 'doh_provider');
    if (doh == -1) {
      settings.doHEnabled = false;
    } else if (doh != null && doh >= 1 && doh <= 12) {
      settings
        ..doHEnabled = true
        ..doHProviderId = doh - 1;
    }
    _applyBool(
      decoded,
      'show_nsfw_source',
      (value) => settings.showNSFW = value,
    );
    _applyBool(
      decoded,
      'auto_clear_chapter_cache',
      (value) => settings.clearChapterCacheOnAppLaunch = value,
    );
    _applyBool(
      decoded,
      'verbose_logging',
      (value) => settings.enableLogs = value,
    );
    _applyBool(
      decoded,
      'pref_enable_discord_rpc',
      (value) => settings.enableDiscordRpc = value,
    );
    _applyBool(
      decoded,
      'pref_discord_show_progress',
      (value) => settings.rpcShowReadingWatchingProgress = value,
    );
    _applyBool(
      decoded,
      'pref_auto_update_manga_sync_key',
      (value) => settings.updateProgressAfterReading = value,
    );

    final progress = _floating(decoded, 'pref_progress_preference');
    if (progress != null && progress >= 0 && progress <= 1) {
      final percent = progress * 100;
      final rounded = percent.round();
      if ((percent - rounded).abs() < 0.0001) {
        settings.markEpisodeAsSeenType = rounded;
      }
    }
    _applyInt(
      decoded,
      'pref_default_intro_length',
      (value) => settings.defaultSkipIntroLength = value,
    );
    _applyInt(
      decoded,
      'pref_skip_length_preference',
      (value) => settings.defaultDoubleTapToSkipLength = value,
    );
    _applyFloat(
      decoded,
      'pref_player_speed',
      (value) => settings.defaultPlayBackSpeed = value,
    );
    _applyBool(
      decoded,
      'player_fullscreen',
      (value) => settings.fullScreenPlayer = value,
    );
    _applyBool(
      decoded,
      'pref_enable_ani_skip',
      (value) => settings.enableAniSkip = value,
    );
    _applyBool(
      decoded,
      'pref_enable_auto_skip_ani_skip',
      (value) => settings.enableAutoSkip = value,
    );
    _applyInt(
      decoded,
      'pref_waiting_time_aniskip',
      (value) => settings.aniSkipTimeoutLength = value,
    );
    _applyString(
      decoded,
      'pref_audio_lang',
      (value) => settings.audioPreferredLanguages = value,
    );
    _applyBool(
      decoded,
      'pref_audio_pitch_correction',
      (value) => settings.enableAudioPitchCorrection = value,
    );
    final audioChannel =
        _audioChannelFromWire[_string(decoded, 'pref_audio_config')];
    if (audioChannel != null) settings.audioChannels = audioChannel;
    _applyInt(
      decoded,
      'pref_audio_volume_boost_cap',
      (value) => settings.volumeBoostCap = value,
    );
    final debanding =
        _debandingFromWire[_string(decoded, 'pref_video_debanding')];
    if (debanding != null) settings.debandingType = debanding;
    _applyBool(
      decoded,
      'pref_try_hwdec',
      (value) => settings.enableHardwareAcceleration = value,
    );
    _applyBool(
      decoded,
      'pref_gpu_next',
      (value) => settings.enableGpuNext = value,
    );
    _applyBool(decoded, 'use_yuv420p', (value) => settings.useYUV420P = value);

    _importSubtitles(settings, decoded);

    final backupFrequency =
        _backupFrequencyFromWire[_integer(decoded, 'backup_interval')];
    if (backupFrequency != null) settings.backupFrequency = backupFrequency;
  }

  Map<String, DecodedChimahonPreference> _decodeKnown(
    Iterable<BackupPreference> preferences,
  ) {
    final result = <String, DecodedChimahonPreference>{};
    for (final preference in preferences) {
      if (!supportedKeys.contains(preference.key)) continue;
      try {
        result[preference.key] = codec.decode(preference);
      } on Object {
        // A malformed known envelope remains opaque in the deferred payload.
      }
    }
    return result;
  }

  void _importSubtitles(
    Settings settings,
    Map<String, DecodedChimahonPreference> decoded,
  ) {
    final fontSize = _integer(decoded, 'pref_subtitles_font_size');
    final bold = _boolean(decoded, 'pref_bold_subtitles');
    final italic = _boolean(decoded, 'pref_italic_subtitles');
    final text = _integer(decoded, 'pref_text_color_subtitles');
    final border = _integer(decoded, 'pref_border_color_subtitles');
    final background = _integer(decoded, 'pref_background_color_subtitles');
    if (fontSize == null &&
        bold == null &&
        italic == null &&
        text == null &&
        border == null &&
        background == null) {
      return;
    }

    final subtitles =
        settings.playerSubtitleSettings ?? PlayerSubtitleSettings();
    if (fontSize != null) subtitles.fontSize = fontSize;
    if (bold != null) subtitles.useBold = bold;
    if (italic != null) subtitles.useItalic = italic;
    if (text != null) _setColor(subtitles, _SubtitleColor.text, text);
    if (border != null) _setColor(subtitles, _SubtitleColor.border, border);
    if (background != null) {
      _setColor(subtitles, _SubtitleColor.background, background);
    }
    settings.playerSubtitleSettings = subtitles;
  }

  void _setColor(
    PlayerSubtitleSettings subtitles,
    _SubtitleColor target,
    int value,
  ) {
    final unsigned = value & 0xffffffff;
    final a = (unsigned >> 24) & 0xff;
    final r = (unsigned >> 16) & 0xff;
    final g = (unsigned >> 8) & 0xff;
    final b = unsigned & 0xff;
    switch (target) {
      case _SubtitleColor.text:
        subtitles
          ..textColorA = a
          ..textColorR = r
          ..textColorG = g
          ..textColorB = b;
      case _SubtitleColor.border:
        subtitles
          ..borderColorA = a
          ..borderColorR = r
          ..borderColorG = g
          ..borderColorB = b;
      case _SubtitleColor.background:
        subtitles
          ..backgroundColorA = a
          ..backgroundColorR = r
          ..backgroundColorG = g
          ..backgroundColorB = b;
    }
  }

  int? _exportReaderMode(Settings settings) {
    return switch (settings.effectiveDefaultReaderMode) {
      ReaderMode.horizontalPaged =>
        settings.effectiveDefaultReadingDirection.isRtl ? 2 : 1,
      ReaderMode.verticalPaged => 3,
      ReaderMode.webtoon => 4,
      ReaderMode.verticalContinuous => 5,
      ReaderMode.horizontalContinuous => null,
      ReaderMode.legacyHorizontalPagedRtl ||
      ReaderMode.legacyHorizontalContinuousRtl => null,
    };
  }

  void _importReaderMode(Settings settings, int? value) {
    switch (value) {
      case 1:
        settings
          ..defaultReaderMode = ReaderMode.horizontalPaged
          ..defaultReadingDirectionIndex = ReadingDirection.leftToRight.index;
      case 2:
        settings
          ..defaultReaderMode = ReaderMode.horizontalPaged
          ..defaultReadingDirectionIndex = ReadingDirection.rightToLeft.index;
      case 3:
        settings.defaultReaderMode = ReaderMode.verticalPaged;
      case 4:
        settings.defaultReaderMode = ReaderMode.webtoon;
      case 5:
        settings.defaultReaderMode = ReaderMode.verticalContinuous;
    }
  }

  void _putGridColumns(
    Map<String, Object> values, {
    required String portraitKey,
    required String landscapeKey,
    required int? columns,
    required Set<String> unrepresentableKeys,
  }) {
    if (columns == null) return;
    if (columns < 0 || columns > 7) {
      unrepresentableKeys.addAll({portraitKey, landscapeKey});
      return;
    }
    // Mangatan has one desktop grid width. Chimahon stores independent
    // portrait/landscape widths, so equal values are the lossless projection.
    values[portraitKey] = columns;
    values[landscapeKey] = columns;
  }

  void _applyGridColumns(
    Map<String, DecodedChimahonPreference> decoded, {
    required String portraitKey,
    required String landscapeKey,
    required void Function(int) assign,
  }) {
    final portrait = _integer(decoded, portraitKey);
    final landscape = _integer(decoded, landscapeKey);
    // Preserve Chimahon's richer orientation-specific configuration when it
    // cannot be represented by Mangatan's single desktop value.
    if (portrait != null &&
        portrait == landscape &&
        portrait >= 0 &&
        portrait <= 7) {
      assign(portrait);
    }
  }

  void _putSort(
    Map<String, Object> values,
    String key,
    SortLibraryManga? sort,
    Set<String> unrepresentableKeys,
  ) {
    if (sort == null) return;
    final type = _sortTypeToWire[sort.index];
    final reverse = sort.reverse;
    if (type != null && reverse != null) {
      values[key] = '$type,${reverse ? 'DESCENDING' : 'ASCENDING'}';
    } else {
      unrepresentableKeys.add(key);
    }
  }

  void _applySort(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    void Function(SortLibraryManga) assign,
  ) {
    final value = _string(decoded, key);
    if (value == null) return;
    final parts = value.split(',');
    if (parts.length != 2) return;
    final index = _sortTypeFromWire[parts[0]];
    final reverse = switch (parts[1]) {
      'ASCENDING' => false,
      'DESCENDING' => true,
      _ => null,
    };
    if (index != null && reverse != null) {
      assign(SortLibraryManga(index: index, reverse: reverse));
    }
  }

  void _putTriState(
    Map<String, Object> values,
    String key,
    int? value,
    Set<String> unrepresentableKeys,
  ) {
    final wireValue = _triStateToWire[value];
    _put(values, key, wireValue);
    if (value != null && wireValue == null) unrepresentableKeys.add(key);
  }

  void _applyTriState(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    void Function(int) assign,
  ) {
    final value = _triStateFromWire[_string(decoded, key)];
    if (value != null) assign(value);
  }

  void _applyDisplayMode(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    void Function(DisplayType) assign,
  ) {
    final value = _displayModeFromWire[_string(decoded, key)];
    if (value != null) assign(value);
  }

  void _putColor(
    Map<String, Object> values,
    String key,
    int? a,
    int? r,
    int? g,
    int? b, {
    required Set<String> unrepresentableKeys,
  }) {
    final channels = [a, r, g, b];
    if (channels.any((value) => value == null || value < 0 || value > 255)) {
      unrepresentableKeys.add(key);
      return;
    }
    final unsigned = (a! << 24) | (r! << 16) | (g! << 8) | b!;
    values[key] = unsigned >= 0x80000000 ? unsigned - 0x100000000 : unsigned;
  }

  void _put(Map<String, Object> values, String key, Object? value) {
    if (value != null) values[key] = value;
  }

  void _applyBool(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    void Function(bool) assign,
  ) {
    final value = _boolean(decoded, key);
    if (value != null) assign(value);
  }

  void _applyInt(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    void Function(int) assign,
  ) {
    final value = _integer(decoded, key);
    if (value != null) assign(value);
  }

  void _applyFloat(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    void Function(double) assign,
  ) {
    final value = _floating(decoded, key);
    if (value != null && value.isFinite) assign(value);
  }

  void _applyString(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    void Function(String) assign,
  ) {
    final value = _string(decoded, key);
    if (value != null) assign(value);
  }

  bool? _boolean(Map<String, DecodedChimahonPreference> decoded, String key) =>
      _typed<bool>(decoded, key, ChimahonPreferenceKind.boolean);

  int? _integer(Map<String, DecodedChimahonPreference> decoded, String key) =>
      _typed<int>(decoded, key, ChimahonPreferenceKind.integer);

  double? _floating(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
  ) => _typed<double>(decoded, key, ChimahonPreferenceKind.floatingPoint);

  String? _string(Map<String, DecodedChimahonPreference> decoded, String key) =>
      _typed<String>(decoded, key, ChimahonPreferenceKind.string);

  T? _typed<T>(
    Map<String, DecodedChimahonPreference> decoded,
    String key,
    ChimahonPreferenceKind kind,
  ) {
    final preference = decoded[key];
    if (preference?.kind != kind || preference?.value is! T) return null;
    return preference!.value! as T;
  }
}

enum _SubtitleColor { text, border, background }
