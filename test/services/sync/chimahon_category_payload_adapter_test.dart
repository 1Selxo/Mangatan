import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_category_payload_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:protobuf/protobuf.dart';

void main() {
  const adapter = ChimahonCategoryPayloadAdapter();

  test('exposes a typed lossless boundary for all three media types', () {
    final payload = adapter.merge(
      local: BackupMihon(
        backupCategories: [BackupCategory(name: 'Reading', order: Int64(4))],
        backupNovelCategories: [
          BackupNovelCategory(
            id: 'mangatan-name-hash',
            name: 'Study',
            order: Int64(8),
          ),
        ],
      ),
      remote: BackupMihon(
        backupCategories: [
          _withUnknown(
            BackupCategory(
              name: 'Reading',
              order: Int64(4),
              id: Int64(41),
              flags: Int64(11),
              hidden: true,
            ),
            1,
          ),
        ],
        backupAnimeCategories: [
          _withUnknown(
            BackupCategory(
              name: 'Watching',
              order: Int64(2),
              id: Int64(42),
              flags: Int64(12),
              hidden: true,
            ),
            2,
          ),
        ],
        backupNovelCategories: [
          _withUnknown(
            BackupNovelCategory(
              id: 'chimahon-uuid',
              name: ' study ',
              order: Int64(1),
              flags: Int64(13),
            ),
            3,
          ),
        ],
      ),
    );

    expect(payload.manga.single.id, Int64(41));
    expect(payload.manga.single.flags, Int64(11));
    expect(payload.manga.single.hidden, isTrue);
    expect(_unknownMarkers(payload.manga.single), [Int64(1)]);

    // A remote-only anime category survives an empty local projection.
    expect(payload.anime.single.name, 'Watching');
    expect(payload.anime.single.id, Int64(42));
    expect(payload.anime.single.flags, Int64(12));
    expect(_unknownMarkers(payload.anime.single), [Int64(2)]);

    // The remote UUID, flags, and downward reorder survive Mangatan's
    // name-derived novel projection.
    expect(payload.novel.single.id, 'chimahon-uuid');
    expect(payload.novel.single.order, Int64(1));
    expect(payload.novel.single.flags, Int64(13));
    expect(_unknownMarkers(payload.novel.single), [Int64(3)]);
  });

  test(
    'does not add fields or alter current category serialization defaults',
    () {
      final local = BackupMihon(
        backupCategories: [BackupCategory(name: 'Manga', order: Int64.ZERO)],
        backupAnimeCategories: [BackupCategory(name: 'Anime', order: Int64(1))],
        backupNovelCategories: [
          BackupNovelCategory(id: 'novel', name: 'Novel', order: Int64(2)),
        ],
      );

      final payload = adapter.merge(local: local, remote: BackupMihon());

      expect(
        payload.manga.single.writeToBuffer(),
        local.backupCategories.single.writeToBuffer(),
      );
      expect(
        payload.anime.single.writeToBuffer(),
        local.backupAnimeCategories.single.writeToBuffer(),
      );
      expect(
        payload.novel.single.writeToBuffer(),
        local.backupNovelCategories.single.writeToBuffer(),
      );
      expect(payload.manga.single.hasFlags(), isFalse);
      expect(payload.anime.single.hasFlags(), isFalse);
      expect(payload.novel.single.hasFlags(), isFalse);
    },
  );

  test('remote category tables and memberships survive a codec round trip', () {
    final remote = BackupMihon(
      backupCategories: [
        _withUnknown(
          BackupCategory(
            name: 'Reading',
            order: Int64(5),
            id: Int64(51),
            flags: Int64(21),
            hidden: true,
          ),
          11,
        ),
      ],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/manga',
          title: 'Manga',
          categories: [Int64(5)],
        ),
      ],
      backupAnimeCategories: [
        _withUnknown(
          BackupCategory(
            name: 'Watching',
            order: Int64(6),
            id: Int64(52),
            flags: Int64(22),
            hidden: true,
          ),
          12,
        ),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/anime',
          title: 'Anime',
          categories: [Int64(6)],
        ),
      ],
      backupNovelCategories: [
        _withUnknown(
          BackupNovelCategory(
            id: 'reading-uuid',
            name: 'Books',
            order: Int64(7),
            flags: Int64(23),
          ),
          13,
        ),
      ],
      backupNovels: [
        BackupNovel(
          id: 'novel-id',
          title: 'Novel',
          categoryIds: const ['reading-uuid'],
        ),
      ],
    );

    // An empty local projection is deliberately not interpreted as deletion.
    final merged = const ChimahonSyncMerger().merge(
      local: BackupMihon(),
      remote: remote,
    );
    const codec = ChimahonSyncCodec();
    final firstDecoded = codec
        .decode(
          codec.encode(merged, format: ChimahonSyncWireFormat.gzipProtobuf),
        )
        .backup;

    // Model the next export after Mangatan imported the represented fields.
    // Local database IDs and the lack of a flags field are projection gaps,
    // not requests to clear the Chimahon payload.
    final projectedAfterImport = BackupMihon(
      backupCategories: [
        BackupCategory(name: 'Reading', order: Int64(5), hidden: true),
      ],
      backupAnimeCategories: [
        BackupCategory(name: 'Watching', order: Int64(6), hidden: true),
      ],
      backupNovelCategories: [
        BackupNovelCategory(
          id: 'mangatan-name-hash',
          name: 'Books',
          order: Int64(7),
        ),
      ],
    );
    final secondMerged = const ChimahonSyncMerger().merge(
      local: projectedAfterImport,
      remote: firstDecoded,
    );
    final decoded = codec
        .decode(
          codec.encode(
            secondMerged,
            format: ChimahonSyncWireFormat.gzipProtobuf,
          ),
        )
        .backup;

    expect(decoded.backupManga.single.categories, [Int64(5)]);
    expect(decoded.backupAnime.single.categories, [Int64(6)]);
    expect(decoded.backupNovels.single.categoryIds, ['reading-uuid']);

    expect(decoded.backupCategories.single.id, Int64(51));
    expect(decoded.backupCategories.single.flags, Int64(21));
    expect(decoded.backupCategories.single.hidden, isTrue);
    expect(_unknownMarkers(decoded.backupCategories.single), [Int64(11)]);

    expect(decoded.backupAnimeCategories.single.id, Int64(52));
    expect(decoded.backupAnimeCategories.single.flags, Int64(22));
    expect(decoded.backupAnimeCategories.single.hidden, isTrue);
    expect(_unknownMarkers(decoded.backupAnimeCategories.single), [Int64(12)]);

    expect(decoded.backupNovelCategories.single.id, 'reading-uuid');
    expect(decoded.backupNovelCategories.single.flags, Int64(23));
    expect(_unknownMarkers(decoded.backupNovelCategories.single), [Int64(13)]);
  });

  test(
    'exact-name category collisions remain byte-stable on a no-edit merge',
    () {
      final remote = BackupMihon(
        backupCategories: [
          BackupCategory(
            name: 'Reading',
            order: Int64(1),
            id: Int64(51),
            flags: Int64(11),
          ),
          BackupCategory(
            name: ' reading ',
            order: Int64(2),
            id: Int64(52),
            flags: Int64(12),
          ),
        ],
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            categories: [Int64(1), Int64(2)],
            lastModifiedAt: Int64(100),
            version: Int64(7),
          ),
        ],
        backupAnimeCategories: [
          BackupCategory(
            name: 'Watching',
            order: Int64(3),
            id: Int64(61),
            flags: Int64(21),
          ),
          BackupCategory(
            name: 'watching',
            order: Int64(4),
            id: Int64(62),
            flags: Int64(22),
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            categories: [Int64(3), Int64(4)],
            lastModifiedAt: Int64(200),
            version: Int64(8),
          ),
        ],
      );
      final localProjection = BackupMihon(
        backupCategories: [
          // The importer collapses these two case/whitespace-equivalent
          // Chimahon identities onto one Mangatan category row. The second
          // restore pass leaves that row at the final remote order.
          BackupCategory(name: 'Reading', order: Int64(2)),
        ],
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            categories: [Int64(2)],
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
          ),
        ],
        backupAnimeCategories: [
          BackupCategory(name: 'Watching', order: Int64(4)),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            categories: [Int64(4)],
            lastModifiedAt: Int64(400),
            version: Int64.ZERO,
          ),
        ],
      );

      final merged = const ChimahonSyncMerger().merge(
        local: localProjection,
        remote: remote,
        remoteWinsProjectionTies: true,
      );

      expect(merged.writeToBuffer(), orderedEquals(remote.writeToBuffer()));
    },
  );

  test('remote duplicate manga and anime orders remain byte-identical', () {
    final remote = BackupMihon(
      backupCategories: [
        _withUnknown(
          BackupCategory(
            name: 'Reading',
            order: Int64(7),
            id: Int64(51),
            flags: Int64(11),
          ),
          21,
        ),
        _withUnknown(
          BackupCategory(
            name: 'Reference',
            order: Int64(7),
            id: Int64(52),
            flags: Int64(12),
          ),
          22,
        ),
      ],
      backupAnimeCategories: [
        _withUnknown(
          BackupCategory(
            name: 'Watching',
            order: Int64(9),
            id: Int64(61),
            flags: Int64(13),
          ),
          23,
        ),
        _withUnknown(
          BackupCategory(
            name: 'Rewatching',
            order: Int64(9),
            id: Int64(62),
            flags: Int64(14),
          ),
          24,
        ),
      ],
    );

    final payload = adapter.merge(local: BackupMihon(), remote: remote);

    expect(payload.manga, hasLength(remote.backupCategories.length));
    for (var index = 0; index < payload.manga.length; index++) {
      expect(
        payload.manga[index].writeToBuffer(),
        orderedEquals(remote.backupCategories[index].writeToBuffer()),
      );
    }
    expect(payload.anime, hasLength(remote.backupAnimeCategories.length));
    for (var index = 0; index < payload.anime.length; index++) {
      expect(
        payload.anime[index].writeToBuffer(),
        orderedEquals(remote.backupAnimeCategories[index].writeToBuffer()),
      );
    }
  });

  test('local-only collisions get fresh orders and remapped memberships', () {
    final remote = BackupMihon(
      backupCategories: [
        BackupCategory(name: 'Reading', order: Int64(4), id: Int64(51)),
        BackupCategory(name: 'Reference', order: Int64(4), id: Int64(52)),
      ],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/remote-manga',
          title: 'Remote manga',
          categories: [Int64(4)],
        ),
      ],
      backupAnimeCategories: [
        BackupCategory(name: 'Watching', order: Int64(6), id: Int64(61)),
        BackupCategory(name: 'Reference', order: Int64(6), id: Int64(62)),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/remote-anime',
          title: 'Remote anime',
          categories: [Int64(6)],
        ),
      ],
    );
    final local = BackupMihon(
      backupCategories: [BackupCategory(name: 'Local manga', order: Int64(4))],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/local-manga',
          title: 'Local manga',
          categories: [Int64(4)],
        ),
      ],
      backupAnimeCategories: [
        BackupCategory(name: 'Local anime', order: Int64(6)),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/local-anime',
          title: 'Local anime',
          categories: [Int64(6)],
        ),
      ],
    );

    final merged = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    final mangaOrders = {
      for (final category in merged.backupCategories)
        category.name: category.order,
    };
    final animeOrders = {
      for (final category in merged.backupAnimeCategories)
        category.name: category.order,
    };

    expect(mangaOrders['Reading'], Int64(4));
    expect(mangaOrders['Reference'], Int64(4));
    expect(mangaOrders['Local manga'], isNot(Int64(4)));
    expect(animeOrders['Watching'], Int64(6));
    expect(animeOrders['Reference'], Int64(6));
    expect(animeOrders['Local anime'], isNot(Int64(6)));
    expect(
      merged.backupManga
          .singleWhere((manga) => manga.url == '/remote-manga')
          .categories,
      [Int64(4)],
    );
    expect(
      merged.backupManga
          .singleWhere((manga) => manga.url == '/local-manga')
          .categories,
      [mangaOrders['Local manga']],
    );
    expect(
      merged.backupAnime
          .singleWhere((anime) => anime.url == '/remote-anime')
          .categories,
      [Int64(6)],
    );
    expect(
      merged.backupAnime
          .singleWhere((anime) => anime.url == '/local-anime')
          .categories,
      [animeOrders['Local anime']],
    );
  });

  test('numeric category ids stay opaque across devices', () {
    final local = BackupMihon(
      backupCategories: [
        BackupCategory(
          name: 'Local manga category',
          order: Int64(1),
          id: Int64(77),
        ),
      ],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/local-manga',
          title: 'Local manga',
          categories: [Int64(1)],
        ),
      ],
      backupAnimeCategories: [
        BackupCategory(
          name: 'Local anime category',
          order: Int64(3),
          id: Int64(88),
        ),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/local-anime',
          title: 'Local anime',
          categories: [Int64(3)],
        ),
      ],
    );
    final remote = BackupMihon(
      backupCategories: [
        BackupCategory(
          name: 'Remote manga category',
          order: Int64(2),
          id: Int64(77),
        ),
      ],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/remote-manga',
          title: 'Remote manga',
          categories: [Int64(2)],
        ),
      ],
      backupAnimeCategories: [
        BackupCategory(
          name: 'Remote anime category',
          order: Int64(4),
          id: Int64(88),
        ),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/remote-anime',
          title: 'Remote anime',
          categories: [Int64(4)],
        ),
      ],
    );

    final merged = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    final mangaOrders = {
      for (final category in merged.backupCategories)
        category.name: category.order,
    };
    final animeOrders = {
      for (final category in merged.backupAnimeCategories)
        category.name: category.order,
    };

    expect(
      merged.backupCategories.where((category) => category.id == 77),
      hasLength(2),
    );
    expect(
      merged.backupAnimeCategories.where((category) => category.id == 88),
      hasLength(2),
    );
    for (final manga in merged.backupManga) {
      final categoryName = manga.url == '/local-manga'
          ? 'Local manga category'
          : 'Remote manga category';
      expect(manga.categories, [mangaOrders[categoryName]]);
    }
    for (final anime in merged.backupAnime) {
      final categoryName = anime.url == '/local-anime'
          ? 'Local anime category'
          : 'Remote anime category';
      expect(anime.categories, [animeOrders[categoryName]]);
    }
  });
}

T _withUnknown<T extends GeneratedMessage>(T message, int marker) {
  message.unknownFields.mergeVarintField(1200, Int64(marker));
  return message;
}

List<Int64> _unknownMarkers(GeneratedMessage message) =>
    message.unknownFields.getField(1200)?.varints ?? const [];
