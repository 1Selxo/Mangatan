import 'dart:convert';
import 'dart:typed_data';

import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

class AnkiCardBuilder {
  const AnkiCardBuilder();

  Future<AnkiCardDraft> build({
    required HoshiLookupResult result,
    required MiningContext context,
    AnkiMiningProfile profile = const AnkiMiningProfile(),
  }) async {
    final screenshotBytes = await _loadScreenshot(context);
    final screenshotName = screenshotBytes == null
        ? null
        : _safeMediaName(
            [
              context.sourceTitle,
              context.chapterTitle,
              result.term.expression,
              DateTime.now().millisecondsSinceEpoch.toString(),
            ].where((part) => part.trim().isNotEmpty).join(' '),
          );

    final replacements = <String, String>{
      AnkiMarker.expression: _escape(result.term.expression),
      AnkiMarker.reading: _escape(result.term.reading),
      AnkiMarker.furigana: _furigana(
        result.term.expression,
        result.term.reading,
      ),
      AnkiMarker.glossary: _glossary(result.term.glossaries),
      AnkiMarker.selectedGlossary: _glossary(result.term.glossaries.take(1)),
      AnkiMarker.sentence: _escape(context.sentence),
      AnkiMarker.sentenceFurigana: _escape(context.sentence),
      AnkiMarker.clozePrefix: _cloze(context.sentence, result.matched).$1,
      AnkiMarker.clozeBody: _cloze(context.sentence, result.matched).$2,
      AnkiMarker.clozeSuffix: _cloze(context.sentence, result.matched).$3,
      AnkiMarker.tags: profile.tags.join(' '),
      AnkiMarker.partOfSpeech: _escape(result.term.rules),
      AnkiMarker.dictionary: result.term.glossaries
          .map((entry) => entry.dictName)
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .map(_escape)
          .join(', '),
      AnkiMarker.frequencies: _frequencies(result.term.frequencies),
      AnkiMarker.frequencyHarmonic: _frequencySummary(result.term.frequencies),
      AnkiMarker.frequencyAverage: _frequencySummary(result.term.frequencies),
      AnkiMarker.pitchAccents: _pitchAccents(result.term.pitches),
      AnkiMarker.pitchAccentPositions: result.term.pitches
          .expand((pitch) => pitch.pitchPositions)
          .map((position) => position.toString())
          .toSet()
          .join(', '),
      AnkiMarker.pitchAccentCategories: result.term.pitches
          .map((pitch) => pitch.dictName)
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .map(_escape)
          .join(', '),
      AnkiMarker.screenshot: screenshotName == null
          ? ''
          : '<img src="$screenshotName">',
      AnkiMarker.wordAudio: '',
      AnkiMarker.sentenceAudio: '',
      AnkiMarker.url: _escape(context.sourceUri?.toString() ?? ''),
      AnkiMarker.book: _escape(context.sourceTitle),
      AnkiMarker.chapter: _escape(context.chapterTitle),
      AnkiMarker.media: _escape(context.locationLabel),
      AnkiMarker.source: _escape(context.locationLabel),
    };

    final fields = profile.fieldMap.map((field, template) {
      var value = template;
      for (final replacement in replacements.entries) {
        value = value.replaceAll(replacement.key, replacement.value);
      }
      return MapEntry(field, value);
    });

    return AnkiCardDraft(
      deckName: profile.deckName,
      modelName: profile.modelName,
      expression: result.term.expression,
      fields: fields,
      tags: profile.tags,
      screenshotBytes: screenshotBytes,
      screenshotFileName: screenshotName,
    );
  }

  Future<Uint8List?> _loadScreenshot(MiningContext context) async {
    final loader = context.imageBytesLoader;
    if (loader == null) return null;
    final bytes = await loader();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  static String _furigana(String expression, String reading) {
    if (reading.trim().isEmpty || reading == expression) {
      return _escape(expression);
    }
    return '<ruby>${_escape(expression)}<rt>${_escape(reading)}</rt></ruby>';
  }

  static String _glossary(Iterable<HoshiGlossaryEntry> entries) {
    final rows = entries.where((entry) => entry.glossary.trim().isNotEmpty).map(
      (entry) {
        final dict = entry.dictName.trim().isEmpty
            ? ''
            : '<span class="dict">${_escape(entry.dictName)}</span> ';
        return '<li>$dict${_escape(entry.glossary)}</li>';
      },
    ).join();
    return rows.isEmpty ? '' : '<ol>$rows</ol>';
  }

  static String _frequencies(List<HoshiFrequencyEntry> entries) {
    return entries
        .expand(
          (entry) => entry.frequencies.map(
            (frequency) =>
                '${entry.dictName}: ${frequency.displayValue.trim().isEmpty ? frequency.value : frequency.displayValue}',
          ),
        )
        .map(_escape)
        .join('<br>');
  }

  static String _frequencySummary(List<HoshiFrequencyEntry> entries) {
    final values = entries
        .expand((entry) => entry.frequencies)
        .map((frequency) => frequency.value)
        .toList();
    if (values.isEmpty) return '';
    values.sort();
    return values.first.toString();
  }

  static String _pitchAccents(List<HoshiPitchEntry> entries) {
    return entries
        .map((entry) {
          final positions = entry.pitchPositions
              .map((p) => p.toString())
              .join(', ');
          final transcriptions = entry.transcriptions.join(', ');
          return [
            if (entry.dictName.trim().isNotEmpty) entry.dictName,
            if (positions.isNotEmpty) positions,
            if (transcriptions.isNotEmpty) transcriptions,
          ].join(': ');
        })
        .where((text) => text.trim().isNotEmpty)
        .map(_escape)
        .join('<br>');
  }

  static (String, String, String) _cloze(String sentence, String matched) {
    if (sentence.trim().isEmpty || matched.trim().isEmpty) {
      return ('', _escape(matched), '');
    }
    final index = sentence.indexOf(matched);
    if (index < 0) return ('', _escape(matched), '');
    return (
      _escape(sentence.substring(0, index)),
      _escape(matched),
      _escape(sentence.substring(index + matched.length)),
    );
  }

  static String _safeMediaName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'mangayomi-mining' : safe}.png';
  }

  static String _escape(String value) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(value);
  }
}
