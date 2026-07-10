import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';

void main() {
  const merger = ChimahonSyncMerger();
  const preferenceCodec = ChimahonPreferenceCodec();

  test('merges manga chapters, categories, history, and remote settings', () {
    final local = BackupMihon(
      backupCategories: [BackupCategory(name: 'Reading', order: Int64(0))],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/same',
          title: 'Same',
          author: 'Author',
          version: Int64(2),
          categories: [Int64(0)],
          chapters: [
            BackupChapter(url: '/1', name: 'Chapter 1', version: Int64(1)),
          ],
        ),
      ],
      backupPreferences: [
        preferenceCodec.encode('pref_anki_profiles', 'local defaults'),
      ],
    );
    final remote = BackupMihon(
      backupCategories: [BackupCategory(name: 'Reading', order: Int64(3))],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/same',
          title: 'Same',
          author: 'Author',
          version: Int64(1),
          categories: [Int64(3)],
          chapters: [
            BackupChapter(url: '/2', name: 'Chapter 2', version: Int64(1)),
          ],
        ),
      ],
      backupPreferences: [
        preferenceCodec.encode('pref_anki_profiles', 'filled Chimahon fields'),
      ],
    );

    final merged = merger.merge(local: local, remote: remote);

    expect(merged.backupManga.single.version, Int64(2));
    expect(
      merged.backupManga.single.chapters.map((chapter) => chapter.name),
      containsAll(['Chapter 1', 'Chapter 2']),
    );
    expect(merged.backupCategories.single.order, Int64(3));
    expect(merged.backupManga.single.categories, [Int64(3)]);
    expect(
      preferenceCodec.decode(merged.backupPreferences.single).value,
      'filled Chimahon fields',
    );
  });

  // Adapted from Chimahon's SyncServiceTest.
  test('preserves anime categories and merges episodes', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Anime',
            version: Int64(2),
            episodes: [
              BackupEpisode(url: '/1', name: 'Episode 1', version: Int64(1)),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Anime',
            version: Int64(1),
            episodes: [
              BackupEpisode(url: '/2', name: 'Episode 2', version: Int64(1)),
            ],
          ),
        ],
      ),
    );

    expect(merged.backupAnime.single.version, Int64(2));
    expect(
      merged.backupAnime.single.episodes.map((episode) => episode.name),
      containsAll(['Episode 1', 'Episode 2']),
    );
  });

  test('merges novels and statistics without double counting', () {
    BackupNovel novel(
      int modified,
      int statModified,
      int characters, {
      List<String> categoryIds = const [],
    }) => BackupNovel(
      id: 'different-device-id-$modified',
      title: 'Novel',
      author: 'Author',
      lastModified: Int64(modified),
      categoryIds: categoryIds,
      stats: [
        BackupNovelStat(
          dateKey: '2026-07-10',
          charactersRead: characters,
          lastStatisticModified: Int64(statModified),
        ),
      ],
    );

    final merged = merger.merge(
      local: BackupMihon(
        backupNovels: [
          novel(10, 10, 100, categoryIds: ['default']),
        ],
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-07-10',
            charactersRead: 100,
            readingTime: Int64(200),
            mangaId: Int64(1),
          ),
        ],
      ),
      remote: BackupMihon(
        backupNovels: [
          novel(20, 20, 250, categoryIds: ['reading']),
        ],
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-07-10',
            charactersRead: 250,
            readingTime: Int64(180),
            mangaId: Int64(1),
          ),
        ],
      ),
    );

    expect(merged.backupNovels, hasLength(1));
    expect(merged.backupNovels.single.lastModified, Int64(20));
    expect(merged.backupNovels.single.stats.single.charactersRead, 250);
    expect(merged.backupNovels.single.categoryIds, ['reading']);
    expect(merged.backupMangaStats.single.charactersRead, 250);
    expect(merged.backupMangaStats.single.readingTime, Int64(200));
  });
}
