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

  test('invalid profile language falls back to Japanese', () {
    final profile = DictionaryProfile.fromJson({
      'id': 'legacy',
      'name': 'Legacy',
      'languageCode': 'not-supported',
    });

    expect(profile.languageCode, 'ja');
  });
}
