import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/detail/manga_detail_main.dart';
import 'package:mangayomi/services/anime_seasons.dart';
import 'package:mangayomi/models/chapter.dart';
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
      final flags = (current ?? anime).seasonFlags ?? 1;
      seasons.sort((a, b) {
        final order = switch (flags & 0xe000) {
          0x2000 => (a.seasonNumber ?? -1).compareTo(b.seasonNumber ?? -1),
          0x6000 => (a.name ?? '').toLowerCase().compareTo(
            (b.name ?? '').toLowerCase(),
          ),
          _ => (a.seasonSourceOrder ?? 0).compareTo(b.seasonSourceOrder ?? 0),
        };
        return flags & 1 == 1 ? order : -order;
      });
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
                      flags & 1 == 1
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: () => _setFlags(flags ^ 1),
                  ),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.sort),
                    onSelected: (sort) => _setFlags((flags & ~0xe000) | sort),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 0, child: Text(l10n.by_source)),
                      PopupMenuItem(
                        value: 0x2000,
                        child: Text(l10n.season_number),
                      ),
                      PopupMenuItem(
                        value: 0x6000,
                        child: Text(l10n.alphabetically),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          for (final season in seasons)
            StreamBuilder<void>(
              stream: isar.chapters.watchLazy(),
              builder: (context, _) {
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
              },
            ),
        ],
      );
    },
  );

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
