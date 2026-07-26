import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_mining_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

void main() {
  late Directory tempDirectory;

  Future<void> resetPreferences() async {
    if (Hive.isBoxOpen('mining_preferences')) {
      await Hive.box<dynamic>('mining_preferences').close();
    }
    await Hive.deleteBoxFromDisk('mining_preferences');
  }

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'mangatan-profile-adapter-',
    );
    Hive.init(tempDirectory.path);
    MiningPreferences.configureStorageDirectory(tempDirectory.path);
  });

  setUp(resetPreferences);

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('round-trips profiles and only portable cascade overrides', () async {
    const profiles = [
      DictionaryProfile(
        id: 'neutral',
        name: 'Language neutral',
        languageCode: '',
      ),
      DictionaryProfile(
        id: 'future',
        name: 'Future language',
        languageCode: 'x-future-language',
        dictionaryOrder: ['Future terms', 'Shared frequency'],
        enabledDictionaries: {'Future terms'},
      ),
      DictionaryProfile(id: 'japanese', name: 'Japanese', languageCode: 'ja'),
    ];
    await MiningPreferences.setDictionaryProfiles(profiles, activeId: 'future');
    final localOverrides = {
      DictionaryProfileResolver.mangaOverrideKey(42): 'neutral',
      DictionaryProfileResolver.sourceOverrideKey(9001): 'future',
      DictionaryProfileResolver.sourceOverrideKey(777): 'neutral',
      DictionaryProfileResolver.novelOverrideKey('book-id'): 'japanese',
    };
    final expectedPortableOverrides = {
      DictionaryProfileResolver.sourceOverrideKey(9001): 'future',
      DictionaryProfileResolver.novelOverrideKey('book-id'): 'japanese',
    };
    await MiningPreferences.setDictionaryProfileOverrides(localOverrides);
    await MiningPreferences.setOcrEngine(OcrEnginePreference.googleLens);
    await MiningPreferences.setOcrOverlayEnabled(false);
    await MiningPreferences.setOcrOutlineVisible(true);
    await MiningPreferences.setOcrBackgroundOpacity(0.35);
    await MiningPreferences.setOcrBoxScaleX(1.2);
    await MiningPreferences.setOcrBoxScaleY(0.9);
    await MiningPreferences.setJimakuApiKey('chimahon-compatible-key');

    const adapter = ChimahonMiningSettingsAdapter();
    final sourceStorage = _DictionaryStorageStub(const [
      InstalledDictionary(
        name: 'Future terms',
        hasTerms: true,
        hasFrequencies: false,
        hasPitch: false,
      ),
      InstalledDictionary(
        name: 'Shared frequency',
        hasTerms: false,
        hasFrequencies: true,
        hasPitch: false,
      ),
    ]);
    final exported = await adapter.export(
      dictionaryStorage: sourceStorage,
      portableSourceIds: const {'9001'},
    );
    final exportedPayload = ChimahonSettingsPayload.fromBackup(exported);

    expect(exportedPayload.languageProfiles.map((profile) => profile.id), [
      'neutral',
      'future',
      'japanese',
    ]);
    expect(
      exportedPayload.languageProfiles.map((profile) => profile.languageCode),
      ['', 'x-future-language', 'ja'],
    );
    expect(exportedPayload.activeProfileId, 'future');
    expect(
      exportedPayload.dictionaryProfileOverrides,
      expectedPortableOverrides,
    );
    expect(
      exportedPayload.preferences,
      isNot(contains('pref_dictionary_popup_mode')),
    );
    expect(exportedPayload['pref_ocr_engine'], 'cloud');
    expect(exportedPayload['reader_ocr_overlay_enabled'], isFalse);
    expect(exportedPayload['reader_ocr_outline_visible'], isTrue);
    expect(exportedPayload['pref_jimaku_api_key'], 'chimahon-compatible-key');
    expect(
      exportedPayload['pref_ocr_box_opacity'] as double,
      closeTo(0.35, 0.000001),
    );
    expect(
      exportedPayload['pref_ocr_box_scale_x'] as double,
      closeTo(1.2, 0.000001),
    );
    expect(
      exportedPayload['pref_ocr_box_scale_y'] as double,
      closeTo(0.9, 0.000001),
    );
    expect(exportedPayload.preferences, isNot(contains('pref_ocr_box_scale')));
    expect(exportedPayload.languageProfiles.first.dictionaryOrder, [
      'Future terms',
      'Shared frequency',
    ]);

    await resetPreferences();
    await MiningPreferences.setDictionaryProfileOverride(
      DictionaryProfileResolver.mangaOverrideKey(999),
      'stale-local-profile',
    );
    await MiningPreferences.setDictionaryProfileOverride(
      DictionaryProfileResolver.sourceOverrideKey(777),
      'local-source-profile',
    );
    await MiningPreferences.setOcrEngine(OcrEnginePreference.mokuroOnly);
    await MiningPreferences.setOcrOverlayEnabled(true);
    await MiningPreferences.setOcrOutlineVisible(false);
    await MiningPreferences.setOcrBackgroundOpacity(0.8);
    await MiningPreferences.setOcrBoxScaleX(1.0);
    await MiningPreferences.setOcrBoxScaleY(1.0);
    await MiningPreferences.setJimakuApiKey('stale-local-key');
    final destinationStorage = _DictionaryStorageStub();
    await adapter.import(
      [
        ...exported,
        const ChimahonPreferenceCodec().encode(
          DictionaryProfileResolver.mangaOverrideKey(999),
          'unrelated-remote-manga',
        ),
        const ChimahonPreferenceCodec().encode(
          DictionaryProfileResolver.sourceOverrideKey(777),
          'unrelated-remote-source',
        ),
      ],
      dictionaryStorage: destinationStorage,
      portableSourceIds: const {'9001'},
    );

    final restored = await MiningPreferences.getDictionaryProfiles();
    expect(restored.map((profile) => profile.id), [
      'neutral',
      'future',
      'japanese',
    ]);
    expect(restored.map((profile) => profile.languageCode), [
      '',
      'x-future-language',
      'ja',
    ]);
    expect((await MiningPreferences.getActiveDictionaryProfile()).id, 'future');
    expect(await MiningPreferences.getDictionaryProfileOverrides(), {
      DictionaryProfileResolver.mangaOverrideKey(999): 'stale-local-profile',
      DictionaryProfileResolver.sourceOverrideKey(777): 'local-source-profile',
      ...expectedPortableOverrides,
    });
    expect(destinationStorage.lastReorderedNames, [
      'Future terms',
      'Shared frequency',
    ]);
    expect(
      await MiningPreferences.getOcrEngine(),
      OcrEnginePreference.googleLens,
    );
    expect(await MiningPreferences.getOcrOverlayEnabled(), isFalse);
    expect(await MiningPreferences.getOcrOutlineVisible(), isTrue);
    expect(
      await MiningPreferences.getOcrBackgroundOpacity(),
      closeTo(0.35, 0.000001),
    );
    expect(await MiningPreferences.getOcrBoxScaleX(), closeTo(1.2, 0.000001));
    expect(await MiningPreferences.getOcrBoxScaleY(), closeTo(0.9, 0.000001));
    expect(
      await MiningPreferences.getJimakuApiKey(),
      'chimahon-compatible-key',
    );
  });

  test(
    'read-only projection neither opens nor creates the preference box',
    () async {
      expect(Hive.isBoxOpen('mining_preferences'), isFalse);
      final before = await _entityNames(tempDirectory);

      final projection = await const ChimahonMiningSettingsAdapter().project(
        dictionaryStorage: _DictionaryStorageStub(),
        readOnly: true,
      );

      expect(projection.preferences, isNotEmpty);
      expect(Hive.isBoxOpen('mining_preferences'), isFalse);
      expect(await _entityNames(tempDirectory), before);
    },
  );

  test('read-only projection does not migrate an open legacy box', () async {
    final box = await Hive.openBox<dynamic>('mining_preferences');
    await box.put('ocr_engine', OcrEnginePreference.googleLens.name);
    await box.put('dictionary_language', 'de');
    final before = Map<Object?, Object?>.from(box.toMap());

    final projection = await const ChimahonMiningSettingsAdapter().project(
      dictionaryStorage: _DictionaryStorageStub(),
      readOnly: true,
    );
    final payload = ChimahonSettingsPayload.fromBackup(projection.preferences);

    expect(payload['pref_ocr_engine'], 'cloud');
    expect(payload.languageProfiles.single.languageCode, 'de');
    expect(box.toMap(), before);
    expect(box.containsKey('dictionary_profiles'), isFalse);
    expect(box.containsKey('active_dictionary_profile_id'), isFalse);
  });

  test(
    'closed-box read-only projection matches the open box without disk writes',
    () async {
      await MiningPreferences.setDictionaryProfiles(const [
        DictionaryProfile(
          id: 'german',
          name: 'German study',
          languageCode: 'de',
          dictionaryOrder: ['German terms'],
        ),
      ], activeId: 'german');
      await MiningPreferences.setDictionaryProfileOverride(
        DictionaryProfileResolver.novelOverrideKey('closed-book'),
        'german',
      );
      await MiningPreferences.setOcrEngine(OcrEnginePreference.googleLens);
      await MiningPreferences.setOcrOverlayEnabled(false);
      await MiningPreferences.setOcrOutlineVisible(true);
      await MiningPreferences.setOcrBackgroundOpacity(0.42);
      await MiningPreferences.setOcrBoxScaleX(1.25);
      await MiningPreferences.setOcrBoxScaleY(0.85);
      await MiningPreferences.setDictionaryPopupWidth(611);
      await MiningPreferences.setDictionaryPopupHeight(477);
      await MiningPreferences.setDictionaryFontSize(19);
      await MiningPreferences.setDictionaryTheme(
        DictionaryThemePreference.black,
      );
      await MiningPreferences.setDictionaryCustomCss('body { color: red; }');
      await MiningPreferences.setJimakuApiKey('closed-box-key');

      const adapter = ChimahonMiningSettingsAdapter();
      final storage = _DictionaryStorageStub(const [
        InstalledDictionary(
          name: 'German terms',
          hasTerms: true,
          hasFrequencies: false,
          hasPitch: false,
        ),
      ]);
      final openProjection = await adapter.project(
        dictionaryStorage: storage,
        readOnly: true,
      );

      await Hive.box<dynamic>('mining_preferences').close();
      expect(Hive.isBoxOpen('mining_preferences'), isFalse);
      final before = await _fileSnapshot(tempDirectory);

      final closedProjection = await adapter.project(
        dictionaryStorage: storage,
        readOnly: true,
      );

      expect(
        _encodedPreferences(closedProjection.preferences),
        _encodedPreferences(openProjection.preferences),
      );
      expect(
        closedProjection.unrepresentableKeys,
        openProjection.unrepresentableKeys,
      );
      expect(Hive.isBoxOpen('mining_preferences'), isFalse);
      expect(await _fileSnapshot(tempDirectory), before);
    },
  );

  test(
    'closed-box read-only projection fails closed on a non-file path',
    () async {
      final conflictingPath = Directory(
        '${tempDirectory.path}/mining_preferences.hive',
      );
      await conflictingPath.create();
      try {
        await expectLater(
          const ChimahonMiningSettingsAdapter().project(
            dictionaryStorage: _DictionaryStorageStub(),
            readOnly: true,
          ),
          throwsA(isA<MiningPreferencesSnapshotException>()),
        );

        expect(Hive.isBoxOpen('mining_preferences'), isFalse);
        expect(await conflictingPath.exists(), isTrue);
        expect(await _entityNames(tempDirectory), [
          '${Platform.pathSeparator}mining_preferences.hive',
        ]);
      } finally {
        await conflictingPath.delete();
      }
    },
  );

  test(
    'maps local OCR and ignores unsupported or out-of-range values',
    () async {
      const adapter = ChimahonMiningSettingsAdapter();
      const codec = ChimahonPreferenceCodec();

      await adapter.import([
        codec.encode('pref_ocr_engine', 'local'),
        codec.encode('pref_ocr_box_scale', 1.3),
      ]);
      expect(
        await MiningPreferences.getOcrEngine(),
        OcrEnginePreference.screenAi,
      );
      expect(await MiningPreferences.getOcrBoxScaleX(), closeTo(1.3, 0.000001));
      expect(await MiningPreferences.getOcrBoxScaleY(), closeTo(1.3, 0.000001));

      await MiningPreferences.setDictionaryTheme(
        DictionaryThemePreference.dark,
      );
      await adapter.import([
        codec.encode('pref_ocr_engine', 'future-engine'),
        codec.encode('pref_ocr_box_scale_x', 2.5),
        codec.encode('pref_ocr_box_opacity', -0.1),
        codec.encode('pref_dictionary_theme_mode', 'future-theme'),
      ]);
      expect(
        await MiningPreferences.getOcrEngine(),
        OcrEnginePreference.screenAi,
      );
      expect(await MiningPreferences.getOcrBoxScaleX(), closeTo(1.3, 0.000001));
      expect(
        await MiningPreferences.getOcrBackgroundOpacity(),
        MiningPreferences.defaultOcrBackgroundOpacity,
      );
      expect(
        (await MiningPreferences.getDictionaryPopupPreferences()).theme,
        DictionaryThemePreference.dark,
      );
    },
  );

  test(
    'preserves Mangatan-only OCR projection gaps without importing over them',
    () async {
      const adapter = ChimahonMiningSettingsAdapter();
      const codec = ChimahonPreferenceCodec();
      await MiningPreferences.setOcrEngine(OcrEnginePreference.mokuroOnly);
      await MiningPreferences.setOcrBoxScaleX(1.2);
      await MiningPreferences.setOcrBoxScaleY(0.9);

      final projection = await adapter.project(
        dictionaryStorage: _DictionaryStorageStub(),
      );
      final exportedKeys = projection.preferences
          .map((preference) => preference.key)
          .toSet();
      expect(exportedKeys, isNot(contains('pref_ocr_engine')));
      expect(exportedKeys, isNot(contains('pref_ocr_box_scale')));
      expect(projection.unrepresentableKeys, {
        'pref_ocr_engine',
        'pref_ocr_box_scale',
      });
      expect(
        projection.unrepresentableKeys,
        isNot(contains('pref_jimaku_api_key')),
        reason: 'an intentionally cleared API key remains a deletion',
      );

      await adapter.import(
        [
          codec.encode('pref_ocr_engine', 'cloud'),
          codec.encode('pref_ocr_box_scale', 1.3),
        ],
        dictionaryStorage: _DictionaryStorageStub(),
        preserveLocalKeys: projection.unrepresentableKeys,
      );

      expect(
        await MiningPreferences.getOcrEngine(),
        OcrEnginePreference.mokuroOnly,
      );
      expect(await MiningPreferences.getOcrBoxScaleX(), closeTo(1.2, 0.000001));
      expect(await MiningPreferences.getOcrBoxScaleY(), closeTo(0.9, 0.000001));
    },
  );

  test('preserves Mangatan-only Anki fields in matching profiles', () async {
    await MiningPreferences.setDictionaryProfiles(const [
      DictionaryProfile(
        id: 'japanese',
        name: 'Local name',
        anki: AnkiMiningProfile(
          checkAllModels: true,
          sentenceAudioFormat: AnkiSentenceAudioFormat.opus,
        ),
      ),
    ], activeId: 'japanese');

    final remotePreferences = await const ChimahonMiningSettingsAdapter()
        .export(dictionaryStorage: _DictionaryStorageStub());
    final payload = ChimahonSettingsPayload.fromBackup(remotePreferences);
    final remoteProfile = payload.languageProfiles.single.toJson()
      ..['name'] = 'Remote name'
      ..['ankiDeck'] = 'Remote deck';
    final encoded = const ChimahonPreferenceCodec().encode(
      'pref_anki_profiles',
      jsonEncode([remoteProfile]),
    );

    await const ChimahonMiningSettingsAdapter().import([encoded]);

    final restored = (await MiningPreferences.getDictionaryProfiles()).single;
    expect(restored.name, 'Remote name');
    expect(restored.anki.deckName, 'Remote deck');
    expect(restored.anki.checkAllModels, isTrue);
    expect(restored.anki.sentenceAudioFormat, AnkiSentenceAudioFormat.opus);
  });
}

class _DictionaryStorageStub implements DictionaryStorage {
  _DictionaryStorageStub([this.dictionaries = const []]);

  final List<InstalledDictionary> dictionaries;
  List<String>? lastReorderedNames;

  @override
  Future<List<InstalledDictionary>> installed({
    Directory? root,
    List<String> order = const [],
  }) async => dictionaries;

  @override
  Future<List<InstalledDictionary>> installedReadOnly({
    Directory? root,
    List<String> order = const [],
  }) async => dictionaries;

  @override
  Future<void> reorder(List<String> names, {Directory? root}) async {
    lastReorderedNames = List<String>.of(names);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<List<String>> _entityNames(Directory directory) async => [
  await for (final entity in directory.list(recursive: true))
    entity.path.substring(directory.path.length),
]..sort();

List<String> _encodedPreferences(Iterable<BackupPreference> preferences) => [
  for (final preference in preferences)
    base64Encode(preference.writeToBuffer()),
];

Future<Map<String, String>> _fileSnapshot(Directory directory) async {
  final snapshot = <String, String>{};
  await for (final entity in directory.list(recursive: true)) {
    if (entity is! File) continue;
    final relativePath = entity.path.substring(directory.path.length);
    final stat = await entity.stat();
    final bytes = await entity.readAsBytes();
    snapshot[relativePath] =
        '${stat.modified.microsecondsSinceEpoch}:${base64Encode(bytes)}';
  }
  return snapshot;
}
