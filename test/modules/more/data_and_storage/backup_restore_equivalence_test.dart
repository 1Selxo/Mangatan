// Checks that the faster backup and restore code produces exactly what the
// previous code did. The previous code is kept verbatim in
// legacy_backup_restore.dart; both run on identical databases and every
// table (with its links) is compared afterwards.
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/backup.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/backup_decoder.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/backup_format.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/restore.dart';
import 'package:mangayomi/router/router.dart';

import '../../../test_utils/isar_library.dart';
import 'legacy_backup_restore.dart';

const _schemas = [
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
];

class _QuietRouterLocation extends RouterCurrentLocationState {
  @override
  String? build() => null;

  @override
  void refresh() {}
}

const _now = 1767225600000;

/// A small library with the cases the restore code has to get right:
/// duplicate chapter names in one entry, chapters without a name or URL,
/// orphaned chapters, downloads, history and updates that point nowhere,
/// browsed entries, an anime season reachable only through its parent, and
/// same-named categories for different item types.
void _seed() {
  isar.writeTxnSync(() {
    isar.categorys.putAllSync([
      Category(name: 'Reading', forItemType: ItemType.manga, pos: 0),
      Category(name: 'Later', forItemType: ItemType.manga, pos: 1),
      Category(name: 'Reading', forItemType: ItemType.anime, pos: 0),
      Category(name: 'Seasonal', forItemType: ItemType.anime, pos: 1),
    ]);
    isar.sources.putAllSync([
      for (var i = 0; i < 6; i++)
        Source(
          id: 500 + i,
          name: 'Source $i',
          lang: 'en',
          isAdded: i != 5,
          itemType: i < 3 ? ItemType.manga : ItemType.anime,
        ),
    ]);
    final entries = <Manga>[];
    for (var i = 0; i < 24; i++) {
      final anime = i >= 16 && i < 21;
      final browsed = i >= 21;
      entries.add(
        Manga(
          source: 'Source ${anime ? 3 + i % 3 : i % 3}',
          author: 'A$i',
          artist: 'B$i',
          genre: ['g${i % 4}'],
          imageUrl: 'img$i',
          lang: 'en',
          link: '/e/$i',
          name: 'Entry $i',
          status: Status.values[i % Status.values.length],
          description: 'd$i',
          sourceId: 500 + (anime ? 3 + i % 3 : i % 3),
          favorite: !browsed,
          itemType: anime ? ItemType.anime : ItemType.manga,
          categories: anime ? [3 + i % 2] : [if (i % 3 != 0) 1 + i % 2],
          dateAdded: _now - i * 1000,
          lastRead: _now - i * 3000,
          lastUpdate: _now - i * 2000,
        ),
      );
    }
    // An anime season with seasons, and a season of it that isn't a
    // favorite: the backup includes it through its parent.
    entries[16].animeFetchType = 0;
    entries.add(
      Manga(
        source: entries[16].source,
        author: '',
        artist: '',
        genre: const [],
        imageUrl: '',
        lang: 'en',
        link: '/e/16/s2',
        name: 'Entry 16 S2',
        status: Status.ongoing,
        description: '',
        sourceId: entries[16].sourceId,
        itemType: ItemType.anime,
        animeParentUrl: '/e/16',
        animeFetchType: 1,
      ),
    );
    isar.mangas.putAllSync(entries);
    for (final manga in entries) {
      final chapters = [
        for (var c = 0; c < 12; c++)
          Chapter(
            mangaId: manga.id,
            // Two chapters named "Chapter 3"; one chapter without a name.
            name: c == 7 ? 'Chapter 3' : (c == 9 ? null : 'Chapter $c'),
            url: c == 10 ? null : '${manga.link}/c$c',
            dateUpload: '${_now - c * 86400000}',
            scanlator: c.isEven ? 'G1' : 'G2',
            isRead: c < manga.id! % 12,
            isBookmarked: c == 4,
          )..manga.value = manga,
      ];
      isar.chapters.putAllSync(chapters);
      if (manga.favorite != true) continue;
      for (final chapter in chapters.take(3)) {
        isar.historys.putSync(
          History(
            mangaId: manga.id,
            chapterId: chapter.id,
            itemType: manga.itemType,
            date: '${_now - chapter.id!}',
          )..chapter.value = chapter,
        );
      }
      // Updates for both "Chapter 3"s, the nameless chapter and a chapter
      // that no longer exists.
      for (final name in ['Chapter 3', 'Chapter 3', null, 'Chapter 11', 'X']) {
        isar.updates.putSync(
          Update(
            mangaId: manga.id,
            chapterName: name,
            date: '${_now - manga.id!}',
          ),
        );
      }
      if (manga.id!.isEven) {
        isar.tracks.putSync(
          Track(
            mangaId: manga.id,
            syncId: 1,
            title: manga.name,
            status: TrackStatus.reading,
            itemType: manga.itemType,
          ),
        );
      }
    }
    // Chapters whose entry is gone.
    isar.chapters.putAllSync([
      for (var c = 0; c < 3; c++)
        Chapter(mangaId: 9999, name: 'Orphan $c', url: '/orphan/$c'),
    ]);
    final chapterIds = isar.chapters.where().idProperty().findAllSync();
    isar.downloads.putAllSync([
      for (final id in chapterIds)
        if (id % 5 == 0)
          Download(
            id: id,
            succeeded: 1,
            failed: 0,
            total: 1,
            isDownload: true,
            isStartDownload: false,
          ),
      Download(
        id: 777777,
        succeeded: 0,
        failed: 0,
        total: 1,
        isDownload: false,
        isStartDownload: false,
      ),
    ]);
    isar.historys.putSync(
      History(
        mangaId: 1,
        chapterId: 888888,
        itemType: ItemType.manga,
        date: '0',
      ),
    );
    isar.trackPreferences.putSync(TrackPreference(syncId: 1, username: 'u'));
    isar.sourcePreferences.putSync(SourcePreference(sourceId: 500, key: 'k'));
    isar.customButtons.putSync(
      CustomButton(title: 'b', codePress: 'p', pos: 0),
    );
    isar.settings.putSync(
      Settings()
        ..localFolders = ['/device/local']
        ..sortChapterList = [
          for (final m in entries) SortChapter(mangaId: m.id),
        ],
    );
  });
}

/// Every table, in id order, with the links each row points to.
String _dump() {
  int? linked<T>(IsarLink<T> link, int? Function(T) id) {
    link.loadSync();
    final value = link.value;
    return value == null ? null : id(value);
  }

  return const JsonEncoder.withIndent(' ').convert({
    'mangas': [
      for (final m in isar.mangas.where().findAllSync())
        {...m.toJson(), 'id': m.id},
    ],
    'chapters': [
      for (final c in isar.chapters.where().findAllSync())
        {...c.toJson(), 'link': linked(c.manga, (m) => m.id)},
    ],
    'categories': [
      for (final c in isar.categorys.where().findAllSync()) c.toJson(),
    ],
    'downloads': [
      for (final d in isar.downloads.where().findAllSync())
        {...d.toJson(), 'link': linked(d.chapter, (c) => c.id)},
    ],
    'history': [
      for (final h in isar.historys.where().findAllSync())
        {...h.toJson(), 'link': linked(h.chapter, (c) => c.id)},
    ],
    'updates': [
      for (final u in isar.updates.where().findAllSync())
        {...u.toJson(), 'link': linked(u.chapter, (c) => c.id)},
    ],
    'tracks': [for (final t in isar.tracks.where().findAllSync()) t.toJson()],
    'trackPreferences': [
      for (final t in isar.trackPreferences.where().findAllSync()) t.toJson(),
    ],
    'sources': [for (final s in isar.sources.where().findAllSync()) s.toJson()],
    'sourcePreferences': [
      for (final s in isar.sourcePreferences.where().findAllSync()) s.toJson(),
    ],
    'customButtons': [
      for (final b in isar.customButtons.where().findAllSync()) b.toJson(),
    ],
    'settings': [
      for (final s in isar.settings.where().findAllSync()) s.toJson(),
    ],
  });
}

Future<void> _restoreNew(
  Map<String, dynamic> backup, {
  bool merge = false,
  Map<String, bool> categoryDecisions = const {},
  Map<String, int> sourceDecisions = const {},
}) async {
  final container = ProviderContainer(
    overrides: [
      routerCurrentLocationStateProvider.overrideWith(_QuietRouterLocation.new),
    ],
  );
  try {
    await container.read(
      restoreBackupProvider(
        backup,
        merge: merge,
        categoryDecisions: categoryDecisions,
        sourceDecisions: sourceDecisions,
      ).future,
    );
  } finally {
    container.dispose();
  }
}

/// The backup without every second entry, so a merge sees both new and
/// existing entries.
Map<String, dynamic> _halfBackup(Map<String, dynamic> full) {
  final kept = <int>{};
  final manga = [];
  var index = 0;
  for (final entry in full['manga'] as List) {
    if ((index++).isEven) {
      kept.add((entry as Map)['id'] as int);
      manga.add(entry);
    }
  }
  bool keep(Object? row) => kept.contains((row as Map)['mangaId']);
  return {
    ...full,
    'manga': manga,
    'chapters': (full['chapters'] as List).where(keep).toList(),
    'history': (full['history'] as List).where(keep).toList(),
    'updates': (full['updates'] as List).where(keep).toList(),
  };
}

/// Chapters left behind by an entry that was deleted, under the ids the
/// merge will give its new entries. They share names and URLs with the
/// backup's chapters, so the merge must skip and link exactly as before.
void _addStaleChaptersForNextIds() {
  final nextId = isar.mangas.where().idProperty().findAllSync().last + 1;
  isar.writeTxnSync(() {
    isar.chapters.putAllSync([
      for (var m = 0; m < 3; m++)
        for (final c in [3, 9, 11])
          Chapter(
            mangaId: nextId + m,
            name: c == 9 ? null : 'Chapter $c',
            url: c == 11 ? '/stale/$m' : '/e/${1 + 2 * m}/c$c',
          ),
    ]);
  });
}

void main() {
  late Directory root;
  late Isar legacyDb;
  late Isar newDb;
  late Map<String, dynamic> backup;
  late String backupPath;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('backup_restore_equivalence');
    legacyDb = await Isar.open(_schemas, directory: root.path, name: 'legacy');
    newDb = await Isar.open(_schemas, directory: root.path, name: 'current');
    isar = legacyDb;
    _seed();
    backupPath = await writeMangayomiBackupZip(
      list: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      directory: root.path,
      encrypt: false,
    );
    backup = await readMangayomiBackupJson(backupPath, null);
  });

  tearDownAll(() async {
    await legacyDb.close(deleteFromDisk: true);
    await newDb.close(deleteFromDisk: true);
    root.deleteSync(recursive: true);
  });

  /// Brings both databases to the same starting state.
  Future<void> reset() async {
    for (final db in [legacyDb, newDb]) {
      isar = db;
      db.writeTxnSync(() => db.clearSync());
      _seed();
    }
  }

  test('the backup covers the tricky cases', () {
    expect((backup['manga'] as List).length, 22);
    expect(
      (backup['manga'] as List).any((m) => m['link'] == '/e/16/s2'),
      isTrue,
    );
    expect((backup['chapters'] as List).length, 25 * 12 + 3);
  });

  test('reading a backup on an isolate returns what inline reading did', () {
    final stream = InputFileStream(backupPath);
    try {
      final archive = ZipDecoder().decodeStream(stream);
      final bytes = archive.files.first.content as List<int>;
      final inline = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(jsonEncode(backup), jsonEncode(inline));
    } finally {
      stream.close();
    }
  });

  test('reading a missing or corrupt backup still fails', () async {
    await expectLater(
      readMangayomiBackupJson('${root.path}/missing.backup', null),
      throwsA(anything),
    );
    final corrupt = File('${root.path}/corrupt.backup')
      ..writeAsBytesSync(List.filled(64, 7));
    await expectLater(
      readMangayomiBackupJson(corrupt.path, null),
      throwsA(anything),
    );
  });

  test('replace restore writes the same database', () async {
    await reset();
    isar = legacyDb;
    await legacyRestoreBackup(backup);
    final expected = _dump();
    isar = newDb;
    await _restoreNew(backup);
    expect(_dump(), expected);
    // The cases the update lookup must get right were exercised.
    expect(expected, contains('"chapterName": "Chapter 3"'));
  });

  test('merge restore writes the same database', () async {
    final half = _halfBackup(backup);
    for (final decisions in [
      (categories: const <String, bool>{}, sources: const <String, int>{}),
      (
        categories: const {'Later': false},
        sources: const {'Source 1': 502, 'Source 4': 503},
      ),
    ]) {
      await reset();
      for (final db in [legacyDb, newDb]) {
        isar = db;
        await legacyRestoreBackup(half);
        _addStaleChaptersForNextIds();
      }
      isar = legacyDb;
      await legacyRestoreBackup(
        backup,
        merge: true,
        categoryDecisions: decisions.categories,
        sourceDecisions: decisions.sources,
      );
      final expected = _dump();
      isar = newDb;
      await _restoreNew(
        backup,
        merge: true,
        categoryDecisions: decisions.categories,
        sourceDecisions: decisions.sources,
      );
      expect(_dump(), expected);
    }
  });

  test('mangayomi preview counts the same', () async {
    await reset();
    isar = newDb;
    await legacyRestoreBackup(_halfBackup(backup));
    _addStaleChaptersForNextIds();
    final expected = legacyPreviewMangayomiBackup(backup);
    final actual = previewMangayomiBackup(backup);
    expect(actual.newSeriesCount, expected.newSeriesCount);
    expect(actual.updatedSeriesCount, expected.updatedSeriesCount);
    expect(actual.newChapterCount, expected.newChapterCount);
    expect(actual.conflictingCategories, expected.conflictingCategories);
    expect(actual.unmatchedSourceNames, expected.unmatchedSourceNames);
    expect(actual.updatedSeriesCount, greaterThan(0));
  });

  test('tachibk preview counts the same', () async {
    await reset();
    isar = newDb;
    final mihon = BackupMihon(
      backupSources: [BackupSource(name: 'Source 1', sourceId: Int64(41))],
      backupCategories: [
        BackupCategory(name: 'Reading', order: Int64(0)),
        BackupCategory(name: 'New', order: Int64(1)),
      ],
      backupManga: [
        for (final i in [0, 1, 2, 3, 4, 5, 40, 41])
          BackupManga(
            source: Int64(i.isEven ? 41 : 42),
            url: '/e/$i',
            title: 'T$i',
            chapters: [
              for (var c = 0; c < 14; c++)
                BackupChapter(url: '/e/$i/c$c', name: 'Chapter $c'),
            ],
          ),
      ],
    );
    final path = '${root.path}/tachiyomi_equivalence.tachibk';
    File(path)
        .writeAsBytesSync(const GZipEncoder().encode(mihon.writeToBuffer()));
    final expected = legacyPreviewTachiBkImport(path);
    final actual = previewTachiBkImport(path);
    expect(actual?.newSeriesCount, expected?.newSeriesCount);
    expect(actual?.updatedSeriesCount, expected?.updatedSeriesCount);
    expect(actual?.newChapterCount, expected?.newChapterCount);
    expect(actual?.conflictingCategories, expected?.conflictingCategories);
    expect(actual?.unmatchedSourceNames, expected?.unmatchedSourceNames);
    expect(actual?.updatedSeriesCount, greaterThan(0));
    expect(actual?.newSeriesCount, greaterThan(0));
  });
}
