import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/modules/manga/detail/manga_detail_main.dart';
import 'package:mangayomi/repositories/download_repository.dart';
import 'package:mangayomi/services/anime_seasons.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

class AnimeSeasonList extends StatelessWidget {
  const AnimeSeasonList({super.key, required this.anime});

  final Manga anime;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Manga>>(
    stream: isar.mangas
        .filter()
        .itemTypeEqualTo(ItemType.anime)
        .watch(fireImmediately: true),
    builder: (context, snapshot) {
      final l10n = l10nLocalizations(context)!;
      final related = (snapshot.data ?? []).where(
        (m) => sameAnimeSource(m, anime),
      );
      final parent = related
          .where((m) => m.link == anime.animeParentUrl)
          .firstOrNull;
      final seasons = related
          .where((m) => m.animeParentUrl == anime.link)
          .toList();
      final current = related.where((m) => m.id == anime.id).firstOrNull;
      final flags = (current ?? anime).seasonFlags ?? 0;
      return StreamBuilder<void>(
        stream: isar.chapters.watchLazy(),
        builder: (context, _) {
          final seasonStats = {
            for (final season in seasons) _seasonKey(season): _SeasonStats.from(season),
          };
          final visibleSeasons = seasons
              .where(
                (season) =>
                    _matchesFilters(flags, seasonStats[_seasonKey(season)]!),
              )
              .toList();
          visibleSeasons.sort(
            (a, b) => _compareSeasons(
              a,
              b,
              seasonStats[_seasonKey(a)]!,
              seasonStats[_seasonKey(b)]!,
              flags,
            ),
          );
          return Column(
            children: [
          if (parent != null)
            ListTile(
              leading: const Icon(Icons.tv),
              title: Text(parent.name ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, parent),
            ),
          if (anime.hasSeasons)
            ListTile(
              title: Text(l10n.seasons),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      AnimeSeasonFlags.isAscending(flags)
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: () => _setFlags(flags ^ 1),
                  ),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.sort),
                    onSelected: (sort) =>
                        _setFlags(AnimeSeasonFlags.withSort(flags, sort)),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: AnimeSeasonFlags.sortSource,
                        child: Text(l10n.by_source),
                      ),
                      PopupMenuItem(
                        value: AnimeSeasonFlags.sortSeasonNumber,
                        child: Text(l10n.season_number),
                      ),
                      PopupMenuItem(
                        value: AnimeSeasonFlags.sortUploadDate,
                        child: const Text('Upload date'),
                      ),
                      PopupMenuItem(
                        value: AnimeSeasonFlags.sortAlphabetical,
                        child: Text(l10n.alphabetically),
                      ),
                      PopupMenuItem(
                        value: AnimeSeasonFlags.sortUnseen,
                        child: Text(l10n.unread_count),
                      ),
                      PopupMenuItem(
                        value: AnimeSeasonFlags.sortLastSeen,
                        child: Text(l10n.last_watched),
                      ),
                      PopupMenuItem(
                        value: AnimeSeasonFlags.sortFetchDate,
                        child: Text(l10n.last_update_check),
                      ),
                    ],
                  ),
                  PopupMenuButton<_SeasonFilter>(
                    icon: const Icon(Icons.filter_list),
                    onSelected: (filter) => _setFlags(
                      AnimeSeasonFlags.withFilter(
                        flags,
                        filter.value,
                        filter.mask,
                      ),
                    ),
                    itemBuilder: (_) => _filterItems(l10n),
                  ),
                ],
              ),
            ),
              for (final season in visibleSeasons)
                _seasonTile(context, l10n, season),
            ],
          );
        },
      );
    },
  );

  String _seasonKey(Manga season) => season.id?.toString() ?? season.link ?? '';

  Widget _seasonTile(
    BuildContext context,
    AppLocalizations l10n,
    Manga season,
  ) {
    season.chapters.loadSync();
    final episodes = season.chapters;
    final seen = episodes.where((e) => e.isRead == true).length;
    return ListTile(
      leading: const Icon(Icons.video_library_outlined),
      title: Text(season.name ?? ''),
      subtitle: episodes.isEmpty
          ? null
          : Text('$seen/${l10n.n_episodes(episodes.length)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(context, season),
    );
  }

  void _setFlags(int flags) => isar.writeTxnSync(() {
    final current = isar.mangas.getSync(anime.id!);
    if (current == null) return;
    current.seasonFlags = flags;
    current.updatedAt = DateTime.now().millisecondsSinceEpoch;
    isar.mangas.putSync(current);
  });

  void _open(BuildContext context, Manga entry) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MangaReaderDetail(mangaId: entry.id!),
    ),
  );
}

class _SeasonFilter {
  const _SeasonFilter(this.label, this.value, this.mask);

  final String label;
  final int value;
  final int mask;
}

List<PopupMenuEntry<_SeasonFilter>> _filterItems(AppLocalizations l10n) => [
  PopupMenuItem(
    value: const _SeasonFilter('All seasons', 0, AnimeSeasonFlags.filtersMask),
    child: const Text('All seasons'),
  ),
  PopupMenuItem(
    value: _SeasonFilter(
      l10n.downloaded,
      AnimeSeasonFlags.showDownloaded,
      AnimeSeasonFlags.downloadedMask,
    ),
    child: Text(l10n.downloaded),
  ),
  PopupMenuItem(
    value: const _SeasonFilter(
      'Not downloaded',
      AnimeSeasonFlags.showNotDownloaded,
      AnimeSeasonFlags.downloadedMask,
    ),
    child: const Text('Not downloaded'),
  ),
  PopupMenuItem(
    value: _SeasonFilter(
      l10n.unread,
      AnimeSeasonFlags.showUnseen,
      AnimeSeasonFlags.unseenMask,
    ),
    child: Text(l10n.unread),
  ),
  PopupMenuItem(
    value: const _SeasonFilter(
      'Watched',
      AnimeSeasonFlags.showSeen,
      AnimeSeasonFlags.unseenMask,
    ),
    child: const Text('Watched'),
  ),
  PopupMenuItem(
    value: _SeasonFilter(
      l10n.started,
      AnimeSeasonFlags.showStarted,
      AnimeSeasonFlags.startedMask,
    ),
    child: Text(l10n.started),
  ),
  PopupMenuItem(
    value: _SeasonFilter(
      l10n.not_started,
      AnimeSeasonFlags.showNotStarted,
      AnimeSeasonFlags.startedMask,
    ),
    child: Text(l10n.not_started),
  ),
  PopupMenuItem(
    value: _SeasonFilter(
      l10n.completed,
      AnimeSeasonFlags.showCompleted,
      AnimeSeasonFlags.completedMask,
    ),
    child: Text(l10n.completed),
  ),
  PopupMenuItem(
    value: const _SeasonFilter(
      'Not completed',
      AnimeSeasonFlags.showNotCompleted,
      AnimeSeasonFlags.completedMask,
    ),
    child: const Text('Not completed'),
  ),
  PopupMenuItem(
    value: _SeasonFilter(
      l10n.bookmarked,
      AnimeSeasonFlags.showBookmarked,
      AnimeSeasonFlags.bookmarkedMask,
    ),
    child: Text(l10n.bookmarked),
  ),
  PopupMenuItem(
    value: const _SeasonFilter(
      'Not bookmarked',
      AnimeSeasonFlags.showNotBookmarked,
      AnimeSeasonFlags.bookmarkedMask,
    ),
    child: const Text('Not bookmarked'),
  ),
  const PopupMenuItem(
    value: _SeasonFilter(
      'Filler marked',
      AnimeSeasonFlags.showFillermarked,
      AnimeSeasonFlags.fillermarkedMask,
    ),
    child: Text('Filler marked'),
  ),
  const PopupMenuItem(
    value: _SeasonFilter(
      'Not filler marked',
      AnimeSeasonFlags.showNotFillermarked,
      AnimeSeasonFlags.fillermarkedMask,
    ),
    child: Text('Not filler marked'),
  ),
];

class _SeasonStats {
  const _SeasonStats({
    required this.episodes,
    required this.seenCount,
    required this.downloaded,
    required this.bookmarked,
    required this.fillermarked,
    required this.latestUpload,
    required this.lastSeen,
    required this.fetchedAt,
  });

  factory _SeasonStats.from(Manga season) {
    season.chapters.loadSync();
    final episodes = season.chapters.toList(growable: false);
    final seenCount = episodes
        .where((episode) => episode.isRead == true)
        .length;
    return _SeasonStats(
      episodes: episodes,
      seenCount: seenCount,
      downloaded: episodes.any(
        (episode) =>
            episode.id != null &&
            downloadRepository.getByChapterId(episode.id!)?.isDownload == true,
      ),
      bookmarked: episodes.any((episode) => episode.isBookmarked == true),
      fillermarked: episodes.any((episode) => episode.isFiller == true),
      latestUpload: episodes.map(_chapterDate).fold(0, (a, b) => a > b ? a : b),
      lastSeen: season.lastRead ?? 0,
      fetchedAt: season.updatedAt ?? 0,
    );
  }

  final List<Chapter> episodes;
  final int seenCount;
  final bool downloaded;
  final bool bookmarked;
  final bool fillermarked;
  final int latestUpload;
  final int lastSeen;
  final int fetchedAt;

  bool get unseen => episodes.any((episode) => episode.isRead != true);
  bool get started => seenCount > 0;
  bool get completed => episodes.isNotEmpty && seenCount == episodes.length;
}

int _chapterDate(Chapter chapter) {
  final raw = chapter.dateUpload?.trim();
  if (raw == null || raw.isEmpty) return 0;
  return int.tryParse(raw) ??
      DateTime.tryParse(raw)?.millisecondsSinceEpoch ??
      0;
}

bool _matchesFilters(int flags, _SeasonStats stats) {
  bool matches(int mask, int yes, int no, bool value) {
    final selected = flags & mask;
    if (selected == yes) return value;
    if (selected == no) return !value;
    return true;
  }

  return matches(
        AnimeSeasonFlags.downloadedMask,
        AnimeSeasonFlags.showDownloaded,
        AnimeSeasonFlags.showNotDownloaded,
        stats.downloaded,
      ) &&
      matches(
        AnimeSeasonFlags.unseenMask,
        AnimeSeasonFlags.showUnseen,
        AnimeSeasonFlags.showSeen,
        stats.unseen,
      ) &&
      matches(
        AnimeSeasonFlags.startedMask,
        AnimeSeasonFlags.showStarted,
        AnimeSeasonFlags.showNotStarted,
        stats.started,
      ) &&
      matches(
        AnimeSeasonFlags.completedMask,
        AnimeSeasonFlags.showCompleted,
        AnimeSeasonFlags.showNotCompleted,
        stats.completed,
      ) &&
      matches(
        AnimeSeasonFlags.bookmarkedMask,
        AnimeSeasonFlags.showBookmarked,
        AnimeSeasonFlags.showNotBookmarked,
        stats.bookmarked,
      ) &&
      matches(
        AnimeSeasonFlags.fillermarkedMask,
        AnimeSeasonFlags.showFillermarked,
        AnimeSeasonFlags.showNotFillermarked,
        stats.fillermarked,
      );
}

int _compareSeasons(
  Manga left,
  Manga right,
  _SeasonStats leftStats,
  _SeasonStats rightStats,
  int flags,
) {
  final order = switch (AnimeSeasonFlags.sortMode(flags)) {
    AnimeSeasonFlags.sortSeasonNumber => (left.seasonNumber ?? -1).compareTo(
      right.seasonNumber ?? -1,
    ),
    AnimeSeasonFlags.sortUploadDate => leftStats.latestUpload.compareTo(
      rightStats.latestUpload,
    ),
    AnimeSeasonFlags.sortAlphabetical =>
      (left.name ?? '').toLowerCase().compareTo(
        (right.name ?? '').toLowerCase(),
      ),
    AnimeSeasonFlags.sortUnseen =>
      (leftStats.episodes.length - leftStats.seenCount).compareTo(
        rightStats.episodes.length - rightStats.seenCount,
      ),
    AnimeSeasonFlags.sortLastSeen => leftStats.lastSeen.compareTo(
      rightStats.lastSeen,
    ),
    AnimeSeasonFlags.sortFetchDate => leftStats.fetchedAt.compareTo(
      rightStats.fetchedAt,
    ),
    _ => (left.seasonSourceOrder ?? 0).compareTo(right.seasonSourceOrder ?? 0),
  };
  return AnimeSeasonFlags.isAscending(flags) ? order : -order;
}
