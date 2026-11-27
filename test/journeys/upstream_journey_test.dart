// Journeys from bugs other people fixed or reported: upstream Mangayomi
// commits and issues (kodjodevf/mangayomi), and fork contributors. Each test
// names its source so a failure says which old bug came back.
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';
import 'package:mangayomi/providers/security_state_provider.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

/// [names] in the order they appear on screen: top to bottom, then start to
/// end, the way a library grid reads.
List<String> onScreenOrder(WidgetTester tester, List<String> names) {
  final positions = {
    for (final name in names) name: tester.getTopLeft(find.text(name).last),
  };
  return [...names]..sort((a, b) {
    final pa = positions[a]!, pb = positions[b]!;
    if ((pa.dy - pb.dy).abs() > 4) return pa.dy.compareTo(pb.dy);
    return pa.dx.compareTo(pb.dx);
  });
}

void main() {
  group('chapters and reading', () {
    testWidgets('decimal chapters are not skipped while reading '
        '(upstream #812: "Chapters like XX.1, XX.5 are being skipped")', (
      tester,
    ) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          await seed.chapter(manga, 'Chapter 1', number: 1, pages: 2);
          await seed.chapter(manga, 'Chapter 1.5', number: 1.5, pages: 2);
          await seed.chapter(manga, 'Chapter 2', number: 2, pages: 2);
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.key(LogicalKeyboardKey.keyN);
      await j.settle(rounds: 10);
      expect(
        find.text('Chapter 1.5'),
        findsWidgets,
        reason: '${j.visibleTexts()}',
      );
      expect(find.text('Chapter 2'), findsNothing);
    });

    testWidgets('the manga page lists the chapter numbers that are missing '
        '(upstream #1187)', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          for (final n in [1, 2, 5, 6]) {
            await seed.chapter(manga, 'Chapter $n', number: n.toDouble());
          }
        },
      );
      await j.tapText('Kuso Onna');
      await j.waitFor(find.text('Missing 2 chapters'));
      await j.tapText('Missing 2 chapters');
      await j.waitFor(find.text('Missing chapters'));
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets('specials and prologues are not each other\'s duplicates when '
        'duplicates are marked read (upstream 4af383cb)', (tester) async {
      late List<int> ids;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.settings((s) => s.autoReadDuplicateChapters = true);
          final manga = await seed.manga('Kuso Onna');
          ids = [
            (await seed.chapter(manga, 'Prologue', pages: 2)).id!,
            (await seed.chapter(manga, 'Special', pages: 2)).id!,
            (await seed.chapter(manga, 'Chapter 1', number: 1, pages: 2)).id!,
          ];
        },
      );
      await j.tapText('Kuso Onna');
      await j.openChapter('Special');
      await j.key(LogicalKeyboardKey.space);
      await j.key(LogicalKeyboardKey.space);
      await j.leaveReader();
      expect(await j.isRead(ids[1]), isTrue, reason: 'Special was read');
      expect(
        await j.isRead(ids[0]),
        isFalse,
        reason: 'Prologue is not a duplicate',
      );
      expect(await j.isRead(ids[2]), isFalse);
    });

    testWidgets(
      'a real duplicate (same number, other scanlator) is marked read '
      'with it',
      (tester) async {
        late List<int> ids;
        final j = await Journey.start(
          tester,
          arrange: (seed) async {
            await seed.settings((s) => s.autoReadDuplicateChapters = true);
            final manga = await seed.manga('Kuso Onna');
            ids = [
              (await seed.chapter(manga, 'Chapter 3', number: 3, pages: 2)).id!,
              (await seed.chapter(
                manga,
                'Ch. 3 (other group)',
                number: 3,
                pages: 2,
              )).id!,
            ];
          },
        );
        await j.tapText('Kuso Onna');
        await j.openChapter('Chapter 3');
        await j.key(LogicalKeyboardKey.space);
        await j.key(LogicalKeyboardKey.space);
        await j.leaveReader();
        expect(await j.isRead(ids[0]), isTrue);
        expect(await j.isRead(ids[1]), isTrue);
      },
    );

    testWidgets('swiping a chapter marks it read at once (upstream 425a19d9)', (
      tester,
    ) async {
      late int id;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          id = (await seed.chapters(manga, 2)).first.id!;
        },
      );
      await j.tapText('Kuso Onna');
      await j.waitFor(chapterCount);
      final row = await j.reach(find.text('Chapter 1'));
      // The default end-to-start swipe toggles read.
      await tester.drag(row, const Offset(-400, 0));
      await j.settle(rounds: 10);
      final swipeStart = await j.isRead(id);
      if (swipeStart != true) {
        await tester.drag(
          await j.reach(find.text('Chapter 1')),
          const Offset(400, 0),
        );
        await j.settle(rounds: 10);
      }
      expect(await j.isRead(id), isTrue);
    });

    testWidgets(
      'hiding the page number hides it in the reader (upstream #790)',
      (tester) async {
        final j = await Journey.start(
          tester,
          arrange: (seed) async {
            await seed.settings((s) => s.showPagesNumber = false);
            final manga = await seed.manga('Kuso Onna');
            await seed.chapters(manga, 1, pages: 4);
          },
        );
        await j.tapText('Kuso Onna');
        await j.tap(find.text('Chapter 1'));
        await j.waitFor(find.byType(MangaReaderView));
        await j.settle(rounds: 15);
        // The bars are hidden; only the page number overlay could show a count.
        await j.key(LogicalKeyboardKey.keyM);
        await j.key(LogicalKeyboardKey.keyM);
        expect(
          find.textContaining(RegExp(r'^\d+ / \d+$')).hitTestable(),
          findsNothing,
        );
      },
    );
  });

  group('double page mode (upstream #167, #1008, d693445c)', () {
    for (final mode in [ReaderMode.ltr, ReaderMode.rtl]) {
      testWidgets('${mode.name}: pages go in pairs and the page left on is '
          'where it reopens', (tester) async {
        late int id;
        final j = await Journey.start(
          tester,
          arrange: (seed) async {
            await seed.settings(
              (s) => s
                ..defaultReaderMode = mode
                ..defaultPageMode = PageMode.doublePage,
            );
            final manga = await seed.manga('Kuso Onna');
            id = (await seed.chapters(manga, 1, pages: 8)).first.id!;
          },
        );
        await j.tapText('Kuso Onna');
        await j.openChapter('Chapter 1');
        final first = j.pageIndicator;
        await j.nextPage();
        final second = j.pageIndicator;
        await j.nextPage();
        final third = j.pageIndicator;
        expect(
          {first, second, third}.length,
          3,
          reason: '$first $second $third',
        );
        await j.leaveReader();
        final saved = int.parse((await j.savedPage(id))!);
        // Leaving on the third spread: pages 5 and 6 (4-5 with the first page
        // alone).
        expect(
          saved,
          inInclusiveRange(4, 6),
          reason: 'saved $saved after $third',
        );

        await j.openChapter('Chapter 1');
        expect(j.pageIndicator, third, reason: 'reopened where it was left');
      });
    }
  });

  group('library', () {
    testWidgets('sorted by unread count, read titles come last '
        '(fork fd9a2d9a)', (tester) async {
      await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.settings(
            (s) =>
                s.sortLibraryManga = SortLibraryManga(index: 3, reverse: false),
          );
          for (final (name, unread) in [
            ('Two unread', 2),
            ('All read', 0),
            ('Five unread', 5),
            ('One unread', 1),
          ]) {
            final manga = await seed.manga(name);
            for (var i = 1; i <= 5; i++) {
              await seed.chapter(
                manga,
                'Chapter $i',
                number: i.toDouble(),
                read: i > unread,
              );
            }
          }
        },
      );
      final order = onScreenOrder(tester, [
        'Two unread',
        'All read',
        'Five unread',
        'One unread',
      ]);
      expect(order.last, 'All read', reason: '$order');
    });

    testWidgets('the last row of a long library can be reached above the '
        'floating navigation bar on a phone (fork 5a5c8b35)', (tester) async {
      final j = await Journey.start(
        tester,
        window: phoneWindow,
        arrange: (seed) async {
          for (var i = 1; i <= 23; i++) {
            await seed.manga('Series ${i.toString().padLeft(2, '0')}');
          }
        },
      );
      await j.scrollTo(find.text('Series 23'));
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
        await j.settle(rounds: 2);
      }
      await j.tap(find.text('Series 23'));
      await j.waitFor(chapterCount);
    });

    testWidgets('History and Updates open when a chapter\'s series is gone '
        '(upstream 83450376)', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final kept = await seed.manga('Kept');
          final gone = await seed.manga('Gone');
          final keptChapters = await seed.chapters(kept, 2);
          final goneChapters = await seed.chapters(gone, 2);
          await seed.history(kept, keptChapters[0]);
          await seed.history(gone, goneChapters[0]);
          await seed.update(kept, keptChapters[1]);
          await seed.update(gone, goneChapters[1]);
          await seed.db.writeTxn(() => seed.db.mangas.delete(gone.id!));
          // And entries whose chapter is gone while the series stays.
          final lost = await seed.manga('Lost chapter');
          final lostChapters = await seed.chapters(lost, 2);
          await seed.history(lost, lostChapters[0]);
          await seed.update(lost, lostChapters[1]);
          await seed.db.writeTxn(
            () => seed.db.chapters.deleteAll([
              lostChapters[0].id!,
              lostChapters[1].id!,
            ]),
          );
        },
      );
      await j.go('/history');
      await j.waitFor(find.text('Kept'));
      await j.go('/updates');
      await j.waitFor(find.text('Kept'));
    });
  });

  group('app state', () {
    testWidgets('turning incognito on and off again keeps the app working, '
        'and reading in incognito saves no progress (upstream #1171)', (
      tester,
    ) async {
      late int id;
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          id = (await seed.chapters(manga, 1, pages: 6)).first.id!;
        },
      );
      await j.go('/more');
      // The More screen's switch, not the banner incognito puts on top.
      await j.tap(find.text('Incognito mode').hitTestable().last);
      await j.go('/MangaLibrary');
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.nextPage();
      await j.nextPage();
      await j.leaveReader();
      expect(await j.savedPage(id), '', reason: 'incognito saves no page');

      await j.go('/more');
      // The More screen's switch, not the banner incognito puts on top.
      await j.tap(find.text('Incognito mode').hitTestable().last);
      await j.restart();
      await j.go('/MangaLibrary');
      await j.tapText('Kuso Onna');
      await j.openChapter('Chapter 1');
      await j.nextPage();
      await j.leaveReader();
      expect(await j.savedPage(id), '2');
    });

    testWidgets('locking and unlocking the app keeps the page that was open '
        '(upstream #1161, fix 29b76e36)', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          final manga = await seed.manga('Kuso Onna');
          await seed.chapters(manga, 2);
        },
      );
      await j.tapText('Kuso Onna');
      await j.waitFor(chapterCount);
      // What MyApp does when the app goes to the background with a lock.
      j.read(appUnlockedStateProvider.notifier).lock();
      await j.settle();
      j.read(appUnlockedStateProvider.notifier).unlock();
      await j.settle();
      expect(find.text('Chapter 2'), findsWidgets);
      expect(find.text('Kuso Onna'), findsWidgets);
    });
  });

  group(
    'categories (fork ed: close the order gap when a category is deleted)',
    () {
      testWidgets('categories made, reordered and deleted keep their tabs in '
          'order', (tester) async {
        final j = await Journey.start(
          tester,
          arrange: (seed) async {
            final a = await seed.category('Alpha', pos: 0);
            final b = await seed.category('Beta', pos: 1);
            final c = await seed.category('Gamma', pos: 2);
            await seed.manga('In alpha', categories: [a.id!]);
            await seed.manga('In beta', categories: [b.id!]);
            await seed.manga('In gamma', categories: [c.id!]);
          },
        );
        expect(onScreenOrder(tester, ['Alpha', 'Beta', 'Gamma']), [
          'Alpha',
          'Beta',
          'Gamma',
        ]);
        await tester.runAsync(() async {
          final beta = await j.db.categorys
              .filter()
              .nameEqualTo('Beta')
              .findFirst();
          await j.db.writeTxn(() => j.db.categorys.delete(beta!.id!));
        });
        await j.restart();
        await j.waitFor(find.text('Gamma'));
        expect(onScreenOrder(tester, ['Alpha', 'Gamma']), ['Alpha', 'Gamma']);
        await j.tapText('Gamma');
        expect(find.text('In gamma'), findsWidgets);
      });
    },
  );
}
