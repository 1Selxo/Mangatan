import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
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
  });

  setUp(resetPreferences);

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('round-trips ordered profiles and all cascade overrides', () async {
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
    final expectedOverrides = {
      DictionaryProfileResolver.mangaOverrideKey(42): 'neutral',
      DictionaryProfileResolver.sourceOverrideKey(9001): 'future',
      DictionaryProfileResolver.novelOverrideKey('book-id'): 'japanese',
    };
    await MiningPreferences.setDictionaryProfileOverrides(expectedOverrides);

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
    final exported = await adapter.export(dictionaryStorage: sourceStorage);
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
    expect(exportedPayload.dictionaryProfileOverrides, expectedOverrides);
    expect(exportedPayload.languageProfiles.first.dictionaryOrder, [
      'Future terms',
      'Shared frequency',
    ]);

    await resetPreferences();
    await MiningPreferences.setDictionaryProfileOverride(
      DictionaryProfileResolver.mangaOverrideKey(999),
      'stale-local-profile',
    );
    final destinationStorage = _DictionaryStorageStub();
    await adapter.import(exported, dictionaryStorage: destinationStorage);

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
    expect(
      await MiningPreferences.getDictionaryProfileOverrides(),
      expectedOverrides,
    );
    expect(destinationStorage.lastReorderedNames, [
      'Future terms',
      'Shared frequency',
    ]);
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
  Future<void> reorder(List<String> names, {Directory? root}) async {
    lastReorderedNames = List<String>.of(names);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
