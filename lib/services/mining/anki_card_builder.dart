import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

class AnkiCardBuilder {
  const AnkiCardBuilder();

  Future<AnkiCardDraft> build({
    required HoshiLookupResult result,
    required MiningContext context,
    AnkiMiningProfile profile = const AnkiMiningProfile(),
    Map<String, dynamic> renderedContent = const {},
    List<AnkiMediaFile> dictionaryMedia = const [],
    AnkiMediaFile? wordAudio,
  }) async {
    final screenshot = await _loadScreenshot(context);
    final screenshotName = screenshot == null
        ? null
        : _safeMediaName(
            [
              context.sourceTitle,
              context.chapterTitle,
              result.term.expression,
              DateTime.now().millisecondsSinceEpoch.toString(),
            ].where((part) => part.trim().isNotEmpty).join(' '),
            extension: screenshot.extension,
          );

    final selectedGlossary = result.term.glossaries.take(1).toList();
    String rendered(String key, String fallback) {
      final value = renderedContent[key];
      return value is String && value.isNotEmpty ? value : fallback;
    }

    final glossary = rendered('glossary', _glossary(result.term.glossaries));
    final glossaryPlain = _glossaryPlain(result.term.glossaries);
    final selectedGlossaryHtml = rendered(
      'glossaryFirst',
      _glossary(selectedGlossary),
    );
    final selectedGlossaryPlain = _glossaryPlain(selectedGlossary);
    final frequencySummary = rendered(
      'freqHarmonicRank',
      _frequencySummary(result.term.frequencies),
    );
    final cloze = _cloze(context.sentence, result.matched);
    final wordAudioTag = wordAudio == null
        ? ''
        : '[sound:${_soundFilename(wordAudio.filename)}]';
    final replacements = <String, String>{
      AnkiMarker.expression: _escape(result.term.expression),
      AnkiMarker.reading: _escape(result.term.reading),
      AnkiMarker.furigana: _furigana(
        result.term.expression,
        result.term.reading,
      ),
      AnkiMarker.furiganaPlain: rendered(
        'furiganaPlain',
        _furiganaPlain(result.term.expression, result.term.reading),
      ),
      AnkiMarker.audio: wordAudioTag,
      AnkiMarker.glossary: glossary,
      AnkiMarker.glossaryBrief: selectedGlossaryHtml,
      AnkiMarker.glossaryPlain: glossaryPlain,
      AnkiMarker.glossaryFirst: selectedGlossaryHtml,
      AnkiMarker.selectedGlossary: selectedGlossaryHtml,
      AnkiMarker.singleGlossary: selectedGlossaryPlain,
      AnkiMarker.sentence: _escape(context.sentence),
      AnkiMarker.sentenceBold: _sentenceBold(context.sentence, result.matched),
      AnkiMarker.sentenceFurigana: _escape(context.sentence),
      AnkiMarker.clozePrefix: cloze.$1,
      AnkiMarker.clozeBody: cloze.$2,
      AnkiMarker.clozeBodyKana: cloze.$2,
      AnkiMarker.clozeSuffix: cloze.$3,
      AnkiMarker.tags: profile.tags.join(' '),
      AnkiMarker.partOfSpeech: _escape(result.term.rules),
      AnkiMarker.conjugation: _escape(
        result.trace.map((t) => t.name).join(' '),
      ),
      AnkiMarker.dictionary: result.term.glossaries
          .map((entry) => entry.dictName)
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .map(_escape)
          .join(', '),
      AnkiMarker.dictionaryAlias: result.term.glossaries
          .map((entry) => entry.dictName)
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .map(_escape)
          .join(', '),
      AnkiMarker.frequencies: rendered(
        'frequenciesHtml',
        _frequencies(result.term.frequencies),
      ),
      AnkiMarker.frequencyLowest: frequencySummary,
      AnkiMarker.frequencyHarmonic: frequencySummary,
      AnkiMarker.frequencyHarmonicRank: frequencySummary,
      AnkiMarker.frequencyAverage: frequencySummary,
      AnkiMarker.frequencyAverageRank: frequencySummary,
      AnkiMarker.pitchAccents: _pitchAccents(result.term.pitches),
      AnkiMarker.pitchAccentPositions: rendered(
        'pitchPositions',
        result.term.pitches
            .expand((pitch) => pitch.pitchPositions)
            .map((position) => position.toString())
            .toSet()
            .join(', '),
      ),
      AnkiMarker.pitchAccentCategories: rendered(
        'pitchCategories',
        result.term.pitches
            .map((pitch) => pitch.dictName)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .map(_escape)
            .join(', '),
      ),
      AnkiMarker.screenshot: screenshotName == null
          ? ''
          : '<img src="$screenshotName">',
      AnkiMarker.wordAudio: wordAudioTag,
      AnkiMarker.sentenceAudio: '',
      AnkiMarker.url: _escape(context.sourceUri?.toString() ?? ''),
      AnkiMarker.book: _escape(context.sourceTitle),
      AnkiMarker.chapter: _escape(context.chapterTitle),
      AnkiMarker.media: _escape(context.locationLabel),
      AnkiMarker.source: _escape(context.locationLabel),
      AnkiMarker.documentTitle: _escape(context.sourceTitle),
      AnkiMarker.selectionText: _escape(result.matched),
      AnkiMarker.popupSelectionText: rendered(
        'popupSelectionText',
        _escape(result.matched),
      ),
    };

    final fields = profile.fieldMap.map((field, template) {
      if (_normalizeFieldName(field) == 'definitionpicture') {
        return MapEntry(field, '');
      }
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
      screenshotBytes: screenshot?.bytes,
      screenshotFileName: screenshotName,
      mediaFiles: wordAudio == null
          ? dictionaryMedia
          : [...dictionaryMedia, wordAudio],
    );
  }

  Future<_ScreenshotPayload?> _loadScreenshot(MiningContext context) async {
    final loader = context.imageBytesLoader;
    if (loader == null) return null;
    final bytes = await loader();
    if (bytes == null || bytes.isEmpty) return null;
    final original = Uint8List.fromList(bytes);
    if (original.length <= _maxScreenshotUploadBytes) {
      return _ScreenshotPayload(original, _extensionForImage(original));
    }
    final resized = await _resizeScreenshot(original);
    if (resized != null && resized.length < original.length) {
      return _ScreenshotPayload(resized, 'png');
    }
    if (original.length <= _absoluteScreenshotUploadBytes) {
      return _ScreenshotPayload(original, _extensionForImage(original));
    }
    return null;
  }

  static String _furigana(String expression, String reading) {
    if (reading.trim().isEmpty || reading == expression) {
      return _escape(expression);
    }
    return '<ruby>${_escape(expression)}<rt>${_escape(reading)}</rt></ruby>';
  }

  static String _furiganaPlain(String expression, String reading) {
    if (reading.trim().isEmpty || reading == expression) return expression;
    return '$expression[$reading]';
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

  static String _glossaryPlain(Iterable<HoshiGlossaryEntry> entries) {
    return entries
        .map((entry) => entry.glossary.trim())
        .where((entry) => entry.isNotEmpty)
        .map(_escape)
        .join('<br>');
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

  static String _sentenceBold(String sentence, String matched) {
    if (sentence.trim().isEmpty || matched.trim().isEmpty) {
      return _escape(sentence);
    }
    final index = sentence.indexOf(matched);
    if (index < 0) return _escape(sentence);
    return [
      _escape(sentence.substring(0, index)),
      '<b>${_escape(matched)}</b>',
      _escape(sentence.substring(index + matched.length)),
    ].join();
  }

  static String _safeMediaName(String value, {required String extension}) {
    final safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'mangayomi-mining' : safe}.$extension';
  }

  static String _soundFilename(String value) {
    return value.replaceAll(']', '_');
  }

  static String _escape(String value) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(value);
  }

  static String _normalizeFieldName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

  static const _maxScreenshotUploadBytes = 4 * 1024 * 1024;
  static const _absoluteScreenshotUploadBytes = 8 * 1024 * 1024;
  static const _maxScreenshotDimension = 1280;

  static Future<Uint8List?> _resizeScreenshot(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      final longest = width > height ? width : height;
      if (longest <= _maxScreenshotDimension) return null;
      final scale = _maxScreenshotDimension / longest;
      codec = await descriptor.instantiateCodec(
        targetWidth: (width * scale).round().clamp(1, width),
        targetHeight: (height * scale).round().clamp(1, height),
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static String _extensionForImage(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'png';
  }
}

class _ScreenshotPayload {
  const _ScreenshotPayload(this.bytes, this.extension);

  final Uint8List bytes;
  final String extension;
}
