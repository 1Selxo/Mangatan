import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/sync/chimahon_stats_row_merge.dart';

void main() {
  group('manga statistics', () {
    test('the same day and title collapse to the larger value per field', () {
      final merged = ChimahonStatsRowMerge.mangaStats(
        [
          BackupMangaStats(
            dateKey: '2026-07-18',
            mangaId: Int64(1),
            charactersRead: 100,
            readingTime: Int64(500),
          ),
        ],
        [
          BackupMangaStats(
            dateKey: '2026-07-18',
            mangaId: Int64(1),
            charactersRead: 80,
            readingTime: Int64(900),
          ),
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.single.charactersRead, 100);
      expect(merged.single.readingTime, Int64(900));
    });

    test('distinct days and titles stay separate', () {
      final merged = ChimahonStatsRowMerge.mangaStats(
        [
          BackupMangaStats(dateKey: '2026-07-18', mangaId: Int64(1)),
          BackupMangaStats(dateKey: '2026-07-19', mangaId: Int64(1)),
        ],
        [BackupMangaStats(dateKey: '2026-07-18', mangaId: Int64(2))],
      );

      expect(merged, hasLength(3));
    });

    test('merging is idempotent', () {
      final rows = [
        BackupMangaStats(
          dateKey: '2026-07-18',
          mangaId: Int64(1),
          charactersRead: 100,
          readingTime: Int64(500),
        ),
      ];
      // Re-running a merge must not keep growing the payload or the counters;
      // sync uploads the result and merges it again next time.
      final once = ChimahonStatsRowMerge.mangaStats(rows, rows);
      final twice = ChimahonStatsRowMerge.mangaStats(once, once);

      expect(twice, hasLength(1));
      expect(twice.single.charactersRead, 100);
      expect(twice.single.readingTime, Int64(500));
    });

    test('both sides future protobuf fields survive', () {
      final local = BackupMangaStats(dateKey: '2026-07-18', mangaId: Int64(1))
        ..unknownFields.mergeLengthDelimitedField(900, [1, 2]);
      final remote = BackupMangaStats(dateKey: '2026-07-18', mangaId: Int64(1))
        ..unknownFields.mergeLengthDelimitedField(901, [3, 4]);

      final merged = ChimahonStatsRowMerge.mangaStats([local], [remote]).single;

      expect(merged.unknownFields.getField(900)!.lengthDelimited, [
        [1, 2],
      ]);
      expect(merged.unknownFields.getField(901)!.lengthDelimited, [
        [3, 4],
      ]);
    });

    test('the inputs are not mutated', () {
      final local = BackupMangaStats(
        dateKey: '2026-07-18',
        mangaId: Int64(1),
        charactersRead: 10,
      );
      ChimahonStatsRowMerge.mangaStats([local], [
        BackupMangaStats(
          dateKey: '2026-07-18',
          mangaId: Int64(1),
          charactersRead: 99,
        ),
      ]);

      expect(local.charactersRead, 10);
    });
  });

  group('Anki statistics', () {
    test('the same day, profile, and title take the larger counts', () {
      final merged = ChimahonStatsRowMerge.ankiStats(
        [
          BackupAnkiStats(
            dateKey: '2026-07-18',
            profileId: 'ja',
            mangaCards: 7,
            novelCards: 1,
          ),
        ],
        [
          BackupAnkiStats(
            dateKey: '2026-07-18',
            profileId: 'ja',
            mangaCards: 3,
            novelCards: 9,
          ),
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.single.mangaCards, 7);
      expect(merged.single.novelCards, 9);
    });

    test('different profiles stay separate', () {
      final merged = ChimahonStatsRowMerge.ankiStats(
        [BackupAnkiStats(dateKey: '2026-07-18', profileId: 'ja')],
        [BackupAnkiStats(dateKey: '2026-07-18', profileId: 'ko')],
      );

      expect(merged, hasLength(2));
    });

    test('an absent titleId does not collide with an empty one', () {
      final merged = ChimahonStatsRowMerge.ankiStats(
        [
          BackupAnkiStats(
            dateKey: '2026-07-18',
            profileId: 'ja',
            novelCards: 2,
          ),
        ],
        [
          BackupAnkiStats(
            dateKey: '2026-07-18',
            profileId: 'ja',
            novelCards: 4,
            titleId: '',
          ),
        ],
      );

      expect(merged, hasLength(2));
      expect(merged.map((row) => row.novelCards), containsAll([2, 4]));
    });

    test('merging is idempotent', () {
      final rows = [
        BackupAnkiStats(
          dateKey: '2026-07-18',
          profileId: 'ja',
          mangaCards: 5,
        ),
      ];
      final twice = ChimahonStatsRowMerge.ankiStats(
        ChimahonStatsRowMerge.ankiStats(rows, rows),
        ChimahonStatsRowMerge.ankiStats(rows, rows),
      );

      expect(twice, hasLength(1));
      expect(twice.single.mangaCards, 5);
    });
  });

  test('an empty side returns the other unchanged', () {
    final rows = [
      BackupMangaStats(
        dateKey: '2026-07-18',
        mangaId: Int64(1),
        charactersRead: 42,
      ),
    ];

    expect(ChimahonStatsRowMerge.mangaStats(rows, const []), hasLength(1));
    expect(
      ChimahonStatsRowMerge.mangaStats(const [], rows).single.charactersRead,
      42,
    );
    expect(ChimahonStatsRowMerge.mangaStats(const [], const []), isEmpty);
  });
}
