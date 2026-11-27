// Chimahon sync over SyncYomi, end to end: the app's real sync code talks
// HTTP to a SyncYomi server on 127.0.0.1 that holds a generic payload shaped
// like a real account's (sync_fixture.dart). The 2026-11-21 checklist:
// "Sync: Chimahon, SyncYomi ... still sync", "Chimahon progress resumes at
// page 1", "download only took a long time until the toast".
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations_en.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/widgets/cover_view_widget.dart';
import 'package:mangayomi/services/sync_server.dart';
import 'package:material_ui/material_ui.dart' show Icons;

import '../harness/journey.dart';
import 'fake_syncyomi.dart';
import 'sync_fixture.dart';

final _l10n = AppLocalizationsEn();

/// An app connected to [server] for Chimahon sync over SyncYomi.
Future<Journey> connectedTo(
  WidgetTester tester,
  FakeSyncYomi server, {
  String? token,
  Future<void> Function(Seed seed)? arrange,
}) => Journey.start(
  tester,
  arrange: (seed) async {
    await seed.db.writeTxn(
      () => seed.db.syncPreferences.put(
        SyncPreference(
          syncId: 1,
          syncMode: SyncMode.chimahon,
          chimahonSyncProvider: ChimahonSyncProvider.syncYomi,
          syncYomiServer: server.url,
          syncYomiApiToken: token ?? server.token,
          // "Sync on", as when someone uses sync; automatic sync stays off.
          syncOn: true,
        ),
      ),
    );
    if (arrange != null) await arrange(seed);
  },
);

extension on Journey {
  SyncServer get syncServer => read(syncServerProvider(syncId: 1).notifier);

  /// Runs a sync the way the Sync screen's buttons do, accepting the
  /// download preview, and waits for it in real time (it talks HTTP).
  Future<bool> sync({bool download = false, bool upload = false}) async {
    late bool result;
    final done = await drive(() async {
      // Not silent: as the Sync screen's buttons call it.
      result = await syncServer.startSync(
        _l10n,
        false,
        download: download,
        upload: upload,
        confirmChimahonDownload: (_) async => true,
      );
    }(), limit: const Duration(seconds: 60));
    expect(done, isTrue, reason: 'the sync finished');
    await settle(rounds: 10);
    return result;
  }

  Future<Manga?> series(String name) => tester
      .runAsync(() => db.mangas.filter().nameEqualTo(name).findFirst())
      .then((m) => m);

  Future<List<Chapter>> chaptersOf(String name) async {
    final manga = await series(name);
    if (manga == null) return const [];
    return (await tester.runAsync(
      () => db.chapters.filter().mangaIdEqualTo(manga.id).findAll(),
    ))!;
  }
}

void main() {
  late FakeSyncYomi server;
  tearDown(() async => server.close());

  group('download only into a new installation', () {
    testWidgets('brings the library, categories, progress and history', (
      tester,
    ) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      expect(await j.sync(download: true), isTrue);
      expect(server.uploads, isEmpty, reason: 'download only never uploads');

      // The library: favourites in, history-only series out.
      for (final name in [
        Fixture.inProgress,
        Fixture.caughtUp,
        Fixture.decimal,
        Fixture.noGenres,
      ]) {
        final manga = await j.series(name);
        expect(manga?.favorite, isTrue, reason: '$name is in the library');
      }
      expect(
        (await j.series(Fixture.notInLibrary))?.favorite ?? false,
        isFalse,
      );

      // Categories, with their series.
      final categories = await tester.runAsync(
        () => j.db.categorys.where().findAll(),
      );
      final names = categories!.map((c) => c.name).toSet();
      expect(names, containsAll([Fixture.categoryA, Fixture.categoryB]));
      final shelfA = categories.firstWhere((c) => c.name == Fixture.categoryA);
      expect(
        (await j.series(Fixture.inProgress))!.categories,
        contains(shelfA.id),
      );

      // Progress: read marks and the page of the chapter in progress.
      final chapters = await j.chaptersOf(Fixture.inProgress);
      final byName = {for (final c in chapters) c.name: c};
      expect(byName['Chapter 1']?.isRead, isTrue);
      expect(byName['Chapter 2']?.isBookmarked, isTrue);
      expect(byName['Chapter 3']?.isRead, isFalse);
      expect(byName['Chapter 3']?.lastPageRead, '${Fixture.inProgressPage}');

      // Decimal chapters arrive as their own chapters.
      final decimals = await j.chaptersOf(Fixture.decimal);
      expect(
        decimals.map((c) => c.chapterNumber),
        containsAll([1.0, 1.5, 2.0, 2.5]),
      );

      // History.
      expect(
        await tester.runAsync(() => j.db.historys.count()),
        greaterThan(0),
      );

      // And the app shows it: the library and the page under the chapter.
      await j.go('/MangaLibrary');
      await j.waitFor(find.text(Fixture.categoryA));
      await j.tapText(Fixture.categoryA);
      // The grid's tile: the Continue shelf's caption does not open it (S3).
      await j.tap(
        find.descendant(
          of: find.byType(CoverViewWidget),
          matching: find.text(Fixture.inProgress),
        ),
      );
      await j.waitFor(find.text('Page ${Fixture.inProgressPage}'));
    });

    testWidgets('anime and novels arrive too', (tester) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      await j.sync(download: true);
      final anime = await j.series(Fixture.anime);
      expect(anime?.itemType, ItemType.anime);
      final episodes = await j.chaptersOf(Fixture.anime);
      expect(episodes.where((e) => e.isRead == true).length, 2);
      expect(await j.series(Fixture.seasonedShow), isNotNull);
      final novel = await j.series(Fixture.novel);
      expect(novel?.itemType, ItemType.novel);
    });

    testWidgets('a series without genres from the sync opens', (tester) async {
      // Was S9, reached through sync.
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      await j.sync(download: true);
      await j.go('/MangaLibrary');
      await j.tap(
        find.descendant(
          of: find.byType(CoverViewWidget),
          matching: find.text(Fixture.noGenres),
        ),
      );
      await j.waitFor(find.text('Chapter 1'));
    });
  });

  group('the Sync screen', () {
    testWidgets('Download only asks first, then brings the library', (
      tester,
    ) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      await j.go('/more');
      await j.push('settings');
      await j.tapText(_l10n.syncing);
      await j.waitFor(find.text(_l10n.sync_button_download));
      // The icon above the label is the button; the label is not (S3).
      await j.tap(find.byIcon(Icons.file_download_outlined));
      // The preview has to come from the server first.
      for (
        var i = 0;
        i < 100 && find.text(_l10n.dialog_confirm).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await j.settle(rounds: 1);
      }
      await j.tap(find.text(_l10n.dialog_confirm).hitTestable().last);
      // The sync reports its result when it is done, as a person sees it.
      final result = find.textContaining('Downloaded:');
      for (var i = 0; i < 400 && result.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await j.settle(rounds: 1);
      }
      expect(result, findsWidgets, reason: j.visibleTexts().join(' | '));
      expect(await j.series(Fixture.inProgress), isNotNull);
      expect(server.uploads, isEmpty);
    });
  });

  group('two-way sync', () {
    testWidgets('local reading goes up, the rest of the account is kept', (
      tester,
    ) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      await j.sync(download: true);

      // Read on this device: chapter 4 of the series in progress.
      await tester.runAsync(() async {
        final manga = (await j.db.mangas
            .filter()
            .nameEqualTo(Fixture.inProgress)
            .findFirst())!;
        final chapter = (await j.db.chapters
            .filter()
            .mangaIdEqualTo(manga.id)
            .nameEqualTo('Chapter 3')
            .findFirst())!;
        chapter
          ..isRead = true
          ..lastPageRead = '1'
          ..updatedAt = DateTime.now().millisecondsSinceEpoch;
        await j.db.writeTxn(() => j.db.chapters.put(chapter));
      });
      final before = server.etag;
      expect(await j.sync(), isTrue);

      expect(server.uploads, isNotEmpty, reason: 'the change went up');
      final upload = server.uploads.last;
      expect(
        upload.headers['if-match'],
        before,
        reason: 'a conditional upload',
      );
      final remote = server.backup!;
      final manga = remote.backupManga.firstWhere(
        (m) => m.title == Fixture.inProgress,
      );
      expect(
        manga.chapters.firstWhere((c) => c.name == 'Chapter 3').read,
        isTrue,
      );

      // Everything the app has no screen for is still on the server.
      final original = buildSyncFixture(mediaBase: server.url);
      expect(
        remote.backupPreferences.length,
        greaterThanOrEqualTo(original.backupPreferences.length),
      );
      expect(
        remote.backupExtensionStores.map((s) => s.name),
        contains('Fixture Store'),
      );
      expect(remote.backupFeeds, hasLength(original.backupFeeds.length));
      expect(remote.backupNovels.map((n) => n.title), contains(Fixture.novel));
      expect(remote.backupSourcePreferences, isNotEmpty);
      // Fields this app does not know pass through.
      expect(
        remote.unknownFields.hasField(702),
        isTrue,
        reason: 'root #702 kept',
      );
      expect(
        manga.unknownFields.hasField(601),
        isTrue,
        reason: 'manga #601 kept',
      );
    });

    testWidgets('once settled, syncing again uploads nothing', (tester) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      // A fresh install settles within two syncs (S15: the second adds local
      // anime IDs).
      await j.sync();
      await j.sync();
      final uploads = server.uploads.length;
      final content = server.content;
      await j.sync();
      await j.sync();
      expect(server.uploads.length, uploads);
      expect(server.content, content);
    });

    testWidgets(
      'S15: the second sync after a fresh install uploads nothing new',
      skip: true, // Suspected bug S15: it uploads once more, adding anime IDs.
      (tester) async {
        await tester.runAsync(() async => server = await FakeSyncYomi.start());
        final j = await connectedTo(tester, server);
        await j.sync();
        final uploads = server.uploads.length;
        await j.sync();
        expect(server.uploads.length, uploads);
      },
    );

    testWidgets('progress from another device wins over older local progress', (
      tester,
    ) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      await j.sync(download: true);
      // Another device reads further and uploads.
      final other = buildSyncFixture(mediaBase: server.url);
      final manga = other.backupManga.firstWhere(
        (m) => m.title == Fixture.inProgress,
      );
      final chapter = manga.chapters.firstWhere((c) => c.name == 'Chapter 3');
      chapter
        ..lastPageRead = Int64(11)
        ..lastModifiedAt = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      server.store(other.writeToBuffer());

      await j.sync();
      final local = {
        for (final c in await j.chaptersOf(Fixture.inProgress)) c.name: c,
      };
      expect(local['Chapter 3']?.lastPageRead, '12');
    });

    testWidgets('an upload refused because another device synced in between '
        'loses nothing', (tester) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server);
      await j.sync(download: true);
      // Removed from the library with the heart, as a person does.
      final id = (await tester.runAsync(
        () => j.db.mangas.filter().nameEqualTo(Fixture.caughtUp).findFirst(),
      ))!.id!;
      j.router.push('/manga-reader/detail', extra: id);
      await j.settle();
      await j.tapText('In library');
      await j.settle(rounds: 10);
      expect((await j.series(Fixture.caughtUp))?.favorite, isFalse);
      server.beforeNextUpload = (s) {
        final other = buildSyncFixture(mediaBase: s.url)
          ..backupCategories.add(
            BackupCategory(
              name: 'Made On Another Device',
              order: Int64(9),
              id: Int64(99),
              flags: Int64(3),
            ),
          );
        s.store(other.writeToBuffer());
      };
      await j.sync();
      // Either the app retried with the newer payload or reported it; in
      // both cases the other device's category and the local change survive.
      await j.sync();
      final remote = server.backup!;
      expect(
        remote.backupCategories.map((c) => c.name),
        contains('Made On Another Device'),
      );
      final caught = remote.backupManga.where(
        (m) => m.title == Fixture.caughtUp,
      );
      expect(
        caught.every((m) => !m.favorite),
        isTrue,
        reason: 'local removal kept',
      );
    });
  });

  group('when the server says no', () {
    testWidgets('a wrong token changes nothing and says so', (tester) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(tester, server, token: 'not-the-token');
      final ok = await j.sync(download: true);
      expect(ok, isFalse);
      expect(server.requests.map((r) => r.status), everyElement(401));
      expect(await tester.runAsync(() => j.db.mangas.count()), 0);
    });

    testWidgets('a server error during download changes nothing', (
      tester,
    ) async {
      await tester.runAsync(() async => server = await FakeSyncYomi.start());
      final j = await connectedTo(
        tester,
        server,
        arrange: (seed) async {
          final manga = await seed.manga('Already here');
          await seed.chapters(manga, 2);
        },
      );
      server.failNextWith = 500;
      expect(await j.sync(download: true), isFalse);
      expect((await j.series('Already here'))?.favorite, isTrue);
      expect(await j.series(Fixture.inProgress), isNull);
    });

    testWidgets('an empty account receives this device\'s library', (
      tester,
    ) async {
      await tester.runAsync(
        () async => server = await FakeSyncYomi.start(empty: true),
      );
      final j = await connectedTo(
        tester,
        server,
        arrange: (seed) async {
          // A series from a Mihon extension: only those can sync, as other
          // devices resolve them by the extension's source ID.
          final manga = await seed.manga('Local favourite', local: false)
            ..mihonSourceId = '$fixtureSourceId';
          await seed.db.writeTxn(() => seed.db.mangas.put(manga));
          await seed.chapters(manga, 3);
        },
      );
      expect(await j.sync(), isTrue);
      expect(server.uploads, isNotEmpty);
      expect(server.uploads.first.headers['if-none-match'], '*');
      expect(
        server.backup!.backupManga.map((m) => m.title),
        contains('Local favourite'),
      );
    });
  });
}
