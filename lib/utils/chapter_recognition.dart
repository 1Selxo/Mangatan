import 'package:mangayomi/utils/log/logger.dart';

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

  // Dedup so a repeatedly-rebuilt chapter list doesn't spam the log file
  // with the same unrecognized name on every rebuild.
  static final Set<String> _loggedUnrecognized = {};

  /// Sort key for a single chapter with no list context. Always buckets by
  /// season when present: key = season * 100000 + episode.
  int parseChapterNumber(String mangaTitle, String chapterName) {
    final (season, ep) = rawSeasonAndNumber(mangaTitle, chapterName);
    return _withSeason(season, ep ?? 0).toInt();
  }

  /// Episode number within a season, for tracker updates (MAL/AniList/Kitsu)
  /// and AniSkip results. The tracker entry is already season-specific,
  /// so season is never applied.
  int parseEpisodeNumber(String mangaTitle, String chapterName) {
    final (_, ep) = rawSeasonAndNumber(mangaTitle, chapterName);
    return (ep ?? 0).toInt();
  }

  /// Returns a season-aware identity key for chapter deduplication.
  ///
  /// Names with no positive episode number remain unkeyed so unrelated
  /// specials and prologues are never folded together. Callers that need to
  /// distinguish scanlator variants can include [scanlator].
  String? chapterIdentityKey(
    String mangaTitle,
    String chapterName, [
    String? scanlator,
  ]) {
    final (season, episode) = rawSeasonAndNumber(mangaTitle, chapterName);
    if (episode == null || episode <= 0) return null;
    return '$season::$episode::${scanlator ?? ''}';
  }

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

  double? resolveChapterNumberOrNull(
    String mangaTitle,
    String chapterName, {
    double? sourceChapterNumber,
  }) {
    final sourceNumber = normalizeSourceChapterNumber(sourceChapterNumber);
    if (sourceNumber != null) return sourceNumber;
    final (season, episode) = rawSeasonAndNumber(mangaTitle, chapterName);
    return episode == null ? null : _withSeason(season, episode);
  }

  double resolveEpisodeNumber(
    String mangaTitle,
    String episodeName, {
    double? sourceEpisodeNumber,
  }) {
    final sourceNumber = normalizeSourceChapterNumber(sourceEpisodeNumber);
    if (sourceNumber != null) return sourceNumber;
    final (_, episode) = rawSeasonAndNumber(mangaTitle, episodeName);
    return episode ?? 0;
  }

  /// Raw (season, episode) pair, unbucketed — season is 0 if none matched.
  /// Episode keeps its fractional part (e.g. 12.5) so callers needing exact
  /// chapter identity (dedup, stable sort of split chapters) don't collide
  /// at the same truncated integer. Episode is null when the name has no
  /// detectable number at all (e.g. "Special", "Prologue") — distinct from
  /// a genuine chapter 0, so callers can avoid treating every such chapter
  /// as a duplicate of every other one.
  (int, double?) rawSeasonAndNumber(String mangaTitle, String chapterName) {
    final name = chapterName
        .toLowerCase()
        .replaceAll(mangaTitle.toLowerCase(), '')
        .trim()
        .replaceAll(',', '.')
        .replaceAll('-', '.')
        .replaceAll(_unwantedWhiteSpace, '');

    final season =
        int.tryParse(_seasonKeyword.firstMatch(name)?.group(1) ?? '') ?? 0;

    final epMatch = _episodeKeyword.firstMatch(name);
    if (epMatch != null) {
      return (season, double.parse(epMatch.group(1)!));
    }

    final chapterMatch = _chNotation.firstMatch(name);
    if (chapterMatch != null) {
      return (season, _fromMatch(chapterMatch));
    }

    final japaneseChapterMatch = _japaneseChapterNumber.firstMatch(name);
    if (japaneseChapterMatch != null) {
      final chapter = _parseJapaneseNumber(japaneseChapterMatch.group(1)!);
      if (chapter != null) return (season, chapter.toDouble());
    }

    final japaneseVolumeMatch = _japaneseVolume.firstMatch(name);
    if (japaneseVolumeMatch != null) {
      return (season, _fromMatch(japaneseVolumeMatch));
    }

    final stripped = name.replaceAll(_unwanted, '');
    final westernVolumeMatch = _westernVolume.firstMatch(name);
    final ep =
        _extractNumber(stripped) ??
        (westernVolumeMatch == null ? null : _fromMatch(westernVolumeMatch));
    if (ep == null && _loggedUnrecognized.add('$mangaTitle|$chapterName')) {
      AppLogger.log(
        'ChapterRecognition: no number detected in "$chapterName" (manga: "$mangaTitle")',
        logLevel: LogLevel.warning,
      );
    }
    return (season, ep);
  }

  // Combines season + episode into a sortable number.
  double _withSeason(int season, double ep) =>
      season > 0 ? season * 100000 + ep : ep;

  double? _extractNumber(String name) {
    final chMatch = _chNotation.firstMatch(name);
    if (chMatch != null) return _fromMatch(chMatch);

    final numMatch = _bareNumber.firstMatch(name);
    if (numMatch != null) return _fromMatch(numMatch);

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
