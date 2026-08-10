import 'package:mangayomi/services/mining/mining_models.dart';

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
  static const popupSelectionText = '{popup-selection-text}';
  static const mediaName = '{media-name}';

  static const lapisModelName = 'Lapis';

  /// Matches Chimahon's bundled Lapis preset. Chimahon treats a blank map as
  /// this preset both while loading profiles and immediately before export.
  static const lapisDefaultFieldMap = <String, String>{
    'Expression': expression,
    'ExpressionFurigana': furiganaPlain,
    'ExpressionReading': reading,
    'ExpressionAudio': audio,
    'SelectionText': popupSelectionText,
    'MainDefinition': selectedGlossary,
    'Sentence': sentence,
    'SentenceFurigana': sentenceFurigana,
    'SentenceAudio': sentenceAudio,
    'Picture': screenshot,
    'Glossary': glossary,
    'IsWordAndSentenceCard': 'x',
    'PitchPosition': pitchAccentPositions,
    'PitchCategories': pitchAccentCategories,
    'Frequency': frequencies,
    'FreqSort': frequencyHarmonicRank,
    'MiscInfo': mediaName,
  };

  static bool isBundledLapisModelName(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized == 'lapis' ||
        normalized == 'lapis (chimahon)' ||
        normalized.startsWith('lapis (chimahon ');
  }

  static Map<String, String> effectiveFieldMap(
    String modelName,
    Map<String, String> fieldMap,
  ) => fieldMap.isEmpty && isBundledLapisModelName(modelName)
      ? lapisDefaultFieldMap
      : fieldMap;

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

  static String? autoDetectTemplate(
    String fieldName,
    int fieldIndex, {
    bool isLapis = false,
  }) {
    if (isLapis) {
      for (final entry in lapisDefaultFieldMap.entries) {
        if (entry.key.toLowerCase() == fieldName.toLowerCase()) {
          return entry.value;
        }
      }
    }
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

  static Map<String, String> defaultsForFields(
    List<String> fields, {
    bool isLapis = false,
  }) => {
    for (final indexed in fields.indexed)
      indexed.$2:
          autoDetectTemplate(indexed.$2, indexed.$1, isLapis: isLapis) ?? '',
  };
}

class AnkiMiningProfile {
  final bool ankiEnabled;
  final String deckName;
  final String modelName;
  final List<String> tags;
  final bool duplicateCheck;
  final String duplicateScope;
  final List<String> duplicateDeckNames;
  final bool checkAllModels;
  final bool syncOnCreate;
  final AnkiSentenceAudioFormat sentenceAudioFormat;
  final Map<String, String> fieldMap;

  const AnkiMiningProfile({
    this.ankiEnabled = true,
    this.deckName = 'Mining',
    this.modelName = 'Basic',
    this.tags = const ['mangatan'],
    this.duplicateCheck = true,
    this.duplicateScope = 'deck',
    this.duplicateDeckNames = const [],
    this.checkAllModels = false,
    this.syncOnCreate = false,
    this.sentenceAudioFormat = AnkiSentenceAudioFormat.mp3,
    this.fieldMap = defaultFieldMap,
  });

  factory AnkiMiningProfile.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const AnkiMiningProfile();
    final rawFieldMap = json['fieldMap'];
    final modelName = json['modelName'] as String? ?? 'Basic';
    final parsedFieldMap = rawFieldMap is Map
        ? rawFieldMap.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : null;
    return AnkiMiningProfile(
      ankiEnabled: json['ankiEnabled'] as bool? ?? true,
      deckName: json['deckName'] as String? ?? 'Mining',
      modelName: modelName,
      tags:
          (json['tags'] as List?)?.map((tag) => tag.toString()).toList() ??
          const ['mangatan'],
      duplicateCheck: json['duplicateCheck'] as bool? ?? true,
      duplicateScope: json['duplicateScope'] as String? ?? 'deck',
      duplicateDeckNames:
          (json['duplicateDeckNames'] as List?)
              ?.map((deck) => deck.toString())
              .where((deck) => deck.trim().isNotEmpty)
              .toList() ??
          const [],
      checkAllModels: json['checkAllModels'] as bool? ?? false,
      syncOnCreate: json['syncOnCreate'] as bool? ?? false,
      sentenceAudioFormat: AnkiSentenceAudioFormat.values.firstWhere(
        (format) => format.name == json['sentenceAudioFormat'],
        orElse: () => AnkiSentenceAudioFormat.mp3,
      ),
      fieldMap: AnkiMarker.effectiveFieldMap(
        modelName,
        parsedFieldMap ??
            (AnkiMarker.isBundledLapisModelName(modelName)
                ? const {}
                : defaultFieldMap),
      ),
    );
  }

  Map<String, String> get effectiveFieldMap =>
      AnkiMarker.effectiveFieldMap(modelName, fieldMap);

  AnkiMiningProfile copyWith({
    bool? ankiEnabled,
    String? deckName,
    String? modelName,
    List<String>? tags,
    bool? duplicateCheck,
    String? duplicateScope,
    List<String>? duplicateDeckNames,
    bool? checkAllModels,
    bool? syncOnCreate,
    AnkiSentenceAudioFormat? sentenceAudioFormat,
    Map<String, String>? fieldMap,
  }) {
    return AnkiMiningProfile(
      ankiEnabled: ankiEnabled ?? this.ankiEnabled,
      deckName: deckName ?? this.deckName,
      modelName: modelName ?? this.modelName,
      tags: tags ?? this.tags,
      duplicateCheck: duplicateCheck ?? this.duplicateCheck,
      duplicateScope: duplicateScope ?? this.duplicateScope,
      duplicateDeckNames: duplicateDeckNames ?? this.duplicateDeckNames,
      checkAllModels: checkAllModels ?? this.checkAllModels,
      syncOnCreate: syncOnCreate ?? this.syncOnCreate,
      sentenceAudioFormat: sentenceAudioFormat ?? this.sentenceAudioFormat,
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
      'duplicateDeckNames': duplicateDeckNames,
      'checkAllModels': checkAllModels,
      'syncOnCreate': syncOnCreate,
      'sentenceAudioFormat': sentenceAudioFormat.name,
      'fieldMap': fieldMap,
    };
  }

  static const defaultFieldMap = <String, String>{
    'Front': AnkiMarker.expression,
    'Back':
        '${AnkiMarker.reading}<br>${AnkiMarker.glossary}<br>${AnkiMarker.sentence}<br>${AnkiMarker.source}<br>${AnkiMarker.screenshot}',
  };
}
