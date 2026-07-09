class AnkiMarker {
  static const expression = '{expression}';
  static const reading = '{reading}';
  static const furigana = '{furigana}';
  static const furiganaPlain = '{furigana-plain}';
  static const audio = '{audio}';
  static const glossary = '{glossary}';
  static const glossaryBrief = '{glossary-brief}';
  static const glossaryPlain = '{glossary-plain}';
  static const glossaryFirst = '{glossary-first}';
  static const selectedGlossary = '{selected-glossary}';
  static const singleGlossary = '{single-glossary}';
  static const sentence = '{sentence}';
  static const sentenceBold = '{sentence-bold}';
  static const sentenceFurigana = '{sentence-furigana}';
  static const clozePrefix = '{cloze-prefix}';
  static const clozeBody = '{cloze-body}';
  static const clozeBodyKana = '{cloze-body-kana}';
  static const clozeSuffix = '{cloze-suffix}';
  static const tags = '{tags}';
  static const partOfSpeech = '{part-of-speech}';
  static const conjugation = '{conjugation}';
  static const dictionary = '{dictionary}';
  static const dictionaryAlias = '{dictionary-alias}';
  static const frequencies = '{frequencies}';
  static const frequencyLowest = '{frequency-lowest}';
  static const frequencyHarmonic = '{frequency-harmonic}';
  static const frequencyHarmonicRank = '{frequency-harmonic-rank}';
  static const frequencyAverage = '{frequency-average}';
  static const frequencyAverageRank = '{frequency-average-rank}';
  static const pitchAccents = '{pitch-accents}';
  static const pitchAccentPositions = '{pitch-accent-positions}';
  static const pitchAccentCategories = '{pitch-accent-categories}';
  static const screenshot = '{screenshot}';
  static const wordAudio = '{word-audio}';
  static const sentenceAudio = '{sentence-audio}';
  static const url = '{url}';
  static const book = '{book}';
  static const chapter = '{chapter}';
  static const media = '{media}';
  static const source = '{source}';
  static const documentTitle = '{document-title}';
  static const selectionText = '{selection-text}';

  static const standardTemplates = <String, String>{
    'Expression': expression,
    'Reading': reading,
    'Furigana': furigana,
    'Furigana plain': furiganaPlain,
    'Glossary': glossary,
    'Selected glossary': selectedGlossary,
    'Single glossary': singleGlossary,
    'Sentence': sentence,
    'Sentence bold': sentenceBold,
    'Sentence furigana': sentenceFurigana,
    'Cloze prefix': clozePrefix,
    'Cloze body': clozeBody,
    'Cloze suffix': clozeSuffix,
    'Dictionary': dictionary,
    'Part of speech': partOfSpeech,
    'Frequencies': frequencies,
    'Frequency rank': frequencyHarmonicRank,
    'Pitch accents': pitchAccents,
    'Pitch positions': pitchAccentPositions,
    'Pitch categories': pitchAccentCategories,
    'Screenshot': screenshot,
    'Word audio': wordAudio,
    'Sentence audio': sentenceAudio,
    'Tags': tags,
    'Book': book,
    'Chapter': chapter,
    'Media': media,
    'URL': url,
    'Document title': documentTitle,
    'Selection text': selectionText,
  };

  static Map<String, String> singleGlossaryTemplatesForDictionaries(
    Iterable<String> dictionaries,
  ) {
    final templates = <String, String>{};
    final usedMarkers = <String>{};
    for (final dictionary in dictionaries) {
      final marker = singleGlossaryMarkerForDictionary(dictionary);
      if (marker == null || !usedMarkers.add(marker)) continue;
      templates['Single glossary: $dictionary'] = marker;
    }
    return templates;
  }

  static String? singleGlossaryMarkerForDictionary(
    String dictionary, {
    String suffix = '',
  }) {
    final name = kebabCase(dictionary);
    if (name.isEmpty) return null;
    return '{single-glossary-$name$suffix}';
  }

  static String kebabCase(String value) {
    return value
        .replaceAll(RegExp(r'[\s_\u3000]'), '-')
        .replaceAll(RegExp(r'[^\p{L}\p{N}-]', unicode: true), '')
        .replaceAll(RegExp(r'--+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .toLowerCase();
  }

  static String? autoDetectTemplate(String fieldName, int fieldIndex) {
    final lapis = _lapisFieldMap[fieldName.toLowerCase()];
    if (lapis != null) return lapis;
    if (fieldIndex == 0) return expression;
    final normalized = _normalizeFieldName(fieldName);
    for (final entry in _autoDetectAliases.entries) {
      for (final alias in entry.value) {
        if (normalized == _normalizeFieldName(alias)) return entry.key;
      }
    }
    return null;
  }

  static String _normalizeFieldName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

  static const _autoDetectAliases = <String, List<String>>{
    expression: ['expression', 'phrase', 'term', 'word', 'front'],
    reading: ['reading', 'expression-reading', 'term-reading', 'word-reading'],
    furigana: ['furigana', 'expression-furigana', 'term-furigana'],
    glossary: ['glossary', 'definition', 'meaning', 'back'],
    selectedGlossary: [
      'main-definition',
      'maindefinition',
      'selected-glossary',
    ],
    sentence: ['sentence', 'example-sentence'],
    sentenceFurigana: ['sentence-furigana', 'sentencefurigana'],
    clozeBody: ['cloze-body', 'cloze'],
    clozePrefix: ['cloze-prefix'],
    clozeSuffix: ['cloze-suffix'],
    frequencies: ['frequencies', 'frequency-list'],
    frequencyHarmonicRank: [
      'frequency',
      'freq',
      'freq-sort',
      'freqsort',
      'frequency-rank',
    ],
    pitchAccents: ['pitch', 'pitch-accent', 'pitch-accents', 'accent'],
    pitchAccentPositions: ['pitch-position', 'pitch-positions', 'positions'],
    pitchAccentCategories: ['pitch-categories', 'categories'],
    screenshot: ['screenshot', 'picture'],
    wordAudio: ['audio', 'sound', 'word-audio', 'term-audio'],
    audio: ['expression-audio', 'expressionaudio'],
    sentenceAudio: ['sentence-audio', 'sentenceaudio', 'sentence-sound'],
    tags: ['tags', 'tag'],
    partOfSpeech: ['part-of-speech', 'pos', 'part'],
    conjugation: ['conjugation', 'inflection'],
    dictionary: ['dictionary', 'dict'],
    book: ['book', 'manga', 'series', 'title'],
    chapter: ['chapter', 'episode'],
    media: ['media', 'source', 'context'],
    documentTitle: ['miscinfo', 'document-title', 'documenttitle'],
    selectionText: ['selection', 'selection-text', 'popup-selection-text'],
  };

  static const _lapisFieldMap = <String, String>{
    'expression': expression,
    'expressionfurigana': furiganaPlain,
    'expressionreading': reading,
    'expressionaudio': audio,
    'selectiontext': selectionText,
    'maindefinition': selectedGlossary,
    'definitionpicture': '',
    'sentence': sentence,
    'sentencefurigana': '',
    'sentenceaudio': sentenceAudio,
    'picture': screenshot,
    'glossary': glossary,
    'hint': '',
    'iswordandsentencecard': 'x',
    'isclickcard': '',
    'issentencecard': '',
    'isaudiocard': '',
    'pitchposition': pitchAccentPositions,
    'pitchcategories': pitchAccentCategories,
    'frequency': frequencies,
    'freqsort': frequencyHarmonicRank,
    'miscinfo': documentTitle,
  };

  static Map<String, String> defaultsForFields(List<String> fields) => {
    for (final indexed in fields.indexed)
      indexed.$2: autoDetectTemplate(indexed.$2, indexed.$1) ?? '',
  };
}

class AnkiMiningProfile {
  final bool ankiEnabled;
  final String deckName;
  final String modelName;
  final List<String> tags;
  final bool duplicateCheck;
  final String duplicateScope;
  final bool syncOnCreate;
  final Map<String, String> fieldMap;

  const AnkiMiningProfile({
    this.ankiEnabled = true,
    this.deckName = 'Mining',
    this.modelName = 'Basic',
    this.tags = const ['mangayomi'],
    this.duplicateCheck = true,
    this.duplicateScope = 'deck',
    this.syncOnCreate = false,
    this.fieldMap = defaultFieldMap,
  });

  factory AnkiMiningProfile.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const AnkiMiningProfile();
    final rawFieldMap = json['fieldMap'];
    return AnkiMiningProfile(
      ankiEnabled: json['ankiEnabled'] as bool? ?? true,
      deckName: json['deckName'] as String? ?? 'Mining',
      modelName: json['modelName'] as String? ?? 'Basic',
      tags:
          (json['tags'] as List?)?.map((tag) => tag.toString()).toList() ??
          const ['mangayomi'],
      duplicateCheck: json['duplicateCheck'] as bool? ?? true,
      duplicateScope: json['duplicateScope'] as String? ?? 'deck',
      syncOnCreate: json['syncOnCreate'] as bool? ?? false,
      fieldMap: rawFieldMap is Map
          ? rawFieldMap.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : defaultFieldMap,
    );
  }

  AnkiMiningProfile copyWith({
    bool? ankiEnabled,
    String? deckName,
    String? modelName,
    List<String>? tags,
    bool? duplicateCheck,
    String? duplicateScope,
    bool? syncOnCreate,
    Map<String, String>? fieldMap,
  }) {
    return AnkiMiningProfile(
      ankiEnabled: ankiEnabled ?? this.ankiEnabled,
      deckName: deckName ?? this.deckName,
      modelName: modelName ?? this.modelName,
      tags: tags ?? this.tags,
      duplicateCheck: duplicateCheck ?? this.duplicateCheck,
      duplicateScope: duplicateScope ?? this.duplicateScope,
      syncOnCreate: syncOnCreate ?? this.syncOnCreate,
      fieldMap: fieldMap ?? this.fieldMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ankiEnabled': ankiEnabled,
      'deckName': deckName,
      'modelName': modelName,
      'tags': tags,
      'duplicateCheck': duplicateCheck,
      'duplicateScope': duplicateScope,
      'syncOnCreate': syncOnCreate,
      'fieldMap': fieldMap,
    };
  }

  static const defaultFieldMap = <String, String>{
    'Front': AnkiMarker.expression,
    'Back':
        '${AnkiMarker.reading}<br>${AnkiMarker.glossary}<br>${AnkiMarker.sentence}<br>${AnkiMarker.source}<br>${AnkiMarker.screenshot}',
  };
}
