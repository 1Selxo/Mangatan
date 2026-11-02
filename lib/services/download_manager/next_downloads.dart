import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';

/// Input is reading order, never the reversible display order. Fill the batch
/// with new episodes, not entries already downloaded or waiting in the queue.
List<Chapter> selectNextDownloads(
  List<Chapter> chapters, {
  required int count,
  required Iterable<Download> downloads,
}) {
  if (count <= 0) return [];
  final unavailable = downloads
      .where((d) => d.isDownload == true || d.isStartDownload == true)
      .map((d) => d.id)
      .toSet();
  return chapters
      .where((c) => c.isRead != true && !unavailable.contains(c.id))
      .take(count)
      .toList();
}

/// The chapters to download ahead while [current] is read: the next [count]
/// unread chapters after it in [readingOrder], not already downloaded or
/// queued. Nothing when [current] itself is not downloaded: reading a chapter
/// online says nothing about wanting the next ones offline.
List<Chapter> selectDownloadAhead(
  List<Chapter> readingOrder,
  Chapter current, {
  required int count,
  required Iterable<Download> downloads,
}) {
  if (count <= 0) return [];
  final currentDownloaded = downloads.any(
    (download) => download.id == current.id && download.isDownload == true,
  );
  if (!currentDownloaded) return [];
  final index = readingOrder.indexWhere((c) => c.id == current.id);
  if (index < 0) return [];
  return selectNextDownloads(
    readingOrder.sublist(index + 1),
    count: count,
    downloads: downloads,
  );
}
