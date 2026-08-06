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
    if (withLocalData.length > 1 || source.localId == null) return null;
    final installed = candidates
        .where((manga) => manga.sourceId == source.localId)
        .toList(growable: false);
    return installed.length == 1 ? installed.single : null;
  }

  String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
}
