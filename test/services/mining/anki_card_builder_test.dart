import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/anki_card_builder.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

void main() {
  test('uses the Yomitan-rendered payload for Lapis fields', () async {
    final result = HoshiLookupResult(
      matched: 'term',
      deinflected: 'term',
      trace: const [],
      preprocessorSteps: 0,
      term: HoshiTermResult(
        expression: 'term',
        reading: 'reading',
        rules: 'n',
        score: 1,
        glossaries: const [
          HoshiGlossaryEntry(
            dictName: 'Test',
            glossary: '{"type":"structured-content"}',
            definitionTags: 'n',
            termTags: '',
          ),
        ],
        frequencies: const [],
        pitches: const [],
      ),
    );
    final fields = [
      'Expression',
      'ExpressionFurigana',
      'MainDefinition',
      'DefinitionPicture',
      'Picture',
      'Glossary',
      'IsWordAndSentenceCard',
      'Frequency',
      'FreqSort',
    ];
    final media = AnkiMediaFile(
      filename: 'hoshi_dict_0.png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    final draft = await const AnkiCardBuilder().build(
      result: result,
      context: const MiningContext(sentence: 'a term in context'),
      profile: AnkiMiningProfile(
        modelName: 'Lapis',
        fieldMap: AnkiMarker.defaultsForFields(fields),
      ),
      renderedContent: const {
        'furiganaPlain': 'term[reading]',
        'glossary': '<div class="yomitan-glossary">all</div>',
        'glossaryFirst': '<div class="yomitan-glossary">first</div>',
        'frequenciesHtml': '<ul><li>Test: 10</li></ul>',
        'freqHarmonicRank': '10',
      },
      dictionaryMedia: [media],
    );

    expect(draft.fields['ExpressionFurigana'], 'term[reading]');
    expect(draft.fields['MainDefinition'], contains('first'));
    expect(draft.fields['Glossary'], contains('all'));
    expect(draft.fields['DefinitionPicture'], isEmpty);
    expect(draft.fields['IsWordAndSentenceCard'], 'x');
    expect(draft.fields['Frequency'], contains('Test: 10'));
    expect(draft.fields['FreqSort'], '10');
    expect(draft.mediaFiles, [media]);
  });

  test('fills audio markers and attaches audio media', () async {
    final result = HoshiLookupResult(
      matched: '食べる',
      deinflected: '食べる',
      trace: const [],
      preprocessorSteps: 0,
      term: const HoshiTermResult(
        expression: '食べる',
        reading: 'たべる',
        rules: 'v1',
        score: 1,
        glossaries: [
          HoshiGlossaryEntry(
            dictName: 'JMdict',
            glossary: 'to eat',
            definitionTags: 'v1',
            termTags: '',
          ),
        ],
        frequencies: [],
        pitches: [],
      ),
    );
    final audio = AnkiMediaFile(
      filename: 'taberu.mp3',
      bytes: Uint8List.fromList([0x49, 0x44, 0x33]),
    );

    final draft = await const AnkiCardBuilder().build(
      result: result,
      context: const MiningContext(sentence: 'パンを食べる。'),
      profile: const AnkiMiningProfile(
        fieldMap: {
          'Audio': AnkiMarker.audio,
          'WordAudio': AnkiMarker.wordAudio,
        },
      ),
      wordAudio: audio,
    );

    expect(draft.fields['Audio'], '[sound:taberu.mp3]');
    expect(draft.fields['WordAudio'], '[sound:taberu.mp3]');
    expect(draft.mediaFiles, [audio]);
  });

  test(
    'keeps screenshots out of DefinitionPicture even for old profiles',
    () async {
      final result = HoshiLookupResult(
        matched: '割方',
        deinflected: '割方',
        trace: const [],
        preprocessorSteps: 0,
        term: const HoshiTermResult(
          expression: '割方',
          reading: 'わりかた',
          rules: 'adv',
          score: 1,
          glossaries: [
            HoshiGlossaryEntry(
              dictName: 'JMdict',
              glossary: 'comparatively',
              definitionTags: 'adv',
              termTags: '',
            ),
          ],
          frequencies: [],
          pitches: [],
        ),
      );

      final draft = await const AnkiCardBuilder().build(
        result: result,
        context: MiningContext(
          sentence: '割方わかった',
          imageBytesLoader: () async => Uint8List.fromList([
            0x89,
            0x50,
            0x4e,
            0x47,
            0x0d,
            0x0a,
            0x1a,
            0x0a,
          ]),
        ),
        profile: const AnkiMiningProfile(
          fieldMap: {
            'DefinitionPicture': AnkiMarker.screenshot,
            'Picture': AnkiMarker.screenshot,
          },
        ),
      );

      expect(draft.fields['DefinitionPicture'], isEmpty);
      expect(draft.fields['Picture'], contains('<img src="'));
    },
  );
}
