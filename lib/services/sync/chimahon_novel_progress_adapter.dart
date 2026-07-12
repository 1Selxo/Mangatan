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
    chapterIndex: progress.chapterIndex,
    progress: progress.progress,
    characterCount: progress.characterCount,
    lastModified: Int64(progress.lastModified ?? 0),
  );

  List<BackupNovel> exportAll(Iterable<EpubBookProgress> progresses) => [
    for (final progress in progresses) export(progress),
  ];

  /// Applies a restored/synced bookmark only when Chimahon's whole-record
  /// last-write-wins rule selects it. Equal timestamps keep the local value.
  bool applyIfNewer(EpubBookProgress local, BackupNovel remote) {
    if (stableId(title: local.title, author: local.author) !=
        stableId(title: remote.title, author: remote.author)) {
      return false;
    }
    final remoteModified = remote.lastModified.toInt();
    if (remoteModified <= (local.lastModified ?? 0)) return false;
    local
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
    final remoteById = {
      for (final novel in remote)
        stableId(title: novel.title, author: novel.author): novel,
    };
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
}
