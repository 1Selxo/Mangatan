// Journeys through the manga reader: opening, turning pages, leaving, coming
// back where you were, in every reading mode. These are the checks repeated
// by hand after the upstream reader rewrite (2026-11-08) and the Chimahon
// progress fixes (2026-11-21).
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

void main() {
  group('reading and coming back', () {
    testWidgets('pages turn with the keyboard and the page you leave on is '
        'saved and shown on the manga page', (tester) async {
      late int chapterId;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          chapterId = (await seed.chapters(manga, 2, pages: 6)).first.id!;
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      expect(j.pageIndicator, '1 / 6');

      await j.key(LogicalKeyboardKey.arrowDown);
      await j.key(LogicalKeyboardKey.space);
      await j.key(LogicalKeyboardKey.arrowRight);
      expect(j.pageIndicator, '4 / 6');
      await j.key(LogicalKeyboardKey.arrowUp);
      expect(j.pageIndicator, '3 / 6');

      await j.leaveReader();
      expect(await j.savedPage(chapterId), '3');
      await j.waitFor(find.text('Page 3'));
    });

    testWidgets('a chapter opened from the list resumes at its saved page', (
      tester,
    ) async {
      late int chapterId;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          final chapters = await seed.chapters(manga, 2, pages: 6);
          chapterId = chapters[1].id!;
          chapters[1].lastPageRead = '5';
          await seed.db.writeTxn(() => seed.db.chapters.put(chapters[1]));
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 2');
      expect(j.pageIndicator, '5 / 6');
      // Opening must not write over the progress it opened at.
      expect(await j.savedPage(chapterId), '5');
    });

    testWidgets('progress that arrives by sync while the manga page is open '
        'is where the chapter opens (fix: resume manga chapters at synced '
        'pages)', (tester) async {
      late int chapterId;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          chapterId = (await seed.chapters(manga, 1, pages: 6)).first.id!;
        },
      );
      await j.tapText('Kuso Onna');
      await j.waitFor(find.text('Chapter 1'));

      // A Chimahon download-only sync writes the other device's page.
      await tester.runAsync(() async {
        final chapter = (await j.db.chapters.get(chapterId))!
          ..lastPageRead = '5';
        await j.db.writeTxn(() => j.db.chapters.put(chapter));
      });
      await j.waitFor(find.text('Page 5'));

      await j.openChapter('Chapter 1');
      expect(j.pageIndicator, '5 / 6');
      expect(await j.savedPage(chapterId), '5');
    });

    testWidgets('reading past the last page continues into the next chapter '
        'and marks the first one read', (tester) async {
      late List<int> ids;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          ids = [
            for (final c in await seed.chapters(manga, 2, pages: 3)) c.id!,
          ];
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      for (
        var i = 0;
        i < 6 && !find.text('Chapter 2').evaluate().isNotEmpty;
        i++
      ) {
        await j.key(LogicalKeyboardKey.space);
        await j.settle(rounds: 4);
      }
      expect(
        find.text('Chapter 2'),
        findsWidgets,
        reason: '${j.visibleTexts()}',
      );
      await j.leaveReader();
      expect(await j.isRead(ids[0]), isTrue);
    });

    testWidgets('next and previous chapter keys move between chapters', (
      tester,
    ) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          await seed.chapters(manga, 3, pages: 3);
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 2');
      await j.key(LogicalKeyboardKey.keyN);
      await j.settle(rounds: 10);
      expect(find.text('Chapter 3'), findsWidgets);
      await j.key(LogicalKeyboardKey.keyP);
      await j.settle(rounds: 10);
      await j.key(LogicalKeyboardKey.keyP);
      await j.settle(rounds: 10);
      expect(find.text('Chapter 1'), findsWidgets);
    });

    testWidgets('switching chapter and leaving while OCR is still reading the '
        'chapter is clean', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          await seed.chapters(manga, 2, pages: 6);
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.key(LogicalKeyboardKey.space);
      // Next chapter: its reader replaces this one while the scan runs.
      await j.key(LogicalKeyboardKey.pageDown);
      // Any framework error during the teardown fails the test.
      await j.leaveReader();
      expect(find.byType(MangaReaderView), findsNothing);
    });
  });

  group('every reading mode', () {
    for (final mode in ReaderMode.values) {
      testWidgets('${mode.name}: opens, turns forward and back with the '
          'keyboard, and saves the page', (tester) async {
        late int chapterId;
        final j = await Journey.start(
          tester,
          arrange: (seed) async {
            await seed.settings((s) => s.defaultReaderMode = mode);
            final manga = await seed.manga('Kuso Onna');
            chapterId = (await seed.chapters(manga, 1, pages: 12)).first.id!;
          },
        );
        await j.tapText('Kuso Onna');
        await j.openChapter('Chapter 1');
        expect(j.pageIndicator, '1 / 12');

        await j.nextPage();
        final forward = await j.nextPage();
        expect(forward, '3 / 12', reason: mode.name);
        final back = await j.previousPage();
        expect(back, '2 / 12', reason: mode.name);

        await j.leaveReader();
        expect(await j.savedPage(chapterId), '2');
      });

      testWidgets('${mode.name}: reopening resumes at the saved page', (
        tester,
      ) async {
        final j = await Journey.start(
          tester,
          arrange: (seed) async {
            await seed.settings((s) => s.defaultReaderMode = mode);
            final manga = await seed.manga('Kuso Onna');
            final chapter = (await seed.chapters(manga, 1, pages: 12)).first
              ..lastPageRead = '4';
            await seed.db.writeTxn(() => seed.db.chapters.put(chapter));
          },
        );
        await j.tapText('Kuso Onna');
        await j.openChapter('Chapter 1');
        await j.settle(rounds: 10);
        expect(
          j.pageIndicator,
          '4 / 12',
          reason: '${mode.name} ${j.visibleTexts()}',
        );
      });
    }
  });

  group('reader at different window sizes', () {
    for (final (label, size) in [
      ('phone', phoneWindow),
      ('small window', const Size(640, 480)),
      ('wide desktop', const Size(1920, 1080)),
    ]) {
      testWidgets('the reader opens and turns pages on a $label', (
        tester,
      ) async {
        final j = await Journey.start(
          tester,
          window: size,
          arrange: (seed) async {
            final manga = await seed.manga('Kuso Onna');
            await seed.chapters(manga, 1, pages: 4);
          },
        );
        await j.tapText('Kuso Onna');
        await j.openChapter('Chapter 1');
        expect(await j.nextPage(), '2 / 4');
      });
    }

    testWidgets('maximizing the window mid-chapter keeps the page', (
      tester,
    ) async {
      final j = await Journey.start(
        tester,
        window: const Size(800, 600),
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          await seed.chapters(manga, 1, pages: 6);
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.nextPage();
      await j.nextPage();
      await j.resize(const Size(1920, 1080));
      await j.settle(rounds: 10);
      expect(j.pageIndicator, '3 / 6');
    });
  });
}
