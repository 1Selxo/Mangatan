import 'dart:collection';

import 'package:mangayomi/services/hoshidicts/kiwi_korean_analyzer.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

/// Lightweight fallback used only when Kiwi cannot initialize on the device.
/// Normal Korean lookup is driven by Kiwi's contextual morphology analysis.
class KoreanLanguageParser {
  const KoreanLanguageParser();

  List<KoreanLookupCandidate> candidates(String text, {int scanLength = 20}) {
    final token = _leadingKoreanToken(text, scanLength);
    if (token.isEmpty) return const [];

    final candidates = <String, KoreanLookupCandidate>{};

    void add(String lemma, List<KoreanTransform> trace, int priority) {
      final normalized = lemma.trim();
      if (normalized.isEmpty || normalized == token) return;
      final existing = candidates[normalized];
      final candidate = KoreanLookupCandidate(
        surface: token,
        lemma: normalized,
        trace: List.unmodifiable(trace),
        priority: priority,
      );
      if (existing == null || candidate.priority < existing.priority) {
        candidates[normalized] = candidate;
      }
    }

    for (final rule in _particleRules) {
      if (!token.endsWith(rule.suffix) || token.length <= rule.suffix.length) {
        continue;
      }
      final stem = token.substring(0, token.length - rule.suffix.length);
      add(stem, [
        KoreanTransform(rule.label, 'Removed ${rule.suffix}'),
      ], rule.priority);
      if (stem.endsWith('들') && stem.length > 1) {
        add(stem.substring(0, stem.length - 1), [
          KoreanTransform(rule.label, 'Removed ${rule.suffix}'),
          const KoreanTransform('plural', 'Removed 들'),
        ], rule.priority + 2);
      }
    }

    for (final rule in _copulaRules) {
      if (!token.endsWith(rule.suffix) || token.length <= rule.suffix.length) {
        continue;
      }
      final noun = token.substring(0, token.length - rule.suffix.length);
      add(noun, [
        KoreanTransform('copula', 'Removed ${rule.suffix}'),
      ], rule.priority);
      add('이다', [
        KoreanTransform('copula', 'Recognized ${rule.suffix}'),
      ], rule.priority + 4);
    }

    final endingStems = <_StemAnalysis>[];
    for (final rule in _verbEndingRules) {
      if (!token.endsWith(rule.suffix) || token.length <= rule.suffix.length) {
        continue;
      }
      endingStems.add(
        _StemAnalysis(token.substring(0, token.length - rule.suffix.length), [
          KoreanTransform(rule.label, 'Removed ${rule.suffix}'),
        ], rule.priority),
      );
    }

    for (final analysis in endingStems) {
      for (final stem in _normalizeVerbStem(analysis)) {
        if (stem.value.isEmpty) continue;
        add('${stem.value}다', stem.trace, stem.priority);
      }
    }

    return candidates.values.toList()..sort((a, b) {
      final priority = a.priority.compareTo(b.priority);
      if (priority != 0) return priority;
      final trace = a.trace.length.compareTo(b.trace.length);
      if (trace != 0) return trace;
      return b.lemma.length.compareTo(a.lemma.length);
    });
  }

  List<_StemAnalysis> _normalizeVerbStem(_StemAnalysis initial) {
    final queue = Queue<_StemAnalysis>()..add(initial);
    final output = <String, _StemAnalysis>{};

    void enqueue(
      _StemAnalysis source,
      String value,
      String name,
      String description, {
      int cost = 1,
    }) {
      if (value.isEmpty || value == source.value) return;
      queue.add(
        _StemAnalysis(value, [
          ...source.trace,
          KoreanTransform(name, description),
        ], source.priority + cost),
      );
    }

    while (queue.isNotEmpty && output.length < 28) {
      final current = queue.removeFirst();
      final previous = output[current.value];
      if (previous != null && previous.priority <= current.priority) continue;
      output[current.value] = current;
      final value = current.value;

      for (final suffix in const ['겠', '시', '으시']) {
        if (value.endsWith(suffix) && value.length > suffix.length) {
          enqueue(
            current,
            value.substring(0, value.length - suffix.length),
            suffix == '겠' ? 'future/intent' : 'honorific',
            'Removed $suffix',
          );
        }
      }
      for (final suffix in const ['았', '었', '였']) {
        if (value.endsWith(suffix) && value.length > suffix.length) {
          enqueue(
            current,
            value.substring(0, value.length - suffix.length),
            'past tense',
            'Removed $suffix',
          );
        }
      }

      final last = value.substring(value.length - 1);
      final syllable = _HangulSyllable.tryParse(last);
      if (syllable == null) continue;
      final prefix = value.substring(0, value.length - last.length);

      if (syllable.coda == _codaSs) {
        enqueue(
          current,
          '$prefix${syllable.withCoda(0)}',
          'past tense',
          'Removed contracted ㅆ',
        );
      }
      if (syllable.coda == _codaBieup) {
        enqueue(
          current,
          '$prefix${syllable.withCoda(0)}',
          'formal ending',
          'Removed contracted ㅂ',
        );
      }
      if (syllable.coda == _codaNieun) {
        enqueue(
          current,
          '$prefix${syllable.withCoda(0)}',
          'adnominal/declarative ending',
          'Removed contracted ㄴ',
          cost: 2,
        );
      }
      if (syllable.coda == _codaRieul) {
        enqueue(
          current,
          '$prefix${syllable.withCoda(_codaDigeut)}',
          'ㄷ irregular',
          'Restored ㄷ from ㄹ',
          cost: 5,
        );
      } else if (syllable.coda == 0) {
        enqueue(
          current,
          '$prefix${syllable.withCoda(_codaSiot)}',
          'ㅅ irregular',
          'Restored dropped ㅅ',
          cost: 6,
        );
      }

      final contracted = _contractedVowelStem(syllable);
      if (contracted != null) {
        enqueue(
          current,
          '$prefix$contracted',
          'vowel contraction',
          'Expanded ${syllable.character}',
          cost: 2,
        );
      }
      if (last == '해') {
        enqueue(current, '$prefix하', '하다 contraction', 'Expanded 해');
      } else if (last == '돼') {
        enqueue(current, '$prefix되', '되다 contraction', 'Expanded 돼');
      } else if (last == '셔') {
        enqueue(current, '$prefix시', 'vowel contraction', 'Expanded 셔');
      }

      if (value.length > 1 && (last == '와' || last == '워')) {
        final previousText = value.substring(0, value.length - last.length);
        final previousLast = previousText.substring(previousText.length - 1);
        final previousSyllable = _HangulSyllable.tryParse(previousLast);
        if (previousSyllable != null && previousSyllable.coda == 0) {
          final beforePrevious = previousText.substring(
            0,
            previousText.length - previousLast.length,
          );
          enqueue(
            current,
            '$beforePrevious${previousSyllable.withCoda(_codaBieup)}',
            'ㅂ irregular',
            'Restored ㅂ before $last',
            cost: 3,
          );
        }
      }

      if (value.length > 1 && last == '라') {
        final previousText = value.substring(0, value.length - last.length);
        final previousLast = previousText.substring(previousText.length - 1);
        final previousSyllable = _HangulSyllable.tryParse(previousLast);
        if (previousSyllable?.coda == _codaRieul) {
          final beforePrevious = previousText.substring(
            0,
            previousText.length - previousLast.length,
          );
          enqueue(
            current,
            '$beforePrevious${previousSyllable!.withCoda(0)}르',
            '르 irregular',
            'Restored 르 from ㄹ라',
            cost: 3,
          );
        }
      }

      if (value.length > 1 && last == '어') {
        final previousText = value.substring(0, value.length - last.length);
        final previousLast = previousText.substring(previousText.length - 1);
        final previousSyllable = _HangulSyllable.tryParse(previousLast);
        if (previousSyllable != null) {
          final beforePrevious = previousText.substring(
            0,
            previousText.length - previousLast.length,
          );
          if (previousSyllable.coda == _codaRieul) {
            enqueue(
              current,
              '$beforePrevious${previousSyllable.withCoda(_codaDigeut)}',
              'ㄷ irregular',
              'Restored ㄷ before 어',
              cost: 4,
            );
          } else if (previousSyllable.coda == 0) {
            enqueue(
              current,
              '$beforePrevious${previousSyllable.withCoda(_codaSiot)}',
              'ㅅ irregular',
              'Restored ㅅ before 어',
              cost: 5,
            );
          }
        }
      }
    }

    return output.values.toList();
  }
}

class KoreanLookupCandidate {
  const KoreanLookupCandidate({
    required this.surface,
    required this.lemma,
    required this.trace,
    required this.priority,
  });

  final String surface;
  final String lemma;
  final List<KoreanTransform> trace;
  final int priority;
}

class KoreanTransform {
  const KoreanTransform(this.name, this.description);

  final String name;
  final String description;
}

typedef HoshiLookupCallback =
    Future<List<HoshiLookupResult>> Function(
      String text,
      int maxResults,
      int scanLength,
    );

Future<List<HoshiLookupResult>> lookupKoreanDictionary({
  required String text,
  required int maxResults,
  required int scanLength,
  required HoshiLookupCallback lookup,
  KoreanLanguageParser parser = const KoreanLanguageParser(),
  KoreanMorphologyAnalyzer? morphologyAnalyzer,
}) async {
  final direct = await lookup(text, maxResults, scanLength);
  final merged = <String, HoshiLookupResult>{};
  final tokenLength = _leadingKoreanToken(text, scanLength).runes.length;
  final exactDirect = direct.where(
    (result) => result.matched.runes.length == tokenLength,
  );
  final shorterDirect = direct.where(
    (result) => result.matched.runes.length != tokenLength,
  );
  for (final result in exactDirect) {
    merged['${result.term.expression}\u0000${result.term.reading}'] = result;
  }

  List<KoreanLookupCandidate> candidates;
  try {
    candidates = await _kiwiLookupCandidates(
      text,
      scanLength: scanLength,
      analyzer: morphologyAnalyzer ?? KiwiKoreanAnalyzer.instance,
    );
  } catch (_) {
    // Keep dictionary lookup usable if the native library or its model cannot
    // be initialized on a particular device.
    candidates = parser.candidates(text, scanLength: scanLength);
  }
  for (final candidate in candidates) {
    if (merged.length >= maxResults) break;
    final remaining = maxResults - merged.length;
    final results = await lookup(
      candidate.lemma,
      remaining,
      candidate.lemma.runes.length,
    );
    for (final result in results) {
      if (result.matched.runes.length != candidate.lemma.runes.length) {
        continue;
      }
      final key = '${result.term.expression}\u0000${result.term.reading}';
      merged.putIfAbsent(
        key,
        () => HoshiLookupResult(
          matched: candidate.surface,
          deinflected: result.deinflected,
          trace: [
            for (final transform in candidate.trace)
              HoshiTransformGroup(
                name: 'Korean ${transform.name}',
                description: transform.description,
              ),
            ...result.trace,
          ],
          preprocessorSteps: result.preprocessorSteps,
          term: result.term,
        ),
      );
      if (merged.length >= maxResults) break;
    }
  }
  for (final result in shorterDirect) {
    if (merged.length >= maxResults) break;
    merged.putIfAbsent(
      '${result.term.expression}\u0000${result.term.reading}',
      () => result,
    );
  }
  return List.unmodifiable(merged.values.take(maxResults));
}

Future<List<KoreanLookupCandidate>> _kiwiLookupCandidates(
  String text, {
  required int scanLength,
  required KoreanMorphologyAnalyzer analyzer,
}) async {
  final surface = _leadingKoreanToken(text, scanLength);
  if (surface.isEmpty) return const [];
  final context = text.trimLeft();
  final analysisText = context.length <= 160
      ? context
      : context.substring(0, 160);
  final morphemes = await analyzer.analyze(analysisText);
  final candidates = <String, KoreanLookupCandidate>{};
  var priority = 0;
  for (final morpheme in morphemes) {
    if (morpheme.start >= surface.length) break;
    if (!_isKiwiDictionaryTag(morpheme.tag)) continue;
    final lemma = _kiwiDictionaryLemma(morpheme.form, morpheme.tag);
    if (lemma.isEmpty || lemma == surface) continue;
    candidates.putIfAbsent(
      lemma,
      () => KoreanLookupCandidate(
        surface: surface,
        lemma: lemma,
        trace: [
          KoreanTransform(
            'Kiwi ${morpheme.tag}',
            'Kiwi analyzed $surface as ${morpheme.form}/${morpheme.tag}',
          ),
        ],
        priority: priority++,
      ),
    );
  }
  return candidates.values.toList(growable: false);
}

bool _isKiwiDictionaryTag(String rawTag) {
  final tag = rawTag.split('-').first.toUpperCase();
  return tag.startsWith('N') ||
      tag.startsWith('V') ||
      tag == 'XR' ||
      tag == 'XSV' ||
      tag == 'XSA' ||
      tag == 'XSN' ||
      tag == 'MM' ||
      tag == 'MAG' ||
      tag == 'MAJ' ||
      tag == 'IC';
}

String _kiwiDictionaryLemma(String form, String rawTag) {
  final normalized = form.trim();
  if (normalized.isEmpty) return '';
  final tag = rawTag.split('-').first.toUpperCase();
  final isPredicate = tag.startsWith('V') || tag == 'XSV' || tag == 'XSA';
  return isPredicate && !normalized.endsWith('다')
      ? '$normalized다'
      : normalized;
}

String _leadingKoreanToken(String text, int scanLength) {
  final buffer = StringBuffer();
  var count = 0;
  for (final rune in text.trimLeft().runes) {
    if (count >= scanLength || !_isKoreanRune(rune)) break;
    buffer.writeCharCode(rune);
    count++;
  }
  return buffer.toString();
}

bool _isKoreanRune(int rune) =>
    (rune >= 0xAC00 && rune <= 0xD7A3) ||
    (rune >= 0x1100 && rune <= 0x11FF) ||
    (rune >= 0x3130 && rune <= 0x318F) ||
    (rune >= 0xA960 && rune <= 0xA97F) ||
    (rune >= 0xD7B0 && rune <= 0xD7FF);

class _SuffixRule {
  const _SuffixRule(this.suffix, this.label, this.priority);

  final String suffix;
  final String label;
  final int priority;
}

const _particleRules = <_SuffixRule>[
  _SuffixRule('으로부터', 'source particle', 10),
  _SuffixRule('에게서', 'source particle', 10),
  _SuffixRule('한테서', 'source particle', 10),
  _SuffixRule('으로써', 'instrument particle', 10),
  _SuffixRule('으로서', 'role particle', 10),
  _SuffixRule('이라도', 'additive particle', 11),
  _SuffixRule('에서부터', 'source particle', 11),
  _SuffixRule('까지도', 'limit particle', 12),
  _SuffixRule('에서', 'location particle', 13),
  _SuffixRule('에게', 'dative particle', 13),
  _SuffixRule('한테', 'dative particle', 13),
  _SuffixRule('께서', 'honorific subject particle', 13),
  _SuffixRule('처럼', 'comparison particle', 14),
  _SuffixRule('보다', 'comparison particle', 14),
  _SuffixRule('부터', 'source particle', 14),
  _SuffixRule('까지', 'limit particle', 14),
  _SuffixRule('밖에', 'exclusive particle', 14),
  _SuffixRule('조차', 'additive particle', 14),
  _SuffixRule('마저', 'additive particle', 14),
  _SuffixRule('마다', 'distributive particle', 14),
  _SuffixRule('하고', 'comitative particle', 15),
  _SuffixRule('이랑', 'comitative particle', 15),
  _SuffixRule('으로', 'direction particle', 15),
  _SuffixRule('라고', 'quotation particle', 16),
  _SuffixRule('라고는', 'quotation/topic particle', 16),
  _SuffixRule('은', 'topic particle', 20),
  _SuffixRule('는', 'topic particle', 20),
  _SuffixRule('이', 'subject particle', 20),
  _SuffixRule('가', 'subject particle', 20),
  _SuffixRule('을', 'object particle', 20),
  _SuffixRule('를', 'object particle', 20),
  _SuffixRule('의', 'possessive particle', 20),
  _SuffixRule('에', 'location/time particle', 20),
  _SuffixRule('께', 'honorific dative particle', 20),
  _SuffixRule('와', 'comitative particle', 20),
  _SuffixRule('과', 'comitative particle', 20),
  _SuffixRule('랑', 'comitative particle', 20),
  _SuffixRule('로', 'direction particle', 20),
  _SuffixRule('도', 'additive particle', 20),
  _SuffixRule('만', 'restrictive particle', 20),
];

const _copulaRules = <_SuffixRule>[
  _SuffixRule('이었습니다', 'copula', 5),
  _SuffixRule('였습니다', 'copula', 5),
  _SuffixRule('이었어요', 'copula', 5),
  _SuffixRule('였어요', 'copula', 5),
  _SuffixRule('입니다', 'copula', 6),
  _SuffixRule('이에요', 'copula', 6),
  _SuffixRule('예요', 'copula', 6),
  _SuffixRule('이었다', 'copula', 7),
  _SuffixRule('였다', 'copula', 7),
  _SuffixRule('이라면', 'copula', 8),
  _SuffixRule('라면', 'copula', 8),
  _SuffixRule('이고', 'copula', 9),
  _SuffixRule('이고요', 'copula', 9),
  _SuffixRule('이라', 'copula', 9),
  _SuffixRule('이다', 'copula', 9),
];

const _verbEndingRules = <_SuffixRule>[
  _SuffixRule('으셨습니다', 'honorific formal ending', 3),
  _SuffixRule('셨습니다', 'honorific formal ending', 3),
  _SuffixRule('겠습니다', 'future formal ending', 3),
  _SuffixRule('었습니다', 'past formal ending', 3),
  _SuffixRule('았습니다', 'past formal ending', 3),
  _SuffixRule('였습니다', 'past formal ending', 3),
  _SuffixRule('습니까', 'formal question ending', 4),
  _SuffixRule('습니다', 'formal ending', 4),
  _SuffixRule('니까', 'formal question ending', 4),
  _SuffixRule('니다', 'formal ending', 4),
  _SuffixRule('ㅂ니까', 'formal question ending', 4),
  _SuffixRule('ㅂ니다', 'formal ending', 4),
  _SuffixRule('으세요', 'honorific request ending', 5),
  _SuffixRule('세요', 'honorific request ending', 5),
  _SuffixRule('십시오', 'honorific imperative ending', 5),
  _SuffixRule('었어요', 'past polite ending', 5),
  _SuffixRule('았어요', 'past polite ending', 5),
  _SuffixRule('였어요', 'past polite ending', 5),
  _SuffixRule('겠어요', 'future polite ending', 5),
  _SuffixRule('으니까', 'reason ending', 7),
  _SuffixRule('니까', 'reason ending', 7),
  _SuffixRule('으면서', 'simultaneous ending', 7),
  _SuffixRule('면서', 'simultaneous ending', 7),
  _SuffixRule('으려고', 'intent ending', 7),
  _SuffixRule('려고', 'intent ending', 7),
  _SuffixRule('더라도', 'concessive ending', 8),
  _SuffixRule('았지만', 'past contrast ending', 8),
  _SuffixRule('었지만', 'past contrast ending', 8),
  _SuffixRule('지만', 'contrast ending', 8),
  _SuffixRule('는데', 'background ending', 8),
  _SuffixRule('은데', 'background ending', 8),
  _SuffixRule('ㄴ데', 'background ending', 8),
  _SuffixRule('아서', 'connective ending', 8),
  _SuffixRule('어서', 'connective ending', 8),
  _SuffixRule('여서', 'connective ending', 8),
  _SuffixRule('으러', 'purpose ending', 9),
  _SuffixRule('러', 'purpose ending', 9),
  _SuffixRule('으려', 'intent ending', 9),
  _SuffixRule('려', 'intent ending', 9),
  _SuffixRule('는다', 'declarative ending', 9),
  _SuffixRule('ㄴ다', 'declarative ending', 9),
  _SuffixRule('어요', 'polite ending', 10),
  _SuffixRule('아요', 'polite ending', 10),
  _SuffixRule('여요', 'polite ending', 10),
  _SuffixRule('네요', 'exclamatory ending', 11),
  _SuffixRule('군요', 'exclamatory ending', 11),
  _SuffixRule('지요', 'confirmation ending', 11),
  _SuffixRule('죠', 'confirmation ending', 11),
  _SuffixRule('고', 'connective ending', 12),
  _SuffixRule('며', 'connective ending', 12),
  _SuffixRule('면', 'conditional ending', 12),
  _SuffixRule('자', 'propositive ending', 12),
  _SuffixRule('라', 'imperative/quotation ending', 13),
  _SuffixRule('어', 'informal ending', 14),
  _SuffixRule('아', 'informal ending', 14),
  _SuffixRule('여', 'informal ending', 14),
  _SuffixRule('요', 'polite marker', 15),
  _SuffixRule('는', 'adnominal ending', 16),
  _SuffixRule('은', 'adnominal ending', 16),
  _SuffixRule('ㄴ', 'adnominal ending', 16),
  _SuffixRule('을', 'prospective adnominal ending', 16),
  _SuffixRule('ㄹ', 'prospective adnominal ending', 16),
  _SuffixRule('기', 'nominalizing ending', 17),
  _SuffixRule('음', 'nominalizing ending', 17),
  _SuffixRule('지', 'negation/connective ending', 17),
  _SuffixRule('다', 'dictionary/declarative ending', 18),
];

class _StemAnalysis {
  const _StemAnalysis(this.value, this.trace, this.priority);

  final String value;
  final List<KoreanTransform> trace;
  final int priority;
}

const _hangulBase = 0xAC00;
const _hangulEnd = 0xD7A3;
const _vowelA = 0;
const _vowelEo = 4;
const _vowelO = 8;
const _vowelWa = 9;
const _vowelWae = 10;
const _vowelU = 13;
const _vowelWo = 14;
const _vowelEu = 18;
const _vowelI = 20;
const _vowelEui = 19;
const _codaNieun = 4;
const _codaDigeut = 7;
const _codaRieul = 8;
const _codaBieup = 17;
const _codaSiot = 19;
const _codaSs = 20;

class _HangulSyllable {
  const _HangulSyllable(this.onset, this.vowel, this.coda);

  final int onset;
  final int vowel;
  final int coda;

  static _HangulSyllable? tryParse(String character) {
    if (character.runes.length != 1) return null;
    final rune = character.runes.single;
    if (rune < _hangulBase || rune > _hangulEnd) return null;
    final offset = rune - _hangulBase;
    return _HangulSyllable(
      offset ~/ (21 * 28),
      (offset % (21 * 28)) ~/ 28,
      offset % 28,
    );
  }

  String get character => withCoda(coda);

  String withCoda(int nextCoda) =>
      String.fromCharCode(_hangulBase + (onset * 21 + vowel) * 28 + nextCoda);

  String withVowel(int nextVowel) =>
      String.fromCharCode(_hangulBase + (onset * 21 + nextVowel) * 28 + coda);
}

String? _contractedVowelStem(_HangulSyllable syllable) {
  switch (syllable.vowel) {
    case _vowelWa:
      return syllable.withVowel(_vowelO);
    case _vowelWo:
      return syllable.withVowel(_vowelU);
    case _vowelWae:
      return syllable.withVowel(11); // ㅚ: 돼 -> 되
    case _vowelEo:
      return syllable.withVowel(_vowelEu); // 써 -> 쓰 (candidate)
    case _vowelEui:
      return syllable.withVowel(_vowelI);
    case _vowelA:
    case _vowelO:
    case _vowelU:
    case _vowelEu:
    case _vowelI:
      return null;
  }
  return null;
}
