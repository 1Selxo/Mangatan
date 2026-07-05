class AnkiMarker {
  static const expression = '{expression}';
  static const reading = '{reading}';
  static const furigana = '{furigana}';
  static const glossary = '{glossary}';
  static const selectedGlossary = '{selected-glossary}';
  static const sentence = '{sentence}';
  static const sentenceFurigana = '{sentence-furigana}';
  static const clozePrefix = '{cloze-prefix}';
  static const clozeBody = '{cloze-body}';
  static const clozeSuffix = '{cloze-suffix}';
  static const tags = '{tags}';
  static const partOfSpeech = '{part-of-speech}';
  static const dictionary = '{dictionary}';
  static const frequencies = '{frequencies}';
  static const frequencyHarmonic = '{frequency-harmonic}';
  static const frequencyAverage = '{frequency-average}';
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
      tags: (json['tags'] as List?)?.cast<String>() ?? const ['mangayomi'],
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
