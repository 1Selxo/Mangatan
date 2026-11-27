// Journeys through the library: what a person checks after an upstream merge
// (the 2026-11-21 rebase checklist) and the library bugs fixed since.
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';

/// The continue-reading button on a library tile.
final resumeButton = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Resume',
);

void main() {
  group('library categories', () {
    Future<Journey> withCategories(WidgetTester tester) => Journey.start(
      tester,
      arrange: (seed) async {
        final romance = await seed.category('Romance', pos: 0);
        final comedy = await seed.category('Comedy', pos: 1);
        await seed.manga('Love Story', categories: [romance.id!]);
        await seed.manga('Funny Story', categories: [comedy.id!]);
      },
    );

    testWidgets('the first category tab starts at the left edge', (
      tester,
    ) async {
      // Material 3's startOffset put 52 px of nothing before it; seen by hand
      // on Windows at phone width and at 640×480.
      final j = await withCategories(tester);
      final tab = find.text('Romance').hitTestable().first;
      final bar = find.ancestor(of: tab, matching: find.byType(TabBar));
      expect(
        tester.getTopLeft(tab).dx - tester.getTopLeft(bar.first).dx,
        lessThan(40),
      );
      await j.settle();
    });

    testWidgets('each category tab shows only its own series', (tester) async {
      final j = await withCategories(tester);
      expect(find.text('Love Story'), findsWidgets);
      expect(find.text('Funny Story'), findsNothing);

      await j.tapText('Comedy');
      expect(find.text('Funny Story'), findsWidgets);
      expect(find.text('Love Story'), findsNothing);
    });

    testWidgets(
      'the library reopens on the category it was left on after the window '
      'is closed (fix: remember the category tab on desktop)',
      (tester) async {
        final j = await withCategories(tester);
        await j.tapText('Comedy');
        // Someone browsing a category for a moment, then closing the window.
        await j.wait(const Duration(seconds: 3));
        await j.kill();

        await j.waitFor(find.text('Funny Story'));
        expect(find.text('Love Story'), findsNothing);
      },
    );

    testWidgets('the remembered category survives a normal restart too', (
      tester,
    ) async {
      final j = await withCategories(tester);
      await j.tapText('Comedy');
      await j.restart();
      await j.waitFor(find.text('Funny Story'));
    });

    testWidgets('a deleted remembered category falls back to the first tab', (
      tester,
    ) async {
      final j = await withCategories(tester);
      await j.tapText('Comedy');
      await j.wait(const Duration(seconds: 3));
      await tester.runAsync(() async {
        final comedy = await j.db.categorys
            .filter()
            .nameEqualTo('Comedy')
            .findFirst();
        await j.db.writeTxn(() => j.db.categorys.delete(comedy!.id!));
      });
      await j.restart();
      await j.waitFor(find.text('Love Story'));
    });
  });

  group('continue reading', () {
    testWidgets('caught-up series show no resume button', (tester) async {
      await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.settings((s) => s.libraryShowContinueReadingButton = true);
          final manga = await seed.manga('Finished Story');
          await seed.chapter(manga, 'Chapter 1', number: 1, read: true);
        },
      );
      expect(find.text('Finished Story'), findsWidgets);
      expect(resumeButton, findsNothing);
    });

    testWidgets('resume reopens the chapter in progress at its saved page', (
      tester,
    ) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.settings((s) => s.libraryShowContinueReadingButton = true);
          final manga = await seed.manga('Kuso Onna');
          final chapters = await seed.chapters(manga, 3, pages: 6);
          chapters[1]
            ..lastPageRead = '4'
            ..isRead = false;
          chapters[0].isRead = true;
          await seed.db.writeTxn(() => seed.db.chapters.putAll(chapters));
          await seed.history(manga, chapters[1]);
        },
      );
      await j.tap(resumeButton);
      await j.waitFor(find.byType(MangaReaderView));
      await j.settle(rounds: 20);

      expect(find.text('Chapter 2'), findsWidgets);
      // Stored 1-based: page 4 of 6.
      expect(find.text('4 / 6'), findsWidgets, reason: '${j.visibleTexts()}');
    });

    testWidgets('once the chapter in progress is read, resume moves on to the '
        'first unread one', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.settings((s) => s.libraryShowContinueReadingButton = true);
          final manga = await seed.manga('Kuso Onna');
          final chapters = await seed.chapters(manga, 3, pages: 4);
          chapters[0].isRead = true;
          await seed.db.writeTxn(() => seed.db.chapters.put(chapters[0]));
          await seed.history(manga, chapters[0]);
        },
      );
      await j.tap(resumeButton);
      await j.waitFor(find.byType(MangaReaderView));
      expect(find.text('Chapter 2'), findsWidgets);
    });
  });

  group('library at different window sizes', () {
    for (final (label, size) in [
      ('desktop', desktopWindow),
      ('phone', phoneWindow),
      ('narrow window', const Size(700, 600)),
    ]) {
      testWidgets('a full library lays out without overflow on a $label', (
        tester,
      ) async {
        // CJK titles once overflowed the Continue shelf tiles.
        await Journey.start(
          tester,
          window: size,
          arrange: (seed) async {
            for (final name in [
              'KUSO ONNA NO SACHIARE',
              '请欺负我吧，恶役小姐！',
              'わたしが恋人になれるわけないじゃん、ムリムリ！（※ムリじゃなかった!?）',
              'A',
              'An extraordinarily long English title that keeps going and going',
            ]) {
              final manga = await seed.manga(name);
              await seed.chapter(manga, 'Chapter 1', number: 1);
            }
          },
        );
        // Layout overflow is reported as a test failure by the framework.
        expect(find.text('A'), findsWidgets);
      });
    }

    testWidgets('resizing the window keeps the library usable', (tester) async {
      final j = await Journey.start(
        tester,
        arrange: (seed) => seed.manga('Kuso Onna'),
      );
      await j.resize(phoneWindow);
      await j.settle();
      expect(find.text('Kuso Onna'), findsWidgets);
      await j.resize(desktopWindow);
      await j.settle();
      expect(find.text('Kuso Onna'), findsWidgets);
    });
  });
}
