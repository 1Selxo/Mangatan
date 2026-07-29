import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'mangatan-profile-preferences-',
    );
    Hive.init(tempDirectory.path);
  });

  setUp(() async {
    if (Hive.isBoxOpen('mining_preferences')) {
      await Hive.box<dynamic>('mining_preferences').close();
    }
    await Hive.deleteBoxFromDisk('mining_preferences');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('persists and clears exact Chimahon override keys', () async {
    final mangaKey = DictionaryProfileResolver.mangaOverrideKey(42);
    final sourceKey = DictionaryProfileResolver.sourceOverrideKey(9001);
    await MiningPreferences.setDictionaryProfileOverride(mangaKey, 'ja');
    await MiningPreferences.setDictionaryProfileOverride(sourceKey, 'en');

    expect(await MiningPreferences.getDictionaryProfileOverrides(), {
      mangaKey: 'ja',
      sourceKey: 'en',
    });

    await MiningPreferences.setDictionaryProfileOverride(mangaKey, null);
    expect(await MiningPreferences.getDictionaryProfileOverride(mangaKey), '');
    expect(await MiningPreferences.getDictionaryProfileOverrides(), {
      sourceKey: 'en',
    });
  });

  test('defaults to AnkiMobile and persists the selected iOS mode', () async {
    expect(
      await MiningPreferences.getAnkiIntegrationMode(),
      AnkiIntegrationMode.ankiMobile,
    );

    await MiningPreferences.setAnkiIntegrationMode(
      AnkiIntegrationMode.ankiConnect,
    );
    await Hive.box<dynamic>('mining_preferences').close();

    expect(
      await MiningPreferences.getAnkiIntegrationMode(),
      AnkiIntegrationMode.ankiConnect,
    );
  });

  test('desktop always resolves to AnkiConnect', () {
    expect(
      effectiveAnkiIntegrationMode(
        preferredMode: AnkiIntegrationMode.ankiMobile,
        isIOS: false,
      ),
      AnkiIntegrationMode.ankiConnect,
    );
    expect(
      effectiveAnkiIntegrationMode(
        preferredMode: AnkiIntegrationMode.ankiMobile,
        isIOS: true,
      ),
      AnkiIntegrationMode.ankiMobile,
    );
  });

  test('uses and persists ordered Japanese audio sources', () async {
    final defaults = await MiningPreferences.getAnkiAudioPreferences();
    expect(defaults.effectiveSources.map((source) => source.type), [
      AnkiAudioSourceType.japanesePod101,
      AnkiAudioSourceType.jisho,
      AnkiAudioSourceType.languagePod101,
    ]);

    const configured = AnkiAudioPreferences(
      enabled: true,
      sourceType: AnkiAudioSourceType.jisho,
      url: '',
      sources: [
        AnkiAudioSource(type: AnkiAudioSourceType.jisho),
        AnkiAudioSource(
          type: AnkiAudioSourceType.customUrl,
          url: 'https://audio.example/{term}.mp3',
        ),
      ],
      timeout: Duration(seconds: 7),
      language: 'ja',
    );
    await MiningPreferences.setAnkiAudioPreferences(configured);
    await Hive.box<dynamic>('mining_preferences').close();

    final restored = await MiningPreferences.getAnkiAudioPreferences();
    expect(restored.effectiveSources.map((source) => source.type), [
      AnkiAudioSourceType.jisho,
      AnkiAudioSourceType.customUrl,
    ]);
    expect(
      restored.effectiveSources.last.url,
      'https://audio.example/{term}.mp3',
    );
    expect(restored.timeout, const Duration(seconds: 7));
  });

  test('migrates an existing custom single audio source', () async {
    final box = await Hive.openBox<dynamic>('mining_preferences');
    await box.put('anki_audio_source_type', 'customJson');
    await box.put(
      'anki_audio_url',
      'http://audio.local/?term={term}&reading={reading}',
    );

    final restored = await MiningPreferences.getAnkiAudioPreferences();

    expect(restored.effectiveSources, hasLength(1));
    expect(
      restored.effectiveSources.single.type,
      AnkiAudioSourceType.customJson,
    );
    expect(
      restored.effectiveSources.single.url,
      'http://audio.local/?term={term}&reading={reading}',
    );
  });

  test('deleting a profile sweeps overrides at every cascade level', () async {
    const japanese = DictionaryProfile(id: 'ja', name: 'Japanese');
    const english = DictionaryProfile(
      id: 'en',
      name: 'English',
      languageCode: 'en',
    );
    await MiningPreferences.setDictionaryProfiles(const [
      japanese,
      english,
    ], activeId: japanese.id);
    final overrides = {
      DictionaryProfileResolver.mangaOverrideKey(1): japanese.id,
      DictionaryProfileResolver.sourceOverrideKey(2): japanese.id,
      DictionaryProfileResolver.novelOverrideKey('book'): japanese.id,
      DictionaryProfileResolver.mangaOverrideKey(3): english.id,
    };
    await MiningPreferences.setDictionaryProfileOverrides(overrides);

    expect(
      await MiningPreferences.deleteDictionaryProfile(japanese.id),
      isTrue,
    );
    expect(await MiningPreferences.getDictionaryProfileOverrides(), {
      DictionaryProfileResolver.mangaOverrideKey(3): english.id,
    });
  });

  test(
    'profile order and language-neutral values survive Hive reload',
    () async {
      const profiles = [
        DictionaryProfile(id: 'neutral', name: 'Neutral', languageCode: ''),
        DictionaryProfile(id: 'future', name: 'Future', languageCode: 'x-new'),
      ];
      await MiningPreferences.setDictionaryProfiles(
        profiles,
        activeId: profiles.last.id,
      );
      await Hive.box<dynamic>('mining_preferences').close();

      final restored = await MiningPreferences.getDictionaryProfiles();
      expect(restored.map((profile) => profile.id), ['neutral', 'future']);
      expect(restored.map((profile) => profile.languageCode), ['', 'x-new']);
    },
  );

  test('storage-backed resolver follows every cascade level', () async {
    const profiles = [
      DictionaryProfile(
        id: 'japanese-first',
        name: 'Japanese first',
        languageCode: 'ja',
      ),
      DictionaryProfile(
        id: 'japanese-second',
        name: 'Japanese second',
        languageCode: 'ja',
      ),
      DictionaryProfile(
        id: 'manga-profile',
        name: 'Manga profile',
        languageCode: 'ko',
      ),
      DictionaryProfile(
        id: 'source-profile',
        name: 'Source profile',
        languageCode: 'en',
      ),
      DictionaryProfile(
        id: 'novel-profile',
        name: 'Novel profile',
        languageCode: 'de',
      ),
      DictionaryProfile(
        id: 'active-profile',
        name: 'Active profile',
        languageCode: 'fr',
      ),
    ];
    await MiningPreferences.setDictionaryProfiles(
      profiles,
      activeId: 'active-profile',
    );

    const mangaId = 42;
    const sourceId = 9001;
    const novelId = 'book-id';
    final mangaKey = DictionaryProfileResolver.mangaOverrideKey(mangaId);
    final sourceKey = DictionaryProfileResolver.sourceOverrideKey(sourceId);
    final novelKey = DictionaryProfileResolver.novelOverrideKey(novelId);
    await MiningPreferences.setDictionaryProfileOverrides({
      mangaKey: 'manga-profile',
      sourceKey: 'source-profile',
      novelKey: 'novel-profile',
    });

    Future<void> expectResolution(
      String profileId,
      DictionaryProfileResolutionLevel level,
    ) async {
      final resolved = await DictionaryProfileResolver.resolveWithLevel(
        mangaId: mangaId,
        sourceId: sourceId,
        novelId: novelId,
        sourceLanguage: 'JA',
      );
      expect(resolved.profile.id, profileId);
      expect(resolved.level, level);
    }

    await expectResolution(
      'manga-profile',
      DictionaryProfileResolutionLevel.manga,
    );
    await MiningPreferences.setDictionaryProfileOverride(mangaKey, null);
    await expectResolution(
      'source-profile',
      DictionaryProfileResolutionLevel.source,
    );
    await MiningPreferences.setDictionaryProfileOverride(sourceKey, null);
    await expectResolution(
      'novel-profile',
      DictionaryProfileResolutionLevel.novel,
    );
    await MiningPreferences.setDictionaryProfileOverride(novelKey, null);
    await expectResolution(
      'japanese-first',
      DictionaryProfileResolutionLevel.language,
    );

    await MiningPreferences.setDictionaryProfileOverrides({
      mangaKey: 'deleted-manga-profile',
      sourceKey: 'deleted-source-profile',
      novelKey: 'deleted-novel-profile',
    });
    await expectResolution(
      'japanese-first',
      DictionaryProfileResolutionLevel.language,
    );

    final active = await DictionaryProfileResolver.resolveWithLevel(
      mangaId: mangaId,
      sourceId: sourceId,
      novelId: novelId,
      sourceLanguage: 'all',
    );
    expect(active.profile.id, 'active-profile');
    expect(active.level, DictionaryProfileResolutionLevel.active);
  });
}
