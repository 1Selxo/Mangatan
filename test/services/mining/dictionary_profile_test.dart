import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';

void main() {
  test('round-trips Chimahon-compatible profile state', () {
    const profile = DictionaryProfile(
      id: 'english-study',
      name: 'English study',
      languageCode: 'en',
      anki: AnkiMiningProfile(
        deckName: 'English',
        modelName: 'Lapis',
        tags: ['mangatan', 'english'],
      ),
      dictionaryOrder: ['English Frequency', 'English Dictionary'],
      enabledDictionaries: {'English Dictionary'},
      dictionaryCollapseMode: 'custom',
      dictionaryDisplayModes: {'English Frequency': 'always_collapsed'},
    );

    final restored = DictionaryProfile.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.languageCode, 'en');
    expect(restored.anki.deckName, 'English');
    expect(restored.dictionaryOrder, profile.dictionaryOrder);
    expect(restored.enabledDictionaries, {'English Dictionary'});
    expect(restored.isDictionaryEnabled('English Dictionary'), isTrue);
    expect(restored.isDictionaryEnabled('English Frequency'), isFalse);
  });

  test('empty enabled set means all dictionaries are active', () {
    const profile = DictionaryProfile(id: 'default', name: 'Default');

    expect(profile.isDictionaryEnabled('JMdict'), isTrue);
    expect(profile.isDictionaryEnabled('Frequency'), isTrue);
  });

  test('unknown and blank profile languages survive compatible storage', () {
    final profile = DictionaryProfile.fromJson({
      'id': 'legacy',
      'name': 'Legacy',
      'languageCode': 'x-future-language',
    });
    final blank = DictionaryProfile.fromJson({
      'id': 'language-neutral',
      'name': 'Language neutral',
      'languageCode': '',
    });

    expect(profile.languageCode, 'x-future-language');
    expect(blank.languageCode, isEmpty);
  });

  test('install and delete update every Chimahon dictionary field', () {
    const profile = DictionaryProfile(
      id: 'profile',
      name: 'Profile',
      dictionaryOrder: ['Alpha'],
      enabledDictionaries: {'Alpha'},
      dictionaryDisplayModes: {'Alpha': 'always_collapsed'},
    );

    final installed = profile.withInstalledDictionary('Beta');
    expect(installed.dictionaryOrder, ['Alpha', 'Beta']);
    expect(installed.enabledDictionaries, {'Alpha', 'Beta'});

    final deleted = installed.withoutDictionary('Alpha');
    expect(deleted.dictionaryOrder, ['Beta']);
    expect(deleted.enabledDictionaries, {'Beta'});
    expect(deleted.dictionaryDisplayModes, isNot(contains('Alpha')));
  });
}
