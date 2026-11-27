// Data as it arrives from syncs, imports and old versions, not as the app
// writes it: empty, missing, corrupt or out of range. Upstream's crash
// reports (#1048 RangeError on an empty list, the "Null check operator"
// family, #848 restore emptying the library) come from exactly this. Each
// journey only has to stay usable; any exception or error view fails it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';
import 'package:material_ui/material_ui.dart' show Scrollable;
import 'package:path/path.dart' as p;

import 'harness/journey.dart';
import 'harness/reader.dart';

Future<Chapter> folderChapter(
  Seed seed,
  Manga manga,
  Directory folder, {
  String name = 'Chapter 1',
  String lastPageRead = '',
}) async {
  final chapter = Chapter(
    mangaId: manga.id,
    name: name,
    chapterNumber: 1,
    archivePath: folder.path,
    lastPageRead: lastPageRead,
  )..manga.value = manga;
  await seed.db.writeTxn(() async {
    await seed.db.chapters.put(chapter);
    await chapter.manga.save();
  });
  return chapter;
}

void main() {
  testWidgets('a series without any chapter opens, and offers nothing to '
      'resume', (tester) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        await seed.settings((s) => s.libraryShowContinueReadingButton = true);
        await seed.manga('Empty series');
      },
    );
    await j.tapText('Empty series');
    await j.waitFor(find.text('0 chapters'));
  });

  testWidgets('a chapter whose folder was deleted from disk says so instead '
      'of crashing', (tester) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Moved files');
        final folder = await seed.pageFolder(3);
        await folderChapter(seed, manga, folder);
        await folder.delete(recursive: true);
      },
    );
    await j.tapText('Moved files');
    await j.waitFor(chapterCount);
    j.checkHealth = false; // An error view is the right answer here.
    await j.tap(find.text('Chapter 1'));
    await j.settle(rounds: 20);
    // Still a usable app: back to the series page.
    await j.key(LogicalKeyboardKey.escape);
    await j.settle(rounds: 10);
    await j.waitFor(chapterCount);
  });

  testWidgets('a chapter folder without any image opens without crashing', (
    tester,
  ) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Empty folder');
        final folder = Directory(p.join(seed.directory.path, 'empty-chapter'))
          ..createSync();
        await folderChapter(seed, manga, folder);
      },
    );
    await j.tapText('Empty folder');
    await j.waitFor(chapterCount);
    j.checkHealth = false;
    await j.tap(find.text('Chapter 1'));
    await j.settle(rounds: 20);
    await j.key(LogicalKeyboardKey.escape);
    await j.settle(rounds: 10);
    await j.waitFor(chapterCount);
  });

  testWidgets(
    'a corrupt page shows as failed and the rest of the chapter '
    'still reads',
    // Was S11: OCR's precacheImage reported the failed page as an uncaught
    // error (an "error report" in the app).
    (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Corrupt page');
          final folder = await seed.pageFolder(4);
          File(p.join(folder.path, '002.png'))
              .writeAsBytesSync([1, 2, 3, 4, 5]);
          await folderChapter(seed, manga, folder);
        },
      );
      await j.tapText('Corrupt page');
      await j.openChapter('Chapter 1');
      j.checkHealth = false; // The failed page may show an error card.
      await j.nextPage();
      await j.nextPage();
      expect(j.pageIndicator, '3 / 4');
    },
  );

  testWidgets('a saved page beyond the end of the chapter (a sync from '
      'another copy) opens at a real page', (tester) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Too far');
        final folder = await seed.pageFolder(4);
        await folderChapter(seed, manga, folder, lastPageRead: '57');
      },
    );
    await j.tapText('Too far');
    await j.openChapter('Chapter 1');
    final page = int.parse(j.pageIndicator!.split(' ').first);
    expect(page, inInclusiveRange(1, 4), reason: j.pageIndicator);
  });

  testWidgets('a saved page that is not a number opens at the start', (
    tester,
  ) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Garbled');
        final folder = await seed.pageFolder(4);
        await folderChapter(seed, manga, folder, lastPageRead: 'abc');
      },
    );
    await j.tapText('Garbled');
    await j.openChapter('Chapter 1');
    expect(j.pageIndicator, '1 / 4');
  });

  testWidgets('history and updates with zero, empty and future dates show '
      'sensible times', (tester) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        for (final (name, date) in [
          ('Zero date', '0'),
          (
            'Future date',
            '${DateTime.now().add(const Duration(days: 400)).millisecondsSinceEpoch}',
          ),
        ]) {
          final manga = await seed.manga(name);
          final chapter = (await seed.chapters(manga, 1)).first;
          final history = History(
            itemType: ItemType.manga,
            chapterId: chapter.id,
            mangaId: manga.id,
            date: date,
          )..chapter.value = chapter;
          final update = Update(
            mangaId: manga.id,
            chapterName: chapter.name,
            date: date,
          )..chapter.value = chapter;
          await seed.db.writeTxn(() async {
            await seed.db.historys.put(history);
            await history.chapter.save();
            await seed.db.updates.put(update);
            await update.chapter.save();
          });
        }
      },
    );
    await j.go('/history');
    await j.settle(rounds: 10);
    await j.go('/updates');
    await j.settle(rounds: 10);
    // The health check fails on "20000 days ago" and the like by itself.
  });

  testWidgets(
    'S10: History still opens with one malformed date among its entries',
    skip: true, // Suspected bug S10: a FormatException takes the tab down.
    (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          for (final (name, date) in [
            ('Fine', '${DateTime.now().millisecondsSinceEpoch}'),
            ('Broken', ''),
          ]) {
            final manga = await seed.manga(name);
            final chapter = (await seed.chapters(manga, 1)).first;
            final history = History(
              itemType: ItemType.manga,
              chapterId: chapter.id,
              mangaId: manga.id,
              date: date,
            )..chapter.value = chapter;
            await seed.db.writeTxn(() async {
              await seed.db.historys.put(history);
              await history.chapter.save();
            });
          }
        },
      );
      await j.go('/history');
      await j.waitFor(find.text('Fine'));
    },
  );

  testWidgets('chapters with odd names and numbers list and open', (
    tester,
  ) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Odd chapters');
        for (final (name, number) in [
          ('', null),
          ('Chapter -1', -1.0),
          ('Chapter 1e9', 1e9),
          ('Chapter 2', 2.0),
          ('Chapter 2', 2.0),
          ('  ', 3.0),
          ('第3話 「とても長いサブタイトルがここに入ります」 そしてもっと長く続いていく', 3.5),
        ]) {
          await seed.chapter(manga, name, number: number, pages: 2);
        }
      },
    );
    await j.tapText('Odd chapters');
    await j.waitFor(chapterCount);
    await j.openChapter('Chapter 2');
    await j.key(LogicalKeyboardKey.keyN);
    await j.settle(rounds: 10);
    await j.key(LogicalKeyboardKey.keyP);
    await j.settle(rounds: 10);
    expect(find.byType(MangaReaderView), findsOneWidget);
  });

  testWidgets('a series with 500 chapters opens and scrolls to the oldest', (
    tester,
  ) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Long runner');
        final chapters = [
          for (var i = 1; i <= 500; i++)
            Chapter(
              mangaId: manga.id,
              name: 'Chapter $i',
              chapterNumber: i.toDouble(),
              url: '/c/$i',
            )..manga.value = manga,
        ];
        await seed.db.writeTxn(() async {
          await seed.db.chapters.putAll(chapters);
          for (final c in chapters) {
            await c.manga.save();
          }
        });
      },
    );
    await j.tapText('Long runner');
    await j.waitFor(find.text('500 chapters'));
    await tester.scrollUntilVisible(
      find.text('Chapter 1'),
      2000,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 200,
    );
    await j.settle(rounds: 4);
    expect(find.text('Chapter 1'), findsWidgets);
  });

  testWidgets('a series without genres opens its manga page', (tester) async {
    // Was S9: manga_detail_view.dart read `manga.genre!`, null for local
    // series whose details.json has no genre, LNReader novels without genres
    // and Aidoku entries without tags.
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('No genres');
        manga.genre = null;
        await seed.db.writeTxn(() => seed.db.mangas.put(manga));
        await seed.chapters(manga, 1, pages: 2);
      },
    );
    await j.tapText('No genres');
    await j.openChapter('Chapter 1');
  });

  testWidgets('a series whose every field but the name and genres is empty', (
    tester,
  ) async {
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = Manga(
          source: '',
          author: null,
          artist: null,
          genre: const [],
          imageUrl: '',
          lang: '',
          link: '',
          name: 'Bare',
          status: Status.unknown,
          description: null,
          sourceId: null,
          favorite: true,
          isLocalArchive: true,
        );
        await seed.db.writeTxn(() => seed.db.mangas.put(manga));
        await seed.chapters(manga, 1, pages: 2);
      },
    );
    await j.tapText('Bare');
    await j.openChapter('Chapter 1');
  });

  testWidgets(
    // Was S16: Ink.image in CoverViewWidget had no onImageError.
    'a cover that cannot be loaded is not reported as an app error',
    (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Dead cover');
          manga.imageUrl = 'https://cover.invalid/gone.jpg';
          await seed.db.writeTxn(() => seed.db.mangas.put(manga));
        },
      );
      await j.settle(rounds: 20);
      expect(find.text('Dead cover'), findsWidgets);
    },
  );
}
