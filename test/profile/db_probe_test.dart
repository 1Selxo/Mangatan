// Reports the size and shape of a real database, and what the queries the app
// runs at startup and in browse cost on it. Read-only apart from Isar's own
// bookkeeping; point it at a COPY:
//
//   MANGATAN_PROFILE_DB=<folder with mangayomiDb.isar> \
//     flutter test test/profile/db_probe_test.dart
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/providers/storage_provider.dart';

import '../test_utils/isar_library.dart';

final _dir = Platform.environment['MANGATAN_PROFILE_DB'];

void main() {
  test('database shape and query costs', () async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    final open = Stopwatch()..start();
    isar = await Isar.open(
      appIsarSchemas,
      directory: _dir!,
      name: 'mangayomiDb',
    );
    print('open ${open.elapsedMilliseconds} ms');
    print('file ${File('$_dir/mangayomiDb.isar').lengthSync() >> 20} MiB');
    print('used ${await isar.getSize(includeIndexes: true) >> 20} MiB');
    for (final entry in {
      'sources': isar.sources,
      'mangas': isar.mangas,
      'chapters': isar.chapters,
      'historys': isar.historys,
      'updates': isar.updates,
      'trackPreferences': isar.trackPreferences,
    }.entries) {
      final c = entry.value as IsarCollection<Object?>;
      print(
        '${entry.key}: ${await c.count()} rows, '
        '${await c.getSize(includeIndexes: true) >> 10} KiB',
      );
    }

    T timed<T>(String label, T Function() run) {
      run(); // warm up
      final w = Stopwatch()..start();
      final result = run();
      final n = result is List ? ' (${result.length} rows)' : '';
      print(
        '$label: ${(w.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms$n',
      );
      return result;
    }

    final all = timed('all sources', () => isar.sources.where().findAllSync());
    final added = all.where((s) => s.isAdded == true).toList();
    final code = added.fold<int>(0, (n, s) => n + (s.sourceCode?.length ?? 0));
    final anyCode = all.fold<int>(0, (n, s) => n + (s.sourceCode?.length ?? 0));
    print('installed sources: ${added.length}, code ${code >> 20} MiB');
    print('code across all sources: ${anyCode >> 20} MiB');
    final byLang = <String, int>{};
    for (final s in added) {
      final key =
          '${s.itemType.name}/${s.sourceCodeLanguage.name}'
          '${s.isActive == true ? '' : '/inactive'}'
          '${s.isNsfw == true ? '/nsfw' : ''}'
          '${s.isPinned == true ? '/pinned' : ''}';
      byLang[key] = (byLang[key] ?? 0) + 1;
    }
    print('installed by kind: $byLang');
    print(
      'distinct installed APKs: '
      '${added.map((s) => s.sourceCodeUrl).toSet().length}',
    );
    timed(
      'installed manga sources',
      () => isar.sources
          .filter()
          .isAddedEqualTo(true)
          .itemTypeEqualTo(ItemType.manga)
          .findAllSync(),
    );
    final one = added.where((s) => s.name != null).firstOrNull;
    if (one != null) {
      timed('one source by id', () => isar.sources.getSync(one.id!));
      timed(
        'one source by name and lang',
        () => isar.sources
            .filter()
            .nameEqualTo(one.name)
            .langEqualTo(one.lang)
            .findFirstSync(),
      );
    }
    timed(
      'favorites',
      () => isar.mangas.filter().favoriteEqualTo(true).findAllSync(),
    );
    timed(
      'local-library scan query',
      () => isar.mangas
          .filter()
          .sourceEqualTo('local')
          .or()
          .linkContains('Mangatan/local')
          .or()
          .linkContains('Mangatan\\local')
          .findAllSync(),
    );
    final settings = isar.settings.getSync(227)!;
    print(
      'settings: showNSFW=${settings.showNSFW} '
      'onlyPinned=${settings.onlyIncludePinnedSources} '
      'logs=${settings.enableLogs} '
      'checkForExtensionUpdates=${settings.checkForExtensionUpdates} '
      'localFolders=${settings.localFolders} '
      '',
    );
    await isar.close();
  }, skip: _dir == null);
}
