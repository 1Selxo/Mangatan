import 'package:flutter/material.dart';
import 'package:mangayomi/modules/more/statistics/widgets/immersion_stats_format.dart';
import 'package:mangayomi/modules/more/statistics/widgets/stats_sheet_layout.dart';
import 'package:mangayomi/services/statistics/manga_statistics_tracker.dart';
import 'package:mangayomi/services/statistics/novel_statistics_tracker.dart';

/// Chimahon's in-reader novel statistics sheet.
///
/// The tracker already maintains session, today, and all-time buckets, so this
/// only formats them and computes the two projections.
class NovelStatsSheet extends StatelessWidget {
  const NovelStatsSheet({
    super.key,
    required this.tracker,
    required this.currentCharacter,
    required this.totalCharacters,
    required this.chapterEndCharacter,
    required this.onToggleTracking,
  });

  final NovelStatisticsTracker tracker;

  /// Live reader position, used for projections while tracking.
  final int currentCharacter;
  final int totalCharacters;
  final int chapterEndCharacter;
  final VoidCallback onToggleTracking;

  @override
  Widget build(BuildContext context) {
    final state = tracker.state;
    final session = state.session;
    // While paused, project from the frozen position so page flips during the
    // pause do not move the estimate.
    final projectionCharacter = state.isTracking
        ? currentCharacter
        : tracker.frozenPosition;

    return StatsSheetLayout(
      title: 'Statistics',
      isTracking: state.isTracking,
      onToggleTracking: onToggleTracking,
      sections: [
        StatsSheetSection(
          title: 'Session',
          rows: [
            StatsSheetRow('Characters Read', formatCount(session.charactersRead)),
            StatsSheetRow('Reading Speed', '${session.lastReadingSpeed} / h'),
            StatsSheetRow(
              'Reading Time',
              formatElapsed(Duration(seconds: session.readingTimeSeconds.toInt())),
            ),
            StatsSheetRow(
              'Time to finish Book',
              formatEstimate(
                MangaStatsEstimate.secondsRemaining(
                  totalCharacters - projectionCharacter,
                  session.lastReadingSpeed,
                ),
              ),
            ),
            StatsSheetRow(
              'Time to finish Chapter',
              formatEstimate(
                MangaStatsEstimate.secondsRemaining(
                  chapterEndCharacter - projectionCharacter,
                  session.lastReadingSpeed,
                ),
              ),
            ),
          ],
        ),
        StatsSheetSection(
          title: 'Today',
          rows: _totalsRows(state.today.charactersRead,
              state.today.lastReadingSpeed, state.today.readingTimeSeconds),
        ),
        StatsSheetSection(
          title: 'All Time',
          rows: _totalsRows(state.allTime.charactersRead,
              state.allTime.lastReadingSpeed, state.allTime.readingTimeSeconds),
        ),
      ],
    );
  }

  static List<StatsSheetRow> _totalsRows(
    int characters,
    int speed,
    double seconds,
  ) => [
    StatsSheetRow('Characters Read', formatCount(characters)),
    StatsSheetRow('Reading Speed', '$speed / h'),
    StatsSheetRow('Reading Time', formatElapsed(Duration(seconds: seconds.toInt()))),
  ];
}
