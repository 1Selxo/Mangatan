import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_novel_category_adapter.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

/// Lossless mapping between Mangatan's EPUB bookmark and Chimahon's novel
/// backup record. The four progress fields and timestamp conflict policy are
/// intentionally identical to Chimahon.
class ChimahonNovelProgressAdapter {
  const ChimahonNovelProgressAdapter();

  /// Returns Chimahon's canonical novel identity when it can be represented.
  ///
  /// A populated title or author always wins and is hashed exactly as
  /// Chimahon does. When both normalize to empty, Chimahon falls back to the
  /// book's persisted ID. A legacy Mangatan row without that retained ID has
  /// no collision-free wire identity and therefore returns `null`.
  String? stableIdOrNull({
    required String title,
    String? author,
    String? fallbackId,
  }) => ChimahonNovelIdentity.stableIdOrNull(
    title: title,
    author: author,
    fallbackId: fallbackId,
  );

  /// Resolves the identity used by local novel UI features.
  ///
  /// A persisted progress row supplies its retained Chimahon ID. Before that
  /// row exists, reader metadata is used when available; otherwise there is no
  /// safe identity and this returns `null`.
  String? stableLocalIdOrNull(
    EpubBookProgress? progress, {
    String fallbackTitle = '',
    String? fallbackAuthor,
  }) => stableIdOrNull(
    title: progress?.title ?? fallbackTitle,
    author: progress?.author ?? fallbackAuthor,
    fallbackId: progress?.chimahonId,
  );

  String stableId({
    required String title,
    String? author,
    String? fallbackId,
  }) =>
      stableIdOrNull(title: title, author: author, fallbackId: fallbackId) ??
      (throw StateError(
        'A novel with an empty title and author needs a retained Chimahon ID.',
      ));

  BackupNovel export(
    EpubBookProgress progress, {
    Iterable<String> categoryIds = const [
      ChimahonNovelCategoryAdapter.uncategorizedId,
    ],
  }) => BackupNovel(
    id: stableId(
      title: progress.title,
      author: progress.author,
      fallbackId: progress.chimahonId,
    ),
    title: progress.title,
    author: progress.author,
    lang: progress.lang,
    chapterIndex: progress.chapterIndex,
    progress: progress.progress,
    characterCount: progress.characterCount,
    lastModified: Int64(progress.lastModified ?? 0),
    categoryIds: const ChimahonNovelCategoryAdapter().normalizeIds(categoryIds),
  );

  List<BackupNovel> exportAll(
    Iterable<EpubBookProgress> progresses, {
    Map<int, List<String>> categoryIdsByMangaId = const {},
  }) {
    final exported = <BackupNovel>[];
    for (final progress in progresses) {
      if (stableLocalIdOrNull(progress) == null) continue;
      exported.add(
        export(
          progress,
          categoryIds:
              categoryIdsByMangaId[progress.mangaId] ??
              const [ChimahonNovelCategoryAdapter.uncategorizedId],
        ),
      );
    }
    return exported;
  }

  /// Returns the union of remote per-book categories for each coarser
  /// Mangatan novel parent. Missing remote books do not produce an entry, so
  /// callers can preserve the parent's existing memberships by absence.
  Map<int, List<String>> remoteCategoryIdsByMangaId({
    required Iterable<EpubBookProgress> local,
    required Iterable<BackupNovel> remote,
  }) {
    final remoteById = canonicalRemoteByStableId(remote);
    final result = <int, List<String>>{};
    for (final progress in local) {
      final localId = stableLocalIdOrNull(progress);
      if (localId == null) continue;
      final novel = remoteById[localId];
      if (novel == null) continue;
      result[progress.mangaId] = const ChimahonNovelCategoryAdapter()
          .normalizeIds([...?result[progress.mangaId], ...novel.categoryIds]);
    }
    return result;
  }

  /// Merges a restored/synced record using Chimahon's rules: bookmark fields
  /// are last-write-wins (ties stay local), while present book metadata is
  /// restored independently.
  bool applyIfNewer(EpubBookProgress local, BackupNovel remote) {
    final localId = stableLocalIdOrNull(local);
    final remoteId = _remoteStableId(remote);
    if (localId == null || remoteId == null || localId != remoteId) {
      return false;
    }
    var changed = false;
    if (local.chimahonId != remoteId) {
      // Retain the canonical value (the exact wire ID for empty metadata). It
      // becomes authoritative only if title and author later normalize empty.
      local.chimahonId = remoteId;
      changed = true;
    }
    final remoteModified = remote.lastModified.toInt();
    if (remoteModified > (local.lastModified ?? 0)) {
      local
        ..chapterIndex = remote.chapterIndex
        ..progress = remote.progress
        ..characterCount = remote.characterCount
        ..lastModified = remoteModified;
      changed = true;
    }

    // Chimahon restores present book metadata independently from the
    // last-write-wins bookmark tuple. An absent field preserves local data;
    // an explicitly present empty string remains lossless.
    if (remote.hasAuthor() && local.author != remote.author) {
      local.author = remote.author;
      changed = true;
    }
    if (remote.hasLang() && local.lang != remote.lang) {
      local.lang = remote.lang;
      changed = true;
    }
    return changed;
  }

  /// Replaces a database-only cloud placeholder from the current remote row.
  ///
  /// Empty-path placeholder rows are a cache, not local reading intent. Their
  /// timestamp therefore must not win when the user connects a different
  /// Drive account containing the same canonical book ID. Callers must limit
  /// this to an exact synthetic placeholder; real EPUB rows continue to use
  /// [applyIfNewer].
  bool applyAuthoritative(EpubBookProgress local, BackupNovel remote) {
    final localId = stableLocalIdOrNull(local);
    final remoteId = _remoteStableId(remote);
    if (localId == null || remoteId == null || localId != remoteId) {
      return false;
    }

    final remoteAuthor = remote.hasAuthor() ? remote.author : null;
    final remoteLang = remote.hasLang() ? remote.lang : null;
    final remoteModified = remote.lastModified.toInt();
    final changed =
        local.chimahonId != remoteId ||
        local.title != remote.title ||
        local.author != remoteAuthor ||
        local.lang != remoteLang ||
        local.chapterIndex != remote.chapterIndex ||
        local.progress != remote.progress ||
        local.characterCount != remote.characterCount ||
        (local.lastModified ?? 0) != remoteModified;
    if (!changed) return false;

    local
      ..chimahonId = remoteId
      ..title = remote.title
      ..author = remoteAuthor
      ..lang = remoteLang
      ..chapterIndex = remote.chapterIndex
      ..progress = remote.progress
      ..characterCount = remote.characterCount
      ..lastModified = remoteModified;
    return true;
  }

  List<EpubBookProgress> mergeIntoLocal({
    required Iterable<EpubBookProgress> local,
    required Iterable<BackupNovel> remote,
  }) {
    final remoteById = canonicalRemoteByStableId(remote);
    final changed = <EpubBookProgress>[];
    for (final progress in local) {
      final localId = stableLocalIdOrNull(progress);
      if (localId == null) continue;
      final novel = remoteById[localId];
      if (novel != null && applyIfNewer(progress, novel)) {
        changed.add(progress);
      }
    }
    return changed;
  }

  /// Canonicalizes Chimahon novel rows by the same stable identity used by
  /// import and export. Duplicate wire rows are folded without mutating the
  /// caller's protobuf objects.
  Map<String, BackupNovel> canonicalRemoteByStableId(
    Iterable<BackupNovel> remote,
  ) {
    final remoteById = <String, BackupNovel>{};
    for (final novel in remote) {
      final id = _remoteStableId(novel);
      if (id == null) continue;
      final canonical = novel.deepCopy()..id = id;
      final existing = remoteById[id];
      remoteById[id] = existing == null
          ? canonical
          : _mergeRemoteRecord(existing, canonical);
    }
    return remoteById;
  }

  String? _remoteStableId(BackupNovel novel) => stableIdOrNull(
    title: novel.title,
    author: novel.author,
    fallbackId: novel.id,
  );

  BackupNovel _mergeRemoteRecord(BackupNovel first, BackupNovel second) {
    final latest = first.lastModified >= second.lastModified ? first : second;
    final fallback = identical(latest, first) ? second : first;
    final merged = latest.deepCopy();
    if (!merged.hasLang() && fallback.hasLang()) {
      merged.lang = fallback.lang;
    }
    return merged
      ..categoryIds.clear()
      ..categoryIds.addAll(
        const ChimahonNovelCategoryAdapter().normalizeIds([
          ...first.categoryIds,
          ...second.categoryIds,
        ]),
      );
  }
}
