import 'package:mangayomi/services/statistics/immersion_stats_storage.dart';

/// Live totals for the manga stats sheet.
class MangaStatisticsSession {
  const MangaStatisticsSession({
    this.charactersRead = 0,
    this.readingTimeMs = 0,
    this.isTracking = true,
  });

  final int charactersRead;
  final int readingTimeMs;
  final bool isTracking;

  int get charactersPerHour => readingTimeMs > 0
      ? (charactersRead / (readingTimeMs / 3600000)).toInt()
      : 0;

  MangaStatisticsSession copyWith({
    int? charactersRead,
    int? readingTimeMs,
    bool? isTracking,
  }) => MangaStatisticsSession(
    charactersRead: charactersRead ?? this.charactersRead,
    readingTimeMs: readingTimeMs ?? this.readingTimeMs,
    isTracking: isTracking ?? this.isTracking,
  );
}

/// Port of Chimahon's manga-side page dwell tracking (`trackMangaStats`).
///
/// Unlike the novel reader, which knows an absolute character position, the
/// manga reader learns a page's character count only after OCR has run. So each
/// page is attributed when the reader *leaves* it: the dwell time is the gap
/// between page changes and the characters are that page's OCR text length.
class MangaStatisticsTracker {
  MangaStatisticsTracker({
    required this.mangaId,
    this.enabled = true,
    Stopwatch Function()? stopwatchFactory,
  }) : _elapsed = (stopwatchFactory ?? Stopwatch.new)()..start();

  /// Chimahon buckets reading with no library entry under id 0.
  final int mangaId;
  final bool enabled;

  /// Chimahon caps a single page's attributed time. Anything longer is the app
  /// having sat in the background or the device asleep, not reading.
  static const maxPageDurationMs = 120000;

  /// Below this, a page was flipped past rather than read.
  static const minPageDurationMs = 500;

  final Stopwatch _elapsed;

  /// Pages already counted this chapter, so scrolling back and forth over the
  /// same page cannot inflate the character total.
  final Set<int> _consumedPages = <int>{};

  int? _currentPageIndex;
  int _lastTimestampMs = 0;
  MangaStatisticsSession _session = const MangaStatisticsSession();

  MangaStatisticsSession get session => _session;

  bool get isTracking => _session.isTracking;

  void toggleTracking() {
    _session = _session.copyWith(isTracking: !_session.isTracking);
    // Restart the window so paused time is never attributed to the next page.
    _lastTimestampMs = _elapsed.elapsedMilliseconds;
  }

  /// Called when the visible page changes, and with `null` when the reader
  /// closes or switches chapter.
  ///
  /// [charactersForPage] resolves the *previous* page's OCR character count. It
  /// is a callback because OCR may still have been running while that page was
  /// on screen.
  Future<void> onPageChanged({
    required int? pageIndex,
    required Future<int> Function(int pageIndex) charactersForPage,
    bool incognito = false,
  }) async {
    if (pageIndex == null) _consumedPages.clear();

    final now = _elapsed.elapsedMilliseconds;
    final previousPage = _currentPageIndex;
    final rawTime = now - _lastTimestampMs;
    final timeSpent = rawTime > maxPageDurationMs ? maxPageDurationMs : rawTime;

    _currentPageIndex = pageIndex;
    _lastTimestampMs = now;

    if (!enabled ||
        incognito ||
        previousPage == null ||
        timeSpent <= minPageDurationMs ||
        _consumedPages.contains(previousPage)) {
      return;
    }
    _consumedPages.add(previousPage);

    final characters = await charactersForPage(previousPage);
    await ImmersionStatsStorage.addMangaStats(
      characters: characters,
      timeMs: timeSpent,
      mangaId: mangaId,
    );
    if (_session.isTracking) {
      _session = _session.copyWith(
        charactersRead: _session.charactersRead + characters,
        readingTimeMs: _session.readingTimeMs + timeSpent,
      );
    }
  }

  /// Attributes the page currently on screen, for reader teardown.
  Future<void> flush({
    required Future<int> Function(int pageIndex) charactersForPage,
    bool incognito = false,
  }) => onPageChanged(
    pageIndex: null,
    charactersForPage: charactersForPage,
    incognito: incognito,
  );

  /// Forgets consumed pages when moving to a new chapter, matching Chimahon's
  /// per-chapter dedup scope.
  void resetChapter() {
    _consumedPages.clear();
    _lastTimestampMs = _elapsed.elapsedMilliseconds;
  }
}

/// Remaining-time projections shown in the manga stats sheet.
class MangaStatsEstimate {
  const MangaStatsEstimate({
    this.remainingBookCharacters = 0,
    this.remainingChapterCharacters = 0,
    this.remainingBookSeconds = 0,
    this.remainingChapterSeconds = 0,
  });

  final int remainingBookCharacters;
  final int remainingChapterCharacters;
  final double remainingBookSeconds;
  final double remainingChapterSeconds;

  /// Converts a remaining character count into seconds at [charactersPerHour].
  /// A zero or unknown speed yields zero rather than infinity.
  static double secondsRemaining(int remainingCharacters, int charactersPerHour) {
    if (charactersPerHour <= 0) return 0;
    final remaining = remainingCharacters < 0 ? 0 : remainingCharacters;
    return remaining / (charactersPerHour / 3600);
  }
}
