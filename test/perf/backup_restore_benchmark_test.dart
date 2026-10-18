// Benchmarks creating and restoring backups on a large library.
//
// Skipped unless MANGATAN_PERF is set:
//
//   MANGATAN_PERF=1 flutter test test/perf/backup_restore_benchmark_test.dart
//
// MANGATAN_PERF_RUNS sets the measured runs (default 12, after 3 warm-up
// runs). MANGATAN_PERF_OUT=<file> also writes the results as JSON.
//
// Everything runs on a real Isar database through the same functions and
// providers the backup screens use. Each sample reports the wall time and
// the longest stall of this isolate while the operation ran.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
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
import 'package:mangayomi/modules/more/data_and_storage/providers/restore.dart';
import 'package:mangayomi/router/router.dart';

import '../test_utils/isar_library.dart';

final _enabled = Platform.environment['MANGATAN_PERF'] != null;
final _iterations =
    int.tryParse(Platform.environment['MANGATAN_PERF_RUNS'] ?? '') ?? 12;
const _warmup = 3;
const _mangaEntries = 400;
const _animeEntries = 60;
const _browsedEntries = 40;
const _chaptersPerEntry = 150;

class _Stat {
  _Stat(List<double> values) : _sorted = [...values]..sort();
  final List<double> _sorted;

  double get median {
    final n = _sorted.length;
    return n.isOdd
        ? _sorted[n ~/ 2]
        : (_sorted[n ~/ 2 - 1] + _sorted[n ~/ 2]) / 2;
  }

  double get p90 =>
      _sorted[min(_sorted.length - 1, (_sorted.length * 0.9).floor())];

  Map<String, double> toJson() => {
    'median': double.parse(median.toStringAsFixed(2)),
    'p90': double.parse(p90.toStringAsFixed(2)),
  };
}

/// Longest gap between ticks of a periodic timer on this isolate, which is
/// how long the isolate was busy without yielding. Only the maximum is
/// reported; no threshold is applied.
class _StallProbe {
  final _clock = Stopwatch();
  int _last = 0;
  int longest = 0;
  Timer? _timer;

  void start() {
    longest = 0;
    _clock
      ..reset()
      ..start();
    _last = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = _clock.elapsedMicroseconds;
    longest = max(longest, now - _last);
    _last = now;
  }

  int stop() {
    _timer?.cancel();
    _tick();
    return longest;
  }
}

final _results = <String, Object?>{};

/// Runs [run] warm-up plus measured times. [prepare] runs untimed before
/// each run, for operations that change the database.
Future<void> _bench(
  String name,
  Future<void> Function() run, {
  FutureOr<void> Function()? prepare,
  int? runs,
}) async {
  final measured = runs ?? _iterations;
  final totals = <double>[];
  final stalls = <double>[];
  for (var i = 0; i < _warmup + measured; i++) {
    await prepare?.call();
    final probe = _StallProbe()..start();
    final clock = Stopwatch()..start();
    await run();
    clock.stop();
    final stall = probe.stop();
    if (i < _warmup) continue;
    totals.add(clock.elapsedMicroseconds / 1000);
    stalls.add(stall / 1000);
  }
  final result = {
    'runs': measured,
    'totalMs': _Stat(totals).toJson(),
    'longestMainIsolateStallMs': _Stat(stalls).toJson(),
  };
  _results[name] = result;
  // ignore: avoid_print
  print('BENCH $name ${jsonEncode(result)}');
}

class _QuietRouterLocation extends RouterCurrentLocationState {
  @override
  String? build() => null;

  @override
  void refresh() {}
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    routerCurrentLocationStateProvider.overrideWith(_QuietRouterLocation.new),
  ],
);

/// Fills the database with a realistic library: favorites and browsed
/// entries, ~150 chapters each, downloads, history, updates, categories,
/// tracks, sources, source preferences and per-entry chapter settings.
void _seed() {
  final random = Random(7);
  final now = DateTime(2026).millisecondsSinceEpoch;
  isar.writeTxnSync(() {
    isar.categorys.putAllSync([
      for (var i = 0; i < 6; i++)
        Category(
          name: 'Category $i',
          forItemType: i < 4 ? ItemType.manga : ItemType.anime,
          pos: i,
          hide: false,
        ),
    ]);
    isar.sources.putAllSync([
      for (var i = 0; i < 24; i++)
        Source(
          id: 9000 + i,
          name: 'Source ${i % 12}',
          lang: 'en',
          baseUrl: 'https://source$i.example',
          isAdded: true,
          itemType: i < 12 ? ItemType.manga : ItemType.anime,
          sourceCode: 'x' * 2000,
        ),
    ]);
    final entries = <Manga>[];
    for (var i = 0; i < _mangaEntries + _animeEntries + _browsedEntries; i++) {
      final anime = i >= _mangaEntries && i < _mangaEntries + _animeEntries;
      final browsed = i >= _mangaEntries + _animeEntries;
      entries.add(
        Manga(
          source: 'Source ${i % 12}',
          author: 'Author ${i % 50}',
          artist: 'Artist ${i % 40}',
          genre: ['Action', 'Drama', if (i.isEven) 'Comedy'],
          imageUrl: 'https://cdn.example/covers/$i.jpg',
          lang: 'en',
          link: '/series/$i',
          name: 'Library Entry ${random.nextInt(1 << 30)}',
          status: Status.values[i % Status.values.length],
          description: 'Description of entry $i. ' * 8,
          sourceId: 9000 + (anime ? 12 : 0) + i % 12,
          favorite: !browsed,
          itemType: anime ? ItemType.anime : ItemType.manga,
          categories: browsed
              ? const []
              : anime
              ? [5 + i % 2]
              : [if (i % 3 != 2) i % 4 + 1],
          dateAdded: now - random.nextInt(1 << 30),
          lastUpdate: now - random.nextInt(1 << 30),
          lastRead: now - random.nextInt(1 << 30),
        ),
      );
    }
    isar.mangas.putAllSync(entries);
    for (final manga in entries) {
      final read = random.nextInt(_chaptersPerEntry);
      final chapters = [
        for (var c = 0; c < _chaptersPerEntry; c++)
          Chapter(
            mangaId: manga.id,
            name: 'Chapter ${c + 1}',
            url: '${manga.link}/chapter-${c + 1}',
            dateUpload: '${now - (_chaptersPerEntry - c) * 86400000}',
            scanlator: c.isEven ? 'Group A' : 'Group B',
            isRead: c < read,
            isBookmarked: c % 37 == 0,
            lastPageRead: c < read ? '20' : '0',
          )..manga.value = manga,
      ];
      isar.chapters.putAllSync(chapters);
      for (final chapter in chapters) {
        chapter.manga.saveSync();
      }
      if (manga.favorite != true) continue;
      // History for the last few read chapters and recent updates.
      for (final chapter in chapters.skip(max(0, read - 3)).take(3)) {
        final history = History(
          mangaId: manga.id,
          chapterId: chapter.id,
          itemType: manga.itemType,
          date: '${now - random.nextInt(1 << 30)}',
          readingTimeSeconds: random.nextInt(3600),
        )..chapter.value = chapter;
        isar.historys.putSync(history);
        history.chapter.saveSync();
      }
      for (final chapter in chapters.reversed.take(4)) {
        final update = Update(
          mangaId: manga.id,
          chapterName: chapter.name,
          date: '${now - random.nextInt(1 << 30)}',
        )..chapter.value = chapter;
        isar.updates.putSync(update);
        update.chapter.saveSync();
      }
      if (manga.id! % 2 == 0) {
        isar.tracks.putSync(
          Track(
            mangaId: manga.id,
            syncId: 1 + manga.id! % 3,
            mediaId: manga.id,
            title: manga.name,
            lastChapterRead: read,
            totalChapter: _chaptersPerEntry,
            score: 7,
            status: TrackStatus.reading,
            itemType: manga.itemType,
          ),
        );
      }
    }
    final chapterIds = isar.chapters.where().idProperty().findAllSync();
    isar.downloads.putAllSync([
      for (final id in chapterIds)
        if (id % 9 == 0)
          Download(
            id: id,
            succeeded: 1,
            failed: 0,
            total: 1,
            isDownload: true,
            isStartDownload: false,
          ),
    ]);
    isar.trackPreferences.putAllSync([
      for (var i = 1; i <= 3; i++)
        TrackPreference(syncId: i, username: 'user$i', oAuth: 'token$i'),
    ]);
    isar.sourcePreferences.putAllSync([
      for (var i = 0; i < 24; i++)
        for (var k = 0; k < 4; k++)
          SourcePreference(sourceId: 9000 + i, key: 'pref_$k'),
    ]);
    isar.customButtons.putAllSync([
      for (var i = 0; i < 4; i++)
        CustomButton(title: 'Button $i', codePress: 'press$i', pos: i),
    ]);
    isar.settings.putSync(
      Settings()
        ..chapterFilterUnreadList = [
          for (final m in entries) ChapterFilterUnread(mangaId: m.id),
        ]
        ..chapterFilterBookmarkedList = [
          for (final m in entries) ChapterFilterBookmarked(mangaId: m.id),
        ]
        ..chapterFilterDownloadedList = [
          for (final m in entries) ChapterFilterDownloaded(mangaId: m.id),
        ]
        ..sortChapterList = [
          for (final m in entries) SortChapter(mangaId: m.id),
        ],
    );
  });
}

const _allParts = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

Map<String, dynamic> _readBackupZip(String path) {
  final stream = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(stream);
    final bytes = archive.files.first.content as List<int>;
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  } finally {
    stream.close();
  }
}

Future<void> _restore(Map<String, dynamic> backup, {bool merge = false}) async {
  final container = _container();
  try {
    await container.read(restoreBackupProvider(backup, merge: merge).future);
  } finally {
    container.dispose();
  }
}

/// The same backup with every second favorite entry (and what belongs to
/// it) left out, so a merge has both new and existing entries.
Map<String, dynamic> _halfBackup(Map<String, dynamic> full) {
  final kept = <int>{};
  final manga = <Object?>[];
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
    'tracks': (full['tracks'] as List).where(keep).toList(),
  };
}

void main() {
  late Directory root;
  late Map<String, dynamic> fullBackup;
  late String fullBackupPath;

  setUpAll(() async {
    if (!_enabled) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('mangatan_backup_perf');
    isar = await Isar.open(
      [
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
      ],
      directory: root.path,
      name: 'backup_perf',
    );
    _seed();
    final dir = Directory('${root.path}/reference')..createSync();
    fullBackupPath = await writeMangayomiBackupZip(
      list: _allParts,
      directory: dir.path,
      encrypt: false,
    );
    fullBackup = _readBackupZip(fullBackupPath);
    // Put the database in the state a replace restore leaves it in, so every
    // run below starts from the same contents.
    await _restore(fullBackup);
    // ignore: avoid_print
    print(
      'BACKUP_SIZE ${jsonEncode({'zipBytes': File(fullBackupPath).lengthSync(), 'manga': (fullBackup['manga'] as List).length, 'chapters': (fullBackup['chapters'] as List).length, 'history': (fullBackup['history'] as List).length, 'updates': (fullBackup['updates'] as List).length, 'downloads': (fullBackup['downloads'] as List).length})}',
    );
  });

  tearDownAll(() async {
    if (!_enabled) return;
    final out = Platform.environment['MANGATAN_PERF_OUT'];
    if (out != null) {
      File(
        out,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
    }
    await isar.close(deleteFromDisk: true);
    root.deleteSync(recursive: true);
  });

  test('create backup: everything', skip: !_enabled, () async {
    final dir = Directory('${root.path}/create')..createSync();
    await _bench('backup_create_all', () async {
      final path = await writeMangayomiBackupZip(
        list: _allParts,
        directory: dir.path,
        encrypt: false,
      );
      File(path).deleteSync();
    });
  });

  test('create backup: library only', skip: !_enabled, () async {
    final dir = Directory('${root.path}/create_library')..createSync();
    await _bench('backup_create_library', () async {
      final path = await writeMangayomiBackupZip(
        list: const [0, 1, 2],
        directory: dir.path,
        encrypt: false,
      );
      File(path).deleteSync();
    });
  });

  test('read backup file', skip: !_enabled, () async {
    // As decodeMangayomiBackup reads an unencrypted backup.
    await _bench('backup_decode', () async {
      await readMangayomiBackupJson(fullBackupPath, null);
    });
  });

  test('preview mangayomi backup', skip: !_enabled, () async {
    await _bench('backup_preview_mangayomi', () async {
      previewMangayomiBackup(fullBackup);
    });
  });

  test('restore mangayomi backup: replace', skip: !_enabled, () async {
    await _bench('restore_replace', () => _restore(fullBackup));
  });

  test('restore mangayomi backup: merge', skip: !_enabled, () async {
    final half = _halfBackup(fullBackup);
    await _bench(
      'restore_merge',
      () => _restore(fullBackup, merge: true),
      prepare: () => _restore(half),
    );
    await _restore(fullBackup);
  });
}
