// Importing a Mihon/Chimahon backup file (.tachibk) from Data and storage,
// with the same generic payload the SyncYomi journeys use: moving a library
// over from Mihon, Komikku or Chimahon on another device.
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/restore.dart';
import 'package:material_ui/material_ui.dart' show Scaffold;

import '../harness/journey.dart';
import 'fake_syncyomi.dart';
import 'sync_fixture.dart';

/// The fixture as Mihon writes a backup file: gzip, named like Mihon's.
/// Its covers are served by a [FakeSyncYomi], so they load as they would
/// from a source (a cover that fails is suspected bug S16).
Future<String> writeTachibk(
  Journey j, {
  String name = 'app.mihon_2026-11-20_12-00.tachibk',
}) async {
  final dir = Directory.systemTemp.createTempSync('backups-');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await j.tester.runAsync(() async {
    final media = await FakeSyncYomi.start(empty: true);
    addTearDown(() => j.tester.runAsync(media.close));
    await file.writeAsBytes(
      const GZipEncoder().encodeBytes(syncFixtureBytes(mediaBase: media.url)),
    );
  });
  return file.path;
}

Future<void> restoreFile(Journey j, String path, {bool merge = false}) async {
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
  expect(done, isTrue, reason: 'import finished');
  await j.settle(rounds: 10);
}

void main() {
  testWidgets('a Mihon backup brings its library, categories and progress', (
    tester,
  ) async {
    final j = await Journey.start(tester);
    await restoreFile(j, await writeTachibk(j));

    final mangas = await tester.runAsync(
      () => j.db.mangas.filter().favoriteEqualTo(true).findAll(),
    );
    final names = mangas!.map((m) => m.name).toSet();
    expect(
      names,
      containsAll([Fixture.inProgress, Fixture.caughtUp, Fixture.decimal]),
    );
    final categories = await tester.runAsync(
      () => j.db.categorys.where().findAll(),
    );
    expect(
      categories!.map((c) => c.name),
      containsAll([Fixture.categoryA, Fixture.categoryB]),
    );

    final reading = mangas.firstWhere((m) => m.name == Fixture.inProgress);
    final chapters = await tester.runAsync(
      () => j.db.chapters.filter().mangaIdEqualTo(reading.id).findAll(),
    );
    final chapter3 = chapters!.firstWhere((c) => c.name == 'Chapter 3');
    expect(chapter3.lastPageRead, '${Fixture.inProgressPage}');
    expect(chapters.firstWhere((c) => c.name == 'Chapter 1').isRead, isTrue);
  });

  testWidgets('importing a Mihon backup over an existing library keeps the '
      'existing series when merging', (tester) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Already here');
        await seed.chapters(manga, 2);
      },
    );
    await restoreFile(j, await writeTachibk(j), merge: true);
    final names = (await tester.runAsync(
      () => j.db.mangas.filter().favoriteEqualTo(true).findAll(),
    ))!.map((m) => m.name).toSet();
    expect(names, containsAll(['Already here', Fixture.inProgress]));
  });

  testWidgets('importing the same Mihon backup twice duplicates nothing', (
    tester,
  ) async {
    final j = await Journey.start(tester);
    final path = await writeTachibk(j);
    await restoreFile(j, path, merge: true);
    final mangas = await tester.runAsync(() => j.db.mangas.count());
    final chapters = await tester.runAsync(() => j.db.chapters.count());
    await restoreFile(j, path, merge: true);
    expect(await tester.runAsync(() => j.db.mangas.count()), mangas);
    expect(await tester.runAsync(() => j.db.chapters.count()), chapters);
  });
}
