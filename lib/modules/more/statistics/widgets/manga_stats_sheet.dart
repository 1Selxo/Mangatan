import 'package:flutter/material.dart';
import 'package:mangayomi/modules/more/statistics/widgets/immersion_stats_format.dart';
import 'package:mangayomi/modules/more/statistics/widgets/stats_sheet_layout.dart';
import 'package:mangayomi/services/statistics/immersion_stats_models.dart';
import 'package:mangayomi/services/statistics/immersion_stats_storage.dart';
import 'package:mangayomi/services/statistics/manga_statistics_tracker.dart';

/// Chimahon's in-reader manga statistics sheet.
///
/// Session values come from the live tracker; today and all-time are read from
/// storage so they include reading from earlier sessions.
class MangaStatsSheet extends StatefulWidget {
  const MangaStatsSheet({
    super.key,
    required this.mangaId,
    required this.session,
    this.estimate = const MangaStatsEstimate(),
    this.onToggleTracking,
  });

  final int mangaId;
  final MangaStatisticsSession session;
  final MangaStatsEstimate estimate;

  /// Null hides the session section and pause control, for contexts outside the
  /// reader (such as the library entry's stats action).
  final VoidCallback? onToggleTracking;

  @override
  State<MangaStatsSheet> createState() => _MangaStatsSheetState();
}

class _MangaStatsSheetState extends State<MangaStatsSheet> {
  var _today = const _Totals();
  var _allTime = const _Totals();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await ImmersionStatsStorage.loadMangaStats();
    final todayKey = statsDateKey(DateTime.now());
    final forManga = stats.where((entry) => entry.mangaId == widget.mangaId);
    final today = forManga.where((entry) => entry.dateKey == todayKey);
    if (!mounted) return;
    setState(() {
      _today = _Totals.from(today);
      _allTime = _Totals.from(forManga);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showSession = widget.onToggleTracking != null;
    final session = widget.session;
    return StatsSheetLayout(
      title: 'Statistics',
      isTracking: showSession ? session.isTracking : null,
      onToggleTracking: widget.onToggleTracking,
      sections: [
        if (showSession)
          StatsSheetSection(
            title: 'Session',
            rows: [
              StatsSheetRow('Characters Read', formatCount(session.charactersRead)),
              StatsSheetRow('Reading Speed', '${session.charactersPerHour} /h'),
              StatsSheetRow(
                'Reading Time',
                formatElapsed(Duration(milliseconds: session.readingTimeMs)),
              ),
              StatsSheetRow(
                'Time to finish Book',
                formatEstimate(widget.estimate.remainingBookSeconds),
              ),
              StatsSheetRow(
                'Time to finish Chapter',
                formatEstimate(widget.estimate.remainingChapterSeconds),
              ),
            ],
          ),
        StatsSheetSection(
          title: 'Today',
          rows: [
            StatsSheetRow('Characters Read', formatCount(_today.characters)),
            StatsSheetRow('Reading Speed', '${_today.charactersPerHour} /h'),
            StatsSheetRow(
              'Reading Time',
              formatElapsed(Duration(milliseconds: _today.timeMs)),
            ),
          ],
        ),
        StatsSheetSection(
          title: 'All Time',
          rows: [
            StatsSheetRow('Characters Read', formatCount(_allTime.characters)),
            StatsSheetRow('Reading Speed', '${_allTime.charactersPerHour} /h'),
            StatsSheetRow(
              'Reading Time',
              formatElapsed(Duration(milliseconds: _allTime.timeMs)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Totals {
  const _Totals({this.characters = 0, this.timeMs = 0});

  factory _Totals.from(Iterable<MangaStatsEntry> entries) {
    var characters = 0;
    var timeMs = 0;
    for (final entry in entries) {
      characters += entry.charactersRead;
      timeMs += entry.readingTimeMs;
    }
    return _Totals(characters: characters, timeMs: timeMs);
  }

  final int characters;
  final int timeMs;

  int get charactersPerHour =>
      timeMs > 0 ? (characters / (timeMs / 3600000)).toInt() : 0;
}
