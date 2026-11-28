import 'dart:async';
import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/repositories/db.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';
import 'package:mangayomi/repositories/chapter_consolidation.dart';

class DownloadRepository {
  Future<List<int>> getAllIds() =>
      isar.downloads.where().idProperty().findAll();

  List<Download> getAll() =>
      isar.downloads.filter().idIsNotNull().findAllSync();

  /// The download whose id is [chapterId] (download ids equal chapter ids).
  /// A primary-key lookup: the same row a filter on `id` finds, without
  /// scanning every download. Stored rows always have an id, so a null
  /// [chapterId] matches nothing.
  Download? getByChapterId(int? chapterId) =>
      chapterId == null ? null : isar.downloads.getSync(chapterId);

  Download? getById(int id) => isar.downloads.getSync(id);

  /// Watches the download whose id is [chapterId]: its current state, then
  /// again whenever a download changes. A null [chapterId] matches no row.
  ///
  /// Every chapter row of a series and of Updates watches its download. A
  /// database watch each made scrolling a long chapter list register and
  /// drop native watchers for every row going by; all rows now share one
  /// watch of the downloads table and read their own row by primary key.
  Stream<List<Download>> watchByChapterId(int? chapterId) {
    List<Download> current() {
      final download = getByChapterId(chapterId);
      return download == null ? const [] : [download];
    }

    if (chapterId == null) return Stream.value(const []);
    return Stream.multi((listener) {
      var last = current();
      listener.add(last);
      final changes = _downloadChanges().listen((_) {
        final now = current();
        // Only this row's changes, not every other download's.
        if (_sameState(now, last)) return;
        last = now;
        listener.add(now);
      });
      listener.onCancel = changes.cancel;
    });
  }

  static bool _sameState(List<Download> a, List<Download> b) =>
      a.length == b.length &&
      (a.isEmpty ||
          jsonEncode(a.first.toJson()) == jsonEncode(b.first.toJson()));

  Stream<void>? _changes;
  Isar? _changesDatabase;

  /// One lazy watch of the downloads table for every listener, started by
  /// the first and stopped after the last.
  Stream<void> _downloadChanges() {
    final changes = _changes;
    if (changes != null && identical(_changesDatabase, isar)) return changes;
    _changesDatabase = isar;
    return _changes = isar.downloads.watchLazy().asBroadcastStream(
      onCancel: (subscription) {
        subscription.cancel();
        _changes = null;
      },
    );
  }

  List<int> getDownloadedIdsAmong(List<int> chapterIds) => isar.downloads
      .where()
      .anyOf(chapterIds, (q, id) => q.idEqualTo(id))
      .filter()
      .isDownloadEqualTo(true)
      .findAllSync()
      .map((d) => d.id!)
      .toList();

  Future<int> countDownloadedByFavoriteItemType(ItemType itemType) => isar
      .downloads
      .filter()
      .chapter(
        (q) =>
            q.manga((m) => m.favoriteEqualTo(true).itemTypeEqualTo(itemType)),
      )
      .isDownloadEqualTo(true)
      .count();

  Stream<List<Download>> watchDownloaded() => isar.downloads
      .where()
      .isDownloadEqualTo(true)
      .watch(fireImmediately: true);

  Stream<List<Download>> watchPendingStarted() => isar.downloads
      .filter()
      .idIsNotNull()
      .isDownloadEqualTo(false)
      .isStartDownloadEqualTo(true)
      .watch(fireImmediately: true);

  Stream<List<Download>> watchPending() => isar.downloads
      .filter()
      .idIsNotNull()
      .isDownloadEqualTo(false)
      .watch(fireImmediately: true);

  Future<List<Download>> getPendingStarted() => isar.downloads
      .filter()
      .idIsNotNull()
      .isDownloadEqualTo(false)
      .isStartDownloadEqualTo(true)
      .findAll();

  // No updatedAt stamping - Download has no such field.
  /// Atomically appends a chapter to the queue. Repeated requests preserve
  /// completed and active entries, while failed entries become retryable.
  /// Resolves to the stored chapter queued (an alias resolved to the chapter
  /// it was merged into), or null when it no longer exists.
  Future<Chapter?> enqueue(Chapter chapter) =>
      dbWriteQueue.run(() => isar.writeTxnSync(() => _enqueueSync(chapter)));

  /// Queues [chapters] in order, with the same result as awaiting [enqueue]
  /// for each of them in turn: the same download rows, links and saved queue
  /// order.
  ///
  /// Every chapter is queued in one write transaction instead of one each, so
  /// a "download all" of hundreds of chapters commits once. If that
  /// transaction fails it is rolled back and the chapters are queued one by
  /// one exactly as before, so a failure leaves the same partial queue and
  /// raises the same error.
  Future<void> enqueueAll(Iterable<Chapter> chapters) async {
    final list = chapters.toList();
    if (list.isEmpty) return;
    try {
      await dbWriteQueue.run(
        () => isar.writeTxnSync(() {
          for (final chapter in list) {
            _enqueueSync(chapter);
          }
        }),
      );
    } catch (_) {
      for (final chapter in list) {
        await enqueue(chapter);
      }
    }
  }

  /// [enqueue]'s body. Must run inside a write transaction.
  Chapter? _enqueueSync(Chapter chapter) {
    final current =
        isar.chapters.getSync(chapter.id!) ??
        isar.chapters.getSync(resolveChapterAlias(isar, chapter.id!));
    if (current == null || current.mangaId != chapter.mangaId) return null;
    chapter = current;
    final existing = isar.downloads.getSync(chapter.id!);
    if (existing?.isDownload == true || existing?.isStartDownload == true) {
      return chapter;
    }
    final download =
        existing ??
        Download(
          id: chapter.id,
          total: 100,
          succeeded: 0,
          failed: 0,
          isDownload: false,
          isStartDownload: true,
        );
    download
      ..succeeded = 0
      ..failed = 0
      ..total = 100
      ..isDownload = false
      ..isStartDownload = true
      ..chapter.value = chapter;
    isar.downloads.putSync(download);
    download.chapter.saveSync();
    // Chapter IDs follow source insertion order, often newest first. Persist
    // arrival order in the same transaction so queue readers cannot reverse
    // a "Next X" batch by sorting its database IDs.
    final settings = isar.settings.getSync(227) ?? Settings();
    final order = [...?settings.downloadQueueOrder];
    // Membership checks go through a set; [order] keeps the sequence.
    final known = order.toSet();
    // Existing queues from older builds have no saved order. Keep them ahead
    // of newly added episodes instead of promoting the new batch over them.
    // Only the ids are read, in the same id order as the full rows.
    for (final pendingId
        in isar.downloads
            .filter()
            .isDownloadEqualTo(false)
            .isStartDownloadEqualTo(true)
            .idProperty()
            .findAllSync()) {
      if (pendingId != chapter.id && known.add(pendingId)) {
        order.add(pendingId);
      }
    }
    if (known.add(chapter.id!)) {
      order.add(chapter.id!);
      settings.downloadQueueOrder = order;
      settings.updatedAt = DateTime.now().millisecondsSinceEpoch;
      isar.settings.putSync(settings);
    }
    return chapter;
  }

  Future<void> save(Download download) => dbWriteQueue.run(
    () => isar.writeTxnSync(() => isar.downloads.putSync(download)),
  );

  Future<void> delete(int id) => dbWriteQueue.run(
    () => isar.writeTxnSync(() => isar.downloads.deleteSync(id)),
  );

  Future<void> deleteAll(List<int> ids) => dbWriteQueue.run(() {
    isar.writeTxnSync(() {
      for (final id in ids) {
        isar.downloads.deleteSync(id);
      }
    });
  });

  // Escape hatch for download-rooted read transactions too specific to name.
  Future<T> transaction<T>(T Function() body) =>
      dbWriteQueue.run(() => isar.txnSync(body));

  // Sync primitives below are for callers already inside a write transaction
  // opened by another repository's transaction()/writeTransaction() (e.g.
  // restoreRepository) — they don't queue on their own.
  void putAllSync(List<Download> downloads) =>
      isar.downloads.putAllSync(downloads);

  void clearSync() => isar.downloads.clearSync();
}

final downloadRepository = DownloadRepository();
