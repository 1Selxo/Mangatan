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
      _parse(mangaTitle, chapterName, applySeason: true);

  /// Episode number within a season, for tracker updates (MAL/AniList/Kitsu)
  /// and AniSkip results. The tracker entry is already season-specific,
  /// so season is stripped.
  int parseEpisodeNumber(String mangaTitle, String chapterName) =>
      _parse(mangaTitle, chapterName, applySeason: false);

  /// Prefers a number supplied by the source, as Mihon and Chimahon do, and
  /// falls back to filename recognition for sources without that metadata.
  double resolveChapterNumber(
    String mangaTitle,
    String chapterName, {
    double? sourceChapterNumber,
  }) {
    final sourceNumber = _knownSourceNumber(sourceChapterNumber);
    if (sourceNumber != null) return sourceNumber;
    return parseChapterNumber(mangaTitle, chapterName).toDouble();
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
    return parseEpisodeNumber(mangaTitle, episodeName).toDouble();
  }

  double? _knownSourceNumber(double? number) {
    return number == -2 || (number ?? -1) >= 0 ? number : null;
  }

  int _parse(
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
        : 0;
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
