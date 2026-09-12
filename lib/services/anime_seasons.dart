import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/models/manga.dart';

bool sameAnimeSource(Manga left, Manga right) =>
    left.itemType == ItemType.anime &&
    right.itemType == ItemType.anime &&
    (left.mihonSourceId != null && right.mihonSourceId != null
        ? left.mihonSourceId == right.mihonSourceId
        : left.sourceId != null && left.sourceId == right.sourceId);

/// Includes unfavorited seasons of library series in portable backups.
List<Manga> animeSeasonLibraryClosure(Iterable<Manga> entries) {
  final all = entries.toList();
  final included = all
      .where((m) => m.favorite == true || m.favoriteModifiedAt != null)
      .toSet();
  bool changed;
  do {
    changed = false;
    for (final entry in all) {
      if (included.contains(entry) || entry.animeParentUrl == null) continue;
      if (included.any(
        (parent) =>
            parent.hasSeasons &&
            parent.link == entry.animeParentUrl &&
            sameAnimeSource(parent, entry),
      )) {
        included.add(entry);
        changed = true;
      }
    }
  } while (changed);
  return all.where(included.contains).toList();
}

/// Reuses source identities, keeping season progress and custom titles. A
/// removed season is detached, never deleted together with its downloads.
Future<List<int>> storeAnimeSeasons(
  Isar database,
  Manga parent,
  List<MManga> seasons,
) async {
  if (seasons.isEmpty) {
    throw StateError('The source returned no seasons. Try refreshing again.');
  }
  final urls = <String>{};
  for (final season in seasons) {
    if (season.link == null ||
        season.link!.isEmpty ||
        season.link == parent.link) {
      throw StateError('The source returned an invalid season relationship.');
    }
    urls.add(season.link!);
  }
  final result = <int>[];
  await database.writeTxn(() async {
    final all = (await database.mangas.where().findAll())
        .where((m) => sameAnimeSource(m, parent))
        .toList();
    final ancestors = <String>{parent.link!};
    var ancestorUrl = parent.animeParentUrl;
    while (ancestorUrl != null && ancestors.add(ancestorUrl)) {
      ancestorUrl = all
          .where((m) => m.link == ancestorUrl)
          .firstOrNull
          ?.animeParentUrl;
    }
    if (urls.any(ancestors.contains)) {
      throw StateError('The source returned a cyclic season relationship.');
    }
    for (final existing in all) {
      if (existing.animeParentUrl == parent.link &&
          !urls.contains(existing.link)) {
        existing.animeParentUrl = null;
        existing.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await database.mangas.put(existing);
      }
    }
    final seen = <String>{};
    for (final (order, detail) in seasons.indexed) {
      if (!seen.add(detail.link!)) continue;
      final matches = all.where((m) => m.link == detail.link).toList();
      if (matches.length > 1) {
        throw StateError('Multiple local entries match a season.');
      }
      final season =
          matches.firstOrNull ??
          Manga(
            source: parent.source,
            sourceId: parent.sourceId,
            mihonSourceId: parent.mihonSourceId,
            lang: parent.lang,
            link: detail.link,
            name: detail.name,
            author: detail.author,
            artist: detail.artist,
            genre: detail.genre,
            imageUrl: detail.imageUrl,
            description: detail.description,
            status: detail.status ?? Status.unknown,
            itemType: ItemType.anime,
          );
      season
        ..animeParentUrl = parent.link
        ..animeFetchType = detail.animeFetchType ?? 1
        ..seasonNumber = detail.seasonNumber ?? -1
        ..seasonSourceOrder = order
        ..backgroundUrl = detail.backgroundUrl ?? season.backgroundUrl
        ..updateSourceTitle(detail.name)
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      result.add(await database.mangas.put(season));
    }
    await database.mangas.put(parent);
  });
  return result;
}
