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
