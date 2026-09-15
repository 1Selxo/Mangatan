import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/services/hachidori/hachidori_wire_adapter.dart';
import 'package:mangayomi/services/hoshidicts/yomitan_kanji_dictionary.dart';

void main() {
  group('Hachidori wire lookup adapter', () {
    test('projects lookup JSON into the existing generated models', () {
      final results = adaptHachidoriLookupResults([
        {
          'matched': '食べた',
          'deinflected': '食べる',
          'trace': [
            {'name': 'past', 'description': 'past tense'},
          ],
          'preprocessorSteps': 1,
          'term': {
            'expression': '食べる',
            'reading': 'たべる',
            'rules': 'v1',
            'score': 42,
            'glossaries': [
              {
                'dictionary': 'JMdict',
                'glossary': '["to eat"]',
                'definitionTags': 'common',
                'termTags': 'v1',
              },
            ],
            'frequencies': [
              {
                'dictionary': 'Frequency',
                'frequencies': [
                  {'value': 123, 'displayValue': '123'},
                ],
              },
            ],
            'pitches': [
              {
                'dictionary': 'Pitch',
                'pitches': [
                  {
                    'position': 2,
                    'pattern': 'LHH',
                    'nasal': [1],
                    'devoice': [2],
                  },
                  {
                    'position': 0,
                    'pattern': 'HLL',
                    'nasal': <Object?>[],
                    'devoice': <Object?>[],
                  },
                ],
                'transcriptions': ['tàbérú'],
              },
            ],
          },
        },
      ]);

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.matched, '食べた');
      expect(result.deinflected, '食べる');
      expect(result.trace.single.name, 'past');
      expect(result.trace.single.description, 'past tense');
      expect(result.preprocessorSteps, 1);
      expect(result.term.expression, '食べる');
      expect(result.term.reading, 'たべる');
      expect(result.term.rules, 'v1');
      expect(result.term.score, 42);
      expect(result.term.glossaries.single.dictName, 'JMdict');
      expect(result.term.glossaries.single.glossary, '["to eat"]');
      expect(result.term.glossaries.single.definitionTags, 'common');
      expect(result.term.glossaries.single.termTags, 'v1');
      expect(result.term.frequencies.single.dictName, 'Frequency');
      expect(result.term.frequencies.single.frequencies.single.value, 123);
      expect(
        result.term.frequencies.single.frequencies.single.displayValue,
        '123',
      );
      expect(result.term.pitches.single.dictName, 'Pitch');
      expect(result.term.pitches.single.pitchPositions, [2, 0]);
      expect(result.term.pitches.single.transcriptions, ['tàbérú']);
    });

    test(
      'rejects malformed lookup rows instead of partially accepting them',
      () {
        expect(
          () => adaptHachidoriLookupResults({'results': <Object?>[]}),
          throwsA(isA<HachidoriProtocolException>()),
        );
        expect(
          () => adaptHachidoriLookupResults([
            {
              'matched': 'x',
              'deinflected': 'x',
              'trace': <Object?>[],
              'preprocessorSteps': 0,
              'term': {
                'expression': 'x',
                'reading': '',
                'rules': '',
                'score': 0,
                'glossaries': <Object?>[],
                'frequencies': <Object?>[],
                'pitches': [
                  {
                    'dictionary': 'Pitch',
                    'pitches': [
                      {'position': 1.5},
                    ],
                    'transcriptions': <Object?>[],
                  },
                ],
              },
            },
          ]),
          throwsA(isA<HachidoriProtocolException>()),
        );
      },
    );
  });

  group('Hachidori wire Kanji and style adapters', () {
    test(
      'projects host Kanji entries into Mangatan Kanji glossary results',
      () {
        final results = adaptHachidoriKanji({
          'character': '食',
          'entries': [
            {
              'dictionary': 'KANJIDIC',
              'onyomi': 'ショク ジキ',
              'kunyomi': 'た.べる く.う',
              'tags': 'jouyou common',
              'definitions': ['eat', 'food'],
              'stats': [
                {'name': 'grade', 'value': '2'},
                {'name': 'strokes', 'value': '9'},
              ],
            },
          ],
        });

        expect(results, hasLength(1));
        final result = results.single;
        expect(result.matched, '食');
        expect(result.term.expression, '食');
        expect(result.term.glossaries.single.dictName, 'KANJIDIC');
        final glossary = jsonDecode(
          result.term.glossaries.single.glossary,
        ) as Map<String, dynamic>;
        expect(glossary['type'], yomitanKanjiContentType);
        expect(glossary['character'], '食');
        expect(glossary['dictionary'], 'KANJIDIC');
        expect(glossary['onyomi'], ['ショク', 'ジキ']);
        expect(glossary['kunyomi'], ['た.べる', 'く.う']);
        expect(
          glossary['tags'],
          containsAll([
            {'name': 'jouyou', 'content': 'jouyou'},
            {'name': 'common', 'content': 'common'},
          ]),
        );
        expect(glossary['definitions'], ['eat', 'food']);
        expect(
          (glossary['stats'] as Map<String, dynamic>)['misc'],
          contains(
            allOf(
              containsPair('name', 'grade'),
              containsPair('content', 'grade'),
              containsPair('value', '2'),
            ),
          ),
        );
        expect(glossary['frequencies'], isEmpty);
      },
    );

    test('handles no Kanji match and preserves host style order', () {
      expect(adaptHachidoriKanji(null), isEmpty);

      final styles = adaptHachidoriStyles([
        {'dictionary': 'Second', 'styles': '.second {}'},
        {'dictionary': 'First', 'styles': '.first {}'},
      ]);
      expect(styles.map((style) => style.dictName), ['Second', 'First']);
      expect(styles.map((style) => style.styles), ['.second {}', '.first {}']);
    });

    test('rejects malformed Kanji and style payloads', () {
      expect(
        () => adaptHachidoriKanji({
          'character': '食',
          'entries': [
            {
              'dictionary': 'KANJIDIC',
              'onyomi': <Object?>[],
              'kunyomi': '',
              'tags': '',
              'definitions': <Object?>[],
              'stats': <Object?>[],
            },
          ],
        }),
        throwsA(isA<HachidoriProtocolException>()),
      );
      expect(
        () => adaptHachidoriStyles([
          {'dictionary': 'Broken', 'styles': 4},
        ]),
        throwsA(isA<HachidoriProtocolException>()),
      );
    });
  });

  group('Hachidori media data URL adapter', () {
    test('decodes an allowed base64 image payload and preserves null', () {
      expect(adaptHachidoriMedia(null), isNull);
      expect(adaptHachidoriMedia('data:image/png;base64,iVBORw0KGgo='), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
    });

    test('rejects oversized media before decoding', () {
      final oversized = 'A' * (16 * 1024 * 1024 + 4);
      expect(
        () => adaptHachidoriMedia('data:image/png;base64,$oversized'),
        throwsA(isA<HachidoriProtocolException>()),
      );
    });

    test('rejects non-base64, unsupported MIME, and invalid base64 data', () {
      for (final value in [
        'data:image/png,raw',
        'data:text/html;base64,PGgxPk5vPC9oMT4=',
        'data:image/png;base64,***',
        'https://host.test/image.png',
      ]) {
        expect(
          () => adaptHachidoriMedia(value),
          throwsA(isA<HachidoriProtocolException>()),
          reason: value,
        );
      }
    });
  });
}
