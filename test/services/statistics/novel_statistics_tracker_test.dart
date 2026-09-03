import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/statistics/immersion_stats_models.dart';
import 'package:mangayomi/services/statistics/novel_statistics_tracker.dart';

void main() {
  /// A tracker driven by a controllable clock, so the character/time arithmetic
  /// can be asserted exactly rather than approximately.
  ({NovelStatisticsTracker tracker, void Function(int seconds) advance})
  build({List<NovelStatsEntry> initial = const []}) {
    var now = DateTime(2026, 7, 18, 12);
    return (
      tracker: NovelStatisticsTracker(
        novelId: 'book',
        initialStatistics: initial,
        clock: () => now,
      ),
      advance: (seconds) => now = now.add(Duration(seconds: seconds)),
    );
  }

  test('records characters and time into session, today, and all time', () {
    final (tracker: tracker, advance: advance) = build();
    tracker.start(0);
    advance(60);
    tracker.update(600);

    final state = tracker.state;
    expect(state.session.charactersRead, 600);
    expect(state.session.readingTimeSeconds, 60);
    // 600 characters in one minute is 36000 characters per hour.
    expect(state.session.lastReadingSpeed, 36000);
    expect(state.today.charactersRead, 600);
    expect(state.allTime.charactersRead, 600);
  });

  test('a paused tracker records nothing', () {
    final (tracker: tracker, advance: advance) = build();
    tracker.start(0);
    advance(60);
    tracker.update(600);
    tracker.pause(600);

    advance(600);
    tracker.update(1200);

    expect(tracker.state.isTracking, isFalse);
    expect(tracker.state.session.charactersRead, 600);
    expect(tracker.state.session.readingTimeSeconds, 60);
  });

  test('a large jump backwards cannot push the session negative', () {
    final (tracker: tracker, advance: advance) = build();
    tracker.start(1000);
    advance(60);
    tracker.update(1100);
    expect(tracker.state.session.charactersRead, 100);

    // Jumping to the start of the book is navigation, not un-reading 1100
    // characters: it can only cancel what this session counted.
    advance(10);
    tracker.update(0);
    expect(tracker.state.session.charactersRead, 0);
  });

  test('an idle tick leaves the alternate minimum speed untouched', () {
    final (tracker: tracker, advance: advance) = build();
    tracker.start(0);
    advance(60);
    tracker.update(600);
    final speedAfterReading = tracker.state.session.altMinReadingSpeed;
    expect(speedAfterReading, 36000);

    // Time passing with no characters read would otherwise drag the alternate
    // minimum toward zero; Chimahon only moves it when characters change.
    advance(3600);
    tracker.update(600);
    expect(tracker.state.session.altMinReadingSpeed, speedAfterReading);
    // The plain minimum does track the idle period.
    expect(tracker.state.session.minReadingSpeed, lessThan(speedAfterReading));
  });

  test('all-time totals include statistics from previous sessions', () {
    final (tracker: tracker, advance: advance) = build(
      initial: [
        const NovelStatsEntry(
          dateKey: '2026-07-01',
          charactersRead: 5000,
          readingTimeSeconds: 1000,
        ),
      ],
    );
    expect(tracker.state.allTime.charactersRead, 5000);

    tracker.start(0);
    advance(60);
    tracker.update(600);
    expect(tracker.state.allTime.charactersRead, 5600);
    // Today is a separate day from the stored row, so it starts from zero.
    expect(tracker.state.today.charactersRead, 600);
  });

  test('a stored row for today resumes rather than restarting', () {
    final (tracker: tracker, advance: advance) = build(
      initial: [
        const NovelStatsEntry(
          dateKey: '2026-07-18',
          charactersRead: 300,
          readingTimeSeconds: 30,
        ),
      ],
    );
    expect(tracker.state.today.charactersRead, 300);

    tracker.start(0);
    advance(60);
    tracker.update(600);
    expect(tracker.state.today.charactersRead, 900);
    expect(tracker.state.session.charactersRead, 600);
  });

  test('persistence keeps other days and replaces today', () {
    final (tracker: tracker, advance: advance) = build(
      initial: [
        const NovelStatsEntry(dateKey: '2026-07-01', charactersRead: 5000),
        const NovelStatsEntry(dateKey: '2026-07-18', charactersRead: 300),
      ],
    );
    tracker.start(0);
    advance(60);
    tracker.update(600);

    final persisted = tracker.statisticsForPersistence();
    expect(persisted, hasLength(2));
    final byDate = {for (final entry in persisted) entry.dateKey: entry};
    expect(byDate['2026-07-01']!.charactersRead, 5000);
    expect(byDate['2026-07-18']!.charactersRead, 900);
  });

  test('duplicate stored days collapse to the most recently modified', () {
    final (tracker: tracker, advance: _) = build(
      initial: [
        const NovelStatsEntry(
          dateKey: '2026-07-01',
          charactersRead: 100,
          lastStatisticModified: 1,
        ),
        const NovelStatsEntry(
          dateKey: '2026-07-01',
          charactersRead: 900,
          lastStatisticModified: 2,
        ),
      ],
    );

    final persisted = tracker.statisticsForPersistence();
    final july1 = persisted.where((entry) => entry.dateKey == '2026-07-01');
    expect(july1, hasLength(1));
    expect(july1.single.charactersRead, 900);
  });

  test('a session spanning midnight splits across both days', () {
    var now = DateTime(2026, 7, 18, 23, 59);
    final tracker = NovelStatisticsTracker(
      novelId: 'book',
      clock: () => now,
    );
    tracker.start(0);
    now = now.add(const Duration(seconds: 30));
    tracker.update(300);
    expect(tracker.state.today.dateKey, '2026-07-18');
    expect(tracker.state.today.charactersRead, 300);

    // Crossing midnight must open a fresh row rather than crediting the new
    // day's reading to the old one.
    now = now.add(const Duration(seconds: 60));
    tracker.update(600);
    expect(tracker.state.today.dateKey, '2026-07-19');
    expect(tracker.state.today.charactersRead, 300);
    // The session keeps accumulating across the boundary.
    expect(tracker.state.session.charactersRead, 600);

    // Both days survive persistence.
    final byDate = {
      for (final entry in tracker.statisticsForPersistence())
        entry.dateKey: entry,
    };
    expect(byDate.keys, containsAll(['2026-07-18', '2026-07-19']));
    expect(byDate['2026-07-18']!.charactersRead, 300);
  });

  test('a disabled tracker ignores every reader tick', () {
    var now = DateTime(2026, 7, 18, 12);
    final tracker = NovelStatisticsTracker(
      novelId: 'book',
      enabled: false,
      clock: () => now,
    );
    tracker.start(0);
    now = now.add(const Duration(seconds: 60));
    tracker.update(600);

    expect(tracker.state.isTracking, isFalse);
    expect(tracker.state.session.charactersRead, 0);
    expect(tracker.statisticsForPersistenceOrNull(), isNull);
  });

  test('resuming after a pause does not bill the paused time', () {
    final (tracker: tracker, advance: advance) = build();
    tracker.start(0);
    advance(60);
    tracker.update(600);
    tracker.pause(600);

    // Time away from the reader must not become reading time when it resumes.
    advance(3600);
    tracker.start(600);
    advance(60);
    tracker.update(1200);

    expect(tracker.state.session.readingTimeSeconds, 120);
    expect(tracker.state.session.charactersRead, 1200);
  });

  test('the frozen position holds while paused', () {
    final (tracker: tracker, advance: advance) = build();
    tracker.start(0);
    advance(60);
    tracker.update(600);
    tracker.pause(600);
    expect(tracker.frozenPosition, 600);

    // Page flips during a pause must not move the projection anchor.
    advance(10);
    tracker.update(5000);
    expect(tracker.frozenPosition, 600);
  });
}
