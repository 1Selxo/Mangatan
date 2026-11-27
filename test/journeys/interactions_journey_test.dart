// Everyday interactions across History, Updates, the library's search and
// filters, the reader's own controls and category management: the many small
// things clicked through by hand after each merge.
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

extension on Journey {
  /// Confirms a dialog or sheet by the last visible button labelled with one
  /// of [labels] (dialogs put their confirming action last).
  Future<void> confirm(List<String> labels) async {
    await settle(rounds: 4);
    for (final label in labels) {
      final button = find.text(label).hitTestable();
      if (button.evaluate().isNotEmpty) {
        await tap(button.last);
        return;
      }
    }
  }
}

void main() {
  group('history', () {
    Future<(Journey, List<int>)> withHistory(WidgetTester tester) async {
      late List<int> ids;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final a = await seed.manga('Kuso Onna');
          final b = await seed.manga('Watanare');
          final ac = await seed.chapters(a, 2, pages: 6);
          final bc = await seed.chapters(b, 1, pages: 4);
          ac[1].lastPageRead = '4';
          await seed.db.writeTxn(() => seed.db.chapters.put(ac[1]));
          await seed.history(a, ac[1]);
          await seed.history(
            b,
            bc[0],
            at: DateTime.now().subtract(const Duration(days: 2)),
          );
          ids = [ac[1].id!, bc[0].id!];
        },
      );
      await j.go('/history');
      await j.waitFor(find.text('Kuso Onna'));
      return (j, ids);
    }

    testWidgets('tapping an entry resumes its chapter at the saved page', (
      tester,
    ) async {
      final (j, _) = await withHistory(tester);
      await j.tapText('Kuso Onna');
      await j.waitFor(find.byType(MangaReaderView));
      await j.waitFor(find.textContaining(RegExp(r'^\d+ / \d+$')));
      await j.settle(rounds: 10);
      expect(j.pageIndicator, '4 / 6');
      expect(find.text('Chapter 2'), findsWidgets);
    });

    testWidgets('removing one entry removes only that one', (tester) async {
      final (j, _) = await withHistory(tester);
      await j.tap(find.byTooltip('Remove').first);
      await j.confirm(['Remove', 'OK', 'Yes']);
      // Removal waits out its Undo toast before it is written.
      await j.wait(const Duration(seconds: 8));
      final left = await tester.runAsync(() => j.db.historys.count());
      expect(left, 1);
      expect(
        find.text('Kuso Onna').hitTestable().evaluate().length +
            find.text('Watanare').hitTestable().evaluate().length,
        1,
      );
    });

    testWidgets('removing everything empties History', (tester) async {
      final (j, _) = await withHistory(tester);
      await j.tapTooltip('Remove everything');
      await j.confirm(['Remove', 'OK', 'Yes']);
      await j.wait(const Duration(seconds: 8));
      expect(await tester.runAsync(() => j.db.historys.count()), 0);
      expect(find.text('Watanare').hitTestable(), findsNothing);
    });

    testWidgets('reading a chapter puts it at the top of History', (
      tester,
    ) async {
      final (j, _) = await withHistory(tester);
      await j.go('/MangaLibrary');
      // The grid's tile; the Continue shelf only opens from its cover.
      await j.tap(find.text('Watanare').last);
      await j.openChapter('Chapter 1');
      await j.nextPage();
      await j.leaveReader();
      await j.go('/history');
      await j.waitFor(find.text('Watanare'));
      final watanare = tester.getTopLeft(find.text('Watanare').last).dy;
      final kuso = tester.getTopLeft(find.text('Kuso Onna').last).dy;
      expect(watanare, lessThan(kuso));
    });
  });

  group('updates', () {
    testWidgets('an update opens its chapter, and Remove everything clears '
        'the list', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final m = await seed.manga('Kuso Onna');
          final c = await seed.chapters(m, 3, pages: 3);
          await seed.update(m, c[2]);
          await seed.update(
            m,
            c[1],
            at: DateTime.now().subtract(const Duration(days: 3)),
          );
        },
      );
      await j.go('/updates');
      await j.waitFor(find.text('Chapter 3'));
      await j.tapText('Chapter 3');
      await j.waitFor(find.byType(MangaReaderView));
      expect(find.text('Chapter 3'), findsWidgets);
      await j.leaveReaderTo(find.text('Chapter 2'));
      await j.tapTooltip('Remove everything');
      await j.confirm(['Remove', 'OK', 'Yes']);
      await j.wait(const Duration(seconds: 8));
      expect(await tester.runAsync(() => j.db.updates.count()), 0);
    });
  });

  group('library search and filters', () {
    Future<Journey> library(WidgetTester tester) => Journey.start(
      tester,
      arrange: (seed) async {
        final read = await seed.manga('Everything read');
        await seed.chapter(read, 'Chapter 1', number: 1, read: true);
        final started = await seed.manga('Half way');
        await seed.chapter(started, 'Chapter 1', number: 1, read: true);
        await seed.chapter(started, 'Chapter 2', number: 2);
        final fresh = await seed.manga('Brand new');
        await seed.chapter(fresh, 'Chapter 1', number: 1, bookmarked: true);
      },
    );

    testWidgets('search narrows the library to matching titles and clearing '
        'it brings them back', (tester) async {
      final j = await library(tester);
      await j.tap(find.byTooltip('Search').hitTestable());
      await tester.enterText(find.byType(TextField).last, 'half');
      await j.wait(const Duration(seconds: 1));
      expect(find.text('Half way'), findsWidgets);
      expect(find.text('Brand new').hitTestable(), findsNothing);
      await tester.enterText(find.byType(TextField).last, '');
      await j.wait(const Duration(seconds: 1));
      expect(find.text('Brand new'), findsWidgets);
    });

    testWidgets('search finds titles by genre too', (tester) async {
      final j = await library(tester);
      await j.tap(find.byTooltip('Search').hitTestable());
      await tester.enterText(find.byType(TextField).last, 'romance');
      await j.wait(const Duration(seconds: 1));
      expect(find.text('Half way'), findsWidgets);
    });

    testWidgets('the unread filter hides series with nothing left to read', (
      tester,
    ) async {
      final j = await library(tester);
      await j.tapTooltip('Filter');
      await j.tapText('Unread');
      await j.key(LogicalKeyboardKey.escape);
      await j.settle(rounds: 8);
      expect(find.text('Everything read').hitTestable(), findsNothing);
      expect(find.text('Half way'), findsWidgets);
      expect(find.text('Brand new'), findsWidgets);
    });

    testWidgets('filters survive a restart', (tester) async {
      final j = await library(tester);
      await j.tapTooltip('Filter');
      await j.tapText('Unread');
      await j.key(LogicalKeyboardKey.escape);
      await j.restart();
      await j.waitFor(find.text('Half way'));
      expect(find.text('Everything read').hitTestable(), findsNothing);
    });

    for (final display in ['List', 'Compact grid']) {
      testWidgets('the $display display shows and opens the series', (
        tester,
      ) async {
        final j = await library(tester);
        await j.tapTooltip('Filter');
        await j.tapText('Display');
        await j.tapText(display);
        await j.key(LogicalKeyboardKey.escape);
        await j.settle(rounds: 8);
        await j.tapText('Half way');
        await j.waitFor(chapterCount);
      });
    }
  });

  testWidgets(
    // Was S3: only the cover opened it.
    'in the Comfortable grid, the title under a cover opens the series',
    (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.settings(
            (s) => s.displayType = DisplayType.comfortableGrid,
          );
          await seed.manga('Half way');
        },
      );
      await j.tapText('Half way');
      await j.waitFor(chapterCount);
    },
  );

  group('reader controls', () {
    Future<Journey> inReader(WidgetTester tester, {int pages = 8}) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final m = await seed.manga('Kuso Onna');
          await seed.chapters(m, 3, pages: pages);
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.showReaderBars();
      return j;
    }

    testWidgets('page previews jump to the page tapped', (tester) async {
      final j = await inReader(tester);
      await j.tapTooltip('Page previews');
      await j.waitFor(find.text('6'));
      await j.tap(find.text('6').last);
      await j.settle(rounds: 10);
      expect(j.pageIndicator, '6 / 8');
    });

    testWidgets('the chapter list in the reader switches chapter', (
      tester,
    ) async {
      final j = await inReader(tester);
      await j.tapTooltip('Chapters');
      await j.waitFor(find.text('Chapter 3'));
      await j.tap(find.text('Chapter 3').last);
      await j.settle(rounds: 15);
      expect(find.text('Chapter 3'), findsWidgets);
      expect(j.pageIndicator, '1 / 8');
    });

    testWidgets('the next and previous chapter buttons', (tester) async {
      final j = await inReader(tester);
      await j.tapTooltip('Next chapter');
      await j.settle(rounds: 15);
      expect(find.text('Chapter 2'), findsWidgets);
      await j.showReaderBars();
      await j.tapTooltip('Previous chapter');
      await j.settle(rounds: 15);
      expect(find.text('Chapter 1'), findsWidgets);
    });

    testWidgets('the double page button pairs pages and back', (tester) async {
      final j = await inReader(tester);
      await j.tapTooltip('Double page');
      await j.settle(rounds: 10);
      final paired = j.pageIndicator;
      await j.nextPage();
      await j.showReaderBars();
      await j.tapTooltip('Double page');
      await j.settle(rounds: 10);
      final single = j.pageIndicator;
      expect(
        single,
        matches(RegExp(r'^\d+ / 8$')),
        reason: 'paired was $paired',
      );
    });

    testWidgets('crop borders and the reader settings sheet open cleanly', (
      tester,
    ) async {
      final j = await inReader(tester);
      await j.tapTooltip('Crop borders');
      await j.settle(rounds: 8);
      await j.tapTooltip('Crop borders');
      await j.tapTooltip('Settings');
      await j.settle(rounds: 8);
      await j.key(LogicalKeyboardKey.escape);
      await j.nextPage();
    });

    testWidgets('the keyboard shortcuts list opens with ? and closes with '
        'Escape, and the arrows still turn pages after', (tester) async {
      final j = await inReader(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await j.settle(rounds: 6);
      expect(find.text('Keyboard shortcuts'), findsWidgets);
      await j.key(LogicalKeyboardKey.escape);
      expect(find.byType(MangaReaderView), findsOneWidget);
      expect(await j.nextPage(), '2 / 8');
    });

    testWidgets('hiding and showing the bars with M keeps the page keys '
        'working', (tester) async {
      final j = await inReader(tester);
      await j.key(LogicalKeyboardKey.keyM);
      await j.key(LogicalKeyboardKey.arrowRight);
      await j.key(LogicalKeyboardKey.keyM);
      await j.key(LogicalKeyboardKey.arrowRight);
      expect(j.pageIndicator, '3 / 8');
    });

    testWidgets('a bookmark set in the reader shows on the manga page', (
      tester,
    ) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final m = await seed.manga('Kuso Onna');
          await seed.chapters(m, 1, pages: 3);
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.showReaderBars();
      final bookmark = find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            (w.message ?? '').toLowerCase().contains('bookmark'),
      );
      await j.tap(bookmark);
      await j.leaveReader();
      final chapter = await tester.runAsync(
        () => j.db.chapters.filter().nameEqualTo('Chapter 1').findFirst(),
      );
      expect(chapter!.isBookmarked, isTrue);
    });
  });

  group('categories', () {
    testWidgets('a category added in Categories becomes a library tab', (
      tester,
    ) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.category('Romance');
          await seed.manga('Kuso Onna');
        },
      );
      await j.go('/more');
      await j.tapText('Categories');
      await j.waitFor(find.text('Romance'));
      final add = find.byType(FloatingActionButton);
      await j.tap(add);
      await tester.enterText(find.byType(TextField).last, 'Comedy');
      await j.confirm(['Add', 'OK', 'Save']);
      await j.waitFor(find.text('Comedy'));
      final saved = await tester.runAsync(
        () => j.db.categorys.filter().nameEqualTo('Comedy').findFirst(),
      );
      expect(saved, isNotNull);
    });
  });
}

extension on Journey {
  /// Leaves the reader back to wherever it was opened from.
  Future<void> leaveReaderTo(Finder landmark) async {
    await key(LogicalKeyboardKey.escape);
    await waitFor(landmark);
  }
}
