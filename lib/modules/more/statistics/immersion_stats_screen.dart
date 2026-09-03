import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/modules/more/statistics/immersion_stats_data.dart';
import 'package:mangayomi/modules/more/statistics/immersion_stats_provider.dart';
import 'package:mangayomi/modules/more/statistics/widgets/immersion_stats_format.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';

/// Chimahon's immersion statistics screen.
///
/// Passing [titleId] renders the single-title variant: library, tracker, and
/// download metrics are hidden because they are not per-title values.
class ImmersionStatsScreen extends ConsumerStatefulWidget {
  const ImmersionStatsScreen({
    super.key,
    this.titleId,
    this.isNovel = false,
    this.titleName,
  });

  final String? titleId;
  final bool isNovel;
  final String? titleName;

  @override
  ConsumerState<ImmersionStatsScreen> createState() =>
      _ImmersionStatsScreenState();
}

class _ImmersionStatsScreenState extends ConsumerState<ImmersionStatsScreen> {
  late ImmersionStatsQuery _query;

  bool get _isSingleTitle => widget.titleId != null;

  @override
  void initState() {
    super.initState();
    _query = ImmersionStatsQuery(
      titleId: widget.titleId,
      isNovel: widget.isNovel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(immersionStatsProvider(query: _query));
    final profiles = ref
        .watch(immersionStatsProfilesProvider)
        .whenOrNull(data: (profiles) => profiles);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleName ?? 'Statistics'),
        actions: [
          if (!_isSingleTitle)
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                PopupMenuItem<void>(
                  onTap: () => setState(
                    () => _query = _query.copyWith(
                      includeNonLibrary: !_query.includeNonLibrary,
                    ),
                  ),
                  child: Text(
                    _query.includeNonLibrary
                        ? 'Ignore non-library entries'
                        : 'Include all read entries',
                  ),
                ),
              ],
            ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Err: $error')),
        data: (overview) => ListView(
          children: [
            _FiltersRow(
              query: _query,
              profiles: profiles ?? const [],
              isSingleTitle: _isSingleTitle,
              onChanged: (query) => setState(() => _query = query),
            ),
            if (_query.scale != ImmersionStatsDateScale.allTime)
              _DateNavigation(
                query: _query,
                onOffsetChange: (offset) =>
                    setState(() => _query = _query.copyWith(offset: offset)),
              ),
            _HeroSection(
              overview: overview,
              selectedOffset: _query.offset,
              onOffsetChange: (offset) =>
                  setState(() => _query = _query.copyWith(offset: offset)),
            ),
            _StatsGrid(
              overview: overview,
              query: _query,
              isSingleTitle: _isSingleTitle,
              onLibraryTap: _isSingleTitle
                  ? null
                  : () => context.push('/statistics/titles', extra: _query),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.query,
    required this.profiles,
    required this.isSingleTitle,
    required this.onChanged,
  });

  final ImmersionStatsQuery query;
  final List<dynamic> profiles;
  final bool isSingleTitle;
  final ValueChanged<ImmersionStatsQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeProfile = profiles.cast<dynamic>().where(
      (profile) => profile.id == query.profileId,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 12),
      child: Row(
        spacing: 8,
        children: [
          if (!isSingleTitle)
            for (final type in ImmersionStatsType.values)
              FilterChip(
                selected: query.type == type,
                showCheckmark: false,
                label: Text(immersionStatsTypeLabel(type)),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                // Switching scope invalidates the selected period's meaning as
                // little as possible, so the offset is intentionally kept.
                onSelected: (_) => onChanged(query.copyWith(type: type)),
              ),
          PopupMenuButton<ImmersionStatsDateScale>(
            onSelected: (scale) =>
                // A new scale reinterprets the offset units, so reset to the
                // current period rather than jumping somewhere arbitrary.
                onChanged(query.copyWith(scale: scale, offset: 0)),
            itemBuilder: (context) => [
              for (final scale in ImmersionStatsDateScale.values)
                PopupMenuItem(
                  value: scale,
                  child: Text(immersionStatsScaleLabel(scale)),
                ),
            ],
            child: _ChipShell(
              label: immersionStatsScaleLabel(query.scale),
              selected: false,
            ),
          ),
          if (!isSingleTitle && profiles.isNotEmpty)
            PopupMenuButton<String?>(
              onSelected: (profileId) => onChanged(
                profileId == null
                    ? query.copyWith(clearProfileId: true)
                    : query.copyWith(profileId: profileId),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem<String?>(child: Text('All profiles')),
                for (final profile in profiles)
                  PopupMenuItem<String?>(
                    value: profile.id as String,
                    child: Text(profile.name as String),
                  ),
              ],
              child: _ChipShell(
                label: activeProfile.isEmpty
                    ? 'All profiles'
                    : 'Profile: ${activeProfile.first.name}',
                selected: query.profileId != null,
              ),
            ),
        ],
      ),
    );
  }
}

/// A chip that opens a menu rather than toggling, so it cannot use FilterChip's
/// tap handling.
class _ChipShell extends StatelessWidget {
  const _ChipShell({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.primaryContainer : null,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(
          color: selected
              ? Colors.transparent
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? theme.colorScheme.onPrimaryContainer : null,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

class _DateNavigation extends StatelessWidget {
  const _DateNavigation({required this.query, required this.onOffsetChange});

  final ImmersionStatsQuery query;
  final ValueChanged<int> onOffsetChange;

  @override
  Widget build(BuildContext context) {
    final canGoForward = query.offset < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => onOffsetChange(query.offset - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            immersionStatsPeriodLabel(query.scale, query.offset),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            // The future holds no reading, so navigating past the current
            // period is disabled rather than showing empty periods.
            onPressed: canGoForward
                ? () => onOffsetChange(query.offset + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Total time for the period, the per-day average, and a tappable bar chart.
class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.overview,
    required this.selectedOffset,
    required this.onOffsetChange,
  });

  final ImmersionStatsOverview overview;
  final int selectedOffset;
  final ValueChanged<int> onOffsetChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = overview.totalReadDurationMs;
    final hours = duration ~/ 3600000;
    final minutes = (duration % 3600000) ~/ 60000;
    final average = overview.avgDurationPerDayMs;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hours > 0) ...[
                Text(
                  '$hours',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 2, right: 4),
                  child: Text(
                    'h',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              Text(
                '$minutes',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 2),
                child: Text(
                  'm',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 48,
            child: average == null
                ? null
                : Text(
                    formatAveragePerDay(average),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          _HistoryChart(
            points: overview.historyPoints,
            selectedOffset: selectedOffset,
            onOffsetChange: onOffsetChange,
          ),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({
    required this.points,
    required this.selectedOffset,
    required this.onOffsetChange,
  });

  final List<ImmersionHistoryPoint> points;
  final int selectedOffset;
  final ValueChanged<int> onOffsetChange;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final maxValue = points
        .map((point) => point.durationMs)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onOffsetChange(point.dateOffset),
                      // A transparent hit area keeps short bars tappable.
                      behavior: HitTestBehavior.opaque,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 4),
                            height: maxValue > 0
                                ? 120 * point.durationMs / maxValue
                                : 4,
                            decoration: BoxDecoration(
                              color: point.dateOffset == selectedOffset
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(
                                      alpha: point.durationMs > 0 ? 0.3 : 0.15,
                                    ),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              for (final point in points)
                Expanded(
                  child: Text(
                    point.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: point.dateOffset == selectedOffset
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                      fontWeight: point.dateOffset == selectedOffset
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.overview,
    required this.query,
    required this.isSingleTitle,
    this.onLibraryTap,
  });

  final ImmersionStatsOverview overview;
  final ImmersionStatsQuery query;
  final bool isSingleTitle;
  final VoidCallback? onLibraryTap;

  @override
  Widget build(BuildContext context) {
    final showMangaOnlyMetrics =
        query.type != ImmersionStatsType.novels && !isSingleTitle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        spacing: 24,
        children: [
          _MetricSection(
            rows: [
              [
                _Metric(
                  value: '${overview.readingStreak}',
                  label: 'Streak',
                  unit: 'day',
                  icon: Icons.local_fire_department_outlined,
                ),
                _Metric(
                  value: formatCount(overview.ankiCardsAdded),
                  label: 'Added cards',
                  icon: Icons.style_outlined,
                ),
              ],
              [
                _Metric(
                  value: formatCount(overview.charactersRead),
                  label: 'Characters read',
                  icon: Icons.text_fields_outlined,
                ),
                _Metric(
                  value: formatCount(overview.charactersPerHour ?? 0),
                  label: 'Avg speed',
                  unit: 'ch/h',
                  icon: Icons.speed_outlined,
                ),
              ],
            ],
          ),
          if (!isSingleTitle)
            _MetricSection(
              title: 'Library',
              rows: [
                [
                  _Metric(
                    value: formatCount(overview.libraryTitleCount),
                    label: query.includeNonLibrary ? 'All read' : 'In library',
                    icon: Icons.library_books_outlined,
                    onTap: onLibraryTap,
                  ),
                  _Metric(
                    value: formatCount(overview.localTitleCount),
                    label: 'Local',
                    icon: Icons.sd_card_outlined,
                  ),
                ],
                [
                  _Metric(
                    value: formatCount(overview.startedTitleCount),
                    label: 'Started',
                    icon: Icons.play_arrow_outlined,
                  ),
                  _Metric(
                    value: formatCount(overview.completedTitleCount),
                    label: 'Completed',
                    icon: Icons.done_all_outlined,
                  ),
                ],
              ],
            ),
          _MetricSection(
            title: 'Chapters',
            rows: [
              [
                _Metric(
                  value: formatCount(overview.totalChapterCount),
                  label: 'Total',
                  icon: Icons.menu_book_outlined,
                ),
                _Metric(
                  value: formatCount(overview.readChapterCount),
                  label: 'Read',
                  icon: Icons.history_outlined,
                ),
              ],
              if (showMangaOnlyMetrics)
                [
                  _Metric(
                    value: formatCount(overview.downloadedChapterCount),
                    label: 'Downloaded',
                    icon: Icons.download_outlined,
                  ),
                ],
            ],
          ),
          if (showMangaOnlyMetrics)
            _MetricSection(
              title: 'Trackers',
              rows: [
                [
                  _Metric(
                    value: formatCount(overview.trackedTitleCount),
                    label: 'Tracked titles',
                    icon: Icons.collections_bookmark_outlined,
                  ),
                  _Metric(
                    value: overview.meanScore > 0
                        ? overview.meanScore.toStringAsFixed(1)
                        : '0.0',
                    label: 'Mean score',
                    icon: Icons.star_outline,
                  ),
                ],
                [
                  _Metric(
                    value: formatCount(overview.trackerCount),
                    label: 'Trackers',
                    icon: Icons.public_outlined,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({this.title, required this.rows});

  final String? title;
  final List<List<_Metric>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        for (final row in rows)
          Row(
            spacing: 12,
            children: [
              for (final metric in row) Expanded(child: metric),
              // Pad a short row so a lone card keeps the grid's column width.
              if (row.length == 1) const Spacer(),
            ],
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    this.unit,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final String? unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: SizedBox(
          height: 114,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 24, color: context.primaryColor),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 4,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (unit != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              unit!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
