import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/hoshidicts/kiwi_korean_analyzer.dart';
import 'package:mangayomi/services/hoshidicts/korean_language_parser.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

void main() {
  const parser = KoreanLanguageParser();

  test('separates Korean noun particles', () {
    final lemmas = parser
        .candidates('한국어를 배우고 있어요')
        .map((candidate) => candidate.lemma);

    expect(lemmas, contains('한국어'));
  });

  test('restores polite and past verb forms', () {
    expect(
      parser.candidates('먹었습니다').map((candidate) => candidate.lemma),
      contains('먹다'),
    );
    expect(
      parser.candidates('봤어요').map((candidate) => candidate.lemma),
      contains('보다'),
    );
  });

  test('restores 하다 and 되다 contractions', () {
    expect(
      parser.candidates('했어요').map((candidate) => candidate.lemma),
      contains('하다'),
    );
    expect(
      parser.candidates('돼요').map((candidate) => candidate.lemma),
      contains('되다'),
    );
  });

  test('generates common irregular Korean lemmas', () {
    expect(
      parser.candidates('추워요').map((candidate) => candidate.lemma),
      contains('춥다'),
    );
    expect(
      parser.candidates('몰라요').map((candidate) => candidate.lemma),
      contains('모르다'),
    );
    expect(
      parser.candidates('걸어요').map((candidate) => candidate.lemma),
      contains('걷다'),
    );
    expect(
      parser.candidates('지어요').map((candidate) => candidate.lemma),
      contains('짓다'),
    );
  });

  test(
    'lookup layer queries lemmas and preserves the matched surface',
    () async {
      final queries = <String>[];
      final results = await lookupKoreanDictionary(
        text: '먹었습니다',
        maxResults: 10,
        scanLength: 20,
        morphologyAnalyzer: const _UnavailableMorphologyAnalyzer(),
        lookup: (text, maxResults, scanLength) async {
          queries.add(text);
          if (text != '먹다') return const [];
          return const [
            HoshiLookupResult(
              matched: '먹다',
              deinflected: '먹다',
              trace: [],
              preprocessorSteps: 0,
              term: HoshiTermResult(
                expression: '먹다',
                reading: '먹다',
                rules: 'v5',
                score: 0,
                glossaries: [],
                frequencies: [],
                pitches: [],
              ),
            ),
          ];
        },
      );

      expect(queries.first, '먹었습니다');
      expect(queries, contains('먹다'));
      expect(results.single.matched, '먹었습니다');
      expect(results.single.term.expression, '먹다');
      expect(results.single.trace.first.name, startsWith('Korean '));
    },
  );

  test(
    'parsed full-word lemmas rank ahead of shorter direct matches',
    () async {
      final results = await lookupKoreanDictionary(
        text: '먹었습니다',
        maxResults: 2,
        scanLength: 20,
        morphologyAnalyzer: const _UnavailableMorphologyAnalyzer(),
        lookup: (text, maxResults, scanLength) async {
          if (text == '먹었습니다') return [_result('먹', '먹')];
          if (text == '먹다') return [_result('먹다', '먹다')];
          return const [];
        },
      );

      expect(results.map((result) => result.term.expression), ['먹다', '먹']);
      expect(results.first.matched, '먹었습니다');
    },
  );

  test('uses Kiwi morphemes as Korean dictionary lemmas', () async {
    final queries = <String>[];
    final results = await lookupKoreanDictionary(
      text: '먹었어요',
      maxResults: 5,
      scanLength: 20,
      morphologyAnalyzer: const _FakeKiwiAnalyzer(),
      lookup: (text, maxResults, scanLength) async {
        queries.add(text);
        return text == '먹다' ? [_result('먹다', '먹다')] : const [];
      },
    );

    expect(queries, contains('먹다'));
    expect(results.single.matched, '먹었어요');
    expect(results.single.term.expression, '먹다');
    expect(results.single.trace.first.name, 'Korean Kiwi Verb');
    expect(results.single.trace.first.description, contains('(verb)'));
    expect(results.single.trace.first.name, isNot(contains('VV')));
  });

  test('renders Kiwi conjugation suffixes as meaningful text', () async {
    final results = await lookupKoreanDictionary(
      text: '가는다랗고',
      maxResults: 5,
      scanLength: 20,
      morphologyAnalyzer: const _FakeIrregularKiwiAnalyzer(),
      lookup: (text, maxResults, scanLength) async {
        return text == '가느다랗다' ? [_result('가느다랗다', '가느다랗다')] : const [];
      },
    );

    expect(
      results.single.trace.first.name,
      'Korean Kiwi Adjective · Irregular conjugation',
    );
    expect(
      results.single.trace.first.description,
      contains('(adjective, irregular conjugation)'),
    );
    expect(results.single.trace.first.name, isNot(contains('VA-I')));
  });
}

class _UnavailableMorphologyAnalyzer implements KoreanMorphologyAnalyzer {
  const _UnavailableMorphologyAnalyzer();

  @override
  Future<List<KoreanMorpheme>> analyze(String text) {
    throw StateError('Kiwi unavailable in fallback test');
  }
}

class _FakeKiwiAnalyzer implements KoreanMorphologyAnalyzer {
  const _FakeKiwiAnalyzer();

  @override
  Future<List<KoreanMorpheme>> analyze(String text) async => const [
    KoreanMorpheme(form: '먹', tag: 'VV', start: 0, length: 1),
    KoreanMorpheme(form: '었', tag: 'EP', start: 1, length: 1),
    KoreanMorpheme(form: '어요', tag: 'EF', start: 2, length: 2),
  ];
}

class _FakeIrregularKiwiAnalyzer implements KoreanMorphologyAnalyzer {
  const _FakeIrregularKiwiAnalyzer();

  @override
  Future<List<KoreanMorpheme>> analyze(String text) async => const [
    KoreanMorpheme(form: '가느다랗', tag: 'VA-I', start: 0, length: 5),
    KoreanMorpheme(form: '고', tag: 'EC', start: 5, length: 1),
  ];
}

HoshiLookupResult _result(String matched, String expression) {
  return HoshiLookupResult(
    matched: matched,
    deinflected: expression,
    trace: const [],
    preprocessorSteps: 0,
    term: HoshiTermResult(
      expression: expression,
      reading: expression,
      rules: '',
      score: 0,
      glossaries: const [],
      frequencies: const [],
      pitches: const [],
    ),
  );
}
