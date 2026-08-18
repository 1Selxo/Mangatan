/// Chimahon-compatible immersion statistics records.
///
/// Field names, units, and identity tuples are deliberately identical to
/// Chimahon's `com.canopus.chimareader.data` models so the same rows survive a
/// backup round trip in either direction:
///
/// * [MangaStatsEntry] keys on `(dateKey, mangaId)` and stores reading time in
///   **milliseconds**.
/// * [NovelStatsEntry] keys on `dateKey` within a single book and stores
///   reading time in **seconds** as a double.
/// * [AnkiStatsEntry] keys on `(dateKey, profileId, titleId)`.
library;

/// One day of manga reading for one title.
///
/// `mangaId == 0` is Chimahon's bucket for reading that has no library entry,
/// so it is a valid key rather than a missing value.
class MangaStatsEntry {
  const MangaStatsEntry({
    required this.dateKey,
    this.charactersRead = 0,
    this.readingTimeMs = 0,
    this.mangaId = 0,
  });

  factory MangaStatsEntry.fromJson(Map<dynamic, dynamic> json) =>
      MangaStatsEntry(
        dateKey: json['dateKey']?.toString() ?? '',
        charactersRead: _int(json['charactersRead']),
        readingTimeMs: _int(json['readingTime']),
        mangaId: _int(json['mangaId']),
      );

  final String dateKey;
  final int charactersRead;

  /// Chimahon stores manga reading time in milliseconds.
  final int readingTimeMs;
  final int mangaId;

  MangaStatsEntry copyWith({
    String? dateKey,
    int? charactersRead,
    int? readingTimeMs,
    int? mangaId,
  }) => MangaStatsEntry(
    dateKey: dateKey ?? this.dateKey,
    charactersRead: charactersRead ?? this.charactersRead,
    readingTimeMs: readingTimeMs ?? this.readingTimeMs,
    mangaId: mangaId ?? this.mangaId,
  );

  /// Chimahon's wire field name is `readingTime`; the unit lives in the docs.
  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'charactersRead': charactersRead,
    'readingTime': readingTimeMs,
    'mangaId': mangaId,
  };

  @override
  bool operator ==(Object other) =>
      other is MangaStatsEntry &&
      other.dateKey == dateKey &&
      other.charactersRead == charactersRead &&
      other.readingTimeMs == readingTimeMs &&
      other.mangaId == mangaId;

  @override
  int get hashCode =>
      Object.hash(dateKey, charactersRead, readingTimeMs, mangaId);
}

/// One day of Anki mining, scoped to a dictionary profile and optional title.
class AnkiStatsEntry {
  const AnkiStatsEntry({
    required this.dateKey,
    this.mangaCards = 0,
    this.novelCards = 0,
    this.profileId = '',
    this.titleId,
  });

  factory AnkiStatsEntry.fromJson(Map<dynamic, dynamic> json) => AnkiStatsEntry(
    dateKey: json['dateKey']?.toString() ?? '',
    mangaCards: _int(json['mangaCards']),
    novelCards: _int(json['novelCards']),
    profileId: json['profileId']?.toString() ?? '',
    titleId: json['titleId']?.toString(),
  );

  final String dateKey;
  final int mangaCards;
  final int novelCards;
  final String profileId;

  /// Manga rows carry the library ID as a string; novel rows carry Chimahon's
  /// stable book ID. `null` means the card was mined outside any title.
  final String? titleId;

  int get totalCards => mangaCards + novelCards;

  AnkiStatsEntry copyWith({
    String? dateKey,
    int? mangaCards,
    int? novelCards,
    String? profileId,
    String? titleId,
  }) => AnkiStatsEntry(
    dateKey: dateKey ?? this.dateKey,
    mangaCards: mangaCards ?? this.mangaCards,
    novelCards: novelCards ?? this.novelCards,
    profileId: profileId ?? this.profileId,
    titleId: titleId ?? this.titleId,
  );

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'mangaCards': mangaCards,
    'novelCards': novelCards,
    'profileId': profileId,
    if (titleId != null) 'titleId': titleId,
  };

  @override
  bool operator ==(Object other) =>
      other is AnkiStatsEntry &&
      other.dateKey == dateKey &&
      other.mangaCards == mangaCards &&
      other.novelCards == novelCards &&
      other.profileId == profileId &&
      other.titleId == titleId;

  @override
  int get hashCode =>
      Object.hash(dateKey, mangaCards, novelCards, profileId, titleId);
}

/// One day of novel reading for one book.
///
/// This mirrors Chimahon's `Statistics`, including the derived speed fields it
/// persists rather than recomputes. `completedBook`/`completedData` are not
/// modelled: Chimahon never writes them from the reader and its backup schema
/// omits them, so round-tripping them is not possible in either direction.
class NovelStatsEntry {
  const NovelStatsEntry({
    required this.dateKey,
    this.charactersRead = 0,
    this.readingTimeSeconds = 0,
    this.minReadingSpeed = 0,
    this.altMinReadingSpeed = 0,
    this.lastReadingSpeed = 0,
    this.maxReadingSpeed = 0,
    this.lastStatisticModified = 0,
  });

  factory NovelStatsEntry.fromJson(Map<dynamic, dynamic> json) =>
      NovelStatsEntry(
        dateKey: json['dateKey']?.toString() ?? '',
        charactersRead: _int(json['charactersRead']),
        readingTimeSeconds: _double(json['readingTime']),
        minReadingSpeed: _int(json['minReadingSpeed']),
        altMinReadingSpeed: _int(json['altMinReadingSpeed']),
        lastReadingSpeed: _int(json['lastReadingSpeed']),
        maxReadingSpeed: _int(json['maxReadingSpeed']),
        lastStatisticModified: _int(json['lastStatisticModified']),
      );

  final String dateKey;
  final int charactersRead;

  /// Chimahon stores novel reading time in fractional seconds.
  final double readingTimeSeconds;
  final int minReadingSpeed;
  final int altMinReadingSpeed;
  final int lastReadingSpeed;
  final int maxReadingSpeed;
  final int lastStatisticModified;

  int get readingTimeMs => (readingTimeSeconds * 1000).round();

  NovelStatsEntry copyWith({
    String? dateKey,
    int? charactersRead,
    double? readingTimeSeconds,
    int? minReadingSpeed,
    int? altMinReadingSpeed,
    int? lastReadingSpeed,
    int? maxReadingSpeed,
    int? lastStatisticModified,
  }) => NovelStatsEntry(
    dateKey: dateKey ?? this.dateKey,
    charactersRead: charactersRead ?? this.charactersRead,
    readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
    minReadingSpeed: minReadingSpeed ?? this.minReadingSpeed,
    altMinReadingSpeed: altMinReadingSpeed ?? this.altMinReadingSpeed,
    lastReadingSpeed: lastReadingSpeed ?? this.lastReadingSpeed,
    maxReadingSpeed: maxReadingSpeed ?? this.maxReadingSpeed,
    lastStatisticModified: lastStatisticModified ?? this.lastStatisticModified,
  );

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'charactersRead': charactersRead,
    'readingTime': readingTimeSeconds,
    'minReadingSpeed': minReadingSpeed,
    'altMinReadingSpeed': altMinReadingSpeed,
    'lastReadingSpeed': lastReadingSpeed,
    'maxReadingSpeed': maxReadingSpeed,
    'lastStatisticModified': lastStatisticModified,
  };

  /// Applies Chimahon's per-tick update, including its clamping rules.
  ///
  /// A negative [characterDiff] (the reader moved backwards) reduces the
  /// running count but never below zero, and `altMinReadingSpeed` only moves
  /// when characters actually changed so idle ticks cannot drag it to zero.
  NovelStatsEntry updated({
    required double timeDiffSeconds,
    required int characterDiff,
    required int modifiedAtMs,
  }) {
    final nextTime = readingTimeSeconds + timeDiffSeconds;
    final nextCharacters = (charactersRead + characterDiff).clamp(
      0,
      1 << 62,
    );
    final nextSpeed = nextTime > 0
        ? (nextCharacters / nextTime * 3600).toInt()
        : 0;
    return copyWith(
      readingTimeSeconds: nextTime,
      charactersRead: nextCharacters,
      lastReadingSpeed: nextSpeed,
      maxReadingSpeed: maxReadingSpeed > nextSpeed
          ? maxReadingSpeed
          : nextSpeed,
      minReadingSpeed: minReadingSpeed != 0
          ? (minReadingSpeed < nextSpeed ? minReadingSpeed : nextSpeed)
          : nextSpeed,
      altMinReadingSpeed: characterDiff != 0
          ? (altMinReadingSpeed != 0
                ? (altMinReadingSpeed < nextSpeed
                      ? altMinReadingSpeed
                      : nextSpeed)
                : nextSpeed)
          : altMinReadingSpeed,
      lastStatisticModified: modifiedAtMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NovelStatsEntry &&
      other.dateKey == dateKey &&
      other.charactersRead == charactersRead &&
      other.readingTimeSeconds == readingTimeSeconds &&
      other.minReadingSpeed == minReadingSpeed &&
      other.altMinReadingSpeed == altMinReadingSpeed &&
      other.lastReadingSpeed == lastReadingSpeed &&
      other.maxReadingSpeed == maxReadingSpeed &&
      other.lastStatisticModified == lastStatisticModified;

  @override
  int get hashCode => Object.hash(
    dateKey,
    charactersRead,
    readingTimeSeconds,
    minReadingSpeed,
    altMinReadingSpeed,
    lastReadingSpeed,
    maxReadingSpeed,
    lastStatisticModified,
  );
}

/// Formats a date the way Chimahon's `LocalDate.toString()` does.
String statsDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Parses a Chimahon `dateKey`, returning `null` for anything malformed.
DateTime? parseStatsDateKey(String dateKey) {
  final parsed = DateTime.tryParse(dateKey);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _double(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
