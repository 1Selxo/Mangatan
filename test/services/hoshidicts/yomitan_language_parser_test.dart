import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_languages.dart';
import 'package:mangayomi/services/hoshidicts/yomitan_language_parser.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

void main() {
  test('registry matches every selectable Yomitan language', () {
    expect(dictionaryLanguages, hasLength(56));
    expect(dictionaryLanguages.first.code, 'ja');
    expect(dictionaryLanguages[1].code, 'ko');
    expect(
      supportedDictionaryLanguageCodes,
      containsAll(<String>[
        'aii',
        'ar',
        'arz',
        'de',
        'en',
        'es',
        'fr',
        'grc',
        'ka',
        'la',
        'ru',
        'tl',
        'vi',
        'yi',
        'yue',
        'zh',
      ]),
    );
    expect(supportedDictionaryLanguageCodes, isNot(contains('xxx')));
    expect(normalizeDictionaryLanguage('fr'), 'fr');
    expect(normalizeDictionaryLanguage('unsupported'), 'ja');
  });

  test('candidate JSON retains Yomitan trace information', () {
    final candidate = YomitanLookupCandidate.fromJson({
      'surface': 'walked',
      'lemma': 'walk',
      'priority': 7,
      'trace': [
        {'name': 'past', 'description': 'Simple past tense of a verb'},
      ],
    });

    expect(candidate.surface, 'walked');
    expect(candidate.lemma, 'walk');
    expect(candidate.trace.single.name, 'past');
  });

  test(
    'derived language result precedes an incidental shorter prefix',
    () async {
      final shorterDirect = _result(expression: 'walk', matched: 'walk');
      final derived = _result(expression: 'walk', matched: 'walk');

      final results = await lookupYomitanDictionary(
        language: 'en',
        text: 'walked home',
        maxResults: 5,
        scanLength: 20,
        lookup: (text, maxResults, scanLength) async {
          if (text == 'walked home') return [shorterDirect];
          if (text == 'walk') return [derived];
          return const [];
        },
        loadCandidates: (language, text, scanLength, maxCandidates) async =>
            const [
              YomitanLookupCandidate(
                surface: 'walked',
                lemma: 'walk',
                priority: 7,
                trace: [
                  YomitanTransform('past', 'Simple past tense of a verb'),
                ],
              ),
            ],
      );

      expect(results, hasLength(1));
      expect(results.single.matched, 'walked');
      expect(results.single.trace.single.name, 'English past');
    },
  );
}

HoshiLookupResult _result({
  required String expression,
  required String matched,
}) => HoshiLookupResult(
  matched: matched,
  deinflected: expression,
  trace: const [],
  preprocessorSteps: 0,
  term: HoshiTermResult(
    expression: expression,
    reading: '',
    rules: '',
    score: 0,
    glossaries: const [],
    frequencies: const [],
    pitches: const [],
  ),
);
