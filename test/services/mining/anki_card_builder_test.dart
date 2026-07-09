import 'dart:convert';
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
      'SelectionText',
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
        'popupSelectionText': 'chosen definition',
        'frequenciesHtml': '<ul><li>Test: 10</li></ul>',
        'freqHarmonicRank': '10',
      },
      dictionaryMedia: [media],
    );

    expect(draft.fields['ExpressionFurigana'], 'term[reading]');
    expect(draft.fields['MainDefinition'], contains('first'));
    expect(draft.fields['Glossary'], contains('all'));
    expect(draft.fields['SelectionText'], 'chosen definition');
    expect(draft.fields['DefinitionPicture'], isEmpty);
    expect(draft.fields['IsWordAndSentenceCard'], 'x');
    expect(draft.fields['Frequency'], contains('Test: 10'));
    expect(draft.fields['FreqSort'], '10');
    expect(draft.mediaFiles, [media]);
  });

  test('fills selection markers from highlighted popup text only', () async {
    expect(AnkiMarker.standardTemplates['Selection text'], '{selection-text}');

    final result = HoshiLookupResult(
      matched: 'term',
      deinflected: 'term',
      trace: const [],
      preprocessorSteps: 0,
      term: const HoshiTermResult(
        expression: 'term',
        reading: 'term',
        rules: '',
        score: 1,
        glossaries: [
          HoshiGlossaryEntry(
            dictName: 'JMdict',
            glossary: 'long definition',
            definitionTags: '',
            termTags: '',
          ),
        ],
        frequencies: [],
        pitches: [],
      ),
    );

    final selectedDraft = await const AnkiCardBuilder().build(
      result: result,
      context: const MiningContext(sentence: 'a term in context'),
      profile: const AnkiMiningProfile(
        fieldMap: {
          'SelectionText': AnkiMarker.selectionText,
          'LegacyPopupSelectionText': '{popup-selection-text}',
        },
      ),
      renderedContent: const {'popupSelectionText': 'chosen <definition>'},
    );

    expect(selectedDraft.fields['SelectionText'], 'chosen &lt;definition&gt;');
    expect(
      selectedDraft.fields['LegacyPopupSelectionText'],
      'chosen &lt;definition&gt;',
    );

    final emptyDraft = await const AnkiCardBuilder().build(
      result: result,
      context: const MiningContext(sentence: 'a term in context'),
      profile: const AnkiMiningProfile(
        fieldMap: {
          'SelectionText': AnkiMarker.selectionText,
          'LegacyPopupSelectionText': '{popup-selection-text}',
        },
      ),
    );

    expect(emptyDraft.fields['SelectionText'], isEmpty);
    expect(emptyDraft.fields['LegacyPopupSelectionText'], isEmpty);
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

  test('fills sentence audio only when an Anki field requests it', () async {
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
        glossaries: [],
        frequencies: [],
        pitches: [],
      ),
    );
    final sentenceAudio = AnkiMediaFile(
      filename: 'sentence.opus',
      bytes: Uint8List.fromList([0x4f, 0x67, 0x67, 0x53]),
    );
    var loads = 0;
    final context = MiningContext(
      sentence: 'パンを食べる。',
      sentenceAudioLoader: (format) {
        loads++;
        expect(format, AnkiSentenceAudioFormat.opus);
        return sentenceAudio;
      },
    );

    final draft = await const AnkiCardBuilder().build(
      result: result,
      context: context,
      profile: const AnkiMiningProfile(
        sentenceAudioFormat: AnkiSentenceAudioFormat.opus,
        fieldMap: {'SentenceAudio': AnkiMarker.sentenceAudio},
      ),
    );

    expect(loads, 1);
    expect(draft.fields['SentenceAudio'], '[sound:sentence.opus]');
    expect(draft.mediaFiles, [sentenceAudio]);
    expect(
      AnkiMiningProfile.fromJson({
        'sentenceAudioFormat': 'opus',
      }).sentenceAudioFormat,
      AnkiSentenceAudioFormat.opus,
    );

    await const AnkiCardBuilder().build(
      result: result,
      context: context,
      profile: const AnkiMiningProfile(
        fieldMap: {'Sentence': AnkiMarker.sentence},
      ),
    );
    expect(loads, 1);
  });

  test(
    'fills Chimahon/Yomitan-style dictionary single glossary markers',
    () async {
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
              dictName: 'JMdict (English)',
              glossary: 'to eat',
              definitionTags: 'v1',
              termTags: '',
            ),
            HoshiGlossaryEntry(
              dictName: '大辞林',
              glossary: '食物を口に入れる',
              definitionTags: '',
              termTags: '',
            ),
            HoshiGlossaryEntry(
              dictName: 'JMdict (English)',
              glossary: 'to consume',
              definitionTags: 'v1',
              termTags: '',
            ),
          ],
          frequencies: [],
          pitches: [],
        ),
      );

      final draft = await const AnkiCardBuilder().build(
        result: result,
        context: const MiningContext(sentence: 'パンを食べる。'),
        profile: const AnkiMiningProfile(
          fieldMap: {
            'Rendered': '{single-glossary-jmdict-english}',
            'Substring': '{single-glossary-jmdict}',
            'NoDictionary': '{single-glossary-jmdict-english-no-dictionary}',
            'Brief': '{single-glossary-jmdict-english-brief}',
            'FirstBrief': '{single-glossary-jmdict-first-brief}',
            'Plain': '{single-glossary-jmdict-english-plain}',
            'PlainNoDictionary':
                '{single-glossary-jmdict-english-plain-no-dictionary}',
            'AllFirstPlain': '{single-glossary-all-first-plain}',
            'Cjk': '{single-glossary-大辞林}',
            'Selected': AnkiMarker.selectedGlossary,
          },
        ),
        renderedContent: {
          'selectedDictionary': '大辞林',
          'singleGlossaries': jsonEncode({
            'JMdict (English)': '<div>rendered jmdict</div>',
            '大辞林': '<div>rendered daijirin</div>',
          }),
        },
      );

      expect(draft.fields['Rendered'], '<div>rendered jmdict</div>');
      expect(draft.fields['Substring'], '<div>rendered jmdict</div>');
      expect(draft.fields['NoDictionary'], contains('to eat'));
      expect(draft.fields['NoDictionary'], isNot(contains('JMdict')));
      expect(draft.fields['Brief'], contains('to consume'));
      expect(draft.fields['Brief'], isNot(contains('JMdict')));
      expect(draft.fields['FirstBrief'], '<ol><li>to eat</li></ol>');
      expect(
        draft.fields['Plain'],
        '(JMdict (English))<br>to eat<br>(JMdict (English))<br>to consume',
      );
      expect(draft.fields['PlainNoDictionary'], 'to eat<br>to consume');
      expect(draft.fields['AllFirstPlain'], '(JMdict (English))<br>to eat');
      expect(draft.fields['Cjk'], '<div>rendered daijirin</div>');
      expect(draft.fields['Selected'], '<div>rendered daijirin</div>');
      expect(
        AnkiMarker.singleGlossaryTemplatesForDictionaries(const [
          'JMdict (English)',
        ]),
        const {
          'Single glossary: JMdict (English)':
              '{single-glossary-jmdict-english}',
        },
      );
    },
  );

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
