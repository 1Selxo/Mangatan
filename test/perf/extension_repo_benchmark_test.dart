import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

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
import 'package:mangayomi/repositories/db_write_queue.dart';
import 'package:mangayomi/services/fetch_sources_list.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../test_utils/isar_library.dart';

/// Refreshing an extension repository the size of Keiyoushi's: the first
/// fetch (every source new), a refresh with nothing changed, and a refresh in
/// which installed extensions have updates. Gated by MANGATAN_PERF.
///
/// MANGATAN_PERF=1 flutter test test/perf/extension_repo_benchmark_test.dart
final _enabled = Platform.environment['MANGATAN_PERF'] != null;
final _iterations =
    int.tryParse(Platform.environment['MANGATAN_PERF_RUNS'] ?? '') ?? 10;
const _warmup = 2;
const _extensions = 1300;
const _updated = 100;

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

double _p90(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[min(sorted.length - 1, (sorted.length * 0.9).floor())];
}

final _results = <String, Object?>{};

Future<void> _bench(
  String name,
  Future<void> Function() setUp,
  Future<void> Function() run,
) async {
  final values = <double>[];
  final stalls = <double>[];
  for (var i = 0; i < _warmup + _iterations; i++) {
    await setUp();
    // The longest time the isolate went without running a 1 ms timer.
    final tick = Stopwatch()..start();
    var longest = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      longest = max(longest, tick.elapsedMicroseconds);
      tick.reset();
    });
    final watch = Stopwatch()..start();
    await run();
    final ms = watch.elapsedMicroseconds / 1000;
    timer.cancel();
    longest = max(longest, tick.elapsedMicroseconds);
    if (i >= _warmup) {
      values.add(ms);
      stalls.add(longest / 1000);
    }
  }
  _results[name] = {
    'runs': values.length,
    'median': double.parse(_median(values).toStringAsFixed(2)),
    'p90': double.parse(_p90(values).toStringAsFixed(2)),
    'longestStallMs': double.parse(_median(stalls).toStringAsFixed(2)),
  };
  // ignore: avoid_print
  print('BENCH $name ${jsonEncode(_results[name])}');
}

/// A Keiyoushi-style `index.min.json`: most extensions have one source, some
/// have one per language.
List<Map<String, Object?>> repositoryIndex({int bumpVersions = 0}) {
  final random = Random(3);
  const langs = ['en', 'ja', 'es', 'fr', 'pt-BR', 'id', 'ru', 'zh'];
  var sourceId = 1000;
  return [
    for (var i = 0; i < _extensions; i++)
      () {
        final multi = random.nextInt(10) < 2;
        final lang = multi ? 'all' : langs[random.nextInt(langs.length)];
        final pkg = 'eu.kanade.tachiyomi.extension.$lang.ext$i';
        return <String, Object?>{
          'name': 'Tachiyomi: Extension $i',
          'pkg': pkg,
          'apk': 'tachiyomi-$lang.ext$i-v1.4.${i < bumpVersions ? 2 : 1}.apk',
          'lang': lang,
          'code': 1,
          'version': '1.4.${i < bumpVersions ? 2 : 1}',
          'nsfw': random.nextInt(5) == 0 ? 1 : 0,
          'sources': [
            for (final l in multi ? langs.take(2 + random.nextInt(6)) : [lang])
              {
                'name': 'Extension $i',
                'lang': l,
                'id': '${sourceId++}${random.nextInt(1 << 30)}',
                'baseUrl': 'https://ext$i.example',
              },
          ],
        };
      }(),
  ];
}

void main() {
  late Directory root;
  late HttpServer server;
  var index = <int>[];
  late Repo repo;

  setUpAll(() async {
    if (!_enabled) return;
    PackageInfo.setMockInitialValues(
      appName: 'Mangatan',
      packageName: 'mangatan',
      version: '0.9.8',
      buildNumber: '1',
      buildSignature: '',
    );
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('mangatan_repo_perf');
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
      name: 'repo_perf',
    );
    isar.writeTxnSync(() => isar.settings.putSync(Settings()));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..add(index)
        ..close();
    });
    repo = Repo(
      name: 'Bench',
      jsonUrl: 'http://127.0.0.1:${server.port}/index.min.json',
    );
  });

  tearDownAll(() async {
    if (!_enabled) return;
    await server.close(force: true);
    await isar.close(deleteFromDisk: true);
    root.deleteSync(recursive: true);
    final out = Platform.environment['MANGATAN_PERF_OUT'];
    if (out != null) {
      File(
        out,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
    }
  });

  Future<void> refresh() => fetchSourcesList(
    refresh: true,
    androidProxyServer: '',
    autoUpdateExtensions: false,
    itemType: ItemType.manga,
    repo: repo,
  );

  // The obsolete check runs unawaited after each refresh; let it finish so
  // it doesn't overlap the next measurement.
  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dbWriteQueue.run(() {});
  }

  test(
    'extension repository refresh',
    skip: !_enabled,
    timeout: Timeout.none,
    () async {
      final plain = utf8.encode(jsonEncode(repositoryIndex()));
      final bumped = utf8.encode(
        jsonEncode(repositoryIndex(bumpVersions: _updated)),
      );

      await _bench('repo_first_fetch', () async {
        await settle();
        index = plain;
        isar.writeTxnSync(() => isar.sources.clearSync());
      }, refresh);

      await _bench('repo_refresh_unchanged', () async {
        await settle();
        index = plain;
      }, refresh);

      // Install the first extensions at the old version; the repository then
      // offers an update for each.
      await _bench('repo_refresh_with_updates', () async {
        await settle();
        index = bumped;
        final installed = isar.sources
            .filter()
            .versionEqualTo('1.4.1')
            .or()
            .versionEqualTo('1.4.2')
            .findAllSync()
            .where((s) => s.sourceCodeUrl!.contains('-v1.4.'))
            .toList();
        isar.writeTxnSync(() {
          for (final s in installed) {
            final ext = int.parse(
              RegExp(r'\.ext(\d+)-').firstMatch(s.sourceCodeUrl!)!.group(1)!,
            );
            s
              ..isAdded = ext < _updated
              ..version = '1.4.1'
              ..versionLast = '1.4.1';
          }
          isar.sources.putAllSync(installed);
        });
      }, refresh);

      final sourceList = isar.sources.filter().idIsNotNull().findAllSync();
      await _bench('repo_obsolete_check', settle, () async {
        await checkIfSourceIsObsolete(sourceList, repo, ItemType.manga);
      });
      // ignore: avoid_print
      print('sources stored: ${sourceList.length}');
    },
  );
}
