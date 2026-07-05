import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class JimakuException implements Exception {
  final String message;
  const JimakuException(this.message);

  @override
  String toString() => message;
}

class JimakuEntry {
  final int id;
  final String name;
  final String? englishName;
  final String? japaneseName;

  const JimakuEntry({
    required this.id,
    required this.name,
    this.englishName,
    this.japaneseName,
  });

  factory JimakuEntry.fromJson(Map<String, dynamic> json) {
    return JimakuEntry(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      englishName: json['english_name']?.toString(),
      japaneseName: json['japanese_name']?.toString(),
    );
  }
}

class JimakuFile {
  final Uri url;
  final String name;
  final int size;
  final String lastModified;

  const JimakuFile({
    required this.url,
    required this.name,
    required this.size,
    required this.lastModified,
  });

  factory JimakuFile.fromJson(Map<String, dynamic> json) {
    return JimakuFile(
      url: _absoluteJimakuUri(json['url']?.toString() ?? ''),
      name: json['name']?.toString() ?? 'jimaku-subtitle.srt',
      size: (json['size'] as num?)?.toInt() ?? 0,
      lastModified: json['last_modified']?.toString() ?? '',
    );
  }
}

class JimakuMediaGuess {
  final String title;
  final int? episode;
  final int? season;
  final Set<int> episodeCandidates;

  const JimakuMediaGuess({
    required this.title,
    this.episode,
    this.season,
    this.episodeCandidates = const {},
  });

  String get displayName {
    final seasonText = season == null ? '' : ' season $season';
    final episodeText = episode == null ? '' : ' episode $episode';
    return '$title$seasonText$episodeText';
  }

  bool matchesEpisode(int value) {
    return value == episode || episodeCandidates.contains(value);
  }

  bool get hasEpisodeCandidates {
    return episode != null || episodeCandidates.isNotEmpty;
  }
}

class JimakuSubtitleService {
  static const _baseUrl = 'https://jimaku.cc/api';

  final http.Client _client;

  JimakuSubtitleService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<JimakuEntry>> searchEntries({
    required String apiKey,
    required String query,
  }) async {
    final anime = await _searchEntries(
      apiKey: apiKey,
      query: query,
      anime: true,
    );
    final nonAnime = await _searchEntries(
      apiKey: apiKey,
      query: query,
      anime: false,
    );
    final byId = <int, JimakuEntry>{};
    for (final entry in [...anime, ...nonAnime]) {
      byId[entry.id] = entry;
    }
    return byId.values.toList();
  }

  Future<List<JimakuFile>> getFiles({
    required String apiKey,
    required int entryId,
    int? episode,
  }) async {
    final query = <String, String>{};
    if (episode != null) query['episode'] = episode.toString();
    final uri = Uri.parse(
      '$_baseUrl/entries/$entryId/files',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri, headers: _headers(apiKey));
    _throwIfBad(response);
    return (jsonDecode(response.body) as List)
        .whereType<Map>()
        .map((item) => JimakuFile.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<File> downloadFile({
    required String apiKey,
    required JimakuFile file,
    required Directory outputDirectory,
  }) async {
    await outputDirectory.create(recursive: true);
    final outputFile = File(
      p.join(outputDirectory.path, _safeFileName(file.name)),
    );
    if (await outputFile.exists()) await outputFile.delete();
    final response = await _client.get(file.url, headers: _headers(apiKey));
    _throwIfBad(response);
    await outputFile.writeAsBytes(response.bodyBytes);
    return outputFile;
  }

  Future<List<JimakuFile>> matchingFiles({
    required String apiKey,
    required JimakuEntry entry,
    required JimakuMediaGuess guess,
  }) async {
    var files = await getFiles(
      apiKey: apiKey,
      entryId: entry.id,
      episode: guess.episode,
    );
    var matched = files.matchedSubtitleFiles(guess, episodeFiltered: true);
    if (matched.isNotEmpty || guess.episode == null) return matched;
    files = await getFiles(apiKey: apiKey, entryId: entry.id);
    return files.matchedSubtitleFiles(guess, episodeFiltered: false);
  }

  Future<List<JimakuEntry>> _searchEntries({
    required String apiKey,
    required String query,
    required bool anime,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/entries/search',
    ).replace(queryParameters: {'anime': anime.toString(), 'query': query});
    final response = await _client.get(uri, headers: _headers(apiKey));
    _throwIfBad(response);
    return (jsonDecode(response.body) as List)
        .whereType<Map>()
        .map((item) => JimakuEntry.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Map<String, String> _headers(String apiKey) {
    return {'Authorization': apiKey.trim()};
  }

  void _throwIfBad(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw JimakuException(
      'Jimaku HTTP ${response.statusCode}: ${response.body}',
    );
  }
}

JimakuMediaGuess? guessJimakuMedia(String value) {
  final withoutExtension = value.toJimakuFilename().replaceAll(
    _knownExtensionRegex,
    '',
  );
  final season = _seasonRegexes
      .map((regex) => regex.firstMatch(withoutExtension)?.group(1))
      .map((value) => int.tryParse(value ?? ''))
      .whereType<int>()
      .firstOrNull;
  final episodes = withoutExtension.jimakuEpisodeNumbers();
  final title = withoutExtension.preferredJimakuTitleSeed().cleanJimakuTitle();
  if (title.trim().isEmpty) return null;
  return JimakuMediaGuess(
    title: title,
    episode: episodes.$1,
    season: season,
    episodeCandidates: episodes.$2,
  );
}

JimakuEntry? selectBestJimakuEntry(List<JimakuEntry> entries, String title) {
  if (entries.isEmpty) return null;
  if (entries.length == 1) return entries.first;
  final target = title.normalizedJimakuText();
  for (final entry in entries) {
    final names = [
      entry.name,
      entry.englishName ?? '',
      entry.japaneseName ?? '',
    ];
    if (names.any((name) => name.normalizedJimakuText() == target)) {
      return entry;
    }
  }
  final ranked = [...entries]
    ..sort((a, b) {
      return _entryScore(b, title).compareTo(_entryScore(a, title));
    });
  return ranked.first;
}

extension JimakuFileMatcher on List<JimakuFile> {
  List<JimakuFile> matchedSubtitleFiles(
    JimakuMediaGuess guess, {
    required bool episodeFiltered,
  }) {
    final files =
        where((file) {
          final lower = file.name.toLowerCase();
          return lower.endsWith('.srt') ||
              lower.endsWith('.ass') ||
              lower.endsWith('.ssa') ||
              lower.endsWith('.vtt');
        }).where((file) {
          final parsed = guessJimakuMedia(file.name);
          final parsedSeason = parsed?.season;
          final parsedEpisode = parsed?.episode;
          final seasonMatches =
              guess.season == null ||
              parsedSeason == null ||
              parsedSeason == guess.season;
          if (!seasonMatches) return false;
          if (guess.episode == null) return true;
          return parsed?.matchesEpisode(guess.episode!) == true ||
              (episodeFiltered &&
                  parsed?.hasEpisodeCandidates != true &&
                  parsedEpisode == null);
        }).toList();
    files.sort((a, b) {
      final score = _fileScore(b, guess).compareTo(_fileScore(a, guess));
      return score == 0 ? a.name.compareTo(b.name) : score;
    });
    return files;
  }
}

final _absoluteEpisodeRegexes = [
  RegExp(r'\u7b2c\s*(\d{1,4})\s*[\u8a71\u96c6\u56de]'),
  RegExp(r'(\d{1,4})\s*[\u8a71\u96c6\u56de]'),
  RegExp(r'(?:\uc81c\s*)?(\d{1,4})\s*(?:\ud654|\ud68c)', caseSensitive: false),
];

final _episodeRegexes = [
  RegExp(r'\bS\s*\d{1,3}\s*[._ -]*E\s*(\d{1,4})\b', caseSensitive: false),
  RegExp(r'\bS\s*\d{1,3}\s*[._ -]*x\s*E?\s*(\d{1,4})\b', caseSensitive: false),
  RegExp(r'\b\d{1,3}\s*x\s*(\d{1,4})\b', caseSensitive: false),
  RegExp(
    r'\b(?:ep|eps|episode|episodes|episodio|episodios|capitulo|capitulos|cap|e)\.?\s*[-_ ]?(\d{1,4})(?:v\d+)?\b',
    caseSensitive: false,
  ),
  RegExp(
    r'\b(\d{1,4})(?:st|nd|rd|th)?\s*(?:ep|episode|episodes)\b',
    caseSensitive: false,
  ),
  RegExp(r'[#\uff03]\s*(\d{1,4})\b'),
];

final _standaloneEpisodeRegex = RegExp(
  r'(?:^|[^A-Za-z0-9])(\d{1,4})(?![A-Za-z0-9pP])',
);

final _seasonRegexes = [
  RegExp(
    r'\bS\s*(\d{1,3})\s*[._ -]*(?:E|xE?|x)\s*\d{1,4}\b',
    caseSensitive: false,
  ),
  RegExp(r'\b(\d{1,3})\s*x\s*\d{1,4}\b', caseSensitive: false),
  RegExp(
    r'\b(?:season|seasons|saison|saisons|seizoen|temporada|temporadas|stagione|temp|s)\.?\s*(\d{1,3})\b',
    caseSensitive: false,
  ),
];

final _knownExtensionRegex = RegExp(
  r'\.(?:3g2|3gp|avi|divx|flv|m2ts|m4v|mkv|mov|mp4|mpeg|mpg|ogm|ogv|rmvb|ts|vob|webm|wmv|ass|idx|smi|srt|ssa|sub|vtt)$',
  caseSensitive: false,
);

const _releaseInfoPattern =
    r'144p|240p|360p|368p|480p|540p|576p|720p|900p|960p|1080[pi]|1440p|2160p|4320p|4k|8k|uhd|fhd|vhs(?:rip)?|cam(?:rip)?|hdcam|telesync|hdts|workprint|telecine|hdtc|ppv|sdtv|hdtv|tvrip|dvb|vod(?:rip)?|web(?:rip|dl|cap|uhd)?|web-?dl|dvd(?:rip|r|5|9)?|blu-?ray|b[dr](?:rip|remux)?|brrip|bdrip|remux|xvid|divx|x264|x265|h[._-]?264|h[._-]?265|hevc|avc|av1|vp9|hi10p|10bit|8bit|aac|ac-?3|e-?ac-?3|ddp?|dts(?:-?hd|-?ma|-?x)?|true-?hd|atmos|flac|opus|dual[ ._-]?audio|multi[ ._-]?audio|fansub|hardsub|softsub|subbed|dubbed|vostfr|hdr(?:10\+?)?|proper|repack|uncensored|uncut|remastered|complete|amzn|amazon|nf|netflix|cr|crunchyroll|hidive|bilibili';

final _episodeCleanupRegex = RegExp(
  r'\bS\s*\d{1,3}\s*[._ -]*(?:E|xE?|x)\s*\d{1,4}\b|\b\d{1,3}\s*x\s*\d{1,4}\b|\b(?:ep|eps|episode|episodes|episodio|episodios|capitulo|capitulos|cap|e)\.?\s*[-_ ]?\d{1,4}(?:v\d+)?\b|[#\uff03]\s*\d{1,4}\b|\u7b2c\s*\d{1,4}\s*[\u8a71\u96c6\u56de]|\d{1,4}\s*[\u8a71\u96c6\u56de]|(?:\uc81c\s*)?\d{1,4}\s*(?:\ud654|\ud68c)',
  caseSensitive: false,
);
final _seasonCleanupRegex = RegExp(
  r'\bseason[ ._-]*\d{1,3}\b',
  caseSensitive: false,
);
final _releaseTailRegex = RegExp(
  '(?:[\\s._-]+|[\\[(]\\s*)(?:$_releaseInfoPattern)(?:\$|[\\s._-]|\\]|\\)|\\}).*\$',
  caseSensitive: false,
);
final _filenameJunkRegex = RegExp(
  '(?:^|[\\s._-])(?:$_releaseInfoPattern)(?:\$|[\\s._-])|\\[[^\\]]*]|\\([^)]*\\)|\\{[^}]*\\}',
  caseSensitive: false,
);
final _trailingEpisodeCleanupRegex = RegExp(
  r'\s*(?:[-._]+\s*(?:ep|episode|e)?\.?|(?:ep|episode|e)\.?\s*)\d{1,4}\s*$',
  caseSensitive: false,
);
final _leadingReleaseGroupRegex = RegExp(
  r'^\s*(?:\[[^\]]{1,80}]|\([^)]{1,80}\)|\{[^}]{1,80}\})\s*',
);
final _trailingReleaseGroupRegex = RegExp(
  r'-[A-Za-z0-9][A-Za-z0-9._-]{1,40}$',
  caseSensitive: false,
);
final _hashRegex = RegExp(
  r'[\[(]?[A-F0-9]{8}(?:[A-F0-9]{8})?[\])]?(?:$|[\s._-])',
  caseSensitive: false,
);
final _websiteRegex = RegExp(
  r'\b(?:www\.)?[A-Za-z0-9-]+\.(?:com|net|org|ru|cc|tv)\b',
  caseSensitive: false,
);
final _subtitleLanguageSuffixRegex = RegExp(
  r'(?:[\s._-]+(?:sub|subs|subtitle|subtitles|dub|dual|multi|eng|english|en|en-us|en-gb|fre|french|fr|spa|spanish|es|ger|deu|de|ita|it|por|pt|rus|ru|jpn|japanese|ja|jp|ja-jp|kor|korean|ko|chi|chs|cht|zho|zh|ara|ar))+\s*$',
  caseSensitive: false,
);

final _titleBeforeEpisodeRegexes = [
  RegExp(
    r'^(.+?)(?=[\s._-]+S\s*\d{1,3}\s*[._ -]*(?:E|xE?|x)\s*\d{1,4}\b)',
    caseSensitive: false,
  ),
  RegExp(r'^(.+?)(?=[\s._-]+\d{1,3}\s*x\s*\d{1,4}\b)', caseSensitive: false),
  RegExp(
    r'^(.+?)(?=\s*[-._]\s*(?:ep|episode|e)?\.?\s*\d{1,4}\b)',
    caseSensitive: false,
  ),
  RegExp(r'^(.+?)(?=[\s._-]+\u7b2c\s*\d{1,4}\s*[\u8a71\u96c6\u56de])'),
];

final _titleAfterLeadingEpisodeRegexes = [
  RegExp(
    r'^\s*(?:\[[^\]]{1,80}]\s*)?(?:[#\uff03]\s*)?\d{1,4}(?:v\d+)?\s*[-._ ]+\s*(.+)$',
    caseSensitive: false,
  ),
  RegExp(
    r'^\s*(?:\[[^\]]{1,80}]\s*)?(?:ep|episode|e)\.?\s*\d{1,4}(?:v\d+)?\s*[-._ ]+\s*(.+)$',
    caseSensitive: false,
  ),
];

const _ignoredNumbers = {480, 720, 1080, 2160, 264, 265, 10};

extension _JimakuStringParsing on String {
  String toJimakuFilename() {
    return split(
      '?',
    ).first.split('#').first.split('/').last.split('\\').last.trim();
  }

  (int?, Set<int>) jimakuEpisodeNumbers() {
    final absolute = _numbersFrom(_absoluteEpisodeRegexes);
    final marked = _numbersFrom(_episodeRegexes);
    final standalone = _standaloneEpisodeRegex
        .allMatches(this)
        .map((match) => int.tryParse(match.group(1) ?? ''))
        .whereType<int>()
        .where(
          (number) =>
              _isValidEpisode(number) && !_ignoredNumbers.contains(number),
        )
        .toList();
    final weak = absolute.isEmpty && marked.isEmpty ? standalone : <int>[];
    final primary =
        absolute.firstOrNull ?? marked.firstOrNull ?? weak.lastOrNull;
    return (primary, {...absolute, ...marked, ...weak});
  }

  List<int> _numbersFrom(List<RegExp> regexes) {
    return regexes
        .expand((regex) => regex.allMatches(this))
        .map((match) => int.tryParse(match.group(match.groupCount) ?? ''))
        .whereType<int>()
        .where(_isValidEpisode)
        .toList();
  }

  String preferredJimakuTitleSeed() {
    for (final regex in _titleBeforeEpisodeRegexes) {
      final candidate = regex.firstMatch(this)?.group(1) ?? '';
      if (candidate.cleanJimakuTitle().normalizedJimakuText().length >= 2) {
        return candidate;
      }
    }
    for (final regex in _titleAfterLeadingEpisodeRegexes) {
      final candidate = regex.firstMatch(this)?.group(1) ?? '';
      if (candidate.cleanJimakuTitle().normalizedJimakuText().length >= 2) {
        return candidate;
      }
    }
    return this;
  }

  String cleanJimakuTitle() {
    return replaceAll(_knownExtensionRegex, '')
        .replaceAll(_leadingReleaseGroupRegex, ' ')
        .replaceAll(_hashRegex, ' ')
        .replaceAll(_websiteRegex, ' ')
        .replaceAll(_episodeCleanupRegex, ' ')
        .replaceAll(_seasonCleanupRegex, ' ')
        .replaceAll(_releaseTailRegex, ' ')
        .replaceAll(_filenameJunkRegex, ' ')
        .replaceAll(_subtitleLanguageSuffixRegex, ' ')
        .replaceAll(_trailingEpisodeCleanupRegex, ' ')
        .replaceAll(_trailingReleaseGroupRegex, ' ')
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String normalizedJimakuText() {
    final buffer = StringBuffer();
    var lastWasSpace = true;
    for (final rune in toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z0-9]').hasMatch(char) || rune > 127) {
        buffer.write(char);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
    }
    return buffer.toString().trim();
  }
}

bool _isValidEpisode(int value) => value >= 0 && value <= 9999;

int _entryScore(JimakuEntry entry, String title) {
  final target = title.normalizedJimakuText();
  var best = 0;
  for (final candidate in [
    entry.name,
    entry.englishName ?? '',
    entry.japaneseName ?? '',
  ]) {
    if (candidate.trim().isEmpty) continue;
    final normalized = candidate.normalizedJimakuText();
    final score = normalized == target
        ? 100
        : normalized.contains(target) || target.contains(normalized)
        ? 90
        : _tokenScore(target, normalized);
    if (score > best) best = score;
  }
  return best;
}

int _fileScore(JimakuFile file, JimakuMediaGuess guess) {
  final parsed = guessJimakuMedia(file.name);
  var score = 0;
  if (guess.season != null) {
    score += parsed?.season == guess.season
        ? 60
        : parsed?.season == null
        ? 0
        : -160;
  }
  if (guess.episode != null) {
    score += parsed?.matchesEpisode(guess.episode!) == true
        ? 100
        : parsed?.hasEpisodeCandidates == true
        ? -80
        : parsed?.episode == null
        ? 20
        : -80;
  }
  final fileTitle = parsed?.title.normalizedJimakuText() ?? '';
  final targetTitle = guess.title.normalizedJimakuText();
  if (fileTitle.isNotEmpty &&
      targetTitle.isNotEmpty &&
      (fileTitle.contains(targetTitle) || targetTitle.contains(fileTitle))) {
    score += 25;
  }
  final lower = file.name.toLowerCase();
  if (lower.contains('ja-jp') ||
      lower.contains('japanese') ||
      lower.contains('.ja.')) {
    score += 25;
  }
  if (lower.endsWith('.ass') ||
      lower.endsWith('.srt') ||
      lower.endsWith('.ssa')) {
    score += 10;
  }
  return score;
}

int _tokenScore(String target, String candidate) {
  final targetTokens = target
      .split(' ')
      .where((item) => item.isNotEmpty)
      .toSet();
  final candidateTokens = candidate
      .split(' ')
      .where((item) => item.isNotEmpty)
      .toSet();
  if (targetTokens.isEmpty || candidateTokens.isEmpty) return 0;
  return (targetTokens.intersection(candidateTokens).length * 100) ~/
      (targetTokens.length > candidateTokens.length
          ? targetTokens.length
          : candidateTokens.length);
}

String _safeFileName(String value) {
  final safe = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return safe.isEmpty ? 'jimaku-subtitle.srt' : safe;
}

Uri _absoluteJimakuUri(String value) {
  final parsed = Uri.parse(value);
  if (parsed.hasScheme) return parsed;
  final prefix = value.startsWith('/') ? '' : '/';
  return Uri.parse('https://jimaku.cc$prefix$value');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
