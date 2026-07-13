import 'dart:convert';

import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

/// Bridges settings Mangatan already supports. Unsupported Chimahon keys stay
/// in the deferred protobuf payload and are therefore not lost on round-trip.
class ChimahonMiningSettingsAdapter {
  const ChimahonMiningSettingsAdapter({
    this.codec = const ChimahonPreferenceCodec(),
  });

  final ChimahonPreferenceCodec codec;

  Future<List<BackupPreference>> export({
    DictionaryStorage? dictionaryStorage,
  }) async {
    final popup = await MiningPreferences.getDictionaryPopupPreferences();
    final profiles = await MiningPreferences.getDictionaryProfiles();
    final active = await MiningPreferences.getActiveDictionaryProfile();
    final installed = await (dictionaryStorage ?? DictionaryStorage.instance)
        .installed();
    final installedNames = installed
        .map((dictionary) => dictionary.name)
        .toList();
    final overrides = await MiningPreferences.getDictionaryProfileOverrides();
    final chimahonProfiles = [
      for (final profile in profiles)
        _exportProfile(
          profile,
          dictionaryOrder: profile.dictionaryOrder.isEmpty
              ? installedNames
              : profile.dictionaryOrder,
        ),
    ];

    return [
      codec.encode(
        'pref_anki_profiles',
        jsonEncode(
          chimahonProfiles.map((profile) => profile.toJson()).toList(),
        ),
      ),
      codec.encode('pref_active_profile_id', active.id),
      codec.encode(
        'pref_dictionary_order',
        (active.dictionaryOrder.isEmpty
                ? installedNames
                : active.dictionaryOrder)
            .join(','),
      ),
      codec.encode('pref_dictionary_popup_width', popup.width.round()),
      codec.encode('pref_dictionary_popup_height', popup.height.round()),
      codec.encode('pref_dictionary_popup_mode', 'floating'),
      codec.encode('pref_dictionary_font_size', popup.fontSize.round()),
      codec.encode('pref_dictionary_theme_mode', _exportTheme(popup.theme)),
      codec.encode('pref_dictionary_eink_mode', popup.eInkMode),
      codec.encode(
        'pref_dictionary_paginated_scrolling',
        popup.paginatedScrolling,
      ),
      codec.encode('pref_dictionary_custom_css', popup.customCss),
      codec.encode(
        'pref_dict_show_frequency_harmonic',
        popup.showFrequencyHarmonic,
      ),
      codec.encode(
        'pref_dict_show_frequency_average',
        popup.showFrequencyAverage,
      ),
      codec.encode('pref_dict_show_pitch_number', popup.showPitchNumber),
      codec.encode('pref_dict_show_pitch_text', popup.showPitchText),
      for (final override in overrides.entries)
        codec.encode(override.key, override.value),
    ];
  }

  Future<void> import(
    Iterable<BackupPreference> preferences, {
    DictionaryStorage? dictionaryStorage,
  }) async {
    final payload = ChimahonSettingsPayload.fromBackup(
      preferences,
      codec: codec,
    );
    final importedProfiles = payload.languageProfiles
        .map(_importProfile)
        .where((profile) => profile.id.isNotEmpty)
        .toList(growable: false);
    if (importedProfiles.isNotEmpty) {
      await MiningPreferences.setDictionaryProfiles(
        importedProfiles,
        activeId: payload.activeProfileId,
      );
    }
    // A normal Mihon backup can omit app preferences entirely. Treat the
    // dynamic override keys as an authoritative snapshot only when the
    // Chimahon profile payload itself is present.
    if (payload.preferences.containsKey('pref_anki_profiles')) {
      await MiningPreferences.setDictionaryProfileOverrides(
        payload.dictionaryProfileOverrides,
      );
    }
    final profile = payload.activeLanguageProfile;
    if (profile != null) {
      final current = await MiningPreferences.getAnkiProfile();
      await MiningPreferences.setAnkiProfile(
        current.copyWith(
          ankiEnabled: profile.ankiEnabled,
          deckName: profile.ankiDeck,
          modelName: profile.ankiModel,
          tags: profile.ankiTags
              .split(RegExp(r'[\s,]+'))
              .where((tag) => tag.isNotEmpty)
              .toList(),
          duplicateCheck: profile.ankiDuplicateCheck,
          duplicateScope: profile.ankiDuplicateScope,
          syncOnCreate: profile.ankiSyncOnCreate,
          fieldMap: profile.ankiFieldMap,
        ),
      );
      if (profile.dictionaryOrder.isNotEmpty) {
        await (dictionaryStorage ?? DictionaryStorage.instance).reorder(
          profile.dictionaryOrder,
        );
      }
    }

    await _setNumber(
      payload['pref_dictionary_popup_width'],
      MiningPreferences.setDictionaryPopupWidth,
    );
    await _setNumber(
      payload['pref_dictionary_popup_height'],
      MiningPreferences.setDictionaryPopupHeight,
    );
    await _setNumber(
      payload['pref_dictionary_font_size'],
      MiningPreferences.setDictionaryFontSize,
    );
    await _setBool(
      payload['pref_dictionary_eink_mode'],
      MiningPreferences.setDictionaryEInkMode,
    );
    await _setBool(
      payload['pref_dictionary_paginated_scrolling'],
      MiningPreferences.setDictionaryPaginatedScrolling,
    );
    await _setString(
      payload['pref_dictionary_custom_css'],
      MiningPreferences.setDictionaryCustomCss,
    );
    await _setBool(
      payload['pref_dict_show_frequency_harmonic'],
      MiningPreferences.setShowFrequencyHarmonic,
    );
    await _setBool(
      payload['pref_dict_show_frequency_average'],
      MiningPreferences.setShowFrequencyAverage,
    );
    await _setBool(
      payload['pref_dict_show_pitch_number'],
      MiningPreferences.setShowPitchNumber,
    );
    await _setBool(
      payload['pref_dict_show_pitch_text'],
      MiningPreferences.setShowPitchText,
    );

    final theme = payload['pref_dictionary_theme_mode'];
    if (theme is String) {
      await MiningPreferences.setDictionaryTheme(_importTheme(theme));
    }
  }

  Future<void> _setNumber(
    Object? value,
    Future<void> Function(double) setter,
  ) => value is num ? setter(value.toDouble()) : Future.value();

  Future<void> _setBool(Object? value, Future<void> Function(bool) setter) =>
      value is bool ? setter(value) : Future.value();

  Future<void> _setString(
    Object? value,
    Future<void> Function(String) setter,
  ) => value is String ? setter(value) : Future.value();

  String _exportTheme(DictionaryThemePreference theme) => switch (theme) {
    DictionaryThemePreference.system => 'system',
    DictionaryThemePreference.light => 'light',
    DictionaryThemePreference.dark => 'dark',
    DictionaryThemePreference.black => 'pure_black',
  };

  DictionaryThemePreference _importTheme(String theme) => switch (theme) {
    'light' => DictionaryThemePreference.light,
    'dark' => DictionaryThemePreference.dark,
    'pure_black' => DictionaryThemePreference.black,
    _ => DictionaryThemePreference.system,
  };

  ChimahonLanguageProfile _exportProfile(
    DictionaryProfile profile, {
    required List<String> dictionaryOrder,
  }) {
    final anki = profile.anki;
    return ChimahonLanguageProfile(
      id: profile.id,
      name: profile.name,
      ankiEnabled: anki.ankiEnabled,
      ankiDeck: anki.deckName,
      ankiModel: anki.modelName,
      ankiFieldMap: anki.fieldMap,
      ankiTags: anki.tags.join(' '),
      ankiDuplicateCheck: anki.duplicateCheck,
      ankiDuplicateScope: anki.duplicateScope,
      ankiDuplicateAction: profile.duplicateAction,
      ankiCropMode: profile.cropMode,
      ankiSyncOnCreate: anki.syncOnCreate,
      dictionaryOrder: dictionaryOrder,
      enabledDictionaries: profile.enabledDictionaries,
      dictionaryCollapseMode: profile.dictionaryCollapseMode,
      dictionaryDisplayModes: profile.dictionaryDisplayModes,
      languageCode: profile.languageCode,
    );
  }

  DictionaryProfile _importProfile(ChimahonLanguageProfile profile) {
    return DictionaryProfile(
      id: profile.id,
      name: profile.name,
      languageCode: profile.languageCode,
      anki: const AnkiMiningProfile().copyWith(
        ankiEnabled: profile.ankiEnabled,
        deckName: profile.ankiDeck,
        modelName: profile.ankiModel,
        tags: profile.ankiTags
            .split(RegExp(r'[\s,]+'))
            .where((tag) => tag.isNotEmpty)
            .toList(),
        duplicateCheck: profile.ankiDuplicateCheck,
        duplicateScope: profile.ankiDuplicateScope,
        syncOnCreate: profile.ankiSyncOnCreate,
        fieldMap: profile.ankiFieldMap,
      ),
      dictionaryOrder: profile.dictionaryOrder,
      enabledDictionaries: profile.enabledDictionaries,
      dictionaryCollapseMode: profile.dictionaryCollapseMode,
      dictionaryDisplayModes: profile.dictionaryDisplayModes,
      duplicateAction: profile.ankiDuplicateAction,
      cropMode: profile.ankiCropMode,
    );
  }
}
