import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';

/// Lossless mapping between Mangatan's EPUB bookmark and Chimahon's novel
/// backup record. The four progress fields and timestamp conflict policy are
/// intentionally identical to Chimahon.
class ChimahonNovelProgressAdapter {
  const ChimahonNovelProgressAdapter();

  String stableId({required String title, String? author}) {
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedAuthor = (author ?? '').trim().toLowerCase();
    return md5
        .convert(utf8.encode('$normalizedTitle|$normalizedAuthor'))
        .toString();
  }

  BackupNovel export(EpubBookProgress progress) => BackupNovel(
    id: stableId(title: progress.title, author: progress.author),
    title: progress.title,
    author: progress.author,
    lang: progress.lang,
    chapterIndex: progress.chapterIndex,
    progress: progress.progress,
    characterCount: progress.characterCount,
    lastModified: Int64(progress.lastModified ?? 0),
  );

  List<BackupNovel> exportAll(Iterable<EpubBookProgress> progresses) => [
    for (final progress in progresses) export(progress),
  ];

  /// Merges a restored/synced record using Chimahon's rules: bookmark fields
  /// are last-write-wins (ties stay local), while present book metadata is
  /// restored independently.
  bool applyIfNewer(EpubBookProgress local, BackupNovel remote) {
    if (stableId(title: local.title, author: local.author) !=
        stableId(title: remote.title, author: remote.author)) {
      return false;
    }
    var changed = false;
    final remoteModified = remote.lastModified.toInt();
    if (remoteModified > (local.lastModified ?? 0)) {
      local
        ..chapterIndex = remote.chapterIndex
        ..progress = remote.progress
        ..characterCount = remote.characterCount
        ..lastModified = remoteModified;
      changed = true;
    }

    // Chimahon restores language as book metadata, independently from the
    // last-write-wins bookmark tuple. An absent field preserves local data;
    // an explicitly present empty string remains lossless.
    if (remote.hasLang() && local.lang != remote.lang) {
      local.lang = remote.lang;
      changed = true;
    }
    return changed;
  }

  List<EpubBookProgress> mergeIntoLocal({
    required Iterable<EpubBookProgress> local,
    required Iterable<BackupNovel> remote,
  }) {
    final remoteById = <String, BackupNovel>{};
    for (final novel in remote) {
      final id = stableId(title: novel.title, author: novel.author);
      final existing = remoteById[id];
      remoteById[id] = existing == null
          ? novel
          : _mergeRemoteRecord(existing, novel);
    }
    final changed = <EpubBookProgress>[];
    for (final progress in local) {
      final novel =
          remoteById[stableId(title: progress.title, author: progress.author)];
      if (novel != null && applyIfNewer(progress, novel)) {
        changed.add(progress);
      }
    }
    return changed;
  }

  BackupNovel _mergeRemoteRecord(BackupNovel first, BackupNovel second) {
    final latest = first.lastModified >= second.lastModified ? first : second;
    final fallback = identical(latest, first) ? second : first;
    final merged = latest.deepCopy();
    if (!merged.hasLang() && fallback.hasLang()) {
      merged.lang = fallback.lang;
    }
    return merged;
  }
}
