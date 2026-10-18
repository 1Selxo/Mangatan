import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/services/sync/mihon_backup_source_resolver.dart';

/// Conservative matcher for Chimahon media identity.
///
/// Native IDs and source-local IDs are identity. Human-facing source labels
/// are intentionally absent because factory extensions can rename children.
class ChimahonPortableTitleMatcher {
  const ChimahonPortableTitleMatcher();

  String identityKey(Manga manga) => [
    manga.itemType.index,
    manga.mihonSourceId ?? '',
    manga.link ?? '',
    _normalize(manga.sourceTitle ?? manga.name),
    _normalize(manga.author),
  ].join('\u0000');

  Manga? find({
    required Iterable<Manga> localMangas,
    required ItemType itemType,
    required ResolvedMihonBackupSource source,
    required String url,
    required String sourceTitle,
    required String? author,
    required bool allowSourceUrlFallback,
  }) {
    final candidates = localMangas
        .where(
          (manga) =>
              manga.itemType == itemType && !(manga.isLocalArchive ?? false),
        )
        .toList(growable: false);
    bool sourceMatches(Manga manga) {
      if (manga.mihonSourceId == source.portableId) return true;
      return source.localId != null &&
          manga.mihonSourceId == null &&
          manga.sourceId == source.localId;
    }

    if (url.isNotEmpty) {
      final matchingUrl = candidates
          .where((manga) => manga.link == url && sourceMatches(manga))
          .toList(growable: false);
      final exact = matchingUrl
          .where(
            (manga) =>
                _normalize(manga.sourceTitle ?? manga.name) ==
                    _normalize(sourceTitle) &&
                _normalize(manga.author) == _normalize(author),
          )
          .toList(growable: false);
      final selectedExact = _select(exact, source);
      if (selectedExact != null) return selectedExact;
      if (allowSourceUrlFallback && matchingUrl.length == 1) {
        return matchingUrl.single;
      }
      if (!allowSourceUrlFallback) return null;
      final legacyExact = candidates
          .where(
            (manga) =>
                manga.mihonSourceId == null &&
                (manga.sourceId == null || manga.sourceId == source.localId) &&
                manga.link == url &&
                _normalize(manga.sourceTitle ?? manga.name) ==
                    _normalize(sourceTitle) &&
                _normalize(manga.author) == _normalize(author),
          )
          .toList(growable: false);
      return _select(legacyExact, source);
    }

    final exact = candidates
        .where(
          (manga) =>
              sourceMatches(manga) &&
              (manga.sourceTitle == sourceTitle || manga.name == sourceTitle) &&
              _normalize(manga.author) == _normalize(author),
        )
        .toList(growable: false);
    return _select(exact, source);
  }

  Manga? _select(List<Manga> candidates, ResolvedMihonBackupSource source) {
    if (candidates.length == 1) return candidates.single;
    if (candidates.isEmpty) return null;
    final withLocalData = candidates
        .where((manga) => manga.hasLocalChapterOverlay ?? false)
        .toList(growable: false);
    if (withLocalData.length == 1) return withLocalData.single;
    if (withLocalData.length > 1) return null;
    // Without device-local files the rows are interchangeable source cache, so
    // pick one deterministically. Returning null would add yet another
    // duplicate on every sync. Prefer the library row, which is the one the
    // exporter sends, over a row left behind by browsing the source.
    final ranked = candidates.toList()
      ..sort((left, right) {
        final byFavorite = _rank(left.favorite == true, right.favorite == true);
        if (byFavorite != 0) return byFavorite;
        final byInstalled = _rank(
          source.localId != null && left.sourceId == source.localId,
          source.localId != null && right.sourceId == source.localId,
        );
        if (byInstalled != 0) return byInstalled;
        return (left.id ?? 0).compareTo(right.id ?? 0);
      });
    return ranked.first;
  }

  int _rank(bool left, bool right) => left == right ? 0 : (left ? -1 : 1);

  String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
}
