// Realistic local library and remote Chimahon payload for the Chimahon sync
// benchmark and its equivalence tests. Everything is synthetic: no user data,
// credentials or network access.
import 'dart:math';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';

/// Every collection the app opens, so revision capture and projection read
/// the same collections they read in the app.
const chimahonSyncBenchmarkSchemas = [
  MangaSchema,
  ChangedPartSchema,
  ChapterSchema,
  CategorySchema,
  CustomButtonSchema,
  UpdateSchema,
  HistorySchema,
  DownloadSchema,
  SourceSchema,
  SettingsSchema,
  TrackPreferenceSchema,
  TrackSchema,
  SourcePreferenceSchema,
  SourcePreferenceStringValueSchema,
  SyncPreferenceSchema,
  EpubBookProgressSchema,
];

const _sources = 12;

/// Seeds [database] with [entries] favorite manga of [chaptersPerEntry]
/// chapters each, [animeEntries] anime of 24 episodes, categories, history,
/// trackers, downloads and a few tracker-deletion markers.
void seedChimahonSyncLibrary(
  Isar database, {
  required int entries,
  required int chaptersPerEntry,
  int animeEntries = 0,
  int seed = 7,
}) {
  final random = Random(seed);
  final now = DateTime(2026).millisecondsSinceEpoch;
  database.writeTxnSync(() {
    database.settings.putSync(Settings());
    final sources = [
      for (var i = 0; i < _sources; i++)
        Source(
          id: 9000 + i,
          name: 'Source $i',
          lang: i.isEven ? 'en' : 'ja',
          isManga: i < _sources - 2,
          itemType: i < _sources - 2 ? ItemType.manga : ItemType.anime,
          additionalParams: encodeMihonSourceMetadata(
            sourceId: 700000 + i,
            packageName: 'test.extension.$i',
          ),
        )..sourceCodeLanguage = SourceCodeLanguage.mihon,
    ];
    database.sources.putAllSync(sources);
    final categories = [
      for (var i = 0; i < 4; i++)
        Category(
          name: 'Shelf $i',
          forItemType: ItemType.manga,
          pos: i,
          updatedAt: now - i * 1000,
        ),
      Category(
        name: 'Watching',
        forItemType: ItemType.anime,
        pos: 0,
        updatedAt: now,
      ),
    ];
    database.categorys.putAllSync(categories);

    final mangas = [
      for (var i = 0; i < entries; i++)
        Manga(
          source: 'Source ${i % (_sources - 2)}',
          author: 'Author ${i % 37}',
          artist: 'Artist ${i % 29}',
          genre: const ['Drama', 'Comedy'],
          imageUrl: 'https://example.invalid/cover/$i.jpg',
          lang: 'en',
          link: '/series/$i',
          name: 'Entry $i ${random.nextInt(1 << 20)}',
          status: Status.values[i % 4],
          description: 'Description of entry $i',
          sourceId: 9000 + i % (_sources - 2),
          favorite: true,
          favoriteModifiedAt:
              (now - (1 << 29) - random.nextInt(1 << 28)) ~/ 1000,
          updatedAt: now - random.nextInt(1 << 28),
          categories: [
            if (i % 4 != 3) categories[i % 4].id!,
            if (i % 7 == 0) categories[(i + 1) % 4].id!,
          ],
          dateAdded: now - random.nextInt(1 << 30),
          lastUpdate: now - random.nextInt(1 << 30),
          lastRead: now - random.nextInt(1 << 30),
        ),
      for (var i = 0; i < animeEntries; i++)
        Manga(
          source: 'Source ${_sources - 2 + i % 2}',
          author: 'Studio ${i % 11}',
          artist: '',
          genre: const ['Action'],
          imageUrl: 'https://example.invalid/anime/$i.jpg',
          lang: 'ja',
          link: '/anime/$i',
          name: 'Anime $i ${random.nextInt(1 << 20)}',
          status: Status.values[i % 4],
          description: 'Anime $i',
          sourceId: 9000 + _sources - 2 + i % 2,
          favorite: true,
          favoriteModifiedAt:
              (now - (1 << 29) - random.nextInt(1 << 28)) ~/ 1000,
          updatedAt: now - random.nextInt(1 << 28),
          itemType: ItemType.anime,
          categories: [if (i.isEven) categories.last.id!],
          dateAdded: now - random.nextInt(1 << 30),
        ),
    ];
    database.mangas.putAllSync(mangas);
    final histories = <History>[];
    final tracks = <Track>[];
    final downloads = <Download>[];
    for (final (index, manga) in mangas.indexed) {
      final anime = manga.itemType == ItemType.anime;
      final count = anime ? 24 : chaptersPerEntry;
      final read = random.nextInt(count);
      final chapters = [
        for (var c = 0; c < count; c++)
          Chapter(
            mangaId: manga.id,
            name: anime ? 'Episode ${c + 1}' : 'Chapter ${c + 1}',
            url: '${manga.link}/${anime ? 'ep' : 'ch'}-${c + 1}',
            dateUpload: '${now - (count - c) * 86400000}',
            scanlator: c.isEven ? 'Group A' : 'Group B',
            chapterNumber: c + 1.0,
            isRead: c < read,
            isBookmarked: c % 37 == 0,
            lastPageRead: c == read ? '${random.nextInt(20)}' : '',
            updatedAt: c <= read ? now - random.nextInt(1 << 28) : 0,
          )..manga.value = manga,
      ];
      database.chapters.putAllSync(chapters);
      for (final chapter in chapters) {
        chapter.manga.saveSync();
      }
      final last = chapters[read];
      histories.add(
        History(
          mangaId: manga.id,
          chapterId: last.id,
          itemType: manga.itemType,
          date: '${now - random.nextInt(1 << 28)}',
          updatedAt: now - random.nextInt(1 << 28),
          readingTimeSeconds: random.nextInt(4000),
        )..chapter.value = last,
      );
      if (index.isEven) {
        tracks.add(
          Track(
            mangaId: manga.id,
            syncId: 1 + index % 3,
            mediaId: 10000 + index,
            libraryId: 20000 + index,
            title: manga.name,
            lastChapterRead: read,
            totalChapter: count,
            score: index % 10,
            status: TrackStatus.values[index % 4],
            trackingUrl: 'https://example.invalid/track/$index',
            itemType: manga.itemType,
            updatedAt: now - random.nextInt(1 << 28),
          ),
        );
      }
      if (index % 9 == 0) {
        downloads.add(
          Download(
            id: chapters.first.id,
            succeeded: 1,
            failed: 0,
            total: 1,
            isDownload: true,
            isStartDownload: false,
          ),
        );
      }
    }
    database.historys.putAllSync(histories);
    for (final history in histories) {
      history.chapter.saveSync();
    }
    database.tracks.putAllSync(tracks);
    database.downloads.putAllSync(downloads);
  });
}

/// Edits made on another device that started from the same library: it read
/// further in a quarter of the entries, changed some categories, removed a
/// few favorites and added [newEntries] titles this device doesn't have.
/// Projecting the edited copy gives the remote payload.
void applyRemoteDeviceEdits(
  Isar database, {
  int newEntries = 40,
  int chaptersPerEntry = 150,
  int seed = 13,
}) {
  final random = Random(seed);
  final later = DateTime(2027).millisecondsSinceEpoch;
  database.writeTxnSync(() {
    final categories = database.categorys
        .filter()
        .forItemTypeEqualTo(ItemType.manga)
        .findAllSync();
    final mangas = database.mangas
        .filter()
        .itemTypeEqualTo(ItemType.manga)
        .findAllSync();
    for (final (index, manga) in mangas.indexed) {
      var changed = false;
      if (index % 4 == 0) {
        final unread = database.chapters
            .filter()
            .mangaIdEqualTo(manga.id)
            .isReadEqualTo(false)
            .limit(10)
            .findAllSync();
        for (final chapter in unread) {
          chapter
            ..isRead = true
            ..updatedAt = later + index;
        }
        database.chapters.putAllSync(unread);
        changed = true;
      }
      if (index % 11 == 0) {
        manga.categories = [categories[random.nextInt(categories.length)].id!];
        changed = true;
      }
      if (index % 53 == 0) {
        manga
          ..favorite = false
          ..favoriteModifiedAt = later ~/ 1000;
        changed = true;
      }
      if (changed) {
        manga.updatedAt = later + index;
        database.mangas.putSync(manga);
      }
    }
    final template = mangas.first;
    for (var i = 0; i < newEntries; i++) {
      final manga = Manga(
        source: template.source,
        author: 'Remote author ${i % 5}',
        artist: 'Remote artist',
        genre: const ['Mystery'],
        imageUrl: 'https://example.invalid/remote/$i.jpg',
        lang: 'en',
        link: '/remote-series/$i',
        name: 'Remote entry $i',
        status: Status.ongoing,
        description: 'Added on another device',
        sourceId: template.sourceId,
        favorite: true,
        favoriteModifiedAt: later ~/ 1000,
        updatedAt: later,
        categories: [categories[i % categories.length].id!],
        dateAdded: later,
      );
      database.mangas.putSync(manga);
      final chapters = [
        for (var c = 0; c < chaptersPerEntry; c++)
          Chapter(
            mangaId: manga.id,
            name: 'Chapter ${c + 1}',
            url: '/remote-series/$i/ch-${c + 1}',
            dateUpload: '${later - c * 86400000}',
            scanlator: 'Remote group',
            chapterNumber: c + 1.0,
            isRead: c < chaptersPerEntry ~/ 3,
            updatedAt: later,
          )..manga.value = manga,
      ];
      database.chapters.putAllSync(chapters);
      for (final chapter in chapters) {
        chapter.manga.saveSync();
      }
    }
  });
}

/// Reading progress made on this device after the other device's edits, in
/// entries the other device didn't touch.
void applyLocalDeviceEdits(Isar database) {
  final later = DateTime(2027, 2).millisecondsSinceEpoch;
  database.writeTxnSync(() {
    final mangas = database.mangas
        .filter()
        .itemTypeEqualTo(ItemType.manga)
        .findAllSync();
    for (final (index, manga) in mangas.indexed) {
      if (index % 5 != 1 || index % 11 == 0 || index % 53 == 0) continue;
      final unread = database.chapters
          .filter()
          .mangaIdEqualTo(manga.id)
          .isReadEqualTo(false)
          .limit(5)
          .findAllSync();
      for (final chapter in unread) {
        chapter
          ..isRead = true
          ..updatedAt = later + index;
      }
      database.chapters.putAllSync(unread);
      manga.updatedAt = later + index;
      database.mangas.putSync(manga);
    }
  });
}

/// Dictionary order is part of the mining projection. The benchmark has no
/// installed dictionaries.
class EmptyDictionaryStorage implements DictionaryStorage {
  @override
  Future<List<InstalledDictionary>> installed({
    Object? root,
    List<String> order = const [],
  }) async => const [];

  @override
  Future<List<InstalledDictionary>> installedReadOnly({
    Object? root,
    List<String> order = const [],
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Benchmark dictionary write');
}
