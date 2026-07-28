import 'package:mangayomi/services/statistics/immersion_stats_models.dart';
import 'package:mangayomi/services/statistics/immersion_stats_storage.dart';

/// Session/today/all-time view of one novel's reading, refreshed on every tick.
class NovelStatisticsState {
  const NovelStatisticsState({
    required this.isTracking,
    required this.session,
    required this.today,
    required this.allTime,
  });

  final bool isTracking;
  final NovelStatsEntry session;
  final NovelStatsEntry today;
  final NovelStatsEntry allTime;

  NovelStatisticsState copyWith({
    bool? isTracking,
    NovelStatsEntry? session,
    NovelStatsEntry? today,
    NovelStatsEntry? allTime,
  }) => NovelStatisticsState(
    isTracking: isTracking ?? this.isTracking,
    session: session ?? this.session,
    today: today ?? this.today,
    allTime: allTime ?? this.allTime,
  );
}

/// Port of Chimahon's `ReaderStatisticsTracker`.
///
/// The reader reports its absolute explored character position; this converts
/// successive positions plus wall-clock deltas into per-day statistics. All the
/// clamping quirks are Chimahon's and are preserved so the same reading
/// produces the same numbers in both apps.
class NovelStatisticsTracker {
  NovelStatisticsTracker({
    required this.novelId,
    List<NovelStatsEntry> initialStatistics = const [],
    this.enabled = true,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _statistics = List.of(initialStatistics) {
    _lastTimestampMs = _nowMs();
    _state = NovelStatisticsState(
      isTracking: false,
      session: _defaultEntry(),
      today: _entryForDate(_currentDateKey()),
      allTime: _allTimeEntry(_statistics),
    );
  }

  /// Chimahon's stable book identity. An empty ID disables persistence.
  final String novelId;
  final bool enabled;
  final DateTime Function() _clock;

  List<NovelStatsEntry> _statistics;
  late NovelStatisticsState _state;
  late int _lastTimestampMs;
  int _lastCharacterCount = 0;
  bool _hasUpdated = false;

  NovelStatisticsState get state => _state;

  /// Position the ETA projections should use while tracking is paused, so page
  /// flips during a pause do not move the estimate.
  int get frozenPosition => _lastCharacterCount;

  bool get hasUnsavedUpdates => _hasUpdated;

  void start(int currentCharacter) {
    if (!enabled) return;
    _state = _state.copyWith(isTracking: true);
    resetBaseline(currentCharacter);
  }

  void startForPageTurnIfNeeded(int currentCharacter) {
    if (!_state.isTracking) start(currentCharacter);
  }

  void stop(int currentCharacter) => pause(currentCharacter);

  bool pause(int currentCharacter) {
    if (!_state.isTracking) return false;
    update(currentCharacter);
    _state = _state.copyWith(isTracking: false);
    return true;
  }

  void togglePause(int currentCharacter) {
    if (_state.isTracking) {
      pause(currentCharacter);
    } else {
      start(currentCharacter);
    }
  }

  /// Folds the time and characters since the last call into all three buckets.
  void update(int currentCharacter) {
    if (!enabled || !_state.isTracking) return;
    _rollTodayIfNeeded();
    final now = _nowMs();
    final timeDiff = (now - _lastTimestampMs) / 1000.0;
    if (timeDiff <= 0) return;

    final charDiff = currentCharacter - _lastCharacterCount;
    // A large jump backwards (chapter restart, TOC jump) must not push the
    // session negative; it can only cancel what this session counted.
    final finalCharDiff =
        charDiff < 0 && charDiff.abs() > _state.session.charactersRead
        ? -_state.session.charactersRead
        : charDiff;
    final modified = now;
    _state = _state.copyWith(
      session: _state.session.updated(
        timeDiffSeconds: timeDiff,
        characterDiff: finalCharDiff,
        modifiedAtMs: modified,
      ),
      today: _state.today.updated(
        timeDiffSeconds: timeDiff,
        characterDiff: finalCharDiff,
        modifiedAtMs: modified,
      ),
      allTime: _state.allTime.updated(
        timeDiffSeconds: timeDiff,
        characterDiff: finalCharDiff,
        modifiedAtMs: modified,
      ),
    );
    _hasUpdated = true;
    _lastTimestampMs = now;
    _lastCharacterCount = currentCharacter;
  }

  /// Re-anchors position and time without recording anything, for jumps that
  /// are navigation rather than reading.
  void resetBaseline(int currentCharacter) {
    _lastCharacterCount = currentCharacter;
    _lastTimestampMs = _nowMs();
  }

  /// The rows to persist: stored days, deduplicated by most recently modified,
  /// with today's live row replacing its stored counterpart.
  List<NovelStatsEntry> statisticsForPersistence() {
    final today = _state.today;
    final grouped = <String, NovelStatsEntry>{};
    for (final entry in _statistics) {
      final existing = grouped[entry.dateKey];
      if (existing == null ||
          entry.lastStatisticModified >= existing.lastStatisticModified) {
        grouped[entry.dateKey] = entry;
      }
    }
    grouped[today.dateKey] = today;
    final next = grouped.values.toList();
    _statistics = List.of(next);
    return next;
  }

  List<NovelStatsEntry>? statisticsForPersistenceOrNull() =>
      enabled && (_hasUpdated || _statistics.isNotEmpty)
      ? statisticsForPersistence()
      : null;

  /// Writes the current statistics for this book, if there is anything to save.
  Future<void> persist() async {
    final stats = statisticsForPersistenceOrNull();
    if (stats == null || novelId.isEmpty) return;
    await ImmersionStatsStorage.saveNovelStats(novelId, stats);
    _hasUpdated = false;
  }

  /// Rolls over at midnight so a session spanning two days is split correctly.
  void _rollTodayIfNeeded() {
    final key = _currentDateKey();
    if (_state.today.dateKey == key) return;
    statisticsForPersistence();
    _state = _state.copyWith(today: _entryForDate(key));
  }

  NovelStatsEntry _entryForDate(String dateKey) {
    for (final entry in _statistics) {
      if (entry.dateKey == dateKey) return entry;
    }
    return _defaultEntry(dateKey);
  }

  NovelStatsEntry _defaultEntry([String? dateKey]) =>
      NovelStatsEntry(dateKey: dateKey ?? _currentDateKey());

  NovelStatsEntry _allTimeEntry(List<NovelStatsEntry> statistics) {
    var total = _defaultEntry();
    for (final entry in statistics) {
      final readingTime = total.readingTimeSeconds + entry.readingTimeSeconds;
      final charactersRead = total.charactersRead + entry.charactersRead;
      total = total.copyWith(
        readingTimeSeconds: readingTime,
        charactersRead: charactersRead,
        lastReadingSpeed: readingTime > 0
            ? (charactersRead / readingTime * 3600).toInt()
            : 0,
      );
    }
    return total;
  }

  int _nowMs() => _clock().millisecondsSinceEpoch;

  String _currentDateKey() => statsDateKey(_clock());
}
