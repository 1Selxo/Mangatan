// What a desktop does that a phone does not: the window is closed with the
// process (no dispose, no "paused"), resized at any moment, and the reading
// mode is switched mid-chapter from the bottom bar. The library category bug
// (fixed 2026-11-21) was exactly "saved on dispose, lost on window close".
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

const _modeNames = {
  ReaderMode.vertical: 'Vertical',
  ReaderMode.ltr: 'Left to Right',
  ReaderMode.rtl: 'Right to Left',
  ReaderMode.verticalContinuous: 'Vertical continuous',
  ReaderMode.webtoon: 'Webtoon',
  ReaderMode.horizontalContinuous: 'Horizontal continuous',
};

void main() {
  group('closing the window', () {
    for (final mode in [ReaderMode.ltr, ReaderMode.webtoon]) {
      testWidgets(
        'S4 ${mode.name}: closing the window mid-chapter keeps the '
        'page for next time',
        skip: true, // Suspected bug S4: the page is saved only on dispose.
        (tester) async {
          late int id;
          final j = await Journey.start(
            tester,
            arrange: (seed) async {
              await seed.settings((s) => s.defaultReaderMode = mode);
              final manga = await seed.manga('Kuso Onna');
              id = (await seed.chapters(manga, 1, pages: 12)).first.id!;
            },
          );
          await j.tapText('Kuso Onna');
          await j.openChapter('Chapter 1');
          for (var i = 0; i < 4; i++) {
            await j.nextPage();
          }
          final leftOn = j.pageIndicator;
          // Someone reads a while, then closes the window.
          await j.wait(const Duration(seconds: 5));
          await j.kill();

          expect(
            await j.savedPage(id),
            isNot(anyOf('', '1')),
            reason: 'left on $leftOn',
          );
          await j.tapText('Kuso Onna');
          await j.openChapter('Chapter 1');
          expect(j.pageIndicator, leftOn);
        },
      );
    }

    testWidgets('closing the window mid-chapter keeps it in History and the '
        'Continue shelf', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          await seed.chapters(manga, 2, pages: 6);
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 2');
      await j.nextPage();
      await j.wait(const Duration(seconds: 5));
      await j.kill();
      await j.go('/history');
      await j.waitFor(find.text('Kuso Onna'));
    });

    testWidgets('a chapter read to the end is still read after the window is '
        'closed', (tester) async {
      late int id;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          id = (await seed.chapters(manga, 2, pages: 3)).first.id!;
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.nextPage();
      await j.nextPage();
      await j.wait(const Duration(seconds: 5));
      await j.kill();
      expect(await j.isRead(id), isTrue);
    });
  });

  group('switching the reading mode mid-chapter', () {
    for (final to in [
      ReaderMode.verticalContinuous,
      ReaderMode.webtoon,
      ReaderMode.rtl,
      ReaderMode.horizontalContinuous,
    ]) {
      testWidgets(
        '${to.isContinuous && to != ReaderMode.webtoon ? 'S6 ' : ''}left to right → ${to.name} stays on the same page',
        // Suspected bug S6: vertical and horizontal continuous land a page early.
        skip: to.isContinuous && to != ReaderMode.webtoon,
        (tester) async {
          final j = await Journey.start(
            tester,
            arrange: (seed) async {
              await seed.settings((s) => s.defaultReaderMode = ReaderMode.ltr);
              final manga = await seed.manga('Kuso Onna');
              await seed.chapters(manga, 1, pages: 12);
            },
          );
          await j.tapText('Kuso Onna');
          await j.openChapter('Chapter 1');
          for (var i = 0; i < 4; i++) {
            await j.nextPage();
          }
          expect(j.pageIndicator, '5 / 12');
          await j.showReaderBars();
          await j.tap(
            find.byWidgetPredicate(
              (w) =>
                  w is Tooltip && (w.message ?? '').startsWith('Reading mode'),
            ),
          );
          await j.tap(find.text(_modeNames[to]!).hitTestable().last);
          await j.settle(rounds: 15);
          // The picker closes itself on a choice; close it only if it stayed.
          if (find.text('Set as default').hitTestable().evaluate().isNotEmpty) {
            await j.key(LogicalKeyboardKey.escape);
          }
          await j.dismissTapZoneGuide();
          await j.settle(rounds: 10);
          expect(
            j.pageIndicator,
            '5 / 12',
            reason: 'after switching to ${to.name}',
          );
        },
      );
    }
  });

  group('resizing the window', () {
    for (final mode in [
      ReaderMode.verticalContinuous,
      ReaderMode.webtoon,
      ReaderMode.horizontalContinuous,
      ReaderMode.rtl,
    ]) {
      testWidgets(
        '${mode == ReaderMode.webtoon ? 'S5 ' : ''}${mode.name}: maximizing mid-chapter keeps the page',
        // Suspected bug S5: webtoon keeps the pixel offset, not the page.
        skip: mode == ReaderMode.webtoon,
        (tester) async {
          final j = await Journey.start(
            tester,
            window: const Size(800, 600),
            arrange: (seed) async {
              await seed.settings((s) => s.defaultReaderMode = mode);
              final manga = await seed.manga('Kuso Onna');
              await seed.chapters(manga, 1, pages: 12);
            },
          );
          await j.tapText('Kuso Onna');
          await j.openChapter('Chapter 1');
          for (var i = 0; i < 4; i++) {
            await j.nextPage();
          }
          final before = j.pageIndicator;
          await j.resize(const Size(1920, 1080));
          await j.settle(rounds: 15);
          expect(
            j.pageIndicator,
            before,
            reason: '${mode.name} after maximizing',
          );
          await j.resize(const Size(800, 600));
          await j.settle(rounds: 15);
          expect(
            j.pageIndicator,
            before,
            reason: '${mode.name} after restoring',
          );
        },
      );
    }
  });

  group('split wide pages', () {
    testWidgets('turning split wide pages off unsplits the pages already '
        'shown (fixed by hand 2026-11-08)', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.settings(
            (s) => s
              ..defaultReaderMode = ReaderMode.ltr
              ..splitWidePages = true,
          );
          final manga = await seed.manga('Kuso Onna');
          final folder = await seed.pageFolder(6, wideEvery3rd: true);
          final chapter = Chapter(
            mangaId: manga.id,
            name: 'Chapter 1',
            chapterNumber: 1,
            archivePath: folder.path,
          )..manga.value = manga;
          await seed.db.writeTxn(() async {
            await seed.db.chapters.put(chapter);
            await chapter.manga.save();
          });
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      // Page 3 is wide: split, it shows as two halves under one number.
      Future<int> pressesThroughPage3() async {
        while (j.pageIndicator != '3 / 6') {
          await j.key(
            int.parse(j.pageIndicator!.split(' ').first) < 3
                ? LogicalKeyboardKey.space
                : LogicalKeyboardKey.arrowUp,
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)),
          );
          await j.settle(rounds: 3);
        }
        var presses = 0;
        while (j.pageIndicator == '3 / 6' && presses < 4) {
          await j.key(LogicalKeyboardKey.space);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)),
          );
          await j.settle(rounds: 3);
          presses++;
        }
        return presses;
      }

      expect(await pressesThroughPage3(), 2, reason: 'split: two halves');
      await j.showReaderBars();
      await j.tapTooltip('Settings');
      await j.scrollTo(find.text('Split wide pages'));
      await j.tap(find.text('Split wide pages').hitTestable().last);
      await j.key(LogicalKeyboardKey.escape);
      await j.settle(rounds: 10);
      expect(await pressesThroughPage3(), 1, reason: 'unsplit: one page');
    });
  });
}
