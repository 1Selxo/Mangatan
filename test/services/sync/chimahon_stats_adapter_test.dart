import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/statistics/immersion_stats_models.dart';
import 'package:mangayomi/services/sync/chimahon_stats_adapter.dart';

void main() {
  const adapter = ChimahonStatsAdapter();

  group('manga statistics', () {
    test('round-trips every field', () {
      const entry = MangaStatsEntry(
        dateKey: '2026-07-18',
        charactersRead: 1234,
        readingTimeMs: 567890,
        mangaId: 42,
      );

      expect(adapter.importMangaStats(adapter.exportMangaStats(entry)), entry);
    });

    test('reading time crosses the wire in milliseconds', () {
      const entry = MangaStatsEntry(
        dateKey: '2026-07-18',
        readingTimeMs: 567890,
      );
      expect(adapter.exportMangaStats(entry).readingTime, Int64(567890));
    });

    test('a row without a date key is dropped in both directions', () {
      expect(
        adapter.exportAllMangaStats([
          const MangaStatsEntry(dateKey: '', charactersRead: 1),
          const MangaStatsEntry(dateKey: '2026-07-18', charactersRead: 2),
        ]),
        hasLength(1),
      );
      expect(
        adapter.importAllMangaStats([
          BackupMangaStats(dateKey: '', charactersRead: 1),
          BackupMangaStats(dateKey: '2026-07-18', charactersRead: 2),
        ]),
        hasLength(1),
      );
    });
  });

  group('Anki statistics', () {
    test('round-trips every field', () {
      const entry = AnkiStatsEntry(
        dateKey: '2026-07-18',
        mangaCards: 7,
        novelCards: 3,
        profileId: 'ja',
        titleId: 'book-id',
      );

      expect(adapter.importAnkiStats(adapter.exportAnkiStats(entry)), entry);
    });

    test('a null titleId stays absent on the wire', () {
      const entry = AnkiStatsEntry(dateKey: '2026-07-18', profileId: 'ja');
      final wire = adapter.exportAnkiStats(entry);

      expect(wire.hasTitleId(), isFalse);
      expect(adapter.importAnkiStats(wire).titleId, isNull);
    });

    test('an empty titleId stays present and distinct from absent', () {
      const entry = AnkiStatsEntry(
        dateKey: '2026-07-18',
        profileId: 'ja',
        titleId: '',
      );
      final wire = adapter.exportAnkiStats(entry);

      expect(wire.hasTitleId(), isTrue);
      expect(adapter.importAnkiStats(wire).titleId, '');
    });
  });

  group('novel statistics', () {
    test('round-trips every field including derived speeds', () {
      const entry = NovelStatsEntry(
        dateKey: '2026-07-18',
        charactersRead: 4321,
        readingTimeSeconds: 987.5,
        minReadingSpeed: 1000,
        altMinReadingSpeed: 1200,
        lastReadingSpeed: 15750,
        maxReadingSpeed: 30000,
        lastStatisticModified: 1784000000000,
      );

      expect(adapter.importNovelStats(adapter.exportNovelStats(entry)), entry);
    });

    test('reading time crosses the wire in fractional seconds', () {
      const entry = NovelStatsEntry(
        dateKey: '2026-07-18',
        readingTimeSeconds: 987.5,
      );
      // Chimahon's novel stats are a double in seconds, unlike manga's integer
      // milliseconds; rounding here would lose sub-second reading.
      expect(adapter.exportNovelStats(entry).readingTime, 987.5);
    });

    test('a row without a date key is dropped in both directions', () {
      expect(
        adapter.exportAllNovelStats([
          const NovelStatsEntry(dateKey: '', charactersRead: 1),
          const NovelStatsEntry(dateKey: '2026-07-18', charactersRead: 2),
        ]),
        hasLength(1),
      );
      expect(
        adapter.importAllNovelStats([
          BackupNovelStat(dateKey: '', charactersRead: 1),
          BackupNovelStat(dateKey: '2026-07-18', charactersRead: 2),
        ]),
        hasLength(1),
      );
    });
  });
}
