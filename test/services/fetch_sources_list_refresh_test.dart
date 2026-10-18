import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

/// Refreshing a repository stores the same sources, in the same state, as the
/// implementation that read and wrote each source on its own. The golden file
/// was produced by that implementation; regenerate it only for an intended
/// behavior change, with UPDATE_GOLDEN=1.
const _golden = 'test/services/goldens/fetch_sources_list_refresh.txt';

List<Map<String, Object?>> catalog({int bump = 0, int moved = 0}) {
  final random = Random(3);
  const langs = ['en', 'ja', 'es', 'fr', 'pt-BR', 'id', 'ru', 'zh'];
  var sourceId = 1000;
  return [
    for (var i = 0; i < 25; i++)
      () {
        final multi = random.nextInt(10) < 2;
        final lang = multi ? 'all' : langs[random.nextInt(langs.length)];
        final v = '1.4.${i < bump ? 2 : 1}';
        return <String, Object?>{
          'name': 'Tachiyomi: Extension $i',
          'pkg': 'eu.kanade.tachiyomi.extension.$lang.ext$i',
          'apk': 'tachiyomi-$lang.ext$i-v$v.apk',
          'lang': lang,
          'code': 1,
          'version': v,
          'nsfw': random.nextInt(5) == 0 ? 1 : 0,
          'sources': [
            for (final l in multi ? langs.take(2 + random.nextInt(6)) : [lang])
              {
                'name': 'Extension $i',
                'lang': l,
                // Extension 21 reuses a source id of an earlier extension.
                'id': i == 21 ? '1005' : '${sourceId++}',
                'baseUrl': i < moved
                    ? 'https://moved$i.example'
                    : 'https://ext$i.example',
              },
          ],
        };
      }(),
  ];
}

void main() {
  test('stores the same sources as before', () async {
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
    final root = Directory.systemTemp.createTempSync('fsl_dump');
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
      name: 'fsl_dump',
    );
    isar.writeTxnSync(() => isar.settings.putSync(Settings()));
    var body = <int>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(
      (r) => r.response
        ..add(body)
        ..close(),
    );
    final repo = Repo(
      name: 'R',
      jsonUrl: 'http://127.0.0.1:${server.port}/index.min.json',
    );
    final dumps = <String, Object?>{};

    Future<void> step(String name, List<Map<String, Object?>> index) async {
      body = utf8.encode(jsonEncode(index));
      Object? error;
      try {
        await fetchSourcesList(
          refresh: true,
          androidProxyServer: '',
          autoUpdateExtensions: false,
          itemType: ItemType.manga,
          repo: repo,
        );
      } catch (e) {
        error = e.runtimeType.toString();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await dbWriteQueue.run(() {});
      dumps[name] = {
        'error': error,
        'sources': [
          for (final s in isar.sources.where().findAllSync())
            {
              ...s.toJson()
                ..remove('updatedAt')
                ..['sourceCode'] = sha256
                    .convert(utf8.encode(s.sourceCode ?? ''))
                    .toString(),
              'isarId': s.id,
            },
        ],
      };
    }

    // Stored state before the first fetch: a language the user turned off.
    isar.writeTxnSync(
      () => isar.sources.putSync(
        Source(name: 'Old', lang: 'ja')
          ..id = 1
          ..itemType = ItemType.manga
          ..isActive = false
          ..isLocal = false,
      ),
    );
    await step('first', catalog());

    // Install some extensions at an older version, rename others, turn some
    // off; then the repository offers updates and moved base URLs.
    final all = isar.sources.where().findAllSync();
    isar.writeTxnSync(() {
      for (final (i, s) in all.indexed) {
        if (i % 7 == 0) s.isAdded = true;
        if (i % 11 == 0) s.name = 'Renamed';
        if (i % 13 == 0) s.isActive = !(s.isActive ?? false);
        if (i % 7 == 0) s.version = '1.4.0';
      }
      isar.sources.putAllSync(all);
    });
    await step('updates', catalog(bump: 12, moved: 8));
    await step('again', catalog(bump: 12, moved: 8));

    // An installed source without a version makes the refresh throw part
    // way through.
    final broken = isar.sources.where().findAllSync()[30]
      ..isAdded = true
      ..version = null;
    isar.writeTxnSync(() => isar.sources.putSync(broken));
    await step('throws', catalog(bump: 24, moved: 16));

    await server.close(force: true);
    await isar.close(deleteFromDisk: true);
    // The local server's port changes between runs.
    final actual = [
      for (final MapEntry(:key, :value) in dumps.entries) ...[
        '# $key',
        for (final line in (value as Map)['sources'] as List) jsonEncode(line),
        'error: ${value['error']}',
      ],
    ].join('\n').replaceAll(RegExp(r'127\.0\.0\.1:\d+'), 'HOST');
    if (Platform.environment['UPDATE_GOLDEN'] != null) {
      File(_golden)
        ..createSync(recursive: true)
        ..writeAsStringSync('$actual\n');
    }
    expect(actual, File(_golden).readAsStringSync().trimRight());
  });
}
