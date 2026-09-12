import 'package:mangayomi/models/manga.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';

/// Resolves only explicit, unique IDs within one backup. Missing IDs in older
/// backups are not zero-valued parents, and a cross-source link is invalid.
Map<BackupAnime, BackupAnime> chimahonSeasonParents(
  Iterable<BackupAnime> entries,
) {
  final all = entries.toList();
  final byId = <Int64, List<BackupAnime>>{};
  for (final anime in all) {
    if (anime.hasId() && anime.id > Int64.ZERO) {
      byId.putIfAbsent(anime.id, () => []).add(anime);
    }
  }
  final parents = <BackupAnime, BackupAnime>{};
  for (final anime in all) {
    if (!anime.hasParentId()) continue;
    final matches = byId[anime.parentId];
    if (matches?.length != 1) continue;
    final parent = matches!.single;
    if (parent == anime ||
        parent.source != anime.source ||
        parent.url == anime.url ||
        !parent.hasFetchType() ||
        parent.fetchType != 0) {
      continue;
    }
    parents[anime] = parent;
  }
  // Reject cycles before either importing or reassigning IDs.
  final cyclic = <BackupAnime>{};
  for (final anime in parents.keys) {
    final seen = <BackupAnime>{anime};
    var parent = parents[anime];
    while (parent != null) {
      if (!seen.add(parent)) {
        cyclic.add(anime);
        break;
      }
      parent = parents[parent];
    }
  }
  parents.removeWhere((anime, _) => cyclic.contains(anime));
  return parents;
}

/// Put a local projection in the remote backup's ID namespace before merging.
/// IDs are relationship handles only; source + URL identifies an anime here.
List<BackupAnime> rebaseChimahonSeasonIds(
  Iterable<BackupAnime> local,
  Iterable<BackupAnime> remote,
) {
  final left = local.toList();
  final right = remote.toList();
  final parents = chimahonSeasonParents(left);
  final used = right.where((a) => a.hasId()).map((a) => a.id).toSet();
  final ids = <BackupAnime, Int64>{};
  var next = Int64.ONE;
  for (final anime in left) {
    if (!anime.hasId()) continue;
    final matches = right
        .where(
          (r) =>
              r.source == anime.source &&
              r.url == anime.url &&
              r.title.trim().toLowerCase() ==
                  anime.title.trim().toLowerCase() &&
              r.hasAuthor() == anime.hasAuthor() &&
              r.author.trim().toLowerCase() ==
                  anime.author.trim().toLowerCase(),
        )
        .toList();
    final ownMatches = left.where(
      (r) => r.source == anime.source && r.url == anime.url,
    );
    if (matches.length == 1 &&
        ownMatches.length == 1 &&
        matches.single.hasId()) {
      ids[anime] = matches.single.id;
    } else {
      while (used.contains(next)) {
        next += Int64.ONE;
      }
      ids[anime] = next;
      used.add(next);
      next += Int64.ONE;
    }
  }
  return left.map((anime) {
    final result = anime.deepCopy();
    if (ids[anime] case final id?) result.id = id;
    if (anime.hasParentId()) {
      final parentId = ids[parents[anime]];
      if (parentId != null) {
        result.parentId = parentId;
      } else {
        result.clearParentId();
      }
    }
    return result;
  }).toList();
}

/// A source refresh knows the fetch type but may not supply display flags or
/// background art. An older client knows none of these fields. Fill only these
/// representation gaps; a known parent's absent parentId is an explicit detach.
void retainAnimeSeasonProjectionGaps(
  BackupAnime selected,
  BackupAnime local,
  BackupAnime remote,
) {
  if (!local.hasFetchType() || !local.hasId()) return;
  if (!remote.hasFetchType()) {
    for (final tag in [500, 502, 503, 504, 505, 506, 507]) {
      if (local.hasField(tag)) selected.setField(tag, local.getField(tag));
    }
  }
  for (final tag in [500, 504, 505, 506]) {
    if (!selected.hasField(tag) && remote.hasField(tag)) {
      selected.setField(tag, remote.getField(tag));
    }
  }
}

bool animeSeasonProjectionEquals(BackupAnime local, BackupAnime remote) =>
    !local.hasFetchType() ||
    !local.hasId() ||
    ([500, 502, 503, 504, 505, 506, 507].every(
          (tag) =>
              !local.hasField(tag) ||
              (remote.hasField(tag) &&
                  local.getField(tag) == remote.getField(tag)),
        ) &&
        local.hasParentId() == remote.hasParentId());

/// Shared by manual restore and incremental sync. Field presence distinguishes
/// older clients from an explicit update or detach by a season-aware client.
void applyChimahonAnimeSeasons(
  Manga local,
  BackupAnime remote,
  BackupAnime? parent,
) {
  if (remote.hasFetchType()) local.animeFetchType = remote.fetchType;
  if (remote.hasSeasonNumber()) local.seasonNumber = remote.seasonNumber;
  if (remote.hasSeasonSourceOrder()) {
    local.seasonSourceOrder = remote.seasonSourceOrder.toInt();
  }
  if (remote.hasSeasonFlags()) local.seasonFlags = remote.seasonFlags.toInt();
  if (remote.hasBackgroundUrl()) local.backgroundUrl = remote.backgroundUrl;
  if (remote.hasId() || remote.hasParentId() || remote.hasFetchType()) {
    local.animeParentUrl = parent?.url;
  }
}
