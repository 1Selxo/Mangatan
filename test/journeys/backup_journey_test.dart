// Backing up and restoring a lived-in library with the app's own providers
// (the ones Data and storage calls), then checking what a person would check:
// every series back, in its categories, at its pages, with its history.
// Upstream #848: "Restoring Backup deletes all manga library entries".
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/backup.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/restore.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

/// What a person checks after a restore, read from the database.
Future<Map<String, Object?>> snapshot(
  Journey j,
) async => (await j.tester.runAsync(() async {
  final mangas = await j.db.mangas.filter().favoriteEqualTo(true).findAll();
  final chapters = await j.db.chapters.where().findAll();
  final categories = await j.db.categorys.where().findAll();
  final categoryName = {for (final c in categories) c.id: c.name};
  return {
    'series': {
      for (final m in mangas)
        m.name: [for (final id in m.categories ?? <int>[]) categoryName[id]]
          ..sort(),
    },
    'progress': {
      for (final c in chapters)
        '${mangas.where((m) => m.id == c.mangaId).firstOrNull?.name}/${c.name}':
            '${c.isRead}|${c.lastPageRead}|${c.isBookmarked}',
    },
    'history': await j.db.historys.count(),
  };
}))!;

Future<String> backUp(Journey j) async {
  final dir = Directory('${j.directory.path}${Platform.pathSeparator}backups')
    ..createSync();
  late String path;
  await j.drive(() async {
    path = await writeMangayomiBackupZip(
      list: List.generate(11, (i) => i),
      directory: dir.path,
      encrypt: false,
    );
  }());
  expect(File(path).existsSync(), isTrue, reason: 'backup written');
  return path;
}

Future<void> restore(Journey j, String path, {required bool merge}) async {
  final context = j.tester.element(find.byType(Scaffold).first);
  final provider = doRestoreProvider(
    path: path,
    context: context,
    merge: merge,
  );
  final sub = j.container.listen(provider, (_, _) {}, onError: (_, _) {});
  final done = await j.drive(
    j.container.read(provider.future),
    limit: const Duration(seconds: 60),
  );
  sub.close();
  expect(done, isTrue, reason: 'restore finished');
  await j.settle(rounds: 10);
}

void main() {
  Future<Journey> livedIn(WidgetTester tester) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        await seed.livedIn();
        final kuso = await seed.db.mangas
            .filter()
            .nameEqualTo('KUSO ONNA NO SACHIARE')
            .findFirst();
        final chapters = await seed.db.chapters
            .filter()
            .mangaIdEqualTo(kuso!.id)
            .findAll();
        chapters.last.isBookmarked = true;
        await seed.db.writeTxn(() => seed.db.chapters.put(chapters.last));
      },
    );
    return j;
  }

  testWidgets('a restore brings back what was lost since the backup', (
    tester,
  ) async {
    final j = await livedIn(tester);
    final before = await snapshot(j);
    final path = await backUp(j);

    // Things go wrong: a series removed, progress overwritten, history wiped.
    await tester.runAsync(() async {
      final gone = await j.db.mangas
          .filter()
          .nameEqualTo('Frieren')
          .findFirst();
      final chapters = await j.db.chapters.where().findAll();
      for (final c in chapters) {
        c
          ..isRead = false
          ..lastPageRead = '';
      }
      await j.db.writeTxn(() async {
        await j.db.mangas.delete(gone!.id!);
        await j.db.chapters.putAll(chapters);
        await j.db.historys.clear();
      });
    });

    await restore(j, path, merge: false);
    final after = await snapshot(j);
    expect(after['series'], before['series']);
    expect(after['progress'], before['progress']);
    expect(after['history'], before['history']);

    // And the app shows it: the library, and the page a chapter resumes at.
    await j.go('/MangaLibrary');
    await j.tap(find.text('KUSO ONNA NO SACHIARE').last);
    await j.openChapter('Chapter 2');
    expect(j.pageIndicator, '3 / 3');
  });

  testWidgets('a merge restore keeps series added after the backup '
      '(upstream #848)', (tester) async {
    final j = await livedIn(tester);
    final before = await snapshot(j);
    final path = await backUp(j);
    await tester.runAsync(() => j.seed.manga('Added after the backup'));

    await restore(j, path, merge: true);
    final after = await snapshot(j);
    final series = after['series']! as Map;
    expect(series.keys, containsAll((before['series']! as Map).keys));
    expect(series.keys, contains('Added after the backup'));
  });

  testWidgets('restoring the same backup twice does not duplicate anything', (
    tester,
  ) async {
    final j = await livedIn(tester);
    final path = await backUp(j);
    await restore(j, path, merge: true);
    final once = await snapshot(j);
    final chaptersOnce = await tester.runAsync(() => j.db.chapters.count());
    await restore(j, path, merge: true);
    final twice = await snapshot(j);
    expect(twice, once);
    expect(await tester.runAsync(() => j.db.chapters.count()), chaptersOnce);
  });

  testWidgets('a restore into a fresh install brings the whole library', (
    tester,
  ) async {
    final j = await livedIn(tester);
    final before = await snapshot(j);
    final path = await backUp(j);
    // Same file name: a Mangatan backup is recognised by its name (a renamed
    // one is refused as "unsupported backup" by the restore screen).
    final copyDir = Directory.systemTemp.createTempSync('journey-backup-');
    final copy =
        '${copyDir.path}${Platform.pathSeparator}'
        '${path.split(Platform.pathSeparator).last}';
    File(path).copySync(copy);
    addTearDown(() {
      if (copyDir.existsSync()) copyDir.deleteSync(recursive: true);
    });

    // Everything gone, as on a new computer.
    await tester.runAsync(() async {
      await j.db.writeTxn(() async {
        await j.db.mangas.clear();
        await j.db.chapters.clear();
        await j.db.categorys.clear();
        await j.db.historys.clear();
        await j.db.updates.clear();
      });
    });
    await j.restart();
    await restore(j, copy, merge: false);
    final after = await snapshot(j);
    expect(after['series'], before['series']);
    expect(after['progress'], before['progress']);
  });
}

// The container is read for the restore provider; keep the import used.
// ignore: unused_element
typedef _Container = ProviderContainer;
