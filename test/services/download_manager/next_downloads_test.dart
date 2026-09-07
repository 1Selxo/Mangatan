import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/services/download_manager/next_downloads.dart';

void main() {
  test('watched filler ahead does not skip earlier unwatched episodes', () {
    final chapters = List.generate(20, (i) {
      final number = 316 + i;
      return Chapter(
        id: number,
        mangaId: 1,
        name: 'Episode $number',
        isRead: number <= 320 || (number >= 326 && number <= 331),
      );
    });
    expect(
      selectNextDownloads(chapters, count: 10, downloads: []).map((c) => c.id),
      [321, 322, 323, 324, 325, 332, 333, 334, 335],
    );
  });
  List<Chapter> episodes({int watched = 0}) => List.generate(
    25,
    (i) => Chapter(
      id: i + 1,
      mangaId: 1,
      name: 'Episode ${i + 1}',
      isRead: i < watched,
    ),
  );
  Download queued(int id, {bool completed = false, bool failed = false}) =>
      Download(
        id: id,
        succeeded: 0,
        failed: failed ? 1 : 0,
        total: 100,
        isDownload: completed,
        isStartDownload: !failed,
      );

  test('next 5 on an unwatched series starts at episode 1 and fills batch', () {
    expect(
      selectNextDownloads(episodes(), count: 5, downloads: []).map((c) => c.id),
      [1, 2, 3, 4, 5],
    );
  });
  test('repeated next 5 advances past queued and completed episodes', () {
    expect(
      selectNextDownloads(
        episodes(watched: 5),
        count: 5,
        downloads: [
          for (var i = 6; i <= 10; i++) queued(i),
          queued(11, completed: true),
        ],
      ).map((c) => c.id),
      [12, 13, 14, 15, 16],
    );
  });
  test('failed downloads are retryable and end of series is bounded', () {
    expect(
      selectNextDownloads(
        episodes(watched: 23),
        count: 25,
        downloads: [queued(24, failed: true)],
      ).map((c) => c.id),
      [24, 25],
    );
    expect(selectNextDownloads([], count: 5, downloads: []), isEmpty);
    expect(
      selectNextDownloads(episodes(watched: 25), count: 5, downloads: []),
      isEmpty,
    );
  });
}
