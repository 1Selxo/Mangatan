import 'dart:convert';
import 'dart:typed_data';

import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/services/hoshidicts/yomitan_kanji_dictionary.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

List<HoshiLookupResult> adaptHachidoriLookupResults(Object? value) {
  final rows = _list(value, 'lookup results');
  return List<HoshiLookupResult>.unmodifiable(
    rows.map((row) {
      final result = _map(row, 'lookup result');
      final term = _map(result['term'], 'lookup term');
      return HoshiLookupResult(
        matched: _string(result['matched'], 'matched'),
        deinflected: _string(result['deinflected'], 'deinflected'),
        trace: List<HoshiTransformGroup>.unmodifiable(
          _list(result['trace'], 'lookup trace').map((rawTrace) {
            final trace = _map(rawTrace, 'lookup trace row');
            return HoshiTransformGroup(
              name: _string(trace['name'], 'trace name'),
              description: _string(trace['description'], 'trace description'),
            );
          }),
        ),
        preprocessorSteps: _integer(
          result['preprocessorSteps'],
          'preprocessorSteps',
          minimum: 0,
        ),
        term: HoshiTermResult(
          expression: _string(term['expression'], 'term expression'),
          reading: _string(term['reading'], 'term reading'),
          rules: _string(term['rules'], 'term rules'),
          score: _integer(term['score'], 'term score'),
          glossaries: List<HoshiGlossaryEntry>.unmodifiable(
            _list(term['glossaries'], 'term glossaries').map((rawGlossary) {
              final glossary = _map(rawGlossary, 'glossary row');
              return HoshiGlossaryEntry(
                dictName: _string(
                  glossary['dictionary'],
                  'glossary dictionary',
                ),
                glossary: _string(glossary['glossary'], 'glossary'),
                definitionTags: _string(
                  glossary['definitionTags'],
                  'definition tags',
                ),
                termTags: _string(glossary['termTags'], 'term tags'),
              );
            }),
          ),
          frequencies: List<HoshiFrequencyEntry>.unmodifiable(
            _list(term['frequencies'], 'term frequencies').map((rawEntry) {
              final entry = _map(rawEntry, 'frequency entry');
              return HoshiFrequencyEntry(
                dictName: _string(entry['dictionary'], 'frequency dictionary'),
                frequencies: List<HoshiFrequency>.unmodifiable(
                  _list(entry['frequencies'], 'frequency values').map((
                    rawFrequency,
                  ) {
                    final frequency = _map(rawFrequency, 'frequency value');
                    return HoshiFrequency(
                      value: _integer(frequency['value'], 'frequency'),
                      displayValue: _string(
                        frequency['displayValue'],
                        'frequency display value',
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
          pitches: List<HoshiPitchEntry>.unmodifiable(
            _list(term['pitches'], 'term pitches').map((rawEntry) {
              final entry = _map(rawEntry, 'pitch entry');
              final positions = <int>[];
              for (final rawPitch in _list(entry['pitches'], 'pitch values')) {
                final pitch = _map(rawPitch, 'pitch value');
                positions.add(
                  _integer(
                    pitch['position'],
                    'pitch position',
                    minimum: 0,
                    maximum: 0x7fffffff,
                  ),
                );
                _string(pitch['pattern'], 'pitch pattern');
                _integerList(pitch['nasal'], 'pitch nasal positions');
                _integerList(pitch['devoice'], 'pitch devoice positions');
              }
              return HoshiPitchEntry(
                dictName: _string(entry['dictionary'], 'pitch dictionary'),
                pitchPositions: Int32List.fromList(positions),
                transcriptions: List<String>.unmodifiable(
                  _list(
                    entry['transcriptions'],
                    'pitch transcriptions',
                  ).map((value) => _string(value, 'pitch transcription')),
                ),
              );
            }),
          ),
        ),
      );
    }),
  );
}

List<HoshiLookupResult> adaptHachidoriKanji(Object? value) {
  if (value == null) return const [];
  final kanji = _map(value, 'Kanji result');
  final character = _string(kanji['character'], 'Kanji character');
  if (character.isEmpty) _malformed('Kanji character');
  return List<HoshiLookupResult>.unmodifiable(
    _list(kanji['entries'], 'Kanji entries').map((rawEntry) {
      final entry = _map(rawEntry, 'Kanji entry');
      final dictionary = _string(entry['dictionary'], 'Kanji dictionary');
      final tags = _splitWords(_string(entry['tags'], 'Kanji tags'));
      final definitions = List<String>.unmodifiable(
        _list(
          entry['definitions'],
          'Kanji definitions',
        ).map((definition) => _string(definition, 'Kanji definition')),
      );
      final stats = List<Map<String, String>>.unmodifiable(
        _list(entry['stats'], 'Kanji stats').map((rawStat) {
          final stat = _map(rawStat, 'Kanji stat');
          final name = _string(stat['name'], 'Kanji stat name');
          return {
            'name': name,
            'content': name,
            'value': _string(stat['value'], 'Kanji stat value'),
          };
        }),
      );
      final glossary = jsonEncode({
        'type': yomitanKanjiContentType,
        'character': character,
        'dictionary': dictionary,
        'frequencies': const <Object?>[],
        'onyomi': _splitWords(_string(entry['onyomi'], 'Kanji onyomi')),
        'kunyomi': _splitWords(_string(entry['kunyomi'], 'Kanji kunyomi')),
        'tags': [
          for (final tag in tags) {'name': tag, 'content': tag},
        ],
        'definitions': definitions,
        'stats': {'misc': stats},
      });
      return HoshiLookupResult(
        matched: character,
        deinflected: character,
        trace: const [],
        preprocessorSteps: 0,
        term: HoshiTermResult(
          expression: character,
          reading: '',
          rules: '',
          score: 0,
          glossaries: [
            HoshiGlossaryEntry(
              dictName: dictionary,
              glossary: glossary,
              definitionTags: '',
              termTags: '',
            ),
          ],
          frequencies: const [],
          pitches: const [],
        ),
      );
    }),
  );
}

List<HoshiDictionaryStyle> adaptHachidoriStyles(Object? value) =>
    List<HoshiDictionaryStyle>.unmodifiable(
      _list(value, 'dictionary styles').map((rawStyle) {
        final style = _map(rawStyle, 'dictionary style');
        return HoshiDictionaryStyle(
          dictName: _string(style['dictionary'], 'style dictionary'),
          styles: _string(style['styles'], 'dictionary CSS'),
        );
      }),
    );

Uint8List? adaptHachidoriMedia(Object? value) {
  if (value == null) return null;
  if (value is! String) _malformed('media data URL');
  final match = RegExp(
    r'^data:([a-z0-9.+-]+/[a-z0-9.+-]+);base64,([A-Za-z0-9+/]+={0,2})$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) _malformed('media data URL');
  const mediaTypes = {
    'image/avif',
    'image/webp',
    'image/png',
    'image/jpeg',
    'image/gif',
    'image/svg+xml',
  };
  final mediaType = match.group(1)!.toLowerCase();
  final payload = match.group(2)!;
  if (!mediaTypes.contains(mediaType) || payload.length % 4 != 0) {
    _malformed('media data URL');
  }
  try {
    final decoded = base64Decode(payload);
    if (decoded.isEmpty) _malformed('media data URL');
    return decoded;
  } on FormatException {
    _malformed('media data URL');
  }
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map || value is List) _malformed(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) _malformed(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) _malformed(field);
  return value.cast<Object?>();
}

String _string(Object? value, String field) {
  if (value is! String) _malformed(field);
  return value;
}

int _integer(Object? value, String field, {int? minimum, int? maximum}) {
  if (value is! int ||
      (minimum != null && value < minimum) ||
      (maximum != null && value > maximum)) {
    _malformed(field);
  }
  return value;
}

List<int> _integerList(Object? value, String field) =>
    _list(value, field).map((item) => _integer(item, field)).toList();

List<String> _splitWords(String value) => value
    .split(RegExp(r'\s+'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList(growable: false);

Never _malformed(String field) {
  throw HachidoriProtocolException('malformed Hachidori $field');
}
