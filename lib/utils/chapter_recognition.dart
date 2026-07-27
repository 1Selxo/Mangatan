/// Mihon uses negative values for "number unknown". Mangatan keeps `-2` as a
/// meaningful source value for compatibility, but all other negative and
/// non-finite values must fall back to name recognition.
double? normalizeSourceChapterNumber(double? number) {
  if (number == null || !number.isFinite) return null;
  return number == -2 || number >= 0 ? number : null;
}

/// Matches the legacy Mihon backup projection: use the final numeric token in
/// a chapter or episode name when the source did not provide a known number.
double fallbackChapterNumberFromName(String? name) {
  final matches = RegExp(r'\d+(?:\.\d+)?').allMatches(name ?? '').toList();
  return matches.isEmpty
      ? 0
      : double.tryParse(matches.last.group(0) ?? '') ?? 0;
}

String formatChapterNumberForDisplay(double number) {
  if (number == number.truncateToDouble()) return number.toInt().toString();
  return number
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String chapterNumberDisplayTitle({
  required String sourceTitle,
  required String mangaTitle,
  required String numberLabel,
  double? sourceChapterNumber,
}) {
  final number = ChapterRecognition().resolveChapterNumberOrNull(
    mangaTitle,
    sourceTitle,
    sourceChapterNumber: sourceChapterNumber,
  );
  return number == null || number < 0
      ? sourceTitle
      : '$numberLabel ${formatChapterNumberForDisplay(number)}';
}

class ChapterRecognition {
  static final _unwanted = RegExp(
    r"\b(?:v|ver|vol|version|volume|season|staffel|saison|temporada|s)[^a-z]?[0-9]+",
  );
  static final _unwantedWhiteSpace = RegExp(r"\s(?=extra|special|omake)");
  static final _seasonKeyword = RegExp(
    r"\b(?:staffel|season|saison|temporada|s)\s*([0-9]+)",
  );
  static final _episodeKeyword = RegExp(
    r"\b(?:folge|episode|ep\.?)\s*([0-9]+(?:\.[0-9]+)?)",
  );
  static final _japaneseVolume = RegExp(
    r"第\s*([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?\s*巻",
  );
  static final _japaneseChapterNumber = RegExp(
    r"第\s*([〇零一二三四五六七八九十百千万億兆壱弐参拾]+)\s*(?:話|章|回|節|篇|巻)",
  );
  static final _westernVolume = RegExp(
    r"\b(?:v|vol(?:ume)?)\.?\s*([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?",
  );
  // lookbehind for "ch." then zero or more spaces.
  static final _chNotation = RegExp(
    r"(?<=ch\.) *([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?",
  );
  static final _bareNumber = RegExp(r"([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?");

  /// Sort key for the UI list. Encodes season into the key so multi-season
  /// anime sort correctly: key = season * 100000 + episode.
  int parseChapterNumber(String mangaTitle, String chapterName) =>
      _parse(mangaTitle, chapterName, applySeason: true) ?? 0;

  /// Episode number within a season, for tracker updates (MAL/AniList/Kitsu)
  /// and AniSkip results. The tracker entry is already season-specific,
  /// so season is stripped.
  int parseEpisodeNumber(String mangaTitle, String chapterName) =>
      _parse(mangaTitle, chapterName, applySeason: false) ?? 0;

  /// Prefers a number supplied by the source, as Mihon and Chimahon do, and
  /// falls back to filename recognition for sources without that metadata.
  double resolveChapterNumber(
    String mangaTitle,
    String chapterName, {
    double? sourceChapterNumber,
  }) =>
      resolveChapterNumberOrNull(
        mangaTitle,
        chapterName,
        sourceChapterNumber: sourceChapterNumber,
      ) ??
      0;

  /// Returns null when neither the source nor the chapter title provides a
  /// recognizable number. This lets display code fall back to the source title
  /// instead of presenting the unknown-number sentinel as "Chapter 0".
  double? resolveChapterNumberOrNull(
    String mangaTitle,
    String chapterName, {
    double? sourceChapterNumber,
  }) {
    final sourceNumber = _knownSourceNumber(sourceChapterNumber);
    if (sourceNumber != null) return sourceNumber;
    return _parse(mangaTitle, chapterName, applySeason: true)?.toDouble();
  }

  /// Episode equivalent of [resolveChapterNumber]. The filename fallback does
  /// not fold season numbers into the result, matching tracker expectations.
  double resolveEpisodeNumber(
    String mangaTitle,
    String episodeName, {
    double? sourceEpisodeNumber,
  }) {
    final sourceNumber = _knownSourceNumber(sourceEpisodeNumber);
    if (sourceNumber != null) return sourceNumber;
    return (_parse(mangaTitle, episodeName, applySeason: false) ?? 0)
        .toDouble();
  }

  double? _knownSourceNumber(double? number) {
    return normalizeSourceChapterNumber(number);
  }

  int? _parse(
    String mangaTitle,
    String chapterName, {
    required bool applySeason,
  }) {
    // Normalize the chapter name by removing title, punctuation noise, etc.
    final name = chapterName
        .toLowerCase()
        .replaceAll(mangaTitle.toLowerCase(), '')
        .trim()
        .replaceAll(',', '.')
        .replaceAll('-', '.')
        .replaceAll(_unwantedWhiteSpace, '');

    final season = applySeason
        ? int.tryParse(_seasonKeyword.firstMatch(name)?.group(1) ?? '') ?? 0
        : 0;

    final epMatch = _episodeKeyword.firstMatch(name);
    if (epMatch != null) {
      final ep = double.parse(epMatch.group(1)!).toInt();
      return _withSeason(season, ep);
    }

    final chapterMatch = _chNotation.firstMatch(name);
    if (chapterMatch != null) {
      return _withSeason(season, _fromMatch(chapterMatch).toInt());
    }

    final japaneseChapterMatch = _japaneseChapterNumber.firstMatch(name);
    if (japaneseChapterMatch != null) {
      final chapter = _parseJapaneseNumber(japaneseChapterMatch.group(1)!);
      if (chapter != null) return _withSeason(season, chapter);
    }

    // Mokuro volume filenames often contain an unrelated number in the title,
    // e.g. "14歳の恋 第12巻". Prefer the explicit Japanese volume marker.
    final japaneseVolumeMatch = _japaneseVolume.firstMatch(name);
    if (japaneseVolumeMatch != null) {
      return _withSeason(season, _fromMatch(japaneseVolumeMatch).toInt());
    }

    // strip season/volume noise, then look for ch. or bare number.
    final stripped = name.replaceAll(_unwanted, '');
    final ep = _extractNumber(stripped);
    if (ep != null) return _withSeason(season, ep);

    // If stripping removed the only useful token (such as Mokuro's "v22"),
    // use that explicit volume number as the final fallback.
    final westernVolumeMatch = _westernVolume.firstMatch(name);
    return westernVolumeMatch != null
        ? _withSeason(season, _fromMatch(westernVolumeMatch).toInt())
        : null;
  }

  // Combines season + episode into a sortable integer.
  int _withSeason(int season, int ep) => season > 0 ? season * 100000 + ep : ep;

  int? _extractNumber(String name) {
    final chMatch = _chNotation.firstMatch(name);
    if (chMatch != null) return _fromMatch(chMatch).toInt();

    final numMatch = _bareNumber.firstMatch(name);
    if (numMatch != null) return _fromMatch(numMatch).toInt();

    return null;
  }

  int? _parseJapaneseNumber(String value) {
    const digits = {
      '〇': 0,
      '零': 0,
      '一': 1,
      '壱': 1,
      '二': 2,
      '弐': 2,
      '三': 3,
      '参': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    const smallUnits = {'十': 10, '拾': 10, '百': 100, '千': 1000};
    const largeUnits = {'万': 10000, '億': 100000000, '兆': 1000000000000};

    final hasUnit = value
        .split('')
        .any(
          (character) =>
              smallUnits.containsKey(character) ||
              largeUnits.containsKey(character),
        );
    if (!hasUnit) {
      final converted = value
          .split('')
          .map((character) => digits[character]?.toString())
          .join();
      return converted.length == value.length ? int.tryParse(converted) : null;
    }

    var total = 0;
    var section = 0;
    var pendingDigit = 0;
    for (final character in value.split('')) {
      final digit = digits[character];
      if (digit != null) {
        pendingDigit = digit;
        continue;
      }

      final smallUnit = smallUnits[character];
      if (smallUnit != null) {
        section += (pendingDigit == 0 ? 1 : pendingDigit) * smallUnit;
        pendingDigit = 0;
        continue;
      }

      final largeUnit = largeUnits[character];
      if (largeUnit != null) {
        section += pendingDigit;
        total += (section == 0 ? 1 : section) * largeUnit;
        section = 0;
        pendingDigit = 0;
        continue;
      }

      return null;
    }
    return total + section + pendingDigit;
  }

  double _fromMatch(Match match) {
    final base = double.parse(match.group(1)!);
    return base + _decimalAddition(match.group(2), match.group(3));
  }

  double _decimalAddition(String? decimal, String? alpha) {
    if (decimal != null && decimal.isNotEmpty) return double.parse(decimal);
    if (alpha != null && alpha.isNotEmpty) {
      if (alpha.contains("extra")) {
        return 0.99;
      }
      if (alpha.contains("omake")) {
        return 0.98;
      }
      if (alpha.contains("special")) {
        return 0.97;
      }
      final trimmedAlpha = alpha.replaceFirst('.', '');
      if (trimmedAlpha.length == 1) {
        return _parseAlphaPostFix(trimmedAlpha[0]);
      }
    }

    return 0.0;
  }

  double _parseAlphaPostFix(String alpha) {
    final number = alpha.codeUnitAt(0) - ('a'.codeUnitAt(0) - 1);
    if (number >= 10) return 0.0;
    return number / 10.0;
  }
}
