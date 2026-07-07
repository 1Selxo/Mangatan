import 'package:hive_flutter/adapters.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';

enum OcrEnginePreference { automatic, screenAi, googleLens, mokuroOnly }

enum DictionaryThemePreference { system, light, dark, black }

enum AnkiAudioSourceType { customUrl, customJson }

class AnkiAudioPreferences {
  const AnkiAudioPreferences({
    required this.enabled,
    required this.sourceType,
    required this.url,
    required this.timeout,
    required this.language,
  });

  static const defaultUrl =
      'http://127.0.0.1:5050/?term={term}&reading={reading}';

  static const defaults = AnkiAudioPreferences(
    enabled: false,
    sourceType: AnkiAudioSourceType.customJson,
    url: defaultUrl,
    timeout: Duration(milliseconds: 5000),
    language: 'ja',
  );

  final bool enabled;
  final AnkiAudioSourceType sourceType;
  final String url;
  final Duration timeout;
  final String language;

  AnkiAudioPreferences copyWith({
    bool? enabled,
    AnkiAudioSourceType? sourceType,
    String? url,
    Duration? timeout,
    String? language,
  }) {
    return AnkiAudioPreferences(
      enabled: enabled ?? this.enabled,
      sourceType: sourceType ?? this.sourceType,
      url: url ?? this.url,
      timeout: timeout ?? this.timeout,
      language: language ?? this.language,
    );
  }
}

class DictionaryPopupPreferences {
  const DictionaryPopupPreferences({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.theme,
    required this.eInkMode,
    required this.paginatedScrolling,
    required this.customCss,
    required this.showFrequencyHarmonic,
    required this.showFrequencyAverage,
    required this.showPitchNumber,
    required this.showPitchText,
  });

  final double width;
  final double height;
  final double fontSize;
  final DictionaryThemePreference theme;
  final bool eInkMode;
  final bool paginatedScrolling;
  final String customCss;
  final bool showFrequencyHarmonic;
  final bool showFrequencyAverage;
  final bool showPitchNumber;
  final bool showPitchText;

  DictionaryPopupPreferences copyWith({
    double? width,
    double? height,
    double? fontSize,
    DictionaryThemePreference? theme,
    bool? eInkMode,
    bool? paginatedScrolling,
    String? customCss,
    bool? showFrequencyHarmonic,
    bool? showFrequencyAverage,
    bool? showPitchNumber,
    bool? showPitchText,
  }) {
    return DictionaryPopupPreferences(
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      theme: theme ?? this.theme,
      eInkMode: eInkMode ?? this.eInkMode,
      paginatedScrolling: paginatedScrolling ?? this.paginatedScrolling,
      customCss: customCss ?? this.customCss,
      showFrequencyHarmonic:
          showFrequencyHarmonic ?? this.showFrequencyHarmonic,
      showFrequencyAverage: showFrequencyAverage ?? this.showFrequencyAverage,
      showPitchNumber: showPitchNumber ?? this.showPitchNumber,
      showPitchText: showPitchText ?? this.showPitchText,
    );
  }
}

class MiningPreferences {
  static const _boxName = 'mining_preferences';
  static const _jimakuApiKey = 'jimaku_api_key';
  static const _autoJimaku = 'auto_jimaku';
  static const _ankiEndpoint = 'anki_endpoint';
  static const _ankiProfile = 'anki_profile';
  static const _ankiAudioEnabled = 'anki_audio_enabled';
  static const _ankiAudioSourceType = 'anki_audio_source_type';
  static const _ankiAudioUrl = 'anki_audio_url';
  static const _ankiAudioTimeoutMs = 'anki_audio_timeout_ms';
  static const _ankiAudioLanguage = 'anki_audio_language';
  static const _ocrEngine = 'ocr_engine';
  static const _ocrOverlayEnabled = 'ocr_overlay_enabled';
  static const _ocrLanguage = 'ocr_language';
  static const _ocrOverlayOpacity = 'ocr_overlay_opacity';
  static const _ocrBoxScale = 'ocr_box_scale';
  static const _ocrOutlineVisible = 'ocr_outline_visible';
  static const _ocrLookupOnHover = 'ocr_lookup_on_hover';
  static const _ocrBoxScaleX = 'ocr_box_scale_x';
  static const _ocrBoxScaleY = 'ocr_box_scale_y';
  static const _dictionaryPopupWidth = 'dictionary_popup_width';
  static const _dictionaryPopupHeight = 'dictionary_popup_height';
  static const _dictionaryFontSize = 'dictionary_font_size';
  static const _dictionaryTheme = 'dictionary_theme';
  static const _dictionaryEInk = 'dictionary_eink';
  static const _dictionaryPaginated = 'dictionary_paginated';
  static const _dictionaryCustomCss = 'dictionary_custom_css';
  static const _showFrequencyHarmonic = 'dictionary_frequency_harmonic';
  static const _showFrequencyAverage = 'dictionary_frequency_average';
  static const _showPitchNumber = 'dictionary_pitch_number';
  static const _showPitchText = 'dictionary_pitch_text';

  MiningPreferences._();

  static Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static Future<Box<dynamic>?> _boxOrNull() async {
    try {
      return await _box();
    } catch (_) {
      return null;
    }
  }

  static Future<String> getJimakuApiKey() async {
    return (await _boxOrNull())?.get(_jimakuApiKey, defaultValue: '')
            as String? ??
        '';
  }

  static Future<void> setJimakuApiKey(String value) async {
    await (await _boxOrNull())?.put(_jimakuApiKey, value.trim());
  }

  static Future<bool> getAutoJimakuEnabled() async {
    return (await _boxOrNull())?.get(_autoJimaku, defaultValue: true)
            as bool? ??
        true;
  }

  static Future<void> setAutoJimakuEnabled(bool value) async {
    await (await _boxOrNull())?.put(_autoJimaku, value);
  }

  static Future<String> getJimakuTitleOverride(int? mediaId) async {
    return (await _boxOrNull())?.get(_jimakuTitleKey(mediaId), defaultValue: '')
            as String? ??
        '';
  }

  static Future<void> setJimakuTitleOverride(int? mediaId, String value) async {
    await (await _boxOrNull())?.put(_jimakuTitleKey(mediaId), value.trim());
  }

  static Future<Uri> getAnkiEndpoint() async {
    final raw =
        (await _boxOrNull())?.get(
              _ankiEndpoint,
              defaultValue: 'http://127.0.0.1:8765',
            )
            as String? ??
        'http://127.0.0.1:8765';
    return Uri.tryParse(raw) ?? Uri.parse('http://127.0.0.1:8765');
  }

  static Future<void> setAnkiEndpoint(Uri value) async {
    await (await _boxOrNull())?.put(_ankiEndpoint, value.toString());
  }

  static Future<AnkiMiningProfile> getAnkiProfile() async {
    final raw = (await _boxOrNull())?.get(_ankiProfile);
    return AnkiMiningProfile.fromJson(raw is Map ? raw : null);
  }

  static Future<void> setAnkiProfile(AnkiMiningProfile profile) async {
    await (await _boxOrNull())?.put(_ankiProfile, profile.toJson());
  }

  static Future<AnkiAudioPreferences> getAnkiAudioPreferences() async {
    final box = await _boxOrNull();
    final sourceTypeName =
        box?.get(
              _ankiAudioSourceType,
              defaultValue: AnkiAudioSourceType.customJson.name,
            )
            as String? ??
        AnkiAudioSourceType.customJson.name;
    return AnkiAudioPreferences(
      enabled:
          box?.get(_ankiAudioEnabled, defaultValue: false) as bool? ?? false,
      sourceType: AnkiAudioSourceType.values.firstWhere(
        (value) => value.name == sourceTypeName,
        orElse: () => AnkiAudioSourceType.customJson,
      ),
      url:
          box?.get(_ankiAudioUrl, defaultValue: AnkiAudioPreferences.defaultUrl)
              as String? ??
          AnkiAudioPreferences.defaultUrl,
      timeout: Duration(
        milliseconds:
            (box?.get(_ankiAudioTimeoutMs, defaultValue: 5000) as int?) ?? 5000,
      ),
      language:
          box?.get(_ankiAudioLanguage, defaultValue: 'ja') as String? ?? 'ja',
    );
  }

  static Future<void> setAnkiAudioPreferences(
    AnkiAudioPreferences preferences,
  ) async {
    final box = await _boxOrNull();
    await box?.put(_ankiAudioEnabled, preferences.enabled);
    await box?.put(_ankiAudioSourceType, preferences.sourceType.name);
    await box?.put(_ankiAudioUrl, preferences.url.trim());
    await box?.put(_ankiAudioTimeoutMs, preferences.timeout.inMilliseconds);
    await box?.put(_ankiAudioLanguage, preferences.language.trim());
  }

  static Future<OcrEnginePreference> getOcrEngine() async {
    final name =
        (await _boxOrNull())?.get(
              _ocrEngine,
              defaultValue: OcrEnginePreference.automatic.name,
            )
            as String? ??
        OcrEnginePreference.automatic.name;
    return OcrEnginePreference.values.firstWhere(
      (value) => value.name == name,
      orElse: () => OcrEnginePreference.automatic,
    );
  }

  static Future<void> setOcrEngine(OcrEnginePreference value) async {
    await (await _boxOrNull())?.put(_ocrEngine, value.name);
  }

  static Future<bool> getOcrOverlayEnabled() async {
    return (await _boxOrNull())?.get(_ocrOverlayEnabled, defaultValue: true)
            as bool? ??
        true;
  }

  static Future<void> setOcrOverlayEnabled(bool value) async {
    await (await _boxOrNull())?.put(_ocrOverlayEnabled, value);
  }

  static Future<String> getOcrLanguage() async {
    return (await _boxOrNull())?.get(_ocrLanguage, defaultValue: 'ja')
            as String? ??
        'ja';
  }

  static Future<void> setOcrLanguage(String value) async {
    await (await _boxOrNull())?.put(_ocrLanguage, value);
  }

  static Future<double> getOcrOverlayOpacity() async {
    return ((await _boxOrNull())?.get(_ocrOverlayOpacity, defaultValue: 0.0)
                as num? ??
            0.0)
        .toDouble();
  }

  static Future<void> setOcrOverlayOpacity(double value) async {
    await (await _boxOrNull())?.put(_ocrOverlayOpacity, value.clamp(0.0, 1.0));
  }

  static Future<double> getOcrBoxScale() async {
    return ((await _boxOrNull())?.get(_ocrBoxScale, defaultValue: 1.0)
                as num? ??
            1.0)
        .toDouble();
  }

  static Future<void> setOcrBoxScale(double value) async {
    await (await _boxOrNull())?.put(_ocrBoxScale, value.clamp(0.8, 1.5));
  }

  static Future<double> getOcrBoxScaleX() async {
    final box = await _boxOrNull();
    return ((box?.get(_ocrBoxScaleX) ??
                box?.get(_ocrBoxScale, defaultValue: 1.0) ??
                1.0)
            as num)
        .toDouble();
  }

  static Future<void> setOcrBoxScaleX(double value) async {
    await (await _boxOrNull())?.put(_ocrBoxScaleX, value.clamp(0.8, 1.5));
  }

  static Future<double> getOcrBoxScaleY() async {
    final box = await _boxOrNull();
    return ((box?.get(_ocrBoxScaleY) ??
                box?.get(_ocrBoxScale, defaultValue: 1.0) ??
                1.0)
            as num)
        .toDouble();
  }

  static Future<void> setOcrBoxScaleY(double value) async {
    await (await _boxOrNull())?.put(_ocrBoxScaleY, value.clamp(0.8, 1.5));
  }

  static Future<bool> getOcrOutlineVisible() async {
    return (await _boxOrNull())?.get(_ocrOutlineVisible, defaultValue: false)
            as bool? ??
        true;
  }

  static Future<void> setOcrOutlineVisible(bool value) async {
    await (await _boxOrNull())?.put(_ocrOutlineVisible, value);
  }

  static Future<bool> getOcrLookupOnHover() async {
    return (await _boxOrNull())?.get(_ocrLookupOnHover, defaultValue: false)
            as bool? ??
        false;
  }

  static Future<void> setOcrLookupOnHover(bool value) async {
    await (await _boxOrNull())?.put(_ocrLookupOnHover, value);
  }

  static Future<DictionaryPopupPreferences>
  getDictionaryPopupPreferences() async {
    final box = await _boxOrNull();
    final themeName =
        box?.get(
              _dictionaryTheme,
              defaultValue: DictionaryThemePreference.system.name,
            )
            as String?;
    return DictionaryPopupPreferences(
      width:
          ((box?.get(_dictionaryPopupWidth, defaultValue: 430) as num?) ?? 430)
              .toDouble(),
      height:
          ((box?.get(_dictionaryPopupHeight, defaultValue: 360) as num?) ?? 360)
              .toDouble(),
      fontSize:
          ((box?.get(_dictionaryFontSize, defaultValue: 14) as num?) ?? 14)
              .toDouble(),
      theme: DictionaryThemePreference.values.firstWhere(
        (value) => value.name == themeName,
        orElse: () => DictionaryThemePreference.system,
      ),
      eInkMode:
          box?.get(_dictionaryEInk, defaultValue: false) as bool? ?? false,
      paginatedScrolling:
          box?.get(_dictionaryPaginated, defaultValue: false) as bool? ?? false,
      customCss:
          box?.get(_dictionaryCustomCss, defaultValue: '') as String? ?? '',
      showFrequencyHarmonic:
          box?.get(_showFrequencyHarmonic, defaultValue: false) as bool? ??
          false,
      showFrequencyAverage:
          box?.get(_showFrequencyAverage, defaultValue: false) as bool? ??
          false,
      showPitchNumber:
          box?.get(_showPitchNumber, defaultValue: true) as bool? ?? true,
      showPitchText:
          box?.get(_showPitchText, defaultValue: true) as bool? ?? true,
    );
  }

  static Future<void> setDictionaryPopupWidth(double value) async =>
      (await _boxOrNull())?.put(_dictionaryPopupWidth, value.clamp(280, 720));

  static Future<void> setDictionaryPopupHeight(double value) async =>
      (await _boxOrNull())?.put(_dictionaryPopupHeight, value.clamp(240, 720));

  static Future<void> setDictionaryFontSize(double value) async =>
      (await _boxOrNull())?.put(_dictionaryFontSize, value.clamp(11, 24));

  static Future<void> setDictionaryTheme(
    DictionaryThemePreference value,
  ) async => (await _boxOrNull())?.put(_dictionaryTheme, value.name);

  static Future<void> setDictionaryEInkMode(bool value) async =>
      (await _boxOrNull())?.put(_dictionaryEInk, value);

  static Future<void> setDictionaryPaginatedScrolling(bool value) async =>
      (await _boxOrNull())?.put(_dictionaryPaginated, value);

  static Future<void> setDictionaryCustomCss(String value) async =>
      (await _boxOrNull())?.put(_dictionaryCustomCss, value);

  static Future<void> setShowFrequencyHarmonic(bool value) async =>
      (await _boxOrNull())?.put(_showFrequencyHarmonic, value);

  static Future<void> setShowFrequencyAverage(bool value) async =>
      (await _boxOrNull())?.put(_showFrequencyAverage, value);

  static Future<void> setShowPitchNumber(bool value) async =>
      (await _boxOrNull())?.put(_showPitchNumber, value);

  static Future<void> setShowPitchText(bool value) async =>
      (await _boxOrNull())?.put(_showPitchText, value);

  static String _jimakuTitleKey(int? mediaId) {
    return 'jimaku_title_${mediaId ?? 'global'}';
  }
}
